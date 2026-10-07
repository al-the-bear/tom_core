#!/usr/bin/env python3
"""Run every gate in this folder and hold each one to a recorded fault count.

Run from anywhere::

    python3 tool/check_gates.py            # run them all, report, gate
    python3 tool/check_gates.py --json     # the same, machine-readable
    python3 tool/check_gates.py --update   # rewrite the baselines to today

Exits non-zero when any gate disagrees with its baseline, in either direction,
or when a gate's own ``--self-test`` fails.

**What this is for.** Every checker beside this file was written to hold a
documentation invariant, and until this runner existed *nothing ran any of
them*. Grepping the repository for their names found them in the README,
in two changelogs, and in one Dart comment -- no test, no hook, no CI step. The
predictable thing had happened: five were failing, one had silently drifted from
zero to one dangling reference, and that single regression was found only
because somebody happened to run the checker by hand.

An invariant nobody re-checks is not an invariant, it is a comment. This file
is what makes them invariants.

**Why a baseline instead of zero.** Demanding zero on the day the runner lands
means 444 documentation faults have to be repaired before anything at all is
enforced, and until they are, every new fault lands unnoticed alongside them.
So each gate is pinned to the count it reports *today*: the backlog is frozen
where it is, and the next fault is a failure. Clearing a backlog is separate
work, tracked separately, and this file gets out of its way.

**The ratchet turns both ways.** A count *below* its baseline fails too, with a
message saying to lower it. Without that, repaired ground silently reopens: a
gate baselined at 43 stays quiet while faults fall to 12 and climb back to 43,
which is the whole failure this runner exists to prevent, merely slower. The
same reasoning makes an unbaselined gate a failure rather than a skip -- a new
checker is enforced from the day it lands, not from the day someone remembers
to register it -- and makes a missing [gate_report.FAULT_LINE] a failure rather
than a count of zero.

**Every self-test runs too.** A gate that holds at zero passes just as well when
it has stopped reading anything, and a count cannot tell the two apart. So a
gate may implement ``--self-test``: damage a real document in memory, require
the matching objection, restore it and require the restored state to be clean.
This runner runs that as well as the measuring run, for every gate whose source
carries the flag as a string literal, and a self-test that fails makes the gate
fail -- ``self-test-failed`` when the count itself held -- rather than read as a
zero. A gate without one is reported as such in its row and counted in the
closing line, so the population a count alone vouches for stays visible.
``--update`` skips the self-tests: it records counts, and a broken self-test
does not change one.

**What a gate must do to be run.** Be named ``check_*.py`` in this folder, and
end its ``main`` with [gate_report.report_faults]. Discovery is by glob, so
there is no list of gates to forget to update. ``report_*.py`` is excluded by
the naming convention: those report and never gate.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

from dart_sdk import environment_with_dart
from gate_report import FAULT_LINE

SELF = Path(__file__).name
TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parent
BASELINES = TOOL_DIR / "gate_baselines.json"

#: Statuses a run may end in. The first two pass; the rest fail.
PASSING = {"clean", "at-baseline"}

#: The exit status a gate uses to say it could not run at all -- `dart` absent,
#: a walk that found nothing -- as distinct from `0` (clean) and `1` (faults).
#: Reported as `cannot-run` with the gate's own reason.
CANNOT_RUN_EXIT = 2

#: How long one gate may run before it is stopped and reported `timed-out`.
#:
#: Derived from a measured run rather than guessed: the whole suite in
#: sequence, as this runner runs it, on 2026-09-30 (mbp) with the verdict cache
#: (gate_cache.py) emptied first. The slowest gate took 41.3 s
#: (`check_dartdoc_build`, which is not cached), the analyzer-backed pair 23.5 s
#: and 22.7 s cold -- a fraction of that warm -- and the suite 3 min 13 s. The
#: limit is about twenty times the slowest gate: room for a loaded machine and a
#: cold pub cache, and still short enough that a gate which genuinely hangs is
#: noticed within a run. Why earlier runs overran the old 600 s limit was never
#: established; one candidate is gone -- a killed gate no longer leaves its
#: `dart analyze` running into the next one (see [_stop_tree]). `--timings`
#: prints what each gate took, which is the number to revisit this against.
GATE_TIMEOUT_SECONDS = 900

#: How long to wait for a killed gate's remaining output. Its whole process
#: group is gone by then, so this only matters when something escaped the kill.
POST_KILL_READ_SECONDS = 10


def gate_scripts() -> list[Path]:
    """Every gate in this folder, discovered rather than listed.

    By name, not by path: this file matches its own glob, and running itself
    would not merely be wrong but unbounded.
    """
    return sorted(p for p in TOOL_DIR.glob("check_*.py") if p.name != SELF)


#: How a gate declares that it implements `--self-test`: the flag as a string
#: literal, which is what its argv handling compares against. A gate that only
#: names the flag in prose is not matched.
SELF_TEST_FLAG = re.compile(r"""["']--self-test["']""")


def has_self_test(script: Path) -> bool:
    """Whether [script] implements `--self-test`."""
    return bool(SELF_TEST_FLAG.search(script.read_text(encoding="utf-8")))


def read_baselines() -> dict:
    if not BASELINES.exists():
        return {}
    return json.loads(BASELINES.read_text(encoding="utf-8")).get("gates", {})


def fault_count(output: str) -> int | None:
    """The number on the gate's [gate_report.FAULT_LINE], or None if absent."""
    for line in reversed(output.split("\n")):
        if line.startswith(f"{FAULT_LINE}:"):
            try:
                return int(line.split(":", 1)[1].strip())
            except ValueError:
                return None
    return None


#: The environment every gate runs in: this one, with the Dart SDK's `bin/` on
#: PATH when the shell did not put it there (see dart_sdk.py). Several gates
#: refuse to run without `dart`; finding it once here is what makes the
#: documented command measure them from a plain shell.
GATE_ENV, ADDED_DART = environment_with_dart()

#: Whether any `dart` resolves in the environment the gates run in. When none
#: does, every gate that needs one fails for that single reason, and the run
#: says so once, before the per-gate rows, so that a column of failures with a
#: shared cause is not read as that many regressions.
DART_FOUND = shutil.which("dart", path=GATE_ENV.get("PATH")) is not None

#: The self-test column of a gate's row.
SELF_TEST_MARK = {"passed": "self-test ok    ",
                  "failed": "self-test FAILED",
                  "none": "no self-test    "}

#: The statuses in which a gate measured nothing: it refused, crashed or was
#: stopped. Its count is absent from the total, which is not the same as zero.
UNMEASURED = {"cannot-run", "crashed", "timed-out"}


def _stop_tree(process: subprocess.Popen) -> None:
    """Kill [process] and everything it started.

    A gate is a Python process that shells out -- to `dart analyze`, which may
    itself start an analysis server. Killing only the gate orphans those, and
    an orphaned analyzer keeps working through the gates that run after it,
    which is one way a gate that takes seconds alone can be slow in sequence.
    So each gate is started as the leader of its own process group, and the
    group is what is killed.
    """
    if sys.platform == "win32":
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(process.pid)],
                       capture_output=True)
    else:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


