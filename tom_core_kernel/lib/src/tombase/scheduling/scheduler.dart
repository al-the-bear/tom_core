/// The scheduler runtime — the loop that turns schedules into dispatched work.
///
/// Everything the scheduler does happens in one method, [TomScheduler.tick].
/// [TomScheduler.start] merely arranges for it to be called periodically. That
/// shape is deliberate: a runtime whose behaviour is only reachable through a
/// timer can only be tested by waiting, and a test that waits for a nightly job
/// is a test nobody writes. Here the entire loop — window planning, catch-up,
/// claiming, dispatch, timeout, retry and alerting — is a single awaitable call
/// driven by an injectable clock, so a year of scheduling is exercised in
/// milliseconds and the code under test is the code that runs in production.
///
/// ## One pass, in order
///
/// 1. **Recover.** Runs whose lease expired go back to `pending`. This is how a
///    run that was in flight when the process died becomes visible again.
/// 2. **Plan.** For each clock-driven job, work out which windows have elapsed
///    since the last one on record and enqueue them per the job's
///    [TomMissedWindowPolicy], then enqueue the next future window. Enqueueing
///    is keyed by window, so this is idempotent and a replayed tick is a no-op.
/// 3. **Dispatch.** Claim the due runs, hand each body to the
///    [TomJobDispatcher], and record the outcome — success, a retry with
///    backoff, or terminal failure with an alert.
///
/// ## What this runtime does not do
///
/// It does not execute anything. Bodies go to a dispatcher, which in production
/// is the kernel's existing isolate pool.
///
/// ## Running more than one of these
///
/// Two schedulers pointed at the same store will both claim the same due run
/// unless something arbitrates between them. Supply a [TomLeaseLock] and this
/// scheduler becomes cluster-safe: every run is gated on a lease, the lease is
/// renewed while the work runs, and a node that dies has its work picked up when
/// its lease lapses. Leave the lock `null` — the default — and the scheduler
/// behaves exactly as a single-node runtime, with [TomJobDefinition.allowOverlap]
/// serialising a job's runs within this process only.
///
/// The execution guarantee is **at-least-once**, and it is stated in full in
/// `doc/scheduling/scheduling.md`. Job bodies must be idempotent. The lock makes
/// duplicate execution rare and bounded; it does not make it impossible, and a
/// runtime that claimed otherwise would be lying about a case its users will
/// eventually hit.
library;

import 'dart:async';
import 'dart:math';

import 'package:tom_basics/tom_basics.dart';

import '../isolate_pooling/tom_worker.dart';
import '../shutdown_cleanup/tom_shutdown_cleanup.dart';
import 'job_definition.dart';
import 'job_store.dart';
import 'lease_lock.dart';
import 'schedule.dart';

/// Drives registered [TomJobDefinition]s against a [TomJobStore].
class TomScheduler implements TomClosable {
  /// How many windows the catch-up scan will step through before giving up.
  ///
  /// A guard, not a policy: without it, a job with a minutely schedule whose
  /// store was last written a year ago would spin through half a million
  /// iterations on its first tick. At the default this is roughly ten weeks of
  /// minutely windows, far beyond any outage worth catching up on.
  static const int maxCatchUpScan = 100000;

  /// Durable storage for planned and in-flight runs.
  final TomJobStore store;

  /// Where work bodies are executed.
  final TomJobDispatcher dispatcher;

  /// How often [start] runs a [tick].
  final Duration tickInterval;

  /// How long a claim may go unrefreshed before the run is considered
  /// abandoned and returned to the queue.
  ///
  /// Must comfortably exceed the longest [TomJobDefinition.timeout] in the
  /// registry, or a slow-but-healthy run will be handed to a second attempt
  /// while the first is still going.
  final Duration leaseTimeout;

  /// Identifies this scheduler in [TomJobRun.claimedBy].
  final String ownerId;

  /// The clock. Injectable so tests can move time without waiting.
  final DateTime Function() clock;

