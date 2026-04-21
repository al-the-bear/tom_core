/// Phase 6 — `TomSkeletonLoader`.
///
/// Shimmer / skeleton placeholder for async-loading surfaces. Renders
/// a soft animated shimmer over a coloured rectangle (or a child widget
/// when supplied), giving downstream apps a consistent loading idiom
/// without taking a third-party dependency.
///
/// The shimmer is driven by a [SingleTickerProviderStateMixin]-backed
/// [AnimationController] that cycles a horizontal gradient from left to
/// right at the configured [period]. When [child] is non-null the
/// shimmer is masked to the child silhouette via [ShaderMask], which
/// lets callers compose skeletons out of plain widgets (`Container`,
/// `Row` of `SizedBox`, etc.).
library;

import 'package:flutter/material.dart';

/// Shimmering skeleton placeholder for async-loading surfaces.
class TomSkeletonLoader extends StatefulWidget {
  /// Optional child whose silhouette receives the shimmer mask. When
  /// `null`, the loader renders a [width] × [height] rounded rectangle
  /// painted with the base colour.
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

  /// Whether the shimmer animation runs. When `false` the placeholder
  /// is rendered as a static rectangle (useful for tests / reduced-
  /// motion settings).
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period);
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant TomSkeletonLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller.duration = widget.period;
    }
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
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

    final placeholder = widget.child ??
        Container(
          width: widget.width,
          height: widget.height,
          decoration:
              BoxDecoration(color: base, borderRadius: widget.borderRadius),
        );

    if (!widget.enabled) return placeholder;

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
