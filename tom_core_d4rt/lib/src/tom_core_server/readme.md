# tom_core_server

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

Generated D4rt bridge for **[`tom_core_server`](../../../../tom_core_server/README.md)**.
Registering `tom_core_d4rt` exposes the server toolkit to sandboxed DartScript,
so REPL sessions and `.d4rt` scripts can
`import 'package:tom_core_server/tom_core_server.dart'` and use the datasources,
persistence, endpoint and authorization types directly. The bridge forwards the
API unchanged.

## What it bridges

The `TomCoreServerBridge` container registers the public surface of
`tom_core_server`, including the server/endpoints (`TomServer`,
`TomEndpointRouting`), object persistence (`TomRepository`,
`TomSqlDatasourceRepository`, the `TomDbTable`/`TomDbColumn`/`TomEntityId`
annotations), the query builder (`TomQueryBuilder` and the `Eq`/`And`/`Like`/`In`
operators), datasources (`MariaDbDatasource`, `MariaDbXADatasource`,
`TomStandardSqlDialect`), caching (`TomCache`, `TomCacheManager`), transactions
(`TomTransactionManager`, `TomTransaction`), configuration, authentication and
healthcheck types. For the authoritative API, read the upstream package README;
this bridge mirrors it.

## Use it from a script

```dart
// d4rt REPL or a .d4rt script — the bridge is pre-registered.
import 'package:tom_core_server/tom_core_server.dart';

// Datasource, repository, endpoint and auth types are now in scope.
```

Inside the REPL, `info tom_core_server` lists every bridged class and `classes`
lists them across all packages.

---

Bridges **[`tom_core_server`](../../../../tom_core_server/README.md)** · see
[`doc/tom_core_server.md`](../../../doc/tom_core_server.md) for generation notes.
Part of [`tom_core_d4rt`](../../../README.md) — see the package README for the
REPL, the full bridge list, and build instructions.
