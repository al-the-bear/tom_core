/// Phase 4 — Search & Lookup fields.
///
/// `TomFormSearchField<T>` is the type-ahead autocomplete pattern: large
/// candidate set, filter as the user types, single-pick. `TomFormLookupField<T>`
/// is the modal-picker pattern: candidate browsing happens in a dialog so
/// the form row stays compact.
///
/// Both consume a [TomSelectableSource] for items. Search relies on the
/// source returning the full set up-front and filters in-process — for
/// truly remote / paged sources, callers can provide a custom source
/// whose `getItems()` returns the current chunk.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../decoration/tom_dropdown_decoration_mixin.dart';
import '../decoration/tom_string_input_decoration_mixin.dart';
import '../selection/tom_selectable_source.dart';
import '../tom_form.dart';
import 'tom_field_widget_adapter.dart';

// ===========================================================================
// Abstract types
// ===========================================================================

/// Abstract base for search-style single-pick fields.
abstract class TomFormSearchField<T> extends TomField<T> {
  final String? labelTextOverride;
  final String? hintTextOverride;
  final String? descriptionTextOverride;

  TomFormSearchField(
    super.tomId,
    super.initialValue, {
    this.labelTextOverride,
    this.hintTextOverride,
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
  });

  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');
  String? get hintText =>
      hintTextOverride ?? TomCtr.textOrNull(basePath, 'hint');
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');
}

/// Abstract base for modal-picker lookup fields.
abstract class TomFormLookupField<T> extends TomField<T> {
  final String? labelTextOverride;
  final String? descriptionTextOverride;

  TomFormLookupField(
    super.tomId,
    super.initialValue, {
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
  });

  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');
}

// ===========================================================================
// TomFormSearchInput<T> — Autocomplete-driven type-ahead picker
// ===========================================================================

@tomReflector
class TomFormSearchInput<T> extends TomFormSearchField<T>
    with TomStringInputDecorationMixin<T> {
  final TomSelectableSource<T> source;

  /// Custom search predicate. Defaults to substring (case-insensitive)
  /// match against `SelectableItem.label`.
  final bool Function(String query, SelectableItem<T> item)? searchPredicate;

  /// Map from selected value → display string. Required because the
  /// `TextEditingController` round-trips through string. Defaults to the
  /// matching item's label, or `value.toString()` if the value isn't in
  /// the source's snapshot.
  final String Function(T value)? labelOf;

  TomFormSearchInput(
    super.tomId,
    super.initialValue, {
    required this.source,
    this.searchPredicate,
    this.labelOf,
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
        child: _SearchInputWidget<T>(field: this),
      );
}

class _SearchInputWidget<T> extends StatefulWidget {
  final TomFormSearchInput<T> field;
  const _SearchInputWidget({required this.field});

  @override
  State<_SearchInputWidget<T>> createState() => _SearchInputWidgetState<T>();
}

class _SearchInputWidgetState<T> extends State<_SearchInputWidget<T>> {
  StreamSubscription<List<SelectableItem<T>>>? _subscription;
  List<SelectableItem<T>> _items = <SelectableItem<T>>[];
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormSearchInput<T> get field => widget.field;

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

  String _label(T v) {
    final fn = field.labelOf;
    if (fn != null) return fn(v);
    final hit = _items.firstWhere(
      (it) => it.value == v,
      orElse: () =>
          SelectableItem<T>(value: v, label: v?.toString() ?? ''),
    );
    return hit.label;
  }

  bool _match(String q, SelectableItem<T> it) {
    final pred = field.searchPredicate;
    if (pred != null) return pred(q, it);
    return it.label.toLowerCase().contains(q.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final f = field;
    final style = f.resolveStyle(context);

    final autocomplete = Autocomplete<SelectableItem<T>>(
      initialValue: TextEditingValue(text: _label(f.get())),
      displayStringForOption: (it) => it.label,
      optionsBuilder: (input) {
        final q = input.text;
        if (q.isEmpty) return _items.where((i) => i.enabled).take(50);
        return _items.where((i) => i.enabled && _match(q, i)).take(50);
      },
      onSelected: (it) => f.setValue(it.value),
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: f.isEditable,
          style: style.inputStyle,
          onSubmitted: (_) => onSubmit(),
          decoration: f.applyErrorVisualsTo(
            context,
            InputDecoration(
              labelText: f.labelText,
              hintText: f.hintText ?? 'Type to search…',
              suffixIcon: const Icon(Icons.search),
              contentPadding: style.fieldContentPadding,
              border: style.fieldBorder,
              focusedBorder: style.focusedBorder,
              errorBorder: style.errorBorder,
              enabledBorder: style.fieldBorder,
            ),
          ),
        );
      },
    );

    return f.decorateField(context, autocomplete);
  }
}

// ===========================================================================
// TomFormLookupDialog<T> — Read-only field + "Browse" dialog
// ===========================================================================

