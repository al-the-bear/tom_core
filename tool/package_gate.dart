/// Runs a `tool/` checker from inside a package's suite.
///
/// The repository's documentation rules are Python checkers under `tool/`, run
/// together by `tool/check_gates.py`. That is what a reader of the whole tree
/// runs; a package's own suite is what runs when *that* package changes. A
/// package member built on this file runs one checker scoped to its package, so
/// a rule is stated once — in the checker — and its failure still lands in the
/// suite of the package that broke it.
///
/// This file imports nothing but `dart:io`, so a plain Dart suite and a Flutter
/// suite can both import it by relative path.
library;

import 'dart:io';

/// The repository root, `tom_ai/core`, found from the package a suite runs in.
///
/// A suite runs with its package root as the working directory, and every
/// package sits directly beneath the repository root.
Directory repositoryRoot() => Directory.current.parent;

/// The launchers that start Python 3, in the order they are tried.
///
/// `python3` everywhere except Windows, where the standard entry point is the
/// `py` launcher. Both are tried rather than branched on [Platform] so that a
/// machine with only one of them works without this file knowing which.
const List<List<String>> pythonLaunchers = [
  ['python3'],
  ['py', '-3'],
];

/// Runs a Python script under `tool/` from the repository root.
///
/// Throws rather than skips when Python is absent. A skip would stop the rules
/// being enforced on precisely the machine where nobody notices, and a
/// repository whose documentation verification *is* a folder of Python scripts
/// already requires Python to work on.
ProcessResult runPython(List<String> arguments) {
  final failures = <String>[];
  for (final launcher in pythonLaunchers) {
    try {
      return Process.runSync(launcher.first, [
        ...launcher.skip(1),
        ...arguments,
      ], workingDirectory: repositoryRoot().path);
    } on ProcessException catch (e) {
      failures.add('${launcher.join(' ')}: ${e.message}');
    }
  }
  throw StateError(
    'no Python 3 launcher worked, so the checkers in tool/ could not run. '
    'Install Python 3 — they are the repository\'s documentation '
    'verification and every one of them is a Python script.\n'
    '${failures.join('\n')}',
  );
}

/// What one checker reported about one package.
class PackageGateResult {
  PackageGateResult._(this.faults, this.output);

  /// The fault count from the checker's `GATE-FAULTS:` line, or `null` when it
  /// printed none — it stopped before measuring, which is not a clean result.
  final int? faults;

  /// Everything the checker printed, for the failure message.
  final String output;
}

/// Runs `tool/<gate>.py` with this package's directory name as its argument.
///
/// Every checker that accepts a subtree takes it as a path relative to the
/// repository root, so the package's directory name is that path.
PackageGateResult runPackageGate(String gate) {
  final package = Directory.current.uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .last;
  final result = runPython(['tool/$gate.py', package]);
  final output = '${result.stdout}${result.stderr}';
  final count = RegExp(
    r'^GATE-FAULTS: (\d+)$',
    multiLine: true,
  ).firstMatch(output)?.group(1);
  return PackageGateResult._(count == null ? null : int.parse(count), output);
}
