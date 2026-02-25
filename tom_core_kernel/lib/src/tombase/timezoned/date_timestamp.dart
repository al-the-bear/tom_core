import 'package:timezone/timezone.dart' as tz;

import 'timezones.dart';

/// Base class for timezone-aware date/time values.
///
/// [TomTimezoned] extends [DateTime] to add timezone awareness. The internal
/// DateTime is always stored in UTC, representing the actual moment in time.
/// Accessors like [localYear], [localMonth], [localDay], [localHour], etc.
/// return the local time values in the associated timezone.
///
/// ## Serialization Format
///
/// TomTimezoned values serialize to a string format that includes:
/// - ISO 8601 datetime (always in UTC)
/// - UTC offset at the time of serialization
/// - Timezone name
///
/// Format: `ISO8601_OFFSET_TIMEZONE`
/// Example: `2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo`
///
/// ## Subclasses
///
/// Three specialized subclasses are provided:
/// - [TomZonedDate] - For date-only values (time components are zero)
/// - [TomZonedTime] - For time-only values (date is 1970-01-01)
/// - [TomZonedDateTime] - For full datetime values
///
/// Each has its own serialization prefix for identification:
/// - `@D@` for dates
/// - `@T@` for times
/// - `@X@` for datetimes
///
/// ## Usage
///
/// ```dart
/// // Create from local time with timezone
/// final tokyo = TomTimezone.fromName('Asia/Tokyo');
/// final tt = TomZonedDateTime(
///   year: 2024, month: 6, day: 15, hour: 14, minute: 30,
///   timezone: tokyo,
/// );
/// print(tt.localHour); // 14 (local time in Tokyo)
/// print(tt.hour);      // 5 (UTC time)
///
/// // Parse from serialized string
/// final parsed = TomTimezoned.parseFromString('2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo');
/// ```
class TomTimezoned extends DateTime {

  TomTimezone _timezone = TomTimezone.utc;
  
  /// Returns the timezone associated with this datetime.
  ///
  /// The timezone is preserved from creation and used for display
  /// and timezone conversion operations.
  TomTimezone get timezone => _timezone;

  /// Returns the serialization prefix for this type.
  ///
  /// The base class returns an empty string. Subclasses override this
  /// to provide type-specific prefixes:
  /// - [TomZonedDate]: `@D@`
  /// - [TomZonedTime]: `@T@`
  /// - [TomZonedDateTime]: `@X@`
  String getSerializationPrefix() => '';

  /// Internal constructor that takes already-computed UTC values.
  /// 
  /// Used by factories and subclasses after they've converted local time to UTC.
  TomTimezoned._fromUtc({
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
    required int second,
    required int millisecond,
    required int microsecond,
    TomTimezone? timezone,
  }) : super.utc(year, month, day, hour, minute, second, millisecond, microsecond) {
    _timezone = timezone ?? TomTimezone.utc;
  }

