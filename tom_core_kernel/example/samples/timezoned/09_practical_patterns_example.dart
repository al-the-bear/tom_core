/// Practical Patterns Example
///
/// This example demonstrates common real-world patterns for using TomTimezoned
/// types: scheduling meetings across timezones, storing/retrieving from
/// databases, working with user preferences, and more.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Example Code
// ============================================================================

void run() {
  print('=== 09: Practical Patterns Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Scheduling a meeting across timezones
  // -------------------------------------------------------------------------
  print('1. Scheduling a meeting across timezones:');

  // Meeting scheduled for 2pm Tokyo time
  final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
  final newYork = TomTimezone.fromName('America/New_York')!;
  final london = TomTimezone.fromName('Europe/London')!;

  final meetingTokyo = TomZonedDateTime(
    year: 2024,
    month: 6,
    day: 15,
    hour: 14,
    minute: 0,
    timezone: tokyo,
  );

  final meetingSerialized = meetingTokyo.toString();

  print('   Meeting scheduled: 2:00 PM Tokyo time');
  print('   Stored as: $meetingSerialized');

  // Convert to other timezones using convertToTimezone method
  final inNewYork = meetingTokyo.convertToTimezone(newYork);
  final inLondon = meetingTokyo.convertToTimezone(london);
  final inTokyo = meetingTokyo.convertToTimezone(tokyo);

  final tokyoTimeStr =
      '${inTokyo.localHour}:${inTokyo.localMinute.toString().padLeft(2, '0')}';
  final newYorkTimeStr =
      '${inNewYork.localHour}:${inNewYork.localMinute.toString().padLeft(2, '0')}';
  final londonTimeStr =
      '${inLondon.localHour}:${inLondon.localMinute.toString().padLeft(2, '0')}';

  print('   Local times:');
  print('   - Tokyo: $tokyoTimeStr');
  print('   - New York: $newYorkTimeStr');
  print('   - London: $londonTimeStr\n');

  // -------------------------------------------------------------------------
  // Example 2: Database storage pattern
  // -------------------------------------------------------------------------
  print('2. Database storage pattern:');

  // Simulate storing to database
  final userEvent = TomZonedDateTime(
    year: 2024,
    month: 12,
    day: 31,
    hour: 23,
    minute: 59,
    timezone: newYork,
  );

  // Store as string in database
  final dbValue = userEvent.toString();
  print('   Storing in DB: $dbValue');

  // Later, retrieve from database
  final retrieved = TomZonedDateTime.parseFromString(dbValue);
  final retrievedDateStr =
      '${retrieved.localYear}-${retrieved.localMonth}-${retrieved.localDay}';
  final retrievedTimezone = retrieved.timezone.timezone;

  print('   Retrieved: $retrievedDateStr');
  print('   Timezone preserved: $retrievedTimezone\n');

  // -------------------------------------------------------------------------
  // Example 3: User timezone preferences
  // -------------------------------------------------------------------------
  print('3. User timezone preferences:');

  // User's preferred timezone from settings
  final userTimezoneName = 'Europe/Paris';
  final userTz = TomTimezone.fromName(userTimezoneName);

  // Create event in user's timezone
  final userBirthday = TomZonedDate(
    year: 1990,
    month: 5,
    day: 15,
    timezone: userTz,
  );

  final userTzName = userTz?.timezone;
  final birthdaySerialized = userBirthday.toString();

  print('   User timezone: $userTzName');
  print('   Birthday: $birthdaySerialized\n');

  // -------------------------------------------------------------------------
  // Example 4: Comparing events across timezones
  // -------------------------------------------------------------------------
  print('4. Comparing events across timezones:');

  // Event 1: 12:00 UTC
  final event1 = TomZonedDateTime(
    year: 2024,
    month: 6,
    day: 15,
    hour: 12,
    timezone: TomTimezone.utc,
  );

  // Event 2: 21:00 Tokyo (which is also 12:00 UTC, since Tokyo is +9)
  final event2 = TomZonedDateTime(
    year: 2024,
    month: 6,
    day: 15,
    hour: 21,
    timezone: tokyo,
  );

  final event1Serialized = event1.toString();
  final event2Serialized = event2.toString();

  print('   Event 1: $event1Serialized');
  print('   Event 2: $event2Serialized');

  // Compare using millisecondsSinceEpoch (UTC comparison)
  final sameTime =
      event1.millisecondsSinceEpoch == event2.millisecondsSinceEpoch;
  print('   Same moment in time: $sameTime');
  print('   (Both are 12:00 UTC)\n');

  // -------------------------------------------------------------------------
  // Example 5: Date-only events (birthdays, holidays)
  // -------------------------------------------------------------------------
  print('5. Date-only events:');

  final holiday = TomZonedDate(
    year: 2024,
    month: 12,
    day: 25,
    timezone: TomTimezone.utc,
  );

  final holidayDateStr =
      '${holiday.localYear}-${holiday.localMonth.toString().padLeft(2, '0')}-${holiday.localDay.toString().padLeft(2, '0')}';
  final holidaySerialized = holiday.toString();

  print('   Holiday: $holidayDateStr');
  print('   Stored as: $holidaySerialized');

  // Check if a specific date matches the holiday
  final checkDate = TomZonedDate(
    year: 2024,
    month: 12,
    day: 25,
    timezone: TomTimezone.utc,
  );
  final isHoliday =
      checkDate.localDay == holiday.localDay &&
      checkDate.localMonth == holiday.localMonth;

  print('   Is Dec 25 the holiday: $isHoliday\n');

  // -------------------------------------------------------------------------
  // Example 6: Business hours check
  // -------------------------------------------------------------------------
  print('6. Business hours check:');

  // Check if a specific time is business hours in Tokyo (9 AM - 5 PM)
  final workdayMorning = TomZonedDateTime(
    year: 2024,
    month: 6,
    day: 15,
    hour: 10,
    minute: 0,
    timezone: tokyo,
  );

  final workdayEvening = TomZonedDateTime(
    year: 2024,
    month: 6,
    day: 15,
    hour: 18,
    minute: 0,
    timezone: tokyo,
  );

  final morningHour = workdayMorning.localHour;
  final eveningHour = workdayEvening.localHour;
  final morningIsBusinessHours = morningHour >= 9 && morningHour < 17;
  final eveningIsBusinessHours = eveningHour >= 9 && eveningHour < 17;

  print('   Morning (10:00): Business hours? $morningIsBusinessHours');
  print('   Evening (18:00): Business hours? $eveningIsBusinessHours\n');

  // -------------------------------------------------------------------------
  // Example 7: Time-only values (recurring schedules)
  // -------------------------------------------------------------------------
  print('7. Time-only values for recurring schedules:');

  // Daily standup at 9:00 AM in each office's local time
  final standupTime = TomZonedTime(
    hour: 9,
    minute: 0,
    timezone: TomTimezone.utc, // Stored as UTC reference
  );

  final standupLocalHour = standupTime.localHour;
  final standupLocalMinute = standupTime.localMinute;
  final standupSerialized = standupTime.toString();

  print(
    '   Daily standup: $standupLocalHour:${standupLocalMinute.toString().padLeft(2, '0')} local time',
  );
  print('   Stored as: $standupSerialized\n');

  // -------------------------------------------------------------------------
  // Example 8: Determining type from serialized string
  // -------------------------------------------------------------------------
  print('8. Determining type from serialized string:');

  final strings = [
    '@X@2024-06-15T14:30:00.000Z_+09:00_Asia/Tokyo',
    '@D@2024-06-15T00:00:00.000Z_+09:00_Asia/Tokyo',
    '@T@1970-01-01T09:00:00.000Z_+00:00_UTC',
  ];

  final detectedTypes = <String, String>{};

  for (final s in strings) {
    String type;
    if (TomZonedDateTime.isTomZonedDateTimeString(s)) {
      type = 'TomZonedDateTime (@X@)';
    } else if (TomZonedDate.isTomZonedDateString(s)) {
      type = 'TomZonedDate (@D@)';
    } else if (TomZonedTime.isTomZonedTimeString(s)) {
      type = 'TomZonedTime (@T@)';
    } else {
      type = 'Unknown';
    }
    detectedTypes[s.substring(0, 3)] = type;
    print('   ${s.substring(0, 3)}... -> $type');
  }
  print('');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: Meeting across timezones
  assert(tokyoTimeStr == '14:00');
  assert(inTokyo.localHour == 14);
  assert(inNewYork.localHour == 1); // 14:00 Tokyo = 05:00 UTC = 01:00 EDT
  assert(inLondon.localHour == 6); // 14:00 Tokyo = 05:00 UTC = 06:00 BST
  assert(meetingSerialized.contains('Asia/Tokyo'));

  // Example 2: Database storage
  assert(dbValue.startsWith('@X@'));
  assert(retrievedTimezone == 'America/New_York');
  assert(retrieved.localYear == 2024);
  assert(retrieved.localMonth == 12);
  assert(retrieved.localDay == 31);

  // Example 3: User timezone
  assert(userTz != null);
  assert(userTzName == 'Europe/Paris');
  assert(birthdaySerialized.startsWith('@D@'));

  // Example 4: Comparing events
  assert(sameTime == true);
  assert(event1.millisecondsSinceEpoch == event2.millisecondsSinceEpoch);

  // Example 5: Date-only events
  assert(holidayDateStr == '2024-12-25');
  assert(holidaySerialized.startsWith('@D@'));
  assert(isHoliday == true);

  // Example 6: Business hours
  assert(morningHour == 10);
  assert(eveningHour == 18);
  assert(morningIsBusinessHours == true);
  assert(eveningIsBusinessHours == false);

  // Example 7: Time-only values
  assert(standupLocalHour == 9);
  assert(standupLocalMinute == 0);
  assert(standupSerialized.startsWith('@T@'));

  // Example 8: Type detection
  assert(detectedTypes['@X@'] == 'TomZonedDateTime (@X@)');
  assert(detectedTypes['@D@'] == 'TomZonedDate (@D@)');
  assert(detectedTypes['@T@'] == 'TomZonedTime (@T@)');
}

/// Standalone entry point.
void main() => run();
