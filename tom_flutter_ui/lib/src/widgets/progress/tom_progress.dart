import 'package:flutter/cupertino.dart' hide RefreshCallback;
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../groups/tom_ui_group.dart';
import '../../groups/tom_widget_mixin.dart';
import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_style_resolvers.dart';

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
    super.scope,
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
        semanticsLabel ??
            resolveResourceOrNull('semanticsLabel') ??
            (tomId != null ? resolveResourceOrFail('label') : null);
    final resolvedSemanticsValue =
        semanticsValue ?? resolveResourceOrNull('semanticsValue');

    // Phase 2: Resolve optional parameters from resources
    final resolvedValue = value ?? resolveDoubleOrNull('value');
    final resolvedColor = color ?? resolveColorOrNull('color');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedStrokeWidth =
      strokeWidth ?? resolveDoubleOrNull('strokeWidth') ?? 4.0;
    final resolvedStrokeAlign =
        resolveDoubleOrNull('strokeAlign') ?? strokeAlign;

    return CircularProgressIndicator(
      value: resolvedValue,
      backgroundColor: resolvedBackgroundColor,
      color: resolvedColor,
      valueColor: valueColor,
      strokeWidth: resolvedStrokeWidth,
      strokeAlign: resolvedStrokeAlign,
      semanticsLabel: resolvedLabel,
      semanticsValue: resolvedSemanticsValue,
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
  final BorderRadiusGeometry? borderRadius;

  const TomLinearProgressIndicator({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.value,
    this.backgroundColor,
    this.color,
    this.valueColor,
    this.minHeight,
    this.semanticsLabel,
    this.semanticsValue,
    this.borderRadius,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel =
      semanticsLabel ??
        resolveResourceOrNull('semanticsLabel') ??
        (tomId != null ? resolveResourceOrFail('label') : null);
    final resolvedSemanticsValue =
      semanticsValue ?? resolveResourceOrNull('semanticsValue');

    // Phase 2: Resolve optional parameters from resources
    final resolvedValue = value ?? resolveDoubleOrNull('value');
    final resolvedColor = color ?? resolveColorOrNull('color');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedMinHeight =
        minHeight ?? resolveDoubleOrNull('minHeight');

    return LinearProgressIndicator(
      value: resolvedValue,
      backgroundColor: resolvedBackgroundColor,
      color: resolvedColor,
      valueColor: valueColor,
      minHeight: resolvedMinHeight,
      semanticsLabel: resolvedLabel,
      semanticsValue: resolvedSemanticsValue,
      borderRadius: borderRadius ?? _resolveBorderRadius('borderRadius') ?? BorderRadius.zero,
    );
  }

  BorderRadiusGeometry? _resolveBorderRadius(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderRadius(basePath, suffix);
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
    super.scope,
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
      semanticsLabel ??
        resolveResourceOrNull('semanticsLabel') ??
        (tomId != null ? resolveResourceOrFail('label') : null);
    final resolvedSemanticsValue =
      semanticsValue ?? resolveResourceOrNull('semanticsValue');

    // Phase 2: Resolve optional color parameters from resources
    final resolvedDisplacement =
      resolveDoubleOrNull('displacement') ?? displacement;
    final resolvedEdgeOffset =
      resolveDoubleOrNull('edgeOffset') ?? edgeOffset;
    final resolvedColor = color ?? resolveColorOrNull('color');
    final resolvedBackgroundColor =
        backgroundColor ?? resolveColorOrNull('backgroundColor');
    final resolvedStrokeWidth =
      resolveDoubleOrNull('strokeWidth') ?? strokeWidth;

    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: resolvedDisplacement,
      edgeOffset: resolvedEdgeOffset,
      color: resolvedColor,
      backgroundColor: resolvedBackgroundColor,
      notificationPredicate: notificationPredicate,
      semanticsLabel: resolvedLabel,
      semanticsValue: resolvedSemanticsValue,
      strokeWidth: resolvedStrokeWidth,
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
    super.scope,
    this.animating = true,
    this.radius = 10.0,
    this.color,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional color parameter from resources
    final resolvedAnimating =
        resolveBoolOrNull('animating') ?? animating;
    final resolvedRadius =
        resolveDoubleOrNull('radius') ?? radius;
    final resolvedColor = color ?? resolveColorOrNull('color');

    return CupertinoActivityIndicator(
      animating: resolvedAnimating,
      radius: resolvedRadius,
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
    super.scope,
    this.value,
    this.color,
    this.trackHeight,
    this.padding,
  });

  @override
  Widget buildContent(BuildContext context) {
    // CupertinoActivityIndicator doesn't have a linear variant by default.
    // Using MaterialLinearProgressIndicator with Cupertino styling.
    final resolvedValue = value ?? resolveDoubleOrNull('value') ?? 0.0;
    final resolvedColor = color ?? resolveColorOrNull('color') ??
        CupertinoTheme.of(context).primaryColor;
    final resolvedTrackHeight =
        trackHeight ?? resolveDoubleOrNull('trackHeight') ?? 4.0;
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding') ?? EdgeInsets.zero;

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
    super.scope,
    this.refreshTriggerPullDistance,
    this.refreshIndicatorExtent,
    this.builder = CupertinoSliverRefreshControl.buildRefreshIndicator,
    this.onRefresh,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedRefreshTriggerPullDistance = refreshTriggerPullDistance ??
        resolveDoubleOrNull('refreshTriggerPullDistance') ?? 100.0;
    final resolvedRefreshIndicatorExtent = refreshIndicatorExtent ??
        resolveDoubleOrNull('refreshIndicatorExtent') ?? 60.0;

    return CupertinoSliverRefreshControl(
      refreshTriggerPullDistance: resolvedRefreshTriggerPullDistance,
      refreshIndicatorExtent: resolvedRefreshIndicatorExtent,
      builder: builder,
      onRefresh: onRefresh,
    );
  }
}

/// Tom wrapper for [RefreshProgressIndicator] with construction-time resource resolution.
///
/// Circular indicator used by RefreshIndicator. Auth controls refresh progress.
/// Uses extension pattern because parent may check `is CircularProgressIndicator`.
///
/// Resources are resolved at construction time:
/// - [semanticsLabel] — resolved from `$tomId.semanticsLabel`
/// - [semanticsValue] — resolved from `$tomId.semanticsValue`
/// - [color] — resolved from `$tomId.color`
/// - [backgroundColor] — resolved from `$tomId.backgroundColor`
/// - [strokeWidth] — resolved from `$tomId.strokeWidth`
class TomRefreshProgressIndicator extends RefreshProgressIndicator
    with TomWidgetMixin {
  @override
  final String? tomId;
  @override
  final TomUIGroup? tomGroup;

  /// Optional explicit scope for resource resolution.
  final TomScope? scope;

  TomRefreshProgressIndicator({
    super.key,
    this.tomId,
    this.tomGroup,
    this.scope,
    double? value,
    Color? backgroundColor,
    Color? color,
    super.valueColor,
    double? strokeWidth,
    super.strokeAlign,
    String? semanticsLabel,
    String? semanticsValue,
    super.strokeCap,
  }) : super(
          value: value,
          backgroundColor: backgroundColor ?? TomCtr.color(_p(tomId, scope, 'backgroundColor')),
          color: color ?? TomCtr.color(_p(tomId, scope, 'color')),
          strokeWidth: strokeWidth ?? TomCtr.doubleVal(_p(tomId, scope, 'strokeWidth')) ?? RefreshProgressIndicator.defaultStrokeWidth,
          semanticsLabel: semanticsLabel ?? TomCtr.textOrNull(_p(tomId, scope, 'semanticsLabel')),
          semanticsValue: semanticsValue ?? TomCtr.textOrNull(_p(tomId, scope, 'semanticsValue')),
        );

  /// Helper to build full path with suffix.
  static String? _p(String? tomId, TomScope? scope, String suffix) {
    final base = TomCtr.resolvePath(tomId, scope);
    return base != null ? '$base.$suffix' : null;
  }
}
