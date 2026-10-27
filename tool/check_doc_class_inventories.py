#!/usr/bin/env python3
"""Hold a document's class inventory to the directory it inventories.

Run from anywhere::

    python3 tool/check_doc_class_inventories.py                # every document
    python3 tool/check_doc_class_inventories.py tom_flutter_ui # one subtree
    python3 tool/check_doc_class_inventories.py --self-test    # check the checker

Exits non-zero when an inventory and its source directory disagree, so it can
gate a build.

An *inventory* is a region of a document that undertakes to list a family of
classes completely. It is not the same thing as a document that mentions
classes: a reader consults an inventory to answer "what is there?", and takes
its silence as an answer. That is what makes it decay differently from ordinary
prose. Prose that has fallen behind is merely incomplete, and reads as such; an
inventory that has fallen behind is *confidently wrong in two directions at
once*, and reads as authoritative in both.

Both directions were live in ``tom_ui_widgets_forms.md`` before this gate
existed, in one 300-line appendix:

* 81 rows carried a ``**(TBD)** = class needs to be created`` marker against
  classes that had shipped -- ``TomFormStringInput``, ``TomFormBoolSwitch``,
  ``TomFormDatePicker`` among them;
* 42 of the names in the same appendix named nothing at all, because the
  catalogue was built under different names (``TomCupertinoFormDatePicker``,
  not ``TomFormCupertinoDatePicker``) or was never built;
* and the three concretes that shipped later -- ``TomFormFileDropzone``,
  ``TomFormFileThumbnail``, ``TomFormDateTextInput`` -- appeared nowhere.

The second and third are why clearing the markers would have been the wrong
repair. It converts "wrongly says this does not exist" into "wrongly says this
does", which is strictly worse: a reader can check the first claim by opening
the file and finding the class, and cannot check the second by any means short
of the exercise this gate performs.

**Why a marker rather than a heuristic.** Nothing in a table's shape says
whether it is an inventory or an illustration, and guessing wrong is expensive
in both directions -- a missed inventory is a gate that checks nothing, and a
table read as an inventory by mistake demands that a five-row example list
ninety classes. So the region declares itself::

    <!-- class-inventory: tom_flutter_ui/lib/src/forms/fields extends TomField -->
    ... tables ...
    <!-- /class-inventory -->

The declaration is also the only durable place to record *what the region is
for*. A section heading says "Form Class Hierarchy Inventory"; the marker says
which directory that sentence is about, which is the fact that makes the
sentence checkable.

Two faults are reported.

``MISSING``
    The directory declares a class the region never names. This is the decay
    that produced ``TomFormFileDropzone``: a class shipped, and the document
    that undertook to list its family did not gain a row. Only classes whose
    ``extends`` chain reaches the base named in the marker are demanded, so
    the private widget and ``State`` classes that make up most of a Flutter
    field file are not inventory entries and are not asked for.

``PHANTOM``
    The region names a class, in its family's vocabulary, that no ``lib/`` in
    the repository declares. This is the decay that produced ``TomFormEmailStringInput``: a
    planned name that the build reached by another route, left behind in the
    plan's own list. The index spans every package rather than the marked
    directory, because an inventory legitimately mentions its neighbours --
    ``TomList``, ``TomSelectableSource``, ``TomAuthState`` -- and a gate that
    called those phantoms would be unusable.

*In the family's vocabulary* is what lets a family reach past ``Tom*``. The
server's exception family includes ``MariadbMigrationException``, and an
inventory of it has to be able to say so. So a region's listed names are every
backticked capitalised identifier in it, and a name is held to the index when
its leading word is one the family itself uses -- ``Tom`` always, ``Mariadb``
in the server's exceptions. A name in any other vocabulary -- ``String``,
``List`` in the forms inventory -- is the SDK's, which this repository's index
cannot speak for, and is neither demanded nor called a phantom.

Markers are read from every markdown file under this repository and from the
completion corpus in the quest folder, which inventories the same families from
outside the tree.

There is deliberately no third fault for a name that exists elsewhere in the
repository but not under the marked directory. ``TomListForm`` belongs to the
list module and is named in the forms inventory for contrast; demanding that
every mentioned class live in the inventoried folder would forbid the sentence
that tells a reader where the boundary runs.

**Anti-vacuity.** A gate baselined at zero passes just as well when it has
stopped reading anything. ``main`` exits 2 when the declaration index is empty,
when the completion corpus cannot be found, when no marked region is found at
all, and when a marked region resolves to a directory that declares nothing --
each of which is the checker failing rather than the tree being clean.
``--self-test`` asks the opposite question directly: it perturbs every marked
inventory by one name in each direction, once per leading word its family uses,
and requires this checker to object each time.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

from check_unimplemented_claims import index_types
from gate_report import report_faults
import gate_scope

REPO_ROOT = Path(__file__).resolve().parent.parent

#: A class named in an inventory row. This is ``check_unimplemented_claims``'s
#: ``TOM_SYMBOL`` widened to accept a type-parameter list, because an inventory
#: writes a generic the way its declaration does -- ``TomFormEnumField<T>``,
#: ``TomFormObjectListField<T>``. Reading only the bare form would have demanded
#: six rows this document already carries, which is the gate crying wolf about
#: its own notation rather than about the tree. The parameter list may be
#: markdown-escaped (``\<T\>``), which is how a name is written outside a code
#: span in the same document.
NAMED = re.compile(r"`([A-Z]\w*)(?:\\?<[^`]*>)?`")

#: The completion corpus. It describes this tree from outside it, in the quest
#: folder, and its tables inventory families exactly as the package guides do --
#: so a marker placed there is held to the same directory. The path is the one
#: ``check_doc_inventories`` reads the corpus from.
CORPUS_ROOT = REPO_ROOT.parent.parent / "_ai" / "quests" / "tom_core" / "completion"

#: A class name's leading word -- ``Tom`` in ``TomStorageException``,
#: ``Mariadb`` in ``MariadbMigrationException``. See :func:`audit`.
LEADING_WORD = re.compile(r"^[A-Z][a-z0-9]*")

#: The opening marker. The directory is repository-relative; the base type is
#: the class an entry must descend from to be demanded of the region.
OPEN = re.compile(
    r"<!--\s*class-inventory:\s*(?P<dir>\S+)\s+extends\s+(?P<base>\w+)\s*-->"
)

#: The closing marker. A region that is never closed is a fault in itself --
#: see :class:`Report` -- because an unbounded region silently swallows the
#: rest of the document and starts demanding names of prose.
CLOSE = re.compile(r"<!--\s*/class-inventory\s*-->")

#: A fenced block's delimiter. Markers inside a fence are shown, not made: the
#: README documents this notation by printing it, and a reader of markdown
#: source cannot tell the two apart without tracking fences. Read literally, the
#: README's own five-line example opened a second region over the same
#: directory and demanded all ninety-seven classes of it -- the gate objecting
#: to its own documentation.
FENCE = re.compile(r"^\s*(?:```|~~~)")

#: ``class Foo extends Bar`` / ``... extends Bar<T> with Mixin``. Only the
#: superclass is read: a mixin cannot be the root of a field hierarchy, and
#: ``implements`` does not inherit the behaviour an inventory is grouping by.
#:
#: The header is matched across newlines, because a Dart formatter wraps a long
#: one and the wrap falls exactly where this pattern looks::
#:
#:     class TomCupertinoFormEnumSegmented<T extends Object>
#:         extends TomFormEnumField<T>
#:
#: A line-at-a-time match misses that class, and missing a class here is the
#: quiet failure: the gate under-demands and reports the inventory complete.
#:
#: The type-parameter list is consumed explicitly rather than swept up by the
#: gap, because a bounded parameter contains the word this pattern is looking
#: for: read loosely, ``<T extends Object>`` makes every Cupertino field in the
#: package a direct child of ``Object``. The gap that follows may not cross
#: ``{`` or ``;``, which is what stops a class with no superclass at all from
#: borrowing the next declaration's.
EXTENDS = re.compile(
    r"^[ \t]*(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+)*"
    r"class\s+(?P<name>\w+)\s*(?:<(?:[^<>]|<[^<>]*>)*>)?"
    r"[^{;]*?\bextends\s+(?P<super>\w+)",
    re.MULTILINE,
)


def superclasses(directory: Path) -> dict[str, str]:
    """Map every class declared under `directory` to the class it extends."""
    parents: dict[str, str] = {}
    for source in sorted(directory.rglob("*.dart")):
        try:
            text = source.read_text()
        except (OSError, UnicodeDecodeError):
            continue
        for match in EXTENDS.finditer(text):
            parents.setdefault(match.group("name"), match.group("super"))
    return parents


def descendants(parents: dict[str, str], base: str) -> set[str]:
    """The public classes in `parents` whose extends chain reaches `base`.

    The walk is bounded by the number of known classes rather than by a visited
    set alone, so a cycle in a malformed source tree terminates instead of
    hanging the gate.
    """
    found: set[str] = set()
    for name in parents:
        if name.startswith("_"):
            continue
        current, hops = name, 0
        while current in parents and hops <= len(parents):
            current = parents[current]
            hops += 1
            if current == base:
                found.add(name)
                break
    return found


@dataclass
class Region:
    """One marked inventory: where it is, what it claims to cover."""

    document: Path
    first_line: int
    directory: str
    base: str
    named: set[str] = field(default_factory=set)
    closed: bool = False


def regions(document: Path) -> list[Region]:
    """Read every marked inventory region out of one document.

    Fenced blocks are skipped entirely: inside one a marker is being *shown*
    rather than *made*, and the rows around it are an illustration nobody
    intends as a claim about a directory.
    """
    try:
        text = document.read_text()
    except (OSError, UnicodeDecodeError):
        return []
    if "class-inventory:" not in text:
        return []

    found: list[Region] = []
    open_region: Region | None = None
    fenced = False
    for number, line in enumerate(text.split("\n"), start=1):
        if FENCE.match(line):
            fenced = not fenced
            continue
        if fenced:
            continue
        start = OPEN.search(line)
        if start is not None:
            open_region = Region(
                document, number, start.group("dir"), start.group("base")
            )
            found.append(open_region)
            continue
        if open_region is None:
            continue
        if CLOSE.search(line):
            open_region.closed = True
            open_region = None
            continue
        open_region.named.update(NAMED.findall(line))
    return found


@dataclass
class Report:
    """One region's disagreements with the directory it inventories."""

    region: Region
    demanded: int = 0
    missing: list[str] = field(default_factory=list)
    phantom: list[str] = field(default_factory=list)

    @property
    def clean(self) -> bool:
        return not self.missing and not self.phantom and self.region.closed

    @property
    def faults(self) -> int:
        return len(self.missing) + len(self.phantom) + (0 if self.region.closed else 1)

    def render(self) -> str:
        region = self.region
        lines = [
            f"{shown(region.document)}:{region.first_line}"
            f"  ({region.directory}, extends {region.base})"
        ]
        if not region.closed:
            lines.append("    UNCLOSED  no <!-- /class-inventory --> follows")
        for name in sorted(self.missing):
            lines.append(f"    MISSING   `{name}` is declared there and not listed")
        for name in sorted(self.phantom):
            lines.append(f"    PHANTOM   `{name}` is listed and declared nowhere")
        return "\n".join(lines)


