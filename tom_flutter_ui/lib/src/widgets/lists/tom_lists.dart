import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_style_resolvers.dart';

/// Tom wrapper for [ListView].
///
/// Adds ID, group, authorization, and resource resolution to the standard
/// Flutter [ListView]. Supports both simple children lists and builder patterns.
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
  final SliverChildDelegate? _childrenDelegate;
  final List<Widget>? _children;
  final double? cacheExtent;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;

  /// Creates a scrollable, linear array of widgets from an explicit [List].
  ///
  /// This constructor is appropriate for list views with a small number of
  /// children because constructing the [List] requires doing work for every
  /// child that could possibly be displayed in the list view instead of just
  /// those children that are actually visible.
  // Pre-resolved resource values
  late final bool _resolvedReverse;
  late final bool? _resolvedPrimary;
  late final bool _resolvedShrinkWrap;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final double? _resolvedItemExtent;
  late final ScrollCacheExtent? _resolvedCacheExtent;
  late final int? _resolvedSemanticChildCount;
  late final String? _resolvedRestorationId;
  late final bool _resolvedAddAutomaticKeepAlives;
  late final bool _resolvedAddRepaintBoundaries;
  late final bool _resolvedAddSemanticIndexes;
  late final ScrollPhysics? _resolvedPhysics;

  TomListView({
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
    this.shrinkWrap = false,
    this.padding,
    this.itemExtent,
    this.prototypeItem,
    List<Widget> children = const <Widget>[],
    this.cacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
  })  : _children = children,
        _childrenDelegate = null {
    _initResolvedFields();
  }

  /// Creates a scrollable, linear array of widgets that are created on demand.
  ///
  /// This constructor is appropriate for list views with a large (or infinite)
  /// number of children because the builder is called only for those children
  /// that are actually visible.
  TomListView.builder({
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
    this.shrinkWrap = false,
    this.padding,
    this.itemExtent,
    this.prototypeItem,
    required NullableIndexedWidgetBuilder itemBuilder,
    int? itemCount,
    this.cacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
  })  : _children = null,
        _childrenDelegate = SliverChildBuilderDelegate(
          InScopeBuilder(scope: scope).wrap2(itemBuilder),
          childCount: itemCount,
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
          addSemanticIndexes: addSemanticIndexes,
        ) {
    _initResolvedFields();
  }

  /// Creates a fixed-length scrollable linear array of list "items" separated
  /// by list item "separators".
  TomListView.separated({
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
    this.shrinkWrap = false,
    this.padding,
    required NullableIndexedWidgetBuilder itemBuilder,
    required IndexedWidgetBuilder separatorBuilder,
    required int itemCount,
    this.cacheExtent,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
  })  : itemExtent = null,
        prototypeItem = null,
        semanticChildCount = itemCount,
        _children = null,
        _childrenDelegate = SliverChildBuilderDelegate(
          InScopeBuilder(scope: scope).wrap2((BuildContext context, int index) {
            final int itemIndex = index ~/ 2;
            if (index.isEven) {
              return itemBuilder(context, itemIndex);
            }
            return separatorBuilder(context, itemIndex);
          }),
          childCount: _computeActualChildCount(itemCount),
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
          addSemanticIndexes: addSemanticIndexes,
        ) {
    _initResolvedFields();
  }

  /// Creates a scrollable, linear array of widgets with a custom child model.
  TomListView.custom({
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
    this.shrinkWrap = false,
    this.padding,
    this.itemExtent,
    this.prototypeItem,
    required SliverChildDelegate childrenDelegate,
    this.cacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
  })  : _children = null,
        _childrenDelegate = childrenDelegate {
    _initResolvedFields();
  }

  void _initResolvedFields() {
    _resolvedReverse = TomCtr.boolVal(basePath, 'reverse') ?? reverse;
    _resolvedPrimary = primary ?? TomCtr.boolVal(basePath, 'primary');
    _resolvedShrinkWrap = TomCtr.boolVal(basePath, 'shrinkWrap') ?? shrinkWrap;
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
    _resolvedItemExtent = itemExtent ?? TomCtr.doubleVal(basePath, 'itemExtent');
    final cacheExtentPixels = cacheExtent ?? TomCtr.doubleVal(basePath, 'cacheExtent');
    _resolvedCacheExtent = cacheExtentPixels == null ? null : ScrollCacheExtent.pixels(cacheExtentPixels);
    _resolvedSemanticChildCount = semanticChildCount ?? TomCtr.intVal(basePath, 'semanticChildCount');
    _resolvedRestorationId = restorationId ?? TomCtr.textOrNull(basePath, 'restorationId');
    _resolvedAddAutomaticKeepAlives = TomCtr.boolVal(basePath, 'addAutomaticKeepAlives') ?? addAutomaticKeepAlives;
    _resolvedAddRepaintBoundaries = TomCtr.boolVal(basePath, 'addRepaintBoundaries') ?? addRepaintBoundaries;
    _resolvedAddSemanticIndexes = TomCtr.boolVal(basePath, 'addSemanticIndexes') ?? addSemanticIndexes;
    _resolvedPhysics = physics ?? _resolveScrollPhysics('physics');
  }

  static int _computeActualChildCount(int itemCount) {
    return itemCount > 0 ? itemCount * 2 - 1 : 0;
  }

  @override
  Widget buildContent(BuildContext context) {
    // If children list provided, use default ListView constructor
    if (_children != null) {
      return ListView(
        scrollDirection: scrollDirection,
        reverse: _resolvedReverse,
        controller: controller,
        primary: _resolvedPrimary,
        physics: _resolvedPhysics,
        shrinkWrap: _resolvedShrinkWrap,
        padding: _resolvedPadding,
        itemExtent: _resolvedItemExtent,
        prototypeItem: prototypeItem,
        scrollCacheExtent: _resolvedCacheExtent,
        semanticChildCount: _resolvedSemanticChildCount,
        dragStartBehavior: dragStartBehavior,
        keyboardDismissBehavior: keyboardDismissBehavior,
        restorationId: _resolvedRestorationId,
        clipBehavior: clipBehavior,
        addAutomaticKeepAlives: _resolvedAddAutomaticKeepAlives,
        addRepaintBoundaries: _resolvedAddRepaintBoundaries,
        addSemanticIndexes: _resolvedAddSemanticIndexes,
        children: _children,
      );
    }
    // Otherwise use custom with delegate
    return ListView.custom(
      scrollDirection: scrollDirection,
      reverse: _resolvedReverse,
      controller: controller,
      primary: _resolvedPrimary,
      physics: _resolvedPhysics,
      shrinkWrap: _resolvedShrinkWrap,
      padding: _resolvedPadding,
      itemExtent: _resolvedItemExtent,
      prototypeItem: prototypeItem,
      childrenDelegate: _childrenDelegate!,
      scrollCacheExtent: _resolvedCacheExtent,
      semanticChildCount: _resolvedSemanticChildCount,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: _resolvedRestorationId,
      clipBehavior: clipBehavior,
    );
  }

  ScrollPhysics? _resolveScrollPhysics(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveScrollPhysics(basePath!, suffix);
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

  // Pre-resolved resource values
  late final int _resolvedInitialItemCount;
  late final bool _resolvedReverse;
  late final bool? _resolvedPrimary;
  late final bool _resolvedShrinkWrap;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final ScrollPhysics? _resolvedPhysics;

  TomAnimatedList({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required AnimatedItemBuilder itemBuilder,
    this.initialItemCount = 0,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.clipBehavior = Clip.hardEdge,
  }) : itemBuilder = InScopeBuilder(scope: scope).wrap3(itemBuilder) {
    _resolvedInitialItemCount = TomCtr.intVal(basePath, 'initialItemCount') ?? initialItemCount;
    _resolvedReverse = TomCtr.boolVal(basePath, 'reverse') ?? reverse;
    _resolvedPrimary = primary ?? TomCtr.boolVal(basePath, 'primary');
    _resolvedShrinkWrap = TomCtr.boolVal(basePath, 'shrinkWrap') ?? shrinkWrap;
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
    _resolvedPhysics = physics ?? _resolveScrollPhysics('physics');
  }

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedList(
      itemBuilder: itemBuilder,
      initialItemCount: _resolvedInitialItemCount,
      scrollDirection: scrollDirection,
      reverse: _resolvedReverse,
      controller: controller,
      primary: _resolvedPrimary,
      physics: _resolvedPhysics,
      shrinkWrap: _resolvedShrinkWrap,
      padding: _resolvedPadding,
      clipBehavior: clipBehavior,
    );
  }

  ScrollPhysics? _resolveScrollPhysics(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveScrollPhysics(basePath!, suffix);
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
  final double? crossAxisEndOffset;
  final DragStartBehavior dragStartBehavior;
  final HitTestBehavior behavior;

  // Pre-resolved resource values
  late final double _resolvedCrossAxisEndOffset;

  TomDismissible({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.child,
    this.background,
    this.secondaryBackground,
    ConfirmDismissCallback? confirmDismiss,
    VoidCallback? onResize,
    DismissUpdateCallback? onUpdate,
    DismissDirectionCallback? onDismissed,
    this.direction = DismissDirection.horizontal,
    this.resizeDuration = const Duration(milliseconds: 300),
    this.dismissThresholds = const {},
    this.movementDuration = const Duration(milliseconds: 200),
    this.crossAxisEndOffset,
    this.dragStartBehavior = DragStartBehavior.start,
    this.behavior = HitTestBehavior.opaque,
  })  : confirmDismiss = InScopeBuilder(scope: scope).wrap1n(confirmDismiss),
        onResize = InScopeBuilder(scope: scope).wrap0n(onResize),
        onUpdate = InScopeBuilder(scope: scope).wrap1n(onUpdate),
        onDismissed = InScopeBuilder(scope: scope).wrap1n(onDismissed) {
    _resolvedCrossAxisEndOffset = crossAxisEndOffset ?? TomCtr.doubleVal(basePath, 'crossAxisEndOffset') ?? 0.0;
  }

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
      crossAxisEndOffset: _resolvedCrossAxisEndOffset,
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
  final double? diameterRatio;
  final double? perspective;
  final double? offAxisFraction;
  final bool useMagnifier;
  final double? magnification;
  final double? overAndUnderCenterOpacity;
  final double? itemExtent;
  final double? squeeze;
  final ValueChanged<int>? onSelectedItemChanged;
  final bool renderChildrenOutsideViewport;
  final Clip clipBehavior;
  final String? restorationId;
  final ScrollBehavior? scrollBehavior;
  final ListWheelChildDelegate childDelegate;

  // Pre-resolved resource values
  late final double _resolvedDiameterRatio;
  late final double _resolvedPerspective;
  late final double _resolvedOffAxisFraction;
  late final double _resolvedMagnification;
  late final double _resolvedOverAndUnderCenterOpacity;
  late final double _resolvedItemExtent;
  late final double _resolvedSqueeze;
  late final bool _resolvedUseMagnifier;
  late final bool _resolvedRenderChildrenOutsideViewport;
  late final String? _resolvedRestorationId;

  TomListWheelScrollView({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.controller,
    this.physics,
    this.diameterRatio,
    this.perspective,
    this.offAxisFraction,
    this.useMagnifier = false,
    this.magnification,
    this.overAndUnderCenterOpacity,
    this.itemExtent,
    this.squeeze,
    ValueChanged<int>? onSelectedItemChanged,
    this.renderChildrenOutsideViewport = false,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.scrollBehavior,
    required this.childDelegate,
  })  : onSelectedItemChanged = InScopeBuilder(scope: scope).wrap1n(onSelectedItemChanged) {
    _resolvedDiameterRatio = diameterRatio ?? TomCtr.doubleVal(basePath, 'diameterRatio') ?? RenderListWheelViewport.defaultDiameterRatio;
    _resolvedPerspective = perspective ?? TomCtr.doubleVal(basePath, 'perspective') ?? RenderListWheelViewport.defaultPerspective;
    _resolvedOffAxisFraction = offAxisFraction ?? TomCtr.doubleVal(basePath, 'offAxisFraction') ?? 0.0;
    _resolvedMagnification = magnification ?? TomCtr.doubleVal(basePath, 'magnification') ?? 1.0;
    _resolvedOverAndUnderCenterOpacity = overAndUnderCenterOpacity ?? TomCtr.doubleVal(basePath, 'overAndUnderCenterOpacity') ?? 1.0;
    _resolvedItemExtent = itemExtent ?? TomCtr.doubleOrFail(basePath, 'itemExtent');
    _resolvedSqueeze = squeeze ?? TomCtr.doubleVal(basePath, 'squeeze') ?? 1.0;
    _resolvedUseMagnifier = TomCtr.boolVal(basePath, 'useMagnifier') ?? useMagnifier;
    _resolvedRenderChildrenOutsideViewport = TomCtr.boolVal(basePath, 'renderChildrenOutsideViewport') ?? renderChildrenOutsideViewport;
    _resolvedRestorationId = restorationId ?? TomCtr.textOrNull(basePath, 'restorationId');
  }

  @override
  Widget buildContent(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      physics: physics,
      diameterRatio: _resolvedDiameterRatio,
      perspective: _resolvedPerspective,
      offAxisFraction: _resolvedOffAxisFraction,
      useMagnifier: _resolvedUseMagnifier,
      magnification: _resolvedMagnification,
      overAndUnderCenterOpacity: _resolvedOverAndUnderCenterOpacity,
      itemExtent: _resolvedItemExtent,
      squeeze: _resolvedSqueeze,
      onSelectedItemChanged: onSelectedItemChanged,
      renderChildrenOutsideViewport: _resolvedRenderChildrenOutsideViewport,
      clipBehavior: clipBehavior,
      restorationId: _resolvedRestorationId,
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
  final Widget? title;
  final String? titleText;
  final Widget? subtitle;
  final Widget? additionalInfo;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final double? leadingSize;
  final double? leadingToTitle;

  // Pre-resolved resource values
  late final String _resolvedTitle;
  late final Color? _resolvedBackgroundColor;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final double _resolvedLeadingSize;
  late final double _resolvedLeadingToTitle;

  TomCupertinoListTile({
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
    this.additionalInfo,
    this.leading,
    this.trailing,
    VoidCallback? onTap,
    this.backgroundColor,
    this.padding,
    this.leadingSize,
    this.leadingToTitle,
  })  : onTap = InScopeBuilder(scope: scope).wrap0n(onTap) {
    _resolvedTitle = titleText ?? TomCtr.textOrNull(basePath, 'titleText') ?? TomCtr.textOrFail(basePath, 'label');
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
    _resolvedLeadingSize = leadingSize ?? TomCtr.doubleVal(basePath, 'leadingSize') ?? 28.0;
    _resolvedLeadingToTitle = leadingToTitle ?? TomCtr.doubleVal(basePath, 'leadingToTitle') ?? 12.0;
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoListTile(
      title: title ?? Text(_resolvedTitle),
      subtitle: subtitle,
      additionalInfo: additionalInfo,
      leading: leading,
      trailing: trailing,
      onTap: onTap,
      backgroundColor: _resolvedBackgroundColor,
      padding: _resolvedPadding,
      leadingSize: _resolvedLeadingSize,
      leadingToTitle: _resolvedLeadingToTitle,
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
  final bool? hasLeading;
  final Color? dividerMargin;
  final double additionalDividerMargin;
  final Widget? decoration;
  final Widget? separatorColor;

  // Pre-resolved resource values
  late final Color _resolvedBackgroundColor;
  late final double? _resolvedTopMargin;
  late final bool _resolvedHasLeading;
  late final double _resolvedAdditionalDividerMargin;
  late final EdgeInsetsGeometry _resolvedMargin;

  TomCupertinoListSection({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.children = const <Widget>[],
    this.header,
    this.footer,
    this.margin,
    this.backgroundColor,
    this.type = CupertinoListSectionType.base,
    this.clipBehavior = Clip.hardEdge,
    this.topMargin,
    this.hasLeading,
    this.dividerMargin,
    this.additionalDividerMargin = 0.0,
    this.decoration,
    this.separatorColor,
  }) {
    _resolvedBackgroundColor = backgroundColor ?? TomCtr.color(basePath, 'backgroundColor') ?? CupertinoColors.systemBackground;
    _resolvedTopMargin = topMargin ?? TomCtr.doubleVal(basePath, 'topMargin');
    _resolvedHasLeading = hasLeading ?? TomCtr.boolVal(basePath, 'hasLeading') ?? true;
    _resolvedAdditionalDividerMargin = additionalDividerMargin != 0.0 ? additionalDividerMargin : TomCtr.doubleVal(basePath, 'additionalDividerMargin') ?? 0.0;
    _resolvedMargin = margin ?? TomCtr.edgeInsets(basePath, 'margin') ?? const EdgeInsets.only(bottom: 8.0);
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoListSection(
      header: header,
      footer: footer,
      backgroundColor: _resolvedBackgroundColor,
      clipBehavior: clipBehavior,
      topMargin: _resolvedTopMargin,
      hasLeading: _resolvedHasLeading,
      additionalDividerMargin: _resolvedAdditionalDividerMargin,
      margin: _resolvedMargin,
      children: children,
    );
  }
}

/// Tom wrapper for [ReorderableList].
///
/// Reorderable list implementation. Auth on list content and reorder capability.
class TomReorderableList extends TomListBase {
  final SliverChildDelegate childrenDelegate;
  final ReorderCallback onReorderItem;
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
  final bool? shrinkWrap;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;
  final double anchor;
  final double? cacheExtent;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;

  // Pre-resolved resource values
  late final double? _resolvedItemExtent;
  late final bool _resolvedShrinkWrap;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final double _resolvedAnchor;
  late final ScrollCacheExtent? _resolvedCacheExtent;

  TomReorderableList({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.childrenDelegate,
    required ReorderCallback onReorderItem,
    void Function(int)? onReorderStart,
    void Function(int)? onReorderEnd,
    this.itemExtent,
    this.itemExtentBuilder,
    this.prototypeItem,
    this.proxyDecorator,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.shrinkWrap,
    this.padding,
    this.clipBehavior = Clip.hardEdge,
    this.anchor = 0.0,
    this.cacheExtent,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
  })  : onReorderItem = InScopeBuilder(scope: scope).wrap2(onReorderItem),
        onReorderStart = InScopeBuilder(scope: scope).wrap1n(onReorderStart),
        onReorderEnd = InScopeBuilder(scope: scope).wrap1n(onReorderEnd) {
    _resolvedItemExtent = itemExtent ?? TomCtr.doubleVal(basePath, 'itemExtent');
    _resolvedShrinkWrap = shrinkWrap ?? TomCtr.boolVal(basePath, 'shrinkWrap') ?? false;
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
    _resolvedAnchor = anchor != 0.0 ? anchor : TomCtr.doubleVal(basePath, 'anchor') ?? 0.0;
    final cacheExtentPixels = cacheExtent ?? TomCtr.doubleVal(basePath, 'cacheExtent');
    _resolvedCacheExtent = cacheExtentPixels == null ? null : ScrollCacheExtent.pixels(cacheExtentPixels);
  }

  @override
  Widget buildContent(BuildContext context) {
    // `childrenDelegate` is a `SliverChildDelegate` — both stock subtypes are
    // valid. A builder delegate yields items lazily; a list delegate exposes a
    // fixed `children` list. Pattern-match instead of force-casting so the
    // common `SliverChildListDelegate([...])` form works as well (bug §34).
    final delegate = childrenDelegate;
    final Widget Function(BuildContext, int) resolvedItemBuilder;
    final int resolvedItemCount;
    if (delegate is SliverChildBuilderDelegate) {
      resolvedItemBuilder =
          (context, index) => delegate.builder(context, index)!;
      resolvedItemCount = delegate.childCount ?? 0;
    } else if (delegate is SliverChildListDelegate) {
      final children = delegate.children;
      resolvedItemBuilder = (context, index) => children[index];
      resolvedItemCount = children.length;
    } else {
      throw ArgumentError(
        'TomReorderableList.childrenDelegate must be a '
        'SliverChildBuilderDelegate or SliverChildListDelegate, '
        'got ${delegate.runtimeType}.',
      );
    }
    return ReorderableList(
      itemBuilder: resolvedItemBuilder,
      itemCount: resolvedItemCount,
      onReorderItem: onReorderItem,
      onReorderStart: onReorderStart,
      onReorderEnd: onReorderEnd,
      itemExtent: _resolvedItemExtent,
      itemExtentBuilder: itemExtentBuilder,
      prototypeItem: prototypeItem,
      proxyDecorator: proxyDecorator,
      scrollDirection: scrollDirection,
      reverse: reverse,
      controller: controller,
      primary: primary,
      physics: physics,
      shrinkWrap: _resolvedShrinkWrap,
      padding: _resolvedPadding,
      clipBehavior: clipBehavior,
      anchor: _resolvedAnchor,
      scrollCacheExtent: _resolvedCacheExtent,
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
  final ReorderCallback onReorderItem;
  final void Function(int)? onReorderStart;
  final void Function(int)? onReorderEnd;
  final double? itemExtent;
  final ItemExtentBuilder? itemExtentBuilder;
  final Widget? prototypeItem;
  final ReorderItemProxyDecorator? proxyDecorator;

  // Pre-resolved resource values
  late final double? _resolvedItemExtent;

  TomSliverReorderableList({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.itemBuilder,
    required this.itemCount,
    required ReorderCallback onReorderItem,
    void Function(int)? onReorderStart,
    void Function(int)? onReorderEnd,
    this.itemExtent,
    this.itemExtentBuilder,
    this.prototypeItem,
    this.proxyDecorator,
  })  : onReorderItem = InScopeBuilder(scope: scope).wrap2(onReorderItem),
        onReorderStart = InScopeBuilder(scope: scope).wrap1n(onReorderStart),
        onReorderEnd = InScopeBuilder(scope: scope).wrap1n(onReorderEnd) {
    _resolvedItemExtent = itemExtent ?? TomCtr.doubleVal(basePath, 'itemExtent');
  }

  @override
  Widget buildContent(BuildContext context) {
    return SliverReorderableList(
      itemBuilder: itemBuilder,
      itemCount: itemCount,
      onReorderItem: onReorderItem,
      onReorderStart: onReorderStart,
      onReorderEnd: onReorderEnd,
      itemExtent: _resolvedItemExtent,
      itemExtentBuilder: itemExtentBuilder,
      prototypeItem: prototypeItem,
      proxyDecorator: proxyDecorator,
    );
  }
}
