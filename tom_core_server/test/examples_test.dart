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
  'example/transactions/transactions_example.dart':
      'test/transactions_test.dart',
};

/// Example programs this suite deliberately does not spawn, and why.
///
/// Stating them here with a reason is the point — a silently unrun example is
/// the defect this file exists to prevent, one level up. A reason is what
/// separates "we decided not to" from "we forgot".
const _notSpawnedHere = <String, String>{
  // The scheduling cluster demo: three nodes that expect a live MariaDB and
  // each other, started as a group rather than individually.
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
