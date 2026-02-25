/// Zoned DateTime Example
///
/// This example demonstrates the three TomTimezoned subclasses:
/// TomZonedDateTime, TomZonedDate, and TomZonedTime.
/// It shows how to create, manipulate, and use these timezone-aware types.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Example Code
// ============================================================================

void run() {
  print('=== 02: Zoned DateTime Example ===\n');

  final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
  final newYork = TomTimezone.fromName('America/New_York')!;
  final london = TomTimezone.fromName('Europe/London')!;

  // -------------------------------------------------------------------------
  // Example 1: TomZonedDateTime - Full date and time
  // -------------------------------------------------------------------------
  print('1. TomZonedDateTime - Full date and time:');
  
  // Create with all components
  final meeting = TomZonedDateTime(
    year: 2024,
    month: 6,
    day: 15,
    hour: 14,
    minute: 30,
    second: 0,
    timezone: tokyo,
  );
  
  final meetingLocalYear = meeting.localYear;
  final meetingLocalMonth = meeting.localMonth;
  final meetingLocalDay = meeting.localDay;
  final meetingLocalHour = meeting.localHour;
  final meetingLocalMinute = meeting.localMinute;
  final meetingUtcYear = meeting.year;
  final meetingUtcHour = meeting.hour;
  final meetingTimezone = meeting.timezone.timezone;
  final meetingSerialized = meeting.toString();
  
  print('   Meeting in Tokyo:');
  print('   - Year (local): $meetingLocalYear');
  print('   - Month (local): $meetingLocalMonth');
  print('   - Day (local): $meetingLocalDay');
  print('   - Hour (local): $meetingLocalHour');
  print('   - Minute (local): $meetingLocalMinute');
  print('   - Year (UTC): $meetingUtcYear');
  print('   - Hour (UTC): $meetingUtcHour');
  print('   - Timezone: $meetingTimezone');
  print('   - Serialized: $meetingSerialized\n');

  // -------------------------------------------------------------------------
  // Example 2: Creating from DateTime
  // -------------------------------------------------------------------------
  print('2. Creating from existing DateTime:');
  
  final fixedUtc = DateTime.utc(2024, 6, 15, 12, 0);
  final fixedInNewYork = TomZonedDateTime.fromDateTime(fixedUtc, newYork);
  
  final fixedNyLocalHour = fixedInNewYork.localHour;
  final fixedNyTimezone = fixedInNewYork.timezone.timezone;
  
  print('   Original UTC: ${fixedUtc.toIso8601String()}');
  print('   As TomZonedDateTime (NY): ${fixedInNewYork.toString()}');
  print('   Local hour in NY: $fixedNyLocalHour');
  print('   Timezone: $fixedNyTimezone\n');

  // -------------------------------------------------------------------------
  // Example 3: TomZonedDate - Date only
  // -------------------------------------------------------------------------
  print('3. TomZonedDate - Date only (no time components):');
  
  final birthday = TomZonedDate(
    year: 1990,
    month: 3,
    day: 25,
    timezone: tokyo,
  );
  
  final birthdayLocalYear = birthday.localYear;
  final birthdayLocalMonth = birthday.localMonth;
  final birthdayLocalDay = birthday.localDay;
  final birthdayLocalHour = birthday.localHour;
  final birthdayLocalMinute = birthday.localMinute;
  final birthdayIsDate = TomZonedDate.isDate(birthday);
  final birthdaySerialized = birthday.toString();
  
  print('   Birthday:');
  print('   - Date: $birthdayLocalYear-${birthdayLocalMonth.toString().padLeft(2, '0')}-${birthdayLocalDay.toString().padLeft(2, '0')}');
  print('   - Hour (local): $birthdayLocalHour (always 0)');
  print('   - Minute (local): $birthdayLocalMinute (always 0)');
  print('   - Is date-only (checks UTC): $birthdayIsDate');
  print('   - Serialized: $birthdaySerialized\n');

  // -------------------------------------------------------------------------
  // Example 4: TomZonedTime - Time only
  // -------------------------------------------------------------------------
  print('4. TomZonedTime - Time only (date is 1970-01-01):');
  
  final lunchTime = TomZonedTime(
    hour: 12,
    minute: 30,
    second: 0,
    timezone: london,
  );
  
  final lunchLocalHour = lunchTime.localHour;
  final lunchLocalMinute = lunchTime.localMinute;
  final lunchUtcYear = lunchTime.year;
  final lunchUtcMonth = lunchTime.month;
  final lunchUtcDay = lunchTime.day;
  final lunchIsTime = TomZonedTime.isTime(lunchTime);
  final lunchSerialized = lunchTime.toString();
  
  print('   Lunch time:');
  print('   - Hour (local): $lunchLocalHour');
  print('   - Minute (local): $lunchLocalMinute');
  print('   - Year (internal): $lunchUtcYear (UTC epoch-based)');
  print('   - Month (internal): $lunchUtcMonth');
  print('   - Day (internal): $lunchUtcDay');
  print('   - Is time-only: $lunchIsTime');
  print('   - Serialized: $lunchSerialized\n');

  // -------------------------------------------------------------------------
  // Example 5: Serialization prefixes
  // -------------------------------------------------------------------------
  print('5. Serialization prefixes:');
  
  final dateTimePrefix = TomZonedDateTime.serializationPrefix;
  final datePrefix = TomZonedDate.serializationPrefix;
  final timePrefix = TomZonedTime.serializationPrefix;
  
  print('   TomZonedDateTime prefix: $dateTimePrefix (@X@)');
  print('   TomZonedDate prefix: $datePrefix (@D@)');
  print('   TomZonedTime prefix: $timePrefix (@T@)\n');

  // -------------------------------------------------------------------------
  // Example 6: DateTime arithmetic (inherited from DateTime)
  // -------------------------------------------------------------------------
  print('6. DateTime arithmetic (inherited from DateTime):');
  
  final eventStart = TomZonedDateTime(
    year: 2024, month: 6, day: 15, hour: 10,
    timezone: tokyo,
  );
  
  final event2 = TomZonedDateTime(
    year: 2024, month: 6, day: 15, hour: 12,
    timezone: tokyo,
  );
  
  // Add duration - note: returns plain DateTime, not TomZonedDateTime
  final later = eventStart.add(Duration(hours: 2));
  final laterHour = later.hour;
  final isEventStartBefore = eventStart.isBefore(event2);
  final diffHours = event2.difference(eventStart).inHours;
  
  print('   Event start (local): ${eventStart.localHour}:00');
  print('   2 hours later (UTC): $laterHour:00');
  print('   eventStart.isBefore(event2): $isEventStartBefore');
  print('   Difference: $diffHours hours\n');

  // =========================================================================
  // Assertions
  // =========================================================================
  
  // Example 1: TomZonedDateTime
  assert(meetingLocalYear == 2024);
  assert(meetingLocalMonth == 6);
  assert(meetingLocalDay == 15);
  assert(meetingLocalHour == 14);
  assert(meetingLocalMinute == 30);
  assert(meetingUtcYear == 2024);
  assert(meetingUtcHour == 5); // 14:30 Tokyo = 05:30 UTC
  assert(meetingTimezone == 'Asia/Tokyo');
  assert(meetingSerialized.startsWith('@X@'));
  assert(meetingSerialized.contains('Asia/Tokyo'));
  
  // Example 2: FromDateTime
  assert(fixedNyLocalHour == 8); // 12 UTC = 08:00 EDT (June)
  assert(fixedNyTimezone == 'America/New_York');
  
  // Example 3: TomZonedDate
  assert(birthdayLocalYear == 1990);
  assert(birthdayLocalMonth == 3);
  assert(birthdayLocalDay == 25);
  assert(birthdayLocalHour == 0);
  assert(birthdayLocalMinute == 0);
  // isDate checks UTC values - since Tokyo is +9, midnight local = 15:00 UTC previous day
  assert(birthdayIsDate == false);
  assert(birthdaySerialized.startsWith('@D@'));
  
  // Example 4: TomZonedTime
  assert(lunchLocalHour == 12);
  assert(lunchLocalMinute == 30);
  assert(lunchUtcYear == 1970);
  assert(lunchUtcMonth == 1);
  assert(lunchUtcDay == 1);
  assert(lunchIsTime == true);
  assert(lunchSerialized.startsWith('@T@'));
  
  // Example 5: Serialization prefixes
  assert(dateTimePrefix == '@X@');
  assert(datePrefix == '@D@');
  assert(timePrefix == '@T@');
  
  // Example 6: DateTime arithmetic
  assert(eventStart.localHour == 10);
  assert(laterHour == 3); // 10:00 Tokyo (01:00 UTC) + 2 hours = 03:00 UTC
  assert(isEventStartBefore == true);
  assert(diffHours == 2);
}
