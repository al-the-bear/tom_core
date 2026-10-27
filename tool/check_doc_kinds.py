#!/usr/bin/env python3
"""Find `Kind` columns that name something Dart does not declare.

Run from anywhere::

    python3 tool/check_doc_kinds.py                  # every document root
    python3 tool/check_doc_kinds.py tom_core_agentic # one package subtree
    python3 tool/check_doc_kinds.py _ai              # the completion set
    python3 tool/check_doc_kinds.py --self-test      # check the checker

Exits non-zero when a claim disagrees with the source, so it can gate a build.

The argument is a prefix filter on the path each document is *reported* under,
not a root -- it narrows the default set, it cannot widen it. The roots
themselves are ``DOCUMENT_ROOTS``.

Most module documents open with an Overview table whose second column is
``Kind``, and a reader uses that column to decide what they are allowed to do
with the symbol before reading another line. "abstract interface class" means
*implement me, do not extend me*; "final class" means *you may not subclass this
at all*; "class" means both are open. Those are not synonyms, and the difference
is the entire reason the column exists -- a `Purpose` cell already says what the
thing is *for*.

The column decays in a specific direction. Nobody writes ``exception``,
``widget``, ``entity``, ``singleton`` or ``annotation`` because they misread the
source; they write it because it is the more *informative* word, and Dart has no
keyword for it. So the cell reads fluently, describes the symbol's role
correctly, and answers the question the column is actually asked -- may I
subclass this? -- with a word that cannot answer it. ``BearerAuthFailure`` was
listed as ``exception``: true as a description, and silent on the one thing its
declaration decides, whether a reader may extend it. Its neighbour
``BearerTokenAuthenticator`` was listed as ``interface`` while being an
``abstract interface class`` -- the one kind whose whole point is a restriction
the word "interface" does not convey.

**Why a checker rather than a careful read.** This was found three times by
hand, one document at a time -- ``isolate_streaming``, then ``mcp_auth``, then
``placeholders`` -- each time as an isolated finding, and each time the fix was
a two-minute edit. Three identical findings in three consecutive scans is not a
run of bad luck; the documents were written by the same pass, and a pass writes
its habits into everything it touches. Checking the remaining documents the same
way, one scan at a time, would have taken as many rounds as there are documents.

**Why the drift is invisible to the neighbouring gates.**
``check_doc_inventories`` audits *measurements* -- file counts, line counts --
and a kind is not a measurement. ``check_dartdoc_refs`` and
``check_consumer_claims`` both ask whether a name resolves; every symbol in
these tables resolves perfectly, and the sentence about it is still wrong.
Resolution and description are different questions.

**What is checked.** Only tables whose header row has ``Kind`` as its second
column and a declaration -- ``Type``, ``Symbol``, ``Member``, ``Widget``,
``Declaration`` -- as its first. That restriction is what keeps this honest.
Module documents carry other two-column tables of the same shape (a symbol
beside its wire code, a placeholder form beside its meaning), and reading those
as kind claims produced four false positives per real one when this was first
measured; the module guides' ``Dependency | Kind`` tables tabulate imports, not
declarations. A symbol the repo does not declare is skipped rather than
reported: these documents name Flutter and Dart core types freely, and this
checker has no index for them. A code span naming a member (``Type.member``)
is skipped for the same reason.

**A row may name several symbols** -- ``| `A` / `B` / `C` | ... |`` -- and those
rows are where the defect had moved: when the row pattern could only read one
backticked symbol, six of the seven multi-symbol rows found by hand carried a
role word. Such a row makes either one claim every named symbol shares,
singular or plural (``class`` or ``classes``), or its claims in the same order
separated by `` / ``, where a plural claim covers a run of symbols of that kind:
``abstract class / classes`` describes one abstract class and two plain ones.

**A row that names nothing is reported, not skipped.** A first cell with no code
span and no bare identifier -- prose such as ``20 family branch bases`` --
holds a kind claim this checker cannot test, and skipping it would read as a
pass. Name the symbols, or move the prose out of the table.

**Which documents, and why two roots.** The package documents under
``<package>/doc/`` are one set; the completion write-ups in
``_ai/quests/tom_core/completion/`` are the other. They carry the same tables,
written in the same pass, and for a long time only the first set was reachable
-- not unconfigured but *unreachable*, because the single root was this repo and
the CLI argument filters that root rather than replacing it. The completion set
was measured the moment it was reached: 111 role-words across 19 documents,
against a gated set that was reporting clean. A gate whose scope stops short of
half its corpus reports the half it can see, and the report reads like the
whole. The quest folder is a separate clone, so a missing root is skipped rather
than fatal -- but every root that *is* present is audited by default, because a
root you have to ask for is a root nobody asks for.

**What counts as correct** is the declaration's modifiers verbatim, in source
order: ``final class``, ``abstract interface class``, ``sealed class``,
``enum``, ``typedef``, ``mixin``, ``extension type``, ``extension``. Bare ``class`` is
correct only for a class with no modifiers. ``function`` and ``getter`` are
accepted for the two top-level forms that have no keyword of their own -- the
completion documents already use both words and each names a real declaration
form. A top-level ``const`` / ``final`` is written the way the documents write
it, as the modifier plus the type: ``const String``, ``const int``.

The vocabulary is closed, and deliberately admits no decoration: not
``top-level getter`` for ``getter``, not ``class (static)`` or ``class ×3`` for
``class``, not the supertype (``StatelessWidget``, ``State``) in place of the
kind. Every one of those was in the corpus, and each is *true* -- which is the
problem, because a cell that is true and unparseable trains the reader to read
the column as prose. Whatever the decoration was carrying (that a class is a
static-only namespace, that it is reflected, that three variant files declare
it, that it extends ``StatelessWidget``) is a fact about the symbol's role, and
the ``Purpose`` cell beside it is where roles are described. Keeping the
vocabulary closed is what lets a disagreement mean something; accepting synonyms
would make the gate agree with the decay it exists to catch.

**Why constants are indexed at all**, given they are two rows in the whole
corpus: they are the two rows of ``mcp_auth.md``, the document that prompted
this checker. Without them that document has no resolvable row, so it is
reported as having no kind table -- and a checker that answers "clean" for its
own motivating example is worse than no checker, because the silence reads as a
pass. The same reasoning added ``extension`` and the top-level getter: each was
a form the index could not see, and an unseeable form is a permanent blind spot
rather than a deferred one. What remains unindexed is a constant whose type
cannot be read off a literal (a ``const`` bound to a constructor call or a
collection); inferring those needs real type resolution, and guessing would
trade silent misses for loud false alarms.
"""

