# Tom Core Server API Reference: Datasources Module

The data-access foundation of the server: SQL-typed values (`TomDbType<T>`), a
typed operator tree (`TomOperator<R>`), a SQL dialect that renders that tree to
SQL fragments (`TomStandardSqlDialect`), reusable query objects (`TomSelect`,
`TomCount`, `TomDelete`, `TomUpdate`, `TomLiteralSelect`), and the data-source / driver
abstraction (`TomDataSource`, `TomDatasourceDriver`, `TomDataSourceInfo`) with
two SQL drivers — MariaDB and PostgreSQL — built on one driver-neutral base
(`TomSqlDatasource`). Two smaller surfaces sit beside them because every
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
    - [PostgresSqlDialect](#postgressqldialect)
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
    - [TomUpdate](#tomupdate)
  - [Data Sources and Drivers](#data-sources-and-drivers)
    - [TomDataSource](#tomdatasource)
    - [TomPreparedStatement&lt;T&gt;](#tompreparedstatementt)
    - [TomStatementOutcome&lt;T&gt;](#tomstatementoutcomet)
    - [TomDatasourceDriver](#tomdatasourcedriver)
    - [TomDataSourceInfo](#tomdatasourceinfo)
  - [The Connection Pool](#the-connection-pool)
    - [TomConnectionPool&lt;C&gt;](#tomconnectionpoolc)
    - [TomConnectionPoolSettings](#tomconnectionpoolsettings)
    - [TomConnectionFactory&lt;C&gt;](#tomconnectionfactoryc)
  - [The SQL Driver Base](#the-sql-driver-base)
    - [TomSqlDatasource](#tomsqldatasource)
    - [TomSqlPreparedStatement&lt;T&gt;](#tomsqlpreparedstatementt)
    - [TomSqlRow](#tomsqlrow)
    - [TomSqlResult](#tomsqlresult)
    - [TomSqlResultValues](#tomsqlresultvalues)
    - [TomSqlLink](#tomsqllink)
    - [TomSqlBranch](#tomsqlbranch)
    - [TomSqlTwoPhaseRecovery](#tomsqltwophaserecovery)
  - [The MariaDB Driver](#the-mariadb-driver)
    - [MariaDbDatasource](#mariadbdatasource)
    - [MariaDbXADatasource](#mariadbxadatasource)
    - [MariadbPreparedStatement&lt;T&gt;](#mariadbpreparedstatementt)
  - [The PostgreSQL Driver](#the-postgresql-driver)
    - [PostgresDatasource](#postgresdatasource)
    - [PostgresXADatasource](#postgresxadatasource)
  - [Read Replicas](#read-replicas)
    - [TomPrimaryReads](#tomprimaryreads)
    - [TomReplicaRouting](#tomreplicarouting)
  - [Placeholder Scanning](#placeholder-scanning)
    - [SqlPlaceholderScan](#sqlplaceholderscan)
  - [SQL Lexing](#sql-lexing)
    - [TomSqlLexer](#tomsqllexer)
  - [Framework-Owned Tables](#framework-owned-tables)
    - [TomFrameworkColumn](#tomframeworkcolumn)
    - [TomFrameworkKey](#tomframeworkkey)
    - [TomFrameworkTable](#tomframeworktable)
    - [TomSchemaProvisioning](#tomschemaprovisioning)
  - [Exceptions](#exceptions)
    - [TomDatasourceInitException](#tomdatasourceinitexception)
    - [TomConnectionPoolException](#tomconnectionpoolexception)
    - [TomSqlDatasourceException](#tomsqldatasourceexception)
    - [TomSqlConnectionLostException](#tomsqlconnectionlostexception)
    - [MariadbDatasourceException](#mariadbdatasourceexception)
    - [MariadbPreparedStatementException](#mariadbpreparedstatementexception)
    - [PostgresDatasourceException](#postgresdatasourceexception)
    - [PostgresConnectionLostException](#postgresconnectionlostexception)
- [Enums](#enums)
  - [TomAggregateFunction](#tomaggregatefunction)
  - [TomSqlTypeFamily](#tomsqltypefamily)
  - [TomSqlFailureMode](#tomsqlfailuremode)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/datasources/connection_pool.dart`,
`lib/src/tomserver/datasources/datasource_initialization.dart`,
`lib/src/tomserver/datasources/framework_table.dart`,
`lib/src/tomserver/datasources/mariadb_datasource.dart`,
`lib/src/tomserver/datasources/mariadb_sql_dialect.dart`,
`lib/src/tomserver/datasources/postgres_datasource.dart`,
`lib/src/tomserver/datasources/postgres_sql_dialect.dart`,
`lib/src/tomserver/datasources/queries.dart`,
`lib/src/tomserver/datasources/read_replicas.dart`,
`lib/src/tomserver/datasources/sql_datasource.dart`,
`lib/src/tomserver/datasources/sql_dialects.dart`,
`lib/src/tomserver/datasources/sql_failure_mode.dart`,
`lib/src/tomserver/datasources/sql_instant.dart`,
`lib/src/tomserver/datasources/sql_lexer.dart`,
`lib/src/tomserver/datasources/sql_placeholder_scan.dart`,
`lib/src/tomserver/datasources/types_operator.dart`.

A `TomDbType<T>` boxes a Dart value together with its SQL column type; a
`TomOperator<R>` is a node in a type-safe SQL expression tree that renders
itself through a `TomStandardSqlDialect`. Query objects (`TomSelect`,
`TomCount`, `TomDelete`, `TomUpdate`, `TomLiteralSelect`) wrap a predicate into a full
statement. `TomAggregateFunction` and four dialect fragments (`aggregate`,
`aliased`, `groupByClause`, `havingClause`) are the whole SQL surface a grouped
query renders through — the query object itself, `TomGroupedSelect`, is declared
in the object-persistence module because it is built from that module's
aggregate nodes. A `TomDataSource` is a driver-implemented data source that prepares
statements, runs commands and queries, and enlists in transactions;
`TomDataSourceInfo` is the process-wide registry of named, configured data
sources. `TomSqlDatasource` implements the whole surface once, over a
`TomConnectionPool` — a connection per transaction, so concurrent transactions
run side by side — and reads every result through one text convention
(`TomSqlRow`, `TomSqlResult`); a driver supplies only the wire. Two drivers
extend it: MariaDB (`MariaDbDatasource`, plus the XA variant
`MariaDbXADatasource`) and PostgreSQL 15 and later (`PostgresDatasource`, plus
the two-phase variant `PostgresXADatasource`), each with its own dialect
(`MariadbSqlDialect`, `PostgresSqlDialect`). `SqlPlaceholderScan` rewrites the
generated `:name` placeholders into the positional form each protocol binds —
`?` for MariaDB, `$1`, `$2`, … for PostgreSQL. A SQL data source configured
with `replicas` lets read replicas serve the repository reads of read-only work;
`TomReplicaRouting` holds the rules and `TomPrimaryReads` pins an entity's reads
to the primary.

The framework declares its own tables in one canonical DDL vocabulary,
MariaDB's spelling (`DATETIME(6)`, `TINYINT(1)`, `AUTO_INCREMENT`, inline
`KEY`s). The dialect's DDL and row-write methods (`columnType`,
`columnDefinition`, `keyDefinition`, `createIndex`, `insertInto`,
`replaceInto`, `incrementCounter`, `returningKey`, `translateCanonical`) render
that declaration and the framework's conflicting writes in each database's own
words; the defaults render MariaDB's spelling unchanged.

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
    ├── MariadbSqlDialect
    └── PostgresSqlDialect

TomDatasourceDriver  (annotation)

TomTypedPersistenceBase
    └── TomQuery
            ├── TomGeneratedQuery
            │       ├── TomSelect
            │       ├── TomCount
            │       ├── TomDelete
            │       ├── TomUpdate
            │       └── TomGroupedSelect  (object_persistence)
            └── TomLiteralSelect

TomTypePersistenceInfo

TomPreparedStatement<T>
    └── TomSqlPreparedStatement<T>
            └── MariadbPreparedStatement<T>

TomStatementOutcome<T>  (value — what one run reported)

TomTransactionParticipant  (transactions)
    └── TomDataSource
            └── TomSqlDatasource  (implements)
                    ├── MariaDbDatasource
                    │       └── MariaDbXADatasource  (with TomSqlTwoPhaseRecovery)
                    └── PostgresDatasource
                            └── PostgresXADatasource  (with TomSqlTwoPhaseRecovery)

TomSqlTwoPhaseRecovery  (mixin on TomSqlDatasource; implements
                         TomPreparedBranchHolder, TomTwoPhaseRecoverable — transactions)

TomSqlRow     (interface)
TomSqlResult  (interface)
    └── TomSqlResultValues  (implements)
TomSqlLink
TomSqlBranch

TomConnectionPool<C>
TomConnectionPoolSettings
TomConnectionFactory<C>  (interface)

TomDataSourceInfo
TomPrimaryReads  (annotation)
TomReplicaRouting  (statics)
SqlPlaceholderScan
TomSqlLexer
TomFrameworkTable
TomFrameworkColumn
TomFrameworkKey
TomSchemaProvisioning

TomServerException  (little_things)
    ├── TomSqlDatasourceException
    │       ├── MariadbDatasourceException
    │       └── PostgresDatasourceException
    ├── TomSqlConnectionLostException
    │       ├── MariadbPreparedStatementException
    │       └── PostgresConnectionLostException
    ├── TomConnectionPoolException
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

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `likeEscapeCharacter` | `String` | *(getter)* The character that turns the next `%` or `_` in a `LIKE` pattern into itself, named in the `ESCAPE` clause `like` and `notLike` render. A dialect whose escape character differs overrides this alone; `escapeLikePattern` and the rendered clause both read it from here. Defaults to `\`. |
| `declaresIndexesInline` | `bool` | *(getter)* Whether a `CREATE TABLE` body may declare a non-unique index inline (`KEY name (columns)`). `true` here; where it is `false`, `createIndex` renders one statement per index after the table. |
| `backslashEscapes` | `bool` | *(getter)* Whether a backslash escapes the next character inside a string literal — `true` here (MariaDB's default mode); a statement splitter needs the database's rule. |
| `schemaSetting` | `String` | *(getter)* The data-source setting that points a connection at a schema — `databaseName` here, where a schema and a database are one thing. A schema-isolated tenant's data source is its base data source with this one setting changed. |
| `currentSchema` | `SqlString` | *(getter)* The expression naming the schema the connection works in — `DATABASE()` here — for a catalogue query about "this" schema. |
| `tableColumnsQuery` | `SqlString` | *(getter)* A query answering, for the table bound as `:table` in `currentSchema`, one row per column in declaration order: `column_name`, `column_type` (with its length — `varchar(191)`, `tinyint(1)`), `is_nullable` (`YES` / `NO`) and `column_key` (`PRI` for a primary-key column). What the live framework-schema check compares a framework table against. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isNull` | `SqlString isNull<T>(TomOperator<T> what)` | Renders `<what> IS NULL`. |
| `isNotNull` | `SqlString isNotNull<T>(TomOperator<T> what)` | Renders `<what> IS NOT NULL`. |
| `isin` | `SqlString isin<T>(TomOperator<T> what, List<TomOperator<T>> choices)` | Renders `<what> IN (<choices...>)` comma-separated. |
| `between` | `SqlString between<T>(TomOperator<T> what, List<TomOperator<T>> betweenLimits)` | Renders `<what> BETWEEN <lo> AND <hi>`. |
| `like` | `SqlString like(TomOperator<TomDbString> text, TomOperator<TomDbString> test)` | Renders `<text> LIKE <test> ESCAPE '<likeEscapeCharacter>'`. The clause is always written: standard SQL defines no default escape character, so without it whether `escapeLikePattern`'s output works would be a property of the driver rather than of the rendering. |
| `notLike` | `SqlString notLike(TomOperator<TomDbString> text, TomOperator<TomDbString> test)` | Renders `<text> NOT LIKE <test> ESCAPE '<likeEscapeCharacter>'` — see `like`. |
| `escapeLikePattern` | `String escapeLikePattern(String literal)` | Escapes `%`, `_` and `likeEscapeCharacter` in `literal`, so a `LIKE` pattern built from it matches those characters literally. The wildcards stay the caller's to place: `'%${dialect.escapeLikePattern(input)}%'`. |
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
| `exists` | `SqlString exists(SqlString subquery)` | Renders `EXISTS (<subquery>)` over the rendered `subquery`. |
| `inSubquery` | `SqlString inSubquery(SqlString operand, SqlString subquery)` | Renders `<operand> IN (<subquery>)` over the rendered `operand` and `subquery`. |
| `subquery` | `SqlString subquery(SqlString projection, List<String> tables, List<SqlString> conditions)` | Renders `SELECT <projection> FROM <tables> WHERE (<c1>) AND (<c2>) …`, each condition parenthesised so an `OR` inside one cannot bind across the `AND` that joins them; no `WHERE` when `conditions` is empty. |
| `text` | `SqlString text(String text)` | Renders a single-quoted string literal, escaping `\` and `'`. |
| `intOp` | `SqlString intOp(int value)` | Renders an integer literal. |
| `doubleOp` | `SqlString doubleOp(double value)` | Renders a double literal. |
| `boolOp` | `SqlString boolOp(bool value)` | Renders a boolean literal — a value compared with a truth column. |
| `truthPredicate` | `SqlString truthPredicate(bool value)` | Renders a constant predicate — the `WHERE false` of a scope that admits nothing. The same text as `boolOp` here; a database whose truth columns are not booleans (PostgreSQL, where they are `SMALLINT`) renders the two differently. |
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

##### Methods — DDL and row writes

The framework declares its own tables once, in a **canonical** type vocabulary —
MariaDB's spelling: `DATETIME(6)`, `TINYINT(1)`, `LONGTEXT`, `AUTO_INCREMENT`,
inline `KEY`s — and every database renders that declaration, and the
framework's conflicting writes, in its own words. The defaults below render the
canonical spelling unchanged; a dialect whose database spells a type, a key or
a conflicting write differently overrides the method that renders it.

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `columnType` | `String columnType(String canonicalType)` | The type this database stores the canonical `canonicalType` as. Returns it unchanged here. |
| `columnDefinition` | `SqlString columnDefinition({required String name, required String type, required bool nullable, String? defaultValue, bool autoIncrement = false, int nameWidth = 0, int typeWidth = 0})` | One column's line in a `CREATE TABLE` body — name, `columnType(type)`, `NULL` / `NOT NULL`, the `DEFAULT`, then `AUTO_INCREMENT` — with the name and type padded to `nameWidth` and `typeWidth` so a reader can scan the types in a column. |
| `keyDefinition` | `SqlString keyDefinition(String name, List<String> columns, {required bool unique})` | An inline key's line in a `CREATE TABLE` body: `UNIQUE KEY name (…)` or `KEY name (…)`. |
| `createIndex` | `SqlString createIndex(String name, String table, List<String> columns)` | `CREATE INDEX IF NOT EXISTS name ON table (…)` — the statement for an index the body cannot declare (`declaresIndexesInline` is `false`). |
| `insertInto` | `SqlString insertInto(String table, Map<String, String> values, {bool ignoreConflict = false})` | A row-writing statement into `table`: the columns of `values` with the SQL text that supplies each — a `:bind` or a literal. A row whose key already exists raises the database's duplicate-key error, unless `ignoreConflict` asks for the stored row to be kept and the write to change nothing (`INSERT IGNORE` here). |
| `replaceInto` | `List<SqlString> replaceInto(String table, Map<String, String> values, {required List<String> primaryKey, List<List<String>> uniqueKeys = const []})` | The statements writing a row over every row it supersedes — the one with its `primaryKey`, and any colliding with it on one of `uniqueKeys` — run in order, in one transaction when there is more than one. One `REPLACE INTO` here. A database without `REPLACE` deletes the superseded rows first: a key freed by a statement is free to the next statement of the same transaction, and to nothing earlier. |
| `incrementCounter` | `SqlString incrementCounter(String table, Map<String, String> values, String counter, {required List<String> conflictKey})` | One statement that counts one more in `table`'s row whose `conflictKey` columns hold what `values` supplies, creating the row with a count of `1` when there is none, and reports the count it left in `counter` as the statement's generated id. Taken and read in one statement because a second read is wrong under concurrency: every caller of a burst would see the final total rather than its own place in it. `LAST_INSERT_ID(expr)` with `ON DUPLICATE KEY UPDATE` here. |
| `returningKey` | `SqlString returningKey(String insert, String keyColumn)` | `insert` made to report the value of `keyColumn` it generated as the statement's generated id. Returns `insert` unchanged here — a database with a last-insert id reports the key on its own. |
| `translateCanonical` | `List<SqlString> translateCanonical(String statement)` | `statement`, written in the canonical DDL, as the statements this database runs to the same effect. Returns `[statement]` here. A store that keeps a hand-written `CREATE TABLE`, and a test that builds a fixture table, pass it through here so one declaration serves every database. |
| `translateCanonicalScript` | `String translateCanonicalScript(String script)` | A whole canonical `script` — a migration file — in this database's words: each statement (`TomSqlLexer.splitStatements`) through `translateCanonical`, comments kept, one `;`-terminated statement per paragraph. |
| `createSchema` | `SqlString createSchema(String name)` | The statement creating schema `name` if it does not exist — `` CREATE DATABASE IF NOT EXISTS `name` `` here, where a schema is a database. `name` must be a plain identifier; the caller checks it. |
| `rejectingTrigger` | `List<SqlString> rejectingTrigger({required String name, required String table, required String event, required String message})` | The statements installing trigger `name`, which refuses every `event` (`UPDATE` or `DELETE`) on `table` with `message` — a guard a deployment installs, not something the framework issues itself. One `CREATE TRIGGER … SIGNAL SQLSTATE '45000'` here. |
| `quoteIdentifier` | `SqlString quoteIdentifier(String identifier)` | `identifier` quoted, for a name that may be a reserved word or carry characters an unquoted identifier may not — backticks here, an embedded backtick doubled. |

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

#### PostgresSqlDialect

The SQL dialect for PostgreSQL 15 and later. Like `MariadbSqlDialect`, nothing
looks it up: `PostgresDatasource.sqlDialect` returns an instance. It renders the
canonical DDL in PostgreSQL's words and the truth-value, regexp, conflict and
catalogue fragments PostgreSQL spells differently.

A Dart `bool` is bound as `1`/`0` on every database and a framework truth column
is a `SMALLINT` here, so a boolean *value* renders as `1`/`0` (`boolOp`) while a
constant *predicate* renders as `TRUE`/`FALSE` (`truthPredicate`) — a `true`
compared with a `SMALLINT` is a type error in PostgreSQL, and a `WHERE 0` is
one too.

- **Extends:** `TomStandardSqlDialect`

##### Constructors

```dart
PostgresSqlDialect()
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `backslashEscapes` | `bool` | *(override)* `false`: PostgreSQL reads a backslash in an ordinary literal as itself. |
| `declaresIndexesInline` | `bool` | *(override)* `false`: PostgreSQL declares no index inside `CREATE TABLE`, only uniqueness. |
| `schemaSetting` | `String` | *(override)* `schema` — the `PostgresDatasource` setting that sets the session's `search_path`. |
| `currentSchema` | `SqlString` | *(override)* `current_schema()`. |
| `tableColumnsQuery` | `SqlString` | *(override)* The catalogue's answer in MariaDB's column shape: `format_type` for the type with its length (`character varying(191)`, `timestamp(6) without time zone`), and `PRI` for a column of the primary key. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `text` | `SqlString text(String text)` | *(override)* A string literal with single quotes doubled and nothing else: PostgreSQL reads a backslash in an ordinary literal as itself (`standard_conforming_strings`), so doubling it would store two. |
| `boolOp` | `SqlString boolOp(bool value)` | *(override)* `1` or `0`. |
| `truthPredicate` | `SqlString truthPredicate(bool value)` | *(override)* `TRUE` or `FALSE`: a predicate has to be a boolean. |
| `regexp` | `SqlString regexp(TomOperator<TomDbString> text, TomOperator<TomDbString> test)` | *(override)* `<text> ~ <test>`, PostgreSQL's POSIX regular-expression match. |
| `typeFamily` | `TomSqlTypeFamily typeFamily(String sqlType)` | *(override)* The standard families plus PostgreSQL's own names — the sized `INT` aliases, `BIGSERIAL` and `SMALLSERIAL` integer, the sized `FLOAT` aliases decimal, `BYTEA` binary, `TIMESTAMPTZ` date-time, `TIMETZ` time, `JSONB`/`CITEXT`/`BPCHAR` text — delegating everything else to `super`. |
| `columnType` | `String columnType(String canonicalType)` | *(override)* The canonical type in PostgreSQL's words: `DATETIME(n)` → `TIMESTAMP(n)`, `TINYINT` → `SMALLINT`, `INT` / `MEDIUMINT` → `INTEGER`, `DOUBLE` → `DOUBLE PRECISION`, `FLOAT` → `REAL`, `TINYTEXT` / `MEDIUMTEXT` / `LONGTEXT` → `TEXT`, `CHAR(n)` → `VARCHAR(n)`, every `BLOB`, `VARBINARY` and `BINARY` → `BYTEA`, `ENUM(…)` → `VARCHAR(255)`; anything else unchanged. |
| `columnDefinition` | `SqlString columnDefinition({required String name, required String type, required bool nullable, String? defaultValue, bool autoIncrement = false, int nameWidth = 0, int typeWidth = 0})` | *(override)* As the base, with `GENERATED BY DEFAULT AS IDENTITY` for an auto-increment column. |
| `keyDefinition` | `SqlString keyDefinition(String name, List<String> columns, {required bool unique})` | *(override)* `CONSTRAINT name UNIQUE (…)` — the only key a PostgreSQL table body declares. |
| `insertInto` | `SqlString insertInto(String table, Map<String, String> values, {bool ignoreConflict = false})` | *(override)* `INSERT INTO … VALUES (…)`, with `ON CONFLICT DO NOTHING` for an ignored conflict. |
| `replaceInto` | `List<SqlString> replaceInto(String table, Map<String, String> values, {required List<String> primaryKey, List<List<String>> uniqueKeys = const []})` | *(override)* MariaDB's `REPLACE` as two statements: a `DELETE` of every row the new one supersedes — the one with its primary key, and any colliding on a unique key whose columns the write supplies in full — then `INSERT … ON CONFLICT (<primary key>) DO UPDATE SET` every other column (`DO NOTHING` when there is none), which absorbs a writer that inserted the same key between the two. |
| `incrementCounter` | `SqlString incrementCounter(String table, Map<String, String> values, String counter, {required List<String> conflictKey})` | *(override)* `INSERT … VALUES (…, 1) ON CONFLICT (<conflictKey>) DO UPDATE SET counter = table.counter + 1 RETURNING counter`; the driver reports the returned count as the generated id. |
| `returningKey` | `SqlString returningKey(String insert, String keyColumn)` | *(override)* `insert` with `RETURNING keyColumn` appended — PostgreSQL has no last-insert id, and its driver reads a single returned integer as the generated id. |
| `createSchema` | `SqlString createSchema(String name)` | *(override)* `CREATE SCHEMA IF NOT EXISTS "name"` — a PostgreSQL schema lives inside the one database. |
| `rejectingTrigger` | `List<SqlString> rejectingTrigger({required String name, required String table, required String event, required String message})` | *(override)* Two statements: a PL/pgSQL trigger function `<name>_reject` raising `message`, and the `BEFORE <event>` row trigger calling it. The function body is an ordinary single-quoted literal rather than dollar-quoted, so the statement splitter sees one statement in it. |
| `quoteIdentifier` | `SqlString quoteIdentifier(String identifier)` | *(override)* `identifier` in double quotes, an embedded double quote doubled. |
| `translateCanonical` | `List<SqlString> translateCanonical(String statement)` | *(override)* The canonical `statement` in PostgreSQL's words — see below. Leading comment lines are kept on the first statement it becomes; a statement of no kind listed below runs as written. |

What `translateCanonical` rewrites:

| Canonical statement | Becomes |
| ------------------- | ------- |
| `CREATE TABLE` | Each column's type through `columnType`; `AUTO_INCREMENT` as an identity; `UNSIGNED`, `COMMENT`, `CHARACTER SET`, `COLLATE` and `ON UPDATE CURRENT_TIMESTAMP` dropped — except a binary collation (`…_bin`), which becomes `COLLATE "C"`, both meaning case-sensitive identity and code-unit order; a `TRUE`/`FALSE` default on a truth column as `1`/`0`; an `ENUM`'s value list as a `CHECK` on the `VARCHAR`; inline `UNIQUE KEY`s as constraints; inline `KEY`/`INDEX`es as `CREATE INDEX IF NOT EXISTS` statements after the table; the table options (`ENGINE=…`, `DEFAULT CHARSET=…`) dropped. An index name is schema-wide in PostgreSQL, so one that does not already name its table is prefixed with it. |
| `ALTER TABLE … ADD [COLUMN] …` | The column translated the same way. |
| `ALTER TABLE … MODIFY [COLUMN] …` | PostgreSQL's two actions: `ALTER COLUMN … TYPE … USING col::type` and `SET NOT NULL` / `DROP NOT NULL`. |
| MariaDB's refusing `CREATE TRIGGER … SIGNAL SQLSTATE` | The function and trigger `rejectingTrigger` renders. |
| `TRUNCATE TABLE …` | `TRUNCATE TABLE … RESTART IDENTITY`, so the identity restarts as an `AUTO_INCREMENT` does. |

Backtick quoting is removed throughout, and the name then folds to lower case
exactly as every unquoted reference to it does.

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

#### TomUpdate

An `UPDATE` of the first of the entity `types`: the columns of `set`, by their
column names, assigned their operands, for the rows the predicate selects. What
a repository renders a soft delete and a restore as (see
[Soft delete](../object_persistence.md#soft-delete)) — the `WHERE` the matching
hard delete would take, and the deletion-time column moved.

- **Extends:** `TomGeneratedQuery`

##### Constructors

```dart
TomUpdate(
  List<Type> types, {
  required TomOperator<TomDbBool> query,
  required Map<String, TomOperator<Object?>> set,
})
```

No shaping options: the statement updates every row the predicate selects. A
repository delete cut to a window resolves the window to its keys first.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `set` | `Map<String, TomOperator<Object?>>` | The assignments: column name to its new value. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `generateQuery` | `String generateQuery(TomStandardSqlDialect t)` | *(override)* Renders `UPDATE <table> SET <column> = <operand>, … WHERE <predicate>`. |
| `getParameters` | `List<String> getParameters(TomStandardSqlDialect t)` | *(override)* The assignments' parameters first, then the predicate's — the order their placeholders appear in. |
| `toString` | `String toString()` | *(override)* Debug description prefixed `TomUpdate:`. |

### Data Sources and Drivers

#### TomDataSource

One configured data source — the abstract contract a driver implements. It
exposes its `sqlDialect`, lifecycle, and execution surface, and is a
`TomTransactionParticipant`.

- **Implements:** `TomTransactionParticipant`

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `createDatasourceOf` | `static TomDataSource createDatasourceOf(String type)` | Returns a fresh data source for `type`, discovering drivers on first call; throws `TomDatasourceInitException` when none is registered or instantiation fails. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `sqlDialect` | `TomStandardSqlDialect` | The SQL dialect this data source generates against. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `initialize` | `Future<void> initialize(Map<String, dynamic> settings)` | Applies `settings` and opens the data source. |
| `close` | `Future<void> close()` | Closes the data source and frees its connections. |
| `isOperational` | `bool isOperational()` | Whether the data source is currently usable. Abstract: a driver must answer, from what it knows (whether it holds an open connection), so a driver that never implemented it cannot report usable by default. |
| `prepareStatement` | `Future<TomPreparedStatement<T>> prepareStatement<T extends Object>(TomQuery query, [Type? resultType])` | Compiles `query` into a reusable prepared statement. |
| `executeCommand` | `Future<BigInt> executeCommand(String command, [Map<String, dynamic>? params])` | Executes a write command and returns the affected-row count. |
| `executeQuery` | `Future<List<T>> executeQuery<T extends Object>(String command, [Map<String, dynamic>? params, Type? resultType])` | Executes a read command, mapping rows to `resultType`. |

#### TomPreparedStatement&lt;T&gt;

A reusable, server-side compiled statement that can be run any number of times —
concurrently, by any number of requests — and then deallocated. It keeps no
per-execution state: what one execution reported comes back from `run` as a
`TomStatementOutcome`, because a repository shares one statement across every
request and state on the handle would belong to whichever execution finished
last.

- **Type Parameters:** `T extends Object` — the mapped result row type.

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `execute` | `Future<List<T>> execute([Map<String, Object?>? params])` | Runs the statement and returns the mapped result rows. |
| `run` | `Future<TomStatementOutcome<T>> run([Map<String, Object?>? params])` | Runs the statement and returns everything that execution reported: its rows, the rows it changed and the key it generated. Abstract and without a default, because each is acted on — a save returns the row stored under `generatedId`, a delete returns `affectedRows` as the number of rows removed, and a versioned update reads `0` there as a conflict — so a default would let a driver's silence read as a real answer. |
| `deallocate` | `Future<void> deallocate()` | Releases the statement's server-side resources. |

#### TomStatementOutcome&lt;T&gt;

What one execution of a `TomPreparedStatement` reported, returned by `run` — the
execution it describes — rather than kept on the statement. Two saves
overlapping on one shared handle would otherwise each read the other's count,
and a versioned update that read "one row changed" from somebody else's update
would report a refused save as a success.

- **Type Parameters:** `T extends Object` — the mapped result row type.

##### Constructors

```dart
const TomStatementOutcome({
  required List<T> rows,
  required int affectedRows,
  required int? generatedId,
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `rows` | `List<T>` | The mapped result rows; empty for a statement that returns none. |
| `affectedRows` | `int` | The number of rows the execution changed — the count an `UPDATE` or `DELETE` reports, `0` for one that changed nothing. MariaDB counts rows changed, not matched; a versioned update always moves the version, so for it the two are the same. |
| `generatedId` | `int?` | The auto-increment / identity key the execution produced, or `null` when it produced none. Read from the insert's own result, so it is connection-correct where a follow-up `SELECT LAST_INSERT_ID()` is not; `TomSqlDatasourceRepository.save` refuses an insert whose key it asked the database to assign and did not get back (`crud_repository.save.no_generated_key`). |

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
| `router` | `TomDataSourceInfo Function(TomDataSourceInfo base)?` | The routing a multi-tenant deployment installs: maps a registered data source to the one the current tenant's data lives in — its schema or its database — or answers it unchanged. `null` routes nothing. Declared here and installed by the `tenancy` module's `TomTenancy.install`, so this module does not depend on it. |
| `registryKeys` | `Set<String>` | The settings keys the registry reads itself and does not pass on — `type`, which selects the driver, and `delegateTo`, which makes the entry an alias. Neither is a field of any driver. They are removed from the block before it reaches `TomDataSource.initialize` rather than being excused by an allowlist inside the unknown-key check, so that a driver is handed only what is addressed to it and every key it is handed has to bind. |

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `route` | `static TomDataSourceInfo route(TomDataSourceInfo base)` | `base` as the current tenant reaches it — `router(base)`, or `base` itself when no router is installed. A repository resolves its data source through this on every call, so one repository serves every tenant. |
| `getDataSourceInfo` | `static TomDataSourceInfo? getDataSourceInfo(String dsName)` | Returns the registered info for `dsName` as the current tenant reaches it (`route`), or `null` if none is registered. |
| `getBaseDataSourceInfo` | `static TomDataSourceInfo? getBaseDataSourceInfo(String dsName)` | Returns the registered info for `dsName` itself, unrouted, or `null` — what a store built for the whole deployment, and the tenancy's own provisioning, look up. |
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

### The Connection Pool

A connection carries one transaction at a time, so a data source serves
concurrent transactions only by giving each one a connection of its own.
`TomConnectionPool` lends connections up to a bound and takes them back for
reuse. It knows nothing about any database: a driver supplies a
`TomConnectionFactory` for its own connection type and decides what a lease is
held for — the SQL drivers (`TomSqlDatasource`) pin one connection to a transaction from its
first statement to its end, and lend one to a statement outside a transaction
for that statement alone. See [The Connection
Pool](../datasources.md#the-connection-pool).

#### TomConnectionPool&lt;C&gt;

A bounded pool of connections of type `C`. `acquire` lends a connection and
`release` takes it back. A released connection goes to the longest-waiting
`acquire` first, so a caller that arrived later cannot overtake one that has
been waiting. Idle connections past their idle timeout or lifetime are retired
when the pool is next used — there is no timer, which would keep a process that
never closes its data source from exiting.

- **Type Parameters:** `C extends Object` — the driver's connection type.

##### Constructors

```dart
TomConnectionPool(
  TomConnectionFactory<C> factory, {
  TomConnectionPoolSettings settings = const TomConnectionPoolSettings(),
  DateTime Function()? clock,
})
```

Validates `settings` (see `TomConnectionPoolSettings.validate`). `clock` is
injectable for tests.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `factory` | `TomConnectionFactory<C>` | Opens, closes and checks the connections. |
| `settings` | `TomConnectionPoolSettings` | How the pool sizes itself and retires connections. |
| `isClosed` | `bool` | *(getter)* Whether `close` has been called. |
| `size` | `int` | *(getter)* Open connections, lent or idle, plus those being opened. |
| `idleCount` | `int` | *(getter)* Idle connections. |
| `lentCount` | `int` | *(getter)* Lent connections. |
| `waitingCount` | `int` | *(getter)* Callers waiting in `acquire`. |
| `connections` | `Iterable<C>` | *(getter)* Every open connection, lent or idle. |
| `idleConnections` | `Iterable<C>` | *(getter)* The idle connections, which nothing is using. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `acquire` | `Future<C> acquire()` | Lends a connection: the most recently released usable idle one — validated first when it sat idle past `validateAfterIdle` — or a new one when there is room, or else the next one released, waiting up to `acquireTimeout`. Throws `TomConnectionPoolException` (`error.datasource.pool.closed`) once the pool is closed and (`error.datasource.pool.acquire_timeout`, parameters `maxSize` and `timeoutMs`) when the wait runs out. A failure to open propagates as the factory raised it and frees the slot it reserved. |
| `release` | `Future<void> release(C connection, {bool discard = false})` | Takes `connection` back. With `discard`, or when the connection is no longer usable, past its `maxLifetime`, or the pool is closed, it is closed instead of kept; otherwise it goes to the longest waiter, or to the idle list. Releasing a connection the pool did not lend throws `StateError`. |
| `close` | `Future<void> close()` | Closes the pool: idle connections at once, lent ones when they are released, and every waiter fails with `error.datasource.pool.closed`. Closing twice does nothing. |
| `isLent` | `bool isLent(C connection)` | Whether `connection` is currently lent out. |
| `toString` | `String toString()` | *(override)* `lent`, `idle`, `waiting` and `max` counts, and `closed` once closed. |

#### TomConnectionPoolSettings

How a `TomConnectionPool` sizes itself and when it retires a connection. The
defaults are the common ones of JDBC pools, HikariCP among them.

##### Constructors

```dart
const TomConnectionPoolSettings({
  int maxSize = 10,
  int minIdle = 0,
  Duration acquireTimeout = const Duration(seconds: 30),
  Duration idleTimeout = const Duration(minutes: 10),
  Duration maxLifetime = const Duration(minutes: 30),
  Duration validateAfterIdle = const Duration(seconds: 30),
})
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `maxSize` | `int` | The most connections open at once, lent or idle. At least 1. |
| `minIdle` | `int` | Idle connections exempt from the idle timeout, refilled in the background when a connection is discarded on its return. At most `maxSize`; `0` opens connections only when they are asked for. |
| `acquireTimeout` | `Duration` | How long `acquire` waits when all `maxSize` connections are lent, before it fails. |
| `idleTimeout` | `Duration` | How long a connection may sit idle before the pool closes it, while more than `minIdle` are idle. Checked whenever the pool is used, not by a timer. |
| `maxLifetime` | `Duration` | How long a connection is used at all before the pool replaces it. |
| `validateAfterIdle` | `Duration` | A connection idle for longer than this is validated before it is lent, and replaced if the check fails. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `validate` | `void validate()` | Throws `TomConnectionPoolException` (`error.datasource.pool.invalid_settings`, its `fault` parameter naming the problem) unless `maxSize` is at least 1, `minIdle` is between 0 and `maxSize`, every timeout is positive and `validateAfterIdle` is not negative. |
| `toString` | `String toString()` | *(override)* Every setting, for a log line. |

#### TomConnectionFactory&lt;C&gt;

What a driver tells a `TomConnectionPool` about its connection type `C`. An
`abstract interface class`: a driver implements every member.

- **Type Parameters:** `C extends Object` — the driver's connection type.

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `open` | `Future<C> open()` | Opens a new connection. A failure propagates to the caller of `acquire` that needed it. |
| `close` | `Future<void> close(C connection)` | Closes `connection`. Called once per connection, when the pool retires it; a failure is logged by the driver, never propagated. |
| `isUsable` | `bool isUsable(C connection)` | Whether `connection` is still usable without asking the server — the driver's own record of whether its link is up. |
| `validate` | `Future<bool> validate(C connection)` | Asks the server whether `connection` still works (a `SELECT 1`). |

### The SQL Driver Base

Everything a SQL data source does that does not depend on the database lives
once in `sql_datasource.dart`: the connection pool, the transaction a
connection is pinned to, the statement paths, the row mapping and the settings
binding. A driver supplies the wire — how a connection is opened, how a
statement runs on it, how its results read as text, which words open and close a
transaction — by extending `TomSqlDatasource`, so the two drivers cannot drift
apart on a rule that has nothing to do with which server is on the other end.

**Results are read as text in one convention.** A driver hands its rows over as
`TomSqlRow`s, which answer every column as text: an instant as
`YYYY-MM-DD HH:MM:SS.ffffff` in UTC (`sqlInstant`), a date as `YYYY-MM-DD`, a
time as `HH:MM:SS`, a number as its decimal digits, a truth value as `1` or `0`.
That is how the MariaDB protocol delivers values anyway; the PostgreSQL driver,
whose protocol delivers typed values, renders them into it. The mapper then
reads one representation, with one set of parsers and one set of failure keys,
whichever database a row came from.

#### TomSqlDatasource

A pooled SQL `TomDataSource` — the driver-neutral base both SQL drivers extend.
Connection settings (`username`, `password`, `host`, `port`, `databaseName`,
`timeOut`) and pool settings (`poolMaxSize`, `poolMinIdle`,
`poolAcquireTimeoutMs`, `poolIdleTimeoutMs`, `poolMaxLifetimeMs`,
`poolValidateAfterIdleMs`) and read-replica settings (`replicas`,
`replicaStickinessMs`, `replicaRetryMs`) are filled from the configuration map
by reflection in `initialize`, which then opens the data source — and its
replicas, if any ([Read Replicas](#read-replicas)).

**Connections come from a `TomConnectionPool`.** A transaction gets a
connection of its own: its first statement on this data source enlists the data
source in it and takes a connection from the pool, every later statement of the
transaction runs on that connection, and `endTransaction` hands it back. A
statement outside any transaction borrows a connection for that statement
alone. Concurrent transactions therefore run side by side, and wait only when
all `poolMaxSize` connections are lent — for at most `poolAcquireTimeoutMs`,
after which the statement fails with `error.datasource.pool.acquire_timeout`.

**A data source is opened explicitly — by `initialize(settings)`, or by setting
the fields and calling `connect()` — and never by the statement that wants to
run.** Opening creates the pool and opens its first connection, so a data
source that cannot reach its database fails where it was opened. All execution
entry points (`prepareStatement`, `executeQuery`, `executeCommand`, `withLink`)
require an open data source and throw the driver's `datasourceException`
(`error.datasource.not_opened`, naming the entry point in the `operation`
parameter and the state that refused it in `state`) when reached without one.
Opening on demand is not offered because it could not work: the pool opens
connections with `host`, `port` and the credentials, so before they are
configured it would dial `:-1`, reporting an unreachable database where the
truth is an unconfigured one.

`executeQuery` and `executeCommand` take one statement each and refuse more with
`error.datasource.multiple_statements` (parameters `operation`, `statements`,
`command`) before touching a connection: MariaDB's client reads only the first
reply of a multi-statement command and leaves the rest to answer the next calls
on the same connection, and PostgreSQL's extended protocol refuses a second
statement outright. The check is quote- and comment-aware, so a terminating
`;` or one inside a literal is not a separator.

`close()` closes the pool **and lets go of it**, so a closed data source is
not-open and refuses statements (`state: "closed"`) exactly as one that was
never opened does (`state: "never_opened"`) — re-opening it by itself would
resurrect a data source the application deliberately let go. A connection that
drops is replaced: the pool checks a connection before lending it, discards one
that is down and opens a new one.

Members marked *(protected)* are `@protected`: they are what a driver supplies
or calls, not part of the surface an application reaches for.

- **Implements:** `TomDataSource`

##### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `integerSettings` | `Set<String>` | `const`: the settings a driver binds to `int` fields — `port`, `timeOut`, `replicaStickinessMs`, `replicaRetryMs` and the six `pool…` settings. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `username` | `String` | The connection user name. |
| `password` | `String` | The connection password. |
| `host` | `String` | The database host. |
| `port` | `int` | The database port (`-1` until configured; a driver may set its own default). |
| `databaseName` | `String` | The database name (empty selects no default database where the server allows that). |
| `timeOut` | `int` | The connect timeout in milliseconds. Default `10000`. |
| `poolMaxSize` | `int` | The most connections the pool opens at once. Default `10`. |
| `poolMinIdle` | `int` | How many idle connections the pool keeps open past the idle timeout. Default `0`. |
| `poolAcquireTimeoutMs` | `int` | How long a statement waits for a free connection, in milliseconds. Default `30000`. |
| `poolIdleTimeoutMs` | `int` | How long a connection may sit idle before it is closed, in milliseconds. Default `600000`. |
| `poolMaxLifetimeMs` | `int` | How long a connection is used at all before it is replaced, in milliseconds. Default `1800000`. |
| `poolValidateAfterIdleMs` | `int` | How long a connection may sit idle and still be lent without a check, in milliseconds. Default `30000`. |
| `replicas` | `List<Object?>` | The read replicas: one settings map per replica, each overriding this data source's own settings — usually only `host` and `port`. Empty — the default — routes everything to this data source. `initialize` refuses anything but a list of maps with `error.initialize.invalid_replicas` (parameter `replicas`). |
| `replicaStickinessMs` | `int` | How long after a principal's write (per tenant) its reads stay on the primary rather than a replica — read-your-writes, remembered per process. Default `5000`. |
| `replicaRetryMs` | `int` | How long a replica that failed to serve a connection is left out; its reads go to the primary meanwhile. Default `30000`. |
| `poolSettings` | `TomConnectionPoolSettings` | *(getter)* The pool settings the six `pool…` fields describe; read when the data source is opened. |
| `registeredName` | `String` | *(getter)* The name this data source is registered under — `app`, or `app@tenant` for a tenant's own pool — which is the `datasource` label of its metrics; `driverLabel` until `registerAs` names it. |
| `driverLabel` | `String` | *(getter, protected, abstract)* How the driver names itself in messages — `MariadbDatasource`, `PostgresDatasource`. |
| `preparedStatementLabel` | `String` | *(getter, protected, abstract)* How the driver's prepared statements name themselves in messages. |
| `participantPrefix` | `String` | *(getter, protected, abstract)* The prefix of `getParticipantId` — `MariaDb`, `Postgres`. |
| `commitStatement` | `String` | *(getter, protected, abstract)* The statement committing a one-phase transaction. |
| `rollbackStatement` | `String` | *(getter, protected, abstract)* The statement rolling a one-phase transaction back. |
| `replicaSources` | `List<TomSqlDatasource>` | *(getter)* The replicas, one per `replicas` entry, each registered as `<registeredName>.replica<n>`; empty until the data source is opened. |
| `connected` | `bool` | *(getter)* Whether the data source is open and at least one of its connections is established. |
| `openConnectionCount` | `int` | *(getter)* How many connections the pool holds, lent or idle; `0` when not open. |
| `lentConnectionCount` | `int` | *(getter)* How many connections are lent out — to transactions or statements. |
| `pooledLinks` | `Iterable<TomSqlLink>` | *(getter, protected)* Every connection of the pool, lent or idle; empty when not open. |

##### Methods — what a driver supplies

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `datasourceException` | `TomServerException datasourceException(String key, String message, {Map<String, dynamic>? parameters, StackTrace? stack, Object? rootException, bool autoLog = false})` | *(protected)* The exception this driver throws, carrying `key` — a `TomSqlDatasourceException` unless the driver narrows it (`MariadbDatasourceException`, `PostgresDatasourceException`). Every refusal the base raises goes through it, so a log names the database. |
| `connectionLostException` | `TomServerException connectionLostException(String key, String message, {Map<String, dynamic>? parameters, StackTrace? stack, Object? rootException})` | *(protected)* The retry signal this driver raises for a statement whose connection was lost; see `TomSqlConnectionLostException`. |
| `openLink` | `Future<TomSqlLink> openLink()` | *(protected, abstract)* Opens one new connection with the configured settings. |
| `closeLink` | `Future<void> closeLink(TomSqlLink link)` | *(protected, abstract)* Closes `link`; a failure is the driver's to log. |
| `tryLockOn` | `Future<bool> tryLockOn(TomSqlLink link, String name)` | *(protected, abstract)* Tries **once**, without waiting, to take the session lock `name` on `link`; `true` when this session now holds it. The lock belongs to that connection's session, and the database must release it when the session ends — closed, or lost with the process that held it. `GET_LOCK(name, 0)` on MariaDB, `pg_try_advisory_lock(hashtextextended(name, 0))` on PostgreSQL. |
| `unlockOn` | `Future<void> unlockOn(TomSqlLink link, String name)` | *(protected, abstract)* Releases the session lock `name` that `tryLockOn` took on `link`. `RELEASE_LOCK` on MariaDB, `pg_advisory_unlock` on PostgreSQL. |
| `validateLink` | `Future<bool> validateLink(TomSqlLink link)` | *(protected, abstract)* Whether `link` still answers a trivial statement. |
| `runPreparedOn` | `Future<TomSqlResult> runPreparedOn(TomSqlLink link, String command, List<Object?> parameters)` | *(protected, abstract)* Runs the positional `command` with `parameters` on `link` as a prepared statement, preparing it on that connection on first use. |
| `runCommandOn` | `Future<TomSqlResult> runCommandOn(TomSqlLink link, String command, Map<String, Object?>? params)` | *(protected, abstract)* Runs the named-parameter `command` with `params` (already marshalled by `tomSqlBindParams`) on `link`. |
| `forgetStatementOn` | `void forgetStatementOn(TomSqlLink link, String command)` | *(protected, abstract)* Forgets `command`'s server-side statement on `link`; the driver frees it when `releaseForgottenOn` runs. |
| `releaseForgottenOn` | `Future<void> releaseForgottenOn(TomSqlLink link)` | *(protected, abstract)* Frees the statements forgotten on `link` while it was out, before it goes back to the pool. |
| `isLostConnection` | `bool isLostConnection(Object error, TomSqlLink link)` | *(protected, abstract)* Whether `error` means `link` was lost while the statement ran, so a retry on another connection may recover it. Both drivers answer with `isLostConnectionFailure`. |
| `beginStatement` | `String beginStatement({required bool readOnly})` | *(protected, abstract)* The statement opening a transaction, read-only when `readOnly`. |
| `toPositional` | `(String, List<String>) toPositional(String namedSql)` | *(abstract)* Translates the generated `:name` `namedSql` into the positional form this driver's protocol binds, returning the SQL and the placeholder names in slot order. |
| `prepareOn` | `Future<void> prepareOn(TomSqlLink link, String command, int parameterCount)` | *(protected, abstract)* Prepares `command`, which binds `parameterCount` parameters, on `link` without running it. `MariaDbDatasource` skips the prepare when `parameterCount` is `0` and the statement answers no rows (it does not start with `SELECT`, `WITH`, `SHOW` or a bracket), and runs such a statement over the text protocol in `runPreparedOn`, because the server answers the `PREPARE` of a statement with neither parameters nor result columns in a way `mysql_client` waits on forever; that statement's errors surface when it runs. |
| `newPreparedStatement` | `TomSqlPreparedStatement<T> newPreparedStatement<T extends Object>(List<String> parameterList, Type? resultType, String command, Map<String, Type>? groupedProjection)` | *(protected)* The prepared-statement handle this driver hands out — a `TomSqlPreparedStatement` unless the driver returns its own subtype. |
| `bindSettings` | `void bindSettings(Map<String, dynamic> settings)` | *(protected, abstract)* Binds `settings` onto the driver's fields by reflection. |
| `newReplica` | `TomSqlDatasource newReplica()` | *(protected, abstract)* A new, unconfigured data source of this driver, to serve as a replica. It is bound with this data source's settings overlaid by the replica's map. |
| `normalizeSettings` | `Map<String, dynamic> normalizeSettings(Map<String, dynamic> settings)` | *(protected)* Returns `settings` with every `integerSettings` value given as a string folded to an `int`, so an environment substitution (`port: ${DB_PORT:3306}`) binds. The port is parsed by `parseConfiguredPort`; any other value that is not an integer throws `error.initialize.invalid_integer` (parameters `setting` and `value`). A map with no string-valued integer setting is returned unchanged. |
| `parseConfiguredPort` | `int parseConfiguredPort(Object? raw)` | *(protected)* Parses a configured port value — an `int`, or a `String` holding one — into the `int` the driver binds; anything else throws `error.initialize.invalid_port`. |

##### Methods — opening, running, mapping

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `registerAs` | `void registerAs(String name)` | Records the registry name `registeredName` reports. Called by `TomDataSourceInfo.initialize` when it creates the driver, before the data source is opened; a data source created by hand calls it to be labelled. |
| `connect` | `Future<void> connect()` | Opens the data source: creates the pool from `poolSettings` and opens its first connection, then its replicas — a replica that cannot be reached is left out for `replicaRetryMs`, not fatal. A server that cannot be reached or refuses the session fails the call with the driver's own error and leaves the data source unopened. Does nothing on an open data source. |
| `withLink` | `Future<R> withLink<R>(String operation, Future<R> Function(TomSqlLink link) body, {String? statement})` | *(protected)* Runs `body` on the connection `operation` belongs on — the one place connections are chosen. `statement`, the SQL a statement path runs, is what read-replica routing reads: a repository read of it in read-only work may run on a replica, a replica that cannot lend a connection is left out for `replicaRetryMs` and the statement runs here, and a statement that is not a read records the principal's write for `replicaStickinessMs`. Otherwise: a transaction's own lifecycle statement runs on the connection pinned to that transaction; a statement inside a running transaction first enlists this data source in it, then runs on the transaction's connection; any other statement borrows a connection for itself and hands it back, discarding it if it went down while in use. |
| `prepareStatement` | `Future<TomPreparedStatement<T>> prepareStatement<T extends Object>(TomQuery query, [Type? resultType])` | *(override)* Renders `query` through `sqlDialect`, translates it with `toPositional`, and prepares it on the connection the current zone selects, so a statement the server cannot compile fails here. A grouped query's `projectionTypes` travel with the returned handle. |
| `mapGroupedRow` | `TomGroupedRow mapGroupedRow(TomSqlRow row, Map<String, Type> projection)` | Maps one row of a grouped result, reading each alias as the Dart type the query declared for it. Throws `error.result_processing_grouped.unknown_type` for a declared type outside `int` / `double` / `String` / `bool` / `DateTime`. |
| `executeQuery` | `Future<List<T>> executeQuery<T extends Object>(String command, [Map<String, dynamic>? params, Type? resultType])` | *(override)* Runs a read command with reflection-based row→object mapping. A `TomClass` result type maps by observable member — by member name without `@TomDbTable`, by `@TomDbColumn` with it — supporting `int` / `double` / `String` / `bool` / `DateTime` members whether declared as the plain or the nullable (`TomN…`) observable, with a SQL `NULL` read as `null`. The rows are mapped after the connection is handed back, so a `@TomReference` column's own query never needs a second connection while the first is held. |
| `mapSqlResult` | `Future<List<T>> mapSqlResult<T extends Object>(TomSqlResult result, [Type? resultType, Map<String, Type>? groupedProjection])` | Maps `result` onto a list of `T`, choosing between the five row shapes: a grouped row (when `groupedProjection` is given), a table-less `TomClass` bound by member name, an annotated `TomClass` bound by `@TomDbColumn`, a plain reflected holder bound by declared field name, and an annotated entity bound by its persistent columns. A column the result does not carry is skipped on every shape. Throws `error.result_processing.unsuitable_class` for a result type the reflector does not hold. Needs no open connection — only a `@TomReference` column reaches back to the database. |
| `initialize` | `Future<void> initialize(Map<String, dynamic> settings)` | *(override)* `bindSettings(normalizeSettings(settings))` for every setting but `replicas`, which it reads into `replicas` — refusing anything but a list of maps with `error.initialize.invalid_replicas` — then `connect()`. |
| `isOperational` | `bool isOperational()` | *(override)* Whether the data source is open and can reach its database: open, and either holding a live connection or — holding none — having opened the last one it tried. |
| `executeCommand` | `Future<BigInt> executeCommand(String command, [Map<String, dynamic>? params])` | *(override)* Runs a write command and returns the affected-row count. |
| `close` | `Future<void> close()` | *(override)* Closes the pool and lets go of it, and closes the replicas. Idle connections are closed at once; a connection still lent — to a transaction or a running statement — is closed when it is handed back. A connection that fails to close is logged and dropped, never thrown. A data source that was never opened has nothing to release and stays "never opened". |
| `toString` | `String toString()` | *(override)* `<driverLabel> host:port/database` and its state: `open (N lent, M idle)` while it is open, and otherwise which of the two ways it came to hold no pool — `closed` or `never opened`. |
| `getParticipantId` | `String getParticipantId()` | *(override)* `<participantPrefix>-<database>@<host>:@<port>` — the database this source speaks to, so two instances configured for one database enlist once. |
| `withSessionLock` | `Future<R> withSessionLock<R>(String name, Future<R> Function() body, {Duration wait = const Duration(minutes: 10), Duration poll = const Duration(milliseconds: 250)})` | Runs `body` while this process holds the database-wide session lock `name`, trying `tryLockOn` every `poll` for up to `wait` and then throwing `error.datasource.session_lock_timeout` (parameters `lock` and `waitMs`). The lock is taken on a connection of its own, opened through `openLink` beside the pool and closed when `body` ends, so it is released when `body` returns, when it throws, and by the database when the process dies. `body`'s statements run on the pool as usual — a mutual exclusion between processes, not a transaction. Re-entrant within the zone per `host:port/databaseName` and `name`: a `body` asking for the same lock again runs without waiting for itself. The migration lock is built on it. |

##### Methods — transactions

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `branchOf` | `TomSqlBranch? branchOf(TomTransaction transaction)` | *(protected)* `transaction`'s branch on this data source, or `null`. |
| `lifecycle` | `Future<BigInt> lifecycle(TomTransaction transaction, String command)` | *(protected)* Issues one of `transaction`'s own lifecycle statements on its pinned connection, without enlisting anything. Routed through `executeCommand`, so there stays one way a command reaches a connection. |
| `refuseNestedTransaction` | `Never refuseNestedTransaction([String? transactionId])` | *(protected)* Throws `error.transaction.already_active` (parameter `participant`, and `transactionId` when a two-phase branch is open) — a second start of a transaction this data source is already in. |
| `startTransaction` | `Future<bool> startTransaction(TomTransaction transaction)` | *(override)* Opens `transaction` on a connection of its own with `beginStatement` (read-only for a read-only transaction). Returns `false`, and hands the connection back, when the database refuses it; **throws** `error.transaction.already_active` when the same transaction starts it twice — a caller mistake no retry fixes. Another transaction is not refused. Normally reached through the data source's own enlistment at the point of use. |
| `openBranch` | `TomSqlBranch openBranch(TomTransaction transaction, TomSqlBranch? existing)` | *(protected)* The branch `transaction` starts on: `existing`, when the transaction ran on this data source before and was concluded, keeping its connection — otherwise a new one. |
| `abandonStart` | `Future<void> abandonStart(TomTransaction transaction, TomSqlBranch branch, TomSqlBranch? existing)` | *(protected)* Undoes a start that failed: a new branch is forgotten with its connection, a reused one is left as it was. |
| `endTransaction` | `Future<bool> endTransaction(TomTransaction transaction)` | *(override)* Issues nothing and always succeeds: it hands `transaction`'s connection back to the pool. The coordinator calls it on every participant after either conclusion. |
| `prepare` | `Future<bool> prepare(TomTransaction transaction)` | *(override)* Returns `true`: a one-phase transaction has no statement that makes a commit certain without performing it. |
| `commit` | `Future<bool> commit(TomTransaction transaction)` | *(override)* Issues `commitStatement` on `transaction`'s connection. |
| `rollback` | `Future<bool> rollback(TomTransaction transaction)` | *(override)* Issues `rollbackStatement` on `transaction`'s connection and reports whether it was undone. |

Numeric columns are read from their text and parsed, never through a driver's
typed accessor: MariaDB types `SUM`/`AVG` over an integer column — and every
`DECIMAL` column — as `NEWDECIMAL`, which `mysql_client` will not convert to a
number, and the text form parses losslessly on every driver. An `int`-declared
field over a `DECIMAL` column is read when the value is exactly integral and
refused by name (`error.result_processing.fractional_int`) when it is not —
never silently truncated.

#### TomSqlPreparedStatement&lt;T&gt;

A `TomPreparedStatement` of a `TomSqlDatasource`: the compiled `command`, the
ordered `parameterList` its placeholders expect, the owning `datasource`, and
the optional `resultType`.

The handle belongs to no connection. A server-side prepared statement lives on
one connection, while a pooled data source runs each execution on whichever
connection it is given — the transaction's, or one lent for the statement — so
every pooled connection prepares `command` the first time it runs it and keeps
the server-side statement for the next. A repository can therefore prepare a
statement once and keep it for the life of the process.

- **Extends:** `TomPreparedStatement<T>`
- **Type Parameters:** `T extends Object` — the mapped result row type.

##### Constructors

```dart
TomSqlPreparedStatement(
  List<String> parameterList,
  TomSqlDatasource datasource,
  Type? resultType,
  String command, {
  Map<String, Type>? groupedProjection,
})
```

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `buildPositionalParameters` | `static List<Object?> buildPositionalParameters(List<String> parameterList, Map<String, Object?>? params)` | Maps named `params` onto the positional bind list in placeholder order, each through `tomSqlBindValue`. Values are taken raw — a Dart `null` binds SQL `NULL`, a `String` keeps its exact characters — never rendered through `objectOp`, which would double-encode them. Returns an empty list when `params` is `null`. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `TomSqlDatasource` | The data source that prepared and runs this statement. |
| `parameterList` | `List<String>` | The placeholder names in positional order. |
| `resultType` | `Type?` | The type result rows are mapped to (defaults to `T`). |
| `command` | `String` | The compiled SQL command, prepared on each connection that runs it. |
| `groupedProjection` | `Map<String, Type>?` | For a grouped query, the Dart type of each projected result column keyed by its alias; `null` for every other statement. The types travel with the statement because a grouped row is not an entity. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `execute` | `Future<List<T>> execute([Map<String, Object?>? params])` | *(override)* The rows of `run(params)`. |
| `run` | `Future<TomStatementOutcome<T>> run([Map<String, Object?>? params])` | *(override)* Runs the statement on the connection the current zone selects, preparing it there on first use, and reports the rows, the affected-row count and the generated key — all three from this execution's own result. A connection found gone (the driver raised its `connectionLostException`) is retried once, on another connection, outside a transaction, and the outcome is the retry's; inside a transaction there is nothing to retry on, and the failure is `error.failed-to-execute.transaction_connection_lost`. |
| `deallocate` | `Future<void> deallocate()` | *(override)* Forgets the statement on every connection that prepared it; each frees its server-side statement the next time it is handed back, so nothing is freed under a statement that is running. |

#### TomSqlRow

One row of a statement's result, every column read as text in the convention
described under [The SQL Driver Base](#the-sql-driver-base).

- **Kind:** `abstract interface class`

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `text` | `String? text(String column)` | `column` as text, or `null` for SQL `NULL`. |
| `temporalText` | `String? temporalText(String column)` | `column` as the text of a temporal value — an instant, a date or a time. Separate from `text` because a driver may have to repair what its protocol renders for a temporal column specifically (MariaDB's binary protocol writes the microsecond field as a bare integer), and must not touch a text column that only happens to look like one. |
| `boolean` | `bool? boolean(String column)` | `column` as a truth value: `1`/`0` and `true`/`false` alike. |

#### TomSqlResult

What a statement produced: its rows, the rows it changed, and the key it
generated. An interface so a driver can answer it lazily — reading its own
result only for what the statement's caller asks — and `TomSqlResultValues` for
one that holds the values outright.

- **Kind:** `abstract interface class`

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `columns` | `List<String>` | *(getter)* The result columns, in order. |
| `rows` | `List<TomSqlRow>` | *(getter)* The rows. |
| `affectedRows` | `int` | *(getter)* How many rows the statement changed. |
| `generatedId` | `int?` | *(getter)* The key the statement generated, or `null` when it generated none. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `hasColumn` | `bool hasColumn(String name)` | Whether the result carries a column called `name`. |

#### TomSqlResultValues

A `TomSqlResult` holding its values.

- **Implements:** `TomSqlResult`

##### Constructors

```dart
TomSqlResultValues({
  List<String> columns = const [],
  List<TomSqlRow> rows = const [],
  int affectedRows = 0,
  int? generatedId,
  bool caseInsensitiveColumns = false,
})
```

With `caseInsensitiveColumns`, `hasColumn` ignores case — for a database that
folds unquoted identifiers, where `SELECT x AS dueAt` answers a column called
`dueat`. The PostgreSQL driver builds its results this way.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `columns` | `List<String>` | *(override)* The result columns, in order. |
| `rows` | `List<TomSqlRow>` | *(override)* The rows. |
| `affectedRows` | `int` | *(override)* How many rows the statement changed. |
| `generatedId` | `int?` | *(override)* The key the statement generated, or `null`. |
| `caseInsensitiveColumns` | `bool` | Whether column names compare without regard to case. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `hasColumn` | `bool hasColumn(String name)` | *(override)* Whether the result carries a column called `name`, case-insensitively when `caseInsensitiveColumns` is set. |

#### TomSqlLink

One pooled connection of a `TomSqlDatasource`. Each driver extends it privately
with its own driver connection and the server-side statements prepared on it.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `connected` | `bool` | *(getter, abstract)* Whether the connection is still established. |

#### TomSqlBranch

One transaction's share of a data source: the pooled connection pinned to it,
and — for a two-phase driver — the branch it opened. Held by the data source
from the transaction's first statement to `endTransaction`.

##### Constructors

```dart
TomSqlBranch()
```

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `link` | `Future<TomSqlLink>?` | The connection, acquired by the transaction's first statement and held until `TomSqlDatasource.endTransaction`. |
| `started` | `Completer<bool>` | Completes with whether the transaction's start succeeded; a statement racing the start waits for it. |
| `active` | `bool` | Whether the transaction is open on the connection: started, and not yet committed or rolled back. A second start is refused only while it is. |
| `xaId` | `String?` | The two-phase branch id, quoted; `null` on a one-phase driver. |
| `ended` | `bool` | Whether a two-phase branch has left its active state — `XA END`ed on MariaDB, `PREPARE TRANSACTION`ed on PostgreSQL. |

#### TomSqlTwoPhaseRecovery

A mixin on `TomSqlDatasource` giving a two-phase driver its part in recovering
prepared branches (see
[transactions.md](../transactions.md#recovering-prepared-branches)): as a
`TomPreparedBranchHolder` it answers the branch it prepared for a transaction,
which the coordinator records; as a `TomTwoPhaseRecoverable` it lists its
database's prepared branches and commits or rolls back one by id. A driver
supplies the four statements; the listing, the ownership and age checks, the
character check and the quoting are the mixin's. `MariaDbXADatasource` and
`PostgresXADatasource` mix it in.

- **Mixin on:** `TomSqlDatasource`
- **Implements:** `TomPreparedBranchHolder`, `TomTwoPhaseRecoverable`

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `listPreparedSql` | `String` | *(getter, protected, abstract)* The statement listing the prepared branches. |
| `preparedIdColumn` | `String` | *(getter, protected, abstract)* The column of `listPreparedSql` holding a branch id. |
| `recoveryLabel` | `String` | *(getter, override)* `<driver> <host>:<port>/<database>`, naming the data source in a recovery's report and log lines. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `commitPreparedSql` | `String commitPreparedSql(String quotedId)` | *(protected, abstract)* The statement committing the prepared branch `quotedId`. |
| `rollbackPreparedSql` | `String rollbackPreparedSql(String quotedId)` | *(protected, abstract)* The statement rolling the prepared branch `quotedId` back. |
| `preparedBranchOf` | `String? preparedBranchOf(TomTransaction transaction)` | *(override)* The branch id of `transaction` (`TomSqlBranch.xaId`), unquoted, or `null` when the data source holds no branch for it. |
| `listPreparedBranches` | `Future<List<String>> listPreparedBranches()` | *(override)* Runs `listPreparedSql` on a pooled connection and reads `preparedIdColumn` of every row. |
| `ownsBranch` | `bool ownsBranch(String branchId)` | *(override)* `tomSqlOwnsBranch` with this data source's `databaseName`, `host` and `port`. |
| `branchOpenedAt` | `DateTime? branchOpenedAt(String branchId)` | *(override)* `tomSqlBranchOpenedAt(branchId)`. |
| `commitPreparedBranch` | `Future<void> commitPreparedBranch(String branchId)` | *(override)* Runs `commitPreparedSql` over the quoted id. An id with a character `tomSqlBranchId` does not write is refused with `error.datasource.invalid_branch_id` before any statement runs. |
| `rollbackPreparedBranch` | `Future<void> rollbackPreparedBranch(String branchId)` | *(override)* Runs `rollbackPreparedSql` over the quoted id, refusing an id the same way. |

### The MariaDB Driver

#### MariaDbDatasource

A MariaDB / MySQL `TomDataSource` driver (registered for the `"mariadb"` type),
over `mysql_client`. Everything that does not depend on the database — the pool,
the lifecycle, the statement paths, the row mapping — is inherited from
`TomSqlDatasource`; what is declared here is the wire. Transactions are plain
`START TRANSACTION` / `COMMIT` / `ROLLBACK`; `MariaDbXADatasource` is the
two-phase variant.

- **Extends:** `TomSqlDatasource`

##### Constructors

```dart
MariaDbDatasource()
```

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toPositionalStatement` | `static (String, List<String>) toPositionalStatement(String namedSql)` | Translates generated `:name` SQL into the positional `?` form the MySQL binary protocol binds, returning the rewritten SQL and placeholder names in order. Delegates to `SqlPlaceholderScan.toPositional`. |
| `normalizeIntegerSettings` | `static Map<String, dynamic> normalizeIntegerSettings(Map<String, dynamic> settings)` | Returns `settings` with every `TomSqlDatasource.integerSettings` value given as a string folded to an `int`. The port is parsed by `parsePort`; any other value that is not an integer throws `MariadbDatasourceException` (`error.initialize.invalid_integer`, parameters `setting` and `value`). A map with no string-valued integer setting is returned unchanged. |
| `parsePort` | `static int parsePort(Object? raw)` | Parses a configured port value into the `int` the driver binds; throws `MariadbDatasourceException` (`error.initialize.invalid_port`) when unparsable. |

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `sqlDialect` | `TomStandardSqlDialect` | *(override)* The MariaDB SQL dialect, a `MariadbSqlDialect`. |
| `driverLabel` | `String` | *(override)* `MariadbDatasource`. |
| `preparedStatementLabel` | `String` | *(override)* `MariadbPreparedStatement`. |
| `participantPrefix` | `String` | *(override)* `MariaDb`. |
| `commitStatement` | `String` | *(override)* `COMMIT;`. |
| `rollbackStatement` | `String` | *(override)* `ROLLBACK;`. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `datasourceException` | `MariadbDatasourceException datasourceException(String key, String message, {Map<String, dynamic>? parameters, StackTrace? stack, Object? rootException, bool autoLog = false})` | *(override)* Every refusal of this driver is a `MariadbDatasourceException`. |
| `connectionLostException` | `MariadbPreparedStatementException connectionLostException(String key, String message, {Map<String, dynamic>? parameters, StackTrace? stack, Object? rootException})` | *(override)* The retry signal is a `MariadbPreparedStatementException`. |
| `openConnection` | `Future<MySQLConnection> openConnection()` | Opens one new `MySQLConnection` with the configured settings (no default database when `databaseName` is empty). The pool calls it, through `openLink`, whenever it needs a connection; a driver test overrides it to hand out stand-in connections. |
| `openLink` | `Future<TomSqlLink> openLink()` | *(override)* Wraps `openConnection()` as a pooled link. |
| `closeLink` | `Future<void> closeLink(TomSqlLink link)` | *(override)* Closes the link's connection; a failure is logged, never thrown. |
| `tryLockOn` | `Future<bool> tryLockOn(TomSqlLink link, String name)` | *(override)* `SELECT GET_LOCK(:name, 0)` on the link's connection — `true` when it answers `1`. A MariaDB lock name is server-wide and at most 64 characters. |
| `unlockOn` | `Future<void> unlockOn(TomSqlLink link, String name)` | *(override)* `SELECT RELEASE_LOCK(:name)` on the link's connection. |
| `validateLink` | `Future<bool> validateLink(TomSqlLink link)` | *(override)* `SELECT 1` on the link's connection. |
| `withDriverConnection` | `Future<R> withDriverConnection<R>(Future<R> Function(MySQLConnection connection) body)` | Runs `body` with the driver connection a statement would use: the running transaction's when this data source is enlisted in one, otherwise one lent for the call and handed back when `body` completes. For the driver's own API — its typed row accessors, or a session-scoped lock taken and released on one connection. The connection must not be kept beyond `body`. |
| `prepareOn` | `Future<void> prepareOn(TomSqlLink link, String command)` | *(override)* Prepares `command` on the link's connection, keeping the server-side statement for later runs. |
| `runPreparedOn` | `Future<TomSqlResult> runPreparedOn(TomSqlLink link, String command, List<Object?> parameters)` | *(override)* Executes the link's prepared statement for `command`, preparing it on first use. A temporal value's fraction read over the binary protocol is repaired to six digits (`temporalText`). |
| `runCommandOn` | `Future<TomSqlResult> runCommandOn(TomSqlLink link, String command, Map<String, Object?>? params)` | *(override)* Executes `command` over the text protocol with named `params`. |
| `forgetStatementOn` | `void forgetStatementOn(TomSqlLink link, String command)` | *(override)* Moves the link's statement for `command` to its pending-deallocation list. |
| `releaseForgottenOn` | `Future<void> releaseForgottenOn(TomSqlLink link)` | *(override)* Deallocates the link's pending statements; a failure is logged. |
| `isLostConnection` | `bool isLostConnection(Object error, TomSqlLink link)` | *(override)* `isLostConnectionFailure(error, connected: link.connected)`. |
| `beginStatement` | `String beginStatement({required bool readOnly})` | *(override)* `START TRANSACTION READ ONLY;` or `START TRANSACTION;`. |
| `toPositional` | `(String, List<String>) toPositional(String namedSql)` | *(override)* `toPositionalStatement(namedSql)` — the `?` form. |
| `mapResultSet` | `Future<List<T>> mapResultSet<T extends Object>(IResultSet qResult, [Type? resultType, Map<String, Type>? groupedProjection])` | Maps a `mysql_client` result set onto a list of `T` through `mapSqlResult` — the driver's own result type adapted to the shared mapper. Needs no open connection. |
| `newPreparedStatement` | `TomSqlPreparedStatement<T> newPreparedStatement<T extends Object>(List<String> parameterList, Type? resultType, String command, Map<String, Type>? groupedProjection)` | *(override)* Hands out a `MariadbPreparedStatement`. |
| `bindSettings` | `void bindSettings(Map<String, dynamic> settings)` | *(override)* Binds `settings` onto this driver's fields by reflection. |
| `newReplica` | `TomSqlDatasource newReplica()` | *(override)* A plain `MariaDbDatasource` — one-phase even behind an XA primary, since a replica only ever serves reads. |
| `normalizeSettings` | `Map<String, dynamic> normalizeSettings(Map<String, dynamic> settings)` | *(override)* `normalizeIntegerSettings(settings)`. |
| `parseConfiguredPort` | `int parseConfiguredPort(Object? raw)` | *(override)* `parsePort(raw)`. |

#### MariaDbXADatasource

A MariaDB `TomDataSource` that uses XA (distributed) transactions (registered
for the `"mariadb_xa"` type). Inherits connection and execution behaviour from
`MariaDbDatasource` but overrides the transaction lifecycle to issue `XA`
commands. `endTransaction` is the inherited one: it issues nothing and hands the
connection back, exactly as the one-phase sibling's does, because every XA
statement belongs to `prepare`, `commit` and `rollback`.

Its prepared branches are recovered through `TomSqlTwoPhaseRecovery`: `XA
RECOVER` lists them — every database's on the server, the id in the `data`
column, of which `ownsBranch` keeps this database's — and `XA COMMIT '<id>'` /
`XA ROLLBACK '<id>'` resolve one.

- **Extends:** `MariaDbDatasource`
- **Mixes in:** `TomSqlTwoPhaseRecovery`

##### Constructors

```dart
MariaDbXADatasource()
```

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `startTransaction` | `Future<bool> startTransaction(TomTransaction transaction)` | *(override)* Takes a connection for `transaction` as the base class does, then issues `XA START` against a fresh branch id kept with that transaction, so concurrent XA transactions are separate branches. Throws the same `error.transaction.already_active` as the base class — with the open branch in the `transactionId` parameter — if the same transaction starts it twice. Clears the id and hands the connection back when the command fails, since the database never opened that branch. `XA START` has no read-only form, so a read-only transaction is logged as unprotected rather than refused. |
| `prepare` | `Future<bool> prepare(TomTransaction transaction)` | *(override)* Issues `XA END` and then `XA PREPARE` on `transaction`'s branch, as two calls. Keeps the branch id on failure, because a `false` is a veto and the rollback that follows needs the branch to name. |
| `commit` | `Future<bool> commit(TomTransaction transaction)` | *(override)* Issues `XA COMMIT` against `transaction`'s prepared branch and clears the id. On failure the branch is in doubt, and the id is kept so it has a name. |
| `rollback` | `Future<bool> rollback(TomTransaction transaction)` | *(override)* Issues `XA END` then `XA ROLLBACK` for a branch still active, and `XA ROLLBACK` alone for one already ended — idle after a refused `XA PREPARE`, or prepared — because the server refuses each statement in the other's state. Clears the branch id either way and reports whether the branch was undone. Issues nothing when there is no branch, which is the state a participant is in when it committed before someone else vetoed. |

##### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `maxBranchIdBytes` | `int` | `const`, `64`: the most bytes an XA `gtrid` may hold. The branch id is built by `tomSqlBranchId` and bounded to it. |

Every exit clears the branch id except a failing `prepare` or `commit`. The id
is also the guard `startTransaction` refuses a second start of the same
transaction on, so a start the database refused clears it as well: kept, it
would refuse every later start of that transaction — and a caller cannot clear
it by rolling back, having been told the transaction did not begin.

The statements follow the coordinator's two phases, and cannot be arranged any
other way: `TomTransaction.commitTransaction` drains its `commit` loop before
it calls `endTransaction` on anyone, so a prepare in `endTransaction` would
run after the commit it is a precondition of — the server would refuse that
commit, the `false` would read as a veto, and the transaction would become a
rollback with the branch left ACTIVE holding its locks.

#### MariadbPreparedStatement&lt;T&gt;

The MariaDB driver's `TomSqlPreparedStatement`. Execution, the retry after a
lost connection and deallocation are the base class's; what is declared here is
the constructor narrowed to a `MariaDbDatasource` and the two static helpers.

- **Extends:** `TomSqlPreparedStatement<T>`
- **Type Parameters:** `T extends Object` — the mapped result row type.

##### Constructors

```dart
MariadbPreparedStatement(
  List<String> parameterList,
  MariaDbDatasource super.datasource,
  Type? resultType,
  String command, {
  Map<String, Type>? groupedProjection,
})
```

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `normalizeGeneratedId` | `static int? normalizeGeneratedId(BigInt rawLastInsertId)` | Maps a driver-reported last-insert id into a generated key: `0` — what the driver reports when a statement generated no `AUTO_INCREMENT` value — becomes `null`, every other value passes through as an `int`. |
| `buildPositionalParameters` | `static List<Object?> buildPositionalParameters(List<String> parameterList, Map<String, Object?>? params)` | `TomSqlPreparedStatement.buildPositionalParameters`, under this class's name. |

### The PostgreSQL Driver

#### PostgresDatasource

A PostgreSQL 15+ `TomDataSource` driver (registered for the `"postgresql"`
type), over `package:postgres`. Like the MariaDB driver it inherits the pool,
the lifecycle, the statement paths and the row mapping from `TomSqlDatasource`;
what is declared here is the wire, and the reading of PostgreSQL's typed result
values into the text convention the shared mapper reads. Transactions are plain
`BEGIN` / `COMMIT` / `ROLLBACK`; `PostgresXADatasource` is the two-phase
variant.

Every session runs with `TimeZone` set to `UTC`, so a server-side
`CURRENT_TIMESTAMP` reads in the zone the framework writes instants in. Every
bind value is sent as text with an unspecified type, so PostgreSQL infers each
parameter's type from where it is used — the one marshalled `1` reads into a
`SMALLINT`, a `BOOLEAN` or an `INTEGER` alike. Result column names are matched
without regard to case, because PostgreSQL folds unquoted identifiers
(`SELECT x AS dueAt` answers `dueat`).

An `INSERT … RETURNING` that answers one row of one integer column reports that
integer as the statement's generated id — PostgreSQL has no last-insert id, so
the dialect's `returningKey` and `incrementCounter` ask for the key with
`RETURNING` and the driver reads it back. A prepared statement PostgreSQL
refuses with `cached plan must not change result type` (SQLSTATE `0A000`) — a
table that changed shape under a long-lived `SELECT *` — is dropped and
prepared again, once.

- **Extends:** `TomSqlDatasource`

##### Constructors

```dart
PostgresDatasource()
```

Sets `port` to PostgreSQL's default, `5432`.

##### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `sqlDialect` | `TomStandardSqlDialect` | *(override)* The PostgreSQL SQL dialect, a `PostgresSqlDialect`. |
| `schema` | `String` | The schema statements resolve unqualified names in — set as the session's `search_path` when a connection opens — or empty for the server's default (`public`). This is what a schema-isolated tenant is on PostgreSQL: one database, a schema per tenant. |
| `sslMode` | `String` | How the connection is encrypted: `disable`, `require` (encrypt, accept any certificate) or `verifyFull` (encrypt and verify). Default `require`. Any other value fails the first connection with `error.initialize.invalid_ssl_mode` (parameter `sslMode`). |
| `driverLabel` | `String` | *(override)* `PostgresDatasource`. |
| `preparedStatementLabel` | `String` | *(override)* `PostgresPreparedStatement`. |
| `participantPrefix` | `String` | *(override)* `Postgres`. |
| `commitStatement` | `String` | *(override)* `COMMIT`. |
| `rollbackStatement` | `String` | *(override)* `ROLLBACK`. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `datasourceException` | `PostgresDatasourceException datasourceException(String key, String message, {Map<String, dynamic>? parameters, StackTrace? stack, Object? rootException, bool autoLog = false})` | *(override)* Every refusal of this driver is a `PostgresDatasourceException`. |
| `connectionLostException` | `PostgresConnectionLostException connectionLostException(String key, String message, {Map<String, dynamic>? parameters, StackTrace? stack, Object? rootException})` | *(override)* The retry signal is a `PostgresConnectionLostException`. |
| `openLink` | `Future<TomSqlLink> openLink()` | *(override)* Opens a connection to `databaseName` (the `postgres` database when it is empty) with `sslMode`, the `timeOut` connect timeout and `TimeZone` `UTC`, then sets `search_path` to `schema` when one is configured. |
| `closeLink` | `Future<void> closeLink(TomSqlLink link)` | *(override)* Closes the link's connection; a failure is logged, never thrown. |
| `tryLockOn` | `Future<bool> tryLockOn(TomSqlLink link, String name)` | *(override)* `SELECT pg_try_advisory_lock(hashtextextended(:name, 0))` on the link's connection. An advisory lock takes a number, so the name is hashed into one with `hashtextextended`, alike on every node. |
| `unlockOn` | `Future<void> unlockOn(TomSqlLink link, String name)` | *(override)* `SELECT pg_advisory_unlock(hashtextextended(:name, 0))` on the link's connection. |
| `validateLink` | `Future<bool> validateLink(TomSqlLink link)` | *(override)* `SELECT 1` on the link's connection. |
| `prepareOn` | `Future<void> prepareOn(TomSqlLink link, String command)` | *(override)* Prepares `command` on the link's connection, keeping the server-side statement for later runs. |
| `runPreparedOn` | `Future<TomSqlResult> runPreparedOn(TomSqlLink link, String command, List<Object?> parameters)` | *(override)* Runs the link's prepared statement for `command`, preparing it on first use; a statement refused with SQLSTATE `0A000` (`cached plan must not change result type`) is disposed of and prepared again, once. |
| `runCommandOn` | `Future<TomSqlResult> runCommandOn(TomSqlLink link, String command, Map<String, Object?>? params)` | *(override)* Translates `command` with `toPositional` and runs it with the named `params` bound in slot order. |
| `forgetStatementOn` | `void forgetStatementOn(TomSqlLink link, String command)` | *(override)* Moves the link's statement for `command` to its pending-disposal list. |
| `releaseForgottenOn` | `Future<void> releaseForgottenOn(TomSqlLink link)` | *(override)* Disposes of the link's pending statements; a failure is logged. |
| `isLostConnection` | `bool isLostConnection(Object error, TomSqlLink link)` | *(override)* `isLostConnectionFailure(error, connected: link.connected)`. |
| `beginStatement` | `String beginStatement({required bool readOnly})` | *(override)* `BEGIN READ ONLY` or `BEGIN`. |
| `toPositional` | `(String, List<String>) toPositional(String namedSql)` | *(override)* `:name` placeholders to `$1`, `$2`, …, one slot per occurrence, with a backslash in a string literal read as PostgreSQL reads it — as itself. |
| `bindSettings` | `void bindSettings(Map<String, dynamic> settings)` | *(override)* Binds `settings` onto this driver's fields by reflection. |
| `newReplica` | `TomSqlDatasource newReplica()` | *(override)* A plain `PostgresDatasource` — one-phase even behind a `postgresql_xa` primary, since a replica only ever serves reads. |

#### PostgresXADatasource

A PostgreSQL `TomDataSource` taking part in two-phase commits (registered for
the `"postgresql_xa"` type). Inherits connection and execution behaviour from
`PostgresDatasource` and overrides the transaction lifecycle: `startTransaction`
issues `BEGIN`, `prepare` issues `PREPARE TRANSACTION '<id>'`, `commit` issues
`COMMIT PREPARED '<id>'`, and `rollback` issues `ROLLBACK` while the
transaction is still open or `ROLLBACK PREPARED '<id>'` once it has been
prepared. A prepared transaction survives a server restart and is resolved only
by those two statements — which is the promise the prepare phase asks every
participant for. `endTransaction` is the inherited one.

The server must allow prepared transactions: `max_prepared_transactions` above
zero. It is `0` by default, which makes every `PREPARE TRANSACTION` fail and so
vetoes every two-phase transaction this data source joins. Unlike MariaDB's
`XA START`, `BEGIN` has a read-only form, so a read-only transaction is
honoured here as on the one-phase driver.

Its prepared transactions are recovered through `TomSqlTwoPhaseRecovery`:
`SELECT gid FROM pg_prepared_xacts WHERE database = current_database()` lists
this database's, and `COMMIT PREPARED '<id>'` / `ROLLBACK PREPARED '<id>'`
resolve one.

- **Extends:** `PostgresDatasource`
- **Mixes in:** `TomSqlTwoPhaseRecovery`

##### Constructors

```dart
PostgresXADatasource()
```

##### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `maxBranchIdBytes` | `int` | `const`, `200`: the most bytes a prepared transaction's id may hold. The id is built by `tomSqlBranchId` and bounded to it. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `startTransaction` | `Future<bool> startTransaction(TomTransaction transaction)` | *(override)* Opens the transaction with `beginStatement` (read-only when it is) and names its branch. The branch id doubles as the in-transaction guard, exactly as on `MariaDbXADatasource`: a second start of the same transaction throws `error.transaction.already_active` with the open branch in `transactionId`. A start the database refused clears the id and hands the connection back. |
| `prepare` | `Future<bool> prepare(TomTransaction transaction)` | *(override)* `PREPARE TRANSACTION '<id>'`. A failure keeps the branch for `rollback`, which the coordinator calls on every participant after a veto; PostgreSQL has already aborted the transaction, so that rollback finds an ordinary transaction-less session and only clears the branch. |
| `commit` | `Future<bool> commit(TomTransaction transaction)` | *(override)* `COMMIT PREPARED '<id>'`, clearing the id. A failure leaves the branch in doubt, named in `pg_prepared_xacts`, where a recovery commits it when the decision is recorded. |
| `rollback` | `Future<bool> rollback(TomTransaction transaction)` | *(override)* `ROLLBACK` while the transaction is open, `ROLLBACK PREPARED '<id>'` once it was prepared; nothing when no branch was opened or a commit cleared it. Clears the branch either way and reports whether it was undone. |

### Read Replicas

A `TomSqlDatasource` configured with `replicas` keeps a pool per replica
beside its own and routes a statement to a replica only when it is read-only
work (a read-only transaction, a `GET` or `HEAD` request, or a `readOnly`
block), a repository read of an entity not marked `@TomPrimaryReads`, a read
(`isReadStatement`), and the principal in context has not written through the
data source within `replicaStickinessMs`. Everything else runs on the primary.
Source: `lib/src/tomserver/datasources/read_replicas.dart`. See
[Read Replicas](../datasources.md#read-replicas).

#### TomPrimaryReads

Marks an entity whose reads are always served by the primary, never by a read
replica — data a decision is taken on the moment it changes. The framework
marks `TomResourceGrant`, `TomPrincipalResourceGrant`,
`TomPrincipalDelegation`, `TomUserTwoFactorEnrolment`,
`TomExternalIdentityLink` and `TomExternalIdentityToken`.

##### Constructors

```dart
const TomPrimaryReads()
```

#### TomReplicaRouting

The routing rules of read replicas, as statics. The zone markers are what the
data source reads when it chooses a statement's connection.

- **Modifiers:** `abstract final` — statics only.

##### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `routeSafeRequests` | `bool` | Whether a `GET` or `HEAD` request is read-only work, so its repository reads may be served by a replica. Default `true`; a deployment whose safe requests write sets it `false`. |
| `isReadOnlyContext` | `bool` | *(getter)* Whether the current zone is read-only work: a running transaction answers with its `isReadOnly`, otherwise whether a `readOnly` block is in effect. |
| `isPrimaryForced` | `bool` | *(getter)* Whether the current zone sends every read to the primary (`primary`). |
| `isRepositoryRead` | `bool` | *(getter)* Whether the current zone is a repository read of an entity a replica may serve (`repositoryRead`). |

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `readOnly` | `static Future<R> readOnly<R>(Future<R> Function() body)` | Runs `body` as read-only work: its repository reads may be served by a replica. |
| `primary` | `static Future<R> primary<R>(Future<R> Function() body)` | Runs `body` with every read on the primary, whatever the context. |
| `repositoryRead` | `static Future<R> repositoryRead<R>(Type entity, Future<R> Function() body)` | Runs `body`, a read of `entity` by its repository, marked as one a replica may serve — unless `entity` is `@TomPrimaryReads`, in which case `body` runs unmarked. `TomSqlDatasourceRepository` wraps every read method in it. |
| `readsFromPrimary` | `static bool readsFromPrimary(Type entity)` | Whether `entity` carries `@TomPrimaryReads`; the answer is cached per type. |
| `isReadStatement` | `static bool isReadStatement(String sql)` | Whether `sql` only reads: it starts with `SELECT` or `WITH` (after any opening brackets and comments) and names no locking clause (`FOR UPDATE`, `FOR SHARE`, `FOR NO KEY UPDATE`), no writing keyword and no session function (`INTO`, `LOCK`, `nextval`, `GET_LOCK`, the advisory locks, `LAST_INSERT_ID`, `SLEEP`, …) anywhere. Conservative: a word inside a string literal counts too. |

### Placeholder Scanning

#### SqlPlaceholderScan

Quote-aware scan of `:name` parameter placeholders in generated SQL. Walks the
SQL character by character, copying quoted spans verbatim, and only recognises a
`:name` placeholder in ordinary (outside-quotes) text, and never reads a `::`
(a PostgreSQL cast) as one. This is the single shared implementation both SQL
drivers and the CRUD repository use.

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toPositional` | `static (String, List<String>) toPositional(String namedSql, {String Function(int index)? slot, bool backslashEscapes = true})` | Rewrites every outside-of-literal `:name` placeholder to a positional slot, returning the rewritten SQL and placeholder names in order (repeats included). `slot` renders the slot at a 0-based index — `?` when omitted, `$1`, `$2`, … for the PostgreSQL driver. `backslashEscapes` says whether a backslash escapes the next character inside a string literal: MariaDB's default mode, and not PostgreSQL's, where `'\'` is a literal backslash and the quote after it closes the literal. |
| `extractNames` | `static List<String> extractNames(String namedSql)` | The placeholder names in textual order (repeats included), skipping any inside a string literal. |

### SQL Lexing

#### TomSqlLexer

The shared SQL lexing primitives — the one place this package decides where a
quoted run ends and where one statement ends and the next begins. The SQL
drivers' one-statement check, `db_migration`'s appliers
(`TomSqlMigrationAdaptor.applyScript`) and its reader
(`TomSchemaDdlReader`) are all written on it, because a scan that disagrees with the
server does not fail loudly: it cuts a statement in half inside a string literal,
or swallows a closing quote and welds two statements into one.

Escaping is not uniform across the three quote characters, and the lexer
implements what MariaDB actually does under the default `sql_mode`
(`NO_BACKSLASH_ESCAPES` off):

| Quote | `''` doubling | `\'` backslash |
| ----- | ------------- | -------------- |
| `'` string literal | yes | yes |
| `"` string literal | yes | yes |
| `` ` `` identifier | yes | **no** |

##### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `quoteCharacters` | `String` | The three characters that open a quoted run: `'`, `"` and `` ` ``. |

##### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `endOfQuotedRun` | `static int endOfQuotedRun(String sql, int openIndex, {bool backslashEscapes = true})` | The index of the closing quote of the run opened at `openIndex` — by the database's literal rule `backslashEscapes` — or `sql.length - 1` when the run is never closed (reported, not thrown — this is a lexer, not a validator). |
| `endOfComment` | `static int endOfComment(String sql, int startIndex)` | The index of the last character of the comment starting at `startIndex`; a line comment ends before its newline, a block comment at its `*/`. |
| `commentOpensAt` | `static bool commentOpensAt(String sql, int index)` | Whether a comment opens at `index` — `--`, `#` or `/*`. Only meaningful outside a quoted run. |
| `splitStatements` | `static List<String> splitStatements(String sql, {bool backslashEscapes = true})` | Splits `sql` into its statements on unquoted, uncommented semicolons, trimmed, dropping whitespace-only fragments; `backslashEscapes` is the database's literal rule (`false` for PostgreSQL, where `'C:\'` is a whole literal). **Comments are preserved** — `/*!40101 … */` is executable, version-gated SQL, so dropping it would silently remove a statement. |

### Framework-Owned Tables

The framework's own tables — the job queue, the lease table, the scheduler roll
call, the blob manifest/chunk pair, the audit trail — are not entities, so the
entity-to-migration convergence check does not reach them. A
`TomFrameworkTable` is the one declaration they get instead, and everything
else is derived from it: the create-if-missing DDL, the column lists the
hand-written statements interpolate, the `INSERT`/`REPLACE` statements in
each database's words, and the `TomSchemaModel` the convergence guard compares. Declared here rather than in
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
| `maxCharacters` | `int?` | The declared character capacity of a string column, or `null` for a type carrying none — `VARCHAR(160)` and `CHAR(64)` answer with their length, `BIGINT` and `LONGTEXT` answer `null`. Read from `type` rather than declared beside it, so a writer trimming a value to fit and a reader trimming a search term the same way ask one declaration where the width is. A precision is not a character capacity, which is why the type name is matched and not the parenthesis alone. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ddl` | `String ddl(int nameWidth, int typeWidth)` | The column's line in a `CREATE TABLE` body, padded to the two widths so a reader can scan the types in a column — the canonical rendering, the type as declared. |
| `ddlIn` | `String ddlIn(TomStandardSqlDialect dialect, int nameWidth, int typeWidth)` | The column's line as `dialect`'s database spells it (`TomStandardSqlDialect.columnDefinition`). |
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
| `ddl` | `String ddl(String table)` | The key's line in a `CREATE TABLE` body, canonically rendered. |

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

Throws `ArgumentError` when `columns` is empty, or when `primaryKey` or a key
names a column the table does not declare. Both are checked on construction
because a descriptor is built once at start-up, where the alternative is a
`CREATE TABLE` that fails against a live server.

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
| `createTableDdl` | `String` | The canonical `CREATE TABLE IF NOT EXISTS` statement of this table — the types as declared, in MariaDB's spelling — which the convergence guard reads. A store creates its table with `create`, in its own database's words. |

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `has` | `bool has(String column)` | Whether a column called `column` exists, case-insensitively. |
| `column` | `TomFrameworkColumn? column(String column)` | The named column, or `null`. |
| `columnsOf` | `String columnsOf(Iterable<String> names)` | `names` as a column list, in the order given. Throws `ArgumentError` when a name is not a column — a projection that outlived the column it names fails at the first call rather than at the database. |
| `insertRow` | `String insertRow(TomStandardSqlDialect dialect, Map<String, String> values, {bool ignoreConflict = false})` | Renders a row-writing statement for `dialect`'s database (`TomStandardSqlDialect.insertInto`). `values` maps a column name to the SQL text that supplies it, usually a `:bind` but sometimes a literal. With `ignoreConflict` a row whose key already exists is kept and the write changes nothing. Keyed by name rather than by position, because a positional list would let a column inserted in the descriptor silently shift every value one place along. Throws `ArgumentError` on an unknown column. |
| `replaceStatements` | `List<String> replaceStatements(TomStandardSqlDialect dialect, Map<String, String> values)` | The statements writing a row over every row it supersedes — the one with its primary key, and any colliding on one of this table's unique keys — in `dialect`'s database (`TomStandardSqlDialect.replaceInto`). Throws `ArgumentError` on an unknown column. |
| `replaceRow` | `Future<void> replaceRow(TomDataSource datasource, Map<String, String> values, Map<String, dynamic> params)` | Writes a row over every row it supersedes, in `datasource`: one statement on MariaDB; a `DELETE` and an `INSERT` run in one transaction where the database has no `REPLACE`. `values` names the SQL text per column as for `insertRow`; `params` binds it. |
| `createStatements` | `List<String> createStatements(TomStandardSqlDialect dialect)` | The statements building this table in `dialect`'s database: the `CREATE TABLE IF NOT EXISTS`, then — where the database cannot declare an index inside the table — one `CREATE INDEX IF NOT EXISTS` per index. `IF NOT EXISTS` because every store calls it on first use and a second process must not fail on a table the first one created. |
| `create` | `Future<void> create(TomDataSource datasource)` | Creates this table in `datasource` if it does not exist, running `createStatements` in the data source's own dialect. |
| `toString` | `String toString()` | *(override)* `"TomFrameworkTable(<name>)"`. |

#### TomSchemaProvisioning

Provisions a store's tables at most once, however many first calls arrive
together. A store creates its tables on first use; two requests reaching a fresh
store at the same moment both see "not yet created", and with a connection pool
their two `CREATE TABLE IF NOT EXISTS` run on two connections — the second can
return before the first has finished creating the table, so the second request's
statement fails on a table that does not exist yet. Sharing the one creation in
flight closes that: every caller awaits the same run. A creation that fails is
forgotten, so the next call tries again rather than inheriting the failure for
the life of the store. Every framework store's `ensureSchema` — `TomSqlJobStore`,
`TomSqlLeaseLock`, `TomSqlSchedulerNodes`, `TomSqlDeliveryReportStore`,
`TomSqlInvalidationChannel`, `TomSqlOAuthStateStore`, `TomSqlScimStore` and
`TomDatabaseBlobStore` — runs through one.

##### Constructors

```dart
TomSchemaProvisioning()
```

##### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ensure` | `Future<void> ensure(Future<void> Function() create)` | Runs `create` once, or awaits the run already in flight or finished. |

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
| `tom_datasource_info.initialize.no_type_specified` | The configuration entry carries no `type` |
| `tom_datasource_info.initialize.unknown_setting` | A settings key names no field of the configured driver |

#### TomConnectionPoolException

Thrown when the pool cannot hand out a connection: it is closed, every
connection stayed busy past the acquire timeout, or its settings are
inconsistent. A server-side condition, so it is raised with
`clientThrow: false`; the key is what an operator matches on.

- **Extends:** `TomServerException`

##### Constructors

```dart
TomConnectionPoolException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? rootException,
  StackTrace? stack,
})
```

##### Error keys

| Key | Raised by |
| --- | --------- |
| `error.datasource.pool.closed` | `acquire` on a closed pool, and every caller still waiting when the pool closes |
| `error.datasource.pool.acquire_timeout` | `acquire` when no connection became free within `acquireTimeout`; parameters `maxSize` and `timeoutMs` |
| `error.datasource.pool.invalid_settings` | `TomConnectionPoolSettings.validate`, run by the pool's constructor; parameter `fault` |

#### TomSqlDatasourceException

A SQL data-source failure: connect, execute, or result mapping. Each driver
throws its own subtype, so a log names the database; code that handles any of
them catches this. `TomSqlDatasource` raises every refusal through its
`datasourceException`, which answers this type unless the driver narrows it.

- **Extends:** `TomServerException`

##### Constructors

```dart
TomSqlDatasourceException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

#### TomSqlConnectionLostException

A prepared statement failed with no live connection to have run on, so one
reconnect-and-retry may recover it. The type carries the whole signal:
`TomSqlPreparedStatement.run` catches this and nothing else, so raising it *is*
the decision to retry — outside a transaction; inside one it becomes the
`rootException` of `error.failed-to-execute.transaction_connection_lost`. Which
failures qualify is the driver's `isLostConnection`, which both drivers answer
with `isLostConnectionFailure`.

- **Extends:** `TomServerException`

##### Constructors

```dart
TomSqlConnectionLostException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

#### MariadbDatasourceException

Thrown for MariaDB data-source failures (connect, execute, result mapping).

- **Extends:** `TomSqlDatasourceException`

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

The MariaDB driver's `TomSqlConnectionLostException`: a MariaDB prepared
statement failed with no live link to have run on (keyed
`error.failed-to-execute.connection_closed`).

- **Extends:** `TomSqlConnectionLostException`

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

#### PostgresDatasourceException

Thrown for PostgreSQL data-source failures (connect, execute, result mapping),
among them `error.initialize.invalid_ssl_mode` for an `sslMode` that is none of
`disable`, `require`, `verifyFull`.

- **Extends:** `TomSqlDatasourceException`

##### Constructors

```dart
PostgresDatasourceException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

#### PostgresConnectionLostException

The PostgreSQL driver's `TomSqlConnectionLostException`: a PostgreSQL prepared
statement failed with no live connection to have run on (keyed
`error.failed-to-execute.connection_closed`).

- **Extends:** `TomSqlConnectionLostException`

##### Constructors

```dart
PostgresConnectionLostException(
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
| `classifySqlFailure` | `TomSqlFailureMode classifySqlFailure(Object? error)` | Classifies the failure of a data-source write: `definite` when the chain contains a `MySQLServerException` or a PostgreSQL `ServerException` (the server received the statement and rejected it), `ambiguous` for everything else. |
| `sqlFailureCauses` | `Iterable<Object> sqlFailureCauses(Object? error)` | `error` and every `rootException` beneath it, outermost first — exposed so a caller that has decided a failure is ambiguous can name the driver exception several wrappers down. |
| `isLostConnectionFailure` | `bool isLostConnectionFailure(Object? error, {required bool connected})` | Whether the statement was left with no live link to have run on, so one reconnect-and-retry is worth it: true when `connected` is false *and* `classifySqlFailure` finds no server answer in the chain. Both drivers answer `TomSqlDatasource.isLostConnection` with it, which drives `TomSqlPreparedStatement.run`'s single retry. |
| `sqlInstant` | `String sqlInstant(DateTime value)` | Renders `value` as the UTC `DATETIME(6)` literal the columns bind — always UTC, always six fractional digits, so nodes that disagree about the local zone still agree about the instant and the text stays comparable in SQL as well as in Dart. |
| `sqlDate` | `String sqlDate(DateTime value)` | Renders the calendar half of `value` as the fixed-width `YYYY-MM-DD` a `DATE` column takes. The components are read **as labelled** — the opposite choice from `sqlInstant`, and the right one for the same reason: an instant is a moment, so it is normalised to the frame every node shares, while a date names a day *in the calendar it was written in*, and converting it to UTC moves it to the previous or next day for half the world's zones. |
| `sqlTimeOfDay` | `String sqlTimeOfDay(DateTime value)` | Renders the clock half of `value` as the fixed-width `HH:MM:SS` a `TIME` column takes — the other half of `sqlDate`, components likewise as labelled. Sub-second digits are dropped: a `TIME` with no declared precision keeps whole seconds, and text the column cannot hold compares unequal to the value stored from it. |
| `parseSqlInstant` | `DateTime parseSqlInstant(String value)` | Reads a stored `DATETIME(6)` back as a UTC `DateTime`. `DateTime.parse` on the column text alone would produce a *local* value, which compares unequal to the UTC one that was written; appending the zone marker is what makes the round trip exact. |
| `parseOptionalSqlInstant` | `DateTime? parseOptionalSqlInstant(String? value)` | Reads an optional stored `DATETIME(6)`, treating an empty column as absent — the driver reports a `NULL` instant as either `null` or `''` depending on the row mapper, and the two are collapsed here rather than at every caller. |
| `parseSqlDate` | `TomZonedDate parseSqlDate(String value)` | Reads a stored `DATE` back as a `TomZonedDate` — the reading half of `sqlDate`, taking the components as labelled and anchoring them in UTC, because a `DATE` column has nowhere to put a zone. Tom's `@D@…` serialization is accepted too, and does carry one. The trailing midnight the driver appends when it materialises a `DATE` (`2026-07-15 00:00:00.0`) is accepted and discarded; a trailing clock reading that is not zero throws, being a timestamp read by the wrong reader. |
| `parseSqlTimeOfDay` | `TomZonedTime parseSqlTimeOfDay(String value)` | Reads a stored `TIME` back as a `TomZonedTime` — the other half, on the same terms. Sub-second digits are accepted and dropped, matching `sqlTimeOfDay`. An hour past 23 throws: MariaDB's `TIME` spans 838 hours because it doubles as a duration type, and a duration is not a clock reading — wrapping it into the next day would turn a modelling mistake into a plausible wrong answer. |
| `tomSqlBindValue` | `Object? tomSqlBindValue(Object? value)` | Marshals one bind value into the primitive a SQL driver binds: a `TomDbType` box is unwrapped; a Dart `bool` becomes `1`/`0`; a `TomZonedDate` becomes its `DATE` text and a `TomZonedTime` its `TIME` text; any other `DateTime` becomes its UTC instant text (`sqlInstant`); every other value is bound as-is. One encoding for every driver: MariaDB has no boolean type and rejects a bound `'false'` and an instant ending in `Z`, and PostgreSQL, sent each value as text with an unspecified type, reads the same text correctly into a `SMALLINT`, a `BOOLEAN` or a `TIMESTAMP`. |
| `tomSqlBindParams` | `Map<String, Object?>? tomSqlBindParams(Map<String, dynamic>? params)` | `params` with every value marshalled through `tomSqlBindValue`, or `null` for `null`. Both statement paths marshal, so a hand-written store binding a `DateTime` or a `bool` gets the same encoding as a prepared statement. |
| `tomSqlBranchId` | `String tomSqlBranchId({required String databaseName, required String host, required int port, required String processTag, required int counter, required int maxBytes})` | A process-unique two-phase branch id, `<database>@<host>:<port>_<process>_<time>_<counter>`, at most `maxBytes` long. Both servers refuse an over-long transaction id, so the unique tail is always kept whole and the readable head is truncated; characters outside `[A-Za-z0-9_.@:-]` become `_`, which keeps the id single-byte and safe to quote. |
| `tomSqlOwnsBranch` | `bool tomSqlOwnsBranch(String branchId, {required String databaseName, required String host, required int port})` | Whether `branchId` is a `tomSqlBranchId` built for `databaseName` at `host` and `port`: its tail has the shape `tomSqlBranchId` writes, and its head is the coordinates — with the characters `tomSqlBranchId` replaces replaced — whole, or truncated to no fewer than sixteen characters. How a recovery tells its own branches from the rest of a server-wide `XA RECOVER`. |
| `tomSqlBranchOpenedAt` | `DateTime? tomSqlBranchOpenedAt(String branchId)` | When the `tomSqlBranchId` `branchId` was opened — the UTC time its tail carries — or `null` for an id of another shape. |
| `unknownFrameworkColumns` | `List<String> unknownFrameworkColumns(String sql, Iterable<TomFrameworkTable> tables)` | The identifiers in `sql` that are not a column of any of `tables`, not one of their names or index names, and not SQL. The guard for the half of a statement a column list cannot cover — the references inside `SET`, `WHERE` and `ORDER BY` — driven by passing every statement a store issued through it. String literals, `:bind` placeholders and numbers are stripped first, and anything surviving that is not a known SQL word is reported: a missing word is a noisy false positive in a test, a missed column reference is a production failure. |

### Constants

The names of the series every `TomSqlDatasource` records into
`TomMetrics.registry` (see [metrics.md](../metrics.md#data-sources)). Each is
labelled `datasource` with `registeredName`.

| Constant | Value | Description |
| -------- | ----- | ----------- |
| `tomDbStatementDurationMetric` | `'tom_db_statement_duration_seconds'` | Histogram of one statement's duration on a connection already held, also labelled `operation` (`query`, `command`, `prepare`, `prepared`, `driver`). |
| `tomDbStatementErrorsMetric` | `'tom_db_statement_errors'` | Counter of statements that threw, labelled as the duration. |
| `tomDbPoolConnectionsMetric` | `'tom_db_pool_connections'` | Observed gauge of the pool's connections by `state`: `idle`, `in_use`, `waiting`, `max`. Reported while the data source is open. |
| `tomDbPoolAcquireDurationMetric` | `'tom_db_pool_acquire_duration_seconds'` | Histogram of the wait for a pooled connection. |
| `tomDbPoolAcquireFailuresMetric` | `'tom_db_pool_acquire_failures'` | Counter of failed acquires — the acquire timeout, or a connection that could not be opened. |

The constants live in `sql_datasource.dart`, beside the class that records them.

`SqlString` (in `sql_dialects.dart`) is a typedef alias for `String` that
documents "this is a SQL fragment" at call sites.
