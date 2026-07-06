/// Drift guard: the externalized text-resource tree (RC-24) and the gradable
/// item field set must name the same set of `todo.item.*` fields.
///
/// Three artifacts have to agree on the scope/form/field keys — the gradable
/// item key set (`todo.item.<field>`, the wire contract each side addresses),
/// the app server's `assets/resources_app.json` text tree, and the auth
/// server's `tom_resource_grant` matrix seed. This test pins the **app
/// server's** half: the field segments the resource JSON labels under
/// `todo.item.*` are exactly the gradable field tokens — no field missing a
/// label, and no stray label for a field the domain does not grade.
///
/// (G-RES-6: addressing is by scope + `tomId`, so there is no catalogue class;
/// steps 21/24/26 derive the gradable set from reflection/the resource bundle.
/// Until then the expected set is the inline literals below.)
///
/// The existing `resource_bundle_endpoint_test.dart` already asserts the *first*
/// direction (every gradable field has a label key). This test adds the *reverse*
/// direction — a renamed or typo'd `todo.item.*` key in the JSON that no longer
/// matches a gradable field would pass the one-directional check but fail here —
/// so the two together catch drift either way. Pure text, no database.
///
/// The auth server's grant-matrix half of the same invariant is pinned by
/// `advanced_auth_server/test/grant_matrix_key_consistency_test.dart`; each test
/// lives in the package that owns its artifact (no cross-package file reads).
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:test/test.dart';

/// The gradable item field tokens (plain field names) and their full wire keys.
/// Steps 21/24/26 derive these from reflection/the resource bundle; here they
/// are the inline expectation this drift guard checks against.
const _gradableItemFields = <String>[
  'title',
  'status',
  'priority',
  'assigneeId',
  'dueDate',
  'estimate',
  'description',
];
const _gradableItemKeys = <String>[
  'todo.item.title',
  'todo.item.status',
  'todo.item.priority',
  'todo.item.assigneeId',
  'todo.item.dueDate',
  'todo.item.estimate',
  'todo.item.description',
];

/// Extracts the distinct `<field>` segment of every `todo.item.<field>.<suffix>`
/// key in the flattened resource bundle (e.g. `todo.item.title.label` → `title`).
Set<String> _gradedFieldsLabelledIn(Map<String, Object?> texts) {
  const prefix = 'todo.item.';
  final fields = <String>{};
  for (final key in texts.keys) {
    if (!key.startsWith(prefix)) continue;
    // `todo.item.<field>.<suffix>` — at least four dot-segments.
    final parts = key.split('.');
    if (parts.length < 4) continue;
    fields.add(parts[2]);
  }
  return fields;
}

void main() {
  group('resource-key consistency (RC-26)', () {
    test('resources_app.json labels exactly the gradable item fields '
        '(no missing, no stray)', () {
      final texts = AppResourceBundles.appBundle().texts;
      final labelled = _gradedFieldsLabelledIn(texts);

      expect(
        labelled,
        equals(_gradableItemFields.toSet()),
        reason: 'The todo.item.* fields labelled in resources_app.json must '
            'match the gradable item field set exactly. A difference means '
            'the text tree drifted from the field set — add the missing '
            'label or remove the stray one.',
      );
    });

    test('every labelled key resolves to a known gradable item key', () {
      // Each labelled field reconstructs to a known full resource key, proving
      // the JSON keys are addressable as `todo.item.<field>`.
      final texts = AppResourceBundles.appBundle().texts;
      for (final field in _gradedFieldsLabelledIn(texts)) {
        expect(
          _gradableItemKeys,
          contains('todo.item.$field'),
          reason: 'labelled field "$field" has no matching gradable item key',
        );
      }
    });
  });
}
