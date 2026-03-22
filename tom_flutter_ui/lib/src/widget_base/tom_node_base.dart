import 'package:flutter/widgets.dart';

import '../resource_auth/tom_id_prefix.dart';
import '../resource_auth/tom_resources.dart';

/// Base class for all Tom UI elements (widgets, actions, containers).
///
/// Provides:
/// - [tomId] — unique ID within its scope, prefixed at resolution time.
/// - [tomGroup] — optional group membership (0 or 1).
/// - Resource path resolution via [resolveResourceBasePath].
/// - Debug identity via [debugLabel].
abstract class TomNodeBase extends StatelessWidget {
  /// The plain (unprefixed) ID for this node.
  final String? tomId;

  /// The group this node belongs to, if any.
  final String? tomGroup;

  const TomNodeBase({super.key, this.tomId, this.tomGroup});

  /// The prefix applied to this node's ID when building the canonical path.
  ///
  /// Override in subclasses: widgets → 'w-', containers → 'c-', etc.
  String get idPrefix => TomIdPrefix.widget;

  /// Resolves the canonical resource base path for this node by walking up
  /// the widget tree via [AclScope] and prepending ancestor IDs.
  ///
  /// Returns `null` if this node has no [tomId].
  String? resolveResourceBasePath(BuildContext context) {
    if (tomId == null) return null;
    final prefixedId = TomIdPrefix.prefixed(idPrefix, tomId!);

    // Walk up AclScope to collect parent path segments
    // This integrates with the existing AclScope InheritedWidget
    final parentPath = _resolveParentPath(context);
    if (parentPath != null && parentPath.isNotEmpty) {
      return '$parentPath.$prefixedId';
    }
    return prefixedId;
  }

  String? _resolveParentPath(BuildContext context) {
    // Look for TomNodeScope (if one exists in the ancestor chain)
    final scope = context.dependOnInheritedWidgetOfExactType<TomNodeScope>();
    return scope?.fullIdPath;
  }

  /// Resolves a text resource relative to this node's base path.
  ///
  /// Returns the resolved text, or the full key as a development fallback.
  String resolveResource(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return suffix;
    return TomUIResources.resolveText(basePath, suffix);
  }

  /// Debug description for this node.
  String get debugLabel {
    final parts = <String>[];
    if (tomId != null) parts.add('id: $tomId');
    if (tomGroup != null) parts.add('group: $tomGroup');
    return '${runtimeType.toString()}(${parts.join(', ')})';
  }
}

/// InheritedWidget providing the current node's identity context to descendants.
class TomNodeScope extends InheritedWidget {
  final String? fullIdPath;
  final String? groupName;

  const TomNodeScope({
    super.key,
    required super.child,
    this.fullIdPath,
    this.groupName,
  });

  static TomNodeScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TomNodeScope>();
  }

  @override
  bool updateShouldNotify(TomNodeScope oldWidget) {
    return fullIdPath != oldWidget.fullIdPath ||
        groupName != oldWidget.groupName;
  }
}
