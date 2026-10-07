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
    # Scratch output. `check_doc_dart_blocks.py` extracts every ```dart block
    # in the corpus to `tool/ztmp/` so `dart analyze` can compile it; the copy
    # carries whatever the document carried, and the document is scanned here
    # already. Reporting both makes one fault two.
    "ztmp",
}

#: Everything a reader can end up holding: sources, tests, examples, the
#: package documentation, the scripts that ship beside them, and the fixtures
#: and configuration files a test run reads. Wider than
#: ``check_section_refs.py``'s three directories because a work-item id in
#: ``dart_test.yaml`` or a migration fixture is just as unresolvable, and
#: unlike a ``§`` it costs nothing to look for everywhere. The figures are
#: shipped text too: an SVG's comments and labels reach the same reader as the
#: README that embeds it, and a figure is the one place a sweep of the Dart and
#: the Markdown leaves an id standing.
SCANNED_EXTENSIONS = {".dart", ".md", ".sh", ".sql", ".svg", ".yaml"}

#: Files that are history by definition, and the in-suite guards, which have to
#: quote ``bug §50`` and ``csexb2`` to say which shapes they reject. Matched by
#: filename, since the guards and the changelogs are per package.
EXEMPT_FILES = {
    "comments_read_as_is_test.dart",
    "shipped_text_test.dart",
    "CHANGELOG.md",
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

#: The shape of a work-item id: letters, then digits, optionally followed by
#: the date code the id generator appends (``tcincb154_ahzj``).
ID_SHAPE = re.compile(r"\b([a-z]{2,12})\d+(_[a-zäñößü]{4})?\b")

#: Stems that take a numeric suffix in ordinary prose. Everything matching
#: [ID_SHAPE] whose stem is *not* here is reported.
#:
#: **The list is inverted from what it used to be, and that is the whole
#: point.** It used to enumerate quest prefixes -- ``tcinc``, ``tcca``,
#: ``cs[a-z]*`` and a dozen more. That is an *open* set: it grows whenever
#: anyone mints a prefix, and until someone thinks to add the new one the gate
#: reports the tree clean. It failed exactly that way twice over. ``qrc1`` sat
#: in three ``tom_core_server`` dartdoc comments and ``tfca4`` in two more,
#: shipping, while this gate passed -- two prefixes nobody had added.
#:
#: What is enumerated here instead is English words and published technical
#: vocabulary. That set is *closed*: no new quest prefix can join it, because
#: minting ``zzq7`` does not make ``zzq`` a word. So the failure direction
#: inverts with it. The prefix list failed open and silently; this fails closed
#: and loudly -- a worked example that introduces ``widget1`` produces one
#: visible fault and costs one line here, which is the cheap half of the trade.
#:
#: **The shape rule was rejected here once, on a figure that was measured
#: wrong.** The note that stood in its place said the shape "matches 397
#: further tokens on 4,582 lines". It does -- counted over whole lines, code
#: included, which is not where a pointer to a work item can sit. Counted over
#: prose, which is what [prose_of] extracts and what this gate is about, the
#: shape leaves 116 tokens over the 58 stems below, and every one of them is a
#: word. The sibling guard in ``advanced_ops_server`` had reached the right
#: answer years earlier; what kept it from travelling back was an inflated
#: count, not a real obstacle.
KNOWN_STEMS = frozenset(
    """
    abc address api arg arm avc base black col command container data db dec
    demo element
    fade field flex form gsm http image iso layer level list map march material mp
    name names oauth operant opt pass person phase pkcs prefix python row scope
    scores sha shade sigusr spacer sqlite step street strongpass subtitle time
    total tz ucs utf value white woff wrap
    """.split()
)

#: The same shape in capitals: ``RCK13``, ``TCCA17``, ``CSEXF1``, ``OT2``.
#:
#: **Needed because case is a bypass.** [ID_SHAPE] is lowercase, so an id
#: written the way prose usually writes one -- shouted -- walked past it. This
#: half replaced an enumeration of plan prefixes (``RC[BCK]?\d+``) that had the
#: open-set defect in its purest form: it knew ``RCB``, ``RCC`` and ``RCK``,
#: and did not know ``RCA``, ``RCD``, ``RCF``, ``RCI``, ``RCJ`` or ``RCL``,
#: which between them were shipping 29 pointers.
#:
#: Capitals are matched *only* as a whole run, never camelCase. That is what
#: makes the exemption list short: a Dart identifier with a numeric suffix is
#: written ``addressLine1``, ``promptSha256``, ``mBlue100``, and a quest id is
#: never written that way. Restricting to ALL-CAPS turned 62 candidate stems
#: into 18 families of pointer plus the 20 published names below.
CAPS_SHAPE = re.compile(r"\b([A-Z]{2,12})\d+\b")

#: ALL-CAPS names that a reader can look up: hash and cipher families, media,
#: container and encoding standards, SQL types, signal names, and the two
#: mermaid node prefixes the design diagrams use (``RT1``, ``FB1``).
KNOWN_CAPS = frozenset(
    """
    AES AWS ES FB FF HS INT ISO MD MGF MP PKCS POP RFC RGBA RS RT SHA SIGUSR SKU
    USR UTF X ZIP
    """.split()
)

#: The hyphenated plan ids, which neither shape reaches: ``RC-24``, ``D-A3``,
#: ``D-RC5-b``. Deliberately does **not** match ``G-`` (framework guideline
#: ids), ``TC-`` (testkit ids) or a bare ``C-5`` (framework concept codes),
#: all of which index published vocabulary.
PLAN_ID = re.compile(r"\b(RC-\d+|D-(?:RC)?[A-Z]?\d+)\b")

#: A pointer at a numbered row of a plan. ``Todo`` is capitalised because it is
#: a proper noun here -- the row -- whereas a lowercase ``todo`` in prose is
#: the ordinary word. A bare ``step 4`` is not matched: an example that
#: numbers its own steps refers to something the reader is holding.
WORK_ITEM_POINTER = re.compile(r"\b(Todo|plan step)\s+#?\d+\b")

#: Past-indicative narration about the code's own history.
#:
#: ``used to`` is matched only before the verbs that cannot follow it in the
#: *passive* sense -- "the scope segment used to resolve display keys" is a
#: reduced relative clause, not a claim about the past, and dartdoc is full of
#: them. A verb that reads both ways (``resolve``, ``reach``, ``look``,
#: ``present``) would make the gate demand a rewrite of correct prose, so it
#: stays out and the shapes below carry the rest of the rule.
#:
#: ``as before`` has no innocent reading in shipped text: whatever it compares
#: to, the reader is not holding it. ``formerly`` likewise. ``Previously``
#: leading a sentence is narration; the same word *inside* one is usually
#: adjectival ("previously persisted records", "a run previously lost"), so
#: the lowercase form is matched only when a determiner or pronoun follows it
#: and a clause is therefore starting.
NARRATION = re.compile(
    r"\b(used to (be|been|return|claim|carry|call|stand|reflect|throw|write"
    r"|test|exercise|live|sit|happen|recurse|appear)"
    r"|(before|after|prior to) the fix"
    r"|the todo that"
    r"|this todo"
    r"|as before"
    r"|formerly)\b",
    re.IGNORECASE,
)

#: The sentence-initial half of the narration rule, which is case-sensitive
#: and so cannot live in [NARRATION].
NARRATION_CASED = re.compile(
    r"\bPreviously\b"
    r"|\bpreviously\s+(the|a|an|it|this|that|these|those|they|we)\b"
)

#: The three rules that read a whole line. They match shapes no code
#: identifier has -- ``RCK13``, ``Todo 9``, "used to return" -- so narrowing
#: them to prose would buy nothing.
PATTERNS = {
    "build-plan id": PLAN_ID,
    "work-item pointer": WORK_ITEM_POINTER,
    "history narration": NARRATION,
    "history narration (sentence-initial)": NARRATION_CASED,
}

#: The parts of a line a reader reads as prose, which is the only place a
#: pointer at a work item can sit. In Dart that is comments and the
#: descriptions of tests and groups; in markdown and shell it is the line.
#:
#: **Not every string literal.** Widening this to all quoted text takes the
#: vocabulary that has to be exempted from 116 tokens to 296, because fixture
#: data is full of ``user1`` and ``task2``. A fixture string is data the test
#: feeds to the code, not prose the reader is asked to understand, so a
#: work-item id could not be pointing at anything from in there.
DART_COMMENT = re.compile(r"//+(.*)$")
DART_TEST_NAME = re.compile(
    r"""\b(?:test|group|testWidgets)\s*\(\s*(['"])(.*?)\1"""
)


#: In a figure the prose is what is drawn as text and what its comments say;
#: everything else is markup. A tag's attributes carry marker and gradient ids
#: (``arrow2``) and a ``<style>`` block carries class selectors (``.db{``), and
#: both are names the file gives itself, never pointers at a work item.
SVG_COMMENT = re.compile(r"<!--(.*?)(?:-->|$)|^(.*?)-->")
SVG_TAG = re.compile(r"<[^>]*>?|^[^<]*>")


def svg_prose(line: str) -> list[str]:
    """The comment text and drawn text on one line of an SVG figure."""
    found = [part for match in SVG_COMMENT.finditer(line)
             for part in match.groups() if part]
    rest = SVG_COMMENT.sub(" ", line)
    if "{" in rest or "}" in rest or "=" in rest:
        # A style rule, or a tag's attributes continued from the line above.
        rest = SVG_TAG.sub(" ", rest) if rest.lstrip().startswith("<") else ""
    else:
        rest = SVG_TAG.sub(" ", rest)
    return found + [rest]


def prose_of(path: Path, line: str) -> list[str]:
    """The stretches of ``line`` that are prose rather than code."""
    if path.suffix == ".svg":
        return svg_prose(line)
    if path.suffix != ".dart":
        return [line]
    found = []
    if comment := DART_COMMENT.search(line):
        found.append(comment.group(1))
    if name := DART_TEST_NAME.search(line):
        found.append(name.group(2))
    return found


#: The two shapes an id is written in, each with the vocabulary that shape's
#: legitimate tokens come from. Splitting them keeps each list short enough to
#: read: lowercase prose words are not ALL-CAPS standards names, and mixing the
#: two would exempt ``SHA`` from the lowercase side for free.
SHAPES = ((ID_SHAPE, KNOWN_STEMS), (CAPS_SHAPE, KNOWN_CAPS))


def work_item_ids(path: Path, line: str) -> list[str]:
    """Every token in ``line``'s prose shaped like a work-item id."""
    return [
        match.group(0)
        for chunk in prose_of(path, line)
        for shape, known in SHAPES
        for match in shape.finditer(chunk)
        if match.group(1) not in known
    ]

#: A testkit id in the leading ``ID: description`` position of a test or group
#: name. The id is the baseline's join key, so it stays. The trailing number
#: may be interpolated -- ``'tccm1-$id: ...'`` names one row of a generated
#: family, and those are join keys like any other.
TESTKIT_ID_POSITION = re.compile(r"""['"]\s*[a-z]+\d+(-(?:\d+|\$\w+))?:\s""")


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
        if work_item_ids(path, line):
            faults.append((index + 1, "quest todo id", line.strip()))
            continue  # one report per line is enough to find it
        for kind, pattern in PATTERNS.items():
            if pattern.search(line):
                faults.append((index + 1, kind, line.strip()))
                break
    return faults


#: Lines from real figures, each with whether it carries a work-item id. The
#: markup lines are the ones that broke a line-as-prose reading: a marker id,
#: a style rule, an attribute continued from the line above.
SVG_CASES = (
    ('  <!-- traced from a row to a widget (RCC2). -->', True),
    ('    traced from a row to a widget (RCC2).', True),
    ('  <text x="40" y="20" class="lbl">ceiling (RCB5)</text>', True),
    ('  <marker id="arrow2" viewBox="0 0 10 10">', False),
    ('    .db{fill:#eef;stroke:#557}', False),
    ('       marker-end="url(#arrow2)"/>', False),
    ('  <text x="40" y="20">the field renders at its grade</text>', False),
)


def self_test() -> int:
    """The figure reader finds ids in prose and none in markup."""
    figure = Path("figure.svg")
    wrong = [line for line, has_id in SVG_CASES
             if bool(work_item_ids(figure, line)) != has_id]
    for line in wrong:
        print(f"self-test: misread {line.strip()!r}", file=sys.stderr)
    if wrong:
        return 1
    print(f"self-test: {len(SVG_CASES)} figure lines read as expected")
    return 0


def main(argv: list[str]) -> int:
    if argv == ["--self-test"]:
        return self_test()
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
