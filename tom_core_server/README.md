# tom_core_server

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

> **⚠️ Work in progress — unstable API.** The Tom Core packages are under active
> development and not yet stable. Their version numbers carry no promise about
> API maturity: they are publishing counters, not semver. The patch number is
> bumped on every change — **including breaking changes** — so a patch bump may
> break you. Expect the public surface to shift without notice. Not recommended
> for production use yet.

Server-side runtime for the Tom Framework — an HTTP host, an endpoint pipeline,
and a relational persistence layer built on the platform-neutral kernel.

## Overview

`tom_core_server` is the backend layer of the Tom Framework. It builds on
[`tom_core_kernel`](../tom_core_kernel/README.md) (dependency injection,
observable state, security, resources) and adds everything a service needs:

- a **shelf-based HTTP host** (`TomServer`) with a middleware pipeline —
  request context, per-request IDs, authentication, logging, and JSON error
  mapping wrapped around a declarative **endpoint router**;
- an **ORM-style persistence layer** — repositories with type-safe queries
  built from expression operators, persistence annotations, and a query
  builder, over pluggable **datasources** (MariaDB/MySQL driver included);
- **versioned schema migrations** — with a convergence check that the entities,
  the migration chain and the live database still agree — and **local/XA
  transaction** coordination;
- an **audit trail** that is attributable and tamper-evident, **outbound
  messaging** with a durable outbox and **per-recipient localized text**,
  **tabular export** to CSV/XLSX/PDF,
  **streaming blob storage** behind one contract, and relational **job
  scheduling** for a cluster that shares no filesystem;
- server **configuration** (typed config + YAML resources), an isolate-backed
  **cache**, **authentication/authorization** services, and **health** endpoints.

Because the barrel re-exports the kernel, a server app depends only on
`tom_core_server` — one import gives both the kernel API and the server stack.

## Installation

This package is internal to the Tom workspace and consumed by path (it is
`publish_to: none`), so there is no `dart pub add` line:

```yaml
dependencies:
  tom_core_server:
    path: ../tom_core_server
```

Then import the single barrel — it re-exports `tom_core_kernel`,
`tom_basics_console`, and the MariaDB client, so you rarely import those
directly:

```dart
import 'package:tom_core_server/tom_core_server.dart';
```

**SDK:** Dart `^3.10.0`. Modules that use reflection (persistence entities,
endpoint services) require `dart run build_runner build` to generate
`*.reflection.dart`. The relational layer targets **MariaDB/MySQL** via
`mysql_client`; the datasource, dialect, migration, and repository contracts are
abstract, so other backends can be added.

## Features

### HTTP host & endpoints (`server`, `endpoints`)

| Type | Responsibility |
| ---- | -------------- |
| `TomServer` | The shelf-based HTTP host and its middleware pipeline |
| `TomEndpoint` / `TomEndpointHandler` / `TomEndpointRouting` | Endpoint declaration and the request-handling pipeline |
| `TomService` / `TomApiImplementation` / `TomTransactional` | Annotations that turn a class into a routed API, and mark a handler transactional |
| `TomFileEndpoint` / `TomFileSlots` / `TomFileSlot` | Upload/download/probe/delete over a `<table>/<id>/<column>` slot derived from the entity's own annotations — registered per repository, exposed only where `@TomFileReference` says so |
| `TomMultipartForm` / `TomFormFile` | HTML form bodies (multipart or url-encoded): text parts fold into the request DTO, file parts bind as typed parameters and upload through the same file slot |
| `TomRedirect` | The directive a handler returns to answer with a `3xx`, so the pipeline builds the response rather than the handler |
| `TomWebSocketEndpoint` / `TomWebSocketConnection` | Sockets as a *kind of endpoint* — same scan, access check and parameter binding, run inside the captured request zone, with their own connection lifecycle |
| `TomErrorHandler` / `TomDefaultErrorHandler` | Maps a thrown exception onto the response the caller sees |

### Persistence (`object_persistence`, `datasources`)

