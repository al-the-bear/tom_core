/// Timezone Conversion Example
///
/// This example demonstrates timezone conversion operations:
/// - Converting between timezones (same moment, different representation)
/// - Understanding UTC storage model
/// - Working with DST transitions
/// - Practical use cases like meeting scheduling
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/timezoned/04_timezone_conversion_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// ============================================================================
// Example Class
// ============================================================================

class TimezoneConversionExample {
  // Captured results
  static late TomZonedDateTime tokyoMeeting;
  static late TomZonedDateTime nyMeeting;
  static late TomZonedDateTime londonMeeting;

  // -------------------------------------------------------------------------
  // Example 1: Basic timezone conversion
  // -------------------------------------------------------------------------
  static void example1BasicConversion() {
    print('1. Basic timezone conversion:');

    final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
    final newYork = TomTimezone.fromName('America/New_York')!;
    final london = TomTimezone.fromName('Europe/London')!;

    // Create a meeting at 3 PM Tokyo time
    tokyoMeeting = TomZonedDateTime(
      year: 2024,
      month: 6,
      day: 15,
      hour: 15,
      minute: 0,
      timezone: tokyo,
    );

    // Convert to other timezones
    nyMeeting = tokyoMeeting.convertToTimezone(newYork);
    londonMeeting = tokyoMeeting.convertToTimezone(london);

    print('   - Meeting scheduled at:');
    print(
      '   - Tokyo: ${tokyoMeeting.localHour}:${tokyoMeeting.localMinute.toString().padLeft(2, '0')} (${tokyoMeeting.localMonth}/${tokyoMeeting.localDay})',
    );
    print(
      '   - New York: ${nyMeeting.localHour}:${nyMeeting.localMinute.toString().padLeft(2, '0')} (${nyMeeting.localMonth}/${nyMeeting.localDay})',
    );
    print(
      '   - London: ${londonMeeting.localHour}:${londonMeeting.localMinute.toString().padLeft(2, '0')} (${londonMeeting.localMonth}/${londonMeeting.localDay})',
    );

    // All represent the same UTC moment
    print('   - Same UTC time? ${tokyoMeeting.toUtc() == nyMeeting.toUtc()}');

    // Assertions
    assert(tokyoMeeting.localHour == 15, 'Tokyo should be 15:00');
    // Tokyo is UTC+9, NY is UTC-4 in summer, so 15:00 Tokyo = 02:00 NY
    assert(nyMeeting.localHour == 2, 'NY should be 02:00');
    // London is UTC+1 in summer, so 15:00 Tokyo = 07:00 London
    assert(londonMeeting.localHour == 7, 'London should be 07:00');
  }

  // -------------------------------------------------------------------------
  // Example 2: Understanding UTC storage
  // -------------------------------------------------------------------------
  static void example2UtcStorage() {
    print('\n2. Understanding UTC storage:');

    final berlin = TomTimezone.fromName('Europe/Berlin')!;

    // Create a time during summer (CEST = UTC+2)
    final summerTime = TomZonedDateTime(
      year: 2024,
      month: 7,
      day: 15,
      hour: 14,
      minute: 30,
      timezone: berlin,
    );

    print(
      '   - Berlin local time: ${summerTime.localHour}:${summerTime.localMinute}',
    );
    print('   - Stored UTC time: ${summerTime.hour}:${summerTime.minute}');
    print(
      '   - Difference: Berlin is UTC+${(summerTime.localHour - summerTime.hour)} in summer',
    );

    // Create a time during winter (CET = UTC+1)
    final winterTime = TomZonedDateTime(
      year: 2024,
      month: 1,
      day: 15,
      hour: 14,
      minute: 30,
      timezone: berlin,
    );

    print(
      '   - Berlin winter local time: ${winterTime.localHour}:${winterTime.localMinute}',
    );
    print('   - Stored UTC time: ${winterTime.hour}:${winterTime.minute}');
    print(
      '   - Difference: Berlin is UTC+${(winterTime.localHour - winterTime.hour)} in winter',
    );

    // Assertions
    assert(summerTime.hour == 12, 'Summer: 14:30 Berlin = 12:30 UTC');
    assert(winterTime.hour == 13, 'Winter: 14:30 Berlin = 13:30 UTC');
  }

