import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../state/phase3_state.dart';

// ---------------------------------------------------------------------------
// DateTimeDemoForm — hosts every Phase 3 date/time/duration field for Demo J.
// ---------------------------------------------------------------------------

/// Hosts every Phase 3 date/time/duration field for Demo J.
///
/// Exercises `tom_flutter_ui`'s date/time concretes: `TomFormDatePicker`,
/// `TomFormDateCalendar` (inline), `TomFormTimePicker`,
/// `TomFormDateTimePicker`, `TomFormDateRangePicker`,
/// `TomFormDurationInput`, the typed-input variants
/// (`TomFormDateTextInput` / `TomFormTimeTextInput` /
/// `TomFormDateTimeTextInput` with configurable `TomDateTimeFormat`), and a
/// companion `TomFormIntSlider`.
@tomReflector
class DateTimeDemoForm extends TomForm<DateTimeDemoState> {
  DateTimeDemoForm() : super(formId: 'dateTimeDemo');

  late final eventDate = TomFormDatePicker(
    'eventDate',
    DateTime(2026, 5, 12),
    form: this,
    firstDate: DateTime(2024, 1, 1),
    lastDate: DateTime(2030, 12, 31),
    labelTextOverride: 'Event date (picker)',
  );

  late final eventDateInline = TomFormDateCalendar(
    'eventDateInline',
    DateTime(2026, 5, 12),
    form: this,
    firstDate: DateTime(2024, 1, 1),
    lastDate: DateTime(2030, 12, 31),
    labelTextOverride: 'Event date (inline calendar)',
  );

  late final startTime = TomFormTimePicker(
    'startTime',
    const TimeOfDay(hour: 9, minute: 0),
    form: this,
    labelTextOverride: 'Start time',
  );

  late final eventDateTime = TomFormDateTimePicker(
    'eventDateTime',
    DateTime(2026, 5, 12, 9, 30),
    form: this,
    firstDate: DateTime(2024, 1, 1),
    lastDate: DateTime(2030, 12, 31),
    labelTextOverride: 'Event date + time',
  );

  late final bookingRange = TomFormDateRangePicker(
    'bookingRange',
    DateTimeRange(start: DateTime(2026, 6, 1), end: DateTime(2026, 6, 7)),
    form: this,
    firstDate: DateTime(2025, 1, 1),
    lastDate: DateTime(2030, 12, 31),
    labelTextOverride: 'Booking date range',
  );

  late final taskDuration = TomFormDurationInput(
    'taskDuration',
    const Duration(hours: 1, minutes: 30),
    form: this,
    labelTextOverride: 'Task duration',
    descriptionTextOverride: 'Segmented h / m entry',
  );

  // ── Text-input variants (type by hand + picker icon) ─────────────────
  //
  // Each field carries an explicit TomDateTimeFormat.  The format can also
  // be set at runtime through the resource system: place the pattern string
  // at `{tomId}.dateFormat`, `{tomId}.timeFormat`, or
  // `{tomId}.dateTimeFormat` in the app's resource map — resource config
  // wins over the constructor parameter.

  /// ISO date — `YYYY-MM-DD`  (international standard, sortable)
  late final typedDate = TomFormDateTextInput(
    'typedDate',
    DateTime(2026, 5, 12),
    form: this,
    format: TomDateTimeFormat.isoDate,
    firstDate: DateTime(2024, 1, 1),
    lastDate: DateTime(2030, 12, 31),
    labelTextOverride: 'Date — ISO (YYYY-MM-DD)',
    descriptionTextOverride: 'Type a date or tap the calendar icon',
  );

  /// European date — `DD/MM/YYYY`
  late final typedDateEu = TomFormDateTextInput(
    'typedDateEu',
    DateTime(2026, 5, 12),
    form: this,
    format: TomDateTimeFormat.europeanDate,
    firstDate: DateTime(2024, 1, 1),
    lastDate: DateTime(2030, 12, 31),
    labelTextOverride: 'Date — European (DD/MM/YYYY)',
    descriptionTextOverride: 'Type a date or tap the calendar icon',
  );

  /// US date — `MM/DD/YYYY`
  late final typedDateUs = TomFormDateTextInput(
    'typedDateUs',
    DateTime(2026, 5, 12),
    form: this,
    format: TomDateTimeFormat.usDate,
    firstDate: DateTime(2024, 1, 1),
    lastDate: DateTime(2030, 12, 31),
    labelTextOverride: 'Date — US (MM/DD/YYYY)',
    descriptionTextOverride: 'Type a date or tap the calendar icon',
  );

  /// German date — `DD.MM.YYYY` with localised hint `TT.MM.JJJJ`
  ///
  /// The parsing pattern stays `DD.MM.YYYY` (machine-readable); the user
  /// sees the German placeholder `TT.MM.JJJJ` (Tag / Monat / Jahr).
  late final typedDateDe = TomFormDateTextInput(
    'typedDateDe',
    DateTime(2026, 5, 12),
    form: this,
    format: TomDateTimeFormat.germanDate,
    firstDate: DateTime(2024, 1, 1),
    lastDate: DateTime(2030, 12, 31),
    labelTextOverride: 'Date — German (TT.MM.JJJJ hint)',
    descriptionTextOverride:
        'Parsing pattern: DD.MM.YYYY  ·  hint shown: TT.MM.JJJJ',
  );

  /// 24-hour time — `HH:mm`
  late final typedTime = TomFormTimeTextInput(
    'typedTime',
    const TimeOfDay(hour: 9, minute: 0),
    form: this,
    format: TomDateTimeFormat.time24,
    labelTextOverride: 'Time — 24 h (HH:mm)',
    descriptionTextOverride: 'Type a time or tap the clock icon',
  );

  /// European datetime — `DD/MM/YYYY HH:mm`
  late final typedDateTime = TomFormDateTimeTextInput(
    'typedDateTime',
    DateTime(2026, 5, 12, 9, 30),
    form: this,
    format: TomDateTimeFormat.europeanDateTime,
    firstDate: DateTime(2024, 1, 1),
    lastDate: DateTime(2030, 12, 31),
    labelTextOverride: 'Date + time — European (DD/MM/YYYY HH:mm)',
    descriptionTextOverride: 'Type date and time or tap the calendar icon',
  );

  /// Equivalent minute count slider — the Demo J intro promises a side-
  /// by-side comparison with the duration input. Stored as plain int
  /// minutes; the demo synchronises it with [taskDuration] manually.
  late final taskMinutes = TomFormIntSlider(
    'taskMinutes',
    90,
    form: this,
    min: 0,
    max: 240,
    divisions: 48,
    labelTextOverride: 'Task minutes (slider)',
  );

  TomFunctionObserver<TomObservable>? _inlineToPicker;
  TomFunctionObserver<TomObservable>? _pickerToInline;

  @override
  void createFormElements() {
    // Round-5 (g): the inline calendar and the dialog picker should be
    // two views of the same logical "event date". Mirror in both
    // directions so picking a day in either widget updates the readout
    // and the other widget without a manual reload.
    _inlineToPicker =
        eventDateInline >>
        (_) {
          final v = eventDateInline.get();
          if (eventDate.get() != v) eventDate.setValue(v);
        };
    _pickerToInline =
        eventDate >>
        (_) {
          final v = eventDate.get();
          if (eventDateInline.get() != v) eventDateInline.setValue(v);
        };
  }

  @override
  void dispose() {
    final a = _inlineToPicker;
    if (a != null) eventDateInline.removeObserver(a);
    final b = _pickerToInline;
    if (b != null) eventDate.removeObserver(b);
    super.dispose();
  }
}
