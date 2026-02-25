/// DateTime Types Example
///
/// This example demonstrates how to work with DateTime and Tom's
/// timezone-aware date/time types in the reflection system.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Model Classes
// ============================================================================

/// A class with standard DateTime fields.
@tomReflector
class Event {
  String name = '';
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();
  DateTime? cancelledAt;
}

/// A class with timezone-aware date/time fields.
@tomReflector
class Meeting {
  String title = '';
  TomZonedDateTime startTime = TomZonedDateTime(
    year: 2000, month: 1, day: 1, hour: 0, minute: 0, timezone: TomTimezone.utc);
  TomZonedDateTime endTime = TomZonedDateTime(
    year: 2000, month: 1, day: 1, hour: 0, minute: 0, timezone: TomTimezone.utc);
  TomZonedDate date = TomZonedDate(
    year: 2000, month: 1, day: 1, timezone: TomTimezone.utc);
}

/// A class with lists of DateTimes.
@tomReflector
class Schedule {
  String name = '';
  List<DateTime> appointments = [];
  List<TomZonedDateTime> meetings = [];
}

/// A class with maps containing DateTimes.
@tomReflector
class Timeline {
  String title = '';
  Map<String, DateTime> milestones = {};
  Map<String, TomZonedDate> holidays = {};
}

// ============================================================================
// Example Code
// ============================================================================

void run() {
  print('=== 04: DateTime Types Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Standard DateTime
  // -------------------------------------------------------------------------
  print('1. Standard DateTime:');
  
  final event = Event();
  tomReflectionInfo.setValues(event, {
    'name': 'Annual Conference',
    'startDate': '2024-06-15T09:00:00.000Z',
    'endDate': '2024-06-17T17:00:00.000Z',
    'cancelledAt': null,
  });
  
  print('   Event: ${event.name}');
  print('   Start: ${event.startDate}');
  print('   End: ${event.endDate}');
  print('   Cancelled: ${event.cancelledAt}\n');

  // -------------------------------------------------------------------------
  // Example 2: Serializing DateTime
  // -------------------------------------------------------------------------
  print('2. Serializing DateTime:');
  
  event.cancelledAt = DateTime(2024, 5, 1, 12, 0);
  final eventJson = tomReflectionInfo.getValues(event);
  
  print('   Serialized:');
  print('   - name: ${eventJson['name']}');
  print('   - startDate: ${eventJson['startDate']}');
  print('   - cancelledAt: ${eventJson['cancelledAt']}\n');

  // -------------------------------------------------------------------------
  // Example 3: Timezone-aware dates and times
  // -------------------------------------------------------------------------
  print('3. Timezone-aware dates and times:');
  
  final meeting = Meeting();
  tomReflectionInfo.setValues(meeting, {
    'title': 'Product Review',
    'startTime': TomZonedDateTime(
      year: 2024,
      month: 7,
      day: 20,
      hour: 14,
      minute: 0,
      timezone: TomTimezone.utc,
    ).toString(),
    'endTime': TomZonedDateTime(
      year: 2024,
      month: 7,
      day: 20,
      hour: 15,
      minute: 30,
      timezone: TomTimezone.utc,
    ).toString(),
    'date': TomZonedDate(
      year: 2024,
      month: 7,
      day: 20,
      timezone: TomTimezone.utc,
    ).toString(),
  });
  
  print('   Meeting: ${meeting.title}');
  print('   Date: ${meeting.date}');
  print('   Start: ${meeting.startTime}');
  print('   End: ${meeting.endTime}\n');

  // -------------------------------------------------------------------------
  // Example 4: Lists of DateTimes
  // -------------------------------------------------------------------------
  print('4. Lists of DateTimes:');
  
  final schedule = Schedule();
  tomReflectionInfo.setValues(schedule, {
    'name': 'Weekly Schedule',
    'appointments': [
      '2024-08-01T10:00:00.000Z',
      '2024-08-02T14:30:00.000Z',
      '2024-08-03T09:00:00.000Z',
    ],
    'meetings': [
      TomZonedDateTime(year: 2024, month: 8, day: 5, hour: 10, minute: 0, timezone: TomTimezone.utc).toString(),
      TomZonedDateTime(year: 2024, month: 8, day: 6, hour: 15, minute: 0, timezone: TomTimezone.utc).toString(),
    ],
  });
  
  print('   Schedule: ${schedule.name}');
  print('   Appointments (${schedule.appointments.length}):');
  for (var appt in schedule.appointments) {
    print('   - $appt');
  }
  print('   Meetings (${schedule.meetings.length}):');
  for (var mtg in schedule.meetings) {
    print('   - $mtg');
  }
  print('');

  // -------------------------------------------------------------------------
  // Example 5: Maps with DateTimes
  // -------------------------------------------------------------------------
  print('5. Maps with DateTimes:');
  
  final timeline = Timeline();
  tomReflectionInfo.setValues(timeline, {
    'title': 'Project Timeline',
    'milestones': {
      'kickoff': '2024-01-15T00:00:00.000Z',
      'alpha': '2024-04-01T00:00:00.000Z',
      'beta': '2024-07-01T00:00:00.000Z',
      'launch': '2024-10-01T00:00:00.000Z',
    },
    'holidays': {
      'new_year': TomZonedDate(year: 2024, month: 1, day: 1, timezone: TomTimezone.utc).toString(),
      'independence_day': TomZonedDate(year: 2024, month: 7, day: 4, timezone: TomTimezone.utc).toString(),
      'christmas': TomZonedDate(year: 2024, month: 12, day: 25, timezone: TomTimezone.utc).toString(),
    },
  });
  
  print('   Timeline: ${timeline.title}');
  print('   Milestones:');
  timeline.milestones.forEach((key, value) {
    print('   - $key: $value');
  });
  print('   Holidays:');
  timeline.holidays.forEach((key, value) {
    print('   - $key: $value');
  });
  print('');

  // -------------------------------------------------------------------------
  // Example 6: Round-trip with timezone types
  // -------------------------------------------------------------------------
  print('6. Round-trip serialization:');
  
  final meetingJson = tomReflectionInfo.convertToJsonString(meeting);
  print('   Serialized meeting: $meetingJson');
  
  final meeting2 = Meeting();
  tomReflectionInfo.convertFromJsonString(meeting2, meetingJson);
  print('   Restored title: ${meeting2.title}');
  print('   Restored startTime: ${meeting2.startTime}');
  print('   StartTime year: ${meeting2.startTime.year}');
  print('   StartTime hour: ${meeting2.startTime.hour}\n');

  print('=== DateTime Types Example Complete ===\n');
}
