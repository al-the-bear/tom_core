#!/usr/bin/env python3
"""Audit the hand-written measurements in the tom_core completion documents.

Run from anywhere::

    python3 tool/check_doc_inventories.py                 # audit every document
    python3 tool/check_doc_inventories.py tom_core_kernel # one project's documents
    python3 tool/check_doc_inventories.py --fix           # re-measure and rewrite
    python3 tool/check_doc_inventories.py --self-test     # check the checker

Exits non-zero when any measurement disagrees with the tree.

``--self-test`` asks the opposite question: it damages a document in memory --
raising one figure of each kind by one, and writing a length into a sentence
that had none -- and requires this checker to object. A gate held to a baseline
of zero faults passes just as well when it has stopped reading anything, so the
baseline alone cannot tell working coverage from absent coverage. See
:func:`self_test`.

Two shapes are audited. Most documents open by naming the module's directory
and how much is in it, and then tabulate the directory a file at a time::

    | File | Lines | Carries |
    | ---- | ----- | ------- |
    | `date_timestamp.dart` | 1184 | `TomTimezoned` and its three subclasses. |

A module with sub-folders maps them instead, counting the types in each::

    | Sub-folder | File | Family | Types |
    | --- | --- | --- | --- |
    | `animated/` | [`tom_animated.dart`](...) | `animated` | 20 |

Those numbers are measurements, and a measurement written by hand is correct
only until the next commit. They are worth keeping because they tell a reader
the shape of a module before they open it -- a two-file, 150-line module and a
nine-file, 4000-line one are read differently -- but nobody re-measures them
when a module changes, so without a check they decay silently into confident
misinformation, which is worse than having omitted them.

That is not hypothetical for the ``Types`` column: deleting two deprecated
button wrappers left the widgets map claiming 23 buttons where the sub-folder
had 21, and the claim survived a sweep that corrected the same census in six
other documents -- because a bare number in a table cell is invisible to a
scan that looks for a count beside a noun.

A package document maps its whole tree instead, in a fenced block that labels
each barrel with how much it re-exports::

    advanced_app_client/
      lib/
        app/
          app.dart                       barrel — 4 exports

and opens by sizing the package as a whole::

    `tom_core_samples/advanced_todo_domain/` — 23 files, of which 17 are Dart:
    14 under `lib/` (619 lines, all hand-written) and 3 under `test/`, ...

Eleven faults are reported:

``LINES``
    A file whose claimed length is not its length -- in an inventory table's
    ``Lines`` column, or beside its row in a layout block (``main.dart
    bootstrap + backend injection (107 lines)``). The common defect: the module
    was edited, the claim was not.
``LAYOUT``
    A layout-block row naming a file the package does not have. This is
    ``UNKNOWN`` for the drawn tree rather than the table, and it is separate
    because the tree is the *only* inventory some documents draw: a package with
    a flat ``lib/`` and no per-file lengths, or an asset folder with no Dart in
    it at all, tabulates nothing and so was audited for nothing until this read
    its tree.
``UNKNOWN``
    A tabulated file that is not in the directory -- renamed or deleted.
``ABSENT``
    A file in the directory that the table does not list. An inventory that
    silently drops a file misleads exactly as much as one with bad arithmetic.
``HEADER``
    The opening paragraph's file count or line total, or the ``readme.md (K
    lines)`` aside beside it, disagreeing with the directory.
``COUNT``
    A sub-folder map row whose ``Types`` count is not the number of ``Tom``
    classes declared under that sub-folder, or a sub-folder present in the
    module and missing from the map.
``BARREL``
    A layout-block ``barrel — N exports`` label whose number is not the count
    of ``export`` directives in the file it labels.
``PKGINV``
    An atom of a package document's opening inventory -- the package's file
    count, its Dart-file count, how many of those sit under ``lib/``, ``bin/``,
    ``test/`` or ``example/``, the hand-written file counts and line totals
    beside them, and the counts of SQL migrations and of ``assets/`` files --
    disagreeing with the package. Also an atom the package *has* and the census
    does not state: a silent omission is the same defect as a wrong figure, one
    step earlier.
``LIBSIZE``
    The standalone ``lib/`` size paragraph of a server package document --
    ``lib/` totals 3 513 lines, of which `app_endpoints.dart` is 1 748`` --
    disagreeing with the library.
``INDEX``
    An entry in the completion overview whose restated file count or line total
    disagrees with the module it links to, or whose link names a document that
    does not exist. The census is stated twice -- once in its own document,
    once in the index -- and it is the second copy that goes stale.
``PROSE``
    A length written into a sentence that no audit above read -- ``a 74-line
    controller``, ``Eight steps, one file, 239 lines``. It is not reported as a
    wrong number, because usually it is not one *yet*; it is reported as a
    measurement in the one position nothing can maintain. Unlike every other
    fault this one is defined by the others rather than by a shape of its own:
    each audit records the spans it read a length out of, and this reports the
    leftovers. Widening any audit therefore narrows this one automatically,
    with no second list of covered positions to keep in step.

``PKGINV`` exists because the opening inventory of a *package* document was
the one measurement in these documents that nothing checked. It drifted
exactly as the docstring above predicts: ``advanced_todo_domain`` claimed 24
files when it had 23, and its line total went stale the next time anyone
edited a dartdoc -- a one-line comment change silently falsifies the paragraph
a reader trusts most, because it is the first one they read.

**The census is one sentence in one grammar, and that is what makes it
gateable.** The eight advanced package documents once wrote it in three
different hands -- ``13 tests`` beside ``13 under `test/```, ``runtime assets``
beside ``assets``, a Dart split introduced by a colon in one document and by a
parenthesis in the next -- and a regex set tolerant of all of them is a regex
set that will not survive the ninth. So the sentence has a shape, and the audit
reads only that shape:

1. ``` `<package path>/` — N files, of which D are Dart ```, then the Dart split.
2. Each folder the package actually has, as ``` K under `<folder>/` ```,
   optionally followed **immediately** by a parenthetical carrying its line
   total and hand-written file count.
3. ``S are SQL migrations`` and ``A are assets``, each stated where the package
   has any, each with the verb between the count and the noun.
4. Then prose.

**A count in this sentence is a count of files, and nothing else.** That rule is
what ``A are assets`` encodes, and it was bought with a defect.
``advanced_auth_server`` used to say ``4 are runtime assets and 2 are JSON
resource bundles`` -- but the 2 bundles are a *subset* of the 6 files under
``assets/``, written as though they were 2 more, so the atoms summed to 45
against a package of 44 and no reader could tell which figure was wrong. A gate
derived from ``git ls-files`` sees only "``assets/`` holds 6 files"; it cannot
know which of them a person would call runtime. So the number is always the
total, and any semantic split is written after it, parenthesised and **spelled
out in words** -- ``6 are assets (four runtime configuration bundles and two
JSON resource bundles)``. Words rather than digits is not decoration: it puts
the split visibly outside the class of things that are measurements, so nobody
later mistakes it for one and nothing has to teach the gate about file
semantics.

The census is also required to be *complete*. Checking only the atoms a sentence
happens to mention makes the audit exactly as good as the sentence, which is the
wrong way round: a package that gains its first migration would keep a census
silent about migrations and go on passing. A document may omit an atom only when
the package does not have it.

``HEADER`` reads the module header as a sentence rather than as a template,
because the template was the fault. It once required the literal ``N source
files, M lines``, and a header that stated the same two numbers in any other
words was not merely mis-parsed but *invisible*: ``audit`` returned "measures
nothing", ``main`` dropped the document, and the run reported it as passing.
Four module documents wrote their size in prose (``two files (the wire
constants plus the sub-barrel), 50 lines``) and were audited by nothing at
all; a fifth, ``tomclient/runtime``, wrote ``4 source files (227 lines)`` and
lost its header to a missing space. A silent skip is the worst failure mode a
gate has -- a defective measurement at least appears in the fault count, while
an unparsed one inflates the *pass* rate -- so the count of documents that
measure nothing is now printed beside the count that were audited. Widening
recognition took coverage from 41 documents to 69 and surfaced six stale
figures, two of which had been stale across two consecutive edits apiece.

What a header counts is read from the header. ``N source files`` and ``N Dart
files`` say the readme is not in the figure. A bare ``N files`` is settled by
whether the parenthetical that follows it breaks the figure down and names the
readme among the parts -- ``11 files (10 Dart, 1 readme)`` counts it, while
``14 source files plus a readme`` sets it beside the count and does not. That
distinction is not a guess: it agrees with all 59 module headers in this set,
the two that count a readme included.
The line total always counts the sources, since no header here totals a readme
in with them and several give its length separately. A count is recursed only
when the module has sub-folders, which is when its header describes a tree
(``25 files (24 Dart across 20 sub-folders, ...)``) rather than a directory.
A rounded figure -- ``~23 000 lines`` -- is skipped, because demanding an
approximation be exact reports a fault on every run.

The atoms are still deliberately narrow, and the widening did not relax them.
Only a directory carrying a ``pubspec.yaml`` is treated as a package; a number
counts only where it sits immediately beside the noun it measures (``— 23
files``, ``of which 17 are Dart``, ``14 under `lib/```); and the header is read
only within the paragraph its module path opens, because a later paragraph
will eventually say ``4 files`` about something else. Prose that merely
contains a number near a noun -- ``14 hand-written library files``, ``10 test
suites and 1 shared test fixture`` -- is left alone. That is what keeps the
check free of false positives; a pattern loose enough to read any sentence
would flag the documents it cannot understand and be turned off.

``BARREL`` is the one measurement here that has twice hidden a defect rather
than merely gone stale. ``advanced_app_client``'s ``lib/app/app.dart`` was
labelled ``4 exports`` and had three: the missing fourth was
``session_two_factor_controller.dart``, a real file the same layout block
listed one line below and the document gave its own section, but which no
consumer of ``package:advanced_app_client/app/app.dart`` could name. The
number was right about what the barrel was *for* and wrong about what it
*was*, and only counting the directives tells the two apart. Three of the labels
the check could see were wrong the first time it ran.

That record is why a barrel label is required to carry its count. An uncounted
one -- ``public barrel``, ``wire barrel`` -- states nothing that can go stale, so
it looks harmless, and it is exactly the shape this audit cannot see. The seven
that were written that way had gone unread for as long as they had existed.

**Which layout styles are read, and what in them is a claim.** The blocks come
in two hands. Most indent with spaces::

    lib/
      main.dart      bootstrap + backend injection (107 lines)

while others draw the tree::

    ├── bin/
    │   └── ops_server_start.dart   # boot + reflection root (282 lines)

Both are walked, and a row's directory is the chain of folder rows above it at
smaller indents either way -- the box-drawing characters are simply part of the
indent. Which hands are read is worth stating rather than leaving to be
discovered, because coverage that depends on the characters a document happens
to indent with, and says so nowhere, reads exactly like coverage that is
complete.

Only a fence whose first row names a directory is walked at all. These documents
also paste console transcripts into ``text`` fences, and a transcript read as a
tree yields a row per line, each "naming" whatever its first word happens to be.
Within a block, a row whose first word is ``#`` is a comment wrapped onto its own
line: it continues the row above, names nothing, and is skipped without
disturbing the folder stack, since its indent is the comment column rather than a
depth in the tree.

A claim is a number immediately in front of the word ``lines``, on a row that
names a file. The noun is required. Two of these documents also wrote a length
as a bare number in the trailing comment (``ops_jobs.dart  # 172 -- the three
job declarations``), and all seven such figures were true; they are still not
read, because a bare number is not a measurement a checker can recognise
without guessing, and the fix is to write the noun rather than to teach the
gate to guess. A rounded figure (``~324 k lines``) is skipped for the reason
the module header skips one: demanding an approximation be exact reports a
fault on every run.

A row naming a *folder* is not read, even when it carries a length --
``test/  12 suites, 2 153 lines`` is the one instance in this set, and it is
true. It is left alone because it is an aggregate rather than a file's length,
and the sum it aggregates is undefined in general: over every file in the
directory, over the Dart files, or over the twelve suites the same row counts.
Those agree here only because ``test/`` happens to be flat and all Dart, and a
rule that is determinate by accident is the kind that reports a fault the first
time the accident ends.

**The overview restates every census, and the restatement is what drifts.**
``tom_core_completion_overview.md`` is an index: seventy-nine entries, each a
heading, a link to a completion document, and a paragraph summarising it. Most
of those paragraphs repeat the linked document's file count or line total, a
thousand lines away from the census they copy, and until ``INDEX`` nothing read
the two together -- the header audit stops at the *first* module path in a
document, so an index of seventy-nine modules was audited once and then not at
all. Forty of the fifty-nine figures in it were stale, several by a third.

An ``INDEX`` claim is measured against the module, not against the wording of
the census it restates. Comparing text to text is the tempting reading, since
the fault class really is a copy drifting from its original, and it is wrong:
the two are written in different nouns and would disagree where they are both
right. ``widgets/`` is ``25 files (24 Dart ..., plus the module readme)`` in its
own document and ``24 Dart files`` in the index. Measuring each claim in the
noun it was written in -- `counted_files` is shared by both audits for exactly
this reason -- makes them agree by construction, so an entry faults only when
it is actually wrong.

What an entry may say, and what is read from it:

* a file count -- ``nine files``, ``Twelve files``, ``73 Dart files``, ``three
  small files``. One adjective may sit between the count and the noun; the
  noun decides whether the module readme is in the figure, on the same rule the
  header audit uses. ``besides the barrel`` is read and subtracts one.
* a line total -- ``4 480 lines``, or ``one 808-line file``.
* an approximation, marked ``~`` or ``roughly``, which is skipped. Three
  entries hedge deliberately and demanding they be exact would fault forever.

Only the entry's *first* paragraph is read, and within it only the first figure
of each kind: an entry is prose, and its later paragraphs are as full of
unrelated numbers as any completion document's.

**What ``INDEX`` does not cover.** An entry linking to a *package* document is
declined outright. Package figures are about ``lib/`` and ``test/`` trees, and
the index writes them in prose that shares no grammar with either a module
census or the package atoms -- ``64 Dart files under `lib/` ... 14 under
`test/` ... four documents under `doc/```. Nineteen entries are in that class;
their figures are true as of this writing and are held true by hand. The rule
for them, until the gate reaches them, is the one this audit exists to enforce
elsewhere: **a figure restated in an index entry must be the figure its
document's census states, in the census's own noun.** Widening the gate to read
them means first normalising those nineteen paragraphs onto one grammar, which
is a change to the documents rather than to this tool.

**A length is stated where a gate holds it, and nowhere else.** A completion
document states its census once, at the top, where ``HEADER`` or ``PKGINV``
holds it to the tree, and tabulates its per-file lengths where ``LINES`` holds
them. Every *later* mention of a length is a copy, and a copy is what drifts --
the index above is the extreme case, but the same thing happened inside single
documents, in sentences a thousand lines below the census. ``PROSE`` is the
rule made mechanical: a length figure sitting anywhere no audit read it faults,
so the choice is to put it in the inventory or to write the sentence without
it. Both are improvements on a number nothing maintains, and the second is
usually the better one -- ``one small controller`` says what the sentence was
actually claiming, where ``a 74-line controller`` only appeared to.

``--fix`` repairs ``LINES``, ``HEADER``, ``COUNT``, ``BARREL``, ``PKGINV``,
``LIBSIZE`` and ``INDEX``
by writing the measurement back, so keeping the numbers true costs one command
rather than a manual pass. A count spelled out is repaired spelled out, with
its capitalisation, since an index entry routinely opens its sentence with one
and ``13 files, all exported`` would be a worse sentence than it was. What
``--fix`` never does is re-wrap: a repaired figure with more digits than the
stale one can push its line past the margin, so read the diff.
It never touches ``UNKNOWN``, ``ABSENT``, ``LAYOUT`` or ``PROSE``, nor a
missing map row, nor a ``says nothing about`` fault: adding or retiring a row --
or naming a part of the package the census is silent about -- means writing the
sentence that says what the file or folder carries, and only a reader of it can
do that. A ``LAYOUT`` row is the sharpest case of it: a tree row is a file's
place in a structure, and where its replacement belongs in that structure is
exactly the judgement a rewrite cannot make. ``PROSE`` is unrepairable for the
opposite reason -- the number is usually *right*, and what is wrong is that it
is in a sentence, so the repair is to rewrite the sentence and only its author
knows what it was for.

Note what ``--fix`` means for a ``BARREL`` fault: it makes the *document*
agree with the code, which is right when the label is stale and wrong when the
label is a symptom, as the case above was. The repair is always available and
never automatic -- read which of the two you have before running it.

The type count mirrors ``declarationPattern`` in
``tom_flutter_ui/test/widgets/widget_census.dart``, which answers the same
question on the Dart side for the package's own suites. A gate written in
Python cannot call it, so the pattern is stated twice; changing either one
means changing both, and the totals they produce should always agree.

The documents live in the ``_ai`` layer, beside the quest that produced them,
while the tree they describe lives here -- hence the reach across the two
repositories. That split is why this check has to be deliberate: nothing about
editing a module brings its completion document into view.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent
DOCS_ROOT = REPO_ROOT.parent.parent / "_ai" / "quests" / "tom_core" / "completion"

# The module directory, as the documents name it: a backticked path that starts
# at a project and reaches into its source tree. Taken from the first mention,
# which is the "On disk at ..." opening; later mentions point at neighbours.
MODULE_PATH = re.compile(r"`(tom_\w+/lib/src/[\w/]+?)/?`")

# A package document's "path on disk" line: the backticked package directory
# opening a paragraph, followed by the em dash that introduces its file count.
# Anchored at the line start so a mid-sentence mention of a neighbour package
# -- of which these documents have several -- cannot be taken for the subject.
PACKAGE_PATH = re.compile(r"^`(tom_\w+/[\w/]+?)/?`\s+—", re.M)

# The layout block: a ```text fence whose first line is the package directory.
LAYOUT_FENCE = re.compile(r"^```text\n(.*?)^```", re.M | re.S)

# A barrel label inside it. `entity barrel — 9 exports, no generated code` and
# `DTO barrel — 9 exports` both carry the same claim, so the word `barrel` is
# matched wherever it falls rather than required to start the label.
BARREL_LABEL = re.compile(r"\bbarrel\s+—\s+(\d+)\s+exports")

#: A row that calls its file a barrel. Used to catch the ones `BARREL_LABEL`
#: cannot read, so an uncounted barrel is reported rather than quietly skipped.
BARE_BARREL = re.compile(r"\b(barrel)\b")

#: The characters a drawn tree indents with. Treated as indentation rather than
#: as content, which is what lets one walk read both hands -- see the module
#: docstring on layout styles.
BRANCH = " │├└─"

#: An `export` directive, counted the way the barrels are written -- one per
#: line, at the left margin. A `part` is not an export and is not counted.
EXPORT = re.compile(r"^export\s", re.M)

#: A number as these documents group it: digits, optionally split by a space or
#: a thin space every three (``4 337``). Kept as written when a figure is
#: rewritten, so ``--fix`` does not restyle the prose around it.
#:
#: It must begin and end on a digit. Letting the separator class lead would
#: allow the match to start on the space in front of the figure, and `--fix`
#: would overwrite that space along with the number -- turning
#: `20 hand-written, 4 337 lines` into `20 hand-written,4 337 lines`.
NUMBER = r"\d(?:[\d   ]*\d)?"

#: A length claim beside a layout row: a number immediately in front of `lines`,
#: parenthesised (`(107 lines)`) or not (`# 429 lines`). Grouped figures are
#: read (`1 159 lines`). A rounded one is matched so it can be recognised and
#: skipped -- `~324 k lines` is an approximation, and a gate that demands an
#: approximation be exact reports a fault every run.
LAYOUT_LINES = re.compile(r"(~\s*)?(" + NUMBER + r")\s*(k\s+)?lines\b")

#: The package's own file count, taken only where it sits directly after the em
#: dash that opens the inventory. `— 14 hand-written library files` does not
#: match: the number must be the one immediately in front of `files`.
PKG_FILES = re.compile(r"—\s*(" + NUMBER + r")\s+files\b")
PKG_DART = re.compile(r"of\s+which\s+(" + NUMBER + r")\s+are\s+Dart\b")
#: `21 under `lib/``, `2 under `bin/``, `12 under `test/``, `4 under `example/``
#: -- Dart files only.
PKG_UNDER = re.compile(r"(" + NUMBER + r")\s+under\s+`(lib|bin|test|example)/`")
#: A parenthetical qualifying an `under `<folder>/`` mention, which is where the
#: line totals and hand-written file counts live.
#:
#: Every folder `PKG_UNDER` counts is read here too. The pair used to disagree --
#: a count under `bin/` was audited while the length beside it was not -- and the
#: asymmetry was invisible in exactly the way an unread figure always is: a boot
#: entrypoint's `(239 lines)` sat eleven lines stale beside a file count the gate
#: checked on every run. A `bin/` entrypoint and an `example/` program are
#: hand-written sources that decay as `lib/` does, so the same parenthetical is
#: read wherever it is written.
#:
#: The parenthetical must follow the folder *immediately*. It once did not, and
#: the scan would run past a folder that carried no parenthetical to whatever one
#: came next -- measuring `test/`'s figures against `lib/` if the two happened to
#: be written in that order with no bracket between them. Nothing in this set was
#: mis-read, which is the only kind of luck a loose pattern ever has.
PKG_SEGMENT = re.compile(r"under\s+`(lib|bin|test|example)/`\s*\(([^)]*)\)", re.S)
PKG_LINES = re.compile(r"(" + NUMBER + r")\s+(?:hand-written\s+)?lines")
#: `20 hand-written, 4 337 lines` -- a file count, not the line count beside it.
PKG_HAND = re.compile(r"(" + NUMBER + r")\s+hand-written(?!\s+lines)")
#: `5 are SQL migrations`, `1 is a SQL migration`. Singular and plural both, and
#: the verb between count and noun is what keeps `[001]-auth_authz_grants.sql`
#: and other prose near the word out of the measurement.
PKG_SQL = re.compile(
    r"(" + NUMBER + r")\s+(?:are|is)\s+(?:an?\s+)?SQL\s+migrations?\b"
)
#: `6 are assets`. The noun is bare on purpose. It used to be qualified --
#: `4 are runtime assets and 2 are JSON resource bundles` -- and the qualifier
#: is what made the sentence unaddable: the 2 bundles are a *subset* of the 6
#: files under `assets/`, stated as though they were a further 2, so the atoms
#: summed to 45 against a package of 44. A count deriveable from `git ls-files`
#: can only ever be "how many files are under `assets/`", so that is the only
#: figure the documents state as a number; any semantic split is written after
#: it, parenthesised and spelled out in words, where it is prose rather than a
#: claim -- see the `PKGINV` note in the module docstring.
PKG_ASSETS = re.compile(r"(" + NUMBER + r")\s+(?:are|is)\s+(?:an?\s+)?assets?\b")

TABLE_HEADER = re.compile(r"^\|\s*File\s*\|\s*Lines\s*\|")
TABLE_ROW = re.compile(r"^\|\s*`([^`]+)`\s*\|\s*(\d+)\s*\|", re.M)

# A sub-folder map row: a backticked folder, then any cells, then the count as
# the last one. The folder is required to end in `/` so that a `| Type | Wraps |`
# row -- the other four-column table in these documents -- cannot match.
MAP_HEADER = re.compile(r"^\|\s*Sub-folder\s*\|.*\|\s*Types\s*\|")
MAP_ROW = re.compile(r"^\|\s*`([\w/]+)/`\s*\|.*\|\s*(\d+)\s*\|\s*$", re.M)

# A public `Tom` class declaration. Mirrors `declarationPattern` in
# tom_flutter_ui/test/widgets/widget_census.dart -- see the module docstring.
DECLARATION = re.compile(
    r"^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|mixin\s+)*"
    r"class\s+(Tom\w+)(?:<[^>]*>)?\s*[^{]*\{",
    re.M,
)


def declared_types(folder: Path) -> set[str]:
    """Every `Tom` class declared under `folder`, recursively.

    Recursive because a sub-folder may nest one -- `containers/` holds `acl/`,
    and the map counts the pair as one entry.
    """
    names: set[str] = set()
    for source in sorted(folder.rglob("*.dart")):
        text = source.read_text(encoding="utf-8", errors="replace")
        names |= {m.group(1) for m in DECLARATION.finditer(text)}
    return names

#: Number-words, as the prose headers write small counts -- `two files`, `six
#: files`. A count spelled out is the same measurement as one in digits, and
#: reading only digits is what let four module headers go unaudited.
NUMBER_WORDS = {
    "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
    "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12,
    "thirteen": 13, "fourteen": 14, "fifteen": 15, "sixteen": 16,
    "seventeen": 17, "eighteen": 18, "nineteen": 19, "twenty": 20,
}

#: Compounds, because a module of twenty-three files says so in words. Written
#: out rather than assembled from the tens so the alternation stays a literal
#: list -- the same thing `_WORDS` is, and readable in a traceback.
NUMBER_WORDS |= {
    f"{ten}-{unit}": value + digit
    for ten, value in (("twenty", 20), ("thirty", 30), ("forty", 40))
    for unit, digit in list(NUMBER_WORDS.items())[:9]
}

#: Longest first, so `six` cannot win against `sixteen` -- and so `twenty-three`
#: wins against the `three` inside it, which is what a shorter-first alternation
#: would read and did: the `agent` module's `Twenty-three files` was measured as
#: three against a directory of twenty-four.
_WORDS = "|".join(sorted(NUMBER_WORDS, key=len, reverse=True))

#: A module header's file count, in whichever words the header used. Taken only
#: where the figure sits directly after the em dash that opens the header and
#: immediately in front of `files` -- the same discipline the package atoms
#: use, and what keeps `nine of the ten callers` out of the measurement.
#:
#: The noun matters: `source files` and `Dart files` say the readme is not in
#: the figure. A bare `files` leaves it open, and `counts_readme` settles it.
MODULE_FILES = re.compile(
    r"—\s*(" + NUMBER + r"|" + _WORDS + r")\s+(source\s+|Dart\s+)?files?\b",
    re.I,
)

#: A parenthetical that breaks the file count down and names the readme among
#: its parts -- `(10 Dart, 1 readme)`, `(24 Dart across 20 sub-folders, plus
#: the module readme)`. Its presence is the one signal that separates a bare
#: `N files` counting the readme from one counting only the sources, which the
#: documents otherwise write identically. A readme mentioned *outside* the
#: parenthetical is the opposite claim -- `14 source files plus a readme` sets
#: it beside the figure, not inside it -- so the match is anchored to the
#: parenthetical that immediately follows the count.
BREAKDOWN_README = re.compile(r"\s*\([^()]*readme[^()]*\)", re.I)

#: The module's line total. `~23 000 lines` is a rounded figure and is skipped:
#: a gate that demands an approximation be exact reports a fault every time.
MODULE_LINES = re.compile(r"(~\s*)?(" + NUMBER + r")\s+lines\b")

# Allows `\s+` between its words rather than a single space: the documents are
# hard-wrapped, so the claim routinely straddles a line break.
README_CLAIM = re.compile(r"`readme\.md`\s+\((\d+)\s+lines\)")

#: The standalone paragraph in which a *server* package document sizes its
#: library, written after the layout tree rather than inside the opening census:
#: ``lib/` totals 3 513 lines`, ``lib/` is 1 894 lines across nine files`.
#: Anchored at a line start so the phrase cannot be picked up mid-sentence.
LIB_TOTAL = re.compile(r"^`lib/`\s+(?:totals|is)\s+(" + NUMBER + r")\s+lines\b", re.M)

#: A file count in the same paragraph -- `across nine files`. Optional; only
#: `advanced_ops_server` states one.
LIB_FILES = re.compile(r"across\s+(" + NUMBER + r"|" + _WORDS + r")\s+files\b", re.I)

#: A per-file claim in the same paragraph, in the two hands the documents use:
#: ``app_endpoints.dart` is 1 748` and ``admin_endpoints.dart` 742`. The word
#: `lines` is not required, because the aggregate one sentence earlier has
#: already named the unit and repeating it reads badly; the backticked `.dart`
#: name immediately in front of the figure is what makes it a measurement.
LIB_FILE = re.compile(r"`([\w.]+\.dart)`\s+(?:is\s+)?(" + NUMBER + r")\b")


def line_count(path: Path) -> int:
    """Count lines the way ``wc -l`` does -- the tool the numbers came from."""
    return path.read_text(encoding="utf-8", errors="replace").count("\n")


def rewrite_groups(match: re.Match[str], values: dict[int, str]) -> tuple[int, int, str]:
    """Return the span of `match` and its text with numbered groups replaced.

    Groups are substituted back to front so that replacing one does not shift
    the offsets of the next.
    """
    text = match.group(0)
    start = match.start()
    for group in sorted(values, reverse=True):
        head = match.start(group) - start
        tail = match.end(group) - start
        text = text[:head] + values[group] + text[tail:]
    return match.start(), match.end(), text


class Report:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.faults: list[str] = []
        self.edits: list[tuple[int, int, str]] = []
        #: Spans of `text` an audit actually read a length out of. `PROSE`
        #: reports the line figures left over, so this is what separates a
        #: measurement the gate holds to the tree from one nothing checks.
        #: Recorded whether or not the figure faulted, and whether or not it
        #: was deliberately skipped: a hedged `~4 000 lines` was read and
        #: waived, which is a decision, not a gap.
        self.read: list[tuple[int, int]] = []

    def mark(self, span: tuple[int, int]) -> None:
        """Record that an audit consumed the length figure at `span`."""
        self.read.append(span)

    def was_read(self, start: int, end: int) -> bool:
        return any(s <= start and end <= e for s, e in self.read)

    @property
    def clean(self) -> bool:
        return not self.faults

    def render(self) -> str:
        rel = self.path.relative_to(DOCS_ROOT)
        return "\n".join([str(rel), *(f"    {f}" for f in self.faults)])

    def apply(self) -> None:
        """Write the pending measurements back, last edit first."""
        text = self.path.read_text(encoding="utf-8")
        for start, end, replacement in sorted(self.edits, reverse=True):
            text = text[:start] + replacement + text[end:]
        self.path.write_text(text, encoding="utf-8")


def audit(path: Path) -> Report | None:
    """Return a Report, or None if the document measures nothing.

    Five independent audits, any of which may find nothing to say: a document
    carries an opening header, a file inventory, a sub-folder map, a layout
    block, or none of them. The two layout audits run first and on their own
    terms, because a package document has a layout block and no module
    directory to resolve -- the two shapes describe different things and
    neither implies the other. They walk the block separately rather than
    sharing a pass: a row may carry a barrel label, a length, both or neither,
    and reading each claim where it falls costs one more walk of a thirty-line
    block.

    The header audit stands beside the table audit rather than inside it, which
    is where it used to sit. A document whose header states its size and whose
    body tabulates nothing -- four of them do -- was audited by nothing at all,
    and a document audited by nothing is reported as passing.
    """
    return audit_text(path.read_text(encoding="utf-8", errors="replace"), path)


def audit_text(text: str, path: Path) -> Report | None:
    """Run every audit over `text` as though it were the content of `path`.

    Split from :func:`audit` so the self-test can put a document through the
    whole chain after changing it in memory. ``PROSE`` is the one fault that
    cannot be exercised an audit at a time: it reports what the *others* did
    not read, so proving it still works means running all of them.
    """
    report = Report(path)
    measured = audit_barrel_exports(text, report)
    measured |= audit_layout_lines(text, report)
    measured |= audit_package_inventory(text, report)
    measured |= audit_library_size(text, report)
    measured |= audit_index_sections(text, report)

    module_match = MODULE_PATH.search(text)
    if module_match is not None:
        module = REPO_ROOT / module_match.group(1)
        if module.is_dir():
            measured |= audit_module_header(text, module, report)
            measured |= audit_file_inventory(text, module, report)
            measured |= audit_subfolder_map(text, module, report)

    # Last, and unconditionally: it reports the figures the audits above did
    # not mark, so it can only run once they have all had their say. It is
    # outside `measured` because it applies to a document that measures
    # nothing -- a document with no inventory is exactly where a stray length
    # in a sentence has nothing to be checked against.
    audit_prose_lengths(text, report)

    return report if measured or report.faults else None


def layout_rows(text: str, package: Path):
    """Yield `(path, start, end)` for every layout-block row that names a file.

    The block is an indented tree, so a file's directory is the chain of folder
    rows above it at smaller indents -- the same reading a person gives it. The
    root row names the package the tree is rooted at and is dropped, since
    `package` already points there. `start`/`end` bound the row in `text`, so a
    caller can look for its own label there and get a span `--fix` can write
    through.

    Indentation is the leading run of spaces *and* box-drawing characters, which
    is what makes the walk read a drawn tree and a space-indented one alike; the
    two hands differ only in what they fill the indent with. A row that names a
    folder is consumed into the stack rather than yielded -- it locates the rows
    below it, and its own labels are aggregates rather than facts about a file.

    A `text` fence is only walked when its first line names a directory. These
    documents also paste console transcripts into `text` fences, and a transcript
    walked as a tree yields a row per line, each "naming" whatever its first word
    happens to be. Nothing came of it so far only because no transcript line
    carries a label -- but one that printed `wrote 42 lines` would be read as a
    claim about a file called `wrote`. Requiring a root directory row also makes
    honest an assumption the walk already had: `stack[1:]` drops the first folder
    as the tree's root, which is only right if there is one.

    Two hands write a row's name in a way a bare `split()[0]` mis-reads, and both
    appear in these trees:

    - a trailing comment glued to the name with no space, `main.dart# the boot
      entrypoint`, which reads as a file called `main.dart#`;
    - a *listing* row that names several files at once, `build.yaml,
      reflection_generation.sh, pubspec.yaml`, whose first word reads as a file
      called `build.yaml,`.

    The comment is cut off; the listing row is dropped entirely rather than split.
    A listing is a row about a folder's leftovers, so it has no single file for a
    label beside it to describe -- and yielding its members would attach one row's
    label to each of them. Dropping it costs nothing a tree row would have given.
    """
    for fence in LAYOUT_FENCE.finditer(text):
        body, offset = fence.group(1), fence.start(1)
        rows = (line.lstrip(BRANCH).split() for line in body.splitlines())
        root = next((words[0] for words in rows if words), "")
        if not root.endswith("/"):
            continue
        stack: list[tuple[int, str]] = []
        position = offset
        for line in body.splitlines(keepends=True):
            rest = line.lstrip(BRANCH)
            indent = len(line) - len(rest)
            words = rest.split()
            # A comment wrapped onto its own line continues the row above: it
            # names nothing and, since its indent is the comment column rather
            # than a tree depth, must not disturb the folder stack either.
            if words and not words[0].startswith("#"):
                while stack and stack[-1][0] >= indent:
                    stack.pop()
                name = words[0].partition("#")[0]
                if name.endswith("/"):
                    stack.append((indent, name))
                elif name and not name.endswith(","):
                    # `stack[1:]` drops the tree's root line.
                    folders = "".join(f for _, f in stack[1:])
                    yield package / (folders + name), position, position + len(line)
            position += len(line)


def layout_package(text: str) -> Path | None:
    """The package a layout block is rooted at, or None if there is no block."""
    package_match = PACKAGE_PATH.search(text)
    if package_match is None:
        return None
    package = REPO_ROOT / package_match.group(1)
    return package if package.is_dir() else None


def audit_barrel_exports(text: str, report: Report) -> bool:
    """Check each layout-block barrel label against the file's export count.

    Returns whether the document has a layout block with labels at all.

    A row that calls a file a barrel and gives no count is itself a fault. It is
    not a wrong measurement -- it makes no claim, so nothing can drift -- but it
    is a barrel this audit cannot see, and every barrel that has been outside the
    guard for long enough has turned out to be wrong. Requiring the count is what
    makes the coverage total rather than equal to whichever labels somebody
    happened to write in the counted style.
    """
    package = layout_package(text)
    if package is None:
        return False

    found = False
    for path, start, end in layout_rows(text, package):
        label = BARREL_LABEL.search(text, start, end)
        if label is None:
            bare = BARE_BARREL.search(text, start, end)
            if bare is not None and path.is_file():
                found = True
                shown = path.relative_to(package)
                actual = len(EXPORT.findall(path.read_text(encoding="utf-8", errors="replace")))
                report.faults.append(
                    f"BARREL   `{shown}` is called a barrel without a count"
                )
                report.edits.append(
                    rewrite_groups(bare, {1: f"barrel — {actual} exports"})
                )
            continue
        found = True
        shown = path.relative_to(package)
        if not path.is_file():
            report.faults.append(
                f"BARREL   `{shown}` is not in {package.name}/"
            )
            continue
        source = path.read_text(encoding="utf-8", errors="replace")
        actual = len(EXPORT.findall(source))
        claimed = int(label.group(1))
        if actual != claimed:
            report.faults.append(
                f"BARREL   `{shown}` says {claimed} exports, has {actual}"
            )
            report.edits.append(rewrite_groups(label, {1: str(actual)}))
    return found


def audit_layout_lines(text: str, report: Report) -> bool:
    """Check each layout-block row against the file it names: that the file is
    there, and -- where the row carries one -- that its length claim is true.

    Returns whether the document draws such a block at all.

    The length claims are the same measurement the inventory tables carry,
    written beside a row instead of in a column, and they decay the same way --
    two consecutive dartdoc edits falsified four of them here before anything
    read them.

    Existence is checked on *every* row, not only on the rows that carry a
    length. It used to be checked only on those, which made the drawn tree of a
    package whose files are labelled nowhere -- an asset folder, a sample with a
    flat `lib/` -- an inventory nothing read: a renamed file left a row naming a
    path that had not existed for weeks, and the document still passed. The row
    names a file whether or not it also measures it, and naming one that is not
    there is the plainer error of the two.
    """
    package = layout_package(text)
    if package is None:
        return False

    found = False
    for path, start, end in layout_rows(text, package):
        found = True
        shown = path.relative_to(package)
        if not path.exists():
            report.faults.append(f"LAYOUT   `{shown}` is not in {package.name}/")
            continue
        claim = LAYOUT_LINES.search(text, start, end)
        if claim is not None:
            report.mark(claim.span())
        # A rounded figure is a deliberate approximation, not a measurement.
        if claim is None or claim.group(1) or claim.group(3):
            continue
        written = claim.group(2)
        measured = line_count(path)
        if as_number(written) != measured:
            report.faults.append(
                f"LINES    `{shown}` says {written.strip()}, is {measured}"
            )
            report.edits.append(
                rewrite_groups(claim, {2: like(written, measured)})
            )
    return found


def tracked_files(package: Path) -> list[str] | None:
    """The package's git-tracked files, which is what the inventories count.

    ``git ls-files`` rather than a directory walk, because the counts are meant
    to describe the package as it is committed -- build output under
    ``.dart_tool`` and a scratch file are not part of its shape. Returns
    None when git cannot answer, so the audit stays silent rather than
    reporting every atom as wrong.
    """
    try:
        result = subprocess.run(
            ["git", "ls-files"],
            cwd=package,
            capture_output=True,
            text=True,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    return result.stdout.split()


def as_number(written: str) -> int:
    """Read a grouped figure (``4 337``) as an integer."""
    return int(re.sub(r"\D", "", written))


def like(written: str, value: int) -> str:
    """Render `value` in the grouping style `written` used.

    A document that writes ``4 337`` keeps its thin space when the figure is
    repaired; one that writes ``619`` stays bare. Without this, ``--fix`` would
    slowly normalise the prose to whatever the tool happened to prefer.
    """
    separator = next((c for c in written if not c.isdigit()), "")
    if not separator or len(str(value)) <= 3:
        return str(value)
    digits = str(value)
    head = len(digits) % 3 or 3
    rest = [digits[i:i + 3] for i in range(head, len(digits), 3)]
    return separator.join([digits[:head], *rest])


def as_count(written: str) -> int:
    """Read a header's file count, written either as digits or as a word."""
    word = NUMBER_WORDS.get(written.strip().lower())
    return as_number(written) if word is None else word


