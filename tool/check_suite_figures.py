#!/usr/bin/env python3
"""Hold the sample suite's figures and their embed sites to their convention.

Run from anywhere::

    python3 tool/check_suite_figures.py              # the audit
    python3 tool/check_suite_figures.py --self-test  # plant each fault, require it

Exits non-zero per [gate_report.report_faults], so ``check_gates.py`` holds the
count to its baseline.

**What it guards.** ``tom_core_samples/assets/architecture/`` holds the advanced
sample's figures, and ``tom_core_samples/assets/README.md`` states the rules
they follow. Nothing read either: a tenth figure could be added and never
embedded, an embed could name a file that was renamed, and the inventory could
miss a figure - each passing silently, because a markdown renderer shows a
broken image as a blank and a missing row as nothing at all. The rules are
facts about files, so they are checked as facts:

``ORPHAN``
    An SVG in ``assets/architecture/`` that no document under
    ``tom_core_samples/`` embeds.
``DANGLING``
    An embed whose ``assets/architecture/...`` path resolves to no file.
``INVENTORY``
    The figure table in ``assets/README.md`` disagrees with the tree: a figure
    with no row, a row for a figure that does not exist, or a row whose
    "Embedded by" links are not exactly the documents that embed it.
``SITE``
    An embed site missing one of its three parts: the ``<!-- Figure: ... -->``
    comment directly above the image, and the
    ``<details><summary>Text / mermaid equivalent</summary>`` disclosure
    directly below it.
``ALT``
    Alt text that is a label rather than a sentence - under six words, or not
    ending in a full stop. The alt text is what a screen reader and a text-only
    reading get instead of the figure.
``SVG``
    A figure without a ``viewBox``, or whose first element after ``<svg>`` is
    not the HTML comment describing it.

**What it does not guard, and who does.** Whether an SVG parses is
[check_figure_wellformed]'s question, and a line number cited inside a figure's
comment is [check_source_citations]'s. What the code a figure names still
*does* is not checked by anything, deliberately: matching prose citations with a
regex would be more fragile than the citations, and naming a file and symbol
rather than a line is what keeps them honest.

Fenced blocks and inline code spans are skipped, so the README's own recipe -
which shows the embed shape as code - is not read as an embed.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

from gate_report import report_faults

SUITE = Path(__file__).resolve().parent.parent / "tom_core_samples"
FIGURES = SUITE / "assets" / "architecture"
INVENTORY = SUITE / "assets" / "README.md"

SKIP_DIRS = {"build", ".dart_tool", "node_modules", ".git"}
# Alt text may hold balanced brackets (`projectRoleFieldGrades[role]` in A1's
# figure), which CommonMark allows in link text; one level of nesting is enough.
EMBED = re.compile(
    r"!\[((?:[^\[\]]|\[[^\[\]]*\])*)\]\(([^)\s]*assets/architecture/[^)\s]+)\)"
)
FENCE = re.compile(r"^```.*?^```", re.S | re.M)
INLINE_CODE = re.compile(r"`[^`\n]*`")
DISCLOSURE = "<details><summary>Text / mermaid equivalent</summary>"
ROW = re.compile(r"^\|\s*`([a-z0-9_]+)`\s*\|(.*)\|\s*$", re.M)
LINK_TARGET = re.compile(r"\]\(([^)#\s]+)")


def blank_code(text: str) -> str:
    """[text] with fenced blocks and inline code replaced by spaces, keeping
    every offset and line break where it was."""
    keep_lines = lambda m: re.sub(r"[^\n]", " ", m.group(0))
    return INLINE_CODE.sub(keep_lines, FENCE.sub(keep_lines, text))


def documents() -> list[Path]:
    return sorted(
        p for p in SUITE.rglob("*.md")
        if not SKIP_DIRS & set(p.relative_to(SUITE).parts)
    )


def figures() -> list[Path]:
    return sorted(FIGURES.glob("*.svg"))


def embeds() -> list[tuple[Path, int, str, Path, str, str]]:
    """Every embed: document, line, alt text, resolved target, and the text
    immediately before and after it in the document."""
    found = []
    for doc in documents():
        raw = doc.read_text(encoding="utf8")
        text = blank_code(raw)
        for m in EMBED.finditer(text):
            target = (doc.parent / m.group(2)).resolve()
            line = text.count("\n", 0, m.start()) + 1
            found.append((doc, line, m.group(1), target,
                          raw[:m.start()].rstrip(), raw[m.end():].lstrip()))
    return found


def rel(path: Path) -> str:
    return str(path.relative_to(SUITE.parent))


def audit() -> list[str]:
    faults: list[str] = []
    sites = embeds()
    embedded_by: dict[Path, set[Path]] = {}

    for doc, line, alt, target, before, after in sites:
        where = f"{rel(doc)}:{line}"
        if not target.is_file():
            faults.append(f"DANGLING {where} embeds {target.name}, which does not exist")
            continue
        embedded_by.setdefault(target, set()).add(doc.resolve())
        last_comment = before.rfind("<!--")
        if not (before.endswith("-->") and
                before[last_comment:].startswith("<!-- Figure")):
            faults.append(f"SITE {where} {target.name} has no <!-- Figure: ... --> comment directly above it")
        if not after.startswith(DISCLOSURE):
            faults.append(f"SITE {where} {target.name} is not followed by the Text / mermaid equivalent disclosure")
        words = alt.split()
        if len(words) < 6 or not alt.rstrip().endswith("."):
            faults.append(f"ALT {where} {target.name} alt text is a label, not a sentence: {alt!r}")

    for svg in figures():
        if svg.resolve() not in embedded_by:
            faults.append(f"ORPHAN {rel(svg)} is embedded by no document")
        source = svg.read_text(encoding="utf8")
        if "viewBox=" not in source.split(">", 1)[0]:
            faults.append(f"SVG {rel(svg)} has no viewBox on its <svg> element")
        body = source.split(">", 1)[1].lstrip() if ">" in source else ""
        if not body.startswith("<!--"):
            faults.append(f"SVG {rel(svg)} does not open with its describing comment")

    faults += inventory_faults(embedded_by)
    return faults


def inventory_faults(embedded_by: dict[Path, set[Path]]) -> list[str]:
    if not INVENTORY.is_file():
        return [f"INVENTORY {rel(INVENTORY)} is missing"]
    text = INVENTORY.read_text(encoding="utf8")
    rows = {m.group(1): m.group(2) for m in ROW.finditer(text)
            if m.group(1).startswith("advanced_")}
    faults = []
    stems = {svg.stem: svg.resolve() for svg in figures()}
    for stem in sorted(set(stems) - set(rows)):
        faults.append(f"INVENTORY {stem} has no row in {rel(INVENTORY)}")
    for stem in sorted(set(rows) - set(stems)):
        faults.append(f"INVENTORY {rel(INVENTORY)} lists {stem}, which is not in assets/architecture/")
    for stem in sorted(set(rows) & set(stems)):
        listed = {(INVENTORY.parent / t).resolve()
                  for t in LINK_TARGET.findall(rows[stem])}
        actual = embedded_by.get(stems[stem], set())
        if listed != actual:
            names = lambda paths: sorted(p.name for p in paths) or ["nothing"]
            faults.append(
                f"INVENTORY {stem} says it is embedded by {names(listed)}; "
                f"it is embedded by {names(actual)}"
            )
    return faults


def self_test() -> int:
    """Plant each fault in the real files and require it to be reported."""
    chapter = SUITE / "README_advanced_01_architecture.md"
    figure = FIGURES / "advanced_02_jwt_shared_key.svg"
    orphan = FIGURES / "advanced_99_self_test_orphan.svg"
    originals = {p: p.read_text(encoding="utf8") for p in (chapter, figure, INVENTORY)}

    def edit(path: Path, old: str, new: str) -> None:
        text = originals[path]
        assert old in text, f"self-test anchor missing in {path.name}: {old!r}"
        path.write_text(text.replace(old, new, 1), encoding="utf8")

    plants = [
        ("DANGLING", lambda: edit(chapter, "advanced_06_token_refresh.svg", "advanced_06_token_refreshed.svg")),
        ("ORPHAN", lambda: orphan.write_text('<svg viewBox="0 0 1 1">\n  <!-- x -->\n</svg>\n', encoding="utf8")),
        ("INVENTORY", lambda: edit(INVENTORY, "| `advanced_08_domain_ownership` |", "| `advanced_08_domain_owner` |")),
        ("SITE", lambda: edit(chapter, DISCLOSURE, "<details><summary>Mermaid</summary>")),
        ("ALT", lambda: edit(chapter, "![Token refresh:", "![Token refresh.](assets/architecture/advanced_06_token_refresh.svg) ![Token refresh:")),
        ("SVG", lambda: edit(figure, 'viewBox="', 'data-box="')),
    ]
    failures = 0
    try:
        for label, plant in plants:
            plant()
            hit = any(f.startswith(label) for f in audit())
            print(f"{'ok  ' if hit else 'FAIL'} {label} reported when planted")
            failures += 0 if hit else 1
            for path, text in originals.items():
                path.write_text(text, encoding="utf8")
            orphan.unlink(missing_ok=True)
    finally:
        for path, text in originals.items():
            path.write_text(text, encoding="utf8")
        orphan.unlink(missing_ok=True)
    print(f"restored: {len(audit())} fault(s)")
    return failures


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return 1 if self_test() else 0
    faults = audit()
    for fault in faults:
        print(fault)
    if "--quiet" not in argv:
        print()
        print(f"figures      : {len(figures())}")
        print(f"embed sites  : {len(embeds())}")
        print(f"documents    : {len(documents())}")
    return report_faults(len(faults))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
