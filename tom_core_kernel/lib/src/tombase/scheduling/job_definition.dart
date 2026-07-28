/// The *what* half of a background job: its work body and its operational
/// policy — retry, backoff, timeout, overlap and failure alerting.
///
/// CE-JB declares all four of retry, backoff, timeout and alerting as part of a
/// job's definition. They live here, on the definition, rather than inside the
/// job body for one reason: a policy the body implements is a policy every body
/// implements differently, and the moment two jobs disagree about what "retry
/// three times" means, the declaration in the spec has stopped describing the
/// system. The runtime honours these; the body does the work.
///
/// ## The dispatcher seam
///
/// A job's work body is a [TomCommand] — the same unit the kernel's isolate
/// pool already runs. The scheduler never executes one itself; it hands it to a
/// [TomJobDispatcher]. That seam is what keeps the promise not to build a
/// second execution engine: [TomWorkerPoolJobDispatcher] is a thin adapter over
/// [TomWorkerPool], and the only other implementation,
/// [TomInlineJobDispatcher], exists so tests and single-threaded deployments do
/// not have to spawn isolates to exercise scheduling logic.
library;

import 'dart:async';
import 'dart:math';

import '../isolate_pooling/tom_worker.dart';
import 'job_store.dart';
import 'lease_lock.dart';
import 'schedule.dart';

// =============================================================================
// MISSED WINDOW POLICY
// =============================================================================

/// What a job does about windows that elapsed while the scheduler was down.
///
/// This has to be *stated*, because every possible behaviour is wrong for some
/// job and there is no default that is merely technical. A nightly report that
/// missed three nights probably wants one catch-up run, not three; a billing
/// job that missed three days probably wants all three; a cache warm-up that
/// missed three days wants none of them.
enum TomMissedWindowPolicy {
  /// Ignore every missed window; resume at the next future one.
  ///
  /// Right for work whose value is entirely in being current — cache warming,
  /// health probes, anything where a late run does the same thing as the next
  /// on-time run and merely costs more.
  skip,

  /// Run the most recent missed window once, and ignore the rest.
  ///
  /// The default, because it preserves the property most schedules are actually
  /// asserting — "this ran today" — without replaying an outage's worth of
  /// windows. The run carries the missed window in
  /// [TomJobRun.scheduledFor], so a body that cares can see it was late.
  runOnce,

  /// Run every missed window, most recent first, up to
  /// [TomJobDefinition.catchUpLimit].
  ///
  /// Right when each window has its own work — a per-period aggregation where
  /// skipping a window means that period is never processed. The limit is not
  /// optional: an unbounded catch-up after a long outage is a self-inflicted
  /// denial of service.
  runAll,
}

// =============================================================================
// RETRY POLICY
// =============================================================================

/// How a failed attempt is retried.
///
/// Backoff is exponential from [initialBackoff] by [multiplier], clamped to
/// [maxBackoff]. [jitter] spreads the retries of jobs that failed together —
/// without it, a downstream service that dropped every job at once gets them
/// all back simultaneously, which is how a brief outage becomes a long one.
class TomRetryPolicy {
  /// Total attempts including the first, so `1` means "no retry".
  final int maxAttempts;

  /// The delay before the second attempt.
  final Duration initialBackoff;

  /// The factor each successive backoff is multiplied by.
  final double multiplier;

  /// The ceiling backoff never exceeds.
  final Duration maxBackoff;

  /// The fraction of the computed backoff that may be added at random, `0`-`1`.
  ///
  /// Applied additively upward only, so jitter never makes a retry earlier than
  /// the backoff the policy promised.
  final double jitter;

  /// Creates a retry policy.
  const TomRetryPolicy({
    this.maxAttempts = 3,
    this.initialBackoff = const Duration(seconds: 30),
    this.multiplier = 2.0,
    this.maxBackoff = const Duration(minutes: 30),
    this.jitter = 0.1,
  });

  /// A policy that never retries: one attempt, and a failure is final.
  static const TomRetryPolicy none = TomRetryPolicy(maxAttempts: 1);

  /// Whether an attempt numbered [attempt] may be followed by another.
  bool allowsRetryAfter(int attempt) => attempt < maxAttempts;

