import 'tom_action.dart';
import 'tom_action_context.dart';
import 'tom_action_transaction.dart';

/// Adapter action that executes multiple actions sequentially.
///
/// Each sub-action can have an optional guard that determines whether
/// it should actually execute. If a guard returns false, that sub-action
/// is skipped.
///
/// ```dart
/// final saveAndClose = TomCompositeAction(
///   actionId: 'saveAndClose',
///   controller: formController,
///   steps: [
///     TomCompositeStep(
///       action: saveAction,
///       contextBuilder: () => SaveContext(...),
///       guard: () => form.isValid,
///     ),
///     TomCompositeStep(
///       action: closeAction,
///       contextBuilder: () => CloseContext(...),
///     ),
///   ],
/// );
/// ```
class TomCompositeAction extends TomAction<TomActionContext, TomActionUndo> {
  /// The steps to execute in order.
  final List<TomCompositeStep> steps;

  /// Whether to stop at the first failed guard (true) or skip and continue (false).
  final bool stopOnGuardFailure;

  TomCompositeAction({
    required super.actionId,
    required super.controller,
    required this.steps,
    this.stopOnGuardFailure = true,
    super.scope,
    super.authorizationGroup,
  });

  @override
  bool canExecute(TomActionContext context) {
    // Composite can execute if at least one step can execute
    return steps.any((step) => step.guard == null || step.guard!());
  }

  @override
  TomActionUndo? execute(TomActionContext context, TomActionTransaction tx) {
    for (final step in steps) {
      // Check guard
      if (step.guard != null && !step.guard!()) {
        if (stopOnGuardFailure) break;
        continue;
      }

      final stepContext = step.contextBuilder();
      if (!step.action.canExecute(stepContext)) {
        if (stopOnGuardFailure) break;
        continue;
      }

      final undoState = step.action.execute(stepContext, tx);
      if (undoState != null && step.action.isUndoable) {
        tx.record(step.action, undoState);
      }
    }
    return null;
  }
}

/// A single step in a [TomCompositeAction].
class TomCompositeStep<TContext extends TomActionContext> {
  /// The action to execute.
  final TomAction<TContext, TomActionUndo> action;

  /// Builds the context for this step's action.
  final TContext Function() contextBuilder;

  /// Optional guard — returns true if this step should execute.
  final bool Function()? guard;

  TomCompositeStep({
    required this.action,
    required this.contextBuilder,
    this.guard,
  });
}

/// Adapter action that executes two actions sequentially with individual guards.
///
/// Convenience specialization of [TomCompositeAction] for the common
/// two-action case (e.g., save-and-close, validate-and-submit).
class TomDualAction<TCtx1 extends TomActionContext,
    TCtx2 extends TomActionContext> extends TomAction<TomActionContext, TomActionUndo> {
  final TomAction<TCtx1, TomActionUndo> first;
  final TCtx1 Function() firstContextBuilder;
  final bool Function()? firstGuard;

  final TomAction<TCtx2, TomActionUndo> second;
  final TCtx2 Function() secondContextBuilder;
  final bool Function()? secondGuard;

  TomDualAction({
    required super.actionId,
    required super.controller,
    required this.first,
    required this.firstContextBuilder,
    this.firstGuard,
    required this.second,
    required this.secondContextBuilder,
    this.secondGuard,
    super.scope,
    super.authorizationGroup,
  });

  @override
  bool canExecute(TomActionContext context) {
    final firstCan = firstGuard == null || firstGuard!();
    final secondCan = secondGuard == null || secondGuard!();
    return firstCan || secondCan;
  }

  @override
  TomActionUndo? execute(TomActionContext context, TomActionTransaction tx) {
    // Execute first
    if (firstGuard == null || firstGuard!()) {
      final ctx1 = firstContextBuilder();
      if (first.canExecute(ctx1)) {
        final undo1 = first.execute(ctx1, tx);
        if (undo1 != null && first.isUndoable) {
          tx.record(first, undo1);
        }
      }
    }

    // Execute second
    if (secondGuard == null || secondGuard!()) {
      final ctx2 = secondContextBuilder();
      if (second.canExecute(ctx2)) {
        final undo2 = second.execute(ctx2, tx);
        if (undo2 != null && second.isUndoable) {
          tx.record(second, undo2);
        }
      }
    }

    return null;
  }
}
