/// Cupertino Nullable input variants.
///
/// Mirror the four Material nullable inputs but render through
/// Cupertino primitives. Each variant binds a `T?` value so the user can
/// express "explicitly empty" as a distinct state from "default /
/// pristine"; clearing emits `null`.
///
/// Concretes:
///   * [TomCupertinoFormNStringInput]  — `CupertinoTextField` over `String?`.
///   * [TomCupertinoFormNIntInput]     — `CupertinoTextField` over `int?`.
///   * [TomCupertinoFormNDoubleInput]  — `CupertinoTextField` over `double?`.
///   * [TomCupertinoFormNDateInput]    — `CupertinoDatePicker` sheet over
///                                       `DateTime?`.
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
import '../../tom_form.dart';
import '../../tom_form_labels.dart';
import '../tom_field_widget_adapter.dart';

// ===========================================================================
// Shared label / description resource resolution
// ===========================================================================

mixin _CupertinoNullableLabels<T> on TomField<T> {
  String? get labelTextOverride;
  String? get hintTextOverride;
  String? get descriptionTextOverride;

  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');
  String? get hintText =>
      hintTextOverride ?? TomCtr.textOrNull(basePath, 'hint');
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  /// Text shown in place of the value when null.
  ///
  /// Same order as the Material nullable fields: a field-scoped `nullDisplay`
  /// resource, then the field's hint, then the shared `form.nullDisplay`
  /// caption — which is itself resolvable, so the sentinel is translatable
  /// rather than a literal baked into the widget.
  String resolveNullDisplay() =>
      TomCtr.textOrNull(basePath, 'nullDisplay') ??
      hintText ??
      TomFormLabels.nullDisplay(basePath);
}

// ===========================================================================
// TomCupertinoFormNStringInput — TomField<String?>
// ===========================================================================

@tomReflector
class TomCupertinoFormNStringInput extends TomField<String?>
    with
        TomStringInputDecorationMixin<String?>,
        _CupertinoNullableLabels<String?> {
  @override
  final String? labelTextOverride;
  @override
  final String? hintTextOverride;
  @override
  final String? descriptionTextOverride;

  final int? maxLength;
  final Widget? prefix;

  TomCupertinoFormNStringInput(
    super.tomId,
    super.initialValue, {
    this.labelTextOverride,
    this.hintTextOverride,
    this.descriptionTextOverride,
    this.maxLength,
    this.prefix,
    super.form,
    super.obscureText,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
  });

  @override
  Widget get widget => TomFieldWidgetAdapter(
    field: this,
    child: _CupertinoNullableTextWidget<String?>(
      field: this,
      decorationField: this,
      nullDisplay: resolveNullDisplay(),
      format: (v) => v ?? '',
      parse: (text) => text.isEmpty ? null : text,
      keyboardType: TextInputType.text,
      inputFormatters: const [],
      maxLength: maxLength,
      prefix: prefix,
    ),
  );
}

// ===========================================================================
// TomCupertinoFormNIntInput — TomField<int?>
// ===========================================================================

@tomReflector
class TomCupertinoFormNIntInput extends TomField<int?>
    with TomStringInputDecorationMixin<int?>, _CupertinoNullableLabels<int?> {
  @override
  final String? labelTextOverride;
  @override
  final String? hintTextOverride;
  @override
  final String? descriptionTextOverride;

  final Widget? prefix;

  TomCupertinoFormNIntInput(
    super.tomId,
    super.initialValue, {
    this.labelTextOverride,
    this.hintTextOverride,
    this.descriptionTextOverride,
    this.prefix,
    super.form,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
  });

  @override
  Widget get widget => TomFieldWidgetAdapter(
    field: this,
    child: _CupertinoNullableTextWidget<int?>(
      field: this,
      decorationField: this,
      nullDisplay: resolveNullDisplay(),
      format: (v) => v?.toString() ?? '',
      parse: (text) => text.isEmpty ? null : int.tryParse(text),
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))],
      prefix: prefix,
      skipUnparseableNonEmpty: true,
    ),
  );
}

