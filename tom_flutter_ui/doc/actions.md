# Actions Module

`actions/` is the **behavioural** layer of `tom_flutter_ui` — the counterpart to
the widget layer. Where a widget answers *"what does the user see?"*, an action
answers *"what happens when the user acts?"*. Actions carry their business logic
in a typed, authorization-aware, undoable unit that plugs straight into a
widget's `onPressed` / `onTap` callback.

The design goal is the same separation Tom applies everywhere: a button does not
*contain* the logic to save an order, it *triggers* a `SaveOrderAction`. That
keeps widgets dumb and reusable, and keeps logic testable without a widget tree.

## Table of Contents

- [Overview](#overview)
- [`TomAction` — the unit of behaviour](#tomaction--the-unit-of-behaviour)
- [`TomActionController` — grouping & canonical paths](#tomactioncontroller--grouping--canonical-paths)
- [`TomActionContext` — typed inputs](#tomactioncontext--typed-inputs)
- [Undo: `TomActionUndo`, `TomActionTransaction`, `TomUndoHistory`](#undo-tomactionundo-tomactiontransaction-tomundohistory)
- [`TomActionTrigger` — wiring into widgets](#tomactiontrigger--wiring-into-widgets)
- [Composite actions](#composite-actions)
- [Authorization](#authorization)
- [Dependencies](#dependencies)

---

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `TomAction<TContext, TUndo>` | abstract class | A single unit of behaviour: typed context, authorization, optional undo. |
| `TomSimpleAction<TContext>` | abstract class | A `TomAction` that produces no undo state. |
| `TomActionController` | class | Owns a group of related actions and supplies the first segment of their canonical path. |
| `TomActionContext` | class | Base for the typed inputs an action needs; domain contexts extend it. |
| `TomActionUndo` | abstract interface class | Marker for undo-state objects returned from `execute`. |
| `TomActionTransaction` | class | Groups sub-actions into one atomic undo entry. |
| `TomUndoHistory` | class | Application-level undo/redo stack of transactions. |
| `TomActionTrigger<TContext, TUndo>` | class | Adapts an action to a `VoidCallback` for a widget, recording undo state. |
| `TomCompositeAction` | class | Runs a list of guarded steps as one action. |
| `TomUndoAction` / `TomRedoAction` | classes | Coordinator actions that drive a `TomUndoHistory`. |

## `TomAction` — the unit of behaviour

`TomAction<TContext, TUndo>` is generic over its **context** (the typed inputs it
needs) and its **undo state** (what it must remember to reverse itself). A
concrete action overrides:

| Member | Default | Override when |
| ------ | ------- | ------------ |
| `execute(context, tx)` | *abstract* | always — this is the behaviour |
| `canExecute(context)` | `true` | the action is conditionally available (empty list, invalid form) |
| `isUndoable` | `false` | the action can be reversed |
| `undo(undoState)` | no-op | `isUndoable` is `true` |

`execute` returns a `TUndo?`: the snapshot needed to reverse the change, or
`null` when there is nothing to undo. Actions are **stateless** — they hold no
mutable state between invocations; everything they touch arrives through the
context.

`TomSimpleAction<TContext>` is the convenience base for the (common) case of an
action that is never undoable: override `executeSimple(context, tx)` and it
returns `null` for you.

## `TomActionController` — grouping & canonical paths

Every action belongs to a `TomActionController`. The controller has a unique
`controllerId`, which becomes the first segment of each action's
**canonical path**:

```
canonicalPath = '<controllerId>.<actionId>'
```

That path is the key for authorization (`TomAuthorization.resolveAuth`) and for
resource lookups (`label`, `tooltip`, `iconName` via `TomCtr`). A typical
controller declares its actions as fields:

```dart
class OrderController extends TomActionController {
  OrderController() : super(controllerId: 'orderMgmt');

  late final create = CreateOrderAction(controller: this);
  late final delete = DeleteOrderAction(controller: this);
}
```

Actions register themselves with the controller in their constructor, so
`controller.actions` and `controller.findAction(id)` see them without extra
wiring.

## `TomActionContext` — typed inputs

`TomActionContext` is the base for everything an action reads. Domain contexts
extend it with the concrete data and collaborators the action needs:

```dart
class OrderActionContext extends TomActionContext {
  final Order selectedOrder;
  final OrderRepository orderRepo;
  OrderActionContext({required this.selectedOrder, required this.orderRepo});
}
```

Passing inputs through a context (rather than action fields) is what keeps the
action stateless and the same action instance reusable across invocations.

## Undo: `TomActionUndo`, `TomActionTransaction`, `TomUndoHistory`

Undo is built from three cooperating pieces:

| Piece | Role |
| ----- | ---- |
| `TomActionUndo` | Tag interface for the snapshot `execute` returns. |
| `TomActionTransaction` | Collects one *or many* sub-action undo states into a single atomic entry, then `commit`s. |
| `TomUndoHistory` | A bounded undo/redo stack of committed transactions. |

A transaction is the unit the history reverses. One user gesture that fans out
to several sub-actions records each into the same transaction, so a single undo
reverses the whole gesture in reverse order:

```dart
final tx = TomActionTransaction(label: 'Move items');
for (final item in selected) {
  tx.run(moveAction, MoveContext(item: item, to: folder));
}
tx.commit();
undoHistory.push(tx);
```

`run` is the one place that pairs *executing* an action with *recording* it: an
action contributes an undo entry only when it returned a state **and** declares
itself `isUndoable`. `TomActionTrigger` and `TomCompositeAction` both dispatch
through it, so the rule cannot drift between them.
`record` remains available for the rare case where you hold an undo state that
did not come from a call you just made.

`TomUndoHistory` enforces the invariants: it refuses to `push` an uncommitted or
empty transaction, clears the redo stack on every new push, trims to `maxSize`,
and exposes `canUndo` / `canRedo` / `undoLabel` / `redoLabel` for driving UI.
`TomUndoAction` and `TomRedoAction` are ready-made coordinator actions that wrap
a history so undo/redo themselves become first-class, authorizable actions.

**The two directions are not symmetric, and this is the one thing to know about
the class.** `undo()` runs the transaction's `undoAll()` and genuinely reverses
its effects. `redo()` only moves the transaction back onto the undo stack — it
re-applies nothing, and application state does not change. The reason is what a
transaction records: `(action, undoState)` pairs, which is precisely what
`TomAction.undo(TUndo undoState)` needs. Running forward again would mean
`TomAction.execute`, which also takes a `TContext`, and the context an action
ran with is never recorded — so the history has no argument to re-execute with.
An action that needs true redo implements it itself, executing forward with a
context the application still holds.

## `TomActionTrigger` — wiring into widgets

`TomActionTrigger` is the bridge from an action to a widget callback. Its
`trigger` (or `callback`) does the full dance so the widget doesn't have to:

1. build the context via `contextBuilder`,
2. short-circuit through `canExecute` (firing `onCannotExecute`),
3. open a `TomActionTransaction`, run `execute`, and record undo state when the
   action `isUndoable`,
4. `commit`, push onto the `undoHistory` if the transaction recorded anything,
5. fire `onExecuted`.

```dart
TomElevatedButton(
  authorizer: saveAction.authorizer,
  onPressed: TomActionTrigger(
    action: saveAction,
    contextBuilder: () => OrderActionContext(selectedOrder: order, orderRepo: repo),
    undoHistory: appUndoHistory,
  ).trigger,
)
```

## Composite actions

`TomCompositeAction` runs a list of `TomCompositeStep`s in order, each with its
own `contextBuilder` and optional `guard`. A step is *blocked* when its `guard`
returns false **or** when the step's own action refuses via `canExecute` — a
composite with no guards at all can still be blocked. `stopOnBlockedStep`
chooses between *stop at the first blocked step* and *skip blocked steps and
continue*.

A composite's `canExecute` reports exactly whether `execute` would run at least
one step, so gating a button on it cannot produce an enabled control that does
nothing. It therefore checks both blocking conditions and respects
reachability: under `stopOnBlockedStep` only the first step can run, so a
runnable step behind a blocked one does not make the composite executable.

Sub-step undo states are recorded into the surrounding transaction, so a
composite is still one atomic undo entry.

The everyday two-sided shapes — *save-and-close*, *validate-and-submit* — are
just two-step composites. There is no separate two-action class, and the
composite covers the case in full:

- **Different context types per side.** A `List<TomCompositeStep>` holds a
  `TomCompositeStep<CtxA>` and a `TomCompositeStep<CtxB>` side by side, because
  the step's type parameter is covariant and each step pairs its own action
  with its own builder.
- **Independent sides.** Where neither step should block the other, pass
  `stopOnBlockedStep: false`; the composite then runs whichever steps are
  runnable and its `canExecute` is true when any of them is.

Both steps run forward, in list order, with no reversal between them —
reversal is `TomActionTransaction`'s job.

## Authorization

`TomAction` implements `TomAuthorizable`, so it participates in the same
four-state authorization model as widgets (`tomId` is the `actionId`,
`canonicalPath` is the auth key, optional `tomGroup` applies collective modes via
`effectiveAuthState`). `action.authorizer` produces a `TomAuthorizer` with the
default *widget-full + action-none ⇒ disabled* pattern, ready to hand to a
button so its enabled/disabled state follows the action's authorization without
any extra glue.

## Dependencies

- `package:tom_core_kernel/tom_core_kernel.dart` — `TomAuthorizable`,
  `TomAuthorizationGroup`, `TomAuthState`, `TomAuthorization`, `TomAuthorizer`,
  `TomScope`.
- `../widget_base/tom_construction_helpers.dart` — `TomCtr` for `label` /
  `tooltip` / `iconName` resource resolution.
- `package:flutter/widgets.dart` — `VoidCallback` (used by `TomActionTrigger`).

> The action classes themselves are pure logic and need no widget tree. Because
> the package barrel pulls in `flutter/material` (→ `dart:ui`), run the example
> under the Flutter toolchain — see
> [`example/actions/actions_example.dart`](../example/actions/actions_example.dart),
> exercised by `flutter test`.
