import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../state/phase3_state.dart';

// ---------------------------------------------------------------------------
// DateTimeDemoForm — hosts every Phase 3 date/time/duration field for Demo J.
// ---------------------------------------------------------------------------
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
    DateTimeRange(
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 6, 7),
    ),
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
    _inlineToPicker = eventDateInline >> (_) {
      final v = eventDateInline.get();
      if (eventDate.get() != v) eventDate.setValue(v);
    };
    _pickerToInline = eventDate >> (_) {
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
