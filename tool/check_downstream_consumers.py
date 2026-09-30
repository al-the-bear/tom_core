#!/usr/bin/env python3
"""Hold the downstream consumers of tom_core to the framework as it stands.

Run from anywhere::

    python3 tool/check_downstream_consumers.py

Exits non-zero when a consumer no longer builds against the current tree.

**Why the framework's own gates are not enough.** `tom_uam` is kept on the
current level of tom_core on purpose: it is the one application-sized consumer
of the whole framework, which makes it the place a framework change that looks
local turns out not to be. `TomLoginException` gained a required `reason`, and
`tom_uam_server` stopped compiling -- seven call sites, found weeks later and
by accident, because no gate looked past `tom_ai/core`. Its generated
reflection had meanwhile gone stale against a removed annotation and a renamed
member, and three of its test files failed to load.

**What it checks, per consumer package:**

1. `pub get` first. A consumer's package config is gitignored, per-machine
   state; analyzing whatever it happens to hold reports a stale or damaged
   config as a framework defect, and two todos were filed on exactly that. The
   resolve makes the check about the source, not about this machine's history.
2. `analyze`, counting every diagnostic the package's own options report.
3. Every generated `*.reflection.dart`, analyzed by name for errors. The
   packages' options exclude generated files, so step 2 cannot see a
   reflection file that names a member the framework no longer has -- which
   is precisely how the stale one went unnoticed, and how the client's entry
   point came to reference constructors it cannot call. Naming the file is
   what makes the analyzer read it; a compile would do the same but cannot
   build a Flutter package.

**Where the consumers are.** Every package directly under
`<workspace>/tom_uam/`. A consumer tree that is missing is a fault, not a
skip: a check that silently measures nothing reads exactly like one that
passed.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path

from gate_report import report_faults

TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parent
#: `tom_ai/core` -> `tom_ai` -> the workspace root.
WORKSPACE = REPO_ROOT.parent.parent
CONSUMER_ROOTS = [WORKSPACE / "tom_uam"]

#: One diagnostic in `dart analyze --format=machine` output:
#: `SEVERITY|TYPE|CODE|FILE|LINE|COLUMN|LENGTH|MESSAGE`.
MACHINE_LINE = re.compile(r"^(ERROR|WARNING|INFO)\|")


def is_flutter(package: Path) -> bool:
    pubspec = (package / "pubspec.yaml").read_text(encoding="utf-8")
    return re.search(r"^\s*sdk:\s*flutter\s*$", pubspec, re.M) is not None


def consumers() -> tuple[list[Path], list[str]]:
    """The consumer packages, and a fault line for every root that is missing."""
    found: list[Path] = []
    missing: list[str] = []
    for root in CONSUMER_ROOTS:
        if not root.is_dir():
            missing.append(f"MISSING  {root}: the consumer tree is not checked out")
            continue
        found += sorted(p.parent for p in root.glob("*/pubspec.yaml"))
    return found, missing


def run(command: list[str], cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True)


def check(package: Path) -> list[str]:
    tool = "flutter" if is_flutter(package) else "dart"
    name = f"{package.parent.name}/{package.name}"
    got = run([tool, "pub", "get"], package)
    if got.returncode != 0:
        tail = (got.stderr or got.stdout).strip().splitlines()[-1:]
        return [f"PUBGET   {name}: {' '.join(tail)}"]

    faults: list[str] = []
    analyzed = run(["dart", "analyze", "--format=machine"], package)
    for line in (analyzed.stdout + analyzed.stderr).splitlines():
        if MACHINE_LINE.match(line):
            severity, _, code, file, row, *_rest = line.split("|")
            message = line.split("|", 7)[-1]
            relative = Path(file).relative_to(package) if file.startswith(str(package)) else file
            faults.append(f"ANALYZE  {name}: {relative}:{row} {severity.lower()} {code} -- {message}")

    # Named explicitly, because the package's own `analysis_options.yaml`
    # excludes them from the directory run above -- and an excluded file that
    # names a member the framework no longer has is exactly the failure this
    # step exists for. Only errors count: a lint in generated code is nobody's
    # to fix, a compile error is the application not building.
    for generated in sorted(package.glob("**/*.reflection.dart")):
        if ".dart_tool" in generated.parts or "build" in generated.parts:
            continue
        relative = generated.relative_to(package)
        read = run(["dart", "analyze", "--format=machine", str(relative)], package)
        for line in (read.stdout + read.stderr).splitlines():
            if line.startswith("ERROR|"):
                _, _, code, _, row, *_rest = line.split("|")
                faults.append(f"GENERATED {name}: {relative}:{row} {code}")
    return faults


def main() -> int:
    if shutil.which("dart") is None:
        print("dart is not on PATH, so no consumer can be checked", file=sys.stderr)
        return 2
    packages, faults = consumers()
    for package in packages:
        faults += check(package)
    for fault in faults:
        print(fault)
    print(f"\n{len(packages)} consumer package(s) checked, {len(faults)} fault(s)")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main())
