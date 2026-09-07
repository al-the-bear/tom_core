/// TomZonedDateTime Example
///
/// This example demonstrates the TomZonedDateTime class for full
/// date and time values with timezone awareness:
/// - Creating TomZonedDateTime instances
/// - Accessing UTC and local time components
/// - Converting from DateTime
/// - Using the now() factory
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/timezoned/02_zoned_datetime_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// ============================================================================
// Example Class
// ============================================================================

class ZonedDateTimeExample {
  // Captured results
  static late TomZonedDateTime tokyoMeeting;
  static late TomZonedDateTime utcTime;
  static late TomZonedDateTime fromDateTime;

  // -------------------------------------------------------------------------
  // Example 1: Creating TomZonedDateTime with local time components
  // -------------------------------------------------------------------------
  static void example1CreateWithComponents() {
    print('1. Creating TomZonedDateTime with local time components:');

    final tokyo = TomTimezone.fromName('Asia/Tokyo')!;

    // Create a meeting at 2:30 PM Tokyo time
    tokyoMeeting = TomZonedDateTime(
      year: 2024,
      month: 6,
      day: 15,
      hour: 14,
      minute: 30,
      second: 45,
      timezone: tokyo,
    );

    print('   - Timezone: ${tokyoMeeting.timezone.timezone}');
    print(
      '   - Local time: ${tokyoMeeting.localYear}-${tokyoMeeting.localMonth.toString().padLeft(2, '0')}-${tokyoMeeting.localDay.toString().padLeft(2, '0')} ${tokyoMeeting.localHour}:${tokyoMeeting.localMinute.toString().padLeft(2, '0')}:${tokyoMeeting.localSecond.toString().padLeft(2, '0')}',
    );
    print(
      '   - UTC time: ${tokyoMeeting.year}-${tokyoMeeting.month.toString().padLeft(2, '0')}-${tokyoMeeting.day.toString().padLeft(2, '0')} ${tokyoMeeting.hour}:${tokyoMeeting.minute.toString().padLeft(2, '0')}:${tokyoMeeting.second.toString().padLeft(2, '0')}',
    );
    print('   - isUtc: ${tokyoMeeting.isUtc}');

    // Assertions
    assert(tokyoMeeting.localHour == 14, 'Local hour should be 14');
    assert(tokyoMeeting.localMinute == 30, 'Local minute should be 30');
    assert(tokyoMeeting.hour == 5, 'UTC hour should be 5 (14 - 9 = 5)');
    assert(tokyoMeeting.isUtc == true, 'Should be stored as UTC');
  }

  // -------------------------------------------------------------------------
  // Example 2: Creating TomZonedDateTime in UTC
  // -------------------------------------------------------------------------
  static void example2CreateUtc() {
    print('\n2. Creating TomZonedDateTime in UTC:');

    utcTime = TomZonedDateTime(
      year: 2024,
      month: 12,
      day: 31,
      hour: 23,
      minute: 59,
      second: 59,
      timezone: TomTimezone.utc,
    );

    print('   - Timezone: ${utcTime.timezone.timezone}');
    print(
      '   - Local/UTC time: ${utcTime.localYear}-${utcTime.localMonth}-${utcTime.localDay} ${utcTime.localHour}:${utcTime.localMinute}:${utcTime.localSecond}',
    );
    print('   - For UTC, local and UTC values are the same');

    // Assertions
    assert(
      utcTime.localHour == utcTime.hour,
      'For UTC, local and UTC hour should match',
    );
    assert(
      utcTime.localDay == utcTime.day,
      'For UTC, local and UTC day should match',
    );
    assert(utcTime.timezone == TomTimezone.utc, 'Timezone should be UTC');
  }

