import 'dart:async';

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

/// A resource that can enlist in a [TomTransaction] (two-phase style).
///
/// Implemented by `TomDataSource`, so any data source used during a transaction
/// joins it. Participants are keyed by [getParticipantId] — registering the same
/// id twice enlists once. The coordinator drives the lifecycle:
/// [startTransaction] on enlistment, then either [commit] followed by
/// [endTransaction] on success, or [rollback] followed by [endTransaction] on
/// failure. [commit] returns `false` to veto the commit (which turns the whole
/// transaction into a rollback); [endTransaction] releases any per-transaction
/// resources (e.g. returning a connection to the pool).
abstract class TomTransactionParticipant {
  /// A stable id used to deduplicate this participant within a transaction.
  String getParticipantId();

  /// Begins the participant's part of the transaction; called once on enlist.
  Future<bool> startTransaction();

  /// Releases per-transaction resources after commit or rollback.
  Future<bool> endTransaction();

  /// Commits the participant's work; returning `false` vetoes the transaction.
  Future<bool> commit();

  /// Undoes the participant's work when the transaction is rolled back.
  Future<void> rollback();
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

  TomTransaction._(this._scope, [this.isReadOnly=false]);

  /// Enlists [ttp] in this transaction, calling its `startTransaction()` once.
  ///
  /// Participants are deduplicated by [TomTransactionParticipant.getParticipantId];
  /// registering an already-enlisted id is a no-op, so callers may register
  /// freely without tracking membership. The returned future completes once the
  /// participant's `startTransaction()` has run, so callers can `await`
  /// enlistment and observe its result. Throws [TomTransactionException] if the
  /// transaction is no longer running; a failure thrown by `startTransaction()`
  /// surfaces through the returned future.
  Future<void> registerParticipant(TomTransactionParticipant ttp) async {
    if (!_isRunning) {
      throw TomTransactionException(
        "transaction_manager.register_participant.transaction_not_running",
        "Transaction is no longer running.",
      );
    }
    if (_participants[ttp.getParticipantId()] == null) {
      _participants[ttp.getParticipantId()] = ttp;
      await ttp.startTransaction();
    }
  }

  /// Commits every participant, then ends them; clears the current transaction.
  ///
  /// Marks the transaction not-running, then calls `commit()` on each
  /// participant in registration order. If any participant vetoes (returns
  /// `false`), the whole transaction is rolled back via [rollbackTransaction]
  /// instead. On a clean commit, `endTransaction()` is called on every
  /// participant and the transaction is cleared from its scope. Returns
  /// whether the commit (and all end calls) succeeded.
  Future<bool> commitTransaction() async {
    bool ok = true;
    _isRunning = false;
    for (var p in _participants.values) {
      ok = await p.commit();
      if (!ok) {
        return rollbackTransaction();
      }
    }
    for (var p in _participants.values) {
      ok = ok && await p.endTransaction();
    }
    _scope._clear(this);
    return ok;
  }

  /// Rolls back every participant, then ends them; clears the current transaction.
  ///
  /// Marks the transaction not-running, calls `rollback()` on every participant,
  /// then `endTransaction()` on each, and clears the transaction from its
  /// scope. Returns whether all end calls succeeded.
  Future<bool> rollbackTransaction() async {
    _isRunning = false;
    for (var p in _participants.values) {
      await p.rollback();
    }
    bool ok = true;
    for (var p in _participants.values) {
      ok = ok && await p.endTransaction();
    }
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
  static (TomTransaction, bool) startTransaction([bool isReadOnly=false]) {
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
