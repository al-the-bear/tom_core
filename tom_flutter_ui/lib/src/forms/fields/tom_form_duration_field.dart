library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../decoration/tom_generic_field_decoration_mixin.dart';
import '../style/tom_form_style.dart';
import '../style/tom_form_style_scope.dart';
import '../tom_form.dart';
import 'tom_field_widget_adapter.dart';

// ---------------------------------------------------------------------------
// TomFormDurationField — abstract Duration-typed field (Phase 3)
// ---------------------------------------------------------------------------

abstract class TomFormDurationField extends TomField<Duration> {
  final String? labelTextOverride;
  final String? descriptionTextOverride;

  TomFormDurationField(
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

// ---------------------------------------------------------------------------
// TomFormDurationInput — h:mm segmented entry
// ---------------------------------------------------------------------------

@tomReflector
class TomFormDurationInput extends TomFormDurationField
    with TomGenericFieldDecorationMixin<Duration> {
  /// Maximum hours allowed (display + clamp). Defaults to 99.
  final int maxHours;

  TomFormDurationInput(
    super.tomId,
    super.initialValue, {
    this.maxHours = 99,
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
    return form.resolveFieldStyle(form.stringInputStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _TomFormDurationInputWidget(field: this),
      );
}

class _TomFormDurationInputWidget extends StatefulWidget {
  final TomFormDurationInput field;
  const _TomFormDurationInputWidget({required this.field});

  @override
  State<_TomFormDurationInputWidget> createState() =>
      _TomFormDurationInputWidgetState();
}

class _TomFormDurationInputWidgetState
    extends State<_TomFormDurationInputWidget> {
  late final TextEditingController _hours;
  late final TextEditingController _minutes;
  late final TomFunctionObserver<TomObservable> _observer;
  bool _updatingFromField = false;

  TomFormDurationInput get field => widget.field;

  @override
  void initState() {
    super.initState();
    final d = field.get();
    _hours = TextEditingController(text: d.inHours.toString());
    _minutes = TextEditingController(
        text: (d.inMinutes - d.inHours * 60).toString().padLeft(2, '0'));
    _observer = field >> (observable) {
      if (!_updatingFromField) {
        final v = (observable as TomObject<Duration>).get();
        final h = v.inHours.toString();
        final m = (v.inMinutes - v.inHours * 60).toString().padLeft(2, '0');
        if (_hours.text != h) _hours.text = h;
        if (_minutes.text != m) _minutes.text = m;
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
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _push() {
    final h = int.tryParse(_hours.text) ?? 0;
    final m = int.tryParse(_minutes.text) ?? 0;
    final clampedH = h.clamp(0, field.maxHours);
    final clampedM = m.clamp(0, 59);
    _updatingFromField = true;
    field.setValue(Duration(hours: clampedH, minutes: clampedM));
    _updatingFromField = false;
  }

  Widget _segment(
    BuildContext context, {
    required TextEditingController controller,
    required String suffix,
    required int maxLength,
    required TomFieldStyle style,
  }) {
    return SizedBox(
      width: 56,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxLength),
        ],
        style: style.inputStyle,
        enabled: field.isEditable,
        onChanged: (_) => _push(),
        decoration: InputDecoration(
          isDense: true,
          suffixText: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: style.fieldBorder,
          focusedBorder: style.focusedBorder,
          enabledBorder: style.fieldBorder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = field.resolveStyle(context);
    final inner = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _segment(
          context,
          controller: _hours,
          suffix: 'h',
          maxLength: 2,
          style: style,
        ),
        const SizedBox(width: 8),
        _segment(
          context,
          controller: _minutes,
          suffix: 'm',
          maxLength: 2,
          style: style,
        ),
      ],
    );
    return field.decorateField(context, inner);
  }
}
