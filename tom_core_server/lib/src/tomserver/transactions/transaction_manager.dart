import '../little_things/server_exception.dart';

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

abstract class TomTransactionParticipant {
  String getParticipantId();

  Future<bool> startTransaction();
  Future<bool> endTransaction();
  Future<bool> commit();
  Future<void> rollback();
}

class TomTransaction {

  final Map<String, TomTransactionParticipant> _participants = {};
  final bool isReadOnly;

  bool _isRunning = true;
  bool get isRunning => _isRunning;

  TomTransaction._([this.isReadOnly=false]);

  /// you can register multiple times without problems, the participants will be called only once.
  /// Participant are distinguished by their ID. This will call startTransaction() on the participant.
  void registerParticipant(TomTransactionParticipant ttp) async {
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

abstract class TomTransactionManager {

  static TomTransaction? _currentTransaction;

  // create or get transaction, bool tells if it is a new transaction or not
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

  static TomTransaction? getCurrentTransaction() => _currentTransaction;

  static bool get transactional => _currentTransaction != null && _currentTransaction!._isRunning;

}
