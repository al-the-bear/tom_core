import 'package:flutter/material.dart';

import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_style_resolvers.dart';

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

  TomFilterChip({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
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
    final resolvedLabel = labelText ?? resolveResourceOrFail('label');
    final chipLabel = label ?? Text(resolvedLabel);

    // Phase 2: Resolve optional parameters from resources
    final resolvedCheckmarkColor =
        checkmarkColor ?? resolveColorOrNull('checkmarkColor');
    final resolvedSelectedColor =
        selectedColor ?? resolveColorOrNull('selectedColor');
    final resolvedDisabledColor =
        disabledColor ?? resolveColorOrNull('disabledColor');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedSelectedShadowColor =
        selectedShadowColor ?? resolveColorOrNull('selectedShadowColor');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedPressElevation =
        pressElevation ?? resolveDoubleOrNull('pressElevation');
    final resolvedDeleteIconColor =
        deleteIconColor ?? resolveColorOrNull('deleteIconColor');

    // Phase 3: Resolve TextStyle from resources
    final resolvedLabelStyle = labelStyle ?? _resolveTextStyle('labelStyle');

    // Phase 3: Resolve remaining optional parameters from resources
    final resolvedLabelPadding =
        labelPadding ?? resolveEdgeInsetsOrNull('labelPadding');
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding');
    final resolvedShowCheckmark =
        resolveBoolOrNull('showCheckmark') ?? showCheckmark;
    final resolvedDeleteButtonTooltipMessage =
        deleteButtonTooltipMessage ?? resolveResourceOrNull('deleteButtonTooltipMessage');

    Widget chip = FilterChip(
      selected: selected,
      onSelected: onSelected,
      avatar: avatar,
      label: chipLabel,
      labelStyle: resolvedLabelStyle,
      labelPadding: resolvedLabelPadding,
      padding: resolvedPadding,
      showCheckmark: resolvedShowCheckmark,
      checkmarkColor: resolvedCheckmarkColor,
      selectedColor: resolvedSelectedColor,
      disabledColor: resolvedDisabledColor,
      backgroundColor: resolvedBackgroundColor,
      selectedShadowColor: resolvedSelectedShadowColor,
      shadowColor: resolvedShadowColor,
      shape: shape ?? _resolveShapeBorder('shape') as OutlinedBorder?,
      side: side ?? _resolveBorderSide('side'),
      clipBehavior: clipBehavior,
      visualDensity: visualDensity ?? _resolveVisualDensity('visualDensity'),
      elevation: resolvedElevation,
      pressElevation: resolvedPressElevation,
      deleteIcon: deleteIcon,
      onDeleted: onDeleted,
      deleteIconColor: resolvedDeleteIconColor,
      deleteButtonTooltipMessage: resolvedDeleteButtonTooltipMessage,
    );

    return chip;
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }

  BorderSide? _resolveBorderSide(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderSide(basePath!, suffix);
  }

  VisualDensity? _resolveVisualDensity(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveVisualDensity(basePath!, suffix);
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

  TomChoiceChip({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
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
    final resolvedLabel = labelText ?? resolveResourceOrFail('label');
    final chipLabel = label ?? Text(resolvedLabel);

    // Phase 2: Resolve optional parameters from resources
    final resolvedSelectedColor =
        selectedColor ?? resolveColorOrNull('selectedColor');
    final resolvedDisabledColor =
        disabledColor ?? resolveColorOrNull('disabledColor');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedSelectedShadowColor =
        selectedShadowColor ?? resolveColorOrNull('selectedShadowColor');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedPressElevation =
        pressElevation ?? resolveDoubleOrNull('pressElevation');

    // Phase 3: Resolve TextStyle from resources
    final resolvedLabelStyle = labelStyle ?? _resolveTextStyle('labelStyle');

    // Phase 3: Resolve remaining optional parameters from resources
    final resolvedLabelPadding =
        labelPadding ?? resolveEdgeInsetsOrNull('labelPadding');
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding');

    Widget chip = ChoiceChip(
      selected: selected,
      onSelected: onSelected,
      avatar: avatar,
      label: chipLabel,
      labelStyle: resolvedLabelStyle,
      labelPadding: resolvedLabelPadding,
      padding: resolvedPadding,
      selectedColor: resolvedSelectedColor,
      disabledColor: resolvedDisabledColor,
      backgroundColor: resolvedBackgroundColor,
      selectedShadowColor: resolvedSelectedShadowColor,
      shadowColor: resolvedShadowColor,
      shape: shape ?? _resolveShapeBorder('shape') as OutlinedBorder?,
      side: side ?? _resolveBorderSide('side'),
      clipBehavior: clipBehavior,
      visualDensity: visualDensity ?? _resolveVisualDensity('visualDensity'),
      elevation: resolvedElevation,
      pressElevation: resolvedPressElevation,
    );

    return chip;
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }

  BorderSide? _resolveBorderSide(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderSide(basePath!, suffix);
  }

  VisualDensity? _resolveVisualDensity(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveVisualDensity(basePath!, suffix);
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

  TomActionChip({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
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
    final resolvedLabel = labelText ?? resolveResourceOrFail('label');
    final resolvedTooltip = tooltip ?? resolveResourceOrFail('tooltip');
    final chipLabel = label ?? Text(resolvedLabel);

    // Phase 2: Resolve optional parameters from resources
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedSurfaceTintColor =
        surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedPressElevation =
        pressElevation ?? resolveDoubleOrNull('pressElevation');

    // Phase 3: Resolve TextStyle from resources
    final resolvedLabelStyle = labelStyle ?? _resolveTextStyle('labelStyle');

    // Phase 3: Resolve remaining optional parameters from resources
    final resolvedLabelPadding =
        labelPadding ?? resolveEdgeInsetsOrNull('labelPadding');
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding');

    Widget chip = ActionChip(
      onPressed: onPressed,
      avatar: avatar,
      label: chipLabel,
      labelStyle: resolvedLabelStyle,
      labelPadding: resolvedLabelPadding,
      padding: resolvedPadding,
      tooltip: resolvedTooltip,
      backgroundColor: resolvedBackgroundColor,
      shadowColor: resolvedShadowColor,
      surfaceTintColor: resolvedSurfaceTintColor,
      shape: shape ?? _resolveShapeBorder('shape') as OutlinedBorder?,
      side: side ?? _resolveBorderSide('side'),
      clipBehavior: clipBehavior,
      visualDensity: visualDensity ?? _resolveVisualDensity('visualDensity'),
      elevation: resolvedElevation,
      pressElevation: resolvedPressElevation,
    );

    return chip;
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }

  BorderSide? _resolveBorderSide(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderSide(basePath!, suffix);
  }

  VisualDensity? _resolveVisualDensity(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveVisualDensity(basePath!, suffix);
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

  TomInputChip({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
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
    final resolvedLabel = labelText ?? resolveResourceOrFail('label');
    final resolvedTooltip = tooltip ?? resolveResourceOrFail('tooltip');
    final chipLabel = label ?? Text(resolvedLabel);

    // Phase 2: Resolve optional parameters from resources
    final resolvedDeleteIconColor =
        deleteIconColor ?? resolveColorOrNull('deleteIconColor');
    final resolvedCheckmarkColor =
        checkmarkColor ?? resolveColorOrNull('checkmarkColor');
    final resolvedSelectedColor =
        selectedColor ?? resolveColorOrNull('selectedColor');
    final resolvedDisabledColor =
        disabledColor ?? resolveColorOrNull('disabledColor');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedSelectedShadowColor =
        selectedShadowColor ?? resolveColorOrNull('selectedShadowColor');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedPressElevation =
        pressElevation ?? resolveDoubleOrNull('pressElevation');

    // Phase 3: Resolve TextStyle from resources
    final resolvedLabelStyle = labelStyle ?? _resolveTextStyle('labelStyle');

    // Phase 3: Resolve remaining optional parameters from resources
    final resolvedLabelPadding =
        labelPadding ?? resolveEdgeInsetsOrNull('labelPadding');
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding');
    final resolvedDeleteButtonTooltipMessage =
        deleteButtonTooltipMessage ?? resolveResourceOrNull('deleteButtonTooltipMessage');
    final resolvedShowCheckmark =
        resolveBoolOrNull('showCheckmark') ?? showCheckmark;

    return InputChip(
      selected: selected,
      isEnabled: isEnabled,
      onSelected: onSelected,
      onDeleted: onDeleted,
      onPressed: onPressed,
      avatar: avatar,
      label: chipLabel,
      labelStyle: resolvedLabelStyle,
      labelPadding: resolvedLabelPadding,
      padding: resolvedPadding,
      deleteIcon: deleteIcon,
      deleteIconColor: resolvedDeleteIconColor,
      deleteButtonTooltipMessage: resolvedDeleteButtonTooltipMessage,
      showCheckmark: resolvedShowCheckmark,
      checkmarkColor: resolvedCheckmarkColor,
      selectedColor: resolvedSelectedColor,
      disabledColor: resolvedDisabledColor,
      backgroundColor: resolvedBackgroundColor,
      selectedShadowColor: resolvedSelectedShadowColor,
      shadowColor: resolvedShadowColor,
      shape: shape ?? _resolveShapeBorder('shape') as OutlinedBorder?,
      side: side ?? _resolveBorderSide('side'),
      clipBehavior: clipBehavior,
      visualDensity: visualDensity ?? _resolveVisualDensity('visualDensity'),
      elevation: resolvedElevation,
      pressElevation: resolvedPressElevation,
      tooltip: resolvedTooltip,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }

  BorderSide? _resolveBorderSide(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderSide(basePath!, suffix);
  }

  VisualDensity? _resolveVisualDensity(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveVisualDensity(basePath!, suffix);
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

  TomRawChip({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
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
    final resolvedLabel = labelText ?? resolveResourceOrFail('label');
    final chipLabel = label ?? Text(resolvedLabel);
    final resolvedTooltip =
      tooltip ?? resolveResourceOrFail('tooltip');

    // Phase 2: Resolve optional parameters from resources
    final resolvedDeleteIconColor =
        deleteIconColor ?? resolveColorOrNull('deleteIconColor');
    final resolvedPressElevation =
        pressElevation ?? resolveDoubleOrNull('pressElevation');
    final resolvedCheckmarkColor =
        checkmarkColor ?? resolveColorOrNull('checkmarkColor');
    final resolvedSelectedColor =
        selectedColor ?? resolveColorOrNull('selectedColor');
    final resolvedDisabledColor =
        disabledColor ?? resolveColorOrNull('disabledColor');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedSelectedShadowColor =
        selectedShadowColor ?? resolveColorOrNull('selectedShadowColor');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedSurfaceTintColor =
        surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');

    // Phase 3: Resolve TextStyle from resources
    final resolvedLabelStyle = labelStyle ?? _resolveTextStyle('labelStyle');

    // Phase 3: Resolve remaining optional parameters from resources
    final resolvedLabelPadding =
        labelPadding ?? resolveEdgeInsetsOrNull('labelPadding');
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding');
    final resolvedDeleteButtonTooltipMessage =
        deleteButtonTooltipMessage ?? resolveResourceOrNull('deleteButtonTooltipMessage');

    return RawChip(
      avatar: avatar,
      label: chipLabel,
      labelStyle: resolvedLabelStyle,
      labelPadding: resolvedLabelPadding,
      selected: selected,
      isEnabled: isEnabled,
      onSelected: onSelected,
      deleteIcon: deleteIcon,
      onDeleted: onDeleted,
      deleteIconColor: resolvedDeleteIconColor,
      deleteButtonTooltipMessage: resolvedDeleteButtonTooltipMessage,
      onPressed: onPressed,
      pressElevation: resolvedPressElevation,
      showCheckmark: showCheckmark,
      checkmarkColor: resolvedCheckmarkColor,
      shape: shape ?? _resolveShapeBorder('shape') as OutlinedBorder?,
      side: side ?? _resolveBorderSide('side'),
      clipBehavior: clipBehavior,
      selectedColor: resolvedSelectedColor,
      disabledColor: resolvedDisabledColor,
      backgroundColor: resolvedBackgroundColor,
      selectedShadowColor: resolvedSelectedShadowColor,
      shadowColor: resolvedShadowColor,
      surfaceTintColor: resolvedSurfaceTintColor,
      padding: resolvedPadding,
      visualDensity: visualDensity ?? _resolveVisualDensity('visualDensity'),
      materialTapTargetSize: materialTapTargetSize,
      elevation: resolvedElevation,
      tooltip: resolvedTooltip,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }

  BorderSide? _resolveBorderSide(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderSide(basePath!, suffix);
  }

  VisualDensity? _resolveVisualDensity(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveVisualDensity(basePath!, suffix);
  }
}
