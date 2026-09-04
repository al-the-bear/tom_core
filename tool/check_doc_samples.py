#!/usr/bin/env python3
"""Find Dart samples in the docs that call a constructor the wrong way.

Run from anywhere::

    python3 tool/check_doc_samples.py                  # the whole repo
    python3 tool/check_doc_samples.py tom_core_server  # one subtree

Exits non-zero when any sample is wrong, so it can gate a build.

Four faults are reported. The first two are the two halves of one mistake:

``POSITIONAL``
    A constructor declared to take named parameters only, called with a
    positional argument -- ``TomFileAuditSink(Directory('/var/audit'))`` where
    the signature is ``{required Directory directory, ...}``.
``NAMED``
    The reverse: a constructor whose first parameter is a required positional,
    called with a named argument first.

The third counts rather than classifies:

``ARITY``
    A call passing the wrong *number* of arguments --
    ``LiveAppBackend(auth, api)`` against a three-parameter constructor. Style
    and count are independent failures: that call is positional against a
    positional signature, so the two rules above pass it, and for a year no
    arity fault could be reported because none could be detected.

    **Only for a parameter list that is entirely required and positional** --
    no ``[`` optional group, no ``{`` named group, no ``=`` default. For those
    the required count is a single number decidable from the declaration text,
    so a call whose top-level argument count differs is wrong with no context
    needed. The moment a list carries any of the three the requirement becomes
    a range, and a range is not what this file reports; ``parameter_arity``
    returns ``None`` and the constructor is skipped. That is the narrow,
    provably-noise-free slice, chosen over the wider one for the reason the
    closing line of this docstring gives.

    Both sides are counted by one scanner, which splits on commas at bracket
    depth one and ignores a trailing comma. It differs between the two only
    over angle brackets: in a declaration a ``<`` is always a type argument and
    nests cleanly, so it is tracked; in a call it may be a comparison, so a
    top-level ``<`` or ``>`` abandons the count instead of risking a wrong
    split. ``=>`` is exempt from that, being a lambda arrow and never a
    comparison -- without the exemption every sample passing a callback would
    drop out of the check.

The fourth is about a keyword rather than a bracket:

``CONST``
    A const instance of a class that has no ``const`` constructor. This is the
    fault that rots *silently*: a sample written when the constructor was const
    stays on the page unchanged after someone drops the modifier, and nothing in
    the build notices. It happened here -- ``TomEmptyState`` gave up its
    ``const`` so that a missing title would fail at the call site, and
    ``custom/readme.md`` went on showing a const one.

    Both written forms count, because both are const: the direct
    ``const Foo(...)`` and the declaration ``const x = Foo(...)`` /
    ``const Foo x = Foo(...)``. The second is worth its extra regex -- it is
    what the module readmes' quick-start sections are written in, and a
    first cut of this check that recognised only the direct form was silent on
    the ``TomEmptyState`` regression that prompted the whole fault. A check that
    misses the case that motivated it is worth nothing; the mutation test that
    put the defect back is what caught that.

    Only an explicit ``const`` keyword is matched. Inside a const context
    (``const [Foo(), Bar()]``) the inner calls are const without saying so, and
    catching those would mean tracking the context. A ``const`` followed by a
    ``{`` or ``[`` parameter list is skipped as well -- that is a signature the
    document is *quoting*, not a call it is making. That last skip is why a
    handful of documents can show ``const TomElevatedButton({ ... })`` without
    being reported: they are quoting a declaration, and whether the *real*
    declaration carries ``const`` is a different question than this tool asks.

**Why this reads text rather than compiling.** Running every fence through the
analyzer is a separate gate -- ``check_doc_dart_blocks.py`` -- and the two are
not substitutes. That one wraps a block in each context a sample can occupy and
asks whether it parses and whether the framework names in it resolve; it needs
a scratch package, a `pub get` and the Dart toolchain, and it says nothing
about a call whose arguments are the wrong *shape* for a constructor that does
exist. This one needs nothing but the files, runs over the whole repository
rather than the packages that gate has been triaged for, and answers exactly
that question.

So this takes the part decidable from the text alone. Whether a call is
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
with more than one constructor signature of the same name across files.

**Text inside a ``//`` comment is not checked, and that is a documentation
convention rather than a limitation to be lifted.** ``strip_noise`` blanks
comments before any matching, because prose is the one real source of false
positives here -- ``// principal.user -> TomUser (name, email)`` reads as a
positional call to anything that only looks at brackets, and no tightening of
the pattern makes English stop resembling Dart. The consequence is a rule for
the documents: **an API construction is written as real code, never as comment
prose.** ``// or LiveAppBackend(auth, api)`` rots exactly like code and is
checked by nothing; the same claim written as a second fenced line, or as the
call the sample actually makes, is inside this gate's field of view. A comment
may say *why* a constructor is called as it is; it may not be where the call
itself is shown.

A rule that never cries wolf is one people leave switched on.
"""

from __future__ import annotations

import re
import sys
from itertools import chain
from pathlib import Path