  /// Where alerts go. Defaults to the framework log.
  final TomJobAlertSink onAlert;

  /// Randomness for retry jitter. Injectable so backoff is reproducible.
  final Random random;

  /// The most runs claimed in one pass.
  final int maxRunsPerTick;

  /// Cluster coordination, or `null` for a single-node scheduler.
  ///
  /// When present, no run is executed without first winning its lease, so two
  /// schedulers sharing a store cannot both execute the same run.
  final TomLeaseLock? lock;

  /// How long a coordination lease is taken for.
  ///
  /// Short is good: it bounds how long a dead node blocks its work. It is safe
  /// to keep it short because [leaseRenewInterval] pushes it forward for as long
  /// as the work is genuinely running, so this does **not** need to exceed the
  /// slowest job.
  final Duration leaseTtl;

  /// How often a held lease is renewed while its work runs.
  ///
  /// Must be comfortably shorter than [leaseTtl] — a third of it by default —
  /// so a single missed renewal does not lapse the lease. The gap is the margin
  /// that absorbs a slow store, a GC pause or a moment of clock skew.
  final Duration leaseRenewInterval;

  final Map<String, TomJobDefinition> _jobs = {};
  final Map<String, StreamSubscription<Object?>> _eventSubscriptions = {};

  /// Runs currently dispatched: run id to job name.
  ///
  /// The in-process view of what the store has leased to us. Keyed by run so a
  /// completion removes exactly its own entry; valued by job so the
  /// [TomJobDefinition.allowOverlap] check is a lookup rather than a scan.
  final Map<String, String> _inFlight = {};

  /// Coordination leases currently held, keyed by run id.
  ///
  /// Exposed through [heldLeases] so an operator can ask what this node is
  /// sitting on without going to the substrate.
  final Map<String, TomLease> _leases = {};

  /// Runs whose lease was lost mid-flight, and whose outcome this node must
  /// therefore not record. Cleared when the run finishes here.
  final Set<String> _lostLeases = {};

  Timer? _timer;
  bool _ticking = false;
  bool _closed = false;
  int _runCounter = 0;

  /// Creates a scheduler.
  ///
  /// [ownerId] defaults to a value derived from the process start time, which
  /// is enough to tell one scheduler's leases from another's in the store.
  /// **In a cluster it must be distinct per node**, and the default satisfies
  /// that only by luck — two nodes started in the same microsecond would
  /// collide. Set it explicitly to something stable and unique, such as the
  /// host name plus the process id.
  ///
  /// [leaseRenewInterval] defaults to a third of [leaseTtl], which leaves room
  /// for two renewals to fail before the lease lapses.
  TomScheduler({
    required this.store,
    required this.dispatcher,
    this.tickInterval = const Duration(seconds: 30),
    this.leaseTimeout = const Duration(minutes: 15),
    String? ownerId,
    DateTime Function()? clock,
    TomJobAlertSink? onAlert,
    Random? random,
    this.maxRunsPerTick = 16,
    this.lock,
    this.leaseTtl = const Duration(minutes: 1),
    Duration? leaseRenewInterval,
  })  : ownerId = ownerId ?? 'scheduler-${DateTime.now().microsecondsSinceEpoch}',
        clock = clock ?? DateTime.now,
        onAlert = onAlert ?? _logAlert,
        random = random ?? Random(),
        leaseRenewInterval = leaseRenewInterval ??
            Duration(microseconds: leaseTtl.inMicroseconds ~/ 3) {
    if (this.leaseRenewInterval >= leaseTtl) {
      throw TomScheduleException(
        'schedule.scheduler.renew_interval',
        'leaseRenewInterval must be shorter than leaseTtl, or a lease lapses '
            'before it is ever renewed.',
        parameters: {
          'leaseTtl': leaseTtl.toString(),
          'leaseRenewInterval': this.leaseRenewInterval.toString(),
        },
      );
    }
  }

