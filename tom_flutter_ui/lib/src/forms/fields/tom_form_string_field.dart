library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../decoration/tom_field_decoration_mixin.dart';
import '../selection/tom_selectable_source.dart';
import '../style/tom_form_style_scope.dart';
import '../tom_form.dart';

// ---------------------------------------------------------------------------
// TomFormStringField — Abstract String Field (§6)
// ---------------------------------------------------------------------------

/// Abstract base for all string-typed form fields.
///
/// Provides string-specific resource resolution (label, hint, description,
/// error messages) and a common constructor surface. Concrete
/// implementations provide the widget ([TomFormStringInput] for text input,
/// [TomFormStringDropdown] for dropdown selection).
abstract class TomFormStringField extends TomField<String> {
  /// Explicit label text (overrides resource lookup).
  final String? labelTextOverride;

  /// Explicit hint text (overrides resource lookup).
  final String? hintTextOverride;

  /// Explicit description text (overrides resource lookup).
  final String? descriptionTextOverride;

  /// Maximum allowed character length (optional).
  final int? maxLength;

  TomFormStringField(
    super.fieldId,
    super.initialValue, {
    this.labelTextOverride,
    this.hintTextOverride,
    this.descriptionTextOverride,
    this.maxLength,
    super.form,
    super.obscureText,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
  });

  // --- Resource resolution (§17) ---

  /// Resolved label: explicit → resource → fieldId.
  String? get labelText =>
      labelTextOverride ??
      TomCtr.textOrNull(basePath, 'label');

  /// Resolved hint: explicit → resource → null.
  String? get hintText =>
      hintTextOverride ?? TomCtr.textOrNull(basePath, 'hint');

  /// Resolved description: explicit → resource → null.
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  /// Resolve an error message for the given error key.
  String resolveErrorMessage(String errorKey) {
    return TomCtr.textOrNull(basePath, 'error.$errorKey') ?? errorKey;
  }
}

// ---------------------------------------------------------------------------
// TomFormStringInput — Concrete Text Input (§7, §8)
// ---------------------------------------------------------------------------

/// A concrete text-input field that renders as a plain [TextField]
/// wrapped with [TomFieldDecorationMixin] anatomy (label, error, description).
///
/// Uses `TomFieldDecorationMixin` for consistent visual anatomy across all
/// field types (checklist C1). The inner [TextField] has no
/// `InputDecoration` label/error/helper — all anatomy comes from the mixin.
@tomReflector
class TomFormStringInput extends TomFormStringField
    with TomFieldDecorationMixin<String> {
  /// Optional prefix icon for the input.
  final Widget? prefixIcon;

  /// Optional suffix icon for the input.
  final Widget? suffixIcon;

  /// The keyboard type for the input.
  final TextInputType? keyboardType;

  /// Maximum number of lines for the input.
  final int? maxLines;

  TomFormStringInput(
    super.fieldId,
    super.initialValue, {
    super.labelTextOverride,
    super.hintTextOverride,
    super.descriptionTextOverride,
    super.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.maxLines,
    super.form,
    super.obscureText,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
  });

  // Override labelText/descriptionText to resolve through the
  // TomFormStringField resource resolution logic rather than
  // TomFieldDecorationMixin's default (null).
  @override
  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');

  @override
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  @override
  Widget get widget => _TomFormStringInputWidget(field: this);
}

class _TomFormStringInputWidget extends StatefulWidget {
  final TomFormStringInput field;

  const _TomFormStringInputWidget({required this.field});

  @override
  State<_TomFormStringInputWidget> createState() =>
      _TomFormStringInputWidgetState();
}

class _TomFormStringInputWidgetState
    extends State<_TomFormStringInputWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final TomFunctionObserver<TomObservable> _observer;
  bool _updatingFromField = false;

  TomFormStringInput get field => widget.field;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: field.get());
    _focusNode = FocusNode();
    // Observe field value changes (e.g., from bind/reset) and sync to controller
    _observer = field >> (observable) {
      if (!_updatingFromField) {
        final newText = (observable as TomObject<String>).get();
        if (_controller.text != newText) {
          _controller.text = newText;
        }
      }
    };
  }

  @override
  void dispose() {
    field.removeObserver(_observer);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _updatingFromField = true;
    field.setValue(value);
    _updatingFromField = false;
  }

  @override
  Widget build(BuildContext context) {
    final style = TomFormStyleScope.of(context);

    // Plain TextField — no InputDecoration label/error/helper.
    // All anatomy (label, error, description) comes from TomFieldDecorationMixin.
    final textField = TextField(
      controller: _controller,
      focusNode: _focusNode,
      obscureText: field.obscureText,
      keyboardType: field.keyboardType,
      maxLength: field.maxLength,
      maxLines: field.obscureText ? 1 : field.maxLines,
      onChanged: field.isEditable ? _onChanged : null,
      enabled: field.isEditable,
      decoration: InputDecoration(
        hintText: field.hintText,
        prefixIcon: field.prefixIcon,
        suffixIcon: field.suffixIcon,
        contentPadding: style.fieldContentPadding,
        border: style.fieldBorder,
        focusedBorder: style.focusedBorder,
        errorBorder: style.errorBorder,
        enabledBorder: style.fieldBorder,
        hintStyle: style.hintStyle,
        // No labelText, errorText, or helperText — handled by mixin
      ),
    );

    // Wrap with mixin anatomy (label row, error row, description row)
    return field.decorateField(context, textField);
  }
}

