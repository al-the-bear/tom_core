import 'tom_action.dart';
import 'tom_action_context.dart';
import 'tom_action_controller.dart';
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

  /// Redoes the most recently undone transaction.
  ///
  /// Note: Redo re-executes by undoing the undo — the transaction's
  /// entries are replayed. For complex redo scenarios, actions should
  /// implement their own redo logic.
  void redo() {
    if (!canRedo) return;
    final tx = _redoStack.removeLast();
    // Re-push to undo stack (redo = "do it again")
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
    required TomActionController controller,
    required this.history,
  }) : super(actionId: 'undo', controller: controller);

  @override
  bool canExecute(TomUndoRedoContext context) => history.canUndo;

  @override
  void executeSimple(TomUndoRedoContext context, TomActionTransaction tx) {
    history.undo();
  }
}

/// Action that redoes the most recently undone transaction.
class TomRedoAction extends TomSimpleAction<TomUndoRedoContext> {
  final TomUndoHistory history;

  TomRedoAction({
    required TomActionController controller,
    required this.history,
  }) : super(actionId: 'redo', controller: controller);

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
