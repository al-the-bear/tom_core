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
/// Reading back is one route: `TomDbDateTime.of` and the hand-written mappers
/// both go through [parseOptionalSqlInstant], so a column read is UTC.
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
String sqlDate(DateTime value) {
  String pad(int v, int width) => v.toString().padLeft(width, '0');
  return '${pad(value.year, 4)}-${pad(value.month, 2)}-${pad(value.day, 2)}';
}

/// Renders the clock half of [value] as the `TIME` text a time column takes.
///
/// Fixed-width `HH:MM:SS`, components taken as labelled — see [sqlDate], of
/// which this is the other half. Sub-second digits are dropped: a `TIME` with
/// no declared precision keeps whole seconds, and text the column cannot hold
/// compares unequal to the value stored from it.
String sqlTimeOfDay(DateTime value) {
  String pad(int v) => v.toString().padLeft(2, '0');
  return '${pad(value.hour)}:${pad(value.minute)}:${pad(value.second)}';
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

/// Reads an optional stored `DATETIME(6)`, treating an empty column as absent.
///
/// The driver reports a `NULL` instant column as either `null` or the empty
/// string depending on the row mapper, and every caller has to collapse the two
/// the same way — so it is collapsed once, here.
DateTime? parseOptionalSqlInstant(String? value) =>
    value == null || value.isEmpty ? null : parseSqlInstant(value);
