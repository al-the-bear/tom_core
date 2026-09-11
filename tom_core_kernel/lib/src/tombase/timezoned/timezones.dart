import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:tom_basics/tom_basics.dart';

import '../little_things/exception_base.dart';
// Prefixed: the top-level `convertMinutesToUtcOffset` shares its name with the
// static member below, and an unprefixed call from inside the class would
// resolve to that member and recurse.
import '../little_things/formatting.dart' as formatting;

// Imported for the synchronous lazy-init below, and re-exported because
// `tomSetupTimezones` is part of the module's public surface: in the browser it
// is the only way to load the database, and an import alone would not carry it
// through this library to the package barrel. The two lines repeat the same
// platform configuration because an `export` does not bring names into scope
// and an `import` does not pass them on; keep them in step.
//
// The embedded database is the default rather than a conditional arm because it
// needs nothing from the platform, and the default arm is taken exactly where
// no condition can be relied on. Only the browser needs a different
// implementation — it has no bundled copy and fetches over the network instead.
import 'init_tz_embedded.dart' if (dart.library.js) 'init_tz_web.dart';
export 'init_tz_embedded.dart' if (dart.library.js) 'init_tz_web.dart';

// see https://stackoverflow.com/questions/63666615/how-to-get-timezone-name-in-flutter

/// Exception thrown by [TomTimezone.findTimezone], and by nothing else in this
/// module.
///
/// Extends [TomException] to provide consistent error handling across the
/// Tom framework. It is raised for exactly two reasons:
/// - Timezone name not found in the database
/// - Timezone name and UTC offset mismatch
///
/// It is *not* what a parse failure raises. The `parseFromString` of each
/// variant throws [FormatException] — for a string that does not match the
/// serialized form, and for one naming a zone that is not in the database —
/// so a caller reading serialized values catches that instead. The lenient
/// lookup [TomTimezone.fromName] raises nothing at all and returns `null`.
///
/// Example:
/// ```dart
/// try {
///   TomTimezone.findTimezone('UTC', 60); // UTC should have offset 0, not 60
/// } on TomTimezoneException catch (e) {
///   print('Error: ${e.key}'); // timezone.not_found.name_offset_mismatch
/// }
/// ```
class TomTimezoneException extends TomException {
  TomTimezoneException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// Represents a timezone with its name and location data.
///
/// [TomTimezone] provides a unified interface for working with timezones across
/// the Tom framework. It wraps the `timezone` package's functionality and provides:
///
/// - **Timezone lookup**: Find timezones by name or UTC offset
/// - **Offset calculation**: Get UTC offset for any timezone at any point in time
/// - **DateTime conversion**: Convert between timezones and to/from TZDateTime
/// - **DST awareness**: Automatically handles daylight saving time transitions
///
/// ## Initialization
///
/// On native (Flutter / VM) platforms the timezone database is loaded
/// **synchronously on first access** from the embedded IANA data, so no manual
/// initialization is required.
///
/// On the **web** the database must be fetched over the network and therefore
/// cannot be loaded synchronously: applications must call (and await)
/// `tomSetupTimezones()` during startup **before** any timezone access. If the
/// database is still empty on first access, lookups throw a clear error rather
/// than returning empty results.
///
/// ## Common Usage
///
/// ```dart
/// // Get a timezone by name
/// final tokyo = TomTimezone.fromName('Asia/Tokyo');
/// print(tokyo?.timezone); // 'Asia/Tokyo'
/// print(tokyo?.timezoneOffsetMin); // 540 (UTC+9)
///
/// // Get the UTC timezone
/// final utc = TomTimezone.utc;
///
/// // Get current time in a timezone
/// final now = tokyo!.now();
///
/// // Convert DateTime to TZDateTime
/// final tzDt = tokyo.toTZDateTime(DateTime.now());
/// ```
///
/// ## Finding Timezones
///
/// ```dart
/// // By name (case-insensitive)
/// final tz = TomTimezone.fromName('America/New_York');
///
/// // By UTC offset (returns first matching timezone)
/// final tz2 = TomTimezone.firstWithOffset(540); // UTC+9
///
/// // All timezones with a specific offset
/// final tzList = TomTimezone.allWithOffset(0); // All UTC+0 timezones
/// ```
class TomTimezone {
  /// The IANA timezone name (e.g., 'America/New_York', 'Europe/London').
  final String timezone;

