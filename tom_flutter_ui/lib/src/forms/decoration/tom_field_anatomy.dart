library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../style/form_style_enums.dart';
import '../style/tom_form_style.dart';
import '../validation/form_validation_error.dart';
import '../validation/validation_result.dart';
import '../validation/validators.dart';
import '../tom_form_labels.dart';

/// Composes [CupertinoTextField.prefix] with [TomFieldStyle.leadingWidget].
///
/// Cupertino inputs don't go through [InputDecoration]; they take a `prefix`
/// / `suffix` Widget pair directly. To keep the same "field-supplied prefix
/// inside, style leading widget outside" ordering as the Material side, this
/// helper is used at every Cupertino input build site instead of the
/// applyErrorVisuals path.
///
/// Returns:
///   * `null` when both [fieldPrefix] and `style.leadingWidget` are null.
///   * Just one of them when only one is set.
///   * A `Row(min)` of `[styleLeading][gap][fieldPrefix]` when both exist.
Widget? composeCupertinoLeading(Widget? fieldPrefix, TomFieldStyle style) {
  final styleLeading = style.leadingWidget;
  if (styleLeading == null) return fieldPrefix;
  if (fieldPrefix == null) return styleLeading;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      styleLeading,
      SizedBox(width: style.leadingGap),
      fieldPrefix,
    ],
  );
}

/// Mirror of [composeCupertinoLeading] for the trailing slot.
///
/// Order is `[fieldSuffix][gap][styleTrailing]` — the field-supplied suffix
/// is the *innermost* trailing widget, matching the Material composition.
Widget? composeCupertinoTrailing(Widget? fieldSuffix, TomFieldStyle style) {
  final styleTrailing = style.trailingWidget;
  if (styleTrailing == null) return fieldSuffix;
  if (fieldSuffix == null) return styleTrailing;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      fieldSuffix,
      SizedBox(width: style.trailingGap),
      styleTrailing,
    ],
  );
}

/// Composes the effective hint [TextStyle] by layering
/// [TomFieldStyle.hintFontWeight] and [TomFieldStyle.hintOpacity] on top of
/// [TomFieldStyle.hintStyle]. Returns `null` when the style has no hint
/// configuration at all (lets Flutter's TextField fall through to its own
/// defaults).
TextStyle? composeHintStyle(TomFieldStyle style, ThemeData theme) {
  final base = style.hintStyle ?? theme.textTheme.bodyMedium;
  if (base == null &&
      style.hintFontWeight == null &&
      style.hintOpacity == null) {
    return null;
  }
  var effective = base ?? const TextStyle();
  if (style.hintFontWeight != null) {
    effective = effective.copyWith(fontWeight: style.hintFontWeight);
  }
  if (style.hintOpacity != null) {
    final color = effective.color ?? theme.colorScheme.onSurface;
    final alpha = style.hintOpacity!.clamp(0.0, 1.0);
    effective = effective.copyWith(color: color.withValues(alpha: alpha));
  }
  return effective;
}

/// Returns [border] with its [BorderRadius] replaced by [radius], when the
/// border is one of Flutter's built-in rounded input-border types. For any
/// other border (or null) the input is returned unchanged.
///
/// Used by every spec-aligned field widget to make [TomFieldStyle.borderRadius]
/// actually take effect: presets carry their own preconstructed borders (so
/// setting `borderRadius` in isolation wouldn't otherwise do anything), and
/// this helper reshapes them without rebuilding the whole preset.
InputBorder? applyBorderRadius(InputBorder? border, double radius) {
  final rect = BorderRadius.circular(radius);
  if (border is OutlineInputBorder) {
    return border.copyWith(borderRadius: rect);
  }
  if (border is UnderlineInputBorder) {
    return border.copyWith(borderRadius: rect);
  }
  return border;
}

