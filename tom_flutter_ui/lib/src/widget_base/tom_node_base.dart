import 'package:flutter/widgets.dart';

import '../resource_auth/tom_colors.dart';
import '../resource_auth/tom_icons.dart';
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

  /// Resolves a text resource relative to this node's base path.
  ///
  /// Returns `null` if:
  /// - This node has no [tomId]
  /// - No resource exists for this suffix
  String? resolveResourceOrNull(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    if (!TomUIResources.resourceExists(basePath, suffix)) return null;
    return TomUIResources.resolveText(basePath, suffix);
  }

  /// Resolves a required text resource relative to this node's base path.
  ///
  /// Use this for required text fields (label, tooltip) that must be provided
  /// either explicitly or via resources.
  ///
  /// Throws [StateError] if:
  /// - This node has no [tomId] (resource lookup is impossible)
  ///
  /// If [tomId] is set but no resource exists, returns the looked-up key
  /// (`<basePath>.<suffix>`) for development visibility.
  String resolveResourceOrFail(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a tomId for '
        'resource lookup. Widget: $runtimeType',
      );
    }
    if (!TomUIResources.resourceExists(basePath, suffix)) {
      return '$basePath.$suffix';
    }
    return TomUIResources.resolveText(basePath, suffix);
  }

  /// Resolves an icon from resources relative to this node's base path.
  ///
  /// Returns `null` if:
  /// - This node has no [tomId]
  /// - No icon resource exists for this node
  /// - The icon name cannot be resolved to an [IconData]
  ///
  /// The icon is resolved in two steps:
  /// 1. Get icon name from resources (using suffix 'icon')
  /// 2. Look up [IconData] from [TomUIIcons] provider
  IconData? resolveIcon(BuildContext context) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;

    // Get icon name from resources
    final iconName = TomUIResources.resolveText(basePath, 'icon');

    // Skip if it returns the key itself (no resource found)
    if (iconName.endsWith('.icon')) return null;

    // Look up IconData from icon provider
    return TomUIIcons.resolveIcon(iconName);
  }

  // ===========================================================================
  // Typed Resource Resolution (Phase 1)
  // ===========================================================================

  /// Resolves a color from resources relative to this node's base path.
  ///
  /// Returns `null` if:
  /// - This node has no [tomId]
  /// - No color resource exists for this suffix
  /// - The color name cannot be resolved to a [Color]
  ///
  /// The resource value should be a color name (e.g., "mRed", "cSystemBlue")
  /// or hex string (e.g., "#FF5733") that [TomUIColors] can resolve.
  Color? resolveColorOrNull(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomUIResources.resolveColor(basePath, suffix);
  }

  /// Resolves a double from resources relative to this node's base path.
  ///
  /// Returns `null` if:
  /// - This node has no [tomId]
  /// - No resource exists for this suffix
  /// - The value is not numeric
  double? resolveDoubleOrNull(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomUIResources.resolveDouble(basePath, suffix);
  }

  /// Resolves a required double from resources relative to this node's base path.
  ///
  /// Throws [StateError] if:
  /// - This node has no [tomId] (resource lookup is impossible)
  /// - No resource exists for this suffix
  /// - The value exists but is not numeric
  double resolveDoubleOrFail(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a tomId for '
        'resource lookup. Widget: $runtimeType',
      );
    }
    if (!TomUIResources.resourceExists(basePath, suffix)) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a numeric '
        'resource value at $basePath.$suffix. Widget: $runtimeType',
      );
    }
    final value = TomUIResources.resolveDouble(basePath, suffix);
    if (value == null) {
      throw StateError(
        'Resource $basePath.$suffix must be numeric for widget $runtimeType.',
      );
    }
    return value;
  }

  /// Resolves an int from resources relative to this node's base path.
  ///
  /// Returns `null` if:
  /// - This node has no [tomId]
  /// - No resource exists for this suffix
  /// - The value is not numeric
  int? resolveIntOrNull(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomUIResources.resolveInt(basePath, suffix);
  }

  /// Resolves a bool from resources relative to this node's base path.
  ///
  /// Returns `null` if:
  /// - This node has no [tomId]
  /// - No resource exists for this suffix
  /// - The value is not boolean-like
  bool? resolveBoolOrNull(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomUIResources.resolveBool(basePath, suffix);
  }

  /// Resolves edge insets from resources relative to this node's base path.
  ///
  /// Returns `null` if:
  /// - This node has no [tomId]
  /// - No resource exists for this suffix
  /// - The format is not recognized
  ///
  /// Accepts various formats in the JSON resource:
  /// - A single number for uniform insets
  /// - An array [all], [horizontal, vertical], or [left, top, right, bottom]
  /// - A map with keys: "all", "horizontal", "vertical", "left", "top", "right", "bottom"
  EdgeInsets? resolveEdgeInsetsOrNull(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomUIResources.resolveEdgeInsets(basePath, suffix);
  }

  /// Resolves a list from resources relative to this node's base path.
  ///
  /// Returns `null` if:
  /// - This node has no [tomId]
  /// - No resource exists for this suffix
  /// - The resource is not a list
  List<dynamic>? resolveListOrNull(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomUIResources.resolveList(basePath, suffix);
  }

  /// Resolves a map from resources relative to this node's base path.
  ///
  /// Returns `null` if:
  /// - This node has no [tomId]
  /// - No resource exists for this suffix
  /// - The resource is not a map
  Map<String, dynamic>? resolveMapOrNull(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomUIResources.resolveMap(basePath, suffix);
  }

  /// Resolves any value from resources relative to this node's base path.
  ///
  /// Returns `null` if:
  /// - This node has no [tomId]
  /// - No resource exists for this suffix
  dynamic resolveValueOrNull(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomUIResources.resolveValue(basePath, suffix);
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
///
/// Propagates route, container, group, and form IDs down the widget tree.
/// Each ID segment is optional and contributes to the canonical path.
///
/// Canonical path format:
/// ```
/// r-<route>.c-<container>.g-<group>.f-<form>.w-<widget>
/// ```
class TomNodeScope extends InheritedWidget {
  /// The route ID (without prefix).
  final String? routeId;

  /// The container ID (without prefix).
  final String? containerId;

  /// The group ID (without prefix).
  final String? groupId;

  /// The form ID (without prefix).
  final String? formId;

  /// Legacy: full pre-computed ID path (for backwards compatibility).
  final String? fullIdPath;

  const TomNodeScope({
    super.key,
    required super.child,
    this.routeId,
    this.containerId,
    this.groupId,
    this.formId,
    this.fullIdPath,
  });

  /// Creates a scope that extends the parent scope with additional IDs.
  factory TomNodeScope.extend(
    BuildContext context, {
    Key? key,
    required Widget child,
    String? routeId,
    String? containerId,
    String? groupId,
    String? formId,
  }) {
    final parent = TomNodeScope.of(context);
    return TomNodeScope(
      key: key,
      routeId: routeId ?? parent?.routeId,
      containerId: containerId ?? parent?.containerId,
      groupId: groupId ?? parent?.groupId,
      formId: formId ?? parent?.formId,
      child: child,
    );
  }

  /// Appends a widget ID to create the canonical path.
  String appendWidget(String widgetId) {
    final parts = <String>[];
    if (routeId != null) parts.add('r-$routeId');
    if (containerId != null) parts.add('c-$containerId');
    if (groupId != null) parts.add('g-$groupId');
    if (formId != null) parts.add('f-$formId');
    parts.add('w-$widgetId');
    return parts.join('.');
  }

  /// Appends a group ID to create the canonical group path.
  String appendGroup(String gId) {
    final parts = <String>[];
    if (routeId != null) parts.add('r-$routeId');
    if (containerId != null) parts.add('c-$containerId');
    parts.add('g-$gId');
    return parts.join('.');
  }

  /// Appends a container ID to create the canonical container path.
  String appendContainer(String cId) {
    final parts = <String>[];
    if (routeId != null) parts.add('r-$routeId');
    if (containerId != null) parts.add('c-$containerId');
    parts.add('c-$cId');
    return parts.join('.');
  }

  /// Appends a form ID to create the canonical form path.
  String appendForm(String fId) {
    final parts = <String>[];
    if (routeId != null) parts.add('r-$routeId');
    if (containerId != null) parts.add('c-$containerId');
    if (groupId != null) parts.add('g-$groupId');
    parts.add('f-$fId');
    return parts.join('.');
  }

  static TomNodeScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TomNodeScope>();
  }

  @override
  bool updateShouldNotify(TomNodeScope oldWidget) {
    return routeId != oldWidget.routeId ||
        containerId != oldWidget.containerId ||
        groupId != oldWidget.groupId ||
        formId != oldWidget.formId ||
        fullIdPath != oldWidget.fullIdPath;
  }
}

