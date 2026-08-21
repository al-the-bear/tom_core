import 'package:timezone/standalone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Loads the IANA timezone database — the fallback implementation.
///
/// This library is the default arm of the conditional import in
/// `timezones.dart`, chosen only where neither `dart:io` nor `dart:js` is
/// available. Reads the database from disk via `package:timezone/standalone`.
/// Resolves to `0`.
Future<int> tomSetupTimezones() async {
  await tz.initializeTimeZone();
  return 0;
}

/// Synchronously loads the embedded timezone database.
///
/// Uses the bundled IANA database (`package:timezone/data/latest.dart`) so the
/// zone data is available synchronously on first access, with no file I/O.
/// This backs the synchronous lazy-init path of `TomTimezone`.
void tomSetupTimezonesSync() {
  tz_data.initializeTimeZones();
}
