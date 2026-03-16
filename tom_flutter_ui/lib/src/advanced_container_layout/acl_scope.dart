import 'package:flutter/widgets.dart';

/// Provides ID and group metadata to widgets inside an ACL layout.
///
/// Injected by [AclContainer] around each component. Access via
/// `AclScope.of(context)`.
class AclScope extends InheritedWidget {
  /// The container's ID (from `setAclId`), or null if not set.
  final String? containerId;

  /// This component's ID (from `setId`), or null if not set.
  final String? componentId;

  /// This row's ID (from `setRowId`), or null if not set.
  final String? rowId;

  /// The group this component belongs to, or null if ungrouped.
  final String? groupName;

  /// The full dot-separated ID path from root to this component.
  final String? fullIdPath;

  const AclScope({
    super.key,
    required super.child,
    this.containerId,
    this.componentId,
    this.rowId,
    this.groupName,
    this.fullIdPath,
  });

  static AclScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AclScope>();
  }

  @override
  bool updateShouldNotify(AclScope oldWidget) {
    return containerId != oldWidget.containerId ||
        componentId != oldWidget.componentId ||
        rowId != oldWidget.rowId ||
        groupName != oldWidget.groupName ||
        fullIdPath != oldWidget.fullIdPath;
  }
}