#: The inverse of `NUMBER_WORDS`, so a count spelled out can be repaired
#: spelled out. Built from the map rather than beside it, because a second list
#: is a second thing to keep in step.
_NUMBER_WORD = {value: word for word, value in reversed(NUMBER_WORDS.items())}


def as_written(written: str, value: int) -> str:
    """Render `value` the way `written` was written.

    A figure keeps its grouping, and a count spelled out stays spelled out with
    its capitalisation: the index sections open sentences with their count, so
    turning `Twelve files` into `13 files` would mid-sentence a figure that the
    prose deliberately wrote in words. Only a value with no word for it falls
    back to digits -- above twenty the documents write digits anyway.
    """
    stripped = written.strip()
    if stripped.lower() in NUMBER_WORDS:
        word = _NUMBER_WORD.get(value)
        if word is None:
            return str(value)
        return word.capitalize() if stripped[:1].isupper() else word
    return like(written, value)


def module_files(module: Path) -> list[Path]:
    """The files a module header counts.

    Recursed only when the module has sub-folders. A module whose sources sit
    in one directory is counted flat; one that groups them -- `widgets/` across
    20 sub-folders, `forms/` across nine -- is counted through, because that is
    what its header says it holds.
    """
    if any(p.is_dir() for p in module.iterdir()):
        return sorted(p for p in module.rglob("*") if p.is_file())
    return sorted(p for p in module.iterdir() if p.is_file())


