import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../groups/tom_ui_group.dart';
import '../../groups/tom_widget_mixin.dart';
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

  // Pre-resolved resource values
  late final Color? _resolvedColor;
  late final Color? _resolvedShadowColor;
  late final Color? _resolvedSurfaceTintColor;
  late final double? _resolvedElevation;
  late final EdgeInsetsGeometry? _resolvedMargin;
  late final ShapeBorder? _resolvedShape;
  late final bool _resolvedBorderOnForeground;
  late final bool _resolvedSemanticContainer;

  TomCard({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
  }) {
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
    _resolvedShadowColor = shadowColor ?? TomCtr.color(basePath, 'shadowColor');
    _resolvedSurfaceTintColor = surfaceTintColor ?? TomCtr.color(basePath, 'surfaceTintColor');
    _resolvedElevation = elevation ?? TomCtr.doubleVal(basePath, 'elevation');
    _resolvedMargin = margin ?? TomCtr.edgeInsets(basePath, 'margin');
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
    _resolvedBorderOnForeground = TomCtr.boolVal(basePath, 'borderOnForeground') ?? borderOnForeground;
    _resolvedSemanticContainer = TomCtr.boolVal(basePath, 'semanticContainer') ?? semanticContainer;
  }

  @override
  Widget buildContent(BuildContext context) {
    return Card(
      color: _resolvedColor,
      shadowColor: _resolvedShadowColor,
      surfaceTintColor: _resolvedSurfaceTintColor,
      elevation: _resolvedElevation,
      shape: _resolvedShape,
      borderOnForeground: _resolvedBorderOnForeground,
      margin: _resolvedMargin,
      clipBehavior: clipBehavior,
      semanticContainer: _resolvedSemanticContainer,
      child: child,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
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

  // Pre-resolved resource values
  late final String _resolvedTitle;
  late final Color? _resolvedBackgroundColor;
  late final Color? _resolvedCollapsedBackgroundColor;
  late final Color? _resolvedTextColor;
  late final Color? _resolvedCollapsedTextColor;
  late final Color? _resolvedIconColor;
  late final Color? _resolvedCollapsedIconColor;
  late final EdgeInsetsGeometry? _resolvedChildrenPadding;
  late final EdgeInsetsGeometry? _resolvedTilePadding;
  late final ShapeBorder? _resolvedShape;
  late final ShapeBorder? _resolvedCollapsedShape;
  late final bool _resolvedInitiallyExpanded;
  late final bool _resolvedMaintainState;
  late final bool _resolvedDense;
  late final bool _resolvedShowTrailingIcon;

  TomExpansionTile({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
    ValueChanged<bool>? onExpansionChanged,
    this.children = const [],
    this.dense = false,
    this.showTrailingIcon = true,
  })  : onExpansionChanged = InScopeBuilder(scope: scope).wrap1n(onExpansionChanged) {
    _resolvedTitle = titleText ?? TomCtr.textOrFail(basePath, 'label', supersededBy: title);
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedCollapsedBackgroundColor = collapsedBackgroundColor ?? TomCtr.color(basePath, 'collapsedBackgroundColor');
    _resolvedTextColor = textColor ?? TomCtr.color(basePath, 'textColor');
    _resolvedCollapsedTextColor = collapsedTextColor ?? TomCtr.color(basePath, 'collapsedTextColor');
    _resolvedIconColor = iconColor ?? TomCtr.color(basePath, 'iconColor');
    _resolvedCollapsedIconColor = collapsedIconColor ?? TomCtr.color(basePath, 'collapsedIconColor');
    _resolvedChildrenPadding = childrenPadding ?? TomCtr.edgeInsets(basePath, 'childrenPadding');
    _resolvedTilePadding = tilePadding ?? TomCtr.edgeInsets(basePath, 'tilePadding');
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
    _resolvedCollapsedShape = collapsedShape ?? _resolveShapeBorder('collapsedShape');
    _resolvedInitiallyExpanded = TomCtr.boolVal(basePath, 'initiallyExpanded') ?? initiallyExpanded;
    _resolvedMaintainState = TomCtr.boolVal(basePath, 'maintainState') ?? maintainState;
    _resolvedDense = TomCtr.boolVal(basePath, 'dense') ?? dense;
    _resolvedShowTrailingIcon = TomCtr.boolVal(basePath, 'showTrailingIcon') ?? showTrailingIcon;
  }

  @override
  Widget buildContent(BuildContext context) {
    final titleWidget = title ?? Text(_resolvedTitle);

    return ExpansionTile(
      title: titleWidget,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      initiallyExpanded: _resolvedInitiallyExpanded,
      maintainState: _resolvedMaintainState,
      tilePadding: _resolvedTilePadding,
      expandedCrossAxisAlignment: expandedCrossAxisAlignment,
      expandedAlignment: expandedAlignment,
      childrenPadding: _resolvedChildrenPadding,
      backgroundColor: _resolvedBackgroundColor,
      collapsedBackgroundColor: _resolvedCollapsedBackgroundColor,
      textColor: _resolvedTextColor,
      collapsedTextColor: _resolvedCollapsedTextColor,
      iconColor: _resolvedIconColor,
      collapsedIconColor: _resolvedCollapsedIconColor,
      shape: _resolvedShape,
      collapsedShape: _resolvedCollapsedShape,
      clipBehavior: clipBehavior,
      controlAffinity: controlAffinity,
      onExpansionChanged: onExpansionChanged,
      dense: _resolvedDense,
      showTrailingIcon: _resolvedShowTrailingIcon,
      children: children,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
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

  // Pre-resolved resource values
  late final Color? _resolvedBackgroundColor;
  late final Color? _resolvedDrawerScrimColor;
  late final double? _resolvedDrawerEdgeDragWidth;
  late final bool _resolvedPrimary;
  late final bool _resolvedExtendBody;
  late final bool _resolvedExtendBodyBehindAppBar;
  late final bool _resolvedDrawerEnableOpenDragGesture;
  late final bool _resolvedEndDrawerEnableOpenDragGesture;
  late final String? _resolvedRestorationId;

  TomScaffold({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
  }) {
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedDrawerScrimColor = drawerScrimColor ?? TomCtr.color(basePath, 'drawerScrimColor');
    _resolvedDrawerEdgeDragWidth = drawerEdgeDragWidth ?? TomCtr.doubleVal(basePath, 'drawerEdgeDragWidth');
    _resolvedPrimary = TomCtr.boolVal(basePath, 'primary') ?? primary;
    _resolvedExtendBody = TomCtr.boolVal(basePath, 'extendBody') ?? extendBody;
    _resolvedExtendBodyBehindAppBar = TomCtr.boolVal(basePath, 'extendBodyBehindAppBar') ?? extendBodyBehindAppBar;
    _resolvedDrawerEnableOpenDragGesture = TomCtr.boolVal(basePath, 'drawerEnableOpenDragGesture') ?? drawerEnableOpenDragGesture;
    _resolvedEndDrawerEnableOpenDragGesture = TomCtr.boolVal(basePath, 'endDrawerEnableOpenDragGesture') ?? endDrawerEnableOpenDragGesture;
    _resolvedRestorationId = restorationId ?? TomCtr.textOrNull(basePath, 'restorationId');
  }

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
      backgroundColor: _resolvedBackgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      primary: _resolvedPrimary,
      extendBody: _resolvedExtendBody,
      extendBodyBehindAppBar: _resolvedExtendBodyBehindAppBar,
      drawerScrimColor: _resolvedDrawerScrimColor,
      drawerEdgeDragWidth: _resolvedDrawerEdgeDragWidth,
      drawerEnableOpenDragGesture: _resolvedDrawerEnableOpenDragGesture,
      endDrawerEnableOpenDragGesture: _resolvedEndDrawerEnableOpenDragGesture,
      restorationId: _resolvedRestorationId,
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
  @override
  final TomScope? scope;
  @override
  final TomAuthorizer? authorizer;

  @override
  final TomAuthorizerStrategy authorizerStrategy;

  @override
  final TomUIStateController? uiStateController;

  @override
  final String? basePath;

  TomAppBar({
    super.key,
    this.tomId,
    this.tomGroup,
    this.scope,
    this.authorizer,
    this.authorizerStrategy = TomAuthorizerStrategy.authorizerNarrowsOnly,
    this.uiStateController,
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
  }) : basePath = TomCtr.resolvePath(tomId, scope) {
    tomGroup?.register(this);
  }

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0.0;
    return Size.fromHeight((toolbarHeight ?? kToolbarHeight) + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final resolvedTitleText =
        titleText ?? TomCtr.textOrNull(basePath, 'titleText');
    final resolvedTitle =
        resolvedTitleText ?? (tomId != null ? getText('label') : null);
    final effectiveTitle =
        title ?? (resolvedTitle != null ? Text(resolvedTitle) : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedAutomaticallyImplyLeading =
        TomCtr.boolVal(basePath, 'automaticallyImplyLeading') ?? automaticallyImplyLeading;
    final resolvedElevation =
        elevation ?? TomCtr.doubleVal(basePath, 'elevation');
    final resolvedScrolledUnderElevation =
        scrolledUnderElevation ?? TomCtr.doubleVal(basePath, 'scrolledUnderElevation');
    final resolvedShadowColor =
        shadowColor ?? TomCtr.color(basePath, 'shadowColor');
    final resolvedSurfaceTintColor =
        surfaceTintColor ?? TomCtr.color(basePath, 'surfaceTintColor');
    final resolvedBackgroundColor =
        backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    final resolvedForegroundColor =
        foregroundColor ?? TomCtr.color(basePath, 'foregroundColor');
    final resolvedTitleSpacing =
        titleSpacing ?? TomCtr.doubleVal(basePath, 'titleSpacing');
    final resolvedToolbarHeight =
        toolbarHeight ?? TomCtr.doubleVal(basePath, 'toolbarHeight');
    final resolvedLeadingWidth =
        leadingWidth ?? TomCtr.doubleVal(basePath, 'leadingWidth');
    final resolvedPrimary =
        TomCtr.boolVal(basePath, 'primary') ?? primary;
    final resolvedCenterTitle =
        centerTitle ?? TomCtr.boolVal(basePath, 'centerTitle');
    final resolvedExcludeHeaderSemantics =
        TomCtr.boolVal(basePath, 'excludeHeaderSemantics') ?? excludeHeaderSemantics;
    final resolvedToolbarOpacity =
        TomCtr.doubleVal(basePath, 'toolbarOpacity') ?? toolbarOpacity;
    final resolvedBottomOpacity =
        TomCtr.doubleVal(basePath, 'bottomOpacity') ?? bottomOpacity;
    final resolvedForceMaterialTransparency =
        TomCtr.boolVal(basePath, 'forceMaterialTransparency') ?? forceMaterialTransparency;

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
    if (basePath == null) return null;
    return TomStyleResolvers.resolveIconThemeData(basePath!, suffix);
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
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

  // Pre-resolved resource values
  late final Color? _resolvedColor;
  late final double? _resolvedElevation;
  late final double? _resolvedHeight;
  late final Color? _resolvedShadowColor;
  late final Color? _resolvedSurfaceTintColor;
  late final double _resolvedNotchMargin;
  late final EdgeInsetsGeometry? _resolvedPadding;

  TomBottomAppBar({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
  }) {
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
    _resolvedElevation = elevation ?? TomCtr.doubleVal(basePath, 'elevation');
    _resolvedHeight = height ?? TomCtr.doubleVal(basePath, 'height');
    _resolvedShadowColor = shadowColor ?? TomCtr.color(basePath, 'shadowColor');
    _resolvedSurfaceTintColor = surfaceTintColor ?? TomCtr.color(basePath, 'surfaceTintColor');
    _resolvedNotchMargin = TomCtr.doubleVal(basePath, 'notchMargin') ?? notchMargin;
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
  }

  @override
  Widget buildContent(BuildContext context) {
    return BottomAppBar(
      color: _resolvedColor,
      elevation: _resolvedElevation,
      shape: shape,
      clipBehavior: clipBehavior,
      notchMargin: _resolvedNotchMargin,
      padding: _resolvedPadding,
      height: _resolvedHeight,
      shadowColor: _resolvedShadowColor,
      surfaceTintColor: _resolvedSurfaceTintColor,
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

  // Pre-resolved resource values
  late final double? _resolvedHeight;
  late final double? _resolvedThickness;
  late final double? _resolvedIndent;
  late final double? _resolvedEndIndent;
  late final Color? _resolvedColor;

  TomDivider({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.height,
    this.thickness,
    this.indent,
    this.endIndent,
    this.color,
  }) {
    _resolvedHeight = height ?? TomCtr.doubleVal(basePath, 'height');
    _resolvedThickness = thickness ?? TomCtr.doubleVal(basePath, 'thickness');
    _resolvedIndent = indent ?? TomCtr.doubleVal(basePath, 'indent');
    _resolvedEndIndent = endIndent ?? TomCtr.doubleVal(basePath, 'endIndent');
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Divider(
      height: _resolvedHeight,
      thickness: _resolvedThickness,
      indent: _resolvedIndent,
      endIndent: _resolvedEndIndent,
      color: _resolvedColor,
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

  // Pre-resolved resource values
  late final Color? _resolvedColor;
  late final double? _resolvedWidth;
  late final double? _resolvedHeight;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final EdgeInsetsGeometry? _resolvedMargin;
  late final Decoration? _resolvedDecoration;
  late final Decoration? _resolvedForegroundDecoration;
  late final BoxConstraints? _resolvedConstraints;
  late final AlignmentGeometry? _resolvedAlignment;
  late final AlignmentGeometry? _resolvedTransformAlignment;

  TomContainer({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
  }) {
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
    _resolvedWidth = width ?? TomCtr.doubleVal(basePath, 'width');
    _resolvedHeight = height ?? TomCtr.doubleVal(basePath, 'height');
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
    _resolvedMargin = margin ?? TomCtr.edgeInsets(basePath, 'margin');
    _resolvedDecoration = decoration ?? _resolveDecoration('decoration');
    _resolvedForegroundDecoration = foregroundDecoration ?? _resolveDecoration('foregroundDecoration');
    _resolvedConstraints = constraints ?? _resolveBoxConstraints('constraints');
    _resolvedAlignment = alignment ?? _resolveAlignment('alignment');
    _resolvedTransformAlignment = transformAlignment ?? _resolveAlignment('transformAlignment');
  }

  @override
  Widget buildContent(BuildContext context) {
    // Flutter's Container rejects `color` alongside any `decoration`.
    // When the caller passes a BoxDecoration that only sets structural
    // bits (borderRadius / border / shape / gradient) and leaves color
    // unset, fold the resource-resolved color into it so resource-
    // driven colors still reach the container. Same for ShapeDecoration.
    var effectiveDecoration = _resolvedDecoration;
    if (_resolvedColor != null) {
      if (effectiveDecoration is BoxDecoration &&
          effectiveDecoration.color == null &&
          effectiveDecoration.gradient == null) {
        effectiveDecoration =
            effectiveDecoration.copyWith(color: _resolvedColor);
      } else if (effectiveDecoration is ShapeDecoration &&
          effectiveDecoration.color == null &&
          effectiveDecoration.gradient == null) {
        effectiveDecoration = ShapeDecoration(
          color: _resolvedColor,
          image: effectiveDecoration.image,
          gradient: effectiveDecoration.gradient,
          shadows: effectiveDecoration.shadows,
          shape: effectiveDecoration.shape,
        );
      }
    }
    return Container(
      alignment: _resolvedAlignment,
      padding: _resolvedPadding,
      color: effectiveDecoration != null ? null : _resolvedColor,
      decoration: effectiveDecoration,
      foregroundDecoration: _resolvedForegroundDecoration,
      constraints: _resolvedConstraints,
      margin: _resolvedMargin,
      transform: transform,
      transformAlignment: _resolvedTransformAlignment,
      clipBehavior: clipBehavior,
      width: _resolvedWidth,
      height: _resolvedHeight,
      child: child,
    );
  }

  Decoration? _resolveDecoration(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveDecoration(basePath!, suffix);
  }

  BoxConstraints? _resolveBoxConstraints(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBoxConstraints(basePath!, suffix);
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
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

  TomColumn({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
      textBaseline: textBaseline ??
          (crossAxisAlignment == CrossAxisAlignment.baseline
              ? TextBaseline.alphabetic
              : null),
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

  TomRow({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
      textBaseline: textBaseline ??
          (crossAxisAlignment == CrossAxisAlignment.baseline
              ? TextBaseline.alphabetic
              : null),
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

  // Pre-resolved resource values
  late final double _resolvedSpacing;
  late final double _resolvedRunSpacing;

  TomWrap({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
  }) {
    _resolvedSpacing = spacing ?? TomCtr.doubleVal(basePath, 'spacing') ?? 0.0;
    _resolvedRunSpacing = runSpacing ?? TomCtr.doubleVal(basePath, 'runSpacing') ?? 0.0;
  }

  @override
  Widget buildContent(BuildContext context) {
    return Wrap(
      direction: direction,
      alignment: alignment,
      spacing: _resolvedSpacing,
      runAlignment: runAlignment,
      runSpacing: _resolvedRunSpacing,
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

  // Pre-resolved resource values
  late final AlignmentGeometry _resolvedAlignment;

  TomStack({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.fit = StackFit.loose,
    this.clipBehavior = Clip.hardEdge,
    this.children = const [],
  }) {
    _resolvedAlignment = _resolveAlignment('alignment') ?? alignment;
  }

  @override
  Widget buildContent(BuildContext context) {
    return Stack(
      alignment: _resolvedAlignment,
      textDirection: textDirection,
      fit: fit,
      clipBehavior: clipBehavior,
      children: children,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
  }
}

/// Tom wrapper for [IndexedStack].
class TomIndexedStack extends TomContainerBase {
  final int? index;
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;
  final StackFit sizing;
  final List<Widget> children;

  // Pre-resolved resource values
  late final int? _resolvedIndex;
  late final AlignmentGeometry _resolvedAlignment;

  TomIndexedStack({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.index = 0,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.sizing = StackFit.loose,
    this.children = const [],
  }) {
    _resolvedIndex = index ?? TomCtr.intVal(basePath, 'index');
    _resolvedAlignment = _resolveAlignment('alignment') ?? alignment;
  }

  @override
  Widget buildContent(BuildContext context) {
    return IndexedStack(
      index: _resolvedIndex,
      alignment: _resolvedAlignment,
      textDirection: textDirection,
      sizing: sizing,
      children: children,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
  }
}

/// Tom wrapper for [SizedBox].
class TomSizedBox extends TomContainerBase {
  final double? width;
  final double? height;
  final Widget? child;

  // Pre-resolved resource values
  late final double? _resolvedWidth;
  late final double? _resolvedHeight;

  TomSizedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.width,
    this.height,
    this.child,
  }) {
    _resolvedWidth = width ?? TomCtr.doubleVal(basePath, 'width');
    _resolvedHeight = height ?? TomCtr.doubleVal(basePath, 'height');
  }

  @override
  Widget buildContent(BuildContext context) {
    return SizedBox(
      width: _resolvedWidth,
      height: _resolvedHeight,
      child: child,
    );
  }
}

/// Tom wrapper for [ConstrainedBox].
class TomConstrainedBox extends TomContainerBase {
  final BoxConstraints constraints;
  final Widget? child;

  TomConstrainedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  // Pre-resolved resource values
  late final EdgeInsetsGeometry _resolvedPadding;

  TomPadding({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.padding,
    this.child,
  }) {
    _resolvedPadding = TomCtr.edgeInsets(basePath, 'padding') ?? padding;
  }

  @override
  Widget buildContent(BuildContext context) {
    return Padding(
      padding: _resolvedPadding,
      child: child,
    );
  }
}

/// Tom wrapper for [Center].
class TomCenter extends TomContainerBase {
  final double? widthFactor;
  final double? heightFactor;
  final Widget? child;

  // Pre-resolved resource values
  late final double? _resolvedWidthFactor;
  late final double? _resolvedHeightFactor;

  TomCenter({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.widthFactor,
    this.heightFactor,
    this.child,
  }) {
    _resolvedWidthFactor = widthFactor ?? TomCtr.doubleVal(basePath, 'widthFactor');
    _resolvedHeightFactor = heightFactor ?? TomCtr.doubleVal(basePath, 'heightFactor');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Center(
      widthFactor: _resolvedWidthFactor,
      heightFactor: _resolvedHeightFactor,
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

  // Pre-resolved resource values
  late final double? _resolvedWidthFactor;
  late final double? _resolvedHeightFactor;

  TomAlign({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.alignment = Alignment.center,
    this.widthFactor,
    this.heightFactor,
    this.child,
  }) {
    _resolvedWidthFactor = widthFactor ?? TomCtr.doubleVal(basePath, 'widthFactor');
    _resolvedHeightFactor = heightFactor ?? TomCtr.doubleVal(basePath, 'heightFactor');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Align(
      alignment: alignment,
      widthFactor: _resolvedWidthFactor,
      heightFactor: _resolvedHeightFactor,
      child: child,
    );
  }
}

/// Tom wrapper for [AspectRatio].
class TomAspectRatio extends TomContainerBase {
  final double aspectRatio;
  final Widget? child;

  TomAspectRatio({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  TomFittedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  // Pre-resolved resource values
  late final double? _resolvedWidthFactor;
  late final double? _resolvedHeightFactor;

  TomFractionallySizedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.alignment = Alignment.center,
    this.widthFactor,
    this.heightFactor,
    this.child,
  }) {
    _resolvedWidthFactor = widthFactor ?? TomCtr.doubleVal(basePath, 'widthFactor');
    _resolvedHeightFactor = heightFactor ?? TomCtr.doubleVal(basePath, 'heightFactor');
  }

  @override
  Widget buildContent(BuildContext context) {
    return FractionallySizedBox(
      alignment: alignment,
      widthFactor: _resolvedWidthFactor,
      heightFactor: _resolvedHeightFactor,
      child: child,
    );
  }
}

/// Tom wrapper for [IntrinsicHeight].
class TomIntrinsicHeight extends TomContainerBase {
  final Widget? child;

  TomIntrinsicHeight({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  // Pre-resolved resource values
  late final double? _resolvedStepWidth;
  late final double? _resolvedStepHeight;

  TomIntrinsicWidth({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.stepWidth,
    this.stepHeight,
    this.child,
  }) {
    _resolvedStepWidth = stepWidth ?? TomCtr.doubleVal(basePath, 'stepWidth');
    _resolvedStepHeight = stepHeight ?? TomCtr.doubleVal(basePath, 'stepHeight');
  }

  @override
  Widget buildContent(BuildContext context) {
    return IntrinsicWidth(
      stepWidth: _resolvedStepWidth,
      stepHeight: _resolvedStepHeight,
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

  // Pre-resolved resource values
  late final double _resolvedElevation;
  late final Color? _resolvedColor;
  late final Color? _resolvedShadowColor;
  late final Color? _resolvedSurfaceTintColor;
  late final TextStyle? _resolvedTextStyle;
  late final BorderRadiusGeometry? _resolvedBorderRadius;
  late final ShapeBorder? _resolvedShape;

  TomMaterial({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
  }) {
    _resolvedElevation = elevation ?? TomCtr.doubleVal(basePath, 'elevation') ?? 0.0;
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
    _resolvedShadowColor = shadowColor ?? TomCtr.color(basePath, 'shadowColor');
    _resolvedSurfaceTintColor = surfaceTintColor ?? TomCtr.color(basePath, 'surfaceTintColor');
    _resolvedTextStyle = textStyle ?? _resolveTextStyle('textStyle');
    _resolvedBorderRadius = borderRadius ?? _resolveBorderRadius('borderRadius');
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Material(
      type: type,
      elevation: _resolvedElevation,
      color: _resolvedColor,
      shadowColor: _resolvedShadowColor,
      surfaceTintColor: _resolvedSurfaceTintColor,
      textStyle: _resolvedTextStyle,
      borderRadius: _resolvedBorderRadius,
      shape: _resolvedShape,
      borderOnForeground: borderOnForeground,
      clipBehavior: clipBehavior,
      animationDuration: animationDuration,
      child: child,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  BorderRadiusGeometry? _resolveBorderRadius(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderRadius(basePath!, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }
}

/// Tom wrapper for [DecoratedBox].
class TomDecoratedBox extends TomContainerBase {
  final Decoration decoration;
  final DecorationPosition position;
  final Widget? child;

  TomDecoratedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  TomClipRRect({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  TomClipOval({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  TomClipRect({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  // Pre-resolved resource values
  late final String _resolvedTitle;
  late final double? _resolvedElevation;
  late final double? _resolvedScrolledUnderElevation;
  late final Color? _resolvedShadowColor;
  late final Color? _resolvedSurfaceTintColor;
  late final Color? _resolvedBackgroundColor;
  late final Color? _resolvedForegroundColor;
  late final double? _resolvedTitleSpacing;
  late final double? _resolvedExpandedHeight;
  late final double? _resolvedCollapsedHeight;
  late final double? _resolvedLeadingWidth;
  late final IconThemeData? _resolvedIconTheme;
  late final IconThemeData? _resolvedActionsIconTheme;
  late final ShapeBorder? _resolvedShape;
  late final TextStyle? _resolvedToolbarTextStyle;
  late final TextStyle? _resolvedTitleTextStyle;

  TomSliverAppBar({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
  }) {
    _resolvedTitle = titleText ?? TomCtr.textOrFail(basePath, 'label', supersededBy: title);
    _resolvedElevation = elevation ?? TomCtr.doubleVal(basePath, 'elevation');
    _resolvedScrolledUnderElevation = scrolledUnderElevation ?? TomCtr.doubleVal(basePath, 'scrolledUnderElevation');
    _resolvedShadowColor = shadowColor ?? TomCtr.color(basePath, 'shadowColor');
    _resolvedSurfaceTintColor = surfaceTintColor ?? TomCtr.color(basePath, 'surfaceTintColor');
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedForegroundColor = foregroundColor ?? TomCtr.color(basePath, 'foregroundColor');
    _resolvedTitleSpacing = titleSpacing ?? TomCtr.doubleVal(basePath, 'titleSpacing');
    _resolvedExpandedHeight = expandedHeight ?? TomCtr.doubleVal(basePath, 'expandedHeight');
    _resolvedCollapsedHeight = collapsedHeight ?? TomCtr.doubleVal(basePath, 'collapsedHeight');
    _resolvedLeadingWidth = leadingWidth ?? TomCtr.doubleVal(basePath, 'leadingWidth');
    _resolvedIconTheme = iconTheme ?? _resolveIconThemeData('iconTheme');
    _resolvedActionsIconTheme = actionsIconTheme ?? _resolveIconThemeData('actionsIconTheme');
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
    _resolvedToolbarTextStyle = toolbarTextStyle ?? _resolveTextStyle('toolbarTextStyle');
    _resolvedTitleTextStyle = titleTextStyle ?? _resolveTextStyle('titleTextStyle');
  }

  @override
  Widget buildContent(BuildContext context) {
    final effectiveTitle = title ?? Text(_resolvedTitle);

    return SliverAppBar(
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: effectiveTitle,
      actions: actions,
      flexibleSpace: flexibleSpace,
      bottom: bottom,
      elevation: _resolvedElevation,
      scrolledUnderElevation: _resolvedScrolledUnderElevation,
      shadowColor: _resolvedShadowColor,
      surfaceTintColor: _resolvedSurfaceTintColor,
      backgroundColor: _resolvedBackgroundColor,
      foregroundColor: _resolvedForegroundColor,
      iconTheme: _resolvedIconTheme,
      actionsIconTheme: _resolvedActionsIconTheme,
      primary: primary,
      centerTitle: centerTitle,
      excludeHeaderSemantics: excludeHeaderSemantics,
      titleSpacing: _resolvedTitleSpacing,
      expandedHeight: _resolvedExpandedHeight,
      collapsedHeight: _resolvedCollapsedHeight,
      toolbarHeight: toolbarHeight,
      leadingWidth: _resolvedLeadingWidth,
      floating: floating,
      pinned: pinned,
      snap: snap,
      stretch: stretch,
      stretchTriggerOffset: stretchTriggerOffset,
      shape: _resolvedShape,
      toolbarTextStyle: _resolvedToolbarTextStyle,
      titleTextStyle: _resolvedTitleTextStyle,
      systemOverlayStyle: systemOverlayStyle,
      forceMaterialTransparency: forceMaterialTransparency,
      clipBehavior: clipBehavior,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  IconThemeData? _resolveIconThemeData(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveIconThemeData(basePath!, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }
}

/// Tom wrapper for [SliverToBoxAdapter].
class TomSliverToBoxAdapter extends TomContainerBase {
  final Widget? child;

  TomSliverToBoxAdapter({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  TomSliverList({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  TomSliverGrid({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  TomSliverFillRemaining({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  // Pre-resolved resource values
  late final ScrollCacheExtent? _resolvedCacheExtent;

  TomCustomScrollView({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
  }) {
    final cacheExtentPixels = cacheExtent ?? TomCtr.doubleVal(basePath, 'cacheExtent');
    _resolvedCacheExtent = cacheExtentPixels == null ? null : ScrollCacheExtent.pixels(cacheExtentPixels);
  }

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
      scrollCacheExtent: _resolvedCacheExtent,
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
  final TomUIGroup? authorizationGroup;

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

  TomExpansionPanel({
    this.tomId,
    this.authorizationGroup,
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

  // Pre-resolved resource values
  late final Color? _resolvedDividerColor;
  late final double _resolvedElevation;
  late final EdgeInsets _resolvedExpandedHeaderPadding;

  TomExpansionPanelList({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.children = const [],
    this.expansionCallback,
    this.animationDuration = kThemeAnimationDuration,
    this.expandedHeaderPadding,
    this.dividerColor,
    this.elevation,
  }) {
    _resolvedDividerColor = dividerColor ?? TomCtr.color(basePath, 'dividerColor');
    _resolvedElevation = elevation ?? TomCtr.doubleVal(basePath, 'elevation') ?? 2;
    _resolvedExpandedHeaderPadding = expandedHeaderPadding ?? TomCtr.edgeInsets(basePath, 'expandedHeaderPadding') ?? const EdgeInsets.symmetric(vertical: 16.0);
  }

  @override
  Widget buildContent(BuildContext context) {
    return ExpansionPanelList(
      children: children,
      expansionCallback: expansionCallback,
      animationDuration: animationDuration,
      expandedHeaderPadding: _resolvedExpandedHeaderPadding,
      dividerColor: _resolvedDividerColor,
      elevation: _resolvedElevation,
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

  // Pre-resolved resource values
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final Color? _resolvedColor;
  late final double? _resolvedWidth;
  late final double? _resolvedHeight;
  late final Decoration? _resolvedDecoration;

  TomInk({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.padding,
    this.color,
    this.decoration,
    this.width,
    this.height,
    this.child,
  }) {
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
    _resolvedWidth = width ?? TomCtr.doubleVal(basePath, 'width');
    _resolvedHeight = height ?? TomCtr.doubleVal(basePath, 'height');
    _resolvedDecoration = decoration ?? _resolveDecoration('decoration');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Ink(
      padding: _resolvedPadding,
      color: _resolvedDecoration != null ? null : _resolvedColor,
      decoration: _resolvedDecoration,
      width: _resolvedWidth,
      height: _resolvedHeight,
      child: child,
    );
  }

  Decoration? _resolveDecoration(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveDecoration(basePath!, suffix);
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

  @override
  final TomScope? scope;

  @override
  final TomAuthorizer? authorizer;

  @override
  final TomAuthorizerStrategy authorizerStrategy;

  @override
  final TomUIStateController? uiStateController;

  @override
  final String? basePath;

  /// Creates a Tom Expanded widget with optional resource resolution.
  TomExpanded({
    this.tomId,
    this.tomGroup,
    this.scope,
    this.authorizer,
    this.authorizerStrategy = TomAuthorizerStrategy.authorizerNarrowsOnly,
    this.uiStateController,
    super.key,
    super.flex,
    Widget? child,
  }) : basePath = TomCtr.resolvePath(tomId, scope),
       super(child: child ?? TomCtr.defaultTextOrEmpty(TomCtr.childTomId(tomId, 'child'), scope, tomGroup)) {
    tomGroup?.register(this);
  }
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

  @override
  final TomScope? scope;

  @override
  final TomAuthorizer? authorizer;

  @override
  final TomAuthorizerStrategy authorizerStrategy;

  @override
  final TomUIStateController? uiStateController;

  @override
  final String? basePath;

  /// Creates a Tom Flexible widget with optional resource resolution.
  TomFlexible({
    this.tomId,
    this.tomGroup,
    this.scope,
    this.authorizer,
    this.authorizerStrategy = TomAuthorizerStrategy.authorizerNarrowsOnly,
    this.uiStateController,
    super.key,
    super.flex,
    super.fit,
    Widget? child,
  }) : basePath = TomCtr.resolvePath(tomId, scope),
       super(child: child ?? TomCtr.defaultTextOrEmpty(TomCtr.childTomId(tomId, 'child'), scope, tomGroup)) {
    tomGroup?.register(this);
  }
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

  @override
  final TomScope? scope;

  @override
  final TomAuthorizer? authorizer;

  @override
  final TomAuthorizerStrategy authorizerStrategy;

  @override
  final TomUIStateController? uiStateController;

  @override
  final String? basePath;

  /// Creates a Tom Spacer widget.
  TomSpacer({
    this.tomId,
    this.tomGroup,
    this.scope,
    this.authorizer,
    this.authorizerStrategy = TomAuthorizerStrategy.authorizerNarrowsOnly,
    this.uiStateController,
    super.key,
    super.flex,
  }) : basePath = TomCtr.resolvePath(tomId, scope) {
    tomGroup?.register(this);
  }
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
  // Pre-resolved resource values
  late final double? _resolvedLeft;
  late final double? _resolvedTop;
  late final double? _resolvedRight;
  late final double? _resolvedBottom;
  late final double? _resolvedWidth;
  late final double? _resolvedHeight;

  TomPositioned({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
    required this.child,
  }) {
    _initResolvedFields();
  }

  /// Creates a Tom Positioned widget that fills the Stack.
  TomPositioned.fill({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.left = 0.0,
    this.top = 0.0,
    this.right = 0.0,
    this.bottom = 0.0,
    required this.child,
  })  : width = null,
        height = null {
    _initResolvedFields();
  }

  void _initResolvedFields() {
    _resolvedLeft = left ?? TomCtr.doubleVal(basePath, 'left');
    _resolvedTop = top ?? TomCtr.doubleVal(basePath, 'top');
    _resolvedRight = right ?? TomCtr.doubleVal(basePath, 'right');
    _resolvedBottom = bottom ?? TomCtr.doubleVal(basePath, 'bottom');
    _resolvedWidth = width ?? TomCtr.doubleVal(basePath, 'width');
    _resolvedHeight = height ?? TomCtr.doubleVal(basePath, 'height');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Positioned(
      left: _resolvedLeft,
      top: _resolvedTop,
      right: _resolvedRight,
      bottom: _resolvedBottom,
      width: _resolvedWidth,
      height: _resolvedHeight,
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
  // Pre-resolved resource values
  late final double? _resolvedStart;
  late final double? _resolvedTop;
  late final double? _resolvedEnd;
  late final double? _resolvedBottom;
  late final double? _resolvedWidth;
  late final double? _resolvedHeight;

  TomPositionedDirectional({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.start,
    this.top,
    this.end,
    this.bottom,
    this.width,
    this.height,
    required this.child,
  }) {
    _resolvedStart = start ?? TomCtr.doubleVal(basePath, 'start');
    _resolvedTop = top ?? TomCtr.doubleVal(basePath, 'top');
    _resolvedEnd = end ?? TomCtr.doubleVal(basePath, 'end');
    _resolvedBottom = bottom ?? TomCtr.doubleVal(basePath, 'bottom');
    _resolvedWidth = width ?? TomCtr.doubleVal(basePath, 'width');
    _resolvedHeight = height ?? TomCtr.doubleVal(basePath, 'height');
  }

  @override
  Widget buildContent(BuildContext context) {
    return PositionedDirectional(
      start: _resolvedStart,
      top: _resolvedTop,
      end: _resolvedEnd,
      bottom: _resolvedBottom,
      width: _resolvedWidth,
      height: _resolvedHeight,
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

  @override
  final TomScope? scope;

  @override
  final TomAuthorizer? authorizer;

  @override
  final TomAuthorizerStrategy authorizerStrategy;

  @override
  final TomUIStateController? uiStateController;

  @override
  final String? basePath;

  /// Creates a Tom TableCell widget with optional resource resolution.
  TomTableCell({
    this.tomId,
    this.tomGroup,
    this.scope,
    this.authorizer,
    this.authorizerStrategy = TomAuthorizerStrategy.authorizerNarrowsOnly,
    this.uiStateController,
    super.key,
    super.verticalAlignment,
    Widget? child,
  }) : basePath = TomCtr.resolvePath(tomId, scope),
       super(child: child ?? TomCtr.defaultTextOrEmpty(TomCtr.childTomId(tomId, 'child'), scope, tomGroup)) {
    tomGroup?.register(this);
  }
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

  TomSafeArea({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  // Pre-resolved resource values
  late final ScrollPhysics? _resolvedPhysics;
  late final String? _resolvedRestorationId;
  late final EdgeInsetsGeometry? _resolvedPadding;

  TomSingleChildScrollView({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
  }) {
    _resolvedPhysics = physics ?? _resolveScrollPhysics('physics');
    _resolvedRestorationId = restorationId ?? TomCtr.textOrNull(basePath, 'restorationId');
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
  }

  @override
  Widget buildContent(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: scrollDirection,
      reverse: reverse,
      padding: _resolvedPadding,
      physics: _resolvedPhysics,
      controller: controller,
      dragStartBehavior: dragStartBehavior,
      clipBehavior: clipBehavior,
      restorationId: _resolvedRestorationId,
      keyboardDismissBehavior: keyboardDismissBehavior,
      child: child,
    );
  }

  ScrollPhysics? _resolveScrollPhysics(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveScrollPhysics(basePath!, suffix);
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

  // Pre-resolved resource values
  late final EdgeInsets? _resolvedPadding;
  late final Color? _resolvedBackgroundColor;
  late final double? _resolvedElevation;
  late final ShapeBorder? _resolvedShape;
  late final double? _resolvedItemExtent;
  late final double? _resolvedShrinkExtent;

  TomCarouselView({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
    ValueChanged<int>? onTap,
  })  : onTap = InScopeBuilder(scope: scope).wrap1n(onTap) {
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedElevation = elevation ?? TomCtr.doubleVal(basePath, 'elevation');
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
    _resolvedItemExtent = itemExtent ?? TomCtr.doubleVal(basePath, 'itemExtent');
    _resolvedShrinkExtent = shrinkExtent ?? TomCtr.doubleVal(basePath, 'shrinkExtent');
  }

  @override
  Widget buildContent(BuildContext context) {
    return CarouselView(
      padding: _resolvedPadding,
      backgroundColor: _resolvedBackgroundColor,
      elevation: _resolvedElevation,
      shape: _resolvedShape,
      itemExtent: _resolvedItemExtent ?? 200.0,
      shrinkExtent: _resolvedShrinkExtent ?? 0.0,
      controller: controller,
      scrollDirection: scrollDirection,
      reverse: reverse,
      onTap: onTap,
      children: children,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
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

  TomVisibility({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  // Pre-resolved resource values
  late final bool _resolvedOffstage;

  TomOffstage({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.offstage = true,
    this.child,
  }) {
    _resolvedOffstage = TomCtr.boolVal(basePath, 'offstage') ?? offstage;
  }

  @override
  Widget buildContent(BuildContext context) {
    return Offstage(
      offstage: _resolvedOffstage,
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

  // Pre-resolved resource values
  late final Color? _resolvedBackgroundColor;

  TomCupertinoPageScaffold({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.navigationBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    required this.child,
  }) {
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: navigationBar,
      backgroundColor: _resolvedBackgroundColor,
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

  // Pre-resolved resource values
  late final Color? _resolvedBackgroundColor;

  TomCupertinoTabScaffold({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.tabBar,
    required IndexedWidgetBuilder tabBuilder,
    this.controller,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.restorationId,
  }) : tabBuilder = InScopeBuilder(scope: scope).wrap2(tabBuilder) {
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: tabBar,
      tabBuilder: tabBuilder,
      controller: controller,
      backgroundColor: _resolvedBackgroundColor,
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

  // Pre-resolved resource values
  late final EdgeInsetsGeometry? _resolvedPadding;

  TomCupertinoFormRow({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.child,
    this.prefix,
    this.padding,
    this.helper,
    this.error,
  }) {
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoFormRow(
      prefix: prefix,
      padding: _resolvedPadding,
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

  // Pre-resolved resource values
  late final EdgeInsetsGeometry _resolvedMargin;
  late final Color? _resolvedBackgroundColor;

  TomCupertinoFormSection({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.children,
    this.header,
    this.footer,
    this.margin,
    this.backgroundColor,
    this.decoration,
    this.clipBehavior = Clip.none,
    this.insetGrouped = false,
  }) {
    _resolvedMargin = margin ?? TomCtr.edgeInsets(basePath, 'margin') ?? EdgeInsets.zero;
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
  }

  @override
  Widget buildContent(BuildContext context) {
    final resolvedBgColor = _resolvedBackgroundColor ?? CupertinoColors.systemGroupedBackground.resolveFrom(context);
    if (insetGrouped) {
      return CupertinoFormSection.insetGrouped(
        header: header,
        footer: footer,
        margin: _resolvedMargin,
        backgroundColor: resolvedBgColor,
        decoration: decoration,
        clipBehavior: clipBehavior,
        children: children,
      );
    }
    return CupertinoFormSection(
      header: header,
      footer: footer,
      margin: _resolvedMargin,
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

  // Pre-resolved resource values
  late final bool _resolvedFloatHeaderSlivers;
  late final String? _resolvedRestorationId;
  late final ScrollPhysics? _resolvedPhysics;

  TomNestedScrollView({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics,
    required NestedScrollViewHeaderSliversBuilder headerSliverBuilder,
    required this.body,
    this.dragStartBehavior = DragStartBehavior.start,
    this.floatHeaderSlivers,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.scrollBehavior,
  }) : headerSliverBuilder = InScopeBuilder(scope: scope).wrap2(headerSliverBuilder) {
    _resolvedFloatHeaderSlivers = floatHeaderSlivers ?? TomCtr.boolVal(basePath, 'floatHeaderSlivers') ?? false;
    _resolvedRestorationId = restorationId ?? TomCtr.textOrNull(basePath, 'restorationId');
    _resolvedPhysics = physics ?? _resolveScrollPhysics('physics');
  }

  @override
  Widget buildContent(BuildContext context) {
    return NestedScrollView(
      controller: controller,
      scrollDirection: scrollDirection,
      reverse: reverse,
      physics: _resolvedPhysics,
      headerSliverBuilder: headerSliverBuilder,
      body: body,
      dragStartBehavior: dragStartBehavior,
      floatHeaderSlivers: _resolvedFloatHeaderSlivers,
      clipBehavior: clipBehavior,
      restorationId: _resolvedRestorationId,
      scrollBehavior: scrollBehavior,
    );
  }

  ScrollPhysics? _resolveScrollPhysics(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveScrollPhysics(basePath!, suffix);
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

  // Pre-resolved resource values
  late final bool? _resolvedThumbVisibility;
  late final bool? _resolvedTrackVisibility;
  late final double? _resolvedThickness;
  late final bool? _resolvedInteractive;

  TomScrollbar({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.child,
    this.controller,
    this.thumbVisibility,
    this.trackVisibility,
    this.thickness,
    this.radius,
    this.notificationPredicate,
    this.interactive,
    this.scrollbarOrientation,
  }) {
    _resolvedThumbVisibility = thumbVisibility ?? TomCtr.boolVal(basePath, 'thumbVisibility');
    _resolvedTrackVisibility = trackVisibility ?? TomCtr.boolVal(basePath, 'trackVisibility');
    _resolvedThickness = thickness ?? TomCtr.doubleVal(basePath, 'thickness');
    _resolvedInteractive = interactive ?? TomCtr.boolVal(basePath, 'interactive');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Scrollbar(
      controller: controller,
      thumbVisibility: _resolvedThumbVisibility,
      trackVisibility: _resolvedTrackVisibility,
      thickness: _resolvedThickness,
      radius: radius,
      notificationPredicate: notificationPredicate,
      interactive: _resolvedInteractive,
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

  // Pre-resolved resource values
  late final bool? _resolvedThumbVisibility;
  late final double _resolvedThickness;
  late final double _resolvedThicknessWhileDragging;

  TomCupertinoScrollbar({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.child,
    this.controller,
    this.thumbVisibility,
    this.thickness,
    this.thicknessWhileDragging,
    this.radius = CupertinoScrollbar.defaultRadius,
    this.radiusWhileDragging = CupertinoScrollbar.defaultRadiusWhileDragging,
    this.notificationPredicate,
  }) {
    _resolvedThumbVisibility = thumbVisibility ?? TomCtr.boolVal(basePath, 'thumbVisibility');
    _resolvedThickness = thickness ?? TomCtr.doubleVal(basePath, 'thickness') ?? CupertinoScrollbar.defaultThickness;
    _resolvedThicknessWhileDragging = thicknessWhileDragging ?? TomCtr.doubleVal(basePath, 'thicknessWhileDragging') ?? CupertinoScrollbar.defaultThicknessWhileDragging;
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoScrollbar(
      controller: controller,
      thumbVisibility: _resolvedThumbVisibility,
      thickness: _resolvedThickness,
      thicknessWhileDragging: _resolvedThicknessWhileDragging,
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

  // Pre-resolved resource values
  late final double _resolvedInitialChildSize;
  late final double _resolvedMinChildSize;
  late final double _resolvedMaxChildSize;
  late final bool _resolvedExpand;
  late final bool _resolvedSnap;
  late final bool _resolvedShouldCloseOnMinExtent;

  TomDraggableScrollableSheet({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.initialChildSize,
    this.minChildSize,
    this.maxChildSize,
    this.expand,
    this.snap,
    this.snapSizes,
    this.snapAnimationDuration,
    this.controller,
    this.shouldCloseOnMinExtent,
    required ScrollableWidgetBuilder builder,
  }) : builder = InScopeBuilder(scope: scope).wrap2(builder) {
    _resolvedInitialChildSize = initialChildSize ?? TomCtr.doubleVal(basePath, 'initialChildSize') ?? 0.5;
    _resolvedMinChildSize = minChildSize ?? TomCtr.doubleVal(basePath, 'minChildSize') ?? 0.25;
    _resolvedMaxChildSize = maxChildSize ?? TomCtr.doubleVal(basePath, 'maxChildSize') ?? 1.0;
    _resolvedExpand = expand ?? TomCtr.boolVal(basePath, 'expand') ?? true;
    _resolvedSnap = snap ?? TomCtr.boolVal(basePath, 'snap') ?? false;
    _resolvedShouldCloseOnMinExtent = shouldCloseOnMinExtent ?? TomCtr.boolVal(basePath, 'shouldCloseOnMinExtent') ?? true;
  }

  @override
  Widget buildContent(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _resolvedInitialChildSize,
      minChildSize: _resolvedMinChildSize,
      maxChildSize: _resolvedMaxChildSize,
      expand: _resolvedExpand,
      snap: _resolvedSnap,
      snapSizes: snapSizes,
      controller: controller,
      shouldCloseOnMinExtent: _resolvedShouldCloseOnMinExtent,
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

  // Pre-resolved resource values
  late final EdgeInsets _resolvedBoundaryMargin;
  late final bool _resolvedConstrained;
  late final double _resolvedMaxScale;
  late final double _resolvedMinScale;
  late final double _resolvedInteractionEndFrictionCoefficient;
  late final bool _resolvedPanEnabled;
  late final bool _resolvedScaleEnabled;
  late final double _resolvedScaleFactor;
  late final Alignment _resolvedAlignment;

  TomInteractiveViewer({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.clipBehavior = Clip.hardEdge,
    this.panAxis = PanAxis.free,
    this.boundaryMargin,
    this.constrained,
    this.maxScale,
    this.minScale,
    this.interactionEndFrictionCoefficient,
    GestureScaleEndCallback? onInteractionEnd,
    GestureScaleStartCallback? onInteractionStart,
    GestureScaleUpdateCallback? onInteractionUpdate,
    this.panEnabled,
    this.scaleEnabled,
    this.scaleFactor,
    this.transformationController,
    this.alignment,
    required this.child,
  })  : onInteractionEnd = InScopeBuilder(scope: scope).wrap1n(onInteractionEnd),
        onInteractionStart = InScopeBuilder(scope: scope).wrap1n(onInteractionStart),
        onInteractionUpdate = InScopeBuilder(scope: scope).wrap1n(onInteractionUpdate) {
    _resolvedBoundaryMargin = boundaryMargin ?? TomCtr.edgeInsets(basePath, 'boundaryMargin') ?? EdgeInsets.zero;
    _resolvedConstrained = constrained ?? TomCtr.boolVal(basePath, 'constrained') ?? true;
    _resolvedMaxScale = maxScale ?? TomCtr.doubleVal(basePath, 'maxScale') ?? 2.5;
    _resolvedMinScale = minScale ?? TomCtr.doubleVal(basePath, 'minScale') ?? 0.8;
    _resolvedInteractionEndFrictionCoefficient = interactionEndFrictionCoefficient ?? TomCtr.doubleVal(basePath, 'interactionEndFrictionCoefficient') ?? 0.0000135;
    _resolvedPanEnabled = panEnabled ?? TomCtr.boolVal(basePath, 'panEnabled') ?? true;
    _resolvedScaleEnabled = scaleEnabled ?? TomCtr.boolVal(basePath, 'scaleEnabled') ?? true;
    _resolvedScaleFactor = scaleFactor ?? TomCtr.doubleVal(basePath, 'scaleFactor') ?? kDefaultMouseScrollToScaleFactor;
    _resolvedAlignment = alignment ?? _resolveAlignment('alignment') ?? Alignment.topLeft;
  }

  @override
  Widget buildContent(BuildContext context) {
    return InteractiveViewer(
      clipBehavior: clipBehavior,
      panAxis: panAxis,
      boundaryMargin: _resolvedBoundaryMargin,
      constrained: _resolvedConstrained,
      maxScale: _resolvedMaxScale,
      minScale: _resolvedMinScale,
      interactionEndFrictionCoefficient: _resolvedInteractionEndFrictionCoefficient,
      onInteractionEnd: onInteractionEnd,
      onInteractionStart: onInteractionStart,
      onInteractionUpdate: onInteractionUpdate,
      panEnabled: _resolvedPanEnabled,
      scaleEnabled: _resolvedScaleEnabled,
      scaleFactor: _resolvedScaleFactor,
      transformationController: transformationController,
      alignment: _resolvedAlignment,
      child: child,
    );
  }

  Alignment? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    final resolved = TomStyleResolvers.resolveAlignment(basePath!, suffix);
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

  TomClipPath({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  // Pre-resolved resource values
  late final Color _resolvedColor;

  TomColoredBox({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.color,
    this.child,
  }) {
    _resolvedColor = color ?? TomCtr.colorOrFail(basePath, 'color');
  }

  @override
  Widget buildContent(BuildContext context) {
    return ColoredBox(
      color: _resolvedColor,
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

  // Pre-resolved resource values
  late final double _resolvedOpacity;

  TomOpacity({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.opacity,
    this.alwaysIncludeSemantics = false,
    this.child,
  }) {
    _resolvedOpacity = opacity ?? TomCtr.doubleOrFail(basePath, 'opacity');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Opacity(
      opacity: _resolvedOpacity,
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

  // Pre-resolved resource values
  late final AlignmentGeometry? _resolvedAlignment;
  late final bool _resolvedTransformHitTests;

  TomTransform({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.transform,
    this.origin,
    this.alignment,
    this.transformHitTests,
    this.filterQuality,
    this.child,
  }) {
    _resolvedAlignment = alignment ?? _resolveAlignment('alignment');
    _resolvedTransformHitTests = transformHitTests ?? TomCtr.boolVal(basePath, 'transformHitTests') ?? true;
  }

  @override
  Widget buildContent(BuildContext context) {
    return Transform(
      transform: transform,
      origin: origin,
      alignment: _resolvedAlignment,
      transformHitTests: _resolvedTransformHitTests,
      filterQuality: filterQuality,
      child: child,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
  }
}

/// Tom wrapper for [RotatedBox].
///
/// Quarter-turn rotation with child. Auth on rotated content.
class TomRotatedBox extends TomContainerBase {
  final int? quarterTurns;
  final Widget? child;

  // Pre-resolved resource values
  late final int _resolvedQuarterTurns;

  TomRotatedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.quarterTurns,
    this.child,
  }) {
    _resolvedQuarterTurns = quarterTurns ?? TomCtr.intOrFail(basePath, 'quarterTurns');
  }

  @override
  Widget buildContent(BuildContext context) {
    return RotatedBox(
      quarterTurns: _resolvedQuarterTurns,
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

  // Pre-resolved resource values
  late final double _resolvedSpacing;
  late final double _resolvedOverflowSpacing;

  TomOverflowBar({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.spacing,
    this.alignment,
    this.overflowSpacing,
    this.overflowAlignment = OverflowBarAlignment.start,
    this.overflowDirection = VerticalDirection.down,
    this.textDirection,
    this.children = const <Widget>[],
  }) {
    _resolvedSpacing = spacing ?? TomCtr.doubleVal(basePath, 'spacing') ?? 0.0;
    _resolvedOverflowSpacing = overflowSpacing ?? TomCtr.doubleVal(basePath, 'overflowSpacing') ?? 0.0;
  }

  @override
  Widget buildContent(BuildContext context) {
    return OverflowBar(
      spacing: _resolvedSpacing,
      alignment: alignment,
      overflowSpacing: _resolvedOverflowSpacing,
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

  // Pre-resolved resource values
  late final double? _resolvedMinWidth;
  late final double? _resolvedMaxWidth;
  late final double? _resolvedMinHeight;
  late final double? _resolvedMaxHeight;
  late final AlignmentGeometry _resolvedAlignment;

  TomOverflowBox({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.alignment = Alignment.center,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.fit = OverflowBoxFit.max,
    this.child,
  }) {
    _resolvedMinWidth = minWidth ?? TomCtr.doubleVal(basePath, 'minWidth');
    _resolvedMaxWidth = maxWidth ?? TomCtr.doubleVal(basePath, 'maxWidth');
    _resolvedMinHeight = minHeight ?? TomCtr.doubleVal(basePath, 'minHeight');
    _resolvedMaxHeight = maxHeight ?? TomCtr.doubleVal(basePath, 'maxHeight');
    _resolvedAlignment = _resolveAlignment('alignment') ?? alignment;
  }

  @override
  Widget buildContent(BuildContext context) {
    return OverflowBox(
      alignment: _resolvedAlignment,
      minWidth: _resolvedMinWidth,
      maxWidth: _resolvedMaxWidth,
      minHeight: _resolvedMinHeight,
      maxHeight: _resolvedMaxHeight,
      fit: fit,
      child: child,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
  }
}

/// Tom wrapper for [SizedOverflowBox].
///
/// Fixed size with unconstrained child. Auth on content.
class TomSizedOverflowBox extends TomContainerBase {
  final Size size;
  final AlignmentGeometry alignment;
  final Widget? child;

  TomSizedOverflowBox({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  TomUnconstrainedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  TomConstraintsTransformBox({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  // Pre-resolved resource values
  late final double _resolvedMaxWidth;
  late final double _resolvedMaxHeight;

  TomLimitedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.maxWidth,
    this.maxHeight,
    this.child,
  }) {
    _resolvedMaxWidth = maxWidth ?? TomCtr.doubleVal(basePath, 'maxWidth') ?? double.infinity;
    _resolvedMaxHeight = maxHeight ?? TomCtr.doubleVal(basePath, 'maxHeight') ?? double.infinity;
  }

  @override
  Widget buildContent(BuildContext context) {
    return LimitedBox(
      maxWidth: _resolvedMaxWidth,
      maxHeight: _resolvedMaxHeight,
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

  // Pre-resolved resource values
  late final double _resolvedBaseline;

  TomBaseline({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.baseline,
    required this.baselineType,
    this.child,
  }) {
    _resolvedBaseline = baseline ?? TomCtr.doubleOrFail(basePath, 'baseline');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Baseline(
      baseline: _resolvedBaseline,
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

  // Pre-resolved resource values
  late final bool _resolvedReverse;

  TomListBody({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.mainAxis = Axis.vertical,
    this.reverse,
    this.children = const <Widget>[],
  }) {
    _resolvedReverse = reverse ?? TomCtr.boolVal(basePath, 'reverse') ?? false;
  }

  @override
  Widget buildContent(BuildContext context) {
    return ListBody(
      mainAxis: mainAxis,
      reverse: _resolvedReverse,
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

  TomFlow({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  TomCustomMultiChildLayout({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  TomCustomSingleChildLayout({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  // Pre-resolved resource values
  late final bool _resolvedIsComplex;
  late final bool _resolvedWillChange;

  TomCustomPaint({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.painter,
    this.foregroundPainter,
    this.size,
    this.isComplex,
    this.willChange,
    this.child,
  }) {
    _resolvedIsComplex = isComplex ?? TomCtr.boolVal(basePath, 'isComplex') ?? false;
    _resolvedWillChange = willChange ?? TomCtr.boolVal(basePath, 'willChange') ?? false;
  }

  @override
  Widget buildContent(BuildContext context) {
    final resolvedSize = size ?? Size.zero;

    return CustomPaint(
      painter: painter,
      foregroundPainter: foregroundPainter,
      size: resolvedSize,
      isComplex: _resolvedIsComplex,
      willChange: _resolvedWillChange,
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

  // Pre-resolved resource values
  late final double _resolvedElevation;
  late final Color _resolvedColor;
  late final Color _resolvedShadowColor;
  late final BorderRadius? _resolvedBorderRadius;

  TomPhysicalModel({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.shape = BoxShape.rectangle,
    this.clipBehavior = Clip.none,
    this.borderRadius,
    this.elevation,
    this.color,
    this.shadowColor,
    this.child,
  }) {
    _resolvedElevation = elevation ?? TomCtr.doubleVal(basePath, 'elevation') ?? 0.0;
    _resolvedColor = color ?? TomCtr.colorOrFail(basePath, 'color');
    _resolvedShadowColor = shadowColor ?? TomCtr.color(basePath, 'shadowColor') ?? const Color(0xFF000000);
    _resolvedBorderRadius = borderRadius ?? _resolveBorderRadius('borderRadius');
  }

  @override
  Widget buildContent(BuildContext context) {
    return PhysicalModel(
      shape: shape,
      clipBehavior: clipBehavior,
      borderRadius: _resolvedBorderRadius,
      elevation: _resolvedElevation,
      color: _resolvedColor,
      shadowColor: _resolvedShadowColor,
      child: child,
    );
  }

  BorderRadius? _resolveBorderRadius(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderRadius(basePath!, suffix);
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

  // Pre-resolved resource values
  late final double _resolvedElevation;
  late final Color _resolvedColor;
  late final Color _resolvedShadowColor;

  TomPhysicalShape({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.clipper,
    this.clipBehavior = Clip.none,
    this.elevation,
    this.color,
    this.shadowColor,
    this.child,
  }) {
    _resolvedElevation = elevation ?? TomCtr.doubleVal(basePath, 'elevation') ?? 0.0;
    _resolvedColor = color ?? TomCtr.colorOrFail(basePath, 'color');
    _resolvedShadowColor = shadowColor ?? TomCtr.color(basePath, 'shadowColor') ?? const Color(0xFF000000);
  }

  @override
  Widget buildContent(BuildContext context) {
    return PhysicalShape(
      clipper: clipper,
      clipBehavior: clipBehavior,
      elevation: _resolvedElevation,
      color: _resolvedColor,
      shadowColor: _resolvedShadowColor,
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

  // Pre-resolved resource values
  late final bool _resolvedTransformHitTests;

  TomFractionalTranslation({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.translation,
    this.transformHitTests,
    this.child,
  }) {
    _resolvedTransformHitTests = transformHitTests ?? TomCtr.boolVal(basePath, 'transformHitTests') ?? true;
  }

  @override
  Widget buildContent(BuildContext context) {
    return FractionalTranslation(
      translation: translation,
      transformHitTests: _resolvedTransformHitTests,
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

  TomGridTile({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  // Pre-resolved resource values
  late final Color? _resolvedBackgroundColor;

  TomGridTileBar({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.backgroundColor,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
  }) {
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
  }

  @override
  Widget buildContent(BuildContext context) {
    return GridTileBar(
      backgroundColor: _resolvedBackgroundColor,
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

  // Pre-resolved resource values
  late final String _resolvedTitle;

  TomCupertinoExpansionTile({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.title,
    this.titleText,
    required this.child,
    this.controller,
    this.transitionMode = ExpansionTileTransitionMode.fade,
  }) {
    _resolvedTitle = titleText ?? TomCtr.textOrFail(basePath, 'label', supersededBy: title);
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoExpansionTile(
      title: title ?? Text(_resolvedTitle),
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

  TomClipRSuperellipse({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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

  @override
  final TomScope? scope;

  @override
  final TomAuthorizer? authorizer;

  @override
  final TomAuthorizerStrategy authorizerStrategy;

  @override
  final TomUIStateController? uiStateController;

  @override
  final String? basePath;

  TomCupertinoTabView({
    super.key,
    this.tomId,
    this.tomGroup,
    this.scope,
    this.authorizer,
    this.authorizerStrategy = TomAuthorizerStrategy.authorizerNarrowsOnly,
    this.uiStateController,
    super.builder,
    super.navigatorKey,
    super.defaultTitle,
    super.routes,
    super.onGenerateRoute,
    super.onUnknownRoute,
    super.navigatorObservers,
    super.restorationScopeId,
  }) : basePath = TomCtr.resolvePath(tomId, scope) {
    tomGroup?.register(this);
  }
}
