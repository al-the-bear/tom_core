import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_style_resolvers.dart';

/// Tom wrapper for [Text].
///
/// Provides both positional [data] parameter (matching Flutter's Text API)
/// and optional resource resolution when neither [data] nor [text] is provided.
class TomText extends TomLabelBase {
  /// The text to display (positional parameter for Flutter API compatibility).
  final String? data;

  /// Alternative named text parameter for resource-based resolution.
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
  /// Use the positional [data] parameter for Flutter API compatibility:
  /// ```dart
  /// TomText('Hello')  // Same as Text('Hello')
  /// ```
  ///
  /// Or use named parameters for resource resolution:
  /// ```dart
  /// TomText(tomId: 'app.greeting')  // Resolves from resources
  /// ```
  const TomText(
    String? this.data, {
    super.key,
    super.tomId,
    super.tomGroup,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedText = data ?? text ?? resolveResourceOrFail(context, 'label');

    // Phase 2: Resolve optional parameter from resources
    final resolvedMaxLines = maxLines ?? resolveIntOrNull(context, 'maxLines');
    final resolvedSoftWrap = softWrap ?? resolveBoolOrNull(context, 'softWrap');
    final resolvedSemanticsLabel =
        semanticsLabel ?? resolveResourceOrNull(context, 'semanticsLabel');

    return Text(
      resolvedText,
      style: style,
      strutStyle: strutStyle ?? _resolveStrutStyle(context, 'strutStyle'),
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: resolvedSoftWrap,
      overflow: overflow,
      maxLines: resolvedMaxLines,
      semanticsLabel: resolvedSemanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior ?? _resolveTextHeightBehavior(context, 'textHeightBehavior'),
    );
  }

  StrutStyle? _resolveStrutStyle(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveStrutStyle(basePath, suffix);
  }

  TextHeightBehavior? _resolveTextHeightBehavior(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextHeightBehavior(basePath, suffix);
  }
}

/// Tom wrapper for [SelectableText].
///
/// Provides both positional [data] parameter (matching Flutter's SelectableText API)
/// and optional resource resolution when neither [data] nor [text] is provided.
///
/// Drop-in replacement for Flutter's [SelectableText] widget:
/// ```dart
/// TomSelectableText('Hello')  // Same as SelectableText('Hello')
/// ```
class TomSelectableText extends TomLabelBase {
  /// The text to display (positional parameter for Flutter API compatibility).
  final String? data;

