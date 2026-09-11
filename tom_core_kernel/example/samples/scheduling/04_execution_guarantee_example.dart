/// The execution guarantee, written as code rather than as a warning.
///
/// > **A job body may run more than once for the same window. It will not
/// > silently run zero times. Write bodies to be idempotent.**
///
/// That is *at-least-once*, and it is a choice, not an unfixed limitation. There
/// are only two options and they fail in opposite directions. **At-most-once**
/// marks a run complete *before* executing it, so a node that dies mid-run
/// leaves work that was silently never done — the nightly invoice run that
/// produced no invoices and told nobody. **At-least-once** marks it complete
/// *after*, so a node that dies mid-run leaves a run somebody picks up, and the
/// work happens — possibly twice. For scheduled business work silent omission is
/// the worse failure, so the module takes at-least-once and gives the job author
/// the tools to make duplication harmless.
///
/// The consequence is that idempotence is the *body's* responsibility, and these
/// examples are about where the duplicate comes from and what the author does
/// about it:
///
/// 1. A retry — the duplicate the framework promises you outright.
/// 2. A run reserved and lost, which is free to re-offer because nothing ran.
/// 3. A run interrupted mid-execution, where re-offering is the job's call.
/// 4. The pause that no store can rule out, and the fencing token that survives
///    it when the effect genuinely cannot be made idempotent.
/// 5. A body that outlives its timeout, which the scheduler holds the job for
///    rather than starting the retry beside it.
///
/// The last one steps back from the duplicate to the policy that spaces them:
/// how far apart retries actually fall, and why the curve settles below the
/// ceiling rather than on it.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/scheduling/04_execution_guarantee_example.dart
/// ```
library;

import 'dart:async';
import 'dart:math';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'scheduling_support.dart';

import '../../sample_preamble.dart';

// =============================================================================
// EXAMPLE 1: The Duplicate You Are Promised
// =============================================================================

/// A failing first attempt, under two bodies that differ only in their key.
///
/// Nothing here is a fault condition being tolerated: a retry is the framework
/// working exactly as documented, and it is the duplicate every job author will
/// meet first. `run.scheduledFor` is what makes it harmless — it is stable
/// across every attempt and every node, so it is a natural idempotence key,
/// which is precisely why the body is handed the window instead of "now".
///
/// Note *where* the failure is placed. A body that throws before it does
/// anything is the easy case and proves nothing: there is no duplicate, because
/// there was no first effect. The case that matters — and the one at-least-once
/// is actually about — is the body whose work **landed** and whose
/// acknowledgement did not. From outside, the two are indistinguishable, so the
/// scheduler must assume the second and retry.
class RetryIdempotenceExample {
  /// Bad: appends unconditionally, so a retry duplicates the row.
  static final List<String> appended = [];

  /// Good: keyed on the window, so a second execution overwrites rather than
  /// adds.
  static final Map<DateTime, String> upserted = {};

  static int attemptsMade = 0;
  static int finalAttempt = 0;
  static TomJobRunState? finalState;

