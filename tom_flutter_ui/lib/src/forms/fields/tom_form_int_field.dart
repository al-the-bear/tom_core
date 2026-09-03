library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../decoration/tom_generic_field_decoration_mixin.dart';
import '../decoration/tom_string_input_decoration_mixin.dart';
import '../style/form_style_enums.dart';
import '../style/tom_form_style.dart';
import '../style/tom_form_style_scope.dart';
import '../tom_form.dart';
import '../validation/validators.dart';
import 'tom_field_widget_adapter.dart';

// ---------------------------------------------------------------------------
// TomFormIntField — Abstract Int Field
// ---------------------------------------------------------------------------

/// Abstract base for integer-typed form fields. Mirrors the surface of
/// [TomFormStringField] but without the string-specific concerns
/// (maxLength, obscureText). Concrete implementations: [TomFormIntInput],
/// [TomFormIntSlider], [TomFormIntStepper].
abstract class TomFormIntField extends TomField<int> {
  final String? labelTextOverride;
  final String? hintTextOverride;
  final String? descriptionTextOverride;

  /// Optional inclusive minimum. Slider / stepper variants honour it
  /// for clamping; input variants surface it via a built-in validator
  /// auto-prepended to [validators] when this is non-null.
  final int? minValue;

  /// Optional inclusive maximum.
  final int? maxValue;

  TomFormIntField(
    super.tomId,
    super.initialValue, {
    this.labelTextOverride,
    this.hintTextOverride,
    this.descriptionTextOverride,
    this.minValue,
    this.maxValue,
    super.form,
    List<Object> validators = const [],
    super.autoValidate = false,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
    super.actionIcon,
    super.actionIconTooltip,
    super.onActionIconPressed,
  }) : super(
         validators: [
           if (minValue != null) Validators.min(minValue),
           if (maxValue != null) Validators.max(maxValue),
           ...validators,
         ],
       );

  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');
  String? get hintText =>
      hintTextOverride ?? TomCtr.textOrNull(basePath, 'hint');
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');
}

// ---------------------------------------------------------------------------
// TomFormIntInput — Integer text input (numeric keyboard)
// ---------------------------------------------------------------------------

@tomReflector
class TomFormIntInput extends TomFormIntField
    with TomStringInputDecorationMixin<int> {
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  TomFormIntInput(
    super.tomId,
    super.initialValue, {
    super.labelTextOverride,
    super.hintTextOverride,
    super.descriptionTextOverride,
    super.minValue,
    super.maxValue,
    this.prefixIcon,
    this.suffixIcon,
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
  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');

  @override
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  @override
  Widget get widget => TomFieldWidgetAdapter(
    field: this,
    child: _TomFormIntInputWidget(field: this),
  );
}

class _TomFormIntInputWidget extends StatefulWidget {
  final TomFormIntInput field;
  const _TomFormIntInputWidget({required this.field});

  @override
  State<_TomFormIntInputWidget> createState() => _TomFormIntInputWidgetState();
}

class _TomFormIntInputWidgetState extends State<_TomFormIntInputWidget> {
  late final TextEditingController _controller;
  late final TomFunctionObserver<TomObservable> _observer;
  bool _updatingFromField = false;

  TomFormIntInput get field => widget.field;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: field.get().toString());
    _observer =
        field >>
        (observable) {
          if (!_updatingFromField) {
            final v = (observable as TomObject<int>).get().toString();
            if (_controller.text != v) _controller.text = v;
          }
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
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final n = int.tryParse(text);
    if (n == null) return;
    // Don't silently clamp here — the abstract field auto-prepends
    // Validators.min/max so out-of-range values surface as a normal
    // validation error in the field anatomy. Slider and stepper variants
    // still clamp because the widget itself can't produce out-of-range
    // values in the first place.
    _updatingFromField = true;
    field.setValue(n);
    _updatingFromField = false;
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final decoration = InputDecoration(
      labelText: _floatingLabelOrNull(style, field),
      hintText: field.hintText,
      prefixIcon: field.prefixIcon,
      suffixIcon: field.suffixIcon,
      contentPadding: style.fieldContentPadding,
      border: style.fieldBorder,
      focusedBorder: style.focusedBorder,
      errorBorder: style.errorBorder,
      enabledBorder: style.fieldBorder,
    );

    final textField = TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))],
      style: style.inputStyle,
      onChanged: field.isEditable ? _onChanged : null,
      enabled: field.isEditable,
      decoration: field.applyErrorVisualsTo(context, decoration),
    );

    return field.decorateField(context, textField);
  }
}

