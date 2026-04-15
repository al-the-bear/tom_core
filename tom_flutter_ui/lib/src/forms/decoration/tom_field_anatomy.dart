library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../style/form_style_enums.dart';
import '../style/tom_form_style.dart';
import '../validation/validation_result.dart';
import '../validation/validators.dart';

/// True when [validators] contains the canonical Required validator.
bool fieldHasRequiredValidator(List<Object> validators) {
  for (final v in validators) {
    if (v == Validators.requiredInstance) return true;
  }
  return false;
}

/// Resolves a validation-error message through the TomCtr resource chain.
///
/// Chain (most specific wins):
///   1. Field-scoped:  `basePath.errorKey`
///   2. Form-scoped:   `scope.errorKey`
///   3. Global:        `errorKey`
/// Falls through to the raw errorKey as a development indicator.
String? resolveFieldValidationMessage({
  required ValidationResult validationState,
  required String basePath,
  required String scope,
}) {
  if (validationState is! ValidationError) return null;
  final key = validationState.errorKey;
  return TomCtr.textOrNull(basePath, key) ??
      TomCtr.textOrNull(scope, key) ??
      TomCtr.textOrNull(key) ??
      key;
}

/// Text suffix for the required indicator in plain-text slots such as
/// `InputDecoration.labelText` or `hintText`.
String requiredIndicatorSuffixFor(
  RequiredIndicator kind, {
  required bool hasRequired,
  required bool isEditable,
}) {
  if (!hasRequired || !isEditable) return '';
  return switch (kind) {
    RequiredIndicator.asterisk => ' *',
    RequiredIndicator.text => ' (required)',
    RequiredIndicator.none => '',
    RequiredIndicator.custom => '',
  };
}

/// Applies error visuals (error border switch + trailing error icon) to an
/// [InputDecoration] based on the resolved [style].
///
/// Called from per-widget build methods before the decoration is attached to
/// the underlying Flutter widget. The two toggles are independent of
/// [ErrorPlacement]:
///   * [TomFieldStyle.errorBorderEnabled] — when in error and enabled,
///     replaces the enabled border with [TomFieldStyle.errorBorder] (fallback
///     to the default `errorBorder` behaviour of Material).
///   * [TomFieldStyle.errorIconEnabled] — when in error and enabled, appends
///     a red circle-exclamation icon to the trailing slot; if a suffix icon
///     already exists, the error icon appears immediately to its right.
///
/// When the field is not in error, the decoration is returned unchanged.
InputDecoration applyErrorVisuals({
  required InputDecoration decoration,
  required TomFieldStyle style,
  required bool hasError,
}) {
  if (!hasError) return decoration;

  InputDecoration updated = decoration;

  if (style.errorBorderEnabled && style.errorBorder != null) {
    updated = updated.copyWith(
      enabledBorder: style.errorBorder,
      focusedBorder: style.errorBorder,
      border: style.errorBorder,
      disabledBorder: style.errorBorder,
    );
  }

  if (style.errorIconEnabled) {
    const errorIconWidget = Icon(
      Icons.error,
      color: Color(0xFFD32F2F),
      size: 20,
      semanticLabel: 'error',
    );
    final existingSuffix = updated.suffixIcon;
    final suffix = existingSuffix == null
        ? errorIconWidget
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              existingSuffix,
              const SizedBox(width: 4),
              errorIconWidget,
            ],
          );
    updated = updated.copyWith(suffixIcon: suffix);
  }

  return updated;
}

/// Builds the field's anatomy column around [innerWidget] using the
/// fully-resolved [style] for the current width.
///
/// Shared by every per-widget decoration mixin. Returns `SizedBox.shrink()`
/// for `TomAuthState.none`. Applies `disabledOpacity` wrapping for
/// `TomAuthState.disabled`. Paints `readOnlyBackground` in the read state.
Widget buildFieldAnatomy({
  required BuildContext context,
  required TomFieldStyle style,
  required Widget innerWidget,
  required TomAuthState effectiveAuth,
  required String? labelText,
  required String? descriptionText,
  required String? errorMessage,
  required bool hasRequired,
  required bool isEditable,
  required bool isSlowPending,
}) {
  if (effectiveAuth == TomAuthState.none) {
    return const SizedBox.shrink();
  }
  final theme = Theme.of(context);
  Widget content = _anatomyColumn(
    style: style,
    theme: theme,
    innerWidget: innerWidget,
    effectiveAuth: effectiveAuth,
    labelText: labelText,
    descriptionText: descriptionText,
    errorMessage: errorMessage,
    hasRequired: hasRequired,
    isEditable: isEditable,
    isSlowPending: isSlowPending,
  );
  if (effectiveAuth == TomAuthState.disabled) {
    content = Opacity(opacity: style.disabledOpacity, child: content);
  }
  return content;
}

