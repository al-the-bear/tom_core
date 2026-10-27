#!/usr/bin/env python3
"""Analyze every checked-in `*.reflection.dart`, which nothing else does.

Run from anywhere::

    python3 tool/check_reflection_artifacts.py
    python3 tool/check_reflection_artifacts.py --self-test
    python3 tool/check_reflection_artifacts.py --no-cache   # analyze everything

**The hole this closes.** `analysis_options.yaml` excludes
`**/*.reflection.dart` from analysis, for a good reason: a mirror reflects
whatever its source declares, including members that are deprecated or
`@visibleForTesting`, and a generated file that trips six lints per package
teaches everyone to ignore the analyzer. The cost is that the artifact is the
one file in the repository nothing reads. It is not compiled by `dart analyze`,
it is not formatted, and it is not reviewed — so a *reference* in it can rot
silently. `advanced_ops_server` carried one: `MariadbMigrationAdaptor` lost
`splitSqlStatements` to the SQL-lexer extraction, the checked-in mirror went on
naming it, and `dart analyze lib test` stayed clean while every test file in the
package failed to load with `Member not found`. The sample looked healthy right
up to the moment its tests were run.

**Why analysis and not regeneration.** `reflection_generation.sh --check`
answers a stronger question — is this file what the generator would emit today
— and answers it in about ninety seconds per package, twenty-odd minutes for
the repository. That is the right check to run before a release and the wrong
one to run on every gate pass. This one asks the weaker question that covers
the failure above: does every name the artifact writes still resolve. It costs
about four seconds per package because the analyzer is already the tool for it,
and an explicitly named file is analyzed whether or not the options exclude it.

The two are complements, and the difference is worth stating. An artifact can
pass here and still be stale: a mirror that is merely *missing* a class the
source has added references nothing that does not exist. What it cannot do is
pass here and fail to compile, which is the failure that takes a suite down.

**Only `error` severity counts.** A warning or an info in generated code is the
generator's style — `deprecated_member_use` on a reflected deprecated member is
the mirror doing its job — and faulting on it would recreate the noise the
exclusion exists to suppress. An `error` is different in kind: it is a name that
does not resolve, and a file full of them is a file that will not compile.
"""

from __future__ import annotations

import subprocess
import shutil
import sys
import tempfile
from pathlib import Path

from gate_cache import GateCache, _root_digest, package_key
from gate_report import report_faults
import gate_scope

REPO_ROOT = Path(__file__).resolve().parent.parent

#: Directories the walk does not enter. `ztmp` is the scratch tree
#: `check_doc_dart_blocks.py` writes; `build` and `.dart_tool` hold copies this
#: repository does not author.
SKIPPED = {"ztmp", "build", "coverage", ".dart_tool", ".git"}

#: Packages the walk must reach. Not the scope — the scope is every artifact —
#: but landmarks, because one subprocess over an empty file list analyzes
#: nothing and passes, reporting a clean tree it never opened.
LANDMARKS = ["tom_core_kernel", "tom_core_server", "advanced_ops_server"]

#: The floor the walk has to clear, stated loosely: the count is supposed to
#: move as packages come and go.
MINIMUM_ARTIFACTS = 25


def artifacts() -> list[Path]:
    """Every checked-in reflection artifact under [REPO_ROOT], sorted."""
    found: list[Path] = []
    stack = list(gate_scope.ROOTS)
    while stack:
        directory = stack.pop()
        for entry in sorted(directory.iterdir()):
            if entry.is_dir():
                if entry.name in SKIPPED or entry.name.startswith("."):
                    continue
                stack.append(entry)
            elif entry.name.endswith(".reflection.dart"):
                found.append(entry)
    return sorted(found)


def owning_package(artifact: Path) -> Path | None:
    """The nearest ancestor of [artifact] holding a `pubspec.yaml`."""
    for parent in artifact.parents:
        if (parent / "pubspec.yaml").is_file():
            return parent
        if parent in gate_scope.ROOTS:
            break
    return None


def errors_in(package: Path, files: list[Path]) -> list[str]:
    """The `error`-severity findings the analyzer reports for [files].

    Named explicitly rather than analyzing the package, because the package's
    options exclude exactly these files — an explicit path is analyzed anyway,
    which is what makes this gate possible without changing the options.
    """
    relative = [str(path.relative_to(package)) for path in files]
    result = subprocess.run(
        ["dart", "analyze", *relative],
        cwd=package,
        capture_output=True,
        text=True,
    )
    return [
        line.strip()
        for line in (result.stdout + result.stderr).splitlines()
        if line.strip().startswith("error -")
    ]


