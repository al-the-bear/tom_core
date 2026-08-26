import 'tom_action.dart';
import 'tom_action_context.dart';
import 'tom_action_transaction.dart';

/// Adapter action that executes multiple actions sequentially.
///
/// A step runs unless it is *blocked*. A step is blocked by either of two
/// independent conditions: its optional [TomCompositeStep.guard] returns
/// false, or the step's own action refuses via [TomAction.canExecute]. The
/// two are treated identically, and [stopOnBlockedStep] decides what a
/// blocked step does to the rest of the run.
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

  /// What a blocked step does to the rest of the run: abandon the remaining
  /// steps (true, the default) or skip only that step and carry on (false).
  ///
  /// This governs *both* conditions that block a step — a
  /// [TomCompositeStep.guard] returning false and the step's own action
  /// returning false from [TomAction.canExecute]. A composite with no guards
  /// at all still stops at the first action that refuses.
  final bool stopOnBlockedStep;

  TomCompositeAction({
    required super.actionId,
    required super.controller,
    required this.steps,
    this.stopOnBlockedStep = true,
    super.scope,
    super.tomGroup,
  });

  @override
  bool canExecute(TomActionContext context) {
    // Composite can execute if at least one step can execute
    return steps.any((step) => step.guard == null || step.guard!());
  }

  @override
  TomActionUndo? execute(TomActionContext context, TomActionTransaction tx) {
    for (final step in steps) {
      // Blocked by the step's guard.
      if (step.guard != null && !step.guard!()) {
        if (stopOnBlockedStep) break;
        continue;
      }

      // Blocked by the action itself. Same handling as a failed guard —
      // hence the flag's name is about blocked steps, not about guards.
      final stepContext = step.contextBuilder();
      if (!step.action.canExecute(stepContext)) {
        if (stopOnBlockedStep) break;
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
    super.tomGroup,
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
