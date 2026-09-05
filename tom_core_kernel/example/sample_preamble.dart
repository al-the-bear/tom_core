/// What every sample does before it demonstrates anything.
///
/// Two duties, both process-wide, both belonging to whatever *starts* a sample
/// rather than to the sample itself: turn a flagless run into a loud failure,
/// and give the process a platform identity so its log lines are labelled.
///
/// ## Duty one: refuse to run without asserts
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
/// ## Duty two: establish the process platform
///
/// `TomPlatformUtils` is the indirection every Tom library goes through instead
/// of touching `dart:io`, and until an application installs an implementation
/// the process answers with [TomFallbackPlatformUtils], whose
/// `getIsolateName()` is the empty string. The framework's log header is built
/// as `${TomPlatformUtils.current.getIsolateName()}-$isolateName`, so on the
/// fallback every framework log line reads
///
/// ```text
/// 2026-09-05 03:13:14.994291 - INFO    Simple string message
/// ```
///
/// with a bare `-` where the isolate identity belongs, instead of
/// `main-main`.
///
/// Installing it here rather than in `run_all_samples.dart` is the point.
/// Establishing it in the master runner alone would relabel a full run and
/// leave every *individual* sample run unlabelled — the same two-format fault
/// the master run used to have, moved onto a different axis. Every way of
/// starting a sample goes through this function, so one rule covers all three:
/// **whatever prepares a sample to run establishes the process platform.**
///
/// The alternative it replaces was worse than either: the identity used to
/// arrive as a *side effect* of `samples/beanlocator/01_…`, the first sample of
/// the first module, which installed it while demonstrating something else and
/// which every later module then silently inherited. A sample is not the right
/// owner of process-wide state, and the accident proved it by breaking the
/// moment that sample's imports were tidied.
///
/// [TomStandalonePlatformUtils] comes from `tom_basics_console`, named as a
/// direct dev-dependency. The kernel itself is platform-neutral by design and
/// never reaches for `dart:io`; only the samples, which are console programs,
/// may.
///
/// ## Usage
///
/// ```dart
/// void main() {
///   prepareSampleProcess();
///   run();
/// }
/// ```
///
/// ## Why this is not part of `sample_bootstrap.dart`
///
/// [bootstrapSamples] does three things: these two, and registering the
/// generated reflection data. Only the samples that build reflected types need
/// the third, and it is expensive — `sample_bootstrap.dart` imports
/// `run_all_samples.reflection.dart`, one large registry for the whole
/// `samples/` tree, costing roughly three seconds of compile time per entry
/// point.
///
/// The preamble needs none of that. Keeping it in this registry-free library is
/// what lets the ~77 samples that reflect over nothing be prepared too, instead
/// of paying three seconds each or going unprepared. Samples that do reflect
/// call [bootstrapSamples], which calls [prepareSampleProcess] for them — they
/// must not call both.
library;

import 'dart:io';

// `TomPlatformUtils` and `TomStandalonePlatformUtils` both arrive through this
// one import: `tom_basics_console` re-exports the platform-neutral contract
// alongside the standalone implementation of it.
import 'package:tom_basics_console/tom_basics_console.dart';

/// Prepares the process a sample is about to run in.
///
/// Call this as the first statement of a sample's `main()`. Samples that also
/// need the reflection registry call `bootstrapSamples()` instead, which begins
/// by calling this.
///
/// Refuses a flagless run — exiting rather than throwing, because the reader's
/// mistake is a missing flag and a stack trace would bury the one sentence that
/// fixes it. Exit `2` — not `1` — so `tool/run_standalone_examples.sh`'s log
/// distinguishes "never ran" from "ran and failed".
///
/// Then installs [TomStandalonePlatformUtils], so the framework's log lines
/// carry an isolate identity. A sample that wants to demonstrate a *different*
/// platform implementation installs its own and restores this one when it is
/// done; see `samples/runtime/01_platform_detection_example.dart`.
void prepareSampleProcess() {
  if (!_assertsEnabled) {
    stderr.writeln(
      'Asserts are disabled, so this sample would verify nothing.\n'
      'Every check in the samples is an `assert`, and `dart run` strips them.\n'
      'Re-run with the flag:\n'
      '\n'
      '    dart run --enable-asserts <sample>\n',
    );
    exit(2);
  }
  TomPlatformUtils.setCurrentPlatform(TomStandalonePlatformUtils());
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
