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
library;

// =============================================================================
// TIME ZONE FORMATTING
// =============================================================================

/// Converts a UTC offset in minutes to an ISO 8601 formatted string.
///
/// Returns "Z" for zero offset (UTC), otherwise returns a string in the
/// format "+HH:MM" or "-HH:MM".
///
/// ## Parameters
///
/// - [totalMinutes]: The offset from UTC in minutes. Positive values
///   indicate east of UTC, negative values indicate west.
///
/// ## Returns
///
/// An ISO 8601 formatted UTC offset string.
///
/// ## Example
///
/// ```dart
/// convertMinutesToUtcOffset(0);     // "Z" (UTC)
/// convertMinutesToUtcOffset(60);    // "+01:00" (CET)
/// convertMinutesToUtcOffset(330);   // "+05:30" (IST)
/// convertMinutesToUtcOffset(-480);  // "-08:00" (PST)
/// ```
String convertMinutesToUtcOffset(int totalMinutes) {
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
