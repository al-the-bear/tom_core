import 'package:flutter/material.dart';

import '../style/form_style_enums.dart';
import '../style/tom_form_style.dart';
import '../style/tom_form_style_scope.dart';
import '../tom_form.dart';
import 'tom_field_anatomy.dart';

/// Decoration mixin for dropdown selection fields.
///
/// Same anatomy pipeline as [TomStringInputDecorationMixin] but resolves
/// against [TomFormStyle.dropdownStyle].
mixin TomDropdownDecorationMixin<T> on TomField<T> {
  /// Label text — resolved from resources or set explicitly.
  String? get labelText => null;

  /// Description/helper text — resolved from resources or set explicitly.
  String? get descriptionText => null;

  /// Whether this field has a required validator.
  bool get hasRequiredValidator => fieldHasRequiredValidator(validators);

  /// Resolves the per-width [TomFieldStyle] for this widget type.
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.dropdownStyle, width);
  }

  /// Resolves the underlying [TomDropdownStyle] override (may be null).
  TomDropdownStyle? resolveOver(BuildContext context) {
    return TomFormStyleScope.of(context).dropdownStyle;
  }

  /// Text suffix for the required indicator.
  String requiredIndicatorSuffix(RequiredIndicator kind) {
    return requiredIndicatorSuffixFor(
      kind,
      hasRequired: hasRequiredValidator,
      isEditable: isEditable,
      basePath: basePath,
    );
  }

  /// Resolves the current validation-error message, or `null`.
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

  /// A dropdown *field* always fills the width its column gives it — the
  /// value to pass as [DropdownButton.isExpanded].
  ///
  /// Flutter defaults that flag to `false`, sizing the button to its content.
  /// That is right for a general-purpose dropdown a caller places wherever it
  /// likes — which is what `TomDropdownButton` in `widgets/selects` is, and
  /// why it keeps the Flutter default and exposes the knob. It is wrong for a
  /// form field. A field never chooses its own width: the form lays it into a
  /// column sized by a breakpoint, a two-column section or a drawer, while its
  /// items arrive from data — a country list, a set of display names, rows
  /// loaded from the server. "The widest label is wider than the column" is
  /// therefore an ordinary runtime state and not a mis-configuration, and a
  /// button that sizes to content answers it with a `RenderFlex overflowed by
  /// N pixels` — a red-striped band in release, a thrown `FlutterError` under
  /// test.
  bool get dropdownFillsColumnWidth => true;

  /// Renders a menu-item label so that it elides rather than reflows.
  ///
  /// The closed button draws its selected item into a row of fixed height, so
  /// a label that wrapped to a second line would trade a horizontal overflow
  /// for a vertical one. One line plus an ellipsis is the only degradation
  /// that stays inside both axes, and it is also the one a user can read: the
  /// beginning of a label distinguishes the options, the end rarely does.
  Widget dropdownItemLabel(String label, TextStyle? style) {
    return Text(
      label,
      style: style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Wraps [innerWidget] with the standard field anatomy. Mirrors
  /// [TomStringInputDecorationMixin] so dropdowns also honour the
  /// `actionIcon` + `onActionIconPressed` fields from `TomField`.
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
