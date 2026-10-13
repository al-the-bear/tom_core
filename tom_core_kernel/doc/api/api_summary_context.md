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
  - [TomTenantContext](#tomtenantcontext)
  - [TomTenantException](#tomtenantexception)
  - [TomTenantScopedCommand](#tomtenantscopedcommand)
  - [TomTenantEvent](#tomtenantevent)
- [Global Functions and Constants](#global-functions-and-constants)
  - [Constants](#constants)
  - [Functions](#functions)

## Overview

Source: `lib/src/tombase/context/execution_context.dart`,
`lib/src/tombase/context/tenant_context.dart`.

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

`TomTenantContext` carries, in the same zone, the **tenant** a piece of work
belongs to. A tenant is an isolation boundary — whose data a query may read,
which database or schema a connection reaches, whose cache entries and queued
jobs these are. It is not the **organization**, a business unit inside a tenant
that `TomContextProviders.getOrganization` reads; the framework never infers one
from the other. The server's request pipeline sets the tenant per request; work
that leaves the request carries it explicitly — a job run records it and the
scheduler runs the body back inside it through `TomTenantScopedCommand`, and an
event-triggered job learns it from a `TomTenantEvent`.

## Class Hierarchy

```
TomExecutionContext

TomZoneValues

TomContextEntry<T>

TomContextProviders

TomTenantContext  (abstract final)
TomException  (little_things)
    └── TomTenantException
TomCommand  (isolate_pooling)
    └── TomTenantScopedCommand
TomTenantEvent
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
| `contextMap` | `Map<String, TomContextEntry>` | The entries by name, as a **live unmodifiable view** — reads and iteration only, and it tracks later changes rather than snapshotting. A write throws `UnsupportedError`: a context is installed in a zone and every caller there reads the same object, so a write through this map would be a write into everyone else's context. Change a context with `add`, `clear` or `combineWith`. Prefer `getEntry` / `getValueFromCurrentZone` for reading a single entry — they answer with the entry's type; this view is for what they cannot answer, such as which names exist. |

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
| `zoneValues` | `final Map<Object?, Object?>` | The underlying zone values map. The map is mutable by design — writing values from inside the zone is what this container exists for, and is what raw zone values cannot do — so unlike `TomExecutionContext.contextMap` it is not a read-only view. The *slot* is `final`: the backing map of a container other code in the same zone is reading through cannot be swapped. Write with `[]=`, empty with `clear()`. |

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

`TomExecutionContext.getEntry` reads by assignability, so an entry declared
`TomContextEntry<int>` is found by `getEntry<num>` and `getEntry<Object>`, and
not by `getEntry<String>`. `T` must still be written explicitly at every call
site: `TomContextEntry<String>(() => 'acme')`. Written bare inside the
`Map<String, TomContextEntry>` a context is constructed from, the entry infers
`TomContextEntry<dynamic>` from the map's value type rather than from the value
expression — and `dynamic` is a subtype of nothing, so every typed read of it
still returns `null`.

#### Constructors

```dart
const TomContextEntry(T? Function() contextFunction)
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

Each reads **one** field; none chooses between the stored pair and the device's.
The locale to render text in for a recipient is derived by
`TomTextLocale.fromPrincipal` (`tom_core_server`, resources module), which
applies that precedence and answers `null` rather than a sentinel.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getOrganization` | `static String getOrganization()` | Organization from the current principal, or `"default"`. |
| `getApplication` | `static String getApplication()` | Application from the current principal, or `"default"`. |
| `getProcess` | `static String getProcess()` | Process from the current principal, or `"default"`. |
| `getLanguage` | `static String getLanguage()` | Stored language from the current principal, or `"en"` — meaning none was named, not that the user reads English. |
| `getCountry` | `static String getCountry()` | Stored country from the current principal, or `"XX"` — a deliberate non-locale sentinel from the ISO 3166-1 user-assigned range, not a country. |
| `getTimezone` | `static String getTimezone()` | Server timezone from the current principal, or `"utc"`. |
| `getClientLanguage` | `static String getClientLanguage()` | Client language from the current principal, or `"en"`. |
| `getClientCountry` | `static String getClientCountry()` | Client country from the current principal, or `"XX"`; often the stored value, since `TomLoginMessage.clientCountry` defaults to it. |
| `getClientTimezone` | `static String getClientTimezone()` | Client timezone from the current principal, or `"utc"`. |

### TomTenantContext

The current tenant, held in the zone. All members are static.

- **Extends:** none (abstract final — not instantiable)

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `idPattern` | `RegExp` | `^[a-z][a-z0-9_]{0,31}$` — a lower-case letter, then up to 31 lower-case letters, digits or underscores (final). Narrow on purpose: a tenant id names a schema or a database in the stronger isolation models, is part of cache keys and job windows, and is written into tokens, so it must be a safe identifier everywhere. |
| `currentId` | `String?` | *(getter)* The tenant the current zone belongs to, or `null` when it belongs to none — a deployment without tenancy, a system task, an anonymous request that named no tenant. |
| `isSet` | `bool` | *(getter)* Whether the current zone states a tenant (or states that it has none), as opposed to inheriting no statement at all. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `run` | `static R run<R>(String? tenantId, R Function() body)` | Runs `body` with `tenantId` as the current tenant; `null` runs it explicitly outside every tenant. Throws `tenancy.id.invalid` for an id that is not `idPattern`. |
| `require` | `static String require(String what)` | The current tenant, or throws `tenancy.context.missing` naming `what` needed it. |
| `validate` | `static void validate(String tenantId)` | Throws `tenancy.id.invalid` unless `tenantId` matches `idPattern`. |
| `qualify` | `static String qualify(String name, [String? tenantId])` | `name` qualified by `tenantId` — `tenant:<id>/<name>` — or `name` itself when `tenantId` is `null`. The one spelling every tenant-scoped key uses (cache entries, revocations), so two tenants' `alice` never meet. |

### TomTenantException

A tenant identifier or context that cannot be used.

| Key | Meaning |
| --- | ------- |
| `tenancy.id.invalid` | A tenant id is not a lower-case identifier of at most 32 characters. |
| `tenancy.context.missing` | Tenant-owned work ran with no tenant in context. |

- **Extends:** `TomException`

#### Constructors

```dart
TomTenantException(String key, String defaultUserMessage, {Map<String, Object?>? parameters})
```

### TomTenantScopedCommand

A `TomCommand` that runs `inner` inside `tenantId`'s context — wherever it
executes, including a worker isolate the command is copied into, where the zone
does not follow. The scheduler wraps the body of every run of a tenant in one.

- **Extends:** `TomCommand`

#### Constructors

```dart
TomTenantScopedCommand(String tenantId, TomCommand inner)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `tenantId` | `String` | The tenant the command runs for (final). |
| `inner` | `TomCommand` | The work (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `execute` | `Future<Object?> execute()` | *(override)* Runs `inner.execute()` inside `TomTenantContext.run(tenantId, …)`. |

### TomTenantEvent

An event for an event-triggered job, carrying the tenant it was raised for. A
stream listener runs in the zone it subscribed in, not the zone the event was
added from, so a tenant cannot reach an event-triggered run through the zone.
Adding a `TomTenantEvent` to the job's stream instead makes the run record the
tenant, carry `payload`, and run its body inside the tenant.

- **Extends:** none

#### Constructors

```dart
const TomTenantEvent(String tenant, Object? payload)
factory TomTenantEvent.inCurrentTenant(Object? payload)
```

`inCurrentTenant` takes the current tenant, and throws `tenancy.context.missing`
when there is none.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `tenant` | `String` | The tenant the run belongs to (final). |
| `payload` | `Object?` | The run's payload (final). |

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `tomExecutionContext` | `TomExecutionContext` | Pre-configured execution context wiring the `TomContextProviders` entries (`organization`, `application`, `process`, `language`, `country`, `timezone`, `clientLanguage`, `clientCountry`, `clientTimezone`). Declared with `var`, so reassignable. |

### Functions

None — this module exposes no top-level functions.
