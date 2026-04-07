import 'tom_action.dart';

/// Groups sub-actions into an atomic unit for undo purposes.
///
/// When multiple actions execute as part of a single user gesture,
/// wrap them in a transaction so undo reverses all of them:
///
/// ```dart
/// final tx = TomActionTransaction(label: 'Move items');
/// for (final item in selectedItems) {
///   moveAction.execute(MoveContext(item: item, target: folder), tx);
/// }
/// tx.commit();  // Records all undo states as one entry
/// ```
class TomActionTransaction {
  /// Human-readable label for the undo history.
  final String label;

  /// Whether this transaction has been committed.
  bool _committed = false;

  /// Whether this transaction has been rolled back.
  bool _rolledBack = false;

  /// Recorded undo entries from sub-actions.
  final List<_UndoEntry> _entries = [];

  TomActionTransaction({required this.label});

  /// Records an undo entry for a sub-action.
  ///
  /// Called automatically by the action trigger mechanism.
  void record<TUndo extends TomActionUndo>(
    TomAction action,
    TUndo undoState,
  ) {
    if (_committed) {
      throw StateError('Cannot record into a committed transaction');
    }
    if (_rolledBack) {
      throw StateError('Cannot record into a rolled-back transaction');
    }
    _entries.add(_UndoEntry(action: action, undoState: undoState));
  }

  /// Marks this transaction as committed.
  ///
  /// After commit, no more entries can be recorded.
  void commit() {
    _committed = true;
  }

  /// Rolls back all recorded sub-actions in reverse order.
  void rollback() {
    if (_rolledBack) return;
    _rolledBack = true;
    for (final entry in _entries.reversed) {
      entry.action.undo(entry.undoState);
    }
  }

  /// Undoes all sub-actions in reverse order.
  ///
  /// This is called by the undo history when undoing a transaction.
  void undoAll() {
    for (final entry in _entries.reversed) {
      entry.action.undo(entry.undoState);
    }
  }

  /// Whether this transaction has any recorded entries.
  bool get hasEntries => _entries.isNotEmpty;

  /// Whether this transaction has been committed.
  bool get isCommitted => _committed;

  /// Number of recorded sub-actions.
  int get entryCount => _entries.length;

  @override
  String toString() => 'TomActionTransaction($label, entries: ${_entries.length})';
}

class _UndoEntry {
  final TomAction action;
  final dynamic undoState;

  _UndoEntry({required this.action, required this.undoState});
}