def run_gate(script: Path, timeout: float = GATE_TIMEOUT_SECONDS,
             arguments: tuple[str, ...] = ()) -> dict:
    """Run one gate and describe what happened, without judging it yet."""
    started = time.monotonic()
    process = subprocess.Popen(
        [sys.executable, str(script), *arguments],
        cwd=REPO_ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=GATE_ENV,
        start_new_session=sys.platform != "win32",
        creationflags=(subprocess.CREATE_NEW_PROCESS_GROUP
                       if sys.platform == "win32" else 0),
    )
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        _stop_tree(process)
        try:
            # Bounded as well: a process that escaped the kill still holds the
            # pipes, and an unbounded read would wait for it -- the runner
            # hanging past the very limit it just enforced.
            stdout, stderr = process.communicate(timeout=POST_KILL_READ_SECONDS)
        except subprocess.TimeoutExpired:
            process.kill()
            stdout = stderr = ""
        printed = (stdout + stderr).strip().splitlines()
        return {"name": script.stem, "faults": None, "exit": None,
                "timed_out": True, "limit": timeout,
                "seconds": round(time.monotonic() - started, 1),
                "output": (stdout + stderr).strip(),
                "last_line": printed[-1] if printed else None}
    return {
        "name": script.stem,
        "faults": fault_count(stdout),
        "exit": process.returncode,
        "timed_out": False,
        "seconds": round(time.monotonic() - started, 1),
        "output": (stdout + stderr).strip(),
        "stderr": stderr.strip(),
    }


