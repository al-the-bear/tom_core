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

  /// Whether the transaction's effects are currently reversed.
  ///
  /// The one piece of state that says which way this transaction is applied.
  /// [undoAll] and [rollback] set it, because both run every entry's `undo`;
  /// [redoAll] clears it, because it runs every entry's `redo` and puts the
  /// effects back. It is therefore not a latch but a direction, and each of the
  /// two operations refuses when the transaction is already the way it would
  /// leave it.
  ///
  /// Separate from [_rolledBack], which answers a different question — *was
  /// this transaction abandoned before commit* — and is what [record] refuses
  /// on.
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
  /// The action runs inside the context's frame — see
  /// [TomActionContext.runInScope] — so anything it reaches that reads
  /// `TomScope.current` sees where the invocation is happening rather than
  /// whatever zone the dispatcher stood in.
  ///
  /// Throws if the transaction is already committed or rolled back, via
  /// [record].
  void run<TContext extends TomActionContext, TUndo extends TomActionUndo>(
    TomAction<TContext, TUndo> action,
    TContext context,
  ) {
    final undoState = context.runInScope(() => action.execute(context, this));
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
  /// Leaves the transaction in the same state [undoAll] does — [isUndone] — so
  /// a rolled-back transaction is one [redoAll] would accept. In practice it
  /// never reaches one: a rolled-back transaction is abandoned before commit
  /// and so is never pushed onto a history.
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
  /// Reverse order because the entries are recorded in execution order and a
  /// later step may depend on an earlier one; [redoAll] goes forward for the
  /// same reason.
  ///
  /// Throws [StateError] when the transaction is already undone — applying the
  /// same undos a second time would repeat them, which is invisible for an undo
  /// that assigns a previous value and a duplicated row for one that restores a
  /// deleted record. The check runs before any entry is touched, so a refused
  /// call changes nothing. [redoAll] is what makes a transaction undoable
  /// again, by putting its effects back first.
  void undoAll() {
    if (_undone) {
      throw StateError(
        'Transaction "$label" is already undone; undoing it again would '
        'apply the same undos a second time. Only redoAll() — which puts the '
        'effects back — makes it undoable again.',
      );
    }
    _undone = true;
    for (final entry in _entries.reversed) {
      entry.action.undo(entry.undoState);
    }
  }

  /// Re-applies all sub-actions in the order they were originally executed.
  ///
  /// Called by the undo history when redoing a transaction. The forward
  /// counterpart of [undoAll]: it runs each entry's [TomAction.redo] with the
  /// undo state that entry recorded, and marks the transaction applied again,
  /// so it can be undone once more.
  ///
  /// Forward order, because that is the order the steps ran in and a later step
  /// may depend on an earlier one. [undoAll] reverses for the same reason.
  ///
  /// Throws [StateError] when the transaction is not undone — there is nothing
  /// to put back, and clearing the flag would make an already-applied
  /// transaction look freshly applied. Throws too when [isRedoable] is false,
  /// naming the action that does not implement redo: silently running no-op
  /// redos would report a re-application that did not happen and would leave
  /// the transaction undoable again, which is exactly the corruption the two
  /// methods exist to prevent. The check runs before any entry is touched.
  void redoAll() {
    if (!_undone) {
      throw StateError(
        'Transaction "$label" is not undone; there is nothing to re-apply.',
      );
    }
    final missing = _entries
        .where((e) => !e.action.isRedoable)
        .map((e) => e.action.actionId)
        .toSet();
    if (missing.isNotEmpty) {
      throw StateError(
        'Transaction "$label" cannot be redone: '
        '${missing.join(', ')} ${missing.length == 1 ? 'does' : 'do'} not '
        'declare isRedoable. Override TomAction.redo and isRedoable to make '
        'the action re-applicable. TomUndoHistory.canRedo reports false for '
        'this transaction, so a button bound to TomRedoAction stays disabled.',
      );
    }
    _undone = false;
    for (final entry in _entries) {
      entry.action.redo(entry.undoState);
    }
  }

  /// Whether this transaction has any recorded entries.
  bool get hasEntries => _entries.isNotEmpty;

  /// Whether this transaction has been committed.
  bool get isCommitted => _committed;

  /// Whether this transaction's effects are currently reversed.
  ///
  /// True between an [undoAll] (or a [rollback]) and the [redoAll] that puts
  /// the effects back. A transaction in this state cannot be undone again, and
  /// is the only state [redoAll] accepts.
  bool get isUndone => _undone;

  /// Whether every recorded action can re-apply itself.
  ///
  /// False for an empty transaction, and false as soon as one entry's action
  /// leaves [TomAction.isRedoable] at its default. This is what
  /// [TomUndoHistory.canRedo] consults, so a Redo button is enabled only when
  /// pressing it would do something.
  bool get isRedoable =>
      _entries.isNotEmpty && _entries.every((e) => e.action.isRedoable);

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
