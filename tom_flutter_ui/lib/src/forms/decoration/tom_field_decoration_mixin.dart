import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../style/form_style_enums.dart';
import '../style/tom_form_style.dart';
import '../style/tom_form_style_scope.dart';
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
/// Reads placement settings from [TomFormStyle] via [TomFormStyleScope].
mixin TomFieldDecorationMixin on TomField {
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
    final style = TomFormStyleScope.of(context);
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
    TomFormStyle style,
    ThemeData theme,
    Widget innerWidget,
  ) {
    final children = <Widget>[];

    // Description above field (if configured)
    if (style.descriptionPlacement == DescriptionPlacement.above) {
      final desc = _buildDescription(style, theme);
      if (desc != null) children.add(desc);
    }

    // Label row
    final label = _buildLabelRow(style, theme);
    if (label != null) {
      children.add(label);
      children.add(SizedBox(height: style.labelFieldGap));
    }

    // Error above field
    if (style.errorPlacement == ErrorPlacement.above ||
        style.errorPlacement == ErrorPlacement.both) {
      final error = _buildError(style, theme);
      if (error != null) {
        children.add(error);
        children.add(SizedBox(height: style.errorFieldGap));
      }
    }

    // Input row with action icons
    children.add(_buildInputRow(style, innerWidget));

    // Error below field
    if (style.errorPlacement == ErrorPlacement.below ||
        style.errorPlacement == ErrorPlacement.both) {
      final error = _buildError(style, theme);
      if (error != null) {
        children.add(SizedBox(height: style.errorFieldGap));
        children.add(error);
      }
    }

    // Description below field (default)
    if (style.descriptionPlacement == DescriptionPlacement.below) {
      final desc = _buildDescription(style, theme);
      if (desc != null) children.add(desc);
    }

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

  Widget? _buildLabelRow(TomFormStyle style, ThemeData theme) {
    if (style.labelPlacement == LabelPlacement.hidden ||
        style.labelPlacement == LabelPlacement.floating) {
      return null;
    }

    final resolvedLabel = labelText;
    if (resolvedLabel == null || resolvedLabel.isEmpty) return null;

    final labelTextWidget = Text(
      resolvedLabel,
      style: style.labelStyle ?? theme.textTheme.bodyMedium,
    );

    // Required indicator
    final indicator = _buildRequiredIndicator(style, theme);

    if (indicator == null) return labelTextWidget;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [labelTextWidget, indicator],
    );
  }

  Widget? _buildRequiredIndicator(TomFormStyle style, ThemeData theme) {
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

  Widget _buildInputRow(TomFormStyle style, Widget innerWidget) {
    // Pending validation spinner
    final spinner = _buildPendingSpinner();

    if (spinner == null) return innerWidget;

    if (style.actionIconPlacement == ActionIconPlacement.leading) {
      return Row(
        children: [spinner, Expanded(child: innerWidget)],
      );
    }
    // Default: trailing
    return Row(
      children: [Expanded(child: innerWidget), spinner],
    );
  }

  Widget? _buildPendingSpinner() {
    if (validationState is! ValidationPending) return null;
    return const Padding(
      padding: EdgeInsets.only(left: 8.0),
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget? _buildError(TomFormStyle style, ThemeData theme) {
    final state = validationState;
    if (state is! ValidationError) return null;

    return Text(
      state.errorKey,
      style: (style.errorStyle ?? theme.textTheme.bodySmall)?.copyWith(
        color: theme.colorScheme.error,
      ),
    );
  }

  Widget? _buildDescription(TomFormStyle style, ThemeData theme) {
    final desc = descriptionText;
    if (desc == null || desc.isEmpty) return null;

    return Padding(
      padding: EdgeInsets.only(top: style.errorFieldGap),
      child: Text(
        desc,
        style: style.descriptionStyle ?? theme.textTheme.bodySmall,
      ),
    );
  }
}
