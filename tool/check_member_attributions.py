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

**Member tables read the type from their heading.** The rule above has one
place where it would leave the most common shape of claim unread: a table of a
type's API, written under a heading that names the type, whose first column
lists the members bare -- ``| `convertToTzSameInstant(TomTimezone t)` | ... |``
under ``### `TomZonedDate```. That is where a rename was observed to survive:
`convertToTimezone` became `convertToTzSameInstant`, the package's own documents
followed, and the completion write-up kept three method tables and a worked
example naming the old method while every gate reported clean. So a table is
also read, under these conditions:

5. Its header's first cell is ``Member``, ``Method``, ``Methods``, ``Getter``,
   ``Field``, ``Property``, ``Constructor`` or ``Static method`` -- a column that
   says, in the document's own words, that it lists members. A ``Key`` or
   ``Type`` table under the same heading is not read.
6. The candidate owners are every repo-declared type named by the **nearest
   enclosing heading that names one** (``#### Static methods`` names none, so
   the ``### `TomTimezone``` above it decides) together with every one named by
   the **paragraph that introduces the table** -- "`TomAuthenticationData`
   carries the attempt. All nine fields ..." under a heading about
   `TomAuthenticationService` is a table of the former. A row is accepted if
   **any** candidate declares its name. A fenced code block directly above
   the table -- a constructor shown whole, then its parameters tabulated --
   counts as the lead-in. Choosing one candidate would be a
   guess -- a lead-in routinely names a related type the table is not about --
   and a guess this gate makes wrongly is an accusation. The union can only
   err quiet, and it still catches what it exists for: a renamed member exists
   on no candidate at all. An annotation (`@TomDbTable`) is not a subject and
   is not counted; a table nothing names is not read.
7. The first cell's backticked name is judged -- keywords (``static``, ``get``,
   ``factory``, ...) and the parameter list stripped. A name ending in ``:``
   (or ``name: value``) is a named argument or a configuration key and is not
   judged. A name the repository declares at **top level** -- an annotation
   constant such as `tomService`, a function such as `tomConsumesForm` -- is
   accepted when it is declared under the ``lib/`` of the owner's own package
   -- the API a table documents, not a test's helper: tables that document
   an API list those beside the members. A name starting uppercase
   is a constructor or a type, not a member, and is left alone unless it is
   ``Owner.named``, which is judged as a named constructor. ``operator`` rows
   are not judged.

A member table may list the owner's **constructor parameters** as well as its
members -- a "Resource fallbacks" table of the arguments `TomAclBuilder` stores
privately is naming real API -- so a name is accepted if the owner declares it
as either.

**The Dart SDK completes a closure.** Restriction 4 on its own abstains on
exactly the type the rename above happened on: `TomZonedDate` extends
`TomTimezoned`, which extends `DateTime`, so its member list could not be
enumerated and a table naming the gone `convertToTimezone` was not read. The
SDK's library sources ship beside the `dart` executable every gate already
needs, so the public ``dart:`` libraries are indexed the same way and a closure
that reaches `DateTime`, `Comparable` or `Iterable` continues through them --
`toUtc` then resolves on `DateTime`, and `convertToTimezone` resolves nowhere.
They complete closures only: a table or a qualified reference is judged only
when its *owner* is declared in this repository. A closure that reaches a
non-SDK foreign type (`StatelessWidget`, `ChangeNotifier`) is still abstained
on, and so is every closure when the SDK cannot be found -- the summary line
says which.

**Two roots.** The package documents under this repository are one set; the
completion corpus in ``_ai/quests/tom_core/completion/`` is the other, and it
is where the rename above survived. The quest folder is a separate clone, so a
missing root is skipped rather than fatal, but a present one is always read.

``CHANGELOG.md`` is excluded: an entry records what was true when it was
written, and correcting it would falsify a record rather than repair a claim.
In a completion document, **part 3** -- ``## What changed`` or ``## What this
adds`` -- is not read, except its ``### What is still open`` subsection. The
corpus contract (``completion/README.md``) makes part 3 "the only historical
part of the document" and requires removed and renamed members to be named
there explicitly, so a name the source no longer declares is what that section
is for. "What is still open" is a claim about now, and is read.

A document that opens (within its first ten lines) with a
``<!-- record: <why> -->`` comment is excluded for the same reason -- a design
record or an executed migration plan that names the members of the state it
replaced. The comment has to say why, and the document should say so to its
reader too; a record is not a place to put a document this gate would
otherwise catch.
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