  /// The underlying timezone location from the `timezone` package.
  ///
  /// Provides access to low-level timezone operations and data.
  final tz.Location location;

  TomTimezone._({required this.timezone, required this.location});

  /// The UTC timezone singleton.
  ///
  /// UTC (Coordinated Universal Time) has no offset and no daylight saving time.
  /// This is useful as a reference timezone and for storing timestamps.
  ///
  /// Example:
  /// ```dart
  /// final utc = TomTimezone.utc;
  /// print(utc.timezone); // 'UTC'
  /// print(utc.timezoneOffsetMin); // 0
  /// ```
  static final TomTimezone utc = TomTimezone._(
    timezone: 'UTC',
    location: tz.UTC,
  );

  /// Returns the current UTC offset in minutes for this timezone.
  ///
  /// This reflects the current offset including any daylight saving time
  /// adjustments. For a fixed offset at a specific time, use [getUtcOffsetOn].
  ///
  /// Example:
  /// ```dart
  /// final tokyo = TomTimezone.fromName('Asia/Tokyo');
  /// print(tokyo!.timezoneOffsetMin); // 540 (UTC+9, no DST)
  ///
  /// final newYork = TomTimezone.fromName('America/New_York');
  /// print(newYork!.timezoneOffsetMin); // -300 (EST) or -240 (EDT)
  /// ```
  int get timezoneOffsetMin {
    final now = tz.TZDateTime.now(location);
    return now.timeZoneOffset.inMinutes;
  }

  static bool _initialized = false;

  /// Lazily initializes the timezone database synchronously on first access.
  ///
  /// If the database has already been loaded (e.g. the application called
  /// [tomSetupTimezones] during startup, which is mandatory on web), the
  /// existing data is used. Otherwise the embedded database is loaded
  /// synchronously via [tomSetupTimezonesSync]. On web there is no synchronous
  /// load path, so [tomSetupTimezonesSync] throws to surface the missing
  /// startup initialization instead of silently returning empty results.
  static void _initialize() {
    if (_initialized) return;

    // Load the embedded database synchronously when it has not been
    // pre-populated. On native platforms this is a no-I/O in-memory load; on
    // web it throws because the data must be fetched asynchronously first.
    if (tz.timeZoneDatabase.locations.isEmpty) {
      tomSetupTimezonesSync();
    }

    _populateTimezonesMap();
  }

  static void _populateTimezonesMap() =>
      populateFromLocations(tz.timeZoneDatabase.locations);

  /// Fills the lookup caches from [locations] and registers the [utc]
  /// singleton, which the IANA database does not supply under that name.
  ///
  /// Takes the location map rather than reading `tz.timeZoneDatabase` directly
  /// so that a test can drive the failure branch below. On a native platform
  /// the embedded database always loads, so "it did not load" is the one state
  /// that cannot be provoked through the public entry points — and it is
  /// precisely the state whose handling must not go untested.
  @visibleForTesting
  static void populateFromLocations(Map<String, tz.Location> locations) {
    if (_timezonesMap.isEmpty) {
      for (var entry in locations.entries) {
        _insertTimezone(
          TomTimezone._(timezone: entry.value.name, location: entry.value),
        );
      }
    }
    _initialized = true;

    // Routine setup, not a failure. The IANA database has no location keyed
    // exactly `UTC` — it ships `Etc/UTC` — while [utc] is a documented
    // singleton and `fromName('UTC')` is expected to resolve, so registering it
    // here is how that promise is kept. Announced at debug level because the
    // branch fires on every run of every process, forever: an ERROR line that
    // is always present is how a team learns to filter out ERROR.
    if (_timezonesMap['UTC'] == null) {
      tomLog.debug(
        'UTC is not a location in the IANA database (it ships Etc/UTC); '
        'registering the UTC singleton.',
      );
      _insertTimezone(utc);
    }

    // The genuinely broken case, and the only one here worth an ERROR: the
    // database did not load at all. UTC alone is not a timezone database —
    // every other lookup will miss, and reporting that as a run of unknown
    // zone names would hide a configuration failure behind a data one.
    if (locations.isEmpty) {
      tomLog.error(
        'Timezone database is empty: no IANA locations were loaded, so only '
        'UTC is available and all other timezone lookups will fail.',
      );
    }
  }

