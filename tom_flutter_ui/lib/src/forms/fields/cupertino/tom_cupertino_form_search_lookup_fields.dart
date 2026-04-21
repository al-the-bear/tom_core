/// Phase 5c — Cupertino Search / Lookup concretes.
///
/// Two concretes that subclass the Phase 4 abstract search / lookup bases:
///   * [TomCupertinoFormSearchInput]  → `CupertinoTextField` + inline
///                                      Autocomplete options overlay.
///   * [TomCupertinoFormLookupSheet]  → Tappable tile that opens a full
///                                      Cupertino modal sheet with a
///                                      `CupertinoSearchTextField` filter
///                                      and scrollable list.
///
/// Both share the decoration anatomy with their Material siblings via
/// [TomStringInputDecorationMixin] / [TomGenericFieldDecorationMixin], so
/// label / description / error visuals render identically — only the
/// inner control and overlay surfaces are Cupertino.
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Autocomplete, Divider, Material, Theme;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../../widget_base/tom_construction_helpers.dart';
import '../../decoration/tom_field_anatomy.dart';
import '../../decoration/tom_generic_field_decoration_mixin.dart';
import '../../decoration/tom_string_input_decoration_mixin.dart';
import '../../selection/tom_selectable_source.dart';
import '../../style/tom_cupertino_form_style.dart';
import '../../style/tom_form_style.dart';
import '../../style/tom_form_style_scope.dart';
import '../tom_field_widget_adapter.dart';
import '../tom_form_search_lookup_fields.dart';

// ===========================================================================
// TomCupertinoFormSearchInput<T> — Autocomplete with CupertinoTextField
// ===========================================================================

@tomReflector
class TomCupertinoFormSearchInput<T> extends TomFormSearchField<T>
    with TomStringInputDecorationMixin<T> {
  final TomSelectableSource<T> source;

  /// Custom predicate. Defaults to case-insensitive substring match on
  /// `SelectableItem.label`.
  final bool Function(String query, SelectableItem<T> item)? searchPredicate;

  /// Display-label resolver. Defaults to lookup against the current
  /// source snapshot, falling back to `value.toString()`.
  final String Function(T value)? labelOf;

  TomCupertinoFormSearchInput(
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
        child: _CupertinoSearchInputWidget<T>(field: this),
      );
}

class _CupertinoSearchInputWidget<T> extends StatefulWidget {
  final TomCupertinoFormSearchInput<T> field;
  const _CupertinoSearchInputWidget({required this.field});

  @override
  State<_CupertinoSearchInputWidget<T>> createState() =>
      _CupertinoSearchInputWidgetState<T>();
}

