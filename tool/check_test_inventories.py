#!/usr/bin/env python3
"""Check that a document claiming to inventory a package's tests really does.

Run from anywhere::

    python3 tool/check_test_inventories.py

Exits non-zero when a registered document and the test runner disagree about
which files exist, so it can gate a build.

A completion document that lists a package's test files is making a claim with
two halves, and both can rot:

- **Every file on disk appears in the document.** When it does not, coverage
  that nobody wrote reads exactly like coverage that nobody documented, and
  the reader has no way to tell which.
- **Every file in the document exists on disk.** When it does not, the
  document vouches for a suite that cannot run.

The second half is the one that bites. ``tom_flutter_form_test``'s completion
document listed ``screenshot_tests.dart`` -- plural -- as one of its three
golden suites. ``flutter test`` discovers ``**_test.dart`` and matched nothing,
so the file never ran, and five committed golden baselines had no comparer at
all. The document was the *reason* nobody looked: it stated the baselines were
guarded, and it was the only place anyone would have checked.

**Why a glob is not good enough.** The same table described its other rows with
patterns (``demo_*_test.dart``, ``phase*_test.dart``). A pattern cannot be
wrong, which sounds like a virtue and is the defect: twelve files matched no
pattern in the table and were therefore invisible from inside the document,
including every regression guard in the package. A row that names its files can
be checked; a row that describes a shape cannot. So this gate requires literal
names, and rejects a table that leans on globs by simply not finding the files
they stand for.

**What it does not do.** It does not check that a file is filed under the right
kind, that the prose describing a kind is accurate, or that the tests inside a
file do what the row says. Those need judgement. This needs two sets and a
comparison, and set equality is decidable.

Registering another document is one entry in ``INVENTORIES``. The population is
deliberately small: a document earns an entry by claiming to be exhaustive, and
most documents that mention a test file in passing do not.

**Any document may be registered, not just a completion document.** A package
README that tells a reader what the suite covers is making the same claim as a
completion table and rots the same way, so it is registered the same way. That
is not hypothetical: this package's README once named five of the eleven suites
as though they were all of them, and the six it omitted were the whole of the
coverage a cleanup pass had just added. The repair for that had been to name no
files at all -- accurate, and useless to the reader, because "the suffix is the
whole rule" is only true of the *runner*, not of what the suite is for. A gated
list can be both specific and correct, so the README keeps one.

**A second, weaker claim: counts by kind.** Naming eleven files in a README is
cheap. Naming sixty-five is not -- it makes the README's largest section a wall
of filenames, and orientation is the only thing a README is for. So a document
may instead declare a *partition*: one row per kind with a number, plus the
total. That says nothing about which file is covered, and so cannot catch a
renamed suite the way the literal rule does. What it can catch is the fault that
motivates it -- a suite population that grows or shrinks while a document goes
on describing the old one -- and it catches it three ways at once, because the
numbers are held to the directory's own total, to each other, and to the kind
partition an exhaustive document already declares for the same directory. A
count claim therefore cannot be registered alone: it names the ``INVENTORIES``
entry it is checked against, and the labels have to match it exactly.

The two rules do not compete. The literal rule stays as strict as it was, and a
document that claims to be exhaustive is still held to that; the weaker one is
available only to a document that does not make the stronger claim in the first
place.
"""

from __future__ import annotations

import contextlib
import io
import re
import sys
from pathlib import Path
from typing import NamedTuple

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent
QUEST_COMPLETION = (
    REPO_ROOT.parent.parent / "_ai" / "quests" / "tom_core" / "completion"
)


class Inventory(NamedTuple):
    """A document, the test directory it claims to inventory, and where to look.

    ``doc`` is an absolute path so that a document anywhere in the workspace can
    be registered; ``tests`` is likewise absolute and reported relative to
    ``REPO_ROOT``.
    """

    doc: Path
    tests: Path
    files_column: int