def audit_module_header(text: str, module: Path, report: Report) -> bool:
    """Check the opening paragraph's file and line counts against the module.

    Returns whether the header makes a countable claim at all.

    Bounded to the paragraph the module path opens, for the reason the package
    inventory is: later paragraphs describe the same module in prose full of
    numbers, and one of them will eventually read `4 files` about something
    else.
    """
    path_match = MODULE_PATH.search(text)
    if path_match is None:
        return False
    start = text.rfind("\n\n", 0, path_match.start()) + 2
    blank = text.find("\n\n", path_match.start())
    end = len(text) if blank < 0 else blank

    files = MODULE_FILES.search(text, start, end)
    if files is None:
        return False

    on_disk = module_files(module)
    dart = [p for p in on_disk if p.suffix == ".dart"]
    counted, noun = counted_files(text, files, end, module)

    written = files.group(1)
    if as_count(written) != len(counted):
        report.faults.append(
            f"HEADER   says {written.strip()} {noun}; is {len(counted)}"
        )
        report.edits.append(
            rewrite_groups(files, {1: as_written(written, len(counted))})
        )

    # The line total always counts the sources: no header in this set totals
    # its readme in with them, and several name the readme's length separately.
    lines = MODULE_LINES.search(text, files.end(), end)
    if lines is not None:
        report.mark(lines.span())
    if lines is not None and not lines.group(1):
        total = lines.group(2)
        measured = sum(line_count(p) for p in dart)
        if as_number(total) != measured:
            report.faults.append(
                f"HEADER   says {total.strip()} lines; is {measured}"
            )
            report.edits.append(rewrite_groups(lines, {2: like(total, measured)}))

    readme = README_CLAIM.search(text, start, end)
    if readme is not None:
        report.mark(readme.span())
    on_disk_readme = next((p for p in on_disk if p.name == "readme.md"), None)
    if readme is not None and on_disk_readme is not None:
        measured = line_count(on_disk_readme)
        if int(readme.group(1)) != measured:
            report.faults.append(
                f"HEADER   says readme.md is {readme.group(1)} lines; is {measured}"
            )
            report.edits.append(rewrite_groups(readme, {1: str(measured)}))

    return True


