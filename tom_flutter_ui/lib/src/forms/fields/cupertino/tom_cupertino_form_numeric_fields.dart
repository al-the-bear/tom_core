/// Cupertino Numeric concretes.
///
/// Four concretes that subclass the same abstract numeric
/// fields (`TomFormIntField`, `TomFormDoubleField`) used by the
/// Material side, but render their inner control with Cupertino
/// widgets:
///   * [TomCupertinoFormIntInput]            → `CupertinoTextField` (numeric)
///   * [TomCupertinoFormIntPicker]           → `CupertinoPicker` sheet
///   * [TomCupertinoFormDoubleInput]         → `CupertinoTextField` (decimal)
///   * [TomCupertinoFormCurrencyDoubleInput] → `CupertinoTextField` + locale
///
/// Anatomy reuse: identical mixin set (`TomStringInputDecorationMixin`
/// for inputs, `TomGenericFieldDecorationMixin` for the picker) so
/// label / error / description / action icons render exactly like the
/// Material counterparts. Only the inner control swaps. The shared
/// `cupertinoFieldDecoration()` helper renders the surface.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../../widget_base/tom_construction_helpers.dart';
import '../../decoration/tom_field_anatomy.dart';
import '../../decoration/tom_generic_field_decoration_mixin.dart';
import '../../decoration/tom_string_input_decoration_mixin.dart';
import '../../style/tom_cupertino_form_style.dart';
import '../../style/tom_form_style.dart';
import '../../style/tom_form_style_scope.dart';
import '../tom_field_widget_adapter.dart';
import '../tom_form_double_field.dart';
import '../tom_form_int_field.dart';

// ===========================================================================
// TomCupertinoFormIntInput — CupertinoTextField with numeric keyboard
// ===========================================================================

@tomReflector
class TomCupertinoFormIntInput extends TomFormIntField
    with TomStringInputDecorationMixin<int> {
  /// Optional prefix widget shown inside the field box.
  final Widget? prefix;

  /// Optional suffix widget shown inside the field box.
  final Widget? suffix;

  TomCupertinoFormIntInput(
    super.tomId,
    super.initialValue, {
    super.labelTextOverride,
    super.hintTextOverride,
    super.descriptionTextOverride,
    super.minValue,
    super.maxValue,
    this.prefix,
    this.suffix,
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
        child: _CupertinoIntInputWidget(field: this),
      );
}

class _CupertinoIntInputWidget extends StatefulWidget {
  final TomCupertinoFormIntInput field;
  const _CupertinoIntInputWidget({required this.field});

  @override
  State<_CupertinoIntInputWidget> createState() =>
      _CupertinoIntInputWidgetState();
}

class _CupertinoIntInputWidgetState extends State<_CupertinoIntInputWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final TomFunctionObserver<TomObservable> _observer;
  bool _updatingFromField = false;

  TomCupertinoFormIntInput get field => widget.field;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: field.get().toString());
    _focusNode = FocusNode()..addListener(_onFocus);
    _observer = field >> (observable) {
      if (!_updatingFromField) {
        final next = (observable as TomObject<int>).get().toString();
        if (_controller.text != next) _controller.text = next;
      }
      if (mounted) setState(() {});
    };
    field.validationListenable.addListener(_onValidationChanged);
  }

  void _onValidationChanged() {
    if (mounted) setState(() {});
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    field.validationListenable.removeListener(_onValidationChanged);
    field.removeObserver(_observer);
    _focusNode
      ..removeListener(_onFocus)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final n = int.tryParse(text);
    if (n == null) return;
    _updatingFromField = true;
    field.setValue(n);
    _updatingFromField = false;
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final hint = field.hintText;

    final input = CupertinoTextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))],
      placeholder: hint == null
          ? null
          : hint +
              field.requiredIndicatorSuffix(style.requiredIndicatorOnHint),
      placeholderStyle: composeHintStyle(style, Theme.of(context)),
      style: style.inputStyle,
      onChanged: field.isEditable ? _onChanged : null,
      enabled: field.isEditable,
      padding: style.fieldContentPadding,
      prefix: composeCupertinoLeading(field.prefix, style),
      suffix: composeCupertinoTrailing(field.suffix, style),
      decoration: cupertinoFieldDecoration(
        context: context,
        borderRadius: style.borderRadius,
        focused: _focusNode.hasFocus,
      ),
    );

    return field.decorateField(context, input);
  }
}

