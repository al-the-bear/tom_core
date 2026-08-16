# Tom Core Kernel API Reference: Context Module

A zone-based execution-context system that propagates request-scoped values
(user principal data, tenant information, locale) through synchronous and
asynchronous call chains without explicit parameter passing.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomExecutionContext](#tomexecutioncontext)
  - [TomZoneValues](#tomzonevalues)
  - [TomContextEntry\<T\>](#tomcontextentryt)
  - [TomContextProviders](#tomcontextproviders)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tombase/context/execution_context.dart`.

The Context module uses Dart's Zone system to propagate contextual information
across async boundaries. `TomExecutionContext` holds a map of named
`TomContextEntry` providers and runs a body inside a zone (via `runInContext` /
`runInContextAsync`) where those entries — merged with any context already
installed in the current zone, the inner context winning on collisions — are
available. Each `TomContextEntry<T>` is a typed, lazily evaluated value provider.
Alongside the typed entries, arbitrary untyped `zoneValues` can be threaded
through a `TomZoneValues` container. `TomContextProviders` supplies static
providers that read common values (organization, application, process, locale)
from the current zone's `TomPrincipal` with sensible defaults, and the global
`tomExecutionContext` pre-wires them.

## Class Hierarchy

```
TomExecutionContext

TomZoneValues

TomContextEntry<T>

TomContextProviders
```

## Classes

### TomExecutionContext

A zone-based execution context for propagating request-scoped values through
synchronous and asynchronous call chains.

#### Constructors

```dart
TomExecutionContext(
  Map<String, TomContextEntry> contextMap, {
  TomExecutionContext? parentContext,
})
```

Merges `parentContext`'s entries (if any) as the base and overwrites them with
`contextMap` on collision, into a fresh map; the passed-in maps are not mutated.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getValueFromCurrentZone` | `static T? getValueFromCurrentZone<T>(String name)` | Reads the value of the entry named `name` and typed `T` from the `TomExecutionContext` in the current zone, or `null` if none. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `contextMap` | `Map<String, TomContextEntry>` | Map of context entry names to their entries (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getEntry` | `TomContextEntry<T>? getEntry<T>(String name)` | Returns the entry registered under `name` when its type matches `T`, otherwise `null`. |
| `add` | `void add(String name, TomContextEntry entry)` | Adds or replaces the entry under `name`. |
| `clear` | `void clear()` | Removes all entries from this context. |
| `combineWith` | `void combineWith(TomExecutionContext other)` | Merges `other`'s entries into this context; colliding names are overwritten by `other`. |
| `runInContext` | `T runInContext<T>(T Function() body, {Map<Object?, Object?> zoneValues = const {}})` | Runs `body` synchronously in a new zone whose typed entries are this context merged over any inherited context (this context wins), threading `zoneValues` through a merged `TomZoneValues`. |
| `runInContextAsync` | `Future<T> runInContextAsync<T>(Future<T> Function() body, {Map<Object?, Object?> zoneValues = const {}})` | Installs the same zone as `runInContext` and differs only in signature: `body` must return a `Future<T>`, which is handed back, so `T` names the awaited value. |

Both run methods install the same zone, so the context and zone values survive
`await` boundaries under either, and reach callbacks scheduled from the body
that fire after the call has returned. `runInContextAsync` is the right choice
when the body is asynchronous not because of propagation but because its
signature makes a dropped future a compile error.

### TomZoneValues

A mutable container for arbitrary untyped zone values, offering indexed access.

`runInContext` / `runInContextAsync` install this container in the zone under
the `TomZoneValues` type key, so a value threaded through `zoneValues:` is read
back through the container — `getFromCurrentZone<TomZoneValues>()?[key]` — and
not with `getValueFromCurrentZone`, which resolves named entries of the context
map. The keys are not installed in the zone under themselves, so
`Zone.current[key]` stays `null` — including for a `Type` key, which means
`zoneValues: {TomPrincipal: p}` does not make `getFromCurrentZone<TomPrincipal>()`
resolve even though that is the correct idiom for `runZoned`.

The container exists because it makes the values mutable from inside the zone
and mergeable across nested runs; raw zone values are fixed once installed and a
nested zone replaces them wholesale.

#### Constructors

```dart
TomZoneValues(
  Map<Object?, Object?>? zoneValues, {
  TomZoneValues? existingValues,
})
```

Starts from `existingValues` (if any) and adds `zoneValues` on top.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `zoneValues` | `Map<Object?, Object?>` | The underlying zone values map (late). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `addAll` | `TomZoneValues addAll(Map<Object?, Object?> other)` | Adds all entries from `other` and returns this container. |
| `clear` | `void clear()` | Clears all zone values. |
| `containsKey` | `bool containsKey(Object? key)` | Returns whether `key` exists in the zone values. |
| `remove` | `Object? remove(Object? key)` | Removes `key`, returning the removed value or `null` if absent. |

#### Operators

| Operator | Signature | Description |
| -------- | --------- | ----------- |
| `operator []=` | `void operator []=(Object? key, Object? value)` | Sets a zone value by key. |
| `operator []` | `Object? operator [](Object? key)` | Gets a zone value by key. |

### TomContextEntry\<T\>

A typed context entry wrapping a lazy value provider; the value is computed on
access.

- **Type Parameters:** `<T>`

`TomExecutionContext.getEntry` matches `T` exactly, so `T` must be written
explicitly at every call site: `TomContextEntry<String>(() => 'acme')`. Written
bare inside the `Map<String, TomContextEntry>` a context is constructed from,
the entry infers `TomContextEntry<dynamic>` from the map's value type rather
than from the value expression, and every typed read of it returns `null`.

#### Constructors

```dart
const TomContextEntry<T>(T? Function() contextFunction)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `contextFunction` | `T? Function()` | Function that provides the context value (final). |
| `type` | `Type` | The type `T` of this entry's value (getter). |
| `value` | `T?` | The value produced by calling `contextFunction` (getter). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `call` | `T? call()` | Returns the value directly by invoking `contextFunction`. |

#### Operators

| Operator | Signature | Description |
| -------- | --------- | ----------- |
| `operator ~` | `T? operator ~()` | Returns the value directly by invoking `contextFunction`. |

### TomContextProviders

Static providers for common context values drawn from the current zone's
`TomPrincipal`, each returning a sensible default when no principal is present.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getOrganization` | `static String getOrganization()` | Organization from the current principal, or `"default"`. |
| `getApplication` | `static String getApplication()` | Application from the current principal, or `"default"`. |
| `getProcess` | `static String getProcess()` | Process from the current principal, or `"default"`. |
| `getLanguage` | `static String getLanguage()` | Server language from the current principal, or `"en"`. |
| `getCountry` | `static String getCountry()` | Server country from the current principal, or `"XX"`. |
| `getTimezone` | `static String getTimezone()` | Server timezone from the current principal, or `"utc"`. |
| `getClientLanguage` | `static String getClientLanguage()` | Client language from the current principal, or `"en"`. |
| `getClientCountry` | `static String getClientCountry()` | Client country from the current principal, or `"XX"`. |
| `getClientTimezone` | `static String getClientTimezone()` | Client timezone from the current principal, or `"utc"`. |

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `tomExecutionContext` | `TomExecutionContext` | Pre-configured execution context wiring the `TomContextProviders` entries (`organization`, `application`, `process`, `language`, `country`, `timezone`, `clientLanguage`, `clientCountry`, `clientTimezone`). Declared with `var`, so reassignable. |

### Functions

None — this module exposes no top-level functions.
