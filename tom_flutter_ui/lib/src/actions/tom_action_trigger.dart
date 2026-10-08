import 'package:flutter/widgets.dart';

import 'tom_action.dart';
import 'tom_action_context.dart';
import 'tom_action_transaction.dart';
import 'tom_undo_history.dart';

/// Connects a [TomAction] to a widget's callback (e.g., onPressed).
///
/// The trigger handles:
/// 1. Refusing an action authorization does not permit ([TomAction.isAuthorized])
/// 2. Checking [TomAction.canExecute] before running
/// 3. Creating a [TomActionTransaction] if needed
/// 4. Recording undo state into the [TomUndoHistory]
/// 5. Executing the action with the provided context
///
/// The authorization check is not a security boundary — the server enforces —
/// and it is not what normally stops an unauthorized action: a button bound to
/// [TomAction.authorizer] is already disabled or hidden. It is here for the
/// paths that do not go through such a button, a keyboard shortcut or a
/// callback holding `trigger` directly, so that an action a user cannot see
/// cannot be run either.
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
class TomActionTrigger<
  TContext extends TomActionContext,
  TUndo extends TomActionUndo
> {
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

  /// Optional callback invoked when the action was **not** run — because
  /// authorization refused it, or because [TomAction.canExecute] did.
  ///
  /// One callback for both, because the caller can tell them apart without
  /// being told: `action.isAuthorized` answers which refusal this was. A second
  /// callback, or a reason parameter, would carry information already in reach.
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
    // Authorization first, and before the context is built: an action the user
    // cannot see must not run whatever canExecute says about it, and a
    // `contextBuilder` is application code — it may read the very data the
    // refusal is about.
    if (!action.isAuthorized) {
      onCannotExecute?.call();
      return;
    }

    final context = contextBuilder();

    if (!action.canExecute(context)) {
      onCannotExecute?.call();
      return;
    }

    final tx = TomActionTransaction(label: action.label);
    tx.run(action, context);
    tx.commit();

    if (tx.hasEntries && undoHistory != null) {
      undoHistory!.push(tx);
    }

    onExecuted?.call();
  }

  /// Creates a VoidCallback that triggers this action.
  VoidCallback get callback => trigger;
}
