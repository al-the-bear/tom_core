library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../decoration/tom_dropdown_decoration_mixin.dart';
import '../decoration/tom_field_anatomy.dart';
import '../decoration/tom_string_input_decoration_mixin.dart';
import '../selection/tom_selectable_source.dart';
import '../style/form_style_enums.dart';
import '../tom_form.dart';
import 'tom_field_widget_adapter.dart';

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
    super.tomId,
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
    super.actionIcon,
    super.actionIconTooltip,
    super.onActionIconPressed,
  });

  // --- Resource resolution (§17) ---

  /// Resolved label: explicit → resource → tomId.
  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');

  /// Overrides [TomField.resolvedLabel] to surface the explicit
  /// [labelTextOverride] at the highest priority, matching the resolution
  /// order already used by [labelText].
  @override
  String get resolvedLabel => labelText ?? tomId;

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
/// wrapped with [TomStringInputDecorationMixin] anatomy (label, error,
/// description).
@tomReflector
class TomFormStringInput extends TomFormStringField
    with TomStringInputDecorationMixin<String> {
  /// Optional prefix icon for the input.
  final Widget? prefixIcon;

  /// Optional suffix icon for the input.
  final Widget? suffixIcon;

  /// The keyboard type for the input.
  final TextInputType? keyboardType;

  /// Maximum number of lines for the input.
  final int? maxLines;

  TomFormStringInput(
    super.tomId,
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
    super.actionIcon,
    super.actionIconTooltip,
    super.onActionIconPressed,
  });

  // The mixin declares null-returning defaults for labelText/descriptionText.
  // Re-expose the resource-resolving versions from TomFormStringField.
  @override
  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');

  @override
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _TomFormStringInputWidget(field: this),
      );
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
    _observer = field >> (observable) {
      if (!_updatingFromField) {
        final newText = (observable as TomObject<String>).get();
        if (_controller.text != newText) {
          _controller.text = newText;
        }
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

  void _onChanged(String value) {
    _updatingFromField = true;
    field.setValue(value);
    _updatingFromField = false;
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);

    String? effectiveHint = field.hintText;
    final TextStyle? effectiveHintStyle =
        composeHintStyle(style, Theme.of(context));
    if (effectiveHint != null && effectiveHint.isNotEmpty) {
      effectiveHint +=
          field.requiredIndicatorSuffix(style.requiredIndicatorOnHint);
    }

    // Floating label lives inside InputDecoration; the anatomy column does
    // not render a label row for this placement.
    String? floatingLabel;
    if (style.labelPlacement == LabelPlacement.floating) {
      final resolved = field.labelText;
      if (resolved != null && resolved.isNotEmpty) {
        floatingLabel =
            resolved + field.requiredIndicatorSuffix(style.requiredIndicator);
      }
    }

    // Reshape borders to honour style.borderRadius / borderWidth /
    // focusedBorderWidth — presets carry preconstructed borders whose
    // built-in radius + stroke width wouldn't otherwise respond to these
    // style knobs.
    final fieldBorder = applyBorderWidth(
      applyBorderRadius(style.fieldBorder, style.borderRadius),
      style.borderWidth,
    );
    final focusedBorder = applyBorderWidth(
      applyBorderRadius(style.focusedBorder, style.borderRadius),
      style.focusedBorderWidth ?? style.borderWidth,
    );
    final errorBorder = applyBorderWidth(
      applyBorderRadius(style.errorBorder, style.borderRadius),
      style.borderWidth,
    );

    // floatingLabelStyle is derived from labelStyle so color/family are
    // preserved (the whole reason labelStyle is passed through explicitly
    // here — `style.labelStyle` carries the cs.primary ink from withTheme),
    // but fontSize is scaled to Material's canonical floating-label ratio
    // (0.75× rest size). Without the scale, a large rest labelStyle (e.g.
    // 18 px serif from a themed bodyMedium) stays 18 px when floating,
    // overflows the top of the decorator bounds, and is clipped by the
    // parent — the floating label then visually sits as a half-height
    // strip bisected by the outlined border.
    const floatScale = 0.75;
    final labelFontSize = style.labelStyle?.fontSize;
    final floatingLabelStyle = style.labelStyle?.copyWith(
      fontSize: labelFontSize != null ? labelFontSize * floatScale : null,
    );

    final baseDecoration = InputDecoration(
      labelText: floatingLabel,
      labelStyle: style.labelStyle,
      floatingLabelStyle: floatingLabelStyle,
      hintText: effectiveHint,
      prefixIcon: field.prefixIcon,
      suffixIcon: field.suffixIcon,
      contentPadding: style.fieldContentPadding,
      border: fieldBorder,
      focusedBorder: focusedBorder,
      errorBorder: errorBorder,
      enabledBorder: fieldBorder,
      hintStyle: effectiveHintStyle,
      // No errorText or helperText — handled by the anatomy column.
    );

    final textField = TextField(
      controller: _controller,
      focusNode: _focusNode,
      style: style.inputStyle,
      obscureText: field.obscureText,
      keyboardType: field.keyboardType,
      maxLength: field.maxLength,
      maxLines: field.obscureText ? 1 : (field.maxLines ?? 1),
      onChanged: field.isEditable ? _onChanged : null,
      enabled: field.isEditable,
      decoration: field.applyErrorVisualsTo(context, baseDecoration),
    );

    return field.decorateField(context, textField);
  }
}

