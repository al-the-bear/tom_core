import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_style_resolvers.dart';

/// Tom wrapper for [Text].
///
/// Provides optional [text] parameter and resource resolution
/// when [text] is not provided.
class TomText extends TomLabelBase {
  /// The text to display. When omitted, resolves from Tom resources.
  final String? text;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;

  /// Creates a TomText widget.
  ///
  /// ```dart
  /// TomText(text: 'Hello')         // Explicit text
  /// TomText(tomId: 'app.greeting')  // Resolves from resources
  /// ```
  // Pre-resolved resource values
  late final String _resolvedText;
  late final int? _resolvedMaxLines;
  late final bool? _resolvedSoftWrap;
  late final String? _resolvedSemanticsLabel;
  late final TextStyle? _resolvedStyle;
  late final StrutStyle? _resolvedStrutStyle;
  late final TextHeightBehavior? _resolvedTextHeightBehavior;

  TomText({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.text,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
  }) {
    _resolvedText = text ?? resolveResourceOrFail('label');
    _resolvedMaxLines = maxLines ?? resolveIntOrNull('maxLines');
    _resolvedSoftWrap = softWrap ?? resolveBoolOrNull('softWrap');
    _resolvedSemanticsLabel = semanticsLabel ?? resolveResourceOrNull('semanticsLabel');
    _resolvedStyle = style ?? _resolveTextStyle('style');
    _resolvedStrutStyle = strutStyle ?? _resolveStrutStyle('strutStyle');
    _resolvedTextHeightBehavior = textHeightBehavior ?? _resolveTextHeightBehavior('textHeightBehavior');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Text(
      _resolvedText,
      style: _resolvedStyle,
      strutStyle: _resolvedStrutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: _resolvedSoftWrap,
      overflow: overflow,
      maxLines: _resolvedMaxLines,
      semanticsLabel: _resolvedSemanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: _resolvedTextHeightBehavior,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  StrutStyle? _resolveStrutStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveStrutStyle(basePath!, suffix);
  }

  TextHeightBehavior? _resolveTextHeightBehavior(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextHeightBehavior(basePath!, suffix);
  }
}

/// Tom wrapper for [SelectableText].
///
/// Provides optional [text] parameter and resource resolution
/// when [text] is not provided.
///
/// ```dart
/// TomSelectableText(text: 'Hello')         // Explicit text
/// TomSelectableText(tomId: 'app.greeting')  // Resolves from resources
/// ```
class TomSelectableText extends TomLabelBase {
  /// The text to display. When omitted, resolves from Tom resources.
  final String? text;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool showCursor;
  final int? minLines;
  final double cursorWidth;
  final double? cursorHeight;
  final Radius? cursorRadius;
  final Color? cursorColor;
  final DragStartBehavior? dragStartBehavior;
  final VoidCallback? onTap;
  final ScrollPhysics? scrollPhysics;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final TextMagnifierConfiguration? magnifierConfiguration;
  final TextSelectionControls? selectionControls;
  final SelectionChangedCallback? onSelectionChanged;

  /// Creates a TomSelectableText widget.
  ///
  /// ```dart
  /// TomSelectableText(text: 'Hello')         // Explicit text
  /// TomSelectableText(tomId: 'app.greeting')  // Resolves from resources
  /// ```
  // Pre-resolved resource values
  late final String _resolvedText;
  late final Color? _resolvedCursorColor;
  late final int? _resolvedMaxLines;
  late final int? _resolvedMinLines;
  late final bool _resolvedAutofocus;
  late final bool _resolvedShowCursor;
  late final double _resolvedCursorWidth;
  late final double? _resolvedCursorHeight;
  late final String? _resolvedSemanticsLabel;
  late final TextStyle? _resolvedStyle;
  late final ScrollPhysics? _resolvedScrollPhysics;
  late final StrutStyle? _resolvedStrutStyle;
  late final TextHeightBehavior? _resolvedTextHeightBehavior;

