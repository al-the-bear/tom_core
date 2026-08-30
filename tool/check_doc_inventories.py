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

A package document maps its whole tree instead, in a fenced block that labels
each barrel with how much it re-exports::

    advanced_app_client/
      lib/
        app/
          app.dart                       barrel — 4 exports

and opens by sizing the package as a whole::

    `tom_core_samples/advanced_todo_domain/` — 23 files, of which 17 are Dart:
    14 under `lib/` (619 lines, all hand-written) and 3 under `test/`, ...

Seven faults are reported:

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
``BARREL``
    A layout-block ``barrel — N exports`` label whose number is not the count
    of ``export`` directives in the file it labels.
``PKGINV``
    An atom of a package document's opening inventory -- the package's file
    count, its Dart-file count, how many of those sit under ``lib/``, ``bin/``
    or ``test/``, and the hand-written line totals -- disagreeing with the
    package.

``PKGINV`` exists because the opening inventory was the one measurement in
these documents that nothing checked. ``HEADER`` looks for the literal words
``N source files``, which a *module* document writes and a *package* document
never does, so every ``advanced_*`` package opened with a hand-maintained
census that no gate could see. It drifted exactly as the docstring above
predicts: ``advanced_todo_domain`` claimed 24 files when it had 23, and its
line total went stale the next time anyone edited a dartdoc -- a one-line
comment change silently falsifies the paragraph a reader trusts most, because
it is the first one they read.

The atoms are deliberately narrow. Only a directory carrying a ``pubspec.yaml``
is treated as a package, and a number counts only where it sits immediately
beside the noun it measures (``— 23 files``, ``of which 17 are Dart``,
``14 under `lib/```). Prose that merely contains a number near a noun -- ``14
hand-written library files``, ``10 test suites and 1 shared test fixture`` --
is left alone. That is what keeps the check free of false positives across the
43 documents whose opening line it inspects while still covering the 8 it can
measure exactly; a wider pattern would flag the other 35 and be turned off.

``BARREL`` is the one measurement here that has twice hidden a defect rather
than merely gone stale. ``advanced_app_client``'s ``lib/app/app.dart`` was
labelled ``4 exports`` and had three: the missing fourth was
``session_two_factor_controller.dart``, a real file the same layout block
listed one line below and the document gave its own section, but which no
consumer of ``package:advanced_app_client/app/app.dart`` could name. The
number was right about what the barrel was *for* and wrong about what it
*was*, and only counting the directives tells the two apart. Three of the nine
labels in this set were wrong when the check was written.

``--fix`` repairs ``LINES``, ``HEADER``, ``COUNT``, ``BARREL`` and ``PKGINV``
by writing the measurement back, so keeping the numbers true costs one command
rather than a manual pass. It never touches ``UNKNOWN`` or ``ABSENT``, nor a
missing map row: adding or retiring a row means writing the sentence that says
what the file or folder carries, and only a reader of it can do that.

Note what ``--fix`` means for a ``BARREL`` fault: it makes the *document*
agree with the code, which is right when the label is stale and wrong when the
label is a symptom, as the case above was. The repair is always available and
never automatic -- read which of the two you have before running it.

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
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DOCS_ROOT = REPO_ROOT.parent.parent / "_ai" / "quests" / "tom_core" / "completion"

# The module directory, as the documents name it: a backticked path that starts
# at a project and reaches into its source tree. Taken from the first mention,
# which is the "On disk at ..." opening; later mentions point at neighbours.
MODULE_PATH = re.compile(r"`(tom_\w+/lib/src/[\w/]+?)/?`")

# A package document's "path on disk" line: the backticked package directory
# opening a paragraph, followed by the em dash that introduces its file count.
# Anchored at the line start so a mid-sentence mention of a neighbour package
# -- of which these documents have several -- cannot be taken for the subject.
PACKAGE_PATH = re.compile(r"^`(tom_\w+/[\w/]+?)/?`\s+—", re.M)

# The layout block: a ```text fence whose first line is the package directory.
LAYOUT_FENCE = re.compile(r"^```text\n(.*?)^```", re.M | re.S)

# A barrel label inside it. `entity barrel — 9 exports, no generated code` and
# `DTO barrel — 9 exports` both carry the same claim, so the word `barrel` is
# matched wherever it falls rather than required to start the label.
BARREL_LABEL = re.compile(r"\bbarrel\s+—\s+(\d+)\s+exports")

