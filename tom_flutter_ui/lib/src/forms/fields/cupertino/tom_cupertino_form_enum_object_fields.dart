/// Phase 5c — Cupertino Enum / Object selection concretes.
///
/// Three concretes that subclass the same Phase 4 abstract enum / object
/// fields used by the Material side, but render through Cupertino
/// primitives:
///   * [TomCupertinoFormEnumPicker]      → `CupertinoPicker` modal sheet
///   * [TomCupertinoFormEnumSegmented]   → `CupertinoSlidingSegmentedControl`
///   * [TomCupertinoFormObjectPicker]    → `CupertinoPicker` modal sheet
///
/// `Enum` and `Object` fields share the exact same widget shape — they
/// only differ in the abstract base class, which exists so call-sites
/// read clearly (closed enum sets vs. open domain objects). All three
/// concretes use [TomGenericFieldDecorationMixin] so label / error /
/// description / action-icon anatomy renders through the same column
/// the Material counterparts use.
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../../widget_base/tom_construction_helpers.dart';
import '../../decoration/tom_generic_field_decoration_mixin.dart';
import '../../selection/tom_selectable_source.dart';
import '../../style/tom_cupertino_form_style.dart';
import '../../style/tom_form_style.dart';
import '../../style/tom_form_style_scope.dart';
import '../tom_field_widget_adapter.dart';
import '../tom_form_enum_object_fields.dart';

// ===========================================================================
// Shared modal-sheet picker helper
// ===========================================================================

