/// The small harness every scheduling example needs.
///
/// [FakeClock] and [settle] exist for the same reason: a scheduler is a
/// *clock-driven* component whose work finishes *asynchronously*, and an example
/// that observed either property honestly would print numbers that differ on
/// every run. Neither fakes anything about the scheduler — they only give the
/// example a clock it can move and a way to wait for what a tick started.
/// [quietly] is unrelated to timing; it keeps a deliberately provoked failure
/// from writing its (correct) log output into the sample's stdout.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A clock the example moves by hand.
///
/// [TomScheduler] takes its `clock` as a `DateTime Function()`, so a job that
/// fires "every 15 minutes" can be walked across an hour without waiting one.
/// This is not a testing-only affordance bolted on for the example: it is the
/// same seam production uses to run a scheduler against a simulated timeline,
/// and it is why every assertion below is an equality rather than a range.
class FakeClock {
  /// The instant the clock currently reads.
  DateTime now;

  /// Starts the clock at [now].
  FakeClock(this.now);

  /// The `DateTime Function()` a scheduler, store or lock expects.
  DateTime call() => now;

  /// Moves the clock forward by [by].
  ///
  /// Nothing is scheduled by moving it — the next `tick()` simply sees a later
  /// "now". Time passing and work happening are separate events here, which is
  /// exactly the separation that makes the outcome reproducible.
  void advance(Duration by) => now = now.add(by);
}

/// Lets the runs a `tick()` started actually finish.
///
/// `tick()` deliberately does not await the work it dispatches — a slow job
/// must not hold up the next window of a fast one — so completion, the store
/// write and the lease release all land in later turns of the event loop. Any
/// assertion about the *aftermath* of a run has to yield first.
///
/// The generous turn count is deliberate. How many turns a dispatch takes is an
/// implementation detail of the scheduler, and a caller that encodes the exact
/// number breaks the next time the runtime gains an `await`. Twenty turns is
/// far more than the path needs and costs nothing, because each is an empty
/// event-loop cycle.
Future<void> settle([int turns = 20]) async {
  for (var turn = 0; turn < turns; turn++) {
    await Future<void>(() {});
  }
}

/// Runs [body] with logging switched off, and restores the previous level.
///
/// Scan-time job errors are raised with `autoLog: true`, which is right: a
/// start-up that refuses to register a job must say so even if nobody catches
/// the exception. An example that *provokes* such a failure on purpose inherits
/// that output, and a page of stack traces between two ✓ lines reads like a
/// broken sample rather than a demonstrated guarantee.
///
/// Note what this does and does not change: the exception is still thrown, still
/// caught, and still asserted on. Only the log write is suppressed, and only for
/// the duration of the call.
T quietly<T>(T Function() body) {
  tomLog.pushLogLevel(TomLogLevel.none);
  try {
    return body();
  } finally {
    tomLog.popLogLevel();
  }
}
