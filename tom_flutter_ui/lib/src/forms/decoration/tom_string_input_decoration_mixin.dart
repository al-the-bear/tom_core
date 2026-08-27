import 'package:flutter/material.dart';

import '../style/form_style_enums.dart';
import '../style/tom_form_style.dart';
import '../style/tom_form_style_scope.dart';
import '../tom_form.dart';
import 'tom_field_anatomy.dart';

/// Decoration mixin for string-input fields.
///
/// Reads the per-width resolved [TomFieldStyle] from the ambient
/// [TomFormStyleScope] by merging [TomFormStyle.defaults] with
/// [TomFormStyle.stringInputStyle] (if any) via
/// [TomFormStyle.resolveFieldStyle], then wraps [innerWidget] in the
/// standard field anatomy (label, error, description, action icons).
mixin TomStringInputDecorationMixin<T> on TomField<T> {
  /// Label text — resolved from resources or set explicitly.
  String? get labelText => null;

  /// Description/helper text — resolved from resources or set explicitly.
  String? get descriptionText => null;

  /// Whether this field has a required validator.
  bool get hasRequiredValidator =>
      fieldHasRequiredValidator(validators);

  /// Resolves the per-width [TomFieldStyle] for this widget type.
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.stringInputStyle, width);
  }

  /// Resolves the underlying [TomStringInputStyle] override (may be null).
  TomStringInputStyle? resolveOver(BuildContext context) {
    return TomFormStyleScope.of(context).stringInputStyle;
  }

  /// Text suffix for the required indicator, suitable for appending to
  /// plain-text slots such as `InputDecoration.labelText` or `hintText`.
  String requiredIndicatorSuffix(RequiredIndicator kind) {
    return requiredIndicatorSuffixFor(
      kind,
      hasRequired: hasRequiredValidator,
      isEditable: isEditable,
      basePath: basePath,
    );
  }

  /// Resolves the current validation-error message through the resource
  /// system, or `null` when the field is not in error.
  String? resolveValidationErrorMessage() {
    return resolveFieldValidationMessage(
      validationState: validationState,
      basePath: basePath,
      scope: scope,
    );
  }

  /// Applies error visuals (error border + red icon) to a base
  /// [InputDecoration] when the field is in error, per the resolved style's
  /// `errorBorderEnabled` / `errorIconEnabled` toggles.
  InputDecoration applyErrorVisualsTo(
    BuildContext context,
    InputDecoration decoration,
  ) {
    return applyErrorVisuals(
      decoration: decoration,
      style: resolveStyle(context),
      hasError: resolveValidationErrorMessage() != null,
    );
  }

  /// Wraps [innerWidget] with the standard field anatomy. Also threads
  /// the field's optional `actionIcon` + tap handler through — the
  /// anatomy renders them in the `actionIconPlacement` slot and takes
  /// care of the IconButton/Tooltip wrapping when the caller only
  /// supplied a plain [Icon].
  Widget decorateField(BuildContext context, Widget innerWidget) {
    final style = resolveStyle(context);
    return buildFieldAnatomy(
      context: context,
      style: style,
      innerWidget: innerWidget,
      effectiveAuth: effectiveAuthState,
      labelText: labelText,
      descriptionText: descriptionText,
      errorMessage: resolveValidationErrorMessage(),
      hasRequired: hasRequiredValidator,
      isEditable: isEditable,
      isSlowPending: isSlowValidationPending,
      actionIcon: _buildActionIcon(),
    );
  }

  Widget? _buildActionIcon() {
    if (actionIcon == null) return null;
    if (onActionIconPressed == null && actionIconTooltip == null) {
      return actionIcon;
    }
    return IconButton(
      onPressed: isEditable ? onActionIconPressed : null,
      tooltip: actionIconTooltip,
      icon: actionIcon!,
      iconSize: 18,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(),
    );
  }
}
