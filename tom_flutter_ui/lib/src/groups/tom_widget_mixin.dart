import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../resource_auth/tom_resources.dart';
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
  TomAuthorizationGroup? get authorizationGroup => null;

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
  /// Resolves `<canonical-path>.<suffix>` from [TomUIResources].
  String getText(String suffix) {
    if (basePath == null) return '';
    return TomUIResources.resolveText(basePath!, suffix);
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
    authorizationGroup?.register(this);
  }

  void unregisterFromGroup() {
    authorizationGroup?.unregister(this);
  }

  String get debugLabel {
    final parts = <String>['id: $tomId'];
    if (authorizationGroup != null) {
      parts.add('group: ${authorizationGroup!.groupId}');
    }
    return '${runtimeType.toString()}(${parts.join(', ')})';
  }

  // ===========================================================================
  // Typed Resource Resolution
  // ===========================================================================

  /// Resolves a color from resources relative to this widget's canonical path.
  ///
  /// Returns `null` if:
  /// - This widget has no [tomId]
  /// - No color resource exists for this suffix
  /// - The color name cannot be resolved to a [Color]
  ///
  /// The resource value should be a color name (e.g., "mRed", "cSystemBlue")
  /// or hex string (e.g., "#FF5733") that [TomUIColors] can resolve.
  Color? resolveColorOrNull(String suffix) {
    if (basePath == null) return null;
    return TomUIResources.resolveColor(basePath!, suffix);
  }

  /// Resolves a double from resources relative to this widget's canonical path.
  ///
  /// Returns `null` if:
  /// - This widget has no [tomId]
  /// - No resource exists for this suffix
  /// - The value is not numeric
  double? resolveDoubleOrNull(String suffix) {
    if (basePath == null) return null;
    return TomUIResources.resolveDouble(basePath!, suffix);
  }

  /// Resolves a required double from resources relative to this widget's canonical path.
  ///
  /// Throws [StateError] if:
  /// - This widget has no [tomId] (resource lookup is impossible)
  /// - No resource exists for this suffix
  /// - The value exists but is not numeric
  double resolveDoubleOrFail(String suffix) {
    if (basePath == null) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a tomId for '
        'resource lookup. Widget: $runtimeType',
      );
    }
    if (!TomUIResources.resourceExists(basePath!, suffix)) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a numeric '
        'resource value at $basePath.$suffix. Widget: $runtimeType',
      );
    }
    final value = TomUIResources.resolveDouble(basePath!, suffix);
    if (value == null) {
      throw StateError(
        'Resource $basePath.$suffix must be numeric for widget $runtimeType.',
      );
    }
    return value;
  }

  /// Resolves an int from resources relative to this widget's canonical path.
  ///
  /// Returns `null` if:
  /// - This widget has no [tomId]
  /// - No resource exists for this suffix
  /// - The value is not numeric
  int? resolveIntOrNull(String suffix) {
    if (basePath == null) return null;
    return TomUIResources.resolveInt(basePath!, suffix);
  }

  /// Resolves a bool from resources relative to this widget's canonical path.
  ///
  /// Returns `null` if:
  /// - This widget has no [tomId]
  /// - No resource exists for this suffix
  /// - The value is not boolean-like
  bool? resolveBoolOrNull(String suffix) {
    if (basePath == null) return null;
    return TomUIResources.resolveBool(basePath!, suffix);
  }

  /// Resolves edge insets from resources relative to this widget's canonical path.
  ///
  /// Returns `null` if:
  /// - This widget has no [tomId]
  /// - No resource exists for this suffix
  /// - The format is not recognized
  ///
  /// Accepts various formats in the JSON resource:
  /// - A single number for uniform insets
  /// - An array [all], [horizontal, vertical], or [left, top, right, bottom]
  /// - A map with keys: "all", "horizontal", "vertical", "left", "top", "right", "bottom"
  EdgeInsets? resolveEdgeInsetsOrNull(String suffix) {
    if (basePath == null) return null;
    return TomUIResources.resolveEdgeInsets(basePath!, suffix);
  }
}
