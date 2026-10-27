#!/usr/bin/env python3
"""Audit the error vocabulary a tom_core document states against the code's.

Run from anywhere::

    python3 tool/check_doc_error_keys.py                 # audit every document
    python3 tool/check_doc_error_keys.py tom_core_server # one project's documents
    python3 tool/check_doc_error_keys.py --list          # print each census

Exits non-zero when a document disagrees with the code it describes.

A module's error keys are its public vocabulary of failure: the section is
written as a reference a client author branches on, so a key that is raised and
not listed is a branch nobody knows to write, and a key that is listed and not
raised is a branch that can never be taken. Both are silent -- neither the
compiler nor any test notices, because the section lives in another repository
from the code it describes, and nothing about editing a module brings it into
view. That is the same decay ``check_doc_inventories.py`` was written for, and
this table has proved as prone to it: a hand census of one section found six
glosses describing the wrong condition and, later, thirteen keys missing
outright -- including an entire family, every failure an external login can
report.

Three faults are reported:

``ABSENT``
    A key the module raises that the section does not name. The common defect:
    a key was added with a feature and the document was not revisited.
``UNKNOWN``
    A key the section names that the module does not raise -- a typo, or a key
    that was renamed or deleted while the row stayed. Worth catching for its own
    sake: the todo that prompted this checker asserted a
    ``login.error.oauth.unknown-issuer`` that has never existed, so even a
    careful hand census invents keys.

``UNTESTED``
    A key a package's code raises that no test in that package names. The
    first two faults keep the *documents* honest; this one keeps the *suites*
    honest. A key no test names is a failure mode nobody is checking: the code
    can raise it, the documents promise it, and no run would notice if it
    stopped. A test that only asserts ``throwsA(isA<TomException>())`` does not
    count, deliberately -- a key the test does not name is a key it does not
    pin. The fix is a test that names the key, or, when the raise cannot be
    reached at all, deleting it and its documented entries, which is what a
    phantom failure mode deserves.

    The census for this fault reads *code* only: comment lines are dropped
    before the raises are read, because a dartdoc example that throws
    ``TomException('payment.transfer.rejected', ...)`` documents the API rather
    than raising anything. It covers every package under this repository --
    the framework packages and each sample -- and reads ``lib/`` and ``bin/``,
    not ``example/``; an example is checked by running it, not by a suite.

**What counts as an error key.** The census does not trust the shape of a string
literal -- plenty of dotted lowercase literals are configuration keys, claim
names or table names. It works in two passes:

1. Every ``SomethingException(`` or ``SomethingError(`` whose *first* argument
   is a string literal contributes that literal, as does every ``errorKey:``
   named argument. Requiring the literal to be the immediately following token
   is what separates a raise from the exception's own constructor declaration,
   where ``super.key`` comes first instead.
2. Those keys establish the module's *families* (see ``family``). Any other
   dotted literal belonging to an established family is then counted too.

The second pass exists because not every key reaches a client through an
exception: ``login.error.unknown`` is handed straight to a
``TomAuthenticationResult``, ``login.error.2fa.invalid-code`` is assigned to its
``error`` field, and the whole ``file_endpoint`` vocabulary is returned by a
local ``_error`` helper that builds a response. Deriving the families from pass
1 rather than listing them here keeps the rule general -- a new module needs no
edit to this file -- while still excluding ``oauth.providers``, a configuration
key no exception establishes a family for.

``Error`` and ``errorKey:`` sit in pass 1 beside ``Exception`` because a form's
validation vocabulary is raised in neither of the other two hands: a validator
returns ``TomValidationError('error.taxIdTaken')`` or is declared with
``errorKey: 'error.invalidUrl'``, and the resulting key is exactly as public as
a thrown one -- more so, since an undeclared one does not throw but *renders as
itself*. Requiring the first argument to be a dotted literal is what keeps
``StateError('cannot ...')`` and its siblings out: a message is a sentence, and
a sentence is not key-shaped.

A key segment may be camelCase. The server vocabulary is snake_case throughout
and the pattern used to say so, which made every ``error.taxIdTaken`` in the
sample packages invisible -- not mis-read but *unseen*, which is the failure
mode that inflates a pass rate rather than a fault count.

The same two-pass definition is applied to the document, so that a backticked
``result.error`` in the section's prose is read as the field access it is rather
than as a key nothing raises.

**Two kinds of document are audited, and they are read differently.**

A *module* document carries an ``Error keys`` section: a reference table a
client author branches on. It is matched to its module the way
``check_doc_inventories.py`` does it, by the backticked source path in the
document's opening, and both faults are reported -- the section promises
completeness in both directions, so a key it names and nothing raises is as much
a defect as one raised and unnamed.

A *package* document -- the ``tom_core_samples`` set -- has no such section, and
should not be made to grow one: a sample's keys are named where the feature that
raises them is described, and the sections they sit in are about resource
bundles and HTTP error mapping rather than about a vocabulary. So a package
document is anchored on its opening package path (the same line
``check_doc_inventories.py`` reads for its inventory, so no document needs an
edit to be reachable), its keys are read as tokens *anywhere* in the document,
and only ``ABSENT`` is reported.

A *prose module document* -- the hand-written guides under
``tom_core_*/doc/`` -- is the third genre and takes the package shape rather
than the module one, for a reason about how it is written. A completion
document's ``Error keys`` section promises to be the whole vocabulary in one
place; a guide distributes its keys by topic on purpose, so
``authentication.md`` houses seventeen ``login.error.2fa.*`` keys in an
``### Outcomes`` table and the rest across two ``Failure keys`` tables. Pointing
[documented] at it would read the first table and report the other twenty-odd
keys as ``ABSENT``. So the whole document is read, with [named_in], and the
assertion weakens to *named somewhere*.

``ABSENT`` only, for the reason the next paragraph gives about the samples,
reached by a different route. A guide is prose, and prose about an API is full
of dotted tokens that are not keys: ``preferences.getOr`` and
``preferences.set`` are method references, and no shape tells them from a key of
the ``preferences`` family. Measured over the whole corpus, ``UNKNOWN`` produced
six findings on the guides and four were exactly that.

That asymmetry is deliberate rather than a shortcut. A sample document names
framework keys it does not raise, because teaching the framework is what it is
for: ``advanced_auth_server`` names ``login.error.2fa.invalid-code``, which
``tom_core_server`` throws, and ``core_flutter_acl_responsive`` names
``error.email``, which ``TomValidators`` does. Reported as ``UNKNOWN`` those are
false alarms, and a gate that cries wolf gets turned off. ``ABSENT`` -- a key
the sample can emit that its own document never names -- has no such ambiguity,
and it is the defect this extension was written for: four of seven validation
keys in the form showcase were undocumented, and the gate named for that class
could not see the document at all.
"""

