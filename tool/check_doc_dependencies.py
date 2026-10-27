#!/usr/bin/env python3
"""Audit each package document's Dependencies section against its pubspec.

Run from anywhere::

    python3 tool/check_doc_dependencies.py                     # every package document
    python3 tool/check_doc_dependencies.py tom_core_samples    # one prefix

Exits non-zero when any section is incomplete.

Two faults are reported:

``MISSING``
    A name in the package's ``dependencies`` or ``dev_dependencies`` that the
    document's Dependencies section does not carry.
``NOSECTION``
    A package document with no Dependencies section at all.

**What went wrong without it.** Eleven of these documents carried a
Dependencies section and seven of them were incomplete, omitting twenty-eight
declared entries between them; a further four package documents had no section
at all. The omissions were not random. Every one of the twenty-eight was a
*build-time* entry -- ``build``, ``build_runner``, ``tom_reflection_generator``,
``lints``, ``test``, ``flutter_test``, ``flutter_lints`` -- and the runtime half
was in every case complete. That is the worst possible half to drop, because it
is precisely what a reader needs in order to reproduce a generated file: a
document that lists what a package *links* and omits what *built* it reads as
complete and leaves the one question a newcomer actually has unanswered.
``advanced_authadmin_client`` documented none of its six.

**Why the check is worth leaving switched on.** A name either appears in the
section or it does not, so this gate cannot cry wolf -- the bar
``check_consumer_claims.py`` sets for a rule worth keeping. And the defect is
one no reviewer catches: a section that lists five true dependencies looks
right, and only counting it against the pubspec shows that the pubspec declares
eleven.

**A name must appear as a whole inline code span**, i.e. ```build``` rather than
merely the letters ``build`` somewhere in the prose. Substring matching would
accept ``build.yaml`` as evidence for ``build`` and ``tom_reflection`` as
evidence for ``tom_reflection_generator``; every one of these documents already
writes dependency names as code spans, so the stricter rule costs a writer
nothing and removes a whole class of false pass. It is a false *pass* that
matters here, not a false alarm: a gate this cheap is only worth its line in
the baseline if passing it means something.

**The audit is deliberately one-directional.** It requires every declared
dependency to be documented; it does *not* require every name in the section to
be declared. These sections earn much of their value from naming what is
*absent* -- ``advanced_client_core`` explains that it depends on neither Flutter
nor ``tom_core_server``, ``advanced_app_server`` that it never calls
``advanced_auth_server``, several that ``tom_reflection`` arrives transitively
through ``tom_core_kernel`` rather than being declared. Faulting an undeclared
mention would fault exactly the sentences worth writing.

**A document is a package document when its opening inventory resolves to a
directory carrying a ``pubspec.yaml``** -- the same rule, and the same regex,
``check_doc_inventories.py`` uses to decide what to measure. Keying on that
rather than on the document's filename means the resolution is already gated
(by that checker's ``PKGINV`` fault) and cannot drift here unnoticed. Module
documents are skipped, including the two whose narrative carries a heading
about dependencies -- ``The package's dependencies moved with it`` -- because
those describe a move rather than inventory a package.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from gate_report import report_faults
import gate_scope

REPO_ROOT = Path(__file__).resolve().parent.parent
DOCS_ROOT = REPO_ROOT.parent.parent / "_ai" / "quests" / "tom_core" / "completion"

#: A package document's opening inventory line, e.g.
#: ```tom_core_samples/advanced_todo_domain/` — 23 files, ...``.
#: Kept identical to ``check_doc_inventories.PACKAGE_PATH`` on purpose.
PACKAGE_PATH = re.compile(r"^`(tom_\w+/[\w/]+?)/?`\s+—", re.M)

HEADING = re.compile(r"^(#{2,6})\s+(.*?)\s*$", re.M)
CODE_SPAN = re.compile(r"`([^`\n]+)`")

#: A top-level pubspec block, and an entry within one. Entries are indented by
#: exactly two spaces, which is what separates a dependency name from the keys
#: *inside* one (``path:``, ``sdk:``).
PUBSPEC_BLOCK = re.compile(r"^(\w+):\s*$")
PUBSPEC_ENTRY = re.compile(r"^ {2}([A-Za-z_][\w-]*)\s*:")

DEPENDENCY_BLOCKS = ("dependencies", "dev_dependencies")


def declared_dependencies(pubspec: Path) -> list[str]:
    """Every name in the pubspec's ``dependencies`` and ``dev_dependencies``.

    Returned in declaration order, so a fault list reads in the order a writer
    would work through the pubspec.
    """
    names: list[str] = []
    block: str | None = None
    for line in pubspec.read_text(encoding="utf-8").splitlines():
        heading = PUBSPEC_BLOCK.match(line)
        if heading:
            block = heading.group(1) if heading.group(1) in DEPENDENCY_BLOCKS else None
            continue
        if block is None:
            continue
        entry = PUBSPEC_ENTRY.match(line)
        if entry and entry.group(1) not in names:
            names.append(entry.group(1))
    return names


def dependencies_section(text: str) -> str | None:
    """The body of the document's ``Dependencies`` section, or ``None``.

    The heading must be exactly that word. A heading that merely mentions
    dependencies is prose about them rather than an inventory of them.
    """
    for heading in HEADING.finditer(text):
        if heading.group(2).strip().lower() != "dependencies":
            continue
        depth = len(heading.group(1))
        body = text[heading.end() :]
        for following in HEADING.finditer(body):
            if len(following.group(1)) <= depth:
                return body[: following.start()]
        return body
    return None


def audit(document: Path) -> tuple[list[str], bool] | None:
    """Fault lines for one document, plus whether it was audited at all.

    Returns ``None`` for a document that names no package -- a module document,
    which has no pubspec to be measured against.
    """
    text = document.read_text(encoding="utf-8")
    match = PACKAGE_PATH.search(text)
    if match is None:
        return None
    package = gate_scope.at(match.group(1))
    pubspec = package / "pubspec.yaml"
    if not pubspec.is_file():
        return None

    section = dependencies_section(text)
    if section is None:
        return (
            [
                f"NOSECTION `{document.name}` documents"
                f" {match.group(1)} and has no Dependencies section"
            ],
            True,
        )

    documented = {span.strip() for span in CODE_SPAN.findall(section)}
    faults = [
        f"MISSING   `{document.name}` omits `{name}`"
        for name in declared_dependencies(pubspec)
        if name not in documented
    ]
    return faults, True


def main(argv: list[str]) -> int:
    if not DOCS_ROOT.is_dir():
        print(f"completion documents not found at {DOCS_ROOT}", file=sys.stderr)
        return 2

    prefix = argv[1] if len(argv) > 1 else ""
    documents = sorted(p for p in DOCS_ROOT.glob("*.md") if p.name.startswith(prefix))

    audited = 0
    faults: list[str] = []
    defective = 0
    for document in documents:
        result = audit(document)
        if result is None:
            continue
        audited += 1
        found, _ = result
        if found:
            defective += 1
            faults.extend(found)

    # A checker that stops finding package documents reports a clean tree,
    # which is the one way this kind of audit fails without anyone noticing.
    if audited == 0:
        print(f"no package documents found under {DOCS_ROOT}", file=sys.stderr)
        return 2

    for fault in faults:
        print(fault)

    print(
        f"\n{audited} package documents audited, "
        f"{defective} defective, {len(faults)} faults"
    )
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv))
