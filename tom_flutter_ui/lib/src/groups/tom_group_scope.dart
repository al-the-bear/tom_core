import 'package:flutter/widgets.dart';

import '../resource_auth/tom_auth_state.dart';
import '../resource_auth/tom_id_prefix.dart';
import '../widget_base/tom_node_base.dart';
import 'tom_group.dart';
import 'tom_groups.dart';

/// Widget that defines an explicit group scope.
///
/// Children can reference the group via [TomNodeScope.of] and register with it.
/// The group is automatically hidden if authorization denies visibility.
///
/// Use [TomGroupScope] when you need a group boundary without an ACL container:
///
/// ```dart
/// TomGroupScope(
///   groupId: 'shippingPanel',
///   child: Column(children: [
///     TomTextField(tomId: 'street', tomGroup: 'shippingPanel', ...),
///     TomTextField(tomId: 'city', tomGroup: 'shippingPanel', ...),
///   ]),
/// )
/// ```
///
/// For ACL containers with IDs, the container acts as an implicit group scope.
class TomGroupScope extends StatelessWidget {
  /// The local group ID (without prefix).
  final String groupId;

  /// The child widget tree.
  final Widget child;

  /// Whether to check authorization and hide if the group is hidden.
  ///
  /// Defaults to `true`. Set to `false` to skip authorization check.
  final bool checkAuth;

  const TomGroupScope({
    super.key,
    required this.groupId,
    required this.child,
    this.checkAuth = true,
  });

  @override
  Widget build(BuildContext context) {
    if (checkAuth) {
      final group = TomGroups.of(groupId);
      final auth = group.getAuth(context);
      if (!auth.visible) {
        return const SizedBox.shrink();
      }
    }

    return TomNodeScope.extend(
      context,
      groupId: groupId,
      child: child,
    );
  }

  /// Resolves the full canonical path for this group.
  String resolveGroupPath(BuildContext context) {
    final scope = TomNodeScope.of(context);
    return scope?.appendGroup(groupId) ??
        TomIdPrefix.prefixed(TomIdPrefix.group, groupId);
  }

  /// Gets the group instance for this scope.
  TomGroup getGroup() => TomGroups.of(groupId);

  /// Gets the authorization state for this group.
  TomAuthState getAuth(BuildContext context) {
    return TomUIAuthorization.resolveAuth(resolveGroupPath(context));
  }
}
