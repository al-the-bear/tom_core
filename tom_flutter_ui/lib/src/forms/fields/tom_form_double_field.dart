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
import 'tom_field_widget_adapter.dart';

// ---------------------------------------------------------------------------
// TomFormDoubleField — Abstract Double Field (Phase 3)
// ---------------------------------------------------------------------------

abstract class TomFormDoubleField extends TomField<double> {
  final String? labelTextOverride;
  final String? hintTextOverride;
  final String? descriptionTextOverride;
  final double? minValue;
  final double? maxValue;

  TomFormDoubleField(
    super.tomId,
    super.initialValue, {
    this.labelTextOverride,
    this.hintTextOverride,
    this.descriptionTextOverride,
    this.minValue,
    this.maxValue,
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

  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');
  String? get hintText =>
      hintTextOverride ?? TomCtr.textOrNull(basePath, 'hint');
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');
}

// ---------------------------------------------------------------------------
// TomFormDoubleInput — plain decimal text input
// ---------------------------------------------------------------------------

@tomReflector
class TomFormDoubleInput extends TomFormDoubleField
    with TomStringInputDecorationMixin<double> {
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  /// Number of decimals shown / accepted. `null` means unrestricted.
  final int? decimals;

  TomFormDoubleInput(
    super.tomId,
    super.initialValue, {
    this.decimals,
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
        child: _TomFormDoubleInputWidget(field: this),
      );
}

class _TomFormDoubleInputWidget extends StatefulWidget {
  final TomFormDoubleInput field;
  const _TomFormDoubleInputWidget({required this.field});

  @override
  State<_TomFormDoubleInputWidget> createState() =>
      _TomFormDoubleInputWidgetState();
}

class _TomFormDoubleInputWidgetState extends State<_TomFormDoubleInputWidget> {
  late final TextEditingController _controller;
  late final TomFunctionObserver<TomObservable> _observer;
  bool _updatingFromField = false;

  TomFormDoubleInput get field => widget.field;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(field.get()));
    _observer = field >> (observable) {
      if (!_updatingFromField) {
        final v = _format((observable as TomObject<double>).get());
        if (_controller.text != v) _controller.text = v;
      }
      if (mounted) setState(() {});
    };
    field.validationListenable.addListener(_onValidationChanged);
  }

  String _format(double v) {
    if (field.decimals != null) return v.toStringAsFixed(field.decimals!);
    return v.toString();
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
    final n = double.tryParse(text);
    if (n == null) return;
    final clamped = _clampDouble(n, field.minValue, field.maxValue);
    _updatingFromField = true;
    field.setValue(clamped);
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
      keyboardType: const TextInputType.numberWithOptions(
          decimal: true, signed: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'-?\d*\.?\d*'))
      ],
      style: style.inputStyle,
      onChanged: field.isEditable ? _onChanged : null,
      enabled: field.isEditable,
      decoration: field.applyErrorVisualsTo(context, decoration),
    );

    return field.decorateField(context, textField);
  }
}

// ---------------------------------------------------------------------------
// TomFormCurrencyDoubleInput — locale-aware currency input
// ---------------------------------------------------------------------------