// ===========================================================================
// TomCupertinoFormNDoubleInput — TomField<double?>
// ===========================================================================

@tomReflector
class TomCupertinoFormNDoubleInput extends TomField<double?>
    with
        TomStringInputDecorationMixin<double?>,
        _CupertinoNullableLabels<double?> {
  @override
  final String? labelTextOverride;
  @override
  final String? hintTextOverride;
  @override
  final String? descriptionTextOverride;

  final int? decimals;

  TomCupertinoFormNDoubleInput(
    super.tomId,
    super.initialValue, {
    this.labelTextOverride,
    this.hintTextOverride,
    this.descriptionTextOverride,
    this.decimals,
    super.form,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
  });

  String _format(double? v) {
    if (v == null) return '';
    if (decimals != null) return v.toStringAsFixed(decimals!);
    return v.toString();
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
    field: this,
    child: _CupertinoNullableTextWidget<double?>(
      field: this,
      decorationField: this,
      nullDisplay: resolveNullDisplay(),
      format: _format,
      parse: (text) => text.isEmpty ? null : double.tryParse(text),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'-?\d*\.?\d*')),
      ],
      skipUnparseableNonEmpty: true,
    ),
  );
}

// ===========================================================================
// Shared text-input widget for the three textual variants
// ===========================================================================

typedef _NullableInputDecorator = TomStringInputDecorationMixin;

class _CupertinoNullableTextWidget<T> extends StatefulWidget {
  final TomField<T> field;
  final _NullableInputDecorator decorationField;

  /// The resolved sentinel for a null value, computed by the concrete field
  /// (which is where the resource chain is in scope).
  final String nullDisplay;

  final String Function(T value) format;
  final T Function(String text) parse;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final int? maxLength;
  final Widget? prefix;
  final bool skipUnparseableNonEmpty;

  const _CupertinoNullableTextWidget({
    required this.field,
    required this.decorationField,
    required this.nullDisplay,
    required this.format,
    required this.parse,
    required this.keyboardType,
    required this.inputFormatters,
    this.maxLength,
    this.prefix,
    this.skipUnparseableNonEmpty = false,
  });

  @override
  State<_CupertinoNullableTextWidget<T>> createState() =>
      _CupertinoNullableTextWidgetState<T>();
}

class _CupertinoNullableTextWidgetState<T>
    extends State<_CupertinoNullableTextWidget<T>> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final TomFunctionObserver<TomObservable> _observer;
  bool _updatingFromField = false;

  TomField<T> get field => widget.field;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.format(field.get()));
    _focusNode = FocusNode();
    _observer =
        field >>
        (observable) {
          if (!_updatingFromField) {
            final v = widget.format((observable as TomObject<T>).get());
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
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final parsed = widget.parse(text);
    if (parsed == null && text.isNotEmpty && widget.skipUnparseableNonEmpty) {
      return;
    }
    _updatingFromField = true;
    field.setValue(parsed);
    _updatingFromField = false;
  }

  void _clear() {
    _controller.clear();
    _updatingFromField = true;
    field.setValue(widget.parse(''));
    _updatingFromField = false;
  }

  @override
  Widget build(BuildContext context) {
    final f = field;
    final d = widget.decorationField;
    final style = d.resolveStyle(context);
    final hasValue = field.get() != null;

    final input = CupertinoTextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      maxLength: widget.maxLength,
      style: style.inputStyle,
      placeholder: widget.nullDisplay,
      placeholderStyle: composeHintStyle(style, Theme.of(context)),
      onChanged: f.isEditable ? _onChanged : null,
      enabled: f.isEditable,
      padding: style.fieldContentPadding,
      prefix: composeCupertinoLeading(widget.prefix, style),
      suffix: composeCupertinoTrailing(
        hasValue && f.isEditable
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(28, 28),
                onPressed: _clear,
                child: const Icon(
                  CupertinoIcons.clear_circled_solid,
                  size: 18,
                  color: CupertinoColors.systemGrey,
                ),
              )
            : null,
        style,
      ),
      decoration: cupertinoFieldDecoration(
        context: context,
        borderRadius: style.borderRadius,
        focused: _focusNode.hasFocus,
      ),
    );

    return d.decorateField(context, input);
  }
}

