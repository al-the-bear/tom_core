#!/usr/bin/env python3
"""Run every ```dart block in a package's documents through the Dart analyzer.

Run from anywhere::

    python3 tool/check_doc_dart_blocks.py                  # the gated packages
    python3 tool/check_doc_dart_blocks.py tom_core_server  # one package, ad hoc

Exits non-zero when a block fails, so it can gate a build.

**The defect this exists for is invisible to review.** Four non-compiling
samples were found in one document, `beanlocator.md`. Two were spotted by
reading -- a method that does not exist, a constructor that does not exist. The
other two were not: an elided `[...]` in argument position, and a class
declared twice in the same block. A careful read had already passed over both.
That is the shape of the whole class: a sample that reads correctly and does
not compile, in a document whose entire value is that a reader can trust it.
Nothing but a compiler finds those, and nothing but a gate keeps finding them.

**Two rules, and the reason it is not simply "make it compile".**

*Rule A -- it must parse.* A block has to be syntactically valid Dart in one of
the contexts a documentation sample can occupy: at top level, inside an async
function, as class members, as a single expression, or -- the shape a sample
most often takes -- a declaration followed by statements using it. Every
context is tried and one success is enough. Classifying the block first is the
harder problem, and a wrong classification reports a fault that is really a
mis-wrap.

*Rule B -- every framework name it uses must resolve.* A sample is free to
invent `Person`, `OrderService`, `settings`. That is its own illustrative
fiction, and resolving it would mean writing the fiction out as stubs -- which
is both a great deal of invention and *self-fulfilling*, since a stub written
to match a sample can never contradict it. Auto-stubbing is worse still: it
would define away the exact failure this gate exists to find, because a
mistyped `TomBeen` would be stubbed into existence and pass. What is not
fiction is a name beginning `Tom`/`tom`: that prefix belongs to the framework,
so a sample using one is *claiming* the framework has it. Those must resolve.

So the check keeps the whole of what the manual pass demonstrated and gives up
only the part that would need fiction to evaluate.

*Rule C -- a fence that says it is whole must analyze clean.* Rule B's
concession is also its blind spot: a snippet that used an undeclared
``preference`` and read back a ``stored`` it never named passed, because
neither name begins ``Tom`` and the fiction is what B allows. That is a real
defect and it is the one kind a compiler catches outright, so a fence can opt
in by naming itself in its own info string::

    ```dart complete

and is then judged by *every* diagnostic. Opt-in rather than opt-out because
most fences here are deliberately fragments -- a bare statement, a class body,
a method signature with no enclosing class -- all the right thing to show and
none of them programs. Requiring a fragment to declare the context it omits
would either bury the point in scaffolding or park a preamble somewhere the
reader cannot see it; a snippet that wants checking is written whole instead.

The marker is a claim the gate then holds the page to, which is what makes it
worth having rather than decorative. Of 29 fences that carried both an import
and a `main` -- and so looked whole -- 22 were, and 7 were not: three import a
file `build_runner` generates, and four stand in an application they invent
(`UserService`, `DatabaseConnection`). Those stay unmarked, which is the
honest answer for them. One was neither: `logging.md`'s multi-isolate sample
passed `args` to `startIsolatedLogging` from a `main()` that declared none, so
a reader copying it got exactly the error this rule exists to report.

**The documents' elision conventions are honoured, not edited away.** `{ ... }`
for a body and `// ...` for elided statements are how a sample says "the rest
is not the point", and they are legitimate. [desugar] translates them. Three
positions have to be told apart, because Dart accepts different things in each:
a *type* body becomes empty, a *collection literal* becomes empty, and a
*function* body cannot be empty -- a non-void function that completes normally
is an error -- so it throws.

**Where it looks.** Three trees, walked rather than listed: `doc/`, the
package `README.md`, and the per-module `readme.md` files under `lib/`. The
last of those is the documentation closest to the code and the one a developer
reads while already in the source; the sweep that first reached it found a
sample subclassing `TomWorkerContext` without forwarding to a constructor that
has no zero-argument form -- eight lines under a paragraph stating that the
constructor argument in question is required.

**What is not covered, and why.** The generated API summaries are excluded --
`doc/api_reference/` in some packages, `doc/api/` in others. Those
fences quote *signatures* -- `factory TomBean.fromName(String name)`,
`const TomComponent(Type type)` -- and a signature is a declaration, not a use.
Making them parse would take a mechanical `;` per block and would buy nothing:
a declaration declares, so it never consults the real API, and Rule B could
never fire. A green light there would be coverage in appearance only. Checking
a quoted signature against the framework's own is a genuinely different check
-- comparing text to the element model -- and belongs in its own gate.

A block that imports another package is skipped and counted, not failed. The
scheduling document legitimately points at `tom_core_server` for the relational
job store. Adding that dependency here would invert the layering and blind the
gate to a kernel document reaching for a server type by accident, so the block
is left unchecked and the limit is printed.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

from gate_report import report_faults

TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parent
#: Where the generated libraries are written, one subdirectory per package.
#: Per package rather than shared, because the pubspec inside points at exactly
#: one path dependency and the failures left behind are only readable against
#: it -- with several packages gated, a single directory would describe
#: whichever ran last and misreport the rest.
SCRATCH_ROOT = TOOL_DIR / "ztmp" / "doc_dart_blocks"

#: Packages whose documents are gated -- every one that has been triaged to
#: zero. A package with a backlog is not listed: adding one here without
#: repairing it first would pin the backlog in place rather than fix it. Pass a
#: package name on the command line to survey one ad hoc; `tom_core_server`,
#: `tom_flutter_ui` and `tom_flutter_ui_test` still answer with faults, and the
#: last two need a `package:flutter` preamble this checker does not yet write.
#: `tom_core_flutter` needs no preamble -- its documents are about the binding
#: layer, not about widgets -- but gating it does mean the scratch package
#: resolves against the Flutter SDK, so this gate now needs one on PATH.
PACKAGES = [
    "tom_core_kernel",
    "tom_core_agentic",
    "tom_core_codespecs",
    "tom_core_flutter",
]

#: Document subtrees left out, keyed by the reason (see the module docstring).
#: Two names for one thing: the packages disagree on whether the generated API
#: summaries live under `doc/api_reference/` or `doc/api/`, and the content is
#: the same quoted signatures either way.
EXCLUDED_DIRS = {"api_reference", "api"}

PUBSPEC = """name: doc_dart_blocks
publish_to: none
environment:
  sdk: ^3.10.0
