#!/usr/bin/env python3
"""Count the `Tom*` type names shipped documentation writes that no code declares.

Run from anywhere::

    python3 tool/check_doc_phantom_names.py                 # the whole repo
    python3 tool/check_doc_phantom_names.py tom_flutter_ui  # one subtree
    python3 tool/check_doc_phantom_names.py --names         # grouped by name

Exits non-zero when any is found, so the runner can hold the count to its
baseline.

**Why.** A specification is designed first and built second, and the build
does not always keep the design's names. The forms specification named five
error-presentation widgets -- `TomFormErrorDisplay`, `TomFormErrorSnackbar`,
`TomFormErrorInline`, `TomFormErrorList`, `TomMasterDetailScaffold` -- that the
framework never declared, in prose describing the subsystem as built. A reader
who searched for any of them found nothing, and no gate noticed:
``check_doc_class_inventories.py`` reports a phantom only inside a marked
inventory region, and these sat in ordinary prose.

**What counts.** A name in a code span that begins ``Tom`` and an upper-case
letter, in a shipped markdown document, that no `class`, `enum`, `mixin`,
`typedef` or `extension` anywhere under `tom_ai/` declares. The declaration
index spans the sibling repositories because documentation here legitimately
names their types. Each (line, name) occurrence is one fault, so one more
mention of a known phantom moves the count.

**Why a ratchet, not a zero.** Measured 2026-10-07 the population is 211
occurrences of 107 names, and most are not defects: a design document that
says it is partially implemented names the parts still unbuilt, a migration
note names the type it migrated from, a divergence table names what the
specification called a type before the build chose otherwise, and a family is
written by its prefix (`TomCupertinoForm…`). Telling those apart from a
phantom is a judgement this gate cannot make, so it does not try. What it can
do is make the population *visible and fixed*: a new phantom moves the count
and fails the run, and repairing one lowers the baseline.

The population is the shipped markdown ``check_section_refs.py`` scans --
every document under a package's ``doc/`` and every package or module readme.
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

from check_section_refs import REPO_ROOT, shipped_files
from gate_report import report_faults
import gate_scope

#: The tree whose Dart declares the names documentation may write.
WORKSPACE_CODE = REPO_ROOT.parent

DECLARATION = re.compile(
    r"\b(?:class|enum|mixin|typedef|extension(?:\s+type)?)\s+(Tom[A-Z]\w*)")

#: A `Tom*` name opening a code span: `` `TomForm` ``, `` `TomForm<T>` ``,
#: `` `TomForm.validate()` ``.
NAME_IN_SPAN = re.compile(r"`(Tom[A-Z]\w*)")

SKIP_DIRS = {".dart_tool", "build", ".git", "node_modules"}


def declared_names() -> set[str]:
    """Every `Tom*` type declared in Dart anywhere under `tom_ai/`."""
    names: set[str] = set()
    for path in WORKSPACE_CODE.rglob("*.dart"):
        if SKIP_DIRS & set(path.parts):
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        names.update(DECLARATION.findall(text))
    return names


def phantoms(root: Path, declared: set[str]):
    """Yield `(path, line, name)` for every undeclared name in a code span."""
    for path in shipped_files(root):
        if path.suffix != ".md":
            continue
        lines = path.read_text(encoding="utf-8").split("\n")
        for number, line in enumerate(lines, start=1):
            for name in sorted(set(NAME_IN_SPAN.findall(line))):
                if name not in declared:
                    yield path, number, name


def main(argv: list[str]) -> int:
    by_name = "--names" in argv
    args = [a for a in argv if a != "--names"]
    roots = gate_scope.scope(args[0] if args else None)
    if not roots[0].exists():
        print(f"no such path: {roots[0]}", file=sys.stderr)
        return 2

    declared = declared_names()
    # A declaration index this small means the walk missed the code, and every
    # name would read as a phantom: refuse rather than report a flood.
    if len(declared) < 500:
        print(f"only {len(declared)} declarations found under "
              f"{WORKSPACE_CODE}; not measured", file=sys.stderr)
        return 2

    found = [hit for root in roots for hit in phantoms(root, declared)]
    if by_name:
        grouped: dict[str, list[str]] = defaultdict(list)
        for path, line, name in found:
            grouped[name].append(f"{gate_scope.rel(path)}:{line}")
        for name in sorted(grouped, key=lambda n: (-len(grouped[n]), n)):
            print(f"{name}  ({len(grouped[name])})")
            for site in grouped[name]:
                print(f"    {site}")
    else:
        for path, line, name in found:
            print(f"{gate_scope.rel(path)}:{line}: `{name}` is "
                  "declared nowhere under tom_ai/")

    print()
    print(f"declarations indexed     : {len(declared)}")
    print(f"undeclared names         : {len({n for _, _, n in found})}")
    print(f"occurrences              : {len(found)}")
    return report_faults(len(found))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
