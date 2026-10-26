/// The durable job queue — pending and in-flight runs that survive a restart.
///
/// A scheduler that keeps its plan in memory forgets everything the moment the
/// process exits: work that was queued is lost, and work that was *half done*
/// is lost twice over, because nothing records that it was ever started. This
/// library is the store that stops both.
///
/// ## What is persisted, and why that is the whole model
///
/// The unit of persistence is the [TomJobRun] — **one attempt-carrying record
/// per schedule window**. Two fields on it do most of the work:
///
/// * [TomJobRun.scheduledFor] is the *window* the run belongs to, and it is the
///   idempotence key. The scheduler enqueues by window, so replaying a tick —
///   or restarting mid-tick — cannot produce a second run for the same window.
/// * [TomJobRun.runAt] is when the run should next be *attempted*. A retry is
///   therefore not a new record and not a new state; it is the same run with a
///   higher [TomJobRun.attempt] and a later [runAt]. That keeps the state
///   machine at four values and makes "what is outstanding" a single query.
///
/// A claimed run carries [TomJobRun.claimedBy] and [TomJobRun.claimedAt] — a
/// lease. If the process dies holding it, the record stays `running` with a
/// stale timestamp, and [TomJobStore.recoverAbandoned] hands it back. That is
/// what "in-flight runs survive a restart" means concretely: not that the work
/// continues, but that it is visibly outstanding again rather than silently
/// gone.
///
/// ## Implementations
///
/// * [TomMemoryJobStore] — no durability. Correct for tests and for jobs whose
///   loss on restart is acceptable.
/// * [TomFileJobStore] — mirrors the queue to a JSON file on every mutation and
///   reloads it on construction, following the same pattern as the kernel's
///   file-backed log replay store. This is what makes the scheduler durable
///   **without a database**, which matters because `tom_core_kernel` has no
///   persistence layer and must not grow one for this.
///
/// A relational implementation belongs in `tom_core_server`, over the same
/// [TomJobStore] contract; the lease fields are already shaped for the
/// multi-node lock that will need it.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:tom_basics/tom_basics.dart';

import '../little_things/atomic_file.dart';
import 'job_run_context.dart';
import 'lease_lock.dart';
import 'schedule.dart';

// =============================================================================
// RUN STATE
// =============================================================================

/// The lifecycle of a single [TomJobRun].
///
/// Deliberately four values. "Failed but will be retried" is **not** among them
/// — that is a `pending` run with a higher attempt count and a later
/// `runAt`, because modelling it as its own state would mean two places
/// answering "is there work outstanding?".
enum TomJobRunState {
  /// Planned and not currently held by anyone. Due when `runAt <= now`.
  pending,

  /// Claimed by a runner, whose lease is [TomJobRun.claimedAt].
  running,

  /// Finished successfully. Terminal.
  succeeded,

  /// Finished unsuccessfully with retries exhausted. Terminal.
  failed,
}

// =============================================================================
// RUN RECORD
// =============================================================================

/// One attempt-carrying occurrence of a job.
///
/// Mutable by design: a run is a record that moves through states, and copying
/// it on each transition would leave the store deciding which copy is current.
/// All mutation goes through [TomJobStore], so the persisted mirror can never
/// drift from the in-memory one.
class TomJobRun {
  /// Unique identity of this run, stable across restarts.
  final String id;

  /// The [TomJobDefinition.name] this run belongs to.
  final String jobName;

  /// The schedule window this run realises — the idempotence key.
  ///
  /// For a catch-up run this is the window that was *missed*, not the moment
  /// the catch-up was noticed, so a job body can tell which period it is
  /// processing.
  final DateTime scheduledFor;

  /// When this run should next be attempted.
  ///
  /// Equal to [scheduledFor] for a first attempt, and the backoff deadline for
  /// every retry after that.
  DateTime runAt;

  /// Where this run is in its lifecycle.
  TomJobRunState state;

  /// Which attempt is next (or in flight), 1-based.
  int attempt;

  /// Identity of the runner holding the lease, `null` when unclaimed.
  String? claimedBy;

  /// When the lease was last heard from, `null` when unclaimed. Compared
  /// against the lease timeout by [TomJobStore.recoverAbandoned].
  ///
  /// This is the *heartbeat*, not the claim's identity:
  /// [TomJobStore.renewClaim] pushes it forward for as long as the attempt
  /// runs. Which claim is current is [claimToken]'s job.
  DateTime? claimedAt;

  /// Which claim of this run is current: strictly increasing across claims,
  /// never decreasing, and never reset.
  ///
  /// The fencing token of [TomJobClaim], and the counterpart of `TomLease.token`
  /// on the coordination lock — the same problem, solved the same way, because
  /// the two must agree about who holds a run. It starts at 0 on an unclaimed
  /// run and is incremented by [TomJobStore.claimDue] on every claim, including
  /// a re-claim by the node that held it before.
  ///
  /// It is a separate field from [claimedAt] because the two answer different
  /// questions and only one of them may move during an attempt. A heartbeat
  /// that doubled as the identity would invalidate the claim it was proving
  /// alive.
  int claimToken;

  /// When the body actually began executing, `null` if it never did.
  ///
  /// The distinction between "claimed" and "started" is what makes recovery
  /// safe to reason about. A `running` run with no [startedAt] was reserved and
  /// then lost — the node died between the claim and the dispatch — so nothing
  /// was executed and re-queueing it cannot repeat a side effect. A `running`
  /// run *with* [startedAt] was interrupted **mid-execution**, and whether it is
  /// safe to run again is a property of the job, not of the store: see
  /// [TomJobDefinition.requestsRecovery].
  ///
  /// Quartz draws the same line with two trigger states, `ACQUIRED` and
  /// `EXECUTING`. It is one nullable instant here because the instant is also
  /// worth having — "how long had it been running when the node died" is the
  /// first question asked after an incident.
  DateTime? startedAt;

  /// The most recent failure message, retained on retry so a run that
  /// eventually fails can report why it kept failing.
  String? lastError;

  /// When the run reached a terminal state.
  DateTime? completedAt;

  /// Trigger payload for an event-driven run; `null` for clock-driven ones.
  ///
  /// Restricted to a JSON-encodable value so a durable store can round-trip it.
  final Object? payload;

  /// The tenant the run belongs to, or `null` for a run of no tenant.
  ///
  /// The scheduler runs the body inside this tenant's context
  /// (`TomTenantContext`), and keeps each tenant's windows apart: two tenants'
  /// events arriving in the same instant are two runs, not one.
  final String? tenant;

