import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widget_base/tom_family_base.dart';

// =============================================================================
// Section II: Interaction Widgets
// =============================================================================

/// Tom wrapper for [GestureDetector].
///
/// Detects taps, drags, long-press, etc. Auth can disable interactions on protected content.
class TomGestureDetector extends TomInteractionBase {
  final Widget? child;
  final GestureTapCallback? onTap;
  final GestureTapCallback? onTapCancel;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCallback? onSecondaryTap;
  final GestureTapDownCallback? onSecondaryTapDown;
  final GestureTapUpCallback? onSecondaryTapUp;
  final GestureTapCallback? onSecondaryTapCancel;
  final GestureTapDownCallback? onTertiaryTapDown;
  final GestureTapUpCallback? onTertiaryTapUp;
  final GestureTapCallback? onTertiaryTapCancel;
  final GestureDoubleTapCallback? onDoubleTap;
  final GestureLongPressCallback? onLongPress;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;
  final GestureLongPressUpCallback? onLongPressUp;
  final GestureLongPressEndCallback? onLongPressEnd;
  final GestureDragDownCallback? onVerticalDragDown;
  final GestureDragStartCallback? onVerticalDragStart;
  final GestureDragUpdateCallback? onVerticalDragUpdate;
  final GestureDragEndCallback? onVerticalDragEnd;
  final GestureDragCancelCallback? onVerticalDragCancel;
  final GestureDragDownCallback? onHorizontalDragDown;
  final GestureDragStartCallback? onHorizontalDragStart;
  final GestureDragUpdateCallback? onHorizontalDragUpdate;
  final GestureDragEndCallback? onHorizontalDragEnd;
  final GestureDragCancelCallback? onHorizontalDragCancel;
  final GestureDragDownCallback? onPanDown;
  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;
  final GestureDragCancelCallback? onPanCancel;
  final GestureScaleStartCallback? onScaleStart;
  final GestureScaleUpdateCallback? onScaleUpdate;
  final GestureScaleEndCallback? onScaleEnd;
  final GestureForcePressStartCallback? onForcePressStart;
  final GestureForcePressPeakCallback? onForcePressPeak;
  final GestureForcePressUpdateCallback? onForcePressUpdate;
  final GestureForcePressEndCallback? onForcePressEnd;
  final HitTestBehavior? behavior;
  final bool? excludeFromSemantics;
  final DragStartBehavior dragStartBehavior;
  final Set<PointerDeviceKind>? supportedDevices;
  final bool? trackpadScrollCausesScale;
  final Offset trackpadScrollToScaleFactor;

