# Tom Core Kernel API Reference: Context Module

A zone-based execution-context system that propagates request-scoped values
(user principal data, tenant information, locale) through synchronous and
asynchronous call chains without explicit parameter passing, together with the
tenant, the W3C trace and the request id a piece of work belongs to.

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
  - [TomTraceContext](#tomtracecontext)
  - [TomRequestId](#tomrequestid)
- [Global Functions and Constants](#global-functions-and-constants)
  - [Constants](#constants)
  - [Functions](#functions)

## Overview

Source: `lib/src/tombase/context/execution_context.dart`,
`lib/src/tombase/context/request_id.dart`,
`lib/src/tombase/context/tenant_context.dart`,
`lib/src/tombase/context/trace_context.dart`.

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

`TomTraceContext` carries, in the same zone again, the **trace** the work belongs
to in the W3C Trace Context form — a 32-hex-digit trace id, a 16-hex-digit span
id, the span it continues, the `sampled` flag and the caller's `tracestate`.
`parse` reads a `traceparent` header (and a `tracestate`) and answers `null` for
an invalid one, `newRoot` starts a trace, `child` continues one with a new span,
and `traceparent` / `headers` render what to send on an outgoing call —
`TomResilientClient` (http_connection module) sends a child span with every
call. `tom_core_server`'s request pipeline continues an incoming trace (or
starts one) and serves the request inside `TomTraceContext.run`; the structured
log output (logging module, `TomLogContext`) reads `TomTraceContext.current`
into every line's `trace_id` and `span_id`.

`TomRequestId` carries, beside the trace, the **id of the unit of work** — a
request, a job run, a socket message — that every log line (`request_id`),
server exception and audit entry of that work names. `runRoot` starts work of
its own in a new trace whose trace id is the request id (a job run, a
delivery); `runChild` starts one step of the current work in a new span, with
the id `<trace id>-<span id>` (a socket message); `run` publishes an id chosen
elsewhere — `tom_core_server`'s request pipeline uses the caller's trace id, or a
trusted proxy's request-id header. An id is 8 to 128 characters of ASCII
letters, digits and `._:-`, starting with a letter or digit.

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

TomTraceContext

TomRequestId  (final)
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
| `qualifyCurrent` | `static String qualifyCurrent(String name)` | `name` qualified by the tenant in context — `qualify(name, currentId)`. The key a store files a per-tenant name under where several tenants' rows share one table, e.g. another principal's id in a resource grant. |

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

### TomTraceContext

One position in a trace: the trace, this span, the span it continues, and
whether the trace is sampled. The ids are those of the W3C `traceparent` header
— lower-case hex, 32 digits for the trace and 16 for a span, never all zeros.

- **Extends:** none

#### Constructors

```dart
TomTraceContext({
  required String traceId,
  required String spanId,
  String? parentSpanId,
  bool sampled = true,
  String? traceState,
})
factory TomTraceContext.newRoot({bool sampled = true})
```

The generative constructor throws `FormatException` for an id that is not
lower-case hex of the right length, or that is all zeros — the W3C rule for an
invalid id. `newRoot` starts a new trace with a new span, from a secure random
source, for work no caller is tracing.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `parse` | `static TomTraceContext? parse(String? header, {String? traceState})` | The context a `traceparent` header value names (version `00`, surrounding whitespace ignored), or `null` when `header` is absent or invalid. An invalid header is ignored rather than refused, as the W3C specification requires: a malformed header from an upstream proxy must not fail the request, it only fails to continue the trace. The parsed context has no `parentSpanId`; its `spanId` is the caller's span. `traceState` is the request's `tracestate` header: carried on (trimmed) when `validTraceState` accepts it, dropped otherwise — never repaired. |
| `validTraceState` | `static bool validTraceState(String value)` | Whether `value` may be passed on as a `tracestate` header: non-empty and at most 512 characters of printable ASCII once trimmed — the W3C limit on what a participant must propagate. The list members are the vendors' and are not interpreted. |
| `run` | `static R run<R>(TomTraceContext context, R Function() body)` | Runs `body` with `context` as the current trace context. The zone follows the body across its awaits. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `traceId` | `String` | The trace, 32 lower-case hex digits (final). |
| `spanId` | `String` | This span, 16 lower-case hex digits (final). |
| `parentSpanId` | `String?` | The span this one continues, or `null` for the first span of a trace (final). |
| `sampled` | `bool` | Whether the trace is recorded — the `sampled` flag of `traceparent` (final). |
| `traceState` | `String?` | The caller's `tracestate`, passed on unchanged, or `null` (final). |
| `traceparent` | `String` | *(getter)* This context as a `traceparent` header value, `00-<traceId>-<spanId>-<01 or 00>` — the value to send on an outgoing call so the callee continues this span. |
| `headers` | `Map<String, String>` | *(getter)* The headers an outgoing call carries so the callee continues this span: `traceparent`, and `tracestate` when there is one. |

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `current` | `TomTraceContext?` | *(getter)* The context of the current zone, or `null` outside any trace. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `child` | `TomTraceContext child()` | A new span in the same trace, continuing this one: same `traceId`, `sampled` and `traceState`, a new `spanId`, and this span as `parentSpanId`. |
| `toString` | `String toString()` | *(override)* `TomTraceContext(<traceparent>)`. |

### TomRequestId

The correlation id of the work running in the current zone — a request, a job
run, a socket message. It is published into the zone under its own type, so
`getFromCurrentZone<TomRequestId>()` and `current` answer the same; the
structured log output writes it as `request_id`, a `tom_core_server` exception
names it, and an audit entry records it.

| Work | Request id |
| ---- | ---------- |
| An HTTP request with a valid `traceparent` | the caller's trace id |
| An HTTP request with a request-id header from a trusted proxy | that header's value, when `isValid` accepts it |
| Any other HTTP request | the trace id of the new trace it starts |
| A job run, and so an outbox delivery | the trace id of a new trace (`runRoot`) |
| A socket message read through `TomWebSocketConnection.serve` | `<trace id>-<span id>` (`runChild`) |

The HTTP rows are `tom_core_server`'s request pipeline; this type holds the
value and the ways of starting work under one.

- **Kind:** final class.
- **Extends:** none

#### Constructors

```dart
TomRequestId()
TomRequestId.of(String value)
```

`TomRequestId()` is a new id, a random version-4 UUID from a secure random
source. `TomRequestId.of` throws `FormatException` unless `isValid` accepts
`value`.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `tryOf` | `static TomRequestId? tryOf(String? value)` | The id `value` names, or `null` when `value` is absent or not valid. |
| `isValid` | `static bool isValid(String value)` | Whether `value` may be a request id: 8 to 128 characters of ASCII letters, digits and `._:-`, the first a letter or digit. Narrow on purpose: the id is written into log lines, response headers and an audit column 191 characters wide, and a caller may supply it. |
| `run` | `static R run<R>(TomRequestId id, R Function() body)` | Runs `body` with `id` as the current request id. |
| `runRoot` | `static R runRoot<R>(R Function() body)` | Runs `body` as work of its own: in a new trace (`TomTraceContext.newRoot`), whose trace id is the request id. For work no caller started — a job run, a delivery. |
| `runChild` | `static R runChild<R>(R Function() body)` | Runs `body` as one step of the current work: in a new span of the current trace (a new trace, as `runRoot`, when there is none), with the request id `<trace id>-<span id>`. For work that belongs to a longer conversation — one message of a socket. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `value` | `String` | The id (final). |
| `hashCode` | `int` | *(getter, override)* The hash of `value`. |

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `current` | `TomRequestId?` | *(getter)* The id of the current zone, or `null` outside any unit of work. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `operator ==` | `bool operator ==(Object other)` | *(override)* Equal to another `TomRequestId` with the same `value`. |
| `toString` | `String toString()` | *(override)* `TomRequestId: <value>`. |

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `tomExecutionContext` | `TomExecutionContext` | Pre-configured execution context wiring the `TomContextProviders` entries (`organization`, `application`, `process`, `language`, `country`, `timezone`, `clientLanguage`, `clientCountry`, `clientTimezone`). Declared with `var`, so reassignable. |

### Functions

None — this module exposes no top-level functions.
