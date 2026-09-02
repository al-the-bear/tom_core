#!/usr/bin/env python3
"""Find pubspecs still carrying `flutter create` / `dart create` boilerplate.

Run from anywhere::

    python3 tool/check_pubspec_boilerplate.py                  # whole repo
    python3 tool/check_pubspec_boilerplate.py tom_core_samples # one subtree

Exits non-zero when a generator default survives, so it can gate a build.

Two faults, both exact-match against verbatim generator output:

``description``
    The generator writes a placeholder -- "A new Flutter project.",
    "A sample command-line application.", "A starting point for Dart libraries
    or applications." A pubspec's description is the one place a tool reads the
    package's own summary, so a placeholder there is the package failing to say
    what it is no matter how well the README does.
``commentary``
    The generator also writes ~60 lines of tutorial prose explaining versioning,
    `pub upgrade`, `flutter_lints`, and how one *would* declare assets and fonts.
    None of it documents the package it sits in. In `tom_flutter_ui_test` it was
    62 of 100 lines, and the commented-out asset block described an asset bundle
    the package does not have.

**Why this needs a gate rather than a fix.** Unlike a prose slip, this defect is
**machine-generated, reproducibly, by the standard way packages are created**.
It was filed twice against two packages -- tcinc1099 (`tom_flutter_form_test`)
and tcinc1107 (`tom_flutter_ui_test`) -- and every future `flutter create` in
this repo reintroduces it in full. Both are fixed and the repo is currently at
zero faults; this keeps it there.

The match is exact rather than heuristic: every sentinel below was verified
present, verbatim, in freshly generated `flutter create -t app`,
`dart create -t package` and `dart create -t console` output. Nothing here
guesses at intent, so a hand-written description is never a false positive.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Directories that hold generated or vendored package copies, not our sources.
SKIP_PARTS = {"build", ".dart_tool", "ephemeral", ".pub-cache", "node_modules"}

# Verbatim `description:` values written by the generators.
TEMPLATE_DESCRIPTIONS = {
    "A new Flutter project.",
    "A new Flutter plugin project.",
    "A new Flutter package project.",
    "A new Dart project.",
    "A sample command-line application.",
    "A starting point for Dart libraries or applications.",
}

# Verbatim comment lines written by the generators. Each is the first line of a
# tutorial block; matching the opener is enough to condemn the whole block.
TEMPLATE_COMMENTS = (
    "# The following defines the version and build number for your application.",
    "# To automatically upgrade your package dependencies to the latest versions",
    '# The "flutter_lints" package below contains a set of recommended lints to',
    "# To add assets to your application, add an assets section, like this:",
    "# To add custom fonts to your application, add a fonts section here,",
    "# The following line prevents the package from being accidentally published to",
    "# The following adds the Cupertino Icons font to your application.",
    "# For information on the generic Dart part of this file, see the",
    "# The following line ensures that the Material Icons font is",
    '# An image asset can refer to one or more resolution-specific "variants", see',
    # `flutter create -t package` writes the same blocks saying "package" where
    # the app template says "application" -- both variants are in this repo.
    "# To add assets to your package, add an assets section, like this:",
    "# To add custom fonts to your package, add a fonts section here,",
    "# For details regarding assets in packages, see",
    "# The following section is specific to Flutter packages.",
)

DESCRIPTION = re.compile(r"^description:(.*)$", re.MULTILINE)


def read_description(text: str) -> str | None:
    """The description value, folded to one line, or None when absent.

    Handles the plain (`description: text`), quoted and block-scalar
    (`description: >-`) forms, since the repo uses all three.
    """
    match = DESCRIPTION.search(text)
    if match is None:
        return None

    lines = text.split("\n")
    start = text[: match.start()].count("\n")
    head = match.group(1).strip()

    # A block scalar carries its value on the following indented lines.
    if head in {">", ">-", ">+", "|", "|-", "|+", ""}:
        collected: list[str] = []
        for line in lines[start + 1 :]:
            if line.strip() and not line[0].isspace():
                break  # the next top-level key
            collected.append(line.strip())
        head = " ".join(part for part in collected if part)

    return " ".join(head.strip("\"'").split())


def pubspecs(root: Path) -> list[Path]:
    found = [
        path
        for path in sorted(root.rglob("pubspec.yaml"))
        if not SKIP_PARTS.intersection(path.parts)
    ]
    return found


def main(argv: list[str]) -> int:
    root = REPO_ROOT / argv[0] if argv else REPO_ROOT
    if not root.exists():
        print(f"MISSING    {root} does not exist")
        return 1

    faults = 0
    scanned = 0

    for path in pubspecs(root):
        scanned += 1
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(REPO_ROOT)

        description = read_description(text)
        if description is None or not description:
            print(f"{rel}:1: no description -- the package does not say what it is")
            faults += 1
        elif description in TEMPLATE_DESCRIPTIONS:
            print(
                f"{rel}:1: description is the generator placeholder "
                f"{description!r} -- name what this package is"
            )
            faults += 1

        for number, line in enumerate(text.split("\n"), start=1):
            stripped = line.strip()
            for sentinel in TEMPLATE_COMMENTS:
                if stripped.startswith(sentinel):
                    print(
                        f"{rel}:{number}: generator commentary -- {sentinel[:52]}..."
                    )
                    faults += 1

    print()
    print(f"pubspecs scanned : {scanned}")
    print(f"faults           : {faults}")
    return 1 if faults else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
