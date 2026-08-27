import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../theme/tom_theme.dart';
import 'tom_node_base.dart';

/// Authorization enforcement layer for Tom UI elements.
///
/// Every Tom widget passes through this base class. It resolves the effective
/// authorization state by combining:
/// 1. Resource-based authorization (via [TomAuthorization] singleton)
/// 2. Group authorization (if a member of a [TomAuthorizationGroup])
/// 3. Per-widget [authorizer] (if set)
/// 4. Build-time [uiStateController] (if set, can only narrow)
///
/// Enforcement:
/// - [TomAuthState.none] → [SizedBox.shrink] (hidden from layout)
/// - [TomAuthState.disabled] → disabled visual treatment
/// - [TomAuthState.read] → readonly visual treatment
/// - [TomAuthState.full] → normal rendering
abstract class TomPolicyNodeBase extends TomNodeBase {
  TomPolicyNodeBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
  });

  @override
  Widget build(BuildContext context) {
    return constructionScope.runInScope(() => _buildWithAuth(context));
  }

  /// Resolves the effective [TomAuthState] for this widget.
  ///
  /// Combines resource auth, group auth, authorizer, and UI state controller,
  /// in that order — the same four layers, in the same sequence, as
  /// `TomWidgetMixin.getAuth`. `TomField.resolveEffectiveAuth` runs a fifth:
  /// it narrows by the enclosing form between the group and the authorizer.
  ///
  /// Resource and group together establish what is *granted*; the controller
  /// then narrows it, and the authorizer either narrows or decides outright
  /// depending on its [TomAuthorizerStrategy]. The controller has to run last
  /// for its "can only narrow" promise to hold — [TomAuthorizationGroup.applyMode]
  /// widens under `controlsNarrowest` and replaces outright under
  /// `controlsAll`, so a group applied afterwards would undo the narrowing.
  TomAuthState resolveEffectiveAuth() {
    // 1. Resource-based authorization
    var state = basePath != null
        ? TomAuthorization.resolveAuth(basePath!)
        : TomAuthState.full;

    // 2. Group authorization (if member of a group), resolved in the scope
    //    [basePath] was built from. [build] re-enters that scope, so reading
    //    the state from inside a build was always right; every other reader —
    //    [TomAuthorizationGroup.members] and the inspection getters defined on
    //    it — stands outside it, and would otherwise see a different ceiling
    //    than the one the widget renders under.
    if (tomGroup != null) {
      state = tomGroup!.applyMode(state, constructionScope);
    }

    // 3. Per-widget authorizer
    if (authorizer != null) {
      state = authorizer!.effectiveAuth(state);
    }

    // 4. Build-time UI state controller (can only narrow)
    if (uiStateController != null) {
      state = uiStateController!.apply(state);
    }

    return state;
  }

  @override
  TomAuthState get effectiveAuthState => resolveEffectiveAuth();

  Widget _buildWithAuth(BuildContext context) {
    final authState = resolveEffectiveAuth();

    switch (authState) {
      case TomAuthState.none:
        return const SizedBox.shrink();
      case TomAuthState.disabled:
        return buildDisabled(context);
      case TomAuthState.read:
        return buildReadonly(context);
      case TomAuthState.full:
        return buildContent(context);
    }
  }

  /// Builds the actual widget content after authorization has been resolved.
  ///
  /// Subclasses implement this instead of [build].
  Widget buildContent(BuildContext context);

  /// Builds the readonly visual treatment.
  ///
  /// The default implementation resolves [TomReadonlyStyle] from the
  /// nearest [TomThemeScope] and applies it. When no theme scope exists,
  /// [TomReadonlyStyle.defaultStyle] is used (AbsorbPointer + 0.6 opacity).
  Widget buildReadonly(BuildContext context) {
    final style = TomThemeScope.readonlyStyleOf(context);
    return style.apply(buildContent(context));
  }

  /// Builds the disabled visual treatment.
  ///
  /// Disabled means the widget is visible but greyed out with no content.
  /// The default applies opacity + absorbs pointers, similar to readonly
  /// but with reduced opacity to indicate the element is not available.
  Widget buildDisabled(BuildContext context) {
    return AbsorbPointer(
      child: Opacity(
        opacity: 0.38,
        child: buildContent(context),
      ),
    );
  }
}