/// Runs a Cupertino-style modal-sheet picker with a fixed Cancel/Done bar
/// above a [CupertinoPicker]. Returns the selected value (or `null` on
/// cancel). The picker's body is rendered inside a Cupertino popup so it
/// matches the look of the Phase 5b date / time pickers.
Future<T?> _showCupertinoListPicker<T>({
  required BuildContext context,
  required List<SelectableItem<T>> items,
  required int initialIndex,
  double sheetHeight = 216,
}) {
  return showCupertinoModalPopup<T?>(
    context: context,
    builder: (ctx) {
      int tempIndex = initialIndex;
      return Container(
        height: sheetHeight + 56,
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
                    child: const Text('Cancel'),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      if (tempIndex >= 0 && tempIndex < items.length) {
                        Navigator.of(ctx).pop(items[tempIndex].value);
                      } else {
                        Navigator.of(ctx).pop(null);
                      }
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
                    for (final item in items)
                      Center(child: Text(item.label)),
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

/// Shared Cupertino "tile" body — clickable surface with the selected
/// label on the left and a chevron-down hint on the right. Mirrors the
/// look of [TomCupertinoFormStringPicker].
Widget _cupertinoPickerTile({
  required BuildContext context,
  required TomFieldStyle style,
  required String displayLabel,
  required bool isEditable,
  required VoidCallback? onTap,
}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: isEditable ? onTap : null,
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
              displayLabel,
              style: style.inputStyle,
              overflow: TextOverflow.ellipsis,
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
}

// ===========================================================================
// TomCupertinoFormEnumPicker<T> — CupertinoPicker sheet
// ===========================================================================

@tomReflector
class TomCupertinoFormEnumPicker<T> extends TomFormEnumField<T>
    with TomGenericFieldDecorationMixin<T> {
  final TomSelectableSource<T> source;

  /// Optional placeholder shown when the bound value isn't present in the
  /// current source snapshot. Defaults to "Choose…".
  final String? placeholder;

  /// Height of the picker sheet (excluding the Cancel/Done bar).
  final double sheetHeight;

  TomCupertinoFormEnumPicker(
    super.tomId,
    super.initialValue, {
    required this.source,
    this.placeholder,
    this.sheetHeight = 216,
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
        child: _CupertinoEnumPickerWidget<T>(field: this),
      );
}

class _CupertinoEnumPickerWidget<T> extends StatefulWidget {
  final TomCupertinoFormEnumPicker<T> field;
  const _CupertinoEnumPickerWidget({required this.field});

  @override
  State<_CupertinoEnumPickerWidget<T>> createState() =>
      _CupertinoEnumPickerWidgetState<T>();
}

class _CupertinoEnumPickerWidgetState<T>
    extends State<_CupertinoEnumPickerWidget<T>> {
  StreamSubscription<List<SelectableItem<T>>>? _subscription;
  List<SelectableItem<T>> _items = const [];
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormEnumPicker<T> get field => widget.field;

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

  String _displayLabel() {
    if (_items.isEmpty) return field.placeholder ?? 'Choose…';
    final v = field.get();
    final hit = _items.where((i) => i.value == v).map((i) => i.label).firstOrNull;
    return hit ?? (field.placeholder ?? 'Choose…');
  }

  Future<void> _open() async {
    if (_items.isEmpty) return;
    final v = field.get();
    int initialIndex = _items.indexWhere((i) => i.value == v);
    if (initialIndex < 0) initialIndex = 0;
    final picked = await _showCupertinoListPicker<T>(
      context: context,
      items: _items,
      initialIndex: initialIndex,
      sheetHeight: field.sheetHeight,
    );
    if (picked != null && mounted) field.setValue(picked);
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final tile = _cupertinoPickerTile(
      context: context,
      style: style,
      displayLabel: _displayLabel(),
      isEditable: field.isEditable && _items.isNotEmpty,
      onTap: _open,
    );
    return field.decorateField(context, tile);
  }
}

// ===========================================================================
// TomCupertinoFormEnumSegmented<T> — CupertinoSlidingSegmentedControl
// ===========================================================================

@tomReflector
class TomCupertinoFormEnumSegmented<T extends Object> extends TomFormEnumField<T>
    with TomGenericFieldDecorationMixin<T> {
  final TomSelectableSource<T> source;

  TomCupertinoFormEnumSegmented(
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
  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');

  @override
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  @override
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.segmentedStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _CupertinoEnumSegmentedWidget<T>(field: this),
      );
}

class _CupertinoEnumSegmentedWidget<T extends Object>
    extends StatefulWidget {
  final TomCupertinoFormEnumSegmented<T> field;
  const _CupertinoEnumSegmentedWidget({required this.field});

  @override
  State<_CupertinoEnumSegmentedWidget<T>> createState() =>
      _CupertinoEnumSegmentedWidgetState<T>();
}

class _CupertinoEnumSegmentedWidgetState<T extends Object>
    extends State<_CupertinoEnumSegmentedWidget<T>> {
  StreamSubscription<List<SelectableItem<T>>>? _subscription;
  List<SelectableItem<T>> _items = const [];
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormEnumSegmented<T> get field => widget.field;

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
    final style = field.resolveStyle(context);
    if (_items.isEmpty) {
      return field.decorateField(
        context,
        Text('…', style: style.inputStyle),
      );
    }
    final v = field.get();
    final groupValue =
        _items.any((i) => i.value == v) ? v : _items.first.value;
    final segmented = CupertinoSlidingSegmentedControl<T>(
      groupValue: groupValue,
      onValueChanged: field.isEditable
          ? (next) {
              if (next != null) field.setValue(next);
            }
          : (_) {},
      children: {
        for (final it in _items)
          it.value: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(it.label, style: style.inputStyle),
          ),
      },
    );
    return field.decorateField(context, segmented);
  }
}

// ===========================================================================
// TomCupertinoFormObjectPicker<T> — CupertinoPicker sheet over an
// open-set domain-object source
// ===========================================================================

@tomReflector
class TomCupertinoFormObjectPicker<T> extends TomFormObjectField<T>
    with TomGenericFieldDecorationMixin<T> {
  final TomSelectableSource<T> source;
  final String? placeholder;
  final double sheetHeight;

  TomCupertinoFormObjectPicker(
    super.tomId,
    super.initialValue, {
    required this.source,
    this.placeholder,
    this.sheetHeight = 216,
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
        child: _CupertinoObjectPickerWidget<T>(field: this),
      );
}

class _CupertinoObjectPickerWidget<T> extends StatefulWidget {
  final TomCupertinoFormObjectPicker<T> field;
  const _CupertinoObjectPickerWidget({required this.field});

  @override
  State<_CupertinoObjectPickerWidget<T>> createState() =>
      _CupertinoObjectPickerWidgetState<T>();
}

class _CupertinoObjectPickerWidgetState<T>
    extends State<_CupertinoObjectPickerWidget<T>> {
  StreamSubscription<List<SelectableItem<T>>>? _subscription;
  List<SelectableItem<T>> _items = const [];
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormObjectPicker<T> get field => widget.field;

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

  String _displayLabel() {
    if (_items.isEmpty) return field.placeholder ?? 'Choose…';
    final v = field.get();
    final hit = _items.where((i) => i.value == v).map((i) => i.label).firstOrNull;
    return hit ?? (field.placeholder ?? 'Choose…');
  }

  Future<void> _open() async {
    if (_items.isEmpty) return;
    final v = field.get();
    int initialIndex = _items.indexWhere((i) => i.value == v);
    if (initialIndex < 0) initialIndex = 0;
    final picked = await _showCupertinoListPicker<T>(
      context: context,
      items: _items,
      initialIndex: initialIndex,
      sheetHeight: field.sheetHeight,
    );
    if (picked != null && mounted) field.setValue(picked);
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final tile = _cupertinoPickerTile(
      context: context,
      style: style,
      displayLabel: _displayLabel(),
      isEditable: field.isEditable && _items.isNotEmpty,
      onTap: _open,
    );
    return field.decorateField(context, tile);
  }
}