def self_test() -> int:
    """Prove the reader sees an unresolvable name, and passes a sound file.

    Both directions, because a gate that reports nothing is indistinguishable
    from a clean tree unless it has been shown to report something.
    """
    package = REPO_ROOT / "tom_core_kernel"
    with tempfile.TemporaryDirectory(dir=package / "test") as scratch:
        sound = Path(scratch) / "sound.reflection.dart"
        sound.write_text("final int answer = 42;\n")
        if errors_in(package, [sound]):
            print("self-test: a sound file was reported", file=sys.stderr)
            return 2

        rotten = Path(scratch) / "rotten.reflection.dart"
        rotten.write_text(
            "import 'package:tom_core_kernel/tom_core_kernel.dart' as prefix0;\n"
            "final Object? gone = prefix0.TomBean.noSuchMemberAnywhere;\n"
        )
        reported = errors_in(package, [rotten])
        if not any("noSuchMemberAnywhere" in line for line in reported):
            print(
                "self-test: an unresolvable member was not reported — "
                f"got {reported}",
                file=sys.stderr,
            )
            return 2

        # The cache must not outlive a change in a dependency: an artifact
        # that did not move can still be broken by a member removed in another
        # package, which is the failure this gate exists for.
        dependent = REPO_ROOT / "tom_core_server"
        before = package_key(dependent, "self-test")
        (Path(scratch) / "probe.dart").write_text("// changed\n")
        _root_digest.cache_clear()
        after = package_key(dependent, "self-test")
        if before is None or before == after:
            print(
                "self-test: a change in tom_core_kernel left "
                "tom_core_server's cache key unchanged",
                file=sys.stderr,
            )
            return 2

    print("self-test: passed")
    return 0


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()

    found = artifacts()
    packages: dict[Path, list[Path]] = {}
    orphans: list[Path] = []
    for artifact in found:
        package = owning_package(artifact)
        if package is None:
            orphans.append(artifact)
        else:
            packages.setdefault(package, []).append(artifact)

    reached = {package.name for package in packages}
    missing = [name for name in LANDMARKS if name not in reached]
    if missing or len(found) < MINIMUM_ARTIFACTS:
        print(
            f"the walk found {len(found)} artifacts across {len(packages)} "
            "packages"
            + (f", missing {', '.join(missing)}" if missing else "")
            + " — it has gone wrong rather than found a smaller repository",
            file=sys.stderr,
        )
        return 2

    faults: list[str] = [
        f"{gate_scope.rel(artifact)}: outside any package"
        for artifact in orphans
    ]
    # A package whose inputs match its last clean run is not re-analyzed
    # (gate_cache.py says what the key covers). Only clean verdicts are stored,
    # so every reported error comes from a fresh analysis.
    cache = GateCache("check_reflection_artifacts",
                      enabled="--no-cache" not in argv)
    gate_source = Path(__file__).read_text(encoding="utf-8")
    for package in sorted(packages):
        name = str(gate_scope.rel(package))
        key = package_key(package, gate_source)
        if cache.get(name, key) is not None:
            continue
        # Asked here rather than up front: a package whose inputs match its
        # last clean run needs no analyzer, so a run on a machine without the
        # SDK still measures everything cached. One that does need analyzing
        # cannot be measured, and saying so is the gate's answer rather than a
        # traceback from the subprocess that could not start.
        if shutil.which("dart") is None:
            print("dart is not on PATH, so no artifact can be analyzed",
                  file=sys.stderr)
            return 2
        lines = errors_in(package, packages[package])
        if lines:
            cache.forget(name)
        else:
            cache.put_clean(name, key, [])
        for line in lines:
            faults.append(f"{name}  {line}")
    cache.save()

    for fault in faults:
        print(fault)

    print(f"\nartifacts analyzed       : {len(found)}")
    print(f"packages covered         : {len(packages)}")
    print(f"packages from the cache  : {cache.hits}")
    print(f"artifacts with an error  : {len(faults)}")
    if faults:
        print(
            "\nAn artifact is generated: regenerate it with the package's "
            "reflection_generation.sh and commit the result. Do not edit it."
        )
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
