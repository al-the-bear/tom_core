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

Five faults are reported, and the third is the one worth keeping:

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
``CROSS``
    A link ``other.md#fragment`` into *another* document whose fragment that
    document does not define. ``check_doc_links`` verifies only that
    ``other.md`` exists, so before this rule a renamed heading silently broke
    every link from elsewhere that targeted it -- the cheapest link to break,
    because nothing in the edited file shows that anything points at it. A
    target that is not on disk is left to ``check_doc_links`` (``DEAD``), so the
    two gates never report one link twice.

**What a fragment may name.** A heading's slug (see ``anchor``) or an explicit
HTML anchor, ``<a id="...">`` or ``<a name="...">``. The explicit form is how a
document gives a stable name to a place no heading marks -- or keeps an old
fragment alive across a heading rename -- so accepting it is reading markdown
correctly, not an exemption. It counts for in-document links too.

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
from urllib.parse import unquote

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

#: ``<a id="x">`` / ``<a name="x">`` -- a fragment defined without a heading.
EXPLICIT_ANCHOR = re.compile(
    r"""<a\s+(?:[^>]*?\s)?(?:id|name)\s*=\s*["']([^"']+)["']""", re.I)

#: An inline link to another markdown document *with* a fragment. The path part
#: must end in ``.md`` and may be wrapped in ``<...>``, markdown's escape for a
#: target containing spaces; a title after the target is allowed and ignored.
CROSS_LINK = re.compile(
    r"\[[^\]]*\]\(\s*<?([^)\s<>#]*?\.md)#([^)\s<>]+?)>?"
    r"(?:\s+\"[^\"]*\")?\s*\)")

#: A scheme or ``//`` -- a link a browser resolves and this gate does not.
EXTERNAL = re.compile(r"^(?:[a-z][a-z0-9+.-]*:|//)", re.I)


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


def defined_fragments(text: str) -> set[str]:
    """Every fragment [text] defines: its heading slugs and explicit anchors.

    Lower-cased, as every comparison in this gate is. Fenced blocks define
    nothing -- a ``## Heading`` inside a code sample is an example, and so is an
    ``<a id>`` -- so they are skipped exactly as the audit skips them.
    """
    headings: list[str] = []
    explicit: list[str] = []
    in_fence = False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        match = HEADING.match(line)
        if match:
            headings.append(match.group(2))
        explicit += EXPLICIT_ANCHOR.findall(line)
    return {a.lower() for a in anchors_of(headings)} | {
        a.lower() for a in explicit}


def cross_links(lines: list[str]) -> list[tuple[int, str, str]]:
    """``(line, path, fragment)`` for every link into another document's anchor.

    Code is blanked first for the reason [BODY_ANCHOR_LINK] gives: a link shown
    as syntax is not a link a reader follows.
    """
    out: list[tuple[int, str, str]] = []
    in_fence = False
    for i, line in enumerate(lines):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        prose = CODE_SPAN.sub(lambda m: " " * len(m.group()), line)
        for path, fragment in CROSS_LINK.findall(prose):
            if not EXTERNAL.match(path):
                out.append((i + 1, path, fragment))
    return out


_FRAGMENTS: dict[Path, set[str]] = {}


def fragments_of(path: Path) -> set[str]:
    """[defined_fragments] of the document at [path], read once per run."""
    key = path.resolve()
    if key not in _FRAGMENTS:
        _FRAGMENTS[key] = defined_fragments(
            key.read_text(encoding="utf-8", errors="replace"))
    return _FRAGMENTS[key]


def cross_faults(source: Path, lines: list[str], fragments=fragments_of,
                 exists=Path.is_file) -> list[tuple[int, str]]:
    """``(line, target)`` for each cross-document link whose fragment is unknown.

    [fragments] and [exists] are injectable so the self-test can resolve
    against documents held in memory. A link whose file does not exist is skipped: that is
    ``check_doc_links``'s ``DEAD``, and reporting it here too would count one
    broken link twice.
    """
    faults: list[tuple[int, str]] = []
    for number, target, fragment in cross_links(lines):
        destination = source.parent / unquote(target)
        if not exists(destination):
            continue
        if unquote(fragment).lower() not in fragments(destination):
            faults.append((number, f"{target}#{fragment}"))
    return faults


class Report:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.missing: list[tuple[int, str]] = []
        self.stale: list[tuple[str, str]] = []
        self.order: tuple[list[str], list[str]] | None = None
        self.dangling: list[tuple[int, str]] = []
        self.cross: list[tuple[int, str]] = []
        self.has_toc = False

    @property
    def clean(self) -> bool:
        return not (self.missing or self.stale or self.order or self.dangling
                    or self.cross)

    def render(self) -> str:
        lines = [f"{self.path.relative_to(REPO_ROOT)}"]
        for line_no, text in self.missing:
            lines.append(f"    MISSING  :{line_no:<5} {text}")
        for text, target in self.stale:
            lines.append(f"    STALE          [{text}](#{target})")
        for line_no, target in self.dangling:
            lines.append(f"    DANGLING :{line_no:<5} #{target}")
        for line_no, target in self.cross:
            lines.append(f"    CROSS    :{line_no:<5} {target}")
        if self.order:
            doc_order, toc_order = self.order
            lines.append("    ORDER    document: " + " ".join(doc_order))
            lines.append("    ORDER    contents: " + " ".join(toc_order))
        return "\n".join(lines)


