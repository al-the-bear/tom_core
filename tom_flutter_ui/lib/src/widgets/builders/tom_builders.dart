/// Builder family wrappers – Section II widgets for Tom Flutter UI.
///
/// Includes: StatefulBuilder, StreamBuilder, FutureBuilder, ValueListenableBuilder,
/// ListenableBuilder, TweenAnimationBuilder, OrientationBuilder, LayoutBuilder.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../widget_base/tom_family_base.dart';

// ────────────────────────────────────────────────────────────────────────────
// TomStatefulBuilder
// ────────────────────────────────────────────────────────────────────────────

/// Tom-aware wrapper for [StatefulBuilder].
///
/// Provides inline stateful widget capability via a builder function.
/// Authorization applies to the entire builder content region.
class TomStatefulBuilder extends TomBuilderBase {
  TomStatefulBuilder({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.builder,
  });

  /// The builder function that creates the widget tree with setState capability.
  final StatefulWidgetBuilder builder;

  @override
  Widget buildContent(BuildContext context) {
    return StatefulBuilder(
      builder: builder,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// TomStreamBuilder
// ────────────────────────────────────────────────────────────────────────────

/// Tom-aware wrapper for [StreamBuilder].
///
/// Rebuilds the widget tree whenever the stream emits a new event.
/// Authorization applies to stream-driven content.
class TomStreamBuilder<T> extends TomBuilderBase {
  TomStreamBuilder({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.initialData,
    this.stream,
    required this.builder,
  });

  /// The initial data to use before the stream emits any events.
  final T? initialData;

  /// The stream to listen to.
  final Stream<T>? stream;

  /// The builder function that creates the widget tree based on stream state.
  final AsyncWidgetBuilder<T> builder;

  @override
  Widget buildContent(BuildContext context) {
    return StreamBuilder<T>(
      initialData: initialData,
      stream: stream,
      builder: builder,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// TomFutureBuilder
// ────────────────────────────────────────────────────────────────────────────

/// Tom-aware wrapper for [FutureBuilder].
///
/// Rebuilds the widget tree when the future completes.
/// Authorization applies to async-loaded content.
class TomFutureBuilder<T> extends TomBuilderBase {
  TomFutureBuilder({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.initialData,
    this.future,
    required this.builder,
  });

  /// The initial data to use before the future completes.
  final T? initialData;

  /// The asynchronous computation to wait for.
  final Future<T>? future;

  /// The builder function that creates the widget tree based on future state.
  final AsyncWidgetBuilder<T> builder;

  @override
  Widget buildContent(BuildContext context) {
    return FutureBuilder<T>(
      initialData: initialData,
      future: future,
      builder: builder,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// TomValueListenableBuilder
// ────────────────────────────────────────────────────────────────────────────

/// Tom-aware wrapper for [ValueListenableBuilder].
///
/// Rebuilds the widget tree whenever the [ValueListenable] changes.
/// Authorization applies to reactive content.
class TomValueListenableBuilder<T> extends TomBuilderBase {
  TomValueListenableBuilder({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.valueListenable,
    required this.builder,
    this.child,
  });

  /// The [ValueListenable] to listen to.
  final ValueListenable<T> valueListenable;

  /// The builder function that creates the widget tree based on the value.
  final ValueWidgetBuilder<T> builder;

  /// The child widget to pass to the builder (optimization for static content).
  final Widget? child;

  @override
  Widget buildContent(BuildContext context) {
    return ValueListenableBuilder<T>(
      valueListenable: valueListenable,
      builder: builder,
      child: child,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// TomListenableBuilder
// ────────────────────────────────────────────────────────────────────────────

/// Tom-aware wrapper for [ListenableBuilder].
///
/// Rebuilds the widget tree whenever the [Listenable] notifies.
/// Authorization applies to reactive content.
class TomListenableBuilder extends TomBuilderBase {
  TomListenableBuilder({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.listenable,
    required this.builder,
    this.child,
  });

  /// The [Listenable] to listen to.
  final Listenable listenable;

  /// The builder function that creates the widget tree.
  final TransitionBuilder builder;

  /// The child widget to pass to the builder (optimization for static content).
  final Widget? child;

  @override
  Widget buildContent(BuildContext context) {
    return ListenableBuilder(
      listenable: listenable,
      builder: builder,
      child: child,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// TomTweenAnimationBuilder
// ────────────────────────────────────────────────────────────────────────────

/// Tom-aware wrapper for [TweenAnimationBuilder].
///
/// Animates a tween and rebuilds the widget tree on each animation frame.
/// Authorization applies to animated content.
class TomTweenAnimationBuilder<T extends Object> extends TomBuilderBase {
  // Pre-resolved resource values
  late final Curve _resolvedCurve;

  TomTweenAnimationBuilder({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.tween,
    required this.duration,
    this.curve,
    required this.builder,
    this.onEnd,
    this.child,
  }) {
    _resolvedCurve = curve ?? _resolveCurve(resolveResourceOrNull('curve')) ?? Curves.linear;
  }

  /// The tween to animate.
  final Tween<T> tween;

  /// The duration of the animation.
  final Duration duration;

  /// The curve to apply to the animation.
  final Curve? curve;

  /// The builder function that creates the widget tree based on the animated value.
  final ValueWidgetBuilder<T> builder;

  /// Callback invoked when the animation ends.
  final VoidCallback? onEnd;

  /// The child widget to pass to the builder (optimization for static content).
  final Widget? child;

  @override
  Widget buildContent(BuildContext context) {
    return TweenAnimationBuilder<T>(
      tween: tween,
      duration: duration,
      curve: _resolvedCurve,
      builder: builder,
      onEnd: onEnd,
      child: child,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// TomOrientationBuilder
// ────────────────────────────────────────────────────────────────────────────

/// Tom-aware wrapper for [OrientationBuilder].
///
/// Rebuilds the widget tree when the device orientation changes.
/// Authorization applies to orientation-responsive content.
class TomOrientationBuilder extends TomBuilderBase {
  TomOrientationBuilder({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.builder,
  });

  /// The builder function that creates the widget tree based on orientation.
  final OrientationWidgetBuilder builder;

  @override
  Widget buildContent(BuildContext context) {
    return OrientationBuilder(
      builder: builder,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// TomLayoutBuilder
// ────────────────────────────────────────────────────────────────────────────

/// Tom-aware wrapper for [LayoutBuilder].
///
/// Rebuilds the widget tree with the parent's constraints.
/// Authorization applies to constraint-responsive content.
class TomLayoutBuilder extends TomBuilderBase {
  TomLayoutBuilder({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.builder,
  });

  /// The builder function that creates the widget tree based on constraints.
  final LayoutWidgetBuilder builder;

  @override
  Widget buildContent(BuildContext context) {
    return LayoutBuilder(
      builder: builder,
    );
  }
}

Curve? _resolveCurve(String? value) {
  switch (value?.toLowerCase()) {
    case 'linear':
      return Curves.linear;
    case 'ease':
      return Curves.ease;
    case 'easein':
      return Curves.easeIn;
    case 'easeout':
      return Curves.easeOut;
    case 'easeinout':
      return Curves.easeInOut;
    case 'decelerate':
      return Curves.decelerate;
    case 'fastoutslowin':
      return Curves.fastOutSlowIn;
    case 'bouncein':
      return Curves.bounceIn;
    case 'bounceout':
      return Curves.bounceOut;
    default:
      return null;
  }
}