  /// How urgent the run is: among runs due at the same moment, a higher
  /// priority is claimed first. `0` by default; negative values are allowed.
  ///
  /// Copied from [TomJobDefinition.priority] when the run is planned, so the
  /// order is a property of the queue every node reads, not of whichever node
  /// happens to scan it. Priority orders the claim and nothing else: it does
  /// not pre-empt a run already executing, and a low-priority run still runs
  /// once nothing more urgent is due.
  final int priority;

  /// The progress the run last recorded, or `null` when it never recorded any.
  ///
  /// A body saves it through [TomJobRunContext.saveCheckpoint] whenever it
  /// chooses — after each batch of a long import, say — and it is kept with the
  /// run across retries and across recovery after a node died. The attempt that
  /// runs next reads it here (or from [TomJobRunContext.checkpoint]) and decides
  /// how to continue; a body that never saves one starts over every time.
  ///
  /// What it holds is the job's business — the framework stores it and hands it
  /// back. It is restricted to JSON-native values for the reason [payload] is.
  Map<String, Object?>? checkpoint;

  /// Creates a run record.
  TomJobRun({
    required this.id,
    required this.jobName,
    required this.scheduledFor,
    required this.runAt,
    this.state = TomJobRunState.pending,
    this.attempt = 1,
    this.claimedBy,
    this.claimedAt,
    this.claimToken = 0,
    this.startedAt,
    this.lastError,
    this.completedAt,
    this.payload,
    this.tenant,
    this.priority = 0,
    this.checkpoint,
  });

  /// Whether this run has reached a terminal state.
  bool get isFinished =>
      state == TomJobRunState.succeeded || state == TomJobRunState.failed;

  /// Whether this run is due to be attempted at [now].
  bool isDue(DateTime now) =>
      state == TomJobRunState.pending && !runAt.isAfter(now);

  /// Encodes this run as a JSON-native map.
  Map<String, Object?> toJson() => {
    'id': id,
    'jobName': jobName,
    'scheduledFor': scheduledFor.toIso8601String(),
    'runAt': runAt.toIso8601String(),
    'state': state.name,
    'attempt': attempt,
    'claimedBy': claimedBy,
    'claimedAt': claimedAt?.toIso8601String(),
    'claimToken': claimToken,
    'startedAt': startedAt?.toIso8601String(),
    'lastError': lastError,
    'completedAt': completedAt?.toIso8601String(),
    'payload': payload,
    'tenant': tenant,
    'priority': priority,
    'checkpoint': checkpoint,
  };

  /// Decodes a map produced by [toJson].
  ///
  /// An unrecognised state decodes as [TomJobRunState.pending] rather than
  /// throwing: a store written by a newer build must not make an older one
  /// unable to start, and "pending" is the safe reading — the run is offered
  /// again instead of being silently treated as done.
  factory TomJobRun.fromJson(Map<String, Object?> map) => TomJobRun(
    id: map['id'] as String,
    jobName: map['jobName'] as String,
    scheduledFor: DateTime.parse(map['scheduledFor'] as String),
    runAt: DateTime.parse(map['runAt'] as String),
    state: TomJobRunState.values.firstWhere(
      (s) => s.name == map['state'],
      orElse: () => TomJobRunState.pending,
    ),
    attempt: map['attempt'] as int? ?? 1,
    claimedBy: map['claimedBy'] as String?,
    claimedAt: _parseOrNull(map['claimedAt']),
    // Absent in a queue file written before claims were fenced. Zero is the
    // safe reading: the next claim raises it, and nothing holds a ticket for a
    // run this process has not claimed yet.
    claimToken: map['claimToken'] as int? ?? 0,
    startedAt: _parseOrNull(map['startedAt']),
    lastError: map['lastError'] as String?,
    completedAt: _parseOrNull(map['completedAt']),
    payload: map['payload'],
    tenant: map['tenant'] as String?,
    priority: map['priority'] as int? ?? 0,
    checkpoint: switch (map['checkpoint']) {
      final Map<Object?, Object?> value => value.cast<String, Object?>(),
      _ => null,
    },
  );

  static DateTime? _parseOrNull(Object? value) =>
      value is String ? DateTime.parse(value) : null;

  @override
  String toString() =>
      '$jobName#${scheduledFor.toIso8601String()} '
      '(${state.name}, attempt $attempt)';
}

// =============================================================================
// CLAIM TICKET
// =============================================================================

/// A ticket proving that one particular claim of [run] was won.
///
/// [TomJobStore.claimDue] issues one per run it hands over, and every
/// transition out of a claim takes the ticket rather than the run. That is the
/// same arrangement `TomLeaseLock` uses — `acquire` returns a `TomLease` and
/// `renew`/`release` take it back — and it is here for the same reason: a
/// caller cannot record an outcome for work it did not claim, because it has
/// nothing to call the method with.
///
/// ## What the ticket has to identify
///
/// Not the run, and not the node: **this claim of this run**. [owner] alone is
/// not enough, because a node can re-claim a run it had previously lost — and
/// then its first attempt's outcome would be accepted as its second's.
///
/// So the fence is [token], a counter that rises on every claim of the run and
/// never repeats. It is exactly `TomLease.token`, for exactly the same reason:
/// two acquisitions of the same thing have to be orderable, or "the current
/// holder" is not a decidable question. That the queue lacked one while the
/// lock had one is why the two could disagree.
///
/// ## Why not the claim instant
///
/// [TomJobRun.claimedAt] looks like a cheaper answer — it is already stored,
/// and it already distinguishes two claims. But it is the *heartbeat*:
/// [TomJobStore.renewClaim] moves it forward while the attempt runs. A ticket
/// fenced on it would be invalidated by the first heartbeat of the very attempt
/// it certifies, so the claimant would silently lose the right to report its
/// own outcome. The identity must be the thing that does *not* move, which is
/// the whole reason the lock separates `token` from `expiresAt`.
class TomJobClaim {
  /// The claimed run, as the claimant sees it.
  ///
  /// Mutable, and mutated by the transitions below so a caller's copy keeps up
  /// with what it just wrote — the ticket is the identity, this is the payload.
  final TomJobRun run;

  /// The runner this claim was leased to.
  ///
  /// Not load-bearing on its own — [token] already separates two claims — but
  /// checked alongside it, so a ticket threaded to the wrong store or the wrong
  /// node is refused rather than coincidentally accepted.
  final String owner;

  /// The value of [TomJobRun.claimToken] this claim was granted.
  final int token;

  /// Creates a ticket for [run], claimed by [owner] at [token].
  ///
  /// Public because implementations construct it and tests need to forge one —
  /// a fence that could only be built by the store would be untestable against
  /// the case it exists for.
  const TomJobClaim(this.run, this.owner, this.token);

