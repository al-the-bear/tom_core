import 'package:timezone/browser.dart' as tz;

import 'sync_load_refusal.dart';

/// Fetches the IANA timezone database — the web implementation.
///
/// **Mandatory on web, and must be awaited.** The browser has no bundled
/// database and no synchronous way to obtain one, so every `TomTimezone`
/// access before this completes throws [StateError] — not the module's
/// `TomTimezoneException`, because the fault is in the application's startup
/// rather than in any value a caller passed, and catching it leaves the module
/// as unusable as it was. Call this during application startup, ahead of
/// anything that reads a timezone. Resolves to `0`.
Future<int> tomSetupTimezones() async {
  await tz.initializeTimeZone();
  return 0;
}

/// Web has no synchronous initialization path.
///
/// On the browser the timezone database is fetched over the network, so it
/// cannot be loaded synchronously. Applications must call (and await)
/// [tomSetupTimezones] during startup before any synchronous timezone access.
/// If the database is still empty when `TomTimezone` is first accessed, this
/// refuses — with the [StateError] of [refuseSynchronousTimezoneLoad], which
/// says what is missing — rather than returning empty results.
void tomSetupTimezonesSync() => refuseSynchronousTimezoneLoad();