/// Returns [border] with its stroke width replaced by [width]. Null [width]
/// is a pass-through so callers can cheaply forward
/// [TomFieldStyle.borderWidth] / [TomFieldStyle.focusedBorderWidth] without
/// branching. Unrecognised or null borders are returned unchanged.
InputBorder? applyBorderWidth(InputBorder? border, double? width) {
  if (border == null || width == null) return border;
  if (border is OutlineInputBorder) {
    return border.copyWith(
      borderSide: border.borderSide.copyWith(width: width),
    );
  }
  if (border is UnderlineInputBorder) {
    return border.copyWith(
      borderSide: border.borderSide.copyWith(width: width),
    );
  }
  return border;
}

/// True when [validators] contains the canonical Required validator.
bool fieldHasRequiredValidator(List<Object> validators) {
  for (final v in validators) {
    if (v == TomValidators.requiredInstance) return true;
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
///
/// Whatever level resolves, the error's `params` are interpolated into it (see
/// [TomValidationError.interpolate]), so a template such as
/// `Use at least {min} characters.` reaches the screen with the bound value
/// substituted rather than the placeholder showing through.
String? resolveFieldValidationMessage({
  required TomValidationResult validationState,
  required String basePath,
  required String scope,
}) {
  if (validationState is! TomValidationError) return null;
  final key = validationState.errorKey;
  final template =
      TomCtr.textOrNull(basePath, key) ??
      TomCtr.textOrNull(scope, key) ??
      TomCtr.textOrNull(key) ??
      key;
  return validationState.interpolate(template);
}

/// Resolves a form-level [TomFormValidationError] to the text a user reads.
///
/// An error naming exactly one field is looked up first under that field's
/// `basePath`, so a form can word it per field; every error is then looked up
/// globally by its key, and the key itself is the fallback. [TomFormValidationError.errorKey]
/// is used **unprefixed** — stock keys already carry their `error.` prefix — and
/// the global lookup passes the key as the path with no suffix, because
/// `TomCtr.textOrNull('', key)` would build `'.<key>'`, which never resolves.
///
/// Whatever resolves, the error's `params` replace their `{name}` placeholders.
/// Every widget that shows form-level errors reads them through this, so the
/// same error says the same thing wherever it is displayed.
String resolveFormValidationMessage(TomFormValidationError error) {
  final key = error.errorKey;
  final template =
      (error.fields.length == 1
          ? TomCtr.textOrNull(error.fields.first.basePath, key)
          : null) ??
      TomCtr.textOrNull(key) ??
      key;
  final params = error.params;
  if (params == null || params.isEmpty) return template;
  var out = template;
  params.forEach((name, value) => out = out.replaceAll('{$name}', '$value'));
  return out;
}

/// Text suffix for the required indicator in plain-text slots such as
/// `InputDecoration.labelText` or `hintText`.
String requiredIndicatorSuffixFor(
  TomRequiredIndicator kind, {
  required bool hasRequired,
  required bool isEditable,
  String? basePath,
}) {
  if (!hasRequired || !isEditable) return '';
  return switch (kind) {
    TomRequiredIndicator.asterisk => ' *',
    TomRequiredIndicator.text => TomFormLabels.requiredSuffix(basePath),
    TomRequiredIndicator.none => '',
    TomRequiredIndicator.custom => '',
  };
}

/// Applies style-driven decoration add-ons to an [InputDecoration] — the
/// fixed leading / trailing slots and (if the field is in error) the error
/// border switch + trailing error icon.
///
/// Called from per-widget build methods before the decoration is attached to
/// the underlying Flutter widget. Behaviour:
///   * [TomFieldStyle.leadingWidget] — always applied (independent of error
///     state). Wrapped with right-padding [TomFieldStyle.leadingGap] and
///     composed into [InputDecoration.prefixIcon]. Any field-supplied
///     `prefixIcon` survives — the leading widget sits to its left so the
///     style addition acts as an outermost decoration.
///   * [TomFieldStyle.trailingWidget] — always applied. Wrapped with
///     left-padding [TomFieldStyle.trailingGap] and composed into
///     [InputDecoration.suffixIcon] *before* the error icon, so the error
///     icon stays rightmost.
///   * [TomFieldStyle.errorBorderEnabled] — when in error and enabled,
///     replaces the enabled border with [TomFieldStyle.errorBorder] (fallback
///     to the default `errorBorder` behaviour of Material).
///   * [TomFieldStyle.errorIconEnabled] — when in error and enabled, appends
///     a red circle-exclamation icon to the trailing slot; if a suffix icon
///     already exists, the error icon appears immediately to its right.
///
/// The function name retains "ErrorVisuals" for call-site stability — the
/// extra leading/trailing branch is a strict superset of the previous
/// behaviour so existing call sites pick it up automatically.
InputDecoration applyErrorVisuals({
  required InputDecoration decoration,
  required TomFieldStyle style,
  required bool hasError,
}) {
  InputDecoration updated = decoration;

  // 1) Style-driven leading widget — composes with any field-supplied
  // prefixIcon. Order: [leadingWidget][gap][existing prefixIcon][editable].
  if (style.leadingWidget != null) {
    final leading = Padding(
      padding: EdgeInsets.only(right: style.leadingGap),
      child: style.leadingWidget,
    );
    final existing = updated.prefixIcon;
    final composed = existing == null
        ? leading
        : Row(mainAxisSize: MainAxisSize.min, children: [leading, existing]);
    updated = updated.copyWith(prefixIcon: composed);
  }

  // 2) Style-driven trailing widget — composes with any field-supplied
  // suffixIcon. Order: [editable][existing suffixIcon][gap][trailingWidget].
  // The error icon (added in step 4 below) lands to the right of this so
  // ordering ends up [editable][suffixIcon][trailingWidget][errorIcon].
  if (style.trailingWidget != null) {
    final trailing = Padding(
      padding: EdgeInsets.only(left: style.trailingGap),
      child: style.trailingWidget,
    );
    final existing = updated.suffixIcon;
    final composed = existing == null
        ? trailing
        : Row(mainAxisSize: MainAxisSize.min, children: [existing, trailing]);
    updated = updated.copyWith(suffixIcon: composed);
  }

  if (!hasError) return updated;

  if (style.errorBorderEnabled && style.errorBorder != null) {
    // Reshape to style.borderRadius / style.borderWidth so the error-state
    // border matches the rest of the field's rounded corners and stroke.
    final errorBorder = applyBorderWidth(
      applyBorderRadius(style.errorBorder, style.borderRadius),
      style.borderWidth,
    );
    updated = updated.copyWith(
      enabledBorder: errorBorder,
      focusedBorder: errorBorder,
      border: errorBorder,
      disabledBorder: errorBorder,
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
  Widget? actionIcon,
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
    actionIcon: actionIcon,
  );
  if (effectiveAuth == TomAuthState.disabled) {
    content = Opacity(opacity: style.disabledOpacity, child: content);
  } else if (effectiveAuth == TomAuthState.read) {
    // Light dim for readonly — keeps content readable but visibly distinct
    // from editable fields. Sits outside the optional readOnlyBackground
    // ColoredBox, so a configured background is dimmed uniformly with the
    // rest of the field.
    content = Opacity(opacity: style.readOnlyOpacity, child: content);
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
  required Widget? actionIcon,
}) {
  final children = <Widget>[];

  // Header-block mode: when label is above AND description is above, render
  // both with a tighter line-height. Material's default bodyMedium height
  // (~1.43) adds ~6-7px of invisible font leading between the two text
  // rows; that dwarfs any SizedBox we can reasonably use between them. We
  // override to 1.15 to reclaim most of that leading while still leaving a
  // little room for ascenders/descenders.
  final bool tightHeader =
      style.labelPlacement == TomLabelPlacement.above &&
      style.descriptionPlacement == TomDescriptionPlacement.above;
  const double headerBlockHeight = 1.15;
  final double? headerHeightOverride = tightHeader ? headerBlockHeight : null;

  final label = _labelRow(
    style,
    theme,
    labelText,
    hasRequired,
    isEditable,
    lineHeightOverride: headerHeightOverride,
  );

  // The description slot is always rendered (transparent when there is no
  // description text) so every field has the same total height regardless of
  // whether it carries a description. This keeps row gaps uniform when some
  // fields in a row have descriptions and others don't.
  // When replaceDescription is active and the field is in error, the error
  // message replaces the description slot's text (rendered in error color).
  final replacingDesc =
      style.errorPlacement == TomErrorPlacement.replaceDescription &&
      errorMessage != null;
  final descAbove = style.descriptionPlacement == TomDescriptionPlacement.above
      ? _description(
          style,
          theme,
          descriptionText,
          hasRequired: hasRequired,
          isEditable: isEditable,
          errorOverride: replacingDesc ? errorMessage : null,
          lineHeightOverride: headerHeightOverride,
        )
      : null;
  final descBelow = style.descriptionPlacement == TomDescriptionPlacement.below
      ? _description(
          style,
          theme,
          descriptionText,
          hasRequired: hasRequired,
          isEditable: isEditable,
          errorOverride: replacingDesc ? errorMessage : null,
        )
      : null;

  Widget? errorAbove;
  Widget? errorBelow;
  if (style.errorPlacement == TomErrorPlacement.above ||
      style.errorPlacement == TomErrorPlacement.both) {
    errorAbove = _error(style, theme, errorMessage);
  }
  if (style.errorPlacement == TomErrorPlacement.below ||
      style.errorPlacement == TomErrorPlacement.both) {
    errorBelow = _error(style, theme, errorMessage);
  }

  final isLabelAbove =
      label != null && style.labelPlacement == TomLabelPlacement.above;
  final isLabelBelow =
      label != null && style.labelPlacement == TomLabelPlacement.below;

  if (style.labelPlacement == TomLabelPlacement.inline) {
    if (descAbove != null) {
      children.add(descAbove);
      children.add(SizedBox(height: style.labelFieldGap));
    }
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
          Expanded(
            child: _inputRow(style, innerWidget, isSlowPending, actionIcon),
          ),
        ],
      ),
    );
  } else {
    if (isLabelAbove) {
      children.add(label);
      if (descAbove != null) {
        // No explicit gap here: the tight 1.15 line-height on both Texts
        // still leaves ~2px of visual breathing room between their glyphs,
        // which is the desired header-block feel.
        children.add(descAbove);
      }
      children.add(SizedBox(height: style.labelFieldGap));
    } else if (descAbove != null) {
      children.add(descAbove);
      children.add(SizedBox(height: style.labelFieldGap));
    }
    if (errorAbove != null) {
      children.add(errorAbove);
      children.add(SizedBox(height: style.errorFieldGap));
    }
    children.add(_inputRow(style, innerWidget, isSlowPending, actionIcon));
    if (isLabelBelow) {
      children.add(SizedBox(height: style.labelFieldGap));
      children.add(label);
    }
  }

  if (errorBelow != null) {
    children.add(SizedBox(height: style.errorFieldGap));
    children.add(errorBelow);
  }
  if (descBelow != null) {
    // Distinct from errorFieldGap — callers want the description to
    // breathe independently from error copy, especially when an error
    // sits between the input and the description (errorPlacement.below).
    children.add(SizedBox(height: style.descriptionFieldGap));
    children.add(descBelow);
  }

  Widget column = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: children,
  );

  if (effectiveAuth == TomAuthState.read && style.readOnlyBackground != null) {
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
  bool isEditable, {
  double? lineHeightOverride,
}) {
  if (style.labelPlacement == TomLabelPlacement.hidden ||
      style.labelPlacement == TomLabelPlacement.floating) {
    return null;
  }
  if (labelText == null || labelText.isEmpty) return null;

  final baseTextStyle = style.labelStyle ?? theme.textTheme.bodyMedium;
  final effectiveStyle = lineHeightOverride != null
      ? (baseTextStyle ?? const TextStyle()).copyWith(
          height: lineHeightOverride,
        )
      : baseTextStyle;
  final labelWidget = Text(
    labelText,
    style: effectiveStyle,
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
    children: [
      Flexible(child: labelWidget),
      indicator,
    ],
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
    TomRequiredIndicator.asterisk => Text(
      ' *',
      style: (style.errorStyle ?? theme.textTheme.bodySmall)?.copyWith(
        color: theme.colorScheme.error,
      ),
    ),
    // Resolved globally rather than per field: the anatomy builder is style-
    // driven and carries no basePath, and the required marker is a form-wide
    // convention an application words once anyway.
    TomRequiredIndicator.text => Text(
      TomFormLabels.requiredSuffix(null),
      style: style.descriptionStyle ?? theme.textTheme.bodySmall,
    ),
    TomRequiredIndicator.none => null,
    TomRequiredIndicator.custom => null,
  };
}

