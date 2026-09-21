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
  IncrementAction({
    required super.controller,
    this.step = 1,
    String id = 'increment',
    super.scope,
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
  void undo(IncrementUndo undoState) =>
      undoState.counter.value = undoState.previous;

  @override
  bool get isRedoable => true;

  // The undo state names the target and the action holds the parameter, so the
  // pair is enough to go forward as well as back.
  @override
  void redo(IncrementUndo undoState) =>
      undoState.counter.value = undoState.previous + step;
}

class ResetAction extends TomSimpleAction<CounterContext> {
  ResetAction({required super.controller}) : super(actionId: 'reset');

  @override
  bool canExecute(CounterContext context) => context.counter.value > 0;

  @override
  void executeSimple(CounterContext context, TomActionTransaction tx) =>
      context.counter.value = 0;
}

/// Returns an undo state but leaves [TomAction.isUndoable] at its default
/// `false` — the one shape that distinguishes the two halves of the recording
/// rule in [TomActionTransaction.run].
class UnrecordedIncrementAction
    extends TomAction<CounterContext, IncrementUndo> {
  UnrecordedIncrementAction({required super.controller})
    : super(actionId: 'unrecordedIncrement');

  @override
  IncrementUndo execute(CounterContext context, TomActionTransaction tx) {
    final previous = context.counter.value;
    context.counter.value += 1;
    return IncrementUndo(context.counter, previous);
  }
}

/// An action whose undo is **not** idempotent — it appends rather than assigns.
///
/// [IncrementAction.undo] writes `counter.value = previous`, so running it
/// twice lands on the same value and cannot show a repeated undo. This one can:
/// each `undo` adds the restored row back to the list, which is the shape of
/// the module's own documented `DeleteOrderAction` — `undo` puts the deleted
/// order back. Undo it twice and the order is there twice.
class RestoreRowUndo implements TomActionUndo {
  final List<String> rows;
  final String removed;
  RestoreRowUndo(this.rows, this.removed);
}

class RowContext extends TomActionContext {
  final List<String> rows;
  RowContext(this.rows);
}

class DeleteRowAction extends TomAction<RowContext, RestoreRowUndo> {
  DeleteRowAction({required super.controller}) : super(actionId: 'deleteRow');

  @override
  RestoreRowUndo execute(RowContext context, TomActionTransaction tx) {
    final removed = context.rows.removeLast();
    return RestoreRowUndo(context.rows, removed);
  }

  @override
  bool get isUndoable => true;

  @override
  void undo(RestoreRowUndo undoState) => undoState.rows.add(undoState.removed);

  @override
  bool get isRedoable => true;

  @override
  void redo(RestoreRowUndo undoState) =>
      undoState.rows.remove(undoState.removed);
}

/// Undoable but **not** redoable — it leaves [TomAction.isRedoable] at its
/// default, which is what every action did before redo existed.
///
/// Exists so the disabled half of the contract has a subject: a history holding
/// one of these reports `canRedo == false`, so a button bound to
/// `TomRedoAction` stays disabled rather than enabling itself and doing nothing.
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
  void undo(IncrementUndo undoState) =>
      undoState.counter.value = undoState.previous;
}

/// Appends its step's name to a shared log on every execute, undo and redo, so
/// a test can assert the *order* entries are applied in.
class OrderLogUndo implements TomActionUndo {
  final List<String> log;
  final String name;
  OrderLogUndo(this.log, this.name);
}

class OrderLogContext extends TomActionContext {
  final List<String> log;
  OrderLogContext(this.log);
}

class OrderLogAction extends TomAction<OrderLogContext, OrderLogUndo> {
  final String name;
  OrderLogAction({required super.controller, required this.name})
    : super(actionId: 'log_$name');

  @override
  OrderLogUndo execute(OrderLogContext context, TomActionTransaction tx) {
    context.log.add('do:$name');
    return OrderLogUndo(context.log, name);
  }

  @override
  bool get isUndoable => true;

  @override
  void undo(OrderLogUndo undoState) =>
      undoState.log.add('undo:${undoState.name}');

  @override
  bool get isRedoable => true;

  @override
  void redo(OrderLogUndo undoState) =>
      undoState.log.add('redo:${undoState.name}');
}

/// Records the scope in force at each point it is consulted.
///
/// `TomActionContext.scope` is the only field in the module whose whole effect
/// is on the *ambient* frame, so nothing about a return value can show it. This
/// action reports `TomScope.current` instead, which is what any real consumer —
/// a nested controller, a resource lookup, a widget built in response — would
/// have read.
class ScopeProbeContext extends TomActionContext {
  final List<String> seenInCanExecute;
  final List<String> seenInExecute;
  ScopeProbeContext({
    required this.seenInCanExecute,
    required this.seenInExecute,
    super.scope,
  });
}

class ScopeProbeAction extends TomSimpleAction<ScopeProbeContext> {
  ScopeProbeAction({required super.controller}) : super(actionId: 'probe');

  @override
  bool canExecute(ScopeProbeContext context) {
    context.seenInCanExecute.add(TomScope.current.id);
    return true;
  }

  @override
  void executeSimple(ScopeProbeContext context, TomActionTransaction tx) {
    context.seenInExecute.add(TomScope.current.id);
  }
}

/// A second context type, unrelated to [CounterContext].
///
/// Exists so a composite can be built whose steps take *different* context
/// types. That a single step list is well typed across unrelated contexts is
/// what makes one composite class enough for every multi-step shape.
class LabelContext extends TomActionContext {
  final List<String> log;
  LabelContext(this.log);
}

class AppendLabelAction extends TomSimpleAction<LabelContext> {
  AppendLabelAction({required super.controller, required this.text})
    : super(actionId: 'append');

  /// Not named `label` — [TomAction.label] is the resource-resolved caption.
  final String text;

  @override
  void executeSimple(LabelContext context, TomActionTransaction tx) =>
      context.log.add(text);
}

