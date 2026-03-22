import 'package:flutter/material.dart';

import 'tom_style_variant.dart';

/// Maps [TomStyleVariant] values to concrete Flutter style objects.
///
/// Only families that need semantic variant support get entries here.
/// Families like labels, images, progress indicators, sliders, and toggles
/// have no variant concept and rely purely on Flutter's [ThemeData].
///
/// ## Usage
///
/// ```dart
/// final variantMap = TomVariantMap(
///   buttonVariants: {
///     TomStyleVariant.primary: ElevatedButton.styleFrom(
///       backgroundColor: colorScheme.primary,
///       foregroundColor: colorScheme.onPrimary,
///     ),
///     TomStyleVariant.secondary: OutlinedButton.styleFrom(
///       foregroundColor: colorScheme.primary,
///     ),
///     TomStyleVariant.destructive: ElevatedButton.styleFrom(
///       backgroundColor: colorScheme.error,
///       foregroundColor: colorScheme.onError,
///     ),
///     TomStyleVariant.auxiliary: TextButton.styleFrom(
///       foregroundColor: colorScheme.onSurfaceVariant,
///     ),
///   },
/// );
/// ```
class TomVariantMap {
  /// Variant → [ButtonStyle] mapping for the button family.
  final Map<TomStyleVariant, ButtonStyle> buttonVariants;

  /// Variant → [InputDecoration] mapping for the input family.
  final Map<TomStyleVariant, InputDecoration> inputVariants;

  /// Variant → [ChipThemeData] mapping for the chip family.
  final Map<TomStyleVariant, ChipThemeData> chipVariants;

  const TomVariantMap({
    this.buttonVariants = const {},
    this.inputVariants = const {},
    this.chipVariants = const {},
  });

  /// Returns the [ButtonStyle] for the given variant, or `null`.
  ButtonStyle? buttonStyleFor(TomStyleVariant variant) =>
      buttonVariants[variant];

  /// Returns the [InputDecoration] for the given variant, or `null`.
  InputDecoration? inputDecorationFor(TomStyleVariant variant) =>
      inputVariants[variant];

  /// Returns the [ChipThemeData] for the given variant, or `null`.
  ChipThemeData? chipThemeFor(TomStyleVariant variant) =>
      chipVariants[variant];

  /// Creates a copy with the given overrides.
  TomVariantMap copyWith({
    Map<TomStyleVariant, ButtonStyle>? buttonVariants,
    Map<TomStyleVariant, InputDecoration>? inputVariants,
    Map<TomStyleVariant, ChipThemeData>? chipVariants,
  }) {
    return TomVariantMap(
      buttonVariants: buttonVariants ?? this.buttonVariants,
      inputVariants: inputVariants ?? this.inputVariants,
      chipVariants: chipVariants ?? this.chipVariants,
    );
  }
}
