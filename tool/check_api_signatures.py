#!/usr/bin/env python3
"""Hold every signature an API summary quotes to the analyzer's element model.

Run from anywhere::

    python3 tool/check_api_signatures.py               # the gated summaries
    python3 tool/check_api_signatures.py --self-test   # check the checker

Exits non-zero when a quoted signature disagrees with the code.

**Why it exists.** The API summaries (``doc/api/api_summary_*.md``)
are what a reader consults *instead of* the source, so a stale signature there
misleads more directly than anywhere else -- and nothing read them.
``check_doc_dart_blocks.py`` skips the directory on purpose: its fences quote
declarations without bodies, and a declaration that parses still says nothing
about whether it is true. A renamed parameter, a positional argument that
became named, a type that changed: each parses perfectly. The first run over
the six packages with summaries found 27 such faults -- five exceptions quoting
``bool? serverCallError`` for a parameter typed ``TomServerCallError?``, three
quoting ``autoLog = true`` for a default of ``false``, a constructor quoted with
a parameter list it no longer has, a ``progress`` typed ``Widget?`` that is a
``double?``, a missing ``const``, a constructor of a type the package does not
export -- and one whole summary, ``tom_core_codespecs``'s, whose 21 constructor
fences had been cut off before their closing ``})``.

**How.** ``tool/api_signatures/`` is a small Dart program on
``package:analyzer``. It resolves the package's barrel, parses each fence as
members of the type it documents -- the class its constructor names, else the
nearest heading that names an exported type -- and compares every member with
the element: that it exists, ``const`` / ``factory`` / ``static``, its return
type, and each parameter's kind, type and default. Positional parameters are
matched by position, since no caller writes their names; named ones by name.
A fence that quotes a bare class header (``abstract interface class X``) is
held to the class's modifiers; one that quotes top-level functions, getters or
a ``typedef`` is held to those exports.

A fence must parse as declarations. The one parse error tolerated is the one a
quoted signature always has, a missing body; anything else -- a truncated
parameter list, a type parameter on a constructor -- is a fault, unless the
fence parses as statements, which makes it a usage sample.

Types are compared structurally, not as text, so the spellings a declaration
uses and the analyzer expands are the same type: a typedef with its arguments
(``ValueChanged<String>``), a raw generic for its instantiation to bounds, a
function type with parameter names, a record with its named fields in any
order. A default the declaration names bare (``defaultLimit``) may be quoted as
``Owner.defaultLimit``, the only way a reader outside the class can write it; a
private default cannot be quoted and is not compared. A fence with a body or
a statement is a usage sample, not a signature, and is counted and left to
``check_doc_dart_blocks.py``.

**What it does not read.** The ``Methods`` and ``Properties`` *tables* quote
signatures too, as inline code in a cell; this reads fences only. The package
conformance suites (``test/api_reference_coverage_test.dart``) hold the
summaries' *inventory* -- which types and members appear -- which is the other
half of the same promise.

**Scope.** Every package under ``tom_ai/core`` with API summaries. The two
harnesses and the samples have none.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

from gate_report import report_faults

TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parent
PROGRAM = TOOL_DIR / "api_signatures"
SCRATCH = TOOL_DIR / "ztmp" / "api_signatures"

#: (package, its API summary folder) -- every one triaged to zero. The folder's
#: name differs by package; the content is the same kind of document.
PACKAGES = [
    ("tom_core_kernel", "doc/api"),
    ("tom_core_server", "doc/api"),
    ("tom_core_flutter", "doc/api"),
    ("tom_core_agentic", "doc/api"),
    ("tom_core_codespecs", "doc/api"),
    ("tom_core_openapi", "doc/api"),
    ("tom_core_secrets_vault", "doc/api"),
    ("tom_core_secrets_aws", "doc/api"),
    ("tom_core_secrets_azure", "doc/api"),
    ("tom_flutter_ui", "doc/api"),
]


def dart(*args: str, cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(["dart", *args], cwd=cwd, capture_output=True,
                          text=True)


def prepare() -> None:
    """Resolve the checker's own dependencies, offline when the cache allows."""
    if dart("pub", "get", "--offline", cwd=PROGRAM).returncode == 0:
        return
    done = dart("pub", "get", cwd=PROGRAM)
    if done.returncode != 0:
        raise SystemExit("could not resolve tool/api_signatures:\n"
                         + done.stdout + done.stderr)


