/// Cupertino Bool concretes.
///
/// Mirror of the Material bool concretes ([TomFormBoolSwitch],
/// [TomFormBoolToggle]) backed by Cupertino controls. They subclass
/// the same `TomFormBoolField` abstract used by the Material concretes
/// so a single bound state object can be rendered by either family —
/// the `FormFieldFamily` factory leans on this.
///
///   * [TomCupertinoFormBoolSwitch] → `CupertinoSwitch`
///   * [TomCupertinoFormBoolToggle] → `CupertinoSegmentedControl<bool>`
///   * [TomCupertinoFormNullableBoolToggle] → three-segment tristate control
///
/// All three share the Material-side anatomy via
/// [TomGenericFieldDecorationMixin] — label / error / description /
/// action-icon render identically.
library;

import 'package:flutter/cupertino.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../../widget_base/tom_construction_helpers.dart';
import '../../decoration/tom_generic_field_decoration_mixin.dart';
import '../../style/tom_form_style.dart';
import '../../style/tom_form_style_scope.dart';
import '../tom_field_widget_adapter.dart';
import '../tom_form_bool_field.dart';
import '../tom_form_nullable_bool_field.dart';

// ===========================================================================
// TomCupertinoFormBoolSwitch — CupertinoSwitch
// ===========================================================================

/// Renders the boolean as a [CupertinoSwitch] inside the standard
/// field anatomy. Picks the `switchStyle` slot from the ambient
/// [TomFormStyle] so per-widget overrides keep working alongside the
/// Material switch.
@tomReflector
class TomCupertinoFormBoolSwitch extends TomFormBoolField
    with TomGenericFieldDecorationMixin<bool> {
  TomCupertinoFormBoolSwitch(
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
        child: _CupertinoBoolSwitchWidget(field: this),
      );
}

class _CupertinoBoolSwitchWidget extends StatefulWidget {
  final TomCupertinoFormBoolSwitch field;
  const _CupertinoBoolSwitchWidget({required this.field});

  @override
  State<_CupertinoBoolSwitchWidget> createState() =>
      _CupertinoBoolSwitchWidgetState();
}

class _CupertinoBoolSwitchWidgetState
    extends State<_CupertinoBoolSwitchWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormBoolSwitch get field => widget.field;

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
    final cupertinoSwitch = Align(
      alignment: AlignmentDirectional.centerStart,
      child: CupertinoSwitch(
        value: field.get(),
        onChanged: field.isEditable ? field.setValue : null,
      ),
    );
    return field.decorateField(context, cupertinoSwitch);
  }
}

// ===========================================================================
// TomCupertinoFormBoolToggle — CupertinoSegmentedControl<bool>
// ===========================================================================

/// Renders the boolean as a two-segment [CupertinoSegmentedControl]
/// (Off / On). Mirror of the Material [TomFormBoolToggle] — same label
/// resource lookup (`<basePath>.onLabel` / `.offLabel`), same fallback
/// strings, same `segmentedStyle` slot.
@tomReflector
class TomCupertinoFormBoolToggle extends TomFormBoolField
    with TomGenericFieldDecorationMixin<bool> {
  /// Label for the `true` segment. Resolved from `<basePath>.onLabel`
  /// resource when not set, defaults to "On".
  final String? onLabelOverride;

  /// Label for the `false` segment. Resolved from `<basePath>.offLabel`
  /// resource when not set, defaults to "Off".
  final String? offLabelOverride;

  TomCupertinoFormBoolToggle(
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
        child: _CupertinoBoolToggleWidget(field: this),
      );
}

class _CupertinoBoolToggleWidget extends StatefulWidget {
  final TomCupertinoFormBoolToggle field;
  const _CupertinoBoolToggleWidget({required this.field});

  @override
  State<_CupertinoBoolToggleWidget> createState() =>
      _CupertinoBoolToggleWidgetState();
}

