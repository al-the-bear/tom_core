/// Shared start-up for the samples.
///
/// Every sample has a `main()` so it can be run on its own:
///
/// ```bash
/// dart run --enable-asserts example/samples/observable/03_tom_class.dart
/// ```
///
/// The `--enable-asserts` is not decoration, and [bootstrapSamples] refuses to
/// run without it — see *Asserts are the samples' only verification* below.
///
/// Samples that build reflected types — anything using `@tomReflector`,
/// `TomClass`, or the preference/scheduling codecs that reflect over their
/// values — must register the generated reflection data before they run, or
/// the first construction fails with *"Reflection has not been initialized"*.
/// Those samples call [bootstrapSamples] as the first statement of `main()`;
/// the ones that reflect over nothing call nothing.
///
/// This file is the only place that names `run_all_samples.reflection.dart`.
/// That file is generated (`dart run build_runner build`), it is one large
/// registry for the whole `samples/` tree, and importing it costs roughly three
/// seconds of compile time per entry point — which is why samples that do not
/// need it do not pay for it.
///
/// ## Asserts are the samples' only verification
///
/// A sample demonstrates an API by *stating what it should produce*, and it
/// states that with `assert`. There is no other check in the tree: roughly 1800
/// `assert`s and not one `expect`. Dart strips asserts in release mode, and
/// `dart run` **is** release mode, so a sample run without `--enable-asserts`
/// executes every line, prints every "✓ … passed", exits 0 — and verifies
/// nothing whatsoever.
///
/// That is a worse failure than a crash, because it is indistinguishable from
/// success. It is also not hypothetical: two real defects in these samples (a
/// shifted instant that lost its `isUtc`, and a codec example that threw on its
/// fourth case) sat behind exactly this, green in every flagless run.
///
/// So [bootstrapSamples] checks the flag and exits with a message naming the
/// correct command rather than letting a hollow run report success. Every group
/// runner and `run_all_samples.dart` call it, so the entry points a reader
/// actually starts from are covered. The samples that reflect over nothing call
/// nothing — they must not import the registry above for a flag check — and are
/// covered instead by `tool/run_standalone_examples.sh`, which both runs them
/// with the flag and fails the sweep if any sample's header documents a command
/// without it.
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

import 'dart:io';

import 'run_all_samples.reflection.dart';

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
/// nothing (see the library documentation above).
void bootstrapSamples() {
  _requireAsserts();
  initializeReflection();
}

/// Whether the VM was started with `--enable-asserts`.
///
/// The assignment inside the `assert` is the standard detection idiom: the
/// expression is the assert's condition, so it is evaluated only when asserts
/// are on, and `enabled` stays `false` in a run where they were stripped.
bool get _assertsEnabled {
  var enabled = false;
  assert(enabled = true);
  return enabled;
}

/// Stops a flagless run before it can report a success it did not verify.
///
/// Exits rather than throws: the reader's mistake is a missing flag, and a
/// stack trace would bury the one sentence that fixes it. Exit `2` — not `1` —
/// so the sweep script's log distinguishes "never ran" from "ran and failed".
void _requireAsserts() {
  if (_assertsEnabled) return;
  stderr.writeln(
    'Asserts are disabled, so this sample would verify nothing.\n'
    'Every check in the samples is an `assert`, and `dart run` strips them.\n'
    'Re-run with the flag:\n'
    '\n'
    '    dart run --enable-asserts <sample>\n',
  );
  exit(2);
}
