#!/usr/bin/env python3
"""Find machine-generated artifacts tracked under a package's ``doc/``.

Run from anywhere::

    python3 tool/check_doc_artifacts.py                  # every package
    python3 tool/check_doc_artifacts.py tom_core_kernel  # one subtree

Exits non-zero when any artifact is tracked, so it can gate a build.

``doc/`` is where a package keeps the documentation a person wrote. Three
places in this workspace already say so -- the repository ``.gitignore``
("the ``doc/`` folder itself is fully tracked (no test artifacts written
there)"), testkit's ``trackingDirName`` ("this folder is expected to be fully
gitignored ... and ``doc/`` is reserved for hand-authored documentation"), and
the documentation-placement guideline. None of the three could *notice* being
broken, and all three were broken: six generated files sat in version control
under ``doc/`` across three packages, the youngest of them months stale.

**Why staleness is the defect and size is not.** A tracked artifact is a
photograph of one machine's build, and nothing updates it. It cannot be told
apart from a current one without finding the live path and comparing dates, so
a reader who trusts it is misled and a reader who does not gains nothing. Weight
is the lesser harm; the kernel's captured test run was 934 KB, which is
annoying, while its being eleven weeks out of date is what makes it wrong.

**What the rule keys on.** Not a list of known generated filenames -- that only
ever catches the artifact someone already found. Documentation a person writes
is markdown, with diagrams and the occasional released PDF beside it, so
anything else tracked under ``doc/`` was put there by a tool. Stating it that
way is what makes the gate catch the *next* artifact rather than the last one.

**On disk is fine; committed is not.** The question is what version control
carries, so the inventory comes from ``git ls-files`` rather than a directory
walk. A tool that writes under ``doc/`` on a developer's machine costs nobody
anything until the file is committed, and answering "is this ignored?" any
other way means reimplementing git's ignore rules by hand.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent

#: What a person authors, and what a document carries with it. Markdown is the
#: documentation itself; the image formats are the diagrams it embeds; PDF is
#: here because a released API reference is a deliberate, hand-triggered build
#: that the documentation guideline puts in ``doc/`` on purpose.
AUTHORED_SUFFIXES = {
    ".md",
    ".pdf",
    ".png",
    ".jpg",
    ".jpeg",
    ".svg",
    ".gif",
    ".webp",
}


def tracked_doc_files(root: Path) -> list[Path]:
    """Every version-controlled file under a ``doc/`` directory in ``root``."""
    listing = subprocess.run(
        ["git", "ls-files", "-z", "--", str(root)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return [
        Path(name)
        for name in listing.stdout.split("\0")
        if name and "doc" in Path(name).parts[:-1]
    ]


def main(argv: list[str]) -> int:
    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"no such path: {root}", file=sys.stderr)
        return 2

    scanned = 0
    faults: list[Path] = []
    for path in sorted(tracked_doc_files(root)):
        scanned += 1
        if path.suffix.lower() not in AUTHORED_SUFFIXES:
            faults.append(path)

    for path in faults:
        size = (REPO_ROOT / path).stat().st_size if (REPO_ROOT / path).exists() else 0
        print(f"{path}: generated artifact tracked under doc/ ({size:,} bytes)")

    print()
    print(f"tracked doc files        : {scanned}")
    print(f"generated artifacts      : {len(faults)}")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
