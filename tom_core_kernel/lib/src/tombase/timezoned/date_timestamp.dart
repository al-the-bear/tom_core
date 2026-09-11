import 'package:timezone/timezone.dart' as tz;

import 'timezones.dart';

/// The instant section of the serialized form.
///
/// The trailing `Z` is required. It is the only thing in the whole serialized
/// form that ties the reading to a point in time: the offset that follows is
/// derived from the zone and is not consulted, and the zone alone cannot say
/// which of its two readings a summer-time boundary meant. Without the `Z`,
/// [DateTime.parse] would resolve the reading against whatever zone the host
/// machine is in, so the same string would name different instants on
/// different machines.
///
/// Six fractional digits are admitted because `toIso8601String` emits six as
/// soon as the microsecond component is non-zero.
const String _instantSection =
    r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z';

/// The offset section of the serialized form.
///
/// A second rendering of what the zone already says, kept because it makes a
/// stored value readable without a timezone database to hand.
const String _offsetSection = r'Z|[+-]\d{2}:\d{2}';

/// The IANA zone-name section of the serialized form.
const String _zoneSection = r'[a-zA-Z0-9_/-]+';

/// Builds the pattern matching a serialized value carrying [prefix].
///
/// One definition of the format, from which every type's pattern is derived —
/// the alternative is a copy per type per use, and a copy that drifts is a
/// string one half of the library will accept and the other half will refuse.
///
/// Group 1 is the instant, group 2 the offset, group 3 the zone name.
RegExp _serializedForm(String prefix) =>
    RegExp('^$prefix($_instantSection)_($_offsetSection)_($_zoneSection)\$');

/// The form of an unprefixed [TomTimezoned].
final RegExp _timezonedForm = _serializedForm('');

/// The form of a [TomZonedDate].
final RegExp _zonedDateForm = _serializedForm(TomZonedDate.serializationPrefix);

/// The form of a [TomZonedTime].
final RegExp _zonedTimeForm = _serializedForm(TomZonedTime.serializationPrefix);

/// The form of a [TomZonedDateTime].
final RegExp _zonedDateTimeForm = _serializedForm(
  TomZonedDateTime.serializationPrefix,
);

