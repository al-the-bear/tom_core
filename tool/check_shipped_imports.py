#!/usr/bin/env python3
"""Find Dart files a published archive ships that import outside their package.

Run from anywhere::

    python3 tool/check_shipped_imports.py              # every publishable package
    python3 tool/check_shipped_imports.py --self-test  # prove the check still fires

Exits non-zero when a shipped file's relative `import`, `export` or `part`
resolves outside the package that ships it.

**Why.** A package's archive holds the package directory and nothing above it.
A test that imports `../../tool/package_gate.dart` loads in this repository,
where `tom_ai/core/tool/` is beside the package, and fails to load from the
archive a consumer installs, where it is not. Every publishable framework
package carried such tests -- the repository-wide gates run as package tests --
and nothing said so until a consumer ran the shipped tests of an installed
archive. The answer for a test that is bound to this repository is not to ship
it: the package's `.pubignore` names it.

**What ships.** A package is publishable unless its pubspec says
`publish_to: none`; the samples and test harnesses under `tom_core_samples/`
are not packages anyone installs and are left out. Its shipped files are its
git-tracked files minus what pub leaves out: `.pubignore` when the package has
one, else `.gitignore` (pub reads one or the other, never both, which is why a
`.pubignore` repeats the `.gitignore` lines it still needs). Patterns follow
gitignore: a pattern holding a slash is anchored to the package directory, one
without matches a name at any depth, a trailing slash matches a directory,
and the last pattern that matches decides — a `!` pattern re-including what an
earlier one left out, as a tracked `pubspec.lock` is.

`package:` and `dart:` URIs are a dependency's business and are not checked.
"""

from __future__ import annotations

import fnmatch
import re
import sys
from pathlib import Path, PurePosixPath

from gate_report import report_faults
import gate_scope

#: A Dart directive naming a URI. `\\s+` crosses line breaks, so a directive
#: whose URI sits on the next line is still read.
DIRECTIVE = re.compile(
    r"^\s*(?:import|export|part(?:\s+of)?)\s+['\"]([^'\"]+)['\"]", re.M
)

PUBLISH_NONE = re.compile(r"^publish_to:\s*['\"]?none['\"]?\s*$", re.M)


def ignore_patterns(package: Path) -> list[str]:
    """The patterns pub applies at the package root: `.pubignore` or `.gitignore`."""
    for name in (".pubignore", ".gitignore"):
        file = package / name
        if file.is_file():
            patterns = []
            for line in file.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                patterns.append(line)
            return patterns
    return []


def ignored(relative: PurePosixPath, patterns: list[str]) -> bool:
    """Whether [patterns] leave [relative] out: the last pattern that matches
    decides, a `!` pattern re-including it."""
    left_out = False
    for line in patterns:
        negated = line.startswith("!")
        if _matches(relative, line[1:] if negated else line):
            left_out = not negated
    return left_out


def _matches(relative: PurePosixPath, raw: str) -> bool:
    """Whether the gitignore pattern [raw] (without its `!`) matches [relative]."""
    parts = relative.parts
    directory = raw.endswith("/")
    pattern = raw.strip("/") if raw.startswith("/") else raw.rstrip("/")
    anchored = raw.startswith("/") or "/" in pattern
    pattern = pattern.lstrip("/")
    # A directory pattern matches any leading run of the path's parent
    # directories; a file pattern matches the path itself as well.
    candidates = [PurePosixPath(*parts[:i]) for i in range(1, len(parts))]
    if not directory:
        candidates.append(relative)
    for candidate in candidates:
        if anchored:
            if fnmatch.fnmatchcase(str(candidate), pattern):
                return True
        elif fnmatch.fnmatchcase(candidate.name, pattern):
            return True
    return False


def publishable_packages() -> list[Path]:
    packages = []
    for pubspec in gate_scope.tracked_files("pubspec.yaml", "*/pubspec.yaml"):
        package = pubspec.parent
        if gate_scope.SAMPLES in gate_scope.rel(package).parts:
            continue
        if PUBLISH_NONE.search(pubspec.read_text(encoding="utf-8")):
            continue
        packages.append(package)
    return sorted(packages)


def shipped_dart_files(package: Path) -> list[Path]:
    patterns = ignore_patterns(package)
    shipped = []
    for file in gate_scope.tracked_files(f"{gate_scope.rel(package)}/*.dart"):
        relative = PurePosixPath(file.relative_to(package).as_posix())
        if not ignored(relative, patterns):
            shipped.append(file)
    return sorted(shipped)


def escapes(file: Path, text: str, package: Path) -> list[str]:
    """The relative URIs in [text] that resolve outside [package]."""
    outside = []
    for match in DIRECTIVE.finditer(text):
        uri = match.group(1)
        if ":" in uri:
            continue
        target = (file.parent / uri).resolve()
        if not target.is_relative_to(package.resolve()):
            outside.append(uri)
    return outside


def find_faults() -> tuple[int, list[tuple[Path, str]]]:
    files = 0
    faults: list[tuple[Path, str]] = []
    for package in publishable_packages():
        for file in shipped_dart_files(package):
            files += 1
            text = file.read_text(encoding="utf-8", errors="replace")
            for uri in escapes(file, text, package):
                faults.append((file, uri))
    return files, faults


def self_test() -> int:
    """Damage a shipped file in memory, require the objection, restore it."""
    package = next(iter(publishable_packages()), None)
    if package is None:
        print("self-test: no publishable package found", file=sys.stderr)
        return 1
    file = next(iter(shipped_dart_files(package)), None)
    if file is None:
        print(f"self-test: {gate_scope.rel(package)} ships no Dart file", file=sys.stderr)
        return 1
    clean = file.read_text(encoding="utf-8")
    if escapes(file, clean, package):
        print(f"self-test: {gate_scope.rel(file)} is not clean to start from", file=sys.stderr)
        return 1
    damaged = "import '../../../tool/package_gate.dart';\n" + clean
    if escapes(file, damaged, package) != ["../../../tool/package_gate.dart"]:
        print("self-test: an import outside the package was not reported", file=sys.stderr)
        return 1
    if not ignored(PurePosixPath("test/formatting_test.dart"), ["test/formatting_test.dart"]):
        print("self-test: an anchored .pubignore line did not match", file=sys.stderr)
        return 1
    if not ignored(PurePosixPath("test/a/b_test.dart"), ["test/"]):
        print("self-test: a directory .pubignore line did not match", file=sys.stderr)
        return 1
    if ignored(PurePosixPath("lib/test_util.dart"), ["test/"]):
        print("self-test: a directory line matched a file of a similar name", file=sys.stderr)
        return 1
    if ignored(PurePosixPath("pubspec.lock"), ["*.lock", "!/pubspec.lock"]):
        print("self-test: a negated line did not re-include its file", file=sys.stderr)
        return 1
    if not ignored(PurePosixPath("other.lock"), ["*.lock", "!/pubspec.lock"]):
        print("self-test: a negated line re-included another file", file=sys.stderr)
        return 1
    print("self-test: passed")
    return 0


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()
    files, faults = find_faults()
    for file, uri in faults:
        print(
            f"{gate_scope.rel(file)}: ships `{uri}`, which resolves outside its "
            "package and is absent from the archive -- name the file in the "
            "package's .pubignore, or move what it imports into the package"
        )
    print()
    print(f"shipped Dart files checked : {files}")
    print(f"imports leaving the package: {len(faults)}")
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
