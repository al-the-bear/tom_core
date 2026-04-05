import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../widget_base/tom_family_base.dart';
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

  const TomDecoratedSliver({
    super.key,
    super.tomId,
    super.tomGroup,
    this.decoration,
    required this.sliver,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedDecoration = decoration ?? _resolveDecoration('decoration');
    if (resolvedDecoration == null) {
      throw FlutterError(
        'TomDecoratedSliver requires a decoration. '
        'Provide it explicitly or define it in resources.',
      );
    }

    return DecoratedSliver(
      decoration: resolvedDecoration,
      sliver: sliver,
    );
  }

  Decoration? _resolveDecoration(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveDecoration(basePath, suffix);
  }
}

/// Tom wrapper for [PinnedHeaderSliver].
///
/// Pinned header in scroll view. Auth on pinned header content.
class TomPinnedHeaderSliver extends TomSliverBase {
  final Widget child;

  const TomPinnedHeaderSliver({
    super.key,
    super.tomId,
    super.tomGroup,
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

  const TomSliverConstrainedCrossAxis({
    super.key,
    super.tomId,
    super.tomGroup,
    this.maxExtent,
    required this.sliver,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedMaxExtent =
      maxExtent ?? resolveDoubleOrFail('maxExtent');

    return SliverConstrainedCrossAxis(
      maxExtent: resolvedMaxExtent,
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

  const TomSliverCrossAxisExpanded({
    super.key,
    super.tomId,
    super.tomGroup,
    this.flex,
    required this.sliver,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedFlex = flex ?? resolveIntOrNull('flex') ?? 1;

    return SliverCrossAxisExpanded(
      flex: resolvedFlex,
      sliver: sliver,
    );
  }
}

/// Tom wrapper for [SliverCrossAxisGroup].
///
/// Groups slivers on cross axis. Auth on sliver group.
class TomSliverCrossAxisGroup extends TomSliverBase {
  final List<Widget> slivers;

  const TomSliverCrossAxisGroup({
    super.key,
    super.tomId,
    super.tomGroup,
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

  const TomSliverFillViewport({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.delegate,
    this.viewportFraction,
    this.padEnds = true,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedViewportFraction =
        viewportFraction ?? resolveDoubleOrNull('viewportFraction') ?? 1.0;
    final resolvedPadEnds = resolveBoolOrNull('padEnds') ?? padEnds;

    return SliverFillViewport(
      delegate: delegate,
      viewportFraction: resolvedViewportFraction,
      padEnds: resolvedPadEnds,
    );
  }
}

/// Tom wrapper for [SliverFixedExtentList].
///
/// Fixed-height items in sliver. Auth on list content.
class TomSliverFixedExtentList extends TomSliverBase {
  final SliverChildDelegate delegate;
  final double? itemExtent;

  const TomSliverFixedExtentList({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.delegate,
    this.itemExtent,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedItemExtent =
      itemExtent ?? resolveDoubleOrFail('itemExtent');

    return SliverFixedExtentList(
      delegate: delegate,
      itemExtent: resolvedItemExtent,
    );
  }
}

/// Tom wrapper for [SliverFloatingHeader].
///
/// Floating header in scroll. Auth on header content.
class TomSliverFloatingHeader extends TomSliverBase {
  final Widget child;

  const TomSliverFloatingHeader({
    super.key,
    super.tomId,
    super.tomGroup,
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

  const TomSliverMainAxisGroup({
    super.key,
    super.tomId,
    super.tomGroup,
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

  const TomSliverOffstage({
    super.key,
    super.tomId,
    super.tomGroup,
    this.offstage,
    required this.sliver,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedOffstage =
        offstage ?? resolveBoolOrNull('offstage') ?? true;

    return SliverOffstage(
      offstage: resolvedOffstage,
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

  const TomSliverOpacity({
    super.key,
    super.tomId,
    super.tomGroup,
    this.opacity,
    this.alwaysIncludeSemantics,
    required this.sliver,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedOpacity =
        opacity ?? resolveDoubleOrFail('opacity');
    final resolvedAlwaysIncludeSemantics = alwaysIncludeSemantics ??
        resolveBoolOrNull('alwaysIncludeSemantics') ?? false;

    return SliverOpacity(
      opacity: resolvedOpacity,
      alwaysIncludeSemantics: resolvedAlwaysIncludeSemantics,
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

  const TomSliverPadding({
    super.key,
    super.tomId,
    super.tomGroup,
    this.padding,
    required this.sliver,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding');
    if (resolvedPadding == null) {
      throw StateError(
        'Tom widget requires either an explicit padding or a tomId resource '
        'value at padding. Widget: $runtimeType',
      );
    }

    return SliverPadding(
      padding: resolvedPadding,
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

  const TomSliverPersistentHeader({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.delegate,
    this.pinned,
    this.floating,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedPinned = pinned ?? resolveBoolOrNull('pinned') ?? false;
    final resolvedFloating =
        floating ?? resolveBoolOrNull('floating') ?? false;

    return SliverPersistentHeader(
      delegate: delegate,
      pinned: resolvedPinned,
      floating: resolvedFloating,
    );
  }
}

/// Tom wrapper for [SliverPrototypeExtentList].
///
/// List with prototype-based extent. Auth on list content.
class TomSliverPrototypeExtentList extends TomSliverBase {
  final SliverChildDelegate delegate;
  final Widget prototypeItem;

  const TomSliverPrototypeExtentList({
    super.key,
    super.tomId,
    super.tomGroup,
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

  const TomSliverResizingHeader({
    super.key,
    super.tomId,
    super.tomGroup,
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

  const TomSliverSafeArea({
    super.key,
    super.tomId,
    super.tomGroup,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.minimum,
    required this.sliver,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedLeft = left ?? resolveBoolOrNull('left') ?? true;
    final resolvedTop = top ?? resolveBoolOrNull('top') ?? true;
    final resolvedRight = right ?? resolveBoolOrNull('right') ?? true;
    final resolvedBottom =
        bottom ?? resolveBoolOrNull('bottom') ?? true;
    final resolvedMinimum =
        minimum ?? resolveEdgeInsetsOrNull('minimum') ?? EdgeInsets.zero;

    return SliverSafeArea(
      left: resolvedLeft,
      top: resolvedTop,
      right: resolvedRight,
      bottom: resolvedBottom,
      minimum: resolvedMinimum,
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

  const TomSliverVariedExtentList({
    super.key,
    super.tomId,
    super.tomGroup,
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

  const TomSliverVisibility({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.sliver,
    this.replacementSliver = const SliverToBoxAdapter(child: SizedBox.shrink()),
    this.visible,
    this.maintainState,
    this.maintainAnimation,
    this.maintainSize,
    this.maintainSemantics,
    this.maintainInteractivity,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedVisible =
        visible ?? resolveBoolOrNull('visible') ?? true;
    final resolvedMaintainState =
        maintainState ?? resolveBoolOrNull('maintainState') ?? false;
    final resolvedMaintainAnimation = maintainAnimation ??
        resolveBoolOrNull('maintainAnimation') ?? false;
    final resolvedMaintainSize =
        maintainSize ?? resolveBoolOrNull('maintainSize') ?? false;
    final resolvedMaintainSemantics = maintainSemantics ??
        resolveBoolOrNull('maintainSemantics') ?? false;
    final resolvedMaintainInteractivity = maintainInteractivity ??
        resolveBoolOrNull('maintainInteractivity') ?? false;

    return SliverVisibility(
      sliver: sliver,
      replacementSliver: replacementSliver,
      visible: resolvedVisible,
      maintainState: resolvedMaintainState,
      maintainAnimation: resolvedMaintainAnimation,
      maintainSize: resolvedMaintainSize,
      maintainSemantics: resolvedMaintainSemantics,
      maintainInteractivity: resolvedMaintainInteractivity,
    );
  }
}
