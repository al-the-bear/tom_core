# cache

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Named, isolate-aware in-memory caches. A `TomCache` holds `TomCacheEntry` values
with optional time-based expiry, an LRU `maximumEntries` bound, and periodic
clear/deletion timers. `TomCacheManager` owns the named caches per isolate and
forwards operations from worker isolates to the main isolate (where caches
physically live). Static helpers key a cache by Dart type or by name.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomCache` | A named cache; constructor takes `cacheName` plus `deleteEntriesAfterSeconds`, `maximumEntries`, and clear/deletion intervals. `TomCache.forType(Type)` names it after a type. Its clear and deletion timers run in `Zone.root` rather than the zone that constructed the cache, and stop through `stopTimers()`. |
| `TomCacheEntry` | One cached value (`value`) with an optional `deletionTime`. |
| `TomCacheManager` | Per-isolate registry; `getCache(name)` / `addCache`, and the cross-isolate forwarding decision (`useInThisIsolate`). |
| Static helpers | `TomCache.toTypeCache<T>` / `fromTypeCache<T>` / `removeFromTypeCache<T>` and the `*NameCache` variants store/retrieve/remove by type or name. |

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

See [`doc/cache.md`](../../../../doc/cache.md) for expiry and bounds, the
isolate model, and what the module does not yet do, and
`example/cache/cache_example.dart` for a runnable nine-step walkthrough that
checks its own results. `test/cache_test.dart` covers the module and also runs
both the example and the snippet above, so neither can drift unnoticed.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