  /// The claimed run's id.
  String get id => run.id;

  /// Whether [stored] is still held under *this* claim.
  bool holds(TomJobRun stored) =>
      stored.claimedBy == owner && stored.claimToken == token;

  @override
  String toString() => 'TomJobClaim(${run.id} by $owner, token $token)';
}

// =============================================================================
// STORE CONTRACT
// =============================================================================

/// Durable storage for job runs.
///
/// Every method is asynchronous so a database-backed implementation fits the
/// same contract without the in-memory one having to pretend to be slow.
///
/// **Claiming must be atomic.** [claimDue] transitions a run to `running` and
/// stamps the lease in one step; an implementation that let two callers observe
/// the same run as claimable would double-fire it. The in-process
/// implementations here are atomic by virtue of Dart's single-threaded event
/// loop — they perform no `await` between selecting and stamping.
///
/// **A transition out of a claim only ever *records* a run; it never creates
/// one, and never overrules another claimant.** [release], [markStarted],
/// [renewClaim], [complete] and [fail] are all no-ops unless the store still
/// holds the run, still holds it as `running`, *and* still holds it under the
/// [TomJobClaim] being presented. Each of the five is reached by a caller
/// holding a ticket it obtained some time earlier, so each can be handed a
/// claim the store has since finished, re-queued, handed to another node via
/// [recoverAbandoned], or dropped entirely via [purgeFinished] — and in every
/// one of those cases the outcome of the attempt this caller is reporting is no
/// longer the run's outcome.
///
/// The two halves of the guard answer two different questions, and only both
/// together are sufficient:
///
///  * **Does the store still hold this run, as `running`?** Without it, writing
///    back would resurrect a purged row — [purgeFinished] is the only thing
///    bounding the store, and a re-inserted run carries a freshly stamped
///    [TomJobRun.completedAt] that restarts its retention clock, so it survives
///    every subsequent cutoff.
///  * **Is it still held under *this* claim?** State alone cannot see the case
///    the lease timeout exists for. A node partitioned for longer than the
///    timeout returns to a run that recovery re-queued and a peer re-claimed:
///    the row exists and is `running`, so a state-only guard passes, and the
///    returning node's outcome silently overwrites an attempt the peer is still
///    executing. The peer then heartbeats a run already marked succeeded, and
///    its own completion no-ops.
///
/// The rule costs nothing when nothing went wrong — a run this node still owns
/// is `running` under its own claim by definition — and it is what makes the
/// five safe to call without first re-reading the store.
abstract class TomJobStore {
  /// Whether an abandoned [run] may be offered again.
  ///
  /// A run that never started always may — nothing executed, so nothing can
  /// repeat. One that was interrupted mid-execution may only when its job says
  /// so, which is what [requestsRecovery] answers; a `null` predicate means the
  /// caller cannot see the job registry, and re-queueing is then the only
  /// answer it can give.
  ///
  /// Shared rather than duplicated because both stores must decide identically
  /// — but only the decision is shared. Each store applies the resulting
  /// transition in its own idiom: field assignment in memory, a different
  /// `UPDATE` in SQL.
  static bool isRecoverable(
    TomJobRun run,
    bool Function(String jobName)? requestsRecovery,
  ) =>
      run.startedAt == null ||
      requestsRecovery == null ||
      requestsRecovery(run.jobName);

  /// What an interrupted run's [TomJobRun.lastError] says when its job did not
  /// ask to be recovered.
  ///
  /// A constant because it is the operator-facing explanation of a decision the
  /// framework made on the job's behalf, and it must read the same whichever
  /// store recorded it.
  static const String recoveryDeclinedError =
      'Interrupted mid-execution and not re-queued: the job does not set '
      'requestsRecovery, so re-running it could repeat work already done.';

  /// The JSON text a durable store writes for [run]'s payload, or `null` when
  /// there is no payload.
  ///
  /// This is also the contract's definition of "JSON-encodable", and every
  /// implementation of [enqueue] calls it — *including the in-memory one*,
  /// which has nothing to write. The restriction belongs to the contract rather
  /// than to any one medium: a payload only the memory store would accept is a
  /// payload that fails on the first deployment that has a file or a database,
  /// and it should fail on the developer's machine instead.
  ///
  /// Throws a `schedule.job.payload` [TomScheduleException] naming the job and
  /// the offending type. The raw [JsonUnsupportedObjectError] says only that
  /// *some* object could not be converted, which is of little use several
  /// frames below whichever event handed the payload over.
  static String? encodePayload(TomJobRun run) {
    if (run.payload == null) return null;
    try {
      return jsonEncode(run.payload);
    } on JsonUnsupportedObjectError catch (error, stack) {
      final type = error.unsupportedObject.runtimeType;
      throw TomScheduleException(
        'schedule.job.payload',
        "The payload for job '${run.jobName}' is not JSON-encodable: it "
            'contains $type. A payload has to survive being written to a file or '
            'a database column, so it must be built from JSON-native values — '
            'send $type as a string or a number instead.',
        parameters: {'job': run.jobName, 'run': run.id, 'type': '$type'},
        rootException: error,
        stack: stack,
      );
    }
  }

  /// The JSON text a durable store writes for [checkpoint], or `null` when
  /// there is none.
  ///
  /// The checkpoint's counterpart of [encodePayload], called by every
  /// implementation of [saveCheckpoint] before it changes anything — the
  /// in-memory one included, for the reason given there.
  ///
  /// Throws a `schedule.job.checkpoint` [TomScheduleException] naming the job
  /// and the offending type.
  static String? encodeCheckpoint(
    TomJobRun run,
    Map<String, Object?>? checkpoint,
  ) {
    if (checkpoint == null) return null;
    try {
      return jsonEncode(checkpoint);
    } on JsonUnsupportedObjectError catch (error, stack) {
      final type = error.unsupportedObject.runtimeType;
      throw TomScheduleException(
        'schedule.job.checkpoint',
        "The checkpoint of job '${run.jobName}' is not JSON-encodable: it "
            'contains $type. A checkpoint is stored with the run, so it must be '
            'built from JSON-native values.',
        parameters: {'job': run.jobName, 'run': run.id, 'type': '$type'},
        rootException: error,
        stack: stack,
      );
    }
  }

  /// Adds [run] to the queue.
  ///
  /// The caller is responsible for idempotence via [findWindow]; the store
  /// stores what it is given.
  ///
  /// Throws a `schedule.job.payload` [TomScheduleException], **before changing
  /// the queue**, when [TomJobRun.payload] is not JSON-encodable — see
  /// [encodePayload].
  Future<void> enqueue(TomJobRun run);

