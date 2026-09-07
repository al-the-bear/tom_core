#!/usr/bin/env python3
"""Build each gated package's API documentation and require a silent build.

Run from anywhere::

    python3 tool/check_dartdoc_build.py                  # the gated packages
    python3 tool/check_dartdoc_build.py tom_core_server  # one package, ad hoc

Exits non-zero when `dart doc` reports anything, so it can gate a build.

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

**The rendered output is thrown away.** What this gate wants is the log, and the
log names every fault by file and line; the HTML tree is 18 MB for
tom_core_kernel alone and regenerating it is most of the run time either way.
The log is kept beside the scratch directory so a failure can be read after the
fact.

**Packages are gated only once they are silent**, the same rule
`check_doc_dart_blocks.py` states: adding one with a backlog would pin the
backlog rather than fix it. Run an ungated package with the argument to survey
it.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path

from gate_report import report_faults

TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parent
SCRATCH = TOOL_DIR / "ztmp" / "dartdoc"

#: Packages whose documentation build must be silent. Triaged to zero first --
#: see the module docstring. `tom_core_server` and the Flutter-side packages
#: have not been surveyed.
PACKAGES = ["tom_core_kernel", "tom_core_agentic", "tom_core_codespecs"]

#: The opening line of a warning, and the location line that follows it.
WARNING = re.compile(r"^\s*warning:\s*(.+)$")
LOCATION = re.compile(r"^\s+from\s+(.+?):\s*\(file://(.+?)\)\s*$")
#: `dart doc`'s own verdict, which is the count this gate reports.
VERDICT = re.compile(r"^Found (\d+) warnings? and (\d+) errors?\.")


def build(package: Path) -> tuple[str, int]:
    """`(log, exit status)` from documenting `package` into the scratch tree."""
    output = SCRATCH / package.name
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        ["dart", "doc", "--output", str(output)],
        capture_output=True, text=True, cwd=package)
    log = done.stdout + done.stderr
    (SCRATCH / f"{package.name}.log").write_text(log, encoding="utf-8")
    shutil.rmtree(output, ignore_errors=True)
    return log, done.returncode


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

    SCRATCH.mkdir(parents=True, exist_ok=True)
    faults = 0
    for name in wanted:
        package = REPO_ROOT / name
        if not (package / "pubspec.yaml").is_file():
            print(f"{name} is not a package under {REPO_ROOT}", file=sys.stderr)
            return 2
        log, status = build(package)
        rendered, warnings, errors = faults_in(log)
        if status != 0 and warnings == 0 and errors == 0:
            # The build did not merely complain, it failed -- and said so
            # somewhere this parser does not read. Surface the log rather than
            # reporting a clean package.
            print(f"=== dart doc failed for {name} ===\n{log}",
                  file=sys.stderr)
            return 2
        if rendered:
            print(f"=== {name} ===")
            for entry in rendered:
                print(entry)
        print(f"{name:24} {warnings:3d} warning(s)  {errors:3d} error(s)")
        faults += warnings + errors

    print(f"\npackages built          : {', '.join(wanted)}\n"
          f"logs                    : "
          f"{SCRATCH.relative_to(REPO_ROOT)}/<package>.log")
    return report_faults(faults)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
