"""The trees the gates in this folder read: `tom_core` and `tom_core_extensions`.

Imported by the gates; it gates nothing itself.

**Why two roots.** The optional services built on the core
(`tom_ai/core_extension`, the `tom_core_extensions` repository) are held to the
same documentation invariants as the core: the same README shape, the same
module documents, the same doc-link and dartdoc rules. They live in a sibling
repository, so a gate that walked only this one would stop reading them the day
they moved, and its count would not change to say so. Every gate therefore reads
both trees through the functions here, and one baseline file holds both.

**Paths are named relative to their own root.** A file in the extensions is
named `tom_core_agentic/lib/...`, exactly as it was when the package lived here,
so a report's first path segment is always the package. Package names are
unique across the two repositories, which is what makes that unambiguous.
"""
from __future__ import annotations

import os
from pathlib import Path

TOOL_DIR = Path(__file__).resolve().parent

#: The `tom_core` repository (`tom_ai/core`).
REPO_ROOT = TOOL_DIR.parent

#: The `tom_core_extensions` repository (`tom_ai/core_extension`).
EXTENSIONS_ROOT = REPO_ROOT.parent / "core_extension"

#: Every root the gates read, the core first. A checkout without the
#: extensions reads the core alone.
ROOTS: tuple[Path, ...] = tuple(
    root for root in (REPO_ROOT, EXTENSIONS_ROOT) if root.is_dir()
)


def root_of(path: Path) -> Path:
    """The root [path] lies under; the core when it lies under neither."""
    resolved = Path(path).resolve()
    for root in ROOTS:
        if resolved == root or root in resolved.parents:
            return root
    return REPO_ROOT


def rel(path: Path) -> Path:
    """[path] relative to its own root (see the module comment)."""
    resolved = Path(path).resolve()
    for root in ROOTS:
        if resolved == root or root in resolved.parents:
            return resolved.relative_to(root)
    return Path(os.path.relpath(resolved, REPO_ROOT))


#: The folder of the core holding the samples and the two demo apps; a package
#: in it is found by its name like a top-level one.
SAMPLES = "tom_core_samples"


def package_dir(name: str) -> Path:
    """The directory of the package (or root-level folder) [name], in
    whichever root holds it -- at its top level, or, for a sample or demo app,
    in the core's `tom_core_samples/`; under the core when nothing does, so a
    gate that reports a missing package names the place it looked first."""
    for root in ROOTS:
        if (root / name).exists():
            return root / name
    if (REPO_ROOT / SAMPLES / name / "pubspec.yaml").is_file():
        return REPO_ROOT / SAMPLES / name
    return REPO_ROOT / name


def at(relative: str | Path) -> Path:
    """The absolute path of a root-relative [relative] path (the inverse of
    [rel]): its first segment names the package, which says which root."""
    parts = Path(relative).parts
    if not parts:
        return REPO_ROOT
    return package_dir(parts[0]).joinpath(*parts[1:])


def scope(subtree: str | None = None) -> list[Path]:
    """The roots a gate walks: every root, or the one directory [subtree]
    (a root-relative path, as a gate's command-line argument names it)."""
    return [at(subtree)] if subtree else list(ROOTS)


def glob_all(pattern: str) -> list[Path]:
    """`Path.glob(pattern)` over every root, the core's matches first."""
    found: list[Path] = []
    for root in ROOTS:
        found += sorted(root.glob(pattern))
    return found


def rglob_all(pattern: str) -> list[Path]:
    """`Path.rglob(pattern)` over every root, the core's matches first."""
    found: list[Path] = []
    for root in ROOTS:
        found += sorted(root.rglob(pattern))
    return found


def top_level_entries() -> list[Path]:
    """The entries directly under every root, each root's sorted by name."""
    found: list[Path] = []
    for root in ROOTS:
        found += sorted(root.iterdir())
    return found


def tracked_files(*pathspecs: str) -> list[Path]:
    """Every file `git ls-files` lists in every root, as absolute paths, the
    core's first. [pathspecs] narrow the listing as they would `git ls-files`
    in each repository; a root that is not a git checkout lists nothing."""
    import subprocess

    found: list[Path] = []
    for root in ROOTS:
        out = subprocess.run(
            ["git", "ls-files", "-z", "--", *pathspecs],
            cwd=root, capture_output=True, text=True,
        )
        if out.returncode != 0:
            continue
        found += [root / p for p in out.stdout.split("\0") if p]
    return found
