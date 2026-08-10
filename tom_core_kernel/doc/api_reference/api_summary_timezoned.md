# Tom Core Kernel API Reference: Timezoned Module

Timezone-aware date/time value types that store the underlying instant in UTC
while exposing local values in an associated IANA timezone, plus a `TomTimezone`
wrapper for zone lookup/offset/conversion and platform-conditional database
initialization.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomTimezoned](#tomtimezoned)
  - [TomZonedDate](#tomzoneddate)
  - [TomZonedTime](#tomzonedtime)
  - [TomZonedDateTime](#tomzoneddatetime)
  - [TomTimezoneException](#tomtimezoneexception)
  - [TomTimezone](#tomtimezone)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources:
- `lib/src/tombase/timezoned/date_timestamp.dart`
- `lib/src/tombase/timezoned/timezones.dart`
- `lib/src/tombase/timezoned/init_tz.dart`
- `lib/src/tombase/timezoned/init_tz_flutter.dart`
- `lib/src/tombase/timezoned/init_tz_web.dart`

`TomTimezoned` extends `DateTime` and always stores its value in UTC, adding
`local*` accessors that render the moment in an associated `TomTimezone`. Three
specialized subclasses narrow the shape: `TomZonedDate` (date-only, `@D@`
prefix), `TomZonedTime` (time-only anchored at 1970-01-01, `@T@` prefix), and
`TomZonedDateTime` (full datetime, `@X@` prefix). Each serializes to
`ISO8601_OFFSET_TIMEZONE` and parses back with a matching `parseFromString` /
`isTom…String` pair.

`TomTimezone` wraps the `timezone` package's `Location`: it looks zones up by
name or UTC offset, computes offsets (including DST) at any instant, and
converts `DateTime`s between zones. The IANA database is loaded lazily on first
access via a platform-conditional import — synchronously from the embedded data
on native/Flutter, and (asynchronously, via `tomSetupTimezones`) over the
network on web where the synchronous path throws. `TomTimezoneException`
(extends the kernel `TomException`) is raised on name/offset mismatch.

## Class Hierarchy

```
DateTime
└── TomTimezoned
    ├── TomZonedDate
    ├── TomZonedTime
    └── TomZonedDateTime

TomException  (kernel)
    └── TomTimezoneException

Object
└── TomTimezone
```

## Classes

### TomTimezoned

Base class for timezone-aware date/time values. Extends `DateTime`; the internal
value is always stored in UTC, and `local*` accessors return the values in the
associated `TomTimezone`. Serializes to `ISO8601_OFFSET_TIMEZONE`.

- **Extends:** `DateTime`

#### Constructors

```dart
factory TomTimezoned({
  required int year,
  int month = 1,
  int day = 1,
  int hour = 0,
  int minute = 0,
  int second = 0,
  int millisecond = 0,
  int microsecond = 0,
  TomTimezone? timezone,
})

TomTimezoned.utc({
  int year = 1970,
  int month = 1,
  int day = 1,
  int hour = 0,
  int minute = 0,
  int second = 0,
  int millisecond = 0,
  int microsecond = 0,
})

factory TomTimezoned.now([TomTimezone? timezone])

factory TomTimezoned.fromDateTime(DateTime dateTime, [TomTimezone? timezone])

factory TomTimezoned.parseFromString(String formattedString)
```

The default factory interprets the components as local time in `timezone` and
converts to UTC. `parseFromString` throws `FormatException` for an invalid
string or unknown zone.

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `isTomTimezonedString(String s)` | `bool` | Whether `s` matches the base serialization format. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `timezone` | `TomTimezone` | *(getter)* The timezone associated with this datetime. |
| `localYear` | `int` | *(getter)* The year in the local timezone. |
| `localMonth` | `int` | *(getter)* The month (1-12) in the local timezone. |
| `localDay` | `int` | *(getter)* The day of month (1-31) in the local timezone. |
| `localHour` | `int` | *(getter)* The hour (0-23) in the local timezone. |
| `localMinute` | `int` | *(getter)* The minute (0-59) in the local timezone. |
| `localSecond` | `int` | *(getter)* The second (0-59) in the local timezone. |
| `localMillisecond` | `int` | *(getter)* The millisecond (0-999) in the local timezone. |
| `localMicrosecond` | `int` | *(getter)* The microsecond (0-999) in the local timezone. |
| `localWeekday` | `int` | *(getter)* The weekday in the local timezone (1=Monday, 7=Sunday). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getSerializationPrefix` | `String getSerializationPrefix()` | The serialization prefix for this type (empty for the base class; overridden by subclasses). |
| `toString` | `String toString()` | *(override)* The serialized string in `ISO8601_OFFSET_TIMEZONE` format. |
| `toDateTime` | `DateTime toDateTime()` | The local time representation (a `TZDateTime`) in the associated timezone. |

### TomZonedDate

A timezone-aware date value without time components; all time fields are midnight
in the local timezone. Serializes with the `@D@` prefix.

- **Extends:** `TomTimezoned`

#### Constructors

```dart
factory TomZonedDate({
  int year = 1970,
  int month = 1,
  int day = 1,
  TomTimezone? timezone,
})

factory TomZonedDate.fromDateTime(DateTime dtx, [TomTimezone? timezone])

factory TomZonedDate.parseFromString(String formattedString)
```

`parseFromString` throws `FormatException` for an invalid `@D@` string or unknown
zone.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `serializationPrefix` | `String` | The `@D@` prefix that identifies serialized date strings. |

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `isTomZonedDateString(String s)` | `bool` | Whether `s` is a valid `@D@`-prefixed date string. |
| `isDate(DateTime dt)` | `bool` | Whether `dt` has all-zero time components (date-only). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getSerializationPrefix` | `String getSerializationPrefix()` | *(override)* Returns `@D@`. |
| `toString` | `String toString()` | *(override)* The `@D@ISO8601_OFFSET_TIMEZONE` serialized string. |
| `convertToTimezone` | `TomZonedDate convertToTimezone(TomTimezone targetTimezone)` | A new date at the same instant displayed in `targetTimezone`. |

### TomZonedTime

A timezone-aware time-of-day value without date components; the date is anchored
at the Unix epoch (1970-01-01). Serializes with the `@T@` prefix.

- **Extends:** `TomTimezoned`

#### Constructors

```dart
factory TomZonedTime({
  int hour = 0,
  int minute = 0,
  int second = 0,
  int millisecond = 0,
  int microsecond = 0,
  TomTimezone? timezone,
})

factory TomZonedTime.fromDateTime(DateTime dtx, [TomTimezone? timezone])

factory TomZonedTime.parseFromString(String formattedString)
```

`parseFromString` throws `FormatException` for an invalid `@T@` string or unknown
zone.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `serializationPrefix` | `String` | The `@T@` prefix that identifies serialized time strings. |

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `isTomZonedTimeString(String s)` | `bool` | Whether `s` is a valid `@T@`-prefixed time string. |
| `isTime(DateTime dt)` | `bool` | Whether `dt`'s date is the Unix epoch (time-only). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getSerializationPrefix` | `String getSerializationPrefix()` | *(override)* Returns `@T@`. |
| `toString` | `String toString()` | *(override)* The `@T@ISO8601_OFFSET_TIMEZONE` serialized string. |
| `convertToTimezone` | `TomZonedTime convertToTimezone(TomTimezone targetTimezone)` | A new time at the same instant displayed in `targetTimezone`. |
| `inTimezoneOn` | `DateTime inTimezoneOn(DateTime when)` | Applies this local time to the date of `when`, yielding a `TZDateTime` (DST-aware). |

### TomZonedDateTime

A timezone-aware full datetime value — the most common timezone-aware type.
Stored internally as UTC; the offset is determined at creation from the value
itself (DST-aware). Serializes with the `@X@` prefix.

- **Extends:** `TomTimezoned`

#### Constructors

```dart
factory TomZonedDateTime({
  int year = 1970,
  int month = 1,
  int day = 1,
  int hour = 0,
  int minute = 0,
  int second = 0,
  int millisecond = 0,
  int microsecond = 0,
  TomTimezone? timezone,
})

factory TomZonedDateTime.fromDateTime(DateTime dtx, [TomTimezone? timezone])

factory TomZonedDateTime.parseFromString(String formattedString)
```

`parseFromString` throws `FormatException` for an invalid `@X@` string or unknown
zone.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `serializationPrefix` | `String` | The `@X@` prefix that identifies serialized datetime strings. |

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `isTomZonedDateTimeString(String s)` | `bool` | Whether `s` is a valid `@X@`-prefixed datetime string. |
| `isTomDateTime(DateTime dt)` | `bool` | Whether `dt` can be represented as a full datetime (always `true`). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getSerializationPrefix` | `String getSerializationPrefix()` | *(override)* Returns `@X@`. |
| `toString` | `String toString()` | *(override)* The `@X@ISO8601_OFFSET_TIMEZONE` serialized string. |
| `convertToTimezone` | `TomZonedDateTime convertToTimezone(TomTimezone targetTimezone)` | A new datetime at the same UTC instant displayed in `targetTimezone`. |

### TomTimezoneException

Exception thrown when a timezone operation fails (e.g. a name not found in the
database, or a name/offset mismatch). Extends the kernel's `TomException` for
consistent framework error handling.

- **Extends:** `TomException`

#### Constructors

```dart
TomTimezoneException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool? autoLog,
})
```

### TomTimezone

Represents a timezone with its IANA name and location data, wrapping the
`timezone` package. Provides name/offset lookup, DST-aware offset calculation,
and conversion between zones. The database is lazily initialized on first access
(synchronously on native, via `tomSetupTimezones` on web).

#### Constructors

None — the constructor is private. Obtain instances via `TomTimezone.utc`,
`fromName`, `firstWithOffset`, `allWithOffset`, or `findTimezone`.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `utc` | `TomTimezone` | The UTC timezone singleton (offset 0, no DST). |
| `timezones` | `Map<String, TomTimezone>` | *(getter)* All available timezones, keyed by uppercase name. Lazily initialized. |

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `fromName(String name)` | `TomTimezone?` | Finds a timezone by IANA name (case-insensitive); `null` if not found. |
| `firstWithOffset(int utcOffsetMinutes)` | `TomTimezone?` | The first timezone matching the given UTC offset, or `null`. |
| `allWithOffset(int utcOffsetMinutes)` | `List<TomTimezone>?` | All timezones matching the given UTC offset, or `null`. |
| `findTimezone(String? name, int? utcOffsetMinutes)` | `TomTimezone?` | Looks up a zone by name, optionally validating its offset. A name-only lookup returns the named zone; an unknown name, or a name whose current offset differs from a supplied `utcOffsetMinutes`, throws `TomTimezoneException`. With `name` null, returns the first zone at the given offset (or `null` if both arguments are null). |
| `convertMinutesToUtcOffset(int totalMinutes)` | `String` | Formats a minute offset as `Z`, `+HH:MM`, or `-HH:MM`. |
| `changeLocation(DateTime dt, TomTimezone inTimezone, TomTimezone toTimezone)` | `DateTime` | Reads the calendar fields of `dt` as a wall-clock reading **in `inTimezone`**, resolves them to an instant there, and renders that instant in `toTimezone`. The instant `dt` itself denotes is ignored, so the result never depends on the host's local zone and `DateTime(...)` / `DateTime.utc(...)` with the same fields convert alike. Use `toTZDateTime` instead to re-render an instant you already hold. |
| `populateFromLocations(Map<String, tz.Location> locations)` | `void` | *(`@visibleForTesting`)* Fills the lookup caches from `locations` and registers the `utc` singleton, which the IANA database does not supply under that name. Logs an ERROR when `locations` is empty. Exists so a test can drive the empty-database branch, which the public entry points cannot provoke on a native platform. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `timezone` | `String` | The IANA timezone name (e.g. `America/New_York`). |
| `location` | `tz.Location` | The underlying `timezone` package location. |
| `timezoneOffsetMin` | `int` | *(getter)* The current UTC offset in minutes, including DST. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* `{offset}_{timezone}` using the current offset. |
| `toStringOn` | `String toStringOn(DateTime when)` | `{offset}_{timezone}` with the offset computed for `when` (DST-aware). |
| `getUtcOffsetOn` | `int getUtcOffsetOn(DateTime dt)` | The UTC offset in minutes at `dt`. |
| `getUtcOffsetStringOn` | `String getUtcOffsetStringOn(DateTime dt)` | The formatted UTC offset string at `dt`. |
| `getCurrentUtcOffset` | `int getCurrentUtcOffset()` | The current UTC offset in minutes. |
| `getCurrentUtcOffsetString` | `String getCurrentUtcOffsetString()` | The current UTC offset as a formatted string. |
| `toTZDateTime` | `tz.TZDateTime toTZDateTime(DateTime dt)` | Converts `dt` to a `TZDateTime` in this timezone. |
| `now` | `DateTime now()` | The current time in this timezone. |
| `changeToThisLocation` | `DateTime changeToThisLocation(DateTime dt, TomTimezone inTimezone)` | The instance form of `changeLocation` with this timezone as the target; it delegates to it, so the reinterpretation semantics are identical. |

## Global Functions and Constants

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `tomSetupTimezones` | `Future<int> tomSetupTimezones()` | Asynchronously initializes the IANA timezone database. Mandatory on web (fetched over the network) before any timezone access; resolves to `0`. |
| `tomSetupTimezonesSync` | `void tomSetupTimezonesSync()` | Loads the embedded database synchronously (native/Flutter). Backs `TomTimezone`'s synchronous lazy-init; on web it throws a `StateError` because there is no synchronous load path. |

These two functions are provided by a platform-conditional import
(`init_tz.dart` / `init_tz_flutter.dart` / `init_tz_web.dart`), so the active
implementation is selected at compile time for the target platform.
