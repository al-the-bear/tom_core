library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../decoration/tom_generic_field_decoration_mixin.dart';
import '../selection/tom_selectable_source.dart';
import '../style/tom_form_style.dart';
import '../style/tom_form_style_scope.dart';
import 'tom_field_widget_adapter.dart';
import 'tom_form_string_field.dart';

// ---------------------------------------------------------------------------
// Shared state for single-select concretes that consume a
// TomSelectableSource<String>. Each widget mounts an instance and the
// mixin below loads the items + listens for stream updates + clears
// the field value when the current selection vanishes from the source
// (same semantics as TomFormStringDropdown).
// ---------------------------------------------------------------------------

mixin _SourceBackedStringWidgetStateMixin<TWidget extends StatefulWidget>
    on State<TWidget> {
  StreamSubscription<List<SelectableItem<String>>>? _subscription;
  List<SelectableItem<String>> items = const [];
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormStringField get field;
  TomSelectableSource<String> get source;

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
    final initial = await source.getItems();
    if (mounted) {
      setState(() => items = initial);
      _resetIfValueMissing(initial);
    }
    final stream = source.itemsStream;
    if (stream != null) {
      _subscription = stream.listen((next) {
        if (mounted) {
          setState(() => items = next);
          _resetIfValueMissing(next);
        }
      });
    }
  }

  void _resetIfValueMissing(List<SelectableItem<String>> current) {
    final v = field.get();
    if (v.isEmpty) return;
    final stillPresent = current.any((i) => i.value == v);
    if (!stillPresent) {
      final firstEnabled =
          current.where((i) => i.enabled).firstOrNull?.value ?? '';
      field.setValue(firstEnabled);
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
// TomFormStringSegmented — single-select SegmentedButton
// ---------------------------------------------------------------------------

@tomReflector
class TomFormStringSegmented extends TomFormStringField
    with TomGenericFieldDecorationMixin<String> {
  final TomSelectableSource<String> source;

  TomFormStringSegmented(
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
    return form.resolveFieldStyle(form.segmentedStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _TomFormStringSegmentedWidget(field: this),
      );
}

class _TomFormStringSegmentedWidget extends StatefulWidget {
  final TomFormStringSegmented field;
  const _TomFormStringSegmentedWidget({required this.field});

  @override
  State<_TomFormStringSegmentedWidget> createState() =>
      _TomFormStringSegmentedWidgetState();
}

class _TomFormStringSegmentedWidgetState
    extends State<_TomFormStringSegmentedWidget>
    with _SourceBackedStringWidgetStateMixin<_TomFormStringSegmentedWidget> {
  @override
  TomFormStringField get field => widget.field;

  @override
  TomSelectableSource<String> get source => widget.field.source;

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final style = f.resolveStyle(context);
    final full = f.resolveFullStyle(context);
    final override = full.segmentedStyle;

    final selected = f.get();
    final selectionSet = <String>{
      if (selected.isNotEmpty) selected,
    };

    // SegmentedButton requires at least one segment; when items haven't
    // loaded yet render a disabled placeholder so the anatomy row stays
    // stable.
    final segments = items.isEmpty
        ? [
            ButtonSegment<String>(
              value: '',
              label: Text('…', style: style.inputStyle),
              enabled: false,
            ),
          ]
        : items
            .map((it) => ButtonSegment<String>(
                  value: it.value,
                  label: Text(it.label, style: style.inputStyle),
                  enabled: it.enabled,
                ))
            .toList();

    final segmented = SegmentedButton<String>(
      segments: segments,
      // SegmentedButton requires a non-empty selection; fall back to
      // whatever first item the items list has when the field value
      // hasn't resolved yet (same behaviour as the dropdown's hint
      // state).
      selected: selectionSet.isEmpty
          ? {items.isEmpty ? '' : items.first.value}
          : selectionSet,
      showSelectedIcon: false,
      onSelectionChanged: f.isEditable && items.isNotEmpty
          ? (sel) {
              if (sel.isNotEmpty) f.setValue(sel.first);
            }
          : null,
      style: override?.selectedColor != null
          ? ButtonStyle(backgroundColor: override!.selectedColor)
          : null,
    );

    return f.decorateField(context, segmented);
  }
}

// ---------------------------------------------------------------------------
// TomFormStringRadioGroup — single-select radio column
// ---------------------------------------------------------------------------

@tomReflector
class TomFormStringRadioGroup extends TomFormStringField
    with TomGenericFieldDecorationMixin<String> {
  final TomSelectableSource<String> source;

  TomFormStringRadioGroup(
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
    return form.resolveFieldStyle(form.radioGroupStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _TomFormStringRadioGroupWidget(field: this),
      );
}

class _TomFormStringRadioGroupWidget extends StatefulWidget {
  final TomFormStringRadioGroup field;
  const _TomFormStringRadioGroupWidget({required this.field});

  @override
  State<_TomFormStringRadioGroupWidget> createState() =>
      _TomFormStringRadioGroupWidgetState();
}

class _TomFormStringRadioGroupWidgetState
    extends State<_TomFormStringRadioGroupWidget>
    with _SourceBackedStringWidgetStateMixin<_TomFormStringRadioGroupWidget> {
  @override
  TomFormStringField get field => widget.field;

  @override
  TomSelectableSource<String> get source => widget.field.source;

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final style = f.resolveStyle(context);
    final full = f.resolveFullStyle(context);
    final selectedColor = full.radioGroupStyle?.selectedColor;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: items.map((item) {
        return InkWell(
          onTap: f.isEditable && item.enabled
              ? () => f.setValue(item.value)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                // ignore: deprecated_member_use
                Radio<String>(
                  value: item.value,
                  // ignore: deprecated_member_use
                  groupValue: f.get(),
                  // ignore: deprecated_member_use
                  onChanged: f.isEditable && item.enabled
                      ? (v) {
                          if (v != null) f.setValue(v);
                        }
                      : null,
                  fillColor: selectedColor,
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

// ---------------------------------------------------------------------------
// TomFormStringChoiceChips — single-select ChoiceChip row
// ---------------------------------------------------------------------------

@tomReflector
class TomFormStringChoiceChips extends TomFormStringField
    with TomGenericFieldDecorationMixin<String> {
  final TomSelectableSource<String> source;

  /// Gap between chips. Defaults to 8.
  final double chipGap;

  TomFormStringChoiceChips(
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
        child: _TomFormStringChoiceChipsWidget(field: this),
      );
}

class _TomFormStringChoiceChipsWidget extends StatefulWidget {
  final TomFormStringChoiceChips field;
  const _TomFormStringChoiceChipsWidget({required this.field});

  @override
  State<_TomFormStringChoiceChipsWidget> createState() =>
      _TomFormStringChoiceChipsWidgetState();
}

class _TomFormStringChoiceChipsWidgetState
    extends State<_TomFormStringChoiceChipsWidget>
    with _SourceBackedStringWidgetStateMixin<_TomFormStringChoiceChipsWidget> {
  @override
  TomFormStringField get field => widget.field;

  @override
  TomSelectableSource<String> get source => widget.field.source;

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final style = f.resolveStyle(context);
    final full = f.resolveFullStyle(context);
    final override = full.chipsStyle;

    final chips = Wrap(
      spacing: f.chipGap,
      runSpacing: f.chipGap,
      children: items.map((item) {
        final isSelected = item.value == f.get();
        return ChoiceChip(
          label: Text(item.label, style: style.inputStyle),
          selected: isSelected,
          onSelected: f.isEditable && item.enabled
              ? (sel) {
                  if (sel) f.setValue(item.value);
                }
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
