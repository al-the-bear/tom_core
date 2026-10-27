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

/// The repository whose `tool/` holds the gates, `tom_ai/core`, found from the
/// package a suite runs in.
Directory repositoryRoot() => _roots().core;

/// The package a suite runs in, as a path relative to the root that holds it
/// -- `tom_core_kernel`, `tom_core_samples/advanced_ops_server`, or, for a
/// package of `tom_core_extensions`, `tom_core_agentic`. The gates resolve
/// such a path in either root (`tool/gate_scope.py`).
String packagePath() {
  final root = _roots().own.uri.pathSegments.where((s) => s.isNotEmpty);
  final here = Directory.current.absolute.uri.pathSegments.where(
    (s) => s.isNotEmpty,
  );
  return here.skip(root.length).join('/');
}

/// The gates' repository and the repository the current package is in.
///
/// A suite runs with its package root as the working directory. Walking up,
/// the first directory holding `tool/check_gates.py` is `tom_ai/core` itself
/// -- found from a sample nested under `tom_core_samples/` as well as from a
/// package directly beneath it. A package of `tom_core_extensions` finds
/// instead the directory whose sibling `core/` holds the gates: that is
/// `tom_ai/core_extension`, and the gates read it too.
({Directory core, Directory own}) _roots() {
  var dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/tool/check_gates.py').existsSync()) {
      return (core: dir, own: dir);
    }
    final sibling = Directory('${dir.parent.path}/core');
    if (File('${sibling.path}/tool/check_gates.py').existsSync()) {
      return (core: sibling, own: dir);
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'no ancestor of ${Directory.current.path} holds tool/check_gates.py '
        'or sits beside a core/ that does, so this suite is not running '
        'inside tom_ai/core or tom_ai/core_extension',
      );
    }
    dir = parent;
  }
}

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

/// Runs `tool/<gate>.py` with this package's path as its argument.
///
/// Every checker that accepts a subtree takes it as a path relative to the
/// root that holds it, which is what [packagePath] returns.
PackageGateResult runPackageGate(String gate) {
  final result = runPython(['tool/$gate.py', packagePath()]);
  final output = '${result.stdout}${result.stderr}';
  final count = RegExp(
    r'^GATE-FAULTS: (\d+)$',
    multiLine: true,
  ).firstMatch(output)?.group(1);
  return PackageGateResult._(count == null ? null : int.parse(count), output);
}
