# Tom Timezoned System

The Tom Timezoned System provides robust timezone-aware date and time handling for Dart applications.
It extends Dart's built-in `DateTime` with proper timezone support, serialization, and
automatic handling of daylight saving time (DST) transitions.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [TomTimezone](#tomtimezone)
- [TomTimezoned Types](#tomtimezoned-types)
- [Serialization](#serialization)
- [DST Handling](#dst-handling)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)
- [Dependencies](#dependencies)

## Overview

The timezoned system consists of two main components:

1. **`TomTimezone`**: A wrapper around the `timezone` package's `Location` class that provides
   timezone lookup, UTC offset calculation, and formatting.

2. **`TomTimezoned`** and subclasses: DateTime extensions that store values as **true UTC internally**
   while maintaining the associated timezone for display and conversion.

### Internal Storage Model

All `TomTimezoned` values store the actual UTC moment internally:

- **Standard accessors** (`year`, `month`, `day`, `hour`, etc.) return **UTC values**
- **Local accessors** (`localYear`, `localMonth`, `localDay`, `localHour`, etc.) return **local time values** in the associated timezone
- **Timezone conversion** is simple: just change the timezone, the UTC moment stays the same

### Why Use TomTimezoned?

- **Timezone preservation**: Unlike `DateTime`, timezone context is preserved across operations
- **Automatic DST handling**: UTC offsets are calculated correctly for any point in time
- **Serialization**: Built-in string format preserves both the datetime and timezone information
- **Type safety**: Separate classes for date-only, time-only, and full datetime values
- **IANA timezone names**: Uses standard identifiers like `'America/New_York'` or `'Asia/Tokyo'`

## Quick Start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // On native platforms the timezone database loads synchronously on first
  // access — no startup call needed. On web, `await tomSetupTimezones()` first.
  final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
  final newYork = TomTimezone.fromName('America/New_York')!;
  
  // Create a meeting in Tokyo
  final meeting = TomZonedDateTime(
    year: 2024, month: 6, day: 15, hour: 14, minute: 30,
    timezone: tokyo,
  );
  
  // Convert to New York time (same moment, different timezone)
  final inNY = meeting.convertToTimezone(newYork);
  print('Tokyo: ${meeting.localHour}:${meeting.localMinute}');   // 14:30
  print('New York: ${inNY.localHour}:${inNY.localMinute}');      // 01:30
  
  // Serialize and parse
  final serialized = meeting.toString();
  final parsed = TomZonedDateTime.parseFromString(serialized);
}
```

## TomTimezone

### Creating Timezones

```dart
// By IANA name (returns null if not found)
final tokyo = TomTimezone.fromName('Asia/Tokyo');
final newYork = TomTimezone.fromName('America/New_York');

// UTC singleton
final utc = TomTimezone.utc;

// By UTC offset in minutes
final utcPlus9 = TomTimezone.firstWithOffset(540);   // +09:00
final utcMinus5 = TomTimezone.firstWithOffset(-300); // -05:00
final allPlus9 = TomTimezone.allWithOffset(540);     // All +09:00 timezones

// With offset validation
final tz = TomTimezone.findTimezone('America/New_York', -300); // Throws if mismatch
```

### UTC Offset Operations

```dart
final newYork = TomTimezone.fromName('America/New_York')!;

// Get offset at specific dates (shows DST difference)
final winter = DateTime.utc(2024, 1, 15);
final summer = DateTime.utc(2024, 7, 15);

newYork.getUtcOffsetOn(winter);       // -300 minutes (EST: -5:00)
newYork.getUtcOffsetOn(summer);       // -240 minutes (EDT: -4:00)
newYork.getUtcOffsetStringOn(winter); // '-05:00'
newYork.getUtcOffsetStringOn(summer); // '-04:00'

// Current offset
newYork.getCurrentUtcOffset();        // Offset in minutes
newYork.getCurrentUtcOffsetString();  // Offset as string
```

### String Representation

```dart
final newYork = TomTimezone.fromName('America/New_York')!;

newYork.toString();                          // Current: '-05:00_America/New_York' or '-04:00_...'
newYork.toStringOn(DateTime.utc(2024, 1, 15)); // '-05:00_America/New_York'
newYork.toStringOn(DateTime.utc(2024, 7, 15)); // '-04:00_America/New_York'
```

### TZDateTime Interop

```dart
final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
final utcTime = DateTime.utc(2024, 6, 15, 12, 0);

// Convert UTC DateTime to TZDateTime in timezone
final tzDt = tokyo.toTZDateTime(utcTime);

// Get current TZDateTime in timezone
final nowInTokyo = tokyo.now();
```

## TomTimezoned Types

All types share these features:

```dart
// Common accessors (return UTC values)
year, month, day, hour, minute, second, millisecond, microsecond, weekday

// Local accessors (return values in the timezone)
localYear, localMonth, localDay, localHour, localMinute, localSecond, 
localMillisecond, localMicrosecond, localWeekday

// Common methods
timezone                              // The associated TomTimezone
convertToTimezone(TomTimezone tz)     // Convert to another timezone
toDateTime()                          // Get DateTime with local time values
toString()                            // Serialize to string
```

### TomZonedDateTime

Full date and time values. **Serialization prefix**: `@X@`

```dart
final tokyo = TomTimezone.fromName('Asia/Tokyo')!;

// Create with components
final dt = TomZonedDateTime(
  year: 2024, month: 6, day: 15, hour: 14, minute: 30,
  timezone: tokyo,
);

// Create from DateTime
final now = TomZonedDateTime.fromDateTime(DateTime.now(), tokyo);

// Parse from string
final parsed = TomZonedDateTime.parseFromString(
  '@X@2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo'
);

// Check string format
if (TomZonedDateTime.isTomZonedDateTimeString(input)) { ... }
```

### TomZonedDate

Date-only values (time components are zero). **Serialization prefix**: `@D@`

```dart
final tokyo = TomTimezone.fromName('Asia/Tokyo')!;

// Create with components
final date = TomZonedDate(year: 2024, month: 6, day: 15, timezone: tokyo);

// Parse from string
final parsed = TomZonedDate.parseFromString(
  '@D@2024-06-14T15:00:00.000Z_+09:00_Asia/Tokyo'
);

// Check if a DateTime is date-only
if (TomZonedDate.isDate(someDateTime)) { ... }
```

### TomZonedTime

Time-only values (date is 1970-01-01). **Serialization prefix**: `@T@`

```dart
final nyTz = TomTimezone.fromName('America/New_York')!;

// Create with components
final standup = TomZonedTime(hour: 9, minute: 0, timezone: nyTz);

// Parse from string
final parsed = TomZonedTime.parseFromString(
  '@T@1970-01-01T14:00:00.000Z_-05:00_America/New_York'
);

// Check if a DateTime is time-only
if (TomZonedTime.isTime(someDateTime)) { ... }
```

#### Getting Local Time on Different Dates

Use `inTimezoneOn(DateTime when)` to apply a `TomZonedTime` to a specific date.
This is essential for recurring events that need to account for DST transitions:

```dart
final nyTz = TomTimezone.fromName('America/New_York')!;
final standup = TomZonedTime(hour: 9, minute: 0, timezone: nyTz);

// Before DST transition (EST: -05:00)
final march9 = DateTime(2024, 3, 9);
final standupMarch9 = standup.inTimezoneOn(march9);
print(standupMarch9); // 2024-03-09 09:00:00.000-0500

// After DST transition (EDT: -04:00)
final march11 = DateTime(2024, 3, 11);
final standupMarch11 = standup.inTimezoneOn(march11);
print(standupMarch11); // 2024-03-11 09:00:00.000-0400

// The local time stays 9:00 AM, but the UTC moment differs by 1 hour
```

## Serialization

### Format

```
{PREFIX}ISO8601_UTC_OFFSET_TIMEZONE
```

- **PREFIX**: `@D@` (date), `@T@` (time), or `@X@` (datetime)
- **ISO8601**: UTC datetime in ISO 8601 format
- **OFFSET**: UTC offset at serialization time (`Z`, `+09:00`, `-05:00`, etc.)
- **TIMEZONE**: IANA timezone name

### Examples

```dart
'@X@2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo'  // TomZonedDateTime
'@D@2024-06-14T15:00:00.000Z_+09:00_Asia/Tokyo'  // TomZonedDate
'@T@1970-01-01T14:00:00.000Z_+09:00_Asia/Tokyo'  // TomZonedTime
'@X@2024-06-15T14:30:00.000Z_Z_UTC'              // UTC
```

### Parsing

```dart
// Check format before parsing
if (TomZonedDateTime.isTomZonedDateTimeString(input)) {
  final dt = TomZonedDateTime.parseFromString(input);
} else if (TomZonedDate.isTomZonedDateString(input)) {
  final date = TomZonedDate.parseFromString(input);
} else if (TomZonedTime.isTomZonedTimeString(input)) {
  final time = TomZonedTime.parseFromString(input);
}
```

## DST Handling

The system handles DST automatically by storing UTC internally and calculating
offsets based on the datetime value:

```dart
final newYork = TomTimezone.fromName('America/New_York')!;

// Summer (EDT: UTC-4)
final summer = TomZonedDateTime(
  year: 2024, month: 6, day: 15, hour: 12,
  timezone: newYork,
);
print(newYork.getUtcOffsetStringOn(summer)); // '-04:00'

// Winter (EST: UTC-5)
final winter = TomZonedDateTime(
  year: 2024, month: 1, day: 15, hour: 12,
  timezone: newYork,
);
print(newYork.getUtcOffsetStringOn(winter)); // '-05:00'
```

### DST Transition Example

```dart
final ny = TomTimezone.fromName('America/New_York')!;

// March 10, 2024 - DST starts (clocks spring forward at 2:00 AM)
final beforeDST = TomZonedDateTime(
  year: 2024, month: 3, day: 10, hour: 1, minute: 30,
  timezone: ny,
);
print(beforeDST.toString()); // Offset is -05:00

final afterDST = TomZonedDateTime(
  year: 2024, month: 3, day: 10, hour: 3, minute: 30,
  timezone: ny,
);
print(afterDST.toString()); // Offset is -04:00
```

## Error Handling

### TomTimezoneException

Thrown when timezone validation fails:

```dart
try {
  TomTimezone.findTimezone('America/New_York', 540); // +9:00 doesn't match NY
} on TomTimezoneException catch (e) {
  print(e.defaultUserMessage);
}
```

### Null Returns

Lookup methods return `null` for unknown values:

```dart
final tz = TomTimezone.fromName('Invalid/Zone');       // null
final offset = TomTimezone.firstWithOffset(99999);     // null
```

### Format Exceptions

Thrown when parsing fails — either because the string does not match the
expected shape, or because it names a zone the database does not know:

```dart
try {
  TomZonedDateTime.parseFromString('invalid');
} on FormatException catch (e) {
  print(e.message); // Invalid TomZonedDateTime string: invalid
}

try {
  TomZonedDateTime.parseFromString(
    '@X@2024-06-15T05:30:00.000Z_+09:00_Mars/Olympus',
  );
} on FormatException catch (e) {
  print(e.message); // Unknown timezone 'Mars/Olympus' in ...
}
```

An unknown zone is a parse failure, not a silent substitution: the parsed value
would otherwise carry UTC while claiming a zone it never had.

### Safe Parsing Pattern

```dart
TomZonedDateTime? safeParse(String input) {
  if (!TomZonedDateTime.isTomZonedDateTimeString(input)) return null;
  try {
    return TomZonedDateTime.parseFromString(input);
  } on FormatException {
    return null;
  }
}
```

## Best Practices

### Use Local Accessors for Display

```dart
final meeting = TomZonedDateTime(
  year: 2024, month: 6, day: 15, hour: 14, minute: 30,
  timezone: tokyo,
);

// Display: use local accessors
print('${meeting.localHour}:${meeting.localMinute}'); // 14:30 (Tokyo time)

// Internal: UTC values
print('${meeting.hour}:${meeting.minute}');           // 05:30 (UTC)
```

### Preserve Timezone in Serialization

```dart
// Good - preserves timezone
final json = {'meeting_time': meeting.toString()};

// Avoid - loses timezone
final json = {'meeting_time': meeting.toIso8601String()};
```

### Convert Between Timezones

```dart
final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
final newYork = TomTimezone.fromName('America/New_York')!;

final tokyoTime = TomZonedDateTime(
  year: 2024, month: 6, day: 15, hour: 14, minute: 30,
  timezone: tokyo,
);

// Same moment, different timezone
final newYorkTime = tokyoTime.convertToTimezone(newYork);
print('${newYorkTime.localHour}:${newYorkTime.localMinute}'); // 01:30
```

### Compare Datetimes

Since TomTimezoned stores UTC internally, standard comparison works correctly:

```dart
final utcNoon = TomZonedDateTime(
  year: 2024, month: 6, day: 15, hour: 12,
  timezone: TomTimezone.utc,
);

final tokyoEvening = TomZonedDateTime(
  year: 2024, month: 6, day: 15, hour: 21,
  timezone: TomTimezone.fromName('Asia/Tokyo')!,
);

// Same moment in time
print(utcNoon.millisecondsSinceEpoch == tokyoEvening.millisecondsSinceEpoch); // true
```

### Validate Before Parsing

```dart
if (TomZonedDateTime.isTomZonedDateTimeString(input)) {
  final dt = TomZonedDateTime.parseFromString(input);
} else {
  // Handle invalid input
}
```

---

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `timezone` | package | every file | The IANA database and `tz.TZDateTime`. This is the module — the Tom types are a typed, observable surface over it |
| [**Little Things Module**](../little_things/little_things.md) | kernel module | `timezones.dart` | `TomException`, the base of the module's exception (`exception_base.dart`), and `convertMinutesToUtcOffset` for rendering a UTC offset (`formatting.dart`) |
| `tom_basics` | package | `timezones.dart` | `tomLog`, at `debug` when a zone lookup falls back and at `error` when initialization fails |
| `meta` | package | `timezones.dart` | `@visibleForTesting` only; no runtime behaviour |

Note that `date_timestamp.dart` — where `TomZonedDate`, `TomZonedTime` and
`TomZonedDateTime` live — imports only `timezone` and its sibling
`timezones.dart`. The kernel dependencies above all belong to `timezones.dart`,
the initialization and lookup half of the module.

### Platform selection is a conditional import

`timezones.dart` picks its initializer at compile time:

```dart
import 'init_tz.dart'
    if (dart.library.io) 'init_tz_flutter.dart'
    if (dart.library.js) 'init_tz_web.dart';
```

So the `timezone` package is reached through a different entry point per
platform — `standalone.dart` on native, `data/latest.dart` under Flutter,
`browser.dart` on the web. Nothing in the calling code changes, but a
platform whose database has not been loaded fails at the first lookup rather
than at import.