def judge(run: dict, baselines: dict) -> dict:
    """Give a run a status and, when it fails, the sentence that explains it."""
    name, faults = run["name"], run["faults"]
    entry = baselines.get(name)
    result = {"name": name, "faults": faults,
              "seconds": run.get("seconds"),
              "baseline": entry["faults"] if entry else None,
              "measured": entry.get("measured") if entry else None,
              "note": entry.get("note") if entry else None}

    if run.get("timed_out"):
        # Told apart from a gate that finished without its count line: the
        # remedy is the opposite one. This gate was stopped, not silent, and
        # the old message sent readers to add a `report_faults` it already had.
        limit = run.get("limit", GATE_TIMEOUT_SECONDS)
        last = run.get("last_line")
        result["status"] = "timed-out"
        result["limit"] = limit
        result["message"] = (
            f"{name} was stopped after the {limit:g}s limit, before it "
            f"reported a count; it and every process it started were killed. "
            f"Its content has not been judged -- this is not a missing "
            f"'{FAULT_LINE}:' line. "
            + (f"The last thing it printed was: {last}. " if last
               else "It printed nothing before it was stopped. ")
            + "Run it alone to see whether it is slow or stuck, and see "
            "GATE_TIMEOUT_SECONDS in check_gates.py.")
        return result

    if faults is None and run["exit"] == CANNOT_RUN_EXIT:
        # The gate's own refusal -- it could not measure, and said why. That is
        # a different failure from a gate that ran and forgot to count, and the
        # remedy is in the reason, so the reason is what is reported.
        said = (run.get("stderr") or run["output"]).strip().splitlines()
        result["status"] = "cannot-run"
        result["message"] = (
            f"{name} reported that it could not run, so nothing was measured: "
            f"{said[-1] if said else '(no reason given)'}")
        return result

    if faults is None and "Traceback (most recent call last)" in (
            run.get("stderr") or ""):
        # The gate died before it could count, and Python said why. The
        # exception line is the diagnosis -- a `dart` that could not be
        # started, a module that would not import -- so it is what is
        # reported. Telling the reader to add a `report_faults` the gate
        # already ends with sent them to edit healthy gates, and when several
        # crash for one shared reason the message is the only place that
        # reason appears.
        said = [line for line in run["stderr"].splitlines() if line.strip()]
        result["status"] = "crashed"
        result["message"] = (
            f"{name} crashed before it reported a count, so nothing was "
            f"measured: {said[-1].strip() if said else '(no message)'}. "
            f"Its content has not been judged -- this is not a missing "
            f"'{FAULT_LINE}:' line. Run `python3 tool/{name}.py` for the "
            f"whole traceback.")
        return result

    if faults is None:
        result["status"] = "no-count"
        result["message"] = (
            f"{name} printed no '{FAULT_LINE}:' line, so its faults cannot be "
            f"counted. End its main() with `return report_faults(n)` from "
            f"gate_report.py. Its exit status was {run['exit']}.")
        return result

    if entry is None:
        result["status"] = "unbaselined"
        result["message"] = (
            f"{name} is a gate with no baseline. It reports {faults} fault(s) "
            f"today. Record that with `python3 tool/check_gates.py --update` "
            f"and write a note saying what the faults are.")
        return result

    baseline = entry["faults"]
    measured = entry.get("measured", "an unknown date")
    if faults > baseline:
        result["status"] = "regressed"
        result["message"] = (
            f"{name} reports {faults} fault(s), {faults - baseline} more than "
            f"the {baseline} recorded on {measured}. Repair the new fault -- "
            f"run `python3 tool/{name}.py` to see it. Do not raise the "
            f"baseline.")
    elif faults < baseline:
        result["status"] = "improved"
        result["message"] = (
            f"{name} reports {faults} fault(s), down from the {baseline} "
            f"recorded on {measured}. Lower the baseline with `python3 "
            f"tool/check_gates.py --update` so the ground you just took "
            f"cannot be given back quietly.")
    elif faults == 0:
        result["status"] = "clean"
        result["message"] = None
    else:
        result["status"] = "at-baseline"
        result["message"] = None
    return result


