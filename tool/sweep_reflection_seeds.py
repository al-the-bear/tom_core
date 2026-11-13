#!/usr/bin/env python3
"""Check every sample's reflection seed against what the generator emits today.

Run from anywhere, by hand::

    python3 tool/sweep_reflection_seeds.py                 # every seed (~15 min)
    python3 tool/sweep_reflection_seeds.py todo_domain ops # a subset, by name part
    python3 tool/sweep_reflection_seeds.py --status        # the last sweep, and what moved since
    python3 tool/sweep_reflection_seeds.py --list          # the seeds it would check
    python3 tool/sweep_reflection_seeds.py --help          # this text

Exits 0 only when every selected seed was measured and is up to date.

**Why this exists.** The `*.reflection.dart` seeds under
`tom_core_samples/` mirror every type reachable from their roots, the
framework's included, so they go stale **without any edit in their own
package**: a `tom_core_kernel` or `tom_core_server` member added, or a new
`tom_reflection_generator`, moves them. A stale seed still analyzes and still
passes every suite, and `check_reflection_artifacts.py` checks only that the
names it cites resolve. The one detector is the generator's own
`./reflection_generation.sh --check`, per package -- and a manual sweep of all
of them found seven stale seeds once and four more a week later, every time
after the framework change that moved them had long been committed.

**Why it is not a gate.** Each package's check builds analyzer summaries for
its whole dependency graph: about a minute for a Dart package and two to three
for a Flutter one, about fifteen minutes in all, against a gate suite of three.
It is a script you run, and the moments to run it are named in
`tom_core_samples/README.md` § "Reflection seeds": after a framework change a
sample reaches, after a generator upgrade, and before a release. Nothing runs it
on a schedule -- the workspace starts builds and checks by hand.

**Remembering to run it** is what failed twice, so the script records each
full sweep (a subset is not recorded, since it does not say every seed is
fresh) (machine-local, in ``tool/ztmp/reflection_sweep/last_run.json``) and
``--status`` answers the question that matters without the fifteen minutes:
when the last sweep ran, what it found, and which inputs have changed since --
the framework packages' ``lib/`` and each sample, compared by content, so an
uncommitted edit counts and the commit that records regenerated seeds does not.
A changed framework package makes every seed suspect; a changed sample, its own.

**Verdicts, one per seed:**

``FRESH``
    The generator checked the seed and found it equal to what it emits.
``STALE``
    The generator named the seed as differing (or missing). The remedy is to
    run ``./reflection_generation.sh`` in that package, run its suite against
    the result, and commit the seed with the change that moved it.
``FAILED``
    The generator could not check -- a resolution failure, a pub cache that
    cannot supply a locked package. Its log is named.
``NOT MEASURED``
    The run exited cleanly without checking anything. Reported as its own
    verdict rather than as fresh: a script that matched no file is not a seed
    that passed.

Seeds are found by walking `tom_core_samples/` for tracked `*.reflection.dart`
files, not from a list, and a package holding one without a
`reflection_generation.sh` beside its pubspec is reported -- it has a seed
nobody can check.

The full output of each check is kept under
``tool/ztmp/reflection_sweep/<package>.log``.
"""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SAMPLES = REPO_ROOT / "tom_core_samples"
SCRIPT = "reflection_generation.sh"
LOG_DIR = REPO_ROOT / "tool" / "ztmp" / "reflection_sweep"
RECORD = LOG_DIR / "last_run.json"

#: Packages whose `lib/` can move a sample's seed. Each sample is an input to
#: its own seed too, and its `pubspec.lock` carries the generator version.
FRAMEWORK = ["tom_core_kernel", "tom_core_server", "tom_core_flutter",
             "tom_flutter_ui"]

STALE_LINE = re.compile(r"^\s*STALE(?: \([a-z]+\))?: (.+?)\s*$", re.M)
SUCCEEDED = re.compile(r"Reflection check succeeded .*?(\d+) up to date")
FAILED = re.compile(r"Reflection (?:check|generation) FAILED")


@dataclass
class Result:
    package: str
    verdict: str
    seconds: float
    stale: list[str] = field(default_factory=list)
    log: str = ""


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=REPO_ROOT, capture_output=True,
                          text=True, check=True).stdout


def seed_packages() -> tuple[list[str], list[str]]:
    """Packages with a tracked seed, and those among them with no script."""
    seeds = git("ls-files", "--", "tom_core_samples/*.reflection.dart")
    packages = sorted({Path(p).parts[1] for p in seeds.split()})
    unscripted = [p for p in packages if not (SAMPLES / p / SCRIPT).is_file()]
    return [p for p in packages if p not in unscripted], unscripted


def classify(package: str, exit_code: int, output: str) -> Result:
    # The generator names a stale file twice, once absolute and once relative
    # to the package; report each once, relative to the repository.
    root = SAMPLES / package
    stale = sorted({
        str((root / found).resolve().relative_to(REPO_ROOT))
        for found in STALE_LINE.findall(output)
    })
    if stale:
        return Result(package, "STALE", 0, stale)
    if exit_code != 0 or FAILED.search(output):
        return Result(package, "FAILED", 0)
    match = SUCCEEDED.search(output)
    if match and int(match.group(1)) > 0:
        return Result(package, "FRESH", 0)
    return Result(package, "NOT MEASURED", 0)


def check(package: str) -> Result:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log = LOG_DIR / f"{package}.log"
    started = time.monotonic()
    run = subprocess.run([f"./{SCRIPT}", "--check"], cwd=SAMPLES / package,
                         capture_output=True, text=True)
    output = run.stdout + run.stderr
    log.write_text(output, encoding="utf-8")
    result = classify(package, run.returncode, output)
    result.seconds = round(time.monotonic() - started, 1)
    result.log = str(log.relative_to(REPO_ROOT))
    return result


