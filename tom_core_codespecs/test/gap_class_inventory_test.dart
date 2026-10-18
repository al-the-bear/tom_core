import 'dart:io';

import 'package:test/test.dart';

/// Every gap-class file this package is allowed to ship, and the part that
/// justifies it.
///
/// **Why this is pinned.** A gap class exists only where `tom_core` genuinely
/// lacks a holder (`codespecs_mapping.md` §1.1 pillar (b)). That is a *verdict*
/// about another package, so it can go stale without anything here changing:
/// when `tom_core` grows the holder, the part flips to reuse and the gap class
/// silently becomes a second, worse holder for the same part. CE-CC drifted that
/// way — `TomBaseClientConfiguration` landed in `tom_core_flutter` while a
/// `TomClientConfiguration` was still exported here.
///
/// Pinning the inventory does not detect the flip on its own, but it makes
/// adding or removing a gap class an edit someone has to justify here, next to
/// the part it claims. The granularity is the file because that is how this
/// package is organised: one gap-class subject per file.
///
/// This map records what the package **ships** and why each file was authored.
/// It is not a claim that every verdict is settled — where
/// `codespecs_mapping.md` §4.1 and a file here disagree, the disagreement is
/// noted on the entry.
const Map<String, String> _expectedGapClassFiles = {
  'client_application.dart': 'CE-CL — no client-application descriptor root',
  'job_declaration.dart': 'CE-JB — no deployment/ownership envelope',
  'layout_node.dart': 'CE-LO — no base/override two-layer layout model',
  'message_key.dart': 'CE-TX — no closed message-key catalogue',
  'notification_model.dart': 'CE-NT — no channel-choosing layer',
  'operation_binding.dart':
      'CE-API — no second binding of an already-named operation',
  'report_model.dart': 'CE-RP — no authorable grouped-projection shape',
  'route_flow.dart': 'CE-NV — no route-id registry / screen-flow model',
};

