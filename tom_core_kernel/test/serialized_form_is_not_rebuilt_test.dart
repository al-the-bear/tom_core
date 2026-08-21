import 'dart:io';

import 'package:test/test.dart';

/// `TomTimezoned.toString()` already returns the complete serialized form,
/// prefix included. Nothing should build that form a second time.
///
/// The mistake is a natural one to make, because the two halves are both
/// public and both look like ingredients: `getSerializationPrefix()` returns
/// `@X@`, and the value renders as `@X@2024-…`, so joining them reads like
/// assembling the string rather than doubling half of it. What comes out —
/// `@X@@X@2024-06-15T12:00:00.000Z_Z_UTC` — is a string no `parseFromString`
/// in the module will accept, and printing it in a sample teaches the wrong
/// format to every reader who copies it.
///
/// Nothing catches it at runtime unless something tries to read the result
/// back, so a sample that only prints it passes forever. That is what makes
/// the mistake worth a scan: it is silent, it is plausible, and its natural
/// home is example code, which is exactly where a wrong format does the most
/// damage.
///
/// `getSerializationPrefix()` on its own remains entirely legitimate — naming
/// the prefix, switching on it, asserting it. Only joining it to the value it
/// came from is forbidden.
void main() {
  // ===========================================================================
  // The serialized form is not rebuilt
  // ===========================================================================
  group('the serialized form is not rebuilt', () {
    test('no source joins a value\'s prefix to the value itself', () {
      expect(_scan(_rebuildPatterns), isEmpty, reason: _rebuildReason);
    });

    test('no artefact carries a doubled prefix', () {
      expect(_scan([_doubledPrefix]), isEmpty, reason: _doubledReason);
    });

    // A scan matching nothing reports a clean tree whether or not the tree is
    // clean, so both halves are checked: that the patterns recognise the
    // defect, and that the walk reaches the files it claims to cover.
    test('the scan finds the defect it claims to catch', () {
      const offenders = [
        r'print("${dt.getSerializationPrefix()}$dt");',
        r'print("${dt.getSerializationPrefix()}${dt}");',
        r'final s = "${dt.getSerializationPrefix()}${dt.toString()}";',
        r'final s = dt.getSerializationPrefix() + dt.toString();',
      ];
      for (final offender in offenders) {
        expect(
          _rebuildPatterns.any((p) => p.hasMatch(offender)),
          isTrue,
          reason: 'missed "$offender"',
        );
      }
      expect(_doubledPrefix.hasMatch('@X@@X@2024-06-15T12:00:00.000Z'), isTrue);

      // Naming the prefix without joining it to the value is the whole point
      // of the accessor, and must stay allowed.
      const allowed = [
        r'print("Prefix: ${dt.getSerializationPrefix()}");',
        r'assert(dt.getSerializationPrefix() == "@X@");',
        r'final p = dt.getSerializationPrefix();',
        r'print("${dt.getSerializationPrefix()}$other");',
      ];
      for (final line in allowed) {
        expect(
          _rebuildPatterns.any((p) => p.hasMatch(line)),
          isFalse,
          reason: 'wrongly flagged "$line"',
        );
      }
    });

    test('the scan reaches the tree it claims to cover', () {
      expect(_filesToScan(), hasLength(greaterThanOrEqualTo(150)));
      // The accessor has legitimate call sites, and the scan must be looking
      // at the files holding them — otherwise it is walking the wrong tree.
      expect(_scan([_anyPrefixCall]), hasLength(greaterThanOrEqualTo(10)));
    });
  });
}

// -----------------------------------------------------------------------------
// What counts as a violation
// -----------------------------------------------------------------------------

/// A value's prefix joined to that same value.
///
/// The backreference is what makes this precise: `${a.getSerializationPrefix()}
/// $b` joins a prefix to a *different* value, which is a deliberate act with
/// its own meaning, while joining a value's prefix to itself can only be the
/// doubling. Both the interpolated and the `+` spelling are covered, since the
/// formatter rewrites long interpolations into concatenations.
final _rebuildPatterns = <RegExp>[
  RegExp(
    r'\$\{(\w+)\.getSerializationPrefix\(\)\}'
    r'\$\{?\1\b(?:\.toString\(\))?\}?',
  ),
  RegExp(r'(\w+)\.getSerializationPrefix\(\)\s*\+\s*\1\b'),
];

/// `@X@@X@`, `@D@@D@`, `@T@@T@` — the output the doubling produces.
///
/// Catches it wherever it lands: a hand-written literal, a fixture, a sample's
/// expected output pasted into a document.
final _doubledPrefix = RegExp(r'(@[DTX]@)\1');

/// Any call to the accessor, used only to prove the scan is reading the files
/// that contain one.
final _anyPrefixCall = RegExp(r'\.getSerializationPrefix\(\)');

// -----------------------------------------------------------------------------
// The scan
// -----------------------------------------------------------------------------

/// The trees carrying hand-written source and prose.
const _scannedDirectories = ['lib', 'test', 'example', 'doc'];

/// Extensions holding something a reader is expected to copy.
const _scannedExtensions = ['.dart', '.md'];

/// Files exempt from the scan, and why each one is.
///
/// - This file states the patterns it forbids, so it matches all of them.
/// - `CHANGELOG.md` is a history document: recording a defect means being able
///   to show it.
/// - The `.reflection.dart` mirrors and `doc/analyzer_analysis.json` are
///   generated. They restate whatever the sources hold and are corrected by
///   regenerating, never by editing.
bool _isExempt(String path) =>
    path.endsWith('serialized_form_is_not_rebuilt_test.dart') ||
    path.endsWith('CHANGELOG.md') ||
    path.endsWith('.reflection.dart') ||
    path.endsWith('analyzer_analysis.json');

/// Returns `'<path>:<line>: <text>'` for every line matching [patterns].
List<String> _scan(List<RegExp> patterns) {
  final offenders = <String>[];

  for (final file in _filesToScan()) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (!patterns.any((p) => p.hasMatch(lines[i]))) continue;
      offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
    }
  }

  return offenders;
}

/// Every file in scope.
List<File> _filesToScan() => [
  for (final directory in _scannedDirectories)
    if (Directory(directory).existsSync())
      for (final entity in Directory(directory).listSync(recursive: true))
        if (entity is File &&
            _scannedExtensions.any(entity.path.endsWith) &&
            !_isExempt(entity.path))
          entity,
];

const _rebuildReason =
    'A value\'s serialization prefix is joined to that same value. '
    '`toString()` already carries the prefix, so the result is a doubled '
    'prefix that no `parseFromString` accepts. Print `toString()` alone; use '
    '`getSerializationPrefix()` only where the prefix itself is the subject.';

const _doubledReason =
    'A doubled serialization prefix reached an artefact. It is not a form any '
    'parser in the module accepts, so wherever it came from produced an '
    'unreadable string.';
