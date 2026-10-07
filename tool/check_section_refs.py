#!/usr/bin/env python3
"""Find section references in shipped code that name no resolvable document.

Run from anywhere::

    python3 tool/check_section_refs.py                  # the whole repo
    python3 tool/check_section_refs.py tom_core_server  # one subtree
    python3 tool/check_section_refs.py --self-test      # check the checker

Exits non-zero when any reference is unresolvable, so it can gate a build.

``--self-test`` asks the opposite question of the repository: it writes one
reference of each shape the rules below distinguish and requires this checker to
reach the stated verdict on it. A gate pinned to zero passes exactly as well
when it has stopped reading anything, so the count alone cannot tell working
coverage from absent coverage -- and this checker's coverage is unusually easy
to lose, because five of its six rules *resolve* a reference rather than fault
it. A regex that stopped matching would show up as a repository that got
cleaner. See :func:`self_test`.

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

The check therefore covers everything that leaves the workspace: the Dart under
``lib/``, ``test/``, ``example/``, ``bin/`` and ``tool/``, and the prose in each
package's ``doc/`` and ``README.md``. Quest plans are not scanned:
cross-referencing its own sections is exactly what a plan is for.

**Why the prose is in scope, given that a document *can* cite itself.** It was
once excluded on the reasoning that markdown is where cross-references belong,
and the exclusion cost the gate its whole shipped-prose population: the sample
packages' documentation carried section references the Dart gate could never
see. Almost all of them turned out to be correct -- a numbered heading of the
citing document, which a reader resolves by scrolling -- so the answer is not to
fail them but to *resolve* them; see [own_sections]. What the widened scope
actually catches is the one reference that looks identical and is not: a bare
``§23`` in a document that has no §23, which in this tree matched a numbered
heading in two different specifications. That is worse than an unresolvable
reference, because a reader who follows it lands somewhere plausible and wrong.

**Lettered sections count too.** A section number may carry an appendix letter
-- ``§A.4``, ``§A.10`` -- and such a reference is no more resolvable than a
plain ``§75``; if anything it is less, since a letter suggests an appendix the
reader may go looking for. The advanced sample's ``§A.4``/``§A.6``/``§A.10``
were the whole population of this form and indexed a specification document
that no longer exists in any shape, so a reader could not have reached them
even inside the workspace. A reference written ``§"Heading Name"`` is a
different construction and deliberately out of scope: it quotes the heading, so
it names what it indexes and can be found by title.

**A quoted reference is not a reference.** A guard that enforces this same
convention has to exhibit ``bug §50`` to say which shape it rejects, and a
rule that cannot state its own subject is not a rule. What distinguishes the
exhibit from the citation is where the sign falls relative to an inline code
span: the house style writes the *document* in code and the section beside it
(``\`codespecs_mapping.md\` §5.16``), so a real citation's sign lands outside
the span, and only a text being shown as text puts the whole of itself in. A
sign inside a span is therefore skipped; see [is_quoted].

That replaced skipping a filename. ``comments_read_as_is_test.dart`` was named
in an exemption list, which cost it every other reference it might ever carry --
a *bare* ``§45`` added to it would not have been reported -- and covered only
the one guard anybody had noticed. ``acl_shipped_text_test.dart`` quotes the
same shapes and was never listed; it passed because a document name happened to
sit in view of each. The rule covers both, and leaves both checked.

**What counts as naming the document.** A document name is a markdown-quoted or
bare ``.md`` filename, an ``RFC <n>``, or one of the specification names used in
this tree (``CodeSpecs``, ``OIDC Core``, ``WebAuthn Level <n>``). The reference resolves when such a
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

**Why a work-item marker overrides everything in view.** Widening the question
to "is a document named nearby" made one shape invisible, and it is the shape
this gate exists for. A comment that opens ``bug §77 / tests §61(e):`` and then
cites ``doc/widget_base.md`` two lines down has a document in view of the
number -- so the number resolved, against a document it does not index. That is
the *plausible and wrong* landing the widened scope was introduced to catch,
arriving through the mechanism that widened it.

No proximity rule can decide this case, because proximity is exactly what is
misleading: the document is genuinely there and genuinely cited, just by a
different sentence. What settles it is the word immediately left of the sign.
``bug``, ``tests``, ``gap`` and their siblings name a *work item* -- a list in a
quest plan -- and a work item is never a document a reader can open. So a
number introduced by one of them is a fault whatever else is on the page, and
the check runs before the three resolutions rather than after them. It cannot
fire on a citation, since a citation names a document rather than a backlog:
``codespecs_mapping.md §5.16`` and ``RFC 7636 §1`` are untouched by it.
"""