| Type | Responsibility |
| ---- | -------------- |
| `TomRepository` / `TomSqlDatasourceRepository` | CRUD + type-safe query repository |
| `TomDbTable` / `TomDbColumn` / `TomEntityId` / `TomReference` / `TomFileReference` / `TomDbScope` | Entity-mapping annotations |
| `TomQueryBuilder` + `Eq` / `And` / `Like` / `In` / `Gte` … | Type-safe query expressions |
| `TomAggregate` + `countAll` / `sum` / `avg` / `min` / `max`, `TomGroupedSelect`, `TomGroupedRow` | Grouping and aggregation — results come back as group keys plus aggregate values, not entities |
| `TomQuerySentenceCompiler` | Compiles a readable query sentence (`find first 25 skip 50 by name = :name order by age desc name asc`) into the same query objects the builder produces |
| `TomPageRequest` / `TomSortField` / `TomSortDirection` | The row window and the per-field sort a caller passes to `findAll`, `findAllById`, `findByQuery` and `findByQuerySentence` — cut out of the *scoped* rows, so `count()` reports the scoped total beside it |
| `TomDataScope` / `TomDataScopeRegistry` / `TomColumnAuthorization` | Row scoping ANDed into every query — `owner`, `group` and the grant-driven `resource` kind, the last applied automatically to any entity with a `resource_key` column — and per-column read/write rights enforced by the repository |
| `TomDataSource` / `MariaDbDatasource` / `MariaDbXADatasource` | Connection drivers (MariaDB/MySQL) |
| `TomDbType` family / `TomStandardSqlDialect` | Typed columns and SQL rendering |
| `TomSelect` / `TomCount` / `TomDelete` / `TomGroupedSelect` / `TomLiteralSelect` | Generated query objects, plus the raw-SQL escape hatch |

### Schema & transactions (`db_migration`, `transactions`)

| Type | Responsibility |
| ---- | -------------- |
| `TomDbMigrator` / `TomDbMigrations` / `TomDbVersion` | Versioned schema migrations (MariaDB adapter) |
| `TomSchemaConvergenceCheck` / `TomSchemaModel` / `TomEntitySchemaReader` / `TomSchemaDivergence` | Checks that the entities, the migrations and the live database still describe the same schema, and names each divergence |
| `TomTransactionManager` / `TomTransaction` / `TomTransactionParticipant` | Local/XA transaction coordination |

### Platform services (`configuration`, `cache`, `authentication`, `authorization`, `audit`, `messaging`, `resources`, `export`, `file_storage`, `scheduling`, `preferences`, `healthcheck`, `cmdline`, `little_things`)

