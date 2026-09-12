/// How the module refuses a synchronous load of the timezone database, kept
/// apart from the arm that raises it.
///
/// `init_tz_web.dart` is the arm that refuses, and it reaches
/// `package:timezone/browser.dart`, so it cannot be imported anywhere but a
/// browser. Refusing asks nothing of any platform. Written out there, the
/// refusal could only be checked by reading a source file; written here, the
/// suite that runs on the VM executes the very refusal a browser meets, and
/// the arm is left holding one line that says which platform meets it.
library;

/// Refuses a synchronous load of the IANA timezone database.
///
/// A [StateError], and the only failure in this module that is not a
/// `TomTimezoneException`. The difference is what the caller is being told. The
/// exceptions answer a question about a value — this zone is not in the
/// database, that offset belongs to no zone — and a caller can catch one,
/// report it, and carry on with the rest of its work. This says the module is
/// not usable yet: the database was never fetched, every later access fails the
/// same way, and no handler repairs that. It is a fault in the application's
/// startup, which is what an [Error] means.
///
/// Reached on the browser, where the database arrives over the network and
/// `tomSetupTimezones()` must be awaited during startup. Native platforms never
/// see it — their database is embedded and loads synchronously on first access.
Never refuseSynchronousTimezoneLoad() => throw StateError(
  'Timezone database is not initialized. On web, call and await '
  'tomSetupTimezones() during application startup before using TomTimezone.',
);
