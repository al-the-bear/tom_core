library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../decoration/tom_generic_field_decoration_mixin.dart';
import '../style/tom_form_style.dart';
import '../style/tom_form_style_scope.dart';
import '../tom_form.dart';
import 'tom_date_time_format.dart';
import 'tom_field_widget_adapter.dart';

// ---------------------------------------------------------------------------
// TomFormDateField — abstract date-only field (DateTime, time portion = 0)
// ---------------------------------------------------------------------------

abstract class TomFormDateField extends TomField<DateTime> {
  final String? labelTextOverride;
  final String? descriptionTextOverride;
  final DateTime firstDate;
  final DateTime lastDate;

  TomFormDateField(
    super.tomId,
    super.initialValue, {
    required this.firstDate,
    required this.lastDate,
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
  })  : assert(!firstDate.isAfter(lastDate),
            'TomFormDateField: firstDate must be on or before lastDate'),
        assert(
            !initialValue.isBefore(firstDate) &&
                !initialValue.isAfter(lastDate),
            'TomFormDateField: initialValue must be within '
            '[firstDate, lastDate]; otherwise the picker throws on open');

  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// TomFormDatePicker — opens a Material date picker dialog on tap
// ---------------------------------------------------------------------------

@tomReflector
class TomFormDatePicker extends TomFormDateField
    with TomGenericFieldDecorationMixin<DateTime> {
  TomFormDatePicker(
    super.tomId,
    super.initialValue, {
    required super.firstDate,
    required super.lastDate,
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

  // The mixin's `labelText` / `descriptionText` getters return null by
  // default; the concrete class has to delegate to the abstract field's
  // resolution chain so the field anatomy renders the label above the
  // picker tile. (Mirrors the same workaround on the Cupertino side.)
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
    return form.resolveFieldStyle(form.datePickerStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _TomFormDatePickerWidget(field: this),
      );
}

class _TomFormDatePickerWidget extends StatefulWidget {
  final TomFormDatePicker field;
  const _TomFormDatePickerWidget({required this.field});

  @override
  State<_TomFormDatePickerWidget> createState() =>
      _TomFormDatePickerWidgetState();
}

class _TomFormDatePickerWidgetState extends State<_TomFormDatePickerWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormDatePicker get field => widget.field;

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

  Future<void> _open() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: field.get(),
      firstDate: field.firstDate,
      lastDate: field.lastDate,
    );
    if (picked != null) {
      field.setValue(DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inner = OutlinedButton.icon(
      onPressed: field.isEditable ? _open : null,
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text(
        field.formatDate(field.get()),
        style: theme.textTheme.bodyMedium,
      ),
    );
    return field.decorateField(context, inner);
  }
}

// ---------------------------------------------------------------------------
// TomFormDateCalendar — inline calendar
// ---------------------------------------------------------------------------

@tomReflector
class TomFormDateCalendar extends TomFormDateField
    with TomGenericFieldDecorationMixin<DateTime> {
  TomFormDateCalendar(
    super.tomId,
    super.initialValue, {
    required super.firstDate,
    required super.lastDate,
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

  // Mixin's labelText returns null and shadows the parent — restore the
  // standard delegation chain so anatomy renders the label.
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
    return form.resolveFieldStyle(form.datePickerStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _TomFormDateCalendarWidget(field: this),
      );
}

class _TomFormDateCalendarWidget extends StatefulWidget {
  final TomFormDateCalendar field;
  const _TomFormDateCalendarWidget({required this.field});

  @override
  State<_TomFormDateCalendarWidget> createState() =>
      _TomFormDateCalendarWidgetState();
}

class _TomFormDateCalendarWidgetState
    extends State<_TomFormDateCalendarWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormDateCalendar get field => widget.field;

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
    final value = field.get();
    final calendar = SizedBox(
      height: 320,
      child: CalendarDatePicker(
        // CalendarDatePicker captures `initialDate` in its own State on
        // first mount and never reconsults it. When `field.setValue`
        // fires from outside (e.g. another widget mirroring this one),
        // a plain rebuild leaves the selected highlight stuck on the
        // original date. Keying the widget by the current value forces
        // a fresh State so the visual selection follows the model.
        key: ValueKey(value),
        initialDate: value,
        firstDate: field.firstDate,
        lastDate: field.lastDate,
        onDateChanged: field.isEditable
            ? (d) => field.setValue(DateTime(d.year, d.month, d.day))
            : (_) {},
      ),
    );
    return field.decorateField(context, calendar);
  }
}

// ---------------------------------------------------------------------------
// TomFormTimeField — abstract time-only field (uses TimeOfDay)
// ---------------------------------------------------------------------------

abstract class TomFormTimeField extends TomField<TimeOfDay> {
  final String? labelTextOverride;
  final String? descriptionTextOverride;

  TomFormTimeField(
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

  String formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

@tomReflector
class TomFormTimePicker extends TomFormTimeField
    with TomGenericFieldDecorationMixin<TimeOfDay> {
  TomFormTimePicker(
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

  // Restore label/description delegation that the mixin's `=> null`
  // shadows.
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
    return form.resolveFieldStyle(form.timePickerStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _TomFormTimePickerWidget(field: this),
      );
}

class _TomFormTimePickerWidget extends StatefulWidget {
  final TomFormTimePicker field;
  const _TomFormTimePickerWidget({required this.field});

  @override
  State<_TomFormTimePickerWidget> createState() =>
      _TomFormTimePickerWidgetState();
}

class _TomFormTimePickerWidgetState extends State<_TomFormTimePickerWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormTimePicker get field => widget.field;

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

  Future<void> _open() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: field.get(),
    );
    if (picked != null) field.setValue(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inner = OutlinedButton.icon(
      onPressed: field.isEditable ? _open : null,
      icon: const Icon(Icons.access_time, size: 16),
      label: Text(field.formatTime(field.get()),
          style: theme.textTheme.bodyMedium),
    );
    return field.decorateField(context, inner);
  }
}

// ---------------------------------------------------------------------------
// TomFormDateTimeField — abstract date+time field (DateTime)
// ---------------------------------------------------------------------------

abstract class TomFormDateTimeField extends TomField<DateTime> {
  final String? labelTextOverride;
  final String? descriptionTextOverride;
  final DateTime firstDate;
  final DateTime lastDate;

  TomFormDateTimeField(
    super.tomId,
    super.initialValue, {
    required this.firstDate,
    required this.lastDate,
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
  })  : assert(!firstDate.isAfter(lastDate),
            'TomFormDateTimeField: firstDate must be on or before lastDate'),
        assert(
            !initialValue.isBefore(firstDate) &&
                !initialValue.isAfter(lastDate),
            'TomFormDateTimeField: initialValue must be within '
            '[firstDate, lastDate]');

  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  String formatDateTime(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

@tomReflector
class TomFormDateTimePicker extends TomFormDateTimeField
    with TomGenericFieldDecorationMixin<DateTime> {
  TomFormDateTimePicker(
    super.tomId,
    super.initialValue, {
    required super.firstDate,
    required super.lastDate,
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

  // Restore label/description delegation that the mixin's `=> null`
  // shadows.
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
    return form.resolveFieldStyle(form.datePickerStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _TomFormDateTimePickerWidget(field: this),
      );
}

class _TomFormDateTimePickerWidget extends StatefulWidget {
  final TomFormDateTimePicker field;
  const _TomFormDateTimePickerWidget({required this.field});

  @override
  State<_TomFormDateTimePickerWidget> createState() =>
      _TomFormDateTimePickerWidgetState();
}

class _TomFormDateTimePickerWidgetState
    extends State<_TomFormDateTimePickerWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormDateTimePicker get field => widget.field;

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

  Future<void> _open() async {
    final current = field.get();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: field.firstDate,
      lastDate: field.lastDate,
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (pickedTime == null) return;
    field.setValue(DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inner = OutlinedButton.icon(
      onPressed: field.isEditable ? _open : null,
      icon: const Icon(Icons.event, size: 16),
      label: Text(field.formatDateTime(field.get()),
          style: theme.textTheme.bodyMedium),
    );
    return field.decorateField(context, inner);
  }
}

// ---------------------------------------------------------------------------
// TomFormDateRangeField + TomFormDateRangePicker
// ---------------------------------------------------------------------------

abstract class TomFormDateRangeField extends TomField<DateTimeRange> {
  final String? labelTextOverride;
  final String? descriptionTextOverride;
  final DateTime firstDate;
  final DateTime lastDate;

  TomFormDateRangeField(
    super.tomId,
    super.initialValue, {
    required this.firstDate,
    required this.lastDate,
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
  })  : assert(!firstDate.isAfter(lastDate),
            'TomFormDateRangeField: firstDate must be on or before lastDate'),
        assert(
            !initialValue.start.isBefore(firstDate) &&
                !initialValue.end.isAfter(lastDate),
            'TomFormDateRangeField: initialValue range must fit within '
            '[firstDate, lastDate]');

  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  String formatRange(DateTimeRange r) =>
      '${_dateOnly(r.start)}  →  ${_dateOnly(r.end)}';

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

@tomReflector
class TomFormDateRangePicker extends TomFormDateRangeField
    with TomGenericFieldDecorationMixin<DateTimeRange> {
  TomFormDateRangePicker(
    super.tomId,
    super.initialValue, {
    required super.firstDate,
    required super.lastDate,
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

  // Restore label/description delegation that the mixin's `=> null`
  // shadows.
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
    return form.resolveFieldStyle(form.datePickerStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _TomFormDateRangePickerWidget(field: this),
      );
}

class _TomFormDateRangePickerWidget extends StatefulWidget {
  final TomFormDateRangePicker field;
  const _TomFormDateRangePickerWidget({required this.field});

  @override
  State<_TomFormDateRangePickerWidget> createState() =>
      _TomFormDateRangePickerWidgetState();
}

class _TomFormDateRangePickerWidgetState
    extends State<_TomFormDateRangePickerWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormDateRangePicker get field => widget.field;

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

  Future<void> _open() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: field.firstDate,
      lastDate: field.lastDate,
      initialDateRange: field.get(),
    );
    if (picked != null) field.setValue(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inner = OutlinedButton.icon(
      onPressed: field.isEditable ? _open : null,
      icon: const Icon(Icons.date_range, size: 16),
      label: Text(field.formatRange(field.get()),
          style: theme.textTheme.bodyMedium),
    );
    return field.decorateField(context, inner);
  }
}

// ---------------------------------------------------------------------------
// TimeRange value type + TomFormTimeRangeField (abstract)
// ---------------------------------------------------------------------------

/// A `(start, end)` pair of [TimeOfDay] values, used as the value type for
/// time-range fields. Equatable so observers see a real change only when
/// at least one endpoint moves.
///
/// No concrete widget ships in Phase 3 (the spec table treats Phase 3
/// concretes as a "target — not every row is required"). Apps that need
/// a time-range picker today can subclass [TomFormTimeRangeField] with
/// two stacked [TomFormTimePicker]-style buttons.
class TimeRange {
  final TimeOfDay start;
  final TimeOfDay end;

  const TimeRange(this.start, this.end);

  @override
  bool operator ==(Object other) =>
      other is TimeRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '($start, $end)';
}

abstract class TomFormTimeRangeField extends TomField<TimeRange> {
  final String? labelTextOverride;
  final String? descriptionTextOverride;

  TomFormTimeRangeField(
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

  String formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  String formatRange(TimeRange r) =>
      '${formatTime(r.start)}  →  ${formatTime(r.end)}';
}

// ---------------------------------------------------------------------------
// TomFormDateTimeRangeField (abstract)
// ---------------------------------------------------------------------------

/// Abstract field for a `(start, end)` pair of full [DateTime] values.
/// Reuses Flutter's [DateTimeRange] as the value type. As with
/// [TomFormTimeRangeField], no concrete widget ships in Phase 3 — apps
/// that need one can compose [TomFormDateTimePicker] twice.
abstract class TomFormDateTimeRangeField extends TomField<DateTimeRange> {
  final String? labelTextOverride;
  final String? descriptionTextOverride;
  final DateTime firstDate;
  final DateTime lastDate;

  TomFormDateTimeRangeField(
    super.tomId,
    super.initialValue, {
    required this.firstDate,
    required this.lastDate,
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

  String formatDateTime(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  String formatRange(DateTimeRange r) =>
      '${formatDateTime(r.start)}  →  ${formatDateTime(r.end)}';
}

// ---------------------------------------------------------------------------
// TomFormDateTextInput — text field + calendar icon that opens the date
// picker dialog. Accepts manual entry in the configured date format; the
// picker can fill the field without typing.
//
// Format precedence (highest first):
//   1. Resource key `{fieldBasePath}.dateFormat` (e.g. 'DD/MM/YYYY')
//   2. Constructor parameter `format`
//   3. Default: [TomDateTimeFormat.isoDate] (`YYYY-MM-DD`)
// ---------------------------------------------------------------------------

@tomReflector
class TomFormDateTextInput extends TomFormDateField
    with TomGenericFieldDecorationMixin<DateTime> {
  /// Optional explicit format.  Overridden by the `dateFormat` resource key
  /// when one is present for this field's base path.
  final TomDateTimeFormat? format;

  TomFormDateTextInput(
    super.tomId,
    super.initialValue, {
    required super.firstDate,
    required super.lastDate,
    this.format,
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

  /// Resolves the effective format: resource → constructor param → ISO default.
  TomDateTimeFormat get resolvedFormat {
    final resource = TomCtr.textOrNull(basePath, 'dateFormat');
    if (resource != null) return TomDateTimeFormat(resource);
    return format ?? TomDateTimeFormat.isoDate;
  }

  /// Resolves the hint text shown in the text field placeholder and error
  /// message.  Precedence:
  ///   1. Resource key `{fieldBasePath}.dateHint` (e.g. `'TT.MM.JJJJ'`)
  ///   2. [TomDateTimeFormat.displayPattern] on the resolved format
  ///   3. [TomDateTimeFormat.pattern] (fallback)
  String get resolvedHintText =>
      TomCtr.textOrNull(basePath, 'dateHint') ?? resolvedFormat.hintText;

  @override
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.datePickerStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _TomFormDateTextInputWidget(field: this),
      );
}

class _TomFormDateTextInputWidget extends StatefulWidget {
  final TomFormDateTextInput field;
  const _TomFormDateTextInputWidget({required this.field});

  @override
  State<_TomFormDateTextInputWidget> createState() =>
      _TomFormDateTextInputWidgetState();
}

class _TomFormDateTextInputWidgetState
    extends State<_TomFormDateTextInputWidget> {
  late TextEditingController _ctrl;
  late FocusNode _focus;
  late TomFunctionObserver<TomObservable> _observer;
  String? _parseError;
  bool _updatingFromField = false;

  TomFormDateTextInput get field => widget.field;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: field.resolvedFormat.formatDate(field.get()));
    _focus = FocusNode()..addListener(_onFocusChange);
    _subscribe(field);
  }

  void _subscribe(TomFormDateTextInput target) {
    _observer = target >> (_) {
      if (!_updatingFromField) {
        final text = target.resolvedFormat.formatDate(target.get());
        if (_ctrl.text != text) {
          _ctrl.text = text;
          _parseError = null;
        }
      }
      if (mounted) setState(() {});
    };
    target.validationListenable.addListener(_onValidationChanged);
  }

  void _unsubscribe(TomFormDateTextInput target) {
    target.validationListenable.removeListener(_onValidationChanged);
    target.removeObserver(_observer);
  }

  @override
  void didUpdateWidget(covariant _TomFormDateTextInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.field, widget.field)) {
      _unsubscribe(oldWidget.field);
      _subscribe(widget.field);
      final text = widget.field.resolvedFormat.formatDate(widget.field.get());
      if (_ctrl.text != text) {
        _ctrl.text = text;
        _parseError = null;
      }
    }
  }

  void _onValidationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _unsubscribe(field);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _validateText();
  }

  void _onChanged(String text) {
    final parsed = field.resolvedFormat.parseDate(
      text,
      firstDate: field.firstDate,
      lastDate: field.lastDate,
    );
    if (parsed != null) {
      _updatingFromField = true;
      field.setValue(parsed);
      _updatingFromField = false;
      if (mounted) setState(() => _parseError = null);
    }
  }

  void _validateText() {
    final parsed = field.resolvedFormat.parseDate(
      _ctrl.text,
      firstDate: field.firstDate,
      lastDate: field.lastDate,
    );
    if (mounted) {
      setState(() => _parseError =
          parsed == null ? 'Format: ${field.resolvedHintText}' : null);
    }
  }

  Future<void> _openPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: field.get(),
      firstDate: field.firstDate,
      lastDate: field.lastDate,
    );
    if (picked != null && mounted) {
      final d = DateTime(picked.year, picked.month, picked.day);
      _updatingFromField = true;
      field.setValue(d);
      _updatingFromField = false;
      _ctrl.text = field.resolvedFormat.formatDate(d);
      setState(() => _parseError = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inner = TextField(
      controller: _ctrl,
      focusNode: _focus,
      enabled: field.isEditable,
      keyboardType: TextInputType.datetime,
      onChanged: _onChanged,
      decoration: InputDecoration(
        hintText: field.resolvedHintText,
        errorText: _parseError,
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today, size: 18),
          tooltip: 'Open date picker',
          onPressed: field.isEditable ? _openPicker : null,
        ),
      ),
    );
    return field.decorateField(context, inner);
  }
}

// ---------------------------------------------------------------------------
// TomFormTimeTextInput — text field + clock icon that opens the time picker
// dialog. Accepts manual entry in the configured time format.
//
// Format precedence (highest first):
//   1. Resource key `{fieldBasePath}.timeFormat` (e.g. 'H:mm')
//   2. Constructor parameter `format`
//   3. Default: [TomDateTimeFormat.time24] (`HH:mm`)
// ---------------------------------------------------------------------------

@tomReflector
class TomFormTimeTextInput extends TomFormTimeField
    with TomGenericFieldDecorationMixin<TimeOfDay> {
  /// Optional explicit format.  Overridden by the `timeFormat` resource key.
  final TomDateTimeFormat? format;

  TomFormTimeTextInput(
    super.tomId,
    super.initialValue, {
    this.format,
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

  /// Resolves the effective format: resource → constructor param → 24 h default.
  TomDateTimeFormat get resolvedFormat {
    final resource = TomCtr.textOrNull(basePath, 'timeFormat');
    if (resource != null) return TomDateTimeFormat(resource);
    return format ?? TomDateTimeFormat.time24;
  }

  /// Resolves the hint text shown in the text field placeholder and error
  /// message.  Precedence:
  ///   1. Resource key `{fieldBasePath}.timeHint`
  ///   2. [TomDateTimeFormat.displayPattern] on the resolved format
  ///   3. [TomDateTimeFormat.pattern] (fallback)
  String get resolvedHintText =>
      TomCtr.textOrNull(basePath, 'timeHint') ?? resolvedFormat.hintText;

  @override
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.timePickerStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _TomFormTimeTextInputWidget(field: this),
      );
}

class _TomFormTimeTextInputWidget extends StatefulWidget {
  final TomFormTimeTextInput field;
  const _TomFormTimeTextInputWidget({required this.field});

  @override
  State<_TomFormTimeTextInputWidget> createState() =>
      _TomFormTimeTextInputWidgetState();
}

class _TomFormTimeTextInputWidgetState
    extends State<_TomFormTimeTextInputWidget> {
  late TextEditingController _ctrl;
  late FocusNode _focus;
  late TomFunctionObserver<TomObservable> _observer;
  String? _parseError;
  bool _updatingFromField = false;

  TomFormTimeTextInput get field => widget.field;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: field.resolvedFormat.formatTime(field.get()));
    _focus = FocusNode()..addListener(_onFocusChange);
    _subscribe(field);
  }

  void _subscribe(TomFormTimeTextInput target) {
    _observer = target >> (_) {
      if (!_updatingFromField) {
        final text = target.resolvedFormat.formatTime(target.get());
        if (_ctrl.text != text) {
          _ctrl.text = text;
          _parseError = null;
        }
      }
      if (mounted) setState(() {});
    };
    target.validationListenable.addListener(_onValidationChanged);
  }

  void _unsubscribe(TomFormTimeTextInput target) {
    target.validationListenable.removeListener(_onValidationChanged);
    target.removeObserver(_observer);
  }

  @override
  void didUpdateWidget(covariant _TomFormTimeTextInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.field, widget.field)) {
      _unsubscribe(oldWidget.field);
      _subscribe(widget.field);
      final text = widget.field.resolvedFormat.formatTime(widget.field.get());
      if (_ctrl.text != text) {
        _ctrl.text = text;
        _parseError = null;
      }
    }
  }

  void _onValidationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _unsubscribe(field);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _validateText();
  }

  void _onChanged(String text) {
    final parsed = field.resolvedFormat.parseTime(text);
    if (parsed != null) {
      _updatingFromField = true;
      field.setValue(parsed);
      _updatingFromField = false;
      if (mounted) setState(() => _parseError = null);
    }
  }

  void _validateText() {
    final parsed = field.resolvedFormat.parseTime(_ctrl.text);
    if (mounted) {
      setState(() => _parseError =
          parsed == null ? 'Format: ${field.resolvedHintText}' : null);
    }
  }

  Future<void> _openPicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: field.get(),
    );
    if (picked != null && mounted) {
      _updatingFromField = true;
      field.setValue(picked);
      _updatingFromField = false;
      _ctrl.text = field.resolvedFormat.formatTime(picked);
      setState(() => _parseError = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inner = TextField(
      controller: _ctrl,
      focusNode: _focus,
      enabled: field.isEditable,
      keyboardType: TextInputType.datetime,
      onChanged: _onChanged,
      decoration: InputDecoration(
        hintText: field.resolvedHintText,
        errorText: _parseError,
        suffixIcon: IconButton(
          icon: const Icon(Icons.access_time, size: 18),
          tooltip: 'Open time picker',
          onPressed: field.isEditable ? _openPicker : null,
        ),
      ),
    );
    return field.decorateField(context, inner);
  }
}

// ---------------------------------------------------------------------------
// TomFormDateTimeTextInput — text field + calendar icon that opens the
// sequential date-then-time picker dialogs. Accepts manual entry in the
// configured datetime format.
//
// Format precedence (highest first):
//   1. Resource key `{fieldBasePath}.dateTimeFormat` (e.g. 'DD/MM/YYYY HH:mm')
//   2. Constructor parameter `format`
//   3. Default: [TomDateTimeFormat.isoDateTime] (`YYYY-MM-DD HH:mm`)
// ---------------------------------------------------------------------------

@tomReflector
class TomFormDateTimeTextInput extends TomFormDateTimeField
    with TomGenericFieldDecorationMixin<DateTime> {
  /// Optional explicit format.  Overridden by the `dateTimeFormat` resource key.
  final TomDateTimeFormat? format;

  TomFormDateTimeTextInput(
    super.tomId,
    super.initialValue, {
    required super.firstDate,
    required super.lastDate,
    this.format,
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

  /// Resolves the effective format: resource → constructor param → ISO default.
  TomDateTimeFormat get resolvedFormat {
    final resource = TomCtr.textOrNull(basePath, 'dateTimeFormat');
    if (resource != null) return TomDateTimeFormat(resource);
    return format ?? TomDateTimeFormat.isoDateTime;
  }

  /// Resolves the hint text shown in the text field placeholder and error
  /// message.  Precedence:
  ///   1. Resource key `{fieldBasePath}.dateTimeHint`
  ///   2. [TomDateTimeFormat.displayPattern] on the resolved format
  ///   3. [TomDateTimeFormat.pattern] (fallback)
  String get resolvedHintText =>
      TomCtr.textOrNull(basePath, 'dateTimeHint') ?? resolvedFormat.hintText;

  @override
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.datePickerStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _TomFormDateTimeTextInputWidget(field: this),
      );
}

class _TomFormDateTimeTextInputWidget extends StatefulWidget {
  final TomFormDateTimeTextInput field;
  const _TomFormDateTimeTextInputWidget({required this.field});

  @override
  State<_TomFormDateTimeTextInputWidget> createState() =>
      _TomFormDateTimeTextInputWidgetState();
}

class _TomFormDateTimeTextInputWidgetState
    extends State<_TomFormDateTimeTextInputWidget> {
  late TextEditingController _ctrl;
  late FocusNode _focus;
  late TomFunctionObserver<TomObservable> _observer;
  String? _parseError;
  bool _updatingFromField = false;

  TomFormDateTimeTextInput get field => widget.field;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: field.resolvedFormat.formatDateTime(field.get()));
    _focus = FocusNode()..addListener(_onFocusChange);
    _subscribe(field);
  }

  void _subscribe(TomFormDateTimeTextInput target) {
    _observer = target >> (_) {
      if (!_updatingFromField) {
        final text = target.resolvedFormat.formatDateTime(target.get());
        if (_ctrl.text != text) {
          _ctrl.text = text;
          _parseError = null;
        }
      }
      if (mounted) setState(() {});
    };
    target.validationListenable.addListener(_onValidationChanged);
  }

  void _unsubscribe(TomFormDateTimeTextInput target) {
    target.validationListenable.removeListener(_onValidationChanged);
    target.removeObserver(_observer);
  }

  @override
  void didUpdateWidget(covariant _TomFormDateTimeTextInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.field, widget.field)) {
      _unsubscribe(oldWidget.field);
      _subscribe(widget.field);
      final text =
          widget.field.resolvedFormat.formatDateTime(widget.field.get());
      if (_ctrl.text != text) {
        _ctrl.text = text;
        _parseError = null;
      }
    }
  }

  void _onValidationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _unsubscribe(field);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _validateText();
  }

  void _onChanged(String text) {
    final parsed = field.resolvedFormat.parseDateTime(
      text,
      firstDate: field.firstDate,
      lastDate: field.lastDate,
    );
    if (parsed != null) {
      _updatingFromField = true;
      field.setValue(parsed);
      _updatingFromField = false;
      if (mounted) setState(() => _parseError = null);
    }
  }

  void _validateText() {
    final parsed = field.resolvedFormat.parseDateTime(
      _ctrl.text,
      firstDate: field.firstDate,
      lastDate: field.lastDate,
    );
    if (mounted) {
      setState(() => _parseError =
          parsed == null ? 'Format: ${field.resolvedHintText}' : null);
    }
  }

  Future<void> _openPicker() async {
    final current = field.get();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: field.firstDate,
      lastDate: field.lastDate,
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (pickedTime == null || !mounted) return;
    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    _updatingFromField = true;
    field.setValue(dt);
    _updatingFromField = false;
    _ctrl.text = field.resolvedFormat.formatDateTime(dt);
    setState(() => _parseError = null);
  }

  @override
  Widget build(BuildContext context) {
    final inner = TextField(
      controller: _ctrl,
      focusNode: _focus,
      enabled: field.isEditable,
      keyboardType: TextInputType.datetime,
      onChanged: _onChanged,
      decoration: InputDecoration(
        hintText: field.resolvedHintText,
        errorText: _parseError,
        suffixIcon: IconButton(
          icon: const Icon(Icons.event, size: 18),
          tooltip: 'Open date + time picker',
          onPressed: field.isEditable ? _openPicker : null,
        ),
      ),
    );
    return field.decorateField(context, inner);
  }
}
