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
/// - Hex format: `#RGB`, `#ARGB`, `#RRGGBB` or `#AARRGGBB`
///   (e.g., `#FF5733`, `#80FF5733`) — **alpha leads**, as in `Color(0x…)`,
///   not the trailing-alpha `#RRGGBBAA` that CSS and design tools emit
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
/// final colorName = TomCtr.text('w-errorCard', 'color');
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

  /// Drops the adapter **and** every custom registration.
  ///
  /// Intended for testing only. This is the whole hygiene hook: after it the
  /// module holds no state, so a suite needs nothing else in its `tearDown`.
  /// Clearing the registrations is the point — they live in a module-wide,
  /// process-global registry, so an override left behind by one test would
  /// silently change a colour in every later test rather than failing.
  ///
  /// To drop registrations while keeping the installed adapter, use
  /// [AllColorsAdapter.clearCustomColors].
  static void reset() {
    _adapter = null;
    _customColors.clear();
  }
}

/// Colours registered at runtime, shared by every adapter in this module.
///
/// Module-level rather than a static on one adapter, mirroring the icon side:
/// registration, resolution and [TomUIColors.reset] all have to agree about
/// where the registry is, and only one of them belongs to any single adapter.
final Map<String, Color> _customColors = {};

/// Default adapter using all generated Flutter colors (Material + Cupertino).
///
/// Contains Material and Cupertino color palettes plus hex/RGB parsing.
/// This is the recommended adapter for most applications.
///
/// Color naming:
/// - Material: `m<ColorName>` (e.g., `mRed`, `mBlue500`, `mAmberAccent`)
/// - Cupertino: `c<ColorName>` (e.g., `cSystemRed`, `cActiveBlue`)
/// - Hex: `#RGB`, `#ARGB`, `#RRGGBB` or `#AARRGGBB` — alpha first, see
///   [_parseHexColor] for why that matters when copying from a design tool
/// - RGB: `rgb(r, g, b)` or `rgba(r, g, b, a)`
class AllColorsAdapter implements TomUIColorAdapter {
  /// Hex color pattern: #RGB, #ARGB, #RRGGBB, or #AARRGGBB.
  ///
  /// Alpha leads in both forms that carry it — see [_parseHexColor].
  static final RegExp _hexPattern = RegExp(
    r'^#([0-9A-Fa-f]{3,4}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$',
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
  /// - `#RGB` (expanded to `#RRGGBB`, opaque)
  /// - `#ARGB` (expanded to `#AARRGGBB`)
  /// - `#RRGGBB` (opaque)
  /// - `#AARRGGBB` (with alpha)
  ///
  /// **Alpha comes first** in both forms that carry it, matching Dart's
  /// `Color(0xAARRGGBB)` literal. CSS, Figma, Sketch and web palette exports
  /// put alpha *last* (`#RRGGBBAA` / `#RGBA`), and the two orderings cannot be
  /// told apart from the string: `#FF5733AA` is a designer's orange at
  /// two-thirds alpha, but is read here as opaque blue-violet. Nothing detects
  /// that, so the convention is documented rather than guessed — check the
  /// channel order when copying a colour in from a design tool.
  Color? _parseHexColor(String hex) {
    final match = _hexPattern.firstMatch(hex);
    if (match == null) return null;

    var value = match.group(1)!;

    // Expand the shorthands by doubling each digit: RGB -> RRGGBB and
    // ARGB -> AARRGGBB. Doubling preserves channel order, so the alpha-first
    // reading below applies to the 4-digit form for free.
    if (value.length == 3 || value.length == 4) {
      value = value
          .split('')
          .map((c) => '$c$c')
          .join();
    }

    // Six digits carry no alpha, so the colour is opaque.
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
  /// Registrations take precedence over hex/rgb parsing and the generated
  /// palette. [TomUIColors.reset] clears them along with the adapter.
  static void registerColors(Map<String, Color> colors) {
    _customColors.addAll(colors);
  }

  /// Clears all custom registered colors, keeping the installed adapter.
  ///
  /// A test tearing down the whole module wants [TomUIColors.reset] instead.
  static void clearCustomColors() {
    _customColors.clear();
  }
}
