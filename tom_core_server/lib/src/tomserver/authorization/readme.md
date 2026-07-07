# authorization

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

A short-lived cache of authenticated principals, keyed by authorization token.
Once `authentication` issues a token, `TomAuthorizationCache` stores the
`TomPrincipal` so later requests on the same token skip a fresh login. The cache
is isolate-aware: a worker isolate forwards `storePrincipal` / `getPrincipal` to
the main isolate (where the cache lives) via a `TomExecutor` command.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomAuthorizationCache` | Static principal cache; `storePrincipal(...)` and `getPrincipal(...)`, with cross-isolate forwarding. |
| `TomAuthorizationCacheEntry` | One cached principal with its expiry bookkeeping. |
| `TomAuthorizationCacheStoreMessage` · `TomAuthorizationCacheRetrieveMessage` | Cross-isolate commands carrying a store/retrieve to the main isolate. |
| `TomAuthorizationCacheExecutor` | `TomExecutor` that runs those commands in the creator isolate. |
| `TomAuthorizationCacheException` | Raised on cache faults. |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  // A request arrives bearing its authorization token:
  final token = TomClientJwtToken(issuedAuthorizationTokenString, decrypt: true);

  // The cache resolves it to the principal stored at login (null if expired
  // or never cached), so the request skips a fresh authentication:
  final principal = await TomAuthorizationCache.getPrincipal(token);
  print(principal == null); // true when nothing is cached for this token
}
```

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
