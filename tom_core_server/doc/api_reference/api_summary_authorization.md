# Tom Core Server API Reference: Authorization Module

Server-side authorization: the per-token principal cache, the four-state graded
authorization model, per-principal-per-resource role grants (C-5), delegation of
those roles (C-6), and the row scope that turns both into a `WHERE` clause.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomAuthorizationCacheException](#tomauthorizationcacheexception)
  - [TomAuthorizationCacheEntry](#tomauthorizationcacheentry)
  - [TomAuthorizationCache](#tomauthorizationcache)
  - [TomAuthorizationCacheStoreMessage](#tomauthorizationcachestoremessage)
  - [TomAuthorizationCacheRetrieveMessage](#tomauthorizationcacheretrievemessage)
  - [TomAuthorizationCacheExecutor](#tomauthorizationcacheexecutor)
  - [TomAuthStateCodec](#tomauthstatecodec)
  - [TomResourceGrant](#tomresourcegrant)
  - [TomGradedAccessControlInformation](#tomgradedaccesscontrolinformation)
  - [TomDelegationMode](#tomdelegationmode)
  - [TomPrincipalDelegation](#tomprincipaldelegation)
  - [PrincipalDelegationStore](#principaldelegationstore)
  - [TomDelegationResolver](#tomdelegationresolver)
  - [RepositoryPrincipalDelegationStore](#repositoryprincipaldelegationstore)
  - [InMemoryPrincipalDelegationStore](#inmemoryprincipaldelegationstore)
  - [TomPrincipalResourceGrant](#tomprincipalresourcegrant)
  - [PrincipalResourceGrantStore](#principalresourcegrantstore)
  - [TomPrincipalResourceRoleResolver](#tomprincipalresourceroleresolver)
  - [RepositoryPrincipalResourceGrantStore](#repositoryprincipalresourcegrantstore)
  - [InMemoryPrincipalResourceGrantStore](#inmemoryprincipalresourcegrantstore)
  - [TomResourceDataScope](#tomresourcedatascope)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tomserver/authorization/authorization_cache.dart`,
`lib/src/tomserver/authorization/graded_authorization.dart`,
`lib/src/tomserver/authorization/principal_delegation.dart`,
`lib/src/tomserver/authorization/principal_resource_grant.dart`,
`lib/src/tomserver/authorization/resource_data_scope.dart`.

`authorization_cache.dart` caches the `TomPrincipal` resolved for an
authentication token so the authorization lookup runs once per token; the cache
lives in the main isolate and worker isolates forward store/retrieve commands to
it via cross-isolate messages serviced by `TomAuthorizationCacheExecutor`. The
forwarding is transparent: a hit, a miss and an expiry are reported the same way
on either side of the isolate boundary, so a caller cannot tell where it runs.

`graded_authorization.dart` adds the four-state authorization model
(`TomAuthState.none`/`disabled`/`read`/`full`): `TomResourceGrant` persists a
per-`(role, resourceKey)` grade, `TomAuthStateCodec` round-trips the state
to/from its stored column, and `TomGradedAccessControlInformation` resolves the
effective state for a key, falling back to the kernel's legacy binary list.

`principal_resource_grant.dart` (C-5) stores which role a principal holds on a
resource: `TomPrincipalResourceGrant` rows, a `PrincipalResourceGrantStore`
seam, and `TomPrincipalResourceRoleResolver` folding grants into a
`resourceKey → roleName` map. `principal_delegation.dart` (C-6) lends those
roles from one principal to another via `TomPrincipalDelegation` rows resolved by
`TomDelegationResolver`, in `share`/`absence`/`intentional` modes.

`resource_data_scope.dart` is where those two models stop being advisory:
`TomResourceDataScope` implements `TomResourceScopeSource` — declared by this
package's `object_persistence` module, which is the inversion that lets
persistence offer a grant-driven row scope without depending on this layer — so an
entity column annotated `@TomDbScope(scope: TomDbScope.resourceScope)` is
filtered by the keys the caller holds a grant on — readable at
`TomAuthState.read` or wider, writable only at `TomAuthState.full`. While no
source is installed the scope denies every row.

## Class Hierarchy

```
TomServerException  (little_things)
    └── TomAuthorizationCacheException

TomExecutor  (kernel)
    └── TomAuthorizationCacheExecutor

PrincipalDelegationStore  (abstract)
    ├── RepositoryPrincipalDelegationStore   (implements)
    └── InMemoryPrincipalDelegationStore     (implements)

PrincipalResourceGrantStore  (abstract)
    ├── RepositoryPrincipalResourceGrantStore  (implements)
    └── InMemoryPrincipalResourceGrantStore    (implements)

TomResourceScopeSource  (object_persistence, abstract)
    └── TomResourceDataScope                   (implements)

Standalone: TomAuthorizationCacheEntry, TomAuthorizationCache,
TomAuthorizationCacheStoreMessage, TomAuthorizationCacheRetrieveMessage,
TomAuthStateCodec, TomResourceGrant (@tomReflector),
TomGradedAccessControlInformation, TomPrincipalDelegation (@tomReflector),
TomDelegationResolver, TomPrincipalResourceGrant (@tomReflector),
TomPrincipalResourceRoleResolver

Enum: TomDelegationMode
```

## Classes

### TomAuthorizationCacheException

Raised by `TomAuthorizationCache` when a principal cannot be returned or cached.
Three conditions carry three keys, because they call for three different
responses.

- **Extends:** `TomServerException`

#### Error keys

| Key | Meaning |
| --- | ------- |
| `authorization.cache.expired_principal` | A matching entry existed but its expiry had passed; it has been dropped, so the next read of the same token is a miss. The client should re-authorize. |
| `authorization.cache.missing_expiry` | The token carries no readable `exp` claim -- absent, or not an integer -- so nothing was cached. |
| `authorization.cache.invalid_expiry` | The token's `exp` claim is an integer no clock can represent, so nothing was cached. |
| `authorization.cache.executor_not_registered` | A worker forwarded to a creator where nothing claimed the command, which means `TomAuthorizationCacheExecutor` was never registered. |

The two `exp` keys report a malformed token rather than anything about
the principal. Each carries three exception parameters -- the name of the claim,
the value found in it, and an excerpt of the token -- so the diagnosis does not
depend on the stack.

#### Constructors

```dart
TomAuthorizationCacheException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
  bool clientThrow = true,
})
```

`clientThrow` defaults to `true`, which is the opposite of most of the package
and is the point: all three conditions above are about the token the caller
presented, and two of them tell the caller what to do next. An answer the
caller cannot read leaves it retrying a token that will never be accepted.

### TomAuthorizationCacheEntry

A single cache entry: the authorized `TomPrincipal` paired with the deletion
time at which it should be considered stale and evicted. Both are required and
neither is settable afterwards -- an entry's lifetime is the lifetime of the
token its principal was authorized under, so there is no instant the class could
default to that would be right, and no later one it should accept.

#### Constructors

```dart
TomAuthorizationCacheEntry(TomPrincipal authorizedPrincipal, DateTime deletionTime)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `deletionTime` | `final DateTime` | Instant after which the entry is expired and may be evicted; normally the `exp` of the token the principal was authorized under. |
| `authorizedPrincipal` | `final TomPrincipal` | The principal resolved for the associated authentication token. |

### TomAuthorizationCache

Caches the `TomPrincipal` resolved for an authentication token, keyed by the JWT
token string. Lives in the main isolate; worker-isolate calls forward to the
creator isolate. A periodic sweep evicts expired entries, started by the first
stored principal and stoppable through `stopEviction` or `dispose`; a read that
meets an expired entry first rejects it and drops it in the same breath, so the
map holds about one entry per live session rather than one per login per sweep
interval. The sweep's
timer is created in `Zone.root`, not in the caller's zone, so the request that
happens to store first does not end up owning process-lifetime work.

Implements `TomDisposable`. The constructor is private: `instance` is the single
cache the static API uses, exposed so a server can register it for shutdown
(`tomShutdownCleanup.addDisposable(TomAuthorizationCache.instance)`). Every
instance would own a sweep, and a second one's sweep would walk a map nothing
can populate, so there is exactly one.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `instance` | `TomAuthorizationCache` | The one cache the static API reads and writes; register it with `tomShutdownCleanup` for orderly shutdown. |
| `evictionInterval` | `Duration` | How often the sweep runs when no other interval is asked for -- one hour. |
| `isEvicting` | `bool` | Whether a sweep is currently running. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getPrincipal` | `static Future<TomPrincipal?> getPrincipal(TomClientJwtToken authenticationToken)` | Returns the cached principal, or `null` on a cache miss. Throws `TomAuthorizationCacheException` when the entry has expired, and removes that entry as part of the same read -- so the expiry is reported once and a second read of the same token is an ordinary miss. Called from a worker isolate the lookup is forwarded to the main isolate, and all three answers survive the trip -- a hit returns the principal, a miss returns `null`, an expiry rethrows -- so callers need no isolate-dependent handling. |
| `storePrincipal` | `static Future<void> storePrincipal(TomClientJwtToken authenticationToken, TomPrincipal authorizedPrincipal)` | Stores the principal under the token, using the token's standard `exp` claim as expiry, and starts the eviction sweep if it is not already running. Throws `TomAuthorizationCacheException` (`missing_expiry` / `invalid_expiry`) when that claim is absent, is not an integer, or is an integer no clock can represent -- there is no fallback lifetime, because an invented one would keep a principal cached past the expiry of the token authorizing it. Nothing is cached in that case and the caller keeps resolving the principal per request. The future carries completion and failure only: a store either happens or throws, so there is nothing to branch on. |
| `startEviction` | `static void startEviction({Duration interval = evictionInterval})` | Starts the sweep at `interval`, replacing any sweep already running -- so the postcondition "a sweep is running at this interval" holds whenever it returns. Rarely needed: a store starts one at the hourly default. For a server that wants a different interval, and for tests that cannot wait an hour. Not needed to control the sweep's zone: it is created in `Zone.root` whichever path starts it. |
| `stopEviction` | `static void stopEviction()` | Cancels the sweep; a no-op when none is running. Cached entries are left in place -- stopping the sweep suspends the bounding of the map, it does not invalidate its contents. Reads still reject expired entries and still drop the ones they reject, so a stopped cache sheds the tokens anyone asks about, just not the ones nobody does. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `dispose` | `void dispose()` | *(override)* Stops the sweep and drops every cached principal. Synchronous, as `TomDisposable` requires. |

### TomAuthorizationCacheStoreMessage

Cross-isolate command asking the main isolate to store a principal for a token.
Handled by `TomAuthorizationCacheExecutor`.

#### Constructors

```dart
TomAuthorizationCacheStoreMessage(
  TomClientJwtToken authenticationToken,
  TomPrincipal authorizedPrincipal,
)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `authenticationToken` | `TomClientJwtToken` | The token the principal is stored under. |
| `authorizedPrincipal` | `TomPrincipal` | The principal to store. |

### TomAuthorizationCacheRetrieveMessage

Cross-isolate command asking the main isolate to return the cached principal for
a token. Handled by `TomAuthorizationCacheExecutor`.

#### Constructors

```dart
TomAuthorizationCacheRetrieveMessage(TomClientJwtToken authenticationToken)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `authenticationToken` | `TomClientJwtToken` | The token whose cached principal is requested. |

### TomAuthorizationCacheExecutor

Runs in the main isolate and services the store/retrieve commands forwarded from
worker isolates, delegating to `TomAuthorizationCache`. Returns
`TomExecutor.noResult` for any other command.

- **Extends:** `TomExecutor`

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `execute` | `Object execute(Object command)` | *(override)* Dispatches store/retrieve messages to `TomAuthorizationCache`, returning the delegate's future rather than awaiting it -- so a creator-side failure (an expired entry on a retrieve, an unreadable `exp` on a store) reaches the asking worker as a throw. Returns `TomExecutor.noResult` otherwise. |

### TomAuthStateCodec

Round-trips a `TomAuthState` to and from the string value stored in a database
column, and bridges the legacy binary granted/denied model. All members are
static; the class is not instantiable (private const constructor).

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toStored` | `static String toStored(TomAuthState state)` | The canonical stored token for `state` (its `TomAuthState.name`). |
| `fromStored` | `static TomAuthState fromStored(String? stored, {TomAuthState orElse = TomAuthState.none})` | Parses `stored` back to a `TomAuthState`; a null/unrecognised value yields `orElse` rather than throwing. |
| `fromLegacyGranted` | `static TomAuthState fromLegacyGranted(bool granted)` | Bridges the legacy binary model: granted → `TomAuthState.full`, denied → `TomAuthState.none`. |
| `fromDbColumn` | `static TomAuthState fromDbColumn(TomDbType column)` | `TomDbColumn` read converter: a stored `TomDbString` column → `TomAuthState`. |
| `toDbColumn` | `static TomDbString toDbColumn(dynamic state)` | `TomDbColumn` write converter: a `TomAuthState` → the stored `TomDbString`. |

### TomResourceGrant

A persistable grant of a single `TomAuthState` to a `(roleName, resourceKey)`
pair — the storage row behind the four-state authorization model. Mapped to
`tom_resource_grant` and reflection-discoverable (`@tomReflector`,
`@TomDbTable`).

#### Constructors

```dart
TomResourceGrant({
  int id = -1,
  String roleName = '',
  String resourceKey = '',
  TomAuthState accessLevel = TomAuthState.none,
})
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `createTableSql` | `static const String` | The canonical DDL for the `tom_resource_grant` table. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `int` | Surrogate primary key (`-1` until persisted). |
| `roleName` | `String` | The role the grant applies to. |
| `resourceKey` | `String` | The resource key being graded. |
| `accessLevel` | `TomAuthState` | The graded access level for `(roleName, resourceKey)`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* `'TomResourceGrant(role, key -> level)'`. |

### TomGradedAccessControlInformation

A graded view over resource-key authorization that resolves the effective
`TomAuthState` for a key, from persisted `TomResourceGrant`s and an optional
binary fallback ACI.

#### Constructors

```dart
TomGradedAccessControlInformation({
  Map<String, TomAuthState>? grades,
  TomAccessControlInformation? binary,
})

factory TomGradedAccessControlInformation.fromGrants(
  Iterable<TomResourceGrant> grants, {
  TomAccessControlInformation? binary,
})
```

The `fromGrants` factory folds duplicate keys to the most permissive grade
(`TomAuthState.widen`).

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `grades` | `Map<String, TomAuthState>` | Unmodifiable view of the explicit per-key grades. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolveState` | `TomAuthState resolveState(String resourceKey)` | The effective state for the key: the explicit grade when present, otherwise the binary fallback. |
| `toGrants` | `List<TomResourceGrant> toGrants(String roleName)` | Materialises the explicit grades back into persistable grants for `roleName` (inverse of `fromGrants`). |

### TomDelegationMode

How a `TomPrincipalDelegation` lends the delegator's roles to the delegate.

- **Enum values:** `share`, `absence`, `intentional`

### TomPrincipalDelegation

A persistable delegation of a delegator's C-5 roles to a delegate — the storage
row behind share/absence/intentional delegation. Mapped to
`tom_principal_delegation` and reflection-discoverable (`@tomReflector`,
`@TomDbTable`).

#### Constructors

```dart
TomPrincipalDelegation({
  int id = -1,
  String delegatorId = '',
  String delegateId = '',
  String mode = '',
  String? resourceKey,
  String? role,
  DateTime? validFrom,
  DateTime? validTo,
  bool revoked = false,
})
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `createTableSql` | `static const String` | The canonical DDL for the `tom_principal_delegation` table; the delegate index covers `(delegate_id, revoked)` and the window columns are `DATETIME(6)`. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `int` | Surrogate primary key (`-1` until persisted). |
| `delegatorId` | `String` | The principal whose roles are lent (A, the delegator). |
| `delegateId` | `String` | The principal receiving the lent roles (B, the delegate). |
| `mode` | `String` | The delegation mode, stored as the `TomDelegationMode` name. |
| `resourceKey` | `String?` | For `share` the resource shared; for `absence`/`intentional` an optional single resource to narrow the inherited roles. |
| `role` | `String?` | For `share` the role granted; for `absence`/`intentional` an optional override applied to every inherited resource. |
| `validFrom` | `DateTime?` | Inclusive window start; `null` = unbounded. An **instant**, stored and read as UTC `DATETIME(6)` by the datasource's instant convention, so every node reads the same window. |
| `validTo` | `DateTime?` | Inclusive window end; `null` = unbounded. An instant on the same terms as `validFrom`. |
| `revoked` | `bool` | Manual kill-switch: a revoked delegation is inactive at every timestamp. |
| `delegationMode` | `TomDelegationMode?` | The parsed mode, or `null` when `mode` is unknown/blank. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isActiveAt` | `bool isActiveAt(DateTime now)` | Whether the delegation is in force at `now`: not revoked and within the validity window. |
| `toString` | `String toString()` | *(override)* Human-readable summary of the delegation. |

### PrincipalDelegationStore

The delegation-lookup seam the `TomDelegationResolver` reads through.

- **Abstract**

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `activeDelegationsForDelegate` | `Future<List<TomPrincipalDelegation>> activeDelegationsForDelegate(String delegateId, DateTime at)` | The delegations targeting `delegateId` that are **in force at** `at` — those `isActiveAt` admits; empty when none target them, or none of theirs is live at that instant. The instant is a parameter rather than a post-filter so an implementation can answer the question where the rows are. |

### TomDelegationResolver

Resolves the roles a delegate receives via C-6 delegation and merges them with
the delegate's own C-5 direct grants, folding under the C-5 strength ordering.

#### Constructors

```dart
TomDelegationResolver(
  PrincipalDelegationStore delegationStore,
  TomPrincipalResourceRoleResolver directResolver, {
  String Function(String a, String b)? strongerRole,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `delegationStore` | `PrincipalDelegationStore` | The store active delegations are read through. |
| `directResolver` | `TomPrincipalResourceRoleResolver` | Resolves a delegator's (and the delegate's own) direct C-5 roles. |
| `strongerRole` | `String Function(String a, String b)` | Ranks two competing roles on one resource, returning the stronger. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolveDelegatedRoles` | `Future<Map<String, String>> resolveDelegatedRoles(String delegateId, DateTime at)` | The `resourceKey → roleName` map received purely via delegations active at `at`. Costs one grant read per *distinct* delegator named by the active rows, not one per row; the reuse lasts only this call. |
| `resolveEffectiveRoles` | `Future<Map<String, String>> resolveEffectiveRoles(String principalId, DateTime at)` | Direct grants merged with every delegated role, folded to the stronger role per resource. |
| `resolveAdapter` | `Future<TomResourceRoleAdapter> resolveAdapter(String principalId, DateTime at)` | Resolves effective roles at `at` and wraps them in a kernel `TomResourceRoleAdapter`. |

### RepositoryPrincipalDelegationStore

The query-backed `PrincipalDelegationStore` wired at boot, reading through a
`TomPrincipalDelegation` repository over the `main` datasource.

- **Implements:** `PrincipalDelegationStore`

#### Constructors

```dart
const RepositoryPrincipalDelegationStore(
  TomSqlDatasourceRepository<TomPrincipalDelegation, int> repository,
)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `repository` | `TomSqlDatasourceRepository<TomPrincipalDelegation, int>` | The repository the store reads delegation rows through. |
| `activeDelegationsQuery` | `static const String` | The query sentence the store runs — the SQL expression of `isActiveAt`. Named so a test can compile the real sentence rather than a copy of it. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `activeDelegationsForDelegate` | `Future<List<TomPrincipalDelegation>> activeDelegationsForDelegate(String delegateId, DateTime at)` | *(override)* Runs `activeDelegationsQuery`: the delegate, `revoked = false`, and both window bounds tested at the database, each admitting `NULL`. Only live rows come back. |

### InMemoryPrincipalDelegationStore

A seeded, database-free `PrincipalDelegationStore` for tests.

- **Implements:** `PrincipalDelegationStore`

#### Constructors

```dart
InMemoryPrincipalDelegationStore(List<TomPrincipalDelegation> delegations)
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `activeDelegationsForDelegate` | `Future<List<TomPrincipalDelegation>> activeDelegationsForDelegate(String delegateId, DateTime at)` | *(override)* Filters the seeded rows by delegate id **and** `isActiveAt(at)` — the same two filters the repository store pushes into SQL. |

### TomPrincipalResourceGrant

A persistable grant of a single role to a `(principalId, resourceKey)` pair — the
storage row behind per-principal-per-resource roles (C-5). Mapped to
`tom_principal_resource_grant` and reflection-discoverable (`@tomReflector`,
`@TomDbTable`).

#### Constructors

```dart
TomPrincipalResourceGrant({
  int id = -1,
  String principalId = '',
  String resourceKey = '',
  String role = '',
})
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `createTableSql` | `static const String` | The canonical DDL for the `tom_principal_resource_grant` table. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `int` | Surrogate primary key (`-1` until persisted). |
| `principalId` | `String` | The principal the grant applies to (stringified stable id). |
| `resourceKey` | `String` | The resource the role is scoped to (a resource key / `tomId`). |
| `role` | `String` | The role the principal holds on the resource. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* `'TomPrincipalResourceGrant(principal, key -> role)'`. |

### PrincipalResourceGrantStore

The grant-lookup seam the `TomPrincipalResourceRoleResolver` reads through.

- **Abstract**

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `grantsForPrincipal` | `Future<List<TomPrincipalResourceGrant>> grantsForPrincipal(String principalId)` | Every grant for the principal; empty when they have none. |

### TomPrincipalResourceRoleResolver

Resolves a principal's grant rows into the `resourceKey → roleName` map that
feeds `TomAccessControlInformation.resourceRoles`.

#### Constructors

```dart
TomPrincipalResourceRoleResolver(
  PrincipalResourceGrantStore store, {
  String Function(String a, String b)? strongerRole,
})
```

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `foldRoles` | `static Map<String, String> foldRoles(Iterable<MapEntry<String, String>> entries, String Function(String a, String b) stronger)` | Folds `resourceKey → roleName` entries, collapsing duplicate resources to the stronger role. |
| `registryStrength` | `static String registryStrength(String a, String b)` | Default strength ordering: the role with the wider registered `TomAuthState` wins. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `store` | `PrincipalResourceGrantStore` | The store the resolver loads grant rows through. |
| `strongerRole` | `String Function(String a, String b)` | Ranks two competing roles on the same resource, returning the stronger. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolveResourceRoles` | `Future<Map<String, String>> resolveResourceRoles(String principalId)` | Loads the principal's grants and folds them into a `resourceKey → roleName` map. |
| `resolveAdapter` | `Future<TomResourceRoleAdapter> resolveAdapter(String principalId)` | Resolves the principal's roles and wraps them in a kernel `TomResourceRoleAdapter`. |

### RepositoryPrincipalResourceGrantStore

The query-backed `PrincipalResourceGrantStore` wired at boot, reading through a
`TomPrincipalResourceGrant` repository over the `main` datasource.

- **Implements:** `PrincipalResourceGrantStore`

#### Constructors

```dart
const RepositoryPrincipalResourceGrantStore(
  TomSqlDatasourceRepository<TomPrincipalResourceGrant, int> repository,
)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `repository` | `TomSqlDatasourceRepository<TomPrincipalResourceGrant, int>` | The repository the store reads grant rows through. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `grantsForPrincipal` | `Future<List<TomPrincipalResourceGrant>> grantsForPrincipal(String principalId)` | *(override)* Queries `FIND BY principal_id = :principalId`. |

### InMemoryPrincipalResourceGrantStore

A seeded, database-free `PrincipalResourceGrantStore` for tests.

- **Implements:** `PrincipalResourceGrantStore`

#### Constructors

```dart
InMemoryPrincipalResourceGrantStore(List<TomPrincipalResourceGrant> grants)
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `grantsForPrincipal` | `Future<List<TomPrincipalResourceGrant>> grantsForPrincipal(String principalId)` | *(override)* Filters the seeded rows by principal id. |

### TomResourceDataScope

The grant-driven row scope: an entity column annotated
`@TomDbScope(field: …, scope: TomDbScope.resourceScope)` is filtered by the
resource keys the calling principal holds a grant on. Resolution is **live** —
the grant and delegation tables are read per resolution rather than trusted from
the token — so a revoked share stops granting access at revocation instead of at
token expiry.

Delegations are folded in *through* `TomDelegationResolver`, so every rule that
model already enforces (validity window, revocation, mode semantics,
non-transitivity) governs the row scope without being restated.

- **Implements:** `TomResourceScopeSource` (this package's `object_persistence`
  module — see `api_summary_object_persistence.md`)

#### Constructors

```dart
TomResourceDataScope(
  TomDelegationResolver delegationResolver, {
  DateTime Function()? now,
  String Function(TomPrincipal)? principalId,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `delegationResolver` | `TomDelegationResolver` | Resolves the principal's effective per-resource roles — direct grants folded with the delegations active at `now`. |
| `now` | `DateTime Function()` | The clock delegation validity is evaluated against; injectable for tests. Defaults to `DateTime.now`. |
| `principalId` | `String Function(TomPrincipal)` | Maps the request's principal to the id the grant rows are keyed by. Defaults to the numeric `id` rendered as a string; a deployment keying grants by username or by an external subject claim overrides it. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `install` | `static TomResourceDataScope install(TomDelegationResolver delegationResolver, {DateTime Function()? now, String Function(TomPrincipal)? principalId})` | Builds the source and registers it as `TomDataScopeRegistry.resourceScopeSource`. Returns it, so a caller that also wants to hold or assert on it need not rebuild it. |
| `uninstall` | `static void uninstall()` | Clears the registered source, returning the `resource` scope to deny-all. |
| `runCached` | `static Future<T> runCached<T>(Future<T> Function() body)` | Runs `body` with the resolved roles cached per principal for its duration. A request typically resolves the scope once per repository call plus once for the write check; this collapses those into one read while keeping resolution live *between* requests — a revocation still takes effect on the next request, never mid-request. The cache lives in the zone, so it cannot outlive `body` or leak between concurrently-served requests. |

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isInstalled` | `static bool` | Whether a source is registered — and therefore whether the `resource` scope admits anything at all. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `readableResourceKeys` | `Future<List<Object?>> readableResourceKeys(TomPrincipal? principal)` | *(override)* The keys whose role is registered at `TomAuthState.read` or wider. A `null` principal resolves to no keys, so an unauthenticated query sees nothing. |
| `writableResourceKeys` | `Future<List<Object?>> writableResourceKeys(TomPrincipal? principal)` | *(override)* The keys whose role is registered at `TomAuthState.full`. The narrower answer is what makes a viewer's shared project listable and openable but not modifiable — an out-of-scope write is rejected with `TomDataScopeAuthorizationException`. |

An unregistered role grades as nothing and therefore grants nothing: a typo in a
grant row closes a door rather than opening one. Role grades come from the
kernel's `TomResourceRoleRegistry`.

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