from __future__ import annotations

import re
import sys
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

from gate_report import report_faults
import gate_scope

REPO_ROOT = Path(__file__).resolve().parent.parent
WORKSPACE_ROOT = REPO_ROOT.parent.parent

# Every place a Kind table lives, as (base, glob). The package documents sit
# inside the repo; the completion write-ups sit in the quest folder beside it.
# A base that is not on disk is skipped -- `_ai` is a separate clone and the
# gate has to run without it.
DOCUMENT_ROOTS: tuple[tuple[Path, str], ...] = (
    *((root, "**/doc/*.md") for root in gate_scope.ROOTS),
    (WORKSPACE_ROOT / "_ai" / "quests" / "tom_core" / "completion", "*.md"),
)

# A type declaration and its modifiers. The modifier group is deliberately
# permissive about order -- Dart fixes it, but a checker that assumed the order
# would silently skip anything written the other way, which is the failure mode
# that matters here.
DECLARATION = re.compile(
    r"^(?P<kind>"
    r"(?:abstract\s+)?(?:base\s+|final\s+|sealed\s+|interface\s+)*"
    r"(?:mixin\s+)?class"
    r"|enum|mixin|extension\s+type|extension|typedef"
    r")\s+(?P<name>\w+)"
)

# The leading run of a top-level signature: its return type. The first character
# is matched separately and must be a word character, which is what pins the
# match to column 0 -- the run itself has to admit spaces (`Map<String, int>`),
# and a class that admits spaces also admits *leading* spaces, so folding the
# two into one `[\w<>,\s?\[\]]+` silently matches indented members. That is how
# `throw IsolateCancellationException(token);` came to be indexed as a top-level
# function: the anchor was in the comment, not in the pattern.
RETURN_TYPE = r"[\w<>?\[\]][\w<>,\s?\[\]]*"

