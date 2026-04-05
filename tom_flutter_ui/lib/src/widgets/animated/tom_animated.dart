import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../groups/tom_ui_group.dart';
import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_style_resolvers.dart';

// =============================================================================
// Section II: Animated Widgets
// =============================================================================

/// Tom wrapper for [AnimatedAlign].
///
/// Animates alignment changes. Auth on animated content region.
class TomAnimatedAlign extends TomAnimatedBase {
  final AlignmentGeometry? alignment;
  final Widget? child;
  final double? heightFactor;
  final double? widthFactor;
  final Duration? duration;
  final Curve curve;
  final VoidCallback? onEnd;

  const TomAnimatedAlign({
    super.key,
    super.tomId,
    super.tomGroup,
    this.alignment,
    this.child,
    this.heightFactor,
    this.widthFactor,
    this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedHeightFactor =
        heightFactor ?? resolveDoubleOrNull('heightFactor');
    final resolvedWidthFactor =
        widthFactor ?? resolveDoubleOrNull('widthFactor');

    return AnimatedAlign(
      alignment: alignment ?? _resolveAlignment('alignment') ?? Alignment.center,
      child: child,
      heightFactor: resolvedHeightFactor,
      widthFactor: resolvedWidthFactor,
      duration: duration ?? Duration(milliseconds: resolveIntOrNull('duration') ?? 300),
      curve: curve,
      onEnd: onEnd,
    );
  }
  AlignmentGeometry? _resolveAlignment(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath, suffix);
  }}

/// Tom wrapper for [AnimatedBuilder].
///
/// Rebuilds on Listenable changes. Auth on rebuilt content.
///
/// Accepts either [animation] (Flutter API) or [listenable] parameter.
class TomAnimatedBuilder extends TomAnimatedBase {
  final Listenable? _listenable;
  final Listenable? _animation;
  final TransitionBuilder builder;
  final Widget? child;

  /// Creates TomAnimatedBuilder with [listenable] parameter.
  const TomAnimatedBuilder({
    super.key,
    super.tomId,
    super.tomGroup,
    Listenable? listenable,
    Listenable? animation,
    required this.builder,
    this.child,
  })  : _listenable = listenable,
        _animation = animation;

  Listenable get effectiveListenable {
    final anim = _animation ?? _listenable;
    assert(anim != null, 'Either animation or listenable must be provided');
    return anim!;
  }

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedBuilder(
      animation: effectiveListenable,
      builder: builder,
      child: child,
    );
  }
}

/// Tom wrapper for [AnimatedContainer].
///
/// Animates Container property changes. Auth on animated content region.
class TomAnimatedContainer extends TomAnimatedBase {
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Decoration? decoration;
  final Decoration? foregroundDecoration;
  final BoxConstraints? constraints;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;
  final Widget? child;
  final Clip clipBehavior;
  final Duration? duration;
  final Curve curve;
  final VoidCallback? onEnd;

