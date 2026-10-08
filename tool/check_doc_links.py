#!/usr/bin/env python3
"""Find markdown links that open nothing, and links across the documentation seam.

Run from anywhere::

    python3 tool/check_doc_links.py                  # every package
    python3 tool/check_doc_links.py tom_core_kernel  # one subtree

Exits non-zero when any link is unresolvable, so it can gate a build.

**The fault.** A markdown link is the one part of a document that promises to
*take you somewhere*, and it is the part nothing verifies. The sweep that
prompted this gate found 89 broken links under this repo alone and 371 of one
single shape across the workspace -- every project's
``_copilot_guidelines/index.md``, each one opening with a table of four to seven
links to the shared guidelines, and not one of those links working anywhere.
They had been copied from a template in ``dart/new_project_setup.md`` that
carried the defect, so the count grew by one table with every new project.

**Four rules, and why each is a rule rather than a warning.**

``ABSOLUTE``
    A target beginning with ``/``. It reads like "from the workspace root" and
    means nothing of the kind: markdown resolves it against the *filesystem*
    root, so it opens neither in VS Code nor on GitHub. This is the shape that
    reached 371 instances, and it is the one worth stating plainly, because a
    leading slash looks so much more deliberate than a mistake. The repair is
    the relative path -- ugly at four levels deep, but a link that works.

``DEAD``
    A relative target that is not on disk. Usually a file that moved, sometimes
    one that never existed: ``api_summary_index.md`` in the kernel offered a
    "Result" row pointing at ``api_summary_result.md``, for a module the kernel
    does not have and a file nobody ever wrote, in a table whose own header
    says seventeen modules and which listed eighteen.

``GUIDELINE``
    A link from outside a ``_copilot_guidelines/`` folder into one. This is not
    a broken link -- it resolves fine -- it is a layering rule: ``doc/`` and
    ``README.md`` are what a *consumer* of the package reads, and
    ``_copilot_guidelines/`` is workspace tooling that ships with neither the
    package nor its pub.dev page. A README that routes its reader there is
    making the package's documentation depend on the workspace it happens to
    sit in. Naming the folder in prose is fine and is not matched; pointing at
    it is what this catches.

``REFERENCE``
    A bracketed inline code span with no target and no definition, where the
    file carries no ``[label]: target`` line. It is
    dartdoc's square-bracket syntax carried into a markdown file, where it
    means something else entirely: markdown renders it as literal brackets
    around a code span, so the reader sees punctuation where the author meant
    a pointer.

    This gate was blind to the shape **by construction**, which is the reason
    the rule is here rather than in a gate of its own. The three rules above
    scan for ``](``, and the scan runs after inline code has been blanked --
    but the label of one of these IS the code span, so after blanking the line
    reads ``[      ]`` and there is nothing left to match. A reference with no
    definition also has no target, so nothing in a link-resolving checker can
    ever see it. Thirty-four of them sat across four packages while this file
    reported zero faults, nine in a single document that no scan had read.

    Only bracketed **code spans** are matched. A bare ``[Some Name]`` in prose
    is ordinary English punctuation far more often than it is a broken link,
    and a rule that could not tell them apart would be the gate crying wolf.
    The repair is almost always to drop the brackets: of the thirty-four, not
    one had an anchor it could have pointed at, so turning them into links
    would have meant inventing thirty-four targets.

**What is not checked here, and why.** Anchors. ``doc/foo.md#some-heading`` is
accepted whenever ``doc/foo.md`` exists, because [check_doc_tocs] owns the
heading-slug rule and checks every fragment against it -- within a document
(``DANGLING``) and into another (``CROSS``). Checking fragments here as well
would mean a second dialect of heading-slug, which is how two gates come to
disagree. External URLs are not checked either: a checker that reaches the
network is a checker that fails when the network does.

**Code is not prose.** Fenced blocks are skipped entirely and inline code spans
are blanked before scanning, which is not tidiness but correctness in both
directions. A naive scan reports ``operator [](Object? key)`` in every
``api_summary_*.md`` as a link to ``Object? key``, and it *rewrites* the
template inside ``new_project_setup.md``'s ```markdown fence -- turning an
example of what a project should write into something true only of the file
containing it. Both happened while this gate was being written.

**The inventory comes from git.** ``git ls-files`` rather than a walk, so a
scratch document in the working tree cannot fail the build, and -- the half
that matters -- a link is checked against what a reader who *clones* the repo
receives. Existence on the author's disk is not the question.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

from gate_report import report_faults

TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parent

#: A fence opens or closes on any line whose first non-space run is three or
#: more backticks or tildes. Info strings (```` ```markdown ````) are part of
#: the opening line, so matching the prefix is enough.
FENCE = re.compile(r"^\s*(?:```|~~~)")

#: Inline code, blanked rather than deleted so that a link on the same line
#: keeps its shape. Only single-backtick spans: a double-backtick span exists
#: to *contain* backticks, and neither form should be read as prose.
CODE_SPAN = re.compile(r"``[^`]*``|`[^`]*`")

#: ``[text](target)`` and ``![alt](target)`` alike -- the ``!`` sits outside
#: the match and needs no handling. The target stops at whitespace so that a
#: title (``](path "Title")``) is not swallowed, and ``<...>`` is accepted
#: because that is markdown's own escape for a target containing spaces.
LINK = re.compile(r"\[[^\]]*\]\(\s*(?:<([^>]*)>|([^)\s]+))(?:\s+\"[^\"]*\")?\s*\)")

#: Anything a browser handles and this gate must not. ``//`` is
#: protocol-relative, which is a URL with the scheme left to the page.
EXTERNAL = re.compile(r"^(?:[a-z][a-z0-9+.-]*:|//)", re.I)

#: ``[`Name`]`` with nothing after it -- a reference link whose label is an
#: inline code span. Matched on the raw line, before [CODE_SPAN] blanking,
#: because the label is exactly what that blanking removes.
REFERENCE = re.compile(r"\[(`[^`\]]+`)\](?!\()")

#: ``[label]: target`` at the start of a line, which is what makes a reference
#: link resolve. Up to three leading spaces, per CommonMark.
DEFINITION = re.compile(r"^\s{0,3}\[([^\]]+)\]:\s*\S", re.M)

#: A double-backtick span, blanked before [REFERENCE] is applied. It exists to
#: *contain* backticks, which is markdown's way of quoting the very shape that
#: rule forbids -- so a document explaining the defect would otherwise be an
#: instance of it. This is reading markdown correctly rather than an exemption:
#: inside ``` `` `` ```, the brackets are literal text and render as literal
#: text, which is what makes them harmless there and a defect outside.
QUOTED = re.compile(r"``.+?``")

GUIDELINES = "_copilot_guidelines"


def tracked_markdown(root: Path) -> list[Path]:
    """Every tracked ``.md`` file under *root*, as repo-relative paths."""
    listing = subprocess.run(
        ["git", "ls-files", "-z", "--", "*.md"],
        cwd=root,
        capture_output=True,
        text=True,
        check=True,
    )
    return [root / name for name in listing.stdout.split("\0") if name]


def links(path: Path):
    """Yield ``(line_number, target)`` for every link outside code.

    A fence toggles rather than being matched to its own delimiter, because a
    document that opens a fence and never closes it is malformed in a way this
    gate has no business reporting -- and treating the rest of the file as code
    is the safe reading of it either way.
    """
    inside = False
    text = path.read_text(encoding="utf-8", errors="replace")
    for number, line in enumerate(text.splitlines(), 1):
        if FENCE.match(line):
            inside = not inside
            continue
        if inside:
            continue
        prose = CODE_SPAN.sub(lambda m: " " * len(m.group(0)), line)
        for match in LINK.finditer(prose):
            yield number, match.group(1) or match.group(2)


def dangling_references(path: Path):
    """Yield ``(line_number, label)`` for every definition-less reference link.

    Fenced blocks are skipped for the same reason the link scan skips them: a
    ``[Name]`` inside a ```` ```dart ```` block is dartdoc, and dartdoc is
    where this syntax is correct.
    """
    text = path.read_text(encoding="utf-8", errors="replace")
    defined = {label.strip().lower() for label in DEFINITION.findall(text)}
    inside = False
    for number, line in enumerate(text.splitlines(), 1):
        if FENCE.match(line):
            inside = not inside
            continue
        if inside:
            continue
        prose = QUOTED.sub(lambda m: " " * len(m.group(0)), line)
        for match in REFERENCE.finditer(prose):
            if match.group(1).strip().lower() not in defined:
                yield number, match.group(1)


def classify(source: Path, target: str) -> str | None:
    """Name the fault in *target* as written in *source*, or ``None``."""
    if EXTERNAL.match(target) or target.startswith("#"):
        return None
    if target.startswith("/"):
        return "ABSOLUTE"
    bare = target.split("#", 1)[0]
    if not bare:
        return None
    if not (source.parent / bare).exists():
        return "DEAD"
    # Resolved, so the seam question can be asked of a real path. Both sides
    # are needed: a guidelines document linking its neighbours is the whole
    # point of the folder, and only a crossing *into* it is a fault.
    if GUIDELINES in (source.parent / bare).resolve().parts:
        if GUIDELINES not in source.parts:
            return "GUIDELINE"
    return None


def main(argv: list[str]) -> int:
    # `--repo PATH` points the same rules at another repository: its tracked
    # markdown is the inventory and paths are reported relative to it. That is
    # how the workspace-wide sweep (`_bin/check_doc_links_workspace.py` at the
    # workspace root) reuses this file instead of a second copy of its rules.
    repo_root = REPO_ROOT
    if argv[:1] == ["--repo"] and len(argv) >= 2:
        repo_root = Path(argv[1]).resolve()
        argv = argv[2:]
    root = repo_root / argv[0] if argv else repo_root
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    scanned = checked = 0
    faults: list[str] = []
    for path in sorted(tracked_markdown(root)):
        scanned += 1
        for number, target in links(path):
            checked += 1
            kind = classify(path, target)
            if kind is not None:
                name = path.relative_to(repo_root)
                faults.append(f"{kind:9} {name}:{number}  {target}")
        for number, label in dangling_references(path):
            checked += 1
            name = path.relative_to(repo_root)
            faults.append(f"{'REFERENCE':9} {name}:{number}  [{label}]")

    for fault in faults:
        print(fault)

    print()
    print(f"markdown files scanned   : {scanned}")
    print(f"links checked            : {checked}")
    for kind in ("ABSOLUTE", "DEAD", "GUIDELINE", "REFERENCE"):
        print(f"{kind.lower():25}: {sum(f.startswith(kind) for f in faults)}")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
