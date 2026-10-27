#!/usr/bin/env python3
"""Hold every module document's Dependencies table to the module's imports.

Run from anywhere::

    python3 tool/check_module_dependencies.py              # every module
    python3 tool/check_module_dependencies.py tom_core_kernel
    python3 tool/check_module_dependencies.py --self-test   # perturb and require detection

**Why this table and not another.** A dependency table is the one part of a
prose document that is wholly derivable from the source, and it is also the
part that goes stale most quietly. An import added to a file changes nothing a
reader can see: the table keeps listing what the module used to need, and the
omission looks exactly like a dependency that was never there. That is not
hypothetical -- the timezoned table reached ``little_things`` through two files
and named one, and no reader could have told.

**Why it is checked in both directions.** A dependency with no row is an
omission and a row with no dependency is a leftover, and they are wrong in the
same way: the reader is told the module needs a set of things that is not the
set it needs. The ``Imported by`` column is checked per dependency for the same
reason -- a table can name the right four dependencies and still attribute them
to the wrong files, which sends a reader auditing one half of a module to the
other half.

**What the fourth column can and cannot be held to.** ``For`` is prose, and
prose is not decidable: this gate requires it to be non-empty and stops there.
Requiring more -- that every backticked name in it appear in the importing
files -- was tried and rejected. These cells earn their value by naming what a
dependency is *for*, which routinely means naming a type the dependency does
not declare (``TomException`` is what ``exception_base.dart`` gives the module,
``the transport underneath TomServerChannel`` names this module's own class).
A rule that faulted those would fault the sentences worth writing, which is the
bar ``check_consumer_claims.py`` sets for a rule worth keeping.

**One shape, so the table is worth parsing.** Before this gate the 57 module
documents used four different table layouts and 51 stated their dependencies in
prose, which is why only one of them was ever checked: a checker tolerant of
five formats can only verify what each format happens to state, and the
``| Dependency | Used for |`` shape names no importing file at all. Normalising
first is what makes a single rule possible, and a reader who has read one
Dependencies section has now read them all.

**Kinds.** ``dart`` for a ``dart:`` library, ``package`` for a ``package:``
import, ``module`` for a sibling module of the same package. The package is not
repeated in a module row because the document is already inside it.

**The importer cell** lists the files, module-relative, in backticks. Two
resolvable summaries are allowed where a list would be unreadable: ``every
file`` when every file in the module imports it, and ``N of M files`` when more
than [MAX_LISTED] do -- both numbers are checked, so the summary is exact even
though it does not name which.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from gate_report import report_faults
import gate_scope

REPO_ROOT = Path(__file__).resolve().parent.parent

#: Where each package keeps its modules, and how it names a module's document.
#: A package is in this map exactly when its modules carry prose documents.
PACKAGES = {
    "tom_core_kernel": ("lib/src/tombase", "doc/{m}/{m}.md"),
    "tom_core_server": ("lib/src/tomserver", "doc/{m}.md"),
    "tom_core_flutter": ("lib/src/tomclient", "doc/{m}.md"),
    "tom_core_agentic": ("lib/src", "doc/{m}.md"),
    "tom_flutter_ui": ("lib/src", "doc/{m}.md"),
}

HEADING = "## Dependencies"
HEADER = "| Dependency | Kind | Imported by | For |"

#: Beyond this many importing files the cell may state a count instead.
MAX_LISTED = 6

KIND_ORDER = {"dart": 0, "package": 1, "module": 2}

GENERATED = (".reflection.dart", ".versioner.dart", ".g.dart")

IMPORT = re.compile(r"^\s*(?:import|export)\s+'([^']+)'", re.M)
ANY_HEADING = re.compile(r"^#{1,6}\s")
SEPARATOR = re.compile(r"^-+$")
BACKTICKED = re.compile(r"`([\w./:]+)`")
LINK_TARGET = re.compile(r"\]\(([^)]+)\)")
COUNTED = re.compile(r"^(\d+) of (\d+) files$")


# -----------------------------------------------------------------------------
# The anchor: what a module imports
# -----------------------------------------------------------------------------


def module_dirs(package: str) -> list[Path]:
    root = gate_scope.package_dir(package) / PACKAGES[package][0]
    return sorted(d for d in root.iterdir() if d.is_dir()) if root.is_dir() else []


def module_files(mdir: Path) -> list[str]:
    return sorted(
        p.relative_to(mdir).as_posix()
        for p in mdir.rglob("*.dart")
        if not p.name.endswith(GENERATED)
    )


def dependencies(package: str, mdir: Path) -> dict[str, tuple[str, set[str]]]:
    """``key -> (kind, importing files)``, keyed as a table row names it."""
    src = (gate_scope.package_dir(package) / PACKAGES[package][0]).resolve()
    found: dict[str, tuple[str, set[str]]] = {}

    for path in sorted(mdir.rglob("*.dart")):
        if path.name.endswith(GENERATED):
            continue
        rel = path.relative_to(mdir).as_posix()
        for uri in IMPORT.findall(path.read_text()):
            if uri.startswith("dart:"):
                key, kind = uri, "dart"
            elif uri.startswith("package:"):
                key, kind = uri[len("package:"):].split("/")[0], "package"
            else:
                # Resolved rather than pattern-matched: a nested module reaches
                # a sibling through `../../`, and the same prefix can still be
                # inside the module it started in.
                target = (path.parent / uri).resolve()
                try:
                    inside = target.relative_to(src)
                except ValueError:
                    continue
                if inside.parts[0] == mdir.name:
                    continue
                key, kind = inside.parts[0], "module"
            found.setdefault(key, (kind, set()))[1].add(rel)

    return found


# -----------------------------------------------------------------------------
# The scan: what the table states
# -----------------------------------------------------------------------------


def section(doc: Path) -> list[str] | None:
    """The lead-in under [HEADING], up to the next heading of any level.

    A ``###`` subsection is its own passage: the table does not own its
    paragraphs, and a scan that swallowed them would judge their prose.
    """
    lines = doc.read_text().splitlines()
    try:
        start = lines.index(HEADING)
    except ValueError:
        return None
    end = start + 1
    while end < len(lines) and not ANY_HEADING.match(lines[end]):
        end += 1
    return lines[start + 1:end]


def cells(row: str) -> list[str]:
    parts = [c.strip() for c in row.split("|")]
    return parts[1:-1]


def row_key(cell: str) -> str | None:
    """The dependency a first cell names.

    A module is named by a link to its document and the key comes from the
    *target*, not the text: the text is prose and only the path can be compared
    to an import. A package or a ``dart:`` library is a bare code span.
    """
    link = LINK_TARGET.search(cell)
    if link:
        return Path(link.group(1)).stem
    code = BACKTICKED.search(cell)
    return code.group(1) if code else None


def stated_importers(cell: str, files: list[str]) -> set[str] | None:
    """The files a row credits, or ``None`` when the cell names none."""
    if cell == "every file":
        return set(files)
    counted = COUNTED.match(cell)
    if counted:
        listed, total = int(counted.group(1)), int(counted.group(2))
        if total != len(files):
            return None
        return {f"{listed} files"}  # compared by count, below
    named = {m.group(1) for m in BACKTICKED.finditer(cell)}
    return named or None


# -----------------------------------------------------------------------------
# The audit
# -----------------------------------------------------------------------------


def audit_module(package: str, mdir: Path, doc: Path) -> list[str]:
    faults: list[str] = []
    name = f"{package}/{mdir.name}"

    if not doc.exists():
        return [f"NODOC    {name} — no document, so no Dependencies section"]

    body = section(doc)
    if body is None:
        return [f"NOSECTION {gate_scope.rel(doc)} — no `{HEADING}` section"]

    table = [ln for ln in body if ln.startswith("|")]
    rel = gate_scope.rel(doc)
    deps = dependencies(package, mdir)
    files = module_files(mdir)

    if not deps:
        # A module that imports nothing has no table to write. It still has to
        # say so: an empty section reads as one nobody finished.
        if table:
            return [f"SHAPE    {rel} — a table, but the module imports nothing"]
        if not any(ln.strip() for ln in body):
            return [f"SHAPE    {rel} — the module imports nothing and the section says nothing"]
        return []

    if not table or table[0] != HEADER:
        return [f"SHAPE    {rel} — the section does not open with `{HEADER}`"]

    rows: dict[str, list[str]] = {}
    order: list[tuple[int, str]] = []
    for line in table[1:]:
        c = cells(line)
        if c and SEPARATOR.match(c[0]):
            continue
        if len(c) != 4:
            # Silently skipping a malformed row would let a wrong one hide
            # behind a missing pipe.
            faults.append(
                f"CELLS    {rel} — a row with {len(c)} cells where the table has "
                f"four: {line[:60]}"
            )
            continue
        key = row_key(c[0])
        if key is None:
            faults.append(f"UNNAMED  {rel} — a row whose first cell names no dependency: {line[:60]}")
            continue
        rows[key] = c
        order.append((KIND_ORDER.get(c[1], 9), key))

    for key in sorted(set(deps) - set(rows)):
        faults.append(f"MISSING  {rel} — imports `{key}` and the table has no row for it")
    for key in sorted(set(rows) - set(deps)):
        faults.append(f"EXTRA    {rel} — a row for `{key}`, which no file in the module imports")

    for key, c in sorted(rows.items()):
        if key not in deps:
            continue
        kind, importers = deps[key]
        if c[1] != kind:
            faults.append(f"KIND     {rel} — `{key}` is a {kind}, the row says `{c[1]}`")
        if not c[3]:
            faults.append(f"FOR      {rel} — `{key}`'s row says nothing about what it is for")
        counted = COUNTED.match(c[2])
        if counted:
            if (int(counted.group(1)), int(counted.group(2))) != (len(importers), len(files)):
                faults.append(
                    f"COUNT    {rel} — `{key}` is imported by {len(importers)} of "
                    f"{len(files)} files, the row says {c[2]}"
                )
            elif len(importers) <= MAX_LISTED:
                faults.append(
                    f"COUNT    {rel} — `{key}` has only {len(importers)} importers; "
                    f"name them rather than counting them"
                )
            continue
        stated = stated_importers(c[2], files)
        if stated is None:
            faults.append(f"IMPORTERS {rel} — `{key}`'s row credits no file")
        elif stated != importers:
            faults.append(
                f"IMPORTERS {rel} — `{key}` is imported by {_list(importers)}; "
                f"the row says {_list(stated)}"
            )
        elif len(importers) > MAX_LISTED and c[2] != "every file":
            faults.append(
                f"COUNT    {rel} — `{key}` has {len(importers)} importers; "
                f"state `{len(importers)} of {len(files)} files` instead"
            )

    if order != sorted(order):
        faults.append(
            f"ORDER    {rel} — rows run out of order; they go dart, package, "
            f"module, alphabetical within each"
        )

    return faults


def _list(values) -> str:
    return ", ".join(sorted(values)) or "(none)"


def audit(prefix: str | None) -> tuple[list[str], int]:
    faults: list[str] = []
    audited = 0
    for package, (_, docpat) in PACKAGES.items():
        if prefix and not package.startswith(prefix):
            continue
        for mdir in module_dirs(package):
            doc = gate_scope.package_dir(package) / docpat.format(m=mdir.name)
            faults += audit_module(package, mdir, doc)
            audited += 1
    return faults, audited


# -----------------------------------------------------------------------------
# The self-test: perturb what the gate claims to read, require it to object
# -----------------------------------------------------------------------------

#: A module whose ``dart:async`` row lists a subset of its files, so every
#: perturbation below has something true to spoil.
CACHE = ("tom_core_server", "cache", "doc/cache.md")

#: A module large enough to state a count rather than a file list.
FORMS = ("tom_flutter_ui", "forms", "doc/forms.md")

#: The one module that imports nothing, so its section carries no table.
BEARER = ("tom_core_agentic", "bearer_auth", "doc/bearer_auth.md")

#: ``(name, probe, perturbation, expected fault)``. Each rewrites one true table
#: into a false one, so a gate that had stopped reading that column would pass
#: the perturbed document and fail here.
SELF_TESTS = [
    ("a dropped row", CACHE, lambda t: re.sub(r"(?m)^\| `dart:async` \|.*\n", "", t, count=1), "MISSING"),
    ("an invented row", CACHE, lambda t: re.sub(
        r"(?m)^(\| `dart:async` \|.*\n)",
        r"\1| `nonesuch` | package | `nowhere.dart` | invented |\n", t, count=1), "EXTRA"),
    ("a wrong kind", CACHE, lambda t: re.sub(r"(?m)^(\| `dart:async` \| )dart( \|)", r"\1package\2", t, count=1), "KIND"),
    ("a wrong importer", CACHE, lambda t: re.sub(r"(?m)^(\| `dart:async` \| dart \| )[^|]*(\|)",
                                          r"\1`nowhere.dart` \2", t, count=1), "IMPORTERS"),
    ("an empty reason", CACHE, lambda t: re.sub(r"(?m)^(\| `dart:async` \| dart \| [^|]*\| )[^|]*(\|)",
                                         r"\1\2", t, count=1), "FOR"),
    ("a row missing a cell", CACHE, lambda t: re.sub(
        r"(?m)^(\| `dart:isolate` \| dart \| `server_cache\.dart` \| )([^|]*)\|",
        r"\1\2", t, count=1), "CELLS"),
    ("rows out of order", CACHE, lambda t: _swap_rows(t), "ORDER"),
    ("a wrong count", FORMS, lambda t: re.sub(
        r"(?m)^(\| `flutter` \| package \| )\d+( of \d+ files)", r"\g<1>3\2",
        t, count=1), "COUNT"),
    ("a table where there are no imports", BEARER, lambda t: t.replace(
        "## Dependencies\n",
        "## Dependencies\n\n" + HEADER + "\n| ---------- | ---- | ----------- | --- |\n"
        "| `nonesuch` | package | `x.dart` | invented |\n", 1), "SHAPE"),
    ("a lost header", CACHE, lambda t: t.replace(HEADER, "| Dependency | Used for |", 1), "SHAPE"),
]

def _swap_rows(text: str) -> str:
    """The first two body rows, exchanged — a table in the wrong order."""
    lines = text.splitlines()
    first = next(
        (i for i, ln in enumerate(lines) if ln.startswith("| `dart:async`")), None
    )
    if first is None or first + 1 >= len(lines):
        return text
    lines[first], lines[first + 1] = lines[first + 1], lines[first]
    return "\n".join(lines) + "\n"


def self_test() -> int:
    failures = 0
    for name, probe, perturb, expected in SELF_TESTS:
        package, module, docrel = probe
        doc = gate_scope.package_dir(package) / docrel
        mdir = gate_scope.package_dir(package) / PACKAGES[package][0] / module
        original = doc.read_text()

        clean = audit_module(package, mdir, doc)
        if clean:
            print(f"  FAIL  {name} — the probe {docrel} is not clean to begin with: {clean[0]}")
            failures += 1
            continue

        spoiled = perturb(original)
        if spoiled == original:
            print(f"  FAIL  {name} — the perturbation changed nothing; the probe moved")
            failures += 1
            continue
        try:
            doc.write_text(spoiled)
            got = audit_module(package, mdir, doc)
        finally:
            doc.write_text(original)

        if any(f.startswith(expected) for f in got):
            print(f"  ok    {name} — caught as {expected}")
        else:
            print(f"  FAIL  {name} — expected {expected}, got {got or '(nothing)'}")
            failures += 1

    print(f"\n{len(SELF_TESTS) - failures} of {len(SELF_TESTS)} perturbations detected")
    return report_faults(failures)


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()

    prefix = next((a for a in argv if not a.startswith("-")), None)
    faults, audited = audit(prefix)

    for fault in faults:
        print(fault)

    print(f"\nmodules audited          : {audited}")
    print(f"documents defective      : {len({f.split()[1] for f in faults})}")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
