import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../groups/tom_widget_mixin.dart';
import '../../widget_base/tom_family_base.dart';

/// Tom wrapper for [DropdownButton].
///
/// Adds ID, group, authorization, and resource resolution for hint label.
class TomDropdownButton<T> extends TomSelectBase {
  final T? value;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final VoidCallback? onTap;
  final int elevation;
  final TextStyle? style;
  final Widget? underline;
  final Widget? icon;
  final Color? iconDisabledColor;
  final Color? iconEnabledColor;
  final double iconSize;
  final bool isDense;
  final bool isExpanded;
  final double? itemHeight;
  final Color? focusColor;
  final FocusNode? focusNode;
  final bool autofocus;
  final Color? dropdownColor;
  final double? menuMaxHeight;
  final bool? enableFeedback;
  final AlignmentGeometry alignment;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final String? hint;

  const TomDropdownButton({
    super.key,
    super.tomId,
    super.tomGroup,
    this.value,
    this.items,
    this.onChanged,
    this.onTap,
    this.elevation = 8,
    this.style,
    this.underline,
    this.icon,
    this.iconDisabledColor,
    this.iconEnabledColor,
    this.iconSize = 24.0,
    this.isDense = false,
    this.isExpanded = false,
    this.itemHeight,
    this.focusColor,
    this.focusNode,
    this.autofocus = false,
    this.dropdownColor,
    this.menuMaxHeight,
    this.enableFeedback,
    this.alignment = AlignmentDirectional.centerStart,
    this.borderRadius,
    this.padding,
    this.hint,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedHint = hint ?? (tomId != null ? resolveResource(context, 'hint') : null);

    return DropdownButton<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      onTap: onTap,
      elevation: elevation,
      style: style,
      underline: underline,
      icon: icon,
      iconDisabledColor: iconDisabledColor,
      iconEnabledColor: iconEnabledColor,
      iconSize: iconSize,
      isDense: isDense,
      isExpanded: isExpanded,
      itemHeight: itemHeight,
      focusColor: focusColor,
      focusNode: focusNode,
      autofocus: autofocus,
      dropdownColor: dropdownColor,
      menuMaxHeight: menuMaxHeight,
      enableFeedback: enableFeedback,
      alignment: alignment,
      borderRadius: borderRadius,
      padding: padding,
      hint: resolvedHint != null ? Text(resolvedHint) : null,
    );
  }
}

/// Tom wrapper for [PopupMenuButton].
///
/// Adds ID, group, authorization, and resource resolution for tooltip.
class TomPopupMenuButton<T> extends TomSelectBase {
  final PopupMenuItemBuilder<T> itemBuilder;
  final T? initialValue;
  final PopupMenuItemSelected<T>? onSelected;
  final PopupMenuCanceled? onCanceled;
  final String? tooltip;
  final double? elevation;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final EdgeInsetsGeometry padding;
  final Widget? child;
  final Widget? icon;
  final double? iconSize;
  final Offset offset;
  final bool enabled;
  final ShapeBorder? shape;
  final Color? color;
  final bool? enableFeedback;
  final BoxConstraints? constraints;
  final PopupMenuPosition? position;
  final Clip clipBehavior;

