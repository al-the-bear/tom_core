#!/usr/bin/env python3
"""Find documentation that calls a shipped `Tom*` type unimplemented.

Run from anywhere::

    python3 tool/check_unimplemented_claims.py                 # whole repo
    python3 tool/check_unimplemented_claims.py tom_flutter_ui  # one subtree

Exits non-zero when a document denies the existence of something in `lib/`, so
it can gate a build.

**The fault.** A planning table is written before the work, listing what is to
be built with an `Implemented` column reading `No`. The work then happens, and
nothing brings the writer back to the column. In `tom_flutter_ui` that table sat
for months saying `Implemented: No` for eleven widgets, nine of which ship and
seven of which have their own section in `doc/custom.md` — and one row denied a
widget the *same document* had already recorded as wrapped, three hundred lines
higher up.

**Why this decays and other claims do not.** Most documentation faults are a
sentence that was always wrong. This one is a sentence that was *right when
written*, which is worse in two ways: nobody who reviewed it made a mistake, and
the moment it turned false left no trace in the diff of either file. Building
`TomEmptyState` does not touch the document that says `TomEmptyState` does not
exist. There is no edit to review, so review cannot catch it — only re-checking
can, which is what this file is.

**Why the neighbouring gates miss it.** `check_dartdoc_refs` and
`check_consumer_claims` both ask whether a name *resolves*; every name in these
tables resolves, and the row about it is still false. `check_doc_kinds` reads
the cell beside a symbol, but only in tables whose second column is `Kind`, and
it asks what the symbol *is* rather than whether it is. Resolution, kind, and
existence are three different questions, and only the third one is checked here.

**What is checked, and the restrictions that keep it honest.**

A row is read as an existence claim only when all three hold:

1. Its table has a header cell naming an existence column — `Implemented`,
   `Ships`, `Exists`, `Built`, `Available` or `Wrapped`. `Status` is
   deliberately *not* in that set: a status column carries workflow states, and
   reading "No" there as "does not exist" invents a claim the writer did not
   make.
2. That cell's value opens with a denial (`No`, `Not implemented`, `Planned`,
   `TODO`, `❌`, …). Emphasis and backticks are stripped first, so
   ``**No — superseded**`` still reads as a denial, and the qualification after
   the dash is preserved in the report.
3. The row's first cell names at least one ``Tom*`` symbol **in backticks**.
   Prose mentions are not claims about a table row, and reading them as such
   produced the false positives that this restriction exists to prevent.

Only then is the symbol looked up, and only a *type* declaration counts — class,
enum, mixin, extension, typedef. A top-level function or getter that happens to
share the name is not what a row like this is about.

**`CHANGELOG.md` is excluded.** A changelog entry records what was true when it
was written; correcting it would be falsifying a record rather than repairing a
claim. Everything else is in scope — `doc/`, package READMEs, module readmes —
because a table of this shape decays the same way wherever it is kept.

**What a fault looks like.** The report names the document, the line, the symbol
and where it is declared, so the repair is a lookup rather than a search::

    doc/tom_ui_flutter_widgets.md
      573  `TomRadioGroup` claimed 'No' under 'Implemented'
           declared in tom_flutter_ui/lib/src/custom/tom_radio_group.dart

The declaration index is shared with `check_doc_kinds` rather than copied, so
the two gates cannot disagree about what a Dart declaration looks like.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

from check_doc_kinds import DECLARATION
from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent

#: Header labels whose column answers "does this exist?". `Status` is absent on
#: purpose -- see the module docstring.
EXISTENCE_HEADERS = {
    "implemented",
    "ships",
    "exists",
    "built",
    "available",
    "wrapped",
}

#: Openings that deny existence. Matched against the cell with emphasis and
#: backticks stripped, so `**No -- superseded**` is caught along with a bare
#: `No`. Anchored at the start: a cell reading "Yes, but not on web" denies
#: nothing.
DENIALS = re.compile(
    r"^(no\b|no$|none\b|not\b|never\b|planned\b|todo\b|pending\b"
    r"|unimplemented\b|missing\b|❌|:x:)",
    re.IGNORECASE,
)

#: A `Tom*` symbol written as a code span. The backticks are required -- see the
#: module docstring on why prose mentions are not claims.
TOM_SYMBOL = re.compile(r"`(Tom\w+)`")

#: A markdown table's header underline, `|---|:-:|---|`, which is what tells a
#: header row apart from any other row of pipes.
UNDERLINE = re.compile(r"^\|[\s:|-]+\|$")

#: Emphasis and code markers, removed before a cell is read as a verdict.
DECORATION = re.compile(r"[*_`]")


def cells(line: str) -> list[str]:
    """Split a markdown table row into its trimmed cells."""
    return [c.strip() for c in line.strip().strip("|").split("|")]


def index_types(root: Path) -> dict[str, Path]:
    """Map every public top-level *type* in `lib/` to the file declaring it.

    Only types, because a row claiming `TomFoo` is unimplemented is a claim
    about a class, enum, mixin, extension or typedef -- never about a top-level
    function that happens to be named the same.
    """
    declared: dict[str, Path] = {}
    for source in sorted(root.rglob("lib/**/*.dart")):
        try:
            text = source.read_text()
        except (OSError, UnicodeDecodeError):
            continue
        for line in text.split("\n"):
            match = DECLARATION.match(line)
            if match is None:
                continue
            name = match.group("name")
            if not name.startswith("_"):
                declared.setdefault(name, source)
    return declared


@dataclass
class Report:
    """One document's existence claims and the ones the source contradicts."""

    document: Path
    claims: int = 0
    faults: list[tuple[int, str, str, str, Path]] = field(default_factory=list)

    @property
    def clean(self) -> bool:
        return not self.faults

    def render(self) -> str:
        lines = [str(self.document.relative_to(REPO_ROOT))]
        for number, symbol, verdict, header, source in self.faults:
            lines.append(
                f"  {number:4d}  `{symbol}` claimed {verdict!r} under {header!r}"
            )
            lines.append(f"        declared in {source.relative_to(REPO_ROOT)}")
        return "\n".join(lines)