  /// The default alert sink: everything goes to the framework log, with a
  /// severity that matches how bad the news is.
  static void _logAlert(TomJobAlert alert) {
    switch (alert.kind) {
      case TomJobAlertKind.runFailed:
      case TomJobAlertKind.runAbandoned:
      case TomJobAlertKind.leaseLost:
        tomLog.error(alert.describe());
      case TomJobAlertKind.attemptFailed:
      case TomJobAlertKind.timedOut:
      case TomJobAlertKind.windowsMissed:
      case TomJobAlertKind.leaseStolen:
        tomLog.warn(alert.describe());
      case TomJobAlertKind.lockContended:
        // Every node but the winner reports this on every run. At warn level a
        // healthy three-node cluster would generate two spurious warnings per
        // job per window, which is how operators learn to ignore warnings.
        tomLog.debug(alert.describe());
    }
  }

  /// The jobs currently registered, keyed by name.
  Map<String, TomJobDefinition> get jobs => Map.unmodifiable(_jobs);

  /// Whether the periodic timer is running.
  bool get isRunning => _timer != null;

  /// How many runs this scheduler currently has dispatched.
  int get inFlightCount => _inFlight.length;

  /// The coordination leases this node currently holds, keyed by run id.
  ///
  /// The local half of "who holds the lock": what *this* node believes it owns.
  /// For the cluster-wide answer, including leases held elsewhere, ask
  /// [TomLeaseLock.inspect] — which is authoritative, because a lease can lapse
  /// without the holder noticing until its next renewal.
  Map<String, TomLease> get heldLeases => Map.unmodifiable(_leases);

  /// Registers [job], replacing any previous definition of the same name.
  ///
  /// An [TomEventSchedule] job is subscribed immediately, so events that arrive
  /// before [start] are still enqueued — they are just not dispatched until a
  /// tick runs.
  void register(TomJobDefinition job) {
    _requireOpen();
    _jobs[job.name] = job;
    final schedule = job.schedule;
    if (schedule is TomEventSchedule) {
      _cancel(_eventSubscriptions.remove(job.name));
      _eventSubscriptions[job.name] = schedule.events.listen(
        (payload) => unawaited(_enqueueEvent(job, payload)),
        onError: (Object error, StackTrace stack) => onAlert(
          TomJobAlert(
            jobName: job.name,
            kind: TomJobAlertKind.runFailed,
            error: error,
            stackTrace: stack,
          ),
        ),
      );
    }
  }

  /// Removes [name] from the registry and cancels any event subscription.
  ///
  /// Runs already in the store are left alone: they were planned, and dropping
  /// them silently would make deregistration a way to lose work.
  void deregister(String name) {
    _jobs.remove(name);
    _cancel(_eventSubscriptions.remove(name));
  }

  /// Cancels [subscription] without waiting for it.
  ///
  /// Cancellation of a broadcast/controller subscription completes on a later
  /// microtask; nothing downstream depends on that completion, and making
  /// [register], [deregister] and [close] async just to await it would put an
  /// await point in the middle of registry mutation.
  static void _cancel(StreamSubscription<Object?>? subscription) {
    if (subscription != null) unawaited(subscription.cancel());
  }

  /// Runs one [tick] immediately, then repeats every [tickInterval].
  ///
  /// The immediate pass matters on restart: it is what recovers abandoned
  /// leases and catches up missed windows without waiting out a full interval.
  Future<void> start() async {
    _requireOpen();
    if (_timer != null) return;
    _timer = Timer.periodic(tickInterval, (_) => unawaited(tick()));
    await tick();
  }

