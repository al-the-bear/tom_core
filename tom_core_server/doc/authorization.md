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
| `TomAuthorizationCache` | class | The main-isolate cache: `getPrincipal` / `storePrincipal` keyed by JWT token string, plus the eviction sweep's lifecycle |
| `TomAuthorizationCacheEntry` | class | One cached principal paired with its expiry (`deletionTime`) |
| `TomAuthorizationCacheException` | class | Thrown when a cached entry has expired, or when a token's `validUntil` claim is unreadable so nothing was cached |
| `TomAuthorizationCacheStoreMessage` | class | Cross-isolate command: store a principal in the main isolate |
| `TomAuthorizationCacheRetrieveMessage` | class | Cross-isolate command: read a principal from the main isolate |
| `TomAuthorizationCacheExecutor` | class | Services the two messages in the main isolate |
| `TomPrincipalResourceGrant` | class | One `(principalId, resourceKey, role)` row — the role a principal holds on a resource (C-5) |
| `PrincipalResourceGrantStore` | abstract class | The read seam over those rows (repository-backed at boot, in-memory under test) |
| `RepositoryPrincipalResourceGrantStore` | class | The seam wired at boot: reads a principal's grant rows through a repository over the `main` datasource |
| `InMemoryPrincipalResourceGrantStore` | class | The seam under test: seeded rows filtered by principal, with no connection and no reflection |
| `TomPrincipalResourceRoleResolver` | class | Folds a principal's grants into a `resourceKey → role` map, strongest role winning |
| `TomDelegationMode` | enum | The three ways roles are lent — `share`, `absence`, `intentional` |
| `TomPrincipalDelegation` | class | One delegation row: A lends roles to B in `share` / `absence` / `intentional` mode (C-6) |
| `PrincipalDelegationStore` | abstract class | The read seam over the delegations targeting one delegate and in force at one instant |
| `RepositoryPrincipalDelegationStore` | class | The seam wired at boot: pushes the delegate, the `revoked` flag and both window bounds into one query |
| `InMemoryPrincipalDelegationStore` | class | The seam under test: seeded rows under the same delegate and window filters, so a test sees what the database would return |
| `TomDelegationResolver` | class | Resolves *effective* roles — direct grants folded with the delegations active now |
| `TomResourceGrant` | class | Grades a `(role, resourceKey)` pair with a `TomAuthState` |
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

