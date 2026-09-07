#!/usr/bin/env python3
"""Find dartdoc references to private names that do not exist.

Run from anywhere::

    python3 tool/check_dartdoc_refs.py                # check the whole repo
    python3 tool/check_dartdoc_refs.py tom_core_server  # check one subtree

Exits non-zero when any reference dangles, so it can gate a build.

A dartdoc reference is ``[someName]`` in a ``///`` comment. When the name
resolves, dartdoc renders a link; when it does not, it renders as plain text
and the reader who followed the pointer finds nothing. The failure is silent in
both directions -- nothing warns at the writing end, and nothing looks wrong at
the reading end except an absent link nobody was told to expect.

**Why only private names.** The obvious detector is the ``comment_references``
lint, and it is the wrong tool for this tree. It flags every reference not
visible in the importing scope, which here is hundreds of *correct* references
to real classes in sibling files -- ``[TomAuditAnchor]`` from
``audit_sink.dart``, ``[TomMessageTransport]`` from ``message.dart``. Measured
by the neighbouring ``report_crosslib_refs.py``, 353 of the 5556 bracketed
references that name a workspace-declared type do not resolve from the library
writing them (``tom_flutter_ui`` alone: 68 of 744) -- and that is a lower bound
on the lint's output, which judges SDK names too. Re-run that report before
revisiting any of this; it exists so these numbers stay checkable rather than
becoming folklore. Satisfying the lint would mean adding imports that
exist only for prose, several of them cycles (``audit_anchor.dart`` already
imports ``audit_sink.dart``, so the reverse link is a loop). Trading import
graph clarity for link rendering is a bad trade, and a lint nobody can turn on
is not a guard.

Nor can that backlog be triaged mechanically. Whether a given reference wants an
import or a demotion to backticks turns on whether the two libraries *ought* to
depend on each other, which is an architectural judgement and not a property of
the reference. ``custom/tom_loading_overlay.dart`` linking ``[SlowValidator]``
over in ``forms/validation`` wanted backticks -- the dependency would have been
new and wrong; ``[TomForm]`` from ``tom_form_child_container.dart`` plausibly
wants the link. No single rule separates them, so a checker over this population
would spend most of its output being wrong.

Private names carry no such ambiguity. ``_foo`` can only ever resolve inside its
own library, so "does it exist?" is answerable from the library alone, with no
import question to get wrong. The third check below extends the same *existence*
question -- and only that question -- to public names, which is what a renamed
member leaves behind.

**One package does turn the lint on, and the exception proves the rule.**
``tom_core_samples/advanced_todo_domain`` enables ``comment_references`` in its
own ``analysis_options.yaml``. It can afford to because the argument above is
about scale and ambiguity, and it has neither: ten hand-written files, 62
repo-declared references, and -- per this report -- 0 that do not resolve. Every
one of its cross-entity links wanted the import (the eight entity files already
model a mutually-referring graph, so the imports document a real relation), and
the single case that would have needed a cycle was demoted to backticks instead:
``enums.dart`` is the leaf every entity depends on, so it names its owning
entities in backticks rather than importing them back for a link. The
architectural judgement the paragraph above says cannot be made mechanically was
made by hand, once, for one small package.

It generalises no further. The package also has a reason the rest of the tree
does not: its barrel folds all eight files into a single library, so ``dart doc``
resolves a cross-entity ``[Sibling]`` whether or not the referring file imports
it -- a broken link there is invisible in the generated output *and* in the
warning count. That was measured, not assumed: deleting one doc-only import
leaves ``dart doc`` reporting "0 warnings and 0 errors" while the analyzer
reports two dangling references. Where the generated docs cannot see the fault,
the lint is the only thing that can.

Existence is decided by looking for the identifier anywhere in the library's
code -- deliberately lenient. The point is to catch names that vanished, not to
police whether a reference points at a declaration rather than a local. A
lenient rule that never cries wolf is one people leave switched on.

**Second check: prose that orients the reader against a type that is gone.**
The argument above rules out judging *bracketed* public references, because a
dangling one is indistinguishable from a correct one that simply lacks an
import. Backticked names carry no such ambiguity, and for the same structural
reason private names do not: dartdoc never links a backticked span, so there is
no import question to get wrong. The only question left is whether the name
exists at all.

That matters because a removed type leaves its name behind in prose, and
nothing objects. ``advanced_authadmin_client/lib/forms/admin_login_form.dart``
described its fields as "not the legacy ``TomFormOld``/``TomEmailField`` API"
for the three weeks after both types were deleted with the ``forms/`` module.
Backticks rather than brackets meant dartdoc emitted no broken link, the
analyzer saw a string, and the build stayed green -- which is precisely why it
survived. The cost is paid by the reader, who is told what the code *is not* by
appeal to something they cannot look up, in a sample whose job is to be the
worked example a newcomer copies. Two more copies sat in
``tom_uam_client/lib/uam/sample_app_state.dart`` (tcinc1112).

So the rule is narrow on purpose: a capitalised identifier inside backticks, on
a doc line that frames it as *past* -- "legacy", "formerly", "used to be",
"replaced by", "no longer" -- must appear somewhere in the repo's code. Framing
is what makes the line checkable. "The legacy ``TomFormOld``" is a claim that
something existed and has been superseded; if the name appears nowhere, the
claim orients the reader at nothing. A backticked name with no such framing is
usually a parameter, a key, or a literal, and judging those would produce the
wolf-crying this file's first check was designed to avoid.

Existence is again decided leniently, by looking for the identifier anywhere in
repo code rather than for a declaration. That is what keeps SDK and third-party
names (``String``, ``Future``, ``Widget``) out of the output without an
allowlist to maintain: they are all over the code already. Only a name that
appears in *no* code anywhere -- a genuinely vanished one -- can fail.

**Framing is matched per line, and that was measured rather than assumed.** The
obvious alternative is to judge a whole ``///`` block, so that a name wrapped
onto the line below its framing still counts. Measured on this tree, block scope
judges 195 backticked names and reports 8, of which **6 are wrong**: ``O_EXCL``
(a POSIX flag), ``QRTZ_JOB_DETAILS`` and ``JOB_CLASS_NAME`` (Quartz's SQL column
names, quoted as the schema this one is modelled on), ``ClassName`` twice (a
metavariable in a test's format description), and ``CsRouteRef``. Every one sits
in a paragraph that happens to contain a framing word about something else
entirely. Line scope judges 21 names and reports 2, both real. Six false
positives is the wolf-crying the first check was built to avoid, so the miss is
accepted: a wrapped name goes unflagged, and ``resource_role_resolver.dart``
had exactly one such case. Re-measure before widening this -- the numbers are
here so they stay checkable rather than becoming folklore.

The framing vocabulary earns its entries the same way. Adding ``replaces`` and
``retires`` took the judged population from 3 names to 21 and surfaced a second
genuine fault (``ShareRecord`` in ``share_delegation_store.dart``) with no new
false positive. A word that cannot show that ledger does not belong in the list.

**Third check: a bracketed public name that exists nowhere at all.** The first
section rules out judging whether a public reference *resolves from here*, and
none of that argument is retracted. This check asks a strictly narrower
question: does the name exist *anywhere*? A name whose identifier appears in no
Dart code in the tree cannot be fixed by any import, so there is no
architectural judgement to make and no backlog to triage -- it is decidable, and
it is always a defect. ``[describeAnchoring]`` in ``ops_anchoring.dart`` was
exactly that: a member renamed to ``describe()``, left pointing at nothing, in a
package green on all eleven gates (tcinc989).

Nor is ``dart doc`` a substitute. It reports 0 warnings on
``advanced_ops_server`` *with that reference present*, because the dangling name
sat in the ``library;`` comment of ``lib/src/ops_anchoring.dart`` and dartdoc
renders only the canonical library -- the barrel. The library comments under
``lib/src/**`` are never rendered and so never checked. Verified by grepping the
generated HTML: the sentence around the reference appears nowhere in the output,
while the identically-worded sentence in the barrel's own comment does.

**Ownership of the head is what makes the question decidable, and that is the
whole SDK story.** A dotted ``[Head.member]`` asks whether ``member`` exists *on
Head*. When ``Head`` is somebody else's type that needs a resolved type index --
precisely the dependency this gate declines to acquire -- so those references are
skipped. When ``Head`` is a type this repo declares, the member is ours and the
same existence question applies. An undotted ``[name]`` is always judged: it asks
only whether the token exists anywhere, and an SDK name we actually use is all
over our code already, so it cannot fail.

Measured on this tree: of 14 649 public references, **14 498 are judged** (12 749
undotted plus 1 749 whose head is one of the 3 443 types declared here) and 151
are skipped. Four named nothing anywhere, and **all four were genuine** --
``[setToken]`` (renamed to ``setTokens``), ``[ShareDialog]`` (the class is
private; the entry point is ``showShareDialog``), ``[tomChildren]`` (a
constructor that never existed), and ``[ModalBottomSheet]`` (Flutter's class is
``BottomSheet``; ``ModalBottomSheet`` is private to the framework). The exclusion
earns its place on the same evidence: **the only two skipped names that would
have failed the test are both correct SDK API** --
``[RandomAccessFile.lockSync]`` and
``[CupertinoActivityIndicator.partiallyRevealed]``. Reporting them would be the
wolf-crying the first check was built to avoid. Note that
``CupertinoActivityIndicator`` *does* appear in our code, so "is the head a name
we use" would have reported it; only "is the head a type we declare" does not.

Judging owned heads is not free scope -- it closes the shape the exemplar now
sits in. tcinc989's own fix rewrote ``[describeAnchoring]`` to
``[OpsAnchoring.describe]``, so an undotted-only rule would not have caught a
*second* rename of that very member. Over the 1 749 owned-head references the
extension adds, it reports 0 faults today: it costs one regex pass and buys the
blind spot's closure.

The obvious alternative -- restrict the rule to workspace-shaped names, a
``Tom*``/``ops*`` prefix -- was measured and is worse. It keeps **0 of the 4**
genuine faults case-sensitively and 1 of 4 case-insensitively (``tomChildren``
alone), because the defect a rename leaves behind is spelled however the member
was spelled: ``setToken`` carries no convention marker. Shape of the *question*
separates the populations; spelling of the *name* does not. Re-measure before
widening this to unowned heads -- the numbers are here so they stay checkable
rather than becoming folklore.

Scope is this repo (``tom_ai/core``). Across the whole of ``tom_ai`` the same
scan finds more, but the surplus includes ``tom_ai/xternal/`` -- vendored
upstream forks whose doc comments are not ours to edit -- so widening the gate
means acquiring an allowlist before it can ever be green.

**The three checks are guarded by a fixture that runs on every invocation**
(``self_test``). A gate whose own extraction quietly breaks reports zero faults
and looks like success, which is the failure mode a ratchet cannot see; running
the assertions inline means they cannot rot in a test file nobody executes, and
they cost microseconds. A fixture failure exits 2 with no fault line, so
``check_gates.py`` records it as ``no-count`` -- a broken gate fails the suite
rather than passing it.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent

SKIP_DIRS = {".dart_tool", "build", ".git", "node_modules", "__pycache__"}
SKIP_SUFFIXES = (".reflection.dart", "_generated.dart", "_bridges.dart", ".g.dart")

DOC_LINE = re.compile(r"^\s*///(.*)$")
FENCE = re.compile(r"^\s*///\s*```")
PART_OF = re.compile(r"""^\s*part\s+of\s+['"]([^'"]+)['"]\s*;""", re.M)
PART = re.compile(r"""^\s*part\s+['"]([^'"]+)['"]\s*;""", re.M)
IDENTIFIER = re.compile(r"\b_\w+")
INLINE_CODE = re.compile(r"`[^`]*`")
CAPITALISED = re.compile(r"\b[A-Z]\w*")
# Any identifier, capitalised or not. The third check needs this where the
# second does not: `setToken` and `tomChildren` are invisible to CAPITALISED.
ANY_IDENTIFIER = re.compile(r"\b[A-Za-z_]\w*")
# A dotted or undotted run of identifiers and nothing else -- what a judgeable
# reference must be once `new`/`const` and any argument list are stripped.
DOTTED_NAME = re.compile(r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*")
# A type declaration, so the gate can tell a head it owns from one it does not.
DECLARATION = re.compile(
    r"^\s*(?:abstract\s+|sealed\s+|final\s+|base\s+|interface\s+|mixin\s+)*"
    r"(?:class|enum|mixin|extension|typedef)\s+(\w+)",
    re.M,
)
# Words that frame a backticked name as something that *was* -- the framing is
# what turns "a name in backticks" into a checkable claim about existence.
PAST_FRAMING = re.compile(
    r"\b(legacy|formerly|used to be|replaces?|replaced by|retires?|supersede[sd]|"
    r"no longer|deprecated in favour of|old\s+\w*\s*API)\b",
    re.I,
)
# A bracketed run with no nested brackets. The trailing lookahead rejects
# markdown links -- `[text](url)` and `[text][ref]` are not dartdoc references.
REFERENCE = re.compile(r"\[([^\[\]]+)\](?![\(\[])")


def source_files(root: Path) -> list[Path]:
    out = []
    for path in sorted(root.rglob("*.dart")):
        if SKIP_DIRS & set(path.parts):
            continue
        if path.name.endswith(SKIP_SUFFIXES):
            continue
        out.append(path)
    return out


def code_identifiers(text: str) -> set[str]:
    """Every private identifier appearing outside a doc comment."""
    lines = [ln for ln in text.split("\n") if not DOC_LINE.match(ln)]
    return set(IDENTIFIER.findall("\n".join(lines)))


def library_of(path: Path, text: str) -> Path:
    """The file whose library ``path`` belongs to -- itself, unless it is a part."""
    match = PART_OF.search(text)
    if not match:
        return path
    target = match.group(1)
    # `part of` takes either a URI or a library name; only the URI form is
    # resolvable here, and it is the only form this tree uses.
    if target.endswith(".dart"):
        resolved = (path.parent / target).resolve()
        if resolved.exists():
            return resolved
    return path


def library_identifiers(path: Path, cache: dict[Path, set[str]]) -> set[str]:
    """Private identifiers across the whole library: the file plus its parts."""
    if path in cache:
        return cache[path]
    cache[path] = set()  # guard against a malformed part cycle
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return cache[path]
    names = code_identifiers(text)
    for part in PART.findall(text):
        resolved = (path.parent / part).resolve()
        if resolved.exists() and resolved != path:
            names |= library_identifiers(resolved, cache)
    cache[path] = names
    return names


def private_references(text: str) -> list[tuple[int, str]]:
    """``(line number, referenced name)`` for every private dartdoc reference."""
    found = []
    in_fence = False
    for number, line in enumerate(text.split("\n"), start=1):
        doc = DOC_LINE.match(line)
        if not doc:
            in_fence = False  # a fence cannot span a break in the comment
            continue
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        body = INLINE_CODE.sub("", doc.group(1))
        for match in REFERENCE.finditer(body):
            name = match.group(1).strip()
            name = re.sub(r"^(new|const)\s+", "", name)
            head = name.split(".")[0].split("(")[0].strip()
            if head.startswith("_") and re.fullmatch(r"_\w+", head):
                found.append((number, head))
    return found


#: The prefix that marks a name as this workspace's own, and therefore one
#: whose absence from all code is decidable rather than merely unindexed.
OUR_PREFIX = "Tom"


def code_names(text: str) -> set[str]:
    """Every capitalised identifier appearing outside a doc comment."""
    lines = [ln for ln in text.split("\n") if not DOC_LINE.match(ln)]
    return set(CAPITALISED.findall("\n".join(lines)))


def code_words(text: str) -> set[str]:
    """Every identifier appearing outside a doc comment, capitalised or not."""
    lines = [ln for ln in text.split("\n") if not DOC_LINE.match(ln)]
    return set(ANY_IDENTIFIER.findall("\n".join(lines)))


def declared_types(text: str) -> set[str]:
    """Every type this file declares -- the heads whose members are ours to judge."""
    return set(DECLARATION.findall(text))


def public_references(text: str) -> list[tuple[int, str, str, str]]:
    """``(line, reference, head, leaf)`` for every public dartdoc reference."""
    found = []
    in_fence = False
    for number, line in enumerate(text.split("\n"), start=1):
        doc = DOC_LINE.match(line)
        if not doc:
            in_fence = False
            continue
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        body = INLINE_CODE.sub("", doc.group(1))
        for match in REFERENCE.finditer(body):
            name = match.group(1).strip()
            name = re.sub(r"^(new|const)\s+", "", name)
            name = name.split("(")[0].strip()
            if name.startswith("_"):
                continue  # the first check's territory
            if not DOTTED_NAME.fullmatch(name):
                continue  # an operator, prose, or an argument list
            segments = name.split(".")
            found.append((number, name, segments[0], segments[-1]))
    return found


def judge_public(
    text: str, known_words: set[str], declared: set[str]
) -> tuple[int, list[tuple[int, str]]]:
    """``(judged, hits)`` for the public references whose existence is decidable.

    A dotted ``[Head.member]`` is only judged when ``Head`` is a type this repo
    declares. Where it is not, the question is whether a member exists on
    somebody else's type, which needs a resolved type index this gate
    deliberately does not have. See the module docstring's third-check section.

    **The head itself is judged when it is one of ours.** Skipping every
    unrecognised head leaves a hole the same size as the check: a reference
    whose *type* was renamed is not decidable by its leaf, so ``[Head.member]``
    passes on a ``Head`` that exists nowhere. ``[TomCrudRepository.save]`` sat
    in ``crud_repository.dart`` -- beside the ``TomRepository`` it meant --
    through every gate, because the head was unknown and the reference was
    therefore never looked at. A ``Tom``-prefixed name is this workspace's own
    vocabulary: if it existed, it would appear in code here, so its absence is
    decidable on exactly the terms the leaf test uses. Other prefixes are left
    alone because they are not: ``RandomAccessFile``, ``EnumName`` and
    ``AgentQuery`` are all real names this tree reaches only through inference
    or a dependency, and judging them would be the wolf-crying the first check
    exists to avoid. All three were measured -- of the twelve dotted references
    whose head appears in no code under ``tom_ai/core``, those three plus
    ``EnumName``'s eight repeats are correct and only the two above are not.
    """
    judged = 0
    hits = []
    for number, name, head, leaf in public_references(text):
        if "." in name and head not in declared:
            if head.startswith(OUR_PREFIX) and head not in known_words:
                judged += 1
                hits.append((number, name))
            continue
        judged += 1
        if leaf not in known_words:
            hits.append((number, name))
    return judged, hits


def past_framed_names(text: str) -> list[tuple[int, str]]:
    """``(line number, name)`` for backticked types framed as superseded."""
    found = []
    in_fence = False
    for number, line in enumerate(text.split("\n"), start=1):
        doc = DOC_LINE.match(line)
        if not doc:
            in_fence = False
            continue
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence or not PAST_FRAMING.search(doc.group(1)):
            continue
        for span in INLINE_CODE.findall(doc.group(1)):
            for name in CAPITALISED.findall(span.strip("`")):
                found.append((number, name))
    return found


# A library shaped like the fault this gate exists to catch: a member renamed
# from `describeAnchoring` to `describe`, leaving the old name pointing at
# nothing. Around it sit the cases each check must *not* report -- a name that
# does exist, a dotted SDK member, a markdown link, inline code, and a fenced
# block -- so the fixture pins the exclusions as firmly as the detection.
SELF_TEST_SOURCE = """\
/// Anchoring, described by [describe].
///
/// Renamed from [describeAnchoring], which now names nothing at all.
/// The private helper [_fold] is here; [_gone] is not.
/// A member of a type we declare is judged: [OpsAnchoring.describe] resolves,
/// [OpsAnchoring.describeAnchoring] does not.
/// A member of a type we do not declare is not judged, however it is
/// spelled: [RandomAccessFile.lockSync], [RandomAccessFile.lockNothing].
/// A markdown [link](https://example.com) is not a reference.
/// Inline `[notARef]` is code, not a reference.
/// The legacy `AnchorSink` was replaced by `TomAuditAnchor`.
///
/// ```dart
/// [alsoNotARef]
/// ```
library;

