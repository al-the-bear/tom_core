#!/usr/bin/env python3
"""Audit a document's own navigation: its table of contents and its anchors.

Run from anywhere::

    python3 tool/check_doc_tocs.py            # audit the whole repo
    python3 tool/check_doc_tocs.py tom_core_kernel   # audit one subtree

Exits non-zero when any document is defective, so it can gate a build.

``check_doc_links`` deliberately accepts any ``#fragment`` and names this gate
as the one that answers whether the heading exists, so that the two never
disagree about how a heading becomes a slug. That makes every in-document
anchor this gate's business -- not only the ones a table of contents happens to
use. A ``[§10](#10-datasources-and-configuration)`` in running prose is the
same defect as a stale contents entry, and nothing else looks for it.

Four faults are reported, and the third is the one worth keeping:

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
``DANGLING``
    A link in the *body* pointing at an anchor of its own document that no
    heading provides. ``STALE`` is this same fault confined to the contents
    block; a document need not carry a table of contents to be checked for it.

Why this file exists at all: it has now been written from scratch twice, and
both times most of the effort went into rediscovering the same five ways of
producing false positives (see ``anchor`` and the notes below). Committing it
is cheaper than re-deriving it a third time.
"""

from __future__ import annotations

import html
import re
import sys
from collections.abc import Iterable
from pathlib import Path

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent

TOC_HEADING = re.compile(r"^##\s+table of contents\s*$", re.I)
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*$")

# Bullet ToCs (`- [x](#x)`) and numbered ToCs (`1. [x](#1-x)`) alike. Matching
# only bullets hides whole doc families — and a numbered ToC is exactly the
# kind that drifts, because the label drops the number while the anchor keeps
# it, so the two sides stop resembling each other.
TOC_ENTRY = re.compile(r"^(\s*)(?:[-*]|\d+[.)])\s+\[(.+?)\]\(#([^)]*)\)")

