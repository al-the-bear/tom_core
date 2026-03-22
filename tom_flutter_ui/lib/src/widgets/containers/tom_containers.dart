import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Tom wrapper for [Scaffold].
///
/// Adds ID, group, and authorization.
class TomScaffold extends TomContainerBase {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final FloatingActionButtonAnimator? floatingActionButtonAnimator;
  final List<Widget>? persistentFooterButtons;
  final AlignmentDirectional persistentFooterAlignment;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final bool primary;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final Color? drawerScrimColor;
  final double? drawerEdgeDragWidth;
  final bool drawerEnableOpenDragGesture;
  final bool endDrawerEnableOpenDragGesture;
  final String? restorationId;

  const TomScaffold({
    super.key,
    super.tomId,
    super.tomGroup,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.floatingActionButtonAnimator,
    this.persistentFooterButtons,
    this.persistentFooterAlignment = AlignmentDirectional.centerEnd,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.primary = true,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.drawerScrimColor,
    this.drawerEdgeDragWidth,
    this.drawerEnableOpenDragGesture = true,
    this.endDrawerEnableOpenDragGesture = true,
    this.restorationId,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      floatingActionButtonAnimator: floatingActionButtonAnimator,
      persistentFooterButtons: persistentFooterButtons,
      persistentFooterAlignment: persistentFooterAlignment,
      drawer: drawer,
      endDrawer: endDrawer,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      primary: primary,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      drawerScrimColor: drawerScrimColor,
      drawerEdgeDragWidth: drawerEdgeDragWidth,
      drawerEnableOpenDragGesture: drawerEnableOpenDragGesture,
      endDrawerEnableOpenDragGesture: endDrawerEnableOpenDragGesture,
      restorationId: restorationId,
    );
  }
}

/// Tom wrapper for [AppBar].
///
/// Adds ID, group, authorization, and resource resolution for title text.
class TomAppBar extends TomContainerBase {
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Widget? title;
  final String? titleText;
  final List<Widget>? actions;
  final Widget? flexibleSpace;
  final PreferredSizeWidget? bottom;
  final double? elevation;
  final double? scrolledUnderElevation;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconThemeData? iconTheme;
  final IconThemeData? actionsIconTheme;
  final bool primary;
  final bool? centerTitle;
  final bool excludeHeaderSemantics;
  final double? titleSpacing;
  final double toolbarOpacity;
  final double bottomOpacity;
  final double? toolbarHeight;
  final double? leadingWidth;
  final TextStyle? toolbarTextStyle;
  final TextStyle? titleTextStyle;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final bool forceMaterialTransparency;
  final Clip? clipBehavior;
  final ShapeBorder? shape;
  final ScrollNotificationPredicate notificationPredicate;

  const TomAppBar({
    super.key,
    super.tomId,
    super.tomGroup,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.title,
    this.titleText,
    this.actions,
    this.flexibleSpace,
    this.bottom,
    this.elevation,
    this.scrolledUnderElevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.backgroundColor,
    this.foregroundColor,
    this.iconTheme,
    this.actionsIconTheme,
    this.primary = true,
    this.centerTitle,
    this.excludeHeaderSemantics = false,
    this.titleSpacing,
    this.toolbarOpacity = 1.0,
    this.bottomOpacity = 1.0,
    this.toolbarHeight,
    this.leadingWidth,
    this.toolbarTextStyle,
    this.titleTextStyle,
    this.systemOverlayStyle,
    this.forceMaterialTransparency = false,
    this.clipBehavior,
    this.shape,
    this.notificationPredicate = defaultScrollNotificationPredicate,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTitle =
        titleText ?? (tomId != null ? resolveResource(context, 'label') : null);
    final effectiveTitle =
        title ?? (resolvedTitle != null ? Text(resolvedTitle) : null);

    return AppBar(
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: effectiveTitle,
      actions: actions,
      flexibleSpace: flexibleSpace,
      bottom: bottom,
      elevation: elevation,
      scrolledUnderElevation: scrolledUnderElevation,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      iconTheme: iconTheme,
      actionsIconTheme: actionsIconTheme,
      primary: primary,
      centerTitle: centerTitle,
      excludeHeaderSemantics: excludeHeaderSemantics,
      titleSpacing: titleSpacing,
      toolbarOpacity: toolbarOpacity,
      bottomOpacity: bottomOpacity,
      toolbarHeight: toolbarHeight,
      leadingWidth: leadingWidth,
      toolbarTextStyle: toolbarTextStyle,
      titleTextStyle: titleTextStyle,
      systemOverlayStyle: systemOverlayStyle,
      forceMaterialTransparency: forceMaterialTransparency,
      clipBehavior: clipBehavior,
      shape: shape,
      notificationPredicate: notificationPredicate,
    );
  }
}

/// Tom wrapper for [BottomAppBar].
///
/// Adds ID, group, and authorization.
class TomBottomAppBar extends TomContainerBase {
  final Widget? child;
  final Color? color;
  final double? elevation;
  final NotchedShape? shape;
  final Clip clipBehavior;
  final double notchMargin;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final Color? shadowColor;
  final Color? surfaceTintColor;

  const TomBottomAppBar({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    this.color,
    this.elevation,
    this.shape,
    this.clipBehavior = Clip.none,
    this.notchMargin = 4.0,
    this.padding,
    this.height,
    this.shadowColor,
    this.surfaceTintColor,
  });

  @override
  Widget buildContent(BuildContext context) {
    return BottomAppBar(
      color: color,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      notchMargin: notchMargin,
      padding: padding,
      height: height,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      child: child,
    );
  }
}

/// Tom wrapper for [Divider].
///
/// Adds ID, group, and authorization.
class TomDivider extends TomContainerBase {
  final double? height;
  final double? thickness;
  final double? indent;
  final double? endIndent;
  final Color? color;

  const TomDivider({
    super.key,
    super.tomId,
    super.tomGroup,
    this.height,
    this.thickness,
    this.indent,
    this.endIndent,
    this.color,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Divider(
      height: height,
      thickness: thickness,
      indent: indent,
      endIndent: endIndent,
      color: color,
    );
  }
}