def audit_package_inventory(text: str, report: Report) -> bool:
    """Check the opening inventory of a package document against the package.

    Only the atoms whose meaning is unambiguous are measured -- see ``PKGINV``
    in the module docstring for why the patterns are as tight as they are.
    Returns whether this document has a package inventory at all.
    """
    package_match = PACKAGE_PATH.search(text)
    if package_match is None:
        return False
    package = REPO_ROOT / package_match.group(1)
    if not (package / "pubspec.yaml").is_file():
        return False

    # The inventory is the paragraph the package path opens, and nothing after
    # it: later paragraphs describe the same package in prose full of numbers.
    # The patterns are bounded to that span rather than run against a slice, so
    # every match offset is absolute and can be handed straight to `--fix`.
    start = package_match.start()
    blank = text.find("\n\n", start)
    end = len(text) if blank < 0 else blank

    file_claim = PKG_FILES.search(text, start, end)
    dart_claim = PKG_DART.search(text, start, end)
    if file_claim is None and dart_claim is None:
        return False

    files = tracked_files(package)
    if files is None:
        return False
    dart = [f for f in files if f.endswith(".dart")]

    def under(folder: str) -> list[str]:
        return [f for f in dart if f.startswith(f"{folder}/")]

    def handwritten(paths: list[str]) -> list[str]:
        return [p for p in paths if not p.endswith(".reflection.dart")]

    # (claim, measured, what the number counts)
    claims: list[tuple[re.Match[str], int, str]] = []
    if file_claim is not None:
        claims.append((file_claim, len(files), "files"))
    if dart_claim is not None:
        claims.append((dart_claim, len(dart), "Dart files"))
    stated = set()
    for match in PKG_UNDER.finditer(text, start, end):
        folder = match.group(2)
        stated.add(folder)
        noun = f"Dart files under {folder}/"
        claims.append((match, len(under(folder)), noun))

    # A census states every part of the package that has one. Checking only the
    # parts it happens to mention makes the audit exactly as complete as the
    # sentence is, which is the wrong way round: a package that *gains* a
    # `bin/` or a first migration would keep a census that is silent about it
    # and go on passing. What a document may leave out is a part the package
    # does not have.
    for folder in ("lib", "bin", "test", "example"):
        if under(folder) and folder not in stated:
            report.faults.append(
                f"PKGINV   says nothing about the "
                f"{len(under(folder))} Dart files under {folder}/"
            )

    for pattern, present, noun in (
        (PKG_SQL, [f for f in files if f.endswith(".sql")], "SQL migrations"),
        (PKG_ASSETS, [f for f in files if f.startswith("assets/")], "assets"),
    ):
        match = pattern.search(text, start, end)
        if match is not None:
            claims.append((match, len(present), noun))
        elif present:
            report.faults.append(
                f"PKGINV   says nothing about the {len(present)} {noun}"
            )

    for segment in PKG_SEGMENT.finditer(text, start, end):
        folder = segment.group(1)
        hand = handwritten(under(folder))
        body, tail = segment.start(2), segment.end(2)
        for match in PKG_LINES.finditer(text, body, tail):
            report.mark(match.span())
            total = sum(line_count(package / p) for p in hand)
            claims.append((match, total, f"hand-written lines under {folder}/"))
        for match in PKG_HAND.finditer(text, body, tail):
            claims.append(
                (match, len(hand), f"hand-written files under {folder}/")
            )

    for match, measured, noun in claims:
        written = match.group(1)
        if as_number(written) == measured:
            continue
        report.faults.append(
            f"PKGINV   says {written.strip()} {noun}; is {measured}"
        )
        report.edits.append(rewrite_groups(match, {1: like(written, measured)}))
    return True


