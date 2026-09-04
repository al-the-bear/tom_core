#!/usr/bin/env python3
"""Check that files copied between packages say so, and agree about it.

Run from anywhere::

    python3 tool/check_shared_chrome.py                  # the whole repo
    python3 tool/check_shared_chrome.py tom_core_samples # one subtree

Exits non-zero when a copied file carries no pointer to its siblings, or when
the pointers disagree with each other.

**The thing being protected.** Some files exist several times over on purpose.
Four showcase samples each carry their own `lib/common/showcase_section.dart`
because a sample a reader can run must be self-contained -- a shared package
would make the interesting file the one *outside* the sample. The cost is that a
fix applied to one copy reaches none of the others, and nothing about the file
says the others are there. The convention that answers this is a sentence in the
file's header comment naming its siblings::

    /// Shared in shape with `core_flutter_acl_sample` /
    /// `core_flutter_acl_responsive`.

It works only while it is true, and it is exactly the kind of claim that stops
being true silently: `demo_box.dart` in `core_flutter_ui_showcase` named both its
siblings and *neither named it back*, so a developer editing either one was told
about one other copy out of two. That asymmetry outlived the commit that
declared the pointers "complete and symmetric" by a single day.

**Two independent questions, because one rule cannot answer both.**

*Is a copy declared?* Answered by content, not by the pointer -- otherwise a file
with no pointer is invisible to the very check meant to find it. Two files with
the same basename in different packages whose code is identical once comments and
whitespace are stripped are copies, and must be in one declared group. Comments
are stripped because copies drift in their prose long before they drift in their
behaviour, and it is the behaviour a fix lands in. That is an exact rule with no
similarity threshold: a threshold would drop a pair out of the gate as it drifted,
which is the failure being gated against, arriving quietly.

*Do the declarations agree?* Answered by the pointers alone. "Shared in shape
with" is an equivalence relation -- if A is a copy of B and B of C, then a fix in
A belongs in C -- so every file's declared siblings must be exactly its connected
component minus itself. Checking symmetry alone would pass A<->B, B<->C, A missing
C: symmetric, and still a reader of A never hears about C.

The two questions overlap by design and neither subsumes the other.
`showcase_cell.dart` is declared across four packages but identical in only
three, because the form showcase's copy has drifted -- content discovery does not
see the fourth, and the declaration does. `dto_reflection.dart` was identical in
two packages and declared in neither -- the declaration had nothing to say, and
content discovery found it.

**Where the pointer has to be.** In the file's header comment: the first run of
`///` lines. Dartdoc renders it as the file's own description and it is what an
editor shows on open, so it is the one place a reader is certain to have seen
before making the edit that needs to reach the siblings. A pointer further down
is reported as misplaced rather than accepted, since a sentence nobody reaches in
time does not do the job the sentence exists for.

**What is not checked.** Whether the copies *should* be copies. Extracting shared
chrome into a package is a design decision about what a sample is for, and this
gate deliberately takes no position on it -- it only insists that whatever is
duplicated is duplicated in the open.
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent

SKIP_DIRS = {".dart_tool", "build", ".git", "node_modules", "__pycache__",
             "ztmp", ".venv"}

#: Generated code is written by a builder from a source elsewhere, so two
#: identical copies are a fact about the builder rather than a duplication
#: anybody maintains.
GENERATED_SUFFIXES = (".reflection.dart", ".versioner.dart", ".g.dart")

#: The pointer, and the package names inside it. The sentence ends at the first
#: full stop, which is why the names are backquoted rather than bare -- a bare
#: `core_flutter_acl_sample` would be indistinguishable from prose.
POINTER = re.compile(r"Shared in shape with\s+([^.]*)\.")
PACKAGE_NAME = re.compile(r"`([a-z][a-z0-9_]*)`")

DOC_LINE = re.compile(r"^\s*///\s?(.*)$")
CODE_COMMENT = re.compile(r"^\s*//")


def packages(root: Path) -> dict[str, Path]:
    """Every package under `root`, by the directory name it is known as.

    Directory name rather than pubspec `name:`, because that is what the
    pointers spell and what a reader types into a file search.
    """
    found: dict[str, Path] = {}
    for pubspec in sorted(root.rglob("pubspec.yaml")):
        if SKIP_DIRS & set(pubspec.parts):
            continue
        found[pubspec.parent.name] = pubspec.parent
    return found


def library_files(package: Path):
    """Every hand-written Dart file in `package/lib`."""
    lib = package / "lib"
    if not lib.is_dir():
        return
    for path in sorted(lib.rglob("*.dart")):
        if SKIP_DIRS & set(path.parts):
            continue
        if path.name.endswith(GENERATED_SUFFIXES):
            continue
        yield path


def header(lines: list[str]) -> tuple[str, int, int]:
    """The file's header comment, flattened, with the span it occupies.

    The first unbroken run of `///` lines, wherever it starts -- a file with a
    `library;` directive puts it at line 1, and one without it (`dto_reflection`)
    puts it after the imports. Flattened because the pointer sentence is a
    sentence: it wraps, and a check that reads one line at a time sees half of
    it. That is not hypothetical -- a first attempt at this check reported two
    correct files as missing their pointers for exactly that reason.
    """
    start = None
    text: list[str] = []
    for index, line in enumerate(lines):
        match = DOC_LINE.match(line)
        if match:
            if start is None:
                start = index
            text.append(match.group(1).strip())
        elif start is not None:
            return " ".join(text), start, index
    return (" ".join(text), start, len(lines)) if start is not None else ("", -1, -1)


def flattened_doc(lines: list[str]) -> str:
    """Every `///` line in the file, flattened -- used to spot a misplaced
    pointer, which by definition is not in the header."""
    return " ".join(m.group(1).strip()
                    for m in (DOC_LINE.match(line) for line in lines) if m)


def declared(text: str) -> list[str]:
    """The package names a flattened comment points at."""
    match = POINTER.search(text)
    return PACKAGE_NAME.findall(match.group(1)) if match else []


def code(lines: list[str]) -> str:
    """`lines` with comments and whitespace removed.

    What is left is what a behavioural fix would land in, which is the only
    thing that makes two files copies for this gate's purposes.
    """
    kept = []
    for line in lines:
        if CODE_COMMENT.match(line) or not line.strip():
            continue
        kept.append(" ".join(line.split()))
    return "\n".join(kept)


def components(edges: dict[str, set[str]]) -> list[set[str]]:
    """The connected components of an undirected graph given as an adjacency map."""
    seen: set[str] = set()
    found = []
    for node in edges:
        if node in seen:
            continue
        group = set()
        stack = [node]
        while stack:
            current = stack.pop()
            if current in group:
                continue
            group.add(current)
            stack.extend(edges.get(current, ()))
        seen |= group
        found.append(group)
    return found


class Copy:
    """One file, its declared siblings, and what its code normalizes to."""

    def __init__(self, path: Path, package: str):
        lines = path.read_text(encoding="utf-8", errors="replace").split("\n")
        self.path = path
        self.package = package
        self.name = path.name
        self.code = code(lines)
        head, _, _ = header(lines)
        self.declared = declared(head)
        self.misplaced = not self.declared and bool(
            POINTER.search(flattened_doc(lines)))

    def __repr__(self) -> str:
        return f"{self.package}/{self.name}"


def collect(root: Path) -> dict[str, list[Copy]]:
    """Every library file that shares its basename with one in another package.

    Files unique to their package cannot be copies of anything, so they are not
    read past their name.
    """
    by_name: dict[str, list[tuple[Path, str]]] = defaultdict(list)
    for name, package in packages(root).items():
        for path in library_files(package):
            by_name[path.name].append((path, name))

    return {
        name: [Copy(path, package) for path, package in entries]
        for name, entries in sorted(by_name.items())
        if len({package for _, package in entries}) > 1
    }


def quoted(names: list[str]) -> str:
    """Package names written the way the pointer sentence writes them, so a
    fault message can be pasted into the file it is about."""
    return " / ".join(f"`{name}`" for name in names)


def faults_for(name: str, copies: list[Copy], known: set[str]) -> list[str]:
    """Every fault the copies of one basename carry."""
    found: list[str] = []
    by_package = {copy.package: copy for copy in copies}

    # A pointer that names nothing reachable is worse than no pointer: it reads
    # as a checked fact and sends the reader to a file that is not there.
    edges: dict[str, set[str]] = {p: set() for p in by_package}
    for copy in copies:
        for sibling in copy.declared:
            if sibling not in by_package:
                reason = ("is not a package in this repository"
                          if sibling not in known
                          else f"has no {name}")
                found.append(f"{copy.path.relative_to(REPO_ROOT)}: points at "
                             f"`{sibling}`, which {reason}")
                continue
            edges[copy.package].add(sibling)
            edges[sibling].add(copy.package)

    # Identical code is a copy whether or not anybody said so.
    identical: dict[str, list[Copy]] = defaultdict(list)
    for copy in copies:
        identical[copy.code].append(copy)
    for group in identical.values():
        if len(group) < 2:
            continue
        for copy in group:
            for other in group:
                if other.package != copy.package:
                    edges[copy.package].add(other.package)
                    edges[other.package].add(copy.package)

    # Every file must name its whole component. One rule for symmetry and
    # transitivity together: a component is what "a fix here belongs there"
    # closes over.
    for group in components(edges):
        if len(group) < 2:
            continue
        for package in sorted(group):
            copy = by_package[package]
            expected = sorted(group - {package})
            if sorted(copy.declared) == expected:
                continue
            says = (f"points at {quoted(sorted(copy.declared))}"
                    if copy.declared else "carries no pointer")
            found.append(f"{copy.path.relative_to(REPO_ROOT)}: {says}, "
                         f"but is shared with {quoted(expected)}")

    for copy in copies:
        if copy.misplaced:
            found.append(f"{copy.path.relative_to(REPO_ROOT)}: has a "
                         f"'Shared in shape with' pointer outside its header "
                         f"comment, where a reader opening the file will not "
                         f"meet it before editing")
    return found


def main(argv: list[str]) -> int:
    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    known = set(packages(root))
    shared = collect(root)

    faults: list[str] = []
    declared_groups = 0
    for name, copies in shared.items():
        if any(copy.declared for copy in copies):
            declared_groups += 1
        faults.extend(faults_for(name, copies, known))

    for fault in faults:
        print(fault)
    if faults:
        print()

    print(f"packages scanned         : {len(known)}")
    print(f"basenames in >1 package  : {len(shared)}")
    print(f"declared shared groups   : {declared_groups}")
    print(f"pointers disagreeing     : {len(faults)}")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