# Only the *files* column of a table is the inventory. The other columns
# routinely name a file to say something specific about it ("...including
# validator behaviour (`form_validation_test.dart`)"), and reading those as
# inventory entries would report a duplicate for a file that is in fact filed
# exactly once. The narrower rule also frees the description column to be prose.
#
# The column is per-document because the two demo apps group their suites
# differently, and neither grouping is wrong. `tom_flutter_form_test` has 61
# suites and files them by kind, so its table is `| Kind | Files | ... |` and one
# row names many files. `tom_flutter_ui_test` has 11 and gives each its own row,
# so its table is `| Suite | What it asserts |` and the names are in column 1.
# Forcing the second into the first's shape would trade eleven specific
# sentences for four generic ones purely to satisfy this checker.
#
# `tom_flutter_ui_test` is inventoried twice on purpose -- once by its completion
# document and once by its README -- because the two are read by different people
# for different reasons, and a reader of one is not served by the accuracy of the
# other. Both are held to the same set equality against the same directory, so
# they cannot drift apart either.
INVENTORIES: dict[str, Inventory] = {
    "completion/tom_flutter_form_test_app_changes.md": Inventory(
        doc=QUEST_COMPLETION / "tom_flutter_form_test_app_changes.md",
        tests=REPO_ROOT / "tom_flutter_form_test" / "test",
        files_column=2,
    ),
    "completion/tom_flutter_ui_test_app_changes.md": Inventory(
        doc=QUEST_COMPLETION / "tom_flutter_ui_test_app_changes.md",
        tests=REPO_ROOT / "tom_flutter_ui_test" / "test",
        files_column=1,
    ),
    "tom_flutter_ui_test/README.md": Inventory(
        doc=REPO_ROOT / "tom_flutter_ui_test" / "README.md",
        tests=REPO_ROOT / "tom_flutter_ui_test" / "test",
        files_column=1,
    ),
}


class CountInventory(NamedTuple):
    """A document that summarises a suite by kind rather than naming its files.

    ``against`` is a key into ``INVENTORIES``: the exhaustive document whose
    kind partition this one mirrors. Both are then held to the same directory,
    so a count claim is checked against a list of real filenames rather than
    against another count.
    """

    doc: Path
    kind_column: int
    count_column: int
    against: str


COUNT_INVENTORIES: dict[str, CountInventory] = {
    "tom_flutter_form_test/README.md": CountInventory(
        doc=REPO_ROOT / "tom_flutter_form_test" / "README.md",
        kind_column=1,
        count_column=2,
        against="completion/tom_flutter_form_test_app_changes.md",
    ),
}

# The document's inventory lives between these two markers, so that test files
# named elsewhere in the prose (a worked example, a cross-reference) are not
# mistaken for inventory entries.
BEGIN = "<!-- test-inventory:begin -->"
END = "<!-- test-inventory:end -->"

COUNT_BEGIN = "<!-- test-inventory:counts-begin -->"
COUNT_END = "<!-- test-inventory:counts-end -->"

FILENAME = re.compile(r"`([A-Za-z0-9_]+_test\.dart)`")

# The total is inside the marked block and not merely near it, because a number
# a reader takes for the size of the suite is part of the same claim as the rows
# that partition it -- and an unmarked one is exactly the sentence that rots.
TOTAL = re.compile(r"\*\*(\d+)\*\* gating suites")

# An exhaustive row labels its kind with the size of that kind: `Unit tests (8)`.
# The parenthesised figure is the label a count claim mirrors, so it is checked
# against the names in the same row first -- otherwise the two documents could
# agree on a number that neither of them holds to the directory.
DECLARED = re.compile(r"^(.*?)\s*\((\d+)\)$")


def _block(doc: Path, begin: str, end: str) -> tuple[str | None, str | None]:
    """The text between two markers, or an error naming the missing pair."""
    text = doc.read_text(encoding="utf-8")
    if begin not in text or end not in text:
        return None, f"no {begin} / {end} block"
    return text.split(begin, 1)[1].split(end, 1)[0], None


def _is_separator(line: str) -> bool:
    """A `| --- | ---: |` rule line, which is what makes the row above a header."""
    cells = [cell.strip() for cell in line.split("|")[1:-1]]
    return bool(cells) and all(cell and set(cell) <= {"-", ":"} for cell in cells)


def _rows(block: str) -> list[list[str]]:
    """Data rows of every table in the block, as raw cell lists.

    A header is identified by the rule line under it rather than by position,
    so a block holding two tables drops both headers instead of reading the
    second one as data.
    """
    lines = [line for line in block.splitlines() if line.lstrip().startswith("|")]
    rows = []
    for index, line in enumerate(lines):
        if _is_separator(line):
            continue
        if index + 1 < len(lines) and _is_separator(lines[index + 1]):
            continue  # a header
        rows.append(line.split("|"))
    return rows


