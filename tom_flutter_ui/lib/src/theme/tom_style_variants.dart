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
///
/// No widget in this package consumes it. The button family takes a plain
/// [ButtonStyle] and this produces one, so wiring a `variant` parameter in
/// would add a second way to say what `style:` already says. It is a
/// convenience for application code, and the absence of an in-package caller
/// is a decision rather than an oversight.
class TomButtonVariants {
  final ColorScheme _colors;

  // Not `const`, because the four variants below are `late final` and a const
  // constructor cannot carry lazy fields. Nothing is lost: this constructor is
  // private and both public entry points are ordinary factories, so no call
  // site could ever have been const in the first place.
  TomButtonVariants._(this._colors);

  /// Resolves variants from the nearest [Theme].
  factory TomButtonVariants.of(BuildContext context) =>
      TomButtonVariants._(Theme.of(context).colorScheme);

  /// Resolves variants from the given [colorScheme].
  factory TomButtonVariants.fromColorScheme(ColorScheme colorScheme) =>
      TomButtonVariants._(colorScheme);

  // Each variant is a pure function of `_colors`, which never changes for a
  // given instance, so it is built on first read and kept. The documented
  // idiom reads them inside `build` — as expression-bodied getters that meant
  // a fresh `ButtonStyle` per button per frame, for a value that could not
  // have differed from the last one.

  /// Main action — filled, prominent color.
  late final ButtonStyle primary = ElevatedButton.styleFrom(
    backgroundColor: _colors.primary,
    foregroundColor: _colors.onPrimary,
  );

  /// Supporting action — outlined.
  late final ButtonStyle secondary = OutlinedButton.styleFrom(
    foregroundColor: _colors.primary,
  );

  /// Utility action — text-only, subtle.
  late final ButtonStyle auxiliary = TextButton.styleFrom(
    foregroundColor: _colors.onSurfaceVariant,
  );

  /// Dangerous / irreversible action — error color.
  late final ButtonStyle destructive = ElevatedButton.styleFrom(
    backgroundColor: _colors.error,
    foregroundColor: _colors.onError,
  );
}