from __future__ import annotations

import re
import sys
import tempfile
from pathlib import Path

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent

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

#: The directories whose Dart ships. Everything else in a package is
#: workspace-internal and may reference the plans freely. ``bin`` and ``tool``
#: are here because a package's entry points and its scripts are read by whoever
#: runs them, which is the same reader ``lib`` and ``test`` are written for.
SHIPPED_DIRS = {"lib", "test", "example", "bin", "tool"}

#: The directory whose markdown ships, alongside each package's ``README.md``.
#: Kept separate from [SHIPPED_DIRS] because prose resolves differently from
#: code: a document may cite its own sections, and code has no sections.
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

#: Markdown that is workspace-internal despite sitting where shipped prose does.
#: The repo README indexes the quest's own working documents -- naming their
#: sections is its job -- and a changelog is a record of the sequence of states
#: this convention otherwise keeps out of shipped text. Relative to [REPO_ROOT].
EXEMPT_DOCS = {Path("README.md")}
EXEMPT_DOC_NAMES = {"CHANGELOG.md"}

#: Generated Dart carries whatever its sources carried and is repaired by
#: regenerating, never by editing.
GENERATED_SUFFIX = ".reflection.dart"

#: A section reference: the sign, optional space, a section number. The number
#: may carry a leading appendix letter (``§A.4``, ``§A.10``) as well as being
#: plain (``§75``, ``§5.26``). Both forms index a section; only the letter form
#: was invisible here, and what is invisible to a gate accumulates.
REFERENCE = re.compile(r"§\s*([A-Za-z]?\.?[0-9]+(?:\.[0-9]+)*)")

#: What has to sit immediately left of the sign for the reference to resolve on
#: its own. Anchored at the end, so it is the *nearest* preceding token that
#: decides. ``Core`` is here and not in [DOCUMENT_NAME] because it only names a
#: document in the fixed phrase "OIDC Core"; loose in a line it is a word.
NAMED_SOURCE = re.compile(
    r"(\.md`?|RFC\s*\d+|CodeSpecs|OIDC Core|Core|WebAuthn Level\s*\d+)\s*$",
    re.IGNORECASE,
)

#: The same names, unanchored, for the in-view test. A ``.md`` filename must
#: carry at least one filename character before the extension so that a bare
#: ``.md`` in prose about the format does not resolve anything.
DOCUMENT_NAME = re.compile(
    r"([\w./-]+\.md|RFC\s*\d+|CodeSpecs|OIDC Core|WebAuthn Level\s*\d+)",
    re.IGNORECASE,
)

#: A word that names a *work item* rather than a document, sitting immediately
#: left of the sign. Anchored at the end, so only the nearest token counts:
#: ``Phase 2a §16`` is not matched, because ``2a`` stands between the word and
#: the sign and the reference is then bare rather than marked.
#:
#: These are the lists a quest plan keeps -- bugs, tests, gaps, phases, steps --
#: and none of them is something a reader of the package can open. A number
#: introduced by one is therefore unresolvable by construction, which is why
#: [unresolved] consults this before asking whether a document is in view.
WORK_ITEM_MARKER = re.compile(
    r"\b(bugs?|tests?|gaps?|phases?|steps?|items?|plans?|todos?)\s*$",
    re.IGNORECASE,
)

#: Where a comment starts. Used to decide whether two adjacent lines are one
#: block, and so whether a wrapped sentence may be read as a whole.
COMMENT = re.compile(r"^\s*///?")

#: A markdown heading that opens with its own section number, in either of the
#: two styles this tree writes: ``## 23. Demo Requirements`` and
#: ``### 5.16 User Settings``. The number is what a ``§`` in the same document
#: indexes, so it is what makes such a reference resolvable.
NUMBERED_HEADING = re.compile(r"^#{1,6}\s+([A-Za-z]?\.?[0-9]+(?:\.[0-9]+)*)(?:[.\s]|$)")