// ---------------------------------------------------------------------------
// TomFormIntSlider — Integer slider
// ---------------------------------------------------------------------------

@tomReflector
class TomFormIntSlider extends TomFormIntField
    with TomGenericFieldDecorationMixin<int> {
  /// Lower end of the track. Required — a slider without bounds has no
  /// geometry — and forwarded to the base field's `minValue`, so the range
  /// and the validation bound cannot drift apart.
  final int min;

  /// Upper end of the track, forwarded to the base field's `maxValue`.
  /// Required for the same reason as [min], and asserted to exceed it.
  final int max;

  /// Number of discrete divisions; defaults to `max - min`.
  final int? divisions;

  /// Whether the current value is shown as a label above the thumb.
  final bool showValueLabel;

  TomFormIntSlider(
    super.tomId,
    super.initialValue, {
    required this.min,
    required this.max,
    this.divisions,
    this.showValueLabel = true,
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
  }) : assert(max > min, 'TomFormIntSlider: max must be greater than min'),
       super(minValue: min, maxValue: max);

  @override
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.sliderStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
    field: this,
    child: _TomFormIntSliderWidget(field: this),
  );
}

class _TomFormIntSliderWidget extends StatefulWidget {
  final TomFormIntSlider field;
  const _TomFormIntSliderWidget({required this.field});

  @override
  State<_TomFormIntSliderWidget> createState() =>
      _TomFormIntSliderWidgetState();
}

class _TomFormIntSliderWidgetState extends State<_TomFormIntSliderWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormIntSlider get field => widget.field;

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
    final value = field.get().clamp(field.min, field.max).toDouble();
    final divisions = field.divisions ?? (field.max - field.min);
    final slider = Slider(
      value: value,
      min: field.min.toDouble(),
      max: field.max.toDouble(),
      divisions: divisions > 0 ? divisions : null,
      label: field.showValueLabel ? field.get().toString() : null,
      onChanged: field.isEditable ? (v) => field.setValue(v.round()) : null,
    );
    return field.decorateField(context, slider);
  }
}

// ---------------------------------------------------------------------------
// TomFormIntStepper — Integer +/- stepper
// ---------------------------------------------------------------------------

@tomReflector
class TomFormIntStepper extends TomFormIntField
    with TomGenericFieldDecorationMixin<int> {
  final int step;

  TomFormIntStepper(
    super.tomId,
    super.initialValue, {
    this.step = 1,
    super.minValue,
    super.maxValue,
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
    return form.resolveFieldStyle(form.stringInputStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
    field: this,
    child: _TomFormIntStepperWidget(field: this),
  );
}

class _TomFormIntStepperWidget extends StatefulWidget {
  final TomFormIntStepper field;
  const _TomFormIntStepperWidget({required this.field});

  @override
  State<_TomFormIntStepperWidget> createState() =>
      _TomFormIntStepperWidgetState();
}

class _TomFormIntStepperWidgetState extends State<_TomFormIntStepperWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormIntStepper get field => widget.field;

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

  bool get _canDecrement {
    if (!field.isEditable) return false;
    if (field.minValue == null) return true;
    return field.get() - field.step >= field.minValue!;
  }

  bool get _canIncrement {
    if (!field.isEditable) return false;
    if (field.maxValue == null) return true;
    return field.get() + field.step <= field.maxValue!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stepper = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          onPressed: _canDecrement
              ? () => field.setValue(field.get() - field.step)
              : null,
          icon: const Icon(Icons.remove, size: 18),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 48,
          child: Text(
            field.get().toString(),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: 12),
        IconButton.outlined(
          onPressed: _canIncrement
              ? () => field.setValue(field.get() + field.step)
              : null,
          icon: const Icon(Icons.add, size: 18),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
    return field.decorateField(context, stepper);
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

String? _floatingLabelOrNull(TomFieldStyle style, TomFormIntField field) {
  if (style.labelPlacement != LabelPlacement.floating) return null;
  final label = field.labelText;
  if (label == null || label.isEmpty) return null;
  return label;
}
