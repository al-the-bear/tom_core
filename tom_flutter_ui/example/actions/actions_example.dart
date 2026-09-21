/// Executable quick start for the `actions/` module of `tom_flutter_ui`.
///
/// The shapes you write first, without a widget tree: a controller owning
/// typed, undoable actions; direct execution inside a transaction; the
/// `TomActionTrigger` → `TomUndoHistory` wiring; undo and redo; `canExecute`
/// gating; and a guarded `TomCompositeAction`.
///
/// Scope frames, authorization, resource resolution, the undo/redo coordinator
/// actions and the direct transaction API are in the companion
/// `actions_advanced_example.dart`, which reuses the domain declared here.
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

  // -------------------------------------------------------------------------
  // Assertions
  // -------------------------------------------------------------------------
  assert(controller.actions.length == 3); // increment, reset, composite
  assert(controller.canonicalPrefix == 'counter');
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
}

void main() => run();
