/// Tests that hold for *every* example in the package rather than for one.
///
/// The per-module suites each run their own example and assert its transcript —
/// the step numbers, the values it prints — because that is module knowledge
/// and belongs beside the module. What is left over is the part no module can
/// check about itself: that no example anywhere states an expectation in a form
/// that does not run, and that every example is run by *something*. Those are
/// properties of the set, so they live here.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../example/_support/check.dart';

/// Examples whose own module suite already spawns them, and where.
///
/// These carry transcript assertions that only the module can make, so they are
/// run there rather than here — running them twice would add a minute and a
/// half to the suite to learn nothing. Listing them is what lets this file spawn
/// the rest without either double-spawning or guessing: this list, the stated
/// exclusions and the swept remainder are checked against the directory below,
/// so an example belonging to none of the three is a failure rather than an
/// omission.
const _spawnedByModuleTest = <String, String>{
  'example/cache/cache_example.dart': 'test/cache_test.dart',
  'example/cmdline/cmdline_example.dart': 'test/cmdline_test.dart',
  'example/configuration/configuration_example.dart':
      'test/configuration_test.dart',
  'example/datasources/datasources_example.dart': 'test/datasources_test.dart',
  'example/db_migration/db_migration_example.dart':
      'test/db_migration_test.dart',
  'example/export/export_example.dart': 'test/export_test.dart',
  'example/messaging/messaging_example.dart': 'test/messaging_test.dart',
  'example/messaging/messaging_templated_example.dart':
      'test/messaging_test.dart',
  'example/messaging/sms_gateway_presets.dart': 'test/messaging_test.dart',
  'example/transactions/transactions_example.dart':
      'test/transactions_test.dart',
};

/// Example programs this suite deliberately does not spawn, and why.
///
/// Stating them here with a reason is the point — a silently unrun example is
/// the defect this file exists to prevent, one level up. A reason is what
/// separates "we decided not to" from "we forgot".
const _notSpawnedHere = <String, String>{
  // The scheduling cluster demo: one node program run twice plus its two
  // operator scripts, all expecting a live MariaDB and started as a group by
  // `run_cluster_demo.sh` rather than individually.
  'example/scheduling/cluster/cluster_node.dart':
      'a cluster member: waits for peers and a shared database',
  'example/scheduling/cluster/cluster_provision.dart':
      'provisions the cluster schema in a live MariaDB',
  'example/scheduling/cluster/cluster_verify.dart':
      'reads the run table a live cluster produced',
  // Not an example at all in the sense the rest of this file means: it is the
  // reflection generator's root, and its `main` is empty by contract because
  // the generator requires a root to declare one. Spawning it costs eight
  // seconds to observe that an empty function returns.
  'example/example_reflection.dart':
      'a generator root: its `main` is empty by contract and checks nothing',
};

