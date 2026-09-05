/// Runs the repository's documentation gates and holds each to its baseline.
///
/// `tom_ai/core/tool/` holds a checker per documentation invariant — that a
/// `[name]` in a dartdoc resolves, that a table of contents lists the sections
/// its document has, that a `Kind` column names something Dart declares, that
/// no table calls a shipped type unimplemented. How many there are is a number
/// `check_gates.py` prints; repeating it here would be one more unchecked copy
/// of a fact, which is the shape of fault these gates exist to catch. Until this file existed **nothing ran
/// any of them**. Searching the repository for their names found the README,
/// two changelogs and one Dart comment: no test, no hook, no CI step.
///
/// What followed was not a surprise. Five of the checkers were failing, and one
/// had drifted from zero dangling references to one — a dartdoc pointing at
/// `[_processResultSet]` where the method is named `_processResult` — which was
/// found only because somebody happened to run the checker by hand. An
/// invariant nobody re-checks is not an invariant; it is a comment that used to
/// be true.
///
/// **Why this lives in `tom_flutter_ui`.** It should not, strictly: the gates
/// span every package under `tom_ai/core`, and this package owns none of the
/// documents most of them read. But there is no repo-level Dart package to hang
/// it from, and creating one to host a single test buys a pubspec, a build-order
/// entry and a workspace-metadata row for no other purpose. This is the largest
/// always-run suite and it already hosts the repo's other documentation
/// invariants (`library_dartdoc_test.dart`, `kernel_types_doc_test.dart`), so it
/// is where a failure is seen soonest. Read a failure here as "the repository's
/// documentation moved", not "`tom_flutter_ui` is broken" — the gate name in the
/// failure says which document.
///
/// **What is asserted.** One test per gate, and each passes in exactly two
/// states: the gate is clean, or its fault count equals the number recorded in
/// `tool/gate_baselines.json`. A count above the baseline is a new fault. A
/// count *below* it is also a failure, asking for the baseline to be lowered —
/// without that, repaired ground reopens silently, which is the same decay one
/// step slower.
///
/// The gate list is discovered from the directory rather than written here, so
/// a checker added tomorrow is enforced tomorrow rather than whenever someone
/// remembers to register it.
///
/// Prose: `tool/check_gates.py`, which is also runnable on its own —
/// `python3 tool/check_gates.py` for the report, `--update` to re-record.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The repository root. Tests run with the package directory as the working
/// directory, and `tool/` sits one level above it.
final Directory _repoRoot = Directory('..');

/// Every gate the runner will run, taken from the same directory it globs.
///
/// Read here rather than from `gate_baselines.json` so that a gate missing
/// from the baselines still gets a test — and fails in it, reported as
/// `unbaselined`, instead of vanishing from the suite along with its entry.
List<String> _discoverGates() =>
    Directory('${_repoRoot.path}/tool')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.startsWith('check_') && n.endsWith('.py'))
        .where((n) => n != 'check_gates.py')
        .map((n) => n.substring(0, n.length - 3))
        .toList()
      ..sort();

/// The launchers that start Python 3, in the order they are tried.
///
/// `python3` everywhere except Windows, where the standard entry point is the
/// `py` launcher. Both are tried rather than branched on [Platform] so that a
/// machine with only one of them works without this file knowing which.
const _pythonLaunchers = <List<String>>[
  ['python3'],
  ['py', '-3'],
];

/// The gates that carry a `--self-test`, found by reading them.
///
/// Discovered rather than listed for the same reason the gate list is: a
/// checker that grows a self-test tomorrow should be exercised tomorrow. The
/// probe is the literal flag string in the source, which is what a checker
/// dispatches on. A gate that only names the flag in a comment is picked up
/// too and then runs its ordinary check instead — reported as a failure, which
/// is the safe way round.
List<String> _selfTestingGates() =>
    _discoverGates()
        .where(
          (n) => File(
            '${_repoRoot.path}/tool/$n.py',
          ).readAsStringSync().contains('--self-test'),
        )
        .toList();