  static Future<void> example1TheDuplicateYouArePromised() async {
    appended.clear();
    upserted.clear();
    attemptsMade = 0;

    final clock = FakeClock(DateTime.utc(2026, 3, 2, 9));
    final store = TomMemoryJobStore();
    final scheduler = TomScheduler(
      store: store,
      dispatcher: const TomInlineJobDispatcher(),
      clock: clock.call,
      ownerId: 'node-a',
      tickJitter: 0,
      onAlert: (_) {},
    );

    scheduler.register(
      TomJobDefinition(
        name: 'daily-report',
        schedule: TomIntervalSchedule(const Duration(hours: 1)),
        body: (run) => _ReportBody(run),
        // One retry, a minute later, with the jitter turned off so the example
        // knows when to move the clock. Jitter exists to stop a cluster's
        // retries arriving in lockstep; it is not part of what is being shown.
        retryPolicy: const TomRetryPolicy(
          maxAttempts: 2,
          initialBackoff: Duration(minutes: 1),
          jitter: 0,
        ),
      ),
    );

    await scheduler.tick();
    clock.advance(const Duration(hours: 1));
    await scheduler.tick();
    await settle();

    // Attempt 1 threw. The run is pending again, dated to the same window and
    // due after the backoff.
    clock.advance(const Duration(minutes: 2));
    await scheduler.tick();
    await settle();

    // The 10:00 window — the one that failed and retried. Beside it the store
    // holds the pending look-ahead for 11:00, which every tick plans.
    final run = (await store.all()).firstWhere(
      (r) => r.scheduledFor == DateTime.utc(2026, 3, 2, 10),
    );
    finalAttempt = run.attempt;
    finalState = run.state;

    await scheduler.close();

    assert(attemptsMade == 2, 'One failure, one retry');
    assert(
      run.state == TomJobRunState.succeeded && finalAttempt == 2,
      'The run succeeded on its second attempt — one run, two executions',
    );
    assert(
      appended.length == 2,
      'The unkeyed body wrote its row twice. Nothing failed, nothing was '
      'reported: the report is simply in there twice and no operator will ever '
      'be told',
    );
    assert(
      upserted.length == 1,
      'The window-keyed body wrote the same row twice and is therefore correct '
      'once — which is all "idempotent" has to mean here',
    );
    assert(
      upserted.keys.single == DateTime.utc(2026, 3, 2, 10),
      'And it is keyed on the window, not on when the retry happened to land',
    );
  }
}

/// Writes the report two ways, then loses its first acknowledgement.
class _ReportBody extends TomCommand {
  final TomJobRun run;

  _ReportBody(this.run);

  @override
  Future<Object?> execute() async {
    RetryIdempotenceExample.attemptsMade++;

    final body = 'report for ${run.scheduledFor.toIso8601String()}';
    // Both lines do the same work; only the second survives being run twice.
    RetryIdempotenceExample.appended.add(body);
    RetryIdempotenceExample.upserted[run.scheduledFor] = body;

    if (run.attempt == 1) {
      // The report is written. What failed is the *reply* — a socket closing
      // after the commit, a timeout on the response, a node dying between the
      // effect and the return. The scheduler sees a thrown attempt and cannot
      // tell it from one that never started, so it retries, and the body above
      // runs a second time.
      throw StateError('the report was written, but the commit reply was lost');
    }
    return body;
  }
}

// =============================================================================
// EXAMPLE 2: Reserved And Lost — Free To Re-Offer
// =============================================================================

/// The cheap half of recovery, and why the store records `startedAt` at all.
///
/// A node can die between claiming a run and dispatching it. Nothing executed,
/// so nothing can repeat, and the run goes back on the queue unconditionally —
/// no job policy is consulted and no attempt is charged, because charging one
/// would let a crash loop eat a job's whole retry budget without ever running
/// its body.
class ReservedAndLostExample {
  static TomJobRunState? stateAfterRecovery;
  static int attemptAfterRecovery = 0;
  static bool claimCleared = false;

  static Future<void> example2ReservedAndLost() async {
    final store = TomMemoryJobStore();
    final claimedAt = DateTime.utc(2026, 3, 2, 10);
    await store.enqueue(
      TomJobRun(
        id: 'run-1',
        jobName: 'daily-report',
        scheduledFor: claimedAt,
        runAt: claimedAt,
      ),
    );

    // node-a reserves the run — and then dies, before `markStarted` was ever
    // called. This is what the crash looks like in the store.
    await store.claimDue(claimedAt, 'node-a');

    // A surviving peer, twenty minutes later, with a fifteen-minute lease.
    final recovered = await store.recoverAbandoned(
      DateTime.utc(2026, 3, 2, 10, 20),
      const Duration(minutes: 15),
      // The predicate is consulted only for a run that had started. This one
      // had not, so the answer below is never asked for.
      requestsRecovery: (_) => false,
    );

    stateAfterRecovery = recovered.single.state;
    attemptAfterRecovery = recovered.single.attempt;
    claimCleared = recovered.single.claimedBy == null;

    assert(
      stateAfterRecovery == TomJobRunState.pending,
      'A reservation that was never started always comes back, whatever the '
      'job says about recovery: startedAt is null, so nothing executed',
    );
    assert(
      attemptAfterRecovery == 1,
      'And it is still attempt 1 — the scheduler\'s death is not the job\'s '
      'fault, so it does not spend the job\'s retry budget',
    );
    assert(claimCleared, 'The dead node no longer holds it');
  }
}

