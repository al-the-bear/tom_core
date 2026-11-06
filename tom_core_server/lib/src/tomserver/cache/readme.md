# cache

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Named, isolate-aware in-memory caches. A `TomCache` holds `TomCacheEntry` values
with optional time-based expiry, an LRU `maximumEntries` bound, and periodic
clear/deletion timers. `TomCacheManager` owns the named caches per isolate and
forwards operations from worker isolates to the main isolate (where caches
physically live). Static helpers key a cache by Dart type or by name.

**Invalidation reaches every node.** Caches — these and the authorization
cache — live in one process each, so on a cluster `TomCacheInvalidator` carries
an invalidation to the other nodes through an installed
`TomInvalidationChannel`: `revokePrincipal(username)` refuses every token the
user holds so far on every node, and `invalidateCacheEntry` / `invalidateCache` remove
an entry or empty a cache everywhere, and `invalidateItemAuthorization` drops
the item-authorization answers an item and a subject name. The default `TomLocalInvalidationChannel`
reaches no other node, for a single process; `TomSqlInvalidationChannel` writes
each invalidation to the `tom_cache_invalidation` table — declared once by
`invalidationTable` — and every node polls it,
so its poll interval (two seconds by default) is the staleness bound;
`TomBusInvalidationChannel` publishes each invalidation on a message bus
(`tom_core_message_bus`) every node subscribes to with an ephemeral group of
its own, for near-immediate eviction, and reads the revocations still in force
from a `TomInvalidationLog` — normally the SQL channel's table — when it starts;
its bound is stated, one second by default. Install the channel once at
start-up, before serving requests.

**Forwarding is one crossing per operation.** There is no batch command and no
worker-side copy, so ten cached lookups from a worker are ten round trips and
asking twice for the same key costs twice. That stands deliberately: a batch
command only helps a call site that knows its keys up front, and a worker-side
copy would cost the module its one guarantee that there is exactly *one* copy of
a cached value. The size of the cost is unmeasured. A deployment that finds it
matters resolves a key once per request rather than repeatedly, or registers the
cache in the worker as well — the local registry is consulted before forwarding,
so that serves the read with no crossing at all, at the price of the second copy
being the deployment's decision rather than the framework's.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomCache` | A named cache; constructor takes `cacheName` plus `deleteEntriesAfterSeconds`, `maximumEntries`, and clear/deletion intervals — each positive or `null`, since `null` is how a feature is switched off and a non-positive value would give a black-hole cache or a busy-loop sweep. **`maximumEntries` defaults to `TomCache.defaultMaximumEntries` (100)**: a cache is LRU-bounded unless the caller passes `null`, because whether growing without a bound is a leak depends on the shape of the key and the cache cannot see it. `TomCache.forType(Type)` names it after a type. Its clear and deletion timers run in `Zone.root` rather than the zone that constructed the cache, and stop through `stopTimers()`. |
| `TomCacheEntry` | One cached value (`value`) with an optional `deletionTime`. The value is non-nullable: a read answers `null` for a miss and for an expiry, so an entry holding `null` would be one no read could surface. |
| Static helpers | `TomCache.toTypeCache<T>` / `fromTypeCache<T>` / `removeFromTypeCache<T>` and the `*NameCache` variants store/retrieve/remove by type or name. |
| `TomCacheManager` | Per-isolate registry; `getCache(name)` / `addCache` / `removeCache(name)`, `dispose()`, and the cross-isolate forwarding decision (`useInThisIsolate`). A cache installs its timers in its constructor, so leaving the registry has to stop them too — `removeCache` and `dispose` do, while `setCurrent` stays a pure swap and hands back the displaced manager for the caller to `dispose` when the swap is final. |
| `TomCacheInvalidator` | The cluster-wide entry point: `install(channel)` at start-up, then `revokePrincipal`, `invalidateCacheEntry`, `invalidateCache` and `invalidateItemAuthorization`. Applies each invalidation here first, then publishes it; a publish failure propagates. Callable from any isolate. |
| `TomInvalidationChannel` · `TomLocalInvalidationChannel` · `TomSqlInvalidationChannel` · `TomBusInvalidationChannel` | How invalidations reach the other nodes, each stating its `stalenessBound`: zero for the local channel, the poll interval for the SQL one, the expected broker delivery time (one second by default) for the bus one. The SQL and bus channels apply the revocations still in force when they start. |
| `TomInvalidationLog` · `TomMemoryInvalidationLog` · `tomInvalidationTopic` | Where the bus channel remembers revocations — `TomSqlInvalidationChannel` is a log too, `TomMemoryInvalidationLog` keeps one in memory — and the topic it publishes on, `tom.cache.invalidation`. |
| `TomCacheInvalidation` · `TomInvalidationKind` | One invalidation — `principal`, `cacheEntry`, `cache` or `item` — with its target, instant and originating node. |
| `TomItemAuthorizationCache` · `TomCachedItemLevel` | The answers a remote authority (Tom UAM) gave on items — which level a subject holds — keyed by item and subject, kept until a change names them or their lifetime ends. |
| `TomItemAuthorizationWebhook` · `TomItemAuthorizationFeedFollower` · `TomItemAuthorizationChange` · `TomItemAuthorizationChangePage` | How the authority's change reports arrive: a verified `itemAuthorization.changed` delivery, and the change feed read on a timer as the catch-up. Each change raises `invalidateItemAuthorization`. Failures: `TomItemAuthorizationWebhookException`, `TomItemAuthorizationFeedExpiredException`. |

**Two reads, and only one of them expires.** `TomCache.fromNameCache` is the
*value*-level read: it applies the expiry rule, dropping an entry whose
`deletionTime` has passed and answering `null`. `getEntry` is the *structural*
one and deliberately does not — applying a value policy there would collapse "no
such key" and "a key whose value has died" into one `null`, which is the
distinction a structural read exists to keep, and would make a read a mutation,
since honouring the rule means dropping the entry. So the rule lives once, and
the entry `getEntry` hands back carries its own `deletionTime` for a caller that
wants to apply it. Read values through the static helpers; reach for
`getEntry` / `putEntry` when the question is about the structure — storing an
entry with a lifetime of its own, or inspecting what is actually held.

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  // Register a cache keyed by the type it holds.
  final greetings = TomCache.forType(String);
  TomCacheManager.addCache(greetings);

  await TomCache.toTypeCache<String>('greeting', 'hello');
  final value = await TomCache.fromTypeCache<String>('greeting');

  print(value); // hello

  // A cache installs periodic timers when it is constructed, and a live timer
  // keeps the isolate alive — so a program that outlives its caches has to stop
  // them to exit. A server never gets here; a script like this one does.
  greetings.stopTimers();
}
```

**Metrics.** Every value read is counted in `tom_cache_lookups`
(`tomCacheLookupsMetric`) by cache and result — `hit`, `miss` or `expired` — see
[`doc/metrics.md`](../../../../doc/metrics.md).

See [`doc/cache.md`](../../../../doc/cache.md) for expiry and bounds, the
isolate model, cross-node invalidation, and what the module does not yet do, and
`example/cache/cache_example.dart` for a runnable ten-step walkthrough that
checks its own results. `test/cache_test.dart` covers the module and also runs
the example; `test/readme_quick_start_test.dart` runs the snippet above, so
neither can drift unnoticed.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