Widget _anatomyColumn({
  required TomFieldStyle style,
  required ThemeData theme,
  required Widget innerWidget,
  required TomAuthState effectiveAuth,
  required String? labelText,
  required String? descriptionText,
  required String? errorMessage,
  required bool hasRequired,
  required bool isEditable,
  required bool isSlowPending,
}) {
  final children = <Widget>[];

  final label = _labelRow(style, theme, labelText, hasRequired, isEditable);
  final descAbove = style.descriptionPlacement == DescriptionPlacement.above
      ? _description(style, theme, descriptionText)
      : null;
  final descBelow = style.descriptionPlacement == DescriptionPlacement.below
      ? _description(style, theme, descriptionText)
      : null;

  Widget? errorAbove;
  Widget? errorBelow;
  if (style.errorPlacement == ErrorPlacement.above ||
      style.errorPlacement == ErrorPlacement.both) {
    errorAbove = _error(style, theme, errorMessage);
  }
  if (style.errorPlacement == ErrorPlacement.below ||
      style.errorPlacement == ErrorPlacement.both) {
    errorBelow = _error(style, theme, errorMessage);
  }

  final isLabelAbove =
      label != null && style.labelPlacement == LabelPlacement.above;
  final isLabelBelow =
      label != null && style.labelPlacement == LabelPlacement.below;

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
          if (label != null) ...[
            label,
            SizedBox(width: style.labelFieldGap * 2),
          ],
          Expanded(child: _inputRow(style, innerWidget, isSlowPending)),
        ],
      ),
    );
  } else {
    if (isLabelAbove) {
      children.add(label);
      children.add(SizedBox(height: style.labelFieldGap));
    }
    if (descAbove != null) children.add(descAbove);
    if (errorAbove != null) {
      children.add(errorAbove);
      children.add(SizedBox(height: style.errorFieldGap));
    }
    children.add(_inputRow(style, innerWidget, isSlowPending));
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

  Widget column = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: children,
  );

  if (effectiveAuth == TomAuthState.read &&
      style.readOnlyBackground != null) {
    final color = style.readOnlyBackground!.resolve(const <WidgetState>{});
    column = ColoredBox(color: color, child: column);
  }
  return column;
}

Widget? _labelRow(
  TomFieldStyle style,
  ThemeData theme,
  String? labelText,
  bool hasRequired,
  bool isEditable,
) {
  if (style.labelPlacement == LabelPlacement.hidden ||
      style.labelPlacement == LabelPlacement.floating) {
    return null;
  }
  if (labelText == null || labelText.isEmpty) return null;

  final labelWidget = Text(
    labelText,
    style: style.labelStyle ?? theme.textTheme.bodyMedium,
    overflow: TextOverflow.ellipsis,
  );

  final indicator = _requiredIndicatorWidget(
    style,
    theme,
    hasRequired,
    isEditable,
  );
  if (indicator == null) return labelWidget;

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [Flexible(child: labelWidget), indicator],
  );
}

Widget? _requiredIndicatorWidget(
  TomFieldStyle style,
  ThemeData theme,
  bool hasRequired,
  bool isEditable,
) {
  if (!hasRequired || !isEditable) return null;
  return switch (style.requiredIndicator) {
    RequiredIndicator.asterisk => Text(
        ' *',
        style: (style.errorStyle ?? theme.textTheme.bodySmall)?.copyWith(
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

Widget _inputRow(
  TomFieldStyle style,
  Widget innerWidget,
  bool isSlowPending,
) {
  // Keep the Row structure stable across pending-state transitions so the
  // inner field's Element (and its FocusNode attachment) is preserved.
  final Widget trailing = isSlowPending
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
    return Row(children: [trailing, Expanded(child: innerWidget)]);
  }
  return Row(children: [Expanded(child: innerWidget), trailing]);
}

Widget? _error(TomFieldStyle style, ThemeData theme, String? message) {
  if (message == null) return null;
  return Text(
    message,
    style: (style.errorStyle ?? theme.textTheme.bodySmall)?.copyWith(
      color: theme.colorScheme.error,
    ),
  );
}

Widget _description(
  TomFieldStyle style,
  ThemeData theme,
  String? descriptionText,
) {
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
