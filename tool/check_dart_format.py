#!/usr/bin/env python3
"""Hold every Dart file under `tom_ai/core` to `dart format`.

Run from anywhere::

    python3 tool/check_dart_format.py            # every package
    python3 tool/check_dart_format.py --fix      # format them instead
    python3 tool/check_dart_format.py --self-test

**Why a gate and not a habit.** Formatting drift is invisible to the check
everybody actually runs. ``dart analyze`` says nothing about line wrapping, so a
file can be analyzer-clean, test-green, reviewed and merged while being
unformatted — and nothing says so until somebody runs the formatter and watches
it rewrite files they did not touch. By then the cost is not the whitespace, it
is that every subsequent change drags an arbitrary slice of the pending reformat
into its diff: a 173-line change arrives as a 6,000-line one and stops being
reviewable.

This repository has paid that bill four times. ``tom_core_kernel`` and
``tom_core_server`` each reformatted wholesale and then drifted again days
later, which is why each grew its own ``test/formatting_test.dart``.
``tom_flutter_ui`` reformatted 245 files in one commit. And on the day this gate
landed, ``tom_flutter_form_test`` had four drifted test files that nothing in
the repository could see — a package with no guard, which is 21 of the 23 here.

**Why one gate rather than a third copy of that test.** The two in-suite guards
are per package, and each new package would need its own. Nothing about the rule
is per package, so the copies would differ only in which files they walk — which
is the part that goes stale. The two that exist stay: they run under their own
package's ``testkit :test``, which is where a developer working in that package
gets the signal. This one covers the other 21, and runs in the gate suite.

**Scope is a walk, not a list.** Every ``.dart`` file under [REPO_ROOT], found
by walking it. A checker told where to look stops covering the tree the moment a
file appears somewhere else, and reports nothing while it does — which is
exactly how the drift it guards against accumulates.

Three things are left out, each for a stated reason:

``.`` directories
    ``.dart_tool`` holds package copies this repository does not author and
    ``.git`` holds no Dart at all, so descending costs more than the walk.
``tool/ztmp``
    The scratch tree ``check_doc_dart_blocks.py`` extracts every ```dart block
    into. Those files are written by that checker from prose, so faulting them
    would report a documentation snippet's wrapping as a package's defect. The
    same directory is skipped by ``check_comments_read_as_is.py``.
[GENERATED]
    A generator that emits unformatted code is the generator's defect, and
    failing here would point the reader at the wrong package.

**If this fails on a machine where nothing was edited**, the SDK's formatter has
changed its output. Reformat and commit that as its own whitespace-only change.
Do not relax this gate to accommodate it: a formatter change nobody reformats
for is precisely how the first drift accumulated.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from gate_report import report_faults
import gate_scope

REPO_ROOT = Path(__file__).resolve().parent.parent

#: Machine-written files, which this repository does not author.
GENERATED = (".reflection.dart", ".versioner.dart", ".g.dart", ".freezed.dart")

#: Directories whose contents are not this repository's to format.
SKIPPED = {"ztmp", "build", "coverage"}

#: Packages the walk must reach, whatever else it finds.
#:
#: Not the scope — the scope is every Dart file — but landmarks. The check below
#: is one subprocess over a file list, and an empty list formats nothing and
#: passes, reporting a clean tree it never opened. A walk that misses one of
#: these has gone wrong rather than found a smaller repository.
LANDMARKS = ["tom_core_kernel", "tom_core_server", "tom_flutter_ui"]

#: The floor the walk has to clear, stated loosely on purpose: the count is
#: supposed to move, and a test that must be edited whenever the thing it
#: measures grows correctly is one that will be edited without being read.
MINIMUM_FILES = 1000


def dart_files() -> list[Path]:
    """Every Dart file the repository authors, sorted."""
    found: list[Path] = []

    def walk(directory: Path) -> None:
        for entry in sorted(directory.iterdir()):
            name = entry.name
            if name.startswith(".") or name in SKIPPED:
                continue
            if entry.is_symlink():
                continue
            if entry.is_dir():
                walk(entry)
            elif entry.suffix == ".dart" and not name.endswith(GENERATED):
                found.append(entry)

    for root in gate_scope.ROOTS:
        walk(root)
    return found


def unformatted(files: list[Path], fix: bool = False) -> list[str]:
    """The files `dart format` rewrites, or would, repository-relative.

    Paths go in relative and come back relative, because an absolute one in a
    fault line is this machine's layout rather than the repository's.

    The two modes print different words for the same event — ``Changed`` when
    only reporting, ``Formatted`` when writing — so both are read. Reading one
    would make ``--fix`` silently claim it repaired nothing.
    """
    if not files:
        return []
    args = ["format"] if fix else ["format", "--output=none"]
    touched = []
    # One run per root, from that root, so a path in and out is relative to
    # the root that holds it (see gate_scope).
    for root in gate_scope.ROOTS:
        mine = [f for f in files if gate_scope.root_of(f) == root]
        if not mine:
            continue
        relative = [str(gate_scope.rel(f)) for f in mine]
        result = subprocess.run(
            ["dart", *args, *relative],
            capture_output=True,
            text=True,
            cwd=root,
        )
        for line in result.stdout.splitlines():
            for prefix in ("Changed ", "Formatted "):
                if line.startswith(prefix) and line.rstrip().endswith(".dart"):
                    touched.append(line[len(prefix) :].strip())
    return sorted(touched)


# -----------------------------------------------------------------------------
# The self-test: perturb a file, require the gate to object
# -----------------------------------------------------------------------------


#: A file whose formatting the gate claims to read.
PROBE = REPO_ROOT / "tom_core_kernel" / "lib" / "tom_core_kernel.dart"


def self_test() -> int:
    failures = 0
    files = dart_files()

    if PROBE not in files:
        print(f"  FAIL  the walk does not reach {PROBE.name}; the probe moved")
        return report_faults(1)
    print(f"  ok    the walk reaches the probe, among {len(files)} files")

    original = PROBE.read_text()
    try:
        # An indented top-level directive: the smallest edit the formatter
        # undoes, and one no compiler or analyzer would report. Deliberately in
        # code rather than in a comment — the formatter leaves prose alone, so a
        # perturbed doc comment would prove nothing.
        PROBE.write_text(original.replace("\nexport ", "\n  export ", 1))
        if PROBE.read_text() == original:
            print("  FAIL  the perturbation changed nothing; the probe moved")
            failures += 1
        else:
            found = unformatted([PROBE])
            if found:
                print("  ok    an unformatted file is reported")
            else:
                print("  FAIL  an unformatted file was not reported")
                failures += 1
    finally:
        PROBE.write_text(original)

    if unformatted([PROBE]):
        print("  FAIL  the probe is still reported after being restored")
        failures += 1
    else:
        print("  ok    a formatted file is not reported")

    print(f"\n{3 - failures} of 3 checks passed")
    return report_faults(failures)


def main(argv: list[str]) -> int:
    if subprocess.run(["which", "dart"], capture_output=True).returncode != 0:
        print("dart is not on PATH, so no file can be checked", file=sys.stderr)
        return 2

    if "--self-test" in argv:
        return self_test()

    fix = "--fix" in argv
    files = dart_files()

    # A package is a directory with a pubspec, so `tom_core_samples`'s fifteen
    # are counted as fifteen rather than as the directory holding them.
    packages = {
        parent
        for f in files
        for parent in f.parents
        if (parent / "pubspec.yaml").is_file()
    }
    reached = {p.name for p in packages}
    missing = [name for name in LANDMARKS if name not in reached]
    if missing or len(files) < MINIMUM_FILES:
        print(
            f"the walk found {len(files)} files across {len(packages)} packages"
            + (f", missing {', '.join(missing)}" if missing else "")
            + " — it has gone wrong rather than found a smaller repository",
            file=sys.stderr,
        )
        return 2

    changed = unformatted(files, fix=fix)

    for path in changed:
        print(f"{'formatted' if fix else 'unformatted'}  {path}")

    label = "formatted" if fix else "unformatted"
    print(f"\nfiles walked             : {len(files)}")
    print(f"packages covered         : {len(packages)}")
    print(f"{label:<25}: {len(changed)}")
    if fix:
        print("\nrun again without --fix to confirm")
        return report_faults(0)
    return report_faults(len(changed))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