  /// Stops the periodic timer. In-flight runs are left to finish.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Stops the scheduler, cancels event subscriptions and closes the
  /// dispatcher.
  ///
  /// Runs already dispatched are not waited for — [close] is the shutdown path,
  /// and their leases will expire so another process picks them up.
  ///
  /// Held leases are released on the way out so peers can take the work
  /// immediately instead of waiting out [leaseTtl]. That release is
  /// fire-and-forget: [TomClosable.close] is synchronous, and a lease that fails
  /// to release simply expires, which is the behaviour a hard kill would have
  /// produced anyway.
  @override
  void close() {
    _closed = true;
    stop();
    for (final subscription in _eventSubscriptions.values) {
      _cancel(subscription);
    }
    _eventSubscriptions.clear();
    final coordinator = lock;
    if (coordinator != null) {
      for (final lease in _leases.values) {
        unawaited(coordinator.release(lease));
      }
    }
    _leases.clear();
    _lostLeases.clear();
    dispatcher.close();
  }

  // ===========================================================================
  // THE PASS
  // ===========================================================================

  /// Runs one complete scheduling pass.
  ///
  /// Safe to call directly — this is the unit tests drive. Overlapping calls
  /// are collapsed: a pass still running when the timer fires again is not
  /// re-entered, because two concurrent planners would both see the same window
  /// as unplanned.
  Future<void> tick() async {
    if (_closed || _ticking) return;
    _ticking = true;
    try {
      final now = clock();
      await _recoverAbandoned(now);
      for (final job in List.of(_jobs.values)) {
        if (!job.schedule.isClockDriven) continue;
        await _planWindows(job, now);
      }
      await _dispatchDue(now);
    } finally {
      _ticking = false;
    }
  }

  /// Returns expired leases to the queue and alerts on each.
  Future<void> _recoverAbandoned(DateTime now) async {
    final recovered = await store.recoverAbandoned(now, leaseTimeout);
    for (final run in recovered) {
      _inFlight.remove(run.id);
      _leases.remove(run.id);
      onAlert(
        TomJobAlert(
          jobName: run.jobName,
          kind: TomJobAlertKind.runAbandoned,
          run: run,
        ),
      );
    }
  }

  // ===========================================================================
  // PLANNING
  // ===========================================================================

  /// Enqueues whatever [job] owes: missed windows per its policy, plus the next
  /// future window.
  ///
  /// The two halves are anchored differently on purpose. Catch-up is anchored
  /// on the last window *on record*, because that is what defines "missed".
  /// Look-ahead is anchored on **now**, not on the record — anchoring it on the
  /// record too would enqueue one window further into the future on every tick,
  /// walking the plan forward forever.
  Future<void> _planWindows(TomJobDefinition job, DateTime now) async {
    final last = await store.lastWindow(job.name);

    if (last == null) {
      // First sight of this job. Anchor on the present: treating all of history
      // as missed would make registering a long-standing daily job replay every
      // day since the epoch.
      final first = job.schedule.nextFireAfter(now);
      if (first != null) await _enqueueWindow(job, first, first);
      return;
    }

    if (job.missedWindowPolicy != TomMissedWindowPolicy.skip) {
      await _enqueueMissed(job, last, now);
    } else {
      final missed = _countMissed(job, last, now);
      if (missed > 0) {
        onAlert(
          TomJobAlert(
            jobName: job.name,
            kind: TomJobAlertKind.windowsMissed,
            missedWindows: missed,
          ),
        );
      }
    }

    final upcoming = job.schedule.nextFireAfter(now);
    if (upcoming != null) await _enqueueWindow(job, upcoming, upcoming);
  }