from gate_report import report_faults

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
CONSTRUCTOR = re.compile(
    r"(?:^|\n)[ \t]*(?P<mods>(?:const\s+|factory\s+)*)(?P<name>\w+)"
    r"(?:\.(?P<named>\w+))?\s*\("
)
CALL = re.compile(r"\b([A-Z]\w*)(?:<[\w<>,\s?]*>)?(?:\.(\w+))?\s*\(")
# A sample explicitly asking for a const instance, in its two written forms:
# the direct `const Foo(...)`, and the declaration `const x = Foo(...)` /
# `const Foo x = Foo(...)`. Both are equally const and equally illegal against a
# non-const constructor. The second form is the one worth the extra regex -- it
# is what the quick-start sections of the module readmes are written in, and a
# checker that saw only the first would have missed the `TomEmptyState`
# regression that prompted this fault in the first place.
#
# Only an explicit `const` is matched. Inside a const context
# (`const [Foo(), Bar()]`) the inner calls are const without saying so, and
# reporting those would need the context tracked.
CONST_CALL = re.compile(
    r"\bconst\s+(?P<cls>[A-Z]\w*)(?:<[\w<>,\s?]*>)?(?:\.(?P<named>\w+))?\s*\("
)
CONST_ASSIGN = re.compile(
    r"\bconst[ \t]+(?:[\w<>,?]+[ \t]+)*?\w+[ \t]*=[ \t]*"
    r"(?P<cls>[A-Z]\w*)(?:<[\w<>,\s?]*>)?(?:\.(?P<named>\w+))?[ \t]*\("
)
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


def top_level_segments(text: str, paren: int, *, generics: bool) -> list[str] | None:
    """The comma-separated parts of the bracketed list opening at ``paren``.

    Splits on commas at depth one, so nested calls, collections and function
    types stay whole, and drops an empty trailing part so ``(a, b,)`` counts
    two. Comments and string bodies inside the list are stepped over -- a comma
    in either is punctuation, not a separator.

    ``None`` means "do not answer": the list is unterminated (the fence showed
    only part of the call), a block comment never closes, or -- with
    ``generics`` off -- a bare ``<`` or ``>`` appears at the top level. That
    last one is the whole reason the flag exists. In a *declaration* an angle
    bracket is always a type argument and nests cleanly, so it is tracked; in a
    *call* it may be a comparison, and there is no way to tell which from the
    text. Guessing would split ``Foo(a < b, c)`` into three parts and report a
    fault that is not there, so the count is abandoned instead. ``=>`` is the
    one exemption -- a lambda arrow is never a comparison, and without it every
    sample that passes a callback would drop out of the check.
    """
    depth = 0
    angle = 0
    segments: list[str] = []
    buf: list[str] = []
    i = paren
    n = len(text)
    while i < n:
        char = text[i]
        pair = text[i:i + 2]
        if pair == "//":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if pair == "/*":
            close = text.find("*/", i + 2)
            if close == -1:
                return None
            i = close + 2
            continue
        if pair == "=>":
            buf.append(pair)
            i += 2
            continue
        if char in "'\"":
            quote = char
            j = i + 1
            while j < n and text[j] != quote:
                j += 2 if text[j] == "\\" else 1
            if j >= n:
                return None
            buf.append(text[i:j + 1])
            i = j + 1
            continue
        if char in "([{":
            depth += 1
            if depth == 1:
                i += 1
                continue  # the opening bracket itself is not content
        elif char in ")]}":
            depth -= 1
            if depth == 0:
                segments.append("".join(buf))
                return [part for part in (s.strip() for s in segments) if part]
        elif char == "<" or char == ">":
            if not generics:
                return None
            angle += 1 if char == "<" else -1
            angle = max(angle, 0)
        elif char == "," and depth == 1 and angle == 0:
            segments.append("".join(buf))
            buf = []
            i += 1
            continue
        buf.append(char)
        i += 1
    return None


def parameter_arity(text: str, paren: int) -> int | None:
    """How many arguments a call on the declaration at ``paren`` must pass.

    ``None`` whenever that is not a single number. An optional-positional
    ``[`` group, a named ``{`` group or an ``=`` default each turn the
    requirement into a range, and this check reports counts rather than ranges
    -- see the ``ARITY`` entry in the module docstring for why the slice is
    drawn there.
    """
    segments = top_level_segments(text, paren, generics=True)
    if segments is None:
        return None
    if any(bracket in segment for segment in segments for bracket in "[{="):
        return None
    return len(segments)


def call_arity(text: str, paren: int) -> int | None:
    """How many arguments the call at ``paren`` passes, or ``None`` if the
    text does not say unambiguously."""
    segments = top_level_segments(text, paren, generics=False)
    return None if segments is None else len(segments)


def package_of(path: Path) -> Path | None:
    """The nearest ancestor of ``path`` holding a ``pubspec.yaml``."""
    for parent in path.parents:
        if (parent / "pubspec.yaml").is_file():
            return parent
        if parent == REPO_ROOT:
            break
    return None


