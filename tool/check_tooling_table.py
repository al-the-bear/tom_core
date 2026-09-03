#!/usr/bin/env python3
"""Pin the README's repository-tooling table to the contents of ``tool/``.

Run from anywhere::

    python3 tool/check_tooling_table.py

Exits non-zero when the table and the directory disagree, so it can gate a
build.

**The fault.** ``README.md`` § "Repository tooling" is an inventory: a table of
every tool in ``tool/``, followed by one prose section per gate explaining what
it catches. Both halves are maintained by hand, and adding a script does not
touch either. So a gate lands, is wired into ``check_gates.py`` by glob, runs on
every build -- and is documented nowhere. A contributor reading the README to
learn what the repository checks gets a confident, incomplete answer, and the
undocumented gate is the one most likely to be deleted as unused, because
nothing in the tree points at it.

**Why a gate and not a habit.** This has already re-opened once. Two scripts
(``check_kernel_bridge.py``, ``check_section_numbers.py``) each ran undocumented
long enough to be noticed and written up -- and by the time they were, both had
been added incidentally by later commits while a *third*,
``check_unimplemented_claims.py``, had slipped in unnoticed to take their place.
The backlog was never the problem; the drift is, and it is silent in exactly the
way the rest of this suite exists to catch. Nobody who reviewed the commit that
added the script made a mistake: the omission is in a file the commit did not
touch.

**What is checked.** Three questions, counted separately so that one going quiet
cannot be masked by another staying noisy:

1. Every ``tool/*.py`` on disk is named by a table row.
2. Every ``tool/*.py`` a row names is on disk -- the reverse drift, a row left
   behind by a deleted or renamed script.
3. Every ``check_*.py`` has an invocation block (``python3 tool/<name>.py``) in
   the section's prose. ``gate_report.py`` deliberately has none: it is the
   contract a gate implements, not a gate to run, and its row describes it
   fully.

**What it deliberately does not check.** Whether a row's summary is *accurate*,
or whether a prose section says anything useful. Both need judgement; presence
does not. This is the same line ``check_doc_inventories.py`` and
``check_test_inventories.py`` draw -- they audit that a document claiming to
inventory a directory still matches it, and leave the prose to a reader.

**Falsification.** Delete a row and the script it named is reported under (1);
rename a script without touching the table and it is reported under (1) and its
old row under (2); delete a prose block and its gate is reported under (3). The
guards below cover the failure that would matter most -- reporting a clean tree
by looking at nothing -- so a moved heading, a reformatted table or a relocated
``tool/`` directory fails loudly rather than passing silently.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent
TOOL_DIR = REPO_ROOT / "tool"
README = REPO_ROOT / "README.md"

SECTION = "## Repository tooling"

# A row names its tool as a link: | [`tool/check_x.py`](tool/check_x.py) | ... |
ROW = re.compile(r"^\|\s*\[`tool/([A-Za-z0-9_]+\.py)`\]", re.MULTILINE)
# A prose section opens with a shell invocation of the tool it describes.
INVOCATION = re.compile(r"^python3 tool/([A-Za-z0-9_]+\.py)", re.MULTILINE)


def tooling_section(text: str) -> str | None:
    """Return the text of the tooling section, or None if it is not there."""
    if SECTION not in text:
        return None
    body = text.split(SECTION, 1)[1]
    return body.split("\n## ", 1)[0]


def main(argv: list[str]) -> int:
    if argv:
        print("usage: check_tooling_table.py  (no arguments)", file=sys.stderr)
        return 2

    if not README.exists():
        print(f"no README at {README} -- wrong path?", file=sys.stderr)
        return 2

    section = tooling_section(README.read_text(encoding="utf-8"))
    if section is None:
        print(
            f"no `{SECTION}` heading in {README.name} -- renamed? "
            "Refusing to report a clean table by reading nothing.",
            file=sys.stderr,
        )
        return 2

    on_disk = {path.name for path in TOOL_DIR.glob("*.py")}
    if not on_disk:
        print(f"no *.py under {TOOL_DIR} -- wrong path?", file=sys.stderr)
        return 2

    listed = set(ROW.findall(section))
    if not listed:
        print(
            "the tooling section lists no tools -- the table's shape has "
            "changed. Refusing to report parity against an empty table.",
            file=sys.stderr,
        )
        return 2

    invoked = set(INVOCATION.findall(section))
    gates = {name for name in on_disk if name.startswith("check_")}

    unlisted = sorted(on_disk - listed)
    stale = sorted(listed - on_disk)
    undocumented = sorted(gates - invoked)

    for name in unlisted:
        print(f"tool/{name}: on disk, but no row in the README tooling table")
    for name in stale:
        print(f"tool/{name}: named by a table row, but no such script")
    for name in undocumented:
        print(f"tool/{name}: a gate, but no prose section in the README invokes it")

    faults = len(unlisted) + len(stale) + len(undocumented)

    print()
    print(f"tools on disk        : {len(on_disk)}")
    print(f"rows in the table    : {len(listed)}")
    print(f"gates on disk        : {len(gates)}")
    print(f"missing a table row  : {len(unlisted)}")
    print(f"rows without a script: {len(stale)}")
    print(f"gates without prose  : {len(undocumented)}")
    return report_faults(faults)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
