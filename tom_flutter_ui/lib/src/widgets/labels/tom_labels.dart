import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../widget_base/tom_family_base.dart';

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

    return Text(
      resolvedText,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
    );
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

    return SelectableText(
      resolvedText,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: maxLines,
      focusNode: focusNode,
      autofocus: autofocus,
      showCursor: showCursor,
      minLines: minLines,
      cursorWidth: cursorWidth,
      cursorHeight: cursorHeight,
      cursorRadius: cursorRadius,
      cursorColor: cursorColor,
      onTap: onTap,
      scrollPhysics: scrollPhysics,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      contextMenuBuilder: contextMenuBuilder,
      magnifierConfiguration: magnifierConfiguration,
      selectionControls: selectionControls,
      onSelectionChanged: onSelectionChanged,
    );
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
    return RichText(
      text: text,
      textAlign: textAlign,
      textDirection: textDirection,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      locale: locale,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionRegistrar: selectionRegistrar,
      selectionColor: selectionColor,
    );
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

    return Badge(
      label: effectiveLabel,
      backgroundColor: backgroundColor,
      textColor: textColor,
      textStyle: textStyle,
      padding: padding,
      alignment: alignment,
      offset: offset,
      isLabelVisible: isLabelVisible,
      smallSize: smallSize,
      largeSize: largeSize,
      child: child,
    );
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

    return ListTile(
      title: effectiveTitle,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      isThreeLine: isThreeLine,
      dense: dense,
      visualDensity: visualDensity,
      shape: shape,
      selectedColor: selectedColor,
      iconColor: iconColor,
      textColor: textColor,
      titleTextStyle: titleTextStyle,
      subtitleTextStyle: subtitleTextStyle,
      leadingAndTrailingTextStyle: leadingAndTrailingTextStyle,
      contentPadding: contentPadding,
      enabled: enabled,
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      focusColor: focusColor,
      hoverColor: hoverColor,
      splashColor: splashColor,
      focusNode: focusNode,
      autofocus: autofocus,
      tileColor: tileColor,
      selectedTileColor: selectedTileColor,
      enableFeedback: enableFeedback,
      horizontalTitleGap: horizontalTitleGap,
      minVerticalPadding: minVerticalPadding,
      minLeadingWidth: minLeadingWidth,
      minTileHeight: minTileHeight,
      titleAlignment: titleAlignment,
      mouseCursor: mouseCursor,
    );
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

    return Chip(
      avatar: avatar,
      label: chipLabel,
      labelStyle: labelStyle,
      labelPadding: labelPadding,
      padding: padding,
      deleteIcon: deleteIcon,
      onDeleted: onDeleted,
      deleteIconColor: deleteIconColor,
      deleteButtonTooltipMessage: deleteButtonTooltipMessage,
      side: side,
      shape: shape,
      clipBehavior: clipBehavior,
      backgroundColor: backgroundColor,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      elevation: elevation,
      materialTapTargetSize: materialTapTargetSize,
      visualDensity: visualDensity,
      iconTheme: iconTheme,
      color: color,
    );
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
    return AboutListTile(
      icon: icon,
      applicationName: applicationName ??
          (tomId != null ? resolveResourceOrFail(context, 'applicationName') : null),
      applicationVersion: applicationVersion ??
          (tomId != null
              ? resolveResourceOrFail(context, 'applicationVersion')
              : null),
      applicationIcon: applicationIcon,
      applicationLegalese: applicationLegalese ??
          (tomId != null
              ? resolveResourceOrFail(context, 'applicationLegalese')
              : null),
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
    return VerticalDivider(
      width: width,
      thickness: thickness,
      indent: indent,
      endIndent: endIndent,
      color: color,
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
  final Color color;

  const TomBanner({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    this.message,
    this.textDirection,
    required this.location,
    this.textStyle = _kTextStyle,
    this.color = _kColor,
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
    return Banner(
      message: resolvedMessage,
      textDirection: textDirection,
      location: location,
      textStyle: textStyle,
      color: color,
      child: child,
    );
  }
}
