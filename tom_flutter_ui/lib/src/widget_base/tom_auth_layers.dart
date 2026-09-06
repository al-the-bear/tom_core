import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Composes the authorization layers into one effective [TomAuthState].
///
/// Three resolvers in this package answer "what may the user do with this
/// element?" — [TomPolicyNodeBase.resolveEffectiveAuth] for widgets on the base
/// chain, `TomWidgetMixin.getAuth` for widgets that extend their Flutter
/// originals, and `TomField.resolveEffectiveAuth` in `forms/`. They see
/// different inputs but must reach the same answer from the same ones, so the
/// composition lives here and each of them supplies its own arguments.
///
/// ## The order is load-bearing
///
/// Layers are applied resource → group → [narrowBy] → authorizer → controller,
/// and that sequence is not a convention. Three of the layers can *widen*:
/// [TomAuthorizationGroup.applyMode] widens under `controlsNarrowest` and
/// replaces outright under `controlsAll`, and a [TomAuthorizer] with a deciding
/// strategy answers on its own rather than narrowing what it was given. The
/// [TomUIStateController] is documented as being able to *only narrow, never
/// widen*, and that promise holds only because it runs last — a group applied
/// after it would silently undo the narrowing it had just performed.
///
/// So a permutation of these five lines is a behaviour change, not a
/// refactoring. That is the reason they are written once: the order was
/// previously spelled out in three places, where a correction to one was a
/// correction the other two did not receive — and for a time did not, the two
/// widget-side resolvers running the group *last* while `forms/` ran it second.
///
/// This class holds no Flutter dependency, for the same reason [TomScopePath]
/// holds none: `TomField` is not a `Widget`, and a rule the form layer cannot
/// call is a rule with a third copy.
class TomAuthLayers {
  TomAuthLayers._();

  /// Resolves the effective state from the layers the caller has.
  ///
  /// Every layer is optional and an absent one is skipped, so a caller passes
  /// what it has and nothing more. [basePath] of `null` means the element
  /// addresses no resource — it seeds [TomAuthState.full] rather than looking
  /// up the empty path.
  ///
  /// [groupScope] is the frame [basePath] was built from, and callers differ in
  /// how they name it: widgets on the base chain hold a `constructionScope`
  /// fixed at construction, while a [TomWidgetMixin] widget resolves its
  /// `effectiveScope` from an explicit scope or the ambient one. Passing the
  /// scope in rather than reading [TomScope.current] here is what lets a group
  /// be read from outside the widget's own build — a caller inspecting
  /// [TomAuthorizationGroup] while standing at the root would otherwise see a
  /// different ceiling than the one the widget renders under.
  ///
  /// [narrowBy] is an additional ceiling applied between the group and the
  /// authorizer. Only `forms/` supplies one: a field is bounded by its
  /// enclosing form, which behaves as an implicit group that can only narrow.
  /// It sits after the group deliberately — the form's ceiling has to survive a
  /// `controlsAll` group, and before the authorizer because the authorizer may
  /// decide outright.
  static TomAuthState resolve({
    required String? basePath,
    required TomAuthorizationGroup? group,
    required TomScope groupScope,
    required TomAuthorizer? authorizer,
    required TomUIStateController? uiStateController,
    TomAuthState? narrowBy,
  }) {
    // 1. Resource-based authorization.
    var state = basePath != null
        ? TomAuthorization.resolveAuth(basePath)
        : TomAuthState.full;

    // 2. Group authorization, resolved in the scope the base path was built
    //    from, so both halves of the `<prefix>.<id>` pair come out of one frame.
    if (group != null) {
      state = group.applyMode(state, groupScope);
    }

    // 3. An enclosing ceiling that can only narrow (the form, in `forms/`).
    if (narrowBy != null) {
      state = state.narrow(narrowBy);
    }

    // 4. Per-element authorizer — narrows or decides, per its strategy.
    if (authorizer != null) {
      state = authorizer.effectiveAuth(state);
    }

    // 5. Build-time UI state controller. Last, so it can only narrow.
    if (uiStateController != null) {
      state = uiStateController.apply(state);
    }

    return state;
  }
}
