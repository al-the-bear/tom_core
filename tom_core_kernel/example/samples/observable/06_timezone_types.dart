/// Observable Timezone Types Example
///
/// This example demonstrates the timezone-aware observable types:
/// - TomOZonedDate, TomOZonedTime, TomOZonedDateTime
/// - Nullable variants: TomNOZonedDate, TomNOZonedTime, TomNOZonedDateTime
/// - Serialization with prefixes (@D@, @T@, @X@)
/// - Range types: TomDateRange, TomTimeRange, TomDateTimeRange
/// - Using setByString for deserialization
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_bootstrap.dart';

// ============================================================================
// Example Class
// ============================================================================

class TimezoneTypesExample {
  // Captured results
  static late TomOZonedDate observableBirthday;
  static late TomOZonedTime observableMeetingTime;
  static late TomOZonedDateTime observableEvent;

  // -------------------------------------------------------------------------
  // Example 1: Creating TomOZonedDate
  // -------------------------------------------------------------------------
  static void example1ZonedDate() {
    print('1. Creating TomOZonedDate:');

    final birthday = TomZonedDate(
      year: 1990,
      month: 5,
      day: 15,
      timezone: TomTimezone.utc,
    );
    observableBirthday = TomOZonedDate(birthday);

    print('   birthday: ${~observableBirthday}');
    print('   year: ${(~observableBirthday).localYear}');
    print('   month: ${(~observableBirthday).localMonth}');
    print('   day: ${(~observableBirthday).localDay}');
    print('   Serialization prefix: ${observableBirthday.getSerializationPrefix()}');

    // Assertions
    assert((~observableBirthday).localYear == 1990, 'Year should be 1990');
    assert((~observableBirthday).localMonth == 5, 'Month should be 5');
    assert((~observableBirthday).localDay == 15, 'Day should be 15');
    assert(observableBirthday.getSerializationPrefix() == '@D@', 'Prefix should be @D@');
  }

  // -------------------------------------------------------------------------
  // Example 2: Creating TomOZonedTime
  // -------------------------------------------------------------------------
  static void example2ZonedTime() {
    print('\n2. Creating TomOZonedTime:');

    final meetingTime = TomZonedTime(
      hour: 14,
      minute: 30,
      second: 0,
      timezone: TomTimezone.utc,
    );
    observableMeetingTime = TomOZonedTime(meetingTime);

    print('   meetingTime: ${~observableMeetingTime}');
    print('   hour: ${(~observableMeetingTime).localHour}');
    print('   minute: ${(~observableMeetingTime).localMinute}');
    print('   Serialization prefix: ${observableMeetingTime.getSerializationPrefix()}');

    // Assertions
    assert((~observableMeetingTime).localHour == 14, 'Hour should be 14');
    assert((~observableMeetingTime).localMinute == 30, 'Minute should be 30');
    assert(observableMeetingTime.getSerializationPrefix() == '@T@', 'Prefix should be @T@');
  }

  // -------------------------------------------------------------------------
  // Example 3: Creating TomOZonedDateTime
  // -------------------------------------------------------------------------
  static void example3ZonedDateTime() {
    print('\n3. Creating TomOZonedDateTime:');

    final eventDateTime = TomZonedDateTime(
      year: 2024,
      month: 12,
      day: 25,
      hour: 18,
      minute: 0,
      second: 0,
      timezone: TomTimezone.utc,
    );
    observableEvent = TomOZonedDateTime(eventDateTime);

    print('   eventDateTime: ${~observableEvent}');
    print('   year: ${(~observableEvent).localYear}');
    print('   month: ${(~observableEvent).localMonth}');
    print('   hour: ${(~observableEvent).localHour}');
    print('   Serialization prefix: ${observableEvent.getSerializationPrefix()}');

    // Assertions
    assert((~observableEvent).localYear == 2024, 'Year should be 2024');
    assert((~observableEvent).localMonth == 12, 'Month should be 12');
    assert((~observableEvent).localHour == 18, 'Hour should be 18');
    assert(observableEvent.getSerializationPrefix() == '@X@', 'Prefix should be @X@');
  }

