library;

import 'package:flutter/material.dart';

import '../../widget_base/tom_construction_helpers.dart';

/// A tiny, serialisable view of [ThemeData] covering the ~90% of
/// theme-setup apps actually configure at their root: colour-scheme seed,
/// brightness, font family, base size, weights, and visual density.
///
/// Call [toThemeData] with a **base** [ThemeData] to produce a final theme —
/// unset spec fields are inherited from the base so component themes,
/// theme extensions, and anything else the app set upstream are preserved.
/// Passing no base yields a vanilla Material-3 light theme.
///
/// Resource schema (all keys optional):
/// ```jsonc
/// "app.theme": {
///   "brightness":  "light",         // light | dark (else inherits)
///   "seed":        "#5E35B1",       // used by ColorScheme.fromSeed
///   "primary":     "#5E35B1",       // direct override of scheme
///   "secondary":   "#F57C00",
///   "error":       "#B00020",
///   "fontFamily":  "Inter",         // applied across the whole textTheme
///   "bodySize":    14,              // scales bodyMedium / labelLarge
///   "weights": {
///     "body":  "w400",
///     "label": "w500"
///   },
///   "density":     "standard"       // compact | standard | comfortable
/// }
/// ```
class TomThemeSpec {
  /// `null` means "inherit from base".
  final Brightness? brightness;
  final Color? seed;
  final Color? primary;
  final Color? secondary;
  final Color? error;
  final String? fontFamily;
  final double? bodySize;
  final FontWeight? bodyWeight;
  final FontWeight? labelWeight;

  /// `null` means "inherit from base".
  final VisualDensity? density;

  const TomThemeSpec({
    this.brightness,
    this.seed,
    this.primary,
    this.secondary,
    this.error,
    this.fontFamily,
    this.bodySize,
    this.bodyWeight,
    this.labelWeight,
    this.density,
  });

  /// Reads the spec keys under [basePath] (optionally suffixed by
  /// [subKey] so callers can nest under e.g. `app.theme` or
  /// `myForm.@bp.tablet.theme`). Returns `null` when no known key is
  /// present — the caller should then fall through to any base value.
  static TomThemeSpec? fromResources(String basePath, {String subKey = ''}) {
    final root = subKey.isEmpty ? basePath : '$basePath.$subKey';
    final brightness = _parseBrightness(TomCtr.textOrNull(root, 'brightness'));
    final seed = TomCtr.color(root, 'seed');
    final primary = TomCtr.color(root, 'primary');
    final secondary = TomCtr.color(root, 'secondary');
    final error = TomCtr.color(root, 'error');
    final fontFamily = TomCtr.textOrNull(root, 'fontFamily');
    final bodySize = TomCtr.doubleVal(root, 'bodySize');
    final bodyWeight = _parseFontWeight(
      TomCtr.textOrNull(root, 'weights.body'),
    );
    final labelWeight = _parseFontWeight(
      TomCtr.textOrNull(root, 'weights.label'),
    );
    final density = _parseDensity(TomCtr.textOrNull(root, 'density'));

    final anySet = brightness != null ||
        seed != null ||
        primary != null ||
        secondary != null ||
        error != null ||
        fontFamily != null ||
        bodySize != null ||
        bodyWeight != null ||
        labelWeight != null ||
        density != null;
    if (!anySet) return null;

    return TomThemeSpec(
      brightness: brightness,
      seed: seed,
      primary: primary,
      secondary: secondary,
      error: error,
      fontFamily: fontFamily,
      bodySize: bodySize,
      bodyWeight: bodyWeight,
      labelWeight: labelWeight,
      density: density,
    );
  }

  /// Materialises the spec into a [ThemeData], deriving from [base] when
  /// provided so the app's component themes and other customisations stay
  /// intact. When [base] is null, a vanilla Material-3 light theme is
  /// used as the baseline.
  ///
  /// Precedence per field:
  ///   - spec value if set → wins
  ///   - else inherited from [base]
  ///
  /// For `colorScheme`: if [seed] is provided, a fresh scheme is built via
  /// `ColorScheme.fromSeed`; otherwise the base's scheme is preserved.
  /// Direct `primary` / `secondary` / `error` overrides layer on top
  /// afterwards.
  ///
  /// For `textTheme`: starts from the base's, applies [fontFamily] via
  /// `TextTheme.apply`, then layers size/weight changes to `bodyMedium`,
  /// `bodySmall`, and `labelLarge`.
  ThemeData toThemeData([ThemeData? base]) {
    final b = base ?? ThemeData(useMaterial3: true);

    // --- Color scheme ---
    final effectiveBrightness = brightness ?? b.brightness;
    ColorScheme scheme = b.colorScheme;
    if (seed != null) {
      scheme = ColorScheme.fromSeed(
        seedColor: seed!,
        brightness: effectiveBrightness,
      );
    } else if (effectiveBrightness != b.colorScheme.brightness) {
      // Brightness explicitly changed but no seed — flip via copyWith.
      scheme = scheme.copyWith(brightness: effectiveBrightness);
    }
    if (primary != null || secondary != null || error != null) {
      scheme = scheme.copyWith(
        primary: primary,
        secondary: secondary,
        error: error,
      );
    }

    // --- Text theme ---
    TextTheme textTheme = b.textTheme;
    if (fontFamily != null) {
      textTheme = textTheme.apply(fontFamily: fontFamily!);
    }
    if (bodySize != null || bodyWeight != null || labelWeight != null) {
      final bs = bodySize;
      textTheme = textTheme.copyWith(
        bodyMedium: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
          fontSize: bs,
          fontWeight: bodyWeight,
        ),
        bodySmall: (textTheme.bodySmall ?? const TextStyle()).copyWith(
          fontSize: bs == null ? null : bs - 2,
          fontWeight: bodyWeight,
        ),
        labelLarge: (textTheme.labelLarge ?? const TextStyle()).copyWith(
          fontSize: bs,
          fontWeight: labelWeight ?? bodyWeight,
        ),
      );
    }

    return b.copyWith(
      colorScheme: scheme,
      textTheme: textTheme,
      visualDensity: density,
    );
  }

  static Brightness? _parseBrightness(String? raw) {
    if (raw == null) return null;
    switch (raw.trim().toLowerCase()) {
      case 'light':
        return Brightness.light;
      case 'dark':
        return Brightness.dark;
      default:
        return null;
    }
  }

  static VisualDensity? _parseDensity(String? raw) {
    if (raw == null) return null;
    switch (raw.trim().toLowerCase()) {
      case 'compact':
        return VisualDensity.compact;
      case 'standard':
        return VisualDensity.standard;
      case 'comfortable':
        return VisualDensity.comfortable;
      default:
        return null;
    }
  }

  static FontWeight? _parseFontWeight(String? raw) {
    if (raw == null) return null;
    switch (raw.trim().toLowerCase()) {
      case 'w100':
      case 'thin':
        return FontWeight.w100;
      case 'w200':
      case 'extralight':
        return FontWeight.w200;
      case 'w300':
      case 'light':
        return FontWeight.w300;
      case 'w400':
      case 'normal':
      case 'regular':
        return FontWeight.w400;
      case 'w500':
      case 'medium':
        return FontWeight.w500;
      case 'w600':
      case 'semibold':
        return FontWeight.w600;
      case 'w700':
      case 'bold':
        return FontWeight.w700;
      case 'w800':
      case 'extrabold':
        return FontWeight.w800;
      case 'w900':
      case 'black':
        return FontWeight.w900;
      default:
        return null;
    }
  }
}