def audit_library_size(text: str, report: Report) -> bool:
    """Check the standalone ``lib/`` size paragraph against the package.

    Returns whether the document has such a paragraph at all.

    Three of the eight package documents state their library's length here,
    after the layout tree, rather than in the opening census -- ``lib/` totals
    3 513 lines, of which `app_endpoints.dart` is 1 748`. It is the same
    measurement the census parenthetical carries elsewhere, in a different place
    and a different grammar, and a gate scoped to the census alone would leave
    all of it unread. That is not a hypothetical gap: when this audit first ran,
    four of the six figures in these three paragraphs were stale, one of them a
    regression introduced by two documentation todos that had each checked their
    collateral for `file.dart:NNN` *citations* and neither for line *counts*.

    **The denominator is `lib/**`, not `lib/src/**`.** That is the one detail
    worth stating, because getting it wrong is silent and plausible: every one
    of these packages has a barrel outside `lib/src/`, so a `lib/src/`-only sum
    is always a little smaller and always looks like a believable answer.
    `advanced_auth_server`'s figure was wrong the day it was written for exactly
    that reason -- a `lib/src/` count published under the label `lib/`, dropping
    the 21-line barrel -- and it survived several passes because a reviewer
    spot-checking `lib/src/` reproduces the printed number and concludes it is
    fine. A gate recomputing from `lib/src/` would ratify the bug it exists to
    catch.

    Generated code is excluded, as it is everywhere else here. No server package
    has a `*.reflection.dart` under `lib/` today, so the two readings agree; they
    would stop agreeing the moment one gained a reflection seed, and a 90 000-line
    generated file is not what any of these sentences means by "totals".
    """
    package = layout_package(text)
    if package is None:
        return False
    total = LIB_TOTAL.search(text)
    if total is None:
        return False

    # The paragraph the claim opens: later paragraphs discuss the same library
    # in prose, and one of them names a file beside a number that is not its
    # length -- `app_endpoints.dart:1527` is a citation, not a measurement.
    blank = text.find("\n\n", total.start())
    end = len(text) if blank < 0 else blank

    tracked = tracked_files(package)
    if tracked is None:
        return False
    sources = [
        f for f in tracked
        if f.startswith("lib/") and f.endswith(".dart")
        and not f.endswith(".reflection.dart")
    ]
    measured = sum(line_count(package / f) for f in sources)
    report.mark(total.span())
    written = total.group(1)
    if as_number(written) != measured:
        report.faults.append(
            f"LIBSIZE  says lib/ totals {written.strip()} lines; is {measured}"
        )
        report.edits.append(rewrite_groups(total, {1: like(written, measured)}))

    count = LIB_FILES.search(text, total.end(), end)
    if count is not None and as_count(count.group(1)) != len(sources):
        report.faults.append(
            f"LIBSIZE  says lib/ is {count.group(1).strip()} files;"
            f" is {len(sources)}"
        )
        report.edits.append(
            rewrite_groups(count, {1: as_written(count.group(1), len(sources))})
        )

    by_name = {f.rsplit("/", 1)[-1]: f for f in sources}
    for claim in LIB_FILE.finditer(text, total.end(), end):
        report.mark(claim.span())
        name = claim.group(1)
        source = by_name.get(name)
        if source is None:
            report.faults.append(f"LIBSIZE  `{name}` is not under lib/")
            continue
        length = line_count(package / source)
        if as_number(claim.group(2)) != length:
            report.faults.append(
                f"LIBSIZE  `{name}` says {claim.group(2).strip()}; is {length}"
            )
            report.edits.append(
                rewrite_groups(claim, {2: like(claim.group(2), length)})
            )
    return True


