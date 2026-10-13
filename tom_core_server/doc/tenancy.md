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
- [Starting a Multi-Tenant Server](#starting-a-multi-tenant-server)
  - [Per-tenant migrations](#per-tenant-migrations)
- [Resolving a Request's Tenant](#resolving-a-requests-tenant)
  - [Rejections](#rejections)
  - [A login binds the token to its tenant](#a-login-binds-the-token-to-its-tenant)
- [Tenant-Owned Entities](#tenant-owned-entities)
- [What Is Tenant-Scoped](#what-is-tenant-scoped)
- [What Stays Deployment-Wide](#what-stays-deployment-wide)
- [Working in a Tenant Outside a Request](#working-in-a-tenant-outside-a-request)
- [Onboarding a Tenant](#onboarding-a-tenant)
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
| `TomTenant` | class | One tenant: its id, display name, isolation model, schema and data sources |
| `TomTenantIsolation` | enum | `shared`, `schema` or `database` — where a tenant's rows live |
| `TomTenancyException` | class | A tenancy configuration that cannot be used, or a tenant that does not exist |
| `TomTenantResolver` | abstract interface class | Reads a tenant id from a request that carries no token claim |
| `TomTenantHostResolver` | class | Names the tenant by host: an exact host, or a subdomain of a suffix |
| `TomTenantHeaderResolver` | class | Names the tenant by a request header, `X-Tenant-Id` by default |
| `TomTenantResolution` | class | The outcome of resolving a request: a tenant, none, or a rejection |

The module is two files: `tenancy.dart` holds the configuration, the
provisioning and the routing; `tenant_resolution.dart` holds the request-side
resolvers.

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
| `TomTenantIsolation.shared` | the shared database; every tenant-owned table carries a tenant column | the row predicate | one database, one migration run |
| `TomTenantIsolation.schema` | a schema of its own on the shared server (on MariaDB, a database) | the schema boundary, and the predicate | one schema and one connection pool per tenant |
| `TomTenantIsolation.database` | a database of its own, configured per tenant — another server, another region | the server boundary, and the predicate | one database, one pool and one migration run per tenant |

The row predicate that `@TomTenantOwned` adds (see
[Tenant-Owned Entities](#tenant-owned-entities)) applies **in every model**.
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
  resolution: [host, header]     # how a request without a token names its tenant, in order
  hostSuffix: app.example.com    # <tenant>.app.example.com
  header: X-Tenant-Id            # the header the header resolver reads
  createSchemas: true            # create a schema tenant's schema at provisioning
  tenants:
    acme: {}                     # shared, the default
    globex: {isolation: schema}  # schema main_globex on the shared server
    initech:
      isolation: database
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
| `resolution` | none | `host`, `header`, or both in order. With none, only the token claim names a tenant. |
| `hostSuffix` | none | The domain tenants are subdomains of, for the `host` resolver. |
| `header` | `X-Tenant-Id` | The header the `header` resolver reads. |
| `createSchemas` | `false` | Whether provisioning a `schema` tenant runs `CREATE DATABASE IF NOT EXISTS` for its schema. |
| `tenants.<id>.name` | none | A display name. |
| `tenants.<id>.isolation` | the default | The tenant's model. |
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
the tenants, the routed data sources, the resolvers, the default model and
`createSchemas`:

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

## Starting a Multi-Tenant Server

Tenancy is installed after the data sources are registered and before the
server serves its first request:

```dart
await TomDataSourceInfo.initializeDatasourceInfo(datasourceConfiguration);
await TomTenancy.install(TomTenancy.fromConfiguration());
```

`install` provisions every tenant first — a `schema` tenant's schema is created
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
// database, and a shared tenant's run is a no-op after the first.
await TomTenancy.current!.forEachTenant(
  (_) => TomDbMigrations.migrateDatabases('migrations/tenant'),
);
```

Each tenant's schema or database keeps its own versioning table, so a tenant
added later is brought to the current version by the same loop. Keeping the two
trees apart is what keeps the framework's tables out of every tenant's schema —
see [What Stays Deployment-Wide](#what-stays-deployment-wide).

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
   - `TomTenantHeaderResolver` answers the value of its header, trimmed.
3. **No answer is not a rejection.** The request proceeds in an explicit
   no-tenant context; tenant-owned data is closed to it, and everything else is
   served normally.

A header is the weakest of the sources, because a client chooses it freely. It
is safe here because it only ever *proposes* a tenant: data stays closed until a
login in that tenant succeeds, and once a token exists its claim wins and a
contradicting header or host is refused.

### Rejections

A refused request is answered by the middleware itself, before any handler runs,
so nothing downstream ever sees a request in a tenant it may not enter. The
body is a small JSON object carrying the key and a message:

```json
{ "error": "tenancy.resolution.conflict", "message": "The request names a different tenant than its token." }
```

| Status | Key | When |
| ------ | --- | ---- |
| `403` | `tenancy.resolution.conflict` | The host or header names another tenant than the token's claim. A token is not a pass to another tenant. |
| `404` | `tenancy.tenant.unknown` | The request names a tenant the deployment does not have. |
| `400` | `tenancy.id.invalid` | The request names something that is not a tenant id. |

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

## Tenant-Owned Entities

`@TomTenantOwned` (object_persistence) marks an entity whose every row belongs
to a tenant:

```dart
@tomReflector
@TomTenantOwned()
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

The annotation's `field` names the entity field holding the tenant id —
`tenantId` by default. The repository then:

- adds `<field> = <current tenant>` as a bound predicate to every read —
  `findAll`, `findById`, `count`, `findWhere`, the existence checks;
- lets an update or delete touch only rows that predicate admits;
- fills an unset tenant field on insert with the current tenant, and refuses an
  entity naming another tenant (`data_scope.write.foreign_tenant`) — which also
  stops an update from moving a row to another tenant;
- with no tenant in context, reads nothing and refuses every write
  (`data_scope.write.no_tenant`).

The predicate is independent of `@TomDbScope` and is ANDed with it, so an
entity can be a tenant's *and* scoped to its owner or to a resource grant. Unlike
the data scope it is not suppressed while an async scope resolver computes its
visible ids: a resolver working out one tenant's rows must not read another
tenant's to do it. See
[object_persistence.md](object_persistence.md#tenant-owned-rows) for the
repository side.

## What Is Tenant-Scoped

| Concern | How it is kept per tenant | Guide |
| ------- | ------------------------- | ----- |
| Repositories | data source routed per tenant; `@TomTenantOwned` predicate on every read and write | [object_persistence](object_persistence.md#tenant-owned-rows), [datasources](datasources.md#routing-per-tenant) |
| Caches | `TomCache`'s static API qualifies every key by the tenant in context — two tenants caching `plan` hold two entries | [cache](cache.md#tenant-scoped-entries) |
| Principal revocation | `revokePrincipal('alice')` in a tenant revokes that tenant's `alice` only; another tenant's `alice` is a different person | [authorization](authorization.md#revocation-per-tenant) |
| Jobs | a run records its tenant; its body runs inside it, across a worker isolate too; its window and its overlap protection are per tenant | [scheduling](scheduling.md#runs-per-tenant) |
| Messaging outbox | a message is queued for the tenant in context and delivered inside it; its receipt and its delivery correlation name the tenant | [messaging](messaging.md#messages-per-tenant) |
| Delivery reports | `tom_delivery_report.tenant` attributes a carrier's report, which arrives carrying nothing but the carrier's id, to its tenant | [messaging](messaging.md#messages-per-tenant) |

A tenant-scoped key is spelled one way everywhere —
`TomTenantContext.qualify(name, tenant)`, which is `tenant:<id>/<name>`, or the
bare name with no tenant. A value meant for every tenant is cached, or a
principal revoked, outside any tenant's context.

## What Stays Deployment-Wide

The framework's own tables serve the whole deployment and are **not routed**:
each store is built over a data source at start-up and keeps it, whatever tenant
is in context. Where the tenant matters, it is a column.

| Table | Store | Tenant |
| ----- | ----- | ------ |
| `tom_job_run` | `TomSqlJobStore` | a `tenant` column; `''` for a run of no tenant; part of the unique window key |
| `tom_lease` | `TomSqlLeaseLock` | none — a lease names a run or a job, and a job's lease names its tenant |
| `tom_scheduler_node` | `TomSqlSchedulerNodes` | none — nodes serve every tenant |
| `tom_delivery_report` | `TomSqlDeliveryReportStore` | a nullable `tenant` column |
| `tom_cache_invalidation` | `TomSqlInvalidationChannel` | none — the keys it carries are already qualified |
| `tom_oauth_state` | `TomSqlOAuthStateStore` | none |
| `tom_scim_resource` | `TomSqlScimStore` | none |
| `tom_blob`, `tom_blob_chunk` | `TomDatabaseBlobStore` | none |
| `tom_audit_trail` | `TomSqlAuditSink` | none |

Build these stores over a data source that is not in `TomTenancy.datasources`,
or construct them outside any tenant's context, which is where a server's
start-up runs anyway. Their migrations belong in the deployment-wide tree.

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

`addTenant` provisions the tenant's schema or database first and adds it to the
running deployment only once that succeeded, so a request naming the tenant
cannot arrive before its data source exists. No restart is needed. Add the
tenant to the configuration as well, so the next start knows it.

## Operating Costs

- **Connection pools.** Every `schema` and `database` tenant has a data source
  of its own, and so a pool of its own: a deployment of fifty schema tenants
  holds fifty pools against one server. Size each tenant's pool in its settings
  (a schema tenant inherits the base data source's), and size the server's
  connection limit for the sum. `shared` tenants add no pool.
- **Migrations.** A `shared` deployment migrates once. Every `schema` or
  `database` tenant is one more migration run per release, and a release is
  complete only when every tenant's run succeeded — run the per-tenant loop as
  part of the deployment, not on first request.
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
| `tenancy.config.unknown_resolver` | `TomTenancy.fromConfiguration` | A tenant resolution other than `host` or `header`. |
| `tenancy.config.schema_unsupported` | provisioning | Schema isolation over a data source whose settings name no `databaseName`. |
| `tenancy.config.invalid_schema` | provisioning | A schema name that is not a plain identifier of at most 64 characters. |
| `tenancy.config.missing_datasource` | provisioning | Database isolation without a data source for a routed name. |
| `tenancy.config.unknown_datasource` | provisioning | A routed or referenced data source that is not registered. |
| `tenancy.tenant.unknown` | `route`, `runFor`, `resolveRequest` | Work or a request for a tenant the deployment does not have (`404` on a request; `clientThrow: true`). |
| `tenancy.resolution.conflict` | `resolveRequest` | A request naming another tenant than its token (`403`). |
| `tenancy.id.invalid` | kernel `TomTenantContext.validate`, `TomTenant`, `resolveRequest` | A tenant id that is not a lower-case identifier of at most 32 characters (`400` on a request). |
| `tenancy.context.missing` | kernel `TomTenantContext.require` | Tenant-owned work ran with no tenant in context. |
| `data_scope.write.no_tenant` | object_persistence | A tenant-owned row written with no tenant in context. |
| `data_scope.write.foreign_tenant` | object_persistence | A tenant-owned row naming another tenant than the one in context. |
| `login.error.tenant-mismatch` | authentication | An account of one tenant signing in through another tenant. |

`TomTenancyException` extends `TomServerException`; the two kernel keys are
raised as the kernel's `TomTenantException`.

## Not Yet Implemented

- **A tenant cannot be removed from a running deployment.** `addTenant` onboards
  without a restart; there is no counterpart that closes a tenant's data source
  and withdraws it. Removing a tenant is a configuration change and a restart.
  <!-- unpinned: absence — no removeTenant exists -->
- **The framework's own stores are not tenant-scoped beyond their columns.** The
  audit trail, the blob store, the SCIM store and the OAuth state store serve the
  whole deployment from the data source they were built over, and their rows
  carry no tenant. A deployment that needs a tenant's audit trail or blobs apart
  builds one store per tenant.
  <!-- unpinned: decision — framework tables are deployment-wide and not routed -->
- **A tenant's accounts are the authentication service's.** The framework binds
  a token to the tenant a login ran in and refuses a principal placed in another,
  but which accounts exist in which tenant is the deployment's
  `TomAuthenticationService` to decide — typically by reading them through a
  `@TomTenantOwned` entity.
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

`test/tenancy_db_test.dart`, tagged `db`, runs two tenants against MariaDB under
each of the three isolation models with the same assertions — that is the point
of one seam — and checks where the rows land: in the shared table under
`shared`, in each tenant's schema under `schema`, in each tenant's database under
`database`. It covers repositories, caches, revocations, jobs and the outbox.
`tool/run_db_tests.sh` starts a database for it.

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

- **`TomTenancy`** — the configuration (`tenants`, `datasources`, `resolvers`,
  `defaultIsolation`, `createSchemas`), its reading (`fromConfiguration`,
  `configurationKey`), its lifecycle (`install`, `reset`, `current`,
  `addTenant`), its routing (`route`, `isolationOf`), work in a tenant
  (`runFor`, `forEachTenant`), request resolution (`resolveRequest`) and the
  refusal of an unknown tenant (`unknownTenant`).
- **`TomTenant`** / **`TomTenantIsolation`** — one tenant and its model;
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
| `dart:async` | dart | `tenancy.dart` | `FutureOr`, the body type of `runFor` and `forEachTenant` |
| `shelf` | package | every file | `Request`, which a resolver reads and `resolveRequest` resolves |
| `tom_core_kernel` | package | `tenancy.dart` | `TomTenantContext` — the zone-carried tenant, the id rule and `qualify` |
| [configuration](configuration.md) | module | `tenancy.dart` | `TomServerConfigResourceProvider`, which `fromConfiguration` reads the `tenancy` key from |
| [datasources](datasources.md) | module | `tenancy.dart` | `TomDataSourceInfo` — the registry routed per tenant, the data sources opened over a tenant's schema or database |
| [little_things](little_things.md) | module | `tenancy.dart` | `TomServerException`, the base of `TomTenancyException` |
