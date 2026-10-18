/// Runs every shipped example under exactly the command its own header
/// documents, and holds the folder to one example per gap class.
///
/// **The defect this exists for.** These examples verify themselves with
/// `assert` and nothing else, and `dart run` leaves assertions *disabled* —
/// which is what its `--enable-asserts` flag is for. Under a flagless run every
/// check compiles out, so an example prints a plausible transcript and exits 0
/// whether or not anything it claims is true. The headers do name the flag;
/// without this file nothing checks that they still do, and nothing runs the
/// examples at all, so a header edited to drop the flag — or an example that
/// stopped working — would be invisible.
///
/// Two properties, because either alone is satisfiable by a broken package: the
/// examples must pass, and the command a reader is told to use must be the one
/// under which they were made to pass. A sweep that runs them with a flag the
/// header does not mention proves nothing about what a reader will see.
///
/// **The third property is this package's own.** A gap class is a verdict about
/// another package (`gap_class_inventory_test.dart` pins which ones ship), and
/// an example is where that verdict is shown to be usable. So the folder is
/// held to the inventory in both directions: a gap class with no example, or an
/// example for a gap class that no longer ships, is a fault here.
///
/// `tom_core_agentic/test/examples_test.dart` asks the first two questions of
/// its own examples in the same way, for the same reason.
library;

import 'dart:io';

import 'package:test/test.dart';

/// The flag without which an `assert` in an example is not evaluated.
const String _assertsFlag = '--enable-asserts';

/// Every example program this package ships, sorted for a stable report.
///
/// Derived by walking `example/` rather than from a list, so an example added
/// later is run the day it appears rather than the day someone remembers to
/// widen this.
List<File> _examples() {
  final files = Directory('example')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('_example.dart'))
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// The gap-class files under `lib/src/`, by bare name.
Set<String> _gapClassSubjects() => Directory('lib/src')
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .map((f) => f.uri.pathSegments.last.replaceAll('.dart', ''))
    .toSet();

void main() {
  final examples = _examples();

  group('every example is run under the command it documents', () {
    test('the sweep found the examples it claims to check', () {
      // One assertion over a directory walk runs nothing when the walk finds
      // nothing, and reports a clean package it never opened. A floor rather
      // than an exact count, because the count is supposed to grow.
      expect(
        examples.length,
        greaterThanOrEqualTo(8),
        reason: 'the walk of example/ found ${examples.length} programs',
      );
    });

    for (final example in examples) {
      final path = example.path;

      test('$path documents $_assertsFlag', () {
        // The header is the one instruction a reader is certain to follow. An
        // example that checks itself with `assert` and documents a flagless
        // `dart run` is telling the reader to run it with its checks removed.
        expect(
          example.readAsStringSync(),
          contains('dart run $_assertsFlag $path'),
          reason:
              '$path checks itself with assert, so its header must name the '
              'exact command that evaluates those asserts',
        );
      });

      test('$path runs green under it', () async {
        final result = await Process.run(Platform.resolvedExecutable, [
          'run',
          _assertsFlag,
          path,
        ]);
        expect(
          result.exitCode,
          0,
          reason: 'example failed: ${result.stdout}${result.stderr}',
        );
      }, timeout: const Timeout(Duration(minutes: 2)));

      test(
        '$path refuses to run without it',
        () async {
          // The other half. The run above keeps the example honest; it does
          // nothing for a reader who runs it from memory without the flag, and
          // under a flagless run every assert compiles out, so the example would
          // print its transcript and exit 0 having verified nothing. It must
          // refuse instead, loudly and with the fix in the message.
          final result = await Process.run(Platform.resolvedExecutable, [
            'run',
            path,
          ]);
          expect(
            result.exitCode,
            2,
            reason:
                '$path ran without $_assertsFlag and did not refuse: '
                '${result.stdout}${result.stderr}',
          );
          expect(result.stderr, contains(_assertsFlag));
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    }

    test(
      'the aggregator runs every example',
      () async {
        final result = await Process.run(Platform.resolvedExecutable, [
          'run',
          _assertsFlag,
          'example/run_all_samples.dart',
        ]);
        expect(
          result.exitCode,
          0,
          reason: 'aggregator failed: ${result.stdout}${result.stderr}',
        );
        expect(
          result.stdout,
          contains('all ${examples.length} tom_core_codespecs examples'),
          reason:
              'the aggregator reported a count that is not the number of '
              'examples on disk (${examples.length})',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  group('the examples match the gap-class inventory', () {
    test('every gap class has an example, and every example a gap class', () {
      // An example is where a gap-class verdict is shown to be usable, so the
      // two sets are held equal rather than one being a subset. A gap class
      // added without an example leaves the hardest thing in the package
      // undemonstrated; an example left behind by a removed gap class points
      // at a shape the package no longer has.
      final subjects = _gapClassSubjects();
      final demonstrated = examples
          .map((f) => f.uri.pathSegments.last.replaceAll('_example.dart', ''))
          .toSet();

      expect(
        demonstrated,
        equals(subjects),
        reason:
            'gap classes with no example: ${subjects.difference(demonstrated)}; '
            'examples with no gap class: ${demonstrated.difference(subjects)}',
      );
    });
  });
}
