#!/usr/bin/env python3
"""Find section references in shipped code that name no resolvable document.

Run from anywhere::

    python3 tool/check_section_refs.py                  # the whole repo
    python3 tool/check_section_refs.py tom_core_server  # one subtree

Exits non-zero when any reference is unresolvable, so it can gate a build.

A ``§`` reference is fine when the sentence says *what it indexes*::

    per `codespecs_mapping.md` §5.16
    RFC 7636 §1
    OIDC Core §3.1.3.7

and is a fault when it stands bare::

    (bug §75)
    Before §22 the unanchored regex accepted this
    // §43(a) / bug §69: a registry endpoint must inherit ...

**Why a bare number is a defect and not a style preference.** The numbers index
sections of the quest plans -- ``readme_and_example_plan.md`` and its siblings
-- which are working documents that ship with neither the package nor its
tests. A reader of the shipped artefact cannot resolve them, and a reader who
could would find a build log rather than a rule. The shipped convention is that
source and tests state the *current* behaviour and the reason for it, not the
sequence of states that produced it. A test name in particular is read as a
specification, and ``bug §75`` specifies nothing: when it fails, the report
names an index entry instead of the contract that broke.

The check therefore covers ``lib/``, ``test/`` and ``example/`` -- the three
places whose contents leave the workspace. Quest plans and other markdown are
not scanned: cross-referencing its own sections is exactly what a plan is for.

**Lettered sections count too.** A section number may carry an appendix letter
-- ``§A.4``, ``§A.10`` -- and such a reference is no more resolvable than a
plain ``§75``; if anything it is less, since a letter suggests an appendix the
reader may go looking for. The advanced sample's ``§A.4``/``§A.6``/``§A.10``
were the whole population of this form and indexed a specification document
that no longer exists in any shape, so a reader could not have reached them
even inside the workspace. A reference written ``§"Heading Name"`` is a
different construction and deliberately out of scope: it quotes the heading, so
it names what it indexes and can be found by title.

**What counts as naming the document.** A document name is a markdown-quoted or
bare ``.md`` filename, an ``RFC <n>``, or one of the specification names used in
this tree (``CodeSpecs``, ``OIDC Core``). The reference resolves when such a
name sits *in view of it*: on the same line, or on a line immediately above or
below within the same comment block.

**Why "in view" and not "immediately to the left".** The rule was once the
narrower one -- the text ending at the ``§`` had to be the document name -- and
it reported three constructions as faults that are not::

    /// See "Container IDs" (§24) in `doc/acl_design_specification.md`.
    /// (§11.2 / §11.4 of `tom_specs_editor_specification.md`)
    /// See "Layout Direction (RTL/LTR)" (§30) in
    /// `doc/acl_design_specification.md`.

The first names its document to the right, which is ordinary English; the
second names one document for two sections, so only the first ``§`` has it on
the left; the third is the same sentence wrapped, which is not a choice the
writer makes. Between them they were 17 of the faults in one file and every
one of them was correct prose. A gate that fails correct work is a gate that
gets switched off, so the question it asks is now the one that matters to the
reader: *can I see, from here, which document this indexes?* A bare ``bug §75``
still cannot be resolved from anywhere and is still a fault.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {".dart_tool", "build", ".git", "node_modules", "__pycache__"}

#: The directories whose contents ship. Everything else in a package is
#: workspace-internal and may reference the plans freely.
SHIPPED_DIRS = {"lib", "test", "example"}

#: A section reference: the sign, optional space, a section number. The number
#: may carry a leading appendix letter (``§A.4``, ``§A.10``) as well as being
#: plain (``§75``, ``§5.26``). Both forms index a section; only the letter form
#: was invisible here, and what is invisible to a gate accumulates.
REFERENCE = re.compile(r"§\s*[A-Za-z]?\.?[0-9]+")

#: What has to sit immediately left of the sign for the reference to resolve on
#: its own. Anchored at the end, so it is the *nearest* preceding token that
#: decides. ``Core`` is here and not in [DOCUMENT_NAME] because it only names a
#: document in the fixed phrase "OIDC Core"; loose in a line it is a word.
NAMED_SOURCE = re.compile(
    r"(\.md`?|RFC\s*\d+|CodeSpecs|OIDC Core|Core)\s*$",
    re.IGNORECASE,
)

#: The same names, unanchored, for the in-view test. A ``.md`` filename must
#: carry at least one filename character before the extension so that a bare
#: ``.md`` in prose about the format does not resolve anything.
DOCUMENT_NAME = re.compile(
    r"([\w./-]+\.md|RFC\s*\d+|CodeSpecs|OIDC Core)",
    re.IGNORECASE,
)

#: Where a comment starts. Used to decide whether two adjacent lines are one
#: block, and so whether a wrapped sentence may be read as a whole.
COMMENT = re.compile(r"^\s*///?")


def dart_files(root: Path):
    """Every shipped Dart file under ``root``."""
    for path in sorted(root.rglob("*.dart")):
        parts = set(path.parts)
        if SKIP_DIRS & parts:
            continue
        if not (SHIPPED_DIRS & parts):
            continue
        yield path


def in_view(lines: list[str], index: int) -> str:
    """The text a reader of ``lines[index]`` can take the document name from.

    The line itself, plus either neighbour that is part of the same comment
    block -- a wrapped sentence is one sentence, and the writer did not choose
    where it broke. A reference on a *code* line gets only its own line, since
    the comment above it is about the declaration, not about the reference.
    """
    span = [lines[index]]
    if COMMENT.match(lines[index]):
        for neighbour in (index - 1, index + 1):
            if 0 <= neighbour < len(lines) and COMMENT.match(lines[neighbour]):
                span.append(lines[neighbour])
    return " ".join(span)


def unresolved(path: Path) -> list[tuple[int, str]]:
    """The `(line, text)` of every unresolvable section reference in ``path``."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return []
    lines = text.split("\n")
    faults = []
    for index, line in enumerate(lines):
        for match in REFERENCE.finditer(line):
            if NAMED_SOURCE.search(line[: match.start()]):
                continue
            if DOCUMENT_NAME.search(in_view(lines, index)):
                continue
            faults.append((index + 1, line.strip()))
            break  # one report per line is enough to find it
    return faults


def main(argv: list[str]) -> int:
    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    scanned = 0
    faults: list[tuple[Path, int, str]] = []
    for path in dart_files(root):
        scanned += 1
        for line, text in unresolved(path):
            faults.append((path, line, text))

    for path, line, text in faults:
        print(f"{path.relative_to(REPO_ROOT)}:{line}: {text}")

    print()
    print(f"dart files scanned       : {scanned}")
    print(f"unresolvable references  : {len(faults)}")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