def audit_subfolder_map(text: str, module: Path, report: Report) -> bool:
    """Check each map row's type count against the sub-folder it names.

    Returns whether the document has a map at all.
    """
    rows: dict[str, re.Match[str]] = {}
    in_table = False
    position = 0
    for line in text.splitlines(keepends=True):
        if MAP_HEADER.match(line):
            in_table = True
        elif in_table and not line.startswith("|"):
            in_table = False
        elif in_table:
            row = MAP_ROW.match(text, position)
            if row:
                rows[row.group(1)] = row
        position += len(line)
    if not rows:
        return False

    for name, match in sorted(rows.items()):
        folder = module / name
        if not folder.is_dir():
            report.faults.append(f"COUNT    `{name}/` is not in {module.name}/")
            continue
        actual = len(declared_types(folder))
        claimed = int(match.group(2))
        if actual != claimed:
            report.faults.append(
                f"COUNT    `{name}/` says {claimed} types, has {actual}"
            )
            report.edits.append(rewrite_groups(match, {2: str(actual)}))

    for folder in sorted(p for p in module.iterdir() if p.is_dir()):
        if folder.name not in rows:
            report.faults.append(
                f"COUNT    `{folder.name}/` is on disk, not in the map"
            )
    return True


def audit_file_inventory(text: str, module: Path, report: Report) -> bool:
    """Check the `| File | Lines |` table against the module directory.

    Returns whether the document has such a table at all.
    """
    # Rows are recognised only between a `| File | Lines |` header and the end
    # of its table, so a backticked filename in some unrelated table elsewhere
    # in the document is not mistaken for part of the inventory.
    # Rows are matched against the whole text at the line's own offset, so the
    # match carries a span `--fix` can write through.
    rows: dict[str, re.Match[str]] = {}
    in_table = False
    position = 0
    for line in text.splitlines(keepends=True):
        if TABLE_HEADER.match(line):
            in_table = True
        elif in_table and not line.startswith("|"):
            in_table = False
        elif in_table:
            row = TABLE_ROW.match(text, position)
            if row:
                rows[row.group(1)] = row
        position += len(line)
    if not rows:
        return False

    on_disk = {p.name: p for p in sorted(module.iterdir()) if p.is_file()}

    for name, match in sorted(rows.items()):
        actual = on_disk.get(name)
        if actual is None:
            report.faults.append(f"UNKNOWN  `{name}` is not in {module.name}/")
            continue
        measured = line_count(actual)
        claimed = int(match.group(2))
        if measured != claimed:
            report.faults.append(f"LINES    `{name}` says {claimed}, is {measured}")
            report.edits.append(rewrite_groups(match, {2: str(measured)}))

    for name in on_disk:
        if name not in rows:
            report.faults.append(f"ABSENT   `{name}` is on disk, not in the table")

    return True


#: A length written into running text: `250 lines`, `1 892 lines`, `a 740-line
#: backend`, `one 255-line screen`, `~335k lines`. All of these are one pattern
#: because they are one claim -- hyphenating it before a noun, or rounding it to
#: thousands, is a writer's choice, and a rule that caught only the longest
#: spelling would be evaded by the shorter ones.
#:
#: What it cannot catch is a length with the noun elided -- `the seven in
#: `file_storage/` (2 602 lines) plus `file_reference.dart` (93)`, where `(93)`
#: is a line count only because the reader carries the noun forward. Nothing
#: distinguishes that from any other parenthesised number, so the rule does not
#: try; the sentence it came from was rewritten by hand instead.
PROSE_LENGTH = re.compile(
    r"(?<![\w.])(" + NUMBER + r")\s*[kK]?\s*[-‑]?\s*lines?\b"
)

#: A count of lines used as a *distance* rather than a size -- `120 lines
#: further down`, `three lines above`. It measures the document the reader is
#: holding, not an artifact on disk, so there is nothing to re-measure it
#: against and reporting it would be a false positive. A gate held at zero
#: earns its zero only if every fault it raises is real, so the exemption is
#: keyed to the words that make the number a direction.
PROSE_EXEMPT = re.compile(
    NUMBER + r"\s*[-‑]?\s*lines?\s+"
    r"(?:further\s+)?(?:down|up|below|above|later|earlier|on|back)\b",
    re.I,
)


def prose_spans(text: str):
    """Yield `(start, end)` for each length figure in running text.

    Fenced blocks and table rows are excluded because they are the two shapes
    the other audits already read: a layout row's length is `LINES`/`LAYOUT`'s
    business and an inventory cell's is `LINES`'. What is left is prose, which
    is the position this audit exists for.

    The scan runs over the whole document with the excluded lines blanked out,
    rather than line by line, because these documents are hard-wrapped and a
    figure breaks across the wrap: ``Nine files and 3 359\\nlines`` is one
    claim written on two lines, and a per-line reader sees no measurement at
    all. Blanking preserves every offset, so the spans stay the document's own.
    """
    keep: list[str] = []
    fenced = False
    for line in text.splitlines(keepends=True):
        stripped = line.lstrip()
        if stripped.startswith("```"):
            fenced = not fenced
            keep.append(" " * len(line))
        elif fenced or stripped.startswith("|"):
            keep.append(" " * len(line))
        else:
            keep.append(line)
    prose = "".join(keep)

    for match in PROSE_LENGTH.finditer(prose):
        # Anchored at the figure and reading forward: the words that turn a
        # count into a direction follow it. Newlines count as spaces here, so
        # a wrapped `120 lines\nfurther down` is exempted like the flat one.
        if PROSE_EXEMPT.match(prose, match.start()):
            continue
        yield match.start(), match.end()


