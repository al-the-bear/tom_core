/// The implicit-authorization adapter that backs every gradable field in the
/// app (the realignment's keystone — see `advanced_examples_alignment_plan.md`
/// todo 2).
///
/// The Tom Flutter UI form layer resolves per-field authorization *implicitly*:
/// `TomField.resolveEffectiveAuth()` (`tom_flutter_ui/.../tom_form.dart`) calls
/// `TomAuthorization.resolveAuth(basePath)` as layer 1, where `basePath` is the
/// field's scope-derived key. Once the item form runs under scope `todo` with
/// `formId: 'item'` (todo 4), a field's `basePath` *equals* the wire grade key
/// (`todo.item.title`, …). So a single adapter installed at startup, fed the
/// session's resolved grade matrix, replaces the hand-wired per-field
/// `TomAuthorizer.fixed(...)` the form used to build.
///
/// ## Why resolution is ancestor-aware, not a flat map
///
/// `resolveEffectiveAuth()` also has a layer-3 *form narrow*: it looks up the
/// **form path** (`todo.item`) and narrows every field by it
/// (`tom_form.dart` §3). The grade matrix the server sends is keyed only by
/// *leaf* field keys — it carries no `todo.item` row — so a flat map that
/// returned the closed-safe `none` for the absent form path would narrow every
/// field to `none` and hide the whole form. To avoid that, [resolveAuth]
/// resolves a path that is a structural *ancestor* of a graded field
/// permissively ([TomAuthState.full]), making the form narrow a no-op, while an
/// unknown *leaf* still degrades to [TomAuthState.none] (D-A4, closed-safe).
///
/// This is the form-path-aware variant of the parent-path pattern in
/// `tom_flutter_form_test/lib/demos/demo_3_authorization.dart`: that demo walks
/// leaf→ancestor to *inherit* a grade; here we resolve ancestor→permissive to
/// *avoid clobbering* per-field grades that have no form-level row.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A [TomAuthorizationAdapter] that resolves a field's authorization from a
/// repointable `Map<String, TomAuthState>` grade matrix.
///
/// Install one instance once at startup (`TomAuthorization.adapter = …`) and
/// repoint [states] as the session loads each item's matrix (todo 3) — the
/// installed singleton then always reflects the item currently in view, with no
/// reinstall.
class FieldStateAuthorizationAdapter extends TomAuthorizationAdapter {
  /// Creates the adapter over an initial grade [states] matrix (empty by
  /// default — every lookup then resolves to [TomAuthState.none] until the
  /// session feeds a matrix).
  FieldStateAuthorizationAdapter([this.states = const {}]);

  /// The grade matrix this adapter resolves against, keyed by a field's
  /// scope-derived `basePath` (== the wire resource key, e.g. `todo.item.title`).
  ///
  /// Repointable: assign a freshly loaded matrix as the session opens each item
  /// (todo 3) and the installed singleton picks the new grades up immediately —
  /// no reinstall needed.
  Map<String, TomAuthState> states;

  @override
  TomAuthState resolveAuth(String resourceKeyPath) {
    // 1. An exact grade for this field/path wins (this is the common case for a
    //    leaf field key, and also honours an explicit form-level grade should
    //    the matrix ever carry one).
    final exact = states[resourceKeyPath];
    if (exact != null) return exact;

    // 2. A structural ancestor of a graded field (the form node `todo.item`,
    //    the scope `todo`, …) is not itself graded by this matrix → resolve
    //    permissively so the layer-3 form narrow does not clobber the per-field
    //    grades.
    final childPrefix = '$resourceKeyPath.';
    for (final key in states.keys) {
      if (key.startsWith(childPrefix)) return TomAuthState.full;
    }

    // 3. An unknown leaf — closed-safe default (D-A4): hidden, never a leaked
    //    editable control.
    return TomAuthState.none;
  }
}