# A top-level function: a return type, a name, and an open parameter list. The
# list is deliberately *not* required to close on the same line -- a wrapped
# signature is the normal shape for anything past two parameters, and demanding
# the closing paren skipped every one of them. Being pinned to column 0 is what
# makes the open form safe: Dart has no top-level statements, so a bare `name(`
# there cannot be a call, and a comment or a variable initialiser is excluded by
# `/` and `=` being absent from the return-type class.
FUNCTION = re.compile(rf"^{RETURN_TYPE}\s(?P<name>\w+)\(")

# A top-level getter: `String get tomAppId => ...`.
GETTER = re.compile(rf"^{RETURN_TYPE}\sget\s+(?P<name>\w+)\s*(?:=>|\{{)")

# A top-level `const` / `final`, with the type either written or inferable from
# the literal it is bound to.
CONSTANT = re.compile(
    r"^(?P<modifier>const|final)\s+"
    r"(?:(?P<type>[A-Za-z_]\w*(?:<[^>=]*>)?\??)\s+)?"
    r"(?P<name>\w+)\s*=\s*(?P<value>.+?);\s*$"
)

# Literal forms whose type can be read off the source text alone. Anything not
# matched here leaves the constant unindexed rather than guessed at.
LITERAL_TYPES: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"^r?'''|^r?\"\"\"|^r?'|^r?\""), "String"),
    (re.compile(r"^(?:true|false)$"), "bool"),
    (re.compile(r"^[+-]?\d[\d_]*\.\d|^[+-]?\d[\d_]*e[+-]?\d", re.I), "double"),
    (re.compile(r"^[+-]?(?:0x[0-9a-f_]+|\d[\d_]*)$", re.I), "int"),
]


def constant_kind(match: re.Match[str]) -> str | None:
    """The `const <Type>` / `final <Type>` kind for a top-level binding."""
    declared = match.group("type")
    if declared is not None:
        return f"{match.group('modifier')} {declared}"
    value = match.group("value").strip()
    for pattern, inferred in LITERAL_TYPES:
        if pattern.match(value):
            return f"{match.group('modifier')} {inferred}"
    return None

# A table of declarations: a first column naming what is declared, then Kind.
# The module guides' dependency tables (`Dependency | Kind | Imported by`) have
# the same second column but tabulate imports -- `dart:io`, a sibling module's
# document -- and none of their rows is a claim about a declaration.
KIND_HEADER = re.compile(
    r"^\|\s*(?:Type|Symbol|Member|Widget|Declaration)\s*\|\s*Kind\s*\|"
)
TABLE_RULE = re.compile(r"^\|[\s\-:|]+\|$")
ROW = re.compile(r"^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|")

# The code spans of a row's first cell, and the one shape of span that names a
# top-level declaration: an identifier, optionally with type arguments or a
# parameter list (`Name<T>`, `name(String)`). A dotted span (`Type.member`)
# names a member, which the index does not hold.
CODE_SPAN = re.compile(r"`([^`]+)`")
TOP_LEVEL_NAME = re.compile(r"^([A-Za-z_]\w*)(?:<.*>)?(?:\(.*\))?$")
BARE_SYMBOL = re.compile(r"^([A-Za-z_]\w*)(?:<.*>)?$")

