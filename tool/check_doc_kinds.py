#!/usr/bin/env python3
"""Find `Kind` columns that name something Dart does not declare.

Run from anywhere::

    python3 tool/check_doc_kinds.py                  # whole repo
    python3 tool/check_doc_kinds.py tom_core_agentic # one subtree

Exits non-zero when a claim disagrees with the source, so it can gate a build.

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
listed as ``exception``: true as a description, and it happens to be a plain
``class``, so a reader who wanted to extend it was left to guess. Its neighbour
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
column -- that restriction is what keeps this honest. Module documents carry
other two-column tables of the same shape (a symbol beside its wire code, a
placeholder form beside its meaning), and reading those as kind claims produced
four false positives per real one when this was first measured. A symbol the
repo does not declare is skipped rather than reported: these documents name
Flutter and Dart core types freely, and this checker has no index for them.

**What counts as correct** is the declaration's modifiers verbatim, in source
order: ``final class``, ``abstract interface class``, ``sealed class``,
``enum``, ``typedef``, ``mixin``, ``extension type``, ``extension``. Bare ``class`` is
correct only for a class with no modifiers. ``function`` and ``getter`` are
accepted for the two top-level forms that have no keyword of their own -- the
completion documents already use both words and each names a real declaration
form. A top-level ``const`` / ``final`` is written the way the documents write
it, as the modifier plus the type: ``const String``, ``const int``.

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

REPO_ROOT = Path(__file__).resolve().parent.parent

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

KIND_HEADER = re.compile(r"^\|[^|]+\|\s*Kind\s*\|")
TABLE_RULE = re.compile(r"^\|[\s\-:|]+\|$")
ROW = re.compile(r"^\|\s*`?([^`|]+?)`?\s*\|\s*([^|]+?)\s*\|")


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


@dataclass
class Report:
    document: Path
    rows: int = 0
    faults: list[tuple[int, str, str, str]] = field(default_factory=list)

    @property
    def clean(self) -> bool:
        return not self.faults

    def render(self) -> str:
        lines = [str(self.document.relative_to(REPO_ROOT))]
        for line_no, symbol, claimed, actual in self.faults:
            lines.append(
                f"  :{line_no:<4} {symbol:<38} says {claimed!r}, is {actual!r}"
            )
        return "\n".join(lines)


def audit(document: Path, kinds: dict[str, str]) -> Report | None:
    try:
        text = document.read_text()
    except (OSError, UnicodeDecodeError):
        return None

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
        # Strip any type arguments: the table writes the symbol as the reader
        # will use it, the source declares it bare.
        symbol = match.group(1).split("<")[0].strip()
        claimed = match.group(2).strip().strip("`")
        actual = kinds.get(symbol)
        if actual is None:
            continue
        report.rows += 1
        if claimed != actual:
            report.faults.append((line_no, symbol, claimed, actual))

    return report if report.rows else None


def main(argv: list[str]) -> int:
    prefix = argv[1] if len(argv) > 1 else ""

    # The index is always built from the whole repo even when a subtree is being
    # checked: a document in one package routinely tabulates a type declared in
    # another, and a subtree-scoped index would call every one of those unknown
    # and skip it -- reporting a clean tree by looking at less of it.
    kinds = index_declarations(REPO_ROOT)
    if not kinds:
        print(f"no declarations found under {REPO_ROOT}", file=sys.stderr)
        return 2

    documents = sorted(
        p
        for p in REPO_ROOT.rglob("doc/*.md")
        if str(p.relative_to(REPO_ROOT)).startswith(prefix)
    )
    reports = [r for r in (audit(p, kinds) for p in documents) if r is not None]

    # A checker that quietly stops finding kind tables reports a clean tree,
    # which is the one way this kind of audit fails without anyone noticing.
    if not reports:
        print(f"no Kind tables found under {REPO_ROOT}", file=sys.stderr)
        return 2

    defective = [r for r in reports if not r.clean]
    for report in defective:
        print(report.render())

    faults = sum(len(r.faults) for r in defective)
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
    return 1 if defective else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
