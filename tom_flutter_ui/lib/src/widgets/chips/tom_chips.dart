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

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final Widget _chipLabel;
  late final Color? _resolvedCheckmarkColor;
  late final Color? _resolvedSelectedColor;
  late final Color? _resolvedDisabledColor;
  late final Color? _resolvedBackgroundColor;
  late final Color? _resolvedSelectedShadowColor;
  late final Color? _resolvedShadowColor;
  late final double? _resolvedElevation;
  late final double? _resolvedPressElevation;
  late final Color? _resolvedDeleteIconColor;
  late final TextStyle? _resolvedLabelStyle;
  late final EdgeInsetsGeometry? _resolvedLabelPadding;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final bool _resolvedShowCheckmark;
  late final String? _resolvedDeleteButtonTooltipMessage;
  late final OutlinedBorder? _resolvedShape;
  late final BorderSide? _resolvedSide;
  late final VisualDensity? _resolvedVisualDensity;

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
  }) {
    _resolvedLabel = labelText ?? resolveResourceOrFail('label');
    _chipLabel = label ?? Text(_resolvedLabel);
    _resolvedCheckmarkColor = checkmarkColor ?? resolveColorOrNull('checkmarkColor');
    _resolvedSelectedColor = selectedColor ?? resolveColorOrNull('selectedColor');
    _resolvedDisabledColor = disabledColor ?? resolveColorOrNull('disabledColor');
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
    _resolvedSelectedShadowColor = selectedShadowColor ?? resolveColorOrNull('selectedShadowColor');
    _resolvedShadowColor = shadowColor ?? resolveColorOrNull('shadowColor');
    _resolvedElevation = elevation ?? resolveDoubleOrNull('elevation');
    _resolvedPressElevation = pressElevation ?? resolveDoubleOrNull('pressElevation');
    _resolvedDeleteIconColor = deleteIconColor ?? resolveColorOrNull('deleteIconColor');
    _resolvedLabelStyle = labelStyle ?? _resolveTextStyle('labelStyle');
    _resolvedLabelPadding = labelPadding ?? resolveEdgeInsetsOrNull('labelPadding');
    _resolvedPadding = padding ?? resolveEdgeInsetsOrNull('padding');
    _resolvedShowCheckmark = resolveBoolOrNull('showCheckmark') ?? showCheckmark;
    _resolvedDeleteButtonTooltipMessage = deleteButtonTooltipMessage ?? resolveResourceOrNull('deleteButtonTooltipMessage');
    _resolvedShape = shape ?? _resolveShapeBorder('shape') as OutlinedBorder?;
    _resolvedSide = side ?? _resolveBorderSide('side');
    _resolvedVisualDensity = visualDensity ?? _resolveVisualDensity('visualDensity');
  }

  @override
  Widget buildContent(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: onSelected,
      avatar: avatar,
      label: _chipLabel,
      labelStyle: _resolvedLabelStyle,
      labelPadding: _resolvedLabelPadding,
      padding: _resolvedPadding,
      showCheckmark: _resolvedShowCheckmark,
      checkmarkColor: _resolvedCheckmarkColor,
      selectedColor: _resolvedSelectedColor,
      disabledColor: _resolvedDisabledColor,
      backgroundColor: _resolvedBackgroundColor,
      selectedShadowColor: _resolvedSelectedShadowColor,
      shadowColor: _resolvedShadowColor,
      shape: _resolvedShape,
      side: _resolvedSide,
      clipBehavior: clipBehavior,
      visualDensity: _resolvedVisualDensity,
      elevation: _resolvedElevation,
      pressElevation: _resolvedPressElevation,
      deleteIcon: deleteIcon,
      onDeleted: onDeleted,
      deleteIconColor: _resolvedDeleteIconColor,
      deleteButtonTooltipMessage: _resolvedDeleteButtonTooltipMessage,
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

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final Widget _chipLabel;
  late final Color? _resolvedSelectedColor;
  late final Color? _resolvedDisabledColor;
  late final Color? _resolvedBackgroundColor;
  late final Color? _resolvedSelectedShadowColor;
  late final Color? _resolvedShadowColor;
  late final double? _resolvedElevation;
  late final double? _resolvedPressElevation;
  late final TextStyle? _resolvedLabelStyle;
  late final EdgeInsetsGeometry? _resolvedLabelPadding;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final OutlinedBorder? _resolvedShape;
  late final BorderSide? _resolvedSide;
  late final VisualDensity? _resolvedVisualDensity;

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
  }) {
    _resolvedLabel = labelText ?? resolveResourceOrFail('label');
    _chipLabel = label ?? Text(_resolvedLabel);
    _resolvedSelectedColor = selectedColor ?? resolveColorOrNull('selectedColor');
    _resolvedDisabledColor = disabledColor ?? resolveColorOrNull('disabledColor');
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
    _resolvedSelectedShadowColor = selectedShadowColor ?? resolveColorOrNull('selectedShadowColor');
    _resolvedShadowColor = shadowColor ?? resolveColorOrNull('shadowColor');
    _resolvedElevation = elevation ?? resolveDoubleOrNull('elevation');
    _resolvedPressElevation = pressElevation ?? resolveDoubleOrNull('pressElevation');
    _resolvedLabelStyle = labelStyle ?? _resolveTextStyle('labelStyle');
    _resolvedLabelPadding = labelPadding ?? resolveEdgeInsetsOrNull('labelPadding');
    _resolvedPadding = padding ?? resolveEdgeInsetsOrNull('padding');
    _resolvedShape = shape ?? _resolveShapeBorder('shape') as OutlinedBorder?;
    _resolvedSide = side ?? _resolveBorderSide('side');
    _resolvedVisualDensity = visualDensity ?? _resolveVisualDensity('visualDensity');
  }

  @override
  Widget buildContent(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: onSelected,
      avatar: avatar,
      label: _chipLabel,
      labelStyle: _resolvedLabelStyle,
      labelPadding: _resolvedLabelPadding,
      padding: _resolvedPadding,
      selectedColor: _resolvedSelectedColor,
      disabledColor: _resolvedDisabledColor,
      backgroundColor: _resolvedBackgroundColor,
      selectedShadowColor: _resolvedSelectedShadowColor,
      shadowColor: _resolvedShadowColor,
      shape: _resolvedShape,
      side: _resolvedSide,
      clipBehavior: clipBehavior,
      visualDensity: _resolvedVisualDensity,
      elevation: _resolvedElevation,
      pressElevation: _resolvedPressElevation,
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

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final String _resolvedTooltip;
  late final Widget _chipLabel;
  late final Color? _resolvedBackgroundColor;
  late final Color? _resolvedShadowColor;
  late final Color? _resolvedSurfaceTintColor;
  late final double? _resolvedElevation;
  late final double? _resolvedPressElevation;
  late final TextStyle? _resolvedLabelStyle;
  late final EdgeInsetsGeometry? _resolvedLabelPadding;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final OutlinedBorder? _resolvedShape;
  late final BorderSide? _resolvedSide;
  late final VisualDensity? _resolvedVisualDensity;

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
  }) {
    _resolvedLabel = labelText ?? resolveResourceOrFail('label');
    _resolvedTooltip = tooltip ?? resolveResourceOrFail('tooltip');
    _chipLabel = label ?? Text(_resolvedLabel);
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
    _resolvedShadowColor = shadowColor ?? resolveColorOrNull('shadowColor');
    _resolvedSurfaceTintColor = surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    _resolvedElevation = elevation ?? resolveDoubleOrNull('elevation');
    _resolvedPressElevation = pressElevation ?? resolveDoubleOrNull('pressElevation');
    _resolvedLabelStyle = labelStyle ?? _resolveTextStyle('labelStyle');
    _resolvedLabelPadding = labelPadding ?? resolveEdgeInsetsOrNull('labelPadding');
    _resolvedPadding = padding ?? resolveEdgeInsetsOrNull('padding');
    _resolvedShape = shape ?? _resolveShapeBorder('shape') as OutlinedBorder?;
    _resolvedSide = side ?? _resolveBorderSide('side');
    _resolvedVisualDensity = visualDensity ?? _resolveVisualDensity('visualDensity');
  }

  @override
  Widget buildContent(BuildContext context) {
    return ActionChip(
      onPressed: onPressed,
      avatar: avatar,
      label: _chipLabel,
      labelStyle: _resolvedLabelStyle,
      labelPadding: _resolvedLabelPadding,
      padding: _resolvedPadding,
      tooltip: _resolvedTooltip,
      backgroundColor: _resolvedBackgroundColor,
      shadowColor: _resolvedShadowColor,
      surfaceTintColor: _resolvedSurfaceTintColor,
      shape: _resolvedShape,
      side: _resolvedSide,
      clipBehavior: clipBehavior,
      visualDensity: _resolvedVisualDensity,
      elevation: _resolvedElevation,
      pressElevation: _resolvedPressElevation,
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

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final String _resolvedTooltip;
  late final Widget _chipLabel;
  late final Color? _resolvedDeleteIconColor;
  late final Color? _resolvedCheckmarkColor;
  late final Color? _resolvedSelectedColor;
  late final Color? _resolvedDisabledColor;
  late final Color? _resolvedBackgroundColor;
  late final Color? _resolvedSelectedShadowColor;
  late final Color? _resolvedShadowColor;
  late final double? _resolvedElevation;
  late final double? _resolvedPressElevation;
  late final TextStyle? _resolvedLabelStyle;
  late final EdgeInsetsGeometry? _resolvedLabelPadding;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final String? _resolvedDeleteButtonTooltipMessage;
  late final bool _resolvedShowCheckmark;
  late final OutlinedBorder? _resolvedShape;
  late final BorderSide? _resolvedSide;
  late final VisualDensity? _resolvedVisualDensity;

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
  }) {
    _resolvedLabel = labelText ?? resolveResourceOrFail('label');
    _resolvedTooltip = tooltip ?? resolveResourceOrFail('tooltip');
    _chipLabel = label ?? Text(_resolvedLabel);
    _resolvedDeleteIconColor = deleteIconColor ?? resolveColorOrNull('deleteIconColor');
    _resolvedCheckmarkColor = checkmarkColor ?? resolveColorOrNull('checkmarkColor');
    _resolvedSelectedColor = selectedColor ?? resolveColorOrNull('selectedColor');
    _resolvedDisabledColor = disabledColor ?? resolveColorOrNull('disabledColor');
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
    _resolvedSelectedShadowColor = selectedShadowColor ?? resolveColorOrNull('selectedShadowColor');
    _resolvedShadowColor = shadowColor ?? resolveColorOrNull('shadowColor');
    _resolvedElevation = elevation ?? resolveDoubleOrNull('elevation');
    _resolvedPressElevation = pressElevation ?? resolveDoubleOrNull('pressElevation');
    _resolvedLabelStyle = labelStyle ?? _resolveTextStyle('labelStyle');
    _resolvedLabelPadding = labelPadding ?? resolveEdgeInsetsOrNull('labelPadding');
    _resolvedPadding = padding ?? resolveEdgeInsetsOrNull('padding');
    _resolvedDeleteButtonTooltipMessage = deleteButtonTooltipMessage ?? resolveResourceOrNull('deleteButtonTooltipMessage');
    _resolvedShowCheckmark = resolveBoolOrNull('showCheckmark') ?? showCheckmark;
    _resolvedShape = shape ?? _resolveShapeBorder('shape') as OutlinedBorder?;
    _resolvedSide = side ?? _resolveBorderSide('side');
    _resolvedVisualDensity = visualDensity ?? _resolveVisualDensity('visualDensity');
  }

  @override
  Widget buildContent(BuildContext context) {
    return InputChip(
      selected: selected,
      isEnabled: isEnabled,
      onSelected: onSelected,
      onDeleted: onDeleted,
      onPressed: onPressed,
      avatar: avatar,
      label: _chipLabel,
      labelStyle: _resolvedLabelStyle,
      labelPadding: _resolvedLabelPadding,
      padding: _resolvedPadding,
      deleteIcon: deleteIcon,
      deleteIconColor: _resolvedDeleteIconColor,
      deleteButtonTooltipMessage: _resolvedDeleteButtonTooltipMessage,
      showCheckmark: _resolvedShowCheckmark,
      checkmarkColor: _resolvedCheckmarkColor,
      selectedColor: _resolvedSelectedColor,
      disabledColor: _resolvedDisabledColor,
      backgroundColor: _resolvedBackgroundColor,
      selectedShadowColor: _resolvedSelectedShadowColor,
      shadowColor: _resolvedShadowColor,
      shape: _resolvedShape,
      side: _resolvedSide,
      clipBehavior: clipBehavior,
      visualDensity: _resolvedVisualDensity,
      elevation: _resolvedElevation,
      pressElevation: _resolvedPressElevation,
      tooltip: _resolvedTooltip,
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

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final String _resolvedTooltip;
  late final Widget _chipLabel;
  late final Color? _resolvedDeleteIconColor;
  late final double? _resolvedPressElevation;
  late final Color? _resolvedCheckmarkColor;
  late final Color? _resolvedSelectedColor;
  late final Color? _resolvedDisabledColor;
  late final Color? _resolvedBackgroundColor;
  late final Color? _resolvedSelectedShadowColor;
  late final Color? _resolvedShadowColor;
  late final Color? _resolvedSurfaceTintColor;
  late final double? _resolvedElevation;
  late final TextStyle? _resolvedLabelStyle;
  late final EdgeInsetsGeometry? _resolvedLabelPadding;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final String? _resolvedDeleteButtonTooltipMessage;
  late final OutlinedBorder? _resolvedShape;
  late final BorderSide? _resolvedSide;
  late final VisualDensity? _resolvedVisualDensity;

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
  }) {
    _resolvedLabel = labelText ?? resolveResourceOrFail('label');
    _resolvedTooltip = tooltip ?? resolveResourceOrFail('tooltip');
    _chipLabel = label ?? Text(_resolvedLabel);
    _resolvedDeleteIconColor = deleteIconColor ?? resolveColorOrNull('deleteIconColor');
    _resolvedPressElevation = pressElevation ?? resolveDoubleOrNull('pressElevation');
    _resolvedCheckmarkColor = checkmarkColor ?? resolveColorOrNull('checkmarkColor');
    _resolvedSelectedColor = selectedColor ?? resolveColorOrNull('selectedColor');
    _resolvedDisabledColor = disabledColor ?? resolveColorOrNull('disabledColor');
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
    _resolvedSelectedShadowColor = selectedShadowColor ?? resolveColorOrNull('selectedShadowColor');
    _resolvedShadowColor = shadowColor ?? resolveColorOrNull('shadowColor');
    _resolvedSurfaceTintColor = surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    _resolvedElevation = elevation ?? resolveDoubleOrNull('elevation');
    _resolvedLabelStyle = labelStyle ?? _resolveTextStyle('labelStyle');
    _resolvedLabelPadding = labelPadding ?? resolveEdgeInsetsOrNull('labelPadding');
    _resolvedPadding = padding ?? resolveEdgeInsetsOrNull('padding');
    _resolvedDeleteButtonTooltipMessage = deleteButtonTooltipMessage ?? resolveResourceOrNull('deleteButtonTooltipMessage');
    _resolvedShape = shape ?? _resolveShapeBorder('shape') as OutlinedBorder?;
    _resolvedSide = side ?? _resolveBorderSide('side');
    _resolvedVisualDensity = visualDensity ?? _resolveVisualDensity('visualDensity');
  }

  @override
  Widget buildContent(BuildContext context) {
    return RawChip(
      avatar: avatar,
      label: _chipLabel,
      labelStyle: _resolvedLabelStyle,
      labelPadding: _resolvedLabelPadding,
      selected: selected,
      isEnabled: isEnabled,
      onSelected: onSelected,
      deleteIcon: deleteIcon,
      onDeleted: onDeleted,
      deleteIconColor: _resolvedDeleteIconColor,
      deleteButtonTooltipMessage: _resolvedDeleteButtonTooltipMessage,
      onPressed: onPressed,
      pressElevation: _resolvedPressElevation,
      showCheckmark: showCheckmark,
      checkmarkColor: _resolvedCheckmarkColor,
      shape: _resolvedShape,
      side: _resolvedSide,
      clipBehavior: clipBehavior,
      selectedColor: _resolvedSelectedColor,
      disabledColor: _resolvedDisabledColor,
      backgroundColor: _resolvedBackgroundColor,
      selectedShadowColor: _resolvedSelectedShadowColor,
      shadowColor: _resolvedShadowColor,
      surfaceTintColor: _resolvedSurfaceTintColor,
      padding: _resolvedPadding,
      visualDensity: _resolvedVisualDensity,
      materialTapTargetSize: materialTapTargetSize,
      elevation: _resolvedElevation,
      tooltip: _resolvedTooltip,
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