  const TomAnimatedContainer({
    super.key,
    super.tomId,
    super.tomGroup,
    this.alignment,
    this.padding,
    this.color,
    this.decoration,
    this.foregroundDecoration,
    this.constraints,
    this.width,
    this.height,
    this.margin,
    this.transform,
    this.transformAlignment,
    this.child,
    this.clipBehavior = Clip.none,
    this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedColor =
        color ?? resolveColorOrNull('color');
    final resolvedWidth =
        width ?? resolveDoubleOrNull('width');
    final resolvedHeight =
        height ?? resolveDoubleOrNull('height');
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding');
    final resolvedMargin =
        margin ?? resolveEdgeInsetsOrNull('margin');

    return AnimatedContainer(
      alignment: alignment ?? _resolveAlignment('alignment'),
      padding: resolvedPadding,
      color: resolvedColor,
      decoration: decoration ?? _resolveDecoration('decoration'),
      foregroundDecoration: foregroundDecoration ?? _resolveDecoration('foregroundDecoration'),
      constraints: constraints ?? _resolveBoxConstraints('constraints'),
      width: resolvedWidth,
      height: resolvedHeight,
      margin: resolvedMargin,
      transform: transform,
      transformAlignment: transformAlignment ?? _resolveAlignment('transformAlignment'),
      clipBehavior: clipBehavior,
      duration: duration ?? Duration(milliseconds: resolveIntOrNull('duration') ?? 300),
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath, suffix);
  }

  Decoration? _resolveDecoration(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveDecoration(basePath, suffix);
  }

  BoxConstraints? _resolveBoxConstraints(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBoxConstraints(basePath, suffix);
  }
}

/// Tom wrapper for [AnimatedCrossFade].
///
/// Cross-fades between two children. Auth on both fade children.
class TomAnimatedCrossFade extends TomAnimatedBase {
  final Widget firstChild;
  final Widget secondChild;
  final CrossFadeState crossFadeState;
  final Duration? duration;
  final Duration? reverseDuration;
  final Curve firstCurve;
  final Curve secondCurve;
  final Curve sizeCurve;
  final AlignmentGeometry? alignment;
  final AnimatedCrossFadeBuilder layoutBuilder;
  final bool? excludeBottomFocus;

  const TomAnimatedCrossFade({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.firstChild,
    required this.secondChild,
    required this.crossFadeState,
    this.duration,
    this.reverseDuration,
    this.firstCurve = Curves.linear,
    this.secondCurve = Curves.linear,
    this.sizeCurve = Curves.linear,
    this.alignment,
    this.layoutBuilder = AnimatedCrossFade.defaultLayoutBuilder,
    this.excludeBottomFocus,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedExcludeBottomFocus = excludeBottomFocus ??
        resolveBoolOrNull('excludeBottomFocus') ?? true;

    return AnimatedCrossFade(
      firstChild: firstChild,
      secondChild: secondChild,
      crossFadeState: crossFadeState,
      duration: duration ?? Duration(milliseconds: resolveIntOrNull('duration') ?? 300),
      reverseDuration: reverseDuration,
      firstCurve: firstCurve,
      secondCurve: secondCurve,
      sizeCurve: sizeCurve,
      alignment: alignment ?? _resolveAlignment('alignment') ?? Alignment.topCenter,
      layoutBuilder: layoutBuilder,
      excludeBottomFocus: resolvedExcludeBottomFocus,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath, suffix);
  }
}

/// Tom wrapper for [AnimatedDefaultTextStyle].
///
/// Animates text style changes. Auth on styled content.
class TomAnimatedDefaultTextStyle extends TomAnimatedBase {
  final Widget child;
  final TextStyle style;
  final TextAlign? textAlign;
  final bool? softWrap;
  final TextOverflow overflow;
  final int? maxLines;
  final TextWidthBasis textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Duration? duration;
  final Curve curve;
  final VoidCallback? onEnd;

