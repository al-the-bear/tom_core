/// Every module readme names the whole surface its module exports.
///
/// A module readme opens with a **Key types** table, and a reader takes that
/// table for the module's reference surface. It is worth keeping true and it
/// does not stay true by itself: adding a type to a module is a one-line edit
/// away from leaving the table behind, and nothing about the omission is
/// visible from either side alone. Six of the kernel's modules had drifted at
/// once — `security` was missing 23 of 47 names, `observable` 14 of 33 — and
/// the drift was found by a hand-written scan rather than by anything standing.
///
/// The surface is read from the **package barrel**, not from the module
/// directory. A file that exists but is not exported is not public, and
/// demanding a readme document it would be wrong; conversely the barrel is what
/// a consumer actually sees. `lib/tom_core_kernel.dart` exports
/// `src/tombase/<module>/<file>.dart` a file at a time, so grouping those by
/// module gives each module's public files exactly.
///
/// A name counts only when it appears **as a whole word inside an inline code
/// span**, which is how these tables write API. A plain substring search passes
/// vacuously — and an abbreviation is what hid part of this drift in the first
/// place: `observable`'s table read `TomNString / TomNInt / TomND…`, which
/// names two of five nullable cells and leaves a reader unable to tell whether
/// the one they want exists. The ellipsis satisfied a reader and no check.
library;

import 'dart:io';

import 'package:test/test.dart';

/// Modules the package barrel exports that ship no `readme.md`.
///
/// Empty, and the second test below keeps it that way in both directions: a
/// module that loses its readme has to be named here with a reason, and one
/// that gains a readme has to be removed. An entry is therefore always a live
/// admission rather than a stale exemption nobody revisits.
const _withoutReadme = <String>{};

final _declaration = RegExp(
  r'^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|mixin\s+)*'
  r'(?:class|mixin|enum|extension|typedef)\s+(\w+)',
  multiLine: true,
);

final _barrelExport = RegExp(
  r"^export\s+'(src/tombase/[^']+)'",
  multiLine: true,
);

final _inlineCode = RegExp(r'`([^`\n]+)`');

/// The public files the package barrel exports, grouped by module directory.
Map<String, List<String>> _filesByModule() {
  final barrel = File('lib/tom_core_kernel.dart').readAsStringSync();
  final byModule = <String, List<String>>{};
  for (final match in _barrelExport.allMatches(barrel)) {
    final parts = match.group(1)!.split('/');
    if (parts.length < 4) continue;
    byModule.putIfAbsent(parts[2], () => []).add('lib/${match.group(1)}');
  }
  return byModule;
}

/// Every public type declared in [files].
Set<String> _publicTypes(List<String> files) => {
  for (final path in files.where((p) => File(p).existsSync()))
    for (final match in _declaration.allMatches(File(path).readAsStringSync()))
      if (!match.group(1)!.startsWith('_')) match.group(1)!,
};

/// Whether [readme] names [symbol] as API rather than merely containing it.
bool _names(String readme, String symbol) {
  final code = _inlineCode.allMatches(readme).map((m) => m.group(1)!).join(' ');
  return RegExp(r'(?<!\w)' + RegExp.escape(symbol) + r'(?!\w)').hasMatch(code);
}

void main() {
  final byModule = _filesByModule();

  test('the scan finds the modules it claims to check', () {
    // A barrel this failed to parse would leave every check below with nothing
    // to disagree with, which is how a derived test passes while reading
    // nothing.
    expect(
      byModule.length,
      greaterThanOrEqualTo(15),
      reason:
          'found ${byModule.length} modules in the package barrel — the '
          'export pattern is broken, not the barrel',
    );
    expect(byModule.keys, contains('security'));
  });

  test(
    'every exported module ships a readme, or is listed as not doing so',
    () {
      final missing = byModule.keys
          .where((m) => !File('lib/src/tombase/$m/readme.md').existsSync())
          .toSet();

      expect(
        missing.difference(_withoutReadme).toList()..sort(),
        isEmpty,
        reason:
            'these modules are exported from the package barrel and have no '
            'readme.md. Write one, or add it to _withoutReadme with the reason',
      );
      expect(
        _withoutReadme.difference(missing).toList()..sort(),
        isEmpty,
        reason: '_withoutReadme names modules that now have a readme',
      );
    },
  );

  group('module readmes name the surface their module exports', () {
    for (final module in byModule.keys.toList()..sort()) {
      if (_withoutReadme.contains(module)) continue;

      test('$module/readme.md names every public type', () {
        final types = _publicTypes(byModule[module]!);
        expect(
          types,
          isNotEmpty,
          reason:
              'found no public types in $module — the declaration pattern is '
              'broken, not the readme',
        );

        final readme = File(
          'lib/src/tombase/$module/readme.md',
        ).readAsStringSync();
        final absent = types.where((t) => !_names(readme, t)).toList()..sort();

        expect(
          absent,
          isEmpty,
          reason:
              'lib/tom_core_kernel.dart exports these public types from '
              '$module and lib/src/tombase/$module/readme.md never names them '
              'in a code span: $absent',
        );
      });
    }
  });
}