@tomReflector
class TomFormCurrencyDoubleInput extends TomFormDoubleField
    with TomStringInputDecorationMixin<double> {
  /// IETF locale (e.g. `'en_US'`, `'de_DE'`). `null` uses the current
  /// system locale.
  final String? locale;

  /// ISO 4217 currency code (e.g. `'USD'`, `'EUR'`, `'JPY'`). When null
  /// the locale's default currency is used.
  final String? currencyCode;

  TomFormCurrencyDoubleInput(
    super.tomId,
    super.initialValue, {
    this.locale,
    this.currencyCode,
    super.labelTextOverride,
    super.hintTextOverride,
    super.descriptionTextOverride,
    super.minValue,
    super.maxValue,
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

  /// Currency formatting profile derived from [locale] / [currencyCode].
  /// Without `intl`, we ship a minimal table covering the common cases
  /// (USD, EUR, GBP, JPY) plus a sensible default — the spec's Demo I
  /// only needs locale-aware visual differences, not full ICU coverage.
  CurrencyFormatProfile get formatProfile =>
      CurrencyFormatProfile.resolve(locale: locale, code: currencyCode);

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _TomFormCurrencyDoubleInputWidget(field: this),
      );
}

class _TomFormCurrencyDoubleInputWidget extends StatefulWidget {
  final TomFormCurrencyDoubleInput field;
  const _TomFormCurrencyDoubleInputWidget({required this.field});

  @override
  State<_TomFormCurrencyDoubleInputWidget> createState() =>
      _TomFormCurrencyDoubleInputWidgetState();
}

class _TomFormCurrencyDoubleInputWidgetState
    extends State<_TomFormCurrencyDoubleInputWidget> {
  late final TextEditingController _controller;
  late final TomFunctionObserver<TomObservable> _observer;
  bool _updatingFromField = false;

  TomFormCurrencyDoubleInput get field => widget.field;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatted(field.get()));
    _observer = field >> (observable) {
      if (!_updatingFromField) {
        final next = _formatted((observable as TomObject<double>).get());
        if (_controller.text != next) _controller.text = next;
      }
      if (mounted) setState(() {});
    };
    field.validationListenable.addListener(_onValidationChanged);
  }

  String _formatted(double v) => field.formatProfile.format(v);

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
    final n = field.formatProfile.parse(text);
    if (n == null) return;
    final clamped = _clampDouble(n, field.minValue, field.maxValue);
    _updatingFromField = true;
    field.setValue(clamped);
    _updatingFromField = false;
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final decoration = InputDecoration(
      labelText: _floatingLabelOrNull(style, field),
      hintText: field.hintText,
      contentPadding: style.fieldContentPadding,
      border: style.fieldBorder,
      focusedBorder: style.focusedBorder,
      errorBorder: style.errorBorder,
      enabledBorder: style.fieldBorder,
    );

    final textField = TextField(
      controller: _controller,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      style: style.inputStyle,
      onChanged: field.isEditable ? _onChanged : null,
      enabled: field.isEditable,
      decoration: field.applyErrorVisualsTo(context, decoration),
    );

    return field.decorateField(context, textField);
  }
}

// ---------------------------------------------------------------------------
// TomFormPercentDoubleInput — 0..100 display, 0.0..1.0 value
// ---------------------------------------------------------------------------

@tomReflector
class TomFormPercentDoubleInput extends TomFormDoubleField
    with TomStringInputDecorationMixin<double> {
  /// Decimals shown in the percent string (e.g. `2` → `12.34 %`).
  final int decimals;

  TomFormPercentDoubleInput(
    super.tomId,
    super.initialValue, {
    this.decimals = 1,
    super.labelTextOverride,
    super.hintTextOverride,
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
  }) : super(minValue: 0.0, maxValue: 1.0);

  @override
  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');

  @override
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _TomFormPercentDoubleInputWidget(field: this),
      );
}

class _TomFormPercentDoubleInputWidget extends StatefulWidget {
  final TomFormPercentDoubleInput field;
  const _TomFormPercentDoubleInputWidget({required this.field});

  @override
  State<_TomFormPercentDoubleInputWidget> createState() =>
      _TomFormPercentDoubleInputWidgetState();
}

class _TomFormPercentDoubleInputWidgetState
    extends State<_TomFormPercentDoubleInputWidget> {
  late final TextEditingController _controller;
  late final TomFunctionObserver<TomObservable> _observer;
  bool _updatingFromField = false;

  TomFormPercentDoubleInput get field => widget.field;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _displayed(field.get()));
    _observer = field >> (observable) {
      if (!_updatingFromField) {
        final next = _displayed((observable as TomObject<double>).get());
        if (_controller.text != next) _controller.text = next;
      }
      if (mounted) setState(() {});
    };
    field.validationListenable.addListener(_onValidationChanged);
  }

  String _displayed(double fraction) =>
      (fraction * 100).toStringAsFixed(field.decimals);

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
    final n = double.tryParse(text);
    if (n == null) return;
    final fraction = (n / 100.0).clamp(0.0, 1.0);
    _updatingFromField = true;
    field.setValue(fraction);
    _updatingFromField = false;
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final decoration = InputDecoration(
      labelText: _floatingLabelOrNull(style, field),
      hintText: field.hintText,
      suffixText: '%',
      contentPadding: style.fieldContentPadding,
      border: style.fieldBorder,
      focusedBorder: style.focusedBorder,
      errorBorder: style.errorBorder,
      enabledBorder: style.fieldBorder,
    );

    final textField = TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'\d*\.?\d*'))
      ],
      style: style.inputStyle,
      onChanged: field.isEditable ? _onChanged : null,
      enabled: field.isEditable,
      decoration: field.applyErrorVisualsTo(context, decoration),
    );

    return field.decorateField(context, textField);
  }
}

// ---------------------------------------------------------------------------
// TomFormDoubleSlider — Slider with divisions for a double range
// ---------------------------------------------------------------------------

