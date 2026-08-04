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
| `static TomScope defaultScope` | The root scope used when none is installed |
| `static TomScope get current` | The scope installed on the current zone, or `defaultScope` |
| `static T withScope(String, T Function())` | Runs a body in a new child scope named for the string |
| `static String buildScopePath(TomScope)` | Dot-joins a scope's chain, skipping `default` |
| `String getScopePath()` | This scope's full path as a dot-separated string |
| `T runInScope(T Function())` | Runs a body with this scope installed on the zone |

`runInScope` is a no-op wrapper when `this` is already the current scope
(identity check), which prevents redundant zone nesting.

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
**skipping the `default` root**, then joins the segments with `.` in
root-to-leaf order:

```dart
// default ← "app" ← "checkout" ← "orderForm"
//   produces "app.checkout.orderForm"
```

An empty path (only the default scope) yields `''`, which lets consumers treat
"no scope" as an empty prefix.

## Crossing Zone Boundaries

Because the active scope lives on the zone, it is lost whenever execution hops to
a callback the framework runs later. The two tools for keeping the scope intact
are:

- `withScope` / `runInScope` — install a scope for the duration of a synchronous
  body.
- `InScopeBuilder` — capture the scope now and restore it inside a deferred
  callback.

## Best Practices

1. **Construct scopes, don't mutate them.** Use the `TomScopeBase` constructor;
   treat the identity as immutable after creation.
2. **Wrap framework callbacks.** Any builder that the UI framework calls back
   into should be wrapped with `InScopeBuilder` so resource/authorization
   lookups resolve against the right path.
3. **Keep ids path-safe.** Scope ids become dot-separated path segments — avoid
   embedding `.` in an id.

## Dependencies

This module depends on:

- **Little Things Module**: `getFromCurrentZone` for reading the active scope
  off the current zone.