# How a kind claim is split when one row names several symbols.
CLAIM_SEPARATOR = re.compile(r"\s+/\s+")


def plural(kind: str) -> str:
    """The plural a cell writes for several symbols of one kind: `classes`,
    `final classes`, `enums`, `typedefs`, `functions`."""
    return kind + "es" if kind.endswith("class") else kind + "s"


def symbols_of(cell: str) -> list[str | None] | None:
    """The symbols a first cell names, in order, or None for a prose cell.

    A code span that names something the index cannot hold (a member) is kept
    as `None`, so the claims that follow still line up with their symbols.
    """
    spans = CODE_SPAN.findall(cell)
    if spans:
        names = []
        for span in spans:
            match = TOP_LEVEL_NAME.match(span.strip())
            names.append(match.group(1) if match else None)
        return names
    bare = BARE_SYMBOL.match(cell.strip())
    return [bare.group(1)] if bare else None


def all_declarations() -> dict[str, str]:
    """[index_declarations] over every root the gates read (gate_scope)."""
    kinds: dict[str, str] = {}
    for root in reversed(gate_scope.ROOTS):
        kinds.update(index_declarations(root))
    return kinds


def index_declarations(root: Path) -> dict[str, str]:
    """Map every public top-level declaration in the repo to its kind."""
    kinds: dict[str, str] = {}
    for source in root.rglob("lib/**/*.dart"):
        try:
            text = source.read_text()
        except (OSError, UnicodeDecodeError):
            continue
        for line in text.split("\n"):
            # Ordered loosest-last: `DECLARATION` and `CONSTANT` both start with
            # a keyword, `GETTER` is pinned by its `get`, and `FUNCTION` is the
            # open-ended one, so it only ever sees lines the others rejected.
            match = DECLARATION.match(line)
            if match:
                record(kinds, match.group("name"),
                       " ".join(match.group("kind").split()))
                continue
            match = CONSTANT.match(line)
            if match:
                kind = constant_kind(match)
                if kind is not None:
                    record(kinds, match.group("name"), kind)
                continue
            match = GETTER.match(line)
            if match:
                record(kinds, match.group("name"), "getter")
                continue
            match = FUNCTION.match(line)
            if match:
                record(kinds, match.group("name"), "function")
    return kinds


def record(kinds: dict[str, str], name: str, kind: str) -> None:
    """Index a public declaration, keeping the first sighting of a name."""
    if not name.startswith("_"):
        kinds.setdefault(name, kind)


def display_path(document: Path) -> str:
    """How a document is named in reports, and what the prefix filter matches.

    Repo documents stay repo-relative so the filter keeps naming packages
    (`tom_core_agentic`); anything outside is workspace-relative
    (`_ai/quests/...`). Falling back to the absolute path matters more than it
    looks: `relative_to` *raises* for a path under neither root, and rendering a
    report is the moment a checker is least able to afford an exception.
    """
    for base in (*gate_scope.ROOTS, WORKSPACE_ROOT):
        if document.is_relative_to(base):
            return str(document.relative_to(base))
    return str(document)


def collect_documents(prefix: str) -> list[Path]:
    """Every document under every present root whose display path starts with
    `prefix`, deduplicated in case the roots ever overlap."""
    found: dict[str, Path] = {}
    for base, pattern in DOCUMENT_ROOTS:
        if not base.is_dir():
            continue
        for document in base.glob(pattern):
            shown = display_path(document)
            if shown.startswith(prefix):
                found[shown] = document
    return [found[shown] for shown in sorted(found)]


@dataclass
class Report:
    document: Path
    rows: int = 0
    faults: list[tuple[int, str, str, str]] = field(default_factory=list)
    unparsed: list[tuple[int, str]] = field(default_factory=list)

    @property
    def clean(self) -> bool:
        return not self.faults and not self.unparsed

    def render(self) -> str:
        lines = [display_path(self.document)]
        for line_no, symbol, claimed, actual in self.faults:
            lines.append(
                f"  :{line_no:<4} {symbol:<38} says {claimed!r}, is {actual!r}"
            )
        for line_no, cell in self.unparsed:
            lines.append(f"  :{line_no:<4} {cell!r} names no symbol")
        return "\n".join(lines)


