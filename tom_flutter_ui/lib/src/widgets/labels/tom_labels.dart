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
  const TomText({
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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedText = text ?? resolveResourceOrFail('label');

    // Phase 2: Resolve optional parameter from resources
    final resolvedMaxLines = maxLines ?? resolveIntOrNull('maxLines');
    final resolvedSoftWrap = softWrap ?? resolveBoolOrNull('softWrap');
    final resolvedSemanticsLabel =
        semanticsLabel ?? resolveResourceOrNull('semanticsLabel');

    return Text(
      resolvedText,
      style: style ?? _resolveTextStyle('style'),
      strutStyle: strutStyle ?? _resolveStrutStyle('strutStyle'),
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: resolvedSoftWrap,
      overflow: overflow,
      maxLines: resolvedMaxLines,
      semanticsLabel: resolvedSemanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior ?? _resolveTextHeightBehavior('textHeightBehavior'),
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
  }

  StrutStyle? _resolveStrutStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveStrutStyle(basePath, suffix);
  }

  TextHeightBehavior? _resolveTextHeightBehavior(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextHeightBehavior(basePath, suffix);
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
  const TomSelectableText({
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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedText = text ?? resolveResourceOrFail('label');

    // Phase 2: Resolve optional parameters from resources
    final resolvedCursorColor =
        cursorColor ?? resolveColorOrNull('cursorColor');
    final resolvedMaxLines = maxLines ?? resolveIntOrNull('maxLines');
    final resolvedMinLines = minLines ?? resolveIntOrNull('minLines');
    final resolvedAutofocus =
        resolveBoolOrNull('autofocus') ?? autofocus;
    final resolvedShowCursor =
        resolveBoolOrNull('showCursor') ?? showCursor;
    final resolvedCursorWidth =
        resolveDoubleOrNull('cursorWidth') ?? cursorWidth;
    final resolvedCursorHeight =
        cursorHeight ?? resolveDoubleOrNull('cursorHeight');
    final resolvedSemanticsLabel =
        semanticsLabel ?? resolveResourceOrNull('semanticsLabel');

    return SelectableText(
      resolvedText,
      style: style ?? _resolveTextStyle('style'),
      strutStyle: strutStyle ?? _resolveStrutStyle('strutStyle'),
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
      scrollPhysics: scrollPhysics ?? _resolveScrollPhysics('scrollPhysics'),
      semanticsLabel: resolvedSemanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior ?? _resolveTextHeightBehavior('textHeightBehavior'),
      contextMenuBuilder: contextMenuBuilder,
      magnifierConfiguration: magnifierConfiguration,
      selectionControls: selectionControls,
      onSelectionChanged: onSelectionChanged,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
  }

  StrutStyle? _resolveStrutStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveStrutStyle(basePath, suffix);
  }

  TextHeightBehavior? _resolveTextHeightBehavior(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextHeightBehavior(basePath, suffix);
  }

  ScrollPhysics? _resolveScrollPhysics(String suffix) {
    final basePath = resolveResourceBasePath();
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
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedMaxLines = maxLines ?? resolveIntOrNull('maxLines');
    final resolvedSelectionColor =
        selectionColor ?? resolveColorOrNull('selectionColor');
    final resolvedSoftWrap =
        resolveBoolOrNull('softWrap') ?? softWrap;

    return RichText(
      text: text,
      textAlign: textAlign,
      textDirection: textDirection,
      softWrap: resolvedSoftWrap,
      overflow: overflow,
      maxLines: resolvedMaxLines,
      locale: locale,
      strutStyle: strutStyle ?? _resolveStrutStyle('strutStyle'),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior ?? _resolveTextHeightBehavior('textHeightBehavior'),
      selectionRegistrar: selectionRegistrar,
      selectionColor: resolvedSelectionColor,
    );
  }

  StrutStyle? _resolveStrutStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveStrutStyle(basePath, suffix);
  }

  TextHeightBehavior? _resolveTextHeightBehavior(String suffix) {
    final basePath = resolveResourceBasePath();
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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = labelText ?? resolveResourceOrFail('label');
    final effectiveLabel = label ?? Text(resolvedLabel);

    // Phase 2: Resolve optional parameters from resources
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedTextColor =
        textColor ?? resolveColorOrNull('textColor');
    final resolvedSmallSize =
        smallSize ?? resolveDoubleOrNull('smallSize');
    final resolvedLargeSize =
        largeSize ?? resolveDoubleOrNull('largeSize');
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding');

    // Phase 3: Resolve TextStyle from resources
    final resolvedTextStyle =
        textStyle ?? _resolveTextStyle('textStyle');

    return Badge(
      label: effectiveLabel,
      backgroundColor: resolvedBackgroundColor,
      textColor: resolvedTextColor,
      textStyle: resolvedTextStyle,
      padding: resolvedPadding,
      alignment: alignment ?? _resolveAlignment('alignment'),
      offset: offset ?? _resolveOffset('offset'),
      isLabelVisible: resolveBoolOrNull('isLabelVisible') ?? isLabelVisible,
      smallSize: resolvedSmallSize,
      largeSize: resolvedLargeSize,
      child: child,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath, suffix);
  }

  Offset? _resolveOffset(String suffix) {
    final basePath = resolveResourceBasePath();
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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTitle = titleText ?? resolveResourceOrFail('label');
    final effectiveTitle = title ?? Text(resolvedTitle);

    // Phase 2: Resolve optional parameters from resources
    final resolvedIsThreeLine =
        resolveBoolOrNull('isThreeLine') ?? isThreeLine;
    final resolvedDense = dense ?? resolveBoolOrNull('dense');
    final resolvedEnabled =
        resolveBoolOrNull('enabled') ?? enabled;
    final resolvedSelected =
        resolveBoolOrNull('selected') ?? selected;
    final resolvedAutofocus =
        resolveBoolOrNull('autofocus') ?? autofocus;
    final resolvedEnableFeedback =
        enableFeedback ?? resolveBoolOrNull('enableFeedback');
    final resolvedSelectedColor =
        selectedColor ?? resolveColorOrNull('selectedColor');
    final resolvedIconColor =
        iconColor ?? resolveColorOrNull('iconColor');
    final resolvedTextColor =
        textColor ?? resolveColorOrNull('textColor');
    final resolvedContentPadding =
        contentPadding ?? resolveEdgeInsetsOrNull('contentPadding');
    final resolvedFocusColor =
        focusColor ?? resolveColorOrNull('focusColor');
    final resolvedHoverColor =
        hoverColor ?? resolveColorOrNull('hoverColor');
    final resolvedSplashColor =
        splashColor ?? resolveColorOrNull('splashColor');
    final resolvedTileColor =
        tileColor ?? resolveColorOrNull('tileColor');
    final resolvedSelectedTileColor =
        selectedTileColor ?? resolveColorOrNull('selectedTileColor');
    final resolvedHorizontalTitleGap =
        horizontalTitleGap ?? resolveDoubleOrNull('horizontalTitleGap');
    final resolvedMinVerticalPadding =
        minVerticalPadding ?? resolveDoubleOrNull('minVerticalPadding');
    final resolvedMinLeadingWidth =
        minLeadingWidth ?? resolveDoubleOrNull('minLeadingWidth');
    final resolvedMinTileHeight =
        minTileHeight ?? resolveDoubleOrNull('minTileHeight');

    // Phase 3: Resolve complex objects from resources
    final resolvedVisualDensity =
        visualDensity ?? _resolveVisualDensity('visualDensity');
    final resolvedShape =
        shape ?? _resolveShapeBorder('shape');
    final resolvedTitleTextStyle =
        titleTextStyle ?? _resolveTextStyle('titleTextStyle');
    final resolvedSubtitleTextStyle =
        subtitleTextStyle ?? _resolveTextStyle('subtitleTextStyle');
    final resolvedLeadingAndTrailingTextStyle =
        leadingAndTrailingTextStyle ?? _resolveTextStyle('leadingAndTrailingTextStyle');

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

  TextStyle? _resolveTextStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
  }

  VisualDensity? _resolveVisualDensity(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveVisualDensity(basePath, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    final basePath = resolveResourceBasePath();
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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = labelText ?? resolveResourceOrFail('label');
    final chipLabel = label ?? Text(resolvedLabel);

    // Phase 2: Resolve optional parameters from resources
    final resolvedDeleteIconColor =
        deleteIconColor ?? resolveColorOrNull('deleteIconColor');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedSurfaceTintColor =
        surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');

    // Phase 3: Resolve TextStyle from resources
    final resolvedLabelStyle =
        labelStyle ?? _resolveTextStyle('labelStyle');

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

  TextStyle? _resolveTextStyle(String suffix) {
    final basePath = resolveResourceBasePath();
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

  const TomAboutListTile({
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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedApplicationName =
      applicationName ?? resolveResourceOrNull('applicationName');
    final resolvedApplicationVersion =
      applicationVersion ?? resolveResourceOrNull('applicationVersion');
    final resolvedApplicationLegalese =
      applicationLegalese ?? resolveResourceOrNull('applicationLegalese');

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
    super.scope,
    this.width,
    this.thickness,
    this.indent,
    this.endIndent,
    this.color,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedWidth = width ?? resolveDoubleOrNull('width');
    final resolvedThickness =
        thickness ?? resolveDoubleOrNull('thickness');
    final resolvedIndent = indent ?? resolveDoubleOrNull('indent');
    final resolvedEndIndent =
        endIndent ?? resolveDoubleOrNull('endIndent');
    final resolvedColor = color ?? resolveColorOrNull('color');

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
    super.scope,
    this.label,
    this.builder,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = label ?? resolveResourceOrFail('label');
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
    super.scope,
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
    final resolvedMessage = message ?? resolveResourceOrFail('message');
    final resolvedColor = color ?? resolveColorOrNull('color') ?? _kColor;
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