  const TomAnimatedDefaultTextStyle({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.child,
    required this.style,
    this.textAlign,
    this.softWrap,
    this.overflow = TextOverflow.clip,
    this.maxLines,
    this.textWidthBasis = TextWidthBasis.parent,
    this.textHeightBehavior,
    this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedStyle = _resolveTextStyle('style');
    final resolvedSoftWrap =
        softWrap ?? resolveBoolOrNull('softWrap') ?? true;
    final resolvedMaxLines =
        maxLines ?? resolveIntOrNull('maxLines');

    return AnimatedDefaultTextStyle(
      style: resolvedStyle ?? style,
      textAlign: textAlign,
      softWrap: resolvedSoftWrap,
      overflow: overflow,
      maxLines: resolvedMaxLines,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      duration: duration ?? Duration(milliseconds: resolveIntOrNull('duration') ?? 300),
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
  }
}

/// Tom wrapper for [AnimatedFractionallySizedBox].
///
/// Animates fractional sizing. Auth on sized content.
class TomAnimatedFractionallySizedBox extends TomAnimatedBase {
  final AlignmentGeometry? alignment;
  final double? widthFactor;
  final double? heightFactor;
  final Widget? child;
  final Duration? duration;
  final Curve curve;
  final VoidCallback? onEnd;

  const TomAnimatedFractionallySizedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    this.alignment,
    this.widthFactor,
    this.heightFactor,
    this.child,
    this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedWidthFactor =
        widthFactor ?? resolveDoubleOrNull('widthFactor');
    final resolvedHeightFactor =
        heightFactor ?? resolveDoubleOrNull('heightFactor');

    return AnimatedFractionallySizedBox(
      alignment: alignment ?? _resolveAlignment('alignment') ?? Alignment.center,
      widthFactor: resolvedWidthFactor,
      heightFactor: resolvedHeightFactor,
      duration: duration ?? Duration(milliseconds: resolveIntOrNull('duration') ?? 300),
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath, suffix);
  }
}

/// Tom wrapper for [AnimatedOpacity].
///
/// Animates opacity changes. Auth on content being faded.
class TomAnimatedOpacity extends TomAnimatedBase {
  final Widget? child;
  final double? opacity;
  final Duration? duration;
  final Curve curve;
  final VoidCallback? onEnd;
  final bool? alwaysIncludeSemantics;

  const TomAnimatedOpacity({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    this.opacity,
    this.duration,
    this.curve = Curves.linear,
    this.onEnd,
    this.alwaysIncludeSemantics,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedOpacity =
        opacity ?? resolveDoubleOrFail('opacity');
    final resolvedAlwaysIncludeSemantics = alwaysIncludeSemantics ??
        resolveBoolOrNull('alwaysIncludeSemantics') ?? false;

    return AnimatedOpacity(
      opacity: resolvedOpacity,
      duration: duration ?? Duration(milliseconds: resolveIntOrNull('duration') ?? 300),
      curve: curve,
      onEnd: onEnd,
      alwaysIncludeSemantics: resolvedAlwaysIncludeSemantics,
      child: child,
    );
  }
}

/// Tom wrapper for [AnimatedPadding].
///
/// Animates padding changes. Auth on padded content.
class TomAnimatedPadding extends TomAnimatedBase {
  final EdgeInsetsGeometry? padding;
  final Widget? child;
  final Duration? duration;
  final Curve curve;
  final VoidCallback? onEnd;