// =============================================================================
// EXAMPLE 3: Interrupted Mid-Execution — The Job's Call
// =============================================================================

/// The expensive half, where the framework refuses to decide for you.
///
/// A `running` run whose body had already begun is a different animal:
/// re-running it repeats whatever it had already done. Whether that is safe is a
/// property of the *job*, not of the store, so the store asks — and a job that
/// has not said yes is failed terminally with an explanation rather than
/// silently re-run. That is the one place the module chooses omission over
/// duplication, and it does it loudly, because an operator now has to decide.
class InterruptedMidExecutionExample {
  static TomJobRunState? declinedState;
  static String? declinedError;
  static TomJobRunState? recoveredState;

  static Future<void> example3InterruptedMidExecution() async {
    final store = TomMemoryJobStore();
    final window = DateTime.utc(2026, 3, 2, 10);
    for (final job in ['charge-cards', 'rebuild-search-index']) {
      await store.enqueue(
        TomJobRun(
          id: 'run-$job',
          jobName: job,
          scheduledFor: window,
          runAt: window,
        ),
      );
    }

    // Both claimed *and started* by node-a, which then died mid-body.
    for (final run in await store.claimDue(window, 'node-a')) {
      await store.markStarted(run, window);
    }

    final recovered = await store.recoverAbandoned(
      DateTime.utc(2026, 3, 2, 10, 20),
      const Duration(minutes: 15),
      // Rebuilding an index from scratch is safe to repeat. Charging cards is
      // not, and no framework can tell which is which.
      requestsRecovery: (jobName) => jobName == 'rebuild-search-index',
    );

    final byName = {for (final run in recovered) run.jobName: run};
    declinedState = byName['charge-cards']!.state;
    declinedError = byName['charge-cards']!.lastError;
    recoveredState = byName['rebuild-search-index']!.state;

    assert(
      declinedState == TomJobRunState.failed,
      'Not re-queued: without requestsRecovery the module will not repeat work '
      'that may already have happened',
    );
    assert(
      declinedError == TomJobStore.recoveryDeclinedError,
      'And it says why, in the run itself — the operator inherits a decision '
      'the framework made on the job\'s behalf, so the record has to explain '
      'it. This is the counterpart to the runAbandoned alert: one says "it '
      'will run again", the other says "it will not, and somebody has to '
      'decide what to do"',
    );
    assert(
      recoveredState == TomJobRunState.pending,
      'The job that declared itself recoverable goes back on the queue — and '
      'this is exactly the at-least-once window: its body will run a second '
      'time for a window it may already have processed',
    );
  }
}

// =============================================================================
// EXAMPLE 4: The Pause No Store Can Rule Out
// =============================================================================

/// Where the last duplicate comes from, and the one way to make it harmless.
///
/// With a lease lock configured, one node holds a window at a time under normal
/// operation. A duplicate needs a node to be **paused for longer than its lease
/// TTL** — a stop-the-world pause, a suspended VM, a wedged disk — so its lease
/// lapses, a peer takes over, and the original then wakes up and finishes. The
/// scheduler notices on its next heartbeat and stops the displaced node from
/// *recording* an outcome, but by then the work may already have happened twice.
///
/// Closing that gap is not something the scheduler can do alone: it needs the
/// protected resource to check the **fencing token**, which is strictly
/// increasing per resource across acquisitions. Against a token-checking
/// resource the effect is single-fire even under a pause. Against everything
/// else, idempotence is the contract.
class FencingTokenExample {
  /// Short enough that the pause below outlasts it — which is exactly the
  /// condition a duplicate needs.
  static const Duration ttl = Duration(minutes: 1);