  const TomPopupMenuButton({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.itemBuilder,
    this.initialValue,
    this.onSelected,
    this.onCanceled,
    this.tooltip,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.padding = const EdgeInsets.all(8.0),
    this.child,
    this.icon,
    this.iconSize,
    this.offset = Offset.zero,
    this.enabled = true,
    this.shape,
    this.color,
    this.enableFeedback,
    this.constraints,
    this.position,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTooltip = tooltip ?? resolveResourceOrFail(context, 'tooltip');

    return PopupMenuButton<T>(
      itemBuilder: itemBuilder,
      initialValue: initialValue,
      onSelected: onSelected,
      onCanceled: onCanceled,
      tooltip: resolvedTooltip,
      elevation: elevation,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      padding: padding,
      icon: icon,
      iconSize: iconSize,
      offset: offset,
      enabled: enabled,
      shape: shape,
      color: color,
      enableFeedback: enableFeedback,
      constraints: constraints,
      position: position,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

/// Tom wrapper for [DropdownMenu].
///
/// Material 3 dropdown menu with built-in search/filter.
/// Adds ID, group, authorization, and resource resolution for label/hint.
class TomDropdownMenu<T> extends TomSelectBase {
  final T? initialSelection;
  final ValueChanged<T?>? onSelected;
  final List<DropdownMenuEntry<T>> dropdownMenuEntries;
  final bool enabled;
  final double? width;
  final double? menuHeight;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final Widget? selectedTrailingIcon;
  final bool enableFilter;
  final bool enableSearch;
  final TextStyle? textStyle;
  final TextAlign textAlign;
  final InputDecorationTheme? inputDecorationTheme;
  final MenuStyle? menuStyle;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool requestFocusOnTap;
  final EdgeInsets? expandedInsets;
  final SearchCallback<T>? searchCallback;

  const TomDropdownMenu({
    super.key,
    super.tomId,
    super.tomGroup,
    this.initialSelection,
    this.onSelected,
    required this.dropdownMenuEntries,
    this.enabled = true,
    this.width,
    this.menuHeight,
    this.leadingIcon,
    this.trailingIcon,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.selectedTrailingIcon,
    this.enableFilter = false,
    this.enableSearch = true,
    this.textStyle,
    this.textAlign = TextAlign.start,
    this.inputDecorationTheme,
    this.menuStyle,
    this.controller,
    this.focusNode,
    this.requestFocusOnTap = true,
    this.expandedInsets,
    this.searchCallback,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = label ?? resolveResourceOrFail(context, 'label');
    final resolvedHint =
        hintText ?? (tomId != null ? resolveResource(context, 'hint') : null);

    return DropdownMenu<T>(
      initialSelection: initialSelection,
      onSelected: onSelected,
      dropdownMenuEntries: dropdownMenuEntries,
      enabled: enabled,
      width: width,
      menuHeight: menuHeight,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      label: Text(resolvedLabel),
      hintText: resolvedHint,
      helperText: helperText,
      errorText: errorText,
      selectedTrailingIcon: selectedTrailingIcon,
      enableFilter: enableFilter,
      enableSearch: enableSearch,
      textStyle: textStyle,
      textAlign: textAlign,
      inputDecorationTheme: inputDecorationTheme,
      menuStyle: menuStyle,
      controller: controller,
      focusNode: focusNode,
      requestFocusOnTap: requestFocusOnTap,
      expandedInsets: expandedInsets,
      searchCallback: searchCallback,
    );
  }
}

/// Tom wrapper for [MenuAnchor].
///
/// Anchors a menu to a child widget. Adds ID, group, authorization.
class TomMenuAnchor extends TomSelectBase {
  final List<Widget> menuChildren;
  final MenuController? controller;
  final Widget? child;
  final FocusNode? childFocusNode;
  final MenuStyle? style;
  final Offset? alignmentOffset;
  final Clip clipBehavior;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;
  final bool consumeOutsideTap;
  final Widget Function(BuildContext, MenuController, Widget?)? builder;

  const TomMenuAnchor({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.menuChildren,
    this.controller,
    this.child,
    this.childFocusNode,
    this.style,
    this.alignmentOffset,
    this.clipBehavior = Clip.none,
    this.onOpen,
    this.onClose,
    this.consumeOutsideTap = false,
    this.builder,
  });

  @override
  Widget buildContent(BuildContext context) {
    return MenuAnchor(
      menuChildren: menuChildren,
      controller: controller,
      childFocusNode: childFocusNode,
      style: style,
      alignmentOffset: alignmentOffset,
      clipBehavior: clipBehavior,
      onOpen: onOpen,
      onClose: onClose,
      consumeOutsideTap: consumeOutsideTap,
      builder: builder,
      child: child,
    );
  }
}

/// Tom wrapper for [DropdownButtonFormField].
///
/// Adds ID, group, authorization, and resource resolution.
class TomDropdownButtonFormField<T> extends TomSelectBase {
  final List<DropdownMenuItem<T>>? items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final VoidCallback? onTap;
  final InputDecoration? decoration;
  final Widget? hint;
  final Widget? disabledHint;
  final int elevation;
  final TextStyle? style;
  final Widget? icon;
  final Color? iconDisabledColor;
  final Color? iconEnabledColor;
  final double iconSize;
  final bool isDense;
  final bool isExpanded;
  final double? itemHeight;
  final Color? focusColor;
  final FocusNode? focusNode;
  final bool autofocus;
  final Color? dropdownColor;
  final EdgeInsetsGeometry? padding;
  final double? menuMaxHeight;
  final bool? enableFeedback;
  final AlignmentGeometry alignment;
  final BorderRadius? borderRadius;
  final FormFieldSetter<T>? onSaved;
  final FormFieldValidator<T>? validator;
  final AutovalidateMode? autovalidateMode;

  const TomDropdownButtonFormField({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.items,
    this.value,
    this.onChanged,
    this.onTap,
    this.decoration,
    this.hint,
    this.disabledHint,
    this.elevation = 8,
    this.style,
    this.icon,
    this.iconDisabledColor,
    this.iconEnabledColor,
    this.iconSize = 24.0,
    this.isDense = true,
    this.isExpanded = false,
    this.itemHeight,
    this.focusColor,
    this.focusNode,
    this.autofocus = false,
    this.dropdownColor,
    this.padding,
    this.menuMaxHeight,
    this.enableFeedback,
    this.alignment = AlignmentDirectional.centerStart,
    this.borderRadius,
    this.onSaved,
    this.validator,
    this.autovalidateMode,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = resolveResourceOrFail(context, 'label');
    final effectiveDecoration =
      decoration ?? InputDecoration(labelText: resolvedLabel);

    return DropdownButtonFormField<T>(
      items: items,
      value: value,
      onChanged: onChanged,
      onTap: onTap,
      decoration: effectiveDecoration,
      hint: hint,
      disabledHint: disabledHint,
      elevation: elevation,
      style: style,
      icon: icon,
      iconDisabledColor: iconDisabledColor,
      iconEnabledColor: iconEnabledColor,
      iconSize: iconSize,
      isDense: isDense,
      isExpanded: isExpanded,
      itemHeight: itemHeight,
      focusColor: focusColor,
      focusNode: focusNode,
      autofocus: autofocus,
      dropdownColor: dropdownColor,
      padding: padding,
      menuMaxHeight: menuMaxHeight,
      enableFeedback: enableFeedback,
      alignment: alignment,
      borderRadius: borderRadius,
      onSaved: onSaved,
      validator: validator,
      autovalidateMode: autovalidateMode,
    );
  }
}

/// Tom wrapper for [CupertinoSlidingSegmentedControl].
///
/// iOS 13-style sliding segmented control. Adds ID, group, authorization,
/// and resource resolution.
class TomCupertinoSlidingSegmentedControl<T extends Object>
    extends TomSelectBase {
  final Map<T, Widget> children;
  final T? groupValue;
  final ValueChanged<T?> onValueChanged;
  final Color? thumbColor;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  const TomCupertinoSlidingSegmentedControl({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.children,
    required this.groupValue,
    required this.onValueChanged,
    this.thumbColor,
    this.padding = const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
    this.backgroundColor,
  });

  @override
  Widget buildContent(BuildContext context) {
    final effectiveBg = backgroundColor ??
        CupertinoDynamicColor.resolve(
          CupertinoColors.tertiarySystemFill, context);
    final effectiveThumb = thumbColor ??
        CupertinoDynamicColor.resolve(
          CupertinoColors.white, context);

    return CupertinoSlidingSegmentedControl<T>(
      children: children,
      groupValue: groupValue,
      onValueChanged: onValueChanged,
      thumbColor: effectiveThumb,
      padding: padding,
      backgroundColor: effectiveBg,
    );
  }
}

// ============================================================================
// EXTENSION-BASED WIDGETS (extends Flutter widget + TomWidgetMixin)
// These preserve type identity for Flutter's runtime `is`-checks.
// ============================================================================

/// Tom widget that EXTENDS [PopupMenuItem] with authorization and resources.
///
/// This widget IS a [PopupMenuItem] — it passes `is PopupMenuItem` checks
/// and `is PopupMenuEntry` checks for use in [showMenu] and [PopupMenuButton].
///
/// **StatefulWidget pattern:**
/// - Widget has the mixin and `tomId`
/// - State overrides `build()` and accesses mixin methods through `widget`
///
/// ```dart
/// PopupMenuButton<String>(
///   itemBuilder: (context) => [
///     TomPopupMenuItem<String>(tomId: 'edit', value: 'edit', child: Text('Edit')),
///     TomPopupMenuItem<String>(tomId: 'delete', value: 'delete', child: Text('Delete')),
///   ],
/// )
/// ```
class TomPopupMenuItem<T> extends PopupMenuItem<T> with TomWidgetMixin {
  /// Creates a Tom PopupMenuItem.
  const TomPopupMenuItem({
    this.tomId,
    this.tomGroup,
    super.key,
    super.value,
    super.onTap,
    super.enabled,
    super.height,
    super.padding,
    super.textStyle,
    super.labelTextStyle,
    super.mouseCursor,
    required super.child,
  });

  @override
  final String? tomId;

  @override
  final String? tomGroup;

  @override
  PopupMenuItemState<T, TomPopupMenuItem<T>> createState() =>
      _TomPopupMenuItemState<T>();
}

class _TomPopupMenuItemState<T>
    extends PopupMenuItemState<T, TomPopupMenuItem<T>> {
  @override
  void initState() {
    super.initState();
    widget.registerWithGroup();
  }

  @override
  void dispose() {
    widget.unregisterFromGroup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hidden = widget.checkHidden(context);
    if (hidden != null) return hidden;
    return widget.applyReadonly(context, super.build(context));
  }
}

/// Tom widget that EXTENDS [PopupMenuDivider] with authorization.
///
/// This widget IS a [PopupMenuDivider] — passes `is PopupMenuEntry` checks.
///
/// Typically controlled via group authorization with adjacent menu items.
class TomPopupMenuDivider extends PopupMenuDivider with TomWidgetMixin {
  /// Creates a Tom PopupMenuDivider.
  const TomPopupMenuDivider({
    this.tomId,
    this.tomGroup,
    super.key,
    super.height,
  });

  @override
  final String? tomId;

  @override
  final String? tomGroup;

  @override
  State<PopupMenuDivider> createState() => _TomPopupMenuDividerState();
}

class _TomPopupMenuDividerState extends State<TomPopupMenuDivider> {
  @override
  void initState() {
    super.initState();
    (widget as TomWidgetMixin).registerWithGroup();
  }

  @override
  void dispose() {
    (widget as TomWidgetMixin).unregisterFromGroup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final widgetMixin = widget as TomWidgetMixin;
    final hidden = widgetMixin.checkHidden(context);
    if (hidden != null) return hidden;
    return const Divider(height: 1.0, thickness: 0.0);
  }
}

/// Tom widget that EXTENDS [CheckedPopupMenuItem] with authorization.
///
/// This widget IS a [CheckedPopupMenuItem] — it passes `is PopupMenuEntry` checks.
///
/// ```dart
/// PopupMenuButton<String>(
///   itemBuilder: (context) => [
///     TomCheckedPopupMenuItem<String>(tomId: 'opt1', value: 'opt1', child: Text('Option 1')),
///   ],
/// )
/// ```
class TomCheckedPopupMenuItem<T> extends CheckedPopupMenuItem<T>
    with TomWidgetMixin {
  /// Creates a Tom CheckedPopupMenuItem.
  const TomCheckedPopupMenuItem({
    this.tomId,
    this.tomGroup,
    super.key,
    super.value,
    super.checked,
    super.enabled,
    super.padding,
    super.height,
    super.labelTextStyle,
    super.mouseCursor,
    super.child,
  });

  @override
  final String? tomId;

  @override
  final String? tomGroup;

  @override
  PopupMenuItemState<T, CheckedPopupMenuItem<T>> createState() =>
      _TomCheckedPopupMenuItemState<T>();
}

class _TomCheckedPopupMenuItemState<T>
    extends PopupMenuItemState<T, CheckedPopupMenuItem<T>> {
  @override
  void initState() {
    super.initState();
    (widget as TomWidgetMixin).registerWithGroup();
  }

  @override
  void dispose() {
    (widget as TomWidgetMixin).unregisterFromGroup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final widgetMixin = widget as TomWidgetMixin;
    final hidden = widgetMixin.checkHidden(context);
    if (hidden != null) return hidden;
    return widgetMixin.applyReadonly(context, super.build(context));
  }
}

// ============================================================================
// Section II Selects — Cupertino pickers, additional select widgets
// ============================================================================

/// Tom wrapper for [CupertinoPicker].
///
/// Cupertino scroll wheel picker. Auth controls selection access.
class TomCupertinoPicker extends TomSelectBase {
  final double diameterRatio;
  final Color? backgroundColor;
  final double offAxisFraction;
  final bool useMagnifier;
  final double magnification;
  final double squeeze;
  final double itemExtent;
  final ValueChanged<int> onSelectedItemChanged;
  final List<Widget> children;
  final Widget? selectionOverlay;
  final bool looping;

  const TomCupertinoPicker({
    super.key,
    super.tomId,
    super.tomGroup,
    this.diameterRatio = 1.07,
    this.backgroundColor,
    this.offAxisFraction = 0.0,
    this.useMagnifier = false,
    this.magnification = 1.0,
    this.squeeze = 1.45,
    required this.itemExtent,
    required this.onSelectedItemChanged,
    required this.children,
    this.selectionOverlay = const CupertinoPickerDefaultSelectionOverlay(),
    this.looping = false,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoPicker(
      diameterRatio: diameterRatio,
      backgroundColor: backgroundColor,
      offAxisFraction: offAxisFraction,
      useMagnifier: useMagnifier,
      magnification: magnification,
      squeeze: squeeze,
      itemExtent: itemExtent,
      onSelectedItemChanged: onSelectedItemChanged,
      selectionOverlay: selectionOverlay,
      looping: looping,
      children: children,
    );
  }
}

/// Tom wrapper for [CupertinoSegmentedControl].
///
/// Classic (pre-sliding) Cupertino segmented control. Auth per segment.
class TomCupertinoSegmentedControl<T extends Object> extends TomSelectBase {
  final Map<T, Widget> children;
  final T? groupValue;
  final ValueChanged<T> onValueChanged;
  final Color? unselectedColor;
  final Color? selectedColor;
  final Color? borderColor;
  final Color? pressedColor;
  final EdgeInsetsGeometry? padding;

  const TomCupertinoSegmentedControl({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.children,
    this.groupValue,
    required this.onValueChanged,
    this.unselectedColor,
    this.selectedColor,
    this.borderColor,
    this.pressedColor,
    this.padding,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoSegmentedControl<T>(
      children: children,
      groupValue: groupValue,
      onValueChanged: onValueChanged,
      unselectedColor: unselectedColor,
      selectedColor: selectedColor,
      borderColor: borderColor,
      pressedColor: pressedColor,
      padding: padding,
    );
  }
}

/// Tom widget that EXTENDS [DropdownMenuItem] with authorization.
///
/// This widget IS a [DropdownMenuItem] — passes `is DropdownMenuItem<T>` checks.
/// Use this when you need type identity for DropdownButton itemBuilder.
///
/// ```dart
/// TomDropdownButton<String>(
///   items: [
///     TomDropdownMenuItem<String>(tomId: 'apple', value: 'apple', child: Text('Apple')),
///     TomDropdownMenuItem<String>(tomId: 'banana', value: 'banana', child: Text('Banana')),
///   ],
///   onChanged: (value) { ... },
/// )
/// ```
class TomDropdownMenuItem<T> extends DropdownMenuItem<T> with TomWidgetMixin {
  /// Creates a Tom DropdownMenuItem.
  const TomDropdownMenuItem({
    this.tomId,
    this.tomGroup,
    super.key,
    super.onTap,
    super.value,
    super.enabled,
    super.alignment,
    required super.child,
  });

  @override
  final String? tomId;

  @override
  final String? tomGroup;
}