| Module | Key types | What it does |
| ------ | --------- | ------------ |
| `configuration` | `TomBaseServerConfiguration`, `TomServerConfigResourceProvider`, `TomConfig<T>`, `TomYaml` | Typed config + YAML resources |
| `cache` | `TomCache`, `TomCacheManager` | Isolate-backed server-side cache |
| `authentication` | `TomAuthenticationService`, `TomAuthenticationData`, `TomAuthenticationAdaptor`, `Tom2FAAdaptor`, `Tom2FAService`, `Tom2FARegistry`, `TomTotp2FAService`, `TomServerSelfLogin`, `TomOAuthAuthenticationService`, `TomOAuthFlow`, `TomOAuthProviders`, `TomExternalIdentityStore` | Authentication service and adaptor annotations; second-factor challenges behind one service contract, with a TOTP implementation and a registry that picks the factor per principal; a server's own login when it calls another service as itself; and external identity — an OAuth 2.0 / OIDC authorization-code + PKCE login written as *another implementation of the same service contract*, so it reaches the unchanged token and 2FA path instead of a second one |
| `authorization` | `TomAuthorizationCache`, `TomResourceGrant`, `TomGradedAccessControlInformation`, `TomPrincipalResourceGrant`, `TomPrincipalDelegation`, `TomDelegationResolver`, `TomResourceDataScope` | Isolate-backed authorization cache; graded per-key grants that add the middle states the kernel's granted/denied list cannot express; per-principal-per-resource roles; delegation of those roles by explicit share, out-of-office window, or revocable hand-over; and the row scope that filters an entity's rows by those grants — `read` to list, `full` to write — with no application-side resolver |
| `audit` | `TomAuditTrail`, `TomAudited`, `TomAuditRecord`, `TomAuditSink`, `TomSqlAuditSink`, `TomAuditAnchor`, `TomAuditAnchorStore`, `TomAuditAnchorPublisher` | Attributable, tamper-evident trail written at the endpoint and repository chokepoints, stored in memory, in append-only files, or in a table whose write-once guarantee is the grant it is served with — and anchors, published outside the server, that turn a wholesale rewrite or a truncation from invisible into provable |
| `messaging` | `TomMessage`, `TomMessageTransport`, `TomSmtpTransport`, `TomMessageOutbox` | Outbound messages: a channel-neutral shape, SMTP, and a durable outbox on the kernel's job scheduler |
| `resources` | `TomTextLocale`, `TomLocalizedTextResources`, `TomResourceLocaleException` | Per-recipient text for a server that renders many languages at once: the locale is an argument rather than ambient state, bundles resolve along a fallback chain *per key* so a half-translated language serves what it has, and a missing key answers `null` instead of the key — right on a screen, unacceptable in a subject line |
| `export` | `TomTabularResult`, `TomTabularRenderer`, `TomCsvRenderer`, `TomXlsxRenderer`, `TomPdfRenderer`, `TomExportService`, `TomExportStore` | CSV/XLSX/PDF rendering from one streaming tabular shape, streamed back to a caller or into storage |
| `file_storage` | `TomBlobStore`, `TomDatabaseBlobStore`, `TomDirectoryBlobStore`, `TomS3BlobStore`, `TomMemoryBlobStore`, `TomBlobStoreInfo`, `TomFileReference` | Streaming blob storage behind one four-method contract, backends chosen in configuration, and entity columns that hold a storage key instead of the bytes |
| `scheduling` | `TomSqlJobStore`, `TomSqlLeaseLock` | The kernel's job-store and lease-lock contracts over a shared database, so a cluster whose nodes share no filesystem still runs each window exactly once |
| `preferences` | `TomUserPreference`, `TomUserPreferenceRepository`, `TomUserPreferences`, `TomUserPreferencesServer` | Per-principal preferences that follow the user across devices: one scoped table, a typed service that reads its caller from the request zone, and the `/preferences/*` endpoints behind the kernel's contract |
| `healthcheck` | `TomHealthService`, `TomHealthServer`, `TomHealthAnalyzer` | Health endpoints and analyzers |
| `cmdline` | `TomArgs`, `TomEnvFile` | Argument parsing and `.env` loading |
| `little_things` | `TomServerException`, `TomLoginException`, `TomRequestId` | Server exception base (extends kernel `TomException`), the login failure it raises, and the per-request correlation id it reads from the zone |

## Quick start

Construct a server from a configuration and start it:

```dart
import 'package:tom_core_server/tom_core_server.dart';

void main(List<String> argv) {
  // `configuration` is your subclass of TomBaseServerConfiguration.
  final server = TomServer(configuration);
  server.start(); // HTTP host listening; endpoints routed
}
```

Parse command-line arguments and a `.env` file into typed values:

```dart
final config = TomArgs.fillFromArgs(argv, MyServerArgs()); // reflected key=value
final env = TomEnvFile.read('.env');                       // typed map
```

## Example projects

Every module ships a runnable sample under [`example/`](example/), each mirrored
by a `test/<module>_test.dart` suite. The connection-independent examples run
without a database; the datasource/persistence drivers require a live MySQL and
annotated entities and are documented in [`doc/`](doc/).

