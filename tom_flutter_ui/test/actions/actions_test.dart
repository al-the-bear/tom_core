import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../example/actions/actions_example.dart' as example;

// ---------------------------------------------------------------------------
// Test domain
// ---------------------------------------------------------------------------

class Counter {
  int value = 0;
}

class CounterContext extends TomActionContext {
  final Counter counter;
  CounterContext(this.counter);
}

class IncrementUndo implements TomActionUndo {
  final Counter counter;
  final int previous;
  IncrementUndo(this.counter, this.previous);
}

class IncrementAction extends TomAction<CounterContext, IncrementUndo> {
  final int step;
  IncrementAction({required super.controller, this.step = 1, String id = 'increment'})
      : super(actionId: id);

  @override
  IncrementUndo execute(CounterContext context, TomActionTransaction tx) {
    final previous = context.counter.value;
    context.counter.value += step;
    return IncrementUndo(context.counter, previous);
  }

  @override
  bool get isUndoable => true;

  @override
  void undo(IncrementUndo undoState) =>
      undoState.counter.value = undoState.previous;
}

class ResetAction extends TomSimpleAction<CounterContext> {
  ResetAction({required super.controller}) : super(actionId: 'reset');

  @override
  bool canExecute(CounterContext context) => context.counter.value > 0;

  @override
  void executeSimple(CounterContext context, TomActionTransaction tx) =>
      context.counter.value = 0;
}

/// Increment action attached to an authorization group, used to exercise the
/// `effectiveAuthState` group-mode branch (§58b).
class _GroupedIncrement extends TomAction<CounterContext, IncrementUndo> {
  _GroupedIncrement({
    required super.controller,
    required String id,
    required TomAuthorizationGroup group,
  }) : super(actionId: id, tomGroup: group);

  @override
  IncrementUndo execute(CounterContext context, TomActionTransaction tx) {
    final previous = context.counter.value;
    context.counter.value += 1;
    return IncrementUndo(context.counter, previous);
  }
}

/// Map-backed authorization adapter keyed on resource path.
class _PathAuthAdapter implements TomAuthorizationAdapter {
  _PathAuthAdapter(this.rules);
  final Map<String, TomAuthState> rules;

  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

void main() {
  group('actions example', () {
    test('runs end to end with its assertions', () {
      expect(example.run, returnsNormally);
    });
  });

  group('TomActionController', () {
    test('registers actions and finds them by id', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final reset = ResetAction(controller: controller);
      expect(controller.actions, [inc, reset]);
      expect(controller.findAction('increment'), inc);
      expect(controller.findAction('reset'), reset);
      expect(controller.findAction('missing'), isNull);
    });

    test('canonicalPrefix is the controller id', () {
      final controller = TomActionController(controllerId: 'orderMgmt');
      expect(controller.canonicalPrefix, 'orderMgmt');
    });

    test('actions list is unmodifiable', () {
      final controller = TomActionController(controllerId: 'c');
      IncrementAction(controller: controller);
      expect(() => controller.actions.add(IncrementAction(controller: controller)),
          throwsUnsupportedError);
    });
  });

  group('TomAction', () {
    final controller = TomActionController(controllerId: 'counter');

    test('canonicalPath joins controller id and action id', () {
      final inc = IncrementAction(controller: controller);
      expect(inc.canonicalPath, 'counter.increment');
      expect(inc.tomId, 'increment');
    });

    test('label falls back to actionId when no resource', () {
      final inc = IncrementAction(controller: controller, id: 'labelless');
      expect(inc.label, 'labelless');
      expect(inc.tooltip, isNull);
      expect(inc.iconName, isNull);
    });

    test('default canExecute is true and isUndoable default is false', () {
      final reset = ResetAction(controller: controller);
      expect(reset.isUndoable, isFalse);
      expect(reset.canExecute(CounterContext(Counter()..value = 1)), isTrue);
    });
  });

  group('TomSimpleAction', () {
    test('execute returns null and runs executeSimple', () {
      final controller = TomActionController(controllerId: 'c');
      final reset = ResetAction(controller: controller);
      final counter = Counter()..value = 5;
      final undo = reset.execute(
          CounterContext(counter), TomActionTransaction(label: 'reset'));
      expect(undo, isNull);
      expect(counter.value, 0);
    });
  });

