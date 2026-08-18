/// Formatting utilities for common data transformations.
///
/// This library provides helper functions for formatting data, particularly
/// around time and date handling:
///
/// - [convertMinutesToUtcOffset] - Converts minute offsets to UTC offset strings
///
/// ## Example
///
/// ```dart
/// // Convert timezone offset to ISO 8601 format
/// print(convertMinutesToUtcOffset(0));    // "Z"
/// print(convertMinutesToUtcOffset(330));  // "+05:30" (IST)
/// print(convertMinutesToUtcOffset(-300)); // "-05:00" (EST)
/// ```
///
/// Offsets are bounded to ±14:00, the range real timezones occupy; anything
/// wider throws [TomFormattingException] rather than producing a string no
/// ISO 8601 parser accepts.
library;

import 'exception_base.dart';

// =============================================================================
// EXCEPTIONS
// =============================================================================

/// Thrown when a formatting function is given a value it cannot render.
///
/// The rest of this module deliberately does not throw — [tomGetStackTrace]
/// and friends run while reporting some other failure, so raising there would
/// lose it. That reasoning does not reach here: [convertMinutesToUtcOffset]
/// renders timezone data on the ordinary path, where a value it cannot express
/// is a caller bug worth surfacing rather than a crash report worth saving.
class TomFormattingException extends TomException {
  /// Creates a formatting exception with the given [key] and message.
  TomFormattingException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

// =============================================================================
// TIME ZONE FORMATTING
// =============================================================================

/// The widest UTC offset, in minutes, that [convertMinutesToUtcOffset] can
/// render — ±14:00.
///
/// Measured rather than assumed. Scanning every location's transition table in
/// the packaged IANA data yields reachable offsets from -720 (Pacific/Kanton)
/// to +840 (Asia/Anadyr) and nothing outside, so this bound never rejects a
/// value the timezone API can produce. It is *inclusive* precisely because
/// Asia/Anadyr sits exactly on it; an exclusive bound would break a real zone.
///
/// The raw `zones` tables do carry a few wider historical LMT records — Asia/
/// Manila at -956, America/Metlakatla at +913 — but no transition selects
/// them, so they are unreachable and do not widen the bound.
const int _maxUtcOffsetMinutes = 840;

/// Converts a UTC offset in minutes to an ISO 8601 formatted string.
///
/// Returns "Z" for zero offset (UTC), otherwise returns a string in the
/// format "+HH:MM" or "-HH:MM".
///
/// ## Parameters
///
/// - [totalMinutes]: The offset from UTC in minutes. Positive values
///   indicate east of UTC, negative values indicate west. Must be within
///   ±840 (±14:00) inclusive — the range real timezones occupy.
///
/// ## Returns
///
/// An ISO 8601 formatted UTC offset string.
///
/// ## Throws
///
/// [TomFormattingException] (`formatting.utc_offset.out_of_range`) when
/// [totalMinutes] lies outside ±840. The hour field is two digits wide, so a
/// larger offset could only be rendered as something like `+100:00` — a string
/// no ISO 8601 parser accepts. Failing is the honest outcome: the value did
/// not come from a timezone, and there is no correct way to write it.
///
/// ## Example
///
/// ```dart
/// convertMinutesToUtcOffset(0);     // "Z" (UTC)
/// convertMinutesToUtcOffset(60);    // "+01:00" (CET)
/// convertMinutesToUtcOffset(330);   // "+05:30" (IST)
/// convertMinutesToUtcOffset(-480);  // "-08:00" (PST)
/// convertMinutesToUtcOffset(840);   // "+14:00" (Line Islands, the maximum)
/// convertMinutesToUtcOffset(6000);  // throws TomFormattingException
/// ```
String convertMinutesToUtcOffset(int totalMinutes) {
  // Two explicit comparisons rather than the shorter `totalMinutes.abs() >
  // _maxUtcOffsetMinutes`: in Dart the most negative int is its own `abs()`,
  // so that form waves through the one input least able to survive the
  // arithmetic below.
  if (totalMinutes < -_maxUtcOffsetMinutes ||
      totalMinutes > _maxUtcOffsetMinutes) {
    throw TomFormattingException(
      'formatting.utc_offset.out_of_range',
      'UTC offset must be within ±$_maxUtcOffsetMinutes minutes (±14:00); '
          'got $totalMinutes.',
      parameters: {'totalMinutes': totalMinutes},
    );
  }
  if (totalMinutes == 0) {
    return "Z";
  }
  String sign = totalMinutes < 0 ? "-" : "+";
  int absMinutes = totalMinutes.abs();
  int hours = absMinutes ~/ 60;
  int minutes = absMinutes % 60;
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  return "$sign${twoDigits(hours)}:${twoDigits(minutes)}";
}
