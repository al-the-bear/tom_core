#!/usr/bin/env python3
"""Hold every runnable Flutter sample's README to the step its first run needs.

Run from anywhere::

    python3 tool/check_flutter_platform_step.py

Exits non-zero when a README tells its reader to ``flutter run`` a package that
cannot start on a clean checkout.

**What went wrong without it.** None of the seven Flutter samples under
``tom_core_samples/`` tracks a platform folder -- they carry their own source,
not generated scaffolding -- and every one of their READMEs said ``flutter
run``. Flutter refuses to run a project on a platform it has no folder for, so
the documented command failed before the first frame, for every reader, on
every sample.

The one-time repair is ``flutter create --empty --platforms=<platform> .``, and
``--empty`` is part of it rather than a detail: without it the command also
writes a counter-app ``test/widget_test.dart`` that pumps a ``MyApp`` none of
these packages has, so following the README would break the package's own
suite.

**Which packages are held.** A package is in scope when all four hold: its
``pubspec.yaml`` is tracked and depends on the Flutter SDK, it has a
``lib/main.dart``, its README says ``flutter run``, and git tracks no file
under any of its platform folders. The last condition is what leaves the two
harnesses (``tom_flutter_ui_test``, ``tom_flutter_form_test``) out: they commit
their platform folders, so ``flutter run`` works for them as documented. A
sample added tomorrow is in scope by the same test, with nothing to register.

Three faults are reported:

``STEP``
    The README never names ``flutter create --empty --platforms=<p> .``.
``ORDER``
    It does, but only after the first fenced ``flutter run``, so a reader
    following the page top to bottom meets the failing command first. Prose
    mentions (a TL;DR saying "Run ``flutter run``") are not held to this;
    code blocks are what gets copied.
``IGNORE``
    ``.gitignore`` does not list one of the entries the step writes -- the six
    platform folders and ``.metadata`` -- so following the README once leaves
    scaffolding to commit by accident.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from gate_report import report_faults
import gate_scope

REPO_ROOT = Path(__file__).resolve().parent.parent

PLATFORMS = ("android", "ios", "linux", "macos", "web", "windows")

#: What the step writes, as `.gitignore` lines.
GENERATED = (".metadata",) + tuple(f"{p}/" for p in PLATFORMS)

STEP = re.compile(r"flutter create --empty --platforms=\w+ \.")
ANY_CREATE = re.compile(r"flutter create\b")


def tracked_files() -> list[Path]:
    """Every tracked file of every root the gates read (gate_scope)."""
    return gate_scope.tracked_files()


def packages_in_scope(files: list[Path]) -> list[Path]:
    """Runnable Flutter packages that track no platform folder."""
    found: list[Path] = []
    names = [str(f) for f in files]
    for package in (f for f in files if f.name == "pubspec.yaml"):
        root = package.parent
        prefix = f"{root}/"
        if not re.search(r"^\s*sdk:\s*flutter\s*$", package.read_text(), re.M):
            continue
        if not (root / "lib" / "main.dart").is_file():
            continue
        readme = root / "README.md"
        if not readme.is_file() or "flutter run" not in readme.read_text():
            continue
        if any(f.startswith(tuple(f"{prefix}{p}/" for p in PLATFORMS))
               for f in names):
            continue
        found.append(root)
    return sorted(found)


def fenced_lines(text: str) -> list[tuple[int, str]]:
    """Every line inside a ``` fence, with its 1-based line number."""
    inside = False
    lines: list[tuple[int, str]] = []
    for number, line in enumerate(text.splitlines(), start=1):
        if line.lstrip().startswith("```"):
            inside = not inside
            continue
        if inside:
            lines.append((number, line))
    return lines


def check(root: Path) -> list[str]:
    name = gate_scope.rel(root)
    text = (root / "README.md").read_text(encoding="utf-8")
    faults: list[str] = []

    step_at = next(
        (n for n, line in enumerate(text.splitlines(), 1) if STEP.search(line)),
        None,
    )
    if step_at is None:
        faults.append(
            f"STEP   {name}/README.md names `flutter create` without "
            "`--empty`, which writes a counter-app test this package cannot "
            "compile" if ANY_CREATE.search(text) else
            f"STEP   {name}/README.md never names `flutter create --empty "
            "--platforms=<p> .`, so `flutter run` cannot start on a clean "
            "checkout")
    else:
        first_run = next(
            (n for n, line in fenced_lines(text) if "flutter run" in line),
            None,
        )
        if first_run is not None and first_run < step_at:
            faults.append(
                f"ORDER  {name}/README.md:{first_run} shows `flutter run` "
                f"before the platform step at line {step_at}")

    ignore = root / ".gitignore"
    listed = ({line.strip() for line in ignore.read_text().splitlines()}
              if ignore.is_file() else set())
    for entry in GENERATED:
        if entry not in listed:
            faults.append(f"IGNORE {name}/.gitignore does not list `{entry}`, "
                          "which the platform step writes")
    return faults


def main() -> int:
    packages = packages_in_scope(tracked_files())
    # A walk that finds nothing reports a clean tree, which is how a gate
    # stops measuring without anyone noticing.
    if not packages:
        print("no runnable Flutter package without platform folders was found",
              file=sys.stderr)
        return 2

    faults = [fault for root in packages for fault in check(root)]
    for fault in faults:
        print(fault)
    print(f"\n{len(packages)} runnable Flutter package(s) without platform "
          f"folders checked, {len(faults)} fault(s)")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main())