  // -------------------------------------------------------------------------
  // Example 3: Converting UTC to multiple timezones
  // -------------------------------------------------------------------------
  static void example3UtcToMultiple() {
    print('\n3. Converting UTC to multiple timezones:');

    // Start with a UTC time
    final utcEvent = TomZonedDateTime(
      year: 2024,
      month: 9,
      day: 1,
      hour: 12,
      minute: 0,
      timezone: TomTimezone.utc,
    );

    final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
    final sydney = TomTimezone.fromName('Australia/Sydney')!;
    final losAngeles = TomTimezone.fromName('America/Los_Angeles')!;
    final sao = TomTimezone.fromName('America/Sao_Paulo')!;

    print('   - UTC: ${utcEvent.localHour}:00 on Sept 1');
    print('   - Tokyo: ${utcEvent.convertToTimezone(tokyo).localHour}:00');
    print('   - Sydney: ${utcEvent.convertToTimezone(sydney).localHour}:00');
    print(
      '   - Los Angeles: ${utcEvent.convertToTimezone(losAngeles).localHour}:00 on ${utcEvent.convertToTimezone(losAngeles).localMonth}/${utcEvent.convertToTimezone(losAngeles).localDay}',
    );
    print('   - São Paulo: ${utcEvent.convertToTimezone(sao).localHour}:00');

    // Assertions
    assert(utcEvent.convertToTimezone(tokyo).localHour == 21, 'Tokyo is UTC+9');
  }

  // -------------------------------------------------------------------------
  // Example 4: Date line crossing
  // -------------------------------------------------------------------------
  static void example4DateLineCrossing() {
    print('\n4. Date line crossing:');

    final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
    final honolulu = TomTimezone.fromName('Pacific/Honolulu')!;

    // Late night in Tokyo on Jan 1
    final tokyoNewYear = TomZonedDateTime(
      year: 2025,
      month: 1,
      day: 1,
      hour: 2,
      minute: 0,
      timezone: tokyo,
    );

    final honoluluTime = tokyoNewYear.convertToTimezone(honolulu);

    print(
      '   - Tokyo: ${tokyoNewYear.localYear}-${tokyoNewYear.localMonth.toString().padLeft(2, '0')}-${tokyoNewYear.localDay.toString().padLeft(2, '0')} ${tokyoNewYear.localHour}:00',
    );
    print(
      '   - Honolulu: ${honoluluTime.localYear}-${honoluluTime.localMonth.toString().padLeft(2, '0')}-${honoluluTime.localDay.toString().padLeft(2, '0')} ${honoluluTime.localHour}:00',
    );
    print('   - Honolulu is still in the previous year!');

    // Tokyo is UTC+9, Honolulu is UTC-10
    // 2:00 Tokyo = 17:00 UTC Dec 31 = 7:00 Honolulu Dec 31
    // Assertions
    assert(honoluluTime.localYear == 2024, 'Honolulu should still be 2024');
    assert(honoluluTime.localMonth == 12, 'Honolulu should be December');
    assert(honoluluTime.localDay == 31, 'Honolulu should be Dec 31');
  }

