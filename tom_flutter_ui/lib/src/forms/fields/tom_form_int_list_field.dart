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
// TomFormIntListField — Abstract multi-select list of ints
// ---------------------------------------------------------------------------
//
// Mirrors the surface of TomFormStringListField — same toggleItem semantics
// (allocate-fresh on mutate so TomField change detection fires), same
// labelTextOverride / descriptionTextOverride resource resolution.
abstract class TomFormIntListField extends TomField<List<int>> {
  /// Explicit label text (overrides resource lookup).
  final String? labelTextOverride;

  /// Explicit description text (overrides resource lookup).
  final String? descriptionTextOverride;

  TomFormIntListField(
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

  /// Toggle a value in/out of the selection. Allocates a fresh list so
  /// `TomField.setValue` can detect the change and fire its notifier.
  void toggleItem(int value, bool include) {
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
// TomFormIntFilterChips — multi-select FilterChip row over int values
// ---------------------------------------------------------------------------

@tomReflector
class TomFormIntFilterChips extends TomFormIntListField
    with TomGenericFieldDecorationMixin<List<int>> {
  final TomSelectableSource<int> source;

  /// Gap between chips. Defaults to 8.
  final double chipGap;

  TomFormIntFilterChips(
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
        child: _TomFormIntFilterChipsWidget(field: this),
      );
}

class _TomFormIntFilterChipsWidget extends StatefulWidget {
  final TomFormIntFilterChips field;
  const _TomFormIntFilterChipsWidget({required this.field});

  @override
  State<_TomFormIntFilterChipsWidget> createState() =>
      _TomFormIntFilterChipsWidgetState();
}

class _TomFormIntFilterChipsWidgetState
    extends State<_TomFormIntFilterChipsWidget> {
  StreamSubscription<List<SelectableItem<int>>>? _subscription;
  List<SelectableItem<int>> _items = const [];
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormIntFilterChips get field => widget.field;

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
    if (mounted) {
      setState(() => _items = initial);
      _pruneVanished(initial);
    }
    final stream = field.source.itemsStream;
    if (stream != null) {
      _subscription = stream.listen((next) {
        if (mounted) {
          setState(() => _items = next);
          _pruneVanished(next);
        }
      });
    }
  }

  void _pruneVanished(List<SelectableItem<int>> current) {
    final selected = field.get();
    if (selected.isEmpty) return;
    final available = current.map((i) => i.value).toSet();
    final pruned = selected.where(available.contains).toList();
    if (pruned.length != selected.length) field.setValue(pruned);
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
    final f = widget.field;
    final style = f.resolveStyle(context);
    final full = f.resolveFullStyle(context);
    final override = full.chipsStyle;

    final selected = f.get().toSet();

    final chips = Wrap(
      spacing: f.chipGap,
      runSpacing: f.chipGap,
      children: _items.map((item) {
        final isSelected = selected.contains(item.value);
        return FilterChip(
          label: Text(item.label, style: style.inputStyle),
          selected: isSelected,
          onSelected: f.isEditable && item.enabled
              ? (sel) => f.toggleItem(item.value, sel)
              : null,
          selectedColor:
              override?.selectedColor?.resolve(const {WidgetState.selected}),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );

    return f.decorateField(context, chips);
  }
}
