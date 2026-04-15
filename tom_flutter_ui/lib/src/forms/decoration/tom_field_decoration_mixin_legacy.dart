import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../style/form_style_enums.dart';
import '../style/tom_form_style_legacy.dart';
import '../style/tom_form_style_scope_legacy.dart';
import '../tom_form.dart';
import '../validation/validation_result.dart';
import '../validation/validators.dart';

/// Mixin that wraps any field widget with the standard form field anatomy:
/// label row, error row, description row, and action icons.
///
/// Used by non-text fields (Slider, Checkbox, SegmentedButton, etc.)
/// that lack built-in decoration. Text-input fields typically use
/// `InputDecoration` instead.
///
/// Reads placement settings from [TomFormStyleLegacy] via [TomFormStyleScopeLegacy].
mixin TomFieldDecorationMixinLegacy<T> on TomField<T> {
  /// Label text — resolved from resources or set explicitly.
  String? get labelText => null;

  /// Description/helper text — resolved from resources or set explicitly.
  String? get descriptionText => null;

  /// Whether this field has a required validator.
  bool get hasRequiredValidator {
    for (final validator in validators) {
      if (validator == Validators.requiredInstance) return true;
    }
    return false;
  }

  /// Wraps [innerWidget] with the standard field anatomy
  /// (label, error, description, action icons).
  Widget decorateField(BuildContext context, Widget innerWidget) {
    final style = TomFormStyleScopeLegacy.of(context);
    final theme = Theme.of(context);
    final effectiveAuth = effectiveAuthState;

    // Hidden fields render nothing
    if (effectiveAuth == TomAuthState.none) {
      return const SizedBox.shrink();
    }

    // Disabled opacity wrapper
    Widget content = _buildAnatomyColumn(context, style, theme, innerWidget);
    if (effectiveAuth == TomAuthState.disabled) {
      content = Opacity(opacity: style.disabledOpacity, child: content);
    }

    return content;
  }

  Widget _buildAnatomyColumn(
    BuildContext context,
    TomFormStyleLegacy style,
    ThemeData theme,
    Widget innerWidget,
  ) {
    final children = <Widget>[];

    // Resolved parts (null when not applicable for the current placement).
    final label = _buildLabelRow(style, theme);
    final descAbove =
        style.descriptionPlacement == DescriptionPlacement.above
            ? _buildDescription(style, theme)
            : null;
    final descBelow =
        style.descriptionPlacement == DescriptionPlacement.below
            ? _buildDescription(style, theme)
            : null;

    Widget? errorAbove;
    Widget? errorBelow;
    if (style.errorPlacement == ErrorPlacement.above ||
        style.errorPlacement == ErrorPlacement.both) {
      errorAbove = _buildError(style, theme);
    }
    if (style.errorPlacement == ErrorPlacement.below ||
        style.errorPlacement == ErrorPlacement.both) {
      errorBelow = _buildError(style, theme);
    }

    final isLabelAbove =
        label != null && style.labelPlacement == LabelPlacement.above;
    final isLabelBelow =
        label != null && style.labelPlacement == LabelPlacement.below;

    // Inline label: label and input in same row (no above/below label rows).
    if (style.labelPlacement == LabelPlacement.inline) {
      if (descAbove != null) children.add(descAbove);
      if (errorAbove != null) {
        children.add(errorAbove);
        children.add(SizedBox(height: style.errorFieldGap));
      }
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (label != null) ...[label, SizedBox(width: style.labelFieldGap * 2)],
            Expanded(child: _buildInputRow(style, innerWidget)),
          ],
        ),
      );
    } else {
      // Label row above field (only when labelPlacement == above).
      if (isLabelAbove) {
        children.add(label);
        children.add(SizedBox(height: style.labelFieldGap));
      }

      // Description-above sits between the label and the input when the
      // label is rendered above. Otherwise it's the first row.
      if (descAbove != null) children.add(descAbove);

      if (errorAbove != null) {
        children.add(errorAbove);
        children.add(SizedBox(height: style.errorFieldGap));
      }

      // Input row with action icons.
      children.add(_buildInputRow(style, innerWidget));

      // Label row below field — between the input and the below-description.
      if (isLabelBelow) {
        children.add(SizedBox(height: style.labelFieldGap));
        children.add(label);
      }
    }

    if (errorBelow != null) {
      children.add(SizedBox(height: style.errorFieldGap));
      children.add(errorBelow);
    }

    if (descBelow != null) children.add(descBelow);

    // Read-only background
    Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );

    if (effectiveAuthState == TomAuthState.read &&
        style.readOnlyBackground != null) {
      column = ColoredBox(color: style.readOnlyBackground!, child: column);
    }

    return column;
  }

  Widget? _buildLabelRow(TomFormStyleLegacy style, ThemeData theme) {
    // Hidden renders nothing. Floating is handled inside the field's own
    // InputDecoration, so no separate row is emitted here either.
    if (style.labelPlacement == LabelPlacement.hidden ||
        style.labelPlacement == LabelPlacement.floating) {
      return null;
    }

    final resolvedLabel = labelText;
    if (resolvedLabel == null || resolvedLabel.isEmpty) return null;

    final labelTextWidget = Text(
      resolvedLabel,
      style: style.labelStyle ?? theme.textTheme.bodyMedium,
      overflow: TextOverflow.ellipsis,
    );

    // Required indicator
    final indicator = _buildRequiredIndicator(style, theme);

    if (indicator == null) return labelTextWidget;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Flexible(child: labelTextWidget), indicator],
    );
  }

  /// Text suffix for the required indicator, suitable for appending to
   /// plain-text slots such as `InputDecoration.labelText` or `hintText`
   /// where a styled widget cannot be used.
  ///
  /// Returns an empty string when no indicator should be shown (field is
  /// not required, is not editable, or [kind] is [RequiredIndicator.none]
  /// / [RequiredIndicator.custom]).
  String requiredIndicatorSuffix(RequiredIndicator kind) {
    if (!hasRequiredValidator || !isEditable) return '';
    return switch (kind) {
      RequiredIndicator.asterisk => ' *',
      RequiredIndicator.text => ' (required)',
      RequiredIndicator.none => '',
      RequiredIndicator.custom => '',
    };
  }

  Widget? _buildRequiredIndicator(TomFormStyleLegacy style, ThemeData theme) {
    if (!hasRequiredValidator) return null;
    if (!isEditable) return null;

    return switch (style.requiredIndicator) {
      RequiredIndicator.asterisk => Text(
          ' *',
          style:
              (style.errorStyle ?? theme.textTheme.bodySmall)?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      RequiredIndicator.text => Text(
          ' (required)',
          style: style.descriptionStyle ?? theme.textTheme.bodySmall,
        ),
      RequiredIndicator.none => null,
      RequiredIndicator.custom => null,
    };
  }

  Widget _buildInputRow(TomFormStyleLegacy style, Widget innerWidget) {
    // Keep the Row structure stable across pending-state transitions so the
    // inner field's Element (and its FocusNode attachment) is preserved.
    // Swapping between `innerWidget` and `Row(Expanded, spinner)` would
    // reparent the field and drop focus mid-typing while a slow async
    // validator is running.
    final Widget trailing = isSlowValidationPending
        ? const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : const SizedBox.shrink();

    if (style.actionIconPlacement == ActionIconPlacement.leading) {
      return Row(
        children: [trailing, Expanded(child: innerWidget)],
      );
    }
    return Row(
      children: [Expanded(child: innerWidget), trailing],
    );
  }

  /// Resolves the current validation-error message through the resource
  /// system, or returns null if the field is not in error state.
  ///
  /// Resolution chain (most specific wins):
  ///   1. Field-scoped:  `basePath.errorKey`  (e.g. companyBasicInfo.name.error.required)
  ///   2. Form-scoped:   `scope.errorKey`     (e.g. companyBasicInfo.error.required)
  ///   3. Global:        `errorKey`           (e.g. error.required)
  /// Falls through to the raw errorKey as a development indicator.
  String? resolveValidationErrorMessage() {
    final state = validationState;
    if (state is! ValidationError) return null;
    return TomCtr.textOrNull(basePath, state.errorKey) ??
        TomCtr.textOrNull(scope, state.errorKey) ??
        TomCtr.textOrNull(state.errorKey) ??
        state.errorKey;
  }

  Widget? _buildError(TomFormStyleLegacy style, ThemeData theme) {
    final message = resolveValidationErrorMessage();
    if (message == null) return null;

    return Text(
      message,
      style: (style.errorStyle ?? theme.textTheme.bodySmall)?.copyWith(
        color: theme.colorScheme.error,
      ),
    );
  }

  Widget _buildDescription(TomFormStyleLegacy style, ThemeData theme) {
    final desc = descriptionText;
    final textStyle = style.descriptionStyle ?? theme.textTheme.bodySmall;

    return Padding(
      padding: EdgeInsets.only(top: style.errorFieldGap),
      child: Text(
        (desc != null && desc.isNotEmpty) ? desc : ' ',
        style: (desc != null && desc.isNotEmpty)
            ? textStyle
            : textStyle?.copyWith(color: Colors.transparent),
      ),
    );
  }
}