  /// Creates a [TomTimezoned] with the specified components in local timezone time.
  ///
  /// The provided values are interpreted as local time in the given timezone,
  /// then converted to UTC for internal storage.
  ///
  /// [year] The year in local time.
  /// [month] The month 1-12 in local time (defaults to 1).
  /// [day] The day of month in local time (defaults to 1).
  /// [hour] The hour 0-23 in local time (defaults to 0).
  /// [minute] The minute 0-59 in local time (defaults to 0).
  /// [second] The second 0-59 in local time (defaults to 0).
  /// [millisecond] The millisecond 0-999 (defaults to 0).
  /// [microsecond] The microsecond 0-999 (defaults to 0).
  /// [timezone] The timezone for the local time values (defaults to UTC).
  ///
  /// Example:
  /// ```dart
  /// final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
  /// final tt = TomTimezoned(
  ///   year: 2024, month: 6, day: 15,
  ///   hour: 14, minute: 30,
  ///   timezone: tokyo,
  /// );
  /// print(tt.localHour); // 14 (local Tokyo time)
  /// print(tt.hour);      // 5 (UTC)
  /// ```
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
  }) {
    final tz_ = timezone ?? TomTimezone.utc;
    // Convert local time to UTC using TZDateTime
    final localTime = tz.TZDateTime(tz_.location, year, month, day, hour, minute, second, millisecond, microsecond);
    final utcTime = localTime.toUtc();
    return TomTimezoned._fromUtc(
      year: utcTime.year,
      month: utcTime.month,
      day: utcTime.day,
      hour: utcTime.hour,
      minute: utcTime.minute,
      second: utcTime.second,
      millisecond: utcTime.millisecond,
      microsecond: utcTime.microsecond,
      timezone: tz_,
    );
  }

  /// Creates a [TomTimezoned] in UTC with the specified components.
  ///
  /// All time components are stored as-is (they are already UTC).
  TomTimezoned.utc({
    int year = 1970,
    int month = 1,
    int day = 1,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
    int microsecond = 0,
  }) : super.utc(year, month, day, hour, minute, second, millisecond, microsecond);

  /// Creates a [TomTimezoned] representing the current time.
  ///
  /// The current time is captured in UTC and associated with the provided
  /// timezone (defaults to UTC if not specified).
  ///
  /// [timezone] The timezone to associate with this datetime.
  ///
  /// Example:
  /// ```dart
  /// final now = TomTimezoned.now(TomTimezone.fromName('Europe/London'));
  /// print(now.timezone.timezone); // 'Europe/London'
  /// ```
  factory TomTimezoned.now([TomTimezone? timezone]) {
    DateTime nowUtc = DateTime.now().toUtc();
    return TomTimezoned._fromUtc(
      year: nowUtc.year,
      month: nowUtc.month,
      day: nowUtc.day,
      hour: nowUtc.hour,
      minute: nowUtc.minute,
      second: nowUtc.second,
      millisecond: nowUtc.millisecond,
      microsecond: nowUtc.microsecond,
      timezone: timezone,
    );
  }

  /// Creates a [TomTimezoned] from an existing [DateTime].
  ///
  /// The DateTime is converted to UTC before storing. The provided timezone
  /// is associated for display and conversion purposes.
  ///
  /// [dateTime] The DateTime to convert.
  /// [timezone] The timezone to associate (defaults to UTC).
  ///
  /// Example:
  /// ```dart
  /// final local = DateTime.now();
  /// final tt = TomTimezoned.fromDateTime(local, TomTimezone.utc);
  /// print(tt.isUtc); // true
  /// ```
  factory TomTimezoned.fromDateTime(
    DateTime dateTime, [
    TomTimezone? timezone,
  ]) {
    var dt = dateTime.toUtc();
    return TomTimezoned._fromUtc(
      year: dt.year,
      month: dt.month,
      day: dt.day,
      hour: dt.hour,
      minute: dt.minute,
      second: dt.second,
      millisecond: dt.millisecond,
      microsecond: dt.microsecond,
      timezone: timezone,
    );
  }

  /// Parses a [TomTimezoned] from its serialized string format.
  ///
  /// The string must be in the format: `ISO8601_OFFSET_TIMEZONE`
  /// Example: `2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo`
  ///
  /// Throws [FormatException] if the string format is invalid.
  ///
  /// Example:
  /// ```dart
  /// final tt = TomTimezoned.parseFromString(
  ///   '2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo'
  /// );
  /// print(tt.timezone.timezone); // 'Asia/Tokyo'
  /// ```
  factory TomTimezoned.parseFromString(String formattedString) {
    if (!TomTimezoned.isTomTimezonedString(formattedString)) {
      throw FormatException("Invalid TomTimezoned string: $formattedString");
    }
    // Format: ISO8601_offset_timezone
    final match = RegExp(
      r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z?)_(Z|[+-]\d{2}:\d{2})_([a-zA-Z0-9_/-]+)\s?$",
    ).firstMatch(formattedString.trim());
    if (match == null) {
      throw FormatException("Failed to parse TomTimezoned string: $formattedString");
    }
    String dateTimeStr = match.group(1)!;
    String zone = match.group(3)!;
    DateTime dt = DateTime.parse(dateTimeStr).toUtc();
    return TomTimezoned.fromDateTime(dt, TomTimezone.fromName(zone));
  }

  /// Returns the string representation of this datetime.
  ///
  /// Format: `ISO8601_OFFSET_TIMEZONE`
  /// Example: `2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo`
  @override
  String toString() {
    return "${super.toIso8601String()}_$_timezone";
  }

  /// Checks if a string is in valid [TomTimezoned] format.
  ///
  /// Returns `true` if the string matches the expected serialization format.
  static bool isTomTimezonedString(String s) {
    return RegExp(
      r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?Z?_(Z|[+-]\d{2}:\d{2})_[a-zA-Z0-9_/-]+\s?$",
    ).hasMatch(s);
  }

  // =========================================================================
  // Local time accessors - return values in the associated timezone
  // =========================================================================

  /// Returns the year in the local timezone.
  int get localYear => _toLocal().year;

  /// Returns the month (1-12) in the local timezone.
  int get localMonth => _toLocal().month;

  /// Returns the day of month (1-31) in the local timezone.
  int get localDay => _toLocal().day;

  /// Returns the hour (0-23) in the local timezone.
  int get localHour => _toLocal().hour;

  /// Returns the minute (0-59) in the local timezone.
  int get localMinute => _toLocal().minute;

  /// Returns the second (0-59) in the local timezone.
  int get localSecond => _toLocal().second;

  /// Returns the millisecond (0-999) in the local timezone.
  int get localMillisecond => _toLocal().millisecond;

  /// Returns the microsecond (0-999) in the local timezone.
  int get localMicrosecond => _toLocal().microsecond;

  /// Returns the weekday in the local timezone (1=Monday, 7=Sunday).
  int get localWeekday => _toLocal().weekday;

  /// Converts the stored UTC time to a TZDateTime in the local timezone.
  tz.TZDateTime _toLocal() {
    return tz.TZDateTime.from(this, _timezone.location);
  }

  /// Converts this [TomTimezoned] to a [DateTime] in its timezone.
  ///
  /// Returns the local time representation in the associated timezone.
  /// The returned DateTime is actually a TZDateTime which provides
  /// timezone-aware local time values.
  ///
  /// Example:
  /// ```dart
  /// final tt = TomZonedDateTime(
  ///   year: 2024, month: 6, day: 15, hour: 14,
  ///   timezone: TomTimezone.fromName('America/New_York'),
  /// );
  /// final localDt = tt.toDateTime();
  /// print(localDt.hour); // 14 (local time in New York)
  /// ```
  DateTime toDateTime() {
    return _toLocal();
  }

}