def audit_prose_lengths(text: str, report: Report) -> None:
    """Report every length figure in prose that no other audit read.

    This is the counterpart to every audit above, and it is defined by them
    rather than by a pattern of its own: a figure faults precisely when nothing
    marked it. That is what makes the rule maintainable -- widening any audit
    to cover a new position narrows this one automatically, with no second
    place to update and no chance of the two disagreeing about what is covered.

    The rule it enforces is that a file's length is stated where a gate holds
    it to the file -- an inventory table's `Lines` column, a layout row, or the
    census the document opens with -- and nowhere else. A length written into a
    sentence is a copy with no check behind it, and copies drift: a document
    here said `239 lines` of a file that had been 250 for four commits, and the
    gate ran green over it every time, because a measurement in a sentence sat
    in the one position nothing parsed.

    It is not reported as a wrong number, because usually it is not one yet.
    It is reported as a measurement in a position that cannot be maintained.
    """
    for start, end in prose_spans(text):
        if report.was_read(start, end):
            continue
        quoted = text[start:end].strip()
        line = text.count("\n", 0, start) + 1
        report.faults.append(
            f"PROSE    line {line}: `{quoted}` is a length no gate can check;"
            f" state it in the inventory or drop the number"
        )


def census_module(text: str) -> Path | None:
    """The module a document's census measures, or None if it measures a package.

    A package document's figures are about `lib/` and `test/` trees, counted by
    the package atoms and in nouns of their own -- hand-written lines, files
    under a folder. They are not module headers and must not be read as one, so
    a document whose first path reference is a package path is declined here
    rather than half-understood: `tom_core_codespecs` opens on
    ``tom_core_codespecs/lib/`` and mentions a module path only much later, and
    reading that later path would measure a directory the census never spoke
    about.
    """
    module = MODULE_PATH.search(text)
    if module is None:
        return None
    package = PACKAGE_PATH.search(text)
    if package is not None and package.start() < module.start():
        return None
    path = REPO_ROOT / module.group(1)
    return path if path.is_dir() else None


def counted_files(
    text: str, files: re.Match[str], end: int, module: Path
) -> tuple[list[Path], str]:
    """The files a ``N files`` claim counts, and the noun it counted them in.

    The noun is the claim: `source files` and `Dart files` exclude the module
    readme, a bare `files` includes it -- but only when a breakdown says so,
    since the documents write both meanings identically. Shared by the header
    audit and the index audit so the rule is stated once; the index restates
    the header's figure, and a restatement read by a different rule than the
    original would drift by construction.
    """
    on_disk = module_files(module)
    if (files.group(2) or "").strip():
        return [p for p in on_disk if p.suffix == ".dart"], "source files"
    if BREAKDOWN_README.match(text, files.end(), end) is not None:
        return on_disk, "files"
    return [p for p in on_disk if p.suffix == ".dart"], "source files"


#: An index entry: a level-four heading naming the module or package, the link
#: line to its completion document, and the paragraph that summarises it. The
#: paragraph is the one the entry's figures live in; later ones describe the
#: same module in prose full of numbers, exactly as in a completion document,
#: and are left alone for the same reason.
INDEX_SECTION = re.compile(
    r"^#### +`[^`]+`\s*\n+\[`([^`]+\.md)`\]\([^)]*\)\s*\n+(.+?)(?=\n\n|\Z)",
    re.M | re.S,
)

#: The entry's file count. Unlike `MODULE_FILES` this is not anchored to an em
#: dash: an index entry writes its count in whatever grammar the sentence wants
#: -- ``across six files``, ``Twelve files, all exported``, ``in nine files``.
#: The anchor that replaces it is the comparison itself. The figure is checked
#: against the linked document's own count rather than against a directory, so
#: a mis-read number is a number that disagrees with a *document*, not with a
#: convention this regex would otherwise have to encode.
#:
#: One adjective is allowed between the count and the noun. An index entry is
#: prose and writes ``three small files`` where a census would write ``3 source
#: files``; without the slot that entry was read as making no claim at all,
#: which is how it came to say three about a directory of four.
INDEX_FILES = re.compile(
    r"\b(" + NUMBER + r"|" + _WORDS + r")\s+(source\s+|Dart\s+)?(?:[a-z]+\s+)?files?\b",
    re.I,
)

#: ``nine Dart files besides the barrel`` counts one fewer than the directory
#: holds. The phrase is the entry's own arithmetic, stated plainly, and reading
#: it is cheaper than rewriting two entries to drop it. `\s+` between the words
#: because the documents are hard-wrapped and both uses of it straddle a line
#: break -- a literal space matched neither, and the audit read both entries as
#: understating a count they state exactly.
BESIDES_BARREL = re.compile(r"\s*(?:,[^.]*?)?\bbesides\s+the\s+barrel\b")

#: The entry's line total, in the two shapes the index uses: ``4118 lines`` and
#: ``one 808-line file``. An approximation is skipped -- ``~``, and ``roughly``,
#: which `MODULE_LINES` does not know because no census hedges but three index
#: entries do.
INDEX_LINES = re.compile(
    r"(~\s*|\broughly\s+)?(" + NUMBER + r")[\s-]+lines?\b|"
    r"(~\s*|\broughly\s+)?(" + NUMBER + r")-line\b"
)


def index_claims(
    text: str, start: int, end: int, report: Report | None = None
) -> dict[str, re.Match[str]]:
    """The figures an index entry states, by name.

    Both are optional and most entries state one or neither: an entry is prose
    first, and only says a number where the number is the point. Matched in
    `text` rather than in a slice of it so the spans are the document's own and
    `--fix` can write through them.

    Only the *first* line figure counts, and only if it is not an
    approximation. An entry that leads with a rounded total has hedged its
    measurement deliberately and the audit takes it at its word rather than
    reaching past it for the next number, which would be a figure about
    something else.
    """
    claims: dict[str, re.Match[str]] = {}
    files = INDEX_FILES.search(text, start, end)
    if files is not None:
        claims["files"] = files
    lines = INDEX_LINES.search(text, start, end)
    if lines is not None:
        # Marked even when hedged and dropped below: an entry that says
        # `roughly 4 000 lines` was read and waived on purpose, so `PROSE`
        # must not then report it as a figure nothing checks.
        if report is not None:
            report.mark(lines.span())
        if not (lines.group(1) or lines.group(3)):
            claims["lines"] = lines
    return claims


def audit_index_sections(text: str, report: Report) -> bool:
    """Check each index entry's figures against the document it links to.

    Returns whether the document is an index at all.

    The overview restates every module's size beside its link, which is what
    makes it usable as an index -- and what makes it drift. The figure is a
    *copy*, sitting a thousand lines away from the census it copies, and
    nothing until now read the two together: the header audit stops at the
    first module path in a document, so an index of seventy-nine of them was
    audited once and then not at all.

    The entry is measured against the module, not against the wording of the
    census it copies. Comparing text to text is the tempting reading -- the
    fault class *is* a copy drifting from its original -- but the two are
    written in different nouns and the comparison would be invalid where it
    matters most: `widgets/` is ``25 files (24 Dart ..., plus the module
    readme)`` in its own document and ``24 Dart files`` in the index, and both
    are right. Measuring each claim in the noun it was written in makes the two
    audits agree by construction, and the entry is then wrong only when it is
    actually wrong.

    Only entries linking to a module document are read. A package entry states
    figures about `lib/` and `test/` trees in the package atoms' vocabulary,
    which this audit does not speak; declining them is a coverage limit, not a
    silent pass, and `audit_package_inventory` covers the same figures where
    they are stated in the package's own document.
    """
    sections = list(INDEX_SECTION.finditer(text))
    if not sections:
        return False

    for section in sections:
        linked = DOCS_ROOT / section.group(1)
        if not linked.is_file():
            report.faults.append(f"INDEX    `{section.group(1)}` is not a document")
            continue
        module = census_module(linked.read_text(encoding="utf-8", errors="replace"))
        if module is None:
            continue
        end = section.end(2)
        claims = index_claims(text, section.start(2), end, report)

        claim = claims.get("files")
        if claim is not None:
            counted, noun = counted_files(text, claim, end, module)
            measured = len(counted)
            if BESIDES_BARREL.match(text, claim.end(), end) is not None:
                measured -= 1
                noun = f"{noun} besides the barrel"
            if as_count(claim.group(1)) != measured:
                report.faults.append(
                    f"INDEX    `{section.group(1)}` says"
                    f" {claim.group(1).strip()} {noun}; is {measured}"
                )
                report.edits.append(
                    rewrite_groups(claim, {1: as_written(claim.group(1), measured)})
                )

        claim = claims.get("lines")
        if claim is not None:
            group = 2 if claim.group(2) is not None else 4
            measured = sum(
                line_count(p) for p in module_files(module) if p.suffix == ".dart"
            )
            if as_number(claim.group(group)) != measured:
                report.faults.append(
                    f"INDEX    `{section.group(1)}` says"
                    f" {claim.group(group).strip()} lines; is {measured}"
                )
                report.edits.append(
                    rewrite_groups(claim, {group: like(claim.group(group), measured)})
                )

    return True