/// Declares two actions with the same id, as `late final` fields.
///
/// The canonical controller shape, so the duplicate is not constructed until a
/// field is read — which is where the refusal surfaces.
class _DuplicateIdController extends TomActionController {
  _DuplicateIdController() : super(controllerId: 'dupes');

  late final first = IncrementAction(controller: this, id: 'clash');
  late final second = IncrementAction(controller: this, id: 'clash');
}

/// Increment action attached to an authorization group, used to exercise the
/// `effectiveAuthState` group-mode branch.
class _GroupedIncrement extends TomAction<CounterContext, IncrementUndo> {
  _GroupedIncrement({
    required super.controller,
    required String id,
    required TomAuthorizationGroup group,
    super.scope,
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
      // A distinct id, because the second action is constructed for real and a
      // duplicate would be refused before `add` was ever reached.
      expect(
        () => controller.actions.add(
          IncrementAction(controller: controller, id: 'other'),
        ),
        throwsUnsupportedError,
      );
    });

    group('a duplicate action id is refused', () {
      test('the second registration throws, naming both sides', () {
        final controller = TomActionController(controllerId: 'c');
        IncrementAction(controller: controller, id: 'dup');
        expect(
          () => IncrementAction(controller: controller, id: 'dup'),
          throwsA(
            isA<StateError>()
                .having((e) => e.message, 'message', contains('"dup"'))
                .having((e) => e.message, 'message', contains('"c"'))
                .having((e) => e.message, 'message', contains('c.dup')),
          ),
        );
      });

      test('the first action is left registered and reachable', () {
        final controller = TomActionController(controllerId: 'c');
        final first = IncrementAction(controller: controller, id: 'dup');
        expect(
          () => IncrementAction(controller: controller, id: 'dup'),
          throwsStateError,
        );
        expect(controller.actions, [
          first,
        ], reason: 'the refusal added nothing');
        expect(controller.findAction('dup'), same(first));
      });

      test('the same id on a different controller is fine', () {
        // The id is namespaced by the controller — `a.dup` and `b.dup` are
        // different canonical paths, so there is nothing to collide.
        final a = TomActionController(controllerId: 'a');
        final b = TomActionController(controllerId: 'b');
        final inA = IncrementAction(controller: a, id: 'dup');
        final inB = IncrementAction(controller: b, id: 'dup');
        expect(inA.canonicalPath, 'a.dup');
        expect(inB.canonicalPath, 'b.dup');
      });

      test('late final fields surface the throw when the second is read', () {
        // The canonical declaration builds actions lazily, so the duplicate
        // does not exist until *both* fields have been read — later than the
        // controller's construction, and still the earliest moment at which
        // there is a duplicate to report.
        final controller = _DuplicateIdController();
        expect(controller.actions, isEmpty, reason: 'nothing built yet');

        expect(controller.first, isNotNull, reason: 'the first is fine alone');
        expect(controller.actions.length, 1);

        expect(() => controller.second, throwsStateError);
      });

      test('an unread colliding field is not a collision', () {
        // Reading only one of two same-id fields constructs only that one, so
        // nothing shares its keys and findAction is unambiguous. The check is
        // exactly as strict as the problem: a declared-but-never-built action
        // has no canonical path to collide on.
        final controller = _DuplicateIdController();
        expect(controller.second, isNotNull);
        expect(controller.actions.length, 1);
        expect(controller.findAction('clash'), same(controller.second));
      });
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
        CounterContext(counter),
        TomActionTransaction(label: 'reset'),
      );
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
      expect(
        () => tx.record(inc, IncrementUndo(Counter(), 0)),
        throwsStateError,
      );
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

    test('run executes an action and records its undo state', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final counter = Counter();
      final tx = freshTx();
      tx.run(inc, CounterContext(counter));
      expect(counter.value, 1, reason: 'the action ran');
      expect(tx.entryCount, 1, reason: 'its undo state was recorded');
    });

    test('run records nothing for an action that is not undoable', () {
      // ResetAction is a TomSimpleAction: it returns no undo state, so there
      // is nothing to reverse and the transaction stays empty.
      final controller = TomActionController(controllerId: 'c');
      final counter = Counter()..value = 5;
      final tx = freshTx();
      tx.run(ResetAction(controller: controller), CounterContext(counter));
      expect(counter.value, 0, reason: 'the action still ran');
      expect(tx.hasEntries, isFalse);
    });

    test('run ignores an undo state from an action that is not undoable', () {
      // Both halves of the rule matter: an action may hand back a state and
      // still decline to be reversed. Recording it would make undo call
      // TomAction.undo on an action whose default undo is a no-op, so the
      // transaction would claim an entry that reverses nothing.
      final controller = TomActionController(controllerId: 'c');
      final action = UnrecordedIncrementAction(controller: controller);
      final counter = Counter();
      final tx = freshTx();
      tx.run(action, CounterContext(counter));
      expect(counter.value, 1, reason: 'the action ran');
      expect(
        tx.hasEntries,
        isFalse,
        reason: 'isUndoable is false, so nothing is recorded',
      );
    });

