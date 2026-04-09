import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../widget_base/tom_construction_helpers.dart';
import '../theme/tom_theme.dart';

/// Mixin for Tom widgets that extend Flutter widgets directly.
///
/// This mixin provides the Tom UI concerns (ID, group, authorization, resources)
/// to widgets that extend their Flutter originals.
///
/// Implements [TomAuthorizable] for type-safe group registration.
mixin TomWidgetMixin on Widget implements TomAuthorizable {
  @override
  String? get tomId;

  @override
  TomAuthorizationGroup? get tomGroup => null;

  TomScope? get scope => null;

  /// Optional per-widget authorizer.
  TomAuthorizer? get authorizer => null;

  /// Authorizer strategy. Defaults to narrowing only.
  TomAuthorizerStrategy get authorizerStrategy =>
      TomAuthorizerStrategy.authorizerNarrowsOnly;

  /// Optional build-time state controller.
  TomUIStateController? get uiStateController => null;

  String? get basePath {
    if (tomId == null) return null;
    final effectiveScope = scope ?? TomScope.current;
    final scopePath = effectiveScope.getScopePath();
    if (scopePath.isNotEmpty) return '$scopePath.$tomId';
    return tomId;
  }

  /// Gets the effective authorization state for this widget.
  ///
  /// Combines resource auth, authorizer, and UI state controller.
  TomAuthState getAuth() {
    // 1. Resource-based authorization
    var state = (basePath != null)
        ? TomAuthorization.resolveAuth(basePath!)
        : TomAuthState.full;

    // 2. Per-widget authorizer
    if (authorizer != null) {
      state = authorizer!.effectiveAuth(state);
    }

    // 3. Build-time UI state controller (can only narrow)
    if (uiStateController != null) {
      state = uiStateController!.apply(state);
    }

    return state;
  }

  /// Gets a text resource for this widget.
  ///
  /// Resolves `<canonical-path>.<suffix>` from [TomCtr].
  String getText(String suffix) {
    return TomCtr.text(basePath, suffix);
  }

  /// Returns `SizedBox.shrink()` if authorization says hidden, `null` otherwise.
  Widget? checkHidden() {
    final auth = getAuth();
    if (auth == TomAuthState.none) return const SizedBox.shrink();
    return null;
  }

  /// Applies the appropriate visual treatment based on auth state.
  Widget applyAuthState(BuildContext context, Widget child) {
    final auth = getAuth();
    switch (auth) {
      case TomAuthState.none:
        return const SizedBox.shrink();
      case TomAuthState.disabled:
        return AbsorbPointer(
          child: Opacity(opacity: 0.38, child: child),
        );
      case TomAuthState.read:
        final style = TomThemeScope.readonlyStyleOf(context);
        return style.apply(child);
      case TomAuthState.full:
        return child;
    }
  }

  void registerWithGroup() {
    tomGroup?.register(this);
  }

  void unregisterFromGroup() {
    tomGroup?.unregister(this);
  }

  String get debugLabel {
    final parts = <String>['id: $tomId'];
    if (tomGroup != null) {
      parts.add('group: ${tomGroup!.groupId}');
    }
    return '${runtimeType.toString()}(${parts.join(', ')})';
  }

  // ===========================================================================
  // Typed Resource Resolution
  // ===========================================================================

  /// Resolves a color from resources relative to this widget's canonical path.
  Color? resolveColorOrNull(String suffix) {
    return TomCtr.color(basePath, suffix);
  }

  /// Resolves a double from resources relative to this widget's canonical path.
  double? resolveDoubleOrNull(String suffix) {
    return TomCtr.doubleVal(basePath, suffix);
  }

  /// Resolves a required double from resources relative to this widget's canonical path.
  double resolveDoubleOrFail(String suffix) {
    return TomCtr.doubleOrFail(basePath, suffix);
  }

  /// Resolves an int from resources relative to this widget's canonical path.
  int? resolveIntOrNull(String suffix) {
    return TomCtr.intVal(basePath, suffix);
  }

  /// Resolves a bool from resources relative to this widget's canonical path.
  bool? resolveBoolOrNull(String suffix) {
    return TomCtr.boolVal(basePath, suffix);
  }

  /// Resolves edge insets from resources relative to this widget's canonical path.
  EdgeInsets? resolveEdgeInsetsOrNull(String suffix) {
    return TomCtr.edgeInsets(basePath, suffix);
  }
}
