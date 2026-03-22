import 'package:flutter/material.dart';

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
    final resolvedTooltip = tooltip ?? (tomId != null ? resolveResource(context, 'tooltip') : null);

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
    final resolvedLabel =
        label ?? (tomId != null ? resolveResource(context, 'label') : null);
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
      label: resolvedLabel != null ? Text(resolvedLabel) : null,
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