  const TomGestureDetector({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    this.onTap,
    this.onTapCancel,
    this.onTapDown,
    this.onTapUp,
    this.onSecondaryTap,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.onSecondaryTapCancel,
    this.onTertiaryTapDown,
    this.onTertiaryTapUp,
    this.onTertiaryTapCancel,
    this.onDoubleTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressUp,
    this.onLongPressEnd,
    this.onVerticalDragDown,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
    this.onHorizontalDragDown,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onHorizontalDragCancel,
    this.onPanDown,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onPanCancel,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.onForcePressStart,
    this.onForcePressPeak,
    this.onForcePressUpdate,
    this.onForcePressEnd,
    this.behavior,
    this.excludeFromSemantics,
    this.dragStartBehavior = DragStartBehavior.start,
    this.supportedDevices,
    this.trackpadScrollCausesScale,
    this.trackpadScrollToScaleFactor = kDefaultTrackpadScrollToScaleFactor,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedExcludeFromSemantics = excludeFromSemantics ??
      resolveBoolOrNull(context, 'excludeFromSemantics') ?? false;
    final resolvedTrackpadScrollCausesScale = trackpadScrollCausesScale ??
      resolveBoolOrNull(context, 'trackpadScrollCausesScale') ?? false;

    return GestureDetector(
      onTap: onTap,
      onTapCancel: onTapCancel,
      onTapDown: onTapDown,
      onTapUp: onTapUp,
      onSecondaryTap: onSecondaryTap,
      onSecondaryTapDown: onSecondaryTapDown,
      onSecondaryTapUp: onSecondaryTapUp,
      onSecondaryTapCancel: onSecondaryTapCancel,
      onTertiaryTapDown: onTertiaryTapDown,
      onTertiaryTapUp: onTertiaryTapUp,
      onTertiaryTapCancel: onTertiaryTapCancel,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onLongPressStart: onLongPressStart,
      onLongPressMoveUpdate: onLongPressMoveUpdate,
      onLongPressUp: onLongPressUp,
      onLongPressEnd: onLongPressEnd,
      onVerticalDragDown: onVerticalDragDown,
      onVerticalDragStart: onVerticalDragStart,
      onVerticalDragUpdate: onVerticalDragUpdate,
      onVerticalDragEnd: onVerticalDragEnd,
      onVerticalDragCancel: onVerticalDragCancel,
      onHorizontalDragDown: onHorizontalDragDown,
      onHorizontalDragStart: onHorizontalDragStart,
      onHorizontalDragUpdate: onHorizontalDragUpdate,
      onHorizontalDragEnd: onHorizontalDragEnd,
      onHorizontalDragCancel: onHorizontalDragCancel,
      onPanDown: onPanDown,
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      onPanCancel: onPanCancel,
      onScaleStart: onScaleStart,
      onScaleUpdate: onScaleUpdate,
      onScaleEnd: onScaleEnd,
      onForcePressStart: onForcePressStart,
      onForcePressPeak: onForcePressPeak,
      onForcePressUpdate: onForcePressUpdate,
      onForcePressEnd: onForcePressEnd,
      behavior: behavior,
      excludeFromSemantics: resolvedExcludeFromSemantics,
      dragStartBehavior: dragStartBehavior,
      supportedDevices: supportedDevices,
      trackpadScrollCausesScale: resolvedTrackpadScrollCausesScale,
      trackpadScrollToScaleFactor: trackpadScrollToScaleFactor,
      child: child,
    );
  }
}

/// Tom wrapper for [InkWell].
///
/// Material tap target with ink splash. Auth can control tap access.
class TomInkWell extends TomInteractionBase {
  final Widget? child;
  final GestureTapCallback? onTap;
  final GestureTapCallback? onDoubleTap;
  final GestureLongPressCallback? onLongPress;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCallback? onTapCancel;
  final GestureTapCallback? onSecondaryTap;
  final GestureTapUpCallback? onSecondaryTapUp;
  final GestureTapDownCallback? onSecondaryTapDown;
  final GestureTapCallback? onSecondaryTapCancel;
  final ValueChanged<bool>? onHighlightChanged;
  final ValueChanged<bool>? onHover;
  final MouseCursor? mouseCursor;
  final Color? focusColor;
  final Color? hoverColor;
  final Color? highlightColor;
  final WidgetStateProperty<Color?>? overlayColor;
  final Color? splashColor;
  final InteractiveInkFeatureFactory? splashFactory;
  final double? radius;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  final bool? enableFeedback;
  final bool excludeFromSemantics;
  final FocusNode? focusNode;
  final bool canRequestFocus;
  final ValueChanged<bool>? onFocusChange;
  final bool autofocus;
  final WidgetStatesController? statesController;
  final Duration? hoverDuration;