  /// Alternative named text parameter for resource-based resolution.
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
  /// Use the positional [data] parameter for Flutter API compatibility:
  /// ```dart
  /// TomSelectableText('Hello')  // Same as SelectableText('Hello')
  /// ```
  const TomSelectableText(
    String? this.data, {
    super.key,
    super.tomId,
    super.tomGroup,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedText = data ?? text ?? resolveResourceOrFail(context, 'label');

    // Phase 2: Resolve optional parameters from resources
    final resolvedCursorColor =
        cursorColor ?? resolveColorOrNull(context, 'cursorColor');
    final resolvedMaxLines = maxLines ?? resolveIntOrNull(context, 'maxLines');
    final resolvedMinLines = minLines ?? resolveIntOrNull(context, 'minLines');
    final resolvedAutofocus =
        resolveBoolOrNull(context, 'autofocus') ?? autofocus;
    final resolvedShowCursor =
        resolveBoolOrNull(context, 'showCursor') ?? showCursor;
    final resolvedCursorWidth =
        resolveDoubleOrNull(context, 'cursorWidth') ?? cursorWidth;
    final resolvedCursorHeight =
        cursorHeight ?? resolveDoubleOrNull(context, 'cursorHeight');
    final resolvedSemanticsLabel =
        semanticsLabel ?? resolveResourceOrNull(context, 'semanticsLabel');

    return SelectableText(
      resolvedText,
      style: style,
      strutStyle: strutStyle ?? _resolveStrutStyle(context, 'strutStyle'),
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: resolvedMaxLines,
      focusNode: focusNode,
      autofocus: resolvedAutofocus,
      showCursor: resolvedShowCursor,
      minLines: resolvedMinLines,
      cursorWidth: resolvedCursorWidth,
      cursorHeight: resolvedCursorHeight,
      cursorRadius: cursorRadius,
      cursorColor: resolvedCursorColor,
      onTap: onTap,
      scrollPhysics: scrollPhysics ?? _resolveScrollPhysics(context, 'scrollPhysics'),
      semanticsLabel: resolvedSemanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior ?? _resolveTextHeightBehavior(context, 'textHeightBehavior'),
      contextMenuBuilder: contextMenuBuilder,
      magnifierConfiguration: magnifierConfiguration,
      selectionControls: selectionControls,
      onSelectionChanged: onSelectionChanged,
    );
  }

  StrutStyle? _resolveStrutStyle(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveStrutStyle(basePath, suffix);
  }

  TextHeightBehavior? _resolveTextHeightBehavior(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextHeightBehavior(basePath, suffix);
  }

  ScrollPhysics? _resolveScrollPhysics(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveScrollPhysics(basePath, suffix);
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

  const TomRichText({
    super.key,
    super.tomId,
    super.tomGroup,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedMaxLines = maxLines ?? resolveIntOrNull(context, 'maxLines');
    final resolvedSelectionColor =
        selectionColor ?? resolveColorOrNull(context, 'selectionColor');
    final resolvedSoftWrap =
        resolveBoolOrNull(context, 'softWrap') ?? softWrap;

    return RichText(
      text: text,
      textAlign: textAlign,
      textDirection: textDirection,
      softWrap: resolvedSoftWrap,
      overflow: overflow,
      maxLines: resolvedMaxLines,
      locale: locale,
      strutStyle: strutStyle ?? _resolveStrutStyle(context, 'strutStyle'),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior ?? _resolveTextHeightBehavior(context, 'textHeightBehavior'),
      selectionRegistrar: selectionRegistrar,
      selectionColor: resolvedSelectionColor,
    );
  }

  StrutStyle? _resolveStrutStyle(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveStrutStyle(basePath, suffix);
  }

  TextHeightBehavior? _resolveTextHeightBehavior(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextHeightBehavior(basePath, suffix);
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

  const TomBadge({
    super.key,
    super.tomId,
    super.tomGroup,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = labelText ?? resolveResourceOrFail(context, 'label');
    final effectiveLabel = label ?? Text(resolvedLabel);

    // Phase 2: Resolve optional parameters from resources
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull(context, 'backgroundColor');
    final resolvedTextColor =
        textColor ?? resolveColorOrNull(context, 'textColor');
    final resolvedSmallSize =
        smallSize ?? resolveDoubleOrNull(context, 'smallSize');
    final resolvedLargeSize =
        largeSize ?? resolveDoubleOrNull(context, 'largeSize');
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull(context, 'padding');

    // Phase 3: Resolve TextStyle from resources
    final resolvedTextStyle =
        textStyle ?? _resolveTextStyle(context, 'textStyle');

    return Badge(
      label: effectiveLabel,
      backgroundColor: resolvedBackgroundColor,
      textColor: resolvedTextColor,
      textStyle: resolvedTextStyle,
      padding: resolvedPadding,
      alignment: alignment ?? _resolveAlignment(context, 'alignment'),
      offset: offset ?? _resolveOffset(context, 'offset'),
      isLabelVisible: resolveBoolOrNull(context, 'isLabelVisible') ?? isLabelVisible,
      smallSize: resolvedSmallSize,
      largeSize: resolvedLargeSize,
      child: child,
    );
  }

  TextStyle? _resolveTextStyle(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
  }

  AlignmentGeometry? _resolveAlignment(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath, suffix);
  }

  Offset? _resolveOffset(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveOffset(basePath, suffix);
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

  const TomListTile({
    super.key,
    super.tomId,
    super.tomGroup,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTitle = titleText ?? resolveResourceOrFail(context, 'label');
    final effectiveTitle = title ?? Text(resolvedTitle);

    // Phase 2: Resolve optional parameters from resources
    final resolvedIsThreeLine =
        resolveBoolOrNull(context, 'isThreeLine') ?? isThreeLine;
    final resolvedDense = dense ?? resolveBoolOrNull(context, 'dense');
    final resolvedEnabled =
        resolveBoolOrNull(context, 'enabled') ?? enabled;
    final resolvedSelected =
        resolveBoolOrNull(context, 'selected') ?? selected;
    final resolvedAutofocus =
        resolveBoolOrNull(context, 'autofocus') ?? autofocus;
    final resolvedEnableFeedback =
        enableFeedback ?? resolveBoolOrNull(context, 'enableFeedback');
    final resolvedSelectedColor =
        selectedColor ?? resolveColorOrNull(context, 'selectedColor');
    final resolvedIconColor =
        iconColor ?? resolveColorOrNull(context, 'iconColor');
    final resolvedTextColor =
        textColor ?? resolveColorOrNull(context, 'textColor');
    final resolvedContentPadding =
        contentPadding ?? resolveEdgeInsetsOrNull(context, 'contentPadding');
    final resolvedFocusColor =
        focusColor ?? resolveColorOrNull(context, 'focusColor');
    final resolvedHoverColor =
        hoverColor ?? resolveColorOrNull(context, 'hoverColor');
    final resolvedSplashColor =
        splashColor ?? resolveColorOrNull(context, 'splashColor');
    final resolvedTileColor =
        tileColor ?? resolveColorOrNull(context, 'tileColor');
    final resolvedSelectedTileColor =
        selectedTileColor ?? resolveColorOrNull(context, 'selectedTileColor');
    final resolvedHorizontalTitleGap =
        horizontalTitleGap ?? resolveDoubleOrNull(context, 'horizontalTitleGap');
    final resolvedMinVerticalPadding =
        minVerticalPadding ?? resolveDoubleOrNull(context, 'minVerticalPadding');
    final resolvedMinLeadingWidth =
        minLeadingWidth ?? resolveDoubleOrNull(context, 'minLeadingWidth');
    final resolvedMinTileHeight =
        minTileHeight ?? resolveDoubleOrNull(context, 'minTileHeight');

    // Phase 3: Resolve complex objects from resources
    final resolvedVisualDensity =
        visualDensity ?? _resolveVisualDensity(context, 'visualDensity');
    final resolvedShape =
        shape ?? _resolveShapeBorder(context, 'shape');
    final resolvedTitleTextStyle =
        titleTextStyle ?? _resolveTextStyle(context, 'titleTextStyle');
    final resolvedSubtitleTextStyle =
        subtitleTextStyle ?? _resolveTextStyle(context, 'subtitleTextStyle');
    final resolvedLeadingAndTrailingTextStyle =
        leadingAndTrailingTextStyle ?? _resolveTextStyle(context, 'leadingAndTrailingTextStyle');

    return ListTile(
      title: effectiveTitle,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      isThreeLine: resolvedIsThreeLine,
      dense: resolvedDense,
      visualDensity: resolvedVisualDensity,
      shape: resolvedShape,
      selectedColor: resolvedSelectedColor,
      iconColor: resolvedIconColor,
      textColor: resolvedTextColor,
      titleTextStyle: resolvedTitleTextStyle,
      subtitleTextStyle: resolvedSubtitleTextStyle,
      leadingAndTrailingTextStyle: resolvedLeadingAndTrailingTextStyle,
      contentPadding: resolvedContentPadding,
      enabled: resolvedEnabled,
      onTap: onTap,
      onLongPress: onLongPress,
      selected: resolvedSelected,
      focusColor: resolvedFocusColor,
      hoverColor: resolvedHoverColor,
      splashColor: resolvedSplashColor,
      focusNode: focusNode,
      autofocus: resolvedAutofocus,
      tileColor: resolvedTileColor,
      selectedTileColor: resolvedSelectedTileColor,
      enableFeedback: resolvedEnableFeedback,
      horizontalTitleGap: resolvedHorizontalTitleGap,
      minVerticalPadding: resolvedMinVerticalPadding,
      minLeadingWidth: resolvedMinLeadingWidth,
      minTileHeight: resolvedMinTileHeight,
      titleAlignment: titleAlignment,
      mouseCursor: mouseCursor,
    );
  }

  TextStyle? _resolveTextStyle(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
  }

  VisualDensity? _resolveVisualDensity(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveVisualDensity(basePath, suffix);
  }

  ShapeBorder? _resolveShapeBorder(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath, suffix);
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

  const TomChip({
    super.key,
    super.tomId,
    super.tomGroup,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = labelText ?? resolveResourceOrFail(context, 'label');
    final chipLabel = label ?? Text(resolvedLabel);

    // Phase 2: Resolve optional parameters from resources
    final resolvedDeleteIconColor =
        deleteIconColor ?? resolveColorOrNull(context, 'deleteIconColor');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull(context, 'backgroundColor');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull(context, 'shadowColor');
    final resolvedSurfaceTintColor =
        surfaceTintColor ?? resolveColorOrNull(context, 'surfaceTintColor');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull(context, 'elevation');

    // Phase 3: Resolve TextStyle from resources
    final resolvedLabelStyle =
        labelStyle ?? _resolveTextStyle(context, 'labelStyle');

    return Chip(
      avatar: avatar,
      label: chipLabel,
      labelStyle: resolvedLabelStyle,
      labelPadding: labelPadding,
      padding: padding,
      deleteIcon: deleteIcon,
      onDeleted: onDeleted,
      deleteIconColor: resolvedDeleteIconColor,
      deleteButtonTooltipMessage: deleteButtonTooltipMessage,
      side: side,
      shape: shape,
      clipBehavior: clipBehavior,
      backgroundColor: resolvedBackgroundColor,
      shadowColor: resolvedShadowColor,
      surfaceTintColor: resolvedSurfaceTintColor,
      elevation: resolvedElevation,
      materialTapTargetSize: materialTapTargetSize,
      visualDensity: visualDensity,
      iconTheme: iconTheme,
      color: color,
    );
  }

  TextStyle? _resolveTextStyle(BuildContext context, String suffix) {
    final basePath = resolveResourceBasePath(context);
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
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

  const TomDefaultTextStyle({
    super.key,
    super.tomId,
    super.tomGroup,
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

  const TomAboutListTile({
    super.key,
    super.tomId,
    super.tomGroup,
    this.icon,
    this.child,
    this.applicationName,
    this.applicationVersion,
    this.applicationIcon,
    this.applicationLegalese,
    this.aboutBoxChildren,
    this.dense = false,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedApplicationName =
      applicationName ?? resolveResourceOrNull(context, 'applicationName');
    final resolvedApplicationVersion =
      applicationVersion ?? resolveResourceOrNull(context, 'applicationVersion');
    final resolvedApplicationLegalese =
      applicationLegalese ?? resolveResourceOrNull(context, 'applicationLegalese');

    return AboutListTile(
      icon: icon,
      applicationName: resolvedApplicationName,
      applicationVersion: resolvedApplicationVersion,
      applicationIcon: applicationIcon,
      applicationLegalese: resolvedApplicationLegalese,
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

  const TomVerticalDivider({
    super.key,
    super.tomId,
    super.tomGroup,
    this.width,
    this.thickness,
    this.indent,
    this.endIndent,
    this.color,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedWidth = width ?? resolveDoubleOrNull(context, 'width');
    final resolvedThickness =
        thickness ?? resolveDoubleOrNull(context, 'thickness');
    final resolvedIndent = indent ?? resolveDoubleOrNull(context, 'indent');
    final resolvedEndIndent =
        endIndent ?? resolveDoubleOrNull(context, 'endIndent');
    final resolvedColor = color ?? resolveColorOrNull(context, 'color');

    return VerticalDivider(
      width: resolvedWidth,
      thickness: resolvedThickness,
      indent: resolvedIndent,
      endIndent: resolvedEndIndent,
      color: resolvedColor,
    );
  }
}

/// Tom wrapper for [MenuAcceleratorLabel].
///
/// Keyboard accelerator underline display. Auth controls visibility; resource for label.
class TomMenuAcceleratorLabel extends TomLabelBase {
  final String? label;
  final MenuAcceleratorChildBuilder? builder;

  const TomMenuAcceleratorLabel({
    super.key,
    super.tomId,
    super.tomGroup,
    this.label,
    this.builder,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = label ?? resolveResourceOrFail(context, 'label');
    return MenuAcceleratorLabel(
      resolvedLabel,
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

  const TomBanner({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    this.message,
    this.textDirection,
    required this.location,
    this.textStyle = _kTextStyle,
    this.color,
  });

  static const Color _kColor = Color(0xA0B71C1C);
  static const TextStyle _kTextStyle = TextStyle(
    color: Color(0xFFFFFFFF),
    fontSize: 12.0 * 0.85,
    fontWeight: FontWeight.w900,
    height: 1.0,
  );

  @override
  Widget buildContent(BuildContext context) {
    final resolvedMessage = message ?? resolveResourceOrFail(context, 'message');
    final resolvedColor = color ?? resolveColorOrNull(context, 'color') ?? _kColor;
    return Banner(
      message: resolvedMessage,
      textDirection: textDirection,
      location: location,
      textStyle: textStyle,
      color: resolvedColor,
      child: child,
    );
  }
}
