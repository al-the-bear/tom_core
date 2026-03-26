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
  // Core Resolution Methods
  // ===========================================================================

  /// Resolves the text resource for [basePath] + [suffix].
  ///
  /// If no adapter is set, returns the full key (`basePath.suffix`) as a
  /// visible indicator that a resource is missing.
  static String resolveText(String basePath, String suffix) {
    return _adapter?.resolveText(basePath, suffix) ?? '$basePath.$suffix';
  }

  /// Whether a resource exists for [basePath] + [suffix].
  static bool resourceExists(String basePath, String suffix) {
    return _adapter?.resourceExists(basePath, suffix) ?? false;
  }

  // ===========================================================================
  // Type-Aware Resolution Methods (NEW - Phase 1)
  // ===========================================================================

  /// Resolves any value from resources for [basePath] + [suffix].
  ///
  /// Returns `null` if no adapter is set or the resource doesn't exist.
  static dynamic resolveValue(String basePath, String suffix) {
    return _adapter?.resolveValue(basePath, suffix);
  }

  /// Resolves a list from resources for [basePath] + [suffix].
  ///
  /// Returns `null` if no adapter is set, no resource exists, or the
  /// resource is not a list.
  static List<dynamic>? resolveList(String basePath, String suffix) {
    return _adapter?.resolveList(basePath, suffix);
  }

  /// Resolves a map from resources for [basePath] + [suffix].
  ///
  /// Returns `null` if no adapter is set, no resource exists, or the
  /// resource is not a map.
  static Map<String, dynamic>? resolveMap(String basePath, String suffix) {
    return _adapter?.resolveMap(basePath, suffix);
  }

  // ===========================================================================
  // Typed Resolution Helpers (NEW - Phase 1)
  // ===========================================================================

  /// Resolves a color from resources for [basePath] + [suffix].
  ///
  /// The resource value should be a color name (e.g., "mRed", "cSystemBlue")
  /// or hex string (e.g., "#FF5733") that [TomUIColors] can resolve.
  ///
  /// Returns `null` if no adapter is set or the color cannot be resolved.
  static Color? resolveColor(String basePath, String suffix) {
    return _adapter?.resolveColor(basePath, suffix);
  }

  /// Resolves an icon from resources for [basePath] + [suffix].
  ///
  /// The resource value should be an icon name (e.g., "mAdd", "mSettings")
  /// that [TomUIIcons] can resolve.
  ///
  /// Returns `null` if no adapter is set or the icon cannot be resolved.
  static IconData? resolveIcon(String basePath, String suffix) {
    return _adapter?.resolveIcon(basePath, suffix);
  }

  /// Resolves a double from resources for [basePath] + [suffix].
  ///
  /// Returns `null` if no adapter is set or the value is not numeric.
  static double? resolveDouble(String basePath, String suffix) {
    return _adapter?.resolveDouble(basePath, suffix);
  }

  /// Resolves an int from resources for [basePath] + [suffix].
  ///
  /// Returns `null` if no adapter is set or the value is not numeric.
  static int? resolveInt(String basePath, String suffix) {
    return _adapter?.resolveInt(basePath, suffix);
  }

  /// Resolves a bool from resources for [basePath] + [suffix].
  ///
  /// Returns `null` if no adapter is set or the value is not boolean-like.
  static bool? resolveBool(String basePath, String suffix) {
    return _adapter?.resolveBool(basePath, suffix);
  }

  /// Resolves edge insets from resources for [basePath] + [suffix].
  ///
  /// Accepts various formats in the JSON resource:
  /// - A single number for uniform insets
  /// - An array [all], [horizontal, vertical], or [left, top, right, bottom]
  /// - A map with keys: "all", "horizontal", "vertical", "left", "top", "right", "bottom"
  ///
  /// Returns `null` if no adapter is set or the format is not recognized.
  static EdgeInsets? resolveEdgeInsets(String basePath, String suffix) {
    return _adapter?.resolveEdgeInsets(basePath, suffix);
  }

  /// Resets the adapter. Intended for testing only.
  static void reset() => _adapter = null;
}
