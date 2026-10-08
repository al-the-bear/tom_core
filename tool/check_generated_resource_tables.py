#!/usr/bin/env python3
"""Hold `tom_flutter_ui`'s generated resource tables to the installed Flutter SDK.

Run from anywhere::

    python3 tool/check_generated_resource_tables.py              # exit 1 on a stale table
    python3 tool/check_generated_resource_tables.py --self-test  # the gate's own test

Exit 0 when both tables match what their generators emit today, 1 when either
differs, 2 when no Flutter SDK can be found (NOT MEASURED -- never clean).

**What is checked.** `tom_flutter_ui/lib/src/resource_auth/tom_icons_generated.dart`
and `tom_colors_generated.dart` are written by `tool/generate_icons.dart` and
`tool/generate_colors.dart`, which read the Flutter SDK's own icon and colour
declarations. Both generators emit no timestamp and format their output, so a
regeneration reproduces the committed file byte for byte unless the SDK moved.
The table's header tests in `test/resource_auth/resource_auth_test.dart` hold a
header to the entries below it; only regenerating holds the entries to the SDK.

This gate regenerates both tables into a scratch directory -- the generators
write to `lib/src/resource_auth/` relative to their working directory, so they
are run with the scratch directory as that -- and compares each with the
committed file. The fault count is the number of differing lines, added plus
removed, so one more icon is one more fault rather than "the file differs".

**What a difference means.** A stale table is the SDK moving, which is
information rather than damage: an icon Flutter removed is a resource key that
no longer resolves. The remedy is to regenerate with the command each
generator's header names and to read the diff for removed keys before
committing it -- a decision this gate leaves to a person. It is baselined like
every gate, so a table knowingly left behind an SDK can be recorded with a
note rather than turning the suite red.

**Which SDK.** The Flutter SDK is located from `FLUTTER_ROOT`, then from the
`dart` the gate runner resolved (`dart_sdk.py`): a `dart` inside a Flutter
checkout has `packages/flutter` above it. A plain Dart SDK has no Flutter
sources, so on such a machine the gate refuses rather than guessing.
"""

from __future__ import annotations

import difflib
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from dart_sdk import dart_bin_directory
from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent
PACKAGE = REPO_ROOT / "tom_flutter_ui"
TABLE_DIR = Path("lib/src/resource_auth")
SCRATCH_ROOT = REPO_ROOT / "tool" / "ztmp"

#: Generator script (under the package) -> the table it writes (under TABLE_DIR).
TABLES = {
    "tool/generate_icons.dart": "tom_icons_generated.dart",
    "tool/generate_colors.dart": "tom_colors_generated.dart",
}

#: The SDK file both generators read first; its presence identifies a Flutter root.
FLUTTER_MARKER = Path("packages/flutter/lib/src/material/icons.dart")

CANNOT_RUN = 2


def flutter_root() -> Path | None:
    """The Flutter SDK the tables are judged against, or None."""
    candidates: list[Path] = []
    if os.environ.get("FLUTTER_ROOT"):
        candidates.append(Path(os.environ["FLUTTER_ROOT"]))
    dart_bin = dart_bin_directory()
    if dart_bin is not None:
        # `<flutter>/bin`, or `<flutter>/bin/cache/dart-sdk/bin`.
        candidates += [dart_bin.parent, *list(dart_bin.parents)[:4]]
    for candidate in candidates:
        if (candidate / FLUTTER_MARKER).is_file() and (candidate / "bin").is_dir():
            return candidate.resolve()
    return None


def regenerate(root: Path, into: Path) -> dict[str, str]:
    """Run both generators with [into] as their working directory.

    Returns `{table name: generated text}`. Raises RuntimeError when a
    generator fails, carrying what it printed.
    """
    (into / TABLE_DIR).mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    # The generators find the SDK through `which flutter`, then FLUTTER_ROOT;
    # putting this root first on PATH makes both answers the one judged here.
    env["PATH"] = str(root / "bin") + os.pathsep + env.get("PATH", "")
    env["FLUTTER_ROOT"] = str(root)
    dart = root / "bin" / ("dart.bat" if sys.platform == "win32" else "dart")
    out: dict[str, str] = {}
    for script, table in TABLES.items():
        run = subprocess.run([str(dart), str(PACKAGE / script)], cwd=into,
                             env=env, capture_output=True, text=True)
        generated = into / TABLE_DIR / table
        if run.returncode != 0 or not generated.is_file():
            raise RuntimeError(f"{script} failed (exit {run.returncode}): "
                               f"{(run.stdout + run.stderr).strip()[-400:]}")
        out[table] = generated.read_text(encoding="utf-8")
    return out