/// How many numbered steps each example's transcript prints.
///
/// A `check` that throws catches an expectation that is *violated*. It says
/// nothing about a step **removed** — the run stays green with one fewer
/// demonstration — or a step **added** without anyone deciding it belonged,
/// which is a surface nothing checks. Recording the count is what makes both
/// visible, and the two module suites that already do it
/// (`datasources_test.dart`, `db_migration_test.dart`) are the shape this
/// generalises, one manifest instead of one block per module.
///
/// The unit is the **step number**, not the printed line: a step may report
/// several cases under one number, and several do. `export`'s step 2 prints a
/// line per renderer and `messaging`'s step 8 one per delivery outcome, which
/// reads exactly as intended and would fail a rule counting lines.
///
/// `0` means the program's transcript is not numbered — the four authentication
/// programs narrate a flow in prose instead, and the package example is a tour.
/// Recorded rather than omitted, so a transcript that *starts* being numbered
/// has to be registered here rather than arriving unmeasured.
const _stepCounts = <String, int>{
  'example/audit/audit_example.dart': 11,
  'example/authentication/authentication_example.dart': 0,
  'example/authentication/oauth_login_example.dart': 0,
  'example/authentication/two_factor_enrolment_example.dart': 0,
  'example/authentication/two_factor_login_example.dart': 0,
  'example/authorization/authorization_example.dart': 6,
  'example/authorization/resource_data_scope_example.dart': 10,
  'example/cache/cache_example.dart': 10,
  'example/cmdline/cmdline_example.dart': 9,
  'example/configuration/configuration_example.dart': 12,
  'example/datasources/datasources_example.dart': 10,
  'example/db_migration/db_migration_example.dart': 10,
  'example/endpoints/endpoints_example.dart': 11,
  'example/export/export_email.dart': 6,
  'example/export/export_retention.dart': 7,
  'example/export/export_example.dart': 14,
  'example/file_storage/file_storage_example.dart': 12,
  'example/healthcheck/healthcheck_example.dart': 6,
  'example/little_things/little_things_example.dart': 6,
  'example/messaging/messaging_example.dart': 12,
  'example/messaging/messaging_templated_example.dart': 12,
  'example/messaging/sms_gateway_presets.dart': 7,
  'example/object_persistence/object_persistence_example.dart': 17,
  'example/preferences/preferences_example.dart': 13,
  'example/resources/resources_example.dart': 10,
  'example/scheduling/scheduling_example.dart': 10,
  'example/server/server_example.dart': 6,
  'example/tom_core_server_example.dart': 0,
  'example/transactions/transactions_example.dart': 7,
};

/// The distinct step numbers [transcript] prints, in the order they first
/// appear.
///
/// Distinct, because a step reporting several cases prints its number once per
/// case; ordered, because a transcript whose steps arrive out of order is a
/// program that no longer does what its numbering says.
List<int> _stepsIn(String transcript) {
  final steps = <int>[];
  for (final match in RegExp(
    r'^(\d+)\. ',
    multiLine: true,
  ).allMatches(transcript)) {
    final step = int.parse(match.group(1)!);
    if (steps.isEmpty || steps.last != step) steps.add(step);
  }
  return steps;
}

/// Every hand-written `.dart` file under `example/`, package-relative and
/// slash-separated.
///
/// The unit is the **file**, not the module: `example/authentication/` ships
/// four programs, each with its own header documenting its own `dart run`
/// command, so each answers for its own expectations. A rule stated per module
/// would let three of them slip as long as one was clean.
///
/// Generated reflection output is excluded. It is not something a reader runs,
/// and the one shipped root is 80k machine-written lines that would dominate
/// any scan of this directory.
List<String> _exampleSources() {
  final root = Directory('example');
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => p.split(f.path).join('/'))
      .where((f) => f.endsWith('.dart') && !f.endsWith('.reflection.dart'))
      .toList()
    ..sort();
}

/// The handlers in [source] that would catch a failing [check], quoted as they
/// are written.
///
/// `check` reports by throwing a `StateError`, so a check made inside a `try`
/// whose handler catches one is the original defect in a new spelling: the
/// expectation is stated, the call site is intact, the ban on `assert` is
/// satisfied, and the run is green whether or not the expectation holds.
///
/// A bare `catch` takes everything, and `on Object` / `on Error` / `on
/// StateError` name it. `on Exception` and every named exception type do not —
/// a `StateError` is an `Error` — and neither does `finally`, which reraises.
/// That distinction is the reason this looks at the handler rather than
/// forbidding a `check` inside a `try` outright: five examples make one, all
/// five legitimately, four under `finally` and one under a typed handler.
///
/// Blocks are delimited by the **indentation** of the `try`, which `dart
/// format` guarantees and which — unlike counting braces — cannot be fooled by
/// a brace inside a string or a comment.
List<String> _swallowingHandlers(String source) {
  final lines = source.split('\n');
  final swallowing = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final opened = RegExp(r'^(\s*)try \{\s*$').firstMatch(lines[i]);
    if (opened == null) continue;
    final closes = RegExp('^${opened.group(1)!}\\}');

    var end = i + 1;
    while (end < lines.length && !closes.hasMatch(lines[end])) {
      end++;
    }
    if (end == lines.length) continue;
    if (!lines.getRange(i + 1, end).join('\n').contains('check(')) continue;

    // A `try` may carry several handlers, each opening at the `try`'s own
    // indentation, so reading only the first would miss `} on Foo catch (e) {
    // … } catch (_) {`, where the dangerous one is second.
    for (var j = end; j < lines.length;) {
      final handler = lines[j].trim();
      if (handler == '}') break;
      if (RegExp(r'^\}\s*catch\s*\(').hasMatch(handler) ||
          RegExp(r'^\}\s*on\s+(Object|Error|StateError)\b').hasMatch(handler)) {
        swallowing.add(handler);
      }
      // An empty handler body is written `{}` and closes on its own line, so
      // the statement ends here and there is no terminating `}` to look for.
      // Without this the scan runs on to the *next* `try` at the same
      // indentation and reports its handler against this one.
      if (handler.endsWith('{}')) break;
      for (j++; j < lines.length && !closes.hasMatch(lines[j]); j++) {}
    }
  }
  return swallowing;
}

