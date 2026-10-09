#!/usr/bin/env python3
"""Hold every item of an open-ends list to the todo it names.

Run from anywhere::

    python3 tool/check_open_lists.py              # the report
    python3 tool/check_open_lists.py --quiet      # findings only
    python3 tool/check_open_lists.py --self-test  # perturb and require detection

Exits non-zero per [gate_report.report_faults], so ``check_gates.py`` holds the
outstanding number to a baseline.

**What this asks that its two neighbours do not.** ``check_open_ends.py`` asks
whether a completion document *has* a ``### What is still open`` section, and
``check_open_ends_ledger.py`` asks whether every unfinished todo on the unit is
*named* in it. Neither reads the items. An item can say a thing is open while
the todo it cites was completed months ago -- the case that prompted this gate:
the configuration section listed an optional YAML load as open, "tracked as" a
todo long since completed, in a document whose own part 1 tabulated the two
methods that closed it. Nothing noticed.

**The convention it reads** (``completion/README.md``):

- An item is a list item at the left margin of the section -- ``-``, ``*`` or
  ``1.`` -- together with its indented continuation lines.
- An item marked ``**Closed**`` reports something that has ended. It must still
  name the todo that closed it, so a reader can see where it went.
- Every other item is open, and names the todo that tracks it.

A todo id is cited by its stem (``tcopen346``) or in full
(``tcopen346_ahku``); the stem is what is matched. Both families the quest's
corpus holds are stems: the ``tc…`` review todos and the ``csex…`` CodeSpecs
extension todos that built several of the modules. A todo is *finished* when it
is ``completed`` or ``cancelled``, or when it sits only in the archived or
deleted files; anything else is *unfinished*.

**Four faults.**

``UNTRACKED``
    An open item names no todo the corpus contains. Prose alone gives a reader
    nothing to check the item against.

``STALE``
    An open item names todos, and every one of them is finished. Either the
    item has closed and should say so, or it needs the todo that tracks what is
    left.

``CLOSED-UNTRACKED``
    A ``**Closed**`` item names no todo the corpus contains.

``CLOSED-UNFINISHED``
    A ``**Closed**`` item names todos and none of them is finished. A closed
    item may *also* name an unfinished todo -- a finding that moved rather than
    ended points at where it went -- but it must name the finished one that
    closed it here.

An id the corpus does not contain at all is ``check_open_ends_ledger.py``'s
PHANTOM and is not reported twice; here it simply does not count as tracking.

**What no id check can do.** An open end written as a paragraph rather than as
an item is invisible to this gate, exactly as the convention says it is
invisible to a reader who wants to check it. The rule is to write it as an item.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

import yaml

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent
QUEST = REPO_ROOT.parent.parent / "_ai" / "quests" / "tom_core"
DOCS_ROOT = QUEST / "completion"

#: The live file, whose todos carry their own status, and the two terminal
#: files, every entry of which is finished by being there.
LIVE = "todos.tom_core.todo.yaml"
TERMINAL = ("todos-archived.tom_core.todo.yaml", "todos-deleted.tom_core.todo.yaml")

NOT_A_MODULE_DOCUMENT = {"README.md", "tom_core_completion_overview.md"}

HEADING = re.compile(r"^### What is still open\s*$", re.M)
NEXT_HEADING = re.compile(r"^#{1,6}\s", re.M)

#: A list item at the left margin.
ITEM_START = re.compile(r"^(?:[-*]|\d+\.)\s")

#: The stem of a todo id, as prose cites it — a ``tc…`` or a ``csex…`` todo.
STEM = re.compile(r"\b((?:tc|csex)[a-z]*\d+)")

#: The closed marker. Bold, so it reads as a verdict rather than as a word in
#: a sentence that happens to say "closed".
CLOSED = re.compile(r"\*\*Closed\b")

FINISHED_STATUSES = {"completed", "cancelled"}


@dataclass
class Item:
    document: str
    line: int
    text: str

    @property
    def closed(self) -> bool:
        return bool(CLOSED.search(self.text))

    @property
    def stems(self) -> list[str]:
        return STEM.findall(self.text)

    @property
    def head(self) -> str:
        first = self.text.strip().splitlines()[0]
        return first if len(first) <= 72 else first[:69] + "..."


def _load(path: Path) -> list[dict]:
    # The archive runs to hundreds of thousands of lines; the C loader is the
    # difference between a gate that answers and one that times out.
    loader = getattr(yaml, "CSafeLoader", yaml.SafeLoader)
    return yaml.load(path.read_text(encoding="utf8"), Loader=loader)["todos"] or []


@lru_cache(maxsize=1)
def corpus() -> dict[str, bool]:
    """Every todo stem, mapped to whether it is finished. Read once per run."""
    finished: dict[str, bool] = {}
    for name in TERMINAL:
        path = QUEST / name
        if path.is_file():
            for todo in _load(path):
                match = STEM.match(todo["id"])
                if match:
                    finished[match.group(1)] = True
    path = QUEST / LIVE
    for todo in _load(path):
        match = STEM.match(todo["id"])
        if match:
            # A live entry decides by its status. A stem reused by a live
            # unfinished todo is unfinished, whatever the archive holds.
            done = todo.get("status") in FINISHED_STATUSES
            finished[match.group(1)] = finished.get(match.group(1), True) and done
    return finished


def items_of(document: Path, text: str) -> list[Item]:
    """The items of the section in [text], each with its continuation lines."""
    heading = HEADING.search(text)
    if heading is None:
        return []
    start_line = text.count("\n", 0, heading.end()) + 1
    rest = text[heading.end():]
    following = NEXT_HEADING.search(rest)
    body = rest[: following.start()] if following else rest

    items: list[Item] = []
    current: list[str] | None = None
    current_line = 0
    pending_blank = False
    for offset, line in enumerate(body.split("\n")):
        if ITEM_START.match(line):
            if current is not None:
                items.append(Item(document.name, current_line, "\n".join(current)))
            current, current_line, pending_blank = [line], start_line + offset, False
        elif current is None:
            continue
        elif not line.strip():
            pending_blank = True
        elif line[0].isspace():
            current.append(line)
            pending_blank = False
        else:
            # A paragraph at the margin ends the list -- after a blank line it
            # is prose about the list, not a continuation of the last item.
            items.append(Item(document.name, current_line, "\n".join(current)))
            current = None
    if current is not None:
        items.append(Item(document.name, current_line, "\n".join(current)))
    return items


def documents() -> list[Path]:
    return sorted(
        p for p in DOCS_ROOT.glob("*.md") if p.name not in NOT_A_MODULE_DOCUMENT
    )


def fault_of(item: Item, finished: dict[str, bool]) -> str | None:
    known = [s for s in item.stems if s in finished]
    where = f"{item.document}:{item.line}"
    if item.closed:
        if not known:
            return f"CLOSED-UNTRACKED  {where}  {item.head}"
        if not any(finished[s] for s in known):
            return (
                f"CLOSED-UNFINISHED {where}  names {', '.join(known)}, none "
                f"finished: {item.head}"
            )
        return None
    if not known:
        return f"UNTRACKED         {where}  {item.head}"
    if all(finished[s] for s in known):
        return (
            f"STALE             {where}  {', '.join(known)} finished: {item.head}"
        )
    return None


def audit(texts: dict[Path, str] | None = None) -> tuple[list[str], int, int]:
    """Faults, items read and sections read, over the set or over [texts]."""
    finished = corpus()
    faults: list[str] = []
    item_count = sections = 0
    for document in documents():
        text = (texts or {}).get(document) or document.read_text(encoding="utf8")
        if HEADING.search(text) is None:
            continue
        sections += 1
        for item in items_of(document, text):
            item_count += 1
            fault = fault_of(item, finished)
            if fault:
                faults.append(fault)
    return faults, item_count, sections


def self_test() -> int:
    """Plant each fault in a section of the real set and require it reported."""
    finished = corpus()
    done = next(s for s, f in sorted(finished.items()) if f)
    live = next((s for s, f in sorted(finished.items()) if not f), None)
    if live is None:
        print("self-test: the corpus holds no unfinished todo to plant")
        return 1
    subject = next(d for d in documents() if HEADING.search(d.read_text("utf8")))
    original = subject.read_text(encoding="utf8")
    heading = HEADING.search(original)
    assert heading is not None

    def plant(item: str) -> dict[Path, str]:
        cut = heading.end()
        return {subject: f"{original[:cut]}\n\n{item}\n\n{original[cut:]}"}

    checks = [
        ("UNTRACKED", "- An open end with no todo at all."),
        ("STALE", f"- An open end tracked by a finished todo (`{done}`)."),
        ("CLOSED-UNTRACKED", "- ~~Something.~~ **Closed** with nothing named."),
        ("CLOSED-UNFINISHED", f"- ~~Something.~~ **Closed** (`{live}`)."),
    ]
    clean = [
        ("open item, unfinished todo", f"- An open end (`{live}`)."),
        ("closed item, finished todo", f"- ~~Something.~~ **Closed** (`{done}`)."),
        (
            "closed item that moved",
            f"- ~~Something.~~ **Closed** here (`{done}`); continues in `{live}`.",
        ),
        (
            "continuation line carries the id",
            f"- An open end whose todo is named\n  on its second line (`{live}`).",
        ),
    ]
    baseline, _, _ = audit()
    failures = 0
    for label, item in checks:
        faults, _, _ = audit(plant(item))
        hit = len(faults) == len(baseline) + 1 and any(
            f.startswith(label + " ") for f in faults if f not in baseline
        )
        print(f"{'ok  ' if hit else 'FAIL'} {label} reported when planted")
        failures += 0 if hit else 1
    for label, item in clean:
        faults, _, _ = audit(plant(item))
        quiet = len(faults) == len(baseline)
        print(f"{'ok  ' if quiet else 'FAIL'} no fault for: {label}")
        failures += 0 if quiet else 1
    return failures


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return 1 if self_test() else 0
    if not DOCS_ROOT.is_dir():
        print(f"completion documents not found at {DOCS_ROOT}", file=sys.stderr)
        return 2

    faults, item_count, sections = audit()
    for fault in faults:
        print(fault)

    if "--quiet" not in argv:
        print()
        print(f"sections read            : {sections}")
        print(f"items read               : {item_count}")
        print(f"documents with a fault   : "
              f"{len({f.split()[1].split(':')[0] for f in faults})}")

    return report_faults(len(faults))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
