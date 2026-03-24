import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';import 'package:flutter/cupertino.dart';import 'package:flutter/rendering.dart';

import '../../widget_base/tom_family_base.dart';

/// Tom wrapper for [ListView].
///
/// Adds ID, group, authorization, and resource resolution to the standard
/// Flutter [ListView]. Uses the `custom` constructor to accept a delegate.
class TomListView extends TomListBase {
  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;
  final double? itemExtent;
  final Widget? prototypeItem;
  final SliverChildDelegate childrenDelegate;
  final double? cacheExtent;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;

  const TomListView({
    super.key,
    super.tomId,
    super.tomGroup,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.itemExtent,
    this.prototypeItem,
    required this.childrenDelegate,
    this.cacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
  });

  @override
  Widget buildContent(BuildContext context) {
    return ListView.custom(
      scrollDirection: scrollDirection,
      reverse: reverse,
      controller: controller,
      primary: primary,
      physics: physics,
      shrinkWrap: shrinkWrap,
      padding: padding,
      itemExtent: itemExtent,
      prototypeItem: prototypeItem,
      childrenDelegate: childrenDelegate,
      cacheExtent: cacheExtent,
      semanticChildCount: semanticChildCount,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: restorationId,
      clipBehavior: clipBehavior,
    );
  }
}

/// Tom wrapper for [AnimatedList].
///
/// Adds ID, group, authorization, and resource resolution.
class TomAnimatedList extends TomListBase {
  final AnimatedItemBuilder itemBuilder;
  final int initialItemCount;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;

  const TomAnimatedList({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.itemBuilder,
    this.initialItemCount = 0,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.clipBehavior = Clip.hardEdge,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedList(
      itemBuilder: itemBuilder,
      initialItemCount: initialItemCount,
      scrollDirection: scrollDirection,
      reverse: reverse,
      controller: controller,
      primary: primary,
      physics: physics,
      shrinkWrap: shrinkWrap,
      padding: padding,
      clipBehavior: clipBehavior,
    );
  }
}

/// Tom wrapper for [Dismissible].
///
/// Adds ID, group, authorization, and resource resolution.
class TomDismissible extends TomListBase {
  final Widget child;
  final Widget? background;
  final Widget? secondaryBackground;
  final ConfirmDismissCallback? confirmDismiss;
  final VoidCallback? onResize;
  final DismissUpdateCallback? onUpdate;
  final DismissDirectionCallback? onDismissed;
  final DismissDirection direction;
  final Duration? resizeDuration;
  final Map<DismissDirection, double> dismissThresholds;
  final Duration movementDuration;
  final double crossAxisEndOffset;
  final DragStartBehavior dragStartBehavior;
  final HitTestBehavior behavior;

  const TomDismissible({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.child,
    this.background,
    this.secondaryBackground,
    this.confirmDismiss,
    this.onResize,
    this.onUpdate,
    this.onDismissed,
    this.direction = DismissDirection.horizontal,
    this.resizeDuration = const Duration(milliseconds: 300),
    this.dismissThresholds = const {},
    this.movementDuration = const Duration(milliseconds: 200),
    this.crossAxisEndOffset = 0.0,
    this.dragStartBehavior = DragStartBehavior.start,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Dismissible(
      key: key ?? ValueKey(tomId),
      background: background,
      secondaryBackground: secondaryBackground,
      confirmDismiss: confirmDismiss,
      onResize: onResize,
      onUpdate: onUpdate,
      onDismissed: onDismissed,
      direction: direction,
      resizeDuration: resizeDuration,
      dismissThresholds: dismissThresholds,
      movementDuration: movementDuration,
      crossAxisEndOffset: crossAxisEndOffset,
      dragStartBehavior: dragStartBehavior,
      behavior: behavior,
      child: child,
    );
  }
}

/// Tom wrapper for [ListWheelScrollView].
///
/// Adds ID, group, authorization, and resource resolution.
class TomListWheelScrollView extends TomListBase {
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final double diameterRatio;
  final double perspective;
  final double offAxisFraction;
  final bool useMagnifier;
  final double magnification;
  final double overAndUnderCenterOpacity;
  final double itemExtent;
  final double squeeze;
  final ValueChanged<int>? onSelectedItemChanged;
  final bool renderChildrenOutsideViewport;
  final Clip clipBehavior;
  final String? restorationId;
  final ScrollBehavior? scrollBehavior;
  final ListWheelChildDelegate childDelegate;

  const TomListWheelScrollView({
    super.key,
    super.tomId,
    super.tomGroup,
    this.controller,
    this.physics,
    this.diameterRatio = RenderListWheelViewport.defaultDiameterRatio,
    this.perspective = RenderListWheelViewport.defaultPerspective,
    this.offAxisFraction = 0.0,
    this.useMagnifier = false,
    this.magnification = 1.0,
    this.overAndUnderCenterOpacity = 1.0,
    required this.itemExtent,
    this.squeeze = 1.0,
    this.onSelectedItemChanged,
    this.renderChildrenOutsideViewport = false,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.scrollBehavior,
    required this.childDelegate,
  });

  @override
  Widget buildContent(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      physics: physics,
      diameterRatio: diameterRatio,
      perspective: perspective,
      offAxisFraction: offAxisFraction,
      useMagnifier: useMagnifier,
      magnification: magnification,
      overAndUnderCenterOpacity: overAndUnderCenterOpacity,
      itemExtent: itemExtent,
      squeeze: squeeze,
      onSelectedItemChanged: onSelectedItemChanged,
      renderChildrenOutsideViewport: renderChildrenOutsideViewport,
      clipBehavior: clipBehavior,
      restorationId: restorationId,
      scrollBehavior: scrollBehavior,
      childDelegate: childDelegate,
    );
  }
}

/// Tom wrapper for [CupertinoListTile].
///
/// iOS-style list tile. Adds ID, group, authorization,
/// and resource resolution.
class TomCupertinoListTile extends TomListBase {
  final Widget title;
  final Widget? subtitle;
  final Widget? additionalInfo;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final double? leadingSize;
  final double? leadingToTitle;