  static final Map<String, TomTimezone> _timezonesMap = {};
  static final Map<int, List<TomTimezone>> _timezoneByOffset = {};

  /// Every available timezone, keyed by uppercase IANA name (e.g.
  /// `'AMERICA/NEW_YORK'`).
  ///
  /// The database is lazily built on first access, and the map is
  /// **unmodifiable**: it is a view onto the index every lookup in this class
  /// reads, so a write would not add a timezone, it would corrupt the database
  /// for the rest of the process. An attempted one throws `UnsupportedError`
  /// where the mistake is, rather than surfacing later as [fromName] resolving
  /// a name the IANA database has never held.
  ///
  /// To work with a modifiable copy — to sort, filter, or add entries of your
  /// own — take one: `Map.of(TomTimezone.timezones)`.
  ///
  /// Example:
  /// ```dart
  /// final allTimezones = TomTimezone.timezones;
  /// print(allTimezones.length); // Typically 400+ timezones
  /// print(allTimezones.containsKey('EUROPE/LONDON')); // true
  /// ```
  static Map<String, TomTimezone> get timezones {
    _initialize();
    return UnmodifiableMapView(_timezonesMap);
  }

  static void _insertTimezone(TomTimezone tomTz) {
    _timezonesMap[tomTz.timezone.toUpperCase()] = tomTz;
    // Use current offset for indexing by offset
    final currentOffset = tomTz.timezoneOffsetMin;
    List<TomTimezone>? offsetTimezones = _timezoneByOffset[currentOffset];
    if (offsetTimezones == null) {
      offsetTimezones = [tomTz];
      _timezoneByOffset[currentOffset] = offsetTimezones;
    } else {
      offsetTimezones.add(tomTz);
    }
  }

  /// Finds a timezone by its IANA name.
  ///
  /// The lookup is case-insensitive. Returns `null` if the timezone
  /// is not found in the database.
  ///
  /// [name] The IANA timezone name (e.g., 'America/New_York', 'Europe/Berlin').
  ///
  /// Example:
  /// ```dart
  /// final tz1 = TomTimezone.fromName('Asia/Tokyo');
  /// final tz2 = TomTimezone.fromName('asia/tokyo'); // Same result
  /// final tz3 = TomTimezone.fromName('Unknown/Zone'); // Returns null
  /// ```
  static TomTimezone? fromName(String name) {
    _initialize();
    return _timezonesMap[name.toUpperCase()];
  }

