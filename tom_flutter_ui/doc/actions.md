# Actions Module

`actions/` is the **behavioural** layer of `tom_flutter_ui` — the counterpart to
the widget layer. Where a widget answers *"what does the user see?"*, an action
answers *"what happens when the user acts?"*. Actions carry their business logic
in a typed, authorization-aware, undoable unit that plugs straight into a
widget's `onPressed` / `onTap` callback.

The design goal is the same separation Tom applies everywhere: a button does not
*contain* the logic to save an order, it *triggers* a `SaveOrderAction`. That
keeps widgets dumb and reusable, and keeps logic testable without a widget tree.

*Symbol-level reference: [api/api_summary_actions.md](api/api_summary_actions.md)
— every public type with its members and signatures. This document explains how
they fit together.*

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
| `TomActionController` | class | Owns a group of related actions, supplies the first segment of their canonical path, and the authorization group they join by default. |
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
| `isRedoable` | `false` | the action can be re-applied after an undo |
| `redo(undoState)` | no-op | `isRedoable` is `true` |

`isAuthorized` is not overridable: it is `effectiveAuthState.isInteractive`, and
gating belongs in `canExecute`.

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

### Action ids are unique per controller

Registering a second action with an id already on the controller throws a
`StateError`. The id is what distinguishes one action from another *within* a
controller, and a duplicate does more than shadow a lookup: both actions resolve
the canonical path `<controllerId>.<actionId>`, so they share **one**
authorization decision and **one** set of label, tooltip and icon keys — two
behaviours wearing one caption and one permission, with the second unreachable
through `findAction` for the controller's lifetime.

The same id on a *different* controller is fine: `orders.delete` and
`users.delete` are different paths with nothing to collide.

The throw lands at the definition site, because registration happens in the
`TomAction` constructor. With the `late final` declaration above, that is when
the **second** of the two colliding fields is first read — later than the
controller's construction, and still the earliest moment at which a duplicate
exists. Reading only one of them constructs only one action, which has nothing
to collide with and is correctly allowed.

`TomForm` implements `TomActionController` rather than extending it, so it keeps
its own action list; both registrations route through
`TomActionController.addUniquely`, so the rule cannot hold in one and not the
other.

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