from __future__ import annotations

import re
import sys
from collections.abc import Sequence
from pathlib import Path

from gate_report import report_faults
import gate_scope

REPO_ROOT = Path(__file__).resolve().parent.parent
DOCS_ROOT = REPO_ROOT.parent.parent / "_ai" / "quests" / "tom_core" / "completion"

# The module directory, as the documents name it -- the same convention
# `check_doc_inventories.py` reads, taken from the "On disk at ..." opening.
MODULE_PATH = re.compile(r"`(tom_core_\w+/lib/src/[\w/]+?)/?`")

#: A package document's "path on disk" line, in the grammar
#: `check_doc_inventories.py` already requires of it: the backticked package
#: directory opening a line, followed by the em dash that introduces its file
#: count. Anchored at the line start so a mid-sentence mention of a neighbour
#: package -- of which these documents have several -- cannot be taken for the
#: subject.
PACKAGE_PATH = re.compile(r"^`(tom_\w+/[\w/]+?)/?`\s+—", re.M)

#: Where each package keeps its modules and how its guides are named -- the same
#: map `check_module_dependencies.py` walks, and for the same reason: a guide is
#: matched to its module by position, because unlike a completion document it
#: does not open with the source path. Kept as a copy rather than imported so a
#: gate stays runnable on its own; the two are checked against each other by
#: `no module goes unaudited` below.
PROSE_PACKAGES = {
    "tom_core_kernel": ("lib/src/tombase", "doc/{m}/{m}.md"),
    "tom_core_server": ("lib/src/tomserver", "doc/{m}.md"),
    "tom_core_flutter": ("lib/src/tomclient", "doc/{m}.md"),
    "tom_core_agentic": ("lib/src", "doc/{m}.md"),
    "tom_flutter_ui": ("lib/src", "doc/{m}.md"),
}