Index = dict[Path, dict[tuple[str, str], set[str]]]
# ``package -> (class, constructor name) -> {is it declared const}``. A set,
# not a bool, for the same reason ``Index`` holds a set of styles: two files
# declaring the same name differently leave no single rule to apply.
ConstIndex = dict[Path, dict[tuple[str, str], set[bool]]]
# ``package -> (class, constructor name) -> {required argument count}``, with
# ``None`` in the set for a declaration whose count is not a single number. A
# set again, and for the sharper version of the same reason: a name declared
# decidably in one file and undecidably in another yields ``{2, None}``, whose
# size alone disqualifies it -- the undecidable declaration cannot be silently
# outvoted by the decidable one.
ArityIndex = dict[Path, dict[tuple[str, str], set[int | None]]]


def constructor_index(root: Path) -> tuple[Index, ConstIndex, ArityIndex]:
    """``package -> (class, constructor name) -> {styles}``, and the same
    keys mapped to whether the declaration carries ``const`` and to how many
    arguments it requires.

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
    consts: ConstIndex = {}
    arities: ArityIndex = {}
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
            name = match.group("name")
            if name not in declared:
                continue  # a method call or a nested function, not a constructor
            key = (name, match.group("named") or "")
            styles = index.setdefault(package, {}).setdefault(key, set())
            styles.add(parameter_style(text, match.end() - 1))
            consts.setdefault(package, {}).setdefault(key, set()).add(
                "const" in match.group("mods")
            )
            arities.setdefault(package, {}).setdefault(key, set()).add(
                parameter_arity(text, match.end() - 1)
            )
    return index, consts, arities


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


def audit(path: Path, index: Index, consts: ConstIndex,
          arities: ArityIndex) -> list[tuple[int, str, str]]:
    """``(line, fault, detail)`` for every miscalled constructor in ``path``."""
    package = package_of(path)
    if package is None:
        return []  # a document outside any package -- nothing to resolve against
    constructors = index.get(package, {})
    constness = consts.get(package, {})
    required = arities.get(package, {})
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return []
    faults = []
    for first_line, block in fenced_dart(text):
        clean = strip_noise(block)
        for match in chain(CONST_CALL.finditer(clean),
                           CONST_ASSIGN.finditer(clean)):
            key = (match.group("cls"), match.group("named") or "")
            declared = constness.get(key)
            if declared is None or len(declared) != 1:
                continue  # unknown, or declared both ways across files
            if next(iter(declared)):
                continue  # genuinely const
            if parameter_style(clean, match.end() - 1) != POSITIONAL:
                continue  # `const Foo({` -- the signature, not a call
            label = key[0] + ("." + key[1] if key[1] else "")
            line = first_line + clean[: match.start()].count("\n")
            faults.append(
                (line, "CONST", f"{label} has no const constructor")
            )
        for match in CALL.finditer(clean):
            key = (match.group(1), match.group(2) or "")
            paren = match.end() - 1
            label = key[0] + ("." + key[1] if key[1] else "")
            line = first_line + clean[: match.start()].count("\n")
            argument = first_argument(clean, paren)
            # A document quoting the signature rather than calling it. Checked
            # once here because both rules below need the same exemption.
            quoted = argument is not None and DECLARATION.match(argument)

            counts = required.get(key)
            if counts is not None and len(counts) == 1 and not quoted:
                expected = next(iter(counts))
                passed = call_arity(clean, paren)
                # `None` on either side is this check declining to answer, not
                # agreement: an undecidable signature or an unreadable call.
                if (expected is not None and passed is not None
                        and passed != expected
                        and parameter_style(clean, paren) != NAMED_ONLY):
                    plural = "" if expected == 1 else "s"
                    faults.append((
                        line, "ARITY",
                        f"{label} takes {expected} argument{plural}, "
                        f"the sample passes {passed}",
                    ))

            styles = constructors.get(key)
            if styles is None or len(styles) != 1:
                continue  # unknown, or overloaded across files -- no single rule
            style = next(iter(styles))
            if style == EMPTY:
                continue
            if parameter_style(clean, paren) != POSITIONAL:
                continue  # `Foo({` / `Foo([` -- a signature, not a call
            if not argument:
                continue  # empty call, or a call the fence cut in half
            if quoted:
                continue  # this is the signature being documented, not a call
            is_named = re.match(r"^\w+\s*:", argument) is not None
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

    index, consts, arities = constructor_index(REPO_ROOT)

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
        for line, fault, detail in audit(path, index, consts, arities):
            faults.append((path, line, fault, detail))

    for path, line, fault, detail in faults:
        print(f"{path.relative_to(REPO_ROOT)}:{line}: {fault} -- {detail}")

    print()
    indexed = sum(len(package) for package in index.values())
    print(f"constructors indexed     : {indexed} in {len(index)} packages")
    print(f"documents with samples   : {documents}")
    print(f"dart samples checked     : {samples}")
    print(f"miscalled constructors   : {len(faults)}")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
