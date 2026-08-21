#!/usr/bin/env python3
"""Find Dart samples in the docs that call a constructor the wrong way.

Run from anywhere::

    python3 tool/check_doc_samples.py                  # the whole repo
    python3 tool/check_doc_samples.py tom_core_server  # one subtree

Exits non-zero when any sample is wrong, so it can gate a build.

Two faults are reported, and they are the two halves of the same mistake:

``POSITIONAL``
    A constructor declared to take named parameters only, called with a
    positional argument -- ``TomFileAuditSink(Directory('/var/audit'))`` where
    the signature is ``{required Directory directory, ...}``.
``NAMED``
    The reverse: a constructor whose first parameter is a required positional,
    called with a named argument first.

**Why not just compile the samples.** The obvious guard is to extract every
```dart fence and analyze it, and that is a much larger job than it sounds:
there are 1500-odd fences in this tree and the great majority are fragments --
no imports, undefined variables, a method body with no class around it. Making
them compilable means writing a harness per sample, and a check that expensive
to satisfy gets switched off.

This takes the part that is decidable from the text alone. Whether a call is
positional or named is visible in the call; whether the constructor accepts
that is visible in the signature; neither needs the surrounding program. It is
a narrow slice of "does the sample compile", but it is the slice that catches
the copy-paste failure -- a reader pastes the shortest snippet in the document,
and the shortest snippet is the one nobody re-checked after the signature grew
a named parameter.

Coverage is deliberately bounded by the same rule. A call is only checked
against a constructor declared in **its own package's ``lib/``**: without an
import graph there is no way to tell a genuine cross-package reference from a
name collision, and the collisions are the common case -- the `User` a document
sketches inside its own fence is not some other package's `User`. Argument
shapes that cannot be resolved without a parser are skipped too, as are classes
with more than one constructor signature of the same name across files. A rule
that never cries wolf is one people leave switched on.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

SKIP_DIRS = {".dart_tool", "build", ".git", "node_modules", "__pycache__"}
SKIP_SUFFIXES = (".reflection.dart", "_generated.dart", "_bridges.dart", ".g.dart")

CLASS = re.compile(
    r"^(?:abstract\s+|final\s+|base\s+|interface\s+|sealed\s+|mixin\s+)*"
    r"class\s+(\w+)",
    re.M,
)
# A constructor at the start of a line: `Foo(`, `Foo.named(`, `const Foo(`,
# `factory Foo.x(`. The class-name guard below rejects the method calls this
# also matches.
CONSTRUCTOR = re.compile(r"(?:^|\n)[ \t]*(?:const\s+|factory\s+)*(\w+)(?:\.(\w+))?\s*\(")
CALL = re.compile(r"\b([A-Z]\w*)(?:<[\w<>,\s?]*>)?(?:\.(\w+))?\s*\(")
FENCE_OPEN = re.compile(r"^\s*```dart\s*$")
FENCE_CLOSE = re.compile(r"^\s*```\s*$")
LINE_COMMENT = re.compile(r"//.*$", re.M)
STRING = re.compile(r"""'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*\"""")

NAMED_ONLY = "named-only"
POSITIONAL = "positional"
EMPTY = "empty"


def dart_files(root: Path):
    """Every library source file under ``root``.

    ``lib/`` only. A class declared in ``example/`` or ``test/`` is not part of
    the package's API, so a document is never documenting it -- but scratch
    classes there carry the most ordinary names (`User`, `Item`), which is
    exactly what collides with the throwaway types a document sketches inside
    its own fence.
    """
    for path in sorted(root.rglob("*.dart")):
        if SKIP_DIRS & set(path.parts):
            continue
        if "lib" not in path.parts:
            continue
        if path.name.endswith(SKIP_SUFFIXES):
            continue
        yield path


def parameter_style(text: str, paren: int) -> str:
    """Classify a parameter list by its first character after ``(``."""
    i = paren + 1
    while i < len(text) and text[i] in " \t\n":
        i += 1
    if i >= len(text):
        return EMPTY
    if text[i] == ")":
        return EMPTY
    if text[i] == "{":
        return NAMED_ONLY
    if text[i] == "[":
        # Optional positionals only -- calling it either way is fine.
        return EMPTY
    return POSITIONAL


def package_of(path: Path) -> Path | None:
    """The nearest ancestor of ``path`` holding a ``pubspec.yaml``."""
    for parent in path.parents:
        if (parent / "pubspec.yaml").is_file():
            return parent
        if parent == REPO_ROOT:
            break
    return None


Index = dict[Path, dict[tuple[str, str], set[str]]]