  /// Returns the first timezone whose offset **right now** is
  /// [utcOffsetMinutes].
  ///
  /// The match is against the current offset, so the answer has a shelf life.
  /// A zone that observes daylight saving is in one bucket in winter and a
  /// different one in summer — roughly a third of the IANA database moves this
  /// way — and the index is built once at first access and never rebuilt, so a
  /// process that runs across a transition keeps answering for the season it
  /// started in. Use offset lookup for discovery ("who is at +05:30 at the
  /// moment", a zone picker) and store the [timezone] name it yields, never
  /// the offset it was found under. For the offset a zone had at a particular
  /// instant, ask the zone with [getUtcOffsetOn].
  ///
  /// *First* means first in the bucket, which is IANA name order rather than
  /// the best-known zone at that offset: `firstWithOffset(0)` yields
  /// `Africa/Abidjan`, not `UTC`. Where a particular zone is wanted, name it
  /// with [fromName].
  ///
  /// [utcOffsetMinutes] The UTC offset in minutes (e.g., 540 for UTC+9).
  ///
  /// Returns `null` if no timezone is at that offset now.
  ///
  /// Example:
  /// ```dart
  /// final tz = TomTimezone.firstWithOffset(540); // UTC+9
  /// print(tz?.timezone); // Some zone currently at +09:00
  /// ```
  static TomTimezone? firstWithOffset(int utcOffsetMinutes) {
    _initialize();
    var list = _timezoneByOffset[utcOffsetMinutes];
    if (list != null && list.isNotEmpty) {
      return list.first;
    }
    return null;
  }

  /// Returns every timezone whose offset **right now** is [utcOffsetMinutes].
  ///
  /// The same shelf life as [firstWithOffset], and for the same reason: the
  /// bucket holds the zones that were at this offset when the index was built,
  /// not the zones that are ever at it. `allWithOffset(0)` in July does not
  /// contain `Europe/London`, which is on BST and sits at 60; in January it
  /// does. Treat the result as a snapshot, not as a membership rule.
  ///
  /// The list is **unmodifiable**, and for the same reason [timezones] is: it
  /// is a view onto the bucket [firstWithOffset] reads, so sorting or filtering
  /// it in place would not shape a local result, it would rewrite the index for
  /// the rest of the process. Neither operation reads as dangerous, which is
  /// why the refusal is at the call rather than in a comment. Take a copy to
  /// work with: `[...?TomTimezone.allWithOffset(0)]`.
  ///
  /// [utcOffsetMinutes] The UTC offset in minutes.
  ///
  /// Returns `null` if no timezone is at that offset now.
  ///
  /// Example:
  /// ```dart
  /// final tzList = TomTimezone.allWithOffset(0); // Zones at +00:00 today
  /// for (final tz in tzList ?? <TomTimezone>[]) {
  ///   print(tz.timezone); // 'UTC', 'Africa/Abidjan', 'Etc/GMT', ...
  /// }
  /// ```
  static List<TomTimezone>? allWithOffset(int utcOffsetMinutes) {
    _initialize();
    final bucket = _timezoneByOffset[utcOffsetMinutes];
    return bucket == null ? null : UnmodifiableListView(bucket);
  }

  /// Finds a timezone by name, optionally validating its UTC offset.
  ///
  /// This is the strict lookup: where [fromName] answers "is this zone here?"
  /// with a zone or `null`, this one treats a name it cannot honour as an
  /// error. Supplying an offset adds a second thing that can be wrong, and both
  /// raise [TomTimezoneException].
  ///
  /// [name] The timezone name (optional).
  /// [utcOffsetMinutes] The expected UTC offset in minutes (optional).
  ///
  /// Returns:
  /// - The named zone, when it exists and — if an offset was given — its
  ///   current offset is that offset
  /// - The first zone at [utcOffsetMinutes] if [name] is null, or `null` when
  ///   no zone is at that offset. This branch reads the same offset index as
  ///   [firstWithOffset] and inherits its shelf life
  /// - `null` if both parameters are null
  ///
  /// Throws [TomTimezoneException] in two cases:
  /// - [name] is not found in the database. This happens whether or not an
  ///   offset was supplied, so a name-only lookup throws too — unlike
  ///   [fromName], which returns `null` for the same name.
  /// - [name] is found but its current offset does not match
  ///   [utcOffsetMinutes].
  ///
  /// The offset compared is the zone's offset *now*, so a zone that observes
  /// daylight saving matches a different value in summer than in winter. Use
  /// [getUtcOffsetOn] to ask about a particular date.
  ///
  /// Example:
  /// ```dart
  /// // Valid: UTC has offset 0
  /// final tz = TomTimezone.findTimezone('UTC', 0);
  ///
  /// // Throws: UTC doesn't have offset 60
  /// TomTimezone.findTimezone('UTC', 60); // TomTimezoneException
  ///
  /// // Throws: no such zone, even with no offset to disagree with
  /// TomTimezone.findTimezone('Mars/Olympus', null); // TomTimezoneException
  /// ```
  static TomTimezone? findTimezone(String? name, int? utcOffsetMinutes) {
    _initialize();
    if (name != null) {
      var byName = _timezonesMap[name.toUpperCase()];
      // A name-only lookup (no offset given) returns the named zone; when an
      // offset is supplied it must match the zone's current offset.
      if (byName != null &&
          (utcOffsetMinutes == null ||
              byName.timezoneOffsetMin == utcOffsetMinutes)) {
        return byName;
      } else {
        throw TomTimezoneException(
          'timezone.not_found.name_offset_mismatch',
          'Timezone with name $name not found or does not match offset $utcOffsetMinutes',
          parameters: {'name': name, 'utcOffsetMinutes': utcOffsetMinutes},
        );
      }
    }
    return utcOffsetMinutes != null
        ? _timezoneByOffset[utcOffsetMinutes]?.first
        : null;
  }