// ---------------------------------------------------------------------------
// TomFormStringDropdown — Concrete Dropdown Selection (§7, §8)
// ---------------------------------------------------------------------------

/// A concrete dropdown selection field that renders as a
/// [DropdownButtonFormField] wrapped with [TomDropdownDecorationMixin]
/// anatomy.
///
/// Uses [TomSelectableSource<String>] for populating options (checklist I1-I3).
@tomReflector
class TomFormStringDropdown extends TomFormStringField
    with TomDropdownDecorationMixin<String> {
  /// The source of selectable items.
  final TomSelectableSource<String> source;

  TomFormStringDropdown(
    super.tomId,
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

  /// Field-level cache of the async-loaded items. Populated on the first
  /// successful `_loadItems()` and used to synchronously seed a freshly
  /// mounted state — so remounts caused by anatomy-structure changes
  /// (e.g. `labelPlacement` flipping between breakpoints) don't flash the
  /// hint text while `source.getItems()` re-resolves.
  List<SelectableItem<String>>? _cachedItems;

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _TomFormStringDropdownWidget(field: this),
      );
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
    // Seed from the field-level cache synchronously so a remount (caused
    // by anatomy-structure changes between breakpoints) doesn't flash the
    // hint text for one frame while the async load re-runs.
    _items = field._cachedItems ?? const [];
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
    final items = await field.source.getItems();
    field._cachedItems = items;
    if (mounted) {
      setState(() => _items = items);
      _resetIfValueMissing(items);
    }
    final stream = field.source.itemsStream;
    if (stream != null) {
      _subscription = stream.listen((items) {
        field._cachedItems = items;
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
      final firstValue =
          items.where((i) => i.enabled).firstOrNull?.value ?? '';
      field.setValue(firstValue);
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

    String? effectiveHint = field.hintText;
    if (effectiveHint != null && effectiveHint.isNotEmpty) {
      effectiveHint +=
          field.requiredIndicatorSuffix(style.requiredIndicatorOnHint);
    }

    String? floatingLabel;
    if (style.labelPlacement == LabelPlacement.floating) {
      final resolved = field.labelText;
      if (resolved != null && resolved.isNotEmpty) {
        floatingLabel =
            resolved + field.requiredIndicatorSuffix(style.requiredIndicator);
      }
    }

    final fieldBorder = applyBorderWidth(
      applyBorderRadius(style.fieldBorder, style.borderRadius),
      style.borderWidth,
    );
    final focusedBorder = applyBorderWidth(
      applyBorderRadius(style.focusedBorder, style.borderRadius),
      style.focusedBorderWidth ?? style.borderWidth,
    );
    final errorBorder = applyBorderWidth(
      applyBorderRadius(style.errorBorder, style.borderRadius),
      style.borderWidth,
    );

    // Same floatingLabelStyle scaling policy as TomFormStringInput — see the
    // comment on its InputDecoration for the full reasoning.
    const floatScale = 0.75;
    final labelFontSize = style.labelStyle?.fontSize;
    final floatingLabelStyle = style.labelStyle?.copyWith(
      fontSize: labelFontSize != null ? labelFontSize * floatScale : null,
    );

    final baseDecoration = InputDecoration(
      labelText: floatingLabel,
      labelStyle: style.labelStyle,
      floatingLabelStyle: floatingLabelStyle,
      hintText: effectiveHint,
      contentPadding: style.fieldContentPadding,
      border: fieldBorder,
      focusedBorder: focusedBorder,
      errorBorder: errorBorder,
      enabledBorder: fieldBorder,
      hintStyle: composeHintStyle(style, Theme.of(context)),
    );

    final dropdown = DropdownButtonFormField<String>(
      initialValue: field.get().isEmpty ? null : field.get(),
      style: style.inputStyle,
      items: _items.map((item) {
        return DropdownMenuItem<String>(
          value: item.value,
          enabled: item.enabled,
          child: Text(item.label, style: style.inputStyle),
        );
      }).toList(),
      onChanged: field.isEditable
          ? (value) {
              if (value != null) field.setValue(value);
            }
          : null,
      decoration: field.applyErrorVisualsTo(context, baseDecoration),
    );

    return field.decorateField(context, dropdown);
  }
}