  TomSelectableText({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.text,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.maxLines,
    this.focusNode,
    this.autofocus = false,
    this.showCursor = false,
    this.minLines,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.dragStartBehavior,
    this.onTap,
    this.scrollPhysics,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.contextMenuBuilder,
    this.magnifierConfiguration,
    this.selectionControls,
    this.onSelectionChanged,
  }) {
    _resolvedText = text ?? resolveResourceOrFail('label');
    _resolvedCursorColor = cursorColor ?? resolveColorOrNull('cursorColor');
    _resolvedMaxLines = maxLines ?? resolveIntOrNull('maxLines');
    _resolvedMinLines = minLines ?? resolveIntOrNull('minLines');
    _resolvedAutofocus = resolveBoolOrNull('autofocus') ?? autofocus;
    _resolvedShowCursor = resolveBoolOrNull('showCursor') ?? showCursor;
    _resolvedCursorWidth = resolveDoubleOrNull('cursorWidth') ?? cursorWidth;
    _resolvedCursorHeight = cursorHeight ?? resolveDoubleOrNull('cursorHeight');
    _resolvedSemanticsLabel = semanticsLabel ?? resolveResourceOrNull('semanticsLabel');
    _resolvedStyle = style ?? _resolveTextStyle('style');
    _resolvedScrollPhysics = scrollPhysics ?? _resolveScrollPhysics('scrollPhysics');
    _resolvedStrutStyle = strutStyle ?? _resolveStrutStyle('strutStyle');
    _resolvedTextHeightBehavior = textHeightBehavior ?? _resolveTextHeightBehavior('textHeightBehavior');
  }

  @override
  Widget buildContent(BuildContext context) {
    return SelectableText(
      _resolvedText,
      style: _resolvedStyle,
      strutStyle: _resolvedStrutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: _resolvedMaxLines,
      focusNode: focusNode,
      autofocus: _resolvedAutofocus,
      showCursor: _resolvedShowCursor,
      minLines: _resolvedMinLines,
      cursorWidth: _resolvedCursorWidth,
      cursorHeight: _resolvedCursorHeight,
      cursorRadius: cursorRadius,
      cursorColor: _resolvedCursorColor,
      onTap: onTap,
      scrollPhysics: _resolvedScrollPhysics,
      semanticsLabel: _resolvedSemanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: _resolvedTextHeightBehavior,
      contextMenuBuilder: contextMenuBuilder,
      magnifierConfiguration: magnifierConfiguration,
      selectionControls: selectionControls,
      onSelectionChanged: onSelectionChanged,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  StrutStyle? _resolveStrutStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveStrutStyle(basePath!, suffix);
  }

  TextHeightBehavior? _resolveTextHeightBehavior(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextHeightBehavior(basePath!, suffix);
  }

  ScrollPhysics? _resolveScrollPhysics(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveScrollPhysics(basePath!, suffix);
  }
}

/// Tom wrapper for [RichText].
///
/// Adds ID, group, and authorization.
class TomRichText extends TomLabelBase {
  final InlineSpan text;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final bool softWrap;
  final TextOverflow overflow;
  final int? maxLines;
  final Locale? locale;
  final StrutStyle? strutStyle;
  final TextWidthBasis textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final SelectionRegistrar? selectionRegistrar;
  final Color? selectionColor;

  // Pre-resolved resource values
  late final int? _resolvedMaxLines;
  late final Color? _resolvedSelectionColor;
  late final bool _resolvedSoftWrap;
  late final StrutStyle? _resolvedStrutStyle;
  late final TextHeightBehavior? _resolvedTextHeightBehavior;

