import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../groups/tom_ui_group.dart';
import '../../groups/tom_widget_mixin.dart';
import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_style_resolvers.dart';

/// Tom wrapper for [NavigationRail].
///
/// Adds ID, group, authorization, and resource resolution for labels.
class TomNavigationRail extends TomNavigationBase {
  final int? selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final List<NavigationRailDestination> destinations;
  final Widget? leading;
  final Widget? trailing;
  final NavigationRailLabelType? labelType;
  final Color? backgroundColor;
  final double? elevation;
  final Color? indicatorColor;
  final ShapeBorder? indicatorShape;
  final double? minWidth;
  final double? minExtendedWidth;
  final bool? useIndicator;
  final double? groupAlignment;
  final TextStyle? selectedLabelTextStyle;
  final TextStyle? unselectedLabelTextStyle;
  final IconThemeData? selectedIconTheme;
  final IconThemeData? unselectedIconTheme;
  final bool extended;

  // Pre-resolved resource values
  late final int? _resolvedSelectedIndex;
  late final Color? _resolvedBackgroundColor;
  late final double? _resolvedElevation;
  late final Color? _resolvedIndicatorColor;
  late final double? _resolvedMinWidth;
  late final double? _resolvedMinExtendedWidth;
  late final bool? _resolvedUseIndicator;
  late final double? _resolvedGroupAlignment;
  late final bool _resolvedExtended;
  late final TextStyle? _resolvedSelectedLabelTextStyle;
  late final TextStyle? _resolvedUnselectedLabelTextStyle;
  late final ShapeBorder? _resolvedIndicatorShape;
  late final IconThemeData? _resolvedSelectedIconTheme;
  late final IconThemeData? _resolvedUnselectedIconTheme;

  TomNavigationRail({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.selectedIndex,
    this.onDestinationSelected,
    required this.destinations,
    this.leading,
    this.trailing,
    this.labelType,
    this.backgroundColor,
    this.elevation,
    this.indicatorColor,
    this.indicatorShape,
    this.minWidth,
    this.minExtendedWidth,
    this.useIndicator,
    this.groupAlignment,
    this.selectedLabelTextStyle,
    this.unselectedLabelTextStyle,
    this.selectedIconTheme,
    this.unselectedIconTheme,
    this.extended = false,
  }) {
    _resolvedSelectedIndex = selectedIndex ?? resolveIntOrNull('selectedIndex');
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
    _resolvedElevation = elevation ?? resolveDoubleOrNull('elevation');
    _resolvedIndicatorColor = indicatorColor ?? resolveColorOrNull('indicatorColor');
    _resolvedMinWidth = minWidth ?? resolveDoubleOrNull('minWidth');
    _resolvedMinExtendedWidth = minExtendedWidth ?? resolveDoubleOrNull('minExtendedWidth');
    _resolvedUseIndicator = useIndicator ?? resolveBoolOrNull('useIndicator');
    _resolvedGroupAlignment = groupAlignment ?? resolveDoubleOrNull('groupAlignment');
    _resolvedExtended = resolveBoolOrNull('extended') ?? extended;
    _resolvedSelectedLabelTextStyle = selectedLabelTextStyle ?? _resolveTextStyle('selectedLabelTextStyle');
    _resolvedUnselectedLabelTextStyle = unselectedLabelTextStyle ?? _resolveTextStyle('unselectedLabelTextStyle');
    _resolvedIndicatorShape = indicatorShape ?? _resolveShapeBorder('indicatorShape');
    _resolvedSelectedIconTheme = selectedIconTheme ?? _resolveIconThemeData('selectedIconTheme');
    _resolvedUnselectedIconTheme = unselectedIconTheme ?? _resolveIconThemeData('unselectedIconTheme');
  }

  // Phase 3: Resolve TextStyle from resources
  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }

  IconThemeData? _resolveIconThemeData(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveIconThemeData(basePath!, suffix);
  }

  @override
  Widget buildContent(BuildContext context) {
    return NavigationRail(
      selectedIndex: _resolvedSelectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
      leading: leading,
      trailing: trailing,
      labelType: labelType,
      backgroundColor: _resolvedBackgroundColor,
      elevation: _resolvedElevation,
      indicatorColor: _resolvedIndicatorColor,
      indicatorShape: _resolvedIndicatorShape,
      minWidth: _resolvedMinWidth,
      minExtendedWidth: _resolvedMinExtendedWidth,
      useIndicator: _resolvedUseIndicator,
      groupAlignment: _resolvedGroupAlignment,
      selectedLabelTextStyle: _resolvedSelectedLabelTextStyle,
      unselectedLabelTextStyle: _resolvedUnselectedLabelTextStyle,
      selectedIconTheme: _resolvedSelectedIconTheme,
      unselectedIconTheme: _resolvedUnselectedIconTheme,
      extended: _resolvedExtended,
    );
  }
}

/// Tom wrapper for [NavigationBar].
///
/// Adds ID, group, authorization, and resource resolution.
class TomNavigationBar extends TomNavigationBase {
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final List<Widget> destinations;
  final Color? backgroundColor;
  final Color? indicatorColor;
  final ShapeBorder? indicatorShape;
  final double? elevation;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final Duration? animationDuration;
  final NavigationDestinationLabelBehavior? labelBehavior;
  final double? height;
  final WidgetStateProperty<TextStyle?>? labelTextStyle;
  final WidgetStateProperty<IconThemeData?>? iconTheme;
  final WidgetStateProperty<Color?>? overlayColor;