class _CupertinoSearchInputWidgetState<T>
    extends State<_CupertinoSearchInputWidget<T>> {
  StreamSubscription<List<SelectableItem<T>>>? _subscription;
  List<SelectableItem<T>> _items = const [];
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormSearchInput<T> get field => widget.field;

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
    final hit = _items
        .where((i) => i.value == v)
        .map((i) => i.label)
        .firstOrNull;
    return hit ?? (v?.toString() ?? '');
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
    final hint = f.hintText ?? 'Search…';

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
        return CupertinoTextField(
          controller: controller,
          focusNode: focusNode,
          enabled: f.isEditable,
          style: style.inputStyle,
          placeholder: hint,
          placeholderStyle: composeHintStyle(style, Theme.of(context)),
          padding: style.fieldContentPadding,
          prefix: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(
              CupertinoIcons.search,
              size: 18,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          onSubmitted: (_) => onSubmit(),
          decoration: cupertinoFieldDecoration(
            context: context,
            borderRadius: style.borderRadius,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 480),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (ctx, i) {
                  final it = options.elementAt(i);
                  return CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    alignment: Alignment.centerLeft,
                    onPressed: () => onSelected(it),
                    child: Text(
                      it.label,
                      style: style.inputStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    return f.decorateField(context, autocomplete);
  }
}

// ===========================================================================
// TomCupertinoFormLookupSheet<T> — Tile that opens a full Cupertino sheet
// ===========================================================================

@tomReflector
class TomCupertinoFormLookupSheet<T> extends TomFormLookupField<T>
    with TomGenericFieldDecorationMixin<T> {
  final TomSelectableSource<T> source;

  /// Display-label resolver. Defaults to lookup against the source
  /// snapshot, falling back to `value.toString()`.
  final String Function(T value)? labelOf;

  /// Title for the lookup sheet. Defaults to `labelText` or "Lookup".
  final String? sheetTitle;

  TomCupertinoFormLookupSheet(
    super.tomId,
    super.initialValue, {
    required this.source,
    this.labelOf,
    this.sheetTitle,
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

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _CupertinoLookupSheetWidget<T>(field: this),
      );
}

class _CupertinoLookupSheetWidget<T> extends StatefulWidget {
  final TomCupertinoFormLookupSheet<T> field;
  const _CupertinoLookupSheetWidget({required this.field});

  @override
  State<_CupertinoLookupSheetWidget<T>> createState() =>
      _CupertinoLookupSheetWidgetState<T>();
}

class _CupertinoLookupSheetWidgetState<T>
    extends State<_CupertinoLookupSheetWidget<T>> {
  StreamSubscription<List<SelectableItem<T>>>? _subscription;
  List<SelectableItem<T>> _items = const [];
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormLookupSheet<T> get field => widget.field;

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
    final hit = _items
        .where((i) => i.value == v)
        .map((i) => i.label)
        .firstOrNull;
    return hit ?? (v?.toString() ?? '');
  }

  Future<void> _openSheet() async {
    final picked = await showCupertinoModalPopup<T>(
      context: context,
      builder: (ctx) {
        final title = field.sheetTitle ?? field.labelText ?? 'Lookup';
        return _CupertinoLookupSheetBody<T>(
          title: title,
          items: _items,
        );
      },
    );
    if (picked != null && mounted) field.setValue(picked);
  }

  @override
  Widget build(BuildContext context) {
    final f = field;
    final style = f.resolveStyle(context);
    final v = f.get();
    final display = _label(v);

    final tile = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: f.isEditable ? _openSheet : null,
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
                display.isEmpty ? '—' : display,
                style: style.inputStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              CupertinoIcons.search,
              size: 18,
              color: CupertinoColors.secondaryLabel,
            ),
          ],
        ),
      ),
    );

    return f.decorateField(context, tile);
  }
}

/// Sheet body for [TomCupertinoFormLookupSheet]. Encapsulates the
/// filter-as-you-type state inside the popover so the outer widget
/// doesn't have to carry transient search state.
class _CupertinoLookupSheetBody<T> extends StatefulWidget {
  final String title;
  final List<SelectableItem<T>> items;
  const _CupertinoLookupSheetBody({required this.title, required this.items});

  @override
  State<_CupertinoLookupSheetBody<T>> createState() =>
      _CupertinoLookupSheetBodyState<T>();
}

class _CupertinoLookupSheetBodyState<T>
    extends State<_CupertinoLookupSheetBody<T>> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final visible = _filter.isEmpty
        ? widget.items
        : widget.items
            .where((it) =>
                it.label.toLowerCase().contains(_filter.toLowerCase()))
            .toList();

    final mediaHeight = MediaQuery.of(context).size.height;
    final sheetHeight = (mediaHeight * 0.7).clamp(320.0, 640.0);

    return Container(
      height: sheetHeight,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  Text(
                    widget.title,
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .navTitleTextStyle,
                  ),
                  const Spacer(),
                  const SizedBox(width: 64),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: CupertinoSearchTextField(
                placeholder: 'Filter…',
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: visible.length,
                separatorBuilder: (_, _) => Divider(
                  height: 0.5,
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
                itemBuilder: (ctx, i) {
                  final it = visible[i];
                  return CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    alignment: Alignment.centerLeft,
                    onPressed: it.enabled
                        ? () => Navigator.of(ctx).pop(it.value)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.label,
                          style: CupertinoTheme.of(ctx).textTheme.textStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (it.description != null)
                          Text(
                            it.description!,
                            style: CupertinoTheme.of(ctx)
                                .textTheme
                                .tabLabelTextStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
