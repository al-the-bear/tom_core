#!/usr/bin/env python3
"""Pin every documented copy of the advanced field-grade matrix to the code.

Run from anywhere::

    python3 tool/check_field_grade_matrix.py                  # whole repo
    python3 tool/check_field_grade_matrix.py tom_core_samples # one subtree

Exits non-zero when a documented cell disagrees with the map, so it can gate a
build.

The advanced sample's per-field grade matrix (`projectRoleFieldGrades` in
`advanced_todo_domain`) is the sample's worked example of the four-state
authorization model, so it is *quoted* far more often than a normal constant:
three documents reproduce the whole 7x4 table, and a dozen sentences paraphrase
one of its columns in prose. That makes it the sample's most-copied fact, and
copies drift.

**What already pins it, and what did not.**
`advanced_auth_server/test/grant_matrix_key_consistency_test.dart` pins the
*seed SQL* against the map, cell for cell. That is the enforcement copy, and it
is well guarded. Nothing pinned the **documentation** copies, and that is where
the drift landed: four separate sentences told the reader that a `viewer` sees
`status` disabled "while the rest are read-only", when the viewer's `estimate`
is `none` -- masked, not read-only. A reader who trusted that prose expected a
greyed estimate on the item screen and would find nothing there.

The tables were right in all 84 cells; only the prose beneath them was wrong.
That asymmetry is the reason this checker asks two different questions rather
than one.

**TABLE -- a documented matrix cell disagrees with the map.** Any Markdown or
dartdoc table whose header names all four roles is read as a copy of the matrix
and compared cell for cell. Detection is by the header alone, so a table cannot
opt out by being formatted differently, and rows naming something that is not a
graded field are skipped rather than guessed at.

**RESIDUAL -- a prose summary claims a uniform remainder that is not uniform.**
The recurring sentence shape is "<role> ... -- `status` renders disabled while
the rest are read-only": one named exception, everything else swept into a
single word. That is safe only when the role really does have exactly one
non-`read` cell. The advanced `viewer` has two, so "the rest" is false however
fluently it reads. Two forms are judged:

- "the rest are read-only" is a fault when the named role has more than one
  non-`read` cell -- there is a second exception the sentence did not name.
- "the remaining <n> are read-only" is checked numerically: `<n>` must equal the
  count of `read` cells in that role's column. This is the form the fix uses,
  and it is self-checking -- adding a field to the matrix breaks the count
  rather than silently widening the word "rest".

**Why the sentence must name exactly one role.** A summary that walks all four
roles in one breath ("owner edits everything, ... viewer can toggle nothing --
the rest are read-only") gives no mechanical way to say which column "the rest"
belongs to, and guessing is how a doc checker starts crying wolf. Those are left
unjudged: the population this checker is for is single-role sentences, and every
real instance of the fault was one.

**Why quoted prose is skipped.** A document explaining this fault has to
reproduce the faulty sentence, and the first one to do so was this checker's own
entry in the repository README -- which it promptly reported. Text inside double
quotes is being *mentioned* rather than asserted, so it is blanked before
scanning. Backticks are left alone: the real faults write the role as `viewer`,
and blanking code spans would erase the word that says which column is meant.

**Why the whole check is scoped by `commenter`.** `core_client_sample` carries
its *own* three-role matrix (owner/member/viewer) in which the viewer genuinely
is read-only apart from one disabled toggle -- the identical sentence is true
there. `commenter` is a role only the advanced matrix has, so its presence in a
file is an exact discriminator between the two samples. Without it this checker
would report the simpler sample's correct prose as a fault, which is the failure
mode that gets a checker switched off.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from gate_report import report_faults
import gate_scope

REPO_ROOT = Path(__file__).resolve().parent.parent

SKIP_DIRS = {".dart_tool", "build", ".git", "node_modules", "__pycache__"}

#: The map this checker treats as the single source of truth.
MATRIX_SOURCE = (
    "tom_core_samples/advanced_todo_domain/lib/src/authz/"
    "field_grade_vocabulary.dart"
)

ROLES = ("owner", "editor", "commenter", "viewer")

#: The role only the advanced matrix declares -- see the module docstring.
DISCRIMINATOR = "commenter"

MAP_BODY = re.compile(r"projectRoleFieldGrades = \{(.*?)\n\};", re.S)
MAP_ROLE = re.compile(r"ProjectRole\.(\w+):\s*\{(.*?)\n  \}", re.S)
MAP_CELL = re.compile(r"'todo\.item\.(\w+)':\s*TomAuthState\.(\w+)")

#: A table row, in Markdown or in dartdoc (`/// | a | b |`).
ROW = re.compile(r"^\s*(?:///\s*)?\|(.+)\|\s*$")

#: "the rest are read-only" / "the remaining five are read-only".
RESIDUAL = re.compile(
    r"\bthe\s+(?:(rest)|remaining\s+(\w+))\s+are\s+read-only", re.I)

#: A double-quoted span, straight or typographic. Prose *inside* one is being
#: quoted rather than asserted -- this checker's own documentation reproduces
#: the faulty sentence in order to explain it, and so will any later note about
#: the fault. Backticks are deliberately **not** treated this way: the real
#: faults write the role as `` `viewer` ``, so blanking code spans would erase
#: the very word that says which column the claim is about.
QUOTATION = re.compile("\"[^\"\n]*\"|“[^”\n]*”")

NUMBER_WORDS = {
    "one": 1, "two": 2, "three": 3, "four": 4,
    "five": 5, "six": 6, "seven": 7, "eight": 8,
}


def load_matrix(root: Path) -> dict[str, dict[str, str]]:
    """The grade map, parsed from its Dart declaration.

    Returns an empty mapping when the source is absent, which lets a
    subtree-scoped run outside the sample stay silent rather than fail.
    """
    source = root / MATRIX_SOURCE
    if not source.exists():
        return {}
    body = MAP_BODY.search(source.read_text(encoding="utf-8"))
    if body is None:
        return {}
    return {
        role.group(1): {
            cell.group(1): cell.group(2)
            for cell in MAP_CELL.finditer(role.group(2))
        }
        for role in MAP_ROLE.finditer(body.group(1))
    }


def doc_files(root: Path):
    for path in sorted(root.rglob("*")):
        if path.suffix not in (".md", ".dart"):
            continue
        if SKIP_DIRS & set(path.parts):
            continue
        yield path


def cells(line: str) -> list[str]:
    """The row's cells, stripped of Markdown emphasis and code ticks."""
    row = ROW.match(line)
    assert row is not None
    return [cell.strip().strip("`*_ ") for cell in row.group(1).split("|")]


