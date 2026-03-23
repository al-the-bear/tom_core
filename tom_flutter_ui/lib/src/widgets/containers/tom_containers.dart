import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

// ────────────────────────────────────────────────────────────────────────────
// Layout containers
// ────────────────────────────────────────────────────────────────────────────

/// Tom wrapper for [Container].
class TomContainer extends TomContainerBase {
  final Widget? child;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Decoration? decoration;
  final Decoration? foregroundDecoration;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? margin;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;
  final Clip clipBehavior;
  final double? width;
  final double? height;

  const TomContainer({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    this.alignment,
    this.padding,
    this.color,
    this.decoration,
    this.foregroundDecoration,
    this.constraints,
    this.margin,
    this.transform,
    this.transformAlignment,
    this.clipBehavior = Clip.none,
    this.width,
    this.height,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: padding,
      color: color,
      decoration: decoration,
      foregroundDecoration: foregroundDecoration,
      constraints: constraints,
      margin: margin,
      transform: transform,
      transformAlignment: transformAlignment,
      clipBehavior: clipBehavior,
      width: width,
      height: height,
      child: child,
    );
  }
}

/// Tom wrapper for [Column].
class TomColumn extends TomContainerBase {
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline? textBaseline;
  final List<Widget> children;

  const TomColumn({
    super.key,
    super.tomId,
    super.tomGroup,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
    this.children = const [],
  });

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      children: children,
    );
  }
}

/// Tom wrapper for [Row].
class TomRow extends TomContainerBase {
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline? textBaseline;
  final List<Widget> children;

  const TomRow({
    super.key,
    super.tomId,
    super.tomGroup,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
    this.children = const [],
  });

  @override
  Widget buildContent(BuildContext context) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      children: children,
    );
  }
}

/// Tom wrapper for [Wrap].
class TomWrap extends TomContainerBase {
  final Axis direction;
  final WrapAlignment alignment;
  final double spacing;
  final WrapAlignment runAlignment;
  final double runSpacing;
  final WrapCrossAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final Clip clipBehavior;
  final List<Widget> children;

  const TomWrap({
    super.key,
    super.tomId,
    super.tomGroup,
    this.direction = Axis.horizontal,
    this.alignment = WrapAlignment.start,
    this.spacing = 0.0,
    this.runAlignment = WrapAlignment.start,
    this.runSpacing = 0.0,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.clipBehavior = Clip.none,
    this.children = const [],
  });

  @override
  Widget buildContent(BuildContext context) {
    return Wrap(
      direction: direction,
      alignment: alignment,
      spacing: spacing,
      runAlignment: runAlignment,
      runSpacing: runSpacing,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      clipBehavior: clipBehavior,
      children: children,
    );
  }
}

/// Tom wrapper for [Stack].
class TomStack extends TomContainerBase {
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;
  final StackFit fit;
  final Clip clipBehavior;
  final List<Widget> children;

  const TomStack({
    super.key,
    super.tomId,
    super.tomGroup,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.fit = StackFit.loose,
    this.clipBehavior = Clip.hardEdge,
    this.children = const [],
  });

  @override
  Widget buildContent(BuildContext context) {
    return Stack(
      alignment: alignment,
      textDirection: textDirection,
      fit: fit,
      clipBehavior: clipBehavior,
      children: children,
    );
  }
}

/// Tom wrapper for [IndexedStack].
class TomIndexedStack extends TomContainerBase {
  final int? index;
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;
  final StackFit sizing;
  final List<Widget> children;

  const TomIndexedStack({
    super.key,
    super.tomId,
    super.tomGroup,
    this.index = 0,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.sizing = StackFit.loose,
    this.children = const [],
  });

  @override
  Widget buildContent(BuildContext context) {
    return IndexedStack(
      index: index,
      alignment: alignment,
      textDirection: textDirection,
      sizing: sizing,
      children: children,
    );
  }
}

/// Tom wrapper for [SizedBox].
class TomSizedBox extends TomContainerBase {
  final double? width;
  final double? height;
  final Widget? child;

  const TomSizedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    this.width,
    this.height,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: child,
    );
  }
}

/// Tom wrapper for [ConstrainedBox].
class TomConstrainedBox extends TomContainerBase {
  final BoxConstraints constraints;
  final Widget? child;

  const TomConstrainedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.constraints,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return ConstrainedBox(
      constraints: constraints,
      child: child,
    );
  }
}

/// Tom wrapper for [Padding].
class TomPadding extends TomContainerBase {
  final EdgeInsetsGeometry padding;
  final Widget? child;

  const TomPadding({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.padding,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Padding(
      padding: padding,
      child: child,
    );
  }
}

/// Tom wrapper for [Center].
class TomCenter extends TomContainerBase {
  final double? widthFactor;
  final double? heightFactor;
  final Widget? child;

