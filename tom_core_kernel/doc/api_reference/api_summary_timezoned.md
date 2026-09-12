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
  - [Functions](#functions)

## Overview

Sources:
- `lib/src/tombase/timezoned/date_timestamp.dart`
- `lib/src/tombase/timezoned/timezones.dart`
- `lib/src/tombase/timezoned/init_tz_embedded.dart`
- `lib/src/tombase/timezoned/init_tz_web.dart`

`TomTimezoned` extends `DateTime` and always stores its value in UTC, adding
`local*` accessors that render the moment in an associated `TomTimezone`. Three
specialized subclasses narrow the shape: `TomZonedDate` (date-only, `@D@`
prefix), `TomZonedTime` (time-only anchored at 1970-01-01, `@T@` prefix), and
`TomZonedDateTime` (full datetime, `@X@` prefix). Each serializes to
`ISO8601_OFFSET_TIMEZONE` and parses back with a matching `parseFromString` /
`isTom…String` pair. The ISO section must end in `Z`, since it is the only part
of the string that fixes a point in time; the offset that follows is the zone's
offset at that instant — the one the value's local fields use — and is written
for readability, and read back only for a zone name this runtime does not know,
where it is the only reading the string carries. A produced
string ends where the zone name ends: nothing appends to it, and the parse
regexes anchor there, so whitespace inside the form is refused. Whitespace
*around* a stored value is trimmed by both `parseFromString` and the
`isTom…String` predicates, so a value padded in transit is still read and
re-serializes without the padding.

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
converts to UTC. `parseFromString` throws `FormatException` for a string that is
not in the serialized form; a zone name this runtime does not know is read as a
`TomTimezone.fixedOffset` at the offset stored beside it, not refused.

`==` and `hashCode` are `DateTime`'s, on this type and all three subclasses:
equality is the UTC instant alone, and neither the runtime type nor `timezone`
takes part. A `TomZonedDate` therefore equals the `TomZonedDateTime` naming the
same moment, the same instant in two zones is one value, and a plain
`DateTime.utc(...)` at that instant equals both — so a `Set` keeps one entry and
`Map` keys collide. Compare `runtimeType`, `timezone` or `toString()` when the
question is "the same value" rather than "the same moment".

All of them return `TomTimezoned` itself rather than one of the subclasses, so
the methods below are the whole of what such a value offers. No `convertToTz*`
method is among them, and that is a decision rather than a language limit: an
override may narrow its return type, so a hoisted declaration would compile.
What rules it out is that the three subclasses offer different conversion
*sets*, and the only one they share — preserve the instant — is the wrong
default for a date and for a time. Converting a base value therefore means
rebuilding it as the subclass first, which is one line.

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `isTomTimezonedString(String s)` | `bool` | Whether `s` matches the base serialization format. Judges shape only — a well-formed string may still name a zone the database does not know, which `parseFromString` rejects. |

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
| `getSerializationPrefix` | `String getSerializationPrefix()` | The serialization prefix for this type (empty for the base class; overridden by subclasses). For recognising a stored value's type before parsing — `toString()` already carries the prefix, so prepending this to it doubles it into a string no parser accepts. |
| `toString` | `String toString()` | *(override)* The serialized string in `ISO8601_OFFSET_TIMEZONE` format. |
| `toDateTime` | `DateTime toDateTime()` | The local time representation (a `TZDateTime`) in the associated timezone. |

### TomZonedDate

A timezone-aware date value without time components; it is anchored to the first
instant of the day in the local timezone. Serializes with the `@D@` prefix.

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

`fromDateTime` reads `dtx` in `timezone` to find the calendar day it falls on
*there* and anchors to the start of that day, discarding the time of day — so it
produces the same value the primary constructor would for those components.

The start of a day is local midnight except on the handful of zone-days where a
zone springs forward *at* midnight, when it is 01:00 because 00:00 never
happens. Chile, Cuba, Lebanon, Egypt, Paraguay and the Azores each do this once
a year — seven zone-days in 2024, five in 2025. Both constructors ask the
timezone database rather than assuming, so both agree, and `isDate` recognises
the result.

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
| `isDate(DateTime dt)` | `bool` | Whether `dt` sits at the start of a calendar day. A value that knows its zone — a `TomTimezoned` or any `TZDateTime` — is read in that zone and compared against the first instant of the local day, so every well-formed `TomZonedDate` passes, including one anchored at 01:00 because the zone skipped midnight. A plain `DateTime` carries no zone and is judged on all-zero time components. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getSerializationPrefix` | `String getSerializationPrefix()` | *(override)* Returns `@D@`. |
| `toString` | `String toString()` | *(override)* The `@D@ISO8601_OFFSET_TIMEZONE` serialized string. |
| `convertToTzSameInstant` | `TomZonedDate convertToTzSameInstant(TomTimezone targetTimezone)` | The same instant, read in `targetTimezone` — **not closed over this type**. Midnight on the 15th in Tokyo is 11:00 on the 14th in New York, so the result carries a time of day and a different calendar day, which the type's anchoring otherwise rules out. Answers "when was this, over there". |
| `convertToTzSameDate` | `TomZonedDate convertToTzSameDate(TomTimezone targetTimezone)` | The same calendar day, re-anchored to midnight in `targetTimezone` — closed over the type, so the result is a well-formed date. The instant moves. Answers "what date is this, expressed over there", which is what a holiday or an invoice date means. |

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

`fromDateTime` reads `dtx` in `timezone` to find the wall-clock time it shows
*there* and re-anchors the date to 1970-01-01, discarding the incoming date — so
it produces the same value the primary constructor would for those components.

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
| `isTime(DateTime dt)` | `bool` | Whether `dt`'s date is the Unix epoch (time-only). A `TomTimezoned` is read in the timezone it carries, so every well-formed `TomZonedTime` passes. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getSerializationPrefix` | `String getSerializationPrefix()` | *(override)* Returns `@T@`. |
| `toString` | `String toString()` | *(override)* The `@T@ISO8601_OFFSET_TIMEZONE` serialized string. |
| `convertToTzSameInstant` | `TomZonedTime convertToTzSameInstant(TomTimezone targetTimezone)` | The same instant, read in `targetTimezone` — **not closed over this type**. The clock reading moves, and the local date can leave 1970-01-01, so the result fails `isTime`. Answers "what time was that, over there". |
| `convertToTzSameTime` | `TomZonedTime convertToTzSameTime(TomTimezone targetTimezone)` | The same clock reading, re-anchored to 1970-01-01 in `targetTimezone` — closed over the type, so `isTime` still holds. The instant moves. Answers "what does 09:00 mean over there", which is what a daily standup means. |
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
| `convertToTzSameInstant` | `TomZonedDateTime convertToTzSameInstant(TomTimezone targetTimezone)` | The same UTC instant, read in `targetTimezone`. Closed over this type, which does name an instant — so unlike its date-only and time-only siblings it needs no re-anchoring counterpart. |

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
  bool autoLog = false,
})
```

### TomTimezone

Represents a timezone with its IANA name and location data, wrapping the
`timezone` package. Provides name/offset lookup, DST-aware offset calculation,
and conversion between zones. The database is lazily initialized on first access
(synchronously on native, via `tomSetupTimezones` on web).

#### Constructors

```dart
factory TomTimezone.fixedOffset({required String name, required int utcOffsetMinutes})
```

A zone named `name` that sits at `utcOffsetMinutes` at every instant, with no
transitions and no daylight saving. What a parse falls back to for a zone name
this runtime's database does not hold: the value keeps its stored name and is
read at its stored offset. It **does not join the database** — `fromName`,
`timezones` and the offset lookups do not see it — so a value arriving over the
wire cannot write to the index. An offset outside ±840 minutes throws
`TomFormattingException`.

Otherwise the constructor is private; obtain instances via `TomTimezone.utc`,
`fromName`, `firstWithOffset`, `allWithOffset`, `firstWithOffsetOn`,
`allWithOffsetOn`, or `findTimezone`.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `utc` | `TomTimezone` | The UTC timezone singleton (offset 0, no DST). |
| `timezones` | `Map<String, TomTimezone>` | *(getter)* All available timezones, keyed by uppercase name. Lazily initialized, and **unmodifiable** — a view onto the index every lookup here reads. Take `Map.of(...)` to work with a copy. |

#### Static Methods

| Method | Return Type | Description |
| ------ | ----------- | ----------- |
| `fromName(String name)` | `TomTimezone?` | Finds a timezone by IANA name (case-insensitive); `null` if not found. |
| `firstWithOffset(int utcOffsetMinutes)` | `TomTimezone?` | The first zone whose **current** offset is `utcOffsetMinutes`, or `null` if none is at it now. *First* is bucket order — IANA name order — not the best-known zone: `firstWithOffset(0)` yields `Africa/Abidjan`, not `UTC`. |
| `allWithOffset(int utcOffsetMinutes)` | `List<TomTimezone>?` | Every zone whose **current** offset is `utcOffsetMinutes`, or `null` if none is at it now. **Unmodifiable**, like `timezones`, and for the same reason: it is the bucket `firstWithOffset` reads. Take `[...?…]` to sort or filter. |
| `firstWithOffsetOn(int utcOffsetMinutes, DateTime when)` | `TomTimezone?` | The first zone whose offset **at `when`** is `utcOffsetMinutes`, or `null` if none was. Computed by scanning the database rather than read from the index, so it never goes stale; *first* is database order, as for `firstWithOffset`. |
| `allWithOffsetOn(int utcOffsetMinutes, DateTime when)` | `List<TomTimezone>` | Every zone whose offset **at `when`** is `utcOffsetMinutes`; empty when none was, since a scan always has an answer. **Unmodifiable**. O(zones) per call, against `allWithOffset`'s map hit — a correct answer for an instant, or a fast answer for today. |
| `findTimezone(String? name, int? utcOffsetMinutes, {DateTime? at})` | `TomTimezone` | The strict lookup: never returns `null`. A name-only lookup returns the named zone; with `name` null, the first zone at the given offset — a branch that reads the same index as `firstWithOffset` and inherits its shelf life. Throws `TomTimezoneException`, one key per failure: `timezone.lookup.name_not_found` for a name not in the database (parameters `name`, and `utcOffsetMinutes` when given), `timezone.lookup.offset_mismatch` for a named zone whose offset differs from the one supplied (`name`, `utcOffsetMinutes`, `actualUtcOffsetMinutes`, `at` when given), `timezone.lookup.offset_not_found` for an offset no zone is at (`utcOffsetMinutes`, `at` when given), and `timezone.lookup.no_criteria` when both arguments are null. |
| `convertMinutesToUtcOffset(int totalMinutes)` | `String` | Formats a minute offset as `Z`, `+HH:MM`, or `-HH:MM`. Throws `TomFormattingException` outside ±840 minutes (±14:00, inclusive), which no real zone reaches. Offsets read from a zone are always inside that range, so this static entry point — the only one taking an arbitrary `int` — is also the only one that can raise; `getUtcOffsetStringOn`, `toStringOn` and `toString` cannot. |
| `changeLocation(DateTime dt, TomTimezone inTimezone, TomTimezone toTimezone)` | `DateTime` | Reads the calendar fields of `dt` as a wall-clock reading **in `inTimezone`**, resolves them to an instant there, and renders that instant in `toTimezone`. The instant `dt` itself denotes is ignored, so the result never depends on the host's local zone and `DateTime(...)` / `DateTime.utc(...)` with the same fields convert alike. Use `toTZDateTime` instead to re-render an instant you already hold. |
| `populateFromLocations(Map<String, tz.Location> locations)` | `void` | *(`@visibleForTesting`)* Fills the lookup caches from `locations` and registers the `utc` singleton, which the IANA database does not supply under that name. Logs an ERROR when `locations` is empty. Populates **once per isolate**: a second call throws `TomTimezoneException` (`timezone.database.already_populated`, carrying `loaded` and `offered` counts) rather than replacing the database or ignoring the call. Exists so a test can drive the empty-database branch, which the public entry points cannot provoke on a native platform. |

The index-backed offset entry points — `firstWithOffset`, `allWithOffset` and
`findTimezone`'s name-null branch without `at` — read one index, and that index
is built once at first access from each zone's offset *at that moment*. It is
never rebuilt. So a zone that observes daylight saving is in one bucket in
winter and another in summer (about a third of the IANA database moves this
way: `allWithOffset(0)` contains `Europe/London` in January and not in July,
when London is on BST at +60), and a process that runs across a transition
keeps answering for the season it started in.

Use those for discovery and store the `timezone` name they yield, never the
offset it was found under. When the question is about an instant, ask for it:
`firstWithOffsetOn`, `allWithOffsetOn`, and `findTimezone(..., at:)` compute
each zone's offset at the instant given, so they neither depend on when the
process started nor go stale while it runs. For the offset of a zone you
already hold, `getUtcOffsetOn` is the direct question.

`timezones` and `allWithOffset` return **unmodifiable views** of that index
rather than the index itself. A write throws `UnsupportedError` where it is
made; the alternative is that it succeeds and the database stays wrong for the
life of the process, since the index is built once and never rebuilt. Copy
before sorting or filtering.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `timezone` | `String` | The IANA timezone name (e.g. `America/New_York`). |
| `location` | `tz.Location` | The underlying `timezone` package location — the **shared** object the database holds, so every lookup of a zone yields the same instance. Its transition and zone lists are the package's own mutable lists: rewriting one rewrites that zone's offsets for the process. The lookups this class owns hand out unmodifiable views; this type cannot be wrapped, so read it and leave its lists alone. |
| `timezoneOffsetMin` | `int` | *(getter)* The current UTC offset in minutes, including DST. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* `{offset}_{timezone}` using the current offset. Zoned values do not use it: they render their zone through `toStringOn` at their own instant. |
| `toStringOn` | `String toStringOn(DateTime when)` | `{offset}_{timezone}` with the offset computed for `when` (DST-aware). Every zoned value renders its zone through this at its own instant, so whatever it returns is the tail of every serialized string — which is why it appends nothing. |
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
(`init_tz_embedded.dart` by default, `init_tz_web.dart` in the browser), so the
active implementation is selected at compile time for the target platform.
`timezones.dart` re-exports that same conditional configuration, which is what
carries both names out to `package:tom_core_kernel/tom_core_kernel.dart` — an
import alone would have kept them inside the module.
