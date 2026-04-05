import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'tom_colors.dart';
import 'tom_icons.dart';

/// Global resource singleton backed by [TomTextResourceProvider].
///
/// Initialized at app startup. Widgets resolve labels, hints, error messages,
/// colors, icons, and other values through this — no [InheritedWidget] or
/// [BuildContext] needed.
///
/// Resources are resolved using simple path lookup: `$basePath.$suffix`
/// No fallback chain — if the resource doesn't exist at the exact path,
/// text resources return the full key, value resources return `null`.
///
/// ```dart
/// // App startup - configure TomTextResourceProvider
/// TomTextResourceProvider.setAppResourceProvider(
///   TomTextResourceProvider.from({
///     'checkout.email.label': 'Email Address',
///     'checkout.email.hint': 'Enter your email',
///   })
/// );
///
/// // Usage anywhere
/// final label = TomUIResources.resolveText('checkout.email', 'label');
/// final bgColor = TomUIResources.resolveColor('checkout.email', 'backgroundColor');
/// ```
class TomUIResources {
  TomUIResources._();

  /// Gets the resource provider instance.
  static TomTextResourceProvider get _provider =>
      TomTextResourceProvider.getAppResources();

  // ===========================================================================
  // Core Resolution Methods
  // ===========================================================================

  /// Resolves the text resource for [basePath] + [suffix].
  ///
  /// If no resource is found, returns the full key (`basePath.suffix`)
  /// as a visible development indicator.
  static String resolveText(String basePath, String suffix) {
    final key = '$basePath.$suffix';
    return _provider.getText(key);
  }

  /// Whether a resource exists for [basePath] + [suffix].
  static bool resourceExists(String basePath, String suffix) {
    final key = '$basePath.$suffix';
    return _provider.exists(key) || _provider.existsObject(key);
  }

  // ===========================================================================
  // Type-Aware Resolution Methods
  // ===========================================================================

  /// Resolves any value from resources for [basePath] + [suffix].
  ///
  /// Returns `null` if no resource found.
  static dynamic resolveValue(String basePath, String suffix) {
    final key = '$basePath.$suffix';
    if (!_provider.existsObject(key)) return null;
    return _provider.getObject(key);
  }

  /// Resolves a list from resources for [basePath] + [suffix].
  ///
  /// Returns `null` if no resource found or the resource is not a list.
  static List<dynamic>? resolveList(String basePath, String suffix) {
    final value = resolveValue(basePath, suffix);
    if (value is List) return value;
    return null;
  }

  /// Resolves a map from resources for [basePath] + [suffix].
  ///
  /// Returns `null` if no resource found or the resource is not a map.
  static Map<String, dynamic>? resolveMap(String basePath, String suffix) {
    final value = resolveValue(basePath, suffix);
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  // ===========================================================================
  // Typed Resolution Helpers
  // ===========================================================================

  /// Resolves a color from resources for [basePath] + [suffix].
  ///
  /// The resource value should be a color name (e.g., "mRed", "cSystemBlue")
  /// or hex string (e.g., "#FF5733") that [TomUIColors] can resolve.
  ///
  /// Returns `null` if no resource found or the color cannot be resolved.
  static Color? resolveColor(String basePath, String suffix) {
    final value = resolveValue(basePath, suffix);
    if (value == null) return null;
    if (value is String) return TomUIColors.resolveColor(value);
    if (value is int) return Color(value);
    return null;
  }

  /// Resolves an icon from resources for [basePath] + [suffix].
  ///
  /// The resource value should be an icon name (e.g., "mAdd", "mSettings")
  /// that [TomUIIcons] can resolve.
  ///
  /// Returns `null` if no resource found or the icon cannot be resolved.
  static IconData? resolveIcon(String basePath, String suffix) {
    final value = resolveValue(basePath, suffix);
    if (value == null) return null;
    if (value is String) return TomUIIcons.resolveIcon(value);
    return null;
  }

  /// Resolves a double from resources for [basePath] + [suffix].
  ///
  /// Accepts both double and int values in the JSON resource.
  /// Returns `null` if no resource exists or the value is not numeric.
  static double? resolveDouble(String basePath, String suffix) {
    final value = resolveValue(basePath, suffix);
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Resolves an int from resources for [basePath] + [suffix].
  ///
  /// Accepts both int and double values (truncated) in the JSON resource.
  /// Returns `null` if no resource exists or the value is not numeric.
  static int? resolveInt(String basePath, String suffix) {
    final value = resolveValue(basePath, suffix);
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Resolves a bool from resources for [basePath] + [suffix].
  ///
  /// Accepts bool values or string "true"/"false".
  /// Returns `null` if no resource exists or the value is not boolean-like.
  static bool? resolveBool(String basePath, String suffix) {
    final value = resolveValue(basePath, suffix);
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return null;
  }

  /// Resolves edge insets from resources for [basePath] + [suffix].
  ///
  /// Accepts:
  /// - A single number for uniform insets
  /// - An array [all], [horizontal, vertical], or [left, top, right, bottom]
  /// - A map with keys: "all", "horizontal", "vertical", "left", "top", "right", "bottom"
  ///
  /// Returns `null` if no resource exists or the format is not recognized.
  static EdgeInsets? resolveEdgeInsets(String basePath, String suffix) {
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