  // Pre-resolved resource values
  late final int _resolvedSelectedIndex;
  late final Color? _resolvedBackgroundColor;
  late final Color? _resolvedIndicatorColor;
  late final double? _resolvedElevation;
  late final Color? _resolvedShadowColor;
  late final Color? _resolvedSurfaceTintColor;
  late final double? _resolvedHeight;
  late final ShapeBorder? _resolvedIndicatorShape;

  TomNavigationBar({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.selectedIndex = 0,
    this.onDestinationSelected,
    required this.destinations,
    this.backgroundColor,
    this.indicatorColor,
    this.indicatorShape,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.animationDuration,
    this.labelBehavior,
    this.height,
    this.labelTextStyle,
    this.iconTheme,
    this.overlayColor,
  }) {
    _resolvedSelectedIndex = resolveIntOrNull('selectedIndex') ?? selectedIndex;
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
    _resolvedIndicatorColor = indicatorColor ?? resolveColorOrNull('indicatorColor');
    _resolvedElevation = elevation ?? resolveDoubleOrNull('elevation');
    _resolvedShadowColor = shadowColor ?? resolveColorOrNull('shadowColor');
    _resolvedSurfaceTintColor = surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    _resolvedHeight = height ?? resolveDoubleOrNull('height');
    _resolvedIndicatorShape = indicatorShape ?? _resolveShapeBorder('indicatorShape');
  }

  @override
  Widget buildContent(BuildContext context) {
    return NavigationBar(
      selectedIndex: _resolvedSelectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
      backgroundColor: _resolvedBackgroundColor,
      indicatorColor: _resolvedIndicatorColor,
      indicatorShape: _resolvedIndicatorShape,
      elevation: _resolvedElevation,
      shadowColor: _resolvedShadowColor,
      surfaceTintColor: _resolvedSurfaceTintColor,
      animationDuration: animationDuration,
      labelBehavior: labelBehavior,
      height: _resolvedHeight,
      overlayColor: overlayColor,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }
}

/// Tom wrapper for [TabBar].
///
/// Adds ID, group, and authorization.
/// Implements [PreferredSizeWidget] for use in [AppBar.bottom].
class TomTabBar extends TomNavigationBase implements PreferredSizeWidget {
  final List<Widget> tabs;
  final TabController? controller;
  final bool isScrollable;
  final EdgeInsetsGeometry? padding;
  final Color? indicatorColor;
  final double? indicatorWeight;
  final EdgeInsetsGeometry? indicatorPadding;
  final Decoration? indicator;
  final TabBarIndicatorSize? indicatorSize;
  final Color? dividerColor;
  final double? dividerHeight;
  final Color? labelColor;
  final TextStyle? labelStyle;
  final EdgeInsetsGeometry? labelPadding;
  final Color? unselectedLabelColor;
  final TextStyle? unselectedLabelStyle;
  final DragStartBehavior? dragStartBehavior;
  final WidgetStateProperty<Color?>? overlayColor;
  final ValueChanged<int>? onTap;
  final bool automaticIndicatorColorAdjustment;
  final ScrollPhysics? physics;
  final InteractiveInkFeatureFactory? splashFactory;
  final BorderRadius? splashBorderRadius;
  final TabAlignment? tabAlignment;
  final TextScaler? textScaler;

  // Pre-resolved resource values
  late final bool _resolvedIsScrollable;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final Color? _resolvedIndicatorColor;
  late final double? _resolvedIndicatorWeight;
  late final EdgeInsetsGeometry? _resolvedIndicatorPadding;
  late final Color? _resolvedDividerColor;
  late final double? _resolvedDividerHeight;
  late final Color? _resolvedLabelColor;
  late final Color? _resolvedUnselectedLabelColor;
  late final EdgeInsetsGeometry? _resolvedLabelPadding;
  late final bool _resolvedAutomaticIndicatorColorAdjustment;
  late final TextStyle? _resolvedLabelStyle;
  late final TextStyle? _resolvedUnselectedLabelStyle;
  late final Decoration? _resolvedIndicator;
  late final BorderRadius? _resolvedSplashBorderRadius;

  TomTabBar({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.padding,
    this.indicatorColor,
    this.indicatorWeight,
    this.indicatorPadding,
    this.indicator,
    this.indicatorSize,
    this.dividerColor,
    this.dividerHeight,
    this.labelColor,
    this.labelStyle,
    this.labelPadding,
    this.unselectedLabelColor,
    this.unselectedLabelStyle,
    this.dragStartBehavior,
    this.overlayColor,
    this.onTap,
    this.automaticIndicatorColorAdjustment = true,
    this.physics,
    this.splashFactory,
    this.splashBorderRadius,
    this.tabAlignment,
    this.textScaler,
  }) {
    _resolvedIsScrollable = resolveBoolOrNull('isScrollable') ?? isScrollable;
    _resolvedPadding = padding ?? resolveEdgeInsetsOrNull('padding');
    _resolvedIndicatorColor = indicatorColor ?? resolveColorOrNull('indicatorColor');
    _resolvedIndicatorWeight = indicatorWeight ?? resolveDoubleOrNull('indicatorWeight');
    _resolvedIndicatorPadding = indicatorPadding ?? resolveEdgeInsetsOrNull('indicatorPadding');
    _resolvedDividerColor = dividerColor ?? resolveColorOrNull('dividerColor');
    _resolvedDividerHeight = dividerHeight ?? resolveDoubleOrNull('dividerHeight');
    _resolvedLabelColor = labelColor ?? resolveColorOrNull('labelColor');
    _resolvedUnselectedLabelColor = unselectedLabelColor ?? resolveColorOrNull('unselectedLabelColor');
    _resolvedLabelPadding = labelPadding ?? resolveEdgeInsetsOrNull('labelPadding');
    _resolvedAutomaticIndicatorColorAdjustment = resolveBoolOrNull('automaticIndicatorColorAdjustment') ?? automaticIndicatorColorAdjustment;
    _resolvedLabelStyle = labelStyle ?? _resolveTextStyle('labelStyle');
    _resolvedUnselectedLabelStyle = unselectedLabelStyle ?? _resolveTextStyle('unselectedLabelStyle');
    _resolvedIndicator = indicator ?? _resolveDecoration('indicator');
    _resolvedSplashBorderRadius = splashBorderRadius ?? _resolveBorderRadius('splashBorderRadius');
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (indicatorWeight ?? 2.0),
      );

