#!/usr/bin/env python3
"""Find shipped documentation that cites a path in the AI-state layer.

Run from anywhere::

    python3 tool/check_doc_ai_citations.py                  # every package
    python3 tool/check_doc_ai_citations.py tom_flutter_ui   # one subtree

Exits non-zero when any shipped document cites ``_ai/``, so it can gate a build.

One fault is reported:

``AILINK``
    A shipped document naming a path under ``_ai/``.

**What went wrong without it.** ``tom_flutter_ui/doc/`` cited
``_ai/quests/flutter_ui/acl_json_layout.md`` from two places, and the section
doing so called that document *the canonical layout contract*. The file exists,
so this was never a dangling link -- it was an unreachable one, which is the
sharper problem: ``_ai/`` is a separate repository (``tom_agent_state``) mounted
by symlink and absent from any checkout of ``tom_ai/core``, so the shipped
document deferred its authority to a file its reader cannot obtain. The contract
was, in effect, unstated. Worse, the cited document specified ``AclJsonLayout``,
a JSON entry-point this package's own appendix records as abandoned, so a reader
who *did* reach it would have been misled rather than informed.

**Why a scan does not find these on its own.** ``find`` and ``git ls-files`` do
not follow the ``_ai`` symlink, so a citation of a file that is present reads as
"file does not exist" to any tool run from the container root. That is precisely
how an earlier repair came to assert, wrongly, that its cited document had never
existed. A checker keyed on the *citation* rather than on the target sidesteps
the question of whether the file resolves, which is the only way to get a stable
answer here.

**Scope is the audience, not the file type.** What is audited is what leaves the
workspace with the package: ``doc/`` and the package ``README.md``. Two
neighbours are deliberately out of scope, both because ``_ai/`` is genuinely
reachable for their readers:

``_copilot_guidelines/``
    Development documentation whose audience is the agent working in this
    workspace, where the ``_ai`` mount is present. Citing a quest todo file from
    a refactoring guideline is the correct thing to do.
``CHANGELOG.md``
    A changelog entry naming ``_ai/quests/tom_core/completion/`` is a historical
    statement about how a change was verified, not a contract the reader must
    open. Provenance survives the document it points at going away; a contract
    does not.

``tool/`` is likewise unscanned -- a checker that reads the completion documents
has to name the directory it reads.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent

#: A path into the AI-state layer, in the shapes documents actually write it:
#: bare (``_ai/quests/...``) or workspace-qualified. The trailing character class
#: keeps ``_ai`` from matching a longer identifier that merely starts that way.
AI_PATH = re.compile(r"(?<![\w/])_ai/[\w./-]+")

#: The directories whose markdown ships with the package.
SHIPPED_DIR = "doc"

#: The one shipped markdown file that lives outside ``doc/``.
SHIPPED_FILE = "README.md"


def shipped_documents(root: Path) -> list[Path]:
    """Every markdown file under ``root`` whose audience is a package consumer.

    That is the contents of any ``doc/`` directory, plus each ``README.md``.
    Anything under ``_copilot_guidelines/`` or ``tool/`` is excluded, and so is
    ``CHANGELOG.md`` -- see the module docstring for why each is legitimate.
    """
    documents: list[Path] = []
    for path in sorted(root.rglob("*.md")):
        parts = path.relative_to(REPO_ROOT).parts
        if "_copilot_guidelines" in parts or "tool" in parts:
            continue
        if SHIPPED_DIR in parts[:-1] or path.name == SHIPPED_FILE:
            documents.append(path)
    return documents


def citations(document: Path) -> list[tuple[int, str]]:
    """Every ``_ai/`` path the document names, as ``(line number, path)``."""
    found: list[tuple[int, str]] = []
    for number, line in enumerate(
        document.read_text(encoding="utf-8").splitlines(), start=1
    ):
        found.extend((number, match.group(0)) for match in AI_PATH.finditer(line))
    return found


def main(argv: list[str]) -> int:
    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    documents = shipped_documents(root)

    # A checker that stops finding documents reports a clean tree, which is the
    # one way this kind of audit fails without anyone noticing.
    if not documents:
        print(f"no shipped documents found under {root}", file=sys.stderr)
        return 2

    faults: list[str] = []
    for document in documents:
        relative = document.relative_to(REPO_ROOT)
        faults.extend(
            f"AILINK {relative}:{number} cites `{path}`, which no reader of"
            f" the package can open"
            for number, path in citations(document)
        )

    for fault in faults:
        print(fault)

    print(f"\n{len(documents)} shipped documents scanned, {len(faults)} faults")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