  const TomCenter({
    super.key,
    super.tomId,
    super.tomGroup,
    this.widthFactor,
    this.heightFactor,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Center(
      widthFactor: widthFactor,
      heightFactor: heightFactor,
      child: child,
    );
  }
}

/// Tom wrapper for [Align].
class TomAlign extends TomContainerBase {
  final AlignmentGeometry alignment;
  final double? widthFactor;
  final double? heightFactor;
  final Widget? child;

  const TomAlign({
    super.key,
    super.tomId,
    super.tomGroup,
    this.alignment = Alignment.center,
    this.widthFactor,
    this.heightFactor,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Align(
      alignment: alignment,
      widthFactor: widthFactor,
      heightFactor: heightFactor,
      child: child,
    );
  }
}

/// Tom wrapper for [AspectRatio].
class TomAspectRatio extends TomContainerBase {
  final double aspectRatio;
  final Widget? child;

  const TomAspectRatio({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.aspectRatio,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: child,
    );
  }
}

/// Tom wrapper for [FittedBox].
class TomFittedBox extends TomContainerBase {
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final Clip clipBehavior;
  final Widget? child;

  const TomFittedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.clipBehavior = Clip.none,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return FittedBox(
      fit: fit,
      alignment: alignment,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

/// Tom wrapper for [FractionallySizedBox].
class TomFractionallySizedBox extends TomContainerBase {
  final AlignmentGeometry alignment;
  final double? widthFactor;
  final double? heightFactor;
  final Widget? child;

  const TomFractionallySizedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    this.alignment = Alignment.center,
    this.widthFactor,
    this.heightFactor,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return FractionallySizedBox(
      alignment: alignment,
      widthFactor: widthFactor,
      heightFactor: heightFactor,
      child: child,
    );
  }
}

/// Tom wrapper for [IntrinsicHeight].
class TomIntrinsicHeight extends TomContainerBase {
  final Widget? child;

  const TomIntrinsicHeight({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return IntrinsicHeight(child: child);
  }
}

/// Tom wrapper for [IntrinsicWidth].
class TomIntrinsicWidth extends TomContainerBase {
  final double? stepWidth;
  final double? stepHeight;
  final Widget? child;

  const TomIntrinsicWidth({
    super.key,
    super.tomId,
    super.tomGroup,
    this.stepWidth,
    this.stepHeight,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return IntrinsicWidth(
      stepWidth: stepWidth,
      stepHeight: stepHeight,
      child: child,
    );
  }
}

/// Tom wrapper for [Material].
class TomMaterial extends TomContainerBase {
  final MaterialType type;
  final double elevation;
  final Color? color;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final TextStyle? textStyle;
  final BorderRadiusGeometry? borderRadius;
  final ShapeBorder? shape;
  final bool borderOnForeground;
  final Clip clipBehavior;
  final Duration animationDuration;
  final Widget? child;

  const TomMaterial({
    super.key,
    super.tomId,
    super.tomGroup,
    this.type = MaterialType.canvas,
    this.elevation = 0.0,
    this.color,
    this.shadowColor,
    this.surfaceTintColor,
    this.textStyle,
    this.borderRadius,
    this.shape,
    this.borderOnForeground = true,
    this.clipBehavior = Clip.none,
    this.animationDuration = kThemeChangeDuration,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Material(
      type: type,
      elevation: elevation,
      color: color,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      textStyle: textStyle,
      borderRadius: borderRadius,
      shape: shape,
      borderOnForeground: borderOnForeground,
      clipBehavior: clipBehavior,
      animationDuration: animationDuration,
      child: child,
    );
  }
}

/// Tom wrapper for [DecoratedBox].
class TomDecoratedBox extends TomContainerBase {
  final Decoration decoration;
  final DecorationPosition position;
  final Widget? child;

  const TomDecoratedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.decoration,
    this.position = DecorationPosition.background,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return DecoratedBox(
      decoration: decoration,
      position: position,
      child: child,
    );
  }
}

/// Tom wrapper for [ClipRRect].
class TomClipRRect extends TomContainerBase {
  final BorderRadiusGeometry borderRadius;
  final CustomClipper<RRect>? clipper;
  final Clip clipBehavior;
  final Widget? child;