from gate_report import report_faults
import gate_scope

TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parent
WORKSPACE_ROOT = REPO_ROOT.parent.parent

#: The public ``dart:`` libraries indexed to complete a closure (see "The Dart
#: SDK completes a closure").
SDK_LIBRARIES = ("core", "async", "collection", "convert", "io", "math", "typed_data", "isolate")

#: Types the Dart SDK declares, consulted only when a closure leaves the repo.
SDK_TYPES: dict[str, list["TypeInfo"]] = {}


def sdk_library_root() -> Path | None:
    """The Dart SDK's ``lib/`` directory, found from ``DART_SDK`` or ``dart``."""
    import os
    import shutil

    candidates = []
    if os.environ.get("DART_SDK"):
        candidates.append(Path(os.environ["DART_SDK"]) / "lib")
    dart = shutil.which("dart")
    if dart:
        bin_dir = Path(dart).resolve().parent
        candidates += [bin_dir / "cache" / "dart-sdk" / "lib", bin_dir.parent / "lib"]
    return next((c for c in candidates if (c / "core").is_dir()), None)


#: The completion corpus: the second document root (see "Two roots").
COMPLETION = WORKSPACE_ROOT / "_ai" / "quests" / "tom_core" / "completion"

#: First header cells that declare a table to be a list of members (rule 5).
MEMBER_TABLE_HEADERS = frozenset(
    {
        "member", "members", "method", "methods", "getter", "getters",
        "field", "fields", "property", "properties", "constructor",
        "constructors", "static method", "static methods",
    }
)

#: A markdown heading.
HEADING = re.compile(r"^(#{1,6})\s+(.*)$")

#: Words that may lead a member cell before its name.
CELL_KEYWORDS = frozenset(
    {"static", "get", "set", "factory", "const", "final", "late", "abstract",
     "external", "covariant", "async", "void"}
)

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

#: A top-level declaration: a function, getter, variable or constant at column
#: zero. Read from the same masked text as members, so a comment or a string
#: cannot contribute one.
TOP_LEVEL = re.compile(
    # `(?=\S)`: at column zero. The type group admits spaces, so without it an
    # indented field -- a class member -- would read as top-level.
    r"^(?=\S)(?:external\s+)?(?:final\s+|const\s+|late\s+|var\s+)*"
    r"(?:(?:[\w<>,\[\]?.$ ]|" + _BALANCED + r")+\s+)?"
    r"(?:get\s+|set\s+)?"
    r"(?!(?:async|sync|class|enum|mixin|extension|typedef|import|export|part|library)\b)"
    r"([a-z_]\w*)\s*(?:[(<=;]|=>|\{)",
    re.MULTILINE,
)

#: Every top-level name [index_types] saw, by package, for rule 7. Scoped to
#: the package because common words -- `rows`, `columns` -- are declared at top
#: level somewhere in a tree this size, and accepting them repo-wide would pass
#: a member table that names them on the wrong type.
TOP_LEVEL_NAMES: dict[str, set[str]] = defaultdict(set)


def package_of(path: Path) -> str:
    """The package directory a source file belongs to (first path segment)."""
    try:
        return gate_scope.rel(path).parts[0]
    except (ValueError, IndexError):
        return ""

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
    parameters: set[str] = field(default_factory=set)


#: What a string literal's contents are blanked to: neither a word character
#: nor whitespace.
#:
#: Not a space, which is what comments are blanked to. A multi-line string
#: blanked to spaces leaves lines that are nothing but whitespace inside a class
#: body, and [MEMBER] -- whose leading indentation and whose type group both
#: accept spaces -- tries every way of dividing such a line between the two
#: before it fails. `base_server_configuration.dart`, whose development TLS pair
#: is two such literals, took 212 of this gate's 267 seconds that way. A
#: character neither part of the pattern accepts fails each of those lines at
#: once. Comments stay blanked to spaces: code may need whitespace to span a
#: comment between two tokens, and a string's contents are never that.
STRING_FILL = "#"


