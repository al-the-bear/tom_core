import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_style_resolvers.dart';

// =============================================================================
// Section II: Sliver Widgets
// =============================================================================

/// Tom wrapper for [DecoratedSliver].
///
/// Decoration around a sliver with sliver child. Auth on decorated sliver content.
///
/// If [decoration] is not provided, it will be resolved from resources.
/// Throws if neither an explicit value nor a resource-based definition exists.
class TomDecoratedSliver extends TomSliverBase {
  final Decoration? decoration;
  final Widget sliver;

  // Pre-resolved resource values
  late final Decoration? _resolvedDecoration;

  TomDecoratedSliver({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.decoration,
    required this.sliver,
  }) {
    _resolvedDecoration = decoration ?? _resolveDecoration('decoration');
  }

  @override
  Widget buildContent(BuildContext context) {
    if (_resolvedDecoration == null) {
      throw FlutterError(
        'TomDecoratedSliver requires a decoration. '
        'Provide it explicitly or define it in resources.',
      );
    }

    return DecoratedSliver(
      decoration: _resolvedDecoration,
      sliver: sliver,
    );
  }

  Decoration? _resolveDecoration(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveDecoration(basePath!, suffix);
  }
}

/// Tom wrapper for [PinnedHeaderSliver].
///
/// Pinned header in scroll view. Auth on pinned header content.
class TomPinnedHeaderSliver extends TomSliverBase {
  final Widget child;

  TomPinnedHeaderSliver({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return PinnedHeaderSliver(
      child: child,
    );
  }
}

/// Tom wrapper for [SliverConstrainedCrossAxis].
///
/// Constrains sliver cross-axis size. Auth on constrained sliver content.
class TomSliverConstrainedCrossAxis extends TomSliverBase {
  final double? maxExtent;
  final Widget sliver;

  // Pre-resolved resource values
  late final double _resolvedMaxExtent;

  TomSliverConstrainedCrossAxis({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.maxExtent,
    required this.sliver,
  }) {
    _resolvedMaxExtent = maxExtent ?? TomCtr.doubleOrFail(basePath, 'maxExtent');
  }

  @override
  Widget buildContent(BuildContext context) {
    return SliverConstrainedCrossAxis(
      maxExtent: _resolvedMaxExtent,
      sliver: sliver,
    );
  }
}

/// Tom wrapper for [SliverCrossAxisExpanded].
///
/// Expands sliver in cross axis. Auth on expanded sliver section.
class TomSliverCrossAxisExpanded extends TomSliverBase {
  final int? flex;
  final Widget sliver;

  // Pre-resolved resource values
  late final int _resolvedFlex;

  TomSliverCrossAxisExpanded({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.flex,
    required this.sliver,
  }) {
    _resolvedFlex = flex ?? TomCtr.intVal(basePath, 'flex') ?? 1;
  }

  @override
  Widget buildContent(BuildContext context) {
    return SliverCrossAxisExpanded(
      flex: _resolvedFlex,
      sliver: sliver,
    );
  }
}

/// Tom wrapper for [SliverCrossAxisGroup].
///
/// Groups slivers on cross axis. Auth on sliver group.
class TomSliverCrossAxisGroup extends TomSliverBase {
  final List<Widget> slivers;

  TomSliverCrossAxisGroup({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.slivers,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SliverCrossAxisGroup(
      slivers: slivers,
    );
  }
}

/// Tom wrapper for [SliverFillViewport].
///
/// Fills viewport with each child. Auth on viewport children.
class TomSliverFillViewport extends TomSliverBase {
  final SliverChildDelegate delegate;
  final double? viewportFraction;
  final bool padEnds;

  // Pre-resolved resource values
  late final double _resolvedViewportFraction;
  late final bool _resolvedPadEnds;

  TomSliverFillViewport({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.delegate,
    this.viewportFraction,
    this.padEnds = true,
  }) {
    _resolvedViewportFraction = viewportFraction ?? TomCtr.doubleVal(basePath, 'viewportFraction') ?? 1.0;
    _resolvedPadEnds = TomCtr.boolVal(basePath, 'padEnds') ?? padEnds;
  }

  @override
  Widget buildContent(BuildContext context) {
    return SliverFillViewport(
      delegate: delegate,
      viewportFraction: _resolvedViewportFraction,
      padEnds: _resolvedPadEnds,
    );
  }
}

/// Tom wrapper for [SliverFixedExtentList].
///
/// Fixed-height items in sliver. Auth on list content.
class TomSliverFixedExtentList extends TomSliverBase {
  final SliverChildDelegate delegate;
  final double? itemExtent;

  // Pre-resolved resource values
  late final double _resolvedItemExtent;

  TomSliverFixedExtentList({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.delegate,
    this.itemExtent,
  }) {
    _resolvedItemExtent = itemExtent ?? TomCtr.doubleOrFail(basePath, 'itemExtent');
  }

