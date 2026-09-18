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
///       guard: () => form.isDirty,
///     ),
///     TomCompositeStep(
///       action: closeAction,
///       contextBuilder: () => CloseContext(...),
///     ),
///   ],
/// );
/// ```
///
/// The guard above asks `isDirty` rather than `isValid` because `isValid`
/// means "validation has run and passed" — a form the user never touched is
/// pristine, and pristine is not success, so an `isValid` guard would block
/// the save step on a perfectly valid form. Guard on "is there anything to
/// do" and let the step's own action reject bad data.
///
/// Two steps is the everyday case — *save-and-close*, *validate-and-submit* —
/// and it needs nothing beyond this class. Steps may take **different context
/// types**: [TomCompositeStep]'s type parameter is covariant, so one list
/// holds a `TomCompositeStep<CtxA>` beside a `TomCompositeStep<CtxB>`, each
/// pairing its own action with its own builder. Where the two steps are
/// genuinely *independent* — neither should block the other — pass
/// `stopOnBlockedStep: false`.
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
    // Each step is gated in its own context's frame, the same one
    // [TomActionTransaction.run] will execute it in.
    return stepContext.runInScope(() => step.action.canExecute(stepContext))
        ? stepContext
        : null;
  }

  @override
  TomActionUndo? execute(TomActionContext context, TomActionTransaction tx) {
    for (final step in steps) {
      final stepContext = _contextIfRunnable(step);
      if (stepContext == null) {
        if (stopOnBlockedStep) break;
        continue;
      }

      tx.run(step.action, stepContext);
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
