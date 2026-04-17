library;

import 'package:flutter/material.dart';

/// Resolves a `cs.*` token string to a concrete [Color] from the supplied
/// [ColorScheme]. Token names are case-insensitive and mirror Flutter's
/// [ColorScheme] property names prefixed with `cs.`:
///
/// ```jsonc
/// "labelStyle": { "color": "cs.primary" }
/// "focusedBorder": { "color": "cs.primary" }
/// "hintStyle": { "color": "cs.onSurfaceVariant" }
/// "errorStyle": { "color": "cs.error" }
/// "fieldBorder": { "color": "cs.outline" }
/// ```
///
/// Returns `null` for unrecognised token names so callers can fall through
/// to a default.
Color? resolveColorSchemeToken(String token, ColorScheme cs) {
  // Normalise: strip "cs." prefix, lowercase, remove underscores/hyphens.
  final name = token
      .toLowerCase()
      .replaceFirst(RegExp(r'^cs\.'), '')
      .replaceAll(RegExp(r'[-_]'), '');

  switch (name) {
    // --- Primary ---
    case 'primary':
      return cs.primary;
    case 'onprimary':
      return cs.onPrimary;
    case 'primarycontainer':
      return cs.primaryContainer;
    case 'onprimarycontainer':
      return cs.onPrimaryContainer;
    case 'primaryfixed':
      return cs.primaryFixed;
    case 'primaryfixeddim':
      return cs.primaryFixedDim;
    case 'onprimaryfixed':
      return cs.onPrimaryFixed;
    case 'onprimaryfixedvariant':
      return cs.onPrimaryFixedVariant;

    // --- Secondary ---
    case 'secondary':
      return cs.secondary;
    case 'onsecondary':
      return cs.onSecondary;
    case 'secondarycontainer':
      return cs.secondaryContainer;
    case 'onsecondarycontainer':
      return cs.onSecondaryContainer;
    case 'secondaryfixed':
      return cs.secondaryFixed;
    case 'secondaryfixeddim':
      return cs.secondaryFixedDim;
    case 'onsecondaryfixed':
      return cs.onSecondaryFixed;
    case 'onsecondaryfixedvariant':
      return cs.onSecondaryFixedVariant;

    // --- Tertiary ---
    case 'tertiary':
      return cs.tertiary;
    case 'ontertiary':
      return cs.onTertiary;
    case 'tertiarycontainer':
      return cs.tertiaryContainer;
    case 'ontertiarycontainer':
      return cs.onTertiaryContainer;
    case 'tertiaryfixed':
      return cs.tertiaryFixed;
    case 'tertiaryfixeddim':
      return cs.tertiaryFixedDim;
    case 'ontertiaryfixed':
      return cs.onTertiaryFixed;
    case 'ontertiaryfixedvariant':
      return cs.onTertiaryFixedVariant;

    // --- Error ---
    case 'error':
      return cs.error;
    case 'onerror':
      return cs.onError;
    case 'errorcontainer':
      return cs.errorContainer;
    case 'onerrorcontainer':
      return cs.onErrorContainer;

    // --- Surface ---
    case 'surface':
      return cs.surface;
    case 'onsurface':
      return cs.onSurface;
    case 'onsurfacevariant':
      return cs.onSurfaceVariant;
    case 'surfacetint':
      return cs.surfaceTint;
    case 'surfacecontainerhighest':
      return cs.surfaceContainerHighest;
    case 'surfacecontainerhigh':
      return cs.surfaceContainerHigh;
    case 'surfacecontainer':
      return cs.surfaceContainer;
    case 'surfacecontainerlow':
      return cs.surfaceContainerLow;
    case 'surfacecontainerlowest':
      return cs.surfaceContainerLowest;

    // --- Inverse ---
    case 'inversesurface':
      return cs.inverseSurface;
    case 'oninversesurface':
      return cs.onInverseSurface;
    case 'inverseprimary':
      return cs.inversePrimary;

    // --- Outline / shadow ---
    case 'outline':
      return cs.outline;
    case 'outlinevariant':
      return cs.outlineVariant;
    case 'scrim':
      return cs.scrim;
    case 'shadow':
      return cs.shadow;

    default:
      return null;
  }
}

/// Returns true when [raw] looks like a `cs.*` color-scheme token.
bool isColorSchemeToken(String raw) =>
    raw.toLowerCase().startsWith('cs.');

/// Resolves [raw] using [cs] if it is a `cs.*` token, otherwise delegates
/// to [fallback] (e.g. `TomUIColors.resolveColor`). Returns `null` when
/// neither path produces a color.
Color? resolveAnyColor(
  String raw,
  ColorScheme cs,
  Color? Function(String) fallback,
) {
  if (isColorSchemeToken(raw)) {
    return resolveColorSchemeToken(raw, cs);
  }
  return fallback(raw);
}
