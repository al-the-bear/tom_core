# Changelog

## 0.1.0

### Added

- **Appointments.** `CalendarAppointment`: timed in UTC or all-day by date,
  the creation offset, a verbatim RRULE with its parsed form, exceptions, a
  deterministic map form and on-demand occurrences.
- **Recurrence.** `CalendarRecurrenceRule` — the interpreted subset, its
  parser, its writer (the exact inverse) and its expansion.
- **Editing.** `CalendarOccurrenceEdit`, `CalendarAppointmentEditing` and
  `CalendarRecurrenceEditing`, as pure list transforms.
- **Frames.** `CalendarTimeFrame` and `CalendarClock`.
- **Times in words.** `calendarDescribeTimes` and `calendarDescribeRecurrence`.
- **Tasks.** `CalendarTask` and `CalendarTaskStatus`.
- **iCalendar.** `ICalendarCodec` for events and tasks, with the producer's
  `PRODID` and extension prefix, override detachment and the warnings report.