#: Any inline link whose target is an anchor in this same document. Blanking
#: code spans first keeps a documented ``[x](#y)`` out of the results -- there
#: it is an example of the syntax, not a link the reader can follow.
BODY_ANCHOR_LINK = re.compile(r"\[[^\]]*\]\(\s*#([^)\s]+)\s*\)")
CODE_SPAN = re.compile(r"``[^`]*``|`[^`]*`")

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

    This is the slug *before* disambiguation. A document may head two sections
    identically, and GitHub gives the second ``-1``; see :func:`anchors_of`,
    which is what a whole-document walk has to use.
    """
    text = html.unescape(text).lower()
    text = re.sub(r"[^a-z0-9 _-]", "", text)
    return text.replace(" ", "-")


def anchors_of(headings: Iterable[str]) -> list[str]:
    """The fragments [headings] define, in document order, disambiguated.

    A repeated heading does not overwrite the first one's fragment: GitHub
    appends ``-1``, ``-2``, … in the order the headings appear, so the second
    ``### Failure keys`` in a document is reachable only as ``#failure-keys-1``.
    Without this the second section reads as unlisted however carefully its
    entry is written, and the entry that *is* correct reads as stale — the
    check accusing the document of two faults it does not have.

    The count runs over every heading it is given, so a caller passing only the
    levels it cares about would shift every suffix after a skipped one. Pass
    them all.
    """
    seen: dict[str, int] = {}
    out: list[str] = []
    for heading in headings:
        base = anchor(heading)
        ordinal = seen.get(base, 0)
        seen[base] = ordinal + 1
        out.append(base if ordinal == 0 else f"{base}-{ordinal}")
    return out


class Report:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.missing: list[tuple[int, str]] = []
        self.stale: list[tuple[str, str]] = []
        self.order: tuple[list[str], list[str]] | None = None
        self.dangling: list[tuple[int, str]] = []
        self.has_toc = False

    @property
    def clean(self) -> bool:
        return not (self.missing or self.stale or self.order or self.dangling)

    def render(self) -> str:
        lines = [f"{self.path.relative_to(REPO_ROOT)}"]
        for line_no, text in self.missing:
            lines.append(f"    MISSING  :{line_no:<5} {text}")
        for text, target in self.stale:
            lines.append(f"    STALE          [{text}](#{target})")
        for line_no, target in self.dangling:
            lines.append(f"    DANGLING :{line_no:<5} #{target}")
        if self.order:
            doc_order, toc_order = self.order
            lines.append("    ORDER    document: " + " ".join(doc_order))
            lines.append("    ORDER    contents: " + " ".join(toc_order))
        return "\n".join(lines)


def audit(path: Path) -> Report:
    """Audit one document's contents block and its own-document anchors.

    Always returns a Report: a file with no table of contents still has
    anchors, and a link into a heading that was later reworded goes nowhere
    whether or not the document indexes itself.
    """
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()

    toc_start = next((i for i, l in enumerate(lines) if TOC_HEADING.match(l)), None)
    toc_end = len(lines)
    if toc_start is not None:
        for i in range(toc_start + 1, len(lines)):
            if lines[i].startswith("## "):
                toc_end = i
                break

    entries: list[tuple[str, str]] = []  # (label, target)
    if toc_start is not None:
        for line in lines[toc_start + 1:toc_end]:
            match = TOC_ENTRY.match(line)
            if match:
                entries.append((match.group(2), match.group(3)))

    # `headings` holds every level, because an entry pointing at an `####` is a
    # perfectly good link and staleness must be judged against the whole file.
    # `listable` is the subset a ToC can fairly be held to: only `##`. A ToC
    # that indents a few subsections is not promising to list them all, so
    # holding it to every `###` manufactures defects instead of finding them.
    headings: list[tuple[int, str]] = []
    listable: list[tuple[int, str]] = []
    body_links: list[tuple[int, str]] = []
    in_fence = False
    for i, line in enumerate(lines):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue

        # Links inside the contents block are judged as entries, below; a link
        # anywhere else is prose the reader is invited to follow.
        if toc_start is None or not (toc_start <= i < toc_end):
            prose = CODE_SPAN.sub(lambda m: " " * len(m.group()), line)
            body_links += [(i + 1, a) for a in BODY_ANCHOR_LINK.findall(prose)]

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
    # Disambiguated over the whole document, so a heading that repeats is
    # judged by the fragment it actually defines rather than by the first
    # section's. Keyed by line, because `listable` is a subset of `headings`
    # and the two have to agree about which occurrence each one is.
    slugs = anchors_of(text for _, text in headings)
    assert len(slugs) == len(headings)
    resolved = {n: slug for (n, _), slug in zip(headings, slugs)}
    heading_anchors = set(resolved.values())
    targets = {target.lower() for _, target in entries}

    report = Report(path)
    report.has_toc = bool(entries)
    report.dangling = [
        (n, a) for n, a in body_links if a.lower() not in heading_anchors
    ]
    if not entries:
        return report

    report.missing = [(n, t) for n, t in listable if resolved[n] not in targets]
    report.stale = [(l, t) for l, t in entries if t.lower() not in heading_anchors]

    doc_order = [resolved[n] for n, _ in headings if resolved[n] in targets]
    toc_order = [t.lower() for _, t in entries if t.lower() in heading_anchors]
    if doc_order != toc_order:
        report.order = (doc_order, toc_order)

    return report


def main(argv: list[str]) -> int:
    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    scanned = 0
    checked = 0
    defective: list[Report] = []
    for path in sorted(root.rglob("*.md")):
        if SKIP_DIRS & set(path.parts):
            continue
        report = audit(path)
        scanned += 1
        checked += report.has_toc
        if not report.clean:
            defective.append(report)

    for report in defective:
        print(report.render())

    missing = sum(len(r.missing) for r in defective)
    stale = sum(len(r.stale) for r in defective)
    order = sum(1 for r in defective if r.order)
    dangling = sum(len(r.dangling) for r in defective)

    print()
    print(f"documents scanned                  : {scanned}")
    print(f"documents with a table of contents : {checked}")
    print(f"documents defective                : {len(defective)}")
    print(f"  unlisted sections                : {missing}")
    print(f"  contents links to no heading     : {stale}")
    print(f"  contents out of document order   : {order}")
    print(f"  body links to no heading         : {dangling}")
    return report_faults(missing + stale + order + dangling)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
