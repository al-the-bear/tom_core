# Tom Timezoned System

The Tom Timezoned System provides robust timezone-aware date and time handling for Dart applications.
It extends Dart's built-in `DateTime` with proper timezone support, serialization, and
automatic handling of daylight saving time (DST) transitions.

## Table of Contents

- [Overview](#overview)
  - [Internal Storage Model](#internal-storage-model)
  - [Why Use TomTimezoned?](#why-use-tomtimezoned)
- [Initialization](#initialization)
- [Quick Start](#quick-start)
- [TomTimezone](#tomtimezone)
  - [Creating Timezones](#creating-timezones)
  - [UTC Offset Operations](#utc-offset-operations)
  - [String Representation](#string-representation)
  - [TZDateTime Interop](#tzdatetime-interop)
- [TomTimezoned Types](#tomtimezoned-types)
  - [Equality is the instant alone](#equality-is-the-instant-alone)
  - [TomZonedDateTime](#tomzoneddatetime)
  - [TomZonedDate](#tomzoneddate)
  - [TomZonedTime](#tomzonedtime)
- [Serialization](#serialization)
  - [Format](#format)
  - [Examples](#examples)
  - [Parsing](#parsing)
- [DST Handling](#dst-handling)
  - [DST Transition Example](#dst-transition-example)
- [Error Handling](#error-handling)
  - [TomTimezoneException](#tomtimezoneexception)
  - [Null Returns](#null-returns)
  - [Format Exceptions](#format-exceptions)
  - [Safe Parsing Pattern](#safe-parsing-pattern)
- [Best Practices](#best-practices)
  - [Use Local Accessors for Display](#use-local-accessors-for-display)
  - [Preserve Timezone in Serialization](#preserve-timezone-in-serialization)
  - [Convert Between Timezones](#convert-between-timezones)
  - [Compare Datetimes](#compare-datetimes)
  - [Validate Before Parsing](#validate-before-parsing)
- [Dependencies](#dependencies)
  - [Platform selection is a conditional import](#platform-selection-is-a-conditional-import)

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

## Initialization

Every lookup needs the IANA timezone database in memory, and where that data
comes from differs by platform.

**On native (VM / Flutter) there is nothing to do.** The database is bundled
with the package, so the first `TomTimezone` access loads it synchronously and
in memory. No startup call, no `await`.

**On web the database is fetched over the network**, which cannot happen
synchronously — so it has to be done before anything reads a timezone:

```dart complete
import 'package:tom_core_kernel/tom_core_kernel.dart';

Future<void> main() async {
  await tomSetupTimezones();

  // Safe from here on.
  final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
}
```

Skipping it is not a silent degradation: `TomTimezone` throws a `StateError`
naming the missing call rather than behaving as though no zone matched. That is
deliberate — an empty database makes every lookup return `null`, which reads
like a bad zone name and sends you looking in the wrong place.

An `Error`, and not the module's `TomTimezoneException`, is deliberate too. The
module's exceptions answer a question about a value you passed — this zone is
not in the database, that offset belongs to no zone — and you can catch one,
report it, and carry on with the rest of the work. This says something else:
the module is not usable yet. Every later access fails the same way and no
handler repairs that, so the instruction to the reader is to fix the startup,
not to write a `catch`. That is what an `Error` means in Dart, and it is the
only failure in this module raised as one.

`tomSetupTimezones` is safe to call on native too, where it is a no-op beyond
loading data that would have loaded anyway. So startup code that awaits it
unconditionally is correct on both platforms, and that is the simplest thing to
write if the application targets both.

There is also `tomSetupTimezonesSync`, which is what backs the native lazy
load. Calling it directly is rarely useful — it does what first access already
does — and on web it throws, because the synchronous path it names does not
exist there.

## Quick Start

```dart complete
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // Native: the database loads on first access. On web, await
  // tomSetupTimezones() first — see Initialization above.
  final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
  final newYork = TomTimezone.fromName('America/New_York')!;
  
  // Create a meeting in Tokyo
  final meeting = TomZonedDateTime(
    year: 2024, month: 6, day: 15, hour: 14, minute: 30,
    timezone: tokyo,
  );
  
  // Convert to New York time (same moment, different timezone)
  final inNY = meeting.convertToTzSameInstant(newYork);
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

// By UTC offset in minutes — zones that are at that offset *right now*
final utcPlus9 = TomTimezone.firstWithOffset(540);   // +09:00
final utcMinus5 = TomTimezone.firstWithOffset(-300); // -05:00
final allPlus9 = TomTimezone.allWithOffset(540);     // Every zone at +09:00 today

// By UTC offset at a given instant — computed, so it is the same answer
// whenever it is asked
final winter = DateTime.utc(2024, 1, 15);
final atZeroThen = TomTimezone.allWithOffsetOn(0, winter); // includes Europe/London
final firstThen = TomTimezone.firstWithOffsetOn(0, winter);

// With offset validation — -300 is New York in winter, so this throws in summer
final ny = TomTimezone.findTimezone('America/New_York', -300);
// findTimezone throws: unknown name, mismatch, no zone at the offset, both null
```

The offset lookups have a shelf life, and it is worth knowing before you use
one. They match the zone's **current** offset, so a zone that observes daylight
saving is in one bucket in winter and another in summer — about a third of the
IANA database moves this way. `allWithOffset(0)` contains `Europe/London` in
January and does not in July, when London is on BST at +60. The index is built
once, on first access, and never rebuilt, so a process that runs across a
transition keeps answering for the season it started in.

Two consequences at the call site. Use the index-backed lookups for
**discovery** — a zone picker, "who is at +05:30 at the moment" — and store the
zone *name* they give you, never the offset you found it under; a stored offset
stops identifying the same zone twice a year. And when the question is about an
instant rather than about today, ask for that instant: `allWithOffsetOn(offset,
when)` and `firstWithOffsetOn(offset, when)` compute each zone's offset at
`when` instead of reading the index, and `findTimezone`'s `at:` argument does
the same on both of its branches — reading a named zone's offset at `when`, or
scanning for a zone that was at one. They cost a walk of the database where the
index-backed pair costs a map hit, and in exchange the answer neither depends on
the season the process started in nor goes stale while it runs. What
`findTimezone` does with a lookup it cannot satisfy is unchanged — see
[Error Handling](#error-handling):

```dart
final january = DateTime.utc(2024, 1, 15);
final july = DateTime.utc(2024, 7, 15);

TomTimezone.allWithOffsetOn(0, january);  // holds Europe/London
TomTimezone.allWithOffsetOn(0, july);     // does not — London is on BST
// -05:00 is New York in winter and -04:00 in summer, so the same pair agrees
// at one instant and is refused at the other.
TomTimezone.findTimezone('America/New_York', -300, at: january);
TomTimezone.findTimezone('America/New_York', -240, at: july);
```

For the offset of a zone you already hold, the direct question is
`getUtcOffsetOn` (see [UTC Offset Operations](#utc-offset-operations)).

A third follows from the index being built once: `TomTimezone.timezones` and
`allWithOffset` hand back **unmodifiable views** of it, not the collections
themselves. Sorting a returned bucket in place, or filtering it with
`removeWhere`, would not shape a local result — it would rewrite the index for
the rest of the process, and the damage would surface somewhere else entirely,
as a later `firstWithOffset` naming a different zone. Both throw
`UnsupportedError` at the call instead, which is the only place a caller can act
on it.
Copy first when you need a modifiable one: `Map.of(TomTimezone.timezones)`,
`[...?TomTimezone.allWithOffset(0)]`.

`firstWithOffset` is likewise a weaker promise than it looks. *First* means
first in the bucket, which is IANA name order rather than the best-known zone
at that offset: `firstWithOffset(0)` yields `Africa/Abidjan`, not `UTC`. Where a
particular zone is wanted, name it with `fromName`.

The same applies to `findTimezone(null, offset)`, which reads the same index.
Its name-plus-offset form compares against the current offset too, so the
offset you pass has to be the one the zone holds today:
`findTimezone('America/New_York', -300)` above agrees in winter and mismatches
in summer, when New York is at -240.

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

newYork.toString();                          // Current: '-05:00_America/New_York' or '-04:00_... '
newYork.toStringOn(DateTime.utc(2024, 1, 15)); // '-05:00_America/New_York'
newYork.toStringOn(DateTime.utc(2024, 7, 15)); // '-04:00_America/New_York'
```

Both end where the zone name ends — see [Serialization](#serialization).

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

All types share these features, because `TomTimezoned` itself has them:

```text
// Common accessors (return UTC values)
  year, month, day, hour, minute, second, millisecond, microsecond, weekday

// Local accessors (return values in the timezone)
  localYear, localMonth, localDay, localHour, localMinute, localSecond,
  localMillisecond, localMicrosecond, localWeekday

// Common members
  timezone                    // The associated TomTimezone
  getSerializationPrefix()    // '' here; '@D@', '@T@' or '@X@' on the subclasses
  toDateTime()                // Get DateTime with local time values
  toString()                  // Serialize to string
```

Conversion is not on that list, and that is deliberate. It matters because
`TomTimezoned.now()`, `TomTimezoned.parseFromString(...)` and the default
factory all hand back the base class rather than a subclass, so a value held at
that type has no conversion method to call and the compiler is what tells you
so.

The narrowed return types are **not** the obstacle: Dart permits an override to
narrow its return type, so a base declaration that each subclass narrowed would
compile. What stops it is that which conversion is meaningful depends on what
the value is, and the three types do not offer the same set:

| Type | Conversions |
| ---- | ----------- |
| [TomZonedDate](#tomzoneddate) | `convertToTzSameInstant`, `convertToTzSameDate` |
| [TomZonedTime](#tomzonedtime) | `convertToTzSameInstant`, `convertToTzSameTime` |
| [TomZonedDateTime](#tomzoneddatetime) | `convertToTzSameInstant` only — it names an instant, so a re-anchoring counterpart would have nothing to move |

A base value has no declared kind, so the only method that could be hoisted is
the instant-preserving one — and preserving the instant is the wrong answer for
a date and for a time, which is exactly why those two carry a second
conversion. Hoisting it would install that wrong default on every value whose
kind the reader has not yet established, and it would compile, so nothing would
say so.

The compile error is therefore the type system asking which kind of value this
is. Answering it costs one line:

```dart
final base = TomTimezoned.now();

// The instant and the zone are all a conversion needs.
final moved = TomZonedDateTime.fromDateTime(base, base.timezone)
    .convertToTzSameInstant(newYork);
```

Hold a value at `TomTimezoned` where the kind genuinely does not matter: as the
supertype every zoned value shares — `TomOTimezoned` binds its type parameter
to it — for the accessors above, and for a serialization round trip that
carries a value through without asking what it is.

### Equality is the instant alone

`==` and `hashCode` are `DateTime`'s: two values are equal when they name the
same UTC instant. Neither the runtime type nor the timezone takes part, and
nothing in this module overrides that — a zoned value is a `DateTime`, and that
is the equality a `DateTime` carries.

Three consequences, each of which shows up as a deduplication surprise rather
than as a compile error:

```dart
final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
final berlin = TomTimezone.fromName('Europe/Berlin')!;
final instant = DateTime.utc(2024, 6, 14, 15);

// A date and a datetime: Tokyo's midnight on the 15th *is* 15:00Z on the 14th.
TomZonedDate(year: 2024, month: 6, day: 15, timezone: tokyo) ==
    TomZonedDateTime.fromDateTime(instant, tokyo); // true, same hashCode

// Two zones, one moment.
TomZonedDateTime.fromDateTime(instant, tokyo) ==
    TomZonedDateTime.fromDateTime(instant, berlin); // true

// And a plain UTC DateTime at that instant.
TomZonedDateTime.fromDateTime(instant, tokyo) == instant; // true
```

So a `Set` does not keep one entry per type or per zone, and two such values
collide as `Map` keys. That is the right answer when the question is "the same
moment", which is what these types are for.

When the question is "the same *value*", compare what equality drops — it is
all still on the value:

| To distinguish | Compare |
| -------------- | ------- |
| A date from a time from a datetime | `runtimeType`, or `getSerializationPrefix()` |
| One zone from another | `timezone.timezone` |
| Both at once | `toString()` — the serialized form carries the prefix, the offset and the zone name |

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

// Same instant, read in another timezone
final inNewYork = dt.convertToTzSameInstant(newYork); // TomZonedDateTime
```

### TomZonedDate

Date-only values, anchored to the start of the day. **Serialization prefix**: `@D@`

```dart
final tokyo = TomTimezone.fromName('Asia/Tokyo')!;

// Create with components
final date = TomZonedDate(year: 2024, month: 6, day: 15, timezone: tokyo);

// Create from an instant: which calendar day is this, in Tokyo?
final today = TomZonedDate.fromDateTime(DateTime.now(), tokyo);
print(today.localHour); // 0 — the time of day is discarded

// Parse from string
final parsed = TomZonedDate.parseFromString(
  '@D@2024-06-14T15:00:00.000Z_+09:00_Asia/Tokyo'
);

// Check if a DateTime is date-only
if (TomZonedDate.isDate(someDateTime)) { ... }

// Two different questions, two methods, because they give different answers.
// "When was this, over there" — the instant is kept, so the local day moves
// and the result carries a time of day:
final momentInNY = date.convertToTzSameInstant(newYork); // 14th, 11:00

// "What date is this, expressed over there" — the day is kept and re-anchored
// to midnight, so the result is still a well-formed date:
final dateInNY = date.convertToTzSameDate(newYork);      // 15th, 00:00
```

Only the second is *closed* over `TomZonedDate`. Preserving an instant across
zones necessarily moves the local day and introduces a time of day — the two
things this type's anchoring otherwise guarantees it has not got — so
`convertToTzSameInstant` answers a real question and hands back a value that no
longer satisfies `isDate`. Reach for `convertToTzSameDate` whenever the date is
a label rather than a moment, which is what a holiday, a birthday and an
invoice date all are.

`fromDateTime` asks its question of the *target* timezone, so the day it picks
can differ from the UTC one: 22:30 UTC is already tomorrow in Tokyo.

`isDate` reads a value that knows its zone — a `TomTimezoned`, or any
`TZDateTime` — in that zone, which is the frame the anchor is defined in, and
compares it against the first instant of the local day. So every well-formed
`TomZonedDate` passes wherever it is anchored, even though the UTC components it
stores are not midnight. A plain `DateTime` carries no zone to be read in and is
judged on its components alone.

The anchor is local midnight almost always, but not quite, and the exception is
worth knowing because it looks like corruption when you first meet it. A few
zones spring forward *at* midnight — Chile, Cuba, Lebanon, Egypt, Paraguay and
the Azores each do so once a year, seven zone-days in 2024 and five in 2025 —
and on those days 00:00 never happens, so the day begins at 01:00:

```dart
final santiago = TomTimezone.fromName('America/Santiago')!;
final date = TomZonedDate(year: 2024, month: 9, day: 8, timezone: santiago);
print(date.localHour);            // 1, not 0 — midnight was skipped
print(TomZonedDate.isDate(date)); // true — still the start of that day
```

Both constructors ask the timezone database for that instant instead of forcing
the components to zero, so they agree with each other and the value round-trips
through its serialized form. Code that tests for a date by checking
`localHour == 0` disagrees with all of them on those days; call `isDate`.

### TomZonedTime

Time-only values (date is 1970-01-01). **Serialization prefix**: `@T@`

```dart
final nyTz = TomTimezone.fromName('America/New_York')!;

// Create with components
final standup = TomZonedTime(hour: 9, minute: 0, timezone: nyTz);

// Create from an instant: what does the New York clock read?
final rightNow = TomZonedTime.fromDateTime(DateTime.now(), nyTz);
print(rightNow.localYear); // 1970 — the date is re-anchored to the epoch

// Parse from string
final parsed = TomZonedTime.parseFromString(
  '@T@1970-01-01T14:00:00.000Z_-05:00_America/New_York'
);

// Check if a DateTime is time-only
if (TomZonedTime.isTime(someDateTime)) { ... }

// "What time was that, over there" — the instant is kept, so the clock reading
// moves and the local date can leave 1970-01-01:
final momentUtc = standup.convertToTzSameInstant(TomTimezone.utc);

// "What does 09:00 mean over there" — the reading is kept and re-anchored, so
// `isTime` still holds:
final standupUtc = standup.convertToTzSameTime(TomTimezone.utc);
```

The same split as `TomZonedDate`, for the same reason: only
`convertToTzSameTime` is closed over the type. A daily standup is 09:00
wherever it is run, and a shift that starts at 22:00 starts at 22:00 in every
office — for those, the clock reading is the content and the instant is not.

`isTime` reads a `TomTimezoned` in its own timezone just as `isDate` does, so a
`TomZonedTime` passes even where the epoch anchor puts the stored date on
1969-12-31 or 1970-01-02.

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
{PREFIX}{ISO8601}_{OFFSET}_{TIMEZONE}{SPACE}
```

Three underscore-separated fields, carrying a prefix in front:

- **PREFIX**: `@D@` (date), `@T@` (time), or `@X@` (datetime)
- **ISO8601**: UTC datetime in ISO 8601 format, ending in a mandatory `Z`, with
  up to six fractional digits
- **OFFSET**: the UTC offset the zone had at that instant (`Z`, `+09:00`,
  `-05:00`, etc.)
- **TIMEZONE**: IANA timezone name

The form ends where the zone name ends, with no trailing character. That is
worth saying because the alternative is invisible: a serialized value is
compared, used as a map key and written into URLs and filenames, and a byte
nobody asked for travels into all of them without ever showing on a printed
line. The parse patterns are correspondingly exact, anchored straight after the
zone, so whitespace *inside* the form is refused.

Reading is forgiving about what **surrounds** a value: `parseFromString` and
the `isTom…String` predicates trim before matching, so a string that picked up
whitespace in transit — a padded column, a hand-edited configuration file, a
copied line — is still read, and the two agree, so a caller is never told a
string is recognisable and then refused when parsing it. What comes back is the
exact form: re-serializing a padded string writes it without the padding.

`toString()` produces the whole form, prefix included, and `parseFromString`
reads it back as it stands. `getSerializationPrefix()` exists for the other
direction — recognising which type a stored string holds before parsing it —
and is not an ingredient: prepending it to a rendering that already carries it
doubles the prefix into a string no parser accepts.

The `Z` is the only part of the string that names a point in time, so it is
required. A reading without it would have to be resolved against the zone of
whatever machine happened to be parsing, and the same string would then name
different instants on different hosts; such a string is rejected by both the
`is…String` predicates and `parseFromString`.

The offset is written for readability — it lets a stored value be understood
without a timezone database to hand — and it is consulted in exactly one case:
a zone name this runtime does not know. Where the name resolves, the zone is
authoritative, because the database also holds what that zone did at the
instant, and because it revises historical offsets, so an offset stored under
an older database is not evidence about a zone this one holds. Where the name
resolves to nothing, the offset is the only reading the string carries, and the
value is read with it — see [Error Handling](#error-handling).

The offset describes the value, not the zone today: it is the offset the zone
had at the value's own instant — `toString()` renders the zone through
`TomTimezone.toStringOn(this)` — which is also the offset every `local*`
reading is computed with. A January `America/New_York` value reads `-05:00`
and a July one `-04:00`, whichever season it is written in, so the string is
self-describing and a round trip writes it back unchanged. A date is stored as
its local midnight and carries the offset in force then; a time is stored on
1970-01-01 and carries the zone's offset on that day, since that is the offset
its local fields use.

### Examples

Exactly as produced; the quotes are there to show that nothing follows the
zone name:

```text
'@X@2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo'  TomZonedDateTime
'@D@2024-06-14T15:00:00.000Z_+09:00_Asia/Tokyo'  TomZonedDate
'@T@1970-01-01T14:00:00.000Z_+09:00_Asia/Tokyo'  TomZonedTime
'@X@2024-06-15T14:30:00.000Z_Z_UTC'              UTC
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

Thrown by `findTimezone` for every lookup it cannot satisfy — a name not in the
database, a supplied offset that does not match the zone's current one, an
offset no zone is at, and both arguments null:

```dart
try {
  TomTimezone.findTimezone('America/New_York', 540); // +9:00 doesn't match NY
} on TomTimezoneException catch (e) {
  print(e.defaultUserMessage);
}

// An unknown name throws too, with or without an offset to disagree with —
// where fromName would simply return null.
TomTimezone.findTimezone('Mars/Olympus', null);

// So does an offset no zone is at, and so do both arguments null, leaving
// nothing to look up — firstWithOffset would return null for the first.
TomTimezone.findTimezone(null, 7);    // timezone.lookup.offset_not_found
TomTimezone.findTimezone(null, null); // timezone.lookup.no_criteria
```

Each failure carries its own key, so a caller branches on the key and a
translated message never has to read the text:

| Key | Raised when | Parameters |
| --- | ----------- | ---------- |
| `timezone.lookup.name_not_found` | the name is not in this runtime's database, with or without an offset beside it | `name`, and `utcOffsetMinutes` when one was given |
| `timezone.lookup.offset_mismatch` | the named zone exists but sits elsewhere | `name`, `utcOffsetMinutes` asked for, `actualUtcOffsetMinutes` found, `at` when given |
| `timezone.lookup.offset_not_found` | no name was given and no zone is at the offset | `utcOffsetMinutes`, `at` when given |
| `timezone.lookup.no_criteria` | neither a name nor an offset was given | — |

The first two are the pair worth having apart: "there is no such zone" and
"that zone is not at that offset" are different facts about the world, and one
key could only have said "one of these happened".

One more call raises this type, and it is not a lookup:
`populateFromLocations`, the `@visibleForTesting` entry point a test uses to
drive the empty-database branch, populates **once per isolate**. A second call
throws `timezone.database.already_populated`, carrying the `loaded` and
`offered` counts, rather than replacing the database — which would detach every
`TomTimezone` a caller holds from the index it is looked up through — or
ignoring the call and keeping a database nobody asked it to keep.

### Null Returns

Most lookups return `null` for unknown values:

```dart
final tz = TomTimezone.fromName('Invalid/Zone');       // null
final offset = TomTimezone.firstWithOffset(99999);     // null
```

`findTimezone` is the one that does not: it never returns `null`. A name that is
not in the database raises `TomTimezoneException`, as does a name whose current
offset does not match a value supplied alongside it, an offset no zone is at,
and a call with both arguments null. Choose between the lookups on that
difference: `fromName` to ask whether a zone exists, `findTimezone` when its
absence is a fault.

### Format Exceptions

Thrown when parsing fails — either because the string does not match the
expected shape, or because it names a zone the database does not know:

```dart
try {
  TomZonedDateTime.parseFromString('invalid');
} on FormatException catch (e) {
  print(e.message); // Invalid TomZonedDateTime string: invalid
}

```

A zone this runtime does not know is **not** a parse failure. The string
carries an offset beside the name, and that is what the value is read with:

```dart
final value = TomZonedDateTime.parseFromString(
  '@X@2024-06-15T05:30:00.000Z_+09:00_Mars/Olympus',
);

value.timezone.timezone; // Mars/Olympus — the name it was stored under
value.localHour;         // 14 — 05:30Z read at the stored +09:00
value.toString();        // the string it came from
```

The zone it gets is a `TomTimezone.fixedOffset`: that one offset at every
instant, with no daylight saving, which is the whole of what the string says.
It does not join the database — `fromName` still answers `null` for the name —
so a value arriving over the wire cannot write to the index the process reads.
A host whose database *does* hold the zone reads the same string as the zone
itself, and the name is what makes that possible.

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
final newYorkTime = tokyoTime.convertToTzSameInstant(newYork);
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
| `dart:collection` | dart | `timezones.dart` | `UnmodifiableMapView`, `UnmodifiableListView` — the lookups hand out views onto the index rather than the index itself |
| `meta` | package | `timezones.dart` | `@visibleForTesting` only; no runtime behaviour |
| `timezone` | package | `date_timestamp.dart`, `init_tz_embedded.dart`, `init_tz_web.dart`, `timezones.dart` | The IANA database and `tz.TZDateTime`. This is the module — the Tom types are a typed, observable surface over it |
| `tom_basics` | package | `timezones.dart` | `tomLog`, at `debug` when a zone lookup falls back and at `error` when initialization fails |
| [little_things](../little_things/little_things.md) | module | `timezones.dart` | `TomException`, the base of the module's exception (`exception_base.dart`), and `convertMinutesToUtcOffset` for rendering a UTC offset (`formatting.dart`) |

Note that `date_timestamp.dart` — where `TomZonedDate`, `TomZonedTime` and
`TomZonedDateTime` live — imports only `timezone` and its sibling
`timezones.dart`. The kernel dependencies above all belong to `timezones.dart`,
the initialization and lookup half of the module.

`sync_load_refusal.dart` is the one file that imports nothing at all, and that
is what it is for: it holds the `StateError` the browser's arm raises, and a
file with no imports can be read on any platform — including the VM, where the
suite runs it.

### Platform selection is a conditional import

`timezones.dart` picks its initializer at compile time:

```dart
import 'init_tz_embedded.dart' if (dart.library.js) 'init_tz_web.dart';
```

The first entry is the **default** arm, taken wherever the condition does not
hold. Only the browser is singled out, because only the browser needs a
different implementation: it has no bundled copy of the database and fetches
one over the network. Everything else — server, CLI, test runner, Flutter on
mobile and desktop — takes `init_tz_embedded.dart` and reads the copy that
ships inside the `timezone` package.

The browser's arm holds one statement: it calls
`refuseSynchronousTimezoneLoad`, which lives in `sync_load_refusal.dart` and
raises the `StateError` above. Apart, because `init_tz_web.dart` reaches
`package:timezone/browser.dart` and so cannot be imported anywhere but a
browser, while refusing asks nothing of any platform — which is what lets the
suite run the refusal a browser meets instead of reading it out of a source
file.

So the `timezone` package is reached through `data/latest.dart` on native, the
same `data/latest.dart` under Flutter — one arm serves both — and
`browser.dart` on the web. Nothing in the calling code changes, but a platform
whose database has not been loaded fails at the first lookup rather than at
import.

The default arm carries a requirement the conditional arm does not, and it is
the reason the embedded implementation is the one sitting there. An arm reached
where no condition holds cannot assume any condition is true, so it may not
touch `dart:io` any more than it may touch `dart:js`. `data/latest.dart` meets
that bar — it is a constant and a decoder, with no file system and no network
behind it. A `standalone`-flavoured entry point would not: it reads the
database off disk and needs `dart:io`, which is precisely what a default arm
cannot have.