// ===========================================================================
// TomCupertinoFormIntPicker — CupertinoPicker sheet over a discrete range
// ===========================================================================

@tomReflector
class TomCupertinoFormIntPicker extends TomFormIntField
    with TomGenericFieldDecorationMixin<int> {
  /// Inclusive minimum shown in the picker (uses [minValue] if not set).
  final int min;

  /// Inclusive maximum shown in the picker (uses [maxValue] if not set).
  final int max;

  /// Step between consecutive values (defaults to 1).
  final int step;

  /// Height of the picker sheet (excluding the Cancel/Done bar).
  final double sheetHeight;

  /// Optional formatter for the row label (defaults to `value.toString()`).
  final String Function(int value)? format;

  TomCupertinoFormIntPicker(
    super.tomId,
    super.initialValue, {
    required this.min,
    required this.max,
    this.step = 1,
    this.sheetHeight = 216,
    this.format,
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
  })  : assert(max > min, 'TomCupertinoFormIntPicker: max must be > min'),
        assert(step >= 1, 'TomCupertinoFormIntPicker: step must be >= 1'),
        super(minValue: min, maxValue: max);

  // The mixin's `labelText` / `descriptionText` getters return null by
  // default; concrete classes have to delegate to the abstract
  // `TomFormIntField` resolution chain so the field anatomy can render
  // the label above the picker tile.
  @override
  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');

  @override
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  @override
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.dropdownStyle, width);
  }

  /// All values produced by the picker, inclusive of [min] and [max] when
  /// reachable from [step].
  List<int> get values {
    final out = <int>[];
    for (var v = min; v <= max; v += step) {
      out.add(v);
    }
    return out;
  }

  String renderLabel(int v) => format?.call(v) ?? v.toString();

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _CupertinoIntPickerWidget(field: this),
      );
}

class _CupertinoIntPickerWidget extends StatefulWidget {
  final TomCupertinoFormIntPicker field;
  const _CupertinoIntPickerWidget({required this.field});

  @override
  State<_CupertinoIntPickerWidget> createState() =>
      _CupertinoIntPickerWidgetState();
}

