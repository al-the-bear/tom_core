#!/usr/bin/env python3
"""Check that a cited section number exists in the document it names.

Run from anywhere::

    python3 tool/check_section_numbers.py                  # the whole repo
    python3 tool/check_section_numbers.py tom_core_server  # one subtree
    python3 tool/check_section_numbers.py --self-test      # check the checker

Exits non-zero when a reference names a document that *is* in the workspace
but cites a section that document does not have, or when a Dart comment cites
a document that lives outside this repository.

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

**How a name is resolved.** A citation is read the way its reader reads it:
from where it is written. So the cited spelling -- prefix included -- is first
tried against each directory from the citing file up to the repo root, and only
then against the workspace-wide basename index. That ordering is what makes
``README.md §5`` in ``core_flutter_acl_responsive/lib/`` checkable: the reader
opens *that package's* README, and so does this check, where the basename index
alone sees one ambiguous name among dozens and gives up.

**Documents that are not resolved are reported, not failed.** A name that
neither pass locates may be external, may be ambiguous, or may be genuinely
lost -- three different problems, none of which is "the number is wrong".
Failing on them would mean this gate could never go green without first
settling questions it is not equipped to answer.
"""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent

#: Documents are cited across repo boundaries -- `tom_specs_model_rules.md`
#: lives in `tom_ai/ai_build` -- so the search for a target starts above this
#: repo.
WORKSPACE = REPO_ROOT.parent.parent

#: Directories whose contents are never a document a reader opens, and which
#: therefore must not be able to move either gate's count.
#:
#: ``ztmp`` is the workspace-wide scratch name (gitignored) and it earns its
#: place the hard way: ``check_doc_dart_blocks.py`` writes every sample it
#: analyzes into ``tool/ztmp/doc_dart_blocks/``, so a single ad-hoc run of that
#: gate over an ungated package left ten copied ``§`` references sitting under
#: ``tool/`` -- a shipped directory here -- and turned this gate red over files
#: that are not in the repository. ``_copilot_guidelines`` is the other
#: direction: it is development documentation for this workspace, addressed to
#: whoever changes the package rather than to whoever uses it, so a plan
#: reference in it is correct writing.
SKIP_DIRS = {
    ".dart_tool",
    "build",
    ".git",
    "node_modules",
    "__pycache__",
    "ztmp",
    ".venv",
    "_copilot_guidelines",
}

#: The file set that ships, matching `check_section_refs.py` exactly. The two
#: gates ask consecutive questions about the same references -- does it name a
#: document, and does that document have the section -- so a reference either
#: gate cannot see is unchecked in a way neither report shows. Widening one
#: without the other would leave that hole open in the shape hardest to notice:
#: a green pair of gates.
SHIPPED_DIRS = {"lib", "test", "example", "bin", "tool"}
SHIPPED_DOC_DIR = "doc"

#: The markdown that ships outside ``doc/``: a package or module ``readme``, in
#: either case, and the ``README_advanced_*.md`` series the samples package
#: keeps at its root. Matching only the exact name ``README.md`` was the rule
#: once, and it silently cost both gates 72 documents -- every module readme
#: under ``lib/src/`` and all 22 of the advanced sample's chapters. A gate is
#: only as good as the population it reads, and a population that omits the
#: module documentation reports zero for a reason that has nothing to do with
#: the repository being clean.
SHIPPED_DOC_NAME = re.compile(r"^(README.*\.md|readme\.md)$")
EXEMPT_DOCS = {Path("README.md")}
EXEMPT_DOC_NAMES = {"CHANGELOG.md"}
GENERATED_SUFFIX = ".reflection.dart"

#: A section number: dotted, with an optional single letter suffix.
NUMBER = r"[0-9]+(?:\.[0-9]+)*[a-z]?"

REFERENCE = re.compile(rf"§\s*({NUMBER})")

#: The markdown file nearest to the left of the sign, bare or backquoted.
#: A path prefix is allowed and *kept* (group 1), because it is what makes a
#: citation resolvable from where it was written; group 2 is the bare name the
#: workspace-wide fallback looks up.
DOCUMENT = re.compile(
    r"`?((?:[A-Za-z0-9_./-]*/)?([A-Za-z0-9_.-]+\.md))`?\s*\(?$")

#: A markdown link to a document, nearest to the left of the sign:
#: ``[`codespecs_mapping.md`](../doc/codespecs_mapping.md) §4.1``. The link's
#: target is the document the reader opens, so it is what is resolved.
DOCUMENT_LINK = re.compile(r"\]\(([A-Za-z0-9_./-]*\.md)(?:#[^)]*)?\)\s*$")