/// A timezone-aware date value (without time components).
///
/// [TomZonedDate] represents a calendar date associated with a specific timezone.
/// All time components (hour, minute, second, etc.) are set to zero in the local timezone.
///
/// ## Serialization
///
/// Serializes with the `@D@` prefix:
/// ```
/// @D@2024-06-14T15:00:00.000Z_+09:00_Asia/Tokyo
/// ```
/// (midnight June 15 Tokyo = 15:00 June 14 UTC)
///
/// ## Usage
///
/// ```dart
/// // Create a date in a specific timezone
/// final tokyo = TomTimezone.fromName('Asia/Tokyo');
/// final date = TomZonedDate(year: 2024, month: 6, day: 15, timezone: tokyo);
/// print(date.localDay); // 15 (local day in Tokyo)
///
/// // Parse from string
/// final parsed = TomZonedDate.parseFromString('@D@2024-06-14T15:00:00.000Z_+09:00_Asia/Tokyo');
/// print(parsed.localDay); // 15 (local day in Tokyo)
/// ```
class TomZonedDate extends TomTimezoned {
  
  /// The serialization prefix for date values.
  ///
  /// All [TomZonedDate] strings start with `@D@` to identify the type.
  static const String serializationPrefix = "@D@";
  
  /// Returns the serialization prefix for this date type.
  @override
  String getSerializationPrefix() => serializationPrefix;

  /// Creates a [TomZonedDate] with the specified date components in the local timezone.
  ///
  /// Time components are automatically set to midnight (00:00:00) in the local timezone.
  /// The values are then converted to UTC for internal storage.
  ///
  /// [year] The year in local time (defaults to 1970).
  /// [month] The month 1-12 in local time (defaults to 1).
  /// [day] The day 1-31 in local time (defaults to 1).
  /// [timezone] The timezone for the local time values (defaults to UTC).
  factory TomZonedDate({
    int year = 1970,
    int month = 1,
    int day = 1,
    TomTimezone? timezone,
  }) {
    final tz_ = timezone ?? TomTimezone.utc;
    // Create midnight in the local timezone
    final localMidnight = tz.TZDateTime(tz_.location, year, month, day, 0, 0, 0, 0, 0);
    // Convert to UTC
    final utcTime = localMidnight.toUtc();
    return TomZonedDate._fromUtcValues(
      utcYear: utcTime.year,
      utcMonth: utcTime.month,
      utcDay: utcTime.day,
      utcHour: utcTime.hour,
      utcMinute: utcTime.minute,
      utcSecond: utcTime.second,
      utcMillisecond: utcTime.millisecond,
      utcMicrosecond: utcTime.microsecond,
      timezone: tz_,
    );
  }

  /// Internal constructor from UTC values.
  TomZonedDate._fromUtcValues({
    required int utcYear,
    required int utcMonth,
    required int utcDay,
    required int utcHour,
    required int utcMinute,
    required int utcSecond,
    required int utcMillisecond,
    required int utcMicrosecond,
    required TomTimezone timezone,
  }) : super._fromUtc(
          year: utcYear,
          month: utcMonth,
          day: utcDay,
          hour: utcHour,
          minute: utcMinute,
          second: utcSecond,
          millisecond: utcMillisecond,
          microsecond: utcMicrosecond,
          timezone: timezone,
        );

