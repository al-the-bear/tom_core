library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../decoration/tom_generic_field_decoration_mixin.dart';
import '../style/tom_form_style.dart';
import '../style/tom_form_style_scope.dart';
import '../tom_form.dart';
import 'tom_field_widget_adapter.dart';

// ---------------------------------------------------------------------------
// Range value type
// ---------------------------------------------------------------------------

/// A simple `(low, high)` pair used as the value type for the range
/// slider fields. Equatable so observers see a real change only when at
/// least one endpoint moves.
class NumRange<T extends num> {
  final T low;
  final T high;
  const NumRange(this.low, this.high);

  @override
  bool operator ==(Object other) =>
      other is NumRange<T> && other.low == low && other.high == high;

  @override
  int get hashCode => Object.hash(low, high);

  @override
  String toString() => '($low, $high)';
}

// ---------------------------------------------------------------------------
// TomFormIntRangeField — Abstract Int-range field
// ---------------------------------------------------------------------------

abstract class TomFormIntRangeField extends TomField<NumRange<int>> {
  final String? labelTextOverride;
  final String? descriptionTextOverride;
  final int min;
  final int max;

  TomFormIntRangeField(
    super.tomId,
    super.initialValue, {
    required this.min,
    required this.max,
    this.labelTextOverride,
    this.descriptionTextOverride,
    super.form,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
    super.actionIcon,
    super.actionIconTooltip,
    super.onActionIconPressed,
  }) : assert(max > min, 'TomFormIntRangeField: max must be > min');

  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');
}

@tomReflector
class TomFormIntRangeSlider extends TomFormIntRangeField
    with TomGenericFieldDecorationMixin<NumRange<int>> {
  final int? divisions;

  TomFormIntRangeSlider(
    super.tomId,
    super.initialValue, {
    required super.min,
    required super.max,
    this.divisions,
    super.labelTextOverride,
    super.descriptionTextOverride,
    super.form,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
    super.actionIcon,
    super.actionIconTooltip,
    super.onActionIconPressed,
  });

  @override
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.sliderStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
    field: this,
    child: _TomFormIntRangeSliderWidget(field: this),
  );
}

class _TomFormIntRangeSliderWidget extends StatefulWidget {
  final TomFormIntRangeSlider field;
  const _TomFormIntRangeSliderWidget({required this.field});

  @override
  State<_TomFormIntRangeSliderWidget> createState() =>
      _TomFormIntRangeSliderWidgetState();
}

class _TomFormIntRangeSliderWidgetState
    extends State<_TomFormIntRangeSliderWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormIntRangeSlider get field => widget.field;

  @override
  void initState() {
    super.initState();
    _observer =
        field >>
        (_) {
          if (mounted) setState(() {});
        };
    field.validationListenable.addListener(_onValidationChanged);
  }

  void _onValidationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    field.validationListenable.removeListener(_onValidationChanged);
    field.removeObserver(_observer);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = field.get();
    final low = value.low.clamp(field.min, field.max).toDouble();
    final high = value.high.clamp(field.min, field.max).toDouble();
    final divisions = field.divisions ?? (field.max - field.min);
    final slider = RangeSlider(
      values: RangeValues(low, high),
      min: field.min.toDouble(),
      max: field.max.toDouble(),
      divisions: divisions > 0 ? divisions : null,
      labels: RangeLabels('${value.low}', '${value.high}'),
      onChanged: field.isEditable
          ? (v) => field.setValue(NumRange<int>(v.start.round(), v.end.round()))
          : null,
    );
    return field.decorateField(context, slider);
  }
}

// ---------------------------------------------------------------------------
// TomFormDoubleRangeField — Abstract Double-range field
// ---------------------------------------------------------------------------

abstract class TomFormDoubleRangeField extends TomField<NumRange<double>> {
  final String? labelTextOverride;
  final String? descriptionTextOverride;
  final double min;
  final double max;

  TomFormDoubleRangeField(
    super.tomId,
    super.initialValue, {
    required this.min,
    required this.max,
    this.labelTextOverride,
    this.descriptionTextOverride,
    super.form,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
    super.actionIcon,
    super.actionIconTooltip,
    super.onActionIconPressed,
  }) : assert(max > min, 'TomFormDoubleRangeField: max must be > min');

  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');
}

@tomReflector
class TomFormDoubleRangeSlider extends TomFormDoubleRangeField
    with TomGenericFieldDecorationMixin<NumRange<double>> {
  final int? divisions;
  final int valueLabelDecimals;

  TomFormDoubleRangeSlider(
    super.tomId,
    super.initialValue, {
    required super.min,
    required super.max,
    this.divisions,
    this.valueLabelDecimals = 2,
    super.labelTextOverride,
    super.descriptionTextOverride,
    super.form,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
    super.actionIcon,
    super.actionIconTooltip,
    super.onActionIconPressed,
  });

  @override
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.sliderStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
    field: this,
    child: _TomFormDoubleRangeSliderWidget(field: this),
  );
}

class _TomFormDoubleRangeSliderWidget extends StatefulWidget {
  final TomFormDoubleRangeSlider field;
  const _TomFormDoubleRangeSliderWidget({required this.field});

  @override
  State<_TomFormDoubleRangeSliderWidget> createState() =>
      _TomFormDoubleRangeSliderWidgetState();
}

class _TomFormDoubleRangeSliderWidgetState
    extends State<_TomFormDoubleRangeSliderWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormDoubleRangeSlider get field => widget.field;

  @override
  void initState() {
    super.initState();
    _observer =
        field >>
        (_) {
          if (mounted) setState(() {});
        };
    field.validationListenable.addListener(_onValidationChanged);
  }

  void _onValidationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    field.validationListenable.removeListener(_onValidationChanged);
    field.removeObserver(_observer);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = field.get();
    final low = value.low.clamp(field.min, field.max);
    final high = value.high.clamp(field.min, field.max);
    final slider = RangeSlider(
      values: RangeValues(low, high),
      min: field.min,
      max: field.max,
      divisions: field.divisions,
      labels: RangeLabels(
        value.low.toStringAsFixed(field.valueLabelDecimals),
        value.high.toStringAsFixed(field.valueLabelDecimals),
      ),
      onChanged: field.isEditable
          ? (v) => field.setValue(NumRange<double>(v.start, v.end))
          : null,
    );
    return field.decorateField(context, slider);
  }
}
