#!/usr/bin/env python3
"""Hold each open-ends section to the quest todos filed against its unit.

Run from anywhere::

    python3 tool/check_open_ends_ledger.py            # the report
    python3 tool/check_open_ends_ledger.py --quiet    # findings only
    python3 tool/check_open_ends_ledger.py --self-test  # perturb and require detection

Exits non-zero per [gate_report.report_faults], so ``check_gates.py`` holds the
outstanding number to a baseline.

**What this asks that ``check_open_ends.py`` does not.** That gate asks whether
the section is *there*. This one asks whether it is *true*. A section is written
once, when the unit is assessed, and every todo filed against that unit
afterwards is a fact about it the section does not know. Nothing connected the
two, so a section could go on saying "nothing is open" while three todos sat
open on the same unit -- which is not a hypothetical: the ``mcp_auth`` section
said exactly that, one turn after it was written, with ``tcopen346``,
``tcopen347`` and ``tcopen348`` filed and unworked.

The join is exact rather than heuristic. A completion document is named
``<project>_<module>_{new,changes}.md`` and a todo carries ``scope.project`` and
``scope.module``, so a document and a todo meet on one equality. Nothing here
reads prose to decide what a document is about.

**Two faults.**

``UNNAMED``
    A todo is open on the unit and the section never names it. The contract in
    ``completion/README.md`` already requires an item to name its tracking todo;
    this is the other direction -- the todo exists and the item does not.

``PHANTOM``
    The section names an id the corpus does not contain. A renamed or
    hand-typed id resolves to nothing, and a reader cannot tell that from a
    todo they lack permission to see.

**What an item says about its todos is ``check_open_lists.py``'s question.**
That gate reads the items: an open item must name an unfinished todo, a closed
one a finished todo. A closed item may also name an unfinished todo -- a finding
that MOVED rather than ended, as this unit's own reference-link item does,
closed here and still open in two other pages -- so the rule there is that the
finished one is named too, not that no unfinished one is.

**A todo about the document is not an item in it.** ``tcopen345`` asks for this
very section to be written; a section naming it would be reporting itself as an
open end forever. So a todo whose ``scope.files`` names the completion document
is out of scope for that document -- a rule about what the todo is *about*,
rather than an exemption list, so the next one is handled without an edit here.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent
QUEST = REPO_ROOT.parent.parent / "_ai" / "quests" / "tom_core"
DOCS_ROOT = QUEST / "completion"
CORPUS = ("todos.tom_core.todo.yaml", "todos-archived.tom_core.todo.yaml")

NOT_A_MODULE_DOCUMENT = {"README.md", "tom_core_completion_overview.md"}

HEADING = re.compile(r"^### What is still open\s*$", re.M)
NEXT_HEADING = re.compile(r"^#{1,6}\s", re.M)

#: The stem of a todo id -- the part before the date code, which is what prose
#: cites when it writes `tcopen346_ahku` or bare `tcopen346`. Both families the
#: corpus holds count: the `tc…` review todos and the `csex…` CodeSpecs ones.
STEM = re.compile(r"\b((?:tc|csex)[a-z]*\d+)")

SUFFIXES = ("_new", "_changes")


def unit_of(stem: str) -> str:
    for suffix in SUFFIXES:
        if stem.endswith(suffix):
            return stem[: -len(suffix)]
    return stem


def todos() -> list[dict]:
    out: list[dict] = []
    for name in CORPUS:
        path = QUEST / name
        if path.is_file():
            out.extend(yaml.safe_load(path.read_text(encoding="utf8"))["todos"])
    return out


def section_of(text: str) -> str | None:
    match = HEADING.search(text)
    if match is None:
        return None
    rest = text[match.end():]
    following = NEXT_HEADING.search(rest)
    return rest[: following.start()] if following else rest


def documents() -> list[Path]:
    return sorted(
        p for p in DOCS_ROOT.glob("*.md") if p.name not in NOT_A_MODULE_DOCUMENT
    )


def audit(extra: list[dict] | None = None) -> tuple[list[str], int]:
    """Faults across every documented section, and how many sections were read.

    [extra] joins the corpus for this one call -- the self-test's way of
    planting an open todo without depending on one staying open in the real
    corpus, which is what broke the check the first time the todo it borrowed
    was completed.
    """
    faults: list[str] = []
    every = todos() + (extra or [])
    known = {STEM.match(t["id"]).group(1) for t in every if STEM.match(t["id"])}
    audited = 0
    for document in documents():
        section = section_of(document.read_text(encoding="utf8"))
        if section is None:
            continue
        audited += 1
        named = set(STEM.findall(section))
        unit = unit_of(document.stem)

        for stem in sorted(named - known):
            faults.append(f"PHANTOM {document.name}  {stem} is in no todo file")

        for todo in every:
            scope = todo.get("scope") or {}
            project, module = scope.get("project"), scope.get("module")
            if not project or not module or f"{project}_{module}" != unit:
                continue
            if todo["status"] == "completed":
                continue
            if any(
                document.name in str(f) for f in (scope.get("files") or [])
            ):
                continue
            match = STEM.match(todo["id"])
            if match and match.group(1) not in named:
                faults.append(
                    f"UNNAMED {document.name}  {todo['id']} is "
                    f"{todo['status']} and the section never names it"
                )

    return faults, audited


def self_test() -> int:
    """Plant each fault in a real section and require it to be reported."""
    subject = DOCS_ROOT / "tom_core_agentic_mcp_auth_changes.md"
    original = subject.read_text(encoding="utf8")
    # An open todo on the subject's unit that its section does not name. Planted
    # rather than borrowed from the corpus, so the check keeps meaning something
    # after every real todo on the unit has been completed.
    planted = {
        "id": "tcopen9998_zzzz_planted-by-the-self-test",
        "status": "not-started",
        "scope": {"project": "tom_core_agentic", "module": "mcp_auth"},
    }
    checks = [
        (
            # A todo id in the section that names no todo in the corpus.
            # Inserted rather than made by renaming an id the section already
            # carries, so the check does not depend on what the section says.
            "PHANTOM",
            lambda t: t.replace(
                "### What is still open\n",
                "### What is still open\n\nTracked by `tcopen9999_zzzz`.\n",
                1,
            ),
            None,
        ),
        ("UNNAMED", lambda t: t, [planted]),
    ]
    failures = 0
    try:
        for label, mutate, extra in checks:
            subject.write_text(mutate(original), encoding="utf8")
            faults, _ = audit(extra)
            hit = any(f.startswith(label) for f in faults)
            print(f"{'ok  ' if hit else 'FAIL'} {label} reported when planted")
            failures += 0 if hit else 1
    finally:
        subject.write_text(original, encoding="utf8")
    faults, _ = audit()
    print(f"restored: {len(faults)} fault(s)")
    return failures


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return 1 if self_test() else 0
    if not DOCS_ROOT.is_dir():
        print(f"completion documents not found at {DOCS_ROOT}", file=sys.stderr)
        return 2

    faults, audited = audit()
    for fault in faults:
        print(fault)

    if "--quiet" not in argv:
        print()
        print(f"documents with a section : {audited}")
        print(f"todos in the corpus      : {len(todos())}")
        print(f"sections out of step     : "
              f"{len({f.split()[1] for f in faults})}")

    return report_faults(len(faults))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