  // Phase 3: Resolve TextStyle from resources
  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  @override
  Widget buildContent(BuildContext context) {
    return TabBar(
      tabs: tabs,
      controller: controller,
      isScrollable: _resolvedIsScrollable,
      padding: _resolvedPadding,
      indicatorColor: _resolvedIndicatorColor,
      indicatorWeight: _resolvedIndicatorWeight ?? 2.0,
      indicatorPadding: _resolvedIndicatorPadding ?? EdgeInsets.zero,
      indicator: _resolvedIndicator,
      indicatorSize: indicatorSize,
      dividerColor: _resolvedDividerColor,
      dividerHeight: _resolvedDividerHeight,
      labelColor: _resolvedLabelColor,
      labelStyle: _resolvedLabelStyle,
      labelPadding: _resolvedLabelPadding,
      unselectedLabelColor: _resolvedUnselectedLabelColor,
      unselectedLabelStyle: _resolvedUnselectedLabelStyle,
      overlayColor: overlayColor,
      onTap: onTap,
      automaticIndicatorColorAdjustment: _resolvedAutomaticIndicatorColorAdjustment,
      physics: physics,
      splashFactory: splashFactory,
      splashBorderRadius: _resolvedSplashBorderRadius,
      tabAlignment: tabAlignment,
      textScaler: textScaler,
    );
  }

  Decoration? _resolveDecoration(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveDecoration(basePath!, suffix);
  }

  BorderRadius? _resolveBorderRadius(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderRadius(basePath!, suffix);
  }
}

/// Tom wrapper for [NavigationDrawer].
///
/// Adds ID, group, and authorization.
class TomNavigationDrawer extends TomNavigationBase {
  final List<Widget> children;
  final int? selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final Color? backgroundColor;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final double? elevation;
  final Color? indicatorColor;
  final ShapeBorder? indicatorShape;
  final EdgeInsetsGeometry? tilePadding;

  // Pre-resolved resource values
  late final int? _resolvedSelectedIndex;
  late final Color? _resolvedBackgroundColor;
  late final Color? _resolvedShadowColor;
  late final Color? _resolvedSurfaceTintColor;
  late final double? _resolvedElevation;
  late final Color? _resolvedIndicatorColor;
  late final EdgeInsetsGeometry? _resolvedTilePadding;
  late final ShapeBorder? _resolvedIndicatorShape;

  TomNavigationDrawer({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.children,
    this.selectedIndex,
    this.onDestinationSelected,
    this.backgroundColor,
    this.shadowColor,
    this.surfaceTintColor,
    this.elevation,
    this.indicatorColor,
    this.indicatorShape,
    this.tilePadding,
  }) {
    _resolvedSelectedIndex = selectedIndex ?? resolveIntOrNull('selectedIndex');
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
    _resolvedShadowColor = shadowColor ?? resolveColorOrNull('shadowColor');
    _resolvedSurfaceTintColor = surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    _resolvedElevation = elevation ?? resolveDoubleOrNull('elevation');
    _resolvedIndicatorColor = indicatorColor ?? resolveColorOrNull('indicatorColor');
    _resolvedTilePadding = tilePadding ?? resolveEdgeInsetsOrNull('tilePadding');
    _resolvedIndicatorShape = indicatorShape ?? _resolveShapeBorder('indicatorShape');
  }

  @override
  Widget buildContent(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: _resolvedSelectedIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: _resolvedBackgroundColor,
      shadowColor: _resolvedShadowColor,
      surfaceTintColor: _resolvedSurfaceTintColor,
      elevation: _resolvedElevation,
      indicatorColor: _resolvedIndicatorColor,
      indicatorShape: _resolvedIndicatorShape,
      tilePadding: _resolvedTilePadding ?? const EdgeInsets.symmetric(horizontal: 12.0),
      children: children,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }
}

/// Tom wrapper for [Drawer].
///
/// Adds ID, group, and authorization.
class TomDrawer extends TomNavigationBase {
  final Widget? child;
  final Color? backgroundColor;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final double? elevation;
  final ShapeBorder? shape;
  final double? width;
  final Clip? clipBehavior;
  final String? semanticLabel;

  // Pre-resolved resource values
  late final String? _resolvedLabel;
  late final Color? _resolvedBackgroundColor;
  late final Color? _resolvedShadowColor;
  late final Color? _resolvedSurfaceTintColor;
  late final double? _resolvedElevation;
  late final double? _resolvedWidth;
  late final ShapeBorder? _resolvedShape;