  /// The run already recorded for [jobName] at [scheduledFor] for [tenant]
  /// (`null` for runs of no tenant), or `null`.
  ///
  /// This is what makes enqueueing idempotent, and therefore what makes a tick
  /// safe to replay after a crash. A window belongs to one tenant: the same
  /// instant for two tenants is two windows.
  Future<TomJobRun?> findWindow(
    String jobName,
    DateTime scheduledFor, {
    String? tenant,
  });

  /// The latest window ever enqueued for [jobName], or `null` if the job has no
  /// history in this store.
  ///
  /// The scheduler uses `null` to mean "first sight of this job" and anchors on
  /// the present instead of treating all of history as missed.
  Future<DateTime?> lastWindow(String jobName);

  /// Atomically claims up to [limit] runs that are due at [now], marking each
  /// `running` and leasing it to [owner].
  ///
  /// Runs are taken in descending [TomJobRun.priority], and in insertion order
  /// among equal priorities. A run of a paused job ([pauseJob]) is not
  /// claimed, whatever its priority, until the job is resumed.
  ///
  /// Returns one [TomJobClaim] per run won — the ticket every transition below
  /// requires. When [accept] is supplied, only runs it approves are claimed;
  /// the scheduler uses it to enforce per-job overlap policy without a second
  /// round-trip.
  Future<List<TomJobClaim>> claimDue(
    DateTime now,
    String owner, {
    int limit = 16,
    bool Function(TomJobRun run)? accept,
  });

  /// Returns the run held by [claim] to `pending` without charging it an
  /// attempt.
  ///
  /// The voluntary counterpart of [recoverAbandoned]: a runner that claimed a
  /// run and then found it could not proceed — most usually because a cluster
  /// peer holds the coordination lease for it — hands it straight back instead
  /// of sitting on the claim until the lease times out.
  ///
  /// The attempt count is deliberately untouched. Nothing was attempted, and
  /// charging an attempt would let a busy cluster exhaust a job's retry budget
  /// through contention alone.
  ///
  /// A no-op unless the store still holds the run as `running` under [claim] —
  /// a completion that raced the release must win, and a run recovery has since
  /// handed to a peer must not be pushed back into the queue underneath it.
  Future<void> release(TomJobClaim claim);

  /// Records that [claim]'s body actually began executing at [now].
  ///
  /// Called once per attempt, immediately before the body is handed to the
  /// dispatcher, and it is the only thing that distinguishes an interrupted
  /// *execution* from an abandoned *reservation*. Without it every `running` row
  /// looks the same after a node dies, and recovery has to guess.
  ///
  /// A no-op unless the store still holds the run as `running` under [claim]:
  /// the outcome of a run this node has lost belongs to whoever took it over.
  /// Stamping `startedAt` onto it would tell recovery that a *different* node's
  /// attempt had begun.
  Future<void> markStarted(TomJobClaim claim, DateTime now);

  /// Refreshes the lease timestamp on [claim] to [now].
  ///
  /// A long-running attempt must be able to say it is still alive, or
  /// [recoverAbandoned] would hand its work to a second runner while the first
  /// is still going. This is the store half of that heartbeat; the lock half is
  /// `TomLeaseLock.renew`.
  ///
  /// A no-op unless the store still holds the run as `running` under [claim] —
  /// a heartbeat for a lease this node no longer owns would keep recovery off a
  /// run it has already reassigned.
  ///
  /// The [TomJobClaim] itself does not move: it names the claim that was won,
  /// and a renewal extends that claim rather than starting a new one. What
  /// advances is the stored lease stamp, [TomJobRun.claimedAt]; the token the
  /// ticket carries is untouched, so the claimant keeps the right to record its
  /// own outcome for as long as the attempt lasts.
  Future<void> renewClaim(TomJobClaim claim, DateTime now);

  /// Stores [checkpoint] as the progress of [claim]'s run, replacing the one
  /// it had; `null` clears it. Returns whether it was stored.
  ///
  /// The checkpoint stays with the run across retries and across recovery, so
  /// the attempt that runs next can continue from it — see
  /// [TomJobRun.checkpoint].
  ///
  /// Fenced like the transitions: `false`, and nothing written, unless the
  /// store still holds the run as `running` under [claim]. Progress reported by
  /// an attempt that lost its run is not the run's progress — a peer is
  /// executing it from the checkpoint *it* was handed.
  ///
  /// Throws a `schedule.job.checkpoint` [TomScheduleException], before writing,
  /// when [checkpoint] is not JSON-encodable — see [encodeCheckpoint].
  Future<bool> saveCheckpoint(
    TomJobClaim claim,
    Map<String, Object?>? checkpoint,
  );

  /// Marks [claim]'s run succeeded at [now] and releases its lease.
  ///
  /// A no-op unless the store still holds the run as `running` under [claim] —
  /// see the rule on [TomJobStore]. Calling it twice therefore records the
  /// *first* completion only; the second does not move [TomJobRun.completedAt]
  /// forward, so a duplicate outcome cannot extend the run's retention.
  Future<void> complete(TomJobClaim claim, DateTime now);

  /// Records a failed attempt of [claim]'s run.
  ///
  /// When [retryAt] is non-null the run returns to `pending` with its attempt
  /// count incremented and `runAt` set to [retryAt]; when it is `null` the run
  /// becomes terminally [TomJobRunState.failed].
  ///
  /// A no-op unless the store still holds the run as `running` under [claim],
  /// exactly as [complete] is. The retrying branch has a second reason to
  /// check: it increments the attempt count, and charging a retry to a run that
  /// now belongs to another node would eat a retry budget this caller is no
  /// longer spending.
  Future<void> fail(
    TomJobClaim claim,
    String error,
    DateTime now, {
    DateTime? retryAt,
  });

  /// Reclaims runs left `running` by a holder that vanished.
  ///
  /// A lease older than [leaseTimeout] is treated as abandoned. The attempt
  /// count is **not** incremented: the run may never have started, and charging
  /// it an attempt for the scheduler's own death would let a crash loop consume
  /// a job's whole retry budget. Returns every run whose state this call
  /// changed, so the caller can alert on each; read [TomJobRun.state] to see
  /// which way it went.
  ///
  /// ## Re-queued, or terminally failed
  ///
  /// A run that was claimed but never started ([TomJobRun.startedAt] is `null`)
  /// always returns to `pending`, unpenalised: nothing ran, so nothing can
  /// repeat.
  ///
  /// A run that *had* started was interrupted mid-execution, and re-running it
  /// repeats whatever it had already done. Whether that is safe is a property of
  /// the job, so [requestsRecovery] is consulted: it returns `true` for a job
  /// that has declared itself recoverable ([TomJobDefinition.requestsRecovery]),
  /// and such a run goes back to `pending` like any other. A run whose job says
  /// otherwise becomes terminally [TomJobRunState.failed] with an explanatory
  /// [TomJobRun.lastError], because silently re-running a non-idempotent job is
  /// the worse of the two failures and the operator needs to see the decision.
  ///
  /// Passing `null` — the default — recovers everything, which is what a caller
  /// that cannot see the job registry must do. A store cannot invent the answer,
  /// and re-queueing is the behaviour every caller had before the distinction
  /// existed. `TomScheduler` always supplies the predicate.
  Future<List<TomJobRun>> recoverAbandoned(
    DateTime now,
    Duration leaseTimeout, {
    bool Function(String jobName)? requestsRecovery,
  });

