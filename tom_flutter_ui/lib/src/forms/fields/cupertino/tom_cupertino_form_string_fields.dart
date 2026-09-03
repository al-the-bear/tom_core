/// Cupertino String concretes.
///
/// Four concretes that subclass the same `TomFormStringField` abstract
/// used by the Material side:
///   * [TomCupertinoFormStringInput]      → `CupertinoTextField`
///   * [TomCupertinoFormStringSearchInput]→ `CupertinoSearchTextField`
///   * [TomCupertinoFormStringPicker]     → `CupertinoPicker` sheet
///   * [TomCupertinoFormStringSegmented]  → `CupertinoSlidingSegmentedControl`
///
/// All four share the Material decoration anatomy via
/// [TomStringInputDecorationMixin] / [TomGenericFieldDecorationMixin] —
/// label / error / description / action icons render the same way, only
/// the inner control is Cupertino. A form that mixes both families
/// therefore still aligns vertically.
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../../widget_base/tom_construction_helpers.dart';
import '../../decoration/tom_field_anatomy.dart';
import '../../decoration/tom_generic_field_decoration_mixin.dart';
import '../../decoration/tom_string_input_decoration_mixin.dart';
import '../../selection/tom_selectable_source.dart';
import '../../style/tom_cupertino_form_style.dart';
import '../../style/tom_form_style.dart';
import '../../style/tom_form_style_scope.dart';
import '../../tom_form_labels.dart';
import '../tom_field_widget_adapter.dart';
import '../tom_form_string_field.dart';

// ===========================================================================
// TomCupertinoFormStringInput — CupertinoTextField
// ===========================================================================

@tomReflector
class TomCupertinoFormStringInput extends TomFormStringField
    with TomStringInputDecorationMixin<String> {
  /// Optional prefix widget shown inside the field box.
  final Widget? prefix;

  /// Optional suffix widget shown inside the field box.
  final Widget? suffix;

  /// Keyboard type for the input.
  final TextInputType? keyboardType;

  /// Maximum number of lines.
  final int? maxLines;

  TomCupertinoFormStringInput(
    super.tomId,
    super.initialValue, {
    super.labelTextOverride,
    super.hintTextOverride,
    super.descriptionTextOverride,
    super.maxLength,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.maxLines,
    super.form,
    super.obscureText,
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
    child: _CupertinoStringInputWidget(field: this),
  );
}

class _CupertinoStringInputWidget extends StatefulWidget {
  final TomCupertinoFormStringInput field;
  const _CupertinoStringInputWidget({required this.field});

  @override
  State<_CupertinoStringInputWidget> createState() =>
      _CupertinoStringInputWidgetState();
}

class _CupertinoStringInputWidgetState
    extends State<_CupertinoStringInputWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final TomFunctionObserver<TomObservable> _observer;
  bool _updatingFromField = false;

  TomCupertinoFormStringInput get field => widget.field;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: field.get());
    _focusNode = FocusNode();
    _observer =
        field >>
        (observable) {
          if (!_updatingFromField) {
            final next = (observable as TomObject<String>).get();
            if (_controller.text != next) _controller.text = next;
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
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _updatingFromField = true;
    field.setValue(v);
    _updatingFromField = false;
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final hint = field.hintText;

    final input = CupertinoTextField(
      controller: _controller,
      focusNode: _focusNode,
      placeholder: hint == null
          ? null
          : hint + field.requiredIndicatorSuffix(style.requiredIndicatorOnHint),
      placeholderStyle: composeHintStyle(style, Theme.of(context)),
      style: style.inputStyle,
      obscureText: field.obscureText,
      keyboardType: field.keyboardType,
      maxLength: field.maxLength,
      maxLines: field.obscureText ? 1 : (field.maxLines ?? 1),
      onChanged: field.isEditable ? _onChanged : null,
      enabled: field.isEditable,
      padding: style.fieldContentPadding,
      prefix: composeCupertinoLeading(field.prefix, style),
      suffix: composeCupertinoTrailing(field.suffix, style),
      decoration: cupertinoFieldDecoration(
        context: context,
        borderRadius: style.borderRadius,
        focused: _focusNode.hasFocus,
      ),
    );

    return field.decorateField(context, input);
  }
}

// ===========================================================================
// TomCupertinoFormStringSearchInput — CupertinoSearchTextField
// ===========================================================================

