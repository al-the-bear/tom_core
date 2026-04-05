import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../groups/tom_ui_group.dart';
import '../../groups/tom_widget_mixin.dart';
import '../../resource_auth/tom_resources.dart';
import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_style_resolvers.dart';

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
    // Phase 2: Resolve optional parameters from resources
    final resolvedColor = color ?? resolveColorOrNull('color');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedSurfaceTintColor =
        surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedMargin = margin ?? resolveEdgeInsetsOrNull('margin');

    // Phase 3: Resolve complex objects from resources
    final resolvedShape = shape ?? _resolveShapeBorder('shape');

    // Phase 3: Resolve remaining optional parameters from resources
    final resolvedBorderOnForeground =
        resolveBoolOrNull('borderOnForeground') ?? borderOnForeground;
    final resolvedSemanticContainer =
        resolveBoolOrNull('semanticContainer') ?? semanticContainer;

    return Card(
      color: resolvedColor,
      shadowColor: resolvedShadowColor,
      surfaceTintColor: resolvedSurfaceTintColor,
      elevation: resolvedElevation,
      shape: resolvedShape,
      borderOnForeground: resolvedBorderOnForeground,
      margin: resolvedMargin,
      clipBehavior: clipBehavior,
      semanticContainer: resolvedSemanticContainer,
      child: child,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath, suffix);
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
    final resolvedTitle = titleText ?? resolveResourceOrFail('label');
    final titleWidget = title ?? Text(resolvedTitle);

    // Phase 2: Resolve optional color parameters from resources
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedCollapsedBackgroundColor = collapsedBackgroundColor ??
        resolveColorOrNull('collapsedBackgroundColor');
    final resolvedTextColor =
        textColor ?? resolveColorOrNull('textColor');
    final resolvedCollapsedTextColor =
        collapsedTextColor ?? resolveColorOrNull('collapsedTextColor');
    final resolvedIconColor =
        iconColor ?? resolveColorOrNull('iconColor');
    final resolvedCollapsedIconColor =
        collapsedIconColor ?? resolveColorOrNull('collapsedIconColor');
    final resolvedChildrenPadding =
        childrenPadding ?? resolveEdgeInsetsOrNull('childrenPadding');
    final resolvedTilePadding =
        tilePadding ?? resolveEdgeInsetsOrNull('tilePadding');

    // Phase 3: Resolve complex objects from resources
    final resolvedShape = shape ?? _resolveShapeBorder('shape');
    final resolvedCollapsedShape =
        collapsedShape ?? _resolveShapeBorder('collapsedShape');

    // Phase 3: Resolve remaining optional parameters from resources
    final resolvedInitiallyExpanded =
        resolveBoolOrNull('initiallyExpanded') ?? initiallyExpanded;
    final resolvedMaintainState =
        resolveBoolOrNull('maintainState') ?? maintainState;
    final resolvedDense =
        resolveBoolOrNull('dense') ?? dense;
    final resolvedShowTrailingIcon =
        resolveBoolOrNull('showTrailingIcon') ?? showTrailingIcon;

    return ExpansionTile(
      title: titleWidget,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      initiallyExpanded: resolvedInitiallyExpanded,
      maintainState: resolvedMaintainState,
      tilePadding: resolvedTilePadding,
      expandedCrossAxisAlignment: expandedCrossAxisAlignment,
      expandedAlignment: expandedAlignment,
      childrenPadding: resolvedChildrenPadding,
      backgroundColor: resolvedBackgroundColor,
      collapsedBackgroundColor: resolvedCollapsedBackgroundColor,
      textColor: resolvedTextColor,
      collapsedTextColor: resolvedCollapsedTextColor,
      iconColor: resolvedIconColor,
      collapsedIconColor: resolvedCollapsedIconColor,
      shape: resolvedShape,
      collapsedShape: resolvedCollapsedShape,
      clipBehavior: clipBehavior,
      controlAffinity: controlAffinity,
      onExpansionChanged: onExpansionChanged,
      dense: resolvedDense,
      showTrailingIcon: resolvedShowTrailingIcon,
      children: children,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath, suffix);
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
    // Phase 2: Resolve optional parameters from resources
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedDrawerScrimColor =
        drawerScrimColor ?? resolveColorOrNull('drawerScrimColor');
    final resolvedDrawerEdgeDragWidth =
        drawerEdgeDragWidth ?? resolveDoubleOrNull('drawerEdgeDragWidth');

    // Phase 3: Resolve remaining parameters from resources
    final resolvedPrimary =
        resolveBoolOrNull('primary') ?? primary;
    final resolvedExtendBody =
        resolveBoolOrNull('extendBody') ?? extendBody;
    final resolvedExtendBodyBehindAppBar =
        resolveBoolOrNull('extendBodyBehindAppBar') ?? extendBodyBehindAppBar;
    final resolvedDrawerEnableOpenDragGesture =
        resolveBoolOrNull('drawerEnableOpenDragGesture') ?? drawerEnableOpenDragGesture;
    final resolvedEndDrawerEnableOpenDragGesture =
        resolveBoolOrNull('endDrawerEnableOpenDragGesture') ?? endDrawerEnableOpenDragGesture;
    final resolvedRestorationId =
        restorationId ?? resolveResourceOrNull('restorationId');

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
      backgroundColor: resolvedBackgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      primary: resolvedPrimary,
      extendBody: resolvedExtendBody,
      extendBodyBehindAppBar: resolvedExtendBodyBehindAppBar,
      drawerScrimColor: resolvedDrawerScrimColor,
      drawerEdgeDragWidth: resolvedDrawerEdgeDragWidth,
      drawerEnableOpenDragGesture: resolvedDrawerEnableOpenDragGesture,
      endDrawerEnableOpenDragGesture: resolvedEndDrawerEnableOpenDragGesture,
      restorationId: resolvedRestorationId,
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
  final TomUIGroup? tomGroup;

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
    final resolvedTitleText =
        titleText ?? _resolveStringOrNull('titleText');
    final resolvedTitle =
        resolvedTitleText ?? (tomId != null ? getText('label') : null);
    final effectiveTitle =
        title ?? (resolvedTitle != null ? Text(resolvedTitle) : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedAutomaticallyImplyLeading =
        resolveBoolOrNull('automaticallyImplyLeading') ?? automaticallyImplyLeading;
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedScrolledUnderElevation =
        scrolledUnderElevation ?? resolveDoubleOrNull('scrolledUnderElevation');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedSurfaceTintColor =
        surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedForegroundColor =
        foregroundColor ?? resolveColorOrNull('foregroundColor');
    final resolvedTitleSpacing =
        titleSpacing ?? resolveDoubleOrNull('titleSpacing');
    final resolvedToolbarHeight =
        toolbarHeight ?? resolveDoubleOrNull('toolbarHeight');
    final resolvedLeadingWidth =
        leadingWidth ?? resolveDoubleOrNull('leadingWidth');
    final resolvedPrimary =
        resolveBoolOrNull('primary') ?? primary;
    final resolvedCenterTitle =
        centerTitle ?? resolveBoolOrNull('centerTitle');
    final resolvedExcludeHeaderSemantics =
        resolveBoolOrNull('excludeHeaderSemantics') ?? excludeHeaderSemantics;
    final resolvedToolbarOpacity =
        resolveDoubleOrNull('toolbarOpacity') ?? toolbarOpacity;
    final resolvedBottomOpacity =
        resolveDoubleOrNull('bottomOpacity') ?? bottomOpacity;
    final resolvedForceMaterialTransparency =
        resolveBoolOrNull('forceMaterialTransparency') ?? forceMaterialTransparency;

    // Phase 3: Resolve complex objects from resources
    final resolvedIconTheme =
        iconTheme ?? _resolveIconThemeData('iconTheme');
    final resolvedActionsIconTheme =
        actionsIconTheme ?? _resolveIconThemeData('actionsIconTheme');
    final resolvedToolbarTextStyle =
        toolbarTextStyle ?? _resolveTextStyle('toolbarTextStyle');
    final resolvedTitleTextStyle =
        titleTextStyle ?? _resolveTextStyle('titleTextStyle');
    final resolvedShape = shape ?? _resolveShapeBorder('shape');

    return AppBar(
      leading: leading,
      automaticallyImplyLeading: resolvedAutomaticallyImplyLeading,
      title: effectiveTitle,
      actions: actions,
      flexibleSpace: flexibleSpace,
      bottom: bottom,
      elevation: resolvedElevation,
      scrolledUnderElevation: resolvedScrolledUnderElevation,
      shadowColor: resolvedShadowColor,
      surfaceTintColor: resolvedSurfaceTintColor,
      backgroundColor: resolvedBackgroundColor,
      foregroundColor: resolvedForegroundColor,
      iconTheme: resolvedIconTheme,
      actionsIconTheme: resolvedActionsIconTheme,
      primary: resolvedPrimary,
      centerTitle: resolvedCenterTitle,
      excludeHeaderSemantics: resolvedExcludeHeaderSemantics,
      titleSpacing: resolvedTitleSpacing,
      toolbarOpacity: resolvedToolbarOpacity,
      bottomOpacity: resolvedBottomOpacity,
      toolbarHeight: resolvedToolbarHeight,
      leadingWidth: resolvedLeadingWidth,
      toolbarTextStyle: resolvedToolbarTextStyle,
      titleTextStyle: resolvedTitleTextStyle,
      systemOverlayStyle: systemOverlayStyle,
      forceMaterialTransparency: resolvedForceMaterialTransparency,
      clipBehavior: clipBehavior,
      shape: resolvedShape,
      notificationPredicate: notificationPredicate,
    );
  }

  IconThemeData? _resolveIconThemeData(String suffix) {
    final basePath = resolveFullPath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveIconThemeData(basePath, suffix);
  }

  TextStyle? _resolveTextStyle(String suffix) {
    final basePath = resolveFullPath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    final basePath = resolveFullPath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath, suffix);
  }

  String? _resolveStringOrNull(String suffix) {
    final basePath = resolveFullPath();
    if (basePath == null) return null;
    if (!TomUIResources.resourceExists(basePath, suffix)) return null;
    return TomUIResources.resolveText(basePath, suffix);
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
    // Phase 2: Resolve optional parameters from resources
    final resolvedColor = color ?? resolveColorOrNull('color');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedHeight = height ?? resolveDoubleOrNull('height');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedSurfaceTintColor =
        surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    final resolvedNotchMargin =
        resolveDoubleOrNull('notchMargin') ?? notchMargin;
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding');

    return BottomAppBar(
      color: resolvedColor,
      elevation: resolvedElevation,
      shape: shape,
      clipBehavior: clipBehavior,
      notchMargin: resolvedNotchMargin,
      padding: resolvedPadding,
      height: resolvedHeight,
      shadowColor: resolvedShadowColor,
      surfaceTintColor: resolvedSurfaceTintColor,
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
    // Phase 2: Resolve optional parameters from resources
    final resolvedHeight = height ?? resolveDoubleOrNull('height');
    final resolvedThickness =
        thickness ?? resolveDoubleOrNull('thickness');
    final resolvedIndent = indent ?? resolveDoubleOrNull('indent');
    final resolvedEndIndent =
        endIndent ?? resolveDoubleOrNull('endIndent');
    final resolvedColor = color ?? resolveColorOrNull('color');

    return Divider(
      height: resolvedHeight,
      thickness: resolvedThickness,
      indent: resolvedIndent,
      endIndent: resolvedEndIndent,
      color: resolvedColor,
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
    // Phase 2: Resolve optional parameters from resources
    final resolvedColor = color ?? resolveColorOrNull('color');
    final resolvedWidth = width ?? resolveDoubleOrNull('width');
    final resolvedHeight = height ?? resolveDoubleOrNull('height');
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding');
    final resolvedMargin = margin ?? resolveEdgeInsetsOrNull('margin');

    // Phase 3: Resolve complex objects from resources
    final resolvedDecoration =
        decoration ?? _resolveDecoration('decoration');
    final resolvedForegroundDecoration = foregroundDecoration ??
        _resolveDecoration('foregroundDecoration');
    final resolvedConstraints =
        constraints ?? _resolveBoxConstraints('constraints');
    final resolvedAlignment =
        alignment ?? _resolveAlignment('alignment');
    final resolvedTransformAlignment =
        transformAlignment ?? _resolveAlignment('transformAlignment');

    return Container(
      alignment: resolvedAlignment,
      padding: resolvedPadding,
      color: resolvedDecoration != null ? null : resolvedColor,
      decoration: resolvedDecoration,
      foregroundDecoration: resolvedForegroundDecoration,
      constraints: resolvedConstraints,
      margin: resolvedMargin,
      transform: transform,
      transformAlignment: resolvedTransformAlignment,
      clipBehavior: clipBehavior,
      width: resolvedWidth,
      height: resolvedHeight,
      child: child,
    );
  }

  Decoration? _resolveDecoration(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveDecoration(basePath, suffix);
  }

  BoxConstraints? _resolveBoxConstraints(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBoxConstraints(basePath, suffix);
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath, suffix);
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
  final double? spacing;
  final WrapAlignment runAlignment;
  final double? runSpacing;
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
    this.spacing,
    this.runAlignment = WrapAlignment.start,
    this.runSpacing,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.clipBehavior = Clip.none,
    this.children = const [],
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedSpacing =
      spacing ?? resolveDoubleOrNull('spacing') ?? 0.0;
    final resolvedRunSpacing =
      runSpacing ?? resolveDoubleOrNull('runSpacing') ?? 0.0;

    return Wrap(
      direction: direction,
      alignment: alignment,
      spacing: resolvedSpacing,
      runAlignment: runAlignment,
      runSpacing: resolvedRunSpacing,
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
    // Phase 3: Resolve complex objects from resources
    final resolvedAlignment =
        _resolveAlignment('alignment') ?? alignment;

    return Stack(
      alignment: resolvedAlignment,
      textDirection: textDirection,
      fit: fit,
      clipBehavior: clipBehavior,
      children: children,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath, suffix);
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
    // Phase 2: Resolve optional parameters from resources
    final resolvedIndex = index ?? resolveIntOrNull('index');

    // Phase 3: Resolve complex objects from resources
    final resolvedAlignment =
        _resolveAlignment('alignment') ?? alignment;

    return IndexedStack(
      index: resolvedIndex,
      alignment: resolvedAlignment,
      textDirection: textDirection,
      sizing: sizing,
      children: children,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath, suffix);
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
    // Phase 2: Resolve optional parameters from resources
    final resolvedWidth = width ?? resolveDoubleOrNull('width');
    final resolvedHeight = height ?? resolveDoubleOrNull('height');

    return SizedBox(
      width: resolvedWidth,
      height: resolvedHeight,
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
    final resolvedPadding =
        resolveEdgeInsetsOrNull('padding') ?? padding;

    return Padding(
      padding: resolvedPadding,
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
    // Phase 2: Resolve optional parameters from resources
    final resolvedWidthFactor =
        widthFactor ?? resolveDoubleOrNull('widthFactor');
    final resolvedHeightFactor =
        heightFactor ?? resolveDoubleOrNull('heightFactor');

    return Center(
      widthFactor: resolvedWidthFactor,
      heightFactor: resolvedHeightFactor,
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
    // Phase 2: Resolve optional parameters from resources
    final resolvedWidthFactor =
        widthFactor ?? resolveDoubleOrNull('widthFactor');
    final resolvedHeightFactor =
        heightFactor ?? resolveDoubleOrNull('heightFactor');

    return Align(
      alignment: alignment,
      widthFactor: resolvedWidthFactor,
      heightFactor: resolvedHeightFactor,
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
    // Phase 2: Resolve optional parameters from resources
    final resolvedWidthFactor =
        widthFactor ?? resolveDoubleOrNull('widthFactor');
    final resolvedHeightFactor =
        heightFactor ?? resolveDoubleOrNull('heightFactor');

    return FractionallySizedBox(
      alignment: alignment,
      widthFactor: resolvedWidthFactor,
      heightFactor: resolvedHeightFactor,
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
    // Phase 2: Resolve optional parameters from resources
    final resolvedStepWidth =
        stepWidth ?? resolveDoubleOrNull('stepWidth');
    final resolvedStepHeight =
        stepHeight ?? resolveDoubleOrNull('stepHeight');

    return IntrinsicWidth(
      stepWidth: resolvedStepWidth,
      stepHeight: resolvedStepHeight,
      child: child,
    );
  }
}

/// Tom wrapper for [Material].
class TomMaterial extends TomContainerBase {
  final MaterialType type;
  final double? elevation;
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
    this.elevation,
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
    // Phase 2: Resolve optional parameters from resources
    final resolvedElevation =
      elevation ?? resolveDoubleOrNull('elevation') ?? 0.0;
    final resolvedColor = color ?? resolveColorOrNull('color');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedSurfaceTintColor =
        surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');

    // Phase 3: Resolve complex objects from resources
    final resolvedTextStyle =
        textStyle ?? _resolveTextStyle('textStyle');
    final resolvedBorderRadius =
        borderRadius ?? _resolveBorderRadius('borderRadius');
    final resolvedShape = shape ?? _resolveShapeBorder('shape');

    return Material(
      type: type,
      elevation: resolvedElevation,
      color: resolvedColor,
      shadowColor: resolvedShadowColor,
      surfaceTintColor: resolvedSurfaceTintColor,
      textStyle: resolvedTextStyle,
      borderRadius: resolvedBorderRadius,
      shape: resolvedShape,
      borderOnForeground: borderOnForeground,
      clipBehavior: clipBehavior,
      animationDuration: animationDuration,
      child: child,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
  }

  BorderRadiusGeometry? _resolveBorderRadius(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderRadius(basePath, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath, suffix);
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
    final resolvedTitle = titleText ?? resolveResourceOrFail('label');
    final effectiveTitle = title ?? Text(resolvedTitle);

    // Phase 2: Resolve optional parameters from resources
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedScrolledUnderElevation =
        scrolledUnderElevation ?? resolveDoubleOrNull('scrolledUnderElevation');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedSurfaceTintColor =
        surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedForegroundColor =
        foregroundColor ?? resolveColorOrNull('foregroundColor');
    final resolvedTitleSpacing =
        titleSpacing ?? resolveDoubleOrNull('titleSpacing');
    final resolvedExpandedHeight =
        expandedHeight ?? resolveDoubleOrNull('expandedHeight');
    final resolvedCollapsedHeight =
        collapsedHeight ?? resolveDoubleOrNull('collapsedHeight');
    final resolvedLeadingWidth =
        leadingWidth ?? resolveDoubleOrNull('leadingWidth');

    // Phase 3: Resolve complex objects from resources
    final resolvedIconTheme =
        iconTheme ?? _resolveIconThemeData('iconTheme');
    final resolvedActionsIconTheme =
        actionsIconTheme ?? _resolveIconThemeData('actionsIconTheme');
    final resolvedShape = shape ?? _resolveShapeBorder('shape');
    final resolvedToolbarTextStyle =
        toolbarTextStyle ?? _resolveTextStyle('toolbarTextStyle');
    final resolvedTitleTextStyle =
        titleTextStyle ?? _resolveTextStyle('titleTextStyle');

    return SliverAppBar(
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: effectiveTitle,
      actions: actions,
      flexibleSpace: flexibleSpace,
      bottom: bottom,
      elevation: resolvedElevation,
      scrolledUnderElevation: resolvedScrolledUnderElevation,
      shadowColor: resolvedShadowColor,
      surfaceTintColor: resolvedSurfaceTintColor,
      backgroundColor: resolvedBackgroundColor,
      foregroundColor: resolvedForegroundColor,
      iconTheme: resolvedIconTheme,
      actionsIconTheme: resolvedActionsIconTheme,
      primary: primary,
      centerTitle: centerTitle,
      excludeHeaderSemantics: excludeHeaderSemantics,
      titleSpacing: resolvedTitleSpacing,
      expandedHeight: resolvedExpandedHeight,
      collapsedHeight: resolvedCollapsedHeight,
      toolbarHeight: toolbarHeight,
      leadingWidth: resolvedLeadingWidth,
      floating: floating,
      pinned: pinned,
      snap: snap,
      stretch: stretch,
      stretchTriggerOffset: stretchTriggerOffset,
      shape: resolvedShape,
      toolbarTextStyle: resolvedToolbarTextStyle,
      titleTextStyle: resolvedTitleTextStyle,
      systemOverlayStyle: systemOverlayStyle,
      forceMaterialTransparency: forceMaterialTransparency,
      clipBehavior: clipBehavior,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
  }

  IconThemeData? _resolveIconThemeData(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveIconThemeData(basePath, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath, suffix);
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
    // Phase 2: Resolve optional parameters from resources
    final resolvedCacheExtent =
        cacheExtent ?? resolveDoubleOrNull('cacheExtent');

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
      cacheExtent: resolvedCacheExtent,
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
  final TomUIGroup? tomGroup;

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
  final EdgeInsets? expandedHeaderPadding;
  final Color? dividerColor;
  final double? elevation;

  const TomExpansionPanelList({
    super.key,
    super.tomId,
    super.tomGroup,
    this.children = const [],
    this.expansionCallback,
    this.animationDuration = kThemeAnimationDuration,
    this.expandedHeaderPadding,
    this.dividerColor,
    this.elevation,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedDividerColor =
        dividerColor ?? resolveColorOrNull('dividerColor');
    final resolvedElevation =
      elevation ?? resolveDoubleOrNull('elevation') ?? 2;
    final resolvedExpandedHeaderPadding =
      expandedHeaderPadding ?? resolveEdgeInsetsOrNull('expandedHeaderPadding') ?? const EdgeInsets.symmetric(vertical: 16.0);

    return ExpansionPanelList(
      children: children,
      expansionCallback: expansionCallback,
      animationDuration: animationDuration,
      expandedHeaderPadding: resolvedExpandedHeaderPadding,
      dividerColor: resolvedDividerColor,
      elevation: resolvedElevation,
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
    // Phase 2: Resolve optional parameters from resources
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding');
    final resolvedColor = color ?? resolveColorOrNull('color');
    final resolvedWidth = width ?? resolveDoubleOrNull('width');
    final resolvedHeight = height ?? resolveDoubleOrNull('height');

    // Phase 3: Resolve complex objects from resources
    final resolvedDecoration =
        decoration ?? _resolveDecoration('decoration');

    return Ink(
      padding: resolvedPadding,
      color: resolvedDecoration != null ? null : resolvedColor,
      decoration: resolvedDecoration,
      width: resolvedWidth,
      height: resolvedHeight,
      child: child,
    );
  }

  Decoration? _resolveDecoration(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveDecoration(basePath, suffix);
  }
}

// ============================================================================
// EXTENSION-BASED WIDGETS (extends Flutter widget + TomWidgetMixin)
// These preserve type identity for Flutter's runtime `is`-checks.
// ============================================================================

/// Tom widget that EXTENDS [Expanded] with authorization and resource resolution.
///
/// This widget IS an [Expanded] (and IS a [Flexible]) — it passes `is Expanded`
/// and `is Flexible` checks for use in [Row], [Column], and [Flex].
///
/// Resources are resolved at construction time:
/// - [child] — if null, creates `TomText(tomId: '$tomId.child')`
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
///     TomExpanded(tomId: 'content'),  // Resolves child from resources
///     TomExpanded(tomId: 'sidebar'),
///   ],
/// )
/// ```
class TomExpanded extends Expanded with TomWidgetMixin {
  @override
  final String? tomId;

  @override
  final TomUIGroup? tomGroup;

  /// Optional explicit scope for resource resolution.
  final TomScope? scope;

  /// Creates a Tom Expanded widget with optional resource resolution.
  TomExpanded({
    this.tomId,
    this.tomGroup,
    this.scope,
    super.key,
    super.flex,
    Widget? child,
  }) : super(child: child ?? TomCtr.defaultTextOrEmpty(TomCtr.childTomId(tomId, 'child'), scope, tomGroup));
}

/// Tom widget that EXTENDS [Flexible] with authorization and resource resolution.
///
/// This widget IS a [Flexible] — it passes `is Flexible` checks.
///
/// Resources are resolved at construction time:
/// - [child] — if null, creates `TomText(tomId: '$tomId.child')`
///
/// ```dart
/// TomRow(
///   tomId: 'flexRow',
///   children: [
///     TomFlexible(tomId: 'flex1', flex: 2),  // Resolves child from resources
///     TomFlexible(tomId: 'flex2', flex: 1),
///   ],
/// )
/// ```
class TomFlexible extends Flexible with TomWidgetMixin {
  @override
  final String? tomId;

  @override
  final TomUIGroup? tomGroup;

  /// Optional explicit scope for resource resolution.
  final TomScope? scope;

  /// Creates a Tom Flexible widget with optional resource resolution.
  TomFlexible({
    this.tomId,
    this.tomGroup,
    this.scope,
    super.key,
    super.flex,
    super.fit,
    Widget? child,
  }) : super(child: child ?? TomCtr.defaultTextOrEmpty(TomCtr.childTomId(tomId, 'child'), scope, tomGroup));
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
  @override
  final String? tomId;

  @override
  final TomUIGroup? tomGroup;

  /// Optional explicit scope for resource resolution.
  final TomScope? scope;

  /// Creates a Tom Spacer widget.
  const TomSpacer({
    this.tomId,
    this.tomGroup,
    this.scope,
    super.key,
    super.flex,
  });
}

/// Tom wrapper for [Positioned] with authorization and resource resolution.
///
/// Wraps Flutter [Positioned] for use in [Stack], with resource-resolved
/// positioning values.
///
/// ```dart
/// TomStack(
///   tomId: 'overlayStack',
///   children: [
///     TomPositioned(tomId: 'badge', top: 0, right: 0, child: Badge()),
///   ],
/// )
/// ```
class TomPositioned extends TomContainerBase {
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final double? width;
  final double? height;
  final Widget child;

  /// Creates a Tom Positioned widget.
  const TomPositioned({
    super.key,
    super.tomId,
    super.tomGroup,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
    required this.child,
  });

  /// Creates a Tom Positioned widget that fills the Stack.
  const TomPositioned.fill({
    super.key,
    super.tomId,
    super.tomGroup,
    this.left = 0.0,
    this.top = 0.0,
    this.right = 0.0,
    this.bottom = 0.0,
    required this.child,
  })  : width = null,
        height = null;

  @override
  Widget buildContent(BuildContext context) {
    return Positioned(
      left: left ?? resolveDoubleOrNull('left'),
      top: top ?? resolveDoubleOrNull('top'),
      right: right ?? resolveDoubleOrNull('right'),
      bottom: bottom ?? resolveDoubleOrNull('bottom'),
      width: width ?? resolveDoubleOrNull('width'),
      height: height ?? resolveDoubleOrNull('height'),
      child: child,
    );
  }
}

/// Tom wrapper for [PositionedDirectional] with authorization and resource resolution.
///
/// Wraps Flutter [PositionedDirectional] for RTL-aware positioning in [Stack].
class TomPositionedDirectional extends TomContainerBase {
  final double? start;
  final double? top;
  final double? end;
  final double? bottom;
  final double? width;
  final double? height;
  final Widget child;

  /// Creates a Tom PositionedDirectional widget.
  const TomPositionedDirectional({
    super.key,
    super.tomId,
    super.tomGroup,
    this.start,
    this.top,
    this.end,
    this.bottom,
    this.width,
    this.height,
    required this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return PositionedDirectional(
      start: start ?? resolveDoubleOrNull('start'),
      top: top ?? resolveDoubleOrNull('top'),
      end: end ?? resolveDoubleOrNull('end'),
      bottom: bottom ?? resolveDoubleOrNull('bottom'),
      width: width ?? resolveDoubleOrNull('width'),
      height: height ?? resolveDoubleOrNull('height'),
      child: child,
    );
  }
}

/// Tom widget that EXTENDS [TableCell] with authorization and resource resolution.
///
/// This widget IS a [TableCell] — used in [Table] with vertical alignment.
///
/// Resources are resolved at construction time:
/// - [child] — if null, creates `TomText(tomId: '$tomId.child')`
class TomTableCell extends TableCell with TomWidgetMixin {
  @override
  final String? tomId;

  @override
  final TomUIGroup? tomGroup;

  /// Optional explicit scope for resource resolution.
  final TomScope? scope;

  /// Creates a Tom TableCell widget with optional resource resolution.
  TomTableCell({
    this.tomId,
    this.tomGroup,
    this.scope,
    super.key,
    super.verticalAlignment,
    Widget? child,
  }) : super(child: child ?? TomCtr.defaultTextOrEmpty(TomCtr.childTomId(tomId, 'child'), scope, tomGroup));
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
    // Phase 3: Resolve complex objects from resources
    final resolvedPhysics =
        physics ?? _resolveScrollPhysics('physics');
    final resolvedRestorationId =
        restorationId ?? resolveResourceOrNull('restorationId');

    return SingleChildScrollView(
      scrollDirection: scrollDirection,
      reverse: reverse,
      padding: padding ?? resolveEdgeInsetsOrNull('padding'),
      physics: resolvedPhysics,
      controller: controller,
      dragStartBehavior: dragStartBehavior,
      clipBehavior: clipBehavior,
      restorationId: resolvedRestorationId,
      keyboardDismissBehavior: keyboardDismissBehavior,
      child: child,
    );
  }

  ScrollPhysics? _resolveScrollPhysics(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveScrollPhysics(basePath, suffix);
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
  final double? shrinkExtent;
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
    this.shrinkExtent,
    this.controller,
    this.scrollDirection = Axis.horizontal,
    this.reverse = false,
    this.onTap,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CarouselView(
      padding: padding ?? resolveEdgeInsetsOrNull('padding'),
      backgroundColor: backgroundColor ?? resolveColorOrNull('backgroundColor'),
      elevation: elevation ?? resolveDoubleOrNull('elevation'),
      shape: shape ?? _resolveShapeBorder('shape'),
      itemExtent: itemExtent ?? resolveDoubleOrNull('itemExtent') ?? 200.0,
      shrinkExtent: shrinkExtent ?? resolveDoubleOrNull('shrinkExtent') ?? 0.0,
      controller: controller,
      scrollDirection: scrollDirection,
      reverse: reverse,
      onTap: onTap,
      children: children,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath, suffix);
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
    // Phase 2: Resolve optional parameters from resources
    final resolvedOffstage =
        resolveBoolOrNull('offstage') ?? offstage;

    return Offstage(
      offstage: resolvedOffstage,
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
      backgroundColor: backgroundColor ?? resolveColorOrNull('backgroundColor'),
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
      backgroundColor: backgroundColor ?? resolveColorOrNull('backgroundColor'),
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
      padding: padding ?? resolveEdgeInsetsOrNull('padding'),
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
  final EdgeInsetsGeometry? margin;
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
    this.margin,
    this.backgroundColor,
    this.decoration,
    this.clipBehavior = Clip.none,
    this.insetGrouped = false,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedBgColor = backgroundColor ?? resolveColorOrNull('backgroundColor') ?? CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final resolvedMargin = margin ?? resolveEdgeInsetsOrNull('margin') ?? EdgeInsets.zero;
    if (insetGrouped) {
      return CupertinoFormSection.insetGrouped(
        header: header,
        footer: footer,
        margin: resolvedMargin,
        backgroundColor: resolvedBgColor,
        decoration: decoration,
        clipBehavior: clipBehavior,
        children: children,
      );
    }
    return CupertinoFormSection(
      header: header,
      footer: footer,
      margin: resolvedMargin,
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
  final bool? floatHeaderSlivers;
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
    this.floatHeaderSlivers,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.scrollBehavior,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedFloatHeaderSlivers =
        floatHeaderSlivers ?? resolveBoolOrNull('floatHeaderSlivers') ?? false;
    final resolvedRestorationId =
        restorationId ?? resolveResourceOrNull('restorationId');

    // Phase 3: Resolve complex objects from resources
    final resolvedPhysics =
        physics ?? _resolveScrollPhysics('physics');

    return NestedScrollView(
      controller: controller,
      scrollDirection: scrollDirection,
      reverse: reverse,
      physics: resolvedPhysics,
      headerSliverBuilder: headerSliverBuilder,
      body: body,
      dragStartBehavior: dragStartBehavior,
      floatHeaderSlivers: resolvedFloatHeaderSlivers,
      clipBehavior: clipBehavior,
      restorationId: resolvedRestorationId,
      scrollBehavior: scrollBehavior,
    );
  }

  ScrollPhysics? _resolveScrollPhysics(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveScrollPhysics(basePath, suffix);
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
    final resolvedThumbVisibility =
        thumbVisibility ?? resolveBoolOrNull('thumbVisibility');
    final resolvedTrackVisibility =
        trackVisibility ?? resolveBoolOrNull('trackVisibility');
    final resolvedThickness =
        thickness ?? resolveDoubleOrNull('thickness');
    final resolvedInteractive =
        interactive ?? resolveBoolOrNull('interactive');

    return Scrollbar(
      controller: controller,
      thumbVisibility: resolvedThumbVisibility,
      trackVisibility: resolvedTrackVisibility,
      thickness: resolvedThickness,
      radius: radius,
      notificationPredicate: notificationPredicate,
      interactive: resolvedInteractive,
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
  final double? thickness;
  final double? thicknessWhileDragging;
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
    this.thickness,
    this.thicknessWhileDragging,
    this.radius = CupertinoScrollbar.defaultRadius,
    this.radiusWhileDragging = CupertinoScrollbar.defaultRadiusWhileDragging,
    this.notificationPredicate,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedThumbVisibility =
        thumbVisibility ?? resolveBoolOrNull('thumbVisibility');
    final resolvedThickness =
        thickness ?? resolveDoubleOrNull('thickness') ?? CupertinoScrollbar.defaultThickness;
    final resolvedThicknessWhileDragging =
        thicknessWhileDragging ?? resolveDoubleOrNull('thicknessWhileDragging') ?? CupertinoScrollbar.defaultThicknessWhileDragging;

    return CupertinoScrollbar(
      controller: controller,
      thumbVisibility: resolvedThumbVisibility,
      thickness: resolvedThickness,
      thicknessWhileDragging: resolvedThicknessWhileDragging,
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
  final double? initialChildSize;
  final double? minChildSize;
  final double? maxChildSize;
  final bool? expand;
  final bool? snap;
  final List<double>? snapSizes;
  final double? snapAnimationDuration;
  final DraggableScrollableController? controller;
  final bool? shouldCloseOnMinExtent;
  final ScrollableWidgetBuilder builder;

  const TomDraggableScrollableSheet({
    super.key,
    super.tomId,
    super.tomGroup,
    this.initialChildSize,
    this.minChildSize,
    this.maxChildSize,
    this.expand,
    this.snap,
    this.snapSizes,
    this.snapAnimationDuration,
    this.controller,
    this.shouldCloseOnMinExtent,
    required this.builder,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedInitialChildSize =
        initialChildSize ?? resolveDoubleOrNull('initialChildSize') ?? 0.5;
    final resolvedMinChildSize =
        minChildSize ?? resolveDoubleOrNull('minChildSize') ?? 0.25;
    final resolvedMaxChildSize =
        maxChildSize ?? resolveDoubleOrNull('maxChildSize') ?? 1.0;
    final resolvedExpand =
        expand ?? resolveBoolOrNull('expand') ?? true;
    final resolvedSnap =
        snap ?? resolveBoolOrNull('snap') ?? false;
    final resolvedShouldCloseOnMinExtent =
        shouldCloseOnMinExtent ?? resolveBoolOrNull('shouldCloseOnMinExtent') ?? true;

    return DraggableScrollableSheet(
      initialChildSize: resolvedInitialChildSize,
      minChildSize: resolvedMinChildSize,
      maxChildSize: resolvedMaxChildSize,
      expand: resolvedExpand,
      snap: resolvedSnap,
      snapSizes: snapSizes,
      controller: controller,
      shouldCloseOnMinExtent: resolvedShouldCloseOnMinExtent,
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
  final EdgeInsets? boundaryMargin;
  final bool? constrained;
  final double? maxScale;
  final double? minScale;
  final double? interactionEndFrictionCoefficient;
  final GestureScaleEndCallback? onInteractionEnd;
  final GestureScaleStartCallback? onInteractionStart;
  final GestureScaleUpdateCallback? onInteractionUpdate;
  final bool? panEnabled;
  final bool? scaleEnabled;
  final double? scaleFactor;
  final TransformationController? transformationController;
  final Alignment? alignment;
  final Widget child;

  const TomInteractiveViewer({
    super.key,
    super.tomId,
    super.tomGroup,
    this.clipBehavior = Clip.hardEdge,
    this.panAxis = PanAxis.free,
    this.boundaryMargin,
    this.constrained,
    this.maxScale,
    this.minScale,
    this.interactionEndFrictionCoefficient,
    this.onInteractionEnd,
    this.onInteractionStart,
    this.onInteractionUpdate,
    this.panEnabled,
    this.scaleEnabled,
    this.scaleFactor,
    this.transformationController,
    this.alignment,
    required this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedBoundaryMargin =
      boundaryMargin ?? resolveEdgeInsetsOrNull('boundaryMargin') ?? EdgeInsets.zero;
    final resolvedConstrained =
      constrained ?? resolveBoolOrNull('constrained') ?? true;
    final resolvedMaxScale =
      maxScale ?? resolveDoubleOrNull('maxScale') ?? 2.5;
    final resolvedMinScale =
      minScale ?? resolveDoubleOrNull('minScale') ?? 0.8;
    final resolvedInteractionEndFrictionCoefficient =
      interactionEndFrictionCoefficient ?? resolveDoubleOrNull('interactionEndFrictionCoefficient') ?? 0.0000135;
    final resolvedPanEnabled =
      panEnabled ?? resolveBoolOrNull('panEnabled') ?? true;
    final resolvedScaleEnabled =
      scaleEnabled ?? resolveBoolOrNull('scaleEnabled') ?? true;
    final resolvedScaleFactor =
      scaleFactor ?? resolveDoubleOrNull('scaleFactor') ?? kDefaultMouseScrollToScaleFactor;

    // Phase 3: Resolve complex objects from resources
    final resolvedAlignment =
        alignment ?? _resolveAlignment('alignment') ?? Alignment.topLeft;

    return InteractiveViewer(
      clipBehavior: clipBehavior,
      panAxis: panAxis,
      boundaryMargin: resolvedBoundaryMargin,
      constrained: resolvedConstrained,
      maxScale: resolvedMaxScale,
      minScale: resolvedMinScale,
      interactionEndFrictionCoefficient: resolvedInteractionEndFrictionCoefficient,
      onInteractionEnd: onInteractionEnd,
      onInteractionStart: onInteractionStart,
      onInteractionUpdate: onInteractionUpdate,
      panEnabled: resolvedPanEnabled,
      scaleEnabled: resolvedScaleEnabled,
      scaleFactor: resolvedScaleFactor,
      transformationController: transformationController,
      alignment: resolvedAlignment,
      child: child,
    );
  }

  Alignment? _resolveAlignment(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    final resolved = TomStyleResolvers.resolveAlignment(basePath, suffix);
    // TomStyleResolvers returns AlignmentGeometry, but InteractiveViewer needs Alignment
    if (resolved is Alignment) return resolved;
    return null;
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
  final Color? color;
  final Widget? child;

  const TomColoredBox({
    super.key,
    super.tomId,
    super.tomGroup,
    this.color,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedColor = color ?? resolveColorOrFail('color');

    return ColoredBox(
      color: resolvedColor,
      child: child,
    );
  }
}

/// Tom wrapper for [Opacity].
///
/// Visual opacity 0.0–1.0. Auth on content.
class TomOpacity extends TomContainerBase {
  final double? opacity;
  final bool alwaysIncludeSemantics;
  final Widget? child;

  const TomOpacity({
    super.key,
    super.tomId,
    super.tomGroup,
    this.opacity,
    this.alwaysIncludeSemantics = false,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedOpacity = opacity ?? resolveDoubleOrFail('opacity');

    return Opacity(
      opacity: resolvedOpacity,
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
  final bool? transformHitTests;
  final FilterQuality? filterQuality;
  final Widget? child;

  const TomTransform({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.transform,
    this.origin,
    this.alignment,
    this.transformHitTests,
    this.filterQuality,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 3: Resolve complex objects from resources
    final resolvedAlignment =
        alignment ?? _resolveAlignment('alignment');
    final resolvedTransformHitTests =
        transformHitTests ?? resolveBoolOrNull('transformHitTests') ?? true;

    return Transform(
      transform: transform,
      origin: origin,
      alignment: resolvedAlignment,
      transformHitTests: resolvedTransformHitTests,
      filterQuality: filterQuality,
      child: child,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath, suffix);
  }
}

/// Tom wrapper for [RotatedBox].
///
/// Quarter-turn rotation with child. Auth on rotated content.
class TomRotatedBox extends TomContainerBase {
  final int? quarterTurns;
  final Widget? child;

  const TomRotatedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    this.quarterTurns,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedQuarterTurns =
        quarterTurns ?? resolveIntOrFail('quarterTurns');

    return RotatedBox(
      quarterTurns: resolvedQuarterTurns,
      child: child,
    );
  }
}

/// Tom wrapper for [OverflowBar].
///
/// Wrapping row that overflows to column (ButtonBar replacement). Auth on children.
class TomOverflowBar extends TomContainerBase {
  final double? spacing;
  final MainAxisAlignment? alignment;
  final double? overflowSpacing;
  final OverflowBarAlignment overflowAlignment;
  final VerticalDirection overflowDirection;
  final TextDirection? textDirection;
  final List<Widget> children;

  const TomOverflowBar({
    super.key,
    super.tomId,
    super.tomGroup,
    this.spacing,
    this.alignment,
    this.overflowSpacing,
    this.overflowAlignment = OverflowBarAlignment.start,
    this.overflowDirection = VerticalDirection.down,
    this.textDirection,
    this.children = const <Widget>[],
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedSpacing =
        spacing ?? resolveDoubleOrNull('spacing') ?? 0.0;
    final resolvedOverflowSpacing =
        overflowSpacing ?? resolveDoubleOrNull('overflowSpacing') ?? 0.0;

    return OverflowBar(
      spacing: resolvedSpacing,
      alignment: alignment,
      overflowSpacing: resolvedOverflowSpacing,
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
    // Phase 2: Resolve optional parameters from resources
    final resolvedMinWidth =
        minWidth ?? resolveDoubleOrNull('minWidth');
    final resolvedMaxWidth =
        maxWidth ?? resolveDoubleOrNull('maxWidth');
    final resolvedMinHeight =
        minHeight ?? resolveDoubleOrNull('minHeight');
    final resolvedMaxHeight =
        maxHeight ?? resolveDoubleOrNull('maxHeight');

    // Phase 3: Resolve complex objects from resources
    final resolvedAlignment =
        _resolveAlignment('alignment') ?? alignment;

    return OverflowBox(
      alignment: resolvedAlignment,
      minWidth: resolvedMinWidth,
      maxWidth: resolvedMaxWidth,
      minHeight: resolvedMinHeight,
      maxHeight: resolvedMaxHeight,
      fit: fit,
      child: child,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath, suffix);
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
  final double? maxWidth;
  final double? maxHeight;
  final Widget? child;

  const TomLimitedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    this.maxWidth,
    this.maxHeight,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedMaxWidth =
        maxWidth ?? resolveDoubleOrNull('maxWidth') ?? double.infinity;
    final resolvedMaxHeight =
        maxHeight ?? resolveDoubleOrNull('maxHeight') ?? double.infinity;

    return LimitedBox(
      maxWidth: resolvedMaxWidth,
      maxHeight: resolvedMaxHeight,
      child: child,
    );
  }
}

/// Tom wrapper for [Baseline].
///
/// Aligns child by text baseline. Auth on content.
class TomBaseline extends TomContainerBase {
  final double? baseline;
  final TextBaseline baselineType;
  final Widget? child;

  const TomBaseline({
    super.key,
    super.tomId,
    super.tomGroup,
    this.baseline,
    required this.baselineType,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedBaseline = baseline ?? resolveDoubleOrFail('baseline');

    return Baseline(
      baseline: resolvedBaseline,
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
  final bool? reverse;
  final List<Widget> children;

  const TomListBody({
    super.key,
    super.tomId,
    super.tomGroup,
    this.mainAxis = Axis.vertical,
    this.reverse,
    this.children = const <Widget>[],
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedReverse = reverse ?? resolveBoolOrNull('reverse') ?? false;

    return ListBody(
      mainAxis: mainAxis,
      reverse: resolvedReverse,
      children: children,
    );
  }
}

/// Tom wrapper for [Flow].
///
/// Delegate-based custom flow layout. Auth on flow children.
class TomFlow extends TomContainerBase {
  final FlowDelegate delegate;
  final Clip? clipBehavior;
  final List<Widget> children;

  const TomFlow({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.delegate,
    this.clipBehavior,
    this.children = const <Widget>[],
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedClipBehavior = clipBehavior ?? Clip.hardEdge;

    return Flow(
      delegate: delegate,
      clipBehavior: resolvedClipBehavior,
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
  final Size? size;
  final bool? isComplex;
  final bool? willChange;
  final Widget? child;

  const TomCustomPaint({
    super.key,
    super.tomId,
    super.tomGroup,
    this.painter,
    this.foregroundPainter,
    this.size,
    this.isComplex,
    this.willChange,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedSize = size ?? Size.zero;
    final resolvedIsComplex =
        isComplex ?? resolveBoolOrNull('isComplex') ?? false;
    final resolvedWillChange =
        willChange ?? resolveBoolOrNull('willChange') ?? false;

    return CustomPaint(
      painter: painter,
      foregroundPainter: foregroundPainter,
      size: resolvedSize,
      isComplex: resolvedIsComplex,
      willChange: resolvedWillChange,
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
  final double? elevation;
  final Color? color;
  final Color? shadowColor;
  final Widget? child;

  const TomPhysicalModel({
    super.key,
    super.tomId,
    super.tomGroup,
    this.shape = BoxShape.rectangle,
    this.clipBehavior = Clip.none,
    this.borderRadius,
    this.elevation,
    this.color,
    this.shadowColor,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation') ?? 0.0;
    final resolvedColor = color ?? resolveColorOrFail('color');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor') ?? const Color(0xFF000000);

    // Phase 3: Resolve complex objects from resources
    final resolvedBorderRadius =
        borderRadius ?? _resolveBorderRadius('borderRadius');

    return PhysicalModel(
      shape: shape,
      clipBehavior: clipBehavior,
      borderRadius: resolvedBorderRadius,
      elevation: resolvedElevation,
      color: resolvedColor,
      shadowColor: resolvedShadowColor,
      child: child,
    );
  }

  BorderRadius? _resolveBorderRadius(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderRadius(basePath, suffix);
  }
}

/// Tom wrapper for [PhysicalShape].
///
/// Custom-shaped shadow/elevation with child. Auth on shaped content.
class TomPhysicalShape extends TomContainerBase {
  final CustomClipper<Path> clipper;
  final Clip clipBehavior;
  final double? elevation;
  final Color? color;
  final Color? shadowColor;
  final Widget? child;

  const TomPhysicalShape({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.clipper,
    this.clipBehavior = Clip.none,
    this.elevation,
    this.color,
    this.shadowColor,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation') ?? 0.0;
    final resolvedColor = color ?? resolveColorOrFail('color');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor') ?? const Color(0xFF000000);

    return PhysicalShape(
      clipper: clipper,
      clipBehavior: clipBehavior,
      elevation: resolvedElevation,
      color: resolvedColor,
      shadowColor: resolvedShadowColor,
      child: child,
    );
  }
}

/// Tom wrapper for [FractionalTranslation].
///
/// Fractional offset translation with child. Auth on translated content.
class TomFractionalTranslation extends TomContainerBase {
  final Offset translation;
  final bool? transformHitTests;
  final Widget? child;

  const TomFractionalTranslation({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.translation,
    this.transformHitTests,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTransformHitTests =
        transformHitTests ?? resolveBoolOrNull('transformHitTests') ?? true;

    return FractionalTranslation(
      translation: translation,
      transformHitTests: resolvedTransformHitTests,
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
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');

    return GridTileBar(
      backgroundColor: resolvedBackgroundColor,
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
    final resolvedTitle = titleText ?? resolveResourceOrFail('label');
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
  final TomUIGroup? tomGroup;

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
