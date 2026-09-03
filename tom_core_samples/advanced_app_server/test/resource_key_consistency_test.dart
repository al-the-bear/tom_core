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
/// (G-RES-6: addressing is by scope + `tomId`, so there is no catalogue class.
/// The *server's* gradable set is derived from the resource bundle
/// ([AppResourceBundles.gradableItemKeys], asserted below); the *client's* set
/// is derived from the form. The anchor both derivations are checked
/// against is the shared domain's own [gradableItemKeys], not a list re-typed
/// here — the same anchor the auth server's grant-matrix guard uses.)
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
///
/// One `todo.item.*` key is deliberately **outside** this set:
/// [itemAttachmentGradeKey], the item's graded file column. It is granted in the
/// same auth-server matrix but must never join the bundle-derived *field* set —
/// see the last test for why that exclusion is load-bearing rather than an
/// oversight.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:test/test.dart';

/// The plain field tokens of the domain's [gradableItemKeys]
/// (`todo.item.title` → `title`) — the shape the resource JSON nests its labels
/// under, which is the only reason this second spelling exists at all.
///
/// **Derived, not re-typed.** Everything this guard asserts is anchored on the
/// shared domain vocabulary, so a regrade that renames a key in
/// [gradableItemKeys] without touching `resources_app.json` fails here. An
/// inline copy of the seven would leave exactly that drift green — which is the
/// drift the guard exists to catch.
final Set<String> _gradableItemFields = {
  for (final key in gradableItemKeys) key.split('.').last,
};

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
        equals(_gradableItemFields),
        reason:
            'The todo.item.* fields labelled in resources_app.json must '
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
          gradableItemKeys,
          contains('todo.item.$field'),
          reason: 'labelled field "$field" has no matching gradable item key',
        );
      }
    });

    test('the bundle derives the gradable key set in display order', () {
      // The server holds no hand-maintained gradable-key list — the resolver
      // and the write path both address
      // AppResourceBundles.gradableItemKeys(). Pin that derivation (set + order)
      // to the shared domain vocabulary, so a reordered or renamed label is
      // caught, and so is a regrade applied to `gradableItemKeys` alone. The
      // two orders are independent: the bundle's comes from the JSON tree, the
      // domain's from its own declaration.
      expect(
        AppResourceBundles.gradableItemKeys(),
        orderedEquals(gradableItemKeys),
      );
    });

    test('the write path enforces exactly the bundle-derived keys', () {
      // The write path's field-binding table is built from the same bundle keys,
      // so a bundle field without a read/copy binding (or a stray binding) would
      // surface here as a mismatch.
      expect(gradableItemFieldKeys, orderedEquals(gradableItemKeys));
    });

    test('the graded attachment column stays out of the gradable field set', () {
      // `todo.item.attachment` is granted by the same four roles in the same
      // auth-server matrix, but it is a **column**, not a form field, and the
      // difference is a security boundary rather than bookkeeping:
      //
      //  * the gradable field set is the list of form fields the item write
      //    path will overlay from a client payload, each bound to its column
      //    explicitly. `attachment` holds a *blob key* minted server-side by
      //    `saveFile`; a caller able to write it would repoint their row at
      //    somebody else's bytes.
      //  * the set is bundle-derived, and the write path looks every derived key
      //    up in its binding table with `!`. A `todo.item.attachment.label` text
      //    added to `resources_app.json` would therefore not merely widen the
      //    set — it would crash the write path at boot-time binding.
      //
      // The column is graded on the file endpoint instead, where the only thing
      // a caller supplies is bytes (`registerAppColumnGrades`).
      expect(
        AppResourceBundles.gradableItemKeys(),
        isNot(contains(itemAttachmentGradeKey)),
        reason:
            'a todo.item.attachment.* text in resources_app.json would pull '
            'the file column into the item write path — grade it on the file '
            'endpoint instead',
      );
      expect(gradableItemFieldKeys, isNot(contains(itemAttachmentGradeKey)));
    });
  });
}
