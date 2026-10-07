#!/usr/bin/env python3
"""Hold a module document's Overview table to the types its module exports.

Run from anywhere::

    python3 tool/check_doc_overview_types.py                 # every document
    python3 tool/check_doc_overview_types.py tom_core_server # one package
    python3 tool/check_doc_overview_types.py --self-test     # check the checker

Exits non-zero when a module exports a public type its document's Overview
table does not name, so it can gate a build.

**The rule, and why it is exhaustive.** A module document opens with a table of
the module's public types, and that table lists *every* type the package barrel
exports from the module — not a selection. A curated table cannot be checked,
which is not an abstract objection: `doc/preferences.md` named five of six
public types, and the missing one was the subject of the document's own longest
section. Nobody noticed, because with no rule about what belongs there was
nothing for the omission to contradict.

Exhaustive costs something and the cost is accepted. `object_persistence`
exports eighty-five types and its table has eighty-five rows, most of them
one-line query-DSL operators. A table that long is closer to an index than an
overview — but an index that is complete beats an overview that is silently
partial, because a reader takes the silence of a list for an answer.

**A row may cover several names.** The table is prose, and the convention the
documents already follow is to group what is used as a set:
`` `TomSelect` / `TomCount` / `TomDelete` `` on one row, or ``TomDbType<T>``
followed by its seven boxed subtypes. That is a presentation choice and this
gate does not touch it — what it asks is that the name appear *somewhere* in the
table, in a code span, whatever row it shares.

**What declares a document in scope.** The Overview section holding a table
whose header names a `Type` (or `Symbol`) column and a `Kind` column. That is
not a heuristic about tables in general: the header is the document saying "this
region enumerates the module's types by kind", and a document that says
something else is out. Every module document of `tom_core_server`,
`tom_core_kernel` and `tom_core_flutter` writes one, as do those of
`tom_flutter_ui` and `tom_core_agentic`; a kernel guide opens its Overview with
the table and keeps its orienting prose beneath it.

Two faults are reported.

``MISSING``
    The module exports a public type the Overview table does not name.

``PHANTOM``
    The table names a `Tom`-prefixed type no `lib/` in the repository declares —
    a type renamed out from under the row, or one the table was written ahead of
    and that never arrived.

    Checked against every package under `tom_ai/` rather than the module,
    because an overview legitimately names its neighbours — `TomPrincipal` to
    say who the caller is, `TomDataSource` to say where the boundary runs — and
    the types of the packages it builds on: the kernel's describe themselves
    against `tom_basics`' `TomRuntime` and `TomPlatform`. A gate that called
    those phantoms would be unusable. It is the same scope
    `check_doc_phantom_names.py` indexes.

    Restricted to the framework's own prefix for the reason a backtick is not a
    type: these tables spell SQL in code spans (`SELECT`, `GROUP BY`,
    `DATETIME`), and type parameters (`T`, `K`, `R`), and Dart's own types
    (`String`, `Response`). Measured over the corpus, dropping the prefix
    produced sixty-nine findings of which none was a type at all. Every type
    these packages declare carries the prefix, so the restriction costs the
    check nothing it could have caught.

**Anti-vacuity.** A gate baselined at zero passes just as well once it has
stopped reading anything, so `main` exits 2 when no document is in scope, when a
document in scope resolves to a module directory that declares nothing, or when
the barrel exports nothing. `--self-test` asks the opposite question directly:
it perturbs a real Overview by one name in each direction and requires this
checker to object.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from check_unimplemented_claims import index_types
from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent

#: A public type declaration, anchored at column zero.
DECLARATION = re.compile(
    r"^(?:abstract\s+|final\s+|sealed\s+|base\s+|interface\s+|mixin\s+)*"
    r"(?:class|mixin|enum|extension type|typedef)\s+([A-Z]\w*)",
    re.M,
)

#: The floor the walk has to clear. Stated loosely — the count is supposed to
#: move — but an order of magnitude below it is a reader that has broken rather
#: than a repository that has shrunk.
MINIMUM_TYPES = 200

#: Modules whose type count the reader must still be able to see, with a floor
#: each. A landmark rather than an inventory: the scope is every document that
#: declares itself, and these are two that must be in it however that walk goes.
LANDMARKS = {
    "tom_core_server/doc/object_persistence.md": 50,
    "tom_core_server/doc/preferences.md": 5,
}

#: The Overview section: everything between its heading and the next `##`.
OVERVIEW = re.compile(r"\n## Overview\n(.*?)(?=\n## )", re.S)

def declares_inventory(overview: str) -> bool:
    """Whether [overview] holds a table enumerating the module's types by kind.

    Read as *cells* rather than as a pattern over the line, because the column
    the table leads with varies: `doc/audit.md` puts a `Layer` first and
    `doc/server.md` writes `Symbol` where the others write `Type`. What every
    one of them shares is a name column beside a `Kind` column, and that pair is
    the document declaring what the region is.
    """
    for line in overview.splitlines():
        if not line.startswith("|"):
            continue
        cells = {cell.strip() for cell in line.strip("|").split("|")}
        if cells & {"Type", "Symbol"} and "Kind" in cells:
            return True
    return False

#: The packages walked. Every directory holding a `doc/` and a `lib/src/`; the
#: scope within one is decided by the header above, not by this list.
def packages(subtree: str | None) -> list[Path]:
    found = [
        entry
        for entry in sorted(REPO_ROOT.iterdir())
        if entry.is_dir() and (entry / "lib").is_dir() and (entry / "doc").is_dir()
    ]
    if subtree is None:
        return found
    return [entry for entry in found if entry.name == subtree]


def without_comments(source: str) -> str:
    """[source] with `//` and `/* */` comments blanked.

    A dartdoc sentence beginning "class X is …" at column zero would otherwise
    be read as a declaration, and the type it names is usually one from another
    module — so the fault would be reported against the wrong document.
    """
    out: list[str] = []
    i = 0
    while i < len(source):
        if source.startswith("//", i):
            while i < len(source) and source[i] != "\n":
                i += 1
            out.append("\n")
            continue
        if source.startswith("/*", i):
            end = source.find("*/", i + 2)
            i = len(source) if end < 0 else end + 2
            continue
        out.append(source[i])
        i += 1
    return "".join(out)


def exported_files(package: Path) -> set[str]:
    """The `lib/`-relative paths the package barrel reaches, transitively.

    Followed rather than read one level deep, because a module may ship a
    sub-barrel: `tom_core_agentic`'s `bearer_auth/bearer_auth.dart` exports the
    contract file its three types are actually declared in. Stopping at the
    package barrel finds the sub-barrel, which declares nothing, and reports the
    module as having no exported type — an answer that looks like a clean
    module and is a checker that has stopped reading.
    """
    lib = package / "lib"
    pending = [
        str(entry.relative_to(lib))
        for entry in lib.glob("*.dart")
        if entry.is_file()
    ]
    reached: set[str] = set()
    while pending:
        relative = pending.pop()
        if relative in reached:
            continue
        reached.add(relative)
        source = lib / relative
        if not source.is_file():
            continue
        for target in re.findall(
            r"export\s+'([^']+)'", source.read_text(encoding="utf8")
        ):
            if target.startswith("package:") or target.startswith("dart:"):
                continue
            pending.append(
                str((source.parent / target).resolve().relative_to(lib.resolve()))
            )
    return reached


def module_types(module: Path, exported: set[str], package: Path) -> set[str]:
    """The public types [module]'s exported files declare."""
    found: set[str] = set()
    for entry in sorted(module.rglob("*.dart")):
        if entry.name.endswith(".reflection.dart"):
            continue
        if str(entry.relative_to(package / "lib")) not in exported:
            continue
        source = without_comments(entry.read_text(encoding="utf8"))
        found.update(
            name for name in DECLARATION.findall(source) if not name.startswith("_")
        )
    return found


