"""Find doc-comment links that `dart doc` sent into a package nobody chose.

Imported by ``check_dartdoc_build.py`` and run by
``tom_core_samples/tool/check_advanced_dartdoc.sh`` over the HTML each of them
generates; it has no entry point of its own beyond ``--self-test``.

**The fault.** `dart doc` resolves a bracketed reference by walking outward
until *something* answers, and a reference that answers is not a warning. In
``advanced_auth_server`` a typedef's doc comment wrote ``[hash]`` meaning the
record's own field. Record fields are not addressable, so dartdoc kept walking
and bound the name to `vector_math`'s deprecated `hash` library -- a transitive
dependency the package never mentions -- and rendered a live link to it. The
build reported zero warnings, the ``comment_references`` lint would have been
silent too (the name does resolve), and the defect was found by reading the
generated page.

**What is read.** Only the prose dartdoc renders from doc comments: the
description section of each page (``<section class="desc markdown">``) and the
one-line summaries in member listings (``<dd>``). Signatures are left alone: a
parameter typed ``SecureRandom`` links into `pointycastle` because the package
really does expose that type through a dependency, and that link is the code's
claim, not the author's.

**What is allowed.** A link may go to the writing package, to the Dart and
Flutter SDKs, and to a package the writing package *depends on* -- a direct
dependency, or a package a direct dependency re-exports, transitively, because
a reader of the barrel can name those types without importing anything else.
Anything else is a link into a package the author never chose, and that is the
fault.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

#: A link into a hosted package's API pages.
PACKAGE_LINK = re.compile(
    r'<a\b[^>]*href="https://pub\.dev/documentation/([A-Za-z0-9_]+)/[^"]*"[^>]*>'
    r"(.*?)</a>", re.S)

#: The two places dartdoc renders doc-comment prose.
PROSE_BLOCK = re.compile(
    r'<section class="desc markdown">(.*?)</section>|<dd\b[^>]*>(.*?)</dd>',
    re.S)

#: `export 'package:<name>/...'` in a library, the re-export a dependency
#: makes on its consumers' behalf.
EXPORT = re.compile(r"""^\s*export\s+['"]package:([A-Za-z0-9_]+)/""", re.M)

TAG = re.compile(r"<[^>]+>")


def _package_roots(package: Path) -> dict[str, Path]:
    """Each resolved package's root, from the package's own config."""
    config = package / ".dart_tool" / "package_config.json"
    data = json.loads(config.read_text(encoding="utf-8"))
    roots: dict[str, Path] = {}
    for entry in data["packages"]:
        uri = entry["rootUri"]
        if uri.startswith("file://"):
            root = Path(uri[len("file://"):])
        else:
            root = (config.parent / uri).resolve()
        roots[entry["name"]] = root
    return roots


def _direct_dependencies(package: Path) -> set[str]:
    """The names under `dependencies:` in the package's pubspec."""
    names: set[str] = set()
    inside = False
    for line in (package / "pubspec.yaml").read_text(encoding="utf-8").split("\n"):
        if re.match(r"^dependencies:\s*$", line):
            inside = True
            continue
        if inside and re.match(r"^\S", line):
            break
        match = re.match(r"^  ([A-Za-z0-9_]+):", line) if inside else None
        if match:
            names.add(match.group(1))
    return names


def allowed_packages(package: Path) -> set[str]:
    """The packages a doc comment of `package` may link into.

    The package itself, its direct dependencies, and -- transitively -- every
    package one of those re-exports from its `lib/`.
    """
    roots = _package_roots(package)
    allowed = {package.name}
    pending = sorted(_direct_dependencies(package))
    while pending:
        name = pending.pop()
        if name in allowed:
            continue
        allowed.add(name)
        lib = roots.get(name, Path("/nonexistent")) / "lib"
        if not lib.is_dir():
            continue
        for source in lib.rglob("*.dart"):
            try:
                text = source.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            pending.extend(n for n in EXPORT.findall(text) if n not in allowed)
    return allowed


def stray_links(output: Path, allowed: set[str]) -> list[str]:
    """`"<page>: [text] -> <package>"` for each doc-prose link outside `allowed`.

    Reported once per (page, text, package): dartdoc repeats a summary on
    every page that lists the member, and one wrong reference is one fault.
    """
    return scan(output, allowed)[0]


def scan(output: Path, allowed: set[str]) -> tuple[list[str], int, int]:
    """`(stray links, prose blocks read, package links read)` over `output`.

    The two counts exist so a caller can refuse a vacuous pass: if dartdoc ever
    renders doc prose under a different class, the blocks would stop matching
    and every package would read clean.
    """
    blocks = links = 0
    found: set[str] = set()
    for page in sorted(output.rglob("*.html")):
        html = page.read_text(encoding="utf-8", errors="ignore")
        for block in PROSE_BLOCK.finditer(html):
            blocks += 1
            prose = block.group(1) or block.group(2) or ""
            for link in PACKAGE_LINK.finditer(prose):
                links += 1
                target = link.group(1)
                if target in allowed:
                    continue
                text = TAG.sub("", link.group(2)).strip()
                where = page.relative_to(output)
                found.add(f"{where}: [{text}] -> {target}")
    return sorted(found), blocks, links


def self_test() -> int:
    """The `[hash]` page, as dartdoc rendered it, must be reported; its
    signature link into an allowed package and a prose link into one must not."""
    import tempfile
    with tempfile.TemporaryDirectory() as scratch:
        root = Path(scratch)
        (root / "x").mkdir()
        (root / "x" / "PasswordHash.html").write_text(
            '<section class="multi-line-signature"><a href="https://pub.dev/'
            'documentation/pointycastle/3.9.1/api/SecureRandom-class.html">'
            'SecureRandom</a></section>'
            '<section class="desc markdown"><p>The <a class="deprecated" '
            'href="https://pub.dev/documentation/vector_math/2.4.1/hash/">hash'
            '</a> and the <a href="https://pub.dev/documentation/tom_basics/'
            '3.1.1/tom_basics/TomRuntime-class.html">TomRuntime</a>.</p>'
            '</section>', encoding="utf-8")
        got = stray_links(root, {"tom_basics", "advanced_auth_server"})
    expected = ["x/PasswordHash.html: [hash] -> vector_math"]
    if got != expected:
        print(f"self-test: expected {expected}, got {got}", file=sys.stderr)
        return 1
    print("self-test: the prose mis-link is reported, the signature and the "
          "allowed link are not")
    return 0


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        sys.exit(self_test())
    print(__doc__)
    sys.exit(2)
