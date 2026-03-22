import 'package:flutter/material.dart';

import '../../widget_base/tom_family_base.dart';

/// Tom wrapper for [CircularProgressIndicator].
///
/// Adds ID, group, and authorization.
class TomCircularProgressIndicator extends TomProgressBase {
  final double? value;
  final Color? backgroundColor;
  final Color? color;
  final Animation<Color?>? valueColor;
  final double strokeWidth;
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
    this.strokeWidth = 4.0,
    this.strokeAlign = 0.0,
    this.semanticsLabel,
    this.semanticsValue,
    this.strokeCap,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel =
        semanticsLabel ?? (tomId != null ? resolveResource(context, 'label') : null);

    return CircularProgressIndicator(
      value: value,
      backgroundColor: backgroundColor,
      color: color,
      valueColor: valueColor,
      strokeWidth: strokeWidth,
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
        semanticsLabel ?? (tomId != null ? resolveResource(context, 'label') : null);

    return LinearProgressIndicator(
      value: value,
      backgroundColor: backgroundColor,
      color: color,
      valueColor: valueColor,
      minHeight: minHeight,
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
  final RefreshCallback onRefresh;
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
        semanticsLabel ?? (tomId != null ? resolveResource(context, 'label') : null);

    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: displacement,
      edgeOffset: edgeOffset,
      color: color,
      backgroundColor: backgroundColor,
      notificationPredicate: notificationPredicate,
      semanticsLabel: resolvedLabel,
      semanticsValue: semanticsValue,
      strokeWidth: strokeWidth,
      child: child,
    );
  }
}