/// Reads the two sections of a serialized value that carry information.
///
/// The offset is deliberately not read. It restates the zone's offset at the
/// instant, and the IANA database revises historical offsets, so an incoming
/// offset is not evidence about the value; the zone decides, and serializing
/// restates the offset from it.
///
/// [pattern] The form for the expected prefix, from [_serializedForm].
/// [formattedString] The string to read.
/// [typeName] Names the expected type in the exception, so a failure says
/// which format the string failed to be.
///
/// Throws [FormatException] if the string is not in the form, or names a zone
/// the timezone database does not know.
({DateTime instant, TomTimezone timezone}) _readSerializedForm(
  RegExp pattern,
  String formattedString,
  String typeName,
) {
  final match = pattern.firstMatch(formattedString.trim());
  if (match == null) {
    throw FormatException('Invalid $typeName string: $formattedString');
  }
  final zone = match.group(3)!;
  final timezone = TomTimezone.fromName(zone);
  if (timezone == null) {
    throw FormatException(
      "Unknown timezone '$zone' in $typeName string: $formattedString",
    );
  }
  // The `Z` is mandatory, so this is a UTC value already.
  return (instant: DateTime.parse(match.group(1)!), timezone: timezone);
}

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
/// - UTC offset the zone had at that instant — the one the value's local
///   fields are computed with, so it does not depend on when the string was
///   written. It is informational: parsing reads the instant and the zone
///   name, never the offset
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
/// ## Conversion lives on the subclasses
///
/// None of the `convertToTz*` methods is declared here, so a value obtained
/// from [TomTimezoned.now], [TomTimezoned.parseFromString] or the default
/// factory cannot be converted at that type: the call does not compile.
///
/// That is a decision, not a limitation of the language. Dart permits an
/// override to narrow its return type, so a base declaration that each
/// subclass narrowed to its own type would compile perfectly well. The reason
/// against it is that *which* conversion is meaningful depends on what the
/// value is, and the three types do not agree:
///
/// - [TomZonedDate] has [TomZonedDate.convertToTzSameInstant] and
///   [TomZonedDate.convertToTzSameDate].
/// - [TomZonedTime] has [TomZonedTime.convertToTzSameInstant] and
///   [TomZonedTime.convertToTzSameTime].
/// - [TomZonedDateTime] has only [TomZonedDateTime.convertToTzSameInstant]. It
///   names an instant, so a re-anchoring counterpart would have nothing to
///   move.
///
/// A value held at this type has no declared kind, so the only method that
/// could be hoisted is the instant-preserving one — and preserving the instant
/// is the wrong answer for a date and for a time, which is precisely why those
/// two carry a second conversion. Hoisting it would install that wrong default
/// on every value whose kind the reader has not yet established, and it would
/// do so silently, because it would compile.
///
/// So the compile error is the type system asking which kind of value this is.
/// Answering it costs one line:
///
/// ```dart
/// final base = TomTimezoned.now();
///
/// // The instant and the zone are all a conversion needs.
/// final moved = TomZonedDateTime.fromDateTime(base, base.timezone)
///     .convertToTzSameInstant(newYork);
/// ```
///
/// ## What this type is for
///
/// Holding a value at [TomTimezoned] is right where the kind genuinely does
/// not matter: as the supertype every zoned value shares — `TomOTimezoned`
/// binds its type parameter to it — for the accessors above, and for a
/// serialization round trip that carries a value through without asking what
/// it is.
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
  }) : super.utc(
         year,
         month,
         day,
         hour,
         minute,
         second,
         millisecond,
         microsecond,
       ) {
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
    final localTime = tz.TZDateTime(
      tz_.location,
      year,
      month,
      day,
      hour,
      minute,
      second,
      millisecond,
      microsecond,
    );
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
  }) : super.utc(
         year,
         month,
         day,
         hour,
         minute,
         second,
         millisecond,
         microsecond,
       );

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
    final read = _readSerializedForm(
      _timezonedForm,
      formattedString,
      'TomTimezoned',
    );
    return TomTimezoned.fromDateTime(read.instant, read.timezone);
  }

  /// Returns the string representation of this datetime.
  ///
  /// Format: `ISO8601_OFFSET_TIMEZONE`
  /// Example: `2024-06-15T05:30:00.000Z_+09:00_Asia/Tokyo`
  @override
  String toString() {
    return "${super.toIso8601String()}_${_timezone.toStringOn(this)}";
  }

  /// Checks if a string is in valid [TomTimezoned] format.
  ///
  /// Returns `true` if the string matches the expected serialization format.
  /// This judges shape only; a well-formed string may still name a zone the
  /// timezone database does not know, which [parseFromString] rejects.
  static bool isTomTimezonedString(String s) {
    return _timezonedForm.hasMatch(s.trim());
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

/// Returns [dt] as its own timezone sees it.
///
/// A [TomTimezoned] stores UTC while its anchoring — midnight for a date, the
/// epoch for a time — is defined in the zone it carries, so the components it
/// inherits from [DateTime] are a storage detail and the wrong thing to
/// classify it by. `toDateTime()` is the value in the frame its anchoring was
/// stated in. Any other [DateTime] carries a single frame, which is therefore
/// already the right one.
DateTime _inOwnFrame(DateTime dt) => dt is TomTimezoned ? dt.toDateTime() : dt;

/// The IANA zone [dt] knows itself to be in, or `null` if it carries none.
///
/// A [TomTimezoned] stores UTC and keeps its zone alongside; a [tz.TZDateTime]
/// carries its location directly. A plain [DateTime] knows only whether it is
/// UTC or "local", neither of which the timezone database can be asked
/// questions about, so such values can only be judged on their components.
tz.Location? _zoneOf(DateTime dt) {
  if (dt is TomTimezoned) return dt.timezone.location;
  if (dt is tz.TZDateTime) return dt.location;
  return null;
}

/// A timezone-aware date value (without time components).
///
/// [TomZonedDate] represents a calendar date associated with a specific timezone.
/// The value is anchored to the first instant of that day in the local
/// timezone — normally midnight, and 01:00 on the few zone-days where a
/// spring-forward transition means midnight never happens.
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
  /// Time components are set to the start of that day in the local timezone
  /// and the result is converted to UTC for internal storage. The start of the
  /// day is midnight except where the zone springs forward at midnight — Chile
  /// on 2024-09-08, Cuba, Lebanon, Egypt and the Azores each do this once a
  /// year — in which case it is 01:00, because midnight does not exist there
  /// that day. [isDate] accounts for this, so such a value is still a date.
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
    final localMidnight = tz.TZDateTime(
      tz_.location,
      year,
      month,
      day,
      0,
      0,
      0,
      0,
      0,
    );
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

  /// Creates a [TomZonedDate] for the calendar day on which [dtx] falls in
  /// [timezone].
  ///
  /// [dtx] names an instant; a date names a calendar day. The instant is read
  /// in [timezone] to find out which day it is *there*, and the result is
  /// anchored to the start of that day — the same value the primary
  /// constructor produces for those date components, including its handling of
  /// a midnight that a spring-forward transition skips. Any time-of-day
  /// carried by [dtx] is therefore discarded, which is what makes the result a
  /// date rather than a timestamp that happens to be typed as one.
  ///
  /// The day depends on the timezone: 22:30 UTC is already the next day in
  /// Berlin, so passing that instant with `Europe/Berlin` yields the later
  /// day, not the UTC one.
  ///
  /// [dtx] The instant to take the calendar day from; may be local or UTC.
  /// [timezone] The timezone the day is read in (defaults to UTC).
  ///
  /// Example:
  /// ```dart
  /// final todayInTokyo = TomZonedDate.fromDateTime(
  ///   DateTime.now(),
  ///   TomTimezone.fromName('Asia/Tokyo'),
  /// );
  /// print(todayInTokyo.localHour); // 0
  /// ```
  factory TomZonedDate.fromDateTime(DateTime dtx, [TomTimezone? timezone]) {
    final tz_ = timezone ?? TomTimezone.utc;
    final local = tz.TZDateTime.from(dtx, tz_.location);
    return TomZonedDate(
      year: local.year,
      month: local.month,
      day: local.day,
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
    final read = _readSerializedForm(
      _zonedDateForm,
      formattedString,
      'TomZonedDate',
    );
    return TomZonedDate.fromDateTime(read.instant, read.timezone);
  }

  /// Returns the serialized string representation of this date.
  ///
  /// Format: `@D@ISO8601_OFFSET_TIMEZONE`
  /// Example: `@D@2024-06-14T15:00:00.000Z_+09:00_Asia/Tokyo`
  @override
  String toString() {
    return "${TomZonedDate.serializationPrefix}${super.toIso8601String()}_${_timezone.toStringOn(this)}";
  }

  /// Checks if a string is in valid [TomZonedDate] format.
  ///
  /// Returns `true` if the string starts with `@D@` and matches
  /// the expected serialization format. This judges shape only; a well-formed
  /// string may still name a zone the timezone database does not know, which
  /// [parseFromString] rejects.
  static bool isTomZonedDateString(String s) {
    return _zonedDateForm.hasMatch(s.trim());
  }

  /// Checks whether [dt] sits at the start of a calendar day.
  ///
  /// A value that knows its zone — a [TomTimezoned], or any `TZDateTime` — is
  /// read in that zone and compared against the first instant of the local
  /// day, so every well-formed [TomZonedDate] passes wherever it is anchored.
  ///
  /// The first instant of a day is usually local midnight but not always: a
  /// few zones spring forward *at* midnight, and on those days the day begins
  /// at 01:00 because 00:00 never happens. [TomZonedDate] is built by asking
  /// the timezone database for that instant, so a predicate insisting on zero
  /// components would reject values its own constructor produces.
  ///
  /// A plain [DateTime] carries no zone to be read in, so it is judged as it
  /// stands: `true` when its time components are all zero.
  ///
  /// Example:
  /// ```dart
  /// final tokyo = TomTimezone.fromName('Asia/Tokyo');
  /// final date = TomZonedDate(year: 2024, month: 6, day: 15, timezone: tokyo);
  /// print(date.hour);                 // 15 — midnight in Tokyo, stored as UTC
  /// print(TomZonedDate.isDate(date)); // true
  ///
  /// // Chile springs forward at midnight on 2024-09-08.
  /// final santiago = TomTimezone.fromName('America/Santiago');
  /// final skipped =
  ///     TomZonedDate(year: 2024, month: 9, day: 8, timezone: santiago);
  /// print(skipped.localHour);            // 1 — the day starts an hour late
  /// print(TomZonedDate.isDate(skipped)); // true
  /// ```
  static bool isDate(DateTime dt) {
    final local = _inOwnFrame(dt);
    final zone = _zoneOf(dt);
    if (zone != null) {
      // Ask the database when the day began rather than assuming midnight.
      // TZDateTime normalizes a local midnight that does not exist forward to
      // the first instant that does, which is exactly what the constructor
      // stored, so this comparison is the round trip of construction.
      final startOfDay = tz.TZDateTime(
        zone,
        local.year,
        local.month,
        local.day,
      );
      return startOfDay.isAtSameMomentAs(dt);
    }
    return local.hour == 0 &&
        local.minute == 0 &&
        local.second == 0 &&
        local.millisecond == 0 &&
        local.microsecond == 0;
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
  /// final dateInNY = dateInTokyo.convertToTzSameInstant(nyTz);
  /// print(dateInNY.timezone.timezone); // 'America/New_York'
  /// print(dateInNY.localDay);          // 14 — not 15
  /// print(dateInNY.localHour);         // 11 — a date carrying a time of day
  /// ```
  ///
  /// **The result is not a well-formed date**, and the name says which
  /// question was asked. Midnight on the 15th in Tokyo *is* 11:00 on the 14th
  /// in New York, so preserving the instant necessarily moves the local day and
  /// gives the value a time of day — the two things [TomZonedDate]'s anchoring
  /// otherwise guarantees it has not got. That is the honest answer to "when
  /// was this, for someone over there", and it is the wrong answer to "what
  /// date is this, expressed over there": a public holiday is the same date
  /// everywhere. For that, use [convertToTzSameDate], which is closed over the
  /// type.
  TomZonedDate convertToTzSameInstant(TomTimezone targetTimezone) {
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

  /// The same calendar day, expressed in [targetTimezone].
  ///
  /// The counterpart to [convertToTzSameInstant], and the one that is *closed*
  /// over this type: the day, month and year are carried across unchanged and
  /// re-anchored to midnight in the new zone, so the result is a well-formed
  /// [TomZonedDate] again. The instant moves, necessarily — midnight on the
  /// 15th in Tokyo and midnight on the 15th in New York are fourteen hours
  /// apart — and that is the point. A date is a label on a calendar, not a
  /// moment: a public holiday, a birthday and an invoice date are the same date
  /// wherever they are read.
  ///
  /// ```dart
  /// final dateInTokyo = TomZonedDate(
  ///   year: 2024, month: 6, day: 15,
  ///   timezone: tokyo,
  /// );
  ///
  /// final dateInNY = dateInTokyo.convertToTzSameDate(nyTz);
  /// print(dateInNY.localDay);  // 15 — the same date
  /// print(dateInNY.localHour); // 0  — still anchored to midnight
  /// ```
  TomZonedDate convertToTzSameDate(TomTimezone targetTimezone) => TomZonedDate(
    year: localYear,
    month: localMonth,
    day: localDay,
    timezone: targetTimezone,
  );
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
    final localTime = tz.TZDateTime(
      tz_.location,
      1970,
      1,
      1,
      hour,
      minute,
      second,
      millisecond,
      microsecond,
    );
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

  /// Creates a [TomZonedTime] for the wall-clock time [dtx] shows in
  /// [timezone].
  ///
  /// [dtx] names an instant; a time names a position within a day. The
  /// instant is read in [timezone] to find the clock reading *there*, and the
  /// date it fell on is replaced by the epoch anchor — the same value the
  /// primary constructor produces for those time components. Discarding the
  /// date is what makes the result a time of day rather than a timestamp that
  /// happens to be typed as one.
  ///
  /// The reading depends on the timezone: 13:47 UTC is 15:47 in Berlin during
  /// CEST, and it is the Berlin reading that a Berlin time-of-day means.
  ///
  /// [dtx] The instant to take the clock reading from; may be local or UTC.
  /// [timezone] The timezone the reading is taken in (defaults to UTC).
  factory TomZonedTime.fromDateTime(DateTime dtx, [TomTimezone? timezone]) {
    final tz_ = timezone ?? TomTimezone.utc;
    final local = tz.TZDateTime.from(dtx, tz_.location);
    return TomZonedTime(
      hour: local.hour,
      minute: local.minute,
      second: local.second,
      millisecond: local.millisecond,
      microsecond: local.microsecond,
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
    final read = _readSerializedForm(
      _zonedTimeForm,
      formattedString,
      'TomZonedTime',
    );
    return TomZonedTime.fromDateTime(read.instant, read.timezone);
  }

  /// Returns the serialized string representation of this time.
  ///
  /// Format: `@T@ISO8601_OFFSET_TIMEZONE`
  /// Example: `@T@1970-01-01T05:30:00.000Z_+09:00_Asia/Tokyo`
  @override
  String toString() {
    return "${TomZonedTime.serializationPrefix}${super.toIso8601String()}_${_timezone.toStringOn(this)}";
  }

  /// Checks if a string is in valid [TomZonedTime] format.
  ///
  /// This judges shape only; a well-formed string may still name a zone the
  /// timezone database does not know, which [parseFromString] rejects.
  static bool isTomZonedTimeString(String s) {
    return _zonedTimeForm.hasMatch(s.trim());
  }

  /// Checks whether [dt] represents a time-only value.
  ///
  /// Returns `true` if the date components are 1970-01-01 (Unix epoch).
  ///
  /// A [TomTimezoned] is read in the timezone it carries, which is the frame
  /// its anchoring is defined in — so every well-formed [TomZonedTime] passes,
  /// wherever it is anchored. Any other [DateTime] is read as it stands.
  ///
  /// Example:
  /// ```dart
  /// final tokyo = TomTimezone.fromName('Asia/Tokyo');
  /// final time = TomZonedTime(hour: 0, minute: 30, timezone: tokyo);
  /// print(time.year);                 // 1969 — 00:30 Tokyo is the day before
  /// print(TomZonedTime.isTime(time)); // true
  /// ```
  static bool isTime(DateTime dt) {
    final local = _inOwnFrame(dt);
    return local.year == 1970 && local.month == 1 && local.day == 1;
  }

  /// The same instant, read in [targetTimezone].
  ///
  /// **The result is not a well-formed time**, and the name says which question
  /// was asked. Preserving the instant moves the local clock reading, and can
  /// move the local date off 1970-01-01 — which is exactly what [isTime] tests
  /// for, so the returned value fails it. That is the honest answer to "what
  /// time was that, over there", and the wrong answer to "what does 09:00 mean
  /// over there": a 09:00 standup is 09:00 wherever it is run. For that, use
  /// [convertToTzSameTime], which is closed over the type.
  ///
  /// [targetTimezone] The timezone to read the instant in.
  TomZonedTime convertToTzSameInstant(TomTimezone targetTimezone) {
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

  /// The same clock reading, expressed in [targetTimezone].
  ///
  /// The counterpart to [convertToTzSameInstant], and the one that is *closed*
  /// over this type: the hour, minute and sub-second components are carried
  /// across unchanged and re-anchored to 1970-01-01 in the new zone, so the
  /// result satisfies [isTime] again. The instant moves, and that is the point.
  /// A time of day is a reading on a clock, not a moment: a 09:00 standup is
  /// 09:00 wherever it is run, and a shift that starts at 22:00 starts at 22:00
  /// in every office that runs it.
  ///
  /// ```dart
  /// final standupTokyo = TomZonedTime(hour: 9, timezone: tokyo);
  ///
  /// final standupNY = standupTokyo.convertToTzSameTime(nyTz);
  /// print(standupNY.localHour);           // 9 — the same clock reading
  /// print(TomZonedTime.isTime(standupNY)); // true
  /// ```
  TomZonedTime convertToTzSameTime(TomTimezone targetTimezone) => TomZonedTime(
    hour: localHour,
    minute: localMinute,
    second: localSecond,
    millisecond: localMillisecond,
    microsecond: localMicrosecond,
    timezone: targetTimezone,
  );

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
/// final dtNy = dt.convertToTzSameInstant(ny);
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
    final localTime = tz.TZDateTime(
      tz_.location,
      year,
      month,
      day,
      hour,
      minute,
      second,
      millisecond,
      microsecond,
    );
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
    return "${TomZonedDateTime.serializationPrefix}${super.toIso8601String()}_${_timezone.toStringOn(this)}";
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
    final read = _readSerializedForm(
      _zonedDateTimeForm,
      formattedString,
      'TomZonedDateTime',
    );
    return TomZonedDateTime.fromDateTime(read.instant, read.timezone);
  }

  /// Checks if a string is in valid [TomZonedDateTime] format.
  ///
  /// This judges shape only; a well-formed string may still name a zone the
  /// timezone database does not know, which [parseFromString] rejects.
  static bool isTomZonedDateTimeString(String s) {
    return _zonedDateTimeForm.hasMatch(s.trim());
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
  /// final meetingInNY = meetingInTokyo.convertToTzSameInstant(nyTz);
  /// print(meetingInNY.timezone.timezone); // 'America/New_York'
  /// print(meetingInNY.localHour); // 1 (local time in New York)
  /// print(meetingInNY.hour); // 5 (UTC - same as original)
  /// ```
  TomZonedDateTime convertToTzSameInstant(TomTimezone targetTimezone) {
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
