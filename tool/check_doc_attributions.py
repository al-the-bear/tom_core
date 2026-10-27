#!/usr/bin/env python3
"""Find prose that names a source file and then names a type that file has not got.

Run from anywhere::

    python3 tool/check_doc_attributions.py                  # whole repo
    python3 tool/check_doc_attributions.py tom_flutter_ui   # one subtree

Exits non-zero when an attribution is false, so it can gate a build.

**The fault.** A README says ``lib/screens/grants_screen.dart`` is "a
``DataTable`` of ``projectRole`` (rows) x field resource key (columns)". The
screen builds a ``TomDataTable``. Both names exist, both are spelled right, both
resolve -- and the sentence is still false, because the file it points at
contains the other one. Its neighbour said ``lib/screens/board_screen.dart``
re-runs "when the workspace/project ``DropdownButtonFormField`` changes", where
the screen has a ``TomDropdownButton``. Both were found by hand, and the reason
neither was found by machine is that every gate here was asking a different
question: ``check_dartdoc_refs`` resolves only *private* names, and only inside
``///`` comments; ``check_consumer_claims`` reads only "Used by ``[TomFoo]``"
sentences. A README could name any type it liked, in any package, and nothing
objected.

**Why resolution cannot find it.** The obvious rule -- does the name exist? --
misses both. ``DataTable`` and ``DropdownButtonFormField`` are real Flutter
classes, in scope in every package here. The name is not dangling; it is
*misattributed*, and misattribution is a two-place relation. Nothing about a
name on its own says which file it was claimed for.

**Why absence from the package is too coarse.** The other obvious rule --
is the name absent from the package's own ``lib/``? -- was measured across the
fifteen sample READMEs before this file was written: 421 backticked type names,
24 of them absent, of which four are not types at all (``VARCHAR``, ``ENUM``,
``LICENSE``, a base32 secret) and eighteen are deliberate framework or contrast
mentions that must stay -- "``TomMessenger`` wrapping ``ScaffoldMessenger``",
"no raw ``StatelessWidget``, ``StatefulWidget`` or ``Column``/``Container``".
Two true faults in 24 candidates is a 92 % false-positive rate. A gate at that
rate is switched off within a week, and the eighteen sentences it objects to are
the good ones.

**The signal is attribution, and attribution has a shape.** What separates the
two faults from the eighteen legitimate mentions is that the prose *names a
file* and then, still talking about that file, names a type. The contrast
mentions never do this: they name a type in the abstract, with no file beside
it. So the unit of judgement here is not the document, the paragraph or the
name -- it is the **claim**: one cited file, and the span of prose still
speaking about it.

That span is bounded by four rules, each of which was measured -- by ablating
*this* function, not a sketch of it -- and each of which earns its place.
Numbers are over the repaired tree, as ``claims / names judged / faults``, so
the full rule scores 441 / 105 / 0 and every fault a dropped rule produces is a
false positive:

``the citation's own sentence``
    Where the claim starts. Nothing before the file is named can be about it,
    so a name to the *left* of the citation is never judged -- which is what
    keeps "Each rail destination is a thin ``StatelessWidget`` configuring
    ``AdminCrudScreen<T>`` (``lib/screens/admin_crud_screen.dart``)" out of it.

``plus the next sentence, but only if it continues anaphorically``
    A claim usually runs past its first full stop -- the board-screen fault sat
    in the sentence *after* the citation, opening "It cascades the reads in
    ``initState``". "It", "This", "They", "The file" all say, in the text
    itself, that the subject has not changed. A sentence that opens by naming
    its own subject -- "Create and edit open a reflected editor bound to a
    client-local **draft** (``UserDraft``/``RoleDraft``...)", two sentences
    below a citation of ``lib/screens/admin_crud_screen.dart`` -- has moved on,
    and reading it as part of the claim is what a character-count window does
    wrong. Dropping this test: 441 / 139 / 6, and all six are that kind of
    sentence.

``minus names under a negation``
    "carry no ``TomForm`` of their own", "no class in ``lib/`` extends a raw
    ``StatelessWidget``" -- prose stating what a file does *not* contain, which
    is the one case where the file not containing it is the point. Dropping
    this test: 441 / 121 / 3.

``against every file the claim cites, not just the first``
    A sentence naming two files is making one claim about both:
    "``lib/screens/login_screen.dart`` is a bound ``TomForm``
    (``lib/forms/login_form.dart``)" cites the form's real home in the same
    breath as the screen that mounts it. Dropping this: 441 / 105 / 1.

**What counts as contained** is deliberately lenient, on the same reasoning as
``check_consumer_claims``: the name has to occur in the cited file's text --
comments included, since a file's own dartdoc naming a type is not a
misattribution -- or in anything it ``export``s or takes as a ``part``,
followed transitively. A barrel contains nothing itself, and "exported from
``lib/src/custom/tom_custom_widgets.dart``, together with
``TomAuthTreeNode``, ``TomRadioGroupItem``, ..." is true of the eight files
behind it. Dropping the export walk: 441 / 105 / 6 -- every one of them that
one sentence, which is exactly the shape a barrel produces.

**Documents that are not making an as-is claim are out of scope.** Two paths
are skipped, for one reason: a ``CHANGELOG.md`` describes a past revision, and
``_copilot_guidelines/`` describes an intended one. Neither is a statement about
the tree as it stands, and neither can be repaired -- a changelog entry is not
retro-edited, and a plan naming a type that does not exist yet is doing its job.
Both were measured rather than assumed: including changelogs adds 46 judged
names and exactly two faults, ``HealthAnalyzer`` and ``TomUIGroup``, each a
correct sentence about a class that has since been renamed.

**Measured before being switched on.** 441 claims across the repo, 105 type
names judged, and on first run exactly one fault -- a real one, of the same
class as the two found by hand: ``tom_flutter_ui_test``'s layout table called
``lib/locale_settings.dart`` an "``AppBar`` language selector", where the file
declares ``LanguageSelectorButton`` and the ``AppBar`` that holds it is in
``lib/main.dart``. Repaired in the same pass, so the steady state is zero. One
true fault in 105 judged names is the ratio the naive rule could not reach: a
rule that never cries wolf is one people leave switched on.

Falsified against the shipped function rather than a reimplementation: with each
of the two historical faults re-planted in its own README, the gate reports that
fault and no other.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from gate_report import report_faults
import gate_scope

REPO_ROOT = Path(__file__).resolve().parent.parent

SKIP_DIRS = {".dart_tool", "build", ".git", "node_modules", "__pycache__", "ztmp"}

#: A backticked path with at least one separator, ending ``.dart``. The
#: separator is what distinguishes a path from a bare filename: ``main.dart``
#: on its own names a file the reader cannot locate, and there are several.
DART_PATH = re.compile(r"`([\w.]+(?:/[\w.]+)+\.dart)`")
CODE_SPAN = re.compile(r"`([^`]+)`")

#: A Dart type name: an initial capital and at least one lowercase letter.
#: The second half is what keeps ``VARCHAR``, ``ENUM``, ``DELETE`` and
#: ``LICENSE`` out -- all of them backticked in this corpus, none of them types.
TYPE_NAME = re.compile(r"^[A-Z][a-z]\w*$")

#: A sentence break: terminal punctuation followed by something that can open a
#: sentence. Requiring the opener is what stops ``lib/src/x.dart`` and version
#: numbers from splitting a sentence in half.
SENTENCE_BREAK = re.compile(r"(?<=[.!?])[ \n]+(?=[A-Z`\[*(])")

#: A sentence that continues the previous one's subject rather than naming a new
#: one. This is the whole of the "next sentence" rule -- see the module
#: docstring on why a character-count window cannot do it.
ANAPHORIC = re.compile(
    r"^\s*(?:It|Its|They|Their|This|These|Those|That|"
    r"The (?:file|class|widget|screen|service|same))\b"
)

#: Prose saying what is *not* there. A type named under one of these is being
#: contrasted, and its absence from the file is the author's point.
NEGATION = re.compile(
    r"\b(?:no|not|never|neither|nor|without|rather than|instead of|raw)\b", re.I
)

#: Blocks that stand alone: a list item or a table row is its own claim, and
#: joining it to its neighbours is what makes a fourteen-item plan read as one
#: sentence about the file named in item one.
BLOCK_START = re.compile(r"^\s*(?:[-*+]\s|\d+\.\s|\|)")

EXPORT = re.compile(r"""^\s*export\s+['"]([^'"]+)['"]""", re.M)
PART = re.compile(r"""^\s*part\s+['"]([^'"]+)['"]\s*;""", re.M)


def is_as_is(md: Path) -> bool:
    """False for a document that describes a past or intended tree, not this one."""
    return md.name != "CHANGELOG.md" and "_copilot_guidelines" not in md.parts


def markdown_files(root: Path):
    for md in sorted(root.rglob("*.md")):
        if SKIP_DIRS & set(md.parts):
            continue
        if is_as_is(md):
            yield md


def package_of(md: Path) -> Path | None:
    """The package directory containing *md*, or ``None`` outside one."""
    for parent in md.parents:
        if (parent / "pubspec.yaml").is_file():
            return parent
        if parent in gate_scope.ROOTS:
            break
    return None


def blocks(text: str) -> list[tuple[int, str]]:
    """``(line number, text)`` for each block of prose, fences excluded.

    A block is a paragraph, except that a list item or table row starts one of
    its own: those are written as independent claims and read as independent
    claims, and running them together attributes every name in a list to
    whichever file the first entry happened to mention.
    """
    found: list[tuple[int, str]] = []
    start = 0
    buffer: list[str] = []
    in_fence = False

    def flush() -> None:
        nonlocal buffer
        if buffer:
            found.append((start, "\n".join(buffer)))
        buffer = []

    for number, line in enumerate(text.split("\n"), start=1):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            flush()
            continue
        if in_fence:
            continue
        if not line.strip() or BLOCK_START.match(line):
            flush()
            if not line.strip():
                continue
        if not buffer:
            start = number
        buffer.append(line)
    flush()
    return found


def sentences(block: str) -> list[tuple[int, int]]:
    """``(start, end)`` character offsets of each sentence in *block*."""
    starts = [0] + [m.end() for m in SENTENCE_BREAK.finditer(block)]
    ends = starts[1:] + [len(block) + 1]
    return list(zip(starts, ends))


def contents(path: Path, _seen: frozenset[Path] = frozenset()) -> str:
    """*path*'s text, plus everything it exports or takes as a part.

    A barrel declares nothing, so judging a claim against its own bytes would
    call every name it re-exports a misattribution. Transitive because barrels
    nest.
    """
    if path in _seen:
        return ""
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""
    chunks = [text]
    for target in EXPORT.findall(text) + PART.findall(text):
        if ":" in target:  # package: / dart: -- outside this file's directory
            continue
        resolved = (path.parent / target).resolve()
        if resolved.is_file():
            chunks.append(contents(resolved, _seen | {path}))
    return "\n".join(chunks)


def resolve(cited: str, package: Path) -> Path | None:
    """The file *cited* names, package-relative, lib-relative or repo-relative."""
    for candidate in (package / cited, package / "lib" / cited,
                      gate_scope.at(cited)):
        if candidate.is_file():
            return candidate
    return None


def claims(block: str, package: Path) -> tuple[list[Path], int, list[tuple[int, int]]]:
    """The files a block cites, where its claim starts, and the sentences it spans.

    Returns ``([], 0, [])`` when the block cites nothing that resolves.
    """
    cited: list[Path] = []
    first: re.Match[str] | None = None
    for match in DART_PATH.finditer(block):
        resolved = resolve(match.group(1), package)
        if resolved is None:
            continue
        cited.append(resolved)
        if first is None:
            first = match
    if first is None:
        return [], 0, []

    spans = sentences(block)
    index = max(i for i, (lo, _) in enumerate(spans) if lo <= first.start())
    scope = [spans[index]]
    if index + 1 < len(spans):
        lo, hi = spans[index + 1]
        if ANAPHORIC.match(block[lo:hi]):
            scope.append(spans[index + 1])
    return cited, first.end(), scope


def audit(md: Path, package: Path) -> tuple[int, int, list[tuple[int, str, str]]]:
    """``(claims, names judged, faults)`` for one document."""
    try:
        text = md.read_text(encoding="utf-8")
    except OSError:
        return 0, 0, []

    seen = 0
    judged = 0
    faults: list[tuple[int, str, str]] = []
    for line, block in blocks(text):
        cited, start, scope = claims(block, package)
        if not cited:
            continue
        seen += 1
        body = "\n".join(contents(path) for path in cited)
        for match in CODE_SPAN.finditer(block):
            name = match.group(1)
            if not TYPE_NAME.match(name) or match.start() < start:
                continue
            here = [span for span in scope if span[0] <= match.start() < span[1]]
            if not here:
                continue
            if NEGATION.search(block[here[0][0] : match.start()]):
                continue
            judged += 1
            if re.search(rf"\b{re.escape(name)}\b", body):
                continue
            where = ", ".join(
                str(path.relative_to(package)) for path in dict.fromkeys(cited)
            )
            faults.append((line, name, where))
    return seen, judged, faults


def main(argv: list[str]) -> int:
    roots = gate_scope.scope(argv[0] if argv else None)
    if not roots[0].exists():
        print(f"no such path: {roots[0]}", file=sys.stderr)
        return 2

    documents = 0
    seen = 0
    judged = 0
    total = 0
    for md in (m for r in roots for m in markdown_files(r)):
        package = package_of(md)
        if package is None:
            continue
        claimed, names, faults = audit(md, package)
        if not claimed:
            continue
        documents += 1
        seen += claimed
        judged += names
        total += len(faults)
        for line, name, where in faults:
            print(f"{gate_scope.rel(md)}:{line}")
            print(f"    MISATTRIBUTED: {name} is claimed of {where}, "
                  f"which does not contain it")

    print()
    print(f"documents with a claim  : {documents}")
    print(f"attribution claims      : {seen}")
    print(f"type names judged       : {judged}")
    print(f"misattributed           : {total}")
    return report_faults(total)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
