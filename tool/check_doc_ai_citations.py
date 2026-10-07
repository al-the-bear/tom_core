#!/usr/bin/env python3
"""Find shipped files that cite a document in the AI-state layer.

Run from anywhere::

    python3 tool/check_doc_ai_citations.py                  # every package
    python3 tool/check_doc_ai_citations.py tom_flutter_ui   # one subtree

Exits non-zero when any shipped file cites a document its reader cannot open,
so it can gate a build.

Three faults are reported:

``AILINK``
    A shipped file naming a path under ``_ai/``, or one of the mount's own
    directories written without it -- ``completion/README.md``,
    ``quests/tom_core/...``. The bare form is the one citations actually take:
    it reads like a folder beside the file it appears in, which is what makes
    it hard to notice, and ``README.md`` beneath it is a name this repository
    also has, so ``AINAME`` cannot see it.
``AINAME``
    A shipped file naming, by bare filename, a document that exists under
    ``_ai/quests/`` and nowhere in this repository -- ``deferred.tom_core.md``,
    or a completion document such as ``tom_core_server_export_new.md``.
``NOQUESTS``
    The ``_ai/quests/`` tree is not present, so ``AINAME`` could not be
    measured. Counted as a fault rather than skipped: a half of the check that
    silently measured nothing would read exactly like one that passed.

**What went wrong without it.** ``tom_flutter_ui/doc/`` cited
``_ai/quests/flutter_ui/acl_json_layout.md`` from two places, and the section
doing so called that document *the canonical layout contract*. The file exists,
so this was never a dangling link -- it was an unreachable one: ``_ai/`` is a
separate repository (``tom_agent_state``) mounted by symlink and absent from
any checkout of ``tom_ai/core``, so the shipped document deferred its authority
to a file its reader cannot obtain.

The path form is the easy half. ``tom_core_agentic/lib/src/llm/llm.dart``
explained which providers were left behind by pointing at
``deferred.tom_specs.md`` -- no ``_ai/`` in sight, and the document did not
even carry the claim. Three such citations in one package had been written by
three different passes, none of them trying to; the bare name is the shape a
citation takes once its author knows the document well enough to stop saying
where it lives. ``AINAME`` catches that shape.

**Why a scan does not find these on its own.** ``find`` and ``git ls-files`` do
not follow the ``_ai`` symlink, so a citation of a file that is present reads as
"file does not exist" to any tool run from the container root. A checker keyed
on the *citation* rather than on the target sidesteps the question of whether
the file resolves. For ``AINAME`` the quest tree is enumerated explicitly, with
``os.walk(followlinks=True)`` through the mount.

**What a quest document is.** Every ``.md`` and ``.yaml`` file under
``_ai/quests/``, less each quest's ``history/`` (machine-local chat transcripts,
which no shipped file has reason to name), less every filename that also exists
somewhere in this repository. The subtraction is what keeps ``README.md``,
``index.md`` or ``pubspec.yaml`` from matching: a name the reader can find in
the package is not unreachable, whichever copy the author meant.

**Scope is the audience, not the file type.** What is audited is what leaves the
workspace with a package: every ``.dart`` and ``.md`` file in the repository,
``CHANGELOG.md`` included -- it ships, and a reader following a changelog entry
to a document it cannot open is stranded as surely as one following ``doc/``.
``test/`` is in scope too: a checkout of ``tom_ai/core`` carries its tests, and
the reader of a test comment is as likely to hold the code without the mount as
the reader of ``doc/``. Two neighbours are out of scope, because ``_ai/`` is
reachable for their readers or because they do not ship:

``_copilot_guidelines/``
    Development documentation whose audience is the agent working in this
    workspace, where the ``_ai`` mount is present. Citing a quest todo file from
    a refactoring guideline is the correct thing to do.
``tool/``
    A checker that reads the completion documents has to name what it reads.

Generated Dart (``*.reflection.dart``, ``*.b.dart``, ``*.versioner.dart``) is
skipped: its comments are copies of the source they were generated from, which
is scanned.

**One ``_ai/`` path is not a citation.** ``_ai/trail/`` is where the Tom VS Code
extension writes its per-quest prompt trail in *whichever* workspace it runs
in, the reader's included; ``tom_core_agentic`` reads and writes it, and names
it the way code names any runtime directory -- to describe its own behaviour,
not to send a reader elsewhere for a reason. That is the whole distinction
between a citation and a path an implementation operates on, and it is drawn
here, by prefix, once: nothing else under ``_ai/`` is exempt.

**Every package runs this for itself.** Each package under ``tom_ai/core``
carries ``test/ai_citation_test.dart``, which runs this checker scoped to that
package through ``tool/package_gate.dart``. The rule and its one exemption
live here; the package members only make the failure appear in the suite of
the package that introduced it.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent
#: `tom_ai/core` -> `tom_ai` -> the workspace root, where the `_ai` mount lives.
QUESTS = REPO_ROOT.parent.parent / "_ai" / "quests"

#: A path into the AI-state layer, in the shapes files actually write it: bare
#: (``_ai/quests/...``), workspace-qualified, or starting at one of the mount's
#: own directories (``completion/README.md``). The lookbehind keeps a segment
#: from matching a longer identifier that merely ends that way --
#: ``tom_core_completion/`` is not a citation.
AI_PATH = re.compile(r"(?<![\w/])(?:_ai|quests|completion)/[\w./{}-]+")

#: Runtime directories under ``_ai/`` that exist in every Tom workspace, the
#: reader's included -- see the module docstring.
RUNTIME_PREFIXES = ("_ai/trail/",)

#: A bare document filename. The lookbehind rejects a name that is the tail of
#: a path (``doc/x.md``, which is a path into the package) or of a longer word.
DOCUMENT_NAME = re.compile(r"(?<![\w/.-])[\w.-]+\.(?:md|yaml)\b")

#: Directories that never ship or are out of scope; see the module docstring.
EXCLUDED_DIRS = {
    "_copilot_guidelines",
    "tool",
    ".dart_tool",
    "build",
    ".git",
    "node_modules",
    "ztmp",
    "testlog",
}

GENERATED_SUFFIXES = (".reflection.dart", ".b.dart", ".versioner.dart")


def _walk_names(root: Path, skip: set[str], follow: bool) -> set[str]:
    names: set[str] = set()
    for directory, subdirs, files in os.walk(root, followlinks=follow):
        subdirs[:] = [d for d in subdirs if d not in skip]
        names.update(files)
    return names


def quest_only_names() -> set[str] | None:
    """Document names under ``_ai/quests/`` that this repository does not have.

    None when the quest tree is not present.
    """
    if not QUESTS.is_dir():
        return None
    quest_documents = {
        name
        for name in _walk_names(QUESTS, {"history"}, follow=True)
        if name.endswith((".md", ".yaml"))
    }
    return quest_documents - _walk_names(
        REPO_ROOT, {".dart_tool", "build", ".git", "node_modules"}, follow=False
    )


def shipped_files(root: Path) -> list[Path]:
    """Every ``.dart`` and ``.md`` file under ``root`` that leaves with a package."""
    found: list[Path] = []
    for directory, subdirs, files in os.walk(root):
        subdirs[:] = sorted(d for d in subdirs if d not in EXCLUDED_DIRS)
        for name in sorted(files):
            if not name.endswith((".dart", ".md")) or name.endswith(
                GENERATED_SUFFIXES
            ):
                continue
            found.append(Path(directory) / name)
    return found


def citations(path: Path, quest_names: set[str]) -> list[tuple[str, int, str]]:
    """Every unreachable citation in ``path``, as ``(kind, line, cited)``."""
    found: list[tuple[str, int, str]] = []
    text = path.read_text(encoding="utf-8", errors="replace")
    for number, line in enumerate(text.splitlines(), start=1):
        for match in AI_PATH.finditer(line):
            if not match.group(0).startswith(RUNTIME_PREFIXES):
                found.append(("AILINK", number, match.group(0)))
        for match in DOCUMENT_NAME.finditer(line):
            if match.group(0) in quest_names:
                found.append(("AINAME", number, match.group(0)))
    return found


def main(argv: list[str]) -> int:
    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    files = shipped_files(root)
    # A checker that stops finding files reports a clean tree, which is the one
    # way this kind of audit fails without anyone noticing.
    if not files:
        print(f"no shipped files found under {root}", file=sys.stderr)
        return 2

    faults: list[str] = []
    quest_names = quest_only_names()
    if quest_names is None:
        faults.append(
            f"NOQUESTS {QUESTS} is not present, so no bare document name could"
            " be checked"
        )
        quest_names = set()

    for path in files:
        relative = path.relative_to(REPO_ROOT)
        faults.extend(
            f"{kind} {relative}:{number} cites `{cited}`, which no reader of"
            " the package can open"
            for kind, number, cited in citations(path, quest_names)
        )

    for fault in faults:
        print(fault)

    print(
        f"\n{len(files)} shipped files scanned against"
        f" {len(quest_names)} quest-only document names, {len(faults)} faults"
    )
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
