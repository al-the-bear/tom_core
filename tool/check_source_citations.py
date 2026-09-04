#!/usr/bin/env python3
"""Find a comment, figure or guide that cites a line number instead of naming a thing.

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

**Markdown was deliberately left out, then let in for one subtree, then let in
wherever documentation navigates.** The original argument was arithmetic: the
pattern occurred 173 times across 18 files of guide prose, and switching the
rule on would have meant 173 judgement calls on day one -- the noise threshold
this suite has twice declined to cross (353 for the cross-library dartdoc rule,
519 for "name every public type"). What changed is that the judgement calls were
*made*. Every one of those citations in ``tom_core_samples/`` was resolved by
hand and replaced with the name of the declaration it pointed at, so the subtree
sat where the figures already sat: zero violations, and a rule that cost nothing
to switch on.

The subtree boundary then turned out to be the wrong shape. It was drawn around
the place the fault had *accumulated*, not around the place it can *do harm*,
and twelve citations outside it went on rotting unwatched -- nine of them in
``doc/`` pages shipped to consumers. One had already failed in the worst
available way: ``form_authorizers.md`` opened its "The real ``TomAuthorizer``
API" section by citing ``tom_authorization.dart:352``, which is a doc comment
belonging to a *different* class eighty lines above the one it names. It
resolved, it read fluently, and it was wrong.

That work also settled the empirical question. Sampling the anchors against the
files they named found the failure was not occasional -- *essentially every* one
had drifted, and drifted in the dangerous direction: still in range, so still
resolving to real code, just not the code the sentence described. An anchor for
the login JWT pair landed inside two-factor submission; one for the closed-safe
grade default landed on a different method entirely; several landed on blank
lines and bare closing braces. Two pointed past end of file, which is the only
variant a reader can detect. This is the ``CROSS`` argument with a measurement
attached: the guides are the sample's primary teaching artifact, so a reader
following a citation into unrelated code is the worst place for this fault to
live, and it is exactly where it had accumulated most.

**The boundary is now "documentation that navigates", which is a property of
the document rather than a list of paths.** A ``doc/`` page, a package
``README.md`` and a sample guide are all written to be read beside the code, so
in them a ``file.dart:12`` is an instruction to go and look, and the rule is
unambiguous. The sites that still match these patterns elsewhere are a different
kind of sentence, and each is excluded for a reason that can be stated rather
than listed: a CHANGELOG is a dated record, so its citations describe a tree
that no longer exists and "repairing" one would falsify the entry;
``_copilot_guidelines/`` is workspace tooling that ships with neither the
package nor its pub.dev page, the same seam ``check_doc_links.py`` draws; and
this repository's own ``README.md`` is where the suite explains its rules, which
it cannot do without quoting the shapes it forbids. That last exclusion is what
lets the gate keep its documentation instead of acquiring the per-site
suppression list this suite does not have. ``check_doc_source_paths.py`` draws
the same line from the other end: naming a thing in prose is not the same as
pointing at it.

**The repair is never "check the number harder".** It is tempting to gate these
by *validating* them -- many citations are annotated, naming what should be at
the line in a parenthetical or the fenced block below it, and a checker could
assert the line still contains it. That gate would be strictly weaker. It can
only speak about the annotated ones, so it has to report the rest as
*unverifiable*, and a gate with an unverifiable category does not gate; and
where the annotation is present the number has already been made redundant by
it. Both halves of that showed up in the repair: three of the twelve sites named
their target and then cited a line as well (``api_summary_runtime.md`` said
"``lib/tom_core_flutter.dart:21`` exports
``src/tomclient/runtime/platform_detection_client.dart``" -- the sentence is
complete without the number), and one cited ``(line 151)`` for a declaration in
a file that had since been deleted. Naming the declaration is the fix in every
case, and it is the one that survives the next edit.

**A bare ``:12`` is not matched, for the reason ``line 2`` is not.** The guides
also carried about 77 bare backticked continuations (``` `:809` ``` after a full
citation), and 23 backticked ``` `:N` ``` tokens that are TCP ports -- ``:8080``,
``:3307``. Separating them needs a port allowlist, which is judgement of exactly
the kind excluded above. The rewrite removed the continuations at the source
(they only ever trail a named citation this rule *does* catch), so the gate does
not need to see them.

Falsified in five directions against the shipped function, not a
reimplementation. It fires on a planted ``CROSS`` in guide prose, on a planted
``SELF``, and on one hidden in a fenced ``dart`` block -- and stays silent on a
pinned permalink that happens to end in ``.dart:807``, and on the same planted
fault written *outside* ``tom_core_samples``, which is the scope boundary the
paragraph above argues for. That last case is the one worth keeping: it is the
difference between this rule and the repo-wide version that would have made the
suite unable to document itself.

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

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent

SKIP_DIRS = {".dart_tool", "build", ".git", "node_modules", "__pycache__"}
SKIP_SUFFIXES = (".reflection.dart", "_generated.dart", "_bridges.dart", ".g.dart")
SUFFIXES = (".dart", ".svg", ".md")

# Markdown is scanned where it *navigates* -- see the docstring. A `doc/` page,
# a package README and a sample guide are written to be followed; everything
# else that carries these shapes is prose *about* them.
GUIDE_ROOT = REPO_ROOT / "tom_core_samples"
DOC_DIR = "doc"
GUIDELINES = "_copilot_guidelines"


def navigates(path: Path) -> bool:
    """Is *path* documentation a reader is meant to follow into the source?

    In: a ``doc/`` page, a package ``README.md``, and the sample guides -- all
    of them written to be read *beside* the code, so a ``file.dart:12`` in one
    is an instruction to go and look.

    Out, and each for its own reason. A ``CHANGELOG`` is a dated record, so its
    citations describe a tree that no longer exists and repairing them would
    falsify the entry. ``_copilot_guidelines/`` is workspace tooling that ships
    with neither the package nor its pub.dev page -- the same seam
    [check_doc_links] draws. And this repository's own ``README.md`` is where
    the suite explains its rules, which it cannot do without quoting the shapes
    it forbids; excluding it is what lets the gate keep its documentation
    rather than acquire a suppression list.
    """
    if GUIDELINES in path.parts or path == REPO_ROOT / "README.md":
        return False
    return (
        DOC_DIR in path.parts
        or path.name == "README.md"
        or path.is_relative_to(GUIDE_ROOT)
    )

# A comment line, `//` or `///`, capturing the prose after the slashes.
COMMENT = re.compile(r"^\s*///?(?!/)(.*)$")
# A URL, blanked before matching: `.../blob/<sha>/a.dart#L42` is a pinned
# permalink into some other repository, which is exactly the stable form this
# check is asking for rather than an instance of the fault. `file://` is here
# for the opposite reason -- it is how a Dart stack frame prints
# (`#0 Foo.bar (file:///…/foo.dart:12:5)`), and a pasted trace is a transcript
# of what the program said, not a citation anyone wrote or can repair.
URL = re.compile(r"\b(?:https?|file)://\S+")

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
        if path.suffix == ".md" and not navigates(path):
            continue
        yield path


def citable_lines(path: Path, text: str) -> list[tuple[int, str]]:
    """``(line number, the prose that could carry a citation)``.

    In Dart, only a comment can -- code is checked by the compiler. A figure has
    no code, so the whole file is prose, and the citation that reaches a reader
    is the one drawn in a `<text>` element rather than the one in the XML
    comment. Reading only the comment would check the copy nobody sees. A guide
    is prose throughout for the same reason, fenced blocks included: a comment
    inside a fenced snippet is *displayed*, not compiled, so it rots exactly
    like the paragraph around it.
    """
    numbered = list(enumerate(text.split("\n"), start=1))
    if path.suffix in (".svg", ".md"):
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

    scanned = {".dart": 0, ".svg": 0, ".md": 0}
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
    # total would hide the day the figure scan silently stops finding them. The
    # guide count is the same guard for a scan that is scoped to one subtree and
    # would report a clean zero if that subtree ever moved.
    print(f"dart files scanned       : {scanned['.dart']}")
    print(f"figures scanned          : {scanned['.svg']}")
    print(f"guide files scanned      : {scanned['.md']}")
    print(f"citations naming a line  : {len(faults)}")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
