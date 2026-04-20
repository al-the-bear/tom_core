import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_style_resolvers.dart';

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

  // Pre-resolved resource values
  late final bool _resolvedExcludeFromSemantics;
  late final bool _resolvedTrackpadScrollCausesScale;
  late final Offset _resolvedTrackpadScrollToScaleFactor;

  TomGestureDetector({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.child,
    GestureTapCallback? onTap,
    GestureTapCallback? onTapCancel,
    GestureTapDownCallback? onTapDown,
    GestureTapUpCallback? onTapUp,
    GestureTapCallback? onSecondaryTap,
    GestureTapDownCallback? onSecondaryTapDown,
    GestureTapUpCallback? onSecondaryTapUp,
    GestureTapCallback? onSecondaryTapCancel,
    GestureTapDownCallback? onTertiaryTapDown,
    GestureTapUpCallback? onTertiaryTapUp,
    GestureTapCallback? onTertiaryTapCancel,
    GestureDoubleTapCallback? onDoubleTap,
    GestureLongPressCallback? onLongPress,
    GestureLongPressStartCallback? onLongPressStart,
    GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate,
    GestureLongPressUpCallback? onLongPressUp,
    GestureLongPressEndCallback? onLongPressEnd,
    GestureDragDownCallback? onVerticalDragDown,
    GestureDragStartCallback? onVerticalDragStart,
    GestureDragUpdateCallback? onVerticalDragUpdate,
    GestureDragEndCallback? onVerticalDragEnd,
    GestureDragCancelCallback? onVerticalDragCancel,
    GestureDragDownCallback? onHorizontalDragDown,
    GestureDragStartCallback? onHorizontalDragStart,
    GestureDragUpdateCallback? onHorizontalDragUpdate,
    GestureDragEndCallback? onHorizontalDragEnd,
    GestureDragCancelCallback? onHorizontalDragCancel,
    GestureDragDownCallback? onPanDown,
    GestureDragStartCallback? onPanStart,
    GestureDragUpdateCallback? onPanUpdate,
    GestureDragEndCallback? onPanEnd,
    GestureDragCancelCallback? onPanCancel,
    GestureScaleStartCallback? onScaleStart,
    GestureScaleUpdateCallback? onScaleUpdate,
    GestureScaleEndCallback? onScaleEnd,
    GestureForcePressStartCallback? onForcePressStart,
    GestureForcePressPeakCallback? onForcePressPeak,
    GestureForcePressUpdateCallback? onForcePressUpdate,
    GestureForcePressEndCallback? onForcePressEnd,
    this.behavior,
    this.excludeFromSemantics,
    this.dragStartBehavior = DragStartBehavior.start,
    this.supportedDevices,
    this.trackpadScrollCausesScale,
    this.trackpadScrollToScaleFactor = kDefaultTrackpadScrollToScaleFactor,
  })  : onTap = InScopeBuilder(scope: scope).wrap0n(onTap),
        onTapCancel = InScopeBuilder(scope: scope).wrap0n(onTapCancel),
        onTapDown = InScopeBuilder(scope: scope).wrap1n(onTapDown),
        onTapUp = InScopeBuilder(scope: scope).wrap1n(onTapUp),
        onSecondaryTap = InScopeBuilder(scope: scope).wrap0n(onSecondaryTap),
        onSecondaryTapDown = InScopeBuilder(scope: scope).wrap1n(onSecondaryTapDown),
        onSecondaryTapUp = InScopeBuilder(scope: scope).wrap1n(onSecondaryTapUp),
        onSecondaryTapCancel = InScopeBuilder(scope: scope).wrap0n(onSecondaryTapCancel),
        onTertiaryTapDown = InScopeBuilder(scope: scope).wrap1n(onTertiaryTapDown),
        onTertiaryTapUp = InScopeBuilder(scope: scope).wrap1n(onTertiaryTapUp),
        onTertiaryTapCancel = InScopeBuilder(scope: scope).wrap0n(onTertiaryTapCancel),
        onDoubleTap = InScopeBuilder(scope: scope).wrap0n(onDoubleTap),
        onLongPress = InScopeBuilder(scope: scope).wrap0n(onLongPress),
        onLongPressStart = InScopeBuilder(scope: scope).wrap1n(onLongPressStart),
        onLongPressMoveUpdate = InScopeBuilder(scope: scope).wrap1n(onLongPressMoveUpdate),
        onLongPressUp = InScopeBuilder(scope: scope).wrap0n(onLongPressUp),
        onLongPressEnd = InScopeBuilder(scope: scope).wrap1n(onLongPressEnd),
        onVerticalDragDown = InScopeBuilder(scope: scope).wrap1n(onVerticalDragDown),
        onVerticalDragStart = InScopeBuilder(scope: scope).wrap1n(onVerticalDragStart),
        onVerticalDragUpdate = InScopeBuilder(scope: scope).wrap1n(onVerticalDragUpdate),
        onVerticalDragEnd = InScopeBuilder(scope: scope).wrap1n(onVerticalDragEnd),
        onVerticalDragCancel = InScopeBuilder(scope: scope).wrap0n(onVerticalDragCancel),
        onHorizontalDragDown = InScopeBuilder(scope: scope).wrap1n(onHorizontalDragDown),
        onHorizontalDragStart = InScopeBuilder(scope: scope).wrap1n(onHorizontalDragStart),
        onHorizontalDragUpdate = InScopeBuilder(scope: scope).wrap1n(onHorizontalDragUpdate),
        onHorizontalDragEnd = InScopeBuilder(scope: scope).wrap1n(onHorizontalDragEnd),
        onHorizontalDragCancel = InScopeBuilder(scope: scope).wrap0n(onHorizontalDragCancel),
        onPanDown = InScopeBuilder(scope: scope).wrap1n(onPanDown),
        onPanStart = InScopeBuilder(scope: scope).wrap1n(onPanStart),
        onPanUpdate = InScopeBuilder(scope: scope).wrap1n(onPanUpdate),
        onPanEnd = InScopeBuilder(scope: scope).wrap1n(onPanEnd),
        onPanCancel = InScopeBuilder(scope: scope).wrap0n(onPanCancel),
        onScaleStart = InScopeBuilder(scope: scope).wrap1n(onScaleStart),
        onScaleUpdate = InScopeBuilder(scope: scope).wrap1n(onScaleUpdate),
        onScaleEnd = InScopeBuilder(scope: scope).wrap1n(onScaleEnd),
        onForcePressStart = InScopeBuilder(scope: scope).wrap1n(onForcePressStart),
        onForcePressPeak = InScopeBuilder(scope: scope).wrap1n(onForcePressPeak),
        onForcePressUpdate = InScopeBuilder(scope: scope).wrap1n(onForcePressUpdate),
        onForcePressEnd = InScopeBuilder(scope: scope).wrap1n(onForcePressEnd) {
    _resolvedExcludeFromSemantics = excludeFromSemantics ?? TomCtr.boolVal(basePath, 'excludeFromSemantics') ?? false;
    _resolvedTrackpadScrollCausesScale = trackpadScrollCausesScale ?? TomCtr.boolVal(basePath, 'trackpadScrollCausesScale') ?? false;
    _resolvedTrackpadScrollToScaleFactor = _resolveOffset('trackpadScrollToScaleFactor') ?? trackpadScrollToScaleFactor;
  }

  @override
  Widget buildContent(BuildContext context) {
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
      excludeFromSemantics: _resolvedExcludeFromSemantics,
      dragStartBehavior: dragStartBehavior,
      supportedDevices: supportedDevices,
      trackpadScrollCausesScale: _resolvedTrackpadScrollCausesScale,
      trackpadScrollToScaleFactor: _resolvedTrackpadScrollToScaleFactor,
      child: child,
    );
  }

  Offset? _resolveOffset(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveOffset(basePath!, suffix);
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

  // Pre-resolved resource values
  late final Color? _resolvedFocusColor;
  late final Color? _resolvedHoverColor;
  late final Color? _resolvedHighlightColor;
  late final Color? _resolvedSplashColor;
  late final double? _resolvedRadius;
  late final BorderRadius? _resolvedBorderRadius;
  late final ShapeBorder? _resolvedCustomBorder;
  late final bool _resolvedEnableFeedback;
  late final bool _resolvedExcludeFromSemantics;
  late final bool _resolvedCanRequestFocus;
  late final bool _resolvedAutofocus;

  TomInkWell({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.child,
    GestureTapCallback? onTap,
    GestureTapCallback? onDoubleTap,
    GestureLongPressCallback? onLongPress,
    GestureTapDownCallback? onTapDown,
    GestureTapUpCallback? onTapUp,
    GestureTapCallback? onTapCancel,
    GestureTapCallback? onSecondaryTap,
    GestureTapUpCallback? onSecondaryTapUp,
    GestureTapDownCallback? onSecondaryTapDown,
    GestureTapCallback? onSecondaryTapCancel,
    ValueChanged<bool>? onHighlightChanged,
    ValueChanged<bool>? onHover,
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
    ValueChanged<bool>? onFocusChange,
    this.autofocus = false,
    this.statesController,
    this.hoverDuration,
  })  : onTap = InScopeBuilder(scope: scope).wrap0n(onTap),
        onDoubleTap = InScopeBuilder(scope: scope).wrap0n(onDoubleTap),
        onLongPress = InScopeBuilder(scope: scope).wrap0n(onLongPress),
        onTapDown = InScopeBuilder(scope: scope).wrap1n(onTapDown),
        onTapUp = InScopeBuilder(scope: scope).wrap1n(onTapUp),
        onTapCancel = InScopeBuilder(scope: scope).wrap0n(onTapCancel),
        onSecondaryTap = InScopeBuilder(scope: scope).wrap0n(onSecondaryTap),
        onSecondaryTapUp = InScopeBuilder(scope: scope).wrap1n(onSecondaryTapUp),
        onSecondaryTapDown = InScopeBuilder(scope: scope).wrap1n(onSecondaryTapDown),
        onSecondaryTapCancel = InScopeBuilder(scope: scope).wrap0n(onSecondaryTapCancel),
        onHighlightChanged = InScopeBuilder(scope: scope).wrap1n(onHighlightChanged),
        onHover = InScopeBuilder(scope: scope).wrap1n(onHover),
        onFocusChange = InScopeBuilder(scope: scope).wrap1n(onFocusChange) {
    _resolvedFocusColor = focusColor ?? TomCtr.color(basePath, 'focusColor');
    _resolvedHoverColor = hoverColor ?? TomCtr.color(basePath, 'hoverColor');
    _resolvedHighlightColor = highlightColor ?? TomCtr.color(basePath, 'highlightColor');
    _resolvedSplashColor = splashColor ?? TomCtr.color(basePath, 'splashColor');
    _resolvedRadius = radius ?? TomCtr.doubleVal(basePath, 'radius');
    _resolvedBorderRadius = borderRadius ?? _resolveBorderRadius('borderRadius');
    _resolvedCustomBorder = customBorder ?? _resolveShapeBorder('customBorder');
    _resolvedEnableFeedback = enableFeedback ?? TomCtr.boolVal(basePath, 'enableFeedback') ?? true;
    _resolvedExcludeFromSemantics = TomCtr.boolVal(basePath, 'excludeFromSemantics') ?? excludeFromSemantics;
    _resolvedCanRequestFocus = TomCtr.boolVal(basePath, 'canRequestFocus') ?? canRequestFocus;
    _resolvedAutofocus = TomCtr.boolVal(basePath, 'autofocus') ?? autofocus;
  }

  @override
  Widget buildContent(BuildContext context) {
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
      focusColor: _resolvedFocusColor,
      hoverColor: _resolvedHoverColor,
      highlightColor: _resolvedHighlightColor,
      overlayColor: overlayColor,
      splashColor: _resolvedSplashColor,
      splashFactory: splashFactory,
      radius: _resolvedRadius,
      borderRadius: _resolvedBorderRadius,
      customBorder: _resolvedCustomBorder,
      enableFeedback: _resolvedEnableFeedback,
      excludeFromSemantics: _resolvedExcludeFromSemantics,
      focusNode: focusNode,
      canRequestFocus: _resolvedCanRequestFocus,
      onFocusChange: onFocusChange,
      autofocus: _resolvedAutofocus,
      statesController: statesController,
      hoverDuration: hoverDuration,
      child: child,
    );
  }

  BorderRadius? _resolveBorderRadius(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderRadius(basePath!, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
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

  // Pre-resolved resource values
  late final bool _resolvedContainedInkWell;
  late final double? _resolvedRadius;
  late final Color? _resolvedFocusColor;
  late final Color? _resolvedHoverColor;
  late final Color? _resolvedHighlightColor;
  late final Color? _resolvedSplashColor;
  late final bool _resolvedEnableFeedback;
  late final bool _resolvedExcludeFromSemantics;
  late final bool _resolvedAutofocus;
  late final bool _resolvedCanRequestFocus;
  late final BorderRadius? _resolvedBorderRadius;
  late final ShapeBorder? _resolvedCustomBorder;

  TomInkResponse({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.child,
    GestureTapCallback? onTap,
    GestureTapDownCallback? onTapDown,
    GestureTapUpCallback? onTapUp,
    GestureTapCallback? onTapCancel,
    GestureTapCallback? onDoubleTap,
    GestureLongPressCallback? onLongPress,
    ValueChanged<bool>? onHighlightChanged,
    ValueChanged<bool>? onHover,
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
    ValueChanged<bool>? onFocusChange,
    this.autofocus,
    this.focusNode,
    this.canRequestFocus,
    this.statesController,
    this.hoverDuration,
  })  : onTap = InScopeBuilder(scope: scope).wrap0n(onTap),
        onTapDown = InScopeBuilder(scope: scope).wrap1n(onTapDown),
        onTapUp = InScopeBuilder(scope: scope).wrap1n(onTapUp),
        onTapCancel = InScopeBuilder(scope: scope).wrap0n(onTapCancel),
        onDoubleTap = InScopeBuilder(scope: scope).wrap0n(onDoubleTap),
        onLongPress = InScopeBuilder(scope: scope).wrap0n(onLongPress),
        onHighlightChanged = InScopeBuilder(scope: scope).wrap1n(onHighlightChanged),
        onHover = InScopeBuilder(scope: scope).wrap1n(onHover),
        onFocusChange = InScopeBuilder(scope: scope).wrap1n(onFocusChange) {
    _resolvedContainedInkWell = containedInkWell ?? TomCtr.boolVal(basePath, 'containedInkWell') ?? false;
    _resolvedRadius = radius ?? TomCtr.doubleVal(basePath, 'radius');
    _resolvedFocusColor = focusColor ?? TomCtr.color(basePath, 'focusColor');
    _resolvedHoverColor = hoverColor ?? TomCtr.color(basePath, 'hoverColor');
    _resolvedHighlightColor = highlightColor ?? TomCtr.color(basePath, 'highlightColor');
    _resolvedSplashColor = splashColor ?? TomCtr.color(basePath, 'splashColor');
    _resolvedEnableFeedback = enableFeedback ?? TomCtr.boolVal(basePath, 'enableFeedback') ?? true;
    _resolvedExcludeFromSemantics = excludeFromSemantics ?? TomCtr.boolVal(basePath, 'excludeFromSemantics') ?? false;
    _resolvedAutofocus = autofocus ?? TomCtr.boolVal(basePath, 'autofocus') ?? false;
    _resolvedCanRequestFocus = canRequestFocus ?? TomCtr.boolVal(basePath, 'canRequestFocus') ?? true;
    _resolvedBorderRadius = borderRadius ?? _resolveBorderRadius('borderRadius');
    _resolvedCustomBorder = customBorder ?? _resolveShapeBorder('customBorder');
  }

  @override
  Widget buildContent(BuildContext context) {
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
      containedInkWell: _resolvedContainedInkWell,
      highlightShape: highlightShape,
      radius: _resolvedRadius,
      borderRadius: _resolvedBorderRadius,
      customBorder: _resolvedCustomBorder,
      focusColor: _resolvedFocusColor,
      hoverColor: _resolvedHoverColor,
      highlightColor: _resolvedHighlightColor,
      overlayColor: overlayColor,
      splashColor: _resolvedSplashColor,
      splashFactory: splashFactory,
      enableFeedback: _resolvedEnableFeedback,
      excludeFromSemantics: _resolvedExcludeFromSemantics,
      onFocusChange: onFocusChange,
      autofocus: _resolvedAutofocus,
      focusNode: focusNode,
      canRequestFocus: _resolvedCanRequestFocus,
      statesController: statesController,
      hoverDuration: hoverDuration,
      child: child,
    );
  }

  BorderRadius? _resolveBorderRadius(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderRadius(basePath!, suffix);
  }

  ShapeBorder? _resolveShapeBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveShapeBorder(basePath!, suffix);
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

  // Pre-resolved resource values
  late final int? _resolvedMaxSimultaneousDrags;
  late final bool _resolvedIgnoringFeedbackSemantics;
  late final bool _resolvedIgnoringFeedbackPointer;
  late final bool _resolvedRootOverlay;
  late final Offset _resolvedFeedbackOffset;

  TomDraggable({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.child,
    required this.feedback,
    this.data,
    this.axis,
    this.childWhenDragging,
    this.feedbackOffset = Offset.zero,
    this.dragAnchorStrategy = childDragAnchorStrategy,
    this.affinity,
    this.maxSimultaneousDrags,
    VoidCallback? onDragStarted,
    DragUpdateCallback? onDragUpdate,
    DraggableCanceledCallback? onDraggableCanceled,
    DragEndCallback? onDragEnd,
    VoidCallback? onDragCompleted,
    this.ignoringFeedbackSemantics,
    this.ignoringFeedbackPointer,
    this.rootOverlay,
    this.hitTestBehavior = HitTestBehavior.deferToChild,
    this.allowedButtonsFilter = true,
  })  : onDragStarted = InScopeBuilder(scope: scope).wrap0n(onDragStarted),
        onDragUpdate = InScopeBuilder(scope: scope).wrap1n(onDragUpdate),
        onDraggableCanceled = InScopeBuilder(scope: scope).wrap2n(onDraggableCanceled),
        onDragEnd = InScopeBuilder(scope: scope).wrap1n(onDragEnd),
        onDragCompleted = InScopeBuilder(scope: scope).wrap0n(onDragCompleted) {
    _resolvedMaxSimultaneousDrags = maxSimultaneousDrags ?? TomCtr.intVal(basePath, 'maxSimultaneousDrags');
    _resolvedIgnoringFeedbackSemantics = ignoringFeedbackSemantics ?? TomCtr.boolVal(basePath, 'ignoringFeedbackSemantics') ?? true;
    _resolvedIgnoringFeedbackPointer = ignoringFeedbackPointer ?? TomCtr.boolVal(basePath, 'ignoringFeedbackPointer') ?? true;
    _resolvedRootOverlay = rootOverlay ?? TomCtr.boolVal(basePath, 'rootOverlay') ?? false;
    _resolvedFeedbackOffset = _resolveOffset('feedbackOffset') ?? feedbackOffset;
  }

  @override
  Widget buildContent(BuildContext context) {
    return Draggable<T>(
      data: data,
      axis: axis,
      childWhenDragging: childWhenDragging,
      feedbackOffset: _resolvedFeedbackOffset,
      dragAnchorStrategy: dragAnchorStrategy,
      affinity: affinity,
      maxSimultaneousDrags: _resolvedMaxSimultaneousDrags,
      onDragStarted: onDragStarted,
      onDragUpdate: onDragUpdate,
      onDraggableCanceled: onDraggableCanceled,
      onDragEnd: onDragEnd,
      onDragCompleted: onDragCompleted,
      ignoringFeedbackSemantics: _resolvedIgnoringFeedbackSemantics,
      ignoringFeedbackPointer: _resolvedIgnoringFeedbackPointer,
      rootOverlay: _resolvedRootOverlay,
      hitTestBehavior: hitTestBehavior,
      feedback: feedback,
      child: child,
    );
  }

  Offset? _resolveOffset(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveOffset(basePath!, suffix);
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

  // Pre-resolved resource values
  late final HitTestBehavior _resolvedHitTestBehavior;

  TomDragTarget({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required DragTargetBuilder<T> builder,
    DragTargetWillAcceptWithDetails<T>? onWillAcceptWithDetails,
    DragTargetAcceptWithDetails<T>? onAcceptWithDetails,
    DragTargetLeave<T>? onLeave,
    DragTargetMove<T>? onMove,
    this.hitTestBehavior,
  }) : builder = InScopeBuilder(scope: scope).wrap3(builder),
       onWillAcceptWithDetails = InScopeBuilder(scope: scope).wrap1n(onWillAcceptWithDetails),
       onAcceptWithDetails = InScopeBuilder(scope: scope).wrap1n(onAcceptWithDetails),
       onLeave = InScopeBuilder(scope: scope).wrap1n(onLeave),
       onMove = InScopeBuilder(scope: scope).wrap1n(onMove) {
    _resolvedHitTestBehavior = hitTestBehavior ?? _resolveHitTestBehavior(TomCtr.textOrNull(basePath, 'hitTestBehavior')) ?? HitTestBehavior.translucent;
  }

  @override
  Widget buildContent(BuildContext context) {
    return DragTarget<T>(
      builder: builder,
      onWillAcceptWithDetails: onWillAcceptWithDetails,
      onAcceptWithDetails: onAcceptWithDetails,
      onLeave: onLeave,
      onMove: onMove,
      hitTestBehavior: _resolvedHitTestBehavior,
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

  // Pre-resolved resource values
  late final int? _resolvedMaxSimultaneousDrags;
  late final bool _resolvedHapticFeedbackOnStart;
  late final bool _resolvedIgnoringFeedbackSemantics;
  late final bool _resolvedIgnoringFeedbackPointer;

  TomLongPressDraggable({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.child,
    required this.feedback,
    this.data,
    this.axis,
    this.childWhenDragging,
    this.feedbackOffset = Offset.zero,
    this.dragAnchorStrategy = childDragAnchorStrategy,
    this.maxSimultaneousDrags,
    VoidCallback? onDragStarted,
    DragUpdateCallback? onDragUpdate,
    DraggableCanceledCallback? onDraggableCanceled,
    DragEndCallback? onDragEnd,
    VoidCallback? onDragCompleted,
    this.hapticFeedbackOnStart,
    this.ignoringFeedbackSemantics,
    this.ignoringFeedbackPointer,
    this.delay = kLongPressTimeout,
  })  : onDragStarted = InScopeBuilder(scope: scope).wrap0n(onDragStarted),
        onDragUpdate = InScopeBuilder(scope: scope).wrap1n(onDragUpdate),
        onDraggableCanceled = InScopeBuilder(scope: scope).wrap2n(onDraggableCanceled),
        onDragEnd = InScopeBuilder(scope: scope).wrap1n(onDragEnd),
        onDragCompleted = InScopeBuilder(scope: scope).wrap0n(onDragCompleted) {
    _resolvedMaxSimultaneousDrags = maxSimultaneousDrags ?? TomCtr.intVal(basePath, 'maxSimultaneousDrags');
    _resolvedHapticFeedbackOnStart = hapticFeedbackOnStart ?? TomCtr.boolVal(basePath, 'hapticFeedbackOnStart') ?? true;
    _resolvedIgnoringFeedbackSemantics = ignoringFeedbackSemantics ?? TomCtr.boolVal(basePath, 'ignoringFeedbackSemantics') ?? true;
    _resolvedIgnoringFeedbackPointer = ignoringFeedbackPointer ?? TomCtr.boolVal(basePath, 'ignoringFeedbackPointer') ?? true;
  }

  @override
  Widget buildContent(BuildContext context) {
    return LongPressDraggable<T>(
      data: data,
      axis: axis,
      childWhenDragging: childWhenDragging,
      feedbackOffset: feedbackOffset,
      dragAnchorStrategy: dragAnchorStrategy,
      maxSimultaneousDrags: _resolvedMaxSimultaneousDrags,
      onDragStarted: onDragStarted,
      onDragUpdate: onDragUpdate,
      onDraggableCanceled: onDraggableCanceled,
      onDragEnd: onDragEnd,
      onDragCompleted: onDragCompleted,
      hapticFeedbackOnStart: _resolvedHapticFeedbackOnStart,
      ignoringFeedbackSemantics: _resolvedIgnoringFeedbackSemantics,
      ignoringFeedbackPointer: _resolvedIgnoringFeedbackPointer,
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

  // Pre-resolved resource values
  late final bool _resolvedAbsorbing;

  TomAbsorbPointer({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.absorbing,
    this.child,
  }) {
    _resolvedAbsorbing = absorbing ?? TomCtr.boolVal(basePath, 'absorbing') ?? true;
  }

  @override
  Widget buildContent(BuildContext context) {
    return AbsorbPointer(
      absorbing: _resolvedAbsorbing,
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

  // Pre-resolved resource values
  late final bool _resolvedIgnoring;

  TomIgnorePointer({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.ignoring,
    this.child,
  }) {
    _resolvedIgnoring = ignoring ?? TomCtr.boolVal(basePath, 'ignoring') ?? true;
  }

  @override
  Widget buildContent(BuildContext context) {
    return IgnorePointer(
      ignoring: _resolvedIgnoring,
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

  // Pre-resolved resource values
  late final bool _resolvedOpaque;
  late final HitTestBehavior? _resolvedHitTestBehavior;

  TomMouseRegion({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    PointerEnterEventListener? onEnter,
    PointerExitEventListener? onExit,
    PointerHoverEventListener? onHover,
    this.cursor = MouseCursor.defer,
    this.opaque,
    this.hitTestBehavior,
    this.child,
  })  : onEnter = InScopeBuilder(scope: scope).wrap1n(onEnter),
        onExit = InScopeBuilder(scope: scope).wrap1n(onExit),
        onHover = InScopeBuilder(scope: scope).wrap1n(onHover) {
    _resolvedOpaque = opaque ?? TomCtr.boolVal(basePath, 'opaque') ?? true;
    _resolvedHitTestBehavior = hitTestBehavior ?? _resolveHitTestBehavior(TomCtr.textOrNull(basePath, 'hitTestBehavior'));
  }

  @override
  Widget buildContent(BuildContext context) {
    return MouseRegion(
      onEnter: onEnter,
      onExit: onExit,
      onHover: onHover,
      cursor: cursor,
      opaque: _resolvedOpaque,
      hitTestBehavior: _resolvedHitTestBehavior,
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
