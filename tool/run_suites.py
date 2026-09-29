#!/usr/bin/env python3
"""Run every tom_core package suite and the gate suite, and give one verdict.

Run from anywhere::

    python3 tool/run_suites.py                      # all eight suites + the gates
    python3 tool/run_suites.py kernel server        # a subset, by name or prefix
    python3 tool/run_suites.py --no-gates flutter_ui
    python3 tool/run_suites.py --gates-only         # the gate suite alone
    python3 tool/run_suites.py --list               # what would run, and how

Exits 0 only when every selected suite passed.

**Why this exists.** `check_gates.py` holds the documentation to the code and is
routinely read as "tom_core is green" -- but it says nothing about the
packages' own suites. A change reaching several packages was twice verified by
running the gates and the suite of the package it was *about*, and a sibling
package's suite stayed red for a day with nothing saying so: a documentation
table another package's test parsed, and a stricter claim reader a server test
still asserted the old leniency of. Remembering which packages a change reached
is the step that failed; this runs all of them, so nobody has to.

**What "green" means here** is what the quest overview says it means: every
package that carries a suite passes it, and the gates hold. That is the five
framework packages, `tom_core_codespecs`, and the two `tom_flutter_ui`
harnesses -- eight suites -- plus `check_gates.py`.

**How each suite runs.** Flutter packages run under `flutter test`, the rest
under `dart test`, each in its own package directory with its own
configuration: a package's `dart_test.yaml` decides its concurrency, and this
runner forces none. (`tom_core_server` serialises its suite files there;
`tom_flutter_form_test`'s README asks explicitly that nobody add `-j 1`.) A
package whose dependencies were never resolved gets `pub get` first.

The DB-backed tests in `tom_core_server` skip themselves when no MariaDB is
reachable, as they do under a plain `dart test`; bring one up with
`tom_core_server/tool/run_db_tests.sh` to include them.

`tom_flutter_ui`'s suite contains `repo_doc_gates_test.dart`, which runs every
gate's self-test and the gate suite itself, so selecting it together with the
gates runs the gates twice. That is harmless, only slow; pass ``--no-gates``
when the one suite is what you want.

**Output.** One line when a suite starts, a progress line every 30 seconds
with the reporter's running counts (the longest suites take a quarter of an
hour, and silence that long reads as a hang), and a table at the end with each
suite's verdict, counts and duration. The full output of each run is kept under
``tool/ztmp/suites/<package>.log`` (untracked), named in the table for any
suite that failed.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parent
LOG_DIR = TOOL_DIR / "ztmp" / "suites"

#: Every package that carries a suite, in build order (the order a failure in a
#: lower package is most informative in).
PACKAGES = (
    "tom_core_kernel",
    "tom_core_server",
    "tom_core_agentic",
    "tom_core_codespecs",
    "tom_flutter_ui",
    "tom_core_flutter",
    "tom_flutter_ui_test",
    "tom_flutter_form_test",
)

#: The gate suite's name in selections and in the table.
GATES = "gates"

#: How often a running suite reports progress.
PROGRESS_EVERY = 30.0

#: The reporter's running counts: ``+pass ~skip -fail``.
COUNTS = re.compile(r"\+(\d+)(?: ~(\d+))?(?: -(\d+))?")


@dataclass
class Result:
    name: str
    passed: bool
    summary: str
    seconds: float
    log: Path | None


def is_flutter(package: str) -> bool:
    """Whether ``package`` depends on the Flutter SDK, so needs `flutter test`."""
    pubspec = (REPO_ROOT / package / "pubspec.yaml").read_text(encoding="utf-8")
    return re.search(r"^\s*sdk:\s*flutter\s*$", pubspec, re.MULTILINE) is not None


def command_for(package: str) -> list[str]:
    return ["flutter", "test"] if is_flutter(package) else ["dart", "test"]


def select(arguments: list[str]) -> tuple[list[str], bool]:
    """The packages the arguments name, and whether the gates run.

    A name selects the package it equals, or else every package it is a
    substring of -- ``server`` is `tom_core_server`, ``flutter_ui`` is
    `tom_flutter_ui` alone because an exact match wins. A name matching nothing
    is an error rather than an empty run: a typo that selected no suite would
    otherwise report success.
    """
    names = [a for a in arguments if not a.startswith("-")]
    gates = "--no-gates" not in arguments
    if "--gates-only" in arguments:
        return [], True
    if not names:
        return list(PACKAGES), gates
    chosen: list[str] = []
    for name in names:
        if name == GATES:
            gates = True
            continue
        exact = [p for p in PACKAGES if p == name or p == f"tom_{name}" or p == f"tom_core_{name}"]
        matches = exact or [p for p in PACKAGES if name in p]
        if not matches:
            raise SystemExit(f"run_suites: '{name}' names no package; known: {', '.join(PACKAGES)}")
        chosen += [m for m in matches if m not in chosen]
    # Naming packages narrows the run to them; the gates join only when asked.
    return [p for p in PACKAGES if p in chosen], gates and GATES in names


def run(name: str, command: list[str], cwd: Path) -> Result:
    """Run one suite, streaming progress, and judge it by its exit status."""
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log = LOG_DIR / f"{name}.log"
    print(f"\n==> {name}: {' '.join(command)}", flush=True)
    started = time.monotonic()
    last_report = started
    counts = ""
    # A runner that prints no `+N` counts -- the gate suite -- is summarised by
    # its last line instead ("41 gates, 0 failing, ...").
    last_line = ""
    # Line-buffered, so the log shows the test a suite is on *while* it runs --
    # a suite that stops advancing is exactly when somebody reads the log.
    with log.open("w", encoding="utf-8", buffering=1) as sink:
        process = subprocess.Popen(
            command,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            errors="replace",
        )
        assert process.stdout is not None
        for line in process.stdout:
            sink.write(line)
            if line.strip():
                last_line = line.strip()
            match = COUNTS.search(line)
            if match:
                counts = match.group(0)
            now = time.monotonic()
            if now - last_report >= PROGRESS_EVERY:
                print(f"    {name}: {counts or 'running'}  ({now - started:.0f}s)", flush=True)
                last_report = now
        status = process.wait()
    seconds = time.monotonic() - started
    passed = status == 0
    summary = counts or last_line[:48] or ("no output" if passed else f"exit {status}")
    print(f"<== {name}: {'PASS' if passed else 'FAIL'}  {summary}  ({seconds:.0f}s)", flush=True)
    return Result(name, passed, summary, seconds, None if passed else log)


def ensure_resolved(package: str) -> None:
    """Run `pub get` for a package whose dependencies were never resolved."""
    directory = REPO_ROOT / package
    if (directory / ".dart_tool" / "package_config.json").exists():
        return
    tool = "flutter" if is_flutter(package) else "dart"
    print(f"    {package}: resolving dependencies ({tool} pub get)", flush=True)
    subprocess.run([tool, "pub", "get"], cwd=directory, check=False)


def main(argv: list[str]) -> int:
    arguments = argv[1:]
    packages, gates = select(arguments)

    missing = [t for t in ("dart", "flutter") if shutil.which(t) is None]
    needed = {"flutter" for p in packages if is_flutter(p)} | ({"dart"} if packages else set())
    if needed & set(missing):
        print(
            f"run_suites: {', '.join(sorted(needed & set(missing)))} not on PATH; "
            "put the Flutter SDK's bin directory on PATH",
            file=sys.stderr,
        )
        return 2

    plan = [(p, command_for(p), REPO_ROOT / p) for p in packages]
    if gates:
        plan.append((GATES, [sys.executable, str(TOOL_DIR / "check_gates.py")], REPO_ROOT))

    if "--list" in arguments:
        for name, command, cwd in plan:
            print(f"{name:24} {' '.join(command)}   (in {cwd.relative_to(REPO_ROOT.parent) if cwd != REPO_ROOT else '.'})")
        return 0
    if not plan:
        print("run_suites: nothing selected", file=sys.stderr)
        return 2

    results: list[Result] = []
    for name, command, cwd in plan:
        if name != GATES:
            ensure_resolved(name)
        results.append(run(name, command, cwd))

    print("\n" + "-" * 72)
    for r in results:
        verdict = "PASS" if r.passed else "FAIL"
        where = f"   log: {r.log.relative_to(REPO_ROOT)}" if r.log else ""
        print(f"{verdict}  {r.name:24} {r.summary:48} {r.seconds:6.0f}s{where}")
    failed = [r.name for r in results if not r.passed]
    total = sum(r.seconds for r in results)
    print("-" * 72)
    print(
        f"{len(results)} suite(s), {len(failed)} failing"
        + (f": {', '.join(failed)}" if failed else "")
        + f"  ({total / 60:.1f} min)"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
