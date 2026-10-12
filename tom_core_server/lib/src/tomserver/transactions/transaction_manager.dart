import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';

/// Raised when a transaction operation is attempted in an invalid state — for
/// example registering a participant with a transaction that is no longer
/// running. A [TomServerException], so it flows through the standard server
/// error mapping.
class TomTransactionException extends TomServerException {
  TomTransactionException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// What became of a transaction's **work**.
///
/// The four are distinguished because three of them need different things done
/// about them, and a boolean merged all four into "did something go wrong".
enum TomTransactionOutcome {
  /// Every participant committed. The work is durable.
  committed,

  /// Every participant promised in [TomTransactionParticipant.prepare] and at
  /// least one then failed to commit. Some of the work is durable and some is
  /// not, and no coordinator can repair that — see
  /// [TomTransaction.commitTransaction].
  partiallyCommitted,

  /// The transaction was rolled back and every participant undid its work.
  ///
  /// The ordinary abort: a veto during prepare, or an explicit
  /// [TomTransaction.rollbackTransaction]. Nothing is durable and nothing is
  /// outstanding.
  rolledBack,

  /// The transaction was rolled back and at least one participant could not
  /// undo its work.
  ///
  /// The outcome a caller most needs told, because it is the one that requires
  /// a human: the work was neither committed nor undone.
  rolledBackWithFailures,
}

/// What a transaction's conclusion did, and to whom.
///
/// Returned by [TomTransaction.commitTransaction] and
/// [TomTransaction.rollbackTransaction] in place of a boolean. The boolean
/// could not say which of four things had happened — committed, partially
/// committed, rolled back, rolled back badly — and it merged them further with
/// a fifth, unrelated fact: whether every participant released its
/// per-transaction resources. A caller reading `false` could not tell "your
/// work is gone" from "your work is durable and a connection leaked".
class TomTransactionResult {
  /// Creates a result.
  const TomTransactionResult(
    this.outcome, {
    this.failed = const [],
    this.notReleased = const [],
  });

  /// What became of the work.
  final TomTransactionOutcome outcome;

  /// The participants whose commit or rollback did not do what it said.
  ///
  /// Names rather than a count, because repairing a partial commit or a failed
  /// rollback means going to those resources.
  final List<String> failed;

  /// The participants whose `endTransaction()` did not release.
  ///
  /// A separate list because it is a separate fact: the work may be perfectly
  /// durable and a pooled connection still lost. For a data source that is a
  /// connection that never returns to the pool, and nothing calls back to
  /// release it — the transaction is over.
  final List<String> notReleased;

  /// Whether the work committed. The question most callers are asking.
  bool get isCommitted => outcome == TomTransactionOutcome.committed;

  /// Whether the conclusion left nothing outstanding at all.
  ///
  /// Stronger than [isCommitted]: a transaction whose work committed and whose
  /// connection leaked is committed and not clean.
  bool get isClean => failed.isEmpty && notReleased.isEmpty;

