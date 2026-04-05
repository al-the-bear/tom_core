import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../groups/tom_ui_group.dart';
import '../../groups/tom_widget_mixin.dart';
import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_style_resolvers.dart';

/// Tom wrapper for [DropdownButton].
///
/// Adds ID, group, authorization, and resource resolution for hint label.
class TomDropdownButton<T> extends TomSelectBase {
  final T? value;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final VoidCallback? onTap;
  final int? elevation;
  final TextStyle? style;
  final Widget? underline;
  final Widget? icon;
  final Color? iconDisabledColor;
  final Color? iconEnabledColor;
  final double? iconSize;
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

  TomDropdownButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.value,
    this.items,
    this.onChanged,
    this.onTap,
    this.elevation,
    this.style,
    this.underline,
    this.icon,
    this.iconDisabledColor,
    this.iconEnabledColor,
    this.iconSize,
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
    final resolvedHint =
      hint ??
        resolveResourceOrNull('hint') ??
        (tomId != null ? resolveResourceOrFail('hint') : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedElevation =
        elevation ?? resolveIntOrNull('elevation') ?? 8;
    final resolvedIconDisabledColor =
        iconDisabledColor ?? resolveColorOrNull('iconDisabledColor');
    final resolvedIconEnabledColor =
        iconEnabledColor ?? resolveColorOrNull('iconEnabledColor');
    final resolvedIconSize =
        iconSize ?? resolveDoubleOrNull('iconSize') ?? 24.0;
    final resolvedItemHeight =
        itemHeight ?? resolveDoubleOrNull('itemHeight');
    final resolvedFocusColor =
        focusColor ?? resolveColorOrNull('focusColor');
    final resolvedDropdownColor =
        dropdownColor ?? resolveColorOrNull('dropdownColor');
    final resolvedMenuMaxHeight =
        menuMaxHeight ?? resolveDoubleOrNull('menuMaxHeight');
    final resolvedIsDense =
      resolveBoolOrNull('isDense') ?? isDense;
    final resolvedIsExpanded =
      resolveBoolOrNull('isExpanded') ?? isExpanded;
    final resolvedAutofocus =
      resolveBoolOrNull('autofocus') ?? autofocus;
    final resolvedEnableFeedback =
      enableFeedback ?? resolveBoolOrNull('enableFeedback');
    final resolvedAlignment =
      _resolveAlignment('alignment') ?? alignment;
    final resolvedPadding =
      padding ?? resolveEdgeInsetsOrNull('padding');

    // Phase 3: Resolve TextStyle from resources
    final resolvedStyle = style ?? _resolveTextStyle(context);

    return DropdownButton<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      onTap: onTap,
      elevation: resolvedElevation,
      style: resolvedStyle,
      underline: underline,
      icon: icon,
      iconDisabledColor: resolvedIconDisabledColor,
      iconEnabledColor: resolvedIconEnabledColor,
      iconSize: resolvedIconSize,
      isDense: resolvedIsDense,
      isExpanded: resolvedIsExpanded,
      itemHeight: resolvedItemHeight,
      focusColor: resolvedFocusColor,
      focusNode: focusNode,
      autofocus: resolvedAutofocus,
      dropdownColor: resolvedDropdownColor,
      menuMaxHeight: resolvedMenuMaxHeight,
      enableFeedback: resolvedEnableFeedback,
      alignment: resolvedAlignment,
      borderRadius: borderRadius ?? _resolveBorderRadius('borderRadius'),
      padding: resolvedPadding,
      hint: resolvedHint != null ? Text(resolvedHint) : null,
    );
  }

  /// Phase 3: Resolves TextStyle from resources.
  TextStyle? _resolveTextStyle(BuildContext context) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, 'style');
  }

  BorderRadius? _resolveBorderRadius(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderRadius(basePath!, suffix);
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
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
  final Offset? offset;
  final bool enabled;
  final ShapeBorder? shape;
  final Color? color;
  final bool? enableFeedback;
  final BoxConstraints? constraints;
  final PopupMenuPosition? position;
  final Clip clipBehavior;

  TomPopupMenuButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
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
    this.offset,
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
    final resolvedTooltip = tooltip ?? resolveResourceOrFail('tooltip');

    // Phase 2: Resolve optional parameters from resources
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedSurfaceTintColor =
        surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    final resolvedPadding =
      resolveEdgeInsetsOrNull('padding') ?? padding;
    final resolvedIconSize =
        iconSize ?? resolveDoubleOrNull('iconSize');
    final resolvedEnabled =
      resolveBoolOrNull('enabled') ?? enabled;
    final resolvedColor =
        color ?? resolveColorOrNull('color');
    final resolvedEnableFeedback =
      enableFeedback ?? resolveBoolOrNull('enableFeedback');

    return PopupMenuButton<T>(
      itemBuilder: itemBuilder,
      initialValue: initialValue,
      onSelected: onSelected,
      onCanceled: onCanceled,
      tooltip: resolvedTooltip,
      elevation: resolvedElevation,
      shadowColor: resolvedShadowColor,
      surfaceTintColor: resolvedSurfaceTintColor,
      padding: resolvedPadding,
      icon: icon,
      iconSize: resolvedIconSize,
      offset: offset ?? _resolveOffset('offset') ?? Offset.zero,
      enabled: resolvedEnabled,
      shape: shape ?? _resolveShapeBorder('shape'),
      color: resolvedColor,
      enableFeedback: resolvedEnableFeedback,
      constraints: constraints ?? _resolveBoxConstraints('constraints'),
      position: position,
      clipBehavior: clipBehavior,
      child: child,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }

  BoxConstraints? _resolveBoxConstraints(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBoxConstraints(basePath!, suffix);
  }

  Offset? _resolveOffset(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveOffset(basePath!, suffix);
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

  TomDropdownMenu({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
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
      label ??
        resolveResourceOrNull('label') ??
        resolveResourceOrFail('label');
    final resolvedHint =
      hintText ??
        resolveResourceOrNull('hintText') ??
        resolveResourceOrNull('hint') ??
        (tomId != null ? resolveResourceOrFail('hint') : null);
    final resolvedHelperText =
      helperText ?? resolveResourceOrNull('helperText');
    final resolvedErrorText =
      errorText ?? resolveResourceOrNull('errorText');

    // Phase 2: Resolve optional parameters from resources
    final resolvedEnabled =
      resolveBoolOrNull('enabled') ?? enabled;
    final resolvedWidth =
        width ?? resolveDoubleOrNull('width');
    final resolvedMenuHeight =
        menuHeight ?? resolveDoubleOrNull('menuHeight');
    final resolvedEnableFilter =
      resolveBoolOrNull('enableFilter') ?? enableFilter;
    final resolvedEnableSearch =
      resolveBoolOrNull('enableSearch') ?? enableSearch;
    final resolvedExpandedInsets =
      expandedInsets ?? resolveEdgeInsetsOrNull('expandedInsets');
    final resolvedRequestFocusOnTap =
      resolveBoolOrNull('requestFocusOnTap') ?? requestFocusOnTap;

    return DropdownMenu<T>(
      initialSelection: initialSelection,
      onSelected: onSelected,
      dropdownMenuEntries: dropdownMenuEntries,
      enabled: resolvedEnabled,
      width: resolvedWidth,
      menuHeight: resolvedMenuHeight,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      label: Text(resolvedLabel),
      hintText: resolvedHint,
      helperText: resolvedHelperText,
      errorText: resolvedErrorText,
      selectedTrailingIcon: selectedTrailingIcon,
      enableFilter: resolvedEnableFilter,
      enableSearch: resolvedEnableSearch,
      textStyle: textStyle ?? _resolveTextStyle(context),
      textAlign: textAlign,
      inputDecorationTheme: inputDecorationTheme,
      menuStyle: menuStyle ?? _resolveMenuStyle(context),
      controller: controller,
      focusNode: focusNode,
      requestFocusOnTap: resolvedRequestFocusOnTap,
      expandedInsets: resolvedExpandedInsets,
      searchCallback: searchCallback,
    );
  }

  /// Phase 3: Resolves TextStyle from resources.
  TextStyle? _resolveTextStyle(BuildContext context) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, 'textStyle');
  }

  /// Phase 3: Resolves MenuStyle from resources.
  MenuStyle? _resolveMenuStyle(BuildContext context) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveMenuStyle(basePath!, 'menuStyle');
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

  TomMenuAnchor({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
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
    final resolvedAlignmentOffset =
        alignmentOffset ?? _resolveOffset('alignmentOffset');
    final resolvedConsumeOutsideTap =
        resolveBoolOrNull('consumeOutsideTap') ?? consumeOutsideTap;

    return MenuAnchor(
      menuChildren: menuChildren,
      controller: controller,
      childFocusNode: childFocusNode,
      style: style ?? _resolveMenuStyle(context),
      alignmentOffset: resolvedAlignmentOffset,
      clipBehavior: clipBehavior,
      onOpen: onOpen,
      onClose: onClose,
      consumeOutsideTap: resolvedConsumeOutsideTap,
      builder: builder,
      child: child,
    );
  }

  /// Phase 3: Resolves MenuStyle from resources.
  MenuStyle? _resolveMenuStyle(BuildContext context) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveMenuStyle(basePath!, 'style');
  }

  Offset? _resolveOffset(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveOffset(basePath!, suffix);
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
  final int? elevation;
  final TextStyle? style;
  final Widget? icon;
  final Color? iconDisabledColor;
  final Color? iconEnabledColor;
  final double? iconSize;
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

  TomDropdownButtonFormField({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.items,
    this.value,
    this.onChanged,
    this.onTap,
    this.decoration,
    this.hint,
    this.disabledHint,
    this.elevation,
    this.style,
    this.icon,
    this.iconDisabledColor,
    this.iconEnabledColor,
    this.iconSize,
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
    final resolvedLabel = resolveResourceOrFail('label');
    // Phase 3: Resolve InputDecoration from resources
    final effectiveDecoration =
      decoration ?? _resolveInputDecoration(context) ?? InputDecoration(labelText: resolvedLabel);

    // Phase 2: Resolve optional parameters from resources
    final resolvedElevation =
        elevation ?? resolveIntOrNull('elevation') ?? 8;
    final resolvedIconDisabledColor =
        iconDisabledColor ?? resolveColorOrNull('iconDisabledColor');
    final resolvedIconEnabledColor =
        iconEnabledColor ?? resolveColorOrNull('iconEnabledColor');
    final resolvedIconSize =
        iconSize ?? resolveDoubleOrNull('iconSize') ?? 24.0;
    final resolvedItemHeight =
        itemHeight ?? resolveDoubleOrNull('itemHeight');
    final resolvedFocusColor =
        focusColor ?? resolveColorOrNull('focusColor');
    final resolvedDropdownColor =
        dropdownColor ?? resolveColorOrNull('dropdownColor');
    final resolvedMenuMaxHeight =
        menuMaxHeight ?? resolveDoubleOrNull('menuMaxHeight');
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding');
    final resolvedIsDense =
      resolveBoolOrNull('isDense') ?? isDense;
    final resolvedIsExpanded =
      resolveBoolOrNull('isExpanded') ?? isExpanded;
    final resolvedAutofocus =
      resolveBoolOrNull('autofocus') ?? autofocus;
    final resolvedEnableFeedback =
      enableFeedback ?? resolveBoolOrNull('enableFeedback');
    final resolvedAlignment =
      _resolveAlignment('alignment') ?? alignment;

    // Phase 3: Resolve TextStyle from resources
    final resolvedStyle = style ?? _resolveTextStyle(context);

    return DropdownButtonFormField<T>(
      items: items,
      value: value,
      onChanged: onChanged,
      onTap: onTap,
      decoration: effectiveDecoration,
      hint: hint,
      disabledHint: disabledHint,
      elevation: resolvedElevation,
      style: resolvedStyle,
      icon: icon,
      iconDisabledColor: resolvedIconDisabledColor,
      iconEnabledColor: resolvedIconEnabledColor,
      iconSize: resolvedIconSize,
      isDense: resolvedIsDense,
      isExpanded: resolvedIsExpanded,
      itemHeight: resolvedItemHeight,
      focusColor: resolvedFocusColor,
      focusNode: focusNode,
      autofocus: resolvedAutofocus,
      dropdownColor: resolvedDropdownColor,
      padding: resolvedPadding,
      menuMaxHeight: resolvedMenuMaxHeight,
      enableFeedback: resolvedEnableFeedback,
      alignment: resolvedAlignment,
      borderRadius: borderRadius ?? _resolveBorderRadius('borderRadius'),
      onSaved: onSaved,
      validator: validator,
      autovalidateMode: autovalidateMode,
    );
  }

  /// Phase 3: Resolves TextStyle from resources.
  TextStyle? _resolveTextStyle(BuildContext context) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, 'style');
  }

  /// Phase 3: Resolves InputDecoration from resources.
  InputDecoration? _resolveInputDecoration(BuildContext context) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveInputDecoration(basePath!, 'decoration');
  }

  BorderRadius? _resolveBorderRadius(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderRadius(basePath!, suffix);
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
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
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  TomCupertinoSlidingSegmentedControl({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.children,
    required this.groupValue,
    required this.onValueChanged,
    this.thumbColor,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedThumbColor =
        thumbColor ?? resolveColorOrNull('thumbColor');
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding') ?? const EdgeInsets.symmetric(vertical: 2, horizontal: 3);

    final effectiveBg = resolvedBackgroundColor ??
        CupertinoDynamicColor.resolve(
          CupertinoColors.tertiarySystemFill, context);
    final effectiveThumb = resolvedThumbColor ??
        CupertinoDynamicColor.resolve(
          CupertinoColors.white, context);

    return CupertinoSlidingSegmentedControl<T>(
      children: children,
      groupValue: groupValue,
      onValueChanged: onValueChanged,
      thumbColor: effectiveThumb,
      padding: resolvedPadding,
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
  TomPopupMenuItem({
    this.tomId,
    this.tomGroup,
    this.scope,
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
  }) : basePath = TomCtr.resolvePath(tomId, scope) {
    tomGroup?.register(this);
  }

  @override
  final String? tomId;

  @override
  final TomUIGroup? tomGroup;

  @override
  final TomScope? scope;

  @override
  final String? basePath;

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
    final hidden = widget.checkHidden();
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
  TomPopupMenuDivider({
    this.tomId,
    this.tomGroup,
    this.scope,
    super.key,
    super.height,
  }) : basePath = TomCtr.resolvePath(tomId, scope) {
    tomGroup?.register(this);
  }

  @override
  final String? tomId;

  @override
  final TomUIGroup? tomGroup;

  @override
  final TomScope? scope;

  @override
  final String? basePath;

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
    final hidden = widgetMixin.checkHidden();
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
  TomCheckedPopupMenuItem({
    this.tomId,
    this.tomGroup,
    this.scope,
    super.key,
    super.value,
    super.checked,
    super.enabled,
    super.padding,
    super.height,
    super.labelTextStyle,
    super.mouseCursor,
    super.child,
  }) : basePath = TomCtr.resolvePath(tomId, scope) {
    tomGroup?.register(this);
  }

  @override
  final String? tomId;

  @override
  final TomUIGroup? tomGroup;

  @override
  final TomScope? scope;

  @override
  final String? basePath;

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
    final hidden = widgetMixin.checkHidden();
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
  final double? diameterRatio;
  final Color? backgroundColor;
  final double? offAxisFraction;
  final bool useMagnifier;
  final double? magnification;
  final double? squeeze;
  final double? itemExtent;
  final ValueChanged<int> onSelectedItemChanged;
  final List<Widget> children;
  final Widget? selectionOverlay;
  final bool looping;

  TomCupertinoPicker({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.diameterRatio,
    this.backgroundColor,
    this.offAxisFraction,
    this.useMagnifier = false,
    this.magnification,
    this.squeeze,
    this.itemExtent,
    required this.onSelectedItemChanged,
    required this.children,
    this.selectionOverlay = const CupertinoPickerDefaultSelectionOverlay(),
    this.looping = false,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoPicker(
      diameterRatio: diameterRatio ?? resolveDoubleOrNull('diameterRatio') ?? 1.07,
      backgroundColor: backgroundColor ?? resolveColorOrNull('backgroundColor'),
      offAxisFraction: offAxisFraction ?? resolveDoubleOrNull('offAxisFraction') ?? 0.0,
      useMagnifier: useMagnifier,
      magnification: magnification ?? resolveDoubleOrNull('magnification') ?? 1.0,
      squeeze: squeeze ?? resolveDoubleOrNull('squeeze') ?? 1.45,
      itemExtent: itemExtent ?? resolveDoubleOrNull('itemExtent') ?? 32.0,
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

  TomCupertinoSegmentedControl({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
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
      unselectedColor: unselectedColor ?? resolveColorOrNull('unselectedColor'),
      selectedColor: selectedColor ?? resolveColorOrNull('selectedColor'),
      borderColor: borderColor ?? resolveColorOrNull('borderColor'),
      pressedColor: pressedColor ?? resolveColorOrNull('pressedColor'),
      padding: padding ?? resolveEdgeInsetsOrNull('padding'),
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
  TomDropdownMenuItem({
    this.tomId,
    this.tomGroup,
    this.scope,
    super.key,
    super.onTap,
    super.value,
    super.enabled,
    super.alignment,
    required super.child,
  }) : basePath = TomCtr.resolvePath(tomId, scope) {
    tomGroup?.register(this);
  }

  @override
  final String? tomId;

  @override
  final TomUIGroup? tomGroup;

  @override
  final TomScope? scope;

  @override
  final String? basePath;
}