    test('run after commit throws', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final tx = freshTx()..commit();
      expect(() => tx.run(inc, CounterContext(Counter())), throwsStateError);
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

    test('a second undoAll throws instead of applying the undos again', () {
      final controller = TomActionController(controllerId: 'c');
      final delete = DeleteRowAction(controller: controller);
      final rows = ['a', 'b'];
      final tx = freshTx();
      tx.run(delete, RowContext(rows));
      expect(rows, ['a'], reason: 'the row was deleted');
      tx.commit();

      tx.undoAll();
      expect(rows, ['a', 'b'], reason: 'the row is back');
      expect(tx.isUndone, isTrue);

      expect(
        () => tx.undoAll(),
        throwsStateError,
        reason: 'the undos are spent; applying them again would duplicate them',
      );
      expect(rows, ['a', 'b'], reason: 'the refused call changed nothing');
    });

    test('rollback marks the transaction undone and stays idempotent', () {
      // The asymmetry with undoAll is deliberate: rollback runs from error
      // handling that may be reached more than once, so a second call must not
      // replace the original failure with one of its own.
      final controller = TomActionController(controllerId: 'c');
      final delete = DeleteRowAction(controller: controller);
      final rows = ['a', 'b'];
      final tx = freshTx();
      tx.run(delete, RowContext(rows));
      tx.rollback();
      expect(rows, ['a', 'b']);
      expect(tx.isUndone, isTrue);

      tx.rollback();
      expect(rows, ['a', 'b'], reason: 'the second rollback did nothing');
    });

    test('rollback after undoAll does not re-apply the undos', () {
      final controller = TomActionController(controllerId: 'c');
      final delete = DeleteRowAction(controller: controller);
      final rows = ['a', 'b'];
      final tx = freshTx();
      tx.run(delete, RowContext(rows));
      tx.commit();
      tx.undoAll();
      tx.rollback();
      expect(rows, ['a', 'b'], reason: 'one restore, not two');
    });

    test('redoAll re-applies the entries and makes the tx undoable again', () {
      final controller = TomActionController(controllerId: 'c');
      final delete = DeleteRowAction(controller: controller);
      final rows = ['a', 'b'];
      final tx = freshTx();
      tx.run(delete, RowContext(rows));
      tx.commit();

      tx.undoAll();
      expect(rows, ['a', 'b']);
      tx.redoAll();
      expect(rows, ['a'], reason: 'the delete was re-applied');
      expect(tx.isUndone, isFalse);

      tx.undoAll();
      expect(rows, ['a', 'b'], reason: 'undoable again, and once');
    });

    test('redoAll applies entries in the original execution order', () {
      // undoAll reverses; redoAll must not, or a step that depends on an
      // earlier one runs before it.
      final controller = TomActionController(controllerId: 'c');
      final log = <String>[];
      final tx = freshTx();
      for (final name in ['a', 'b', 'c']) {
        tx.run(
          OrderLogAction(controller: controller, name: name),
          OrderLogContext(log),
        );
      }
      tx.commit();
      tx.undoAll();
      tx.redoAll();
      expect(log, [
        'do:a',
        'do:b',
        'do:c',
        'undo:c',
        'undo:b',
        'undo:a',
        'redo:a',
        'redo:b',
        'redo:c',
      ]);
    });

    test('redoAll on a transaction that is not undone throws', () {
      final controller = TomActionController(controllerId: 'c');
      final delete = DeleteRowAction(controller: controller);
      final rows = ['a', 'b'];
      final tx = freshTx();
      tx.run(delete, RowContext(rows));
      tx.commit();
      expect(() => tx.redoAll(), throwsStateError);
      expect(rows, ['a'], reason: 'the refused call changed nothing');
    });

    test('redoAll names the action that does not implement redo', () {
      final controller = TomActionController(controllerId: 'c');
      final undoOnly = UndoOnlyIncrementAction(controller: controller);
      final counter = Counter();
      final tx = freshTx();
      tx.run(undoOnly, CounterContext(counter));
      tx.commit();
      expect(tx.isRedoable, isFalse);
      tx.undoAll();

      expect(
        () => tx.redoAll(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('undoOnlyIncrement'),
          ),
        ),
      );
      expect(
        tx.isUndone,
        isTrue,
        reason: 'the refusal left the transaction reversed, not half-applied',
      );
    });

    test('isRedoable is false for an empty transaction', () {
      final tx = freshTx()..commit();
      expect(tx.isRedoable, isFalse);
    });

    test('run executes the action in the context scope', () {
      final controller = TomActionController(controllerId: 'c');
      final probe = ScopeProbeAction(controller: controller);
      final seen = <String>[];
      final tx = freshTx();
      tx.run(
        probe,
        ScopeProbeContext(
          seenInCanExecute: [],
          seenInExecute: seen,
          scope: TomScopeBase(scopeId: 'invocation'),
        ),
      );
      expect(seen, ['invocation']);
    });

    test('run executes in the ambient scope when the context names none', () {
      final controller = TomActionController(controllerId: 'c');
      final probe = ScopeProbeAction(controller: controller);
      final seen = <String>[];
      TomScope.withScope('ambient', () {
        freshTx().run(
          probe,
          ScopeProbeContext(seenInCanExecute: [], seenInExecute: seen),
        );
      });
      expect(seen, [
        'ambient',
      ], reason: 'a null scope defers, it does not reset');
    });