void main() {
  group('csrb2: the gap-class inventory is pinned to its justifications', () {
    test('lib/src holds exactly the justified gap-class files', () {
      final files = Directory('lib/src')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((name) => name.endsWith('.dart'))
          .toSet();

      expect(
        files,
        equals(_expectedGapClassFiles.keys.toSet()),
        reason:
            'A gap class exists only where tom_core lacks a holder. Adding '
            'or removing one means a part changed its reuse verdict — state '
            'the part in _expectedGapClassFiles and update '
            'codespecs_mapping.md §4.1 to match.',
      );
    });

    test('the barrel exports every gap-class file and nothing else', () {
      final exported = File('lib/tom_core_codespecs.dart')
          .readAsLinesSync()
          .where((line) => line.startsWith("export 'src/"))
          .map((line) => line.split('/').last.split("'").first)
          .toSet();

      expect(exported, equals(_expectedGapClassFiles.keys.toSet()));
    });

    test('CE-CC has no gap class — it reuses TomBaseClientConfiguration', () {
      // The specific drift this inventory was introduced to close. CE-CC is a
      // reuse verdict (codespecs_mapping.md §4.1, §5.16): the (client app,
      // machine) holder is tom_core_flutter's TomBaseClientConfiguration with
      // TomSetting<T> and TomClientConfigurationStore.
      expect(
        _expectedGapClassFiles.keys,
        isNot(contains('client_configuration.dart')),
      );
      expect(
        File('lib/tom_core_codespecs.dart').readAsStringSync(),
        isNot(contains("export 'src/client_configuration.dart';")),
      );
    });

    test(
      'csrb7: domain enums have no gap class — they are a plain Dart enum',
      () {
        // The domainEnum member kind is realised as a plain Dart `enum`, so
        // there is no class to build on. A holder would also give value
        // labels a second home, and a value label is CE-TX copy — it belongs
        // to the text plane, which already owns exactly one home for it.
        expect(
          _expectedGapClassFiles.keys,
          isNot(contains('domain_enum.dart')),
        );
        expect(
          File('lib/tom_core_codespecs.dart').readAsStringSync(),
          isNot(contains('TomDomainEnum')),
        );
      },
    );

    test(
      'tspcmp2: CE-UP has no gap class — it reuses the preferences plane',
      () {
        // The same drift in shape as CE-CC's. A TomUserSettings holder and a
        // TomUserSettingsStore seam would presume tom_core has neither, but
        // tom_core_server's TomUserPreferences (over
        // TomUserPreferenceRepository, principal-scoped) is the seam — and no
        // holder is needed either, because a setting's type and default sit on
        // the annotated member and its key on @CsUserSetting's own argument.
        expect(
          _expectedGapClassFiles.keys,
          isNot(contains('user_settings.dart')),
        );
        final barrel = File('lib/tom_core_codespecs.dart').readAsStringSync();
        expect(barrel, isNot(contains("export 'src/user_settings.dart';")));
        expect(barrel, isNot(contains('TomUserSettingsStore')));
      },
    );
  });

  group('tcinc934: the package is dependency-free', () {
    // **Why this is pinned.** Dependency-freedom here is an invariant, not a
    // convenience of small size: it is the premise two shipped decisions rest
    // on. TomReportResult does not extend tom_core_server's TomTabularResult
    // (report_model.dart), and a job's CE-RP targets ride
    // @CsJob(targetReports:) in tom_code_specs rather than TomJobDeclaration
    // (job_declaration.dart) — both because taking a tom_core_* dependency
    // here was not an option. A single added import would retract both without
    // touching either file, so the rule is checked rather than restated. A
    // candidate gap class needing a tom_core_* type is not a gap class; it
    // belongs in the package whose type it needs.

    test('pubspec.yaml declares no dependencies', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(
        pubspec,
        contains(RegExp(r'^dependencies:\s*\{\}\s*$', multiLine: true)),
        reason:
            'Adding a dependency retracts the TomReportResult and '
            'TomJobDeclaration placement decisions. Move the class that '
            'needs the type into the package that owns it instead.',
      );
    });

    test('nothing under lib/ imports beyond dart:core', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        for (final line in entity.readAsLinesSync()) {
          if (line.startsWith('import ')) {
            offenders.add('${entity.path}: $line');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'dart:core is implicit, so a dependency-free package has no '
            'import directive at all. Each entry above is a retraction of '
            'the placement decisions this invariant carries.',
      );
    });
  });

  group('tcinc936: the README enumerates every public declaration', () {
    // **Why this is pinned.** The README's per-part table is this package's
    // only inventory of what it ships, and the CE-LO row silently dropped
    // TomLayoutNode — the sealed base that types TomLayoutContainerNode's
    // children and TomLayoutModel.findNode's return. A reader working from the
    // README could not see either. Omitting one name from a parenthesised list
    // is invisible on review, which is why it survived: an inventory compared
    // by eye is an inventory that drifts.
    //
    // Only the forward direction is checkable. The README legitimately names
    // types from other packages (TomGroupedSelect, AclComponent, CsRoleRef),
    // so "every name in the README is ours" is false by design; "every symbol
    // of ours is in the README" is the invariant that holds.

    test('every public top-level declaration is named in README.md', () {
      final declaration = RegExp(
        r'^(?:abstract |final |sealed |base |interface |mixin )*'
        r'(?:class|enum|extension|typedef|mixin) ([A-Za-z_]\w*)',
      );
      final readme = File('README.md').readAsStringSync();
      final missing = <String>[];

      for (final entity in Directory('lib/src').listSync()) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final match = declaration.firstMatch(lines[i]);
          if (match == null) continue;
          final name = match.group(1)!;
          if (name.startsWith('_')) continue;
          if (!readme.contains(name)) {
            missing.add('$name (${entity.path}:${i + 1})');
          }
        }
      }

      expect(
        missing,
        isEmpty,
        reason:
            'Each symbol above is exported but absent from the README '
            'inventory. Add it to its part row, next to the symbols it '
            'relates to, rather than to the end of the list.',
      );
    });
  });
}
