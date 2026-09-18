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
| `TomCompositeStep<TContext>` | class | One step of a `TomCompositeAction`: the action to run and the guard that decides whether it runs. |
| `TomUndoAction` / `TomRedoAction` | classes | Coordinator actions that drive a `TomUndoHistory`. |
| `TomUndoRedoContext` | class | The `TomActionContext` those two coordinators take — a scope and nothing else, because undoing needs no domain input. |

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
canonicalPrefix = '<scopePath>.<controllerId>'
canonicalPath   = '<scopePath>.<controllerId>.<actionId>'
```

The scope segment is dropped at the root, so an action built outside any
`TomScope` addresses itself as the bare `orderMgmt.create` — same rule, and the
same `TomScopePath`, as every widget path in the package.

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

### The frame a path is built in

Both the controller and each action capture a `constructionScope` — the
explicit `scope` they were given, or the ambient `TomScope.current` at the
moment they were built — and every path they produce comes out of that one
frame:

| Element | Frame |
| ------- | ----- |
| `TomActionController` | its own `scope`, else `TomScope.current` at construction |
| `TomAction` | its own `scope`, else its **controller's** frame |
| `TomForm` (which *implements* `TomActionController`) | the form's own `scope`; its `canonicalPrefix` is the form's `basePath` |

Falling back to the controller rather than to the ambient scope is what makes
the usual declaration above work: `late final` action fields are constructed on
first *read*, long after the controller was built and typically outside
whatever scope was installed then. Inheriting the controller's frame keeps the
whole controller in one place.

Capturing the frame once — instead of reading `TomScope.current` per lookup —
is also what makes an action's authorization answer independent of where it is
read from. An action is consulted from screens, triggers and group inspection
alike; only the zone it was built in describes where it actually lives.

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

Because redo re-applies nothing, a transaction's undos stay spent across it, and
**a transaction can be undone once**. `undoAll` throws a `StateError` on a
second call, and `undo()` asks the transaction before it moves either stack, so
a refused undo leaves the history exactly as it was. The sequence that reaches
it is three keystrokes — `undo(); redo(); undo();` — and what it would otherwise
do depends entirely on the action: an undo that assigns (`counter.value =
previous`) is unchanged by a repeat, while an undo that restores a deleted row
inserts it a second time. The throw names the sequence, so the failure arrives
at the call that is wrong rather than as data nobody can account for later. A
transaction reports this through `isUndone`.

`rollback` is deliberately not symmetric: it also marks the transaction undone,
but a second call is a silent no-op. It is the failure path, reached from error
handling that may itself run more than once, and throwing there would replace
the original failure with this one.

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
`effectiveAuthState`). The group is resolved in the action's
`constructionScope` — the frame `canonicalPath` was built in. The two are a
`<prefix>.<id>` pair, and a prefix that differed between them would apply a
ceiling belonging to some other member, or none at all.
`action.authorizer` produces a `TomAuthorizer` with the
default *widget-full + action-none ⇒ disabled* pattern, ready to hand to a
button so its enabled/disabled state follows the action's authorization without
any extra glue.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `flutter` | package | `tom_action_trigger.dart` | `package:flutter/widgets.dart` only — the trigger is a widget, not a Material one |
| `tom_core_kernel` | package | `tom_action.dart`, `tom_action_context.dart`, `tom_action_controller.dart` | `TomAuthorizable`, `TomAuthorizationGroup`, `TomAuthState`, `TomAuthorization`, `TomAuthorizer`, `TomScope` |
| [widget_base](widget_base.md) | module | `tom_action.dart`, `tom_action_controller.dart` | `TomCtr` for `label` / `tooltip` / `iconName` resource resolution |

> The action classes themselves are pure logic and need no widget tree. Because
> the package barrel pulls in `flutter/material` (→ `dart:ui`), run the example
> under the Flutter toolchain — see
> [`example/actions/actions_example.dart`](../example/actions/actions_example.dart),
> exercised by `flutter test`.