  const TomInkWell({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.onSecondaryTap,
    this.onSecondaryTapUp,
    this.onSecondaryTapDown,
    this.onSecondaryTapCancel,
    this.onHighlightChanged,
    this.onHover,
    this.mouseCursor,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.overlayColor,
    this.splashColor,
    this.splashFactory,
    this.radius,
    this.borderRadius,
    this.customBorder,
    this.enableFeedback,
    this.excludeFromSemantics = false,
    this.focusNode,
    this.canRequestFocus = true,
    this.onFocusChange,
    this.autofocus = false,
    this.statesController,
    this.hoverDuration,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedFocusColor =
        focusColor ?? resolveColorOrNull(context, 'focusColor');
    final resolvedHoverColor =
        hoverColor ?? resolveColorOrNull(context, 'hoverColor');
    final resolvedHighlightColor =
        highlightColor ?? resolveColorOrNull(context, 'highlightColor');
    final resolvedSplashColor =
        splashColor ?? resolveColorOrNull(context, 'splashColor');
    final resolvedRadius =
        radius ?? resolveDoubleOrNull(context, 'radius');

    return InkWell(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onTapDown: onTapDown,
      onTapUp: onTapUp,
      onTapCancel: onTapCancel,
      onSecondaryTap: onSecondaryTap,
      onSecondaryTapUp: onSecondaryTapUp,
      onSecondaryTapDown: onSecondaryTapDown,
      onSecondaryTapCancel: onSecondaryTapCancel,
      onHighlightChanged: onHighlightChanged,
      onHover: onHover,
      mouseCursor: mouseCursor,
      focusColor: resolvedFocusColor,
      hoverColor: resolvedHoverColor,
      highlightColor: resolvedHighlightColor,
      overlayColor: overlayColor,
      splashColor: resolvedSplashColor,
      splashFactory: splashFactory,
      radius: resolvedRadius,
      borderRadius: borderRadius,
      customBorder: customBorder,
      enableFeedback: enableFeedback ?? true,
      excludeFromSemantics: excludeFromSemantics,
      focusNode: focusNode,
      canRequestFocus: canRequestFocus,
      onFocusChange: onFocusChange,
      autofocus: autofocus,
      statesController: statesController,
      hoverDuration: hoverDuration,
      child: child,
    );
  }
}

/// Tom wrapper for [InkResponse].
///
/// Low-level ink splash response area. Auth on interactive content; base for InkWell.
class TomInkResponse extends TomInteractionBase {
  final Widget? child;
  final GestureTapCallback? onTap;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCallback? onTapCancel;
  final GestureTapCallback? onDoubleTap;
  final GestureLongPressCallback? onLongPress;
  final ValueChanged<bool>? onHighlightChanged;
  final ValueChanged<bool>? onHover;
  final MouseCursor? mouseCursor;
  final bool? containedInkWell;
  final BoxShape highlightShape;
  final double? radius;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  final Color? focusColor;
  final Color? hoverColor;
  final Color? highlightColor;
  final WidgetStateProperty<Color?>? overlayColor;
  final Color? splashColor;
  final InteractiveInkFeatureFactory? splashFactory;
  final bool? enableFeedback;
  final bool? excludeFromSemantics;
  final ValueChanged<bool>? onFocusChange;
  final bool? autofocus;
  final FocusNode? focusNode;
  final bool? canRequestFocus;
  final WidgetStatesController? statesController;
  final Duration? hoverDuration;

