#!/usr/bin/env python3
"""Find ``**Source:**`` pointers in documentation that name a path which no longer exists.

Run from anywhere::

    python3 tool/check_doc_source_paths.py                  # whole repo
    python3 tool/check_doc_source_paths.py tom_flutter_ui   # one subtree

Exits non-zero when a pointer resolves to nothing, so it can gate a build.

**The fault.** A prose document says "the code for this is over there" and
points at a directory that was deleted two refactors ago. The reader follows
it, finds nothing, and now has to guess whether the *feature* moved, the
*document* is stale, or they typed something wrong. The instance that prompted
this checker had a part header naming ``lib/src/tomclient/forms/`` in a package
where that directory no longer exists -- while a subsection of that same part
correctly pointed at the directory it had moved to. The document contradicted
itself two screens apart, and had done so since the move.

**Why it needs a machine.** This is the failure mode of every cross-artifact
reference: it breaks from a distance. Nothing about deleting a directory brings
the paragraph that cites it into view, the markdown still renders, no build
step reads it, and the sentence around it still reads fluently. The only
signal is a human following the pointer and coming back empty -- which happens
long after the cheap moment to fix it has passed. That is the same argument
made for ``check_source_citations.py``, and it applies with more force here,
because a path can be checked exactly: either the file is on disk or it is not.
There is no judgement in the rule and so no noise to triage.

**Resolution, and why it needs three roots.** A pointer is accepted if it
resolves against any of:

``<workspace>/<path>``
    A workspace-relative path. This is what cross-repo pointers need -- the
    UAM sample lives in a sibling repository, not in this one.
``<repo>/<path>``
    A repo-relative path, i.e. package-prefixed like
    ``tom_flutter_ui/lib/src/forms/``. This is the dominant convention.
``<repo>/<pkg>/<path>`` for each package named in a nearby ``**Package:**``
    A package-*relative* path, which is only meaningful when an adjacent
    ``**Package:**`` (or ``**Packages:**``) line supplies the prefix.

That third root is what keeps the rule honest rather than merely strict. A bare
``lib/src/...`` under a ``**Package:** `tom_core_kernel``` header is *correct*,
and a checker that flagged it would be training readers to ignore it. The same
bare path with no such header is genuinely unresolvable, and is reported. The
two cases differ by a line the checker can see, so it can tell them apart.

**On documents that describe removed code.** A history or migration document
legitimately *names* types and directories that no longer exist, and this rule
does not stop it -- because naming a removed thing in prose is not the same as
pointing at it. ``**Source:**`` is an instruction to go and read something; it
is false the moment the target is gone, whatever the surrounding document is
for. The way to mention a deleted type is inline and explicitly labelled, the
way the state-management document contrasts the legacy
``tom_core_flutter.TomForm`` with the shape that replaced it. So there is no
suppression list here, and no document kind is exempt: the rule is a convention
about what ``**Source:**`` means, not a filter over which files are checked.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
WORKSPACE = REPO_ROOT.parent.parent

SKIP_PARTS = {"build", ".dart_tool", "ephemeral", ".pub-cache", "node_modules"}

SOURCE_LINE = re.compile(r"^\*\*Source:\*\*\s+(.+?)\s*$")
PACKAGE_LINE = re.compile(r"^\*\*Packages?:\*\*\s+(.+?)\s*$")
CODE_SPAN = re.compile(r"`([^`]+)`")

# How far above a ``**Source:**`` line a ``**Package:**`` line may sit and still
# be read as qualifying it. They are adjacent in every current use; the slack
# tolerates a blank line or a **Status:** line slipping between them.
PACKAGE_LOOKBEHIND = 3


def packages_for(lines: list[str], index: int) -> list[str]:
    """Return the package names qualifying the ``**Source:**`` line at *index*."""
    for offset in range(1, PACKAGE_LOOKBEHIND + 1):
        j = index - offset
        if j < 0:
            break
        match = PACKAGE_LINE.match(lines[j])
        if match:
            return CODE_SPAN.findall(match.group(1))
    return []


def resolves(path: str, packages: list[str]) -> bool:
    """True when *path* names something on disk under any accepted root."""
    roots = [WORKSPACE, REPO_ROOT] + [REPO_ROOT / pkg for pkg in packages]
    return any((root / path).exists() for root in roots)


def markdown_files(subtree: Path):
    for md in sorted(subtree.rglob("*.md")):
        if SKIP_PARTS.isdisjoint(md.parts):
            yield md


def main(argv: list[str]) -> int:
    subtree = REPO_ROOT / argv[1] if len(argv) > 1 else REPO_ROOT
    if not subtree.exists():
        print(f"MISSING {subtree}")
        return 1

    checked = 0
    faults = 0

    for md in markdown_files(subtree):
        lines = md.read_text(encoding="utf-8").splitlines()
        for i, line in enumerate(lines):
            match = SOURCE_LINE.match(line)
            if not match:
                continue
            packages = packages_for(lines, i)
            for path in CODE_SPAN.findall(match.group(1)):
                checked += 1
                if resolves(path, packages):
                    continue
                faults += 1
                qualifier = (
                    f" (relative to {', '.join(packages)})" if packages else ""
                )
                print(f"{md.relative_to(REPO_ROOT)}:{i + 1}")
                print(f"    unresolved: {path}{qualifier}")

    print()
    print(f"source pointers checked: {checked}")
    print(f"faults: {faults}")
    return 1 if faults else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
