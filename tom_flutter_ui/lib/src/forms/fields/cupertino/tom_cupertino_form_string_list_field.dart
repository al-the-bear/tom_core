/// Phase 5a — Cupertino String-list concrete.
///
/// Mirror of the Material multi-select string fields
/// ([TomFormStringFilterChips], [TomFormStringMultiCheckbox]) using a
/// Cupertino-flavoured affordance:
///
///   * [TomCupertinoFormStringListCheckedPicker] — closed-state tile
///     shows the comma-joined selection (or hint); tap opens a modal
///     popup listing every item as a tappable row with a check-mark on
///     the selected ones; tap-to-toggle commits immediately.
///
/// Subclasses the same `TomFormStringListField` abstract used by the
/// Material concretes so a shared bound state object can be rendered
/// by either family — this is the contract the Phase 5c
/// `FormFieldFamily` factory leans on.
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
import '../tom_form_string_list_field.dart';

@tomReflector
class TomCupertinoFormStringListCheckedPicker extends TomFormStringListField
    with TomGenericFieldDecorationMixin<List<String>> {
  /// Source of the selectable items.
  final TomSelectableSource<String> source;

  /// Height of the picker sheet body (action area sits above this).
  final double sheetHeight;

  /// Optional placeholder text shown in the closed tile when nothing
  /// is selected. Falls back to `<basePath>.hint` resource, then
  /// "Choose…".
  final String? hintTextOverride;

  TomCupertinoFormStringListCheckedPicker(
    super.tomId,
    super.initialValue, {
    required this.source,
    this.sheetHeight = 320,
    this.hintTextOverride,
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

  String? get hintText =>
      hintTextOverride ?? TomCtr.textOrNull(basePath, 'hint');

  @override
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    // Pick the dropdown slot — semantically the picker is a "select one
    // of many" affordance even though it accepts multi-select.
    return form.resolveFieldStyle(form.dropdownStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _CupertinoStringListCheckedPickerWidget(field: this),
      );
}

class _CupertinoStringListCheckedPickerWidget extends StatefulWidget {
  final TomCupertinoFormStringListCheckedPicker field;
  const _CupertinoStringListCheckedPickerWidget({required this.field});

  @override
  State<_CupertinoStringListCheckedPickerWidget> createState() =>
      _CupertinoStringListCheckedPickerWidgetState();
}

class _CupertinoStringListCheckedPickerWidgetState
    extends State<_CupertinoStringListCheckedPickerWidget> {
  StreamSubscription<List<SelectableItem<String>>>? _subscription;
  List<SelectableItem<String>> _items = const [];
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormStringListCheckedPicker get field => widget.field;

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
      _pruneVanishedSelections(initial);
    }
    final stream = field.source.itemsStream;
    if (stream != null) {
      _subscription = stream.listen((next) {
        if (mounted) {
          setState(() => _items = next);
          _pruneVanishedSelections(next);
        }
      });
    }
  }

  void _pruneVanishedSelections(List<SelectableItem<String>> current) {
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

  String _displayLabel() {
    final selected = field.get();
    if (selected.isEmpty) return field.hintText ?? 'Choose…';
    final byValue = {for (final item in _items) item.value: item.label};
    return selected.map((v) => byValue[v] ?? v).join(', ');
  }

  void _showSheet() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return _CheckedPickerSheet(
          items: _items,
          height: field.sheetHeight,
          initialSelection: field.get().toSet(),
          onItemToggled: (value, include) =>
              field.toggleItem(value, include),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final selected = field.get();
    final hasSelection = selected.isNotEmpty;
    final label = _displayLabel();

    final tile = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: field.isEditable && _items.isNotEmpty ? _showSheet : null,
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
                label,
                style: hasSelection
                    ? style.inputStyle
                    : (style.inputStyle ?? const TextStyle()).copyWith(
                        color: CupertinoColors.placeholderText
                            .resolveFrom(context),
                      ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
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

    return field.decorateField(context, tile);
  }
}

/// Stateful sheet body — rebuilds as items toggle so check-marks
/// reflect the live selection without dismissing the sheet.
class _CheckedPickerSheet extends StatefulWidget {
  final List<SelectableItem<String>> items;
  final double height;
  final Set<String> initialSelection;
  final void Function(String value, bool include) onItemToggled;

  const _CheckedPickerSheet({
    required this.items,
    required this.height,
    required this.initialSelection,
    required this.onItemToggled,
  });

  @override
  State<_CheckedPickerSheet> createState() => _CheckedPickerSheetState();
}

class _CheckedPickerSheetState extends State<_CheckedPickerSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelection};
  }

  void _toggle(String value) {
    final wasSelected = _selected.contains(value);
    setState(() {
      if (wasSelected) {
        _selected.remove(value);
      } else {
        _selected.add(value);
      }
    });
    widget.onItemToggled(value, !wasSelected);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height + 56,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
            Expanded(
              child: ListView.separated(
                itemCount: widget.items.length,
                separatorBuilder: (_, _) => Container(
                  height: 0.5,
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
                itemBuilder: (ctx, i) {
                  final item = widget.items[i];
                  final isSelected = _selected.contains(item.value);
                  return CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: item.enabled ? () => _toggle(item.value) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                color: item.enabled
                                    ? CupertinoColors.label.resolveFrom(ctx)
                                    : CupertinoColors.inactiveGray
                                        .resolveFrom(ctx),
                              ),
                              textAlign: TextAlign.start,
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              CupertinoIcons.check_mark,
                              color:
                                  CupertinoTheme.of(ctx).primaryColor,
                              size: 20,
                            ),
                        ],
                      ),
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
