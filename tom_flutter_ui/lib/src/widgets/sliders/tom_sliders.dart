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
  });

  @override
  Widget buildContent(BuildContext context) {
    final resolvedLabel =
      label ?? resolveResourceOrNull('label');

    // Phase 2: Resolve optional color parameters from resources
    final resolvedMin =
      resolveDoubleOrNull('min') ?? min;
    final resolvedMax =
      resolveDoubleOrNull('max') ?? max;
    final resolvedDivisions =
      divisions ?? resolveIntOrNull('divisions');
    final resolvedActiveColor =
        activeColor ?? resolveColorOrNull('activeColor');
    final resolvedInactiveColor =
        inactiveColor ?? resolveColorOrNull('inactiveColor');
    final resolvedThumbColor =
        thumbColor ?? resolveColorOrNull('thumbColor');
    final resolvedAutofocus =
      resolveBoolOrNull('autofocus') ?? autofocus;

    return Slider(
      value: value,
      onChanged: onChanged,
      onChangeStart: onChangeStart,
      onChangeEnd: onChangeEnd,
      min: resolvedMin,
      max: resolvedMax,
      divisions: resolvedDivisions,
      label: resolvedLabel,
      activeColor: resolvedActiveColor,
      inactiveColor: resolvedInactiveColor,
      thumbColor: resolvedThumbColor,
      overlayColor: overlayColor,
      semanticFormatterCallback: semanticFormatterCallback,
      focusNode: focusNode,
      autofocus: resolvedAutofocus,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedMin = resolveDoubleOrNull('min') ?? min;
    final resolvedMax = resolveDoubleOrNull('max') ?? max;
    final resolvedDivisions = divisions ?? resolveIntOrNull('divisions');
    final resolvedActiveColor =
        activeColor ?? resolveColorOrNull('activeColor');
    final resolvedInactiveColor =
        inactiveColor ?? resolveColorOrNull('inactiveColor');

    return RangeSlider(
      values: values,
      onChanged: onChanged,
      onChangeStart: onChangeStart,
      onChangeEnd: onChangeEnd,
      min: resolvedMin,
      max: resolvedMax,
      divisions: resolvedDivisions,
      labels: labels,
      activeColor: resolvedActiveColor,
      inactiveColor: resolvedInactiveColor,
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
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedMin = resolveDoubleOrNull('min') ?? min;
    final resolvedMax = resolveDoubleOrNull('max') ?? max;
    final resolvedDivisions = divisions ?? resolveIntOrNull('divisions');
    final resolvedActiveColor =
        activeColor ?? resolveColorOrNull('activeColor');
    final resolvedThumbColor =
        resolveColorOrNull('thumbColor') ?? thumbColor;

    return CupertinoSlider(
      value: value,
      onChanged: onChanged,
      onChangeStart: onChangeStart,
      onChangeEnd: onChangeEnd,
      min: resolvedMin,
      max: resolvedMax,
      divisions: resolvedDivisions,
      activeColor: resolvedActiveColor,
      thumbColor: resolvedThumbColor,
    );
  }
}