| Sample | Demonstrates |
| ------ | ------------ |
| [`example/server/`](example/server/) | Building and starting `TomServer` |
| [`example/endpoints/`](example/endpoints/) | Declaring routed endpoints |
| [`example/object_persistence/`](example/object_persistence/) | Repositories, annotations, query builder |
| [`example/datasources/`](example/datasources/) | SQL-typed values and dialect rendering |
| [`example/db_migration/`](example/db_migration/) | Versioned schema migrations |
| [`example/transactions/`](example/transactions/) | Local/XA transaction coordination |
| [`example/configuration/`](example/configuration/) | Typed config + YAML resources |
| [`example/cache/`](example/cache/) | Isolate-backed cache |
| [`example/authentication/`](example/authentication/) · [`example/authorization/`](example/authorization/) | Login and second factors; the authorization cache, graded grants, resource roles and delegation, and the grant-driven row scope those grants filter the database with |
| [`example/audit/`](example/audit/) | Audit records, the declared/automatic split, the hash chain, the relational trail's schema and its write-once check, and signed anchors published outside the server |
| [`example/messaging/`](example/messaging/) | Message composition, the MIME document, stand-in transports, the durable outbox |
| [`example/export/`](example/export/) | The streaming tabular shape, the same shape with its columns derived from a reflected entity — rendered against the hand-written one byte for byte — CSV/XLSX/PDF renderers, the format registry, one export through all three storage backends, and the two delivery channels |
| [`example/file_storage/`](example/file_storage/) | The one streaming blob contract, the key grammar, the infrastructure-free backends, configuration-driven selection, generated file-reference keys and the blob-backed export store |
| [`example/scheduling/`](example/scheduling/) | The relational job queue and lease lock: the schema and why each constraint is load-bearing, the shipped migrations, the UTC instant encoding, and the cluster wiring. [`example/scheduling/cluster/`](example/scheduling/cluster/) adds the part that needs a database — two real nodes arbitrating over one MariaDB, asserted rather than narrated |
| [`example/healthcheck/`](example/healthcheck/) · [`example/cmdline/`](example/cmdline/) · [`example/little_things/`](example/little_things/) | Health, CLI, and exceptions |

Run a single example:

```bash
dart run example/datasources/datasources_example.dart
```

## Usage

### Connecting a datasource (MariaDB/MySQL)

The MariaDB driver is configured by its connection fields, then `connect()`
opens the live connection:

```dart
final ds = MariaDbDatasource()
  ..host = 'localhost'
  ..port = 3306
  ..username = 'tom'
  ..password = 'secret'
  ..databaseName = 'tomdb';
await ds.connect(); // throws MariadbDatasourceException on failure
```

> **MySQL-in-Docker.** The runnable end-to-end story — a Docker Compose MySQL
> plus bootstrap and migrations — ships with the
> [`tom_core_samples/core_server_sample`](../tom_core_samples/core_server_sample/README.md)
> project (see the [samples map](../tom_core_samples/README.md)). This package
> provides the abstract contracts and the MariaDB driver it builds on.

### Repositories and type-safe queries

Repositories expose CRUD plus queries built from the expression operators
(`Eq`, `And`, `Like`, `In`, `Gte`, …):

```dart
final all  = await repository.findAll();
final one  = await repository.findById(42);
final some = await repository.findByQuery(query, params);
```

A grouped query is the one whose rows are not entities — its shape is decided by
the query, so it comes back as group keys plus aggregate values:

```dart
final rows = await repository.findGroupedByQuery(groupedQuery, params);
for (final row in rows) {
  print('${row.stringValue('status')}: ${row.intValue('n')}');
}
```

### Rendering SQL through the dialect

The dialect renders literals and bound-parameter placeholders, keeping untrusted
input out of the SQL string:

```dart
final dialect = TomStandardSqlDialect();
print(dialect.text('abc'));     // 'abc'
print(dialect.objectOp([1, 2, 3])); // 1,2,3
print(dialect.p('userId'));     // :userId
```

### Authentication, authorization, and health

`TomAuthenticationService` (with `TomAuthenticationAdaptor` / `Tom2FAAdaptor`
annotations) drives login, and `Tom2FARegistry` picks the second factor for a
principal — `TomTotp2FAService` ships as one. `TomAuthorizationCache` caches
authorization decisions on an isolate, over grants that are graded per key
(`TomResourceGrant`), held per resource (`TomPrincipalResourceGrant`), and
lendable to another principal (`TomPrincipalDelegation`).
`TomHealthService` / `TomHealthServer` expose health endpoints backed by
`TomHealthAnalyzer`s.

