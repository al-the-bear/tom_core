/// The one implementation of the per-package formatting guard.
///
/// Every package under `tom_ai/core` carries a `test/formatting_test.dart`, and
/// every one of them is a few lines that describe the package — how many files a
/// walk of it must at least find, which directories it must reach, whether it
/// holds generated output — and hand the rest to [PackageFormatSweep]. The
/// logic lives here once, so the eight guards cannot drift apart from each
/// other the way the packages they guard drifted from the formatter.
///
/// **Why a guard per package at all**, when `tool/check_dart_format.py` checks
/// every package at once: the gate is what a reader of the whole tree runs, and
/// a package's own suite is what runs when *that* package changes — which is
/// when its formatting drifts. `dart analyze` reports nothing about line
/// wrapping, so without the guard a file can be analyzer-clean, test-green,
/// reviewed and merged while unformatted, and every later change that runs the
/// formatter drags a slice of that drift into its diff.
///
/// The fix when a guard fails is always the same and never a code change: run
/// `dart format .` in the package. **If it fails on a machine where nothing was
/// edited**, the SDK's formatter has changed its output; reformat the package
/// as its own whitespace-only commit. Do not relax the guard to accommodate it.
///
/// This file imports nothing but `dart:io`, so it can be imported by relative
/// path from a plain Dart suite and a Flutter suite alike, and has no package
/// configuration of its own to resolve.
library;

import 'dart:io';

/// The suffixes of machine-written files. The same list as
/// `tool/check_dart_format.py`, so the guards and the gate agree on what is
/// generated. A generator that emits unformatted code is the generator's
/// defect, and failing a package's suite for it would point at the wrong
/// package.
const List<String> generatedSuffixes = [
  '.reflection.dart',
  '.versioner.dart',
  '.g.dart',
  '.freezed.dart',
];

/// Whether [path] is machine-written; see [generatedSuffixes].
bool isGenerated(String path) => generatedSuffixes.any(path.endsWith);

/// One walk of the package a suite runs in, and the three checks over it.
///
/// Construct it in the test's `main`, where the working directory is the
/// package root under both `dart test` and `flutter test`.
class PackageFormatSweep {
  /// Walks the package rooted at the current directory.
  ///
  /// [minimumFiles] and [landmarks] are how the sweep proves it read the
  /// package: a walk that finds nothing formats nothing and passes. The floor is
  /// a floor rather than an exact count because the count is supposed to grow,
  /// and the landmarks are directories structural to the package that cannot
  /// legitimately become empty. [hasGeneratedOutput] states whether the package
  /// commits generated files, so the exclusion is held to matching something
  /// exactly when there is something to match.
  PackageFormatSweep({
    required this.minimumFiles,
    required this.landmarks,
    required this.hasGeneratedOutput,
  }) {
    final all = _packageDartFiles();
    authored = [
      for (final path in all)
        if (!isGenerated(path)) path,
    ];
    generated = [
      for (final path in all)
        if (isGenerated(path)) path,
    ];
  }

  /// The fewest authored files a correct walk can find.
  final int minimumFiles;

  /// Directories the walk must reach at least one authored file under.
  final List<String> landmarks;

  /// Whether the package commits generated Dart files.
  final bool hasGeneratedOutput;

  /// Every hand-written Dart file in the package, relative to its root.
  late final List<String> authored;

  /// Every generated Dart file in the package, relative to its root.
  late final List<String> generated;

  /// The formatter's report on the authored files, or `null` when every one of
  /// them survives `dart format` unchanged.
  Future<String?> unformatted() async {
    final result = await Process.run(dartExecutable(), [
      'format',
      '--output=none',
      '--set-exit-if-changed',
      ...authored,
    ]);
    if (result.exitCode == 0) return null;
    return 'these files are not formatted; run `dart format .`\n'
        '${result.stdout}${result.stderr}';
  }

