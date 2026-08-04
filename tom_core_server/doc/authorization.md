# Authorization Module

The server-side authorization *data*: which role a principal holds on which
resource, how strongly that role counts, who has lent their roles to whom, and a
per-token cache so a resolved principal is not rebuilt on every request. The
module also turns those grants into a database row filter — the grant-driven
row scope.

## Table of Contents

- [Overview](#overview)
- [The Principal Cache](#the-principal-cache)
- [Where It Fits](#where-it-fits)
- [Isolate Model](#isolate-model)
- [Lifetime and Expiry](#lifetime-and-expiry)
- [Grants, Grades and Delegations](#grants-grades-and-delegations)
- [The Grant-Driven Row Scope](#the-grant-driven-row-scope)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomAuthorizationCache` | class | The main-isolate cache: `getPrincipal` / `storePrincipal` keyed by JWT token string |
| `TomAuthorizationCacheEntry` | class | One cached principal paired with its expiry (`deletionTime`) |
| `TomAuthorizationCacheException` | exception | Thrown when a cached entry exists but has expired |
| `TomAuthorizationCacheStoreMessage` | class | Cross-isolate command: store a principal in the main isolate |
| `TomAuthorizationCacheRetrieveMessage` | class | Cross-isolate command: read a principal from the main isolate |
| `TomAuthorizationCacheExecutor` | `TomExecutor` | Services the two messages in the main isolate |
| `TomPrincipalResourceGrant` | entity | One `(principalId, resourceKey, role)` row — the role a principal holds on a resource (C-5) |
| `PrincipalResourceGrantStore` | abstract class | The read seam over those rows (repository-backed at boot, in-memory under test) |
| `TomPrincipalResourceRoleResolver` | class | Folds a principal's grants into a `resourceKey → role` map, strongest role winning |
| `TomPrincipalDelegation` | entity | One delegation row: A lends roles to B in `share` / `absence` / `intentional` mode (C-6) |
| `TomDelegationResolver` | class | Resolves *effective* roles — direct grants folded with the delegations active now |
| `TomResourceGrant` | entity | Grades a `(role, resourceKey)` pair with a `TomAuthState` |
| `TomAuthStateCodec` | class | Round-trips a `TomAuthState` to and from its stored column value |
| `TomGradedAccessControlInformation` | class | The graded view of a principal's keys, with the legacy binary list as fallback |
| `TomResourceDataScope` | class | Installs the grant-driven `resource` row scope over a `TomDelegationResolver` |

## The Principal Cache

Resolving the `TomPrincipal` for an authentication token (loading roles,
access-control settings, etc.) is comparatively expensive, so the server caches
the result once and reuses it for the lifetime of the token instead of
re-resolving it on every request.

## Where It Fits

The cache is read by the server's authentication middleware. On each incoming
request the middleware extracts the client JWT token, then asks the cache for
the matching principal before falling back to the principal carried on the
request itself:

```dart
var (TomPrincipal? callPrincipal, TomClientJwtToken? clientToken) =
    extractAuthentication(request);

var principal =
    (clientToken != null
        ? await TomAuthorizationCache.getPrincipal(clientToken)
        : null) ??
    callPrincipal;
```

The authorization layer that resolves a principal calls
`TomAuthorizationCache.storePrincipal(token, principal)` once, so subsequent
requests bearing the same token short-circuit straight to the cached value.

### The cache does not decide access

The cache grants and refuses nothing. It is a **cache of resolved principals** —
it makes the *user* operand cheap to obtain, and stops there. The access
decision itself is `TomAccessControl` in `tom_core_kernel`, and it has a second
operand the cache never sees: the deployment's own grants, which cap the user's.

If you are here because a permission that is clearly present was refused
anyway, this is the wrong section. Read `tom_core_kernel`'s
`doc/security/security.md` §"The Server Principal and the Meet", and check
`TomServerPrincipal.current` before you check the cache.

The rest of the module *is* about who may do what: the grant, grade and
delegation rows below are the deployment's own authorization data, and the row
scope applies it to the database.

## Isolate Model

The cache is a single map that lives in the **main isolate**, keyed by the JWT
token string. Worker isolates do not keep their own copy. Both entry points
detect the calling isolate via `TomWorker.isMainIsolate`:

```text
main isolate              worker isolate
─────────────             ──────────────
getPrincipal  ──────────  getPrincipal
   │ reads _cache            │ TomWorker.executeInCreator(
   ▼                        │   TomAuthorizationCacheRetrieveMessage)
TomPrincipal?               ▼
                       TomAuthorizationCacheExecutor (main isolate)
                            │ → TomAuthorizationCache.getPrincipal
                            ▼
                       TomPrincipal?
```

`storePrincipal` works the same way, forwarding a
`TomAuthorizationCacheStoreMessage`. This keeps one authoritative copy of the
cache reachable from every request regardless of which isolate handles it.

## Lifetime and Expiry

Each `TomAuthorizationCacheEntry` carries a `deletionTime`. When stored via
`storePrincipal`, this is set from the token's `validUntil` payload claim, so a
cached principal expires together with the token that authorized it. A
constructed entry with no explicit time defaults to one day.

Expiry is enforced two ways:

- **Lazily on read** — `getPrincipal` throws
  `TomAuthorizationCacheException` if a matching entry is found but already
  past its `deletionTime`. The distinct exception type lets the caller catch it
  specifically and treat it as a prompt to re-authorize (a true cache *miss*,
  by contrast, simply returns `null`).
- **Eagerly on a timer** — a periodic timer sweeps the map once an hour and
  removes entries whose `deletionTime` has passed, so stale principals do not
  accumulate.

## Grants, Grades and Delegations

Three persisted record types answer three different questions. They stack:

| Question | Record | Table |
| -------- | ------ | ----- |
| Which **role** does this principal hold on this resource? | `TomPrincipalResourceGrant` (C-5) | `tom_principal_resource_grant` |
| Whose roles has this principal been **lent**? | `TomPrincipalDelegation` (C-6) | `tom_principal_delegation` |
| How **strong** is a given role on a given resource? | `TomResourceGrant` | `tom_resource_grant` |

`TomPrincipalResourceRoleResolver` folds a principal's grant rows into a
`resourceKey → roleName` map. A `(principal, resource)` with no row simply has
no entry — there is no fallback, and the kernel's `TomResourceRoleAdapter`
resolves the absent key to `TomAuthState.none`. When several rows name the same
resource the **strongest** role wins, decided by a caller-supplied ordering so
the resolver stays independent of any particular role vocabulary.

`TomDelegationResolver` wraps that resolver and folds in the delegations active
at a given instant, in three modes: **share** (an explicit `(resourceKey, role)`
the delegate need hold no grant of their own for), **absence** (within the
validity window the delegate inherits *all* the delegator's direct roles), and
**intentional** (the same, until the row is revoked). The validity window and the
`revoked` kill-switch apply uniformly to every mode; the mode only decides
*which* roles flow. **Delegation is not transitive** — a delegate inherits the
delegator's *direct* grants only, never the delegator's own delegated-in roles,
which forecloses delegation chains and privilege loops.

`TomResourceGrant` is the orthogonal axis: it grades a `(role, resourceKey)`
pair with a `TomAuthState` (`none` / `disabled` / `read` / `full`), stored by
name through `TomAuthStateCodec` — a lenient codec, in that an unknown or `null`
stored value resolves to `none`, the closed default.
`TomGradedAccessControlInformation` resolves the effective grade for a key,
using an explicit grade where one exists and otherwise bridging the kernel's
legacy binary `resourceKeys` list (present → `full`, absent → `none`), so a
deployment that has only the binary list behaves exactly as before.

All three entities are annotated `@TomDbScope.unscoped()`: they are the row
scope's *input*, and filtering them by the scope they feed would close the
authorization layer against itself. See
[`object_persistence.md`](object_persistence.md#automatic-scoping-and-opting-out)
for the second, codegen-independent guard that backs the annotation up.

## The Grant-Driven Row Scope

`TomResourceDataScope` is the module's implementation of the
`TomResourceScopeSource` hook declared in `object_persistence`. It turns the
grants and delegations above into the `WHERE resource_key IN (…)` predicate the
repository ANDs into every query on an entity that carries a resource-key
column — with **no application-side resolver** involved. Install it once, at
start-up, from the same delegation resolver the rest of the layer uses:

```dart
TomResourceDataScope.install(delegationResolver);
```

While nothing is installed the scope denies every row. That is deliberate: an
unwired scope must be a closed door, not an open one.

### The grades are the design

Every grant names a role, and `TomResourceRoleRegistry` (in `tom_core_kernel`)
grades that role as a `TomAuthState`:

- a row is admitted to a **query** at grade `read` or wider;
- a row is admitted to a **write** only at `full`.

So a viewer's shared project is listed and opened, while every attempt to modify
it is rejected with `TomDataScopeAuthorizationException` — which is exactly the
difference between "shared with me" and "mine". The two thresholds are the read
and write resolvers of the `resource` scope kind; the write resolver is the
narrower one, and the persistence layer's `forWrite` flag selects it.

An **unregistered role grades as nothing and grants nothing**, so a typo in a
grant row closes a door rather than opening one.

### Resolution is live

The keys are read from the grant and delegation tables on **every request**,
deliberately: a revoked share must stop granting access at revocation, not at
token expiry. Nothing is trusted from the token.

The cost of that choice is a read per resolution, and a single request resolves
the scope several times (one per repository call, plus the write check).
`TomResourceDataScope.runCached` amortises them:

```dart
await TomResourceDataScope.runCached(() async {
  // every scope resolution in here shares one grant read per principal
});
```

The cache lives in the zone, so it cannot outlive the body and cannot leak
between concurrently-served requests — resolution stays live *across* requests,
which is where liveness actually matters.

### Two guards worth knowing

- **Delegations are folded in *through* `TomDelegationResolver`, not around it**,
  so every rule the delegation model already enforces — validity window,
  revocation, mode semantics, non-transitivity — governs the row scope for free.
- **The resolution runs inside `TomDataScope.runUnscoped`.** It reads the grant
  and delegation tables through ordinary repositories; without the bypass the
  scope would recurse into itself while computing its own input.

A `null` principal (an unauthenticated request) resolves to no keys, so the query
renders a `FALSE` filter rather than an unfiltered one — deny by default, as with
the built-in `owner` and `group` scopes.

`example/authorization/resource_data_scope_example.dart` walks all of this
connection-free; `test/resource_data_scope_db_test.dart` covers it end to end
against MariaDB.

## Core Components

- **`TomAuthorizationCache`** — the cache itself. Public surface is the two
  static methods `getPrincipal` and `storePrincipal`; the backing map is
  private.
- **`TomAuthorizationCacheEntry`** — value object pairing the
  `authorizedPrincipal` with its `deletionTime`.
- **`TomAuthorizationCacheException`** — signals an expired-but-present entry.
- **`TomAuthorizationCacheStoreMessage` / `TomAuthorizationCacheRetrieveMessage`**
  — the commands worker isolates send to the main isolate.
- **`TomAuthorizationCacheExecutor`** — the `TomExecutor` registered in the
  main isolate that turns those commands back into `TomAuthorizationCache`
  calls.
- **`TomPrincipalResourceGrant` + `PrincipalResourceGrantStore` +
  `TomPrincipalResourceRoleResolver`** — the C-5 grant row, its read seam
  (`RepositoryPrincipalResourceGrantStore` at boot,
  `InMemoryPrincipalResourceGrantStore` under test) and the fold into a
  `resourceKey → role` map.
- **`TomPrincipalDelegation` + `TomDelegationMode` + `PrincipalDelegationStore` +
  `TomDelegationResolver`** — the C-6 delegation row, its three modes, its read
  seam and the resolver that produces a principal's effective roles.
- **`TomResourceGrant` + `TomAuthStateCodec` +
  `TomGradedAccessControlInformation`** — the graded `(role, resourceKey)`
  record, its stored representation, and the resolved graded view.
- **`TomResourceDataScope`** — the `TomResourceScopeSource` behind the built-in
  `resource` row scope: `install` / `uninstall` / `isInstalled`, the
  `readableResourceKeys` / `writableResourceKeys` thresholds, and the
  request-scoped `runCached`.

## Dependencies

- `tom_core_kernel` — `TomPrincipal`, `TomClientJwtToken`, `TomWorker`,
  `TomExecutor`, `TomException`, `TomAuthState`, `TomResourceRoleRegistry`,
  `TomAccessControlInformation`, `tomReflector`, and the logging helpers.
- The object-persistence module — the mapping annotations (including
  `@TomDbScope`), `TomSqlDatasourceRepository` for the record stores, and the
  `TomResourceScopeSource` hook / `TomDataScope.runUnscoped` bypass the row
  scope plugs into.
- The datasources module — the `TomDbType` boxes the record columns declare.