#: The folders of a package whose sources carry its error vocabulary. `test/` is
#: not among them, and that is the point of listing them rather than walking the
#: package: a suite constructs exceptions with invented keys to drive the handler
#: under test -- `advanced_app_server` raises `app.share.invalid` in a test with
#: a message of `'bad'` -- and reading those as vocabulary would require every
#: document to name the fixtures of its own suite.
PACKAGE_SOURCE_FOLDERS = ("lib", "bin", "example")

SECTION_HEADING = re.compile(r"^(#{2,4})\s+Error keys\s*$", re.M)

# A dotted key: two or more segments, starting lowercase. Hyphens are allowed
# after the first character of a segment, and so is camelCase -- the server
# vocabulary is snake_case throughout, but a form's validation keys are not
# (`error.taxIdTaken`, `error.mustBeNonNegative`), and a pattern that spelled the
# server convention as a rule did not merely mis-read those, it could not see
# them. A segment may also be an interpolation --
# `authentication.2fa.$type.no_service` is one raise standing for every key it
# can produce, and a regex that stopped at the `$` would read it as the family
# `authentication.2fa` and then fail on the missing quote, losing the raise
# entirely.
SEGMENT = r"(?:\$\{?\w+\}?|[a-z0-9_-][A-Za-z0-9_-]*)"
KEY = rf"[a-z][a-z0-9_]*(?:\.{SEGMENT})+"
KEY_LITERAL = re.compile(rf"['\"]({KEY})['\"]")

# A raise: a constructor whose name ends in `Exception` or `Error` and whose
# first argument is a string literal, or an `errorKey:` named argument. `\s*`
# spans the line break the formatter puts after the `(`. Requiring the argument
# to be a dotted *key* is what keeps `StateError('cannot ...')` out -- a message
# is a sentence, and a sentence is not key-shaped.
RAISED_KEY = re.compile(
    rf"(?:\b[A-Za-z_][A-Za-z0-9_]*(?:Exception|Error)\(\s*|\berrorKey:\s*)"
    rf"['\"]({KEY})['\"]"
)

#: A key as a package document writes it: a bare token in prose, a table cell or
#: a fenced block. Unlike `DOC_KEY` below it is not read out of a backtick pair,
#: because a whole-document backtick walk cannot stay in phase -- these documents
#: are full of triple-backtick fences, and one unpaired run silently inverts
#: every pair after it. The boundaries keep the match maximal: nothing word-like
#: before it, and no letter or hyphen after, so a trailing sentence period ends
#: the key rather than defeating the match.
DOC_TOKEN = re.compile(rf"(?<![\w.$])({KEY})(?![\w-])")

# Keys as the documents write them: backticked, and in the shorthand rows that
# hang several suffixes off one prefix --
# `oauth.provider.http_error` / `malformed_json`.
DOC_KEY = re.compile(rf"({KEY})")
DOC_SUFFIX = re.compile(r"\.?([a-z][a-z0-9_-]*)")