class OpsAnchoring {
  String describe() => _fold('x');
}

String _fold(String s) => s;
TomAuditAnchor? anchor;
"""


def self_test() -> list[str]:
    """Check the three extractors against [SELF_TEST_SOURCE].

    Run on every invocation. A gate whose extraction silently stops matching
    reports zero faults and is indistinguishable from a clean tree, so these
    assertions live where they cannot be skipped.
    """
    failures = []

    def expect(label: str, actual, wanted) -> None:
        if actual != wanted:
            failures.append(f"{label}: expected {wanted!r}, got {actual!r}")

    text = SELF_TEST_SOURCE
    words = code_words(text)
    names = code_names(text)
    private = code_identifiers(text)
    declared = declared_types(text)

    expect("declared types", sorted(declared), ["OpsAnchoring"])
    expect(
        "public references",
        [(number, name) for number, name, _, _ in public_references(text)],
        [
            (1, "describe"),
            (3, "describeAnchoring"),
            (5, "OpsAnchoring.describe"),
            (6, "OpsAnchoring.describeAnchoring"),
            (8, "RandomAccessFile.lockSync"),
            (8, "RandomAccessFile.lockNothing"),
        ],
    )
    judged, hits = judge_public(text, words, declared)
    # The two RandomAccessFile members are excluded, so the count is 4 -- and
    # `lockNothing` names nothing yet is still not reported, which is the point
    # of the exclusion rather than an accident of the fixture's spelling.
    expect("public references judged", judged, 4)
    expect(
        "public names that exist nowhere",
        hits,
        [(3, "describeAnchoring"), (6, "OpsAnchoring.describeAnchoring")],
    )

    refs = private_references(text)
    expect("private references", refs, [(4, "_fold"), (4, "_gone")])
    expect(
        "private names that exist nowhere",
        [name for _, name in refs if name not in private],
        ["_gone"],
    )

    framed = past_framed_names(text)
    expect("past-framed names", framed, [(11, "AnchorSink"), (11, "TomAuditAnchor")])
    expect(
        "past-framed names that exist nowhere",
        [name for _, name in framed if name not in names],
        ["AnchorSink"],
    )
    return failures


def main(argv: list[str]) -> int:
    broken = self_test()
    if broken:
        for failure in broken:
            print(f"self-test failure: {failure}", file=sys.stderr)
        print("this gate's own extraction is broken; its fault count means "
              "nothing until it is fixed", file=sys.stderr)
        return 2

    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    cache: dict[Path, set[str]] = {}
    checked = 0
    references = 0
    dangling: list[tuple[Path, int, str]] = []
    framed = 0
    vanished: list[tuple[Path, int, str]] = []
    judged = 0
    missing: list[tuple[Path, int, str]] = []

    # The second and third checks judge a name against the *whole* repo's code,
    # so the vocabulary has to be complete before any line can be judged.
    # Scanning the repo rather than `root` keeps a subtree run honest: narrowing
    # the search must not turn a name that exists elsewhere into a reported
    # fault.
    sources = [(p, p.read_text(encoding="utf-8", errors="replace"))
               for p in source_files(REPO_ROOT)]
    known_names: set[str] = set()
    known_words: set[str] = set()
    declared: set[str] = set()
    for _, text in sources:
        known_names |= code_names(text)
        known_words |= code_words(text)
        declared |= declared_types(text)

    for path, text in sources:
        if root != REPO_ROOT and root not in path.parents and path != root:
            continue
        refs = private_references(text)
        if refs:
            checked += 1
            references += len(refs)
            known = library_identifiers(library_of(path, text), cache)
            for number, name in refs:
                if name not in known:
                    dangling.append((path, number, name))
        for number, name in past_framed_names(text):
            framed += 1
            if name not in known_names:
                vanished.append((path, number, name))
        count, hits = judge_public(text, known_words, declared)
        judged += count
        missing.extend((path, number, name) for number, name in hits)

    for path, number, name in dangling:
        rel = path.relative_to(REPO_ROOT)
        print(f"{rel}:{number}: [{name}] resolves to nothing in this library")
    for path, number, name in vanished:
        rel = path.relative_to(REPO_ROOT)
        print(f"{rel}:{number}: `{name}` is framed as superseded but appears in "
              f"no code in this repo -- the reader cannot look it up")
    for path, number, name in missing:
        rel = path.relative_to(REPO_ROOT)
        print(f"{rel}:{number}: [{name}] names nothing in this repo -- no import "
              f"can fix it, so the name is wrong")

    print()
    print(f"files with private dartdoc references : {checked}")
    print(f"private references checked            : {references}")
    print(f"references resolving to nothing       : {len(dangling)}")
    print(f"backticked names framed as superseded : {framed}")
    print(f"  of those, naming nothing in the repo: {len(vanished)}")
    print(f"public references checked             : {judged}")
    print(f"  of those, naming nothing in the repo: {len(missing)}")
    return report_faults(len(dangling) + len(vanished) + len(missing))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