@tomReflector
class TomFormDoubleSlider extends TomFormDoubleField
    with TomGenericFieldDecorationMixin<double> {
  final double min;
  final double max;
  final int? divisions;
  final int valueLabelDecimals;

  TomFormDoubleSlider(
    super.tomId,
    super.initialValue, {
    required this.min,
    required this.max,
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
  })  : assert(max > min, 'TomFormDoubleSlider: max must be greater than min'),
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
        child: _TomFormDoubleSliderWidget(field: this),
      );
}

class _TomFormDoubleSliderWidget extends StatefulWidget {
  final TomFormDoubleSlider field;
  const _TomFormDoubleSliderWidget({required this.field});

  @override
  State<_TomFormDoubleSliderWidget> createState() =>
      _TomFormDoubleSliderWidgetState();
}

class _TomFormDoubleSliderWidgetState
    extends State<_TomFormDoubleSliderWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormDoubleSlider get field => widget.field;

  @override
  void initState() {
    super.initState();
    _observer = field >> (_) {
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
    final value = field.get().clamp(field.min, field.max);
    final slider = Slider(
      value: value,
      min: field.min,
      max: field.max,
      divisions: field.divisions,
      label: field.get().toStringAsFixed(field.valueLabelDecimals),
      onChanged: field.isEditable ? field.setValue : null,
    );
    return field.decorateField(context, slider);
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

double _clampDouble(double value, double? min, double? max) {
  var v = value;
  if (min != null && v < min) v = min;
  if (max != null && v > max) v = max;
  return v;
}

String? _floatingLabelOrNull(TomFieldStyle style, TomFormDoubleField field) {
  if (style.labelPlacement != LabelPlacement.floating) return null;
  final label = field.labelText;
  if (label == null || label.isEmpty) return null;
  return label;
}

// ---------------------------------------------------------------------------
// CurrencyFormatProfile — minimal locale-aware currency renderer
// ---------------------------------------------------------------------------

/// Tiny built-in currency formatter so Phase 3 doesn't pull `intl` in.
/// Covers USD / EUR / GBP / JPY visually — enough for Demo I's locale
/// switcher. Apps that need full ICU coverage can swap their own
/// `TomFormCurrencyDoubleInput` subclass that uses the `intl` package.
class CurrencyFormatProfile {
  final String symbol;
  final bool symbolBeforeAmount;
  final String groupSeparator;
  final String decimalSeparator;
  final int decimals;

  const CurrencyFormatProfile({
    required this.symbol,
    required this.symbolBeforeAmount,
    required this.groupSeparator,
    required this.decimalSeparator,
    required this.decimals,
  });

  static CurrencyFormatProfile resolve({String? locale, String? code}) {
    switch (code) {
      case 'EUR':
        return const CurrencyFormatProfile(
          symbol: '€',
          symbolBeforeAmount: false,
          groupSeparator: '.',
          decimalSeparator: ',',
          decimals: 2,
        );
      case 'GBP':
        return const CurrencyFormatProfile(
          symbol: '£',
          symbolBeforeAmount: true,
          groupSeparator: ',',
          decimalSeparator: '.',
          decimals: 2,
        );
      case 'JPY':
        return const CurrencyFormatProfile(
          symbol: '¥',
          symbolBeforeAmount: true,
          groupSeparator: ',',
          decimalSeparator: '.',
          decimals: 0,
        );
      case 'USD':
      default:
        return const CurrencyFormatProfile(
          symbol: r'$',
          symbolBeforeAmount: true,
          groupSeparator: ',',
          decimalSeparator: '.',
          decimals: 2,
        );
    }
  }

  String format(double value) {
    final isNegative = value < 0;
    final abs = value.abs();
    final fixed = abs.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final integerPart = parts[0];
    final fractionalPart = parts.length > 1 ? parts[1] : '';

    final grouped = StringBuffer();
    for (var i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        grouped.write(groupSeparator);
      }
      grouped.write(integerPart[i]);
    }

    final amount = decimals > 0
        ? '$grouped$decimalSeparator$fractionalPart'
        : grouped.toString();
    final signed = isNegative ? '-$amount' : amount;
    return symbolBeforeAmount ? '$symbol$signed' : '$signed $symbol';
  }

  double? parse(String text) {
    if (text.isEmpty) return null;
    final cleaned = text
        .replaceAll(symbol, '')
        .replaceAll(groupSeparator, '')
        .trim();
    final normalised = cleaned.replaceAll(decimalSeparator, '.');
    return double.tryParse(normalised);
  }
}
