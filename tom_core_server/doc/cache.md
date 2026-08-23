# Cache Module

A lightweight in-memory cache for the server. Caches are registered by name in a
[`TomCacheManager`], physically held in the main isolate, and reached from any
isolate through a small set of static helpers. A cache can be unbounded or LRU
bounded, and can expire entries by age or clear itself on a schedule.

## Table of Contents

- [Overview](#overview)
- [Registering a Cache](#registering-a-cache)
- [Reading, Storing, Removing](#reading-storing-removing)
- [Expiry and Bounds](#expiry-and-bounds)
- [Isolate Model](#isolate-model)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomCache` | class | A named cache; static helpers read/store/remove by cache name or type |
| `TomCacheEntry` | class | A cached value plus its optional `deletionTime` |
| `TomCacheManager` | class | Registry of named caches; decides local vs. forwarded operation |
| `TomCacheException` | exception | Missing cache, or a cached value whose type does not match |
| `TomCacheStoreMessage` | `TomCommand` | Cross-isolate store, run in the main isolate |
| `TomCacheRemoveMessage` | `TomCommand` | Cross-isolate remove, run in the main isolate |
| `TomCacheRetrieveMessage` | `TomCommand` | Cross-isolate read, run in the main isolate |

## Registering a Cache

Create a cache and register it once at startup. `TomCache.forType` names the
cache after the Dart type it holds, which pairs with the `…TypeCache` helpers:

```dart
TomCacheManager.addCache(
  TomCache.forType(
    User,
    maximumEntries: 1000,           // LRU-bounded
    deleteEntriesAfterSeconds: 300, // entries expire 5 min after they are stored
  ),
);
```

## Reading, Storing, Removing

The static helpers come in a *by-name* and a *by-type* form. The by-type form
simply uses `T.toString()` as the cache name:

```dart
// by name
await TomCache.toNameCache('User', 'u-42', user);
final cached = await TomCache.fromNameCache<User>('User', 'u-42');
await TomCache.removeFromNameCache('User', 'u-42');

// by type (cache named after T)
await TomCache.toTypeCache<User>('u-42', user);
final same = await TomCache.fromTypeCache<User>('u-42');
await TomCache.removeFromTypeCache<User>('u-42');
```

`fromNameCache` returns `null` on a miss or an expired entry (an expired entry is
removed in passing). It throws [`TomCacheException`] if the stored value is not a
`T`.

A value that *is already* a [`TomCacheEntry`] is stored verbatim, so it keeps its
own `deletionTime` and the cache's `deleteEntriesAfterSeconds` does not apply to
it. This is how a single entry opts out of the cache-wide default:

```dart
await TomCache.toNameCache(
  'greetings',
  'flash',
  TomCacheEntry('short-lived', DateTime.now().add(const Duration(seconds: 30))),
);
```

> **Entries without a deletion time are kept forever.** A value stored with
> neither a `deleteEntriesAfterSeconds` default nor an explicit `deletionTime`
> has `deletionTime == null`: it never expires on its own and is returned by
> every read until it is removed or evicted by an LRU bound or a clear. Only an
> entry whose `deletionTime` lies in the past is treated as expired (and dropped
> in passing on read).

## Expiry and Bounds

A cache has two independent eviction mechanisms plus an optional periodic clear:

- **Per-entry expiry** — a stored value expires at an explicit `deletionTime`,
  or after `deleteEntriesAfterSeconds` from when it was stored. Expired entries
  are dropped lazily on read and swept by a *deletion timer* every
  `deletionIntervalSeconds` (default one hour).
- **LRU bound** — when `maximumEntries` is set the entries form a
  most-recently-used list; reading or writing an entry moves it to the front,
  and exceeding the bound evicts the least-recently-used entry.
- **Periodic clear** — when `clearIntervalSeconds` is set a *clearance timer*
  empties the whole cache on that interval.

## Isolate Model

The caches live in the **main isolate**. `TomCacheManager.useInThisIsolate` is
forced to `true` there. When a static helper runs in a worker isolate that does
not hold the named cache, it forwards the operation to the main isolate as a
[`TomCommand`] (`TomCacheStoreMessage` / `TomCacheRemoveMessage` /
`TomCacheRetrieveMessage`) via `TomWorker.executeInCreator`:

```text
worker isolate                         main isolate
──────────────                         ────────────
TomCache.toNameCache(...)  ──forward──► TomCacheStoreMessage.execute()
                                          └─► TomCache.toNameCache(...)  (local)
```

The forward carries every argument, so a store made from a worker lands with
the `deletionTime` the worker asked for and not the target cache's default. That
matters more than it looks: a dropped argument here cannot surface as an error,
because the receiving side would simply apply `deleteEntriesAfterSeconds`
instead and report success — the write looks fine and the entry outlives its
intended lifetime, which is only discovered at some later read.

If neither a local cache nor forwarding is available, the helper throws
[`TomCacheException`]. The three static helpers (`from…`, `to…`, `removeFrom…`)
share the same forward-or-throw rule.

A failure raised on the main isolate comes back as a **throw**, so a forwarded
operation fails the way it would have failed locally: a store into a cache that
exists nowhere raises rather than returning the `0` that means success, and a
read of one raises rather than reporting an empty cache.

Two of a read's answers are not failures, though, and the transport has nothing
to say about either — a value that crossed intact and then failed to convert to
`T`, and a miss, which arrives as `TomExecutor.noResult` because
`executeInCreator` never resolves to `null`. `fromNameCache` settles both at the
call site, so a forwarded read answers exactly as a local one does: the type
mismatch throws, and the miss is `null` rather than a sentinel object handed
back as though it were the cached value.

## Core Components

- **`TomCache`** — the cache and its static accessor helpers. Instance methods
  `getEntry` / `putEntry` / `removeEntry` implement the MRU bookkeeping;
  `createTimers` / `stopTimers` manage the background timers.
- **`TomCacheEntry`** — value object: the cached `value` and its `deletionTime`.
- **`TomCacheManager`** — the per-isolate registry and the `useInThisIsolate`
  switch.
- **`TomCacheException`** — raised on a missing cache or a type mismatch.
- **`TomCacheStoreMessage` / `TomCacheRemoveMessage` / `TomCacheRetrieveMessage`**
  — the cross-isolate commands.

## Dependencies

- `tom_core_kernel` — `TomWorker`, `TomCommand`, and the logging helpers.
- The module's `little_things/server_exception.dart` — `TomServerException`,
  the base of `TomCacheException`.
