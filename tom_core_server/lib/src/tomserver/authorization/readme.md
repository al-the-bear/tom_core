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

When a user's grants change, the cached principal — and the token's own claims —
would go on granting what was withdrawn until the token expired. So the cache
also keeps a revocation instant per username: a token issued at or before it
yields no principal (`authorization.cache.revoked_principal`), cached or not,
and the client re-authorizes for a token carrying the current grants. A grant
change raises one with `TomCacheInvalidator.revokePrincipal(username)` from the
`cache` module, which carries it to every node of a cluster.

`TomResourceDataScope` applies that data to the database: install it once and
every entity carrying a `resource_key` column is filtered — on reads *and* on
writes — by the resource keys the current principal holds a grant on, with no
application-side resolver involved.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomAuthorizationCache` | Static principal cache; `storePrincipal(...)` and `getPrincipal(...)`, with cross-isolate forwarding. `revokeLocally(username, at)` records a revocation in this process and `isRevoked(token)` compares the token's `iat` (else `nbf`) with it in whole seconds; revocations are kept for `revocationRetention` (one day by default), which must outlast the longest token lifetime. Its eviction sweep starts with the first stored principal, runs in `Zone.root` rather than the storing request's zone, and stops through `stopEviction()` or, on a server, by registering `instance` with `tomShutdownCleanup`. |
| `TomAuthorizationCacheEntry` | One cached principal with the instant it expires. Immutable, and the instant is required: an entry's lifetime is the token's, so there is none the entry could default to or be moved to. |
| `TomAuthorizationCacheStoreMessage` · `TomAuthorizationCacheRetrieveMessage` | Cross-isolate commands carrying a store/retrieve to the main isolate. |
| `TomAuthorizationCacheExecutor` | `TomExecutor` that runs those commands in the creator isolate. |
| `TomAuthorizationCacheException` | Raised on cache faults: an expired entry on read (dropped by the read that rejects it, so the expiry is reported once), a token issued before its user's last revocation, or a token whose `exp` claim is missing or unreadable on write (refused rather than cached under an invented expiry). |
| `TomPrincipalResourceGrant` · `PrincipalResourceGrantStore` · `TomPrincipalResourceRoleResolver` | The `(principalId, resourceKey, role)` row, its read seam, and the fold into a `resourceKey → role` map (strongest role wins). |
| `TomPrincipalDelegation` · `TomDelegationMode` · `TomDelegationResolver` | Share / absence / intentional delegation of a delegator's roles, and the resolver folding them over the delegate's direct grants. Never transitive. The `validFrom` / `validTo` bounds are **instants**, stored and read as UTC `DATETIME(6)` by the datasource's instant convention (`../datasources/sql_instant.dart`), so every node of a cluster reads the same window out of the same row. |
| `PrincipalDelegationStore` · `RepositoryPrincipalDelegationStore` · `InMemoryPrincipalDelegationStore` | The delegation read seam, taking the instant (`activeDelegationsForDelegate(delegateId, at)`) so only live rows are read: the repository store tests `revoked` and both window bounds in SQL, the in-memory store applies `isActiveAt`. |
| `TomResourceGrant` · `TomAuthStateCodec` · `TomGradedAccessControlInformation` | The graded `(role, resourceKey)` record, its stored representation, and the resolved graded view over the kernel's binary fallback. |
| `TomResourceDataScope` | Installs the grant-driven `resource` row scope: `read` or wider admits a row to queries, `full` alone admits a write. |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  // A request arrives bearing its authorization token:
  final token = TomClientJwtToken(issuedAuthorizationTokenString, decrypt: true);

  // The cache resolves it to the principal stored at login, so the request
  // skips a fresh authentication. Nothing cached is `null`; an entry past its
  // expiry throws instead -- and is dropped by that read, so asking again for
  // the same dead token is a plain miss:
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

> **A fragment, not a program.** `issuedAuthorizationTokenString` stands for the
> token a request arrives bearing, and there is nowhere for a standalone script
> to get one — so this does not compile as written. It is shown whole anyway
> because the three things it does (resolve a token, register the cache for
> shutdown, install the row scope) belong to one bootstrap and mislead when
> shown apart.

See [`doc/authorization.md`](../../../../doc/authorization.md) for the grade
thresholds, the delegation modes, revoking a principal and the grant reads kept
for a request, and
`example/authorization/authorization_example.dart` and
`example/authorization/resource_data_scope_example.dart` for runnable,
connection-free walkthroughs of the grant model and of the row scope the
fragment above installs. `test/authorization_test.dart` covers the module, with
`test/graded_authorization_test.dart` on the thresholds,
`test/column_authorization_test.dart` on field grades,
`test/principal_delegation_test.dart` and
`test/principal_resource_grant_test.dart` on delegation, and
`test/data_scope_test.dart` / `test/resource_data_scope_test.dart` on the row
scope — `test/resource_data_scope_db_test.dart` adds what only a live database
(MariaDB or PostgreSQL) can answer. `test/examples_test.dart` runs both examples and
`test/readme_quick_start_test.dart` holds the fragment above to admitting that
it is one. Revocation is covered by `test/cache_invalidation_test.dart`.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