dependencies:
  {package}:
    path: {path}
"""

#: A sample is an excerpt, so it drops things a program would use. None of that
#: is a documentation fault, and leaving it on would bury the faults that are.
ANALYSIS_OPTIONS = """analyzer:
  errors:
    unused_import: ignore
    unused_local_variable: ignore
    unused_element: ignore
    unused_field: ignore
    dead_code: ignore
"""

#: What a sample may reach for without saying so. A document does not repeat
#: `import 'dart:convert';` above every block that mentions `utf8`.
PREAMBLE = "\n".join([
    "import 'dart:async';",
    "import 'dart:convert';",
    "import 'dart:io';",
    "import 'dart:math';",
    "import 'dart:typed_data';",
]) + "\n"

#: Tried in order; the first that parses is the one the block is judged in.
#: `mixed` comes first because it is the shape most samples have, so most
#: blocks are settled by the first pass and the rest cost only their own size.
WRAPPERS = ["mixed", "top", "fn", "member", "expr"]

#: A ```dart fence, with whatever else its info string carries. The word
#: `complete` there is the opt-in marker -- see [COMPLETE] and the module
#: docstring.
FENCE_OPEN = re.compile(r"^\s*```dart(?P<info>[^\n]*)$")

#: The marker that says "this fence is a whole program, judge it as one".
COMPLETE = "complete"
FENCE_CLOSE = re.compile(r"^\s*```\s*$")

BRACE_ELLIPSIS = re.compile(r"\{\s*\.\.\.\s*\}")
CLASSISH = re.compile(r"\b(?:class|enum|mixin|extension)\b[^;{}]*$")
#: `{...}` is a *body* only where a body can stand: after a parameter list, or
#: after `else`, `try`, `do`, or a previous statement. Anywhere else -- after
#: `:`, `=`, `(`, `,` -- it is a map or set literal in expression position.
BODY_POSITION = re.compile(r"(?:\)|\b(?:else|try|do)|\{|\}|;)\s*$")
IMPORT_LINE = re.compile(r"^\s*(?:import|export|part)\s+[^\n]*$", re.M)
#: A framework name as the analyzer quotes it in a message.
TOM_NAME = re.compile(r"'(?:[\w.<>]*\b)?([Tt]om[A-Z]\w*)")


# =============================================================================
# EXTRACTION
# =============================================================================


def fenced_dart(text: str):
    """Every ```dart block, as `(first content line, body, is complete)`.

    `is complete` is the opt-in of the module docstring: the fence said so in
    its own info string, so this one is judged by every diagnostic rather than
    by the two rules a fragment is held to.
    """
    lines = text.split("\n")
    index = 0
    while index < len(lines):
        opened = FENCE_OPEN.match(lines[index])
        if opened:
            start = index + 1
            end = start
            while end < len(lines) and not FENCE_CLOSE.match(lines[end]):
                end += 1
            complete = COMPLETE in opened.group("info").split()
            yield start + 1, "\n".join(lines[start:end]), complete
            index = end
        index += 1


def documents(package: Path):
    """The markdown of `package` that this gate reads, in a stable order.

    Three trees, because a reader trusts a fenced sample wherever it is printed
    and does not know or care which tree it came from. `doc/` is the manual,
    `README.md` is the first page anyone opens, and the per-module `readme.md`
    files under `lib/` are the ones a developer reads while already in the
    source -- the closest documentation to the code, and the only kind that was
    never checked.

    Derived by walking each tree rather than from a list of files, so a
    document that appears somewhere new is covered the day it appears. Only
    `EXCLUDED_DIRS` is left out, for the reason in the module docstring.
    """
    doc_root = package / "doc"
    found: list[Path] = []
    if doc_root.is_dir():
        found += [
            path for path in doc_root.rglob("*.md")
            if not EXCLUDED_DIRS & set(path.relative_to(doc_root).parts)
        ]
    found += package.glob("*.md")
    found += (package / "lib").rglob("*.md")
    return sorted(found)


# =============================================================================
# TRANSLATION
# =============================================================================


def desugar(block: str) -> str:
    """Turn the documents' elision conventions into legal Dart.

    `// ...` is already a comment and already legal. `{ ... }` is not, and what
    it must become depends on where it stands -- see the module docstring.
    """
    out: list[str] = []
    last = 0
    for match in BRACE_ELLIPSIS.finditer(block):
        head = block[:match.start()]
        line = head[head.rfind("\n") + 1:]
        is_function_body = (not CLASSISH.search(line)
                            and BODY_POSITION.search(head.rstrip()))
        out.append(block[last:match.start()])
        out.append("{ throw UnimplementedError(); }" if is_function_body
                   else "{}")
        last = match.end()
    out.append(block[last:])
    return "".join(out)


def hoist_imports(body: str) -> tuple[str, str]:
    """Split a block's own directives out of its body.

    A block that opens with imports cannot be wrapped in a function with them
    still inside it. Pulling them to the header keeps the block's stated
    dependencies while letting it be tried in every context.
    """
    return "\n".join(IMPORT_LINE.findall(body)), IMPORT_LINE.sub("", body)


#: Keywords that continue a construct across a closing brace. `try {} catch {}`
#: and `if {} else {}` are each *one* chunk; splitting at the first `}` would
#: strand the tail as a chunk of its own that parses nowhere.
CONTINUATION = re.compile(r"\s*(?://[^\n]*\n|/\*[\s\S]*?\*/|\s)*"
                          r"\b(?:on|catch|finally|else|while)\b")


def chunks(source: str):
    """Split `source` into its top-level chunks.

    A chunk ends at a `;` outside any bracket, or at the `}` that closes a
    top-level construct -- unless a continuation keyword follows, in which case
    the construct is not over. Strings and comments are skipped so a brace
    inside either does not move the depth.
    """
    depth = 0
    start = 0
    index = 0
    size = len(source)
    while index < size:
        char = source[index]
        pair = source[index:index + 2]
        if pair == "//":
            index = source.find("\n", index)
            if index < 0:
                break
            continue
        if pair == "/*":
            end = source.find("*/", index + 2)
            index = size if end < 0 else end + 2
            continue
        if char in "'\"":
            triple = source[index:index + 3]
            if triple in ("'''", '"""'):
                end = source.find(triple, index + 3)
                index = size if end < 0 else end + 3
                continue
            index += 1
            while index < size and source[index] != char:
                index += 2 if source[index] == "\\" else 1
            index += 1
            continue
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
            if (depth == 0 and char == "}"
                    and not CONTINUATION.match(source, index + 1)):
                yield source[start:index + 1]
                start = index + 1
        elif char == ";" and depth == 0:
            yield source[start:index + 1]
            start = index + 1
        index += 1
    tail = source[start:]
    if tail.strip():
        yield tail


