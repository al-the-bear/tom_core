# Tom Core Server API Reference: Cache Module

Named in-memory caches with optional time-based expiry and LRU eviction, served
from the main isolate and transparently forwarded to from worker isolates.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomCacheException](#tomcacheexception)
  - [TomCacheEntry](#tomcacheentry)
  - [TomCacheManager](#tomcachemanager)
  - [TomCache](#tomcache)
  - [TomCacheStoreMessage](#tomcachestoremessage)
  - [TomCacheRemoveMessage](#tomcacheremovemessage)
  - [TomCacheRetrieveMessage](#tomcacheretrievemessage)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/cache/server_cache.dart`.

`TomCache` is a named in-memory cache of `TomCacheEntry` values keyed by string.
A cache is **bounded by default** (`maximumEntries`, LRU eviction) and unbounded
on request (`maximumEntries: null`, a plain map with optional time-based
expiry). Two background timers can be
installed: a deletion timer that drops expired entries and a clearance timer that
empties the whole cache. Both are created in `Zone.root`, not in the zone that
constructed the cache, so a cache first built on a request path does not leave
two process-lifetime timers answering to that one request. The static `…NameCache` / `…TypeCache` helpers look the
cache up through `TomCacheManager` and, in a worker isolate that does not hold
the cache, forward the operation to the main isolate. A forwarded operation that
fails there fails here too: a read of a cache that exists nowhere raises rather
than answering `null`, and a store into one raises rather than reporting the `0`
that means success. A forwarded read matches a local one on the two outcomes the
transport cannot classify as well — a value that fails to convert to `T` throws
rather than reporting a miss, and a miss is `null` rather than the
`TomExecutor.noResult` sentinel that `executeInCreator` substitutes for it.

**Forwarding is one crossing per operation**, by decision: there is no batch
command and no worker-side copy, so ten lookups from a worker are ten round
trips and repeating a key costs again. A batch command would only help a call
site that knows its keys up front, and a worker-side copy would cost the
module's guarantee that exactly one copy of a cached value exists. The local
registry is consulted *before* forwarding, so a deployment that needs the
crossing gone registers the cache in the worker as well — taking on the second
copy deliberately.

`TomCacheManager` holds the named `TomCache` instances for an isolate and decides
whether operations run locally or are forwarded. `TomCacheException` is raised
when an operation cannot complete. `TomCacheStoreMessage`,
`TomCacheRemoveMessage`, and `TomCacheRetrieveMessage` are cross-isolate commands
that carry store/remove/read operations to the main isolate.

## Class Hierarchy

```
TomServerException  (little_things)
    └── TomCacheException

TomCacheEntry

TomCacheManager

TomCache

TomCommand  (kernel)
    ├── TomCacheStoreMessage
    ├── TomCacheRemoveMessage
    └── TomCacheRetrieveMessage
```

## Classes

### TomCacheException

Raised by the cache API when an operation cannot be completed: the named cache
does not exist in this isolate (and cannot be forwarded), or a retrieved value
does not match the requested type parameter.

Defaults to **`clientThrow: false`**, unlike its base, which defaults to `true`.
Neither failure is actionable by a caller: a missing cache names an entry in a
server-side registry, and a type mismatch says the server stored something other
than what it now reads back. The type-mismatch message names the stored value's
runtime type rather than the value itself, so a cached payload is not rendered
into a logged message. The flag is a parameter, so a raise site with a genuinely
public cache can pass `true`.

The type mismatch is the module's only failure with an underlying cause, and it
carries it: the cast's `TypeError` as `rootException` and the cast site's trace
as `stack`. The runtime's message names the target type as it was resolved,
which the wrapper's own message cannot, and reports types only — never the
value that failed to convert. The other raise sites decide by inspection and
have no cause to pass.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomCacheException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
  bool clientThrow = false,
})
```

### TomCacheEntry

A single cached value paired with the optional `deletionTime` after which it is
considered expired.

In a bounded cache (`TomCache.maximumEntries` set) an entry is also linked into
the most-recently-used list through private `_next` / `_before` pointers, so the
least-recently-used entry can be evicted in O(1). The pointers are the cache's,
not the caller's: an entry belongs to one position in one chain, which is why
`removeEntry` is the module's only unlink routine.

#### Constructors

```dart
TomCacheEntry(Object value, [DateTime? deletionTime])
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `deletionTime` | `DateTime?` | The instant after which this entry is expired; `null` means it does not expire on its own — it may still be evicted by an LRU bound or a clear. |
| `value` | `Object` | The cached value. Non-nullable: an entry holding `null` would be a value no read could surface, since `null` is already what a miss answers. |

### TomCacheManager

Holds the set of named `TomCache` instances for an isolate and decides whether
cache operations run locally or are forwarded to the creator isolate. The caches
physically live in the main isolate.

#### Constructors

```dart
TomCacheManager([bool useInThisIsolate = false])
```

The default is `false`, but the constructor **forces `useInThisIsolate` to
`true` when it runs in the main isolate** — the argument is only honoured in a
worker. Reading the signature alone would suggest a main-isolate manager starts
out forwarding, which it never does.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setCurrent` | `static TomCacheManager setCurrent(TomCacheManager manager)` | Replaces the process-wide current manager and returns it. |
| `getCache` | `static TomCache? getCache(String name)` | Returns the cache registered under `name`, or `null` if none is. |
| `addCache` | `static void addCache(TomCache cache)` | Registers `cache` under its `cacheName`. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `useInThisIsolate` | `bool` | Whether caches are served from this isolate; always `true` in the main isolate, `false` in a worker forwards missing-cache operations to the creator. |

### TomCache

A named in-memory cache of `TomCacheEntry` values keyed by string, either
unbounded or bounded (LRU).

Both constructors throw an `ArgumentError`, naming the parameter, when any of
`maximumEntries`, `deletionIntervalSeconds`, `clearIntervalSeconds` or
`deleteEntriesAfterSeconds` is present and not positive. `null` switches each of
them off, so zero is not a second way of saying that: a non-positive
`maximumEntries` or `deleteEntriesAfterSeconds` would make the cache accept
every store and miss every read, and a non-positive interval would make that
sweep a busy loop, since `Timer.periodic` reads a zero (or negative) period as
*as fast as the event loop allows* rather than as *never*.

#### Constructors

```dart
TomCache(
  String cacheName, {
  int? deleteEntriesAfterSeconds,
  int? deletionIntervalSeconds = 3600,
  int? maximumEntries = TomCache.defaultMaximumEntries,
  int? clearIntervalSeconds,
})

factory TomCache.forType(
  Type type, {
  int? deleteEntriesAfterSeconds,
  int? deletionIntervalSeconds = 3600,
  int? maximumEntries = TomCache.defaultMaximumEntries,
  int? clearIntervalSeconds,
})
```

#### Static Members

| Member | Type | Description |
| ------ | ---- | ----------- |
| `defaultMaximumEntries` | `int` | The bound a cache gets when the caller names none (100). The number matters less than the fact that there is one: an unbounded cache with no lifetime grows for the life of the process, and whether that is a leak depends on the shape of the key — bounded for a route or a template name, unbounded for a user id or a request parameter — which the cache cannot see. So the default is the answer that is merely *wrong* in the first case rather than *unbounded* in the second. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `fromTypeCache` | `static Future<T?> fromTypeCache<T>(String key)` | Reads the value of type `T` keyed by `key` from the cache named after `T`. |
| `fromNameCache` | `static Future<T?> fromNameCache<T>(String cacheName, String key)` | Reads the value keyed by `key` from cache `cacheName`; returns `null` on a miss or expiry, and an expired entry is removed in passing; throws `TomCacheException` on type mismatch or missing cache, and forwards from a worker isolate — with the same answers on the forwarded path as on the local one. |
| `toTypeCache` | `static Future<void> toTypeCache<T>(String key, Object value)` | Stores `value` under `key` in the cache named after `T`. |
| `toNameCache` | `static Future<void> toNameCache(String cacheName, String key, Object value, [DateTime? deletionTime])` | Stores `value` under `key` in cache `cacheName`, defaulting expiry from the cache's `deleteEntriesAfterSeconds`; a `value` that is already a `TomCacheEntry` is stored verbatim and keeps its own `deletionTime` instead, linked into the LRU chain like any other entry. `value` is non-nullable: a `null` is refused, being what a miss already answers. |
| `removeFromTypeCache` | `static Future<void> removeFromTypeCache<T>(String key)` | Removes the entry keyed by `key` from the cache named after `T`. |
| `removeFromNameCache` | `static Future<void> removeFromNameCache(String cacheName, String key)` | Removes the entry keyed by `key` from cache `cacheName`; forwards from a worker isolate. Removing an absent key is not an error. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `cacheName` | `String` | The name this cache is registered under in `TomCacheManager` (final). |
| `deletionIntervalSeconds` | `int?` | How often (seconds) the deletion timer sweeps expired entries; `null` disables it, a value must be positive (default 3600, final). |
| `deleteEntriesAfterSeconds` | `int?` | Default lifetime (seconds) applied when no explicit deletion time is given; `null` means no age expiry, a value must be positive (final). |
| `clearIntervalSeconds` | `int?` | How often (seconds) the clearance timer empties the whole cache; `null` disables it, a value must be positive (final). |
| `maximumEntries` | `int?` | Upper bound on entries; a positive value turns on LRU eviction and `null` makes the cache unbounded. Defaults to `defaultMaximumEntries`, so a cache is bounded unless the caller asks otherwise (final). |
| `deletionTimer` | `Timer?` | The periodic timer that sweeps expired entries, or `null` when none is running — the interval is unset, or `stopTimers` has since cleared it. |
| `clearanceTimer` | `Timer?` | The periodic timer that clears the whole cache, or `null` when none is running — the interval is unset, or `stopTimers` has since cleared it. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `removeEntry` | `void removeEntry(String key)` | Removes the entry stored under `key`, unlinking it from the MRU list if the cache is bounded; a no-op when the key is absent. The module's only chain-unlink routine — the deletion sweep and both of `putEntry`'s removals (replacing a key, evicting the least-recently-used entry) go through it. |
| `getEntry` | `TomCacheEntry? getEntry(String key)` | Returns the entry under `key`, or `null` if absent; in a bounded cache the entry is promoted to most-recently-used. **Does not check expiry, by decision**: this is the *structural* read, and applying a value-level policy here would collapse "no such key" and "a key whose value has died" into one `null` — the distinction a structural read exists to keep — and would make a read a mutation, since honouring the rule means dropping the entry. The rule lives once, in `fromNameCache`; the entry handed back carries its own `deletionTime`, so a caller can apply it. |
| `putEntry` | `void putEntry(String key, TomCacheEntry entry)` | Stores `entry` under `key` at the most-recently-used position; in a bounded cache, exceeding `maximumEntries` evicts the least-recently-used entry. Storing under a key the cache already holds replaces the entry — the previous one is unlinked through `removeEntry` first, so it leaves the MRU chain rather than staying in it unreachable and later being evicted in the replacement's place. |
| `createTimers` | `void createTimers()` | Cancels any running timers and installs the deletion and/or clearance timers for which an interval is configured. Both are created in `Zone.root`, so it does not matter where the cache was constructed or from where this is called. |
| `stopTimers` | `void stopTimers()` | Cancels the deletion and clearance timers if they are running and clears both fields; the intervals are untouched, so `createTimers` restarts the cache. |
| `createDeletionTimer` | `Timer createDeletionTimer()` | Builds the periodic timer that removes entries past their `deletionTime`, in `Zone.root`. |
| `createClearanceTimer` | `Timer createClearanceTimer()` | Builds the periodic timer that empties the entire cache, in `Zone.root`. |

### TomCacheStoreMessage

Cross-isolate command that stores `value` under `key` in cache `cacheName`,
dispatched to the main isolate when a worker stores into a cache it does not
hold.

- **Extends:** `TomCommand`

#### Constructors

```dart
TomCacheStoreMessage(String cacheName, String key, Object value, DateTime? deletionTime)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `cacheName` | `String` | Name of the target cache. |
| `key` | `String` | Entry key. |
| `value` | `Object` | Value to store. Non-nullable, like `TomCache.toNameCache`'s own parameter. |
| `deletionTime` | `DateTime?` | The expiry the caller asked for, applied on arrival in the main isolate. `null` means no explicit expiry, and the target cache's `deleteEntriesAfterSeconds` fills it in. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `execute` | `Future<bool> execute()` | *(override)* Stores the value in the main-isolate cache, under `deletionTime`, and returns `true`. |

### TomCacheRemoveMessage

Cross-isolate command that removes `key` from cache `cacheName`, dispatched to
the main isolate when a worker removes from a cache it does not hold.

- **Extends:** `TomCommand`

#### Constructors

```dart
TomCacheRemoveMessage(String cacheName, String key)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `cacheName` | `String` | Name of the target cache. |
| `key` | `String` | Entry key to remove. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `execute` | `Future<bool> execute()` | *(override)* Removes the entry from the main-isolate cache and returns `true`. |

### TomCacheRetrieveMessage

Cross-isolate command that reads `key` from cache `cacheName` and returns the
value, dispatched to the main isolate when a worker reads from a cache it does
not hold.

- **Extends:** `TomCommand`

#### Constructors

```dart
TomCacheRetrieveMessage(String cacheName, String key)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `cacheName` | `String` | Name of the target cache. |
| `key` | `String` | Entry key to read. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `execute` | `Future<Object?> execute()` | *(override)* Reads the entry from the main-isolate cache and returns its value. |

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