  const TomCupertinoListTile({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.title,
    this.subtitle,
    this.additionalInfo,
    this.leading,
    this.trailing,
    this.onTap,
    this.backgroundColor,
    this.padding,
    this.leadingSize,
    this.leadingToTitle,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoListTile(
      title: title,
      subtitle: subtitle,
      additionalInfo: additionalInfo,
      leading: leading,
      trailing: trailing,
      onTap: onTap,
      backgroundColor: backgroundColor,
      padding: padding,
      leadingSize: leadingSize ?? 28.0,
      leadingToTitle: leadingToTitle ?? 12.0,
    );
  }
}

// =============================================================================
// Section II: Additional List Widgets
// =============================================================================

/// Tom wrapper for [CupertinoListSection].
///
/// Cupertino grouped list section. Auth on section visibility; resources for header/footer.
class TomCupertinoListSection extends TomListBase {
  final List<Widget> children;
  final Widget? header;
  final Widget? footer;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final CupertinoListSectionType type;
  final Clip clipBehavior;
  final double? topMargin;
  final bool hasLeading;
  final Color? dividerMargin;
  final double additionalDividerMargin;
  final Widget? decoration;
  final Widget? separatorColor;

  const TomCupertinoListSection({
    super.key,
    super.tomId,
    super.tomGroup,
    this.children = const <Widget>[],
    this.header,
    this.footer,
    this.margin,
    this.backgroundColor,
    this.type = CupertinoListSectionType.base,
    this.clipBehavior = Clip.hardEdge,
    this.topMargin,
    this.hasLeading = true,
    this.dividerMargin,
    this.additionalDividerMargin = 0.0,
    this.decoration,
    this.separatorColor,
  });

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoListSection(
      header: header,
      footer: footer,
      backgroundColor: backgroundColor ?? CupertinoColors.systemBackground,
      clipBehavior: clipBehavior,
      topMargin: topMargin,
      hasLeading: hasLeading,
      additionalDividerMargin: additionalDividerMargin,
      margin: margin ?? const EdgeInsets.only(bottom: 8.0),
      children: children,
    );
  }
}

/// Tom wrapper for [ReorderableList].
///
/// Reorderable list implementation. Auth on list content and reorder capability.
class TomReorderableList extends TomListBase {
  final SliverChildDelegate childrenDelegate;
  final ReorderCallback onReorder;
  final void Function(int)? onReorderStart;
  final void Function(int)? onReorderEnd;
  final double? itemExtent;
  final ItemExtentBuilder? itemExtentBuilder;
  final Widget? prototypeItem;
  final ReorderItemProxyDecorator? proxyDecorator;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;
  final double anchor;
  final double? cacheExtent;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;

  const TomReorderableList({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.childrenDelegate,
    required this.onReorder,
    this.onReorderStart,
    this.onReorderEnd,
    this.itemExtent,
    this.itemExtentBuilder,
    this.prototypeItem,
    this.proxyDecorator,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.clipBehavior = Clip.hardEdge,
    this.anchor = 0.0,
    this.cacheExtent,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
  });

  @override
  Widget buildContent(BuildContext context) {
    return ReorderableList(
      itemBuilder: (context, index) {
        return (childrenDelegate as SliverChildBuilderDelegate).builder(context, index)!;
      },
      itemCount: (childrenDelegate as SliverChildBuilderDelegate).childCount ?? 0,
      onReorder: onReorder,
      onReorderStart: onReorderStart,
      onReorderEnd: onReorderEnd,
      itemExtent: itemExtent,
      itemExtentBuilder: itemExtentBuilder,
      prototypeItem: prototypeItem,
      proxyDecorator: proxyDecorator,
      scrollDirection: scrollDirection,
      reverse: reverse,
      controller: controller,
      primary: primary,
      physics: physics,
      shrinkWrap: shrinkWrap,
      padding: padding,
      clipBehavior: clipBehavior,
      anchor: anchor,
      cacheExtent: cacheExtent,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: restorationId,
    );
  }
}

/// Tom wrapper for [SliverReorderableList].
///
/// Sliver variant of ReorderableList. Auth on list content and reorder capability.
class TomSliverReorderableList extends TomListBase {
  final Widget Function(BuildContext, int) itemBuilder;
  final int itemCount;
  final ReorderCallback onReorder;
  final void Function(int)? onReorderStart;
  final void Function(int)? onReorderEnd;
  final double? itemExtent;
  final ItemExtentBuilder? itemExtentBuilder;
  final Widget? prototypeItem;
  final ReorderItemProxyDecorator? proxyDecorator;

  const TomSliverReorderableList({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.itemBuilder,
    required this.itemCount,
    required this.onReorder,
    this.onReorderStart,
    this.onReorderEnd,
    this.itemExtent,
    this.itemExtentBuilder,
    this.prototypeItem,
    this.proxyDecorator,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SliverReorderableList(
      itemBuilder: itemBuilder,
      itemCount: itemCount,
      onReorder: onReorder,
      onReorderStart: onReorderStart,
      onReorderEnd: onReorderEnd,
      itemExtent: itemExtent,
      itemExtentBuilder: itemExtentBuilder,
      prototypeItem: prototypeItem,
      proxyDecorator: proxyDecorator,
    );
  }
}
