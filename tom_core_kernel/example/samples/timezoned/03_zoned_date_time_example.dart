/// TomZonedDate and TomZonedTime Example
///
/// This example demonstrates the separate date-only and time-only classes:
/// - TomZonedDate for date values without time components
/// - TomZonedTime for time values without date components
/// - Differences from TomZonedDateTime
/// - Serialization prefixes
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// ============================================================================
// Example Class
// ============================================================================

class ZonedDateTimeExample {
  // Captured results
  static late TomZonedDate tokyoDate;
  static late TomZonedTime lunchTime;

  // -------------------------------------------------------------------------
  // Example 1: Creating TomZonedDate
  // -------------------------------------------------------------------------
  static void example1CreateDate() {
    print('1. Creating TomZonedDate (date-only):');

    final tokyo = TomTimezone.fromName('Asia/Tokyo')!;

    tokyoDate = TomZonedDate(year: 2024, month: 12, day: 25, timezone: tokyo);

    print('   - Timezone: ${tokyoDate.timezone.timezone}');
    print(
      '   - Local date: ${tokyoDate.localYear}-${tokyoDate.localMonth.toString().padLeft(2, '0')}-${tokyoDate.localDay.toString().padLeft(2, '0')}',
    );
    print(
      '   - Local time components: ${tokyoDate.localHour}:${tokyoDate.localMinute}:${tokyoDate.localSecond}',
    );
    print('   - Serialization prefix: "${tokyoDate.getSerializationPrefix()}"');

    // Assertions
    assert(tokyoDate.localYear == 2024, 'Year should be 2024');
    assert(tokyoDate.localMonth == 12, 'Month should be 12');
    assert(tokyoDate.localDay == 25, 'Day should be 25');
    assert(
      tokyoDate.getSerializationPrefix() == '@D@',
      'TomZonedDate prefix should be @D@',
    );
  }

  // -------------------------------------------------------------------------
  // Example 2: Date-only checks
  // -------------------------------------------------------------------------
  static void example2DateOnlyChecks() {
    print('\n2. Checking if values are date-only:');

    // TomZonedDate time components should be zero in local time
    final hasTimeComponent =
        tokyoDate.localHour != 0 ||
        tokyoDate.localMinute != 0 ||
        tokyoDate.localSecond != 0;

    print('   - Date has time component: $hasTimeComponent');

    // Check using isDate static method. It reads whatever frame the DateTime
    // carries, so to ask it about a TomZonedDate pass `value.toDateTime()` —
    // see example 5.
    final dateOnly = DateTime(2024, 6, 15, 0, 0, 0);
    final withTime = DateTime(2024, 6, 15, 14, 30, 0);

    print(
      '   - DateTime(2024,6,15,0,0,0) isDate: ${TomZonedDate.isDate(dateOnly)}',
    );
    print(
      '   - DateTime(2024,6,15,14,30,0) isDate: ${TomZonedDate.isDate(withTime)}',
    );

    // Assertions
    assert(
      TomZonedDate.isDate(dateOnly) == true,
      'Midnight should be date-only',
    );
    assert(TomZonedDate.isDate(withTime) == false, 'Has time component');
  }

  // -------------------------------------------------------------------------
  // Example 3: Creating TomZonedTime
  // -------------------------------------------------------------------------
  static void example3CreateTime() {
    print('\n3. Creating TomZonedTime (time-only):');

    final newYork = TomTimezone.fromName('America/New_York')!;

    lunchTime = TomZonedTime(
      hour: 12,
      minute: 30,
      second: 0,
      timezone: newYork,
    );

    print('   - Timezone: ${lunchTime.timezone.timezone}');
    print(
      '   - Local time: ${lunchTime.localHour}:${lunchTime.localMinute.toString().padLeft(2, '0')}:${lunchTime.localSecond.toString().padLeft(2, '0')}',
    );
    print(
      '   - Local date: ${lunchTime.localYear}-${lunchTime.localMonth}-${lunchTime.localDay}',
    );
    print('   - Serialization prefix: "${lunchTime.getSerializationPrefix()}"');

    // Assertions
    assert(lunchTime.localHour == 12, 'Hour should be 12');
    assert(lunchTime.localMinute == 30, 'Minute should be 30');
    assert(
      lunchTime.getSerializationPrefix() == '@T@',
      'TomZonedTime prefix should be @T@',
    );
  }

