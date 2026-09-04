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
| `sqlInstant` · `parseSqlInstant` | The one encoding of an instant in a `DATETIME(6)` column — see below. |

## Instants are UTC, everywhere

A MariaDB `DATETIME` carries no zone, and the driver materialises one with
`DateTime.parse`, which yields a **local** value — the reader's wall clock, not
the writer's moment. Left alone, two servers of one cluster leave different
characters in the same column for the same instant and each reads the other's
rows off by the difference in their offsets.

`sql_instant.dart` settles it once, for both ways of writing SQL in this server:

- **Hand-written SQL** (scheduling, OAuth state, audit, file storage) calls
  `sqlInstant` / `parseSqlInstant` at each seam explicitly.
- **Reflected entity columns** name no conversion at all, so this module applies
  it on their behalf: the MariaDB bind boundary renders every bound `DateTime`
  through `sqlInstant`, `TomDbDateTime.of` reads a column back through
  `parseOptionalSqlInstant`, and `dateTimeOp` inlines the same text as a
  literal. An entity stores UTC and reads UTC without saying so.

The corollary for DDL: a column holding an instant is `DATETIME(6)`. A plain
`DATETIME` rounds the microseconds this convention always writes, which moves
the stored moment by up to half a second.

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
  try {
    print(db.connected); // true once the connection is established
  } finally {
    // An open connection holds a socket, and a live socket holds the isolate
    // open. A server closes its datasources at shutdown (or through
    // `TomDataSourceInfo.closeAll`); a script has to close its own, or it
    // prints its result and then never returns.
    await db.close();
  }
}
```

> **Needs a live database.** `connect()` opens a real socket to the MariaDB
> named above, so this is a program to run against your own server rather than
> one to paste and expect to work — without a listener on `localhost:3306` it
> fails at the `connect()` line. Everything after that line, including the
> close, is what a script that *does* reach a database must do.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
