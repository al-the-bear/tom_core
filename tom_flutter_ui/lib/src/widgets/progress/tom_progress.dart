import 'package:flutter/cupertino.dart' hide RefreshCallback;
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

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
    super.authorizer,
    super.uiStateController,
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
    _resolvedLabel =
        semanticsLabel ??
        TomCtr.textOrNull(basePath, 'semanticsLabel') ??
        (tomId != null ? TomCtr.textOrFail(basePath, 'label') : null);
    _resolvedSemanticsValue =
        semanticsValue ?? TomCtr.textOrNull(basePath, 'semanticsValue');
    _resolvedValue = value ?? TomCtr.doubleVal(basePath, 'value');
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
    _resolvedBackgroundColor =
        backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedStrokeWidth =
        strokeWidth ?? TomCtr.doubleVal(basePath, 'strokeWidth') ?? 4.0;
    _resolvedStrokeAlign =
        TomCtr.doubleVal(basePath, 'strokeAlign') ?? strokeAlign;
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
    super.authorizer,
    super.uiStateController,
    this.value,
    this.backgroundColor,
    this.color,
    this.valueColor,
    this.minHeight,
    this.semanticsLabel,
    this.semanticsValue,
    this.borderRadius,
  }) {
    _resolvedLabel =
        semanticsLabel ??
        TomCtr.textOrNull(basePath, 'semanticsLabel') ??
        (tomId != null ? TomCtr.textOrFail(basePath, 'label') : null);
    _resolvedSemanticsValue =
        semanticsValue ?? TomCtr.textOrNull(basePath, 'semanticsValue');
    _resolvedValue = value ?? TomCtr.doubleVal(basePath, 'value');
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
    _resolvedBackgroundColor =
        backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedMinHeight = minHeight ?? TomCtr.doubleVal(basePath, 'minHeight');
    _resolvedBorderRadius =
        (borderRadius ?? _resolveBorderRadius('borderRadius')) as BorderRadius?;
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
  final RefreshIndicatorTriggerMode triggerMode;

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
    super.authorizer,
    super.uiStateController,
    required this.child,
    required Future<void> Function() onRefresh,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
    this.color,
    this.backgroundColor,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.semanticsLabel,
    this.semanticsValue,
    this.strokeWidth = RefreshProgressIndicator.defaultStrokeWidth,
    this.triggerMode = RefreshIndicatorTriggerMode.onEdge,
  }) : onRefresh = ScopeCapture(scope: scope).wrap0(onRefresh) {
    _resolvedLabel =
        semanticsLabel ??
        TomCtr.textOrNull(basePath, 'semanticsLabel') ??
        (tomId != null ? TomCtr.textOrFail(basePath, 'label') : null);
    _resolvedSemanticsValue =
        semanticsValue ?? TomCtr.textOrNull(basePath, 'semanticsValue');
    _resolvedDisplacement =
        TomCtr.doubleVal(basePath, 'displacement') ?? displacement;
    _resolvedEdgeOffset =
        TomCtr.doubleVal(basePath, 'edgeOffset') ?? edgeOffset;
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
    _resolvedBackgroundColor =
        backgroundColor ?? TomCtr.color(basePath, 'backgroundColor');
    _resolvedStrokeWidth =
        TomCtr.doubleVal(basePath, 'strokeWidth') ?? strokeWidth;
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
      // Forward the typed trigger mode.
      triggerMode: triggerMode,
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
    super.authorizer,
    super.uiStateController,
    this.animating = true,
    this.radius = 10.0,
    this.color,
  }) {
    _resolvedAnimating = TomCtr.boolVal(basePath, 'animating') ?? animating;
    _resolvedRadius = TomCtr.doubleVal(basePath, 'radius') ?? radius;
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
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
  late final Color? _resolvedColor;

  TomCupertinoLinearActivityIndicator({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    this.value,
    this.color,
    this.trackHeight,
    this.padding,
  }) {
    _resolvedValue = value ?? TomCtr.doubleVal(basePath, 'value') ?? 0.0;
    _resolvedTrackHeight =
        trackHeight ?? TomCtr.doubleVal(basePath, 'trackHeight') ?? 4.0;
    _resolvedPadding =
        padding ?? TomCtr.edgeInsets(basePath, 'padding') ?? EdgeInsets.zero;
    _resolvedColor = color ?? TomCtr.color(basePath, 'color');
  }

  @override
  Widget buildContent(BuildContext context) {
    // CupertinoActivityIndicator doesn't have a linear variant by default.
    // Using MaterialLinearProgressIndicator with Cupertino styling.
    final resolvedColor =
        _resolvedColor ?? CupertinoTheme.of(context).primaryColor;

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
    super.authorizer,
    super.uiStateController,
    this.refreshTriggerPullDistance,
    this.refreshIndicatorExtent,
    RefreshControlIndicatorBuilder? builder =
        CupertinoSliverRefreshControl.buildRefreshIndicator,
    RefreshCallback? onRefresh,
  }) : builder = ScopeCapture(scope: scope).wrap5n(builder),
       onRefresh = ScopeCapture(scope: scope).wrap0n(onRefresh) {
    _resolvedRefreshTriggerPullDistance =
        refreshTriggerPullDistance ??
        TomCtr.doubleVal(basePath, 'refreshTriggerPullDistance') ??
        100.0;
    _resolvedRefreshIndicatorExtent =
        refreshIndicatorExtent ??
        TomCtr.doubleVal(basePath, 'refreshIndicatorExtent') ??
        60.0;
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
  final TomAuthorizationGroup? tomGroup;

  @override
  final TomScope? scope;

  @override
  final TomAuthorizer? authorizer;

  @override
  final TomUIStateController? uiStateController;

  @override
  final String? basePath;

  TomRefreshProgressIndicator({
    super.key,
    this.tomId,
    this.tomGroup,
    this.scope,
    this.authorizer,
    this.uiStateController,
    super.value,
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
         backgroundColor:
             backgroundColor ??
             TomCtr.color(_p(tomId, scope, 'backgroundColor')),
         color: color ?? TomCtr.color(_p(tomId, scope, 'color')),
         strokeWidth:
             strokeWidth ??
             TomCtr.doubleVal(_p(tomId, scope, 'strokeWidth')) ??
             RefreshProgressIndicator.defaultStrokeWidth,
         semanticsLabel:
             semanticsLabel ??
             TomCtr.textOrNull(_p(tomId, scope, 'semanticsLabel')),
         semanticsValue:
             semanticsValue ??
             TomCtr.textOrNull(_p(tomId, scope, 'semanticsValue')),
       ) {
    tomGroup?.register(this);
  }

  /// Helper to build full path with suffix.
  static String? _p(String? tomId, TomScope? scope, String suffix) {
    final base = TomCtr.resolvePath(tomId, scope);
    return base != null ? '$base.$suffix' : null;
  }
}
