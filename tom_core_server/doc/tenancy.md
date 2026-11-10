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

The module is five files: `tenancy.dart` holds the configuration, the
provisioning and the routing; `tenant_type.dart` the tenant types;
`tenant_registry.dart` and `tenant_registry_sql.dart` the registry and its
table; `tenant_resolution.dart` the request-side resolvers.

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
`createSchemas`, the `registry` (an in-memory one unless given) and the
`refreshInterval`:

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
| `migration-failed` | no | `503`, `tenancy.tenant.unavailable` |
| `removed` | not routed at all | `404`, `tenancy.tenant.unknown` |

`addTenant`, `suspendTenant`, `resumeTenant` and `removeTenant` write the
tenant's new status into the registry **before** they change this node's
routing, and `statusOf(id)` answers a served tenant's status.

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
server serves its first request:

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

A tenant's tables live where the tenant's data source points, so the migrations
that create them run once per tenant. The migration orchestrator looks its data
sources up through `TomDataSourceInfo.getDataSourceInfo`, which routes, so the
same tree applied inside each tenant lands in each tenant's schema or database:

```dart
// Deployment-wide tables — the framework's queue, leases and logs — once,
// outside any tenant.
await TomDbMigrations.migrateDatabases('migrations/deployment');

// Tenant tables, once per tenant: each run reaches that tenant's schema or
// database, or its type's shared schema, and a shared tenant's run is a no-op
// after the first of its type. The whole
// walk holds the migration lock, so no other process migrates between two
// tenants.
await TomDbMigrations.withMigrationLock(
  'main',
  () => TomTenancy.current!.forEachTenant(
    (_) => TomDbMigrations.migrateDatabases('migrations/tenant'),
  ),
);
```

Each tenant's schema or database, and each type's shared schema, keeps its own
versioning table, so a tenant added later is brought to the current version by
the same loop.

