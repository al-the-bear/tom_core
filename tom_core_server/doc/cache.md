# Cache Module

A lightweight in-memory cache for the server. Caches are registered by name in a
`TomCacheManager`, physically held in the main isolate, and reached from any
isolate through a small set of static helpers. A cache can be unbounded or LRU
bounded, and can expire entries by age or clear itself on a schedule.

## Table of Contents

- [Overview](#overview)
- [Registering a Cache](#registering-a-cache)
- [Reading, Storing, Removing](#reading-storing-removing)
- [Expiry and Bounds](#expiry-and-bounds)
- [Isolate Model](#isolate-model)
- [Failures Are Internal](#failures-are-internal)
- [Core Components](#core-components)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomCache` | class | A named cache; static helpers read/store/remove by cache name or type |
| `TomCacheEntry` | class | A cached value plus its optional `deletionTime` |
| `TomCacheManager` | class | Registry of named caches; decides local vs. forwarded operation |
| `TomCacheException` | class | Missing cache, or a cached value whose type does not match |
| `TomCacheStoreMessage` | class | Cross-isolate store, run in the main isolate |
| `TomCacheRemoveMessage` | class | Cross-isolate remove, run in the main isolate |
| `TomCacheRetrieveMessage` | class | Cross-isolate read, run in the main isolate |

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

`fromNameCache` returns `null` on a miss or an expired entry (an expired entry
is removed in passing). It throws `TomCacheException` if the stored value is
not a `T`. Both answers hold whichever isolate the read runs in — see
[Isolate Model](#isolate-model).

The three mutators return `Future<int>` and **always answer `0`**. It is a
uniform result shape, not a count: it does not distinguish an insert from a
replacement, or a removal from a no-op. Do not branch on it; see
[Not Yet Implemented](#not-yet-implemented).

A value that *is already* a `TomCacheEntry` is stored verbatim, so it keeps its
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
  are dropped lazily when read *through the static helpers* and swept by a
  *deletion timer* every `deletionIntervalSeconds` (default one hour). The raw
  `getEntry` accessor does not apply the rule, so it can hand back an expired
  entry; the sweep only ever reclaims entries that carry a `deletionTime` in the
  first place.
- **LRU bound** — when `maximumEntries` is set the entries form a
  most-recently-used list; reading or writing an entry moves it to the front,
  and exceeding the bound evicts the least-recently-used entry. The bound must
  be positive: a non-positive value is refused at construction with an
  `ArgumentError`, since a cache permitted to hold nothing would accept every
  store and miss on every read. When `maximumEntries` is **not** set there is no
  bound at all — see [Not Yet Implemented](#not-yet-implemented) before leaving
  a cache unbounded.
- **Periodic clear** — when `clearIntervalSeconds` is set a *clearance timer*
  empties the whole cache on that interval.

None of the three is on by default. `TomCache('x')` with no further arguments is
unbounded, holds its entries forever, and runs an hourly sweep that finds
nothing to sweep.

That last one costs more than the wasted sweep: **a live timer keeps the isolate
alive**. The deletion sweep is installed by the constructor and is on by
default, so a program that builds a cache no longer exits once its work is
done. A server never notices, since it is meant to stay up. A script, a sample
or a one-shot job has to call `stopTimers()` on the caches it created — or exit
explicitly — to return at all. The module readme's quick start ends that way,
and a test runs it to keep the promise honest — see
[Verification](#verification).

## Isolate Model

The caches live in the **main isolate**. `TomCacheManager.useInThisIsolate` is
forced to `true` there. When a static helper runs in a worker isolate that does
not hold the named cache, it forwards the operation to the main isolate as a
`TomCommand` (`TomCacheStoreMessage` / `TomCacheRemoveMessage` /
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
`TomCacheException`. The three static helpers (`from…`, `to…`, `removeFrom…`)
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

## Failures Are Internal

`TomCacheException` defaults to **`clientThrow: false`**, so the endpoints
pipeline treats a cache failure as internal and does not surface its message to
the caller. Both of the module's failures earn that:

- **"No cache with name X found."** names an entry in a server-side registry.
  That is a deployment detail, and the caller never addressed the cache in the
  first place — it asked for a resource, and whether the server answers it from
  a cache is an implementation choice the error has no business disclosing.
- **A type mismatch** says the server stored something other than what it now
  reads back. There is nothing for the caller to do about it.

The type-mismatch message names the **runtime type** of the stored value, not
the value itself. A cache holds whatever a caller put in it — a session token as
readily as a greeting — and the contents never explain why the cast failed,
while the type always does. Rendering the payload into a message that is logged
would be a leak that buys no diagnosis.

Being internal does not mean being undiagnosable. The mismatch is the module's
one failure with an underlying cause, and it keeps it: the cast's `TypeError`
is attached as `rootException` and the cast site's trace as `stack`, both of
which reach the log. The runtime's message names the target type as it was
resolved — generics and nullability included, where the type parameter is only
as specific as the caller wrote it — and reports types only, never the value,
so attaching it does not widen the leak the paragraph above rules out.

The flag is a constructor parameter, so a raise site with a genuinely public
cache can pass `clientThrow: true`. It survives the isolate boundary intact, so
a forwarded failure carries the same `key` **and** the same `clientThrow` as a
local one.

## Core Components

- **`TomCache`** — the cache and its static accessor helpers. Instance methods
  `getEntry` / `putEntry` / `removeEntry` implement the MRU bookkeeping;
  `createTimers` / `stopTimers` manage the background timers.
- **`TomCacheEntry`** — value object: the cached `value` and its `deletionTime`.
- **`TomCacheManager`** — the per-isolate registry and the `useInThisIsolate`
  switch.
- **`TomCacheException`** — raised on a missing cache or a type mismatch;
  `clientThrow: false` by default, since neither is the caller's business.
- **`TomCacheStoreMessage` / `TomCacheRemoveMessage` / `TomCacheRetrieveMessage`**
  — the cross-isolate commands.

## Not Yet Implemented

- **`getEntry` does not enforce expiry.** The expiry rule lives in
  `fromNameCache` alone; the entry accessor is a structural read that looks the
  key up, promotes it in a bounded cache, and hands it back whatever its
  `deletionTime` says. `getEntry` and `putEntry` are public because storing an
  entry with its own lifetime is a documented use, so a caller that reaches past
  the static helpers can read a value the module considers dead. Prefer
  `fromNameCache` unless you specifically want the raw entry.
- **An unbounded cache has no bound at all.** Without `maximumEntries` nothing
  caps the map, and without `deleteEntriesAfterSeconds` the stored entries carry
  no `deletionTime` for the sweep to find — so both eviction mechanisms decline
  and the cache grows for the life of the process. That is the *default*
  configuration: `TomCache('x')` is unbounded, lifetime-free, and swept hourly
  for nothing. It is safe when the key space is itself bounded — routing tables,
  compiled templates, resolved configuration — and a leak when the key is a user
  id or a request parameter. Nothing in the API distinguishes the two, so the
  choice is the caller's to make deliberately.
- **The mutators always answer `0`.** `toNameCache`, `toTypeCache`,
  `removeFromNameCache` and `removeFromTypeCache` return `Future<int>` and the
  `int` is a uniform result shape, not a count: it cannot tell an insert from a
  replacement, or a removal from a no-op. A caller that needs to know reads
  first, which is a second operation and — from a worker isolate — a second
  round trip.
- **Cross-isolate forwarding is one round trip per operation.** Each helper
  issues its own `executeInCreator` call with a single-operation command. There
  is no batch form and no worker-side read-through copy, so a handler resolving
  ten cached keys from a worker pays ten crossings. Nothing measures this today,
  so the size of the cost is unknown.
- **A cache that leaves the registry keeps its timers.**
  `TomCacheManager.setCurrent` swaps the whole registry and nothing stops the
  discarded caches' timers, which carry on sweeping maps no lookup can reach and
  keep the isolate alive. There is also no per-cache deregistration —
  `addCache` has no counterpart — so `setCurrent` is the only way to drop a
  registration, and it is the leaky one. Call `stopTimers()` on a cache you are
  finished with.

All but the fourth are pinned by tests in `test/cache_test.dart` — the second,
third and the timer half of the last in the group "The limits the documentation
records", the first in "getEntry (direct)" — so closing one of them turns a test
red rather than leaving this section quietly wrong. The fourth is a cost rather
than an outcome, and pinning it would mean asserting a shape.

## Verification

`example/cache/cache_example.dart` walks the module in nine steps, in the main
isolate and with no setup of any kind — store and read, expiry, the entry that
never expires, LRU eviction, the type cache, the mismatch, an entry carrying its
own lifetime, stopping the timers, and replacing the manager. Every step checks
its own result and the run fails when one does not hold, so a green run is a
verification rather than a transcript. The checks are a plain `if`/`throw` and
not `assert`, because `dart run` leaves assertions disabled: an `assert` would
compile out under the very command the file documents, and the example would
print a plausible transcript and exit 0 with every expectation violated.

`test/cache_test.dart` covers it end to end in one process — the static helpers
and the raw entry accessors, expiry and bounds, the MRU chain across evictions,
sweeps and clears (including a differential check against a naive LRU of the
same bound under a randomised operation mix), the timer lifecycle, the
`clientThrow` decision at all four raise sites, and the cross-isolate forwarding
against a **real spawned `TomWorker`** rather than a stubbed transport, which is
the only way to establish that an argument survives the crossing. It needs no
external server and carries no tag, so all of it runs in the default
`testkit :test`.

The two are linked in both directions — the example's header names the suite,
and the suite runs the example, under exactly the command that header documents,
requiring exit 0. A second group extracts the `dart` block under the module
readme's "Quick start" heading and runs that too, under a 20-second watchdog:
the regression it guards is a program that never returns, and a hang reported as
a hang says less than a hang reported as a named failure.

So each of this module's prose artefacts is falsifiable from the suite: the
example, the readme's quick start, and all but one of the
[Not Yet Implemented](#not-yet-implemented) items above, which that section
itself accounts for. None of them can drift quietly while nobody is reading.

## Dependencies

- `tom_core_kernel` — `TomWorker`, `TomCommand`, and the logging helpers.
- The module's `little_things/server_exception.dart` — `TomServerException`,
  the base of `TomCacheException`.