  /// Why the walk cannot be trusted to have read the package, or nothing.
  List<String> coverageProblems() => [
    if (authored.length < minimumFiles)
      'the walk found ${authored.length} files, fewer than the $minimumFiles '
          'the package holds at least, so the format check swept almost '
          'nothing',
    for (final directory in landmarks)
      if (!authored.any((path) => path.startsWith('$directory/')))
        'the walk reached no files under $directory/, so nothing there is '
            'format-checked',
  ];

  /// Why the generated-file exclusion is not doing what it says, or nothing.
  ///
  /// An exclusion that matches nothing in a package declaring generated output
  /// is a dead rule nobody will know is dead; generated files in a package
  /// declaring none mean the declaration is out of date.
  List<String> exclusionProblems() => [
    if (hasGeneratedOutput && generated.isEmpty)
      'nothing matches the generated-file exclusion; set hasGeneratedOutput '
          'to false rather than keeping a rule that does nothing',
    if (!hasGeneratedOutput && generated.isNotEmpty)
      'the package now holds generated files (${generated.join(', ')}); set '
          'hasGeneratedOutput to true',
    if (authored.any(isGenerated))
      'generated files reached the format check despite the exclusion',
  ];
}

/// The `dart` that ships with the SDK running this suite.
///
/// Under `dart test`, [Platform.resolvedExecutable] is that `dart`. Under
/// `flutter test` it is `bin/cache/artifacts/engine/<platform>/flutter_tester`,
/// which, handed `format` as its first argument, does not fail but hangs until
/// the suite's timeout — a failure about nothing. So the test engine is
/// recognised and the SDK's `dart` is found through `FLUTTER_ROOT`, which the
/// `flutter` tool sets for every command it runs and beneath which the Dart
/// SDK's location is fixed.
///
/// When `FLUTTER_ROOT` is unset, the checkout is read off the test engine's own
/// path instead.
///
/// The last resort is `dart` on `PATH`, for a run that reaches the guard some
/// other way. It may belong to a different SDK, so it is the last choice
/// rather than the first; a guard checking a slightly different formatter
/// still beats one that cannot run.
String dartExecutable() {
  final running = Platform.resolvedExecutable;
  final name = running.split(Platform.pathSeparator).last;
  if (name == 'dart' || name == 'dart.exe') return running;

  final separator = Platform.pathSeparator;
  // The Flutter checkout the run came from: FLUTTER_ROOT when the `flutter`
  // tool set it, otherwise read off the test engine's own path, which sits at
  // `<root>/bin/cache/artifacts/...` — so a machine that never put `dart` on
  // PATH, or a runner that dropped the variable, still finds the right SDK.
  final cacheAt = running.indexOf('${separator}bin${separator}cache$separator');
  final roots = [
    Platform.environment['FLUTTER_ROOT'] ?? '',
    if (cacheAt > 0) running.substring(0, cacheAt),
  ];
  for (final root in roots) {
    if (root.isEmpty) continue;
    final dart = File(
      [root, 'bin', 'cache', 'dart-sdk', 'bin', 'dart'].join(separator),
    );
    if (dart.existsSync()) return dart.path;
  }
  return 'dart';
}

/// Every Dart file in the package, generated ones included, relative to the
/// package root.
///
/// Derived by walking the package rather than from a list of directories, so a
/// script added under `tool/` or a file at the root is covered the day it
/// appears. Dot-directories are skipped: `.dart_tool` holds package copies the
/// package does not author, and `.git` holds no Dart. Links are not followed,
/// for the cost and for the loops they can form.
List<String> _packageDartFiles() {
  final files = <String>[];

  void walk(Directory directory) {
    for (final entity in directory.listSync(followLinks: false)) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name.startsWith('.')) continue;
      if (entity is Directory) {
        walk(entity);
      } else if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity.path);
      }
    }
  }

  walk(Directory('.'));
  files.sort();
  final prefix = '.${Platform.pathSeparator}';
  return [
    for (final path in files)
      path.startsWith(prefix) ? path.substring(prefix.length) : path,
  ];
}
