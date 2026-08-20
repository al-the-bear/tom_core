/// Shared start-up for the samples.
///
/// Every sample has a `main()` so it can be run on its own:
///
/// ```bash
/// dart run --enable-asserts example/samples/observable/03_tom_class.dart
/// ```
///
/// The `--enable-asserts` is not decoration, and [bootstrapSamples] refuses to
/// run without it — see [requireAsserts], which it calls first and which every
/// other sample calls directly.
///
/// Samples that build reflected types — anything using `@tomReflector`,
/// `TomClass`, or the preference/scheduling codecs that reflect over their
/// values — must register the generated reflection data before they run, or
/// the first construction fails with *"Reflection has not been initialized"*.
/// Those samples call [bootstrapSamples] as the first statement of `main()`;
/// the ones that reflect over nothing call [requireAsserts] instead, from
/// `sample_asserts.dart`, and must not call both.
///
/// This file is the only place that names `run_all_samples.reflection.dart`.
/// That file is generated (`dart run build_runner build`), it is one large
/// registry for the whole `samples/` tree, and importing it costs roughly three
/// seconds of compile time per entry point — which is why samples that do not
/// need it do not pay for it, and why the flag check lives in its own
/// registry-free library rather than here.
///
/// ## Timezones need no bootstrap
///
/// `TomTimezone` loads the embedded IANA database itself, synchronously and
/// without I/O, the first time [TomTimezone.timezones] is read. Sample runners
/// used to open with
///
/// ```dart
/// await tz.initializeTimeZone();
/// final _ = TomTimezone.timezones;
/// await Future.delayed(Duration(milliseconds: 100)); // "wait for async init"
/// ```
///
/// but there is no asynchronous initialization to wait for, so the delay was
/// waiting on nothing. The timezoned samples — the ones that would notice —
/// pass without any of it, in every zone the matrix sweeps. If a future sample
/// ever does need the database loaded eagerly, read `TomTimezone.timezones`;
/// do not reinstate the sleep.
library;

import 'run_all_samples.reflection.dart';
import 'sample_asserts.dart';

export 'sample_asserts.dart' show requireAsserts;

/// Prepares a sample to run: requires `--enable-asserts`, then registers the
/// generated reflection data.
///
/// Call this first in the `main()` of any sample that constructs a reflected
/// type, and in every group runner. It is idempotent: the generated
/// `initializeReflection` only assigns the registry fields, so a sample run
/// through a group runner that has already bootstrapped is unaffected.
///
/// If asserts are disabled it prints the correct command and exits `2` instead
/// of running — a flagless run would otherwise print success while checking
/// nothing (see [requireAsserts]).
void bootstrapSamples() {
  requireAsserts();
  initializeReflection();
}
