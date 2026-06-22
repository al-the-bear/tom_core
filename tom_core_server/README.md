# tom_core_server

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

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
- **versioned schema migrations** and **local/XA transaction** coordination;
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
| `TomService` / `TomApiImplementation` | Annotations that turn a class into a routed API |

### Persistence (`object_persistence`, `datasources`)

| Type | Responsibility |
| ---- | -------------- |
| `TomRepository` / `TomSqlDatasourceRepository` | CRUD + type-safe query repository |
| `TomDbTable` / `TomDbColumn` / `TomEntityId` / `TomReference` | Entity-mapping annotations |
| `TomQueryBuilder` + `Eq` / `And` / `Like` / `In` / `Gte` … | Type-safe query expressions |
| `TomDataSource` / `MariaDbDatasource` / `MariaDbXADatasource` | Connection drivers (MariaDB/MySQL) |
| `TomDbType` family / `TomStandardSqlDialect` | Typed columns and SQL rendering |
| `TomSelect` / `TomCount` / `TomDelete` | Generated query objects |

### Schema & transactions (`db_migration`, `transactions`)

| Type | Responsibility |
| ---- | -------------- |
| `TomDbMigrator` / `TomDbMigrations` / `TomDbVersion` | Versioned schema migrations (MariaDB adapter) |
| `TomTransactionManager` / `TomTransaction` / `TomTransactionParticipant` | Local/XA transaction coordination |

### Platform services (`configuration`, `cache`, `authentication`, `authorization`, `healthcheck`, `cmdline`)

| Module | Key types | What it does |
| ------ | --------- | ------------ |
| `configuration` | `TomBaseServerConfiguration`, `TomServerConfigResourceProvider`, `TomConfig<T>`, `TomYaml` | Typed config + YAML resources |
| `cache` | `TomCache`, `TomCacheManager` | Isolate-backed server-side cache |
| `authentication` | `TomAuthenticationService`, `TomAuthenticationData`, `TomAuthenticationAdaptor`, `Tom2FAAdaptor` | Authentication service + adaptor annotations |
| `authorization` | `TomAuthorizationCache` | Isolate-backed authorization cache |
| `healthcheck` | `TomHealthService`, `TomHealthServer`, `HealthAnalyzer` | Health endpoints and analyzers |
| `cmdline` | `TomArgs`, `TomEnvFile` | Argument parsing and `.env` loading |
| `little_things` | `TomServerException` | Server exception base (extends kernel `TomException`) |

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
| [`example/authentication/`](example/authentication/) · [`example/authorization/`](example/authorization/) | Auth service + authorization cache |
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
annotations) drives login; `TomAuthorizationCache` caches authorization
decisions on an isolate; `TomHealthService` / `TomHealthServer` expose health
endpoints backed by `HealthAnalyzer`s.

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
- [`tom_core_kernel`](../tom_core_kernel/README.md) — the platform-neutral
  building blocks this layer is composed from.
- [`tom_core_d4rt`](../tom_core_d4rt/README.md) — exposes the server API to
  `d4rt` scripts.

## Status

- **Version:** 1.1.0
- **Tests:** 216 test cases across 15 module suites (run with `testkit :test`
  or `dart test`).
- **License:** proprietary — see [LICENSE](LICENSE).
</content>
</invoke>
