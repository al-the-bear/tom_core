#!/usr/bin/env python3
"""Find dartdoc that names a consumer which does not consume.

Run from anywhere::

    python3 tool/check_consumer_claims.py                  # whole repo
    python3 tool/check_consumer_claims.py tom_flutter_ui   # one subtree

Exits non-zero when a claim is unbacked, so it can gate a build.

A *consumer claim* is a dartdoc sentence of the form "Used by ``[TomFoo]``" --
prose that tells the reader where this code is already wired in. It is the most
load-bearing sentence a widget's opening paragraph can carry, because it is the
one a reader uses to decide what the thing is *for*. ``TomEmptyState`` opened
with "Used by ``TomListForm`` when its bound list is empty", and ``TomListForm``
is a pure model with no Flutter import and no ``build`` -- it cannot compose a
widget at all. Nobody misread the sentence; it was simply false, and it had been
false since the file was written.

**Why this needs its own checker.** The neighbouring ``check_dartdoc_refs.py``
cannot catch it, and deliberately so: it checks only *private* names, because
for public ones "does it resolve?" reopens the import-scope question its
docstring declines to fight. But resolution was never the problem here.
``[TomListForm]`` resolves perfectly -- it names a real, exported, correctly
spelled class. The reference is well-formed and the claim about it is wrong.
Link checking and fact checking are different questions, and only the second one
was being asked.

**Why a checker rather than a careful read.** Measured before writing: across
``tom_flutter_ui`` twenty-four dartdoc lines say "used by", but only three name a
specific in-package type -- and two of those three were false. One pointed at a
model that cannot render; the other at ``TomMasterDetailScaffold``, a class
deleted on purpose and documented as deleted two files away. A two-in-three
failure rate on a small population is exactly the shape that rewards mechanical
checking: too rare for a reviewer to expect, too wrong to leave.

The claims decay silently. Nothing about deleting a class visits the prose in
the files that mentioned it, and the surviving sentence still reads fluently --
which is why ``TomMasterDetailScaffold`` kept being recommended by a document
that also, elsewhere, explained its removal.

**What counts as backed** is deliberately lenient: the named consumer's own code
-- excluding its doc comments, since a mention in prose is not a use -- must
reference at least one public name declared by the claiming library. That
tolerates indirection through any of a library's exports and asks only the
question the reader actually cares about: is there a wire here at all? A rule
that never cries wolf is one people leave switched on.

**A claimed consumer that does not exist** is reported separately, and is the
reason the index is always built from the whole repo even when only a subtree is
being checked: ``[TomEmptyState]`` is declared in ``tom_flutter_ui`` but
``[TomForm]`` is not, so a subtree-scoped index would call every cross-package
consumer missing. Repo-wide, a ``Tom``-prefixed name that is declared nowhere
did not move -- it was deleted, and the sentence recommending it outlived it.
The prefix restriction is what keeps this honest: names from outside the
workspace are unresolvable here and stay unjudged.
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

# "used by", "used only by", "is used by" -- the claim opener in any casing.
CLAIM = re.compile(r"\bused\s+(?:\w+\s+){0,2}?by\b", re.I)
# A name the claim points at: a dartdoc reference or an inline-code span.
NAMED = re.compile(r"\[([A-Z]\w+)\]|`([A-Z]\w+)`")
# How far past "used by" a named consumer is still part of the same claim.
# One clause, not one paragraph: past this, "used by the caller ... see [Foo]"
# would start reading the cross-reference as a consumer.
CLAIM_WINDOW = 90

TYPE_DECLARATION = re.compile(
    r"^\s*(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+)*"
    r"(?:mixin\s+class|class|mixin|enum|extension\s+type|extension|typedef)"
    r"\s+([A-Z]\w+)",
    re.M,
)
# A top-level function: a declaration starting in column zero. Members are
# indented, so this needs no brace tracking.
TOP_LEVEL_FUNCTION = re.compile(r"^[\w<>,?\[\] ]+?\s+([a-z]\w+)\s*(?:<[^>]*>)?\s*\(", re.M)

PART_OF = re.compile(r"""^\s*part\s+of\s+['"]([^'"]+)['"]\s*;""", re.M)
PART = re.compile(r"""^\s*part\s+['"]([^'"]+)['"]\s*;""", re.M)


def source_files(root: Path) -> list[Path]:
    out = []
    for path in sorted(root.rglob("*.dart")):
        if SKIP_DIRS & set(path.parts):
            continue
        if path.name.endswith(SKIP_SUFFIXES):
            continue
        out.append(path)
    return out


def code_of(text: str) -> str:
    """The file with its doc comments removed.

    A name appearing only in prose is a mention, not a use -- and counting
    mentions would let two files vouch for each other with nothing between
    them but the claims themselves.
    """
    return "\n".join(ln for ln in text.split("\n") if not DOC_LINE.match(ln))


def declared_names(text: str) -> set[str]:
    code = code_of(text)
    names = set(TYPE_DECLARATION.findall(code))
    names |= {
        name
        for name in TOP_LEVEL_FUNCTION.findall(code)
        if name not in {"if", "for", "while", "switch", "catch", "return"}
    }
    return names


def library_root(path: Path, text: str) -> Path:
    """The file owning ``path``'s library -- itself, unless it is a part."""
    match = PART_OF.search(text)
    if match and match.group(1).endswith(".dart"):
        resolved = (path.parent / match.group(1)).resolve()
        if resolved.exists():
            return resolved
    return path