  /// Every run currently held, in insertion order. Primarily for diagnostics
  /// and tests.
  Future<List<TomJobRun>> all();

  /// Removes terminal runs that completed before [before], returning how many
  /// were dropped.
  ///
  /// Without this the queue is an append-only log that grows forever. It is a
  /// caller-driven operation rather than an automatic one because how much
  /// history to keep is a deployment decision, not the store's.
  Future<int> purgeFinished(DateTime before);

  /// Pauses [jobName] as of [now]: none of its runs is claimed until
  /// [resumeJob].
  ///
  /// The pause is held by the store, so it applies to every node sharing the
  /// queue and survives a restart. It does not touch a run already executing —
  /// that one finishes, or fails and is retried after the resume — and it does
  /// not drop anything: runs stay in the queue, and runs enqueued meanwhile
  /// wait there too. Pausing a paused job keeps the instant of the first pause.
  Future<void> pauseJob(String jobName, DateTime now);

  /// Ends the pause of [jobName]; its due runs are claimable at once. A no-op
  /// for a job that is not paused.
  Future<void> resumeJob(String jobName);

  /// The paused jobs, each with the instant it was paused.
  Future<Map<String, DateTime>> pausedJobs();

  /// The runs due at [now] that nobody has claimed, per job: how many, and
  /// since when the oldest has been due.
  ///
  /// A paused job has no backlog: its runs are waiting because somebody said
  /// so, not because no node takes them.
  ///
  /// The scheduler reports it as the `tom_job_backlog` and
  /// `tom_job_backlog_age_seconds` gauges. A run that is due and unclaimed is
  /// late by definition, so a backlog that does not drain is the signal that no
  /// node is taking that job's work — the one a start-lag histogram cannot
  /// give, because a run nobody starts records no lag.
  Future<List<TomJobBacklog>> backlog(DateTime now);
}

/// The due, unclaimed runs of one job — see [TomJobStore.backlog].
class TomJobBacklog {
  /// The backlog of [jobName]: [due] runs, the oldest due since [oldestDueAt].
  const TomJobBacklog({
    required this.jobName,
    required this.due,
    required this.oldestDueAt,
  });

  /// The job.
  final String jobName;

  /// How many of its runs are due and unclaimed.
  final int due;

  /// When the oldest of them became due.
  final DateTime oldestDueAt;
}

// =============================================================================
// IN-MEMORY STORE
// =============================================================================

/// A [TomJobStore] that keeps everything in memory and nothing across restarts.
///
/// The base for [TomFileJobStore], which adds only the mirroring — so both
/// implementations share one copy of the claim and retry semantics rather than
/// two that can disagree.
class TomMemoryJobStore implements TomJobStore {
  /// Runs keyed by [TomJobRun.id], in insertion order.
  final Map<String, TomJobRun> _runs = {};

  /// Paused jobs and the instant each was paused.
  final Map<String, DateTime> _paused = {};

  /// Hook for subclasses that mirror the queue somewhere durable. Called after
  /// every mutation, and never during a read.
  void onMutated() {}

  @override
  Future<void> enqueue(TomJobRun run) async {
    // Check before mutating, and discard the text: [TomFileJobStore] mirrors
    // from [onMutated], so an encode failure discovered *there* would leave the
    // run in memory and every later mirror re-encoding it — one bad payload
    // would silently stop the queue from ever reaching disk again while the
    // store went on looking healthy.
    TomJobStore.encodePayload(run);
    _runs[run.id] = run;
    onMutated();
  }

  @override
  Future<TomJobRun?> findWindow(
    String jobName,
    DateTime scheduledFor, {
    String? tenant,
  }) async {
    for (final run in _runs.values) {
      if (run.jobName == jobName &&
          run.tenant == tenant &&
          run.scheduledFor.isAtSameMomentAs(scheduledFor)) {
        return run;
      }
    }
    return null;
  }

  @override
  Future<DateTime?> lastWindow(String jobName) async {
    DateTime? latest;
    for (final run in _runs.values) {
      if (run.jobName != jobName) continue;
      if (latest == null || run.scheduledFor.isAfter(latest)) {
        latest = run.scheduledFor;
      }
    }
    return latest;
  }

  @override
  Future<List<TomJobClaim>> claimDue(
    DateTime now,
    String owner, {
    int limit = 16,
    bool Function(TomJobRun run)? accept,
  }) async {
    final claimed = <TomJobClaim>[];
    // Highest priority first; `List.sort` is not stable, so the insertion index
    // breaks ties and keeps equal priorities in queue order.
    final indexed = _runs.values.indexed.toList()
      ..sort(
        (a, b) => a.$2.priority != b.$2.priority
            ? b.$2.priority.compareTo(a.$2.priority)
            : a.$1.compareTo(b.$1),
      );
    // No `await` inside the loop: selecting and stamping happen in one
    // uninterrupted turn of the event loop, which is what makes the claim
    // atomic against a concurrent caller in this isolate.
    for (final (_, run) in indexed) {
      if (claimed.length >= limit) break;
      if (!run.isDue(now) || _paused.containsKey(run.jobName)) continue;
      if (accept != null && !accept(run)) continue;
      run.state = TomJobRunState.running;
      run.claimedBy = owner;
      run.claimedAt = now;
      run.claimToken++;
      // The ticket copies the owner and the token rather than reading them back
      // off the run later. This store hands out the *same object* it holds, so
      // a subsequent recovery and re-claim mutate the very run the first
      // claimant is still carrying — a fence read from that object would always
      // agree with whoever wrote it last, which is precisely the wrong node.
      claimed.add(TomJobClaim(run, owner, run.claimToken));
    }
    if (claimed.isNotEmpty) onMutated();
    return claimed;
  }