  /// The delay before the attempt following [attempt] (1-based).
  ///
  /// [random] is supplied by the scheduler so jitter is reproducible in tests;
  /// omitting it yields the exact, unjittered backoff.
  Duration backoffFor(int attempt, [Random? random]) {
    final steps = (attempt - 1).clamp(0, 30);
    final scaled = initialBackoff.inMicroseconds * pow(multiplier, steps);
    var micros = scaled.isFinite
        ? scaled.round().clamp(0, maxBackoff.inMicroseconds)
        : maxBackoff.inMicroseconds;
    if (random != null && jitter > 0) {
      micros += (micros * jitter * random.nextDouble()).round();
    }
    return Duration(microseconds: micros);
  }

  @override
  String toString() => 'TomRetryPolicy(maxAttempts: $maxAttempts, '
      'initialBackoff: $initialBackoff, multiplier: $multiplier)';
}

// =============================================================================
// PERMANENT FAILURE
// =============================================================================

/// Marks an error as one that retrying cannot fix.
///
/// A [TomRetryPolicy] answers "how many times", but some failures should not be
/// attempted a second time at all: a malformed address, a rejected credential,
/// a request the far side answered with "never". Retrying those burns the whole
/// budget on an outcome that was decided at the first attempt, and — worse —
/// delays the *report* of a failure the caller could have acted on immediately.
///
/// The scheduler already draws this line once: a body factory that throws is
/// failed outright rather than retried, because it would throw identically next
/// time. This mixin extends the same judgement to the body itself, which is the
/// only party that can tell a refusal from an outage.
///
/// Mix it into an existing exception to classify it, or throw
/// [TomPermanentJobFailure] when there is no type to reuse:
///
/// ```dart
/// class MailRejected extends TomException with TomPermanentFailure { … }
/// ```
///
/// The default remains *transient*. An unrecognised error is retried, because
/// retrying a permanent failure costs a few wasted attempts whereas dropping a
/// transient one loses the work.
mixin TomPermanentFailure {}

/// A ready-made [TomPermanentFailure] for bodies with no exception type of
/// their own.
class TomPermanentJobFailure implements Exception, TomPermanentFailure {
  /// Why the work can never succeed.
  final String message;

  /// The error this conclusion was drawn from, when there was one.
  final Object? cause;

  /// Creates a permanent failure.
  const TomPermanentJobFailure(this.message, {this.cause});

  @override
  String toString() => cause == null
      ? 'TomPermanentJobFailure: $message'
      : 'TomPermanentJobFailure: $message ($cause)';
}

// =============================================================================
// ALERTING
// =============================================================================

/// Why a [TomJobAlert] was raised.
enum TomJobAlertKind {
  /// An attempt failed and another will follow.
  attemptFailed,

  /// An attempt exceeded [TomJobDefinition.timeout].
  timedOut,

  /// Every attempt is spent; the run is terminally failed.
  runFailed,

  /// A run whose lease expired was returned to the queue — the scheduler that
  /// held it died, or wedged for longer than the lease.
  runAbandoned,

  /// A schedule produced windows that were skipped by its missed-window policy.
  windowsMissed,

  /// A cluster peer held the coordination lease, so this node did not run the
  /// work.
  ///
  /// Routine in a healthy cluster — exactly one node wins each run and the rest
  /// report this — so the default sink logs it at debug level. It earns its
  /// place as an alert because a job that *never* runs anywhere looks identical
  /// to a job nobody scheduled until you can see that every node is conceding.
  lockContended,

  /// This node took over a lease whose holder had let it expire.
  ///
  /// The cluster-visible answer to "what happened to a run whose holder
  /// vanished": the run was picked up here, and the previous holder is named in
  /// [TomJobAlert.lease].
  leaseStolen,

  /// A lease could not be renewed while its work was still running.
  ///
  /// The serious one. This node no longer owns the run, another node may
  /// already be executing it, and the work in flight here cannot be recalled.
  /// See `doc/scheduling/scheduling.md` — this is the window in which the
  /// at-least-once guarantee becomes visible.
  leaseLost,
}