def audit(document: Path, kinds: dict[str, str]) -> Report | None:
    try:
        text = document.read_text()
    except (OSError, UnicodeDecodeError):
        return None
    return audit_text(document, text, kinds)


def audit_text(document: Path, text: str, kinds: dict[str, str]) -> Report | None:
    """Audit one document's Kind tables; None when it has none to audit."""
    report = Report(document)
    in_kind_table = False
    for line_no, line in enumerate(text.split("\n"), 1):
        if KIND_HEADER.match(line):
            in_kind_table = True
            continue
        if not in_kind_table:
            continue
        if not line.startswith("|"):
            in_kind_table = False
            continue
        if TABLE_RULE.match(line):
            continue

        match = ROW.match(line)
        if not match:
            continue
        symbols = symbols_of(match.group(1))
        claimed = match.group(2).strip().strip("`")
        if symbols is None:
            # A row the table holds but no symbol names cannot be audited, and
            # a skip would read as a pass: it is reported instead.
            report.unparsed.append((line_no, match.group(1).strip()))
            continue
        check_row(report, line_no, symbols, claimed, kinds)

    return report if report.rows or report.unparsed else None


def check_row(
    report: Report,
    line_no: int,
    symbols: list[str | None],
    claimed: str,
    kinds: dict[str, str],
) -> None:
    """Hold one row's Kind cell to the kinds of the symbols it names.

    A row naming several symbols of one kind may make one claim for all of
    them, singular or plural (`class` or `classes`). Otherwise it writes its
    claims in the same order, separated by ` / `: a singular claim covers one
    symbol, a plural claim
    (`classes`, `final classes`) covers a run of two or more consecutive
    symbols of that kind, so `classes / enum` describes class, class, enum. A
    symbol this repo does not declare -- a Flutter or SDK type, a member --
    is skipped: a row with none the index knows is not audited at all.
    """
    actuals = [kinds.get(s) if s is not None else None for s in symbols]
    if all(a is None for a in actuals):
        return
    report.rows += 1
    shown = " / ".join(s or "?" for s in symbols)
    claims = [c.strip().strip("`") for c in CLAIM_SEPARATOR.split(claimed)]
    if covers(claims, actuals):
        return
    expected = " / ".join(a or "?" for a in actuals)
    report.faults.append(
        (line_no, shown if len(symbols) > 1 else symbols[0] or shown,
         claimed, expected)
    )


def covers(claims: list[str], actuals: list[str | None]) -> bool:
    """Whether `claims`, in order, describe the symbols' `actuals`.

    An unknown symbol (`None`) agrees with whatever claim covers it.
    """
    known = {a for a in actuals if a is not None}
    if len(claims) == 1 and len(known) == 1:
        (kind,) = known
        return claims[0] in (kind, plural(kind))

    def fits(claim: str, run: list[str | None]) -> bool:
        known = {a for a in run if a is not None}
        if len(known) > 1:
            return False
        kind = next(iter(known)) if known else None
        if len(run) == 1:
            return kind is None or claim == kind or claim == plural(kind)
        return kind is None or claim == plural(kind)

    def match(ci: int, ai: int) -> bool:
        if ci == len(claims):
            return ai == len(actuals)
        return any(
            fits(claims[ci], actuals[ai:end]) and match(ci + 1, end)
            for end in range(ai + 1, len(actuals) + 1)
        )

    return match(0, 0)