  /// Creates a [TomZonedDate] from an existing [DateTime].
  ///
  /// The DateTime is assumed to already be in UTC. The date portion
  /// from the UTC DateTime is used.
  ///
  /// [dtx] The DateTime to extract the date from.
  /// [timezone] The timezone to associate (defaults to UTC).
  ///
  /// Example:
  /// ```dart
  /// final now = DateTime.now();
  /// final todayInTokyo = TomZonedDate.fromDateTime(
  ///   now,
  ///   TomTimezone.fromName('Asia/Tokyo'),
  /// );
  /// ```
  factory TomZonedDate.fromDateTime(DateTime dtx, [TomTimezone? timezone]) {
    final dt = dtx.isUtc ? dtx : dtx.toUtc();
    final tz_ = timezone ?? TomTimezone.utc;
    return TomZonedDate._fromUtcValues(
      utcYear: dt.year,
      utcMonth: dt.month,
      utcDay: dt.day,
      utcHour: dt.hour,
      utcMinute: dt.minute,
      utcSecond: dt.second,
      utcMillisecond: dt.millisecond,
      utcMicrosecond: dt.microsecond,
      timezone: tz_,
    );
  }

  /// Parses a [TomZonedDate] from its serialized string format.
  ///
  /// The string must start with `@D@` and follow the format:
  /// `@D@ISO8601_OFFSET_TIMEZONE`
  ///
  /// [formattedString] The serialized date string.
  ///
  /// Throws [FormatException] if the string format is invalid.
  ///
  /// Example:
  /// ```dart
  /// final date = TomZonedDate.parseFromString(
  ///   '@D@2024-06-14T15:00:00.000Z_+09:00_Asia/Tokyo'
  /// );
  /// print(date.localYear);  // 2024
  /// print(date.localMonth); // 6
  /// print(date.localDay);   // 15
  /// ```
  factory TomZonedDate.parseFromString(String formattedString) {
    if (!TomZonedDate.isTomZonedDateString(formattedString)) {
      throw FormatException("Invalid TomZonedDate string: $formattedString");
    }
    final match = RegExp(
      r"^@D@(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z?)_(Z|[+-]\d{2}:\d{2})_([a-zA-Z0-9_/-]+)\s?$",
    ).firstMatch(formattedString.trim());
    if (match == null) {
      throw FormatException("Failed to parse TomZonedDate string: $formattedString");
    }
    String dateTimeStr = match.group(1)!;
    String zone = match.group(3)!;
    DateTime dt = DateTime.parse(dateTimeStr).toUtc();
    return TomZonedDate.fromDateTime(dt, TomTimezone.fromName(zone));
  }

  /// Returns the serialized string representation of this date.
  ///
  /// Format: `@D@ISO8601_OFFSET_TIMEZONE`
  /// Example: `@D@2024-06-14T15:00:00.000Z_+09:00_Asia/Tokyo`
  @override
  String toString() {
    return "${TomZonedDate.serializationPrefix}${super.toIso8601String()}_$_timezone";
  }

  /// Checks if a string is in valid [TomZonedDate] format.
  ///
  /// Returns `true` if the string starts with `@D@` and matches
  /// the expected serialization format.
  static bool isTomZonedDateString(String s) {
    return RegExp(r"^@D@\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?Z?_(Z|[+-]\d{2}:\d{2})_[a-zA-Z0-9_/-]+\s?$").hasMatch(s);
  }

  /// Checks if a [DateTime] represents a date-only value.
  ///
  /// Returns `true` if all time components (hour, minute, second,
  /// millisecond, microsecond) are zero.
  static bool isDate(DateTime dt) {
    return dt.hour == 0 &&
        dt.minute == 0 &&
        dt.second == 0 &&
        dt.millisecond == 0 &&
        dt.microsecond == 0;
  }

