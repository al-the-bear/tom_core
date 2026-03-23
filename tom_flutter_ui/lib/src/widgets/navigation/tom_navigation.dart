import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../widget_base/tom_family_base.dart';

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

  @override
  Widget buildContent(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
      leading: leading,
      trailing: trailing,
      labelType: labelType,
      backgroundColor: backgroundColor,
      elevation: elevation,
      indicatorColor: indicatorColor,
      indicatorShape: indicatorShape,
      minWidth: minWidth,
      minExtendedWidth: minExtendedWidth,
      useIndicator: useIndicator,
      groupAlignment: groupAlignment,
      selectedLabelTextStyle: selectedLabelTextStyle,
      unselectedLabelTextStyle: unselectedLabelTextStyle,
      selectedIconTheme: selectedIconTheme,
      unselectedIconTheme: unselectedIconTheme,
      extended: extended,
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
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
      backgroundColor: backgroundColor,
      indicatorColor: indicatorColor,
      indicatorShape: indicatorShape,
      elevation: elevation,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      animationDuration: animationDuration,
      labelBehavior: labelBehavior,
      height: height,
      overlayColor: overlayColor,
    );
  }
}

/// Tom wrapper for [TabBar].
///
/// Adds ID, group, and authorization.
class TomTabBar extends TomNavigationBase {
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
  Widget buildContent(BuildContext context) {
    return TabBar(
      tabs: tabs,
      controller: controller,
      isScrollable: isScrollable,
      padding: padding,
      indicatorColor: indicatorColor,
      indicatorPadding: indicatorPadding ?? EdgeInsets.zero,
      indicator: indicator,
      indicatorSize: indicatorSize,
      dividerColor: dividerColor,
      dividerHeight: dividerHeight,
      labelColor: labelColor,
      labelStyle: labelStyle,
      labelPadding: labelPadding,
      unselectedLabelColor: unselectedLabelColor,
      unselectedLabelStyle: unselectedLabelStyle,
      overlayColor: overlayColor,
      onTap: onTap,
      automaticIndicatorColorAdjustment: automaticIndicatorColorAdjustment,
      physics: physics,
      splashFactory: splashFactory,
      splashBorderRadius: splashBorderRadius,
      tabAlignment: tabAlignment,
      textScaler: textScaler,
    );
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
    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: backgroundColor,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      elevation: elevation,
      indicatorColor: indicatorColor,
      indicatorShape: indicatorShape,
      tilePadding: tilePadding ?? const EdgeInsets.symmetric(horizontal: 12.0),
      children: children,
    );
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
        semanticLabel ?? (tomId != null ? resolveResource(context, 'label') : null);

    return Drawer(
      backgroundColor: backgroundColor,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      elevation: elevation,
      shape: shape,
      width: width,
      clipBehavior: clipBehavior,
      semanticLabel: resolvedLabel,
      child: child,
    );
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
  final double iconSize;
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
    this.iconSize = 24.0,
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
    return BottomNavigationBar(
      items: items,
      currentIndex: currentIndex,
      onTap: onTap,
      elevation: elevation,
      type: type,
      fixedColor: fixedColor,
      backgroundColor: backgroundColor,
      iconSize: iconSize,
      selectedItemColor: selectedItemColor,
      unselectedItemColor: unselectedItemColor,
      selectedIconTheme: selectedIconTheme,
      unselectedIconTheme: unselectedIconTheme,
      selectedLabelStyle: selectedLabelStyle,
      unselectedLabelStyle: unselectedLabelStyle,
      selectedFontSize: selectedFontSize ?? 14.0,
      unselectedFontSize: unselectedFontSize ?? 12.0,
      showSelectedLabels: showSelectedLabels,
      showUnselectedLabels: showUnselectedLabels,
      enableFeedback: enableFeedback,
      landscapeLayout: landscapeLayout,
      mouseCursor: mouseCursor,
    );
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
    return Stepper(
      steps: steps,
      currentStep: currentStep,
      type: type,
      physics: physics,
      onStepContinue: onStepContinue,
      onStepCancel: onStepCancel,
      controlsBuilder: controlsBuilder,
      elevation: elevation,
      margin: margin,
      connectorThickness: connectorThickness,
      connectorColor: connectorColor != null ? WidgetStatePropertyAll<Color>(connectorColor!) : null,
    );
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
  final double viewportFraction;
  final Clip clipBehavior;

  const TomTabBarView({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.children,
    this.controller,
    this.physics,
    this.dragStartBehavior = DragStartBehavior.start,
    this.viewportFraction = 1.0,
    this.clipBehavior = Clip.hardEdge,
  });

  @override
  Widget buildContent(BuildContext context) {
    return TabBarView(
      controller: controller,
      physics: physics,
      dragStartBehavior: dragStartBehavior,
      viewportFraction: viewportFraction,
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
  final double iconSize;
  final double height;
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
    this.iconSize = 30.0,
    this.height = 50.0,
    this.border,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoTabBar(
      items: items,
      onTap: onTap,
      currentIndex: currentIndex,
      backgroundColor: backgroundColor,
      activeColor: activeColor,
      inactiveColor: inactiveColor,
      iconSize: iconSize,
      height: height,
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
    return CupertinoNavigationBar(
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      automaticallyImplyMiddle: automaticallyImplyMiddle,
      previousPageTitle: previousPageTitle,
      middle: middle,
      trailing: trailing,
      backgroundColor: backgroundColor,
      brightness: brightness,
      padding: padding,
      border: border,
      transitionBetweenRoutes: transitionBetweenRoutes,
      heroTag: heroTag ?? _defaultHeroTag,
    );
  }
}

const _defaultHeroTag = 'tom_cupertino_nav_bar';

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

    if (padding != null) {
      return Padding(padding: padding!, child: row);
    }
    return row;
  }
}
