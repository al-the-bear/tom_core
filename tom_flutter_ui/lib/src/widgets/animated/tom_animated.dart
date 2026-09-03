import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../groups/tom_auth_gate.dart';
import '../../groups/tom_widget_mixin.dart';
import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_style_resolvers.dart';
import '../labels/tom_labels.dart';

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

  // Pre-resolved resource values
  late final double? _resolvedHeightFactor;
  late final double? _resolvedWidthFactor;
  late final AlignmentGeometry? _resolvedAlignment;
  late final Duration _resolvedDuration;

  TomAnimatedAlign({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    this.alignment,
    this.child,
    this.heightFactor,
    this.widthFactor,
    this.duration,
    this.curve = Curves.linear,
    VoidCallback? onEnd,
  })  : onEnd = InScopeBuilder(scope: scope).wrap0n(onEnd) {
    _resolvedHeightFactor = heightFactor ?? TomCtr.doubleVal(basePath, 'heightFactor');
    _resolvedWidthFactor = widthFactor ?? TomCtr.doubleVal(basePath, 'widthFactor');
    _resolvedAlignment = alignment ?? _resolveAlignment('alignment');
    _resolvedDuration = duration ?? Duration(milliseconds: TomCtr.intVal(basePath, 'duration') ?? 300);
  }

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedAlign(
      alignment: _resolvedAlignment ?? Alignment.center,
      heightFactor: _resolvedHeightFactor,
      widthFactor: _resolvedWidthFactor,
      duration: _resolvedDuration,
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }
  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
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
  TomAnimatedBuilder({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    Listenable? listenable,
    Listenable? animation,
    required TransitionBuilder builder,
    this.child,
  })  : _listenable = listenable,
        _animation = animation,
        builder = InScopeBuilder(scope: scope).wrap2(builder);

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

  // Pre-resolved resource values
  late final Color? _resolvedColor;
  late final double? _resolvedWidth;
  late final double? _resolvedHeight;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final EdgeInsetsGeometry? _resolvedMargin;
  late final AlignmentGeometry? _resolvedAlignment;
  late final Decoration? _resolvedDecoration;
  late final Decoration? _resolvedForegroundDecoration;
  late final BoxConstraints? _resolvedConstraints;
  late final AlignmentGeometry? _resolvedTransformAlignment;
  late final Duration _resolvedDuration;

  TomAnimatedContainer({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
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
    VoidCallback? onEnd,
  })  : onEnd = InScopeBuilder(scope: scope).wrap0n(onEnd) {
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
    _resolvedWidth = width ?? TomCtr.doubleVal(basePath, 'width');
    _resolvedHeight = height ?? TomCtr.doubleVal(basePath, 'height');
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
    _resolvedMargin = margin ?? TomCtr.edgeInsets(basePath, 'margin');
    _resolvedAlignment = alignment ?? _resolveAlignment('alignment');
    _resolvedDecoration = decoration ?? _resolveDecoration('decoration');
    _resolvedForegroundDecoration = foregroundDecoration ?? _resolveDecoration('foregroundDecoration');
    _resolvedConstraints = constraints ?? _resolveBoxConstraints('constraints');
    _resolvedTransformAlignment = transformAlignment ?? _resolveAlignment('transformAlignment');
    _resolvedDuration = duration ?? Duration(milliseconds: TomCtr.intVal(basePath, 'duration') ?? 300);
  }

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedContainer(
      alignment: _resolvedAlignment,
      padding: _resolvedPadding,
      color: _resolvedColor,
      decoration: _resolvedDecoration,
      foregroundDecoration: _resolvedForegroundDecoration,
      constraints: _resolvedConstraints,
      width: _resolvedWidth,
      height: _resolvedHeight,
      margin: _resolvedMargin,
      transform: transform,
      transformAlignment: _resolvedTransformAlignment,
      clipBehavior: clipBehavior,
      duration: _resolvedDuration,
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
  }

  Decoration? _resolveDecoration(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveDecoration(basePath!, suffix);
  }

  BoxConstraints? _resolveBoxConstraints(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBoxConstraints(basePath!, suffix);
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

  // Pre-resolved resource values
  late final bool _resolvedExcludeBottomFocus;
  late final AlignmentGeometry? _resolvedAlignment;
  late final Duration _resolvedDuration;

  TomAnimatedCrossFade({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.firstChild,
    required this.secondChild,
    required this.crossFadeState,
    this.duration,
    this.reverseDuration,
    this.firstCurve = Curves.linear,
    this.secondCurve = Curves.linear,
    this.sizeCurve = Curves.linear,
    this.alignment,
    AnimatedCrossFadeBuilder layoutBuilder = AnimatedCrossFade.defaultLayoutBuilder,
    this.excludeBottomFocus,
  }) : layoutBuilder = InScopeBuilder(scope: scope).wrap4(layoutBuilder) {
    _resolvedExcludeBottomFocus = excludeBottomFocus ?? TomCtr.boolVal(basePath, 'excludeBottomFocus') ?? true;
    _resolvedAlignment = alignment ?? _resolveAlignment('alignment');
    _resolvedDuration = duration ?? Duration(milliseconds: TomCtr.intVal(basePath, 'duration') ?? 300);
  }

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: firstChild,
      secondChild: secondChild,
      crossFadeState: crossFadeState,
      duration: _resolvedDuration,
      reverseDuration: reverseDuration,
      firstCurve: firstCurve,
      secondCurve: secondCurve,
      sizeCurve: sizeCurve,
      alignment: _resolvedAlignment ?? Alignment.topCenter,
      layoutBuilder: layoutBuilder,
      excludeBottomFocus: _resolvedExcludeBottomFocus,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
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

  // Pre-resolved resource values
  late final TextStyle? _resolvedStyle;
  late final bool _resolvedSoftWrap;
  late final int? _resolvedMaxLines;
  late final Duration _resolvedDuration;

  TomAnimatedDefaultTextStyle({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
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
    VoidCallback? onEnd,
  })  : onEnd = InScopeBuilder(scope: scope).wrap0n(onEnd) {
    _resolvedStyle = _resolveTextStyle('style');
    _resolvedSoftWrap = softWrap ?? TomCtr.boolVal(basePath, 'softWrap') ?? true;
    _resolvedMaxLines = maxLines ?? TomCtr.intVal(basePath, 'maxLines');
    _resolvedDuration = duration ?? Duration(milliseconds: TomCtr.intVal(basePath, 'duration') ?? 300);
  }

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedDefaultTextStyle(
      style: _resolvedStyle ?? style,
      textAlign: textAlign,
      softWrap: _resolvedSoftWrap,
      overflow: overflow,
      maxLines: _resolvedMaxLines,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      duration: _resolvedDuration,
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
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

  // Pre-resolved resource values
  late final double? _resolvedWidthFactor;
  late final double? _resolvedHeightFactor;
  late final AlignmentGeometry? _resolvedAlignment;
  late final Duration _resolvedDuration;

  TomAnimatedFractionallySizedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    this.alignment,
    this.widthFactor,
    this.heightFactor,
    this.child,
    this.duration,
    this.curve = Curves.linear,
    VoidCallback? onEnd,
  })  : onEnd = InScopeBuilder(scope: scope).wrap0n(onEnd) {
    _resolvedWidthFactor = widthFactor ?? TomCtr.doubleVal(basePath, 'widthFactor');
    _resolvedHeightFactor = heightFactor ?? TomCtr.doubleVal(basePath, 'heightFactor');
    _resolvedAlignment = alignment ?? _resolveAlignment('alignment');
    _resolvedDuration = duration ?? Duration(milliseconds: TomCtr.intVal(basePath, 'duration') ?? 300);
  }

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedFractionallySizedBox(
      alignment: _resolvedAlignment ?? Alignment.center,
      widthFactor: _resolvedWidthFactor,
      heightFactor: _resolvedHeightFactor,
      duration: _resolvedDuration,
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
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

  // Pre-resolved resource values
  late final double _resolvedOpacity;
  late final bool _resolvedAlwaysIncludeSemantics;
  late final Duration _resolvedDuration;

  TomAnimatedOpacity({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    this.child,
    this.opacity,
    this.duration,
    this.curve = Curves.linear,
    VoidCallback? onEnd,
    this.alwaysIncludeSemantics,
  })  : onEnd = InScopeBuilder(scope: scope).wrap0n(onEnd) {
    _resolvedOpacity = opacity ?? TomCtr.doubleOrFail(basePath, 'opacity');
    _resolvedAlwaysIncludeSemantics = alwaysIncludeSemantics ?? TomCtr.boolVal(basePath, 'alwaysIncludeSemantics') ?? false;
    _resolvedDuration = duration ?? Duration(milliseconds: TomCtr.intVal(basePath, 'duration') ?? 300);
  }

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedOpacity(
      opacity: _resolvedOpacity,
      duration: _resolvedDuration,
      curve: curve,
      onEnd: onEnd,
      alwaysIncludeSemantics: _resolvedAlwaysIncludeSemantics,
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

  // Pre-resolved resource values
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final Duration _resolvedDuration;

  TomAnimatedPadding({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    this.padding,
    this.child,
    this.duration,
    this.curve = Curves.linear,
    VoidCallback? onEnd,
  })  : onEnd = InScopeBuilder(scope: scope).wrap0n(onEnd) {
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
    _resolvedDuration = duration ?? Duration(milliseconds: TomCtr.intVal(basePath, 'duration') ?? 300);
  }

  @override
  Widget buildContent(BuildContext context) {
    if (_resolvedPadding == null) {
      throw StateError(
        'Tom widget requires either an explicit padding or a tomId resource '
        'value at padding. Widget: $runtimeType',
      );
    }

    return AnimatedPadding(
      padding: _resolvedPadding,
      duration: _resolvedDuration,
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

  // Pre-resolved resource values
  late final double _resolvedElevation;
  late final Color _resolvedColor;
  late final bool _resolvedAnimateColor;
  late final Color _resolvedShadowColor;
  late final bool _resolvedAnimateShadowColor;
  late final BorderRadius? _resolvedBorderRadius;
  late final Duration _resolvedDuration;

  TomAnimatedPhysicalModel({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
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
    VoidCallback? onEnd,
  })  : onEnd = InScopeBuilder(scope: scope).wrap0n(onEnd) {
    _resolvedElevation = elevation ?? TomCtr.doubleOrFail(basePath, 'elevation');
    _resolvedColor = color ?? TomCtr.colorOrFail(basePath, 'color');
    _resolvedAnimateColor = animateColor ?? TomCtr.boolVal(basePath, 'animateColor') ?? true;
    _resolvedShadowColor = shadowColor ?? TomCtr.colorOrFail(basePath, 'shadowColor');
    _resolvedAnimateShadowColor = animateShadowColor ?? TomCtr.boolVal(basePath, 'animateShadowColor') ?? true;
    _resolvedBorderRadius = borderRadius ?? _resolveBorderRadius('borderRadius');
    _resolvedDuration = duration ?? Duration(milliseconds: TomCtr.intVal(basePath, 'duration') ?? 300);
  }

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedPhysicalModel(
      shape: shape,
      clipBehavior: clipBehavior,
      borderRadius: _resolvedBorderRadius ?? BorderRadius.zero,
      elevation: _resolvedElevation,
      color: _resolvedColor,
      animateColor: _resolvedAnimateColor,
      shadowColor: _resolvedShadowColor,
      animateShadowColor: _resolvedAnimateShadowColor,
      duration: _resolvedDuration,
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }

  BorderRadius? _resolveBorderRadius(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderRadius(basePath!, suffix);
  }
}

/// Tom wrapper for [AnimatedPositioned] with construction-time resource resolution.
///
/// Animates position in Stack.
///
/// Extends [AnimatedPositioned] rather than wrapping it, so that a `Stack`
/// receives the type it expects. That closes off the usual way a Tom widget
/// gates itself: [AnimatedPositioned]'s `State` is private to the framework,
/// so `super.build(context)` cannot be reached and there is no build to wrap.
/// The authorization therefore sits on [child], in a [TomAuthGate] — see
/// [TomWidgetMixin] for the surface this and the mixin share.
///
/// Resources are resolved at construction time:
/// - [child] — if null, creates `TomText(tomId: '$tomId.child')`
/// - [left], [top], [right], [bottom], [width], [height] — resolved from resources
class TomAnimatedPositioned extends AnimatedPositioned with TomWidgetMixin {
  /// Tom ID for resource resolution.
  @override
  final String? tomId;

  /// Optional group membership.
  @override
  final TomAuthorizationGroup? tomGroup;

  /// Optional explicit scope for resource resolution.
  @override
  final TomScope? scope;

  /// Optional per-widget authorizer, applied after the group's mode.
  @override
  final TomAuthorizer? authorizer;

  /// Optional build-time UI-state controller, applied last.
  @override
  final TomUIStateController? uiStateController;

  TomAnimatedPositioned({
    super.key,
    this.tomId,
    this.tomGroup,
    this.scope,
    this.authorizer,
    this.uiStateController,
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
          child: TomAuthGate(
            tomId: tomId,
            tomGroup: tomGroup,
            scope: scope,
            authorizer: authorizer,
            uiStateController: uiStateController,
            child: child ??
                TomText.defaultOrEmpty(
                    TomCtr.childTomId(tomId, 'child'), scope, tomGroup),
          ),
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
///
/// Extends [AnimatedPositionedDirectional] for the same reason, and with the
/// same consequence, as [TomAnimatedPositioned]: the framework `State` is
/// private, so the gate sits on [child].
///
/// Resources are resolved at construction time:
/// - [child] — if null, creates `TomText(tomId: '$tomId.child')`
/// - [start], [top], [end], [bottom], [width], [height] — resolved from resources
class TomAnimatedPositionedDirectional extends AnimatedPositionedDirectional
    with TomWidgetMixin {
  /// Tom ID for resource resolution.
  @override
  final String? tomId;

  /// Optional group membership.
  @override
  final TomAuthorizationGroup? tomGroup;

  /// Optional explicit scope for resource resolution.
  @override
  final TomScope? scope;

  /// Optional per-widget authorizer, applied after the group's mode.
  @override
  final TomAuthorizer? authorizer;

  /// Optional build-time UI-state controller, applied last.
  @override
  final TomUIStateController? uiStateController;

  TomAnimatedPositionedDirectional({
    super.key,
    this.tomId,
    this.tomGroup,
    this.scope,
    this.authorizer,
    this.uiStateController,
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
          child: TomAuthGate(
            tomId: tomId,
            tomGroup: tomGroup,
            scope: scope,
            authorizer: authorizer,
            uiStateController: uiStateController,
            child: child ??
                TomText.defaultOrEmpty(
                    TomCtr.childTomId(tomId, 'child'), scope, tomGroup),
          ),
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

  // Pre-resolved resource values
  late final double _resolvedTurns;
  late final Alignment? _resolvedAlignment;
  late final Duration _resolvedDuration;

  TomAnimatedRotation({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    this.child,
    this.turns,
    this.alignment,
    this.filterQuality,
    this.duration,
    this.curve = Curves.linear,
    VoidCallback? onEnd,
  })  : onEnd = InScopeBuilder(scope: scope).wrap0n(onEnd) {
    _resolvedTurns = turns ?? TomCtr.doubleOrFail(basePath, 'turns');
    _resolvedAlignment = alignment ?? _resolveAlignment('alignment');
    _resolvedDuration = duration ?? Duration(milliseconds: TomCtr.intVal(basePath, 'duration') ?? 300);
  }

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedRotation(
      turns: _resolvedTurns,
      alignment: _resolvedAlignment ?? Alignment.center,
      filterQuality: filterQuality,
      duration: _resolvedDuration,
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }

  Alignment? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix) as Alignment?;
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

  // Pre-resolved resource values
  late final double _resolvedScale;
  late final Alignment? _resolvedAlignment;
  late final Duration _resolvedDuration;

  TomAnimatedScale({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    this.child,
    this.scale,
    this.alignment,
    this.filterQuality,
    this.duration,
    this.curve = Curves.linear,
    VoidCallback? onEnd,
  })  : onEnd = InScopeBuilder(scope: scope).wrap0n(onEnd) {
    _resolvedScale = scale ?? TomCtr.doubleOrFail(basePath, 'scale');
    _resolvedAlignment = alignment ?? _resolveAlignment('alignment');
    _resolvedDuration = duration ?? Duration(milliseconds: TomCtr.intVal(basePath, 'duration') ?? 300);
  }

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedScale(
      scale: _resolvedScale,
      alignment: _resolvedAlignment ?? Alignment.center,
      filterQuality: filterQuality,
      duration: _resolvedDuration,
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }

  Alignment? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix) as Alignment?;
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

  // Pre-resolved resource values
  late final AlignmentGeometry? _resolvedAlignment;
  late final Duration _resolvedDuration;

  TomAnimatedSize({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    this.child,
    this.alignment,
    this.duration,
    this.reverseDuration,
    this.curve = Curves.linear,
    this.clipBehavior = Clip.hardEdge,
    VoidCallback? onEnd,
  })  : onEnd = InScopeBuilder(scope: scope).wrap0n(onEnd) {
    _resolvedAlignment = alignment ?? _resolveAlignment('alignment');
    _resolvedDuration = duration ?? Duration(milliseconds: TomCtr.intVal(basePath, 'duration') ?? 300);
  }

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedSize(
      alignment: _resolvedAlignment ?? Alignment.center,
      duration: _resolvedDuration,
      reverseDuration: reverseDuration,
      curve: curve,
      clipBehavior: clipBehavior,
      onEnd: onEnd,
      child: child,
    );
  }

  AlignmentGeometry? _resolveAlignment(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveAlignment(basePath!, suffix);
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

  // Pre-resolved resource values
  late final Offset _resolvedOffset;
  late final Duration _resolvedDuration;

  TomAnimatedSlide({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    this.child,
    this.offset,
    this.duration,
    this.curve = Curves.linear,
    VoidCallback? onEnd,
  })  : onEnd = InScopeBuilder(scope: scope).wrap0n(onEnd) {
    _resolvedOffset = offset ?? _resolveOffset('offset') ?? Offset.zero;
    _resolvedDuration = duration ?? Duration(milliseconds: TomCtr.intVal(basePath, 'duration') ?? 300);
  }

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedSlide(
      offset: _resolvedOffset,
      duration: _resolvedDuration,
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }

  Offset? _resolveOffset(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveOffset(basePath!, suffix);
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

  late final Duration _resolvedDuration;
  TomAnimatedSwitcher({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    this.child,
    this.duration,
    this.reverseDuration,
    this.switchInCurve = Curves.linear,
    this.switchOutCurve = Curves.linear,
    AnimatedSwitcherTransitionBuilder transitionBuilder = AnimatedSwitcher.defaultTransitionBuilder,
    AnimatedSwitcherLayoutBuilder layoutBuilder = AnimatedSwitcher.defaultLayoutBuilder,
  }) : transitionBuilder = InScopeBuilder(scope: scope).wrap2(transitionBuilder),
       layoutBuilder = InScopeBuilder(scope: scope).wrap2(layoutBuilder) {

    _resolvedDuration = duration ?? Duration(milliseconds: TomCtr.intVal(basePath, 'duration') ?? 300);
  }

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedSwitcher(
      duration: _resolvedDuration,
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

  // Pre-resolved resource values
  late final bool _resolvedTransitionOnUserGestures;

  TomHero({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.tag,
    this.createRectTween,
    HeroFlightShuttleBuilder? flightShuttleBuilder,
    HeroPlaceholderBuilder? placeholderBuilder,
    this.transitionOnUserGestures,
    required this.child,
  }) : flightShuttleBuilder = flightShuttleBuilder != null ? InScopeBuilder(scope: scope).wrap5(flightShuttleBuilder) : null,
       placeholderBuilder = placeholderBuilder != null ? InScopeBuilder(scope: scope).wrap3(placeholderBuilder) : null {
    _resolvedTransitionOnUserGestures = transitionOnUserGestures ?? TomCtr.boolVal(basePath, 'transitionOnUserGestures') ?? false;
  }

  @override
  Widget buildContent(BuildContext context) {
    return Hero(
      tag: tag,
      createRectTween: createRectTween,
      flightShuttleBuilder: flightShuttleBuilder,
      placeholderBuilder: placeholderBuilder,
      transitionOnUserGestures: _resolvedTransitionOnUserGestures,
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

  TomRotationTransition({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
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

  TomScaleTransition({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
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

  TomFadeTransition({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
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
