#!/usr/bin/env python3
"""Find resource keys written with a dotted scope in front of the type.

Run from anywhere::

    python3 tool/check_resource_key_namespace.py                  # whole repo
    python3 tool/check_resource_key_namespace.py tom_core_samples # one subtree

Exits non-zero when a merged key appears, so it can gate a build.

The advanced sample addresses things in two key spaces, and they are not one
namespace:

``item:<id>``
    The **resource** key. Built only by ``ResourceRoleKeys`` in the shared
    domain, it names a resource and picks the principal's role
    (``resourceRoles[itemKey]``).
``todo.item.<field>``
    The **graded field** key -- a ``TomField`` basePath, picking the grade
    within that role's row (``grades[basePath]``).

They meet at exactly one point, the narrow in ``item_detail_screen.dart``, and
writing the type segment with the dotted scope glued to its front --
``todo.`` immediately followed by ``item:`` and an id -- merges them.

**Why this needs a gate rather than a fix.** It was fixed, twice, and came
back. The merged form was printed in roughly fifteen places across the guides
and in both representations of figure 09, and doc 07 states the rule those
examples violate six lines above them. Nothing reported any of it; the whole
population was found by a manual scan.

That is the profile this suite already treats as the case *for* automating (see
``check_source_citations.py``): the fault is invisible by construction. The
merged key is a plausible-looking string, no compiler sees it, no test covers
prose, and it reads perfectly fluently -- ``todo.item:5`` looks exactly like
what a reader would guess the key to be. Worse, it is invisible even when
*executed*: ``AppResourceRoleAdapter.resolveAuth`` gates any key containing
``:``, so a merged key is resolved as a resource key, matches no grant, and
collapses the field to ``none``. Closed-safe, so nothing breaks loudly -- the
field simply is not there, which is also what a legitimately unauthorized field
looks like.

**Why the rule can be tight.** The obvious pattern -- a dotted path followed by
a colon -- is unusable here, because this tree is full of source citations
(``tom_form.dart:823``, ``item_detail_screen.dart:146-171``) that match it
perfectly. So the rule keys on the *type segment* instead: a fault is a dotted
prefix immediately before one of the four resource types that
``ResourceRoleKeys`` actually declares. ``dart`` is not a resource type, so
every citation in the tree is ignored without an exception list.

That leaves one real collision, found by running it: a Dart ``switch`` label,
``case AppResourceTypes.item:``, is the fault's shape exactly, and there are ten
of them. Two narrowings separate the two without naming any file. The scope
segment must **start lowercase** -- grade scopes are scopes (``todo``), while
the things that carry a type constant are classes (``AppResourceTypes``,
``TomWidgetFamily``) -- and the colon must be **followed by something on the
same line**, since a case label ends at the colon and a resource key is exactly
the thing that continues into an id. Either one alone would do it on today's
tree; both are cheap, and they fail independently.

The type names are read from ``resource_keys.dart`` rather than copied here, so
adding a fifth resource type extends the check by construction instead of
silently leaving the new type unguarded.

**No exceptions, deliberately.** A checker that permits the bad string
"where it is being explained" would permit it in exactly the document most
likely to be copied from, which is how the guides acquired fifteen copies. The
figure and the guides therefore describe the merge without spelling it, and the
rule holds everywhere with no escape hatch to get wrong.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from gate_report import report_faults
import gate_scope

REPO_ROOT = Path(__file__).resolve().parent.parent

SKIP_DIRS = {".dart_tool", "build", ".git", "node_modules", "__pycache__"}
SUFFIXES = (".dart", ".md", ".svg", ".yaml", ".sql")

VOCABULARY = (
    REPO_ROOT
    / "tom_core_samples"
    / "advanced_todo_domain"
    / "lib"
    / "src"
    / "authz"
    / "resource_keys.dart"
)
TYPE_DECL = re.compile(r"""static\s+const\s+String\s+\w+Type\s*=\s*'([^']+)'""")


def resource_types() -> list[str]:
    """The resource type tokens, read from the shared domain that declares them."""
    text = VOCABULARY.read_text(encoding="utf-8")
    types = TYPE_DECL.findall(text)
    if not types:
        raise SystemExit(f"no resource types found in {VOCABULARY}")
    return types


def source_files(root: Path) -> list[Path]:
    out = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.suffix not in SUFFIXES:
            continue
        if SKIP_DIRS & set(path.parts):
            continue
        out.append(path)
    return out


def main(argv: list[str]) -> int:
    roots = gate_scope.scope(argv[0] if argv else None)
    if not roots[0].exists():
        print(f"no such path: {roots[0]}", file=sys.stderr)
        return 2

    types = resource_types()
    # A dotted scope glued to the front of a real resource type, followed by the
    # `:` that only a resource key carries, and then an id.
    #
    # Two narrowings keep Dart `switch` labels out. `case AppResourceTypes.item:`
    # has the same shape as the fault and appears ten times in this tree, so:
    # the scope segment must start lowercase (grade scopes are `todo`, enum
    # holders are `AppResourceTypes`/`TomWidgetFamily`), and the colon must be
    # followed by something on the same line (a case label ends there).
    merged = re.compile(
        rf"(?<![\w.])[a-z]\w*\.({'|'.join(map(re.escape, types))}):(?=\S)"
    )

    scanned = 0
    faults: list[tuple[Path, int, str]] = []

    for path in (p for root in roots for p in source_files(root)):
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        scanned += 1
        for number, line in enumerate(text.split("\n"), start=1):
            for match in merged.finditer(line):
                faults.append((path, number, match.group(0)))

    for path, number, hit in faults:
        rel = gate_scope.rel(path)
        print(
            f"{rel}:{number}: `{hit}` merges the field-grade namespace into the "
            f"resource-key namespace; the resource key is `{hit.split('.')[-1]}<id>`"
        )

    print()
    print(f"resource types (from resource_keys.dart) : {', '.join(types)}")
    print(f"files scanned                            : {scanned}")
    print(f"merged resource keys                     : {len(faults)}")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
