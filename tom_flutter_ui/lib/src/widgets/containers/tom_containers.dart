import 'package:flutter/material.dart';

import '../../widget_base/tom_family_base.dart';

/// Tom wrapper for [Card].
///
/// Adds ID, group, authorization, and resource resolution for tooltip/label.
class TomCard extends TomContainerBase {
  final Color? color;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final double? elevation;
  final ShapeBorder? shape;
  final bool borderOnForeground;
  final EdgeInsetsGeometry? margin;
  final Clip? clipBehavior;
  final bool semanticContainer;
  final Widget? child;

  const TomCard({
    super.key,
    super.tomId,
    super.tomGroup,
    super.tomStyleVariant,
    this.color,
    this.shadowColor,
    this.surfaceTintColor,
    this.elevation,
    this.shape,
    this.borderOnForeground = true,
    this.margin,
    this.clipBehavior,
    this.semanticContainer = true,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Card(
      color: color,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      elevation: elevation,
      shape: shape,
      borderOnForeground: borderOnForeground,
      margin: margin,
      clipBehavior: clipBehavior,
      semanticContainer: semanticContainer,
      child: child,
    );
  }
}

/// Tom wrapper for [ExpansionTile].
///
/// Adds ID, group, authorization, and resource resolution for title.
class TomExpansionTile extends TomContainerBase {
  final Widget? title;
  final String? titleText;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool initiallyExpanded;
  final bool maintainState;
  final EdgeInsetsGeometry? tilePadding;
  final CrossAxisAlignment? expandedCrossAxisAlignment;
  final Alignment? expandedAlignment;
  final EdgeInsetsGeometry? childrenPadding;
  final Color? backgroundColor;
  final Color? collapsedBackgroundColor;
  final Color? textColor;
  final Color? collapsedTextColor;
  final Color? iconColor;
  final Color? collapsedIconColor;
  final ShapeBorder? shape;
  final ShapeBorder? collapsedShape;
  final Clip? clipBehavior;
  final ListTileControlAffinity? controlAffinity;
  final ValueChanged<bool>? onExpansionChanged;
  final List<Widget> children;
  final bool dense;
  final bool showTrailingIcon;

  const TomExpansionTile({
    super.key,
    super.tomId,
    super.tomGroup,
    super.tomStyleVariant,
    this.title,
    this.titleText,
    this.subtitle,
    this.leading,
    this.trailing,
    this.initiallyExpanded = false,
    this.maintainState = false,
    this.tilePadding,
    this.expandedCrossAxisAlignment,
    this.expandedAlignment,
    this.childrenPadding,
    this.backgroundColor,
    this.collapsedBackgroundColor,
    this.textColor,
    this.collapsedTextColor,
    this.iconColor,
    this.collapsedIconColor,
    this.shape,
    this.collapsedShape,
    this.clipBehavior,
    this.controlAffinity,
    this.onExpansionChanged,
    this.children = const [],
    this.dense = false,
    this.showTrailingIcon = true,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTitle = titleText ?? (tomId != null ? resolveResource(context, 'label') : null);
    final titleWidget = title ?? Text(resolvedTitle ?? '');

    return ExpansionTile(
      title: titleWidget,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      initiallyExpanded: initiallyExpanded,
      maintainState: maintainState,
      tilePadding: tilePadding,
      expandedCrossAxisAlignment: expandedCrossAxisAlignment,
      expandedAlignment: expandedAlignment,
      childrenPadding: childrenPadding,
      backgroundColor: backgroundColor,
      collapsedBackgroundColor: collapsedBackgroundColor,
      textColor: textColor,
      collapsedTextColor: collapsedTextColor,
      iconColor: iconColor,
      collapsedIconColor: collapsedIconColor,
      shape: shape,
      collapsedShape: collapsedShape,
      clipBehavior: clipBehavior,
      controlAffinity: controlAffinity,
      onExpansionChanged: onExpansionChanged,
      dense: dense,
      showTrailingIcon: showTrailingIcon,
      children: children,
    );
  }
}