def judge_self_test(result: dict, run: dict | None) -> dict:
    """Record a gate's self-test on its judged [result].

    `run` is the `--self-test` run, or None for a gate without one. A self-test
    passes on exit 0 and fails on anything else, a timeout included. A failure
    turns a passing measurement into `self-test-failed`: the count held, but
    nothing now shows the gate can still see the fault it counts. On a
    measurement that already failed, it is added to that message instead, so
    the first diagnosis stays first.
    """
    if run is None:
        result["self_test"] = "none"
        return result
    if not run.get("timed_out") and run["exit"] == 0:
        result["self_test"] = "passed"
        return result
    result["self_test"] = "failed"
    said = [line for line in (run.get("output") or "").splitlines()
            if line.strip()]
    why = ("it was stopped at the time limit" if run.get("timed_out")
           else f"it exited {run['exit']}"
           + (f" saying: {said[-1].strip()}" if said else ""))
    sentence = (
        f"{result['name']} --self-test failed -- {why}. A fault it is meant "
        f"to detect survived being planted, so its count no longer shows that "
        f"it is reading. Run `python3 tool/{result['name']}.py --self-test`.")
    if result["status"] in PASSING:
        result["status"] = "self-test-failed"
        result["message"] = sentence
    else:
        result["message"] = f"{result['message']} Separately: {sentence}"
    return result


def row_text(result: dict) -> str:
    """What a gate's summary row says in place of a count it does not have."""
    if result["faults"] is not None:
        return f"{result['faults']} fault(s)"
    if result["status"] == "timed-out":
        return f"timed out after {result['limit']:g}s"
    if result["status"] == "cannot-run":
        return "not measured"
    if result["status"] == "crashed":
        return "crashed"
    return "no count"


def stale_entries(baselines: dict, names: set[str]) -> list[str]:
    """Baselines naming a gate that no longer exists."""
    return sorted(set(baselines) - names)


def write_baselines(results: list[dict], baselines: dict) -> None:
    today = datetime.date.today().isoformat()
    gates = {}
    for result in sorted(results, key=lambda r: r["name"]):
        was = baselines.get(result["name"], {})
        if result["faults"] is None:
            # The gate ran but produced no count -- it crashed, or a tool it
            # shells out to is absent on this machine. Its recorded count and
            # its hand-written note are the only things that survive that, so
            # carry the entry through untouched. Dropping it would let an
            # --update run for an unrelated gate erase the baseline of the one
            # gate that is currently broken.
            if was:
                gates[result["name"]] = was
            continue
        entry = {"faults": result["faults"]}
        entry["measured"] = (
            was.get("measured", today)
            if was.get("faults") == result["faults"] else today)
        if was.get("note"):
            entry["note"] = was["note"]
        gates[result["name"]] = entry
    BASELINES.write_text(
        json.dumps({"about": ABOUT, "gates": gates}, indent=2,
                   ensure_ascii=False) + "\n",
        encoding="utf-8")


ABOUT = (
    "Fault counts the gates in tool/ are held to. Read by tool/check_gates.py, "
    "which fails when a gate's count moves in either direction: up means a new "
    "fault, down means a baseline that should be lowered so the repair sticks. "
    "'measured' is the date the count last changed. Regenerate with "
    "`python3 tool/check_gates.py --update`; write 'note' by hand."
)


#: Where --self-test writes the throwaway gates it runs. Under the gitignored
#: tool/ztmp/, and never matched by [gate_scripts], which globs tool/ only.
SELF_TEST_DIR = TOOL_DIR / "ztmp" / "check_gates_self_test"