DECLARATION = re.compile(
    r"^\s*(?:@\w[\s\S]*?)?\s*(?:"
    r"(?:abstract|base|final|interface|sealed|mixin)\s+)*"
    r"(?:class|enum|mixin|extension|typedef)\b"
)
TOP_VARIABLE = re.compile(r"^\s*(?:@\w[\s\S]*?\s+)?(?:final|const)\s+[^=;]*=")
#: `if (x) { … }` has the shape of a function declaration -- a word, a
#: parenthesised list, a brace -- so the keywords are excluded by name.
STATEMENT_KEYWORD = re.compile(
    r"^\s*(?:if|for|while|switch|try|do|return|assert|catch|throw|await)\b")
#: What may precede a function's parameter list: an optional return type, then
#: the name. `print` qualifies on its own, which is why the tail matters too.
FUNCTION_HEAD = re.compile(r"(?:[\w<>,\s?\[\]]+\s+)?\w+\s*(?:<[^>]*>)?\s*$")
FUNCTION_TAIL = re.compile(r"^\s*(?:async\s*\*?|sync\s*\*)?\s*(?:\{|=>)")
LEADING_COMMENT = re.compile(r"^\s*(?://[^\n]*\n|/\*[\s\S]*?\*/\s*)+")
AWAIT = re.compile(r"\bawait\b")


