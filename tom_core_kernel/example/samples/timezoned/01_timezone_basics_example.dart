/// TomTimezone Basics Example
///
/// This example demonstrates the fundamental features of TomTimezone:
/// - Creating timezones by IANA name
/// - Getting UTC offset for timezones
/// - UTC timezone singleton
/// - Finding timezones by offset
/// - Timezone string representation
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Example Class
// ============================================================================

class TimezoneBasicsExample {
  // Captured results
  static TomTimezone? tokyo;
  static TomTimezone? newYork;
  static TomTimezone? london;
  static TomTimezone? utcTimezone;
  static List<TomTimezone>? offsetTimezones;
  static TomTimezone? firstByOffset;

  // -------------------------------------------------------------------------
  // Example 1: Creating timezones by IANA name
  // -------------------------------------------------------------------------
  static void example1CreateByName() {
    print('1. Creating timezones by IANA name:');

    tokyo = TomTimezone.fromName('Asia/Tokyo');
    newYork = TomTimezone.fromName('America/New_York');
    london = TomTimezone.fromName('Europe/London');
    final sydney = TomTimezone.fromName('Australia/Sydney');
    final invalid = TomTimezone.fromName('Invalid/Timezone');

    print('   - Tokyo: ${tokyo?.timezone}');
    print('   - New York: ${newYork?.timezone}');
    print('   - London: ${london?.timezone}');
    print('   - Sydney: ${sydney?.timezone}');
    print('   - Invalid timezone returns: $invalid');

    // Assertions
    assert(tokyo != null, 'Tokyo timezone should be found');
    assert(tokyo!.timezone == 'Asia/Tokyo', 'Tokyo name should match');
    assert(newYork != null, 'New York timezone should be found');
    assert(london != null, 'London timezone should be found');
    assert(invalid == null, 'Invalid timezone should return null');
  }

  // -------------------------------------------------------------------------
  // Example 2: UTC timezone singleton
  // -------------------------------------------------------------------------
  static void example2UtcSingleton() {
    print('\n2. UTC timezone singleton:');

    utcTimezone = TomTimezone.utc;

    print('   - UTC timezone: ${utcTimezone!.timezone}');
    print('   - UTC offset: ${utcTimezone!.timezoneOffsetMin} minutes');
    print('   - Same instance: ${TomTimezone.utc == utcTimezone}');

    // Assertions
    assert(utcTimezone!.timezone == 'UTC', 'UTC timezone name should be UTC');
    assert(utcTimezone!.timezoneOffsetMin == 0, 'UTC offset should be 0');
    assert(TomTimezone.utc == utcTimezone, 'UTC should be singleton');
  }

  // -------------------------------------------------------------------------
  // Example 3: Getting current UTC offset
  // -------------------------------------------------------------------------
  static void example3CurrentOffset() {
    print('\n3. Getting current UTC offset:');

    final tokyoOffset = tokyo!.timezoneOffsetMin;
    final utcOffset = TomTimezone.utc.timezoneOffsetMin;

    print(
      '   - Tokyo current offset: $tokyoOffset minutes (${tokyoOffset ~/ 60} hours)',
    );
    print('   - UTC current offset: $utcOffset minutes');
    print(
      '   - New York current offset: ${newYork!.timezoneOffsetMin} minutes',
    );

    // Assertions
    assert(tokyoOffset == 540, 'Tokyo should be UTC+9 (540 minutes)');
    assert(utcOffset == 0, 'UTC should have 0 offset');
    // New York varies by DST, so just check it's negative
    assert(
      newYork!.timezoneOffsetMin < 0,
      'New York should have negative offset',
    );
  }

  // -------------------------------------------------------------------------
  // Example 4: Getting offset at specific dates (DST awareness)
  // -------------------------------------------------------------------------
  static void example4OffsetAtSpecificDate() {
    print('\n4. Getting offset at specific dates (DST awareness):');

    final winterDate = DateTime.utc(2024, 1, 15);
    final summerDate = DateTime.utc(2024, 7, 15);

    final nyWinterOffset = newYork!.getUtcOffsetOn(winterDate);
    final nySummerOffset = newYork!.getUtcOffsetOn(summerDate);
    final tokyoWinter = tokyo!.getUtcOffsetOn(winterDate);
    final tokyoSummer = tokyo!.getUtcOffsetOn(summerDate);

    print(
      '   - New York winter (Jan 15): $nyWinterOffset minutes (${newYork!.getUtcOffsetStringOn(winterDate)})',
    );
    print(
      '   - New York summer (Jul 15): $nySummerOffset minutes (${newYork!.getUtcOffsetStringOn(summerDate)})',
    );
    print('   - Tokyo winter: $tokyoWinter minutes (no DST)');
    print('   - Tokyo summer: $tokyoSummer minutes (no DST)');

    // Assertions
    assert(
      nyWinterOffset == -300,
      'NY winter should be EST (-5:00 = -300 minutes)',
    );
    assert(
      nySummerOffset == -240,
      'NY summer should be EDT (-4:00 = -240 minutes)',
    );
    assert(tokyoWinter == 540, 'Tokyo has no DST');
    assert(tokyoSummer == 540, 'Tokyo has no DST');
  }

