#!/usr/bin/env python3
"""Find source comments that cite a line number instead of naming a thing.

Run from anywhere::

    python3 tool/check_source_citations.py                  # whole repo
    python3 tool/check_source_citations.py tom_flutter_ui   # one subtree

Exits non-zero when a comment cites a line, so it can gate a build.

Two faults, the same mistake at two distances:

``SELF``
    A line citation with no file name, so it points into the file it is written
    in -- ``// Per the class contract (lines 13-17): only a `disabled` parent
    caps its subtree``. This is the most fragile cross-reference available.
    *Any* insertion above it moves the target, and the comment then describes
    whatever slid into those lines. It cannot go stale loudly: there is no
    dangling reference to detect, no name to fail to resolve, just a sentence
    that quietly starts pointing at the wrong paragraph.
``CROSS``
    The same thing with a file name -- ``// see tom_form.dart:214``. Rots on
    any edit to *that* file, with the added charm that the edit is somewhere
    else entirely, so nothing about making it brings this comment into view.

**Why a checker for something that happens once.** The population here is one
occurrence, now zero, and that is a deliberate choice rather than an oversight
-- the same one already made for ``check_consumer_claims.py``, which audits
five resolvable claims and is worth keeping. The case for a gate is not how
often a fault appears but whether it would be *noticed* if it reappeared, and
this one is invisible by construction: the comment still reads fluently, the
code still compiles, and the reader who follows the citation has no way to tell
that the lines moved. Rarity is the argument for automating it, not against.
A reviewer cannot be asked to remember a convention they meet once a year.

The cost side is what makes it worth doing: the rule fires zero times on the
current tree, so switching it on adds no triage burden at all. Contrast the
cross-library dartdoc rule declined earlier, at 353 violations of judgement,
and the "name every public type" rule declined at 519 -- both were rejected on
noise, not on principle.

**Naming the target is always available.** That is what makes this rule fair
rather than merely strict. Every line range in a Dart file sits inside
something with a name -- a class, a member, a library doc comment, a headed
list. The fix is never "delete the reference"; it is "say what you mean", and
the named form survives every edit that breaks the numbered one.

**Figures are checked too, and are the worst host of all.** The rule was
originally Dart-only, and ``advanced_09_grade_data_path.svg`` collected five
``CROSS`` citations in the blind spot -- three distinct ones, each written twice
because a figure carries its claims in both an XML comment and the ``<text>``
elements a reader actually sees. All three had rotted: one pointed a whole
layer away from the layer it named, one named a file at a path that no longer
existed, and one had the right start line and a stale end. That is the ``CROSS``
argument intensified rather than a new fault. A Dart comment at least sits in a
file somebody opens; a figure is an *asset*, so nothing compiles it, no test
reads it, and the editing session that moves the target contains no trace of the
reference at all. The stale number then goes on reading as authoritative,
because a number is the most confident thing a citation can say.

So the scan covers ``.svg``, and there it reads **every line**, not just the
comment: the citation a reader of the rendered figure sees is the drawn one, so
checking only the comment would miss the copy that matters most.

**Markdown is deliberately left out.** It is not an oversight and not a
follow-up. The same pattern occurs 173 times across 18 files of guide prose,
where a line citation in a paragraph of explanation is a normal and often useful
thing to write, and switching the rule on there would mean 173 judgement calls
on day one. That is the noise threshold this suite has twice declined to cross
(353 for the cross-library dartdoc rule, 519 for "name every public type"), and
the reason the figure case is different is arithmetic, not taste: nine files,
and after this change zero violations.

**What is deliberately not matched.** A citation needs syntactic evidence that
it *is* one: a plural range (``lines 13-17``), a parenthesis (``(line 12)``),
or a pointing word (``see line 12``). A bare singular ``line 2`` is left alone,
because ``a line 2 pixels wide`` is prose about geometry and reporting it would
teach people to distrust the rule. URLs are skipped whole -- a permalink into
another project pinned at a commit is a stable reference, not a fragile one.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

SKIP_DIRS = {".dart_tool", "build", ".git", "node_modules", "__pycache__"}
SKIP_SUFFIXES = (".reflection.dart", "_generated.dart", "_bridges.dart", ".g.dart")
SUFFIXES = (".dart", ".svg")

# A comment line, `//` or `///`, capturing the prose after the slashes.
COMMENT = re.compile(r"^\s*///?(?!/)(.*)$")
# A URL, blanked before matching: `.../blob/<sha>/a.dart#L42` is a pinned
# permalink into some other repository, which is exactly the stable form this
# check is asking for rather than an instance of the fault.
URL = re.compile(r"\bhttps?://\S+")

CROSS = re.compile(r"\b[\w/.]*\w\.dart\s*:\s*\d+")
SELF = re.compile(
    r"""
      \blines\s+\d+\s*[-–—]\s*\d+          # `lines 13-17` -- a range
    | \(\s*lines?\s+\d+                    # `(line 12` / `(lines 12-14`
    | \b(?:see|per|at|in|from|cf\.?)\s+lines?\s+\d+
    """,
    re.I | re.X,
)


def source_files(root: Path):
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.suffix not in SUFFIXES:
            continue
        if SKIP_DIRS & set(path.parts):
            continue
        if path.name.endswith(SKIP_SUFFIXES):
            continue
        yield path


def citable_lines(path: Path, text: str) -> list[tuple[int, str]]:
    """``(line number, the prose that could carry a citation)``.

    In Dart, only a comment can -- code is checked by the compiler. A figure has
    no code, so the whole file is prose, and the citation that reaches a reader
    is the one drawn in a `<text>` element rather than the one in the XML
    comment. Reading only the comment would check the copy nobody sees.
    """
    numbered = list(enumerate(text.split("\n"), start=1))
    if path.suffix == ".svg":
        return numbered
    return [
        (number, comment.group(1))
        for number, line in numbered
        if (comment := COMMENT.match(line))
    ]


def citations(path: Path, text: str) -> list[tuple[int, str, str]]:
    """``(line, fault, the citing prose)`` for each line citing a line."""
    found: list[tuple[int, str, str]] = []
    for number, raw in citable_lines(path, text):
        prose = URL.sub(" ", raw)
        if CROSS.search(prose):
            found.append((number, "CROSS", prose.strip()))
        elif SELF.search(prose):
            found.append((number, "SELF", prose.strip()))
    return found


def main(argv: list[str]) -> int:
    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    scanned = {".dart": 0, ".svg": 0}
    faults: list[tuple[Path, int, str, str]] = []
    for path in source_files(root):
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        scanned[path.suffix] += 1
        for number, fault, prose in citations(path, text):
            faults.append((path, number, fault, prose))

    if not sum(scanned.values()):
        # Distinguishing "clean" from "looked nowhere" has to be audible: a
        # report whose only failure mode is printing zeros is worse than none.
        print(f"scanned no files under {root} -- wrong path?", file=sys.stderr)
        return 2

    for path, number, fault, prose in faults:
        excerpt = prose if len(prose) <= 70 else prose[:67] + "..."
        print(f"{path.relative_to(REPO_ROOT)}:{number}: {fault} -- {excerpt}")

    print()
    # Counted per kind: the figures are nine files among thousands, so a single
    # total would hide the day the figure scan silently stops finding them.
    print(f"dart files scanned       : {scanned['.dart']}")
    print(f"figures scanned          : {scanned['.svg']}")
    print(f"citations naming a line  : {len(faults)}")
    return 1 if faults else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
