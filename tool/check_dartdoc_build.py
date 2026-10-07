#!/usr/bin/env python3
"""Build each gated package's API documentation, require a silent build, and
require every doc-comment link to land in a package the writer depends on.

Run from anywhere::

    python3 tool/check_dartdoc_build.py                  # the gated packages
    python3 tool/check_dartdoc_build.py tom_core_server  # one package, ad hoc

Exits non-zero when `dart doc` reports anything, or when a doc comment's link
lands in a package the writing package does not depend on.

**The defect.** A dartdoc reference that does not resolve renders as literal
brackets. There is no error at the writing end and nothing looks wrong at the
reading end -- the reader sees `[TomAuthState]` as text, follows nothing, and
has no way to know a link was intended. The only thing in the toolchain that
says so is `dart doc` itself, and nothing was running it.

Left alone the class does not stay still. Eight unresolved references were
recorded on 2026-08-19; three weeks later the same command reported eleven --
two of the original eight had been repaired in passing and five new ones had
arrived, in four modules that had nothing to do with each other. That is drift
at a rate no review catches, because each one is a single bracketed word inside
a comment that reads perfectly.

**Why this and not `check_dartdoc_refs.py`.** That gate answers a deliberately
narrower question -- does the named symbol *exist* -- and declines the scope
question on purpose, because thousands of correct cross-library references in
this tree do not resolve from the library writing them and separating the ones
that want an import from the ones that want backticks is an architectural
judgement, not a rule. See its module docstring; the argument is sound and this
gate does not reopen it.

What makes the scope question answerable *here* is the population. `dart doc`
judges only what is reachable from the package barrel -- the published API
surface, where a reference either resolves for the reader or does not, with no
import graph to trade away. Eleven references in tom_core_kernel, not the 353
the lint would have raised. So the two gates are complements: existence
everywhere, resolution on the surface that ships.

**Every warning counts, not only unresolved references.** The rule is that the
documentation build is silent, because a build that is allowed to say one thing
is a build nobody reads.

**A silent build is necessary, not sufficient.** `dart doc` resolves a
reference by walking outward until something answers, and an answer is not a
warning. ``[hash]``, written in ``advanced_auth_server`` for a record's own
field, bound to `vector_math`'s deprecated `hash` library -- a transitive
dependency the package never names -- and rendered a live link to it with zero
warnings. So the rendered prose is read before the HTML is deleted:
``dartdoc_links.py`` reports every link in doc-comment text (not signatures)
into a package that is neither a direct dependency nor re-exported by one. Each
such link is a fault. A package whose pages render no doc prose at all is
refused as not measured rather than passed.

**The rendered output is otherwise thrown away.** The HTML tree is 18 MB for
tom_core_kernel alone; the log names every warning by file and line and is kept
beside the scratch directory so a failure can be read after the fact.

**Packages are built in parallel.** `dart doc` takes twelve to thirty seconds a
package, nearly all of it analysis, so eleven serial builds would cost four
minutes; side by side they take about eighty seconds. That is what lets the
eight `advanced_*` sample packages be gated here rather than by a runner of
their own, which nobody was obliged to invoke.

**Packages are gated only once they are silent**, the same rule
`check_doc_dart_blocks.py` states: adding one with a backlog would pin the
backlog rather than fix it. Run an ungated package with the argument to survey
it.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from dartdoc_links import allowed_packages, scan, self_test
from gate_report import report_faults

TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parent
SCRATCH = TOOL_DIR / "ztmp" / "dartdoc"

#: Packages whose documentation build must be silent. Triaged to zero first --
#: see the module docstring. `tom_core_server` and the Flutter-side packages
#: have not been surveyed. The `advanced_*` samples are discovered rather than
#: listed, so a ninth is gated the day it is added.
PACKAGES = ["tom_core_kernel", "tom_core_agentic", "tom_core_codespecs"] + sorted(
    f"tom_core_samples/{d.name}"
    for d in (REPO_ROOT / "tom_core_samples").glob("advanced_*")
    if (d / "pubspec.yaml").is_file())

#: Concurrent `dart doc` processes. Each is single-threaded analysis.
WORKERS = max(1, min(6, (os.cpu_count() or 2) // 2))

#: The opening line of a warning, and the location line that follows it.
WARNING = re.compile(r"^\s*warning:\s*(.+)$")
LOCATION = re.compile(r"^\s+from\s+(.+?):\s*\(file://(.+?)\)\s*$")
#: `dart doc`'s own verdict, which is the count this gate reports.
VERDICT = re.compile(r"^Found (\d+) warnings? and (\d+) errors?\.")


def build(package: Path) -> tuple[str, int, list[str], int]:
    """`(log, exit status, stray links, prose blocks read)` for `package`.

    The links are read from the generated HTML before it is deleted.
    """
    output = SCRATCH / package.name
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        ["dart", "doc", "--output", str(output)],
        capture_output=True, text=True, cwd=package)
    log = done.stdout + done.stderr
    (SCRATCH / f"{package.name}.log").write_text(log, encoding="utf-8")
    stray, blocks, _ = scan(output, allowed_packages(package))
    shutil.rmtree(output, ignore_errors=True)
    return log, done.returncode, stray, blocks


def faults_in(log: str) -> tuple[list[str], int, int]:
    """`(rendered warnings, warnings, errors)` as `dart doc` reported them.

    The counts come from `dart doc`'s own verdict line rather than from the
    length of the list: a warning shape this parser does not recognise must
    still be counted, or the gate would go quiet on the one it understood least.
    """
    rendered: list[str] = []
    lines = log.split("\n")
    for index, line in enumerate(lines):
        match = WARNING.match(line)
        if not match:
            continue
        where = ""
        if index + 1 < len(lines):
            place = LOCATION.match(lines[index + 1])
            if place:
                path = place.group(2)
                try:
                    path = str(Path(path.split(":")[0]).relative_to(REPO_ROOT))
                except ValueError:
                    pass
                tail = ":".join(place.group(2).split(":")[1:])
                where = f"  {path}:{tail}  ({place.group(1)})"
        rendered.append(f"{match.group(1)}\n{where}".rstrip())

    warnings = errors = 0
    for line in lines:
        verdict = VERDICT.match(line)
        if verdict:
            warnings += int(verdict.group(1))
            errors += int(verdict.group(2))
    return rendered, warnings, errors


def main(argv: list[str]) -> int:
    wanted = argv[1:] or PACKAGES
    if subprocess.run(["which", "dart"], capture_output=True).returncode != 0:
        print("dart is not on PATH, so no documentation can be built",
              file=sys.stderr)
        return 2

    # The link reader is checked on every run: a reader that has stopped
    # matching dartdoc's markup would pass every package having judged nothing.
    if self_test() != 0:
        return 2

    SCRATCH.mkdir(parents=True, exist_ok=True)
    packages = [REPO_ROOT / name for name in wanted]
    for package in packages:
        if not (package / "pubspec.yaml").is_file():
            print(f"{package.name} is not a package under {REPO_ROOT}",
                  file=sys.stderr)
            return 2

    with ThreadPoolExecutor(WORKERS) as pool:
        results = list(pool.map(build, packages))

    faults = 0
    for package, (log, status, stray, blocks) in zip(packages, results):
        name = package.name
        rendered, warnings, errors = faults_in(log)
        if status != 0 and warnings == 0 and errors == 0:
            # The build did not merely complain, it failed -- and said so
            # somewhere this parser does not read. Surface the log rather than
            # reporting a clean package.
            print(f"=== dart doc failed for {name} ===\n{log}",
                  file=sys.stderr)
            return 2
        if blocks == 0:
            print(f"{name}: no doc-comment prose found in the generated pages, "
                  "so no link was judged; not measured", file=sys.stderr)
            return 2
        if rendered or stray:
            print(f"=== {name} ===")
            for entry in rendered:
                print(entry)
            for link in stray:
                print(f"link outside the dependencies: {link}")
        print(f"{name:26} {warnings:3d} warning(s)  {errors:3d} error(s)  "
              f"{len(stray):3d} stray link(s)")
        faults += warnings + errors + len(stray)

    print(f"\npackages built          : {len(packages)}\n"
          f"logs                    : "
          f"{SCRATCH.relative_to(REPO_ROOT)}/<package>.log")
    return report_faults(faults)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
