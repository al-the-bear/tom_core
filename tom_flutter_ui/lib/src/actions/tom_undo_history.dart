import 'package:tom_forge_core/tom_forge_undo.dart';

import 'tom_action.dart';
import 'tom_action_context.dart';
import 'tom_action_transaction.dart';

/// Application-level undo/redo history.
///
/// A [ForgeUndoStack] of [TomActionTransaction]s: a transaction is undone (or
/// redone) first and moved between the stacks second, so a transaction whose
/// undo throws stays where it was and the history is unchanged.
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
/// Redo is real: [redo] re-applies the transaction by running each action's
/// [TomAction.redo], and [canRedo] is false unless every action in the
/// transaction on top of the redo stack declares [TomAction.isRedoable] — so a
/// button bound to [TomRedoAction] is enabled only when pressing it would do
/// something. See [TomAction.redo] for what an action implements.
class TomUndoHistory {
  /// Maximum number of transactions to keep.
  final int maxSize;

  final ForgeUndoStack<TomActionTransaction> _stack;

  /// Optional callback invoked when the undo/redo state changes.
  void Function()? onChanged;

  TomUndoHistory({this.maxSize = 100, this.onChanged})
    : _stack = ForgeUndoStack(maxEntries: maxSize);

  /// Pushes a committed transaction onto the undo stack.
  ///
  /// Clears the redo stack (new action invalidates redo history), and drops
  /// the oldest transactions beyond [maxSize].
  void push(TomActionTransaction tx) {
    if (!tx.isCommitted) {
      throw StateError('Cannot push an uncommitted transaction');
    }
    if (!tx.hasEntries) return;
    _stack.push(tx);
    onChanged?.call();
  }

  /// Whether there are transactions to undo.
  bool get canUndo => _stack.canUndo;

  /// Whether the next transaction can actually be redone.
  ///
  /// Not merely *is the redo stack non-empty*: the transaction on top must also
  /// report [TomActionTransaction.isRedoable], which it does only when every
  /// action it recorded declares [TomAction.isRedoable]. Redo is per-action
  /// opt-in, so a history can hold undone transactions that nothing can put
  /// back — and a Redo button that says so is worth more than one that enables
  /// itself and then does nothing.
  bool get canRedo => _stack.nextRedo?.isRedoable ?? false;

  /// Undoes the most recent transaction.
  ///
  /// The transaction is undone *before* the stacks move, so a refusal leaves
  /// the history exactly as it was. [TomActionTransaction.undoAll] throws when
  /// a transaction is already undone, and popping first would have left that
  /// failure with a transaction on neither stack. [redo] mirrors the ordering.
  void undo() {
    if (_stack.undo((tx) => tx.undoAll()) != null) onChanged?.call();
  }

  /// Re-applies the most recently undone transaction and moves it back onto the
  /// undo stack.
  ///
  /// Runs each recorded action's [TomAction.redo] in the order the steps
  /// originally executed, then restores the stack position, so the transaction
  /// can be undone again.
  ///
  /// It is not `execute` that runs. [TomActionTransaction] stores
  /// `(action, undoState)` pairs and never the `TContext` an action ran with —
  /// contexts are built per invocation by a `contextBuilder` and are not
  /// guaranteed valid later — so the history has no argument to re-execute
  /// with. [TomAction.redo] takes the argument the history *does* hold, which
  /// is why redo is a hook on the action beside `undo` rather than a replay of
  /// the original call.
  ///
  /// Redo is per-action opt-in, and this does nothing when [canRedo] is false —
  /// which includes a top transaction whose actions do not implement redo. A
  /// caller that reaches [TomActionTransaction.redoAll] directly in that state
  /// gets a [StateError] naming the action that is missing it.
  void redo() {
    if (!canRedo) return;
    _stack.redo((tx) => tx.redoAll());
    onChanged?.call();
  }

  /// Clears all undo/redo history.
  void clear() {
    _stack.clear();
    onChanged?.call();
  }

  /// The label of the next undo-able transaction.
  String? get undoLabel => _stack.nextUndo?.label;

  /// The label of the next redo-able transaction.
  ///
  /// Null when [canRedo] is false, which includes a top transaction that is on
  /// the redo stack but cannot be re-applied — there is no label to offer for
  /// an action a button will not perform.
  String? get redoLabel => canRedo ? _stack.nextRedo!.label : null;

  /// Number of transactions in the undo stack.
  int get undoCount => _stack.undoCount;

  /// Number of transactions in the redo stack.
  ///
  /// Counts what has been undone, not what can be redone — an undone
  /// transaction stays here whether or not its actions implement redo. Use
  /// [canRedo] to drive a button.
  int get redoCount => _stack.redoCount;
}

// =============================================================================
// Coordinator actions for undo/redo
// =============================================================================

/// Action that undoes the most recent transaction in the undo history.
///
/// Gates on [TomUndoHistory.canUndo].
class TomUndoAction extends TomSimpleAction<TomUndoRedoContext> {
  final TomUndoHistory history;

  TomUndoAction({required super.controller, required this.history})
    : super(actionId: 'undo');

  @override
  bool canExecute(TomUndoRedoContext context) => history.canUndo;

  @override
  void executeSimple(TomUndoRedoContext context, TomActionTransaction tx) {
    history.undo();
  }
}

/// Action that drives [TomUndoHistory.redo].
///
/// Gates on [TomUndoHistory.canRedo], which accounts for whether the next
/// transaction's actions implement [TomAction.redo] — so a toolbar button bound
/// to this is disabled both when the redo stack is empty and when what is on it
/// cannot be put back.
class TomRedoAction extends TomSimpleAction<TomUndoRedoContext> {
  final TomUndoHistory history;

  TomRedoAction({required super.controller, required this.history})
    : super(actionId: 'redo');

  @override
  bool canExecute(TomUndoRedoContext context) => history.canRedo;

  @override
  void executeSimple(TomUndoRedoContext context, TomActionTransaction tx) {
    history.redo();
  }
}

/// Context for undo/redo coordinator actions.
class TomUndoRedoContext extends TomActionContext {
  const TomUndoRedoContext();
}