class _CupertinoIntPickerWidgetState extends State<_CupertinoIntPickerWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormIntPicker get field => widget.field;

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

  void _showPicker() {
    final values = field.values;
    final current = field.get();
    int initialIndex = values.indexOf(current);
    if (initialIndex < 0) initialIndex = 0;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        int tempIndex = initialIndex;
        return Container(
          height: field.sheetHeight + 56,
          color: CupertinoColors.systemBackground.resolveFrom(ctx),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    CupertinoButton(
                      onPressed: () {
                        if (tempIndex >= 0 && tempIndex < values.length) {
                          field.setValue(values[tempIndex]);
                        }
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 32,
                    scrollController:
                        FixedExtentScrollController(initialItem: initialIndex),
                    onSelectedItemChanged: (i) => tempIndex = i,
                    children: [
                      for (final v in values)
                        Center(child: Text(field.renderLabel(v))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final tile = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: field.isEditable ? _showPicker : null,
      child: Container(
        padding: style.fieldContentPadding,
        decoration: cupertinoFieldDecoration(
          context: context,
          borderRadius: style.borderRadius,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                field.renderLabel(field.get()),
                style: style.inputStyle,
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_down,
              size: 18,
              color: CupertinoColors.secondaryLabel,
            ),
          ],
        ),
      ),
    );
    return field.decorateField(context, tile);
  }
}

// ===========================================================================
// TomCupertinoFormDoubleInput — CupertinoTextField with decimal keyboard
// ===========================================================================

@tomReflector
class TomCupertinoFormDoubleInput extends TomFormDoubleField
    with TomStringInputDecorationMixin<double> {
  final Widget? prefix;
  final Widget? suffix;

  /// Number of decimals shown / accepted. `null` means unrestricted.
  final int? decimals;

  TomCupertinoFormDoubleInput(
    super.tomId,
    super.initialValue, {
    this.decimals,
    super.labelTextOverride,
    super.hintTextOverride,
    super.descriptionTextOverride,
    super.minValue,
    super.maxValue,
    this.prefix,
    this.suffix,
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
        child: _CupertinoDoubleInputWidget(field: this),
      );
}

class _CupertinoDoubleInputWidget extends StatefulWidget {
  final TomCupertinoFormDoubleInput field;
  const _CupertinoDoubleInputWidget({required this.field});

  @override
  State<_CupertinoDoubleInputWidget> createState() =>
      _CupertinoDoubleInputWidgetState();
}

class _CupertinoDoubleInputWidgetState
    extends State<_CupertinoDoubleInputWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final TomFunctionObserver<TomObservable> _observer;
  bool _updatingFromField = false;

  TomCupertinoFormDoubleInput get field => widget.field;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue(field.get()));
    _focusNode = FocusNode()..addListener(_onFocus);
    _observer = field >> (observable) {
      if (!_updatingFromField) {
        final next = _formatValue((observable as TomObject<double>).get());
        if (_controller.text != next) _controller.text = next;
      }
      if (mounted) setState(() {});
    };
    field.validationListenable.addListener(_onValidationChanged);
  }

  String _formatValue(double v) {
    if (field.decimals == null) {
      // Strip trailing .0 for whole-number doubles for nicer display.
      final s = v.toString();
      return s;
    }
    return v.toStringAsFixed(field.decimals!);
  }

  void _onValidationChanged() {
    if (mounted) setState(() {});
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    field.validationListenable.removeListener(_onValidationChanged);
    field.removeObserver(_observer);
    _focusNode
      ..removeListener(_onFocus)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final n = double.tryParse(text);
    if (n == null) return;
    _updatingFromField = true;
    field.setValue(n);
    _updatingFromField = false;
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final hint = field.hintText;

    final input = CupertinoTextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'-?\d*\.?\d*')),
      ],
      placeholder: hint == null
          ? null
          : hint +
              field.requiredIndicatorSuffix(style.requiredIndicatorOnHint),
      placeholderStyle: composeHintStyle(style, Theme.of(context)),
      style: style.inputStyle,
      onChanged: field.isEditable ? _onChanged : null,
      enabled: field.isEditable,
      padding: style.fieldContentPadding,
      prefix: composeCupertinoLeading(field.prefix, style),
      suffix: composeCupertinoTrailing(field.suffix, style),
      decoration: cupertinoFieldDecoration(
        context: context,
        borderRadius: style.borderRadius,
        focused: _focusNode.hasFocus,
      ),
    );

    return field.decorateField(context, input);
  }
}

// ===========================================================================
// TomCupertinoFormCurrencyDoubleInput — locale-aware currency input
// ===========================================================================

@tomReflector
class TomCupertinoFormCurrencyDoubleInput extends TomFormDoubleField
    with TomStringInputDecorationMixin<double> {
  /// IETF locale (e.g. `'en_US'`, `'de_DE'`). `null` uses the system default.
  final String? locale;

  /// ISO 4217 currency code (e.g. `'USD'`, `'EUR'`, `'JPY'`). `null`
  /// derives from [locale].
  final String? currencyCode;

  TomCupertinoFormCurrencyDoubleInput(
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

  /// Reuses the same lightweight `CurrencyFormatProfile` shipped with
  /// [TomFormCurrencyDoubleInput] so Cupertino renders identical numbers.
  CurrencyFormatProfile get formatProfile =>
      CurrencyFormatProfile.resolve(locale: locale, code: currencyCode);

  /// See [TomFormCurrencyDoubleInput.symbolIsLeading] — same convention.
  bool get symbolIsLeading => formatProfile.symbolBeforeAmount;

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _CupertinoCurrencyDoubleInputWidget(field: this),
      );
}

class _CupertinoCurrencyDoubleInputWidget extends StatefulWidget {
  final TomCupertinoFormCurrencyDoubleInput field;
  const _CupertinoCurrencyDoubleInputWidget({required this.field});

  @override
  State<_CupertinoCurrencyDoubleInputWidget> createState() =>
      _CupertinoCurrencyDoubleInputWidgetState();
}

