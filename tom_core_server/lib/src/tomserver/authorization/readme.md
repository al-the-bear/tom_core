# authorization

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The server-side authorization data — which role a principal holds on which
resource, how strongly that role counts, and who has lent their roles to whom —
plus a short-lived cache of authenticated principals keyed by authorization
token. Once `authentication` issues a token, `TomAuthorizationCache` stores the
`TomPrincipal` so later requests on the same token skip a fresh login. The cache
is isolate-aware: a worker isolate forwards `storePrincipal` / `getPrincipal` to
the main isolate (where the cache lives) via a `TomExecutor` command.

`TomResourceDataScope` applies that data to the database: install it once and
every entity carrying a `resource_key` column is filtered — on reads *and* on
writes — by the resource keys the current principal holds a grant on, with no
application-side resolver involved.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomAuthorizationCache` | Static principal cache; `storePrincipal(...)` and `getPrincipal(...)`, with cross-isolate forwarding. Its eviction sweep starts with the first stored principal, runs in `Zone.root` rather than the storing request's zone, and stops through `stopEviction()` or, on a server, by registering `instance` with `tomShutdownCleanup`. |
| `TomAuthorizationCacheEntry` | One cached principal with its expiry bookkeeping. |
| `TomAuthorizationCacheStoreMessage` · `TomAuthorizationCacheRetrieveMessage` | Cross-isolate commands carrying a store/retrieve to the main isolate. |
| `TomAuthorizationCacheExecutor` | `TomExecutor` that runs those commands in the creator isolate. |
| `TomAuthorizationCacheException` | Raised on cache faults: an expired entry on read, or a token whose `validUntil` claim is unreadable on write (refused rather than cached under an invented expiry). |
| `TomPrincipalResourceGrant` · `PrincipalResourceGrantStore` · `TomPrincipalResourceRoleResolver` | The `(principalId, resourceKey, role)` row, its read seam, and the fold into a `resourceKey → role` map (strongest role wins). |
| `TomPrincipalDelegation` · `TomDelegationMode` · `TomDelegationResolver` | Share / absence / intentional delegation of a delegator's roles, and the resolver folding them over the delegate's direct grants. Never transitive. |
| `TomResourceGrant` · `TomAuthStateCodec` · `TomGradedAccessControlInformation` | The graded `(role, resourceKey)` record, its stored representation, and the resolved graded view over the kernel's binary fallback. |
| `TomResourceDataScope` | Installs the grant-driven `resource` row scope: `read` or wider admits a row to queries, `full` alone admits a write. |

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

  // Caching the first principal starts the hourly eviction sweep, which is a
  // periodic timer and so holds the isolate open. Register the cache once at
  // start-up and shutdown stops the sweep and drops the cached principals.
  tomShutdownCleanup.addDisposable(TomAuthorizationCache.instance);

  // Once at start-up, wire the grant-driven row scope over the same delegation
  // resolver the rest of the layer uses. Until this runs the scope denies every
  // row — an unwired scope is a closed door. The stores are shown seeded here;
  // a server passes RepositoryPrincipalDelegationStore /
  // RepositoryPrincipalResourceGrantStore over their entity repositories.
  TomResourceRoleRegistry.registerAll({
    'owner': TomAuthState.full,
    'viewer': TomAuthState.read,
  });
  TomResourceDataScope.install(
    TomDelegationResolver(
      InMemoryPrincipalDelegationStore([]),
      TomPrincipalResourceRoleResolver(
        InMemoryPrincipalResourceGrantStore([
          TomPrincipalResourceGrant(
            principalId: '1',
            resourceKey: 'proj-a',
            role: 'owner',
          ),
        ]),
      ),
    ),
  );
  print(TomResourceDataScope.isInstalled); // true
}
```

See [`doc/authorization.md`](../../../../doc/authorization.md) for the grade
thresholds, the delegation modes and the request-scoped `runCached`, and
`example/authorization/resource_data_scope_example.dart` for a runnable,
connection-free walkthrough.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
