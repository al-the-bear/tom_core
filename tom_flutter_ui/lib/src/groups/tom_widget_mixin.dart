import 'package:flutter/widgets.dart';

import '../resource_auth/tom_auth_state.dart';
import '../resource_auth/tom_id_prefix.dart';
import '../resource_auth/tom_resources.dart';
import '../theme/tom_theme.dart';
import '../widget_base/tom_node_base.dart';
import 'tom_groups.dart';

/// Mixin for Tom widgets that extend Flutter widgets directly.
///
/// This mixin provides the Tom UI concerns (ID, group, authorization, resources)
/// to widgets that extend their Flutter originals:
///
/// ```dart
/// class TomTab extends Tab with TomWidgetMixin {
///   TomTab({required this.tomId, this.tomGroup, ...});
///
///   @override
///   final String tomId;
///
///   @override
///   final String? tomGroup;
/// }
/// ```
///
/// The mixin provides:
/// - [tomId] — abstract, must be implemented
/// - [tomGroup] — optional group membership (defaults to `null`)
/// - [resolveFullPath] — canonical path via [TomNodeScope]
/// - [getAuth] — authorization state lookup
/// - [getText] — text resource lookup
/// - [checkHidden] — returns `SizedBox.shrink()` if hidden
/// - [applyReadonly] — applies readonly styling
/// - Group registration hooks for StatefulWidgets
mixin TomWidgetMixin on Widget {
  /// The local widget ID (without prefix).
  ///
  /// This is combined with parent scope IDs to create the canonical path.
  /// Can be null for drop-in Flutter compatibility.
  String? get tomId;

  /// Optional group membership (zero or one group).
  ///
  /// When set, the widget registers with [TomGroups] on mount.
  String? get tomGroup => null;

  /// Resolves the full canonical path including route/container/group prefix.
  ///
  /// Uses [TomNodeScope] from the widget tree to build the path.
  /// Returns null if tomId is null.
  String? resolveFullPath(BuildContext context) {
    if (tomId == null) return null;
    final scope = TomNodeScope.of(context);
    return scope?.appendWidget(tomId!) ??
        TomIdPrefix.prefixed(TomIdPrefix.widget, tomId!);
  }

  /// Gets authorization state for this widget.
  TomAuthState getAuth(BuildContext context) {
    final path = resolveFullPath(context);
    if (path == null) return TomAuthState.fullAccess;
    return TomUIAuthorization.resolveAuth(path);
  }

  /// Gets a text resource for this widget.
  ///
  /// Resolves `<canonical-path>.<suffix>` from [TomUIResources].
  String getText(BuildContext context, String suffix) {
    final path = resolveFullPath(context);
    if (path == null) return '';
    return TomUIResources.resolveText(path, suffix);
  }

  /// Returns `SizedBox.shrink()` if authorization says hidden, `null` otherwise.
  ///
  /// Call at the start of `build()` methods:
  /// ```dart
  /// @override
  /// Widget build(BuildContext context) {
  ///   final hidden = checkHidden(context);
  ///   if (hidden != null) return hidden;
  ///   // ... normal build
  /// }
  /// ```
  Widget? checkHidden(BuildContext context) {
    if (!getAuth(context).visible) return const SizedBox.shrink();
    return null;
  }

  /// Wraps [child] in readonly style if authorization says readonly.
  ///
  /// The readonly style is resolved from [TomThemeScope].
  Widget applyReadonly(BuildContext context, Widget child) {
    if (getAuth(context).readonly) {
      final style = TomThemeScope.readonlyStyleOf(context);
      return style.apply(child);
    }
    return child;
  }

  /// Registers this widget with its group.
  ///
  /// For **StatefulWidgets**, call from `State.initState()`:
  /// ```dart
  /// @override
  /// void initState() {
  ///   super.initState();
  ///   widget.registerWithGroup();
  /// }
  /// ```
  ///
  /// For **StatelessWidgets**, registration is handled by calling this
  /// in a wrapper or during build tracking.
  void registerWithGroup() {
    final group = tomGroup;
    if (group != null) {
      TomGroups.of(group).register(this);
    }
  }

  /// Unregisters this widget from its group.
  ///
  /// For **StatefulWidgets**, call from `State.dispose()`:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   widget.unregisterFromGroup();
  ///   super.dispose();
  /// }
  /// ```
  void unregisterFromGroup() {
    final group = tomGroup;
    if (group != null) {
      TomGroups.of(group).unregister(this);
    }
  }

  /// Debug description for this widget.
  String get debugLabel {
    final parts = <String>['id: $tomId'];
    if (tomGroup != null) parts.add('group: $tomGroup');
    return '${runtimeType.toString()}(${parts.join(', ')})';
  }
}