  @override
  String toString() =>
      'TomTransactionResult(${outcome.name}'
      '${failed.isEmpty ? '' : ', failed: ${failed.join(', ')}'}'
      '${notReleased.isEmpty ? '' : ', not released: ${notReleased.join(', ')}'})';
}

/// A resource that can enlist in a [TomTransaction].
///
/// Implemented by `TomDataSource`, so any data source used during a transaction
/// joins it. Participants are keyed by [getParticipantId] — registering the same
/// id twice enlists once.
///
/// ## The lifecycle
///
/// [startTransaction] on enlistment, and then one of two endings. On the happy
/// path the coordinator runs **two phases**: [prepare] on every participant,
/// and — only if all of them answered `true` — [commit] on every participant.
/// On failure, [rollback] on every participant. Either ending is followed by
/// [endTransaction] on every participant, which releases per-transaction
/// resources (a pooled connection, typically) and decides nothing.
///
/// ## What the prepare phase is for
///
/// [prepare] is where a participant does everything that can still fail, and
/// its `false` is the veto. A veto therefore arrives while **nothing has been
/// committed**, so the coordinator can abort by rolling everyone back and the
/// transaction is genuinely atomic across resources — which is the property
/// the phase exists to buy and the reason [commit] is not a veto.
///
/// [commit] runs after the decision. Every participant has already promised it
/// can commit, so a `false` from one of them is not a refusal the coordinator
/// can act on: peers may have committed already, and rolling *them* back would
/// undo work the transaction decided to keep. It is reported, loudly, as a
/// partially committed transaction — the classic in-doubt outcome — and a
/// participant that wants to be able to refuse has to refuse in [prepare].
///
/// A participant with nothing to prepare returns `true` from [prepare] and does
/// its work in [commit]; that is what a one-phase resource like a plain
/// `MariaDbDatasource` does, and it is why enlisting one alongside a
/// two-phase resource weakens the guarantee to "atomic unless the one-phase
/// participant's commit fails". `MariaDbXADatasource` is the two-phase one:
/// [prepare] issues `XA END` + `XA PREPARE` and [commit] issues `XA COMMIT`.
abstract class TomTransactionParticipant {
  /// A stable id naming the **resource** this participant speaks for.
  ///
  /// It identifies the resource, not the object: `MariaDbDatasource` answers
  /// `"MariaDb-<database>@<host>:@<port>"`, so two instances pointing at one
  /// database share it by construction. That is what makes registering the same
  /// participant twice a no-op the caller need not track — and what makes two
  /// *different* objects claiming one id a refusal rather than a silent
  /// collapse; see [TomTransaction.registerParticipant].
  ///
  /// A participant that needs an enlistment of its own returns an id nothing
  /// else answers.
  String getParticipantId();

  /// Begins the participant's part of [transaction]; called once on enlist.
  ///
  /// [transaction] is the one being joined, handed over rather than looked up.
  /// The lookup is the reason: an ambient
  /// `TomTransactionManager.getCurrentTransaction()` asks the participant to
  /// re-derive, from inside a call the coordinator has just made, which
  /// transaction made it — and it answers from whatever zone the call happens
  /// to be running in, which is the case the scoping exists to separate.
  ///
  /// The same transaction is handed to [prepare], [commit], [rollback] and
  /// [endTransaction], so a participant serving several transactions at once —
  /// a pooled data source holds one connection per transaction — knows which
  /// of them each call concludes.
  ///
  /// What a participant reads from it today is
  /// [TomTransaction.isReadOnly]: `MariaDbDatasource` opens
  /// `START TRANSACTION READ ONLY` for one, which is what turns the flag from a
  /// statement of intent into something the server enforces.
  Future<bool> startTransaction(TomTransaction transaction);

  /// Phase one: promises that [commit] will succeed. `false` vetoes.
  ///
  /// Everything that can still fail belongs here, because this is the last
  /// point at which failing is free: the coordinator answers a `false` — or a
  /// throw — by rolling every participant back, and no participant has
  /// committed yet.
  ///
  /// The promise is the point. A participant that returns `true` and then fails
  /// in [commit] has broken the contract the phase exists to enforce, and the
  /// coordinator has no way to repair it.
  ///
  /// A participant with nothing to prepare returns `true`.
  Future<bool> prepare(TomTransaction transaction);

  /// Phase two: makes the work durable.
  ///
  /// Reached only after **every** participant's [prepare] returned `true`, so
  /// the transaction is already decided. A `false` is not a veto — see the
  /// class documentation — it reports that this participant failed to honour
  /// its promise, leaving the transaction partially committed. The coordinator
  /// logs that and commits the remaining participants anyway, because the
  /// alternative is to abandon work peers have already made durable.
  Future<bool> commit(TomTransaction transaction);

  /// Undoes the participant's work when the transaction is rolled back.
  ///
  /// Reachable after a successful [prepare] — that is the ordinary abort, when
  /// a later participant vetoed — and before one, when the veto came earlier.
  /// It is **not** reachable after this participant's [commit].
  ///
  /// Returns whether the work was undone. `false` is the one outcome that
  /// needs a human: the work was neither committed nor rolled back, and the
  /// coordinator reports the transaction as
  /// [TomTransactionOutcome.rolledBackWithFailures] naming this participant.
  /// A participant with nothing to undo returns `true`.
  Future<bool> rollback(TomTransaction transaction);