  /// Enqueues the missed windows [job]'s policy asks for, dating each run to
  /// the window it belongs to but making it due immediately.
  Future<void> _enqueueMissed(
    TomJobDefinition job,
    DateTime last,
    DateTime now,
  ) async {
    final wanted = job.missedWindowPolicy == TomMissedWindowPolicy.runOnce
        ? 1
        : job.catchUpLimit;

    // Keep only the most recent `wanted` windows. Scanning forward and keeping
    // a bounded tail costs nothing and avoids materialising an outage's worth
    // of dates just to throw all but the last away.
    final recent = <DateTime>[];
    var scanned = 0;
    var cursor = last;
    var window = job.schedule.nextFireAfter(cursor);
    while (window != null && !window.isAfter(now)) {
      recent.add(window);
      if (recent.length > wanted) recent.removeAt(0);
      cursor = window;
      if (++scanned >= maxCatchUpScan) {
        tomLog.warn(
          'TomScheduler: catch-up scan for "${job.name}" hit the '
          '$maxCatchUpScan window limit; older windows are not replayed.',
        );
        break;
      }
      window = job.schedule.nextFireAfter(cursor);
    }

    if (scanned > recent.length) {
      onAlert(
        TomJobAlert(
          jobName: job.name,
          kind: TomJobAlertKind.windowsMissed,
          missedWindows: scanned - recent.length,
        ),
      );
    }
    for (final missed in recent) {
      // Due now, dated then: the run is late, and says so.
      await _enqueueWindow(job, missed, now);
    }
  }

  /// How many windows elapsed between [last] and [now] — used only to report
  /// what a `skip` policy is dropping.
  int _countMissed(TomJobDefinition job, DateTime last, DateTime now) {
    var count = 0;
    var cursor = last;
    var window = job.schedule.nextFireAfter(cursor);
    while (window != null && !window.isAfter(now) && count < maxCatchUpScan) {
      count++;
      cursor = window;
      window = job.schedule.nextFireAfter(cursor);
    }
    return count;
  }

  /// Adds a run for [scheduledFor] unless one already exists.
  ///
  /// The existence check is the idempotence guarantee that makes a tick safe to
  /// replay after a crash.
  Future<void> _enqueueWindow(
    TomJobDefinition job,
    DateTime scheduledFor,
    DateTime runAt,
  ) async {
    if (await store.findWindow(job.name, scheduledFor) != null) return;
    await store.enqueue(
      TomJobRun(
        id: _nextRunId(job.name),
        jobName: job.name,
        scheduledFor: scheduledFor,
        runAt: runAt,
      ),
    );
  }

  /// Enqueues a run for an event-triggered job, carrying [payload].
  ///
  /// Each event gets its own window keyed by arrival time, so two events in the
  /// same instant collapse into one run and a rapid source cannot flood the
  /// queue with duplicates of the same moment.
  Future<void> _enqueueEvent(TomJobDefinition job, Object? payload) async {
    if (_closed) return;
    final now = clock();
    if (await store.findWindow(job.name, now) != null) return;
    await store.enqueue(
      TomJobRun(
        id: _nextRunId(job.name),
        jobName: job.name,
        scheduledFor: now,
        runAt: now,
        payload: payload,
      ),
    );
  }

  String _nextRunId(String jobName) =>
      '$jobName:${clock().microsecondsSinceEpoch}:${_runCounter++}';

  // ===========================================================================
  // DISPATCH
  // ===========================================================================

  /// Claims every due run this scheduler is willing to take, and starts it.
  Future<void> _dispatchDue(DateTime now) async {
    final busy = _inFlight.values.toSet();
    final claimed = await store.claimDue(
      now,
      ownerId,
      limit: maxRunsPerTick,
      accept: (run) {
        final job = _jobs[run.jobName];
        // A run whose definition is not registered here belongs to some other
        // scheduler (or an older build); leave it for whoever owns it rather
        // than claiming work we cannot execute.
        if (job == null) return false;
        if (job.allowOverlap) return true;
        // `busy` grows *during* the claim, not after it. Two due windows of a
        // non-overlapping job arrive in the same pass — a catch-up run and the
        // window it was late for, say — and a predicate that only consulted the
        // set as it stood before the claim would accept both.
        return busy.add(run.jobName);
      },
    );
    for (final run in claimed) {
      final job = _jobs[run.jobName];
      if (job == null) continue;
      // The claim is a *local* reservation; the lease is the cluster arbiter.
      // A node that claimed but cannot win the lease hands the claim straight
      // back, so a peer can take it on its own next tick instead of waiting for
      // this one's lease to time out.
      final lease = await _acquireLease(job, run);
      if (lease == null && lock != null) {
        await store.release(run);
        continue;
      }
      _inFlight[run.id] = run.jobName;
      // Not awaited: a tick starts runs, it does not wait them out. A slow job
      // must not hold up the next window of a fast one.
      unawaited(_runOne(job, run, lease));
    }
  }

