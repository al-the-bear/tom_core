#!/usr/bin/env python3
"""Audit the hand-written measurements in the tom_core completion documents.

Run from anywhere::

    python3 tool/check_doc_inventories.py                 # audit every document
    python3 tool/check_doc_inventories.py tom_core_kernel # one project's documents
    python3 tool/check_doc_inventories.py --fix           # re-measure and rewrite

Exits non-zero when any measurement disagrees with the tree.

Two shapes are audited. Most documents open by naming the module's directory
and how much is in it -- ``N source files, M lines`` -- and then tabulate the
directory a file at a time::

    | File | Lines | Carries |
    | ---- | ----- | ------- |
    | `date_timestamp.dart` | 1184 | `TomTimezoned` and its three subclasses. |

A module with sub-folders maps them instead, counting the types in each::

    | Sub-folder | File | Family | Types |
    | --- | --- | --- | --- |
    | `animated/` | [`tom_animated.dart`](...) | `animated` | 20 |

Those numbers are measurements, and a measurement written by hand is correct
only until the next commit. They are worth keeping because they tell a reader
the shape of a module before they open it -- a two-file, 150-line module and a
nine-file, 4000-line one are read differently -- but nobody re-measures them
when a module changes, so without a check they decay silently into confident
misinformation, which is worse than having omitted them.

That is not hypothetical for the ``Types`` column: deleting two deprecated
button wrappers left the widgets map claiming 23 buttons where the sub-folder
had 21, and the claim survived a sweep that corrected the same census in six
other documents -- because a bare number in a table cell is invisible to a
scan that looks for a count beside a noun.

Five faults are reported:

``LINES``
    A tabulated file whose line count is not the file's line count. The common
    defect: the module was edited, the table was not.
``UNKNOWN``
    A tabulated file that is not in the directory -- renamed or deleted.
``ABSENT``
    A file in the directory that the table does not list. An inventory that
    silently drops a file misleads exactly as much as one with bad arithmetic.
``HEADER``
    The opening ``N source files, M lines`` claim, or the ``readme.md (K
    lines)`` aside beside it, disagreeing with the directory.
``COUNT``
    A sub-folder map row whose ``Types`` count is not the number of ``Tom``
    classes declared under that sub-folder, or a sub-folder present in the
    module and missing from the map.

``--fix`` repairs ``LINES``, ``HEADER`` and ``COUNT`` by writing the
measurement back, so keeping the numbers true costs one command rather than a
manual pass. It never touches ``UNKNOWN`` or ``ABSENT``, nor a missing map
row: adding or retiring a row means writing the sentence that says what the
file or folder carries, and only a reader of it can do that.

The type count mirrors ``declarationPattern`` in
``tom_flutter_ui/test/widgets/widget_census.dart``, which answers the same
question on the Dart side for the package's own suites. A gate written in
Python cannot call it, so the pattern is stated twice; changing either one
means changing both, and the totals they produce should always agree.

The documents live in the ``_ai`` layer, beside the quest that produced them,
while the tree they describe lives here -- hence the reach across the two
repositories. That split is why this check has to be deliberate: nothing about
editing a module brings its completion document into view.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DOCS_ROOT = REPO_ROOT.parent.parent / "_ai" / "quests" / "tom_core" / "completion"

# The module directory, as the documents name it: a backticked path that starts
# at a project and reaches into its source tree. Taken from the first mention,
# which is the "On disk at ..." opening; later mentions point at neighbours.
MODULE_PATH = re.compile(r"`(tom_\w+/lib/src/[\w/]+?)/?`")

TABLE_HEADER = re.compile(r"^\|\s*File\s*\|\s*Lines\s*\|")
TABLE_ROW = re.compile(r"^\|\s*`([^`]+)`\s*\|\s*(\d+)\s*\|", re.M)

# A sub-folder map row: a backticked folder, then any cells, then the count as
# the last one. The folder is required to end in `/` so that a `| Type | Wraps |`
# row -- the other four-column table in these documents -- cannot match.
MAP_HEADER = re.compile(r"^\|\s*Sub-folder\s*\|.*\|\s*Types\s*\|")
MAP_ROW = re.compile(r"^\|\s*`([\w/]+)/`\s*\|.*\|\s*(\d+)\s*\|\s*$", re.M)

# A public `Tom` class declaration. Mirrors `declarationPattern` in
# tom_flutter_ui/test/widgets/widget_census.dart -- see the module docstring.
DECLARATION = re.compile(
    r"^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|mixin\s+)*"
    r"class\s+(Tom\w+)(?:<[^>]*>)?\s*[^{]*\{",
    re.M,
)


def declared_types(folder: Path) -> set[str]:
    """Every `Tom` class declared under `folder`, recursively.

    Recursive because a sub-folder may nest one -- `containers/` holds `acl/`,
    and the map counts the pair as one entry.
    """
    names: set[str] = set()
    for source in sorted(folder.rglob("*.dart")):
        text = source.read_text(encoding="utf-8", errors="replace")
        names |= {m.group(1) for m in DECLARATION.finditer(text)}
    return names

# Both claims allow `\s+` between their words rather than a single space: the
# documents are hard-wrapped, so either one routinely straddles a line break.
HEADER_CLAIM = re.compile(r"(\d+)\s+source\s+files?(?:,|\s+\()\s+([\d,]+)\s+lines")
README_CLAIM = re.compile(r"`readme\.md`\s+\((\d+)\s+lines\)")


def line_count(path: Path) -> int:
    """Count lines the way ``wc -l`` does -- the tool the numbers came from."""
    return path.read_text(encoding="utf-8", errors="replace").count("\n")


def rewrite_groups(match: re.Match[str], values: dict[int, str]) -> tuple[int, int, str]:
    """Return the span of `match` and its text with numbered groups replaced.

    Groups are substituted back to front so that replacing one does not shift
    the offsets of the next.
    """
    text = match.group(0)
    start = match.start()
    for group in sorted(values, reverse=True):
        head = match.start(group) - start
        tail = match.end(group) - start
        text = text[:head] + values[group] + text[tail:]
    return match.start(), match.end(), text


class Report:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.faults: list[str] = []
        self.edits: list[tuple[int, int, str]] = []

    @property
    def clean(self) -> bool:
        return not self.faults

    def render(self) -> str:
        rel = self.path.relative_to(DOCS_ROOT)
        return "\n".join([str(rel), *(f"    {f}" for f in self.faults)])

    def apply(self) -> None:
        """Write the pending measurements back, last edit first."""
        text = self.path.read_text(encoding="utf-8")
        for start, end, replacement in sorted(self.edits, reverse=True):
            text = text[:start] + replacement + text[end:]
        self.path.write_text(text, encoding="utf-8")


def audit(path: Path) -> Report | None:
    """Return a Report, or None if the document measures nothing.

    Two independent audits, either of which may find nothing to say: a
    document carries a file inventory, or a sub-folder map, or neither.
    """
    text = path.read_text(encoding="utf-8", errors="replace")

    module_match = MODULE_PATH.search(text)
    if module_match is None:
        return None
    module = REPO_ROOT / module_match.group(1)
    if not module.is_dir():
        return None

    report = Report(path)
    measured = audit_file_inventory(text, module, report)
    measured |= audit_subfolder_map(text, module, report)
    return report if measured else None


def audit_subfolder_map(text: str, module: Path, report: Report) -> bool:
    """Check each map row's type count against the sub-folder it names.

    Returns whether the document has a map at all.
    """
    rows: dict[str, re.Match[str]] = {}
    in_table = False
    position = 0
    for line in text.splitlines(keepends=True):
        if MAP_HEADER.match(line):
            in_table = True
        elif in_table and not line.startswith("|"):
            in_table = False
        elif in_table:
            row = MAP_ROW.match(text, position)
            if row:
                rows[row.group(1)] = row
        position += len(line)
    if not rows:
        return False

    for name, match in sorted(rows.items()):
        folder = module / name
        if not folder.is_dir():
            report.faults.append(f"COUNT    `{name}/` is not in {module.name}/")
            continue
        actual = len(declared_types(folder))
        claimed = int(match.group(2))
        if actual != claimed:
            report.faults.append(
                f"COUNT    `{name}/` says {claimed} types, has {actual}"
            )
            report.edits.append(rewrite_groups(match, {2: str(actual)}))

    for folder in sorted(p for p in module.iterdir() if p.is_dir()):
        if folder.name not in rows:
            report.faults.append(
                f"COUNT    `{folder.name}/` is on disk, not in the map"
            )
    return True


def audit_file_inventory(text: str, module: Path, report: Report) -> bool:
    """Check the `| File | Lines |` table and the header claims beside it.

    Returns whether the document has such a table at all.
    """
    # Rows are recognised only between a `| File | Lines |` header and the end
    # of its table, so a backticked filename in some unrelated table elsewhere
    # in the document is not mistaken for part of the inventory.
    # Rows are matched against the whole text at the line's own offset, so the
    # match carries a span `--fix` can write through.
    rows: dict[str, re.Match[str]] = {}
    in_table = False
    position = 0
    for line in text.splitlines(keepends=True):
        if TABLE_HEADER.match(line):
            in_table = True
        elif in_table and not line.startswith("|"):
            in_table = False
        elif in_table:
            row = TABLE_ROW.match(text, position)
            if row:
                rows[row.group(1)] = row
        position += len(line)
    if not rows:
        return False

    on_disk = {p.name: p for p in sorted(module.iterdir()) if p.is_file()}

    for name, match in sorted(rows.items()):
        actual = on_disk.get(name)
        if actual is None:
            report.faults.append(f"UNKNOWN  `{name}` is not in {module.name}/")
            continue
        measured = line_count(actual)
        claimed = int(match.group(2))
        if measured != claimed:
            report.faults.append(f"LINES    `{name}` says {claimed}, is {measured}")
            report.edits.append(rewrite_groups(match, {2: str(measured)}))

    for name in on_disk:
        if name not in rows:
            report.faults.append(f"ABSENT   `{name}` is on disk, not in the table")

    dart = [p for name, p in on_disk.items() if name.endswith(".dart")]
    header = HEADER_CLAIM.search(text)
    if header:
        count, total = int(header.group(1)), int(header.group(2).replace(",", ""))
        measured = sum(line_count(p) for p in dart)
        if count != len(dart) or total != measured:
            report.faults.append(
                f"HEADER   says {count} source files, {total} lines; "
                f"is {len(dart)}, {measured}"
            )
            report.edits.append(
                rewrite_groups(header, {1: str(len(dart)), 2: str(measured)})
            )

    readme = README_CLAIM.search(text)
    if readme and "readme.md" in on_disk:
        measured = line_count(on_disk["readme.md"])
        if int(readme.group(1)) != measured:
            report.faults.append(
                f"HEADER   says readme.md is {readme.group(1)} lines; is {measured}"
            )
            report.edits.append(rewrite_groups(readme, {1: str(measured)}))

    return True


def main(argv: list[str]) -> int:
    arguments = argv[1:]
    fix = "--fix" in arguments
    arguments = [a for a in arguments if a != "--fix"]

    if not DOCS_ROOT.is_dir():
        print(f"completion documents not found at {DOCS_ROOT}", file=sys.stderr)
        return 2

    prefix = arguments[0] if arguments else ""
    documents = sorted(p for p in DOCS_ROOT.glob("*.md") if p.name.startswith(prefix))
    reports = [r for r in (audit(p) for p in documents) if r is not None]

    # A checker that quietly stops finding measurements reports a clean tree,
    # which is the one way this kind of audit fails without anyone noticing.
    if not reports:
        print(f"no measurements found under {DOCS_ROOT}", file=sys.stderr)
        return 2

    defective = [r for r in reports if not r.clean]
    for report in defective:
        print(report.render())
        if fix:
            report.apply()

    total = sum(len(r.faults) for r in defective)
    remaining = sum(len(r.faults) - len(r.edits) for r in defective)
    print(
        f"\n{len(reports)} documents audited, "
        f"{len(defective)} defective, {total} faults"
    )
    if fix:
        print(f"rewrote {total - remaining}; {remaining} need a hand")
        return 1 if remaining else 0
    return 1 if defective else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