@tomReflector
class TomFormLookupDialog<T> extends TomFormLookupField<T>
    with TomDropdownDecorationMixin<T> {
  final TomSelectableSource<T> source;

  /// Display string for the selected value. Defaults to lookup against
  /// the source snapshot (or `value.toString()` if not present).
  final String Function(T value)? labelOf;

  /// Title for the lookup dialog. Defaults to `labelText` or "Lookup".
  final String? dialogTitle;

  TomFormLookupDialog(
    super.tomId,
    super.initialValue, {
    required this.source,
    this.labelOf,
    this.dialogTitle,
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
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _LookupDialogWidget<T>(field: this),
      );
}

class _LookupDialogWidget<T> extends StatefulWidget {
  final TomFormLookupDialog<T> field;
  const _LookupDialogWidget({required this.field});

  @override
  State<_LookupDialogWidget<T>> createState() => _LookupDialogWidgetState<T>();
}

class _LookupDialogWidgetState<T> extends State<_LookupDialogWidget<T>> {
  StreamSubscription<List<SelectableItem<T>>>? _subscription;
  List<SelectableItem<T>> _items = <SelectableItem<T>>[];
  late final TomFunctionObserver<TomObservable> _observer;

  /// Read-only controller mirrored from the bound field so the lookup
  /// row uses the same TextField anatomy (and therefore baseline,
  /// content-padding, and inputStyle) as every other text input. Was
  /// previously rendered through `InputDecorator` + `Text`, which left
  /// the display string visibly higher than other rows (round-4 item n).
  late final TextEditingController _displayController;

  TomFormLookupDialog<T> get field => widget.field;

  @override
  void initState() {
    super.initState();
    _displayController = TextEditingController();
    _loadItems();
    _observer = field >> (_) {
      if (mounted) {
        _syncDisplay();
        setState(() {});
      }
    };
    field.validationListenable.addListener(_onValidationChanged);
  }

  void _onValidationChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadItems() async {
    final initial = await field.source.getItems();
    if (mounted) {
      setState(() => _items = initial);
      _syncDisplay();
    }
    final stream = field.source.itemsStream;
    if (stream != null) {
      _subscription = stream.listen((next) {
        if (mounted) {
          setState(() => _items = next);
          _syncDisplay();
        }
      });
    }
  }

  void _syncDisplay() {
    final next = _label(field.get());
    if (_displayController.text != next) _displayController.text = next;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    field.validationListenable.removeListener(_onValidationChanged);
    field.removeObserver(_observer);
    _displayController.dispose();
    super.dispose();
  }

  String _label(T v) {
    final fn = field.labelOf;
    if (fn != null) return fn(v);
    final hit = _items.firstWhere(
      (it) => it.value == v,
      orElse: () =>
          SelectableItem<T>(value: v, label: v?.toString() ?? ''),
    );
    return hit.label;
  }

  Future<void> _openDialog() async {
    // Capture the form's input style so the dialog's filter input + list
    // tile labels render with the same font as the rest of the form
    // (round-4 item p). Fall back to the ambient `bodyMedium` so the
    // dialog still has a non-null explicit style even when the resolved
    // form style doesn't override it.
    final inputStyle = field.resolveStyle(context).inputStyle ??
        Theme.of(context).textTheme.bodyMedium;
    final picked = await showDialog<T>(
      context: context,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final visible = filter.isEmpty
                ? _items
                : _items
                    .where((it) =>
                        it.label.toLowerCase().contains(filter.toLowerCase()))
                    .toList();
            return AlertDialog(
              title: Text(field.dialogTitle ?? field.labelText ?? 'Lookup'),
              content: SizedBox(
                width: 400,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      // Outlined border so the icon sits visibly inside
                      // the input box (round-4 item o — was previously a
                      // dense underline that drew the icon on the
                      // separator between input and result list).
                      autofocus: true,
                      style: inputStyle,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 22),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        hintText: 'Filter…',
                        border: const OutlineInputBorder(),
                        focusedBorder: const OutlineInputBorder(),
                        enabledBorder: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => setLocal(() => filter = v),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (ctx, i) {
                          final it = visible[i];
                          return ListTile(
                            dense: true,
                            title: Text(it.label, style: inputStyle),
                            subtitle: it.description != null
                                ? Text(it.description!)
                                : null,
                            enabled: it.enabled,
                            onTap: () => Navigator.of(ctx).pop(it.value),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
    if (picked != null && mounted) field.setValue(picked);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final style = f.resolveStyle(context);

    // Use a read-only TextField so the lookup row shares the exact
    // baseline + content-padding + inputStyle pipeline as every other
    // text input. The trailing search icon doubles as the affordance
    // hint; the `onTap` opens the lookup dialog. Wrapping in
    // AbsorbPointer lets the InkWell receive the tap regardless of the
    // TextField's own gesture handling.
    // Same fallback the dialog uses — guarantees a non-null explicit
    // style so the lookup row reads visually like the rest of the form.
    final inputStyle =
        style.inputStyle ?? Theme.of(context).textTheme.bodyMedium;
    final input = TextField(
      controller: _displayController,
      readOnly: true,
      enabled: f.isEditable,
      style: inputStyle,
      mouseCursor: f.isEditable ? SystemMouseCursors.click : null,
      onTap: f.isEditable ? _openDialog : null,
      decoration: f.applyErrorVisualsTo(
        context,
        InputDecoration(
          hintText: '—',
          suffixIcon: IconButton(
            tooltip: 'Browse…',
            icon: const Icon(Icons.search, size: 20),
            onPressed: f.isEditable ? _openDialog : null,
          ),
          contentPadding: style.fieldContentPadding,
          border: style.fieldBorder,
          focusedBorder: style.focusedBorder,
          errorBorder: style.errorBorder,
          enabledBorder: style.fieldBorder,
        ),
      ),
    );

    return f.decorateField(context, input);
  }
}