  // -------------------------------------------------------------------------
  // Example 4: Observing changes
  // -------------------------------------------------------------------------
  static void example4ObservingChanges() {
    print('\n4. Observing timezone-aware observable changes:');

    final appointment = TomOZonedDateTime(
      TomZonedDateTime.fromDateTime(DateTime.utc(2024, 1, 10, 9, 0)),
    );
    int notifyCount = 0;

    // Retain the returned observer. TomObservable holds its observers by
    // WeakReference, so the wrapper `>>` hands back is the only strong
    // reference keeping the callback alive; discard it and notifications stop
    // at the next garbage collection, silently and nondeterministically.
    final appointmentObserver = appointment >> (obs) {
      notifyCount++;
      print('   Appointment changed! (notification #$notifyCount)');
    };

    // Change the value
    appointment | TomZonedDateTime.fromDateTime(DateTime.utc(2024, 1, 11, 10, 0));
    print('   New appointment: ${~appointment}');

    // Assertions
    assert(notifyCount == 1, 'Should notify on change');

    appointment.removeObserver(appointmentObserver);
  }

  // -------------------------------------------------------------------------
  // Example 5: Nullable timezone types
  // -------------------------------------------------------------------------
  static void example5NullableTypes() {
    print('\n5. Nullable timezone types:');

    final optionalDate = TomNOZonedDate(null);
    final optionalTime = TomNOZonedTime(null);
    final optionalDateTime = TomNOZonedDateTime(null);

    print('   optionalDate.isNull: ${optionalDate.isNull}');
    print('   optionalTime.isNull: ${optionalTime.isNull}');
    print('   optionalDateTime.isNull: ${optionalDateTime.isNull}');

    // Set values
    optionalDate | TomZonedDate.fromDateTime(DateTime.utc(2024, 6, 1));
    optionalTime | TomZonedTime.fromDateTime(DateTime.utc(2024, 1, 1, 12, 30));
    optionalDateTime | TomZonedDateTime.fromDateTime(DateTime.utc(2024, 3, 15, 14, 0));

    print('   After setting optionalDate: ${(~optionalDate)?.localYear}-${(~optionalDate)?.localMonth}-${(~optionalDate)?.localDay}');
    print('   After setting optionalTime: ${(~optionalTime)?.localHour}:${(~optionalTime)?.localMinute}');
    print('   After setting optionalDateTime: ${~optionalDateTime}');

    // Assertions
    assert(!optionalDate.isNull, 'Optional date should not be null after set');
    assert(!optionalTime.isNull, 'Optional time should not be null after set');
    assert(!optionalDateTime.isNull, 'Optional datetime should not be null after set');
  }

  // -------------------------------------------------------------------------
  // Example 6: TomDateRange
  // -------------------------------------------------------------------------
  static void example6DateRange() {
    print('\n6. TomDateRange:');

    final vacation = TomDateRange();
    int rangeNotifyCount = 0;

    final vacationObserver = vacation >> (obs) {
      rangeNotifyCount++;
    };

    vacation.startDate | TomZonedDate.fromDateTime(DateTime.utc(2024, 7, 1));
    vacation.endDate | TomZonedDate.fromDateTime(DateTime.utc(2024, 7, 14));

    print('   Vacation start: ${(~vacation.startDate)?.localYear}-${(~vacation.startDate)?.localMonth}-${(~vacation.startDate)?.localDay}');
    print('   Vacation end: ${(~vacation.endDate)?.localYear}-${(~vacation.endDate)?.localMonth}-${(~vacation.endDate)?.localDay}');
    print('   Range notifications: $rangeNotifyCount');

    // Assertions
    // One notification per endpoint set. `>= 1` passed even if setting the end
    // date notified nobody, which is half the behaviour a range should have.
    assert(rangeNotifyCount == 2, 'Each endpoint should notify once');
    assert((~vacation.startDate)?.localDay == 1, 'Start date should be July 1');
    assert((~vacation.endDate)?.localDay == 14, 'End date should be July 14');

    vacation.removeObserver(vacationObserver);
  }

  // -------------------------------------------------------------------------
  // Example 7: TomTimeRange
  // -------------------------------------------------------------------------
  static void example7TimeRange() {
    print('\n7. TomTimeRange:');

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

    print('   Work hours start: ${(~workHours.startTime)?.localHour}:${(~workHours.startTime)?.localMinute.toString().padLeft(2, '0')}');
    print('   Work hours end: ${(~workHours.endTime)?.localHour}:${(~workHours.endTime)?.localMinute.toString().padLeft(2, '0')}');

    // Assertions
    assert((~workHours.startTime)?.localHour == 9, 'Start hour should be 9');
    assert((~workHours.endTime)?.localHour == 17, 'End hour should be 17');
  }

