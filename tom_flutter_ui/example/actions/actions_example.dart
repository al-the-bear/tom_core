/// Executable example for the `actions/` module of `tom_flutter_ui`.
///
/// Demonstrates the Tom Action system end to end without a widget tree: a
/// controller owning typed, undoable actions; direct execution inside a
/// transaction; the `TomActionTrigger` → `TomUndoHistory` wiring; undo/redo;
/// `canExecute` gating; a guarded `TomCompositeAction`; the invocation frame a
/// context carries; the authorization group a controller lends its actions;
/// the refusal of an action authorization does not permit; the refusal of a
/// duplicate action id; and the scope frame an action's canonical path is built
/// in.
///
/// Because it imports `package:tom_flutter_ui/tom_flutter_ui.dart` (which pulls
/// in `flutter/material` → `dart:ui`), bare `dart run` cannot execute it. Run
/// `flutter test test/actions/actions_test.dart`, which calls this example and
/// reports its result in the exit code.
library;

// Demonstration example: console output is intentional.
// ignore_for_file: avoid_print

import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// A tiny domain: a counter the actions mutate.
// ---------------------------------------------------------------------------

/// Mutable model the example actions operate on.
class Counter {
  int value = 0;
}

/// Typed inputs for the counter actions.
class CounterContext extends TomActionContext {
  final Counter counter;
  CounterContext(this.counter);
}

/// Undo snapshot for [IncrementAction]: the value before the increment.
class IncrementUndo implements TomActionUndo {
  final Counter counter;
  final int previous;
  IncrementUndo(this.counter, this.previous);
}

/// An undoable action that adds [step] to the counter.
class IncrementAction extends TomAction<CounterContext, IncrementUndo> {
  final int step;
  IncrementAction({
    required super.controller,
    this.step = 1,
    String id = 'increment',
    super.tomGroup,
  }) : super(actionId: id);

  @override
  IncrementUndo execute(CounterContext context, TomActionTransaction tx) {
    final previous = context.counter.value;
    context.counter.value += step;
    return IncrementUndo(context.counter, previous);
  }

  @override
  bool get isUndoable => true;

  @override
  void undo(IncrementUndo undoState) {
    undoState.counter.value = undoState.previous;
  }

  // Redo is a second hook beside undo, declared the same way. The history never
  // records the context `execute` would need, so it re-applies through this
  // instead: the undo state names the target and the action holds the step.
  @override
  bool get isRedoable => true;

  @override
  void redo(IncrementUndo undoState) {
    undoState.counter.value = undoState.previous + step;
  }
}

/// An undoable action that does **not** implement redo — the default.
///
/// Included to show the disabled half of the contract: a history whose next
/// undone transaction was built from one of these reports `canRedo == false`,
/// so a Redo button bound to `TomRedoAction` stays disabled instead of enabling
/// itself and doing nothing when pressed.
class UndoOnlyIncrementAction extends TomAction<CounterContext, IncrementUndo> {
  UndoOnlyIncrementAction({required super.controller})
    : super(actionId: 'undoOnlyIncrement');

  @override
  IncrementUndo execute(CounterContext context, TomActionTransaction tx) {
    final previous = context.counter.value;
    context.counter.value += 1;
    return IncrementUndo(context.counter, previous);
  }

  @override
  bool get isUndoable => true;

  @override
  void undo(IncrementUndo undoState) {
    undoState.counter.value = undoState.previous;
  }
}

/// Reports the scope in force each time it is consulted.
///
/// A context's `scope` affects only the *ambient* frame, so no return value can
/// show it; this reports `TomScope.current` instead, which is what a nested
/// controller or a resource lookup inside the action would have read.
class FrameProbeContext extends TomActionContext {
  final List<String> frames;
  FrameProbeContext({required this.frames, super.scope});
}

class FrameProbeAction extends TomSimpleAction<FrameProbeContext> {
  FrameProbeAction({required super.controller}) : super(actionId: 'frameProbe');

  @override
  bool canExecute(FrameProbeContext context) {
    context.frames.add(TomScope.current.id);
    return true;
  }

