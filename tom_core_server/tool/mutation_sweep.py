#!/usr/bin/env python3
"""Break a behaviour on purpose and see whether the suite notices.

A green test that *names* a behaviour is not the same as one that *pins* it,
and reading the test cannot tell the two apart -- the assertion may be about
something the mutation does not touch, or about a value the code would produce
either way. The only way to know is to break the behaviour in `lib/` and watch.
A mutation the suite still passes is an untested behaviour, whatever the test
names say.

The catalogue is `tool/mutations.yaml`, and it is the point of committing this:
it records which behaviours have been asked the question and which tests are
expected to answer. A module absent from the catalogue has not been swept.

    python3 tool/mutation_sweep.py                 # every module
    python3 tool/mutation_sweep.py cache endpoints # named modules
    python3 tool/mutation_sweep.py --list          # what would run

Each entry names the smallest edit that removes one promise -- a fallback
deleted, a precedence reversed, a guard inverted -- and the test files that
should fail because of it. The tests are named per entry rather than run whole:
a full suite is minutes and a module's own files are seconds, and 200 mutations
only fit in a session at the second speed.

The suite is run once unmutated first. A red suite calls every mutation killed,
and a test file that stopped compiling is red in exactly the way that looks like
success -- which happened while this catalogue was being written and reported
six of six killed on a suite that never ran.

A mutant that does not compile is reported as INVALID rather than killed: it
turns every test red without asking anything of them.

Exit code is the number of surviving plus invalid mutations, so a zero exit
means every recorded behaviour is pinned.
"""

import argparse
import os
import re
import signal
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOGUE = ROOT / 'tool' / 'mutations.yaml'


def load_catalogue():
    """The catalogue, as `{module: [entry, ...]}`.

    Hand-parsed rather than via PyYAML, which is not a dependency of this
    package and would make the sweep unrunnable on a machine that has the Dart
    toolchain and nothing else. The grammar is three keys and a list, so the
    cost of parsing it here is smaller than the cost of the dependency.
    """
    modules, module, entry = {}, None, None
    for raw in CATALOGUE.read_text().split('\n'):
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        if not line.startswith(' ') and line.endswith(':'):
            module = line[:-1]
            modules[module] = []
            continue
        stripped = line.strip()
        if stripped.startswith('- '):
            entry = {}
            modules[module].append(entry)
            stripped = stripped[2:]
        key, _, value = stripped.partition(': ')
        value = value.strip()
        if value.startswith('"') and value.endswith('"'):
            value = value[1:-1].encode().decode('unicode_escape')
        if key == 'tests':
            value = value.split()
        entry[key] = value
    return modules


def run_tests(tests):
    """Whether `dart test` passes over [tests]."""
    return _run(tests).returncode == 0


#: The longest one run of an entry's tests may take before it is stopped.
#:
#: A mutation can make the suite hang rather than fail: remove the release of a
#: shared connection and every later statement waits for it forever. Unbounded,
#: that stalls the whole sweep on one entry. Bounded, it is what it is -- the
#: suite noticed the mutation -- and it is reported as killed, with the reason.
RUN_TIMEOUT_SECONDS = 600


def _run(tests):
    """`dart test` over [tests], stopped after [RUN_TIMEOUT_SECONDS].

    Run in its own process group so a timeout can stop the test VMs `dart
    test` spawns, not only `dart` itself: killing the parent alone leaves the
    hung isolate holding its database connection. A timed-out run answers
    returncode `None` and says so in its output.
    """
    process = subprocess.Popen(
        ['dart', 'test', '-j', '1', *tests],
        cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        start_new_session=True,
    )
    try:
        stdout, stderr = process.communicate(timeout=RUN_TIMEOUT_SECONDS)
        return subprocess.CompletedProcess(process.args, process.returncode, stdout, stderr)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        stdout, stderr = process.communicate()
        return subprocess.CompletedProcess(
            process.args, None, stdout,
            (stderr or '') + f'\n[timed out after {RUN_TIMEOUT_SECONDS}s]')


#: How a test file that no longer compiles reports itself.
_LOAD_FAILURE = re.compile(r'loading \S+ \[E\]\n\s+\S+\.dart:\d+:\d+: Error:')


def does_not_compile(output):
    """Whether a red run is red because the mutant is not valid Dart.

    A mutant that does not compile fails every test that imports it, which is
    red in exactly the way a kill is -- and says nothing about the suite. An
    `if (false)` that loses a type promotion is the usual cause, and it was
    catalogued once as killed before this check existed.
    """
    return _LOAD_FAILURE.search(output) is not None


def database_reachable():
    """Whether the MariaDB the `db`-tagged suites need is listening.

    Those suites self-skip when it is not, and a skipped suite passes -- so a
    mutation whose only coverage is a `db` test would be reported as surviving
    on every machine that has no database. That is a false alarm about the one
    thing this tool exists to report truthfully, so such entries are marked
    `requires: db` in the catalogue and skipped outright when the port is shut.
    """
    import socket
    try:
        with socket.create_connection(('127.0.0.1', 3309), timeout=1):
            return True
    except OSError:
        return False


