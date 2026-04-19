library;

import 'package:flutter/material.dart';

import 'form_style_enums.dart';

// ===========================================================================
// TomFieldStyle — shared base for every field type
// ===========================================================================

/// The shared, **fully-populated** base of a [TomFormStyle].
///
/// Every per-widget-type style ([TomStringInputStyle], [TomCheckboxStyle], …)
/// carries the same property shape but with every field nullable — acting as
/// a *partial override* applied on top of this base.
///
/// Breakpoint-aware properties are expressed as two fields: the plain value
/// and a matching `(minWidth, value)` overrides list. Resolution happens
/// against the available width via [resolveForBp] / [pickPair].
class TomFieldStyle {
  // --- Anatomy placements --------------------------------------------------

  final LabelPlacement labelPlacement;
  final List<(double, LabelPlacement)> labelPlacementBpOverrides;
  final ErrorPlacement errorPlacement;
  final RequiredIndicator requiredIndicator;
  final RequiredIndicator requiredIndicatorOnHint;
  final RequiredIndicator requiredIndicatorOnDescription;
  final DescriptionPlacement descriptionPlacement;
  final ActionIconPlacement actionIconPlacement;

  // --- Intra-field anatomy gaps -------------------------------------------

  final double labelFieldGap;
  final List<(double, double)> labelFieldGapBpOverrides;

  final double errorFieldGap;
  final List<(double, double)> errorFieldGapBpOverrides;

  /// Gap between the description text and whatever sits above it — the
  /// input box when error placement is `above`/`none`, or the error
  /// message when placement is `below`/`both`. Independent of
  /// [errorFieldGap] so descriptions can breathe more (or less) than
  /// error text without changing one by adjusting the other.
  final double descriptionFieldGap;
  final List<(double, double)> descriptionFieldGapBpOverrides;

  // --- Field-box shape -----------------------------------------------------

  final EdgeInsets fieldContentPadding;
  final double borderRadius;
  final InputBorder? fieldBorder;
  final InputBorder? focusedBorder;
  final InputBorder? errorBorder;

  /// When non-null, overrides the border-stroke width of the enabled /
  /// default state border. Applied post-facto onto whatever
  /// [fieldBorder] a preset provided, via [applyBorderWidth] — so
  /// `borderWidth: 2` with the `bordered` preset yields a 2-pixel
  /// outline without having to rebuild the entire InputBorder. Leave
  /// null to inherit the width baked into the preset's border.
  final double? borderWidth;

  /// Like [borderWidth] but for the focused-state border.
  final double? focusedBorderWidth;

  // --- Typography ----------------------------------------------------------

  /// Style for the user-entered text inside the field (TextField value,
  /// Dropdown selected label). Distinct from [labelStyle] so the label can
  /// be bold while the typed value follows a different weight/opacity.
  final TextStyle? inputStyle;
  final TextStyle? labelStyle;
  final List<(double, TextStyle)> labelStyleBpOverrides;
  final TextStyle? hintStyle;
  final List<(double, TextStyle)> hintStyleBpOverrides;

  /// Forced font weight for the hint (placeholder). Applied on top of
  /// [hintStyle] regardless of what weight the theme's bodyMedium carries —
  /// so bold labels don't drag the hint along with them.
  ///
  /// Default: `FontWeight.w400`.
  /// Set to `null` to inherit the theme's weight.
  final FontWeight? hintFontWeight;

  /// Alpha multiplier applied to the hint's effective color, rendering it
  /// visually subordinate to the label. Clamped to `[0, 1]`.
  ///
  /// Default: `0.7`.
  /// Set to `null` to skip the opacity adjustment (i.e., full opacity).
  final double? hintOpacity;

  final TextStyle? errorStyle;
  final TextStyle? descriptionStyle;

  // --- State visuals -------------------------------------------------------

  /// Opacity applied to the whole field when the effective auth state is
  /// [TomAuthState.disabled]. Default `0.6` — clearly dimmed so the field
  /// reads as "not available". Lower than [readOnlyOpacity] to keep the two
  /// states visually distinct on fields that both route through
  /// `enabled: false` (text inputs, dropdowns).
  final double disabledOpacity;

  /// Opacity applied to the whole field when the effective auth state is
  /// [TomAuthState.read]. Default `0.8` — a light dim so the content is
  /// still comfortably readable but the field obviously differs from an
  /// editable one. Set to `1.0` to paint readonly fields at full opacity.
  final double readOnlyOpacity;
  final WidgetStateProperty<Color>? readOnlyBackground;
  final WidgetStateProperty<Color>? focusedBackground;

  final bool errorBorderEnabled;
  final List<(double, bool)> errorBorderEnabledBpOverrides;

  final bool errorIconEnabled;
  final List<(double, bool)> errorIconEnabledBpOverrides;

