library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../decoration/tom_field_decoration_mixin.dart';
import '../selection/tom_selectable_source.dart';
import '../style/tom_form_style_scope.dart';
import '../tom_form.dart';
import '../validation/validation_result.dart';

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

/// A concrete text-input field that renders as a [TextField] with
/// [InputDecoration].
///
/// Uses native Material `InputDecoration` for label, hint, and error
/// display (checklist C1). Reads styling from [TomFormStyleScope].
@tomReflector
class TomFormStringInput extends TomFormStringField {
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
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
  });

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
    // Auth: hidden → shrink
    if (!field.isVisible) return const SizedBox.shrink();

    final style = TomFormStyleScope.of(context);

    // Validation error text
    String? errorText;
    final validationState = field.validationState;
    if (validationState is ValidationError) {
      errorText = field.resolveErrorMessage(validationState.errorKey);
    }

    // Pending spinner suffix
    Widget? suffixIcon = field.suffixIcon;
    if (validationState is ValidationPending) {
      suffixIcon = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

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
        labelText: field.labelText,
        hintText: field.hintText,
        helperText: field.descriptionText,
        errorText: errorText,
        prefixIcon: field.prefixIcon,
        suffixIcon: suffixIcon,
        contentPadding: style.fieldContentPadding,
        border: style.fieldBorder,
        focusedBorder: style.focusedBorder,
        errorBorder: style.errorBorder,
        enabledBorder: style.fieldBorder,
        labelStyle: style.labelStyle,
        hintStyle: style.hintStyle,
        errorStyle: style.errorStyle,
        helperStyle: style.descriptionStyle,
      ),
    );

    // Auth: disabled → opacity wrapper
    if (field.effectiveAuthState == TomAuthState.disabled) {
      return Opacity(opacity: style.disabledOpacity, child: textField);
    }

    // Auth: read → background wrapper
    if (field.effectiveAuthState == TomAuthState.read &&
        style.readOnlyBackground != null) {
      return ColoredBox(
        color: style.readOnlyBackground!,
        child: textField,
      );
    }

    return textField;
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
    if (mounted) setState(() => _items = items);
    // Subscribe to stream for dynamic updates
    final stream = field.source.itemsStream;
    if (stream != null) {
      _subscription = stream.listen((items) {
        if (mounted) setState(() => _items = items);
      });
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

    // Validation error text
    String? errorText;
    final validationState = field.validationState;
    if (validationState is ValidationError) {
      errorText = field.resolveErrorMessage(validationState.errorKey);
    }

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
        errorText: errorText,
        contentPadding: style.fieldContentPadding,
        border: style.fieldBorder,
        focusedBorder: style.focusedBorder,
        errorBorder: style.errorBorder,
        enabledBorder: style.fieldBorder,
        hintStyle: style.hintStyle,
        errorStyle: style.errorStyle,
      ),
    );

    return field.decorateField(context, dropdown);
  }
}
