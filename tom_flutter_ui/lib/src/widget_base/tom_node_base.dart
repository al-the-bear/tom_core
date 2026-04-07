import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../resource_auth/tom_colors.dart';
import '../resource_auth/tom_icons.dart';
import '../resource_auth/tom_resources.dart';

/// Base class for all Tom UI elements (widgets, actions, containers).
///
/// Provides:
/// - [tomId] — unique ID within its scope.
/// - [tomGroup] — optional group membership.
/// - [scope] — optional explicit scope (defaults to [TomScope.current]).
/// - [authorizer] — optional per-widget authorizer.
/// - [authorizerStrategy] — how authorizer interacts with resource auth.
/// - [uiStateController] — build-time state narrowing callback.
/// - Resource path resolution via [basePath].
/// - Debug identity via [debugLabel].
///
/// Resource paths are constructed as: `<scopePath>.<tomId>` where scopePath
/// comes from either the explicit [scope] or the current [TomScope].
///
/// Implements [TomAuthorizable] for type-safe group registration and
/// authorization system participation.
abstract class TomNodeBase extends StatelessWidget implements TomAuthorizable {
  @override
  final String? tomId;

  @override
  final TomAuthorizationGroup? tomGroup;

  /// Optional explicit scope for resource/auth lookups.
  ///
  /// When provided, this scope is used instead of [TomScope.current].
  final TomScope? scope;

  /// Optional per-widget authorizer that can modify authorization outcomes.
  ///
  /// When set, the authorizer is consulted after resource-based authorization
  /// and can modify the effective state according to [authorizerStrategy].
  final TomAuthorizer? authorizer;

  /// Strategy controlling how [authorizer] interacts with resource auth.
  ///
  /// Defaults to [TomAuthorizerStrategy.authorizerNarrowsOnly].
  final TomAuthorizerStrategy authorizerStrategy;

  /// Build-time callback that can further narrow the widget's state.
  ///
  /// Runs at build time (not construction time) and can only narrow,
  /// never widen, the effective authorization state.
  final TomUIStateController? uiStateController;

  /// The scope that was active when this widget was constructed.
  final TomScope constructionScope;

  /// The resolved canonical resource base path for this node.
  final String? basePath;

  TomNodeBase({
    super.key,
    this.tomId,
    this.tomGroup,
    this.scope,
    this.authorizer,
    this.authorizerStrategy = TomAuthorizerStrategy.authorizerNarrowsOnly,
    this.uiStateController,
  })  : constructionScope = scope ?? TomScope.current,
        basePath = _resolveBasePath(tomId, scope) {
      tomGroup?.register(this);
  }

  static String? _resolveBasePath(String? tomId, TomScope? scope) {
    if (tomId == null) return null;
    final effectiveScope = scope ?? TomScope.current;
    final scopePath = effectiveScope.getScopePath();
    if (scopePath.isNotEmpty) return '$scopePath.$tomId';
    return tomId;
  }

  /// Resolves a text resource relative to this node's base path.
  ///
  /// Returns the resolved text, or the full key as a development fallback.
  String resolveResource(String suffix) {
    if (basePath == null) return suffix;
    return TomUIResources.resolveText(basePath!, suffix);
  }

  /// Resolves a text resource relative to this node's base path.
  ///
  /// Returns `null` if:
  /// - This node has no [tomId]
  /// - No resource exists for this suffix
  String? resolveResourceOrNull(String suffix) {
    if (basePath == null) return null;
    if (!TomUIResources.resourceExists(basePath!, suffix)) return null;
    return TomUIResources.resolveText(basePath!, suffix);
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
  String resolveResourceOrFail(String suffix) {
    if (basePath == null) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a tomId for '
        'resource lookup. Widget: $runtimeType',
      );
    }
    if (!TomUIResources.resourceExists(basePath!, suffix)) {
      return '$basePath.$suffix';
    }
    return TomUIResources.resolveText(basePath!, suffix);
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
  IconData? resolveIcon() {
    if (basePath == null) return null;

    // Get icon name from resources
    final iconName = TomUIResources.resolveText(basePath!, 'icon');

    // Skip if it returns the key itself (no resource found)
    if (iconName.endsWith('.icon')) return null;

    // Look up IconData from icon provider
    return TomUIIcons.resolveIcon(iconName);
  }

