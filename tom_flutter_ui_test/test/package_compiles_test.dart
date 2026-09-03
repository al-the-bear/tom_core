/// Fails when any file under `lib/` or `test/` does not compile.
///
/// **Why a suite needs a test for this at all.** A test that imports the code
/// it checks shares that code's fate. When `lib/forms_demos/phase2_demos.dart`
/// stopped compiling, the three suites importing it — `widget_test.dart`,
/// `forms_demos_logic_test.dart` and `forms_dispose_test.dart` — did not fail:
/// they failed to **load**, and a load failure is not a test failure, because
/// no assertion in the file ever runs. Nothing turned red. The run reported
/// "92 passing", and a smaller green number reads like a smaller suite rather
/// than a broken one. It stayed that way long enough to be mistaken for the
/// package's normal output, and the twenty-one analyzer errors behind it went
/// unnoticed for weeks.
///
/// So the guard cannot be an assertion inside the suite. It has to be an
/// observer that survives the package not compiling, and the only such
/// observer is a separate process: this file shells out to `dart analyze` and
/// reports what it says. Its own compilation depends on nothing but `dart:io`.
///
/// **Errors only.** Warnings and lints cannot stop a file loading, and a guard
/// that failed on them would be failing for reasons unrelated to the property
/// it protects — which is how a guard gets weakened or deleted instead of
/// fixed. The analyzer is still run in full, so anything else it found is
/// printed alongside a failure; it just cannot cause one.
///
/// The check costs about two seconds against a suite that runs in sixteen.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What the analyzer is pointed at, named once so the guard below checks the
/// same paths the run uses rather than a second copy of them.
const _analyzedPaths = ['lib', 'test'];

/// One diagnostic line of `dart analyze --format=machine`, whose shape is
/// `SEVERITY|TYPE|CODE|FILE|LINE|COLUMN|LENGTH|MESSAGE`.
class _Diagnostic {
  _Diagnostic({
    required this.severity,
    required this.code,
    required this.file,
    required this.line,
    required this.message,
  });

  final String severity;
  final String code;
  final String file;
  final String line;
  final String message;

  static _Diagnostic? parse(String raw) {
    final parts = raw.split('|');
    if (parts.length < 8) return null;
    return _Diagnostic(
      severity: parts[0],
      code: parts[2],
      file: parts[3],
      line: parts[4],
      // The message is the last field and may itself contain a `|`, so it is
      // rejoined rather than indexed.
      message: parts.sublist(7).join('|'),
    );
  }

  @override
  String toString() =>
      '  $severity $code  ${file.replaceFirst('${Directory.current.path}/', '')}'
      ':$line\n    $message';
}

/// Candidate ways to reach the Dart SDK, tried in order.
///
/// `Platform.resolvedExecutable` is no help directly: under `flutter test` it
/// is `flutter_tester`, an engine artifact that does not take `analyze`. But
/// its path names the Flutter checkout it came from, so the SDK's own `dart`
/// can be derived from it — which is what makes this work on a machine that
/// has Flutter and never put `dart` on `PATH`.
List<String> _dartLaunchers() {
  final launchers = <String>['dart'];
  final tester = Platform.resolvedExecutable;
  final cacheAt = tester.indexOf('/bin/cache/');
  if (cacheAt > 0) {
    launchers.add('${tester.substring(0, cacheAt)}/bin/dart');
  }
  return launchers;
}

/// What one analyzer run reported: its diagnostics and the exit code it chose.
///
/// The exit code is kept because it is a second, independent statement of the
/// same fact — `dart analyze` exits by highest severity found, `3` meaning
/// "errors" — and the two are cross-checked below. That cross-check is not
/// hypothetical: the first version of this file read the diagnostics off
/// `stderr`, where the analyzer writes nothing, and so passed against a
/// package with a deliberate compile error in it.
typedef _Report = ({int exitCode, List<_Diagnostic> diagnostics});

/// Runs the analyzer over [_analyzedPaths] and returns everything it said.
///
/// Throws rather than skips when no Dart SDK can be reached. A skip would mean
/// the package stops being checked on precisely the machine where nobody
/// notices, which is the failure this file exists to end — and a Dart package
/// whose tests are running has a Dart SDK by definition.
_Report _analyze() {
  final unreachable = <String>[];
  for (final launcher in _dartLaunchers()) {
    final ProcessResult result;
    try {
      result = Process.runSync(
        launcher,
        ['analyze', '--format=machine', ..._analyzedPaths],
      );
    } on ProcessException catch (e) {
      unreachable.add('$launcher: ${e.message}');
      continue;
    }
    // `dart analyze` exits 0 when clean and 1–3 by the highest severity it
    // found. Anything above that is the analyzer failing to run rather than a
    // result — a path that does not exist exits 64, for instance, which would
    // otherwise read as "clean".
    if (result.exitCode > 3) {
      throw StateError(
        '`$launcher analyze` exited ${result.exitCode}, so nothing was '
        'checked.\n${result.stdout}\n${result.stderr}',
      );
    }
    // Machine format goes to stdout, one diagnostic per line.
    final diagnostics = <_Diagnostic>[];
    for (final line in (result.stdout as String).split('\n')) {
      final diagnostic = _Diagnostic.parse(line.trim());
      if (diagnostic != null) diagnostics.add(diagnostic);
    }
    return (exitCode: result.exitCode, diagnostics: diagnostics);
  }
  throw StateError(
    'no Dart SDK could be reached, so the package was never checked for '
    'compile errors. Tried: ${unreachable.join('; ')}',
  );
}

void main() {
  late final _Report report;

  setUpAll(() => report = _analyze());

  test('every file under lib/ and test/ compiles', () {
    final errors =
        report.diagnostics.where((d) => d.severity == 'ERROR').toList();
    expect(
      errors,
      isEmpty,
      reason: 'The package does not compile, which means some suites did not '
          'run at all — read the passing count as a lower bound, not a '
          'result.\n${errors.join('\n')}',
    );
  });

  test('the analyzer was read correctly', () {
    // Guards the guard, and it has already earned its place: the check above
    // was first written against `stderr`, which the analyzer leaves empty, so
    // it reported a clean package while a deliberate compile error sat in
    // `phase2_demos.dart`. A check that cannot fail is worse than no check,
    // because it is also a claim that someone is watching.
    //
    // `dart analyze` states the same fact twice — once as diagnostics, once as
    // an exit code chosen by highest severity — and the two cannot be read off
    // the same mistake. Anything that silently stops the diagnostics arriving
    // shows up here as `3` with nothing parsed.
    final foundErrors =
        report.diagnostics.any((d) => d.severity == 'ERROR');
    expect(
      foundErrors,
      report.exitCode == 3,
      reason: 'the analyzer exited ${report.exitCode} but '
          '${report.diagnostics.length} diagnostic(s) were parsed from its '
          'output, of which ${foundErrors ? 'some' : 'none'} were errors — '
          'the two disagree, so the output is not being read as intended',
    );
  });

  test('the analyzer was handed something to analyze', () {
    // A path that does not exist exits 64 and is caught in `_analyze`, but a
    // path that exists and holds no Dart files exits 0 in silence, which is
    // indistinguishable from a clean package. Counting the sources is what
    // makes that difference observable.
    for (final path in _analyzedPaths) {
      final sources = Directory(path)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(
        sources,
        isNotEmpty,
        reason: '`$path` holds no Dart files, so analyzing it proves nothing',
      );
    }
  });
}