def audit(region: Region, declared: dict[str, Path]) -> Report:
    """Compare one region against its directory in both directions."""
    report = Report(region)
    directory = gate_scope.at(region.directory)
    if not directory.is_dir():
        report.phantom.append(region.directory)
        return report

    expected = descendants(superclasses(directory), region.base)
    if not expected:
        # Not a clean region: the marker resolves to a directory that declares
        # nothing of the named family, so the comparison below would pass by
        # comparing against an empty set.
        report.phantom.append(f"{region.directory}/*{region.base}")
        return report

    report.demanded = len(expected)
    report.missing = sorted(expected - region.named)
    vocabulary = family_words(expected)
    report.phantom = sorted(
        name
        for name in region.named
        if name not in declared
        and name not in expected
        and leading_word(name) in vocabulary
    )
    return report


def leading_word(name: str) -> str:
    """A class name's first word: ``Tom``, ``Mariadb``."""
    match = LEADING_WORD.match(name)
    return match.group(0) if match else name


def family_words(family: set[str]) -> set[str]:
    """The leading words a family's names are written in, ``Tom`` always."""
    return {"Tom"} | {leading_word(name) for name in family}


def shown(path: Path) -> str:
    """A document's reported path: repository-relative, or the corpus's own."""
    if any(path.is_relative_to(root) for root in gate_scope.ROOTS):
        return str(gate_scope.rel(path))
    return str(path.relative_to(REPO_ROOT.parent.parent))