# What may sit between a key and a suffix that continues it: punctuation, a
# line break, a table pipe, "and"/"or". Prose may not -- that is what keeps the
# `get` in "every backend's `get`" from being read as a suffix of the key in the
# cell before it.
CONTINUATION = re.compile(r"^[\s/,|]*(?:(?:and|or)[\s]*)?$")


def family(key: str) -> str:
    """The key's prefix: its first two segments, or its first when it has only
    two in all.

    `login.error.2fa.expired` -> `login.error`, and `file_endpoint.invalid_id`
    -> `file_endpoint`. Two segments is what separates the error vocabulary
    `oauth.flow` from the configuration key `oauth.providers`, which shares only
    its first segment with anything raised. But a two-segment key *is* its own
    first two segments, so the flat `file_endpoint.*` vocabulary would put every
    key in a family of one -- and a key that reaches its client without ever
    being thrown, as `file_endpoint.method_not_allowed` does through a local
    `_error` helper, would then establish nothing and be invisible to pass 2.
    Dropping to one segment there is what keeps a flat vocabulary whole.
    """
    parts = key.split(".")
    return ".".join(parts[:2]) if len(parts) > 2 else parts[0]


def is_pattern(key: str) -> bool:
    """Whether the literal interpolates, as `authentication.2fa.$type.no_service`."""
    return "$" in key


def matches(pattern: str, key: str) -> bool:
    """Whether `key` is one instantiation of an interpolated `pattern`."""
    expression = re.escape(pattern).replace(r"\$", "$")
    expression = re.sub(r"\$\{?\w+\}?", "[a-z0-9_-]+", expression)
    return re.fullmatch(expression, key) is not None


def sources_of(roots: Sequence[Path]) -> list[str]:
    """Every hand-written Dart source under `roots`.

    Generated code is skipped. A reflection seed is 300 000 lines of emitted
    symbol tables that no reader of a completion document is answerable for, and
    reading them costs more than the rest of the audit put together.
    """
    return [
        path.read_text(encoding="utf-8", errors="replace")
        for root in roots
        for path in sorted(root.rglob("*.dart"))
        if not path.name.endswith(".reflection.dart")
    ]


def raised_families(roots: Sequence[Path]) -> set[str]:
    """The families `roots` establish by throwing them."""
    return {
        family(m.group(1))
        for text in sources_of(roots)
        for m in RAISED_KEY.finditer(text)
    }


def families_of(
    module: Sequence[Path], project: Sequence[Path], listed: set[str]
) -> set[str]:
    """The families this document is answerable for.

    Every family the module itself raises, plus any family the document already
    names *and* the project raises somewhere. The second half is what lets the
    file_storage document own `file_endpoint.*`, a vocabulary raised entirely in
    `endpoints/`; requiring the project to raise it is what stops a document
    from conjuring a family into existence merely by listing it, which would
    make an invented key unreportable.
    """
    return raised_families(module) | (
        {family(key) for key in listed} & raised_families(project)
    )


def census(
    project: Sequence[Path], families: set[str]
) -> tuple[set[str], set[str]]:
    """The `(keys, patterns)` of `families` raised anywhere in the project.

    Widened past the module on purpose: a family is owned by the module that
    throws it, but individual keys of it are raised wherever the work happens --
    the file-endpoint vocabulary is raised in `endpoints/`, not in
    `file_storage/`, and the reference section still has to cover it.
    """
    keys: set[str] = set()
    patterns: set[str] = set()
    for text in sources_of(project):
        for match in KEY_LITERAL.finditer(text):
            key = match.group(1)
            if family(key) not in families:
                continue
            (patterns if is_pattern(key) else keys).add(key)
    return keys, patterns