def is_top_function(chunk: str) -> bool:
    """Does `chunk` declare a top-level function?

    The parameter list has to be found by *scanning*, not by a regex: a greedy
    ``\\(.*\\)`` reads ``print(xs.map((e) => e))`` as a declaration named
    ``print`` whose body is ``=> e))``. Finding the paren that actually closes
    the first one, and insisting a body follows it, tells the two apart.
    """
    opened = chunk.find("(")
    if opened < 0 or not FUNCTION_HEAD.match(chunk[:opened]):
        return False
    depth = 0
    for index in range(opened, len(chunk)):
        if chunk[index] in "([{":
            depth += 1
        elif chunk[index] in ")]}":
            depth -= 1
            if depth == 0:
                return FUNCTION_TAIL.match(chunk[index + 1:]) is not None
    return False


def is_declaration(chunk: str) -> bool:
    """May `chunk` stand at the top level of a library?"""
    # A chunk carries the comments written above it. They say nothing about
    # where it may stand, so classification starts after them.
    stripped = LEADING_COMMENT.sub("", chunk).strip()
    if not stripped:
        return True
    if DECLARATION.match(stripped):
        return True
    if STATEMENT_KEYWORD.match(stripped):
        return False
    if AWAIT.search(stripped):
        return False  # a top-level initialiser cannot await
    if TOP_VARIABLE.match(stripped):
        return True
    return is_top_function(stripped)


def build(body: str, wrapper: str, package: str) -> str:
    """Render one block as a library, in the named context."""
    header, rest = hoist_imports(body)
    if wrapper == "top":
        core = rest
    elif wrapper == "fn":
        core = f"Future<void> _sample() async {{\n{rest}\n}}"
    elif wrapper == "member":
        core = f"abstract class _Sample {{\n{rest}\n}}"
    elif wrapper == "expr":
        # A block that is one expression -- a constructor call shown with its
        # arguments and no statement around it -- is a legitimate
        # documentation form; it needs somewhere to be a value.
        core = f"Future<void> _sample() async {{\n  final _value = {rest};\n}}"
    else:
        # Declare a type, then show it in use. Neither half is legal where the
        # other is -- a statement cannot sit at top level, a class cannot sit
        # in a function body -- so each is put where Dart accepts it. Order
        # within each half is preserved; order *between* them does not matter,
        # since top-level declarations are visible to the whole library.
        declarations, statements = [], []
        for chunk in chunks(rest):
            (declarations if is_declaration(chunk) else statements).append(chunk)
        core = ("".join(declarations) + "\nFuture<void> _sample() async {"
                + "".join(statements) + "\n}")
    import_package = f"import 'package:{package}/{package}.dart';\n"
    return PREAMBLE + import_package + header + "\n" + core + "\n"


# =============================================================================
# ANALYSIS
# =============================================================================


def slug(path: Path, root: Path, line: int) -> str:
    relative = path.relative_to(root).with_suffix("")
    return re.sub(r"\W+", "_", f"{relative}_{line}").strip("_").lower()


