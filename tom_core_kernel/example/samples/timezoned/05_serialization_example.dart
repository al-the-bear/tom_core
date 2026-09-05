// ignore_for_file: unused_local_variable
/// Timezoned Serialization Example
///
/// This example demonstrates serialization and parsing of TomTimezoned types:
/// - String format for TomZonedDateTime, TomZonedDate, TomZonedTime
/// - Parsing from serialized strings
/// - Type detection from prefixes
/// - Error handling for invalid strings
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// ============================================================================
// Example Class
// ============================================================================

class SerializationExample {
  // Captured results
  static late String dateTimeSerialized;
  static late String dateSerialized;
  static late String timeSerialized;
  static late TomZonedDateTime parsedDateTime;

  // -------------------------------------------------------------------------
  // Example 1: Serializing TomZonedDateTime
  // -------------------------------------------------------------------------
  static void example1SerializeDateTime() {
    print('1. Serializing TomZonedDateTime:');

    final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
    final dt = TomZonedDateTime(
      year: 2024,
      month: 6,
      day: 15,
      hour: 14,
      minute: 30,
      second: 45,
      millisecond: 123,
      timezone: tokyo,
    );

    // toString() is the complete serialization — it already carries the type
    // prefix, so it round-trips through parseFromString as-is. Do not prepend
    // getSerializationPrefix() to it; that is for building the prefix
    // separately (e.g. to dispatch on type before parsing).
    dateTimeSerialized = dt.toString();

    print('   - Serialized: $dateTimeSerialized');
    print('   - Prefix for this type: ${dt.getSerializationPrefix()}');
    print('   - Format: @X@ISO8601_OFFSET_TIMEZONE');

    // Assertions
    assert(dateTimeSerialized.contains('Z'), 'Should contain UTC marker');
    assert(
      dateTimeSerialized.contains('Asia/Tokyo'),
      'Should contain timezone name',
    );
    assert(
      dateTimeSerialized.startsWith('@X@'),
      'Should start with @X@ prefix',
    );
    assert(dt.getSerializationPrefix() == '@X@', 'Prefix should be @X@');
  }

  // -------------------------------------------------------------------------
  // Example 2: Serializing TomZonedDate
  // -------------------------------------------------------------------------
  static void example2SerializeDate() {
    print('\n2. Serializing TomZonedDate:');

    final newYork = TomTimezone.fromName('America/New_York')!;
    final date = TomZonedDate(
      year: 2024,
      month: 12,
      day: 25,
      timezone: newYork,
    );

    dateSerialized = date.toString();

    print('   - Serialized: $dateSerialized');
    print('   - Prefix for this type: ${date.getSerializationPrefix()}');
    print('   - Format: @D@ISO8601_OFFSET_TIMEZONE');

    // Assertions
    assert(dateSerialized.startsWith('@D@'), 'Should start with @D@ prefix');
    assert(
      dateSerialized.contains('America/New_York'),
      'Should contain timezone name',
    );
  }

  // -------------------------------------------------------------------------
  // Example 3: Serializing TomZonedTime
  // -------------------------------------------------------------------------
  static void example3SerializeTime() {
    print('\n3. Serializing TomZonedTime:');

    final london = TomTimezone.fromName('Europe/London')!;
    final time = TomZonedTime(hour: 9, minute: 30, second: 0, timezone: london);

    timeSerialized = time.toString();

    print('   - Serialized: $timeSerialized');
    print('   - Prefix for this type: ${time.getSerializationPrefix()}');
    print('   - Format: @T@ISO8601_OFFSET_TIMEZONE');

    // Assertions
    assert(timeSerialized.startsWith('@T@'), 'Should start with @T@ prefix');
  }

  // -------------------------------------------------------------------------
  // Example 4: Parsing TomZonedDateTime
  // -------------------------------------------------------------------------
  static void example4ParseDateTime() {
    print('\n4. Parsing TomZonedDateTime:');

    // Parse from the serialized string (with prefix @X@)
    final parseString = '@X@2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo';
    parsedDateTime = TomZonedDateTime.parseFromString(parseString);

    print('   - Input: $parseString');
    print('   - Parsed timezone: ${parsedDateTime.timezone.timezone}');
    print(
      '   - Parsed local time: ${parsedDateTime.localHour}:${parsedDateTime.localMinute}',
    );
    print(
      '   - Parsed UTC time: ${parsedDateTime.hour}:${parsedDateTime.minute}',
    );

    // Assertions
    assert(
      parsedDateTime.timezone.timezone == 'Asia/Tokyo',
      'Timezone should be Tokyo',
    );
    assert(parsedDateTime.hour == 5, 'UTC hour should be 5');
    assert(parsedDateTime.localHour == 14, 'Local hour should be 14 (5 + 9)');
  }

  // -------------------------------------------------------------------------
  // Example 5: Parsing TomZonedDate
  // -------------------------------------------------------------------------
  static void example5ParseDate() {
    print('\n5. Parsing TomZonedDate:');

    // Note: parseFromString expects the @D@ prefix
    final parseString = '@D@2024-12-25T05:00:00.000Z_-05:00_America/New_York';
    final parsedDate = TomZonedDate.parseFromString(parseString);

    print('   - Input: $parseString');
    print('   - Parsed timezone: ${parsedDate.timezone.timezone}');
    print(
      '   - Parsed local date: ${parsedDate.localYear}-${parsedDate.localMonth}-${parsedDate.localDay}',
    );

    // Assertions
    assert(
      parsedDate.timezone.timezone == 'America/New_York',
      'Timezone should be New York',
    );
    assert(parsedDate.localMonth == 12, 'Month should be December');
    assert(parsedDate.localDay == 25, 'Day should be 25');
  }

