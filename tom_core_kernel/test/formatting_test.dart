/// The guard that keeps the package `dart format`-clean.
///
/// Formatting drift is invisible to the gate everybody actually runs.
/// `dart analyze` reports nothing about line wrapping, so a file can be
/// analyzer-clean, test-green, reviewed and merged while being unformatted —
/// and nothing says so until somebody runs the formatter and watches it rewrite
/// files they did not touch.
///
/// This package has already paid that bill. 83 % of it was unformatted — 97 of
/// 117 example files and 34 of 56 under `lib/` — which is what made the
/// reformat impossible to do in passing: a change that ran the formatter as a
/// side effect arrived with its substantive edit buried among a hundred
/// reflowed files, so the formatter got avoided, so the drift grew. It took two
/// wholesale commits to clear, one for `example/` and `lib/` and one for
/// `test/`.
///
/// Eighteen days later it drifted again, in six example files, all of them
/// rewritten under todos whose stated quality gate was `dart analyze` — which
/// by construction could not see it. That second drift is the reason this file
/// exists: the state had been restored by hand and was being held by hand, and
/// the first agent to touch the package undid part of it without being told.
///
/// The fix when this fails is always the same and never a code change: run
/// `dart format .`.
///
/// The scope is **every Dart file in the package**, derived by walking it, and
/// not a list of directories to keep up to date. A checker told where to look
/// stops covering the package the moment a file appears somewhere else, and
/// reports nothing while it does. Only two things are left out, each for a
/// stated reason: the dot-directories the package does not author, and
/// generated output.
///
/// **If this fails on a machine where nothing was edited**, the SDK's formatter
/// has changed its output. Reformat the package and commit that as its own
/// whitespace-only change. Do not relax this test to accommodate it: a
/// formatter change that nobody reformats for is how the first drift
/// accumulated.
///
/// The shape is `tom_core_server/test/formatting_test.dart`, which solved the
/// same problem in the sibling package first. Kept deliberately identical, down
/// to which files are excluded, so that the two packages cannot answer the same
/// question differently.
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
/// failing this suite for it would point the reader at the wrong package.
///
/// `version.versioner.dart` is generated too but is *not* excluded, matching
/// the sibling guard: its generator emits formatted output, so holding it to
/// the same rule costs nothing and would report a real regression if that
/// changed.
bool _isGenerated(String path) => path.endsWith('.reflection.dart');

/// Every Dart file in the package, generated ones included, as paths relative
/// to the package root.
///
/// Derived by walking the package rather than from a list of directories, so a
/// script added under `tool/`, or a `build.dart` at the root, is guarded the
/// day it appears rather than the day someone remembers to widen this.
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
      // never opened. So the sweep has to prove it ran.
      //
      // Stated as a floor and a set of landmarks rather than an exact count,
      // because the count is supposed to move — every new file adds one — and a
      // test that must be edited whenever the thing it measures grows correctly
      // is a test that will be edited without being read.
      expect(
        authored,
        hasLength(greaterThan(200)),
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