def documents(prefix: str) -> list[Path]:
    """Every markdown file in scope, narrowed by a reported-path prefix.

    The repository is walked except for dot-folders; the corpus is one flat
    folder of documents.
    """
    inside = (
        path
        for root in gate_scope.ROOTS
        for path in root.rglob("*.md")
        if not any(part.startswith(".") for part in path.relative_to(root).parts)
    )
    return sorted(
        path
        for path in [*inside, *CORPUS_ROOT.glob("*.md")]
        if shown(path).startswith(prefix)
    )


def self_test(declared: dict[str, Path]) -> int:
    """Perturb every real region one name each way, in each of its vocabularies.

    Every region is perturbed rather than the first one found, because the
    vocabularies differ between regions: the forms inventory is all ``Tom*``,
    and only the server's exception family exercises a second leading word.
    """
    found = [r for path in documents("") for r in regions(path)]
    if not found:
        print("self-test: no inventory regions to perturb", file=sys.stderr)
        return 2

    checks = 0
    for region in found:
        where = f"{shown(region.document)}:{region.first_line}"
        if not audit(region, declared).clean:
            print(f"self-test: {where} is already defective", file=sys.stderr)
            return 2
        family = descendants(superclasses(gate_scope.at(region.directory)), region.base)
        for word in sorted(family_words(family)):
            members = sorted(
                n for n in family & region.named if leading_word(n) == word
            )
            if members:
                dropped = _variant(region, region.named - {members[0]})
                if members[0] not in audit(dropped, declared).missing:
                    print(
                        f"self-test: {where}: dropping `{members[0]}` "
                        "raised no MISSING",
                        file=sys.stderr,
                    )
                    return 2
                checks += 1
            invented = f"{word}NoSuchClassEver"
            planted = _variant(region, region.named | {invented})
            if invented not in audit(planted, declared).phantom:
                print(
                    f"self-test: {where}: listing `{invented}` raised no PHANTOM",
                    file=sys.stderr,
                )
                return 2
            checks += 1

    print(
        f"self-test: MISSING and PHANTOM both fire "
        f"({len(found)} regions, {checks} perturbations)"
    )
    return 0


