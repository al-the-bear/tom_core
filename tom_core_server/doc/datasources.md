# Datasources Module

The data-access foundation of the server: **SQL-typed values**
(`TomDbType<T>`), a typed **operator tree** (`TomOperator<R>`), a **SQL dialect**
that renders that tree to SQL fragments (`TomStandardSqlDialect`), reusable
**query objects** (`TomSelect`, `TomCount`, `TomDelete`, `TomLiteralSelect`),
and the **data-source / driver** abstraction (`TomDataSource`,
`TomDatasourceDriver`, `TomDataSourceInfo`) with a MariaDB implementation. The
object-persistence module builds its query DSL and repositories on top of this
layer.

## Table of Contents

- [Overview](#overview)
- [SQL-Typed Values](#sql-typed-values)
- [The Operator Tree](#the-operator-tree)
- [The SQL Dialect](#the-sql-dialect)
- [Query Objects](#query-objects)
- [Data Sources and Drivers](#data-sources-and-drivers)
- [The MariaDB Driver](#the-mariadb-driver)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomDbType<T>` (+ `TomDbInt`/`TomDbDouble`/`TomDbString`/`TomDbDateTime`/`TomDbDate`/`TomDbTime`/`TomDbBool`) | class | A boxed, SQL-typed value with a parsing `of(String?)` factory |
| `TomOperator<R>` | abstract class | A node in a SQL expression tree, typed by its SQL return type `R` |
| `SqlString` | typedef | A `String` that documents "this is a SQL fragment" |
| `TomStandardSqlDialect` | class | Renders operator nodes to standard-SQL fragments |
| `TomSqlDialect` | annotation | Binds a dialect subclass to a data-source type |
| `TomQuery` / `TomGeneratedQuery` | abstract class | A query over a set of entity types |
| `TomSelect` / `TomCount` / `TomDelete` / `TomLiteralSelect` | class | Concrete statements |
| `TomTypePersistenceInfo` | reflected class | Per-type persistence metadata (table + columns) |
| `TomDataSource` | abstract class | A connection to one data source (lifecycle + execution) |
| `TomPreparedStatement<T>` | abstract class | A reusable compiled statement |
| `TomDatasourceDriver` | annotation | Marks a `TomDataSource` as the driver for a named type |
| `TomDataSourceInfo` | class | The process-wide registry of named, configured data sources |
| `MariaDbDatasource` / `MariaDbXADatasource` / `MariadbSqlDialect` | class | The MariaDB implementation (plain + XA transactions) |

## SQL-Typed Values

`TomDbType<T>` boxes a nullable Dart value together with the SQL column type it
maps to. Each concrete type exposes a static `of(String?)` that parses a string
(as read from a driver result set) into the boxed type; a `null` string always
yields a box holding `null`:

```dart
TomDbInt.of('42').get();        // 42
TomDbBool.of('true').get();     // true
TomDbDouble.of(null).get();     // null
TomDbString.of('hello').get();  // 'hello'   (wrapped verbatim)
```

These types parameterise the operator tree, keeping operands type-safe.

## The Operator Tree

`TomOperator<R>` is one node of a SQL expression, typed by its SQL return type
`R` (`TomOperator<TomDbBool>` is a predicate, `TomOperator<TomDbString>` a text
expression, …). A node knows how to:

- `generate(dialect)` — render its SQL fragment;
- `getFields(dialect)` — report the columns it references;
- `getParameters(dialect)` — report the positional parameters it contributes.

The object-persistence query builder provides the concrete factories (literals,
field references, comparisons, `AND`/`OR`, …); this module supplies the base
contract and the dialect they render against.

## The SQL Dialect

`TomStandardSqlDialect` turns operator nodes into SQL fragments — one method per
construct:

```dart
final d = TomStandardSqlDialect();
d.text('abc');                 // 'abc'            (single-quoted literal)
d.intOp(42);                   // 42
d.p('userId');                 // :userId          (bound parameter placeholder)
d.objectOp(['a', 1, true]);    // 'a',1,true       (comma-joined list)
d.nullOp();                    // NULL
```

Literal renderers (`text`, `intOp`, `objectOp`, …) interpolate the value
directly into the SQL string; for untrusted input prefer the parameterised form
`p(name)` so the driver binds the value. (Escaping of directly-interpolated
literals is a tracked follow-up — see the completion steps.)

A driver supplies its own dialect by subclassing and annotating with
`@TomSqlDialect("<type>")`; `MariadbSqlDialect` does this and inherits the
standard generation unchanged.

## Query Objects

A query is built over a set of entity `types` and renders to SQL via
`generateQuery(dialect)`. The generated forms wrap a `TomOperator<TomDbBool>`
predicate with shaping options (`distinct`, `orderBy`, `ascending`, `top`):

| Class | Renders |
| ----- | ------- |
| `TomSelect` | `SELECT … FROM … WHERE <predicate> [ORDER BY …]` |
| `TomCount` | `SELECT COUNT(*) AS count FROM … WHERE <predicate>` |
| `TomDelete` | `DELETE FROM <first table> WHERE <predicate>` |
| `TomLiteralSelect` | a raw, hand-written SQL string with explicit parameters |

`TomLiteralSelect` is the escape hatch for statements the generated queries
cannot express; its `types` still drive result-row mapping.

## Data Sources and Drivers

`TomDataSource` is the abstract contract a database driver implements: its
`sqlDialect`, lifecycle (`initialize` / `close` / `isOperational`), and
execution surface (`prepareStatement`, `executeCommand` for writes returning an
affected-row count, `executeQuery` for reads). It is a
`TomTransactionParticipant`, so it can enlist in a transaction.

A driver registers by annotating its class with `@TomDatasourceDriver("<type>")`
and `@tomReflector`. `TomDataSource.createDatasourceOf(type)` discovers drivers
by scanning reflection metadata on first use and returns a fresh instance.

`TomDataSourceInfo` is the process-wide registry of *named, configured* data
sources. `initializeDatasourceInfo(config)` builds an entry per map-valued
configuration key and opens each connection; `getDataSourceInfo(name)` looks one
up; `closeAll()` shuts them down. A `delegateTo` setting aliases one name onto
another already-registered data source instead of opening a second connection:

```dart
await TomDataSourceInfo.initializeDatasourceInfo({
  'main': {'type': 'mariadb', 'host': 'db', 'port': 3306, 'username': 'app', 'password': '…', 'databaseName': 'app'},
  'reporting': {'delegateTo': 'main'},
});
final ds = TomDataSourceInfo.getDataSourceInfo('main')!.datasource;
```

## The MariaDB Driver

`MariaDbDatasource` (`@TomDatasourceDriver("mariadb")`) connects to MariaDB /
MySQL. Connection settings (`username`, `password`, `host`, `port`,
`databaseName`, `timeOut`) are filled from the configuration map by reflection
in `initialize`, which then opens the connection. `executeQuery` maps result
rows back onto annotated `@tomReflector` entity classes (including JSON columns,
custom converters, and reference-field dereferencing). Transactions use plain
`START TRANSACTION` / `COMMIT` / `ROLLBACK`.

`MariaDbXADatasource` (`@TomDatasourceDriver("mariadb_xa")`) inherits all of
that but overrides the transaction lifecycle to use **XA** (`XA START` / `XA
END` + `XA PREPARE` / `XA COMMIT` / `XA ROLLBACK`), so it can take part in a
two-phase commit across multiple resources.

> The MariaDB driver requires a live database connection and is therefore not
> exercised by the unit tests; the tests cover the connection-independent
> surface (the dialect's SQL generation and the SQL-typed value conversions).

## Core Components

- **`TomDbType<T>`** and its concrete subtypes — boxed SQL values with
  `of(String?)` parsing.
- **`TomOperator<R>`** — the typed SQL expression node (`generate`, `getFields`,
  `getParameters`).
- **`TomStandardSqlDialect`** (+ the `TomSqlDialect` annotation) — SQL-fragment
  generation; `SqlString`.
- **`TomQuery` / `TomGeneratedQuery`** and `TomSelect` / `TomCount` /
  `TomDelete` / `TomLiteralSelect` — query objects; `TomTypePersistenceInfo` /
  `TomTypedPersistenceBase` for the per-type metadata.
- **`TomDataSource`** (+ `TomPreparedStatement`, `TomDatasourceDriver`,
  `TomDataSourceInfo`) — the data-source/driver abstraction and registry.
- **`MariaDbDatasource` / `MariaDbXADatasource` / `MariadbSqlDialect`** — the
  MariaDB implementation.

## Dependencies

- `tom_core_kernel` — `TomObject`, `tomReflector` / `ClassMirror` /
  `InstanceMirror`, `TomException`, `TomZonedDate` / `TomZonedTime`,
  `TomExecutionContext`, `runChecked` / `runCheckedSync`, `tomLog`.
- The transactions module — `TomTransactionParticipant`.
- The object-persistence module — `TomAnnotationAnalyzer`,
  `TomColumnInformation`, `TomDbTable`, `DbCol`, `TomQuerySentenceCompiler`.
- `mysql_client` — the MariaDB / MySQL driver used by `MariaDbDatasource`.