  /// Converts this date to another timezone.
  ///
  /// Returns a new [TomZonedDate] representing the same instant in time
  /// but displayed in a different timezone.
  ///
  /// [targetTimezone] The timezone to convert to.
  ///
  /// Example:
  /// ```dart
  /// final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
  /// final nyTz = TomTimezone.fromName('America/New_York')!;
  ///
  /// final dateInTokyo = TomZonedDate(
  ///   year: 2024, month: 6, day: 15,
  ///   timezone: tokyo,
  /// );
  ///
  /// final dateInNY = dateInTokyo.convertToTimezone(nyTz);
  /// print(dateInNY.timezone.timezone); // 'America/New_York'
  /// ```
  TomZonedDate convertToTimezone(TomTimezone targetTimezone) {
    // The UTC time stays the same, just change the timezone
    return TomZonedDate._fromUtcValues(
      utcYear: year,
      utcMonth: month,
      utcDay: day,
      utcHour: hour,
      utcMinute: minute,
      utcSecond: second,
      utcMillisecond: millisecond,
      utcMicrosecond: microsecond,
      timezone: targetTimezone,
    );
  }
}

/// A timezone-aware time value (without date components).
///
/// [TomZonedTime] represents a time of day associated with a specific timezone.
/// The date components are set to the Unix epoch (1970-01-01) as a placeholder.
///
/// ## Serialization
///
/// Serializes with the `@T@` prefix:
/// ```
/// @T@1970-01-01T05:30:00.000Z_+09:00_Asia/Tokyo
/// ```
/// (14:30 Tokyo = 05:30 UTC)
///
/// ## Usage
///
/// ```dart
/// // Create a time in a specific timezone
/// final tokyo = TomTimezone.fromName('Asia/Tokyo');
/// final time = TomZonedTime(hour: 14, minute: 30, timezone: tokyo);
/// print(time.localHour); // 14 (local time in Tokyo)
/// print(time.hour);      // 5 (UTC time)
///
/// // Parse from string
/// final parsed = TomZonedTime.parseFromString('@T@1970-01-01T05:30:00.000Z_+09:00_Asia/Tokyo');
/// ```
class TomZonedTime extends TomTimezoned {
  
  /// The serialization prefix for time values.
  ///
  /// All [TomZonedTime] strings start with `@T@` to identify the type.
  static const String serializationPrefix = "@T@";
  
  /// Returns the serialization prefix for this time type.
  @override
  String getSerializationPrefix() => serializationPrefix;

  /// Creates a [TomZonedTime] with the specified time components in the local timezone.
  ///
  /// Date components are set to 1970-01-01 (Unix epoch).
  /// The time values are interpreted as local time in the timezone,
  /// then converted to UTC for internal storage.
  ///
  /// [hour] The hour 0-23 in local time (defaults to 0).
  /// [minute] The minute 0-59 in local time (defaults to 0).
  /// [second] The second 0-59 in local time (defaults to 0).
  /// [millisecond] The millisecond 0-999 (defaults to 0).
  /// [microsecond] The microsecond 0-999 (defaults to 0).
  /// [timezone] The timezone for the local time values (defaults to UTC).
  factory TomZonedTime({
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
    int microsecond = 0,
    TomTimezone? timezone,
  }) {
    final tz_ = timezone ?? TomTimezone.utc;
    // Create time on 1970-01-01 in local timezone
    final localTime = tz.TZDateTime(tz_.location, 1970, 1, 1, hour, minute, second, millisecond, microsecond);
    // Convert to UTC
    final utcTime = localTime.toUtc();
    return TomZonedTime._fromUtcValues(
      utcYear: utcTime.year,
      utcMonth: utcTime.month,
      utcDay: utcTime.day,
      utcHour: utcTime.hour,
      utcMinute: utcTime.minute,
      utcSecond: utcTime.second,
      utcMillisecond: utcTime.millisecond,
      utcMicrosecond: utcTime.microsecond,
      timezone: tz_,
    );
  }

  /// Internal constructor from UTC values.
  TomZonedTime._fromUtcValues({
    required int utcYear,
    required int utcMonth,
    required int utcDay,
    required int utcHour,
    required int utcMinute,
    required int utcSecond,
    required int utcMillisecond,
    required int utcMicrosecond,
    required TomTimezone timezone,
  }) : super._fromUtc(
          year: utcYear,
          month: utcMonth,
          day: utcDay,
          hour: utcHour,
          minute: utcMinute,
          second: utcSecond,
          millisecond: utcMillisecond,
          microsecond: utcMicrosecond,
          timezone: timezone,
        );

  /// Creates a [TomZonedTime] from an existing [DateTime].
  ///
  /// The time portion from the UTC-converted DateTime is used.
  ///
  /// [dtx] The DateTime to extract the time from.
  /// [timezone] The timezone to associate (defaults to UTC).
  factory TomZonedTime.fromDateTime(DateTime dtx, [TomTimezone? timezone]) {
    final dt = dtx.toUtc();
    final tz_ = timezone ?? TomTimezone.utc;
    return TomZonedTime._fromUtcValues(
      utcYear: dt.year,
      utcMonth: dt.month,
      utcDay: dt.day,
      utcHour: dt.hour,
      utcMinute: dt.minute,
      utcSecond: dt.second,
      utcMillisecond: dt.millisecond,
      utcMicrosecond: dt.microsecond,
      timezone: tz_,
    );
  }

