# Tom Execution Context System

The Tom Execution Context System provides zone-based context propagation for passing request-scoped values through synchronous and asynchronous call chains without explicit parameter passing.

The module also carries the **tenant** a piece of work belongs to —
`TomTenantContext` — in the same zone. A tenant is an isolation boundary, not an
organization: see [Tenant Context](#tenant-context). And it carries the
**trace** the work belongs to — `TomTraceContext`, in the W3C Trace Context
form — so every log line written while serving a request can name it: see
[Trace Context](#trace-context).

## Table of Contents

- [Overview](#overview)
  - [How It Works](#how-it-works)
  - [Two reads, and which one to use](#two-reads-and-which-one-to-use)
    - [Both keys are reserved](#both-keys-are-reserved)
  - [The `zoneValues:` argument is not zone values](#the-zonevalues-argument-is-not-zone-values)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
  - [TomExecutionContext](#tomexecutioncontext)
  - [TomZoneValues](#tomzonevalues)
  - [TomContextEntry](#tomcontextentry)
  - [TomContextProviders](#tomcontextproviders)
- [Context Propagation](#context-propagation)
- [Context Composition](#context-composition)
  - [Which side wins on a colliding name](#which-side-wins-on-a-colliding-name)
- [Default Context](#default-context)
- [Tenant Context](#tenant-context)
  - [Tenant and organization](#tenant-and-organization)
  - [Running work in a tenant](#running-work-in-a-tenant)
  - [Tenant-scoped keys](#tenant-scoped-keys)
  - [Jobs carry their tenant](#jobs-carry-their-tenant)
  - [Failure keys](#failure-keys)
- [Trace Context](#trace-context)
  - [Trace, span and the `traceparent` header](#trace-span-and-the-traceparent-header)
  - [Continuing, starting and running a trace](#continuing-starting-and-running-a-trace)
  - [An invalid header is ignored, an invalid id is refused](#an-invalid-header-is-ignored-an-invalid-id-is-refused)
  - [Who reads it](#who-reads-it)
- [Best Practices](#best-practices)
  - [1. Always write the entry's type parameter](#1-always-write-the-entrys-type-parameter)
  - [2. Handle Missing Context](#2-handle-missing-context)
  - [3. Create Context Once](#3-create-context-once)
  - [4. Choose the variant by what the body returns, not by whether it is async](#4-choose-the-variant-by-what-the-body-returns-not-by-whether-it-is-async)
  - [5. Document Context Dependencies](#5-document-context-dependencies)
- [Dependencies](#dependencies)

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomExecutionContext` | class | Typed, zone-scoped context of named `TomContextEntry` values. |
| `TomContextEntry` | class | A lazily-evaluated named context value. |
| `TomZoneValues` | class | `Map`-like view over a zone's values used when running in context. |
| `TomContextProviders` | class | Static accessors for the ambient providers (organization, application, …). |
| `TomTenantContext` | abstract final class | The current tenant, held in the zone: `currentId`, `run`, `require`, `validate`, `qualify`, `idPattern`. |
| `TomTenantException` | class | A tenant id that cannot be used, or tenant-owned work with no tenant in context. |
| `TomTenantScopedCommand` | class | A `TomCommand` that runs its inner command inside a tenant, wherever it executes. |
| `TomTenantEvent` | class | An event for an event-triggered job, carrying the tenant it was raised for. |
| `TomTraceContext` | class | The W3C trace and span the current zone's work belongs to: `parse`, `newRoot`, `child`, `traceparent`, `current`, `run`. |

The execution-context system consists of four public types:

1. **`TomExecutionContext`**: Container for context entries that runs code in a Dart Zone with those values available.

2. **`TomContextEntry<T>`**: A typed wrapper for a function that provides a context value.

3. **`TomZoneValues`**: The mutable container for the untyped, ad-hoc values passed as `zoneValues:`.

4. **`TomContextProviders`**: Static methods that extract common values from the current zone's `TomPrincipal`.

A run installs two of these in the zone — the `TomExecutionContext` and the
`TomZoneValues` — and everything else is reached through one of them.

### How It Works

1. Create a `TomExecutionContext` with named entries
2. Call `runInContext()` or `runInContextAsync()` with your code
3. Inside that code, read an entry **by name** with
   `TomExecutionContext.getValueFromCurrentZone<T>('name')` — *not* with
   `getFromCurrentZone<T>()`, which is keyed by type and never sees an entry
4. Use `getFromCurrentZone<T>()` only for the two containers the zone actually
   holds: `getFromCurrentZone<TomExecutionContext>()` for the context itself and
   `getFromCurrentZone<TomZoneValues>()` for ad-hoc values passed as
   `zoneValues:`
5. Context flows automatically through async boundaries

Steps 3 and 4 are the whole trick, and picking the wrong one fails silently —
see [Two reads, and which one to use](#two-reads-and-which-one-to-use) below.

### Two reads, and which one to use

A Dart zone is keyed by `Type`, and `runInContext()` installs exactly two keys:
`TomExecutionContext` and `TomZoneValues`. Everything else lives *inside* one of
those two containers, so which read applies depends on what is being fetched:

- **The containers themselves** are read by type, with
  `getFromCurrentZone<TomExecutionContext>()` and
  `getFromCurrentZone<TomZoneValues>()`.
- **A named context entry** is read by name, with
  `TomExecutionContext.getValueFromCurrentZone<T>('name')`. Its type parameter
  selects the entry's *value* type; it is not a zone key.
- **An ad-hoc zone value** passed as `zoneValues:` is read through the
  container: `getFromCurrentZone<TomZoneValues>()?['requestId']`.

Reaching for the wrong one returns `null` rather than failing, so it is worth
being deliberate: `getFromCurrentZone<String>()` never sees an entry named
`'userId'`, however that entry is typed, because nothing ever installs `String`
as a zone key.

#### Both keys are reserved

`TomExecutionContext` and `TomZoneValues` are ordinary `Type` keys, which is
what makes the reads above possible — a private sentinel would be
collision-proof and unreadable. The price is that a bare
`runZoned(zoneValues: {TomZoneValues: something})` can put a foreign value
under one of them. **Do not.** Use a key of your own; there is nothing special
about these two except that this module owns them.

Passing them through `runInContext`'s own `zoneValues:` is *not* a collision:
that map is nested inside the container rather than merged into the zone, so it
cannot displace anything.

A collision made the other way is reported rather than absorbed. The module
reads these two keys when a run nests inside another, and a foreign value there
is not an absence — inheriting nothing would silently drop every entry the
enclosing run installed, while nesting went on working and every read went on
answering `null`:

```dart
runZoned(
  () => context.runInContext(() {}),   // throws
  zoneValues: {TomZoneValues: 'not a container'},
);
// TomException: context.zone_key.reserved_key_holds_foreign_value
// "The zone key TomZoneValues is reserved for the context module's own
//  container, and holds a String."
```

A plain `getFromCurrentZone<TomZoneValues>()` in such a zone still answers
`null`, and that is correct for a *reader*: it asked for a `TomZoneValues` and
there is none. The refusal belongs to the module, which knows the key is its
own.

### The `zoneValues:` argument is not zone values

`runInContext(..., zoneValues: {...})` borrows the name, the type and the
position of `runZoned`'s own `zoneValues:` parameter, but not its semantics. The
caller's keys are never installed in the zone — they are put inside the
`TomZoneValues` container, and the container is what gets installed. So
`Zone.current[key]` stays `null`, and that holds for a `Type` key too:

```dart
// Correct for runZoned — TomContextProviders will find the principal.
runZoned(() => TomContextProviders.getOrganization(),
    zoneValues: {TomPrincipal: principal});   // 'acme'

// The same line under runInContext installs nothing readable by type.
context.runInContext(() => TomContextProviders.getOrganization(),
    zoneValues: {TomPrincipal: principal});   // 'default' — silently
```

The indirection is deliberate. Routing the values through a container is what
makes them **mutable** from inside the zone
(`getFromCurrentZone<TomZoneValues>()?['requestId'] = id`) and **mergeable**
across nested runs — an inner `runInContext` folds its values into the ones it
inherits rather than shadowing them. Raw zone values offer neither: they are
fixed once installed and a nested zone replaces the whole map.

If code needs a value under a real zone type key — because a third-party library
reads it the ordinary Dart way — pass it to `runZoned` yourself, outside the
context run.

## Quick Start

```dart complete
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // Create a context with custom values
  final context = TomExecutionContext({
    'requestId': TomContextEntry<String>(() => 'req-12345'),
    'userId': TomContextEntry<String>(() => 'user-12345'),
  });

  // Run code within the context
  context.runInContext(() {
    processRequest();
  });
}

void processRequest() {
  // Access context entries from anywhere in the zone, by entry name. The type
  // argument must be the declared entry type or a supertype of it — reading
  // 'userId' as <int> here would return null, not 'user-12345'.
  final requestId =
      TomExecutionContext.getValueFromCurrentZone<String>('requestId');
  final userId =
      TomExecutionContext.getValueFromCurrentZone<String>('userId');
  print('Processing request $requestId for $userId');
}
```

## Core Components

### TomExecutionContext

The main context container that stores named entries and runs code in a zone.

#### Creating a Context

```dart
// Empty context
final context = TomExecutionContext({});

// With entries
final context = TomExecutionContext({
  'tenant': TomContextEntry<String>(() => 'acme-corp'),
  'user': TomContextEntry<User>(() => currentUser),
});

// With parent context (entries are inherited)
final childContext = TomExecutionContext(
  {'childKey': TomContextEntry<String>(() => 'value')},
  parentContext: parentContext,
);
```

#### Getting Context Entries

```dart
// Get entry by name with type checking. 'tenant' was declared above as
// TomContextEntry<String>, and getEntry reads it by assignability — asking
// for getEntry<Object>('tenant') finds it too, getEntry<int>('tenant') does not.
final entry = context.getEntry<String>('tenant');
final value = entry?.value;  // Access via value getter

// Static method to read the same entry from the current zone, inside a
// runInContext body. The same assignability rule applies.
final tenant = TomExecutionContext.getValueFromCurrentZone<String>('tenant');
```

#### Modifying a Context

```dart
final context = TomExecutionContext({});

// Add entries
context.add('locale', TomContextEntry<String>(() => 'en-US'));

// Merge another context
final otherContext =
    TomExecutionContext({'theme': TomContextEntry<String>(() => 'dark')});
context.combineWith(otherContext);

// Clear all entries
context.clear();
```

#### Running Code in Context

```dart
// Synchronous
final result = context.runInContext(() {
  return computeValue();
});

// Asynchronous
final result = await context.runInContextAsync(() async {
  return await fetchData();
});

// With additional zone values, read back through the TomZoneValues container
// (they are not context entries, so getValueFromCurrentZone does not see them)
context.runInContext(() {
  final custom = getFromCurrentZone<TomZoneValues>()?['customKey'];
}, zoneValues: {'customKey': 'customValue'});
```

### TomZoneValues

The mutable container holding everything passed as `zoneValues:`. It is what
`runInContext` installs in the zone under the `TomZoneValues` type key, which is
why an ad-hoc value is read back through the container rather than by its own
key — see [The `zoneValues:` argument is not zone values](#the-zonevalues-argument-is-not-zone-values).

Unlike a context entry, a zone value is untyped (`Object?` key, `Object?` value)
and eagerly stored rather than computed on access. Reach for it when a value
does not warrant a named, typed `TomContextEntry`.

#### Reading and writing

Inside a run, get the container by type and index it. Writes are visible for
the rest of that run:

```dart
context.runInContext(() {
  final values = getFromCurrentZone<TomZoneValues>();

  final requestId = values?['requestId'];   // 'req-1'
  values?['stage'] = 'validated';           // add or overwrite
  values?['requestId'] = 'req-2';           // mutate an inherited value

  print(getFromCurrentZone<TomZoneValues>()?['stage']);  // validated
}, zoneValues: {'requestId': 'req-1'});
```

The container is a single instance per run — every
`getFromCurrentZone<TomZoneValues>()` in the same run returns the same object,
so a write through one read is seen by the next.

#### Members

| Member | Signature | Description |
| ------ | --------- | ----------- |
| `operator []` | `Object? operator [](Object? key)` | Reads a value; null when the key is absent. |
| `operator []=` | `void operator []=(Object? key, Object? value)` | Adds or overwrites a value. |
| `addAll` | `TomZoneValues addAll(Map<Object?, Object?> other)` | Adds every entry from `other`, returning `this` so calls chain. |
| `containsKey` | `bool containsKey(Object? key)` | Whether the key is present — distinguishes "absent" from "present and null". |
| `remove` | `Object? remove(Object? key)` | Removes the key, returning the removed value, or null if it was absent. |
| `clear` | `void clear()` | Removes every value. |
| `zoneValues` | `Map<Object?, Object?>` | The underlying map, exposed directly. |

```dart
final values = TomZoneValues({'a': 1}).addAll({'b': 2}).addAll({'c': 3});

values.containsKey('a');   // true
values.remove('a');        // 1
values.remove('a');        // null — already gone
values.clear();            // {}
```

#### Inheriting from an enclosing run

The `existingValues` constructor argument is how a nested run inherits: the
enclosing container supplies the base values and the new map is added on top,
so the inner run wins on a colliding key.

```dart
final parent = TomZoneValues({'shared': 'parent', 'onlyParent': 'p'});
final child = TomZoneValues({'shared': 'child'}, existingValues: parent);

child.zoneValues;   // {shared: child, onlyParent: p}
parent.zoneValues;  // unchanged — both source maps are copied, not aliased
```

`runInContext` applies exactly this when a run is nested inside another, so an
inner run sees the outer run's values without restating them.

#### Nested writes do not leak outward

Because the nested run gets its **own** container, mutations inside it are
scoped to it. The outer run's values are restored when it returns:

```dart
outer.runInContext(() {
  getFromCurrentZone<TomZoneValues>()?['k'] = 'outer';

  inner.runInContext(() {
    getFromCurrentZone<TomZoneValues>()?['k'];        // 'outer' — inherited
    getFromCurrentZone<TomZoneValues>()?['k'] = 'inner';
    getFromCurrentZone<TomZoneValues>()?['added'] = 'x';
  });

  getFromCurrentZone<TomZoneValues>()?['k'];      // 'outer' — not 'inner'
  getFromCurrentZone<TomZoneValues>()?['added'];  // null — never escaped
});
```

Mutability is therefore per-run, not shared upward: a nested run cannot use
zone values to hand a result back to its caller. Return a value from the run
instead.

### TomContextEntry

A typed wrapper for lazy value providers.

#### Creating Entries

```dart
// Static value
final entry = TomContextEntry<String>(() => 'constant-value');

// Dynamic value (computed each access)
final entry = TomContextEntry<DateTime>(() => DateTime.now());
```

#### Accessing Values

```dart
// Via contextFunction (original method)
final value = entry.contextFunction();

// Via value getter (recommended)
final value = entry.value;

// Via call operator (shortest)
final value = entry();

// Via ~ operator (alternative)
final value = ~entry;

// Value from another zone value
final entry = TomContextEntry<String>(() {
  return getFromCurrentZone<TomPrincipal>()?.organization ?? 'default';
});
```

### TomContextProviders

Static methods for extracting common values from `TomPrincipal`:

```dart
// Organization info (the business unit, not the tenant)
TomContextProviders.getOrganization();  // Returns 'default' if no principal
TomContextProviders.getApplication();
TomContextProviders.getProcess();

// Server locale
TomContextProviders.getLanguage();      // Returns 'en' if no principal
TomContextProviders.getCountry();       // Returns 'XX' if no principal
TomContextProviders.getTimezone();      // Returns 'utc' if no principal

// Client locale
TomContextProviders.getClientLanguage();
TomContextProviders.getClientCountry();
TomContextProviders.getClientTimezone();
```

#### Field readers, not a locale derivation

Each provider reads **one** field and answers a sentinel when it is absent. The
stored pair and the device pair are reported separately on purpose: a caller
that needs a specific claim — an audit entry recording what the device said, a
diagnostic naming what the user chose — must be able to ask for that one rather
than be handed a blend.

Choosing *between* them is a different question, and these providers do not
answer it. To pick the locale to render text in **for a recipient**, use
`TomTextLocale.fromPrincipal` in `tom_core_server`'s resources module: it
applies the precedence rule (stored preference over device) and answers `null`
— not a guess — when the principal names no locale at all.

`'XX'` is a **deliberate non-locale sentinel**, not a country. It sits in the
range ISO 3166-1 permanently withholds from assignment (`AA`, `QM`–`QZ`,
`XA`–`XZ`, `ZZ`) precisely so applications can use it to mean "none", which is
what it means here and in `TomLoginMessage.clientCountry`. Because it is two
letters, anything checking only the *shape* of a country accepts it: composing
`TomTextLocale(getLanguage(), getCountry())` would name the bundle `en_XX`,
which nothing carries. `TomTextLocale`'s country invariant refuses the
user-assigned codes for that reason, so the mistake fails rather than resolving
quietly through some other bundle.

## Context Propagation

Context values automatically propagate through async boundaries:

```dart
final context = TomExecutionContext({
  'traceId': TomContextEntry<String>(() => generateTraceId()),
});

await context.runInContextAsync(() async {
  // TraceId available here
  await step1();
  
  // Still available after await
  await step2();
  
  // And in nested async calls
  await step3();
});

Future<void> step1() async {
  final ctx = getFromCurrentZone<TomExecutionContext>();
  // TraceId still accessible
}
```

This is a property of the zone, not of `runInContextAsync`. A body run by the
synchronous `runInContext` gets the same treatment: it keeps the context across
its own awaits, and a callback it schedules still reads the context when it
fires, after `runInContext` has returned. See
[Best Practice 4](#4-choose-the-variant-by-what-the-body-returns-not-by-whether-it-is-async)
for what the two variants actually differ in.

## Context Composition

Contexts can be nested, with inner contexts overriding outer values:

```dart
final tenantContext = TomExecutionContext({
  'tenant': TomContextEntry<String>(() => 'acme'),
});

final userContext = TomExecutionContext({
  'user': TomContextEntry<String>(() => 'john'),
});

final requestContext = TomExecutionContext({
  'requestId': TomContextEntry<String>(() => 'req-123'),
  'tenant': TomContextEntry<String>(() => 'override-tenant'),
});

tenantContext.runInContext(() {
  // tenant = 'acme'

  userContext.runInContext(() {
    // tenant = 'acme', user = 'john'

    requestContext.runInContext(() {
      // tenant = 'override-tenant', user = 'john', requestId = 'req-123'
    });
  });
});
```

### Which side wins on a colliding name

Three operations merge two sets of entries, and they resolve a collision from
two different ends. **The map applied last wins, and that is always the one
named closest to the call** — but which object that *is* differs:

| operation | on a shared name, the winner is |
| --- | --- |
| `TomExecutionContext(own, parentContext: p)` | `own` — the context's own map |
| `inner.runInContext(...)` nested inside `outer` | `inner` — it builds a context with `outer` as the parent |
| `receiver.combineWith(other)` | `other` — the argument |

The first two are the same operation: nesting constructs a new context with the
installed one as its parent. The third is the one to watch, because from the
receiver's point of view it is the opposite rule — its entries survive
construction and lose a merge:

```dart
final base = TomExecutionContext({
  'tenant': TomContextEntry<String>(() => 'acme'),
});
final override = TomExecutionContext({
  'tenant': TomContextEntry<String>(() => 'zeta'),
});

// Constructed: the context's own map wins over the parent.
final child = TomExecutionContext(
  {'tenant': TomContextEntry<String>(() => 'zeta')},
  parentContext: base,
);
child.getEntry<String>('tenant')?.value;      // 'zeta'

// Merged: the argument wins over the receiver.
base.combineWith(override);
base.getEntry<String>('tenant')?.value;       // 'zeta'

// Reverse the merge when the receiver's value is the one that should stand.
override.combineWith(base);                   // now 'acme' would win
```

## Default Context

The `tomExecutionContext` global provides a pre-configured context with standard providers:

```dart
// Pre-configured entries:
// - organization, application, process
// - language, country, timezone
// - clientLanguage, clientCountry, clientTimezone

tomExecutionContext.runInContext(() {
  // All standard context values available
  final org = TomContextProviders.getOrganization();
  final lang = TomContextProviders.getLanguage();
});
```

## Tenant Context

`TomTenantContext` holds the tenant the current zone belongs to. It sits beside
`TomExecutionContext` rather than inside it, because the tenant is not a value a
caller composes: it is set once, at the edge — the server's request pipeline,
or a job run — and everything that holds tenant data reads it from here.

### Tenant and organization

A **tenant** is an isolation boundary: whose data a query may read, which
database or schema a connection reaches, whose cache entries and queued jobs
these are. Nothing crosses it. An **organization** is a business unit *inside* a
tenant — the `organization` a principal logs in for, which authorization and
`TomContextProviders.getOrganization()` read, and which a tenant may have
several of. A deployment that sells to companies typically makes each customer a
tenant and lets the customer model its departments as organizations. The two can
coincide, but the framework never infers one from the other, and the
`'tenant'` entries in this guide's `TomExecutionContext` examples are ordinary
named values, not the isolation boundary.

`TomPrincipal.tenant` and the token's `tenant` claim carry the tenant across the
wire; see [Tenant and Organization](../security/security.md#tenant-and-organization)
in the security guide.

### Running work in a tenant

```dart
TomTenantContext.run('acme', () {
  print(TomTenantContext.currentId); // acme
  print(TomTenantContext.isSet);     // true
});

TomTenantContext.run(null, () {
  print(TomTenantContext.currentId); // null — explicitly no tenant
  print(TomTenantContext.isSet);     // true
});

print(TomTenantContext.isSet);       // false — no statement at all
```

| Member | Meaning |
| ------ | ------- |
| `currentId` | The tenant the current zone belongs to, or `null` — a deployment without tenancy, a system task, an anonymous request that named no tenant. |
| `isSet` | Whether the zone states a tenant (or states that it has none), as opposed to inheriting no statement at all. |
| `run(tenantId, body)` | Runs `body` with `tenantId` as the current tenant; `null` runs it explicitly outside every tenant. Validates the id first. The zone follows the body across its awaits, like every zone value. |
| `require(what)` | The current tenant, or `tenancy.context.missing` naming `what` needed it. |
| `validate(tenantId)` | Throws `tenancy.id.invalid` unless the id matches `idPattern`. |
| `idPattern` | `^[a-z][a-z0-9_]{0,31}$` — a lower-case letter, then up to 31 lower-case letters, digits or underscores. |
| `qualify(name, [tenantId])` | `name` qualified by the tenant — `tenant:<id>/<name>` — or `name` itself with none. |

The id rule is narrow on purpose. A tenant id names a schema or a database in
the stronger isolation models, is part of cache keys and job windows, and is
written into tokens; an id that is a safe identifier everywhere is one that never
needs quoting anywhere.

### Tenant-scoped keys

`qualify` is the one spelling every tenant-scoped key uses — the server's cache
entries and principal revocations among them — so two tenants' `alice` never
meet:

```dart
TomTenantContext.qualify('alice', 'acme');   // tenant:acme/alice
TomTenantContext.qualify('alice');           // alice
```

### Jobs carry their tenant

Work that leaves the request carries the tenant explicitly. A `TomJobRun`
records its `tenant`, and the scheduler runs the run's body back inside it: the
body factory runs in the tenant's zone, and the command it returns is wrapped in
a `TomTenantScopedCommand`, which re-enters the tenant when it executes — in a
worker isolate too, where the zone does not follow but the command, copied
across, does.

An event-triggered job cannot learn its tenant from the zone, because a stream
listener runs in the zone it subscribed in, not the zone the event was added
from. Adding a `TomTenantEvent` to the job's stream instead makes the run record
the tenant:

```dart
final events = StreamController<Object?>.broadcast();

// Inside a tenant's request: the current tenant, or tenancy.context.missing.
TomTenantContext.run('acme', () {
  events.add(TomTenantEvent.inCurrentTenant({'invoice': 42}));
});

// From anywhere, naming the tenant.
events.add(TomTenantEvent('globex', {'invoice': 7}));
```

The run's payload is the event's `payload`, and its window — one run per job per
instant — is per tenant, so two tenants' events in the same instant are two
runs. See [the scheduling guide](../scheduling/scheduling.md#runs-and-tenants).

### Failure keys

Both are raised as `TomTenantException`, which extends `TomException`.

| Key | Meaning |
| --- | ------- |
| `tenancy.id.invalid` | A tenant id is not a lower-case identifier of at most 32 characters. |
| `tenancy.context.missing` | Tenant-owned work ran with no tenant in context. |

## Trace Context

`TomTraceContext` holds the trace the current zone's work belongs to. Like the
tenant it is set once, at the edge, and read wherever it is needed; unlike the
tenant it isolates nothing — it names the work, so that what one operation did
across every process it touched can be found again.

### Trace, span and the `traceparent` header

A **trace** is the whole of one operation across every process it touches; a
**span** is one process's part of it. The ids are those of the W3C Trace
Context `traceparent` header, so a request arriving from a traced client, a
gateway or a service mesh keeps the caller's trace:

```text
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
             │  │                                │                └ flags: 01 = sampled
             │  │                                └ the caller's span, 16 hex digits
             │  └ the trace, 32 hex digits
             └ version 00
```

| Member | Meaning |
| ------ | ------- |
| `traceId` | The trace, 32 lower-case hex digits. |
| `spanId` | This span, 16 lower-case hex digits. |
| `parentSpanId` | The span this one continues, or `null` for the first span of a trace — and for a context parsed from a header, whose `spanId` is the caller's span. |
| `sampled` | Whether the trace is recorded — the `sampled` flag of `traceparent`. |
| `traceparent` | This context as a header value — what to send on an outgoing call so the callee continues this span. |
| `current` | The context of the current zone, or `null` outside any trace. |

### Continuing, starting and running a trace

```dart
// An incoming request: continue the caller's trace with a span of our own,
// or start a trace when the request carries none.
final incoming = TomTraceContext.parse(
  '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
);
final context = incoming?.child() ?? TomTraceContext.newRoot();

TomTraceContext.run(context, () {
  final current = TomTraceContext.current!;
  print(current.traceId);      // 4bf92f3577b34da6a3ce929d0e0e4736 — the caller's
  print(current.parentSpanId); // 00f067aa0ba902b7 — the caller's span
  print(current.traceparent);  // 00-4bf9…4736-<our span>-01 — for an outgoing call
});

print(TomTraceContext.current); // null — outside the run
```

| Member | Meaning |
| ------ | ------- |
| `parse(header)` | The context a `traceparent` value names, or `null` for an absent or invalid one. |
| `newRoot({sampled})` | A new trace with a new span, for work no caller is tracing. Ids come from a secure random source and are never all zeros. |
| `child()` | A new span in the same trace: same `traceId` and `sampled`, a new `spanId`, this span as `parentSpanId`. |
| `run(context, body)` | Runs `body` with `context` as the current trace context. The zone follows the body across its awaits, as every zone value does; nested runs replace the context for their body only. |

`tom_core_server`'s request pipeline does exactly the first two lines for every
request: it continues an incoming `traceparent` with a server span, or starts a
trace, and serves the request inside `TomTraceContext.run`.

### An invalid header is ignored, an invalid id is refused

The two ways in treat a bad value differently, on purpose:

- **`parse` answers `null`** for a header that is not a valid version-00 value
  — wrong length, upper-case hex, an all-zero id, an unknown version. The W3C
  specification requires an invalid header to be ignored rather than refused: a
  malformed header from an upstream proxy must not fail the request, it only
  fails to continue the trace. The caller then starts a new one.
- **The constructor throws `FormatException`** for an id that is not lower-case
  hex of the right length, or that is all zeros. An id passed to the
  constructor was chosen in code, so a bad one is a programming error.

### Who reads it

The structured log output of the logging module, `TomJsonLogOutput`, writes
`TomTraceContext.current`'s `traceId` and `spanId` into every line as
`trace_id` and `span_id` — see [Structured JSON
Output](../logging/logging.md#structured-json-output). Nothing at the call site
passes them: a line logged anywhere inside the run carries them.

Exporting spans — recording each span's start, end and outcome and sending them
to a tracing backend — is a separate concern this module does not do. The trace
context is the seam such an exporter uses: the spans it would record are the
ones `run` delimits, under the ids this type carries.

## Best Practices

### 1. Always write the entry's type parameter

```dart
// Good
final context = TomExecutionContext({
  'tenant': TomContextEntry<String>(() => 'value'),
  'user': TomContextEntry<User>(() => currentUser),
});

// Broken — reads back as null
final context = TomExecutionContext({
  'tenant': TomContextEntry(() => 'value'),
});
```

This is not a style preference; omitting the type parameter breaks the entry.
The constructor takes a `Map<String, TomContextEntry>`, so a raw
`TomContextEntry(() => 'value')` written inside that map literal gets
`TomContextEntry<dynamic>` as its inference context — the value expression never
gets a say. `getEntry<T>` reads by assignability, and `dynamic` is not a subtype
of anything, so `getValueFromCurrentZone<String>('tenant')` still returns `null`
rather than `'value'`, with no error to point at the cause. The entry promises
nothing, so there is nothing to assign.

The same expression assigned to a local infers `String`, which is what makes the
trap easy to miss: it is the *position* inside the map literal that changes the
inference, not the way the entry is written.

### 2. Handle Missing Context

Every read in this module returns null rather than throwing.
`getFromCurrentZone` yields null outside a `runInContext` body;
`getValueFromCurrentZone` yields null there too, and also for an entry that was
never declared — or was declared with a different type parameter, which is
Best Practice 1's trap. So always check.

What the check does next depends on whether the value is optional or required.
Optional — fall back:

```dart
final ctx = getFromCurrentZone<TomExecutionContext>();
if (ctx == null) {
  // Handle case where code runs outside context
  return defaultValue;
}
```

Required — throw, naming the entry:

```dart
final tenant = TomExecutionContext.getValueFromCurrentZone<String>('tenant');
if (tenant == null) {
  throw StateError('No "tenant" entry in the current execution context.');
}
```

Do not substitute `!` for the required case. It does enforce the requirement,
but it reports the violation as a bare null-check failure — which does not say
which entry was missing, and does not distinguish a missing entry from code
that never ran inside `runInContext` at all. Those are different bugs with
different fixes, and the two reads above cannot tell them apart on their own.

### 3. Create Context Once

Create contexts at request boundaries, not inside loops:

```dart
// Good: Create once per request
void handleRequest(Request req) {
  final context = TomExecutionContext({
    'requestId': TomContextEntry<String>(() => req.id),
  });
  
  context.runInContext(() => processRequest(req));
}

// Avoid: Creating context in inner loops
```

### 4. Choose the variant by what the body returns, not by whether it is async

Both variants install exactly the same zone — each is a single `runZoned` call
over the same merged entries — so the context survives every `await` in either
one, and it also reaches callbacks scheduled from inside the body and read long
after the call returned. Zone propagation is not what distinguishes them.

What distinguishes them is the signature. `runInContextAsync` takes a
`Future<T> Function()` and hands that future back, so `T` names the awaited
value; `runInContext` takes a `T Function()` and returns whatever the body
returns. Choose on whether the caller needs the future:

```dart
// The body is asynchronous and its result is needed: T is the awaited type.
final data = await context.runInContextAsync(() async {
  return await fetchData();
});

// The body is genuinely synchronous.
final total = context.runInContext(() => computeTotal());
```

The failure mode of the synchronous form is a *discarded future*, not a lost
zone:

```dart
// Broken — but not for the reason it looks. asyncOperation() does run in the
// context and keeps it across its awaits. What is lost is the future: the
// void body drops it, so the caller returns before the work finishes and
// cannot await completion or observe a failure.
context.runInContext(() {
  asyncOperation();
});
```

Writing that body under `runInContextAsync` is a compile error, because a
`Future<T> Function()` may not complete without returning one. The synchronous
form leaves the same mistake to the optional `discarded_futures` lint — which
is the practical reason to reach for the async variant when the body is async.

### 5. Document Context Dependencies

Document which context values your functions expect:

```dart
/// Processes the order.
/// 
/// Requires the following context entries:
/// - `userId`: The current user's ID
/// - `tenantId`: The tenant identifier
Future<void> processOrder(Order order) async {
  final userId =
      TomExecutionContext.getValueFromCurrentZone<String>('userId');
  if (userId == null) {
    throw StateError('processOrder requires a "userId" context entry.');
  }
  // ...
}
```

A documented requirement is worth enforcing at the point of use: the doc
comment tells the caller what to install, and the check tells them, by name,
when they did not. See Best Practice 2 for why this is a null check rather
than a `!`.

---

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | every file | `Future`, and `runZoned` for `TomTraceContext.run` |
| `dart:collection` | dart | `execution_context.dart` | `UnmodifiableMapView`, the read-only view `contextMap` hands out |
| `dart:math` | dart | `trace_context.dart` | `Random.secure`, the source of new trace and span ids |
| [isolate_pooling](../isolate_pooling/isolate_pooling.md) | module | `tenant_context.dart` | `TomCommand`, which `TomTenantScopedCommand` extends so a tenant survives an isolate hop |
| [little_things](../little_things/little_things.md) | module | `execution_context.dart`, `tenant_context.dart` | `getFromCurrentZone`, the zone lookup the context installs itself for, and `TomException`, the base of `TomTenantException` |
| [security](../security/security.md) | module | `execution_context.dart` | `TomPrincipal` for authenticated user context |