  TomDrawer({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.child,
    this.backgroundColor,
    this.shadowColor,
    this.surfaceTintColor,
    this.elevation,
    this.shape,
    this.width,
    this.clipBehavior,
    this.semanticLabel,
  }) {
    _resolvedLabel = semanticLabel ?? resolveResourceOrNull('semanticLabel') ?? (tomId != null ? resolveResourceOrFail('label') : null);
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
    _resolvedShadowColor = shadowColor ?? resolveColorOrNull('shadowColor');
    _resolvedSurfaceTintColor = surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    _resolvedElevation = elevation ?? resolveDoubleOrNull('elevation');
    _resolvedWidth = width ?? resolveDoubleOrNull('width');
    _resolvedShape = shape ?? _resolveShapeBorder('shape');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Drawer(
      backgroundColor: _resolvedBackgroundColor,
      shadowColor: _resolvedShadowColor,
      surfaceTintColor: _resolvedSurfaceTintColor,
      elevation: _resolvedElevation,
      shape: _resolvedShape,
      width: _resolvedWidth,
      clipBehavior: clipBehavior,
      semanticLabel: _resolvedLabel,
      child: child,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
  }
}

/// Tom wrapper for [BottomNavigationBar].
///
/// Adds ID, group, and authorization.
class TomBottomNavigationBar extends TomNavigationBase {
  final List<BottomNavigationBarItem> items;
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final double? elevation;
  final BottomNavigationBarType? type;
  final Color? fixedColor;
  final Color? backgroundColor;
  final double? iconSize;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final IconThemeData? selectedIconTheme;
  final IconThemeData? unselectedIconTheme;
  final TextStyle? selectedLabelStyle;
  final TextStyle? unselectedLabelStyle;
  final double? selectedFontSize;
  final double? unselectedFontSize;
  final bool? showSelectedLabels;
  final bool? showUnselectedLabels;
  final bool? enableFeedback;
  final BottomNavigationBarLandscapeLayout? landscapeLayout;
  final MouseCursor? mouseCursor;

  // Pre-resolved resource values
  late final int _resolvedCurrentIndex;
  late final double? _resolvedElevation;
  late final Color? _resolvedBackgroundColor;
  late final double _resolvedIconSize;
  late final Color? _resolvedSelectedItemColor;
  late final Color? _resolvedUnselectedItemColor;
  late final IconThemeData? _resolvedSelectedIconTheme;
  late final IconThemeData? _resolvedUnselectedIconTheme;
  late final TextStyle? _resolvedSelectedLabelStyle;
  late final TextStyle? _resolvedUnselectedLabelStyle;

  TomBottomNavigationBar({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.items,
    this.currentIndex = 0,
    this.onTap,
    this.elevation,
    this.type,
    this.fixedColor,
    this.backgroundColor,
    this.iconSize,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.selectedIconTheme,
    this.unselectedIconTheme,
    this.selectedLabelStyle,
    this.unselectedLabelStyle,
    this.selectedFontSize,
    this.unselectedFontSize,
    this.showSelectedLabels,
    this.showUnselectedLabels,
    this.enableFeedback,
    this.landscapeLayout,
    this.mouseCursor,
  }) {
    _resolvedCurrentIndex = resolveIntOrNull('currentIndex') ?? currentIndex;
    _resolvedElevation = elevation ?? resolveDoubleOrNull('elevation');
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
    _resolvedIconSize = iconSize ?? resolveDoubleOrNull('iconSize') ?? 24.0;
    _resolvedSelectedItemColor = selectedItemColor ?? resolveColorOrNull('selectedItemColor');
    _resolvedUnselectedItemColor = unselectedItemColor ?? resolveColorOrNull('unselectedItemColor');
    _resolvedSelectedIconTheme = selectedIconTheme ?? _resolveIconThemeData('selectedIconTheme');
    _resolvedUnselectedIconTheme = unselectedIconTheme ?? _resolveIconThemeData('unselectedIconTheme');
    _resolvedSelectedLabelStyle = selectedLabelStyle ?? _resolveTextStyle('selectedLabelStyle');
    _resolvedUnselectedLabelStyle = unselectedLabelStyle ?? _resolveTextStyle('unselectedLabelStyle');
  }

