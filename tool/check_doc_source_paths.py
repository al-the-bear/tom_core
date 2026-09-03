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

**Second check: a named module directory must exist, or be recorded as gone.**
The paragraph above deliberately leaves bare prose mentions alone, because
naming a removed directory is legitimate and a checker that demanded existence
would be wrong. That carve-out has a cost, and ``iding/`` is what it cost.

``lib/src/tomclient/iding/`` was an empty directory. Git tracks files, not
directories, so it was never committed -- it appears in **no** commit on any
branch -- and the removal record for this package was built by diffing the
baseline tree against HEAD. A tree diff cannot report a directory that was
never in either tree, so the record covered four removed directories and did
not know about the fifth. Meanwhile the package's own ``review_findings.md``
named it three times. A reader meeting the name there had nowhere to go.

The fix is not to demand that every named directory exist. It is to demand that
a named directory which *does not* exist be **accounted for** -- and coverage,
unlike existence, is the right bar for prose. So the rule is two lookups:

1. a backticked path ``` `lib/src/.../<dir>/` ``` that resolves on disk passes;
2. one that does not must have ``` `<dir>` ``` named somewhere in the tom_core
   completion corpus, which is where this repo records removals.

Neither step is a judgement, so this stays on the right side of the same line
the rule above draws. What it adds is the one thing a tree diff structurally
cannot supply: documentation is the only surviving witness to an empty
directory, so documentation is what has to be cross-checked.

**Measured before being switched on.** Across the repo the rule finds 97
directory claims. Six sites name five directories that are absent from disk --
``camera``, ``forms``, ``localstorage``, ``qrcode``, ``iding`` -- and all five
are covered by the removal record, so the rule reports zero faults today and
adds no triage burden. Run against the completion corpus as committed before
the ``iding`` fix, it reports exactly one fault: the real one.

Falsified in ten directions against the shipped function, not a
reimplementation. It fires on the historical fault, on a planted absent and
uncovered directory, and on a missing directory in a nested package cited from
two different places; it stays silent on the current tree, for a directory that
exists, for an absent one the record covers, for an existing nested-package
directory cited from two different places, and for a ``.dart`` path, which the
``**Source:**`` rule above owns.

Five of those cases exist because a draft got the resolution wrong, and the
history is worth keeping because each wrong version *passed everything it was
tested against at the time*. F5/F6 guard the repo-root-only index, which could
not see a nested package. F8/F9 guard the ancestor-walk that replaced it, which
resolved a nested package only for documents that happened to live under the
same parent -- a bug this file's own CHANGELOG entry exposed within minutes of
being written, by citing ``advanced_ops_server/lib/src/jobs/`` from
``tom_core_flutter``. Both are now subsumed by ``package_index``.

And the first falsification harness *passed while testing nothing*: it reverted
only the removal record, but this fix had also added the name to the corpus
overview and README, which it read from disk -- so the name was still present
and the rule stayed quiet for the wrong reason. The harness now takes the whole
corpus from the revision under test. A gate that has only been seen to pass is
not a gate.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent
WORKSPACE = REPO_ROOT.parent.parent

SKIP_PARTS = {"build", ".dart_tool", "ephemeral", ".pub-cache", "node_modules"}

SOURCE_LINE = re.compile(r"^\*\*Source:\*\*\s+(.+?)\s*$")
PACKAGE_LINE = re.compile(r"^\*\*Packages?:\*\*\s+(.+?)\s*$")
CODE_SPAN = re.compile(r"`([^`]+)`")

# A backticked module directory, package-relative (`lib/src/x/`) or
# package-prefixed (`tom_core_flutter/lib/src/x/`). The trailing slash is what
# distinguishes a directory claim from a file reference, and it is required:
# without it the rule would start judging `.dart` paths, which the first check
# already owns.
MODULE_DIR = re.compile(r"`((?:[a-z_]\w*/)?lib/src/[\w/]+?)/`")

# Where this repo records removals. A directory absent from disk is a fault
# only if nothing here accounts for it.
REMOVAL_CORPUS = WORKSPACE / "_ai" / "quests" / "tom_core" / "completion"

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


def package_of(md: Path) -> Path | None:
    """The package directory containing *md*, or ``None`` outside one."""
    for parent in md.parents:
        if (parent / "pubspec.yaml").exists():
            return parent
        if parent == REPO_ROOT:
            break
    return None


def removal_corpus() -> str:
    """The text of every removal record, for the coverage lookup."""
    if not REMOVAL_CORPUS.is_dir():
        return ""
    return "\n".join(
        md.read_text(encoding="utf-8", errors="ignore")
        for md in sorted(REMOVAL_CORPUS.glob("*.md"))
    )


def package_index() -> dict[str, Path]:
    """Every package in the repo, by directory name.

    A package-prefixed claim like ``advanced_ops_server/lib/src/jobs/`` names a
    *package*, and the only reliable way to turn that name into a path is to
    look the package up. Two cheaper indexes were tried first and both were
    wrong. The repo root alone fails because packages nest --
    ``advanced_ops_server/`` sits under ``tom_core_samples/`` -- and it reported
    that directory missing when it is plainly there. Walking the *document's*
    ancestors fixes that case only when the document happens to live under the
    same parent, so the ops README resolved it and ``tom_core_flutter``'s
    CHANGELOG, citing the same directory, did not. Where a claim is written has
    nothing to do with where the package it names lives; indexing by name says
    so directly.
    """
    index: dict[str, Path] = {}
    for pubspec in REPO_ROOT.rglob("pubspec.yaml"):
        if not SKIP_PARTS.isdisjoint(pubspec.parts):
            continue
        index.setdefault(pubspec.parent.name, pubspec.parent)
    return index


def audit_module_dirs(
    md: Path,
    lines: list[str],
    corpus: str,
    packages: dict[str, Path] | None = None,
) -> tuple[int, int]:
    """Report directory claims in *md* that neither resolve nor are recorded."""
    package = package_of(md)
    packages = package_index() if packages is None else packages
    claimed = 0
    faults = 0
    for i, line in enumerate(lines):
        for match in MODULE_DIR.finditer(line):
            claim = match.group(1)
            if claim.startswith("lib/"):
                if package is None:
                    continue
                candidates = [package / claim]
            else:
                prefix, rest = claim.split("/", 1)
                named = packages.get(prefix)
                candidates = [REPO_ROOT / claim]
                if named is not None:
                    candidates.append(named / rest)
            claimed += 1
            if any(candidate.is_dir() for candidate in candidates):
                continue
            name = claim.rsplit("/", 1)[-1]
            if re.search(r"`" + re.escape(name) + r"`", corpus):
                continue
            faults += 1
            print(f"{md.relative_to(REPO_ROOT)}:{i + 1}")
            print(f"    UNRECORDED: {claim} is absent and no removal record names it")
    return claimed, faults


def main(argv: list[str]) -> int:
    subtree = REPO_ROOT / argv[1] if len(argv) > 1 else REPO_ROOT
    if not subtree.exists():
        print(f"MISSING {subtree}")
        return 1

    checked = 0
    faults = 0
    claimed = 0
    dir_faults = 0
    corpus = removal_corpus()
    known_packages = package_index()

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

        seen, bad = audit_module_dirs(md, lines, corpus, known_packages)
        claimed += seen
        dir_faults += bad

    print()
    print(f"source pointers checked : {checked}")
    print(f"  unresolved            : {faults}")
    print(f"directory claims checked: {claimed}")
    print(f"  unrecorded            : {dir_faults}")
    return report_faults(faults + dir_faults)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
