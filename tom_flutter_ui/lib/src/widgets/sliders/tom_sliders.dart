import 'package:flutter/cupertino.dart';
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

  // Pre-resolved resource values
  late final String? _resolvedLabel;
  late final double _resolvedMin;
  late final double _resolvedMax;
  late final int? _resolvedDivisions;
  late final Color? _resolvedActiveColor;
  late final Color? _resolvedInactiveColor;
  late final Color? _resolvedThumbColor;
  late final bool _resolvedAutofocus;

  TomSlider({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
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
  }) {
    _resolvedLabel = label ?? resolveResourceOrNull('label');
    _resolvedMin = resolveDoubleOrNull('min') ?? min;
    _resolvedMax = resolveDoubleOrNull('max') ?? max;
    _resolvedDivisions = divisions ?? resolveIntOrNull('divisions');
    _resolvedActiveColor = activeColor ?? resolveColorOrNull('activeColor');
    _resolvedInactiveColor = inactiveColor ?? resolveColorOrNull('inactiveColor');
    _resolvedThumbColor = thumbColor ?? resolveColorOrNull('thumbColor');
    _resolvedAutofocus = resolveBoolOrNull('autofocus') ?? autofocus;
  }

  @override
  Widget buildContent(BuildContext context) {
    return Slider(
      value: value,
      onChanged: onChanged,
      onChangeStart: onChangeStart,
      onChangeEnd: onChangeEnd,
      min: _resolvedMin,
      max: _resolvedMax,
      divisions: _resolvedDivisions,
      label: _resolvedLabel,
      activeColor: _resolvedActiveColor,
      inactiveColor: _resolvedInactiveColor,
      thumbColor: _resolvedThumbColor,
      overlayColor: overlayColor,
      semanticFormatterCallback: semanticFormatterCallback,
      focusNode: focusNode,
      autofocus: _resolvedAutofocus,
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

  // Pre-resolved resource values
  late final double _resolvedMin;
  late final double _resolvedMax;
  late final int? _resolvedDivisions;
  late final Color? _resolvedActiveColor;
  late final Color? _resolvedInactiveColor;

  TomRangeSlider({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
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
  }) {
    _resolvedMin = resolveDoubleOrNull('min') ?? min;
    _resolvedMax = resolveDoubleOrNull('max') ?? max;
    _resolvedDivisions = divisions ?? resolveIntOrNull('divisions');
    _resolvedActiveColor = activeColor ?? resolveColorOrNull('activeColor');
    _resolvedInactiveColor = inactiveColor ?? resolveColorOrNull('inactiveColor');
  }

  @override
  Widget buildContent(BuildContext context) {
    return RangeSlider(
      values: values,
      onChanged: onChanged,
      onChangeStart: onChangeStart,
      onChangeEnd: onChangeEnd,
      min: _resolvedMin,
      max: _resolvedMax,
      divisions: _resolvedDivisions,
      labels: labels,
      activeColor: _resolvedActiveColor,
      inactiveColor: _resolvedInactiveColor,
      overlayColor: overlayColor,
      semanticFormatterCallback: semanticFormatterCallback,
    );
  }
}

/// Tom wrapper for [CupertinoSlider].
///
/// iOS-style slider. Adds ID, group, authorization,
/// and resource resolution.
class TomCupertinoSlider extends TomSliderBase {
  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final int? divisions;
  final Color? activeColor;
  final Color thumbColor;

  // Pre-resolved resource values
  late final double _resolvedMin;
  late final double _resolvedMax;
  late final int? _resolvedDivisions;
  late final Color? _resolvedActiveColor;
  late final Color _resolvedThumbColor;

  TomCupertinoSlider({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    required this.value,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.activeColor,
    this.thumbColor = CupertinoColors.white,
  }) {
    _resolvedMin = resolveDoubleOrNull('min') ?? min;
    _resolvedMax = resolveDoubleOrNull('max') ?? max;
    _resolvedDivisions = divisions ?? resolveIntOrNull('divisions');
    _resolvedActiveColor = activeColor ?? resolveColorOrNull('activeColor');
    _resolvedThumbColor = resolveColorOrNull('thumbColor') ?? thumbColor;
  }

  @override
  Widget buildContent(BuildContext context) {
    return CupertinoSlider(
      value: value,
      onChanged: onChanged,
      onChangeStart: onChangeStart,
      onChangeEnd: onChangeEnd,
      min: _resolvedMin,
      max: _resolvedMax,
      divisions: _resolvedDivisions,
      activeColor: _resolvedActiveColor,
      thumbColor: _resolvedThumbColor,
    );
  }
}
