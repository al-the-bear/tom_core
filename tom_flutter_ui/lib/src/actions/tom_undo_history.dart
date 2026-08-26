import 'tom_action.dart';
import 'tom_action_context.dart';
import 'tom_action_transaction.dart';

/// Application-level undo/redo history.
///
/// Manages a stack of [TomActionTransaction]s for undo/redo support.
///
/// ```dart
/// final undoHistory = TomUndoHistory(maxSize: 50);
///
/// // Actions are pushed via TomActionTrigger automatically
/// // Or manually:
/// undoHistory.push(transaction);
///
/// // Undo/redo
/// if (undoHistory.canUndo) undoHistory.undo();
/// if (undoHistory.canRedo) undoHistory.redo();
/// ```
///
/// The two directions are not symmetric: [undo] reverses the transaction's
/// effects, while [redo] only moves it back onto the undo stack and re-applies
/// nothing. See [redo] for why, and for what an action must do to support a
/// real redo.
class TomUndoHistory {
  /// Maximum number of transactions to keep.
  final int maxSize;

  final List<TomActionTransaction> _undoStack = [];
  final List<TomActionTransaction> _redoStack = [];

  /// Optional callback invoked when the undo/redo state changes.
  void Function()? onChanged;

  TomUndoHistory({this.maxSize = 100, this.onChanged});

  /// Pushes a committed transaction onto the undo stack.
  ///
  /// Clears the redo stack (new action invalidates redo history).
  void push(TomActionTransaction tx) {
    if (!tx.isCommitted) {
      throw StateError('Cannot push an uncommitted transaction');
    }
    if (!tx.hasEntries) return;

    _undoStack.add(tx);
    _redoStack.clear();

    // Trim oldest entries if over max
    while (_undoStack.length > maxSize) {
      _undoStack.removeAt(0);
    }

    onChanged?.call();
  }

  /// Whether there are transactions to undo.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether there are transactions to redo.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Undoes the most recent transaction.
  void undo() {
    if (!canUndo) return;
    final tx = _undoStack.removeLast();
    tx.undoAll();
    _redoStack.add(tx);
    onChanged?.call();
  }

  /// Moves the most recently undone transaction back onto the undo stack.
  ///
  /// **Nothing is re-applied.** This restores the *stack position* only:
  /// [canUndo], [undoCount] and [undoLabel] account for the transaction again
  /// and [onChanged] fires, but no application state changes. Redoing an
  /// increment does not increment anything.
  ///
  /// That follows from what a transaction records, rather than being an
  /// omission here. [TomActionTransaction] stores `(action, undoState)` pairs,
  /// which is exactly what `TomAction.undo(TUndo undoState)` takes — so [undo]
  /// can call `undoAll()`. Going forward again means `TomAction.execute`, whose
  /// signature also takes a `TContext`, and the context an action ran with is
  /// never recorded. The history therefore does not hold the argument a real
  /// redo would need, which is why there is no `redoAll()` for this to call.
  ///
  /// An action that needs true redo implements it itself, executing forward
  /// with a context the application still has, rather than expecting the
  /// history to reconstruct one.
  void redo() {
    if (!canRedo) return;
    final tx = _redoStack.removeLast();
    // Re-push to the undo stack. Note this is the whole operation — the
    // transaction is not touched, so nothing is re-executed.
    _undoStack.add(tx);
    onChanged?.call();
  }

  /// Clears all undo/redo history.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    onChanged?.call();
  }

  /// The label of the next undo-able transaction.
  String? get undoLabel => canUndo ? _undoStack.last.label : null;

  /// The label of the next redo-able transaction.
  String? get redoLabel => canRedo ? _redoStack.last.label : null;

  /// Number of transactions in the undo stack.
  int get undoCount => _undoStack.length;

  /// Number of transactions in the redo stack.
  int get redoCount => _redoStack.length;
}

// =============================================================================
// Coordinator actions for undo/redo
// =============================================================================

/// Action that undoes the most recent transaction in the undo history.
class TomUndoAction extends TomSimpleAction<TomUndoRedoContext> {
  final TomUndoHistory history;

  TomUndoAction({
    required super.controller,
    required this.history,
  }) : super(actionId: 'undo');

  @override
  bool canExecute(TomUndoRedoContext context) => history.canUndo;

  @override
  void executeSimple(TomUndoRedoContext context, TomActionTransaction tx) {
    history.undo();
  }
}

/// Action that drives [TomUndoHistory.redo] — which restores the stack
/// position and re-applies nothing. See that method before binding this to a
/// toolbar button labelled "Redo".
class TomRedoAction extends TomSimpleAction<TomUndoRedoContext> {
  final TomUndoHistory history;

  TomRedoAction({
    required super.controller,
    required this.history,
  }) : super(actionId: 'redo');

  @override
  bool canExecute(TomUndoRedoContext context) => history.canRedo;

  @override
  void executeSimple(TomUndoRedoContext context, TomActionTransaction tx) {
    history.redo();
  }
}

/// Context for undo/redo coordinator actions.
class TomUndoRedoContext extends TomActionContext {
  TomUndoRedoContext({super.scope});
}