  // -------------------------------------------------------------------------
  // Example 3: Creating from existing DateTime
  // -------------------------------------------------------------------------
  static void example3FromDateTime() {
    print('\n3. Creating from existing DateTime:');

    final existingDateTime = DateTime.utc(2024, 3, 15, 10, 30, 0);
    final london = TomTimezone.fromName('Europe/London')!;

    fromDateTime = TomZonedDateTime.fromDateTime(existingDateTime, london);

    print('   - Original DateTime: $existingDateTime');
    print('   - Associated timezone: ${fromDateTime.timezone.timezone}');
    print(
      '   - UTC components: ${fromDateTime.year}-${fromDateTime.month}-${fromDateTime.day} ${fromDateTime.hour}:${fromDateTime.minute}',
    );
    print(
      '   - Local components: ${fromDateTime.localYear}-${fromDateTime.localMonth}-${fromDateTime.localDay} ${fromDateTime.localHour}:${fromDateTime.localMinute}',
    );

    // March is before BST starts, so London is at UTC+0
    // Assertions
    assert(
      fromDateTime.hour == existingDateTime.hour,
      'UTC hour should match original',
    );
    assert(
      fromDateTime.timezone.timezone == 'Europe/London',
      'Timezone should be London',
    );
  }

  // -------------------------------------------------------------------------
  // Example 4: Creating zoned datetime from current time
  // -------------------------------------------------------------------------
  static void example4Now() {
    print('\n4. Creating zoned datetime from current time:');

    final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
    final now = DateTime.now();
    final nowInTokyo = TomZonedDateTime.fromDateTime(now, tokyo);
    final nowInUtc = TomZonedDateTime.fromDateTime(now, TomTimezone.utc);

    print(
      '   - Now in Tokyo: ${nowInTokyo.localHour}:${nowInTokyo.localMinute.toString().padLeft(2, '0')}',
    );
    print(
      '   - Now in UTC: ${nowInUtc.localHour}:${nowInUtc.localMinute.toString().padLeft(2, '0')}',
    );
    print('   - Both represent the same instant');
    print(
      '   - Tokyo UTC offset: ${nowInTokyo.timezone.timezoneOffsetMin} minutes',
    );

    // Assertions
    assert(nowInTokyo.isUtc == true, 'Should be stored as UTC');
    assert(
      nowInTokyo.timezone.timezone == 'Asia/Tokyo',
      'Timezone should be Tokyo',
    );
  }

  // -------------------------------------------------------------------------
  // Example 5: Accessing all local time components
  // -------------------------------------------------------------------------
  static void example5LocalComponents() {
    print('\n5. Accessing all local time components:');

    final newYork = TomTimezone.fromName('America/New_York')!;
    final dt = TomZonedDateTime(
      year: 2024,
      month: 7,
      day: 4,
      hour: 15,
      minute: 30,
      second: 45,
      millisecond: 123,
      microsecond: 456,
      timezone: newYork,
    );

    print('   - localYear: ${dt.localYear}');
    print('   - localMonth: ${dt.localMonth}');
    print('   - localDay: ${dt.localDay}');
    print('   - localHour: ${dt.localHour}');
    print('   - localMinute: ${dt.localMinute}');
    print('   - localSecond: ${dt.localSecond}');
    print('   - localMillisecond: ${dt.localMillisecond}');
    print('   - localMicrosecond: ${dt.localMicrosecond}');
    print(
      '   - localWeekday: ${dt.localWeekday} (${_weekdayName(dt.localWeekday)})',
    );

    // July 4, 2024 is a Thursday (weekday = 4)
    // Assertions
    assert(dt.localYear == 2024, 'Local year should be 2024');
    assert(dt.localMonth == 7, 'Local month should be 7 (July)');
    assert(dt.localDay == 4, 'Local day should be 4');
    assert(dt.localWeekday == 4, 'July 4, 2024 should be Thursday');
  }