  /// Releases per-transaction resources after commit or rollback.
  ///
  /// Called on every participant only once *all* of them have committed or
  /// rolled back, so nothing the outcome depends on belongs here: work placed
  /// in this method runs after the decision it would have informed. Returning
  /// `false` reports a failure to release, not a veto — the transaction has
  /// already happened.
  Future<bool> endTransaction(TomTransaction transaction);
}

/// A single unit of work coordinating one or more [TomTransactionParticipant]s.
///
/// Instances are created only by [TomTransactionManager.startTransaction] (the
/// constructor is private). Participants enlist via [registerParticipant] and
/// the work is concluded with [commitTransaction] (commit-all, falling back to
/// rollback if any participant vetoes) or [rollbackTransaction]. A transaction
/// runs once: after it commits or rolls back, [isRunning] is `false` and it can
/// no longer accept participants.
class TomTransaction {
  /// The scope this transaction is the current one of.
  ///
  /// Held by the transaction rather than looked up on conclusion, because
  /// `commitTransaction` may well run in a different zone from the one that
  /// opened the transaction — an `await` inside a handler, a callback scheduled
  /// elsewhere — and clearing "whatever scope the concluding code happens to be
  /// in" would leave the opening scope pointing at a finished transaction while
  /// wiping an unrelated one.
  final _TomTransactionScope _scope;

  final Map<String, TomTransactionParticipant> _participants = {};

  /// Whether this transaction was opened as read-only.
  ///
  /// Handed to every participant through
  /// [TomTransactionParticipant.startTransaction], which is the only path
  /// between the `@TomTransactional(isReadOnly: true)` that declares it and the
  /// resource that can act on it. The coordinator itself enforces nothing — it
  /// has no idea what a write is — so what the flag *means* is decided by each
  /// participant: `MariaDbDatasource` opens `START TRANSACTION READ ONLY`, and
  /// the server refuses the writes from there on; `MariaDbXADatasource` cannot,
  /// because XA has no read-only branch, and says so rather than appearing to
  /// honour it.
  final bool isReadOnly;

  bool _isRunning = true;

  /// Whether the transaction is still open (not yet committed or rolled back).
  bool get isRunning => _isRunning;

  TomTransaction._(this._scope, [this.isReadOnly = false]);

