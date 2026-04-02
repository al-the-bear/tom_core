import 'package:flutter/widgets.dart';

import 'tom_colors.dart';
import 'tom_icons.dart';

/// Adapter that resolves user-facing resources by base path and suffix.
///
/// Resources are locale-aware and process-context-aware. The correct resource
/// set is resolved during app initialization — widgets simply look up keys.
///
/// This adapter supports various value types:
/// - Text strings via [resolveText]
/// - Any typed value via [resolveValue]
/// - Lists via [resolveList]
/// - Maps via [resolveMap]
/// - Colors via [resolveColor] (resolved through [TomUIColors])
/// - Icons via [resolveIcon] (resolved through [TomUIIcons])
/// - Numeric and boolean primitives via dedicated methods
abstract class TomUIResourceAdapter {
  // ===========================================================================
  // Core Resolution Methods
  // ===========================================================================

  /// Resolves a text resource for [basePath] with [suffix].
  ///
  /// Returns the resolved string, or the full key as a fallback indicator
  /// if no resource is found.
  String resolveText(String basePath, String suffix);

  /// Whether a resource exists for [basePath] with [suffix].
  bool resourceExists(String basePath, String suffix);

  // ===========================================================================
  // Type-Aware Resolution Methods (NEW - Phase 1)
  // ===========================================================================

  /// Resolves any value from resources for [basePath] with [suffix].
  ///
  /// Returns `null` if no resource exists. The caller is responsible for
  /// type checking or casting the result.
  dynamic resolveValue(String basePath, String suffix) => null;

  /// Resolves a list from resources for [basePath] with [suffix].
  ///
  /// Returns `null` if no resource exists or the resource is not a list.
  /// List elements can be any JSON-serializable type.
  List<dynamic>? resolveList(String basePath, String suffix) => null;

  /// Resolves a map from resources for [basePath] with [suffix].
  ///
  /// Returns `null` if no resource exists or the resource is not a map.
  /// Useful for structured data like TextStyle or EdgeInsets specifications.
  Map<String, dynamic>? resolveMap(String basePath, String suffix) => null;

  // ===========================================================================
  // Typed Resolution Helpers (NEW - Phase 1)
  // ===========================================================================

  /// Resolves a color from resources for [basePath] with [suffix].
  ///
  /// The resource value should be a color name (e.g., "mRed", "cSystemBlue")
  /// or hex string (e.g., "#FF5733", "#80FF5733") that [TomUIColors] can resolve.
  ///
  /// Returns `null` if no resource exists or the color cannot be resolved.
  Color? resolveColor(String basePath, String suffix) {
    final value = resolveValue(basePath, suffix);
    if (value == null) return null;
    if (value is String) return TomUIColors.resolveColor(value);
    if (value is int) return Color(value);
    return null;
  }

  /// Resolves an icon from resources for [basePath] with [suffix].
  ///
  /// The resource value should be an icon name (e.g., "mAdd", "mSettings")
  /// that [TomUIIcons] can resolve.
  ///
  /// Returns `null` if no resource exists or the icon cannot be resolved.
  IconData? resolveIcon(String basePath, String suffix) {
    final value = resolveValue(basePath, suffix);
    if (value == null) return null;
    if (value is String) return TomUIIcons.resolveIcon(value);
    return null;
  }