  group('TomActionTransaction', () {
    TomActionTransaction freshTx() => TomActionTransaction(label: 'tx');

    test('records, commits and reports state', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final counter = Counter();
      final tx = freshTx();
      expect(tx.hasEntries, isFalse);
      final undo = inc.execute(CounterContext(counter), tx);
      tx.record(inc, undo);
      expect(tx.entryCount, 1);
      expect(tx.hasEntries, isTrue);
      tx.commit();
      expect(tx.isCommitted, isTrue);
    });

    test('recording after commit throws', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final tx = freshTx()..commit();
      expect(() => tx.record(inc, IncrementUndo(Counter(), 0)),
          throwsStateError);
    });

    test('rollback reverses recorded sub-actions', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final counter = Counter();
      final tx = freshTx();
      final undo = inc.execute(CounterContext(counter), tx);
      tx.record(inc, undo);
      expect(counter.value, 1);
      tx.rollback();
      expect(counter.value, 0);
    });

    test('undoAll reverses entries in reverse order', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final counter = Counter();
      final tx = freshTx();
      for (var i = 0; i < 3; i++) {
        final undo = inc.execute(CounterContext(counter), tx);
        tx.record(inc, undo);
      }
      expect(counter.value, 3);
      tx.commit();
      tx.undoAll();
      expect(counter.value, 0);
    });
  });

  group('TomUndoHistory', () {
    TomActionTransaction committedTx(IncrementAction inc, Counter counter) {
      final tx = TomActionTransaction(label: 'inc');
      final undo = inc.execute(CounterContext(counter), tx);
      tx.record(inc, undo);
      tx.commit();
      return tx;
    }

    test('push rejects uncommitted and empty transactions', () {
      final history = TomUndoHistory();
      final uncommitted = TomActionTransaction(label: 'x');
      expect(() => history.push(uncommitted), throwsStateError);

      final emptyCommitted = TomActionTransaction(label: 'empty')..commit();
      history.push(emptyCommitted);
      expect(history.canUndo, isFalse);
    });

    test('push/undo/redo move transactions across stacks', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final counter = Counter();
      final history = TomUndoHistory();

      history.push(committedTx(inc, counter)); // value 1
      history.push(committedTx(inc, counter)); // value 2
      expect(history.undoCount, 2);
      expect(history.canUndo, isTrue);

      history.undo();
      expect(counter.value, 1);
      expect(history.canRedo, isTrue);
      expect(history.redoLabel, 'inc');

      history.redo();
      // redo restores the stack position only, value is NOT replayed.
      expect(counter.value, 1);
      expect(history.undoCount, 2);
    });

    test('redo restores the stack position and notifies, replaying nothing',
        () {
      var changes = 0;
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final counter = Counter();
      final history = TomUndoHistory(onChanged: () => changes++);

      history.push(committedTx(inc, counter)); // value 1
      history.undo();
      expect(counter.value, 0, reason: 'undo reverses the increment');

      final changesBeforeRedo = changes;
      history.redo();

      // The stack position is restored in full...
      expect(history.canUndo, isTrue);
      expect(history.undoCount, 1);
      expect(history.undoLabel, 'inc');
      expect(history.canRedo, isFalse);
      // ...listeners are told...
      expect(changes, changesBeforeRedo + 1);
      // ...but the action is not run forward again. The transaction holds the
      // undo state, never the context execute would need, so there is nothing
      // to replay. See TomUndoHistory.redo.
      expect(counter.value, 0);
    });

    test('push clears the redo stack', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final counter = Counter();
      final history = TomUndoHistory();
      history.push(committedTx(inc, counter));
      history.undo();
      expect(history.canRedo, isTrue);
      history.push(committedTx(inc, counter));
      expect(history.canRedo, isFalse);
    });

    test('trims to maxSize, keeping the most recent', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final counter = Counter();
      final history = TomUndoHistory(maxSize: 2);
      history.push(committedTx(inc, counter));
      history.push(committedTx(inc, counter));
      history.push(committedTx(inc, counter));
      expect(history.undoCount, 2);
    });

    test('clear empties both stacks and fires onChanged', () {
      var changes = 0;
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final counter = Counter();
      final history = TomUndoHistory(onChanged: () => changes++);
      history.push(committedTx(inc, counter));
      history.clear();
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
      expect(changes, greaterThanOrEqualTo(2));
    });
  });

  group('TomActionTrigger', () {
    test('executes, records undo and fires onExecuted', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final counter = Counter();
      final history = TomUndoHistory();
      var executed = false;
      TomActionTrigger<CounterContext, IncrementUndo>(
        action: inc,
        contextBuilder: () => CounterContext(counter),
        undoHistory: history,
        onExecuted: () => executed = true,
      ).trigger();
      expect(counter.value, 1);
      expect(history.undoCount, 1);
      expect(executed, isTrue);
    });

    test('fires onCannotExecute and does nothing when blocked', () {
      final controller = TomActionController(controllerId: 'c');
      final reset = ResetAction(controller: controller); // needs value > 0
      final counter = Counter(); // value 0 -> cannot execute
      var blocked = false;
      var executed = false;
      TomActionTrigger<CounterContext, TomActionUndo>(
        action: reset,
        contextBuilder: () => CounterContext(counter),
        onCannotExecute: () => blocked = true,
        onExecuted: () => executed = true,
      ).trigger();
      expect(blocked, isTrue);
      expect(executed, isFalse);
      expect(counter.value, 0);
    });

    test('a TomSimpleAction runs but contributes nothing to the history', () {
      final controller = TomActionController(controllerId: 'c');
      final reset = ResetAction(controller: controller);
      final counter = Counter()..value = 5; // > 0, so canExecute passes
      final history = TomUndoHistory();
      var executed = false;
      TomActionTrigger<CounterContext, TomActionUndo>(
        action: reset,
        contextBuilder: () => CounterContext(counter),
        undoHistory: history,
        onExecuted: () => executed = true,
      ).trigger();

      // The action really ran...
      expect(counter.value, 0);
      expect(executed, isTrue);
      // ...but TomSimpleAction returns null undo state, so the trigger records
      // nothing, the transaction stays empty, and push() is never reached.
      expect(history.canUndo, isFalse);
      expect(history.undoCount, 0);
    });

    test('callback getter is the trigger function', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final counter = Counter();
      final t = TomActionTrigger<CounterContext, IncrementUndo>(
        action: inc,
        contextBuilder: () => CounterContext(counter),
      );
      t.callback();
      expect(counter.value, 1);
    });
  });

  group('TomCompositeAction', () {
    TomCompositeStep<CounterContext> step(
      TomAction<CounterContext, TomActionUndo> action,
      Counter counter, {
      bool Function()? guard,
    }) =>
        TomCompositeStep<CounterContext>(
          action: action,
          contextBuilder: () => CounterContext(counter),
          guard: guard,
        );

    test('runs all passing steps and records undo into the transaction', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final counter = Counter();
      final composite = TomCompositeAction(
        actionId: 'twice',
        controller: controller,
        steps: [step(inc, counter), step(inc, counter)],
      );
      final tx = TomActionTransaction(label: 'composite');
      composite.execute(CounterContext(counter), tx);
      expect(counter.value, 2);
      expect(tx.entryCount, 2);
    });

    test('a guard that fails stops the run', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final counter = Counter();
      final composite = TomCompositeAction(
        actionId: 'gated',
        controller: controller,
        steps: [
          step(inc, counter, guard: () => false),
          step(inc, counter),
        ],
      );
      composite.execute(
          CounterContext(counter), TomActionTransaction(label: 'x'));
      expect(counter.value, 0);
    });

    test('without the flag, a failed guard skips only its own step', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final counter = Counter();
      final composite = TomCompositeAction(
        actionId: 'skip',
        controller: controller,
        stopOnBlockedStep: false,
        steps: [
          step(inc, counter, guard: () => false),
          step(inc, counter),
        ],
      );
      composite.execute(
          CounterContext(counter), TomActionTransaction(label: 'x'));
      expect(counter.value, 1);
    });

    test('a step whose action refuses canExecute stops the run, with no guard',
        () {
      final controller = TomActionController(controllerId: 'c');
      final reset = ResetAction(controller: controller);
      final inc = IncrementAction(controller: controller);
      final counter = Counter(); // 0, so reset.canExecute is false
      final composite = TomCompositeAction(
        actionId: 'refused',
        controller: controller,
        // Note: no guard on either step. The stop is caused by the
        // sub-action's own canExecute, not by a guard.
        steps: [step(reset, counter), step(inc, counter)],
      );
      composite.execute(
          CounterContext(counter), TomActionTransaction(label: 'x'));
      expect(counter.value, 0, reason: 'step two never ran');
    });

    test('without the flag, a canExecute refusal skips only its own step', () {
      final controller = TomActionController(controllerId: 'c');
      final reset = ResetAction(controller: controller);
      final inc = IncrementAction(controller: controller);
      final counter = Counter(); // 0, so reset.canExecute is false
      final composite = TomCompositeAction(
        actionId: 'refusedSkip',
        controller: controller,
        stopOnBlockedStep: false,
        steps: [step(reset, counter), step(inc, counter)],
      );
      composite.execute(
          CounterContext(counter), TomActionTransaction(label: 'x'));
      expect(counter.value, 1, reason: 'step two still ran');
    });

    test('canExecute is true when at least one guard passes', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final counter = Counter();
      final composite = TomCompositeAction(
        actionId: 'maybe',
        controller: controller,
        steps: [
          step(inc, counter, guard: () => false),
          step(inc, counter, guard: () => true),
        ],
      );
      expect(composite.canExecute(CounterContext(counter)), isTrue);
    });
  });

  // tests §58a: TomDualAction (the two-action convenience specialization) had
  // zero coverage. Pin the OR-of-guards `canExecute`, the ordered
  // execute-and-record, and each guard-skip branch. `first` uses step 1,
  // `second` uses step 10, so the counter value uniquely identifies which ran.
  group('TomDualAction', () {
    TomDualAction<CounterContext, CounterContext> dual(
      Counter counter, {
      bool Function()? firstGuard,
      bool Function()? secondGuard,
    }) {
      final controller = TomActionController(controllerId: 'dual');
      return TomDualAction<CounterContext, CounterContext>(
        actionId: 'firstThenSecond',
        controller: controller,
        first: IncrementAction(controller: controller, step: 1, id: 'first'),
        firstContextBuilder: () => CounterContext(counter),
        firstGuard: firstGuard,
        second: IncrementAction(controller: controller, step: 10, id: 'second'),
        secondContextBuilder: () => CounterContext(counter),
        secondGuard: secondGuard,
      );
    }

    test('runs both actions in order and records both undos', () {
      final counter = Counter();
      final tx = TomActionTransaction(label: 'dual');
      dual(counter).execute(CounterContext(counter), tx);
      expect(counter.value, 11); // 1 + 10
      expect(tx.entryCount, 2);
    });

    test('skips the first action when firstGuard is false', () {
      final counter = Counter();
      final tx = TomActionTransaction(label: 'dual');
      dual(counter, firstGuard: () => false)
          .execute(CounterContext(counter), tx);
      expect(counter.value, 10); // only second
      expect(tx.entryCount, 1);
    });

    test('skips the second action when secondGuard is false', () {
      final counter = Counter();
      final tx = TomActionTransaction(label: 'dual');
      dual(counter, secondGuard: () => false)
          .execute(CounterContext(counter), tx);
      expect(counter.value, 1); // only first
      expect(tx.entryCount, 1);
    });

    test('runs neither and canExecute is false when both guards fail', () {
      final counter = Counter();
      final action = dual(counter, firstGuard: () => false, secondGuard: () => false);
      expect(action.canExecute(CounterContext(counter)), isFalse);
      action.execute(CounterContext(counter), TomActionTransaction(label: 'x'));
      expect(counter.value, 0);
    });

    test('canExecute is true when only one guard passes (OR semantics)', () {
      final counter = Counter();
      expect(
        dual(counter, firstGuard: () => true, secondGuard: () => false)
            .canExecute(CounterContext(counter)),
        isTrue,
      );
      expect(
        dual(counter, firstGuard: () => false, secondGuard: () => true)
            .canExecute(CounterContext(counter)),
        isTrue,
      );
    });
  });

  // tests §58b: TomAction's authorization surface (authState / effectiveAuthState
  // group branch / authorizer) was untested. Drive it through a map-backed
  // adapter keyed on the action's canonicalPath.
  group('TomAction authorization surface', () {
    tearDown(TomAuthorization.reset);

    test('authState resolves from the adapter at canonicalPath', () {
      TomAuthorization.adapter =
          _PathAuthAdapter({'sec.edit': TomAuthState.read});
      final controller = TomActionController(controllerId: 'sec');
      final action = IncrementAction(controller: controller, id: 'edit');
      expect(action.canonicalPath, 'sec.edit');
      expect(action.authState, TomAuthState.read);
    });

    test('effectiveAuthState equals authState without a group', () {
      TomAuthorization.adapter =
          _PathAuthAdapter({'sec.edit': TomAuthState.read});
      final controller = TomActionController(controllerId: 'sec');
      final action = IncrementAction(controller: controller, id: 'edit');
      expect(action.effectiveAuthState, TomAuthState.read);
    });

    test('effectiveAuthState narrows under a controlsWidest group', () {
      TomAuthorization.adapter = _PathAuthAdapter({
        'sec.edit': TomAuthState.full,
        'billing': TomAuthState.disabled,
      });
      final controller = TomActionController(controllerId: 'sec');
      final grouped = _GroupedIncrement(
        controller: controller,
        id: 'edit',
        group: TomAuthorizationGroup('billing',
            mode: AuthGroupMode.controlsWidest),
      );
      // member full narrowed by group disabled → disabled.
      expect(grouped.effectiveAuthState, TomAuthState.disabled);
    });

    test('effectiveAuthState is replaced under a controlsAll group', () {
      TomAuthorization.adapter = _PathAuthAdapter({
        'sec.edit': TomAuthState.full,
        'billing': TomAuthState.read,
      });
      final controller = TomActionController(controllerId: 'sec');
      final grouped = _GroupedIncrement(
        controller: controller,
        id: 'edit',
        group:
            TomAuthorizationGroup('billing', mode: AuthGroupMode.controlsAll),
      );
      // controlsAll → group state replaces member state.
      expect(grouped.effectiveAuthState, TomAuthState.read);
    });

    test('authorizer applies the fromAction disabled pattern', () {
      TomAuthorization.adapter =
          _PathAuthAdapter({'sec.edit': TomAuthState.none});
      final controller = TomActionController(controllerId: 'sec');
      final action = IncrementAction(controller: controller, id: 'edit');
      // action auth none + widget resource full → disabled.
      expect(action.authorizer.effectiveAuth(TomAuthState.full),
          TomAuthState.disabled);
      // widget hidden stays hidden.
      expect(action.authorizer.effectiveAuth(TomAuthState.none),
          TomAuthState.none);
    });
  });

  group('TomUndoAction / TomRedoAction', () {
    test('drive the undo history and gate on its state', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final counter = Counter();
      final history = TomUndoHistory();

      final undoAction = TomUndoAction(controller: controller, history: history);
      final redoAction = TomRedoAction(controller: controller, history: history);
      final undoCtx = TomUndoRedoContext();

      expect(undoAction.canExecute(undoCtx), isFalse);

      // Record one transaction through a trigger.
      TomActionTrigger<CounterContext, IncrementUndo>(
        action: inc,
        contextBuilder: () => CounterContext(counter),
        undoHistory: history,
      ).trigger();
      expect(counter.value, 1);
      expect(undoAction.canExecute(undoCtx), isTrue);

      undoAction.execute(undoCtx, TomActionTransaction(label: 'undo'));
      expect(counter.value, 0);
      expect(redoAction.canExecute(undoCtx), isTrue);
    });
  });
}