/// A failure worth telling somebody about.
class TomJobAlert {
  /// Which job the alert concerns.
  final String jobName;

  /// Why the alert was raised.
  final TomJobAlertKind kind;

  /// The run involved, when the alert concerns one.
  final TomJobRun? run;

  /// The error, for the failure kinds.
  final Object? error;

  /// The stack trace, when one was captured.
  final StackTrace? stackTrace;

  /// When another attempt will be made, for [TomJobAlertKind.attemptFailed].
  final DateTime? retryAt;

  /// How many windows were dropped, for [TomJobAlertKind.windowsMissed].
  final int missedWindows;

  /// The lease involved, for the coordination kinds.
  ///
  /// For [TomJobAlertKind.leaseStolen] this is the lease *taken over*, so it
  /// names the holder that vanished. For [TomJobAlertKind.leaseLost] it is the
  /// lease this node held and could no longer renew. For
  /// [TomJobAlertKind.lockContended] it is the peer's lease when the lock could
  /// report one.
  final TomLease? lease;

  /// Creates an alert.
  const TomJobAlert({
    required this.jobName,
    required this.kind,
    this.run,
    this.error,
    this.stackTrace,
    this.retryAt,
    this.missedWindows = 0,
    this.lease,
  });

  /// A one-line description suitable for a log line or a notification body.
  String describe() => switch (kind) {
        TomJobAlertKind.attemptFailed =>
          'Job "$jobName" attempt ${run?.attempt} failed ($error); '
              'retrying at ${retryAt?.toIso8601String()}.',
        TomJobAlertKind.timedOut =>
          'Job "$jobName" attempt ${run?.attempt} exceeded its timeout.',
        TomJobAlertKind.runFailed =>
          'Job "$jobName" failed permanently after ${run?.attempt} '
              'attempt(s): $error',
        TomJobAlertKind.runAbandoned =>
          'Job "$jobName" run ${run?.id} was abandoned by its holder and '
              'returned to the queue.',
        TomJobAlertKind.windowsMissed =>
          'Job "$jobName" skipped $missedWindows missed window(s).',
        TomJobAlertKind.lockContended =>
          'Job "$jobName" run ${run?.id} is held by another node'
              '${lease == null ? '' : ' (${lease!.owner})'}; conceding.',
        TomJobAlertKind.leaseStolen =>
          'Job "$jobName" run ${run?.id} taken over from a lapsed holder'
              '${lease == null ? '' : ' (was ${lease!.owner})'}.',
        TomJobAlertKind.leaseLost =>
          'Job "$jobName" run ${run?.id} lost its lease while running '
              '(token ${lease?.token}); another node may now be executing it.',
      };

  @override
  String toString() => describe();
}

/// Where alerts are delivered.
///
/// A plain function so a deployment can route alerts anywhere — a log, a
/// notification service, a metrics counter — without the scheduler knowing
/// about any of them.
typedef TomJobAlertSink = void Function(TomJobAlert alert);

// =============================================================================
// DISPATCHER
// =============================================================================

/// Where a job's work body is actually run.
///
/// The scheduler owns *when* work runs; a dispatcher owns *where*. Keeping them
/// apart is what lets the scheduler be tested against wall-clock-free fakes
/// while production runs the identical logic over the isolate pool.
abstract class TomJobDispatcher {
  /// Creates a dispatcher.
  const TomJobDispatcher();

  /// Runs [command] and completes with its result.
  ///
  /// Errors propagate: the scheduler turns them into retries and alerts, so a
  /// dispatcher must not swallow them.
  Future<Object?> dispatch(TomCommand command);

  /// Releases whatever the dispatcher owns. Does not close resources it was
  /// merely handed — a pool passed in from outside outlives the dispatcher.
  void close() {}
}

/// Runs job bodies on an existing [TomWorkerPool].
///
/// This is the production dispatcher, and it is deliberately trivial: the pool
/// already does worker liveness, replacement and back-pressure, so the adapter
/// adds nothing but the call. Anything more here would be the second execution
/// engine this design exists to avoid.
class TomWorkerPoolJobDispatcher extends TomJobDispatcher {
  /// The pool job bodies are executed on.
  final TomWorkerPool pool;

