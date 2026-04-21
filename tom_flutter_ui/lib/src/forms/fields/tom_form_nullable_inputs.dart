/// Phase 4 — Nullable input variants.
///
/// Mirror the surface of the non-nullable Phase 1 / Phase 3 inputs but
/// bind a `T?` value so the user can express "explicitly empty" as a
/// distinct state from "default / pristine". Each variant ships with a
/// trailing clear icon that sets the value to `null`; for text inputs,
/// clearing the text also yields `null`.
///
/// Concretes:
///   * [TomFormNStringInput] — `TomField<String?>` text input.
///   * [TomFormNIntInput]    — `TomField<int?>` numeric input.
///   * [TomFormNDoubleInput] — `TomField<double?>` decimal input.
///   * [TomFormNDateInput]   — `TomField<DateTime?>` date picker button.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../decoration/tom_generic_field_decoration_mixin.dart';
import '../decoration/tom_string_input_decoration_mixin.dart';
import '../style/tom_form_style.dart';
import '../style/tom_form_style_scope.dart';
import '../tom_form.dart';
import 'tom_field_widget_adapter.dart';

// ===========================================================================
// Shared label / description resource resolution
// ===========================================================================

mixin _NullableFieldLabels<T> on TomField<T> {
  String? get labelTextOverride;
  String? get hintTextOverride;
  String? get descriptionTextOverride;

  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');
  String? get hintText =>
      hintTextOverride ?? TomCtr.textOrNull(basePath, 'hint');
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');
}

// ===========================================================================
// TomFormNStringInput — TomField<String?>
// ===========================================================================

@tomReflector
class TomFormNStringInput extends TomField<String?>
    with
        TomStringInputDecorationMixin<String?>,
        _NullableFieldLabels<String?> {
  @override
  final String? labelTextOverride;
  @override
  final String? hintTextOverride;
  @override
  final String? descriptionTextOverride;

  final int? maxLength;
  final Widget? prefixIcon;

  TomFormNStringInput(
    super.tomId,
    super.initialValue, {
    this.labelTextOverride,
    this.hintTextOverride,
    this.descriptionTextOverride,
    this.maxLength,
    this.prefixIcon,
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
        child: _NullableTextInputWidget<String?>(
          field: this,
          decorationField: this,
          format: (v) => v ?? '',
          parse: (text) => text.isEmpty ? null : text,
          keyboardType: TextInputType.text,
          inputFormatters: const [],
          maxLength: maxLength,
          prefixIcon: prefixIcon,
        ),
      );
}

// ===========================================================================
// TomFormNIntInput — TomField<int?>
// ===========================================================================

@tomReflector
class TomFormNIntInput extends TomField<int?>
    with
        TomStringInputDecorationMixin<int?>,
        _NullableFieldLabels<int?> {
  @override
  final String? labelTextOverride;
  @override
  final String? hintTextOverride;
  @override
  final String? descriptionTextOverride;

  final Widget? prefixIcon;

  TomFormNIntInput(
    super.tomId,
    super.initialValue, {
    this.labelTextOverride,
    this.hintTextOverride,
    this.descriptionTextOverride,
    this.prefixIcon,
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
        child: _NullableTextInputWidget<int?>(
          field: this,
          decorationField: this,
          format: (v) => v?.toString() ?? '',
          parse: (text) => text.isEmpty ? null : int.tryParse(text),
          keyboardType:
              const TextInputType.numberWithOptions(signed: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'-?\d*')),
          ],
          prefixIcon: prefixIcon,
          // Skip parse-failed text (e.g. mid-typing "-") so the field
          // doesn't flip to null while the user is still composing.
          skipUnparseableNonEmpty: true,
        ),
      );
}

// ===========================================================================
// TomFormNDoubleInput — TomField<double?>
// ===========================================================================

