/// Shimmer / skeleton placeholder for async-loading surfaces. Renders
/// a soft animated shimmer over a coloured rectangle (or a child widget
/// when supplied), giving downstream apps a consistent loading idiom
/// without taking a third-party dependency.
///
/// The shimmer is driven by a [SingleTickerProviderStateMixin]-backed
/// [AnimationController] that cycles a horizontal gradient from left to
/// right at the configured [TomSkeletonLoader.period]. It runs while
/// [TomSkeletonLoader.enabled] is true **and** the environment allows motion:
/// `MediaQuery`'s disable-animations flag and an enclosing
/// `TickerMode(enabled: false)` each stop it, which is also what lets a test
/// `pumpAndSettle` with a skeleton on screen. When
/// [TomSkeletonLoader.child] is non-null the shimmer is masked to the
/// child silhouette via [ShaderMask], which
/// lets callers compose skeletons out of plain widgets (`Container`,
/// `Row` of `SizedBox`, etc.).
library;

import 'package:flutter/material.dart';

/// Shimmering skeleton placeholder for async-loading surfaces.
class TomSkeletonLoader extends StatefulWidget {
  /// Optional child whose silhouette receives the shimmer mask. When
  /// `null`, the loader renders a [width] × [height] rounded rectangle
  /// painted with the base colour.
  ///
  /// Only the silhouette survives: the mask repaints the child in the
  /// shimmer colours, so its own colours never show while [enabled] is
  /// true. Pass a placeholder shape, not real content — and see
  /// [enabled], which passes the child through untouched.
  final Widget? child;

  /// Width of the default rectangle (ignored when [child] is non-null).
  final double width;

  /// Height of the default rectangle (ignored when [child] is non-null).
  final double height;

  /// Border radius for the default rectangle.
  final BorderRadius borderRadius;

  /// Base shimmer colour. When `null`, the widget picks
  /// `colorScheme.surfaceContainerHighest`.
  final Color? baseColor;

  /// Highlight shimmer colour. When `null`, the widget picks
  /// `colorScheme.surface`.
  final Color? highlightColor;

  /// Animation period for one shimmer cycle.
  final Duration period;

  /// Whether the shimmer animation runs.
  ///
  /// `false` removes the [ShaderMask] rather than merely freezing it, and
  /// the mask is what *paints* the skeleton — so the widget's two forms
  /// stop in different places:
  ///
  /// * with no [child], the [width] × [height] rectangle it draws itself
  ///   remains, filled with [baseColor]. A static placeholder.
  /// * with a [child], the child is returned exactly as passed, **in its
  ///   own colours**. Nothing is masked over it and no grey box is drawn,
  ///   so whether the result still reads as a placeholder depends
  ///   entirely on what the caller supplied.
  ///
  /// The difference is easy to miss because it is invisible while
  /// `enabled` is true: the mask overpaints a child's colours with
  /// [baseColor] / [highlightColor], so a red child shimmers grey like
  /// every other skeleton and only reveals itself as red once disabled.
  ///
  /// Always right for tests, where a repeating animation never lets
  /// `pumpAndSettle` finish. For reduced motion, only the childless form
  /// is a placeholder on its own; a [child] must already be a silhouette
  /// — which is how [child] is meant to be used — and not the real
  /// content, or the caller gets the finished content instead.
  ///
  /// Two ambient switches reach the same state without touching this flag,
  /// and both are worth knowing because this widget is often built by
  /// something else — `TomInfiniteScroll`'s default skeleton, say, where the
  /// caller never names it:
  ///
  /// * `MediaQuery`'s **disable-animations** accessibility flag. A user who
  ///   has asked for reduced motion gets the static form; a test gets it by
  ///   wrapping the subtree in a `MediaQuery` whose data carries
  ///   `disableAnimations: true`.
  /// * **[TickerMode]**. `TickerMode(enabled: false)` above the subtree mutes
  ///   the ticker, which is the framework's own way to freeze an animation
  ///   wholesale and needs nothing from this widget.
  ///
  /// Either lets `pumpAndSettle` return with a skeleton on screen. Without
  /// one, it cannot: a repeating animation schedules frames forever, so the
  /// binding never reaches a quiescent one — the same as Flutter's own
  /// indeterminate `CircularProgressIndicator`.
  final bool enabled;

  const TomSkeletonLoader({
    super.key,
    this.child,
    this.width = 120,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.baseColor,
    this.highlightColor,
    this.period = const Duration(milliseconds: 1200),
    this.enabled = true,
  });

  @override
  State<TomSkeletonLoader> createState() => _TomSkeletonLoaderState();
}

class _TomSkeletonLoaderState extends State<TomSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Whether the ambient environment allows motion.
  ///
  /// Read from `MediaQuery` rather than checked at each use, because the
  /// answer decides both what [build] returns and whether the controller is
  /// running — and a controller left repeating keeps scheduling frames
  /// whatever the build returns.
  bool _motionAllowed = true;

  bool get _shimmering => widget.enabled && _motionAllowed;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period);
    // Started from `didChangeDependencies`, which runs before the first build
    // and is where `MediaQuery` may be read.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionAllowed = !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    _syncTicker();
  }

  void _syncTicker() {
    if (_shimmering) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void didUpdateWidget(covariant TomSkeletonLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller.duration = widget.period;
    }
    if (oldWidget.enabled != widget.enabled) _syncTicker();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = widget.baseColor ?? theme.colorScheme.surfaceContainerHighest;
    final highlight = widget.highlightColor ?? theme.colorScheme.surface;

    final placeholder =
        widget.child ??
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: base,
            borderRadius: widget.borderRadius,
          ),
        );

    if (!_shimmering) return placeholder;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + 2.0 * t - 0.3, 0),
              end: Alignment(-1.0 + 2.0 * t + 0.3, 0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: placeholder,
        );
      },
    );
  }
}