  /// Whether [close] should also close [pool].
  ///
  /// Defaults to `false`: a pool shared with the rest of the application must
  /// not be torn down because the scheduler stopped.
  final bool ownsPool;

  /// Wraps [pool] as a dispatcher.
  const TomWorkerPoolJobDispatcher(this.pool, {this.ownsPool = false});

  @override
  Future<Object?> dispatch(TomCommand command) => pool.execute(command);

  @override
  void close() {
    if (ownsPool) pool.close();
  }
}

/// Runs job bodies in the calling isolate.
///
/// For tests, and for deployments whose jobs are light enough that an isolate
/// hop costs more than the work. Note that a long body will block the event
/// loop — including the scheduler's own tick timer — which is precisely why the
/// pool-backed dispatcher is the default choice in production.
class TomInlineJobDispatcher extends TomJobDispatcher {
  /// Creates an inline dispatcher.
  const TomInlineJobDispatcher();

  @override
  Future<Object?> dispatch(TomCommand command) => command.execute();
}

// =============================================================================
// JOB DEFINITION
// =============================================================================

/// A registered job: a trigger, a work body, and the policy around both.
class TomJobDefinition {
  /// The job's identity. Used as the store key, so it must be stable across
  /// restarts — a renamed job loses its history and re-anchors as if new.
  final String name;

  /// When the job fires.
  final TomSchedule schedule;

  /// Produces the work body for one run.
  ///
  /// A **factory**, not a single instance, for two reasons: a command may carry
  /// per-run state, and a command dispatched to an isolate is copied, so
  /// reusing one instance across runs invites the illusion that mutations to it
  /// are visible back on the scheduler side.
  ///
  /// The run is passed in so a body can read its window
  /// ([TomJobRun.scheduledFor]), its attempt number, or an event payload.
  final TomCommand Function(TomJobRun run) body;

  /// How failed attempts are retried.
  final TomRetryPolicy retryPolicy;

  /// How long one attempt may take before it is treated as failed.
  ///
  /// A timed-out attempt is failed and retried per [retryPolicy]. The work
  /// itself is **not** cancelled — an isolate command cannot be interrupted
  /// from outside, and killing the worker would take unrelated work with it.
  /// Worker liveness stays the pool's concern; a body that can overrun must be
  /// written to tolerate a later attempt overlapping it, or must set
  /// [allowOverlap] to `false` (the default) so the scheduler holds the next
  /// window back.
  final Duration timeout;

  /// What to do about windows missed while the scheduler was down.
  final TomMissedWindowPolicy missedWindowPolicy;

  /// The most windows [TomMissedWindowPolicy.runAll] will replay.
  final int catchUpLimit;

  /// Whether a new run may start while a previous one is still in flight.
  ///
  /// `false` by default, which is the safe reading for the common case of a job
  /// that reads and rewrites the same rows. This is *single-node* serialisation
  /// only — it holds within one scheduler, not across a cluster.
  final bool allowOverlap;

  /// Creates a job definition.
  TomJobDefinition({
    required this.name,
    required this.schedule,
    required this.body,
    this.retryPolicy = const TomRetryPolicy(),
    this.timeout = const Duration(minutes: 5),
    this.missedWindowPolicy = TomMissedWindowPolicy.runOnce,
    this.catchUpLimit = 10,
    this.allowOverlap = false,
  }) {
    if (name.trim().isEmpty) {
      throw TomScheduleException(
        'schedule.job.unnamed',
        'A job definition needs a non-empty name.',
      );
    }
    if (catchUpLimit < 1) {
      throw TomScheduleException(
        'schedule.job.catch_up_limit',
        'catchUpLimit must be at least 1; got $catchUpLimit.',
        parameters: {'job': name, 'catchUpLimit': catchUpLimit},
      );
    }
    if (timeout <= Duration.zero) {
      throw TomScheduleException(
        'schedule.job.timeout',
        'A job timeout must be positive; got $timeout.',
        parameters: {'job': name},
      );
    }
  }

  @override
  String toString() => 'TomJobDefinition($name, ${schedule.describe()})';
}
