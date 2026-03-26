import 'package:flutter/cupertino.dart' hide RefreshCallback;
import 'package:flutter/material.dart';

import '../../groups/tom_widget_mixin.dart';
import '../../widget_base/tom_family_base.dart';

/// Tom wrapper for [CircularProgressIndicator].
///
/// Adds ID, group, and authorization.
class TomCircularProgressIndicator extends TomProgressBase {
  final double? value;
  final Color? backgroundColor;
  final Color? color;
  final Animation<Color?>? valueColor;
  final double? strokeWidth;
  final double strokeAlign;
  final String? semanticsLabel;
  final String? semanticsValue;
  final StrokeCap? strokeCap;

  const TomCircularProgressIndicator({
    super.key,
    super.tomId,
    super.tomGroup,
    this.value,
    this.backgroundColor,
    this.color,
    this.valueColor,
    this.strokeWidth,
    this.strokeAlign = 0.0,
    this.semanticsLabel,
    this.semanticsValue,
    this.strokeCap,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel =
        semanticsLabel ?? (tomId != null ? resolveResourceOrFail(context, 'label') : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedColor = color ?? resolveColorOrNull(context, 'color');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull(context, 'backgroundColor');
    final resolvedStrokeWidth =
      strokeWidth ?? resolveDoubleOrNull(context, 'strokeWidth') ?? 4.0;

    return CircularProgressIndicator(
      value: value,
      backgroundColor: resolvedBackgroundColor,
      color: resolvedColor,
      valueColor: valueColor,
      strokeWidth: resolvedStrokeWidth,
      strokeAlign: strokeAlign,
      semanticsLabel: resolvedLabel,
      semanticsValue: semanticsValue,
      strokeCap: strokeCap,
    );
  }
}

/// Tom wrapper for [LinearProgressIndicator].
///
/// Adds ID, group, and authorization.
class TomLinearProgressIndicator extends TomProgressBase {
  final double? value;
  final Color? backgroundColor;
  final Color? color;
  final Animation<Color?>? valueColor;
  final double? minHeight;
  final String? semanticsLabel;
  final String? semanticsValue;
  final BorderRadiusGeometry borderRadius;

  const TomLinearProgressIndicator({
    super.key,
    super.tomId,
    super.tomGroup,
    this.value,
    this.backgroundColor,
    this.color,
    this.valueColor,
    this.minHeight,
    this.semanticsLabel,
    this.semanticsValue,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel =
        semanticsLabel ?? (tomId != null ? resolveResourceOrFail(context, 'label') : null);

    // Phase 2: Resolve optional parameters from resources
    final resolvedColor = color ?? resolveColorOrNull(context, 'color');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull(context, 'backgroundColor');
    final resolvedMinHeight =
        minHeight ?? resolveDoubleOrNull(context, 'minHeight');

    return LinearProgressIndicator(
      value: value,
      backgroundColor: resolvedBackgroundColor,
      color: resolvedColor,
      valueColor: valueColor,
      minHeight: resolvedMinHeight,
      semanticsLabel: resolvedLabel,
      semanticsValue: semanticsValue,
      borderRadius: borderRadius,
    );
  }
}

/// Tom wrapper for [RefreshIndicator].
///
/// Adds ID, group, and authorization.
class TomRefreshIndicator extends TomProgressBase {
  final Widget child;
  final Future<void> Function() onRefresh;
  final double displacement;
  final double edgeOffset;
  final Color? color;
  final Color? backgroundColor;
  final ScrollNotificationPredicate notificationPredicate;
  final String? semanticsLabel;
  final String? semanticsValue;
  final double strokeWidth;
  final double triggerMode;

  const TomRefreshIndicator({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.child,
    required this.onRefresh,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
    this.color,
    this.backgroundColor,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.semanticsLabel,
    this.semanticsValue,
    this.strokeWidth = RefreshProgressIndicator.defaultStrokeWidth,
    this.triggerMode = 0,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel =
        semanticsLabel ?? (tomId != null ? resolveResourceOrFail(context, 'label') : null);

    // Phase 2: Resolve optional color parameters from resources
    final resolvedColor = color ?? resolveColorOrNull(context, 'color');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull(context, 'backgroundColor');

    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: displacement,
      edgeOffset: edgeOffset,
      color: resolvedColor,
      backgroundColor: resolvedBackgroundColor,
      notificationPredicate: notificationPredicate,
      semanticsLabel: resolvedLabel,
      semanticsValue: semanticsValue,
      strokeWidth: strokeWidth,
      child: child,
    );
  }
}

/// Tom wrapper for [CupertinoActivityIndicator].
///
/// iOS-style activity spinner. Adds ID, group, authorization,
/// and resource resolution.
class TomCupertinoActivityIndicator extends TomProgressBase {
  final bool animating;
  final double radius;
  final Color? color;

  const TomCupertinoActivityIndicator({
    super.key,
    super.tomId,
    super.tomGroup,
    this.animating = true,
    this.radius = 10.0,
    this.color,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional color parameter from resources
    final resolvedColor = color ?? resolveColorOrNull(context, 'color');

    return CupertinoActivityIndicator(
      animating: animating,
      radius: radius,
      color: resolvedColor,
    );
  }
}

// =============================================================================
// Section II: Additional Progress Widgets
// =============================================================================

/// Tom wrapper for [CupertinoActivityIndicator.partiallyRevealed].
///
/// Linear Cupertino progress indicator. Auth on progress display.
class TomCupertinoLinearActivityIndicator extends TomProgressBase {
  final double? value;
  final Color? color;
  final double? trackHeight;
  final EdgeInsetsGeometry? padding;

  const TomCupertinoLinearActivityIndicator({
    super.key,
    super.tomId,
    super.tomGroup,
    this.value,
    this.color,
    this.trackHeight,
    this.padding,
  });

  @override
  Widget buildContent(BuildContext context) {
    // CupertinoActivityIndicator doesn't have a linear variant by default.
    // Using MaterialLinearProgressIndicator with Cupertino styling.
    final resolvedValue = value ?? resolveDoubleOrNull(context, 'value') ?? 0.0;
    final resolvedColor = color ?? resolveColorOrNull(context, 'color') ??
        CupertinoTheme.of(context).primaryColor;
    final resolvedTrackHeight =
        trackHeight ?? resolveDoubleOrNull(context, 'trackHeight') ?? 4.0;
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull(context, 'padding') ?? EdgeInsets.zero;

    return Padding(
      padding: resolvedPadding,
      child: LinearProgressIndicator(
        value: resolvedValue,
        color: resolvedColor,
        minHeight: resolvedTrackHeight,
        backgroundColor: CupertinoColors.systemGrey5.resolveFrom(context),
      ),
    );
  }
}

/// Tom wrapper for [CupertinoSliverRefreshControl].
///
/// Pull-to-refresh for Cupertino scroll views. Auth can disable refresh.
class TomCupertinoSliverRefreshControl extends TomProgressBase {
  final double? refreshTriggerPullDistance;
  final double? refreshIndicatorExtent;
  final RefreshControlIndicatorBuilder? builder;
  final RefreshCallback? onRefresh;

  const TomCupertinoSliverRefreshControl({
    super.key,
    super.tomId,
    super.tomGroup,
    this.refreshTriggerPullDistance,
    this.refreshIndicatorExtent,
    this.builder = CupertinoSliverRefreshControl.buildRefreshIndicator,
    this.onRefresh,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedRefreshTriggerPullDistance = refreshTriggerPullDistance ??
        resolveDoubleOrNull(context, 'refreshTriggerPullDistance') ?? 100.0;
    final resolvedRefreshIndicatorExtent = refreshIndicatorExtent ??
        resolveDoubleOrNull(context, 'refreshIndicatorExtent') ?? 60.0;

    return CupertinoSliverRefreshControl(
      refreshTriggerPullDistance: resolvedRefreshTriggerPullDistance,
      refreshIndicatorExtent: resolvedRefreshIndicatorExtent,
      builder: builder,
      onRefresh: onRefresh,
    );
  }
}

/// Tom wrapper for [RefreshProgressIndicator].
///
/// Circular indicator used by RefreshIndicator. Auth controls refresh progress.
/// Uses extension pattern because parent may check `is CircularProgressIndicator`.
class TomRefreshProgressIndicator extends RefreshProgressIndicator
    with TomWidgetMixin {
  @override
  final String? tomId;
  @override
  final String? tomGroup;

  const TomRefreshProgressIndicator({
    super.key,
    this.tomId,
    this.tomGroup,
    super.value,
    super.backgroundColor,
    super.color,
    super.valueColor,
    super.strokeWidth,
    super.strokeAlign,
    super.semanticsLabel,
    super.semanticsValue,
    super.strokeCap,
  });
}