  @override
  Widget buildContent(BuildContext context) {
    return BottomNavigationBar(
      items: items,
      currentIndex: _resolvedCurrentIndex,
      onTap: onTap,
      elevation: _resolvedElevation,
      type: type,
      fixedColor: fixedColor,
      backgroundColor: _resolvedBackgroundColor,
      iconSize: _resolvedIconSize,
      selectedItemColor: _resolvedSelectedItemColor,
      unselectedItemColor: _resolvedUnselectedItemColor,
      selectedIconTheme: _resolvedSelectedIconTheme,
      unselectedIconTheme: _resolvedUnselectedIconTheme,
      selectedLabelStyle: _resolvedSelectedLabelStyle,
      unselectedLabelStyle: _resolvedUnselectedLabelStyle,
      selectedFontSize: selectedFontSize ?? 14.0,
      unselectedFontSize: unselectedFontSize ?? 12.0,
      showSelectedLabels: showSelectedLabels,
      showUnselectedLabels: showUnselectedLabels,
      enableFeedback: enableFeedback,
      landscapeLayout: landscapeLayout,
      mouseCursor: mouseCursor,
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
}

/// Tom wrapper for [Stepper].
///
/// Adds ID, group, and authorization.
class TomStepper extends TomNavigationBase {
  final List<Step> steps;
  final int currentStep;
  final StepperType type;
  final ScrollPhysics? physics;
  final VoidCallback? onStepTapped;
  final VoidCallback? onStepContinue;
  final VoidCallback? onStepCancel;
  final Widget Function(BuildContext, ControlsDetails)? controlsBuilder;
  final double? elevation;
  final EdgeInsetsGeometry? margin;
  final double? connectorThickness;
  final Color? connectorColor;

  // Pre-resolved resource values
  late final ScrollPhysics? _resolvedPhysics;
  late final double? _resolvedElevation;
  late final double? _resolvedConnectorThickness;
  late final Color? _resolvedConnectorColor;

  TomStepper({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.steps,
    this.currentStep = 0,
    this.type = StepperType.vertical,
    this.physics,
    this.onStepTapped,
    this.onStepContinue,
    this.onStepCancel,
    this.controlsBuilder,
    this.elevation,
    this.margin,
    this.connectorThickness,
    this.connectorColor,
  }) {
    _resolvedPhysics = physics ?? _resolveScrollPhysics('physics');
    _resolvedElevation = elevation ?? resolveDoubleOrNull('elevation');
    _resolvedConnectorThickness = connectorThickness ?? resolveDoubleOrNull('connectorThickness');
    _resolvedConnectorColor = connectorColor ?? resolveColorOrNull('connectorColor');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Stepper(
      steps: steps,
      currentStep: currentStep,
      type: type,
      physics: _resolvedPhysics,
      onStepContinue: onStepContinue,
      onStepCancel: onStepCancel,
      controlsBuilder: controlsBuilder,
      elevation: _resolvedElevation,
      margin: margin,
      connectorThickness: _resolvedConnectorThickness,
      connectorColor: _resolvedConnectorColor != null ? WidgetStatePropertyAll<Color>(_resolvedConnectorColor) : null,
    );
  }

  ScrollPhysics? _resolveScrollPhysics(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveScrollPhysics(basePath!, suffix);
  }
}

/// Tom wrapper for [TabBarView].
///
/// Adds ID, group, and authorization.
class TomTabBarView extends TomNavigationBase {
  final List<Widget> children;
  final TabController? controller;
  final ScrollPhysics? physics;
  final DragStartBehavior dragStartBehavior;
  final double? viewportFraction;
  final Clip clipBehavior;

  // Pre-resolved resource values
  late final double _resolvedViewportFraction;

  TomTabBarView({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.children,
    this.controller,
    this.physics,
    this.dragStartBehavior = DragStartBehavior.start,
    this.viewportFraction,
    this.clipBehavior = Clip.hardEdge,
  }) {
    _resolvedViewportFraction = viewportFraction ?? resolveDoubleOrNull('viewportFraction') ?? 1.0;
  }

  @override
  Widget buildContent(BuildContext context) {
    return TabBarView(
      controller: controller,
      physics: physics,
      dragStartBehavior: dragStartBehavior,
      viewportFraction: _resolvedViewportFraction,
      clipBehavior: clipBehavior,
      children: children,
    );
  }
}

/// Tom wrapper for [PageView].
///
/// Adds ID, group, and authorization.
class TomPageView extends TomNavigationBase {
  final List<Widget> children;
  final PageController? controller;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollPhysics? physics;
  final bool pageSnapping;
  final ValueChanged<int>? onPageChanged;
  final DragStartBehavior dragStartBehavior;
  final bool allowImplicitScrolling;
  final String? restorationId;
  final Clip clipBehavior;
  final ScrollBehavior? scrollBehavior;
  final bool padEnds;

  TomPageView({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.children,
    this.controller,
    this.scrollDirection = Axis.horizontal,
    this.reverse = false,
    this.physics,
    this.pageSnapping = true,
    this.onPageChanged,
    this.dragStartBehavior = DragStartBehavior.start,
    this.allowImplicitScrolling = false,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.scrollBehavior,
    this.padEnds = true,
  });

  @override
  Widget buildContent(BuildContext context) {
    return PageView(
      controller: controller,
      scrollDirection: scrollDirection,
      reverse: reverse,
      physics: physics,
      pageSnapping: pageSnapping,
      onPageChanged: onPageChanged,
      dragStartBehavior: dragStartBehavior,
      allowImplicitScrolling: allowImplicitScrolling,
      restorationId: restorationId,
      clipBehavior: clipBehavior,
      scrollBehavior: scrollBehavior,
      padEnds: padEnds,
      children: children,
    );
  }
}

/// Tom wrapper for [CupertinoTabBar].
///
/// iOS-style bottom tab bar. Adds ID, group, authorization,
/// and resource resolution.
class TomCupertinoTabBar extends TomNavigationBase {
  final List<BottomNavigationBarItem> items;
  final ValueChanged<int>? onTap;
  final int currentIndex;
  final Color? backgroundColor;
  final Color? activeColor;
  final Color inactiveColor;
  final double? iconSize;
  final double? height;
  final Border? border;

  // Pre-resolved resource values
  late final Color? _resolvedBackgroundColor;
  late final Color? _resolvedActiveColor;
  late final double _resolvedIconSize;
  late final double _resolvedHeight;

  TomCupertinoTabBar({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.items,
    this.onTap,
    this.currentIndex = 0,
    this.backgroundColor,
    this.activeColor,
    this.inactiveColor = CupertinoColors.inactiveGray,
    this.iconSize,
    this.height,
    this.border,
  }) {
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
    _resolvedActiveColor = activeColor ?? resolveColorOrNull('activeColor');
    _resolvedIconSize = iconSize ?? resolveDoubleOrNull('iconSize') ?? 30.0;
    _resolvedHeight = height ?? resolveDoubleOrNull('height') ?? 50.0;
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoTabBar(
      items: items,
      onTap: onTap,
      currentIndex: currentIndex,
      backgroundColor: _resolvedBackgroundColor,
      activeColor: _resolvedActiveColor,
      inactiveColor: inactiveColor,
      iconSize: _resolvedIconSize,
      height: _resolvedHeight,
      border: border,
    );
  }
}

/// Tom wrapper for [CupertinoNavigationBar].
///
/// iOS-style navigation bar. Adds ID, group, authorization,
/// and resource resolution.
class TomCupertinoNavigationBar extends TomNavigationBase {
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool automaticallyImplyMiddle;
  final String? previousPageTitle;
  final Widget? middle;
  final Widget? trailing;
  final Color? backgroundColor;
  final Brightness? brightness;
  final EdgeInsetsDirectional? padding;
  final Border? border;
  final bool transitionBetweenRoutes;
  final Object? heroTag;

  // Pre-resolved resource values
  late final String? _resolvedPreviousPageTitle;
  late final Color? _resolvedBackgroundColor;

  TomCupertinoNavigationBar({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.automaticallyImplyMiddle = true,
    this.previousPageTitle,
    this.middle,
    this.trailing,
    this.backgroundColor,
    this.brightness,
    this.padding,
    this.border,
    this.transitionBetweenRoutes = true,
    this.heroTag,
  }) {
    _resolvedPreviousPageTitle = previousPageTitle ?? resolveResourceOrNull('previousPageTitle');
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
  }

  @override
  Widget buildContent(BuildContext context) {
    // When transitionBetweenRoutes is true, Flutter asserts heroTag must be
    // identical to its internal _defaultHeroTag. We can't access that constant,
    // so we omit heroTag entirely (letting Flutter use its default).
    // When transitions are disabled, we can safely pass a custom heroTag.
    if (!transitionBetweenRoutes && heroTag != null) {
      return CupertinoNavigationBar(
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        automaticallyImplyMiddle: automaticallyImplyMiddle,
        previousPageTitle: _resolvedPreviousPageTitle,
        middle: middle,
        trailing: trailing,
        backgroundColor: _resolvedBackgroundColor,
        brightness: brightness,
        padding: padding,
        border: border,
        transitionBetweenRoutes: transitionBetweenRoutes,
        heroTag: heroTag!,
      );
    }

    return CupertinoNavigationBar(
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      automaticallyImplyMiddle: automaticallyImplyMiddle,
      previousPageTitle: _resolvedPreviousPageTitle,
      middle: middle,
      trailing: trailing,
      backgroundColor: _resolvedBackgroundColor,
      brightness: brightness,
      padding: padding,
      border: border,
      transitionBetweenRoutes: transitionBetweenRoutes,
    );
  }
}

/// Tom wrapper for a custom Breadcrumb navigation widget.
///
/// A simple horizontal breadcrumb trail. Adds ID, group, authorization,
/// and resource resolution.
class TomBreadcrumb extends TomNavigationBase {
  final List<Widget> items;
  final Widget separator;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final EdgeInsetsGeometry? padding;

  // Pre-resolved resource values
  late final EdgeInsetsGeometry? _resolvedPadding;

  TomBreadcrumb({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.items,
    this.separator = const Text(' / '),
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.padding,
  }) {
    _resolvedPadding = padding ?? resolveEdgeInsetsOrNull('padding');
  }

  @override
  Widget buildContent(BuildContext context) {
    final breadcrumbChildren = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      breadcrumbChildren.add(items[i]);
      if (i < items.length - 1) {
        breadcrumbChildren.add(separator);
      }
    }

    final row = Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: breadcrumbChildren,
    );

    if (_resolvedPadding != null) {
      return Padding(padding: _resolvedPadding, child: row);
    }
    return row;
  }
}

// ============================================================================
// EXTENSION-BASED WIDGETS (extends Flutter widget + TomWidgetMixin)
// ============================================================================

/// Tom widget that EXTENDS [Tab] with authorization and resources.
///
/// This widget IS a [Tab] — it passes `is Tab` checks and fits in `List<Tab>`.
///
/// **StatelessWidget pattern:**
/// - Override `build()`, check visibility, apply readonly, delegate to super
///
/// ```dart
/// TabBar(
///   tabs: [
///     TomTab(tomId: 'home', text: 'Home'),
///     TomTab(tomId: 'settings', text: 'Settings'),
///   ],
/// )
/// ```
class TomTab extends Tab with TomWidgetMixin {
  /// Creates a Tom Tab.
  ///
  /// Requires [tomId] for authorization and resource resolution.
  /// At least one of [text], [icon], or [child] must be non-null.
  TomTab({
    this.tomId,
    this.tomGroup,
    this.scope,
    super.key,
    super.text,
    super.icon,
    super.iconMargin,
    super.height,
    super.child,
  }) : basePath = TomCtr.resolvePath(tomId, scope) {
    tomGroup?.register(this);
  }

