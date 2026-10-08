/// The one implementation of the per-package compile guard.
///
/// A package that carries one has a `test/package_compiles_test.dart` of a few
/// lines naming what to analyze and handing the rest to [PackageCompileCheck].
/// The logic lives here once, so the copies cannot drift apart.
///
/// **Why a suite needs a test for this at all.** A test that imports the code
/// it checks shares that code's fate. When a shared library under `lib/` stops
/// compiling, every suite importing it fails to **load**, and a load failure is
/// not a test failure: no assertion in the file ever runs, so nothing turns
/// red. The run reports a smaller passing count, and a smaller green number
/// reads like a smaller suite rather than a broken one. In
/// `tom_flutter_ui_test` that state persisted for weeks behind twenty-one
/// analyzer errors, three suites silently not running.
///
/// So the guard cannot be an assertion inside the code it guards. It has to be
/// an observer that survives the package not compiling, and the only such
/// observer is a separate process: [PackageCompileCheck] shells out to
/// `dart analyze` and reports what it says. This file imports nothing but
/// `dart:io` (and the format guard beside it, which imports nothing but
/// `dart:io`), so it compiles whatever state the package is in, and a plain
/// Dart suite and a Flutter suite can both import it by relative path.
///
/// **Errors only.** Warnings and lints cannot stop a file loading, and a guard
/// that failed on them would be failing for reasons unrelated to the property
/// it protects — which is how a guard gets weakened or deleted instead of
/// fixed. The analyzer is still run in full; it just cannot fail the guard on
/// anything but an error.
///
/// **It checks its own reading.** `dart analyze` states the same fact twice —
/// once as diagnostics, once as an exit code chosen by the highest severity
/// found, `3` meaning errors — and [readingProblem] holds the two against each
/// other. That is not hypothetical: the first version of this guard read the
/// diagnostics off `stderr`, where the analyzer writes nothing, and so passed
/// against a package with a deliberate compile error in it.
library;

import 'dart:io';

import 'package_format_guard.dart' show dartExecutable;

/// One diagnostic line of `dart analyze --format=machine`, whose shape is
/// `SEVERITY|TYPE|CODE|FILE|LINE|COLUMN|LENGTH|MESSAGE`.
class AnalyzerDiagnostic {
  AnalyzerDiagnostic._({
    required this.severity,
    required this.code,
    required this.file,
    required this.line,
    required this.message,
  });

  /// `ERROR`, `WARNING` or `INFO`.
  final String severity;

  /// The diagnostic's code, e.g. `undefined_identifier`.
  final String code;

  /// The file it is in, as the analyzer printed it (absolute).
  final String file;

  /// The line it is on.
  final String line;

  /// The analyzer's message.
  final String message;

  /// Parses one line of machine output, or `null` for anything else.
  static AnalyzerDiagnostic? parse(String raw) {
    final parts = raw.split('|');
    if (parts.length < 8) return null;
    return AnalyzerDiagnostic._(
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

/// One run of `dart analyze` over the package a suite runs in, and the three
/// checks over its result.
///
/// Construct it in the test's `main`, where the working directory is the
/// package root under both `dart test` and `flutter test`. The analyzer runs on
/// the first check that needs it, not at construction, so loading the test
/// file costs nothing.
class PackageCompileCheck {
  /// Checks the package rooted at the current directory, analyzing [paths].
  PackageCompileCheck({required this.paths});

  /// What the analyzer is pointed at, relative to the package root.
  final List<String> paths;

  late final ({int exitCode, List<AnalyzerDiagnostic> diagnostics}) _report =
      _analyze();

  /// Every diagnostic the analyzer reported.
  List<AnalyzerDiagnostic> get diagnostics => _report.diagnostics;

  /// The compile errors, as a failure message, or `null` when there are none.
  String? compileErrors() {
    final errors = diagnostics.where((d) => d.severity == 'ERROR').toList();
    if (errors.isEmpty) return null;
    return 'The package does not compile, which means some suites did not '
        'run at all — read the passing count as a lower bound, not a '
        'result.\n${errors.join('\n')}';
  }

  /// Why the analyzer's output was not read as intended, or `null`.
  ///
  /// Anything that silently stops the diagnostics arriving shows up here as an
  /// exit code of `3` with no error parsed — the two statements of the same
  /// fact disagree, and they cannot be read off the same mistake.
  String? readingProblem() {
    final foundErrors = diagnostics.any((d) => d.severity == 'ERROR');
    if (foundErrors == (_report.exitCode == 3)) return null;
    return 'the analyzer exited ${_report.exitCode} but '
        '${diagnostics.length} diagnostic(s) were parsed from its output, of '
        'which ${foundErrors ? 'some' : 'none'} were errors — the two '
        'disagree, so the output is not being read as intended';
  }

  /// The [paths] that hold no Dart file, so analyzing them proves nothing.
  ///
  /// A path that does not exist makes the analyzer exit 64, which [_analyze]
  /// refuses; a path that exists and holds no Dart files exits 0 in silence,
  /// indistinguishable from a clean package. Counting the sources is what
  /// makes the difference observable.
  List<String> emptyPaths() => [
    for (final path in paths)
      if (!Directory(path)
          .listSync(recursive: true)
          .whereType<File>()
          .any((f) => f.path.endsWith('.dart')))
        path,
  ];

  ({int exitCode, List<AnalyzerDiagnostic> diagnostics}) _analyze() {
    final dart = dartExecutable();
    final ProcessResult result;
    try {
      result = Process.runSync(dart, ['analyze', '--format=machine', ...paths]);
    } on ProcessException catch (e) {
      // Thrown rather than skipped: a skip would stop the package being
      // checked on precisely the machine where nobody notices, and a Dart
      // package whose tests are running has a Dart SDK by definition.
      throw StateError(
        'no Dart SDK could be reached at `$dart`, so the package was never '
        'checked for compile errors: ${e.message}',
      );
    }
    // `dart analyze` exits 0 when clean and 1–3 by the highest severity it
    // found. Anything above that is the analyzer failing to run rather than a
    // result — a path that does not exist exits 64, which would otherwise
    // read as "clean".
    if (result.exitCode > 3) {
      throw StateError(
        '`$dart analyze` exited ${result.exitCode}, so nothing was '
        'checked.\n${result.stdout}\n${result.stderr}',
      );
    }
    // Machine format goes to stdout, one diagnostic per line.
    final diagnostics = <AnalyzerDiagnostic>[
      for (final line in (result.stdout as String).split('\n'))
        ?AnalyzerDiagnostic.parse(line.trim()),
    ];
    return (exitCode: result.exitCode, diagnostics: diagnostics);
  }
}
