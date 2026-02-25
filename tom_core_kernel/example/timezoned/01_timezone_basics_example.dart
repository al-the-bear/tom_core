// ignore_for_file: unused_local_variable, unnecessary_non_null_assertion, unnecessary_null_comparison
/// Timezone Basics Example
///
/// This example demonstrates the fundamental concepts of the TomTimezone
/// class: creating timezones, getting UTC offsets, and understanding
/// how timezones work with the underlying timezone package.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Example Code
// ============================================================================

void run() {
  print('=== 01: Timezone Basics Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Creating timezones by name
  // -------------------------------------------------------------------------
  print('1. Creating timezones by IANA name:');
  
  final tokyo = TomTimezone.fromName('Asia/Tokyo');
  final newYork = TomTimezone.fromName('America/New_York');
  final london = TomTimezone.fromName('Europe/London');
  final utc = TomTimezone.utc;
  
  print('   Created timezones:');
  print('   - Tokyo: ${tokyo?.timezone}');
  print('   - New York: ${newYork?.timezone}');
  print('   - London: ${london?.timezone}');
  print('   - UTC: ${utc.timezone}\n');

  // -------------------------------------------------------------------------
  // Example 2: Getting UTC offsets
  // -------------------------------------------------------------------------
  print('2. Getting UTC offsets:');
  
  // Use fixed dates instead of DateTime.now() for deterministic results
  final winterDate = DateTime.utc(2024, 1, 15);
  final summerDate = DateTime.utc(2024, 6, 15);
  
  final tokyoWinterOffset = tokyo?.getUtcOffsetStringOn(winterDate);
  final nyWinterOffset = newYork?.getUtcOffsetStringOn(winterDate);
  final londonWinterOffset = london?.getUtcOffsetStringOn(winterDate);
  final utcWinterOffset = utc.getUtcOffsetStringOn(winterDate);
  
  print('   Winter offsets (January 15, 2024):');
  print('   - Tokyo: $tokyoWinterOffset');
  print('   - New York: $nyWinterOffset');
  print('   - London: $londonWinterOffset');
  print('   - UTC: $utcWinterOffset\n');

  // -------------------------------------------------------------------------
  // Example 3: Understanding offset in minutes
  // -------------------------------------------------------------------------
  print('3. Offset in minutes:');
  
  final tokyoOffsetMinutes = tokyo?.getUtcOffsetOn(winterDate) ?? 0;
  final nyOffsetMinutes = newYork?.getUtcOffsetOn(winterDate) ?? 0;
  final tokyoOffsetHours = tokyoOffsetMinutes ~/ 60;
  final nyOffsetHours = nyOffsetMinutes ~/ 60;
  final diffHours = (tokyoOffsetMinutes - nyOffsetMinutes) ~/ 60;
  
  print('   Tokyo offset: $tokyoOffsetHours hours ($tokyoOffsetMinutes minutes)');
  print('   New York offset: $nyOffsetHours hours ($nyOffsetMinutes minutes)');
  print('   Difference: $diffHours hours\n');

  // -------------------------------------------------------------------------
  // Example 4: String representation
  // -------------------------------------------------------------------------
  print('4. String representations (at winter date):');
  
  final tokyoString = tokyo?.toStringOn(winterDate);
  final newYorkString = newYork?.toStringOn(winterDate);
  final utcString = utc.toStringOn(winterDate);
  
  print('   tokyo.toStringOn(winter): $tokyoString');
  print('   newYork.toStringOn(winter): $newYorkString');
  print('   utc.toStringOn(winter): $utcString\n');

  // -------------------------------------------------------------------------
  // Example 5: Getting time in a timezone using TZDateTime
  // -------------------------------------------------------------------------
  print('5. Converting UTC time to different timezones:');
  
  final utcTime = DateTime.utc(2024, 6, 15, 12, 0); // Noon UTC
  final tokyoTz = tokyo!.toTZDateTime(utcTime);
  final newYorkTz = newYork!.toTZDateTime(utcTime);
  final utcTz = utc.toTZDateTime(utcTime);
  
  final tokyoHour = tokyoTz.hour;
  final newYorkHour = newYorkTz.hour;
  final utcHour = utcTz.hour;
  
  print('   UTC noon (12:00):');
  print('   - Tokyo: $tokyoHour:00');
  print('   - New York: $newYorkHour:00');
  print('   - UTC: $utcHour:00\n');

  // -------------------------------------------------------------------------
  // Example 6: Error handling
  // -------------------------------------------------------------------------
  print('6. Handling invalid timezones:');
  
  final invalid = TomTimezone.fromName('Invalid/Timezone');
  print('   TomTimezone.fromName("Invalid/Timezone"): ${invalid == null ? "null (not found)" : invalid.timezone}');

  print('\n');

  // =========================================================================
  // Assertions
  // =========================================================================
  
  // Example 1: Timezone creation
  assert(tokyo != null);
  assert(newYork != null);
  assert(london != null);
  assert(tokyo!.timezone == 'Asia/Tokyo');
  assert(newYork!.timezone == 'America/New_York');
  assert(london!.timezone == 'Europe/London');
  assert(utc.timezone == 'UTC');
  
  // Example 2: UTC offset strings
  assert(tokyoWinterOffset == '+09:00');
  assert(nyWinterOffset == '-05:00'); // EST in winter
  assert(londonWinterOffset == 'Z'); // GMT in winter (Z is used for +00:00)
  assert(utcWinterOffset == 'Z');
  
  // Example 3: Offset in minutes
  assert(tokyoOffsetMinutes == 540); // +9 hours = 540 minutes
  assert(nyOffsetMinutes == -300); // -5 hours = -300 minutes (EST)
  assert(tokyoOffsetHours == 9);
  assert(nyOffsetHours == -5);
  assert(diffHours == 14); // Tokyo is 14 hours ahead of NY in winter
  
  // Example 4: String representation
  assert(tokyoString == '+09:00_Asia/Tokyo');
  assert(newYorkString == '-05:00_America/New_York');
  assert(utcString == 'Z_UTC');
  
  // Example 5: TZDateTime conversion
  assert(tokyoHour == 21); // 12 UTC + 9 = 21:00 Tokyo
  assert(newYorkHour == 8); // 12 UTC - 4 = 8:00 (EDT in June)
  assert(utcHour == 12);
  
  // Example 6: Invalid timezone
  assert(invalid == null);
}