  /// Enlists [ttp] in this transaction, calling its `startTransaction()` once.
  ///
  /// Participants are deduplicated by [TomTransactionParticipant.getParticipantId];
  /// registering an already-enlisted id is a no-op, so callers may register
  /// freely without tracking membership.
  ///
  /// **Enlistment is all or nothing.** A participant is recorded only after its
  /// `startTransaction()` has returned `true`; one that returns `false` or
  /// throws is not enlisted, and either way this method raises a
  /// [TomTransactionException] naming the participant — `…start_failed` for the
  /// refusal, `…start_threw` for the throw, the latter carrying the original as
  /// its `rootException`. So a caller either has a participant in the
  /// transaction or has an exception, and never a transaction holding a
  /// resource that never opened one.
  ///
  /// The two failures are reported alike on purpose. `false` and a throw are
  /// the same event to the coordinator, and the two data sources that can fail
  /// here return `false` — so a contract that only handled the throw would be
  /// documenting the path that does not occur. Leaving the participant enlisted
  /// is what made this worth stating: `commitTransaction` would later commit a
  /// resource with nothing open, which for `MariaDbXADatasource` is
  /// `XA COMMIT null;` against the branch its failed start had already cleared
  /// — a commit-time error naming the wrong operation, arriving exactly when
  /// the coordinator is deciding whether to roll everyone back.
  ///
  /// **An id belongs to one object.** Registering the *same* participant again
  /// is the no-op above. Registering a *different* object under an id that is
  /// already enlisted throws `…duplicate_id` — it is not a re-registration, and
  /// collapsing it to the first is the one failure here that says nothing at
  /// all: the second resource never receives `startTransaction`, `prepare`,
  /// `commit`, `rollback` or `endTransaction`, the caller's `await` completes
  /// normally, and the work issued against it is neither committed with the
  /// transaction nor rolled back with it. The first sign is data that should
  /// have been undone and was not.
  ///
  /// [TomTransactionParticipant.getParticipantId] names a *resource*, so the
  /// collision is not exotic: two `MariaDbDatasource` instances pointing at one
  /// database answer the same id by construction, and they are two connections
  /// with two transactions of their own — which is exactly why one of them has
  /// to be refused rather than quietly dropped.
  ///
  /// Also throws [TomTransactionException] if the transaction is no longer
  /// running.
  Future<void> registerParticipant(TomTransactionParticipant ttp) async {
    if (!_isRunning) {
      throw TomTransactionException(
        "transaction_manager.register_participant.transaction_not_running",
        "Transaction is no longer running.",
      );
    }
    final id = ttp.getParticipantId();
    final enlisted = _participants[id];
    if (enlisted != null) {
      if (identical(enlisted, ttp)) return;
      throw TomTransactionException(
        "transaction_manager.register_participant.duplicate_id",
        "Participant '$id' is already enlisted as a different "
            "${enlisted.runtimeType}; two resources cannot share one "
            "participant id.",
        parameters: {'participant': id},
      );
    }

    final bool started;
    try {
      started = await ttp.startTransaction(this);
    } catch (error, stack) {
      // Deliberately wide: the participant is application code — a driver, a
      // pooled connection, a queue client — and whatever it raises means the
      // same thing here, which is that the resource is not in the transaction.
      // Rewrapping rather than rethrowing gives the caller one type to catch
      // for both failures and names which participant it was, which the
      // original exception has no reason to know.
      throw TomTransactionException(
        "transaction_manager.register_participant.start_threw",
        "Participant '$id' threw while starting its transaction.",
        parameters: {'participant': id},
        rootException: error,
        stack: stack,
      );
    }

    if (!started) {
      throw TomTransactionException(
        "transaction_manager.register_participant.start_failed",
        "Participant '$id' refused to start its transaction.",
        parameters: {'participant': id},
      );
    }

    // Recorded last. Recorded first — which is what this did — enlists a
    // resource whose start has not happened yet, and leaves it enlisted when
    // the start turns out to fail.
    _participants[id] = ttp;
  }