  /// The resource a run's coordination lease is taken on.
  ///
  /// The key *is* the policy. A job that forbids overlap leases its own name,
  /// so the whole cluster runs at most one of it at a time — the cluster-wide
  /// reading of [TomJobDefinition.allowOverlap]. A job that allows overlap
  /// leases the individual run, so concurrent windows are fine but no single
  /// window is executed twice.
  String _leaseResource(TomJobDefinition job, TomJobRun run) =>
      job.allowOverlap ? 'run:${run.id}' : 'job:${job.name}';

  /// Wins the coordination lease for [run], or reports why it could not.
  ///
  /// Returns `null` both when there is no lock (the single-node case, where the
  /// caller proceeds anyway) and when a peer holds the lease; the caller
  /// distinguishes them by whether [lock] is set.
  Future<TomLease?> _acquireLease(
    TomJobDefinition job,
    TomJobRun run,
  ) async {
    final coordinator = lock;
    if (coordinator == null) return null;
    final resource = _leaseResource(job, run);

    // Read before taking, so a takeover can name the holder it displaced. This
    // is the observability half of DO 4 and is why "the node that died" is
    // answerable rather than merely inferable.
    final before = await coordinator.inspect(resource);
    final lease = await coordinator.acquire(resource, ownerId, leaseTtl);

    if (lease == null) {
      onAlert(
        TomJobAlert(
          jobName: job.name,
          kind: TomJobAlertKind.lockContended,
          run: run,
          lease: before.lease,
        ),
      );
      return null;
    }
    if (before.holderVanished && before.lease!.owner != ownerId) {
      onAlert(
        TomJobAlert(
          jobName: job.name,
          kind: TomJobAlertKind.leaseStolen,
          run: run,
          lease: before.lease,
        ),
      );
    }
    _leases[run.id] = lease;
    return lease;
  }

  /// Executes one attempt of [run] and records the outcome.
  ///
  /// [lease] is the coordination lease held for this run, or `null` when the
  /// scheduler is running single-node.
  Future<void> _runOne(
    TomJobDefinition job,
    TomJobRun run,
    TomLease? lease,
  ) async {
    final heartbeat = _startHeartbeat(job, run, lease);
    try {
      final TomCommand command;
      try {
        command = job.body(run);
      } catch (error, stack) {
        // A body factory that throws is a permanent defect, not a transient
        // failure — retrying it just fails identically. Fail the run outright.
        if (_stillOurs(run)) await _failFinally(job, run, error, stack);
        return;
      }
      await dispatcher.dispatch(command).timeout(job.timeout);
      if (_stillOurs(run)) await store.complete(run, clock());
    } on TimeoutException catch (error, stack) {
      onAlert(
        TomJobAlert(
          jobName: job.name,
          kind: TomJobAlertKind.timedOut,
          run: run,
          error: error,
        ),
      );
      if (_stillOurs(run)) await _failAttempt(job, run, error, stack);
    } catch (error, stack) {
      if (_stillOurs(run)) await _failAttempt(job, run, error, stack);
    } finally {
      heartbeat?.cancel();
      _inFlight.remove(run.id);
      await _releaseLease(job, run);
      _lostLeases.remove(run.id);
    }
  }

  /// Whether this node may still write [run]'s outcome to the store.
  ///
  /// Once a lease is lost the run belongs to whichever node took it over.
  /// Writing our result anyway would clobber theirs — marking succeeded a run
  /// they are still executing, or failing one they already completed. Our work
  /// is not wasted, it is simply no longer authoritative, and the discrepancy
  /// is reported as [TomJobAlertKind.leaseLost] rather than hidden.
  bool _stillOurs(TomJobRun run) =>
      lock == null || !_lostLeases.contains(run.id);

