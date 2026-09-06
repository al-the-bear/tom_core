#!/usr/bin/env python3
"""Find documentation that attributes a member to a `Tom*` type that lacks it.

Run from anywhere::

    python3 tool/check_member_attributions.py                 # whole repo
    python3 tool/check_member_attributions.py tom_flutter_ui  # one subtree
    python3 tool/check_member_attributions.py --self-test     # check the checker

Exits non-zero when a document writes ``Type.member`` for a repo-declared
``Tom*`` type that declares no such member, so it can gate a build.

**The fault.** A document names a method under a heading naming a class, and
neither half is checked against the other. `tom_flutter_ui_test`'s
`doc/widget_resource_parameters.md` carried a nineteen-row table headed
"Primitive Resolvers (TomNodeBase)" in which seven of the methods existed
nowhere in `lib/`, the twelve that did were declared on a different type, and
`TomNodeBase` itself declared none of them. The body then prescribed those
methods 1,140 times across 291 widgets. Every one of the seven turned out to be
a real capability under an invented name -- `resolveResourceOrNull` for
`TomCtr.textOrNull`, `resolveColorOrFail` for `TomCtr.colorOrFail` -- so the
document was not fiction but a systematic rename away from the truth, which is
the harder thing to see: each row is individually plausible and the table as a
whole looks vetted.

**Why the neighbouring gates miss it.** `check_dartdoc_refs` resolves ``[name]``
in Dart comments, not prose in markdown. `check_doc_attributions` asks what a
*type* is and where it lives, never what it declares. `check_consumer_claims`
and `check_doc_class_inventories` both ask whether a **type** exists; a member
is a finer thing, and a document can name only types that exist and still
attribute every one of their methods wrongly. Existence, kind and *membership*
are three questions and only the third is asked here.

**Why this decays.** Renaming a method updates its call sites, because they stop
compiling. It does not update the markdown table that names it, because nothing
reads that table. So the gap opens on the ordinary path -- a rename, an
extraction, a move between a class and a mixin -- and leaves no trace in the
diff of either file.

**What is checked, and the restrictions that keep it honest.**

A reference is read as an attribution only when all of these hold:

1. It is written in backticks as ``Type.member``. Unbackticked prose is not a
   claim about an API, and reading it as one produces the false positives this
   restriction exists to prevent.
2. ``Type`` starts with ``Tom`` and is *declared in this repository*. Flutter
   and SDK types are out of scope by construction rather than by a suppression
   list, because this checker cannot see their members and a gate that guesses
   is worse than one that abstains.
3. ``member`` starts lowercase. ``TomFoo.Bar`` is not a member reference, and
   the enum-shaped ``TomAuthState.none`` *is* -- enum values are members and are
   checked like any other.
4. The type's inheritance closure is **fully visible**. A class extending or
   mixing in something this repo does not declare (``extends SnackBar``,
   ``with ChangeNotifier``) inherits members that cannot be enumerated here, so
   every one of its types is skipped entirely. Half a member list would fail
   open on the members it has and closed on the ones it cannot see; abstaining
   says so.

Members are collected from the whole closure -- superclass, mixins, interfaces
-- so a document may attribute an inherited member to the subtype that offers
it, which is how a reader meets it. Extension members are collected onto the
type they extend for the same reason.

**Writing a name qualified is what puts it in scope.** Restrictions 1 and 4
together mean this gate reads ``Type.member`` against a fully visible type and
nothing else. The nineteen-row table above escaped it twice over before it was
repaired: the methods were written bare, with the owning type named only in a
heading, and the type that heading named -- `TomNodeBase`, which
``extends StatelessWidget`` -- is one this checker abstains on. Qualifying the
1,181 references to `TomCtr` and `TomStyleResolvers`, both of which extend
nothing, is what moved that document from unverifiable to verified. A table
whose Resolver column holds a bare method name is not caught here, and the
remedy is to qualify it rather than to loosen this gate: an unqualified name
gives the checker no type to check it against, and guessing one from the nearest
heading is how a plausible-looking table stays wrong.

``CHANGELOG.md`` is excluded: an entry records what was true when it was
written, and correcting it would falsify a record rather than repair a claim.
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

from gate_report import report_faults

TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parent

#: A backticked ``Type.member``. The member may itself be followed by a call's
#: empty parentheses, which readers write and which say nothing extra.
REFERENCE = re.compile(r"`(Tom[A-Za-z0-9_]*)\.([a-z_][A-Za-z0-9_]*)(?:\(\))?`")

#: A type declaration and its clause list, e.g.
#: ``class TomFoo<T> extends TomBar with TomMixin implements TomThing {``.
DECLARATION = re.compile(
    r"^\s*(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|mixin\s+)*"
    r"(class|mixin|enum|extension)\s+(\w+)"
    r"(?:\s*<[^>]*>)?"
    r"((?:\s+(?:on|extends|with|implements)\s+[^{]*?)?)"
    r"\s*\{",
    re.MULTILINE,
)

#: The type names in an ``extends`` / ``with`` / ``implements`` / ``on`` clause.
SUPERTYPE = re.compile(r"\b([A-Z]\w*)")

#: A member declared inside a class body. Deliberately loose about the return
#: type -- what matters is the name in a member position, and over-collecting a
#: name that is really a local would only make this gate quieter, never louder.
#:
#: The return-type group is **greedy**, which is load-bearing rather than
#: incidental. Lazily, ``static List<dynamic>? list(...)`` matches with the type
#: skipped: the name group takes ``List`` and the ``<`` that opens the type
#: argument satisfies the generic-method branch of the follow set. The member is
#: then indexed under its own return type and `list` is reported missing. Greedy
#: consumption prefers the longest type and leaves the real name.
#:
#: A Dart type may itself contain parentheses -- a record type
#: (``static (TomTransaction, bool) startTransaction(...)``), a record nested in
#: a generic (``Future<(R result, TomServerCallError? ts)> send(...)``), or a
#: function type (``final Widget Function(Widget content)? builder;``) -- so the
#: type group has to be able to cross one. Admitting ``(`` to a flat character
#: class is the wrong way to do it: greedy matching then lets the type stop
#: *inside* a parameter list, and in
#: ``static Color? color(String? basePath, [String suffix = ''])`` it takes
#: ``Color? color(String? basePath, [String`` and leaves ``suffix`` as the name.
#: That single character cost 1,057 spurious faults, `TomCtr.color` among them.
#:
#: Requiring the parentheses to be **balanced** is what makes it safe. The type
#: can then only end outside a parenthesis, so it can span a record or a
#: parameter list but never stop halfway through one -- and a type that
#: swallowed the whole parameter list is rejected a step later, because the
#: ``{`` or ``=>`` that follows is not an identifier and the match backtracks to
#: the real name. One level of nesting is enough for the types that occur
#: (``List<(double, T)>`` inside a record). ``;`` is excluded from the group so a
#: runaway match cannot wander out of a signature and into a body.
#:
#: Braces are *not* excluded, because a record type may be named:
#: ``static ({TomSchemaModel schema, List<TomSchemaDivergence> divergences}) read(``
#: puts them inside the return type. Excluding them hid `TomEntitySchemaReader.read`
#: and `TomAnnotationAnalyzer.referenceQuery`, both of which the source does
#: declare. Admitting them is safe only in combination with the newline
#: exclusion below: a body's opening brace ends its line, so a group that cannot
#: cross a newline cannot reach into a body no matter what it admits.
#:
#: Newlines are excluded for the same reason, and the reason is not obvious: the
#: plain character class cannot cross one, but a parenthesised group could, and
#: because `re.findall` returns non-overlapping matches, one greedy match that
#: spans several lines *consumes the declarations in between* -- their names are
#: never offered as a name group at all. Permitting it silently lost `TomServer.start`
#: and 33 other members. A record or function type in return position is written
#: on one line; a parameter list that wraps is matched by backtracking to the
#: short type, which is the parse we want anyway.
#:
#: The name carries a negative lookahead for ``async`` / ``sync`` because those
#: sit exactly where a name can. In ``void start() async {`` the type is free to
#: take ``void start()`` -- balanced, on one line -- leaving ``async`` in the
#: name position with ``{`` to follow, a parse the pattern otherwise prefers
#: because it is longer. Rejecting the modifier forces the backtrack to
#: ``void`` / ``start`` / ``(``. They cannot be handled by [NOT_MEMBERS]
#: instead: that filters names after the fact, and by then the real name has
#: already been passed over.
_BALANCED = r"\((?:[^();\n]|\([^();\n]*\))*\)"
MEMBER = re.compile(
    r"^\s{2,}(?:@\w+(?:\([^)]*\))?\s*)*"
    r"(?:static\s+|final\s+|const\s+|late\s+|external\s+|abstract\s+|covariant\s+)*"
    r"(?:(?:get|set)\s+)?"
    r"(?:(?:[\w<>,\[\]?.$ ]|" + _BALANCED + r")+\s+)?"
    r"(?:get\s+|set\s+)?"
    r"(?!(?:async|sync)\b)(\w+)\s*(?:[(<=;]|=>|\{)",
    re.MULTILINE,
)

#: One constant in an enum's constant list -- the identifier, and the
#: constructor arguments or type arguments an enhanced enum may attach to it.
#:
#: Needed as a separate pattern because [MEMBER] cannot see these. A constant is
#: followed by a comma, and a comma cannot join that pattern's follow set: it is
#: also what separates parameters, so admitting it would collect every parameter
#: name in the file as a member of the enclosing type.
ENUM_CONSTANT = re.compile(r"^\s*([a-z_]\w*)\s*(?:<[^>]*>)?\s*(?:\([^)]*\))?\s*(?:,|;|$)")

#: A named constructor, ``const TomDbScope.unscoped() : ...``. A reader reaches
#: one exactly as they reach a static, so a document naming it is making the
#: same kind of claim; [MEMBER] cannot see it because the name it would capture
#: is followed by a dot.
NAMED_CONSTRUCTOR = re.compile(r"^\s{2,}(?:const\s+|factory\s+)*(\w+)\.(\w+)\s*\(", re.MULTILINE)

#: Words that appear in a member position but declare nothing.
#:
#: Dart's **reserved** words only — the ones that cannot be an identifier, so
#: excluding them can never hide a real member. Dart's *built-in* identifiers
#: (``get``, ``set``, ``factory``, ``operator``, ``as``, ``on``, ``show``,
#: ``required``, …) are deliberately absent: every one of them is a legal member
#: name and several are used as one here. `TomObject` declares a method called
#: `get`, and while ``get`` sat in this set every document naming a `.get`
#: member — five of them, across the kernel and server — was accused of naming
#: something that exists.
#:
#: The two errors are not symmetric. Over-collecting a word that declares
#: nothing costs a fault this gate would otherwise have found; under-collecting
#: a real member accuses correct documentation. This set is sized for the
#: second, which is the one that wastes a reader's time and teaches them to
#: distrust the gate.
NOT_MEMBERS = frozenset(
    {
        "assert", "break", "case", "catch", "class", "const", "continue",
        "default", "do", "else", "enum", "extends", "false", "final",
        "finally", "for", "if", "in", "is", "new", "null", "rethrow",
        "return", "super", "switch", "this", "throw", "true", "try", "var",
        "void", "while", "with",
    }
)


@dataclass
class TypeInfo:
    """One declared type: where it lives, what it names, what it declares."""

    name: str
    source: Path
    kind: str
    supertypes: set[str] = field(default_factory=set)
    own_members: set[str] = field(default_factory=set)


def mask_literals(source: str) -> str:
    """``source`` with comment and string-literal *contents* blanked to spaces.

    Length and line breaks are preserved, so offsets and line numbers taken from
    the result address the original file, and code outside literals is returned
    untouched. Delimiters are kept; only what they enclose is erased.

    This exists because [body_of] counts braces, and a brace inside a string is
    not a brace. `TomAnnotationAnalyzer` raises a syntax error whose message ends
    ``"... must have @TomDbColumn annotation.'}"`` -- one ``}`` in prose, which
    closed the mixin 29 lines early and took `referenceQuery` with it. The member
    was then reported missing from two documents that named it correctly.

    Masking comments as well is a second benefit rather than an accident: a
    dartdoc code sample is not a declaration, and reading members out of one
    would let a type appear to declare whatever its examples happen to show.
    """
    out: list[str] = []
    index = 0
    length = len(source)
    while index < length:
        char = source[index]
        # Line comment: keep the marker, blank the rest of the line.
        if source.startswith("//", index):
            end = source.find("\n", index)
            end = length if end == -1 else end
            out.append("//" + " " * (end - index - 2))
            index = end
            continue
        # Block comment: Dart allows nesting, so track depth.
        if source.startswith("/*", index):
            depth, cursor = 0, index
            while cursor < length:
                if source.startswith("/*", cursor):
                    depth += 1
                    cursor += 2
                elif source.startswith("*/", cursor):
                    depth -= 1
                    cursor += 2
                    if depth == 0:
                        break
                else:
                    cursor += 1
            chunk = source[index:cursor]
            out.append("".join(c if c == "\n" else " " for c in chunk))
            index = cursor
            continue
        if char in "'\"":
            raw = index > 0 and source[index - 1] == "r"
            triple = source.startswith(char * 3, index)
            quote = char * 3 if triple else char
            cursor = index + len(quote)
            while cursor < length:
                if not raw and source[cursor] == "\\":
                    cursor += 2
                    continue
                if source.startswith(quote, cursor):
                    cursor += len(quote)
                    break
                # A single-quoted string never spans a line; bail out rather
                # than swallowing the file when a lone apostrophe appears.
                if not triple and source[cursor] == "\n":
                    break
                cursor += 1
            chunk = source[index:cursor]
            body = chunk[len(quote) : len(chunk) - len(quote)] if len(chunk) >= 2 * len(quote) else ""
            out.append(
                quote
                + "".join(c if c == "\n" else " " for c in body)
                + (quote if len(chunk) >= 2 * len(quote) else "")
            )
            index = cursor
            continue
        out.append(char)
        index += 1
    masked = "".join(out)
    assert len(masked) == length, "mask_literals must preserve offsets"
    return masked


def body_of(text: str, open_brace: int) -> str:
    """The source between ``open_brace`` and its matching close.

    Brace counting rather than a regex, because a class body contains braces:
    method bodies, collection literals, string interpolations. It is not a Dart
    parser and does not need to be -- a miscount would end the body early and
    lose members, which makes this gate quieter, and quieter is the safe
    direction for a checker that can only *accuse*.

    Callers pass text that [mask_literals] has already cleaned, so the braces
    counted here are all real ones.
    """
    depth = 0
    for index in range(open_brace, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[open_brace + 1 : index]
    return text[open_brace + 1 :]


def strip_comments(source: str) -> str:
    """``source`` with line and block comments blanked out.

    Newlines are preserved so that anything reading the result line by line
    still sees the original shape.
    """
    source = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), source, flags=re.S)
    return re.sub(r"//[^\n]*", "", source)


def enum_constants(body: str) -> set[str]:
    """The constants declared at the head of an enum body.

    An enhanced enum's constant list ends at the first ``;``, after which the
    body is ordinary members that [MEMBER] reads. A plain enum has no ``;`` and
    the whole body is constants.

    Comments are stripped **before** the split, not after. `TomWidgetFamily`
    documents its six reserved constants in a paragraph that contains a
    semicolon; splitting first ended the constant list inside that prose and
    lost the six constants it was describing, which then read as missing in
    every document that named them.
    """
    head = strip_comments(body).split(";", 1)[0]
    constants: set[str] = set()
    for line in head.splitlines():
        line = line.strip()
        if not line or line.startswith("@"):
            continue
        for piece in line.split(","):
            match = ENUM_CONSTANT.match(piece.strip())
            if match and match.group(1) not in NOT_MEMBERS:
                constants.add(match.group(1))
    return constants


def index_types(root: Path) -> dict[str, list[TypeInfo]]:
    """Every type this repository declares, by name.

    A list per name rather than one entry: a name may be declared more than
    once across packages, and an attribution is satisfied if *any* of them
    carries the member. Picking one arbitrarily would accuse a document of
    naming a member that the type its reader means does have.
    """
    types: dict[str, list[TypeInfo]] = defaultdict(list)
    for path in root.rglob("*.dart"):
        if any(part.startswith(".") for part in path.parts):
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        if "class " not in text and "mixin " not in text and "enum " not in text:
            continue
        text = mask_literals(text)
        for match in DECLARATION.finditer(text):
            kind, name, clauses = match.group(1), match.group(2), match.group(3)
            info = TypeInfo(name=name, source=path, kind=kind)
            info.supertypes = set(SUPERTYPE.findall(clauses))
            body = body_of(text, match.end() - 1)
            info.own_members = {
                m for m in MEMBER.findall(body) if m not in NOT_MEMBERS
            }
            info.own_members |= {
                constructor
                for owner, constructor in NAMED_CONSTRUCTOR.findall(body)
                if owner == name
            }
            if kind == "enum":
                info.own_members |= enum_constants(body)
            if kind == "extension":
                # An extension's members read as members of the type it
                # extends, which is the only way a document can name them.
                for extended in info.supertypes:
                    types[extended].append(
                        TypeInfo(
                            name=extended,
                            source=path,
                            kind="extension",
                            own_members=info.own_members,
                        )
                    )
                continue
            types[name].append(info)
    return types


#: What every Dart type carries from `Object` without declaring it. A document
#: naming one of these is correct, and the source it is checked against will
#: never contain the declaration, because the language supplies it.
OBJECT_MEMBERS = frozenset({"toString", "hashCode", "runtimeType", "noSuchMethod"})

#: What an `enum` carries in addition. `index` and `name` come from `Enum` --
#: which an enum implements implicitly, so unlike an ordinary `extends` clause
#: there is no supertype in the declaration for [closure] to walk to and abstain
#: on. `values` is the static constant list the compiler synthesises.
#:
#: Without these, `TomAuthState.name` reads as a fault in four documents: the
#: enum's inheritance closure looks complete -- it names no supertype at all --
#: so the checker believes its member list is exhaustive when the language has
#: silently extended it.
ENUM_MEMBERS = frozenset({"index", "name", "values"})


def closure(name: str, types: dict[str, list[TypeInfo]]) -> set[str] | None:
    """Every member visible on ``name``, or ``None`` if that cannot be known.

    ``None`` is returned when the walk reaches a supertype this repository does
    not declare. That is not a failure to look hard enough -- the member list of
    `SnackBar` is in the Flutter SDK -- and reporting a partial list as complete
    would accuse documents of naming members that genuinely exist.
    """
    members: set[str] = set(OBJECT_MEMBERS)
    seen: set[str] = set()
    pending = [name]
    while pending:
        current = pending.pop()
        if current in seen:
            continue
        seen.add(current)
        entries = types.get(current)
        if not entries:
            return None
        for info in entries:
            members |= info.own_members
            if info.kind == "enum":
                members |= ENUM_MEMBERS
            pending.extend(info.supertypes)
    return members


@dataclass
class Report:
    """One document's attributions and the ones its source denies."""

    document: Path
    claims: int = 0
    faults: list[tuple[int, str, str, Path]] = field(default_factory=list)

    @property
    def clean(self) -> bool:
        return not self.faults

    def render(self) -> str:
        lines = [f"\n{self.document}"]
        for number, type_name, member, source in self.faults:
            lines.append(
                f"  line {number}: `{type_name}.{member}` — {type_name} is "
                f"declared in {source} and has no member named {member}"
            )
        return "\n".join(lines)