def scratch_for(package: Path) -> Path:
    """The generated-library directory for `package`."""
    return SCRATCH_ROOT / package.name


def write_scratch(package: Path, cases: list[tuple[str, str]]) -> None:
    scratch = scratch_for(package)
    samples = scratch / "lib" / "samples"
    samples.mkdir(parents=True, exist_ok=True)
    for stale in samples.glob("*.dart"):
        stale.unlink()
    (scratch / "pubspec.yaml").write_text(
        PUBSPEC.format(package=package.name, path=package.resolve()),
        encoding="utf-8")
    (scratch / "analysis_options.yaml").write_text(
        ANALYSIS_OPTIONS, encoding="utf-8")
    for name, source in cases:
        (samples / f"{name}.dart").write_text(source, encoding="utf-8")


def run_dart(scratch: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["dart", *args], capture_output=True, text=True,
                          cwd=scratch)


def analyze(scratch: Path) -> dict[str, list[dict]]:
    """Every ERROR the analyzer reports, grouped by the sample it came from."""
    done = run_dart(scratch, "analyze", "--format=json", str(scratch))
    try:
        payload = json.loads(done.stdout)
    except json.JSONDecodeError:
        raise SystemExit(
            "dart analyze produced no JSON:\n" + done.stdout + done.stderr)
    found: dict[str, list[dict]] = {}
    for diagnostic in payload.get("diagnostics", []):
        if diagnostic.get("severity") != "ERROR":
            continue
        stem = Path(diagnostic["location"]["file"]).stem
        found.setdefault(stem, []).append(diagnostic)
    return found


def partition(
    diagnostics: list[dict], complete: bool = False
) -> tuple[list[dict], list[dict]]:
    """`(Rule A failures, Rule B/C failures)`.

    The analyzer's own `type` field makes the split exact: a `SYNTACTIC_ERROR`
    is the parser's, everything else is resolution's. Of the latter only those
    naming a framework identifier count -- the rest are the document's fiction.

    Unless the fence declared itself `complete`, in which case there is no
    fiction to allow and every resolution error counts. That is Rule C, and it
    is the only rule that catches an undeclared plain name: the snippet this
    gate's opt-in was built for used a `preference` it never declared and read
    back a `stored` it never named, neither of which begins `Tom`.
    """
    syntax = [d for d in diagnostics if d.get("type") == "SYNTACTIC_ERROR"]
    resolution = [d for d in diagnostics if d.get("type") != "SYNTACTIC_ERROR"]
    if complete:
        return syntax, resolution
    return syntax, [
        d for d in resolution
        if TOM_NAME.search(d.get("problemMessage", ""))
    ]


# =============================================================================
# REPORTING
# =============================================================================


class Fault:
    """One block that failed, and the diagnostics that condemned it."""

    def __init__(self, name: str, where: str, rule: str, wrapper: str | None,
                 diagnostics: list[dict], scratch: Path) -> None:
        self.name = name
        self.where = where
        self.rule = rule
        self.wrapper = wrapper
        self.diagnostics = diagnostics
        self.scratch = scratch

    @property
    def weight(self) -> int:
        """How many repairs this fault represents.

        A block that does not parse is one repair however many diagnostics
        cascade from the missing token. A block that names framework symbols
        that do not exist is one repair *per symbol*.
        """
        return 1 if self.rule == "parse" else len(self.diagnostics)

    def render(self) -> str:
        head = (f"{self.where}"
                + (f" [{self.wrapper}]" if self.wrapper else "")
                + f"  -> {self.scratch.relative_to(REPO_ROOT)}"
                  f"/lib/samples/{self.name}.dart")
        lines = [head]
        for diagnostic in self.diagnostics[:4]:
            lines.append(f"      {diagnostic['code']}: "
                         f"{diagnostic['problemMessage']}")
        return "\n".join(lines)


