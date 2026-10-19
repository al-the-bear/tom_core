# datasources

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The SQL datasource layer: a database-neutral `TomDataSource` contract plus two
SQL drivers — MariaDB/MySQL and PostgreSQL 15+ — a typed SQL-dialect renderer,
and typed query objects. `TomStandardSqlDialect` (specialised by
`MariadbSqlDialect` and `PostgresSqlDialect`) renders `TomSelect` / `TomCount` /
`TomDelete`, the `TomDbType` column family and the framework's own canonical
DDL into SQL strings. `TomSqlDatasource` is everything a SQL driver does that
does not depend on the database: it draws connections from a
`TomConnectionPool` — one per transaction, one per statement outside a
transaction — runs prepared statements on them, and maps rows read as text in
one convention. `MariaDbDatasource` and `PostgresDatasource` supply the wire;
`MariaDbXADatasource` and `PostgresXADatasource` add two-phase participation.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomDataSource` | Abstract datasource contract (a `TomTransactionParticipant`); `TomDatasourceDriver` / `TomDataSourceInfo` describe a driver. |
| `TomSqlDatasource` · `TomSqlPreparedStatement<T>` | The driver-neutral SQL data source: settable `host`/`port`/`username`/`password`/`databaseName`/`timeOut` and the `pool…` settings, then `connect()`. Concurrent transactions run side by side, each on a pooled connection of its own (`TomSqlBranch`); a statement lost with its connection is retried once outside a transaction (`TomSqlConnectionLostException`). Failures are `TomSqlDatasourceException`s. |
| `TomSqlRow` · `TomSqlResult` · `TomSqlResultValues` · `TomSqlLink` | What a driver hands the shared mapper: a result whose every column reads as text in one convention, and the pooled connection it ran on. `tomSqlBindValue` / `tomSqlBindParams` marshal bind values the same way for every driver; `tomSqlBranchId` names a two-phase branch. |
| `MariaDbDatasource` | MariaDB/MySQL driver (`"mariadb"`); `withDriverConnection` hands a body the `mysql_client` connection a statement would use. |
| `PostgresDatasource` · `PostgresSqlDialect` | PostgreSQL 15+ driver (`"postgresql"`) and its dialect: `schema` (the `search_path`) and `sslMode` settings, sessions in UTC, `$n` placeholders, generated keys read back through `RETURNING`. `PostgresXADatasource` (`"postgresql_xa"`) is the two-phase variant over `PREPARE TRANSACTION`. Failures are `PostgresDatasourceException` / `PostgresConnectionLostException`. |
| `TomConnectionPool<C>` · `TomConnectionPoolSettings` · `TomConnectionFactory<C>` | The driver-neutral bounded pool: lends a connection per caller up to `maxSize`, makes callers wait in line up to `acquireTimeout`, and retires idle and old connections lazily, on use. `TomConnectionPoolException` reports a closed pool, a wait that timed out, or unusable settings. |
| `MariaDbXADatasource` | XA (two-phase-commit) variant of the MariaDB driver. |
| `TomPreparedStatement<T>` · `TomStatementOutcome<T>` | A compiled statement shared by every request that runs it; `run` returns what that one execution reported — rows, affected-row count, generated key — rather than leaving it on the shared handle, where an overlapping execution would overwrite it. |
| `TomStandardSqlDialect` · `MariadbSqlDialect` | Render queries and types into SQL, and the framework's canonical DDL — MariaDB's spelling — and conflicting writes (`insertInto`, `replaceInto`, `incrementCounter`, `returningKey`) into each database's own words. |
| `TomSelect` · `TomCount` · `TomDelete` · `TomLiteralSelect` | Typed generated queries. |
| `TomDbType<T>` family | Column types: `TomDbInt`, `TomDbDouble`, `TomDbString`, `TomDbBool`, `TomDbDateTime`, `TomDbDate`, `TomDbTime`. |
| `sqlInstant` · `parseSqlInstant` | The one encoding of an instant in a `DATETIME(6)` column — see below. |
| `sqlDate` · `parseSqlDate` · `sqlTimeOfDay` · `parseSqlTimeOfDay` | The two halves an instant splits into, written and read as labelled: a `DATE` and a `TIME` column. |
| `TomFrameworkTable` · `TomFrameworkColumn` · `TomFrameworkKey` | The single declaration of a table the framework itself owns, from which its DDL (`create` renders it for the connected database), its row writes (`insertRow`, `replaceRow`), its reflected row type and the convergence check are all derived. `frameworkOwnedTables()` lists them; `unknownFrameworkColumns` audits a hand-written statement against one. |
| `TomSqlFailureMode` · `classifySqlFailure` | Whether a failed write is known not to have happened (`definite`) or may have (`ambiguous`) — the difference between a safe retry and a duplicate. `isLostConnectionFailure` is the narrower question the driver's own retry asks. |
| `SqlPlaceholderScan` | Rewrites the generated `:name` placeholders into the positional form a driver binds — `?` for MariaDB, `$1`, `$2`, … for PostgreSQL — leaving quoted text and `::` casts alone. |
| `TomSqlLexer` | The package's one quote- and comment-aware SQL scanner: where a quoted run ends, where a comment ends, and `splitStatements`. The driver uses it to refuse a multi-statement command; `db_migration`'s applier and DDL reader are written on it. |

## Instants are UTC, everywhere

A MariaDB `DATETIME` (a PostgreSQL `TIMESTAMP`) carries no zone, and the MariaDB driver materialises one with
`DateTime.parse`, which yields a **local** value — the reader's wall clock, not
the writer's moment. Left alone, two servers of one cluster leave different
characters in the same column for the same instant and each reads the other's
rows off by the difference in their offsets.

`sql_instant.dart` settles it once, for both ways of writing SQL in this server:

- **Hand-written SQL** (scheduling, OAuth state, SCIM resources, audit, file
  storage) calls
  `sqlInstant` / `parseSqlInstant` at each seam explicitly.
- **Reflected entity columns** name no conversion at all, so this module applies
  it on their behalf: the bind boundary (`tomSqlBindValue`) renders every bound `DateTime`
  through `sqlInstant`, `TomDbDateTime.of` reads a column back through
  `parseOptionalSqlInstant`, and `dateTimeOp` inlines the same text as a
  literal. An entity stores UTC and reads UTC without saying so. Rows from a
  prepared statement (every repository read) arrive over the binary protocol,
  where the driver writes a `DATETIME`'s microseconds unpadded (`.91371` for
  91 371 µs); the data source restores the six-digit fraction for exactly those
  rows. The PostgreSQL driver runs every session in UTC and renders the typed
  values its protocol delivers into the same text, so the mapper reads one
  convention from both.

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
    print(db.connected); // true once a pooled connection is established
  } finally {
    // An open connection holds a socket, and a live socket holds the isolate
    // open. A server closes its datasources at shutdown (or through
    // `TomDataSourceInfo.closeAll`); a script has to close its own, or it
    // prints its result and then never returns.
    await db.close();
  }
}
```

