/// How an instant is written to and read back from a SQL `DATETIME(6)` column.
///
/// This is a **data source** concern, not a feature of any one module: it exists
/// because of how the MariaDB driver materialises a `DATETIME`, so every table
/// that stores an instant has the same problem and must have the same answer.
///
/// ## The trap
///
/// The driver builds a `DATETIME` column's value with `DateTime.parse` on the
/// column text, which yields a **local** `DateTime`. `DateTime.==` compares
/// `isUtc` as well as the instant, so a value written as UTC does not compare
/// equal to the value read back — even though both denote the same moment.
/// Carrying the column as `String` and converting here makes the round trip
/// exact.
///
/// A caller that writes a local `DateTime` gets a UTC one back: the same
/// instant, differently labelled, which is the right answer for a cluster whose
/// nodes must never compare wall clocks.
///
/// ## Every way an instant reaches a column goes through here
///
/// There are three routes, and they are one convention:
///
///  * **Bound as a `DateTime`** — the MariaDB bind boundary renders every bound
///    `DateTime` through [sqlInstant], whoever built the statement. A reflected
///    `@TomDbColumn<DateTime?, TomDbDateTime>` field names no conversion at all
///    and gets this on its behalf; so does the file-storage manifest, which
///    writes hand-built SQL but binds the value rather than rendering it.
///  * **Rendered explicitly before binding** — the scheduling, OAuth-state and
///    audit stores call [sqlInstant] at each seam themselves. Same text, one
///    more place to forget it. This was not a preference: `executeQuery` and
///    `executeCommand` used to hand their parameter map to the driver
///    unmarshalled, so for a hand-built statement the explicit call was the
///    only thing standing between a `DateTime` and the driver's own encoding.
///    That hole is closed, and these calls are now belt-and-braces.
///  * **Inlined as a literal** — a `DATETIME` literal in generated SQL is
///    rendered by the dialect, again through [sqlInstant].
///
/// Reading back is one route as well: `TomDbDateTime.of`, the hand-written
/// mappers and `TomGroupedRow.dateTimeValue` all go through
/// [parseOptionalSqlInstant] or [parseSqlInstant], so a column read is UTC
/// whichever shape the result took. A test reads this module and the
/// grouped-row accessors off disk and requires that no file but this one names
/// `DateTime.parse`, because a second reading of the same text is a second
/// convention and the two differ silently, by the machine's UTC offset.
///
/// The first case is why this is stated here rather than left to each entity.
/// A validity window, an expiry, a lease deadline — the instants that decide
/// something are exactly the ones an entity is most likely to carry, and the
/// wall-clock reading of whichever node happened to write the row is not an
/// answer to "when". Nodes are allowed to disagree about the zone; they are not
/// allowed to disagree about the moment.
///
/// ## The two halves an instant splits into
///
/// A `DATE` and a `TIME` column each hold part of what a `DATETIME` holds, and
/// neither is an instant: a date names a day in the calendar it was written in
/// and a time names a position within a day, so both are rendered **as
/// labelled** ([sqlDate], [sqlTimeOfDay]) where an instant is normalised to
/// UTC. They live here, beside [sqlInstant], because the three renderings are
/// one decision and reading them apart is how a caller ends up applying the
/// instant rule to a calendar value — which moves the day for half the world's
/// zones. Every route to a temporal column goes through one of the three: the
/// dialect quotes them for an inlined literal, the bind boundary passes them
/// unquoted.
///
/// The corollary for DDL: a column holding an instant is `DATETIME(6)`. A plain
/// `DATETIME` rounds the microseconds this library always writes, which moves
/// the stored moment by up to half a second — tolerable for a "when was this
/// touched" field, not for a boundary something is compared against.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Renders [value] as the UTC `DATETIME(6)` literal the columns bind.
///
/// Always UTC, always six fractional digits. A cluster whose nodes disagree
/// about the local zone must still agree about an instant, and the fixed width
/// keeps the text comparable in SQL as well as in Dart.
String sqlInstant(DateTime value) {
  final utc = value.toUtc();
  String pad(int v, int width) => v.toString().padLeft(width, '0');
  return '${pad(utc.year, 4)}-${pad(utc.month, 2)}-${pad(utc.day, 2)} '
      '${pad(utc.hour, 2)}:${pad(utc.minute, 2)}:${pad(utc.second, 2)}.'
      '${pad(utc.millisecond, 3)}${pad(utc.microsecond, 3)}';
}