// A cache hit wins; a miss falls back to callPrincipal; an *expired* entry
// resolves to no principal at all.
var principal = await _resolveRequestPrincipal(clientToken, callPrincipal);
```

The authorization layer that resolves a principal calls
`TomAuthorizationCache.storePrincipal(token, principal)` once, so subsequent
requests bearing the same token short-circuit straight to the cached value.

### An expired entry resolves to no principal

The third answer is the one worth stating, because it is neither of the other
two. `getPrincipal` reports an expired entry by throwing (see
[Lifetime and Expiry](#lifetime-and-expiry)), and the middleware catches that,
logs it, and resolves the request's principal to `null` — the same answer a
request bearing no credentials gets.

It does **not** fall back to `callPrincipal`, even though one is sitting right
there. An entry's expiry *is* the token's `validUntil`, so an expired entry
means this token has expired; `TomBearerAuthentication.convertTokenPayloadToPrincipal`
performs no expiry check and would rebuild the dead session as authenticated.
Falling back would make the cache's presence decide whether an expired token is
honoured, in the dangerous direction.

Nor does the middleware answer 401 itself. An unauthenticated request is a
legitimate thing for this pipeline to carry: a protected endpoint refuses it
through the ordinary `enforceAccess` path, while a refresh or re-login endpoint
stays reachable — and still receives the token itself from the request zone,
which is the only thing left identifying who is asking.

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
cached principal expires together with the token that authorized it.

The entry has no default expiry, and cannot be given one later: both
constructor arguments are required and both fields are `final`. An entry's
lifetime is the token's, so any instant the class invented on a caller's behalf
would be an instant no token granted — and it would apply precisely to the
caller who had no token expiry to hand. This is the same rule that makes
`storePrincipal` refuse a token whose `validUntil` it cannot read, seen from
the other side.

Expiry is enforced two ways:

- **Lazily on read** — `getPrincipal` throws
  `TomAuthorizationCacheException` if a matching entry is found but already
  past its `deletionTime`. The distinct exception type lets the caller catch it
  specifically and treat it as a prompt to re-authorize (a true cache *miss*,
  by contrast, simply returns `null`). The rejecting read **removes the entry**
  as well: it has the map in hand and has just established the entry is dead,
  so the expiry is reported once and a second read of the same token is an
  ordinary miss.
- **Eagerly on a sweep** — a periodic timer walks the map once an hour and
  removes entries whose `deletionTime` has passed, so stale principals do not
  accumulate.

Between them the two cover the whole map: the read drops the dead tokens
somebody asks about, the sweep drops the ones nobody does. The map's size
therefore tracks the number of live sessions rather than the number of logins
per sweep interval.

The sweep starts with the first principal `storePrincipal` caches: it exists to
bound the map, so it runs from the moment there is something in it to bound and
a process that only ever reads the cache never starts a timer at all. It is a
periodic timer, so it holds the isolate open until it is stopped — a server
therefore registers the cache for shutdown, and gets the cached principals
dropped with it:

```dart
tomShutdownCleanup.addDisposable(TomAuthorizationCache.instance);
```

`stopEviction()` cancels the sweep on its own (entries stay, and expired ones
are still rejected on read); `startEviction(interval:)` starts one at a chosen
interval, replacing any that is running — for a server that wants something
other than the hourly default, and for tests that cannot wait an hour.
`TomAuthorizationCache.instance` is the only way to reach a cache — the
constructor is private, because every instance would own a sweep and a second
one's sweep would walk a map the static API never writes to.

The sweep runs in **`Zone.root`**, whichever path started it. That matters
because the caller that stores the first principal is normally a request, and
the endpoint pipeline runs each request in its own zone to carry the principal:
a timer created with `Zone.current` would leave process-lifetime work answering
to one request's error handling and teardown, and would let whichever caller
arrived first decide the zone. Root rather than a zone the server installs at
boot, because the sweep wants nothing a zone can give it — it walks a plain map,
needs no principal and no transaction, and a failure in it belongs to the
process rather than to any request. Nothing therefore has to call
`startEviction` at start-up to get the zone right.

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

The window and the kill-switch are applied **where the rows are**. The store seam
is `activeDelegationsForDelegate(delegateId, at)`: it takes the instant, and the
repository-backed store compiles it into the query — `revoked = false` plus both
bounds, each written to admit `NULL` (`valid_from IS NULL OR valid_from <= :at`),
because SQL answers `NULL <= :at` with *unknown* and a bare comparison would drop
every open-ended delegation. This matters because revocation is a flag rather
than a delete: a delegate accumulates dead rows for the lifetime of the
deployment, and reading them back to discard them in Dart would make every
request pay for that history. The delegate index covers `(delegate_id, revoked)`
for the same reason. `isActiveAt` remains the in-memory statement of the same
predicate — what the in-memory store filters on, and what the tests share.

Both bounds are **instants**, not wall clocks. They decide whether a delegate
holds a role, so a bound read as the local time of whichever node happened to
load the row would mean a different moment on each node of a cluster — and the
node that is wrong is wrong in the direction of honouring a delegation outside
the window its owner set. The columns are `DATETIME(6)` and the datasource
applies the framework's instant convention (`datasources/sql_instant.dart`) to
them: bound as UTC text, read back UTC-flagged. Nothing is asked of the caller
beyond passing a `DateTime`. The `(6)` matters for the same reason the UTC does
— a plain `DATETIME` rounds each bound to the second, putting the edge of a
security window up to half a second from the one that was set.

Resolving a delegate costs one grant read per **distinct delegator**, not one per
delegation row. The distinction is worth stating because lending several
resources means one row each: a colleague who shares four projects with you is
four rows naming one delegator, and their grants are read once. The reuse is
scoped to the single `resolveDelegatedRoles` call — it declines to ask the same
question twice within one resolution, and holds nothing afterwards, so liveness
is untouched. Amortising across a whole request is `runCached`'s job, below.

`TomResourceGrant` is the orthogonal axis: it grades a `(role, resourceKey)`
pair with a `TomAuthState` (`none` / `disabled` / `read` / `full`), stored by
name through `TomAuthStateCodec` — a lenient codec, in that an unknown or `null`
stored value resolves to `none`, the closed default.
`TomGradedAccessControlInformation` resolves the effective grade for a key,
using an explicit grade where one exists and otherwise bridging the kernel's
legacy binary `resourceKeys` list (present → `full`, absent → `none`), so a
deployment that has only the binary list keeps resolving every key to `full`
or `none`.

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

- **`TomAuthorizationCache`** — the cache itself. Public surface is
  `getPrincipal` / `storePrincipal` plus the eviction lifecycle
  (`startEviction`, `stopEviction`, `isEvicting`, and `dispose` via
  `instance`); the backing map is private, and so is the constructor.
- **`TomAuthorizationCacheEntry`** — value object pairing the
  `authorizedPrincipal` with its `deletionTime`.
- **`TomAuthorizationCacheException`** — signals an entry that was found
  expired (and dropped by the read that found it), or a token whose
  `validUntil` claim could not be read.
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
  seam (`RepositoryPrincipalDelegationStore` at boot,
  `InMemoryPrincipalDelegationStore` under test) and the resolver that produces
  a principal's effective roles.
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
