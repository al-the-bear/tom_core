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

  /// Begins the participant's part of the transaction; called once on enlist.
  Future<bool> startTransaction();

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
  Future<bool> prepare();

  /// Phase two: makes the work durable.
  ///
  /// Reached only after **every** participant's [prepare] returned `true`, so
  /// the transaction is already decided. A `false` is not a veto — see the
  /// class documentation — it reports that this participant failed to honour
  /// its promise, leaving the transaction partially committed. The coordinator
  /// logs that and commits the remaining participants anyway, because the
  /// alternative is to abandon work peers have already made durable.
  Future<bool> commit();

  /// Undoes the participant's work when the transaction is rolled back.
  ///
  /// Reachable after a successful [prepare] — that is the ordinary abort, when
  /// a later participant vetoed — and before one, when the veto came earlier.
  /// It is **not** reachable after this participant's [commit].
  Future<void> rollback();

  /// Releases per-transaction resources after commit or rollback.
  ///
  /// Called on every participant only once *all* of them have committed or
  /// rolled back, so nothing the outcome depends on belongs here: work placed
  /// in this method runs after the decision it would have informed. Returning
  /// `false` reports a failure to release, not a veto — the transaction has
  /// already happened.
  Future<bool> endTransaction();
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

  /// Whether this transaction was opened as read-only (advisory; surfaced to
  /// participants / callers — it does not by itself prevent writes).
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
      started = await ttp.startTransaction();
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
  /// Returns whether the **work committed**, which is what the caller asked.
  /// A vetoed transaction answers `false` however cleanly its rollback ran: the
  /// rollback's own result belongs to [rollbackTransaction], and reporting it
  /// here told a caller its work was durable at the moment it was discarded.
  ///
  /// Both loops run to completion rather than stopping at the first failure — a
  /// participant left uncommitted or un-ended has nothing coming back for it,
  /// because the transaction is over.
  Future<bool> commitTransaction() async {
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
          prepared = await entry.value.prepare();
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
          return _vetoed();
        }
        if (!prepared) {
          tomLog.info(
            "Participant '${entry.key}' vetoed the transaction during prepare; "
            "rolling back.",
          );
          return _vetoed();
        }
      }

      // Past this point the transaction is committing. Every participant has
      // promised it can, and a broken promise is reported rather than acted on.
      bool ok = true;
      final broken = <String>[];
      for (final entry in _participants.entries) {
        bool committed;
        try {
          committed = await entry.value.commit();
        } catch (error) {
          tomLog.error(
            "Participant '${entry.key}' threw while committing a prepared "
            "transaction: $error",
          );
          committed = false;
        }
        if (!committed) broken.add(entry.key);
        ok = ok && committed;
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

      return await _endAll() && ok;
    } finally {
      _scope._clear(this);
    }
  }

  /// Rolls the vetoed transaction back and reports the commit as failed.
  ///
  /// The rollback's own answer — whether every participant released — is not
  /// this method's answer. `commitTransaction` is asked whether the work
  /// committed, and after a veto it did not, however cleanly the rollback ran.
  /// Returning the rollback's `true` told a caller its work was durable at the
  /// exact moment the coordinator had thrown it away.
  Future<bool> _vetoed() async {
    await rollbackTransaction();
    return false;
  }

  /// Calls `endTransaction()` on every participant and reports whether all of
  /// them released.
  ///
  /// Unconditional, and evaluated before it is combined: `ok && await
  /// p.endTransaction()` would short-circuit, so one participant reporting
  /// failure would stop every participant behind it from being ended at all —
  /// and nothing calls back later to release what they hold, because the
  /// transaction is over. For a data source that is a pooled connection that
  /// never returns.
  ///
  /// A throw is a failure to release like any other. Letting it escape would
  /// skip the participants behind it and leave the scope still pointing at a
  /// concluded transaction, which is the same leak with a stack trace.
  Future<bool> _endAll() async {
    bool ok = true;
    for (final entry in _participants.entries) {
      bool ended;
      try {
        ended = await entry.value.endTransaction();
      } catch (error) {
        tomLog.error(
          "Participant '${entry.key}' threw while releasing its transaction "
          "resources: $error",
        );
        ended = false;
      }
      ok = ok && ended;
    }
    return ok;
  }

  /// Rolls back every participant, then ends them; clears the current transaction.
  ///
  /// Marks the transaction not-running, calls `rollback()` on every participant,
  /// then `endTransaction()` on each, and clears the transaction from its
  /// scope. Returns whether all end calls succeeded.
  ///
  /// A participant that throws while rolling back is logged and the rest are
  /// rolled back anyway: an abort that stopped at the first failure would leave
  /// every participant behind it holding an open transaction, which is strictly
  /// worse than the failure that interrupted it.
  Future<bool> rollbackTransaction() async {
    _isRunning = false;
    // Cleared in a `finally` for the reason [commitTransaction] gives: the
    // scope must never hold a transaction that is no longer running, and that
    // has to hold however this method leaves.
    try {
      for (final entry in _participants.entries) {
        try {
          await entry.value.rollback();
        } catch (error) {
          tomLog.error(
            "Participant '${entry.key}' threw while rolling back: $error",
          );
        }
      }
      return await _endAll();
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
  /// (`transaction_manager.run_in_transaction.commit_failed`). A `false` from
  /// [TomTransaction.commitTransaction] is one of three things — the
  /// transaction was vetoed during prepare and rolled back, it was partially
  /// committed, or it committed and a participant failed to release — and the
  /// boolean does not distinguish them. Two of the three mean the work is not
  /// durable and the third is a leaked resource, so none of them is a result to
  /// hand back as though [body] had succeeded. The coordinator's own log does
  /// distinguish them, naming the participant in each case.
  ///
  /// A caller that needs to tell them apart, or to decide commit-or-rollback
  /// itself, drives [startTransaction] and the conclusion directly; that form
  /// stays documented in `doc/transactions.md` for exactly this reason.
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
    if (!await transaction.commitTransaction()) {
      throw TomTransactionException(
        "transaction_manager.run_in_transaction.commit_failed",
        "The transaction did not commit cleanly. It was vetoed and rolled "
            "back, partially committed, or committed with a participant "
            "failing to release — the log names which, and which participant.",
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