def audit(document: Path, declared: dict[str, Path]) -> Report | None:
    """Check one document, or return None when it holds no existence table."""
    try:
        text = document.read_text()
    except (OSError, UnicodeDecodeError):
        return None

    report = Report(document)
    lines = text.split("\n")
    # The index of the existence column in the table currently being read, or
    # None between tables. Reset on every blank line so a row can never be
    # scored against the header of a table that ended above it.
    column: int | None = None
    header_label = ""

    for number, line in enumerate(lines, start=1):
        stripped = line.strip()
        if not stripped.startswith("|"):
            column = None
            continue
        if UNDERLINE.match(stripped):
            continue

        row = cells(stripped)
        if column is None:
            for index, cell in enumerate(row):
                if DECORATION.sub("", cell).strip().lower() in EXISTENCE_HEADERS:
                    column, header_label = index, DECORATION.sub("", cell).strip()
                    break
            continue

        # A row shorter than the header cannot be scored against it; that is a
        # malformed table, which check_figure_wellformed owns.
        if column >= len(row) or not row:
            continue
        verdict = DECORATION.sub("", row[column]).strip()
        if not DENIALS.match(verdict):
            continue

        report.claims += 1
        for symbol in TOM_SYMBOL.findall(row[0]):
            source = declared.get(symbol)
            if source is not None:
                report.faults.append(
                    (number, symbol, verdict, header_label, source)
                )

    return report if report.claims else None


def main(argv: list[str]) -> int:
    prefix = argv[1] if len(argv) > 1 else ""

    declared = index_types(REPO_ROOT)
    # An empty index would let every claim pass, reporting a clean tree by
    # looking at nothing -- the one way this audit fails silently.
    if not declared:
        print(f"no declarations found under {REPO_ROOT}", file=sys.stderr)
        return 2

    documents = sorted(
        path
        for path in REPO_ROOT.rglob("*.md")
        if path.name != "CHANGELOG.md"
        and not any(part.startswith(".") for part in path.parts)
        and str(path.relative_to(REPO_ROOT)).startswith(prefix)
    )
    reports = [r for r in (audit(p, declared) for p in documents) if r is not None]

    # Likewise: a checker that stops recognising the tables reports success.
    if not reports:
        print(f"no existence tables found under {REPO_ROOT}", file=sys.stderr)
        return 2

    defective = [r for r in reports if not r.clean]
    for report in defective:
        print(report.render())

    faults = sum(len(r.faults) for r in defective)
    print(
        f"\ndocuments with claims  : {len(reports)}\n"
        f"existence claims read  : {sum(r.claims for r in reports)}\n"
        f"documents defective    : {len(defective)}\n"
        f"claims the source denies: {faults}"
    )
    return report_faults(faults)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
