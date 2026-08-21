import 'package:timezone/data/latest.dart' as tz;

/// Loads the IANA timezone database — the native (Flutter / VM) implementation.
///
/// Optional here: the database is bundled, so `TomTimezone` loads it
/// synchronously on first access whether or not this was called. It exists so
/// that startup code can be written once and run on both native and web, where
/// calling it is mandatory. Always resolves to `0`.
Future<int> tomSetupTimezones() async {
  tz.initializeTimeZones();
  return 0;
}

/// Synchronously loads the embedded timezone database.
///
/// On native (Flutter / VM) platforms the full IANA database is bundled with
/// the package, so it can be initialized synchronously on first access with no
/// I/O. This backs the synchronous lazy-init path of `TomTimezone`.
void tomSetupTimezonesSync() {
  tz.initializeTimeZones();
}
