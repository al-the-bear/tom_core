# Tom Core Server API Reference: Datasources Module

The data-access foundation of the server: SQL-typed values (`TomDbType<T>`), a
typed operator tree (`TomOperator<R>`), a SQL dialect that renders that tree to
SQL fragments (`TomStandardSqlDialect`), reusable query objects (`TomSelect`,
`TomCount`, `TomDelete`, `TomLiteralSelect`), and the data-source / driver
abstraction (`TomDataSource`, `TomDatasourceDriver`, `TomDataSourceInfo`) with a
MariaDB implementation. Two smaller surfaces sit beside them because every
table has them whichever module owns it: `TomFrameworkTable` declares a table
the framework itself owns, once, and `sqlInstant` / `parseSqlInstant` are the
one encoding of an instant in a `DATETIME(6)` column. The object-persistence
module builds its query DSL and repositories on top of this layer.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [SQL-Typed Values](#sql-typed-values)
    - [TomDbType&lt;T&gt;](#tomdbtypet)
    - [TomDbInt](#tomdbint)
    - [TomDbDouble](#tomdbdouble)
    - [TomDbString](#tomdbstring)
    - [TomDbDateTime](#tomdbdatetime)
    - [TomDbDate](#tomdbdate)
    - [TomDbTime](#tomdbtime)
    - [TomDbBool](#tomdbbool)
  - [The Operator Tree](#the-operator-tree)
    - [TomOperator&lt;R&gt;](#tomoperatorr)
  - [The SQL Dialect](#the-sql-dialect)
    - [TomStandardSqlDialect](#tomstandardsqldialect)
    - [MariadbSqlDialect](#mariadbsqldialect)
  - [Persistence Metadata](#persistence-metadata)
    - [TomTypePersistenceInfo](#tomtypepersistenceinfo)
    - [TomTypedPersistenceBase](#tomtypedpersistencebase)
  - [Query Objects](#query-objects)
    - [TomQuery](#tomquery)
    - [TomGeneratedQuery](#tomgeneratedquery)
    - [TomSelect](#tomselect)
    - [TomLiteralSelect](#tomliteralselect)
    - [TomCount](#tomcount)
    - [TomDelete](#tomdelete)
  - [Data Sources and Drivers](#data-sources-and-drivers)
    - [TomDataSource](#tomdatasource)
    - [TomPreparedStatement&lt;T&gt;](#tompreparedstatementt)
    - [TomDatasourceDriver](#tomdatasourcedriver)
    - [TomDataSourceInfo](#tomdatasourceinfo)
  - [The MariaDB Driver](#the-mariadb-driver)
    - [MariaDbDatasource](#mariadbdatasource)
    - [MariaDbXADatasource](#mariadbxadatasource)
    - [MariadbPreparedStatement&lt;T&gt;](#mariadbpreparedstatementt)
  - [Placeholder Scanning](#placeholder-scanning)
    - [SqlPlaceholderScan](#sqlplaceholderscan)
  - [Framework-Owned Tables](#framework-owned-tables)
    - [TomFrameworkColumn](#tomframeworkcolumn)
    - [TomFrameworkKey](#tomframeworkkey)
    - [TomFrameworkTable](#tomframeworktable)
  - [Exceptions](#exceptions)
    - [TomDatasourceInitException](#tomdatasourceinitexception)
    - [MariadbDatasourceException](#mariadbdatasourceexception)
    - [MariadbPreparedStatementException](#mariadbpreparedstatementexception)
- [Enums](#enums)
  - [TomAggregateFunction](#tomaggregatefunction)
  - [TomSqlTypeFamily](#tomsqltypefamily)
  - [TomSqlFailureMode](#tomsqlfailuremode)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/datasources/datasource_initialization.dart`,
`lib/src/tomserver/datasources/framework_table.dart`,
`lib/src/tomserver/datasources/mariadb_datasource.dart`,
`lib/src/tomserver/datasources/mariadb_sql_dialect.dart`,
`lib/src/tomserver/datasources/queries.dart`,
`lib/src/tomserver/datasources/sql_dialects.dart`,
`lib/src/tomserver/datasources/sql_failure_mode.dart`,
`lib/src/tomserver/datasources/sql_instant.dart`,
`lib/src/tomserver/datasources/sql_placeholder_scan.dart`,
`lib/src/tomserver/datasources/types_operator.dart`.

A `TomDbType<T>` boxes a Dart value together with its SQL column type; a
`TomOperator<R>` is a node in a type-safe SQL expression tree that renders
itself through a `TomStandardSqlDialect`. Query objects (`TomSelect`,
`TomCount`, `TomDelete`, `TomLiteralSelect`) wrap a predicate into a full
statement. `TomAggregateFunction` and four dialect fragments (`aggregate`,
`aliased`, `groupByClause`, `havingClause`) are the whole SQL surface a grouped
query renders through — the query object itself, `TomGroupedSelect`, is declared
in the object-persistence module because it is built from that module's
aggregate nodes. A `TomDataSource` is a driver-implemented connection that prepares
statements, runs commands and queries, and enlists in transactions;
`TomDataSourceInfo` is the process-wide registry of named, configured data
sources. The MariaDB driver (`MariaDbDatasource`, plus the XA variant
`MariaDbXADatasource`) implements the full surface, and `SqlPlaceholderScan`
rewrites the generated `:name` placeholders into the positional `?` form the
MySQL binary protocol binds.

Two surfaces here are about *tables* rather than about queries, and are in this
module because they belong to no single module that uses them. A
`TomFrameworkTable` — with its `TomFrameworkColumn` and `TomFrameworkKey`
parts — is the single declaration of a table the framework itself owns (the job
queue, the lease table, the blob pair, the audit trail), from which its DDL,
its column lists and its inserts are all derived, and `unknownFrameworkColumns`
audits the column references that a column list cannot cover. `sqlInstant`,
`parseSqlInstant` and `parseOptionalSqlInstant` are the one encoding of an
instant in a `DATETIME(6)` column: always UTC, always six fractional digits.
That convention is not optional — a `DATETIME` carries no zone, so a column
read with a bare `DateTime.parse` yields the *reader's* wall clock rather than
the writer's moment. See [Instants Are UTC](../datasources.md#instants-are-utc)
and [Framework-Owned Tables](../datasources.md#framework-owned-tables) for the
reasoning behind both.

## Class Hierarchy

```
TomObject<T>  (kernel)
    └── TomDbType<T>
            ├── TomDbInt
            ├── TomDbDouble
            ├── TomDbString
            ├── TomDbDateTime
            ├── TomDbDate
            ├── TomDbTime
            └── TomDbBool

TomOperator<R>

TomStandardSqlDialect
    └── MariadbSqlDialect

TomDatasourceDriver  (annotation)

TomTypedPersistenceBase
    └── TomQuery
            ├── TomGeneratedQuery
            │       ├── TomSelect
            │       ├── TomCount
            │       ├── TomDelete
            │       └── TomGroupedSelect  (object_persistence)
            └── TomLiteralSelect

TomTypePersistenceInfo

TomPreparedStatement<T>
    └── MariadbPreparedStatement<T>

TomTransactionParticipant  (transactions)
    └── TomDataSource
            └── MariaDbDatasource
                    └── MariaDbXADatasource

TomDataSourceInfo
SqlPlaceholderScan
TomFrameworkTable
TomFrameworkColumn
TomFrameworkKey

TomServerException  (little_things)
    ├── MariadbDatasourceException
    ├── MariadbPreparedStatementException
    └── TomDatasourceInitException
```

## Classes

### SQL-Typed Values

#### TomDbType&lt;T&gt;

A boxed, SQL-typed value: the bridge between a Dart value and the column type it
maps to in a data source. Each concrete subtype wraps a nullable Dart value and
provides a static `of(String?)` factory.

- **Extends:** `TomObject<T>`
- **Type Parameters:** `T` — the boxed Dart value type.

##### Constructors

```dart
TomDbType(T value)
```

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Renders `"TomDbType <runtimeType> <value>"`. |

#### TomDbInt

A SQL-typed box for a nullable `int`.

- **Extends:** `TomDbType<int?>`

##### Constructors

```dart
TomDbInt(int? value)
```

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `of` | `static TomDbInt of(String? s)` | Parses `s` as an `int` (or `null` when `s` is `null`). |

#### TomDbDouble

A SQL-typed box for a nullable `double`.

- **Extends:** `TomDbType<double?>`

##### Constructors

```dart
TomDbDouble(double? value)
```

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `of` | `static TomDbDouble of(String? s)` | Parses `s` as a `double` (or `null` when `s` is `null`). |

#### TomDbString

A SQL-typed box for a nullable `String`.

- **Extends:** `TomDbType<String?>`

##### Constructors

```dart
TomDbString(String? value)
```

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `of` | `static TomDbString of(String? s)` | Wraps `s` verbatim (a `null` string yields a box holding `null`). |

#### TomDbDateTime

A SQL-typed box for a nullable `DateTime` (a timestamp).

- **Extends:** `TomDbType<DateTime?>`

##### Constructors

```dart
TomDbDateTime(DateTime? value)
```

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `of` | `static TomDbDateTime of(String? s)` | Reads a stored instant back as **UTC**, via `parseOptionalSqlInstant`. A `null` *or empty* column yields a box holding `null`. |

#### TomDbDate

A SQL-typed box for a nullable `TomZonedDate` (a calendar date).

- **Extends:** `TomDbType<TomZonedDate?>`

##### Constructors

```dart
TomDbDate(TomZonedDate? value)
```

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `of` | `static TomDbDate of(String? s)` | Parses `s` via `TomZonedDate.parseFromString` (or `null` when `s` is `null`). |

#### TomDbTime

A SQL-typed box for a nullable `TomZonedTime` (a time of day).

- **Extends:** `TomDbType<TomZonedTime?>`

##### Constructors

```dart
TomDbTime(TomZonedTime? value)
```

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `of` | `static TomDbTime of(String? s)` | Parses `s` via `TomZonedTime.parseFromString` (or `null` when `s` is `null`). |

#### TomDbBool

A SQL-typed box for a nullable `bool`.

- **Extends:** `TomDbType<bool?>`

##### Constructors

```dart
TomDbBool(bool? value)
```

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `of` | `static TomDbBool of(String? s)` | Parses `s` via `bool.parse` (or `null` when `s` is `null`). |

### The Operator Tree

#### TomOperator&lt;R&gt;

A node in a SQL expression tree, parameterised by its SQL return type `R`. An
operator knows how to `generate` its SQL fragment against a
`TomStandardSqlDialect`, which fields it references, and which positional
parameters it contributes.

It is also a *tree*, and `children` is the single edge along which that tree is
walked: `getParameters` and `getFields` are defined in terms of it, and so is
every caller that must descend a predicate — the grouped query checks a `HAVING`
clause by walking `children` while treating an aggregate as opaque, because an
aggregate collapses the rows its operand references and so imposes no grouping
obligation on it. The two members are complementary, not alternatives:
`children` is what a node *has* (an instance getter, read by the walkers);
`operandChildren` is how an implementation *builds* it (a static rule applied to
one constructor operand). A container operator's `children` override is
typically nothing more than its operands mapped through `operandChildren`.

- **Type Parameters:** `R` — the SQL return type of the node.

##### Constructors

```dart
TomOperator()
```

##### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `defaultDialect` | `TomStandardSqlDialect` | The dialect used when an operator is rendered without an explicit one. Mutable — assigning it changes the default for every operator rendered afterwards. |

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `operandChildren` | `static List<TomOperator> operandChildren(Object? operand)` | Flattens one constructor operand into the `children` contribution it represents: a nested operator yields itself, a `List<TomOperator>` yields its elements, and a leaf value (a `String` column name, a Dart literal) yields nothing. Used by a container operator to build its own `children`; it does not read the tree. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `returnType` | `Type` | The runtime SQL return type `R`, captured at construction (`late`, assigned by the constructor). |
| `children` | `List<TomOperator>` | *(getter)* The direct sub-expressions of this node, left to right — the one traversal every structural walk goes through. A leaf (a literal, a parameter, a column reference) has none, so the base implementation returns `const []`; a container overrides to yield its operands, flattening an operand that is itself a list (as `AND`/`OR`/`IN` carry). |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `generate` | `SqlString generate(TomStandardSqlDialect t)` | *(abstract)* Renders this operator's SQL fragment using dialect `t`. |
| `getParameters` | `List<String> getParameters(TomStandardSqlDialect t)` | The positional parameter placeholders this operator contributes, in left-to-right order. Leaf literals override this; container operators concatenate their `children`'s parameters. Empty by default. |
| `getFields` | `Set<String> getFields(TomStandardSqlDialect t)` | *(abstract)* The set of column/field names this operator references. |
| `toString` | `String toString()` | *(override)* Human-readable tree (delegates to `analyze(0)`). |
| `indent` | `String indent(int i)` | Newline followed by `i` tab characters (used by `analyze`). |
| `analyze` | `String analyze(int l)` | Indented description of this operator at tree depth `l` (debugging). Container operators override to recurse. |

### The SQL Dialect

#### TomStandardSqlDialect

Generates standard-SQL fragments for the `TomOperator` expression tree. Every
method renders one piece of SQL — a predicate, a literal, a positional parameter
placeholder, or a qualified field reference. Drivers subclass to override any
fragment.

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isNull` | `SqlString isNull<T>(TomOperator<T> what)` | Renders `<what> IS NULL`. |
| `isNotNull` | `SqlString isNotNull<T>(TomOperator<T> what)` | Renders `<what> IS NOT NULL`. |
| `isin` | `SqlString isin<T>(TomOperator<T> what, List<TomOperator<T>> choices)` | Renders `<what> IN (<choices...>)` comma-separated. |
| `between` | `SqlString between<T>(TomOperator<T> what, List<TomOperator<T>> betweenLimits)` | Renders `<what> BETWEEN <lo> AND <hi>`. |
| `like` | `SqlString like(TomOperator<TomDbString> text, TomOperator<TomDbString> test)` | Renders `<text> LIKE <test>`. |
| `notLike` | `SqlString notLike(TomOperator<TomDbString> text, TomOperator<TomDbString> test)` | Renders `<text> NOT LIKE <test>`. |
| `regexp` | `SqlString regexp(TomOperator<TomDbString> text, TomOperator<TomDbString> test)` | Renders `<text> REGEXP <test>`. |
| `group` | `SqlString group<T>(TomOperator<T> operant)` | Wraps `operant` in parentheses. |
| `eq` | `SqlString eq<T>(TomOperator<T> operant1, TomOperator<T> operant2)` | Renders `<operant1> = <operant2>`. |
| `neq` | `SqlString neq<T>(TomOperator<T> operant1, TomOperator<T> operant2)` | Renders `<operant1> <> <operant2>`. |
| `lt` | `SqlString lt<T>(TomOperator<T> operant1, TomOperator<T> operant2)` | Renders `<operant1> < <operant2>`. |
| `lte` | `SqlString lte<T>(TomOperator<T> operant1, TomOperator<T> operant2)` | Renders `<operant1> <= <operant2>`. |
| `gt` | `SqlString gt<T>(TomOperator<T> operant1, TomOperator<T> operant2)` | Renders `<operant1> > <operant2>`. |
| `gte` | `SqlString gte<T>(TomOperator<T> operant1, TomOperator<T> operant2)` | Renders `<operant1> >= <operant2>`. |
| `not` | `SqlString not(TomOperator<TomDbBool> operant1)` | Renders `NOT <operant1>`. |
| `and` | `SqlString and(List<TomOperator<TomDbBool>> operant1)` | Joins the predicates with ` AND `. |
| `or` | `SqlString or(List<TomOperator<TomDbBool>> operant1)` | Joins the predicates with ` OR `. |
| `text` | `SqlString text(String text)` | Renders a single-quoted string literal, escaping `\` and `'`. |
| `intOp` | `SqlString intOp(int value)` | Renders an integer literal. |
| `doubleOp` | `SqlString doubleOp(double value)` | Renders a double literal. |
| `boolOp` | `SqlString boolOp(bool value)` | Renders a boolean literal. |
| `dateTimeOp` | `SqlString dateTimeOp(DateTime value)` | Renders a timestamp literal as the single-quoted UTC `DATETIME(6)` text `sqlInstant` defines — not ISO-8601, whose `T` and `Z` a `DATETIME` column rejects. |
| `dateOp` | `SqlString dateOp(DateTime value)` | Renders a date literal as single-quoted, zero-padded `YYYY-MM-DD`. Unlike `dateTimeOp`, the components are taken as labelled — no UTC conversion. Quotes `sqlDate` rather than restating the format, so an inlined literal and a bound value cannot spell the same day differently. |
| `timeOp` | `SqlString timeOp(DateTime value)` | Renders a time-of-day literal as single-quoted, fixed-width `HH:MM:SS`, discarding the date half of `value` — a `TIME` column stores a position within a day, and MariaDB reads a datetime-shaped string for one as a truncation error rather than as the time it contains. Like `dateOp`, the components are taken as labelled; sub-second precision is dropped. Quotes `sqlTimeOfDay`. |
| `iterableOp` | `SqlString iterableOp(Iterable values)` | Renders `values` as a comma-separated list of literals. |
| `nullOp` | `SqlString nullOp()` | Renders the SQL `NULL` literal. |
| `objectOp` | `SqlString objectOp(Object? o)` | Renders `o` as the appropriate SQL literal, dispatching on runtime type. |
| `p` | `SqlString p<T>(String parameterName)` | Renders a positional parameter placeholder `:<parameterName>`. |
| `textF` | `SqlString textF(String fieldName, DbCol column, Type dbType)` | Renders a qualified reference to a `String` column as `table.column`. |
| `intF` | `SqlString intF(String fieldName, DbCol column, Type dbType)` | Renders a qualified reference to an `int` column as `table.column`. |
| `doubleF` | `SqlString doubleF(String fieldName, DbCol column, Type dbType)` | Renders a qualified reference to a `double` column as `table.column`. |
| `boolF` | `SqlString boolF(String fieldName, DbCol column, Type dbType)` | Renders a qualified reference to a `bool` column as `table.column`. |
| `dateTimeF` | `SqlString dateTimeF(String fieldName, DbCol column, Type dbType)` | Renders a qualified reference to a timestamp column as `table.column`. |
| `dateF` | `SqlString dateF(String fieldName, DbCol column, Type dbType)` | Renders a qualified reference to a date column as `table.column`. |
| `timeF` | `SqlString timeF(String fieldName, DbCol column, Type dbType)` | Renders a qualified reference to a time-of-day column as `table.column`. |

##### Methods — type classification

The dialect's other job. Everything above renders SQL *out*; these three read a
column type name *in*, reducing DDL text such as `VARCHAR(255)` or `BIGINT
UNSIGNED` to a `TomSqlTypeFamily` so that a declared Dart type and a stored SQL
type can be compared at all. The schema-convergence checks run both sides
through `typeFamily`; `baseTypeName` and `typeArguments` are exposed so an
overriding dialect need not re-tokenise the type itself.

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `typeFamily` | `TomSqlTypeFamily typeFamily(String sqlType)` | Classifies a DDL column type into the family it stores. The base word decides; parenthesised arguments and trailing attributes are ignored. An unrecognised type yields `TomSqlTypeFamily.unknown` rather than a guess. **The hook a driver overrides** — call `super.typeFamily` for the standard names. |
| `baseTypeName` | `String baseTypeName(String sqlType)` | The upper-cased leading word of a DDL type — `VARCHAR(255)` → `VARCHAR`, `DOUBLE PRECISION` → `DOUBLE`, `` `int` `` → `INT` (backticks stripped). |
| `typeArguments` | `List<String> typeArguments(String sqlType)` | The trimmed, comma-separated arguments of the type's parenthesis, or an empty list — `VARCHAR(255)` → `['255']`, `DECIMAL(10, 2)` → `['10', '2']`. |

`typeFamily` yields `unknown` instead of guessing because the convergence check
reads that as "no opinion" and stays silent, where a guess would report a
divergence it cannot justify. Widths, precisions, signedness and defaults are
deliberately not represented: the Dart side never states them, so there is
nothing to compare them against.

##### Methods — aggregates

The whole SQL surface a grouped query renders through. A database that spells
any of it differently overrides one method here rather than forking the query
builder.

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `aggregate` | `SqlString aggregate(TomAggregateFunction function, SqlString? operand, {bool distinct = false})` | Renders `COUNT(*)` when `operand` is `null`, else `SUM(t.c)` / `COUNT(DISTINCT t.c)`. `distinct` is meaningless for `COUNT(*)` and is ignored there. |
| `aliased` | `SqlString aliased(SqlString expression, String alias)` | Renders `<expression> AS <alias>` — the projection form that names a result column so the row mapper can find it. |
| `groupByClause` | `SqlString groupByClause(List<SqlString> columnExprs)` | Renders ` GROUP BY a, b`, or `""` for an empty list (an aggregate over the whole result set groups by nothing). |
| `havingClause` | `SqlString havingClause(SqlString? predicate)` | Renders ` HAVING <predicate>`, or `""` when there is none. |

`groupByClause` and `havingClause` are separate methods, and the `WHERE` and
`HAVING` predicates stay separate all the way down to them, because the two
filter different things: `WHERE` removes rows before aggregation, `HAVING`
removes groups after it. ANDing them upstream would change the meaning of both.

#### MariadbSqlDialect

The SQL dialect for MariaDB. Inherits standard SQL *generation* unchanged from
`TomStandardSqlDialect`. Nothing looks it up: a query reaches it because
`MariaDbDatasource.sqlDialect` returns it, and reflection resolves the *driver*
by type name, not the dialect. Its one override is `typeFamily`, which
classifies `TINYINT(1)` as `TomSqlTypeFamily.boolean` — MariaDB has no
distinct boolean storage, so calling
it an integer would report every boolean column of every migration as a type
divergence.

- **Extends:** `TomStandardSqlDialect`

##### Constructors

```dart
MariadbSqlDialect()
```

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `typeFamily` | `TomSqlTypeFamily typeFamily(String sqlType)` | *(override)* Classifies `TINYINT(1)` as `boolean`, delegating everything else to `super`. Only the exact `(1)` display width is boolean — a plain `TINYINT` or a `TINYINT(4)` really is a small integer. |

This is the shape a driver's own dialect should copy: recognise the cases the
database spells differently, then `return super.typeFamily(sqlType)`. Restating
the standard names in the override would mean a name added to the base list
never reaches the subclass.

### Persistence Metadata

#### TomTypePersistenceInfo

The persistence metadata for one entity type: its class mirror, the `TomDbTable`
it maps to, and the per-field `TomColumnInformation`.

##### Constructors

```dart
TomTypePersistenceInfo(
  ClassMirror classMirror,
  TomDbTable table,
  List<TomColumnInformation> columnInfo,
)
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `classMirror` | `ClassMirror` | Reflection mirror of the entity class. |
| `table` | `TomDbTable` | The table the entity maps to. |
| `columnInfo` | `List<TomColumnInformation>` | Per-field column metadata for the entity. |

#### TomTypedPersistenceBase

Base for anything scoped to a set of persistent entity `types`: analyses each
type's annotations once at construction and exposes the resulting metadata.

##### Constructors

```dart
TomTypedPersistenceBase(List<Type> types)
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `types` | `List<Type>` | The entity types this object operates over. |
| `persistenceInfo` | `List<TomTypePersistenceInfo>` | The analysed persistence metadata, one entry per type. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getColumnInformation` | `List<TomColumnInformation> getColumnInformation()` | All columns across all `types`, flattened in type order. |
| `determineColumn` | `TomColumnInformation determineColumn(String name)` | Resolves the column metadata for field `name` across all `types`. |

### Query Objects

#### TomQuery

A query over a set of entity `types` that renders to SQL via `generateQuery`,
contributing positional parameters and referenced fields for the active dialect.

- **Extends:** `TomTypedPersistenceBase`

##### Constructors

```dart
TomQuery(List<Type> types)
```

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `generateQuery` | `String generateQuery(TomStandardSqlDialect t)` | Renders the full SQL statement for dialect `t`. |
| `getParameters` | `List<String> getParameters(TomStandardSqlDialect t)` | The positional parameters the statement binds (empty by default). |
| `getFields` | `Set<String> getFields(TomStandardSqlDialect t)` | The column/field names the statement references (empty by default). An empty set may also mean the statement cannot analyse itself — see `TomLiteralSelect.getFields`. |

#### TomGeneratedQuery

A `TomQuery` whose WHERE clause is built from a `TomOperator<TomDbBool>`
predicate, with shared shaping options. Concrete subclasses render the
appropriate statement around that predicate.

- **Extends:** `TomQuery`

##### Constructors

```dart
TomGeneratedQuery(
  List<Type> types, {
  required TomOperator<TomDbBool> query,
  bool distinct = false,
  List<String> orderBy = const [],
  bool ascending = true,
  List<TomSortField>? sort,
  int top = 0,
  int offset = 0,
  List<String> ignoreFields = const [],
})
```

`orderBy` + `ascending` are a shorthand that maps onto `sort`: they are accepted
so existing call sites keep working, and are not stored. Passing `sort`
supersedes them. The constructor rejects a window SQL cannot express — a negative
bound, or an `offset` without a `top`.

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `distinctPrefix` | `static String distinctPrefix(bool distinct)` | Renders the `DISTINCT ` projection prefix (empty when not `distinct`). |
| `limitClause` | `static String limitClause(int top, [int offset = 0])` | Renders the trailing ` LIMIT n` / ` LIMIT n OFFSET m` row-window clause (empty when `top <= 0`). |
| `orderByClause` | `static String orderByClause(List<TomSortField> sort)` | Renders the trailing ` ORDER BY <col> ASC\|DESC, …` clause, one direction per term. Emits each term verbatim, so callers pass *resolved* names. |
| `resolveSortColumns` | `static List<TomSortField> resolveSortColumns(List<TomSortField> sort, List<TomTypePersistenceInfo> persistenceInfo, {bool qualified = true})` | Substitutes each term's column for the name it was written with, keeping the direction. The step `orderByClause` requires. |
| `countProjection` | `static String countProjection(bool distinct, List<String> columnExprs)` | Renders the `COUNT(*)` / `COUNT(DISTINCT <cols>)` projection. |

A sort term may be written as either the column name or the declared Dart field
name, but only the column name is valid SQL, so `resolveSortColumns` is what
every `ORDER BY`-rendering form runs first. It doubles as the guard on the
statement text: sort names arrive from outside and cannot be bound as
parameters, so an unknown name throws here rather than being interpolated.
`qualified` selects the rendering only — `table.column` for a select that may
span tables, bare `column` for MariaDB's single-table `DELETE`.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `query` | `TomOperator<TomDbBool>` | The boolean predicate forming the WHERE clause. |
| `ignoreFields` | `List<String>` | Field names to omit from the generated column list. |
| `distinct` | `bool` | Whether to request distinct rows. |
| `sort` | `List<TomSortField>` | The ordering, outermost term first (empty = unsorted). |
| `top` | `int` | Row cap (`<= 0` = unbounded). |
| `offset` | `int` | Rows skipped before the first returned row; needs a `top`. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `generateQuery` | `String generateQuery(TomStandardSqlDialect t)` | *(override)* Renders the predicate's SQL. |
| `getParameters` | `List<String> getParameters(TomStandardSqlDialect t)` | *(override)* The predicate's positional parameters. |
| `getFields` | `Set<String> getFields(TomStandardSqlDialect t)` | *(override)* The predicate's referenced fields. |
| `toString` | `String toString()` | *(override)* Debug description of the query and its options. |

#### TomSelect

A `SELECT` over the entity `types`: emits the non-reference columns of all
involved tables, the WHERE clause, and optional `DISTINCT`, `ORDER BY`, and
`LIMIT` clauses.

- **Extends:** `TomGeneratedQuery`

##### Constructors

```dart
TomSelect(
  List<Type> types, {
  required TomOperator<TomDbBool> query,
  bool distinct,
  List<String> orderBy,
  bool ascending,
  List<TomSortField>? sort,
  int top,
  int offset,
  List<String> ignoreFields,
})
```

Each sort term's field is resolved to a qualified `table.column` expression
before rendering, so an unknown field name fails at resolution rather than
reaching the statement text.

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `generateQuery` | `String generateQuery(TomStandardSqlDialect t)` | *(override)* Renders the full `SELECT` statement. |
| `toString` | `String toString()` | *(override)* Debug description prefixed `TomSelect:`. |

#### TomLiteralSelect

A query whose SQL is a raw, hand-written `query` string with explicit positional
`parameters` — an escape hatch for statements the generated queries cannot
express. The `types` still drive result mapping.

- **Extends:** `TomQuery`

##### Constructors

```dart
TomLiteralSelect(
  List<Type> types, {
  required String query,
  List<String> parameters = const [],
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `query` | `String` | The verbatim SQL statement. |
| `parameters` | `List<String>` | The positional parameter names bound by the statement. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `generateQuery` | `String generateQuery(TomStandardSqlDialect t)` | *(override)* Returns the raw `query` string. |
| `getParameters` | `List<String> getParameters(TomStandardSqlDialect t)` | *(override)* Returns the declared `parameters`. |
| `getFields` | `Set<String> getFields(TomStandardSqlDialect t)` | *(override)* Always empty — a hand-written statement's field references cannot be derived. Means *unknown*, not *none*. |
| `toString` | `String toString()` | *(override)* Debug description prefixed `TomLiteralSelect:`. |

#### TomCount

A `SELECT COUNT(*)` (or `COUNT(DISTINCT <cols>)`) over the entity `types`,
filtered by the predicate. Returns a single `count` column.

- **Extends:** `TomGeneratedQuery`

##### Constructors

```dart
TomCount(
  List<Type> types, {
  required TomOperator<TomDbBool> query,
  bool distinct,
  List<String> ignoreFields,
})
```

No window and no ordering — no `top`, `offset`, `sort` or `orderBy`/`ascending`.
The statement returns exactly one row, so `LIMIT` would cap what is *returned*
rather than what is counted, and an `ORDER BY` would have a single row to order;
the total of a filtered set likewise does not depend on which page of it the
caller is reading. The parameters are absent rather than accepted and ignored,
so a call that asks for a window fails where it is written.

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `generateQuery` | `String generateQuery(TomStandardSqlDialect t)` | *(override)* Renders the `SELECT COUNT(...) AS count` statement. |
| `toString` | `String toString()` | *(override)* Debug description prefixed `TomCount:`. |

#### TomDelete

A `DELETE` from the first of the entity `types`, filtered by the predicate.

- **Extends:** `TomGeneratedQuery`

##### Constructors

```dart
TomDelete(
  List<Type> types, {
  required TomOperator<TomDbBool> query,
  bool distinct,
  List<String> orderBy,
  bool ascending,
  List<TomSortField>? sort,
  int top,
  List<String> ignoreFields,
})
```

No `offset`: `DELETE … LIMIT n OFFSET m` is not MariaDB syntax. Sort terms are
rendered unqualified, because a single-table `DELETE` has no table alias to
qualify them with.

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `generateQuery` | `String generateQuery(TomStandardSqlDialect t)` | *(override)* Renders the single-table `DELETE` statement. |
| `toString` | `String toString()` | *(override)* Debug description prefixed `TomDelete:`. |

### Data Sources and Drivers

#### TomDataSource

A connection to one data source — the abstract contract a driver implements. It
exposes its `sqlDialect`, lifecycle, and execution surface, and is a
`TomTransactionParticipant`.

- **Implements:** `TomTransactionParticipant`

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `createDatasourceOf` | `static TomDataSource? createDatasourceOf(String type)` | Returns a fresh data source for `type`, discovering drivers on first call; throws `TomDatasourceInitException` when none is registered or instantiation fails. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `sqlDialect` | `TomStandardSqlDialect` | The SQL dialect this data source generates against. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `initialize` | `Future<void> initialize(Map<String, dynamic> settings)` | Opens the connection and applies `settings`. |
| `close` | `Future<void> close()` | Closes the connection and frees its resources. |
| `isOperational` | `bool isOperational()` | Whether the connection is currently usable (default `true`). |
| `prepareStatement` | `Future<TomPreparedStatement<T>> prepareStatement<T extends Object>(TomQuery query, [Type? resultType])` | Compiles `query` into a reusable prepared statement. |
| `executeCommand` | `Future<BigInt> executeCommand(String command, [Map<String, dynamic>? params])` | Executes a write command and returns the affected-row count. |
| `executeQuery` | `Future<List<T>> executeQuery<T extends Object>(String command, [Map<String, dynamic>? params, Type? resultType])` | Executes a read command, mapping rows to `resultType`. |

#### TomPreparedStatement&lt;T&gt;

A reusable, server-side compiled statement that can be executed any number of
times and then deallocated.

- **Type Parameters:** `T extends Object` — the mapped result row type.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `lastGeneratedId` | `int?` | The auto-increment / identity key from the most recent `execute` that inserted a row, or `null` (default `null`). |
| `lastAffectedRows` | `int` | The number of rows the most recent `execute` changed — the count a `DELETE` or `UPDATE` reports, `0` for a statement that changed nothing or has not run. Abstract and non-nullable, unlike `lastGeneratedId`: a driver that ran a write knows how many rows it touched, and a default would let silence read as a real count. Per-execution state, so read it before `deallocate`. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `execute` | `Future<List<T>> execute([Map<String, Object?>? params])` | Runs the statement and returns the mapped result rows. |
| `deallocate` | `Future<void> deallocate()` | Releases the statement's server-side resources. |

#### TomDatasourceDriver

Annotation marking a `TomDataSource` implementation as the driver for a named
data-source `type`. Drivers are discovered by scanning `tomReflector`.

##### Constructors

```dart
const TomDatasourceDriver(String type)
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `type` | `String` | The data-source type this driver serves. |

#### TomDataSourceInfo

The process-wide registry of named, configured data sources. Each named entry
pairs a `name` with its `settings` and, once initialised, the live `datasource`.

##### Constructors

```dart
TomDataSourceInfo(String name, Map<String, dynamic> settings)
```

##### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasources` | `Map<String, TomDataSourceInfo>` | All registered data sources, keyed by name. |
| `registryKeys` | `Set<String>` | The settings keys the registry reads itself and does not pass on — `type`, which selects the driver, and `delegateTo`, which makes the entry an alias. Neither is a field of any driver. They are removed from the block before it reaches `TomDataSource.initialize` rather than being excused by an allowlist inside the unknown-key check, so that a driver is handed only what is addressed to it and every key it is handed has to bind. |

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getDataSourceInfo` | `static TomDataSourceInfo? getDataSourceInfo(String dsName)` | Returns the registered info for `dsName`, or `null` if none. |
| `initializeDatasourceInfo` | `static Future<int> initializeDatasourceInfo(Map<String, dynamic> datasourceConfiguration)` | Builds and initialises a registry entry for every map-valued config entry. Returns `1` on success. |
| `closeAll` | `static Future<void> closeAll()` | Closes every initialised data source in the registry. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The registry key / logical name of this data source. |
| `type` | `String` | The driver type, resolved from `settings` during `initialize`. |
| `settings` | `Map<String, dynamic>` | The raw configuration for this data source. |
| `isOperational` | `bool` | Whether the underlying data source exists and reports operational. |
| `datasource` | `TomDataSource` | The live data source, or throws if it has not been initialised. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `initialize` | `Future<void> initialize()` | Registers this entry and opens its data source (honouring a `delegateTo` alias). Strips `registryKeys` from `settings`, then requires every remaining key to name a field the configured driver declares — one that does not throws `TomDatasourceInitException` (`tom_datasource_info.initialize.unknown_setting`) naming every offending key and the data source. Both halves of the message are load-bearing: the key is what to fix, and the name is which block to open. The check lives here rather than in each driver because a driver never learns the name it was configured under, and because a check here covers a driver the framework never saw — the field set is read off *that* driver by reflection, so a deployment's own driver is checked against its own settings. |
| `toString` | `String toString()` | *(override)* Debug description of the entry. |

### The MariaDB Driver

#### MariaDbDatasource

A MariaDB / MySQL `TomDataSource` driver (registered for the `"mariadb"` type).
Connection settings are filled from the configuration map by reflection in
`initialize`, which then opens the connection.

**A data source is opened explicitly — by `initialize(settings)`, or by setting
the connection fields and calling `connect()` — and never by the statement that
wants to run.** All three execution entry points (`prepareStatement`,
`executeQuery`, `executeCommand`) require an open connection and throw
`MariadbDatasourceException` (`error.datasource.not_opened`, naming the entry
point in the exception's `operation` parameter and the state that refused it in
`state`) when reached without one. Opening on demand is not offered because it
could not work: `connect()` binds `host`, `port` and the credentials, so before
they are configured it would dial `:-1`, reporting an unreachable database where
the truth is an unconfigured one.

`close()` releases the link **and lets go of it**, so a closed data source is
not-open and refuses statements (`state: "closed"`) exactly as one that was
never opened does (`state: "never_opened"`) — re-opening it by itself would
resurrect a data source the application deliberately let go. A link that *was*
opened and has since dropped is the one case that is repaired: it is re-opened
automatically, on every entry point and on the prepared-statement retry alike.

- **Implements:** `TomDataSource`

##### Constructors

```dart
MariaDbDatasource()
```

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toPositionalStatement` | `static (String, List<String>) toPositionalStatement(String namedSql)` | Translates generated `:name` SQL into the positional `?` form, returning the rewritten SQL and placeholder names in order. |
| `normalizePort` | `static Map<String, dynamic> normalizePort(Map<String, dynamic> settings)` | Returns `settings` with its `port` value normalized to an `int`. |
| `parsePort` | `static int parsePort(Object? raw)` | Parses a configured port value into the `int` the driver binds; throws `MariadbDatasourceException` when unparsable. |
| `mapGroupedRow` | `static TomGroupedRow mapGroupedRow(ResultSetRow row, Map<String, Type> projection)` | Maps one row of a grouped result, reading each alias as the Dart type the query declared for it. Throws `MariadbDatasourceException` (`error.result_processing_grouped.unknown_type`) for a declared type outside `int` / `double` / `String` / `bool` / `DateTime`. |

A grouped query has no entity class and no column metadata — its shape is
decided by the query — so `prepareStatement` copies the query's
`projectionTypes` onto the statement and `mapGroupedRow` runs before any mirror
is taken.

Numeric columns are read as raw text and parsed, not via the driver's typed
accessor: MariaDB types `SUM`/`AVG` over an integer column as `NEWDECIMAL`
(protocol type 246) — as it does every `DECIMAL` column — and `mysql_client`
converts to `double` (or to `int`) only from a whitelist of column types that
omits it, so asking for a number there throws `MySQLProtocolException` rather
than widening. The text form parses losslessly. This is not specific to grouped
rows: `mapGroupedRow` and all four entity-mapping variants share the same two
read helpers, so an entity with a `DECIMAL` money column reads on every path. An
`int`-declared field over a `DECIMAL` column is read when the value is exactly
integral and refused by name (`error.result_processing.fractional_int`) when it
is not — never silently truncated.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `sqlDialect` | `TomStandardSqlDialect` | *(override)* The MariaDB SQL dialect. |
| `username` | `String` | The connection user name. |
| `password` | `String` | The connection password. |
| `host` | `String` | The database host. |
| `port` | `int` | The database port (`-1` until configured). |
| `databaseName` | `String` | The schema / database name (empty selects no default schema). |
| `timeOut` | `int` | The connect timeout in milliseconds. |
| `connection` | `MySQLConnection?` | The live MySQL connection (`null` until `connect` succeeds, and again once `close` has let go of it). |
| `connected` | `bool` | Whether the underlying connection is currently established. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `connect` | `Future<void> connect()` | Opens a connection using the configured settings; throws `MariadbDatasourceException` on failure. |
| `prepareStatement` | `Future<TomPreparedStatement<T>> prepareStatement<T extends Object>(TomQuery query, [Type? resultType])` | *(override)* Prepares a positional statement for `query`. |
| `executeQuery` | `Future<List<T>> executeQuery<T extends Object>(String command, [Map<String, dynamic>? params, Type? resultType])` | *(override)* Runs a read command with reflection-based row→object mapping. A `TomClass` result type maps by observable member — by member name without `@TomDbTable`, by `@TomDbColumn` with it — supporting `int` / `double` / `String` / `bool` / `DateTime` members whether declared as the plain or the nullable (`TomN…`) observable, with a SQL `NULL` read as `null`. |
| `initialize` | `Future<void> initialize(Map<String, dynamic> settings)` | *(override)* Binds `settings` by reflection and connects. |
| `isOperational` | `bool isOperational()` | *(override)* Whether the connection exists and is connected. |
| `executeCommand` | `Future<BigInt> executeCommand(String command, [Map<String, dynamic>? params])` | *(override)* Runs a write command and returns the affected-row count. |
| `close` | `Future<void> close()` | *(override)* Closes the connection if it was still live, and clears `connection` either way — including when closing it throws, since the caller is done with the link regardless. A data source that was never opened has nothing to release and stays "never opened". |
| `toString` | `String toString()` | *(override)* Debug description of the datasource: the link's own state (`connected: true` / `false`) while it holds one, and otherwise which of the two ways it came to hold none — `closed` or `never opened`. |
| `getParticipantId` | `String getParticipantId()` | *(override)* The transaction-participant id. |
| `startTransaction` | `Future<bool> startTransaction()` | *(override)* Issues `START TRANSACTION`. Returns `false` when the database refuses it, but **throws** `MariadbDatasourceException` (`error.transaction.already_active`, naming the `participant`) when this data source is already in a transaction — a caller mistake no retry fixes, and so not the same answer as a failed statement. |
| `endTransaction` | `Future<bool> endTransaction()` | *(override)* A no-op that always succeeds: a one-phase transaction has no prepare step to issue and no state left to release, since `commit` / `rollback` clear the in-transaction flag and the coordinator calls one of them first. |
| `commit` | `Future<bool> commit()` | *(override)* Issues `COMMIT`. |
| `rollback` | `Future<void> rollback()` | *(override)* Issues `ROLLBACK`. |

#### MariaDbXADatasource

A MariaDB `TomDataSource` that uses XA (distributed) transactions (registered
for the `"mariadb_xa"` type). Inherits connection and execution behaviour from
`MariaDbDatasource` but overrides the transaction lifecycle to issue `XA`
commands.

- **Extends:** `MariaDbDatasource`

##### Constructors

```dart
MariaDbXADatasource()
```

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `startTransaction` | `Future<bool> startTransaction()` | *(override)* Issues `XA START` against a fresh branch id, throwing the same `error.transaction.already_active` as the base class — with the open branch in the `transactionId` parameter — if one is already open. Clears the id again when the command fails, since the database never opened that branch. |
| `endTransaction` | `Future<bool> endTransaction()` | *(override)* Issues `XA END` + `XA PREPARE`. The one exit that **keeps** the branch id on success — `commit` still needs it — and clears it on failure, where the branch can no longer be committed. |
| `commit` | `Future<bool> commit()` | *(override)* Issues `XA COMMIT` and clears the branch id either way. |
| `rollback` | `Future<void> rollback()` | *(override)* Issues `XA ROLLBACK` and clears the branch id either way. |

Every exit puts the branch id back except a successful `endTransaction`, which
hands it on to `commit`. The rule is what keeps the data source usable: the id
is also the guard `startTransaction` refuses a second transaction on, so an exit
that forgets to clear locks out every later transaction permanently — and a
caller cannot recover by rolling back, because the branch it would name never
began.

#### MariadbPreparedStatement&lt;T&gt;

A MariaDB-backed `TomPreparedStatement`: wraps a server-side `PreparedStmt`, the
ordered `parameterList` its placeholders expect, the owning `datasource`, and
the optional `resultType`.

- **Extends:** `TomPreparedStatement<T>`
- **Type Parameters:** `T extends Object` — the mapped result row type.

##### Constructors

```dart
MariadbPreparedStatement(
  PreparedStmt preparedStmt,
  List<String> parameterList,
  MariaDbDatasource datasource,
  Type? resultType,
  String command, {
  Map<String, Type>? groupedProjection,
})
```

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `normalizeGeneratedId` | `static int? normalizeGeneratedId(BigInt rawLastInsertId)` | Maps a driver-reported last-insert id into a generated key (`0` → `null`). |
| `buildPositionalParameters` | `static List<Object?> buildPositionalParameters(List<String> parameterList, Map<String, Object?>? params)` | Maps named `params` onto the positional bind list in placeholder order. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `MariaDbDatasource` | The data source that prepared and runs this statement. |
| `preparedStmt` | `PreparedStmt` | The live server-side prepared statement handle (replaced on reconnect). |
| `parameterList` | `List<String>` | The placeholder names in positional order. |
| `resultType` | `Type?` | The type result rows are mapped to (defaults to `T`). |
| `command` | `String` | The compiled SQL command (kept so the statement can be re-prepared). |
| `groupedProjection` | `Map<String, Type>?` | For a grouped query, the Dart type of each projected result column keyed by its alias; `null` for every other statement. The types travel with the statement because a grouped row is not an entity. |
| `lastGeneratedId` | `int?` | *(override)* The auto-increment key the most recent `execute` generated. |
| `lastAffectedRows` | `int` | *(override)* The row count the most recent `execute` reported, taken from that execute's own result set (`IResultSet.affectedRows`). `0` until the statement has run. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `execute` | `Future<List<T>> execute([Map<String, Object?>? params])` | *(override)* Runs the statement (one reconnect-and-retry on a closed connection). |
| `deallocate` | `Future<void> deallocate()` | *(override)* Deallocates the server-side statement. |

### Placeholder Scanning

#### SqlPlaceholderScan

Quote-aware scan of `:name` parameter placeholders in generated SQL. Walks the
SQL character by character, copying quoted spans verbatim, and only recognises a
`:name` placeholder in ordinary (outside-quotes) text. This is the single shared
implementation both the MariaDB datasource and the CRUD repository use.

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toPositional` | `static (String, List<String>) toPositional(String namedSql)` | Rewrites every outside-of-literal `:name` placeholder to `?`, returning the rewritten SQL and placeholder names in order (repeats included). |
| `extractNames` | `static List<String> extractNames(String namedSql)` | The placeholder names in textual order (repeats included), skipping any inside a string literal. |

### Framework-Owned Tables

The framework's own tables — the job queue, the lease table, the scheduler roll
call, the blob manifest/chunk pair, the audit trail — are not entities, so the
entity-to-migration convergence check does not reach them. A
`TomFrameworkTable` is the one declaration they get instead, and everything
else is derived from it: the create-if-missing DDL, the column lists the
hand-written statements interpolate, the `INSERT`/`REPLACE` shape, and the
`TomSchemaModel` the convergence guard compares. Declared here rather than in
`db_migration/` because the stores that own these tables already depend on
`datasources/` and must not be made to depend on the migration module — a
deployment can run the scheduler without ever running a migration.

It is deliberately not a query builder: the statements over these tables are
conditional writes whose exact shape is load-bearing (the affected-row count of
`UPDATE … WHERE state = 'pending'` *is* the arbitration), so only the pure
repetition — the DDL and the column *lists* — is generated. Column references
inside `SET` and `WHERE` stay written out and are audited by
`unknownFrameworkColumns` instead. See [Framework-Owned
Tables](../datasources.md#framework-owned-tables).

#### TomFrameworkColumn

One column of a framework-owned table.

##### Constructors

```dart
const TomFrameworkColumn(
  String name,
  String type, {
  bool nullable = false,
  String? defaultValue,
  bool autoIncrement = false,
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The column name, exactly as it is spelled in SQL. |
| `type` | `String` | The SQL type, including any length or precision — `VARCHAR(191)`. |
| `nullable` | `bool` | Whether the column accepts `NULL`. |
| `defaultValue` | `String?` | The `DEFAULT` clause's value as SQL text, or `null` for no default. |
| `autoIncrement` | `bool` | Whether the column carries `AUTO_INCREMENT`. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ddl` | `String ddl(int nameWidth, int typeWidth)` | The column's line in a `CREATE TABLE` body, padded to the two widths so a reader can scan the types in a column. |
| `toString` | `String toString()` | *(override)* `"<name> <type>"`. |

#### TomFrameworkKey

One index or unique constraint of a framework-owned table. The name is built
from the table's name and `suffix` rather than given outright, because the table
name is a per-instance argument of the owning store: two stores over
differently-named tables in one schema would otherwise collide on an index name
and the second `CREATE TABLE` would fail.

##### Constructors

```dart
const TomFrameworkKey(String suffix, List<String> columns, {bool unique = false})
const TomFrameworkKey.unique(String suffix, List<String> columns)
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `suffix` | `String` | The part of the key's name that identifies what it is for. |
| `columns` | `List<String>` | The columns the key covers, in key order. |
| `unique` | `bool` | Whether the key is a uniqueness constraint rather than an index. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `nameOn` | `String nameOn(String table)` | The key's name on `table` — `ix_<table>_<suffix>`, or `uq_…` when unique. |
| `ddl` | `String ddl(String table)` | The key's line in a `CREATE TABLE` body. |

#### TomFrameworkTable

A table the framework owns, declared once. The constructor checks that every
primary-key part and every key column names a column of this table, because a
descriptor is built once at start-up: a typo would otherwise surface as a
`CREATE TABLE` failure against a live server, which is the class of failure this
type exists to remove.

##### Constructors

```dart
TomFrameworkTable({
  required String name,
  required List<TomFrameworkColumn> columns,
  required String origin,
  List<String> primaryKey = const [],
  List<TomFrameworkKey> keys = const [],
})
```

Throws `ArgumentError` when `primaryKey` or a key names a column the table does
not declare.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The table's name, which is a per-instance argument of the owning store. |
| `columns` | `List<TomFrameworkColumn>` | The columns, in declaration order. |
| `primaryKey` | `List<String>` | The primary-key column names, in key order. |
| `keys` | `List<TomFrameworkKey>` | The unique constraints and secondary indexes. |
| `origin` | `String` | The library-level function that declares this table, named so a divergence report says where to go and not merely what is wrong. |
| `columnNames` | `List<String>` | The column names, in declaration order. |
| `columnList` | `String` | Every column as a `SELECT`/`INSERT` list, in declaration order. |
| `createTableDdl` | `String` | The `CREATE TABLE IF NOT EXISTS` statement that builds this table. `IF NOT EXISTS` because every store calls it on first use and a second process must not fail on a table the first one created. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `has` | `bool has(String column)` | Whether a column called `column` exists, case-insensitively. |
| `column` | `TomFrameworkColumn? column(String column)` | The named column, or `null`. |
| `columnsOf` | `String columnsOf(Iterable<String> names)` | `names` as a column list, in the order given. Throws `ArgumentError` when a name is not a column — a projection that outlived the column it names fails at the first call rather than at the database. |
| `insert` | `String insert(String verb, Map<String, String> values)` | Renders a row-writing statement. `verb` is the whole leading clause (`INSERT`, `REPLACE`, `INSERT IGNORE`); `values` maps a column name to the SQL text that supplies it, usually a `:bind` but sometimes a literal. Keyed by name rather than by position, because a positional list would let a column inserted in the descriptor silently shift every value one place along. Throws `ArgumentError` on an unknown column. |
| `toString` | `String toString()` | *(override)* `"TomFrameworkTable(<name>)"`. |

### Exceptions

#### TomDatasourceInitException

Thrown when a data source cannot be discovered, instantiated, or initialised
(duplicate or missing driver, bad configuration, etc.).

- **Extends:** `TomServerException`

##### Constructors

```dart
TomDatasourceInitException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

`clientThrow` is **not** a parameter: every condition this type reports is
infrastructure, and its messages name driver classes, datasource types and raw
driver errors. Masking is an invariant of the type rather than a default a
raise site could forget to keep.

##### Error keys

All ten read `<area>.<operation>.<condition>`. The operation segment is
load-bearing rather than decorative: `driver_instantiation_failed` and
`invalid_driver_not_implementing_datasource` each arise both during the
reflection scan and during a later `createDatasourceOf`, and only the operation
tells the two apart.

| Key | Raised by |
| --- | --------- |
| `tom_datasource.initialize_datasource_types.duplicate_driver` | Two drivers annotated for one datasource type |
| `tom_datasource.initialize_datasource_types.driver_instantiation_failed` | A driver found by the scan could not be constructed |
| `tom_datasource.initialize_datasource_types.invalid_driver_not_implementing_datasource` | A scanned driver does not implement `TomDataSource` |
| `tom_datasource.create_datasource_of.driver_instantiation_failed` | The registered driver for the requested type could not be constructed |
| `tom_datasource.create_datasource_of.invalid_driver_not_implementing_datasource` | The registered driver does not implement `TomDataSource` |
| `tom_datasource.create_datasource_of.no_driver_found` | No driver is registered for the requested type |
| `tom_datasource_info.get_datasource.datasource_is_null` | The named registry entry has not been initialised |
| `tom_datasource_info.initialize.delegate_not_found` | A `delegateTo` setting names an unregistered data source |
| `tom_datasource_info.initialize.no_datasource_obtained_for_type` | `createDatasourceOf` returned nothing for the configured type |
| `tom_datasource_info.initialize.no_type_specified` | The configuration entry carries no `type` |
| `tom_datasource_info.initialize.unknown_setting` | A settings key names no field of the configured driver |

#### MariadbDatasourceException

Thrown for MariaDB data-source failures (connect, execute, result mapping).

- **Extends:** `TomServerException`

##### Constructors

```dart
MariadbDatasourceException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

#### MariadbPreparedStatementException

Thrown when a MariaDB prepared statement failed with no live link to have run
on, signalling that a single reconnect-and-retry may recover it. The type
carries the whole signal — `MariadbPreparedStatement.execute` catches this and
nothing else — and which failures qualify is settled by
`isLostConnectionFailure`.

- **Extends:** `TomServerException`

##### Constructors

```dart
MariadbPreparedStatementException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

## Enums

### TomAggregateFunction

The aggregate functions the typed query layer can express. Naming the vocabulary
in the dialect file rather than in the expression tree keeps the set a dialect
must be able to render in one place: an override switches on this enum and the
compiler reports every site when a member is added.

| Value | Renders | Meaning |
| ----- | ------- | ------- |
| `count` | `COUNT` | The number of rows, or of non-null operand values. |
| `sum` | `SUM` | The total of the operand across the group. |
| `avg` | `AVG` | The mean of the operand across the group. |
| `min` | `MIN` | The smallest operand value in the group. |
| `max` | `MAX` | The largest operand value in the group. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `sqlName` | `String` | *(getter)* The SQL function name the member renders as (the upper-cased member name). |

### TomSqlTypeFamily

The coarse type classes a stored column can belong to — `integer`, `decimal`,
`text`, `boolean`, `dateTime`, `date`, `time`, `binary`, `unknown`. It exists so
a Dart type and a SQL type name can be compared at all (the schema-convergence
check reduces both sides to it), and is deliberately coarse: widths, precisions,
signedness and defaults are not represented, because the Dart side never states
them. A dialect classifies through `TomStandardSqlDialect.typeFamily` — see
[Methods — type classification](#methods--type-classification) for that method
and the two helpers an override reuses, and [Classifying Column
Types](../datasources.md#classifying-column-types) for the reasoning.

### TomSqlFailureMode

What a failed data-source write says about whether it took effect —
`definite` (the server answered with an error, so the statement did not apply)
or `ambiguous` (the failure was on the way to or from the server, so the write
may have been applied anyway). Ambiguous is the default because only a server
answer is evidence: the set of transport failures is open-ended and grows with
every driver and proxy, so enumerating it would make each omission a silent
correctness bug, while "the server answered" is closed and recognisable. The
costs are asymmetric too — a false `ambiguous` costs one wasted `SELECT`, a
false `definite` is the bug the classifier exists to prevent. See [When a Write
Fails](../datasources.md#when-a-write-fails).

## Global Functions and Constants

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `classifySqlFailure` | `TomSqlFailureMode classifySqlFailure(Object? error)` | Classifies the failure of a data-source write: `definite` when the chain contains a `MySQLServerException` (the server received the statement and rejected it), `ambiguous` for everything else. |
| `sqlFailureCauses` | `Iterable<Object> sqlFailureCauses(Object? error)` | `error` and every `rootException` beneath it, outermost first — exposed so a caller that has decided a failure is ambiguous can name the driver exception several wrappers down. |
| `isLostConnectionFailure` | `bool isLostConnectionFailure(Object? error, {required bool connected})` | Whether the statement was left with no live link to have run on, so one reconnect-and-retry is worth it: true when `connected` is false *and* the chain holds no `MySQLServerException`. Drives `MariadbPreparedStatement.execute`'s single retry. |
| `sqlInstant` | `String sqlInstant(DateTime value)` | Renders `value` as the UTC `DATETIME(6)` literal the columns bind — always UTC, always six fractional digits, so nodes that disagree about the local zone still agree about the instant and the text stays comparable in SQL as well as in Dart. |
| `sqlDate` | `String sqlDate(DateTime value)` | Renders the calendar half of `value` as the fixed-width `YYYY-MM-DD` a `DATE` column takes. The components are read **as labelled** — the opposite choice from `sqlInstant`, and the right one for the same reason: an instant is a moment, so it is normalised to the frame every node shares, while a date names a day *in the calendar it was written in*, and converting it to UTC moves it to the previous or next day for half the world's zones. |
| `sqlTimeOfDay` | `String sqlTimeOfDay(DateTime value)` | Renders the clock half of `value` as the fixed-width `HH:MM:SS` a `TIME` column takes — the other half of `sqlDate`, components likewise as labelled. Sub-second digits are dropped: a `TIME` with no declared precision keeps whole seconds, and text the column cannot hold compares unequal to the value stored from it. |
| `parseSqlInstant` | `DateTime parseSqlInstant(String value)` | Reads a stored `DATETIME(6)` back as a UTC `DateTime`. `DateTime.parse` on the column text alone would produce a *local* value, which compares unequal to the UTC one that was written; appending the zone marker is what makes the round trip exact. |
| `parseOptionalSqlInstant` | `DateTime? parseOptionalSqlInstant(String? value)` | Reads an optional stored `DATETIME(6)`, treating an empty column as absent — the driver reports a `NULL` instant as either `null` or `''` depending on the row mapper, and the two are collapsed here rather than at every caller. |
| `parseSqlDate` | `TomZonedDate parseSqlDate(String value)` | Reads a stored `DATE` back as a `TomZonedDate` — the reading half of `sqlDate`, taking the components as labelled and anchoring them in UTC, because a `DATE` column has nowhere to put a zone. Tom's `@D@…` serialization is accepted too, and does carry one. The trailing midnight the driver appends when it materialises a `DATE` (`2026-07-15 00:00:00.0`) is accepted and discarded; a trailing clock reading that is not zero throws, being a timestamp read by the wrong reader. |
| `parseSqlTimeOfDay` | `TomZonedTime parseSqlTimeOfDay(String value)` | Reads a stored `TIME` back as a `TomZonedTime` — the other half, on the same terms. Sub-second digits are accepted and dropped, matching `sqlTimeOfDay`. An hour past 23 throws: MariaDB's `TIME` spans 838 hours because it doubles as a duration type, and a duration is not a clock reading — wrapping it into the next day would turn a modelling mistake into a plausible wrong answer. |
| `unknownFrameworkColumns` | `List<String> unknownFrameworkColumns(String sql, Iterable<TomFrameworkTable> tables)` | The identifiers in `sql` that are not a column of any of `tables`, not one of their names or index names, and not SQL. The guard for the half of a statement a column list cannot cover — the references inside `SET`, `WHERE` and `ORDER BY` — driven by passing every statement a store issued through it. String literals, `:bind` placeholders and numbers are stripped first, and anything surviving that is not a known SQL word is reported: a missing word is a noisy false positive in a test, a missed column reference is a production failure. |

`SqlString` (in `sql_dialects.dart`) is a typedef alias for `String` that
documents "this is a SQL fragment" at call sites.