  @override
  Widget buildContent(BuildContext context) {
    return SliverFixedExtentList(
      delegate: delegate,
      itemExtent: _resolvedItemExtent,
    );
  }
}

/// Tom wrapper for [SliverFloatingHeader].
///
/// Floating header in scroll. Auth on header content.
class TomSliverFloatingHeader extends TomSliverBase {
  final Widget child;

  TomSliverFloatingHeader({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SliverFloatingHeader(
      child: child,
    );
  }
}

/// Tom wrapper for [SliverMainAxisGroup].
///
/// Groups slivers sequentially. Auth on sliver group.
class TomSliverMainAxisGroup extends TomSliverBase {
  final List<Widget> slivers;

  TomSliverMainAxisGroup({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.slivers,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: slivers,
    );
  }
}

/// Tom wrapper for [SliverOffstage].
///
/// Hides sliver (keeps in tree). Auth on offstage sliver — natural visibility control.
class TomSliverOffstage extends TomSliverBase {
  final bool? offstage;
  final Widget sliver;

  // Pre-resolved resource values
  late final bool _resolvedOffstage;

  TomSliverOffstage({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.offstage,
    required this.sliver,
  }) {
    _resolvedOffstage = offstage ?? TomCtr.boolVal(basePath, 'offstage') ?? true;
  }

  @override
  Widget buildContent(BuildContext context) {
    return SliverOffstage(
      offstage: _resolvedOffstage,
      sliver: sliver,
    );
  }
}

/// Tom wrapper for [SliverOpacity].
///
/// Opacity for slivers. Auth on sliver content; can make sliver invisible.
class TomSliverOpacity extends TomSliverBase {
  final double? opacity;
  final bool? alwaysIncludeSemantics;
  final Widget sliver;

  // Pre-resolved resource values
  late final double _resolvedOpacity;
  late final bool _resolvedAlwaysIncludeSemantics;

  TomSliverOpacity({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.opacity,
    this.alwaysIncludeSemantics,
    required this.sliver,
  }) {
    _resolvedOpacity = opacity ?? TomCtr.doubleOrFail(basePath, 'opacity');
    _resolvedAlwaysIncludeSemantics = alwaysIncludeSemantics ?? TomCtr.boolVal(basePath, 'alwaysIncludeSemantics') ?? false;
  }

  @override
  Widget buildContent(BuildContext context) {
    return SliverOpacity(
      opacity: _resolvedOpacity,
      alwaysIncludeSemantics: _resolvedAlwaysIncludeSemantics,
      sliver: sliver,
    );
  }
}

/// Tom wrapper for [SliverPadding].
///
/// Padding around a sliver. Auth on padded sliver content.
class TomSliverPadding extends TomSliverBase {
  final EdgeInsetsGeometry? padding;
  final Widget sliver;

  // Pre-resolved resource values
  late final EdgeInsetsGeometry? _resolvedPadding;

  TomSliverPadding({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.padding,
    required this.sliver,
  }) {
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
  }

  @override
  Widget buildContent(BuildContext context) {
    if (_resolvedPadding == null) {
      throw StateError(
        'Tom widget requires either an explicit padding or a tomId resource '
        'value at padding. Widget: $runtimeType',
      );
    }

    return SliverPadding(
      padding: _resolvedPadding,
      sliver: sliver,
    );
  }
}

/// Tom wrapper for [SliverPersistentHeader].
///
/// Persistent/pinned header in scroll. Auth on persistent header content.
class TomSliverPersistentHeader extends TomSliverBase {
  final SliverPersistentHeaderDelegate delegate;
  final bool? pinned;
  final bool? floating;

  // Pre-resolved resource values
  late final bool _resolvedPinned;
  late final bool _resolvedFloating;

  TomSliverPersistentHeader({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.delegate,
    this.pinned,
    this.floating,
  }) {
    _resolvedPinned = pinned ?? TomCtr.boolVal(basePath, 'pinned') ?? false;
    _resolvedFloating = floating ?? TomCtr.boolVal(basePath, 'floating') ?? false;
  }

  @override
  Widget buildContent(BuildContext context) {
    return SliverPersistentHeader(
      delegate: delegate,
      pinned: _resolvedPinned,
      floating: _resolvedFloating,
    );
  }
}

/// Tom wrapper for [SliverPrototypeExtentList].
///
/// List with prototype-based extent. Auth on list content.
class TomSliverPrototypeExtentList extends TomSliverBase {
  final SliverChildDelegate delegate;
  final Widget prototypeItem;