def shipped_files(root: Path):
    """Every shipped Dart file and shipped markdown document under ``root``."""
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


def own_sections(lines: list[str]) -> set[str]:
    """The section numbers a document gives its own headings.

    A ``§5.16`` in a document that *has* a §5.16 names what it indexes as
    plainly as a filename would: the reader scrolls. This is the whole reason
    shipped prose can be scanned at all -- almost every reference in it is of
    this kind, and a gate that failed them would be failing correct writing.
    Empty for Dart, which has no headings, so the rule costs code nothing.
    """
    numbers = set()
    for line in lines:
        match = NUMBERED_HEADING.match(line)
        if match:
            numbers.add(match.group(1))
    return numbers


def in_view(lines: list[str], index: int, *, prose: bool) -> str:
    """The text a reader of ``lines[index]`` can take the document name from.

    The line itself, plus either neighbour it shares a block with -- a wrapped
    sentence is one sentence, and the writer did not choose where it broke. In
    Dart the block is the comment: a reference on a *code* line gets only its
    own line, since the comment above it is about the declaration rather than
    about the reference. In markdown the block is the paragraph, so the
    neighbours are simply the adjacent non-blank lines.
    """
    span = [lines[index]]
    joins_block = (
        (lambda text: text.strip() != "") if prose else (lambda text: COMMENT.match(text))
    )
    if joins_block(lines[index]):
        for neighbour in (index - 1, index + 1):
            if 0 <= neighbour < len(lines) and joins_block(lines[neighbour]):
                span.append(lines[neighbour])
    return " ".join(span)


def quoted_spans(line: str) -> list[tuple[int, int]]:
    """The inline code spans of one line, paired left to right.

    Per line rather than per document, which is what makes it safe. A
    document-wide backtick walk goes out of phase at the first fence and reads
    the *gaps* between spans as spans from there on -- the trap
    `check_doc_error_keys.py` documents and sidesteps by never pairing at all.
    Within one line there is no fence to lose phase on, and a trailing unpaired
    backtick simply opens nothing.
    """
    ticks = [m.start() for m in re.finditer("`", line)]
    return [(ticks[i], ticks[i + 1]) for i in range(0, len(ticks) - 1, 2)]


def is_quoted(line: str, at: int) -> bool:
    """Whether the reference at column ``at`` is being *quoted* rather than made.

    The signal is that the sign is inside an inline code span. That reads as a
    rule about typography and is really a rule about house style: a citation
    writes the document in code and the section beside it --
    ``\`codespecs_mapping.md\` §5.16`` -- so the sign lands *outside* the span.
    Only a text being exhibited as text puts the whole of it in, which is what
    the guards that enforce this convention have to do to say what they reject.

    Measured before it was written, because a rule that exempted ordinary
    citations would blind the gate rather than sharpen it: across the shipped
    corpus exactly three references sit inside a span, all three in
    ``acl_shipped_text_test.dart``, and every one of the 400-odd real citations
    sits outside one.

    This is what replaced skipping ``comments_read_as_is_test.dart`` by name.
    The filename exemption cost that file all of its coverage -- a *bare*
    ``§45`` added to it would never have been reported -- and covered only the
    one guard that had been noticed. The rule covers every file that quotes the
    shape it rejects, and leaves each of them checked for the shape it does not.
    """
    return any(start < at < end for start, end in quoted_spans(line))