def differing_lines(committed: str, generated: str) -> list[str]:
    """The `-`/`+` lines of a diff from [committed] to [generated]."""
    return [line for line in difflib.unified_diff(
                committed.splitlines(), generated.splitlines(), lineterm="", n=0)
            if line[:1] in "+-" and not line.startswith(("+++", "---"))]


def judge(committed: dict[str, str], generated: dict[str, str]) -> dict[str, list[str]]:
    """`{table: differing lines}` for every table."""
    return {table: differing_lines(committed[table], generated[table])
            for table in TABLES.values()}


def scratch() -> Path:
    SCRATCH_ROOT.mkdir(parents=True, exist_ok=True)
    return Path(tempfile.mkdtemp(prefix="resource_tables_", dir=SCRATCH_ROOT))


def committed_tables() -> dict[str, str]:
    return {table: (PACKAGE / TABLE_DIR / table).read_text(encoding="utf-8")
            for table in TABLES.values()}


def measure(root: Path) -> dict[str, str]:
    directory = scratch()
    try:
        return regenerate(root, directory)
    finally:
        shutil.rmtree(directory, ignore_errors=True)


def self_test(root: Path) -> int:
    """Edit a committed table out from under its generator and require a fault."""
    failures: list[str] = []
    committed = committed_tables()
    generated = measure(root)
    for table, text in committed.items():
        lines = text.splitlines(keepends=True)
        # The last entry line: an edit somebody makes by hand, and one the
        # header tests cannot see because they only count what is there.
        entry = max(i for i, line in enumerate(lines) if "':" in line)
        edited = dict(committed)
        edited[table] = "".join(lines[:entry] + lines[entry + 1:])
        found = judge(edited, generated)[table]
        if len(found) != 1 or not found[0].startswith("+"):
            failures.append(f"{table}: a removed entry read as {found}")
    if any(judge(generated, generated).values()):
        failures.append("an unedited table was reported as differing")
    for failure in failures:
        print(f"self-test: {failure}")
    if failures:
        return 1
    print("self-test: an entry edited out of either table is detected against a "
          "real regeneration, and an unedited table is clean")
    return 0


def main(argv: list[str]) -> int:
    root = flutter_root()
    if root is None:
        print("NOT MEASURED: no Flutter SDK found (FLUTTER_ROOT, or a `dart` "
              "inside a Flutter checkout); the tables were not regenerated",
              file=sys.stderr)
        return CANNOT_RUN
    if argv == ["--self-test"]:
        return self_test(root)
    try:
        generated = measure(root)
    except RuntimeError as error:
        print(f"NOT MEASURED: {error}", file=sys.stderr)
        return CANNOT_RUN
    findings = judge(committed_tables(), generated)
    for table, lines in findings.items():
        if lines:
            print(f"STALE     tom_flutter_ui/{TABLE_DIR / table}: "
                  f"{len(lines)} line(s) differ from a regeneration")
            for line in lines[:20]:
                print(f"            {line}")
            if len(lines) > 20:
                print(f"            ... {len(lines) - 20} more")
    print()
    print(f"flutter sdk              : {root}")
    print(f"tables regenerated       : {len(findings)}")
    print(f"stale tables             : {sum(1 for v in findings.values() if v)}")
    if any(findings.values()):
        print("Regenerate in tom_flutter_ui with `dart run tool/generate_icons.dart` "
              "and `dart run tool/generate_colors.dart`, and read the diff for "
              "removed keys before committing it.")
    return report_faults(sum(len(v) for v in findings.values()))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
