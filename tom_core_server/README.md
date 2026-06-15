# Tom Core Server

`tom_core_server` is the server-side layer of the Tom Framework. It builds on
the platform-neutral [`tom_core_kernel`](../tom_core_kernel) (dependency
injection, observable state, security, resources) and adds the pieces a backend
service needs: an HTTP/WebSocket host, an endpoint pipeline, a relational
persistence layer with a type-safe query model, database datasources and
migrations, server configuration, caching, and authentication/authorization
services.

Because it re-exports the kernel through its own barrel, a server app only needs
to depend on `tom_core_server` — importing it gives you both the kernel API and
the server extensions.

## Getting started

This package is internal to the Tom workspace and is consumed by path:

```yaml
dependencies:
  tom_core_server:
    path: ../tom_core_server
```

Import the single barrel — it re-exports `tom_core_kernel`,
`tom_basics_console`, and the MariaDB client, so you rarely need to import those
directly:

```dart
import 'package:tom_core_server/tom_core_server.dart';
```

## Usage

Construct a server from a configuration and start it:

```dart
import 'package:tom_core_server/tom_core_server.dart';

void main(List<String> argv) {
  // `configuration` is your subclass of TomBaseServerConfiguration.
  final server = TomServer(configuration);
  server.start();
}
```

Read environment/config and command-line arguments:

```dart
// Parse "key=value" arguments into a typed config object via reflection:
final config = TomArgs.fillFromArgs(argv, MyServerArgs());

// Load a .env file into a typed map (int/double/bool/String):
final env = TomEnvFile.read('.env');
```

Repositories expose CRUD plus type-safe queries built from the expression
operators (`Eq`, `And`, `Like`, `In`, `Gte`, …):

```dart
final all = await repository.findAll();
final one = await repository.findById(42);
final some = await repository.findByQuery(query, params);
```

## Modules

| Module | Summary |
| ------ | ------- |
| Server | `TomServer` — the shelf-based HTTP/WebSocket host, with request IDs, diagnostics, monitoring, and form handling |
| Endpoints | `TomEndpoint` / `TomEndpointHandler` / `TomEndpointRouting` and the `TomService` / `TomApiImplementation` annotations — declarative endpoints and the request-handling pipeline |
| Object Persistence | `TomRepository` / `TomSqlDatasourceRepository`, persistence annotations (`TomDbTable`, `TomDbColumn`, `TomEntityId`, `TomReference`), the `TomQueryBuilder`, and the expression operators (`Eq`, `And`, `Like`, `In`, …) — an ORM-style layer with type-safe queries |
| Datasources | `TomDataSource` and the MariaDB driver (`MariaDbDatasource` / `MariaDbXADatasource`), SQL dialects, the `TomDbType` typed-column model, and the `TomQuery` family (`TomSelect`, `TomCount`, `TomDelete`) |
| DB Migration | `TomDbMigrator` / `TomDbMigrations` / `TomDbVersion` with a MariaDB adapter — versioned schema migrations |
| Transactions | `TomTransactionManager`, `TomTransaction`, `TomTransactionParticipant` — local/XA transaction coordination |
| Configuration | `TomBaseServerConfiguration`, `TomServerConfigResourceProvider`, typed `TomConfig<T>` values, and `TomYaml` YAML resources |
| Cache | `TomCache` / `TomCacheManager` — an isolate-backed server-side cache |
| Authentication | `TomAuthenticationService`, `TomAuthenticationData`, and the `TomAuthenticationAdaptor` / `Tom2FAAdaptor` annotations |
| Authorization | `TomAuthorizationCache` — an isolate-backed authorization cache |
| Health Check | `TomHealthService` / `TomHealthServer` and `HealthAnalyzer` — health endpoints and analyzers |
| Command Line | `TomArgs` and `TomEnvFile` — argument parsing and `.env` file loading |
| Little Things | `TomServerException` — the server-side exception base extending the kernel `TomException` |

## Additional information

- **Kernel API:** all of `tom_core_kernel` is re-exported here; see its
  [README](../tom_core_kernel/README.md) and module docs for the underlying
  building blocks.
- **Database:** the included datasource, migration, and repository
  implementations target **MariaDB/MySQL** via `mysql_client`. The datasource,
  dialect, migration, and repository contracts are abstract, so other backends
  can be added.
- **Tests:** run with `dart test` from the package root.
- **License:** proprietary — see [LICENSE](LICENSE).
