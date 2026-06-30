/// Drift guard: the externalized text-resource tree (RC-24) and the domain's
/// gradable-field keys must name the same set of `todo.item.*` fields.
///
/// Three artifacts have to agree on the scope/form/field keys — the domain
/// [TodoItemResourceKeys] constants (the single source of truth), the app
/// server's `assets/resources_app.json` text tree, and the auth server's
/// `tom_resource_grant` matrix seed. This test pins the **app server's** half:
/// the field segments the resource JSON labels under `todo.item.*` are exactly
/// [TodoItemResourceKeys.allFields] — no field missing a label, and no stray
/// label for a field the domain does not grade.
///
/// The existing `resource_bundle_endpoint_test.dart` already asserts the *first*
/// direction (every SoT field has a label key). This test adds the *reverse*
/// direction — a renamed or typo'd `todo.item.*` key in the JSON that no longer
/// matches a domain field would pass the one-directional check but fail here —
/// so the two together catch drift either way. Pure text, no database.
///
/// The auth server's grant-matrix half of the same invariant is pinned by
/// `advanced_auth_server/test/grant_matrix_key_consistency_test.dart`; each test
/// lives in the package that owns its artifact (no cross-package file reads).
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:test/test.dart';

/// Extracts the distinct `<field>` segment of every `todo.item.<field>.<suffix>`
/// key in the flattened resource bundle (e.g. `todo.item.title.label` → `title`).
Set<String> _gradedFieldsLabelledIn(Map<String, Object?> texts) {
  const prefix = '${TodoItemResourceKeys.scope}.${TodoItemResourceKeys.formId}.';
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
    test('resources_app.json labels exactly the domain gradable fields '
        '(no missing, no stray)', () {
      final texts = AppResourceBundles.appBundle().texts;
      final labelled = _gradedFieldsLabelledIn(texts);

      expect(
        labelled,
        equals(TodoItemResourceKeys.allFields.toSet()),
        reason: 'The todo.item.* fields labelled in resources_app.json must '
            'match TodoItemResourceKeys.allFields exactly. A difference means '
            'the text tree drifted from the domain key set — add the missing '
            'label or remove the stray one.',
      );
    });

    test('every labelled key resolves through the domain key builder', () {
      // Each labelled field reconstructs to a known full resource key, proving
      // the JSON keys are addressable as `TodoItemResourceKeys.keyFor(field)`.
      final texts = AppResourceBundles.appBundle().texts;
      for (final field in _gradedFieldsLabelledIn(texts)) {
        expect(
          TodoItemResourceKeys.all,
          contains(TodoItemResourceKeys.keyFor(field)),
          reason: 'labelled field "$field" has no matching domain key',
        );
      }
    });
  });
}