  /// The stored run [claim] still holds, or `null` when it no longer does.
  ///
  /// The whole of the rule documented on [TomJobStore], in one place: the run
  /// must exist, be `running`, and be `running` *under this claim*. Written
  /// once because five transitions ask the same question, and five copies of a
  /// three-part predicate is five chances for one of them to drift.
  TomJobRun? _held(TomJobClaim claim) {
    final stored = _runs[claim.run.id];
    if (stored == null || stored.state != TomJobRunState.running) return null;
    return claim.holds(stored) ? stored : null;
  }

  @override
  Future<void> release(TomJobClaim claim) async {
    final stored = _held(claim);
    if (stored == null) return;
    stored.state = TomJobRunState.pending;
    stored.claimedBy = null;
    stored.claimedAt = null;
    onMutated();
  }

  @override
  Future<void> markStarted(TomJobClaim claim, DateTime now) async {
    final stored = _held(claim);
    if (stored == null) return;
    stored.startedAt = now;
    claim.run.startedAt = now;
    onMutated();
  }

  @override
  Future<void> renewClaim(TomJobClaim claim, DateTime now) async {
    final stored = _held(claim);
    if (stored == null) return;
    stored.claimedAt = now;
    onMutated();
  }

  @override
  Future<bool> saveCheckpoint(
    TomJobClaim claim,
    Map<String, Object?>? checkpoint,
  ) async {
    TomJobStore.encodeCheckpoint(claim.run, checkpoint);
    final stored = _held(claim);
    if (stored == null) return false;
    // A copy, so a body that keeps mutating its map after saving cannot change
    // what was stored.
    final copy = checkpoint == null ? null : _copyJson(checkpoint);
    stored.checkpoint = copy;
    claim.run.checkpoint = copy;
    onMutated();
    return true;
  }

  /// A deep copy of a JSON-native map, through its encoding.
  static Map<String, Object?> _copyJson(Map<String, Object?> value) =>
      (jsonDecode(jsonEncode(value)) as Map).cast<String, Object?>();

  @override
  Future<void> complete(TomJobClaim claim, DateTime now) async {
    final stored = _held(claim);
    if (stored == null) return;
    stored.state = TomJobRunState.succeeded;
    stored.completedAt = now;
    stored.claimedBy = null;
    stored.claimedAt = null;
    onMutated();
  }

  @override
  Future<void> fail(
    TomJobClaim claim,
    String error,
    DateTime now, {
    DateTime? retryAt,
  }) async {
    final stored = _held(claim);
    if (stored == null) return;
    stored.lastError = error;
    stored.claimedBy = null;
    stored.claimedAt = null;
    if (retryAt == null) {
      stored.state = TomJobRunState.failed;
      stored.completedAt = now;
    } else {
      stored.state = TomJobRunState.pending;
      stored.attempt++;
      stored.runAt = retryAt;
    }
    onMutated();
  }

  @override
  Future<List<TomJobRun>> recoverAbandoned(
    DateTime now,
    Duration leaseTimeout, {
    bool Function(String jobName)? requestsRecovery,
  }) async {
    final recovered = <TomJobRun>[];
    for (final run in _runs.values) {
      if (run.state != TomJobRunState.running) continue;
      final since = run.claimedAt;
      // A `running` run with no lease timestamp is corrupt state; treat it as
      // abandoned rather than leaving it stuck forever.
      if (since != null && now.difference(since) < leaseTimeout) continue;
      run.claimedBy = null;
      run.claimedAt = null;
      if (TomJobStore.isRecoverable(run, requestsRecovery)) {
        run.state = TomJobRunState.pending;
      } else {
        run.state = TomJobRunState.failed;
        run.completedAt = now;
        run.lastError = TomJobStore.recoveryDeclinedError;
      }
      recovered.add(run);
    }
    if (recovered.isNotEmpty) onMutated();
    return recovered;
  }

  @override
  Future<List<TomJobRun>> all() async => snapshotSync();

  @override
  Future<List<TomJobBacklog>> backlog(DateTime now) async {
    final due = <String, int>{};
    final oldest = <String, DateTime>{};
    for (final run in _runs.values) {
      if (!run.isDue(now) || _paused.containsKey(run.jobName)) continue;
      due[run.jobName] = (due[run.jobName] ?? 0) + 1;
      final first = oldest[run.jobName];
      if (first == null || run.runAt.isBefore(first)) {
        oldest[run.jobName] = run.runAt;
      }
    }
    return [
      for (final job in due.keys)
        TomJobBacklog(jobName: job, due: due[job]!, oldestDueAt: oldest[job]!),
    ];
  }

  /// The current runs, without going through the asynchronous contract.
  ///
  /// [TomJobStore] is asynchronous so a database-backed implementation fits it,
  /// but these in-process stores hold everything already. A durable subclass
  /// needs the contents *during* [onMutated], where awaiting would put the
  /// mirror one microtask behind the mutation it is mirroring — and a crash in
  /// that gap is exactly the case the mirror exists for.
  List<TomJobRun> snapshotSync() => List.of(_runs.values);

  @override
  Future<int> purgeFinished(DateTime before) async {
    final doomed = [
      for (final run in _runs.values)
        if (run.isFinished &&
            run.completedAt != null &&
            run.completedAt!.isBefore(before))
          run.id,
    ];
    for (final id in doomed) {
      _runs.remove(id);
    }
    if (doomed.isNotEmpty) onMutated();
    return doomed.length;
  }

  @override
  Future<void> pauseJob(String jobName, DateTime now) async {
    if (_paused.containsKey(jobName)) return;
    _paused[jobName] = now;
    onMutated();
  }

  @override
  Future<void> resumeJob(String jobName) async {
    if (_paused.remove(jobName) != null) onMutated();
  }

  @override
  Future<Map<String, DateTime>> pausedJobs() async => pausedSync();

  /// The paused jobs, without going through the asynchronous contract — see
  /// [snapshotSync].
  Map<String, DateTime> pausedSync() => Map.of(_paused);

  /// Replaces the queue's contents, and with [paused] its paused jobs. Used by
  /// [TomFileJobStore] when reloading.
  void replaceAll(
    Iterable<TomJobRun> runs, [
    Map<String, DateTime> paused = const {},
  ]) {
    _runs
      ..clear()
      ..addEntries(runs.map((r) => MapEntry(r.id, r)));
    _paused
      ..clear()
      ..addAll(paused);
  }
}

// =============================================================================
// FILE-BACKED STORE
// =============================================================================