  /// Runs the two-phase commit, then ends every participant; clears the
  /// current transaction.
  ///
  /// Marks the transaction not-running, then:
  ///
  ///  1. **Prepare.** `prepare()` on every participant in registration order.
  ///     A participant that answers `false` — or throws — vetoes, and the whole
  ///     transaction becomes a [rollbackTransaction]. Nothing has been
  ///     committed at that point, which is the property the phase buys.
  ///  2. **Commit.** `commit()` on every participant. The transaction is
  ///     decided by now, so a `false` here is *not* a veto: it is reported as a
  ///     partially committed transaction and the remaining participants are
  ///     committed anyway. Rolling back instead would discard work peers have
  ///     already made durable, which is the failure the prepare phase exists to
  ///     prevent and would reintroduce at the worst moment.
  ///  3. **End.** `endTransaction()` on every participant, and the transaction
  ///     is cleared from its scope.
  ///
  /// Returns a [TomTransactionResult]: what became of the work, and which
  /// participants did not do what they said. A vetoed transaction returns the
  /// rollback's own result, so the answer says `rolledBack` rather than
  /// claiming a commit that did not happen.
  ///
  /// Both loops run to completion rather than stopping at the first failure — a
  /// participant left uncommitted or un-ended has nothing coming back for it,
  /// because the transaction is over.
  ///
  /// And both are **sequential**, which is a decision rather than an accident.
  /// A transaction spanning *n* resources pays *n* round trips per phase, at
  /// the point in a request where the client is waiting; what that buys is that
  /// the order is knowable. A veto's meaning depends on it — which participants
  /// have already been reached when one arrives is answerable only because they
  /// were reached one at a time — and `Future.wait` would make "the ones
  /// already asked" an arbitrary subset. `test/transactions_test.dart` pins it
  /// with participants that suspend inside every hook; see
  /// `doc/transactions.md`, "Sequential by design".
  Future<TomTransactionResult> commitTransaction() async {
    _isRunning = false;
    // The scope is cleared in a `finally` rather than on the way out, so that
    // it is cleared *whatever* leaves this method. Every participant call
    // below is caught, so nothing should escape — but "nothing should" is a
    // property of today's body, and the invariant is not: a transaction that
    // is no longer running must not be the current one. Broken, it makes
    // `getCurrentTransaction()` and `transactional` disagree, hands every
    // later `startTransaction()` in this scope the dead transaction with
    // `isNew == false`, and answers every enlistment on it with
    // `transaction_not_running` — three symptoms, none of which names the
    // exception that caused them. Off the request path the scope is the
    // process-wide fallback, so that state outlives the flow that produced it.
    try {
      // Read from the map's keys rather than by calling `getParticipantId()`
      // again: the key is the id the participant was enlisted under, it cannot
      // throw here, and a participant whose id getter answers differently later
      // would otherwise be reported under a name nothing else knows it by.
      for (final entry in _participants.entries) {
        final bool prepared;
        try {
          prepared = await entry.value.prepare(this);
        } catch (error, stack) {
          // Deliberately wide, and for the same reason `registerParticipant`
          // catches: a participant is a driver or a client, and whatever it
          // raises means the one thing the coordinator can act on — it cannot
          // promise to commit.
          tomLog.error(
            "Participant '${entry.key}' threw while preparing; rolling the "
            "transaction back: $error",
          );
          tomLog.debug('$stack');
          return rollbackTransaction();
        }
        if (!prepared) {
          tomLog.info(
            "Participant '${entry.key}' vetoed the transaction during prepare; "
            "rolling back.",
          );
          return rollbackTransaction();
        }
      }

      // Past this point the transaction is committing. Every participant has
      // promised it can, and a broken promise is reported rather than acted on.
      final broken = <String>[];
      for (final entry in _participants.entries) {
        bool committed;
        try {
          committed = await entry.value.commit(this);
        } catch (error) {
          tomLog.error(
            "Participant '${entry.key}' threw while committing a prepared "
            "transaction: $error",
          );
          committed = false;
        }
        if (!committed) broken.add(entry.key);
      }
      if (broken.isNotEmpty) {
        // The one outcome two-phase commit cannot rule out, and the one an
        // operator has to be able to find: every participant promised, so the
        // ones that are not named here committed, and the transaction is
        // durable in part. Named individually because repairing it means going
        // to those resources.
        tomLog.error(
          "Transaction partially committed: ${broken.length} of "
          "${_participants.length} participants failed to commit after a "
          "successful prepare (${broken.join(', ')}). The remaining "
          "participants are committed and cannot be rolled back.",
        );
      }

      return TomTransactionResult(
        broken.isEmpty
            ? TomTransactionOutcome.committed
            : TomTransactionOutcome.partiallyCommitted,
        failed: broken,
        notReleased: await _endAll(),
      );
    } finally {
      _scope._clear(this);
    }
  }

  /// Calls `endTransaction()` on every participant and names the ones that did
  /// not release.
  ///
  /// Unconditional: stopping at the first failure would leave every
  /// participant behind it un-ended, and nothing calls back later to release
  /// what they hold, because the transaction is over. For a data source that
  /// is a pooled connection that never returns.
  ///
  /// A throw is a failure to release like any other. Letting it escape would
  /// skip the participants behind it and leave the scope still pointing at a
  /// concluded transaction, which is the same leak with a stack trace.
  Future<List<String>> _endAll() async {
    final notReleased = <String>[];
    for (final entry in _participants.entries) {
      bool ended;
      try {
        ended = await entry.value.endTransaction(this);
      } catch (error) {
        tomLog.error(
          "Participant '${entry.key}' threw while releasing its transaction "
          "resources: $error",
        );
        ended = false;
      }
      if (!ended) notReleased.add(entry.key);
    }
    return notReleased;
  }

