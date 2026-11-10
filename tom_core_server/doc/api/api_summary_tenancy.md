# Tom Core Server API Reference: Tenancy Module

Multi-tenancy for the server: who the tenants are, where each tenant's data
lives — a shared table, a schema of its own or a database of its own, chosen per
tenant — and how a request names the tenant it is for.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomTenancyException](#tomtenancyexception)
  - [TomTenant](#tomtenant)
  - [TomTenancy](#tomtenancy)
  - [TomTenantType](#tomtenanttype)
  - [TomTenantResolver](#tomtenantresolver)
  - [TomTenantHostResolver](#tomtenanthostresolver)
  - [TomTenantPathResolver](#tomtenantpathresolver)
  - [TomTenantHeaderResolver](#tomtenantheaderresolver)
  - [TomTenantResolution](#tomtenantresolution)
  - [TomTenantRegistry](#tomtenantregistry)
  - [TomMemoryTenantRegistry](#tommemorytenantregistry)
  - [TomSqlTenantRegistry](#tomsqltenantregistry)
  - [TomTenantRecord](#tomtenantrecord)
  - [TomTenantRegistryConflict](#tomtenantregistryconflict)
  - [TomTenantRegistryRefresh](#tomtenantregistryrefresh)
  - [TomTenantRow](#tomtenantrow)
  - [TomTenantPoolSettings](#tomtenantpoolsettings)
  - [TomTenantPurgeReport](#tomtenantpurgereport)
  - [TomTenantData](#tomtenantdata)
  - [TomTenancyStartup](#tomtenancystartup)
  - [TomTenancyStartupReport](#tomtenancystartupreport)
- [Enums](#enums)
  - [TomTenancyMode](#tomtenancymode)
  - [TomTenantIsolation](#tomtenantisolation)
  - [TomTenantStatus](#tomtenantstatus)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/tenancy/tenancy.dart`,
`lib/src/tomserver/tenancy/tenancy_startup.dart`,
`lib/src/tomserver/tenancy/tenant_data.dart`,
`lib/src/tomserver/tenancy/tenant_registry.dart`,
`lib/src/tomserver/tenancy/tenant_registry_sql.dart`,
`lib/src/tomserver/tenancy/tenant_resolution.dart`,
`lib/src/tomserver/tenancy/tenant_type.dart`.

A **tenant** is an isolation boundary — whose data a query reads, which schema
or database a connection reaches, whose cache entries and jobs these are. It is
not the **organization**, which is a business unit inside a tenant; the
framework never infers one from the other. The tenant of a piece of work is the
kernel's `TomTenantContext.currentId`, carried in the zone.

`TomTenancy` holds the deployment's `TomTenant`s and is installed once per
process with `TomTenancy.install`, which provisions each tenant's schema or
database and installs `route` as `TomDataSourceInfo.router`. From then on every
repository reaches the current tenant's data source through that one seam, so
application code is the same under all three `TomTenantIsolation` models. The
request pipeline resolves a request's tenant through `resolveRequest`: the
verified token's `tenant` claim is authoritative, and the `TomTenantResolver`s
(`TomTenantHostResolver`, `TomTenantPathResolver`, `TomTenantHeaderResolver`)
answer only for a request
without one. `TomTenantResolution` is the outcome — a tenant, none, or a
rejection with its status and key. `TomTenancyException` is every refusal the
module raises.

## Class Hierarchy

```text
TomServerException  (little_things)
    └── TomTenancyException

TomTenant
TomTenancy
TomTenantType
TomTenantIsolation  (enum)
TomTenantStatus     (enum)

TomTenantRegistry  (abstract)
    ├── TomMemoryTenantRegistry
    └── TomSqlTenantRegistry
TomTenantRecord
TomTenantRegistryConflict
TomTenantRegistryRefresh
TomTenantRow
TomTenantPoolSettings
TomTenantPurgeReport
TomTenantData  (abstract interface)
TomTenancyStartup  (abstract final — the start's decision)
TomTenancyStartupReport
TomTenancyMode  (enum)

TomTenantResolver  (abstract interface)
    ├── TomTenantHostResolver    (implements)
    ├── TomTenantPathResolver    (implements)
    └── TomTenantHeaderResolver  (implements)

TomTenantResolution
```

## Classes

### TomTenancyException

A tenancy configuration that cannot be used, or a tenant that does not exist.

| Key | Meaning |
| --- | ------- |
| `tenancy.config.not_a_map` | `tenancy` or one of its tenants is not a map. |
| `tenancy.config.unknown_isolation` | An isolation model other than `shared`, `schema` or `database`. |
| `tenancy.config.unknown_resolver` | A tenant resolution other than `host` or `header`. |
| `tenancy.config.schema_unsupported` | Schema isolation over a data source whose settings name no `databaseName`. |
| `tenancy.config.invalid_schema` | A schema name that is not a plain identifier of at most 64 characters. |
| `tenancy.config.missing_datasource` | Database isolation without a data source for a routed name. |
| `tenancy.config.unknown_datasource` | A routed or referenced data source that is not registered. |
| `tenancy.config.invalid_registry` | A `registry.refreshSeconds` that is not a whole number of seconds, 0 or more. |
| `tenancy.tenant.unknown` | Work for a tenant the deployment does not have (`clientThrow: true`). |
| `tenancy.tenant.suspended` | A request for a suspended tenant (403). |
| `tenancy.tenant.unavailable` | A request for a tenant that is provisioning, migrating or whose migration failed (503). |
| `tenancy.config.schema_collision` | A schema-isolated tenant whose schema is a tenant type's shared schema. |
| `tenancy.type.invalid` | A tenant type name that is not a lowercase identifier of at most 32 characters. |
| `tenancy.type.unknown` | A tenant of a type the deployment does not declare. |
| `tenancy.type.missing_migrations` | A declared tenant type without a migration tree. |
| `tenancy.type.isolation_not_allowed` | A tenant whose isolation its type does not allow, or a type whose default isolation it does not allow. |
| `tenancy.type.change` | Adding a tenant the registry holds under another type; changing a type is a move. |

The registry's own keys are on [TomTenantRegistry](#tomtenantregistry).

- **Extends:** `TomServerException`

#### Constructors

```dart
TomTenancyException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? rootException,
  bool clientThrow = true,
})
```

### TomTenant

One tenant of the deployment. The constructor throws the kernel's
`tenancy.id.invalid` for an id that is not a tenant id
(`TomTenantContext.idPattern`: a lower-case letter, then up to 31 lower-case
letters, digits or underscores).

- **Extends:** none

#### Constructors

```dart
TomTenant(
  String id, {
  String type = defaultType,
  String? name,
  TomTenantIsolation? isolation,
  String? schema,
  Map<String, Object> datasources = const {},
})
factory TomTenant.fromMap(String id, Map<Object?, Object?> map)
```

`fromMap` reads a tenant from its configuration map: `type`, `name`, `isolation`,
`schema`, and either `datasources` (per routed data source name) or `datasource`
(the one routed name — the common case). A data-source value is a map of
settings to open or the name of a registered data source.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | The tenant's id — what the token's `tenant` claim names (final). |
| `defaultType` | `static const String` | `'default'` — the type of a tenant that names none. |
| `type` | `String` | Its tenant type; `defaultType` unless it names one (final). |
| `name` | `String?` | A display name, or `null` (final). |
| `isolation` | `TomTenantIsolation?` | Where its data lives, or `null` for the deployment's default (final). |
| `schema` | `String?` | Under schema isolation, the schema; `null` for `<databaseName>_<id>` (final). |
| `datasources` | `Map<String, Object>` | Under database isolation, per routed data source name: the name of a registered data source (`String`) or the settings of one to open (`Map`). The key `''` stands for the one routed name (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* `TomTenant(<id>)`. |

### TomTenancy

The deployment's tenants, how a request names one, and where each one's data
lives.

- **Extends:** none

#### Constructors

```dart
TomTenancy({
  required Iterable<TomTenant> tenants,
  Iterable<TomTenantType> types = const [],
  Set<String> datasources = const {'main'},
  List<TomTenantResolver> resolvers = const [],
  TomTenantIsolation defaultIsolation = TomTenantIsolation.shared,
  bool createSchemas = false,
  TomTenantRegistry? registry,
  Duration? refreshInterval,
  Duration purgeAfter = defaultPurgeAfter,
  TomTenantPoolSettings pool = const TomTenantPoolSettings(),
  DateTime Function()? clock,
})
factory TomTenancy.fromConfiguration([TomServerConfigResourceProvider? config])
```

`types` are the declared tenant types; without any the deployment has the
implicit type `default`, which allows every model and routes `datasources`.
`tenants` seed the `registry` — a `TomMemoryTenantRegistry` unless one is given;
`refreshInterval` makes the installed tenancy call `refreshFromRegistry` that
often; `purgeAfter` is how long a removed tenant's data is kept; `pool`
sizes the pools the tenancy opens for tenants; `clock` stamps the registry
rows.

`fromConfiguration` reads the `tenancy` key of the server configuration
(`TomServerConfigResourceProvider.getServerConfig()` unless one is passed):
`isolation`, `datasources`, `resolution` (`host` / `header`, in order),
`hostSuffix`, `header`, `createSchemas`, the `registry`, the `migrations` root,
the `types` map (each read by `TomTenantType.fromMap`), the `tenants` map,
`purgeAfterDays` and `pool` (read by `TomTenantPoolSettings.fromMap`).
An absent key reads as a tenancy with no tenants. `registry: memory` keeps the
tenants in the process; otherwise — also when `registry` is absent — it is a
`TomSqlTenantRegistry.named` on `registry.datasource` (default the first routed
data source) with `registry.table` and `registry.createSchema`, refreshed every
`registry.refreshSeconds` (default `defaultRefreshSeconds`, `0` for never).
Throws `tenancy.config.not_a_map`, `tenancy.config.unknown_isolation`,
`tenancy.config.unknown_resolver`, `tenancy.config.invalid_registry`,
`tenancy.config.invalid_number`,
`tenancy.type.invalid` or `tenancy.type.isolation_not_allowed`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `configurationKey` | `static const String` | `'tenancy'` — the configuration path of the settings. |
| `current` | `static TomTenancy?` | *(getter)* The installed configuration, or `null` in a deployment without tenancy. |
| `defaultRefreshSeconds` | `static const int` | `30` — how often a configured tenancy refreshes from its registry. |
| `implicitTenant` | `static const String` | `'default'` — the tenant of a deployment that installs no tenancy, which tenant-table work with no tenant in context runs as. |
| `tenantTables` | `static Map<Type, TomDbTable>` | *(getter)* The tenant tables the code declares — every reflected `@TomDbTable` entity marked `@TomTenantTable`, with its table, as the annotation analyzer reports them. |
| `tenants` | `Map<String, TomTenant>` | The tenants served, by id: the registry's tenants that are not removed once `install` has read it, the configured ones before (final; `addTenant`, `removeTenant` and `refreshFromRegistry` change it). |
| `registry` | `TomTenantRegistry` | The durable list of tenants (final). |
| `refreshInterval` | `Duration?` | How often the installed tenancy re-reads `registry`, or `null` for never (final). |
| `purgeAfter` | `Duration` | How long a removed tenant's data is kept before `purgeTenant` may drop it — while it is, `restoreTenant` serves the tenant again (final). |
| `defaultPurgeAfter` | `static const Duration` | The default of `purgeAfter`: ninety days. |
| `pool` | `TomTenantPoolSettings` | How the pools this tenancy opens for tenants are sized (final). |
| `registryConflicts` | `List<TomTenantRegistryConflict>` | The configured tenants their registry rows contradicted at the last `install`; the rows were used. |
| `datasources` | `Set<String>` | The data sources routed for a type that names none — the implicit type's, in a deployment that declares no types (final). |
| `types` | `Map<String, TomTenantType>` | The tenant types, by name: the declared ones, or the implicit `default` alone (final). |
| `typesDeclared` | `bool` | Whether `types` were declared rather than implicit (final). |
| `routedDatasources` | `Set<String>` | *(getter)* Every data source some type routes — what `route` considers. |
| `resolvers` | `List<TomTenantResolver>` | How a request without a token claim names its tenant, in order (final). |
| `defaultIsolation` | `TomTenantIsolation` | The isolation of a tenant that names none (final). |
| `createSchemas` | `bool` | Whether schema isolation creates the tenant's schema when it is provisioned — the base data source dialect's `createSchema`: `CREATE DATABASE IF NOT EXISTS` on MariaDB, `CREATE SCHEMA IF NOT EXISTS` on PostgreSQL (final). |
| `schemaChecks` | `Map<String, TomSchemaVersionCheck>` | *(getter)* Every served tenant's last schema check, by tenant id; the readiness check lists those not current. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `install` | `static Future<void> install(TomTenancy tenancy)` | Resets any installed configuration; refuses a declared type without a migration tree (`tenancy.type.missing_migrations`) and a configured tenant of an unknown type or a model its type does not allow — before anything is seeded; reads the tenancy's `registry` — seeding it with the configured tenants it lacks as `active`, and reporting a configured tenant its row contradicts in `registryConflicts` — validates every tenant the registry serves the same way, provisions each, then publishes `tenancy` as `current`, installs `route` as `TomDataSourceInfo.router` and starts refreshing when `refreshInterval` is set. A provisioning failure fails the install. |
| `reset` | `static Future<void> reset()` | Removes the installed configuration, stops its refresh, uninstalls the router, and closes and unregisters the data sources it opened. |
| `unknownTenant` | `static TomTenancyException unknownTenant(String tenantId)` | The `tenancy.tenant.unknown` exception for work in a tenant the deployment does not have (`clientThrow: true`). |
| `tenantForWork` | `static String tenantForWork(String what)` | The tenant work on a tenant table (`what` names it) runs as: the tenant in context; with none, `implicitTenant` when no tenancy is installed, and `tenancy.context.missing` when one is. |
| `addTenant` | `Future<TomMigrationRun?> addTenant(TomTenant tenant)` | Onboarding in one call, without a restart. Refuses, before anything is recorded, a tenant of an unknown type or a model its type does not allow, and one the registry holds — not removed — under another type (`tenancy.type.change`). Records `tenant` as `provisioning` in the registry, provisions its schema or database, migrates it by its type's tree (`migrateTenant`: `migrating`, then `active`) and serves it; answers the run, or `null` when the type has no tree. A failed provisioning leaves it `provisioning`, with the error as its status detail, and unserved; a failed migration leaves it `migration-failed` — refused and not routed — and throws `tenancy.tenant.migration_failed`. A removed tenant whose data was not purged is added back over its old schema or database. |
| `migrateTenant` | `Future<TomMigrationRun?> migrateTenant(String tenantId)` | Migrates the served tenant by its type's tree (`TomDbMigrations.migrateTenant`): `migrating`, then `active`, or `migration-failed` with the error, which throws `tenancy.tenant.migration_failed` (a tree refused before it ran throws its own key, the tenant `migration-failed` as well). Answers the run, or `null` when there is nothing to apply — the tenant then `active` unless suspended. The retry of a tenant whose migration failed. |
| `restoreTenant` | `Future<TomMigrationRun?> restoreTenant(String tenantId)` | Serves a removed tenant again over the schema or database it left — `addTenant` with its registry row. Throws `tenancy.tenant.unknown` for a tenant the registry does not hold and `tenancy.tenant.not_removed` for one that is not removed. |
| `checkSchemaVersions` | `Future<void> checkSchemaVersions([Iterable<String>? tenantIds])` | Compares the schema of each served tenant — `tenantIds`, or all — with this code: per data source of its type's tree, the code's highest version (`codeVersionsOf`) against the registry's `migrated[<datasource>]`, and for a schema ahead the lowest code version it serves (`migrated[<datasource>/requires]`; absent, only its own version). A tenant `behind` or `aheadIncompatible` is then refused by `resolveRequest` (`tenancy.tenant.schema_behind` / `tenancy.tenant.schema_ahead`, 503) while the others are served; a change is logged. Run by `install`, `refreshFromRegistry` and `TomDbMigrations.migrateAll` after each target. |
| `schemaCheckOf` | `TomSchemaVersionCheck? schemaCheckOf(String tenantId)` | The served tenant's last schema check, or `null` for one not checked. |
| `codeVersionsOf` | `Map<String, int> codeVersionsOf(TomTenantType type)` | The highest version of each `<datasource>` chain of `type`'s tree this code carries for the active environment (`TomDbMigrations.treeVersions`), read once per type; empty for a type without a tree. |
| `setStatus` | `Future<void> setStatus(String tenantId, TomTenantStatus status, {String? detail})` | Records the tenant's `status` with `detail` (cleared when `null`) in the registry, then serves it accordingly on this node — how `TomDbMigrations.migrateAll` moves a tenant through `migrating` to `active` or `migration-failed`, and what `suspendTenant` / `resumeTenant` call. Throws `tenancy.tenant.unknown` for an unknown id. |
| `suspendTenant` | `Future<void> suspendTenant(String tenantId)` | Records the tenant as `suspended`, then refuses its requests (`tenancy.tenant.suspended`, 403) and holds its queued runs (`servesWork`); data and routes stay. Throws `tenancy.tenant.unknown` for an unknown id. |
| `resumeTenant` | `Future<void> resumeTenant(String tenantId)` | Records the tenant as `active` and serves it again; its held runs are claimed from the next tick. Throws `tenancy.tenant.unknown` for an unknown id. |
| `statusOf` | `TomTenantStatus? statusOf(String tenantId)` | The registry status of a served tenant, or `null` for one the deployment does not have. |
| `servesWork` | `bool servesWork(String tenantId)` | Whether the tenant's queued work runs now on this node — the scheduler's `TomScheduler.tenantGate` while this tenancy is installed: a served, `active` tenant's runs do; a suspended one's, a migration-failed one's and those of a tenant this node does not serve are held. |
| `activeTenantsOf` | `List<String> activeTenantsOf(List<String> types)` | The served, `active` tenants whose type is one of `types` (every type when empty), in id order — what a job planned per tenant (`TomJobDefinition.tenants`) is planned for, as the scheduler's `TomScheduler.tenantsFor` while this tenancy is installed. |
| `refreshFromRegistry` | `Future<TomTenantRegistryRefresh> refreshFromRegistry()` | Re-reads `registry` and brings this node's routing level with it: tenants another node added are provisioned and served, removed ones unrouted, changed statuses applied; a tenant that cannot be provisioned here is in the result's `failed`. |
| `removeTenant` | `Future<TomTenant> removeTenant(String tenantId, {Iterable<TomJobStore> jobStores = const []})` | Records the tenant as `removed` in the registry, then withdraws it from the running deployment: its requests and work are refused as `tenancy.tenant.unknown`, its routes dropped, the data sources opened for it closed (their pools with them), and its queued runs cancelled in the job stores of the started schedulers and `jobStores` (`TomJobStore.cancelTenantRuns`). Its data stays for `purgeAfter`. Returns the tenant. Throws `tenancy.tenant.unknown` for an unknown id. |
| `purgeTenant` | `Future<TomTenantPurgeReport> purgeTenant(String tenantId, {bool force = false, Iterable<TomTenantData> stores = const [], Iterable<TomJobStore> jobStores = const []})` | Deletes a removed tenant's data for good once `purgeAfter` has passed since its removal (or at once with `force`): a `schema` tenant's schema is dropped on each routed data source (`dropSchema`), a `database` tenant's database when the tenancy opened it on the base data source's server (`dropDatabase`; one named by reference, or on another server, is kept and reported), a `shared` tenant's rows are deleted from every tenant table of its type's shared schema — the application's and `frameworkTenantTables`; its system-table records go through `stores` and the job stores (`TomTenantData.purgeTenant`), and its registry row is deleted. The audit trail is kept; the personal values it sealed for the tenant's subjects become unreadable with their subject keys. Throws `tenancy.tenant.unknown`, `tenancy.purge.not_removed` or `tenancy.purge.retention`. |
| `isolationOf` | `TomTenantIsolation isolationOf(TomTenant tenant)` | The isolation `tenant` runs under: its own, else its type's default, else `defaultIsolation`. Throws `tenancy.type.unknown`. |
| `typeOf` | `TomTenantType typeOf(TomTenant tenant)` | The declared type of `tenant`; throws `tenancy.type.unknown`. |
| `validateTenant` | `void validateTenant(TomTenant tenant)` | Throws unless `tenant` can be served: its type is declared (`tenancy.type.unknown`) and allows its model (`tenancy.type.isolation_not_allowed`). |
| `datasourcesOf` | `Set<String> datasourcesOf(TomTenantType type)` | The data sources `type` routes: its own, or `datasources`. |
| `route` | `TomDataSourceInfo route(TomDataSourceInfo base)` | `base` as the current tenant reaches it: the tenant's schema or database for a data source its type routes, its type's shared schema for a shared tenant of a type other than `default`, `base` itself with no tenant, for an unrouted data source, or for a shared tenant of `default`. Throws `tenancy.tenant.unknown` for a tenant in context the deployment does not have — routing it to the shared data source would hand it everyone's rows. |
| `routeForMaintenance` | `TomDataSourceInfo routeForMaintenance(String tenantId, TomDataSourceInfo base)` | `base` as the tenant reaches it, whatever its status — the route of migrating, repairing or rolling back a tenant whose migration failed, which `route` refuses. Throws `tenancy.tenant.unknown`. |
| `runFor` | `Future<T> runFor<T>(String tenantId, FutureOr<T> Function() body)` | Runs `body` inside `tenantId`, which must be a tenant of the deployment (`tenancy.tenant.unknown` otherwise). |
| `forEachTenant` | `Future<void> forEachTenant(FutureOr<void> Function(TomTenant tenant) body)` | Runs `body` once per tenant, in turn, inside each — per-tenant migrations, a nightly job doing each tenant's work, a cache warm-up. |
| `resolveRequest` | `TomTenantResolution resolveRequest(Request request, {String? claim})` | The tenant `request` is for, or the rejection to answer it with; `claim` is the verified token's `tenant` claim. The claim is authoritative: a host or header naming another tenant is refused (`tenancy.resolution.conflict`, 403). Without a claim, the `resolvers` are asked in order. An unknown tenant is refused (`tenancy.tenant.unknown`, 404), as is an id that is not one (`tenancy.id.invalid`, 400); a suspended tenant is refused as `tenancy.tenant.suspended` (403), one provisioning or migrating as `tenancy.tenant.unavailable` (503), and one whose migration failed as `tenancy.tenant.migration_failed` (503). No answer is not a rejection: the request proceeds with no tenant. |
| `schemaNameOf` | `String schemaNameOf(TomDataSourceInfo base, TomTenant tenant)` | The schema of the `schema`-isolated `tenant` on the data source `base`: its own `TomTenant.schema`, else `<databaseName>_<id>`. |

A routed data source is opened over a schema tenant's schema with the base data
source's settings and the dialect's `schemaSetting` replaced — `databaseName` on
MariaDB, `schema` (the `search_path`) on PostgreSQL — and registered under
`<name>@<tenant>`; a database tenant's is opened from its configured settings
under the same name, or is the registered data source it names.

### TomTenantType

One kind of tenant: the default model of its tenants, the models they may use,
the data sources it routes and its migration tree. The shared-isolation tenants
of one type share one tenant schema (`sharedSchema`), reached through one pool
registered as `<name>@type.<type>`, which the type's tree is applied to once.

- **Extends:** none

#### Constructors

```dart
TomTenantType(
  String name, {
  TomTenantIsolation? isolation,
  Set<TomTenantIsolation>? isolations,
  Set<String>? datasources,
  String? migrations,
})
factory TomTenantType.fromMap(
  String name,
  Map<Object?, Object?> map, {
  String? migrationsRoot,
})
```

The constructor throws `tenancy.type.invalid` for a name that is not a type
name and `tenancy.type.isolation_not_allowed` for an `isolation` outside
`isolations`. `fromMap` reads `isolation`, `isolations`, `datasources` and
`migrations`; a type naming no `migrations` has its tree at
`treeUnder(migrationsRoot, name)` when a root is given.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The type's name — what `TomTenant.type` names (final). |
| `isolation` | `TomTenantIsolation?` | The default model of its tenants, or `null` for the deployment's (final). |
| `isolations` | `Set<TomTenantIsolation>` | The models its tenants may use; all three unless given (final). |
| `datasources` | `Set<String>?` | The data sources it routes, or `null` for the deployment's `datasources` (final). |
| `migrations` | `String?` | The directory of its migration tree, or `null` when it names none (final). |
| `namePattern` | `static final RegExp` | `^[a-z][a-z0-9_]{0,31}$` — a type name has a tenant id's shape, because its shared schema is named after it. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `sharedSchema` | `String? sharedSchema(String databaseName)` | The schema its shared tenants share: `null` — the base data source's own — for `default`, `<databaseName>_<name>` otherwise. |
| `verifyMigrations` | `void verifyMigrations()` | Throws `tenancy.type.missing_migrations` unless `migrations` names an existing directory. |
| `treeUnder` | `static String treeUnder(String root, String type)` | `<root>/tenant/<type>`, a type's tree under the migrations root. |
| `isolationNotAllowed` | `static TomTenancyException isolationNotAllowed(String type, TomTenantIsolation isolation, String what)` | The `tenancy.type.isolation_not_allowed` exception; `what` says whose isolation it is. |
| `toString` | `String toString()` | *(override)* `TomTenantType(<name>)`. |

### TomTenantResolver

Reads a tenant id from a request, or answers `null`. The token's `tenant` claim
is not a resolver: it always comes first, and the resolvers answer only for
requests that have not authenticated — the login, a public page, an identity
provider's redirect.

- **Extends:** none (abstract interface)

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolve` | `String? resolve(Request request)` | The tenant `request` names, or `null` when it names none. |

### TomTenantHostResolver

Names the tenant by host: an exact entry in `hosts`, or the first label of a host
one level under `suffix` — `acme.app.example.com` under `app.example.com`. A
host deeper than one label under the suffix names nothing.

- **Implements:** `TomTenantResolver`

#### Constructors

```dart
const TomTenantHostResolver({String? suffix, Map<String, String> hosts = const {}})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `suffix` | `String?` | The domain tenants are subdomains of, or `null` (final). |
| `hosts` | `Map<String, String>` | Host → tenant, for tenants on a domain of their own (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolve` | `String? resolve(Request request)` | *(override)* The tenant the request's host names, case-insensitively, or `null`. |

### TomTenantPathResolver

Names the tenant by the path segment after a prefix — `/t/acme/sign-in` names
`acme` under the default prefix `t`. With a `lookup`, the segment is a slug
mapped to the tenant id, and a segment the lookup does not know is refused by
`TomTenancy.resolveRequest` as `tenancy.tenant.unknown` (404) instead of
passing as a request without a tenant. It only names the tenant; the routes
under the prefix are the deployment's router's.

- **Implements:** `TomTenantResolver`

#### Constructors

```dart
const TomTenantPathResolver({String prefix = defaultPrefix, String? Function(String segment)? lookup})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `defaultPrefix` | `static const String` | `'t'` — the prefix read when none is configured. |
| `prefix` | `String` | The path segments before the tenant's, `/`-separated: `t`, or `api/t` (final). |
| `lookup` | `String? Function(String segment)?` | Segment → tenant id, `null` for a segment naming no tenant; without it the segment is the tenant id (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `segmentOf` | `String? segmentOf(Request request)` | The tenant segment of the request's path, or `null` when the path does not start with the prefix followed by a segment. |
| `namesUnknownSegment` | `bool namesUnknownSegment(Request request)` | Whether the path names a segment the lookup does not know. |
| `resolve` | `String? resolve(Request request)` | *(override)* The tenant the path names — the segment, or its lookup — or `null`. |

### TomTenantHeaderResolver

Names the tenant by a request header. A header is the weakest source, because a
client chooses it freely; it is safe because it only ever proposes a tenant —
data stays closed until a login in that tenant succeeds, and once a token
exists its claim wins.

- **Implements:** `TomTenantResolver`

#### Constructors

```dart
const TomTenantHeaderResolver({String header = defaultHeader})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `defaultHeader` | `static const String` | `'X-Tenant-Id'` — the header read when none is configured. |
| `header` | `String` | The header naming the tenant (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolve` | `String? resolve(Request request)` | *(override)* The header's value, trimmed, or `null` when absent or blank. |

### TomTenantResolution

The outcome of resolving a request's tenant: a tenant, none, or a rejection to
answer with.

- **Extends:** none

#### Constructors

```dart
const TomTenantResolution.of(String this.tenant)
const TomTenantResolution.none()
const TomTenantResolution.rejected(int this.status, String this.key, String this.message)
```

`of` and `rejected` take non-null arguments for fields that are nullable,
because each fills only its own case.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `tenant` | `String?` | The tenant, or `null` (final). |
| `status` | `int?` | The HTTP status of a rejection, or `null` (final). |
| `key` | `String?` | The key of a rejection, or `null` (final). |
| `message` | `String?` | The message of a rejection, or `null` (final). |
| `isRejected` | `bool` | *(getter)* Whether the request is refused. |

### TomTenantRegistry

The durable list of the deployment's tenants.

| Key | Meaning |
| --- | ------- |
| `tenancy.registry.unknown_tenant` | A status or version change for a tenant the registry does not hold. |
| `tenancy.registry.unknown_status` | A stored status this code does not know. |
| `tenancy.registry.unknown_datasource` | The registry's data source is not registered. |

- **Extends:** none (abstract)

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `all` | `Future<List<TomTenantRecord>> all()` | Every recorded tenant, removed ones included, by id. |
| `find` | `Future<TomTenantRecord?> find(String id)` | The tenant `id`, or `null`. |
| `put` | `Future<void> put(TomTenantRecord record)` | Writes `record`, replacing the tenant's row. |
| `delete` | `Future<void> delete(String id)` | Deletes the tenant's row — what `TomTenancy.purgeTenant` does last. |
| `setStatus` | `Future<TomTenantRecord> setStatus(String id, TomTenantStatus status, {String? detail, required DateTime at})` | Sets the tenant's status with `detail` (cleared when `null`) at `at`; answers the updated record. Throws `tenancy.registry.unknown_tenant`. |
| `setMigrated` | `Future<TomTenantRecord> setMigrated(String id, String target, int version, {required DateTime at})` | Records `version` as the highest migration of the tenant's type tree applied to the data source `target` — what `TomDbMigrations.migrateAll` writes after a tenant's target succeeded. Throws `tenancy.registry.unknown_tenant`. |
| `withMigrationLock` | `Future<R> withMigrationLock<R>(String target, Future<R> Function() body)` | Runs `body` holding the registry's migration lock of `target` (`shared:<type>` or `tenant:<id>`), so two migrations of one target never run at once. This one serialises within the process. |
| `unknownTenant` | `static TomTenancyException unknownTenant(String id)` | The `tenancy.registry.unknown_tenant` exception. |

### TomMemoryTenantRegistry

The registry in memory — a single process's tenants, lost on restart: the
registry of a `TomTenancy` built in code, and of tests.

- **Extends:** `TomTenantRegistry`

#### Constructors

```dart
TomMemoryTenantRegistry()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `delete` | `Future<void> delete(String id)` | *(override)* Forgets the tenant. |

### TomSqlTenantRegistry

The registry in a SQL table of the system schema — the base data source's own
schema, never routed: read and written through
`TomDataSourceInfo.getBaseDataSourceInfo`, also inside a tenant.

- **Extends:** `TomTenantRegistry`

#### Constructors

```dart
TomSqlTenantRegistry(
  TomDataSource datasource, {
  String table = defaultTenantTable,
  bool createSchema = true,
})
TomSqlTenantRegistry.named(
  String this.datasourceName, {
  String table = defaultTenantTable,
  bool createSchema = true,
})
```

`named` looks the data source up, unrouted, when the registry is first used, so
it can be built before the data sources are registered.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasourceName` | `String?` | The registered data source's name, or `null` for a fixed data source (final). |
| `table` | `String` | The table name (final). |
| `createSchema` | `bool` | Whether the store creates its table on first use (final). |
| `datasource` | `TomDataSource` | *(getter)* The data source the table lives in; throws `tenancy.registry.unknown_datasource`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `withMigrationLock` | `Future<R> withMigrationLock<R>(String target, Future<R> Function() body)` | *(override)* The process's lock, and around it the database session lock `migrationLockName(target)` on the registry's data source, so no other process sharing the registry migrates `target` meanwhile; the database releases it when the holder dies. |
| `delete` | `Future<void> delete(String id)` | *(override)* Deletes the tenant's row. |
| `deleteAll` | `Future<void> deleteAll()` | Removes every row. For tests. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `migrationLockName` | `static String migrationLockName(String target)` | `tom_tenant_migration:<target>`, at most 64 characters as MariaDB allows — the target hashed when it would not fit. |

### TomTenantRecord

One tenant as the registry records it.

- **Extends:** none

#### Constructors

```dart
const TomTenantRecord({
  required String id,
  String type = TomTenant.defaultType,
  String? name,
  TomTenantIsolation? isolation,
  String? schema,
  Map<String, Object> datasources = const {},
  required TomTenantStatus status,
  String? statusDetail,
  Map<String, int> migrated = const {},
  required DateTime createdAt,
  required DateTime updatedAt,
})
factory TomTenantRecord.of(TomTenant tenant, TomTenantStatus status, DateTime at)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id`, `type`, `name`, `isolation`, `schema` | | As on `TomTenant` (final). |
| `datasources` | `Map<String, Object>` | Per routed data source name, a registered name or settings — never a literal password (final). |
| `status` | `TomTenantStatus` | Where it is in its lifecycle (final). |
| `statusDetail` | `String?` | What the last status change said — the error of a failed step (final). |
| `migrated` | `Map<String, int>` | The migration version applied per `<datasource>/<schema>` (final). |
| `createdAt`, `updatedAt` | `DateTime` | When it was first recorded and last changed (final). |
| `passwordKey` | `static const String` | `'password'` — the setting a data source's password is under. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `copyWith` | `TomTenantRecord copyWith({TomTenantStatus? status, String? statusDetail, bool clearDetail = false, Map<String, int>? migrated, DateTime? updatedAt})` | The record with those fields replaced. |
| `copyWithCreated` | `TomTenantRecord copyWithCreated(DateTime? createdAt)` | The record created at `createdAt` when one is given. |
| `toTenant` | `TomTenant toTenant({TomTenant? configured})` | The tenant it describes; a data source's `password` comes from `configured`, the same tenant as configured. |
| `storableDatasources` | `static Map<String, Object> storableDatasources(Map<String, Object> datasources)` | `datasources` without a `password` that is not a `secret:` reference. |
| `differencesFrom` | `Map<String, (Object?, Object?)> differencesFrom(TomTenant tenant)` | The fields `tenant` disagrees with — `type`, `isolation`, `schema`, `datasources` — each (configured, recorded). |
| `toString` | `String toString()` | *(override)* `TomTenantRecord(<id>, <status>)`. |

### TomTenantRegistryConflict

A configured tenant its registry row contradicts: the row is used, the
difference reported.

- **Extends:** none

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `tenant` | `String` | The tenant's id (final). |
| `differences` | `Map<String, (Object?, Object?)>` | The fields that differ: name → (configured, recorded) (final). |

### TomTenantRegistryRefresh

What `TomTenancy.refreshFromRegistry` changed on a node.

- **Extends:** none

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `added` | `List<String>` | The tenants now served that were not (final). |
| `removed` | `List<String>` | The tenants no longer served (final). |
| `changed` | `List<String>` | The tenants whose status changed (final). |
| `failed` | `Map<String, Object>` | The tenants that could not be provisioned here, with the error (final). |
| `isEmpty` | `bool` | *(getter)* Whether nothing changed. |

### TomTenantRow

One row of the tenant registry table, as the data source's mapper reads it
(`@tomReflector`): `id`, `type`, `name`, `isolation`, `schemaName`,
`datasources` and `migrated` (JSON), `status`, `statusDetail`, `createdAt`,
`updatedAt`.

- **Extends:** none

### TomTenantPoolSettings

How the pools a `TomTenancy` opens for tenants — a `schema` tenant's, a
`database` tenant's configured by settings, a type's shared schema — are sized:
small, opened by their first statement (`connectLazily`), their idle
connections closed by a timer (`poolSweepIdle`), all of them under one cap. A
`database` tenant's own settings override these.

- **Extends:** none

#### Constructors

```dart
const TomTenantPoolSettings({
  int perTenant = 4,
  Duration idleTimeout = const Duration(seconds: 60),
  int? maxTotal,
})
factory TomTenantPoolSettings.fromMap(Map<Object?, Object?> map)
```

`fromMap` reads `tenancy.pool` — `perTenant`, `idleSeconds`, `maxTotal` — and
refuses a value that is not a positive whole number
(`tenancy.config.invalid_number`).

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `perTenant` | `int` | The most connections a tenant pool opens (`poolMaxSize`) (final). |
| `idleTimeout` | `Duration` | How long a tenant pool's connection may sit idle before it is closed (final). |
| `maxTotal` | `int?` | The most connections all tenant pools together may open — a pool that would pass it is refused with `tenancy.pool.cap_exceeded` before it opens — or `null` for no cap (final). |
| `settings` | `Map<String, Object>` | *(getter)* The data-source settings these stand for, beneath a pool's own: `poolMaxSize`, `poolIdleTimeoutMs`, `poolSweepIdle: true`, `connectLazily: true`. |

### TomTenantPurgeReport

What `TomTenancy.purgeTenant` did for one tenant.

- **Extends:** none

#### Constructors

```dart
const TomTenantPurgeReport(
  String tenant, {
  List<String> dropped = const [],
  List<String> kept = const [],
  Map<String, int> deleted = const {},
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `tenant` | `String` | The purged tenant (final). |
| `dropped` | `List<String>` | The schemas and databases dropped, as `<datasource>: schema <name>` or `<datasource>: database <name>` (final). |
| `kept` | `List<String>` | What was left in place, and why — a database named by reference, or on another server (final). |
| `deleted` | `Map<String, int>` | The rows deleted, by table (shared isolation) or store (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* The report on one line. |

### TomTenantData

A store of a system table that records a tenant on its rows — the job queue,
the blob manifest, delivery reports, the suppression list, OAuth sign-in state,
service accounts and their API keys, saved audit questions — and so can delete
a purged tenant's records. `TomTenancy.purgeTenant` calls it on every store it is handed.

- **Kind:** abstract interface class.
- **Implemented by:** `TomSqlJobStore`, `TomDatabaseBlobStore`,
  `TomSqlDeliveryReportStore`, `TomSqlSuppressionList`,
  `TomSqlOAuthStateStore`, `TomSqlApiKeyStore`, `TomAuditQuestionStore`

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `purgeTenant` | `Future<int> purgeTenant(String tenant)` | Deletes every record the store keeps for `tenant`; answers how many. |

### TomTenancyStartup

What a server's start makes of tenancy, decided from the application's tenant
tables and the configuration — `TomServer.configureTenancy` calls `configure`
before it migrates.

- **Kind:** abstract final class (static members only).

#### Static Members

| Member | Signature | Description |
| ------ | --------- | ----------- |
| `frameworkTenantEntities` | `static const Set<Type>` | The tenant tables the framework itself declares — `TomUserPreference`, `TomPreferenceDefault`, `TomResourceGrant`, `TomPrincipalResourceGrant`, `TomPrincipalDelegation`, `TomExternalIdentityLink`, `TomExternalIdentityToken`, `TomUserTwoFactorEnrolment`. Reflected into every server, used or not; they make no deployment a tenant deployment, and a type's tree is not asked to create them. |
| `applicationTenantTables` | `static Map<Type, TomDbTable> get` | `TomTenancy.tenantTables` less the `frameworkTenantEntities`. |
| `configure` | `static Future<TomTenancyStartupReport> configure({TomServerConfigResourceProvider? config, String? migrationsRoot, Map<Type, TomDbTable>? tenantTables})` | Installs the tenancy the `tenancy` key of `config` (the server configuration unless given) describes, unless one is installed; decides the mode from `tenantTables` (`applicationTenantTables` unless given); refuses a tree under `<migrationsRoot>/tenant/` for an undeclared type (`tenancy.start.undeclared_type_tree`) and a tenant table on a data source a type routes that the type's existing tree never creates (`tenancy.start.table_missing_from_type`); `TomTenancy.install` refuses a declared type without a tree and a tenant of an unknown type. A configured tenancy with no tenant table and no tenant tree is warned about (`tenancy.start.no_tenant_tables`). |

### TomTenancyStartupReport

What `TomTenancyStartup.configure` decided and found.

- **Extends:** none

#### Constructors

```dart
const TomTenancyStartupReport(
  TomTenancyMode mode, {
  Map<Type, TomDbTable> tenantTables = const {},
  List<String> warnings = const [],
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `mode` | `TomTenancyMode` | How the deployment runs (final). |
| `tenantTables` | `Map<Type, TomDbTable>` | The application's tenant tables, by entity (final). |
| `warnings` | `List<String>` | What the start warned about, one line each (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* The mode, the table count and the warnings. |

## Enums

### TomTenancyMode

How a deployment runs, as its start decided it.

| Value | Meaning |
| ----- | ------- |
| `plain` | No tenant table and no tenancy: nothing installed, nothing configured. |
| `implicit` | Tenant tables and no tenancy configured: the one tenant `default`, of the type `default`, shared, in the system schema; nothing installed. |
| `configured` | A `TomTenancy` installed — by the application or from the `tenancy` key — and validated. |

### TomTenantIsolation

Where a tenant's data lives.

| Value | Meaning |
| ----- | ------- |
| `shared` | In the shared database, separated by the tenant column. |
| `schema` | In a schema of the tenant's own on the shared server. |
| `database` | In a database of the tenant's own. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `parse` | `static TomTenantIsolation parse(String raw)` | Parses a configured name, trimmed and case-insensitively; throws `tenancy.config.unknown_isolation`. |

### TomTenantStatus

Where a tenant is in its lifecycle; only `active` is served.

| Value | Wire name | Meaning |
| ----- | --------- | ------- |
| `provisioning` | `provisioning` | Its schema or database is being created (503). |
| `migrating` | `migrating` | Its type's migrations are being applied (503). |
| `active` | `active` | Served. |
| `suspended` | `suspended` | Kept, but refused (403). |
| `migrationFailed` | `migration-failed` | A migration of it failed (503); not routed until it is migrated again. |
| `removed` | `removed` | Gone from the deployment; not routed; its data kept until it is purged. |

| Member | Signature | Description |
| ------ | --------- | ----------- |
| `wireName` | `final String wireName` | The name stored in the registry. |
| `parse` | `static TomTenantStatus parse(String raw)` | The status stored as `raw`; throws `tenancy.registry.unknown_status`. |

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `defaultTenantTable` | `const String defaultTenantTable` | `'tom_tenant'`. |
| `tenantTable` | `TomFrameworkTable tenantTable(String table)` | The tenant registry table, declared once. |
| `tenantTableDdl` | `String tenantTableDdl(String table)` | Its `CREATE TABLE` statement. |