/// Renders the calendar half of [value] as the `DATE` text a date column takes.
///
/// Fixed-width `YYYY-MM-DD`, components taken **as labelled** — the opposite
/// choice from [sqlInstant], and the right one for the same reason. An instant
/// is a moment, so it is normalised to the frame every node shares; a date
/// names a day *in the calendar it was written in*, and converting it to UTC
/// moves it to the previous or next day for half the world's zones.
///
/// "As labelled" is what [_labelled] establishes, and it is not what `value`'s
/// own accessors give for a [TomTimezoned]. That type stores UTC and reports
/// UTC through `year`/`month`/`day`, so reading them directly renders the day
/// the value was *converted to* rather than the day it names — which is the
/// conversion this doc comment says is not applied, applied.
String sqlDate(DateTime value) {
  final labelled = _labelled(value);
  String pad(int v, int width) => v.toString().padLeft(width, '0');
  return '${pad(labelled.year, 4)}-${pad(labelled.month, 2)}-'
      '${pad(labelled.day, 2)}';
}

/// [value]'s components as its own zone labels them.
///
/// A plain [DateTime] labels its components itself, so it is returned
/// unchanged. A [TomTimezoned] holds UTC and answers `hour` in UTC — the
/// reading a user sees is `localHour`, and `toDateTime()` is the whole value in
/// that frame — so it is converted first. Without this,
/// `TomZonedDate(year: 2026, month: 7, day: 5, timezone: 'Pacific/Kiritimati')`
/// renders as the 4th and `TomZonedTime(hour: 14, timezone: 'Asia/Tokyo')` as
/// 05:30, in both cases storing a value the caller never wrote.
///
/// The same rule the kernel applies when it classifies one of these values by
/// its components, for the same reason: the inherited components are a storage
/// detail, and the frame the anchoring was stated in is the one that means
/// anything.
DateTime _labelled(DateTime value) =>
    value is TomTimezoned ? value.toDateTime() : value;

/// Renders the clock half of [value] as the `TIME` text a time column takes.
///
/// Fixed-width `HH:MM:SS`, components taken as labelled — see [sqlDate], of
/// which this is the other half. Sub-second digits are dropped: a `TIME` with
/// no declared precision keeps whole seconds, and text the column cannot hold
/// compares unequal to the value stored from it.
String sqlTimeOfDay(DateTime value) {
  final labelled = _labelled(value);
  String pad(int v) => v.toString().padLeft(2, '0');
  return '${pad(labelled.hour)}:${pad(labelled.minute)}:'
      '${pad(labelled.second)}';
}

/// Reads a stored `DATETIME(6)` back as a UTC [DateTime].
///
/// The driver hands back the column's text; `DateTime.parse` on it alone would
/// produce a *local* `DateTime`, which compares unequal to the UTC value that
/// was written even though it denotes the same wall-clock reading. Appending
/// the zone marker is what makes the round trip exact.
DateTime parseSqlInstant(String value) {
  final text = value.trim();
  return DateTime.parse(text.endsWith('Z') ? text : '${text}Z');
}