  /// Returns a string representation of this timezone.
  ///
  /// Format: `{offset}_{timezone}`, where offset is `Z` for UTC or
  /// `+HH:MM`/`-HH:MM` for other timezones.
  ///
  /// The offset is the zone's offset **now**. A zoned value does not render
  /// its zone through this method but through [toStringOn] at its own
  /// instant, because the offset belongs to the value: a January Berlin value
  /// written in July still reads `+01:00`.
  ///
  /// Example:
  /// ```dart
  /// print(TomTimezone.utc.toString()); // 'Z_UTC'
  /// print(TomTimezone.fromName('Asia/Tokyo')!.toString()); // '+09:00_Asia/Tokyo'
  /// ```
  @override
  String toString() {
    return "${convertMinutesToUtcOffset(timezoneOffsetMin)}_$timezone";
  }

  /// Returns a string representation of this timezone at a specific date/time.
  ///
  /// Format: `{offset}_{timezone}`, as
  /// [toString], with the offset calculated for the given date and
  /// accounting for DST transitions.
  ///
  /// Every zoned value renders its zone through this method, at its own
  /// instant, so whatever this returns is the tail of every serialized string
  /// the module produces — which is why it ends where the zone name ends. A
  /// trailing character nobody asked for is carried into every stored value,
  /// every map key and every URL built from one, and is invisible in each of
  /// them.
  ///
  /// [when] The DateTime to calculate the offset for.
  ///
  /// Example:
  /// ```dart
  /// final newYork = TomTimezone.fromName('America/New_York')!;
  ///
  /// // Winter (EST: UTC-5)
  /// print(newYork.toStringOn(DateTime.utc(2024, 1, 15))); // '-05:00_America/New_York'
  ///
  /// // Summer (EDT: UTC-4)
  /// print(newYork.toStringOn(DateTime.utc(2024, 7, 15))); // '-04:00_America/New_York'
  /// ```
  String toStringOn(DateTime when) {
    return "${getUtcOffsetStringOn(when)}_$timezone";
  }

  /// Converts a UTC offset in minutes to a formatted string.
  ///
  /// [totalMinutes] The UTC offset in minutes (positive = east of UTC).
  ///
  /// Returns:
  /// - `'Z'` for offset of 0
  /// - `'+HH:MM'` for positive offsets
  /// - `'-HH:MM'` for negative offsets
  ///
  /// Example:
  /// ```dart
  /// print(TomTimezone.convertMinutesToUtcOffset(0));    // 'Z'
  /// print(TomTimezone.convertMinutesToUtcOffset(540));  // '+09:00'
  /// print(TomTimezone.convertMinutesToUtcOffset(-300)); // '-05:00'
  /// print(TomTimezone.convertMinutesToUtcOffset(330));  // '+05:30'
  /// ```
  ///
  /// Throws `TomFormattingException` when [totalMinutes] lies outside ±840
  /// (±14:00), which no real zone does — see the top-level function. An offset
  /// obtained from this class is always inside that range, so
  /// [getUtcOffsetStringOn], [toStringOn] and [toString] cannot throw; only
  /// this static entry point, which takes an arbitrary `int`, can.
  ///
  /// Delegates to the top-level [formatting.convertMinutesToUtcOffset] so the
  /// two entry points cannot drift apart; this one exists because offsets are
  /// most often formatted from a timezone.
  static String convertMinutesToUtcOffset(int totalMinutes) =>
      formatting.convertMinutesToUtcOffset(totalMinutes);

