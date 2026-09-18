/// Executable example for the `actions/` module of `tom_flutter_ui`.
///
/// Demonstrates the Tom Action system end to end without a widget tree: a
/// controller owning typed, undoable actions; direct execution inside a
/// transaction; the `TomActionTrigger` → `TomUndoHistory` wiring; undo/redo;
/// `canExecute` gating; a guarded `TomCompositeAction`; and the scope frame an
/// action's canonical path is built in.
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
  IncrementAction({required super.controller, this.step = 1})
    : super(actionId: 'increment');

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

  // Example 4: undo reverses the most recent transaction. redo restores the
  // stack position only — TomUndoHistory.redo does NOT re-apply the action's
  // value change, so the counter is unchanged by redo. The transaction records
  // the undo state an action needs to reverse itself, never the context it
  // would need to run forward again; see TomUndoHistory.redo for the full
  // reasoning.
  history.undo();
  final afterUndo = counter.value; // 2 — second trigger reversed
  print('after undo: $afterUndo (canRedo: ${history.canRedo})');
  history.redo();
  print('after redo: ${counter.value} (undo stack: ${history.undoCount})');

  // Because redo re-applied nothing, that transaction's undo states are still
  // the spent ones, so it cannot be undone a second time. Undoing again throws
  // rather than applying the same undos twice — harmless for this action, which
  // assigns a previous value, but a second restore for an undo that puts a
  // deleted row back. A gesture that must be reversible twice is two
  // transactions.
  var secondUndoRefused = false;
  try {
    history.undo();
  } on StateError {
    secondUndoRefused = true;
  }
  final afterRefusedUndo = counter.value; // still 2 — nothing was applied
  print('second undo refused: $secondUndoRefused (value: $afterRefusedUndo)');

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

  // -------------------------------------------------------------------------
  // Assertions
  // -------------------------------------------------------------------------
  assert(controller.actions.length == 3); // increment, reset, composite
  assert(controller.increment.canonicalPath == 'counter.increment');
  assert(controller.findAction('reset') == controller.reset);

  // Manual transaction recorded one undo entry.
  assert(tx.entryCount == 1);
  assert(tx.isCommitted);

  // Value sequence: manual=1, +2 triggers=3, undo reverses second trigger=2,
  // redo restores stack only (no value replay)=2.
  assert(afterUndo == 2);
  assert(history.undoCount == 2); // redo moved the tx back onto the undo stack

  // The undone transaction stays undone across redo, and the refusal left the
  // history and the counter exactly as they were.
  assert(secondUndoRefused);
  assert(afterRefusedUndo == 2);
  assert(history.undoCount == 2);

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
