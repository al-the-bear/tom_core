# Tom Core Kernel API Reference: Scope Ids Module

Hierarchical, zone-propagated identifiers that namespace resource lookups, plus
a builder that captures the active scope so callbacks invoked outside the
original zone still resolve resources correctly.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomScope](#tomscope)
  - [TomScopeBase](#tomscopebase)
  - [TomScopeMixin](#tomscopemixin)
  - [InScopeBuilder](#inscopebuilder)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tombase/scope_ids/scope_ids.dart`.

A `TomScope` is a hierarchical identifier (e.g. `app.checkout.orderForm`) used to
namespace resource lookups. Scopes form a parent chain rooted at `defaultScope`,
and the active scope is carried on the current `Zone`, so `TomScope.current`
resolves to whichever scope the nearest enclosing `withScope` / `runInScope`
call installed. `TomScopeBase` is the concrete implementation, built from
`TomScopeMixin`, whose write-once identity is set via `initScope`. `InScopeBuilder`
captures a scope at construction time and wraps callback functions (0–5
arguments, nullable variants, and a Flutter counter-builder shape) so they
execute within that scope when Flutter later calls them outside the original
zone.

## Class Hierarchy

```
TomScope  (abstract — nothing extends it)

TomScopeMixin  (mixin on Object, implements TomScope)
    └── TomScopeBase  (with TomScopeMixin; extends Object)

InScopeBuilder
```

`TomScopeBase` is a `TomScope` by *interface*, not by inheritance: it extends
`Object`, applies `TomScopeMixin`, and the mixin's `implements TomScope` is what
makes the subtype hold. Nothing in the package extends `TomScope`, and the mixin
is the only declared implementation of it.

The distinction is load-bearing rather than notational. Adding a concrete member
to `TomScope` does not quietly propagate into `TomScopeBase` the way an inherited
member would — it fails the build at `TomScopeBase`, which now has an unsatisfied
interface (`non_abstract_class_inherits_abstract_member`). Note where the error
lands: a mixin that declares `implements` is not itself obliged to supply the
member, so the diagnostic surfaces on every class applying the mixin, not on
`TomScopeMixin`.

## Classes

### TomScope

A hierarchical, zone-propagated identifier used to namespace resource lookups.
Scopes form a parent chain rooted at `defaultScope`; the active scope is carried
on the current `Zone`.

- **Extends:** none (abstract class, extends `Object`)
- **Implemented by:** `TomScopeMixin` — and so by `TomScopeBase`

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `defaultScope` | `TomScope` | The root scope used when no scope is installed on the current zone. `static final` — immutable by design, because it is the root of every scope path and reassigning it would change resource resolution for the whole process. Use `withScope` / `runInScope` to install a different scope; both install it on a child zone, so the change reaches that body and the callbacks it schedules, never the caller. |
| `current` | `TomScope` | The scope installed on the current `Zone`, or `defaultScope` if none (static getter). |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `withScope` | `static T withScope<T>(String scope, T Function() body)` | Runs `body` in a new child scope named `scope`, parented to `current`. The zone bounds reachability, not lifetime: the caller's continuation never sees the scope, but anything `body` schedules inherits it and observes it whenever it later runs. |
| `buildScopePath` | `static String buildScopePath(TomScope scope)` | Builds the dot-separated scope path for any `TomScope` (e.g. `app.checkout.orderForm`), eliding only the root sentinel. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | This scope's local identifier (the last path segment). |
| `parent` | `TomScope?` | The enclosing scope, or `null` for the root `defaultScope`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `runInScope` | `T runInScope<T>(T Function() body)` | Runs `body` inside this scope's zone; executes directly (no new zone) if this scope is already current. |
| `getScopePath` | `String getScopePath()` | Returns the full scope path as a dot-separated string, used as a resource-lookup prefix. |

### TomScopeBase

Concrete `TomScope` built from a scope id and an optional parent. Its
constructor calls `initScope` to set the write-once identity.

- **Extends:** none (extends `Object`)
- **Mixes in:** `TomScopeMixin`
- **Implements:** `TomScope` (via `TomScopeMixin`)

#### Constructors

```dart
TomScopeBase({required String scopeId, TomScope? parentScope})
```

### TomScopeMixin

Reusable `TomScope` implementation backing `TomScopeBase`. Mix into a class and
call `initScope` exactly once to set the scope's write-once identity — usually
from the constructor, or on the constructed instance when the parent is only
known later.

- **Implements:** `TomScope`
- **Mixin on:** `Object`
- **Applied by:** `TomScopeBase` (the only class in the package that applies it)

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | The scope's local id. Read-only; written once by `initScope`. Throws `StateError` before `initScope` has run. |
| `parent` | `TomScope?` | The parent scope. Read-only; written once by `initScope`. Throws `StateError` before `initScope` has run. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `initScope` | `void initScope({required String scopeId, TomScope? parentScope})` | Initialises this scope's identity. The single write-once entry point: call it exactly once, from the constructor or — for a scope whose parent is only known later — on the constructed instance. Throws `StateError` if `parentScope` has no identity of its own. |
| `getScopePath` | `String getScopePath()` | *(override)* Returns the full dot-separated scope path. |
| `runInScope` | `T runInScope<T>(T Function() body)` | *(override)* Runs `body` inside this scope's zone, reusing the current zone when already active. Throws `StateError` before `initScope` has run, without running `body`. |

Until `initScope` runs, the instance is not yet a scope: it can neither be
installed nor be another scope's parent, and each refusal names the class and
the missing call. Checking the parent at `initScope` rather than during the path
walk keeps both checks O(1) — an initialised scope has a fully initialised chain
by induction — and buys the invariant that whatever `TomScope.current` returns is
usable. See `doc/scope_ids/scope_ids.md`.

### InScopeBuilder

Captures a `TomScope` at construction time and wraps callback functions so they
execute within that scope when called later. Used so Tom widgets created inside
Flutter builder callbacks (invoked outside the original zone) still resolve
resources against the correct scope.

#### Constructors

```dart
InScopeBuilder({TomScope? scope})
```

Omitting `scope` captures `TomScope.current` **at construction time**, which is
the point of the class: construct it where the correct scope is installed, and
the wrapped callbacks carry that scope wherever they are later invoked.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `wrap0` | `R Function() wrap0<R>(R Function() fn)` | Wraps a 0-argument callback to run within the captured scope. |
| `wrap1` | `R Function(A) wrap1<R, A>(R Function(A) fn)` | Wraps a 1-argument callback to run within the captured scope. |
| `wrap2` | `R Function(A, B) wrap2<R, A, B>(R Function(A, B) fn)` | Wraps a 2-argument callback to run within the captured scope. |
| `wrap3` | `R Function(A, B, C) wrap3<R, A, B, C>(R Function(A, B, C) fn)` | Wraps a 3-argument callback to run within the captured scope. |
| `wrap4` | `R Function(A, B, C, D) wrap4<R, A, B, C, D>(R Function(A, B, C, D) fn)` | Wraps a 4-argument callback to run within the captured scope. |
| `wrap5` | `R Function(A, B, C, D, E) wrap5<R, A, B, C, D, E>(R Function(A, B, C, D, E) fn)` | Wraps a 5-argument callback to run within the captured scope. |
| `wrap0n` | `R Function()? wrap0n<R>(R Function()? fn)` | Wraps a nullable 0-argument callback; returns null if `fn` is null. |
| `wrap1n` | `R Function(A)? wrap1n<R, A>(R Function(A)? fn)` | Wraps a nullable 1-argument callback; returns null if `fn` is null. |
| `wrap2n` | `R Function(A, B)? wrap2n<R, A, B>(R Function(A, B)? fn)` | Wraps a nullable 2-argument callback; returns null if `fn` is null. |
| `wrap3n` | `R Function(A, B, C)? wrap3n<R, A, B, C>(R Function(A, B, C)? fn)` | Wraps a nullable 3-argument callback; returns null if `fn` is null. |
| `wrap4n` | `R Function(A, B, C, D)? wrap4n<R, A, B, C, D>(R Function(A, B, C, D)? fn)` | Wraps a nullable 4-argument callback; returns null if `fn` is null. |
| `wrap5n` | `R Function(A, B, C, D, E)? wrap5n<R, A, B, C, D, E>(R Function(A, B, C, D, E)? fn)` | Wraps a nullable 5-argument callback; returns null if `fn` is null. |
| `wrapCounter` | `R Function(A, {required B currentLength, required C maxLength, required D isFocused}) wrapCounter<R, A, B, C, D>(...)` | Wraps a callback with one positional and named parameters (for Flutter's `InputCounterWidgetBuilder`-style typedefs). |

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