def constructor_index(root: Path) -> Index:
    """``package -> (class, constructor name) -> {styles}``.

    **Indexed per package, and a document is only checked against its own
    package.** Indexing repository-wide is the tempting shortcut -- a document
    does routinely construct another package's types -- but without an import
    graph it cannot tell a real cross-package reference from a name collision,
    and collisions are common: a `User` sketched inside a `beanlocator.md`
    fence is not `todo_domain`'s `User`, and `tom_doc_specs`' `ValidationError`
    is not the forms one. Every such pair reads as a fault. Checking only
    same-package references gives up the cross-package half of the corpus and
    keeps the half that can be decided.
    """
    index: Index = {}
    for path in dart_files(root):
        package = package_of(path)
        if package is None:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        declared = {m.group(1) for m in CLASS.finditer(text)}
        if not declared:
            continue
        for match in CONSTRUCTOR.finditer(text):
            name = match.group(1)
            if name not in declared:
                continue  # a method call or a nested function, not a constructor
            key = (name, match.group(2) or "")
            styles = index.setdefault(package, {}).setdefault(key, set())
            styles.add(parameter_style(text, match.end() - 1))
    return index


def strip_noise(block: str) -> str:
    """Blank out comments and string bodies, preserving offsets.

    Prose inside a `//` comment is the one real source of false positives --
    "`// principal.user -> TomUser (name, email)`" reads as a positional call to
    anything that only looks at brackets.
    """
    out = LINE_COMMENT.sub(lambda m: " " * len(m.group(0)), block)
    out = STRING.sub(lambda m: m.group(0)[0] + " " * (len(m.group(0)) - 2) + m.group(0)[-1], out)
    return out


def first_argument(text: str, paren: int) -> str | None:
    """The source of the first argument of the call opening at ``paren``."""
    depth = 1
    i = paren + 1
    buf: list[str] = []
    while i < len(text):
        char = text[i]
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
            if depth == 0:
                break
        elif char == "," and depth == 1:
            break
        buf.append(char)
        i += 1
    else:
        return None  # unterminated -- the fence showed only part of the call
    return "".join(buf).strip()


DECLARATION = re.compile(
    r"^(required\s|covariant\s|this\.|super\.)"
    r"|^[\w<>,\s?]+\s+\w+\s*(=|$)"
)


def fenced_dart(text: str):
    """``(first line number, block source)`` for every ```dart fence."""
    lines = text.split("\n")
    index = 0
    while index < len(lines):
        if FENCE_OPEN.match(lines[index]):
            start = index + 1
            end = start
            while end < len(lines) and not FENCE_CLOSE.match(lines[end]):
                end += 1
            yield start + 1, "\n".join(lines[start:end])
            index = end
        index += 1


def audit(path: Path, index: Index) -> list[tuple[int, str, str]]:
    """``(line, fault, detail)`` for every miscalled constructor in ``path``."""
    package = package_of(path)
    if package is None:
        return []  # a document outside any package -- nothing to resolve against
    constructors = index.get(package, {})
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return []
    faults = []
    for first_line, block in fenced_dart(text):
        clean = strip_noise(block)
        for match in CALL.finditer(clean):
            key = (match.group(1), match.group(2) or "")
            styles = constructors.get(key)
            if styles is None or len(styles) != 1:
                continue  # unknown, or overloaded across files -- no single rule
            style = next(iter(styles))
            if style == EMPTY:
                continue
            if parameter_style(clean, match.end() - 1) != POSITIONAL:
                continue  # `Foo({` / `Foo([` -- a signature, not a call
            argument = first_argument(clean, match.end() - 1)
            if not argument:
                continue  # empty call, or a call the fence cut in half
            if DECLARATION.match(argument):
                continue  # this is the signature being documented, not a call
            is_named = re.match(r"^\w+\s*:", argument) is not None
            label = key[0] + ("." + key[1] if key[1] else "")
            line = first_line + clean[: match.start()].count("\n")
            if style == NAMED_ONLY and not is_named:
                faults.append(
                    (line, "POSITIONAL", f"{label} takes named parameters only")
                )
            elif style == POSITIONAL and is_named:
                faults.append(
                    (line, "NAMED", f"{label} takes a positional argument first")
                )
    return faults


def main(argv: list[str]) -> int:
    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    index = constructor_index(REPO_ROOT)

    documents = 0
    samples = 0
    faults: list[tuple[Path, int, str, str]] = []
    for path in sorted(root.rglob("*.md")):
        if SKIP_DIRS & set(path.parts):
            continue
        try:
            blocks = list(fenced_dart(path.read_text(encoding="utf-8")))
        except OSError:
            continue
        if not blocks:
            continue
        documents += 1
        samples += len(blocks)
        for line, fault, detail in audit(path, index):
            faults.append((path, line, fault, detail))

    for path, line, fault, detail in faults:
        print(f"{path.relative_to(REPO_ROOT)}:{line}: {fault} -- {detail}")

    print()
    indexed = sum(len(package) for package in index.values())
    print(f"constructors indexed     : {indexed} in {len(index)} packages")
    print(f"documents with samples   : {documents}")
    print(f"dart samples checked     : {samples}")
    print(f"miscalled constructors   : {len(faults)}")
    return 1 if faults else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
