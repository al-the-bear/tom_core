/// Phase 4 — Enum & Object selection fields.
///
/// Four abstract field types and their concretes:
///   * [TomFormEnumField] / [TomFormObjectField] — single-value selection
///     of an enum value or domain object from a [TomSelectableSource].
///   * [TomFormEnumListField] / [TomFormObjectListField] — multi-value
///     variants (filter chips).
///
/// Enum and Object fields are structurally identical (both render a
/// `TomSelectableSource<T>` of arbitrary `T`); they're separate types only
/// so call-sites read clearly: enums are closed sets, objects are open
/// sets typically driven by a domain repository. The runtime impl is
/// shared via a generic mixin so we don't duplicate widget code.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../decoration/tom_dropdown_decoration_mixin.dart';
import '../decoration/tom_generic_field_decoration_mixin.dart';
import '../selection/tom_selectable_source.dart';
import '../style/tom_form_style.dart';
import '../style/tom_form_style_scope.dart';
import '../tom_form.dart';
import 'tom_field_widget_adapter.dart';

// ===========================================================================
// Abstract field types
// ===========================================================================

/// Abstract base for single-value enum selection.
abstract class TomFormEnumField<T> extends TomField<T> {
  final String? labelTextOverride;
  final String? descriptionTextOverride;

