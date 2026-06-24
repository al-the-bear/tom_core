import 'package:timezone/standalone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

Future<int> tomSetupTimezones() async {
  await tz.initializeTimeZone();
  return 0;
}

/// Synchronously loads the embedded timezone database.
///
/// Uses the bundled IANA database (`package:timezone/data/latest.dart`) so the
/// zone data is available synchronously on first access, with no file I/O.
/// This backs the synchronous lazy-init path of [TomTimezone].
void tomSetupTimezonesSync() {
  tz_data.initializeTimeZones();
}
