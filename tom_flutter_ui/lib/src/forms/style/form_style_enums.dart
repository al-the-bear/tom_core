/// Placement enums for form field anatomy configuration (§10).
library;

/// Controls where the label appears relative to the field input.
enum LabelPlacement {
  /// Label in a row above the field.
  above,

  /// Label in a row directly below the field, between the input and
  /// the description/helper row (when the description is below).
  below,

  /// Material floating label inside the field (for text inputs).
  floating,

  /// Label to the left of the field (inline layout).
  inline,

  /// No visible label (e.g., icon-only fields).
  hidden,
}

/// Controls where validation error messages appear.
enum ErrorPlacement {
  /// Error text below the field.
  below,

  /// Error text above the field.
  above,

  /// Error shown in a tooltip on hover/focus.
  tooltip,

  /// Error displayed both above and below.
  both,

  /// Error message takes the hint slot inside the field (visible while
  /// the input is empty). No separate error row is rendered. Useful for
  /// very compact layouts — caveat: once the user types, the error is
  /// no longer visible.
  replaceHint,
}

/// Controls how the required indicator is displayed.
enum RequiredIndicator {
  /// Red asterisk after the label.
  asterisk,

  /// "(required)" text after the label.
  text,

  /// No required indicator.
  none,

  /// Custom widget provided per-field.
  custom,
}

/// Controls where the description/helper text appears.
enum DescriptionPlacement {
  /// Description below the error row.
  below,

  /// Description between label and field.
  above,

  /// Description shown on info icon click.
  tooltip,
}

/// Controls where action icons appear relative to the field input.
enum ActionIconPlacement {
  /// Action icons on the right side of the input row.
  trailing,

  /// Action icons on the left side of the input row.
  leading,

  /// Action icons in the label row.
  above,
}
