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
  });

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
    final calendar = SizedBox(
      height: 320,
      child: CalendarDatePicker(
        initialDate: field.get(),
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
  });

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