def unresolved(path: Path) -> list[tuple[int, str]]:
    """The `(line, text)` of every unresolvable section reference in ``path``."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return []
    lines = text.split("\n")
    prose = path.suffix == ".md"
    sections = own_sections(lines) if prose else set()
    faults = []
    for index, line in enumerate(lines):
        if prose and NUMBERED_HEADING.match(line):
            # The heading declares a section; it does not reference one.
            continue
        for match in REFERENCE.finditer(line):
            if is_quoted(line, match.start()):
                # Exhibited as text, so it indexes nothing and resolves nothing.
                # Consulted before the work-item marker, which would otherwise
                # fault a guard for quoting the very shape it exists to reject.
                continue
            left = line[: match.start()]
            if WORK_ITEM_MARKER.search(left):
                # Named its list, which is not a document. Nothing in view can
                # make that resolvable, so the three resolutions do not apply.
                faults.append((index + 1, line.strip()))
                break
            if NAMED_SOURCE.search(left):
                continue
            if match.group(1) in sections:
                continue
            if DOCUMENT_NAME.search(in_view(lines, index, prose=prose)):
                continue
            faults.append((index + 1, line.strip()))
            break  # one report per line is enough to find it
    return faults


#: One probe per rule the checker distinguishes, as
#: ``(name, suffix, text, expected_faults)``. Both verdicts are represented on
#: purpose: a suite of faults alone would pass a checker that reported
#: everything, and a suite of resolutions alone would pass one that reported
#: nothing. Each resolving probe names the rule that carries it, so a rule that
#: stops working is identified rather than merely counted.
SELF_TESTS = [
    (
        "bare number in Dart is a fault",
        ".dart",
        "/// Before §22 the unanchored regex accepted this.\n",
        1,
    ),
    (
        "NAMED_SOURCE — document immediately left",
        ".dart",
        "/// per `codespecs_mapping.md` §5.16\n",
        0,
    ),
    (
        "DOCUMENT_NAME in view — named to the right",
        ".dart",
        '/// See "Container IDs" (§24) in `doc/acl_design_specification.md`.\n',
        0,
    ),
    (
        "DOCUMENT_NAME in view — named on the next line",
        ".dart",
        "/// (§11.2 / §11.4 of\n/// `tom_specs_editor_specification.md`)\n",
        0,
    ),
    (
        "NAMED_SOURCE — an RFC is a document",
        ".dart",
        "/// RFC 7636 §1 defines the transform.\n",
        0,
    ),
    (
        "WORK_ITEM_MARKER overrides a document in view",
        ".dart",
        "/// bug §77 / tests §61(e): see\n/// `doc/widget_base.md` for the rule.\n",
        1,
    ),
    (
        "REFERENCE — a lettered appendix number is seen",
        ".dart",
        "/// The layout follows §A.4.\n",
        1,
    ),
    (
        "own_sections — a heading the document has resolves",
        ".md",
        "## 5. Things\n\nAs §5 says, the order is fixed.\n",
        0,
    ),
    (
        "own_sections — a heading it has not is a fault",
        ".md",
        "## 5. Things\n\nAs §23 says, the order is fixed.\n",
        1,
    ),
    (
        "a numbered heading declares rather than references",
        ".md",
        "## 23. Things §23\n",
        0,
    ),
    (
        "is_quoted — a sign inside an inline code span is an exhibit",
        ".dart",
        "/// 1. **Work-item pointers** — `bug §50`, `tests §34a`.\n",
        0,
    ),
    (
        "is_quoted — a sign outside the span still faults",
        ".dart",
        "/// The guard rejects `bug` pointers such as §50 wherever they appear.\n",
        1,
    ),
    (
        "is_quoted — a citation's sign falls outside the span and resolves",
        ".dart",
        "/// per `codespecs_mapping.md` §5.16\n",
        0,
    ),
]


def self_test() -> int:
    """Prove every rule still reaches its verdict.

    The probes are written to a scratch directory rather than planted in the
    tree, because what this checker reads is the *shape of a sentence* and not a
    measurement of the repository: there is no file whose contents make a rule
    true. Writing them out keeps [unresolved] the thing under test -- it is
    handed a real path and reads it exactly as it does in a run.
    """
    failures = 0
    with tempfile.TemporaryDirectory() as scratch:
        for name, suffix, body, expected in SELF_TESTS:
            probe = Path(scratch) / f"probe{suffix}"
            probe.write_text(body, encoding="utf-8")
            got = len(unresolved(probe))
            if got == expected:
                verdict = "faults" if expected else "resolves"
                print(f"  ok    {name} — {verdict}")
            else:
                print(f"  FAIL  {name} — expected {expected} fault(s), got {got}")
                failures += 1

    print(f"\n{len(SELF_TESTS) - failures} of {len(SELF_TESTS)} rules behave")
    return report_faults(failures)


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()

    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    scanned = 0
    faults: list[tuple[Path, int, str]] = []
    for path in shipped_files(root):
        scanned += 1
        for line, text in unresolved(path):
            faults.append((path, line, text))

    for path, line, text in faults:
        print(f"{path.relative_to(REPO_ROOT)}:{line}: {text}")

    print()
    print(f"files scanned            : {scanned}")
    print(f"unresolvable references  : {len(faults)}")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