  static int? firstToken;
  static int? secondToken;
  static bool staleWriteRejected = false;
  static String? finalContents;
  static bool renewRefused = false;

  static Future<void> example4TheFencingToken() async {
    final clock = FakeClock(DateTime.utc(2026, 3, 2, 10));
    final lock = TomMemoryLeaseLock(clock: clock.call);
    final ledger = _FencedLedger();

    // node-a takes the job and starts working.
    final first = (await lock.acquire('job:charge-cards', 'node-a', ttl))!;
    firstToken = first.token;

    // …and is frozen for longer than the TTL. It is not dead — it is going to
    // wake up and try to finish.
    clock.advance(const Duration(minutes: 5));

    // node-b sees a lapsed lease and takes over, which is the whole point of a
    // TTL: a holder that died must stop blocking the resource.
    final second = (await lock.acquire('job:charge-cards', 'node-b', ttl))!;
    secondToken = second.token;
    ledger.write(second.token, 'charged by node-b');

    // node-a wakes up. It does not know it lost, and its work is already done —
    // this is the moment at-least-once is talking about.
    staleWriteRejected = !ledger.write(first.token, 'charged by node-a');
    finalContents = ledger.contents;

    // The scheduler's own guard closes the *bookkeeping* half on the next
    // heartbeat: the renewal fails, so node-a stops treating its result as
    // authoritative and raises a leaseLost alert. That is what keeps the run
    // record honest — but it happens after the body, which is why the ledger
    // above has to defend itself.
    renewRefused = await lock.renew(first, ttl) == null;

    lock.close();

    assert(firstToken == 1, 'Fencing tokens start at 1');
    assert(
      secondToken == 2,
      'Tokens increase strictly per resource across acquisitions, so a later '
      'holder always outranks an earlier one — that ordering is the entire '
      'mechanism',
    );
    assert(
      staleWriteRejected,
      'The resource rejected the displaced holder by token alone. It never had '
      'to know about schedulers, leases or clusters — only that it had already '
      'served a higher token',
    );
    assert(
      finalContents == 'charged by node-b',
      'One charge, from the node that actually held the lease',
    );
    assert(
      renewRefused,
      'And the displaced node finds out on its next heartbeat, which is when '
      'the leaseLost alert is raised',
    );
  }
}

/// A resource that fences: it remembers the highest token it has served and
/// refuses anything older.
///
/// Five lines, and they are the difference between "probably fine" and
/// single-fire under a pause. A real one does the same check inside the
/// transaction that performs the effect.
class _FencedLedger {
  int _highestSeen = 0;
  String contents = '';

  /// Applies [value] if [token] is at least as new as anything already served.
  bool write(int token, String value) {
    if (token < _highestSeen) return false;
    _highestSeen = token;
    contents = value;
    return true;
  }
}

// =============================================================================
// EXAMPLE 5: A Body That Outlives Its Timeout
// =============================================================================

/// A timeout ends the attempt, not the body.
///
/// Dart cannot cancel arbitrary asynchronous work, so when an attempt overruns
/// its `timeout` the scheduler fails it — alerts, records the failure, makes
/// the retry due — while the body carries on. What the scheduler will not do is
/// start that retry *beside* it. Until the first body returns, the job stays
/// held: on this node through its busy mark, across a cluster through its
/// lease, which the heartbeat keeps renewing. Releasing either at the timeout
/// would put two bodies in flight for one window — the very thing
/// `allowOverlap: false` promises against — on the one path certain to leave a
/// body running.
///
/// The duplicate that remains is the sequential one. The late body did its
/// work, and the retry does it again afterwards. That is at-least-once, not a
/// breach of it, and the window key absorbs it exactly as it absorbs the retry
/// in example 1.
class OverrunningBodyExample {
  /// The report store, keyed on the window as example 1 recommends.
  static final Map<DateTime, String> upserted = {};