  // -------------------------------------------------------------------------
  // Example 4: TomZonedTime base date (epoch)
  // -------------------------------------------------------------------------
  static void example4TimeBaseDate() {
    print('\n4. TomZonedTime base date (epoch):');

    final utcTime = TomZonedTime(
      hour: 10,
      minute: 0,
      timezone: TomTimezone.utc,
    );

    print('   - Time-only values use epoch date (1970-01-01) internally');
    print(
      '   - UTC components: ${utcTime.year}-${utcTime.month}-${utcTime.day}',
    );
    print('   - UTC time: ${utcTime.hour}:${utcTime.minute}');

    // Assertions
    assert(utcTime.year == 1970, 'Base year should be 1970');
    assert(utcTime.month == 1, 'Base month should be 1');
    assert(utcTime.day == 1, 'Base day should be 1');
  }

  // -------------------------------------------------------------------------
  // Example 5: Creating from DateTime
  // -------------------------------------------------------------------------
  static void example5FromDateTime() {
    print('\n5. Creating from DateTime:');

    final london = TomTimezone.fromName('Europe/London')!;
    // Carries a time of day, which a date-only value has no room for.
    final existingDate = DateTime.utc(2024, 7, 14, 9, 20, 30);

    final zonedDate = TomZonedDate.fromDateTime(existingDate, london);

    print('   - Original DateTime: $existingDate');
    print(
      '   - As TomZonedDate: ${zonedDate.localYear}-${zonedDate.localMonth}-${zonedDate.localDay}',
    );
    print('   - Time of day dropped: ${zonedDate.localHour}:00');
    print('   - Timezone: ${zonedDate.timezone.timezone}');

    // For time
    final existingTime = DateTime.utc(2024, 7, 14, 15, 45, 30);
    final zonedTime = TomZonedTime.fromDateTime(existingTime, london);

    print('   - Original time DateTime: $existingTime');
    print(
      '   - As TomZonedTime: ${zonedTime.localHour}:${zonedTime.localMinute}:${zonedTime.localSecond}',
    );
    print('   - Date re-anchored to: ${zonedTime.localYear}');

    // Assertions
    assert(
      zonedDate.timezone.timezone == 'Europe/London',
      'Timezone should be London',
    );
    // Each factory establishes its own type's anchoring rather than copying
    // whatever the incoming DateTime happened to carry.
    assert(zonedDate.localHour == 0, 'A date is anchored to local midnight');
    assert(
      TomZonedDate.isDate(zonedDate.toDateTime()),
      'A date must satisfy its own predicate in its own timezone',
    );
    // 15:45:30 UTC reads as 16:45:30 in London during BST.
    assert(zonedTime.localHour == 16, 'A time keeps the local clock reading');
    assert(zonedTime.localYear == 1970, 'A time is anchored to the epoch');
    assert(
      TomZonedTime.isTime(zonedTime.toDateTime()),
      'A time must satisfy its own predicate in its own timezone',
    );
  }

  // -------------------------------------------------------------------------
  // Example 6: Timezone conversion for date/time
  // -------------------------------------------------------------------------
  static void example6TimezoneConversion() {
    print('\n6. Timezone conversion for date/time:');

    final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
    final losAngeles = TomTimezone.fromName('America/Los_Angeles')!;

    // Date conversion
    final tokyoChristmas = TomZonedDate(
      year: 2024,
      month: 12,
      day: 25,
      timezone: tokyo,
    );

    final laChristmas = tokyoChristmas.convertToTimezone(losAngeles);

    print(
      '   - Tokyo date: ${tokyoChristmas.localYear}-${tokyoChristmas.localMonth}-${tokyoChristmas.localDay}',
    );
    print(
      '   - Same moment in LA: ${laChristmas.localYear}-${laChristmas.localMonth}-${laChristmas.localDay}',
    );
    print('   - (LA is behind Tokyo, so midnight Dec 25 Tokyo = Dec 24 in LA)');

    // Time conversion
    final tokyoTime = TomZonedTime(hour: 10, minute: 0, timezone: tokyo);
    final laTime = tokyoTime.convertToTimezone(losAngeles);

    print(
      '   - Tokyo time: ${tokyoTime.localHour}:${tokyoTime.localMinute.toString().padLeft(2, '0')}',
    );
    print(
      '   - Same moment in LA: ${laTime.localHour}:${laTime.localMinute.toString().padLeft(2, '0')}',
    );

    // Assertions
    assert(
      laChristmas.timezone.timezone == 'America/Los_Angeles',
      'Should be LA timezone',
    );
  }

