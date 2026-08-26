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

  /// Whether [execute] would run at least one step.
  ///
  /// This mirrors [execute] exactly, which is what makes it safe to gate a
  /// button on: a step counts only if neither its guard nor its own action
  /// blocks it, and when [stopOnBlockedStep] is set the run abandons
  /// everything after the first blocked step, so only the first step is
  /// reachable at all.
  ///
  /// [context] is ignored — each step supplies its own via
  /// [TomCompositeStep.contextBuilder], which is therefore called here as
  /// well as in [execute].
  @override
  bool canExecute(TomActionContext context) {
    if (stopOnBlockedStep) {
      return steps.isNotEmpty && _contextIfRunnable(steps.first) != null;
    }
    return steps.any((step) => _contextIfRunnable(step) != null);
  }

  /// The context [step] would run with, or `null` if the step is blocked.
  ///
  /// This is the single definition of *blocked* — a guard returning false, or
  /// the step's own action refusing the context it would be given. Both
  /// [canExecute] and [execute] route through it so the two cannot disagree
  /// about which steps run.
  TomActionContext? _contextIfRunnable(TomCompositeStep step) {
    if (step.guard != null && !step.guard!()) return null;
    final stepContext = step.contextBuilder();
    return step.action.canExecute(stepContext) ? stepContext : null;
  }

  @override
  TomActionUndo? execute(TomActionContext context, TomActionTransaction tx) {
    for (final step in steps) {
      final stepContext = _contextIfRunnable(step);
      if (stepContext == null) {
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
  ///
  /// Called once per evaluation, by [TomCompositeAction.canExecute] as well as
  /// by [TomCompositeAction.execute] — so dispatching through a
  /// `TomActionTrigger`, which checks before it runs, calls it twice. Build a
  /// context here; do not mutate anything.
  final TContext Function() contextBuilder;

  /// Optional guard — returns true if this step should execute.
  ///
  /// Consulted before [contextBuilder], and likewise on both the check and the
  /// run, so it should be a cheap predicate.
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

  /// Builds the context for [first]. Called by [canExecute] as well as by
  /// [execute], so it must build a context without mutating anything.
  final TCtx1 Function() firstContextBuilder;
  final bool Function()? firstGuard;

  final TomAction<TCtx2, TomActionUndo> second;

  /// Builds the context for [second]. Called by [canExecute] as well as by
  /// [execute], so it must build a context without mutating anything.
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

  /// Whether [execute] would run either half.
  ///
  /// A half runs when its guard passes *and* its own action accepts the
  /// context it would be given. The two halves are independent — neither can
  /// block the other — so one being runnable is enough.
  ///
  /// [context] is ignored; each half builds its own, so the context builders
  /// are called here as well as in [execute].
  @override
  bool canExecute(TomActionContext context) =>
      _firstContextIfRunnable() != null || _secondContextIfRunnable() != null;

  /// The context [first] would run with, or `null` if its guard blocks it or
  /// the action itself refuses. Shared with [execute] so the two agree.
  TCtx1? _firstContextIfRunnable() {
    if (firstGuard != null && !firstGuard!()) return null;
    final ctx = firstContextBuilder();
    return first.canExecute(ctx) ? ctx : null;
  }

  /// The context [second] would run with, or `null` if it is blocked.
  TCtx2? _secondContextIfRunnable() {
    if (secondGuard != null && !secondGuard!()) return null;
    final ctx = secondContextBuilder();
    return second.canExecute(ctx) ? ctx : null;
  }

  @override
  TomActionUndo? execute(TomActionContext context, TomActionTransaction tx) {
    final ctx1 = _firstContextIfRunnable();
    if (ctx1 != null) {
      final undo1 = first.execute(ctx1, tx);
      if (undo1 != null && first.isUndoable) {
        tx.record(first, undo1);
      }
    }

    final ctx2 = _secondContextIfRunnable();
    if (ctx2 != null) {
      final undo2 = second.execute(ctx2, tx);
      if (undo2 != null && second.isUndoable) {
        tx.record(second, undo2);
      }
    }

    return null;
  }
}
