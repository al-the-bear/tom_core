import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `lib/tom_flutter_ui.dart` promises that "everything is exported from this
/// one library". Nothing used to hold it to that.
///
/// The package barrel is the only path the documentation tells consumers to
/// import, and this suite now reaches the package the same way — but for a
/// long time most of it went through `src/` instead, so each `export` line was
/// load-bearing for consumers and inert for the tests. Deleting one broke
/// every documented import while the suite stayed green.
///
/// Two guards, because neither subsumes the other:
///
/// - **Completeness** — every module under `lib/src` is exported, and every
///   export resolves. This catches what no import can: a newly added module
///   that was never wired in, whose own tests reach it through `src/` and
///   therefore pass.
/// - **Discipline** — no test reaches past the barrel. Switching a module's
///   test onto the barrel makes that module's exports load-bearing, but only
///   incidentally: the guard is a side effect of an import somebody could
///   rewrite back, and a *new* test file starts from whatever its author
///   copied. Checking the property directly is what makes it stay true.
///
/// Together they mean a symbol dropped from a module barrel now fails the
/// suite rather than reaching a consumer first.
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

  group('the suite reaches the package the way consumers do', () {
    /// Files allowed to import `package:tom_flutter_ui/src/`, and why.
    ///
    /// A reason is required rather than decorative. The exemption is only
    /// defensible when the barrel *cannot* express what the file needs, and
    /// writing that down is what stops the map from becoming the place
    /// inconvenient files go.
    const exempt = <String, String>{
      'test/forms/files/file_opener_test.dart':
          'asserts that the two halves of a conditional import agree with the '
              'half actually resolved, which needs all three by path; the '
              'file_opener trio is deliberately not exported, being internal '
              'plumbing behind TomFilePickers.toFileRef',
    };

    /// Every `.dart` file under `test/`, generated output aside.
    ///
    /// `*.reflection.dart` is emitted by the reflection generator, which
    /// writes prefixed `src/` imports by design. Editing it would be undone by
    /// the next build, so it is skipped by shape rather than listed above —
    /// there is nothing for a reader to weigh.
    Iterable<File> testSources() => Directory('test')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('.reflection.dart'));

    /// An import *directive* naming `lib/src`, not the mere mention of one.
    ///
    /// Anchored to the start of a line because a directive can only appear at
    /// top level: matching the bare string would flag this file, whose own
    /// pattern and failure message have to name the thing they forbid.
    final srcImport =
        RegExp('^import [\'"]package:tom_flutter_ui/src/', multiLine: true);

    test('no test file imports past the barrel', () {
      final sources = testSources().toList();
      // Guards the guard: a wrong root would scan nothing and pass.
      expect(sources, isNotEmpty, reason: 'test/ should hold dart files');

      final offenders = sources
          .map((f) => f.path)
          .where((p) => !exempt.containsKey(p))
          .where((p) => srcImport.hasMatch(File(p).readAsStringSync()))
          .toList()
        ..sort();

      expect(
        offenders,
        isEmpty,
        reason: 'these tests reach into lib/src, so they would stay green if '
            'the symbol they use were dropped from the module barrel or the '
            'package barrel — the break would surface in a consumer instead. '
            'Import package:tom_flutter_ui/tom_flutter_ui.dart. If the barrel '
            'genuinely cannot express what the test needs, add it to `exempt` '
            'above with the reason',
      );
    });

    test('every exemption is still real', () {
      // An entry left behind after its file was deleted or rewritten reads as
      // a standing licence that nobody granted, and quietly widens the rule
      // the next time somebody copies from it.
      for (final entry in exempt.entries) {
        final file = File(entry.key);
        expect(
          file.existsSync(),
          isTrue,
          reason: '${entry.key} is exempted from the barrel rule but does not '
              'exist; drop the entry',
        );
        expect(
          srcImport.hasMatch(file.readAsStringSync()),
          isTrue,
          reason: '${entry.key} no longer imports lib/src, so its exemption '
              'is stale; drop the entry',
        );
        expect(entry.value, isNotEmpty);
      }
    });
  });
}
