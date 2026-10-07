#!/usr/bin/env python3
"""Hold a completion document's claims about the baseline to the baseline.

Run from anywhere::

    python3 tool/check_baseline_claims.py               # every *_changes.md
    python3 tool/check_baseline_claims.py --self-test   # check the checker

Exits non-zero when a `## What changed` section says what a `Tom*` symbol did
at the baseline although the symbol did not exist there.

**Why.** Every other gate here checks a document against the code as it *is*.
Part 3 of a ``*_changes.md`` document is the exception: it describes the
baseline, commit ``3bdb9f0``, and compares only against it (``completion/
README.md`` § 4, the AS-IS rule). A claim about the baseline is therefore a
claim about a tree no other gate reads, and one shape of it is decidable: a
sentence whose subject is a backticked `Tom*` symbol and whose verb is past
tense -- `` `TomFoo` returned a growable list`` -- asserts the symbol was there
to do it. If the baseline declares no such symbol, the sentence is describing
some intermediate state of the code instead, which the contract forbids, or
describing nothing at all.

**What counts as such a claim.** The symbol opens the clause and a past-tense
verb follows it, optionally after one adverb (`previously`, `once`, ...). The
symbol is the leading identifier of the span, so `` `TomFoo.all()` `` is a
claim about `TomFoo`. Four shapes share that surface and are not claims, and
each is excluded by a rule rather than a list:

- the symbol is the object of what precedes it -- ``looking for `TomFoo`
  opened the file`` (a preposition or relative word directly before it);
- the verb is a passive participle -- ``a `TomFoo` shared by two isolates``;
- the clause is negative -- ``` `TomFoo` did not exist ```, which is exactly
  what a baseline claim about a *missing* symbol should say;
- the verb stands alone as a pro-form -- ``not that the `TomFoo` did;``.

**The index.** Every `Tom*` identifier appearing in a Dart file at the
baseline, read with one ``git grep`` against the commit (well under a second;
the commit never changes, so no cache is needed). Appearing anywhere -- a
declaration, a reference, a comment -- is deliberately generous: the gate
reports a symbol that did not exist *at all*, which is the decidable half.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

from gate_report import report_faults

TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parent
DOCS_ROOT = REPO_ROOT.parent.parent / "_ai" / "quests" / "tom_core" / "completion"
BASELINE = "3bdb9f0"

SECTION = "## What changed"

#: A backticked span opening with a `Tom*` identifier, then a past-tense verb.
CLAIM = re.compile(
    r"`(?P<symbol>Tom[A-Z][A-Za-z0-9_]*)[^`\n]*`(?:'s)?\s+"
    r"(?:(?:previously|once|originally|then|also|still|only|never|always|"
    r"already)\s+)?"
    r"(?P<verb>used to|was|were|had|did|[a-z]+ed)\b"
    r"(?P<after>[^\n]{0,12})")

#: A word directly before the span that makes the symbol its object.
GOVERNED = re.compile(
    r"\b(?:for|of|to|with|by|from|about|on|in|into|at|than|that|which|whom)"
    r"\s+(?:the\s+|a\s+|an\s+)?$", re.IGNORECASE)

#: What follows a verb that turns the clause into something other than a claim.
NOT_A_CLAIM_AFTER = re.compile(r"^(?:\s+by\b|\s+not\b|\s+no\b|\s+never\b|[^\s\w])")


def baseline_symbols() -> set[str]:
    """Every `Tom*` identifier in a Dart file at the baseline commit."""
    done = subprocess.run(
        ["git", "grep", "-ohP", r"\bTom[A-Z][A-Za-z0-9_]*", BASELINE, "--",
         "*.dart"],
        cwd=REPO_ROOT, capture_output=True, text=True)
    if done.returncode not in (0, 1):
        raise SystemExit(f"cannot read baseline {BASELINE}: {done.stderr}")
    return set(done.stdout.split())


def what_changed(text: str) -> list[tuple[int, str]]:
    """`(first line number, body)` of each `## What changed` section."""
    sections = []
    lines = text.split("\n")
    start = None
    for index, line in enumerate(lines):
        if line.startswith("## "):
            if start is not None:
                sections.append((start + 1, "\n".join(lines[start:index])))
                start = None
            if line.strip() == SECTION:
                start = index
    if start is not None:
        sections.append((start + 1, "\n".join(lines[start:])))
    return sections


def claims(body: str):
    """Yield `(offset, symbol, text)` for each baseline claim in `body`."""
    for match in CLAIM.finditer(body):
        if GOVERNED.search(body[max(0, match.start() - 40): match.start()]):
            continue
        if NOT_A_CLAIM_AFTER.match(match.group("after")):
            continue
        yield match.start(), match.group("symbol"), match.group(0).split("\n")[0]


def faults_in(text: str, known: set[str]) -> list[tuple[int, str, str]]:
    """`(line, symbol, text)` for every claim about an absent symbol."""
    found = []
    for first_line, body in what_changed(text):
        for offset, symbol, snippet in claims(body):
            if symbol not in known:
                line = first_line + body.count("\n", 0, offset)
                found.append((line, symbol, snippet))
    return found


#: One line per rule: `(text, expected faults)`, judged inside a What changed
#: section against a baseline that knows `TomOld` only.
SELF_TESTS = [
    ("`TomNew.all()` returned a growable list.", 1),
    ("`TomNew` previously carried `clear`.", 1),
    ("`TomNew` used to throw.", 1),
    ("`TomOld` returned a growable list.", 0),
    ("A reader looking for `TomNew` opened the wrong file.", 0),
    ("A `TomNew` shared by two isolates clobbers itself.", 0),
    ("`TomNew` did not exist at the baseline.", 0),
    ("proves a number arrived, not that the `TomNew` did; a builder", 0),
    ("At the baseline there was no `TomNew`.", 0),
]


def self_test() -> int:
    failed = 0
    for text, expected in SELF_TESTS:
        document = f"# Doc\n\n## What changed\n\n{text}\n"
        got = len(faults_in(document, {"TomOld"}))
        if got != expected:
            failed += 1
            print(f"self-test: {text!r}: expected {expected}, got {got}",
                  file=sys.stderr)
    # Outside the section a claim is not judged at all.
    if faults_in("# Doc\n\n## Using it\n\n`TomNew` returned x.\n", {"TomOld"}):
        failed += 1
        print("self-test: a claim outside What changed was judged",
              file=sys.stderr)
    if failed:
        return 1
    print(f"self-test: {len(SELF_TESTS) + 1} claim shapes judged as expected")
    return 0


def main(argv: list[str]) -> int:
    if argv == ["--self-test"]:
        return self_test()
    known = baseline_symbols()
    # The baseline held hundreds of Tom* names; a handful means the read failed.
    if len(known) < 200:
        print(f"only {len(known)} Tom* identifiers at {BASELINE}; not measured",
              file=sys.stderr)
        return 2
    documents = sorted(DOCS_ROOT.glob("*_changes.md"))
    if not documents:
        print(f"no *_changes.md under {DOCS_ROOT}; not measured",
              file=sys.stderr)
        return 2

    total = 0
    claims_read = 0
    for document in documents:
        text = document.read_text(encoding="utf-8")
        for _, body in what_changed(text):
            claims_read += sum(1 for _ in claims(body))
        for line, symbol, snippet in faults_in(text, known):
            total += 1
            print(f"{document.name}:{line}: `{symbol}` did not exist at "
                  f"{BASELINE}, so this cannot describe the baseline: {snippet}")

    print()
    print(f"baseline identifiers     : {len(known)}")
    print(f"documents read           : {len(documents)}")
    print(f"baseline claims judged   : {claims_read}")
    print(f"naming an absent symbol  : {total}")
    return report_faults(total)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
