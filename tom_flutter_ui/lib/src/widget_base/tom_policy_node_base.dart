import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../theme/tom_theme.dart';
import 'tom_auth_layers.dart';
import 'tom_node_base.dart';

/// Authorization enforcement layer for Tom UI elements.
///
/// Every Tom widget passes through this base class. It resolves the effective
/// authorization state through [TomAuthLayers.resolve], which composes
/// resource authorization, the group ceiling, the per-widget [authorizer] and
/// the build-time [uiStateController] in an order that is load-bearing.
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
  /// The layers and their order live in [TomAuthLayers.resolve], shared with
  /// `TomWidgetMixin.getAuth` and `TomField.resolveEffectiveAuth`; this widget
  /// supplies no [TomAuthLayers.resolve] `narrowBy`, which only `forms/` has.
  ///
  /// The group resolves in [constructionScope], the scope [basePath] was built
  /// from. [build] re-enters that scope, so reading the state from inside a
  /// build was always right; every other reader — [TomAuthorizationGroup.members]
  /// and the inspection getters defined on it — stands outside it, and would
  /// otherwise see a different ceiling than the one the widget renders under.
  TomAuthState resolveEffectiveAuth() => TomAuthLayers.resolve(
    basePath: basePath,
    group: tomGroup,
    groupScope: constructionScope,
    authorizer: authorizer,
    uiStateController: uiStateController,
  );

  @override
  TomAuthState get effectiveAuthState => resolveEffectiveAuth();

  /// Dispatches to the per-state build hooks.
  ///
  /// This switch deliberately does *not* delegate to [TomTheme.applyAuthState]
  /// the way `TomWidgetMixin.applyAuthState` does, because [buildReadonly] and
  /// [buildDisabled] are documented override points — a family that swaps a
  /// text field for a non-editable display overrides the hook rather than
  /// restyling the theme. What the two share is one level down: the *default*
  /// hooks resolve their treatment from the same [TomStateStyle] pair, so the
  /// appearance has a single source even though the dispatch does not.
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

  /// Builds the readonly visual treatment — visible, but not editable.
  ///
  /// The default implementation resolves the [TomStateStyle] for `read` from
  /// the nearest [TomThemeScope] and applies it. When no theme scope exists,
  /// [TomStateStyle.readonly] is used (AbsorbPointer + 0.6 opacity).
  Widget buildReadonly(BuildContext context) {
    final style = TomThemeScope.readonlyStyleOf(context);
    return style.apply(buildContent(context));
  }

  /// Builds the disabled visual treatment — visible, but not available.
  ///
  /// Resolved the same way as [buildReadonly], from the `disabled` half of the
  /// theme rather than the `read` half; the default is
  /// [TomStateStyle.disabled] (AbsorbPointer + 0.38 opacity). The dimming used
  /// to be written out here as a literal, and again in
  /// `TomWidgetMixin.applyAuthState`, so an app could restyle one of Tom's two
  /// withheld states and not the other.
  Widget buildDisabled(BuildContext context) {
    final style = TomThemeScope.disabledStyleOf(context);
    return style.apply(buildContent(context));
  }
}
