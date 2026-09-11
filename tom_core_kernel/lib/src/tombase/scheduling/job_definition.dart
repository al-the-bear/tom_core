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
/// Backoff is exponential from [initialBackoff] by [multiplier], and never
/// exceeds [maxBackoff] — jitter included. [jitter] spreads the retries of jobs
/// that failed together — without it, a downstream service that dropped every
/// job at once gets them all back simultaneously, which is how a brief outage
/// becomes a long one.
///
/// That pile-up is worst once every job has saturated at the ceiling, which is
/// what a long outage produces, so the curve plateaus a jitter's width below
/// [maxBackoff] rather than clamping the jittered value. See [backoffFor].
///
/// The fields have ranges — `maxAttempts >= 1`, `multiplier >= 1`,
/// `jitter` in `0..1`, a non-negative [initialBackoff] and a positive
/// [maxBackoff] — enforced by [validate] rather than by the constructor, which
/// must stay `const` for annotation use.
class TomRetryPolicy {
  /// Total attempts including the first, so `1` means "no retry".
  ///
  /// At least 1. `0` is rejected rather than read as "unlimited": it would
  /// behave as [none], since [allowsRetryAfter] asks whether the attempt number
  /// is below this and no attempt is below zero.
  final int maxAttempts;

  /// The delay before the second attempt.
  ///
  /// May be zero, which retries at once. Never negative.
  final Duration initialBackoff;

  /// The factor each successive backoff is multiplied by.
  ///
  /// At least 1. Below 1 the "backoff" would shrink on every failure — 10 s,
  /// 5 s, 2.5 s — which is the pathology exponential backoff exists to prevent.
  /// Exactly 1 is allowed and means a constant delay between attempts.
  final double multiplier;

  /// The ceiling backoff never exceeds, [jitter] included.
  ///
  /// Positive, where [initialBackoff] need only be non-negative: retrying at
  /// once is a real choice, but a zero ceiling clamps every backoff to nothing
  /// and turns [maxAttempts] into a tight spin against whatever just failed.
  ///
  /// Because jitter is added on top, the exponential curve plateaus at
  /// `maxBackoff / (1 + jitter)` — with the defaults, 27 min 16 s under the
  /// 30 min ceiling — and jitter fills the gap.
  final Duration maxBackoff;

  /// The fraction of the computed backoff that may be added at random, `0`-`1`.
  ///
  /// Applied additively upward only, so jitter never makes a retry earlier than
  /// the backoff the policy promised, and never later than [maxBackoff], whose
  /// plateau reserves the room it needs. `0` disables jitter; a negative value
  /// is rejected rather than read as "off", since it would silently mean that.
  final double jitter;

  /// Creates a retry policy.
  ///
  /// The arguments are **not** checked here. This constructor has to stay
  /// `const` — `@TomScheduledJob(retry: TomRetryPolicy(…))` is an annotation
  /// argument, and Dart requires those to be compile-time constants — and a
  /// `const` constructor has no body to throw from. The checks therefore run in
  /// [validate], which [TomJobDefinition] calls; see there for why that is the
  /// honest boundary rather than merely the available one.
  const TomRetryPolicy({
    this.maxAttempts = 3,
    this.initialBackoff = const Duration(seconds: 30),
    this.multiplier = 2.0,
    this.maxBackoff = const Duration(minutes: 30),
    this.jitter = 0.1,
  });

  /// A policy that never retries: one attempt, and a failure is final.
  static const TomRetryPolicy none = TomRetryPolicy(maxAttempts: 1);