def documented(text: str) -> set[str] | None:
    """Every key the document's "Error keys" section names, or None if it has no
    such section.

    The section is walked as one string rather than line by line, because the
    shorthand routinely straddles a line break: a prose list like
    ``.rejected``, ``.bad_token`` hangs its suffixes off the key that opened it
    however the paragraph happens to wrap.
    """
    heading = SECTION_HEADING.search(text)
    if heading is None:
        return None

    # The section runs to the next heading of the same level or shallower.
    depth = len(heading.group(1))
    after = text[heading.end() :]
    end = re.search(rf"^#{{1,{depth}}}\s+\S", after, re.M)
    section = after[: end.start()] if end else after

    keys: set[str] = set()
    prefix: str | None = None
    previous_end: int | None = None
    for span in re.finditer(r"`([^`]+)`", section):
        token = span.group(1)
        if DOC_KEY.fullmatch(token):
            keys.add(token)
            prefix = token
        elif (
            prefix is not None
            and DOC_SUFFIX.fullmatch(token)
            and previous_end is not None
            and CONTINUATION.match(section[previous_end : span.start()])
        ):
            keys.add(f"{prefix.rsplit('.', 1)[0]}.{token.lstrip('.')}")
        previous_end = span.end()
    return keys


def named_in(text: str) -> set[str]:
    """Every key-shaped token anywhere in a package document.

    A package document has no reference section to bound the read, so the whole
    text is scanned and the family filter does the separating -- which is what
    `family` is for. Tokens rather than backtick pairs: these documents are full
    of fenced blocks, and a walk that pairs backticks goes out of phase at the
    first triple-backtick fence and silently reads the *gaps* between keys from
    there on.
    """
    return {match.group(1) for match in DOC_TOKEN.finditer(text)}


class Report:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.keys: set[str] = set()
        self.faults: list[str] = []

    @property
    def clean(self) -> bool:
        return not self.faults

    def render(self) -> str:
        # A completion document is named relative to its own root and a guide
        # relative to the repository, so each reads as the path somebody would
        # open. `is_relative_to` rather than a try/except: the two roots are
        # disjoint and knowing which one a report came from is not an error
        # condition.
        rel = (
            self.path.relative_to(DOCS_ROOT)
            if self.path.is_relative_to(DOCS_ROOT)
            else gate_scope.rel(self.path)
        )
        return "\n".join([str(rel), *(f"    {f}" for f in self.faults)])


def audit(path: Path) -> Report | None:
    """Return a Report, or None if the document states no error vocabulary.

    A document is either a module document with an ``Error keys`` section or a
    package document anchored on its opening package path. The two are disjoint
    -- a module path reaches into `lib/src/`, a package path stops at the
    package -- so the order is a fallback rather than a precedence.
    """
    text = path.read_text(encoding="utf-8", errors="replace")
    return audit_section(path, text) or audit_package(path, text)


def audit_section(path: Path, text: str) -> Report | None:
    """Audit a module document's ``Error keys`` section against its module."""
    module_match = MODULE_PATH.search(text)
    if module_match is None:
        return None
    relative = module_match.group(1)
    module = gate_scope.at(relative)
    if not module.is_dir():
        return None
    # `tom_core_server/lib/src/tomserver/authentication` -> `tom_core_server/lib`.
    project = gate_scope.at("/".join(relative.split("/")[:2]))

    listed = documented(text)
    if listed is None:
        return None

    report = Report(path)
    families = families_of([module], [project], listed)
    keys, patterns = census([project], families)
    report.keys = keys

    # The same rule pass 2 applies to the source, applied to the document: a
    # dotted literal is an error key only if it belongs to an established
    # family. Without it the section's own prose is read as a vocabulary --
    # `result.error` is a field access, and no shape distinguishes it from a
    # key. The cost is that a wholly invented *family* goes unreported; a
    # mistyped key does not, because a typo keeps the family it was typed under.
    listed = {key for key in listed if family(key) in families}

    for key in sorted(keys - listed):
        report.faults.append(f"ABSENT   {key}")
    for key in sorted(listed - keys):
        # An interpolated raise stands for each key it can produce, so a
        # documented instantiation of one is raised, not unknown.
        if any(matches(pattern, key) for pattern in patterns):
            continue
        report.faults.append(f"UNKNOWN  {key}")
    return report


