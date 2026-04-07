import 'package:flutter/widgets.dart';

import 'tom_action.dart';
import 'tom_action_context.dart';
import 'tom_action_transaction.dart';
import 'tom_undo_history.dart';

/// Connects a [TomAction] to a widget's callback (e.g., onPressed).
///
/// The trigger handles:
/// 1. Checking [canExecute] before running
/// 2. Creating a [TomActionTransaction] if needed
/// 3. Recording undo state into the [TomUndoHistory]
/// 4. Executing the action with the provided context
///
/// Usage with a button:
/// ```dart
/// TomElevatedButton(
///   tomId: 'save',
///   authorizer: saveAction.authorizer,
///   onPressed: TomActionTrigger(
///     action: saveAction,
///     contextBuilder: () => OrderActionContext(
///       selectedOrder: order,
///       orderRepo: repo,
///     ),
///   ).trigger,
/// )
/// ```
class TomActionTrigger<TContext extends TomActionContext,
    TUndo extends TomActionUndo> {
  /// The action to trigger.
  final TomAction<TContext, TUndo> action;

  /// Builds the context for action execution.
  final TContext Function() contextBuilder;

  /// Optional undo history for recording undo state.
  ///
  /// When set, committed transactions are pushed onto this history.
  /// When null, undo state is discarded.
  final TomUndoHistory? undoHistory;

  /// Optional callback invoked after successful execution.
  final VoidCallback? onExecuted;

  /// Optional callback invoked when [canExecute] returns false.
  final VoidCallback? onCannotExecute;

  TomActionTrigger({
    required this.action,
    required this.contextBuilder,
    this.undoHistory,
    this.onExecuted,
    this.onCannotExecute,
  });

  /// The trigger callback suitable for `onPressed`, `onTap`, etc.
  void trigger() {
    final context = contextBuilder();

    if (!action.canExecute(context)) {
      onCannotExecute?.call();
      return;
    }

    final tx = TomActionTransaction(label: action.label);
    final undoState = action.execute(context, tx);

    if (undoState != null && action.isUndoable) {
      tx.record(action, undoState);
    }

    tx.commit();

    if (tx.hasEntries && undoHistory != null) {
      undoHistory!.push(tx);
    }

    onExecuted?.call();
  }

  /// Creates a VoidCallback that triggers this action.
  VoidCallback get callback => trigger;
}