  @override
  final String? tomId;

  @override
  final TomUIGroup? tomGroup;

  @override
  final TomScope? scope;

  @override
  final String? basePath;

  @override
  Widget build(BuildContext context) {
    final hidden = checkHidden();
    if (hidden != null) return hidden;

    final resolvedText =
        text ?? (tomId != null ? getText('text') : null);

    return applyReadonly(
      context,
      Tab(
        key: key,
        text: resolvedText,
        icon: icon,
        iconMargin: iconMargin,
        height: height,
        child: child,
      ),
    );
  }
}

/// Tom widget that EXTENDS [NavigationDestination] with authorization and resources.
///
/// This widget IS a [NavigationDestination] — it passes `is NavigationDestination`
/// checks and fits in `List<Widget>` for NavigationBar.
///
/// ```dart
/// NavigationBar(
///   destinations: [
///     TomNavigationDestination(tomId: 'home', icon: Icon(Icons.home), label: 'Home'),
///     TomNavigationDestination(tomId: 'settings', icon: Icon(Icons.settings), label: 'Settings'),
///   ],
/// )
/// ```
class TomNavigationDestination extends NavigationDestination
    with TomWidgetMixin {
  /// Creates a Tom NavigationDestination.
  TomNavigationDestination({
    this.tomId,
    this.tomGroup,
    this.scope,
    super.key,
    required super.icon,
    super.selectedIcon,
    required super.label,
    super.tooltip,
    super.enabled,
  }) : basePath = TomCtr.resolvePath(tomId, scope) {
    tomGroup?.register(this);
  }

  @override
  final String? tomId;

  @override
  final TomUIGroup? tomGroup;

  @override
  final TomScope? scope;

  @override
  final String? basePath;

  @override
  Widget build(BuildContext context) {
    final hidden = checkHidden();
    if (hidden != null) return hidden;

    final resolvedLabel =
        label.isNotEmpty ? label : (tomId != null ? getText('label') : label);
    final resolvedTooltip =
        tooltip ?? (tomId != null ? getText('tooltip') : null);

    return applyReadonly(
      context,
      NavigationDestination(
        key: key,
        icon: icon,
        selectedIcon: selectedIcon,
        label: resolvedLabel,
        tooltip: resolvedTooltip,
        enabled: enabled,
      ),
    );
  }
}

/// Tom widget that EXTENDS [NavigationDrawerDestination] with authorization.
///
/// This widget IS a [NavigationDrawerDestination] — passes runtime checks
/// in [NavigationDrawer].
///
/// ```dart
/// NavigationDrawer(
///   children: [
///     TomNavigationDrawerDestination(tomId: 'home', icon: Icon(Icons.home), label: Text('Home')),
///   ],
/// )
/// ```
class TomNavigationDrawerDestination extends NavigationDrawerDestination
    with TomWidgetMixin {
  /// Creates a Tom NavigationDrawerDestination.
  TomNavigationDrawerDestination({
    this.tomId,
    this.tomGroup,
    this.scope,
    super.key,
    required super.icon,
    super.selectedIcon,
    required super.label,
    super.backgroundColor,
    super.enabled,
  }) : basePath = TomCtr.resolvePath(tomId, scope) {
    tomGroup?.register(this);
  }

  @override
  final String? tomId;

  @override
  final TomUIGroup? tomGroup;

  @override
  final TomScope? scope;

  @override
  final String? basePath;

  @override
  Widget build(BuildContext context) {
    final hidden = checkHidden();
    if (hidden != null) return hidden;

    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');

    return applyReadonly(
      context,
      NavigationDrawerDestination(
        key: key,
        icon: icon,
        selectedIcon: selectedIcon,
        label: label,
        backgroundColor: resolvedBackgroundColor,
        enabled: enabled,
      ),
    );
  }
}

// ============================================================================
// Section II: Extended Navigation Widgets
// ============================================================================

/// Tom wrapper for [CupertinoSliverNavigationBar].
///
/// Cupertino large-title scrollable nav bar. Auth on nav regions.
class TomCupertinoSliverNavigationBar extends TomNavigationBase {
  final Widget? largeTitle;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool automaticallyImplyTitle;
  final String? previousPageTitle;
  final Widget? middle;
  final Widget? trailing;
  final Color? backgroundColor;
  final Brightness? brightness;
  final EdgeInsetsDirectional? padding;
  final Border? border;
  final bool transitionBetweenRoutes;
  final Object heroTag;
  final bool stretch;
  final bool alwaysShowMiddle;

