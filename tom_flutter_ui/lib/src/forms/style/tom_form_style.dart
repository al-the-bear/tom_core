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
  final ErrorPlacement errorPlacement;
  final RequiredIndicator requiredIndicator;
  final RequiredIndicator requiredIndicatorOnHint;
  final DescriptionPlacement descriptionPlacement;
  final ActionIconPlacement actionIconPlacement;

  // --- Intra-field anatomy gaps -------------------------------------------

  final double labelFieldGap;
  final List<(double, double)> labelFieldGapBpOverrides;

  final double errorFieldGap;
  final List<(double, double)> errorFieldGapBpOverrides;

  // --- Field-box shape -----------------------------------------------------

  final EdgeInsets fieldContentPadding;
  final double borderRadius;
  final InputBorder? fieldBorder;
  final InputBorder? focusedBorder;
  final InputBorder? errorBorder;

  // --- Typography ----------------------------------------------------------

  final TextStyle? labelStyle;
  final TextStyle? hintStyle;
  final TextStyle? errorStyle;
  final TextStyle? descriptionStyle;

  // --- State visuals -------------------------------------------------------

  final double disabledOpacity;
  final WidgetStateProperty<Color>? readOnlyBackground;
  final WidgetStateProperty<Color>? focusedBackground;

  final bool errorBorderEnabled;
  final List<(double, bool)> errorBorderEnabledBpOverrides;

  final bool errorIconEnabled;
  final List<(double, bool)> errorIconEnabledBpOverrides;

  const TomFieldStyle({
    this.labelPlacement = LabelPlacement.above,
    this.errorPlacement = ErrorPlacement.below,
    this.requiredIndicator = RequiredIndicator.asterisk,
    this.requiredIndicatorOnHint = RequiredIndicator.none,
    this.descriptionPlacement = DescriptionPlacement.below,
    this.actionIconPlacement = ActionIconPlacement.trailing,
    this.labelFieldGap = 4.0,
    this.labelFieldGapBpOverrides = const [],
    this.errorFieldGap = 4.0,
    this.errorFieldGapBpOverrides = const [],
    this.fieldContentPadding =
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.borderRadius = 8.0,
    this.fieldBorder,
    this.focusedBorder,
    this.errorBorder,
    this.labelStyle,
    this.hintStyle,
    this.errorStyle,
    this.descriptionStyle,
    this.disabledOpacity = 0.5,
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
    ErrorPlacement? errorPlacement,
    RequiredIndicator? requiredIndicator,
    RequiredIndicator? requiredIndicatorOnHint,
    DescriptionPlacement? descriptionPlacement,
    ActionIconPlacement? actionIconPlacement,
    double? labelFieldGap,
    List<(double, double)>? labelFieldGapBpOverrides,
    double? errorFieldGap,
    List<(double, double)>? errorFieldGapBpOverrides,
    EdgeInsets? fieldContentPadding,
    double? borderRadius,
    InputBorder? fieldBorder,
    InputBorder? focusedBorder,
    InputBorder? errorBorder,
    TextStyle? labelStyle,
    TextStyle? hintStyle,
    TextStyle? errorStyle,
    TextStyle? descriptionStyle,
    double? disabledOpacity,
    WidgetStateProperty<Color>? readOnlyBackground,
    WidgetStateProperty<Color>? focusedBackground,
    bool? errorBorderEnabled,
    List<(double, bool)>? errorBorderEnabledBpOverrides,
    bool? errorIconEnabled,
    List<(double, bool)>? errorIconEnabledBpOverrides,
  }) {
    return TomFieldStyle(
      labelPlacement: labelPlacement ?? this.labelPlacement,
      errorPlacement: errorPlacement ?? this.errorPlacement,
      requiredIndicator: requiredIndicator ?? this.requiredIndicator,
      requiredIndicatorOnHint:
          requiredIndicatorOnHint ?? this.requiredIndicatorOnHint,
      descriptionPlacement:
          descriptionPlacement ?? this.descriptionPlacement,
      actionIconPlacement: actionIconPlacement ?? this.actionIconPlacement,
      labelFieldGap: labelFieldGap ?? this.labelFieldGap,
      labelFieldGapBpOverrides:
          labelFieldGapBpOverrides ?? this.labelFieldGapBpOverrides,
      errorFieldGap: errorFieldGap ?? this.errorFieldGap,
      errorFieldGapBpOverrides:
          errorFieldGapBpOverrides ?? this.errorFieldGapBpOverrides,
      fieldContentPadding: fieldContentPadding ?? this.fieldContentPadding,
      borderRadius: borderRadius ?? this.borderRadius,
      fieldBorder: fieldBorder ?? this.fieldBorder,
      focusedBorder: focusedBorder ?? this.focusedBorder,
      errorBorder: errorBorder ?? this.errorBorder,
      labelStyle: labelStyle ?? this.labelStyle,
      hintStyle: hintStyle ?? this.hintStyle,
      errorStyle: errorStyle ?? this.errorStyle,
      descriptionStyle: descriptionStyle ?? this.descriptionStyle,
      disabledOpacity: disabledOpacity ?? this.disabledOpacity,
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
class TomStringInputStyle extends _TomFieldPartialStyle {
  /// Which text-input look to render. `null` → use the default look.
  final StringInputVariant? variant;

  const TomStringInputStyle({
    this.variant,
    super.labelPlacement,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.labelStyle,
    super.hintStyle,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
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
class TomDropdownStyle extends _TomFieldPartialStyle {
  const TomDropdownStyle({
    super.labelPlacement,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.labelStyle,
    super.hintStyle,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for slider fields.
class TomSliderStyle extends _TomFieldPartialStyle {
  final WidgetStateProperty<Color>? trackColor;
  final WidgetStateProperty<Color>? activeColor;
  final WidgetStateProperty<Color>? thumbColor;

  const TomSliderStyle({
    this.trackColor,
    this.activeColor,
    this.thumbColor,
    super.labelPlacement,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.labelStyle,
    super.hintStyle,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for checkbox fields.
class TomCheckboxStyle extends _TomFieldPartialStyle {
  final WidgetStateProperty<Color>? fillColor;
  final WidgetStateProperty<Color>? checkColor;

  const TomCheckboxStyle({
    this.fillColor,
    this.checkColor,
    super.labelPlacement,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.labelStyle,
    super.hintStyle,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for switch fields.
class TomSwitchStyle extends _TomFieldPartialStyle {
  final WidgetStateProperty<Color>? thumbColor;
  final WidgetStateProperty<Color>? trackColor;

  const TomSwitchStyle({
    this.thumbColor,
    this.trackColor,
    super.labelPlacement,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.labelStyle,
    super.hintStyle,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for segmented-button fields.
class TomSegmentedStyle extends _TomFieldPartialStyle {
  final WidgetStateProperty<Color>? selectedColor;
  final WidgetStateProperty<Color>? unselectedColor;

  const TomSegmentedStyle({
    this.selectedColor,
    this.unselectedColor,
    super.labelPlacement,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.labelStyle,
    super.hintStyle,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for radio-group fields.
class TomRadioGroupStyle extends _TomFieldPartialStyle {
  final WidgetStateProperty<Color>? selectedColor;

  const TomRadioGroupStyle({
    this.selectedColor,
    super.labelPlacement,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.labelStyle,
    super.hintStyle,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for date-picker fields.
class TomDatePickerStyle extends _TomFieldPartialStyle {
  const TomDatePickerStyle({
    super.labelPlacement,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.labelStyle,
    super.hintStyle,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for time-picker fields.
class TomTimePickerStyle extends _TomFieldPartialStyle {
  const TomTimePickerStyle({
    super.labelPlacement,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.labelStyle,
    super.hintStyle,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for file-picker fields.
class TomFilePickerStyle extends _TomFieldPartialStyle {
  const TomFilePickerStyle({
    super.labelPlacement,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.labelStyle,
    super.hintStyle,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for chips / multi-select fields.
class TomChipsStyle extends _TomFieldPartialStyle {
  final WidgetStateProperty<Color>? selectedColor;
  final WidgetStateProperty<Color>? deletableColor;

  const TomChipsStyle({
    this.selectedColor,
    this.deletableColor,
    super.labelPlacement,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.labelStyle,
    super.hintStyle,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

/// Partial override for multiline-input fields.
class TomMultilineInputStyle extends _TomFieldPartialStyle {
  final int? minLines;
  final int? maxLines;

  const TomMultilineInputStyle({
    this.minLines,
    this.maxLines,
    super.labelPlacement,
    super.errorPlacement,
    super.requiredIndicator,
    super.requiredIndicatorOnHint,
    super.descriptionPlacement,
    super.actionIconPlacement,
    super.labelFieldGap,
    super.labelFieldGapBpOverrides,
    super.errorFieldGap,
    super.errorFieldGapBpOverrides,
    super.fieldContentPadding,
    super.borderRadius,
    super.fieldBorder,
    super.focusedBorder,
    super.errorBorder,
    super.labelStyle,
    super.hintStyle,
    super.errorStyle,
    super.descriptionStyle,
    super.disabledOpacity,
    super.readOnlyBackground,
    super.focusedBackground,
    super.errorBorderEnabled,
    super.errorBorderEnabledBpOverrides,
    super.errorIconEnabled,
    super.errorIconEnabledBpOverrides,
  });
}

// ---------------------------------------------------------------------------
// Internal shared partial-override superclass (not exported).
// ---------------------------------------------------------------------------

class _TomFieldPartialStyle {
  final LabelPlacement? labelPlacement;
  final ErrorPlacement? errorPlacement;
  final RequiredIndicator? requiredIndicator;
  final RequiredIndicator? requiredIndicatorOnHint;
  final DescriptionPlacement? descriptionPlacement;
  final ActionIconPlacement? actionIconPlacement;

  final double? labelFieldGap;
  final List<(double, double)> labelFieldGapBpOverrides;

  final double? errorFieldGap;
  final List<(double, double)> errorFieldGapBpOverrides;

  final EdgeInsets? fieldContentPadding;
  final double? borderRadius;
  final InputBorder? fieldBorder;
  final InputBorder? focusedBorder;
  final InputBorder? errorBorder;

  final TextStyle? labelStyle;
  final TextStyle? hintStyle;
  final TextStyle? errorStyle;
  final TextStyle? descriptionStyle;

  final double? disabledOpacity;
  final WidgetStateProperty<Color>? readOnlyBackground;
  final WidgetStateProperty<Color>? focusedBackground;

  final bool? errorBorderEnabled;
  final List<(double, bool)> errorBorderEnabledBpOverrides;

  final bool? errorIconEnabled;
  final List<(double, bool)> errorIconEnabledBpOverrides;

  const _TomFieldPartialStyle({
    this.labelPlacement,
    this.errorPlacement,
    this.requiredIndicator,
    this.requiredIndicatorOnHint,
    this.descriptionPlacement,
    this.actionIconPlacement,
    this.labelFieldGap,
    this.labelFieldGapBpOverrides = const [],
    this.errorFieldGap,
    this.errorFieldGapBpOverrides = const [],
    this.fieldContentPadding,
    this.borderRadius,
    this.fieldBorder,
    this.focusedBorder,
    this.errorBorder,
    this.labelStyle,
    this.hintStyle,
    this.errorStyle,
    this.descriptionStyle,
    this.disabledOpacity,
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

    InputBorder? pickBorder(
      InputBorder? current,
      InputBorder? originValue,
      InputBorder themed,
    ) {
      return identical(current, originValue) ? themed : current;
    }

    final themedDefaults = defaults.copyWith(
      labelStyle: pickTextStyle(
        defaults.labelStyle,
        origin.labelStyle,
        tt.bodyMedium,
      ),
      hintStyle: pickTextStyle(
        defaults.hintStyle,
        origin.hintStyle,
        tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
      errorStyle: pickTextStyle(
        defaults.errorStyle,
        origin.errorStyle,
        tt.bodySmall?.copyWith(color: cs.error),
      ),
      descriptionStyle: pickTextStyle(
        defaults.descriptionStyle,
        origin.descriptionStyle,
        tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      fieldBorder: pickBorder(
        defaults.fieldBorder,
        origin.fieldBorder,
        OutlineInputBorder(borderSide: BorderSide(color: cs.outline)),
      ),
      focusedBorder: pickBorder(
        defaults.focusedBorder,
        origin.focusedBorder,
        OutlineInputBorder(
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
      errorBorder: pickBorder(
        defaults.errorBorder,
        origin.errorBorder,
        OutlineInputBorder(borderSide: BorderSide(color: cs.error)),
      ),
      focusedBackground: pickStateColor(
        defaults.focusedBackground,
        origin.focusedBackground,
        WidgetStatePropertyAll(cs.surfaceContainerHighest),
      ),
      readOnlyBackground: pickStateColor(
        defaults.readOnlyBackground,
        origin.readOnlyBackground,
        WidgetStatePropertyAll(cs.surfaceContainer),
      ),
    );

    return copyWith(defaults: themedDefaults);
  }
}