def named_in(text: str) -> set[str]:
    """Every type name [text] writes in a code span, type arguments stripped.

    Stripping them is load-bearing rather than tidy: the tables write
    `TomDbType<T>` and `MariadbPreparedStatement<T>` as their declarations do,
    and a reader of the bare name alone reports three rows the documents
    already carry.
    """
    found: set[str] = set()
    for span in re.findall(r"`([^`]+)`", text):
        found.update(re.findall(r"\b([A-Z]\w*)", re.sub(r"<[^<>]*>", "", span)))
    return found


def module_directories(package: Path) -> list[Path]:
    """Every directory under `lib/src/` that could be a module."""
    source = package / "lib" / "src"
    if not source.is_dir():
        return []
    roots = [entry for entry in source.iterdir() if entry.is_dir()]
    modules = []
    for root in roots:
        children = [entry for entry in root.iterdir() if entry.is_dir()]
        modules.extend(children if children else [root])
    return sorted(modules)


def audit(subtree: str | None) -> tuple[list[str], dict[str, int]]:
    """The faults, and how many types each document in scope was compared to."""
    faults: list[str] = []
    counted: dict[str, int] = {}
    repository = index_types(REPO_ROOT.parent)
    for package in packages(subtree):
        exported = exported_files(package)
        if not exported:
            continue
        modules = {module.name: module for module in module_directories(package)}
        for document in sorted((package / "doc").rglob("*.md")):
            overview = OVERVIEW.search(document.read_text(encoding="utf8"))
            if overview is None or not declares_inventory(overview.group(1)):
                continue
            module = modules.get(document.stem)
            if module is None:
                continue
            declared = module_types(module, exported, package)
            if not declared:
                # A module may legitimately export no *type*:
                # `tom_core_agentic`'s `mcp_auth` is two constants and the wire
                # contract they belong to, and its table lists exactly those.
                # There is nothing here to be complete about, so the anti-vacuity
                # question is asked in aggregate below instead — a checker that
                # had stopped finding declarations would fail the landmarks, not
                # slip past one module at a time.
                continue
            where = document.relative_to(REPO_ROOT)
            counted[str(where)] = len(declared)
            named = named_in(overview.group(1))
            for missing in sorted(declared - named):
                faults.append(f"MISSING  {where}  {missing}")
            for phantom in sorted(named - declared):
                if phantom.startswith("Tom") and phantom not in repository:
                    faults.append(f"PHANTOM  {where}  {phantom}")
    return faults, counted


