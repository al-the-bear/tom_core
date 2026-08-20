#!/usr/bin/env python3
"""Audit every ``## Table of Contents`` in the tom_core tree against its file.

Run from anywhere::

    python3 tool/check_doc_tocs.py            # audit the whole repo
    python3 tool/check_doc_tocs.py tom_core_kernel   # audit one subtree

Exits non-zero when any document is defective, so it can gate a build.

Three faults are reported, and the third is the one worth keeping:

``MISSING``
    An ``##`` section the ToC does not list. This is the common defect — a
    document grows a section and its ToC is not touched.
``STALE``
    An entry whose target matches no heading, i.e. a link that goes nowhere.
    Usually a heading that was reworded after the ToC was written.
``ORDER``
    Entries that all resolve, listed in an order the document does not follow.
    A presence check passes this happily; it is only caught by comparing
    sequences, and it is what makes a ToC misleading rather than merely
    incomplete.

Why this file exists at all: it has now been written from scratch twice, and
both times most of the effort went into rediscovering the same five ways of
producing false positives (see ``anchor`` and the notes below). Committing it
is cheaper than re-deriving it a third time.
"""

from __future__ import annotations

import html
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

TOC_HEADING = re.compile(r"^##\s+table of contents\s*$", re.I)
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*$")

# Bullet ToCs (`- [x](#x)`) and numbered ToCs (`1. [x](#1-x)`) alike. Matching
# only bullets hides whole doc families — and a numbered ToC is exactly the
# kind that drifts, because the label drops the number while the anchor keeps
# it, so the two sides stop resembling each other.
TOC_ENTRY = re.compile(r"^(\s*)(?:[-*]|\d+[.)])\s+\[(.+?)\]\(#([^)]*)\)")

SKIP_DIRS = {"node_modules", ".dart_tool", ".git", "build", "ztmp"}


def anchor(text: str) -> str:
    """Render a heading the way GitHub does when it builds a fragment id.

    Every rule here was added to kill a batch of false positives:

    - Anchors are built from the *rendered* text, so HTML entities decode
      first: ``TomSetting&lt;T&gt;`` renders as ``TomSetting<T>`` and anchors as
      ``tomsettingt``.
    - Punctuation is dropped but ``_`` and ``-`` survive.
    - Runs of spaces are **not** collapsed. Dropping the em dash from
      ``A — B`` leaves two spaces and therefore ``a--b``.
    """
    text = html.unescape(text).lower()
    text = re.sub(r"[^a-z0-9 _-]", "", text)
    return text.replace(" ", "-")


class Report:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.missing: list[tuple[int, str]] = []
        self.stale: list[tuple[str, str]] = []
        self.order: tuple[list[str], list[str]] | None = None

    @property
    def clean(self) -> bool:
        return not (self.missing or self.stale or self.order)

    def render(self) -> str:
        lines = [f"{self.path.relative_to(REPO_ROOT)}"]
        for line_no, text in self.missing:
            lines.append(f"    MISSING  :{line_no:<5} {text}")
        for text, target in self.stale:
            lines.append(f"    STALE          [{text}](#{target})")
        if self.order:
            doc_order, toc_order = self.order
            lines.append("    ORDER    document: " + " ".join(doc_order))
            lines.append("    ORDER    contents: " + " ".join(toc_order))
        return "\n".join(lines)


def audit(path: Path) -> Report | None:
    """Return a Report, or None if the file carries no table of contents."""
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()

    toc_start = next((i for i, l in enumerate(lines) if TOC_HEADING.match(l)), None)
    if toc_start is None:
        return None

    entries: list[tuple[str, str]] = []  # (label, target)
    for line in lines[toc_start + 1:]:
        if line.startswith("## "):
            break
        match = TOC_ENTRY.match(line)
        if match:
            entries.append((match.group(2), match.group(3)))
    if not entries:
        return None

    # `headings` holds every level, because an entry pointing at an `####` is a
    # perfectly good link and staleness must be judged against the whole file.
    # `listable` is the subset a ToC can fairly be held to: only `##`. A ToC
    # that indents a few subsections is not promising to list them all, so
    # holding it to every `###` manufactures defects instead of finding them.
    headings: list[tuple[int, str]] = []
    listable: list[tuple[int, str]] = []
    in_fence = False
    for i, line in enumerate(lines):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        match = HEADING.match(line)
        if not match:
            continue
        level, text = len(match.group(1)), match.group(2)
        headings.append((i + 1, text))
        # The ToC heading is a real anchor (a ToC may link to itself) but is
        # not a section the ToC is expected to list.
        if level == 2 and i != toc_start:
            listable.append((i + 1, text))

    # Everything is judged on the link TARGET, never the label. A numbered ToC
    # legitimately writes `[Overview](#1-overview)` against a heading
    # `1. Overview`; comparing labels would call that broken.
    heading_anchors = {anchor(text) for _, text in headings}
    targets = {target.lower() for _, target in entries}

    report = Report(path)
    report.missing = [(n, t) for n, t in listable if anchor(t) not in targets]
    report.stale = [(l, t) for l, t in entries if t.lower() not in heading_anchors]

    doc_order = [anchor(t) for _, t in headings if anchor(t) in targets]
    toc_order = [t.lower() for _, t in entries if t.lower() in heading_anchors]
    if doc_order != toc_order:
        report.order = (doc_order, toc_order)

    return report


def main(argv: list[str]) -> int:
    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    checked = 0
    defective: list[Report] = []
    for path in sorted(root.rglob("*.md")):
        if SKIP_DIRS & set(path.parts):
            continue
        report = audit(path)
        if report is None:
            continue
        checked += 1
        if not report.clean:
            defective.append(report)

    for report in defective:
        print(report.render())

    missing = sum(len(r.missing) for r in defective)
    stale = sum(len(r.stale) for r in defective)
    order = sum(1 for r in defective if r.order)

    print()
    print(f"documents with a table of contents : {checked}")
    print(f"documents defective                : {len(defective)}")
    print(f"  unlisted sections                : {missing}")
    print(f"  links resolving to no heading    : {stale}")
    print(f"  contents out of document order   : {order}")
    return 1 if defective else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