#: An `export` directive, counted the way the barrels are written -- one per
#: line, at the left margin. A `part` is not an export and is not counted.
EXPORT = re.compile(r"^export\s", re.M)

#: A number as these documents group it: digits, optionally split by a space or
#: a thin space every three (``4 337``). Kept as written when a figure is
#: rewritten, so ``--fix`` does not restyle the prose around it.
#:
#: It must begin and end on a digit. Letting the separator class lead would
#: allow the match to start on the space in front of the figure, and `--fix`
#: would overwrite that space along with the number -- turning
#: `20 hand-written, 4 337 lines` into `20 hand-written,4 337 lines`.
NUMBER = r"\d(?:[\d   ]*\d)?"

#: The package's own file count, taken only where it sits directly after the em
#: dash that opens the inventory. `— 14 hand-written library files` does not
#: match: the number must be the one immediately in front of `files`.
PKG_FILES = re.compile(r"—\s*(" + NUMBER + r")\s+files\b")
PKG_DART = re.compile(r"of\s+which\s+(" + NUMBER + r")\s+are\s+Dart\b")
#: `21 under `lib/``, `2 under `bin/``, `12 under `test/`` -- Dart files only.
PKG_UNDER = re.compile(r"(" + NUMBER + r")\s+under\s+`(lib|bin|test)/`")
#: A parenthetical qualifying an `under `lib/`` / `under `test/`` mention, which
#: is where the line totals and hand-written file counts live.
PKG_SEGMENT = re.compile(r"under\s+`(lib|test)/`[^()]*\(([^)]*)\)", re.S)
PKG_LINES = re.compile(r"(" + NUMBER + r")\s+(?:hand-written\s+)?lines")
#: `20 hand-written, 4 337 lines` -- a file count, not the line count beside it.
PKG_HAND = re.compile(r"(" + NUMBER + r")\s+hand-written(?!\s+lines)")

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

    Three independent audits, any of which may find nothing to say: a document
    carries a file inventory, a sub-folder map, a layout block, or none of
    them. The barrel audit runs first and on its own terms, because a package
    document has a layout block and no module directory to resolve -- the two
    shapes describe different things and neither implies the other.
    """
    text = path.read_text(encoding="utf-8", errors="replace")

    report = Report(path)
    measured = audit_barrel_exports(text, report)
    measured |= audit_package_inventory(text, report)

    module_match = MODULE_PATH.search(text)
    if module_match is not None:
        module = REPO_ROOT / module_match.group(1)
        if module.is_dir():
            measured |= audit_file_inventory(text, module, report)
            measured |= audit_subfolder_map(text, module, report)

    return report if measured else None


def layout_barrels(text: str, package: Path):
    """Yield `(path, match)` for every barrel label in a layout block.

    The block is an indented tree, so a file's directory is the chain of
    folder lines above it at smaller indents -- the same reading a person
    gives it. The root line names the package the tree is rooted at and is
    dropped, since `package` already points there.
    """
    for fence in LAYOUT_FENCE.finditer(text):
        body, offset = fence.group(1), fence.start(1)
        stack: list[tuple[int, str]] = []
        position = offset
        for line in body.splitlines(keepends=True):
            stripped = line.strip()
            indent = len(line) - len(line.lstrip())
            if stripped:
                while stack and stack[-1][0] >= indent:
                    stack.pop()
                name = stripped.split()[0]
                if name.endswith("/"):
                    stack.append((indent, name))
                else:
                    end = position + len(line)
                    label = BARREL_LABEL.search(text, position, end)
                    if label:
                        # `stack[1:]` drops the tree's root line.
                        folders = "".join(f for _, f in stack[1:])
                        yield package / (folders + name), label
            position += len(line)


def audit_barrel_exports(text: str, report: Report) -> bool:
    """Check each layout-block barrel label against the file's export count.

    Returns whether the document has a layout block with labels at all.
    """
    package_match = PACKAGE_PATH.search(text)
    if package_match is None:
        return False
    package = REPO_ROOT / package_match.group(1)
    if not package.is_dir():
        return False

    found = False
    for path, label in layout_barrels(text, package):
        found = True
        shown = path.relative_to(package)
        if not path.is_file():
            report.faults.append(
                f"BARREL   `{shown}` is not in {package.name}/"
            )
            continue
        source = path.read_text(encoding="utf-8", errors="replace")
        actual = len(EXPORT.findall(source))
        claimed = int(label.group(1))
        if actual != claimed:
            report.faults.append(
                f"BARREL   `{shown}` says {claimed} exports, has {actual}"
            )
            report.edits.append(rewrite_groups(label, {1: str(actual)}))
    return found


def tracked_files(package: Path) -> list[str] | None:
    """The package's git-tracked files, which is what the inventories count.

    ``git ls-files`` rather than a directory walk, because the counts are meant
    to describe the package as it is committed -- build output under
    ``.dart_tool`` and a scratch file are not part of its shape. Returns
    None when git cannot answer, so the audit stays silent rather than
    reporting every atom as wrong.
    """
    try:
        result = subprocess.run(
            ["git", "ls-files"],
            cwd=package,
            capture_output=True,
            text=True,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    return result.stdout.split()


def as_number(written: str) -> int:
    """Read a grouped figure (``4 337``) as an integer."""
    return int(re.sub(r"\D", "", written))


def like(written: str, value: int) -> str:
    """Render `value` in the grouping style `written` used.

    A document that writes ``4 337`` keeps its thin space when the figure is
    repaired; one that writes ``619`` stays bare. Without this, ``--fix`` would
    slowly normalise the prose to whatever the tool happened to prefer.
    """
    separator = next((c for c in written if not c.isdigit()), "")
    if not separator or len(str(value)) <= 3:
        return str(value)
    digits = str(value)
    head = len(digits) % 3 or 3
    rest = [digits[i:i + 3] for i in range(head, len(digits), 3)]
    return separator.join([digits[:head], *rest])


def audit_package_inventory(text: str, report: Report) -> bool:
    """Check the opening inventory of a package document against the package.

    Only the atoms whose meaning is unambiguous are measured -- see ``PKGINV``
    in the module docstring for why the patterns are as tight as they are.
    Returns whether this document has a package inventory at all.
    """
    package_match = PACKAGE_PATH.search(text)
    if package_match is None:
        return False
    package = REPO_ROOT / package_match.group(1)
    if not (package / "pubspec.yaml").is_file():
        return False

    # The inventory is the paragraph the package path opens, and nothing after
    # it: later paragraphs describe the same package in prose full of numbers.
    # The patterns are bounded to that span rather than run against a slice, so
    # every match offset is absolute and can be handed straight to `--fix`.
    start = package_match.start()
    blank = text.find("\n\n", start)
    end = len(text) if blank < 0 else blank

    file_claim = PKG_FILES.search(text, start, end)
    dart_claim = PKG_DART.search(text, start, end)
    if file_claim is None and dart_claim is None:
        return False

    files = tracked_files(package)
    if files is None:
        return False
    dart = [f for f in files if f.endswith(".dart")]

    def under(folder: str) -> list[str]:
        return [f for f in dart if f.startswith(f"{folder}/")]

    def handwritten(paths: list[str]) -> list[str]:
        return [p for p in paths if not p.endswith(".reflection.dart")]

    # (claim, measured, what the number counts)
    claims: list[tuple[re.Match[str], int, str]] = []
    if file_claim is not None:
        claims.append((file_claim, len(files), "files"))
    if dart_claim is not None:
        claims.append((dart_claim, len(dart), "Dart files"))
    for match in PKG_UNDER.finditer(text, start, end):
        folder = match.group(2)
        noun = f"Dart files under {folder}/"
        claims.append((match, len(under(folder)), noun))
    for segment in PKG_SEGMENT.finditer(text, start, end):
        folder = segment.group(1)
        hand = handwritten(under(folder))
        body, tail = segment.start(2), segment.end(2)
        for match in PKG_LINES.finditer(text, body, tail):
            total = sum(line_count(package / p) for p in hand)
            claims.append((match, total, f"hand-written lines under {folder}/"))
        for match in PKG_HAND.finditer(text, body, tail):
            claims.append(
                (match, len(hand), f"hand-written files under {folder}/")
            )

    for match, measured, noun in claims:
        written = match.group(1)
        if as_number(written) == measured:
            continue
        report.faults.append(
            f"PKGINV   says {written.strip()} {noun}; is {measured}"
        )
        report.edits.append(rewrite_groups(match, {1: like(written, measured)}))
    return True


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