def doc_blocks(text: str) -> list[tuple[int, str]]:
    """``(first line number, joined text)`` per contiguous ``///`` run.

    Joined because a claim wraps: "Used by [TomMasterDetailListForm] for
    selection changes and by route / pop guards" is one sentence across two
    comment lines, and a line-at-a-time scan sees neither half whole.
    """
    blocks: list[tuple[int, str]] = []
    start = 0
    parts: list[str] = []
    in_fence = False
    for number, line in enumerate(text.split("\n"), start=1):
        doc = DOC_LINE.match(line)
        if not doc:
            if parts:
                blocks.append((start, " ".join(parts)))
            parts, in_fence = [], False
            continue
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if not parts:
            start = number
        parts.append(doc.group(1).strip())
    if parts:
        blocks.append((start, " ".join(parts)))
    return blocks


def claims(text: str) -> list[tuple[int, str]]:
    """``(line number, claimed consumer)`` for every named-consumer claim."""
    found: list[tuple[int, str]] = []
    for number, block in doc_blocks(text):
        for opener in CLAIM.finditer(block):
            window = block[opener.end() : opener.end() + CLAIM_WINDOW]
            for match in NAMED.finditer(window):
                found.append((number, match.group(1) or match.group(2)))
    return found


def main(argv: list[str]) -> int:
    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    # Indexed repo-wide, reported subtree-only: see the module docstring on
    # why a subtree-scoped index cannot tell "deleted" from "elsewhere".
    text_of: dict[Path, str] = {}
    for path in source_files(REPO_ROOT):
        try:
            text_of[path] = path.read_text(encoding="utf-8")
        except OSError:
            continue

    # Where each public type is declared. A name declared twice is ambiguous
    # and gets dropped: with two candidate consumers there is no single file
    # whose code answers the question.
    declaring: dict[str, Path | None] = {}
    exports: dict[Path, set[str]] = {}
    for path, text in text_of.items():
        names = declared_names(text)
        exports.setdefault(library_root(path, text), set()).update(names)
        for name in names:
            if not re.fullmatch(r"[A-Z]\w+", name):
                continue
            declaring[name] = None if name in declaring else path

    # Parts contribute their code to the library that owns them.
    code_cache: dict[Path, str] = {}

    def library_code(path: Path) -> str:
        if path in code_cache:
            return code_cache[path]
        code_cache[path] = ""
        text = text_of.get(path, "")
        chunks = [code_of(text)]
        for part in PART.findall(text):
            resolved = (path.parent / part).resolve()
            if resolved != path and resolved in text_of:
                chunks.append(library_code(resolved))
        code_cache[path] = "\n".join(chunks)
        return code_cache[path]

    checked = 0
    total = 0
    unbacked: list[tuple[Path, int, str, str]] = []
    missing: list[tuple[Path, int, str]] = []

    for path in source_files(root):
        text = text_of.get(path)
        if text is None:
            continue
        found = claims(text)
        if not found:
            continue
        library = library_root(path, text)
        offered = exports.get(library, set())
        seen: set[tuple[int, str]] = set()
        for number, name in found:
            if (number, name) in seen:
                continue
            seen.add((number, name))
            if name not in declaring:
                # Only workspace types are judged: anything else is declared
                # outside this repo and its absence here means nothing.
                if name.startswith("Tom"):
                    total += 1
                    missing.append((path, number, name))
                continue
            consumer = declaring.get(name)
            if consumer is None or consumer == path:
                # Ambiguous (declared twice) or self-referential -- nothing
                # this checker can decide, so it stays quiet.
                continue
            total += 1
            code = library_code(library_root(consumer, text_of[consumer]))
            if not any(re.search(rf"\b{re.escape(n)}\b", code) for n in offered):
                unbacked.append(
                    (path, number, name, str(consumer.relative_to(REPO_ROOT)))
                )
        checked += 1

    for path, number, name in missing:
        rel = path.relative_to(REPO_ROOT)
        print(f"{rel}:{number}: claims [{name}] uses this, but no such type "
              f"is declared anywhere in the repo")

    for path, number, name, consumer in unbacked:
        rel = path.relative_to(REPO_ROOT)
        print(f"{rel}:{number}: claims [{name}] uses this, but {consumer} "
              f"references nothing this library declares")

    print()
    print(f"files with a named-consumer claim : {checked}")
    print(f"resolvable claims checked         : {total}")
    print(f"claims naming a type that is gone : {len(missing)}")
    print(f"claims not backed by any use      : {len(unbacked)}")
    return report_faults(len(missing) + len(unbacked))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
