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
| `TomCache` | A named cache; constructor takes `cacheName` plus `deleteEntriesAfterSeconds`, `maximumEntries`, and clear/deletion intervals. `TomCache.forType(Type)` names it after a type. |
| `TomCacheEntry` | One cached value (`value`) with an optional `deletionTime`. |
| `TomCacheManager` | Per-isolate registry; `getCache(name)` / `addCache`, and the cross-isolate forwarding decision (`useInThisIsolate`). |
| Static helpers | `TomCache.toTypeCache<T>` / `fromTypeCache<T>` / `removeFromTypeCache<T>` and the `*NameCache` variants store/retrieve/remove by type or name. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  // Register a cache keyed by the type it holds.
  TomCacheManager.addCache(TomCache.forType(String));

  await TomCache.toTypeCache<String>('greeting', 'hello');
  final value = await TomCache.fromTypeCache<String>('greeting');

  print(value); // hello
}
```

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
