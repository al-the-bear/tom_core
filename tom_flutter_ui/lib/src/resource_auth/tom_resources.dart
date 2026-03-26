import 'package:flutter/widgets.dart';

import 'tom_colors.dart';
import 'tom_icons.dart';

/// Adapter that resolves user-facing text resources by base path and suffix.
///
/// Resources are locale-aware and process-context-aware. The correct resource
/// set is resolved during app initialization — widgets simply look up keys.
abstract class TomUIResourceAdapter {
  /// Resolves a text resource for [basePath] with [suffix].
  ///
  /// Returns the resolved string, or the full key as a fallback indicator
  /// if no resource is found.
  String resolveText(String basePath, String suffix);

  /// Whether a resource exists for [basePath] with [suffix].
  bool resourceExists(String basePath, String suffix);

  // ─── Phase 1: Typed Resolution API ─────────────────────────────────────────

  /// Resolves any value type by [basePath] and [suffix].
  ///
  /// Returns null if not found or type doesn't match.
  T? resolveValue<T>(String basePath, String suffix) => null;

  /// Resolves a list of values by [basePath] and [suffix].
  ///
  /// Returns null if not found.
  List<T>? resolveList<T>(String basePath, String suffix) => null;

  /// Resolves a map structure by [basePath] and [suffix].
  ///
  /// Returns null if not found.
  Map<String, dynamic>? resolveMap(String basePath, String suffix) => null;

  /// Resolves a [Color] by looking up the value via [TomUIColors].
  ///
  /// The adapter should return a color name/key that [TomUIColors] can resolve.
  Color? resolveColor(String basePath, String suffix) {
    final colorName = resolveValue<String>(basePath, suffix);
    if (colorName == null) return null;
    return TomUIColors.resolveColor(colorName);
  }

  /// Resolves an [IconData] by looking up the value via [TomUIIcons].
  ///
  /// The adapter should return an icon name/key that [TomUIIcons] can resolve.
  IconData? resolveIcon(String basePath, String suffix) {
    final iconName = resolveValue<String>(basePath, suffix);
    if (iconName == null) return null;
    return TomUIIcons.resolveIcon(iconName);
  }

  /// Resolves a [double] value by [basePath] and [suffix].
  double? resolveDouble(String basePath, String suffix) {
    final value = resolveValue<Object>(basePath, suffix);
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Resolves an [int] value by [basePath] and [suffix].
  int? resolveInt(String basePath, String suffix) {
    final value = resolveValue<Object>(basePath, suffix);
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Resolves a [bool] value by [basePath] and [suffix].
  bool? resolveBool(String basePath, String suffix) {
    final value = resolveValue<Object>(basePath, suffix);
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return null;
  }

  /// Resolves [EdgeInsets] by [basePath] and [suffix].
  ///
  /// Supports multiple formats:
  /// - Single number: `16` → `EdgeInsets.all(16)`
  /// - Two-element array: `[16, 8]` → `EdgeInsets.symmetric(horizontal: 16, vertical: 8)`
  /// - Four-element array: `[16, 8, 16, 8]` → `EdgeInsets.fromLTRB(16, 8, 16, 8)`
  /// - Map with keys: `{left: 16, top: 8, right: 16, bottom: 8}`
  EdgeInsets? resolveEdgeInsets(String basePath, String suffix) {
    final value = resolveValue<Object>(basePath, suffix);
    if (value == null) return null;

    // Single number → EdgeInsets.all
    if (value is num) {
      return EdgeInsets.all(value.toDouble());
    }

    // Array format
    if (value is List) {
      final doubles = value
          .map((e) => e is num ? e.toDouble() : double.tryParse('$e'))
          .whereType<double>()
          .toList();
      if (doubles.length == 2) {
        return EdgeInsets.symmetric(
          horizontal: doubles[0],
          vertical: doubles[1],
        );
      }
      if (doubles.length == 4) {
        return EdgeInsets.fromLTRB(
          doubles[0],
          doubles[1],
          doubles[2],
          doubles[3],
        );
      }
    }

    // Map format
    if (value is Map<String, dynamic>) {
      return EdgeInsets.only(
        left: (value['left'] as num?)?.toDouble() ?? 0,
        top: (value['top'] as num?)?.toDouble() ?? 0,
        right: (value['right'] as num?)?.toDouble() ?? 0,
        bottom: (value['bottom'] as num?)?.toDouble() ?? 0,
      );
    }

    return null;
  }
}

/// Global text resource singleton.
///
/// Initialized at app startup with a concrete adapter. Widgets resolve
/// labels, hints, error messages, and tooltips through this — no
/// [InheritedWidget] or [BuildContext] needed.
///
/// ```dart
/// // App startup
/// TomUIResources.adapter = TomKernelResourceAdapter();
///
/// // Usage anywhere
/// final label = TomUIResources.resolveText('r-checkout.w-email', 'label');
/// ```
class TomUIResources {
  TomUIResources._();

  static TomUIResourceAdapter? _adapter;

  static set adapter(TomUIResourceAdapter adapter) => _adapter = adapter;

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

  /// Resets the adapter. Intended for testing only.
  static void reset() => _adapter = null;

  // ─── Phase 1: Typed Resolution API ─────────────────────────────────────────

  /// Resolves any value type by [basePath] and [suffix].
  static T? resolveValue<T>(String basePath, String suffix) {
    return _adapter?.resolveValue<T>(basePath, suffix);
  }

  /// Resolves a list by [basePath] and [suffix].
  static List<T>? resolveList<T>(String basePath, String suffix) {
    return _adapter?.resolveList<T>(basePath, suffix);
  }

  /// Resolves a map by [basePath] and [suffix].
  static Map<String, dynamic>? resolveMap(String basePath, String suffix) {
    return _adapter?.resolveMap(basePath, suffix);
  }

  /// Resolves a [Color] by [basePath] and [suffix].
  static Color? resolveColor(String basePath, String suffix) {
    return _adapter?.resolveColor(basePath, suffix);
  }

  /// Resolves an [IconData] by [basePath] and [suffix].
  static IconData? resolveIcon(String basePath, String suffix) {
    return _adapter?.resolveIcon(basePath, suffix);
  }

  /// Resolves a [double] by [basePath] and [suffix].
  static double? resolveDouble(String basePath, String suffix) {
    return _adapter?.resolveDouble(basePath, suffix);
  }

  /// Resolves an [int] by [basePath] and [suffix].
  static int? resolveInt(String basePath, String suffix) {
    return _adapter?.resolveInt(basePath, suffix);
  }

  /// Resolves a [bool] by [basePath] and [suffix].
  static bool? resolveBool(String basePath, String suffix) {
    return _adapter?.resolveBool(basePath, suffix);
  }

  /// Resolves [EdgeInsets] by [basePath] and [suffix].
  static EdgeInsets? resolveEdgeInsets(String basePath, String suffix) {
    return _adapter?.resolveEdgeInsets(basePath, suffix);
  }
}