Widget _inputRow(
  TomFieldStyle style,
  Widget innerWidget,
  bool isSlowPending,
  Widget? actionIcon,
) {
  // Keep the Row structure stable across pending-state transitions so the
  // inner field's Element (and its FocusNode attachment) is preserved.
  // The pending-indicator (slow validation) and the caller-supplied
  // action icon share the trailing / leading slot — pending visibly
  // replaces the action icon while async validation is in flight, so the
  // user sees progress instead of a redundant trigger.
  const Widget pendingIndicator = Padding(
    padding: EdgeInsets.only(left: 8.0),
    child: SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );

  final Widget trailing = isSlowPending
      ? pendingIndicator
      : (actionIcon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: actionIcon,
              )
            : const SizedBox.shrink());

  if (style.actionIconPlacement == TomActionIconPlacement.leading) {
    return Row(
      children: [
        trailing,
        Expanded(child: innerWidget),
      ],
    );
  }
  return Row(
    children: [
      Expanded(child: innerWidget),
      trailing,
    ],
  );
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
  String? descriptionText, {
  required bool hasRequired,
  required bool isEditable,
  String? errorOverride,
  double? lineHeightOverride,
}) {
  // The description slot is clipped to a single line (ellipsis on overflow)
  // so every field reserves the same vertical space regardless of
  // description length. Combined with always rendering the slot, this keeps
  // field widgets uniform in height — the ACL rows then space evenly.
  //
  // Gap management lives in the caller (_anatomyColumn) — this widget is a
  // bare Text so "description above" and "description below" can use
  // different spacing rules without this function having to know which.
  TextStyle? applyHeight(TextStyle? s) => lineHeightOverride != null
      ? (s ?? const TextStyle()).copyWith(height: lineHeightOverride)
      : s;

  if (errorOverride != null) {
    final errorStyle = (style.errorStyle ?? theme.textTheme.bodySmall)
        ?.copyWith(color: theme.colorScheme.error);
    return Text(
      errorOverride,
      style: applyHeight(errorStyle),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  var desc = descriptionText;
  if (desc != null && desc.isNotEmpty) {
    desc += requiredIndicatorSuffixFor(
      style.requiredIndicatorOnDescription,
      hasRequired: hasRequired,
      isEditable: isEditable,
    );
  }
  final textStyle = style.descriptionStyle ?? theme.textTheme.bodySmall;
  final effectiveStyle = applyHeight(
    (desc != null && desc.isNotEmpty)
        ? textStyle
        : textStyle?.copyWith(color: Colors.transparent),
  );
  return Text(
    (desc != null && desc.isNotEmpty) ? desc : ' ',
    style: effectiveStyle,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}