_STALLING_GATE = """\
import subprocess, sys, time
child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(120)"])
open(sys.argv[0] + ".child", "w").write(str(child.pid))
print("stalled on artifact reflection_entry.reflection.dart", flush=True)
time.sleep(120)
"""


def _alive(pid: int) -> bool:
    """Whether [pid] is still running. A zombie is not: it has exited."""
    state = subprocess.run(["ps", "-o", "stat=", "-p", str(pid)],
                           capture_output=True, text=True).stdout.strip()
    return bool(state) and not state.startswith("Z")


def self_test() -> int:
    """Run throwaway gates that stall, stay silent, crash and refuse, and check
    that each is reported as what it is.

    The stalling one starts a child of its own, as a gate running `dart`
    does, so the test also checks that a timeout leaves nothing running.
    """
    SELF_TEST_DIR.mkdir(parents=True, exist_ok=True)
    failures: list[str] = []

    def gate(name: str, body: str) -> Path:
        path = SELF_TEST_DIR / f"{name}.py"
        path.write_text(body, encoding="utf-8")
        return path

    stalling = gate("check_stalling", _STALLING_GATE)
    run = run_gate(stalling, timeout=3)
    result = judge(run, {})
    if result["status"] != "timed-out":
        failures.append(f"a stalled gate was judged {result['status']!r}")
    if "3s" not in (result.get("message") or ""):
        failures.append("the timeout message does not name the 3s limit")
    if "reflection_entry.reflection.dart" not in (result.get("message") or ""):
        failures.append("the timeout message drops the gate's last line")
    if "report_faults" in (result.get("message") or ""):
        failures.append("the timeout message sends the reader to report_faults")
    if row_text(result) != "timed out after 3s":
        failures.append(f"the timed-out row reads {row_text(result)!r}")
    if sys.platform != "win32":
        child = int(Path(f"{stalling}.child").read_text())
        deadline = time.monotonic() + 5
        while _alive(child) and time.monotonic() < deadline:
            time.sleep(0.1)
        if _alive(child):
            os.kill(child, signal.SIGKILL)
            failures.append("a timed-out gate left the process it started "
                            "running")

    silent = judge(run_gate(gate("check_silent", "print('done')\n")), {})
    if silent["status"] != "no-count" or "report_faults" not in silent["message"]:
        failures.append(f"a gate without a count line was judged "
                        f"{silent['status']!r}")
    if row_text(silent) != "no count":
        failures.append(f"the no-count row reads {row_text(silent)!r}")

    crashing = judge(run_gate(gate(
        "check_crashing",
        "import subprocess\n"
        "subprocess.run(['no-such-executable-for-check-gates'])\n")), {})
    if crashing["status"] != "crashed":
        failures.append(f"a crashing gate was judged {crashing['status']!r}")
    if "No such file or directory" not in (crashing.get("message") or ""):
        failures.append("the crash message drops the exception that explains "
                        "it")
    if "report_faults" in (crashing.get("message") or ""):
        failures.append("the crash message sends the reader to report_faults")
    if row_text(crashing) != "crashed":
        failures.append(f"the crashed row reads {row_text(crashing)!r}")

    refusing = judge(run_gate(gate(
        "check_refusing",
        "import sys\nprint('dart is not on PATH', file=sys.stderr)\n"
        "sys.exit(2)\n")), {})
    if refusing["status"] != "cannot-run":
        failures.append(f"a refusing gate was judged {refusing['status']!r}")

    zero = {"faults": 0}
    escaping = gate(
        "check_escaping",
        "import sys\n"
        "if '--self-test' in sys.argv:\n"
        "    print('self-test: a planted fault escaped')\n"
        "    sys.exit(2)\n"
        "print('GATE-FAULTS: 0')\n")
    if not has_self_test(escaping):
        failures.append("a gate handling '--self-test' was not recognised")
    escaped = judge_self_test(
        judge(run_gate(escaping), {"check_escaping": zero}),
        run_gate(escaping, arguments=("--self-test",)))
    if escaped["status"] != "self-test-failed":
        failures.append(f"a gate whose self-test fails was judged "
                        f"{escaped['status']!r}")
    if "a planted fault escaped" not in (escaped.get("message") or ""):
        failures.append("the self-test failure drops what the self-test said")

    plain = gate("check_plain",
                 "# Mentions --self-test only in prose.\n"
                 "print('GATE-FAULTS: 0')\n")
    if has_self_test(plain):
        failures.append("a gate naming --self-test only in prose was taken "
                        "for one that implements it")
    unvouched = judge_self_test(
        judge(run_gate(plain), {"check_plain": zero}), None)
    if unvouched["status"] != "clean" or unvouched["self_test"] != "none":
        failures.append(f"a gate without a self-test was judged "
                        f"{unvouched['status']!r} / {unvouched['self_test']!r}")

    for failure in failures:
        print(f"self-test: {failure}", file=sys.stderr)
    print(f"self-test: 6 throwaway gates, {len(failures)} failure(s)")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--json", action="store_true",
                        help="emit the results as JSON for a test to read")
    parser.add_argument("--timings", action="store_true",
                        help="list what each gate took, slowest first")
    parser.add_argument("--update", action="store_true",
                        help="rewrite the baselines to the counts measured now")
    parser.add_argument("--self-test", action="store_true",
                        help="check the runner's own verdicts on throwaway "
                             "gates that stall, stay silent, crash, refuse, "
                             "fail their own self-test and have none")
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test()

    baselines = read_baselines()
    scripts = gate_scripts()
    results = [judge(run_gate(s), baselines) for s in scripts]
    if not args.update:
        for script, result in zip(scripts, results):
            judge_self_test(
                result,
                run_gate(script, arguments=("--self-test",))
                if has_self_test(script) else None)
    stale = stale_entries(baselines, {s.stem for s in scripts})

    if args.update:
        write_baselines(results, baselines)
        print(f"wrote {BASELINES.relative_to(REPO_ROOT)} "
              f"({len(results)} gates)")
        if stale:
            print(f"dropped {len(stale)} entry(ies) for gates that are gone: "
                  f"{', '.join(stale)}")
        return 0

    problems = [
        f"gate_baselines.json records '{name}', which is not a gate in tool/. "
        f"Remove the entry with `python3 tool/check_gates.py --update`."
        for name in stale
    ]
    failed = [r for r in results if r["status"] not in PASSING]
    ok = not failed and not problems

    if args.json:
        print(json.dumps(
            {"ok": ok, "gates": results, "problems": problems}, indent=2))
        return 0 if ok else 1

    if args.timings:
        for result in sorted(results, key=lambda r: -(r.get("seconds") or 0)):
            print(f"{result.get('seconds') or 0:7.1f}s  {result['name']}")
        print()
    if ADDED_DART is not None:
        print(f"dart was not on PATH; gates ran with {ADDED_DART}\n")
    if not DART_FOUND:
        print("dart could not be found -- not on PATH, not under DART_SDK or "
              "FLUTTER_ROOT, and not in any conventional install location "
              "(tool/dart_sdk.py). Every gate that needs it is reported as not "
              "measured, for this one reason. Put the SDK's bin/ on PATH or "
              "set DART_SDK and run again.\n")
    width = max(len(r["name"]) for r in results)
    for result in results:
        mark = "ok  " if result["status"] in PASSING else "FAIL"
        pinned = ("" if result["baseline"] in (None, 0)
                  else f"  (baseline {result['baseline']})")
        print(f"{mark}  {result['name']:<{width}}  "
              f"{SELF_TEST_MARK[result.get('self_test', 'none')]}  "
              f"{row_text(result)}{pinned}")
    for result in failed:
        print(f"\n{result['name']}: {result['status']}\n  {result['message']}")
    for problem in problems:
        print(f"\n  {problem}")

    total = sum(r["faults"] or 0 for r in results)
    unmeasured = sum(1 for r in results if r["status"] in UNMEASURED)
    tested = sum(1 for r in results if r.get("self_test") != "none")
    print(f"\n{len(results)} gates ({tested} self-tested, "
          f"{len(results) - tested} without a self-test), {len(failed)} failing"
          + (f" ({unmeasured} not measured, so their faults are not in the "
             f"total)" if unmeasured else "")
          + f", {total} fault(s) outstanding")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
