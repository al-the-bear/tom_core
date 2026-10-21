# Tom Flutter UI API Reference: Actions Module

The behavioural counterpart to widgets: business logic as typed, stateless,
authorizable objects with optional undo and redo.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Exported Surface](#exported-surface)
- [Classes](#classes)
  - [TomActionUndo](#tomactionundo)
  - [TomAction\<TContext, TUndo\>](#tomactiontcontext-tundo)
  - [TomSimpleAction\<TContext\>](#tomsimpleactiontcontext)
  - [TomActionContext](#tomactioncontext)
  - [TomActionController](#tomactioncontroller)
  - [TomActionTransaction](#tomactiontransaction)
  - [TomActionTrigger\<TContext, TUndo\>](#tomactiontriggertcontext-tundo)
  - [TomUndoHistory](#tomundohistory)
  - [TomUndoAction](#tomundoaction)
  - [TomRedoAction](#tomredoaction)
  - [TomUndoRedoContext](#tomundoredocontext)
  - [TomCompositeAction](#tomcompositeaction)
  - [TomCompositeStep\<TContext\>](#tomcompositesteptcontext)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/actions/actions.dart`, `lib/src/actions/tom_action.dart`, `lib/src/actions/tom_action_context.dart`, `lib/src/actions/tom_action_controller.dart`, `lib/src/actions/tom_action_transaction.dart`, `lib/src/actions/tom_action_trigger.dart`, `lib/src/actions/tom_composite_action.dart`, `lib/src/actions/tom_undo_history.dart`.

The module `lib/src/actions/` is barrelled by `lib/src/actions/actions.dart`.

An action is a **stateless** object that holds no data between invocations:
everything it operates on arrives through a typed context built per invocation.
It carries an id, a controller, an authorization state derived from its
canonical path, and optional hooks for reversing and re-applying what it did.

Three concerns meet here and are worth separating before reading the tables:

| Concern | Carried by |
| ------- | ---------- |
| *What the behaviour is* | `TomAction` and its subclasses |
| *Where it stands* — path, authorization, group, scope frame | `TomActionController` + `TomAction.canonicalPath` |
| *How one gesture becomes an undoable unit* | `TomActionTransaction` + `TomUndoHistory` |

Dispatch belongs to none of them: `TomActionTrigger` binds an action, a context
builder and an optional history into a `VoidCallback` a widget can take. A
controller **owns and names** actions; it does not run them.

## Class Hierarchy

```
Object
├── TomAction<TContext, TUndo>          (abstract, implements TomAuthorizable)
│   ├── TomSimpleAction<TContext>       (abstract — TUndo fixed to TomActionUndo)
│   │   ├── TomUndoAction
│   │   └── TomRedoAction
│   └── TomCompositeAction              (TomAction<TomActionContext, TomActionUndo>)
├── TomActionContext
│   └── TomUndoRedoContext
├── TomActionController
├── TomActionTransaction
├── TomActionTrigger<TContext, TUndo>
├── TomUndoHistory
└── TomCompositeStep<TContext>

(interfaces)
└── TomActionUndo                       (abstract interface class — marker)
```

`TomAuthorizable` is declared in `tom_core_kernel`
(`lib/src/tombase/security/tom_authorization.dart`) and reaches this module
through the `tom_core_kernel` barrel, as do `TomAuthState`, `TomAuthorization`,
`TomAuthorizationGroup`, `TomAuthorizer` and `TomScope`.

## Exported Surface

`actions.dart` exports seven files and every public type in them:

| File | Public types |
| ---- | ------------ |
| `tom_action.dart` | `TomActionUndo`, `TomAction`, `TomSimpleAction` |
| `tom_action_controller.dart` | `TomActionController` |
| `tom_action_context.dart` | `TomActionContext` |
| `tom_action_transaction.dart` | `TomActionTransaction` |
| `tom_action_trigger.dart` | `TomActionTrigger` |
| `tom_undo_history.dart` | `TomUndoHistory`, `TomUndoAction`, `TomRedoAction`, `TomUndoRedoContext` |
| `tom_composite_action.dart` | `TomCompositeAction`, `TomCompositeStep` |

Thirteen public types, no top-level functions, no constants. The module's only
public static member is `TomActionController.addUniquely`.

## Classes

### TomActionUndo

Marker interface for the snapshot an action returns from `execute` — whatever it
needs to reverse itself later. It declares no members; implementing it is what
makes a type usable as a `TUndo`.

**Kind:** `abstract interface class`

```dart
abstract interface class TomActionUndo {}
```

### TomAction\<TContext, TUndo\>

The base class for all actions.

**Kind:** `abstract class`
**Implements:** `TomAuthorizable`
**Type Parameters:** `<TContext extends TomActionContext, TUndo extends TomActionUndo>`

#### Constructors

```dart
TomAction({
  required String actionId,
  required TomActionController controller,
  TomScope? scope,
  TomAuthorizationGroup? tomGroup,
})
```

Registers the action with its group (when it resolves to one) and with its
controller, so construction is the point at which an action becomes
discoverable. The controller refuses a duplicate `actionId` — see
[`TomActionController.addUniquely`](#static-methods).

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `actionId` | `String` | Unique id within the controller. |
| `controller` | `TomActionController` | The owner; supplies the canonical-path prefix, the fallback scope frame and the fallback group. |
| `scope` | `TomScope?` | Explicit frame for this action's paths, overriding the controller's. |
| `tomGroup` | `TomAuthorizationGroup?` | Resolved at construction: the action's own group when given one, otherwise `controller.tomGroup`. |
| `constructionScope` | `TomScope` | The frame every path this action produces comes out of: `scope ?? controller.constructionScope`. |
| `tomId` | `String?` | `TomAuthorizable` identity — the `actionId`. |
| `canonicalPath` | `String` (late final) | `<scopePath>.<controllerId>.<actionId>`, the scope segment dropped at the root. The key for authorization and for every resource lookup below. |
| `isUndoable` | `bool` | Whether `undo` is implemented. Defaults to `false`. |
| `isRedoable` | `bool` | Whether `redo` is implemented. Defaults to `false`, independently of `isUndoable`. |
| `authState` | `TomAuthState` | `TomAuthorization.resolveAuth(canonicalPath)`. |
| `effectiveAuthState` | `TomAuthState` | `authState` with the group's mode folded over it, resolved in `constructionScope`. |
| `isAuthorized` | `bool` | `effectiveAuthState.isInteractive` — read before dispatch by `TomActionTrigger` and `TomCompositeAction`. |
| `authorizer` | `TomAuthorizer` | `TomAuthorizer.fromAction`, carrying the *widget full + action none ⇒ disabled* rule. |
| `label` | `String` | `<canonicalPath>.label` from resources, falling back to `actionId`. |
| `tooltip` | `String?` | `<canonicalPath>.tooltip` from resources, or null. |
| `iconName` | `String?` | `<canonicalPath>.iconName` from resources, or null. The widget maps the name to an icon. |

#### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `canExecute(TContext context)` | `bool` | Business-rule gate. Defaults to `true`; override for conditional availability. |
| `execute(TContext context, TomActionTransaction tx)` | `TUndo?` | **Abstract.** Performs the behaviour and returns the undo snapshot, or null when there is nothing to reverse. |
| `undo(TUndo undoState)` | `void` | Reverses the action. No-op by default; called only when `isUndoable`. |
| `redo(TUndo undoState)` | `void` | Re-applies the action. No-op by default; called only when `isRedoable`. Takes the undo state rather than replaying `execute`, because a transaction never keeps the `TContext`. |
| `recordInto(TomActionTransaction tx, TUndo undoState)` | `void` | Files an undo state this action produced into `tx`, with the redo call too when `isRedoable`. On the action rather than the transaction, so the receiver fixes `TUndo` and another action's state is a compile error. |
| `toString()` | `String` | `TomAction(<canonicalPath>)`. |

### TomSimpleAction\<TContext\>

Convenience base for an action that produces no undo state.

**Kind:** `abstract class`
**Extends:** `TomAction<TContext, TomActionUndo>`
**Type Parameters:** `<TContext extends TomActionContext>`

#### Constructors

```dart
TomSimpleAction({
  required String actionId,
  required TomActionController controller,
  TomScope? scope,
  TomAuthorizationGroup? tomGroup,
})
```

#### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `executeSimple(TContext context, TomActionTransaction tx)` | `void` | **Abstract.** The behaviour. Implement this instead of `execute`. |
| `execute(TContext context, TomActionTransaction tx)` | `TomActionUndo?` | Calls `executeSimple` and returns null. |

Because it always returns null, a `TomSimpleAction` contributes no undo entry
even if `isUndoable` were overridden — `TomActionTransaction.run` records only
when both conditions hold.

### TomActionContext

The base for everything an action reads. Domain contexts extend it with the
concrete data and collaborators their action needs; passing inputs this way is
what keeps the action stateless and one instance reusable across invocations.

**Kind:** `class`

#### Constructors

```dart
const TomActionContext()
```

Carries no scope: an action is gated and executed in whatever frame is current
when it is consulted. The frame its path, group and resources resolve in is
`TomAction.scope`, fixed at construction.

### TomActionController

Owns and names a group of related actions, and supplies the first segment of
their canonical paths. It does not dispatch them — see
[`TomActionTrigger`](#tomactiontriggertcontext-tundo).

**Kind:** `class`

#### Constructors

```dart
TomActionController({
  required String controllerId,
  TomScope? scope,
  TomAuthorizationGroup? tomGroup,
})
```

#### Static Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `addUniquely(List<TomAction> registered, TomAction action)` | `void` | Appends `action`, throwing `StateError` when its `actionId` is already present. The single definition of the rule: `TomForm` implements this interface rather than extending it and registers through the same method. |

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `controllerId` | `String` | Unique id; the path segment below the scope. |
| `scope` | `TomScope?` | Explicit frame, overriding the ambient one at construction. |
| `tomGroup` | `TomAuthorizationGroup?` | The group every action this controller owns joins by default. |
| `constructionScope` | `TomScope` | `scope ?? TomScope.current` at construction; the frame the controller and, by default, its actions resolve in. |
| `actions` | `List<TomAction>` | Unmodifiable view of the registered actions. |
| `canonicalPrefix` | `String` (late final) | `<scopePath>.<controllerId>`, or the bare id at the root. |
| `authState` | `TomAuthState` | `TomAuthorization.resolveAuth(canonicalPrefix)` — the controller as a whole. |

#### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `registerAction(TomAction action)` | `void` | Called by the `TomAction` constructor. Throws `StateError` on a duplicate id. |
| `findAction(String actionId)` | `TomAction?` | The action with that id, or null. At most one can match. |
| `toString()` | `String` | `TomActionController(<controllerId>)`. |

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `dispose` | `void dispose()` | Disposes every action this controller owns, which takes each out of its group. |

### TomActionTransaction

The atomic unit the undo history reverses. One user gesture that fans out to
several sub-actions records each into the same transaction, so a single undo
reverses the whole gesture.

**Kind:** `class`

#### Constructors

```dart
TomActionTransaction({required String label})
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `label` | `String` | Human-readable name, surfaced as `TomUndoHistory.undoLabel` / `redoLabel`. |
| `hasEntries` | `bool` | Whether anything was recorded. |
| `isCommitted` | `bool` | Whether `commit` has run; recording afterwards throws. |
| `isUndone` | `bool` | Whether the effects are currently reversed. One flag, set by `undoAll`/`rollback` and cleared by `redoAll`. |
| `isRedoable` | `bool` | True only when there is at least one entry and every entry's action declares `TomAction.isRedoable`. |
| `entryCount` | `int` | Number of recorded entries. |

#### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `run<TContext, TUndo>(TomAction<TContext, TUndo> action, TContext context)` | `void` | Executes the action and records its undo state when it returned one **and** declares `isUndoable`. The one place that pairs executing with recording. |
| `record<TUndo>(TomAction action, TUndo undoState)` | `void` | Records an undo state obtained elsewhere. Throws `StateError` once committed or rolled back. |
| `commit()` | `void` | Seals the transaction against further recording. |
| `rollback()` | `void` | Reverses the entries in reverse order, marking the transaction undone. A second call is a silent no-op — it is the failure path. |
| `undoAll()` | `void` | Reverses the entries in reverse order. Throws `StateError` when already undone, checked before any entry is touched. When `isRedoable` is true the pass is atomic: an entry that throws has the ones already undone put back, and the transaction stays applied. |
| `redoAll()` | `void` | Re-applies the entries in the order they executed. Throws `StateError` when the transaction is not undone, and when `isRedoable` is false — naming the action that lacks the hook. Atomic: an entry that throws has the ones already redone undone again, and the transaction stays undone. |
| `toString()` | `String` | `TomActionTransaction(<label>, entries: <n>)`. |

### TomActionTrigger\<TContext, TUndo\>

The bridge from an action to a widget callback: it runs the whole per-gesture
protocol so the widget does not have to.

**Kind:** `class`
**Type Parameters:** `<TContext extends TomActionContext, TUndo extends TomActionUndo>`

#### Constructors

```dart
TomActionTrigger({
  required TomAction<TContext, TUndo> action,
  required TContext Function() contextBuilder,
  TomUndoHistory? undoHistory,
  VoidCallback? onExecuted,
  VoidCallback? onCannotExecute,
})
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `action` | `TomAction<TContext, TUndo>` | The action to dispatch. |
| `contextBuilder` | `TContext Function()` | Builds the context, once per gesture. Not called at all when authorization refuses. |
| `undoHistory` | `TomUndoHistory?` | Receives the committed transaction when it recorded anything. Null discards the undo state. |
| `onExecuted` | `VoidCallback?` | Fired after a successful execution. |
| `onCannotExecute` | `VoidCallback?` | Fired when the action was **not** run — by authorization or by `canExecute`. `action.isAuthorized` distinguishes the two. |
| `callback` | `VoidCallback` | `trigger` as a callback, for `onPressed` / `onTap`. |

#### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `trigger()` | `void` | Refuse when unauthorized → build the context → consult `canExecute` → open a transaction labelled `action.label`, execute and record → commit and push → fire `onExecuted`. |

### TomUndoHistory

A bounded undo/redo stack of committed transactions, on `tom_forge_core`'s
`ForgeUndoStack`: a transaction whose undo or redo throws stays where it was.

**Kind:** `class`

#### Constructors

```dart
TomUndoHistory({int maxSize = 100, void Function()? onChanged})
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `maxSize` | `int` | Cap on the undo stack; the oldest entry is trimmed past it. |
| `onChanged` | `void Function()?` | Called on every mutation, so a toolbar stays in step. |
| `canUndo` | `bool` | Whether the undo stack holds anything. |
| `canRedo` | `bool` | Whether the redo stack is non-empty **and** its top transaction is redoable. |
| `undoLabel` | `String?` | Label of the next undoable transaction, or null. |
| `redoLabel` | `String?` | Label of the next redoable transaction, or null — including when the top of the redo stack cannot be re-applied. |
| `undoCount` | `int` | Size of the undo stack. |
| `redoCount` | `int` | Size of the redo stack. Counts what was undone, not what can be put back; drive buttons from `canRedo`. |

#### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `push(TomActionTransaction tx)` | `void` | Pushes a committed transaction and clears the redo stack. Throws `StateError` on an uncommitted one; ignores an empty one. |
| `undo()` | `void` | Runs `undoAll()` **then** moves the transaction to the redo stack, so a refusal leaves both stacks untouched. |
| `redo()` | `void` | Runs `redoAll()` then moves the transaction back. Does nothing when `canRedo` is false. |
| `clear()` | `void` | Empties both stacks and fires `onChanged`. |

### TomUndoAction

Coordinator action that drives `TomUndoHistory.undo`, so undo is itself a
first-class, authorizable action rather than a special case.

**Kind:** `class`
**Extends:** `TomSimpleAction<TomUndoRedoContext>`

#### Constructors

```dart
TomUndoAction({
  required TomActionController controller,
  required TomUndoHistory history,
})
```

Takes `actionId` `'undo'`.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `history` | `TomUndoHistory` | The history this action drives. |

#### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `canExecute(TomUndoRedoContext context)` | `bool` | `history.canUndo`. |
| `executeSimple(TomUndoRedoContext context, TomActionTransaction tx)` | `void` | Calls `history.undo()`. |

### TomRedoAction

Coordinator action that drives `TomUndoHistory.redo`.

**Kind:** `class`
**Extends:** `TomSimpleAction<TomUndoRedoContext>`

#### Constructors

```dart
TomRedoAction({
  required TomActionController controller,
  required TomUndoHistory history,
})
```

Takes `actionId` `'redo'`.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `history` | `TomUndoHistory` | The history this action drives. |

#### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `canExecute(TomUndoRedoContext context)` | `bool` | `history.canRedo` — which accounts for whether the next transaction's actions implement `redo`, so a button bound here is disabled when redo would do nothing. |
| `executeSimple(TomUndoRedoContext context, TomActionTransaction tx)` | `void` | Calls `history.redo()`. |

### TomUndoRedoContext

The context the two coordinator actions take: a scope and nothing else, because
undoing needs no domain input.

**Kind:** `class`
**Extends:** `TomActionContext`

#### Constructors

```dart
const TomUndoRedoContext()
```

### TomCompositeAction

Runs a list of steps in order as one action, folding them into a single
transaction. Each step carries its own action, its own context builder and an
optional guard, so the steps' context types need not agree — which is what makes
one composite class enough for every multi-step shape.

**Kind:** `class`
**Extends:** `TomAction<TomActionContext, TomActionUndo>`

#### Constructors

```dart
TomCompositeAction({
  required String actionId,
  required TomActionController controller,
  required List<TomCompositeStep> steps,
  bool stopOnBlockedStep = true,
  TomScope? scope,
  TomAuthorizationGroup? tomGroup,
})
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `steps` | `List<TomCompositeStep>` | The steps, in execution order. |
| `stopOnBlockedStep` | `bool` | What a blocked step does to the rest of the run: abandon the remainder (the default) or skip only that step. Governs all three blocking conditions alike. |

A step is **blocked** when its `guard` returns false, when its action is
unauthorized, or when that action's `canExecute` returns false.

#### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `canExecute(TomActionContext context)` | `bool` | Whether `execute` would run at least one step. Mirrors `execute` exactly, including reachability under `stopOnBlockedStep`, so gating a button on it cannot produce an enabled control that does nothing. The `context` argument is ignored — each step supplies its own. |
| `execute(TomActionContext context, TomActionTransaction tx)` | `TomActionUndo?` | Runs each unblocked step into `tx`. |

Both `canExecute` and `execute` call each step's `contextBuilder`, so
dispatching through a `TomActionTrigger` — which checks before it runs — calls it
twice. Build a context there; do not mutate anything.

### TomCompositeStep\<TContext\>

One step of a composite: an action, the context to run it with, and an optional
guard.

**Kind:** `class`
**Type Parameters:** `<TContext extends TomActionContext>`

#### Constructors

```dart
TomCompositeStep({
  required TomAction<TContext, TomActionUndo> action,
  required TContext Function() contextBuilder,
  bool Function()? guard,
})
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `action` | `TomAction<TContext, TomActionUndo>` | The action this step runs. |
| `contextBuilder` | `TContext Function()` | Builds the step's context. Called on both the check and the run. |
| `guard` | `bool Function()?` | Cheap predicate consulted before `contextBuilder`, on both the check and the run. |

## Global Functions and Constants

None — this module exports types only.
