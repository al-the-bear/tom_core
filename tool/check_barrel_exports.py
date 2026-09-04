#!/usr/bin/env python3
"""Hold every barrel to the directory it claims to inventory.

Run from anywhere::

    python3 tool/check_barrel_exports.py            # every package
    python3 tool/check_barrel_exports.py tom_flutter_ui ...

Exits non-zero when a barrel's directory holds a Dart file the barrel chain
does not reach and no marker declares, so it can gate a build.

**The fault.** ``advanced_app_client/lib/app/app.dart`` declared three exports
while its directory held four exportable files. The missing one,
``session_two_factor_controller.dart``, was a real public type: imported by
``login_screen.dart``, given its own section in the completion document, and
unreachable by name to anyone importing ``package:advanced_app_client/app/app
.dart``. A barrel is the one place a package states what it offers, so a file
omitted from it is invisible in exactly the way that is hardest to notice --
the code compiles, the tests pass, and only a consumer finds out.

``check_doc_inventories.py`` grew a ``BARREL`` fault for this, checking that a
completion document's ``barrel — N exports`` label matches the file's export
count. That would not have caught this defect on its own. It caught it because
the label happened to say 4 while the barrel said 3 -- the number was
accidentally right about what the barrel was *for*. Had the label said 3, both
would have agreed and the type would still have been unreachable. A document
audit compares a claim against the code; this compares the code against itself.

**What a barrel is.** A file under ``lib/`` whose body is nothing but
directives -- it declares no type of its own -- and which carries at least one
unconditional ``export``. Both halves are load-bearing:

*Declaring nothing* is what separates a barrel from a library that happens to
re-export a neighbour. A file with code in it is not claiming to be an
inventory of anything.

*Unconditional* excludes the platform shims, which are the shape most easily
mistaken for a barrel and the one where the rule would be flatly wrong.
``file_opener.dart`` is a single line -- ``export 'file_opener_stub.dart' if
(dart.library.io) 'file_opener_io.dart';`` -- and it names a *variant*, not an
inventory. Reading it as a barrel would demand that it export the other six
files in ``forms/files/``, which would be nonsense. Three such shims exist
across the tree and all three are correct as they stand.

**The claim is the barrel, not the directory.** A directory with no barrel is
reported on by nothing, deliberately. Six of the sample packages are Flutter
applications whose ``screens/`` and ``groups/`` directories re-export nothing,
correctly: a consumer never imports another application's screen. Demanding
coverage there would produce roughly ninety faults, every one of them wrong,
and a gate that is wrong ninety times is a gate somebody switches off. Placing
a barrel in a directory is what opts that directory in.

**Coverage is reachability, not the one barrel's export list.** A sibling
counts as covered when *any* barrel in the package reaches it through export
chains, not only the barrel beside it. This is what makes sub-barrels work:
``advanced_todo_contracts/lib/src/`` holds ``dtos.dart``, which is a barrel
over nine DTO files, next to ``api_registry.dart`` and ``api_services.dart``,
which the *package* barrel exports directly. Asking whether ``dtos.dart``
exports its two neighbours gets the answer "no", and the right answer is that
it should not -- they are not DTOs. Asking whether the package offers them
gets the answer the consumer cares about.

**The opt-out, and why it lives in the barrel.** Some omissions are correct.
``advanced_client_core.dart`` exports everything except ``reflection_seed
.dart``, because the Flutter applications that consume the client core install
their own ``initializeReflection`` and exporting this one would collide with
theirs. A gate with no way to say that is a gate that fails on correct code.

So a barrel may declare an omission, in a comment beside its exports::

    // not-exported: reflection_seed.dart — the apps install their own
    // initializeReflection; exporting this one would collide with theirs.

The marker sits in the barrel rather than in a skip list here or a layout block
in a completion document, for three reasons. It survives a file move, because it
travels with the code. It is visible to the person editing the barrel -- who is
the one person certain to be looking when the question next arises -- rather
than to whoever later reads the document. And it forces the reason to be
written down once, next to the decision, where the next reader can weigh it.

Reasons are required, not decorative, and are held to being real: a marker
naming a file that is not there, or one the barrel chain reaches after all,
is a fault. Without that the list becomes a place inconvenient files go, which
is the failure mode of every suppression mechanism that is not itself checked.

**Generated output is skipped by shape**, not by marker: ``*.reflection.dart``,
``*.versioner.dart``, ``*.g.dart`` and ``*.freezed.dart``. A marker naming one
of them would describe a file no human maintains and the next build rewrites,
so there is nothing for a reader to weigh. Committed-but-generated files that
a *hand-written* neighbour wraps are a different case and do carry markers --
``tom_colors_generated.dart`` is 355 colours behind ``tom_colors.dart``, and
that it is wrapped rather than exported is a decision somebody made.

**Falsification.** Drop an export from any barrel and its file is reported
under ``UNEXPORTED``; delete a file a marker names, or export it after all, and
the marker is reported under ``STALEMARK``; write a marker with no reason and
it is reported under ``NOREASON``. The guards below cover the failure that
would matter most -- reporting a clean tree by looking at nothing -- so a
relocated package root or a barrel-detection rule that stops matching fails
loudly rather than passing silently.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent

#: Output nobody hand-maintains. Skipped as siblings by shape -- see the module
#: docstring on why these take no marker.
GENERATED = (
    ".reflection.dart",
    ".versioner.dart",
    ".g.dart",
    ".freezed.dart",
)

#: A directive and its body, up to the semicolon. `library;` is included so a
#: barrel carrying one is still recognised as declaring nothing.
DIRECTIVE = re.compile(r"^[ \t]*(export|import|part|library)\b([^;]*);", re.MULTILINE)

#: Every quoted URI in a directive body. A conditional export names two, which
#: is how [is_barrel] tells a platform shim from an inventory.
URI = re.compile(r"'([^']+)'")

#: A declared omission: `// not-exported: <file> — <reason>`. The separator may
#: be an em dash or a hyphen; the reason runs to the end of the line and may be
#: continued on the following comment lines, which are not parsed.
MARKER = re.compile(
    r"^[ \t]*//[ \t]*not-exported:[ \t]*(\S+?\.dart)[ \t]*(?:[—-][ \t]*(.*))?$",
    re.MULTILINE,
)

BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)
LINE_COMMENT = re.compile(r"^[ \t]*//.*$", re.MULTILINE)


def uncommented(text: str) -> str:
    """The source with comments removed, for reading directives out of."""
    return LINE_COMMENT.sub("", BLOCK_COMMENT.sub("", text))


def directives(text: str) -> list[tuple[str, str]]:
    """Every `(keyword, body)` directive in [text], comments already gone."""
    return DIRECTIVE.findall(text)


def is_barrel(text: str) -> bool:
    """Whether a file is a barrel: declares nothing, exports unconditionally.

    See the module docstring for why both halves are needed, and for the three
    platform shims the second half exists to exclude.
    """
    body = uncommented(text)
    if DIRECTIVE.sub("", body).strip():
        return False  # Declares something of its own.
    for keyword, rest in directives(body):
        if keyword == "part" and not rest.strip().startswith("of"):
            return False  # Owns parts; its library is the unit, not a barrel.
    return any(
        keyword == "export" and len(URI.findall(rest)) == 1
        for keyword, rest in directives(body)
    )


def exported_targets(path: Path, text: str, within: set[Path]) -> list[Path]:
    """The files [path] re-exports, resolved and restricted to [within].

    Both URIs of a conditional export count: a shim that names two platform
    halves makes each of them reachable on the platform that selects it.
    """
    targets = []
    for keyword, rest in directives(uncommented(text)):
        if keyword == "import":
            continue
        for uri in URI.findall(rest):
            if ":" in uri:
                continue  # dart:… or another package.
            target = (path.parent / uri).resolve()
            if target in within:
                targets.append(target)
    return targets


def packages(names: list[str]) -> list[Path]:
    """The package directories to audit, as `lib`-bearing pubspec roots."""
    found = sorted(
        {p.parent for p in REPO_ROOT.glob("*/pubspec.yaml")}
        | {p.parent for p in REPO_ROOT.glob("*/*/pubspec.yaml")}
    )
    found = [p for p in found if (p / "lib").is_dir()]
    if not names:
        return found
    wanted = set(names)
    return [p for p in found if p.name in wanted]


def audit(package: Path, faults: list[str]) -> int:
    """Check one package's barrels. Returns the number of barrels examined."""
    lib = package / "lib"
    sources = {f.resolve() for f in lib.rglob("*.dart")}

    barrels: dict[Path, str] = {}
    for path in sorted(lib.rglob("*.dart")):
        if path.name.endswith(GENERATED):
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if is_barrel(text):
            barrels[path.resolve()] = text
    if not barrels:
        return 0

    # Everything the barrels reach between them, transitively. A barrel is
    # seeded as reached so that a sub-barrel is not reported beside its parent.
    reached = set(barrels)
    pending = [(p, t) for p, t in barrels.items()]
    while pending:
        path, text = pending.pop()
        for target in exported_targets(path, text, sources):
            if target in reached:
                continue
            reached.add(target)
            pending.append(
                (target, target.read_text(encoding="utf-8", errors="replace"))
            )

    for barrel, text in sorted(barrels.items()):
        shown = barrel.relative_to(REPO_ROOT)
        declared: dict[str, str | None] = {}
        for name, reason in MARKER.findall(text):
            declared[name] = (reason or "").strip() or None

        for sibling in sorted(barrel.parent.glob("*.dart")):
            resolved = sibling.resolve()
            if resolved in reached or sibling.name.endswith(GENERATED):
                continue
            if sibling.name in declared:
                continue
            faults.append(
                f"UNEXPORTED  {shown} does not reach `{sibling.name}`, beside "
                f"it. Export it, or declare the omission with "
                f"`// not-exported: {sibling.name} — <reason>`"
            )

        for name, reason in sorted(declared.items()):
            target = (barrel.parent / name).resolve()
            if not target.exists():
                faults.append(
                    f"STALEMARK   {shown} declares `{name}` not exported, but "
                    f"there is no such file beside it; drop the marker"
                )
            elif target in reached:
                faults.append(
                    f"STALEMARK   {shown} declares `{name}` not exported, but "
                    f"the barrels reach it; drop the marker"
                )
            if reason is None:
                faults.append(
                    f"NOREASON    {shown} declares `{name}` not exported "
                    f"without saying why. Write the reason after an em dash"
                )
    return len(barrels)


def main(argv: list[str]) -> int:
    selected = packages(argv[1:])
    if not selected:
        print("no packages found -- is this being run outside tom_ai/core?")
        return 2

    faults: list[str] = []
    barrels = sum(audit(package, faults) for package in selected)

    # Guards the guard: a detection rule that stopped matching, or a root that
    # resolved somewhere empty, would find no barrels and report a clean tree.
    if not barrels:
        print(f"no barrels found in {len(selected)} package(s) -- the "
              f"detection rule in is_barrel() has stopped matching")
        return 2

    for fault in faults:
        print(fault)
    print(
        f"\n{barrels} barrel(s) across {len(selected)} package(s); "
        f"{len(faults)} fault(s)"
    )
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv))