def documented(doc: Path, files_column: int) -> tuple[list[str], str | None]:
    """Names in the inventory table's files column, duplicates preserved."""
    block, error = _block(doc, BEGIN, END)
    if error:
        return [], error
    assert block is not None

    names: list[str] = []
    for line in block.splitlines():
        if not line.lstrip().startswith("|"):
            continue
        cells = line.split("|")
        if len(cells) <= files_column:
            continue
        names.extend(FILENAME.findall(cells[files_column]))
    return names, None


def partition(
    doc: Path, files_column: int
) -> tuple[list[tuple[str, int, int]], str | None]:
    """The kinds an exhaustive table declares: label, declared size, real size.

    The label is the kind cell with its parenthesised size removed, so that a
    count claim mirrors the words and the number separately and has to get both
    right. A row whose kind carries no `(n)` is skipped -- the one-file-per-row
    shape has nothing to partition.
    """
    block, error = _block(doc, BEGIN, END)
    if error:
        return [], error
    assert block is not None

    kinds: list[tuple[str, int, int]] = []
    for cells in _rows(block):
        if len(cells) <= files_column:
            continue
        declared = DECLARED.match(cells[files_column - 1].strip())
        if not declared:
            continue
        kinds.append(
            (
                declared.group(1).strip(),
                int(declared.group(2)),
                len(FILENAME.findall(cells[files_column])),
            )
        )
    return kinds, None


def counted(
    doc: Path, kind_column: int, count_column: int
) -> tuple[list[tuple[str, int]], int | None, str | None]:
    """The kinds and total a summarising table declares."""
    block, error = _block(doc, COUNT_BEGIN, COUNT_END)
    if error:
        return [], None, error
    assert block is not None

    total = TOTAL.search(block)

    kinds: list[tuple[str, int]] = []
    for cells in _rows(block):
        if len(cells) <= max(kind_column, count_column):
            continue
        figure = cells[count_column].strip()
        if not figure.isdigit():
            return [], None, f"row {cells[kind_column].strip()!r} has no count"
        kinds.append((cells[kind_column].strip(), int(figure)))
    return kinds, int(total.group(1)) if total else None, None


def on_disk(test_dir: Path) -> list[str]:
    return sorted(p.name for p in test_dir.rglob("*_test.dart"))


def _report() -> str:
    """Everything ``check()`` prints, so a self-test can read its verdict."""
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        check()
    return buffer.getvalue()


def self_test() -> int:
    """Perturb a real figure of each shape; require the matching objection.

    The literal rule is left alone -- it is verified by the incident that
    produced it, and a set comparison has no shape to get subtly wrong. The
    count rule is checked here because every one of its three comparisons can
    pass vacuously if a parser silently reads nothing, and a summary that is
    gated but unchecked is the exact failure it was built to prevent.
    """
    claim = COUNT_INVENTORIES["tom_flutter_form_test/README.md"]
    source = INVENTORIES[claim.against]
    papers = {
        path: path.read_text(encoding="utf-8")
        for path in (claim.doc, source.doc)
    }

    perturbations = [
        (claim.doc, "| Unit tests | 8 |", "| Unit tests | 7 |", "WRONG"),
        (claim.doc, "**65** gating suites", "**61** gating suites", "TOTAL"),
        (claim.doc, "| Smoke tests | 10 |", "| Smoke tesst | 10 |", "UNKNOWN"),
        (source.doc, "**65** gating suites", "**62** gating suites", "TOTAL"),
        (source.doc, "| Unit tests (8) |", "| Unit tests (9) |", "MISCOUNTED"),
    ]
    try:
        for paper, before, after, expected in perturbations:
            if papers[paper].count(before) != 1:
                print(
                    f"self-test: {before!r} is not in {paper.name} once",
                    file=sys.stderr,
                )
                return 2
            paper.write_text(papers[paper].replace(before, after, 1), encoding="utf-8")
            if expected not in _report():
                print(f"self-test: {after!r} was not reported", file=sys.stderr)
                return 2
            paper.write_text(papers[paper], encoding="utf-8")
    finally:
        for paper, text in papers.items():
            paper.write_text(text, encoding="utf-8")

    if "faults              : 0" not in _report():
        print("self-test: the restored documents are not clean", file=sys.stderr)
        return 2
    print(f"self-test: passed ({len(perturbations)} perturbations)")
    return 0