Every migration run takes its database's migration lock, so several replicas
starting together apply each script once (see
[db_migration.md](db_migration.md#one-run-per-database-at-a-time-the-migration-lock)).
Holding the lock of the base data source around the whole walk makes the walk
one unit: a replica starting during it waits for every tenant rather than
slipping in between two, and the tenants' own runs take their lock without
waiting for themselves, because it is re-entrant. The lock is named by
database, so the outer hold covers the tenants sharing the base data source's
database — the `shared` tenants and, on PostgreSQL, the `schema` tenants; a
tenant with a database of its own is serialised by its own run's lock. Keeping the two
trees apart is what keeps the framework's tables out of every tenant's schema —
see [Framework Tables](#framework-tables).

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
| `503` | `tenancy.tenant.unavailable` | The tenant is provisioning, migrating, or its migration failed. |

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
id. **One transaction** may hold both: on one data source it is one branch; on
two two-phase (`*_xa`) data sources it commits in two phases; on two data
sources of which one is one-phase it is refused
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
| `tenancy.forEachTenant(body)` | Runs `body` once per tenant, in turn, inside each — per-tenant migrations, a nightly job doing each tenant's work, a cache warm-up. |
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
await tenancy.addTenant(
  TomTenant('umbrella', isolation: TomTenantIsolation.schema),
);
await tenancy.runFor(
  'umbrella',
  () => TomDbMigrations.migrateDatabases('migrations/tenant'),
);
```

`addTenant` records the tenant in the registry as `provisioning`, provisions its
schema or database, records it as `active`, and only then serves it, so a
request naming the tenant cannot arrive before its data source exists. A
provisioning that fails leaves the tenant `provisioning` in the registry, with
the error as its status detail, and unserved. No restart is needed and no
configuration change: the next start reads the tenant from the registry, and
every node serves it from its next refresh.

## Suspending a Tenant

```dart
await TomTenancy.current!.suspendTenant('umbrella');
// ... later
await TomTenancy.current!.resumeTenant('umbrella');
```

`suspendTenant` records the tenant as `suspended`, after which its requests are
refused as `tenancy.tenant.suspended` (`403`); its data and routes stay, so
`resumeTenant` serves it again at once. Suspending first is how a deployment
stops a tenant's traffic before it removes the tenant.

## Removing a Tenant

```dart
final tenancy = TomTenancy.current!;
final removed = await tenancy.removeTenant('umbrella');
// The data stays where it is: drop it once the retention period allows.
final main = TomDataSourceInfo.getBaseDataSourceInfo('main')!;
final schema =
    removed.schema ?? '${main.settings['databaseName']}_${removed.id}';
// MariaDB; on PostgreSQL: 'DROP SCHEMA IF EXISTS "$schema" CASCADE'.
await main.datasource.executeCommand('DROP DATABASE IF EXISTS `$schema`');
```

`removeTenant` is the counterpart of `addTenant`, for a tenant whose deletion is
final. It records the tenant as `removed` in the registry, then takes it out of
`tenants`, so from then on a request
naming it — by its token's claim, its host, its path or a header — is refused
as `tenancy.tenant.unknown` (`404`), and work still in its context is refused by
`route` and `runFor`. It then drops the tenant's routes and closes the data
sources the tenancy opened for it, which closes their connection pools. A data
source the tenant only named by reference belongs to the deployment and stays
open. Other tenants are untouched.

The tenant's data is not touched: dropping its schema or database is the
caller's, with the `TomTenant` the call returns. Work that is still running in
the tenant when its pools close fails, so a deployment that needs it to finish
stops admitting the tenant's requests first — `suspendTenant` — and removes the
tenant afterwards. The registry row stays, as `removed`, so the next start does
not provision the tenant again even if the configuration still names it (that
is reported as a conflict).

## Operating Costs

- **Connection pools.** Every `schema` and `database` tenant has a data source
  of its own, and so a pool of its own: a deployment of fifty schema tenants
  holds fifty pools against one server — on PostgreSQL, against one database,
  every pool counting toward its `max_connections`. Size each tenant's pool in its settings
  (a schema tenant inherits the base data source's), and size the server's
  connection limit for the sum. `shared` tenants add no pool.
- **Migrations.** A `shared` deployment migrates once. Every `schema` or
  `database` tenant is one more migration run per release, and a release is
  complete only when every tenant's run succeeded — run the per-tenant loop as
  part of the deployment, not on first request, under the migration lock
  ([Per-tenant migrations](#per-tenant-migrations)).
- **Moving a tenant between models** is a copy of its rows into the new place
  and a configuration change: the rows already carry their tenant, so no schema
  changes.
- **Backups and residency** follow the model: a `database` tenant can be backed
  up, restored or placed in a region on its own; a `shared` tenant's rows are
  separable only by their tenant column.

## Failure Keys

| Key | Raised by | Meaning |
| --- | --------- | ------- |
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
| `tenancy.tenant.unavailable` | `resolveRequest` | A request for a tenant that is provisioning, migrating or whose migration failed (`503`). |
| `tenancy.registry.unknown_tenant` | `TomTenantRegistry.setStatus`, `setMigrated` | A change to a tenant the registry does not hold. |
| `tenancy.registry.unknown_status` | `TomTenantStatus.parse` | A stored status this code does not know. |
| `tenancy.registry.unknown_datasource` | `TomSqlTenantRegistry` | The registry's data source is not registered. |
| `tenancy.resolution.conflict` | `resolveRequest` | A request naming another tenant than its token (`403`). |
| `tenancy.id.invalid` | kernel `TomTenantContext.validate`, `TomTenant`, `resolveRequest` | A tenant id that is not a lower-case identifier of at most 32 characters (`400` on a request). |
| `tenancy.context.missing` | kernel `TomTenantContext.require`, `TomTenancy.tenantForWork` | A tenant table read or written with no tenant in context under an installed tenancy. |
| `data_scope.write.foreign_tenant` | object_persistence | A tenant-table row naming another tenant than the one in context. |
| `annotation_analyzer.tenant_table.mixed` | object_persistence | A `@TomReference`, a subquery or a repository over tenant tables and system tables together. |
| `crud_repository.transaction.tenant_and_system_one_phase` | object_persistence | One transaction over a tenant table and a system table on two data sources, one of them one-phase. |
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
| `dart:async` | dart | `tenancy.dart` | `FutureOr`, the body type of `runFor` and `forEachTenant`; `Timer`, the registry refresh |
| `dart:convert` | dart | `tenant_registry.dart` | `jsonEncode` / `jsonDecode`, the registry's `datasources` and `migrated` columns |
| `dart:io` | dart | `tenant_type.dart` | `Directory`, whether a type's migration tree exists |
| `shelf` | package | `tenancy.dart`, `tenant_resolution.dart` | `Request`, which a resolver reads and `resolveRequest` resolves |
| `tom_core_kernel` | package | `tenancy.dart`, `tenant_registry.dart` | `TomTenantContext` — the zone-carried tenant, the id rule and `qualify`; `TomDataSource`, `tomLog` and `tomReflector` |
| [configuration](configuration.md) | module | `tenancy.dart` | `TomServerConfigResourceProvider`, which `fromConfiguration` reads the `tenancy` key from |
| [datasources](datasources.md) | module | `tenancy.dart`, `tenant_registry.dart`, `tenant_registry_sql.dart` | `TomDataSourceInfo` — the registry routed per tenant, the data sources opened over a tenant's schema or database — and the base data source's dialect, whose `createSchema` and `schemaSetting` say how a schema is made and pointed at; and `TomFrameworkTable`, `TomSchemaProvisioning` and `sqlInstant` / `parseSqlInstant`, the registry's table and its instants |
| [little_things](little_things.md) | module | `tenancy.dart` | `TomServerException`, the base of `TomTenancyException` |
| [object_persistence](object_persistence.md) | module | `tenancy.dart`, `tenant_registry.dart` | `TomAnnotationAnalyzer.tenantTables` and `TomDbTable`, the tenant tables `tenantTables` reports; `@TomDbTable` / `@TomDbColumn`, the mapping of `TomTenantRow` |
