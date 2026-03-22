import 'package:flutter/material.dart';

import '../../widget_base/tom_family_base.dart';

/// Tom wrapper for [Slider].
///
/// Adds ID, group, authorization, and resource resolution for label.
class TomSlider extends TomSliderBase {
  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final WidgetStateProperty<Color?>? overlayColor;
  final SemanticFormatterCallback? semanticFormatterCallback;
  final FocusNode? focusNode;
  final bool autofocus;
  final SliderInteraction? allowedInteraction;

  const TomSlider({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.value,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.label,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.overlayColor,
    this.semanticFormatterCallback,
    this.focusNode,
    this.autofocus = false,
    this.allowedInteraction,
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel = label ?? (tomId != null ? resolveResource(context, 'label') : null);

    return Slider(
      value: value,
      onChanged: onChanged,
      onChangeStart: onChangeStart,
      onChangeEnd: onChangeEnd,
      min: min,
      max: max,
      divisions: divisions,
      label: resolvedLabel,
      activeColor: activeColor,
      inactiveColor: inactiveColor,
      thumbColor: thumbColor,
      overlayColor: overlayColor,
      semanticFormatterCallback: semanticFormatterCallback,
      focusNode: focusNode,
      autofocus: autofocus,
      allowedInteraction: allowedInteraction,
    );
  }
}

/// Tom wrapper for [RangeSlider].
///
/// Adds ID, group, authorization, and resource resolution for labels.
class TomRangeSlider extends TomSliderBase {
  final RangeValues values;
  final ValueChanged<RangeValues>? onChanged;
  final ValueChanged<RangeValues>? onChangeStart;
  final ValueChanged<RangeValues>? onChangeEnd;
  final double min;
  final double max;
  final int? divisions;
  final RangeLabels? labels;
  final Color? activeColor;
  final Color? inactiveColor;
  final WidgetStateProperty<Color?>? overlayColor;
  final SemanticFormatterCallback? semanticFormatterCallback;

  const TomRangeSlider({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.values,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.labels,
    this.activeColor,
    this.inactiveColor,
    this.overlayColor,
    this.semanticFormatterCallback,
  });

  @override
  Widget buildContent(BuildContext context) {
    return RangeSlider(
      values: values,
      onChanged: onChanged,
      onChangeStart: onChangeStart,
      onChangeEnd: onChangeEnd,
      min: min,
      max: max,
      divisions: divisions,
      labels: labels,
      activeColor: activeColor,
      inactiveColor: inactiveColor,
      overlayColor: overlayColor,
      semanticFormatterCallback: semanticFormatterCallback,
    );
  }
}
