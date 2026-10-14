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
  - [TomCacheInvalidation](#tomcacheinvalidation)
  - [TomInvalidationChannel](#tominvalidationchannel)
  - [TomLocalInvalidationChannel](#tomlocalinvalidationchannel)
  - [TomCacheInvalidator](#tomcacheinvalidator)
  - [TomCacheInvalidateMessage](#tomcacheinvalidatemessage)
  - [TomSqlInvalidationChannel](#tomsqlinvalidationchannel)
  - [TomCacheInvalidationRow](#tomcacheinvalidationrow)
  - [TomCachedItemLevel](#tomcacheditemlevel)
  - [TomItemAuthorizationCache](#tomitemauthorizationcache)
  - [TomItemAuthorizationChange](#tomitemauthorizationchange)
  - [TomItemAuthorizationChangePage](#tomitemauthorizationchangepage)
  - [TomItemAuthorizationWebhookException](#tomitemauthorizationwebhookexception)
  - [TomItemAuthorizationFeedExpiredException](#tomitemauthorizationfeedexpiredexception)
  - [TomItemAuthorizationWebhook](#tomitemauthorizationwebhook)
  - [TomItemAuthorizationFeedFollower](#tomitemauthorizationfeedfollower)
- [Enums](#enums)
  - [TomInvalidationKind](#tominvalidationkind)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tomserver/cache/cache_invalidation.dart`, `lib/src/tomserver/cache/invalidation_sql.dart`, `lib/src/tomserver/cache/item_authorization_cache.dart`, `lib/src/tomserver/cache/item_authorization_changes.dart`, `lib/src/tomserver/cache/server_cache.dart`, `lib/src/tomserver/cache/sql_invalidation_channel.dart`.

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

**Invalidation reaches every node through a channel.** The caches — these and
the authorization cache — live in each process, so on a cluster removing an
entry or revoking a principal on one node leaves the others serving what they
hold. `TomCacheInvalidator` is the cluster-wide entry point: each call applies
the invalidation here and hands it to the installed `TomInvalidationChannel`,
which delivers it to the other nodes. `TomLocalInvalidationChannel`, the
default, reaches no other node and has a staleness bound of zero;
`TomSqlInvalidationChannel` writes each invalidation to a table every node polls,
and its poll interval is the bound.

**Item-authorization answers follow the authority's reports.** An application
that asks a remote authority — Tom UAM — which level a user holds on an item
keeps the answer in `TomItemAuthorizationCache`, keyed by item and subject.
`TomCacheInvalidator.invalidateItemAuthorization` drops the answers an item (or
a pattern `<type>:<prefix>*`, or `*`) and a subject name on every node.
`TomItemAuthorizationWebhook` raises it for each change of a verified
`itemAuthorization.changed` delivery, and `TomItemAuthorizationFeedFollower`
for each change read from the authority's change feed — the catch-up for a
lost delivery.

## Class Hierarchy

```
TomServerException  (little_things)
    ├── TomCacheException
    ├── TomItemAuthorizationWebhookException
    └── TomItemAuthorizationFeedExpiredException

TomCacheEntry

TomCacheManager

TomCache

TomCommand  (kernel)
    ├── TomCacheStoreMessage
    ├── TomCacheRemoveMessage
    ├── TomCacheRetrieveMessage
    └── TomCacheInvalidateMessage

TomCacheInvalidation

TomInvalidationChannel  (interface)
    ├── TomLocalInvalidationChannel
    └── TomSqlInvalidationChannel

TomCacheInvalidator  (static only)

TomCacheInvalidationRow

TomCachedItemLevel

TomItemAuthorizationCache  (static only)

TomItemAuthorizationChange

TomItemAuthorizationChangePage

TomItemAuthorizationWebhook

TomItemAuthorizationFeedFollower
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
| `setCurrent` | `static TomCacheManager setCurrent(TomCacheManager manager)` | Replaces the process-wide current manager and returns **the one it replaced** — the only answer worth having, since the incoming manager is the argument just passed, while the outgoing one is the handle for releasing the registry that was displaced. A **pure swap**: the outgoing caches keep running, because the swap cannot know whether it is final — a caller swapping a manager out to swap it back would get its caches returned dead. Call `dispose()` on the returned manager when it is. |
| `getCache` | `static TomCache? getCache(String name)` | Returns the cache registered under `name`, or `null` if none is. |
| `addCache` | `static void addCache(TomCache cache)` | Registers `cache` under its `cacheName`. |
| `removeCache` | `static TomCache? removeCache(String name)` | Unregisters the cache named `name`, **stops its timers**, and returns it; `null` when none was registered — a caller tidying up should not have to know whether it got as far as registering. Unregistering and stopping are one operation because a cache installs its timers in its constructor, so one that merely leaves the registry goes on sweeping a map no lookup can reach. The cache is returned rather than destroyed: `stopTimers` is reversible, so its entries survive and `createTimers()` restarts it. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `useInThisIsolate` | `bool` | Whether caches are served from this isolate; always `true` in the main isolate, `false` in a worker forwards missing-cache operations to the creator. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `dispose` | `void dispose()` | Unregisters every cache this manager holds and stops each one's timers — what a caller invokes when it is finished with a registry: a test between cases, a process shutting down, or the manager `setCurrent` handed back after a final swap. Idempotent, so a shutdown path reaching it twice is not a fault; the caches survive and are restartable. |

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
| `fromTypeCache` | `static Future<T?> fromTypeCache<T>(String key)` | Reads the value of type `T` keyed by `key` from the cache named after `T`. Like every static entry point, keys the current tenant's entry — see the note under this table. |
| `fromNameCache` | `static Future<T?> fromNameCache<T>(String cacheName, String key)` | Reads the value keyed by `key` from cache `cacheName`; returns `null` on a miss or expiry, and an expired entry is removed in passing; throws `TomCacheException` on type mismatch or missing cache, and forwards from a worker isolate — with the same answers on the forwarded path as on the local one. |
| `toTypeCache` | `static Future<bool> toTypeCache<T>(String key, Object value)` | Stores `value` under `key` in the cache named after `T`; answers whether the key was already held. |
| `toNameCache` | `static Future<bool> toNameCache(String cacheName, String key, Object value, [DateTime? deletionTime])` | Stores `value` under `key` in cache `cacheName`, defaulting expiry from the cache's `deleteEntriesAfterSeconds`. **Answers whether the key was already held** — `true` for a replacement, `false` for an insert — a fact free at the write site, where a caller establishing it otherwise would have to read first (from a worker, a second crossing). It is about *this key*: an insert that pushes a bounded cache past its bound evicts a different key and still answers `false`. A forwarded store carries the same answer back.| a `value` that is already a `TomCacheEntry` is stored verbatim and keeps its own `deletionTime` instead, linked into the LRU chain like any other entry. `value` is non-nullable: a `null` is refused, being what a miss already answers. |
| `removeFromTypeCache` | `static Future<bool> removeFromTypeCache<T>(String key)` | Removes the entry keyed by `key` from the cache named after `T`; answers whether there was one. |
| `removeFromNameCache` | `static Future<bool> removeFromNameCache(String cacheName, String key)` | Removes the entry keyed by `key` from cache `cacheName`; forwards from a worker isolate, which carries the answer back. **Answers whether anything was removed.** Removing an absent key is still not an error — it is merely distinguishable now, where a caller wanting to know had to read first. |

**Tenant-scoped keys.** Every static entry point qualifies `key` by the tenant in
context before it touches the cache, through `TomTenantContext.qualify` —
`tenant:<id>/<key>`, or `key` itself with no tenant — so a tenant reads, replaces and removes only its own entries, and
two tenants caching one key hold two entries. A value meant for every tenant is
cached outside any tenant's context. The instance methods take the key as given.

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
| `removeEntry` | `bool removeEntry(String key)` | Removes the entry stored under `key`, unlinking it from the MRU list if the cache is bounded, and answers whether there was one; a key the cache does not hold answers `false` rather than being an error. The module's only chain-unlink routine — the deletion sweep and both of `putEntry`'s removals (replacing a key, evicting the least-recently-used entry) go through it. |
| `getEntry` | `TomCacheEntry? getEntry(String key)` | Returns the entry under `key`, or `null` if absent; in a bounded cache the entry is promoted to most-recently-used. **Does not check expiry, by decision**: this is the *structural* read, and applying a value-level policy here would collapse "no such key" and "a key whose value has died" into one `null` — the distinction a structural read exists to keep — and would make a read a mutation, since honouring the rule means dropping the entry. The rule lives once, in `fromNameCache`; the entry handed back carries its own `deletionTime`, so a caller can apply it. |
| `putEntry` | `bool putEntry(String key, TomCacheEntry entry)` | Stores `entry` under `key` at the most-recently-used position and answers whether the key was already held — captured before any branch mutates the map, since the sole-entry replacement clears it and re-enters; in a bounded cache, exceeding `maximumEntries` evicts the least-recently-used entry. Storing under a key the cache already holds replaces the entry — the previous one is unlinked through `removeEntry` first, so it leaves the MRU chain rather than staying in it unreachable and later being evicted in the replacement's place. |
| `createTimers` | `void createTimers()` | Cancels any running timers and installs the deletion and/or clearance timers for which an interval is configured. Both are created in `Zone.root`, so it does not matter where the cache was constructed or from where this is called. |
| `stopTimers` | `void stopTimers()` | Cancels the deletion and clearance timers if they are running and clears both fields; the intervals are untouched, so `createTimers` restarts the cache. |
| `createDeletionTimer` | `Timer createDeletionTimer()` | Builds the periodic timer that removes entries past their `deletionTime`, in `Zone.root`. |
| `createClearanceTimer` | `Timer createClearanceTimer()` | Builds the periodic timer that empties the entire cache, in `Zone.root`. |
| `clear` | `void clear()` | Removes every entry, resetting the MRU chain along with the backing map so a bounded cache is left consistently empty. The clearance timer and a cross-node `cache` invalidation (`TomCacheInvalidator.invalidateCache`) both come here. |
| `removeWhere` | `int removeWhere(bool Function(String key) test)` | Removes every entry whose stored key — tenant-qualified where it was stored in a tenant's context — satisfies `test`, each through `removeEntry`, and answers how many. An `item` invalidation comes here. |

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

### TomCacheInvalidation

One invalidation, as it travels between nodes: what is invalidated (`kind`),
the username or cache name it names (`target`), the entry key of a single-entry
invalidation or the subject of an item invalidation (`key`), when it was raised
(`at`, in UTC) and the node that raised it (`origin`). The constructor is
private; an invalidation is built by one of the five factories.

#### Constructors

```dart
factory TomCacheInvalidation.principal(String username, {DateTime? at, String? origin})
factory TomCacheInvalidation.cacheEntry(String cacheName, String key, {DateTime? at, String? origin})
factory TomCacheInvalidation.cache(String cacheName, {DateTime? at, String? origin})
factory TomCacheInvalidation.item(String item, {String? subject, DateTime? at, String? origin})
factory TomCacheInvalidation.fromParts({required String kind, required String target, String? key, required DateTime at, required String origin})
```

`at` defaults to now and `origin` to `TomCacheInvalidator.nodeId`; both are
stored in UTC. `item` takes the item — key, pattern `<type>:<prefix>*` or `*` —
as given; `TomCacheInvalidator.invalidateItemAuthorization` qualifies it by the
tenant in context. `fromParts` rebuilds an invalidation from its stored parts and
throws `ArgumentError` for a `kind` name no `TomInvalidationKind` carries.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `kind` | `TomInvalidationKind` | What is invalidated. |
| `target` | `String` | The username, the cache name, or the item. |
| `key` | `String?` | The entry key of a `cacheEntry` invalidation, the subject of an `item` invalidation; `null` otherwise. |
| `at` | `DateTime` | When the invalidation was raised, in UTC. For a principal, tokens issued at or before it are revoked. |
| `origin` | `String` | The node that raised it — `TomCacheInvalidator.nodeId` there. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* The kind, target, key, instant and origin, for a log line. |

### TomInvalidationChannel

How invalidations reach the other nodes of a cluster — an `abstract interface
class`, implemented rather than extended. An implementation
delivers what other nodes published to the callback given to `start`, and never
delivers a node's own invalidations back to it.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `stalenessBound` | `Duration` | The longest time from `publish` on one node to delivery on another. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `start` | `Future<void> start(Future<void> Function(TomCacheInvalidation invalidation) deliver)` | Starts delivering other nodes' invalidations to `deliver`. Completes once the channel is ready — for a channel that keeps history, after delivering the revocations still in force, so a node joining a cluster does not serve a token another node has revoked. |
| `publish` | `Future<void> publish(TomCacheInvalidation invalidation)` | Sends `invalidation` to every other node. Throws when it could not be sent, so a caller revoking a grant learns that the revocation did not leave this node. |
| `stop` | `Future<void> stop()` | Stops delivering. Idempotent. |

### TomLocalInvalidationChannel

The single-process channel: nothing to send, nothing to receive. The default,
and the right channel for a deployment of one node — an invalidation applied
here is applied everywhere there is.

- **Implements:** `TomInvalidationChannel`

#### Constructors

```dart
const TomLocalInvalidationChannel()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `stalenessBound` | `Duration` | *(override)* `Duration.zero`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `start` | `Future<void> start(Future<void> Function(TomCacheInvalidation invalidation) deliver)` | *(override)* Does nothing. |
| `publish` | `Future<void> publish(TomCacheInvalidation invalidation)` | *(override)* Does nothing. |
| `stop` | `Future<void> stop()` | *(override)* Does nothing. |

### TomCacheInvalidator

The cluster-wide entry point for invalidating caches and revoking principals.
An `abstract final class`: every member is static. Each call applies the invalidation on this node first
and then publishes it through the installed channel; a publish failure
propagates after the local apply, so this node is consistent and the caller
learns that the other nodes did not hear of it.

A grant change — a role removed, a resource grant withdrawn, an account
disabled — calls `revokePrincipal`. Every token the user holds is then refused
on every node within the channel's `stalenessBound`, and the client
re-authorizes and receives a token carrying the current grants.

Callable from any isolate: a worker forwards the call to the main isolate as a
`TomCacheInvalidateMessage`, since the caches and the channel live there.

#### Static Members

| Member | Type | Description |
| ------ | ---- | ----------- |
| `nodeId` | `String` | Identifies this process to the other nodes, so a channel can skip the invalidations it published itself. Random per process (16 hex digits from `Random.secure()`). |
| `channel` | `TomInvalidationChannel` | The installed channel; `TomLocalInvalidationChannel` until `install`. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `install` | `static Future<void> install(TomInvalidationChannel channel)` | Installs `channel`, stops the one it replaces and starts the new one with `apply` as its delivery callback. Called once at start-up, before serving requests, so the revocations still in force reach this node before it answers anyone. |
| `revokePrincipal` | `static Future<void> revokePrincipal(String username)` | Revokes, on every node, the tokens `username` holds that were issued now or earlier, and drops the principals cached for them. In a tenant's context, revokes that tenant's `username` only — the name travels qualified (`TomTenantContext.qualify`), because another tenant's account of the same name is a different person. |
| `invalidateCacheEntry` | `static Future<void> invalidateCacheEntry(String cacheName, String key)` | Removes `key` from the cache named `cacheName` on every node — the current tenant's entry, in a tenant's context, qualified as `TomCache` keys it. |
| `invalidateCache` | `static Future<void> invalidateCache(String cacheName)` | Empties the cache named `cacheName` on every node. |
| `invalidateItemAuthorization` | `static Future<void> invalidateItemAuthorization(String item, {String? subject})` | Drops, on every node, the cached item-authorization answers on `item` — an item key `<type>:<id>`, a pattern `<type>:<prefix>*`, or `*` — for `subject`, or for every subject when it is `null`; the current tenant's, in a tenant's context. |
| `raise` | `static Future<void> raise(TomCacheInvalidation invalidation)` | Applies `invalidation` here, then publishes it — on the main isolate; a worker forwards it there. |
| `apply` | `static Future<void> apply(TomCacheInvalidation invalidation)` | Applies `invalidation` to this process's caches, whichever node raised it: a principal through `TomAuthorizationCache.revokeLocally`, an entry through `TomCache.removeEntry`, a cache through `TomCache.clear`, an item through `TomItemAuthorizationCache.invalidateLocally`. A cache name nothing registered here is nothing to invalidate. |
| `reset` | `static Future<void> reset()` | Puts back the local channel, stopping the installed one. Test support. |

### TomCacheInvalidateMessage

Cross-isolate command raising `invalidation` on the main isolate, where the
caches and the channel live.

- **Extends:** `TomCommand`

#### Constructors

```dart
TomCacheInvalidateMessage(TomCacheInvalidation invalidation)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `invalidation` | `TomCacheInvalidation` | The invalidation to raise (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `execute` | `Future<bool> execute()` | *(override)* Calls `TomCacheInvalidator.raise` in the main isolate and returns `true`. |

### TomSqlInvalidationChannel

A `TomInvalidationChannel` over a database every node already has. `publish`
inserts a row into the invalidation log; every node polls the log every
`pollInterval` for rows above the highest id it has seen, and applies the ones
other nodes wrote. The staleness bound is the poll interval: a revocation raised
on one node is applied on every other within `pollInterval` plus one query.

On `start` the channel takes the log's highest id as its watermark and first
delivers every principal revocation raised within `retention` — the revocations
still in force — so a node that joins or restarts does not serve a token another
node revoked before it was there. Polling then runs on a periodic timer in
`Zone.root`.

- **Implements:** `TomInvalidationChannel`

#### Constructors

```dart
TomSqlInvalidationChannel(
  TomDataSource datasource, {
  String table = defaultInvalidationTable,
  Duration pollInterval = const Duration(seconds: 2),
  Duration? retention,
  bool createSchema = true,
})

factory TomSqlInvalidationChannel.named(
  String datasourceName, {
  String table = defaultInvalidationTable,
  Duration pollInterval = const Duration(seconds: 2),
  Duration? retention,
  bool createSchema = true,
})
```

`retention` defaults to `TomAuthorizationCache.revocationRetention`. `named`
looks the data source up in the registry and throws a `TomCacheException`
keyed `cache.invalidation.unknown_datasource` (`clientThrow: false`) when none
is registered under that name.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `TomDataSource` | The data source the log lives in (final). |
| `table` | `String` | The log table (final). |
| `pollInterval` | `Duration` | How often the log is read; also the `stalenessBound` (final). |
| `retention` | `Duration` | How long a row is kept, and how far back `start` looks for revocations (final). |
| `createSchema` | `bool` | Whether to create the log table on first use; `false` when the migration module owns the schema (final). |
| `stalenessBound` | `Duration` | *(override)* `pollInterval`. |
| `isRunning` | `bool` | Whether the channel is polling. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ensureSchema` | `Future<void> ensureSchema()` | Creates the log table if it does not exist, when `createSchema` is set. Idempotent. |
| `start` | `Future<void> start(Future<void> Function(TomCacheInvalidation invalidation) deliver)` | *(override)* Ensures the schema, records the watermark, delivers the principal revocations within `retention`, then starts the poll timer. |
| `poll` | `Future<void> poll()` | Reads up to 1000 rows above the last one seen and delivers those whose `origin` is not this node; prunes rows older than `retention` at most once per `retention / 24`. A poll still running when the next is due is not overlapped; a failure is logged at warning level and the next poll retries from the same row. Runs on the timer, and is callable directly. |
| `publish` | `Future<void> publish(TomCacheInvalidation invalidation)` | *(override)* Inserts the invalidation as a row; a failure propagates. |
| `stop` | `Future<void> stop()` | *(override)* Cancels the poll timer and drops the delivery callback. |

### TomCacheInvalidationRow

One row of the invalidation log, as `TomSqlInvalidationChannel` reads it — a
reflected row class (`@tomReflector`, `@TomDbTable` with placeholder names, as
every raw-query row type carries).

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `int` | The row's place in the log (`id`). |
| `kind` | `String` | The `TomInvalidationKind` name (`kind`). |
| `target` | `String` | The username or cache name (`target`). |
| `entryKey` | `String?` | The entry key of a single-entry invalidation (`entry_key`). |
| `origin` | `String` | The node that wrote it (`origin`). |
| `raisedAt` | `String` | When it was raised, as the stored `DATETIME(6)` text (`raised_at`). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toInvalidation` | `TomCacheInvalidation toInvalidation()` | The invalidation this row records. |

### TomCachedItemLevel

One cached item-authorization answer: the `level` a subject holds on an item,
or `null` when the authority answered that it holds none. Equal by `level`.

#### Constructors

```dart
const TomCachedItemLevel(String? level)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `level` | `String?` | The level held, or `null` for none (final). |
| `hashCode` | `int` | *(override)* The hash of `level`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `==` | `bool operator ==(Object other)` | *(override)* Equal when `level` is. |
| `toString` | `String toString()` | *(override)* The level, or `none`. |

### TomItemAuthorizationCache

The process-wide cache of item-authorization answers, keyed by item — its
resource key `<type>:<id>` — and subject — the id the authority names it by in
its change reports — and the accessible-item lists, the ids of the items of
one type a subject reaches at a minimum level, and the local copies, the level
a subject holds on every item of one type it reaches. An `abstract final class`:
every member is static. It is a
`TomCache` named `cacheName`, with the copies in a second `TomCache` named
`copyCacheName`, so both live on the main isolate, a worker's read and store are
forwarded, and their entries are the current tenant's.

#### Static Members

| Member | Type | Description |
| ------ | ---- | ----------- |
| `cacheName` | `String` | `'tom.itemAuthorization'`, the name of the underlying `TomCache`. |
| `defaultTimeToLive` | `Duration` | Five minutes: how long an answer is kept when no change names it. |
| `defaultMaximumEntries` | `int` | 10,000: the bound when `install` names none. |
| `copyCacheName` | `String` | `'tom.itemAuthorization.copy'`, the name of the `TomCache` holding the local copies. |
| `defaultCopyTimeToLive` | `Duration` | Twelve hours, a working session: how long a local copy is kept when no change names it. |
| `defaultMaximumCopies` | `int` | 1,000: the bound on local copies — one per signed-in user and copied item type — when `install` names none. |
| `generation` | `int` | Counts the invalidations applied on this isolate. A reader that asked the authority stores the answer only when the count did not move meanwhile, since an invalidation that arrived during the question may concern it. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `install` | `static void install({Duration timeToLive = defaultTimeToLive, int? maximumEntries = defaultMaximumEntries, Duration copyTimeToLive = defaultCopyTimeToLive, int? maximumCopies = defaultMaximumCopies})` | Registers the cache and the local-copy cache on this isolate's `TomCacheManager`, replacing ones of the same names. Called once at start-up on the main isolate. |
| `uninstall` | `static void uninstall()` | Removes both caches. Test support. |
| `lookup` | `static Future<TomCachedItemLevel?> lookup(String subject, String item)` | The cached answer for `subject` on `item`, or `null` on a miss. |
| `store` | `static Future<void> store(String subject, String item, String? level)` | Caches `level` — `null` for none — as `subject`'s answer on `item`. Throws `ArgumentError` when either contains a NUL character. |
| `lookupAccessible` | `static Future<List<String>?> lookupAccessible(String subject, String itemType, String minimumLevel)` | The cached ids of the items of `itemType` that `subject` reaches at `minimumLevel` or above, or `null` on a miss. |
| `storeAccessible` | `static Future<void> storeAccessible(String subject, String itemType, String minimumLevel, List<String> itemIds)` | Caches an accessible-item list. |
| `lookupCopy` | `static Future<Map<String, String>?> lookupCopy(String subject, String itemType)` | `subject`'s local copy of `itemType` — item id to level, every item the subject reaches — or `null` when none is held. |
| `storeCopy` | `static Future<void> storeCopy(String subject, String itemType, Map<String, String> levels)` | Holds `levels` as `subject`'s local copy of `itemType`. |
| `invalidateLocally` | `static int invalidateLocally(String qualifiedItem, String? subject)` | Drops on this node only the answers on `qualifiedItem` — an item key, a pattern `<type>:<prefix>*` or `*`, tenant-qualified as an `item` invalidation carries it — for `subject`, or for every subject when `null`, together with the accessible-item lists and local copies of that subject — or every subject — for the item's type, or for every type when the item is `*`; answers how many. `TomCacheInvalidator.apply` calls it. |

### TomItemAuthorizationChange

One change an authority reports: the `item` whose authorizations changed and
the `subject` they changed for, or `null` when they may have changed for
several subjects.

#### Constructors

```dart
const TomItemAuthorizationChange(String item, {String? subject})
factory TomItemAuthorizationChange.fromJson(Map<String, Object?> json)
```

`fromJson` reads `{"item": "document:42", "subject": "u-7", "subjectKind": "user"}`.
A subject of another kind than `user` — a group, an organization — becomes a
change for every subject, since the application cannot list its members.
Throws `FormatException` when `item` is missing.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `item` | `String` | The item key `<type>:<id>`, a pattern `<type>:<prefix>*`, or `*` (final). |
| `subject` | `String?` | The user the change is for, or `null` for every subject (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | The change as `fromJson` reads it. |
| `invalidate` | `Future<void> invalidate()` | Drops the answers this change names on every node, through `TomCacheInvalidator.invalidateItemAuthorization`. |
| `toString` | `String toString()` | *(override)* The item and subject, for a log line. |

### TomItemAuthorizationChangePage

One answer of the change feed.

#### Constructors

```dart
const TomItemAuthorizationChangePage({required List<TomItemAuthorizationChange> changes, required String nextCursor, bool hasMore = false})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `changes` | `List<TomItemAuthorizationChange>` | The changes since the cursor asked with, oldest first (final). |
| `nextCursor` | `String` | The cursor to read the following changes with (final). |
| `hasMore` | `bool` | Whether more changes follow `nextCursor` at once (final). |

### TomItemAuthorizationWebhookException

A webhook delivery that cannot be trusted or read; the receiving endpoint
answers it with a client error and the authority retries. Keys:
`error.item_authorization.webhook.signature_invalid`,
`error.item_authorization.webhook.timestamp_stale` (with `timestamp`),
`error.item_authorization.webhook.payload_invalid`.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomItemAuthorizationWebhookException(String key, String defaultUserMessage, {Map<String, Object?>? parameters})
```

### TomItemAuthorizationFeedExpiredException

The change feed no longer holds the cursor asked with. Thrown by the fetch
function given to `TomItemAuthorizationFeedFollower`, which then drops every
answer and continues from the current position. Key
`error.item_authorization.feed.cursor_expired`, with `cursor`;
`clientThrow: false`.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomItemAuthorizationFeedExpiredException(String cursor)
```

### TomItemAuthorizationWebhook

Verifies one `itemAuthorization.changed` webhook delivery and drops, on every
node, the answers its changes name. A delivery carries `x-tom-event-id`,
`x-tom-timestamp` (seconds since the epoch) and `x-tom-signature` (`sha256=`
and the hex HMAC-SHA256 of `<event id>.<timestamp>.<body>`, keyed by the
subscription's secret) and the body
`{"type": "itemAuthorization.changed", "changes": [...]}`.

#### Constructors

```dart
TomItemAuthorizationWebhook(List<String> secrets, {String? tenantId, Duration tolerance = defaultTolerance, DateTime Function()? clock})
```

`secrets` holds one secret, or two during a rotation; any other count throws
`ArgumentError`. `clock` defaults to `DateTime.now`.

#### Static Members

| Member | Type | Description |
| ------ | ---- | ----------- |
| `eventIdHeader` | `String` | `'x-tom-event-id'`. |
| `timestampHeader` | `String` | `'x-tom-timestamp'`. |
| `signatureHeader` | `String` | `'x-tom-signature'`. |
| `eventType` | `String` | `'itemAuthorization.changed'`, the event type applied. |
| `defaultTolerance` | `Duration` | Five minutes. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `sign` | `static String sign(String secret, String eventId, String timestamp, String body)` | The signature header value a sender computes. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `secrets` | `List<String>` | The secrets a signature may be made with (final). |
| `tenantId` | `String?` | The tenant the subscription belongs to; changes are applied in its context (final). |
| `tolerance` | `Duration` | How far a delivery's timestamp may lie from now, either way (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `receive` | `Future<int> receive(Map<String, String> headers, String body)` | Verifies the delivery — header names in any case — and raises an item invalidation for each change; answers how many, none for another event type. Throws `TomItemAuthorizationWebhookException` for a missing or wrong signature, a timestamp outside `tolerance`, or a body that is not an event. |

### TomItemAuthorizationFeedFollower

Follows an authority's change feed and drops, on every node, the answers each
change names. Without a known position — at the first poll and after an
expired cursor — it takes the current position and then drops every answer of
its tenant. The cursor advances only after a page is applied; a failed read is
logged and retried at the next poll.

#### Constructors

```dart
TomItemAuthorizationFeedFollower(Future<TomItemAuthorizationChangePage> Function(String? cursor) fetch, {Duration pollInterval = defaultPollInterval, String? tenantId})
```

#### Static Members

| Member | Type | Description |
| ------ | ---- | ----------- |
| `defaultPollInterval` | `Duration` | Thirty seconds. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `fetch` | `Future<TomItemAuthorizationChangePage> Function(String? cursor)` | Reads the feed since a cursor, `null` for the current position; throws `TomItemAuthorizationFeedExpiredException` for a cursor the feed no longer holds (final). |
| `pollInterval` | `Duration` | How often the feed is read (final). |
| `tenantId` | `String?` | The tenant whose feed this is (final). |
| `cursor` | `String?` | The cursor the next poll reads with; `null` until the position is known. |
| `isRunning` | `bool` | Whether the follower polls on a timer. |
| `stalenessBound` | `Duration` | `pollInterval` plus the installed channel's `stalenessBound`: the longest time from a change to its answers being dropped on every node when no webhook delivered it. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `start` | `Future<void> start()` | Polls once, then on a timer in `Zone.root` every `pollInterval`. |
| `poll` | `Future<int> poll()` | Reads the feed until no more changes wait and raises their invalidations; answers how many. Not overlapped with a running poll. |
| `stop` | `void stop()` | Stops the timer. Idempotent. |

## Enums

### TomInvalidationKind

What a `TomCacheInvalidation` invalidates.

| Value | Meaning |
| ----- | ------- |
| `principal` | Every token a user holds that was issued at or before the invalidation; `target` is the username. |
| `cacheEntry` | One entry of a named cache; `target` is the cache name and `key` the entry key. |
| `cache` | Every entry of a named cache; `target` is the cache name. |
| `item` | The cached item-authorization answers an item and a subject name; `target` is the tenant-qualified item key, pattern `<type>:<prefix>*` or `*`, and `key` the subject, or `null` for every subject. |

## Global Functions and Constants

| Name | Declaration | Description |
| ---- | ----------- | ----------- |
| `defaultInvalidationTable` | `const String defaultInvalidationTable = 'tom_cache_invalidation'` | The default name of the cache-invalidation log. |
| `invalidationTable` | `TomFrameworkTable invalidationTable(String table)` | The cache-invalidation log `table`, declared once as a framework-owned table: `id` (`BIGINT` auto-increment, primary key), `kind`, `target`, `entry_key` (nullable), `origin`, `raised_at` (`DATETIME(6)`, indexed). Listed by `frameworkOwnedTables`. |
| `invalidationTableDdl` | `String invalidationTableDdl(String table)` | The `CREATE TABLE` for the log `table`, for a deployment that applies DDL by hand. |