  /// Resolves a double from resources for [basePath] with [suffix].
  ///
  /// Accepts both double and int values in the JSON resource.
  /// Returns `null` if no resource exists or the value is not numeric.
  double? resolveDouble(String basePath, String suffix) {
    final value = resolveValue(basePath, suffix);
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Resolves an int from resources for [basePath] with [suffix].
  ///
  /// Accepts both int and double values (truncated) in the JSON resource.
  /// Returns `null` if no resource exists or the value is not numeric.
  int? resolveInt(String basePath, String suffix) {
    final value = resolveValue(basePath, suffix);
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Resolves a bool from resources for [basePath] with [suffix].
  ///
  /// Accepts bool values or string "true"/"false".
  /// Returns `null` if no resource exists or the value is not boolean-like.
  bool? resolveBool(String basePath, String suffix) {
    final value = resolveValue(basePath, suffix);
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return null;
  }

  /// Resolves edge insets from resources for [basePath] with [suffix].
  ///
  /// Accepts:
  /// - A single number for uniform insets
  /// - An array [all], [horizontal, vertical], or [left, top, right, bottom]
  /// - A map with keys: "all", "horizontal", "vertical", "left", "top", "right", "bottom"
  ///
  /// Returns `null` if no resource exists or the format is not recognized.
  EdgeInsets? resolveEdgeInsets(String basePath, String suffix) {
    final value = resolveValue(basePath, suffix);
    return _parseEdgeInsets(value);
  }

  /// Parses edge insets from various formats.
  static EdgeInsets? _parseEdgeInsets(dynamic value) {
    if (value == null) return null;

    // Single number = uniform
    if (value is num) return EdgeInsets.all(value.toDouble());

    // Array format
    if (value is List) {
      if (value.length == 1 && value[0] is num) {
        return EdgeInsets.all((value[0] as num).toDouble());
      }
      if (value.length == 2 && value[0] is num && value[1] is num) {
        return EdgeInsets.symmetric(
          horizontal: (value[0] as num).toDouble(),
          vertical: (value[1] as num).toDouble(),
        );
      }
      if (value.length == 4) {
        return EdgeInsets.only(
          left: (value[0] as num?)?.toDouble() ?? 0,
          top: (value[1] as num?)?.toDouble() ?? 0,
          right: (value[2] as num?)?.toDouble() ?? 0,
          bottom: (value[3] as num?)?.toDouble() ?? 0,
        );
      }
    }

    // Map format
    if (value is Map<String, dynamic>) {
      if (value.containsKey('all')) {
        return EdgeInsets.all((value['all'] as num).toDouble());
      }
      return EdgeInsets.only(
        left: (value['left'] as num?)?.toDouble() ??
            (value['horizontal'] as num?)?.toDouble() ??
            0,
        top: (value['top'] as num?)?.toDouble() ??
            (value['vertical'] as num?)?.toDouble() ??
            0,
        right: (value['right'] as num?)?.toDouble() ??
            (value['horizontal'] as num?)?.toDouble() ??
            0,
        bottom: (value['bottom'] as num?)?.toDouble() ??
            (value['vertical'] as num?)?.toDouble() ??
            0,
      );
    }

    return null;
  }
}

/// Global resource singleton.
///
/// Initialized at app startup with a concrete adapter. Widgets resolve
/// labels, hints, error messages, colors, icons, and other values through
/// this — no [InheritedWidget] or [BuildContext] needed.
///
/// Resources are resolved using a 4-level fallback chain:
/// 1. Full identity path (e.g., `r-checkout.c-shipping.f-address.w-street`)
/// 2. Without route prefix (e.g., `c-shipping.f-address.w-street`)
/// 3. Form + widget only (e.g., `f-address.w-street`)
/// 4. Widget only (e.g., `w-street`)
///
/// Text resources fall back to the full key string when no entry is found.
/// Value resources (color, icon, etc.) fall back to `null`.
///
/// ```dart
/// // App startup
/// TomUIResources.adapter = TomKernelResourceAdapter();
///
/// // Usage anywhere
/// final label = TomUIResources.resolveText('r-checkout.w-email', 'label');
/// final bgColor = TomUIResources.resolveColor('r-checkout.w-email', 'backgroundColor');
/// ```
class TomUIResources {
  TomUIResources._();

  static TomUIResourceAdapter? _adapter;

  static set adapter(TomUIResourceAdapter adapter) => _adapter = adapter;

  // ===========================================================================
  // Fallback Path Generation
  // ===========================================================================

  /// Generates the fallback path sequence for resource resolution.
  ///
  /// Order: full path → without route → form+widget → widget only.
  /// Only yields paths that differ from the full path.
  static Iterable<String> _fallbackPaths(String basePath) sync* {
    yield basePath;

    // Level 2: strip route prefix (r-xxx.)
    final noRoute = _stripRoutePrefix(basePath);
    if (noRoute != null) yield noRoute;

    // Level 3: form + widget (f-xxx.w-xxx or f-xxx.a-xxx etc.)
    final formWidget = _extractFormAndBeyond(basePath);
    if (formWidget != null) yield formWidget;

    // Level 4: widget/action only (w-xxx or a-xxx etc.)
    final leafOnly = _extractLeaf(basePath);
    if (leafOnly != null) yield leafOnly;
  }

  /// Strips the route prefix (r-<id>.) from the start of a path.
  /// Returns null if there's no route prefix or if the result would be empty.
  static String? _stripRoutePrefix(String path) {
    if (!path.startsWith('r-')) return null;
    final dotIndex = path.indexOf('.');
    if (dotIndex < 0 || dotIndex + 1 >= path.length) return null;
    return path.substring(dotIndex + 1);
  }

  /// Extracts form + leaf segments (f-xxx.w-xxx) from the path.
  /// Returns null if there's no form segment or the result equals the full path.
  static String? _extractFormAndBeyond(String path) {
    final formIndex = path.indexOf('f-');
    if (formIndex < 0) return null;
    final result = path.substring(formIndex);
    if (result == path) return null; // No shorter path
    return result;
  }

  /// Extracts the leaf segment (w-xxx, a-xxx, ac-xxx) from the path.
  /// Returns null if there's no leaf or the result equals the full path.
  static String? _extractLeaf(String path) {
    // Find the last segment that starts with w-, a-, or ac-
    // by searching for the rightmost leaf prefix.
    int leafIndex = -1;
    for (final prefix in ['w-', 'a-', 'ac-']) {
      final idx = path.lastIndexOf('.$prefix');
      if (idx >= 0 && idx > leafIndex) {
        leafIndex = idx + 1; // skip the dot
      }
    }
    // Also check if path starts with a leaf prefix (no dot before it)
    if (leafIndex < 0) {
      for (final prefix in ['w-', 'a-', 'ac-']) {
        if (path.startsWith(prefix)) {
          return null; // Already just the leaf
        }
      }
      return null;
    }
    final result = path.substring(leafIndex);
    if (result == path) return null;
    return result;
  }

  // ===========================================================================
  // Core Resolution Methods
  // ===========================================================================

  /// Resolves the text resource for [basePath] + [suffix].
  ///
  /// Uses the 4-level fallback chain. If no resource is found at any level,
  /// returns the full key (`basePath.suffix`) as a visible development
  /// indicator.
  static String resolveText(String basePath, String suffix) {
    if (_adapter == null) return '$basePath.$suffix';

    for (final path in _fallbackPaths(basePath)) {
      if (_adapter!.resourceExists(path, suffix)) {
        return _adapter!.resolveText(path, suffix);
      }
    }

    // Text fallback: return the full key as displayed value
    return '$basePath.$suffix';
  }

  /// Whether a resource exists for [basePath] + [suffix].
  ///
  /// Checks all 4 fallback levels.
  static bool resourceExists(String basePath, String suffix) {
    if (_adapter == null) return false;

    for (final path in _fallbackPaths(basePath)) {
      if (_adapter!.resourceExists(path, suffix)) return true;
    }
    return false;
  }

  // ===========================================================================
  // Type-Aware Resolution Methods
  // ===========================================================================

  /// Resolves any value from resources for [basePath] + [suffix].
  ///
  /// Uses the 4-level fallback chain. Returns `null` if no resource found.
  static dynamic resolveValue(String basePath, String suffix) {
    if (_adapter == null) return null;

    for (final path in _fallbackPaths(basePath)) {
      if (_adapter!.resourceExists(path, suffix)) {
        return _adapter!.resolveValue(path, suffix);
      }
    }
    return null;
  }

  /// Resolves a list from resources for [basePath] + [suffix].
  ///
  /// Uses the 4-level fallback chain. Returns `null` if no resource found
  /// or the resource is not a list.
  static List<dynamic>? resolveList(String basePath, String suffix) {
    if (_adapter == null) return null;

    for (final path in _fallbackPaths(basePath)) {
      if (_adapter!.resourceExists(path, suffix)) {
        return _adapter!.resolveList(path, suffix);
      }
    }
    return null;
  }

  /// Resolves a map from resources for [basePath] + [suffix].
  ///
  /// Uses the 4-level fallback chain. Returns `null` if no resource found
  /// or the resource is not a map.
  static Map<String, dynamic>? resolveMap(String basePath, String suffix) {
    if (_adapter == null) return null;

    for (final path in _fallbackPaths(basePath)) {
      if (_adapter!.resourceExists(path, suffix)) {
        return _adapter!.resolveMap(path, suffix);
      }
    }
    return null;
  }

  // ===========================================================================
  // Typed Resolution Helpers
  // ===========================================================================

  /// Resolves a color from resources for [basePath] + [suffix].
  ///
  /// Uses the 4-level fallback chain. Returns `null` if no resource found
  /// or the color cannot be resolved.
  static Color? resolveColor(String basePath, String suffix) {
    if (_adapter == null) return null;

    for (final path in _fallbackPaths(basePath)) {
      if (_adapter!.resourceExists(path, suffix)) {
        return _adapter!.resolveColor(path, suffix);
      }
    }
    return null;
  }

  /// Resolves an icon from resources for [basePath] + [suffix].
  ///
  /// Uses the 4-level fallback chain. Returns `null` if no resource found
  /// or the icon cannot be resolved.
  static IconData? resolveIcon(String basePath, String suffix) {
    if (_adapter == null) return null;

    for (final path in _fallbackPaths(basePath)) {
      if (_adapter!.resourceExists(path, suffix)) {
        return _adapter!.resolveIcon(path, suffix);
      }
    }
    return null;
  }

  /// Resolves a double from resources for [basePath] + [suffix].
  ///
  /// Uses the 4-level fallback chain. Returns `null` if no resource found
  /// or the value is not numeric.
  static double? resolveDouble(String basePath, String suffix) {
    if (_adapter == null) return null;

    for (final path in _fallbackPaths(basePath)) {
      if (_adapter!.resourceExists(path, suffix)) {
        return _adapter!.resolveDouble(path, suffix);
      }
    }
    return null;
  }

  /// Resolves an int from resources for [basePath] + [suffix].
  ///
  /// Uses the 4-level fallback chain. Returns `null` if no resource found
  /// or the value is not numeric.
  static int? resolveInt(String basePath, String suffix) {
    if (_adapter == null) return null;

    for (final path in _fallbackPaths(basePath)) {
      if (_adapter!.resourceExists(path, suffix)) {
        return _adapter!.resolveInt(path, suffix);
      }
    }
    return null;
  }

  /// Resolves a bool from resources for [basePath] + [suffix].
  ///
  /// Uses the 4-level fallback chain. Returns `null` if no resource found
  /// or the value is not boolean-like.
  static bool? resolveBool(String basePath, String suffix) {
    if (_adapter == null) return null;

    for (final path in _fallbackPaths(basePath)) {
      if (_adapter!.resourceExists(path, suffix)) {
        return _adapter!.resolveBool(path, suffix);
      }
    }
    return null;
  }

  /// Resolves edge insets from resources for [basePath] + [suffix].
  ///
  /// Uses the 4-level fallback chain. Accepts various formats in the
  /// JSON resource:
  /// - A single number for uniform insets
  /// - An array [all], [horizontal, vertical], or [left, top, right, bottom]
  /// - A map with keys: "all", "horizontal", "vertical", "left", "top", "right", "bottom"
  ///
  /// Returns `null` if no resource found or the format is not recognized.
  static EdgeInsets? resolveEdgeInsets(String basePath, String suffix) {
    if (_adapter == null) return null;

    for (final path in _fallbackPaths(basePath)) {
      if (_adapter!.resourceExists(path, suffix)) {
        return _adapter!.resolveEdgeInsets(path, suffix);
      }
    }
    return null;
  }

  /// Resets the adapter. Intended for testing only.
  static void reset() => _adapter = null;
}