def audit(path: Path, types: dict[str, list[TypeInfo]]) -> Report | None:
    """Read one document; return its report, or ``None`` if it makes no claims."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None

    report = Report(document=path.relative_to(REPO_ROOT))
    for number, line in enumerate(text.splitlines(), start=1):
        for type_name, member in REFERENCE.findall(line):
            entries = types.get(type_name)
            if not entries:
                # Not declared here -- out of scope, per restriction 2.
                continue
            members = closure(type_name, types)
            if members is None:
                # Inheritance leaves the repository; abstain, per restriction 4.
                continue
            report.claims += 1
            if member not in members:
                report.faults.append(
                    (number, type_name, member, entries[0].source.relative_to(REPO_ROOT))
                )
    return report if report.claims else None


def documents(prefix: str) -> list[Path]:
    return sorted(
        path
        for path in REPO_ROOT.rglob("*.md")
        if path.name != "CHANGELOG.md"
        and not any(part.startswith(".") for part in path.parts)
        and str(path.relative_to(REPO_ROOT)).startswith(prefix)
    )


def self_test(types: dict[str, list[TypeInfo]]) -> int:
    """Perturb an attribution this gate calls correct and require it to object.

    A zero fault count is also what a checker that has stopped reading anything
    reports. This asks the question the count cannot: take a document the gate
    passes, break one reference in each of the two ways that matter, and require
    a fault each time.
    """
    subject = REPO_ROOT / "tom_flutter_ui_test/doc/widget_resource_parameters.md"
    if not subject.exists():
        print(f"self-test: {subject} is gone", file=sys.stderr)
        return 2

    original = subject.read_text(encoding="utf-8")
    before = audit(subject, types)
    if before is None:
        print("self-test: subject makes no attributions to perturb", file=sys.stderr)
        return 2
    if not before.clean:
        print(f"self-test: {subject} is already defective", file=sys.stderr)
        return 2

    try:
        # (1) An invented member on a type that is real and fully visible.
        subject.write_text(
            original.replace("`TomCtr.doubleVal`", "`TomCtr.doubleValue`", 1),
            encoding="utf-8",
        )
        if audit(subject, types).clean:
            print(
                "self-test: an invented member raised no fault", file=sys.stderr
            )
            return 1

        # (2) A real member attributed to the wrong -- but also real -- type.
        # This is the fault the gate was written for, and the one a checker
        # that only asked "does this name exist anywhere" would miss.
        #
        # The receiving type has to be one whose closure is visible, which is
        # why it is `TomStyleResolvers` and not the `TomNodeBase` the original
        # defect named: `TomNodeBase extends StatelessWidget`, so restriction 4
        # abstains on it and the perturbation would pass unnoticed -- correct
        # behaviour, and useless as a probe.
        subject.write_text(
            original.replace(
                "`TomCtr.doubleVal`", "`TomStyleResolvers.doubleVal`", 1
            ),
            encoding="utf-8",
        )
        if audit(subject, types).clean:
            print(
                "self-test: a member moved to a type that does not declare it "
                "raised no fault",
                file=sys.stderr,
            )
            return 1
    finally:
        subject.write_text(original, encoding="utf-8")

    print("self-test: invented and misattributed members both fire")
    return 0


def main(argv: list[str]) -> int:
    arguments = argv[1:]
    testing = "--self-test" in arguments
    prefix = next((a for a in arguments if not a.startswith("-")), "")

    types = index_types(REPO_ROOT)
    # An empty index would let every attribution pass, reporting a clean tree by
    # looking at nothing -- the one way this audit fails silently.
    if not types:
        print(f"no type declarations found under {REPO_ROOT}", file=sys.stderr)
        return 2

    if testing:
        return self_test(types)

    reports = [r for r in (audit(p, types) for p in documents(prefix)) if r is not None]
    # Likewise: a checker that stops recognising the references reports success.
    if not reports:
        print(f"no member attributions found under {REPO_ROOT}", file=sys.stderr)
        return 2

    defective = [r for r in reports if not r.clean]
    for report in defective:
        print(report.render())

    faults = sum(len(r.faults) for r in defective)
    print(
        f"\ndocuments with attributions: {len(reports)}\n"
        f"attributions read          : {sum(r.claims for r in reports)}\n"
        f"types indexed              : {len(types)}\n"
        f"documents defective        : {len(defective)}\n"
        f"members the source denies  : {faults}"
    )
    return report_faults(faults)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