def sweep(entry):
    """Apply one mutation, run its tests, restore the file whatever happens.

    Returns `(verdict, seconds)`, the verdict one of `killed`, `survived`,
    `invalid` -- a mutant that does not compile, which proves nothing -- or
    `hung`, a run stopped at [RUN_TIMEOUT_SECONDS], which counts as killed. Restoring in a `finally` is not politeness:
    an interrupted sweep that leaves a mutation in `lib/` is a library defect
    introduced by the tool meant to find them.
    """
    path = ROOT / entry['file']
    original = path.read_text()
    if entry['find'] not in original:
        raise SystemExit(f"{entry['file']}: `find` matches nothing:\n  {entry['find']}")
    if original.count(entry['find']) != 1:
        raise SystemExit(
            f"{entry['file']}: `find` matches "
            f"{original.count(entry['find'])} times, not once:\n  {entry['find']}")
    started = time.time()
    try:
        path.write_text(original.replace(entry['find'], entry['replace'], 1))
        result = _run(entry['tests'])
    finally:
        path.write_text(original)
    if result.returncode is None:
        verdict = 'hung'
    elif result.returncode == 0:
        verdict = 'survived'
    elif does_not_compile(result.stdout + result.stderr):
        verdict = 'invalid'
    else:
        verdict = 'killed'
    return verdict, time.time() - started


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('modules', nargs='*', help='modules to sweep; default all')
    parser.add_argument('--list', action='store_true', help='print entries, run nothing')
    args = parser.parse_args()

    catalogue = load_catalogue()
    selected = args.modules or sorted(catalogue)
    unknown = [m for m in selected if m not in catalogue]
    if unknown:
        raise SystemExit(f"not in the catalogue: {', '.join(unknown)}")

    # Green before anything is broken. A red suite reports every mutation as
    # killed, and a test file that no longer compiles is red in exactly the way
    # that looks like success -- which happened while this catalogue was being
    # written, and reported six of six killed on a suite that never ran.
    # Every `find` checked before anything runs, and every drifted one named.
    # Code moves under a catalogue; discovering the drift one entry per
    # half-hour run is how a sweep stops being run.
    drifted = []
    for module in selected:
        for entry in catalogue[module]:
            count = (ROOT / entry['file']).read_text().count(entry['find'])
            if count != 1:
                drifted.append(f"  {module}: {entry['behaviour']}\n"
                               f"    {entry['file']}: `find` matches {count} times")
    if drifted:
        raise SystemExit('catalogue entries no longer match their file:\n'
                         + '\n'.join(drifted))

    has_database = None if args.list else database_reachable()
    if has_database is False:
        print('no database on 127.0.0.1:3309 — `requires: db` entries are skipped')

    def runnable(entry):
        return entry.get('requires') != 'db' or has_database

    if not args.list:
        baseline = sorted({
            t for m in selected for e in catalogue[m] if runnable(e) for t in e['tests']
        })
        print(f'baseline: {len(baseline)} test file(s)')
        result = _run(baseline)
        if result.returncode != 0:
            failing = sorted({line.strip() for line in result.stdout.splitlines()
                              if line.rstrip().endswith('[E]')})
            raise SystemExit(
                'the suite is red before any mutation, so nothing can be '
                'concluded from it. Failing:\n  ' + '\n  '.join(failing)
                + '\nFix it first:\n  dart test -j 1 ' + ' '.join(baseline))

    survivors = []
    invalid = []
    total = 0
    for module in selected:
        entries = catalogue[module]
        print(f'{module} ({len(entries)})')
        for entry in entries:
            if args.list:
                print(f'    {entry["behaviour"]}')
                continue
            if not runnable(entry):
                print(f'    skipped        needs a database: {entry["behaviour"]}')
                continue
            total += 1
            verdict, seconds = sweep(entry)
            # A hang is the suite noticing, so it counts as a kill.
            mark = {'survived': 'SURVIVED', 'invalid': 'INVALID ',
                    'killed': 'killed  ', 'hung': 'killed (hung)'}[verdict]
            print(f'    {mark} {seconds:5.1f}s  {entry["behaviour"]}')
            if verdict == 'survived':
                survivors.append((module, entry))
            elif verdict == 'invalid':
                invalid.append((module, entry))

    if args.list:
        return 0

    print()
    print(f'{total} mutation(s), {len(survivors)} survived, '
          f'{len(invalid)} did not compile')
    for label, found in (('survived', survivors), ('does not compile', invalid)):
        for module, entry in found:
            print(f'  {label} -- {module}: {entry["behaviour"]}')
            print(f'    {entry["file"]}  ->  {entry["replace"]!r}')
    # An invalid mutant asks nothing, so it fails the run like a survivor: the
    # catalogue entry has to be rewritten before its behaviour counts as pinned.
    return len(survivors) + len(invalid)


if __name__ == '__main__':
    sys.exit(main())
