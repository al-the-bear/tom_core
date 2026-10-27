#!/usr/bin/env python3
"""Hold a README's stated version to its pubspec, and forbid a test count.

Run from anywhere::

    python3 tool/check_readme_status.py                  # every package
    python3 tool/check_readme_status.py tom_core_server  # one package
    python3 tool/check_readme_status.py --self-test      # check the checker

Exits non-zero when a `## Status` block states a version its `pubspec.yaml`
does not, or states a test count at all, so it can gate a build.

**Two rules, and they point opposite ways on purpose.**

The version is *kept and enforced*. It is the one number in the block a reader
acts on — it tells them which release the document describes — and a wrong one
actively misleads rather than merely disappointing. It is also free to check:
one file, one line, no test run. Two of the five packages carrying a Status
block were wrong when this landed, `tom_core_kernel` claiming 1.1.1 against a
pubspec at 1.1.16.

The test count is *forbidden*. A count is a claim nothing checks, and this
repository's whole position is that an unchecked invariant is one that breaks:
`api_reference_coverage_test.dart` exists because "five modules shipped with a
guide and no API summary" proved it. The counts in `tom_core_server`'s block had
drifted to less than half the truth (1726 claimed against 3491 actual), were
corrected in place, and had drifted again within days — 95 suites claimed
against 103, 20 `db`-tagged against 24 — because every added test is a README
edit nobody makes.

Enforcing the count instead was considered and rejected. It is mechanically
possible: run the suite, compare. But it turns every added test into a required
README edit, and a doc test failing on an unrelated commit is friction that gets
the test deleted rather than the document updated. The count also carries almost
no information — nobody chooses a dependency on 3491 tests rather than 1726 —
whereas what a `db` tag gates is operational and does not drift. So the block
describes the suite and states no size.

**Anti-vacuity.** `main` exits 2 when the walk finds no Status block at all.
`--self-test` perturbs a real README in each direction — a wrong version, and a
count put back — and requires this checker to object to each.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from gate_report import report_faults
import gate_scope

REPO_ROOT = Path(__file__).resolve().parent.parent

#: The Status section: its heading to the next `##`, or to the end.
STATUS = re.compile(r"\n## Status\n(.*?)(?=\n## |\Z)", re.S)

#: The version a Status block states, in either spelling the corpus uses:
#: a `- **Version:** 1.2.3` bullet, or prose `Version **1.2.3**,`.
CLAIMED_VERSION = re.compile(
    r"\*\*Version:\*\*\s*([0-9]+(?:\.[0-9]+)+)|Version\s+\*\*([0-9]+(?:\.[0-9]+)+)\*\*"
)

#: A test count. Any number of two digits or more immediately qualified as
#: tests or suites — the shape every drifted claim took.
#:
#: Two digits rather than one because a one-digit count is almost always part of
#: a sentence about something else ("one of the 3 guards"), and the claim being
#: forbidden is the precise-looking total.
COUNT = re.compile(r"\b[0-9][0-9,]+\s+(?:test cases|tests?|suites?)\b")

#: The version a pubspec declares.
PUBSPEC_VERSION = re.compile(r"^version:\s*(\S+)", re.M)


def status_blocks(subtree: str | None) -> list[tuple[Path, str]]:
    """Every `README.md` with a `## Status` section, and that section's text."""
    found: list[tuple[Path, str]] = []
    for readme in gate_scope.glob_all("*/README.md"):
        if subtree is not None and readme.parent.name != subtree:
            continue
        block = STATUS.search(readme.read_text(encoding="utf8"))
        if block is not None:
            found.append((readme, block.group(1)))
    return found


def faults_in(readme: Path, status: str) -> list[str]:
    """The faults [status] carries, reported against [readme]."""
    where = gate_scope.rel(readme)
    faults: list[str] = []

    pubspec = readme.parent / "pubspec.yaml"
    declared = None
    if pubspec.is_file():
        match = PUBSPEC_VERSION.search(pubspec.read_text(encoding="utf8"))
        declared = None if match is None else match.group(1)

    for match in CLAIMED_VERSION.finditer(status):
        claimed = match.group(1) or match.group(2)
        if declared is not None and claimed != declared:
            faults.append(
                f"{where}  says version {claimed}; pubspec.yaml says {declared}"
            )

    for match in COUNT.finditer(status):
        faults.append(
            f"{where}  states a test count ({match.group(0).strip()}) — describe "
            "the suite instead; nothing checks a number here"
        )
    return faults


def self_test() -> int:
    """Perturb a real Status block in each direction; require an objection."""
    readme = REPO_ROOT / "tom_core_server" / "README.md"
    original = readme.read_text(encoding="utf8")
    try:
        readme.write_text(
            original.replace("- **Version:** 1.3.0", "- **Version:** 9.9.9", 1),
            encoding="utf8",
        )
        block = STATUS.search(readme.read_text(encoding="utf8"))
        if not any(
            "pubspec.yaml says" in fault for fault in faults_in(readme, block.group(1))
        ):
            print("self-test: a wrong version was not reported", file=sys.stderr)
            return 2

        readme.write_text(
            original.replace(
                "- **Tests:** run with", "- **Tests:** 3633 tests, run with", 1
            ),
            encoding="utf8",
        )
        block = STATUS.search(readme.read_text(encoding="utf8"))
        if not any(
            "states a test count" in fault
            for fault in faults_in(readme, block.group(1))
        ):
            print("self-test: a restored count was not reported", file=sys.stderr)
            return 2
    finally:
        readme.write_text(original, encoding="utf8")

    block = STATUS.search(readme.read_text(encoding="utf8"))
    if faults_in(readme, block.group(1)):
        print("self-test: the restored README is not clean", file=sys.stderr)
        return 2
    print("self-test: passed")
    return 0


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()
    subtree = argv[0] if argv and not argv[0].startswith("-") else None

    blocks = status_blocks(subtree)
    if not blocks:
        print(
            "no README carries a `## Status` block — the checker has stopped "
            "reading rather than the tree being clean",
            file=sys.stderr,
        )
        return 2

    faults = [
        fault for readme, status in blocks for fault in faults_in(readme, status)
    ]
    for fault in faults:
        print(fault)

    print(f"\nStatus blocks read       : {len(blocks)}")
    print(f"blocks with a fault      : {len({f.split()[0] for f in faults})}")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
