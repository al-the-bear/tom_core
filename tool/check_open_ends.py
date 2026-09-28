#!/usr/bin/env python3
"""Find completion documents that never say what is still open.

Run from anywhere::

    python3 tool/check_open_ends.py            # the report
    python3 tool/check_open_ends.py --quiet    # findings only

Exits non-zero per [gate_report.report_faults], so ``check_gates.py`` holds the
outstanding number to a baseline.

**What the section is.** ``completion/README.md`` requires every document to
close part 3 with a ``### What is still open`` subsection, and spells out why
it reads as a claim either way: present means the unit was assessed and this is
the result, absent means it was *not* assessed -- which is not the same as
nothing being open, and is the reading a later scan has to assume.

**Why a gate and not a sweep.** Writing the missing sections in one pass would
produce the exact artifact the requirement exists to prevent: a section per
document asserting an assessment that nobody performed. The section is written
when the unit is assessed. So the count is held instead -- a new document
cannot join the unassessed set, and each assessment moves the number down,
which the ratchet then requires be recorded.

**Two faults, and the second is the cheap evasion.**

``MISSING``
    No ``### What is still open`` heading anywhere in the document.

``EMPTY``
    The heading is there and carries nothing under it. An empty section is a
    legitimate *claim* -- "assessed, nothing open" -- but the contract asks for
    it to be written as one, with the date the assessment was made, because a
    bare heading and a forgotten heading look identical.

The index and the contract itself are not documents about a module and are
skipped by name.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent
DOCS_ROOT = REPO_ROOT.parent.parent / "_ai" / "quests" / "tom_core" / "completion"

#: The two files in the folder that describe the set rather than a module.
NOT_A_MODULE_DOCUMENT = {"README.md", "tom_core_completion_overview.md"}

#: The heading, matched at its own level. A ``##`` or ``####`` spelling would
#: read the same to a person and sit in the wrong place in the structure, so
#: the level is part of what is checked.
HEADING = re.compile(r"^### What is still open\s*$", re.M)

#: Where the section ends: the next heading of any level.
NEXT_HEADING = re.compile(r"^#{1,6}\s", re.M)


def section_body(text: str) -> str | None:
    """The prose under the heading, or ``None`` when there is no heading."""
    match = HEADING.search(text)
    if match is None:
        return None
    rest = text[match.end() :]
    following = NEXT_HEADING.search(rest)
    return rest[: following.start()] if following else rest


def documents() -> list[Path]:
    return sorted(
        p for p in DOCS_ROOT.glob("*.md") if p.name not in NOT_A_MODULE_DOCUMENT
    )


def main(argv: list[str]) -> int:
    quiet = "--quiet" in argv
    if not DOCS_ROOT.is_dir():
        print(f"completion documents not found at {DOCS_ROOT}", file=sys.stderr)
        return 2

    missing: list[str] = []
    empty: list[str] = []
    for doc in documents():
        body = section_body(doc.read_text(encoding="utf-8"))
        if body is None:
            missing.append(doc.name)
        elif not body.strip():
            empty.append(doc.name)

    for name in missing:
        print(f"MISSING {name}")
    for name in empty:
        print(f"EMPTY   {name}")

    if not quiet:
        total = len(documents())
        print()
        print(f"module documents          : {total}")
        print(f"  with an open-ends section: {total - len(missing)}")
        print(f"  missing the section      : {len(missing)}")
        print(f"  section present but empty: {len(empty)}")

    return report_faults(len(missing) + len(empty))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
