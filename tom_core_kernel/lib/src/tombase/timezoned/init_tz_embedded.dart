import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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
/// calling it is mandatory.
///
/// Answers with the number of zones the database holds once loaded. Nothing
/// here is asynchronous — the work is [tomSetupTimezonesSync] — but the
/// function stays `async` rather than wrapping that call in a `Future.value`:
/// a decoder given a corrupt database throws, and a function that returns a
/// `Future` has to deliver its failures through that future, not past it.
Future<int> tomSetupTimezones() async => tomSetupTimezonesSync();

/// Synchronously loads the embedded timezone database.
///
/// The full IANA database ships with the package, so it can be initialized
/// synchronously on first access with no I/O. This backs the synchronous
/// lazy-init path of `TomTimezone`.
///
/// Answers with the number of zones the database holds once loaded — the same
/// count as [tomSetupTimezones], which is this call. A caller picks between
/// the two on whether it can await, not on what it wants to know.
int tomSetupTimezonesSync() {
  tzdata.initializeTimeZones();
  return tz.timeZoneDatabase.locations.length;
}
