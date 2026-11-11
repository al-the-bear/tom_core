# Tenancy Module

First-class multi-tenancy for a Tom server: one deployment serving several
customers whose data never meets. The module says who the tenants are, where
each tenant's data lives — a shared table, a schema of its own, or a database of
its own, chosen **per tenant** — and how a request finds out which tenant it is
for. Everything that holds tenant data reads the tenant from one place, the
kernel's `TomTenantContext`, so repositories, caches, revocations, jobs and the
messaging outbox keep tenants apart without a tenant parameter on any call.

The kernel half — the zone-carried tenant, the id rule, the scoped job command
and the tenant event — is documented with the context module, in
[`tom_core_kernel/doc/context/context.md`](../../tom_core_kernel/doc/context/context.md#tenant-context).
This guide is the server half.

## Table of Contents

- [Overview](#overview)
- [Tenancy and Migrations, End to End](#tenancy-and-migrations-end-to-end)
- [Do I Need Tenancy?](#do-i-need-tenancy)
  - [What the start refuses](#what-the-start-refuses)
- [Tenant and Organization](#tenant-and-organization)
- [Three Isolation Models](#three-isolation-models)
  - [The model is chosen per tenant](#the-model-is-chosen-per-tenant)
  - [How a data source is routed](#how-a-data-source-is-routed)
- [Configuration](#configuration)
  - [A schema on each database](#a-schema-on-each-database)
- [Tenant Types](#tenant-types)
  - [One shared schema per type](#one-shared-schema-per-type)
  - [A type is not changed in place](#a-type-is-not-changed-in-place)
- [The Tenant Registry](#the-tenant-registry)
  - [Configuration is a seed](#configuration-is-a-seed)
  - [A tenant's status](#a-tenants-status)
  - [A cluster reads one registry](#a-cluster-reads-one-registry)
- [Starting a Multi-Tenant Server](#starting-a-multi-tenant-server)
  - [Per-tenant migrations](#per-tenant-migrations)
- [Resolving a Request's Tenant](#resolving-a-requests-tenant)
  - [Rejections](#rejections)
  - [A login binds the token to its tenant](#a-login-binds-the-token-to-its-tenant)
- [Tenant Tables and System Tables](#tenant-tables-and-system-tables)
- [Principals per Tenant](#principals-per-tenant)
- [Identity Federation per Tenant](#identity-federation-per-tenant)
- [What Is Tenant-Scoped](#what-is-tenant-scoped)
- [Framework Tables](#framework-tables)
- [Working in a Tenant Outside a Request](#working-in-a-tenant-outside-a-request)
- [Onboarding a Tenant](#onboarding-a-tenant)
- [Suspending a Tenant](#suspending-a-tenant)
- [Removing a Tenant](#removing-a-tenant)
- [Purging a Tenant](#purging-a-tenant)
- [Moving a Tenant](#moving-a-tenant)
- [Backing Up and Restoring a Tenant](#backing-up-and-restoring-a-tenant)
- [Operating Costs](#operating-costs)
- [Failure Keys](#failure-keys)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomTenancy` | class | The deployment's tenants, their resolution rules and their routing; installed once per process |
| `TomTenant` | class | One tenant: its id, type, display name, isolation model, schema and data sources |
| `TomTenantType` | class | A kind of tenant: the default and allowed isolation models, the data sources it routes, its migration tree; its shared tenants share one schema |
| `TomTenantRegistry` | abstract class | The durable list of tenants `TomTenancy` reads at install, writes every lifecycle change to and refreshes from |
| `TomMemoryTenantRegistry` | class | The registry in memory — a tenancy built in code, and tests |
| `TomSqlTenantRegistry` | class | The registry in the framework table `tom_tenant` of the system schema |
| `TomTenantRecord` | class | One tenant as the registry records it: type, isolation, data sources, status, migrated versions, created and updated |
| `TomTenantStatus` | enum | `provisioning`, `migrating`, `active`, `suspended`, `migration-failed`, `removed` |
| `TomTenantRegistryConflict` | class | A configured tenant its registry row contradicts, with the differences |
| `TomTenantRegistryRefresh` | class | What `refreshFromRegistry` changed on a node |
| `TomTenantRow` | class | One row of `tom_tenant`, as the data source's mapper reads it |
| `tenantTable` / `tenantTableDdl` | function | The `tom_tenant` table, declared once, and its DDL |
| `defaultTenantTable` | const String | `tom_tenant` |
| `TomTenantIsolation` | enum | `shared`, `schema` or `database` — where a tenant's rows live |
| `TomTenancyException` | class | A tenancy configuration that cannot be used, or a tenant that does not exist |
| `TomTenantResolver` | abstract interface class | Reads a tenant id from a request that carries no token claim |
| `TomTenantHostResolver` | class | Names the tenant by host: an exact host, or a subdomain of a suffix |
| `TomTenantPathResolver` | class | Names the tenant by the path segment after a prefix, `/t/<segment>` by default, mapping the segment to a tenant id when a lookup is given |
| `TomTenantHeaderResolver` | class | Names the tenant by a request header, `X-Tenant-Id` by default |
| `TomTenantResolution` | class | The outcome of resolving a request: a tenant, none, or a rejection |
| `TomTenantPoolSettings` | class | How the pools opened for tenants are sized: connections per tenant, the idle timeout, a deployment-wide cap |
| `TomTenantPurgeReport` | class | What `purgeTenant` dropped, kept and deleted for one tenant |
| `TomTenantData` | abstract interface class | A store of a system table that deletes a purged tenant's records |
| `TomTenancyStartup` | abstract final class | What the server's start makes of tenancy: plain, implicit or configured, and the contradictions it refuses |
| `TomTenancyMode` | enum | `plain`, `implicit` or `configured` |
| `TomTenantMoveReport` | class | What `moveTenant` copied, dropped and deleted |
| `TomTenantBackup` · `TomTenantTableBackup` | class | A tenant's rows in its tenant tables, as `exportTenant` writes and `importTenant` restores them |
| `TomTenantTables` · `TomTenantColumn` | abstract final class / class | The SQL that finds, counts, copies, exports and imports one tenant's rows of a table, and a column as the database describes it |
| `TomTenancyStartupReport` | class | What the start decided: the mode, the application's tenant tables, the warnings |

The module is eight files: `tenancy.dart` holds the configuration, the
provisioning, the routing and the lifecycle; `tenancy_startup.dart` what the
server's start makes of it; `tenant_tables.dart` a tenant's rows table by
table, for moves and backups; `tenant_data.dart` the stores'
purge contract; `tenant_type.dart` the tenant types;
`tenant_registry.dart` and `tenant_registry_sql.dart` the registry and its
table; `tenant_resolution.dart` the request-side resolvers.

## Tenancy and Migrations, End to End

This guide and [db_migration.md](db_migration.md) describe one path, which a
multi-tenant deployment walks in this order:

1. **Decide whether it needs tenancy.** The start decides from the tenant
   tables and the configuration — plain, implicit or configured
   ([Do I Need Tenancy?](#do-i-need-tenancy)).
2. **Mark its tables.** An entity with `@TomTenantTable` is a tenant's, every
   other one a system table in the system schema
   ([Tenant Tables and System Tables](#tenant-tables-and-system-tables)).
3. **Declare its tenant types**, each with its isolation models and a migration
   tree under `<root>/tenant/<type>/`, beside the system tree `<root>/system/`
   ([Tenant Types](#tenant-types);
   [the directory layout](db_migration.md#the-directory-layout)).
4. **Start.** `TomServer.start` installs the configured tenancy and checks it,
   migrates the system schema, each type's shared schema and every tenant of
   its own ([Tenants, by their type](db_migration.md#tenants-by-their-type)),
   and refuses a system schema the code does not fit; a tenant whose schema
   does not fit is refused per request while the others are served
   ([Rolling Deploys](db_migration.md#rolling-deploys-version-skew)).
5. **Serve.** A request names its tenant
   ([Resolving a Request's Tenant](#resolving-a-requests-tenant)); queued work
   keeps the tenant it was raised in, and a job declared per tenant type runs
   once in each ([What Is Tenant-Scoped](#what-is-tenant-scoped)).
6. **Run the tenants.** Onboard, suspend, remove, restore and purge them; move
   one to another isolation or type; back one up and restore it
   ([Onboarding a Tenant](#onboarding-a-tenant) and the sections after it).

[`multi_tenant_sample`](../../tom_core_samples/multi_tenant_sample/README.md)
walks this path live on MariaDB and PostgreSQL: two types, shared and schema
tenants, an application system table, a tenant onboarded at runtime, a job per
type, a move, a backup and a restarted node reading the registry.
[`core_server_sample`](../../tom_core_samples/core_server_sample/README.md) is
the other path: no tenant table, no tenancy, nothing configured.

## Do I Need Tenancy?

Usually there is nothing to decide: `TomServer.start` decides from the
application's tenant tables — its entities marked `@TomTenantTable` — and the
`tenancy` key of the configuration (`TomServer.configureTenancy`, through
`TomTenancyStartup.configure`), before it migrates:

| Tenant tables | `tenancy` configured | At start |
| --- | --- | --- |
| none | no | **plain** — nothing installed, nothing to configure |
| some | no | **implicit** — one tenant, `default`, of the type `default`, shared, its tenant tables in the system schema; work with no tenant in context runs as `default` (`TomTenancy.implicitTenant`). Nothing is installed: this is what a deployment without a `TomTenancy` already is |
| some | yes | **configured** — the configured tenancy installed and validated |
| none | yes | configured, with a warning: no entity is a tenant table and no tenant tree exists |

The answer is `TomTenancyStartupReport.mode` (`TomTenancyMode.plain`,
`implicit` or `configured`). A tenancy the application installed itself before
the start (`TomTenancy.install`) is kept and validated; only without one is the
`tenancy` key installed (`TomTenancy.fromConfiguration`).

Only the application's tenant tables count. The framework's own —
`TomUserPreference`, `TomPreferenceDefault`, the resource grants and
delegations, the external identities and their tokens, the 2FA enrolments
(`TomTenancyStartup.frameworkTenantEntities`) — are reflected into every server
that imports the package, used or not, so they make no deployment a tenant
deployment; their migrations are the framework's reference migrations.

A single-tenant deployment of a multi-tenant application therefore configures
nothing: its tenant tables carry the tenant `default` and live in the system
schema, migrated by `<root>/tenant/default/<datasource>/` when that tree exists
and by the system tree otherwise. Its system tables — every entity without
`@TomTenantTable` — are migrated by the system tree in every mode and need no
configuration.

### What the start refuses

| Contradiction | Key |
| --- | --- |
| A declared type without a migration tree | `tenancy.type.missing_migrations` |
| A configured or registered tenant of an unknown type | `tenancy.type.unknown` |
| A tree under `<root>/tenant/` for a type nobody declares — in the implicit case, any type but `default` | `tenancy.start.undeclared_type_tree` |
| A tenant table on a data source a type routes that the type's tree never creates (`CREATE TABLE` in `<tree>/<datasource>/`) | `tenancy.start.table_missing_from_type` |

The migration root is the `migrations` key's `root`, else
`databaseMigrationsDirectory`; a type with a tree of its own
(`TomTenantType.migrations`) is checked against that one. A type's tree that
does not exist is not asked for tables — only a declared type must have one.

## Tenant and Organization

The two words name different things, and the framework never infers one from
the other.

- A **tenant** is an **isolation boundary**: whose data a query may read, which
  database or schema a connection reaches, whose cache entries and queued jobs
  these are. Nothing crosses it. It is carried as `TomPrincipal.tenant`, as the
  token's `tenant` claim, and in the zone as `TomTenantContext.currentId`.
- An **organization** is a **business unit inside a tenant** — the
  `organization` a principal logs in for, which authorization and the execution
  context read, and which one tenant may have several of. It is carried as
  `TomPrincipal.organization` and the token's `organization` claim.

A deployment that sells to companies typically makes each customer a tenant and
lets the customer model its departments as organizations. The two can coincide
— a tenant with one organization of the same name — but that is the
deployment's choice, written into both fields; nothing here copies one into the
other. A token therefore carries both claims, independently:

```json
{ "username": "alice", "tenant": "acme", "organization": "sales" }
```

## Three Isolation Models

| Model | Where a tenant's rows live | Isolation | Operating cost |
| ----- | -------------------------- | --------- | -------------- |
| `TomTenantIsolation.shared` | the shared schema of its type — the system schema for the type `default`; every tenant table carries a tenant column | the row predicate | one schema and one migration run per type |
| `TomTenantIsolation.schema` | a schema of its own on the shared server — on MariaDB a database, on PostgreSQL a schema inside the one database | the schema boundary, and the predicate | one schema and one connection pool per tenant |
| `TomTenantIsolation.database` | a database of its own, configured per tenant — another server, another region | the server boundary, and the predicate | one database, one pool and one migration run per tenant |

Only tenant tables are placed by the model; a system table stays in the system
schema whatever the tenant (see
[Tenant Tables and System Tables](#tenant-tables-and-system-tables)). The row
predicate a tenant table carries applies **in every model**.
Under `schema` and `database` it is a second wall rather than the only one, and
it is what makes moving a tenant between models a copy of its rows rather than a
schema change: the rows already carry their tenant.

### The model is chosen per tenant

`TomTenancy.defaultIsolation` is the model of every tenant that names none, and a
tenant's own `isolation` overrides it. Most tenants can share one schema while
the one with a data-residency requirement gets a database of its own in its own
region, in one deployment and behind one code path. `isolationOf(tenant)` answers
which model a tenant actually runs under.

### How a data source is routed

Every model is reached through one seam. A repository asks
`TomDataSourceInfo.route` for its data source on every call (its
`datasourceInfo` is a getter, not a field), and `TomTenancy.install` installs
`TomTenancy.route` as `TomDataSourceInfo.router`. The answer depends on the
tenant in context:

| Tenant in context | Data source in `TomTenancy.datasources` | Answer |
| ----------------- | --------------------------------------- | ------ |
| none | either | the registered data source itself |
| any | no | the registered data source itself |
| a `shared` tenant | yes | the registered data source itself |
| a `schema` tenant | yes | the tenant's data source, opened over the tenant's schema |
| a `database` tenant | yes | the tenant's own data source |
| a tenant the deployment does not have | yes | refused: `tenancy.tenant.unknown` |

The last row is a refusal rather than a fall-back on purpose: routing an unknown
tenant to the shared data source would hand it everyone's rows.

`TomTenancy.datasources` names the data sources that hold tenant data —
`{'main'}` by default. A data source not named there is never routed, which is
how a deployment keeps a reporting database or a framework database shared.
Application code is the same under all three models; only the configuration
differs.

A routed data source is registered under `<name>@<tenant>` — `main@globex` —
beside the base one, so it can be looked up by name for maintenance.
`TomDataSourceInfo.getBaseDataSourceInfo(name)` answers the registered data
source without routing, whatever tenant is in context.

## Configuration

`TomTenancy.fromConfiguration()` reads the `tenancy` key
(`TomTenancy.configurationKey`) of the server configuration:

```yaml
tenancy:
  isolation: shared              # the default model (shared | schema | database)
  datasources: [main]            # the data sources holding tenant data
  resolution: [host, path, header]  # how a request without a token names its tenant, in order
  hostSuffix: app.example.com    # <tenant>.app.example.com
  pathPrefix: t                  # /t/<segment>/… for the path resolver
  pathSegments:                  # segment → tenant id, when URLs name tenants by a slug
    acme-gmbh: acme
  header: X-Tenant-Id            # the header the header resolver reads
  createSchemas: true            # create a schema tenant's schema at provisioning
  registry:                      # the tenant registry (see The Tenant Registry)
    datasource: main             # its system schema: the base schema of this data source
    refreshSeconds: 30           # how often each node re-reads it; 0 for never
  migrations: migrations         # the migrations root: a type's tree is <root>/tenant/<type>
  purgeAfterDays: 90             # how long a removed tenant's data is kept before purgeTenant
  pool: {perTenant: 4, idleSeconds: 60, maxTotal: 200}  # the tenant pools (see Operating Costs)
  types:                         # the tenant types (see Tenant Types); none: the type default
    standard:
      isolation: shared          # the default model of its tenants
      isolations: [shared, schema]   # the models its tenants may use
    enterprise:
      isolation: database
      datasources: [main]        # the data sources it routes
  tenants:                       # a seed for the registry
    acme: {type: standard}       # shared, in the type's schema main_standard
    globex: {type: standard, isolation: schema}  # schema main_globex
    initech:
      type: enterprise           # database, its type's default
      datasource:                # its own database, opened from these settings
        type: mariadb
        host: db.eu.example.com
        port: 3306
        databaseName: initech
        username: initech
        password: secret
```

| Key | Default | Meaning |
| --- | ------- | ------- |
| `isolation` | `shared` | The model of a tenant that names none. |
| `datasources` | `[main]` | The data sources routed per tenant. |
| `resolution` | none | `host`, `path`, `header`, or several in order. With none, only the token claim names a tenant. |
| `hostSuffix` | none | The domain tenants are subdomains of, for the `host` resolver. |
| `pathPrefix` | `t` | The path segments before the tenant's, for the `path` resolver: `t`, or `api/t`. |
| `pathSegments` | none | Segment → tenant id, for the `path` resolver. Without it the segment is the tenant id; with it only a listed segment names a tenant, and any other segment after the prefix is refused as an unknown tenant. |
| `header` | `X-Tenant-Id` | The header the `header` resolver reads. |
| `createSchemas` | `false` | Whether provisioning a `schema` tenant creates its schema if it does not exist — `CREATE DATABASE IF NOT EXISTS` on MariaDB, `CREATE SCHEMA IF NOT EXISTS` on PostgreSQL. |
| `registry` | a SQL registry on the first routed data source | `memory` keeps the tenants in the process; a map names the registry's `datasource`, `table` (`tom_tenant`), `createSchema` (`true`) and `refreshSeconds` (`30`; `0` for never). |
| `migrations` | none | The migrations root; a declared type that names no `migrations` has its tree at `<root>/tenant/<type>`. |
| `purgeAfterDays` | `90` | How many days a removed tenant's data is kept before `purgeTenant` may drop it; `restoreTenant` brings the tenant back meanwhile. |
| `pool.perTenant` | `4` | The most connections a tenant pool opens. |
| `pool.idleSeconds` | `60` | How long a tenant pool's connection may sit idle before a timer closes it. |
| `pool.maxTotal` | none | The most connections all tenant pools together may open; a pool that would pass it is refused (`tenancy.pool.cap_exceeded`). |
| `types` | none — the implicit type `default` | The tenant types, by name (a lower-case identifier of at most 32 characters). |
| `types.<type>.isolation` | the deployment's `isolation` | The model of the type's tenants that name none. |
| `types.<type>.isolations` | all three | The models the type's tenants may use; its own `isolation` must be one. |
| `types.<type>.datasources` | the deployment's `datasources` | The data sources the type routes per tenant. |
| `types.<type>.migrations` | `<migrations>/tenant/<type>` | The directory of the type's migration tree, which must exist when the tenancy is installed. |
| `tenants.<id>.type` | `default` | The tenant's type, which must be declared. |
| `tenants.<id>.name` | none | A display name. |
| `tenants.<id>.isolation` | its type's, else the deployment's | The tenant's model; its type must allow it. |
| `tenants.<id>.schema` | `<databaseName>_<id>` | Under `schema`, the schema's name. |
| `tenants.<id>.datasource` | — | Under `database`, the tenant's data source for the one routed name: a map of data-source settings to open, or the name of a data source already registered. |
| `tenants.<id>.datasources` | — | The same per routed name, when several data sources are routed: `{main: {...}, reporting: reporting_initech}`. |

A tenant id is a lower-case letter followed by up to 31 lower-case letters,
digits or underscores (`TomTenantContext.idPattern`). It is narrow on purpose:
the id names a schema in the stronger models, is part of cache keys and job
windows, and is written into tokens, so an id that is a safe identifier
everywhere is one that never needs quoting anywhere. A schema name is held to
letters, digits and underscores, at most 64.

The same configuration can be built in code — `TomTenancy`'s constructor takes
the tenants, the `types` (`TomTenantType`), the routed data sources, the
resolvers, the default model,
`createSchemas`, the `registry` (an in-memory one unless given), the
`refreshInterval`, `purgeAfter` and the tenant `pool` settings
(`TomTenantPoolSettings`):

```dart
final tenancy = TomTenancy(
  tenants: [
    TomTenant('acme', name: 'Acme'),
    TomTenant('globex', isolation: TomTenantIsolation.schema),
  ],
  resolvers: const [
    TomTenantHostResolver(suffix: 'app.example.com'),
    TomTenantHeaderResolver(),
  ],
);
```

### A schema on each database

A `schema` tenant's data source is the base data source with one setting
changed, and the base data source's dialect says which setting and how the
schema is created (`schemaSetting`, `createSchema`):

| Database | A tenant's schema is | Created with | The setting changed |
| -------- | -------------------- | ------------ | ------------------- |
| MariaDB | a database on the shared server | `` CREATE DATABASE IF NOT EXISTS `<schema>` `` | `databaseName` |
| PostgreSQL | a schema inside the base data source's database | `CREATE SCHEMA IF NOT EXISTS "<schema>"` | `schema`, which the driver sets as each connection's `search_path` |

On PostgreSQL the tenants therefore share one database and one server role, and
the schema boundary is the `search_path`: an unqualified name resolves in the
tenant's schema. The schema name defaults to `<databaseName>_<id>` on both, so
the base data source has to name its `databaseName` on PostgreSQL too
(`tenancy.config.schema_unsupported` otherwise).

## Tenant Types

A tenant type is a kind of tenant: the model its tenants use unless they name
one, the models they may use, the data sources it routes, and its own migration
tree — the tenant tables a tenant of the type has. A trial tenant and an
enterprise tenant are typically two types. Every tenant names its type
(`TomTenant.type`, `default` when it names none), and the registry stores it.

| Declared types | The deployment has |
| -------------- | ------------------ |
| none | one implicit type, `default`: every model allowed, the deployment's `isolation` and `datasources`, no migration tree to check |
| some | exactly those; a tenant naming no type is of `default`, which then has to be declared too |

```dart
final tenancy = TomTenancy(
  tenants: [
    TomTenant('acme', type: 'standard'),
    TomTenant('initech', type: 'enterprise'),
  ],
  types: [
    TomTenantType(
      'standard',
      isolation: TomTenantIsolation.shared,
      isolations: {TomTenantIsolation.shared, TomTenantIsolation.schema},
      migrations: 'migrations/tenant/standard',
    ),
    TomTenantType(
      'enterprise',
      isolation: TomTenantIsolation.database,
      datasources: {'main'},
      migrations: 'migrations/tenant/enterprise',
    ),
  ],
);
```

A tenant's model is its own `isolation`, else its type's, else the deployment's
(`isolationOf`); `typeOf` answers its type, and `datasourcesOf(type)` the data
sources the type routes (`routedDatasources` is their union, what `route`
considers). The refusals, each with a key:

| Refused | When | Key |
| ------- | ---- | --- |
| a type name that is not one | the type is constructed | `tenancy.type.invalid` |
| a type whose own `isolation` is not among its `isolations` | the type is constructed | `tenancy.type.isolation_not_allowed` |
| a declared type without a migration tree — none named, or a directory that does not exist | `install`, before the registry is read | `tenancy.type.missing_migrations` |
| a configured tenant, or a registry row, of a type the deployment does not declare | `install` (a configured one before it is seeded), `addTenant`; a row another node wrote is reported by `refreshFromRegistry` in `failed` | `tenancy.type.unknown` |
| a tenant whose model its type does not allow | `install`, `addTenant`, `refreshFromRegistry` | `tenancy.type.isolation_not_allowed` |

### One shared schema per type

The shared-isolation tenants of one type share **one tenant schema**: for the
type `default` the system schema — the base data source's own, so a one-type
deployment keeps its tenant tables beside its system tables — and for every
other type `<databaseName>_<type>` (`TomTenantType.sharedSchema`), so two
types' trees never define one table twice in one schema. Every shared tenant of
the type reaches it through one pool, registered as `<name>@type.<type>` and
opened (and with `createSchemas` created) when the first of them is
provisioned; removing one of them leaves the pool to the others. A
`schema`-isolated tenant whose schema would be a type's shared schema is
refused (`tenancy.config.schema_collision`).

The shared schema is therefore **one migration target**: the type's tree is
applied to it once, however many shared tenants it holds, and the tenant
column keeps their rows apart. A `schema` or `database` tenant is a target of
its own.

### A type is not changed in place

A configured tenant whose type differs from its registry row is reported as a
conflict, and the row is used ([Configuration is a seed](#configuration-is-a-seed)).
`addTenant` for a tenant the registry holds — not removed — under another type
is refused (`tenancy.type.change`): a tenant of another type has other tables,
so changing its type moves its data. A tenant that was removed may be added
again as another type.

## The Tenant Registry

A `TomTenantRegistry` is the durable list of the deployment's tenants. In a
configured deployment it is `TomSqlTenantRegistry`, the framework table
`tom_tenant` in the **system schema** — the base schema of the registry's data
source, never routed, so it is read and written unrouted also inside a tenant.
One row per tenant holds its id, type, name, isolation, schema, data sources,
status (with the detail of the last change), the migration version applied per
`<datasource>/<schema>`, and when it was created and last changed. A tenancy
built in code without a registry keeps an in-memory one
(`TomMemoryTenantRegistry`), which is what tests and a single-process tool
want.

The store creates its table on first use; a deployment whose database user may
not run DDL applies the reference migration
`example/tenancy/migrations/system/main/tomcore/[1]-create_tom_tenant.sql` (or
`migrations_postgresql/`) to the system schema and configures
`registry: {createSchema: false}`.

### Configuration is a seed

At `install` the registry is read. A configured tenant the registry does not
hold yet is written into it as `active`; one it holds is taken from the
registry, and where the configuration says something else — another type,
isolation, schema or data sources, or a tenant the registry records as removed
— the difference is reported in `TomTenancy.registryConflicts` and logged, and
the row is used. A tenant the registry holds and the configuration does not
name is served all the same: tenants added at run time survive a restart. So
the configuration seeds a new deployment and is not a second source of truth.

A literal `password` in a tenant's data-source settings is never written into
the table: the row holds the settings without it, and the configured tenant's
password is merged back in when the tenant is read. A cluster that adds
`database` tenants at run time names their passwords by `secret:` reference,
which the row does hold.

### A tenant's status

| Status | Served | A request is answered |
| ------ | ------ | --------------------- |
| `provisioning` | no | `503`, `tenancy.tenant.unavailable` |
| `migrating` | no | `503`, `tenancy.tenant.unavailable` |
| `active` | yes | — |
| `suspended` | no | `403`, `tenancy.tenant.suspended` |
| `migration-failed` | no, and not routed | `503`, `tenancy.tenant.migration_failed` |
| `removed` | not routed at all | `404`, `tenancy.tenant.unknown` |

`addTenant`, `suspendTenant`, `resumeTenant` and `removeTenant` write the
tenant's new status into the registry **before** they change this node's
routing, and `statusOf(id)` answers a served tenant's status.

An `active` tenant is served only while its schema serves this node's code:
a schema behind the node's type tree is refused with `503`,
`tenancy.tenant.schema_behind`, one ahead by a migration not marked expand with
`503`, `tenancy.tenant.schema_ahead` — judged on each node at install, on every
refresh and after `migrateAll` (`checkSchemaVersions`, `schemaCheckOf(id)`); see
[db_migration.md](db_migration.md#a-tenant-behind-or-ahead).

### A cluster reads one registry

Every node of a cluster reads the same registry. `refreshFromRegistry()` brings a
node level with it: a tenant another node added is provisioned and served, one
it removed is unrouted and its pools closed, and a changed status takes effect;
a tenant that cannot be provisioned on this node is reported in the result's
`failed` and tried again at the next refresh. An installed tenancy with a
`refreshInterval` (`registry.refreshSeconds` in configuration, 30 seconds by
default) refreshes by itself; `reset` stops it.

## Starting a Multi-Tenant Server

Tenancy is installed after the data sources are registered and before the
server serves its first request. `TomServer.start` installs the `tenancy` key
itself ([Do I Need Tenancy?](#do-i-need-tenancy)); a process that does not
start a `TomServer` — a worker, a migration job — installs it in code:

```dart
await TomDataSourceInfo.initializeDatasourceInfo(datasourceConfiguration);
await TomTenancy.install(TomTenancy.fromConfiguration());
```

`install` reads the [registry](#the-tenant-registry) and seeds it with the
configured tenants it lacks. It then provisions every tenant the registry holds
and has not removed — a `schema` tenant's schema is created
(with `createSchemas`) and a data source is opened over it; a `database`
tenant's data source is opened from its settings or looked up by name — and only
then publishes the configuration as `TomTenancy.current` and installs the
router. A tenant whose provisioning fails fails the install, before any request
can reach it. Installing again replaces the previous configuration and closes
the data sources it opened; `TomTenancy.reset()` removes it altogether.

A deployment that never installs a tenancy is unaffected by the module:
`TomTenancy.current` is `null`, no data source is routed, the request pipeline
resolves no tenant, and every key is spelled as it always was.

### Per-tenant migrations

One call migrates the deployment: `TomDbMigrations.migrateAll(root)`, once the
tenancy is installed. The migration root holds two trees:

```text
migrations/
  system/<datasource>/<schema>/   # the system schema: framework and system tables
  tenant/<type>/<datasource>/     # each tenant type's tenant tables
```

It applies, in order:

1. `system/` to the system schema — fatal on failure, nothing else runs;
2. each type's tree **once to the type's shared schema**, for its
   shared-isolation tenants (the system schema for the type `default`);
3. each type's tree to **each tenant with a schema or database of its own**.

```dart
await TomTenancy.install(TomTenancy.fromConfiguration());
final result = await TomDbMigrations.migrateAll('migrations');
```

Every target keeps its own versioning table, `tenant_<type>_versioning` for a
type's tree, so a target is brought to the current version by the same call
whenever it runs. Its tenants are `migrating` meanwhile, then `active`, or
`migration-failed` with the error in their registry row; a failing tenant does
not stop the others, and is refused (`tenancy.tenant.migration_failed`, 503)
and not routed until `migrateAll(root, tenant: id)`, `TomTenancy.migrateTenant(id)`
or a start script's `--migrate-tenant=<id>` migrates it again. Each target is migrated under its database's migration lock
and the registry's lock of the target, so two processes never migrate one
tenant at once; `parallelism` bounds how many migrate at once. See
[db_migration.md](db_migration.md#tenants-by-their-type).

Keeping the two trees apart is what keeps the framework's system tables out of
every tenant's schema — see [Framework Tables](#framework-tables).

## Resolving a Request's Tenant

With a tenancy installed, `tomDefaultAuthenticationMiddleware` resolves every
request's tenant through `TomTenancy.resolveRequest` and runs the request inside
`TomTenantContext.run`. The rules, in order:

1. **The verified token's `tenant` claim is authoritative.** A request carrying
   one is for that tenant.
2. **Without a claim, the resolvers are asked in order**, and the first answer
   wins. These are the requests that have not authenticated yet — the login, a
   public page, an identity provider's redirect.
   - `TomTenantHostResolver` answers an exact entry of its `hosts` map first
     (`{'portal.acme.com': 'acme'}`, for a tenant on a domain of its own), then
     the first label of a host one level under its `suffix`
     (`acme.app.example.com` under `app.example.com`). A host deeper than one
     label under the suffix names nothing.
   - `TomTenantPathResolver` answers the path segment after its `prefix`
     (`/t/acme/sign-in` names `acme` under the default prefix `t`), mapped
     through its `lookup` when it has one. That is how a deployment names
     tenants in its URLs and issuers by a slug other than the tenant id: the
     lookup maps `acme-gmbh` to `acme`. A segment the lookup does not know is
     refused as an unknown tenant (`404`) rather than taken for no tenant, so
     a mistyped or retired slug never reaches a page as an anonymous request. A
     path outside the prefix names nothing. The resolver only names the tenant;
     serving the routes under the prefix is the deployment's router's.
   - `TomTenantHeaderResolver` answers the value of its header, trimmed.
3. **No answer is not a rejection.** The request proceeds in an explicit
   no-tenant context; tenant tables are closed to it
   (`tenancy.context.missing`), and system tables are served normally.

A header is the weakest of the sources, because a client chooses it freely. It
is safe here because it only ever *proposes* a tenant: data stays closed until a
login in that tenant succeeds, and once a token exists its claim wins and a
contradicting header, host or path is refused.

### Rejections

A refused request is answered by the middleware itself, before any handler runs,
so nothing downstream ever sees a request in a tenant it may not enter. The
body is a small JSON object carrying the key and a message:

```json
{ "error": "tenancy.resolution.conflict", "message": "The request names a different tenant than its token." }
```

| Status | Key | When |
| ------ | --- | ---- |
| `403` | `tenancy.resolution.conflict` | The host, path or header names another tenant than the token's claim. A token is not a pass to another tenant. |
| `404` | `tenancy.tenant.unknown` | The request names a tenant the deployment does not have — a path segment the path resolver's lookup does not know included. |
| `400` | `tenancy.id.invalid` | The request names something that is not a tenant id. |
| `403` | `tenancy.tenant.suspended` | The tenant is suspended ([Suspending a Tenant](#suspending-a-tenant)). |
| `503` | `tenancy.tenant.unavailable` | The tenant is provisioning or migrating. |
| `503` | `tenancy.tenant.migration_failed` | The tenant's migration failed. |
| `503` | `tenancy.tenant.schema_behind` | The tenant's schema is behind this node's code. |
| `503` | `tenancy.tenant.schema_ahead` | The tenant's schema is ahead of this node's code by a migration not marked expand. |

### A login binds the token to its tenant

A login runs inside the tenant its request resolved to, and
`TomAuthenticationServer` binds the principal to that tenant before minting the
token: `TomPrincipal.tenant` is set to `TomTenantContext.currentId`, and the
token carries it as its `tenant` claim. From then on the claim decides, by rule
1. A principal the authentication service already placed in **another** tenant
is refused with `login.error.tenant-mismatch` — an account of one tenant signing
in through another tenant's host would otherwise receive a token for the tenant
it reached. A service that places no tenant on its principals leaves the choice
to the request. See
[authentication.md](authentication.md#tenancy-and-the-token) for the
authentication side.

## Tenant Tables and System Tables

Every entity is a **tenant table** — declared with `@TomTenantTable`
(object_persistence) — or a **system table**, every other entity:

```dart
@tomReflector
@TomTenantTable()
@TomDbTable(datasource: 'main', table: 'invoice', primaryKeyFields: ['id'])
class Invoice {
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  @TomDbColumn(columnName: 'tenant_id')
  String? tenantId;

  @TomDbColumn(columnName: 'amount')
  int amount = 0;
}
```

The classification, not a data-source name, decides where a repository reads
and writes. Data-source names stay — a deployment may have `main` and
`reporting` — but a data source's tenant tables are routed and its system
tables never are:

| Table | Tenant in context | Data source |
| ----- | ----------------- | ----------- |
| system | any, or none | the base data source, unrouted — the system schema, also inside a tenant |
| tenant | a `schema` or `database` tenant | the tenant's own schema or database |
| tenant | a `shared` tenant | its type's shared schema — the system schema for the type `default`, `<databaseName>_<type>` otherwise |
| tenant | none, under an installed tenancy | refused: `tenancy.context.missing` |
| tenant | none, with no tenancy installed | the base data source, as the implicit tenant `default` |

`TomTenancy.tenantForWork(what)` answers which tenant tenant-table work runs
as — the tenant in context, else `TomTenancy.implicitTenant` (`default`) when
no tenancy is installed — and throws `tenancy.context.missing` otherwise; an
installed tenancy never guesses whose rows these are. `TomTenancy.tenantTables`
is the set of tenant tables the code declares, as the annotation analyzer
reports them, each with its `@TomDbTable`.

Every tenant table has the tenant column (the annotation's `field`, `tenantId`
by default) **in every isolation model**, because any tenant may be moved to
another model. The repository then:

- adds `<field> = <tenant>` as a bound predicate to every read — `findAll`,
  `findById`, `count`, `findByQuery`, the existence checks, `historyOf`;
- lets an update or delete touch only rows that predicate admits;
- fills an unset tenant field on insert with the tenant, and refuses an entity
  naming another tenant (`data_scope.write.foreign_tenant`) — which also stops
  an update from moving a row to another tenant.

The predicate is independent of `@TomDbScope` and is ANDed with it, so an
entity can be a tenant's *and* scoped to its owner or to a resource grant. Unlike
the data scope it is not suppressed while an async scope resolver computes its
visible ids: a resolver working out one tenant's rows must not read another
tenant's to do it.

A tenant table and a system table **never meet in one statement**: a
`@TomReference`, a subquery or a repository over both kinds is refused when it
is analysed (`annotation_analyzer.tenant_table.mixed`), because a tenant's rows
may move to a database of their own at any time. They refer to each other by
id. **One transaction** may hold both: on one data source it is one branch; for a
tenant whose data source reaches the system schema — `schema` isolation, a
type's shared schema, a `database` tenant on the same MariaDB server — it is
one branch too, the system table running on the tenant's connection with its
table qualified; otherwise on two two-phase (`*_xa`) data sources it commits in
two phases, and on two data sources of which one is one-phase it is refused
(`crud_repository.transaction.tenant_and_system_one_phase`). See
[object_persistence.md](object_persistence.md#tenant-tables-and-system-tables)
for the repository side.

The framework's own per-tenant entities are tenant tables: the preferences and
preference defaults, the resource grants and grades, the delegations, the 2FA
enrolments and the external identities with their provider tokens. Each has a
`tenant_id` column (`DEFAULT 'default'`) leading its unique key. Sync keeps a
tenant table's change log beside the tenant's rows, and a retention run with no
tenant applies a tenant table's policy in every tenant.

## Principals per Tenant

**A principal id is unique within its tenant, and only there.**
`TomPrincipal.id` is a string — a deployment uses whatever identifies its
accounts, a UUID, a directory's object id, a database key rendered as text — and
another tenant may hold a principal with the same id, or the same username. That
is a different person: the same rule revocation states for usernames.

Every framework table that files rows per principal keys them by the
**tenant-qualified id**, `TomPrincipal.qualifiedId` — `tenant:<tenant>/<id>`,
spelled by `TomTenantContext.qualify` like every other tenant-scoped key, and
the bare id in a deployment without tenancy:

| Table | Column | Written by |
| ----- | ------ | ---------- |
| `tom_user_two_factor_enrolment` | `principal_id` | `Tom2FAEnrolmentStore.principalKeyOf` — the two shipped 2FA stores, and the grace store |
| `tom_user_preference` | `principal_id` | `TomUserPreferences`, through the `owner` data scope |
| `tom_principal_resource_grant` | `principal_id` | the deployment; read through `TomResourceDataScope`, whose default key is `qualifiedId` |
| `tom_principal_delegation` | `delegator_id`, `delegate_id` | the deployment, in the same key as the grants |

The `owner` data scope resolves to `qualifiedId` as well, so a deployment's own
owner-scoped entity stores its owner the same way, in a string column. A
deployment without tenancy may keep an integer owner column — the bare id is
bound as the number it spells — but with tenancy an integer column cannot hold
`tenant:<tenant>/<id>`, and the scope then matches no row. A row naming another principal
than the caller — a grant for a colleague — qualifies that principal's id by the
tenant in context: `TomTenantContext.qualifyCurrent(id)`.

These tables lie on the routed data source `main`, so they follow the tenant's
isolation model, and the key is what makes all three models agree:

- under `shared` every tenant's rows sit in one table, and the qualified key is
  what keeps two tenants' `u1` apart;
- under `schema` and `database` each tenant's table is its own, and the key is
  the same — so moving a tenant between models stays a copy of its rows, and a
  tenant restored on its own brings back exactly its own rows.

The organization is not part of the key: a user's second factors, preferences
and grants are theirs in every organization of the tenant they sign in for.

## Identity Federation per Tenant

A tenant federates with identity providers of its own — its staff directory,
its customer's Entra ID — and provisions its users from them. Three parts of
the authentication module follow the tenant in context for that.

**SCIM.** The resources, the secrets and the requests are each tenant's own:

- `TomSqlScimStore.named('main')` resolves the data source through tenancy's
  routing on every call, so under `schema` and `database` isolation each
  tenant's resources live in its own schema or database — and a tenant restored
  on its own brings back its own. Every row also names its tenant, and every
  statement reads and writes only the rows of the tenant in context: under
  `shared`, where routing leaves every tenant in one table, that column is the
  wall. A `userName` is unique per tenant. `TomMemoryScimStore` keeps one
  partition per tenant.
- `TomScimProvisioning` takes secrets per tenant (`tenantBearerTokens`, or
  `scim.tenants.<id>.bearerTokens` in the configuration). A request is admitted
  only by a secret of the tenant it resolves to; the deployment's `bearerTokens`
  admit only requests outside every tenant, so no single secret writes into
  every tenant.
- The SCIM endpoints serve whichever tenant the request resolves to — by host,
  by header, or by a path segment the deployment's router strips before the
  `/scim/v2/…` routes.

**The pending state of an external sign-in.** A flow completes only in the
tenant it began in. `TomOAuthAuthorizationState.tenant` records the tenant of the
request that began the flow, and both state stores answer `peek` and `consume`
with records of the tenant in context only: a callback that reaches another
tenant fails as `oauth.flow.unknown_state` and cannot spend the flow either.
`tom_oauth_state` stays one deployment-wide table — a record lives minutes and
needs no schema of its own, only its `tenant` column and the predicate.

**Provider configuration.** `TomOAuthProviders.tenants` and
`TomSamlProviders.tenants` hold a provider set per tenant. A sign-in in a tenant
with a set of its own offers and accepts only those providers; a tenant without
one uses the deployment's set. The sets are read from
`oauth.tenants.<id>.providers` and `saml.tenants.<id>.providers`
(`loadTenants()`), or installed at run time by a deployment that keeps its
federation sources in its own database:

```dart
TomOAuthProviders.tenants.install(
  'acme',
  await TomOAuthProviders.discover(acmeProviderSettings),
);
TomOAuthProviders.tenants.remove('acme'); // back to the deployment's set
```

A tenant's providers name redirect URIs of the tenant's own — its host or path —
so the provider's callback resolves to the tenant that began the flow.

**Tenant and organization from a Tom identity provider.** An application that
signs its users in through a Tom identity provider (Tom UAM) reads the tenant and
the sign-in organization from the provider's token or assertion
(`tenantClaim`, `organizationClaim` — see
[authentication.md](authentication.md#claim-mapping-tenant-and-organization)).
A claimed tenant other than the request's is refused as
`login.error.tenant-mismatch` before any account is linked or provisioned; the
claimed organization is the session's.

## What Is Tenant-Scoped

| Concern | How it is kept per tenant | Guide |
| ------- | ------------------------- | ----- |
| Repositories | a tenant table (`@TomTenantTable`): data source routed per tenant, the tenant predicate on every read and write; a system table: never routed | [object_persistence](object_persistence.md#tenant-tables-and-system-tables), [datasources](datasources.md#routing-per-tenant) |
| Caches | `TomCache`'s static API qualifies every key by the tenant in context — two tenants caching `plan` hold two entries | [cache](cache.md#tenant-scoped-entries) |
| Principal revocation | `revokePrincipal('alice')` in a tenant revokes that tenant's `alice` only; another tenant's `alice` is a different person | [authorization](authorization.md#revocation-per-tenant) |
| Per-principal rows | 2FA enrolments, preferences, resource grants and delegations are tenant tables, and are keyed by the tenant-qualified principal id; another tenant's `u1` is a different person | [Principals per Tenant](#principals-per-tenant) |
| SCIM | `TomSqlScimStore.named` routed per tenant with a `tenant` column; secrets per tenant | [Identity Federation per Tenant](#identity-federation-per-tenant) |
| External sign-in | a pending flow completes only in the tenant it began in; provider sets per tenant | [Identity Federation per Tenant](#identity-federation-per-tenant) |
| Jobs | a run records its tenant; its body runs inside it, across a worker isolate too; its window and its overlap protection are per tenant | [scheduling](scheduling.md#runs-per-tenant) |
| Messaging outbox | a message is queued for the tenant in context and delivered inside it; its receipt and its delivery correlation name the tenant; queued inside a transaction under `schema` isolation, it commits with the tenant's writes | [messaging](messaging.md#messages-per-tenant) |
| Delivery reports | `tom_delivery_report.tenant` attributes a carrier's report, which arrives carrying nothing but the carrier's id, to its tenant | [messaging](messaging.md#messages-per-tenant) |
| Idempotency keys | a key is scoped to the tenant in context, its principal and the operation; `tom_idempotency_key` is a tenant table, kept in the tenant's data source | [endpoints](endpoints.md#stores-clusters-and-tenants) |
| Sagas | a saga belongs to the tenant it began in, and its steps and compensations run inside it; `tom_saga` is a tenant table, kept beside the data its steps change; a resumption looks into every tenant | [transactions](transactions.md#sagas-per-tenant) |
| Field-encryption keys | a tenant table's values are encrypted under the tenant's own data keys, kept in its data source; a system table's under the system's; the re-encryption pass runs a tenant entity in every tenant |
| Audit trail | every entry records the tenant in context; `TomAuditQuery(tenant: …)` reads one tenant's entries | [audit](audit.md) |
| Blobs | the manifest records the tenant a blob was written in; `keysOfTenant` lists a tenant's blobs | [file_storage](file_storage.md) |
| Message inbox | `tom_message_inbox` is a tenant table, reached in the tenant's data source, so a message is recorded with the consumer's writes | [messaging](messaging.md) | [object_persistence](object_persistence.md#tenancy) |

A tenant-scoped key is spelled one way everywhere —
`TomTenantContext.qualify(name, tenant)`, which is `tenant:<id>/<name>`, or the
bare name with no tenant. A value meant for every tenant is cached, or a
principal revoked, outside any tenant's context.

## Framework Tables

Every table the framework itself owns is declared once, as a
`TomFrameworkTable`, and its descriptor names its kind (`TomTableKind`, see
[datasources.md](datasources.md#framework-owned-tables)). The kind, not the data
source a store was built over, decides where its rows live:

- a **system** table is kept once, in the system data source — the base data
  source, never routed, also when a tenant is in context;
- a **tenant** table is kept where the tenant in context's data lives — the
  tenant's own schema or database, or its type's shared schema — and every row
  names its tenant.

One rule places every store. `TomFrameworkTable.placedInfo(held)` answers the
data source for the data source a store holds: for a system table the
registered base of what it holds (`systemInfoOf`, so a store handed a tenant's
pool `main@acme` still writes to `main`), for a tenant table that base routed
for the tenant in context (`TomDataSourceInfo.route`). A system store places
once, in its constructor; a tenant store places on every call, so one store
built at start-up serves every tenant. A data source registered under no name
— a test's fake, a private pool — is used as it is.

| Table | Store | Placement | Tenant |
| ----- | ----- | --------- | ------ |
| `tom_tenant` | `TomSqlTenantRegistry` | system | the row is the tenant |
| `tom_job_run`, `tom_job_run_archive` | `TomSqlJobStore` | system | a `tenant` column; `''` for a run of no tenant; part of the unique window key |
| `tom_job_pause` | `TomSqlJobStore` | system | none — a pause holds for every tenant's runs of a job |
| `tom_lease` | `TomSqlLeaseLock` | system | none — a job's lease names its tenant |
| `tom_scheduler_node` | `TomSqlSchedulerNodes` | system | none — nodes serve every tenant |
| `tom_audit_trail` | `TomSqlAuditSink` | system | a nullable `tenant` column on every entry: the tenant in context when it was recorded |
| `tom_audit_question` | `TomSqlAuditQuestionStore` | system | an `owner` column |
| `tom_blob`, `tom_blob_chunk` | `TomDatabaseBlobStore` | system | a `tenant` column on the manifest; `''` outside a tenant |
| `tom_blob_ledger`, `tom_blob_content` | `TomSqlBlobLedger` | system | an `owner` column on each key, which a quota sums; contents are shared across owners |
| `tom_delivery_report` | `TomSqlDeliveryReportStore` | system | a nullable `tenant` column |
| `tom_message_suppression` | `TomSqlSuppressionList` | system | a nullable `tenant` column |
| `tom_oauth_state` | `TomSqlOAuthStateStore` | system | a `tenant` column; every read and the completion name the tenant in context |
| `tom_rate_limit` | `TomSqlRateLimiter` | system | none — a `principal` rule's counter key already names the tenant |
| `tom_service_account`, `tom_api_key` | `TomSqlApiKeyStore` | system | a nullable `tenant` column on the account, carried onto the principal its keys authenticate |
| `tom_cache_invalidation` | `TomSqlInvalidationChannel` | system | none — the keys it carries are already qualified |
| `tom_export` | `TomSqlExportRegister` | system | an `owner` column |
| `tom_transaction_decision` | `TomSqlDecisionLog` | system | none — a decision names the branches of every data source it spans |
| `tom_message_inbox` | `TomSqlInbox` | tenant | `tenant` leads the primary key |
| `tom_idempotency_key` | `TomSqlIdempotencyStore` | tenant | a `tenant` column |
| `tom_saga` | `TomSqlSagaStore` | tenant | a `tenant` column |
| `tom_encryption_key` | `TomSqlDataKeyStore` | tenant | `tenant` leads the primary key |
| `tom_subject_key` | `TomSqlSubjectKeyStore` | tenant | a `tenant` column |
| `tom_scim_resource` | `TomSqlScimStore` | tenant | a `tenant` column |
| `tom_sync_change`, `tom_sync_sequence` | `TomSync` | tenant | a `tenant` column |

The framework's eight per-tenant entities — preferences, preference defaults,
resource grants and grades, delegations, 2FA enrolments, external identities and
their provider tokens — are tenant tables by `@TomTenantTable`
([Tenant Tables and System Tables](#tenant-tables-and-system-tables)).

**A system table that does work for tenants carries the tenant.** The audit
trail, the blob manifest, the job queue (and the outbox on it), the delivery
reports and the suppression list record the tenant in context on every row, so
a tenant's records can be listed and exported from the one table:
`TomAuditQuery(tenant: 'acme')` reads one tenant's audit entries,
`TomDatabaseBlobStore.keysOfTenant('acme')` lists its blobs.

**Each tree holds its own kind.** The reference migrations come as two trees per
module — `example/<module>/migrations/system/main/tomcore/` for the system
tables, migrated once into the system schema, and
`example/<module>/migrations/tenant/default/main/` for the tenant tables,
migrated into every tenant's data source
([Per-tenant migrations](#per-tenant-migrations)).
`TomFrameworkSchemaCheck.verifyTree` checks a tree against its kind and reports
a table of the other kind built there as `misplacedTable`; see
[db_migration.md](db_migration.md#the-frameworks-own-tables).

**The job queue's write inside a transaction uses the tenant's connection.**
`tom_job_run` lives in the system data source, but a `TomSqlJobStore.enqueue`
— and the `findRun` before it — made inside a transaction of a tenant whose data
source is routed to one on the same server (`TomSqlDatasource.canQualify`: same
driver, host, port and user, on PostgreSQL also the same database) runs on the
tenant's data source and names the table qualified by the system schema
(`TomSqlDatasource.qualify`). That is what `schema` isolation gives: the row rides
on the tenant's transaction branch, so a message queued on the outbox commits or
rolls back with the tenant's business writes in one commit, and lands in the
system table the scheduler polls. Under `database` isolation on another server
`canQualify` fails and the store's own data source enlists as a second
participant — see
[messaging.md](messaging.md#queueing-inside-a-transaction) for what that commits.

**The message inbox lives with the consumer's writes.** `TomSqlInbox` records a
message in the same transaction as the consumer's own writes; as a tenant table
it is reached, on every call, in the tenant in context's data source
(`placedDatasource`), so one inbox built at start-up serves every tenant and the
consumer's work writes through the same data source:

```dart
final inbox = TomSqlInbox(TomDataSourceInfo.getBaseDataSourceInfo('app')!.datasource);

await tenancy.runFor(tenantId, () => inbox.process(
  'billing',
  message.id,
  () => invoices.record(message),
  acknowledge: message.ack,
));
```

**The idempotency keys follow the tenant.** `TomSqlIdempotencyStore` —
installed by `TomServer.start` when the `idempotency` configuration names a data
source — places that data source on every request: a request in a `schema` or
`database` tenant stores its key in that tenant's schema or database, created
there on first use or, with `createSchema: false`, by the migration in the
tenant tree. A shared tenant's keys go to its type's shared schema, where the
`tenant` column keeps them apart. See
[endpoints.md](endpoints.md#stores-clusters-and-tenants).

**The sagas live with the data their steps change.** A saga's step runs in a
local transaction with the update that moves the saga on, so `tom_saga` is a
tenant table, kept beside the data the steps write. The orchestrator's job runs
stay in the system queue and carry the tenant, and
`TomSagaOrchestrator.resume` — at start and on every sweep — runs in every tenant
of the installed tenancy, so each tenant's unfinished sagas are found in its own
data source. See [transactions.md](transactions.md#sagas-per-tenant).

**The data keys follow the table they encrypt.** The data keys of
`@TomEncrypted` columns are kept in `tom_encryption_key`, keyed by tenant. A
tenant table's values are encrypted under the tenant in context's keys, kept in
that tenant's data source — so a tenant's values share no key with another
tenant's, in a shared schema too. A system table's values are encrypted under
the system's keys (tenant `''` in the system data source), whatever tenant is
in context, so every tenant reads them back. `TomFieldEncryption.forEntity`
chooses by the entity's classification. A rotation acts on the keys of the
scope it runs in, so rotating every tenant's runs inside each
(`forEachTenant`); `TomFieldReencryption.run` re-encrypts a system entity once
and a tenant entity in every tenant of the installed tenancy. See
[object_persistence.md](object_persistence.md#tenancy).

**The subject keys live with the data they cover.** The privacy module's subject
keys — under which personal values in the audit trail are sealed, one key per
data subject — are kept in `tom_subject_key`, a tenant table: a `schema` or
`database` tenant's subject keys are kept in that tenant's schema or database,
a shared tenant's in its type's shared schema under its `tenant` column.
Erasing a subject shreds the key of the tenant in context, as it erases that
tenant's rows. See [privacy.md](privacy.md#tenancy).

## Working in a Tenant Outside a Request

Work that does not arrive as a request states its tenant explicitly:

| Call | Effect |
| ---- | ------ |
| `tenancy.runFor('acme', body)` | Runs `body` inside `acme`; refuses a tenant the deployment does not have (`tenancy.tenant.unknown`). |
| `tenancy.forEachTenant(body)` | Runs `body` once per tenant, in turn, inside each — a nightly job doing each tenant's work, a cache warm-up. |
| `TomTenantContext.run(null, body)` | Runs `body` explicitly outside every tenant. |

A job raised by an event names its tenant through `TomTenantEvent`, because a
stream listener runs in the zone it subscribed in, not the zone the event was
added from:

```dart
// Inside a request of tenant acme:
events.add(TomTenantEvent.inCurrentTenant({'invoice': 42}));
// From anywhere:
events.add(TomTenantEvent('globex', {'invoice': 7}));
```

A periodic job has no tenant of its own; one that does each tenant's work loops
over them in its body with `forEachTenant`.

## Onboarding a Tenant

```dart
final tenancy = TomTenancy.current!;
final run = await tenancy.addTenant(
  TomTenant('umbrella', isolation: TomTenantIsolation.schema),
);
```

One call onboards a tenant. `addTenant` records it in the registry as
`provisioning`, provisions its schema or database, migrates it by its type's
tree (`migrateTenant`, through `TomDbMigrations.migrateTenant`: `migrating`,
then `active`) and only then serves it, so a request naming the tenant cannot
arrive before its tables exist. It answers the migration run, `null` when the
type has no tree. No restart is needed and no configuration change: the next
start reads the tenant from the registry, and every node serves it from its
next refresh.

| What fails | The tenant | `addTenant` |
| ---------- | ---------- | ----------- |
| provisioning | `provisioning` in the registry, the error as its status detail, unserved | rethrows |
| the migration | `migration-failed`, the error as its status detail; refused (`503`, `tenancy.tenant.migration_failed`) and not routed — work in its context is refused by `route` | throws `tenancy.tenant.migration_failed` |

`migrateTenant(id)` migrates the tenant again once the cause is fixed (after a
`--repair-migration=tenant:<id>/…` on MariaDB, which records a failed script).
A shared tenant's target is its type's shared schema, which every shared tenant
of the type shares, so they go `migrating` together for the run.

## Suspending a Tenant

```dart
await TomTenancy.current!.suspendTenant('umbrella');
// ... later
await TomTenancy.current!.resumeTenant('umbrella');
```

`suspendTenant` records the tenant as `suspended`, after which its requests are
refused as `tenancy.tenant.suspended` (`403`) and its **queued work is held**:
the installed tenancy is the scheduler's tenant gate (`TomScheduler.tenantGate`,
`servesWork`), so a run of the tenant — a job, an outbox message, a relayed
publish — stays pending and unclaimed, on every node once it refreshed from the
registry. Its data and routes stay, so `resumeTenant` serves it again at once,
and its runs are claimed at the next tick. The gate holds the runs of every
tenant this node does not serve as `active`, a tenant it does not know yet
included. A job planned per tenant (`TomJobTenants`) plans no window for a
suspended tenant — the tenancy answers the scheduler its active tenants only
(`TomScheduler.tenantsFor`, `activeTenantsOf`) — and catches up the windows the
tenant missed, per its missed-window policy, once it is resumed. An
audit question of the tenant's auditor is held the same way.

## Removing a Tenant

```dart
final tenancy = TomTenancy.current!;
await tenancy.suspendTenant('umbrella');   // stop its traffic first
await tenancy.removeTenant('umbrella');
```

`removeTenant` is the counterpart of `addTenant`, for a tenant whose deletion is
final. It records the tenant as `removed` in the registry, then takes it out of
`tenants`, so from then on a request naming it — by its token's claim, its
host, its path or a header — is refused as `tenancy.tenant.unknown` (`404`),
and work still in its context is refused by `route` and `runFor`. It drops the
tenant's routes and closes the data sources the tenancy opened for it, which
closes their connection pools; a data source the tenant only named by
reference belongs to the deployment and stays open. Its **queued work is
cancelled**: every pending run of the tenant in the started schedulers' job
stores — and in `jobStores` — becomes `failed` with
`TomJobStore.tenantRemovedError`, so it never runs and the record stays; a run
already executing finishes. Other tenants are untouched.

Work that is still running in the tenant when its pools close fails, so a
deployment that needs it to finish suspends the tenant first. The registry row
stays, as `removed`, so the next start does not provision the tenant again even
if the configuration still names it (that is reported as a conflict).

The tenant's data is kept for the retention period, `purgeAfter` (90 days by
default, `tenancy.purgeAfterDays`). Until it is purged, `restoreTenant(id)`
serves the tenant again over the schema or database it left — provisioned and
migrated as by `addTenant`.

A system service that must not take a removed tenant's rows for no rows while
they can still come back reads them without serving it:
`removedTenantIds()` lists the removed tenants the registry keeps, and
`readRemovedTenant(id, body)` runs `body` in the tenant with its tenant tables
routed to its placement — its own pools opened for the call and closed after,
its type's shared schema, or the base data source — while requests and every
other work still find it unknown. The blob orphan sweep's
`TomRepositoryBlobReferences` asks them this way, so a removed tenant's files
stay until `purgeTenant` drops its data
([object_persistence.md](object_persistence.md#sweeping-files-no-row-refers-to)).
`readRemovedTenant` refuses a tenant that is not removed
(`tenancy.tenant.not_removed`) or that the registry does not hold
(`tenancy.tenant.unknown`).

## Purging a Tenant

```dart
final report = await TomTenancy.current!.purgeTenant(
  'umbrella',
  stores: [blobStore, apiKeyStore, deliveryReports, suppressions, oauthState],
);
```

`purgeTenant(id)` deletes a removed tenant's data for good, once its retention
period has passed (`force: true` skips the wait). It refuses a tenant the
registry does not hold (`tenancy.tenant.unknown`), one not removed
(`tenancy.purge.not_removed`) and one still within its retention period
(`tenancy.purge.retention`, naming the date). Then:

| The tenant's | Is |
| ------------ | -- |
| own schema (`schema` isolation) | dropped on each data source its type routes, through the dialect — `DROP DATABASE` on MariaDB, `DROP SCHEMA … CASCADE` on PostgreSQL |
| own database (`database` isolation) | dropped (`DROP DATABASE`, on PostgreSQL `WITH (FORCE)`) when the tenancy opened it on the base data source's server; a data source named by reference, or a database on another server, is the deployment's and is reported as kept |
| rows in its type's shared schema (`shared` isolation) | deleted from every tenant table there — the application's `@TomTenantTable` entities, by their tenant column, and the framework's tenant tables, by `tenant` |
| records in system tables | deleted by every store it is handed (`stores`, each a `TomTenantData`: the blob store, service accounts and API keys, delivery reports, the suppression list, OAuth sign-in state, saved audit questions) and by the job stores — the started schedulers' and `jobStores` — its queued and finished runs |
| audit trail | **kept**: its hash chain is not rewritten. The personal values it sealed for the tenant's data subjects become unreadable, because their subject keys were in the tenant's own tables, dropped or deleted above |
| registry row | deleted |

It answers a `TomTenantPurgeReport`: what was `dropped`, what was `kept` and
why, and the rows `deleted` per table and store.

## Moving a Tenant

```dart
final report = await TomTenancy.current!.moveTenant(
  'acme',
  isolation: TomTenantIsolation.schema, // and/or type:, schema:, datasources:
);
// acme: default/shared -> default/schema; copied {main/invoice: 1200}; deleted …
```

`moveTenant(id, {isolation, type, schema, datasources, keepSource})` moves a
served tenant to another isolation model, another type, another schema or other
data sources:

1. it suspends the tenant (unless it is suspended already), so nothing writes
   its rows meanwhile;
2. it provisions the target — the tenant's schema, its data source, the target
   type's shared schema — and migrates it by the target type's tree;
3. it checks every tenant table the tenant has rows in: the table must exist in
   the target with every column of the source — a target type whose tree does
   not take the data is refused before anything is copied
   (`tenancy.move.target_rejects`), and so is a target already holding rows of
   the tenant (`tenancy.move.target_not_empty`);
4. it copies each table's rows of the tenant — every row of a schema or
   database of its own, its rows by its tenant column out of a shared one — in
   one transaction per data source, and compares the counts
   (`tenancy.move.count_mismatch`). On one server
   (`TomSqlDatasource.canQualify`) a table is one `INSERT … SELECT`, every value
   as the database holds it; to another server the rows travel in the backup's
   text form ([below](#backing-up-and-restoring-a-tenant));
5. it switches the tenant's registry row to the new placement and routes the
   tenant there, then removes its data from the source as a purge would — a
   shared source's rows deleted, a schema or database the tenancy opened
   dropped — unless `keepSource`;
6. it migrates the tenant again, which records the versions, and resumes it if
   it was active.

The tenant's system-table rows — its queued jobs, audit entries, blobs and
delivery reports — stay where they are: its id does not change. A failure before
the switch leaves the tenant where it was, resumed when it was active; the copy
of the failing data source is rolled back. The answer is a
`TomTenantMoveReport`: `from` and `to` as `<type>/<isolation>`, the rows copied
by `<datasource>/<table>`, the source schemas dropped and rows deleted.

Moving into a shared schema whose other tenants use the same surrogate keys
fails on the first duplicate key, and the copy is rolled back: a tenant table
that is to be moved between shared schemas needs keys unique across tenants
(UUIDs, or keys the tenant column is part of).

| Refusal | Key |
| ------- | --- |
| The target is the tenant's placement | `tenancy.move.nothing_to_move` |
| A data source's target is the schema the tenant is in | `tenancy.move.same_place` |
| The tenant is provisioning, migrating or its migration failed | `tenancy.move.not_movable` |
| A target type or isolation that is not allowed | `tenancy.type.unknown`, `tenancy.type.isolation_not_allowed` |

## Backing Up and Restoring a Tenant

```dart
final backup = await tenancy.exportTenant('acme');
File('acme.json').writeAsStringSync(jsonEncode(backup.toJson()));
// … later, or on another server
await tenancy.importTenant(
  TomTenantBackup.fromJson(jsonDecode(File('acme.json').readAsStringSync())),
  replace: true,
);
```

`exportTenant(id)` answers a `TomTenantBackup`: for every routed data source,
every tenant table present in the tenant's placement (`TomTenantTables.present`:
the application's `@TomTenantTable` entities and the framework's tenant tables)
with its columns and the tenant's rows. Values are text — dates and instants as
the driver's temporal text, bytes in hexadecimal, SQL `NULL` as `null` — and
`toJson()` / `TomTenantBackup.fromJson` carry it as a JSON document
(`format: tom-tenant-backup/1`; another is refused with `tenancy.backup.invalid`).
The tenant's system-table rows are not in it.

`importTenant(backup, {replace})` writes the rows into the tenant's current
placement, which must be served and migrated: every table must exist there with
every backed-up column, on a data source the tenant's type routes
(`tenancy.import.target_rejects`), and hold no row of the tenant
(`tenancy.import.not_empty`) unless `replace`, which deletes them first. Values
are converted to the target column's type — a `CAST` on PostgreSQL, bytes from
hexadecimal on both — each data source's tables are written in one transaction,
and the counts are compared (`tenancy.import.count_mismatch`). A residency move
to another server is an export, the tenant added there with its new placement,
and an import.

## Operating Costs

- **Connection pools.** Every `schema` and `database` tenant has a data source
  of its own, and so a pool of its own — on PostgreSQL every pool counting
  toward the one database's `max_connections`. The tenancy keeps them small and
  quiet (`TomTenantPoolSettings`, `tenancy.pool`): each opens no connection until
  its tenant's first statement (`connectLazily`), holds at most `perTenant`
  connections (4 by default; `poolMaxSize`), and closes a connection idle for
  `idleSeconds` (60) even while nobody uses it (`poolSweepIdle`), so an idle
  tenant holds none. `maxTotal` caps the connections all tenant pools together
  may open: a pool that would pass it is refused when it is provisioned
  (`tenancy.pool.cap_exceeded`). A `database` tenant's own settings override
  these; a type's shared schema has one pool; `shared` tenants of the type
  `default` add none. Measured on MariaDB and PostgreSQL
  (`tenant_lifecycle_db_test.dart`, LCD-6): 120 concurrent statements over
  twelve tenant pools of two peaked at 24 connections and fell back to none once
  idle — the connections a deployment holds follow its busy tenants, not its
  tenant count, so tenants are not served from the base pool by switching the
  schema per checkout.

  ```yaml
  tenancy:
    pool: {perTenant: 4, idleSeconds: 60, maxTotal: 200}
    purgeAfterDays: 90
  ```

- **Migrations.** A `shared` deployment migrates once. Every `schema` or
  `database` tenant is one more migration run per release, and a release is
  complete only when every tenant's run succeeded — run `migrateAll` as part of
  the deployment (`--migrate`, or `migrations.onStart`), not on first request
  ([Per-tenant migrations](#per-tenant-migrations)).
- **Version skew during a rolling deploy.** Until every tenant's run of a
  release succeeded, tenants sit at two schema versions while nodes of two
  releases serve them. Each node refuses a tenant whose schema is behind its
  code, and one ahead of it by a migration not marked expand — `503`, while
  the other tenants are served — so a release whose migrations are all
  `-- tom:expand` rolls out with no tenant refused by the older nodes, and a
  contraction (dropping what the older release reads) waits for the release
  after ([db_migration.md](db_migration.md#expand-then-contract)). A tenant
  left behind by a failed run stays refused by the new release until it is
  migrated again.
- **Moving a tenant between models or types** is one call,
  `moveTenant` ([Moving a Tenant](#moving-a-tenant)): a copy of its rows into the
  new place and a switch of its registry row. The rows already carry their
  tenant, so no schema changes; the tenant is suspended for as long as the copy
  takes — one `INSERT … SELECT` per table on one server, a row-by-row write to
  another.
- **Backups and residency** are per tenant in every model: `exportTenant` reads
  a tenant's rows out of its tenant tables — out of a schema or database of its
  own, or by its tenant column out of a shared one — and `importTenant` restores
  them into its placement, on this server or another
  ([Backing Up and Restoring a Tenant](#backing-up-and-restoring-a-tenant)). A
  `database` tenant can also be backed up with the database's own tools, a
  `schema` one with a dump of its schema.

## Failure Keys

| Key | Raised by | Meaning |
| --- | --------- | ------- |
| `tenancy.start.undeclared_type_tree` | `TomTenancyStartup.configure` | A tree under `<root>/tenant/` for a type the deployment does not declare. |
| `tenancy.start.table_missing_from_type` | `TomTenancyStartup.configure` | A tenant table on a data source a type routes that the type's tree never creates. |
| `tenancy.move.nothing_to_move` | `moveTenant` | The target is where the tenant is. |
| `tenancy.move.same_place` | `moveTenant` | A data source's target is the schema the tenant is in. |
| `tenancy.move.not_movable` | `moveTenant` | The tenant is provisioning, migrating or its migration failed. |
| `tenancy.move.target_rejects` | `moveTenant` | The target lacks a table, or a column, the tenant has rows in. |
| `tenancy.move.target_not_empty` | `moveTenant` | The target holds rows of the tenant already. |
| `tenancy.move.count_mismatch` | `moveTenant` | A table's copied rows differ from the source's; the copy is rolled back. |
| `tenancy.backup.invalid` | `TomTenantBackup.fromJson` | The document is not a tenant backup. |
| `tenancy.import.target_rejects` | `importTenant`, `TomTenantTables.import` | The placement lacks a table or a column of the backup, or the type does not route its data source. |
| `tenancy.import.not_empty` | `importTenant` | A table holds rows of the tenant already, and `replace` is not set. |
| `tenancy.import.count_mismatch` | `importTenant` | A table's restored rows differ from the backup's; that data source's restore is rolled back. |
| `tenancy.config.not_a_map` | `TomTenancy.fromConfiguration` | `tenancy` or one of its tenants is not a map. |
| `tenancy.config.unknown_isolation` | `TomTenantIsolation.parse` | An isolation model other than `shared`, `schema` or `database`. |
| `tenancy.config.unknown_resolver` | `TomTenancy.fromConfiguration` | A tenant resolution other than `host`, `path` or `header`. |
| `tenancy.config.schema_unsupported` | provisioning | Schema isolation over a data source whose settings name no `databaseName`. |
| `tenancy.config.invalid_schema` | provisioning | A schema name that is not a plain identifier of at most 64 characters. |
| `tenancy.config.missing_datasource` | provisioning | Database isolation without a data source for a routed name. |
| `tenancy.config.unknown_datasource` | provisioning | A routed or referenced data source that is not registered. |
| `tenancy.config.invalid_registry` | `TomTenancy.fromConfiguration` | A `registry.refreshSeconds` that is not a whole number of seconds, 0 or more. |
| `tenancy.config.schema_collision` | provisioning | A `schema` tenant whose schema is a tenant type's shared schema. |
| `tenancy.type.invalid` | `TomTenantType` | A type name that is not a lower-case identifier of at most 32 characters. |
| `tenancy.type.unknown` | `install`, `addTenant`, `refreshFromRegistry`, `typeOf`, `isolationOf` | A tenant of a type the deployment does not declare. |
| `tenancy.type.missing_migrations` | `install`, `TomTenantType.verifyMigrations` | A declared type with no migration tree, or one whose directory does not exist. |
| `tenancy.type.isolation_not_allowed` | `TomTenantType`, `install`, `addTenant`, `refreshFromRegistry` | A tenant whose model its type does not allow, or a type whose own default it does not allow. |
| `tenancy.type.change` | `addTenant` | A tenant the registry holds under another type; changing a type moves the tenant. |
| `tenancy.tenant.unknown` | `route`, `runFor`, `resolveRequest`, `suspendTenant`, `resumeTenant`, `removeTenant` | Work or a request for a tenant the deployment does not have (`404` on a request; `clientThrow: true`). |
| `tenancy.tenant.suspended` | `resolveRequest` | A request for a suspended tenant (`403`). |
| `tenancy.tenant.unavailable` | `resolveRequest` | A request for a tenant that is provisioning or migrating (`503`). |
| `tenancy.tenant.migration_failed` | `resolveRequest`, `route`, `addTenant`, `migrateTenant` | A request for, or work in, a tenant whose migration failed (`503`) — it is not routed; or the migration of `addTenant` / `migrateTenant` failed. |
| `tenancy.tenant.not_removed` | `restoreTenant`, `readRemovedTenant` | The tenant to restore or read is not removed. |
| `tenancy.purge.not_removed` | `purgeTenant` | The tenant to purge is not removed. |
| `tenancy.purge.retention` | `purgeTenant` | The tenant's retention period (`purgeAfter`) has not passed; the parameter `until` names its end. |
| `tenancy.pool.cap_exceeded` | provisioning (`install`, `addTenant`, refresh) | Opening the tenant's pool would take the tenant pools past `tenancy.pool.maxTotal`. |
| `tenancy.config.invalid_number` | `TomTenancy.fromConfiguration`, `TomTenantPoolSettings.fromMap` | `purgeAfterDays` or a `pool` setting is not a whole number in range. |
| `tenancy.tenant.schema_behind` | `resolveRequest` | A request for a tenant whose schema is behind this node's code (`503`). |
| `tenancy.tenant.schema_ahead` | `resolveRequest` | A request for a tenant whose schema is ahead of this node's code by a migration not marked expand (`503`). |
| `tenancy.registry.unknown_tenant` | `TomTenantRegistry.setStatus`, `setMigrated` | A change to a tenant the registry does not hold. |
| `tenancy.registry.unknown_status` | `TomTenantStatus.parse` | A stored status this code does not know. |
| `tenancy.registry.unknown_datasource` | `TomSqlTenantRegistry` | The registry's data source is not registered. |
| `tenancy.resolution.conflict` | `resolveRequest` | A request naming another tenant than its token (`403`). |
| `tenancy.id.invalid` | kernel `TomTenantContext.validate`, `TomTenant`, `resolveRequest` | A tenant id that is not a lower-case identifier of at most 32 characters (`400` on a request). |
| `tenancy.context.missing` | kernel `TomTenantContext.require`, `TomTenancy.tenantForWork` | A tenant table read or written with no tenant in context under an installed tenancy. |
| `data_scope.write.foreign_tenant` | object_persistence | A tenant-table row naming another tenant than the one in context. |
| `annotation_analyzer.tenant_table.mixed` | object_persistence | A `@TomReference`, a subquery or a repository over tenant tables and system tables together. |
| `crud_repository.transaction.tenant_and_system_one_phase` | object_persistence | One transaction over a tenant table and a system table on two data sources, one of them one-phase, the tenant's not reaching the system schema. |
| `crud_repository.transaction.literal_on_tenant_connection` | object_persistence | A raw statement for a system table the transaction already runs on a tenant's connection. |
| `login.error.tenant-mismatch` | authentication | An account of one tenant signing in through another tenant. |

`TomTenancyException` extends `TomServerException`; the two kernel keys are
raised as the kernel's `TomTenantException`.

## Not Yet Implemented

- **A tenant's accounts are the authentication service's.** The framework binds
  a token to the tenant a login ran in and refuses a principal placed in another,
  but which accounts exist in which tenant is the deployment's
  `TomAuthenticationService` to decide — typically by reading them through a
  `@TomTenantTable` entity.
  <!-- unpinned: decision — account placement belongs to the authentication service -->

## Verification

`test/tenant_move_db_test.dart` (tagged `db`) covers moves and backups on
MariaDB and PostgreSQL: a shared tenant moved into a schema of its own and back
(its source rows deleted, the schema dropped), a type change into another
type's shared schema, a type whose tree does not take the data refused with the
tenant left where it was, a move into a database of its own on the same server
(on PostgreSQL out of reach of a qualified name, so copied through the backup's
text form), a backup carried through JSON and restored, and the
values of every column kind — numbers, booleans, instants, decimals, bytes,
`NULL` — exported and imported unchanged.

`test/tenancy_startup_test.dart` covers what the start makes of tenancy without a
database: a plain application and the implicit tenant installing nothing, a
configured tenancy installed from the `tenancy` key and one the application
installed kept, the warning for a tenancy with no tenant table and no tree, and
each refused contradiction with its key; it also holds
`TomTenancyStartup.frameworkTenantEntities` to every `@TomTenantTable` class the
package declares. `test/tenant_lifecycle_test.dart` and
`test/tenant_lifecycle_db_test.dart` (tagged `db`) cover onboarding,
suspension, removal, restoring and purging, the latter on MariaDB and
PostgreSQL.

`test/schema_version_guard_test.dart` covers the per-tenant [version
guard](db_migration.md#a-tenant-behind-or-ahead): a tenant never migrated is
refused with `tenancy.tenant.schema_behind` and served once `migrateAll`
migrated it, while another tenant stays refused and is listed by readiness; an
older release serves a tenant ahead by expand migrations and refuses one ahead
by a contract migration (`tenancy.tenant.schema_ahead`); and a refresh from the
registry judges again.

`test/tenancy_test.dart` covers the module without a database: resolving a
request's tenant by subdomain, by a host of its own and by header; the token
claim's authority and the refusal of a request naming another tenant; the
refusal of an unknown or malformed tenant and the acceptance of none; reading
tenants, models, data sources and resolution from configuration and refusing an
unknown model, resolver or tenant id; routing a shared tenant to the shared data
source and refusing a tenant the deployment does not have; `runFor` and
`forEachTenant`; the provisioning refusals; the request pipeline running a
request inside its tenant and refusing a token used for another; a deployment
without tenancy running every request in none; and a login binding its token to
its tenant and refusing an account of another.

`test/tenant_registry_test.dart` covers the registry without a database: the
in-memory store, the stored status names, the password never written; `install`
seeding the configured tenants, the registry winning over the configuration and
the conflict reported, a removed tenant not served; `addTenant`,
`suspendTenant`, `resumeTenant` and `removeTenant` writing the registry before
routing, and the request answers for each status; a second node's additions,
suspensions and removals reaching the first at its refresh, and the periodic
refresh; the `registry` configuration, and a registry over an unregistered data
source refused. `test/tenant_registry_db_test.dart`,
tagged `db`, runs the SQL store on MariaDB and PostgreSQL: every field's round
trip, and two nodes over one registry table, a schema-isolated tenant added on
one provisioned, routed and dropped by the other.

`test/tenant_table_test.dart` covers the classification without a database:
`@TomTenantTable` and `tenantTables`, the framework's own tenant tables, a
reference, a subquery and a repository mixing the two kinds refused, the data
source a repository picks inside and outside a tenant, `tenantForWork` and the
implicit tenant. `test/tenant_table_db_test.dart`, tagged `db`, runs it on
MariaDB and PostgreSQL with the tenant rows in the system schema, a type's
shared schema, a schema and a database of their own: rows landing where the
tenant lives and system rows in the system schema, the predicate in every
model, a transaction over both kinds run, refused or committed in two phases,
sync per tenant and retention in every tenant.

`test/tenant_type_test.dart` covers tenant types without a database: the
implicit type, `tenancy.types` and `tenancy.migrations` read from
configuration, each refusal (an invalid name, a disallowed default, a missing
tree, an unknown type — not seeded — and a disallowed model, at `install` and
`addTenant`), a type change refused while a removed tenant may come back as
another type, an unknown type reported by a refresh, routing only the data
sources a type routes, and the shared-schema name and its collision.
`test/tenant_type_db_test.dart`, tagged `db`, shows on MariaDB and PostgreSQL
two shared tenants of one type reaching one schema through one pool — a table
created once serves both — beside a schema tenant of the same type with its own
and a default-type tenant in the system schema.

`test/tenancy_db_test.dart`, tagged `db`, runs two tenants against the database
the DB suites run against — MariaDB or PostgreSQL — under
each of the three isolation models with the same assertions — that is the point
of one seam — and checks where the rows land: in the shared table under
`shared`, in each tenant's schema under `schema`, in each tenant's database under
`database`. It covers repositories, caches, revocations, jobs and the outbox.
`test/outbox_transaction_db_test.dart`, tagged `db`, holds the outbox's queue row
under `schema` isolation, with the store on the unrouted base data source, to
the tenant's transaction branch: rolled back with it, and committed into the
base schema, where the outbox's tick delivers it.
`tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`
(PostgreSQL) starts a database for it.

`test/principal_per_tenant_db_test.dart`, tagged `db`, runs `alice` with id `u1`
in two tenants under each model: each keeps her own 2FA enrolments and her own
preferences, and the stored key is `tenant:<tenant>/u1` in every model.
`test/tenancy_test.dart`'s group "one principal id in two tenants" covers the
same rule without a database for the in-memory 2FA and grace stores, the `owner`
scope and the resource-grant lookup.

`test/tenant_bound_stores_test.dart` covers SCIM through the request pipeline —
two tenants' clients each see only their own users, each tenant admits only its
own secret — the memory SCIM and state stores, a flow begun in one tenant
refused in another (also in `test/oauth_test.dart`), and provider sets per
tenant. `test/tenant_bound_stores_db_test.dart`, tagged `db`, runs the SQL SCIM
store and the SQL state store under each isolation model.

The kernel half is covered by `tom_core_kernel/test/tenant_context_test.dart`
and the tenant case of the kernel's job-store contract.

```bash
dart run example/tenancy/tenancy_example.dart
```

`example/tenancy/tenancy_example.dart` walks two tenants through eight steps
without a database: resolution by host and by header, the token's authority,
a login binding its token, cache entries, revocations, job runs, outbox
deliveries and the refusal of an unknown tenant. Every step checks its own
result, and `test/examples_test.dart` runs it.

## Core Components

- **`TomTenancy`** — the configuration (`tenants`, `types`, `typesDeclared`,
  `datasources`, `routedDatasources`, `datasourcesOf`, `resolvers`,
  `defaultIsolation`, `createSchemas`, `registry`, `refreshInterval`), its
  reading (`fromConfiguration`, `configurationKey`, `defaultRefreshSeconds`),
  its lifecycle (`install`, `reset`, `current`, `addTenant`, `suspendTenant`,
  `resumeTenant`, `removeTenant`, `statusOf`, `refreshFromRegistry`,
  `registryConflicts`), its routing (`route`, `isolationOf`, `typeOf`,
  `validateTenant`), work in a tenant
  (`runFor`, `forEachTenant`), request resolution (`resolveRequest`) and the
  refusal of an unknown tenant (`unknownTenant`); the tenant tenant-table work
  runs as (`tenantForWork`, `implicitTenant`) and the tenant tables the code
  declares (`tenantTables`).
- **`TomTenantRegistry`**, **`TomMemoryTenantRegistry`**,
  **`TomSqlTenantRegistry`** — the durable list of tenants; **`TomTenantRecord`**
  (one row), **`TomTenantStatus`**, **`TomTenantRegistryConflict`**,
  **`TomTenantRegistryRefresh`**, **`TomTenantRow`** (the mapped row);
  **`tenantTable`** / **`tenantTableDdl`** / **`defaultTenantTable`** — the table,
  declared once.
- **`TomTenantType`** — a tenant type: `name`, `isolation`, `isolations`,
  `datasources`, `migrations`, `sharedSchema`, `verifyMigrations`,
  `fromMap`, `treeUnder`, `namePattern`, `isolationNotAllowed`.
- **`TomTenant`** / **`TomTenantIsolation`** — one tenant (with its `type`,
  `defaultType` `default`) and its model;
  `TomTenant.fromMap` reads one from configuration and `TomTenantIsolation.parse`
  a model name.
- **`TomTenantResolver`**, **`TomTenantHostResolver`**,
  **`TomTenantHeaderResolver`** — the request-side sources of a tenant id.
- **`TomTenantResolution`** — a tenant, none, or a rejection with its status,
  key and message.
- **`TomTenancyException`** — every refusal this module raises.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `tenancy.dart`, `tenant_registry.dart` | `FutureOr`, the body type of `runFor` and `forEachTenant`; `Timer`, the registry refresh; `Completer` and `unawaited`, the registry's migration lock within the process |
| `dart:convert` | dart | `tenant_registry.dart` | `jsonEncode` / `jsonDecode`, the registry's `datasources` and `migrated` columns |
| `dart:io` | dart | `tenancy.dart`, `tenancy_startup.dart`, `tenant_type.dart` | `Directory`, whether a type's migration tree exists and the tree `codeVersionsOf` reads |
| `crypto` | package | `tenant_registry.dart` | `sha256`, a migration lock name too long for MariaDB hashed to fit |
| `path` | package | `tenancy_startup.dart` | `join` and `basename`, the trees under `<root>/tenant/` the start checks |
| `shelf` | package | `tenancy.dart`, `tenant_resolution.dart` | `Request`, which a resolver reads and `resolveRequest` resolves |
| `tom_core_kernel` | package | `tenancy.dart`, `tenancy_startup.dart`, `tenant_registry.dart` | `TomTenantContext` — the zone-carried tenant, the id rule and `qualify`; `TomDataSource`, `tomLog` and `tomReflector` |
| [authentication](authentication.md) | module | `tenancy_startup.dart` | `TomExternalIdentityLink`, `TomExternalIdentityToken` and `TomUserTwoFactorEnrolment` — framework tenant tables the start does not count |
| [authorization](authorization.md) | module | `tenancy_startup.dart` | `TomResourceGrant`, `TomPrincipalResourceGrant` and `TomPrincipalDelegation` — framework tenant tables the start does not count |
| [configuration](configuration.md) | module | `tenancy.dart`, `tenancy_startup.dart` | `TomServerConfigResourceProvider`, which `fromConfiguration` reads the `tenancy` key from |
| [datasources](datasources.md) | module | `tenancy.dart`, `tenant_registry.dart`, `tenant_registry_sql.dart`, `tenant_tables.dart` | `TomDataSourceInfo` — the registry routed per tenant, the data sources opened over a tenant's schema or database — and the base data source's dialect, whose `createSchema` and `schemaSetting` say how a schema is made and pointed at; and `TomFrameworkTable`, `TomSchemaProvisioning` and `sqlInstant` / `parseSqlInstant`, the registry's table and its instants |
| [db_migration](db_migration.md) | module | `tenancy.dart`, `tenancy_startup.dart` | `TomDbMigrations.treeVersions`, `requiresKey` and `resolveActiveEnvironment`, what a type's tree carries; `TomSchemaVersionCheck`, `TomSchemaSkew` and `TomMigrationRun.tenantTarget`, a tenant's schema check |
| [little_things](little_things.md) | module | `tenancy.dart` | `TomServerException`, the base of `TomTenancyException` |
| [object_persistence](object_persistence.md) | module | `tenancy.dart`, `tenancy_startup.dart`, `tenant_registry.dart` | `TomAnnotationAnalyzer.tenantTables` and `TomDbTable`, the tenant tables `tenantTables` reports; `@TomDbTable` / `@TomDbColumn`, the mapping of `TomTenantRow` |
| [preferences](preferences.md) | module | `tenancy_startup.dart` | `TomUserPreference` and `TomPreferenceDefault` — framework tenant tables the start does not count |
| [transactions](transactions.md) | module | `tenancy.dart` | `TomTransactionManager.runInTransaction` — a move's copy and a restore, one transaction per data source |
