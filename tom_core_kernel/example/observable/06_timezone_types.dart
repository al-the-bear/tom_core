/// Example: Timezone-Aware Date/Time Types
///
/// This example demonstrates the timezone-aware observable types:
/// - TomOZonedDate, TomOZonedTime, TomOZonedDateTime
/// - Nullable variants: TomNOZonedDate, TomNOZonedTime, TomNOZonedDateTime
/// - Serialization with prefixes (@D@, @T@, @X@)
/// - Range types: TomDateRange, TomTimeRange, TomDateTimeRange
///
/// NOTE: This example requires the reflection build step and timezone
/// initialization to run.
/// Run: `dart run build_runner build` before executing this example.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

void run() {
  print('=== Timezone-Aware Date/Time Example ===\n');

  // --- Creating timezone-aware dates ---
  print('1. Creating TomZonedDate');
  final birthday = TomZonedDate(
    year: 1990,
    month: 5,
    day: 15,
    timezone: TomTimezone.utc,
  );
  final observableBirthday = TomOZonedDate(birthday);

  assert(birthday.year == 1990, "Year should be 1990");
  assert(birthday.month == 5, "Month should be 5");
  assert(birthday.day == 15, "Day should be 15");

  print('   birthday: ${~observableBirthday}');
  print('   year: ${(~observableBirthday).year}');
  print('   month: ${(~observableBirthday).month}');
  print('   day: ${(~observableBirthday).day}');

  // --- Creating timezone-aware times ---
  print('\n2. Creating TomZonedTime');
  final meetingTime = TomZonedTime(
    hour: 14,
    minute: 30,
    second: 0,
    timezone: TomTimezone.utc,
  );
  final observableMeetingTime = TomOZonedTime(meetingTime);

  assert(meetingTime.hour == 14, "Hour should be 14");
  assert(meetingTime.minute == 30, "Minute should be 30");

  print('   meetingTime: ${~observableMeetingTime}');
  print('   hour: ${(~observableMeetingTime).hour}');
  print('   minute: ${(~observableMeetingTime).minute}');

  // --- Creating timezone-aware datetimes ---
  print('\n3. Creating TomZonedDateTime');
  final eventDateTime = TomZonedDateTime(
    year: 2024,
    month: 12,
    day: 25,
    hour: 18,
    minute: 0,
    second: 0,
    timezone: TomTimezone.utc,
  );
  final observableEvent = TomOZonedDateTime(eventDateTime);

  assert(eventDateTime.year == 2024, "Year should be 2024");
  assert(eventDateTime.month == 12, "Month should be 12");
  assert(eventDateTime.hour == 18, "Hour should be 18");

  print('   eventDateTime: ${~observableEvent}');

  // --- Observing changes ---
  print('\n4. Observing timezone-aware observable changes');
  final appointment = TomOZonedDateTime(
    TomZonedDateTime.fromDateTime(DateTime(2024, 1, 10, 9, 0)),
  );
  int notifyCount = 0;

  appointment >> (obs) {
    notifyCount++;
    print('   Appointment changed! (notification #$notifyCount)');
  };

  // Change the value
  appointment | TomZonedDateTime.fromDateTime(DateTime(2024, 1, 11, 10, 0));
  assert(notifyCount == 1, "Should notify on change");
  print('   New appointment: ${~appointment}');

  // --- Serialization prefixes ---
  print('\n5. Serialization prefixes');
  print('   TomZonedDate prefix: ${TomZonedDate.serializationPrefix}');
  print('   TomZonedTime prefix: ${TomZonedTime.serializationPrefix}');
  print('   TomZonedDateTime prefix: ${TomZonedDateTime.serializationPrefix}');

  assert(TomZonedDate.serializationPrefix == "@D@", "Date prefix should be @D@");
  assert(TomZonedTime.serializationPrefix == "@T@", "Time prefix should be @T@");
  assert(TomZonedDateTime.serializationPrefix == "@X@", "DateTime prefix should be @X@");

  // --- Nullable timezone types ---
  print('\n6. Nullable timezone types');
  final optionalDate = TomNOZonedDate(null);
  final optionalTime = TomNOZonedTime(null);
  final optionalDateTime = TomNOZonedDateTime(null);

  assert(optionalDate.isNull, "Optional date should be null");
  assert(optionalTime.isNull, "Optional time should be null");
  assert(optionalDateTime.isNull, "Optional datetime should be null");

  print('   optionalDate.isNull: ${optionalDate.isNull}');
  print('   optionalTime.isNull: ${optionalTime.isNull}');
  print('   optionalDateTime.isNull: ${optionalDateTime.isNull}');

  // Set values
  optionalDate | TomZonedDate.fromDateTime(DateTime(2024, 6, 1));
  assert(!optionalDate.isNull, "Optional date should not be null after set");
  print('   After setting optionalDate: ${~optionalDate}');

  optionalTime | TomZonedTime.fromDateTime(DateTime(2024, 1, 1, 12, 30));
  assert(!optionalTime.isNull, "Optional time should not be null after set");
  print('   After setting optionalTime: ${~optionalTime}');

  // --- TomDateRange ---
  print('\n7. TomDateRange');
  final vacation = TomDateRange();
  int rangeNotifyCount = 0;

  vacation >> (obs) {
    rangeNotifyCount++;
  };

  vacation.startDate | TomZonedDate.fromDateTime(DateTime(2024, 7, 1));
  vacation.endDate | TomZonedDate.fromDateTime(DateTime(2024, 7, 14));

  assert(rangeNotifyCount >= 1, "Range should notify on changes");
  assert(~vacation.startDate != null, "Start date should be set");
  assert(~vacation.endDate != null, "End date should be set");

  print('   Vacation: ${~vacation.startDate} to ${~vacation.endDate}');

  // --- TomTimeRange ---
  print('\n8. TomTimeRange');
  final workHours = TomTimeRange();

  workHours.startTime | TomZonedTime(
    hour: 9,
    minute: 0,
    second: 0,
    timezone: TomTimezone.utc,
  );
  workHours.endTime | TomZonedTime(
    hour: 17,
    minute: 0,
    second: 0,
    timezone: TomTimezone.utc,
  );

  print('   Work hours: ${~workHours.startTime} to ${~workHours.endTime}');

  // --- TomDateTimeRange ---
  print('\n9. TomDateTimeRange');
  final event = TomDateTimeRange();

  event.startDateTime | TomZonedDateTime.fromDateTime(DateTime(2024, 12, 31, 20, 0));
  event.endDateTime | TomZonedDateTime.fromDateTime(DateTime(2025, 1, 1, 2, 0));

  print('   Event: ${~event.startDateTime} to ${~event.endDateTime}');

  // --- setByString for deserialization ---
  print('\n10. setByString for deserialization');
  final deserializedDate = TomOZonedDate(TomZonedDate.fromDateTime(DateTime(1970)));
  
  // Create a serialized string
  final originalDate = TomZonedDate(
    year: 2024,
    month: 3,
    day: 20,
    timezone: TomTimezone.utc,
  );
  // toString() already includes the prefix
  final serialized = originalDate.toString();
  print('   Serialized date: $serialized');

  // Deserialize using setByString - the string already has the prefix
  deserializedDate.setByString(serialized);
  
  print('   Deserialized date: ${~deserializedDate}');
  assert((~deserializedDate).year == 2024, "Deserialized year should be 2024");
  assert((~deserializedDate).month == 3, "Deserialized month should be 3");
  assert((~deserializedDate).day == 20, "Deserialized day should be 20");

  // --- Creating from DateTime ---
  print('\n11. Creating from DateTime');
  final now = DateTime.now();
  final zonedNow = TomZonedDateTime.fromDateTime(now);
  final observableNow = TomOZonedDateTime(zonedNow);

  print('   DateTime.now(): $now');
  print('   TomZonedDateTime: ${~observableNow}');

  // --- Sentinel/default values ---
  print('\n12. Sentinel (default) values');
  print('   TomOZonedTime.noTime: ${TomOZonedTime.noTime}');
  print('   TomOZonedDate.noTime: ${TomOZonedDate.noTime}');
  print('   TomOZonedDateTime.noTime: ${TomOZonedDateTime.noTime}');

  print('\n=== All assertions passed! ===');
}