#: A document named *after* the number: ``§9.6 of `codespecs_mapping.md```,
#: ``[§2 in tom_ui_design_architecture.md](...)``.
DOCUMENT_AFTER = re.compile(
    r"^\s+(?:of|in)\s+`?((?:[A-Za-z0-9_./-]*/)?[A-Za-z0-9_.-]+\.md)`?")

#: A standard cited by its own numbering, which no markdown file holds:
#: ``RFC 2045 §5.1``.
EXTERNAL_STANDARD = re.compile(r"\b(?:RFC|ISO|IEC|ECMA|IEEE)[ -]?[0-9][0-9.:-]*\s*$")

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


def shipped_files(root: Path):
    """Every shipped Dart file and shipped markdown document under `root`."""
    for path in sorted(root.rglob("*")):
        if path.is_dir() or SKIP_DIRS & set(path.parts):
            continue
        if path.suffix == ".dart":
            if not (SHIPPED_DIRS & set(path.parts)):
                continue
            if path.name.endswith(GENERATED_SUFFIX):
                continue
            yield path
        elif path.suffix == ".md":
            if SHIPPED_DOC_DIR not in path.parts and not SHIPPED_DOC_NAME.match(path.name):
                continue
            if path.name in EXEMPT_DOC_NAMES:
                continue
            if path.relative_to(REPO_ROOT) in EXEMPT_DOCS:
                continue
            yield path


#: What may sit between two citations of one run: ``§5.2/§5.12``,
#: ``§4.1 + §4.4.3``, ``§5.16, §11``, ``§3.1 and §3.2``. Anything else between
#: them is prose, and ends the run.
RUN_JOINER = re.compile(
    r"^[\s,;/+&()\[\]*`'–—-]*(?:(?:and|or|to|through)[\s,;/+&()\[\]*`'–—-]*)?$")


def references(path: Path):
    """Yield `(line, document, number)` for every citation in `path`.

    `document` is `None` when no filename has been named in the block yet,
    which is `check_section_refs.py`'s business rather than this one's.

    In Dart a citation carries to the continuation lines of the comment it
    was written in, and no further: a comment has no sections of its own, so
    a bare number can only mean the document named before it.

    Markdown is different, because a document has sections of its own and a
    bare number in its prose means *its* section. A named document therefore
    carries only through the run of citations written after it -- ``§5.16,
    §11`` or ``§5.2/§5.12``, across a line break if the run continues
    there -- and a bare number after intervening prose is the citing
    document's own.
    """
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return
    if path.suffix == ".md":
        yield from _markdown_references(path, text)
        return
    document = None
    in_block = False
    for number, line in enumerate(text.split("\n"), start=1):
        continues_block = line.lstrip().startswith("//")
        if not continues_block or not in_block:
            document = None
        in_block = continues_block
        for match in REFERENCE.finditer(line):
            named = DOCUMENT.search(line[: match.start()].rstrip())
            if named:
                document = named.group(1)
            yield number, document, match.group(1)


def _named(text: str) -> str | None:
    """The document `text` ends by naming, as a link or as a filename."""
    text = text.rstrip()
    link = DOCUMENT_LINK.search(text)
    if link:
        return link.group(1)
    named = DOCUMENT.search(text)
    return named.group(1) if named else None


def _markdown_references(path: Path, text: str):
    # A document with no numbered headings has no sections to cite, so a bare
    # number in it is not its own: it is an external standard's (`RFC 2045
    # §5.1`) or another document's, and stays unattributed as in Dart.
    yield from _markdown_references_with(
        path, text, has_sections=bool(sections(path)))


def _markdown_references_with(path: Path, text: str, *, has_sections: bool):
    own = path.name if has_sections else None
    run_document = None  # the document an open run of citations belongs to
    for number, line in enumerate(text.split("\n"), start=1):
        if line.strip() == "":
            run_document = None
            continue
        position = 0
        for match in REFERENCE.finditer(line):
            between = line[position: match.start()]
            named = _named(between)
            after = DOCUMENT_AFTER.match(line[match.end():])
            if after:
                yield number, after.group(1), match.group(1)
                position = match.end()
                continue
            if EXTERNAL_STANDARD.search(between):
                run_document = None
                position = match.end()
                continue
            if named:
                run_document = named
            elif run_document is None or not RUN_JOINER.match(between):
                run_document = own
            yield number, run_document, match.group(1)
            position = match.end()
        tail = line[position:]
        named = _named(tail)
        if named:
            run_document = named
        elif not RUN_JOINER.match(tail):
            run_document = None