  TomRichText({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.text,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.maxLines,
    this.locale,
    this.strutStyle,
    this.textWidthBasis = TextWidthBasis.parent,
    this.textHeightBehavior,
    this.selectionRegistrar,
    this.selectionColor,
  }) {
    _resolvedMaxLines = maxLines ?? resolveIntOrNull('maxLines');
    _resolvedSelectionColor = selectionColor ?? resolveColorOrNull('selectionColor');
    _resolvedSoftWrap = resolveBoolOrNull('softWrap') ?? softWrap;
    _resolvedStrutStyle = strutStyle ?? _resolveStrutStyle('strutStyle');
    _resolvedTextHeightBehavior = textHeightBehavior ?? _resolveTextHeightBehavior('textHeightBehavior');
  }

  @override
  Widget buildContent(BuildContext context) {
    return RichText(
      text: text,
      textAlign: textAlign,
      textDirection: textDirection,
      softWrap: _resolvedSoftWrap,
      overflow: overflow,
      maxLines: _resolvedMaxLines,
      locale: locale,
      strutStyle: _resolvedStrutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: _resolvedTextHeightBehavior,
      selectionRegistrar: selectionRegistrar,
      selectionColor: _resolvedSelectionColor,
    );
  }

  StrutStyle? _resolveStrutStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveStrutStyle(basePath!, suffix);
  }

  TextHeightBehavior? _resolveTextHeightBehavior(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextHeightBehavior(basePath!, suffix);
  }
}

/// Tom wrapper for [Badge].
///
/// Adds ID, group, authorization, and resource resolution for label.
class TomBadge extends TomLabelBase {
  final Widget? child;
  final Widget? label;
  final String? labelText;
  final Color? backgroundColor;
  final Color? textColor;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;
  final Offset? offset;
  final bool isLabelVisible;
  final double? smallSize;
  final double? largeSize;

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final Color? _resolvedBackgroundColor;
  late final Color? _resolvedTextColor;
  late final double? _resolvedSmallSize;
  late final double? _resolvedLargeSize;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final TextStyle? _resolvedTextStyle;
  late final AlignmentGeometry? _resolvedAlignment;
  late final Offset? _resolvedOffset;
  late final bool _resolvedIsLabelVisible;

  TomBadge({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.child,
    this.label,
    this.labelText,
    this.backgroundColor,
    this.textColor,
    this.textStyle,
    this.padding,
    this.alignment,
    this.offset,
    this.isLabelVisible = true,
    this.smallSize,
    this.largeSize,
  }) {
    _resolvedLabel = labelText ?? resolveResourceOrFail('label');
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
    _resolvedTextColor = textColor ?? resolveColorOrNull('textColor');
    _resolvedSmallSize = smallSize ?? resolveDoubleOrNull('smallSize');
    _resolvedLargeSize = largeSize ?? resolveDoubleOrNull('largeSize');
    _resolvedPadding = padding ?? resolveEdgeInsetsOrNull('padding');
    _resolvedTextStyle = textStyle ?? _resolveTextStyle('textStyle');
    _resolvedAlignment = alignment ?? _resolveAlignment('alignment');
    _resolvedOffset = offset ?? _resolveOffset('offset');
    _resolvedIsLabelVisible = resolveBoolOrNull('isLabelVisible') ?? isLabelVisible;
  }

  @override
  Widget buildContent(BuildContext context) {
    final effectiveLabel = label ?? Text(_resolvedLabel);

    return Badge(
      label: effectiveLabel,
      backgroundColor: _resolvedBackgroundColor,
      textColor: _resolvedTextColor,
      textStyle: _resolvedTextStyle,
      padding: _resolvedPadding,
      alignment: _resolvedAlignment,
      offset: _resolvedOffset,
      isLabelVisible: _resolvedIsLabelVisible,
      smallSize: _resolvedSmallSize,
      largeSize: _resolvedLargeSize,
      child: child,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
  }

  Offset? _resolveOffset(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveOffset(basePath!, suffix);
  }
}

/// Tom wrapper for [ListTile] (as display label).
///
/// Adds ID, group, authorization, and resource resolution for title.
class TomListTile extends TomLabelBase {
  final Widget? title;
  final String? titleText;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool isThreeLine;
  final bool? dense;
  final VisualDensity? visualDensity;
  final ShapeBorder? shape;
  final Color? selectedColor;
  final Color? iconColor;
  final Color? textColor;
  final TextStyle? titleTextStyle;
  final TextStyle? subtitleTextStyle;
  final TextStyle? leadingAndTrailingTextStyle;
  final EdgeInsetsGeometry? contentPadding;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final Color? focusColor;
  final Color? hoverColor;
  final Color? splashColor;
  final FocusNode? focusNode;
  final bool autofocus;
  final Color? tileColor;
  final Color? selectedTileColor;
  final bool? enableFeedback;
  final double? horizontalTitleGap;
  final double? minVerticalPadding;
  final double? minLeadingWidth;
  final double? minTileHeight;
  final ListTileTitleAlignment? titleAlignment;
  final MouseCursor? mouseCursor;

