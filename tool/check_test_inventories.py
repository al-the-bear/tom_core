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

Registering another package is one entry in ``INVENTORIES``. The population is
deliberately small: a document earns an entry by claiming to be exhaustive, and
most documents that mention a test file in passing do not.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
QUEST_COMPLETION = (
    REPO_ROOT.parent.parent / "_ai" / "quests" / "tom_core" / "completion"
)

# doc -> the test directory it claims to inventory, relative to REPO_ROOT.
INVENTORIES: dict[str, str] = {
    "tom_flutter_form_test_app_changes.md": "tom_flutter_form_test/test",
}

# The document's inventory lives between these two markers, so that test files
# named elsewhere in the prose (a worked example, a cross-reference) are not
# mistaken for inventory entries.
BEGIN = "<!-- test-inventory:begin -->"
END = "<!-- test-inventory:end -->"

# Within the block, only the *files* column of the table is the inventory. The
# description column routinely names a file to say something specific about it
# ("...including validator behaviour (`form_validation_test.dart`)"), and
# reading those as inventory entries would report a duplicate for a file that is
# in fact filed exactly once. The narrower rule also frees the description
# column to be prose.
FILES_COLUMN = 2

FILENAME = re.compile(r"`([A-Za-z0-9_]+_test\.dart)`")


def documented(doc: Path) -> tuple[list[str], str | None]:
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
        if len(cells) <= FILES_COLUMN:
            continue
        names.extend(FILENAME.findall(cells[FILES_COLUMN]))
    return names, None


def on_disk(test_dir: Path) -> list[str]:
    return sorted(p.name for p in test_dir.rglob("*_test.dart"))


def main() -> int:
    faults = 0
    checked = 0

    for doc_name, test_rel in sorted(INVENTORIES.items()):
        doc = QUEST_COMPLETION / doc_name
        test_dir = REPO_ROOT / test_rel

        if not doc.exists():
            print(f"{doc_name}: MISSING document")
            faults += 1
            continue
        if not test_dir.is_dir():
            print(f"{doc_name}: MISSING test directory {test_rel}")
            faults += 1
            continue

        listed, error = documented(doc)
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
