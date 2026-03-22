import 'package:flutter/material.dart';

import '../../widget_base/tom_family_base.dart';

/// Tom wrapper for [FilterChip].
///
/// Adds ID, group, authorization, and resource resolution for label.
class TomFilterChip extends TomChipBase {
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? avatar;
  final Widget? label;
  final String? labelText;
  final TextStyle? labelStyle;
  final EdgeInsetsGeometry? labelPadding;
  final EdgeInsetsGeometry? padding;
  final bool showCheckmark;
  final Color? checkmarkColor;
  final Color? selectedColor;
  final Color? disabledColor;
  final Color? backgroundColor;
  final Color? selectedShadowColor;
  final Color? shadowColor;
  final OutlinedBorder? shape;
  final BorderSide? side;
  final Clip clipBehavior;
  final VisualDensity? visualDensity;
  final double? elevation;
  final double? pressElevation;
  final Widget? deleteIcon;
  final VoidCallback? onDeleted;
  final Color? deleteIconColor;
  final String? deleteButtonTooltipMessage;

  const TomFilterChip({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.selected,
    this.onSelected,
    this.avatar,
    this.label,
    this.labelText,
    this.labelStyle,
    this.labelPadding,
    this.padding,
    this.showCheckmark = true,
    this.checkmarkColor,
    this.selectedColor,
    this.disabledColor,
    this.backgroundColor,
    this.selectedShadowColor,
    this.shadowColor,
    this.shape,
    this.side,
    this.clipBehavior = Clip.none,
    this.visualDensity,
    this.elevation,
    this.pressElevation,
    this.deleteIcon,
    this.onDeleted,
    this.deleteIconColor,
    this.deleteButtonTooltipMessage,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = labelText ?? (tomId != null ? resolveResource(context, 'label') : null);
    final chipLabel = label ?? Text(resolvedLabel ?? '');

    return FilterChip(
      selected: selected,
      onSelected: onSelected,
      avatar: avatar,
      label: chipLabel,
      labelStyle: labelStyle,
      labelPadding: labelPadding,
      padding: padding,
      showCheckmark: showCheckmark,
      checkmarkColor: checkmarkColor,
      selectedColor: selectedColor,
      disabledColor: disabledColor,
      backgroundColor: backgroundColor,
      selectedShadowColor: selectedShadowColor,
      shadowColor: shadowColor,
      shape: shape,
      side: side,
      clipBehavior: clipBehavior,
      visualDensity: visualDensity,
      elevation: elevation,
      pressElevation: pressElevation,
      deleteIcon: deleteIcon,
      onDeleted: onDeleted,
      deleteIconColor: deleteIconColor,
      deleteButtonTooltipMessage: deleteButtonTooltipMessage,
    );
  }
}

/// Tom wrapper for [ChoiceChip].
///
/// Adds ID, group, authorization, and resource resolution for label.
class TomChoiceChip extends TomChipBase {
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? avatar;
  final Widget? label;
  final String? labelText;
  final TextStyle? labelStyle;
  final EdgeInsetsGeometry? labelPadding;
  final EdgeInsetsGeometry? padding;
  final Color? selectedColor;
  final Color? disabledColor;
  final Color? backgroundColor;
  final Color? selectedShadowColor;
  final Color? shadowColor;
  final OutlinedBorder? shape;
  final BorderSide? side;
  final Clip clipBehavior;
  final VisualDensity? visualDensity;
  final double? elevation;
  final double? pressElevation;

  const TomChoiceChip({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.selected,
    this.onSelected,
    this.avatar,
    this.label,
    this.labelText,
    this.labelStyle,
    this.labelPadding,
    this.padding,
    this.selectedColor,
    this.disabledColor,
    this.backgroundColor,
    this.selectedShadowColor,
    this.shadowColor,
    this.shape,
    this.side,
    this.clipBehavior = Clip.none,
    this.visualDensity,
    this.elevation,
    this.pressElevation,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = labelText ?? (tomId != null ? resolveResource(context, 'label') : null);
    final chipLabel = label ?? Text(resolvedLabel ?? '');

    return ChoiceChip(
      selected: selected,
      onSelected: onSelected,
      avatar: avatar,
      label: chipLabel,
      labelStyle: labelStyle,
      labelPadding: labelPadding,
      padding: padding,
      selectedColor: selectedColor,
      disabledColor: disabledColor,
      backgroundColor: backgroundColor,
      selectedShadowColor: selectedShadowColor,
      shadowColor: shadowColor,
      shape: shape,
      side: side,
      clipBehavior: clipBehavior,
      visualDensity: visualDensity,
      elevation: elevation,
      pressElevation: pressElevation,
    );
  }
}

/// Tom wrapper for [ActionChip].
///
/// Adds ID, group, authorization, and resource resolution for label/tooltip.
class TomActionChip extends TomChipBase {
  final VoidCallback? onPressed;
  final Widget? avatar;
  final Widget? label;
  final String? labelText;
  final TextStyle? labelStyle;
  final EdgeInsetsGeometry? labelPadding;
  final EdgeInsetsGeometry? padding;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final OutlinedBorder? shape;
  final BorderSide? side;
  final Clip clipBehavior;
  final VisualDensity? visualDensity;
  final double? elevation;
  final double? pressElevation;

  const TomActionChip({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onPressed,
    this.avatar,
    this.label,
    this.labelText,
    this.labelStyle,
    this.labelPadding,
    this.padding,
    this.tooltip,
    this.backgroundColor,
    this.shadowColor,
    this.surfaceTintColor,
    this.shape,
    this.side,
    this.clipBehavior = Clip.none,
    this.visualDensity,
    this.elevation,
    this.pressElevation,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = labelText ?? (tomId != null ? resolveResource(context, 'label') : null);
    final resolvedTooltip = tooltip ?? (tomId != null ? resolveResource(context, 'tooltip') : null);
    final chipLabel = label ?? Text(resolvedLabel ?? '');

    return ActionChip(
      onPressed: onPressed,
      avatar: avatar,
      label: chipLabel,
      labelStyle: labelStyle,
      labelPadding: labelPadding,
      padding: padding,
      tooltip: resolvedTooltip,
      backgroundColor: backgroundColor,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      shape: shape,
      side: side,
      clipBehavior: clipBehavior,
      visualDensity: visualDensity,
      elevation: elevation,
      pressElevation: pressElevation,
    );
  }
}