  // Pre-resolved resource values
  late final String? _resolvedPreviousPageTitle;
  late final Color? _resolvedBackgroundColor;

  TomCupertinoSliverNavigationBar({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.largeTitle,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.automaticallyImplyTitle = true,
    this.previousPageTitle,
    this.middle,
    this.trailing,
    this.backgroundColor,
    this.brightness,
    this.padding,
    this.border,
    this.transitionBetweenRoutes = true,
    this.heroTag = _defaultHeroTag,
    this.stretch = false,
    this.alwaysShowMiddle = true,
  }) {
    _resolvedPreviousPageTitle = previousPageTitle ?? resolveResourceOrNull('previousPageTitle');
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
  }

  static const Object _defaultHeroTag = 'TomCupertinoSliverNavigationBar';

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoSliverNavigationBar(
      largeTitle: largeTitle,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      automaticallyImplyTitle: automaticallyImplyTitle,
      previousPageTitle: _resolvedPreviousPageTitle,
      middle: middle,
      trailing: trailing,
      backgroundColor: _resolvedBackgroundColor,
      brightness: brightness,
      padding: padding,
      border: border,
      transitionBetweenRoutes: transitionBetweenRoutes,
      heroTag: heroTag,
      stretch: stretch,
      alwaysShowMiddle: alwaysShowMiddle,
    );
  }
}

/// Tom wrapper for [FlexibleSpaceBar].
///
/// Flexible space content for SliverAppBar. Auth on flex space content.
class TomFlexibleSpaceBar extends TomNavigationBase {
  final Widget? title;
  final Widget? background;
  final bool centerTitle;
  final EdgeInsetsGeometry? titlePadding;
  final CollapseMode collapseMode;
  final List<StretchMode> stretchModes;
  final double expandedTitleScale;