  @override
  void executeSimple(FrameProbeContext context, TomActionTransaction tx) {
    context.frames.add(TomScope.current.id);
  }
}

/// Resolves `secured.delete` to hidden and everything else to full.
class _HiddenDeleteAdapter implements TomAuthorizationAdapter {
  @override
  TomAuthState resolveAuth(String path) =>
      path == 'secured.delete' ? TomAuthState.none : TomAuthState.full;
}

/// A non-undoable action that only runs while the counter is positive.
class ResetAction extends TomSimpleAction<CounterContext> {
  ResetAction({required super.controller}) : super(actionId: 'reset');

  @override
  bool canExecute(CounterContext context) => context.counter.value > 0;

  @override
  void executeSimple(CounterContext context, TomActionTransaction tx) {
    context.counter.value = 0;
  }
}

/// Controller owning the counter actions.
///
/// The actions are `late final`, so each is constructed on first read — long
/// after the controller was built, and typically outside whatever scope was
/// installed then. They still land in the controller's frame, because an action
/// with no scope of its own stands where its controller does.
class CounterController extends TomActionController {
  CounterController({super.scope}) : super(controllerId: 'counter');

  late final increment = IncrementAction(controller: this);
  late final reset = ResetAction(controller: this);
}

void run() {
  final controller = CounterController();
  final counter = Counter();
  CounterContext ctx() => CounterContext(counter);

  // Example 1: actions register with their controller and expose canonical
  // paths built from the controller id.
  print('actions: ${controller.actions.length}');
  print('increment path: ${controller.increment.canonicalPath}');
  print('found by id: ${controller.findAction('reset') == controller.reset}');

  // Example 2: run an action inside a transaction. `run` executes it and
  // records its undo state — but only when it returned one *and* the action
  // declares itself undoable. Every dispatch path shares this pairing.
  final tx = TomActionTransaction(label: 'manual increment');
  tx.run(controller.increment, ctx());
  tx.commit();
  print('after manual increment: ${counter.value} (entries: ${tx.entryCount})');

  // Example 3: wire an action through a trigger into an undo history.
  final history = TomUndoHistory();
  final trigger = TomActionTrigger<CounterContext, IncrementUndo>(
    action: controller.increment,
    contextBuilder: ctx,
    undoHistory: history,
  );
  trigger.trigger();
  trigger.trigger();
  print(
    'after two triggers: ${counter.value} (undo stack: ${history.undoCount})',
  );

  // Example 4: undo reverses the most recent transaction; redo re-applies it.
  // Redo runs each recorded action's `redo` with the undo state that entry
  // recorded — not `execute`, because the transaction never keeps the context
  // `execute` would need.
  history.undo();
  final afterUndo = counter.value; // 2 — second trigger reversed
  print('after undo: $afterUndo (canRedo: ${history.canRedo})');
  history.redo();
  final afterRedo = counter.value; // 3 — re-applied
  print('after redo: $afterRedo (undo stack: ${history.undoCount})');

  // ...and the transaction is applied again, so it can be undone again.
  history.undo();
  final afterSecondUndo = counter.value; // 2
  print('after second undo: $afterSecondUndo');
  history.redo();
  final afterSecondRedo = counter.value; // 3 again

  // Example 4b: redo is per-action opt-in. An action that leaves isRedoable at
  // its default can be undone but not put back, and the history says so rather
  // than offering a button that does nothing.
  final undoOnlyHistory = TomUndoHistory();
  final undoOnlyCounter = Counter();
  final undoOnlyTx = TomActionTransaction(label: 'undo-only');
  undoOnlyTx.run(
    // Its own controller, so the demo controller above keeps the three actions
    // it declares.
    UndoOnlyIncrementAction(
      controller: TomActionController(controllerId: 'undoOnly'),
    ),
    CounterContext(undoOnlyCounter),
  );
  undoOnlyTx.commit();
  undoOnlyHistory.push(undoOnlyTx);
  undoOnlyHistory.undo();
  final undoOnlyCanRedo = undoOnlyHistory.canRedo; // false
  print(
    'undo-only: redo stack ${undoOnlyHistory.redoCount}, '
    'canRedo $undoOnlyCanRedo, label ${undoOnlyHistory.redoLabel}',
  );

  // Example 5: canExecute gating — reset only runs while positive.
  final resetCanRun = controller.reset.canExecute(ctx());
  print('reset canExecute (positive): $resetCanRun');
  controller.reset.execute(ctx(), TomActionTransaction(label: 'reset'));
  print(
    'after reset: ${counter.value} '
    '(canExecute now: ${controller.reset.canExecute(ctx())})',
  );

  // Example 6: a guarded composite runs only the steps whose guard passes.
  var gate = false;
  final composite = TomCompositeAction(
    actionId: 'maybeIncrement',
    controller: controller,
    stopOnBlockedStep: false,
    steps: [
      TomCompositeStep<CounterContext>(
        action: controller.increment,
        contextBuilder: ctx,
        guard: () => gate,
      ),
    ],
  );
  composite.execute(ctx(), TomActionTransaction(label: 'composite'));
  final afterGuardedOut = counter.value;
  gate = true;
  composite.execute(ctx(), TomActionTransaction(label: 'composite'));
  print('composite guarded-out=$afterGuardedOut guarded-in=${counter.value}');

  // Example 7: a controller built inside a TomScope namespaces its actions.
  // The scope is captured once, when the controller and its actions are
  // constructed, so the path is the same wherever it is later read from — and
  // an action's authorization group is resolved in that same frame.
  final scoped = TomScope.withScope('checkout', () => CounterController());
  final scopedPath = scoped.increment.canonicalPath;
  print('scoped increment path: $scopedPath');

  // Example 8: the same, with the scope handed over as a value instead of
  // installed on a zone — the shape a builder callback produces.
  final detached = CounterController(scope: TomScopeBase(scopeId: 'checkout'));
  print('detached prefix: ${detached.canonicalPrefix}');

  // Example 9: the *invocation* frame, which is a different scope from the
  // construction one above. A context's `scope` is installed around both the
  // gate and the body, so anything they reach that reads TomScope.current sees
  // where this invocation is happening — while the action's canonical path,
  // fixed at construction, does not move.
  final frames = <String>[];
  final probeController = TomActionController(controllerId: 'probe');
  final probe = FrameProbeAction(controller: probeController);
  TomScope.withScope('ambient', () {
    TomActionTrigger<FrameProbeContext, TomActionUndo>(
      action: probe,
      contextBuilder: () => FrameProbeContext(
        frames: frames,
        scope: TomScopeBase(scopeId: 'invocation'),
      ),
    ).trigger();
  });
  final probePath = probe.canonicalPath;
  print('invocation frames: $frames (action path still $probePath)');

  // Example 10: a group declared once on the controller reaches every action
  // it owns — membership and ceiling both — without being repeated per action.
  // An action that names its own group overrides it.
  final billing = TomAuthorizationGroup('billing');
  final reporting = TomAuthorizationGroup('reporting');
  final grouped = TomActionController(controllerId: 'gsec', tomGroup: billing);
  final inheritsGroup = IncrementAction(controller: grouped, id: 'edit');
  final ownGroup = IncrementAction(
    controller: grouped,
    id: 'report',
    tomGroup: reporting,
  );
  print(
    'inherited: ${inheritsGroup.tomGroup?.groupId}, '
    'own: ${ownGroup.tomGroup?.groupId}, '
    'billing members: ${billing.members.length}',
  );

  // Example 11: the trigger refuses an action authorization does not permit.
  // Normally a button bound to `action.authorizer` is already hidden or
  // disabled, so nothing reaches here; this is for the paths that do not go
  // through a button — a keyboard shortcut, a test, a callback holding
  // `trigger` directly.
  TomAuthorization.adapter = _HiddenDeleteAdapter();
  final secured = TomActionController(controllerId: 'secured');
  final hiddenAction = IncrementAction(controller: secured, id: 'delete');
  final securedCounter = Counter();
  var contextsBuilt = 0;
  var refusals = 0;
  TomActionTrigger<CounterContext, IncrementUndo>(
    action: hiddenAction,
    contextBuilder: () {
      contextsBuilt++;
      return CounterContext(securedCounter);
    },
    onCannotExecute: () => refusals++,
  ).trigger();
  final refusedByAuth = !hiddenAction.isAuthorized;
  print(
    'hidden action: state ${hiddenAction.effectiveAuthState.name}, '
    'ran ${securedCounter.value == 1}, refused $refusals, '
    'contexts built $contextsBuilt',
  );
  TomAuthorization.reset();

  // Example 12: an action id is unique within its controller. A duplicate would
  // share one authorization decision and one set of label/tooltip/icon keys
  // with the action already registered, so it is refused at construction.
  var duplicateRefused = false;
  try {
    IncrementAction(controller: controller, id: 'increment');
  } on StateError {
    duplicateRefused = true;
  }
  // The same id under a different controller is a different canonical path,
  // so there is nothing to collide.
  final elsewhere = TomActionController(controllerId: 'elsewhere');
  final sameIdElsewhere = IncrementAction(controller: elsewhere);
  print(
    'duplicate refused: $duplicateRefused, '
    'same id elsewhere: ${sameIdElsewhere.canonicalPath}',
  );

  // -------------------------------------------------------------------------
  // Assertions
  // -------------------------------------------------------------------------
  // The gate and the body both ran in the context's frame, not the ambient
  // one — and the action's own path is unaffected by where it was invoked.
  assert(frames.length == 2);
  assert(frames.every((frame) => frame == 'invocation'));
  assert(probePath == 'probe.frameProbe');

  // The hidden action did not run, the refusal was reported once, and the
  // context builder — application code — was never called. `onCannotExecute`
  // covers both refusals; `isAuthorized` says which one this was.
  assert(securedCounter.value == 0);
  assert(refusals == 1);
  assert(contextsBuilt == 0);
  assert(refusedByAuth);

  // The duplicate never registered, so the controller still owns three actions
  // and the id resolves to the original.
  assert(duplicateRefused);
  assert(sameIdElsewhere.canonicalPath == 'elsewhere.increment');

  // The controller's group covers the action that named none, and only that
  // one — the overriding action never joins it.
  assert(identical(inheritsGroup.tomGroup, billing));
  assert(identical(ownGroup.tomGroup, reporting));
  assert(billing.members.length == 1);
  assert(billing.members.contains(inheritsGroup));

  assert(controller.actions.length == 3); // increment, reset, composite
  assert(controller.increment.canonicalPath == 'counter.increment');
  assert(controller.findAction('reset') == controller.reset);

  // Manual transaction recorded one undo entry.
  assert(tx.entryCount == 1);
  assert(tx.isCommitted);

  // Value sequence: manual=1, +2 triggers=3, undo reverses the second
  // trigger=2, redo re-applies it=3, undo again=2, redo again=3.
  assert(afterUndo == 2);
  assert(afterRedo == 3);
  assert(afterSecondUndo == 2);
  assert(afterSecondRedo == 3);
  assert(history.undoCount == 2); // redo moved the tx back onto the undo stack

  // An action without a redo hook is undoable but not redoable, and the
  // history reports that rather than offering an inert button.
  assert(!undoOnlyCanRedo);
  assert(undoOnlyHistory.redoCount == 1);
  assert(undoOnlyHistory.redoLabel == null);
  assert(undoOnlyCounter.value == 0);

  // Reset clears to zero and then refuses to run again.
  assert(!controller.reset.canExecute(CounterContext(Counter()..value = 0)));

  // Guarded-out step left the counter unchanged; guarded-in incremented it.
  assert(afterGuardedOut == 0);
  assert(counter.value == 1);

  // A scope reaches the controller prefix and every action path under it —
  // read here, outside the scope, and still 'checkout.counter.increment'.
  assert(scopedPath == 'checkout.counter.increment');
  assert(scoped.canonicalPrefix == 'checkout.counter');
  assert(detached.canonicalPrefix == 'checkout.counter');
  // The unscoped controller above is unchanged: no scope, no prefix.
  assert(controller.canonicalPrefix == 'counter');
}

void main() => run();