  const TomFieldStyle({
    this.labelPlacement = LabelPlacement.above,
    this.labelPlacementBpOverrides = const [],
    this.errorPlacement = ErrorPlacement.below,
    this.requiredIndicator = RequiredIndicator.asterisk,
    this.requiredIndicatorOnHint = RequiredIndicator.none,
    this.requiredIndicatorOnDescription = RequiredIndicator.none,
    this.descriptionPlacement = DescriptionPlacement.below,
    this.actionIconPlacement = ActionIconPlacement.trailing,
    this.labelFieldGap = 4.0,
    this.labelFieldGapBpOverrides = const [],
    this.errorFieldGap = 4.0,
    this.errorFieldGapBpOverrides = const [],
    this.descriptionFieldGap = 4.0,
    this.descriptionFieldGapBpOverrides = const [],
    this.fieldContentPadding =
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.borderRadius = 8.0,
    this.borderWidth,
    this.focusedBorderWidth,
    this.fieldBorder,
    this.focusedBorder,
    this.errorBorder,
    this.inputStyle,
    this.labelStyle,
    this.labelStyleBpOverrides = const [],
    this.hintStyle,
    this.hintStyleBpOverrides = const [],
    this.hintFontWeight = FontWeight.w400,
    this.hintOpacity = 0.7,
    this.errorStyle,
    this.descriptionStyle,
    this.disabledOpacity = 0.6,
    this.readOnlyOpacity = 0.8,
    this.readOnlyBackground,
    this.focusedBackground,
    this.errorBorderEnabled = false,
    this.errorBorderEnabledBpOverrides = const [],
    this.errorIconEnabled = false,
    this.errorIconEnabledBpOverrides = const [],
  });

  // --- Breakpoint resolution ----------------------------------------------

  /// Resolves a breakpointed `(value, overrides)` pair against [width].
  ///
  /// Overrides are treated as sorted ascending by `minWidth`; the highest
  /// `minWidth <= width` wins. If none matches, [defaultValue] is returned.
  T resolveForBp<T>(
    double width,
    T defaultValue,
    List<(double, T)> overrides,
  ) {
    if (overrides.isEmpty) return defaultValue;
    T current = defaultValue;
    double best = double.negativeInfinity;
    for (final entry in overrides) {
      final minW = entry.$1;
      if (minW <= width && minW >= best) {
        best = minW;
        current = entry.$2;
      }
    }
    return current;
  }

  /// Per-pair atomic pick: if [overValue] is non-null, resolve
  /// ([overValue], [overOverrides]) against [width]; otherwise resolve
  /// ([baseValue], [baseOverrides]).
  ///
  /// The `(value, overrides)` pair is treated atomically — a sub-style
  /// cannot partially override only the list while inheriting the default.
  T pickPair<T>(
    double width,
    T? overValue,
    List<(double, T)> overOverrides,
    T baseValue,
    List<(double, T)> baseOverrides,
  ) {
    if (overValue != null) {
      return resolveForBp(width, overValue, overOverrides);
    }
    return resolveForBp(width, baseValue, baseOverrides);
  }