  static int executions = 0;
  static int overrunningAfterTimeout = -1;
  static int executionsWhileHeld = -1;
  static TomJobRunState? finalState;

  /// Holds the first attempt's body open until the example lets it finish.
  static Completer<void> firstBodyGate = Completer<void>();

  static Future<void> example5ABodyThatOutlivesItsTimeout() async {
    upserted.clear();
    executions = 0;
    firstBodyGate = Completer<void>();

    final clock = FakeClock(DateTime.utc(2026, 3, 2, 9));
    final store = TomMemoryJobStore();
    final scheduler = TomScheduler(
      store: store,
      dispatcher: const TomInlineJobDispatcher(),
      clock: clock.call,
      ownerId: 'node-a',
      tickJitter: 0,
      onAlert: (_) {},
    );

    scheduler.register(
      TomJobDefinition(
        name: 'slow-report',
        schedule: TomIntervalSchedule(const Duration(hours: 1)),
        body: (run) => _SlowReportBody(run),
        // Absurdly short, so the example does not have to wait for it.
        timeout: const Duration(milliseconds: 20),
        // Due again the moment it fails, so the only thing holding the retry
        // back is the body still running.
        retryPolicy: const TomRetryPolicy(
          maxAttempts: 2,
          initialBackoff: Duration.zero,
          jitter: 0,
        ),
      ),
    );

    await scheduler.tick();
    clock.advance(const Duration(hours: 1));
    await scheduler.tick();
    // The timeout is a real timer; let it fire.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    overrunningAfterTimeout = scheduler.overrunningCount;

    // The retry is due, the scheduler is idle — and the first body has not
    // returned, so the pass does not start it.
    await scheduler.tick();
    await settle();
    executionsWhileHeld = executions;

    // The late body finishes. Only now is the job free, and the retry runs.
    firstBodyGate.complete();
    await settle();
    await scheduler.tick();
    await settle();

    final run = (await store.all()).firstWhere(
      (r) => r.scheduledFor == DateTime.utc(2026, 3, 2, 10),
    );
    finalState = run.state;
    await scheduler.close();

    assert(
      overrunningAfterTimeout == 1,
      'The attempt timed out with its body still running',
    );
    assert(
      executionsWhileHeld == 1,
      'The retry was due, but not started beside the body still in flight',
    );
    assert(executions == 2, 'After the body settled, the retry ran');
    assert(
      finalState == TomJobRunState.succeeded,
      'The run succeeded on its retry',
    );
    assert(
      upserted.length == 1,
      'Two executions, one after the other, and one row — the window key '
      'absorbs the sequential duplicate a timeout leaves',
    );
  }
}

/// A report whose first attempt takes far longer than its timeout.
class _SlowReportBody extends TomCommand {
  final TomJobRun run;

  _SlowReportBody(this.run);

  @override
  Future<Object?> execute() async {
    OverrunningBodyExample.executions++;
    if (run.attempt == 1) await OverrunningBodyExample.firstBodyGate.future;
    OverrunningBodyExample.upserted[run.scheduledFor] =
        'report for ${run.scheduledFor.toIso8601String()}';
    return 'written';
  }
}

// =============================================================================
// EXAMPLE 6: The Curve, And Why Its Ceiling Is Not Where You Left It
// =============================================================================

