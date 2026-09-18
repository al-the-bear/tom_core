import 'tom_action.dart';
import 'tom_action_context.dart';

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

  /// Whether the recorded undos have already been applied.
  ///
  /// Set by both [rollback] and [undoAll], because both run every entry's
  /// `undo`. Separate from [_rolledBack], which answers a different question —
  /// *was this transaction abandoned before commit* — and is what [record]
  /// refuses on.
  ///
  /// Nothing clears it. A transaction's entries hold `(action, undoState)`
  /// pairs and applying them is the only thing that can be done with them; what
  /// would legitimately make them applicable again is re-executing forward,
  /// which [TomUndoHistory.redo] does not do. When it does, clearing this is
  /// part of re-executing.
  bool _undone = false;

  /// Recorded undo entries from sub-actions.
  final List<_UndoEntry> _entries = [];

  TomActionTransaction({required this.label});

  /// Records an undo entry for a sub-action.
  ///
  /// Called automatically by the action trigger mechanism.
  void record<TUndo extends TomActionUndo>(TomAction action, TUndo undoState) {
    if (_committed) {
      throw StateError('Cannot record into a committed transaction');
    }
    if (_rolledBack) {
      throw StateError('Cannot record into a rolled-back transaction');
    }
    _entries.add(_UndoEntry(action: action, undoState: undoState));
  }

  /// Runs [action] against [context] inside this transaction, recording its
  /// undo state when there is one to record.
  ///
  /// This is the one place that pairs *executing* an action with *recording*
  /// it: an action contributes an undo entry only when it returned a state
  /// **and** declares itself [TomAction.isUndoable]. Every caller that runs a
  /// sub-action into a transaction — `TomActionTrigger` and
  /// `TomCompositeAction` — goes through here, so the rule cannot drift
  /// between them.
  ///
  /// Throws if the transaction is already committed or rolled back, via
  /// [record].
  void run<TContext extends TomActionContext, TUndo extends TomActionUndo>(
    TomAction<TContext, TUndo> action,
    TContext context,
  ) {
    final undoState = action.execute(context, this);
    if (undoState != null && action.isUndoable) {
      record(action, undoState);
    }
  }

  /// Marks this transaction as committed.
  ///
  /// After commit, no more entries can be recorded.
  void commit() {
    _committed = true;
  }

  /// Rolls back all recorded sub-actions in reverse order.
  ///
  /// A second call is a silent no-op, unlike [undoAll]'s. The asymmetry is
  /// deliberate: rollback is the failure path — it runs from error handling
  /// that may itself be reached more than once — so arriving twice is an
  /// ordinary consequence of something else going wrong, and throwing there
  /// would replace the original failure with this one.
  void rollback() {
    if (_undone) return;
    _rolledBack = true;
    _undone = true;
    for (final entry in _entries.reversed) {
      entry.action.undo(entry.undoState);
    }
  }

  /// Undoes all sub-actions in reverse order.
  ///
  /// Called by the undo history when undoing a transaction.
  ///
  /// **Once.** A second call throws [StateError] rather than applying the same
  /// undos again, and the check runs before any entry is touched, so a refused
  /// call changes nothing.
  ///
  /// The sequence that reaches it is `undo(); redo(); undo();`.
  /// [TomUndoHistory.redo] moves a transaction back onto the undo stack without
  /// re-executing anything, so the second `undo()` asks for the same undos a
  /// second time with no intervening execution. Against an idempotent undo —
  /// `counter.value = previous` — that is harmless, which is why it went
  /// unnoticed; against the module's own documented example, a `DeleteOrderUndo`
  /// that restores a deleted order, it inserts the order twice.
  ///
  /// Throwing rather than returning silently is the point. A silent second
  /// undo is indistinguishable from a working one at the call site, and the
  /// corruption surfaces later as data nobody can account for. This fails at
  /// the call that is wrong, and says which sequence produced it.
  void undoAll() {
    if (_undone) {
      throw StateError(
        'Transaction "$label" has already been undone. This is the '
        '`undo(); redo(); undo();` sequence: TomUndoHistory.redo restores a '
        "transaction's stack position without re-executing it, so a second "
        'undo would apply the same undos again — harmless for an idempotent '
        'undo, and duplicated work for any other. Push a fresh transaction, '
        'or implement forward re-execution in the action.',
      );
    }
    _undone = true;
    for (final entry in _entries.reversed) {
      entry.action.undo(entry.undoState);
    }
  }

  /// Whether this transaction has any recorded entries.
  bool get hasEntries => _entries.isNotEmpty;

  /// Whether this transaction has been committed.
  bool get isCommitted => _committed;

  /// Whether the recorded undos have been applied, by [undoAll] or [rollback].
  ///
  /// A transaction in this state cannot be undone again — see [undoAll].
  bool get isUndone => _undone;

  /// Number of recorded sub-actions.
  int get entryCount => _entries.length;

  @override
  String toString() =>
      'TomActionTransaction($label, entries: ${_entries.length})';
}

class _UndoEntry {
  final TomAction action;
  final dynamic undoState;

  _UndoEntry({required this.action, required this.undoState});
}
