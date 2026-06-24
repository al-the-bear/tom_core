import 'package:timezone/browser.dart' as tz;

Future<int> tomSetupTimezones() async {
  await tz.initializeTimeZone();
  return 0;
}

/// Web has no synchronous initialization path.
///
/// On the browser the timezone database is fetched over the network, so it
/// cannot be loaded synchronously. Applications must call (and await)
/// [tomSetupTimezones] during startup before any synchronous timezone access.
/// If the database is still empty when [TomTimezone] is first accessed, this
/// throws to surface the missing initialization clearly rather than returning
/// empty results.
void tomSetupTimezonesSync() {
  throw StateError(
    'Timezone database is not initialized. On web, call and await '
    'tomSetupTimezones() during application startup before using TomTimezone.',
  );
}