/// A [TomJobStore] that mirrors the queue to a JSON file on every mutation.
///
/// Constructing it reloads whatever the previous process left behind, so a
/// scheduler pointed at the same path resumes with its pending runs intact and
/// its in-flight runs visible as expired leases. That is the whole of the
/// durability requirement met without a database — which matters, because
/// `tom_core_kernel` deliberately has no persistence layer.
///
/// Writes are synchronous, flushed and *atomic*: the new queue is staged in a
/// sibling file and renamed over the target, so an interrupted write leaves the
/// previous queue rather than a truncated one. That is not a refinement but the
/// difference between losing one mutation and losing the whole queue — the file
/// is rewritten whole each time, and [_load] can only discard a queue it
/// cannot parse.
///
/// The queue is small (one record per window, purged once terminal), so
/// rewriting it whole is cheaper than the bookkeeping an append-only journal
/// would need to compact.
///
/// ## Shared by several stores
///
/// Several stores may point at one file — scheduler processes on one host, or
/// on a shared mount, or isolates in one process — and they then share one
/// queue. Every operation takes an exclusive file mutex (a [TomFileLeaseLock]
/// on the sibling directory `<path>.lock`), **re-reads the file**, applies
/// itself, writes the file back if it changed anything, and releases the
/// mutex. So a claim is atomic across every store on the file: a run is claimed
/// by exactly one of them, and a run one store completed is completed for all.
///
/// Each store's own copy of the queue is therefore only a working copy,
/// refreshed at the start of every operation, and never the truth. That is
/// the whole difference from its superclass, and the reason neither half is
/// optional: a store that read the file once and then mirrored its own copy to
/// it would overwrite every other store's writes and act on runs they had
/// already completed.
///
/// The mutex is a lease, 30 seconds long, so a process that dies while holding
/// it — in the middle of one operation, which takes milliseconds — blocks its
/// peers for at most that long before one of them takes it over. A holder
/// *paused* for longer than that mid-operation could still write a stale queue
/// over a newer one, the hazard every lease carries; the operation is short
/// enough that this needs a stall of half a minute inside it.
///
/// The claim being atomic does not make the lease lock redundant for a
/// scheduler: it is still what enforces `allowOverlap` across nodes, and it is
/// what fences a node paused past its lease.
///
/// The filesystem must make exclusive create and rename atomic between the
/// processes sharing it — true of local filesystems and of well-behaved network
/// ones; see [TomFileLeaseLock].
class TomFileJobStore extends TomMemoryJobStore {
  /// The file the queue is mirrored to and reloaded from.
  final File file;

  /// The mutex every operation holds — see "Shared by several stores".
  final TomFileLeaseLock _mutex;

  /// Distinguishes this store's operations from every other's as mutex
  /// owners. A fresh owner per operation (see [_exclusively]) is what makes two
  /// concurrent operations of one store exclude each other as well: a lease
  /// lock re-grants a live lease to its own owner.
  final String _ownerPrefix;

  int _operations = 0;

  /// Set by [onMutated] during an operation, so the file is written once, at
  /// its end, and only when the operation changed something.
  bool _changed = false;

  /// The mutex resource inside the `<path>.lock` directory.
  static const String _mutexResource = 'queue';

  /// How long a dead holder can keep the mutex from its peers.
  static const Duration _mutexTtl = Duration(seconds: 30);

  /// Creates a store backed by [path], loading any previously persisted runs.
  ///
  /// Writes to [path] if — and only if — what it finds there is damaged: the
  /// unreadable content is moved to [_corruptPath] and whatever could be
  /// salvaged is written back. That is the one case where constructing a store
  /// has an effect on disk, and it is deliberate. A salvage that lived only in
  /// memory would be undone by the next restart, and the original has just been
  /// renamed away, so not rewriting would lose the runs a second time.
  TomFileJobStore(String path)
    : file = File(path),
      _mutex = TomFileLeaseLock('$path.lock'),
      _ownerPrefix =
          '$pid-${Random.secure().nextInt(1 << 32).toRadixString(16)}' {
    _load();
  }

  @override
  void onMutated() => _changed = true;

  /// Runs [operation] against the file's current queue, holding the mutex.
  ///
  /// Re-reads the file first, because this store's copy may be stale — another
  /// store may have written since — and writes it back at the end if the
  /// operation changed anything. A read-only operation leaves the file alone.
  Future<T> _exclusively<T>(Future<T> Function() operation) async {
    final owner = '$_ownerPrefix#${_operations++}';
    var wait = const Duration(milliseconds: 1);
    TomLease? lease;
    while ((lease = await _mutex.acquire(_mutexResource, owner, _mutexTtl)) ==
        null) {
      await Future<void>.delayed(wait);
      if (wait < const Duration(milliseconds: 32)) wait *= 2;
    }
    try {
      _load();
      _changed = false;
      final result = await operation();
      if (_changed) _persist();
      return result;
    } finally {
      _changed = false;
      await _mutex.release(lease!);
    }
  }

  @override
  Future<void> enqueue(TomJobRun run) => _exclusively(() => super.enqueue(run));

  @override
  Future<TomJobRun?> findWindow(
    String jobName,
    DateTime scheduledFor, {
    String? tenant,
  }) => _exclusively(
    () => super.findWindow(jobName, scheduledFor, tenant: tenant),
  );

  @override
  Future<DateTime?> lastWindow(String jobName) =>
      _exclusively(() => super.lastWindow(jobName));

  @override
  Future<List<TomJobClaim>> claimDue(
    DateTime now,
    String owner, {
    int limit = 16,
    bool Function(TomJobRun run)? accept,
  }) => _exclusively(
    () => super.claimDue(now, owner, limit: limit, accept: accept),
  );

  @override
  Future<void> release(TomJobClaim claim) =>
      _exclusively(() => super.release(claim));

  @override
  Future<void> markStarted(TomJobClaim claim, DateTime now) =>
      _exclusively(() => super.markStarted(claim, now));

  @override
  Future<void> renewClaim(TomJobClaim claim, DateTime now) =>
      _exclusively(() => super.renewClaim(claim, now));

  @override
  Future<bool> saveCheckpoint(
    TomJobClaim claim,
    Map<String, Object?>? checkpoint,
  ) => _exclusively(() => super.saveCheckpoint(claim, checkpoint));

  @override
  Future<void> complete(TomJobClaim claim, DateTime now) =>
      _exclusively(() => super.complete(claim, now));

  @override
  Future<void> fail(
    TomJobClaim claim,
    String error,
    DateTime now, {
    DateTime? retryAt,
  }) => _exclusively(() => super.fail(claim, error, now, retryAt: retryAt));

  @override
  Future<List<TomJobRun>> recoverAbandoned(
    DateTime now,
    Duration leaseTimeout, {
    bool Function(String jobName)? requestsRecovery,
  }) => _exclusively(
    () => super.recoverAbandoned(
      now,
      leaseTimeout,
      requestsRecovery: requestsRecovery,
    ),
  );

  @override
  Future<List<TomJobRun>> all() => _exclusively(() => super.all());

