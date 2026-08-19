/// DateTime Types Example
///
/// This example demonstrates how to work with DateTime and Tom's
/// timezone-aware date/time types in the reflection system.
///
/// Key concepts:
/// - Standard DateTime fields
/// - TomZonedDateTime and TomZonedDate types
/// - Lists and Maps of date/time types
/// - Round-trip serialization of date/time values
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_bootstrap.dart';

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
  TomZonedDate date =
      TomZonedDate(year: 2000, month: 1, day: 1, timezone: TomTimezone.utc);
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
// Example Class
// ============================================================================

class DateTimeTypesExample {
  // Captured results
  static late Event event;
  static late Meeting meeting;
  static late Schedule schedule;
  static late Timeline timeline;
  static late String eventJsonResult;
  static late Meeting restoredMeeting;

  // -------------------------------------------------------------------------
  // Example 1: Standard DateTime
  // -------------------------------------------------------------------------
  static void example1StandardDateTime() {
    print('1. Standard DateTime:');

    final event = tomReflectionInfo.createInstance<Event>();
    tomReflectionInfo.setValues(event, {
      'name': 'Annual Conference',
      'startDate': '2024-06-15T09:00:00.000Z',
      'endDate': '2024-06-17T17:00:00.000Z',
      'cancelledAt': null,
    });

    print('   Event: ${event.name}');
    print('   Start: ${event.startDate}');
    print('   End: ${event.endDate}');
    print('   Cancelled: ${event.cancelledAt}');

    DateTimeTypesExample.event = event;

    // Assertions
    assert(event.name == 'Annual Conference', 'Name should match');
    assert(event.startDate.year == 2024, 'Year should be 2024');
    assert(event.startDate.month == 6, 'Month should be June');
    assert(event.startDate.day == 15, 'Day should be 15');
    assert(event.cancelledAt == null, 'CancelledAt should be null');
  }

  // -------------------------------------------------------------------------
  // Example 2: Serializing DateTime
  // -------------------------------------------------------------------------
  static void example2SerializingDateTime() {
    print('\n2. Serializing DateTime:');

    final event = Event()
      ..name = 'Product Launch'
      ..startDate = DateTime(2024, 9, 1, 10, 0)
      ..endDate = DateTime(2024, 9, 1, 18, 0)
      ..cancelledAt = DateTime(2024, 8, 15, 12, 0);

    final eventJson = tomReflectionInfo.getValues(event);

    print('   Serialized:');
    print('   - name: ${eventJson['name']}');
    print('   - startDate: ${eventJson['startDate']}');
    print('   - cancelledAt: ${eventJson['cancelledAt']}');

    eventJsonResult = tomReflectionInfo.convertToJsonString(event);

    // Assertions
    assert(eventJson['name'] == 'Product Launch', 'Name should match');
    assert(eventJson['startDate'] != null, 'Start date should be serialized');
    assert(eventJson['cancelledAt'] != null, 'Cancelled date should be serialized');
  }

  // -------------------------------------------------------------------------
  // Example 3: Timezone-aware dates and times
  // -------------------------------------------------------------------------
  static void example3TimezoneAwareDates() {
    print('\n3. Timezone-aware dates and times:');

    final meeting = tomReflectionInfo.createInstance<Meeting>();
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
    print('   End: ${meeting.endTime}');

    DateTimeTypesExample.meeting = meeting;

    // Assertions
    assert(meeting.title == 'Product Review', 'Title should match');
    assert(meeting.startTime.year == 2024, 'Year should be 2024');
    assert(meeting.startTime.hour == 14, 'Hour should be 14');
  }

