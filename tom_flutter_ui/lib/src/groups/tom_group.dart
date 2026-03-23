import 'package:flutter/widgets.dart';

import '../resource_auth/tom_auth_state.dart';
import '../resource_auth/tom_id_prefix.dart';
import '../widget_base/tom_node_base.dart';

/// A group of related widgets that share visibility control.
///
/// Widgets register themselves with a group on mount and unregister on dispose.
/// The group tracks all registered members and provides visibility checks.
///
/// Group IDs follow the canonical path pattern:
/// ```
/// r-<route>.c-<container>.g-<groupId>
/// ```
class TomGroup {
  /// The local group ID (without prefix).
  final String groupId;

  /// Registered members of this group.
  ///
  /// Members are stored as [Widget] since they use [TomWidgetMixin], but we
  /// avoid a direct import to prevent circular dependencies.
  final Set<Widget> _members = {};

  /// Creates a group with the given [groupId].
  TomGroup(this.groupId);

  /// Registers a widget with this group.
  ///
  /// Called automatically by [TomWidgetMixin.registerWithGroup].
  void register(Widget widget) => _members.add(widget);

  /// Unregisters a widget from this group.
  ///
  /// Called automatically by [TomWidgetMixin.unregisterFromGroup].
  void unregister(Widget widget) => _members.remove(widget);

  /// All currently registered members.
  Iterable<Widget> get members => _members;

  /// Number of registered members.
  int get memberCount => _members.length;

  /// Whether this group has any members.
  bool get isEmpty => _members.isEmpty;

  /// Whether this group has members.
  bool get isNotEmpty => _members.isNotEmpty;

  /// Resolves the full canonical path for this group.
  ///
  /// Uses [TomNodeScope] to prepend route/container context.
  String resolveGroupPath(BuildContext context) {
    final scope = TomNodeScope.of(context);
    return scope?.appendGroup(groupId) ??
        TomIdPrefix.prefixed(TomIdPrefix.group, groupId);
  }

  /// Checks if this group is visible according to authorization.
  bool isVisible(BuildContext context) {
    final fullPath = resolveGroupPath(context);
    return TomUIAuthorization.resolveAuth(fullPath).visible;
  }

  /// Checks if this group is readonly according to authorization.
  bool isReadonly(BuildContext context) {
    final fullPath = resolveGroupPath(context);
    return TomUIAuthorization.resolveAuth(fullPath).readonly;
  }

  /// Gets the full authorization state for this group.
  TomAuthState getAuth(BuildContext context) {
    final fullPath = resolveGroupPath(context);
    return TomUIAuthorization.resolveAuth(fullPath);
  }
}
