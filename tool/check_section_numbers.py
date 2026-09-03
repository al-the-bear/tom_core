#!/usr/bin/env python3
"""Check that a cited section number exists in the document it names.

Run from anywhere::

    python3 tool/check_section_numbers.py                  # the whole repo
    python3 tool/check_section_numbers.py tom_core_server  # one subtree

Exits non-zero when a reference names a document that *is* in the workspace
but cites a section that document does not have.

``check_section_refs.py`` is the sibling of this check and stops one step
short: it asks whether a ``§`` reference names its document at all, so
``bug §75`` is a fault and ``codespecs_mapping.md §5.16`` is not. It never
opens the document. That is why ``codespecs_mapping.md §1.1b`` passed it for
months -- the document is named, so the reference looked well-formed, and the
number was checked by nobody. A citation that names the right file and the
wrong section is worse than a bare one: it survives review precisely because
it looks resolvable, and it sends a reader searching a real document for a
string that is not in it.

**Lettered sections are real here, which is what made ``§1.1b`` plausible.**
``acl_design_specification.md`` genuinely has ``## 26b. Hide on
Authorization``, so ``§26b`` resolves. ``codespecs_mapping.md`` does not use
that form: its §1.1 carries lettered *pillars* as bold inline markers --
**(a)**, **(b)** -- under one heading. So the convention was borrowed from a
document that has it to a document that does not, which no amount of care
about the sign or the filename would catch. Only opening the target does.

**What is a section.** A heading whose text begins with a dotted number,
optionally with a single trailing letter and an optional trailing dot::

    ## 7. Result and error model      -> 7
    ### 5.16 CE-CF / CE-CC ...        -> 5.16
    ## 26b. Hide on Authorization     -> 26b

**What is a reference.** ``§`` plus such a number. The document is the
markdown filename nearest to its left; a bare ``§`` inherits the document
named earlier in the same comment block, which is how ``§5.2/§5.12/§5.22``
and multi-line dartdoc citations are written here.

**Documents that are not in the workspace are reported, not failed.** A name
this check cannot locate may be external, may be ambiguous (several
``README.md``), or may be genuinely lost -- three different problems, none of
which is "the number is wrong". Failing on them would mean this gate could
never go green without first settling questions it is not equipped to answer.
"""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent

#: Documents are cited across repo boundaries -- `codespecs_mapping.md` lives
#: in `tom_ai/ai_build` -- so the search for a target starts above this repo.
WORKSPACE = REPO_ROOT.parent.parent

SKIP_DIRS = {".dart_tool", "build", ".git", "node_modules", "__pycache__",
             "ztmp", ".venv"}

#: The directories whose contents ship, matching `check_section_refs.py`.
SHIPPED_DIRS = {"lib", "test", "example"}

#: A section number: dotted, with an optional single letter suffix.
NUMBER = r"[0-9]+(?:\.[0-9]+)*[a-z]?"

REFERENCE = re.compile(rf"§\s*({NUMBER})")

#: The markdown file nearest to the left of the sign, bare or backquoted.
#: A path prefix is allowed and dropped -- `doc/acl_design_specification.md`
#: and the bare name cite the same document.
DOCUMENT = re.compile(r"`?(?:[A-Za-z0-9_./-]*/)?([A-Za-z0-9_.-]+\.md)`?\s*\(?$")

HEADING = re.compile(rf"^#{{1,6}}\s+({NUMBER})\.?\s")


def markdown_index() -> dict[str, list[Path]]:
    """Every markdown file in the workspace, by basename.

    Symlinked directories are not followed: the `_ai` mount is a symlink onto
    a shared clone, and its quest plans are not the documents shipped code
    cites.
    """
    index: dict[str, list[Path]] = {}
    stack = [WORKSPACE]
    while stack:
        directory = stack.pop()
        try:
            entries = list(directory.iterdir())
        except OSError:
            continue
        for entry in entries:
            if entry.is_symlink():
                continue
            if entry.is_dir():
                if entry.name not in SKIP_DIRS:
                    stack.append(entry)
            elif entry.suffix == ".md":
                index.setdefault(entry.name, []).append(entry)
    return index


def sections(path: Path) -> set[str]:
    """The section numbers `path` defines as headings."""
    found = set()
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return found
    for line in text.split("\n"):
        match = HEADING.match(line)
        if match:
            found.add(match.group(1))
    return found


def dart_files(root: Path):
    """Every shipped Dart file under `root`."""
    for path in sorted(root.rglob("*.dart")):
        parts = set(path.parts)
        if SKIP_DIRS & parts:
            continue
        if not (SHIPPED_DIRS & parts):
            continue
        yield path


def references(path: Path):
    """Yield `(line, document, number)` for every citation in `path`.

    `document` is `None` when no filename has been named in the comment block
    yet, which is `check_section_refs.py`'s business rather than this one's.
    """
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return
    document = None
    in_comment = False
    for number, line in enumerate(text.split("\n"), start=1):
        stripped = line.lstrip()
        is_comment = stripped.startswith("///") or stripped.startswith("//")
        # A citation carries to its continuation lines but not past the
        # comment block it was written in.
        if is_comment and not in_comment:
            document = None
        if not is_comment:
            document = None
        in_comment = is_comment
        for match in REFERENCE.finditer(line):
            named = DOCUMENT.search(line[: match.start()].rstrip())
            if named:
                document = named.group(1)
            yield number, document, match.group(1)


def main(argv: list[str]) -> int:
    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    index = markdown_index()
    cache: dict[str, set[str] | None] = {}

    def known(name: str) -> set[str] | None:
        """`name`'s section numbers, or `None` if it does not resolve to one
        file."""
        if name not in cache:
            paths = index.get(name, [])
            cache[name] = sections(paths[0]) if len(paths) == 1 else None
        return cache[name]

    scanned = 0
    checked = 0
    faults: list[tuple[Path, int, str, str]] = []
    unlocatable: Counter[str] = Counter()

    for path in dart_files(root):
        scanned += 1
        for line, document, number in references(path):
            if document is None:
                continue
            defined = known(document)
            if defined is None:
                unlocatable[document] += 1
                continue
            checked += 1
            if number not in defined:
                faults.append((path, line, document, number))

    for path, line, document, number in faults:
        print(f"{path.relative_to(REPO_ROOT)}:{line}: "
              f"{document} has no §{number}")

    if unlocatable:
        print()
        print("documents cited but not found in the workspace "
              "(reported, not failed):")
        for name, count in sorted(unlocatable.items()):
            print(f"  {name}  ({count} references)")

    print()
    print(f"dart files scanned       : {scanned}")
    print(f"section numbers resolved : {checked}")
    print(f"citing a missing section : {len(faults)}")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
