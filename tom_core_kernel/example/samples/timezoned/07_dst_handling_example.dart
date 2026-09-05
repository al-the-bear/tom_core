/// DST Handling Example
///
/// This example demonstrates how TomTimezone handles Daylight Saving Time
/// (DST) transitions. It shows how offsets change across DST boundaries
/// and how to work with timezones that observe DST.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// ============================================================================
// Example Code
// ============================================================================

void run() {
  print('=== 07: DST Handling Example ===\n');

  final newYork = TomTimezone.fromName('America/New_York')!;
  final london = TomTimezone.fromName('Europe/London')!;
  final tokyo = TomTimezone.fromName('Asia/Tokyo')!;

  // -------------------------------------------------------------------------
  // Example 1: DST vs Non-DST timezones
  // -------------------------------------------------------------------------
  print('1. DST vs Non-DST timezones:');

  // Tokyo does NOT observe DST
  final tokyoSummer = DateTime.utc(2024, 6, 15, 12, 0);
  final tokyoWinter = DateTime.utc(2024, 1, 15, 12, 0);

  final tokyoSummerOffset = tokyo.getUtcOffsetStringOn(tokyoSummer);
  final tokyoWinterOffset = tokyo.getUtcOffsetStringOn(tokyoWinter);

  print('   Tokyo (no DST):');
  print('   - Summer offset: $tokyoSummerOffset');
  print('   - Winter offset: $tokyoWinterOffset');
  print('   - Same offset year-round!\n');

  // New York DOES observe DST
  final nySummer = DateTime.utc(2024, 6, 15, 12, 0);
  final nyWinter = DateTime.utc(2024, 1, 15, 12, 0);

  final nySummerOffset = newYork.getUtcOffsetStringOn(nySummer);
  final nyWinterOffset = newYork.getUtcOffsetStringOn(nyWinter);

  print('   New York (with DST):');
  print('   - Summer offset (EDT): $nySummerOffset');
  print('   - Winter offset (EST): $nyWinterOffset');
  print('   - 1 hour difference!\n');

  // -------------------------------------------------------------------------
  // Example 2: US DST transition dates (2024)
  // -------------------------------------------------------------------------
  print('2. US DST transition dates (2024):');
  print('   Spring Forward: March 10, 2024 at 2:00 AM');
  print('   Fall Back: November 3, 2024 at 2:00 AM\n');

  // Before spring forward
  final beforeSpring = DateTime.utc(2024, 3, 10, 6, 30); // 1:30 AM EST
  // After spring forward
  final afterSpring = DateTime.utc(2024, 3, 10, 7, 30); // 3:30 AM EDT

  final beforeSpringOffset = newYork.getUtcOffsetStringOn(beforeSpring);
  final afterSpringOffset = newYork.getUtcOffsetStringOn(afterSpring);

  print('   Before transition (6:30 UTC):');
  print('   - Offset: $beforeSpringOffset (EST)');

  print('   After transition (7:30 UTC):');
  print('   - Offset: $afterSpringOffset (EDT)\n');

  // -------------------------------------------------------------------------
  // Example 3: European DST (different dates)
  // -------------------------------------------------------------------------
  print('3. European DST (different dates than US):');
  print('   Spring Forward: March 31, 2024 at 1:00 AM UTC');
  print('   Fall Back: October 27, 2024 at 1:00 AM UTC\n');

  // London in summer vs winter
  final londonSummer = DateTime.utc(2024, 6, 15, 12, 0);
  final londonWinter = DateTime.utc(2024, 1, 15, 12, 0);

  final londonSummerOffset = london.getUtcOffsetStringOn(londonSummer);
  final londonWinterOffset = london.getUtcOffsetStringOn(londonWinter);

  print('   London:');
  print('   - Summer offset (BST): $londonSummerOffset');
  print('   - Winter offset (GMT): $londonWinterOffset');
  print('   - GMT is zero offset, and a zero offset renders as "Z"');
  print('     (the ISO 8601 UTC designator), not "+00:00". London is the');
  print('     one common DST zone where this shows up.\n');

  // -------------------------------------------------------------------------
  // Example 4: Creating TomZonedDateTime across DST
  // -------------------------------------------------------------------------
  print('4. TomZonedDateTime with DST awareness:');

  final summerMeeting = TomZonedDateTime(
    year: 2024,
    month: 6,
    day: 15,
    hour: 14,
    minute: 0,
    timezone: newYork,
  );

  final winterMeeting = TomZonedDateTime(
    year: 2024,
    month: 1,
    day: 15,
    hour: 14,
    minute: 0,
    timezone: newYork,
  );

  final summerMeetingSerialized = summerMeeting.toString();
  final winterMeetingSerialized = winterMeeting.toString();

  print('   Summer meeting:');
  print('   - Serialized: $summerMeetingSerialized');
  print('   - Note the -04:00 offset (EDT)');

  print('   Winter meeting:');
  print('   - Serialized: $winterMeetingSerialized');
  print('   - Note the -05:00 offset (EST)\n');

  // -------------------------------------------------------------------------
  // Example 5: Converting times across DST boundaries
  // -------------------------------------------------------------------------
  print('5. Same UTC time, different local times:');

  final utcTime = DateTime.utc(2024, 6, 15, 18, 0); // 6 PM UTC
  final utcZoned = TomZonedDateTime.fromDateTime(utcTime, TomTimezone.utc);

  print('   UTC: ${utcTime.hour}:${utcTime.minute.toString().padLeft(2, '0')}');

  // Convert using convertToTimezone method
  final inNy = utcZoned.convertToTimezone(newYork);
  final nyLocalHour = inNy.localHour;
  final nyLocalMinute = inNy.localMinute;
  print(
    '   New York (EDT): $nyLocalHour:${nyLocalMinute.toString().padLeft(2, '0')}',
  );

  final inLondon = utcZoned.convertToTimezone(london);
  final londonLocalHour = inLondon.localHour;
  final londonLocalMinute = inLondon.localMinute;
  print(
    '   London (BST): $londonLocalHour:${londonLocalMinute.toString().padLeft(2, '0')}',
  );

  final inTokyo = utcZoned.convertToTimezone(tokyo);
  final tokyoLocalHour = inTokyo.localHour;
  final tokyoLocalMinute = inTokyo.localMinute;
  print(
    '   Tokyo (JST): $tokyoLocalHour:${tokyoLocalMinute.toString().padLeft(2, '0')}\n',
  );

  // -------------------------------------------------------------------------
  // Example 6: Finding timezones by current offset
  // -------------------------------------------------------------------------
  print('6. Finding timezones by offset (DST affects results):');

  // Current offset of -240 minutes (-4 hours) could be EDT (New York summer)
  final utcMinus4 = TomTimezone.allWithOffset(-240);
  final utcMinus4Count = utcMinus4?.length ?? 0;
  final utcMinus4First5 =
      utcMinus4?.take(5).map((t) => t.timezone).toList() ?? [];

  print('   Timezones currently at UTC-4:');
  if (utcMinus4Count > 0) {
    print('   First 5: ${utcMinus4First5.join(", ")}');
    print('   Total: $utcMinus4Count timezones\n');
  } else {
    print('   (No timezones with that offset currently)\n');
  }

  // -------------------------------------------------------------------------
  // Example 7: Offset in minutes format
  // -------------------------------------------------------------------------
  print('7. Converting offset minutes to string:');

  final offset540 = TomTimezone.convertMinutesToUtcOffset(540);
  final offsetMinus300 = TomTimezone.convertMinutesToUtcOffset(-300);
  final offset330 = TomTimezone.convertMinutesToUtcOffset(330);
  final offset0 = TomTimezone.convertMinutesToUtcOffset(0);

  print('   540 minutes (+9:00): $offset540');
  print('   -300 minutes (-5:00): $offsetMinus300');
  print('   330 minutes (+5:30): $offset330');
  print('   0 minutes (UTC): $offset0\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: DST vs Non-DST
  assert(tokyoSummerOffset == '+09:00');
  assert(tokyoWinterOffset == '+09:00'); // Tokyo has no DST
  assert(nySummerOffset == '-04:00'); // EDT
  assert(nyWinterOffset == '-05:00'); // EST

  // Example 2: US DST transition
  assert(beforeSpringOffset == '-05:00'); // Still EST
  assert(afterSpringOffset == '-04:00'); // Now EDT

  // Example 3: European DST. London in winter sits at zero offset, which
  // `convertMinutesToUtcOffset` renders as the ISO 8601 designator 'Z' — the
  // same value example 7 below asserts for 0 minutes. It is not '+00:00'.
  assert(londonSummerOffset == '+01:00'); // BST
  assert(londonWinterOffset == 'Z'); // GMT — zero offset, so 'Z'

  // Example 4: Serialization with DST offsets
  // Note: The offset in serialization reflects the current system offset for display
  assert(summerMeetingSerialized.contains('America/New_York'));
  assert(winterMeetingSerialized.contains('America/New_York'));

  // Example 5: Timezone conversions
  assert(nyLocalHour == 14); // 18 UTC - 4 = 14 EDT
  assert(nyLocalMinute == 0);
  assert(londonLocalHour == 19); // 18 UTC + 1 = 19 BST
  assert(londonLocalMinute == 0);
  assert(tokyoLocalHour == 3); // 18 UTC + 9 = 27 = 3 next day
  assert(tokyoLocalMinute == 0);

  // Example 6: Finding timezones by offset
  assert(utcMinus4Count > 0);
  assert(utcMinus4First5.isNotEmpty);

  // Example 7: Offset conversion
  assert(offset540 == '+09:00');
  assert(offsetMinus300 == '-05:00');
  assert(offset330 == '+05:30');
  assert(offset0 == 'Z');
}

/// Standalone entry point.
void main() {
  prepareSampleProcess();
  run();
}
