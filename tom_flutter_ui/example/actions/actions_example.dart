/// Executable example for the `actions/` module of `tom_flutter_ui`.
///
/// Demonstrates the Tom Action system end to end without a widget tree: a
/// controller owning typed, undoable actions; direct execution inside a
/// transaction; the `TomActionTrigger` → `TomUndoHistory` wiring; undo/redo;
/// `canExecute` gating; and a guarded `TomCompositeAction`.
///
/// Because it imports `package:tom_flutter_ui/tom_flutter_ui.dart` (which pulls
/// in `flutter/material` → `dart:ui`), run it under the Flutter toolchain, e.g.
/// `flutter test example/actions/actions_example.dart`, not bare `dart run`.
/// The same scenarios are covered by `test/actions/actions_test.dart`.
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
class CounterController extends TomActionController {
  CounterController() : super(controllerId: 'counter');

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

  // Example 2: direct execution inside a transaction returns undo state.
  final tx = TomActionTransaction(label: 'manual increment');
  final undo = controller.increment.execute(ctx(), tx);
  tx.record(controller.increment, undo);
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
  print('after two triggers: ${counter.value} (undo stack: ${history.undoCount})');

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

  // Example 5: canExecute gating — reset only runs while positive.
  final resetCanRun = controller.reset.canExecute(ctx());
  print('reset canExecute (positive): $resetCanRun');
  controller.reset.execute(ctx(), TomActionTransaction(label: 'reset'));
  print('after reset: ${counter.value} '
      '(canExecute now: ${controller.reset.canExecute(ctx())})');

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

  // Reset clears to zero and then refuses to run again.
  assert(!controller.reset.canExecute(CounterContext(Counter()..value = 0)));

  // Guarded-out step left the counter unchanged; guarded-in incremented it.
  assert(afterGuardedOut == 0);
  assert(counter.value == 1);
}

void main() => run();
