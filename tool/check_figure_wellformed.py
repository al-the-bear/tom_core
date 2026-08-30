#!/usr/bin/env python3
"""Find SVG figures that are not well-formed XML, so they render as nothing.

Run from anywhere::

    python3 tool/check_figure_wellformed.py                  # whole repo
    python3 tool/check_figure_wellformed.py tom_core_samples # one subtree

Exits non-zero when a figure does not parse, so it can gate a build.

SVG is an XML dialect, and a document that is not well-formed is not a document.
A conforming parser does not render it partially or best-effort -- it stops. So
the failure mode of this fault is a figure that is simply *absent* from the
rendered page, with a broken-image placeholder where the diagram was.

**Why this needs a gate.** ``advanced_09_grade_data_path.svg`` was not
well-formed for four commits. Its opening description contained ``--`` inside
an XML comment, which the XML specification forbids outright ("the string '--'
MUST NOT occur within comments"), and no part of the workflow noticed:

- The file is an asset. Nothing compiles it, no test opens it, and neither
  ``dart analyze`` nor any checker in this suite parsed it.
- The fault is invisible in review. A ``--`` in an English sentence, used as a
  dash, is exactly what a careful writer types; the other eight figures reach
  for an em dash instead, and only this one did not.
- It is invisible in the diff of the commit that *introduced* it, and equally
  invisible in the two later commits that edited the same comment and left it.

The fault is also self-concealing at the reading end. Someone opening the
Markdown that embeds the figure sees a missing image and reasonably concludes
the path is wrong or the file is not checked out -- not that the file is present,
correct in every visual respect, and rejected by the parser over two characters
in a comment nobody reads.

**Cost.** The population is nine figures and the rule currently fires zero
times, so switching it on adds no triage burden -- the same trade
``check_source_citations.py`` documents. The check is total for the fault it
names: well-formedness is decidable, so unlike a heuristic there is no class of
broken figure it quietly passes.

What it deliberately does *not* do is validate against the SVG schema or check
that the figure draws anything sensible. Those need judgement; this needs a
parser, and the parser is already in the standard library.
"""

from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

SKIP_DIRS = {".dart_tool", "build", ".git", "node_modules", "__pycache__"}


def figures(root: Path) -> list[Path]:
    return [
        path
        for path in sorted(root.rglob("*.svg"))
        if not SKIP_DIRS & set(path.parts)
    ]


def main(argv: list[str]) -> int:
    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    found = figures(root)
    broken: list[tuple[Path, str]] = []

    for path in found:
        try:
            ET.parse(path)
        except ET.ParseError as error:
            broken.append((path, str(error)))
        except OSError as error:
            broken.append((path, f"unreadable: {error}"))

    for path, error in broken:
        rel = path.relative_to(REPO_ROOT)
        print(f"{rel}: not well-formed XML, so it renders as nothing -- {error}")
        if "--" in path.read_text(encoding="utf-8", errors="replace"):
            print(
                "    check for `--` inside an <!-- --> comment; XML forbids it "
                "and the other figures use an em dash"
            )

    print()
    print(f"figures checked  : {len(found)}")
    print(f"not well-formed  : {len(broken)}")
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
