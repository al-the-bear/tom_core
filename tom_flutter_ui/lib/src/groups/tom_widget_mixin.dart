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

  /// Optional build-time state controller.
  TomUIStateController? get uiStateController => null;

  /// The scope this widget resolves in: the explicit [scope] when it was given
  /// one, otherwise whatever the zone carries.
  ///
  /// Named once and read everywhere, because every path this widget produces
  /// has to come out of the same frame. [basePath] and the group path are a
  /// `<prefix>.<id>` pair; a prefix that differs between them looks up a rule
  /// belonging to some other member.
  TomScope get effectiveScope => scope ?? TomScope.current;

  String? get basePath {
    if (tomId == null) return null;
    final scopePath = effectiveScope.getScopePath();
    if (scopePath.isNotEmpty) return '$scopePath.$tomId';
    return tomId;
  }

  /// Gets the effective authorization state for this widget.
  ///
  /// Combines resource auth, group auth, authorizer, and UI state controller,
  /// in that order — the same four layers, in the same sequence, as
  /// `TomPolicyNodeBase.resolveEffectiveAuth`.
  TomAuthState getAuth() {
    // 1. Resource-based authorization
    var state = (basePath != null)
        ? TomAuthorization.resolveAuth(basePath!)
        : TomAuthState.full;

    // 2. Group authorization (if member of a group), resolved in the same
    //    scope as the base path above — an explicit scope reaches both or the
    //    group's ceiling is quietly looked up somewhere else.
    if (tomGroup != null) {
      state = tomGroup!.applyMode(state, effectiveScope);
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
  TomAuthState get effectiveAuthState => getAuth();

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
  ///
  /// The mapping itself lives in [TomTheme.applyAuthState], shared with
  /// `TomPolicyNodeBase` — the two used to switch over the four states
  /// separately, which is how the `disabled` treatment came to be written out
  /// twice with the opacity hard-coded in both.
  ///
  /// [child] is already built by the caller, so the laziness the callback
  /// affords is spent here; it still matters for the other enforcement point.
  Widget applyAuthState(BuildContext context, Widget child) {
    return TomThemeScope.applyAuthState(context, getAuth(), () => child);
  }

  void registerWithGroup() {
    tomGroup?.register(this);
  }

  void unregisterFromGroup() {
    tomGroup?.unregister(this);
  }

  /// Debug description for this widget.
  ///
  /// Matches `TomNodeBase.debugLabel` field for field, so one widget reads the
  /// same way whichever half of the package it comes from. That includes
  /// omitting an absent [tomId] rather than interpolating it: `tomId` is
  /// nullable here, and `id: null` describes a widget whose id is the string
  /// `null` instead of one that has no id at all.
  String get debugLabel {
    final parts = <String>[];
    if (tomId != null) parts.add('id: $tomId');
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
