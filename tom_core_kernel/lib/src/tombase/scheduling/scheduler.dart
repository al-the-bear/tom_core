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
/// It does not coordinate across machines. [TomJobDefinition.allowOverlap]
/// serialises a job's runs within *this* scheduler; two schedulers pointed at
/// the same store will both claim, because nothing here arbitrates between
/// them. Cluster-wide single-fire is a separate problem with its own failure
/// modes — clock skew, lease expiry versus job duration, the node that dies
/// holding the lock — and is deliberately not solved here.
library;

import 'dart:async';
import 'dart:math';

import 'package:tom_basics/tom_basics.dart';

import '../isolate_pooling/tom_worker.dart';
import '../shutdown_cleanup/tom_shutdown_cleanup.dart';
import 'job_definition.dart';
import 'job_store.dart';
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

  final Map<String, TomJobDefinition> _jobs = {};
  final Map<String, StreamSubscription<Object?>> _eventSubscriptions = {};

  /// Runs currently dispatched: run id to job name.
  ///
  /// The in-process view of what the store has leased to us. Keyed by run so a
  /// completion removes exactly its own entry; valued by job so the
  /// [TomJobDefinition.allowOverlap] check is a lookup rather than a scan.
  final Map<String, String> _inFlight = {};

  Timer? _timer;
  bool _ticking = false;
  bool _closed = false;
  int _runCounter = 0;

  /// Creates a scheduler.
  ///
  /// [ownerId] defaults to a value derived from the process start time, which
  /// is enough to tell one scheduler's leases from another's in the store.
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
  })  : ownerId = ownerId ?? 'scheduler-${DateTime.now().microsecondsSinceEpoch}',
        clock = clock ?? DateTime.now,
        onAlert = onAlert ?? _logAlert,
        random = random ?? Random();

  /// The default alert sink: everything goes to the framework log, with a
  /// severity that matches how bad the news is.
  static void _logAlert(TomJobAlert alert) {
    switch (alert.kind) {
      case TomJobAlertKind.runFailed:
      case TomJobAlertKind.runAbandoned:
        tomLog.error(alert.describe());
      case TomJobAlertKind.attemptFailed:
      case TomJobAlertKind.timedOut:
      case TomJobAlertKind.windowsMissed:
        tomLog.warn(alert.describe());
    }
  }

  /// The jobs currently registered, keyed by name.
  Map<String, TomJobDefinition> get jobs => Map.unmodifiable(_jobs);

  /// Whether the periodic timer is running.
  bool get isRunning => _timer != null;

  /// How many runs this scheduler currently has dispatched.
  int get inFlightCount => _inFlight.length;

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
  @override
  void close() {
    _closed = true;
    stop();
    for (final subscription in _eventSubscriptions.values) {
      _cancel(subscription);
    }
    _eventSubscriptions.clear();
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
      _inFlight[run.id] = run.jobName;
      // Not awaited: a tick starts runs, it does not wait them out. A slow job
      // must not hold up the next window of a fast one.
      unawaited(_runOne(job, run));
    }
  }

  /// Executes one attempt of [run] and records the outcome.
  Future<void> _runOne(TomJobDefinition job, TomJobRun run) async {
    try {
      final TomCommand command;
      try {
        command = job.body(run);
      } catch (error, stack) {
        // A body factory that throws is a permanent defect, not a transient
        // failure — retrying it just fails identically. Fail the run outright.
        await _failFinally(job, run, error, stack);
        return;
      }
      await dispatcher.dispatch(command).timeout(job.timeout);
      await store.complete(run, clock());
    } on TimeoutException catch (error, stack) {
      onAlert(
        TomJobAlert(
          jobName: job.name,
          kind: TomJobAlertKind.timedOut,
          run: run,
          error: error,
        ),
      );
      await _failAttempt(job, run, error, stack);
    } catch (error, stack) {
      await _failAttempt(job, run, error, stack);
    } finally {
      _inFlight.remove(run.id);
    }
  }

  /// Fails one attempt, scheduling a retry when the policy allows one.
  Future<void> _failAttempt(
    TomJobDefinition job,
    TomJobRun run,
    Object error,
    StackTrace stack,
  ) async {
    final now = clock();
    if (!job.retryPolicy.allowsRetryAfter(run.attempt)) {
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
