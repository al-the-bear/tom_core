import 'dart:io';

import 'package:test/test.dart';

/// An assertion that cannot fail is worse than no assertion at all.
///
/// The samples verify themselves with `assert` and nothing else — roughly 1800
/// of them, no `expect` anywhere. So a sample's credibility rests entirely on
/// each of those conditions being *capable* of being false. One that is not
/// still prints its section, still reports "✓ … passed", and still exits 0
/// while checking nothing, which is indistinguishable from a sample that
/// works.
///
/// `unnecessary_null_comparison` is the analyzer telling you it found one:
/// `x != null` on an expression the type system already guarantees is
/// non-null. Suppressing it silences the report and keeps the tautology, and
/// because the suppression is an `ignore_for_file` at the top of the file it
/// then covers every later comparison too — including ones added afterwards by
/// someone who never saw the line.
///
/// Nothing in this package needs the lint suppressed. When it fires, the fix is
/// to assert something that could have gone the other way — that the value the
/// call produced is the one that was asked for, that a second call hands back a
/// different instance, that the resource the shutdown was supposed to close is
/// now closed.
void main() {
  // ===========================================================================
  // Assertions that can fail
  // ===========================================================================
  group('assertions can fail', () {
    test('no file suppresses unnecessary_null_comparison', () {
      expect(
        _nullComparisonSuppressions(),
        isEmpty,
        reason: _suppressionReason,
      );
    });

    // A scan that matches nothing reports a clean tree, which is the one
    // failure this kind of test cannot survive — it would keep passing through
    // exactly the suppression it exists to catch. The floor is far below the
    // present count, so it fires on a broken scan rather than on the next file
    // somebody adds or deletes.
    test('the scan reaches the files it claims to check', () {
      expect(_filesToScan(), hasLength(greaterThanOrEqualTo(200)));
    });
  });
}

// -----------------------------------------------------------------------------
// The rule
// -----------------------------------------------------------------------------

/// An `ignore` or `ignore_for_file` comment naming `unnecessary_null_comparison`.
///
/// Both forms are matched: the file-wide one is the shape that actually occurs,
/// but a single-line `// ignore:` hides the same tautology and is no more
/// defensible for being narrower.
final _suppression = RegExp(
  r'//\s*ignore(_for_file)?\s*:[^\n]*unnecessary_null_comparison',
);

/// Returns `'<path>:<line>: <text>'` for every line matching [_suppression].
List<String> _nullComparisonSuppressions() {
  final offenders = <String>[];

  for (final file in _filesToScan()) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (!_suppression.hasMatch(lines[i])) continue;
      offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
    }
  }

  return offenders;
}

// -----------------------------------------------------------------------------
// The scan
// -----------------------------------------------------------------------------

/// Trees holding Dart this package is responsible for.
const _scannedDirectories = ['lib', 'test', 'example', 'tool'];

/// Generated sources carry whatever the generator emits, and are corrected by
/// regenerating rather than by editing.
bool _isGenerated(String path) =>
    path.endsWith('.reflection.dart') || path.endsWith('.g.dart');

List<File> _filesToScan() => [
  for (final directory in _scannedDirectories)
    if (Directory(directory).existsSync())
      for (final entity in Directory(directory).listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            !_isGenerated(entity.path) &&
            // This file states the pattern it refuses, so it matches it.
            !entity.path.endsWith('assertions_can_fail_test.dart'))
          entity,
];

const _suppressionReason =
    'A file suppresses unnecessary_null_comparison. The analyzer only reports '
    'that lint for a comparison the type system has already decided, so the '
    'suppression is preserving an assertion that cannot fail. Assert something '
    'that could have gone the other way instead — what the call produced, not '
    'that it produced anything.';