  TomFieldStyle copyWith({
    LabelPlacement? labelPlacement,
    List<(double, LabelPlacement)>? labelPlacementBpOverrides,
    ErrorPlacement? errorPlacement,
    RequiredIndicator? requiredIndicator,
    RequiredIndicator? requiredIndicatorOnHint,
    RequiredIndicator? requiredIndicatorOnDescription,
    DescriptionPlacement? descriptionPlacement,
    ActionIconPlacement? actionIconPlacement,
    double? labelFieldGap,
    List<(double, double)>? labelFieldGapBpOverrides,
    double? errorFieldGap,
    List<(double, double)>? errorFieldGapBpOverrides,
    double? descriptionFieldGap,
    List<(double, double)>? descriptionFieldGapBpOverrides,
    EdgeInsets? fieldContentPadding,
    double? borderRadius,
    double? borderWidth,
    bool borderWidthSet = false,
    double? focusedBorderWidth,
    bool focusedBorderWidthSet = false,
    InputBorder? fieldBorder,
    InputBorder? focusedBorder,
    InputBorder? errorBorder,
    TextStyle? inputStyle,
    TextStyle? labelStyle,
    List<(double, TextStyle)>? labelStyleBpOverrides,
    TextStyle? hintStyle,
    List<(double, TextStyle)>? hintStyleBpOverrides,
    FontWeight? hintFontWeight,
    bool hintFontWeightSet = false,
    double? hintOpacity,
    bool hintOpacitySet = false,
    TextStyle? errorStyle,
    TextStyle? descriptionStyle,
    double? disabledOpacity,
    double? readOnlyOpacity,
    WidgetStateProperty<Color>? readOnlyBackground,
    WidgetStateProperty<Color>? focusedBackground,
    bool? errorBorderEnabled,
    List<(double, bool)>? errorBorderEnabledBpOverrides,
    bool? errorIconEnabled,
    List<(double, bool)>? errorIconEnabledBpOverrides,
  }) {
    return TomFieldStyle(
      labelPlacement: labelPlacement ?? this.labelPlacement,
      labelPlacementBpOverrides:
          labelPlacementBpOverrides ?? this.labelPlacementBpOverrides,
      errorPlacement: errorPlacement ?? this.errorPlacement,
      requiredIndicator: requiredIndicator ?? this.requiredIndicator,
      requiredIndicatorOnHint:
          requiredIndicatorOnHint ?? this.requiredIndicatorOnHint,
      requiredIndicatorOnDescription: requiredIndicatorOnDescription ??
          this.requiredIndicatorOnDescription,
      descriptionPlacement:
          descriptionPlacement ?? this.descriptionPlacement,
      actionIconPlacement: actionIconPlacement ?? this.actionIconPlacement,
      labelFieldGap: labelFieldGap ?? this.labelFieldGap,
      labelFieldGapBpOverrides:
          labelFieldGapBpOverrides ?? this.labelFieldGapBpOverrides,
      errorFieldGap: errorFieldGap ?? this.errorFieldGap,
      errorFieldGapBpOverrides:
          errorFieldGapBpOverrides ?? this.errorFieldGapBpOverrides,
      descriptionFieldGap: descriptionFieldGap ?? this.descriptionFieldGap,
      descriptionFieldGapBpOverrides: descriptionFieldGapBpOverrides ??
          this.descriptionFieldGapBpOverrides,
      fieldContentPadding: fieldContentPadding ?? this.fieldContentPadding,
      borderRadius: borderRadius ?? this.borderRadius,
      borderWidth: borderWidthSet ? borderWidth : this.borderWidth,
      focusedBorderWidth:
          focusedBorderWidthSet ? focusedBorderWidth : this.focusedBorderWidth,
      fieldBorder: fieldBorder ?? this.fieldBorder,
      focusedBorder: focusedBorder ?? this.focusedBorder,
      errorBorder: errorBorder ?? this.errorBorder,
      inputStyle: inputStyle ?? this.inputStyle,
      labelStyle: labelStyle ?? this.labelStyle,
      labelStyleBpOverrides:
          labelStyleBpOverrides ?? this.labelStyleBpOverrides,
      hintStyle: hintStyle ?? this.hintStyle,
      hintStyleBpOverrides:
          hintStyleBpOverrides ?? this.hintStyleBpOverrides,
      // Explicit-null semantics: a caller passing `hintFontWeight: null` with
      // `hintFontWeightSet: true` clears the default (inherit theme weight).
      hintFontWeight:
          hintFontWeightSet ? hintFontWeight : this.hintFontWeight,
      hintOpacity: hintOpacitySet ? hintOpacity : this.hintOpacity,
      errorStyle: errorStyle ?? this.errorStyle,
      descriptionStyle: descriptionStyle ?? this.descriptionStyle,
      disabledOpacity: disabledOpacity ?? this.disabledOpacity,
      readOnlyOpacity: readOnlyOpacity ?? this.readOnlyOpacity,
      readOnlyBackground: readOnlyBackground ?? this.readOnlyBackground,
      focusedBackground: focusedBackground ?? this.focusedBackground,
      errorBorderEnabled: errorBorderEnabled ?? this.errorBorderEnabled,
      errorBorderEnabledBpOverrides: errorBorderEnabledBpOverrides ??
          this.errorBorderEnabledBpOverrides,
      errorIconEnabled: errorIconEnabled ?? this.errorIconEnabled,
      errorIconEnabledBpOverrides:
          errorIconEnabledBpOverrides ?? this.errorIconEnabledBpOverrides,
    );
  }
}

// ===========================================================================
// Per-widget-type partial-override classes
//
// Each class carries the same properties as [TomFieldStyle] but with every
// field nullable. Presence of a value signals an override; absence leaves
// the base value from [TomFormStyle.defaults] to apply. Subclasses add
// widget-specific properties on top.
//
// All per-widget classes share the same partial-override surface via the
// [_TomFieldStyleOverrides] shape — kept as individual classes (not a
// single generic) so widget-specific additions stay strongly typed.
// ===========================================================================

/// Partial override for text-input fields.
class TomStringInputStyle extends TomFieldPartialStyle {
  /// Which text-input look to render. `null` → use the default look.
  final StringInputVariant? variant;

