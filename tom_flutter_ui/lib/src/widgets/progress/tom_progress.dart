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

  // Pre-resolved resource values
  late final String? _resolvedLabel;
  late final String? _resolvedSemanticsValue;
  late final double? _resolvedValue;
  late final Color? _resolvedColor;
  late final Color? _resolvedBackgroundColor;
  late final double _resolvedStrokeWidth;
  late final double _resolvedStrokeAlign;

  TomCircularProgressIndicator({
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
  }) {
    _resolvedLabel = semanticsLabel ?? resolveResourceOrNull('semanticsLabel') ?? (tomId != null ? resolveResourceOrFail('label') : null);
    _resolvedSemanticsValue = semanticsValue ?? resolveResourceOrNull('semanticsValue');
    _resolvedValue = value ?? resolveDoubleOrNull('value');
    _resolvedColor = color ?? resolveColorOrNull('color');
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
    _resolvedStrokeWidth = strokeWidth ?? resolveDoubleOrNull('strokeWidth') ?? 4.0;
    _resolvedStrokeAlign = resolveDoubleOrNull('strokeAlign') ?? strokeAlign;
  }

  @override
  Widget buildContent(BuildContext context) {
    return CircularProgressIndicator(
      value: _resolvedValue,
      backgroundColor: _resolvedBackgroundColor,
      color: _resolvedColor,
      valueColor: valueColor,
      strokeWidth: _resolvedStrokeWidth,
      strokeAlign: _resolvedStrokeAlign,
      semanticsLabel: _resolvedLabel,
      semanticsValue: _resolvedSemanticsValue,
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

  // Pre-resolved resource values
  late final String? _resolvedLabel;
  late final String? _resolvedSemanticsValue;
  late final double? _resolvedValue;
  late final Color? _resolvedColor;
  late final Color? _resolvedBackgroundColor;
  late final double? _resolvedMinHeight;
  late final BorderRadius? _resolvedBorderRadius;

  TomLinearProgressIndicator({
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
  }) {
    _resolvedLabel = semanticsLabel ?? resolveResourceOrNull('semanticsLabel') ?? (tomId != null ? resolveResourceOrFail('label') : null);
    _resolvedSemanticsValue = semanticsValue ?? resolveResourceOrNull('semanticsValue');
    _resolvedValue = value ?? resolveDoubleOrNull('value');
    _resolvedColor = color ?? resolveColorOrNull('color');
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
    _resolvedMinHeight = minHeight ?? resolveDoubleOrNull('minHeight');
    _resolvedBorderRadius = (borderRadius ?? _resolveBorderRadius('borderRadius')) as BorderRadius?;
  }

  @override
  Widget buildContent(BuildContext context) {
    return LinearProgressIndicator(
      value: _resolvedValue,
      backgroundColor: _resolvedBackgroundColor,
      color: _resolvedColor,
      valueColor: valueColor,
      minHeight: _resolvedMinHeight,
      semanticsLabel: _resolvedLabel,
      semanticsValue: _resolvedSemanticsValue,
      borderRadius: _resolvedBorderRadius ?? BorderRadius.zero,
    );
  }

  BorderRadiusGeometry? _resolveBorderRadius(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveBorderRadius(basePath!, suffix);
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

  // Pre-resolved resource values
  late final String? _resolvedLabel;
  late final String? _resolvedSemanticsValue;
  late final double _resolvedDisplacement;
  late final double _resolvedEdgeOffset;
  late final Color? _resolvedColor;
  late final Color? _resolvedBackgroundColor;
  late final double _resolvedStrokeWidth;

  TomRefreshIndicator({
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
  }) {
    _resolvedLabel = semanticsLabel ?? resolveResourceOrNull('semanticsLabel') ?? (tomId != null ? resolveResourceOrFail('label') : null);
    _resolvedSemanticsValue = semanticsValue ?? resolveResourceOrNull('semanticsValue');
    _resolvedDisplacement = resolveDoubleOrNull('displacement') ?? displacement;
    _resolvedEdgeOffset = resolveDoubleOrNull('edgeOffset') ?? edgeOffset;
    _resolvedColor = color ?? resolveColorOrNull('color');
    _resolvedBackgroundColor = backgroundColor ?? resolveColorOrNull('backgroundColor');
    _resolvedStrokeWidth = resolveDoubleOrNull('strokeWidth') ?? strokeWidth;
  }

  @override
  Widget buildContent(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: _resolvedDisplacement,
      edgeOffset: _resolvedEdgeOffset,
      color: _resolvedColor,
      backgroundColor: _resolvedBackgroundColor,
      notificationPredicate: notificationPredicate,
      semanticsLabel: _resolvedLabel,
      semanticsValue: _resolvedSemanticsValue,
      strokeWidth: _resolvedStrokeWidth,
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

  // Pre-resolved resource values
  late final bool _resolvedAnimating;
  late final double _resolvedRadius;
  late final Color? _resolvedColor;

  TomCupertinoActivityIndicator({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.animating = true,
    this.radius = 10.0,
    this.color,
  }) {
    _resolvedAnimating = resolveBoolOrNull('animating') ?? animating;
    _resolvedRadius = resolveDoubleOrNull('radius') ?? radius;
    _resolvedColor = color ?? resolveColorOrNull('color');
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoActivityIndicator(
      animating: _resolvedAnimating,
      radius: _resolvedRadius,
      color: _resolvedColor,
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

  // Pre-resolved resource values
  late final double _resolvedValue;
  late final double _resolvedTrackHeight;
  late final EdgeInsetsGeometry _resolvedPadding;

  TomCupertinoLinearActivityIndicator({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.value,
    this.color,
    this.trackHeight,
    this.padding,
  }) {
    _resolvedValue = value ?? resolveDoubleOrNull('value') ?? 0.0;
    _resolvedTrackHeight = trackHeight ?? resolveDoubleOrNull('trackHeight') ?? 4.0;
    _resolvedPadding = padding ?? resolveEdgeInsetsOrNull('padding') ?? EdgeInsets.zero;
  }

  @override
  Widget buildContent(BuildContext context) {
    // CupertinoActivityIndicator doesn't have a linear variant by default.
    // Using MaterialLinearProgressIndicator with Cupertino styling.
    final resolvedColor = color ?? resolveColorOrNull('color') ??
        CupertinoTheme.of(context).primaryColor;

    return Padding(
      padding: _resolvedPadding,
      child: LinearProgressIndicator(
        value: _resolvedValue,
        color: resolvedColor,
        minHeight: _resolvedTrackHeight,
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

  // Pre-resolved resource values
  late final double _resolvedRefreshTriggerPullDistance;
  late final double _resolvedRefreshIndicatorExtent;

  TomCupertinoSliverRefreshControl({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    this.refreshTriggerPullDistance,
    this.refreshIndicatorExtent,
    this.builder = CupertinoSliverRefreshControl.buildRefreshIndicator,
    this.onRefresh,
  }) {
    _resolvedRefreshTriggerPullDistance = refreshTriggerPullDistance ?? resolveDoubleOrNull('refreshTriggerPullDistance') ?? 100.0;
    _resolvedRefreshIndicatorExtent = refreshIndicatorExtent ?? resolveDoubleOrNull('refreshIndicatorExtent') ?? 60.0;
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoSliverRefreshControl(
      refreshTriggerPullDistance: _resolvedRefreshTriggerPullDistance,
      refreshIndicatorExtent: _resolvedRefreshIndicatorExtent,
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

  @override
  final TomScope? scope;

  @override
  final String? basePath;

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
  }) : basePath = TomCtr.resolvePath(tomId, scope),
       super(
          value: value,
          backgroundColor: backgroundColor ?? TomCtr.color(_p(tomId, scope, 'backgroundColor')),
          color: color ?? TomCtr.color(_p(tomId, scope, 'color')),
          strokeWidth: strokeWidth ?? TomCtr.doubleVal(_p(tomId, scope, 'strokeWidth')) ?? RefreshProgressIndicator.defaultStrokeWidth,
          semanticsLabel: semanticsLabel ?? TomCtr.textOrNull(_p(tomId, scope, 'semanticsLabel')),
          semanticsValue: semanticsValue ?? TomCtr.textOrNull(_p(tomId, scope, 'semanticsValue')),
        ) {
    tomGroup?.register(this);
  }

  /// Helper to build full path with suffix.
  static String? _p(String? tomId, TomScope? scope, String suffix) {
    final base = TomCtr.resolvePath(tomId, scope);
    return base != null ? '$base.$suffix' : null;
  }
}