  // -------------------------------------------------------------------------
  // Example 6: Parsing TomZonedTime
  // -------------------------------------------------------------------------
  static void example6ParseTime() {
    print('\n6. Parsing TomZonedTime:');

    // Note: parseFromString expects the @T@ prefix.
    //
    // A time-only TomZonedTime is anchored to the epoch date 1970-01-01, and
    // parseFromString ignores the offset embedded in the string: it reads the
    // UTC instant and the zone name, and derives the local reading from those
    // two through the IANA database. On 1970-01-01 Europe/London was UTC+1
    // year-round — the 1968–1971 British Standard Time experiment — so 09:30
    // London is UTC 08:30, exactly as the framework serializes it (see
    // example 3). Using the naive `09:30Z / +00:00` would parse back to 10:30
    // local, because the database offset for that instant decides the reading
    // and the embedded one has no say.
    final parseString = '@T@1970-01-01T08:30:00.000Z_+01:00_Europe/London';
    final parsedTime = TomZonedTime.parseFromString(parseString);

    print('   - Input: $parseString');
    print('   - Parsed timezone: ${parsedTime.timezone.timezone}');
    print(
      '   - Parsed local time: ${parsedTime.localHour}:${parsedTime.localMinute}',
    );

    // Assertions
    assert(
      parsedTime.timezone.timezone == 'Europe/London',
      'Timezone should be London',
    );
    assert(parsedTime.localHour == 9, 'Hour should be 9');
    assert(parsedTime.localMinute == 30, 'Minute should be 30');
  }

  // -------------------------------------------------------------------------
  // Example 7: Detecting type from string
  // -------------------------------------------------------------------------
  static void example7TypeDetection() {
    print('\n7. Detecting type from string:');

    final testStrings = [
      '@X@2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo',
      '@D@2024-12-25T05:00:00.000Z_-05:00_America/New_York',
      // 08:30Z / +01:00: the epoch-date London offset (BST experiment), the
      // same valid serialization parsed in example 6.
      '@T@1970-01-01T08:30:00.000Z_+01:00_Europe/London',
      '2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo', // No prefix
    ];

    for (final str in testStrings) {
      final isDateTime = TomZonedDateTime.isTomZonedDateTimeString(str);
      final isDate = TomZonedDate.isTomZonedDateString(str);
      final isTime = TomZonedTime.isTomZonedTimeString(str);
      final isGeneric = TomTimezoned.isTomTimezonedString(str);

      String detected = 'unknown';
      if (str.startsWith('@X@')) {
        detected = 'TomZonedDateTime';
      } else if (str.startsWith('@D@')) {
        detected = 'TomZonedDate';
      } else if (str.startsWith('@T@')) {
        detected = 'TomZonedTime';
      } else if (isGeneric) {
        detected = 'TomTimezoned (no prefix)';
      }

      print('   - ${str.substring(0, 30)}... -> $detected');
    }
  }

  // -------------------------------------------------------------------------
  // Example 8: Round-trip serialization
  // -------------------------------------------------------------------------
  static void example8RoundTrip() {
    print('\n8. Round-trip serialization:');

    final sydney = TomTimezone.fromName('Australia/Sydney')!;
    final original = TomZonedDateTime(
      year: 2024,
      month: 3,
      day: 15,
      hour: 10,
      minute: 45,
      second: 30,
      timezone: sydney,
    );

    // Serialize
    final serialized = original.toString();

    // Parse back
    final restored = TomZonedDateTime.parseFromString(serialized);

    print(
      '   - Original: ${original.localHour}:${original.localMinute}:${original.localSecond} in ${original.timezone.timezone}',
    );
    print('   - Serialized: $serialized');
    print(
      '   - Restored: ${restored.localHour}:${restored.localMinute}:${restored.localSecond} in ${restored.timezone.timezone}',
    );

    // Verify all values match
    final match =
        original.localYear == restored.localYear &&
        original.localMonth == restored.localMonth &&
        original.localDay == restored.localDay &&
        original.localHour == restored.localHour &&
        original.localMinute == restored.localMinute &&
        original.localSecond == restored.localSecond &&
        original.timezone.timezone == restored.timezone.timezone;

    print('   - Perfect round-trip: $match');

    // Assertions
    assert(match, 'Round-trip should preserve all values');
  }

  // -------------------------------------------------------------------------
  // Example 9: Error handling for invalid strings
  // -------------------------------------------------------------------------
  static void example9ErrorHandling() {
    print('\n9. Error handling for invalid strings:');

    final invalidStrings = [
      'not-a-valid-string',
      '2024-06-15', // Missing timezone info
      '2024-06-15T10:30:00Z', // Missing underscore format
    ];

    for (final str in invalidStrings) {
      try {
        TomZonedDateTime.parseFromString(str);
        print('   - "$str" -> Unexpectedly parsed');
      } on FormatException catch (e) {
        print(
          '   - "$str" -> FormatException: ${e.message.substring(0, 30)}...',
        );
      }
    }
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 05: Serialization Example ===\n');

    example1SerializeDateTime();
    example2SerializeDate();
    example3SerializeTime();
    example4ParseDateTime();
    example5ParseDate();
    example6ParseTime();
    example7TypeDetection();
    example8RoundTrip();
    example9ErrorHandling();

    print('\n=== Serialization Example Complete ===\n');
  }
}

void run() => SerializationExample.run();

void main() {
  prepareSampleProcess();
  run();
}