def audit_package(path: Path, text: str) -> Report | None:
    """Audit a package document against the keys its package can emit.

    ``ABSENT`` only -- see the module docstring for why ``UNKNOWN`` is unsound
    here. Returns None when the document names no package, when the path it
    names is not a package, or when the package raises nothing: a sample that
    has no error vocabulary owes its document no section about one.
    """
    package_match = PACKAGE_PATH.search(text)
    if package_match is None:
        return None
    package = gate_scope.at(package_match.group(1))
    if not (package / "pubspec.yaml").is_file():
        return None

    roots = [
        package / folder
        for folder in PACKAGE_SOURCE_FOLDERS
        if (package / folder).is_dir()
    ]
    families = raised_families(roots)
    if not families:
        return None

    report = Report(path)
    keys, _ = census(roots, families)
    report.keys = keys

    listed = {key for key in named_in(text) if family(key) in families}
    for key in sorted(keys - listed):
        report.faults.append(f"ABSENT   {key}")
    return report


def prose_documents() -> list[tuple[Path, Path, Path]]:
    """Every `(guide, module, project)` triple `PROSE_PACKAGES` reaches.

    A module with no guide is skipped rather than reported: whether every module
    owes one is `check_module_dependencies.py`'s question, asked there against
    the same map, and answering it twice would mean two gates going red for one
    missing file.
    """
    triples: list[tuple[Path, Path, Path]] = []
    for package, (source, pattern) in PROSE_PACKAGES.items():
        modules = gate_scope.package_dir(package) / source
        if not modules.is_dir():
            continue
        for module in sorted(d for d in modules.iterdir() if d.is_dir()):
            guide = gate_scope.package_dir(package) / pattern.format(m=module.name)
            if guide.is_file():
                triples.append((guide, module, gate_scope.package_dir(package) / "lib"))
    return triples


def audit_prose(guide: Path, module: Path, project: Path) -> Report | None:
    """Audit a hand-written module guide against the keys its module raises.

    ``ABSENT`` only -- see the module docstring for why ``UNKNOWN`` is unsound
    over a whole document. Returns None when the module raises nothing: a module
    with no error vocabulary owes its guide no mention of one.
    """
    families = raised_families([module])
    if not families:
        return None
    keys, _ = census([project], families)
    if not keys:
        return None

    report = Report(guide)
    report.keys = keys
    text = guide.read_text(encoding="utf-8", errors="replace")
    named = {key for key in named_in(text) if family(key) in families}
    for key in sorted(keys - named):
        report.faults.append(f"ABSENT   {key}")
    return report


#: The folders whose raises a package's suite is answerable for. `example/` is
#: not among them: an example asserts its own results when it runs.
TESTED_SOURCE_FOLDERS = ("lib", "bin")


def code_of(text: str) -> str:
    """`text` with every comment line blanked, so a dartdoc example raises nothing.

    Line numbers are kept, so a fault still points at the raise.
    """
    return "\n".join(
        "" if line.lstrip().startswith("//") else line for line in text.split("\n")
    )


def packages() -> list[Path]:
    """Every package in the repository: the framework packages and each sample."""
    found = [p.parent for p in gate_scope.glob_all("*/pubspec.yaml")]
    found += [p.parent for p in gate_scope.glob_all("tom_core_samples/*/pubspec.yaml")]
    return sorted(found, key=gate_scope.rel)


def raises_in(package: Path) -> dict[str, str]:
    """Every key `package`'s code raises, mapped to its first raise site."""
    sites: dict[str, str] = {}
    for folder in TESTED_SOURCE_FOLDERS:
        root = package / folder
        if not root.is_dir():
            continue
        for path in sorted(root.rglob("*.dart")):
            if path.name.endswith(".reflection.dart"):
                continue
            text = code_of(path.read_text(encoding="utf-8", errors="replace"))
            for match in RAISED_KEY.finditer(text):
                line = text.count("\n", 0, match.start()) + 1
                sites.setdefault(
                    match.group(1), f"{path.relative_to(package)}:{line}"
                )
    return sites