  /// Parses a [TomZonedTime] from its serialized string format.
  ///
  /// The string must start with `@T@` and follow the format:
  /// `@T@ISO8601_OFFSET_TIMEZONE`
  ///
  /// [formattedString] The serialized time string.
  ///
  /// Throws [FormatException] if the string format is invalid.
  factory TomZonedTime.parseFromString(String formattedString) {
    if (!TomZonedTime.isTomZonedTimeString(formattedString)) {
      throw FormatException("Invalid TomZonedTime string: $formattedString");
    }
    final match = RegExp(
      r"^@T@(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z?)_(Z|[+-]\d{2}:\d{2})_([a-zA-Z0-9_/-]+)\s?$",
    ).firstMatch(formattedString.trim());
    if (match == null) {
      throw FormatException("Failed to parse TomZonedTime string: $formattedString");
    }
    String dateTimeStr = match.group(1)!;
    String zone = match.group(3)!;
    DateTime dt = DateTime.parse(dateTimeStr).toUtc();
    return TomZonedTime.fromDateTime(dt, TomTimezone.fromName(zone));
  }

  /// Returns the serialized string representation of this time.
  ///
  /// Format: `@T@ISO8601_OFFSET_TIMEZONE`
  /// Example: `@T@1970-01-01T05:30:00.000Z_+09:00_Asia/Tokyo`
  @override
  String toString() {
    return "${TomZonedTime.serializationPrefix}${super.toIso8601String()}_$_timezone";
  }

  /// Checks if a string is in valid [TomZonedTime] format.
  static bool isTomZonedTimeString(String s) {
    return RegExp(
      r"^@T@\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?Z?_(Z|[+-]\d{2}:\d{2})_[a-zA-Z0-9_/-]+\s?$",
    ).hasMatch(s);
  }

  /// Checks if a [DateTime] represents a time-only value.
  ///
  /// Returns `true` if the date components are 1970-01-01 (Unix epoch).
  static bool isTime(DateTime dt) {
    return dt.year == 1970 && dt.month == 1 && dt.day == 1;
  }

  /// Converts this time to another timezone.
  ///
  /// Returns a new [TomZonedTime] representing the same instant in time
  /// but displayed in a different timezone.
  ///
  /// [targetTimezone] The timezone to convert to.
  TomZonedTime convertToTimezone(TomTimezone targetTimezone) {
    // The UTC time stays the same, just change the timezone
    return TomZonedTime._fromUtcValues(
      utcYear: year,
      utcMonth: month,
      utcDay: day,
      utcHour: hour,
      utcMinute: minute,
      utcSecond: second,
      utcMillisecond: millisecond,
      utcMicrosecond: microsecond,
      timezone: targetTimezone,
    );
  }

  /// Returns a [DateTime] representing this time on the given date.
  ///
  /// This method applies the local time values (hour, minute, second, etc.)
  /// from this [TomZonedTime] to the date from [when], creating a full
  /// datetime in this timezone.
  ///
  /// This is useful when you have a recurring time (e.g., daily standup at 9:00)
  /// and want to calculate the actual moment for a specific date, accounting
  /// for DST transitions.
  ///
  /// [when] The date on which to apply this time. Only the date portion is used.
  ///
  /// Returns a [DateTime] with this time on the given date in this timezone.
  /// The returned DateTime is actually a TZDateTime which provides timezone-aware
  /// local time values.
  ///
  /// Example:
  /// ```dart
  /// final standup = TomZonedTime(hour: 9, minute: 0, timezone: nyTz);
  /// 
  /// // Get the actual time for a specific date
  /// final march10 = DateTime(2024, 3, 10);
  /// final standupOnMarch10 = standup.inTimezoneOn(march10);
  /// print(standupOnMarch10); // 2024-03-10 09:00:00.000-0400 (EDT after DST)
  /// ```
  DateTime inTimezoneOn(DateTime when) {
    // Create a TZDateTime with the date from 'when' and time from this TomZonedTime
    return tz.TZDateTime(
      _timezone.location,
      when.year,
      when.month,
      when.day,
      localHour,
      localMinute,
      localSecond,
      localMillisecond,
      localMicrosecond,
    );
  }
}

