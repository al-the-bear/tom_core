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
  /// A stable id used to deduplicate this participant within a transaction.
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
    if (_participants[id] != null) return;

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
  /// Returns whether every phase succeeded. Both loops run to completion rather
  /// than stopping at the first failure — a participant left uncommitted or
  /// un-ended has nothing coming back for it, because the transaction is over.
  Future<bool> commitTransaction() async {
    _isRunning = false;

    for (final p in _participants.values) {
      final bool prepared;
      try {
        prepared = await p.prepare();
      } catch (error, stack) {
        // Deliberately wide, and for the same reason `registerParticipant`
        // catches: a participant is a driver or a client, and whatever it
        // raises means the one thing the coordinator can act on — it cannot
        // promise to commit. Letting it escape would leave the transaction
        // not-running, nobody rolled back and the scope still pointing at it.
        tomLog.error(
          "Participant '${p.getParticipantId()}' threw while preparing; "
          "rolling the transaction back: $error",
        );
        tomLog.debug('$stack');
        return rollbackTransaction();
      }
      if (!prepared) {
        tomLog.info(
          "Participant '${p.getParticipantId()}' vetoed the transaction during "
          "prepare; rolling back.",
        );
        return rollbackTransaction();
      }
    }

    // Past this point the transaction is committing. Every participant has
    // promised it can, and a broken promise is reported rather than acted on.
    bool ok = true;
    final broken = <String>[];
    for (final p in _participants.values) {
      bool committed;
      try {
        committed = await p.commit();
      } catch (error) {
        tomLog.error(
          "Participant '${p.getParticipantId()}' threw while committing a "
          "prepared transaction: $error",
        );
        committed = false;
      }
      if (!committed) broken.add(p.getParticipantId());
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

    ok = await _endAll() && ok;
    _scope._clear(this);
    return ok;
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
    for (final p in _participants.values) {
      bool ended;
      try {
        ended = await p.endTransaction();
      } catch (error) {
        tomLog.error(
          "Participant '${p.getParticipantId()}' threw while releasing its "
          "transaction resources: $error",
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
    for (final p in _participants.values) {
      try {
        await p.rollback();
      } catch (error) {
        tomLog.error(
          "Participant '${p.getParticipantId()}' threw while rolling back: "
          "$error",
        );
      }
    }
    final ok = await _endAll();
    _scope._clear(this);
    return ok;
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
  /// is awaited by the caller rather than here:
  ///
  /// ```dart
  /// await TomTransactionManager.runInTransactionScope(() async {
  ///   final (txn, _) = TomTransactionManager.startTransaction();
  ///   await doWork();
  ///   await txn.commitTransaction();
  /// });
  /// ```
  static R runInTransactionScope<R>(R Function() body) => runZoned(
    zoneValues: {_TomTransactionScope: _TomTransactionScope()},
    body,
  );

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