Those same grants filter the database. Install `TomResourceDataScope` once and
every entity carrying a `resource_key` column is scoped to the keys the current
principal holds a grant on, on reads *and* on writes — a `read` grade lists the
row, only `full` may change it, and resolution is live, so a revoked share stops
granting on the next request rather than at token expiry:

```dart
TomResourceDataScope.install(delegationResolver);
```

"Sign in with …" is wired in as one line, because it is not a second login path:

```dart
TomAuthenticationServer.globalSettingUserAuthenticationService =
    TomOAuthAuthenticationService(
      directory: MyDirectory(),  // your account lookup + provisioning policy
      delegate: TomAuthenticationServer.globalSettingUserAuthenticationService,
    );
```

`TomOAuthAuthenticationService` **implements `TomAuthenticationService`**. It
receives a `TomOAuthCredential` where a password login receives a password,
exchanges the authorization code, resolves the local account through
`TomExternalIdentityStore`'s `(issuer, subject)` linking table — and then stops.
It issues no token, consults no 2FA policy and makes no session decision,
because the result is handed to the same continuation a password login reaches.
An externally authenticated principal is therefore challenged for its second
factor and issued exactly the claims a password login would produce, not because
this is reimplemented but because it is never touched. Any credential that is
not a `TomOAuthCredential` passes through to the `delegate`, so an account may
hold a password *and* several external identities at once.

Providers are configuration data (`oauth.providers`), never code, and what a
first external login with no local account does — `refuse` or `autoProvision` —
is per-provider configuration too. See [`doc/authentication.md`](doc/authentication.md).

## Architecture

```
                       TomServer (shelf host)
                            │
         middleware: context · request-id · auth · logging · JSON errors
                            │
                    TomEndpointRouting
                            │
         ┌──────────────────┼───────────────────┐
   object_persistence   transactions        services
   (TomRepository)   (TomTransactionMgr)  (auth · cache · health)
         │
     datasources  →  MariaDbDatasource / MariaDbXADatasource (MySQL)
         │
     db_migration  →  TomDbMigrator (versioned schema)
```

| Type | Responsibility |
| ---- | -------------- |
| `TomServer` | HTTP host + middleware pipeline |
| `TomEndpointRouting` | Maps requests to endpoint handlers |
| `TomRepository` | CRUD + type-safe query repository |
| `TomDataSource` / `MariaDbDatasource` | Database connection driver |
| `TomQueryBuilder` | Builds type-safe queries from expression operators |
| `TomDbMigrator` | Applies versioned schema migrations |
| `TomTransactionManager` | Coordinates local/XA transactions |
| `TomBaseServerConfiguration` | Server configuration root |

## Ecosystem

```
tom_basics · tom_crypto · tom_reflection
                 │
          tom_core_kernel
                 │
          tom_core_server        ← you are here
          (re-exports the kernel; HTTP, persistence, migrations)
```

`tom_core_server` sits directly on `tom_core_kernel` and re-exports it, so server
apps get the full kernel API through one dependency. See the
[repository map](../README.md) for the full picture.

## Further documentation

- Per-module guides under [`doc/`](doc/) — one markdown file per module
  (`doc/object_persistence.md`, `doc/datasources.md`, `doc/endpoints.md`, …).
- Per-module API reference under [`doc/api_reference/`](doc/api_reference/) —
  start at
  [`doc/api_reference/api_summary_index.md`](doc/api_reference/api_summary_index.md)
  for the type index and one `api_summary_{module}.md` per module.
  (`doc/api/` is reserved for generated `dart doc` HTML and is gitignored.)
- [`tom_core_kernel`](../tom_core_kernel/README.md) — the platform-neutral
  building blocks this layer is composed from.

## Status

- **Version:** 1.3.0
- **Tests:** 3518 test cases across 92 module suites (run with `testkit :test`
  or `dart test`). 421 are tagged `db` and skip unless a live MySQL is
  reachable — bring one up with `tool/run_db_tests.sh`.
- **License:** BSD-3-Clause — see [LICENSE](LICENSE).