/// Reads a stored `DATE` back as a [TomZonedDate].
///
/// The reading half of [sqlDate], and the halves have to be one pair: the
/// renderer writes the calendar components **as labelled**, so the reader takes
/// them as labelled too, anchored in UTC. What a `DATE` column cannot carry is
/// the zone — there is nowhere in `2026-07-15` to put one — so a value written
/// in `Asia/Tokyo` reads back naming the same day in UTC. The day survives, the
/// anchoring does not, and that is the price of a column SQL can order and
/// compare (see `doc/datasources.md`).
///
/// Tom's own `@D@…` serialization is accepted as well, for a date that reached
/// a text column through [TomZonedDate.toString] rather than through this
/// module's renderer. That form *does* carry its zone, so it round-trips
/// exactly.
///
/// **A trailing midnight is accepted**, because that is what the driver
/// actually hands back: a `DATE` column arrives as `2026-07-15 00:00:00.0`,
/// materialised into the same shape a `DATETIME` gets. Only midnight — a
/// trailing clock reading that is not zero means the value came from a column
/// holding a timestamp, which is a different column type read by the wrong
/// reader, and guessing which half was meant is exactly the mistake this
/// function exists to refuse.
///
/// Throws a [FormatException] on anything else, rather than guessing.
TomZonedDate parseSqlDate(String value) {
  final text = value.trim();
  if (TomZonedDate.isTomZonedDateString(text)) {
    return TomZonedDate.parseFromString(text);
  }
  final match = _sqlDatePattern.firstMatch(text);
  if (match == null) {
    throw FormatException('Not a DATE column value or a @D@ date', text);
  }
  return TomZonedDate(
    year: int.parse(match.group(1)!),
    month: int.parse(match.group(2)!),
    day: int.parse(match.group(3)!),
  );
}

/// Reads a stored `TIME` back as a [TomZonedTime].
///
/// The reading half of [sqlTimeOfDay], and the same pairing as [parseSqlDate]:
/// components as labelled, anchored in UTC, the zone not carried by the column
/// and therefore not recovered. A time written as 14:30 in any zone reads back
/// as 14:30.
///
/// The hour is read as written rather than bounded to 0-23. MariaDB's `TIME`
/// spans -838:59:59 to 838:59:59 because it doubles as an interval type, and a
/// column holding `25:00:00` is holding a duration rather than a clock reading
/// — which [TomZonedTime] cannot represent. Such a value therefore throws here
/// rather than silently wrapping into the next day: an interval stored in a
/// time-of-day column is a modelling mistake, and rolling it over would hide
/// it.
///
/// Sub-second digits are accepted and dropped, matching [sqlTimeOfDay], so a
/// column declared `TIME(6)` reads back at the precision the renderer writes.
/// Tom's own `@T@…` serialization is accepted as well, and round-trips its zone
/// exactly.
///
/// Throws a [FormatException] on anything else.
TomZonedTime parseSqlTimeOfDay(String value) {
  final text = value.trim();
  if (TomZonedTime.isTomZonedTimeString(text)) {
    return TomZonedTime.parseFromString(text);
  }
  final match = _sqlTimePattern.firstMatch(text);
  if (match == null) {
    throw FormatException('Not a TIME column value or a @T@ time', text);
  }
  final hour = int.parse(match.group(1)!);
  if (hour > 23) {
    throw FormatException(
      'TIME value $text is an interval, not a time of day: an hour past 23 '
      'has no clock reading, and TomZonedTime holds a reading',
      text,
    );
  }
  return TomZonedTime(
    hour: hour,
    minute: int.parse(match.group(2)!),
    second: int.parse(match.group(3)!),
  );
}

/// A `DATE` column's text: `YYYY-MM-DD`, as [sqlDate] writes it, optionally
/// followed by the midnight the driver appends when it materialises one.
final RegExp _sqlDatePattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})(?:[ T]00:00(?::00(?:\.0+)?)?)?$',
);

/// A `TIME` column's text: `HH:MM:SS`, with the sub-second digits MariaDB adds
/// for a `TIME(n)` column optional and discarded.
///
/// The hour is one-or-more digits because MariaDB writes three for a value past
/// 99 hours; [parseSqlTimeOfDay] is what refuses those, with a message about
/// what they mean rather than about the pattern.
final RegExp _sqlTimePattern = RegExp(r'^(\d{1,3}):(\d{2}):(\d{2})(\.\d+)?$');

/// Reads an optional stored `DATETIME(6)`, treating an empty column as absent.
///
/// The driver reports a `NULL` instant column as either `null` or the empty
/// string depending on the row mapper, and every caller has to collapse the two
/// the same way — so it is collapsed once, here.
DateTime? parseOptionalSqlInstant(String? value) =>
    value == null || value.isEmpty ? null : parseSqlInstant(value);
