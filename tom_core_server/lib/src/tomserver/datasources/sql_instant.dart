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
