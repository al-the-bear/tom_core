/// The samples' one verification mechanism, and the guard that keeps it honest.
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
/// So every sample's `main()` opens with [requireAsserts], which stops a
/// flagless run before it can report a success it did not verify:
///
/// ```dart
/// void main() {
///   requireAsserts();
///   run();
/// }
/// ```
///
/// ## Why this is not part of `sample_bootstrap.dart`
///
/// [bootstrapSamples] does two things: this flag check, and registering the
/// generated reflection data. Only the samples that build reflected types need
/// the second, and it is expensive — `sample_bootstrap.dart` imports
/// `run_all_samples.reflection.dart`, one large registry for the whole
/// `samples/` tree, costing roughly three seconds of compile time per entry
/// point.
///
/// The flag check needs none of that. Keeping it in this registry-free library
/// is what lets the ~77 samples that reflect over nothing be guarded too,
/// instead of paying three seconds each or going unprotected. Samples that do
/// reflect call [bootstrapSamples], which calls [requireAsserts] for them —
/// they must not call both.
library;

import 'dart:io';

/// Stops a flagless run before it can report a success it did not verify.
///
/// Call this as the first statement of a sample's `main()`. Samples that also
/// need the reflection registry call `bootstrapSamples()` instead, which begins
/// by calling this.
///
/// Exits rather than throws: the reader's mistake is a missing flag, and a
/// stack trace would bury the one sentence that fixes it. Exit `2` — not `1` —
/// so `tool/run_standalone_examples.sh`'s log distinguishes "never ran" from
/// "ran and failed".
void requireAsserts() {
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
