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
  - [An expired entry resolves to no principal](#an-expired-entry-resolves-to-no-principal)
  - [The cache does not decide access](#the-cache-does-not-decide-access)
- [Isolate Model](#isolate-model)
- [Lifetime and Expiry](#lifetime-and-expiry)
- [Revoking a Principal](#revoking-a-principal)
  - [Revocation per tenant](#revocation-per-tenant)
- [Grants, Grades and Delegations](#grants-grades-and-delegations)
- [The Grant-Driven Row Scope](#the-grant-driven-row-scope)
  - [The grades are the design](#the-grades-are-the-design)
  - [Resolution is live](#resolution-is-live)
  - [Two guards worth knowing](#two-guards-worth-knowing)
  - [When an external authority keeps the grants](#when-an-external-authority-keeps-the-grants)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomAuthorizationCache` | class | The main-isolate cache: `getPrincipal` / `storePrincipal` keyed by JWT token string, the per-user revocations (`revokeLocally`, `isRevoked`), plus the eviction sweep's lifecycle |
| `TomAuthorizationCacheEntry` | class | One cached principal paired with its expiry (`deletionTime`) |
| `TomAuthorizationCacheException` | class | Thrown when a cached entry has expired, when the token was issued before its user's grants were revoked, when a token's `exp` claim is unreadable so nothing was cached, or when a worker forwards to a creator with no cache executor registered |
| `TomAuthorizationCacheStoreMessage` | class | Cross-isolate command: store a principal in the main isolate |
| `TomAuthorizationCacheRetrieveMessage` | class | Cross-isolate command: read a principal from the main isolate |
| `TomAuthorizationCacheExecutor` | class | Services the two messages in the main isolate |
| `TomPrincipalResourceGrant` | class | One `(principalId, resourceKey, role)` row — the role a principal holds on a resource (C-5); read from the primary, never a read replica (`@TomPrimaryReads`) |
| `PrincipalResourceGrantStore` | abstract class | The read seam over those rows (repository-backed at boot, in-memory under test) |
| `RepositoryPrincipalResourceGrantStore` | class | The seam wired at boot: reads a principal's grant rows through a repository over the `main` datasource |
| `InMemoryPrincipalResourceGrantStore` | class | The seam under test: seeded rows filtered by principal, with no connection and no reflection |
| `TomPrincipalResourceRoleResolver` | class | Folds a principal's grants into a `resourceKey → role` map, strongest role winning |
| `TomDelegationMode` | enum | The three ways roles are lent — `share`, `absence`, `intentional` |
| `TomPrincipalDelegation` | class | One delegation row: A lends roles to B in `share` / `absence` / `intentional` mode (C-6); read from the primary, never a read replica (`@TomPrimaryReads`) |
| `PrincipalDelegationStore` | abstract class | The read seam over the delegations targeting one delegate and in force at one instant |
| `RepositoryPrincipalDelegationStore` | class | The seam wired at boot: pushes the delegate, the `revoked` flag and both window bounds into one query |
| `InMemoryPrincipalDelegationStore` | class | The seam under test: seeded rows under the same delegate and window filters, so a test sees what the database would return |
| `TomDelegationResolver` | class | Resolves *effective* roles — direct grants folded with the delegations active now |
| `TomResourceGrant` | class | Grades a `(role, resourceKey)` pair with a `TomAuthState`; read from the primary, never a read replica (`@TomPrimaryReads`) |
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
var (
  TomPrincipal? callPrincipal,
  TomClientJwtToken? clientToken,
  TomCredentialOutcome outcome,
) = extractAuthentication(request);

// A cache hit wins; a miss falls back to callPrincipal; an *expired* entry or
// a *revoked* token resolves to no principal at all.
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

A revoked token takes the same path: `getPrincipal` refuses it with
`authorization.cache.revoked_principal`, and the request proceeds
unauthenticated — see [Revoking a Principal](#revoking-a-principal).

It does **not** fall back to `callPrincipal`, even though one is sitting right
there. An entry's expiry *is* the token's `exp`, so an expired entry
means this token has expired, and `callPrincipal` is `null` for it already:
`TomBearerAuthentication.convertTokenPayloadToPrincipal` builds no principal from
a token that is not live, so the answer for an expired token is the same whether
or not the cache holds it.

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
`storePrincipal`, this is set from the token's standard `exp` payload claim, so a
cached principal expires together with the token that authorized it.

The entry has no default expiry, and cannot be given one later: both
constructor arguments are required and both fields are `final`. An entry's
lifetime is the token's, so any instant the class invented on a caller's behalf
would be an instant no token granted — and it would apply precisely to the
caller who had no token expiry to hand. This is the same rule that makes
`storePrincipal` refuse a token whose `exp` it cannot read, seen from
the other side. That refusal is `authorization.cache.missing_expiry` when the
claim is absent or is not an integer, and `authorization.cache.invalid_expiry`
when it is an integer no clock can represent; both name the claim, the value
found and an excerpt of the token, and neither leaves anything in the map.

**Why `exp` and not `validUntil`.** A `TomServerJwtToken` writes both, and two
claims naming one instant is one too many for a cache to choose between. `exp`
is the registered claim a JWT verifier already enforces, so reading anything
else would let the cache's notion of expiry drift from the one the rest of the
system applies. And it is unambiguous: an ISO string without an offset means
whatever the *reader's* zone says it means, so a token minted in one zone and
cached by a server in another was out by the difference between them.
`validUntil` remains in the payload as the readable form of the same instant —
`TomServerJwtToken` derives both from one clock read, truncated to the whole
seconds `exp` is encoded in, so the pair cannot drift.

The consequence to know is that an entry's lifetime has **one-second
resolution**: `exp` carries seconds, so a token good for 300 ms cannot be
expressed and reads as already expired.

**A worker whose creator has no executor** is refused rather than served.
`getPrincipal` and `storePrincipal` forward to the main isolate, and a creator
that answers `TomExecutor.notHandled` has no `TomAuthorizationCacheExecutor`
registered — a start-up mistake, not a cache outcome. Both raise
`authorization.cache.executor_not_registered` (`clientThrow: false`, since it
names this deployment's configuration and not the caller's request). Read as a
miss it would be invisible: every lookup would re-resolve its principal for
ever, and every store would report a success it never performed.

Expiry is enforced two ways:

- **Lazily on read** — `getPrincipal` throws
  `TomAuthorizationCacheException` (`authorization.cache.expired_principal`) if
  a matching entry is found but already
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

## Revoking a Principal

A token carries the grants it was issued with until it expires, and so does the
principal cached for it. When a user's grants change — a role removed, a
resource grant withdrawn, an account disabled — the server **revokes the
principal**: every token the user holds that was issued at or before the
revocation stops yielding a principal, the client re-authorizes, and the new
token carries the current grants.

```dart
await TomCacheInvalidator.revokePrincipal('alice');
```

`TomCacheInvalidator.revokePrincipal` lives in the [cache](cache.md) module,
because a revocation has to reach every node: it applies the revocation here
and publishes it through the installed invalidation channel, and every other
node applies it on delivery. How quickly is the channel's staleness bound —
zero with the default single-process channel, the poll interval (default two
seconds) plus one query with `TomSqlInvalidationChannel`, the broker's delivery
time — stated as one second by default — with `TomBusInvalidationChannel`. See
the cache guide's "Cross-Node Invalidation".

On each node the revocation lands in `TomAuthorizationCache.revokeLocally(username,
at)`, which records the instant per username — of two revocations of one user
the later is kept — and drops every principal cached for that user. It is the
process-local half and is called on the main isolate, where the cache lives;
application code calls the invalidator instead.

**What counts as revoked.** `TomAuthorizationCache.isRevoked(token)` compares
the token's `iat` claim — falling back to `nbf` — with its user's revocation
instant, in whole seconds, the precision of `iat`:

| The token | Is |
| --------- | -- |
| issued in a second before the revocation's | revoked |
| issued within the revocation's second | revoked — the safe direction to round: a client re-authorizing in that second is refused once and succeeds a second later |
| issued in a later second | served |
| carrying neither `iat` nor `nbf` | revoked — it cannot show it was issued afterwards |
| carrying no `username` claim | never revoked by user |

`TomAuthorizationCache.revokedAt(username)` answers the recorded instant, or
`null`.

**A revoked token is refused whether or not anything is cached for it.**
`getPrincipal` checks `isRevoked` first and throws
`authorization.cache.revoked_principal`, dropping any entry cached under the
token. Refusing only the cached entry would not be enough: the token's own
claims still list the revoked grants, and the request pipeline would fall back
to the principal they describe. The server's authentication middleware treats
the refusal exactly like an expired entry — logged at info, and the request
proceeds unauthenticated.

**How long a revocation is remembered.** `TomAuthorizationCache.revocationRetention`
— one day by default, and settable — is how long a revocation is kept; the
eviction sweep forgets older ones, and `dispose` forgets them all. A token that
outlives the retention after a revocation is served with the grants it was
issued with, so the retention must be at least the longest lifetime of a token
the deployment issues. `TomSqlInvalidationChannel` keeps its log rows, and
looks back on start-up, over the same span by default.

### Revocation per tenant

In a multi-tenant deployment (see [tenancy.md](tenancy.md)) two tenants may
each have an account called `alice`, and they are two people. A revocation is
therefore recorded under the **tenant-qualified** name —
`TomTenantContext.qualify(username, tenant)`, which is `tenant:<id>/<name>`, or
the bare name for an account of no tenant:

- `TomCacheInvalidator.revokePrincipal('alice')` raised inside a tenant's
  context revokes that tenant's `alice` only; raised outside every tenant it
  revokes the `alice` of no tenant. Revoking a tenant's account from a
  background task runs inside the tenant — `TomTenancy.runFor(tenant, …)`.
- `TomAuthorizationCache.revokeLocally(username, at)` receives the name already
  qualified, and drops the cached principals whose qualified name matches.
- `TomAuthorizationCache.isRevoked(token)` qualifies the token's `username`
  claim by its `tenant` claim before looking the revocation up, so a token is
  compared against its own tenant's revocations only.
- `revokedAt` is asked with the qualified name:
  `TomAuthorizationCache.revokedAt(TomTenantContext.qualify('alice', 'acme'))`.

SCIM deprovisioning revokes through `revokePrincipal` from inside the request
that deprovisioned the account, so it revokes in the tenant that request
resolved to.

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
the resolver stays independent of any particular role vocabulary — except on the
key of a declared item type (`<type>:<id>`), where the role is one of the type's
ordered levels and the type's order decides, so `comment` beats `view` although
both grade `read` (kernel `TomItemTypeRegistry`, `TomResourceRoleRegistry.strongerOn`;
see the kernel's [security guide](../../tom_core_kernel/doc/security/security.md#item-permission-levels)).

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

On the key of a declared item type the role is a **level** of the type and
grades as the type maps it (`TomResourceRoleRegistry.stateOn`): with the standard
levels, `view` and `comment` admit a row to queries, `edit` and `manage` to
writes as well, and a level the type does not declare grants nothing. The
scope matches keys exactly — a level held on a pattern (`document:finance/*`)
counts in the kernel's local checks but names no row here.

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

Two requests never share a cache. Each call builds a fresh map and installs it
on a child zone of its own, so concurrently-served requests hold sibling zones
with nothing in common — the isolation is by construction, not by discipline.
Resolution stays live *across* requests, which is where liveness actually
matters.

The zone bounds *reachability*, not lifetime, and that is the part the caller
has to hold. Anything the body schedules without awaiting — a `Future`, a
`Timer`, a stream subscription — inherits the zone and reads the same cache
whenever it later runs, however long after the request returned. Such a
continuation resolves grants against a snapshot taken during the request, so a
revocation that lands afterwards stays invisible to it for as long as it lives.
The cache is request-scoped only if the request is the whole of what runs in the
zone: start background work outside the body, or let it resolve its own
grants.

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
against a live database — MariaDB or PostgreSQL.

### When an external authority keeps the grants

`TomResourceDataScope` reads grants the application stores itself. When another
service keeps them — Tom UAM keeps who may see which of an application's items,
because those authorizations reach users through groups and delegations and are
shared by every application of a tenant — the same `resource` scope kind is fed
from that service instead: a different `TomResourceScopeSource` is installed,
and nothing else changes. The scoped entity still carries a resource-key column,
holding item keys (`<type>:<id>`), and reads and writes are still graded `read`
and `full`.

The source the framework ships for this is `TomItemAuthorityScopeSource` in the
item_authorization module. It asks the authority, page by page, for the items a
principal reaches at each item type's weakest level granting the grade, caches
the lists, and drops them when the authority reports a change. The pattern —
ask, cache, drop on the authority's report, age out what no report reached — and
its limits are in [item_authorization.md](item_authorization.md#the-external-authority-pattern).

## Not Yet Implemented

- **An entry's lifetime has one-second resolution.** `exp` is encoded in whole
  seconds, so a token good for 300 ms cannot be expressed and reads as already
  expired.
  <!-- pinned: test/documented_limitations_test.dart › a token good for less than a second cannot be cached as live -->
- **The graded model has four states and no fifth.**
  `TomAuthState.none`/`disabled`/`read`/`full` is the whole vocabulary, and
  `TomResourceDataScope` maps it onto rows accordingly: readable at `read` or
  wider, writable only at `full`. There is no append-only, no delete-but-not-edit
  and no per-operation grade. An application that needs a finer vocabulary for
  its items declares it as item permission levels (kernel `TomItemType`), checks
  them with `TomItemPermissions.allows`, and leaves the grades to presentation
  and the row scope.
  <!-- pinned: test/documented_limitations_test.dart › the graded model has exactly four states -->

## Verification

`test/authorization_test.dart` covers the per-token principal cache on both
sides of the isolate boundary: storing and reading a resolved principal in the
main isolate, the miss, the expiry — and the removal that read performs, which
turns the next read of the same dead token back into an ordinary miss — the
refusal to cache a token whose `exp` claim is missing or unreadable, the eviction
sweep that bounds the map, the cross-isolate command objects, and
`TomAuthorizationCacheExecutor` servicing them. The worker-isolate cases are
asserted through the same API the main-isolate ones use, which is the claim
worth making: a hit, a miss and an expiry are reported identically on either
side, so a caller cannot tell where it runs.

Revocation is covered by `test/cache_invalidation_test.dart` — the cached
principal dropped, a revoked token refused with nothing cached, a token issued
after the revocation served, a token issued within the revocation's second and
one carrying no issue instant both refused, other users untouched, the later of
two revocations kept, and the retention sweep — and
across two nodes over MariaDB or PostgreSQL by `test/cache_invalidation_db_test.dart`.
`test/server_test.dart` asserts that the middleware serves a revoked token's
request unauthenticated.

The graded model and the grant-driven row scope are covered by suites named
after the types rather than the module — `graded_authorization_test.dart`,
`principal_resource_grant_test.dart`, `principal_delegation_test.dart`,
`resource_data_scope_test.dart` and its `_db` sibling — and are described in
[Grants, Grades and Delegations](#grants-grades-and-delegations) and
[The Grant-Driven Row Scope](#the-grant-driven-row-scope).

```bash
dart run example/authorization/authorization_example.dart
dart run example/authorization/resource_data_scope_example.dart
```

Both examples check every step through the package's throwing `check` helper
and are run by `test/examples_test.dart`. The second runs connection-free by
printing the predicate the repository would AND into its `WHERE`, which is the
whole of what the scope contributes.

## Core Components

- **`TomAuthorizationCache`** — the cache itself. Public surface is
  `getPrincipal` / `storePrincipal`, the revocations (`revokeLocally`,
  `revokedAt`, `isRevoked`, `revocationRetention`) and the eviction lifecycle
  (`startEviction`, `stopEviction`, `isEvicting`, and `dispose` via
  `instance`); the backing maps are private, and so is the constructor.
- **`TomAuthorizationCacheEntry`** — value object pairing the
  `authorizedPrincipal` with its `deletionTime`.
- **`TomAuthorizationCacheException`** — signals an entry that was found
  expired (and dropped by the read that found it), a token issued before its
  user's last revocation, or a token whose `exp` claim could not be read.
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
- Both rows declare their principal columns data subjects (`@TomDataSubject`:
  the grant's `principalId`, the delegation's `delegatorId` and `delegateId`),
  so registering the repositories their stores are built over with `TomPrivacy`
  has a principal's grants and delegations deleted when they are erased and
  included in their subject-access export — see
  [privacy.md](privacy.md#framework-entities-that-declare-subjects).
- **`TomResourceGrant` + `TomAuthStateCodec` +
  `TomGradedAccessControlInformation`** — the graded `(role, resourceKey)`
  record, its stored representation, and the resolved graded view.
- **`TomResourceDataScope`** — the `TomResourceScopeSource` behind the built-in
  `resource` row scope: `install` / `uninstall` / `isInstalled`, the
  `readableResourceKeys` / `writableResourceKeys` thresholds, and the
  request-scoped `runCached`.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `authorization_cache.dart`, `resource_data_scope.dart` | `Future`, `Timer`, `Zone` |
| `tom_core_kernel` | package | every file | `TomPrincipal`, `TomClientJwtToken`, `TomWorker`, `TomExecutor`, `TomException`, `TomAuthState`, `TomResourceRoleRegistry`, `TomAccessControlInformation`, `tomReflector`, and the logging helpers |
| [datasources](datasources.md) | module | `graded_authorization.dart`, `principal_delegation.dart`, `principal_resource_grant.dart` | `TomDbType` and `TomDbString`, which the access-level codec converts between and its column declares as `columnType:`; `TomPrimaryReads`, which keeps the reads of grants and delegations on the primary |
| [little_things](little_things.md) | module | `authorization_cache.dart` | `TomServerException` |
| [object_persistence](object_persistence.md) | module | `graded_authorization.dart`, `principal_delegation.dart`, `principal_resource_grant.dart`, `resource_data_scope.dart` | the mapping annotations (including `@TomDbScope`), `TomSqlDatasourceRepository` for the record stores, and the `TomResourceScopeSource` hook / `TomDataScope.runUnscoped` bypass the row scope plugs into |
| [privacy](privacy.md) | module | `principal_delegation.dart`, `principal_resource_grant.dart` | `TomDataSubject`, which declares the principal columns of `TomPrincipalResourceGrant` and `TomPrincipalDelegation` to erasure and export |