  // -------------------------------------------------------------------------
  // Example 4: Lists of DateTimes
  // -------------------------------------------------------------------------
  static void example4DateTimeLists() {
    print('\n4. Lists of DateTimes:');

    final schedule = tomReflectionInfo.createInstance<Schedule>();
    tomReflectionInfo.setValues(schedule, {
      'name': 'Weekly Schedule',
      'appointments': [
        '2024-08-01T10:00:00.000Z',
        '2024-08-02T14:30:00.000Z',
        '2024-08-03T09:00:00.000Z',
      ],
      'meetings': [
        TomZonedDateTime(
                year: 2024, month: 8, day: 5, hour: 10, minute: 0, timezone: TomTimezone.utc)
            .toString(),
        TomZonedDateTime(
                year: 2024, month: 8, day: 6, hour: 15, minute: 0, timezone: TomTimezone.utc)
            .toString(),
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

    DateTimeTypesExample.schedule = schedule;

    // Assertions
    assert(schedule.appointments.length == 3, 'Should have 3 appointments');
    assert(schedule.meetings.length == 2, 'Should have 2 meetings');
    assert(schedule.appointments[0].month == 8, 'First appt should be in August');
  }

  // -------------------------------------------------------------------------
  // Example 5: Maps with DateTimes
  // -------------------------------------------------------------------------
  static void example5DateTimeMaps() {
    print('\n5. Maps with DateTimes:');

    final timeline = tomReflectionInfo.createInstance<Timeline>();
    tomReflectionInfo.setValues(timeline, {
      'title': 'Project Timeline',
      'milestones': {
        'kickoff': '2024-01-15T00:00:00.000Z',
        'alpha': '2024-04-01T00:00:00.000Z',
        'beta': '2024-07-01T00:00:00.000Z',
        'launch': '2024-10-01T00:00:00.000Z',
      },
      'holidays': {
        'new_year':
            TomZonedDate(year: 2024, month: 1, day: 1, timezone: TomTimezone.utc).toString(),
        'independence_day':
            TomZonedDate(year: 2024, month: 7, day: 4, timezone: TomTimezone.utc).toString(),
        'christmas':
            TomZonedDate(year: 2024, month: 12, day: 25, timezone: TomTimezone.utc).toString(),
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

    DateTimeTypesExample.timeline = timeline;

    // Assertions
    assert(timeline.milestones.length == 4, 'Should have 4 milestones');
    assert(timeline.holidays.length == 3, 'Should have 3 holidays');
    assert(timeline.milestones['kickoff']!.year == 2024, 'Kickoff year should be 2024');
  }

  // -------------------------------------------------------------------------
  // Example 6: Round-trip serialization
  // -------------------------------------------------------------------------
  static void example6RoundTrip() {
    print('\n6. Round-trip serialization:');

    final meeting = Meeting()
      ..title = 'Team Standup'
      ..startTime = TomZonedDateTime(
          year: 2024, month: 9, day: 15, hour: 9, minute: 0, timezone: TomTimezone.utc)
      ..endTime = TomZonedDateTime(
          year: 2024, month: 9, day: 15, hour: 9, minute: 30, timezone: TomTimezone.utc)
      ..date = TomZonedDate(year: 2024, month: 9, day: 15, timezone: TomTimezone.utc);

    final meetingJson = tomReflectionInfo.convertToJsonString(meeting);
    print('   Serialized meeting: $meetingJson');

    final restored = tomReflectionInfo.createInstance<Meeting>();
    tomReflectionInfo.convertFromJsonString(restored, meetingJson);

    print('   Restored title: ${restored.title}');
    print('   Restored startTime: ${restored.startTime}');
    print('   StartTime year: ${restored.startTime.year}');
    print('   StartTime hour: ${restored.startTime.hour}');

    restoredMeeting = restored;

    // Assertions
    assert(restored.title == 'Team Standup', 'Title should be restored');
    assert(restored.startTime.year == 2024, 'Year should be restored');
    assert(restored.startTime.hour == 9, 'Hour should be restored');
    assert(restored.date.day == 15, 'Day should be restored');
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 04: DateTime Types Example ===\n');

    example1StandardDateTime();
    example2SerializingDateTime();
    example3TimezoneAwareDates();
    example4DateTimeLists();
    example5DateTimeMaps();
    example6RoundTrip();

    print('\n=== DateTime Types Example Complete ===\n');
  }
}

void run() => DateTimeTypesExample.run();

void main() {
  bootstrapSamples();
  run();
}
