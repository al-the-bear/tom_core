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
"""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import NamedTuple

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

# The document's inventory lives between these two markers, so that test files
# named elsewhere in the prose (a worked example, a cross-reference) are not
# mistaken for inventory entries.
BEGIN = "<!-- test-inventory:begin -->"
END = "<!-- test-inventory:end -->"

FILENAME = re.compile(r"`([A-Za-z0-9_]+_test\.dart)`")


def documented(doc: Path, files_column: int) -> tuple[list[str], str | None]:
    """Names in the inventory table's files column, duplicates preserved."""
    text = doc.read_text(encoding="utf-8")
    if BEGIN not in text or END not in text:
        return [], f"no {BEGIN} / {END} block"
    block = text.split(BEGIN, 1)[1].split(END, 1)[0]

    names: list[str] = []
    for line in block.splitlines():
        if not line.lstrip().startswith("|"):
            continue
        cells = line.split("|")
        if len(cells) <= files_column:
            continue
        names.extend(FILENAME.findall(cells[files_column]))
    return names, None


def on_disk(test_dir: Path) -> list[str]:
    return sorted(p.name for p in test_dir.rglob("*_test.dart"))


def main() -> int:
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

    print()
    print(f"inventories audited : {len(INVENTORIES)}")
    print(f"test files checked  : {checked}")
    print(f"faults              : {faults}")
    return 1 if faults else 0


if __name__ == "__main__":
    sys.exit(main())
