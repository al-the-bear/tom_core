import 'package:flutter/material.dart';

import '../../widget_base/tom_construction_helpers.dart';
import 'form_style_enums.dart';

/// Configuration class for form field styling (§10a).
///
/// Controls anatomy defaults, spacing, borders, grouping, typography,
/// and authorization visuals for all form fields within a scope.
///
/// Use [TomFormStyleScope] to provide a style to the widget tree.
class TomFormStyleLegacy {
  // --- Anatomy defaults ---

  /// Where labels are placed relative to field inputs.
  final LabelPlacement labelPlacement;

  /// Where validation error messages appear.
  final ErrorPlacement errorPlacement;

  /// How required fields are indicated on the label.
  final RequiredIndicator requiredIndicator;

  /// How required fields are indicated on the hint/placeholder. Independent
  /// of [requiredIndicator] — set both to show the marker on label and hint.
  final RequiredIndicator requiredIndicatorOnHint;

  /// Where description/helper text appears.
  final DescriptionPlacement descriptionPlacement;

  /// Where action icons appear relative to the field input.
  final ActionIconPlacement actionIconPlacement;

  // --- Spacing ---

  /// Vertical space between fields (default: 16.0).
  final double fieldSpacing;

  /// Space between field groups (default: 24.0).
  final double fieldGroupSpacing;

  /// Space between label and field (default: 4.0).
  final double labelFieldGap;

  /// Space between field and error (default: 4.0).
  final double errorFieldGap;

  /// Padding inside the field container.
  final EdgeInsets fieldContentPadding;

  // --- Border ---

  /// Border style for text inputs (outline, underline, none).
  final InputBorder? fieldBorder;

  /// Border when focused.
  final InputBorder? focusedBorder;

  /// Border when in error state.
  final InputBorder? errorBorder;

  /// Corner radius for field containers (default: 8.0).
  final double borderRadius;

  // --- Grouping containers ---

  /// Border/background decoration for field groups.
  final BoxDecoration? groupDecoration;

  /// Padding inside groups.
  final EdgeInsets groupPadding;

  // --- Typography overrides ---

  /// Style for field labels.
  final TextStyle? labelStyle;

  /// Style for hint/placeholder text.
  final TextStyle? hintStyle;

  /// Style for error messages.
  final TextStyle? errorStyle;

  /// Style for description/helper text.
  final TextStyle? descriptionStyle;

  // --- Authorization visuals ---

  /// Opacity for disabled fields (default: 0.5).
  final double disabledOpacity;

  /// Background tint for read-only fields.
  final Color? readOnlyBackground;

  const TomFormStyleLegacy({
    this.labelPlacement = LabelPlacement.above,
    this.errorPlacement = ErrorPlacement.below,
    this.requiredIndicator = RequiredIndicator.asterisk,
    this.requiredIndicatorOnHint = RequiredIndicator.none,
    this.descriptionPlacement = DescriptionPlacement.below,
    this.actionIconPlacement = ActionIconPlacement.trailing,
    this.fieldSpacing = 16.0,
    this.fieldGroupSpacing = 24.0,
    this.labelFieldGap = 4.0,
    this.errorFieldGap = 4.0,
    this.fieldContentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
    this.fieldBorder,
    this.focusedBorder,
    this.errorBorder,
    this.borderRadius = 8.0,
    this.groupDecoration,
    this.groupPadding = const EdgeInsets.all(16),
    this.labelStyle,
    this.hintStyle,
    this.errorStyle,
    this.descriptionStyle,
    this.disabledOpacity = 0.5,
    this.readOnlyBackground,
  });

  /// Default Material 3 style.
  static const material3 = TomFormStyleLegacy();

  /// Compact style with floating labels and reduced spacing.
  static const compact = TomFormStyleLegacy(
    labelPlacement: LabelPlacement.floating,
    fieldSpacing: 8.0,
    fieldGroupSpacing: 16.0,
  );

