import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Guards the command each shipped example tells a reader to run.
///
/// An example's header is the one instruction a reader is certain to follow, so
/// it has to name a command that both *runs the example* and *reports what
/// happened*. Those are two requirements, and the obvious command satisfies
/// only the first: `flutter test example/<m>/<m>_example.dart` does execute
/// `main()` at load time — every print appears, every assert is evaluated — and
/// then exits 79, "No tests were found", because an example declares no
/// `test()` of its own. A reader sees the output and thinks it worked; anything
/// reading the exit code (CI, a `&&` chain, a `tool/` script, a pre-commit
/// hook) sees it as broken. Worse, it exits 79 whether the assertions held or
/// not, so the code carries no information about the example at all.
///
/// The remedy is that each example points at the suite that calls its `run()`.
/// That command exits 0 when the example succeeds and non-zero when one of its
/// assertions fails — which is only true while the wiring is real, and the
/// wiring is what these tests hold in place.
void main() {
  /// Every example this package ships, sorted for a stable report.
  ///
  /// `_example.dart` rather than every `.dart` under `example/`: the reflection
  /// seed beside them is generated scaffolding with an empty `main`, not
  /// something a reader is ever told to run.
  List<File> exampleFiles() {
    final files = Directory('example')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_example.dart'))
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// The library doc comment at the top of [file] — everything a reader meets
  /// before the code, and where the run instruction lives.
  String headerOf(File file) {
    final source = file.readAsStringSync();
    final end = source.indexOf('\nlibrary;');
    return end == -1 ? source : source.substring(0, end);
  }

  /// The suite an example's header names, or null if it names none.
  final namedSuite = RegExp(r'flutter test (test/[A-Za-z0-9_]+_test\.dart)');

  /// The form that exits 79: `flutter test` aimed at an example file.
  final selfTargetedCommand = RegExp(r'flutter test example/');

  String moduleOf(File file) =>
      p.basenameWithoutExtension(file.path).replaceAll('_example', '');

  test('every shipped example is discovered', () {
    // Paired with the guards below, which a deletion would otherwise satisfy:
    // an example that no longer exists names no bad command either. The named
    // modules are the ones that exist today; the list is a floor, not a
    // census, so adding an example does not fail this.
    final modules = exampleFiles().map(moduleOf).toSet();
    expect(
      modules,
      containsAll(<String>[
        'configuration',
        'little_things',
        'observing',
        'preferences',
        'resources',
        'runtime',
        'security',
      ]),
    );
  });

  test('every example names a suite that exists', () {
    final offenders = <String>[];
    for (final file in exampleFiles()) {
      final match = namedSuite.firstMatch(headerOf(file));
      if (match == null) {
        offenders.add('${file.path}: names no `flutter test test/...` command');
        continue;
      }
      final suite = match.group(1)!;
      if (!File(suite).existsSync()) {
        offenders.add('${file.path}: names $suite, which does not exist');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'an example whose header names no runnable suite leaves the '
          'reader to guess:\n${offenders.join('\n')}',
    );
  });

  test('the suite an example names actually runs it', () {
    // The header's claim is that the command executes the example. Naming a
    // suite that exists but never calls `run()` would satisfy the check above
    // while making the instruction false — and the exit code uninformative
    // again, which is the whole defect.
    final offenders = <String>[];
    for (final file in exampleFiles()) {
      final match = namedSuite.firstMatch(headerOf(file));
      if (match == null) continue; // already reported above
      final suite = File(match.group(1)!);
      if (!suite.existsSync()) continue; // already reported above
      final source = suite.readAsStringSync();
      final importPath = p.url.join(
        '..',
        p.split(p.relative(file.path)).join('/'),
      );
      if (!source.contains("import '$importPath' as example;")) {
        offenders.add('${suite.path}: does not import ${file.path}');
      } else if (!source.contains('example.run()')) {
        offenders.add('${suite.path}: imports ${file.path} but never calls '
            'example.run()');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'an example is quoted as documentation, so the command its '
          'header names has to execute it:\n${offenders.join('\n')}',
    );
  });

  test('no example tells the reader to run a command that exits 79', () {
    final offenders = exampleFiles()
        .where((file) => selfTargetedCommand.hasMatch(headerOf(file)))
        .map((file) => file.path)
        .toList();
    expect(
      offenders,
      isEmpty,
      reason: '`flutter test example/...` runs the example and then exits 79 '
          '("No tests were found") whether it succeeded or not, so the '
          'instruction hands the reader a failing command:\n'
          '${offenders.join('\n')}',
    );
  });
}