  TomFormEnumField(
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

/// Abstract base for single-value domain-object selection. Same surface
/// as [TomFormEnumField] but a separate type so call-sites read clearly.
abstract class TomFormObjectField<T> extends TomField<T> {
  final String? labelTextOverride;
  final String? descriptionTextOverride;

  TomFormObjectField(
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

/// Abstract multi-select list of enum values.
abstract class TomFormEnumListField<T> extends TomField<List<T>> {
  final String? labelTextOverride;
  final String? descriptionTextOverride;

  TomFormEnumListField(
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

  void toggleItem(T value, bool include) {
    final next = [...get()];
    if (include) {
      if (!next.contains(value)) next.add(value);
    } else {
      next.remove(value);
    }
    setValue(next);
  }
}

/// Abstract multi-select list of domain objects.
abstract class TomFormObjectListField<T> extends TomField<List<T>> {
  final String? labelTextOverride;
  final String? descriptionTextOverride;

  TomFormObjectListField(
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

  void toggleItem(T value, bool include) {
    final next = [...get()];
    if (include) {
      if (!next.contains(value)) next.add(value);
    } else {
      next.remove(value);
    }
    setValue(next);
  }
}

// ===========================================================================
// Shared widget-state mixins
// ===========================================================================

mixin _SourceBackedSingleStateMixin<TWidget extends StatefulWidget, T>
    on State<TWidget> {
  StreamSubscription<List<SelectableItem<T>>>? _subscription;
  List<SelectableItem<T>> items = const [];
  late final TomFunctionObserver<TomObservable> _observer;

  TomField<T> get field;
  TomSelectableSource<T> get source;

  /// Optional sentinel: when the bound value disappears from the source
  /// and nothing else is selectable, fall back to this. Defaults to
  /// keeping the current value (no-op).
  T? get fallbackValue => null;

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
      _resetIfMissing(initial);
    }
    final stream = source.itemsStream;
    if (stream != null) {
      _subscription = stream.listen((next) {
        if (mounted) {
          setState(() => items = next);
          _resetIfMissing(next);
        }
      });
    }
  }

  void _resetIfMissing(List<SelectableItem<T>> current) {
    final v = field.get();
    final stillPresent = current.any((i) => i.value == v);
    if (!stillPresent) {
      final firstEnabled = current.where((i) => i.enabled).firstOrNull?.value;
      final fb = firstEnabled ?? fallbackValue;
      if (fb != null) field.setValue(fb);
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

mixin _SourceBackedListStateMixin<TWidget extends StatefulWidget, T>
    on State<TWidget> {
  StreamSubscription<List<SelectableItem<T>>>? _subscription;
  List<SelectableItem<T>> items = const [];
  late final TomFunctionObserver<TomObservable> _observer;

  TomField<List<T>> get field;
  TomSelectableSource<T> get source;

  /// Concrete subclasses delegate the toggle to their abstract field's
  /// `toggleItem` (since both `TomFormEnumListField` and
  /// `TomFormObjectListField` ship one). Mixin can't see those classes
  /// so we wire it through a callback.
  void toggle(T value, bool include);

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
      _prune(initial);
    }
    final stream = source.itemsStream;
    if (stream != null) {
      _subscription = stream.listen((next) {
        if (mounted) {
          setState(() => items = next);
          _prune(next);
        }
      });
    }
  }

  void _prune(List<SelectableItem<T>> current) {
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
}

// ===========================================================================
// TomFormEnumDropdown<T>
// ===========================================================================

@tomReflector
class TomFormEnumDropdown<T> extends TomFormEnumField<T>
    with TomDropdownDecorationMixin<T> {
  final TomSelectableSource<T> source;

  TomFormEnumDropdown(
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
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _EnumDropdownWidget<T>(field: this),
      );
}

class _EnumDropdownWidget<T> extends StatefulWidget {
  final TomFormEnumDropdown<T> field;
  const _EnumDropdownWidget({required this.field});

  @override
  State<_EnumDropdownWidget<T>> createState() => _EnumDropdownWidgetState<T>();
}

class _EnumDropdownWidgetState<T> extends State<_EnumDropdownWidget<T>>
    with _SourceBackedSingleStateMixin<_EnumDropdownWidget<T>, T> {
  @override
  TomField<T> get field => widget.field;

  @override
  TomSelectableSource<T> get source => widget.field.source;

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final style = f.resolveStyle(context);
    final current = f.get();
    final dropdown = DropdownButtonFormField<T>(
      initialValue:
          items.any((i) => i.value == current) ? current : null,
      isExpanded: f.dropdownFillsColumnWidth,
      style: style.inputStyle,
      items: items
          .map((it) => DropdownMenuItem<T>(
                value: it.value,
                enabled: it.enabled,
                child: f.dropdownItemLabel(it.label, style.inputStyle),
              ))
          .toList(),
      onChanged: f.isEditable
          ? (v) {
              if (v != null) f.setValue(v);
            }
          : null,
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

// ===========================================================================
// TomFormEnumSegmented<T>
// ===========================================================================

@tomReflector
class TomFormEnumSegmented<T> extends TomFormEnumField<T>
    with TomGenericFieldDecorationMixin<T> {
  final TomSelectableSource<T> source;

  TomFormEnumSegmented(
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
        child: _EnumSegmentedWidget<T>(field: this),
      );
}

class _EnumSegmentedWidget<T> extends StatefulWidget {
  final TomFormEnumSegmented<T> field;
  const _EnumSegmentedWidget({required this.field});

  @override
  State<_EnumSegmentedWidget<T>> createState() =>
      _EnumSegmentedWidgetState<T>();
}

class _EnumSegmentedWidgetState<T> extends State<_EnumSegmentedWidget<T>>
    with _SourceBackedSingleStateMixin<_EnumSegmentedWidget<T>, T> {
  @override
  TomField<T> get field => widget.field;

  @override
  TomSelectableSource<T> get source => widget.field.source;

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final style = f.resolveStyle(context);
    final v = f.get();

    if (items.isEmpty) {
      return f.decorateField(
        context,
        Text('…', style: style.inputStyle),
      );
    }

    final segmented = SegmentedButton<T>(
      segments: items
          .map((it) => ButtonSegment<T>(
                value: it.value,
                label: Text(it.label, style: style.inputStyle),
                enabled: it.enabled,
              ))
          .toList(),
      selected: items.any((i) => i.value == v) ? {v} : {items.first.value},
      showSelectedIcon: false,
      onSelectionChanged: f.isEditable
          ? (sel) {
              if (sel.isNotEmpty) f.setValue(sel.first);
            }
          : null,
    );

    return f.decorateField(context, segmented);
  }
}

// ===========================================================================
// TomFormEnumRadioGroup<T>
// ===========================================================================

@tomReflector
class TomFormEnumRadioGroup<T> extends TomFormEnumField<T>
    with TomGenericFieldDecorationMixin<T> {
  final TomSelectableSource<T> source;

  TomFormEnumRadioGroup(
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
        child: _EnumRadioGroupWidget<T>(field: this),
      );
}

class _EnumRadioGroupWidget<T> extends StatefulWidget {
  final TomFormEnumRadioGroup<T> field;
  const _EnumRadioGroupWidget({required this.field});

  @override
  State<_EnumRadioGroupWidget<T>> createState() =>
      _EnumRadioGroupWidgetState<T>();
}

class _EnumRadioGroupWidgetState<T> extends State<_EnumRadioGroupWidget<T>>
    with _SourceBackedSingleStateMixin<_EnumRadioGroupWidget<T>, T> {
  @override
  TomField<T> get field => widget.field;

  @override
  TomSelectableSource<T> get source => widget.field.source;

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final style = f.resolveStyle(context);
    final v = f.get();

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
                Radio<T>(
                  value: item.value,
                  // ignore: deprecated_member_use
                  groupValue: v,
                  // ignore: deprecated_member_use
                  onChanged: f.isEditable && item.enabled
                      ? (nv) {
                          if (nv != null) f.setValue(nv);
                        }
                      : null,
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

// ===========================================================================
// TomFormEnumFilterChips<T> — multi-select
// ===========================================================================

@tomReflector
class TomFormEnumFilterChips<T> extends TomFormEnumListField<T>
    with TomGenericFieldDecorationMixin<List<T>> {
  final TomSelectableSource<T> source;
  final double chipGap;

  TomFormEnumFilterChips(
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
        child: _EnumFilterChipsWidget<T>(field: this),
      );
}

class _EnumFilterChipsWidget<T> extends StatefulWidget {
  final TomFormEnumFilterChips<T> field;
  const _EnumFilterChipsWidget({required this.field});

  @override
  State<_EnumFilterChipsWidget<T>> createState() =>
      _EnumFilterChipsWidgetState<T>();
}

class _EnumFilterChipsWidgetState<T> extends State<_EnumFilterChipsWidget<T>>
    with _SourceBackedListStateMixin<_EnumFilterChipsWidget<T>, T> {
  @override
  TomField<List<T>> get field => widget.field;

  @override
  TomSelectableSource<T> get source => widget.field.source;

  @override
  void toggle(T value, bool include) =>
      widget.field.toggleItem(value, include);

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final style = f.resolveStyle(context);
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
              ? (sel) => toggle(item.value, sel)
              : null,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );

    return f.decorateField(context, chips);
  }
}

// ===========================================================================
// TomFormObjectDropdown<T>
// ===========================================================================

@tomReflector
class TomFormObjectDropdown<T> extends TomFormObjectField<T>
    with TomDropdownDecorationMixin<T> {
  final TomSelectableSource<T> source;

  TomFormObjectDropdown(
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
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _ObjectDropdownWidget<T>(field: this),
      );
}

class _ObjectDropdownWidget<T> extends StatefulWidget {
  final TomFormObjectDropdown<T> field;
  const _ObjectDropdownWidget({required this.field});

  @override
  State<_ObjectDropdownWidget<T>> createState() =>
      _ObjectDropdownWidgetState<T>();
}

class _ObjectDropdownWidgetState<T> extends State<_ObjectDropdownWidget<T>>
    with _SourceBackedSingleStateMixin<_ObjectDropdownWidget<T>, T> {
  @override
  TomField<T> get field => widget.field;

  @override
  TomSelectableSource<T> get source => widget.field.source;

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final style = f.resolveStyle(context);
    final v = f.get();

    final dropdown = DropdownButtonFormField<T>(
      initialValue: items.any((i) => i.value == v) ? v : null,
      isExpanded: f.dropdownFillsColumnWidth,
      style: style.inputStyle,
      items: items
          .map((it) => DropdownMenuItem<T>(
                value: it.value,
                enabled: it.enabled,
                child: f.dropdownItemLabel(it.label, style.inputStyle),
              ))
          .toList(),
      onChanged: f.isEditable
          ? (nv) {
              if (nv != null) f.setValue(nv);
            }
          : null,
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

// ===========================================================================
// TomFormObjectFilterChips<T>
// ===========================================================================

@tomReflector
class TomFormObjectFilterChips<T> extends TomFormObjectListField<T>
    with TomGenericFieldDecorationMixin<List<T>> {
  final TomSelectableSource<T> source;
  final double chipGap;

  TomFormObjectFilterChips(
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
        child: _ObjectFilterChipsWidget<T>(field: this),
      );
}

class _ObjectFilterChipsWidget<T> extends StatefulWidget {
  final TomFormObjectFilterChips<T> field;
  const _ObjectFilterChipsWidget({required this.field});

  @override
  State<_ObjectFilterChipsWidget<T>> createState() =>
      _ObjectFilterChipsWidgetState<T>();
}

class _ObjectFilterChipsWidgetState<T>
    extends State<_ObjectFilterChipsWidget<T>>
    with _SourceBackedListStateMixin<_ObjectFilterChipsWidget<T>, T> {
  @override
  TomField<List<T>> get field => widget.field;

  @override
  TomSelectableSource<T> get source => widget.field.source;

  @override
  void toggle(T value, bool include) =>
      widget.field.toggleItem(value, include);

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final style = f.resolveStyle(context);
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
              ? (sel) => toggle(item.value, sel)
              : null,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );

    return f.decorateField(context, chips);
  }
}