// ===========================================================================
// TomCupertinoFormNDateInput — TomField<DateTime?>
// ===========================================================================

@tomReflector
class TomCupertinoFormNDateInput extends TomField<DateTime?>
    with
        TomGenericFieldDecorationMixin<DateTime?>,
        _CupertinoNullableLabels<DateTime?> {
  @override
  final String? labelTextOverride;
  @override
  final String? hintTextOverride;
  @override
  final String? descriptionTextOverride;

  final DateTime firstDate;
  final DateTime lastDate;

  /// Height of the picker sheet (excluding the Cancel/Done bar).
  final double sheetHeight;

  TomCupertinoFormNDateInput(
    super.tomId,
    super.initialValue, {
    required this.firstDate,
    required this.lastDate,
    this.sheetHeight = 216,
    this.labelTextOverride,
    this.hintTextOverride,
    this.descriptionTextOverride,
    super.form,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
  }) : assert(
         !firstDate.isAfter(lastDate),
         'TomCupertinoFormNDateInput: firstDate must be on or before lastDate',
       ),
       assert(
         initialValue == null ||
             (!initialValue.isBefore(firstDate) &&
                 !initialValue.isAfter(lastDate)),
         'TomCupertinoFormNDateInput: initialValue (when non-null) must be '
         'within [firstDate, lastDate]',
       );

  @override
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.datePickerStyle, width);
  }

  String _format(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget get widget => TomFieldWidgetAdapter(
    field: this,
    child: _CupertinoNDateInputWidget(field: this),
  );
}

class _CupertinoNDateInputWidget extends StatefulWidget {
  final TomCupertinoFormNDateInput field;
  const _CupertinoNDateInputWidget({required this.field});

  @override
  State<_CupertinoNDateInputWidget> createState() =>
      _CupertinoNDateInputWidgetState();
}

class _CupertinoNDateInputWidgetState
    extends State<_CupertinoNDateInputWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormNDateInput get field => widget.field;

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

  Future<void> _open() async {
    DateTime temp = field.get() ?? DateTime.now();
    if (temp.isBefore(field.firstDate)) temp = field.firstDate;
    if (temp.isAfter(field.lastDate)) temp = field.lastDate;
    final picked = await showCupertinoModalPopup<DateTime?>(
      context: context,
      builder: (ctx) {
        DateTime tempValue = temp;
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
                      onPressed: () => Navigator.of(ctx).pop(null),
                      child: Text(TomFormLabels.cancel(field.basePath)),
                    ),
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(tempValue),
                      child: Text(TomFormLabels.done(field.basePath)),
                    ),
                  ],
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: temp,
                    minimumDate: field.firstDate,
                    maximumDate: field.lastDate,
                    onDateTimeChanged: (dt) => tempValue = dt,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) {
      field.setValue(DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = field;
    final style = f.resolveStyle(context);
    final v = f.get();

    final tile = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: f.isEditable ? _open : null,
      child: Container(
        padding: style.fieldContentPadding,
        decoration: cupertinoFieldDecoration(
          context: context,
          borderRadius: style.borderRadius,
        ),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.calendar,
              size: 18,
              color: CupertinoColors.secondaryLabel,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                v == null ? f.resolveNullDisplay() : f._format(v),
                style: style.inputStyle,
              ),
            ),
            if (v != null && f.isEditable)
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(28, 28),
                onPressed: () => f.setValue(null),
                child: const Icon(
                  CupertinoIcons.clear_circled_solid,
                  size: 18,
                  color: CupertinoColors.systemGrey,
                ),
              ),
          ],
        ),
      ),
    );

    return f.decorateField(context, tile);
  }
}