  /// Starts the renewal timer that keeps [lease] alive while the work runs.
  ///
  /// Renewal is what decouples the lease TTL from job duration: without it the
  /// TTL would have to exceed the slowest possible run, and a dead node would
  /// then block its work for exactly that long.
  Timer? _startHeartbeat(
    TomJobDefinition job,
    TomJobRun run,
    TomLease? lease,
  ) {
    if (lock == null || lease == null) return null;
    return Timer.periodic(
      leaseRenewInterval,
      (_) => unawaited(_renewLease(job, run)),
    );
  }

  /// One heartbeat: push the lease expiry forward and refresh the store claim.
  Future<void> _renewLease(TomJobDefinition job, TomJobRun run) async {
    final coordinator = lock;
    final current = _leases[run.id];
    if (coordinator == null || current == null) return;

    final renewed = await coordinator.renew(current, leaseTtl);
    if (renewed == null) {
      _leases.remove(run.id);
      _lostLeases.add(run.id);
      onAlert(
        TomJobAlert(
          jobName: job.name,
          kind: TomJobAlertKind.leaseLost,
          run: run,
          lease: current,
        ),
      );
      return;
    }
    _leases[run.id] = renewed;
    // The store lease moves with the lock lease, so `recoverAbandoned` and the
    // coordinator agree about who is alive rather than expiring independently.
    await store.renewClaim(run, clock());
  }

  /// Gives up the lease held for [run], if any.
  Future<void> _releaseLease(TomJobDefinition job, TomJobRun run) async {
    final lease = _leases.remove(run.id);
    final coordinator = lock;
    if (lease == null || coordinator == null) return;
    await coordinator.release(lease);
    // A run-scoped resource is named after an id that is never reused, so its
    // record is dead weight the moment the run ends. A job-scoped one must be
    // kept: forgetting it would restart that job's fencing tokens at 1.
    if (job.allowOverlap) await coordinator.forget(lease.resource);
  }

  /// Fails one attempt, scheduling a retry when the policy allows one.
  ///
  /// Two things can cut the retry budget short: exhausting it, and an error the
  /// body classified as [TomPermanentFailure]. The second is checked first
  /// because it is the stronger statement — "no attempt will ever succeed"
  /// makes "you have two attempts left" irrelevant.
  Future<void> _failAttempt(
    TomJobDefinition job,
    TomJobRun run,
    Object error,
    StackTrace stack,
  ) async {
    final now = clock();
    if (error is TomPermanentFailure ||
        !job.retryPolicy.allowsRetryAfter(run.attempt)) {
      await _failFinally(job, run, error, stack);
      return;
    }
    final retryAt =
        now.add(job.retryPolicy.backoffFor(run.attempt, random));
    await store.fail(run, error.toString(), now, retryAt: retryAt);
    onAlert(
      TomJobAlert(
        jobName: job.name,
        kind: TomJobAlertKind.attemptFailed,
        run: run,
        error: error,
        stackTrace: stack,
        retryAt: retryAt,
      ),
    );
  }

  /// Marks [run] terminally failed and alerts.
  Future<void> _failFinally(
    TomJobDefinition job,
    TomJobRun run,
    Object error,
    StackTrace stack,
  ) async {
    await store.fail(run, error.toString(), clock());
    onAlert(
      TomJobAlert(
        jobName: job.name,
        kind: TomJobAlertKind.runFailed,
        run: run,
        error: error,
        stackTrace: stack,
      ),
    );
  }

  void _requireOpen() {
    if (!_closed) return;
    throw TomScheduleException(
      'schedule.scheduler.closed',
      'This TomScheduler has been closed and cannot be reused.',
    );
  }
}
