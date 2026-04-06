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

  // Pre-resolved resource values
  late final String? _resolvedHint;
  late final int _resolvedElevation;
  late final Color? _resolvedIconDisabledColor;
  late final Color? _resolvedIconEnabledColor;
  late final double _resolvedIconSize;
  late final double? _resolvedItemHeight;
  late final Color? _resolvedFocusColor;
  late final Color? _resolvedDropdownColor;
  late final double? _resolvedMenuMaxHeight;
  late final bool _resolvedIsDense;
  late final bool _resolvedIsExpanded;
  late final bool _resolvedAutofocus;
  late final bool? _resolvedEnableFeedback;
  late final AlignmentGeometry _resolvedAlignment;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final TextStyle? _resolvedStyle;
  late final BorderRadius? _resolvedBorderRadius;

  TomDropdownButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.value,
    this.items,
    ValueChanged<T?>? onChanged,
    VoidCallback? onTap,
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
  })  : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged),
        onTap = InScopeBuilder(scope: scope).wrap0n(onTap) {
    _resolvedHint = hint ?? resolveResourceOrNull('hint') ?? (tomId != null ? resolveResourceOrFail('hint') : null);
    _resolvedElevation = elevation ?? resolveIntOrNull('elevation') ?? 8;
    _resolvedIconDisabledColor = iconDisabledColor ?? resolveColorOrNull('iconDisabledColor');
    _resolvedIconEnabledColor = iconEnabledColor ?? resolveColorOrNull('iconEnabledColor');
    _resolvedIconSize = iconSize ?? resolveDoubleOrNull('iconSize') ?? 24.0;
    _resolvedItemHeight = itemHeight ?? resolveDoubleOrNull('itemHeight');
    _resolvedFocusColor = focusColor ?? resolveColorOrNull('focusColor');
    _resolvedDropdownColor = dropdownColor ?? resolveColorOrNull('dropdownColor');
    _resolvedMenuMaxHeight = menuMaxHeight ?? resolveDoubleOrNull('menuMaxHeight');
    _resolvedIsDense = resolveBoolOrNull('isDense') ?? isDense;
    _resolvedIsExpanded = resolveBoolOrNull('isExpanded') ?? isExpanded;
    _resolvedAutofocus = resolveBoolOrNull('autofocus') ?? autofocus;
    _resolvedEnableFeedback = enableFeedback ?? resolveBoolOrNull('enableFeedback');
    _resolvedAlignment = _resolveAlignment('alignment') ?? alignment;
    _resolvedPadding = padding ?? resolveEdgeInsetsOrNull('padding');
    _resolvedStyle = style ?? _resolveTextStyle();
    _resolvedBorderRadius = borderRadius ?? _resolveBorderRadius('borderRadius');
  }

  @override
  Widget buildContent(BuildContext context) {
    return DropdownButton<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      onTap: onTap,
      elevation: _resolvedElevation,
      style: _resolvedStyle,
      underline: underline,
      icon: icon,
      iconDisabledColor: _resolvedIconDisabledColor,
      iconEnabledColor: _resolvedIconEnabledColor,
      iconSize: _resolvedIconSize,
      isDense: _resolvedIsDense,
      isExpanded: _resolvedIsExpanded,
      itemHeight: _resolvedItemHeight,
      focusColor: _resolvedFocusColor,
      focusNode: focusNode,
      autofocus: _resolvedAutofocus,
      dropdownColor: _resolvedDropdownColor,
      menuMaxHeight: _resolvedMenuMaxHeight,
      enableFeedback: _resolvedEnableFeedback,
      alignment: _resolvedAlignment,
      borderRadius: _resolvedBorderRadius,
      padding: _resolvedPadding,
      hint: _resolvedHint != null ? Text(_resolvedHint) : null,
    );
  }

  /// Phase 3: Resolves TextStyle from resources.
  TextStyle? _resolveTextStyle() {
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

  // Pre-resolved resource values
  late final String _resolvedTooltip;
  late final double? _resolvedElevation;
  late final Color? _resolvedShadowColor;
  late final Color? _resolvedSurfaceTintColor;
  late final EdgeInsetsGeometry _resolvedPadding;
  late final double? _resolvedIconSize;
  late final bool _resolvedEnabled;
  late final Color? _resolvedColor;
  late final bool? _resolvedEnableFeedback;
  late final ShapeBorder? _resolvedShape;
  late final BoxConstraints? _resolvedConstraints;
  late final Offset _resolvedOffset;

  TomPopupMenuButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required PopupMenuItemBuilder<T> itemBuilder,
    this.initialValue,
    PopupMenuItemSelected<T>? onSelected,
    PopupMenuCanceled? onCanceled,
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
  }) : onSelected = InScopeBuilder(scope: scope).wrap1n(onSelected),
       onCanceled = InScopeBuilder(scope: scope).wrap0n(onCanceled),
       itemBuilder = InScopeBuilder(scope: scope).wrap1(itemBuilder) {
    _resolvedTooltip = tooltip ?? resolveResourceOrFail('tooltip');
    _resolvedElevation = elevation ?? resolveDoubleOrNull('elevation');
    _resolvedShadowColor = shadowColor ?? resolveColorOrNull('shadowColor');
    _resolvedSurfaceTintColor = surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    _resolvedPadding = resolveEdgeInsetsOrNull('padding') ?? padding;
    _resolvedIconSize = iconSize ?? resolveDoubleOrNull('iconSize');
    _resolvedEnabled = resolveBoolOrNull('enabled') ?? enabled;
    _resolvedColor = color ?? resolveColorOrNull('color');
    _resolvedEnableFeedback = enableFeedback ?? resolveBoolOrNull('enableFeedback');
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
    _resolvedConstraints = constraints ?? _resolveBoxConstraints('constraints');
    _resolvedOffset = offset ?? _resolveOffset('offset') ?? Offset.zero;
  }

  @override
  Widget buildContent(BuildContext context) {
    return PopupMenuButton<T>(
      itemBuilder: itemBuilder,
      initialValue: initialValue,
      onSelected: onSelected,
      onCanceled: onCanceled,
      tooltip: _resolvedTooltip,
      elevation: _resolvedElevation,
      shadowColor: _resolvedShadowColor,
      surfaceTintColor: _resolvedSurfaceTintColor,
      padding: _resolvedPadding,
      icon: icon,
      iconSize: _resolvedIconSize,
      offset: _resolvedOffset,
      enabled: _resolvedEnabled,
      shape: _resolvedShape,
      color: _resolvedColor,
      enableFeedback: _resolvedEnableFeedback,
      constraints: _resolvedConstraints,
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

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final String? _resolvedHint;
  late final String? _resolvedHelperText;
  late final String? _resolvedErrorText;
  late final bool _resolvedEnabled;
  late final double? _resolvedWidth;
  late final double? _resolvedMenuHeight;
  late final bool _resolvedEnableFilter;
  late final bool _resolvedEnableSearch;
  late final EdgeInsets? _resolvedExpandedInsets;
  late final bool _resolvedRequestFocusOnTap;
  late final TextStyle? _resolvedTextStyle;
  late final MenuStyle? _resolvedMenuStyle;

  TomDropdownMenu({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.initialSelection,
    ValueChanged<T?>? onSelected,
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
    SearchCallback<T>? searchCallback,
  })  : onSelected = InScopeBuilder(scope: scope).wrap1n(onSelected),
        searchCallback = InScopeBuilder(scope: scope).wrap2n(searchCallback) {
    _resolvedLabel = label ?? resolveResourceOrNull('label') ?? resolveResourceOrFail('label');
    _resolvedHint = hintText ?? resolveResourceOrNull('hintText') ?? resolveResourceOrNull('hint') ?? (tomId != null ? resolveResourceOrFail('hint') : null);
    _resolvedHelperText = helperText ?? resolveResourceOrNull('helperText');
    _resolvedErrorText = errorText ?? resolveResourceOrNull('errorText');
    _resolvedEnabled = resolveBoolOrNull('enabled') ?? enabled;
    _resolvedWidth = width ?? resolveDoubleOrNull('width');
    _resolvedMenuHeight = menuHeight ?? resolveDoubleOrNull('menuHeight');
    _resolvedEnableFilter = resolveBoolOrNull('enableFilter') ?? enableFilter;
    _resolvedEnableSearch = resolveBoolOrNull('enableSearch') ?? enableSearch;
    _resolvedExpandedInsets = expandedInsets ?? resolveEdgeInsetsOrNull('expandedInsets');
    _resolvedRequestFocusOnTap = resolveBoolOrNull('requestFocusOnTap') ?? requestFocusOnTap;
    _resolvedTextStyle = textStyle ?? _resolveTextStyle();
    _resolvedMenuStyle = menuStyle ?? _resolveMenuStyle();
  }

  @override
  Widget buildContent(BuildContext context) {
    return DropdownMenu<T>(
      initialSelection: initialSelection,
      onSelected: onSelected,
      dropdownMenuEntries: dropdownMenuEntries,
      enabled: _resolvedEnabled,
      width: _resolvedWidth,
      menuHeight: _resolvedMenuHeight,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      label: Text(_resolvedLabel),
      hintText: _resolvedHint,
      helperText: _resolvedHelperText,
      errorText: _resolvedErrorText,
      selectedTrailingIcon: selectedTrailingIcon,
      enableFilter: _resolvedEnableFilter,
      enableSearch: _resolvedEnableSearch,
      textStyle: _resolvedTextStyle,
      textAlign: textAlign,
      inputDecorationTheme: inputDecorationTheme,
      menuStyle: _resolvedMenuStyle,
      controller: controller,
      focusNode: focusNode,
      requestFocusOnTap: _resolvedRequestFocusOnTap,
      expandedInsets: _resolvedExpandedInsets,
      searchCallback: searchCallback,
    );
  }

  /// Phase 3: Resolves TextStyle from resources.
  TextStyle? _resolveTextStyle() {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, 'textStyle');
  }

  /// Phase 3: Resolves MenuStyle from resources.
  MenuStyle? _resolveMenuStyle() {
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

  // Pre-resolved resource values
  late final Offset? _resolvedAlignmentOffset;
  late final bool _resolvedConsumeOutsideTap;
  late final MenuStyle? _resolvedStyle;

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
    VoidCallback? onOpen,
    VoidCallback? onClose,
    this.consumeOutsideTap = false,
    Widget Function(BuildContext, MenuController, Widget?)? builder,
  }) : onOpen = InScopeBuilder(scope: scope).wrap0n(onOpen),
       onClose = InScopeBuilder(scope: scope).wrap0n(onClose),
       builder = builder != null
           ? InScopeBuilder(scope: scope).wrap3(builder)
           : null {
    _resolvedAlignmentOffset = alignmentOffset ?? _resolveOffset('alignmentOffset');
    _resolvedConsumeOutsideTap = resolveBoolOrNull('consumeOutsideTap') ?? consumeOutsideTap;
    _resolvedStyle = style ?? _resolveMenuStyle();
  }

  @override
  Widget buildContent(BuildContext context) {
    return MenuAnchor(
      menuChildren: menuChildren,
      controller: controller,
      childFocusNode: childFocusNode,
      style: _resolvedStyle,
      alignmentOffset: _resolvedAlignmentOffset,
      clipBehavior: clipBehavior,
      onOpen: onOpen,
      onClose: onClose,
      consumeOutsideTap: _resolvedConsumeOutsideTap,
      builder: builder,
      child: child,
    );
  }

  /// Phase 3: Resolves MenuStyle from resources.
  MenuStyle? _resolveMenuStyle() {
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

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final InputDecoration? _effectiveDecoration;
  late final int _resolvedElevation;
  late final Color? _resolvedIconDisabledColor;
  late final Color? _resolvedIconEnabledColor;
  late final double _resolvedIconSize;
  late final double? _resolvedItemHeight;
  late final Color? _resolvedFocusColor;
  late final Color? _resolvedDropdownColor;
  late final double? _resolvedMenuMaxHeight;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final bool _resolvedIsDense;
  late final bool _resolvedIsExpanded;
  late final bool _resolvedAutofocus;
  late final bool? _resolvedEnableFeedback;
  late final AlignmentGeometry _resolvedAlignment;
  late final TextStyle? _resolvedStyle;
  late final BorderRadius? _resolvedBorderRadius;

  TomDropdownButtonFormField({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.items,
    this.value,
    ValueChanged<T?>? onChanged,
    VoidCallback? onTap,
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
    FormFieldSetter<T>? onSaved,
    FormFieldValidator<T>? validator,
    this.autovalidateMode,
  })  : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged),
        onTap = InScopeBuilder(scope: scope).wrap0n(onTap),
        onSaved = InScopeBuilder(scope: scope).wrap1n(onSaved),
        validator = InScopeBuilder(scope: scope).wrap1n(validator) {
    _resolvedLabel = resolveResourceOrFail('label');
    _effectiveDecoration = decoration ?? _resolveInputDecoration() ?? InputDecoration(labelText: _resolvedLabel);
    _resolvedElevation = elevation ?? resolveIntOrNull('elevation') ?? 8;
    _resolvedIconDisabledColor = iconDisabledColor ?? resolveColorOrNull('iconDisabledColor');
    _resolvedIconEnabledColor = iconEnabledColor ?? resolveColorOrNull('iconEnabledColor');
    _resolvedIconSize = iconSize ?? resolveDoubleOrNull('iconSize') ?? 24.0;
    _resolvedItemHeight = itemHeight ?? resolveDoubleOrNull('itemHeight');
    _resolvedFocusColor = focusColor ?? resolveColorOrNull('focusColor');
    _resolvedDropdownColor = dropdownColor ?? resolveColorOrNull('dropdownColor');
    _resolvedMenuMaxHeight = menuMaxHeight ?? resolveDoubleOrNull('menuMaxHeight');
    _resolvedPadding = padding ?? resolveEdgeInsetsOrNull('padding');
    _resolvedIsDense = resolveBoolOrNull('isDense') ?? isDense;
    _resolvedIsExpanded = resolveBoolOrNull('isExpanded') ?? isExpanded;
    _resolvedAutofocus = resolveBoolOrNull('autofocus') ?? autofocus;
    _resolvedEnableFeedback = enableFeedback ?? resolveBoolOrNull('enableFeedback');
    _resolvedAlignment = _resolveAlignment('alignment') ?? alignment;
    _resolvedStyle = style ?? _resolveTextStyle();
    _resolvedBorderRadius = borderRadius ?? _resolveBorderRadius('borderRadius');
  }

  @override
  Widget buildContent(BuildContext context) {
    return DropdownButtonFormField<T>(
      items: items,
      value: value,
      onChanged: onChanged,
      onTap: onTap,
      decoration: _effectiveDecoration,
      hint: hint,
      disabledHint: disabledHint,
      elevation: _resolvedElevation,
      style: _resolvedStyle,
      icon: icon,
      iconDisabledColor: _resolvedIconDisabledColor,
      iconEnabledColor: _resolvedIconEnabledColor,
      iconSize: _resolvedIconSize,
      isDense: _resolvedIsDense,
      isExpanded: _resolvedIsExpanded,
      itemHeight: _resolvedItemHeight,
      focusColor: _resolvedFocusColor,
      focusNode: focusNode,
      autofocus: _resolvedAutofocus,
      dropdownColor: _resolvedDropdownColor,
      padding: _resolvedPadding,
      menuMaxHeight: _resolvedMenuMaxHeight,
      enableFeedback: _resolvedEnableFeedback,
      alignment: _resolvedAlignment,
      borderRadius: _resolvedBorderRadius,
      onSaved: onSaved,
      validator: validator,
      autovalidateMode: autovalidateMode,
    );
  }

  /// Phase 3: Resolves TextStyle from resources.
  TextStyle? _resolveTextStyle() {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, 'style');
  }

  /// Phase 3: Resolves InputDecoration from resources.
  InputDecoration? _resolveInputDecoration() {
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

  // Pre-resolved resource values
  late final Color? _resolvedBackgroundColor;
  late final Color? _resolvedThumbColor;
  late final EdgeInsetsGeometry _resolvedPadding;

  TomCupertinoSlidingSegmentedControl({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.children,
    required this.groupValue,
    required ValueChanged<T?> onValueChanged,
    this.thumbColor,
    this.padding,
    this.backgroundColor,
  })  : onValueChanged = InScopeBuilder(scope: scope).wrap1(onValueChanged) {
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
    _resolvedThumbColor = thumbColor ?? resolveColorOrNull('thumbColor');
    _resolvedPadding = padding ?? resolveEdgeInsetsOrNull('padding') ?? const EdgeInsets.symmetric(vertical: 2, horizontal: 3);
  }

  @override
  Widget buildContent(BuildContext context) {
    final effectiveBg = _resolvedBackgroundColor ??
        CupertinoDynamicColor.resolve(
          CupertinoColors.tertiarySystemFill, context);
    final effectiveThumb = _resolvedThumbColor ??
        CupertinoDynamicColor.resolve(
          CupertinoColors.white, context);

    return CupertinoSlidingSegmentedControl<T>(
      children: children,
      groupValue: groupValue,
      onValueChanged: onValueChanged,
      thumbColor: effectiveThumb,
      padding: _resolvedPadding,
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

  // Pre-resolved resource values
  late final double? _resolvedDiameterRatio;
  late final Color? _resolvedBackgroundColor;
  late final double? _resolvedOffAxisFraction;
  late final double? _resolvedMagnification;
  late final double? _resolvedSqueeze;
  late final double? _resolvedItemExtent;

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
    required ValueChanged<int> onSelectedItemChanged,
    required this.children,
    this.selectionOverlay = const CupertinoPickerDefaultSelectionOverlay(),
    this.looping = false,
  })  : onSelectedItemChanged = InScopeBuilder(scope: scope).wrap1(onSelectedItemChanged) {
    _resolvedDiameterRatio = diameterRatio ?? resolveDoubleOrNull('diameterRatio');
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
    _resolvedOffAxisFraction = offAxisFraction ?? resolveDoubleOrNull('offAxisFraction');
    _resolvedMagnification = magnification ?? resolveDoubleOrNull('magnification');
    _resolvedSqueeze = squeeze ?? resolveDoubleOrNull('squeeze');
    _resolvedItemExtent = itemExtent ?? resolveDoubleOrNull('itemExtent');
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoPicker(
      diameterRatio: _resolvedDiameterRatio ?? 1.07,
      backgroundColor: _resolvedBackgroundColor,
      offAxisFraction: _resolvedOffAxisFraction ?? 0.0,
      useMagnifier: useMagnifier,
      magnification: _resolvedMagnification ?? 1.0,
      squeeze: _resolvedSqueeze ?? 1.45,
      itemExtent: _resolvedItemExtent ?? 32.0,
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

  // Pre-resolved resource values
  late final Color? _resolvedUnselectedColor;
  late final Color? _resolvedSelectedColor;
  late final Color? _resolvedBorderColor;
  late final Color? _resolvedPressedColor;
  late final EdgeInsetsGeometry? _resolvedPadding;

  TomCupertinoSegmentedControl({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.children,
    this.groupValue,
    required ValueChanged<T> onValueChanged,
    this.unselectedColor,
    this.selectedColor,
    this.borderColor,
    this.pressedColor,
    this.padding,
  })  : onValueChanged = InScopeBuilder(scope: scope).wrap1(onValueChanged) {
    _resolvedUnselectedColor = unselectedColor ?? resolveColorOrNull('unselectedColor');
    _resolvedSelectedColor = selectedColor ?? resolveColorOrNull('selectedColor');
    _resolvedBorderColor = borderColor ?? resolveColorOrNull('borderColor');
    _resolvedPressedColor = pressedColor ?? resolveColorOrNull('pressedColor');
    _resolvedPadding = padding ?? resolveEdgeInsetsOrNull('padding');
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoSegmentedControl<T>(
      children: children,
      groupValue: groupValue,
      onValueChanged: onValueChanged,
      unselectedColor: _resolvedUnselectedColor,
      selectedColor: _resolvedSelectedColor,
      borderColor: _resolvedBorderColor,
      pressedColor: _resolvedPressedColor,
      padding: _resolvedPadding,
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
