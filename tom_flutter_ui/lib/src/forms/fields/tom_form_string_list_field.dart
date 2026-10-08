library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../decoration/tom_generic_field_decoration_mixin.dart';
import '../selection/tom_selectable_source.dart';
import '../style/tom_form_style.dart';
import '../style/tom_form_style_scope.dart';
import '../tom_form.dart';
import 'tom_field_widget_adapter.dart';

// ---------------------------------------------------------------------------
// TomFormStringListField — Abstract multi-select list of strings
// (tom_ui_widgets_forms.md §6)
// ---------------------------------------------------------------------------

/// Abstract base for multi-select string form fields.
///
/// The field *is* the observable — `TomField<List<String>>` — so the bound
/// value is a plain `List<String>` in selection order, not a collection of
/// nested observables. [toggleItem] always publishes a fresh list, which is
/// what lets `setValue` see the change.
///
/// Concrete implementations render the selection as:
/// * [TomFormStringFilterChips] — a `Wrap` of `FilterChip`s.
/// * [TomFormStringMultiCheckbox] — a column of tappable `Checkbox` rows.
///
/// Both widgets share the same anatomy via
/// [TomGenericFieldDecorationMixin] and pull the item set from the
/// supplied [TomSelectableSource] — the subclasses only differ in how
/// they render each option.
abstract class TomFormStringListField extends TomField<List<String>> {
  /// Explicit label text (overrides resource lookup).
  final String? labelTextOverride;

  /// Explicit description text (overrides resource lookup).
  final String? descriptionTextOverride;

  TomFormStringListField(
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

  /// Resolved label: explicit → resource → null.
  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');

  /// Resolved description: explicit → resource → null.
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  /// Toggle an item in the current selection without mutating the list
  /// in place (always allocate a fresh list so `TomField.setValue` can
  /// detect the change and fire its notifier).
  void toggleItem(String value, bool include) {
    final current = get();
    final next = [...current];
    if (include) {
      if (!next.contains(value)) next.add(value);
    } else {
      next.remove(value);
    }
    setValue(next);
  }
}

// ---------------------------------------------------------------------------
// Shared state mixin for source-backed multi-select string fields.
// Handles async item loading, stream subscription, and pruning the
// selection when an item vanishes from the source.
// ---------------------------------------------------------------------------

mixin _SourceBackedStringListWidgetStateMixin<TWidget extends StatefulWidget>
    on State<TWidget> {
  StreamSubscription<List<TomSelectableItem<String>>>? _subscription;
  List<TomSelectableItem<String>> items = const [];
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormStringListField get field;
  TomSelectableSource<String> get source;

  @override
  void initState() {
    super.initState();
    _loadItems();
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

  Future<void> _loadItems() async {
    final initial = await source.getItems();
    if (mounted) {
      setState(() => items = initial);
      _pruneVanishedSelections(initial);
    }
    final stream = source.itemsStream;
    if (stream != null) {
      _subscription = stream.listen((next) {
        if (mounted) {
          setState(() => items = next);
          _pruneVanishedSelections(next);
        }
      });
    }
  }

  void _pruneVanishedSelections(List<TomSelectableItem<String>> current) {
    final selected = field.get();
    if (selected.isEmpty) return;
    final availableValues = current.map((i) => i.value).toSet();
    final pruned = selected.where(availableValues.contains).toList();
    if (pruned.length != selected.length) {
      field.setValue(pruned);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    field.validationListenable.removeListener(_onValidationChanged);
    field.removeObserver(_observer);
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// TomFormStringFilterChips — multi-select FilterChip row
// ---------------------------------------------------------------------------

@tomReflector
class TomFormStringFilterChips extends TomFormStringListField
    with TomGenericFieldDecorationMixin<List<String>> {
  final TomSelectableSource<String> source;

  /// Gap between chips. Defaults to 8.
  final double chipGap;

  TomFormStringFilterChips(
    super.tomId,
    super.initialValue, {
    required this.source,
    this.chipGap = 8.0,
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
    return form.resolveFieldStyle(form.chipsStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
    field: this,
    child: _TomFormStringFilterChipsWidget(field: this),
  );
}

class _TomFormStringFilterChipsWidget extends StatefulWidget {
  final TomFormStringFilterChips field;
  const _TomFormStringFilterChipsWidget({required this.field});

  @override
  State<_TomFormStringFilterChipsWidget> createState() =>
      _TomFormStringFilterChipsWidgetState();
}

class _TomFormStringFilterChipsWidgetState
    extends State<_TomFormStringFilterChipsWidget>
    with
        _SourceBackedStringListWidgetStateMixin<
          _TomFormStringFilterChipsWidget
        > {
  @override
  TomFormStringListField get field => widget.field;

  @override
  TomSelectableSource<String> get source => widget.field.source;

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final style = f.resolveStyle(context);
    final full = f.resolveFullStyle(context);
    final override = full.chipsStyle;

    final selected = f.get().toSet();

    final chips = Wrap(
      spacing: f.chipGap,
      runSpacing: f.chipGap,
      children: items.map((item) {
        final isSelected = selected.contains(item.value);
        return FilterChip(
          label: Text(item.label, style: style.inputStyle),
          selected: isSelected,
          onSelected: f.isEditable && item.enabled
              ? (sel) => f.toggleItem(item.value, sel)
              : null,
          selectedColor: override?.selectedColor?.resolve(const {
            WidgetState.selected,
          }),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );

    return f.decorateField(context, chips);
  }
}

// ---------------------------------------------------------------------------
// TomFormStringMultiCheckbox — multi-select Checkbox column
// ---------------------------------------------------------------------------

@tomReflector
class TomFormStringMultiCheckbox extends TomFormStringListField
    with TomGenericFieldDecorationMixin<List<String>> {
  final TomSelectableSource<String> source;

  TomFormStringMultiCheckbox(
    super.tomId,
    super.initialValue, {
    required this.source,
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
    return form.resolveFieldStyle(form.checkboxStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
    field: this,
    child: _TomFormStringMultiCheckboxWidget(field: this),
  );
}

class _TomFormStringMultiCheckboxWidget extends StatefulWidget {
  final TomFormStringMultiCheckbox field;
  const _TomFormStringMultiCheckboxWidget({required this.field});

  @override
  State<_TomFormStringMultiCheckboxWidget> createState() =>
      _TomFormStringMultiCheckboxWidgetState();
}

class _TomFormStringMultiCheckboxWidgetState
    extends State<_TomFormStringMultiCheckboxWidget>
    with
        _SourceBackedStringListWidgetStateMixin<
          _TomFormStringMultiCheckboxWidget
        > {
  @override
  TomFormStringListField get field => widget.field;

  @override
  TomSelectableSource<String> get source => widget.field.source;

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final style = f.resolveStyle(context);
    final full = f.resolveFullStyle(context);
    final override = full.checkboxStyle;

    final selected = f.get().toSet();

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: items.map((item) {
        final isSelected = selected.contains(item.value);
        return InkWell(
          onTap: f.isEditable && item.enabled
              ? () => f.toggleItem(item.value, !isSelected)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: f.isEditable && item.enabled
                      ? (v) {
                          if (v != null) f.toggleItem(item.value, v);
                        }
                      : null,
                  fillColor: override?.fillColor,
                  checkColor: override?.checkColor?.resolve(const {
                    WidgetState.selected,
                  }),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 4),
                Text(item.label, style: style.inputStyle),
              ],
            ),
          ),
        );
      }).toList(),
    );

    return f.decorateField(context, column);
  }
}