  /// Rolls back every participant, then ends them; clears the current transaction.
  ///
  /// Marks the transaction not-running, calls `rollback()` on every participant,
  /// then `endTransaction()` on each, and clears the transaction from its
  /// scope.
  ///
  /// A participant that throws while rolling back is logged and the rest are
  /// rolled back anyway: an abort that stopped at the first failure would leave
  /// every participant behind it holding an open transaction, which is strictly
  /// worse than the failure that interrupted it. A throw and a `false` are the
  /// same answer here — this participant did not undo its work — and both put
  /// it in [TomTransactionResult.failed].
  ///
  /// Returns [TomTransactionOutcome.rolledBack] when every participant undid
  /// its work, and [TomTransactionOutcome.rolledBackWithFailures] when one did
  /// not. That distinction is the point of the type: the second is the outcome
  /// requiring a human, because the work was neither committed nor undone, and
  /// a boolean built only from the `endTransaction` calls reported it as
  /// success.
  Future<TomTransactionResult> rollbackTransaction() async {
    _isRunning = false;
    // Cleared in a `finally` for the reason [commitTransaction] gives: the
    // scope must never hold a transaction that is no longer running, and that
    // has to hold however this method leaves.
    try {
      final notUndone = <String>[];
      for (final entry in _participants.entries) {
        bool undone;
        try {
          undone = await entry.value.rollback(this);
        } catch (error) {
          tomLog.error(
            "Participant '${entry.key}' threw while rolling back: $error",
          );
          undone = false;
        }
        if (!undone) notUndone.add(entry.key);
      }
      if (notUndone.isNotEmpty) {
        tomLog.error(
          "Transaction rolled back with failures: ${notUndone.length} of "
          "${_participants.length} participants could not undo their work "
          "(${notUndone.join(', ')}). That work is neither committed nor "
          "rolled back.",
        );
      }
      return TomTransactionResult(
        notUndone.isEmpty
            ? TomTransactionOutcome.rolledBack
            : TomTransactionOutcome.rolledBackWithFailures,
        failed: notUndone,
        notReleased: await _endAll(),
      );
    } finally {
      _scope._clear(this);
    }
  }
}

/// The mutable holder of one flow's current transaction.
///
/// A zone value cannot be reassigned once the zone is forked, so what the zone
/// carries is this cell rather than the transaction itself: forking installs a
/// fresh, empty cell, and everything inside that zone reads and writes *that*
/// cell. Two zones therefore have two independent current transactions, which is
/// the whole point.
class _TomTransactionScope {
  TomTransaction? current;

  /// Clears [transaction] if it is still the current one.
  ///
  /// Guarded by identity because a transaction concludes at a point in time when
  /// the scope may already have moved on — nothing opens a second transaction in
  /// a scope whose first is still running, but a concluded transaction must not
  /// be able to wipe a successor either.
  void _clear(TomTransaction transaction) {
    if (identical(current, transaction)) current = null;
  }
}

/// Ambient access to the current [TomTransaction].
///
/// Holds the current transaction so participants and the endpoint pipeline can
/// join or conclude it without threading a handle through every call. The
/// pipeline opens one with [startTransaction] for a `@TomTransactional` endpoint
/// and commits/rolls it back when the call returns; data sources enlist with the
/// current transaction as they are used. The transaction clears itself from here
/// on commit or rollback.
///
/// **"Current" means current *to this flow*, not to this isolate.** The
/// transaction lives in a [Zone] value, exactly as the request principal does —
/// so two requests interleaving in one isolate have two independent current
/// transactions and neither can enlist in, commit, or roll back the other's
/// work. A scope is established by [runInTransactionScope]; the server's
/// authentication middleware opens one per request, and the endpoint pipeline
/// opens one for a `@TomTransactional` endpoint whose request has none.
///
/// Code running outside any scope — a script, a test, a `main()` — shares one
/// process-wide fallback scope, which is the pre-zone behaviour and is correct
/// for a program with a single flow of work. Anything that runs *concurrent*
/// flows outside the request path (a scheduler running two jobs, a batch tool
/// fanning out) must wrap each flow in [runInTransactionScope] to get the same
/// isolation a request gets for free.
abstract class TomTransactionManager {
  /// The scope used by code that is not inside any [runInTransactionScope].
  ///
  /// Deliberately shared rather than per-call: a single-flow program has exactly
  /// one flow of work, and giving each `startTransaction()` its own scope would
  /// silently break the nesting contract (a nested call returning the enclosing
  /// transaction with `false`) that the pipeline and every existing caller rely
  /// on.
  static final _TomTransactionScope _fallbackScope = _TomTransactionScope();

