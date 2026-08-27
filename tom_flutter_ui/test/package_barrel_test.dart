import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `lib/tom_flutter_ui.dart` promises that "everything is exported from this
/// one library". Nothing used to hold it to that.
///
/// The package barrel is the only path the documentation tells consumers to
/// import, yet most of this suite reaches modules through `src/` instead — so
/// each `export` line was load-bearing for consumers and inert for the tests.
/// Deleting one broke every documented import while the suite stayed green.
///
/// Switching a module's own test onto the barrel fixes that for the module it
/// covers, but only incidentally: the guard is then a side effect of an import
/// somebody could rewrite back. This checks the promise itself, and catches the
/// case no import can — a **newly added** module that was never wired in, whose
/// tests reach it through `src/` and therefore pass.
void main() {
  group('package barrel completeness', () {
    /// An `export 'target';` line, capturing the target path.
    final exportLine = RegExp(r"^export\s+'([^']+)'", multiLine: true);

    /// The module a barrel export belongs to.
    ///
    /// Layout is not uniform and deliberately not normalised here: most
    /// modules keep their barrel inside the directory under a name of their
    /// own choosing (`src/forms/tom_forms.dart`), while
    /// `advanced_container_layout` keeps its barrel beside the directory. Both
    /// shapes name their module in the path segment after `src/`, minus any
    /// `.dart`, which is the only part this needs.
    String moduleOf(String exportPath) =>
        exportPath.split('/')[1].replaceAll('.dart', '');

    test('every module under lib/src is exported from the package barrel', () {
      final barrel = File('lib/tom_flutter_ui.dart').readAsStringSync();
      final exported = exportLine
          .allMatches(barrel)
          .map((m) => moduleOf(m.group(1)!))
          .toSet();

      final modules = Directory('lib/src')
          .listSync()
          .whereType<Directory>()
          .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
          .toSet();

      // Guards the guard: a typo in either path would silently compare two
      // empty sets and pass.
      expect(modules, isNotEmpty, reason: 'lib/src should hold modules');
      expect(exported, isNotEmpty, reason: 'the barrel should export');

      expect(
        modules.difference(exported),
        isEmpty,
        reason: 'a module under lib/src is not reachable through '
            'package:tom_flutter_ui/tom_flutter_ui.dart, so every import in '
            'the documentation for it is broken',
      );
    });

    test('every barrel export resolves to a file that exists', () {
      final barrel = File('lib/tom_flutter_ui.dart').readAsStringSync();
      final targets = exportLine.allMatches(barrel).map((m) => m.group(1)!);

      expect(targets, isNotEmpty);
      for (final target in targets) {
        expect(
          File('lib/$target').existsSync(),
          isTrue,
          reason: 'lib/tom_flutter_ui.dart exports $target, which is missing',
        );
      }
    });
  });
}