  /// Returns the UTC offset in minutes for this timezone at a specific date/time.
  ///
  /// This is useful for determining the offset at a historical or future date,
  /// accounting for daylight saving time transitions.
  ///
  /// [dt] The DateTime to get the offset for.
  ///
  /// Example:
  /// ```dart
  /// final newYork = TomTimezone.fromName('America/New_York')!;
  ///
  /// // Winter (EST): -300 minutes (-5 hours)
  /// final winter = newYork.getUtcOffsetOn(DateTime.utc(2024, 1, 15));
  ///
  /// // Summer (EDT): -240 minutes (-4 hours)
  /// final summer = newYork.getUtcOffsetOn(DateTime.utc(2024, 7, 15));
  /// ```
  int getUtcOffsetOn(DateTime dt) {
    final tzDateTime = tz.TZDateTime.from(dt.toUtc(), location);
    return tzDateTime.timeZoneOffset.inMinutes;
  }

  /// Returns the UTC offset string for this timezone at a specific date/time.
  ///
  /// [dt] The DateTime to get the offset for.
  ///
  /// Example:
  /// ```dart
  /// final berlin = TomTimezone.fromName('Europe/Berlin')!;
  /// print(berlin.getUtcOffsetStringOn(DateTime.utc(2024, 1, 15))); // '+01:00'
  /// print(berlin.getUtcOffsetStringOn(DateTime.utc(2024, 7, 15))); // '+02:00'
  /// ```
  String getUtcOffsetStringOn(DateTime dt) {
    return convertMinutesToUtcOffset(getUtcOffsetOn(dt));
  }

  /// Returns the current UTC offset in minutes for this timezone.
  ///
  /// Equivalent to calling `getUtcOffsetOn(DateTime.now())`.
  int getCurrentUtcOffset() {
    return getUtcOffsetOn(DateTime.now());
  }

  /// Returns the current UTC offset string for this timezone.
  ///
  /// Equivalent to calling `getUtcOffsetStringOn(DateTime.now())`.
  String getCurrentUtcOffsetString() {
    return convertMinutesToUtcOffset(getCurrentUtcOffset());
  }

  /// Converts a DateTime to a TZDateTime in this timezone.
  ///
  /// The input DateTime is first converted to UTC, then to the local time
  /// in this timezone.
  ///
  /// [dt] The DateTime to convert.
  ///
  /// Example:
  /// ```dart
  /// final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
  /// final utcTime = DateTime.utc(2024, 6, 15, 3, 0, 0); // 3 AM UTC
  /// final tokyoTime = tokyo.toTZDateTime(utcTime);
  /// print(tokyoTime.hour); // 12 (noon in Tokyo)
  /// ```
  tz.TZDateTime toTZDateTime(DateTime dt) {
    return tz.TZDateTime.from(dt.toUtc(), location);
  }

  /// Returns the current time in this timezone.
  ///
  /// Example:
  /// ```dart
  /// final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
  /// final tokyoNow = tokyo.now();
  /// print('Tokyo time: ${tokyoNow.hour}:${tokyoNow.minute}');
  /// ```
  DateTime now() {
    return tz.TZDateTime.now(location);
  }