#: The numeric claims the self-test proves this checker can still catch.
#:
#: Each case names a pattern that finds one figure, the group holding its
#: number, the audit that is supposed to notice when that number is wrong, and
#: -- where the figure is only meaningful inside a larger construct -- the
#: pattern whose match bounds the search. A per-file length is a measurement
#: only inside a layout fence, and a line total only inside the parenthesis of
#: a census segment; perturbing the first such-looking number anywhere in the
#: document would otherwise hit running prose and prove nothing.
SELF_TEST_CASES: list[tuple[str, re.Pattern[str], int, str, re.Pattern[str] | None]] = [
    ("census file count", PKG_FILES, 1, "audit_package_inventory", None),
    ("census Dart count", PKG_DART, 1, "audit_package_inventory", None),
    ("census directory split", PKG_UNDER, 1, "audit_package_inventory", None),
    ("census line total", PKG_LINES, 1, "audit_package_inventory", PKG_SEGMENT),
    ("per-file line label", LAYOUT_LINES, 2, "audit_layout_lines", LAYOUT_FENCE),
]


def perturb(
    text: str, pattern: re.Pattern[str], group: int, within: re.Pattern[str] | None
) -> str | None:
    """Return `text` with one figure raised by one, or None if none was found.

    Raised rather than lowered because a count is never negative and a figure
    of zero is common: subtracting one could produce a number no writer would
    have written, and a checker that only rejects the impossible is not the
    same as one that reads the value.
    """
    region = text if within is None else None
    start = 0
    if within is not None:
        bounds = within.search(text)
        if bounds is None:
            return None
        start, region = bounds.start(), bounds.group(0)

    match = pattern.search(region)
    if match is None:
        return None
    at = start + match.start(group)
    to = start + match.end(group)
    return text[:at] + like(match.group(group), as_number(match.group(group)) + 1) + text[to:]


def self_test_prose(documents: list[Path]) -> list[str]:
    """Prove ``PROSE`` still reports a length written into a sentence.

    The perturbation above raises a number and asks whether an audit notices.
    That shape cannot exercise this fault, because a ``PROSE`` fault is not a
    wrong number -- every figure in the corpus could be correct and the fault
    would still be the right one to raise. So this perturbs the other way: it
    *adds* a sentence carrying a length to a document that audits clean, and
    requires exactly one new fault naming it.

    Exactly one, not at least one, is the load-bearing part, and it is why the
    document is chosen rather than taken. ``PROSE`` reports the figures no
    other audit marked, so if the instrumentation in those audits stopped
    recording spans, the document's own census and index figures would start
    faulting and the count would jump. That only proves anything in a document
    that *has* such figures: run against one whose every length sits in a
    table, disabling every ``mark()`` call changes nothing and the case passes
    while reading nothing. So the document picked is the clean one carrying the
    most marked prose figures -- the one where the instrumentation is doing the
    most work, and therefore the one where its absence shows.

    The second case is the exemption, checked in the negative. ``120 lines
    further down`` measures the document a reader is holding rather than a file
    on disk, so there is nothing to re-measure it against and reporting it
    would be a false positive. A gate held at a baseline of zero earns that
    zero only if every fault it raises is real, which makes the exemption worth
    as much as the rule -- and worth a test that fails if someone widens the
    pattern past it.
    """
    best: tuple[int, Path, str] | None = None
    for path in documents:
        text = path.read_text(encoding="utf-8", errors="replace")
        report = audit_text(text, path)
        if report is None or not report.clean:
            continue
        marked = sum(1 for s, e in prose_spans(text) if report.was_read(s, e))
        if best is None or marked > best[0]:
            best = (marked, path, text)

    if best is None:
        return ["prose length: no document audits clean, so nothing exercises it"]

    marked, path, text = best
    failures: list[str] = []
    if marked == 0:
        failures.append(
            "prose length: no clean document carries a marked prose figure, so "
            "nothing would notice if the audits stopped recording what they read"
        )

    reported = audit_text(text + "\n\nA sentence claiming 4242 lines.\n", path)
    assert reported is not None
    if len(reported.faults) != 1 or "4242" not in reported.faults[0]:
        failures.append(
            f"prose length: adding `4242 lines` to {path.name} produced "
            f"{len(reported.faults)} faults, not one naming it -- either the "
            f"rule stopped reading prose or an audit stopped marking what it read"
        )
    else:
        print(f"  ok  prose length — caught in {path.name} ({marked} marked)")

    exempt = audit_text(text + "\n\nSee 120 lines further down.\n", path)
    assert exempt is not None
    if not exempt.clean:
        failures.append(
            f"prose distance: adding `120 lines further down` to {path.name} "
            f"raised {exempt.faults[0]}, but a count of lines used as a "
            f"direction measures no file and must be exempt"
        )
    else:
        print(f"  ok  prose distance exemption — held in {path.name}")

    return failures


def self_test() -> int:
    """Prove each audit still fails a document whose figures are wrong.

    The gate suite asserts that every checker sits at its recorded baseline,
    which a checker that has quietly stopped reading anything also satisfies --
    it reports zero faults, matches a zero baseline, and passes. That is not a
    hypothetical failure mode. Eleven wrong figures once stood across six of
    the sample documents while this gate held at its baseline both before and
    after they were corrected, because at the time it read neither the census
    sentences nor the per-file lengths those figures lived in.

    So this asks the opposite question from the gate: not "does the corpus
    pass" but "would it still fail if it were wrong". For each family of claim
    it finds a document that carries one and currently audits clean, raises a
    single figure by one in memory -- nothing on disk is touched -- and
    requires the audit to report a fault. A case that finds no document to
    perturb fails too: coverage that has nothing to run on is not coverage.
    """
    documents = sorted(DOCS_ROOT.glob("*.md"))
    failures: list[str] = []

    for name, pattern, group, audit_name, within in SELF_TEST_CASES:
        run = globals()[audit_name]
        for path in documents:
            text = path.read_text(encoding="utf-8", errors="replace")
            # The document must carry this claim and be right about it, or a
            # fault after perturbing proves nothing -- it was already there.
            clean = Report(path)
            if not run(text, clean) or not clean.clean:
                continue
            wrong = perturb(text, pattern, group, within)
            if wrong is None:
                continue
            caught = Report(path)
            run(wrong, caught)
            if caught.clean:
                failures.append(
                    f"{name}: {audit_name} passed {path.name} after one figure "
                    f"was raised by one, so it is no longer reading that claim"
                )
            else:
                print(f"  ok  {name} — caught in {path.name}")
            break
        else:
            failures.append(
                f"{name}: no document carries this claim, so nothing exercises "
                f"{audit_name} for it"
            )

    failures += self_test_prose(documents)
    families = len(SELF_TEST_CASES) + 1

    for failure in failures:
        print(f"  FAIL {failure}", file=sys.stderr)
    print(f"\n{families - len(failures)} of {families} claim families still detected")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    arguments = argv[1:]
    fix = "--fix" in arguments
    arguments = [a for a in arguments if a != "--fix"]

    if not DOCS_ROOT.is_dir():
        print(f"completion documents not found at {DOCS_ROOT}", file=sys.stderr)
        return 2

    if "--self-test" in arguments:
        return self_test()

    prefix = arguments[0] if arguments else ""
    documents = sorted(p for p in DOCS_ROOT.glob("*.md") if p.name.startswith(prefix))
    reports = [r for r in (audit(p) for p in documents) if r is not None]

    # A checker that quietly stops finding measurements reports a clean tree,
    # which is the one way this kind of audit fails without anyone noticing.
    if not reports:
        print(f"no measurements found under {DOCS_ROOT}", file=sys.stderr)
        return 2

    defective = [r for r in reports if not r.clean]
    for report in defective:
        print(report.render())
        if fix:
            report.apply()

    total = sum(len(r.faults) for r in defective)
    remaining = sum(len(r.faults) - len(r.edits) for r in defective)
    # The unaudited count is reported because its absence is what let this
    # check overstate its own coverage: a document it cannot parse is silently
    # dropped, so a shrinking numerator reads exactly like a clean tree. The
    # number does not fail the run -- a document may legitimately measure
    # nothing -- but it is the figure to look at before trusting the other two.
    print(
        f"\n{len(reports)} documents audited, "
        f"{len(defective)} defective, {total} faults"
    )
    silent = [d.name for d in documents if not any(r.path == d for r in reports)]
    print(f"{len(silent)} of {len(documents)} measure nothing")
    # Named, not just counted. The count exists so a shrinking numerator cannot
    # pass for a clean tree, but a bare number cannot be acted on: deciding
    # whether a skip is legitimate means knowing which document was skipped.
    # Four of the five here are legitimate -- the doc-set contract, a document
    # about *removed* modules, and two whose inventories `check_test_inventories`
    # owns -- and the fifth, `tom_core_codespecs_package_new.md`, states "8
    # files" that nothing reads, because its sources sit at `lib/src/` with no
    # module folder beneath and `MODULE_PATH` wants one. Reading that list off
    # the run is the difference between a metric and a number.
    for name in silent:
        print(f"    measures nothing: {name}")
    if fix:
        print(f"rewrote {total - remaining}; {remaining} need a hand")
        return report_faults(remaining)
    return report_faults(total)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