  // Pre-resolved resource values
  late final String _resolvedTitle;
  late final bool _resolvedIsThreeLine;
  late final bool? _resolvedDense;
  late final bool _resolvedEnabled;
  late final bool _resolvedSelected;
  late final bool _resolvedAutofocus;
  late final bool? _resolvedEnableFeedback;
  late final Color? _resolvedSelectedColor;
  late final Color? _resolvedIconColor;
  late final Color? _resolvedTextColor;
  late final EdgeInsetsGeometry? _resolvedContentPadding;
  late final Color? _resolvedFocusColor;
  late final Color? _resolvedHoverColor;
  late final Color? _resolvedSplashColor;
  late final Color? _resolvedTileColor;
  late final Color? _resolvedSelectedTileColor;
  late final double? _resolvedHorizontalTitleGap;
  late final double? _resolvedMinVerticalPadding;
  late final double? _resolvedMinLeadingWidth;
  late final double? _resolvedMinTileHeight;
  late final VisualDensity? _resolvedVisualDensity;
  late final ShapeBorder? _resolvedShape;
  late final TextStyle? _resolvedTitleTextStyle;
  late final TextStyle? _resolvedSubtitleTextStyle;
  late final TextStyle? _resolvedLeadingAndTrailingTextStyle;

  TomListTile({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.title,
    this.titleText,
    this.subtitle,
    this.leading,
    this.trailing,
    this.isThreeLine = false,
    this.dense,
    this.visualDensity,
    this.shape,
    this.selectedColor,
    this.iconColor,
    this.textColor,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.leadingAndTrailingTextStyle,
    this.contentPadding,
    this.enabled = true,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.focusColor,
    this.hoverColor,
    this.splashColor,
    this.focusNode,
    this.autofocus = false,
    this.tileColor,
    this.selectedTileColor,
    this.enableFeedback,
    this.horizontalTitleGap,
    this.minVerticalPadding,
    this.minLeadingWidth,
    this.minTileHeight,
    this.titleAlignment,
    this.mouseCursor,
  }) {
    _resolvedTitle = titleText ?? resolveResourceOrFail('label');
    _resolvedIsThreeLine = resolveBoolOrNull('isThreeLine') ?? isThreeLine;
    _resolvedDense = dense ?? resolveBoolOrNull('dense');
    _resolvedEnabled = resolveBoolOrNull('enabled') ?? enabled;
    _resolvedSelected = resolveBoolOrNull('selected') ?? selected;
    _resolvedAutofocus = resolveBoolOrNull('autofocus') ?? autofocus;
    _resolvedEnableFeedback = enableFeedback ?? resolveBoolOrNull('enableFeedback');
    _resolvedSelectedColor = selectedColor ?? resolveColorOrNull('selectedColor');
    _resolvedIconColor = iconColor ?? resolveColorOrNull('iconColor');
    _resolvedTextColor = textColor ?? resolveColorOrNull('textColor');
    _resolvedContentPadding = contentPadding ?? resolveEdgeInsetsOrNull('contentPadding');
    _resolvedFocusColor = focusColor ?? resolveColorOrNull('focusColor');
    _resolvedHoverColor = hoverColor ?? resolveColorOrNull('hoverColor');
    _resolvedSplashColor = splashColor ?? resolveColorOrNull('splashColor');
    _resolvedTileColor = tileColor ?? resolveColorOrNull('tileColor');
    _resolvedSelectedTileColor = selectedTileColor ?? resolveColorOrNull('selectedTileColor');
    _resolvedHorizontalTitleGap = horizontalTitleGap ?? resolveDoubleOrNull('horizontalTitleGap');
    _resolvedMinVerticalPadding = minVerticalPadding ?? resolveDoubleOrNull('minVerticalPadding');
    _resolvedMinLeadingWidth = minLeadingWidth ?? resolveDoubleOrNull('minLeadingWidth');
    _resolvedMinTileHeight = minTileHeight ?? resolveDoubleOrNull('minTileHeight');
    _resolvedVisualDensity = visualDensity ?? _resolveVisualDensity('visualDensity');
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
    _resolvedTitleTextStyle = titleTextStyle ?? _resolveTextStyle('titleTextStyle');
    _resolvedSubtitleTextStyle = subtitleTextStyle ?? _resolveTextStyle('subtitleTextStyle');
    _resolvedLeadingAndTrailingTextStyle = leadingAndTrailingTextStyle ?? _resolveTextStyle('leadingAndTrailingTextStyle');
  }