  TomSliverPrototypeExtentList({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.delegate,
    required this.prototypeItem,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SliverPrototypeExtentList(
      delegate: delegate,
      prototypeItem: prototypeItem,
    );
  }
}

/// Tom wrapper for [SliverResizingHeader].
///
/// Resizing header in scroll. Auth on header content.
class TomSliverResizingHeader extends TomSliverBase {
  final Widget? child;
  final double minExtentPrototype;
  final double maxExtentPrototype;

  TomSliverResizingHeader({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.child,
    this.minExtentPrototype = 0.0,
    this.maxExtentPrototype = double.infinity,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SliverResizingHeader(
      child: child,
    );
  }
}

/// Tom wrapper for [SliverSafeArea].
///
/// Safe area insets for slivers. Auth on safe-area sliver content.
class TomSliverSafeArea extends TomSliverBase {
  final bool? left;
  final bool? top;
  final bool? right;
  final bool? bottom;
  final EdgeInsets? minimum;
  final Widget sliver;

  // Pre-resolved resource values
  late final bool _resolvedLeft;
  late final bool _resolvedTop;
  late final bool _resolvedRight;
  late final bool _resolvedBottom;
  late final EdgeInsets _resolvedMinimum;

  TomSliverSafeArea({
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
    this.minimum,
    required this.sliver,
  }) {
    _resolvedLeft = left ?? TomCtr.boolVal(basePath, 'left') ?? true;
    _resolvedTop = top ?? TomCtr.boolVal(basePath, 'top') ?? true;
    _resolvedRight = right ?? TomCtr.boolVal(basePath, 'right') ?? true;
    _resolvedBottom = bottom ?? TomCtr.boolVal(basePath, 'bottom') ?? true;
    _resolvedMinimum = minimum ?? TomCtr.edgeInsets(basePath, 'minimum') ?? EdgeInsets.zero;
  }

  @override
  Widget buildContent(BuildContext context) {
    return SliverSafeArea(
      left: _resolvedLeft,
      top: _resolvedTop,
      right: _resolvedRight,
      bottom: _resolvedBottom,
      minimum: _resolvedMinimum,
      sliver: sliver,
    );
  }
}

/// Tom wrapper for [SliverVariedExtentList].
///
/// Variable-height items in sliver. Auth on list content.
class TomSliverVariedExtentList extends TomSliverBase {
  final SliverChildDelegate delegate;
  final ItemExtentBuilder itemExtentBuilder;

  TomSliverVariedExtentList({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.delegate,
    required this.itemExtentBuilder,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SliverVariedExtentList(
      delegate: delegate,
      itemExtentBuilder: itemExtentBuilder,
    );
  }
}

/// Tom wrapper for [SliverVisibility].
///
/// Visibility control for slivers. Natural auth fit — hides sliver content.
class TomSliverVisibility extends TomSliverBase {
  final Widget sliver;
  final Widget replacementSliver;
  final bool? visible;
  final bool? maintainState;
  final bool? maintainAnimation;
  final bool? maintainSize;
  final bool? maintainSemantics;
  final bool? maintainInteractivity;

  // Pre-resolved resource values
  late final bool _resolvedVisible;
  late final bool _resolvedMaintainState;
  late final bool _resolvedMaintainAnimation;
  late final bool _resolvedMaintainSize;
  late final bool _resolvedMaintainSemantics;
  late final bool _resolvedMaintainInteractivity;

  TomSliverVisibility({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.sliver,
    this.replacementSliver = const SliverToBoxAdapter(child: SizedBox.shrink()),
    this.visible,
    this.maintainState,
    this.maintainAnimation,
    this.maintainSize,
    this.maintainSemantics,
    this.maintainInteractivity,
  }) {
    _resolvedVisible = visible ?? TomCtr.boolVal(basePath, 'visible') ?? true;
    _resolvedMaintainState = maintainState ?? TomCtr.boolVal(basePath, 'maintainState') ?? false;
    _resolvedMaintainAnimation = maintainAnimation ?? TomCtr.boolVal(basePath, 'maintainAnimation') ?? false;
    _resolvedMaintainSize = maintainSize ?? TomCtr.boolVal(basePath, 'maintainSize') ?? false;
    _resolvedMaintainSemantics = maintainSemantics ?? TomCtr.boolVal(basePath, 'maintainSemantics') ?? false;
    _resolvedMaintainInteractivity = maintainInteractivity ?? TomCtr.boolVal(basePath, 'maintainInteractivity') ?? false;
  }

  @override
  Widget buildContent(BuildContext context) {
    return SliverVisibility(
      sliver: sliver,
      replacementSliver: replacementSliver,
      visible: _resolvedVisible,
      maintainState: _resolvedMaintainState,
      maintainAnimation: _resolvedMaintainAnimation,
      maintainSize: _resolvedMaintainSize,
      maintainSemantics: _resolvedMaintainSemantics,
      maintainInteractivity: _resolvedMaintainInteractivity,
    );
  }
}