  // -------------------------------------------------------------------------
  // Example 5: Practical example - scheduling across timezones
  // -------------------------------------------------------------------------
  static void example5SchedulingExample() {
    print('\n5. Practical example - scheduling across timezones:');

    final sanFrancisco = TomTimezone.fromName('America/Los_Angeles')!;
    final bangalore = TomTimezone.fromName('Asia/Kolkata')!;
    final dublin = TomTimezone.fromName('Europe/Dublin')!;

    // Schedule a meeting at 9 AM San Francisco time
    final meeting = TomZonedDateTime(
      year: 2024,
      month: 8,
      day: 15,
      hour: 9,
      minute: 0,
      timezone: sanFrancisco,
    );

    final bangaloreMeeting = meeting.convertToTimezone(bangalore);
    final dublinMeeting = meeting.convertToTimezone(dublin);

    print('   - Standup meeting scheduled:');
    print('   - San Francisco: ${meeting.localHour}:00 (local working hours)');
    print(
      '   - Bangalore: ${bangaloreMeeting.localHour}:${bangaloreMeeting.localMinute.toString().padLeft(2, '0')} (${bangaloreMeeting.localHour < 12
          ? "morning"
          : bangaloreMeeting.localHour < 18
          ? "afternoon"
          : "evening"})',
    );
    print(
      '   - Dublin: ${dublinMeeting.localHour}:00 (${dublinMeeting.localHour < 12
          ? "morning"
          : dublinMeeting.localHour < 18
          ? "afternoon"
          : "evening"})',
    );

    // Check if it's reasonable hours for everyone
    final sfOk = meeting.localHour >= 9 && meeting.localHour <= 17;
    final bangaloreOk =
        bangaloreMeeting.localHour >= 9 && bangaloreMeeting.localHour <= 22;
    final dublinOk =
        dublinMeeting.localHour >= 9 && dublinMeeting.localHour <= 17;

    print(
      '   - Reasonable hours? SF: $sfOk, Bangalore: $bangaloreOk, Dublin: $dublinOk',
    );

    // Assertions
    assert(sfOk, 'SF should be during work hours');
  }

  // -------------------------------------------------------------------------
  // Example 6: Round-trip conversion
  // -------------------------------------------------------------------------
  static void example6RoundTrip() {
    print('\n6. Round-trip conversion:');

    final paris = TomTimezone.fromName('Europe/Paris')!;
    final singapore = TomTimezone.fromName('Asia/Singapore')!;

    final originalTime = TomZonedDateTime(
      year: 2024,
      month: 4,
      day: 20,
      hour: 16,
      minute: 45,
      timezone: paris,
    );

    // Convert to Singapore
    final singaporeTime = originalTime.convertToTimezone(singapore);

    // Convert back to Paris
    final backToParis = singaporeTime.convertToTimezone(paris);

    print(
      '   - Original Paris time: ${originalTime.localHour}:${originalTime.localMinute}',
    );
    print(
      '   - In Singapore: ${singaporeTime.localHour}:${singaporeTime.localMinute}',
    );
    print(
      '   - Back to Paris: ${backToParis.localHour}:${backToParis.localMinute}',
    );
    print(
      '   - Values preserved: ${originalTime.localHour == backToParis.localHour && originalTime.localMinute == backToParis.localMinute}',
    );

    // Assertions
    assert(
      originalTime.localHour == backToParis.localHour,
      'Hour should be preserved',
    );
    assert(
      originalTime.localMinute == backToParis.localMinute,
      'Minute should be preserved',
    );
    assert(
      originalTime.localDay == backToParis.localDay,
      'Day should be preserved',
    );
  }

  // -------------------------------------------------------------------------
  // Example 7: Converting to UTC and back
  // -------------------------------------------------------------------------
  static void example7ToUtcAndBack() {
    print('\n7. Converting to UTC and back:');

    final cairo = TomTimezone.fromName('Africa/Cairo')!;

    final cairoTime = TomZonedDateTime(
      year: 2024,
      month: 10,
      day: 5,
      hour: 18,
      minute: 30,
      timezone: cairo,
    );

    // Convert to UTC
    final utcTime = cairoTime.convertToTimezone(TomTimezone.utc);

    // Convert back to Cairo
    final backToCairo = utcTime.convertToTimezone(cairo);

    print('   - Cairo time: ${cairoTime.localHour}:${cairoTime.localMinute}');
    print('   - As UTC: ${utcTime.localHour}:${utcTime.localMinute}');
    print(
      '   - Back to Cairo: ${backToCairo.localHour}:${backToCairo.localMinute}',
    );

    // Assertions
    assert(
      cairoTime.localHour == backToCairo.localHour,
      'Should be same after round-trip',
    );
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 04: Timezone Conversion Example ===\n');

    example1BasicConversion();
    example2UtcStorage();
    example3UtcToMultiple();
    example4DateLineCrossing();
    example5SchedulingExample();
    example6RoundTrip();
    example7ToUtcAndBack();

    print('\n=== Timezone Conversion Example Complete ===\n');
  }
}

void run() => TimezoneConversionExample.run();

void main() {
  prepareSampleProcess();
  run();
}
