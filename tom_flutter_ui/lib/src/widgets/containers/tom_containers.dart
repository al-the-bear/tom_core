import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../groups/tom_widget_mixin.dart';
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
    final resolvedTitle = titleText ?? resolveResourceOrFail(context, 'label');
    final titleWidget = title ?? Text(resolvedTitle);

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
///
/// Implements [PreferredSizeWidget] for use in [Scaffold.appBar].
class TomAppBar extends StatelessWidget
    with TomWidgetMixin
    implements PreferredSizeWidget {
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

  @override
  final String? tomId;
  @override
  final String? tomGroup;

  const TomAppBar({
    super.key,
    this.tomId,
    this.tomGroup,
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
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0.0;
    return Size.fromHeight((toolbarHeight ?? kToolbarHeight) + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final resolvedTitle =
        titleText ?? (tomId != null ? getText(context, 'label') : null);
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
    final resolvedTitle = titleText ?? resolveResourceOrFail(context, 'label');
    final effectiveTitle = title ?? Text(resolvedTitle);

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

/// Tom equivalent for [ExpansionPanel] (non-widget data class).
///
/// ExpansionPanel is not a widget — it's a data class for ExpansionPanelList.
/// This class mirrors ExpansionPanel's API and adds Tom ID support for
/// resource resolution and authorization tracking.
///
/// Usage:
/// ```dart
/// TomExpansionPanelList(
///   children: [
///     TomExpansionPanel(
///       tomId: 'basicInfo',
///       headerBuilder: (context, isExpanded) => Text('Basic Info'),
///       body: MyBodyWidget(),
///     ).toPanel(),
///   ],
/// )
/// ```
class TomExpansionPanel {
  /// Tom ID for resource resolution and authorization.
  final String? tomId;

  /// Optional group membership.
  final String? tomGroup;

  /// Callback that builds the header widget.
  final ExpansionPanelHeaderBuilder headerBuilder;

  /// The body content when expanded.
  final Widget body;

  /// Whether the panel is expanded.
  final bool isExpanded;

  /// Whether tapping the header toggles expansion.
  final bool canTapOnHeader;

  /// Background color of the panel.
  final Color? backgroundColor;

  /// Splash color when tapping the header.
  final Color? splashColor;

  /// Highlight color when tapping the header.
  final Color? highlightColor;

  const TomExpansionPanel({
    this.tomId,
    this.tomGroup,
    required this.headerBuilder,
    required this.body,
    this.isExpanded = false,
    this.canTapOnHeader = false,
    this.backgroundColor,
    this.splashColor,
    this.highlightColor,
  });

  /// Converts this to a Flutter [ExpansionPanel].
  ExpansionPanel toPanel() {
    return ExpansionPanel(
      headerBuilder: headerBuilder,
      body: body,
      isExpanded: isExpanded,
      canTapOnHeader: canTapOnHeader,
      backgroundColor: backgroundColor,
      splashColor: splashColor,
      highlightColor: highlightColor,
    );
  }
}

/// Tom wrapper for [ExpansionPanelList].
///
/// Adds ID, group, authorization, and resource resolution.
/// Accepts either raw [ExpansionPanel] or [TomExpansionPanel] via the
/// [tomChildren] constructor.
class TomExpansionPanelList extends TomContainerBase {
  final List<ExpansionPanel> children;
  final ExpansionPanelCallback? expansionCallback;
  final Duration animationDuration;
  final EdgeInsets expandedHeaderPadding;
  final Color? dividerColor;
  final double elevation;

  const TomExpansionPanelList({
    super.key,
    super.tomId,
    super.tomGroup,
    this.children = const [],
    this.expansionCallback,
    this.animationDuration = kThemeAnimationDuration,
    this.expandedHeaderPadding = const EdgeInsets.symmetric(vertical: 16.0),
    this.dividerColor,
    this.elevation = 2,
  });

  @override
  Widget buildContent(BuildContext context) {
    return ExpansionPanelList(
      children: children,
      expansionCallback: expansionCallback,
      animationDuration: animationDuration,
      expandedHeaderPadding: expandedHeaderPadding,
      dividerColor: dividerColor,
      elevation: elevation,
    );
  }
}

/// Tom wrapper for [Ink].
///
/// A convenience widget for drawing images and other decorations on
/// [Material] widgets, so that [InkWell] and [InkResponse] splashes
/// render correctly. Adds ID, group, authorization, and resource resolution.
class TomInk extends TomContainerBase {
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Decoration? decoration;
  final double? width;
  final double? height;
  final Widget? child;

  const TomInk({
    super.key,
    super.tomId,
    super.tomGroup,
    this.padding,
    this.color,
    this.decoration,
    this.width,
    this.height,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Ink(
      padding: padding,
      color: color,
      decoration: decoration,
      width: width,
      height: height,
      child: child,
    );
  }
}

// ============================================================================
// EXTENSION-BASED WIDGETS (extends Flutter widget + TomWidgetMixin)
// These preserve type identity for Flutter's runtime `is`-checks.
// ============================================================================

/// Tom widget that EXTENDS [Expanded] with authorization.
///
/// This widget IS an [Expanded] (and IS a [Flexible]) — it passes `is Expanded`
/// and `is Flexible` checks for use in [Row], [Column], and [Flex].
///
/// **ParentDataWidget pattern:**
/// - ParentDataWidgets have no `build()` method — they apply parent data
/// - The mixin adds `tomId` for identification
/// - Visibility is controlled by the **parent container** filtering its children
///
/// ```dart
/// TomRow(
///   tomId: 'mainRow',
///   children: [
///     TomExpanded(tomId: 'content', child: ContentWidget()),
///     TomExpanded(tomId: 'sidebar', child: SidebarWidget()),
///   ],
/// )
/// ```
class TomExpanded extends Expanded with TomWidgetMixin {
  /// Creates a Tom Expanded widget.
  const TomExpanded({
    this.tomId,
    this.tomGroup,
    super.key,
    super.flex,
    required super.child,
  });

  @override
  final String? tomId;

  @override
  final String? tomGroup;
}

/// Tom widget that EXTENDS [Flexible] with authorization.
///
/// This widget IS a [Flexible] — it passes `is Flexible` checks.
///
/// ```dart
/// TomRow(
///   tomId: 'flexRow',
///   children: [
///     TomFlexible(tomId: 'flex1', flex: 2, child: Widget1()),
///     TomFlexible(tomId: 'flex2', flex: 1, child: Widget2()),
///   ],
/// )
/// ```
class TomFlexible extends Flexible with TomWidgetMixin {
  /// Creates a Tom Flexible widget.
  const TomFlexible({
    this.tomId,
    this.tomGroup,
    super.key,
    super.flex,
    super.fit,
    required super.child,
  });

  @override
  final String? tomId;

  @override
  final String? tomGroup;
}

/// Tom widget that EXTENDS [Spacer] with authorization.
///
/// This widget IS a [Spacer] — it passes `is Spacer` checks.
/// Spacer creates empty space in a Flex layout.
///
/// ```dart
/// Row(children: [
///   Text('Left'),
///   TomSpacer(tomId: 'spacer1'),
///   Text('Right'),
/// ])
/// ```
class TomSpacer extends Spacer with TomWidgetMixin {
  /// Creates a Tom Spacer widget.
  const TomSpacer({
    this.tomId,
    this.tomGroup,
    super.key,
    super.flex,
  });

  @override
  final String? tomId;

  @override
  final String? tomGroup;
}

/// Tom widget that EXTENDS [Positioned] with authorization.
///
/// This widget IS a [Positioned] — it passes `is Positioned` checks for use
/// in [Stack].
///
/// ```dart
/// TomStack(
///   tomId: 'overlayStack',
///   children: [
///     TomPositioned(tomId: 'badge', top: 0, right: 0, child: Badge()),
///   ],
/// )
/// ```
class TomPositioned extends Positioned with TomWidgetMixin {
  /// Creates a Tom Positioned widget.
  const TomPositioned({
    this.tomId,
    this.tomGroup,
    super.key,
    super.left,
    super.top,
    super.right,
    super.bottom,
    super.width,
    super.height,
    required super.child,
  });

  /// Creates a Tom Positioned widget that fills the Stack.
  const TomPositioned.fill({
    this.tomId,
    this.tomGroup,
    super.key,
    super.left = 0.0,
    super.top = 0.0,
    super.right = 0.0,
    super.bottom = 0.0,
    required super.child,
  });

  @override
  final String? tomId;

  @override
  final String? tomGroup;
}

/// Tom widget that EXTENDS [PositionedDirectional] with authorization.
///
/// This widget IS a [Positioned] — RTL-aware positioning in [Stack].
class TomPositionedDirectional extends PositionedDirectional
    with TomWidgetMixin {
  /// Creates a Tom PositionedDirectional widget.
  const TomPositionedDirectional({
    this.tomId,
    this.tomGroup,
    super.key,
    super.start,
    super.top,
    super.end,
    super.bottom,
    super.width,
    super.height,
    required super.child,
  });

  @override
  final String? tomId;

  @override
  final String? tomGroup;
}

/// Tom widget that EXTENDS [TableCell] with authorization.
///
/// This widget IS a [TableCell] — used in [Table] with vertical alignment.
class TomTableCell extends TableCell with TomWidgetMixin {
  /// Creates a Tom TableCell widget.
  const TomTableCell({
    this.tomId,
    this.tomGroup,
    super.key,
    super.verticalAlignment,
    required super.child,
  });

  @override
  final String? tomId;

  @override
  final String? tomGroup;
}

// ============================================================================
// Section II Containers — Layout widgets, Cupertino scaffolds, effects
// ============================================================================

/// Tom wrapper for [SafeArea].
///
/// Insets child to avoid system intrusions. Auth can hide safe-area content.
class TomSafeArea extends TomContainerBase {
  final bool left;
  final bool top;
  final bool right;
  final bool bottom;
  final EdgeInsets minimum;
  final bool maintainBottomViewPadding;
  final Widget child;

  const TomSafeArea({
    super.key,
    super.tomId,
    super.tomGroup,
    this.left = true,
    this.top = true,
    this.right = true,
    this.bottom = true,
    this.minimum = EdgeInsets.zero,
    this.maintainBottomViewPadding = false,
    required this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SafeArea(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      minimum: minimum,
      maintainBottomViewPadding: maintainBottomViewPadding,
      child: child,
    );
  }
}

/// Tom wrapper for [SingleChildScrollView].
///
/// Scrollable container for a single child. Auth on scrollable content.
class TomSingleChildScrollView extends TomContainerBase {
  final Axis scrollDirection;
  final bool reverse;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final Widget? child;
  final DragStartBehavior dragStartBehavior;
  final Clip clipBehavior;
  final String? restorationId;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  const TomSingleChildScrollView({
    super.key,
    super.tomId,
    super.tomGroup,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.padding,
    this.physics,
    this.controller,
    this.child,
    this.dragStartBehavior = DragStartBehavior.start,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: scrollDirection,
      reverse: reverse,
      padding: padding,
      physics: physics,
      controller: controller,
      dragStartBehavior: dragStartBehavior,
      clipBehavior: clipBehavior,
      restorationId: restorationId,
      keyboardDismissBehavior: keyboardDismissBehavior,
      child: child,
    );
  }
}

/// Tom wrapper for [CarouselView].
///
/// Horizontal carousel/slider. Auth on carousel sections.
class TomCarouselView extends TomContainerBase {
  final List<Widget> children;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final double? elevation;
  final ShapeBorder? shape;
  final Clip? overlayColor;
  final double? itemExtent;
  final double shrinkExtent;
  final CarouselController? controller;
  final Axis scrollDirection;
  final bool reverse;
  final ValueChanged<int>? onTap;

  const TomCarouselView({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.children,
    this.padding,
    this.backgroundColor,
    this.elevation,
    this.shape,
    this.overlayColor,
    this.itemExtent,
    this.shrinkExtent = 0.0,
    this.controller,
    this.scrollDirection = Axis.horizontal,
    this.reverse = false,
    this.onTap,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CarouselView(
      padding: padding,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      itemExtent: itemExtent ?? 200.0,
      shrinkExtent: shrinkExtent,
      controller: controller,
      scrollDirection: scrollDirection,
      reverse: reverse,
      onTap: onTap,
      children: children,
    );
  }
}

/// Tom wrapper for [Visibility].
///
/// Logical visibility control. Natural fit for auth show/hide.
class TomVisibility extends TomContainerBase {
  final Widget child;
  final Widget replacement;
  final bool visible;
  final bool maintainState;
  final bool maintainAnimation;
  final bool maintainSize;
  final bool maintainSemantics;
  final bool maintainInteractivity;

  const TomVisibility({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.child,
    this.replacement = const SizedBox.shrink(),
    this.visible = true,
    this.maintainState = false,
    this.maintainAnimation = false,
    this.maintainSize = false,
    this.maintainSemantics = false,
    this.maintainInteractivity = false,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Visibility(
      replacement: replacement,
      visible: visible,
      maintainState: maintainState,
      maintainAnimation: maintainAnimation,
      maintainSize: maintainSize,
      maintainSemantics: maintainSemantics,
      maintainInteractivity: maintainInteractivity,
      child: child,
    );
  }
}

/// Tom wrapper for [Offstage].
///
/// Keeps widget in tree but hidden. Natural auth fit.
class TomOffstage extends TomContainerBase {
  final bool offstage;
  final Widget? child;

  const TomOffstage({
    super.key,
    super.tomId,
    super.tomGroup,
    this.offstage = true,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Offstage(
      offstage: offstage,
      child: child,
    );
  }
}

/// Tom wrapper for [CupertinoPageScaffold].
///
/// Cupertino page scaffold. Auth on page regions.
class TomCupertinoPageScaffold extends TomContainerBase {
  final ObstructingPreferredSizeWidget? navigationBar;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final Widget child;

  const TomCupertinoPageScaffold({
    super.key,
    super.tomId,
    super.tomGroup,
    this.navigationBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    required this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: navigationBar,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      child: child,
    );
  }
}

/// Tom wrapper for [CupertinoTabScaffold].
///
/// Cupertino tab scaffold. Auth can control tab access.
class TomCupertinoTabScaffold extends TomContainerBase {
  final CupertinoTabBar tabBar;
  final IndexedWidgetBuilder tabBuilder;
  final CupertinoTabController? controller;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final String? restorationId;

  const TomCupertinoTabScaffold({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.tabBar,
    required this.tabBuilder,
    this.controller,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.restorationId,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: tabBar,
      tabBuilder: tabBuilder,
      controller: controller,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      restorationId: restorationId,
    );
  }
}

/// Tom wrapper for [CupertinoFormRow].
///
/// Cupertino form layout row. Auth on form field regions.
class TomCupertinoFormRow extends TomContainerBase {
  final Widget child;
  final Widget? prefix;
  final EdgeInsetsGeometry? padding;
  final Widget? helper;
  final Widget? error;

  const TomCupertinoFormRow({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.child,
    this.prefix,
    this.padding,
    this.helper,
    this.error,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoFormRow(
      prefix: prefix,
      padding: padding,
      helper: helper,
      error: error,
      child: child,
    );
  }
}

/// Tom wrapper for [CupertinoFormSection].
///
/// Cupertino form section. Auth can hide entire form sections.
class TomCupertinoFormSection extends TomContainerBase {
  final List<Widget> children;
  final Widget? header;
  final Widget? footer;
  final EdgeInsetsGeometry margin;
  final Color? backgroundColor;
  final BoxDecoration? decoration;
  final Clip clipBehavior;
  final bool insetGrouped;

  const TomCupertinoFormSection({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.children,
    this.header,
    this.footer,
    this.margin = EdgeInsets.zero,
    this.backgroundColor,
    this.decoration,
    this.clipBehavior = Clip.none,
    this.insetGrouped = false,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedBgColor = backgroundColor ?? CupertinoColors.systemGroupedBackground.resolveFrom(context);
    if (insetGrouped) {
      return CupertinoFormSection.insetGrouped(
        header: header,
        footer: footer,
        margin: margin,
        backgroundColor: resolvedBgColor,
        decoration: decoration,
        clipBehavior: clipBehavior,
        children: children,
      );
    }
    return CupertinoFormSection(
      header: header,
      footer: footer,
      margin: margin,
      backgroundColor: resolvedBgColor,
      decoration: decoration,
      clipBehavior: clipBehavior,
      children: children,
    );
  }
}

/// Tom wrapper for [NestedScrollView].
///
/// Scroll coordination between header slivers and body. Auth on content.
class TomNestedScrollView extends TomContainerBase {
  final ScrollController? controller;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollPhysics? physics;
  final NestedScrollViewHeaderSliversBuilder headerSliverBuilder;
  final Widget body;
  final DragStartBehavior dragStartBehavior;
  final bool floatHeaderSlivers;
  final Clip clipBehavior;
  final String? restorationId;
  final ScrollBehavior? scrollBehavior;

  const TomNestedScrollView({
    super.key,
    super.tomId,
    super.tomGroup,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics,
    required this.headerSliverBuilder,
    required this.body,
    this.dragStartBehavior = DragStartBehavior.start,
    this.floatHeaderSlivers = false,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.scrollBehavior,
  });

  @override
  Widget buildContent(BuildContext context) {
    return NestedScrollView(
      controller: controller,
      scrollDirection: scrollDirection,
      reverse: reverse,
      physics: physics,
      headerSliverBuilder: headerSliverBuilder,
      body: body,
      dragStartBehavior: dragStartBehavior,
      floatHeaderSlivers: floatHeaderSlivers,
      clipBehavior: clipBehavior,
      restorationId: restorationId,
      scrollBehavior: scrollBehavior,
    );
  }
}

/// Tom wrapper for [Scrollbar].
///
/// Visual scroll position indicator. Auth on scrollbar visibility.
class TomScrollbar extends TomContainerBase {
  final Widget child;
  final ScrollController? controller;
  final bool? thumbVisibility;
  final bool? trackVisibility;
  final double? thickness;
  final Radius? radius;
  final ScrollNotificationPredicate? notificationPredicate;
  final bool? interactive;
  final ScrollbarOrientation? scrollbarOrientation;

  const TomScrollbar({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.child,
    this.controller,
    this.thumbVisibility,
    this.trackVisibility,
    this.thickness,
    this.radius,
    this.notificationPredicate,
    this.interactive,
    this.scrollbarOrientation,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Scrollbar(
      controller: controller,
      thumbVisibility: thumbVisibility,
      trackVisibility: trackVisibility,
      thickness: thickness,
      radius: radius,
      notificationPredicate: notificationPredicate,
      interactive: interactive,
      scrollbarOrientation: scrollbarOrientation,
      child: child,
    );
  }
}

/// Tom wrapper for [CupertinoScrollbar].
///
/// Cupertino-styled scrollbar. Auth on scrollbar visibility.
class TomCupertinoScrollbar extends TomContainerBase {
  final Widget child;
  final ScrollController? controller;
  final bool? thumbVisibility;
  final double thickness;
  final double thicknessWhileDragging;
  final Radius radius;
  final Radius radiusWhileDragging;
  final ScrollNotificationPredicate? notificationPredicate;

  const TomCupertinoScrollbar({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.child,
    this.controller,
    this.thumbVisibility,
    this.thickness = CupertinoScrollbar.defaultThickness,
    this.thicknessWhileDragging = CupertinoScrollbar.defaultThicknessWhileDragging,
    this.radius = CupertinoScrollbar.defaultRadius,
    this.radiusWhileDragging = CupertinoScrollbar.defaultRadiusWhileDragging,
    this.notificationPredicate,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoScrollbar(
      controller: controller,
      thumbVisibility: thumbVisibility,
      thickness: thickness,
      thicknessWhileDragging: thicknessWhileDragging,
      radius: radius,
      radiusWhileDragging: radiusWhileDragging,
      notificationPredicate: notificationPredicate,
      child: child,
    );
  }
}

/// Tom wrapper for [DraggableScrollableSheet].
///
/// Bottom sheet with drag-to-expand. Auth controls sheet access.
class TomDraggableScrollableSheet extends TomContainerBase {
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final bool expand;
  final bool snap;
  final List<double>? snapSizes;
  final double? snapAnimationDuration;
  final DraggableScrollableController? controller;
  final bool shouldCloseOnMinExtent;
  final ScrollableWidgetBuilder builder;

  const TomDraggableScrollableSheet({
    super.key,
    super.tomId,
    super.tomGroup,
    this.initialChildSize = 0.5,
    this.minChildSize = 0.25,
    this.maxChildSize = 1.0,
    this.expand = true,
    this.snap = false,
    this.snapSizes,
    this.snapAnimationDuration,
    this.controller,
    this.shouldCloseOnMinExtent = true,
    required this.builder,
  });

  @override
  Widget buildContent(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      expand: expand,
      snap: snap,
      snapSizes: snapSizes,
      controller: controller,
      shouldCloseOnMinExtent: shouldCloseOnMinExtent,
      builder: builder,
    );
  }
}

/// Tom wrapper for [InteractiveViewer].
///
/// Pan/zoom viewport for child content. Auth can restrict zoom/pan.
class TomInteractiveViewer extends TomContainerBase {
  final Clip clipBehavior;
  final PanAxis panAxis;
  final EdgeInsets boundaryMargin;
  final bool constrained;
  final double maxScale;
  final double minScale;
  final double interactionEndFrictionCoefficient;
  final GestureScaleEndCallback? onInteractionEnd;
  final GestureScaleStartCallback? onInteractionStart;
  final GestureScaleUpdateCallback? onInteractionUpdate;
  final bool panEnabled;
  final bool scaleEnabled;
  final double scaleFactor;
  final TransformationController? transformationController;
  final Alignment alignment;
  final Widget child;

  const TomInteractiveViewer({
    super.key,
    super.tomId,
    super.tomGroup,
    this.clipBehavior = Clip.hardEdge,
    this.panAxis = PanAxis.free,
    this.boundaryMargin = EdgeInsets.zero,
    this.constrained = true,
    this.maxScale = 2.5,
    this.minScale = 0.8,
    this.interactionEndFrictionCoefficient = 0.0000135,
    this.onInteractionEnd,
    this.onInteractionStart,
    this.onInteractionUpdate,
    this.panEnabled = true,
    this.scaleEnabled = true,
    this.scaleFactor = kDefaultMouseScrollToScaleFactor,
    this.transformationController,
    this.alignment = Alignment.topLeft,
    required this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return InteractiveViewer(
      clipBehavior: clipBehavior,
      panAxis: panAxis,
      boundaryMargin: boundaryMargin,
      constrained: constrained,
      maxScale: maxScale,
      minScale: minScale,
      interactionEndFrictionCoefficient: interactionEndFrictionCoefficient,
      onInteractionEnd: onInteractionEnd,
      onInteractionStart: onInteractionStart,
      onInteractionUpdate: onInteractionUpdate,
      panEnabled: panEnabled,
      scaleEnabled: scaleEnabled,
      scaleFactor: scaleFactor,
      transformationController: transformationController,
      alignment: alignment,
      child: child,
    );
  }
}

/// Tom wrapper for [ClipPath].
///
/// Clips child to arbitrary path. Auth on clipped content.
class TomClipPath extends TomContainerBase {
  final CustomClipper<Path>? clipper;
  final Clip clipBehavior;
  final Widget? child;

  const TomClipPath({
    super.key,
    super.tomId,
    super.tomGroup,
    this.clipper,
    this.clipBehavior = Clip.antiAlias,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return ClipPath(
      clipper: clipper,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

/// Tom wrapper for [ColoredBox].
///
/// Single solid-color background with child. Auth on content.
class TomColoredBox extends TomContainerBase {
  final Color color;
  final Widget? child;

  const TomColoredBox({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.color,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return ColoredBox(
      color: color,
      child: child,
    );
  }
}

/// Tom wrapper for [Opacity].
///
/// Visual opacity 0.0–1.0. Auth on content.
class TomOpacity extends TomContainerBase {
  final double opacity;
  final bool alwaysIncludeSemantics;
  final Widget? child;

  const TomOpacity({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.opacity,
    this.alwaysIncludeSemantics = false,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Opacity(
      opacity: opacity,
      alwaysIncludeSemantics: alwaysIncludeSemantics,
      child: child,
    );
  }
}

/// Tom wrapper for [Transform].
///
/// 2D/3D matrix transform with child. Auth on transformed content.
class TomTransform extends TomContainerBase {
  final Matrix4 transform;
  final Offset? origin;
  final AlignmentGeometry? alignment;
  final bool transformHitTests;
  final FilterQuality? filterQuality;
  final Widget? child;

  const TomTransform({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.transform,
    this.origin,
    this.alignment,
    this.transformHitTests = true,
    this.filterQuality,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Transform(
      transform: transform,
      origin: origin,
      alignment: alignment,
      transformHitTests: transformHitTests,
      filterQuality: filterQuality,
      child: child,
    );
  }
}

/// Tom wrapper for [RotatedBox].
///
/// Quarter-turn rotation with child. Auth on rotated content.
class TomRotatedBox extends TomContainerBase {
  final int quarterTurns;
  final Widget? child;

  const TomRotatedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.quarterTurns,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return RotatedBox(
      quarterTurns: quarterTurns,
      child: child,
    );
  }
}

/// Tom wrapper for [OverflowBar].
///
/// Wrapping row that overflows to column (ButtonBar replacement). Auth on children.
class TomOverflowBar extends TomContainerBase {
  final double spacing;
  final MainAxisAlignment? alignment;
  final double overflowSpacing;
  final OverflowBarAlignment overflowAlignment;
  final VerticalDirection overflowDirection;
  final TextDirection? textDirection;
  final List<Widget> children;

  const TomOverflowBar({
    super.key,
    super.tomId,
    super.tomGroup,
    this.spacing = 0.0,
    this.alignment,
    this.overflowSpacing = 0.0,
    this.overflowAlignment = OverflowBarAlignment.start,
    this.overflowDirection = VerticalDirection.down,
    this.textDirection,
    this.children = const <Widget>[],
  });

  @override
  Widget buildContent(BuildContext context) {
    return OverflowBar(
      spacing: spacing,
      alignment: alignment,
      overflowSpacing: overflowSpacing,
      overflowAlignment: overflowAlignment,
      overflowDirection: overflowDirection,
      textDirection: textDirection,
      children: children,
    );
  }
}

/// Tom wrapper for [OverflowBox].
///
/// Allows child to exceed parent constraints. Auth on content.
class TomOverflowBox extends TomContainerBase {
  final AlignmentGeometry alignment;
  final double? minWidth;
  final double? maxWidth;
  final double? minHeight;
  final double? maxHeight;
  final OverflowBoxFit fit;
  final Widget? child;

  const TomOverflowBox({
    super.key,
    super.tomId,
    super.tomGroup,
    this.alignment = Alignment.center,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.fit = OverflowBoxFit.max,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return OverflowBox(
      alignment: alignment,
      minWidth: minWidth,
      maxWidth: maxWidth,
      minHeight: minHeight,
      maxHeight: maxHeight,
      fit: fit,
      child: child,
    );
  }
}

/// Tom wrapper for [SizedOverflowBox].
///
/// Fixed size with unconstrained child. Auth on content.
class TomSizedOverflowBox extends TomContainerBase {
  final Size size;
  final AlignmentGeometry alignment;
  final Widget? child;

  const TomSizedOverflowBox({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.size,
    this.alignment = Alignment.center,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SizedOverflowBox(
      size: size,
      alignment: alignment,
      child: child,
    );
  }
}

/// Tom wrapper for [UnconstrainedBox].
///
/// Removes parent constraints from child. Auth on content.
class TomUnconstrainedBox extends TomContainerBase {
  final TextDirection? textDirection;
  final AlignmentGeometry alignment;
  final Axis? constrainedAxis;
  final Clip clipBehavior;
  final Widget? child;

  const TomUnconstrainedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    this.textDirection,
    this.alignment = Alignment.center,
    this.constrainedAxis,
    this.clipBehavior = Clip.none,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return UnconstrainedBox(
      textDirection: textDirection,
      alignment: alignment,
      constrainedAxis: constrainedAxis,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

/// Tom wrapper for [ConstraintsTransformBox].
///
/// Transforms incoming constraints. Auth on content.
class TomConstraintsTransformBox extends TomContainerBase {
  final TextDirection? textDirection;
  final AlignmentGeometry alignment;
  final BoxConstraintsTransform constraintsTransform;
  final Clip clipBehavior;
  final String debugTransformType;
  final Widget? child;

  const TomConstraintsTransformBox({
    super.key,
    super.tomId,
    super.tomGroup,
    this.textDirection,
    this.alignment = Alignment.center,
    required this.constraintsTransform,
    this.clipBehavior = Clip.none,
    this.debugTransformType = '',
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return ConstraintsTransformBox(
      textDirection: textDirection,
      alignment: alignment,
      constraintsTransform: constraintsTransform,
      clipBehavior: clipBehavior,
      debugTransformType: debugTransformType,
      child: child,
    );
  }
}

/// Tom wrapper for [LimitedBox].
///
/// Limits child size when unconstrained. Auth on content.
class TomLimitedBox extends TomContainerBase {
  final double maxWidth;
  final double maxHeight;
  final Widget? child;

  const TomLimitedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    this.maxWidth = double.infinity,
    this.maxHeight = double.infinity,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return LimitedBox(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      child: child,
    );
  }
}

/// Tom wrapper for [Baseline].
///
/// Aligns child by text baseline. Auth on content.
class TomBaseline extends TomContainerBase {
  final double baseline;
  final TextBaseline baselineType;
  final Widget? child;

  const TomBaseline({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.baseline,
    required this.baselineType,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Baseline(
      baseline: baseline,
      baselineType: baselineType,
      child: child,
    );
  }
}

/// Tom wrapper for [ListBody].
///
/// Linear layout for dialog body lists. Auth on list content.
class TomListBody extends TomContainerBase {
  final Axis mainAxis;
  final bool reverse;
  final List<Widget> children;

  const TomListBody({
    super.key,
    super.tomId,
    super.tomGroup,
    this.mainAxis = Axis.vertical,
    this.reverse = false,
    this.children = const <Widget>[],
  });

  @override
  Widget buildContent(BuildContext context) {
    return ListBody(
      mainAxis: mainAxis,
      reverse: reverse,
      children: children,
    );
  }
}

/// Tom wrapper for [Flow].
///
/// Delegate-based custom flow layout. Auth on flow children.
class TomFlow extends TomContainerBase {
  final FlowDelegate delegate;
  final Clip clipBehavior;
  final List<Widget> children;

  const TomFlow({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.delegate,
    this.clipBehavior = Clip.hardEdge,
    this.children = const <Widget>[],
  });

  @override
  Widget buildContent(BuildContext context) {
    return Flow(
      delegate: delegate,
      clipBehavior: clipBehavior,
      children: children,
    );
  }
}

/// Tom wrapper for [CustomMultiChildLayout].
///
/// Delegate-based positioned layout. Auth on positioned children.
class TomCustomMultiChildLayout extends TomContainerBase {
  final MultiChildLayoutDelegate delegate;
  final List<Widget> children;

  const TomCustomMultiChildLayout({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.delegate,
    this.children = const <Widget>[],
  });

  @override
  Widget buildContent(BuildContext context) {
    return CustomMultiChildLayout(
      delegate: delegate,
      children: children,
    );
  }
}

/// Tom wrapper for [CustomSingleChildLayout].
///
/// Delegate-based single-child layout. Auth on content.
class TomCustomSingleChildLayout extends TomContainerBase {
  final SingleChildLayoutDelegate delegate;
  final Widget? child;

  const TomCustomSingleChildLayout({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.delegate,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CustomSingleChildLayout(
      delegate: delegate,
      child: child,
    );
  }
}

/// Tom wrapper for [CustomPaint].
///
/// Custom painting with optional child. Auth on painted content.
class TomCustomPaint extends TomContainerBase {
  final CustomPainter? painter;
  final CustomPainter? foregroundPainter;
  final Size size;
  final bool isComplex;
  final bool willChange;
  final Widget? child;

  const TomCustomPaint({
    super.key,
    super.tomId,
    super.tomGroup,
    this.painter,
    this.foregroundPainter,
    this.size = Size.zero,
    this.isComplex = false,
    this.willChange = false,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CustomPaint(
      painter: painter,
      foregroundPainter: foregroundPainter,
      size: size,
      isComplex: isComplex,
      willChange: willChange,
      child: child,
    );
  }
}

/// Tom wrapper for [PhysicalModel].
///
/// Box with shadow/elevation and child. Auth on elevated content.
class TomPhysicalModel extends TomContainerBase {
  final BoxShape shape;
  final Clip clipBehavior;
  final BorderRadius? borderRadius;
  final double elevation;
  final Color color;
  final Color shadowColor;
  final Widget? child;

  const TomPhysicalModel({
    super.key,
    super.tomId,
    super.tomGroup,
    this.shape = BoxShape.rectangle,
    this.clipBehavior = Clip.none,
    this.borderRadius,
    this.elevation = 0.0,
    required this.color,
    this.shadowColor = const Color(0xFF000000),
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return PhysicalModel(
      shape: shape,
      clipBehavior: clipBehavior,
      borderRadius: borderRadius,
      elevation: elevation,
      color: color,
      shadowColor: shadowColor,
      child: child,
    );
  }
}

/// Tom wrapper for [PhysicalShape].
///
/// Custom-shaped shadow/elevation with child. Auth on shaped content.
class TomPhysicalShape extends TomContainerBase {
  final CustomClipper<Path> clipper;
  final Clip clipBehavior;
  final double elevation;
  final Color color;
  final Color shadowColor;
  final Widget? child;

  const TomPhysicalShape({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.clipper,
    this.clipBehavior = Clip.none,
    this.elevation = 0.0,
    required this.color,
    this.shadowColor = const Color(0xFF000000),
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return PhysicalShape(
      clipper: clipper,
      clipBehavior: clipBehavior,
      elevation: elevation,
      color: color,
      shadowColor: shadowColor,
      child: child,
    );
  }
}

/// Tom wrapper for [FractionalTranslation].
///
/// Fractional offset translation with child. Auth on translated content.
class TomFractionalTranslation extends TomContainerBase {
  final Offset translation;
  final bool transformHitTests;
  final Widget? child;

  const TomFractionalTranslation({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.translation,
    this.transformHitTests = true,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return FractionalTranslation(
      translation: translation,
      transformHitTests: transformHitTests,
      child: child,
    );
  }
}

/// Tom wrapper for [GridTile].
///
/// Cell container for GridView items with header/footer. Auth on tile content.
class TomGridTile extends TomContainerBase {
  final Widget? header;
  final Widget? footer;
  final Widget child;

  const TomGridTile({
    super.key,
    super.tomId,
    super.tomGroup,
    this.header,
    this.footer,
    required this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return GridTile(
      header: header,
      footer: footer,
      child: child,
    );
  }
}

/// Tom wrapper for [GridTileBar].
///
/// Header/footer bar inside GridTile. Auth on bar content.
class TomGridTileBar extends TomContainerBase {
  final Color? backgroundColor;
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;

  const TomGridTileBar({
    super.key,
    super.tomId,
    super.tomGroup,
    this.backgroundColor,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget buildContent(BuildContext context) {
    return GridTileBar(
      backgroundColor: backgroundColor,
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    );
  }
}

// ============================================================================
// Section II: Extended Container Widgets (continued)
// ============================================================================

/// Tom wrapper for [CupertinoExpansionTile].
///
/// Cupertino-styled expansion tile. Auth on expand access.
class TomCupertinoExpansionTile extends TomContainerBase {
  final Widget? title;
  final String? titleText;
  final Widget child;
  final ExpansibleController? controller;
  final ExpansionTileTransitionMode transitionMode;

  const TomCupertinoExpansionTile({
    super.key,
    super.tomId,
    super.tomGroup,
    this.title,
    this.titleText,
    required this.child,
    this.controller,
    this.transitionMode = ExpansionTileTransitionMode.fade,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTitle = titleText ?? resolveResourceOrFail(context, 'label');
    return CupertinoExpansionTile(
      title: title ?? Text(resolvedTitle),
      controller: controller,
      transitionMode: transitionMode,
      child: child,
    );
  }
}

/// Tom wrapper for [ClipRSuperellipse].
///
/// Clips child to superellipse (squircle) shape. Auth on clipped content.
class TomClipRSuperellipse extends TomContainerBase {
  final BorderRadiusGeometry borderRadius;
  final Clip clipBehavior;
  final Widget? child;

  const TomClipRSuperellipse({
    super.key,
    super.tomId,
    super.tomGroup,
    this.borderRadius = BorderRadius.zero,
    this.clipBehavior = Clip.antiAlias,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return ClipRSuperellipse(
      borderRadius: borderRadius,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

/// Tom wrapper for [CupertinoTabView] (extension pattern).
///
/// Tab content view inside CupertinoTabScaffold. Auth on tab content.
class TomCupertinoTabView extends CupertinoTabView with TomWidgetMixin {
  @override
  final String? tomId;

  @override
  final String? tomGroup;

  TomCupertinoTabView({
    super.key,
    this.tomId,
    this.tomGroup,
    super.builder,
    super.navigatorKey,
    super.defaultTitle,
    super.routes,
    super.onGenerateRoute,
    super.onUnknownRoute,
    super.navigatorObservers,
    super.restorationScopeId,
  });
}
