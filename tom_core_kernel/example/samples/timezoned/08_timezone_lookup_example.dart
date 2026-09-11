/// Timezone Lookup Example
///
/// This example demonstrates the various ways to find and look up timezones:
/// by name, by offset, and how to list all available timezones.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/timezoned/08_timezone_lookup_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// ============================================================================
// Example Code
// ============================================================================

void run() {
  print('=== 08: Timezone Lookup Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Lookup by exact IANA name
  // -------------------------------------------------------------------------
  print('1. Lookup by exact IANA name:');

  final tokyo = TomTimezone.fromName('Asia/Tokyo');
  final la = TomTimezone.fromName('America/Los_Angeles');
  final sydney = TomTimezone.fromName('Australia/Sydney');

  final tokyoName = tokyo?.timezone ?? "null";
  final laName = la?.timezone ?? "null";
  final sydneyName = sydney?.timezone ?? "null";

  print('   TomTimezone.fromName("Asia/Tokyo"): $tokyoName');
  print('   TomTimezone.fromName("America/Los_Angeles"): $laName');
  print('   TomTimezone.fromName("Australia/Sydney"): $sydneyName\n');

  // -------------------------------------------------------------------------
  // Example 2: Find first timezone with specific offset
  // -------------------------------------------------------------------------
  print('2. Find first timezone with specific offset (in minutes):');

  // These match the offset each zone has *right now*, so the answers have a
  // shelf life: a DST-observing zone is in one bucket in winter and another in
  // summer. Discovery, not identity — store the name, not the offset.
  final utcPlus9 = TomTimezone.firstWithOffset(540); // +9:00
  final utcMinus5 = TomTimezone.firstWithOffset(-300); // -5:00
  final utcPlus530 = TomTimezone.firstWithOffset(330); // +5:30

  final utcPlus9Name = utcPlus9?.timezone ?? "not found";
  final utcMinus5Name = utcMinus5?.timezone ?? "not found";
  final utcPlus530Name = utcPlus530?.timezone ?? "not found";

  print('   firstWithOffset(540) = +9:00: $utcPlus9Name');
  print('   firstWithOffset(-300) = -5:00: $utcMinus5Name');
  print('   firstWithOffset(330) = +5:30: $utcPlus530Name\n');

  // -------------------------------------------------------------------------
  // Example 3: Find all timezones with specific offset
  // -------------------------------------------------------------------------
  print('3. Find all timezones with specific offset:');

  final allPlus9 = TomTimezone.allWithOffset(540);
  final allPlus9Count = allPlus9?.length ?? 0;
  final allPlus9First5 =
      allPlus9?.take(5).map((t) => t.timezone).toList() ?? [];

  if (allPlus9Count > 0) {
    print('   allWithOffset(540) = +9:00:');
    print('   - Total: $allPlus9Count timezones');
    print('   - Examples: ${allPlus9First5.join(", ")}\n');
  } else {
    print('   allWithOffset(540): no results\n');
  }

  // -------------------------------------------------------------------------
  // Example 4: Using findTimezone with name and offset validation
  // -------------------------------------------------------------------------
  print('4. Using findTimezone with name and offset validation:');

  TomTimezone? utcValid;
  var utcValidSuccess = false;
  try {
    utcValid = TomTimezone.findTimezone('UTC', 0);
    utcValidSuccess = true;
    print('   findTimezone("UTC", 0): ${utcValid.timezone}');
  } on TomTimezoneException catch (e) {
    print('   findTimezone("UTC", 0): Error - ${e.defaultUserMessage}');
  }

  var invalidOffsetThrew = false;
  try {
    // This should fail - UTC doesn't have offset 60
    TomTimezone.findTimezone('UTC', 60);
    print('   findTimezone("UTC", 60): unexpectedly succeeded');
  } on TomTimezoneException catch (e) {
    invalidOffsetThrew = true;
    print('   findTimezone("UTC", 60): Correctly threw exception');
    print('     ${e.defaultUserMessage}');
    print('     (UTC has offset 0, not 60 minutes)');
  }

  // Every lookup the strict entry point cannot satisfy throws, the two that
  // name no zone included — it never answers null.
  final noZoneKey = _findTimezoneFailureKey(
    () => TomTimezone.findTimezone(null, 7),
  );
  final noCriteriaKey = _findTimezoneFailureKey(
    () => TomTimezone.findTimezone(null, null),
  );
  print('   findTimezone(null, 7):    $noZoneKey');
  print('   findTimezone(null, null): $noCriteriaKey\n');

  // -------------------------------------------------------------------------
  // Example 5: Listing all available timezones
  // -------------------------------------------------------------------------
  print('5. All available timezones:');

  final allTimezones = TomTimezone.timezones;
  final totalTimezones = allTimezones.length;
  print('   Total available: $totalTimezones timezones');
  print('   (the count comes from the IANA database bundled with');
  print('    package:timezone, so it shifts when that package is updated)');

  // Group by region
  final regions = <String, int>{};
  for (final name in allTimezones.keys) {
    final region = name.split('/').first;
    regions[region] = (regions[region] ?? 0) + 1;
  }

  final sortedRegions = regions.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topRegions = sortedRegions.take(5).toList();

  print('   By region (top 5):');
  for (final entry in topRegions) {
    print('   - ${entry.key}: ${entry.value} timezones');
  }
  print('');

  // -------------------------------------------------------------------------
  // Example 6: Checking if timezone exists
  // -------------------------------------------------------------------------
  print('6. Checking if timezone exists:');

  final validNames = ['America/New_York', 'Asia/Tokyo', 'Europe/London'];
  final invalidNames = ['US/Eastern', 'Tokyo', 'GMT'];

  final validResults = <String, bool>{};
  print('   Valid IANA names:');
  for (final name in validNames) {
    final exists = TomTimezone.fromName(name) != null;
    validResults[name] = exists;
    print('   - "$name": $exists');
  }

  final invalidResults = <String, bool>{};
  print('   Common but may not work:');
  for (final name in invalidNames) {
    final exists = TomTimezone.fromName(name) != null;
    invalidResults[name] = exists;
    print('   - "$name": $exists');
  }
  print('');

  // -------------------------------------------------------------------------
  // Example 7: Null-safe handling of lookups
  // -------------------------------------------------------------------------
  print('7. Null-safe handling of lookups:');

  final maybeInvalid = TomTimezone.fromName('NotA/RealTimezone');
  final maybeEst = TomTimezone.fromName('EST');

  print(
    '   fromName("NotA/RealTimezone"): ${maybeInvalid == null ? "null (not found)" : maybeInvalid.timezone}',
  );
  print(
    '   fromName("EST"): ${maybeEst == null ? "null (not found)" : maybeEst.timezone}',
  );
  print('');

  // -------------------------------------------------------------------------
  // Example 8: The UTC singleton
  // -------------------------------------------------------------------------
  print('8. The UTC singleton:');

  final utc1 = TomTimezone.utc;
  final utc2 = TomTimezone.utc;

  final utcTimezoneName = utc1.timezone;
  final utcIsSingleton = identical(utc1, utc2);
  final utcOffset = utc1.getCurrentUtcOffset();

  print('   TomTimezone.utc.timezone: $utcTimezoneName');
  print('   Always same instance: $utcIsSingleton');
  print('   Current offset: $utcOffset minutes\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: Lookup by IANA name
  assert(tokyo != null);
  assert(la != null);
  assert(sydney != null);
  assert(tokyoName == 'Asia/Tokyo');
  assert(laName == 'America/Los_Angeles');
  assert(sydneyName == 'Australia/Sydney');

  // Example 2: First with offset
  assert(utcPlus9 != null);
  assert(utcMinus5 != null);
  assert(utcPlus530 != null);

  // Example 3: All with offset
  assert(allPlus9Count > 0);
  assert(allPlus9First5.isNotEmpty);

  // Example 4: findTimezone validation
  assert(utcValidSuccess == true);
  assert(utcValid?.timezone == 'UTC');
  assert(invalidOffsetThrew == true);
  assert(noZoneKey == 'timezone.not_found.offset');
  assert(noCriteriaKey == 'timezone.find.no_criteria');

  // Example 5: All timezones. The exact count is a property of the IANA
  // database bundled with `package:timezone` (341 locations at 0.11.1, plus
  // the UTC entry TomTimezone adds), so it moves whenever that package is
  // updated. Assert what is actually invariant: the catalogue is a full one
  // rather than a stub, it contains the zones looked up above, and it groups
  // into the IANA regions. The floor of 100 is far below any real tzdb and
  // far above an empty or partially-loaded database, which is the failure
  // this is here to catch.
  assert(totalTimezones > 100);
  assert(allTimezones.containsKey('ASIA/TOKYO'));
  assert(allTimezones.containsKey('AMERICA/LOS_ANGELES'));
  assert(regions.length > 5);
  assert(topRegions.isNotEmpty);

  // Example 6: Timezone existence
  assert(validResults['America/New_York'] == true);
  assert(validResults['Asia/Tokyo'] == true);
  assert(validResults['Europe/London'] == true);

  // Example 7: Null handling
  assert(maybeInvalid == null);

  // Example 8: UTC singleton
  assert(utcTimezoneName == 'UTC');
  assert(utcIsSingleton == true);
  assert(utcOffset == 0);
}

/// Standalone entry point.
void main() {
  prepareSampleProcess();
  run();
}

/// The key of the [TomTimezoneException] [lookup] throws, or `null` if it
/// returns normally.
String? _findTimezoneFailureKey(void Function() lookup) {
  try {
    lookup();
    return null;
  } on TomTimezoneException catch (e) {
    return e.key;
  }
}
