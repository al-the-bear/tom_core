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

  /// Resolves a required color from resources relative to this node's base path.
  ///
  /// Throws [StateError] if:
  /// - This node has no [tomId] (resource lookup is impossible)
  /// - No resource exists for this suffix
  /// - The value exists but cannot be parsed as a color
  Color resolveColorOrFail(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a tomId for '
        'resource lookup. Widget: $runtimeType',
      );
    }
    if (!TomUIResources.resourceExists(basePath, suffix)) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a color '
        'resource value at $basePath.$suffix. Widget: $runtimeType',
      );
    }
    final value = TomUIResources.resolveColor(basePath, suffix);
    if (value == null) {
      throw StateError(
        'Resource $basePath.$suffix must be a valid color for widget '
        '$runtimeType.',
      );
    }
    return value;
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

  /// Resolves a required int from resources relative to this node's base path.
  ///
  /// Throws [StateError] if:
  /// - This node has no [tomId] (resource lookup is impossible)
  /// - No resource exists for this suffix
  /// - The value exists but is not numeric
  int resolveIntOrFail(BuildContext context, String suffix) {
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
    final value = TomUIResources.resolveInt(basePath, suffix);
    if (value == null) {
      throw StateError(
        'Resource $basePath.$suffix must be an int for widget $runtimeType.',
      );
    }
    return value;
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
/// The [fullIdPath] contains only identity-scoped segments. Layout containers
/// (those with `idScope: false`) do NOT appear in descendant paths — they
/// resolve their own resources via [selfPathForContainer] but leave
/// [fullIdPath] unchanged for descendants.
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

  /// The canonical identity path for this scope.
  ///
  /// Contains only identity-scoped segments (route, identity containers,
  /// groups, forms). Layout containers are excluded.
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
  ///
  /// When [containerId] is provided:
  /// - If [containerIdScope] is `true` (identity container), the container ID
  ///   is appended to [fullIdPath] for descendants.
  /// - If [containerIdScope] is `false` (layout container, default), the
  ///   container ID is stored in [containerId] for self-path resolution but
  ///   does NOT modify [fullIdPath].
  factory TomNodeScope.extend(
    BuildContext context, {
    Key? key,
    required Widget child,
    String? routeId,
    String? containerId,
    bool containerIdScope = false,
    String? groupId,
    String? formId,
  }) {
    final parent = TomNodeScope.of(context);
    final effectiveRouteId = routeId ?? parent?.routeId;
    final effectiveContainerId = containerId ?? parent?.containerId;
    final effectiveGroupId = groupId ?? parent?.groupId;
    final effectiveFormId = formId ?? parent?.formId;

    // Build fullIdPath: only include identity-scoped container IDs.
    String? newFullIdPath;
    if (containerId != null && containerIdScope) {
      // Identity container — append to path.
      final parentPath = parent?.fullIdPath;
      final segment = TomIdPrefix.prefixed(TomIdPrefix.container, containerId);
      newFullIdPath = (parentPath != null && parentPath.isNotEmpty)
          ? '$parentPath.$segment'
          : segment;
    } else if (routeId != null && routeId != parent?.routeId) {
      // New route — rebuild path with route prefix.
      final segment = TomIdPrefix.prefixed(TomIdPrefix.route, routeId);
      final parentPath = parent?.fullIdPath;
      newFullIdPath = (parentPath != null && parentPath.isNotEmpty)
          ? '$parentPath.$segment'
          : segment;
    } else if (groupId != null && groupId != parent?.groupId) {
      // New group — append to path.
      final parentPath = parent?.fullIdPath;
      final segment = TomIdPrefix.prefixed(TomIdPrefix.group, groupId);
      newFullIdPath = (parentPath != null && parentPath.isNotEmpty)
          ? '$parentPath.$segment'
          : segment;
    } else if (formId != null && formId != parent?.formId) {
      // New form — append to path.
      final parentPath = parent?.fullIdPath;
      final segment = TomIdPrefix.prefixed(TomIdPrefix.form, formId);
      newFullIdPath = (parentPath != null && parentPath.isNotEmpty)
          ? '$parentPath.$segment'
          : segment;
    } else {
      newFullIdPath = parent?.fullIdPath;
    }

    return TomNodeScope(
      key: key,
      routeId: effectiveRouteId,
      containerId: effectiveContainerId,
      groupId: effectiveGroupId,
      formId: effectiveFormId,
      fullIdPath: newFullIdPath,
      child: child,
    );
  }

  /// Appends a widget ID to create the canonical widget path.
  ///
  /// Uses [fullIdPath] as the base (identity-only path), then appends
  /// the widget's prefixed ID.
  String appendWidget(String widgetId) {
    final base = fullIdPath;
    final segment = '${TomIdPrefix.widget}$widgetId';
    if (base != null && base.isNotEmpty) return '$base.$segment';
    return segment;
  }

  /// Appends a group ID to create the canonical group path.
  String appendGroup(String gId) {
    final base = fullIdPath;
    final segment = '${TomIdPrefix.group}$gId';
    if (base != null && base.isNotEmpty) return '$base.$segment';
    return segment;
  }

  /// Returns the self-path for a container: identity path + c-<id>.
  ///
  /// This is used by containers to resolve their OWN resources and auth,
  /// regardless of whether they are identity or layout containers.
  /// Does NOT modify the scope.
  String selfPathForContainer(String cId) {
    final base = fullIdPath;
    final segment = TomIdPrefix.prefixed(TomIdPrefix.container, cId);
    if (base != null && base.isNotEmpty) return '$base.$segment';
    return segment;
  }

  /// Returns the self-path for a row: identity path + rw-<id>.
  ///
  /// Used by rows to resolve their OWN resources and auth.
  /// Does NOT modify the scope.
  String selfPathForRow(String rowId) {
    final base = fullIdPath;
    final segment = TomIdPrefix.prefixed(TomIdPrefix.row, rowId);
    if (base != null && base.isNotEmpty) return '$base.$segment';
    return segment;
  }

  /// Appends a form ID to create the canonical form path.
  String appendForm(String fId) {
    final base = fullIdPath;
    final segment = '${TomIdPrefix.form}$fId';
    if (base != null && base.isNotEmpty) return '$base.$segment';
    return segment;
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

