import 'package:flutter/material.dart';

import '../../groups/tom_widget_mixin.dart';
import '../../widget_base/tom_family_base.dart';

// =============================================================================
// Section II: Animated Widgets
// =============================================================================

/// Tom wrapper for [AnimatedAlign].
///
/// Animates alignment changes. Auth on animated content region.
class TomAnimatedAlign extends TomAnimatedBase {
  final AlignmentGeometry alignment;
  final Widget? child;
  final double? heightFactor;
  final double? widthFactor;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onEnd;

  const TomAnimatedAlign({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.alignment,
    this.child,
    this.heightFactor,
    this.widthFactor,
    required this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedAlign(
      alignment: alignment,
      child: child,
      heightFactor: heightFactor,
      widthFactor: widthFactor,
      duration: duration,
      curve: curve,
      onEnd: onEnd,
    );
  }
}

/// Tom wrapper for [AnimatedBuilder].
///
/// Rebuilds on Listenable changes. Auth on rebuilt content.
class TomAnimatedBuilder extends TomAnimatedBase {
  final Listenable listenable;
  final TransitionBuilder builder;
  final Widget? child;

  const TomAnimatedBuilder({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedBuilder(
      animation: listenable,
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
  final EdgeInsetsGeometry? margin;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;
  final Widget? child;
  final Clip clipBehavior;
  final Duration duration;
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
    this.margin,
    this.transform,
    this.transformAlignment,
    this.child,
    this.clipBehavior = Clip.none,
    required this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedContainer(
      alignment: alignment,
      padding: padding,
      color: color,
      decoration: decoration,
      foregroundDecoration: foregroundDecoration,
      constraints: constraints,
      margin: margin,
      transform: transform,
      transformAlignment: transformAlignment,
      clipBehavior: clipBehavior,
      duration: duration,
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }
}

/// Tom wrapper for [AnimatedCrossFade].
///
/// Cross-fades between two children. Auth on both fade children.
class TomAnimatedCrossFade extends TomAnimatedBase {
  final Widget firstChild;
  final Widget secondChild;
  final CrossFadeState crossFadeState;
  final Duration duration;
  final Duration? reverseDuration;
  final Curve firstCurve;
  final Curve secondCurve;
  final Curve sizeCurve;
  final AlignmentGeometry alignment;
  final AnimatedCrossFadeBuilder layoutBuilder;
  final bool excludeBottomFocus;

  const TomAnimatedCrossFade({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.firstChild,
    required this.secondChild,
    required this.crossFadeState,
    required this.duration,
    this.reverseDuration,
    this.firstCurve = Curves.linear,
    this.secondCurve = Curves.linear,
    this.sizeCurve = Curves.linear,
    this.alignment = Alignment.topCenter,
    this.layoutBuilder = AnimatedCrossFade.defaultLayoutBuilder,
    this.excludeBottomFocus = true,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: firstChild,
      secondChild: secondChild,
      crossFadeState: crossFadeState,
      duration: duration,
      reverseDuration: reverseDuration,
      firstCurve: firstCurve,
      secondCurve: secondCurve,
      sizeCurve: sizeCurve,
      alignment: alignment,
      layoutBuilder: layoutBuilder,
      excludeBottomFocus: excludeBottomFocus,
    );
  }
}

/// Tom wrapper for [AnimatedDefaultTextStyle].
///
/// Animates text style changes. Auth on styled content.
class TomAnimatedDefaultTextStyle extends TomAnimatedBase {
  final Widget child;
  final TextStyle style;
  final TextAlign? textAlign;
  final bool softWrap;
  final TextOverflow overflow;
  final int? maxLines;
  final TextWidthBasis textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onEnd;

  const TomAnimatedDefaultTextStyle({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.child,
    required this.style,
    this.textAlign,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.maxLines,
    this.textWidthBasis = TextWidthBasis.parent,
    this.textHeightBehavior,
    required this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedDefaultTextStyle(
      style: style,
      textAlign: textAlign,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      duration: duration,
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }
}

/// Tom wrapper for [AnimatedFractionallySizedBox].
///
/// Animates fractional sizing. Auth on sized content.
class TomAnimatedFractionallySizedBox extends TomAnimatedBase {
  final AlignmentGeometry alignment;
  final double? widthFactor;
  final double? heightFactor;
  final Widget? child;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onEnd;

  const TomAnimatedFractionallySizedBox({
    super.key,
    super.tomId,
    super.tomGroup,
    this.alignment = Alignment.center,
    this.widthFactor,
    this.heightFactor,
    this.child,
    required this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedFractionallySizedBox(
      alignment: alignment,
      widthFactor: widthFactor,
      heightFactor: heightFactor,
      duration: duration,
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }
}

/// Tom wrapper for [AnimatedOpacity].
///
/// Animates opacity changes. Auth on content being faded.
class TomAnimatedOpacity extends TomAnimatedBase {
  final Widget? child;
  final double opacity;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onEnd;
  final bool alwaysIncludeSemantics;

  const TomAnimatedOpacity({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    required this.opacity,
    required this.duration,
    this.curve = Curves.linear,
    this.onEnd,
    this.alwaysIncludeSemantics = false,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedOpacity(
      opacity: opacity,
      duration: duration,
      curve: curve,
      onEnd: onEnd,
      alwaysIncludeSemantics: alwaysIncludeSemantics,
      child: child,
    );
  }
}

/// Tom wrapper for [AnimatedPadding].
///
/// Animates padding changes. Auth on padded content.
class TomAnimatedPadding extends TomAnimatedBase {
  final EdgeInsetsGeometry padding;
  final Widget? child;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onEnd;

  const TomAnimatedPadding({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.padding,
    this.child,
    required this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedPadding(
      padding: padding,
      duration: duration,
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
  final BorderRadius borderRadius;
  final double elevation;
  final Color color;
  final bool animateColor;
  final Color shadowColor;
  final bool animateShadowColor;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onEnd;

  const TomAnimatedPhysicalModel({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.child,
    required this.shape,
    this.clipBehavior = Clip.none,
    this.borderRadius = BorderRadius.zero,
    required this.elevation,
    required this.color,
    this.animateColor = true,
    required this.shadowColor,
    this.animateShadowColor = true,
    required this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedPhysicalModel(
      shape: shape,
      clipBehavior: clipBehavior,
      borderRadius: borderRadius,
      elevation: elevation,
      color: color,
      animateColor: animateColor,
      shadowColor: shadowColor,
      animateShadowColor: animateShadowColor,
      duration: duration,
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }
}

/// Tom wrapper for [AnimatedPositioned].
///
/// Animates position in Stack. Auth on positioned content.
/// Uses extension pattern because Stack checks `is Positioned`.
class TomAnimatedPositioned extends AnimatedPositioned with TomWidgetMixin {
  @override
  final String? tomId;
  @override
  final String? tomGroup;

  const TomAnimatedPositioned({
    super.key,
    this.tomId,
    this.tomGroup,
    required super.child,
    super.left,
    super.top,
    super.right,
    super.bottom,
    super.width,
    super.height,
    required super.duration,
    super.curve,
    super.onEnd,
  });
}

/// Tom wrapper for [AnimatedPositionedDirectional].
///
/// RTL-aware animated position. Auth on positioned content.
/// Uses extension pattern because Stack checks `is Positioned`.
class TomAnimatedPositionedDirectional extends AnimatedPositionedDirectional
    with TomWidgetMixin {
  @override
  final String? tomId;
  @override
  final String? tomGroup;

  const TomAnimatedPositionedDirectional({
    super.key,
    this.tomId,
    this.tomGroup,
    required super.child,
    super.start,
    super.top,
    super.end,
    super.bottom,
    super.width,
    super.height,
    required super.duration,
    super.curve,
    super.onEnd,
  });
}

/// Tom wrapper for [AnimatedRotation].
///
/// Animates rotation. Auth on rotated content.
class TomAnimatedRotation extends TomAnimatedBase {
  final Widget? child;
  final double turns;
  final Alignment alignment;
  final FilterQuality? filterQuality;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onEnd;

  const TomAnimatedRotation({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    required this.turns,
    this.alignment = Alignment.center,
    this.filterQuality,
    required this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedRotation(
      turns: turns,
      alignment: alignment,
      filterQuality: filterQuality,
      duration: duration,
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }
}

/// Tom wrapper for [AnimatedScale].
///
/// Animates scale. Auth on scaled content.
class TomAnimatedScale extends TomAnimatedBase {
  final Widget? child;
  final double scale;
  final Alignment alignment;
  final FilterQuality? filterQuality;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onEnd;

  const TomAnimatedScale({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    required this.scale,
    this.alignment = Alignment.center,
    this.filterQuality,
    required this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedScale(
      scale: scale,
      alignment: alignment,
      filterQuality: filterQuality,
      duration: duration,
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }
}

/// Tom wrapper for [AnimatedSize].
///
/// Animates size changes. Auth on resizing content.
class TomAnimatedSize extends TomAnimatedBase {
  final Widget? child;
  final AlignmentGeometry alignment;
  final Duration duration;
  final Duration? reverseDuration;
  final Curve curve;
  final Clip clipBehavior;
  final VoidCallback? onEnd;

  const TomAnimatedSize({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    this.alignment = Alignment.center,
    required this.duration,
    this.reverseDuration,
    this.curve = Curves.linear,
    this.clipBehavior = Clip.hardEdge,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedSize(
      alignment: alignment,
      duration: duration,
      reverseDuration: reverseDuration,
      curve: curve,
      clipBehavior: clipBehavior,
      onEnd: onEnd,
      child: child,
    );
  }
}

/// Tom wrapper for [AnimatedSlide].
///
/// Animates position offset. Auth on sliding content.
class TomAnimatedSlide extends TomAnimatedBase {
  final Widget? child;
  final Offset offset;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onEnd;

  const TomAnimatedSlide({
    super.key,
    super.tomId,
    super.tomGroup,
    this.child,
    required this.offset,
    required this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedSlide(
      offset: offset,
      duration: duration,
      curve: curve,
      onEnd: onEnd,
      child: child,
    );
  }
}

/// Tom wrapper for [AnimatedSwitcher].
///
/// Animates child swap with transition. Auth on switched content.
class TomAnimatedSwitcher extends TomAnimatedBase {
  final Widget? child;
  final Duration duration;
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
    required this.duration,
    this.reverseDuration,
    this.switchInCurve = Curves.linear,
    this.switchOutCurve = Curves.linear,
    this.transitionBuilder = AnimatedSwitcher.defaultTransitionBuilder,
    this.layoutBuilder = AnimatedSwitcher.defaultLayoutBuilder,
  });

  @override
  Widget buildContent(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
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
  final bool transitionOnUserGestures;
  final Widget child;

  const TomHero({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.tag,
    this.createRectTween,
    this.flightShuttleBuilder,
    this.placeholderBuilder,
    this.transitionOnUserGestures = false,
    required this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Hero(
      tag: tag,
      createRectTween: createRectTween,
      flightShuttleBuilder: flightShuttleBuilder,
      placeholderBuilder: placeholderBuilder,
      transitionOnUserGestures: transitionOnUserGestures,
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