  // -------------------------------------------------------------------------
  // Example 6: Comparing UTC and local accessors
  // -------------------------------------------------------------------------
  static void example6UtcVsLocal() {
    print('\n6. Comparing UTC and local accessors:');

    final sydney = TomTimezone.fromName('Australia/Sydney')!;

    // Create a time just before midnight local time
    // Sydney is UTC+10 (or +11 during daylight saving)
    final lateNight = TomZonedDateTime(
      year: 2024,
      month: 1,
      day: 15,
      hour: 23,
      minute: 30,
      timezone: sydney,
    );

    print(
      '   - Local: ${lateNight.localYear}-${lateNight.localMonth.toString().padLeft(2, '0')}-${lateNight.localDay.toString().padLeft(2, '0')} ${lateNight.localHour}:${lateNight.localMinute.toString().padLeft(2, '0')}',
    );
    print(
      '   - UTC: ${lateNight.year}-${lateNight.month.toString().padLeft(2, '0')}-${lateNight.day.toString().padLeft(2, '0')} ${lateNight.hour}:${lateNight.minute.toString().padLeft(2, '0')}',
    );
    print(
      '   - UTC is ${sydney.getUtcOffsetOn(lateNight) ~/ 60} hours behind local',
    );

    // Sydney in January is on AEDT (UTC+11), so 23:30 local = 12:30 UTC same day
    // Assertions
    assert(lateNight.localHour == 23, 'Local hour should be 23');
    assert(lateNight.localDay == 15, 'Local day should be 15');
  }

  // -------------------------------------------------------------------------
  // Example 7: Converting to DateTime
  // -------------------------------------------------------------------------
  static void example7ToDateTime() {
    print('\n7. Converting to DateTime:');

    final berlin = TomTimezone.fromName('Europe/Berlin')!;
    final dt = TomZonedDateTime(
      year: 2024,
      month: 8,
      day: 20,
      hour: 18,
      minute: 45,
      timezone: berlin,
    );

    final regularDateTime = dt.toDateTime();
    final isoString = dt.toIso8601String();

    print('   - TomZonedDateTime: $dt');
    print('   - As DateTime: $regularDateTime');
    print('   - ISO 8601: $isoString');
    print('   - DateTime.isUtc: ${regularDateTime.isUtc}');

    // Assertions
    assert(regularDateTime.isUtc == false, 'toDateTime returns local DateTime');
    assert(isoString.endsWith('Z'), 'ISO 8601 should end with Z for UTC');
  }

  // -------------------------------------------------------------------------
  // Example 8: Serialization prefix
  // -------------------------------------------------------------------------
  static void example8SerializationPrefix() {
    print('\n8. Serialization prefix:');

    final dt = TomZonedDateTime(
      year: 2024,
      month: 5,
      day: 10,
      hour: 9,
      minute: 0,
      timezone: TomTimezone.utc,
    );

    // toString() already carries the prefix, so it is the whole serialized
    // form. getSerializationPrefix() names that prefix for a caller who needs
    // to recognise a type from a stored string; prepending it to the rendering
    // would double the prefix into something no parseFromString accepts.
    final serialized = dt.toString();

    print('   - Prefix: "${dt.getSerializationPrefix()}"');
    print('   - Full serialized: $serialized');

    // Assertions
    assert(
      dt.getSerializationPrefix() == '@X@',
      'TomZonedDateTime prefix should be @X@',
    );
    assert(
      serialized.startsWith(dt.getSerializationPrefix()),
      'The rendering already carries the prefix',
    );
    assert(
      TomZonedDateTime.isTomZonedDateTimeString(serialized),
      'What is printed must be a string the parser accepts',
    );
  }

  // Helper function
  static String _weekdayName(int weekday) {
    const names = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[weekday];
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 02: TomZonedDateTime Example ===\n');

    example1CreateWithComponents();
    example2CreateUtc();
    example3FromDateTime();
    example4Now();
    example5LocalComponents();
    example6UtcVsLocal();
    example7ToDateTime();
    example8SerializationPrefix();

    print('\n=== TomZonedDateTime Example Complete ===\n');
  }
}

void run() => ZonedDateTimeExample.run();

void main() {
  prepareSampleProcess();
  run();
}
