/// Boolean form fields — the abstract [TomFormBoolField] and the three
/// renderings that ship with it.
///
/// The abstract type is catalogued in `tom_ui_widgets_forms.md` §6; the
/// concrete renderings are specified in `tom_ui_widgets_forms.md` §7, and
/// the way each binds to its Flutter widget in `tom_ui_widgets_forms.md` §8.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../decoration/tom_generic_field_decoration_mixin.dart';
import '../style/tom_form_style.dart';
import '../style/tom_form_style_scope.dart';
import '../tom_form.dart';
import 'tom_field_widget_adapter.dart';

// ---------------------------------------------------------------------------
// TomFormBoolField — Abstract Bool Field
// ---------------------------------------------------------------------------

/// Abstract base for boolean form fields.
///
/// Binds to a [TomBool] via [TomField]'s observable plumbing. Concrete
/// implementations pick the rendering ([TomFormBoolCheckbox],
/// [TomFormBoolSwitch], [TomFormBoolToggle]). All three share the same
/// label / error / description anatomy via
/// [TomGenericFieldDecorationMixin].
abstract class TomFormBoolField extends TomField<bool> {
  /// Explicit label text (overrides resource lookup).
  final String? labelTextOverride;

  /// Explicit description text (overrides resource lookup).
  final String? descriptionTextOverride;

  TomFormBoolField(
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
}

// ---------------------------------------------------------------------------
// TomFormBoolCheckbox — Concrete Checkbox
// ---------------------------------------------------------------------------

/// Renders the boolean as a Material [Checkbox] with the standard
/// field anatomy wrapped around it.
@tomReflector
class TomFormBoolCheckbox extends TomFormBoolField
    with TomGenericFieldDecorationMixin<bool> {
  TomFormBoolCheckbox(
    super.tomId,
    super.initialValue, {
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
    return form.resolveFieldStyle(form.checkboxStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _TomFormBoolCheckboxWidget(field: this),
      );
}

class _TomFormBoolCheckboxWidget extends StatefulWidget {
  final TomFormBoolCheckbox field;
  const _TomFormBoolCheckboxWidget({required this.field});

  @override
  State<_TomFormBoolCheckboxWidget> createState() =>
      _TomFormBoolCheckboxWidgetState();
}

class _TomFormBoolCheckboxWidgetState
    extends State<_TomFormBoolCheckboxWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormBoolCheckbox get field => widget.field;

  @override
  void initState() {
    super.initState();
    _observer = field >> (_) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final full = field.resolveFullStyle(context);
    final override = full.checkboxStyle;

    final checkbox = Checkbox(
      value: field.get(),
      onChanged: field.isEditable
          ? (v) {
              if (v != null) field.setValue(v);
            }
          : null,
      fillColor: override?.fillColor,
      // Checkbox's checkColor is a plain Color?, while our style uses
      // WidgetStateProperty<Color>? to match the rest of the palette —
      // pull the selected-state colour out for Checkbox-specific use.
      checkColor: override?.checkColor?.resolve(
        const {WidgetState.selected},
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return field.decorateField(context, checkbox);
  }
}

// ---------------------------------------------------------------------------
// TomFormBoolSwitch — Concrete Switch
// ---------------------------------------------------------------------------

/// Renders the boolean as a Material [Switch].
@tomReflector
class TomFormBoolSwitch extends TomFormBoolField
    with TomGenericFieldDecorationMixin<bool> {
  TomFormBoolSwitch(
    super.tomId,
    super.initialValue, {
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
    return form.resolveFieldStyle(form.switchStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _TomFormBoolSwitchWidget(field: this),
      );
}

class _TomFormBoolSwitchWidget extends StatefulWidget {
  final TomFormBoolSwitch field;
  const _TomFormBoolSwitchWidget({required this.field});

  @override
  State<_TomFormBoolSwitchWidget> createState() =>
      _TomFormBoolSwitchWidgetState();
}

class _TomFormBoolSwitchWidgetState extends State<_TomFormBoolSwitchWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormBoolSwitch get field => widget.field;

  @override
  void initState() {
    super.initState();
    _observer = field >> (_) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final full = field.resolveFullStyle(context);
    final override = full.switchStyle;

    final switchWidget = Switch(
      value: field.get(),
      onChanged: field.isEditable ? field.setValue : null,
      thumbColor: override?.thumbColor,
      trackColor: override?.trackColor,
    );

    return field.decorateField(context, switchWidget);
  }
}

// ---------------------------------------------------------------------------
// TomFormBoolToggle — Concrete Toggle Button
// ---------------------------------------------------------------------------

/// Renders the boolean as a two-segment [SegmentedButton] (Off/On).
/// Useful when the label text needs to be visible on the control
/// itself — e.g. settings screens that read "Enabled / Disabled"
/// inside the button.
@tomReflector
class TomFormBoolToggle extends TomFormBoolField
    with TomGenericFieldDecorationMixin<bool> {
  /// Label for the `true` segment. Resolved from `<basePath>.onLabel`
  /// resource when not set, defaults to "On".
  final String? onLabelOverride;

  /// Label for the `false` segment. Resolved from `<basePath>.offLabel`
  /// resource when not set, defaults to "Off".
  final String? offLabelOverride;

  TomFormBoolToggle(
    super.tomId,
    super.initialValue, {
    this.onLabelOverride,
    this.offLabelOverride,
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

  String get onLabel =>
      onLabelOverride ?? TomCtr.textOrNull(basePath, 'onLabel') ?? 'On';

  String get offLabel =>
      offLabelOverride ?? TomCtr.textOrNull(basePath, 'offLabel') ?? 'Off';

  @override
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.segmentedStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _TomFormBoolToggleWidget(field: this),
      );
}

class _TomFormBoolToggleWidget extends StatefulWidget {
  final TomFormBoolToggle field;
  const _TomFormBoolToggleWidget({required this.field});

  @override
  State<_TomFormBoolToggleWidget> createState() =>
      _TomFormBoolToggleWidgetState();
}

class _TomFormBoolToggleWidgetState extends State<_TomFormBoolToggleWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormBoolToggle get field => widget.field;

  @override
  void initState() {
    super.initState();
    _observer = field >> (_) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final full = field.resolveFullStyle(context);
    final override = full.segmentedStyle;

    final segmented = SegmentedButton<bool>(
      segments: [
        ButtonSegment<bool>(
          value: false,
          label: Text(field.offLabel, style: style.inputStyle),
        ),
        ButtonSegment<bool>(
          value: true,
          label: Text(field.onLabel, style: style.inputStyle),
        ),
      ],
      selected: {field.get()},
      showSelectedIcon: false,
      onSelectionChanged: field.isEditable
          ? (selection) {
              if (selection.isNotEmpty) field.setValue(selection.first);
            }
          : null,
      style: override?.selectedColor != null
          ? ButtonStyle(backgroundColor: override!.selectedColor)
          : null,
    );

    return field.decorateField(context, segmented);
  }
}
