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
| `TomAction` / `TomSimpleAction` / `TomDualAction` | The action base & primitives |
| `TomActionController` | Owns and names a group of actions; supplies the `controllerId` canonical-path prefix |
| `TomActionContext` | The per-invocation context an action operates on |
| `TomActionTransaction` / `TomUndoHistory` / `TomUndoRedoContext` | Atomicity & undo/redo |
| `TomCompositeAction` / `TomCompositeStep` | Composed multi-step actions |
| `TomActionTrigger` | **Dispatches** an action — binds it, a context builder and an optional undo history to a widget callback |

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

(`IncrementAction` / `CounterContext` / `IncrementUndo` are the app's own
subclasses of `TomAction` / `TomActionContext` / `TomActionUndo` — see
`example/actions/`. The action extends `TomAction`, not `TomSimpleAction`,
because the `history.undo()` above needs it to return undo state;
`TomSimpleAction` always returns `null`, so nothing would reach the history.)

---

Part of [`tom_flutter_ui`](../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
