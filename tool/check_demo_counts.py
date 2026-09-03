#!/usr/bin/env python3
"""Check that a document's demo counts match the demo app's source.

Run from anywhere::

    python3 tool/check_demo_counts.py

Exits non-zero when a registered document and `tom_flutter_ui_test/lib`
disagree about how many demos there are, so it can gate a build.

**Why this exists.** Three separate defects were filed against this one number.
A completion document claimed 55 demo screens and a gate over all 55 while its
own source-layout table said otherwise; a README said "27 widget showcases" two
lines above a table saying `demo_01...demo_28`; and the 1.0.0 changelog entry
claimed 27 ACL demos when the tab had listed 26 since before that entry was
written. Each was repaired by hand, and each repair restated a number that
nothing checks -- so the fourth was only a matter of time.

**The trap in every one of them is the same**, and it is not carelessness: a
demo can be *counted* two ways that are both correct. `demo_21_resource_
resolution.dart` is one screen listed on two tabs, so the app declares 59 screens
and offers 60 tiles. `lib/widget_demos/` holds 28 screens but its tab lists 27,
because `demo_28_authorization.dart` is surfaced from Authorization/Resources.
A bare count is therefore ambiguous *even when it is right*, and a reader who
recomputes it from a different starting point concludes the document is wrong.
So this gate checks both numbers side by side and forces a document to say which
it means.

**What a screen is.** A top-level class whose name ends in ``Demo``, declared
under one of the three demo folders. That is the app's own convention and it is
exact: the four support files in `lib/acl_demos/` (the barrel, `demo_helpers`,
`expanding_box`, `resizable_box`) declare no such class, and `lib/forms_demos/`
packs five of them into two files -- which is why counting *files* gets the
forms row wrong and counting classes does not.

**What a tile is.** A ``screen:`` argument in a ``DemoTile`` in `lib/main.dart`,
attributed to the folder its class is declared in. Counting tiles rather than
trusting the tab structure means a demo that moves between tabs, or is listed
twice, changes the number here and fails the document that did not follow.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import NamedTuple

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent
APP = REPO_ROOT / "tom_flutter_ui_test"

# Document label -> the lib/ folder it counts. The label is what has to appear
# in the document's table, so it reads as prose rather than as a path.
GROUPS: dict[str, str] = {
    "ACL Demos": "acl_demos",
    "Widget Demos": "widget_demos",
    "Forms/Actions": "forms_demos",
}

# Documents carrying a counts table, relative to REPO_ROOT.
DOCUMENTS: list[str] = [
    "tom_flutter_ui_test/README.md",
]

BEGIN = "<!-- demo-counts:begin -->"
END = "<!-- demo-counts:end -->"

SCREEN_CLASS = re.compile(r"^class ([A-Za-z0-9_]*Demo)\b", re.MULTILINE)
TILE_SCREEN = re.compile(r"screen:\s*([A-Za-z0-9_]+)\s*\(")


class Counts(NamedTuple):
    screens: int
    tiles: int


def source_counts() -> tuple[dict[str, Counts], list[str]]:
    """Screens and tiles per group, read from lib/."""
    faults: list[str] = []

    def fault(message: str) -> None:
        # Printed at the point of detection, as the per-document faults are.
        # Collecting these silently made the two source-side branches exit
        # non-zero with nothing on stdout to say why.
        print(message)
        faults.append(message)

    # class name -> group, so a tile can be attributed to where it is declared.
    owner: dict[str, str] = {}
    screens: dict[str, int] = {}
    for label, folder in GROUPS.items():
        directory = APP / "lib" / folder
        if not directory.is_dir():
            fault(f"MISSING    lib/{folder} does not exist")
            screens[label] = 0
            continue
        names: set[str] = set()
        for path in sorted(directory.rglob("*.dart")):
            names.update(SCREEN_CLASS.findall(path.read_text(encoding="utf-8")))
        for name in names:
            owner[name] = label
        screens[label] = len(names)

    main = APP / "lib" / "main.dart"
    tiles: dict[str, int] = {label: 0 for label in GROUPS}
    for name in TILE_SCREEN.findall(main.read_text(encoding="utf-8")):
        label = owner.get(name)
        if label is None:
            fault(f"ORPHAN     main.dart offers {name} but no demo folder declares it")
            continue
        tiles[label] += 1

    return {label: Counts(screens[label], tiles[label]) for label in GROUPS}, faults


def documented(doc: Path) -> tuple[dict[str, Counts], str | None]:
    """Rows of the document's counts table: `| Group | Screens | Tiles |`."""
    text = doc.read_text(encoding="utf-8")
    if BEGIN not in text or END not in text:
        return {}, f"no {BEGIN} / {END} block"
    block = text.split(BEGIN, 1)[1].split(END, 1)[0]

    claimed: dict[str, Counts] = {}
    for line in block.splitlines():
        if not line.lstrip().startswith("|"):
            continue
        cells = [cell.strip() for cell in line.split("|")]
        if len(cells) < 5:
            continue
        label = cells[1].strip("*` ")
        if label not in GROUPS:
            continue
        try:
            claimed[label] = Counts(int(cells[2]), int(cells[3]))
        except ValueError:
            return {}, f"row {label!r} does not carry two integers"
    return claimed, None


def main() -> int:
    actual, faults = source_counts()

    for doc_rel in sorted(DOCUMENTS):
        doc = REPO_ROOT / doc_rel
        if not doc.exists():
            print(f"{doc_rel}: MISSING document")
            faults.append(doc_rel)
            continue

        claimed, error = documented(doc)
        if error:
            print(f"{doc_rel}: {error}")
            faults.append(doc_rel)
            continue

        for label in GROUPS:
            if label not in claimed:
                print(f"{doc_rel}: UNLISTED   {label} has no row")
                faults.append(label)
                continue
            if claimed[label].screens != actual[label].screens:
                print(
                    f"{doc_rel}: MISMATCH   {label} claims "
                    f"{claimed[label].screens} screens; lib declares "
                    f"{actual[label].screens}"
                )
                faults.append(label)
            if claimed[label].tiles != actual[label].tiles:
                print(
                    f"{doc_rel}: MISMATCH   {label} claims "
                    f"{claimed[label].tiles} tiles; main.dart offers "
                    f"{actual[label].tiles}"
                )
                faults.append(label)

    total = Counts(
        sum(c.screens for c in actual.values()), sum(c.tiles for c in actual.values())
    )
    print()
    print(f"demo screens declared : {total.screens}")
    print(f"demo tiles offered    : {total.tiles}")
    print(f"documents audited     : {len(DOCUMENTS)}")
    print(f"faults                : {len(faults)}")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main())