#: Markdown lines and the documents their citations must be attributed to,
#: read as if written in a document called ``own.md`` that has sections.
MARKDOWN_CASES = (
    ("See `other.md` \u00a75.16, \u00a711 for both.", ["other.md", "other.md"]),
    ("`other.md` \u00a75.2/\u00a75.12 and \u00a75.22", ["other.md"] * 3),
    ("`other.md` \u00a74.1 + \u00a74.4.3 + \u00a74.4.6", ["other.md"] * 3),
    ("`other.md` \u00a73 governs it; \u00a72.4 says why.", ["other.md", "own.md"]),
    ("Per \u00a72.0 here.", ["own.md"]),
    ("[`other.md`](../x/other.md) \u00a74.1", ["../x/other.md"]),
    ("the rule of \u00a79.6 of `other.md`, which", ["other.md"]),
    ("[\u00a713.7 in other.md](other.md#137-x)", ["other.md"]),
    ("RFC 2045 \u00a75.1 makes it case-insensitive.", []),
)


def self_test() -> int:
    """Each markdown attribution rule, on a line written to exercise it."""
    failed = 0
    for line, expected in MARKDOWN_CASES:
        got = [document for _, document, _ in
               _markdown_references_with(Path("own.md"), line, has_sections=True)]
        if got != expected:
            failed += 1
            print(f"self-test: {line!r}: expected {expected}, got {got}",
                  file=sys.stderr)
    if failed:
        return 1
    print(f"self-test: {len(MARKDOWN_CASES)} markdown attribution rules hold")
    return 0


def main(argv: list[str]) -> int:
    if argv == ["--self-test"]:
        return self_test()
    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    index = markdown_index()
    located: dict[tuple[str, Path], Path | None] = {}
    numbered: dict[Path, set[str]] = {}

    def locate(cited: str, source: Path) -> Path | None:
        """The document `cited` names, read from `source`, or `None`.

        The nearest enclosing directory that actually holds the cited path
        wins, which is the document the citation's own reader would open. The
        workspace-wide basename index is the fallback, and only answers when
        the name is unambiguous.
        """
        directory = source.parent
        key = (cited, directory)
        if key in located:
            return located[key]
        found: Path | None = None
        while True:
            candidate = directory / cited
            if candidate.is_file():
                found = candidate
                break
            if directory == REPO_ROOT or directory.parent == directory:
                break
            directory = directory.parent
        if found is None:
            paths = index.get(cited.rsplit("/", 1)[-1], [])
            found = paths[0] if len(paths) == 1 else None
        located[key] = found
        return found

    def known(cited: str, source: Path) -> set[str] | None:
        """`cited`'s section numbers, or `None` if it does not resolve."""
        path = locate(cited, source)
        if path is None:
            return None
        if path not in numbered:
            numbered[path] = sections(path)
        return numbered[path]

    def outside_ok(cited: str, source: Path) -> bool:
        """Whether a Dart comment's cited document ships in this repository.

        A comment in the source is read by whoever holds the package, and the
        one document guaranteed to be beside it is one in this repository: a
        design document that lives in a sibling repository is a citation the
        reader of a checkout of `tom_ai/core` alone cannot follow. Markdown is
        not held to this, because the design documents shipped here are part
        of a document set that spans repositories and cite its other members.
        """
        path = locate(cited, source)
        return path is None or REPO_ROOT in path.resolve().parents

    scanned = 0
    checked = 0
    faults: list[tuple[Path, int, str, str]] = []
    outside: list[tuple[Path, int, str, str]] = []
    unlocatable: Counter[str] = Counter()

    for path in shipped_files(root):
        scanned += 1
        for line, document, number in references(path):
            if document is None:
                continue
            defined = known(document, path)
            if defined is None:
                unlocatable[document] += 1
                continue
            checked += 1
            if number not in defined:
                faults.append((path, line, document, number))
            elif path.suffix == ".dart" and not outside_ok(document, path):
                outside.append((path, line, document, number))

    for path, line, document, number in faults:
        print(f"{path.relative_to(REPO_ROOT)}:{line}: "
              f"{document} has no §{number}")
    for path, line, document, number in outside:
        print(f"{path.relative_to(REPO_ROOT)}:{line}: "
              f"{document} §{number} is not in this repository")

    if unlocatable:
        print()
        print("documents cited but not found in the workspace "
              "(reported, not failed):")
        for name, count in sorted(unlocatable.items()):
            print(f"  {name}  ({count} references)")

    print()
    print(f"files scanned            : {scanned}")
    print(f"section numbers resolved : {checked}")
    print(f"citing a missing section : {len(faults)}")
    print(f"source citing outside    : {len(outside)}")
    return report_faults(len(faults) + len(outside))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
