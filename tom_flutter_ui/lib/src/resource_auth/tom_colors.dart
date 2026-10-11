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
/// TomUIColors.adapter = TomAllColorsAdapter();
/// ```
class TomUIColors {
  TomUIColors._();

  /// The installed colour adapter, or `null` when none is installed.
  ///
  /// Readable so that a diagnostics screen or a startup assertion can ask
  /// what is wired, and so that code installing an adapter for one operation
  /// can put the previous one back:
  ///
  /// ```dart
  /// final saved = TomUIColors.adapter;
  /// TomUIColors.adapter = TomMaterialOnlyColorAdapter();
  /// // ...
  /// TomUIColors.adapter = saved;
  /// ```
  ///
  /// Assigning `null` is what makes that restore total: it uninstalls without
  /// touching the registrations, which [reset] would also clear. [reset]
  /// remains the teardown hook for tests; this is the narrower tool.
  static TomUIColorAdapter? adapter;

  /// Resolves the color named [name], or `null` when the installed adapter
  /// does not know it.
  ///
  /// Throws a [StateError] when no adapter is installed. A missing adapter is
  /// a start-up mistake, not an unknown name, and answering `null` for it made
  /// the two indistinguishable: every color name resolved to nothing and
  /// nothing reported why.
  static Color? resolveColor(String name) => _installed().resolveColor(name);

  /// Whether the installed adapter knows a color named [name].
  ///
  /// Throws a [StateError] when no adapter is installed, for the reason
  /// [resolveColor] does.
  static bool colorExists(String name) => _installed().colorExists(name);

  static TomUIColorAdapter _installed() {
    final installed = adapter;
    if (installed != null) return installed;
    throw StateError(
      'No color adapter is installed, so no color name can be resolved. '
      'Install one at start-up: TomUIColors.adapter = TomAllColorsAdapter();',
    );
  }

  /// Registers app-specific colors, or overrides built-in ones, for every
  /// adapter in this module.
  ///
  /// The registry belongs to the module rather than to an adapter, so a name
  /// registered here resolves through [TomAllColorsAdapter], [TomMaterialOnlyColorAdapter] and
  /// [TomCupertinoOnlyColorAdapter] alike, and survives switching between them. Registrations
  /// take precedence over everything an adapter knows. [reset] clears them
  /// along with the adapter.
  static void registerColors(Map<String, Color> colors) {
    _customColors.addAll(colors);
  }

  /// Drops every registration made through [registerColors], keeping the
  /// installed adapter.
  ///
  /// A test tearing down the whole module wants [reset] instead.
  static void clearCustomColors() {
    _customColors.clear();
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
  /// [clearCustomColors].
  static void reset() {
    adapter = null;
    _customColors.clear();
  }
}

/// Colours registered at runtime, shared by every adapter in this module.
///
/// Module-level rather than a static on one adapter, mirroring the icon side:
/// registration, resolution and [TomUIColors.reset] all have to agree about
/// where the registry is, and only one of them belongs to any single adapter.
/// An app that registers its brand colours and then switches to
/// [TomMaterialOnlyColorAdapter] for bundle size must not lose them, and losing
/// them would be silent — every registered name would simply resolve to
/// `null`.
final Map<String, Color> _customColors = {};

/// Resolves registrations first, then hex/rgb syntax, then the adapter's own
/// palette.
///
/// The order is stated once here rather than in each adapter, so
/// "registrations win" cannot hold for one adapter and not another. Hex and
/// rgb sit in the base because they are *syntax*, not a palette: neither
/// belongs to the Material or the Cupertino family, so a single-family adapter
/// is a smaller palette, not a different contract.
abstract class _RegistryFirstColorAdapter implements TomUIColorAdapter {
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

    return resolveInPalette(name);
  }

  @override
  bool colorExists(String name) {
    if (_customColors.containsKey(name)) return true;
    if (_hexPattern.hasMatch(name)) return true;
    if (_rgbPattern.hasMatch(name)) return true;
    return existsInPalette(name);
  }

  /// Resolves [name] against the adapter's own palette, ignoring registrations
  /// and the hex/rgb syntax the base already handled.
  Color? resolveInPalette(String name);

  /// Whether [name] is in the adapter's own palette, ignoring registrations.
  bool existsInPalette(String name);

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
      value = value.split('').map((c) => '$c$c').join();
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
}

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
class TomAllColorsAdapter extends _RegistryFirstColorAdapter {
  @override
  Color? resolveInPalette(String name) => GeneratedColors.resolve(name);

  @override
  bool existsInPalette(String name) => GeneratedColors.exists(name);

}

/// Adapter that only includes Material colors.
///
/// Use this for smaller bundle size if you don't need the Cupertino palette,
/// or to make a stray `cSystemBlue` in a resource file resolve to `null` and
/// be caught rather than quietly working. Colors registered through
/// [TomUIColors.registerColors] still resolve — the registry is
/// module-wide — as do hex and rgb literals; only the Cupertino table is gone.
class TomMaterialOnlyColorAdapter extends _RegistryFirstColorAdapter {
  @override
  Color? resolveInPalette(String name) => GeneratedColors.materialColors[name];

  @override
  bool existsInPalette(String name) =>
      GeneratedColors.materialColors.containsKey(name);
}

/// Adapter that only includes Cupertino colors.
///
/// The iOS-facing counterpart to [TomMaterialOnlyColorAdapter], with the same
/// two reasons to reach for it and the same guarantees: registrations, hex and
/// rgb all still resolve; only the Material table is gone.
class TomCupertinoOnlyColorAdapter extends _RegistryFirstColorAdapter {
  @override
  Color? resolveInPalette(String name) => GeneratedColors.cupertinoColors[name];

  @override
  bool existsInPalette(String name) =>
      GeneratedColors.cupertinoColors.containsKey(name);
}