  const TomStringInputStyle({
    this.variant,
    super.labelPlacement,
    super.labelPlacementBpOverrides,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.requiredIndicatorOnDescription,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.descriptionFieldGap,
    super.descriptionFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.borderWidth,
    super.focusedBorderWidth,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.inputStyle,
    super.labelStyle,
    super.labelStyleBpOverrides,
    super.hintStyle,
    super.hintStyleBpOverrides,
    super.hintFontWeight,
    super.hintOpacity,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Variant flavor for text-input decoration.
enum StringInputVariant { material, bordered }

/// Partial override for dropdown selection fields.
class TomDropdownStyle extends TomFieldPartialStyle {
  const TomDropdownStyle({
    super.labelPlacement,
    super.labelPlacementBpOverrides,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.requiredIndicatorOnDescription,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.descriptionFieldGap,
    super.descriptionFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.borderWidth,
    super.focusedBorderWidth,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.inputStyle,
    super.labelStyle,
    super.labelStyleBpOverrides,
    super.hintStyle,
    super.hintStyleBpOverrides,
    super.hintFontWeight,
    super.hintOpacity,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for slider fields.
class TomSliderStyle extends TomFieldPartialStyle {
  final WidgetStateProperty<Color>? trackColor;
  final WidgetStateProperty<Color>? activeColor;
  final WidgetStateProperty<Color>? thumbColor;

  const TomSliderStyle({
    this.trackColor,
    this.activeColor,
    this.thumbColor,
    super.labelPlacement,
    super.labelPlacementBpOverrides,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.requiredIndicatorOnDescription,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.descriptionFieldGap,
    super.descriptionFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.borderWidth,
    super.focusedBorderWidth,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.inputStyle,
    super.labelStyle,
    super.labelStyleBpOverrides,
    super.hintStyle,
    super.hintStyleBpOverrides,
    super.hintFontWeight,
    super.hintOpacity,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for checkbox fields.
class TomCheckboxStyle extends TomFieldPartialStyle {
  final WidgetStateProperty<Color>? fillColor;
  final WidgetStateProperty<Color>? checkColor;

  const TomCheckboxStyle({
    this.fillColor,
    this.checkColor,
    super.labelPlacement,
    super.labelPlacementBpOverrides,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.requiredIndicatorOnDescription,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.descriptionFieldGap,
    super.descriptionFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.borderWidth,
    super.focusedBorderWidth,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.inputStyle,
    super.labelStyle,
    super.labelStyleBpOverrides,
    super.hintStyle,
    super.hintStyleBpOverrides,
    super.hintFontWeight,
    super.hintOpacity,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for switch fields.
class TomSwitchStyle extends TomFieldPartialStyle {
  final WidgetStateProperty<Color>? thumbColor;
  final WidgetStateProperty<Color>? trackColor;

  const TomSwitchStyle({
    this.thumbColor,
    this.trackColor,
    super.labelPlacement,
    super.labelPlacementBpOverrides,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.requiredIndicatorOnDescription,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.descriptionFieldGap,
    super.descriptionFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.borderWidth,
    super.focusedBorderWidth,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.inputStyle,
    super.labelStyle,
    super.labelStyleBpOverrides,
    super.hintStyle,
    super.hintStyleBpOverrides,
    super.hintFontWeight,
    super.hintOpacity,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for segmented-button fields.
class TomSegmentedStyle extends TomFieldPartialStyle {
  final WidgetStateProperty<Color>? selectedColor;
  final WidgetStateProperty<Color>? unselectedColor;

  const TomSegmentedStyle({
    this.selectedColor,
    this.unselectedColor,
    super.labelPlacement,
    super.labelPlacementBpOverrides,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.requiredIndicatorOnDescription,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.descriptionFieldGap,
    super.descriptionFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.borderWidth,
    super.focusedBorderWidth,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.inputStyle,
    super.labelStyle,
    super.labelStyleBpOverrides,
    super.hintStyle,
    super.hintStyleBpOverrides,
    super.hintFontWeight,
    super.hintOpacity,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for radio-group fields.
class TomRadioGroupStyle extends TomFieldPartialStyle {
  final WidgetStateProperty<Color>? selectedColor;

  const TomRadioGroupStyle({
    this.selectedColor,
    super.labelPlacement,
    super.labelPlacementBpOverrides,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.requiredIndicatorOnDescription,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.descriptionFieldGap,
    super.descriptionFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.borderWidth,
    super.focusedBorderWidth,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.inputStyle,
    super.labelStyle,
    super.labelStyleBpOverrides,
    super.hintStyle,
    super.hintStyleBpOverrides,
    super.hintFontWeight,
    super.hintOpacity,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for date-picker fields.
class TomDatePickerStyle extends TomFieldPartialStyle {
  const TomDatePickerStyle({
    super.labelPlacement,
    super.labelPlacementBpOverrides,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.requiredIndicatorOnDescription,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.descriptionFieldGap,
    super.descriptionFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.borderWidth,
    super.focusedBorderWidth,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.inputStyle,
    super.labelStyle,
    super.labelStyleBpOverrides,
    super.hintStyle,
    super.hintStyleBpOverrides,
    super.hintFontWeight,
    super.hintOpacity,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for time-picker fields.
class TomTimePickerStyle extends TomFieldPartialStyle {
  const TomTimePickerStyle({
    super.labelPlacement,
    super.labelPlacementBpOverrides,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.requiredIndicatorOnDescription,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.descriptionFieldGap,
    super.descriptionFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.borderWidth,
    super.focusedBorderWidth,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.inputStyle,
    super.labelStyle,
    super.labelStyleBpOverrides,
    super.hintStyle,
    super.hintStyleBpOverrides,
    super.hintFontWeight,
    super.hintOpacity,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for file-picker fields.
class TomFilePickerStyle extends TomFieldPartialStyle {
  const TomFilePickerStyle({
    super.labelPlacement,
    super.labelPlacementBpOverrides,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.requiredIndicatorOnDescription,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.descriptionFieldGap,
    super.descriptionFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.borderWidth,
    super.focusedBorderWidth,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.inputStyle,
    super.labelStyle,
    super.labelStyleBpOverrides,
    super.hintStyle,
    super.hintStyleBpOverrides,
    super.hintFontWeight,
    super.hintOpacity,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for chips / multi-select fields.
class TomChipsStyle extends TomFieldPartialStyle {
  final WidgetStateProperty<Color>? selectedColor;
  final WidgetStateProperty<Color>? deletableColor;

  const TomChipsStyle({
    this.selectedColor,
    this.deletableColor,
    super.labelPlacement,
    super.labelPlacementBpOverrides,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.requiredIndicatorOnDescription,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.descriptionFieldGap,
    super.descriptionFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.borderWidth,
    super.focusedBorderWidth,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.inputStyle,
    super.labelStyle,
    super.labelStyleBpOverrides,
    super.hintStyle,
    super.hintStyleBpOverrides,
    super.hintFontWeight,
    super.hintOpacity,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for multiline-input fields.
class TomMultilineInputStyle extends TomFieldPartialStyle {
  final int? minLines;
  final int? maxLines;

  const TomMultilineInputStyle({
    this.minLines,
    this.maxLines,
    super.labelPlacement,
    super.labelPlacementBpOverrides,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.requiredIndicatorOnDescription,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.descriptionFieldGap,
    super.descriptionFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.borderWidth,
    super.focusedBorderWidth,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.inputStyle,
    super.labelStyle,
    super.labelStyleBpOverrides,
    super.hintStyle,
    super.hintStyleBpOverrides,
    super.hintFontWeight,
    super.hintOpacity,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

// ---------------------------------------------------------------------------
// Shared partial-override superclass.
//
// Every `Tom<Widget>Style` subclass carries this exact property surface, with
// each field nullable (absence = inherit from base). Exposed so shared
// helpers (e.g. decoration mixins, [TomFormStyle.resolveFieldStyle]) can
// accept any sub-style regardless of its concrete type.
// ---------------------------------------------------------------------------

class TomFieldPartialStyle {
  final LabelPlacement? labelPlacement;
  final List<(double, LabelPlacement)> labelPlacementBpOverrides;
  final ErrorPlacement? errorPlacement;
  final RequiredIndicator? requiredIndicator;
  final RequiredIndicator? requiredIndicatorOnHint;
  final RequiredIndicator? requiredIndicatorOnDescription;
  final DescriptionPlacement? descriptionPlacement;
  final ActionIconPlacement? actionIconPlacement;

  final double? labelFieldGap;
  final List<(double, double)> labelFieldGapBpOverrides;

  final double? errorFieldGap;
  final List<(double, double)> errorFieldGapBpOverrides;

  final double? descriptionFieldGap;
  final List<(double, double)> descriptionFieldGapBpOverrides;

  final EdgeInsets? fieldContentPadding;
  final double? borderRadius;
  final double? borderWidth;
  final double? focusedBorderWidth;
  final InputBorder? fieldBorder;
  final InputBorder? focusedBorder;
  final InputBorder? errorBorder;

  final TextStyle? inputStyle;
  final TextStyle? labelStyle;
  final List<(double, TextStyle)> labelStyleBpOverrides;
  final TextStyle? hintStyle;
  final List<(double, TextStyle)> hintStyleBpOverrides;

  /// Per-widget override for [TomFieldStyle.hintFontWeight]. Null means
  /// "inherit the umbrella default". The explicit-null semantics (clear the
  /// weight entirely) live on [TomFieldStyle.copyWith], not here — this
  /// partial class uses nullability for "unset".
  final FontWeight? hintFontWeight;

  /// Per-widget override for [TomFieldStyle.hintOpacity]. Null means
  /// "inherit the umbrella default".
  final double? hintOpacity;

  final TextStyle? errorStyle;
  final TextStyle? descriptionStyle;

  final double? disabledOpacity;
  final double? readOnlyOpacity;
  final WidgetStateProperty<Color>? readOnlyBackground;
  final WidgetStateProperty<Color>? focusedBackground;

  final bool? errorBorderEnabled;
  final List<(double, bool)> errorBorderEnabledBpOverrides;

  final bool? errorIconEnabled;
  final List<(double, bool)> errorIconEnabledBpOverrides;

  const TomFieldPartialStyle({
    this.labelPlacement,
    this.labelPlacementBpOverrides = const [],
    this.errorPlacement,
    this.requiredIndicator,
    this.requiredIndicatorOnHint,
    this.requiredIndicatorOnDescription,
    this.descriptionPlacement,
    this.actionIconPlacement,
    this.labelFieldGap,
    this.labelFieldGapBpOverrides = const [],
    this.errorFieldGap,
    this.errorFieldGapBpOverrides = const [],
    this.descriptionFieldGap,
    this.descriptionFieldGapBpOverrides = const [],
    this.fieldContentPadding,
    this.borderRadius,
    this.borderWidth,
    this.focusedBorderWidth,
    this.fieldBorder,
    this.focusedBorder,
    this.errorBorder,
    this.inputStyle,
    this.labelStyle,
    this.labelStyleBpOverrides = const [],
    this.hintStyle,
    this.hintStyleBpOverrides = const [],
    this.hintFontWeight,
    this.hintOpacity,
    this.errorStyle,
    this.descriptionStyle,
    this.disabledOpacity,
    this.readOnlyOpacity,
    this.readOnlyBackground,
    this.focusedBackground,
    this.errorBorderEnabled,
    this.errorBorderEnabledBpOverrides = const [],
    this.errorIconEnabled,
    this.errorIconEnabledBpOverrides = const [],
  });
}

// ===========================================================================
// TomFormStyle — umbrella
// ===========================================================================

/// The umbrella style class — one instance per [TomFormStyleScope].
///
/// Holds a fully-populated [defaults] plus a nullable override per widget
/// type. Consumers (fields / decoration mixins) read from both and pick per
/// property via the per-pair atomic rule exposed by [TomFieldStyle.pickPair].
class TomFormStyle {
  final TomFieldStyle defaults;

  final TomStringInputStyle? stringInputStyle;
  final TomDropdownStyle? dropdownStyle;
  final TomSliderStyle? sliderStyle;
  final TomCheckboxStyle? checkboxStyle;
  final TomSwitchStyle? switchStyle;
  final TomSegmentedStyle? segmentedStyle;
  final TomRadioGroupStyle? radioGroupStyle;
  final TomDatePickerStyle? datePickerStyle;
  final TomTimePickerStyle? timePickerStyle;
  final TomFilePickerStyle? filePickerStyle;
  final TomChipsStyle? chipsStyle;
  final TomMultilineInputStyle? multilineInputStyle;

  const TomFormStyle({
    this.defaults = const TomFieldStyle(),
    this.stringInputStyle,
    this.dropdownStyle,
    this.sliderStyle,
    this.checkboxStyle,
    this.switchStyle,
    this.segmentedStyle,
    this.radioGroupStyle,
    this.datePickerStyle,
    this.timePickerStyle,
    this.filePickerStyle,
    this.chipsStyle,
    this.multilineInputStyle,
  });

  // --- Presets -------------------------------------------------------------

  /// Material-3 defaults.
  static const TomFormStyle material3 =
      TomFormStyle(defaults: TomFieldStyle());

  /// Compact style — floating labels, reduced gaps.
  static const TomFormStyle compact = TomFormStyle(
    defaults: TomFieldStyle(
      labelPlacement: LabelPlacement.floating,
      labelFieldGap: 2.0,
      errorFieldGap: 2.0,
    ),
  );

  /// Bordered style — floating labels on an outlined border; error visuals
  /// enabled (error-border recolour + trailing error icon).
  static TomFormStyle get bordered => TomFormStyle(
        defaults: const TomFieldStyle(
          labelPlacement: LabelPlacement.floating,
          errorBorderEnabled: true,
          errorIconEnabled: true,
        ).copyWith(
          fieldBorder: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(width: 2),
          ),
          errorBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFBA1A1A)),
          ),
        ),
      );

  // --- Per-pair atomic resolution ------------------------------------------

  /// Resolves [defaults] + a per-widget [over] partial override down to a
  /// fully-populated [TomFieldStyle] at the given [width].
  ///
  /// Applies the per-pair atomic rule from [TomFieldStyle.pickPair] to every
  /// breakpointable property and a simple `over ?? base` fallback to the
  /// rest. Returns the base unchanged when [over] is null.
  TomFieldStyle resolveFieldStyle(TomFieldPartialStyle? over, double width) {
    final base = defaults;
    over ??= const TomFieldPartialStyle();

    return TomFieldStyle(
      labelPlacement: base.pickPair<LabelPlacement>(
        width,
        over.labelPlacement,
        over.labelPlacementBpOverrides,
        base.labelPlacement,
        base.labelPlacementBpOverrides,
      ),
      labelPlacementBpOverrides: over.labelPlacement != null
          ? over.labelPlacementBpOverrides
          : base.labelPlacementBpOverrides,
      errorPlacement: over.errorPlacement ?? base.errorPlacement,
      requiredIndicator: over.requiredIndicator ?? base.requiredIndicator,
      requiredIndicatorOnHint:
          over.requiredIndicatorOnHint ?? base.requiredIndicatorOnHint,
      requiredIndicatorOnDescription: over.requiredIndicatorOnDescription ??
          base.requiredIndicatorOnDescription,
      descriptionPlacement:
          over.descriptionPlacement ?? base.descriptionPlacement,
      actionIconPlacement:
          over.actionIconPlacement ?? base.actionIconPlacement,
      labelFieldGap: base.pickPair<double>(
        width,
        over.labelFieldGap,
        over.labelFieldGapBpOverrides,
        base.labelFieldGap,
        base.labelFieldGapBpOverrides,
      ),
      labelFieldGapBpOverrides: over.labelFieldGap != null
          ? over.labelFieldGapBpOverrides
          : base.labelFieldGapBpOverrides,
      errorFieldGap: base.pickPair<double>(
        width,
        over.errorFieldGap,
        over.errorFieldGapBpOverrides,
        base.errorFieldGap,
        base.errorFieldGapBpOverrides,
      ),
      errorFieldGapBpOverrides: over.errorFieldGap != null
          ? over.errorFieldGapBpOverrides
          : base.errorFieldGapBpOverrides,
      descriptionFieldGap: base.pickPair<double>(
        width,
        over.descriptionFieldGap,
        over.descriptionFieldGapBpOverrides,
        base.descriptionFieldGap,
        base.descriptionFieldGapBpOverrides,
      ),
      descriptionFieldGapBpOverrides: over.descriptionFieldGap != null
          ? over.descriptionFieldGapBpOverrides
          : base.descriptionFieldGapBpOverrides,
      fieldContentPadding:
          over.fieldContentPadding ?? base.fieldContentPadding,
      borderRadius: over.borderRadius ?? base.borderRadius,
      borderWidth: over.borderWidth ?? base.borderWidth,
      focusedBorderWidth:
          over.focusedBorderWidth ?? base.focusedBorderWidth,
      fieldBorder: over.fieldBorder ?? base.fieldBorder,
      focusedBorder: over.focusedBorder ?? base.focusedBorder,
      errorBorder: over.errorBorder ?? base.errorBorder,
      inputStyle: over.inputStyle ?? base.inputStyle,
      labelStyle: base.pickPair<TextStyle?>(
        width,
        over.labelStyle,
        over.labelStyleBpOverrides
            .map((e) => (e.$1, e.$2 as TextStyle?))
            .toList(),
        base.labelStyle,
        base.labelStyleBpOverrides
            .map((e) => (e.$1, e.$2 as TextStyle?))
            .toList(),
      ),
      labelStyleBpOverrides: over.labelStyle != null
          ? over.labelStyleBpOverrides
          : base.labelStyleBpOverrides,
      hintStyle: base.pickPair<TextStyle?>(
        width,
        over.hintStyle,
        over.hintStyleBpOverrides
            .map((e) => (e.$1, e.$2 as TextStyle?))
            .toList(),
        base.hintStyle,
        base.hintStyleBpOverrides
            .map((e) => (e.$1, e.$2 as TextStyle?))
            .toList(),
      ),
      hintStyleBpOverrides: over.hintStyle != null
          ? over.hintStyleBpOverrides
          : base.hintStyleBpOverrides,
      // Partial override null = inherit from base, so `over ?? base` is
      // correct. The explicit-null "disable" case flows via copyWith on the
      // base, not through the partial.
      hintFontWeight: over.hintFontWeight ?? base.hintFontWeight,
      hintOpacity: over.hintOpacity ?? base.hintOpacity,
      errorStyle: over.errorStyle ?? base.errorStyle,
      descriptionStyle: over.descriptionStyle ?? base.descriptionStyle,
      disabledOpacity: over.disabledOpacity ?? base.disabledOpacity,
      readOnlyOpacity: over.readOnlyOpacity ?? base.readOnlyOpacity,
      readOnlyBackground: over.readOnlyBackground ?? base.readOnlyBackground,
      focusedBackground: over.focusedBackground ?? base.focusedBackground,
      errorBorderEnabled: base.pickPair<bool>(
        width,
        over.errorBorderEnabled,
        over.errorBorderEnabledBpOverrides,
        base.errorBorderEnabled,
        base.errorBorderEnabledBpOverrides,
      ),
      errorBorderEnabledBpOverrides: over.errorBorderEnabled != null
          ? over.errorBorderEnabledBpOverrides
          : base.errorBorderEnabledBpOverrides,
      errorIconEnabled: base.pickPair<bool>(
        width,
        over.errorIconEnabled,
        over.errorIconEnabledBpOverrides,
        base.errorIconEnabled,
        base.errorIconEnabledBpOverrides,
      ),
      errorIconEnabledBpOverrides: over.errorIconEnabled != null
          ? over.errorIconEnabledBpOverrides
          : base.errorIconEnabledBpOverrides,
    );
  }

  TomFormStyle copyWith({
    TomFieldStyle? defaults,
    TomStringInputStyle? stringInputStyle,
    TomDropdownStyle? dropdownStyle,
    TomSliderStyle? sliderStyle,
    TomCheckboxStyle? checkboxStyle,
    TomSwitchStyle? switchStyle,
    TomSegmentedStyle? segmentedStyle,
    TomRadioGroupStyle? radioGroupStyle,
    TomDatePickerStyle? datePickerStyle,
    TomTimePickerStyle? timePickerStyle,
    TomFilePickerStyle? filePickerStyle,
    TomChipsStyle? chipsStyle,
    TomMultilineInputStyle? multilineInputStyle,
  }) {
    return TomFormStyle(
      defaults: defaults ?? this.defaults,
      stringInputStyle: stringInputStyle ?? this.stringInputStyle,
      dropdownStyle: dropdownStyle ?? this.dropdownStyle,
      sliderStyle: sliderStyle ?? this.sliderStyle,
      checkboxStyle: checkboxStyle ?? this.checkboxStyle,
      switchStyle: switchStyle ?? this.switchStyle,
      segmentedStyle: segmentedStyle ?? this.segmentedStyle,
      radioGroupStyle: radioGroupStyle ?? this.radioGroupStyle,
      datePickerStyle: datePickerStyle ?? this.datePickerStyle,
      timePickerStyle: timePickerStyle ?? this.timePickerStyle,
      filePickerStyle: filePickerStyle ?? this.filePickerStyle,
      chipsStyle: chipsStyle ?? this.chipsStyle,
      multilineInputStyle: multilineInputStyle ?? this.multilineInputStyle,
    );
  }

  // --- Theme derivation ----------------------------------------------------

  /// Returns a derivative populated from [theme]'s color scheme and text
  /// theme. Only properties that still equal the preset's original defaults
  /// get replaced — user-set values are preserved.
  ///
  /// This implementation compares each property against
  /// [TomFormStyle.material3]'s `defaults` to decide preservation: callers
  /// starting from any preset that shares those untouched defaults
  /// (`material3`, `compact`, `bordered`) get theme-aware colors without
  /// losing their own `copyWith`-applied overrides.
  TomFormStyle withTheme(ThemeData theme) {
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    const origin = TomFieldStyle(); // the canonical untouched defaults

    TextStyle? pickTextStyle(TextStyle? current, TextStyle? originValue,
        TextStyle? themed) {
      return identical(current, originValue) ? themed : current;
    }

    WidgetStateProperty<Color>? pickStateColor(
      WidgetStateProperty<Color>? current,
      WidgetStateProperty<Color>? originValue,
      WidgetStateProperty<Color>? themed,
    ) {
      return identical(current, originValue) ? themed : current;
    }

    // Preserve the border variant (null stays null, OutlineInputBorder stays
    // outlined, UnderlineInputBorder stays underlined) — only swap the
    // stroke color to the themed one, keeping the original width. This
    // keeps each preset's visual identity across `withTheme` (including
    // custom widths set by the user) while still adopting theme colors.
    InputBorder? reTintBorder(InputBorder? current, Color color) {
      if (current == null) return null;
      if (current is OutlineInputBorder) {
        final side = current.borderSide.copyWith(color: color);
        return current.copyWith(borderSide: side);
      }
      if (current is UnderlineInputBorder) {
        final side = current.borderSide.copyWith(color: color);
        return current.copyWith(borderSide: side);
      }
      return current;
    }

    // Colour policy per slot:
    //   • label / input → preserve whatever colour the theme's bodyMedium
    //     carries. If the theme creator set `bodyMedium.color` that colour
    //     wins; if they left it null, the rendered Text falls through to
    //     the ambient DefaultTextStyle (onSurface by convention).
    //   • error → always `cs.error` (semantic, not theme-choosable).
    //   • hint / description → muted via `cs.onSurfaceVariant` so they read
    //     as secondary regardless of what the theme sets for bodyMedium.
    TextStyle? withColorOrInherit(TextStyle? base) => base;
    TextStyle? withColor(TextStyle? base, Color color) =>
        base?.copyWith(color: color);

    final themedDefaults = defaults.copyWith(
      inputStyle: pickTextStyle(
        defaults.inputStyle,
        origin.inputStyle,
        withColorOrInherit(tt.bodyMedium),
      ),
      labelStyle: pickTextStyle(
        defaults.labelStyle,
        origin.labelStyle,
        withColorOrInherit(tt.bodyMedium),
      ),
      hintStyle: pickTextStyle(
        defaults.hintStyle,
        origin.hintStyle,
        withColor(tt.bodyMedium, cs.onSurfaceVariant),
      ),
      errorStyle: pickTextStyle(
        defaults.errorStyle,
        origin.errorStyle,
        withColor(tt.bodySmall, cs.error),
      ),
      descriptionStyle: pickTextStyle(
        defaults.descriptionStyle,
        origin.descriptionStyle,
        withColor(tt.bodySmall, cs.onSurfaceVariant),
      ),
      fieldBorder: reTintBorder(defaults.fieldBorder, cs.outline),
      focusedBorder: reTintBorder(defaults.focusedBorder, cs.primary),
      errorBorder: reTintBorder(defaults.errorBorder, cs.error),
      focusedBackground: pickStateColor(
        defaults.focusedBackground,
        origin.focusedBackground,
        WidgetStatePropertyAll(cs.surfaceContainerHighest),
      ),
      // readOnlyBackground intentionally NOT auto-derived: a read-only field
      // should not spontaneously grow a grey fill just because a theme is in
      // play. Users who want the visual distinction set it explicitly via
      // style.readOnlyBackground or the `readOnlyBackground` JSON property.
    );

    return copyWith(defaults: themedDefaults);
  }
}
