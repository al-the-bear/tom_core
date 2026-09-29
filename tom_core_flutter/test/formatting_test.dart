/// The guard that keeps the package `dart format`-clean.
///
/// Formatting drift is invisible to the gate everybody actually runs.
/// `flutter analyze` reports nothing about line wrapping, so a file can be
/// analyzer-clean, test-green, reviewed and merged while being unformatted —
/// and nothing says so until somebody runs the formatter and watches it rewrite
/// files they did not touch.
///
/// That is not hypothetical here. Twenty-one of this package's files carried
/// the pre-3.7 short style until they were reformatted in one whitespace-only
/// commit — 29 files, 942 insertions, 634 deletions — and the reason it could
/// not be left alone is the reason this suite exists. While the drift stands,
/// every change that runs the formatter as a side effect drags an arbitrary
/// slice of the reformat into its diff, so a six-test change arrives as a
/// several-hundred-line one and stops being reviewable. The observed response
/// was the bad one: the formatter was avoided and new code written to match the
/// file's existing style, which grows the drift instead of stopping it.
///
/// So the invariant is checked rather than remembered. The fix when this fails
/// is always the same and never a code change: run `dart format .`.
///
/// The scope is **every Dart file in the package**, derived by walking it, and
/// not a list of directories to keep up to date. A checker told where to look
/// stops covering the package the moment a file appears somewhere else, and
/// reports nothing while it does. Only two things are left out, each for a
/// stated reason: the dot-directories the package does not author, and
/// generated output.
///
/// `tool/check_dart_format.py` checks the same property across every package in
/// `tom_ai/core` at once. This is not a duplicate of it but the other half: the
/// gate is what a reader of the whole tree runs, and this is what runs when
/// *this* package changes, which is when its formatting drifts.
///
/// **If this fails on a machine where nothing was edited**, the SDK's formatter
/// has changed its output. Reformat the package and commit that as its own
/// whitespace-only change, the same shape as the commit above. Do not relax
/// this test to accommodate it: a formatter change that nobody reformats for is
/// precisely how the first drift accumulated.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The directories a walk of this package must reach, whatever else it finds.
///
/// These are not the *scope* — the scope is every Dart file in the package (see
/// [_packageDartFiles]). They are landmarks: three directories that are
/// structural to the package and cannot legitimately become empty, so a walk
/// that misses one has gone wrong rather than found a smaller package.
const List<String> _landmarkDirectories = ['lib', 'example', 'test'];

/// The `dart` that ships with the SDK running this suite.
///
/// **Not `Platform.resolvedExecutable`**, which is what the same guard in the
/// non-Flutter packages uses. Under `flutter test` that resolves to
/// `bin/cache/artifacts/engine/<platform>/flutter_tester`, not to `dart` — so
/// the sibling guard, copied across unchanged, spawns the test engine with
/// `format` as its first argument and hangs until the suite's timeout. It fails
/// for a reason that has nothing to do with formatting, which is the worst
/// shape a guard can fail in.
///
/// `FLUTTER_ROOT` is set by the `flutter` tool for every command it runs, and
/// the Dart SDK's location beneath it is fixed. Resolving through it gets the
/// formatter the developer's own `dart format` would use, which is the property
/// the sibling was reaching for by a route this package does not have.
///
/// The fallback to `dart` on `PATH` is for a run that reaches this file some
/// other way. It is a weaker guarantee — that `dart` may belong to a different
/// SDK — so it is the second choice rather than the first, but a guard that
/// checks a slightly different formatter still beats one that cannot run.
String _dartExecutable() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    final dart = File(
      '$root${Platform.pathSeparator}bin${Platform.pathSeparator}cache'
      '${Platform.pathSeparator}dart-sdk${Platform.pathSeparator}bin'
      '${Platform.pathSeparator}dart',
    );
    if (dart.existsSync()) return dart.path;
  }
  return 'dart';
}