  const TomInkResponse({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.onDoubleTap,
    this.onLongPress,
    this.onHighlightChanged,
    this.onHover,
    this.mouseCursor,
    this.containedInkWell,
    this.highlightShape = BoxShape.circle,
    this.radius,
    this.borderRadius,
    this.customBorder,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.overlayColor,
    this.splashColor,
    this.splashFactory,
    this.enableFeedback,
    this.excludeFromSemantics,
    this.onFocusChange,
    this.autofocus,
    this.focusNode,
    this.canRequestFocus,
    this.statesController,
    this.hoverDuration,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedContainedInkWell =
      containedInkWell ?? resolveBoolOrNull(context, 'containedInkWell') ?? false;
    final resolvedRadius = radius ?? resolveDoubleOrNull(context, 'radius');
    final resolvedFocusColor =
      focusColor ?? resolveColorOrNull(context, 'focusColor');
    final resolvedHoverColor =
      hoverColor ?? resolveColorOrNull(context, 'hoverColor');
    final resolvedHighlightColor =
      highlightColor ?? resolveColorOrNull(context, 'highlightColor');
    final resolvedSplashColor =
      splashColor ?? resolveColorOrNull(context, 'splashColor');
    final resolvedEnableFeedback =
      enableFeedback ?? resolveBoolOrNull(context, 'enableFeedback') ?? true;
    final resolvedExcludeFromSemantics = excludeFromSemantics ??
      resolveBoolOrNull(context, 'excludeFromSemantics') ?? false;
    final resolvedAutofocus =
      autofocus ?? resolveBoolOrNull(context, 'autofocus') ?? false;
    final resolvedCanRequestFocus =
      canRequestFocus ?? resolveBoolOrNull(context, 'canRequestFocus') ?? true;

    return InkResponse(
      onTap: onTap,
      onTapDown: onTapDown,
      onTapUp: onTapUp,
      onTapCancel: onTapCancel,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onHighlightChanged: onHighlightChanged,
      onHover: onHover,
      mouseCursor: mouseCursor,
      containedInkWell: resolvedContainedInkWell,
      highlightShape: highlightShape,
      radius: resolvedRadius,
      borderRadius: borderRadius,
      customBorder: customBorder,
      focusColor: resolvedFocusColor,
      hoverColor: resolvedHoverColor,
      highlightColor: resolvedHighlightColor,
      overlayColor: overlayColor,
      splashColor: resolvedSplashColor,
      splashFactory: splashFactory,
      enableFeedback: resolvedEnableFeedback,
      excludeFromSemantics: resolvedExcludeFromSemantics,
      onFocusChange: onFocusChange,
      autofocus: resolvedAutofocus,
      focusNode: focusNode,
      canRequestFocus: resolvedCanRequestFocus,
      statesController: statesController,
      hoverDuration: hoverDuration,
      child: child,
    );
  }
}

/// Tom wrapper for [Draggable].
///
/// Drag source for drag-and-drop. Auth controls who can initiate drags.
class TomDraggable<T extends Object> extends TomInteractionBase {
  final Widget child;
  final Widget feedback;
  final T? data;
  final Axis? axis;
  final Widget? childWhenDragging;
  final Offset feedbackOffset;
  final DragAnchorStrategy dragAnchorStrategy;
  final Axis? affinity;
  final int? maxSimultaneousDrags;
  final VoidCallback? onDragStarted;
  final DragUpdateCallback? onDragUpdate;
  final DraggableCanceledCallback? onDraggableCanceled;
  final DragEndCallback? onDragEnd;
  final VoidCallback? onDragCompleted;
  final bool? ignoringFeedbackSemantics;
  final bool? ignoringFeedbackPointer;
  final bool? rootOverlay;
  final HitTestBehavior hitTestBehavior;
  final bool allowedButtonsFilter;