/// Runs a Python script under `tool/` and returns its result.
///
/// Throws rather than skips when Python is absent. A skip would mean the gates
/// stop being enforced on precisely the machine where nobody notices, which is
/// the failure this file exists to end; and a repository whose documentation
/// verification *is* a folder of Python scripts already requires Python to work
/// on.
ProcessResult _runPython(List<String> arguments) {
  final failures = <String>[];
  for (final launcher in _pythonLaunchers) {
    try {
      return Process.runSync(launcher.first, [
        ...launcher.skip(1),
        ...arguments,
      ], workingDirectory: _repoRoot.path);
    } on ProcessException catch (e) {
      failures.add('${launcher.join(' ')}: ${e.message}');
    }
  }
  throw StateError(
    'no Python 3 launcher worked, so the documentation gates could not run. '
    'Install Python 3 — the checkers in tool/ are the repository\'s '
    'documentation verification and every one of them is a Python script.\n'
    '${failures.join('\n')}',
  );
}

/// Runs `tool/check_gates.py --json` and returns its parsed report.
Map<String, dynamic> _runGates() {
  final result = _runPython(['tool/check_gates.py', '--json']);
  // Exit 1 is "a gate failed", which is a result, not an error. Anything
  // else means the runner itself did not get to speak.
  if (result.exitCode > 1) {
    throw StateError(
      'tool/check_gates.py exited ${result.exitCode}\n'
      '${result.stdout}\n${result.stderr}',
    );
  }
  return jsonDecode(result.stdout as String) as Map<String, dynamic>;
}

void main() {
  final gates = _discoverGates();
  late final Map<String, dynamic> report;
  late final Map<String, Map<String, dynamic>> byName;

  setUpAll(() {
    report = _runGates();
    byName = {
      for (final gate in (report['gates'] as List).cast<Map<String, dynamic>>())
        gate['name'] as String: gate,
    };
  });

  // The gates walk every Dart file and every document in the repository.
  // Together they take about fifteen seconds — once, in setUpAll,
  // whose cost the test that triggers it is charged for. So every test here
  // carries the longer timeout rather than the group, which in `flutter_test`
  // cannot take one.
  const slow = Timeout(Duration(minutes: 5));

  group('the tom_ai/core documentation gates', () {
    test('there are gates to run', timeout: slow, () {
      expect(
        gates,
        isNotEmpty,
        reason:
            'no check_*.py was found in tool/. Either the folder moved or '
            'this test is looking in the wrong place; an empty gate list must '
            'not read as "everything passes".',
      );
    });

    for (final gate in gates) {
      test(gate, timeout: slow, () {
        final result = byName[gate];
        expect(
          result,
          isNotNull,
          reason:
              '$gate is a checker in tool/ that check_gates.py did not '
              'report on. It discovers gates by the same glob this test does, '
              'so the two disagreeing means one of them is wrong.',
        );
        expect(
          result!['status'],
          anyOf('clean', 'at-baseline'),
          reason: result['message'] as String? ?? 'unexplained failure',
        );
      });
    }

    test('every baseline names a gate that still exists', timeout: slow, () {
      expect(
        report['problems'],
        isEmpty,
        reason: (report['problems'] as List).join('\n'),
      );
    });
  });

  // Every test above passes when a checker reports no faults — including a
  // checker that has quietly stopped reading anything. That is not a
  // hypothetical: eleven wrong figures once stood across six completion
  // documents while `check_doc_inventories` held at its baseline both before
  // and after they were corrected, because it read neither the census
  // sentences nor the per-file lengths those figures lived in. A gate's
  // `--self-test` asks the question the baseline cannot: perturb a figure the
  // gate calls correct, and require it to object.
  group('the gates still detect what they claim to read', () {
    final selfTesting = _selfTestingGates();

    test('there are self-tests to run', timeout: slow, () {
      expect(
        selfTesting,
        isNotEmpty,
        reason:
            'no checker in tool/ implements --self-test. At least one did; '
            'losing the last one means nothing now distinguishes a gate that '
            'passes because the documents are right from one that passes '
            'because it stopped looking.',
      );
    });

    for (final gate in selfTesting) {
      test(gate, timeout: slow, () {
        final result = _runPython(['tool/$gate.py', '--self-test']);
        expect(
          result.exitCode,
          0,
          reason:
              '$gate --self-test failed: a claim it is supposed to measure '
              'survived being perturbed, so that claim is no longer gated.\n'
              '${result.stdout}\n${result.stderr}',
        );
      });
    }
  });
}
