import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../widget_base/tom_family_base.dart';

// =============================================================================
// Section II: Sliver Widgets
// =============================================================================

/// Tom wrapper for [DecoratedSliver].
///
/// Decoration around a sliver with sliver child. Auth on decorated sliver content.
class TomDecoratedSliver extends TomSliverBase {
  final Decoration decoration;
  final Widget sliver;

  const TomDecoratedSliver({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.decoration,
    required this.sliver,
  });

  @override
  Widget buildContent(BuildContext context) {
    return DecoratedSliver(
      decoration: decoration,
      sliver: sliver,
    );
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
      maxExtent ?? resolveDoubleOrFail(context, 'maxExtent');

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
  final int flex;
  final Widget sliver;

  const TomSliverCrossAxisExpanded({
    super.key,
    super.tomId,
    super.tomGroup,
    this.flex = 1,
    required this.sliver,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SliverCrossAxisExpanded(
      flex: flex,
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
        viewportFraction ?? resolveDoubleOrNull(context, 'viewportFraction') ?? 1.0;

    return SliverFillViewport(
      delegate: delegate,
      viewportFraction: resolvedViewportFraction,
      padEnds: padEnds,
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
      itemExtent ?? resolveDoubleOrFail(context, 'itemExtent');

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
  final bool offstage;
  final Widget sliver;

  const TomSliverOffstage({
    super.key,
    super.tomId,
    super.tomGroup,
    this.offstage = true,
    required this.sliver,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SliverOffstage(
      offstage: offstage,
      sliver: sliver,
    );
  }
}

/// Tom wrapper for [SliverOpacity].
///
/// Opacity for slivers. Auth on sliver content; can make sliver invisible.
class TomSliverOpacity extends TomSliverBase {
  final double opacity;
  final bool alwaysIncludeSemantics;
  final Widget sliver;

  const TomSliverOpacity({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.opacity,
    this.alwaysIncludeSemantics = false,
    required this.sliver,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SliverOpacity(
      opacity: opacity,
      alwaysIncludeSemantics: alwaysIncludeSemantics,
      sliver: sliver,
    );
  }
}

/// Tom wrapper for [SliverPadding].
///
/// Padding around a sliver. Auth on padded sliver content.
class TomSliverPadding extends TomSliverBase {
  final EdgeInsetsGeometry padding;
  final Widget sliver;

  const TomSliverPadding({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.padding,
    required this.sliver,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: sliver,
    );
  }
}

/// Tom wrapper for [SliverPersistentHeader].
///
/// Persistent/pinned header in scroll. Auth on persistent header content.
class TomSliverPersistentHeader extends TomSliverBase {
  final SliverPersistentHeaderDelegate delegate;
  final bool pinned;
  final bool floating;

  const TomSliverPersistentHeader({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.delegate,
    this.pinned = false,
    this.floating = false,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SliverPersistentHeader(
      delegate: delegate,
      pinned: pinned,
      floating: floating,
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
  final bool left;
  final bool top;
  final bool right;
  final bool bottom;
  final EdgeInsets minimum;
  final Widget sliver;

  const TomSliverSafeArea({
    super.key,
    super.tomId,
    super.tomGroup,
    this.left = true,
    this.top = true,
    this.right = true,
    this.bottom = true,
    this.minimum = EdgeInsets.zero,
    required this.sliver,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SliverSafeArea(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      minimum: minimum,
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
  final bool visible;
  final bool maintainState;
  final bool maintainAnimation;
  final bool maintainSize;
  final bool maintainSemantics;
  final bool maintainInteractivity;

  const TomSliverVisibility({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.sliver,
    this.replacementSliver = const SliverToBoxAdapter(child: SizedBox.shrink()),
    this.visible = true,
    this.maintainState = false,
    this.maintainAnimation = false,
    this.maintainSize = false,
    this.maintainSemantics = false,
    this.maintainInteractivity = false,
  });

  @override
  Widget buildContent(BuildContext context) {
    return SliverVisibility(
      sliver: sliver,
      replacementSliver: replacementSliver,
      visible: visible,
      maintainState: maintainState,
      maintainAnimation: maintainAnimation,
      maintainSize: maintainSize,
      maintainSemantics: maintainSemantics,
      maintainInteractivity: maintainInteractivity,
    );
  }
}