  /// Throws a `schedule.retry.*` [TomScheduleException] if this policy would
  /// misbehave, naming [job] so the report identifies which one to fix.
  ///
  /// Called by [TomJobDefinition], which every policy passes through on its way
  /// into a scheduler. That placement is deliberate rather than a workaround
  /// for the `const` constructor: an unattached policy governs nothing, so the
  /// moment a bad value starts producing wrong answers is the moment a job
  /// adopts it — and only then is there a name to put in the message.
  ///
  /// Each rule below rejects a value that is currently accepted and then
  /// quietly does the wrong thing, which is the shared reason they are errors
  /// and not merely unusual settings.
  void validate(String job) {
    if (maxAttempts < 1) {
      throw TomScheduleException(
        'schedule.retry.max_attempts',
        'maxAttempts counts the first attempt, so it must be at least 1 '
            '(1 means "no retry"); got $maxAttempts.',
        parameters: {'job': job, 'maxAttempts': maxAttempts},
      );
    }
    if (multiplier < 1) {
      throw TomScheduleException(
        'schedule.retry.multiplier',
        'multiplier must be at least 1, or the backoff shrinks on every '
            'failure instead of growing; got $multiplier.',
        parameters: {'job': job, 'multiplier': multiplier},
      );
    }
    if (jitter < 0 || jitter > 1) {
      throw TomScheduleException(
        'schedule.retry.jitter',
        'jitter is a fraction of the computed backoff and must be 0..1; '
            'got $jitter.',
        parameters: {'job': job, 'jitter': jitter},
      );
    }
    if (initialBackoff < Duration.zero) {
      throw TomScheduleException(
        'schedule.retry.initial_backoff',
        'initialBackoff cannot be negative; got $initialBackoff.',
        parameters: {'job': job, 'initialBackoff': '$initialBackoff'},
      );
    }
    // Positive, where initialBackoff need only be non-negative: retrying at
    // once is a real choice, but a zero ceiling clamps every backoff to nothing
    // and turns maxAttempts into a tight spin against whatever just failed.
    if (maxBackoff <= Duration.zero) {
      throw TomScheduleException(
        'schedule.retry.max_backoff',
        'maxBackoff is the ceiling every backoff is clamped to and must be '
            'positive; got $maxBackoff.',
        parameters: {'job': job, 'maxBackoff': '$maxBackoff'},
      );
    }
  }

  /// Whether an attempt numbered [attempt] may be followed by another.
  bool allowsRetryAfter(int attempt) => attempt < maxAttempts;

  /// The delay before the attempt following [attempt] (1-based).
  ///
  /// [random] is supplied by the scheduler so jitter is reproducible in tests;
  /// omitting it yields the exact, unjittered backoff — the low end of the
  /// range a jittered call draws from.
  Duration backoffFor(int attempt, [Random? random]) {
    final steps = (attempt - 1).clamp(0, 30);
    final scaled = initialBackoff.inMicroseconds * pow(multiplier, steps);

    // Jitter is added on top, so the exponential curve has to plateau a
    // jitter's width *below* [maxBackoff] for the jittered result to land on
    // the ceiling rather than past it.
    //
    // The alternative — clamping after jittering — would keep the ceiling by
    // handing every saturated job the same instant to retry on, and saturation
    // is precisely the case jitter exists for: a long outage drives a whole
    // fleet to [maxBackoff] together. Reserving the headroom keeps the full
    // spread there, at the cost of the plateau sitting below the ceiling.
    //
    // The `> 0` guards keep this arithmetic total for a policy that never
    // reached [validate] — one built by hand and used without a job. A
    // registered policy cannot be negative, so for every policy the scheduler
    // actually runs these guards are simply never the deciding branch.
    final headroom = 1 + (jitter > 0 ? jitter : 0);
    final plateau = maxBackoff.inMicroseconds / headroom;
    var micros = (scaled.isFinite ? scaled.clamp(0, plateau) : plateau).round();
    if (random != null && jitter > 0) {
      micros += (micros * jitter * random.nextDouble()).round();
    }

    // Two roundings sit between the plateau and here, either of which can go
    // up, so the ceiling is enforced rather than merely arrived at.
    return Duration(microseconds: micros.clamp(0, maxBackoff.inMicroseconds));
  }

  @override
  String toString() =>
      'TomRetryPolicy(maxAttempts: $maxAttempts, '
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

