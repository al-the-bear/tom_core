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

Existence is decided by looking for the identifier anywhere in the library's
code -- deliberately lenient. The point is to catch names that vanished, not to
police whether a reference points at a declaration rather than a local. A
lenient rule that never cries wolf is one people leave switched on.
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


def main(argv: list[str]) -> int:
    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    cache: dict[Path, set[str]] = {}
    checked = 0
    references = 0
    dangling: list[tuple[Path, int, str]] = []

    for path in source_files(root):
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        refs = private_references(text)
        if not refs:
            continue
        checked += 1
        references += len(refs)
        known = library_identifiers(library_of(path, text), cache)
        for number, name in refs:
            if name not in known:
                dangling.append((path, number, name))

    for path, number, name in dangling:
        rel = path.relative_to(REPO_ROOT)
        print(f"{rel}:{number}: [{name}] resolves to nothing in this library")

    print()
    print(f"files with private dartdoc references : {checked}")
    print(f"private references checked            : {references}")
    print(f"references resolving to nothing       : {len(dangling)}")
    return 1 if dangling else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
