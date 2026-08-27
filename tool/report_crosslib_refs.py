#!/usr/bin/env python3
"""Count dartdoc ``[Name]`` refs naming a repo type not in the writer's scope.

Run from anywhere::

    python3 tool/report_crosslib_refs.py                  # whole repo
    python3 tool/report_crosslib_refs.py tom_flutter_ui   # one subtree

**This reports; it does not gate.** It is named ``report_`` rather than
``check_`` for that reason, and it always exits 0. Its siblings in this folder
fail a build when they find something; this one must not, because what it finds
is not by itself a defect.

**What it is for.** ``check_dartdoc_refs.py`` deliberately checks only *private*
names, and its docstring explains why the public case is left alone: satisfying
it would mean adding imports that exist only for prose, some of them cycles.
That decision rests on the claim that the affected population is large and not
mechanically triageable -- and a claim like that decays silently, which is
precisely the failure the checkers in this folder exist to catch. So the numbers
quoted there are produced here, and can be reproduced here.

At the time of writing: **353 of 5556** judged references repo-wide do not
resolve from the library writing them; ``tom_flutter_ui`` alone accounts for
**68 of 744**. If those numbers have moved far, the decision they support is
worth re-opening. That is the only reason to run this.

**What counts as judged** is deliberately narrow: only names declared somewhere
in this repo. SDK and third-party names cannot be resolved from here, so their
absence would mean nothing and they stay unjudged -- the same honesty rule
``check_consumer_claims.py`` applies with its ``Tom``-prefixed restriction.

Scope is approximated by following ``import`` / ``export`` transitively through
in-repo libraries and their ``part`` files, ignoring ``show`` / ``hide`` and
prefixes. That is close enough to answer "is this population large?", and not
close enough to gate on -- one more reason this file does not.
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
INLINE_CODE = re.compile(r"`[^`]*`")
REFERENCE = re.compile(r"\[([^\[\]]+)\](?![\(\[])")
PART_OF = re.compile(r"""^\s*part\s+of\s+['"]([^'"]+)['"]\s*;""", re.M)
PART = re.compile(r"""^\s*part\s+['"]([^'"]+)['"]\s*;""", re.M)
IMPORT = re.compile(r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""", re.M)
EXPORT = re.compile(r"""^\s*export\s+['"]([^'"]+)['"]""", re.M)
TYPE_DECLARATION = re.compile(
    r"^\s*(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+)*"
    r"(?:mixin\s+class|class|mixin|enum|extension\s+type|extension|typedef)"
    r"\s+([A-Z]\w+)",
    re.M,
)
# The head of a reference: [Foo.bar] and [Foo] both hang off `Foo`.
HEAD = re.compile(r"^([A-Z]\w+)")


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
    return "\n".join(ln for ln in text.split("\n") if not DOC_LINE.match(ln))


def package_roots() -> dict[str, Path]:
    """`package:<name>/` -> that package's `lib/`, for in-repo packages."""
    roots: dict[str, Path] = {}
    for pubspec in REPO_ROOT.rglob("pubspec.yaml"):
        if SKIP_DIRS & set(pubspec.parts):
            continue
        match = re.search(r"^name:\s*(\S+)", pubspec.read_text(encoding="utf-8"), re.M)
        if match and (pubspec.parent / "lib").is_dir():
            roots[match.group(1)] = pubspec.parent / "lib"
    return roots


def main(argv: list[str]) -> int:
    subtree = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not subtree.exists():
        print(f"no such path: {subtree}", file=sys.stderr)
        return 2
    packages = package_roots()
    text_of: dict[Path, str] = {}
    for path in source_files(REPO_ROOT):
        try:
            text_of[path] = path.read_text(encoding="utf-8")
        except OSError:
            continue

    # A report whose only failure mode is printing zeros is worse than no
    # report: this file was briefly misrooted and said "0 of 0" rather than
    # anything. An empty index means the root is wrong, not that the tree is
    # clean, and that distinction has to be audible.
    if not text_of:
        print(f"indexed no Dart files under {REPO_ROOT} -- wrong root?",
              file=sys.stderr)
        return 2

    declared: dict[Path, set[str]] = {}
    everywhere: set[str] = set()
    for path, text in text_of.items():
        names = set(TYPE_DECLARATION.findall(code_of(text)))
        declared[path] = names
        everywhere |= names

    def resolve(base: Path, uri: str) -> Path | None:
        if uri.startswith("package:"):
            rest = uri[len("package:"):]
            name, _, tail = rest.partition("/")
            root = packages.get(name)
            return (root / tail) if root else None
        if uri.startswith("dart:"):
            return None
        return (base.parent / uri).resolve()

    def owning_library(path: Path) -> Path:
        match = PART_OF.search(text_of.get(path, ""))
        if match and match.group(1).endswith(".dart"):
            resolved = (path.parent / match.group(1)).resolve()
            if resolved in text_of:
                return resolved
        return path

    # Names a library offers to importers: its own + its parts' + re-exports.
    offer_cache: dict[Path, set[str]] = {}

    def offered(path: Path, seen: frozenset[Path] = frozenset()) -> set[str]:
        if path in offer_cache:
            return offer_cache[path]
        if path in seen or path not in text_of:
            return set()
        seen = seen | {path}
        text = text_of[path]
        names = set(declared.get(path, set()))
        for part in PART.findall(text):
            target = resolve(path, part)
            if target and target in text_of:
                names |= declared.get(target, set())
        for uri in EXPORT.findall(text):
            target = resolve(path, uri)
            if target and target in text_of:
                names |= offered(target, seen)
        if not seen - {path}:
            offer_cache[path] = names
        return names

    def in_scope(path: Path) -> set[str]:
        library = owning_library(path)
        text = text_of[library]
        names = set(offered(library))
        for uri in IMPORT.findall(text):
            target = resolve(library, uri)
            if target and target in text_of:
                names |= offered(target)
        return names

    total = 0
    dangling: list[tuple[Path, int, str]] = []
    files = 0
    for path in source_files(subtree):
        text = text_of.get(path)
        if text is None:
            continue
        scope = in_scope(path)
        hits = 0
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
            for ref in REFERENCE.findall(body):
                head = HEAD.match(ref.strip())
                if not head:
                    continue
                name = head.group(1)
                if name not in everywhere:
                    continue  # SDK or absent: unjudged
                total += 1
                hits += 1
                if name not in scope:
                    dangling.append((path, number, name))
        if hits:
            files += 1

    for path, number, name in dangling:
        print(f"{path.relative_to(REPO_ROOT)}:{number}: [{name}] not in scope")
    print()
    print(f"files with a judged reference : {files}")
    print(f"repo-declared refs checked    : {total}")
    print(f"not resolvable from library   : {len(dangling)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