def self_test(kinds: dict[str, str]) -> int:
    """Run synthetic tables over real symbols and require each verdict."""
    def first(kind: str) -> str:
        return sorted(name for name, k in kinds.items() if k == kind)[0]

    def second(kind: str) -> str:
        return sorted(name for name, k in kinds.items() if k == kind)[1]

    try:
        plain, plain2 = first("class"), second("class")
        enum, abstract = first("enum"), first("abstract class")
    except IndexError:
        print("self-test: the index lacks a class, enum or abstract class",
              file=sys.stderr)
        return 2

    header = "| Type | Kind | Purpose |\n| --- | --- | --- |\n"
    cases = [
        ("single, right", f"| `{plain}` | class | x |", 0),
        ("single, role word", f"| `{plain}` | model | x |", 1),
        ("shared, singular", f"| `{plain}` / `{plain2}` | class | x |", 0),
        ("shared, plural", f"| `{plain}` / `{plain2}` | classes | x |", 0),
        ("one per symbol", f"| `{abstract}` / `{plain}` | abstract class / class | x |", 0),
        ("grouped", f"| `{plain}` / `{plain2}` / `{enum}` | classes / enum | x |", 0),
        ("grouped, wrong", f"| `{plain}` / `{plain2}` / `{enum}` | classes | x |", 1),
        ("modifier dropped", f"| `{abstract}` / `{plain}` | class | x |", 1),
        ("prose cell", "| 20 family branch bases | abstract class | x |", 1),
        ("member span", f"| `{plain}.member` | factory | x |", 0),
    ]
    failed = 0
    for name, row, expected in cases:
        report = audit_text(Path("self-test.md"), header + row + "\n", kinds)
        got = 0 if report is None else len(report.faults) + len(report.unparsed)
        if got != expected:
            print(f"self-test: {name}: {got} fault(s), expected {expected}\n"
                  f"  {row}", file=sys.stderr)
            failed += 1

    dependency = ("| Dependency | Kind | Imported by |\n| --- | --- | --- |\n"
                  "| `dart:io` | SDK | x |\n")
    if audit_text(Path("self-test.md"), dependency, kinds) is not None:
        print("self-test: a dependency table was audited", file=sys.stderr)
        failed += 1

    if failed:
        return 2
    print(f"self-test: {len(cases) + 1} cases behave")
    return 0


def main(argv: list[str]) -> int:
    if argv[1:] == ["--self-test"]:
        kinds = all_declarations()
        return self_test(kinds) if kinds else 2
    prefix = argv[1] if len(argv) > 1 else ""

    # The index is always built from the whole repo even when a subtree is being
    # checked: a document in one package routinely tabulates a type declared in
    # another, and a subtree-scoped index would call every one of those unknown
    # and skip it -- reporting a clean tree by looking at less of it.
    kinds = all_declarations()
    if not kinds:
        print(f"no declarations found under {REPO_ROOT}", file=sys.stderr)
        return 2

    documents = collect_documents(prefix)
    reports = [r for r in (audit(p, kinds) for p in documents) if r is not None]

    # A checker that quietly stops finding kind tables reports a clean tree,
    # which is the one way this kind of audit fails without anyone noticing.
    if not reports:
        roots = ", ".join(str(base) for base, _ in DOCUMENT_ROOTS)
        print(f"no Kind tables found under {roots}", file=sys.stderr)
        return 2

    defective = [r for r in reports if not r.clean]
    for report in defective:
        print(report.render())

    faults = sum(len(r.faults) + len(r.unparsed) for r in defective)
    if defective:
        print("\n-- most common substitutions --")
        pairs = Counter(
            (claimed, actual)
            for report in defective
            for _, _, claimed, actual in report.faults
        )
        for (claimed, actual), count in pairs.most_common(10):
            print(f"  {count:3d}  {claimed!r:28} -> {actual!r}")

    print(
        f"\nkind tables audited     : {len(reports)}\n"
        f"kind claims checked     : {sum(r.rows for r in reports)}\n"
        f"documents defective     : {len(defective)}\n"
        f"claims naming a non-kind: {faults}"
    )
    return report_faults(faults)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