  TomFlexibleSpaceBar({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.title,
    this.background,
    this.centerTitle = true,
    this.titlePadding,
    this.collapseMode = CollapseMode.parallax,
    this.stretchModes = const <StretchMode>[StretchMode.zoomBackground],
    this.expandedTitleScale = 1.5,
  });

  @override
  Widget buildContent(BuildContext context) {
    return FlexibleSpaceBar(
      title: title,
      background: background,
      centerTitle: centerTitle,
      titlePadding: titlePadding,
      collapseMode: collapseMode,
      stretchModes: stretchModes,
      expandedTitleScale: expandedTitleScale,
    );
  }
}

/// Tom wrapper for [DrawerHeader].
///
/// Header area of a Drawer. Auth on header content.
class TomDrawerHeader extends TomNavigationBase {
  final Decoration? decoration;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Duration duration;
  final Curve curve;
  final Widget? child;

  // Pre-resolved resource values
  late final EdgeInsetsGeometry _resolvedPadding;
  late final EdgeInsetsGeometry _resolvedMargin;

  TomDrawerHeader({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.decoration,
    this.padding,
    this.margin,
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.fastOutSlowIn,
    this.child,
  }) {
    _resolvedPadding = padding ?? resolveEdgeInsetsOrNull('padding') ?? const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0);
    _resolvedMargin = margin ?? resolveEdgeInsetsOrNull('margin') ?? const EdgeInsets.only(bottom: 8.0);
  }

  @override
  Widget buildContent(BuildContext context) {
    return DrawerHeader(
      decoration: decoration,
      padding: _resolvedPadding,
      margin: _resolvedMargin,
      duration: duration,
      curve: curve,
      child: child,
    );
  }
}

/// Tom wrapper for [UserAccountsDrawerHeader].
///
/// User account header in Drawer. Auth on user info display.
class TomUserAccountsDrawerHeader extends TomNavigationBase {
  final Decoration? decoration;
  final EdgeInsetsGeometry? margin;
  final Widget? currentAccountPicture;
  final List<Widget>? otherAccountsPictures;
  final Size currentAccountPictureSize;
  final Size otherAccountsPicturesSize;
  final Widget? accountName;
  final Widget? accountEmail;
  final VoidCallback? onDetailsPressed;
  final Color? arrowColor;

  // Pre-resolved resource values
  late final Color _resolvedArrowColor;

  TomUserAccountsDrawerHeader({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.decoration,
    this.margin = const EdgeInsets.only(bottom: 8.0),
    this.currentAccountPicture,
    this.otherAccountsPictures,
    this.currentAccountPictureSize = const Size.square(72.0),
    this.otherAccountsPicturesSize = const Size.square(40.0),
    this.accountName,
    this.accountEmail,
    this.onDetailsPressed,
    this.arrowColor,
  }) {
    _resolvedArrowColor = arrowColor ?? resolveColorOrNull('arrowColor') ?? Colors.white;
  }

  @override
  Widget buildContent(BuildContext context) {
    return UserAccountsDrawerHeader(
      decoration: decoration,
      margin: margin,
      currentAccountPicture: currentAccountPicture,
      otherAccountsPictures: otherAccountsPictures,
      currentAccountPictureSize: currentAccountPictureSize,
      otherAccountsPicturesSize: otherAccountsPicturesSize,
      accountName: accountName,
      accountEmail: accountEmail,
      onDetailsPressed: onDetailsPressed,
      arrowColor: _resolvedArrowColor,
    );
  }
}

/// Tom wrapper for [CupertinoNavigationBarBackButton].
///
/// Back button inside CupertinoNavigationBar. Auth can hide back navigation.
class TomCupertinoNavigationBarBackButton extends TomNavigationBase {
  final Color? color;
  final String? previousPageTitle;
  final VoidCallback? onPressed;

  // Pre-resolved resource values
  late final String? _resolvedTitle;
  late final String? _resolvedPreviousPageTitle;

  TomCupertinoNavigationBarBackButton({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.color,
    this.previousPageTitle,
    this.onPressed,
  }) {
    _resolvedTitle = previousPageTitle ?? resolveResourceOrNull('previousPageTitle');
    _resolvedPreviousPageTitle = previousPageTitle ?? resolveResourceOrNull('previousPageTitle');
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoNavigationBarBackButton(
      color: color,
      previousPageTitle: _resolvedTitle,
      onPressed: onPressed,
    );
  }
}

/// Tom wrapper for [TabPageSelector].
///
/// Dot indicator showing current tab page. Auth can hide page indicator.
class TomTabPageSelector extends TomNavigationBase {
  final TabController? controller;
  final double? indicatorSize;
  final Color? color;
  final Color? selectedColor;
  final BorderStyle? borderStyle;

  // Pre-resolved resource values
  late final double _resolvedIndicatorSize;
  late final Color? _resolvedColor;
  late final Color? _resolvedSelectedColor;

  TomTabPageSelector({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.controller,
    this.indicatorSize,
    this.color,
    this.selectedColor,
    this.borderStyle,
  }) {
    _resolvedIndicatorSize = indicatorSize ?? resolveDoubleOrNull('indicatorSize') ?? 12.0;
    _resolvedColor = color ?? resolveColorOrNull('color');
    _resolvedSelectedColor = selectedColor ?? resolveColorOrNull('selectedColor');
  }

  @override
  Widget buildContent(BuildContext context) {
    return TabPageSelector(
      controller: controller,
      indicatorSize: _resolvedIndicatorSize,
      color: _resolvedColor,
      selectedColor: _resolvedSelectedColor,
      borderStyle: borderStyle,
    );
  }
}