/// How far apart the retries of example 1 actually are, and the one arithmetic
/// surprise in `TomRetryPolicy`.
///
/// Example 1 turned jitter off and moved the clock by hand, because *when* the
/// retry landed was not what it was about. This is: the spacing is the part of
/// the policy operators tune under an incident, and it has a shape that four
/// field defaults do not convey.
///
/// The surprise is that the exponential curve **plateaus below `maxBackoff`**,
/// at `maxBackoff / (1 + jitter)`, and jitter fills the remaining gap. The
/// obvious implementation — grow, then jitter, then clamp — keeps the same
/// ceiling and destroys the spread exactly where it matters: a long outage
/// drives every node's every job to the ceiling together, and clamping there
/// hands them all the *same* retry instant, which is the thundering herd jitter
/// was added to prevent. Reserving the headroom up front keeps the full spread
/// at saturation, and the price is a plateau that sits a jitter's width low.
///
/// This example reads [TomRetryPolicy.backoffFor] directly rather than running
/// a scheduler. The wiring is example 1's subject; the arithmetic is this one's,
/// and putting a clock in front of it would only hide it.
class BackoffCurveExample {
  static List<Duration> steepCurve = [];
  static Duration plateau = Duration.zero;
  static Duration lowestJittered = const Duration(days: 1);
  static Duration highestJittered = Duration.zero;
  static List<Duration> defaultCurve = [];

  /// Deliberately extreme, so the plateau arrives on the second attempt and is
  /// visible in four numbers instead of ten.
  static const TomRetryPolicy _steep = TomRetryPolicy(
    maxAttempts: 6,
    initialBackoff: Duration(seconds: 10),
    multiplier: 10,
    maxBackoff: Duration(minutes: 1),
    jitter: 0.5,
  );