    test('the context scope wins over the ambient one', () {
      final controller = TomActionController(controllerId: 'c');
      final probe = ScopeProbeAction(controller: controller);
      final seen = <String>[];
      TomScope.withScope('ambient', () {
        freshTx().run(
          probe,
          ScopeProbeContext(
            seenInCanExecute: [],
            seenInExecute: seen,
            scope: TomScopeBase(scopeId: 'invocation'),
          ),
        );
      });
      expect(seen, ['invocation']);
    });
  });

  group('TomActionContext.runInScope', () {
    test('returns the body result and installs the scope', () {
      final context = TomActionContext(
        scope: TomScopeBase(scopeId: 'somewhere'),
      );
      expect(context.runInScope(() => TomScope.current.id), 'somewhere');
    });

    test('runs directly when the context carries no scope', () {
      expect(
        TomScope.withScope(
          'ambient',
          () => TomActionContext().runInScope(() => TomScope.current.id),
        ),
        'ambient',
      );
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
      expect(counter.value, 2, reason: 'redo re-applies the increment');
      expect(history.undoCount, 2);
      expect(history.canRedo, isFalse);
    });

    test(
      'redo re-applies the transaction, restores the position, notifies',
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

        // The application state is put back...
        expect(counter.value, 1);
        // ...the stack position is restored in full...
        expect(history.canUndo, isTrue);
        expect(history.undoCount, 1);
        expect(history.undoLabel, 'inc');
        expect(history.canRedo, isFalse);
        // ...and listeners are told.
        expect(changes, changesBeforeRedo + 1);
      },
    );

    test('canRedo is false when the undone transaction cannot be redone', () {
      // The defect a Redo button used to have: enabled because something was
      // undone, inert because nothing could put it back. canRedo asks the
      // transaction, not just the stack.
      final controller = TomActionController(controllerId: 'c');
      final undoOnly = UndoOnlyIncrementAction(controller: controller);
      final counter = Counter();
      final history = TomUndoHistory();

      final tx = TomActionTransaction(label: 'undo-only');
      tx.run(undoOnly, CounterContext(counter));
      tx.commit();
      history.push(tx);
      history.undo();
      expect(counter.value, 0);

      expect(history.redoCount, 1, reason: 'it is on the redo stack');
      expect(history.canRedo, isFalse, reason: 'but nothing can put it back');
      expect(history.redoLabel, isNull);

      history.redo();
      expect(counter.value, 0, reason: 'redo did nothing');
      expect(history.redoCount, 1, reason: 'and moved nothing');
      expect(history.undoCount, 0);
    });

    test('a TomRedoAction over an undo-only history cannot execute', () {
      final controller = TomActionController(controllerId: 'c');
      final undoOnly = UndoOnlyIncrementAction(controller: controller);
      final history = TomUndoHistory();
      final redoAction = TomRedoAction(
        controller: controller,
        history: history,
      );

      final tx = TomActionTransaction(label: 'undo-only');
      tx.run(undoOnly, CounterContext(Counter()));
      tx.commit();
      history.push(tx);
      history.undo();

      expect(
        redoAction.canExecute(TomUndoRedoContext()),
        isFalse,
        reason: 'the toolbar button stays disabled',
      );
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

    test('undo(); redo(); undo(); applies each direction exactly once', () {
      // The three keystrokes that used to apply the same undo twice. With a
      // real redo the sequence is delete, restore, delete, restore — and the
      // row is present exactly once at every step, which an undo that assigns
      // a previous value could never have shown.
      final controller = TomActionController(controllerId: 'c');
      final delete = DeleteRowAction(controller: controller);
      final rows = ['a', 'b'];
      final history = TomUndoHistory();

      final tx = TomActionTransaction(label: 'delete');
      tx.run(delete, RowContext(rows));
      tx.commit();
      history.push(tx);
      expect(rows, ['a'], reason: 'the row was deleted');

      history.undo();
      expect(rows, ['a', 'b'], reason: 'the row is back, once');

      history.redo();
      expect(rows, ['a'], reason: 'the delete is re-applied, once');

      history.undo();
      expect(rows, ['a', 'b'], reason: 'back again, and still exactly once');
      expect(history.canRedo, isTrue);
    });

    test('a refused undo leaves both stacks untouched', () {
      // undoAll runs before the pop, so the transaction is on neither stack
      // only if the undo succeeded. Reached here by driving the transaction
      // out from under the history: a caller that catches the StateError sees
      // a history in the state it was in before the call.
      var changes = 0;
      final controller = TomActionController(controllerId: 'c');
      final delete = DeleteRowAction(controller: controller);
      final rows = ['a', 'b'];
      final history = TomUndoHistory(onChanged: () => changes++);

      final tx = TomActionTransaction(label: 'delete');
      tx.run(delete, RowContext(rows));
      tx.commit();
      history.push(tx);
      tx.undoAll(); // undone behind the history's back

      final changesBefore = changes;
      expect(() => history.undo(), throwsStateError);
      expect(history.undoCount, 1, reason: 'not popped');
      expect(history.redoCount, 0, reason: 'nothing pushed onto redo');
      expect(history.undoLabel, 'delete');
      expect(changes, changesBefore, reason: 'no change was announced');
    });

    test('a refused redo leaves both stacks untouched', () {
      var changes = 0;
      final controller = TomActionController(controllerId: 'c');
      final delete = DeleteRowAction(controller: controller);
      final rows = ['a', 'b'];
      final history = TomUndoHistory(onChanged: () => changes++);

      final tx = TomActionTransaction(label: 'delete');
      tx.run(delete, RowContext(rows));
      tx.commit();
      history.push(tx);
      history.undo();
      tx.redoAll(); // re-applied behind the history's back

      final changesBefore = changes;
      expect(() => history.redo(), throwsStateError);
      expect(history.redoCount, 1, reason: 'not popped');
      expect(history.undoCount, 0, reason: 'nothing pushed onto undo');
      expect(changes, changesBefore, reason: 'no change was announced');
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

    group('authorization gates the dispatch', () {
      tearDown(TomAuthorization.reset);

      /// Triggers `c.gated` under [state] and reports what happened.
      ({bool ran, bool refused, bool wasAuthorized}) triggerUnder(
        TomAuthState state,
      ) {
        TomAuthorization.adapter = _PathAuthAdapter({'c.gated': state});
        final controller = TomActionController(controllerId: 'c');
        final action = IncrementAction(controller: controller, id: 'gated');
        final counter = Counter();
        var refused = false;
        var wasAuthorized = true;
        TomActionTrigger<CounterContext, IncrementUndo>(
          action: action,
          contextBuilder: () => CounterContext(counter),
          onCannotExecute: () {
            refused = true;
            // The caller can tell an authorization refusal from a canExecute
            // one without being handed a reason.
            wasAuthorized = action.isAuthorized;
          },
        ).trigger();
        return (
          ran: counter.value == 1,
          refused: refused,
          wasAuthorized: wasAuthorized,
        );
      }

      test('a hidden action is not run', () {
        final r = triggerUnder(TomAuthState.none);
        expect(r.ran, isFalse);
        expect(r.refused, isTrue);
        expect(r.wasAuthorized, isFalse);
      });

      test('a disabled action is not run', () {
        final r = triggerUnder(TomAuthState.disabled);
        expect(r.ran, isFalse);
        expect(r.refused, isTrue);
      });

      test('a read-only action is not run either', () {
        // The gate is `effectiveAuthState.isInteractive`, which is `full` and
        // nothing else — the same predicate the widget layer applies, so the
        // trigger and the button cannot disagree about a `read` action.
        final r = triggerUnder(TomAuthState.read);
        expect(r.ran, isFalse);
        expect(r.refused, isTrue);
      });

      test('a fully authorized action runs', () {
        final r = triggerUnder(TomAuthState.full);
        expect(r.ran, isTrue);
        expect(r.refused, isFalse);
      });

      test('a group ceiling that hides the action blocks it too', () {
        // The gate reads effectiveAuthState, not authState: an action whose own
        // rule is full but whose group hides it must not run.
        TomAuthorization.adapter = _PathAuthAdapter({
          'c.gated': TomAuthState.full,
          'billing': TomAuthState.none,
        });
        final controller = TomActionController(
          controllerId: 'c',
          tomGroup: TomAuthorizationGroup(
            'billing',
            mode: AuthGroupMode.controlsAll,
          ),
        );
        final action = IncrementAction(controller: controller, id: 'gated');
        final counter = Counter();
        expect(action.authState, TomAuthState.full);
        expect(action.isAuthorized, isFalse);
        TomActionTrigger<CounterContext, IncrementUndo>(
          action: action,
          contextBuilder: () => CounterContext(counter),
        ).trigger();
        expect(counter.value, 0);
      });

      test('the context is not built for a refused action', () {
        TomAuthorization.adapter = _PathAuthAdapter({
          'c.gated': TomAuthState.none,
        });
        final controller = TomActionController(controllerId: 'c');
        final action = IncrementAction(controller: controller, id: 'gated');
        var built = 0;
        TomActionTrigger<CounterContext, IncrementUndo>(
          action: action,
          contextBuilder: () {
            built++;
            return CounterContext(Counter());
          },
        ).trigger();
        expect(
          built,
          0,
          reason: 'a builder is application code; a refused action runs none',
        );
      });

      test('nothing is pushed onto the undo history', () {
        TomAuthorization.adapter = _PathAuthAdapter({
          'c.gated': TomAuthState.none,
        });
        final controller = TomActionController(controllerId: 'c');
        final action = IncrementAction(controller: controller, id: 'gated');
        final history = TomUndoHistory();
        var executed = false;
        TomActionTrigger<CounterContext, IncrementUndo>(
          action: action,
          contextBuilder: () => CounterContext(Counter()),
          undoHistory: history,
          onExecuted: () => executed = true,
        ).trigger();
        expect(history.canUndo, isFalse);
        expect(executed, isFalse, reason: 'onExecuted is for what executed');
      });
    });

    test('gates and executes in the context scope, not the ambient one', () {
      // Both halves, because a guard that read a different frame from the
      // execute it guards would be worse than no guard.
      final controller = TomActionController(controllerId: 'c');
      final probe = ScopeProbeAction(controller: controller);
      final gate = <String>[];
      final body = <String>[];
      TomScope.withScope('ambient', () {
        TomActionTrigger<ScopeProbeContext, TomActionUndo>(
          action: probe,
          contextBuilder: () => ScopeProbeContext(
            seenInCanExecute: gate,
            seenInExecute: body,
            scope: TomScopeBase(scopeId: 'invocation'),
          ),
        ).trigger();
      });
      expect(gate, ['invocation']);
      expect(body, ['invocation']);
    });
  });

  group('TomCompositeAction', () {
    TomCompositeStep<CounterContext> step(
      TomAction<CounterContext, TomActionUndo> action,
      Counter counter, {
      bool Function()? guard,
    }) => TomCompositeStep<CounterContext>(
      action: action,
      contextBuilder: () => CounterContext(counter),
      guard: guard,
    );

    group('an unauthorized step is blocked', () {
      tearDown(TomAuthorization.reset);

      test('it does not run, and its context is never built', () {
        // A composite is one authorizable and each step is another. The trigger
        // checks the composite; that says nothing about what the composite then
        // reaches — so a hidden action would run as a step of a visible one.
        TomAuthorization.adapter = _PathAuthAdapter({
          'c.hidden': TomAuthState.none,
        });
        final controller = TomActionController(controllerId: 'c');
        final hidden = IncrementAction(controller: controller, id: 'hidden');
        final counter = Counter();
        var built = 0;
        final composite = TomCompositeAction(
          actionId: 'runsHidden',
          controller: controller,
          steps: [
            TomCompositeStep<CounterContext>(
              action: hidden,
              contextBuilder: () {
                built++;
                return CounterContext(counter);
              },
            ),
          ],
        );
        composite.execute(
          TomActionContext(),
          TomActionTransaction(label: 'composite'),
        );
        expect(counter.value, 0, reason: 'the hidden step did not run');
        expect(built, 0, reason: 'nor did its builder');
      });

      test('canExecute agrees, so no button is enabled over it', () {
        TomAuthorization.adapter = _PathAuthAdapter({
          'c.hidden': TomAuthState.none,
        });
        final controller = TomActionController(controllerId: 'c');
        final hidden = IncrementAction(controller: controller, id: 'hidden');
        final composite = TomCompositeAction(
          actionId: 'runsHidden',
          controller: controller,
          steps: [step(hidden, Counter())],
        );
        expect(composite.canExecute(TomActionContext()), isFalse);
      });

      test(
        'with stopOnBlockedStep false, later authorized steps still run',
        () {
          TomAuthorization.adapter = _PathAuthAdapter({
            'c.hidden': TomAuthState.none,
          });
          final controller = TomActionController(controllerId: 'c');
          final hidden = IncrementAction(controller: controller, id: 'hidden');
          final allowed = IncrementAction(
            controller: controller,
            id: 'allowed',
          );
          final counter = Counter();
          final composite = TomCompositeAction(
            actionId: 'mixed',
            controller: controller,
            stopOnBlockedStep: false,
            steps: [step(hidden, counter), step(allowed, counter)],
          );
          composite.execute(
            TomActionContext(),
            TomActionTransaction(label: 'composite'),
          );
          expect(counter.value, 1, reason: 'only the authorized step ran');
        },
      );
    });

    test('gates each step in that step context scope', () {
      // Steps carry their own contexts, so each is gated in its own frame —
      // not the composite's, and not the caller's.
      final controller = TomActionController(controllerId: 'c');
      final probe = ScopeProbeAction(controller: controller);
      final gate = <String>[];
      final body = <String>[];
      TomCompositeStep<ScopeProbeContext> probeStep(String scopeId) =>
          TomCompositeStep<ScopeProbeContext>(
            action: probe,
            contextBuilder: () => ScopeProbeContext(
              seenInCanExecute: gate,
              seenInExecute: body,
              scope: TomScopeBase(scopeId: scopeId),
            ),
          );
      final composite = TomCompositeAction(
        actionId: 'scoped',
        controller: controller,
        steps: [probeStep('first'), probeStep('second')],
      );
      TomScope.withScope('ambient', () {
        composite.execute(
          TomActionContext(),
          TomActionTransaction(label: 'composite'),
        );
      });
      expect(gate, ['first', 'second']);
      expect(body, ['first', 'second']);
    });

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
        CounterContext(counter),
        TomActionTransaction(label: 'x'),
      );
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
        CounterContext(counter),
        TomActionTransaction(label: 'x'),
      );
      expect(counter.value, 1);
    });

    test(
      'a step whose action refuses canExecute stops the run, with no guard',
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
          CounterContext(counter),
          TomActionTransaction(label: 'x'),
        );
        expect(counter.value, 0, reason: 'step two never ran');
      },
    );

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
        CounterContext(counter),
        TomActionTransaction(label: 'x'),
      );
      expect(counter.value, 1, reason: 'step two still ran');
    });

    test('canExecute is true when a reachable step is runnable', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final counter = Counter();
      final composite = TomCompositeAction(
        actionId: 'maybe',
        controller: controller,
        steps: [
          step(inc, counter, guard: () => true),
          step(inc, counter, guard: () => false),
        ],
      );
      expect(composite.canExecute(CounterContext(counter)), isTrue);
    });

    test('canExecute is false when the only step\'s action refuses', () {
      final controller = TomActionController(controllerId: 'c');
      final reset = ResetAction(controller: controller);
      final counter = Counter(); // 0, so reset.canExecute is false
      final composite = TomCompositeAction(
        actionId: 'refusing',
        controller: controller,
        // No guard. The old check read guards only, so it said yes here
        // and then executed nothing — an enabled button doing nothing.
        steps: [step(reset, counter)],
      );
      expect(composite.canExecute(CounterContext(counter)), isFalse);
    });

    test(
      'canExecute is false when a blocked first step would stop the run',
      () {
        final controller = TomActionController(controllerId: 'c');
        final inc = IncrementAction(controller: controller);
        final counter = Counter();
        final composite = TomCompositeAction(
          actionId: 'stops',
          controller: controller,
          // Default stopOnBlockedStep: true, so execute breaks at step one and
          // step two is unreachable however runnable it looks in isolation.
          steps: [
            step(inc, counter, guard: () => false),
            step(inc, counter),
          ],
        );
        expect(composite.canExecute(CounterContext(counter)), isFalse);
      },
    );

    test(
      'canExecute sees past a blocked step when blocked steps are skipped',
      () {
        final controller = TomActionController(controllerId: 'c');
        final inc = IncrementAction(controller: controller);
        final counter = Counter();
        final composite = TomCompositeAction(
          actionId: 'skips',
          controller: controller,
          stopOnBlockedStep: false, // step two is now reachable
          steps: [
            step(inc, counter, guard: () => false),
            step(inc, counter),
          ],
        );
        expect(composite.canExecute(CounterContext(counter)), isTrue);
      },
    );

    test('canExecute is false for an empty step list', () {
      final controller = TomActionController(controllerId: 'c');
      final composite = TomCompositeAction(
        actionId: 'empty',
        controller: controller,
        steps: const [],
      );
      expect(composite.canExecute(CounterContext(Counter())), isFalse);
    });

    test('a refusing composite reports the refusal through its trigger', () {
      // The user-visible payoff: a button bound to this composite is disabled
      // and its press reports onCannotExecute, instead of being enabled and
      // silently doing nothing.
      final controller = TomActionController(controllerId: 'c');
      final reset = ResetAction(controller: controller);
      final counter = Counter(); // 0, so reset.canExecute is false
      final composite = TomCompositeAction(
        actionId: 'deadButton',
        controller: controller,
        steps: [step(reset, counter)],
      );
      var executed = false;
      var refused = false;
      TomActionTrigger<TomActionContext, TomActionUndo>(
        action: composite,
        contextBuilder: () => CounterContext(counter),
        onExecuted: () => executed = true,
        onCannotExecute: () => refused = true,
      ).trigger();

      expect(refused, isTrue, reason: 'the refusal is reported');
      expect(executed, isFalse);
    });

    test('canExecute predicts whether execute will run anything', () {
      // The contract in one assertion, over all four combinations of
      // (first step blocked?) x (stopOnBlockedStep). canExecute must agree
      // with what execute actually does — that agreement is the whole point.
      for (final firstBlocked in [true, false]) {
        for (final stopOnBlocked in [true, false]) {
          final controller = TomActionController(controllerId: 'c');
          final inc = IncrementAction(controller: controller);
          final counter = Counter();
          final composite = TomCompositeAction(
            actionId: 'matrix',
            controller: controller,
            stopOnBlockedStep: stopOnBlocked,
            steps: [
              step(inc, counter, guard: () => !firstBlocked),
              step(inc, counter),
            ],
          );
          final predicted = composite.canExecute(CounterContext(counter));
          composite.execute(
            CounterContext(counter),
            TomActionTransaction(label: 'x'),
          );
          expect(
            predicted,
            counter.value > 0,
            reason:
                'firstBlocked=$firstBlocked '
                'stopOnBlockedStep=$stopOnBlocked',
          );
        }
      }
    });

    // One composite covers every multi-step shape, including the two-sided
    // one, because a step list is well typed across unrelated context types:
    // TomCompositeStep's type parameter is covariant, so a heterogeneous list
    // is legal and each step still pairs its own action with its own builder.
    // Were this not true, two-sided work would need a class of its own.
    test('a composite holds steps whose contexts are different types', () {
      final controller = TomActionController(controllerId: 'mixed');
      final counter = Counter();
      final log = <String>[];
      TomCompositeAction(
        actionId: 'mixed',
        controller: controller,
        steps: [
          TomCompositeStep<CounterContext>(
            action: IncrementAction(controller: controller, id: 'inc'),
            contextBuilder: () => CounterContext(counter),
          ),
          TomCompositeStep<LabelContext>(
            action: AppendLabelAction(controller: controller, text: 'done'),
            contextBuilder: () => LabelContext(log),
          ),
        ],
      ).execute(CounterContext(counter), TomActionTransaction(label: 'x'));

      expect(counter.value, 1, reason: 'the CounterContext step ran');
      expect(log, ['done'], reason: 'the LabelContext step ran');
    });
  });

  // TomAction's authorization surface — authState, the effectiveAuthState
  // group branch, and the authorizer — driven through a map-backed adapter
  // keyed on the action's canonicalPath.
  group('TomAction authorization surface', () {
    tearDown(TomAuthorization.reset);

    test('authState resolves from the adapter at canonicalPath', () {
      TomAuthorization.adapter = _PathAuthAdapter({
        'sec.edit': TomAuthState.read,
      });
      final controller = TomActionController(controllerId: 'sec');
      final action = IncrementAction(controller: controller, id: 'edit');
      expect(action.canonicalPath, 'sec.edit');
      expect(action.authState, TomAuthState.read);
    });

    test('effectiveAuthState equals authState without a group', () {
      TomAuthorization.adapter = _PathAuthAdapter({
        'sec.edit': TomAuthState.read,
      });
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
        group: TomAuthorizationGroup(
          'billing',
          mode: AuthGroupMode.controlsWidest,
        ),
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
        group: TomAuthorizationGroup(
          'billing',
          mode: AuthGroupMode.controlsAll,
        ),
      );
      // controlsAll → group state replaces member state.
      expect(grouped.effectiveAuthState, TomAuthState.read);
    });

    test('authorizer applies the fromAction disabled pattern', () {
      TomAuthorization.adapter = _PathAuthAdapter({
        'sec.edit': TomAuthState.none,
      });
      final controller = TomActionController(controllerId: 'sec');
      final action = IncrementAction(controller: controller, id: 'edit');
      // action auth none + widget resource full → disabled.
      expect(
        action.authorizer.effectiveAuth(TomAuthState.full),
        TomAuthState.disabled,
      );
      // widget hidden stays hidden.
      expect(
        action.authorizer.effectiveAuth(TomAuthState.none),
        TomAuthState.none,
      );
    });
  });

  // An action's member path and its group path are a `<prefix>.<id>` pair, so
  // they have to be resolved in one frame — the same invariant widgets hold to.
  // These pin it for actions: the frame is captured once, at construction, and
  // reaches the controller prefix, the action path and the group ceiling alike.
  group('an action resolves its path and its group in one frame', () {
    tearDown(TomAuthorization.reset);

    /// A scope handed over as a value, never installed on a zone — the shape
    /// `ScopeCapture` and the screen-element providers produce.
    TomScope detachedCheckout() => TomScopeBase(scopeId: 'checkout');

    /// Three rules, and the third is the point. `billing: full` is what an
    /// out-of-frame group lookup lands on, so a frame that fails to reach the
    /// group produces a *wider* answer rather than the same one by luck.
    void installRules() {
      TomAuthorization.adapter = _PathAuthAdapter({
        'checkout.sec.edit': TomAuthState.full,
        'checkout.billing': TomAuthState.read, // the ceiling that must apply
        'billing': TomAuthState.full, // the unscoped decoy
      });
    }

    test('outside any scope the path is controller id and action id', () {
      final controller = TomActionController(controllerId: 'sec');
      final action = IncrementAction(controller: controller, id: 'edit');
      expect(controller.canonicalPrefix, 'sec');
      expect(action.canonicalPath, 'sec.edit');
    });

    test('an ambient scope prefixes the controller and the action', () {
      TomScope.withScope('checkout', () {
        final controller = TomActionController(controllerId: 'sec');
        final action = IncrementAction(controller: controller, id: 'edit');
        expect(controller.canonicalPrefix, 'checkout.sec');
        expect(action.canonicalPath, 'checkout.sec.edit');
      });
    });

    test('an explicit scope prefixes the path with no zone installed', () {
      final controller = TomActionController(controllerId: 'sec');
      final action = IncrementAction(
        controller: controller,
        id: 'edit',
        scope: detachedCheckout(),
      );
      expect(action.canonicalPath, 'checkout.sec.edit');
    });

    test(
      'an action with no scope of its own stands where its controller does',
      () {
        final controller = TomActionController(
          controllerId: 'sec',
          scope: detachedCheckout(),
        );
        final action = IncrementAction(controller: controller, id: 'edit');
        expect(controller.canonicalPrefix, 'checkout.sec');
        expect(action.canonicalPath, 'checkout.sec.edit');
      },
    );

    test('an ambient scope applies the group ceiling', () {
      installRules();
      final group = TomAuthorizationGroup('billing');
      TomScope.withScope('checkout', () {
        final controller = TomActionController(controllerId: 'sec');
        final action = _GroupedIncrement(
          controller: controller,
          id: 'edit',
          group: group,
        );
        expect(action.canonicalPath, 'checkout.sec.edit');
        expect(action.authState, TomAuthState.full);
        expect(action.effectiveAuthState, TomAuthState.read);
      });
    });

    test('an explicit scope applies it too — it is not silently skipped', () {
      installRules();
      final controller = TomActionController(controllerId: 'sec');
      final action = _GroupedIncrement(
        controller: controller,
        id: 'edit',
        group: TomAuthorizationGroup('billing'),
        scope: detachedCheckout(),
      );
      expect(action.canonicalPath, 'checkout.sec.edit');
      expect(action.effectiveAuthState, TomAuthState.read);
    });

    test('the effective state does not depend on where it is read from', () {
      // The defect this closes: the path was frozen without a scope while the
      // group was resolved against whatever zone the *reader* stood in. Both
      // halves now come from the frame captured at construction, so an action
      // built inside a scope answers the same question the same way wherever
      // the answer is asked for.
      installRules();
      final group = TomAuthorizationGroup('billing');
      final action = TomScope.withScope('checkout', () {
        final controller = TomActionController(controllerId: 'sec');
        return _GroupedIncrement(
          controller: controller,
          id: 'edit',
          group: group,
        );
      });

      expect(action.effectiveAuthState, TomAuthState.read, reason: 'outside');
      TomScope.withScope('checkout', () {
        expect(action.effectiveAuthState, TomAuthState.read, reason: 'inside');
      });
      TomScope.withScope('elsewhere', () {
        expect(
          action.effectiveAuthState,
          TomAuthState.read,
          reason: 'a foreign zone does not move the action',
        );
      });
    });

    test('an action joins its controller group when it names none', () {
      // The collective half: declaring the group once on the controller has to
      // reach the actions, or "collective action control" is just the per-action
      // wiring it claims to replace.
      TomAuthorization.adapter = _PathAuthAdapter({
        'sec.edit': TomAuthState.full,
        'billing': TomAuthState.read,
      });
      final group = TomAuthorizationGroup('billing');
      final controller = TomActionController(
        controllerId: 'sec',
        tomGroup: group,
      );
      final action = IncrementAction(controller: controller, id: 'edit');

      expect(action.tomGroup, same(group), reason: 'inherited, not null');
      expect(
        action.effectiveAuthState,
        TomAuthState.read,
        reason: 'the ceiling applies',
      );
      expect(
        group.members,
        contains(action),
        reason: 'registered, so the group can reach it back',
      );
    });

    test(
      'every action of a grouped controller joins, without repeating it',
      () {
        TomAuthorization.adapter = _PathAuthAdapter({
          'sec.edit': TomAuthState.full,
          'sec.view': TomAuthState.full,
          'billing': TomAuthState.read,
        });
        final group = TomAuthorizationGroup('billing');
        final controller = TomActionController(
          controllerId: 'sec',
          tomGroup: group,
        );
        final edit = IncrementAction(controller: controller, id: 'edit');
        final view = IncrementAction(controller: controller, id: 'view');

        expect(group.members, containsAll(<Object>[edit, view]));
        expect(edit.effectiveAuthState, TomAuthState.read);
        expect(view.effectiveAuthState, TomAuthState.read);
      },
    );

    test('an action group of its own overrides the controller group', () {
      TomAuthorization.adapter = _PathAuthAdapter({
        'sec.edit': TomAuthState.full,
        'billing': TomAuthState.none,
        'reporting': TomAuthState.read,
      });
      final controllerGroup = TomAuthorizationGroup('billing');
      final ownGroup = TomAuthorizationGroup('reporting');
      final controller = TomActionController(
        controllerId: 'sec',
        tomGroup: controllerGroup,
      );
      final action = _GroupedIncrement(
        controller: controller,
        id: 'edit',
        group: ownGroup,
      );

      expect(action.tomGroup, same(ownGroup));
      expect(
        action.effectiveAuthState,
        TomAuthState.read,
        reason: 'the reporting ceiling, not the billing one',
      );
      expect(
        controllerGroup.members,
        isNot(contains(action)),
        reason: 'the overridden group never sees it',
      );
    });

    test('an ungrouped controller leaves its actions ungrouped', () {
      TomAuthorization.adapter = _PathAuthAdapter({
        'sec.edit': TomAuthState.full,
      });
      final controller = TomActionController(controllerId: 'sec');
      final action = IncrementAction(controller: controller, id: 'edit');
      expect(action.tomGroup, isNull);
      expect(action.effectiveAuthState, TomAuthState.full);
    });

    test('the inherited group is resolved in the action frame', () {
      // The group arrives from the controller, but its ceiling is still looked
      // up in the frame the *action* captured — the pair a canonical path and a
      // group path have to make.
      installRules();
      final group = TomAuthorizationGroup('billing');
      final action = TomScope.withScope('checkout', () {
        final controller = TomActionController(
          controllerId: 'sec',
          tomGroup: group,
        );
        return IncrementAction(controller: controller, id: 'edit');
      });
      expect(action.canonicalPath, 'checkout.sec.edit');
      expect(
        action.effectiveAuthState,
        TomAuthState.read,
        reason: 'checkout.billing, not the unscoped billing decoy',
      );
    });

    test('resources resolve against the same scoped path', () {
      // `label` / `tooltip` / `iconName` read `<canonicalPath>.<suffix>`, so a
      // scoped action addresses its captions in the scope too — the field is
      // documented for resource resolution and now genuinely reaches it.
      final controller = TomActionController(controllerId: 'sec');
      final action = IncrementAction(
        controller: controller,
        id: 'edit',
        scope: detachedCheckout(),
      );
      expect(action.label, 'edit', reason: 'no resource bundle, so the id');
      expect(action.toString(), 'TomAction(checkout.sec.edit)');
    });
  });

  group('TomUndoAction / TomRedoAction', () {
    test('drive the undo history and gate on its state', () {
      final controller = TomActionController(controllerId: 'c');
      final inc = IncrementAction(controller: controller);
      final counter = Counter();
      final history = TomUndoHistory();

      final undoAction = TomUndoAction(
        controller: controller,
        history: history,
      );
      final redoAction = TomRedoAction(
        controller: controller,
        history: history,
      );
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
