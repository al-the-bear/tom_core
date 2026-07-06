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
/// ## Why resolution is namespace-aware, not a flat map
///
/// The adapter is installed on the [TomAuthorization] **singleton**, so *every*
/// field in the app routes its layer-1 lookup through it — not just the graded
/// item fields, but the login form's `login.username`, the board, every dialog.
/// A flat map that returned the closed-safe [TomAuthState.none] for any path it
/// did not recognise would therefore hide the login screen and break the rest
/// of the app. So the adapter guards a single explicit *namespace* — the
/// gradable item keys ([gradableKeys]) — and stays out of the kernel's way for
/// everything else by returning the dev-mode default [TomAuthState.full].
///
/// `resolveEffectiveAuth()` also has a layer-3 *form narrow*: it looks up the
/// **form path** (`todo.item`) and narrows every field by it
/// (`tom_form.dart` §3). The grade matrix the server sends is keyed only by
/// *leaf* field keys — it carries no `todo.item` row — so resolving that
/// ancestor to the closed-safe `none` would narrow every field to `none` and
/// hide the whole form. To avoid that, [resolveAuth] resolves a path that is a
/// structural *ancestor* of a gradable field permissively ([TomAuthState.full]),
/// making the form narrow a no-op, while a *known* gradable leaf with no grade
/// in the live matrix still degrades to [TomAuthState.none] (D-A4, closed-safe).
///
/// This is the form-path-aware variant of the parent-path pattern in
/// `tom_flutter_form_test/lib/demos/demo_3_authorization.dart`: that demo walks
/// leaf→ancestor to *inherit* a grade; here we resolve ancestor→permissive to
/// *avoid clobbering* per-field grades that have no form-level row.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The gradable item leaf keys the adapter guards when no explicit set is given.
///
/// Addressed by scope + `tomId` (`todo.item.<field>`), resolved here at the one
/// use site rather than pulled from a key-catalogue class (G-RES-6). Steps 24–26
/// derive this set from the item form's field `tomId`s once the form owns the
/// gradable-field declaration; this inline set is the interim client source.
const _gradableItemKeys = <String>{
  'todo.item.title',
  'todo.item.status',
  'todo.item.priority',
  'todo.item.assigneeId',
  'todo.item.dueDate',
  'todo.item.estimate',
  'todo.item.description',
};

/// A [TomAuthorizationAdapter] that resolves an item field's authorization from
/// a repointable `Map<String, TomAuthState>` grade matrix, while leaving every
/// path outside the gradable namespace to the kernel's permissive default.
///
/// Install one instance once at startup (`TomAuthorization.adapter = …`) and
/// repoint [states] as the session loads each item's matrix (todo 3) — the
/// installed singleton then always reflects the item currently in view, with no
/// reinstall.
class FieldStateAuthorizationAdapter extends TomAuthorizationAdapter {
  /// Creates the adapter over an initial grade [states] matrix (empty by
  /// default — known gradable leaves then resolve to [TomAuthState.none] until
  /// the session feeds a matrix; everything outside the namespace stays `full`).
  ///
  /// [gradableKeys] names the namespace the adapter guards; it defaults to the
  /// full set of gradable item leaf keys (`todo.item.*`, [_gradableItemKeys]).
  FieldStateAuthorizationAdapter([
    this.states = const {},
    Set<String>? gradableKeys,
  ]) : gradableKeys = gradableKeys ?? _gradableItemKeys;

  /// The grade matrix this adapter resolves against, keyed by a field's
  /// scope-derived `basePath` (== the wire resource key, e.g. `todo.item.title`).
  ///
  /// Repointable: assign a freshly loaded matrix as the session opens each item
  /// (todo 3) and the installed singleton picks the new grades up immediately —
  /// no reinstall needed.
  Map<String, TomAuthState> states;

  /// The set of leaf resource keys this adapter is responsible for grading. A
  /// path is closed-safe (`none` when ungranted) only if it is one of these;
  /// any path outside this namespace is left permissive (`full`).
  final Set<String> gradableKeys;

  @override
  TomAuthState resolveAuth(String resourceKeyPath) {
    // 1. An exact grade for this field/path wins (the common case for a leaf
    //    item key, and also honours an explicit ancestor grade should the
    //    matrix ever carry one).
    final exact = states[resourceKeyPath];
    if (exact != null) return exact;

    // 2. A structural ancestor of a gradable field (the form node `todo.item`,
    //    the scope `todo`) — even with an empty matrix — resolves permissively
    //    so the layer-3 form narrow does not clobber the per-field grades.
    final childPrefix = '$resourceKeyPath.';
    if (gradableKeys.any((key) => key.startsWith(childPrefix))) {
      return TomAuthState.full;
    }

    // 3. A known gradable leaf with no grade in the live matrix — closed-safe
    //    default (D-A4): hidden, never a leaked editable control.
    if (gradableKeys.contains(resourceKeyPath)) return TomAuthState.none;

    // 4. Anything outside the gradable namespace (login, board, dialogs) is not
    //    this adapter's concern → the kernel's permissive no-adapter default.
    return TomAuthState.full;
  }
}
