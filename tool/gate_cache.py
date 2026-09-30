#!/usr/bin/env python3
"""Remember a clean analyzer verdict until something it depends on changes.

The analyzer-backed gates spend nearly all their time waiting on `dart
analyze`, once per package, over inputs that change rarely. A run after an
unrelated edit repeats every one of those analyses to reach the answer the
last run already reached. This module lets a gate skip a package whose inputs
are byte-identical to the last run that found it clean.

**What the key covers, and why each part is there.** A verdict about a package
depends on more than the package:

* its resolved `package_config.json` -- which hosted versions it compiles
  against; a hosted package's version is part of its path in that file, so the
  file's bytes pin every hosted dependency;
* every file under every dependency root that lives *inside this workspace* --
  the package itself and its path dependencies. That is the half the file
  cannot pin, and it is the failure the reflection gate was written for: an
  artifact that did not change, broken by a member removed in another package;
* the Dart SDK version, because the analyzer is part of it;
* the gate's own source, so a changed gate never reuses its old verdicts;
* whatever the gate adds -- the documents it reads, for instance.

A package with no resolved config is never cached: without it the dependency
set is unknown, and a key that does not cover the inputs is worse than none.

**Only clean verdicts are stored.** A package with a fault is analyzed afresh
every time, so a reported fault always comes from a real analysis -- and the
gates that leave evidence behind for a failure (the scratch sources
`check_doc_dart_blocks.py` writes) still leave it. The run this makes fast is
the common one: the tree is clean and nothing relevant moved.

Force a full run with ``--no-cache`` on any gate that uses this, or by
deleting ``tool/ztmp/gate_cache/``.
"""

from __future__ import annotations

import hashlib
import json
import subprocess
from functools import lru_cache
from pathlib import Path
from urllib.parse import unquote, urlparse

TOOL_DIR = Path(__file__).resolve().parent
#: `tom_ai/core` -> `tom_ai` -> the workspace root. Dependency roots inside it
#: are hashed file by file; roots outside it are pinned by the config.
WORKSPACE = TOOL_DIR.parent.parent.parent
CACHE_DIR = TOOL_DIR / "ztmp" / "gate_cache"

#: Directories under a dependency root that are not its source.
_NOT_SOURCE = {".dart_tool", "build", ".git", "ztmp", "coverage", "testlog"}


@lru_cache(maxsize=None)
def _sdk_version() -> str:
    try:
        done = subprocess.run(
            ["dart", "--version"], capture_output=True, text=True
        )
        return (done.stdout + done.stderr).strip()
    except OSError:
        return "no-dart"


@lru_cache(maxsize=None)
def _root_digest(root: Path) -> str:
    """Every file under [root] that is its source, by path and content."""
    digest = hashlib.sha256()
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root)
        if _NOT_SOURCE & set(relative.parts) or not path.is_file():
            continue
        digest.update(str(relative).encode())
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def _workspace_roots(config: Path) -> list[Path]:
    """The package roots [config] resolves inside the workspace."""
    data = json.loads(config.read_text(encoding="utf-8"))
    roots: set[Path] = set()
    for entry in data.get("packages", []):
        uri = entry.get("rootUri", "")
        if uri.startswith("file:"):
            root = Path(unquote(urlparse(uri).path))
        else:
            root = (config.parent / unquote(uri)).resolve()
        try:
            root.resolve().relative_to(WORKSPACE)
        except ValueError:
            continue
        if root.is_dir():
            roots.add(root.resolve())
    return sorted(roots)


def package_key(package: Path, gate_source: str, *extra: str) -> str | None:
    """The key for a verdict about [package], or None when it cannot be keyed."""
    config = package / ".dart_tool" / "package_config.json"
    if not config.is_file():
        return None
    digest = hashlib.sha256()
    digest.update(_sdk_version().encode())
    digest.update(gate_source.encode())
    digest.update(config.read_bytes())
    for root in _workspace_roots(config):
        digest.update(str(root).encode())
        digest.update(_root_digest(root).encode())
    for part in extra:
        digest.update(b"\0")
        digest.update(part.encode())
    return digest.hexdigest()


class GateCache:
    """The clean verdicts one gate has recorded, keyed by package."""

    def __init__(self, gate: str, enabled: bool = True) -> None:
        self.enabled = enabled
        self.path = CACHE_DIR / f"{gate}.json"
        self.hits = 0
        self._entries: dict[str, dict] = {}
        if enabled and self.path.is_file():
            try:
                self._entries = json.loads(self.path.read_text())
            except (OSError, ValueError):
                self._entries = {}

    def get(self, package: str, key: str | None):
        """The stored clean result for [package] under [key], or None."""
        if not self.enabled or key is None:
            return None
        entry = self._entries.get(package)
        if entry is None or entry.get("key") != key:
            return None
        self.hits += 1
        return entry.get("result")

    def put_clean(self, package: str, key: str | None, result) -> None:
        """Record a clean [result]. A faulty one is never stored."""
        if not self.enabled or key is None:
            return
        self._entries[package] = {"key": key, "result": result}

    def forget(self, package: str) -> None:
        self._entries.pop(package, None)

    def save(self) -> None:
        if not self.enabled:
            return
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps(self._entries, indent=1, sort_keys=True))
