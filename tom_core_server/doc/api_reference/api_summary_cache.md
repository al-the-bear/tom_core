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
A cache may be unbounded (a plain map with optional time-based expiry) or
bounded (`maximumEntries` set, LRU eviction). Two background timers can be
installed: a deletion timer that drops expired entries and a clearance timer that
empties the whole cache. The static `…NameCache` / `…TypeCache` helpers look the
cache up through `TomCacheManager` and, in a worker isolate that does not hold
the cache, forward the operation to the main isolate. A forwarded operation that
fails there fails here too: a read of a cache that exists nowhere raises rather
than answering `null`, and a store into one raises rather than reporting the `0`
that means success. A forwarded read matches a local one on the two outcomes the
transport cannot classify as well — a value that fails to convert to `T` throws
rather than reporting a miss, and a miss is `null` rather than the
`TomExecutor.noResult` sentinel that `executeInCreator` substitutes for it.

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
TomCacheEntry(Object? value, [DateTime? deletionTime])
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `deletionTime` | `DateTime?` | The instant after which this entry is expired; `null` means it does not expire on its own — it may still be evicted by an LRU bound or a clear. |
| `value` | `Object?` | The cached value. |

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

Both constructors throw an `ArgumentError` when `maximumEntries` is present and
not positive — the bound is the module's only capacity guarantee, and zero or
less cannot be honoured as one.

#### Constructors

```dart
TomCache(
  String cacheName, {
  int? deleteEntriesAfterSeconds,
  int? deletionIntervalSeconds = 3600,
  int? maximumEntries,
  int? clearIntervalSeconds,
})

factory TomCache.forType(
  Type type, {
  int? deleteEntriesAfterSeconds,
  int? deletionIntervalSeconds = 3600,
  int? maximumEntries,
  int? clearIntervalSeconds,
})
```

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `fromTypeCache` | `static Future<T?> fromTypeCache<T>(String key)` | Reads the value of type `T` keyed by `key` from the cache named after `T`. |
| `fromNameCache` | `static Future<T?> fromNameCache<T>(String cacheName, String key)` | Reads the value keyed by `key` from cache `cacheName`; returns `null` on a miss or expiry, and an expired entry is removed in passing; throws `TomCacheException` on type mismatch or missing cache, and forwards from a worker isolate — with the same answers on the forwarded path as on the local one. |
| `toTypeCache` | `static Future<int> toTypeCache<T>(String key, Object? value)` | Stores `value` under `key` in the cache named after `T`. |
| `toNameCache` | `static Future<int> toNameCache(String cacheName, String key, Object? value, [DateTime? deletionTime])` | Stores `value` under `key` in cache `cacheName`, defaulting expiry from the cache's `deleteEntriesAfterSeconds`; a `value` that is already a `TomCacheEntry` is stored verbatim and keeps its own `deletionTime` instead, linked into the LRU chain like any other entry. Always returns `0`. |
| `removeFromTypeCache` | `static Future<int> removeFromTypeCache<T>(String key)` | Removes the entry keyed by `key` from the cache named after `T`. |
| `removeFromNameCache` | `static Future<int> removeFromNameCache(String cacheName, String key)` | Removes the entry keyed by `key` from cache `cacheName`; forwards from a worker isolate; always returns `0`. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `cacheName` | `String` | The name this cache is registered under in `TomCacheManager` (final). |
| `deletionIntervalSeconds` | `int?` | How often (seconds) the deletion timer sweeps expired entries; `null` disables it (default 3600, final). |
| `deleteEntriesAfterSeconds` | `int?` | Default lifetime (seconds) applied when no explicit deletion time is given; `null` means no age expiry (final). |
| `clearIntervalSeconds` | `int?` | How often (seconds) the clearance timer empties the whole cache; `null` disables it (final). |
| `maximumEntries` | `int?` | Upper bound on entries; `null` makes the cache unbounded, a positive value turns on LRU eviction (final). |
| `deletionTimer` | `Timer?` | The periodic timer that sweeps expired entries, or `null` when none is running — the interval is unset, or `stopTimers` has since cleared it. |
| `clearanceTimer` | `Timer?` | The periodic timer that clears the whole cache, or `null` when none is running — the interval is unset, or `stopTimers` has since cleared it. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `removeEntry` | `void removeEntry(String key)` | Removes the entry stored under `key`, unlinking it from the MRU list if the cache is bounded; a no-op when the key is absent. The module's only chain-unlink routine — the deletion sweep and both of `putEntry`'s removals (replacing a key, evicting the least-recently-used entry) go through it. |
| `getEntry` | `TomCacheEntry? getEntry(String key)` | Returns the entry under `key`, or `null` if absent; in a bounded cache the entry is promoted to most-recently-used. Does not check expiry. |
| `putEntry` | `void putEntry(String key, TomCacheEntry entry)` | Stores `entry` under `key` at the most-recently-used position; in a bounded cache, exceeding `maximumEntries` evicts the least-recently-used entry. Storing under a key the cache already holds replaces the entry — the previous one is unlinked through `removeEntry` first, so it leaves the MRU chain rather than staying in it unreachable and later being evicted in the replacement's place. |
| `createTimers` | `void createTimers()` | Cancels any running timers and installs the deletion and/or clearance timers for which an interval is configured. |
| `stopTimers` | `void stopTimers()` | Cancels the deletion and clearance timers if they are running and clears both fields; the intervals are untouched, so `createTimers` restarts the cache. |
| `createDeletionTimer` | `Timer createDeletionTimer()` | Builds the periodic timer that removes entries past their `deletionTime`. |
| `createClearanceTimer` | `Timer createClearanceTimer()` | Builds the periodic timer that empties the entire cache. |

### TomCacheStoreMessage

Cross-isolate command that stores `value` under `key` in cache `cacheName`,
dispatched to the main isolate when a worker stores into a cache it does not
hold.

- **Extends:** `TomCommand`

#### Constructors

```dart
TomCacheStoreMessage(String cacheName, String key, Object? value, DateTime? deletionTime)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `cacheName` | `String` | Name of the target cache. |
| `key` | `String` | Entry key. |
| `value` | `Object?` | Value to store. |
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