def check() -> int:
    faults = 0
    checked = 0

    for doc_name, inventory in sorted(INVENTORIES.items()):
        doc = inventory.doc
        test_dir = inventory.tests
        test_rel = test_dir.relative_to(REPO_ROOT)

        if not doc.exists():
            print(f"{doc_name}: MISSING document")
            faults += 1
            continue
        if not test_dir.is_dir():
            print(f"{doc_name}: MISSING test directory {test_rel}")
            faults += 1
            continue

        listed, error = documented(doc, inventory.files_column)
        if error:
            print(f"{doc_name}: {error}")
            faults += 1
            continue

        actual = on_disk(test_dir)
        checked += len(actual)

        seen: set[str] = set()
        for name in listed:
            if name in seen:
                print(f"{doc_name}: DUPLICATE  {name} is listed under two kinds")
                faults += 1
            seen.add(name)

        for name in sorted(set(actual) - seen):
            print(f"{doc_name}: UNLISTED   {test_rel}/{name} runs but is undocumented")
            faults += 1

        for name in sorted(seen - set(actual)):
            print(f"{doc_name}: PHANTOM    {name} is documented but not in {test_rel}")
            faults += 1

    for doc_name, claim in sorted(COUNT_INVENTORIES.items()):
        source = INVENTORIES[claim.against]
        test_rel = source.tests.relative_to(REPO_ROOT)

        if not claim.doc.exists():
            print(f"{doc_name}: MISSING document")
            faults += 1
            continue

        kinds, error = partition(source.doc, source.files_column)
        if error:
            print(f"{doc_name}: {claim.against}: {error}")
            faults += 1
            continue
        for label, declared, actual in kinds:
            if declared != actual:
                print(
                    f"{claim.against}: MISCOUNTED {label} says ({declared}) "
                    f"but the row names {actual} files"
                )
                faults += 1

        summarised, total, error = counted(
            claim.doc, claim.kind_column, claim.count_column
        )
        if error:
            print(f"{doc_name}: {error}")
            faults += 1
            continue

        # Keyed on the names actually in the row, never on the label's own
        # `(n)`, so a WRONG message can only ever quote a figure taken from
        # the directory. The label's figure has its own report above.
        expected = {label: real for label, _, real in kinds}
        claimed = dict(summarised)

        for label in sorted(set(claimed) - set(expected)):
            print(f"{doc_name}: UNKNOWN    kind {label!r} is not a kind of {test_rel}")
            faults += 1
        for label in sorted(set(expected) - set(claimed)):
            print(f"{doc_name}: OMITTED    kind {label!r} of {test_rel} is unmentioned")
            faults += 1
        for label in sorted(set(expected) & set(claimed)):
            if expected[label] != claimed[label]:
                print(
                    f"{doc_name}: WRONG      {label!r} says {claimed[label]}, "
                    f"{test_rel} has {expected[label]}"
                )
                faults += 1

        on_disk_total = len(on_disk(source.tests))

        # The exhaustive document has to state its own total in the same words,
        # because this one's rows mirror its partition: two documents that agree
        # with each other and not with the directory would otherwise both pass.
        # It is required here rather than of every registered document, since a
        # document that no summary leans on loses nothing by omitting the figure.
        source_total = TOTAL.search(source.doc.read_text(encoding="utf-8"))
        if source_total is None:
            print(f"{claim.against}: no '**n** gating suites' total to mirror")
            faults += 1
        elif int(source_total.group(1)) != on_disk_total:
            print(
                f"{claim.against}: TOTAL      says {source_total.group(1)} gating "
                f"suites, {test_rel} has {on_disk_total}"
            )
            faults += 1

        if total is None:
            print(f"{doc_name}: no '**n** gating suites' total in the block")
            faults += 1
        elif total != on_disk_total:
            print(
                f"{doc_name}: TOTAL      says {total} gating suites, "
                f"{test_rel} has {on_disk_total}"
            )
            faults += 1

        summed = sum(claimed.values())
        if summed != on_disk_total:
            print(
                f"{doc_name}: PARTITION  the kinds sum to {summed}, "
                f"{test_rel} has {on_disk_total}"
            )
            faults += 1

    print()
    print(f"inventories audited : {len(INVENTORIES)}")
    print(f"count claims audited: {len(COUNT_INVENTORIES)}")
    print(f"test files checked  : {checked}")
    print(f"faults              : {faults}")
    return report_faults(faults)


def main(argv: list[str]) -> int:
    return self_test() if "--self-test" in argv else check()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