That independence is the reason there is a **second**, unrelated scope on the
context — see [`TomActionContext.scope`](#the-invocation-frame). A construction
scope says where an action *lives* and must not move; a context scope says where
one invocation is *happening*.

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

### The invocation frame

`TomActionContext.scope` is the one scope in the module that is **not** a
construction frame. It names where this particular invocation is happening, and
it is installed — via `context.runInScope(...)` — around every consult of the
action with that context:

| Consulted from | What runs in the frame |
| -------------- | ---------------------- |
| `TomActionTrigger.trigger` | `canExecute`, then `execute` via the transaction |
| `TomCompositeAction` | each step's `canExecute`, then its `execute` |
| `TomActionTransaction.run` | `execute` |

The gate and the body go through the same frame deliberately: a `canExecute`
that read a different scope from the `execute` it guards would be worse than no
guard.

**Null is the ordinary case**, and it means *the ambient frame* — the context is
built by a `contextBuilder` called at the moment of the gesture, so the zone in
force then is usually already right, and capturing it would be redundant.
Setting the field is for the case where it is not: work dispatched from a
callback, a timer or an isolate boundary, where the gesture's frame is no longer
installed.

It does **not** move the action's canonical path or its authorization. Those
come out of `constructionScope` and are fixed; what the invocation frame reaches
is everything downstream that reads `TomScope.current` — a nested controller
built during the action, a resource lookup, a widget shown in response.

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
For an undo state you hold that did not come from a call you just made,
`action.recordInto(tx, undoState)` files it. It is a method on the **action**,
not the transaction, and that is load-bearing: `TUndo` is then the receiver's
own type argument, so pairing one action's state with another is a compile
error at that call rather than a `TypeError` from inside the history when
somebody presses undo. A transaction method taking `(action, undoState)` cannot
give you that — Dart's class type parameters are covariant, so inference widens
the undo type and accepts anything.

`TomUndoHistory` enforces the invariants: it refuses to `push` an uncommitted or
empty transaction, clears the redo stack on every new push, and trims to
`maxSize`. `TomUndoAction` and `TomRedoAction` are ready-made coordinator
actions that wrap a history so undo/redo themselves become first-class,
authorizable actions.

### Undo and redo are both real, and redo is opt-in per action

`undo()` runs the transaction's `undoAll()`, reversing the entries in reverse
order. `redo()` runs `redoAll()`, re-applying them in the order they originally
executed — reverse one way and forward the other, because a later step may
depend on an earlier one.

What redo runs is **not** `execute`. A transaction records `(action, undoState)`
pairs and never the `TContext` an action ran with — contexts are built per
invocation by a `contextBuilder` and are not guaranteed valid later — so the
history has no argument to re-execute with. `TomAction` therefore carries a
forward hook beside its reverse one, taking the argument the history does hold:

| | reverse | forward |
| --- | --- | --- |
| hook | `void undo(TUndo undoState)` | `void redo(TUndo undoState)` |
| opt-in flag | `bool get isUndoable` | `bool get isRedoable` |
| default | no-op, `false` | no-op, `false` |

The undo state generally names the *target* of the change while the action holds
the *parameters*, so one snapshot serves both directions:

```dart
@override
bool get isRedoable => true;

@override
void redo(IncrementUndo undoState) =>
    undoState.counter.value = undoState.previous + step;
```

Because the hook is opt-in, a history can hold undone transactions that nothing
can put back. **`canRedo` accounts for that**: it is true only when the redo
stack is non-empty *and* every action in the transaction on top declares
`isRedoable`. `redoLabel` is null in the same case. So a toolbar button bound to
`TomRedoAction` — which gates on `canRedo` — is disabled both when there is
nothing to redo and when what there is cannot be redone, rather than enabling
itself and doing nothing when pressed. `redoCount` counts what has been undone,
not what can be put back; drive buttons from `canRedo`.

### A transaction is applied or reversed, never both

`isUndone` is the one piece of state that says which. `undoAll` sets it and
`redoAll` clears it, and each refuses when the transaction is already the way it
would leave it: undoing twice would apply the same undos again — invisible for
an undo that assigns a previous value, a duplicated row for one that restores a
deleted record — and redoing a transaction that is not undone would report a
re-application that did not happen. `redoAll` also throws when the transaction is
not redoable, naming the action that lacks the hook, rather than running no-op
redos and claiming the effects are back.

Both checks run before any entry is touched, and both `undo()` and `redo()` ask
the transaction *before* they move either stack — so a refusal leaves the
history exactly as it was rather than stranding a transaction on neither.

`rollback` is deliberately not symmetric: it also marks the transaction undone,
but a second call is a silent no-op. It is the failure path, reached from error
handling that may itself run more than once, and throwing there would replace
the original failure with this one.

## `TomActionTrigger` — wiring into widgets

`TomActionTrigger` is the bridge from an action to a widget callback. Its
`trigger` (or `callback`) does the full dance so the widget doesn't have to:

1. refuse outright when authorization does not permit the action
   (`isAuthorized`), firing `onCannotExecute`,
2. build the context via `contextBuilder`,
3. short-circuit through `canExecute` (firing `onCannotExecute`),
4. open a `TomActionTransaction`, run `execute`, and record undo state when the
   action `isUndoable`,
5. `commit`, push onto the `undoHistory` if the transaction recorded anything,
6. fire `onExecuted`.

Step 1 precedes step 2 deliberately: a `contextBuilder` is application code and
may read the very data the refusal is about, so a refused action builds nothing.
`onCannotExecute` covers both refusals with one callback, because the caller can
tell them apart without being told — `action.isAuthorized` answers which.

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
returns false, when the step's own action is unauthorized, or when that action
refuses via `canExecute` — a composite with no guards at all can still be
blocked. `stopOnBlockedStep`
chooses between *stop at the first blocked step* and *skip blocked steps and
continue*.

A composite's `canExecute` reports exactly whether `execute` would run at least
one step, so gating a button on it cannot produce an enabled control that does
nothing. It therefore checks every blocking condition and respects
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

### Where an action's group comes from

Declared once on the controller, or per action:

| Given | The action's `tomGroup` |
| ----- | ----------------------- |
| `TomAction(tomGroup: …)` | that group — it overrides the controller's |
| nothing, controller has `tomGroup` | the **controller's** group |
| nothing, controller has none | null, and `effectiveAuthState` equals `authState` |

The controller-level group is the collective half: declaring it once covers
every action the controller owns, which is what "collective action control" has
to mean if it is to save the per-action wiring. The inherited group is a real
membership — the action registers with it, so the group can reach the action
back — and its ceiling is still looked up in the **action's** frame, not the
group object's, keeping the `<prefix>.<id>` pair above intact.

Resolved when the action is *constructed*, since that is when it registers. A
controller that assigns its group rather than taking it in the constructor —
`TomForm` does — must do so before its actions are built; for a form, while it
prepares itself, before any `late final` action field is first read.

`action.authorizer` produces a `TomAuthorizer` with the
default *widget-full + action-none ⇒ disabled* pattern, ready to hand to a
button so its enabled/disabled state follows the action's authorization without
any extra glue.

### Authorization also refuses execution

A button bound to `authorizer` is what normally stops an unauthorized action —
it is hidden or disabled, so there is nothing to press. But a trigger can be
reached without one: a keyboard shortcut, a test, a callback holding `trigger`
directly. So `TomActionTrigger` refuses before it dispatches, and
`TomCompositeAction` refuses a step the same way, both reading one predicate:

```dart
bool get isAuthorized => effectiveAuthState.isInteractive;
```

`isInteractive` is `full` and nothing else — the kernel's own predicate, and the
same one that decides whether a widget is operable. Using it rather than *not
`none` and not `disabled`* is what keeps the trigger and the button from
disagreeing about a `read` action, which would be the same divergence one state
over. It reads `effectiveAuthState`, so a group ceiling that hides an otherwise
permitted action blocks it too.

**This is not a security boundary** — the server enforces, and a client that
wants to call the action anyway can. It is what stops the framework itself from
silently running something the user cannot see.

A step's authorization is the **step action's**, not the composite's. The
composite is one authorizable and each step another; a trigger checks the
composite, and that says nothing about what the composite then reaches.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `flutter` | package | `tom_action_trigger.dart` | `package:flutter/widgets.dart` only — the trigger is a widget, not a Material one |
| `tom_core_kernel` | package | `tom_action.dart`, `tom_action_context.dart`, `tom_action_controller.dart` | `TomAuthorizable`, `TomAuthorizationGroup`, `TomAuthState`, `TomAuthorization`, `TomAuthorizer`, `TomScope` |
| [widget_base](widget_base.md) | module | `tom_action.dart`, `tom_action_controller.dart` | `TomCtr` for `label` / `tooltip` / `iconName` resource resolution |

> The action classes themselves are pure logic and need no widget tree. Because
> the package barrel pulls in `flutter/material` (→ `dart:ui`), run the examples
> under the Flutter toolchain. Both assert their own results, so they fail
> rather than merely print when a behaviour drifts:
>
> | Example | Covers |
> | ------- | ------ |
> | [`actions_example.dart`](../example/actions/actions_example.dart) | The quick start — a controller and its actions, a transaction, the trigger → history wiring, undo and redo, `canExecute`, a guarded composite. |
> | [`actions_advanced_example.dart`](../example/actions/actions_advanced_example.dart) | The coordinator actions, the authorization surface, resource-resolved captions, the transaction API including `rollback`, construction and invocation scope frames, controller groups, and the duplicate-id refusal. |