  @override
  Future<List<TomJobBacklog>> backlog(DateTime now) =>
      _exclusively(() => super.backlog(now));

  @override
  Future<int> purgeFinished(DateTime before) =>
      _exclusively(() => super.purgeFinished(before));

  @override
  Future<void> pauseJob(String jobName, DateTime now) =>
      _exclusively(() => super.pauseJob(jobName, now));

  @override
  Future<void> resumeJob(String jobName) =>
      _exclusively(() => super.resumeJob(jobName));

  @override
  Future<Map<String, DateTime>> pausedJobs() =>
      _exclusively(() => super.pausedJobs());

  /// Where damaged content is moved so the next [_persist] cannot overwrite the
  /// evidence of what was lost.
  ///
  /// One fixed name, so a queue that keeps being corrupted does not litter the
  /// directory. The cost is that a second corruption overwrites the first, and
  /// [_recoverFrom] says so explicitly when it happens — silently discarding
  /// the evidence would repeat the very fault this quarantine exists to fix.
  String get _corruptPath => '${file.path}.corrupt';

  /// Reads runs from [file] if it exists, leaving the queue empty when the file
  /// is missing, empty, or not the queue object (a `runs` array beside a `paused` map).
  ///
  /// A record that fails to decode is skipped rather than aborting the load: a
  /// single corrupt entry must not stop the scheduler from starting, since
  /// starting is how the rest of the queue gets drained. For the same reason
  /// this method never throws — the store is built during startup wiring, so a
  /// throw here would turn a past crash into a boot failure, taking down the
  /// process the durable queue exists to protect.
  ///
  /// What it does not do is stay quiet. Every unreadable state degrades to
  /// "carry on with what could be salvaged, and say what was lost", because an
  /// empty queue and a destroyed queue otherwise look identical at startup.
  void _load() {
    if (!file.existsSync()) {
      // Also the reload of a queue another store has not written yet — or one
      // somebody deleted — so what memory held before is not kept.
      replaceAll(const []);
      return;
    }

    final String raw;
    try {
      raw = file.readAsStringSync();
    } catch (error) {
      // Unreadable bytes (permissions, invalid UTF-8) — nothing to salvage.
      _recoverFrom('could not be read ($error)');
      return;
    }
    // A zero-byte file is what a create-then-crash leaves behind. It holds no
    // runs, but nothing was lost either, so it is not corruption.
    if (raw.trim().isEmpty) {
      replaceAll(const []);
      return;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (error) {
      _recoverFrom('could not be read (invalid JSON: $error)');
      return;
    }
    if (decoded is! Map ||
        decoded['runs'] is! List ||
        (decoded['paused'] != null && decoded['paused'] is! Map)) {
      _recoverFrom(
        'could not be read (expected an object with a "runs" array and a '
        '"paused" object, got ${decoded.runtimeType})',
      );
      return;
    }

    final paused = <String, DateTime>{};
    var skipped = 0;
    for (final MapEntry(:key, :value)
        in (decoded['paused'] as Map? ?? {}).entries) {
      final since = value is String ? DateTime.tryParse(value) : null;
      if (key is String && since != null) {
        paused[key] = since;
      } else {
        skipped++;
      }
    }

    final runs = <TomJobRun>[];
    for (final entry in decoded['runs'] as List) {
      if (entry is! Map) {
        skipped++;
        continue;
      }
      try {
        runs.add(TomJobRun.fromJson(Map<String, Object?>.from(entry)));
      } catch (_) {
        skipped++;
      }
    }
    replaceAll(runs, paused);
    if (skipped > 0) {
      // Partial corruption presents as a shorter queue, which reads exactly
      // like a queue that had been drained. Count what was dropped.
      _recoverFrom(
        'contained $skipped unreadable ${skipped == 1 ? 'entry' : 'entries'} '
        'which were dropped (${runs.length} runs recovered)',
      );
    }
  }

  /// Reports the loss described by [detail], moves the damaged file aside to
  /// [_corruptPath], and writes whatever was salvaged back to [file].
  ///
  /// Called only after the salvaged runs are already in the queue, since the
  /// rewrite persists exactly what [snapshotSync] holds.
  void _recoverFrom(String detail) {
    // Checked before the rename, which overwrites without complaint.
    final replaced = File(_corruptPath).existsSync();
    String outcome;
    try {
      // rename, not delete: the unreadable content is the only surviving record
      // of what was queued, and it is worth more than the disk space.
      file.renameSync(_corruptPath);
      outcome = 'its previous content was moved to $_corruptPath';
      if (replaced) {
        outcome = '$outcome, replacing the evidence of an earlier corruption';
      }
    } catch (error) {
      // Say why. "Could not be moved aside" on its own leaves the reader unable
      // to tell a permissions problem from a full disk.
      outcome = 'its previous content could not be moved aside ($error)';
    }
    try {
      _persist();
    } catch (error) {
      outcome =
          '$outcome, and the salvaged runs could not be written back ($error)';
    }
    _report('Job queue file ${file.path} $detail; $outcome');
  }

  /// Logs [message] as an error — the channel an operator actually watches.
  ///
  /// Never throws. The store is constructed during startup wiring, and a broken
  /// log output must not be what stops the scheduler from starting: reporting a
  /// recoverable loss cannot be allowed to become an unrecoverable one.
  ///
  /// `tomLog` already guards the sink it writes to, so the catch below is not
  /// what makes the common case safe. It is here because "loading never throws"
  /// is this store's own contract, and resting that on another package's
  /// internal `try` would make a refactor there a boot failure here.
  void _report(String message) {
    try {
      // Collapsed to one line: a decoder's complaint carries the offending text
      // and its caret on separate lines, and an error split over four lines is
      // one a reader cannot grep for.
      tomLog.error(message.replaceAll(RegExp(r'\s+'), ' ').trim());
    } catch (_) {
      // Nothing left to report to.
    }
  }

  /// Writes the current queue to [file], creating parent directories as needed
  /// and flushing so the bytes reach disk before returning.
  ///
  /// The write is atomic — see [tomWriteFileAtomically]. It has to be: the
  /// queue is rewritten whole on every mutation, and [_load] can do nothing
  /// with a truncated queue but discard it. An overwrite interrupted by a kill
  /// or a full disk would therefore not lose *a* run, it would lose the entire
  /// durable queue, silently, at the next start.
  void _persist() {
    final encoded = jsonEncode({
      'runs': [for (final run in snapshotSync()) run.toJson()],
      'paused': {
        for (final MapEntry(:key, :value) in pausedSync().entries)
          key: value.toIso8601String(),
      },
    });
    tomWriteFileAtomically(file, encoded);
  }
}
