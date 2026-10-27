#!/usr/bin/env python3
"""Hold the quest overview's package counts to the tree.

Run from anywhere::

    python3 tool/check_overview_inventory.py              # exit 1 on a drifted count
    python3 tool/check_overview_inventory.py --self-test  # the parser and the counter

`_ai/quests/tom_core/overview.tom_core.md` is the first document a session
reads, and it states each package's size twice: a **Package Inventory** table
(modules, source files, test files, examples, doc pages, API summaries) and a
**Structure** line per package under *Current State*. Both are exact facts about
the tracked tree, and both drifted for want of anyone recounting — the kernel's
test-file count was off by fifteen before this gate, too large to have been one
missed edit.

The counting rules are the ones written beside the table, and they are
implemented once, in `measure`:

- **modules** — directories under the package's module root;
- **source files** — `lib/**/*.dart` minus generated output;
- **test files** — `*_test.dart` anywhere under `test/`, the files the test
  runner discovers;
- **examples** — `example/**/*.dart` minus generated output;
- **doc pages** — `doc/**/*.md` outside `doc/api/`; **API summaries** — the
  `*.md` under `doc/api/`.

Everything is counted from `git ls-files`, so an untracked scratch file cannot
move a number. The *test counts* in parentheses on the Structure lines are what
a suite run reported; they are not files and are not checked here.

A cell holding `—` or `flat` claims nothing and is skipped. An overview that is
missing, or a table that parses to no rows, is NOT MEASURED — never clean.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

from gate_report import report_faults
import gate_scope

REPO_ROOT = Path(__file__).resolve().parent.parent
OVERVIEW = (REPO_ROOT.parent.parent / "_ai" / "quests" / "tom_core"
            / "overview.tom_core.md")

GENERATED = (".reflection.dart", ".versioner.dart", ".g.dart", ".b.dart")

#: Each package's module root, relative to the package.
MODULE_ROOTS = {
    "tom_core_kernel": "lib/src/tombase",
    "tom_core_server": "lib/src/tomserver",
    "tom_core_flutter": "lib/src/tomclient",
    "tom_flutter_ui": "lib/src",
    "tom_core_agentic": "lib/src",
    "tom_core_secrets": "lib/src",
}

COLUMNS = ("modules", "source", "tests", "examples", "docs", "api")

ROW = re.compile(r"^\| (tom_\w+) \|(.+)\|\s*$", re.M)

#: The Structure line's file counts, in its fixed order.
STRUCTURE = {
    "modules": re.compile(r"(\d+) modules under"),
    "source": re.compile(r"(\d+) source files"),
    "tests": re.compile(r"(\d+) test\s+files"),
    "examples": re.compile(r"(\d+)\s+example\s+files"),
    "docs": re.compile(r"(\d+)\s+documentation\s+pages"),
    "api": re.compile(r"(\d+)\s+API\s+summar(?:y|ies)"),
}


def tracked(package: str) -> list[str]:
    root = gate_scope.root_of(gate_scope.package_dir(package))
    out = subprocess.run(["git", "ls-files", "--", package], cwd=root,
                         capture_output=True, text=True, check=True).stdout
    prefix = f"{package}/"
    return [f[len(prefix):] for f in out.split() if f.startswith(prefix)]


def measure(package: str, files: list[str]) -> dict[str, int]:
    """The six counts for [package], from its tracked [files]."""
    def dart(f: str) -> bool:
        return f.endswith(".dart") and not f.endswith(GENERATED)

    counts = {
        "source": sum(1 for f in files if f.startswith("lib/") and dart(f)),
        "tests": sum(1 for f in files
                     if f.startswith("test/") and f.endswith("_test.dart")),
        "examples": sum(1 for f in files if f.startswith("example/") and dart(f)),
        "docs": sum(1 for f in files if f.startswith("doc/") and f.endswith(".md")
                    and not f.startswith("doc/api/")),
        "api": sum(1 for f in files
                   if f.startswith("doc/api/") and f.endswith(".md")),
    }
    root = MODULE_ROOTS.get(package)
    if root:
        prefix = f"{root}/"
        counts["modules"] = len({f[len(prefix):].split("/")[0] for f in files
                                 if f.startswith(prefix)
                                 and "/" in f[len(prefix):]})
    return counts


def table_claims(text: str) -> dict[str, dict[str, int]]:
    """`{package: {column: number}}` from the Package Inventory table."""
    section = text.split("## Package Inventory", 1)[-1].split("\n## ", 1)[0]
    claims: dict[str, dict[str, int]] = {}
    for package, cells in ROW.findall(section):
        values = [c.strip() for c in cells.split("|")]
        claims[package] = {
            column: int(value) for column, value in zip(COLUMNS, values)
            if value.isdigit()
        }
    return claims


def structure_claims(text: str) -> dict[str, dict[str, int]]:
    """`{package: {column: number}}` from each `### <package>` Structure line."""
    claims: dict[str, dict[str, int]] = {}
    for match in re.finditer(r"^### (tom_\w+)[^\n]*\n\n\*\*Structure:\*\*(.+?)\n\n",
                             text, re.M | re.S):
        package, body = match.group(1), " ".join(match.group(2).split())
        claims[package] = {column: int(m.group(1)) for column, pattern
                           in STRUCTURE.items() if (m := pattern.search(body))}
    return claims


def faults_for(where: str, claims, measured) -> list[str]:
    out = []
    for package, columns in sorted(claims.items()):
        actual = measured(package)
        for column, said in columns.items():
            if column in actual and actual[column] != said:
                out.append(f"{where:9} {package}: {column} says {said}, "
                           f"is {actual[column]}")
    return out


def self_test() -> int:
    files = ["lib/a.dart", "lib/a.reflection.dart", "lib/src/m1/x.dart",
             "lib/src/m2/y.dart", "test/a_test.dart", "test/sub/b_test.dart",
             "test/fixtures/f.dart", "example/e.dart", "doc/g.md",
             "doc/api/api_summary_m1.md"]
    got = measure("tom_flutter_ui", files)
    want = {"source": 3, "tests": 2, "examples": 1, "docs": 1, "api": 1,
            "modules": 2}
    failures = [] if got == want else [f"measure: {got} != {want}"]
    text = ("### tom_x ✅\n\n**Structure:** 2 modules under `lib/src/`, 3 source\n"
            "files, 2 test files (9 tests), 1 example files, 1 documentation\n"
            "pages in `doc/` plus 1 API summary.\n\n"
            "## Package Inventory\n\n| tom_x | 2 | 3 | 2 | — | 1 | 1 |\n")
    if table_claims(text) != {"tom_x": {"modules": 2, "source": 3, "tests": 2,
                                        "docs": 1, "api": 1}}:
        failures.append(f"table: {table_claims(text)}")
    if structure_claims(text) != {"tom_x": dict(want, examples=1)}:
        failures.append(f"structure: {structure_claims(text)}")
    bad = faults_for("TABLE", {"tom_x": {"tests": 3}}, lambda _: {"tests": 2})
    if len(bad) != 1:
        failures.append("a drifted count was not reported")
    for failure in failures:
        print(f"self-test: {failure}")
    if failures:
        return 1
    print("self-test: counting rules, both claim parsers and the comparison "
          "read as expected")
    return 0


def main(argv: list[str]) -> int:
    if argv == ["--self-test"]:
        return self_test()
    if not OVERVIEW.is_file():
        print(f"NOT MEASURED: {OVERVIEW} is missing", file=sys.stderr)
        return 2
    text = OVERVIEW.read_text(encoding="utf-8")
    table, structure = table_claims(text), structure_claims(text)
    if len(table) < 5 or len(structure) < 5:
        print("NOT MEASURED: the overview's table or Structure lines parsed to "
              f"{len(table)} / {len(structure)} packages", file=sys.stderr)
        return 2
    cache: dict[str, dict[str, int]] = {}

    def measured(package: str) -> dict[str, int]:
        if package not in cache:
            cache[package] = measure(package, tracked(package))
        return cache[package]

    faults = (faults_for("TABLE", table, measured)
              + faults_for("STRUCTURE", structure, measured))
    for fault in faults:
        print(fault)
    print()
    print(f"table rows checked       : {len(table)}")
    print(f"structure lines checked  : {len(structure)}")
    print(f"drifted counts           : {len(faults)}")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