  // -------------------------------------------------------------------------
  // Example 7: Comparing serialization prefixes
  // -------------------------------------------------------------------------
  static void example7SerializationPrefixes() {
    print('\n7. Comparing serialization prefixes:');

    final tz = TomTimezone.utc;

    final dateTime = TomZonedDateTime(
      year: 2024,
      month: 6,
      day: 15,
      hour: 12,
      timezone: tz,
    );
    final dateOnly = TomZonedDate(year: 2024, month: 6, day: 15, timezone: tz);
    final timeOnly = TomZonedTime(hour: 12, minute: 0, timezone: tz);

    print(
      '   - TomZonedDateTime prefix: "${dateTime.getSerializationPrefix()}" (@X@)',
    );
    print(
      '   - TomZonedDate prefix: "${dateOnly.getSerializationPrefix()}" (@D@)',
    );
    print(
      '   - TomZonedTime prefix: "${timeOnly.getSerializationPrefix()}" (@T@)',
    );

    final dateTimeStr = '${dateTime.getSerializationPrefix()}$dateTime';
    final dateOnlyStr = '${dateOnly.getSerializationPrefix()}$dateOnly';
    final timeOnlyStr = '${timeOnly.getSerializationPrefix()}$timeOnly';

    print('   - Full serialized DateTime: $dateTimeStr');
    print('   - Full serialized Date: $dateOnlyStr');
    print('   - Full serialized Time: $timeOnlyStr');

    // Assertions
    assert(
      dateTime.getSerializationPrefix() == '@X@',
      'DateTime prefix should be @X@',
    );
    assert(
      dateOnly.getSerializationPrefix() == '@D@',
      'Date prefix should be @D@',
    );
    assert(
      timeOnly.getSerializationPrefix() == '@T@',
      'Time prefix should be @T@',
    );
  }

  // -------------------------------------------------------------------------
  // Example 8: Creating zoned types from current time
  // -------------------------------------------------------------------------
  static void example8NowFactories() {
    print('\n8. Creating zoned types from current time:');

    final berlin = TomTimezone.fromName('Europe/Berlin')!;
    final now = DateTime.now();

    // Create zoned types from current DateTime
    final nowDateTime = TomZonedDateTime.fromDateTime(now, berlin);
    final nowDate = TomZonedDate.fromDateTime(now, berlin);
    final nowTime = TomZonedTime.fromDateTime(now, berlin);

    print(
      '   - Current DateTime in Berlin: ${nowDateTime.localHour}:${nowDateTime.localMinute.toString().padLeft(2, '0')}',
    );
    print(
      '   - Current Date in Berlin: ${nowDate.localYear}-${nowDate.localMonth}-${nowDate.localDay}',
    );
    print(
      '   - Current Time in Berlin: ${nowTime.localHour}:${nowTime.localMinute.toString().padLeft(2, '0')}',
    );

    // Assertions
    assert(
      nowDateTime.timezone.timezone == 'Europe/Berlin',
      'Should be Berlin timezone',
    );
    assert(
      nowDate.timezone.timezone == 'Europe/Berlin',
      'Should be Berlin timezone',
    );
    assert(
      nowTime.timezone.timezone == 'Europe/Berlin',
      'Should be Berlin timezone',
    );
    // One instant, three types, three different amounts of it kept.
    assert(nowDate.localHour == 0, 'The date drops the time of day');
    assert(nowTime.localYear == 1970, 'The time drops the date');
    assert(
      nowDateTime.localYear == nowDate.localYear,
      'The full type keeps both, and agrees with the date on the day',
    );
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 03: TomZonedDate and TomZonedTime Example ===\n');

    example1CreateDate();
    example2DateOnlyChecks();
    example3CreateTime();
    example4TimeBaseDate();
    example5FromDateTime();
    example6TimezoneConversion();
    example7SerializationPrefixes();
    example8NowFactories();

    print('\n=== TomZonedDate and TomZonedTime Example Complete ===\n');
  }
}

void run() => ZonedDateTimeExample.run();

void main() {
  requireAsserts();
  run();
}