def audit(path: Path, fragments=fragments_of) -> Report:
    """Audit one document's contents block and its own-document anchors.

    Always returns a Report: a file with no table of contents still has
    anchors, and a link into a heading that was later reworded goes nowhere
    whether or not the document indexes itself.
    """
    document = path.read_text(encoding="utf-8", errors="replace")
    lines = document.splitlines()

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
    heading_anchors = {slug.lower() for slug in resolved.values()}
    # A body link may also land on an explicit `<a id>`; a contents entry is
    # still judged against headings alone, since it indexes sections.
    body_anchors = heading_anchors | defined_fragments(document)
    targets = {target.lower() for _, target in entries}

    report = Report(path)
    report.has_toc = bool(entries)
    report.dangling = [
        (n, a) for n, a in body_links if unquote(a).lower() not in body_anchors
    ]
    report.cross = cross_faults(path, lines, fragments)
    if not entries:
        return report

    report.missing = [(n, t) for n, t in listable if resolved[n] not in targets]
    report.stale = [(l, t) for l, t in entries if t.lower() not in heading_anchors]

    doc_order = [resolved[n] for n, _ in headings if resolved[n] in targets]
    toc_order = [t.lower() for _, t in entries if t.lower() in heading_anchors]
    if doc_order != toc_order:
        report.order = (doc_order, toc_order)

    return report


def self_test() -> int:
    """Plant each kind of cross-document fragment and require the verdict.

    Two documents are held in memory, so the rule is exercised without a file
    being written; the last case damages a real cross-document link in this
    repository, so a rule that silently stopped matching real links -- a regex
    the corpus's link shape no longer fits -- fails here rather than reading as
    a clean repo.
    """
    target = "\n".join([
        "# Guide",
        "## Layering and dependency arrows",
        '<a id="a-green-run"></a>',
        "Text.",
        "## Repeated",
        "## Repeated",
        "```",
        "## Not a heading",
        '<a id="not-an-anchor"></a>',
        "```",
    ])
    held = {"guide.md": defined_fragments(target)}

    def fragments(path: Path) -> set[str]:
        return held[path.name]

    def exists(path: Path) -> bool:
        return path.name in held

    source = REPO_ROOT / "tool" / "zz_self_test_source.md"
    cases = [
        ("a heading slug", "[x](guide.md#layering-and-dependency-arrows)",
         False),
        ("a misspelled heading slug",
         "[x](guide.md#layering-and-dependancy-arrows)", True),
        ("an explicit <a id>", "[x](guide.md#a-green-run)", False),
        ("a disambiguated repeat", "[x](guide.md#repeated-1)", False),
        ("a heading inside a fence", "[x](guide.md#not-a-heading)", True),
        ("an <a id> inside a fence", "[x](guide.md#not-an-anchor)", True),
        ("a fragment in a code span", "`[x](guide.md#nowhere)`", False),
        ("a missing document, left to check_doc_links",
         "[x](absent.md#nowhere)", False),
        ("an external link", "[x](https://example.com/a.md#nowhere)",
         False),
    ]
    failures = []
    for name, line, faulty in cases:
        found = bool(cross_faults(source, [line], fragments, exists))
        if found != faulty:
            failures.append(f"{name}: expected "
                            f"{'a fault' if faulty else 'none'}, got "
                            f"{'a fault' if found else 'none'}")

    # The real corpus: the first cross-document anchor link that resolves must
    # stop resolving once its fragment is misspelled.
    real = None
    for path in sorted(REPO_ROOT.rglob("*.md")):
        if SKIP_DIRS & set(path.parts):
            continue
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        for number, link, fragment in cross_links(lines):
            if (path.parent / unquote(link)).is_file() and not cross_faults(
                    path, [lines[number - 1]]):
                real = (path, lines[number - 1], f"{link}#{fragment}")
                break
        if real:
            break
    if real is None:
        failures.append("no resolving cross-document anchor link in the repo "
                        "-- the link pattern matches nothing real")
    else:
        path, line, link = real
        damaged = line.replace(link, link + "-misspelled", 1)
        if not cross_faults(path, [damaged]):
            failures.append(f"misspelling {link} in "
                            f"{path.relative_to(REPO_ROOT)} went unreported")
        # And an in-document link may land on an explicit anchor.
        if audit_text_dangling("[x](#a-green-run)\n" + target):
            failures.append("an in-document link to an explicit <a id> was "
                            "reported as dangling")

    for failure in failures:
        print(f"self-test: {failure}")
    if failures:
        return 1
    print("self-test: heading slugs, explicit anchors, fences, code spans, "
          "missing and external targets, and a damaged real link all read as "
          "expected")
    return 0


def audit_text_dangling(text: str) -> list[tuple[int, str]]:
    """The DANGLING findings for [text], audited from a path that holds it."""
    path = REPO_ROOT / "tool" / "zz_self_test_doc.md"
    original = Path.read_text
    Path.read_text = lambda self, *a, **k: (
        text if self == path else original(self, *a, **k))
    try:
        return audit(path, fragments=lambda _: set()).dangling
    finally:
        Path.read_text = original


def main(argv: list[str]) -> int:
    if argv == ["--self-test"]:
        return self_test()
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
    cross = sum(len(r.cross) for r in defective)

    print()
    print(f"documents scanned                  : {scanned}")
    print(f"documents with a table of contents : {checked}")
    print(f"documents defective                : {len(defective)}")
    print(f"  unlisted sections                : {missing}")
    print(f"  contents links to no heading     : {stale}")
    print(f"  contents out of document order   : {order}")
    print(f"  body links to no heading         : {dangling}")
    print(f"  links to another document's      : {cross}")
    print(f"    fragment it does not define")
    return report_faults(missing + stale + order + dangling + cross)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