  // -------------------------------------------------------------------------
  // Example 8: TomDateTimeRange
  // -------------------------------------------------------------------------
  static void example8DateTimeRange() {
    print('\n8. TomDateTimeRange:');

    final event = TomDateTimeRange();

    // Explicit UTC instants. This range straddles a year boundary, so a
    // wall-clock local DateTime would be the worst possible choice here:
    // fromDateTime stores the *absolute instant* and localYear reads it back in
    // the attached zone (UTC), so on a host east of UTC+2 the end instant falls
    // back into 2024, and west of UTC-4 the start instant moves up into 2025.
    event.startDateTime | TomZonedDateTime.fromDateTime(DateTime.utc(2024, 12, 31, 20, 0));
    event.endDateTime | TomZonedDateTime.fromDateTime(DateTime.utc(2025, 1, 1, 2, 0));

    print('   Event start: ${~event.startDateTime}');
    print('   Event end: ${~event.endDateTime}');

    // Assertions
    assert((~event.startDateTime)?.localYear == 2024, 'Start year should be 2024');
    assert((~event.endDateTime)?.localYear == 2025, 'End year should be 2025');
  }

  // -------------------------------------------------------------------------
  // Example 9: setByString for deserialization
  // -------------------------------------------------------------------------
  static void example9SetByString() {
    print('\n9. setByString for deserialization:');

    final deserializedDate = TomOZonedDate(TomZonedDate.fromDateTime(DateTime.utc(1970)));

    // Create a serialized string
    final originalDate = TomZonedDate(
      year: 2024,
      month: 3,
      day: 20,
      timezone: TomTimezone.utc,
    );
    final serialized = originalDate.toString();
    print('   Serialized date: $serialized');

    // Deserialize using setByString
    deserializedDate.setByString(serialized);

    print('   Deserialized year: ${(~deserializedDate).localYear}');
    print('   Deserialized month: ${(~deserializedDate).localMonth}');
    print('   Deserialized day: ${(~deserializedDate).localDay}');

    // Assertions
    assert((~deserializedDate).localYear == 2024, 'Deserialized year should be 2024');
    assert((~deserializedDate).localMonth == 3, 'Deserialized month should be 3');
    assert((~deserializedDate).localDay == 20, 'Deserialized day should be 20');
  }

  // -------------------------------------------------------------------------
  // Example 10: Creating from DateTime
  // -------------------------------------------------------------------------
  static void example10FromDateTime() {
    print('\n10. Creating from DateTime:');

    // Use an explicit UTC DateTime. TomZonedDateTime.fromDateTime converts the
    // DateTime's *absolute instant* to UTC, and localHour reports the hour in
    // the attached zone (UTC here). A wall-clock local DateTime would make the
    // stored instant — and therefore localHour — depend on the host machine's
    // timezone, so a UTC DateTime keeps this example deterministic everywhere.
    final dateTime = DateTime.utc(2024, 6, 15, 14, 30);
    final zonedDateTime = TomZonedDateTime.fromDateTime(dateTime);
    final observableDateTime = TomOZonedDateTime(zonedDateTime);

    print('   Original DateTime: $dateTime');
    print('   As TomOZonedDateTime: ${~observableDateTime}');
    print('   Local hour: ${(~observableDateTime).localHour}');

    // With specific timezone
    final tokyo = TomTimezone.fromName('Asia/Tokyo');
    if (tokyo != null) {
      final tokyoZoned = TomZonedDateTime.fromDateTime(dateTime, tokyo);
      final observableTokyo = TomOZonedDateTime(tokyoZoned);
      print('   With Tokyo timezone: ${(~observableTokyo).timezone.timezone}');
    }

    // Assertions
    assert((~observableDateTime).localHour == 14, 'Hour should be 14');
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 06: Observable Timezone Types Example ===\n');

    example1ZonedDate();
    example2ZonedTime();
    example3ZonedDateTime();
    example4ObservingChanges();
    example5NullableTypes();
    example6DateRange();
    example7TimeRange();
    example8DateTimeRange();
    example9SetByString();
    example10FromDateTime();

    print('\n=== Observable Timezone Types Example Complete ===\n');
  }
}

void run() => TimezoneTypesExample.run();

void main() {
  bootstrapSamples();
  run();
}