  static _TomTransactionScope get _scope =>
      (Zone.current[_TomTransactionScope] as _TomTransactionScope?) ??
      _fallbackScope;

  /// Runs [body] with its own current transaction, isolated from every other
  /// flow in this isolate.
  ///
  /// The transaction opened inside [body] — including inside anything it
  /// `await`s — is invisible outside, and a transaction opened outside is
  /// invisible within. Returns whatever [body] returns, so an asynchronous body
  /// is awaited by the caller rather than here.
  ///
  /// This establishes the *scope*; it opens no transaction and concludes none.
  /// Use it where the two are genuinely separate — the server's authentication
  /// middleware opens a scope per request whether or not the endpoint turns out
  /// to be transactional. To open a transaction and have it concluded on both
  /// the normal and the failing path, use [runInTransaction], which is this
  /// plus the `try`/`catch` a caller otherwise has to remember.
  static R runInTransactionScope<R>(R Function() body) => runZoned(
    zoneValues: {_TomTransactionScope: _TomTransactionScope()},
    body,
  );

  /// Runs [body] in a transaction, committing it on a normal return and rolling
  /// it back on a throw.
  ///
  /// ```dart
  /// await TomTransactionManager.runInTransaction((txn) async {
  ///   await repository.save(order);
  ///   await ledger.record(order);
  /// });
  /// ```
  ///
  /// The conclusion is the point. Written by hand the same flow is
  /// [runInTransactionScope], [startTransaction], the work, `commitTransaction`
  /// **and** a `catch` that rolls back and rethrows — and the version without
  /// the last part is shorter, reads correctly, and leaks: the participants
  /// that enlisted are never rolled back, never ended, and their connections
  /// never return to the pool, while the transaction stays current in its scope
  /// until the scope is discarded. Off the request path that scope is the
  /// process-wide fallback, so one throwing body poisons the flow that follows
  /// it. A protocol whose correct use is four lines longer than its natural use
  /// gets used the short way.
  ///
  /// ## What it does
  ///
  ///  * **Joins a transaction that is already running**, passing it to [body]
  ///    and concluding nothing — the caller that opened it owns its conclusion,
  ///    which is the same contract the `isNew` half of [startTransaction]
  ///    states. [isReadOnly] is then ignored, exactly as it is there.
  ///  * Otherwise **establishes a scope if the flow has none** (as a
  ///    transactional endpoint does rather than trusting the chain in front of
  ///    it), opens a transaction, and owns it: `commitTransaction` after [body]
  ///    returns, `rollbackTransaction` if it throws, and the throw is rethrown
  ///    so the caller sees its own failure rather than a transaction error.
  ///
  /// ## When the commit does not succeed
  ///
  /// It throws [TomTransactionException]
  /// (`transaction_manager.run_in_transaction.commit_failed`) when the work is
  /// not durable — the transaction was vetoed and rolled back, rolled back with
  /// failures, or partially committed. The message and `parameters` carry the
  /// [TomTransactionOutcome] and the participants that failed, because handing
  /// back [body]'s return value would be handing back a result for work that
  /// did not happen.
  ///
  /// A participant that failed to **release** is not that. The work committed;
  /// a connection leaked. That is logged at warning level and the body's result
  /// is returned, because throwing would tell a caller its work did not happen
  /// when it did — and for a non-idempotent operation that invites a retry
  /// which applies it twice.
  ///
  /// A caller that needs to decide commit-or-rollback on something other than a
  /// throw drives [startTransaction] and the conclusion directly, reading the
  /// [TomTransactionResult] itself; that form stays documented in
  /// `doc/transactions.md`.
  static Future<R> runInTransaction<R>(
    FutureOr<R> Function(TomTransaction transaction) body, {
    bool isReadOnly = false,
  }) {
    final current = getCurrentTransaction();
    if (current != null && current.isRunning) {
      // Joined rather than nested. Opening a second, isolated transaction here
      // would give this flow two current transactions with no relationship, and
      // work enlisted in the inner one would commit while the outer rolled
      // back.
      return Future.sync(() => body(current));
    }
    return hasTransactionScope
        ? _runOwnedTransaction(body, isReadOnly)
        : runInTransactionScope(() => _runOwnedTransaction(body, isReadOnly));
  }

