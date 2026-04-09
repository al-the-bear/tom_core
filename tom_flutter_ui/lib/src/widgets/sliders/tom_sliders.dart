import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_construction_helpers.dart';

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
    ValueChanged<double>? onChanged,
    ValueChanged<double>? onChangeStart,
    ValueChanged<double>? onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.label,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.overlayColor,
    SemanticFormatterCallback? semanticFormatterCallback,
    this.focusNode,
    this.autofocus = false,
    this.allowedInteraction,
  }) : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged),
       onChangeStart = InScopeBuilder(scope: scope).wrap1n(onChangeStart),
       onChangeEnd = InScopeBuilder(scope: scope).wrap1n(onChangeEnd),
       semanticFormatterCallback = InScopeBuilder(scope: scope).wrap1n(semanticFormatterCallback) {
    _resolvedLabel = label ?? TomCtr.textOrNull(basePath, 'label');
    _resolvedMin = TomCtr.doubleVal(basePath, 'min') ?? min;
    _resolvedMax = TomCtr.doubleVal(basePath, 'max') ?? max;
    _resolvedDivisions = divisions ?? TomCtr.intVal(basePath, 'divisions');
    _resolvedActiveColor = activeColor ?? TomCtr.color(basePath, 'activeColor');
    _resolvedInactiveColor = inactiveColor ?? TomCtr.color(basePath, 'inactiveColor');
    _resolvedThumbColor = thumbColor ?? TomCtr.color(basePath, 'thumbColor');
    _resolvedAutofocus = TomCtr.boolVal(basePath, 'autofocus') ?? autofocus;
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
    ValueChanged<RangeValues>? onChanged,
    ValueChanged<RangeValues>? onChangeStart,
    ValueChanged<RangeValues>? onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.labels,
    this.activeColor,
    this.inactiveColor,
    this.overlayColor,
    SemanticFormatterCallback? semanticFormatterCallback,
  }) : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged),
       onChangeStart = InScopeBuilder(scope: scope).wrap1n(onChangeStart),
       onChangeEnd = InScopeBuilder(scope: scope).wrap1n(onChangeEnd),
       semanticFormatterCallback = InScopeBuilder(scope: scope).wrap1n(semanticFormatterCallback) {
    _resolvedMin = TomCtr.doubleVal(basePath, 'min') ?? min;
    _resolvedMax = TomCtr.doubleVal(basePath, 'max') ?? max;
    _resolvedDivisions = divisions ?? TomCtr.intVal(basePath, 'divisions');
    _resolvedActiveColor = activeColor ?? TomCtr.color(basePath, 'activeColor');
    _resolvedInactiveColor = inactiveColor ?? TomCtr.color(basePath, 'inactiveColor');
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
    ValueChanged<double>? onChanged,
    ValueChanged<double>? onChangeStart,
    ValueChanged<double>? onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.activeColor,
    this.thumbColor = CupertinoColors.white,
  }) : onChanged = InScopeBuilder(scope: scope).wrap1n(onChanged),
       onChangeStart = InScopeBuilder(scope: scope).wrap1n(onChangeStart),
       onChangeEnd = InScopeBuilder(scope: scope).wrap1n(onChangeEnd) {
    _resolvedMin = TomCtr.doubleVal(basePath, 'min') ?? min;
    _resolvedMax = TomCtr.doubleVal(basePath, 'max') ?? max;
    _resolvedDivisions = divisions ?? TomCtr.intVal(basePath, 'divisions');
    _resolvedActiveColor = activeColor ?? TomCtr.color(basePath, 'activeColor');
    _resolvedThumbColor = TomCtr.color(basePath, 'thumbColor') ?? thumbColor;
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