  const TomDraggable({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.child,
    required this.feedback,
    this.data,
    this.axis,
    this.childWhenDragging,
    this.feedbackOffset = Offset.zero,
    this.dragAnchorStrategy = childDragAnchorStrategy,
    this.affinity,
    this.maxSimultaneousDrags,
    this.onDragStarted,
    this.onDragUpdate,
    this.onDraggableCanceled,
    this.onDragEnd,
    this.onDragCompleted,
    this.ignoringFeedbackSemantics,
    this.ignoringFeedbackPointer,
    this.rootOverlay,
    this.hitTestBehavior = HitTestBehavior.deferToChild,
    this.allowedButtonsFilter = true,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedMaxSimultaneousDrags = maxSimultaneousDrags ??
      resolveIntOrNull(context, 'maxSimultaneousDrags');
    final resolvedIgnoringFeedbackSemantics = ignoringFeedbackSemantics ??
      resolveBoolOrNull(context, 'ignoringFeedbackSemantics') ?? true;
    final resolvedIgnoringFeedbackPointer = ignoringFeedbackPointer ??
      resolveBoolOrNull(context, 'ignoringFeedbackPointer') ?? true;
    final resolvedRootOverlay =
      rootOverlay ?? resolveBoolOrNull(context, 'rootOverlay') ?? false;

    return Draggable<T>(
      data: data,
      axis: axis,
      childWhenDragging: childWhenDragging,
      feedbackOffset: feedbackOffset,
      dragAnchorStrategy: dragAnchorStrategy,
      affinity: affinity,
      maxSimultaneousDrags: resolvedMaxSimultaneousDrags,
      onDragStarted: onDragStarted,
      onDragUpdate: onDragUpdate,
      onDraggableCanceled: onDraggableCanceled,
      onDragEnd: onDragEnd,
      onDragCompleted: onDragCompleted,
      ignoringFeedbackSemantics: resolvedIgnoringFeedbackSemantics,
      ignoringFeedbackPointer: resolvedIgnoringFeedbackPointer,
      rootOverlay: resolvedRootOverlay,
      hitTestBehavior: hitTestBehavior,
      feedback: feedback,
      child: child,
    );
  }
}

/// Tom wrapper for [DragTarget].
///
/// Drop target for drag-and-drop. Auth controls who can receive drops.
class TomDragTarget<T extends Object> extends TomInteractionBase {
  final DragTargetBuilder<T> builder;
  final DragTargetWillAcceptWithDetails<T>? onWillAcceptWithDetails;
  final DragTargetAcceptWithDetails<T>? onAcceptWithDetails;
  final DragTargetLeave<T>? onLeave;
  final DragTargetMove<T>? onMove;
  final HitTestBehavior? hitTestBehavior;

  const TomDragTarget({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.builder,
    this.onWillAcceptWithDetails,
    this.onAcceptWithDetails,
    this.onLeave,
    this.onMove,
    this.hitTestBehavior,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedHitTestBehavior = hitTestBehavior ??
        _resolveHitTestBehavior(resolveResourceOrNull(context, 'hitTestBehavior')) ??
        HitTestBehavior.translucent;

    return DragTarget<T>(
      builder: builder,
      onWillAcceptWithDetails: onWillAcceptWithDetails,
      onAcceptWithDetails: onAcceptWithDetails,
      onLeave: onLeave,
      onMove: onMove,
      hitTestBehavior: resolvedHitTestBehavior,
    );
  }
}

/// Tom wrapper for [LongPressDraggable].
///
/// Long-press-triggered drag. Auth controls long-press drag initiation.
class TomLongPressDraggable<T extends Object> extends TomInteractionBase {
  final Widget child;
  final Widget feedback;
  final T? data;
  final Axis? axis;
  final Widget? childWhenDragging;
  final Offset feedbackOffset;
  final DragAnchorStrategy dragAnchorStrategy;
  final int? maxSimultaneousDrags;
  final VoidCallback? onDragStarted;
  final DragUpdateCallback? onDragUpdate;
  final DraggableCanceledCallback? onDraggableCanceled;
  final DragEndCallback? onDragEnd;
  final VoidCallback? onDragCompleted;
  final bool? hapticFeedbackOnStart;
  final bool? ignoringFeedbackSemantics;
  final bool? ignoringFeedbackPointer;
  final Duration delay;

