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

  final Map<String, TomTransactionParticipant> _participants = {};

  /// Whether this transaction was opened as read-only (advisory; surfaced to
  /// participants / callers — it does not by itself prevent writes).
  final bool isReadOnly;

  bool _isRunning = true;

  /// Whether the transaction is still open (not yet committed or rolled back).
  bool get isRunning => _isRunning;

  TomTransaction._([this.isReadOnly=false]);

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
  /// participant and the [TomTransactionManager] singleton is cleared. Returns
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
    TomTransactionManager._clearTransaction();
    return ok;
  }

  /// Rolls back every participant, then ends them; clears the current transaction.
  ///
  /// Marks the transaction not-running, calls `rollback()` on every participant,
  /// then `endTransaction()` on each, and clears the [TomTransactionManager]
  /// singleton. Returns whether all end calls succeeded.
  Future<bool> rollbackTransaction() async {
    _isRunning = false;
    for (var p in _participants.values) {
      await p.rollback();
    }
    bool ok = true;
    for (var p in _participants.values) {
      ok = ok && await p.endTransaction();
    }
    TomTransactionManager._clearTransaction();
    return ok;
  }
}

/// Ambient access to the current [TomTransaction].
///
/// Holds a single current transaction (per isolate) so participants and the
/// endpoint pipeline can join or conclude it without threading a handle through
/// every call. The pipeline opens one with [startTransaction] for a
/// `@TomTransactional` endpoint and commits/rolls it back when the call returns;
/// data sources enlist with the current transaction as they are used. The
/// transaction clears itself from here on commit or rollback.
///
/// The current transaction is a single static (not zone-scoped), so this models
/// one active transaction per isolate at a time.
abstract class TomTransactionManager {

  static TomTransaction? _currentTransaction;

  /// Returns the current transaction, creating one if none is active.
  ///
  /// The boolean is `true` when a new transaction was created and `false` when
  /// an existing one was returned — letting the caller that actually opened the
  /// transaction be the one responsible for concluding it. [isReadOnly] is only
  /// honoured when a new transaction is created.
  static (TomTransaction, bool) startTransaction([bool isReadOnly=false]) {
    if (_currentTransaction != null) {
      return (_currentTransaction!, false);
    }
    _currentTransaction = TomTransaction._(isReadOnly);
    return (_currentTransaction!, true);
  }

  static void _clearTransaction() {
    _currentTransaction = null;
  }

  /// The current transaction, or `null` if none is active.
  static TomTransaction? getCurrentTransaction() => _currentTransaction;

  /// Whether a transaction is currently active and still running.
  static bool get transactional => _currentTransaction != null && _currentTransaction!._isRunning;

}
