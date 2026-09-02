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
import question to get wrong. That makes this check total for the one case the
lint cannot express: a reference that names *nothing at all*, which is what a
renamed member leaves behind.

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
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

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


def code_names(text: str) -> set[str]:
    """Every capitalised identifier appearing outside a doc comment."""
    lines = [ln for ln in text.split("\n") if not DOC_LINE.match(ln)]
    return set(CAPITALISED.findall("\n".join(lines)))


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


def main(argv: list[str]) -> int:
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

    # The second check judges a name against the *whole* repo's code, so the
    # vocabulary has to be complete before any line can be judged. Scanning the
    # repo rather than `root` keeps a subtree run honest: narrowing the search
    # must not turn a name that exists elsewhere into a reported fault.
    sources = [(p, p.read_text(encoding="utf-8", errors="replace"))
               for p in source_files(REPO_ROOT)]
    known_names: set[str] = set()
    for _, text in sources:
        known_names |= code_names(text)

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

    for path, number, name in dangling:
        rel = path.relative_to(REPO_ROOT)
        print(f"{rel}:{number}: [{name}] resolves to nothing in this library")
    for path, number, name in vanished:
        rel = path.relative_to(REPO_ROOT)
        print(f"{rel}:{number}: `{name}` is framed as superseded but appears in "
              f"no code in this repo -- the reader cannot look it up")

    print()
    print(f"files with private dartdoc references : {checked}")
    print(f"private references checked            : {references}")
    print(f"references resolving to nothing       : {len(dangling)}")
    print(f"backticked names framed as superseded : {framed}")
    print(f"  of those, naming nothing in the repo: {len(vanished)}")
    return 1 if dangling or vanished else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