@tomReflector
class TomCupertinoFormStringSearchInput extends TomFormStringField
    with TomStringInputDecorationMixin<String> {
  TomCupertinoFormStringSearchInput(
    super.tomId,
    super.initialValue, {
    super.labelTextOverride,
    super.hintTextOverride,
    super.descriptionTextOverride,
    super.maxLength,
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
    child: _CupertinoSearchInputWidget(field: this),
  );
}

class _CupertinoSearchInputWidget extends StatefulWidget {
  final TomCupertinoFormStringSearchInput field;
  const _CupertinoSearchInputWidget({required this.field});

  @override
  State<_CupertinoSearchInputWidget> createState() =>
      _CupertinoSearchInputWidgetState();
}

class _CupertinoSearchInputWidgetState
    extends State<_CupertinoSearchInputWidget> {
  late final TextEditingController _controller;
  late final TomFunctionObserver<TomObservable> _observer;
  bool _updatingFromField = false;

  TomCupertinoFormStringSearchInput get field => widget.field;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: field.get());
    _observer =
        field >>
        (observable) {
          if (!_updatingFromField) {
            final next = (observable as TomObject<String>).get();
            if (_controller.text != next) _controller.text = next;
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

  void _onChanged(String v) {
    _updatingFromField = true;
    field.setValue(v);
    _updatingFromField = false;
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final hint = field.hintText;

    final search = CupertinoSearchTextField(
      controller: _controller,
      placeholder: hint ?? TomFormLabels.search(field.basePath),
      placeholderStyle: composeHintStyle(style, Theme.of(context)),
      style: style.inputStyle,
      onChanged: field.isEditable ? _onChanged : null,
      onSuffixTap: field.isEditable
          ? () {
              _controller.clear();
              _onChanged('');
            }
          : null,
      enabled: field.isEditable,
      padding: style.fieldContentPadding,
    );

    return field.decorateField(context, search);
  }
}

// ===========================================================================
// TomCupertinoFormStringPicker — CupertinoPicker sheet
// ===========================================================================

@tomReflector
class TomCupertinoFormStringPicker extends TomFormStringField
    with TomGenericFieldDecorationMixin<String> {
  /// Source of the selectable items.
  final TomSelectableSource<String> source;

  /// Height of the picker sheet.
  final double sheetHeight;

  TomCupertinoFormStringPicker(
    super.tomId,
    super.initialValue, {
    required this.source,
    this.sheetHeight = 216,
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
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.dropdownStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
    field: this,
    child: _CupertinoStringPickerWidget(field: this),
  );
}

class _CupertinoStringPickerWidget extends StatefulWidget {
  final TomCupertinoFormStringPicker field;
  const _CupertinoStringPickerWidget({required this.field});

  @override
  State<_CupertinoStringPickerWidget> createState() =>
      _CupertinoStringPickerWidgetState();
}

class _CupertinoStringPickerWidgetState
    extends State<_CupertinoStringPickerWidget> {
  StreamSubscription<List<SelectableItem<String>>>? _subscription;
  List<SelectableItem<String>> _items = const [];
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormStringPicker get field => widget.field;

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

  void _showPicker() {
    final initial = field.get();
    int initialIndex = _items.indexWhere((i) => i.value == initial);
    if (initialIndex < 0) initialIndex = 0;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        int tempIndex = initialIndex;
        return Container(
          height: field.sheetHeight + 56,
          color: CupertinoColors.systemBackground.resolveFrom(ctx),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(TomFormLabels.cancel(field.basePath)),
                    ),
                    CupertinoButton(
                      onPressed: () {
                        if (tempIndex >= 0 && tempIndex < _items.length) {
                          field.setValue(_items[tempIndex].value);
                        }
                        Navigator.of(ctx).pop();
                      },
                      child: Text(TomFormLabels.done(field.basePath)),
                    ),
                  ],
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(
                      initialItem: initialIndex,
                    ),
                    onSelectedItemChanged: (i) => tempIndex = i,
                    children: [
                      for (final item in _items)
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

  String _displayLabel() {
    final v = field.get();
    if (v.isEmpty) {
      return field.hintText ?? TomFormLabels.choose(field.basePath);
    }
    final found = _items
        .where((i) => i.value == v)
        .map((i) => i.label)
        .firstOrNull;
    return found ?? v;
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final label = _displayLabel();

    final tile = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: field.isEditable && _items.isNotEmpty ? _showPicker : null,
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

    return field.decorateField(context, tile);
  }
}

// ===========================================================================
// TomCupertinoFormStringSegmented — CupertinoSlidingSegmentedControl
// ===========================================================================

@tomReflector
class TomCupertinoFormStringSegmented extends TomFormStringField
    with TomGenericFieldDecorationMixin<String> {
  final TomSelectableSource<String> source;

  TomCupertinoFormStringSegmented(
    super.tomId,
    super.initialValue, {
    required this.source,
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
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.segmentedStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
    field: this,
    child: _CupertinoStringSegmentedWidget(field: this),
  );
}

class _CupertinoStringSegmentedWidget extends StatefulWidget {
  final TomCupertinoFormStringSegmented field;
  const _CupertinoStringSegmentedWidget({required this.field});

  @override
  State<_CupertinoStringSegmentedWidget> createState() =>
      _CupertinoStringSegmentedWidgetState();
}

class _CupertinoStringSegmentedWidgetState
    extends State<_CupertinoStringSegmentedWidget> {
  StreamSubscription<List<SelectableItem<String>>>? _subscription;
  List<SelectableItem<String>> _items = const [];
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormStringSegmented get field => widget.field;

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
      return field.decorateField(context, const SizedBox(height: 32));
    }

    final children = <String, Widget>{
      for (final item in _items)
        item.value: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(item.label, style: style.inputStyle),
        ),
    };

    final current = field.get();
    final groupValue = children.containsKey(current) ? current : null;

    final segmented = SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<String>(
        groupValue: groupValue,
        children: children,
        onValueChanged: field.isEditable
            ? (v) {
                if (v != null) field.setValue(v);
              }
            : (_) {},
      ),
    );

    return field.decorateField(context, segmented);
  }
}
