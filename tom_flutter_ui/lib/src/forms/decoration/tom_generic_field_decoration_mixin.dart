import 'package:flutter/material.dart';

import '../style/form_style_enums.dart';
import '../style/tom_form_style.dart';
import '../style/tom_form_style_scope.dart';
import '../tom_form.dart';
import 'tom_field_anatomy.dart';

/// Decoration mixin for non-text-input fields (checkboxes, switches,
/// segmented buttons, chips, radio groups, etc.).
///
/// Parallel to [TomStringInputDecorationMixin] but drops the Material
/// `InputDecoration` plumbing — those fields don't have an inner
/// `TextField` whose error border needs reshaping, they just need the
/// label / error / description / action-icon anatomy wrapped around
/// their rendered control.
///
/// Each concrete implementation overrides [resolveStyle] to pick the
/// right `Tom*Style` slot off `TomFormStyle` (e.g.
/// `form.checkboxStyle`, `form.chipsStyle`).
mixin TomGenericFieldDecorationMixin<T> on TomField<T> {
  /// Label text — resolved from resources or set explicitly.
  String? get labelText => null;

  /// Description/helper text — resolved from resources or set explicitly.
  String? get descriptionText => null;

  /// Whether this field has a required validator.
  bool get hasRequiredValidator => fieldHasRequiredValidator(validators);

  /// Resolves the per-width [TomFieldStyle] for this widget type.
  /// Override to pick a specific style slot (e.g. `form.checkboxStyle`).
  TomFieldStyle resolveStyle(BuildContext context);

  /// Text suffix for the required indicator, suitable for appending to
  /// plain-text slots. Same semantics as the string-input mixin.
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

  /// Wraps [innerWidget] with the standard field anatomy. Threads the
  /// field's optional `actionIcon` + tap handler through so the same
  /// icon rules (placement, auth-aware disabling, spinner priority
  /// during async validation) apply to every field type.
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

  /// Reads the captured scope width for [context] — call it when a
  /// concrete widget wants to pick per-breakpoint visuals without
  /// duplicating `TomFormStyleScope.widthOf(context)`.
  double scopeWidth(BuildContext context) => TomFormStyleScope.widthOf(context);

  /// Returns the form-style resolved for the ambient width — concretes
  /// call this when they need the full style (e.g. to read an adjacent
  /// slot like `chipsStyle.selectedColor` alongside the base field
  /// style).
  TomFormStyle resolveFullStyle(BuildContext context) =>
      TomFormStyleScope.of(context);
}