  /// A run that was interrupted mid-execution was **not** re-queued, because its
  /// job does not set [TomJobDefinition.requestsRecovery].
  ///
  /// The counterpart to [runAbandoned], and separate from it on purpose: those
  /// two outcomes look alike in a store — an expired lease either way — but they
  /// mean opposite things to an operator. [runAbandoned] says "it will run
  /// again"; this says "it will not, and if that work mattered somebody has to
  /// decide what to do about it". The run is left terminally `failed` with
  /// [TomJobStore.recoveryDeclinedError] recorded against it.
  recoveryDeclined,

  /// A schedule produced windows that were skipped by its missed-window policy.
  windowsMissed,

  /// A registered job's schedule will never produce a window.
  ///
  /// The quiet misconfiguration: a job that can never run looks exactly like a
  /// job that is merely not due yet, and without this nothing would ever say
  /// otherwise. It arises two ways — a recurrence that cannot match (`0 0 30 2
  /// *` is February 30th) and, more usefully, a `TomOnceSchedule` whose instant
  /// had already passed when the job was first registered, which is what a
  /// deadline job restored at start-up after a long outage looks like.
  ///
  /// Raised once per job per scheduler rather than once per tick: the condition
  /// cannot resolve itself, and an alert that repeats every tick forever is how
  /// operators learn to filter a channel.
  neverFires,

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

  /// The schedule involved, for [TomJobAlertKind.neverFires].
  ///
  /// Carried rather than left to the reader to look up: "job X will never run"
  /// is only actionable next to the expression that cannot match.
  final TomSchedule? schedule;

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
    this.schedule,
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
    TomJobAlertKind.recoveryDeclined =>
      'Job "$jobName" run ${run?.id} was interrupted mid-execution and '
          'was NOT re-queued; the job does not set requestsRecovery.',
    TomJobAlertKind.windowsMissed =>
      'Job "$jobName" skipped $missedWindows missed window(s).',
    TomJobAlertKind.neverFires =>
      'Job "$jobName" has no future window and will never run '
          '(schedule: $schedule).',
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
  /// itself is **not** cancelled — Dart cannot cancel arbitrary asynchronous
  /// work, an isolate command cannot be interrupted from outside, and killing
  /// the worker would take unrelated work with it. The timeout bounds the
  /// scheduler's wait, not the body.
  ///
  /// So the body is still treated as executing until it settles: the
  /// scheduler keeps the protection the attempt held — the job counts as busy
  /// (with [allowOverlap] `true`, only its own run does) and the run's cluster
  /// lease is kept and renewed — and the retry is not started until the body
  /// returns or throws. What a late body produces is discarded; the attempt
  /// was already failed. Two consequences follow. A body that finishes late
  /// has done its work *and* its retry will do it again, one after the other —
  /// a duplicate the at-least-once contract already asks bodies to absorb. And
  /// a body that never settles holds its job (or window) indefinitely, which
  /// `TomScheduler.overrunningCount` shows; give a body that can hang a
  /// deadline of its own, shorter than this one.
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

  /// Whether a run interrupted **mid-execution** may be re-queued.
  ///
  /// `false` by default, which is the safe reading: a body that died halfway
  /// through may have written half its effects, and re-running it repeats them.
  /// Set it to `true` only for a body that is idempotent, or whose work is
  /// worthless unless completed — a report regenerated from scratch, a sync that
  /// recomputes the whole delta.
  ///
  /// This governs *only* the interrupted case. A run that was claimed and never
  /// started is always re-queued regardless, because nothing executed and
  /// nothing can therefore repeat; [TomJobRun.startedAt] is what tells the two
  /// apart.
  ///
  /// Quartz spells the same opt-in `REQUESTS_RECOVERY` and defaults it off for
  /// the same reason.
  final bool requestsRecovery;

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
    this.requestsRecovery = false,
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
    // The policy cannot check itself: its constructor is `const` so that it can
    // appear in a @TomScheduledJob annotation. This is where it becomes live,
    // so this is where it is checked.
    retryPolicy.validate(name);
  }

  @override
  String toString() => 'TomJobDefinition($name, ${schedule.describe()})';
}