  // ===========================================================================
  // Typed Resource Resolution
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
  Color? resolveColorOrNull(String suffix) {
    if (basePath == null) return null;
    return TomUIResources.resolveColor(basePath!, suffix);
  }

  /// Resolves a required color from resources relative to this node's base path.
  ///
  /// Throws [StateError] if:
  /// - This node has no [tomId] (resource lookup is impossible)
  /// - No resource exists for this suffix
  /// - The value exists but cannot be parsed as a color
  Color resolveColorOrFail(String suffix) {
    if (basePath == null) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a tomId for '
        'resource lookup. Widget: $runtimeType',
      );
    }
    if (!TomUIResources.resourceExists(basePath!, suffix)) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a color '
        'resource value at $basePath.$suffix. Widget: $runtimeType',
      );
    }
    final value = TomUIResources.resolveColor(basePath!, suffix);
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
  double? resolveDoubleOrNull(String suffix) {
    if (basePath == null) return null;
    return TomUIResources.resolveDouble(basePath!, suffix);
  }

  /// Resolves a required double from resources relative to this node's base path.
  ///
  /// Throws [StateError] if:
  /// - This node has no [tomId] (resource lookup is impossible)
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

  /// Resolves an int from resources relative to this node's base path.
  ///
  /// Returns `null` if:
  /// - This node has no [tomId]
  /// - No resource exists for this suffix
  /// - The value is not numeric
  int? resolveIntOrNull(String suffix) {
    if (basePath == null) return null;
    return TomUIResources.resolveInt(basePath!, suffix);
  }

  /// Resolves a required int from resources relative to this node's base path.
  ///
  /// Throws [StateError] if:
  /// - This node has no [tomId] (resource lookup is impossible)
  /// - No resource exists for this suffix
  /// - The value exists but is not numeric
  int resolveIntOrFail(String suffix) {
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
    final value = TomUIResources.resolveInt(basePath!, suffix);
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
  bool? resolveBoolOrNull(String suffix) {
    if (basePath == null) return null;
    return TomUIResources.resolveBool(basePath!, suffix);
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
  EdgeInsets? resolveEdgeInsetsOrNull(String suffix) {
    if (basePath == null) return null;
    return TomUIResources.resolveEdgeInsets(basePath!, suffix);
  }

  /// Resolves a list from resources relative to this node's base path.
  ///
  /// Returns `null` if:
  /// - This node has no [tomId]
  /// - No resource exists for this suffix
  /// - The resource is not a list
  List<dynamic>? resolveListOrNull(String suffix) {
    if (basePath == null) return null;
    return TomUIResources.resolveList(basePath!, suffix);
  }

  /// Resolves a map from resources relative to this node's base path.
  ///
  /// Returns `null` if:
  /// - This node has no [tomId]
  /// - No resource exists for this suffix
  /// - The resource is not a map
  Map<String, dynamic>? resolveMapOrNull(String suffix) {
    if (basePath == null) return null;
    return TomUIResources.resolveMap(basePath!, suffix);
  }

  /// Resolves any value from resources relative to this node's base path.
  ///
  /// Returns `null` if:
  /// - This node has no [tomId]
  /// - No resource exists for this suffix
  dynamic resolveValueOrNull(String suffix) {
    if (basePath == null) return null;
    return TomUIResources.resolveValue(basePath!, suffix);
  }

  /// Debug description for this node.
  String get debugLabel {
    final parts = <String>[];
    if (tomId != null) parts.add('id: $tomId');
    if (tomGroup != null) parts.add('group: ${tomGroup!.groupId}');
    return '${runtimeType.toString()}(${parts.join(', ')})';
  }
}
