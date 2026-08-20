import 'dart:io';

import 'package:test/test.dart';

/// How this package refers to its own libraries, in both directions.
///
/// Inside `lib/`, a sibling module is reached by a relative path. Outside it —
/// from `test/`, `example/` or `tool/` — the same module is reached by a
/// `package:` URI. Each side has exactly one correct form, and the wrong one
/// resolves anyway, so neither mistake announces itself:
///
/// 1. **`package:tom_core_kernel/src/…` inside `lib/`.** A `package:` URI that
///    reaches into a `src/` tree is what the `implementation_imports` lint
///    exists to refuse; it stays silent here only because the package is
///    importing *itself*. The line therefore reads as a sanctioned instance of
///    a pattern banned everywhere else, and it is the shape a copy-paste into
///    another package carries over — where it is a genuine violation.
/// 2. **`../lib/…` from outside `lib/`.** A relative path into `lib/` gives the
///    file a second library identity, so the same class arrives under two
///    types and `is` checks start failing on values that are obviously the
///    right thing.
///
/// Neither is caught by `dart analyze`: the shared options enable four lint
/// rules and neither `implementation_imports` nor `avoid_relative_lib_imports`
/// is among them. Hence a test.
void main() {
  // ===========================================================================
  // Import convention
  // ===========================================================================
  group('import convention', () {
    test('no library under lib/ imports this package through package:', () {
      expect(_selfSrcImportsInLib(), isEmpty, reason: _selfSrcReason);
    });

    test('nothing outside lib/ reaches into lib/ by relative path', () {
      expect(_relativeLibImports(), isEmpty, reason: _relativeLibReason);
    });
  });
}

// -----------------------------------------------------------------------------
// The two rules
// -----------------------------------------------------------------------------

/// A `package:` URI pointing into this package's own `src/` tree.
///
/// The barrel form (`package:tom_core_kernel/tom_core_kernel.dart` inside
/// `lib/`) is deliberately *not* matched: it names a public entry point rather
/// than reaching past one, so it carries none of the `src/` problem. Six
/// `http_connection` libraries currently use it, and consolidating them is its
/// own piece of work.
final _selfSrcImport = RegExp(r'''package:tom_core_kernel/src/''');

/// A relative path that climbs into `lib/`, e.g. `'../lib/src/…'`.
final _relativeLibImport = RegExp(
  r'''^\s*(?:import|export)\s+['"](?:\.\./)*lib/''',
  multiLine: false,
);

/// Generated sources carry whatever the generator emits, and are corrected by
/// regenerating rather than by editing.
bool _isGenerated(String path) =>
    path.endsWith('.reflection.dart') || path.endsWith('.g.dart');

// -----------------------------------------------------------------------------
// The scans
// -----------------------------------------------------------------------------

/// Returns `'<path>:<line>: <text>'` for every `lib/` line matching
/// [_selfSrcImport].
List<String> _selfSrcImportsInLib() => _scan(['lib'], _selfSrcImport);

/// Returns `'<path>:<line>: <text>'` for every line outside `lib/` matching
/// [_relativeLibImport].
List<String> _relativeLibImports() =>
    _scan(['test', 'example', 'tool'], _relativeLibImport);

List<String> _scan(List<String> directories, RegExp pattern) {
  final offenders = <String>[];

  for (final directory in directories) {
    final dir = Directory(directory);
    if (!dir.existsSync()) continue;

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (!path.endsWith('.dart')) continue;
      // Generated sources carry whatever the generator emits and are corrected
      // by regenerating, never by editing.
      if (_isGenerated(path)) continue;
      // This file states the patterns it refuses, so it matches both.
      if (path.endsWith('import_convention_test.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!pattern.hasMatch(lines[i])) continue;
        offenders.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }
  }

  return offenders;
}

const _selfSrcReason =
    'A library under lib/ imports this package through a package: URI into '
    'src/. Use the relative path to the sibling module instead — the package: '
    'form is what implementation_imports refuses for every other package, and '
    'it only passes here because the package is importing itself.';

const _relativeLibReason =
    'A file outside lib/ reaches into lib/ by relative path. Import it as '
    'package:tom_core_kernel/... instead: a relative path gives the library a '
    'second identity, so the same class arrives under two distinct types.';