def mask_literals(source: str) -> str:
    """``source`` with comment and string-literal *contents* blanked out.

    Comments become spaces and string contents [STRING_FILL].

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
                + "".join(c if c == "\n" else STRING_FILL for c in body)
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
        # `extension ` counts as a declaration too: a part file that holds only
        # extensions on a type declared elsewhere carries members a document
        # can name, and skipping it would report them missing.
        if not any(
            keyword in text for keyword in ("class ", "mixin ", "enum ", "extension ")
        ):
            if "lib" in path.parts:
                TOP_LEVEL_NAMES[package_of(path)].update(
                    n
                    for n in TOP_LEVEL.findall(mask_literals(text))
                    if n not in NOT_MEMBERS
                )
            continue
        text = mask_literals(text)
        if "lib" in path.parts:
            TOP_LEVEL_NAMES[package_of(path)].update(
                n for n in TOP_LEVEL.findall(text) if n not in NOT_MEMBERS
            )
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
            info.parameters = constructor_parameter_names(body, name)
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


def constructor_parameter_names(body: str, name: str) -> set[str]:
    """The parameter names of ``name``'s constructors declared in ``body``.

    Over-collects rather than under: a type or a default value caught as a
    "name" can only make a member table quieter, never accuse it.
    """
    names: set[str] = set()
    for start in re.finditer(rf"(?m)^\s+(?:const\s+|factory\s+)*{re.escape(name)}(?:\.\w+)?\s*\(", body):
        depth, index = 0, start.end() - 1
        for index in range(start.end() - 1, len(body)):
            if body[index] == "(":
                depth += 1
            elif body[index] == ")":
                depth -= 1
                if depth == 0:
                    break
        params = body[start.end() : index]
        names |= set(re.findall(r"(?:this\.|super\.)?\b([a-z_]\w*)\s*(?=[,)}\]=:]|$)", params))
    return names


def constructor_parameters(name: str, types: dict[str, list[TypeInfo]]) -> set[str]:
    """Every constructor parameter any declaration of ``name`` takes."""
    return {p for info in types.get(name, []) for p in info.parameters}


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
        entries = types.get(current) or SDK_TYPES.get(current)
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
    faults: list[tuple[int, str, str, Path, str]] = field(default_factory=list)

    @property
    def clean(self) -> bool:
        return not self.faults

    def render(self) -> str:
        lines = [f"\n{self.document}"]
        for number, type_name, member, source, how in self.faults:
            lines.append(
                f"  line {number}: `{type_name}.{member}`{how} — {type_name} is "
                f"declared in {source} and has no member named {member}"
            )
        return "\n".join(lines)


def audit(path: Path, types: dict[str, list[TypeInfo]]) -> Report | None:
    """Read one document; return its report, or ``None`` if it makes no claims."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None

    report = Report(document=display(path))
    lines = text.splitlines()
    if any("<!-- record:" in line for line in lines[:10]):
        # A declared record of a past state (see the module docstring).
        return None
    if COMPLETION in path.parents:
        lines = blank_historical_part(lines)
    for number, line in enumerate(lines, start=1):
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
                    (number, type_name, member, display(entries[0].source), "")
                )
    audit_member_tables(lines, types, report)
    return report if report.claims else None


def blank_historical_part(lines: list[str]) -> list[str]:
    """``lines`` with a completion document's part 3 blanked, line numbers kept.

    Part 3 runs from ``## What changed`` / ``## What this adds`` to the next
    level-2 heading; its ``### What is still open`` subsection is kept.
    """
    out: list[str] = []
    in_part3 = in_open = False
    for line in lines:
        if line.startswith("## "):
            title = line[3:].strip().lower()
            in_part3 = title.startswith("what changed") or title.startswith("what this adds")
            in_open = False
        elif in_part3 and line.startswith("### "):
            in_open = line[4:].strip().lower().startswith("what is still open")
        out.append("" if in_part3 and not in_open and not line.startswith("#") else line)
    return out


def display(path: Path) -> Path:
    """``path`` relative to whichever root holds it."""
    for root in (*gate_scope.ROOTS, WORKSPACE_ROOT):
        try:
            return path.relative_to(root)
        except ValueError:
            continue
    return path


def heading_owner(text: str, types: dict[str, list[TypeInfo]]) -> list[str]:
    """The repo-declared types a heading or lead-in names (rule 6).

    An annotation -- ``@TomDbTable`` -- is not the subject of a sentence about
    a type, so it is not counted.
    """
    names = re.findall(r"(?<!@)`([A-Z]\w*)\b[^`]*`", text)
    names += re.findall(r"(?<![@\w])(Tom[A-Z]\w*)\b", text)
    seen: list[str] = []
    for name in names:
        if name in types and name not in seen:
            seen.append(name)
    return seen


