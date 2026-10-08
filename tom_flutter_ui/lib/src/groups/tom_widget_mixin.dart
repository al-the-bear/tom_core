import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../widget_base/tom_auth_layers.dart';
import '../widget_base/tom_construction_helpers.dart';
import '../widget_base/tom_scope_path.dart';
import '../widget_base/tom_widget_surface.dart';
import '../theme/tom_theme.dart';

/// Mixin for Tom widgets that extend Flutter widgets directly.
///
/// This mixin provides the Tom UI concerns (ID, group, authorization, resources)
/// to widgets that extend their Flutter originals.
///
/// Implements [TomWidgetSurface] — the same interface `TomNodeBase` implements,
/// which is the point: these two are the kit's only two routes to a Tom widget,
/// and naming one contract for both is what lets the conformance suite treat
/// them uniformly instead of maintaining a second list of who has what.
mixin TomWidgetMixin on Widget implements TomWidgetSurface {
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

  @override
  String? get basePath => TomScopePath.resolve(tomId, effectiveScope);

  /// Gets the effective authorization state for this widget.
  ///
  /// The layers and their order live in [TomAuthLayers.resolve], shared with
  /// `TomPolicyNodeBase.resolveEffectiveAuth` and
  /// `TomField.resolveEffectiveAuth`; this widget supplies no `narrowBy`,
  /// which only `forms/` has.
  ///
  /// The group resolves in [effectiveScope] — the same scope [basePath] was
  /// built from, so an explicit scope reaches both or the group's ceiling is
  /// quietly looked up somewhere else.
  TomAuthState getAuth() => TomAuthLayers.resolve(
    basePath: basePath,
    group: tomGroup,
    groupScope: effectiveScope,
    authorizer: authorizer,
    uiStateController: uiStateController,
  );

  @override
  TomAuthState get effectiveAuthState => getAuth();

  /// Gets a text resource for this widget.
  ///
  /// Resolves `<canonical-path>.<suffix>` from [TomCtr]. Typed values (colors,
  /// numbers, insets) are resolved through the [TomCtr] statics directly, with
  /// [basePath] as the path — the one resolution surface every widget uses.
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
}
