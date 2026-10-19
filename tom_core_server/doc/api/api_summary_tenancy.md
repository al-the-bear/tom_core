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
  - [TomTenantResolver](#tomtenantresolver)
  - [TomTenantHostResolver](#tomtenanthostresolver)
  - [TomTenantPathResolver](#tomtenantpathresolver)
  - [TomTenantHeaderResolver](#tomtenantheaderresolver)
  - [TomTenantResolution](#tomtenantresolution)
- [Enums](#enums)
  - [TomTenantIsolation](#tomtenantisolation)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/tenancy/tenancy.dart`,
`lib/src/tomserver/tenancy/tenant_resolution.dart`.

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
TomTenantIsolation  (enum)

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
| `tenancy.tenant.unknown` | Work for a tenant the deployment does not have (`clientThrow: true`). |

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
  String? name,
  TomTenantIsolation? isolation,
  String? schema,
  Map<String, Object> datasources = const {},
})
factory TomTenant.fromMap(String id, Map<Object?, Object?> map)
```

`fromMap` reads a tenant from its configuration map: `name`, `isolation`,
`schema`, and either `datasources` (per routed data source name) or `datasource`
(the one routed name — the common case). A data-source value is a map of
settings to open or the name of a registered data source.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | The tenant's id — what the token's `tenant` claim names (final). |
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
  Set<String> datasources = const {'main'},
  List<TomTenantResolver> resolvers = const [],
  TomTenantIsolation defaultIsolation = TomTenantIsolation.shared,
  bool createSchemas = false,
})
factory TomTenancy.fromConfiguration([TomServerConfigResourceProvider? config])
```

`fromConfiguration` reads the `tenancy` key of the server configuration
(`TomServerConfigResourceProvider.getServerConfig()` unless one is passed):
`isolation`, `datasources`, `resolution` (`host` / `header`, in order),
`hostSuffix`, `header`, `createSchemas` and the `tenants` map. An absent key
reads as a tenancy with no tenants. Throws `tenancy.config.not_a_map`,
`tenancy.config.unknown_isolation` or `tenancy.config.unknown_resolver`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `configurationKey` | `static const String` | `'tenancy'` — the configuration path of the settings. |
| `current` | `static TomTenancy?` | *(getter)* The installed configuration, or `null` in a deployment without tenancy. |
| `tenants` | `Map<String, TomTenant>` | The tenants, by id (final; `addTenant` adds to it, `removeTenant` removes from it). |
| `datasources` | `Set<String>` | The data sources routed per tenant (final). |
| `resolvers` | `List<TomTenantResolver>` | How a request without a token claim names its tenant, in order (final). |
| `defaultIsolation` | `TomTenantIsolation` | The isolation of a tenant that names none (final). |
| `createSchemas` | `bool` | Whether schema isolation creates the tenant's schema when it is provisioned — the base data source dialect's `createSchema`: `CREATE DATABASE IF NOT EXISTS` on MariaDB, `CREATE SCHEMA IF NOT EXISTS` on PostgreSQL (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `install` | `static Future<void> install(TomTenancy tenancy)` | Resets any installed configuration, provisions every tenant's schema or database, then publishes `tenancy` as `current` and installs `route` as `TomDataSourceInfo.router`. A provisioning failure fails the install. |
| `reset` | `static Future<void> reset()` | Removes the installed configuration, uninstalls the router, and closes and unregisters the data sources it opened. |
| `unknownTenant` | `static TomTenancyException unknownTenant(String tenantId)` | The `tenancy.tenant.unknown` exception for work in a tenant the deployment does not have (`clientThrow: true`). |
| `addTenant` | `Future<void> addTenant(TomTenant tenant)` | Provisions `tenant`'s schema or database, then adds it to the running deployment — onboarding without a restart. |
| `removeTenant` | `Future<TomTenant> removeTenant(String tenantId)` | Withdraws the tenant from the running deployment: its requests and work are refused as `tenancy.tenant.unknown`, its routes dropped, the data sources opened for it closed (their pools with them). Returns the tenant; dropping its schema or database is the caller's. Throws `tenancy.tenant.unknown` for an unknown id. |
| `isolationOf` | `TomTenantIsolation isolationOf(TomTenant tenant)` | The isolation `tenant` runs under: its own, or `defaultIsolation`. |
| `route` | `TomDataSourceInfo route(TomDataSourceInfo base)` | `base` as the current tenant reaches it: the tenant's schema or database for a routed data source, `base` itself with no tenant, for an unrouted data source, or for a shared tenant. Throws `tenancy.tenant.unknown` for a tenant in context the deployment does not have — routing it to the shared data source would hand it everyone's rows. |
| `runFor` | `Future<T> runFor<T>(String tenantId, FutureOr<T> Function() body)` | Runs `body` inside `tenantId`, which must be a tenant of the deployment (`tenancy.tenant.unknown` otherwise). |
| `forEachTenant` | `Future<void> forEachTenant(FutureOr<void> Function(TomTenant tenant) body)` | Runs `body` once per tenant, in turn, inside each — per-tenant migrations, a nightly job doing each tenant's work, a cache warm-up. |
| `resolveRequest` | `TomTenantResolution resolveRequest(Request request, {String? claim})` | The tenant `request` is for, or the rejection to answer it with; `claim` is the verified token's `tenant` claim. The claim is authoritative: a host or header naming another tenant is refused (`tenancy.resolution.conflict`, 403). Without a claim, the `resolvers` are asked in order. An unknown tenant is refused (`tenancy.tenant.unknown`, 404), as is an id that is not one (`tenancy.id.invalid`, 400). No answer is not a rejection: the request proceeds with no tenant. |

A routed data source is opened over a schema tenant's schema with the base data
source's settings and the dialect's `schemaSetting` replaced — `databaseName` on
MariaDB, `schema` (the `search_path`) on PostgreSQL — and registered under
`<name>@<tenant>`; a database tenant's is opened from its configured settings
under the same name, or is the registered data source it names.

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

## Enums

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

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
