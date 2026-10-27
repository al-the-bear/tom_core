#!/usr/bin/env python3
"""Hold every `lib/src/**/readme.md` to the four elements they all share.

Run from anywhere::

    python3 tool/check_module_readme_shape.py                  # every package
    python3 tool/check_module_readme_shape.py tom_core_server  # one package
    python3 tool/check_module_readme_shape.py --self-test      # check the checker

Exits non-zero when a module readme is missing one, so it can gate a build.

**The defect this exists for.** `tom_core_server`'s `scheduling` readme was the
longest and most substantive of its twenty, and carried none of the attribution
blockquote, the `## Key types` heading over its own type table, or a
`## Quick start`. It was not thin — it was complete, written to a different
shape, most likely before the convention settled. A convention that settles
without being written is one a document can miss entirely while reading as
finished work, which is why the omission survived every review the module had.

**What the four are, and why each is load-bearing rather than decoration.**

``> **Attribution.**``
    The blockquote naming the author and the licence. These files are read
    outside the workspace that wrote them.
``## Key types``
    The heading over the type table. `scheduling` *had* the table — unheaded,
    so it appeared in no document outline and a reader scanning headings did
    not find it. The heading is what makes the table reachable by the only
    navigation a long readme has.

    Matched on its opening words rather than in full: two kernel modules ship
    functions beside their types and head the table `## Key types & functions`,
    which is the same undertaking more accurately titled. Demanding the exact
    string would make those two rename a heading to describe their content
    less well, which is the gate legislating about prose rather than about
    what a reader can find.
``## Quick start``
    A runnable sequence whose stated output is reachable given the
    preconditions it shows.
``Part of [`<package>`](…)``
    The footer pointing back at the package README, which is where the module
    map and the installation live. Without it a module readme reached directly
    is a leaf with no route up.

**Anti-vacuity.** A gate baselined at zero passes just as well once it has
stopped reading, so `main` exits 2 when the walk finds fewer readmes than the
floor. `--self-test` asks the opposite question: it removes each of the four
from a real readme in turn and requires this checker to object to each.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from gate_report import report_faults
import gate_scope

REPO_ROOT = Path(__file__).resolve().parent.parent

#: The four elements, each as the pattern that recognises it and the name a
#: failure is reported under.
ELEMENTS = {
    "attribution blockquote": re.compile(r"^> \*\*Attribution\.\*\*", re.M),
    "`## Key types` heading": re.compile(r"^## Key types\b", re.M),
    "`## Quick start` section": re.compile(r"^## Quick start\s*$", re.M),
    "`Part of` footer": re.compile(r"^Part of \[`[\w.]+`\]\(", re.M),
}

#: The floor the walk has to clear. Stated loosely — modules come and go — but
#: an order of magnitude below it is a reader that has broken.
MINIMUM_READMES = 40


def module_readmes(subtree: str | None) -> list[Path]:
    """Every `lib/src/**/readme.md` under [REPO_ROOT], sorted."""
    found = [
        path
        for path in gate_scope.glob_all("*/lib/src/**/readme.md")
        if path.is_file()
    ]
    if subtree is None:
        return found
    return [path for path in found if gate_scope.rel(path).parts[0] == subtree]


def faults_in(readme: Path) -> list[str]:
    """The elements [readme] is missing."""
    text = readme.read_text(encoding="utf8")
    where = gate_scope.rel(readme)
    return [
        f"{where}  has no {name}"
        for name, pattern in ELEMENTS.items()
        if not pattern.search(text)
    ]


def self_test() -> int:
    """Remove each element from a real readme in turn; require an objection."""
    readme = (
        REPO_ROOT
        / "tom_core_server"
        / "lib"
        / "src"
        / "tomserver"
        / "scheduling"
        / "readme.md"
    )
    original = readme.read_text(encoding="utf8")
    try:
        for name, pattern in ELEMENTS.items():
            match = pattern.search(original)
            if match is None:
                print(f"self-test: {readme} has no {name} to remove", file=sys.stderr)
                return 2
            readme.write_text(
                original[: match.start()] + "x" + original[match.end() :],
                encoding="utf8",
            )
            if not any(name in fault for fault in faults_in(readme)):
                print(f"self-test: a missing {name} was not reported", file=sys.stderr)
                return 2
    finally:
        readme.write_text(original, encoding="utf8")

    if faults_in(readme):
        print("self-test: the restored readme is not clean", file=sys.stderr)
        return 2
    print("self-test: passed")
    return 0


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()
    subtree = argv[0] if argv and not argv[0].startswith("-") else None

    readmes = module_readmes(subtree)
    if subtree is None and len(readmes) < MINIMUM_READMES:
        print(
            f"the walk found {len(readmes)} module readmes — it has gone wrong "
            "rather than the repository having shrunk",
            file=sys.stderr,
        )
        return 2

    faults = [fault for readme in readmes for fault in faults_in(readme)]
    for fault in faults:
        print(fault)

    print(f"\nmodule readmes walked    : {len(readmes)}")
    print(f"packages covered         : {len({gate_scope.rel(r).parts[0] for r in readmes})}")
    print(f"readmes with a fault     : {len({f.split()[0] for f in faults})}")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