/// The subset of [_exampleSources] that declares a `main`, i.e. is runnable.
List<String> _examplePrograms() => _exampleSources()
    .where(
      (f) => RegExp(
        r'^(void|Future<void>|Future)\s+main\s*\(',
        multiLine: true,
      ).hasMatch(File(f).readAsStringSync()),
    )
    .toList();

void main() {
  group('The shared example check', () {
    // The two source-level tests below are both satisfied by a `check` that
    // prints instead of throwing — the same defect as the asserts, wearing a
    // spelling the ban cannot see: every call site intact, every expectation
    // stated, and the run green whether or not any of them hold. So the
    // helper's *behaviour* is pinned, not just its name, and pinned once for
    // the twenty-three examples that now share it.
    test('throws when an expectation does not hold', () {
      expect(
        () => check(false, 'a violated expectation'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('a violated expectation'),
          ),
        ),
      );
    });

    test('returns quietly when it does', () {
      expect(() => check(true, 'a held expectation'), returnsNormally);
    });
  });

  group('A violated expectation fails the run', () {
    // The two tests above call `check` in this isolate, which proves it throws
    // and nothing more. What an example needs is a step further out: that a
    // throw raised at a check site, in a `Future<void> main()`, spawned the way
    // the header documents, reaches the *exit code*. Every intervening layer
    // could swallow it — an unawaited future, a handler that catches too
    // broadly — and none of that is visible from inside the isolate.
    //
    // Every real example passes, so none of them can answer this: a green
    // example looks identical whether its checks are load-bearing or inert,
    // which is exactly how the asserts survived. Only a program that fails on
    // purpose settles it, so `test/fixtures/` holds the pair.
    Future<ProcessResult> run(String fixture, {bool enableAsserts = false}) =>
        Process.run(Platform.resolvedExecutable, [
          'run',
          if (enableAsserts) '--enable-asserts',
          'test/fixtures/$fixture',
        ]);

    test('a failing check exits non-zero and stops the run', () async {
      final result = await run('example_check_violation.dart');

      expect(result.exitCode, isNot(0));
      expect(
        result.stderr,
        contains('the fixture violates this expectation deliberately'),
        reason:
            'the expectation that failed is the whole message a reader gets',
      );
      // Non-zero alone would also be satisfied by a run that printed every
      // later step and then failed on the way out, which is not what an
      // expectation means: the step after the violation must not happen.
      expect(result.stdout, contains('1. before the violated expectation'));
      expect(result.stdout, isNot(contains('2. after the violated')));
    });

    test('the same expectation as an assert exits 0 under `dart run`', () async {
      // The control, and the evidence for the reason `check` exists. Without
      // it the helper's explanation is prose, and a helper whose justification
      // nothing verifies is one a later reader may reasonably undo.
      final result = await run('example_assert_violation.dart');

      expect(
        result.exitCode,
        0,
        reason: '`dart run` leaves assertions disabled',
      );
      expect(
        result.stdout,
        contains('2. after the violated expectation'),
        reason: 'the run continues past an assertion that does not hold',
      );
    });

    test('and does fail once assertions are switched on', () async {
      // Which pins the difference to the flag rather than to anything else
      // about the fixture — otherwise "exits 0" would be equally well explained
      // by a fixture whose assertion is accidentally true.
      final result = await run(
        'example_assert_violation.dart',
        enableAsserts: true,
      );

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('Failed assertion'));
    });
  });

  group('No example states an expectation that does not run', () {
    test('none of them uses assert', () {
      // `dart run` leaves assertions disabled — that is what `--enable-asserts`
      // is for — so an `assert` in an example is compiled out under the very
      // command the example's header documents. The run then prints a
      // plausible transcript and exits 0 with every expectation in it
      // unchecked, which reads as a verification to everyone including the
      // author. The defect is invisible from the outside — a green run looks
      // identical either way — so nothing but a source check finds it.
      //
      // This scans every example rather than each module scanning its own,
      // because the files that most need scanning are the ones nobody thought
      // to write a test for.
      final offenders = <String>[
        for (final source in _exampleSources())
          if (File(source).readAsStringSync().contains('assert(')) source,
      ];
      expect(
        offenders,
        isEmpty,
        reason: 'an assert in an example does not run under `dart run`',
      );
    });

    test('none of them declares a check of its own', () {
      // A local copy of the helper would bring with it a copy of the paragraph
      // explaining why it is not an `assert` — and a duplicated *reason* is the
      // shape most certain to drift, since a reader who improves the reasoning
      // in one copy has no way of knowing the others exist. A local copy would
      // also escape the behaviour tests above, which pin the shared helper.
      final offenders = <String>[
        for (final source in _exampleSources())
          if (source != 'example/_support/check.dart' &&
              File(source).readAsStringSync().contains('void check(bool ok'))
            source,
      ];
      expect(
        offenders,
        isEmpty,
        reason: 'examples share example/_support/check.dart',
      );
    });

    test('none of them makes a check a handler would catch', () {
      // `check` throws, so a check inside a `try` that catches broadly states
      // its expectation and discards the answer — the same silence as an
      // `assert`, in a spelling the ban above cannot see. Three examples
      // already write the safe shape without being told to: they capture the
      // throw into a local and check it *after* the block.
      final offenders = <String>[
        for (final source in _exampleSources())
          for (final handler in _swallowingHandlers(
            File(source).readAsStringSync(),
          ))
            '$source: $handler',
      ];
      expect(
        offenders,
        isEmpty,
        reason: 'a check made here cannot fail the run',
      );
    });

    test('and the handler scan tells the two shapes apart', () {
      // Both scans it feeds are satisfied by a scanner that finds nothing, and
      // this one has to draw a line rather than reject a keyword: four of the
      // five checks made inside a `try` today are legitimate. So it is shown
      // one of each.
      const source = '''
void main() {
  try {
    check(true, 'reraised by finally');
  } finally {
    cleanUp();
  }
  try {
    check(true, 'a StateError is not an Exception');
  } on TomServerException catch (e) {
    print(e);
  }
  try {
    check(true, 'swallowed');
  } catch (_) {}
  try {
    check(true, 'swallowed by the second handler');
  } on TomServerException catch (e) {
    print(e);
  } catch (_) {}
  try {
    somethingElse();
  } catch (_) {}
}
''';

      expect(_swallowingHandlers(source), ['} catch (_) {}', '} catch (_) {}']);
    });

    test('and the sweep is reading what it claims to', () {
      // Both scans above are satisfied vacuously by a listing that finds
      // nothing: no file, no offender, green. So the listing proves it ran.
      //
      // Stated as a superset and a shape rather than a count, because the
      // count is supposed to move — every new example adds one — and a test
      // that must be edited whenever the thing it measures grows correctly is
      // a test that will be edited without being read.
      final swept = _exampleSources();
      expect(
        swept,
        containsAll([
          ..._spawnedByModuleTest.keys,
          ..._notSpawnedHere.keys,
          'example/_support/check.dart',
        ]),
        reason: 'the scans above cannot see a file the listing never reached',
      );
      expect(
        swept.where((f) => f.endsWith('.reflection.dart')),
        isEmpty,
        reason: 'generated output is not something a reader runs',
      );
    });
  });

  group('Every example program is accounted for', () {
    test('by a module test, by this file, or by a stated exclusion', () {
      // The guarantee this file exists to give. An example added later belongs
      // to none of the three lists, so it fails here rather than sitting unrun
      // — which is exactly how the asserts survived: nothing spawned an
      // example, so nothing could notice that its checks had stopped running.
      final unaccounted = _examplePrograms()
          .where(
            (f) =>
                !_spawnedByModuleTest.containsKey(f) &&
                !_notSpawnedHere.containsKey(f),
          )
          .toList();
      // Everything not claimed by a module test or excluded is spawned below,
      // so this asserts the lists describe the directory rather than a
      // remembered version of it.
      expect(
        [...unaccounted, ..._spawnedByModuleTest.keys, ..._notSpawnedHere.keys]
          ..sort(),
        _examplePrograms(),
      );
    });

    for (final entry in _spawnedByModuleTest.entries) {
      test('${entry.key} is spawned by ${entry.value}', () {
        // The claim the partition rests on. Without it, moving an example's
        // group out of its module suite would leave the name here pointing at
        // a test that no longer runs it, and this file would skip it in the
        // belief that somebody else did not.
        expect(File(entry.value).existsSync(), isTrue);
        expect(
          File(entry.value).readAsStringSync(),
          contains(p.basename(entry.key)),
          reason: '${entry.value} no longer names this example',
        );
      });
    }
  });

  group('Every example transcript prints the steps it is recorded as having', () {
    test('the manifest describes the directory, not a remembered version', () {
      // Both directions, as everywhere else in this file: an example added
      // later has no entry and fails here rather than running unmeasured, and
      // an entry left behind after a deletion fails rather than describing a
      // file that is gone.
      expect(
        _stepCounts.keys.toList()..sort(),
        _examplePrograms()
            .where((f) => !_notSpawnedHere.containsKey(f))
            .toList(),
      );
    });

    for (final entry in _stepCounts.entries) {
      test(
        '${entry.key} prints ${entry.value} steps',
        () async {
          final result = await Process.run(Platform.resolvedExecutable, [
            'run',
            entry.key,
          ]);
          expect(
            result.exitCode,
            0,
            reason: 'example failed: ${result.stdout}${result.stderr}',
          );
          expect(
            _stepsIn(result.stdout as String),
            [for (var step = 1; step <= entry.value; step++) step],
            reason:
                'the transcript of ${entry.key} is not the consecutive run of '
                '${entry.value} steps it is recorded as printing. A step that '
                'stopped printing and a step added without anyone deciding it '
                'belonged are both invisible to a `check` that throws: the run '
                'stays green either way.',
          );
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    }
  });

  group('Every remaining example runs green', () {
    // Under exactly the command its header documents — plain `dart run`, no
    // extra flags — because that is the command whose behaviour the asserts
    // were wrong about, and a check that only runs under a flag nobody passes
    // is the defect again.
    final spawnHere = _examplePrograms()
        .where(
          (f) =>
              !_spawnedByModuleTest.containsKey(f) &&
              !_notSpawnedHere.containsKey(f),
        )
        .toList();

    for (final example in spawnHere) {
      test(example, () async {
        final result = await Process.run(Platform.resolvedExecutable, [
          'run',
          example,
        ]);
        expect(
          result.exitCode,
          0,
          reason: 'example failed: ${result.stdout}${result.stderr}',
        );
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  });
}