def digest(paths: list[Path]) -> str:
    """One hash over the content of [paths], as they are on disk now."""
    hasher = hashlib.sha256()
    for path in sorted(paths):
        hasher.update(str(path.relative_to(REPO_ROOT)).encode())
        hasher.update(b"\0")
        hasher.update(path.read_bytes() if path.is_file() else b"<absent>")
        hasher.update(b"\0")
    return hasher.hexdigest()


def tracked(pathspec: str) -> list[Path]:
    return [REPO_ROOT / name for name in git("ls-files", "--", pathspec).split()]


def input_digests(packages: list[str]) -> dict[str, str]:
    """A content digest of everything that can move a seed, by input.

    The framework packages are read through `lib/` only -- their tests and
    docs cannot reach a mirror. A sample is read whole except for its seeds,
    which are the output, plus its `pubspec.lock`, which pins the generator and
    is not tracked.
    """
    digests = {name: digest(tracked(f"{name}/lib")) for name in FRAMEWORK}
    for package in packages:
        files = [f for f in tracked(f"tom_core_samples/{package}")
                 if not f.name.endswith(".reflection.dart")]
        files.append(SAMPLES / package / "pubspec.lock")
        digests[f"tom_core_samples/{package}"] = digest(files)
    return digests


def status() -> int:
    if not RECORD.is_file():
        print("No sweep has been recorded on this machine. Run:\n"
              "    python3 tool/sweep_reflection_seeds.py")
        return 1
    record = json.loads(RECORD.read_text(encoding="utf-8"))
    print(f"last sweep : {record['finished']} at commit {record['commit'][:10]}")
    for row in record["results"]:
        print(f"  {row['verdict']:13} {row['package']}")
    now = input_digests([r["package"] for r in record["results"]])
    then = record.get("inputs")
    if then is None:
        print("The recorded sweep holds no input digests, so what changed since "
              "cannot be told. Run the sweep again.")
        return 1
    changed = sorted(k for k in now if then.get(k) != now[k])
    if changed:
        print("changed since, so the seeds are unverified:")
        for name in changed:
            print(f"  {name}")
    else:
        print("changed since: nothing that can move a seed")
    healthy = all(r["verdict"] == "FRESH" for r in record["results"])
    if changed or not healthy:
        print("Run the sweep again before relying on the seeds.")
        return 1
    return 0


OPTIONS = ("--status", "--list", "--help", "-h")


def main(argv: list[str]) -> int:
    unknown = [a for a in argv if a.startswith("-") and a not in OPTIONS]
    if unknown:
        # An unknown option is refused rather than ignored: ignored, it would
        # start the full fifteen-minute sweep the caller did not ask for.
        print(f"unknown option {' '.join(unknown)}; see --help", file=sys.stderr)
        return 2
    if "--help" in argv or "-h" in argv:
        print(__doc__)
        return 0
    if argv == ["--status"]:
        return status()
    packages, unscripted = seed_packages()
    wanted = [a for a in argv if not a.startswith("--")]
    if wanted:
        # An exact name selects that package alone, so `todo_domain` does not
        # also pick `advanced_todo_domain`; anything else is a name part.
        packages = [p for p in packages
                    if any(w == p or (w not in packages and w in p)
                           for w in wanted)]
        if not packages:
            print(f"no seeded package matches {' '.join(wanted)}",
                  file=sys.stderr)
            return 2
    if "--list" in argv:
        for p in packages:
            print(p)
        for p in unscripted:
            print(f"{p}  (no {SCRIPT})")
        return 0

    if shutil.which("dart") is None:
        # Without it every check fails at once and the sweep reports each seed
        # FAILED in 0 s, which reads as a broken generator rather than a PATH.
        print("dart is not on PATH; put the Flutter SDK's bin directory on it "
              "first", file=sys.stderr)
        return 2

    commit = git("rev-parse", "HEAD").strip()
    # Taken before the checks, so an edit made while they run reads as a
    # change at the next --status rather than being certified by this sweep.
    inputs = input_digests(packages)
    results: list[Result] = []
    for index, package in enumerate(packages, 1):
        print(f"[{index}/{len(packages)}] {package} ...", flush=True)
        result = check(package)
        results.append(result)
        print(f"    {result.verdict} in {result.seconds:.0f} s", flush=True)

    print()
    for r in results:
        print(f"{r.verdict:13} {r.package:32} {r.seconds:6.0f} s")
        for path in r.stale:
            print(f"{'':13} stale: {path}")
        if r.verdict in ("FAILED", "NOT MEASURED"):
            print(f"{'':13} log:   {r.log}")
    for p in unscripted:
        print(f"{'UNCHECKABLE':13} {p:32}  has a seed and no {SCRIPT}")

    if not wanted:
        RECORD.write_text(json.dumps({
            "finished": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "commit": commit,
            "inputs": inputs,
            "results": [asdict(r) for r in results],
        }, indent=1) + "\n", encoding="utf-8")

    bad = [r for r in results if r.verdict != "FRESH"]
    print()
    print(f"seeds checked            : {len(results)}")
    print(f"not fresh                : {len(bad)}")
    print(f"without a script         : {len(unscripted)}")
    if any(r.verdict == "STALE" for r in results):
        print("Regenerate each stale package with ./reflection_generation.sh, "
              "run its suite, and commit the seed with the change that moved it.")
    return 0 if not bad and not unscripted else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
