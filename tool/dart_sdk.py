#!/usr/bin/env python3
"""Find the `dart` executable a gate needs, when the shell's PATH has none.

Several gates shell out to `dart` -- to format, to analyze, to build
documentation -- and each refuses to run without it rather than guess. That
refusal is right, but a developer who installed Flutter and never put its
`bin/` on PATH then gets those gates refusing on every run of the documented
command, and learns to read past them. The gate runner asks this module for a
`dart` and hands its directory to every gate it starts.

**Where it looks, in order.** Nothing here names a user, a machine or this
workspace's own install: the candidates are the places a Dart or Flutter SDK is
conventionally installed, relative to the home directory or the filesystem
root, plus what the environment already says.

1. `dart` on PATH -- nothing to do.
2. `DART_SDK` / `FLUTTER_ROOT`, the variables the SDKs themselves document.
3. `flutter` on PATH -- its `bin/` carries `dart` beside it.
4. The conventional install locations in [CANDIDATES].

The first `bin/` holding a runnable `dart` wins. When none does the caller is
told `None`, and the gates go on refusing, which is still the right answer on a
machine with no SDK at all.
"""

from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

#: Conventional SDK `bin/` directories, relative to the home directory (`~`) or
#: absolute. Generic by design: a location that is only true of one machine
#: belongs in that machine's PATH, not here.
CANDIDATES = [
    "~/flutter/bin",
    "~/development/flutter/bin",
    "~/Desktop/development/flutter/bin",
    "~/dev/flutter/bin",
    "~/sdk/flutter/bin",
    "~/sdks/flutter/bin",
    "~/tools/flutter/bin",
    "~/fvm/default/bin",
    "~/snap/flutter/common/flutter/bin",
    "/opt/flutter/bin",
    "/usr/local/flutter/bin",
    "/opt/homebrew/bin",
    "/usr/local/bin",
    "/usr/lib/dart/bin",
    "/opt/dart-sdk/bin",
    "C:/flutter/bin",
    "C:/src/flutter/bin",
    "C:/tools/dart-sdk/bin",
]

_EXECUTABLES = ["dart.exe", "dart.bat", "dart"] if sys.platform == "win32" else ["dart"]


def _holds_dart(directory: Path) -> bool:
    return any(
        (directory / name).is_file() and os.access(directory / name, os.X_OK)
        for name in _EXECUTABLES
    )


def dart_bin_directory() -> Path | None:
    """The directory of the `dart` a gate should use, or None if there is none."""
    on_path = shutil.which("dart")
    if on_path:
        return Path(on_path).resolve().parent

    candidates: list[Path] = []
    if os.environ.get("DART_SDK"):
        candidates.append(Path(os.environ["DART_SDK"]) / "bin")
    if os.environ.get("FLUTTER_ROOT"):
        candidates.append(Path(os.environ["FLUTTER_ROOT"]) / "bin")
    flutter = shutil.which("flutter")
    if flutter:
        candidates.append(Path(flutter).resolve().parent)
    candidates += [Path(os.path.expanduser(c)) for c in CANDIDATES]

    for candidate in candidates:
        if candidate.is_dir() and _holds_dart(candidate):
            return candidate.resolve()
    return None


def environment_with_dart() -> tuple[dict[str, str], Path | None]:
    """A copy of this process's environment with `dart`'s directory on PATH.

    Returns the environment and the directory that was added, or the
    environment unchanged and None when `dart` was already resolvable or could
    not be found -- the caller tells those apart with [dart_bin_directory].
    """
    env = dict(os.environ)
    if shutil.which("dart"):
        return env, None
    found = dart_bin_directory()
    if found is None:
        return env, None
    env["PATH"] = str(found) + os.pathsep + env.get("PATH", "")
    return env, found


if __name__ == "__main__":
    located = dart_bin_directory()
    print(located if located else "no dart found")
    sys.exit(0 if located else 1)
