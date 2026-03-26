import 'dart:ui';

import 'tom_colors_generated.dart';

/// Adapter that resolves colors by name.
///
/// Color names are retrieved from text resources (e.g., `w-errorBanner.color`
/// returns "mRed" or "#FF0000"), then resolved to actual [Color] via this adapter.
///
/// Color naming conventions:
/// - Material colors: `m<ColorName>` (e.g., `mRed`, `mBlue`, `mAmber`)
/// - Material shade: `m<ColorName><Shade>` (e.g., `mRed500`, `mBlue100`)
/// - Material accent: `m<ColorName>Accent` (e.g., `mRedAccent`, `mBlueAccent`)
/// - Cupertino colors: `c<ColorName>` (e.g., `cSystemRed`, `cActiveBlue`)
/// - Hex format: `#RRGGBB` or `#AARRGGBB` (e.g., `#FF5733`, `#80FF5733`)
/// - RGB format: `rgb(255, 87, 51)` or `rgba(255, 87, 51, 0.5)`
abstract class TomUIColorAdapter {
  /// Resolves a color by [name].
  ///
  /// Returns `null` if no color is registered for that name.
  Color? resolveColor(String name);

  /// Whether a color with [name] exists.
  bool colorExists(String name);
}

/// Global color provider singleton.
///
/// Initialized at app startup with a concrete adapter. Widgets resolve
/// colors by first getting the color name from text resources, then looking
/// up the actual [Color] through this provider.
///
/// Usage flow:
/// ```dart
/// // 1. Get color name from resources
/// final colorName = TomUIResources.resolveText('w-errorCard', 'color');
/// // -> returns "mRed" or "#FF0000"
///
/// // 2. Get Color from color provider
/// final color = TomUIColors.resolveColor(colorName);
/// // -> returns Colors.red or Color(0xFFFF0000)
/// ```
///
/// App startup:
/// ```dart
/// TomUIColors.adapter = AllColorsAdapter();
/// ```
class TomUIColors {
  TomUIColors._();

  static TomUIColorAdapter? _adapter;

  static set adapter(TomUIColorAdapter adapter) => _adapter = adapter;

  /// Resolves a color by [name].
  ///
  /// Returns `null` if no adapter is set or the color is not found.
  static Color? resolveColor(String name) {
    return _adapter?.resolveColor(name);
  }

  /// Whether a color with [name] exists.
  static bool colorExists(String name) {
    return _adapter?.colorExists(name) ?? false;
  }

  /// Resets the adapter. Intended for testing only.
  static void reset() => _adapter = null;
}

/// Default adapter using all generated Flutter colors (Material + Cupertino).
///
/// Contains Material and Cupertino color palettes plus hex/RGB parsing.
/// This is the recommended adapter for most applications.
///
/// Color naming:
/// - Material: `m<ColorName>` (e.g., `mRed`, `mBlue500`, `mAmberAccent`)
/// - Cupertino: `c<ColorName>` (e.g., `cSystemRed`, `cActiveBlue`)
/// - Hex: `#RRGGBB` or `#AARRGGBB`
/// - RGB: `rgb(r, g, b)` or `rgba(r, g, b, a)`
class AllColorsAdapter implements TomUIColorAdapter {
  /// Custom colors registered at runtime.
  static final Map<String, Color> _customColors = {};

  /// Hex color pattern: #RGB, #RRGGBB, or #AARRGGBB
  static final RegExp _hexPattern = RegExp(
    r'^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$',
  );

  /// RGB/RGBA pattern: rgb(r, g, b) or rgba(r, g, b, a)
  static final RegExp _rgbPattern = RegExp(
    r'^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*([\d.]+))?\s*\)$',
    caseSensitive: false,
  );

  @override
  Color? resolveColor(String name) {
    // Try custom colors first
    if (_customColors.containsKey(name)) {
      return _customColors[name];
    }

    // Try hex format
    if (name.startsWith('#')) {
      return _parseHexColor(name);
    }

    // Try RGB format
    if (name.toLowerCase().startsWith('rgb')) {
      return _parseRgbColor(name);
    }

    // Try generated colors
    return GeneratedColors.resolve(name);
  }

  @override
  bool colorExists(String name) {
    if (_customColors.containsKey(name)) return true;
    if (_hexPattern.hasMatch(name)) return true;
    if (_rgbPattern.hasMatch(name)) return true;
    return GeneratedColors.exists(name);
  }

  /// Parses a hex color string.
  ///
  /// Supports formats:
  /// - `#RGB` (expanded to #RRGGBB)
  /// - `#RRGGBB` (opaque)
  /// - `#AARRGGBB` (with alpha)
  Color? _parseHexColor(String hex) {
    final match = _hexPattern.firstMatch(hex);
    if (match == null) return null;

    var value = match.group(1)!;

    // Expand 3-char hex to 6-char
    if (value.length == 3) {
      value = value
          .split('')
          .map((c) => '$c$c')
          .join();
    }

    // Add alpha if not present
    if (value.length == 6) {
      value = 'FF$value';
    }

    final intValue = int.tryParse(value, radix: 16);
    if (intValue == null) return null;

    return Color(intValue);
  }

  /// Parses an RGB/RGBA color string.
  ///
  /// Supports formats:
  /// - `rgb(255, 128, 0)`
  /// - `rgba(255, 128, 0, 0.5)`
  Color? _parseRgbColor(String rgb) {
    final match = _rgbPattern.firstMatch(rgb);
    if (match == null) return null;

    final r = int.tryParse(match.group(1)!) ?? 0;
    final g = int.tryParse(match.group(2)!) ?? 0;
    final b = int.tryParse(match.group(3)!) ?? 0;
    final a = match.group(4) != null
        ? (double.tryParse(match.group(4)!) ?? 1.0)
        : 1.0;

    // Clamp values
    final red = r.clamp(0, 255);
    final green = g.clamp(0, 255);
    final blue = b.clamp(0, 255);
    final alpha = (a.clamp(0.0, 1.0) * 255).round();

    return Color.fromARGB(alpha, red, green, blue);
  }

  /// Registers additional custom colors.
  ///
  /// Use this to add app-specific colors or override existing ones.
  static void registerColors(Map<String, Color> colors) {
    _customColors.addAll(colors);
  }

  /// Clears all custom registered colors.
  static void clearCustomColors() {
    _customColors.clear();
  }
}