class _CupertinoBoolToggleWidgetState
    extends State<_CupertinoBoolToggleWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormBoolToggle get field => widget.field;

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
    final segmented = SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<bool>(
        groupValue: field.get(),
        children: <bool, Widget>{
          false: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(field.offLabel, style: style.inputStyle),
          ),
          true: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(field.onLabel, style: style.inputStyle),
          ),
        },
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

// ===========================================================================
// TomCupertinoFormNullableBoolToggle — tristate segmented control
// ===========================================================================

/// The Cupertino face of the tristate boolean field.
///
/// Cupertino has no indeterminate checkbox, so the third state gets its own
/// segment: Off / — / On. When `tristate` is `false` the middle segment is
/// dropped and the control behaves like [TomCupertinoFormBoolToggle] over a
/// nullable value.
@tomReflector
class TomCupertinoFormNullableBoolToggle extends TomFormNullableBoolField
    with TomGenericFieldDecorationMixin<bool?> {
  /// Label for the `true` segment. Resolved from `<basePath>.onLabel`
  /// resource when not set, defaults to "On".
  final String? onLabelOverride;

  /// Label for the `false` segment. Resolved from `<basePath>.offLabel`
  /// resource when not set, defaults to "Off".
  final String? offLabelOverride;

  /// Label for the indeterminate segment. Resolved from
  /// `<basePath>.nullLabel` when not set, defaults to an em dash.
  final String? nullLabelOverride;

  TomCupertinoFormNullableBoolToggle(
    super.tomId,
    super.initialValue, {
    this.onLabelOverride,
    this.offLabelOverride,
    this.nullLabelOverride,
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

  String get onLabel =>
      onLabelOverride ?? TomCtr.textOrNull(basePath, 'onLabel') ?? 'On';

  String get offLabel =>
      offLabelOverride ?? TomCtr.textOrNull(basePath, 'offLabel') ?? 'Off';

  String get nullLabel =>
      nullLabelOverride ?? TomCtr.textOrNull(basePath, 'nullLabel') ?? '—';

  @override
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.segmentedStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _CupertinoNullableBoolToggleWidget(field: this),
      );
}

/// Segment keys — `CupertinoSlidingSegmentedControl` needs a non-null key
/// type, so the indeterminate state gets a name rather than a `null` key.
enum _TriSegment { off, unset, on }

class _CupertinoNullableBoolToggleWidget extends StatefulWidget {
  final TomCupertinoFormNullableBoolToggle field;
  const _CupertinoNullableBoolToggleWidget({required this.field});

  @override
  State<_CupertinoNullableBoolToggleWidget> createState() =>
      _CupertinoNullableBoolToggleWidgetState();
}

class _CupertinoNullableBoolToggleWidgetState
    extends State<_CupertinoNullableBoolToggleWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormNullableBoolToggle get field => widget.field;

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

  Widget _segment(String text, TextStyle? style) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(text, style: style),
      );

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final tristate = field.tristate;
    final value = field.get();

    final segmented = SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<_TriSegment>(
        // A two-state control has no segment for `null`, so an unset field
        // shows as Off until the user answers.
        groupValue: switch (value) {
          true => _TriSegment.on,
          false => _TriSegment.off,
          null => tristate ? _TriSegment.unset : _TriSegment.off,
        },
        children: <_TriSegment, Widget>{
          _TriSegment.off: _segment(field.offLabel, style.inputStyle),
          if (tristate)
            _TriSegment.unset: _segment(field.nullLabel, style.inputStyle),
          _TriSegment.on: _segment(field.onLabel, style.inputStyle),
        },
        onValueChanged: field.isEditable
            ? (segment) => field.setValue(switch (segment) {
                  _TriSegment.on => true,
                  _TriSegment.off => false,
                  _ => null,
                })
            : (_) {},
      ),
    );
    return field.decorateField(context, segmented);
  }
}
