#!/usr/bin/env python3
"""Run every gate in this folder and hold each one to a recorded fault count.

Run from anywhere::

    python3 tool/check_gates.py            # run them all, report, gate
    python3 tool/check_gates.py --json     # the same, machine-readable
    python3 tool/check_gates.py --update   # rewrite the baselines to today

Exits non-zero when any gate disagrees with its baseline, in either direction.

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

**What a gate must do to be run.** Be named ``check_*.py`` in this folder, and
end its ``main`` with [gate_report.report_faults]. Discovery is by glob, so
there is no list of gates to forget to update. ``report_*.py`` is excluded by
the naming convention: those report and never gate.
"""

from __future__ import annotations

import argparse
import datetime
import json
import subprocess
import sys
from pathlib import Path

from gate_report import FAULT_LINE

SELF = Path(__file__).name
TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parent
BASELINES = TOOL_DIR / "gate_baselines.json"

#: Statuses a run may end in. The first two pass; the rest fail.
PASSING = {"clean", "at-baseline"}


def gate_scripts() -> list[Path]:
    """Every gate in this folder, discovered rather than listed.

    By name, not by path: this file matches its own glob, and running itself
    would not merely be wrong but unbounded.
    """
    return sorted(p for p in TOOL_DIR.glob("check_*.py") if p.name != SELF)


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


def run_gate(script: Path) -> dict:
    """Run one gate and describe what happened, without judging it yet."""
    try:
        done = subprocess.run(
            [sys.executable, str(script)],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=600,
        )
    except subprocess.TimeoutExpired:
        return {"name": script.stem, "faults": None, "exit": None,
                "output": "timed out after 600s"}
    return {
        "name": script.stem,
        "faults": fault_count(done.stdout),
        "exit": done.returncode,
        "output": (done.stdout + done.stderr).strip(),
    }


def judge(run: dict, baselines: dict) -> dict:
    """Give a run a status and, when it fails, the sentence that explains it."""
    name, faults = run["name"], run["faults"]
    entry = baselines.get(name)
    result = {"name": name, "faults": faults,
              "baseline": entry["faults"] if entry else None,
              "measured": entry.get("measured") if entry else None,
              "note": entry.get("note") if entry else None}

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


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--json", action="store_true",
                        help="emit the results as JSON for a test to read")
    parser.add_argument("--update", action="store_true",
                        help="rewrite the baselines to the counts measured now")
    args = parser.parse_args(argv)

    baselines = read_baselines()
    scripts = gate_scripts()
    results = [judge(run_gate(s), baselines) for s in scripts]
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

    width = max(len(r["name"]) for r in results)
    for result in results:
        mark = "ok  " if result["status"] in PASSING else "FAIL"
        pinned = ("" if result["baseline"] in (None, 0)
                  else f"  (baseline {result['baseline']})")
        print(f"{mark}  {result['name']:<{width}}  "
              f"{result['faults']} fault(s){pinned}")
    for result in failed:
        print(f"\n{result['name']}: {result['status']}\n  {result['message']}")
    for problem in problems:
        print(f"\n  {problem}")

    total = sum(r["faults"] or 0 for r in results)
    print(f"\n{len(results)} gates, {len(failed)} failing, "
          f"{total} fault(s) outstanding")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
