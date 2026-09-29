/// The guard that keeps the package `dart format`-clean.
///
/// Formatting drift is invisible to the gate everybody actually runs.
/// `dart analyze` reports nothing about line wrapping, so a file can be
/// analyzer-clean, test-green, reviewed and merged while being unformatted —
/// and nothing says so until somebody runs the formatter and watches it rewrite
/// files they did not touch.
///
/// This package has already paid that bill twice. 127 of its files carried the
/// pre-3.7 short style until they were reformatted wholesale, a 6,000-line
/// commit whose own message records the reason it could not be put off: left
/// alone, *every* future change would drag an arbitrary slice of that reformat
/// into its diff, so a 173-line change arrives as a 6,000-line one and stops
/// being reviewable. Four days later the package drifted again — ten hunks in
/// one example, added under a todo whose stated quality gate was `dart analyze`,
/// which by construction could not see them.
///
/// Two drifts with the same cause are a third one waiting, so the invariant is
/// checked here rather than remembered. The fix when this fails is always the
/// same and never a code change: run `dart format .`.
///
/// The scope is **every Dart file in the package**, derived by walking it, and
/// not a list of directories to keep up to date. The distinction is the whole
/// point of the suite applied to itself: a checker told where to look stops
/// covering the package the moment a file appears somewhere else, and reports
/// nothing while it does — which is exactly how the drift it guards against
/// accumulated. Only two things are left out, each for a stated reason: the
/// dot-directories the package does not author, and generated output.
///
/// **If this fails on a machine where nothing was edited**, the SDK's formatter
/// has changed its output. Reformat the package and commit that as its own
/// whitespace-only change — the same shape as the 127-file commit. Do not relax
/// this test to accommodate it: a formatter change that nobody reformats for is
/// precisely how the first drift accumulated.
library;

import 'dart:io';

import 'package:test/test.dart';

/// The directories a walk of this package must reach, whatever else it finds.
///
/// These are not the *scope* — the scope is every Dart file in the package (see
/// [_packageDartFiles]). They are landmarks: three directories that are
/// structural to the package and cannot legitimately become empty, so a walk
/// that misses one has gone wrong rather than found a smaller package.
const List<String> _landmarkDirectories = ['lib', 'example', 'test'];

/// Machine-written files, which this package does not author and cannot fix.
///
/// A generator that emits unformatted code is the generator's defect, and
/// failing this suite for it would point the reader at the wrong package — the
/// same reasoning that keeps `.reflection.dart` out of the example sweep in
/// `api_reference_coverage_test.dart`.
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
/// Derived by walking the package rather than from a list of directories. The
/// list it replaced — `lib`, `example`, `test` — was complete, but complete by
/// coincidence: a script added under `tool/`, or a `build.dart` at the root,
/// would have been unguarded with nothing saying so. That is this suite's own
/// failure mode one level up — an invariant that holds until a file appears
/// somewhere the checker was never told to look — and a guard against drift
/// should not itself depend on someone remembering to widen it.
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

    test('every file it authors survives `dart format` unchanged', () async {
      // Run the formatter that ships with the SDK running this test, rather
      // than whatever `dart` is first on PATH. The two differ on a machine with
      // several SDKs installed, and a guard that checks a different formatter
      // from the one the developer will run to fix it is worse than none.
      final result = await Process.run(Platform.resolvedExecutable, [
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
    });

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
        hasLength(greaterThan(150)),
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