def cell_member(cell: str, owner: str) -> str | None:
    """The member a member table's first cell names, or ``None`` (rule 7)."""
    match = re.search(r"`([^`]+)`", cell)
    if not match:
        return None
    code = match.group(1).strip()
    if re.match(r"^[A-Za-z_]\w*\s*:(\s|$)", code):
        # `cron:` / `event: true` is a named argument or a map key.
        return None
    if code.split()[:1] == ["operator"] or " operator " in f" {code} ":
        return None
    # The name is the last identifier before a parameter list, an initialiser
    # or a type annotation's colon: `bool isJson`, `static Future<void> run(x)`
    # and `int? statusCode` all end in it, while a leading type does not.
    signature = re.split(r"[(=:]", code, maxsplit=1)[0]
    signature = re.sub(r"<[^<>]*(?:<[^<>]*>[^<>]*)*>", " ", signature)
    words = [w for w in signature.replace("?", " ").split() if w not in CELL_KEYWORDS]
    if not words:
        return None
    head = re.fullmatch(r"([A-Za-z_]\w*)(?:\.([A-Za-z_]\w*))?", words[-1])
    if not head:
        return None
    first, second = head.group(1), head.group(2)
    if second is not None:
        # `Owner.named(...)` is a named constructor or a static of the owner;
        # `Other.x` belongs to another type and is REFERENCE's to judge.
        return second if first == owner else None
    if first[0].isupper():
        return None
    return first


def audit_member_tables(
    lines: list[str], types: dict[str, list[TypeInfo]], report: Report
) -> None:
    """Judge member tables against the type their heading names (rules 5-7)."""
    headings: list[tuple[int, list[str]]] = []  # (level, types it names)
    paragraph: list[str] = []  # the last complete prose block, for rule 6
    current: list[str] = []  # the prose block being read
    in_fence = False
    table_owner: list[str] | None = None
    in_table = False
    for number, line in enumerate(lines, start=1):
        stripped = line.strip()
        if stripped.startswith("```"):
            in_fence = not in_fence
            if in_fence:
                current = []
            continue
        if in_fence:
            # A code block directly above a table -- a constructor shown in
            # full, then its parameters tabulated -- is that table's lead-in.
            current.append(stripped)
            continue
        heading = HEADING.match(line)
        if heading:
            level = len(heading.group(1))
            while headings and headings[-1][0] >= level:
                headings.pop()
            headings.append((level, heading_owner(heading.group(2), types)))
            in_table = False
            paragraph, current = [], []
            continue
        if not stripped.startswith("|"):
            if in_table:
                paragraph = []
            if not stripped:
                # A blank line ends the block; the block it ended is still the
                # lead-in of a table that follows it.
                if current:
                    paragraph, current = current, []
            else:
                current.append(stripped)
            in_table = False
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if not in_table:
            # A table's first row is its header.
            in_table = True
            table_owner = None
            if cells and cells[0].strip("*").lower() in MEMBER_TABLE_HEADERS:
                candidates = heading_owner(" ".join(current or paragraph), types)
                for _, named in reversed(headings):
                    if named:
                        candidates += [n for n in named if n not in candidates]
                        break
                table_owner = candidates or None
            paragraph, current = [], []
            continue
        if table_owner is None or set(stripped) <= set("|-: "):
            continue
        judged = [(o, cell_member(cells[0], o)) for o in table_owner]
        names = {m for _, m in judged if m is not None}
        if not names:
            continue
        visible = [closure(o, types) for o in table_owner]
        if any(members is None for members in visible):
            # A candidate's inheritance leaves the repository, so it may declare
            # anything; abstain, per restriction 4.
            continue
        report.claims += 1
        if any(
            m in members
            or m in constructor_parameters(o, types)
            or m in TOP_LEVEL_NAMES[package_of(types[o][0].source)]
            for (o, m), members in zip(judged, visible)
            if m is not None
        ):
            continue
        owner, member = next((o, m) for o, m in judged if m is not None)
        report.faults.append(
            (
                number,
                owner,
                member,
                display(types[owner][0].source),
                " (member table"
                + (f"; also checked {', '.join(o for o in table_owner if o != owner)}" if len(table_owner) > 1 else "")
                + ")",
            )
        )