class _CupertinoCurrencyDoubleInputWidgetState
    extends State<_CupertinoCurrencyDoubleInputWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final TomFunctionObserver<TomObservable> _observer;
  bool _updatingFromField = false;

  TomCupertinoFormCurrencyDoubleInput get field => widget.field;

  @override
  void initState() {
    super.initState();
    // The currency symbol is rendered as a fixed Widget in the
    // CupertinoTextField's prefix/suffix slot — outside the controller text
    // so the user cannot delete it with Backspace. The controller therefore
    // holds only the *amount* portion (no symbol). See the Material
    // counterpart in `tom_form_double_field.dart` for the matching
    // rationale; the formatting helper here is the same minus the symbol
    // concat at the end.
    _controller = TextEditingController(text: _amount(field.get()));
    _focusNode = FocusNode()..addListener(_onFocus);
    _observer = field >> (observable) {
      if (!_updatingFromField) {
        final next = _amount((observable as TomObject<double>).get());
        if (_controller.text != next) _controller.text = next;
      }
      if (mounted) setState(() {});
    };
    field.validationListenable.addListener(_onValidationChanged);
  }

  String _amount(double v) {
    final p = field.formatProfile;
    final isNegative = v < 0;
    final fixed = v.abs().toStringAsFixed(p.decimals);
    final parts = fixed.split('.');
    final integerPart = parts[0];
    final fractionalPart = parts.length > 1 ? parts[1] : '';
    final grouped = StringBuffer();
    for (var i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        grouped.write(p.groupSeparator);
      }
      grouped.write(integerPart[i]);
    }
    final amount = p.decimals > 0
        ? '$grouped${p.decimalSeparator}$fractionalPart'
        : grouped.toString();
    return isNegative ? '-$amount' : amount;
  }

  void _onValidationChanged() {
    if (mounted) setState(() {});
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    field.validationListenable.removeListener(_onValidationChanged);
    field.removeObserver(_observer);
    _focusNode
      ..removeListener(_onFocus)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final n = field.formatProfile.parse(text);
    if (n == null) return;
    _updatingFromField = true;
    field.setValue(n);
    _updatingFromField = false;
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final hint = field.hintText;

    // CupertinoTextField's `prefix` / `suffix` slots sit FLUSH with the
    // outer rounded border — `padding` only insets the editable region,
    // not the prefix. Without explicit padding, the symbol would be
    // glued to the border. Move the field's natural left/right inset in
    // FRONT of the symbol by wrapping it in a Padding, then shrink the
    // editable's padding on the symbol side to just `style.leadingGap` /
    // `trailingGap` so the visual layout becomes:
    //   edge → contentPadding.left → [symbol] → leadingGap → editable
    // This mirrors the Material `prefixText` behaviour where the symbol
    // is part of the in-field decoration row, not glued to the border.
    final basePad = style.fieldContentPadding;
    final symbolText =
        Text(field.formatProfile.symbol, style: style.inputStyle);
    final symbolPrefix = field.symbolIsLeading
        ? Padding(
            padding: EdgeInsets.only(left: basePad.left),
            child: symbolText,
          )
        : null;
    final symbolSuffix = !field.symbolIsLeading
        ? Padding(
            padding: EdgeInsets.only(right: basePad.right),
            child: symbolText,
          )
        : null;
    // Override the editable region's padding to use just the small gap
    // on the symbol side. The opposite side keeps the field's normal
    // inset because no widget consumes it there.
    final editablePadding = EdgeInsets.only(
      left: field.symbolIsLeading ? style.leadingGap : basePad.left,
      right: field.symbolIsLeading ? basePad.right : style.trailingGap,
      top: basePad.top,
      bottom: basePad.bottom,
    );

    final input = CupertinoTextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      placeholder: hint == null
          ? null
          : hint +
              field.requiredIndicatorSuffix(style.requiredIndicatorOnHint),
      placeholderStyle: composeHintStyle(style, Theme.of(context)),
      style: style.inputStyle,
      onChanged: field.isEditable ? _onChanged : null,
      enabled: field.isEditable,
      padding: editablePadding,
      prefix: composeCupertinoLeading(symbolPrefix, style),
      suffix: composeCupertinoTrailing(symbolSuffix, style),
      decoration: cupertinoFieldDecoration(
        context: context,
        borderRadius: style.borderRadius,
        focused: _focusNode.hasFocus,
      ),
    );

    return field.decorateField(context, input);
  }
}