  /// [runInTransaction]'s owning half: opens the transaction and concludes it.
  static Future<R> _runOwnedTransaction<R>(
    FutureOr<R> Function(TomTransaction transaction) body,
    bool isReadOnly,
  ) async {
    final (transaction, isNew) = startTransaction(isReadOnly);
    if (!isNew) {
      // Unreachable from [runInTransaction], which checks for a running
      // transaction first. Kept because ownership is the contract this method
      // is written against, not an assumption about its caller: concluding a
      // transaction somebody else opened is the one mistake here that no test
      // of the happy path would show.
      return await body(transaction);
    }
    final R result;
    try {
      result = await body(transaction);
    } catch (_) {
      await transaction.rollbackTransaction();
      rethrow;
    }
    final concluded = await transaction.commitTransaction();
    if (!concluded.isCommitted) {
      // The work is not durable — vetoed and rolled back, rolled back badly, or
      // partially committed — so the body's return value would be a result for
      // work that did not happen.
      throw TomTransactionException(
        "transaction_manager.run_in_transaction.commit_failed",
        "The transaction did not commit: ${concluded.outcome.name}"
            "${concluded.failed.isEmpty ? '' : ' (${concluded.failed.join(', ')})'}.",
        parameters: {
          'outcome': concluded.outcome.name,
          'failed': concluded.failed,
        },
      );
    }
    if (concluded.notReleased.isNotEmpty) {
      // Not a failure of the body: the work committed. A leaked resource is
      // still worth a line, and throwing here would tell a caller its work did
      // not happen when it did — which for a non-idempotent operation invites
      // a retry that applies it twice.
      tomLog.warn(
        "The transaction committed, but ${concluded.notReleased.length} "
        "participant(s) did not release: ${concluded.notReleased.join(', ')}.",
      );
    }
    return result;
  }

  /// Whether the current zone carries a transaction scope of its own.
  ///
  /// `false` means [startTransaction] would use the process-wide fallback scope.
  /// Used by the endpoint pipeline to establish a scope for a transactional
  /// endpoint when the middleware chain in front of it did not.
  static bool get hasTransactionScope =>
      Zone.current[_TomTransactionScope] != null;

  /// Returns the current transaction, creating one if none is active.
  ///
  /// The boolean is `true` when a new transaction was created and `false` when
  /// an existing one was returned — letting the caller that actually opened the
  /// transaction be the one responsible for concluding it. [isReadOnly] is only
  /// honoured when a new transaction is created.
  static (TomTransaction, bool) startTransaction([bool isReadOnly = false]) {
    final scope = _scope;
    final existing = scope.current;
    if (existing != null) {
      return (existing, false);
    }
    final transaction = TomTransaction._(scope, isReadOnly);
    scope.current = transaction;
    return (transaction, true);
  }

  /// The current transaction, or `null` if none is active.
  static TomTransaction? getCurrentTransaction() => _scope.current;

  /// Whether a transaction is currently active and still running.
  static bool get transactional {
    final current = _scope.current;
    return current != null && current._isRunning;
  }
}
