import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../groups/tom_ui_group.dart';
import '../../groups/tom_widget_mixin.dart';
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

  const TomNavigationRail({
    super.key,
    super.tomId,
    super.tomGroup,
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
  });

  // Phase 3: Resolve TextStyle from resources
  TextStyle? _resolveTextStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath, suffix);
  }

  IconThemeData? _resolveIconThemeData(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveIconThemeData(basePath, suffix);
  }

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedSelectedIndex =
      selectedIndex ?? resolveIntOrNull('selectedIndex');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedIndicatorColor =
        indicatorColor ?? resolveColorOrNull('indicatorColor');
    final resolvedMinWidth =
        minWidth ?? resolveDoubleOrNull('minWidth');
    final resolvedMinExtendedWidth =
        minExtendedWidth ?? resolveDoubleOrNull('minExtendedWidth');
    final resolvedUseIndicator =
      useIndicator ?? resolveBoolOrNull('useIndicator');
    final resolvedGroupAlignment =
        groupAlignment ?? resolveDoubleOrNull('groupAlignment');
    final resolvedExtended =
      resolveBoolOrNull('extended') ?? extended;

    // Phase 3: Resolve TextStyle from resources
    final resolvedSelectedLabelTextStyle =
        selectedLabelTextStyle ?? _resolveTextStyle('selectedLabelTextStyle');
    final resolvedUnselectedLabelTextStyle =
        unselectedLabelTextStyle ?? _resolveTextStyle('unselectedLabelTextStyle');
    final resolvedIndicatorShape =
        indicatorShape ?? _resolveShapeBorder('indicatorShape');

    return NavigationRail(
      selectedIndex: resolvedSelectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
      leading: leading,
      trailing: trailing,
      labelType: labelType,
      backgroundColor: resolvedBackgroundColor,
      elevation: resolvedElevation,
      indicatorColor: resolvedIndicatorColor,
      indicatorShape: resolvedIndicatorShape,
      minWidth: resolvedMinWidth,
      minExtendedWidth: resolvedMinExtendedWidth,
      useIndicator: resolvedUseIndicator,
      groupAlignment: resolvedGroupAlignment,
      selectedLabelTextStyle: resolvedSelectedLabelTextStyle,
      unselectedLabelTextStyle: resolvedUnselectedLabelTextStyle,
      selectedIconTheme: selectedIconTheme ?? _resolveIconThemeData('selectedIconTheme'),
      unselectedIconTheme: unselectedIconTheme ?? _resolveIconThemeData('unselectedIconTheme'),
      extended: resolvedExtended,
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

  const TomNavigationBar({
    super.key,
    super.tomId,
    super.tomGroup,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedSelectedIndex =
      resolveIntOrNull('selectedIndex') ?? selectedIndex;
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedIndicatorColor =
        indicatorColor ?? resolveColorOrNull('indicatorColor');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedSurfaceTintColor =
        surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    final resolvedHeight =
        height ?? resolveDoubleOrNull('height');

    return NavigationBar(
      selectedIndex: resolvedSelectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
      backgroundColor: resolvedBackgroundColor,
      indicatorColor: resolvedIndicatorColor,
      indicatorShape: indicatorShape ?? _resolveShapeBorder('indicatorShape'),
      elevation: resolvedElevation,
      shadowColor: resolvedShadowColor,
      surfaceTintColor: resolvedSurfaceTintColor,
      animationDuration: animationDuration,
      labelBehavior: labelBehavior,
      height: resolvedHeight,
      overlayColor: overlayColor,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath, suffix);
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

  const TomTabBar({
    super.key,
    super.tomId,
    super.tomGroup,
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
  });

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (indicatorWeight ?? 2.0),
      );

  // Phase 3: Resolve TextStyle from resources
  TextStyle? _resolveTextStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
  }

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedIsScrollable =
      resolveBoolOrNull('isScrollable') ?? isScrollable;
    final resolvedPadding =
      padding ?? resolveEdgeInsetsOrNull('padding');
    final resolvedIndicatorColor =
        indicatorColor ?? resolveColorOrNull('indicatorColor');
    final resolvedIndicatorWeight =
        indicatorWeight ?? resolveDoubleOrNull('indicatorWeight');
    final resolvedIndicatorPadding =
      indicatorPadding ?? resolveEdgeInsetsOrNull('indicatorPadding');
    final resolvedDividerColor =
        dividerColor ?? resolveColorOrNull('dividerColor');
    final resolvedDividerHeight =
        dividerHeight ?? resolveDoubleOrNull('dividerHeight');
    final resolvedLabelColor =
        labelColor ?? resolveColorOrNull('labelColor');
    final resolvedUnselectedLabelColor =
        unselectedLabelColor ?? resolveColorOrNull('unselectedLabelColor');
    final resolvedLabelPadding =
      labelPadding ?? resolveEdgeInsetsOrNull('labelPadding');
    final resolvedAutomaticIndicatorColorAdjustment =
      resolveBoolOrNull('automaticIndicatorColorAdjustment') ?? automaticIndicatorColorAdjustment;

    // Phase 3: Resolve TextStyle from resources
    final resolvedLabelStyle =
        labelStyle ?? _resolveTextStyle('labelStyle');
    final resolvedUnselectedLabelStyle =
        unselectedLabelStyle ?? _resolveTextStyle('unselectedLabelStyle');

    // Phase 3: Resolve complex objects from resources
    final resolvedIndicator =
        indicator ?? _resolveDecoration('indicator');
    final resolvedSplashBorderRadius =
        splashBorderRadius ?? _resolveBorderRadius('splashBorderRadius');

    return TabBar(
      tabs: tabs,
      controller: controller,
      isScrollable: resolvedIsScrollable,
      padding: resolvedPadding,
      indicatorColor: resolvedIndicatorColor,
      indicatorWeight: resolvedIndicatorWeight ?? 2.0,
      indicatorPadding: resolvedIndicatorPadding ?? EdgeInsets.zero,
      indicator: resolvedIndicator,
      indicatorSize: indicatorSize,
      dividerColor: resolvedDividerColor,
      dividerHeight: resolvedDividerHeight,
      labelColor: resolvedLabelColor,
      labelStyle: resolvedLabelStyle,
      labelPadding: resolvedLabelPadding,
      unselectedLabelColor: resolvedUnselectedLabelColor,
      unselectedLabelStyle: resolvedUnselectedLabelStyle,
      overlayColor: overlayColor,
      onTap: onTap,
      automaticIndicatorColorAdjustment: resolvedAutomaticIndicatorColorAdjustment,
      physics: physics,
      splashFactory: splashFactory,
      splashBorderRadius: resolvedSplashBorderRadius,
      tabAlignment: tabAlignment,
      textScaler: textScaler,
    );
  }

  Decoration? _resolveDecoration(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveDecoration(basePath, suffix);
  }

  BorderRadius? _resolveBorderRadius(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderRadius(basePath, suffix);
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

  const TomNavigationDrawer({
    super.key,
    super.tomId,
    super.tomGroup,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedSelectedIndex =
      selectedIndex ?? resolveIntOrNull('selectedIndex');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedSurfaceTintColor =
        surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedIndicatorColor =
        indicatorColor ?? resolveColorOrNull('indicatorColor');
    final resolvedTilePadding =
      tilePadding ?? resolveEdgeInsetsOrNull('tilePadding');

    // Phase 3: Resolve complex objects from resources
    final resolvedIndicatorShape =
        indicatorShape ?? _resolveShapeBorder('indicatorShape');

    return NavigationDrawer(
      selectedIndex: resolvedSelectedIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: resolvedBackgroundColor,
      shadowColor: resolvedShadowColor,
      surfaceTintColor: resolvedSurfaceTintColor,
      elevation: resolvedElevation,
      indicatorColor: resolvedIndicatorColor,
      indicatorShape: resolvedIndicatorShape,
      tilePadding: resolvedTilePadding ?? const EdgeInsets.symmetric(horizontal: 12.0),
      children: children,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath, suffix);
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

  const TomDrawer({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    this.backgroundColor,
    this.shadowColor,
    this.surfaceTintColor,
    this.elevation,
    this.shape,
    this.width,
    this.clipBehavior,
    this.semanticLabel,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel =
        semanticLabel ??
            resolveResourceOrNull('semanticLabel') ??
            (tomId != null ? resolveResourceOrFail('label') : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedShadowColor =
        shadowColor ?? resolveColorOrNull('shadowColor');
    final resolvedSurfaceTintColor =
        surfaceTintColor ?? resolveColorOrNull('surfaceTintColor');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedWidth =
        width ?? resolveDoubleOrNull('width');

    return Drawer(
      backgroundColor: resolvedBackgroundColor,
      shadowColor: resolvedShadowColor,
      surfaceTintColor: resolvedSurfaceTintColor,
      elevation: resolvedElevation,
      shape: shape ?? _resolveShapeBorder('shape'),
      width: resolvedWidth,
      clipBehavior: clipBehavior,
      semanticLabel: resolvedLabel,
      child: child,
    );
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath, suffix);
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

  const TomBottomNavigationBar({
    super.key,
    super.tomId,
    super.tomGroup,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedCurrentIndex =
      resolveIntOrNull('currentIndex') ?? currentIndex;
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedIconSize =
        iconSize ?? resolveDoubleOrNull('iconSize') ?? 24.0;
    final resolvedSelectedItemColor =
        selectedItemColor ?? resolveColorOrNull('selectedItemColor');
    final resolvedUnselectedItemColor =
        unselectedItemColor ?? resolveColorOrNull('unselectedItemColor');
    final resolvedSelectedIconTheme =
      selectedIconTheme ?? _resolveIconThemeData('selectedIconTheme');
    final resolvedUnselectedIconTheme =
      unselectedIconTheme ?? _resolveIconThemeData('unselectedIconTheme');

    // Phase 3: Resolve TextStyle from resources
    final resolvedSelectedLabelStyle =
        selectedLabelStyle ?? _resolveTextStyle('selectedLabelStyle');
    final resolvedUnselectedLabelStyle =
        unselectedLabelStyle ?? _resolveTextStyle('unselectedLabelStyle');

    return BottomNavigationBar(
      items: items,
      currentIndex: resolvedCurrentIndex,
      onTap: onTap,
      elevation: resolvedElevation,
      type: type,
      fixedColor: fixedColor,
      backgroundColor: resolvedBackgroundColor,
      iconSize: resolvedIconSize,
      selectedItemColor: resolvedSelectedItemColor,
      unselectedItemColor: resolvedUnselectedItemColor,
      selectedIconTheme: resolvedSelectedIconTheme,
      unselectedIconTheme: resolvedUnselectedIconTheme,
      selectedLabelStyle: resolvedSelectedLabelStyle,
      unselectedLabelStyle: resolvedUnselectedLabelStyle,
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
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
  }

  IconThemeData? _resolveIconThemeData(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveIconThemeData(basePath, suffix);
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

  const TomStepper({
    super.key,
    super.tomId,
    super.tomGroup,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedPhysics =
      physics ?? _resolveScrollPhysics('physics');
    final resolvedElevation =
        elevation ?? resolveDoubleOrNull('elevation');
    final resolvedConnectorThickness =
        connectorThickness ?? resolveDoubleOrNull('connectorThickness');
    final resolvedConnectorColor =
        connectorColor ?? resolveColorOrNull('connectorColor');

    return Stepper(
      steps: steps,
      currentStep: currentStep,
      type: type,
      physics: resolvedPhysics,
      onStepContinue: onStepContinue,
      onStepCancel: onStepCancel,
      controlsBuilder: controlsBuilder,
      elevation: resolvedElevation,
      margin: margin,
      connectorThickness: resolvedConnectorThickness,
      connectorColor: resolvedConnectorColor != null ? WidgetStatePropertyAll<Color>(resolvedConnectorColor) : null,
    );
  }

  ScrollPhysics? _resolveScrollPhysics(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveScrollPhysics(basePath, suffix);
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

  const TomTabBarView({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.children,
    this.controller,
    this.physics,
    this.dragStartBehavior = DragStartBehavior.start,
    this.viewportFraction,
    this.clipBehavior = Clip.hardEdge,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedViewportFraction =
        viewportFraction ?? resolveDoubleOrNull('viewportFraction') ?? 1.0;

    return TabBarView(
      controller: controller,
      physics: physics,
      dragStartBehavior: dragStartBehavior,
      viewportFraction: resolvedViewportFraction,
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

  const TomPageView({
    super.key,
    super.tomId,
    super.tomGroup,
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

  const TomCupertinoTabBar({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.items,
    this.onTap,
    this.currentIndex = 0,
    this.backgroundColor,
    this.activeColor,
    this.inactiveColor = CupertinoColors.inactiveGray,
    this.iconSize,
    this.height,
    this.border,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedActiveColor =
        activeColor ?? resolveColorOrNull('activeColor');
    final resolvedIconSize =
        iconSize ?? resolveDoubleOrNull('iconSize') ?? 30.0;
    final resolvedHeight =
        height ?? resolveDoubleOrNull('height') ?? 50.0;

    return CupertinoTabBar(
      items: items,
      onTap: onTap,
      currentIndex: currentIndex,
      backgroundColor: resolvedBackgroundColor,
      activeColor: resolvedActiveColor,
      inactiveColor: inactiveColor,
      iconSize: resolvedIconSize,
      height: resolvedHeight,
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

  const TomCupertinoNavigationBar({
    super.key,
    super.tomId,
    super.tomGroup,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedPreviousPageTitle =
        previousPageTitle ?? resolveResourceOrNull('previousPageTitle');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');

    // When transitionBetweenRoutes is true, Flutter asserts heroTag must be
    // identical to its internal _defaultHeroTag. We can't access that constant,
    // so we omit heroTag entirely (letting Flutter use its default).
    // When transitions are disabled, we can safely pass a custom heroTag.
    if (!transitionBetweenRoutes && heroTag != null) {
      return CupertinoNavigationBar(
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        automaticallyImplyMiddle: automaticallyImplyMiddle,
        previousPageTitle: resolvedPreviousPageTitle,
        middle: middle,
        trailing: trailing,
        backgroundColor: resolvedBackgroundColor,
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
      previousPageTitle: resolvedPreviousPageTitle,
      middle: middle,
      trailing: trailing,
      backgroundColor: resolvedBackgroundColor,
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

  const TomBreadcrumb({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.items,
    this.separator = const Text(' / '),
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.padding,
  });

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

    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding');

    if (resolvedPadding != null) {
      return Padding(padding: resolvedPadding, child: row);
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
  const TomTab({
    this.tomId,
    this.tomGroup,
    super.key,
    super.text,
    super.icon,
    super.iconMargin,
    super.height,
    super.child,
  });

  @override
  final String? tomId;

  @override
  final TomUIGroup? tomGroup;

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
  const TomNavigationDestination({
    this.tomId,
    this.tomGroup,
    super.key,
    required super.icon,
    super.selectedIcon,
    required super.label,
    super.tooltip,
    super.enabled,
  });

  @override
  final String? tomId;

  @override
  final TomUIGroup? tomGroup;

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
  const TomNavigationDrawerDestination({
    this.tomId,
    this.tomGroup,
    super.key,
    required super.icon,
    super.selectedIcon,
    required super.label,
    super.backgroundColor,
    super.enabled,
  });

  @override
  final String? tomId;

  @override
  final TomUIGroup? tomGroup;

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

  const TomCupertinoSliverNavigationBar({
    super.key,
    super.tomId,
    super.tomGroup,
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
  });

  static const Object _defaultHeroTag = 'TomCupertinoSliverNavigationBar';

  @override
  Widget buildContent(BuildContext context) {
    final resolvedPreviousPageTitle =
        previousPageTitle ?? resolveResourceOrNull('previousPageTitle');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');

    return CupertinoSliverNavigationBar(
      largeTitle: largeTitle,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      automaticallyImplyTitle: automaticallyImplyTitle,
      previousPageTitle: resolvedPreviousPageTitle,
      middle: middle,
      trailing: trailing,
      backgroundColor: resolvedBackgroundColor,
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

  const TomFlexibleSpaceBar({
    super.key,
    super.tomId,
    super.tomGroup,
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

  const TomDrawerHeader({
    super.key,
    super.tomId,
    super.tomGroup,
    this.decoration,
    this.padding,
    this.margin,
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.fastOutSlowIn,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding') ??
            const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0);
    final resolvedMargin =
        margin ?? resolveEdgeInsetsOrNull('margin') ??
            const EdgeInsets.only(bottom: 8.0);

    return DrawerHeader(
      decoration: decoration,
      padding: resolvedPadding,
      margin: resolvedMargin,
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

  const TomUserAccountsDrawerHeader({
    super.key,
    super.tomId,
    super.tomGroup,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedArrowColor =
        arrowColor ?? resolveColorOrNull('arrowColor') ?? Colors.white;

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
      arrowColor: resolvedArrowColor,
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

  const TomCupertinoNavigationBarBackButton({
    super.key,
    super.tomId,
    super.tomGroup,
    this.color,
    this.previousPageTitle,
    this.onPressed,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedTitle =
        previousPageTitle ?? resolveResourceOrNull('previousPageTitle');

    return CupertinoNavigationBarBackButton(
      color: color,
      previousPageTitle: resolvedTitle,
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

  const TomTabPageSelector({
    super.key,
    super.tomId,
    super.tomGroup,
    this.controller,
    this.indicatorSize,
    this.color,
    this.selectedColor,
    this.borderStyle,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedIndicatorSize =
        indicatorSize ?? resolveDoubleOrNull('indicatorSize') ?? 12.0;
    final resolvedColor = color ?? resolveColorOrNull('color');
    final resolvedSelectedColor =
        selectedColor ?? resolveColorOrNull('selectedColor');

    return TabPageSelector(
      controller: controller,
      indicatorSize: resolvedIndicatorSize,
      color: resolvedColor,
      selectedColor: resolvedSelectedColor,
      borderStyle: borderStyle,
    );
  }
}
