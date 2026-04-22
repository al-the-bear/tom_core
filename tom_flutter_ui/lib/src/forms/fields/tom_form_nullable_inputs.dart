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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../decoration/tom_dropdown_decoration_mixin.dart';
import '../decoration/tom_generic_field_decoration_mixin.dart';
import '../decoration/tom_string_input_decoration_mixin.dart';
import '../selection/tom_selectable_source.dart';
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

  /// Optional explicit text rendered in place of the value when the
  /// bound field is `null`. Resolution order, applied by every nullable
  /// concrete:
  ///   1. `nullDisplayOverride` (if non-null) — explicit "show this
  ///      exact text" mode. Pass `''` to render truly empty.
  ///   2. Field-scoped resource `basePath.nullDisplay` — lets demo /
  ///      app authors localise the placeholder without recompiling.
  ///   3. `hintTextOverride` / `hint` resource — hint-based mode that
  ///      mirrors how regular text inputs surface their hint when empty.
  ///   4. Default sentinel `'— null —'` so untouched fields stay
  ///      visually distinguishable from a "set" empty string.
  String? get nullDisplayOverride;

  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');
  String? get hintText =>
      hintTextOverride ?? TomCtr.textOrNull(basePath, 'hint');
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  /// Text shown in place of the value when null, applying the resolution
  /// order documented on [nullDisplayOverride]. Concretes call this from
  /// their widget builders.
  String resolveNullDisplay() {
    if (nullDisplayOverride != null) return nullDisplayOverride!;
    // Round-5 (k.b): consult the resource chain for a `nullDisplay`
    // override before falling through to the hint / sentinel. Lets
    // forms ship a localised "Not set" / "Bitte wählen" placeholder
    // without touching the field declaration.
    final resourced = TomCtr.textOrNull(basePath, 'nullDisplay');
    if (resourced != null) return resourced;
    final hint = hintText;
    if (hint != null) return hint;
    return '— null —';
  }
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
  @override
  final String? nullDisplayOverride;

  final int? maxLength;
  final Widget? prefixIcon;

  TomFormNStringInput(
    super.tomId,
    super.initialValue, {
    this.labelTextOverride,
    this.hintTextOverride,
    this.descriptionTextOverride,
    this.nullDisplayOverride,
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
          nullDisplay: resolveNullDisplay,
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
  @override
  final String? nullDisplayOverride;

  final Widget? prefixIcon;

  TomFormNIntInput(
    super.tomId,
    super.initialValue, {
    this.labelTextOverride,
    this.hintTextOverride,
    this.descriptionTextOverride,
    this.nullDisplayOverride,
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
          nullDisplay: resolveNullDisplay,
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
  @override
  final String? nullDisplayOverride;

  final int? decimals;

  TomFormNDoubleInput(
    super.tomId,
    super.initialValue, {
    this.labelTextOverride,
    this.hintTextOverride,
    this.descriptionTextOverride,
    this.nullDisplayOverride,
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
          nullDisplay: resolveNullDisplay,
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
/// `TomStringInputDecorationMixin`; `labelText`/`hintText`/
/// `resolveNullDisplay()` from the `_NullableFieldLabels` mixin.
typedef _NullableInputDecorator = TomStringInputDecorationMixin;

class _NullableTextInputWidget<T> extends StatefulWidget {
  final TomField<T> field;

  /// Same instance as [field], but typed so we can call the decoration
  /// mixin methods (`applyErrorVisualsTo`, `decorateField`, `resolveStyle`)
  /// and the `_NullableFieldLabels` getters without an `is` check that
  /// the analyzer can't promote across the generic boundary.
  final _NullableInputDecorator decorationField;

  /// Resolves the placeholder shown in place of the value when the bound
  /// field is null. Closure so each concrete can wire it through its own
  /// `_NullableFieldLabels` mixin instance (the static analyzer can't
  /// see the mixin across the generic boundary).
  final String Function() nullDisplay;

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
    required this.nullDisplay,
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
    final resolvedNullDisplay = widget.nullDisplay();

    final decoration = InputDecoration(
      labelText: d.labelText,
      // Resolved by the concrete via the `_NullableFieldLabels` mixin —
      // honours `nullDisplayOverride` (incl. empty for "render nothing"),
      // then `hintTextOverride`, then the `'— null —'` default.
      hintText: resolvedNullDisplay,
      // Round-6 (k.a) — when the resolved null display is truly empty
      // (`nullDisplayOverride: ''` mode), force the label to stay
      // floating. Otherwise Material's InputDecorator drops the
      // labelText into the field area as a stand-in placeholder when
      // both value and hintText are empty, defeating the documented
      // "render nothing when the value is null" mode.
      floatingLabelBehavior: resolvedNullDisplay.isEmpty
          ? FloatingLabelBehavior.always
          : null,
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
  @override
  final String? nullDisplayOverride;

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
    this.nullDisplayOverride,
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
            v == null ? f.resolveNullDisplay() : f._format(v),
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

// ===========================================================================
// TomFormNEnumDropdown<T> — TomField<T?> backed by a TomSelectableSource<T>
// ===========================================================================
//
// Mirrors `TomFormEnumDropdown<T>` but binds a nullable value so the user
// can pick "no selection". The null entry is rendered as the leading
// dropdown item; its label is fully customizable through
// `nullDisplayOverride` / `hintTextOverride` (resolution order documented
// on `_NullableFieldLabels.resolveNullDisplay`). Rest of the surface
// (label, description, source) matches the non-nullable dropdown.

@tomReflector
class TomFormNEnumDropdown<T> extends TomField<T?>
    with
        TomDropdownDecorationMixin<T?>,
        _NullableFieldLabels<T?> {
  final TomSelectableSource<T> source;

  @override
  final String? labelTextOverride;
  @override
  final String? hintTextOverride;
  @override
  final String? descriptionTextOverride;
  @override
  final String? nullDisplayOverride;

  TomFormNEnumDropdown(
    super.tomId,
    super.initialValue, {
    required this.source,
    this.labelTextOverride,
    this.hintTextOverride,
    this.descriptionTextOverride,
    this.nullDisplayOverride,
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

  // Mixin defaults to `null` for both — restore the standard label
  // resolution chain so the field anatomy renders the label above.
  @override
  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');

  @override
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _NEnumDropdownWidget<T>(field: this),
      );
}

class _NEnumDropdownWidget<T> extends StatefulWidget {
  final TomFormNEnumDropdown<T> field;
  const _NEnumDropdownWidget({required this.field});

  @override
  State<_NEnumDropdownWidget<T>> createState() =>
      _NEnumDropdownWidgetState<T>();
}

class _NEnumDropdownWidgetState<T> extends State<_NEnumDropdownWidget<T>> {
  StreamSubscription<List<SelectableItem<T>>>? _subscription;
  List<SelectableItem<T>> _items = const [];
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormNEnumDropdown<T> get field => widget.field;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _observer = field >> (_) {
      if (mounted) setState(() {});
    };
    field.validationListenable.addListener(_onValidationChanged);
  }

  void _onValidationChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadItems() async {
    final initial = await field.source.getItems();
    if (mounted) setState(() => _items = initial);
    final stream = field.source.itemsStream;
    if (stream != null) {
      _subscription = stream.listen((next) {
        if (mounted) setState(() => _items = next);
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    field.validationListenable.removeListener(_onValidationChanged);
    field.removeObserver(_observer);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = field;
    final style = f.resolveStyle(context);
    final inputStyle =
        style.inputStyle ?? Theme.of(context).textTheme.bodyMedium;
    final current = f.get();

    // Leading null item — its label is the resolved null display, so
    // the user can choose any of the three modes (truly empty, custom
    // text, hint-based).
    final nullLabel = f.resolveNullDisplay();
    final menuItems = <DropdownMenuItem<T?>>[
      DropdownMenuItem<T?>(
        value: null,
        // Render in italics to mark it as "no value" rather than a real
        // option from the source. Keeps the input style otherwise so
        // typography stays consistent with the rest of the form.
        //
        // Round-5 (k.a): pass the resolved label through verbatim. We
        // used to substitute `' '` for an empty label so the menu item
        // kept clickable height; that broke the documented "empty
        // when null" mode by drawing a visible single-space line in
        // both the menu and the closed dropdown's selected slot. The
        // SizedBox(height: kMinInteractiveDimension) preserves a
        // tappable target even when the rendered text is zero-width.
        child: SizedBox(
          height: kMinInteractiveDimension,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              nullLabel,
              style: inputStyle?.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ),
      ),
      for (final it in _items)
        DropdownMenuItem<T?>(
          value: it.value,
          enabled: it.enabled,
          child: Text(it.label, style: inputStyle),
        ),
    ];

    final dropdown = DropdownButtonFormField<T?>(
      // The leading null item is always present; if `current` isn't in
      // the source we still pass it through (rendered as null fallback).
      initialValue: current == null ||
              _items.any((i) => i.value == current)
          ? current
          : null,
      style: inputStyle,
      items: menuItems,
      onChanged: f.isEditable ? f.setValue : null,
      decoration: f.applyErrorVisualsTo(
        context,
        InputDecoration(
          labelText: f.labelText,
          contentPadding: style.fieldContentPadding,
          border: style.fieldBorder,
          focusedBorder: style.focusedBorder,
          errorBorder: style.errorBorder,
          enabledBorder: style.fieldBorder,
        ),
      ),
    );
    return f.decorateField(context, dropdown);
  }
}
