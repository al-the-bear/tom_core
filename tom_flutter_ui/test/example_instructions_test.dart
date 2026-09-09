import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Guards the command each shipped example tells a reader to run.
///
/// An example's header is the one instruction a reader is certain to follow, so
/// it has to name a command that both *runs the example* and *reports what
/// happened*. Those are two requirements, and the obvious command satisfies
/// only the first: `flutter test example/<dir>/<name>_example.dart` does
/// execute `main()` at load time — every print appears, every assert is
/// evaluated — and then exits 79, "No tests were found", because an example
/// declares no `test()` of its own. A reader sees the output and thinks it
/// worked; anything reading the exit code (CI, a `&&` chain, a `tool/` script,
/// a pre-commit hook) sees it as broken. Worse, it exits 79 whether the
/// assertions held or not, so the code carries no information about the example
/// at all.
///
/// The premise those headers stated was right and is kept: the package barrel
/// pulls in `flutter/material` and so `dart:ui`, and bare `dart run` genuinely
/// cannot execute one of these. What was wrong was the remedy. Each example now
/// names the suite that calls its `run()`, which exits 0 when the example
/// succeeds and non-zero when one of its assertions fails — true only while the
/// wiring is real, and the wiring is what these tests hold in place.
///
/// **Headers are read unwrapped.** A dartdoc sentence breaks wherever the
/// margin falls, and one of the eleven sites this was written for split the
/// command down the middle — `flutter test` ending a line and
/// `example/widget_base/...` starting the next. A line-oriented search finds
/// ten of eleven and reports the corpus clean, which is how that site survived
/// the sweep that produced this file's todo.
void main() {
  /// Every example this package ships, sorted for a stable report.
  ///
  /// `_example.dart` rather than every `.dart` under `example/`:
  /// `gallery_demo.dart` beside them is a `runApp` demo application, not an
  /// example a reader is told to run under `flutter test`, and holding it to an
  /// instruction it should not carry would push someone to write a false one.
  List<File> exampleFiles() {
    final files = Directory('example')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_example.dart'))
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// The library doc comment at the top of [file], as one line.
  ///
  /// The `///` markers and the line breaks are removed before anything is
  /// matched, so a command is found wherever the margin happened to break it.
  /// See the note on unwrapping above.
  String headerOf(File file) {
    final source = file.readAsStringSync();
    final end = source.indexOf('\nlibrary;');
    final head = end == -1 ? source : source.substring(0, end);
    return head
        .replaceAll(RegExp(r'^\s*///\s?', multiLine: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// The suite an example's header names, or null if it names none.
  ///
  /// The path is nested — `test/<dir>/<name>_test.dart` — where the sibling
  /// guard in `tom_core_flutter` reads a flat `test/<module>_test.dart`. That
  /// is the one thing that could not be copied across, and reading the flat
  /// shape here would find nothing and report every example unguarded.
  final namedSuite = RegExp(r'flutter test (test/[A-Za-z0-9_/]+_test\.dart)');

  /// The form that exits 79: `flutter test` aimed at an example file.
  final selfTargetedCommand = RegExp(r'flutter test example/');

  test('every shipped example is discovered', () {
    // Paired with the guards below, which a deletion would otherwise satisfy:
    // an example that no longer exists names no bad command either. The named
    // directories are the ones that exist today; the list is a floor, not a
    // census, so adding an example does not fail this.
    final directories = exampleFiles()
        .map((f) => p.basename(p.dirname(f.path)))
        .toSet();
    expect(
      directories,
      containsAll(<String>[
        'actions',
        'advanced_container_layout',
        'custom',
        'forms',
        'groups',
        'resource_auth',
        'theme',
        'widget_base',
        'widgets',
      ]),
    );
    expect(
      exampleFiles(),
      hasLength(greaterThanOrEqualTo(11)),
      reason:
          'two directories ship two examples each; a walk that found one '
          'per directory has stopped reading recursively',
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
      reason:
          'an example whose header names no runnable suite leaves the '
          'reader to guess:\n${offenders.join('\n')}',
    );
  });

  test('the suite an example names actually runs it', () {
    // The header's claim is that the command executes the example. Naming a
    // suite that exists but never calls `run()` would satisfy the check above
    // while making the instruction false — and the exit code uninformative
    // again, which is the whole defect.
    //
    // `example.run` without parentheses, not `example.run()`: most of these
    // suites hand the function to a matcher (`expect(example.run,
    // returnsNormally)`) rather than calling it themselves, which runs it just
    // the same. Demanding the parenthesised form would report nine of eleven
    // working suites as broken.
    final offenders = <String>[];
    for (final file in exampleFiles()) {
      final match = namedSuite.firstMatch(headerOf(file));
      if (match == null) continue; // already reported above
      final suite = File(match.group(1)!);
      if (!suite.existsSync()) continue; // already reported above
      // The import may wrap, so the suite is read unwrapped too.
      final source = suite.readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
      final importPath = p.url.join(
        '..',
        '..',
        p.split(p.relative(file.path)).join('/'),
      );
      if (!source.contains("import '$importPath' as example;")) {
        offenders.add('${suite.path}: does not import ${file.path}');
      } else if (!RegExp(r'\bexample\.run\b').hasMatch(source)) {
        offenders.add(
          '${suite.path}: imports ${file.path} but never runs example.run',
        );
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'an example is quoted as documentation, so the command its '
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
      reason:
          '`flutter test example/...` runs the example and then exits 79 '
          '("No tests were found") whether it succeeded or not, so the '
          'instruction hands the reader a failing command:\n'
          '${offenders.join('\n')}',
    );
  });
}
