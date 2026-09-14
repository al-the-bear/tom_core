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
| `sqlDate` · `parseSqlDate` · `sqlTimeOfDay` · `parseSqlTimeOfDay` | The two halves an instant splits into, written and read as labelled: a `DATE` and a `TIME` column. |
| `TomFrameworkTable` · `TomFrameworkColumn` · `TomFrameworkKey` | The single declaration of a table the framework itself owns, from which its DDL, its reflected row type and the convergence check are all derived. `frameworkOwnedTables()` lists them; `unknownFrameworkColumns` audits a hand-written statement against one. |
| `TomSqlFailureMode` · `classifySqlFailure` | Whether a failed write is known not to have happened (`definite`) or may have (`ambiguous`) — the difference between a safe retry and a duplicate. `isLostConnectionFailure` is the narrower question the driver's own retry asks. |
| `SqlPlaceholderScan` | Rewrites the generated `:name` placeholders into the positional `?` form the MySQL binary protocol binds, leaving quoted text alone. |

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

See [`doc/datasources.md`](../../../../doc/datasources.md) for the driver
registry, the connection lifecycle and the transaction seam, and
`example/datasources/datasources_example.dart` for a walkthrough of ten
surfaces in order — SQL value boxing and parsing, literal rendering, bound
parameters, the instant encoding, the clause builders, the classification of a
failed write and the walk over an expression tree. Those are pure functions over their arguments, so unlike the
snippet above the example runs green as it stands; the drivers and the registry
are the part that needs a server, and the example says so rather than
pretending otherwise. `test/datasources_test.dart` covers the module and also
runs the example, requiring it to print every numbered step and no others;
`test/mariadb_row_mapping_test.dart` covers the row mapper's five shapes, its
refusal of an unreflected result type and the text spellings its numeric readers
decide on, over a result set that carries what the protocol carries and hands
every typed read to the driver's own converter;
`test/datasources_db_test.dart` adds what only a live MariaDB can answer, and
self-skips when none is reachable. The framework-table descriptors have two
files of their own: `test/framework_table_test.dart` for what they render and
refuse, and `test/framework_schema_test.dart` for what they have to agree with. `@TomReference` is split across two files for
the same reason: `test/reference_query_test.dart` covers the sentence the
annotation produces, which needs no connection, and
`test/reference_association_db_test.dart` covers what the driver does with the
rows it returns — including that an *n*-row read costs *n* reference queries
rather than *n²*, which is a statement count because the answer is the same
either way.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
