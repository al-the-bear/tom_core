# datasources

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The SQL datasource layer: a database-neutral `TomDataSource` contract plus the
MariaDB/MySQL driver, a typed SQL-dialect renderer, and typed query objects.
`TomStandardSqlDialect` (specialised by `MariadbSqlDialect`) renders `TomSelect`
/ `TomCount` / `TomDelete` and the `TomDbType` column family into SQL strings;
`MariaDbDatasource` opens the connection and runs prepared statements.
`MariaDbXADatasource` adds XA (two-phase) participation.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomDataSource` | Abstract datasource contract (a `TomTransactionParticipant`); `TomDatasourceDriver` / `TomDataSourceInfo` describe a driver. |
| `MariaDbDatasource` | MariaDB/MySQL driver: settable `host`/`port`/`username`/`password`/`databaseName`/`timeOut`, then `connect()`. |
| `MariaDbXADatasource` | XA (two-phase-commit) variant of the MariaDB driver. |
| `TomStandardSqlDialect` · `MariadbSqlDialect` | Render queries and types into SQL. |
| `TomSelect` · `TomCount` · `TomDelete` · `TomLiteralSelect` | Typed generated queries. |
| `TomDbType<T>` family | Column types: `TomDbInt`, `TomDbDouble`, `TomDbString`, `TomDbBool`, `TomDbDateTime`, `TomDbDate`, `TomDbTime`. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  final db = MariaDbDatasource()
    ..host = 'localhost'
    ..port = 3306
    ..username = 'todo'
    ..password = 'secret'
    ..databaseName = 'todo';

  await db.connect();
  print(db.connected); // true once the connection is established
}
```

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