/// A timezone-aware full datetime value.
///
/// [TomZonedDateTime] represents a complete date and time associated with
/// a specific timezone. This is the most commonly used timezone-aware type.
///
/// ## Internal Representation
///
/// The datetime is stored internally as UTC. When you create a TomZonedDateTime
/// with local time values, they are converted to UTC. Use [localHour], [localDay],
/// etc. to get the local time values in the timezone.
///
/// ## Serialization
///
/// Serializes with the `@X@` prefix:
/// ```
/// @X@2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo
/// ```
/// (14:30 Tokyo = 05:30 UTC)
///
/// ## Usage
///
/// ```dart
/// // Create a datetime in a specific timezone
/// final tokyo = TomTimezone.fromName('Asia/Tokyo');
/// final dt = TomZonedDateTime(
///   year: 2024, month: 6, day: 15,
///   hour: 14, minute: 30,
///   timezone: tokyo,
/// );
/// print(dt.localHour); // 14 (local time in Tokyo)
/// print(dt.hour);      // 5 (UTC time)
///
/// // Convert to another timezone
/// final ny = TomTimezone.fromName('America/New_York');
/// final dtNy = dt.convertToTimezone(ny);
/// print(dtNy.localHour); // 1 (local time in New York)
/// ```
///
/// ## DST Handling
///
/// When creating datetimes in DST-aware timezones, the offset is determined
/// at creation time based on the datetime value itself.
///
/// ```dart
/// final ny = TomTimezone.fromName('America/New_York');
/// 
/// // Summer (EDT: UTC-4)
/// final summer = TomZonedDateTime(
///   year: 2024, month: 6, day: 15, hour: 12,
///   timezone: ny,
/// );
/// print(summer.hour); // 16 (12 + 4 hours for EDT)
///
/// // Winter (EST: UTC-5)
/// final winter = TomZonedDateTime(
///   year: 2024, month: 1, day: 15, hour: 12,
///   timezone: ny,
/// );
/// print(winter.hour); // 17 (12 + 5 hours for EST)
/// ```
class TomZonedDateTime extends TomTimezoned {

  /// The serialization prefix for datetime values.
  ///
  /// All [TomZonedDateTime] strings start with `@X@` to identify the type.
  static const String serializationPrefix = "@X@";

  /// Returns the serialization prefix for this datetime type.
  @override
  String getSerializationPrefix() => serializationPrefix;