def documents(prefix: str) -> list[Path]:
    """The package documents, then the completion corpus (see "Two roots")."""
    found = [
        path
        for path in gate_scope.rglob_all("*.md")
        if path.name != "CHANGELOG.md"
        and not any(part.startswith(".") for part in path.parts)
        and str(gate_scope.rel(path)).startswith(prefix)
    ]
    if COMPLETION.is_dir() and (not prefix or prefix.startswith("completion")):
        found += COMPLETION.glob("*.md")
    return sorted(found)


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

    if not SDK_TYPES:
        print(
            "self-test: the Dart SDK was not found (put `dart` on PATH or set "
            "DART_SDK), so the case this gate exists for -- a rename on a type "
            "that extends DateTime -- cannot be checked",
            file=sys.stderr,
        )
        return 2

    # Member tables (rules 5-7), on fixtures run through the same audit, so
    # nothing on disk is touched. Both directions: a renamed member is caught,
    # and a foreign member -- or a table that is not a member table -- is not.
    def table_faults(*lines: str) -> int:
        report = Report(document=Path("self-test"))
        audit_member_tables(list(lines), types, report)
        return len(report.faults)

    table = ("| Method | Returns |", "| --- | --- |")
    cases = [
        # (description, lines, expected fault count)
        (
            "a member the type declares",
            ("### `TomTimezone`", "", *table, "| `fromName(String name)` | `TomTimezone?` |"),
            0,
        ),
        (
            "a renamed member -- the shape convertToTimezone survived in",
            ("### `TomTimezone`", "", *table, "| `fromNameOrNull(String name)` | `TomTimezone?` |"),
            1,
        ),
        (
            "the owner decided by a heading two levels up",
            ("### `TomTimezone`", "#### Static methods", "", *table, "| `fromNameOrNull(String name)` | `TomTimezone?` |"),
            1,
        ),
        (
            "an SDK member reached through the closure (TomZonedDate -> DateTime)",
            ("### `TomZonedDate`", "", *table, "| `toUtc()` | `DateTime` |"),
            0,
        ),
        (
            "the observed rename, on a type whose closure runs through the SDK",
            ("### `TomZonedDate`", "", *table, "| `convertToTimezone(TomTimezone t)` | `TomZonedDate` |"),
            1,
        ),
        (
            "a foreign member on a type whose closure leaves the repo and the SDK",
            ("### `TomNodeBase`", "", *table, "| `createElement()` | `StatelessElement` |"),
            0,
        ),
        (
            "a table that is not a member table",
            ("### `TomTimezone`", "", "| Key | Raised when |", "| --- | --- |", "| `fromNameOrNull` | never |"),
            0,
        ),
        (
            "a named argument, not a member",
            ("### `TomTimezone`", "", "| Field | Builds |", "| --- | --- |", "| `cron:` | a schedule |"),
            0,
        ),
    ]
    for description, lines, expected in cases:
        got = table_faults(*lines)
        if got != expected:
            print(
                f"self-test: member table, {description}: expected {expected} "
                f"fault(s), got {got}",
                file=sys.stderr,
            )
            return 1

    # Part 3 of a completion document is history by contract and is not read,
    # except "What is still open", which is a claim about now.
    blanked = blank_historical_part(
        [
            "## Current API", "`kept`",
            "## What changed", "`dropped`",
            "### What is still open", "`kept again`",
        ]
    )
    if blanked != [
        "## Current API", "`kept`",
        "## What changed", "",
        "### What is still open", "`kept again`",
    ]:
        print(f"self-test: part 3 blanking is wrong: {blanked}", file=sys.stderr)
        return 1

    print(
        "self-test: invented and misattributed members both fire; member "
        "tables catch a rename and leave foreign members, non-member tables "
        "and part 3 alone"
    )
    return 0


def main(argv: list[str]) -> int:
    arguments = argv[1:]
    testing = "--self-test" in arguments
    prefix = next((a for a in arguments if not a.startswith("-")), "")

    types = {}
    for root in reversed(gate_scope.ROOTS):
        types.update(index_types(root))
    # An empty index would let every attribution pass, reporting a clean tree by
    # looking at nothing -- the one way this audit fails silently.
    if not types:
        print(f"no type declarations found under {REPO_ROOT}", file=sys.stderr)
        return 2

    sdk = sdk_library_root()
    if sdk is not None:
        for library in SDK_LIBRARIES:
            if (sdk / library).is_dir():
                for name, entries in index_types(sdk / library).items():
                    SDK_TYPES.setdefault(name, []).extend(entries)

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
        f"SDK types (closures only)  : {len(SDK_TYPES)}"
        f"{'' if SDK_TYPES else '  -- SDK not found; closures through dart: types abstain'}\n"
        f"documents defective        : {len(defective)}\n"
        f"members the source denies  : {faults}"
    )
    return report_faults(faults)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