  /// Load style properties from TomCtr resource keys.
  ///
  /// Keys are resolved under [basePath], e.g.:
  /// - `tomApp.forms.style.fieldSpacing` → 20.0
  /// - `tomApp.forms.style.borderRadius` → 12.0
  /// - `tomApp.forms.style.labelPlacement` → "above"
  factory TomFormStyleLegacy.fromResources(String basePath) {
    return TomFormStyleLegacy(
      labelPlacement: _parseLabelPlacement(
        TomCtr.textOrNull(basePath, 'labelPlacement'),
      ),
      errorPlacement: _parseErrorPlacement(
        TomCtr.textOrNull(basePath, 'errorPlacement'),
      ),
      requiredIndicator: _parseRequiredIndicator(
        TomCtr.textOrNull(basePath, 'requiredIndicator'),
      ),
      requiredIndicatorOnHint: _parseRequiredIndicator(
        TomCtr.textOrNull(basePath, 'requiredIndicatorOnHint'),
        fallback: RequiredIndicator.none,
      ),
      descriptionPlacement: _parseDescriptionPlacement(
        TomCtr.textOrNull(basePath, 'descriptionPlacement'),
      ),
      actionIconPlacement: _parseActionIconPlacement(
        TomCtr.textOrNull(basePath, 'actionIconPlacement'),
      ),
      fieldSpacing: TomCtr.doubleVal(basePath, 'fieldSpacing') ?? 16.0,
      fieldGroupSpacing:
          TomCtr.doubleVal(basePath, 'fieldGroupSpacing') ?? 24.0,
      labelFieldGap: TomCtr.doubleVal(basePath, 'labelFieldGap') ?? 4.0,
      errorFieldGap: TomCtr.doubleVal(basePath, 'errorFieldGap') ?? 4.0,
      borderRadius: TomCtr.doubleVal(basePath, 'borderRadius') ?? 8.0,
      disabledOpacity:
          TomCtr.doubleVal(basePath, 'disabledOpacity') ?? 0.5,
      readOnlyBackground: TomCtr.color(basePath, 'readOnlyBackground'),
    );
  }

