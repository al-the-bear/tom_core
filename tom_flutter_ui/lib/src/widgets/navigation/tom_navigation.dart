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
    super.tomStyleVariant,
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
    super.tomStyleVariant,
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
    super.tomStyleVariant,
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
