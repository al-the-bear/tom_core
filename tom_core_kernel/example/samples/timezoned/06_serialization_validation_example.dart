/// Serialization Example
///
/// This example demonstrates the serialization and parsing capabilities
/// of TomTimezoned types. It shows the string format, how to serialize
/// to strings, and how to parse strings back to objects.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Example Code
// ============================================================================

void run() {
  print('=== 06: Serialization Validation Example ===\n');

  final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
  final newYork = TomTimezone.fromName('America/New_York')!;

  // -------------------------------------------------------------------------
  // Example 1: Understanding the string format
  // -------------------------------------------------------------------------
  print('1. Understanding the serialization format:');
  print('   Format: {PREFIX}ISO8601_OFFSET_TIMEZONE\n');
  
  final dt = TomZonedDateTime(
    year: 2024, month: 6, day: 15,
    hour: 14, minute: 30, second: 0,
    timezone: tokyo,
  );
  
  final serialized = dt.toString();
  print('   Example: $serialized');
  print('   - Prefix: @X@ (TomZonedDateTime)');
  print('   - ISO8601: 2024-06-15T05:30:00.000Z (UTC time)');
  print('   - Offset: +09:00 (Tokyo offset)');
  print('   - Timezone: Asia/Tokyo (IANA name)\n');

  // -------------------------------------------------------------------------
  // Example 2: Serializing different types
  // -------------------------------------------------------------------------
  print('2. Serializing different types:');
  
  final dateTime = TomZonedDateTime(
    year: 2024, month: 6, day: 15, hour: 14, minute: 30,
    timezone: tokyo,
  );
  final date = TomZonedDate(
    year: 2024, month: 6, day: 15,
    timezone: tokyo,
  );
  final time = TomZonedTime(
    hour: 14, minute: 30,
    timezone: tokyo,
  );
  
  final dateTimeSerialized = dateTime.toString();
  final dateSerialized = date.toString();
  final timeSerialized = time.toString();
  
  print('   TomZonedDateTime: $dateTimeSerialized');
  print('   TomZonedDate:     $dateSerialized');
  print('   TomZonedTime:     $timeSerialized\n');

  // -------------------------------------------------------------------------
  // Example 3: Parsing strings back to objects
  // -------------------------------------------------------------------------
  print('3. Parsing strings back to objects:');
  
  final dtString = '@X@2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo';
  final parsedDt = TomZonedDateTime.parseFromString(dtString);
  
  final parsedUtcYear = parsedDt.year;
  final parsedUtcMonth = parsedDt.month;
  final parsedUtcDay = parsedDt.day;
  final parsedUtcHour = parsedDt.hour;
  final parsedLocalHour = parsedDt.localHour;
  final parsedTimezone = parsedDt.timezone.timezone;
  
  print('   Input: $dtString');
  print('   Parsed (UTC values stored):');
  print('   - Year (UTC): $parsedUtcYear');
  print('   - Month (UTC): $parsedUtcMonth');
  print('   - Day (UTC): $parsedUtcDay');
  print('   - Hour (UTC): $parsedUtcHour');
  print('   - Hour (local): $parsedLocalHour');
  print('   - Timezone: $parsedTimezone\n');

  // -------------------------------------------------------------------------
  // Example 4: Validating string formats
  // -------------------------------------------------------------------------
  print('4. Validating string formats:');
  
  final validDateTime = '@X@2024-06-15T14:30:00.000Z_+09:00_Asia/Tokyo';
  final validDate = '@D@2024-06-15T00:00:00.000Z_+09:00_Asia/Tokyo';
  final validTime = '@T@1970-01-01T14:30:00.000Z_+09:00_Asia/Tokyo';
  final invalidFormat = '2024-06-15T14:30:00';
  
  final isValidDateTime = TomZonedDateTime.isTomZonedDateTimeString(validDateTime);
  final isValidDate = TomZonedDate.isTomZonedDateString(validDate);
  final isValidTime = TomZonedTime.isTomZonedTimeString(validTime);
  final isInvalidDateTime = TomZonedDateTime.isTomZonedDateTimeString(invalidFormat);
  
  print('   isTomZonedDateTimeString("$validDateTime"):');
  print('     $isValidDateTime');
  
  print('   isTomZonedDateString("$validDate"):');
  print('     $isValidDate');
  
  print('   isTomZonedTimeString("$validTime"):');
  print('     $isValidTime');
  
  print('   isTomZonedDateTimeString("$invalidFormat"):');
  print('     $isInvalidDateTime\n');

  // -------------------------------------------------------------------------
  // Example 5: Safe parsing pattern
  // -------------------------------------------------------------------------
  print('5. Safe parsing pattern:');
  
  TomZonedDateTime? safeParse(String input) {
    if (TomZonedDateTime.isTomZonedDateTimeString(input)) {
      try {
        return TomZonedDateTime.parseFromString(input);
      } on FormatException {
        return null;
      }
    }
    return null;
  }
  
  final safeResult1 = safeParse(validDateTime);
  final safeResult2 = safeParse(invalidFormat);
  
  print('   safeParse("$validDateTime"):');
  print('     ${safeResult1 != null ? "Success" : "Failed"}');
  
  print('   safeParse("$invalidFormat"):');
  print('     ${safeResult2 != null ? "Success" : "Failed"}\n');

  // -------------------------------------------------------------------------
  // Example 6: Error handling for invalid formats
  // -------------------------------------------------------------------------
  print('6. Error handling for invalid formats:');
  
  var caughtException = false;
  try {
    TomZonedDateTime.parseFromString('invalid-format');
    print('   ERROR: Should have thrown exception');
  } on FormatException catch (e) {
    caughtException = true;
    print('   Caught FormatException: ${e.message}');
  }

  // -------------------------------------------------------------------------
  // Example 7: UTC serialization
  // -------------------------------------------------------------------------
  print('\n7. UTC serialization:');
  
  final utcDateTime = TomZonedDateTime(
    year: 2024, month: 6, day: 15, hour: 12,
    timezone: TomTimezone.utc,
  );
  
  final utcSerialized = utcDateTime.toString();
  
  print('   UTC DateTime: $utcSerialized');
  print('   Note: Offset is "Z" for UTC\n');

  // -------------------------------------------------------------------------
  // Example 8: Round-trip serialization
  // -------------------------------------------------------------------------
  print('8. Round-trip serialization:');
  
  final original = TomZonedDateTime(
    year: 2024, month: 12, day: 31,
    hour: 23, minute: 59, second: 59,
    millisecond: 999,
    timezone: newYork,
  );
  
  final stringForm = original.toString();
  final restored = TomZonedDateTime.parseFromString(stringForm);
  
  final originalLocal = '${original.localYear}-${original.localMonth}-${original.localDay} ${original.localHour}:${original.localMinute}';
  final restoredLocal = '${restored.localYear}-${restored.localMonth}-${restored.localDay} ${restored.localHour}:${restored.localMinute}';
  final timezonePreserved = original.timezone.timezone == restored.timezone.timezone;
  
  print('   Original (local): $originalLocal');
  print('   Serialized: $stringForm');
  print('   Restored (local): $restoredLocal');
  print('   Timezone preserved: $timezonePreserved\n');

  // =========================================================================
  // Assertions
  // =========================================================================
  
  // Example 1: Serialization format
  assert(serialized.startsWith('@X@'));
  assert(serialized.contains('2024-06-15T05:30:00.000Z'));
  assert(serialized.contains('+09:00'));
  assert(serialized.contains('Asia/Tokyo'));
  
  // Example 2: Different types serialization
  assert(dateTimeSerialized.startsWith('@X@'));
  assert(dateSerialized.startsWith('@D@'));
  assert(timeSerialized.startsWith('@T@'));
  
  // Example 3: Parsing
  assert(parsedUtcYear == 2024);
  assert(parsedUtcMonth == 6);
  assert(parsedUtcDay == 15);
  assert(parsedUtcHour == 5);
  assert(parsedLocalHour == 14);
  assert(parsedTimezone == 'Asia/Tokyo');
  
  // Example 4: Format validation
  assert(isValidDateTime == true);
  assert(isValidDate == true);
  assert(isValidTime == true);
  assert(isInvalidDateTime == false);
  
  // Example 5: Safe parsing
  assert(safeResult1 != null);
  assert(safeResult2 == null);
  
  // Example 6: Exception handling
  assert(caughtException == true);
  
  // Example 7: UTC serialization
  assert(utcSerialized.contains('_Z_UTC'));
  
  // Example 8: Round-trip
  assert(originalLocal == restoredLocal);
  assert(timezonePreserved == true);
  assert(original.millisecondsSinceEpoch == restored.millisecondsSinceEpoch);
}