  /// Reads [dt] as a wall-clock reading in [inTimezone] and re-renders it in
  /// this timezone.
  ///
  /// The instance form of [changeLocation], with this timezone as the target.
  /// See there for the full semantics — in particular that only the calendar
  /// fields of [dt] are read, never the instant it denotes.
  ///
  /// [dt] The wall-clock reading to convert.
  /// [inTimezone] The timezone the reading is expressed in.
  ///
  /// Example:
  /// ```dart
  /// final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
  /// final newYork = TomTimezone.fromName('America/New_York')!;
  ///
  /// // Noon on a Tokyo clock.
  /// final tokyoNoon = DateTime.utc(2024, 6, 15, 12, 0);
  /// final nyTime = newYork.changeToThisLocation(tokyoNoon, tokyo);
  /// print('${nyTime.day} ${nyTime.hour}'); // 14 23 (11 PM the previous day)
  /// ```
  DateTime changeToThisLocation(DateTime dt, TomTimezone inTimezone) =>
      changeLocation(dt, inTimezone, this);

  /// Reads [dt] as a wall-clock reading in [inTimezone] and re-renders it in
  /// [toTimezone].
  ///
  /// This is a *reinterpretation*, not a rendering: only the calendar fields of
  /// [dt] are read — year, month, day, hour, minute, second and the sub-second
  /// parts. Whatever instant [dt] itself denotes, and whether it was built with
  /// `DateTime()` or `DateTime.utc()`, is ignored. Those fields are resolved to
  /// an instant *in [inTimezone]*, and that instant is then rendered in
  /// [toTimezone].
  ///
  /// Two consequences worth knowing:
  ///
  /// - The result never depends on the host machine's timezone, so the same
  ///   call answers the same everywhere. `DateTime(2024, 6, 15, 12)` and
  ///   `DateTime.utc(2024, 6, 15, 12)` are the same reading and convert alike.
  /// - To re-render an instant you already hold — the other, equally common
  ///   operation — use [toTZDateTime] instead, which preserves the moment.
  ///
  /// A reading that no clock in [inTimezone] ever showed (the spring-forward
  /// gap) or that it showed twice (the autumn fall-back) still resolves to
  /// exactly one instant. Which one is `package:timezone`'s choice, not a
  /// policy stated here: both cases fall out of its guess-and-correct
  /// `Location.translateToUtc`, and for Europe/Berlin in 2024 both land on
  /// standard time. It is deterministic, so it is safe to rely on — but pin it
  /// with a test if a caller depends on the exact side.
  ///
  /// [dt] The wall-clock reading to convert.
  /// [inTimezone] The timezone the reading is expressed in.
  /// [toTimezone] The timezone to render the resulting instant in.
  ///
  /// Example:
  /// ```dart
  /// final utc = TomTimezone.utc;
  /// final tokyo = TomTimezone.fromName('Asia/Tokyo')!;
  ///
  /// final utcMidnight = DateTime.utc(2024, 6, 15, 0, 0);
  /// final tokyoTime = TomTimezone.changeLocation(utcMidnight, utc, tokyo);
  /// print(tokyoTime.hour); // 9 (9 AM in Tokyo)
  ///
  /// // The source zone is what makes the answer differ: the same reading,
  /// // taken as a Tokyo clock rather than a UTC one, is already 9 AM there.
  /// print(TomTimezone.changeLocation(utcMidnight, tokyo, tokyo).hour); // 0
  /// ```
  static DateTime changeLocation(
    DateTime dt,
    TomTimezone inTimezone,
    TomTimezone toTimezone,
  ) {
    // Construct rather than convert: `TZDateTime(location, ...)` resolves a
    // wall-clock reading to an instant, whereas `TZDateTime.from` would carry
    // the instant of `dt` across unchanged and discard `inTimezone` entirely.
    final instant = tz.TZDateTime(
      inTimezone.location,
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
      dt.millisecond,
      dt.microsecond,
    );
    return tz.TZDateTime.from(instant, toTimezone.location);
  }
}