  const TomAnimatedPadding({
    super.key,
    super.tomId,
    super.tomGroup,
    this.padding,
    this.child,
    this.duration,
    this.curve = Curves.linear,
    this.onEnd,
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

    return AnimatedPadding(
      padding: resolvedPadding,
      duration: duration ?? Duration(milliseconds: resolveIntOrNull('duration') ?? 300),
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }
}

/// Tom wrapper for [AnimatedPhysicalModel].
///
/// Animates elevation/shadow. Auth on elevated content.
class TomAnimatedPhysicalModel extends TomAnimatedBase {
  final Widget child;
  final BoxShape shape;
  final Clip clipBehavior;
  final BorderRadius? borderRadius;
  final double? elevation;
  final Color? color;
  final bool? animateColor;
  final Color? shadowColor;
  final bool? animateShadowColor;
  final Duration? duration;
  final Curve curve;
  final VoidCallback? onEnd;

  const TomAnimatedPhysicalModel({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.child,
    required this.shape,
    this.clipBehavior = Clip.none,
    this.borderRadius,
    this.elevation,
    this.color,
    this.animateColor,
    this.shadowColor,
    this.animateShadowColor,
    this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedElevation =
      elevation ?? resolveDoubleOrFail('elevation');
    final resolvedColor =
      color ?? resolveColorOrFail('color');
    final resolvedAnimateColor =
      animateColor ?? resolveBoolOrNull('animateColor') ?? true;
    final resolvedShadowColor =
      shadowColor ?? resolveColorOrFail('shadowColor');
    final resolvedAnimateShadowColor = animateShadowColor ??
      resolveBoolOrNull('animateShadowColor') ?? true;

    return AnimatedPhysicalModel(
      shape: shape,
      clipBehavior: clipBehavior,
      borderRadius: borderRadius ?? _resolveBorderRadius('borderRadius') ?? BorderRadius.zero,
      elevation: resolvedElevation,
      color: resolvedColor,
      animateColor: resolvedAnimateColor,
      shadowColor: resolvedShadowColor,
      animateShadowColor: resolvedAnimateShadowColor,
      duration: duration ?? Duration(milliseconds: resolveIntOrNull('duration') ?? 300),
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }

  BorderRadius? _resolveBorderRadius(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderRadius(basePath, suffix);
  }
}

/// Tom wrapper for [AnimatedPositioned] with construction-time resource resolution.
///
/// Animates position in Stack.
/// Uses extension pattern because Stack checks `is Positioned`.
///
/// Resources are resolved at construction time:
/// - [child] — if null, creates `TomText(tomId: '$tomId.child')`
/// - [left], [top], [right], [bottom], [width], [height] — resolved from resources
class TomAnimatedPositioned extends AnimatedPositioned {
  /// Tom ID for resource resolution.
  final String? tomId;

  /// Optional group membership.
  final TomUIGroup? tomGroup;

  /// Optional explicit scope for resource resolution.
  final TomScope? scope;

  TomAnimatedPositioned({
    super.key,
    this.tomId,
    this.tomGroup,
    this.scope,
    Widget? child,
    double? left,
    double? top,
    double? right,
    double? bottom,
    double? width,
    double? height,
    required super.duration,
    super.curve,
    super.onEnd,
  }) : super(
          child: child ?? TomCtr.defaultTextOrEmpty(TomCtr.childTomId(tomId, 'child'), scope, tomGroup),
          left: left ?? TomCtr.doubleVal(_p(tomId, scope, 'left')),
          top: top ?? TomCtr.doubleVal(_p(tomId, scope, 'top')),
          right: right ?? TomCtr.doubleVal(_p(tomId, scope, 'right')),
          bottom: bottom ?? TomCtr.doubleVal(_p(tomId, scope, 'bottom')),
          width: width ?? TomCtr.doubleVal(_p(tomId, scope, 'width')),
          height: height ?? TomCtr.doubleVal(_p(tomId, scope, 'height')),
        );

  /// Helper to build full path with suffix (for value resolution).
  static String? _p(String? tomId, TomScope? scope, String suffix) {
    final base = TomCtr.resolvePath(tomId, scope);
    return base != null ? '$base.$suffix' : null;
  }
}

/// Tom wrapper for [AnimatedPositionedDirectional] with construction-time resource resolution.
///
/// RTL-aware animated position.
/// Uses extension pattern because Stack checks `is Positioned`.
///
/// Resources are resolved at construction time:
/// - [child] — if null, creates `TomText(tomId: '$tomId.child')`
/// - [start], [top], [end], [bottom], [width], [height] — resolved from resources
class TomAnimatedPositionedDirectional extends AnimatedPositionedDirectional {
  /// Tom ID for resource resolution.
  final String? tomId;

  /// Optional group membership.
  final TomUIGroup? tomGroup;

  /// Optional explicit scope for resource resolution.
  final TomScope? scope;

  TomAnimatedPositionedDirectional({
    super.key,
    this.tomId,
    this.tomGroup,
    this.scope,
    Widget? child,
    double? start,
    double? top,
    double? end,
    double? bottom,
    double? width,
    double? height,
    required super.duration,
    super.curve,
    super.onEnd,
  }) : super(
          child: child ?? TomCtr.defaultTextOrEmpty(TomCtr.childTomId(tomId, 'child'), scope, tomGroup),
          start: start ?? TomCtr.doubleVal(_p(tomId, scope, 'start')),
          top: top ?? TomCtr.doubleVal(_p(tomId, scope, 'top')),
          end: end ?? TomCtr.doubleVal(_p(tomId, scope, 'end')),
          bottom: bottom ?? TomCtr.doubleVal(_p(tomId, scope, 'bottom')),
          width: width ?? TomCtr.doubleVal(_p(tomId, scope, 'width')),
          height: height ?? TomCtr.doubleVal(_p(tomId, scope, 'height')),
        );

  /// Helper to build full path with suffix (for value resolution).
  static String? _p(String? tomId, TomScope? scope, String suffix) {
    final base = TomCtr.resolvePath(tomId, scope);
    return base != null ? '$base.$suffix' : null;
  }
}

/// Tom wrapper for [AnimatedRotation].
///
/// Animates rotation. Auth on rotated content.
class TomAnimatedRotation extends TomAnimatedBase {
  final Widget? child;
  final double? turns;
  final Alignment? alignment;
  final FilterQuality? filterQuality;
  final Duration? duration;
  final Curve curve;
  final VoidCallback? onEnd;

  const TomAnimatedRotation({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    this.turns,
    this.alignment,
    this.filterQuality,
    this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedTurns =
        turns ?? resolveDoubleOrFail('turns');

    return AnimatedRotation(
      turns: resolvedTurns,
      alignment: alignment ?? _resolveAlignment('alignment') ?? Alignment.center,
      filterQuality: filterQuality,
      duration: duration ?? Duration(milliseconds: resolveIntOrNull('duration') ?? 300),
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }

  Alignment? _resolveAlignment(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath, suffix) as Alignment?;
  }
}

/// Tom wrapper for [AnimatedScale].
///
/// Animates scale. Auth on scaled content.
class TomAnimatedScale extends TomAnimatedBase {
  final Widget? child;
  final double? scale;
  final Alignment? alignment;
  final FilterQuality? filterQuality;
  final Duration? duration;
  final Curve curve;
  final VoidCallback? onEnd;

  const TomAnimatedScale({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    this.scale,
    this.alignment,
    this.filterQuality,
    this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedScale =
        scale ?? resolveDoubleOrFail('scale');

    return AnimatedScale(
      scale: resolvedScale,
      alignment: alignment ?? _resolveAlignment('alignment') ?? Alignment.center,
      filterQuality: filterQuality,
      duration: duration ?? Duration(milliseconds: resolveIntOrNull('duration') ?? 300),
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }

  Alignment? _resolveAlignment(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath, suffix) as Alignment?;
  }
}

/// Tom wrapper for [AnimatedSize].
///
/// Animates size changes. Auth on resizing content.
class TomAnimatedSize extends TomAnimatedBase {
  final Widget? child;
  final AlignmentGeometry? alignment;
  final Duration? duration;
  final Duration? reverseDuration;
  final Curve curve;
  final Clip clipBehavior;
  final VoidCallback? onEnd;

  const TomAnimatedSize({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    this.alignment,
    this.duration,
    this.reverseDuration,
    this.curve = Curves.linear,
    this.clipBehavior = Clip.hardEdge,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedSize(
      alignment: alignment ?? _resolveAlignment('alignment') ?? Alignment.center,
      duration: duration ?? Duration(milliseconds: resolveIntOrNull('duration') ?? 300),
      reverseDuration: reverseDuration,
      curve: curve,
      clipBehavior: clipBehavior,
      onEnd: onEnd,
      child: child,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath, suffix);
  }
}

/// Tom wrapper for [AnimatedSlide].
///
/// Animates position offset. Auth on sliding content.
class TomAnimatedSlide extends TomAnimatedBase {
  final Widget? child;
  final Offset? offset;
  final Duration? duration;
  final Curve curve;
  final VoidCallback? onEnd;

  const TomAnimatedSlide({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    this.offset,
    this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedOffset =
        offset ?? _resolveOffset('offset') ?? Offset.zero;

    return AnimatedSlide(
      offset: resolvedOffset,
      duration: duration ?? Duration(milliseconds: resolveIntOrNull('duration') ?? 300),
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }

  Offset? _resolveOffset(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveOffset(basePath, suffix);
  }
}

/// Tom wrapper for [AnimatedSwitcher].
///
/// Animates child swap with transition. Auth on switched content.
class TomAnimatedSwitcher extends TomAnimatedBase {
  final Widget? child;
  final Duration? duration;
  final Duration? reverseDuration;
  final Curve switchInCurve;
  final Curve switchOutCurve;
  final AnimatedSwitcherTransitionBuilder transitionBuilder;
  final AnimatedSwitcherLayoutBuilder layoutBuilder;

  const TomAnimatedSwitcher({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    this.duration,
    this.reverseDuration,
    this.switchInCurve = Curves.linear,
    this.switchOutCurve = Curves.linear,
    this.transitionBuilder = AnimatedSwitcher.defaultTransitionBuilder,
    this.layoutBuilder = AnimatedSwitcher.defaultLayoutBuilder,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration ?? Duration(milliseconds: resolveIntOrNull('duration') ?? 300),
      reverseDuration: reverseDuration,
      switchInCurve: switchInCurve,
      switchOutCurve: switchOutCurve,
      transitionBuilder: transitionBuilder,
      layoutBuilder: layoutBuilder,
      child: child,
    );
  }
}

/// Tom wrapper for [Hero].
///
/// Shared element transition between routes. Auth on hero content across routes.
class TomHero extends TomAnimatedBase {
  final Object tag;
  final CreateRectTween? createRectTween;
  final HeroFlightShuttleBuilder? flightShuttleBuilder;
  final HeroPlaceholderBuilder? placeholderBuilder;
  final bool? transitionOnUserGestures;
  final Widget child;

  const TomHero({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.tag,
    this.createRectTween,
    this.flightShuttleBuilder,
    this.placeholderBuilder,
    this.transitionOnUserGestures,
    required this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedTransitionOnUserGestures = transitionOnUserGestures ??
        resolveBoolOrNull('transitionOnUserGestures') ?? false;

    return Hero(
      tag: tag,
      createRectTween: createRectTween,
      flightShuttleBuilder: flightShuttleBuilder,
      placeholderBuilder: placeholderBuilder,
      transitionOnUserGestures: resolvedTransitionOnUserGestures,
      child: child,
    );
  }
}

/// Tom wrapper for [RotationTransition].
///
/// Rotation animation driven by Animation. Auth on rotated content.
class TomRotationTransition extends TomAnimatedBase {
  final Animation<double> turns;
  final Alignment alignment;
  final FilterQuality? filterQuality;
  final Widget? child;

  const TomRotationTransition({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.turns,
    this.alignment = Alignment.center,
    this.filterQuality,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return RotationTransition(
      turns: turns,
      alignment: alignment,
      filterQuality: filterQuality,
      child: child,
    );
  }
}

/// Tom wrapper for [ScaleTransition].
///
/// Scale animation driven by Animation. Auth on scaled content.
class TomScaleTransition extends TomAnimatedBase {
  final Animation<double> scale;
  final Alignment alignment;
  final FilterQuality? filterQuality;
  final Widget? child;

  const TomScaleTransition({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.scale,
    this.alignment = Alignment.center,
    this.filterQuality,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return ScaleTransition(
      scale: scale,
      alignment: alignment,
      filterQuality: filterQuality,
      child: child,
    );
  }
}

/// Tom wrapper for [FadeTransition].
///
/// Opacity animation driven by Animation. Auth on faded content.
class TomFadeTransition extends TomAnimatedBase {
  final Animation<double> opacity;
  final bool alwaysIncludeSemantics;
  final Widget? child;

  const TomFadeTransition({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.opacity,
    this.alwaysIncludeSemantics = false,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return FadeTransition(
      opacity: opacity,
      alwaysIncludeSemantics: alwaysIncludeSemantics,
      child: child,
    );
  }
}
