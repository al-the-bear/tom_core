import 'package:timezone/data/latest.dart' as tz;

Future<int> tomSetupTimezones() async {
  tz.initializeTimeZones();
  return 0;
}

/// Synchronously loads the embedded timezone database.
///
/// On native (Flutter / VM) platforms the full IANA database is bundled with
/// the package, so it can be initialized synchronously on first access with no
/// I/O. This backs the synchronous lazy-init path of [TomTimezone].
void tomSetupTimezonesSync() {
  tz.initializeTimeZones();
}