  const TomLongPressDraggable({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.child,
    required this.feedback,
    this.data,
    this.axis,
    this.childWhenDragging,
    this.feedbackOffset = Offset.zero,
    this.dragAnchorStrategy = childDragAnchorStrategy,
    this.maxSimultaneousDrags,
    this.onDragStarted,
    this.onDragUpdate,
    this.onDraggableCanceled,
    this.onDragEnd,
    this.onDragCompleted,
    this.hapticFeedbackOnStart,
    this.ignoringFeedbackSemantics,
    this.ignoringFeedbackPointer,
    this.delay = kLongPressTimeout,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedMaxSimultaneousDrags = maxSimultaneousDrags ??
      resolveIntOrNull(context, 'maxSimultaneousDrags');
    final resolvedHapticFeedbackOnStart = hapticFeedbackOnStart ??
      resolveBoolOrNull(context, 'hapticFeedbackOnStart') ?? true;
    final resolvedIgnoringFeedbackSemantics = ignoringFeedbackSemantics ??
      resolveBoolOrNull(context, 'ignoringFeedbackSemantics') ?? true;
    final resolvedIgnoringFeedbackPointer = ignoringFeedbackPointer ??
      resolveBoolOrNull(context, 'ignoringFeedbackPointer') ?? true;

    return LongPressDraggable<T>(
      data: data,
      axis: axis,
      childWhenDragging: childWhenDragging,
      feedbackOffset: feedbackOffset,
      dragAnchorStrategy: dragAnchorStrategy,
      maxSimultaneousDrags: resolvedMaxSimultaneousDrags,
      onDragStarted: onDragStarted,
      onDragUpdate: onDragUpdate,
      onDraggableCanceled: onDraggableCanceled,
      onDragEnd: onDragEnd,
      onDragCompleted: onDragCompleted,
      hapticFeedbackOnStart: resolvedHapticFeedbackOnStart,
      ignoringFeedbackSemantics: resolvedIgnoringFeedbackSemantics,
      ignoringFeedbackPointer: resolvedIgnoringFeedbackPointer,
      delay: delay,
      feedback: feedback,
      child: child,
    );
  }
}

/// Tom wrapper for [AbsorbPointer].
///
/// Absorbs (blocks) pointer events. Auth can add/remove pointer blocking based on permissions.
class TomAbsorbPointer extends TomInteractionBase {
  final bool? absorbing;
  final Widget? child;

  const TomAbsorbPointer({
    super.key,
    super.tomId,
    super.tomGroup,
    this.absorbing,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedAbsorbing =
        absorbing ?? resolveBoolOrNull(context, 'absorbing') ?? true;

    return AbsorbPointer(
      absorbing: resolvedAbsorbing,
      child: child,
    );
  }
}

/// Tom wrapper for [IgnorePointer].
///
/// Ignores pointer events (pass-through). Auth on pointer passthrough control.
class TomIgnorePointer extends TomInteractionBase {
  final bool? ignoring;
  final Widget? child;

  const TomIgnorePointer({
    super.key,
    super.tomId,
    super.tomGroup,
    this.ignoring,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedIgnoring =
        ignoring ?? resolveBoolOrNull(context, 'ignoring') ?? true;

    return IgnorePointer(
      ignoring: resolvedIgnoring,
      child: child,
    );
  }
}

/// Tom wrapper for [MouseRegion].
///
/// Mouse hover/exit/cursor tracking. Auth on hover-tracked content region.
class TomMouseRegion extends TomInteractionBase {
  final PointerEnterEventListener? onEnter;
  final PointerExitEventListener? onExit;
  final PointerHoverEventListener? onHover;
  final MouseCursor cursor;
  final bool? opaque;
  final HitTestBehavior? hitTestBehavior;
  final Widget? child;

  const TomMouseRegion({
    super.key,
    super.tomId,
    super.tomGroup,
    this.onEnter,
    this.onExit,
    this.onHover,
    this.cursor = MouseCursor.defer,
    this.opaque,
    this.hitTestBehavior,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedOpaque = opaque ?? resolveBoolOrNull(context, 'opaque') ?? true;
    final resolvedHitTestBehavior = hitTestBehavior ??
        _resolveHitTestBehavior(resolveResourceOrNull(context, 'hitTestBehavior'));

    return MouseRegion(
      onEnter: onEnter,
      onExit: onExit,
      onHover: onHover,
      cursor: cursor,
      opaque: resolvedOpaque,
      hitTestBehavior: resolvedHitTestBehavior,
      child: child,
    );
  }
}

HitTestBehavior? _resolveHitTestBehavior(String? value) {
  switch (value?.toLowerCase()) {
    case 'defertochild':
      return HitTestBehavior.deferToChild;
    case 'opaque':
      return HitTestBehavior.opaque;
    case 'translucent':
      return HitTestBehavior.translucent;
    default:
      return null;
  }
}
