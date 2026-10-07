# Scope IDs Module

The Scope IDs module provides a hierarchical, zone-propagated identifier system
used to namespace resource and authorization lookups (for example
`app.checkout.orderForm`). A scope travels on the current Dart `Zone`, so any
code running inside a scope can discover its position in the hierarchy without
threading an identifier through every call.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
  - [TomScope](#tomscope)
  - [TomScopeBase and TomScopeMixin](#tomscopebase-and-tomscopemixin)
    - [The window before initScope](#the-window-before-initscope)
  - [ScopeCapture](#scopecapture)
- [Scope Paths](#scope-paths)
  - [Ids may not contain the separator](#ids-may-not-contain-the-separator)
  - [The chain must be acyclic](#the-chain-must-be-acyclic)
- [Crossing Zone Boundaries](#crossing-zone-boundaries)
  - [Fire-and-forget work started inside a scope](#fire-and-forget-work-started-inside-a-scope)
  - [Deferred callbacks the framework invokes](#deferred-callbacks-the-framework-invokes)
- [Best Practices](#best-practices)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomScope` | abstract class | Scope identity contract with zone-current access and path building. |
| `TomScopeBase` | class | Concrete `TomScope` using `TomScopeMixin`. |
| `TomScopeMixin` | mixin | Adds scope identity/parenting to any `Object`. |
| `ScopeCapture` | class | Captures a scope and wraps callbacks so they run in it when invoked later. |
| `TomScopeException` | class | Raised when a scope cannot be built or used as one. |

A `TomScope` is a node in a parent chain rooted at `TomScope.defaultScope`. Each
scope carries a local `id` and a reference to its `parent`. The **active**
scope is the one installed on the current zone; `TomScope.current` resolves to
the nearest enclosing scope, falling back to `defaultScope` when none is
installed.

The primary purpose is to build a dot-separated **scope path**
(`app.checkout.orderForm`) that downstream systems — resource resolution and
authorization — use as a lookup prefix.

## Quick Start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

// Run code inside a named child scope (parented to the current scope).
TomScope.withScope('checkout', () {
  TomScope.withScope('orderForm', () {
    // The active scope path here is "checkout.orderForm".
    print(TomScope.current.getScopePath()); // checkout.orderForm
  });
});
```

## Core Components

### TomScope

The abstract contract for a scope.

| Member | Description |
| ------ | ----------- |
| `String get id` | This scope's local identifier (the last path segment) |
| `TomScope? get parent` | The enclosing scope, or `null` for the root |
| `static final TomScope defaultScope` | The root scope used when none is installed. `final`, so it cannot be swapped out at runtime — see below |
| `static TomScope get current` | The scope installed on the current zone, or `defaultScope` |
| `static T withScope(String, T Function())` | Runs a body in a new child scope named for the string |
| `static String buildScopePath(TomScope)` | Dot-joins a scope's chain, eliding the root sentinel — by identity, not by id |
| `String getScopePath()` | This scope's full path as a dot-separated string |
| `T runInScope(T Function())` | Runs a body with this scope installed on the zone |

When `this` is already the current scope (identity check), `runInScope` runs
the body directly rather than wrapping it in a child zone. The body runs and
its result is returned either way — it is the zone that is elided, which is
what prevents redundant scope nesting.

**`withScope` does not share that short-circuit.** It is given an id, not a
scope, so it has no instance to recognise: it always constructs a fresh child
of `current`. Re-entering the same id therefore nests, and the path repeats the
segment — `withScope('app', () => withScope('app', ...))` resolves to
`app.app`, where `app.runInScope(() => app.runInScope(...))` on one instance
resolves to `app`. The repeated segment is the intended path, not a missing
check: two nested bodies that each asked for `app` are two namespaces, and
merging them by name would hand the inner one the outer one's resource keys — a
tree node whose key equals its parent's would share its parent's resources.
Code that can be nested inside itself (a widget subtree that installs its own
scope, say) should hold the scope and use `runInScope`.

**The root scope cannot be swapped out.** `defaultScope` is `static final`, so
there is no supported way — and no compiling way — to point the process at a
different root. That is deliberate rather than incidental: it is the root of
every scope path, so a reassignment would silently change resource resolution
for everything already running, including code holding a scope captured before
the swap. Changing the active scope is what `withScope` and `runInScope` are
for; both are zone-carried, so the caller's own continuation is unaffected and
the previous scope is restored on exit. That bounds what the *caller* sees, not
how long the scope lives — see [Crossing Zone Boundaries](#crossing-zone-boundaries).

### TomScopeBase and TomScopeMixin

`TomScopeBase` is the concrete scope you normally construct. It delegates to
`TomScopeMixin`, which stores the identity in write-once (`late final`) fields
set by `initScope`:

```dart
final root = TomScopeBase(scopeId: 'app', parentScope: null);
final child = TomScopeBase(scopeId: 'checkout', parentScope: root);

print(child.getScopePath()); // app.checkout
```

> **Note:** a scope's identity is write-once. `initScope` is the only way to set
> `id` and `parent`, and there is no way to change them afterwards — use the
> constructor (`TomScopeBase(scopeId:, parentScope:)`), or call `initScope`
> exactly once when mixing `TomScopeMixin` into your own type.

A second `initScope` is refused with
`TomScopeException(scope_ids.init_scope.already_initialised)`, whose message
names the class, the id the scope already has and the one the call tried to
give it:

```dart
final scope = TomScopeBase(scopeId: 'orders');
scope.initScope(scopeId: 'invoices');
// TomScopeException(scope_ids.init_scope.already_initialised): Cannot
// initialise TomScopeBase as "invoices": initScope() has already given it the
// id "orders", and a scope's identity is written once. ...
```

It is refused even when both calls pass the same values: a scope whose identity
two places write has two owners, and the second one is the bug. When a call is
wrong twice over — a second call *and* an unusable id — the id is reported,
because that is the mistake still there after the extra call is removed.

#### The window before initScope

Because `initScope` may run after construction, there is a window in which an
instance exists and is not yet a scope. Using it as one inside that window is
refused immediately, with a `TomScopeException` naming the class and the call
that was skipped:

```dart
class LazyScope with TomScopeMixin {}

LazyScope().runInScope(() { /* never runs */ });
// TomScopeException(scope_ids.use_scope.no_identity): Cannot install a scope on
// the zone: LazyScope has no scope identity because initScope() was never
// called on it. …
```

Two entry points enforce it, and between them they close the window:

| Entry point | Refuses |
| ----------- | ------- |
| `runInScope` — and everything built on it, including `ScopeCapture` | installing a scope that has no identity |
| `initScope` | a `parentScope` that has no identity, and an unusable `scopeId` |

Checking the parent at `initScope`, rather than when the path is built, is what
keeps both checks O(1): an initialised scope then has a fully initialised
*chain*, by induction — the identity is write-once, so a parent cannot lose one
later. The result is a single invariant worth relying on: **whatever
`TomScope.current` returns is usable.**

The alternative is worse than it looks. A half-built instance installs onto the
zone perfectly well, so the failure surfaces at whichever later call first asks
for a path — a resource lookup, an authorization check — on a stack that
mentions neither scopes nor the constructor that skipped `initScope`.

`ScopeCapture` still *captures* an uninitialised scope without complaint; it
is the invocation that is refused. Capture is not use, and a widget may legally
be constructed with a scope that gets its identity before the first build.

### ScopeCapture

Flutter invokes builder callbacks (`itemBuilder`, `builder`, …) **outside** the
zone in which the widget was constructed. `ScopeCapture` captures the scope at
construction time and wraps a callback so it re-installs that scope when called:

```dart
class TomFoo extends TomNodeBase {
  final WidgetBuilder _builder;
  TomFoo({required WidgetBuilder builder, super.scope})
      : _builder = ScopeCapture(scope: scope).wrap1(builder);
}
```

`ScopeCapture` provides `wrap0`…`wrap5` for fixed-arity callbacks and the
`wrap0n`…`wrap5n` nullable variants (return `null` when the callback is `null`).
Both are sugar for `run`, which runs any body in the captured scope and returns
its result.

The family is written out per arity because Dart has no variadic generics: no
single method can take "a function of any signature" and return one of the
*same* signature with its static types intact. `Function.apply` would take the
function but return it untyped, and every call site would lose the compiler's
check of the callback it passed. So a shape outside the family — a sixth
argument, or named parameters such as Flutter's `InputCounterWidgetBuilder` —
is a closure of the target type around `run`:

```dart
final capture = ScopeCapture(scope: scope);
final InputCounterWidgetBuilder counter =
    (context, {required currentLength, required maxLength, required isFocused}) =>
        capture.run(() => build(context,
            currentLength: currentLength,
            maxLength: maxLength,
            isFocused: isFocused));
```

## Scope Paths

`buildScopePath` walks from a scope up to the root, collecting each `id` and
**eliding the root sentinel**, then joins the segments with `.` in root-to-leaf
order:

```dart
// defaultScope ← "app" ← "checkout" ← "orderForm"
//   produces "app.checkout.orderForm"
```

An empty path (only the root sentinel) yields `''`, which lets consumers treat
"no scope" as an empty prefix.

The path is rebuilt on every call and not cached. The walk is linear in the
depth and costs a fraction of a microsecond at the depths scopes reach in
practice — more than the map lookup a caller does with the result, but small
beside the work a lookup serves. It also keeps the answer right for any
`TomScope`: `buildScopePath` accepts a hand-rolled implementation whose `id` or
`parent` is computed, and a cached path would outlive a change to either.

**The elision is by identity, not by name.** Only `TomScope.defaultScope`
itself — compared with `identical` — is dropped from the walk. A domain scope
whose local id happens to be `default` is an ordinary scope and keeps its
segment:

```dart
final root = TomScopeBase(scopeId: 'app', parentScope: null);
final named = TomScopeBase(scopeId: 'default', parentScope: root);

print(named.getScopePath()); // app.default — not "app"
```

Matching on the id string instead would delete that segment silently, and
collapse two genuinely distinct scopes onto one path. That is why the rule is
written as an identity check rather than a name comparison.

### Ids may not contain the separator

Because the segments are joined with `.`, an id that *contains* a `.` forges a
segment boundary — it renders as a path belonging to a different, deeper chain:

```dart
TomScopeBase(scopeId: 'a.b');                          // would render "a.b"
TomScopeBase(scopeId: 'b', parentScope: TomScopeBase(scopeId: 'a'));  // also "a.b"
```

The path is what resource and authorization lookups are keyed on, so those two
being indistinguishable means a scope can name another scope's resources. An
empty id is the same defect from the other end: at the root it renders as `''`,
the string consumers are told to read as *no scope at all*.

Both are therefore **refused**, with a `TomScopeException`:

```dart
TomScopeBase(scopeId: 'a.b');
// TomScopeException(scope_ids.init_scope.separator_in_id): A scope id must not
// contain "." … "a.b" would be indistinguishable from a deeper chain of
// separate scopes.

TomScope.withScope('', () {});
// TomScopeException(scope_ids.init_scope.empty_id): A scope id must not be
// empty …
```

The check lives in `initScope`, which `withScope` and the `TomScopeBase`
constructor both route through, so all three entry points are covered by one
check that runs once per scope rather than on every path build. Nothing else
about the id is policed — spaces, slashes, hyphens and non-ASCII are all
unambiguous and stay legal.

Ids written as literals in source can never trip this. The exposure it closes is
the case the module exists for: **one scope per detail row, named from the
row** — a tenant, a key, a user-supplied label.

### The chain must be acyclic

The walk is iterative and has **no cycle guard**. A loop therefore does not
raise `StackOverflowError` — the walk spins silently, appending segments, until
the heap is exhausted and the isolate dies. In a server that is the whole
process, and the stack trace names neither scopes nor whoever built the loop.

Nothing is guarded because nothing needs to be: **a scope built through this
module cannot form a loop.** Both ways of building one hand it a parent that
already exists —

| How the scope is built | Why the parent is already there |
| ---------------------- | ------------------------------- |
| `withScope` | parents the new scope to `TomScope.current` |
| `TomScopeBase(scopeId:, parentScope:)` | `initScope` runs in the constructor |
| `initScope` on a constructed instance | refuses a `parentScope` that has no identity yet |

— so every parent is strictly *older* than its child, and `initScope` writes the
link once, so it stays that way. Following parents only ever moves backwards in
time, and a chain that only moves backwards cannot arrive back where it started.

Bending a link back would take one of two things, and both are refused:

```dart
final a = LazyScope();
final b = LazyScope();
a.initScope(scopeId: 'a', parentScope: b);  // TomScopeException — b has no identity
b.initScope(scopeId: 'b', parentScope: a);

final child = TomScopeBase(scopeId: 'child', parentScope: root);
child.initScope(scopeId: 'child', parentScope: other);  // TomScopeException — written once
```

**The requirement does bind a hand-rolled `implements TomScope`.** Such a type
supplies its own `parent`, so it sits outside the argument above and outside any
check the module can make; `buildScopePath` accepts it and will walk whatever it
is given. If you implement the interface directly, keeping the chain acyclic is
yours to guarantee.

## Crossing Zone Boundaries

A zone bounds **reachability, not lifetime**. This is the single most
misread property of the module, so it is worth stating both halves precisely.

**What is guaranteed:** the caller's own continuation never sees the installed
scope. Once `withScope` returns, the next line runs in whatever scope the caller
was already in. Nothing a body does can change that.

**What is *not* guaranteed is that the scope stops existing.** A zone is not a
dynamic extent. Anything the body *schedules* inherits the zone and observes the
scope whenever it eventually runs, arbitrarily long after the body returned:

```dart
TomScope.withScope('report', () {
  Timer(const Duration(minutes: 5), () {
    // Still "report", five minutes after withScope returned.
    print(TomScope.current.getScopePath());
  });
});

print(TomScope.current.getScopePath()); // "" — the caller is unaffected
```

The same holds for a `Future`, a microtask, and a stream subscription opened
inside the body. An `await` inside an async body also keeps the scope across the
suspension, which is what makes the module usable from async code at all.

### Fire-and-forget work started inside a scope

The practical consequence: **a `Future` started inside a scope and never awaited
keeps that scope for its entire life.** Usually that is exactly right — the work
belongs to the request or the widget that started it, and its resource and
authorization lookups should resolve against that path.

It matters when the work is expected to outlive its origin. A background task
spawned inside `app.checkout.orderForm` still resolves resources under
`app.checkout.orderForm` long after that form is gone. If the work is genuinely
independent, start it outside the scope, or install the scope it should actually
run under:

```dart
// Belongs to the form — inherits app.checkout.orderForm.
TomScope.withScope('orderForm', () {
  unawaited(_sendAnalytics());
});

// Independent of the form — give it its own scope.
TomScope.withScope('orderForm', () { /* ... */ });
unawaited(TomScope.defaultScope.runInScope(_flushOutbox));
```

Nothing needs tearing down: the scope is an identifier, not a resource, and it
becomes unreachable when the last callback holding its zone is collected.

### Deferred callbacks the framework invokes

Zone inheritance covers callbacks the **async machinery** schedules. It does not
cover a closure that is merely *stored* inside the body and invoked directly by
someone else later — that runs in **the invoker's** scope, not the one in force
when it was created:

```dart
late String Function() stored;
TomScope.withScope('origin', () {
  stored = () => TomScope.current.getScopePath();
});

stored(); // "" — not "origin"
```

This is precisely the gap `ScopeCapture` closes, and the reason it exists:
Flutter stores builder callbacks and calls them from its own build pipeline, so
they arrive outside the zone that constructed the widget.

So the two tools are:

- `withScope` / `runInScope` — install a scope for a body **and everything that
  body schedules**.
- `ScopeCapture` — capture the scope now and re-install it inside a callback
  that will be invoked directly, from outside the zone.

## Best Practices

1. **Construct scopes, don't mutate them.** Use the `TomScopeBase` constructor;
   treat the identity as immutable after creation. If you mix `TomScopeMixin`
   into your own type, prefer calling `initScope` from the constructor — that
   leaves no window in which the instance is not yet a scope.
2. **Wrap framework callbacks.** Any builder that the UI framework calls back
   into should be wrapped with `ScopeCapture` so resource/authorization
   lookups resolve against the right path.
3. **Expect an id derived from data to be checked.** Scope ids become
   dot-separated path segments, so an empty id or one containing `.` is refused
   with a `TomScopeException` rather than silently producing another scope's
   path. Literal ids never trip it; if you build an id from a tenant name, a row
   key or a user-supplied label, either keep it separator-free or handle the
   rejection.
4. **Decide which scope background work belongs to.** A `Future` started inside
   a scope keeps it for its whole life, so a fire-and-forget task inherits the
   scope of whatever happened to start it. Start genuinely independent work
   outside the scope, or install the one it should run under.
5. **Prefer `TomScopeMixin` to implementing `TomScope` by hand.** The mixin is
   what makes the chain acyclic, and `buildScopePath` walks the chain without
   checking. A hand-rolled implementation supplies its own `parent` and inherits
   that obligation.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | every file | `Zone` and `runZoned` — the scope is a zone value, which is what makes it ambient |
| [little_things](../little_things/little_things.md) | module | every file | `getFromCurrentZone`, for reading the active scope off the current zone |

`scope_ids.dart` is the module's only source file, and the two rows above are
the whole of what it reaches: one SDK library and one kernel module, through
`exception_base.dart` for `TomException`, the base of `TomScopeException`.

There is no package dependency at all. That is what lets the module sit as far
down the graph as it does — the two kernel modules that use `TomScope` for key
resolution, [security](../security/security.md) (`tom_authorization.dart`) and
[observable](../observable/observable.md) (`tom_observable_enum.dart`), reach it
without dragging anything along.
