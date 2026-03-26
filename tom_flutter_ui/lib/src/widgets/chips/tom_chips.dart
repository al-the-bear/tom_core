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
    final resolvedLabel = labelText ?? resolveResourceOrFail(context, 'label');
    final chipLabel = label ?? Text(resolvedLabel);

    Widget chip = FilterChip(
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

    return chip;
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
    final resolvedLabel = labelText ?? resolveResourceOrFail(context, 'label');
    final chipLabel = label ?? Text(resolvedLabel);

    Widget chip = ChoiceChip(
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

    return chip;
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
    final resolvedLabel = labelText ?? resolveResourceOrFail(context, 'label');
    final resolvedTooltip = tooltip ?? resolveResourceOrFail(context, 'tooltip');
    final chipLabel = label ?? Text(resolvedLabel);

    Widget chip = ActionChip(
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

    return chip;
  }
}

/// Tom wrapper for [InputChip].
///
/// Adds ID, group, authorization, and resource resolution for label.
class TomInputChip extends TomChipBase {
  final bool selected;
  final bool isEnabled;
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onDeleted;
  final VoidCallback? onPressed;
  final Widget? avatar;
  final Widget? label;
  final String? labelText;
  final TextStyle? labelStyle;
  final EdgeInsetsGeometry? labelPadding;
  final EdgeInsetsGeometry? padding;
  final Widget? deleteIcon;
  final Color? deleteIconColor;
  final String? deleteButtonTooltipMessage;
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
  final String? tooltip;

  const TomInputChip({
    super.key,
    super.tomId,
    super.tomGroup,
    this.selected = false,
    this.isEnabled = true,
    this.onSelected,
    this.onDeleted,
    this.onPressed,
    this.avatar,
    this.label,
    this.labelText,
    this.labelStyle,
    this.labelPadding,
    this.padding,
    this.deleteIcon,
    this.deleteIconColor,
    this.deleteButtonTooltipMessage,
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
    this.tooltip,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = labelText ?? resolveResourceOrFail(context, 'label');
    final resolvedTooltip = tooltip ?? resolveResourceOrFail(context, 'tooltip');
    final chipLabel = label ?? Text(resolvedLabel);

    return InputChip(
      selected: selected,
      isEnabled: isEnabled,
      onSelected: onSelected,
      onDeleted: onDeleted,
      onPressed: onPressed,
      avatar: avatar,
      label: chipLabel,
      labelStyle: labelStyle,
      labelPadding: labelPadding,
      padding: padding,
      deleteIcon: deleteIcon,
      deleteIconColor: deleteIconColor,
      deleteButtonTooltipMessage: deleteButtonTooltipMessage,
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
      tooltip: resolvedTooltip,
    );
  }
}

/// Tom wrapper for [RawChip].
///
/// Adds ID, group, authorization, and resource resolution.
class TomRawChip extends TomChipBase {
  final Widget? avatar;
  final Widget? label;
  final String? labelText;
  final TextStyle? labelStyle;
  final EdgeInsetsGeometry? labelPadding;
  final bool selected;
  final bool isEnabled;
  final ValueChanged<bool>? onSelected;
  final Widget? deleteIcon;
  final VoidCallback? onDeleted;
  final Color? deleteIconColor;
  final String? deleteButtonTooltipMessage;
  final VoidCallback? onPressed;
  final double? pressElevation;
  final bool? showCheckmark;
  final Color? checkmarkColor;
  final OutlinedBorder? shape;
  final BorderSide? side;
  final Clip clipBehavior;
  final Color? selectedColor;
  final Color? disabledColor;
  final Color? backgroundColor;
  final Color? selectedShadowColor;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final EdgeInsetsGeometry? padding;
  final VisualDensity? visualDensity;
  final MaterialTapTargetSize? materialTapTargetSize;
  final double? elevation;
  final String? tooltip;

  const TomRawChip({
    super.key,
    super.tomId,
    super.tomGroup,
    this.avatar,
    this.label,
    this.labelText,
    this.labelStyle,
    this.labelPadding,
    this.selected = false,
    this.isEnabled = true,
    this.onSelected,
    this.deleteIcon,
    this.onDeleted,
    this.deleteIconColor,
    this.deleteButtonTooltipMessage,
    this.onPressed,
    this.pressElevation,
    this.showCheckmark,
    this.checkmarkColor,
    this.shape,
    this.side,
    this.clipBehavior = Clip.none,
    this.selectedColor,
    this.disabledColor,
    this.backgroundColor,
    this.selectedShadowColor,
    this.shadowColor,
    this.surfaceTintColor,
    this.padding,
    this.visualDensity,
    this.materialTapTargetSize,
    this.elevation,
    this.tooltip,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = labelText ?? resolveResourceOrFail(context, 'label');
    final chipLabel = label ?? Text(resolvedLabel);
    final resolvedTooltip =
      tooltip ?? resolveResourceOrFail(context, 'tooltip');

    return RawChip(
      avatar: avatar,
      label: chipLabel,
      labelStyle: labelStyle,
      labelPadding: labelPadding,
      selected: selected,
      isEnabled: isEnabled,
      onSelected: onSelected,
      deleteIcon: deleteIcon,
      onDeleted: onDeleted,
      deleteIconColor: deleteIconColor,
      deleteButtonTooltipMessage: deleteButtonTooltipMessage,
      onPressed: onPressed,
      pressElevation: pressElevation,
      showCheckmark: showCheckmark,
      checkmarkColor: checkmarkColor,
      shape: shape,
      side: side,
      clipBehavior: clipBehavior,
      selectedColor: selectedColor,
      disabledColor: disabledColor,
      backgroundColor: backgroundColor,
      selectedShadowColor: selectedShadowColor,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      padding: padding,
      visualDensity: visualDensity,
      materialTapTargetSize: materialTapTargetSize,
      elevation: elevation,
      tooltip: resolvedTooltip,
    );
  }
}