  @override
  Widget buildContent(BuildContext context) {
    final effectiveTitle = title ?? Text(_resolvedTitle);

    return ListTile(
      title: effectiveTitle,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      isThreeLine: _resolvedIsThreeLine,
      dense: _resolvedDense,
      visualDensity: _resolvedVisualDensity,
      shape: _resolvedShape,
      selectedColor: _resolvedSelectedColor,
      iconColor: _resolvedIconColor,
      textColor: _resolvedTextColor,
      titleTextStyle: _resolvedTitleTextStyle,
      subtitleTextStyle: _resolvedSubtitleTextStyle,
      leadingAndTrailingTextStyle: _resolvedLeadingAndTrailingTextStyle,
      contentPadding: _resolvedContentPadding,
      enabled: _resolvedEnabled,
      onTap: onTap,
      onLongPress: onLongPress,
      selected: _resolvedSelected,
      focusColor: _resolvedFocusColor,
      hoverColor: _resolvedHoverColor,
      splashColor: _resolvedSplashColor,
      focusNode: focusNode,
      autofocus: _resolvedAutofocus,
      tileColor: _resolvedTileColor,
      selectedTileColor: _resolvedSelectedTileColor,
      enableFeedback: _resolvedEnableFeedback,
      horizontalTitleGap: _resolvedHorizontalTitleGap,
      minVerticalPadding: _resolvedMinVerticalPadding,
      minLeadingWidth: _resolvedMinLeadingWidth,
      minTileHeight: _resolvedMinTileHeight,
      titleAlignment: titleAlignment,
      mouseCursor: mouseCursor,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  VisualDensity? _resolveVisualDensity(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveVisualDensity(basePath!, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }
}

/// Tom wrapper for [Chip] (as label display).
///
/// Adds ID, group, authorization, and resource resolution for label.
class TomChip extends TomLabelBase {
  final Widget? avatar;
  final Widget? label;
  final String? labelText;
  final TextStyle? labelStyle;
  final EdgeInsetsGeometry? labelPadding;
  final EdgeInsetsGeometry? padding;
  final Widget? deleteIcon;
  final VoidCallback? onDeleted;
  final Color? deleteIconColor;
  final String? deleteButtonTooltipMessage;
  final BorderSide? side;
  final OutlinedBorder? shape;
  final Clip clipBehavior;
  final Color? backgroundColor;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final double? elevation;
  final MaterialTapTargetSize? materialTapTargetSize;
  final VisualDensity? visualDensity;
  final IconThemeData? iconTheme;
  final WidgetStateProperty<Color?>? color;

  // Pre-resolved resource values
  late final String _resolvedLabel;
  late final Color? _resolvedDeleteIconColor;
  late final Color? _resolvedBackgroundColor;
  late final Color? _resolvedShadowColor;
  late final Color? _resolvedSurfaceTintColor;
  late final double? _resolvedElevation;
  late final TextStyle? _resolvedLabelStyle;

  TomChip({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.avatar,
    this.label,
    this.labelText,
    this.labelStyle,
    this.labelPadding,
    this.padding,
    this.deleteIcon,
    this.onDeleted,
    this.deleteIconColor,
    this.deleteButtonTooltipMessage,
    this.side,
    this.shape,
    this.clipBehavior = Clip.none,
    this.backgroundColor,
    this.shadowColor,
    this.surfaceTintColor,
    this.elevation,
    this.materialTapTargetSize,
    this.visualDensity,
    this.iconTheme,
    this.color,
  }) {
    _resolvedLabel = labelText ?? resolveResourceOrFail('label');
    _resolvedDeleteIconColor = deleteIconColor ?? resolveColorOrNull('deleteIconColor');
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
    _resolvedShadowColor = shadowColor ?? resolveColorOrNull('shadowColor');
    _resolvedSurfaceTintColor = surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    _resolvedElevation = elevation ?? resolveDoubleOrNull('elevation');
    _resolvedLabelStyle = labelStyle ?? _resolveTextStyle('labelStyle');
  }

  @override
  Widget buildContent(BuildContext context) {
    final chipLabel = label ?? Text(_resolvedLabel);

    return Chip(
      avatar: avatar,
      label: chipLabel,
      labelStyle: _resolvedLabelStyle,
      labelPadding: labelPadding,
      padding: padding,
      deleteIcon: deleteIcon,
      onDeleted: onDeleted,
      deleteIconColor: _resolvedDeleteIconColor,
      deleteButtonTooltipMessage: deleteButtonTooltipMessage,
      side: side,
      shape: shape,
      clipBehavior: clipBehavior,
      backgroundColor: _resolvedBackgroundColor,
      shadowColor: _resolvedShadowColor,
      surfaceTintColor: _resolvedSurfaceTintColor,
      elevation: _resolvedElevation,
      materialTapTargetSize: materialTapTargetSize,
      visualDensity: visualDensity,
      iconTheme: iconTheme,
      color: color,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }
}

/// Tom wrapper for [DefaultTextStyle].
///
/// Adds ID, group, authorization, and resource resolution.
class TomDefaultTextStyle extends TomLabelBase {
  final TextStyle style;
  final TextAlign? textAlign;
  final bool softWrap;
  final TextOverflow overflow;
  final int? maxLines;
  final TextWidthBasis textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Widget child;

  TomDefaultTextStyle({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.style,
    this.textAlign,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.maxLines,
    this.textWidthBasis = TextWidthBasis.parent,
    this.textHeightBehavior,
    required this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return DefaultTextStyle(
      style: style,
      textAlign: textAlign,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      child: child,
    );
  }
}

// ============================================================================
// Section II: Extended Label Widgets
// ============================================================================

/// Tom wrapper for [AboutListTile].
///
/// List tile that opens About dialog. Auth on about access; resources for strings.
class TomAboutListTile extends TomLabelBase {
  final Widget? icon;
  final Widget? child;
  final String? applicationName;
  final String? applicationVersion;
  final Widget? applicationIcon;
  final String? applicationLegalese;
  final List<Widget>? aboutBoxChildren;
  final bool dense;

  // Pre-resolved resource values
  late final String? _resolvedApplicationName;
  late final String? _resolvedApplicationVersion;
  late final String? _resolvedApplicationLegalese;

  TomAboutListTile({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.icon,
    this.child,
    this.applicationName,
    this.applicationVersion,
    this.applicationIcon,
    this.applicationLegalese,
    this.aboutBoxChildren,
    this.dense = false,
  }) {
    _resolvedApplicationName = applicationName ?? resolveResourceOrNull('applicationName');
    _resolvedApplicationVersion = applicationVersion ?? resolveResourceOrNull('applicationVersion');
    _resolvedApplicationLegalese = applicationLegalese ?? resolveResourceOrNull('applicationLegalese');
  }

  @override
  Widget buildContent(BuildContext context) {
    return AboutListTile(
      icon: icon,
      applicationName: _resolvedApplicationName,
      applicationVersion: _resolvedApplicationVersion,
      applicationIcon: applicationIcon,
      applicationLegalese: _resolvedApplicationLegalese,
      aboutBoxChildren: aboutBoxChildren,
      dense: dense,
      child: child,
    );
  }
}

/// Tom wrapper for [VerticalDivider].
///
/// Vertical separator line. Auth-based visibility to avoid orphan dividers.
class TomVerticalDivider extends TomLabelBase {
  final double? width;
  final double? thickness;
  final double? indent;
  final double? endIndent;
  final Color? color;

  // Pre-resolved resource values
  late final double? _resolvedWidth;
  late final double? _resolvedThickness;
  late final double? _resolvedIndent;
  late final double? _resolvedEndIndent;
  late final Color? _resolvedColor;

  TomVerticalDivider({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.width,
    this.thickness,
    this.indent,
    this.endIndent,
    this.color,
  }) {
    _resolvedWidth = width ?? resolveDoubleOrNull('width');
    _resolvedThickness = thickness ?? resolveDoubleOrNull('thickness');
    _resolvedIndent = indent ?? resolveDoubleOrNull('indent');
    _resolvedEndIndent = endIndent ?? resolveDoubleOrNull('endIndent');
    _resolvedColor = color ?? resolveColorOrNull('color');
  }

  @override
  Widget buildContent(BuildContext context) {
    return VerticalDivider(
      width: _resolvedWidth,
      thickness: _resolvedThickness,
      indent: _resolvedIndent,
      endIndent: _resolvedEndIndent,
      color: _resolvedColor,
    );
  }
}

/// Tom wrapper for [MenuAcceleratorLabel].
///
/// Keyboard accelerator underline display. Auth controls visibility; resource for label.
class TomMenuAcceleratorLabel extends TomLabelBase {
  final String? label;
  final MenuAcceleratorChildBuilder? builder;

  // Pre-resolved resource values
  late final String _resolvedLabel;

  TomMenuAcceleratorLabel({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.label,
    this.builder,
  }) {
    _resolvedLabel = label ?? resolveResourceOrFail('label');
  }

  @override
  Widget buildContent(BuildContext context) {
    return MenuAcceleratorLabel(
      _resolvedLabel,
      builder: builder ?? MenuAcceleratorLabel.defaultLabelBuilder,
    );
  }
}

/// Tom wrapper for [Banner].
///
/// Diagonal banner overlay with child. Auth on banner display; resource for message.
class TomBanner extends TomLabelBase {
  final Widget? child;
  final String? message;
  final TextDirection? textDirection;
  final BannerLocation location;
  final TextStyle textStyle;
  final Color? color;

  // Pre-resolved resource values
  late final String _resolvedMessage;
  late final Color _resolvedColor;

  TomBanner({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.child,
    this.message,
    this.textDirection,
    required this.location,
    this.textStyle = _kTextStyle,
    this.color,
  }) {
    _resolvedMessage = message ?? resolveResourceOrFail('message');
    _resolvedColor = color ?? resolveColorOrNull('color') ?? _kColor;
  }

  static const Color _kColor = Color(0xA0B71C1C);
  static const TextStyle _kTextStyle = TextStyle(
    color: Color(0xFFFFFFFF),
    fontSize: 12.0 * 0.85,
    fontWeight: FontWeight.w900,
    height: 1.0,
  );

  @override
  Widget buildContent(BuildContext context) {
    return Banner(
      message: _resolvedMessage,
      textDirection: textDirection,
      location: location,
      textStyle: textStyle,
      color: _resolvedColor,
      child: child,
    );
  }
}
