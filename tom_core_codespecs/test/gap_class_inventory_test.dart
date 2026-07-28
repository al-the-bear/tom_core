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
  // Disputed: the barrel justifies this as "tom_core has only mechanical
  // enums", while codespecs_mapping.md §4.1 records a domain enum as realised
  // as a plain Dart `enum` with no class here. One arm has to go.
  'domain_enum.dart': '@CsEnum — domain-enum holder (verdict contested)',
  'job_declaration.dart': 'CE-JB — no deployment/ownership envelope',
  'layout_node.dart': 'CE-LO — no base/override two-layer layout model',
  'message_key.dart': 'CE-TX — no closed message-key catalogue',
  'notification_model.dart': 'CE-NT — no channel-choosing layer',
  'report_model.dart': 'CE-RP — no authorable grouped-projection shape',
  'route_flow.dart': 'CE-NV — no route-id registry / screen-flow model',
  'user_settings.dart': 'CE-UP — no user-keyed holder and no persistence seam',
};

void main() {
  group('csrb2: the gap-class inventory is pinned to its §1.1 justifications',
      () {
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
        reason: 'A gap class exists only where tom_core lacks a holder. Adding '
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
      expect(_expectedGapClassFiles.keys, isNot(contains('client_configuration.dart')));
      expect(
        File('lib/tom_core_codespecs.dart').readAsStringSync(),
        isNot(contains("export 'src/client_configuration.dart';")),
      );
    });
  });
}