  static Future<void> example6TheCurveAndItsCeiling() async {
    // Without a Random, backoff is the bare curve: no jitter is applied, which
    // is what makes a policy testable at all.
    steepCurve = [
      1,
      2,
      3,
      4,
    ].map((attempt) => _steep.backoffFor(attempt)).toList();
    plateau = _steep.backoffFor(30);

    // With one, the same attempt spreads. Enough draws that "jitter reaches the
    // ceiling" is a fact about the arithmetic rather than about a lucky seed:
    // missing the top 1% twenty thousand times running has a probability of
    // about 1e-88.
    final random = Random(1);
    lowestJittered = const Duration(days: 1);
    highestJittered = Duration.zero;
    for (var draw = 0; draw < 20000; draw++) {
      final backoff = _steep.backoffFor(3, random);
      if (backoff < lowestJittered) lowestJittered = backoff;
      if (backoff > highestJittered) highestJittered = backoff;
    }

    // And the same shape under the defaults, which is the curve most jobs get.
    defaultCurve = List.generate(
      8,
      (index) => const TomRetryPolicy().backoffFor(index + 1),
    );

    assert(
      steepCurve.map((backoff) => backoff.inSeconds).join(',') == '10,40,40,40',
      'Ten seconds, then ten times that — except 100s is past the plateau, so '
      'attempt 2 already saturates. The curve is exponential until it is not; '
      'multiplier decides how fast you get to the ceiling, not how high it is',
    );
    assert(
      plateau == const Duration(seconds: 40) &&
          plateau.inMicroseconds ==
              _steep.maxBackoff.inMicroseconds ~/ (1 + _steep.jitter),
      'The plateau is 40s under a 60s ceiling — a third of the way down. Read '
      'maxBackoff as "the furthest a retry can ever be", not "where the curve '
      'settles"; with jitter at 0.5 those are 20 seconds apart',
    );
    assert(
      lowestJittered >= const Duration(seconds: 40) &&
          highestJittered <= _steep.maxBackoff,
      'Jitter is added upward only and never past the ceiling: no retry is '
      'earlier than the backoff the policy promised, and none is later than '
      'maxBackoff. Both halves matter — an earlier retry would undo the '
      'backoff, a later one would break the bound operators plan against',
    );
    assert(
      highestJittered >= const Duration(milliseconds: 59_400),
      'And the reserved headroom is used: the spread at saturation runs the '
      'full 40s..60s, which is the point of reserving it. Clamp-after-jitter '
      'would put every saturated job on 60s exactly',
    );
    assert(
      defaultCurve.map((backoff) => backoff.inSeconds).join(',') ==
          '30,60,120,240,480,960,1636,1636',
      'The default curve doubles from 30s for six attempts and then plateaus '
      'at 27m16s — the same rule, arriving slowly enough that a job hitting it '
      'has been failing for over an hour',
    );
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

Future<void> run() async {
  print('=== 04: Execution Guarantee Example ===\n');

  await RetryIdempotenceExample.example1TheDuplicateYouArePromised();
  print('1. The duplicate you are promised — a retry:');
  print('   body executions  : ${RetryIdempotenceExample.attemptsMade}');
  print('   final attempt    : ${RetryIdempotenceExample.finalAttempt}');
  print('   final run state  : ${RetryIdempotenceExample.finalState}');
  print('   unkeyed rows     : ${RetryIdempotenceExample.appended.length}');
  print('   window-keyed rows: ${RetryIdempotenceExample.upserted.length}');
  print(
    '   idempotence key  : '
    '${RetryIdempotenceExample.upserted.keys.single}',
  );
  print('');

  await ReservedAndLostExample.example2ReservedAndLost();
  print('2. Reserved and lost — free to re-offer, nothing had run:');
  print('   state         : ${ReservedAndLostExample.stateAfterRecovery}');
  print('   attempt       : ${ReservedAndLostExample.attemptAfterRecovery}');
  print('   claim cleared : ${ReservedAndLostExample.claimCleared}');
  print('');

  await InterruptedMidExecutionExample.example3InterruptedMidExecution();
  print('3. Interrupted mid-execution — recovery is the job\'s call:');
  print('   charge-cards : ${InterruptedMidExecutionExample.declinedState}');
  print('   why refused  : ${InterruptedMidExecutionExample.declinedError}');
  print('   search-index : ${InterruptedMidExecutionExample.recoveredState}');
  print('');

  await FencingTokenExample.example4TheFencingToken();
  print('4. The pause no store can rule out, fenced by the token:');
  print('   node-a token        : ${FencingTokenExample.firstToken}');
  print('   node-b token        : ${FencingTokenExample.secondToken}');
  print('   stale write refused : ${FencingTokenExample.staleWriteRejected}');
  print('   ledger contents     : ${FencingTokenExample.finalContents}');
  print('   renewal refused     : ${FencingTokenExample.renewRefused}');
  print('');

  await OverrunningBodyExample.example5ABodyThatOutlivesItsTimeout();
  print(
    '5. A body that outlives its timeout — the job is held until it settles:',
  );
  print(
    '   still running after the timeout : '
    '${OverrunningBodyExample.overrunningAfterTimeout}',
  );
  print(
    '   executions while held           : '
    '${OverrunningBodyExample.executionsWhileHeld}',
  );
  print(
    '   executions in total             : '
    '${OverrunningBodyExample.executions}',
  );
  print(
    '   final run state                 : '
    '${OverrunningBodyExample.finalState}',
  );
  print(
    '   window-keyed rows               : '
    '${OverrunningBodyExample.upserted.length}',
  );
  print('');

  await BackoffCurveExample.example6TheCurveAndItsCeiling();
  print('6. The backoff curve, and the plateau below its ceiling:');
  print('   steep curve 1..4 : ${BackoffCurveExample.steepCurve}');
  print('   plateau          : ${BackoffCurveExample.plateau}');
  print('   jittered lowest  : ${BackoffCurveExample.lowestJittered}');
  print('   jittered highest : ${BackoffCurveExample.highestJittered}');
  print('   default curve    : ${BackoffCurveExample.defaultCurve}');
  print('');
}

Future<void> main() {
  prepareSampleProcess();
  return run();
}