def named_by_tests(package: Path) -> set[str]:
    """Every key-shaped token some test of `package` names."""
    tests = package / "test"
    if not tests.is_dir():
        return set()
    return {
        key
        for path in tests.rglob("*_test.dart")
        for key in named_in(path.read_text(encoding="utf-8", errors="replace"))
    }


def audit_tests(package: Path) -> Report | None:
    """Report every key `package` raises that none of its tests names.

    An interpolated raise is covered by a test naming any key it can produce.
    Returns None when the package raises nothing.
    """
    sites = raises_in(package)
    if not sites:
        return None
    named = named_by_tests(package)
    report = Report(package)
    report.keys = set(sites)
    for key in sorted(sites):
        covered = (
            any(matches(key, name) for name in named)
            if is_pattern(key)
            else key in named
        )
        if not covered:
            report.faults.append(f"UNTESTED {key}  ({sites[key]})")
    return report


def main(argv: list[str]) -> int:
    arguments = argv[1:]
    show = "--list" in arguments
    arguments = [a for a in arguments if a != "--list"]

    if not DOCS_ROOT.is_dir():
        print(f"completion documents not found at {DOCS_ROOT}", file=sys.stderr)
        return 2

    prefix = arguments[0] if arguments else ""
    documents = sorted(p for p in DOCS_ROOT.glob("*.md") if p.name.startswith(prefix))
    reports = [r for r in (audit(p) for p in documents) if r is not None]
    completion = len(reports)

    guides: list[Report] = []
    for guide, module, project in prose_documents():
        # Selected by *package*, because that is what the same prefix selects on
        # the completion side: those documents are named `tom_core_server_*.md`
        # and a guide is `authentication.md`, so matching the filename would
        # make one argument mean two different things.
        if not gate_scope.rel(guide).parts[0].startswith(prefix):
            continue
        report = audit_prose(guide, module, project)
        if report is not None:
            guides.append(report)
    reports += guides

    suites: list[Report] = []
    for package in packages():
        if not str(gate_scope.rel(package)).startswith(prefix):
            continue
        report = audit_tests(package)
        if report is not None:
            suites.append(report)
    reports += suites

    # A checker that quietly stops finding sections reports a clean tree, which
    # is the one way this kind of audit fails without anyone noticing. Both
    # genres are required, and separately: the completion documents are found by
    # a glob and the guides by a path map, so one can stop resolving while the
    # other still does and a single combined count would hide it.
    #
    # Only an unscoped run can demand all three: a prefix such as
    # `tom_core_samples` selects package suites and legitimately no completion
    # document or guide, and refusing there would hide the one census it asked
    # for.
    if not prefix:
        if not completion:
            print(f'no "Error keys" sections found under {DOCS_ROOT}', file=sys.stderr)
            return 2
        if not guides:
            print("no module guides with an error vocabulary found", file=sys.stderr)
            return 2
        if not suites:
            print("no package raises an error key", file=sys.stderr)
            return 2
    elif not reports:
        print(f"nothing under {prefix!r} states or raises an error key",
              file=sys.stderr)
        return 2

    if show:
        for report in reports:
            print(report.path.name)
            for key in sorted(report.keys):
                print(f"    {key}")

    defective = [r for r in reports if not r.clean]
    for report in defective:
        print(report.render())

    total = sum(len(r.faults) for r in defective)
    print(
        f"\n{completion} error-key sections, {len(guides)} module guides and "
        f"{len(suites)} package suites audited, {len(defective)} defective, "
        f"{total} faults"
    )
    return report_faults(total)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
