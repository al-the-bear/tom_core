import 'package:flutter/material.dart';

/// Convenience factories that produce standard [ButtonStyle] objects for
/// semantic action variants (primary, secondary, destructive, auxiliary).
///
/// These do **not** introduce a new theming concept — they simply derive
/// styles from the current [ColorScheme] so callers can pass them directly
/// to a button's `style` parameter.
///
/// ```dart
/// TomElevatedButton(
///   style: TomButtonVariants.of(context).primary,
///   onPressed: () => save(),
///   child: Text('Save'),
/// )
/// ```
class TomButtonVariants {
  final ColorScheme _colors;

  const TomButtonVariants._(this._colors);

  /// Resolves variants from the nearest [Theme].
  factory TomButtonVariants.of(BuildContext context) =>
      TomButtonVariants._(Theme.of(context).colorScheme);

  /// Resolves variants from the given [colorScheme].
  factory TomButtonVariants.fromColorScheme(ColorScheme colorScheme) =>
      TomButtonVariants._(colorScheme);

  /// Main action — filled, prominent color.
  ButtonStyle get primary => ElevatedButton.styleFrom(
        backgroundColor: _colors.primary,
        foregroundColor: _colors.onPrimary,
      );

  /// Supporting action — outlined.
  ButtonStyle get secondary => OutlinedButton.styleFrom(
        foregroundColor: _colors.primary,
      );

  /// Utility action — text-only, subtle.
  ButtonStyle get auxiliary => TextButton.styleFrom(
        foregroundColor: _colors.onSurfaceVariant,
      );

  /// Dangerous / irreversible action — error color.
  ButtonStyle get destructive => ElevatedButton.styleFrom(
        backgroundColor: _colors.error,
        foregroundColor: _colors.onError,
      );
}
