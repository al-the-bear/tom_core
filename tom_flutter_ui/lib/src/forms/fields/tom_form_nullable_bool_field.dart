/// Tristate boolean fields — a bound toggle whose third state is "unanswered".
///
/// `TomFormBoolField` binds a `bool` and therefore cannot represent the
/// third, indeterminate state at all: it is a value-type limitation, not a
/// missing constructor argument. This family is the nullable sibling —
/// `TomField<bool?>`, where `null` *is* the third state — following the same
/// pattern the nullable inputs establish in `tom_form_nullable_inputs.dart`.
///
/// The split is additive on purpose. Every existing `TomField<bool>` consumer
/// keeps its non-nullable value; a form that wants "yes / no / not answered"
/// declares the nullable field instead. That third state is what lets a form
/// generated from a declarative field description honour a toggle the
/// description marks as tristate, without the generator having to model the
/// unanswered case itself.
///
/// Concretes:
///   * [TomFormNullableBoolCheckbox] — Material [Checkbox] with `tristate`.
///   * The Cupertino sibling lives in
///     `cupertino/tom_cupertino_form_bool_fields.dart`.
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
// TomFormNullableBoolField — abstract tristate boolean
// ---------------------------------------------------------------------------

/// Abstract base for boolean fields that can hold the indeterminate state.
///
/// Shared by the Material and Cupertino concretes so a single bound field
/// can be rendered by either family, exactly as `TomFormBoolField` is.
abstract class TomFormNullableBoolField extends TomField<bool?> {
  /// Explicit label text (overrides resource lookup).
  final String? labelTextOverride;

  /// Explicit description text (overrides resource lookup).
  final String? descriptionTextOverride;

  /// Explicit [tristate] value (overrides resource lookup).
  final bool? tristateOverride;

  TomFormNullableBoolField(
    super.tomId,
    super.initialValue, {
    this.labelTextOverride,
    this.descriptionTextOverride,
    this.tristateOverride,
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

  /// Whether the user can reach the indeterminate state by interacting with
  /// the control. Resolution order mirrors every other field attribute:
  /// explicit [tristateOverride], then the `<basePath>.tristate` resource,
  /// then `true` — a nullable bool field exists *because* of the third
  /// state, so offering it is the sensible default.
  ///
  /// Setting it to `false` keeps the nullable value type (the field may
  /// still *start* unset) while making the control two-state: once the user
  /// answers, they cannot un-answer.
  bool get tristate =>
      tristateOverride ?? TomCtr.boolVal(basePath, 'tristate') ?? true;
}

// ---------------------------------------------------------------------------
// TomFormNullableBoolCheckbox — Material Checkbox with tristate
// ---------------------------------------------------------------------------

/// Renders the tristate boolean as a Material [Checkbox] inside the standard
/// field anatomy. Uses the same `checkboxStyle` slot as
/// `TomFormBoolCheckbox`, so the two are visually interchangeable.
@tomReflector
class TomFormNullableBoolCheckbox extends TomFormNullableBoolField
    with TomGenericFieldDecorationMixin<bool?> {
  TomFormNullableBoolCheckbox(
    super.tomId,
    super.initialValue, {
    super.labelTextOverride,
    super.descriptionTextOverride,
    super.tristateOverride,
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
    child: _TomFormNullableBoolCheckboxWidget(field: this),
  );
}

class _TomFormNullableBoolCheckboxWidget extends StatefulWidget {
  final TomFormNullableBoolCheckbox field;
  const _TomFormNullableBoolCheckboxWidget({required this.field});

  @override
  State<_TomFormNullableBoolCheckboxWidget> createState() =>
      _TomFormNullableBoolCheckboxWidgetState();
}

class _TomFormNullableBoolCheckboxWidgetState
    extends State<_TomFormNullableBoolCheckboxWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormNullableBoolCheckbox get field => widget.field;

  @override
  void initState() {
    super.initState();
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
    final tristate = field.tristate;

    final checkbox = Checkbox(
      // Checkbox asserts `tristate || value != null`, so a two-state
      // control renders an unset field as unchecked.
      value: tristate ? field.get() : (field.get() ?? false),
      tristate: tristate,
      // Material cycles false → true → null → false itself and hands us the
      // next value, so the third state needs no arithmetic here — unlike
      // TomFormBoolCheckbox, which has to drop the null.
      onChanged: field.isEditable ? field.setValue : null,
      fillColor: override?.fillColor,
      checkColor: override?.checkColor?.resolve(const {WidgetState.selected}),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return field.decorateField(context, checkbox);
  }
}
