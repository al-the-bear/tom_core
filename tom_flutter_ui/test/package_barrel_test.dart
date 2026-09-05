import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/export_surface.dart';

/// `lib/tom_flutter_ui.dart` promises that "everything is exported from this
/// one library". Nothing used to hold it to that.
///
/// The package barrel is the only path the documentation tells consumers to
/// import, and this suite now reaches the package the same way — but for a
/// long time most of it went through `src/` instead, so each `export` line was
/// load-bearing for consumers and inert for the tests. Deleting one broke
/// every documented import while the suite stayed green.
///
/// Three guards, because none subsumes another:
///
/// - **Completeness** — every module under `lib/src` is exported, and every
///   export resolves. This catches what no import can: a newly added module
///   that was never wired in, whose own tests reach it through `src/` and
///   therefore pass.
/// - **Discipline** — nothing under `test/` or `example/` reaches past the
///   barrel, by `import` or by `export`. Switching a module's test onto the
///   barrel makes that module's exports load-bearing, but only incidentally:
///   the guard is a side effect of an import somebody could rewrite back, and
///   a *new* file starts from whatever its author copied. Checking the
///   property directly is what makes it stay true.
/// - **Namespacing** — every public type the barrel carries is `Tom`- or
///   `Acl`-prefixed. The first two guards are about what the barrel exports;
///   this one is about what those exports are *called*, which is a separate
///   promise to the same consumer.
///
/// The first two mean a symbol dropped from a module barrel now fails the
/// suite rather than reaching a consumer first; the third means a symbol added
/// to one cannot quietly take an ordinary name in the consumer's namespace.
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
        reason:
            'a module under lib/src is not reachable through '
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
    /// Files allowed to reach `package:tom_flutter_ui/src/`, and why.
    ///
    /// A reason is required rather than decorative. The exemption is only
    /// defensible when the barrel *cannot* express what the file needs, and
    /// writing that down is what stops the map from becoming the place
    /// inconvenient files go.
    /// An exemption licenses only the libraries the barrel genuinely cannot
    /// offer: the check below re-derives that from the export graph, so a file
    /// on this list still cannot reach an *exported* library by path. Without
    /// it the exemption is granted per file, and the first unexported import
    /// carries the rest of that file's imports in behind it — which is exactly
    /// how `tom_file_picker_registry.dart`, exported all along through
    /// `src/forms/tom_forms.dart`, went unnoticed here.
    const exempt = <String, String>{
      'test/forms/files/file_opener_test.dart':
          'asserts that the two halves of a conditional import agree with the '
          'half actually resolved, which needs all three by path; the '
          'file_opener trio is deliberately not exported, being internal '
          'plumbing behind TomFilePickers.toFileRef',
    };

    /// Every `.dart` file under `test/` and `example/`, generated output aside.
    ///
    /// `example/` is held to the same rule as `test/`, for a stronger reason:
    /// an example is code a consumer copies, so one reaching into `src/` hands
    /// them an import they cannot write themselves. It is clean today, and
    /// scanning it is what keeps it so.
    ///
    /// `*.reflection.dart` is emitted by the reflection generator, which
    /// writes prefixed `src/` imports by design. Editing it would be undone by
    /// the next build, so it is skipped by shape rather than listed above —
    /// there is nothing for a reader to weigh.
    Iterable<File> scannedSources() => ['test', 'example']
        .map(Directory.new)
        .expand((d) => d.listSync(recursive: true))
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('.reflection.dart'));

    /// A *directive* naming `lib/src`, not the mere mention of one.
    ///
    /// Anchored to the start of a line because a directive can only appear at
    /// top level: matching the bare string would flag this file, whose own
    /// pattern and failure message have to name the thing they forbid.
    ///
    /// `export` counts as well as `import`, and is the more dangerous of the
    /// two. A support file that re-exports an internal launders it: every test
    /// then reaches that internal through an ordinary relative import of the
    /// support file, and an import-only rule sees nothing wrong anywhere.
    /// Nothing else covers this — `implementation_imports`, enabled in
    /// `analysis_options.yaml`, governs *other* packages' `src/`, so a
    /// re-export within this package analyzes clean.
    ///
    /// The third spelling, a relative reach like `../lib/src/x.dart`, is
    /// deliberately not matched here: `avoid_relative_lib_imports` arrives
    /// with `flutter_lints` and already rejects it. Restating it would put one
    /// rule in two places that can disagree.
    final srcDirective = RegExp(
      '^(?:import|export) [\'"]package:tom_flutter_ui/src/',
      multiLine: true,
    );

    test('no test or example file reaches past the barrel', () {
      final sources = scannedSources().toList();
      // Guards the guard: a wrong root would scan nothing and pass.
      expect(
        sources,
        isNotEmpty,
        reason: 'test/ and example/ should hold dart files',
      );

      final offenders =
          sources
              .map((f) => f.path)
              .where((p) => !exempt.containsKey(p))
              .where((p) => srcDirective.hasMatch(File(p).readAsStringSync()))
              .toList()
            ..sort();

      expect(
        offenders,
        isEmpty,
        reason:
            'these files reach into lib/src, so they would stay green if '
            'the symbol they use were dropped from the module barrel or the '
            'package barrel — the break would surface in a consumer instead. '
            'Import package:tom_flutter_ui/tom_flutter_ui.dart. If the barrel '
            'genuinely cannot express what the file needs, add it to `exempt` '
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
          reason:
              '${entry.key} is exempted from the barrel rule but does not '
              'exist; drop the entry',
        );
        expect(
          srcDirective.hasMatch(file.readAsStringSync()),
          isTrue,
          reason:
              '${entry.key} no longer reaches lib/src, so its exemption '
              'is stale; drop the entry',
        );
        expect(entry.value, isNotEmpty);
      }
    });

    test('an exempt file reaches only libraries the barrel cannot offer', () {
      final reachable = barrelReachableFiles();
      // Guards the guard: a barrel that resolved to nothing would find every
      // reach unexported and pass.
      expect(
        reachable.length,
        greaterThan(1),
        reason: 'the barrel should export something',
      );

      final srcImport = RegExp(
        '^(?:import|export) [\'"](package:tom_flutter_ui/src/[^\'"]+)',
        multiLine: true,
      );
      final holdouts = <String>[];
      for (final path in exempt.keys) {
        for (final m in srcImport.allMatches(File(path).readAsStringSync())) {
          final target = m
              .group(1)!
              .replaceFirst('package:tom_flutter_ui/', 'lib/');
          if (reachable.contains(target)) holdouts.add('  $path -> $target');
        }
      }

      expect(
        holdouts..sort(),
        isEmpty,
        reason:
            'these reaches are exempt but did not need to be — the library is '
            'already exported through package:tom_flutter_ui/tom_flutter_ui.'
            'dart, so importing it by path buys nothing and loses the '
            'regression the barrel rule exists to catch:\n\n'
            '${holdouts.join('\n')}\n\n'
            'Import the barrel for these; keep the exemption for the rest',
      );
    });
  });

  group("the barrel's public surface is namespaced", () {
    /// The public types the barrel exports without a `Tom` or `Acl` prefix.
    ///
    /// A consumer writes one import and receives every public name this
    /// package exports directly into their own namespace. The prefix is what
    /// keeps that from being an imposition: `Tom` for the package at large,
    /// `Acl` inside `advanced_container_layout`, which is a deliberate second
    /// namespace for a subsystem with its own vocabulary.
    ///
    /// That the hazard is real and not hypothetical is easy to check: the
    /// `file_picker` package exports a class called `FilePicker`, and five
    /// packages in this workspace import it. `Validators`, `ValidationResult`,
    /// `FileRef` and `RowAlignment` are names a consumer is equally likely to
    /// have of their own.
    ///
    /// The names below are listed one by one rather than allowed by pattern
    /// because each is a rename somebody has to perform, not a category the
    /// rule was wrong to cover. The set is a ratchet: it may shrink and never
    /// grow, because a name cannot enter it without an author editing this
    /// list and reading this paragraph. Its size is pinned below, so removing
    /// an entry is a deliberate edit in two places rather than a silent one.
    const knownUnprefixed = <String>{
      // forms/validation — the result hierarchy and its helpers.
      'ValidationResult',
      'ValidationSuccess',
      'ValidationError',
      'ValidationPristine',
      'ValidationPending',
      'SlowValidator',
      'Validators',
      'FormValidationError',
      // forms/events — the eleven event types of one sealed family.
      'FieldAuthChangedEvent',
      'FieldBoundEvent',
      'FieldCommittedEvent',
      'FieldValidatedEvent',
      'FieldValueChangedEvent',
      'FormBoundEvent',
      'FormDiscardedEvent',
      'FormSavedEvent',
      'FormValidatedEvent',
      'ListItemAddedEvent',
      'ListItemRemovedEvent',
      'ListItemReorderedEvent',
      // forms/style — the placement enums and the two style-valued extras.
      'ActionIconPlacement',
      'DescriptionPlacement',
      'ErrorPlacement',
      'LabelPlacement',
      'RequiredIndicator',
      'StringInputVariant',
      // forms — field payloads, sources and the family selector.
      'FileRef',
      'NumRange',
      'TimeRange',
      'CurrencyFormatProfile',
      'SelectableItem',
      'StaticSelectableSource',
      'FormFieldFamily',
      'FormFieldFamilyKind',
      'UnsavedChangesChoice',
      // resource_auth — the theme adapters.
      'AllColorsAdapter',
      'AllIconsAdapter',
      'CupertinoOnlyColorAdapter',
      'CupertinoOnlyIconAdapter',
      'MaterialOnlyColorAdapter',
      'MaterialOnlyIconAdapter',
      // advanced_container_layout — an ACL type that took neither prefix.
      'RowAlignment',
    };

    /// Every public type a consumer receives from the package barrel.
    Set<String> barrelSurface() {
      final surface = exportSurfaces()['lib/tom_flutter_ui.dart'];
      expect(
        surface,
        isNotNull,
        reason: 'the package barrel should be among the walked sources',
      );
      return surface!.where((n) => !n.startsWith('_')).toSet();
    }

    test('every public type the barrel exports is Tom- or Acl-prefixed', () {
      final surface = barrelSurface();
      // Guards the guard: a walk that resolved nothing would compare an empty
      // set and pass. The floor sits far below the package's real export
      // count and still orders of magnitude above a broken walk, so it holds
      // without needing to be recounted.
      expect(
        surface.length,
        greaterThan(500),
        reason: 'the export-surface walk should reach the whole package',
      );

      final homes = typeHomes();
      final offenders =
          surface
              .where((n) => !n.startsWith('Tom') && !n.startsWith('Acl'))
              .where((n) => !knownUnprefixed.contains(n))
              .map((n) => '  $n — ${homes[n] ?? 'declared outside lib/'}')
              .toList()
            ..sort();

      expect(
        offenders,
        isEmpty,
        reason:
            'these public types reach a consumer through '
            'package:tom_flutter_ui/tom_flutter_ui.dart under a name that '
            'claims no namespace, so they collide with whatever the consumer '
            'called their own:\n\n${offenders.join('\n')}\n\n'
            'Prefix them Tom (or Acl, inside advanced_container_layout). '
            'Do not add to `knownUnprefixed` — that set is a ratchet being '
            'emptied, not a place to put new names',
      );
    });

    test('every entry in the known-unprefixed set is still real', () {
      // An entry whose type was renamed or unexported reads as licence for a
      // name nobody is using, and makes the set meaningless as a measure of
      // what is left to do.
      //
      // The size is pinned so the ratchet cannot be loosened by accident:
      // adding a name fails here, and removing one is a two-line edit that
      // says out loud which direction it went.
      expect(
        knownUnprefixed,
        hasLength(42),
        reason:
            'the known-unprefixed set changed size. Fewer is the goal — lower '
            'this number. More is not: prefix the type instead',
      );

      final surface = barrelSurface();
      for (final name in knownUnprefixed) {
        expect(
          surface,
          contains(name),
          reason:
              '$name is listed as a known-unprefixed export but the barrel no '
              'longer exports it; drop the entry',
        );
        expect(
          name.startsWith('Tom') || name.startsWith('Acl'),
          isFalse,
          reason: '$name is prefixed now; drop the entry',
        );
      }
    });
  });
}