// ---------------------------------------------------------------------------
// TomFormStringDropdown — Concrete Dropdown Selection (§7, §8)
// ---------------------------------------------------------------------------

/// A concrete dropdown selection field that renders as a
/// [DropdownButtonFormField] wrapped with [TomFieldDecorationMixin] anatomy.
///
/// Uses [TomSelectableSource<String>] for populating options (checklist I1-I3).
@tomReflector
class TomFormStringDropdown extends TomFormStringField
    with TomFieldDecorationMixin<String> {
  /// The source of selectable items.
  final TomSelectableSource<String> source;

  TomFormStringDropdown(
    super.fieldId,
    super.initialValue, {
    required this.source,
    super.labelTextOverride,
    super.hintTextOverride,
    super.descriptionTextOverride,
    super.form,
    super.validators,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
  });

  // Override labelText/descriptionText to resolve through the
  // TomFormStringField resource resolution logic rather than
  // TomFieldDecorationMixin's default (null).
  // Mixin linearization places the mixin between this class and the
  // superclass, so without these overrides the mixin's null-returning
  // getters would shadow the superclass's resource-resolving getters.

  @override
  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');

  @override
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  @override
  Widget get widget => _TomFormStringDropdownWidget(field: this);
}

class _TomFormStringDropdownWidget extends StatefulWidget {
  final TomFormStringDropdown field;

  const _TomFormStringDropdownWidget({required this.field});

  @override
  State<_TomFormStringDropdownWidget> createState() =>
      _TomFormStringDropdownWidgetState();
}

class _TomFormStringDropdownWidgetState
    extends State<_TomFormStringDropdownWidget> {
  List<SelectableItem<String>> _items = [];
  StreamSubscription<List<SelectableItem<String>>>? _subscription;
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormStringDropdown get field => widget.field;

  @override
  void initState() {
    super.initState();
    _loadItems();
    // Observe field value changes for external updates (bind/reset)
    _observer = field >> (_) {
      if (mounted) setState(() {});
    };
  }

  Future<void> _loadItems() async {
    final items = await field.source.getItems();
    if (mounted) {
      setState(() => _items = items);
      _resetIfValueMissing(items);
    }
    // Subscribe to stream for dynamic updates
    final stream = field.source.itemsStream;
    if (stream != null) {
      _subscription = stream.listen((items) {
        if (mounted) {
          setState(() => _items = items);
          _resetIfValueMissing(items);
        }
      });
    }
  }

  /// C13: When the source items change, reset the field value if the current
  /// value is no longer present among the available items.
  void _resetIfValueMissing(List<SelectableItem<String>> items) {
    final current = field.get();
    if (current.isEmpty) return;
    final stillPresent = items.any((item) => item.value == current);
    if (!stillPresent) {
      // Reset to the first available value, or empty if none.
      final firstValue =
          items.where((i) => i.enabled).firstOrNull?.value ?? '';
      field.setValue(firstValue);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    field.removeObserver(_observer);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = TomFormStyleScope.of(context);

    final dropdown = DropdownButtonFormField<String>(
      initialValue: field.get().isEmpty ? null : field.get(),
      items: _items.map((item) {
        return DropdownMenuItem<String>(
          value: item.value,
          enabled: item.enabled,
          child: Text(item.label),
        );
      }).toList(),
      onChanged: field.isEditable
          ? (value) {
              if (value != null) field.setValue(value);
            }
          : null,
      decoration: InputDecoration(
        hintText: field.hintText,
        contentPadding: style.fieldContentPadding,
        border: style.fieldBorder,
        focusedBorder: style.focusedBorder,
        errorBorder: style.errorBorder,
        enabledBorder: style.fieldBorder,
        hintStyle: style.hintStyle,
        // No errorText — handled by decorateField() via mixin
      ),
    );

    return field.decorateField(context, dropdown);
  }
}