/// Machine-written files, which this package does not author and cannot fix.
///
/// A generator that emits unformatted code is the generator's defect, and
/// failing this suite for it would point the reader at the wrong package.
/// The suffixes of machine-written files. The same list as the repo-wide
/// `tool/check_dart_format.py`, so the two guards agree on what is generated.
const List<String> _generatedSuffixes = [
  '.reflection.dart',
  '.versioner.dart',
  '.g.dart',
  '.freezed.dart',
];

bool _isGenerated(String path) => _generatedSuffixes.any(path.endsWith);

/// Every Dart file in the package, generated ones included, as paths relative
/// to the package root.
///
/// Derived by walking the package rather than from a list of directories, so a
/// script added under `tool/`, or a file at the root, is covered without anyone
/// remembering to widen the list — which is this suite's own failure mode one
/// level up.
///
/// Dot-directories are skipped rather than filtered afterwards: `.dart_tool`
/// holds package copies this package does not author (and which the formatter
/// excludes anyway) and `.git` holds no Dart at all, so descending into either
/// would cost far more than the walk. Links are not followed, for the same
/// reason plus the loop they can form.
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
  // The walk starts at `.`, so every path carries a `./` the landmark check and
  // the failure message are both clearer without.
  final prefix = '.${Platform.pathSeparator}';
  return [
    for (final path in files)
      path.startsWith(prefix) ? path.substring(prefix.length) : path,
  ];
}

void main() {
  group('the package is formatted', () {
    final all = _packageDartFiles();
    final authored = all.where((path) => !_isGenerated(path)).toList();
    final generated = all.where(_isGenerated).toList();

    test(
      'every file it authors survives `dart format` unchanged',
      () async {
        // Run the formatter that ships with the SDK running this test, rather
        // than whatever `dart` is first on PATH. The two differ on a machine with
        // several SDKs installed, and a guard that checks a different formatter
        // from the one the developer will run to fix it is worse than none. See
        // [_dartExecutable] for why that is not `Platform.resolvedExecutable`
        // here.
        final result = await Process.run(_dartExecutable(), [
          'format',
          '--output=none',
          '--set-exit-if-changed',
          ...authored,
        ]);
        expect(
          result.exitCode,
          0,
          reason:
              'these files are not formatted; run `dart format .`\n'
              '${result.stdout}${result.stderr}',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('the sweep is reading the files it claims to check', () {
      // The check above is one assertion over a directory walk, so a walk that
      // finds nothing formats nothing and passes — reporting a clean package it
      // never opened. Neither a rename of `lib/` nor a change in the working
      // directory tests run from would be noticed. So the sweep has to prove it
      // ran.
      //
      // Stated as a floor and a set of landmarks rather than an exact count,
      // because the count is supposed to move — every new file adds one — and a
      // test that must be edited whenever the thing it measures grows correctly
      // is a test that will be edited without being read.
      expect(
        authored,
        hasLength(greaterThan(40)),
        reason:
            'the walk found far fewer files than the package contains, so '
            'the format check above swept almost nothing',
      );
      for (final directory in _landmarkDirectories) {
        expect(
          authored.where((path) => path.startsWith('$directory/')),
          isNotEmpty,
          reason:
              'the walk reached no files under $directory/, so nothing '
              'there is format-checked',
        );
      }
    });

    test('it excludes generated output rather than silently missing it', () {
      // The exclusion is deliberate, so it should fail loudly if it ever stops
      // matching anything: an exclusion that excludes nothing is a rule the
      // next reader will not know is dead, and one that quietly starts covering
      // hand-written files would hide them from the check.
      //
      // Both sets come from the one walk above, so this compares the partition
      // the check actually used rather than a second walk that could disagree
      // with it.
      expect(
        generated,
        isNotEmpty,
        reason:
            'nothing matches the generated-file exclusion any more; drop '
            'it rather than leaving a rule that does nothing',
      );
      expect(
        authored.where(_isGenerated),
        isEmpty,
        reason:
            'generated files reached the format check despite the exclusion',
      );
    });
  });
}
