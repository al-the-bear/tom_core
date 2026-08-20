# Scope IDs Module

The Scope IDs module provides a hierarchical, zone-propagated identifier system
used to namespace resource and authorization lookups (for example
`app.checkout.orderForm`). A scope travels on the current Dart [`Zone`], so any
code running inside a scope can discover its position in the hierarchy without
threading an identifier through every call.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
  - [TomScope](#tomscope)
  - [TomScopeBase and TomScopeMixin](#tomscopebase-and-tomscopemixin)
  - [InScopeBuilder](#inscopebuilder)
- [Scope Paths](#scope-paths)
- [Crossing Zone Boundaries](#crossing-zone-boundaries)
  - [Fire-and-forget work started inside a scope](#fire-and-forget-work-started-inside-a-scope)
  - [Deferred callbacks the framework invokes](#deferred-callbacks-the-framework-invokes)
- [Best Practices](#best-practices)
- [Dependencies](#dependencies)

---

## Overview

A `TomScope` is a node in a parent chain rooted at `TomScope.defaultScope`. Each
scope carries a local [`id`] and a reference to its [`parent`]. The **active**
scope is the one installed on the current zone; `TomScope.current` resolves to
the nearest enclosing scope, falling back to `defaultScope` when none is
installed.

The primary purpose is to build a dot-separated **scope path**
(`app.checkout.orderForm`) that downstream systems — resource resolution and
authorization — use as a lookup prefix.

| Type | Role |
| ---- | ---- |
| `TomScope` | Abstract contract: `id`, `parent`, path building, zone install |
| `TomScopeBase` | Concrete scope built from a scope id and optional parent |
| `TomScopeMixin` | Reusable implementation backing `TomScopeBase` |
| `InScopeBuilder` | Wraps callbacks so they run in a captured scope when invoked later |

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

`runInScope` is a no-op wrapper when `this` is already the current scope
(identity check), which prevents redundant zone nesting.

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

### InScopeBuilder

Flutter invokes builder callbacks (`itemBuilder`, `builder`, …) **outside** the
zone in which the widget was constructed. `InScopeBuilder` captures the scope at
construction time and wraps a callback so it re-installs that scope when called:

```dart
class TomFoo extends TomNodeBase {
  final WidgetBuilder _builder;
  TomFoo({required WidgetBuilder builder, super.scope})
      : _builder = InScopeBuilder(scope: scope).wrap1(builder);
}
```

`InScopeBuilder` provides `wrap0`…`wrap5` for fixed-arity callbacks, the
`wrap0n`…`wrap5n` nullable variants (return `null` when the callback is `null`),
and `wrapCounter` for Flutter's named-parameter `InputCounterWidgetBuilder`
signature.

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

This is precisely the gap `InScopeBuilder` closes, and the reason it exists:
Flutter stores builder callbacks and calls them from its own build pipeline, so
they arrive outside the zone that constructed the widget.

So the two tools are:

- `withScope` / `runInScope` — install a scope for a body **and everything that
  body schedules**.
- `InScopeBuilder` — capture the scope now and re-install it inside a callback
  that will be invoked directly, from outside the zone.

## Best Practices

1. **Construct scopes, don't mutate them.** Use the `TomScopeBase` constructor;
   treat the identity as immutable after creation.
2. **Wrap framework callbacks.** Any builder that the UI framework calls back
   into should be wrapped with `InScopeBuilder` so resource/authorization
   lookups resolve against the right path.
3. **Keep ids path-safe.** Scope ids become dot-separated path segments — avoid
   embedding `.` in an id.
4. **Decide which scope background work belongs to.** A `Future` started inside
   a scope keeps it for its whole life, so a fire-and-forget task inherits the
   scope of whatever happened to start it. Start genuinely independent work
   outside the scope, or install the one it should run under.

## Dependencies

This module depends on:

- **Little Things Module**: `getFromCurrentZone` for reading the active scope
  off the current zone.