def _variant(region: Region, named: set[str]) -> Region:
    """`region` listing `named` instead, and closed."""
    return Region(
        region.document,
        region.first_line,
        region.directory,
        region.base,
        named,
        closed=True,
    )


def main(argv: list[str]) -> int:
    arguments = argv[1:]
    testing = "--self-test" in arguments
    prefix = next((a for a in arguments if not a.startswith("-")), "")

    declared = {}
    for root in reversed(gate_scope.ROOTS):
        declared.update(index_types(root))
    # An empty index would call every listed name a phantom, and a full report
    # of nonsense is harder to notice than a refusal to run.
    if not declared:
        print(f"no declarations found under {REPO_ROOT}", file=sys.stderr)
        return 2

    # The corpus holds markers too; without it those regions vanish from the
    # count instead of failing, which reads as a clean run.
    if not CORPUS_ROOT.is_dir():
        print(f"completion documents not found at {CORPUS_ROOT}", file=sys.stderr)
        return 2

    if testing:
        return self_test(declared)

    found = [r for path in documents(prefix) for r in regions(path)]
    # Likewise: a checker that stops recognising the markers reports success.
    if not found:
        print(f"no class-inventory regions found under {REPO_ROOT}", file=sys.stderr)
        return 2

    reports = [audit(region, declared) for region in found]
    defective = [r for r in reports if not r.clean]
    for report in defective:
        print(report.render())

    faults = sum(r.faults for r in defective)
    print(
        f"\ninventory regions read : {len(reports)}\n"
        f"classes demanded       : {sum(r.demanded for r in reports)}\n"
        f"names listed           : {sum(len(r.region.named) for r in reports)}\n"
        f"regions defective      : {len(defective)}\n"
        f"names out of step      : {faults}"
    )
    return report_faults(faults)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