  /// Creates a [TomZonedDateTime] with all date and time components in local timezone.
  ///
  /// The values are interpreted as local time in the specified timezone,
  /// then converted to UTC for internal storage.
  ///
  /// [year] The year in local time (defaults to 1970).
  /// [month] The month 1-12 in local time (defaults to 1).
  /// [day] The day 1-31 in local time (defaults to 1).
  /// [hour] The hour 0-23 in local time (defaults to 0).
  /// [minute] The minute 0-59 in local time (defaults to 0).
  /// [second] The second 0-59 in local time (defaults to 0).
  /// [millisecond] The millisecond 0-999 (defaults to 0).
  /// [microsecond] The microsecond 0-999 (defaults to 0).
  /// [timezone] The timezone for the local time values (defaults to UTC).
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
  }) {
    final tz_ = timezone ?? TomTimezone.utc;
    // Create local time in the timezone
    final localTime = tz.TZDateTime(tz_.location, year, month, day, hour, minute, second, millisecond, microsecond);
    // Convert to UTC
    final utcTime = localTime.toUtc();
    return TomZonedDateTime._fromUtcValues(
      utcYear: utcTime.year,
      utcMonth: utcTime.month,
      utcDay: utcTime.day,
      utcHour: utcTime.hour,
      utcMinute: utcTime.minute,
      utcSecond: utcTime.second,
      utcMillisecond: utcTime.millisecond,
      utcMicrosecond: utcTime.microsecond,
      timezone: tz_,
    );
  }

  /// Internal constructor from UTC values.
  TomZonedDateTime._fromUtcValues({
    required int utcYear,
    required int utcMonth,
    required int utcDay,
    required int utcHour,
    required int utcMinute,
    required int utcSecond,
    required int utcMillisecond,
    required int utcMicrosecond,
    required TomTimezone timezone,
  }) : super._fromUtc(
          year: utcYear,
          month: utcMonth,
          day: utcDay,
          hour: utcHour,
          minute: utcMinute,
          second: utcSecond,
          millisecond: utcMillisecond,
          microsecond: utcMicrosecond,
          timezone: timezone,
        );

  /// Creates a [TomZonedDateTime] from an existing [DateTime].
  ///
  /// The DateTime is converted to UTC before storing. The provided timezone
  /// is associated for display purposes.
  ///
  /// [dtx] The DateTime to convert.
  /// [timezone] The timezone to associate (defaults to UTC).
  factory TomZonedDateTime.fromDateTime(DateTime dtx, [TomTimezone? timezone]) {
    var dt = dtx.toUtc();
    final tz_ = timezone ?? TomTimezone.utc;
    return TomZonedDateTime._fromUtcValues(
      utcYear: dt.year,
      utcMonth: dt.month,
      utcDay: dt.day,
      utcHour: dt.hour,
      utcMinute: dt.minute,
      utcSecond: dt.second,
      utcMillisecond: dt.millisecond,
      utcMicrosecond: dt.microsecond,
      timezone: tz_,
    );
  }

  /// Returns the serialized string representation of this datetime.
  ///
  /// Format: `@X@ISO8601_OFFSET_TIMEZONE`
  /// Example: `@X@2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo`
  @override
  String toString() {
    return "${TomZonedDateTime.serializationPrefix}${super.toIso8601String()}_$_timezone";
  }

  /// Parses a [TomZonedDateTime] from its serialized string format.
  ///
  /// The string must start with `@X@` and follow the format:
  /// `@X@ISO8601_OFFSET_TIMEZONE`
  ///
  /// [formattedString] The serialized datetime string.
  ///
  /// Throws [FormatException] if the string format is invalid.
  ///
  /// Example:
  /// ```dart
  /// final dt = TomZonedDateTime.parseFromString(
  ///   '@X@2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo'
  /// );
  /// print(dt.localYear);     // 2024
  /// print(dt.localMonth);    // 6
  /// print(dt.localDay);      // 15
  /// print(dt.localHour);     // 14 (local time in Tokyo)
  /// print(dt.hour);          // 5 (UTC time)
  /// print(dt.timezone.timezone); // 'Asia/Tokyo'
  /// ```
  factory TomZonedDateTime.parseFromString(String formattedString) {
    if (!TomZonedDateTime.isTomZonedDateTimeString(formattedString)) {
      throw FormatException(
        "Invalid TomZonedDateTime string: $formattedString",
      );
    }
    final match = RegExp(
      r"^@X@(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z?)_(Z|[+-]\d{2}:\d{2})_([a-zA-Z0-9_/-]+)\s?$",
    ).firstMatch(formattedString.trim());
    if (match == null) {
      throw FormatException("Failed to parse TomZonedDateTime string: $formattedString");
    }
    String dateTimeStr = match.group(1)!;
    String zone = match.group(3)!;
    DateTime dt = DateTime.parse(dateTimeStr).toUtc();
    return TomZonedDateTime.fromDateTime(dt, TomTimezone.fromName(zone));
  }

  /// Checks if a string is in valid [TomZonedDateTime] format.
  static bool isTomZonedDateTimeString(String s) {
    return RegExp(
      r"^@X@\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?Z?_(Z|[+-]\d{2}:\d{2})_[a-zA-Z0-9_/-]+\s?$",
    ).hasMatch(s);
  }

  /// Checks if a [DateTime] can be represented as a [TomZonedDateTime].
  ///
  /// Always returns `true` since any DateTime can be a full datetime.
  static bool isTomDateTime(DateTime dt) {
    return true;
  }

  /// Converts this datetime to another timezone.
  ///
  /// Returns a new [TomZonedDateTime] representing the same instant in time
  /// but displayed in a different timezone. The internal UTC time remains
  /// the same; only the associated timezone changes.
  ///
  /// [targetTimezone] The timezone to convert to.
  ///
  /// Example:
  /// ```dart
  /// final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
  /// final nyTz = TomTimezone.fromName('America/New_York')!;
  ///
  /// final meetingInTokyo = TomZonedDateTime(
  ///   year: 2024, month: 6, day: 15,
  ///   hour: 14, minute: 30,
  ///   timezone: tokyo,
  /// );
  ///
  /// final meetingInNY = meetingInTokyo.convertToTimezone(nyTz);
  /// print(meetingInNY.timezone.timezone); // 'America/New_York'
  /// print(meetingInNY.localHour); // 1 (local time in New York)
  /// print(meetingInNY.hour); // 5 (UTC - same as original)
  /// ```
  TomZonedDateTime convertToTimezone(TomTimezone targetTimezone) {
    // The UTC time stays the same, just change the timezone
    return TomZonedDateTime._fromUtcValues(
      utcYear: year,
      utcMonth: month,
      utcDay: day,
      utcHour: hour,
      utcMinute: minute,
      utcSecond: second,
      utcMillisecond: millisecond,
      utcMicrosecond: microsecond,
      timezone: targetTimezone,
    );
  }
}