def run(package: str, docs: Path) -> tuple[list[str], dict]:
    """The faults and the tally for one package's summaries."""
    done = dart("run", "bin/check_api_signatures.dart",
                str(REPO_ROOT / package), str(docs), cwd=PROGRAM)
    lines = [line for line in done.stdout.splitlines() if line.strip()]
    if done.returncode != 0 or not lines:
        raise SystemExit(f"the checker failed on {package}:\n"
                         + done.stdout + done.stderr)
    return lines[:-1], json.loads(lines[-1])


def self_test() -> int:
    """Each kind of claim, damaged once, must be reported -- and nothing else.

    The summaries are copied to the scratch folder, a mutated copy is added per
    case, and one run reads them all. A clean copy reporting anything, or a
    mutation reporting nothing, fails the test.
    """
    package, folder = PACKAGES[0]
    source = REPO_ROOT / package / folder
    shutil.rmtree(SCRATCH, ignore_errors=True)
    shutil.copytree(source, SCRATCH)
    beans = (source / "api_summary_beanlocator.md").read_text(encoding="utf-8")
    http = (source / "api_summary_http_connection.md").read_text(encoding="utf-8")
    cases = {
        "parameter_type": (beans, "  String key,\n", "  int key,\n",
                           "is `String`, quoted as `int`"),
        "named_parameter": (beans, "  bool autoLog = false,\n",
                            "  bool autoLogging = false,\n",
                            "no named parameter `autoLogging`"),
        "const": (beans, "const TomComponent(Type type)",
                  "TomComponent(Type type)", "is const, quoted without it"),
        "modifiers": (http, "abstract interface class TomHttpClientAbstractFactory",
                      "abstract class TomHttpClientAbstractFactory",
                      "quoted as `abstract class`"),
    }
    for name, (text, old, new, _) in cases.items():
        if old not in text:
            print(f"self-test: the `{name}` case's anchor is gone from the "
                  f"summaries; pick another", file=sys.stderr)
            return 2
        (SCRATCH / f"zz_mutated_{name}.md").write_text(
            text.replace(old, new, 1), encoding="utf-8")

    faults, _ = run(package, SCRATCH)
    failed = False
    stray = [f for f in faults if "zz_mutated_" not in f]
    if stray:
        print("self-test: the unmutated copies report faults:\n  "
              + "\n  ".join(stray), file=sys.stderr)
        failed = True
    for name, (*_, expected) in cases.items():
        mine = [f for f in faults if f"zz_mutated_{name}.md" in f]
        if not any(expected in f for f in mine):
            print(f"self-test: `{name}`: expected a fault saying "
                  f"`{expected}`, got {mine or 'none'}", file=sys.stderr)
            failed = True
    shutil.rmtree(SCRATCH, ignore_errors=True)
    if failed:
        return 1
    print(f"self-test: {len(cases)} kinds of signature damage reported, "
          "and nothing in the unmutated summaries")
    return 0


def main(argv: list[str]) -> int:
    if shutil.which("dart") is None:
        print("dart is not on PATH, so no signature can be resolved",
              file=sys.stderr)
        return 2
    prepare()
    if "--self-test" in argv[1:]:
        return self_test()

    total: list[str] = []
    members = fences = programs = 0
    for package, folder in PACKAGES:
        faults, tally = run(package, REPO_ROOT / package / folder)
        total.extend(f"{package}/{fault}" for fault in faults)
        members += tally["members"]
        fences += tally["fences"]
        programs += tally["programs"]
    # A run that compared nothing would report a clean tree: refuse it.
    if members == 0:
        print("no quoted signature was compared", file=sys.stderr)
        return 2

    for fault in total:
        print(fault)
    print(f"\nfences read             : {fences}\n"
          f"usage samples (skipped) : {programs}\n"
          f"members compared        : {members}\n"
          f"signatures that disagree: {len(total)}")
    return report_faults(len(total))


if __name__ == "__main__":
    sys.exit(main(sys.argv))
