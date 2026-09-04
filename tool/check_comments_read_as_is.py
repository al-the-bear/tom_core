#!/usr/bin/env python3
"""Find work-item ids and history narration in shipped text.

Run from anywhere::

    python3 tool/check_comments_read_as_is.py                  # every package
    python3 tool/check_comments_read_as_is.py tom_core_server  # one subtree

Exits non-zero when any fault is found, so it can gate a build.

Shipped text is read **as is**, by someone holding the package and nothing
else. Two constructions break that, and this gate finds both.

**Work-item ids.** ``tcincb154_ahzj``, ``RCK13``, ``RCC5``, ``Todo 9``. They
name rows in quest documents that ship with neither the package nor its tests.
A reader cannot resolve them, and a reader who could would find a build log
rather than a rule. Traceability runs *todo to code*: a todo may name the file
it changed, so the pointer survives in the place that can hold it.

**History narration.** "used to return", "before the fix it threw", "the todo
that produced this test". A comment describes what the code does now and why;
the sequence of states that produced it is the commit log's job. The repair is
almost always to turn the past indicative into a conditional -- *before the fix
it threw* becomes *doing X instead would throw* -- which says the same thing to
the reader and stays true.

**The section-reference half is a separate gate.** ``§`` citations are checked
by ``check_section_refs.py``, which asks whether the document being indexed is
nameable from where the reference sits. The two rules are different questions
and different repairs, so they are different gates.

What is deliberately *not* a fault:

``tccc3-05:`` and its kind
    A testkit id in the leading ``ID: description`` position of a test or group
    name populates the ID column of ``testlog/baseline_*.csv``. Renaming one
    discards that test's result history, so the leading position is exempt --
    but only there. The same id in prose is a pointer like any other.

``G-API-3``, ``TC-14``, ``C-5``
    Framework guideline ids, testkit ids and concept codes. They index the
    framework's own published vocabulary, not a work item.

``step 4`` in an example
    An example that walks through numbered steps is referring to *itself*, and
    the reader has it. Only ``Todo <n>`` and ``plan step <n>`` name something
    outside the artefact.

``_copilot_guidelines/`` and ``CHANGELOG.md``
    A development guideline is a working document that does not leave the
    workspace, and a changelog is a history by definition. Both may name work
    items freely.

``comments_read_as_is_test.dart`` and the repository ``README.md``
    Both have this convention as their *subject*, and a rule that cannot quote
    the shape it rejects is not a rule. The README is exempt by path, so a
    package's own README stays guarded.

**Why a Python gate rather than a copy of the Dart one per package.**
``tom_core_kernel/test/comments_read_as_is_test.dart`` enforces this from
inside that package's suite, which is the fastest possible signal for the
package it guards. Extending that to the siblings would mean a copy of one
rule per package -- kept in sync by hand, in two dialects, since
``tom_core_flutter`` runs on ``flutter_test`` and ``tom_core_samples`` is not a
package at all. One checker here covers every package including the sample
suite's orphan markdown, and it is enforced by ``check_gates.py`` from the day
it lands.

That is not a prediction any more; the divergence happened. Two copies exist --
the kernel's and ``advanced_ops_server``'s -- and they no longer implement the
same rule. The ops_server copy detects ids by *shape* rather than by prefix,
because the prefix list had let ``csexd4`` and ``csexd6`` through while
reporting that package clean. The fix was made in the copy and never travelled
back, so this gate carried the same blind spot for as long as the note
describing it sat in a sibling file: the ``cs`` family had reached shipped
``lib/`` dartdoc in three packages. Sixteen copies would not have been sixteen
guards, only sixteen places for the next fix to fail to leave.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {
    ".dart_tool",
    "build",
    ".git",
    "node_modules",
    "__pycache__",
    "_copilot_guidelines",
    "testlog",
}

#: Everything a reader can end up holding: sources, tests, examples, the
#: package documentation, the scripts that ship beside them, and the fixtures
#: and configuration files a test run reads. Wider than
#: ``check_section_refs.py``'s three directories because a work-item id in
#: ``dart_test.yaml`` or a migration fixture is just as unresolvable, and
#: unlike a ``§`` it costs nothing to look for everywhere.
SCANNED_EXTENSIONS = {".dart", ".md", ".sh", ".sql", ".yaml"}

#: Files that are history by definition, and the in-suite guards, which have to
#: quote ``bug §50`` and ``csexb2`` to say which shapes they reject. Matched by
#: filename, since the guards and the changelogs are per package.
EXEMPT_FILES = {
    "comments_read_as_is_test.dart",
    "shipped_text_test.dart",
    "CHANGELOG.md",
    "analyzer_analysis.json",
}

#: Generated reflection output, which carries whatever the sources carried at
#: generation time and is repaired by regenerating, never by editing. Both
#: in-suite Dart guards have always skipped it; this gate did not, and the
#: omission was invisible only because no generated identifier happened to
#: match [TODO_ID]. It nearly stopped being invisible: ``reflection_seed``
#: emits ``prefix167``-style names, and one file alone carries 46,929 of them,
#: so the first quest prefix to collide would have buried the report.
GENERATED_SUFFIX = ".reflection.dart"

#: The repository README, for the same reason as the guard: its "Repository
#: tooling" section is an inventory of the gates, and a gate cannot be
#: described without naming what it rejects. Exempt by *path* rather than by
#: filename so that a package's own README stays guarded -- those are shipped
#: text like any other, and only this one has the convention as its subject.
EXEMPT_PATHS = {Path("README.md")}

#: A quest todo id: a quest prefix, a number, and optionally the date code the
#: id generator appends (``tcincb154_ahzj``).
#:
#: **The ``cs`` family is here because ids leak in from the quest that is
#: working next door, not from this one.** The prefixes a gate's author thinks
#: of are the ones they are using that week; the ones that actually reach the
#: tree come from whoever else edited it. ``csex``/``csm``/``csra``/``csfs`` --
#: CodeSpecs and tom_specs work items -- had reached shipped ``lib/`` dartdoc in
#: three packages and the tests of two sample packages while this gate reported
#: every one of them clean.
#:
#: **Why this stays a list of prefixes and not a shape.** The sibling guard in
#: ``advanced_ops_server`` matches ``\b[a-z]{2,10}\d+\b`` and exempts a closed
#: set of technical tokens, on the argument that a list of prefixes is
#: permanently one prefix behind. That is true, and it is still the wrong trade
#: here: the shape matches 397 further tokens on 4,582 lines of this
#: repository, and they are almost all real -- ``demo01`` and its 27 siblings
#: are showcase ids, ``material3`` and ``black54`` are Flutter names,
#: ``operant1`` is a datasource term. The shape works in that package because a
#: small sample has no such vocabulary; it does not survive contact with a
#: framework. A gate that fails correct work is a gate that gets switched off,
#: so the open set is enumerated here and widened when a family leaks in.
TODO_ID = re.compile(
    r"\b(tcinc|tcincb|tcopen|tcca|tccc|tcser|tcdocc|tcscan|tcfinal|tcextension"
    r"|cs[a-z]*)"
    r"\d+(_[a-zäñößü]{4})?\b"
)

#: A build-plan id from the refactor plans: ``RCK13``, ``RCC5``, ``RCB8``,
#: ``RC-24``, ``D-A3``, ``D-RC5-b``. Deliberately does **not** match ``G-``
#: (framework guideline ids), ``TC-`` (testkit ids) or a bare ``C-5``
#: (framework concept codes), all of which index published vocabulary.
PLAN_ID = re.compile(r"\b(RC[BCK]?\d+|RC-\d+|D-(?:RC)?[A-Z]?\d+)\b")

#: A pointer at a numbered row of a plan. ``Todo`` is capitalised because it is
#: a proper noun here -- the row -- whereas a lowercase ``todo`` in prose is
#: the ordinary word. A bare ``step 4`` is not matched: an example that
#: numbers its own steps refers to something the reader is holding.
WORK_ITEM_POINTER = re.compile(r"\b(Todo|plan step)\s+#?\d+\b")

#: Past-indicative narration about the code's own history.
NARRATION = re.compile(
    r"\b(used to (be|been|return|claim|carry|call|stand|reflect|throw|write"
    r"|test|exercise|live|sit|happen)"
    r"|(before|after|prior to) the fix"
    r"|the todo that"
    r"|this todo)\b",
    re.IGNORECASE,
)

PATTERNS = {
    "quest todo id": TODO_ID,
    "build-plan id": PLAN_ID,
    "work-item pointer": WORK_ITEM_POINTER,
    "history narration": NARRATION,
}

#: A testkit id in the leading ``ID: description`` position of a test or group
#: name. The id is the baseline's join key, so it stays.
TESTKIT_ID_POSITION = re.compile(r"""['"]\s*[a-z]+\d+(-\d+)?:\s""")


def scanned_files(root: Path):
    """Every shipped file under ``root`` this gate reads."""
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.suffix not in SCANNED_EXTENSIONS:
            continue
        if SKIP_DIRS & set(path.parts):
            continue
        if path.name in EXEMPT_FILES or path.name.endswith(GENERATED_SUFFIX):
            continue
        if path.relative_to(REPO_ROOT) in EXEMPT_PATHS:
            continue
        yield path


def faults_in(path: Path) -> list[tuple[int, str, str]]:
    """The ``(line, kind, text)`` of every fault in ``path``."""
    try:
        lines = path.read_text(encoding="utf-8").split("\n")
    except (OSError, UnicodeDecodeError):
        return []
    faults = []
    for index, line in enumerate(lines):
        if TESTKIT_ID_POSITION.search(line):
            continue
        for kind, pattern in PATTERNS.items():
            if pattern.search(line):
                faults.append((index + 1, kind, line.strip()))
                break  # one report per line is enough to find it
    return faults


def main(argv: list[str]) -> int:
    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    scanned = 0
    faults: list[tuple[Path, int, str, str]] = []
    for path in scanned_files(root):
        scanned += 1
        for line, kind, text in faults_in(path):
            faults.append((path, line, kind, text))

    for path, line, kind, text in faults:
        print(f"{path.relative_to(REPO_ROOT)}:{line}: [{kind}] {text}")

    print()
    print(f"files scanned            : {scanned}")
    print(f"unreadable references    : {len(faults)}")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
