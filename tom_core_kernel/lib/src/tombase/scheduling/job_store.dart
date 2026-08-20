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

import '../little_things/atomic_file.dart';

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

  /// When the lease was taken, `null` when unclaimed. Compared against the
  /// lease timeout by [TomJobStore.recoverAbandoned].
  DateTime? claimedAt;

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
    this.startedAt,
    this.lastError,
    this.completedAt,
    this.payload,
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
    'startedAt': startedAt?.toIso8601String(),
    'lastError': lastError,
    'completedAt': completedAt?.toIso8601String(),
    'payload': payload,
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
    startedAt: _parseOrNull(map['startedAt']),
    lastError: map['lastError'] as String?,
    completedAt: _parseOrNull(map['completedAt']),
    payload: map['payload'],
  );

  static DateTime? _parseOrNull(Object? value) =>
      value is String ? DateTime.parse(value) : null;

  @override
  String toString() =>
      '$jobName#${scheduledFor.toIso8601String()} '
      '(${state.name}, attempt $attempt)';
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
/// one.** [release], [markStarted], [renewClaim], [complete] and [fail] are all
/// no-ops unless the store still holds the run *and* still holds it as
/// `running`. Each of the five is reached by a caller holding a `TomJobRun` it
/// obtained some time earlier, so each can be handed a run the store has since
/// finished, re-queued, handed to another node via [recoverAbandoned], or
/// dropped entirely via [purgeFinished] — and in every one of those cases the
/// outcome of the attempt this caller is reporting is no longer the run's
/// outcome. Writing it back would either overrule the node that now owns the
/// run or, worse, resurrect a purged row: [purgeFinished] is the only thing
/// bounding the store, and a re-inserted run carries a freshly stamped
/// [TomJobRun.completedAt] that restarts its retention clock, so it survives
/// every subsequent cutoff.
///
/// The rule costs nothing when nothing went wrong — a run this node still owns
/// is `running` by definition — and it is what makes the five safe to call
/// without first re-reading the store.
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

  /// Adds [run] to the queue.
  ///
  /// The caller is responsible for idempotence via [findWindow]; the store
  /// stores what it is given.
  Future<void> enqueue(TomJobRun run);

  /// The run already recorded for [jobName] at [scheduledFor], or `null`.
  ///
  /// This is what makes enqueueing idempotent, and therefore what makes a tick
  /// safe to replay after a crash.
  Future<TomJobRun?> findWindow(String jobName, DateTime scheduledFor);

  /// The latest window ever enqueued for [jobName], or `null` if the job has no
  /// history in this store.
  ///
  /// The scheduler uses `null` to mean "first sight of this job" and anchors on
  /// the present instead of treating all of history as missed.
  Future<DateTime?> lastWindow(String jobName);

  /// Atomically claims up to [limit] runs that are due at [now], marking each
  /// `running` and leasing it to [owner].
  ///
  /// When [accept] is supplied, only runs it approves are claimed; the
  /// scheduler uses it to enforce per-job overlap policy without a second
  /// round-trip.
  Future<List<TomJobRun>> claimDue(
    DateTime now,
    String owner, {
    int limit = 16,
    bool Function(TomJobRun run)? accept,
  });

  /// Returns a claimed [run] to `pending` without charging it an attempt.
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
  /// A no-op unless the store still holds [run] as `running` — a completion
  /// that raced the release must win.
  Future<void> release(TomJobRun run);

  /// Records that [run]'s body actually began executing at [now].
  ///
  /// Called once per attempt, immediately before the body is handed to the
  /// dispatcher, and it is the only thing that distinguishes an interrupted
  /// *execution* from an abandoned *reservation*. Without it every `running` row
  /// looks the same after a node dies, and recovery has to guess.
  ///
  /// A no-op on a run the store no longer holds as `running`: the outcome of a
  /// run this node has lost belongs to whoever took it over. Stamping
  /// `startedAt` onto it would tell recovery that a *different* node's attempt
  /// had begun.
  Future<void> markStarted(TomJobRun run, DateTime now);

  /// Refreshes the lease timestamp on a claimed [run] to [now].
  ///
  /// A long-running attempt must be able to say it is still alive, or
  /// [recoverAbandoned] would hand its work to a second runner while the first
  /// is still going. This is the store half of that heartbeat; the lock half is
  /// `TomLeaseLock.renew`.
  ///
  /// A no-op unless the store still holds [run] as `running` — a heartbeat for
  /// a lease this node no longer owns would keep recovery off a run it has
  /// already reassigned.
  Future<void> renewClaim(TomJobRun run, DateTime now);

  /// Marks [run] succeeded at [now] and releases its lease.
  ///
  /// A no-op unless the store still holds [run] as `running` — see the rule on
  /// [TomJobStore]. Calling it twice therefore records the *first* completion
  /// only; the second does not move [TomJobRun.completedAt] forward, so a
  /// duplicate outcome cannot extend the run's retention.
  Future<void> complete(TomJobRun run, DateTime now);

  /// Records a failed attempt of [run].
  ///
  /// When [retryAt] is non-null the run returns to `pending` with its attempt
  /// count incremented and `runAt` set to [retryAt]; when it is `null` the run
  /// becomes terminally [TomJobRunState.failed].
  ///
  /// A no-op unless the store still holds [run] as `running`, exactly as
  /// [complete] is. The retrying branch has a second reason to check: it
  /// increments the attempt count, and charging a retry to a run that now
  /// belongs to another node would eat a retry budget this caller is no longer
  /// spending.
  Future<void> fail(
    TomJobRun run,
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

  /// Hook for subclasses that mirror the queue somewhere durable. Called after
  /// every mutation, and never during a read.
  void onMutated() {}

  @override
  Future<void> enqueue(TomJobRun run) async {
    _runs[run.id] = run;
    onMutated();
  }

  @override
  Future<TomJobRun?> findWindow(String jobName, DateTime scheduledFor) async {
    for (final run in _runs.values) {
      if (run.jobName == jobName &&
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
  Future<List<TomJobRun>> claimDue(
    DateTime now,
    String owner, {
    int limit = 16,
    bool Function(TomJobRun run)? accept,
  }) async {
    final claimed = <TomJobRun>[];
    // No `await` inside the loop: selecting and stamping happen in one
    // uninterrupted turn of the event loop, which is what makes the claim
    // atomic against a concurrent caller in this isolate.
    for (final run in _runs.values) {
      if (claimed.length >= limit) break;
      if (!run.isDue(now)) continue;
      if (accept != null && !accept(run)) continue;
      run.state = TomJobRunState.running;
      run.claimedBy = owner;
      run.claimedAt = now;
      claimed.add(run);
    }
    if (claimed.isNotEmpty) onMutated();
    return claimed;
  }

  @override
  Future<void> release(TomJobRun run) async {
    // The `running` guard on this and the four transitions below is the rule
    // documented on [TomJobStore]: an outcome records a run, it never creates
    // or overrules one.
    final stored = _runs[run.id];
    if (stored == null || stored.state != TomJobRunState.running) return;
    stored.state = TomJobRunState.pending;
    stored.claimedBy = null;
    stored.claimedAt = null;
    onMutated();
  }

  @override
  Future<void> markStarted(TomJobRun run, DateTime now) async {
    final stored = _runs[run.id];
    if (stored == null || stored.state != TomJobRunState.running) return;
    stored.startedAt = now;
    run.startedAt = now;
    onMutated();
  }

  @override
  Future<void> renewClaim(TomJobRun run, DateTime now) async {
    final stored = _runs[run.id];
    if (stored == null || stored.state != TomJobRunState.running) return;
    stored.claimedAt = now;
    onMutated();
  }

  @override
  Future<void> complete(TomJobRun run, DateTime now) async {
    final stored = _runs[run.id];
    if (stored == null || stored.state != TomJobRunState.running) return;
    stored.state = TomJobRunState.succeeded;
    stored.completedAt = now;
    stored.claimedBy = null;
    stored.claimedAt = null;
    onMutated();
  }

  @override
  Future<void> fail(
    TomJobRun run,
    String error,
    DateTime now, {
    DateTime? retryAt,
  }) async {
    final stored = _runs[run.id];
    if (stored == null || stored.state != TomJobRunState.running) return;
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

  /// Replaces the queue's contents. Used by [TomFileJobStore] when reloading.
  void replaceAll(Iterable<TomJobRun> runs) {
    _runs
      ..clear()
      ..addEntries(runs.map((r) => MapEntry(r.id, r)));
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
/// is rewritten whole each time, and [_load] can only discard an array it
/// cannot parse.
///
/// The queue is small (one record per window, purged once terminal), so
/// rewriting it whole is cheaper than the bookkeeping an append-only journal
/// would need to compact.
class TomFileJobStore extends TomMemoryJobStore {
  /// The file the queue is mirrored to and reloaded from.
  final File file;

  /// Creates a store backed by [path], loading any previously persisted runs.
  TomFileJobStore(String path) : file = File(path) {
    _load();
  }

  @override
  void onMutated() => _persist();

  /// Reads runs from [file] if it exists, leaving the queue empty when the file
  /// is missing, empty, or not a JSON array.
  ///
  /// A record that fails to decode is skipped rather than aborting the load: a
  /// single corrupt entry must not stop the scheduler from starting, since
  /// starting is how the rest of the queue gets drained.
  void _load() {
    if (!file.existsSync()) return;
    final raw = file.readAsStringSync();
    if (raw.trim().isEmpty) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! List) return;
    final runs = <TomJobRun>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      try {
        runs.add(TomJobRun.fromJson(Map<String, Object?>.from(entry)));
      } catch (_) {
        continue;
      }
    }
    replaceAll(runs);
  }

  /// Writes the current queue to [file], creating parent directories as needed
  /// and flushing so the bytes reach disk before returning.
  ///
  /// The write is atomic — see [tomWriteFileAtomically]. It has to be: the
  /// queue is rewritten whole on every mutation, and [_load] can do nothing
  /// with a truncated array but discard it. An overwrite interrupted by a kill
  /// or a full disk would therefore not lose *a* run, it would lose the entire
  /// durable queue, silently, at the next start.
  void _persist() {
    final encoded = jsonEncode(
      snapshotSync().map((run) => run.toJson()).toList(),
    );
    tomWriteFileAtomically(file, encoded);
  }
}
