# actions

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

The behavioural counterpart to widgets: typed, authorization-aware actions
dispatched through a controller, with atomic transactions, undo/redo history,
multi-step composites, and widget triggers. An action declares what it does; the
controller dispatches it; a transaction makes the mutation atomic and reversible.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomAction` / `TomSimpleAction` / `TomDualAction` | The action base & primitives |
| `TomActionController` | Owns and dispatches a group of actions (`controllerId`) |
| `TomActionContext` | The per-invocation context an action operates on |
| `TomActionTransaction` / `TomUndoHistory` / `TomUndoRedoContext` | Atomicity & undo/redo |
| `TomCompositeAction` / `TomCompositeStep` | Composed multi-step actions |
| `TomActionTrigger` | Binds an action + context builder (+ undo history) to a widget |

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
subclasses of `TomSimpleAction` / `TomActionContext` / the undo record — see
`example/actions/`.)

---

Part of [`tom_flutter_ui`](../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
