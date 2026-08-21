import 'package:timezone/data/latest.dart' as tz;

/// Loads the IANA timezone database from the copy embedded in the package —
/// the default implementation, selected wherever nothing more specific is.
///
/// This is the default arm of the conditional import in `timezones.dart`, so
/// it serves every target that is not a browser: the server, the CLI, the test
/// runner, and Flutter on mobile and desktop. It asks nothing of the platform
/// — `package:timezone/data/latest.dart` is a constant and a decoder, with no
/// file system and no network behind it — which is what makes it a safe
/// default. An arm reached where no condition holds cannot rely on any
/// condition being true.
///
/// Optional here: the database is bundled, so `TomTimezone` loads it
/// synchronously on first access whether or not this was called. It exists so
/// that startup code can be written once and run in the browser too, where
/// calling it is mandatory. Always resolves to `0`.
Future<int> tomSetupTimezones() async {
  tz.initializeTimeZones();
  return 0;
}

/// Synchronously loads the embedded timezone database.
///
/// The full IANA database ships with the package, so it can be initialized
/// synchronously on first access with no I/O. This backs the synchronous
/// lazy-init path of `TomTimezone`.
void tomSetupTimezonesSync() {
  tz.initializeTimeZones();
}
