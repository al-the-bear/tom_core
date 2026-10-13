# Cache Module

A lightweight in-memory cache for the server. Caches are registered by name in a
`TomCacheManager`, physically held in the main isolate, and reached from any
isolate through a small set of static helpers. A cache is LRU-bounded by default
and unbounded on request, and can expire entries by age or clear itself on a
schedule. On a cluster, `TomCacheInvalidator` carries an invalidation — of an
entry, of a whole cache, or of a user's tokens in the authorization cache — to
every node through an installed channel.

## Table of Contents

- [Overview](#overview)
- [Walkthrough](#walkthrough)
  - [1. Registering a cache and using it](#1-registering-a-cache-and-using-it)
  - [2. An expired entry reads as a miss](#2-an-expired-entry-reads-as-a-miss)
  - [3. Caching forever](#3-caching-forever)
  - [4. LRU eviction in a bounded cache](#4-lru-eviction-in-a-bounded-cache)
  - [5. A cache named after the type it holds](#5-a-cache-named-after-the-type-it-holds)
  - [6. Reading a value as the wrong type](#6-reading-a-value-as-the-wrong-type)
  - [7. A `null` is not a storable value](#7-a-null-is-not-a-storable-value)
  - [8. Storing an entry with its own lifetime](#8-storing-an-entry-with-its-own-lifetime)
  - [9. Stopping the timers](#9-stopping-the-timers)
  - [10. Installing a manager](#10-installing-a-manager)
- [Registering a Cache](#registering-a-cache)
  - [Leaving the registry](#leaving-the-registry)
- [Reading, Storing, Removing](#reading-storing-removing)
- [Expiry and Bounds](#expiry-and-bounds)
  - [A cache is bounded unless you say otherwise](#a-cache-is-bounded-unless-you-say-otherwise)
  - [Two reads, and only one of them expires](#two-reads-and-only-one-of-them-expires)
- [Isolate Model](#isolate-model)
  - [One crossing per operation](#one-crossing-per-operation)
- [Failures Are Internal](#failures-are-internal)
- [Tenant-Scoped Entries](#tenant-scoped-entries)
- [Cross-Node Invalidation](#cross-node-invalidation)
  - [Channels and their staleness bound](#channels-and-their-staleness-bound)
  - [Installing a channel at start-up](#installing-a-channel-at-start-up)
  - [What each kind does](#what-each-kind-does)
  - [The SQL channel](#the-sql-channel)
  - [Failures](#failures)
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
| `TomCacheInvalidator` | abstract final class | Cluster-wide entry point: revoke a principal, invalidate an entry or a cache on every node |
| `TomCacheInvalidation` | class | One invalidation as it travels between nodes |
| `TomInvalidationKind` | enum | `principal`, `cacheEntry`, `cache` |
| `TomInvalidationChannel` | abstract interface class | How invalidations reach the other nodes, and how fast (`stalenessBound`) |
| `TomLocalInvalidationChannel` | class | The default channel for a single process; bound zero |
| `TomSqlInvalidationChannel` | class | A channel over a table every node polls; bound is the poll interval |
| `TomCacheInvalidateMessage` | class | Cross-isolate invalidation, run in the main isolate |
| `TomCacheInvalidationRow` | class | One row of the invalidation log, as the SQL channel reads it |
| `invalidationTable` / `invalidationTableDdl` / `defaultInvalidationTable` | functions / const String | The invalidation log, declared once as a framework-owned table |

## Walkthrough

The ten subsections below are the ten numbered steps of
`example/cache/cache_example.dart`, one for one and in order. The snippets are
that file with its `print` and `check` lines taken out, so each is code the
suite has run rather than code that merely reads well — the example checks every
result and `test/cache_test.dart` requires it to exit 0, which is what keeps
these honest once nobody runs it by hand.

The pairing is not a convention someone has to remember: the same suite counts
the example's numbered steps and the subsections here and fails when the two
disagree, so a step added on one side and not the other turns a test red. The
sections after this one are the reference — they say *why* each rule is what it
is, and are linked from the steps that demonstrate them.

### 1. Registering a cache and using it

```dart
TomCacheManager.addCache(
  TomCache('greetings', deleteEntriesAfterSeconds: 300),
);

await TomCache.toNameCache('greetings', 'en', 'hello');
final greeting = await TomCache.fromNameCache<String>('greetings', 'en');

greeting;   // hello
```

`deleteEntriesAfterSeconds: 300` gives every entry stored without an explicit
deletion time a five-minute lifetime.

### 2. An expired entry reads as a miss

```dart
await TomCache.toNameCache(
  'greetings',
  'old',
  'stale',
  DateTime.now().subtract(const Duration(seconds: 1)),
);

final expired = await TomCache.fromNameCache<String>('greetings', 'old');

expired;   // null
```

The read drops the stale entry as it returns, so the space is reclaimed on
access rather than waiting for the deletion timer.

### 3. Caching forever

```dart
TomCacheManager.addCache(TomCache('forever'));

await TomCache.toNameCache('forever', 'pi', '3.14159');
final kept = await TomCache.fromNameCache<String>('forever', 'pi');

kept;   // 3.14159
```

With no `deleteEntriesAfterSeconds` and no explicit deletion time the entry
carries no expiry instant at all. This is the other half of step 2's rule: an
entry expires only if it *has* a deletion time that has passed, so one with none
never expires on its own.

### 4. LRU eviction in a bounded cache

```dart
TomCacheManager.addCache(
  TomCache('lru', maximumEntries: 2, deleteEntriesAfterSeconds: 300),
);

await TomCache.toNameCache('lru', 'a', 1);
await TomCache.toNameCache('lru', 'b', 2);
await TomCache.toNameCache('lru', 'c', 3);   // evicts 'a', the least recent

await TomCache.fromNameCache<int>('lru', 'a');   // null
await TomCache.fromNameCache<int>('lru', 'c');   // 3
```

A read counts as a touch: reading `a` before storing `c` would have made `b` the
eviction candidate instead. See [Expiry and Bounds](#expiry-and-bounds).

### 5. A cache named after the type it holds

```dart
class User {
  final String id;
  User(this.id);
}

TomCacheManager.addCache(
  TomCache.forType(User, deleteEntriesAfterSeconds: 300),
);

await TomCache.toTypeCache<User>('u-42', User('42'));
final user = await TomCache.fromTypeCache<User>('u-42');

user?.id;   // 42

await TomCache.removeFromTypeCache<User>('u-42');
await TomCache.fromTypeCache<User>('u-42');   // null
```

`TomCache.forType(User, …)` names the cache `User.toString()`, which is exactly
the name `toTypeCache<User>` and `fromTypeCache<User>` compute — so the two sides
agree without a shared constant.

### 6. Reading a value as the wrong type

```dart
await TomCache.toNameCache('greetings', 'num', 123);

try {
  await TomCache.fromNameCache<String>('greetings', 'num');
} on TomCacheException catch (e) {
  e.key;   // error.cache_retrieve.types_dont_match
}
```

The cache stores `Object`, so nothing prevents a heterogeneous cache; the type
parameter is checked at the point of reading. The exception carries the cast's
`TypeError` as `e.rootException` and the cast site's trace as `e.stack`, so the
mismatch can be diagnosed from the log without reproducing it — see
[Failures Are Internal](#failures-are-internal).

### 7. A `null` is not a storable value

```dart
// Does not compile: `toNameCache` takes a non-nullable `Object`.
// await TomCache.toNameCache('greetings', 'nothing', null);

final dynamic store = TomCache.toNameCache;
var refused = false;
try {
  await store('greetings', 'nothing', null);
} on TypeError {
  refused = true;
}

refused;   // true

await TomCache.fromNameCache<String>('greetings', 'nothing');   // null
```

Both entrances refuse one, so the key simply stays absent: the analyzer stops an
ordinary call site before the program runs, and the dynamic call above — how a
script or a reflective caller reaches the same helper — is refused with a
`TypeError` at the call. The reason is step 2's rule, spelled out under
[Reading, Storing, Removing](#reading-storing-removing).

### 8. Storing an entry with its own lifetime

```dart
await TomCache.toNameCache(
  'greetings',
  'flash',
  TomCacheEntry(
    'short-lived',
    DateTime.now().subtract(const Duration(seconds: 1)),
  ),
);

final flash = await TomCache.fromNameCache<String>('greetings', 'flash');

flash;   // null
```

Passing a `TomCacheEntry` as the value stores it directly and keeps its own
`deletionTime`, overriding the cache's default lifetime for that one entry. The
past instant is what makes that observable rather than merely stated: `greetings`
carries a 300-second default that would have kept this entry readable, so the
miss can only come from the entry's own instant having been the one used.

### 9. Stopping the timers

```dart
final ticking = TomCache('ticking', clearIntervalSeconds: 60);
TomCacheManager.addCache(ticking);

ticking.clearanceTimer?.isActive;   // true

ticking.stopTimers();

ticking.clearanceTimer;   // null
```

A cache installs its periodic timers on construction, and a running timer keeps
the isolate alive. A program that finishes while a cache exists must either stop
the timers or exit explicitly — the example does the latter, with `exit(0)`.

`stopTimers` cancels each timer **and clears the field**, so `clearanceTimer ==
null` is a straight answer to "is this cache still ticking?" rather than one that
holds only until the first stop.

### 10. Installing a manager

```dart
TomCacheManager.getCache('greetings');   // the cache registered in step 1

TomCacheManager.setCurrent(TomCacheManager(true));

TomCacheManager.getCache('greetings');   // null
```

Replacing the current manager discards the registered caches with it, which is
what makes it useful between tests. The positional flag says caches are served
from this isolate; in the main isolate it is forced to `true` regardless.

What it discards is the **registry**, not the caches' timers — and that is
deliberate, because the swap cannot know whether it is final. The *outgoing*
manager is what comes back, which is the handle for releasing it when it is:

```dart
TomCacheManager.setCurrent(TomCacheManager(true)).dispose();
```

See [Leaving the registry](#leaving-the-registry).

## Registering a Cache

Create a cache and register it once at startup — `TomCacheManager.addCache` is
the entrance, and `removeCache` the way out (see [Leaving the
registry](#leaving-the-registry)). A cache is named either by a string
or, through `TomCache.forType`, after the Dart type it holds, which is what pairs
it with the `…TypeCache` helpers. The constructor's four knobs are independent
and all optional: [step 1](#1-registering-a-cache-and-using-it) registers a named
cache with a default lifetime, [step 4](#4-lru-eviction-in-a-bounded-cache) adds
an LRU bound, and [step 5](#5-a-cache-named-after-the-type-it-holds) registers a
type cache. Combining them is just passing more than one:

```dart
TomCacheManager.addCache(
  TomCache.forType(
    User,
    maximumEntries: 1000,           // LRU-bounded
    deleteEntriesAfterSeconds: 300, // entries expire 5 min after they are stored
  ),
);
```

### Leaving the registry

A cache installs its periodic timers in its constructor, so leaving the registry
is not on its own enough to stop one: a cache nothing can look up goes on
sweeping and clearing its map, and a pending timer keeps the isolate alive.
Unregistering and stopping are therefore one operation.

| Call | Does |
| ---- | ---- |
| `TomCacheManager.removeCache(name)` | unregisters that cache, stops its timers, and returns it — `null` if no such cache was registered |
| `manager.dispose()` | the same for every cache the manager holds, and empties the registry |
| `TomCacheManager.setCurrent(other)` | swaps the registry and **stops nothing**, returning the displaced manager |

`setCurrent` stays a pure swap because it cannot know whether the swap is final.
A caller that swaps a manager out in order to swap it back would get its caches
returned dead, and a `setCurrent` that restarted them on the way back would be
doing two things and guessing which was wanted. So it hands back the outgoing
manager instead, and `dispose()` is how a caller says "finished with this one".

Neither call destroys anything. `stopTimers` is reversible by contract, so a
removed cache keeps its entries and `createTimers()` starts it again — which is
what a caller re-registering it later, or reading the map one last time, needs.
`dispose` is idempotent, so a shutdown path that reaches it twice is not a fault.

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
is removed in passing), and on nothing else. It throws `TomCacheException` if
the stored value is not a `T`. Both answers hold whichever isolate the read runs
in — see [Isolate Model](#isolate-model).

**A `null` is not a storable value.** The store helpers take a non-nullable
`Object`, and `TomCacheEntry.value` is non-nullable too, so both entrances to
the cache refuse one — the analyzer stops an ordinary call site, and a dynamic
or reflective caller gets a `TypeError` at the call. The reason is the paragraph
above: `null` is already the answer for a miss and for an expiry, so an entry
holding one would be a value no read could ever surface, while it went on
occupying a slot and counting against a bounded cache's `maximumEntries`. It is
the per-entry form of the black hole the constructor refuses under
[Expiry and Bounds](#expiry-and-bounds) — a store that reports success while
every read misses. A caller holding a nullable value decides what absence means
to it: skip the store, or store a sentinel of its own that a read can hand back.

The four mutators — `toNameCache`, `toTypeCache`, `removeFromNameCache` and
`removeFromTypeCache` — return `Future<bool>`, and each answers the one question
the write already knows the answer to:

| Call | `true` means |
| ---- | ------------ |
| `toNameCache` / `toTypeCache` | the key was **already held** — this was a replacement, not an insert |
| `removeFromNameCache` / `removeFromTypeCache` | there **was** an entry, and it is gone |

Both facts are free at the write site and were previously discarded, so a caller
that needed either had to read first: a second operation, and from a worker
isolate a second round trip for a fact the first crossing already had in hand. A
forwarded mutation carries its answer back, so it reports what a local one
reports.

The store's answer is about *this key*, not about the cache: an insert that
pushes a bounded cache past `maximumEntries` evicts a different key and still
answers `false`. And a removal that answers `false` is still not an error —
removing a key the cache does not hold never was — it is merely distinguishable
now.

A value that *is already* a `TomCacheEntry` is stored verbatim, so it keeps its
own `deletionTime` and the cache's `deleteEntriesAfterSeconds` does not apply to
it. This is how a single entry opts out of the cache-wide default — see
[step 8](#8-storing-an-entry-with-its-own-lifetime).

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
  *deletion timer* every `deletionIntervalSeconds` (default one hour). The
  sweep only ever reclaims entries that carry a `deletionTime` in the first
  place. `getEntry` deliberately does not apply the rule — see [Two reads, and
  only one of them
  expires](#two-reads-and-only-one-of-them-expires).
- **LRU bound** — the entries form a most-recently-used list; reading or writing
  an entry moves it to the front, and exceeding `maximumEntries` evicts the
  least-recently-used one. **On by default**, at
  `TomCache.defaultMaximumEntries` (100) — see [A cache is bounded unless you
  say otherwise](#a-cache-is-bounded-unless-you-say-otherwise).
- **Periodic clear** — when `clearIntervalSeconds` is set a *clearance timer*
  empties the whole cache on that interval.

Expiry and the periodic clear are off by default; the bound is on.
`TomCache('x')` with no further arguments holds a hundred entries, keeps them
forever, and runs an hourly sweep that finds nothing to sweep.

### A cache is bounded unless you say otherwise

`maximumEntries` defaults to `TomCache.defaultMaximumEntries` — a hundred — and
`maximumEntries: null` is how a caller asks for no bound at all.

A bound is the default because an unbounded cache with no lifetime grows for the
life of the process. Whether that is a leak depends entirely on the shape of the
key:

| Key | Unbounded is |
| --- | ------------ |
| a route, a template name, a configuration section | **fine** — the key space is bounded by its own shape, and the cache stops growing on its own |
| a user id, a request parameter, a tenant | **a leak** — the key space is as large as the traffic, and nothing in the process will correct it |

Nothing in the API distinguishes them, so the default has to be the answer that
is merely *wrong* in the first case rather than *unbounded* in the second. A
cache holding a hundred routing entries instead of a hundred and twenty misses a
little more often; a cache holding every user id a long-running server ever saw
is a defect.

The number matters less than the fact that there is one. A hundred is large
enough that a small fixed key space fits — most such caches hold a handful — and
small enough that a hundred of anything is cheap to hold. A deployment that
knows its key space says so:

```dart
TomCache('sessions', maximumEntries: 10000);  // a bound of your own
TomCache('routes', maximumEntries: null);     // bounded by its own key space
```

`null` means exactly what it always meant, and zero is still refused: `null` is
how a feature is switched off, so zero is never a second way of saying that —
see the constructor.

### Two reads, and only one of them expires

`fromNameCache` applies the expiry rule and `getEntry` does not. That asymmetry
is a decision rather than an omission, and it is the reason both exist.

| Read | Level | On an expired entry |
| ---- | ----- | ------------------- |
| `TomCache.fromNameCache<T>(cache, key)` | the **value** | drops it and answers `null` |
| `cache.getEntry(key)` | the **structure** | hands it back, `deletionTime` and all |

`getEntry` answers what the map holds and where the MRU chain puts it. Expiry is
a policy *about a value*, and applying it at the structural level would collapse
two different answers into one `null`: "there is no such key" and "there is a
key whose value has died" — which is precisely the distinction a structural read
exists to keep. It would also make a read a mutation, since honouring the rule
means dropping the entry, and `getEntry` is the accessor `putEntry` and the
deletion sweep are peers of.

So the rule lives once, in the value-level read, and the entry the accessor
hands back carries its own verdict: a caller holding a `TomCacheEntry` has its
`deletionTime` and can decide for itself.

**Which to use.** Read values through `fromNameCache` / `toNameCache` — that is
what they are for, and they also forward correctly from a worker isolate.
`getEntry` and `putEntry` are public for the case the static helpers do not
cover: storing an entry with a lifetime of its own, and inspecting what is
actually held. A caller that reaches for them is asking about the structure, and
gets a structural answer.

**All four configuration numbers must be positive or `null`.** `null` is how
each is switched off, so zero is never a second way of saying that — it is a
caller whose arithmetic produced a number the cache cannot honour, and the
constructor refuses it with an `ArgumentError` naming the parameter. What the
number would otherwise do differs by parameter, and none of it is visible from
outside: a non-positive `maximumEntries` or `deleteEntriesAfterSeconds` makes
the cache a black hole that accepts every store and misses every read — for want
of room in the first case, because the entry is stored already expired in the
second — while a non-positive `deletionIntervalSeconds` or
`clearIntervalSeconds` makes that sweep a busy loop. `Timer.periodic` reads a
zero period as *as fast as the event loop will run it* rather than as *never*,
and treats a negative period the same way; measured, a zero-period timer ticks
tens of thousands of times per 50 ms, burning a core on a sweep that reports
nothing.

That last one costs more than the wasted sweep: **a live timer keeps the isolate
alive**. The deletion sweep is installed by the constructor and is on by
default, so a program that builds a cache no longer exits once its work is
done. A server never notices, since it is meant to stay up. A script, a sample
or a one-shot job has to call `stopTimers()` on the caches it created — or exit
explicitly — to return at all. The module readme's quick start ends that way,
and a test runs it to keep the promise honest — see
[Verification](#verification).

Both timers run in **`Zone.root`**, wherever the cache was constructed. That
matters because a cache is a process-lifetime object — `TomCacheManager` holds it
for the life of the isolate — while nothing constrains where it is built, and
`TomCache.forType` is reached lazily from endpoint code. The endpoint pipeline
runs each request in its own zone to carry the principal, so timers created with
`Zone.current` would leave process-lifetime work answering to one request's error
handling and teardown, with the zone decided by whichever caller happened to
arrive first. Root rather than a zone the server installs at boot, because
neither sweep wants anything a zone can give it: both walk a plain map, need no
principal and no transaction, and a failure in either belongs to the process
rather than to any request. Constructing a cache at start-up is therefore not a
way of getting the zone right — it was already right.

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
share the same forward-or-throw rule, each with its own key:

| Helper | Key when no cache of that name is reachable |
| --- | --- |
| `from…` (read) | `error.cache_retrieve.not_found` |
| `to…` (store) | `error.cache_store.not_found` |
| `removeFrom…` (remove) | `error.cache_remove.cache_not_found` |

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
back as though it were the cached value. The sentinel translation is exact
because a creator-side `null` has only the one meaning: a cached value is never
`null`, so nothing but a miss can arrive that way.

### One crossing per operation

Each helper forwards its own operation. Ten cached lookups from a worker are ten
round trips through the back channel, each an `await` on a completer the main
isolate has to schedule, and asking twice for the same key costs twice. There is
no batch command and no worker-side copy.

That stands, and the reasons are worth stating because the alternatives are
obvious ones:

- **A batch command** — a fourth `TomCommand` carrying a list of keys and
  returning a map — only helps a call site that knows its keys up front. A
  handler resolving a user, then their tenant from the user, then a policy from
  the tenant cannot name the second key until the first has answered, and that
  is the shape most cached lookups have.
- **A worker-side read-through copy** is the only option that would help an
  unmodified call site, and it is the one that costs the module its central
  simplification: today there is exactly **one** copy of a cached value, in the
  main isolate, so every reader sees the same value and an invalidation is a
  single `removeFromNameCache`. A second copy brings a coherence problem the
  module does not have.

**The size of the cost is unmeasured**, and saying so is part of the position
rather than an omission from it: this is a decision not to pay for a fix whose
cost nobody has established, not a claim that the crossing is cheap. A
deployment that finds it matters has two remedies, and neither needs the
framework to change:

- **Resolve once per request.** The crossing is per *operation*, so a handler
  that reads a key once and holds the value for the rest of the request pays for
  one. Re-reading the same key inside one request is the case the round trip
  punishes hardest and the easiest to avoid.
- **Register the cache in the worker too.** `fromNameCache` looks the local
  registry up *before* it considers forwarding, so a cache registered in a
  worker is served there with no crossing at all. That is the read-through copy,
  made explicit: the deployment takes on the second copy and the coherence
  question, for data where it knows the answer — immutable reference data,
  compiled templates, resolved configuration. `tom_uam`'s server start shows the
  shape, registering its caches in `initializeAnyIsolate` rather than in the
  main isolate alone.

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

## Tenant-Scoped Entries

In a multi-tenant deployment (see [tenancy.md](tenancy.md)) two tenants caching
one key hold two entries. Every entry point of the static API — `fromNameCache`,
`toNameCache`, `removeFromNameCache` and the type-cache variants built on them —
qualifies the key by the tenant in context with
`TomTenantContext.qualify(key, TomTenantContext.currentId)`, which is
`tenant:<id>/<key>`, or the key unchanged with no tenant:

```dart
await TomTenantContext.run('acme', () => TomCache.toNameCache('plans', 'plan', 'gold'));

final globex = await TomTenantContext.run(
  'globex',
  () => TomCache.fromNameCache<String>('plans', 'plan'),
); // null — globex's 'plan' is another entry
```

A tenant therefore reads, replaces and removes only its own entries, without a
tenant argument on any call. A value meant for every tenant is cached outside
any tenant's context, under the bare key. The instance methods — `getEntry`,
`putEntry`, `removeEntry` — take the key as given: they are the structural layer
under the static API, and the key they receive is already qualified.

The cluster-wide calls follow the same rule.
`TomCacheInvalidator.invalidateCacheEntry(cacheName, key)` invalidates the
current tenant's entry, qualified exactly as `TomCache` keyed it, and
`revokePrincipal(username)` revokes the current tenant's account of that name
only — another tenant's `alice` is a different person (see
[authorization.md](authorization.md#revocation-per-tenant)).
`invalidateCache(cacheName)` empties the whole cache, every tenant's entries
together.

## Cross-Node Invalidation

Every cache in this module lives in one process, and so does the
`TomAuthorizationCache`. On one node, removing an entry or revoking a principal
there is the whole job. On a cluster it is not: the other nodes keep serving
what they hold, and for the authorization cache that is a security problem — a
withdrawn grant would stay usable on every node but the one that withdrew it.

`TomCacheInvalidator` is the cluster-wide entry point. Each call applies the
invalidation on this node first and then publishes it through the installed
`TomInvalidationChannel`, which delivers it to the other nodes, where the
invalidator applies it in turn:

| Call | On every node |
| ---- | ------------- |
| `TomCacheInvalidator.revokePrincipal(username)` | refuses every token `username` holds that was issued now or earlier, and drops the principals cached for them |
| `TomCacheInvalidator.invalidateCacheEntry(cacheName, key)` | removes `key` from the cache named `cacheName` |
| `TomCacheInvalidator.invalidateCache(cacheName)` | empties the cache named `cacheName` |

**A grant change calls `revokePrincipal`** — a role removed, a resource grant
withdrawn, an account disabled. The user's tokens then stop yielding a principal
on every node within the channel's staleness bound, and the client
re-authorizes and receives a token carrying the current grants. What a revoked
token does on arrival is described in the authorization guide, under
"Revoking a principal".

The calls work from any isolate: a worker forwards the invalidation to the main
isolate as a `TomCacheInvalidateMessage`, because the caches and the channel
live there. `TomCacheInvalidator.raise(invalidation)` takes a prepared
`TomCacheInvalidation`, and `apply(invalidation)` applies one to this process
only — it is the callback a channel delivers to.

### Channels and their staleness bound

A channel states how stale another node can be, as
`TomInvalidationChannel.stalenessBound`: the longest time from `publish` on one
node to delivery on another.

| Channel | Reaches | `stalenessBound` |
| ------- | ------- | ---------------- |
| `TomLocalInvalidationChannel` — the default | no other node | zero: on one node an invalidation applied here is applied everywhere there is |
| `TomSqlInvalidationChannel` | every node polling the same table | the poll interval (default two seconds), plus one query |

A deployment of one process needs nothing. A deployment of several installs the
SQL channel on every node, over a data source they all share.

A channel never delivers a node's own invalidations back to it: each carries
its `origin`, the `TomCacheInvalidator.nodeId` of the process that raised it,
which is random per process.

### Installing a channel at start-up

`TomCacheInvalidator.install(channel)` stops the channel it replaces and starts
the new one with `apply` as its delivery callback. Call it once at start-up,
after the data sources are registered and **before the server answers
requests**: a channel that keeps history delivers the revocations still in
force from `start`, so a node that joins the cluster, or restarts, does not
serve a token another node revoked before it was there.

```dart
// After the data sources are initialised, before the server starts serving.
await TomCacheInvalidator.install(TomSqlInvalidationChannel.named('main'));

// Wherever a user's grants change:
await TomCacheInvalidator.revokePrincipal('alice');
```

`TomSqlInvalidationChannel.named(datasourceName)` looks the data source up in
the registry; `TomSqlInvalidationChannel(datasource)` takes one directly. Both
accept `table`, `pollInterval`, `retention` and `createSchema`.
`TomCacheInvalidator.channel` answers which channel is installed, and
`TomCacheInvalidator.reset()` puts the local channel back — test support.

### What each kind does

An invalidation is a `TomCacheInvalidation`: a `TomInvalidationKind`, a
`target`, an optional entry `key`, the UTC instant `at` it was raised and its
`origin`. `apply` maps each kind onto this process's caches:

| `TomInvalidationKind` | `target` | Applied as |
| --------------------- | -------- | ---------- |
| `principal` | the username, qualified by tenant (`tenant:<id>/<name>`) when raised in a tenant | `TomAuthorizationCache.revokeLocally(target, at)` — tokens issued at or before `at` are refused, and the user's cached principals are dropped |
| `cacheEntry` | the cache name | `removeEntry(key)` on the cache registered under that name; `key` is already qualified by tenant when raised in one |
| `cache` | the cache name | `clear()` on the cache registered under that name |

A cache name nothing registered on this node is nothing to invalidate, and is
skipped. `TomCache.clear()` is the same reset the clearance timer performs: the
map and the most-recently-used chain together.

### The SQL channel

`TomSqlInvalidationChannel` needs no infrastructure a deployment does not
already have. `publish` inserts one row into the invalidation log; every node
polls the log every `pollInterval` for the rows above the highest id it has
seen and applies the ones other nodes wrote.

The log is a framework-owned table, `tom_cache_invalidation` by default,
declared once by `invalidationTable(table)` and listed by
`frameworkOwnedTables`:

| Column | Type | Carries |
| ------ | ---- | ------- |
| `id` | `BIGINT` auto-increment, primary key | the order every node reads by — an instant could not, since two nodes' clocks disagree |
| `kind` | `VARCHAR(16)` | the `TomInvalidationKind` name |
| `target` | `VARCHAR(191)` | the username or cache name |
| `entry_key` | `VARCHAR(512)`, nullable | the key of a single-entry invalidation |
| `origin` | `VARCHAR(32)` | the node that wrote the row |
| `raised_at` | `DATETIME(6)`, indexed, UTC | the retention sweep and the start-up catch-up |

With `createSchema` left `true` the channel creates the table on first use.
Where the application's database user may not run DDL, apply the reference
migration `example/cache/migrations/main/tomcore/[1]-create_tom_cache_invalidation.sql`
and pass `createSchema: false`; for a renamed table, apply what
`invalidationTableDdl(name)` returns.

What the channel does, in order:

- **`start`** creates the table if asked, takes the log's highest id as its
  watermark, delivers every `principal` row raised within `retention` and at or
  below the watermark — the revocations still in force — and then starts a
  periodic poll timer in `Zone.root`, so the flow that installed the channel
  does not own process-lifetime work.
- **`poll`** reads up to a thousand rows above the last id seen, delivers each
  one whose `origin` is not this node, and advances. A poll still running when
  the next is due is not overlapped. At most once per `retention` / 24 it also
  deletes the rows older than `retention`. `poll` runs on the timer and is
  callable directly.
- **`publish`** inserts the row.
- **`stop`** cancels the timer; `isRunning` answers whether it is polling.

`retention` defaults to `TomAuthorizationCache.revocationRetention`, one day: a
revocation has to be remembered as long as a token issued before it can still
be live, so a node starting up must see every revocation that young.

### Failures

**A publish failure propagates.** The invalidation has already been applied on
this node — that happens first, so the node raising it is consistent whatever
the database does — and then the exception reaches the caller of
`revokePrincipal`, who learns that the other nodes did not hear of it.

**A poll failure is logged and retried.** The failure is logged at warning
level and the next poll reads again from the same row, so no invalidation is
skipped by a transient database error; the cost is staleness for as long as
the database is unreachable.

| Key | Raised when |
| --- | ----------- |
| `cache.invalidation.unknown_datasource` | `TomSqlInvalidationChannel.named` names a data source that is not registered. A `TomCacheException` (`clientThrow: false`), carrying the name as `datasource` — a configuration error, best caught at start-up. |

## Core Components

- **`TomCache`** — the cache and its static accessor helpers. Instance methods
  `getEntry` / `putEntry` / `removeEntry` implement the MRU bookkeeping and are
  *structural* — see [Two reads, and only one of them
  expires](#two-reads-and-only-one-of-them-expires); `clear` empties the map
  and the chain together; `createTimers` / `stopTimers` manage the background
  timers.
- **`TomCacheEntry`** — value object: the cached `value`, which is non-nullable,
  and its `deletionTime`.
- **`TomCacheManager`** — the per-isolate registry and the `useInThisIsolate`
  switch.
- **`TomCacheException`** — raised on a missing cache or a type mismatch;
  `clientThrow: false` by default, since neither is the caller's business.
- **`TomCacheStoreMessage` / `TomCacheRemoveMessage` / `TomCacheRetrieveMessage`**
  — the cross-isolate commands.
- **`TomCacheInvalidator`** — the cluster-wide entry point: `install`,
  `revokePrincipal`, `invalidateCacheEntry`, `invalidateCache`, `raise`,
  `apply`, `reset`, `channel` and `nodeId`.
- **`TomCacheInvalidation` + `TomInvalidationKind`** — one invalidation and what
  it invalidates; `TomCacheInvalidateMessage` carries one from a worker.
- **`TomInvalidationChannel`** — the transport seam, with
  `TomLocalInvalidationChannel` (the default) and `TomSqlInvalidationChannel`
  (the polled log, read through `TomCacheInvalidationRow`).
- **`invalidationTable` / `invalidationTableDdl` / `defaultInvalidationTable`**
  — the log's single declaration.

## Not Yet Implemented

The module's two standing decisions — what `getEntry` answers, and the cost of
a crossing — are stated where the behaviour is, under [Expiry and
Bounds](#expiry-and-bounds) and [Isolate Model](#isolate-model) respectively.

- **No channel over a message bus.** Invalidations travel between nodes by
  polling a table, so a cluster is as stale as its poll interval. A channel that
  delivers them as messages, for near-immediate eviction, is not offered.
  <!-- unpinned: absence — no message-bus channel exists -->

## Verification

`example/cache/cache_example.dart` walks the module in ten steps, in the main
isolate and with no setup of any kind — store and read, expiry, the entry that
never expires, LRU eviction, the type cache, the mismatch, the refusal of a
`null`, an entry carrying its own lifetime, stopping the timers, and replacing
the manager. Those ten steps are reproduced above as the
[Walkthrough](#walkthrough). Every step checks
its own result through the shared `example/_support/check.dart` and the run
fails when one does not hold, so a green run is a verification rather than a
transcript — see
[A green run is a verification](../README.md#a-green-example-run-is-a-verification)
for why that helper throws instead of asserting, and what holds the property
for every example at once.

`test/cache_test.dart` covers it end to end in one process — the static helpers
and the raw entry accessors, expiry and bounds, the MRU chain across evictions,
sweeps and clears (including a differential check against a naive LRU of the
same bound under a randomised operation mix), the timer lifecycle, the
`clientThrow` decision at all four raise sites, and the cross-isolate forwarding
against a **real spawned `TomWorker`** rather than a stubbed transport, which is
the only way to establish that an argument survives the crossing. It needs no
external server and carries no tag, so all of it runs in the default
`testkit :test`.

Cross-node invalidation has two suites. `test/cache_invalidation_test.dart`
needs no database: a fake channel plays the other node, recording what this
node publishes and delivering "remote" invalidations through the callback the
invalidator gave it — revocation and its second-granularity comparison, a
publish failure that still revokes here, entry and cache invalidations, channel
replacement and the retention sweep. `test/cache_invalidation_db_test.dart`,
tagged `db`, runs `TomSqlInvalidationChannel` against MariaDB: own-origin rows
skipped, the start-up catch-up of revocations in force, retention pruning, and
a grant revoked on one node refused on a second — a spawned isolate, whose
static caches are its own — within the poll interval.

The two are linked in both directions — the example's header names the suite,
and the suite runs the example, under exactly the command that header documents,
requiring exit 0. The suite also holds the [Walkthrough](#walkthrough) to the
example, counting the numbered steps in one and the subsections in the other and
failing when they disagree, so the pairing the walkthrough claims cannot quietly
stop being true. The module readme's "Quick start" is run too, by
`test/readme_quick_start_test.dart`, which does the same for every module in the
package: it extracts the `dart` block under that heading and runs it under a
watchdog. The regression it guards here is a program that never returns — this
module is the one that makes that easy — and a hang reported as a hang says less
than a hang reported as a named failure.

So each of this module's prose artefacts is falsifiable from the suite: the
example, the walkthrough above, the readme's quick start, and all but one of the
[Not Yet Implemented](#not-yet-implemented) items above, which that section
itself accounts for. None of them can drift quietly while nobody is reading.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `cache_invalidation.dart`, `server_cache.dart`, `sql_invalidation_channel.dart` | `Future`, `Timer`, `Zone` |
| `dart:isolate` | dart | `server_cache.dart` | `Isolate` |
| `dart:math` | dart | `cache_invalidation.dart` | `Random.secure`, for the per-process `nodeId` |
| `tom_core_kernel` | package | `cache_invalidation.dart`, `server_cache.dart`, `sql_invalidation_channel.dart` | `TomWorker`, `TomCommand`, and the logging helpers |
| [authorization](authorization.md) | module | `cache_invalidation.dart`, `sql_invalidation_channel.dart` | `TomAuthorizationCache` — `revokeLocally`, which a principal invalidation applies, and `revocationRetention`, the SQL channel's default retention |
| [datasources](datasources.md) | module | `invalidation_sql.dart`, `sql_invalidation_channel.dart` | `TomFrameworkTable` (the log's declaration), `TomDataSource` and `TomDataSourceInfo` (named data sources), `parseSqlInstant` |
| [little_things](little_things.md) | module | `server_cache.dart` | `TomServerException`, the base of `TomCacheException` |
| [object_persistence](object_persistence.md) | module | `sql_invalidation_channel.dart` | `TomDbTable` / `TomDbColumn` on `TomCacheInvalidationRow` |