  const TomClipRRect({
    super.key,
    super.tomId,
    super.tomGroup,
    this.borderRadius = BorderRadius.zero,
    this.clipper,
    this.clipBehavior = Clip.antiAlias,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      clipper: clipper,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

/// Tom wrapper for [ClipOval].
class TomClipOval extends TomContainerBase {
  final CustomClipper<Rect>? clipper;
  final Clip clipBehavior;
  final Widget? child;

  const TomClipOval({
    super.key,
    super.tomId,
    super.tomGroup,
    this.clipper,
    this.clipBehavior = Clip.antiAlias,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return ClipOval(
      clipper: clipper,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

/// Tom wrapper for [ClipRect].
class TomClipRect extends TomContainerBase {
  final CustomClipper<Rect>? clipper;
  final Clip clipBehavior;
  final Widget? child;

  const TomClipRect({
    super.key,
    super.tomId,
    super.tomGroup,
    this.clipper,
    this.clipBehavior = Clip.hardEdge,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return ClipRect(
      clipper: clipper,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

/// Tom wrapper for [Spacer].
class TomSpacer extends TomContainerBase {
  final int flex;

  const TomSpacer({
    super.key,
    super.tomId,
    super.tomGroup,
    this.flex = 1,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Spacer(flex: flex);
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Sliver containers
// ────────────────────────────────────────────────────────────────────────────

/// Tom wrapper for [SliverAppBar].
class TomSliverAppBar extends TomContainerBase {
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
  final double? expandedHeight;
  final double? collapsedHeight;
  final double toolbarHeight;
  final double? leadingWidth;
  final bool floating;
  final bool pinned;
  final bool snap;
  final bool stretch;
  final double stretchTriggerOffset;
  final ShapeBorder? shape;
  final TextStyle? toolbarTextStyle;
  final TextStyle? titleTextStyle;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final bool forceMaterialTransparency;
  final Clip? clipBehavior;

  const TomSliverAppBar({
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
    this.expandedHeight,
    this.collapsedHeight,
    this.toolbarHeight = kToolbarHeight,
    this.leadingWidth,
    this.floating = false,
    this.pinned = false,
    this.snap = false,
    this.stretch = false,
    this.stretchTriggerOffset = 100.0,
    this.shape,
    this.toolbarTextStyle,
    this.titleTextStyle,
    this.systemOverlayStyle,
    this.forceMaterialTransparency = false,
    this.clipBehavior,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTitle =
        titleText ?? (tomId != null ? resolveResource(context, 'label') : null);
    final effectiveTitle =
        title ?? (resolvedTitle != null ? Text(resolvedTitle) : null);

    return SliverAppBar(
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
      expandedHeight: expandedHeight,
      collapsedHeight: collapsedHeight,
      toolbarHeight: toolbarHeight,
      leadingWidth: leadingWidth,
      floating: floating,
      pinned: pinned,
      snap: snap,
      stretch: stretch,
      stretchTriggerOffset: stretchTriggerOffset,
      shape: shape,
      toolbarTextStyle: toolbarTextStyle,
      titleTextStyle: titleTextStyle,
      systemOverlayStyle: systemOverlayStyle,
      forceMaterialTransparency: forceMaterialTransparency,
      clipBehavior: clipBehavior,
    );
  }
}

/// Tom wrapper for [SliverToBoxAdapter].
class TomSliverToBoxAdapter extends TomContainerBase {
  final Widget? child;

  const TomSliverToBoxAdapter({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SliverToBoxAdapter(child: child);
  }
}

/// Tom wrapper for [SliverList].
class TomSliverList extends TomContainerBase {
  final SliverChildDelegate delegate;

  const TomSliverList({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.delegate,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SliverList(delegate: delegate);
  }
}

/// Tom wrapper for [SliverGrid].
class TomSliverGrid extends TomContainerBase {
  final SliverChildDelegate delegate;
  final SliverGridDelegate gridDelegate;

  const TomSliverGrid({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.delegate,
    required this.gridDelegate,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SliverGrid(
      delegate: delegate,
      gridDelegate: gridDelegate,
    );
  }
}

/// Tom wrapper for [SliverFillRemaining].
class TomSliverFillRemaining extends TomContainerBase {
  final Widget? child;
  final bool hasScrollBody;
  final bool fillOverscroll;

  const TomSliverFillRemaining({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    this.hasScrollBody = true,
    this.fillOverscroll = false,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: hasScrollBody,
      fillOverscroll: fillOverscroll,
      child: child,
    );
  }
}

/// Tom wrapper for [CustomScrollView].
class TomCustomScrollView extends TomContainerBase {
  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;
  final ScrollBehavior? scrollBehavior;
  final bool shrinkWrap;
  final Key? center;
  final double anchor;
  final double? cacheExtent;
  final List<Widget> slivers;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;

  const TomCustomScrollView({
    super.key,
    super.tomId,
    super.tomGroup,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.scrollBehavior,
    this.shrinkWrap = false,
    this.center,
    this.anchor = 0.0,
    this.cacheExtent,
    this.slivers = const [],
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CustomScrollView(
      scrollDirection: scrollDirection,
      reverse: reverse,
      controller: controller,
      primary: primary,
      physics: physics,
      scrollBehavior: scrollBehavior,
      shrinkWrap: shrinkWrap,
      center: center,
      anchor: anchor,
      cacheExtent: cacheExtent,
      slivers: slivers,
      semanticChildCount: semanticChildCount,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: restorationId,
      clipBehavior: clipBehavior,
    );
  }
}