  // -------------------------------------------------------------------------
  // Example 5: Finding timezones by offset
  // -------------------------------------------------------------------------
  static void example5FindByOffset() {
    print('\n5. Finding timezones by offset:');

    // Find first timezone with UTC+9 offset (540 minutes)
    firstByOffset = TomTimezone.firstWithOffset(540);
    print('   - First with +09:00: ${firstByOffset?.timezone}');

    // Find all timezones with UTC+0 offset
    offsetTimezones = TomTimezone.allWithOffset(0);
    print(
      '   - All with +00:00: ${offsetTimezones?.take(5).map((t) => t.timezone).join(', ')}...',
    );
    print('   - Total +00:00 timezones: ${offsetTimezones?.length}');

    // Find timezone with UTC-5 offset (EST)
    final estTimezone = TomTimezone.firstWithOffset(-300);
    print('   - First with -05:00: ${estTimezone?.timezone}');

    // Assertions
    assert(firstByOffset != null, 'Should find timezone with +09:00');
    assert(
      offsetTimezones != null && offsetTimezones!.isNotEmpty,
      'Should find timezones with +00:00',
    );
  }

  // -------------------------------------------------------------------------
  // Example 6: Timezone string representation
  // -------------------------------------------------------------------------
  static void example6StringRepresentation() {
    print('\n6. Timezone string representation:');

    final winterDate = DateTime.utc(2024, 1, 15);
    final summerDate = DateTime.utc(2024, 7, 15);

    final tokyoStr = tokyo!.toString();
    final nyWinterStr = newYork!.toStringOn(winterDate);
    final nySummerStr = newYork!.toStringOn(summerDate);

    print('   - Tokyo (current): $tokyoStr');
    print('   - New York (winter): $nyWinterStr');
    print('   - New York (summer): $nySummerStr');

    // Assertions
    assert(
      tokyoStr.contains('Asia/Tokyo'),
      'Tokyo string should contain timezone name',
    );
    assert(nyWinterStr.contains('-05:00'), 'NY winter should show EST offset');
    assert(nySummerStr.contains('-04:00'), 'NY summer should show EDT offset');
  }

  // -------------------------------------------------------------------------
  // Example 7: Access all available timezones
  // -------------------------------------------------------------------------
  static void example7AllTimezones() {
    print('\n7. Accessing all available timezones:');

    final allTimezones = TomTimezone.timezones;

    print('   - Total timezones: ${allTimezones.length}');
    print(
      '   - Contains EUROPE/LONDON: ${allTimezones.containsKey('EUROPE/LONDON')}',
    );
    print(
      '   - Contains ASIA/TOKYO: ${allTimezones.containsKey('ASIA/TOKYO')}',
    );

    // Sample some timezone names
    final sampleNames = allTimezones.keys.take(5).toList();
    print('   - Sample names: ${sampleNames.join(', ')}');

    // Assertions
    assert(allTimezones.length > 100, 'Should have many timezones');
    assert(allTimezones.containsKey('UTC'), 'Should contain UTC');
  }

  // -------------------------------------------------------------------------
  // Example 8: Convert DateTime to TZDateTime
  // -------------------------------------------------------------------------
  static void example8ToTZDateTime() {
    print('\n8. Converting DateTime to TZDateTime:');

    final utcNow = DateTime.utc(2024, 6, 15, 12, 0, 0);
    final tokyoTz = tokyo!.toTZDateTime(utcNow);

    print('   - UTC time: $utcNow');
    print('   - As TZDateTime in Tokyo: $tokyoTz');
    print('   - Tokyo local hour: ${tokyoTz.hour}');

    // Get current time in timezone
    final nowInTokyo = tokyo!.now();
    print('   - Current time in Tokyo: $nowInTokyo');

    // Assertions
    assert(
      tokyoTz.hour == 21,
      'Tokyo should be UTC+9, so 12:00 UTC = 21:00 Tokyo',
    );
    assert(tokyoTz.day == 15, 'Same day in Tokyo');
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 01: Timezone Basics Example ===\n');

    example1CreateByName();
    example2UtcSingleton();
    example3CurrentOffset();
    example4OffsetAtSpecificDate();
    example5FindByOffset();
    example6StringRepresentation();
    example7AllTimezones();
    example8ToTZDateTime();

    print('\n=== Timezone Basics Example Complete ===\n');
  }
}

void run() => TimezoneBasicsExample.run();

void main() => run();
