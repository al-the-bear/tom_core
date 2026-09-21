# actions

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The behavioural counterpart to widgets: typed, authorization-aware actions
grouped under a controller, with atomic transactions, undo/redo history,
multi-step composites, and widget triggers. An action declares what it does; a
controller owns and names it; a `TomActionTrigger` dispatches it; a transaction
makes the mutation atomic and reversible.

The controller is a **registry**, the trigger is the **protocol** — that split is
the module's central separation. Nothing on `TomActionController` runs an action;
`TomActionTrigger.trigger()` is the one place that sequences `canExecute` →
`execute` → `commit` → `push`.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomAction` / `TomSimpleAction` / `TomCompositeAction` | The action base & primitives |
| `TomActionUndo` | The marker an undo-state object implements — what `execute` hands back and `undo` / `redo` are given |
| `TomActionController` | Owns and names a group of actions; supplies the `<scopePath>.<controllerId>` canonical-path prefix, and the scope frame *and* authorization group its actions inherit. Action ids are unique per controller — `TomActionController.addUniquely`, the static both this class and `TomForm` register through, throws on a duplicate, because two would share one authorization decision and one set of resource keys |
| `TomActionContext` | The per-invocation context an action operates on. Its `scope` is the *invocation* frame — installed around both the gate and the body — as distinct from the construction frame that fixes a canonical path |
| `TomActionTransaction` / `TomUndoHistory` / `TomUndoRedoContext` | Atomicity & undo/redo. A transaction is either applied or reversed — `undoAll` and `redoAll` each refuse when it is already the way they would leave it |
| `TomUndoAction` / `TomRedoAction` | Ready-made actions over a `TomUndoHistory`, so undo/redo dispatches through the same trigger protocol as everything else. Redo is opt-in per action (`TomAction.isRedoable` / `redo`), and `canRedo` accounts for it, so the second one's button is disabled when what was undone cannot be put back |
| `TomCompositeAction` / `TomCompositeStep` | Composed multi-step actions |
| `TomActionTrigger` | **Dispatches** an action — binds it, a context builder and an optional undo history to a widget callback. Refuses before it dispatches when authorization does not permit the action, so a shortcut or a test cannot run what a button would not show |

## Quick start

```dart
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

class CounterController extends TomActionController {
  CounterController() : super(controllerId: 'counter');
  late final increment = IncrementAction(controller: this);
}

void run(CounterController controller, CounterContext ctx) {
  final history = TomUndoHistory();
  final trigger = TomActionTrigger<CounterContext, IncrementUndo>(
    action: controller.increment,
    contextBuilder: () => ctx,
    undoHistory: history,
  );

  trigger.trigger(); // executes the action + records an undo entry
  history.undo();    // reverses the last transaction
}
```

(All three are the app's own types — see `example/actions/`. `IncrementAction`
and `CounterContext` *extend* `TomAction` and `TomActionContext`;
`IncrementUndo` *implements* `TomActionUndo`, which is an
`abstract interface class` and so cannot be extended outside its own library.
The action extends `TomAction`, not `TomSimpleAction`, because the
`history.undo()` above needs it to return undo state; `TomSimpleAction` always
returns `null`, so nothing would reach the history.)

## Examples

Both run under `flutter test` and assert their own results.

| File | Covers |
| ---- | ------ |
| `example/actions/actions_example.dart` | The quick start above, end to end: a controller and its actions, a transaction, the trigger → history wiring, undo and redo, `canExecute`, a guarded composite. |
| `example/actions/actions_advanced_example.dart` | The coordinator actions, the authorization surface, resource-resolved captions, the transaction API including `rollback`, construction and invocation scope frames, controller groups, and the duplicate-id refusal. |

---

Part of [`tom_flutter_ui`](../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