def check(package: Path) -> tuple[list[Fault], int, int]:
    """`(faults, blocks checked, blocks skipped, blocks marked complete)`."""
    foreign_import = re.compile(
        rf"^\s*import\s+'package:(?!{re.escape(package.name)}/)", re.M)

    origin: dict[str, tuple[str, str]] = {}
    complete: set[str] = set()
    skipped = 0
    for path in documents(package):
        for line, block, is_complete in fenced_dart(
            path.read_text(encoding="utf-8")
        ):
            if foreign_import.search(block):
                skipped += 1
                continue
            where = f"{path.relative_to(package)}:{line}"
            name = slug(path, package, line)
            origin[name] = (where, desugar(block))
            if is_complete:
                complete.add(name)

    scratch = scratch_for(package)
    write_scratch(package, [])
    got = run_dart(scratch, "pub", "get")
    if got.returncode != 0:
        # Named, because the likeliest cause is environmental rather than a
        # document fault: a package that depends on the Flutter SDK cannot be
        # resolved by a Dart-only toolchain, and a bare pub log does not say
        # which of the gated packages asked for it.
        raise SystemExit(
            f"could not resolve the scratch package for {package.name}:\n"
            + got.stdout + got.stderr)

    # Blocks settle in the first context that parses, so each pass carries only
    # what the previous ones could not place.
    pending = dict(origin)
    faults: list[Fault] = []
    best_syntax: dict[str, list[dict]] = {}
    for wrapper in WRAPPERS:
        if not pending:
            break
        write_scratch(package, [
            (name, build(body, wrapper, package.name))
            for name, (_, body) in pending.items()
        ])
        found = analyze(scratch)
        still: dict[str, tuple[str, str]] = {}
        for name, (where, body) in pending.items():
            syntax, framework = partition(
                found.get(name, []), name in complete
            )
            if syntax:
                previous = best_syntax.get(name)
                if previous is None or len(syntax) < len(previous):
                    best_syntax[name] = syntax
                still[name] = (where, body)
                continue
            if framework:
                faults.append(Fault(
                    name,
                    where,
                    "complete" if name in complete else "framework",
                    wrapper,
                    framework,
                    scratch,
                ))
        pending = still

    for name, (where, _) in pending.items():
        faults.append(
            Fault(name, where, "parse", None, best_syntax[name], scratch))

    # Leave behind exactly the libraries that failed, and nothing else. They
    # are the evidence -- a fault reads far more easily as the source the
    # analyzer saw than as a line number in a document -- while the 400-odd
    # that passed would only be Dart files lying around a scratch directory
    # for the next tree-walking gate to find.
    write_scratch(package, [
        (fault.name, build(origin[fault.name][1],
                           fault.wrapper or WRAPPERS[0], package.name))
        for fault in faults
    ])
    return faults, len(origin), skipped, len(complete)


def main(argv: list[str]) -> int:
    wanted = argv[1:] or PACKAGES
    if subprocess.run(["which", "dart"], capture_output=True).returncode != 0:
        print("dart is not on PATH, so no block can be analyzed",
              file=sys.stderr)
        return 2

    total_faults: list[Fault] = []
    checked = skipped = opted_in = 0
    for name in wanted:
        package = REPO_ROOT / name
        if not (package / "pubspec.yaml").is_file():
            print(f"{name} is not a package under {REPO_ROOT}",
                  file=sys.stderr)
            return 2
        faults, blocks, left_out, marked = check(package)
        if blocks == 0:
            print(f"no ```dart blocks found under {name}", file=sys.stderr)
            return 2
        total_faults.extend(faults)
        checked += blocks
        skipped += left_out
        opted_in += marked

    parse = [f for f in total_faults if f.rule == "parse"]
    framework = [f for f in total_faults if f.rule == "framework"]
    incomplete = [f for f in total_faults if f.rule == "complete"]

    if parse:
        print("=== blocks that do not parse in any context ===")
        for fault in sorted(parse, key=lambda f: f.where):
            print(fault.render())
    if incomplete:
        print("\n=== blocks marked `complete` that do not analyze clean ===")
        for fault in sorted(incomplete, key=lambda f: f.where):
            print(fault.render())
    if framework:
        print("\n=== blocks naming something the framework does not have ===")
        for fault in sorted(framework, key=lambda f: f.where):
            print(fault.render())
        codes = Counter(
            d["code"] for f in framework + incomplete for d in f.diagnostics
        )
        print("\n-- most common --")
        for code, count in codes.most_common(10):
            print(f"  {count:3d}  {code}")

    faults = sum(fault.weight for fault in total_faults)
    print(
        f"\npackages checked        : {', '.join(wanted)}\n"
        f"dart blocks analyzed    : {checked}\n"
        f"blocks skipped (foreign): {skipped}\n"
        f"blocks marked `complete`: {opted_in}\n"
        f"blocks that do not parse: {len(parse)}\n"
        f"framework names missing : {sum(f.weight for f in framework)}\n"
        f"complete blocks unclean : {sum(f.weight for f in incomplete)}"
    )
    return report_faults(faults)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