@tomReflector
class TomFormNDoubleInput extends TomField<double?>
    with
        TomStringInputDecorationMixin<double?>,
        _NullableFieldLabels<double?> {
  @override
  final String? labelTextOverride;
  @override
  final String? hintTextOverride;
  @override
  final String? descriptionTextOverride;

  final int? decimals;

  TomFormNDoubleInput(
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
        child: _NullableTextInputWidget<double?>(
          field: this,
          decorationField: this,
          format: _format,
          parse: (text) => text.isEmpty ? null : double.tryParse(text),
          keyboardType: const TextInputType.numberWithOptions(
              decimal: true, signed: true),
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

/// Type alias for whatever-the-concrete-field is (one of the three textual
/// nullable variants). Holds the methods needed to lay out the input —
/// `applyErrorVisualsTo`, `decorateField`, `resolveStyle` come from the
/// `TomStringInputDecorationMixin`; `labelText`/`hintText` from the
/// `_NullableFieldLabels` mixin.
typedef _NullableInputDecorator = TomStringInputDecorationMixin;

class _NullableTextInputWidget<T> extends StatefulWidget {
  final TomField<T> field;

  /// Same instance as [field], but typed so we can call the decoration
  /// mixin methods (`applyErrorVisualsTo`, `decorateField`, `resolveStyle`)
  /// and the `_NullableFieldLabels` getters without an `is` check that
  /// the analyzer can't promote across the generic boundary.
  final _NullableInputDecorator decorationField;

  final String Function(T value) format;
  final T Function(String text) parse;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;

  /// Optional max length (only [TomFormNStringInput] uses it).
  final int? maxLength;

  /// Optional prefix icon ([TomFormNStringInput] / [TomFormNIntInput]).
  final Widget? prefixIcon;

  /// If true, when the parsed value is null but the input text isn't
  /// empty, leave the field value alone (used by numeric variants while
  /// the user is mid-typing an unparseable token like a lone `-`).
  final bool skipUnparseableNonEmpty;

  const _NullableTextInputWidget({
    required this.field,
    required this.decorationField,
    required this.format,
    required this.parse,
    required this.keyboardType,
    required this.inputFormatters,
    this.maxLength,
    this.prefixIcon,
    this.skipUnparseableNonEmpty = false,
  });

  @override
  State<_NullableTextInputWidget<T>> createState() =>
      _NullableTextInputWidgetState<T>();
}

class _NullableTextInputWidgetState<T>
    extends State<_NullableTextInputWidget<T>> {
  late final TextEditingController _controller;
  late final TomFunctionObserver<TomObservable> _observer;
  bool _updatingFromField = false;

  TomField<T> get field => widget.field;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.format(field.get()));
    _observer = field >> (observable) {
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

    final decoration = InputDecoration(
      labelText: d.labelText,
      hintText: '— null —',
      prefixIcon: widget.prefixIcon,
      suffixIcon: hasValue && f.isEditable
          ? IconButton(
              icon: const Icon(Icons.clear, size: 18),
              tooltip: 'Clear (set to null)',
              onPressed: _clear,
            )
          : null,
      contentPadding: style.fieldContentPadding,
      border: style.fieldBorder,
      focusedBorder: style.focusedBorder,
      errorBorder: style.errorBorder,
      enabledBorder: style.fieldBorder,
    );

    final textField = TextField(
      controller: _controller,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      maxLength: widget.maxLength,
      style: style.inputStyle,
      onChanged: f.isEditable ? _onChanged : null,
      enabled: f.isEditable,
      decoration: d.applyErrorVisualsTo(context, decoration),
    );

    return d.decorateField(context, textField);
  }
}

// ===========================================================================
// TomFormNDateInput — TomField<DateTime?>
// ===========================================================================

@tomReflector
class TomFormNDateInput extends TomField<DateTime?>
    with
        TomGenericFieldDecorationMixin<DateTime?>,
        _NullableFieldLabels<DateTime?> {
  @override
  final String? labelTextOverride;
  @override
  final String? hintTextOverride;
  @override
  final String? descriptionTextOverride;

  final DateTime firstDate;
  final DateTime lastDate;

  TomFormNDateInput(
    super.tomId,
    super.initialValue, {
    required this.firstDate,
    required this.lastDate,
    this.labelTextOverride,
    this.hintTextOverride,
    this.descriptionTextOverride,
    super.form,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
  })  : assert(!firstDate.isAfter(lastDate),
            'TomFormNDateInput: firstDate must be on or before lastDate'),
        assert(
            initialValue == null ||
                (!initialValue.isBefore(firstDate) &&
                    !initialValue.isAfter(lastDate)),
            'TomFormNDateInput: initialValue (when non-null) must be within '
            '[firstDate, lastDate]');

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
        child: _NDateInputWidget(field: this),
      );
}

class _NDateInputWidget extends StatefulWidget {
  final TomFormNDateInput field;
  const _NDateInputWidget({required this.field});

  @override
  State<_NDateInputWidget> createState() => _NDateInputWidgetState();
}

class _NDateInputWidgetState extends State<_NDateInputWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormNDateInput get field => widget.field;

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

  Future<void> _open() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: field.get() ?? DateTime.now(),
      firstDate: field.firstDate,
      lastDate: field.lastDate,
    );
    if (picked != null) {
      field.setValue(DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = field;
    final theme = Theme.of(context);
    final v = f.get();

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: f.isEditable ? _open : null,
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(
            v == null ? '— null —' : f._format(v),
            style: theme.textTheme.bodyMedium,
          ),
        ),
        if (v != null && f.isEditable)
          IconButton(
            tooltip: 'Clear (set to null)',
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () => f.setValue(null),
          ),
      ],
    );

    return f.decorateField(context, row);
  }
}