  /// Create a copy with overridden fields.
  TomFormStyleLegacy copyWith({
    LabelPlacement? labelPlacement,
    ErrorPlacement? errorPlacement,
    RequiredIndicator? requiredIndicator,
    RequiredIndicator? requiredIndicatorOnHint,
    DescriptionPlacement? descriptionPlacement,
    ActionIconPlacement? actionIconPlacement,
    double? fieldSpacing,
    double? fieldGroupSpacing,
    double? labelFieldGap,
    double? errorFieldGap,
    EdgeInsets? fieldContentPadding,
    InputBorder? fieldBorder,
    InputBorder? focusedBorder,
    InputBorder? errorBorder,
    double? borderRadius,
    BoxDecoration? groupDecoration,
    EdgeInsets? groupPadding,
    TextStyle? labelStyle,
    TextStyle? hintStyle,
    TextStyle? errorStyle,
    TextStyle? descriptionStyle,
    double? disabledOpacity,
    Color? readOnlyBackground,
  }) {
    return TomFormStyleLegacy(
      labelPlacement: labelPlacement ?? this.labelPlacement,
      errorPlacement: errorPlacement ?? this.errorPlacement,
      requiredIndicator: requiredIndicator ?? this.requiredIndicator,
      requiredIndicatorOnHint:
          requiredIndicatorOnHint ?? this.requiredIndicatorOnHint,
      descriptionPlacement:
          descriptionPlacement ?? this.descriptionPlacement,
      actionIconPlacement:
          actionIconPlacement ?? this.actionIconPlacement,
      fieldSpacing: fieldSpacing ?? this.fieldSpacing,
      fieldGroupSpacing: fieldGroupSpacing ?? this.fieldGroupSpacing,
      labelFieldGap: labelFieldGap ?? this.labelFieldGap,
      errorFieldGap: errorFieldGap ?? this.errorFieldGap,
      fieldContentPadding:
          fieldContentPadding ?? this.fieldContentPadding,
      fieldBorder: fieldBorder ?? this.fieldBorder,
      focusedBorder: focusedBorder ?? this.focusedBorder,
      errorBorder: errorBorder ?? this.errorBorder,
      borderRadius: borderRadius ?? this.borderRadius,
      groupDecoration: groupDecoration ?? this.groupDecoration,
      groupPadding: groupPadding ?? this.groupPadding,
      labelStyle: labelStyle ?? this.labelStyle,
      hintStyle: hintStyle ?? this.hintStyle,
      errorStyle: errorStyle ?? this.errorStyle,
      descriptionStyle: descriptionStyle ?? this.descriptionStyle,
      disabledOpacity: disabledOpacity ?? this.disabledOpacity,
      readOnlyBackground: readOnlyBackground ?? this.readOnlyBackground,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TomFormStyleLegacy &&
          runtimeType == other.runtimeType &&
          labelPlacement == other.labelPlacement &&
          errorPlacement == other.errorPlacement &&
          requiredIndicator == other.requiredIndicator &&
          requiredIndicatorOnHint == other.requiredIndicatorOnHint &&
          descriptionPlacement == other.descriptionPlacement &&
          actionIconPlacement == other.actionIconPlacement &&
          fieldSpacing == other.fieldSpacing &&
          fieldGroupSpacing == other.fieldGroupSpacing &&
          labelFieldGap == other.labelFieldGap &&
          errorFieldGap == other.errorFieldGap &&
          fieldContentPadding == other.fieldContentPadding &&
          fieldBorder == other.fieldBorder &&
          focusedBorder == other.focusedBorder &&
          errorBorder == other.errorBorder &&
          borderRadius == other.borderRadius &&
          groupDecoration == other.groupDecoration &&
          groupPadding == other.groupPadding &&
          labelStyle == other.labelStyle &&
          hintStyle == other.hintStyle &&
          errorStyle == other.errorStyle &&
          descriptionStyle == other.descriptionStyle &&
          disabledOpacity == other.disabledOpacity &&
          readOnlyBackground == other.readOnlyBackground;

  @override
  int get hashCode => Object.hash(
        Object.hash(
          labelPlacement,
          errorPlacement,
          requiredIndicator,
          requiredIndicatorOnHint,
          descriptionPlacement,
          actionIconPlacement,
          fieldSpacing,
          fieldGroupSpacing,
          labelFieldGap,
          errorFieldGap,
          fieldContentPadding,
          fieldBorder,
        ),
        Object.hash(
          focusedBorder,
          errorBorder,
          borderRadius,
          groupDecoration,
          groupPadding,
          labelStyle,
          hintStyle,
          errorStyle,
          descriptionStyle,
          disabledOpacity,
          readOnlyBackground,
        ),
      );

  // --- Private enum parsers for fromResources ---

  static LabelPlacement _parseLabelPlacement(String? value) {
    return switch (value) {
      'above' => LabelPlacement.above,
      'below' => LabelPlacement.below,
      'floating' => LabelPlacement.floating,
      'inline' => LabelPlacement.inline,
      'hidden' => LabelPlacement.hidden,
      _ => LabelPlacement.above,
    };
  }

  static ErrorPlacement _parseErrorPlacement(String? value) {
    return switch (value) {
      'below' => ErrorPlacement.below,
      'above' => ErrorPlacement.above,
      'tooltip' => ErrorPlacement.tooltip,
      'both' => ErrorPlacement.both,
      'replaceHint' => ErrorPlacement.replaceHint,
      _ => ErrorPlacement.below,
    };
  }

  static RequiredIndicator _parseRequiredIndicator(
    String? value, {
    RequiredIndicator fallback = RequiredIndicator.asterisk,
  }) {
    return switch (value) {
      'asterisk' => RequiredIndicator.asterisk,
      'text' => RequiredIndicator.text,
      'none' => RequiredIndicator.none,
      'custom' => RequiredIndicator.custom,
      _ => fallback,
    };
  }

  static DescriptionPlacement _parseDescriptionPlacement(String? value) {
    return switch (value) {
      'below' => DescriptionPlacement.below,
      'above' => DescriptionPlacement.above,
      'tooltip' => DescriptionPlacement.tooltip,
      _ => DescriptionPlacement.below,
    };
  }

  static ActionIconPlacement _parseActionIconPlacement(String? value) {
    return switch (value) {
      'trailing' => ActionIconPlacement.trailing,
      'leading' => ActionIconPlacement.leading,
      'above' => ActionIconPlacement.above,
      _ => ActionIconPlacement.trailing,
    };
  }
}
