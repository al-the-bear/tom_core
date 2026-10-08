/// Cupertino flavour of [TomFormStyle].
///
/// `TomCupertinoFormStyle` is the Cupertino counterpart of [TomFormStyle]:
/// the *same* property surface (anatomy, typography, gaps, error-visual
/// toggles), but its `cupertino` preset ships Cupertino-tuned defaults so
/// that fields wrapped by Cupertino concretes sit visually flush with
/// `CupertinoTextField` / `CupertinoSwitch` / etc.
///
/// Cupertino concretes (e.g. `TomCupertinoFormStringInput`) render their
/// own native control inside the same `TomGenericFieldDecorationMixin` /
/// `TomStringInputDecorationMixin` anatomy that Material concretes use,
/// so the entire properties surface stays meaningful — `borderRadius`
/// and `fieldContentPadding` flow into the `CupertinoTextField`
/// `decoration: BoxDecoration(borderRadius: ...)` and `padding: ...`
/// constructor parameters; `labelStyle` / `errorStyle` /
/// `descriptionStyle` flow through the anatomy column unchanged.
///
/// Subclassing [TomFormStyle] (rather than rolling a parallel hierarchy)
/// keeps `TomFormStyleScope.style` polymorphic across families: the
/// scope's `style: TomFormStyle?` parameter accepts either flavour and
/// `styleBpOverrides` may interleave Material and Cupertino entries
/// freely, which is what breakpoint-driven family swap leans on.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'form_style_enums.dart';
import 'tom_form_style.dart';

/// Cupertino flavour of [TomFormStyle].
///
/// Carries the same property surface as [TomFormStyle] (it *is* a
/// [TomFormStyle] subclass) but its [cupertino] preset ships
/// Cupertino-tuned defaults: tighter padding, a `borderRadius` that
/// matches `CupertinoTextField`, label-above placement (Tom convention
/// — Cupertino concretes render placeholders inside the field
/// independently of the anatomy label), and error-icon visuals
/// disabled by default to keep the iOS-ish minimalism.
class TomCupertinoFormStyle extends TomFormStyle {
  const TomCupertinoFormStyle({
    super.defaults,
    super.stringInputStyle,
    super.dropdownStyle,
    super.sliderStyle,
    super.checkboxStyle,
    super.switchStyle,
    super.segmentedStyle,
    super.radioGroupStyle,
    super.datePickerStyle,
    super.timePickerStyle,
    super.filePickerStyle,
    super.chipsStyle,
    super.multilineInputStyle,
  });

  /// Cupertino-derived defaults.
  ///
  ///   * `borderRadius: 6` — matches `CupertinoTextField`'s default
  ///     box-decoration corner radius.
  ///   * `fieldContentPadding: EdgeInsets(horizontal 12, vertical 6)` —
  ///     a pinch tighter than Material's 12/8 to match Cupertino's
  ///     inherent vertical breathing room.
  ///   * `errorBorderEnabled: false`, `errorIconEnabled: false` —
  ///     keep iOS minimalism. Errors surface in the anatomy row only.
  ///   * `labelPlacement: above` — same as Material default; Cupertino
  ///     concretes emit a placeholder *inside* the field independently.
  static TomCupertinoFormStyle get cupertino => const TomCupertinoFormStyle(
    defaults: TomFieldStyle(
      labelPlacement: TomLabelPlacement.above,
      errorPlacement: TomErrorPlacement.below,
      descriptionPlacement: TomDescriptionPlacement.below,
      actionIconPlacement: TomActionIconPlacement.trailing,
      labelFieldGap: 4.0,
      errorFieldGap: 4.0,
      descriptionFieldGap: 4.0,
      fieldContentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      borderRadius: 6.0,
      errorBorderEnabled: false,
      errorIconEnabled: false,
    ),
  );

  /// Returns a derivative populated from [theme]'s color scheme and text
  /// theme, then applies Cupertino-flavour error tinting.
  ///
  /// Delegates to [TomFormStyle.withTheme] for the bulk of the work and
  /// then re-wraps the result so it remains a [TomCupertinoFormStyle]
  /// (subtype identity matters for `is TomCupertinoFormStyle` checks
  /// in style-family-aware widgets and for `TomFormFieldFamily`
  /// resolution downstream).
  @override
  TomCupertinoFormStyle withTheme(ThemeData theme) {
    final themed = super.withTheme(theme);
    return TomCupertinoFormStyle(
      defaults: themed.defaults,
      stringInputStyle: themed.stringInputStyle,
      dropdownStyle: themed.dropdownStyle,
      sliderStyle: themed.sliderStyle,
      checkboxStyle: themed.checkboxStyle,
      switchStyle: themed.switchStyle,
      segmentedStyle: themed.segmentedStyle,
      radioGroupStyle: themed.radioGroupStyle,
      datePickerStyle: themed.datePickerStyle,
      timePickerStyle: themed.timePickerStyle,
      filePickerStyle: themed.filePickerStyle,
      chipsStyle: themed.chipsStyle,
      multilineInputStyle: themed.multilineInputStyle,
    );
  }
}

/// Tiny helper that resolves the ambient `CupertinoThemeData` and
/// returns a `BoxDecoration` suitable for Cupertino field surfaces —
/// honouring [TomFieldStyle.borderRadius] and the field's auth-state
/// background hint. Centralised here so every Cupertino field concrete
/// renders against the same surface contract.
BoxDecoration cupertinoFieldDecoration({
  required BuildContext context,
  required double borderRadius,
  Color? fillColor,
  bool focused = false,
}) {
  final theme = CupertinoTheme.of(context);
  final base =
      fillColor ?? CupertinoColors.tertiarySystemFill.resolveFrom(context);
  return BoxDecoration(
    color: base,
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: focused
          ? theme.primaryColor
          : CupertinoColors.separator.resolveFrom(context),
      width: focused ? 1.5 : 0.5,
    ),
  );
}