def audit_tables(lines: list[str], truth: dict[str, dict[str, str]]):
    """``(line, field, role, documented, actual)`` per disagreeing cell."""
    faults = []
    fields = truth["owner"]
    for index, line in enumerate(lines):
        if not ROW.match(line):
            continue
        header = [cell.lower() for cell in cells(line)]
        if not all(role in header for role in ROLES):
            continue
        column = {role: header.index(role) for role in ROLES}
        # +2 skips the header's `| --- |` separator row.
        cursor = index + 2
        while cursor < len(lines) and ROW.match(lines[cursor]):
            row = cells(lines[cursor])
            field = re.sub(r"^todo\.item\.", "", row[0]).strip()
            if field in fields:
                for role in ROLES:
                    if column[role] >= len(row):
                        continue
                    documented = row[column[role]].lower()
                    actual = truth[role][field]
                    if documented != actual:
                        faults.append(
                            (cursor + 1, field, role, documented, actual))
            cursor += 1
    return faults


def mask_quotations(text: str) -> str:
    """Blank quoted spans, preserving offsets so line numbers stay true."""
    return QUOTATION.sub(
        lambda m: "".join("\n" if c == "\n" else " " for c in m.group(0)),
        text)


def sentence_before(text: str, end: int) -> str:
    """The clause ending at ``end``, back to the previous `.`/`;` boundary."""
    start = max(text.rfind("; ", 0, end), text.rfind(". ", 0, end)) + 1
    return " ".join(text[start:end].replace("///", "").split())


def audit_residuals(text: str, truth: dict[str, dict[str, str]]):
    """``(line, role, claimed, detail)`` per unsound remainder claim."""
    faults = []
    text = mask_quotations(text)
    for match in RESIDUAL.finditer(text):
        clause = sentence_before(text, match.end())
        named = [r for r in ROLES if re.search(rf"\b{r}\b", clause, re.I)]
        if len(named) != 1:
            continue
        role = named[0]
        column = truth[role]
        line = text[:match.start()].count("\n") + 1
        if match.group(1):
            exceptions = {f: g for f, g in column.items() if g != "read"}
            if len(exceptions) > 1:
                listed = ", ".join(
                    f"{f}={g}" for f, g in sorted(exceptions.items()))
                faults.append((line, role, "the rest", listed))
        else:
            claimed = NUMBER_WORDS.get(match.group(2).lower())
            if claimed is None:
                continue
            readable = sum(1 for g in column.values() if g == "read")
            if claimed != readable:
                faults.append((line, role, f"remaining {match.group(2)}",
                               f"{readable} read cells"))
    return faults


def main(argv: list[str]) -> int:
    roots = gate_scope.scope(argv[0] if argv else None)
    if not roots[0].exists():
        print(f"no such path: {roots[0]}", file=sys.stderr)
        return 2

    truth = load_matrix(REPO_ROOT)
    if not truth:
        print(f"could not parse the grade map from {MATRIX_SOURCE}",
              file=sys.stderr)
        return 2

    scanned = tables = claims = 0
    faults: list[str] = []
    for path in (p for root in roots for p in doc_files(root)):
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        if DISCRIMINATOR not in text:
            continue
        scanned += 1
        shown = gate_scope.rel(path)

        lines = text.split("\n")
        for line, field, role, documented, actual in audit_tables(
                lines, truth):
            faults.append(
                f"{shown}:{line}: TABLE -- {field}/{role} documented as "
                f"{documented!r}, map says {actual!r}")
        tables += sum(
            1 for line in lines
            if ROW.match(line)
            and all(r in [c.lower() for c in cells(line)] for r in ROLES))

        for line, role, claimed, detail in audit_residuals(text, truth):
            faults.append(
                f"{shown}:{line}: RESIDUAL -- '{claimed} are read-only' for "
                f"{role}, but {detail}")
        claims += len(RESIDUAL.findall(mask_quotations(text)))

    if not scanned:
        # Distinguishing "clean" from "looked nowhere" has to be audible.
        print(f"no document under {root} mentions the advanced matrix "
              f"-- wrong path?", file=sys.stderr)
        return 2

    for fault in faults:
        print(fault)

    print()
    print(f"documents scanned        : {scanned}")
    print(f"matrix tables compared   : {tables}")
    print(f"remainder claims checked : {claims}")
    print(f"faults                   : {len(faults)}")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