> **Needs a live database.** `connect()` opens the pool's first connection, a
> real socket to the MariaDB
> named above, so this is a program to run against your own server rather than
> one to paste and expect to work — without a listener on `localhost:3306` it
> fails at the `connect()` line. Everything after that line, including the
> close, is what a script that *does* reach a database must do.

See [`doc/datasources.md`](../../../../doc/datasources.md) for the driver
registry, the connection pool, the connection lifecycle and the transaction
seam, and
`example/datasources/datasources_example.dart` for a walkthrough of ten
surfaces in order — SQL value boxing and parsing, literal rendering, bound
parameters, the instant encoding, the clause builders, the classification of a
failed write and the walk over an expression tree. Those are pure functions over their arguments, so unlike the
snippet above the example runs green as it stands; the drivers and the registry
are the part that needs a server, and the example says so rather than
pretending otherwise. `test/datasources_test.dart` covers the module and also
runs the example, requiring it to print every numbered step and no others;
`test/connection_pool_test.dart` covers the pool over a fake factory and clock;
`test/mariadb_row_mapping_test.dart` covers the row mapper's five shapes, its
refusal of an unreflected result type and the text spellings its numeric readers
decide on, over a result set that carries what the protocol carries and hands
every typed read to the driver's own converter;
`test/datasources_db_test.dart` adds what only a live database can answer — run
against MariaDB by `tool/run_db_tests.sh` and against PostgreSQL by
`tool/run_db_tests_postgres.sh` — and self-skips when none is reachable. The framework-table descriptors have two
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
