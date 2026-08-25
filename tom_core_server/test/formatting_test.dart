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
/// **If this fails on a machine where nothing was edited**, the SDK's formatter
/// has changed its output. Reformat the package and commit that as its own
/// whitespace-only change — the same shape as the 127-file commit. Do not relax
/// this test to accommodate it: a formatter change that nobody reformats for is
/// precisely how the first drift accumulated.
library;

import 'dart:io';

import 'package:test/test.dart';

/// The directories whose Dart files this package authors.
///
/// `.dart_tool` is excluded by the formatter itself, so it is not listed.
const List<String> _sourceDirectories = ['lib', 'example', 'test'];

/// Machine-written files, which this package does not author and cannot fix.
///
/// A generator that emits unformatted code is the generator's defect, and
/// failing this suite for it would point the reader at the wrong package — the
/// same reasoning that keeps `.reflection.dart` out of the example sweep in
/// `api_reference_coverage_test.dart`.
bool _isGenerated(String path) => path.endsWith('.reflection.dart');

/// Every hand-written Dart file in the package, as paths relative to its root.
List<String> _authoredDartFiles() {
  final files = <String>[
    for (final directory in _sourceDirectories)
      ...Directory(directory)
          .listSync(recursive: true)
          .whereType<File>()
          .map((entity) => entity.path)
          .where((path) => path.endsWith('.dart'))
          .where((path) => !_isGenerated(path)),
  ];
  files.sort();
  return files;
}

void main() {
  group('the package is formatted', () {
    final authored = _authoredDartFiles();

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
      // Stated as a floor and a set of representatives rather than an exact
      // count, because the count is supposed to move — every new file adds one —
      // and a test that must be edited whenever the thing it measures grows
      // correctly is a test that will be edited without being read.
      expect(
        authored,
        hasLength(greaterThan(150)),
        reason:
            'the walk found far fewer files than the package contains, so '
            'the format check above swept almost nothing',
      );
      for (final directory in _sourceDirectories) {
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
      final generated = [
        for (final directory in _sourceDirectories)
          ...Directory(directory)
              .listSync(recursive: true)
              .whereType<File>()
              .map((entity) => entity.path)
              .where(_isGenerated),
      ];
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
