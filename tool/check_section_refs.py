#!/usr/bin/env python3
"""Find section references in shipped code that name no resolvable document.

Run from anywhere::

    python3 tool/check_section_refs.py                  # the whole repo
    python3 tool/check_section_refs.py tom_core_server  # one subtree

Exits non-zero when any reference is unresolvable, so it can gate a build.

A ``§`` reference is fine when the sentence says *what it indexes*::

    per `codespecs_mapping.md` §5.16
    RFC 7636 §1
    OIDC Core §3.1.3.7

and is a fault when it stands bare::

    (bug §75)
    Before §22 the unanchored regex accepted this
    // §43(a) / bug §69: a registry endpoint must inherit ...

**Why a bare number is a defect and not a style preference.** The numbers index
sections of the quest plans -- ``readme_and_example_plan.md`` and its siblings
-- which are working documents that ship with neither the package nor its
tests. A reader of the shipped artefact cannot resolve them, and a reader who
could would find a build log rather than a rule. The shipped convention is that
source and tests state the *current* behaviour and the reason for it, not the
sequence of states that produced it. A test name in particular is read as a
specification, and ``bug §75`` specifies nothing: when it fails, the report
names an index entry instead of the contract that broke.

The check therefore covers ``lib/``, ``test/`` and ``example/`` -- the three
places whose contents leave the workspace. Quest plans and other markdown are
not scanned: cross-referencing its own sections is exactly what a plan is for.

**What counts as naming the document.** The text immediately left of the ``§``
must end in a markdown-quoted or bare ``.md`` filename, an ``RFC <n>``, or one
of the specification names used in this tree (``CodeSpecs``, ``OIDC Core``).
That is a deliberately literal rule: it is cheap to satisfy correctly (write
the document name you meant) and it cannot be satisfied by accident, which is
the property that makes it worth gating on.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {".dart_tool", "build", ".git", "node_modules", "__pycache__"}

#: The directories whose contents ship. Everything else in a package is
#: workspace-internal and may reference the plans freely.
SHIPPED_DIRS = {"lib", "test", "example"}

#: A section reference: the sign, optional space, a number.
REFERENCE = re.compile(r"§\s*[0-9]+")

#: What has to sit immediately left of the sign for the reference to resolve.
#: Anchored at the end, so it is the *nearest* preceding token that decides.
NAMED_SOURCE = re.compile(
    r"(\.md`?|RFC\s*\d+|CodeSpecs|OIDC Core|Core)\s*$",
    re.IGNORECASE,
)


def dart_files(root: Path):
    """Every shipped Dart file under ``root``."""
    for path in sorted(root.rglob("*.dart")):
        parts = set(path.parts)
        if SKIP_DIRS & parts:
            continue
        if not (SHIPPED_DIRS & parts):
            continue
        yield path


def unresolved(path: Path) -> list[tuple[int, str]]:
    """The `(line, text)` of every bare section reference in ``path``."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return []
    faults = []
    for number, line in enumerate(text.split("\n"), start=1):
        for match in REFERENCE.finditer(line):
            if NAMED_SOURCE.search(line[: match.start()]):
                continue
            faults.append((number, line.strip()))
            break  # one report per line is enough to find it
    return faults


def main(argv: list[str]) -> int:
    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    scanned = 0
    faults: list[tuple[Path, int, str]] = []
    for path in dart_files(root):
        scanned += 1
        for line, text in unresolved(path):
            faults.append((path, line, text))

    for path, line, text in faults:
        print(f"{path.relative_to(REPO_ROOT)}:{line}: {text}")

    print()
    print(f"dart files scanned       : {scanned}")
    print(f"unresolvable references  : {len(faults)}")
    return 1 if faults else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