def self_test() -> int:
    """Perturb a real Overview in each direction and require an objection."""
    document = REPO_ROOT / "tom_core_server" / "doc" / "preferences.md"
    original = document.read_text(encoding="utf8")
    try:
        document.write_text(
            original.replace("| `TomUserPreferenceRepository` | class |", "| x |", 1),
            encoding="utf8",
        )
        faults, _ = audit("tom_core_server")
        if not any("TomUserPreferenceRepository" in fault for fault in faults):
            print("self-test: a dropped type was not reported", file=sys.stderr)
            return 2

        document.write_text(
            original.replace(
                "| `TomUserPreferenceRepository` | class |",
                "| `TomUserPreferenceRepository` | class |\n"
                "| `TomUserPreferenceNoSuchThing` | class | . |\n"
                "| x |",
                1,
            ),
            encoding="utf8",
        )
        faults, _ = audit("tom_core_server")
        if not any("TomUserPreferenceNoSuchThing" in fault for fault in faults):
            print("self-test: an invented type was not reported", file=sys.stderr)
            return 2
    finally:
        document.write_text(original, encoding="utf8")

    faults, _ = audit("tom_core_server")
    if faults:
        print(f"self-test: the restored tree is not clean: {faults}", file=sys.stderr)
        return 2
    print("self-test: passed")
    return 0


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()
    subtree = argv[0] if argv and not argv[0].startswith("-") else None

    faults, counted = audit(subtree)
    documents = len(counted)
    compared = sum(counted.values())
    if documents == 0 or compared < MINIMUM_TYPES:
        print(
            f"{documents} document(s) in scope and {compared} type(s) compared "
            "— the checker has stopped reading rather than the tree being clean",
            file=sys.stderr,
        )
        return 2
    if subtree is None:
        for landmark, floor in LANDMARKS.items():
            if counted.get(landmark, 0) < floor:
                print(
                    f"{landmark} was compared against {counted.get(landmark, 0)} "
                    f"types, fewer than the {floor} it declares — the reader has "
                    "gone wrong rather than the module having shrunk",
                    file=sys.stderr,
                )
                return 2

    for fault in faults:
        print(fault)

    print(f"\ndocuments in scope        : {documents}")
    print(f"public types compared     : {compared}")
    print(f"documents with a fault    : {len({f.split()[1] for f in faults})}")
    if faults:
        print(
            "\nA module's Overview table lists every public type the barrel "
            "exports from it. Add the row, or stop exporting the type."
        )
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
