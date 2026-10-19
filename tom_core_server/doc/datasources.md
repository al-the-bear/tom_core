# Datasources Module

The data-access foundation of the server: **SQL-typed values**
(`TomDbType<T>`), a typed **operator tree** (`TomOperator<R>`), a **SQL dialect**
that renders that tree to SQL fragments (`TomStandardSqlDialect`), reusable
**query objects** (`TomSelect`, `TomCount`, `TomDelete`, `TomLiteralSelect`),
and the **data-source / driver** abstraction (`TomDataSource`,
`TomDatasourceDriver`, `TomDataSourceInfo`) with two **SQL drivers** —
MariaDB and PostgreSQL 15+ — built on one driver-neutral base
(`TomSqlDatasource`) that runs over a bounded **connection pool**
(`TomConnectionPool`). The object-persistence module builds its query DSL and
repositories on top of this layer.

Three smaller things live here for the same reason — they are decisions every
table has to make the same way, so they cannot belong to any one caller: how an
instant is written to a column, how a `:name` placeholder is found in text that
also contains string literals, and how a table the **framework itself** owns is
declared.

## Table of Contents

- [Overview](#overview)
- [SQL-Typed Values](#sql-typed-values)
- [Instants Are UTC](#instants-are-utc)
  - [The two halves an instant splits into](#the-two-halves-an-instant-splits-into)
- [The Operator Tree](#the-operator-tree)
- [The SQL Dialect](#the-sql-dialect)
  - [A `LIKE` pattern is a language, not a value](#a-like-pattern-is-a-language-not-a-value)
- [Classifying Column Types](#classifying-column-types)
- [Aggregate Fragments](#aggregate-fragments)
- [Query Objects](#query-objects)
  - [What a statement reports about itself](#what-a-statement-reports-about-itself)
  - [Ordering and the row window](#ordering-and-the-row-window)
    - [Sort terms name columns, not Dart fields](#sort-terms-name-columns-not-dart-fields)
- [Finding Placeholders in Quoted SQL](#finding-placeholders-in-quoted-sql)
- [Data Sources and Drivers](#data-sources-and-drivers)
  - [Every settings key has to bind](#every-settings-key-has-to-bind)
  - [Routing per tenant](#routing-per-tenant)
  - [What one execution reports](#what-one-execution-reports)
- [When a Write Fails](#when-a-write-fails)
  - [Why the test recognises the *definite* side](#why-the-test-recognises-the-definite-side)
  - [Walking the chain](#walking-the-chain)
  - [Deciding whether to retry](#deciding-whether-to-retry)
- [The Connection Pool](#the-connection-pool)
- [The SQL Drivers](#the-sql-drivers)
  - [Settings](#settings)
  - [Connections](#connections)
  - [The connection lifecycle](#the-connection-lifecycle)
  - [One statement per call](#one-statement-per-call)
  - [Reading rows](#reading-rows)
  - [Transactions](#transactions)
  - [The MariaDB driver](#the-mariadb-driver)
  - [The PostgreSQL driver](#the-postgresql-driver)
- [Framework-Owned Tables](#framework-owned-tables)
  - [One declaration, every database](#one-declaration-every-database)
  - [Creating a store's tables once](#creating-a-stores-tables-once)
- [Verification](#verification)
- [Core Components](#core-components)
- [Not Yet Implemented](#not-yet-implemented)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomDbType<T>` (+ `TomDbInt`/`TomDbDouble`/`TomDbString`/`TomDbDateTime`/`TomDbDate`/`TomDbTime`/`TomDbBool`) | abstract class / classes | A boxed, SQL-typed value with a parsing `of(String?)` factory |
| `TomOperator<R>` | abstract class | A node in a SQL expression tree, typed by its SQL return type `R` |
| `SqlString` | typedef | A `String` that documents "this is a SQL fragment" |
| `sqlInstant` / `parseSqlInstant` / `parseOptionalSqlInstant` | function | The one encoding of an instant in a `DATETIME(6)` column — always UTC, six fractional digits |
| `sqlDate` / `sqlTimeOfDay` | function | The two halves an instant splits into: the `YYYY-MM-DD` a `DATE` column takes and the `HH:MM:SS` a `TIME` column takes, components as labelled |
| `parseSqlDate` / `parseSqlTimeOfDay` | function | The reading halves of those two: a `DATE` back to a `TomZonedDate`, a `TIME` back to a `TomZonedTime` |
| `TomStandardSqlDialect` | class | Renders operator nodes to standard-SQL fragments |
| `TomAggregateFunction` | enum | The aggregate vocabulary a dialect must render (`count`/`sum`/`avg`/`min`/`max`) |
| `TomSqlTypeFamily` | enum | The coarse type classes a stored column can belong to — what a dialect reduces a SQL type name *to* |
| `TomSqlFailureMode` | enum | Whether a failed write is known not to have happened (`definite`) or unknown (`ambiguous`) |
| `classifySqlFailure` / `sqlFailureCauses` | function | Classifies a write failure, and walks the `rootException` chain it reads |
| `isLostConnectionFailure` | function | Whether a failure left no live link to have run on, so one retry on another connection is worth it |
| `TomQuery` / `TomGeneratedQuery` | abstract class | A query over a set of entity types |
| `TomSelect` / `TomCount` / `TomDelete` / `TomLiteralSelect` | class | Concrete statements |
| `TomTypePersistenceInfo` | class | Per-type persistence metadata (table + columns) |
| `TomTypedPersistenceBase` | abstract class | Base for anything scoped to a set of entity types; analyses their annotations once and exposes the flattened column information |
| `SqlPlaceholderScan` | class | Finds `:name` placeholders in generated SQL without mistaking one inside a quoted literal for a bind |
| `TomSqlLexer` | class | The package's one quote/comment scanner and statement splitter — shared by this driver's one-statement check and by `db_migration`'s applier and DDL reader |
| `TomDataSource` | abstract class | One configured data source (lifecycle + execution) |
| `TomSqlDatasource` | abstract class | Everything a SQL driver does that does not depend on the database: the pool, a connection per transaction, the statement paths, the row mapping, the settings binding |
| `TomSqlPreparedStatement<T>` | class | A prepared statement of a `TomSqlDatasource`, prepared on each pooled connection that runs it and retried once on another when its connection was lost |
| `TomSqlRow` / `TomSqlResult` | abstract interface class | What a driver hands the mapper: a row whose every column reads as text in one convention, and a statement's rows, affected-row count and generated key |
| `TomSqlResultValues` | class | A `TomSqlResult` holding its values, optionally matching column names without regard to case |
| `TomSqlLink` / `TomSqlBranch` | abstract class / class | One pooled connection of a SQL data source; one transaction's share of it — the pinned connection and any two-phase branch |
| `tomSqlBindValue` / `tomSqlBindParams` / `tomSqlBranchId` | function | The one marshalling of a bind value every SQL driver uses; a bounded, process-unique two-phase branch id |
| `TomPreparedStatement<T>` | abstract class | A reusable compiled statement, run any number of times — concurrently — through `execute` (rows) or `run` (rows, affected-row count, generated key) |
| `TomStatementOutcome<T>` | class | What one execution of a prepared statement reported: its `rows`, its `affectedRows` and its `generatedId` |
| `TomDatasourceDriver` | class | Marks a `TomDataSource` as the driver for a named type |
| `TomDataSourceInfo` | class | The process-wide registry of named, configured data sources |
| `TomDatasourceInitException` | class | A data source could not be discovered, instantiated or initialised |
| `MariaDbDatasource` / `MariaDbXADatasource` / `MariadbSqlDialect` | class | The MariaDB implementation (plain + XA transactions) |
| `MariadbPreparedStatement<T>` | class | The MariaDB driver's `TomSqlPreparedStatement` |
| `PostgresDatasource` / `PostgresXADatasource` / `PostgresSqlDialect` | class | The PostgreSQL 15+ implementation (plain + two-phase transactions) |
| `TomConnectionPool<C>` | class | A bounded pool of connections of any driver's type: lends them, takes them back, retires idle and old ones |
| `TomConnectionPoolSettings` | class | How a pool sizes itself and when it retires a connection, with the common JDBC-pool defaults |
| `TomConnectionFactory<C>` | abstract interface class | What a driver tells the pool about its connection type: open, close, check, validate |
| `TomConnectionPoolException` | class | The pool cannot hand out a connection: closed, timed out waiting, or misconfigured |
| `TomSqlDatasourceException` / `MariadbDatasourceException` / `PostgresDatasourceException` | class | A SQL connect, execute or result-mapping failure, and its per-driver subtypes |
| `TomSqlConnectionLostException` / `MariadbPreparedStatementException` / `PostgresConnectionLostException` | class | A statement failed with no live link to have run on — raising it *is* the decision to retry once — and its per-driver subtypes |
| `TomFrameworkTable` / `TomFrameworkColumn` / `TomFrameworkKey` | class | The single declaration of a table the framework itself owns, from which its DDL, column lists and row writes are derived — in each database's own words |
| `TomSchemaProvisioning` | class | Creates a store's tables at most once, however many first calls arrive together |
| `unknownFrameworkColumns` | function | Audits a hand-written statement for column references no framework table declares |

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

## Instants Are UTC

A MariaDB `DATETIME` carries no zone — nor does the PostgreSQL `TIMESTAMP` the
canonical `DATETIME(6)` becomes — and a client materialises one with
`DateTime.parse` on the column's text — which yields a **local** `DateTime`.
`DateTime.==` compares `isUtc` as well as the moment, so a value written as UTC
does not compare equal to the value read back, even though both denote the same
instant. Left alone, two nodes of one cluster write different characters into
the same column for the same moment, and each reads the other's rows off by the
difference in their offsets.

`sqlInstant` and `parseSqlInstant` settle it once, and settle it the same way
for both ways this server writes SQL:

- **Hand-written SQL** — the scheduling, OAuth-state, audit and file-storage
  stores build their own statements and call the pair at each seam explicitly.
- **Reflected entity columns** — a `@TomDbColumn` on a `DateTime?` field
  names no conversion at all, so this module applies one on its behalf:
  the bind boundary every SQL driver shares (`tomSqlBindValue`) renders every
  bound `DateTime` through `sqlInstant`,
  `TomDbDateTime.of` reads a column back through `parseOptionalSqlInstant`, and
  `dateTimeOp` inlines the same text as a literal. An entity therefore stores
  UTC and reads UTC without saying so.

  A repository reads through a prepared statement, so its rows arrive over
  MySQL's binary protocol — and there the driver renders the microsecond field
  of a `DATETIME` as a bare integer: 91 371 µs becomes `.91371`, which any
  parser reads as 0.91371 s. The data source marks every row a prepared
  statement returns and restores the six-digit fraction before the reader sees
  it. Over the text protocol (`executeQuery`) the server formats the value
  itself, with the column's own precision, so those rows are left alone: the
  same `.5` is 5 µs from one protocol and 500 ms from a `DATETIME(1)` over the
  other, which is why the repair is decided per result set and never from the
  text. The PostgreSQL driver runs every session in UTC and renders the typed
  instant its protocol delivers through `sqlInstant`, so the reader sees the same
  text. `test/temporal_columns_db_test.dart` holds both halves, on both
  databases.
- **Aggregate results** — `TomGroupedRow.dateTimeValue` (and `typed<DateTime>`
  through it) reads the same way, whether the driver filled the row or a caller
  built one by hand. A value that is already a `DateTime` is relabelled with
  `toUtc` rather than reparsed: the same moment, in the frame every other read
  path answers in.

**There is one convention, and it is enforced rather than described.** A test
reads the data source module and the grouped-row accessors off disk and requires
that no file but `sql_instant.dart` names `DateTime.parse` — a column value
parsed anywhere else is read as *this node's* local time, which is a second
convention arrived at silently. The query-sentence compiler is outside that
population on purpose: it parses literals a caller wrote on the way *into* SQL,
and its datetime literal must carry a zone suffix, which a second test holds it
to.

The second case is why the convention is stated here rather than left to each
entity. A validity window, an expiry, a lease deadline — the instants that
*decide* something are exactly the ones an entity is most likely to carry, and
the wall-clock reading of whichever node happened to write the row is not an
answer to "when". Nodes may disagree about the zone; they may not disagree
about the moment.

```dart
sqlInstant(DateTime.utc(2026, 3, 1, 12, 30, 45, 123, 456));
// 2026-03-01 12:30:45.123456

parseSqlInstant('2026-03-01 12:30:45.123456').isUtc;  // true
parseOptionalSqlInstant('');                          // null
```

A local `DateTime` handed to `sqlInstant` comes back as a UTC one: the same
instant, differently labelled, which is the right answer for a cluster whose
nodes must never compare wall clocks.

The corollary for DDL: **a column holding an instant is `DATETIME(6)`.** A plain
`DATETIME` rounds the microseconds this convention always writes, which moves
the stored moment by up to half a second — tolerable for a "when was this
touched" field, not for a boundary something is compared against.

### The two halves an instant splits into

A `DATE` column names a day and no time; a `TIME` column names a position within
a day and no day. `sqlDate` and `sqlTimeOfDay` render them, and take the
components **as labelled** — the opposite of `sqlInstant`, and the right answer
for the same reason it is the wrong one for an instant. An instant is a moment,
so it is normalised to the frame every node shares. A date is a day *in the
calendar it was written in*: converting `2026-03-01` to UTC moves it to February
28th for half the world's zones, and the row then falls in the wrong month.

```dart
sqlDate(DateTime(2026, 3, 1, 23, 30));       // 2026-03-01
sqlTimeOfDay(DateTime(1970, 1, 1, 9, 5, 3)); // 09:05:03

parseSqlDate('2026-03-01').day;        // 1
parseSqlTimeOfDay('09:05:03').hour;    // 9
```

Sub-second digits are dropped from a time: a `TIME` with no declared precision
keeps whole seconds, so text carrying more than the column can hold compares
unequal to the value stored from it.

Both functions live here rather than in the dialect because **two routes reach
the same column** and must spell a value identically — `dateOp` / `timeOp`
inline a literal into generated SQL, while the MariaDB bind boundary renders a
bound value. Each quotes these renderers instead of restating the format, so the
two cannot drift apart.

`parseSqlDate` and `parseSqlTimeOfDay` are the reading halves, and they live
beside the renderers for the same reason: a writer and a reader are only correct
as a pair. Each takes the components as labelled, which is what makes the round
trip return the day and the reading that were written — and each also accepts
Tom's own `@D@…` / `@T@…` serialization, for a value that reached a text column
through `toString()` rather than through this module. What a `DATE` or `TIME`
column cannot carry is the **zone**, so a value read back from one is anchored
in UTC; see [Not Yet Implemented](#not-yet-implemented).

Two things about reading are properties of the driver rather than of the format.
A `DATE` column arrives as `2026-03-01 00:00:00.0` — materialised into the shape
a `DATETIME` gets — so the trailing midnight is accepted and discarded, while a
trailing clock reading that is not zero is refused: that value came from a
timestamp column being read by the wrong reader. And a `TIME` column may hold up
to 838 hours, because MariaDB's `TIME` doubles as a duration type; a value past
23 hours is not a clock reading and is refused rather than wrapped into the next
day.

Which reader runs is decided by the entity's declared type — a `TomZonedDate`
or `TomZonedTime` field, or a `TomDbDate` / `TomDbTime` box. A box the driver
has no reader for raises
`error.result_processing.unknown_type_dbtype_conversion`, naming the box and the
column, rather than being read as text.

Which half a value means is decided by its **type**. `TomZonedDate` and
`TomZonedTime` both extend `DateTime`, so every dispatch that recognises them
must test them *before* the general `DateTime` arm; otherwise a whole instant is
bound into a column that holds half of one — a `DATE` silently gaining a time
the caller never named, and a `TIME` receiving a datetime-shaped string MariaDB
rejects outright.

## The Operator Tree

`TomOperator<R>` is one node of a SQL expression, typed by its SQL return type
`R` (`TomOperator<TomDbBool>` is a predicate, `TomOperator<TomDbString>` a text
expression, …). A node knows how to:

- `generate(dialect)` — render its SQL fragment;
- `getFields(dialect)` — report the columns it references;
- `getParameters(dialect)` — report the positional parameters it contributes;
- `children` — yield its direct sub-expressions, left to right.

The object-persistence query builder provides the concrete factories (literals,
field references, comparisons, `AND`/`OR`, …); this module supplies the base
contract and the dialect they render against.

`children` is the single traversal every structural walk goes through. A leaf —
a literal, a parameter, a column reference — has none, and a container yields
its operands, flattening one that is itself a list, as `AND`, `OR`, `IN` and
`BETWEEN` carry. A container builds its own `children` by passing each
constructor operand through the static `TomOperator.operandChildren`, which is
the other half of the pair and reads no tree: a nested operator yields itself, a
`List<TomOperator>` its elements, and a leaf value — a column *name*, a Dart
literal — nothing. That last case is why a column reference is a leaf: its
operand is the name, not a node.

`getFields` and `getParameters` are themselves defined in terms of it, and the
reason it is exposed is the walk neither of them can express. A walk may **stop**
at a node — `TomGroupedSelect` checks a `HAVING` predicate by descending here
while treating an aggregate as opaque, because an aggregate collapses the rows
its operand references and so imposes no grouping obligation on it. And a walk
may ask for what a rendered fragment cannot carry: `getFields` answers with the
SQL text `demo_task.priority`, which is what a statement needs, while a layer
deciding whether a query touches a column the principal may not read needs the
column's *declaration* — its resource key, its declared type — and only the
`DbCol` node holds that. Step 10 of the module example walks a nested predicate
for exactly that.

## The SQL Dialect

`TomStandardSqlDialect` turns operator nodes into SQL fragments — one method per
construct:

```dart
final d = TomStandardSqlDialect();
d.text('abc');                 // 'abc'            (single-quoted literal)
d.text("it's");                // 'it''s'          (embedded quote doubled)
d.intOp(42);                   // 42
d.p('userId');                 // :userId          (bound parameter placeholder)
d.objectOp(['a', 1, true]);    // 'a',1,true       (comma-joined list)
d.nullOp();                    // NULL
```

Literal renderers (`text`, `intOp`, `objectOp`, …) interpolate the value
directly into the SQL string. `text` escapes what it interpolates — an embedded
single quote is doubled and a backslash is escaped — so a value cannot
terminate its own literal and have the remainder read as SQL. `objectOp` routes
strings, and anything it does not otherwise recognise, through `text`, so the
escaping covers the values the expression tree reaches on its own.

That does not change the advice: for untrusted input prefer the parameterised
form `p(name)`. It binds out-of-band, so the value never becomes part of the
SQL text and nothing has to escape correctly for it to be safe. The escaping is
what stands behind the literal path `objectOp` takes anyway.

A driver supplies its own dialect by subclassing and returning it from
`TomDataSource.sqlDialect`; `MariadbSqlDialect` inherits the standard generation
unchanged — its one override is on the *reading* side, below.
`PostgresSqlDialect` overrides the fragments PostgreSQL spells differently: a
string literal whose backslash stays single (`standard_conforming_strings`), a
truth value as `1`/`0` but a constant predicate as `TRUE`/`FALSE`
(`truthPredicate`), a regular-expression match as `~`, and the DDL and
conflicting writes described under
[One declaration, every database](#one-declaration-every-database).

There is no dialect registry to register it in, and deliberately so. Reflection
resolves one thing by data-source type name: the *driver*
([`@TomDatasourceDriver`](#data-sources-and-drivers)). A driver arrives knowing
its dialect, so a second lookup keyed by the same string could only restate — or
contradict — what `sqlDialect` already returns. Everything that renders SQL
therefore asks the data source, and a dialect for another database ships as part
of that database's driver.

### A `LIKE` pattern is a language, not a value

Every other predicate compares its right-hand operand as a value. `LIKE` reads
it as a *pattern*: `%` matches any run of characters and `_` any single one,
wherever they appear — including inside a value the caller bound. So a search
box wired straight through binds the user's typing as a pattern, and
`note LIKE :p` with `p` bound to `%50%%` returns every note containing `50`
followed by anything rather than the ones mentioning `50%`.

Binding does not prevent that and is not meant to. `p(name)` makes the value
*safe* — it never becomes part of the SQL text — and a wildcard inside a pattern
is not unsafe; it is the pattern working as specified. The two questions are
different, and only the caller knows the answer to the second: is this text a
pattern, or something to be matched literally?

So the wildcards stay the caller's to place, and `escapeLikePattern` escapes
what goes between them:

```dart
params['p'] = '%${dialect.escapeLikePattern(searchBox.text)}%';
```

It escapes `%`, `_` and `likeEscapeCharacter` itself — that one first, or a
pattern already containing an escape would consume the one being added. `like`
and `notLike` render an explicit `ESCAPE` clause naming the same character, read
from the same property, so a dialect that needs a different one overrides
`likeEscapeCharacter` alone and the two stay consistent by construction.

The clause is written **always**, not only when something was escaped. Standard
SQL defines no default escape character for `LIKE`, so without it whether
`escapeLikePattern`'s output works would be a property of the driver rather than
of this rendering — and it does work on MariaDB, whose default escape is a
backslash. That is exactly the shape in which a dependency on one driver's
undocumented default survives being noticed, so the rendering states it.

## Classifying Column Types

The dialect has a second job that renders no SQL at all: reading a column type
*in*. `typeFamily(String sqlType)` reduces DDL text — `VARCHAR(255)`, `BIGINT
UNSIGNED`, `DECIMAL(10,2)` — to one of the coarse `TomSqlTypeFamily` values
(`integer`, `decimal`, `text`, `boolean`, `dateTime`, `date`, `time`, `binary`,
`unknown`).

It lives on the dialect because type *names* are dialect-specific in the same
way SQL fragments are, and it exists because a Dart type and a SQL type name
cannot be compared directly. [Schema
Convergence](db_migration.md#schema-convergence) tells the other half of this
story: the schema-convergence checks build a dialect-neutral `TomSchemaModel`
from each side — the reflected `@TomDbColumn` declarations, and the DDL replayed
out of the migration chain — and the only way those two meet is by reducing both
to a family. Every type comparison in that check is a `typeFamily` call.

```dart
final d = MariadbSqlDialect();
d.typeFamily('VARCHAR(255)');      // text
d.typeFamily('DECIMAL(10,2)');     // decimal
d.typeFamily('TINYINT(1)');        // boolean   ← the MariaDB override
d.typeFamily('TINYINT');           // integer
d.typeFamily('GEOGRAPHY');         // unknown  ← no opinion, not a guess
```

Two deliberate limits:

- **The base word decides.** Parenthesised arguments and trailing attributes are
  ignored, because no width, precision, signedness or default is expressible on
  the Dart side, so there is nothing to compare them against. Representing them
  would produce divergences no entity declaration could ever resolve.
- **An unrecognised type yields `unknown`, never a guess.** The convergence
  check reads `unknown` as "no opinion" and stays silent. A guess would report a
  divergence it could not justify, and a false alarm in a check that gates
  startup is worse than a gap in it.

A dialect whose database spells types differently overrides `typeFamily`,
recognises only its own special cases, and delegates the rest:

```dart
@override
TomSqlTypeFamily typeFamily(String sqlType) {
  if (baseTypeName(sqlType) == 'TINYINT') {
    final arguments = typeArguments(sqlType);
    if (arguments.length == 1 && arguments.first == '1') {
      return TomSqlTypeFamily.boolean;
    }
  }
  return super.typeFamily(sqlType);
}
```

That is `MariadbSqlDialect` in full. MariaDB has no distinct boolean storage —
`BOOLEAN` is a synonym for `TINYINT(1)`, and that is how a `bool` entity field
reaches DDL — so calling it an integer would report every boolean column of
every migration as a divergence. Only the exact `(1)` display width is boolean;
a plain `TINYINT` or a `TINYINT(4)` really is a small integer.
`PostgresSqlDialect` adds PostgreSQL's own names the same way — the sized `INT`
aliases and the serials as integers, the sized `FLOAT` aliases as decimals, `BYTEA` as
binary, `TIMESTAMPTZ` and `TIMETZ` as a date-time and a time, `JSONB`/`CITEXT`/
`BPCHAR` as text — and leaves `SMALLINT`, the type a canonical `TINYINT(1)`
becomes there, an integer, which the convergence check's `integer` ↔ `boolean`
tolerance accepts.

`baseTypeName` and `typeArguments` are public for exactly this: the override
needs the same tokenisation the base class uses, and restating it would let the
two drift. Delegating the rest to `super` matters for the same reason — a type
name added to the standard list must reach every subclass without being copied
into it.

## Aggregate Fragments

Grouped queries are assembled in the object-persistence module, but every SQL
character they emit comes from four dialect methods and one enum here — so a
database that spells any of it differently overrides a method rather than
forking the query builder:

| Member | Renders |
| ------ | ------- |
| `TomAggregateFunction` | the vocabulary: `count`, `sum`, `avg`, `min`, `max`; `sqlName` is the upper-cased member name |
| `aggregate(fn, operand, {distinct})` | `COUNT(*)` when `operand` is `null`, else `SUM(t.c)` / `COUNT(DISTINCT t.c)` |
| `aliased(expression, alias)` | `<expression> AS <alias>` — the projection form that names a result column |
| `groupByClause(columnExprs)` | ` GROUP BY a, b`, or `""` for an empty list (an aggregate over the whole result set groups by nothing) |
| `havingClause(predicate)` | ` HAVING <predicate>`, or `""` when there is none |

```dart
final d = TomStandardSqlDialect();
d.aggregate(TomAggregateFunction.count, null);                    // COUNT(*)
d.aggregate(TomAggregateFunction.count, 't.c', distinct: true);   // COUNT(DISTINCT t.c)
d.aliased('COUNT(*)', 'n');                                       // COUNT(*) AS n
d.groupByClause(['t.status']);                                    // ' GROUP BY t.status'
d.havingClause('COUNT(*) > 2');                                   // ' HAVING COUNT(*) > 2'
```

The enum exists so the set of functions a dialect must handle is declared in one
place: an override switches on it and the compiler reports every site when a
member is added. `distinct` is meaningless for `COUNT(*)` — there is no
expression to de-duplicate — and is ignored there.

`groupByClause` and `havingClause` stay separate methods, and the `WHERE` and
`HAVING` predicates travel separately all the way down to them, because the two
filter different things: `WHERE` removes rows before aggregation, `HAVING`
removes groups after it. ANDing them upstream would change the meaning of both.

## Query Objects

A query is built over a set of entity `types` and renders to SQL via
`generateQuery(dialect)`. The generated forms wrap a `TomOperator<TomDbBool>`
predicate with shaping options (`distinct`, `sort`, `top`, `offset`):

| Class | Renders |
| ----- | ------- |
| `TomSelect` | `SELECT … FROM … WHERE <predicate> [ORDER BY …] [LIMIT n [OFFSET m]]` |
| `TomCount` | `SELECT COUNT(*) AS count FROM … WHERE <predicate>` |
| `TomDelete` | `DELETE FROM <first table> WHERE <predicate> [ORDER BY …] [LIMIT n]` |
| `TomLiteralSelect` | a raw, hand-written SQL string with explicit parameters |

### What a statement reports about itself

Besides rendering, a query answers two questions about its own text:
`getParameters(dialect)` names the values it binds, and `getFields(dialect)` the
columns it references. The generated forms answer both by walking their
predicate — the operator tree *is* the statement, so reading it off is exact.

`TomLiteralSelect` cannot. Its SQL is a string nothing here parses, so the
caller declares the parameters and there is nothing to declare the fields from:

| Form | `getParameters` | `getFields` |
| ---- | --------------- | ----------- |
| `TomSelect` / `TomCount` / `TomDelete` | from the predicate | from the predicate |
| `TomLiteralSelect` | the declared list | always empty — *unknown* |

The empty set is the honest answer, but it is not the same answer the base class
gives. A statement referencing no columns reports empty because that is true; a
literal select reports empty because it *cannot say*, and its text may well
reference several columns. Anything that acts on `getFields` — choosing a
projection, auditing a statement, gating access — has to decide which of the two
it is looking at, and must not read an empty set from a literal query as
permission. The access gate over grouped queries deliberately reads
`TomGroupedSelect.referencedColumns` instead, a member no statement can answer
vacuously.

### Ordering and the row window

`sort` is an *ordered list* of `TomSortField` — a field name and its own
`TomSortDirection` — rather than a field list plus one shared flag, because
`ORDER BY priority DESC, due_date ASC` cannot be expressed by a direction that
every column has to agree on. The older two-argument form is still accepted at
the constructor (`orderBy:` + `ascending:`) by every form that sorts at all, and
maps onto the list, so existing call sites and generated reflection code keep
working; internally there is only `sort`.

`top` caps the rows and `offset` skips them, rendering as `LIMIT n` or
`LIMIT n OFFSET m`. Two windows are rejected at construction rather than
rendered:

- a negative bound has no meaning; and
- an `offset` without a `top` is *unrepresentable* — the MariaDB grammar is
  `LIMIT n [OFFSET m]`, so there is no bare `OFFSET`, and emitting the statement
  anyway would silently ignore the skip.

Which of the options a form takes is decided by its result, not by the SQL
grammar, and each form takes only the ones that mean something:

| Form | `distinct` | `sort` | `top` | `offset` |
| ---- | ---------- | ------ | ----- | -------- |
| `TomSelect` / `TomGroupedSelect` | ✓ | ✓ | ✓ | ✓ |
| `TomDelete` | ✓ | ✓ | ✓ | — |
| `TomCount` | ✓ | — | — | — |

`TomDelete` has no `offset` because MariaDB's single-table `DELETE … LIMIT n`
has no `OFFSET` form at all; it keeps `sort` and `top` because
`DELETE … ORDER BY x LIMIT n` picks *which* rows go.

`TomCount` takes none of the three. Its statement returns exactly one row, so a
`LIMIT` would cap what is *returned* rather than what is counted — `top: 5`
would count the whole filtered set and then cap nothing — and an `ORDER BY`
would have a single row to order. The total of a filtered set likewise does not
depend on which page of it the caller is reading. The parameters are absent from
the constructor rather than accepted and ignored, and the query-sentence grammar
matches: `count first 5 …` and `count … order by x` are rejected, not silently
counted whole.

#### Sort terms name columns, not Dart fields

A sort term may be *written* with either name — the column lookup matches the
column name and the declared Dart field name alike — but only the column name is
valid SQL. Every form that renders an `ORDER BY` therefore puts its terms
through `TomGeneratedQuery.resolveSortColumns` first, which substitutes the
column and carries each term's direction over unchanged. Without it, an entity
whose two spellings differ (`DateTime? createdAt` mapped to `created_at`) would
render a column that does not exist.

The lookup is also the guard on the statement text. Sort names routinely arrive
from outside — an HTTP `sort=` parameter, a query sentence — and an `ORDER BY`
cannot bind them as parameters, so resolving them is what makes an unknown name
throw instead of being interpolated verbatim.

The rendering differs by form, the lookup does not:

| Form | Renders terms as | Because |
| ---- | ---------------- | ------- |
| `TomSelect` | `table.column` | may span tables, so it qualifies |
| `TomDelete` | `column` | MariaDB's `DELETE` is single-table |
| `TomGroupedSelect` | the projection alias, *unresolved* | see below |

`TomGroupedSelect` is the deliberate exception. A grouped result orders over
what it *projects*: an aggregate alias (`AS total`) has no column, and a group
column is projected `AS <declaredName>`, so the alias is the name in scope.
Resolving those to column names would break both. Its guard is a different one —
a term the query does not project is refused
(`grouped_query.select.order_by_not_projected`) rather than interpolated.

`TomLiteralSelect` renders its own text and so resolves nothing; a caller
appending an `ORDER BY` to one must call `resolveSortColumns` itself, as
`CrudRepository.findAll` does for its windowed `SELECT *`.

`TomLiteralSelect` is the escape hatch for statements the generated queries
cannot express; its `types` still drive result-row mapping.

A fifth generated form, `TomGroupedSelect`, is declared in the
object-persistence module because it is built from that module's aggregate
nodes; it renders `SELECT <group columns + aggregates> FROM … WHERE …
GROUP BY … [HAVING …]` out of the [aggregate fragments](#aggregate-fragments)
above. It is the one query whose rows are not entities, so a driver treats it
specially — see [Reading rows](#reading-rows).

## Finding Placeholders in Quoted SQL

The dialect renders a bound parameter as `:name` (`TomStandardSqlDialect.p`) and
inlines a string literal with its own escaping (`text` doubles single quotes,
and backslashes too in MariaDB's dialect). Two consumers then have to find those
placeholders again in the finished text: a SQL driver rewrites each one to a
positional slot — `?` for MariaDB, `$1`, `$2`, … for PostgreSQL — and the CRUD
repository extracts their names to bind a raw statement.

Finding them by regular expression looks obvious and is wrong, because a regex
has no notion of string-literal context. In

```sql
WHERE a = 'x:y' AND b = :p
```

`:y` is four characters inside a value, not a bind — but `:([A-Za-z_]\w*)` sees
two placeholders. The datasource then emits two `?` and reports two names, so
every positional slot from that point on is bound to the wrong value. That was a
real defect, and it was two defects, because both consumers carried their
own copy of the same regex.

`SqlPlaceholderScan` is the one implementation they now share. It walks the SQL
a character at a time, copies the contents of a quoted span verbatim, and
recognises `:name` only in ordinary text:

```dart
SqlPlaceholderScan.toPositional("WHERE a = 'x:y' AND b = :p");
// ("WHERE a = 'x:y' AND b = ?", ['p'])

SqlPlaceholderScan.extractNames('WHERE a = :first OR b = :second');
// ['first', 'second']
```

`toPositional` returns the rewritten SQL together with the names in the exact
left-to-right order the slots appear — repeats included, because a repeated
name is a repeated slot and the driver binds by position. `extractNames` is the
same walk with the rewrite discarded. A `::` is copied as it stands and never
read as a placeholder, because in PostgreSQL it is a cast (`created::date`).

Two named arguments adapt the walk to a driver. `slot` renders the placeholder
for the slot at a 0-based index — `?` when it is omitted; the PostgreSQL driver
passes `(i) => '\$${i + 1}'`. `backslashEscapes` (default `true`) says whether a
backslash escapes the next character inside a string literal:

```dart
SqlPlaceholderScan.toPositional(
  r"WHERE path = 'C:\' AND id = :id",
  slot: (i) => '\$${i + 1}',
  backslashEscapes: false,
);
// (r"WHERE path = 'C:\' AND id = $1", ['id'])
```

Three quoting forms are skipped, each with the escape rule its delimiter
actually uses:

| Span | Escapes |
| ---- | ------- |
| `'…'` and `"…"` (string literals) | a doubled delimiter (`''`, `""`) is an escaped delimiter that keeps the scan inside the literal; a backslash escapes the next character too when `backslashEscapes` is set (MariaDB's default mode) — PostgreSQL reads `'\'` as a literal backslash, and the quote after it closes the literal |
| `` `…` `` (identifiers) | a doubled backtick only — MySQL/MariaDB identifiers have **no** backslash escaping, so a backslash there is an ordinary character |

Getting the backtick rule wrong would not break generated SQL: a generated
identifier is a Dart field name and never contains a colon. It is a robustness
guard for hand-written and future statements, and it is cheap precisely
because the walk already exists.

## Data Sources and Drivers

`TomDataSource` is the abstract contract a database driver implements: its
`sqlDialect`, lifecycle (`initialize` / `close` / `isOperational`), and
execution surface (`prepareStatement`, `executeCommand` for writes returning an
affected-row count, `executeQuery` for reads). It is a
`TomTransactionParticipant`, and a SQL data source (`TomSqlDatasource`) enlists
itself in the running transaction on the first statement it issues inside one (see
[transactions](transactions.md)).

A driver registers by annotating its class with `@TomDatasourceDriver("<type>")`
and `@tomReflector`. `TomDataSource.createDatasourceOf(type)` discovers drivers
by scanning reflection metadata on first use and returns a fresh instance.
Both steps refuse a registry they cannot trust, with a
`TomDatasourceInitException`:

| Key | Raised when |
| --- | ----------- |
| `tom_datasource.initialize_datasource_types.duplicate_driver` | two driver classes claim the same `<type>` |
| `tom_datasource.initialize_datasource_types.driver_instantiation_failed` | the scan cannot construct an annotated driver class |
| `tom_datasource.initialize_datasource_types.invalid_driver_not_implementing_datasource` | an annotated class is not a `TomDataSource` |
| `tom_datasource.create_datasource_of.no_driver_found` | `createDatasourceOf` is asked for a type no driver registered |
| `tom_datasource.create_datasource_of.driver_instantiation_failed` | the registered driver class fails to construct |
| `tom_datasource.create_datasource_of.invalid_driver_not_implementing_datasource` | what it constructed is not a `TomDataSource` |

`TomDataSourceInfo` is the process-wide registry of *named, configured* data
sources. `initializeDatasourceInfo(config)` builds an entry per map-valued
configuration key and opens each data source; `getDataSourceInfo(name)` looks one
up; `closeAll()` shuts them down. A `delegateTo` setting aliases one name onto
another already-registered data source instead of opening a second one, so the
two names share its pool:

```dart
await TomDataSourceInfo.initializeDatasourceInfo({
  'main': {'type': 'mariadb', 'host': 'db', 'port': 3306, 'username': 'app', 'password': '…', 'databaseName': 'app'},
  'reporting': {'delegateTo': 'main'},
});
final ds = TomDataSourceInfo.getDataSourceInfo('main')!.datasource;
```

A block names either a `type` or a `delegateTo`; one with neither is
`tom_datasource_info.initialize.no_type_specified`. A delegate is resolved
against the entries already registered, so it must come after the block it
names — otherwise it is `tom_datasource_info.initialize.delegate_not_found`.
Reading `datasource` from an entry that was never initialised throws
`tom_datasource_info.get_datasource.datasource_is_null` rather than answering
`null`, and `isOperational` answers `false`.

### Every settings key has to bind

`type` and `delegateTo` are the registry's own — `type` selects the driver,
`delegateTo` makes the entry an alias — and neither is a field of any driver.
They are **removed** from the block before it reaches the driver, so a driver is
handed only what is addressed to it.

Everything that remains has to name a field the configured driver declares. A
key that names none fails the start-up with a `TomDatasourceInitException`
carrying `tom_datasource_info.initialize.unknown_setting`, whose `parameters`
give the data source under `datasource` and the offending keys under `keys`:

```
Datasource 'app_db' (type 'mariadb') is configured with a setting 'database'
that names no field of MariaDbDatasource. Check the spelling in the datasource
configuration for 'app_db'.
```

Both halves of that message are load-bearing: the key is what to fix, and the
data-source name is which block to open. Every offending key is listed, so a
block with two typos in it takes one restart to correct rather than two.

The check is the registry's rather than each driver's, which is what puts the
data-source name in the message — a driver never learns the name it was
configured under — and what makes the guarantee hold for a driver the framework
never saw. The field set is read off *that* driver through reflection, so a
deployment's own driver is checked against its own settings, not against
MariaDB's.

Bind-time tolerance is right on the wire, where the sender may be newer than the
receiver, and the shared `tomReflectionInfo` still provides it. It is wrong for
a file the operator wrote against a driver whose field set is fixed and shipped:
absorbed, a misspelling surfaces much later as a connection error that names
neither the schema nor the credentials the driver was never given, and never
mentions the key that caused it.

### Routing per tenant

The registry answers by name, and in a multi-tenant deployment the answer
depends on the tenant in context. `TomDataSourceInfo.router` is the seam: a
function from a registered data source to the one the current tenant's data
lives in. The `tenancy` module installs it (`TomTenancy.install`); this module
declares it, so it does not depend on tenancy.

| Lookup | Answer |
| ------ | ------ |
| `TomDataSourceInfo.getDataSourceInfo(name)` | The registered data source **as the current tenant reaches it** — its schema or its database under schema or database isolation, the registered one otherwise. `null` when nothing is registered under `name`. |
| `TomDataSourceInfo.route(info)` | `info` as the current tenant reaches it — `router(info)`, or `info` itself when no router is installed. |
| `TomDataSourceInfo.getBaseDataSourceInfo(name)` | The registered data source itself, unrouted, whatever tenant is in context. |

A repository resolves its data source through `route` on every call, so one
repository serves every tenant. A framework store — the job queue, the leases,
the invalidation log — is built once over a data source and keeps it, which is
what keeps the framework's tables deployment-wide. With no router installed,
`getDataSourceInfo` and `getBaseDataSourceInfo` answer the same. See
[tenancy.md](tenancy.md#how-a-data-source-is-routed) for the routing rules.

### What one execution reports

A `TomPreparedStatement` is run two ways. `execute(params)` returns the mapped
rows and nothing else. `run(params)` returns a `TomStatementOutcome` carrying
everything that one execution reported:

| Member | Type | What it is |
| ------ | ---- | ---------- |
| `rows` | `List<T>` | The mapped result rows; empty for a statement that returns none. |
| `affectedRows` | `int` | The rows the execution changed — the count an `UPDATE` or `DELETE` reports, `0` for one that changed nothing. MariaDB counts rows *changed*, not matched, so an `UPDATE` writing the values already present reports `0`. |
| `generatedId` | `int?` | The auto-increment / identity key the execution produced, or `null` when it produced none. On PostgreSQL, the single integer an `INSERT … RETURNING` answered (see below). |

The outcome is returned **by the execution it describes** rather than kept on
the statement, because a statement is shared. A repository prepares each of its
statements once for the life of the process and runs it from every request at
once, so state on the handle would belong to whichever execution finished last:
two saves overlapping on one handle would each read the other's count or key.
For a versioned update that is not a cosmetic slip — a refused save that read
"one row changed" from somebody else's update would report success (see
[Optimistic Locking](object_persistence.md#optimistic-locking)).

The layers above act on each member. `TomSqlDatasourceRepository.save` takes a
freshly inserted row's surrogate key from `generatedId`, and refuses the insert
by name (`crud_repository.save.no_generated_key`) when there is none rather than
store a row under a key that is not its own; the delete methods return
`affectedRows` as *the* number of rows removed; and a versioned update or
`delete(entity)` reads `0` there as a conflict.

`generatedId` has to come from the driver, read from the insert's own result. A
follow-up `SELECT LAST_INSERT_ID()` from any layer above reads the *session's*
last value and answers `0` on another connection, and only the driver knows which
connection the insert ran on. `TomSqlPreparedStatement.run` reads all three from
the one result its execution produced — including on the retry after a lost
connection. The MariaDB driver maps the client's `0` ("no generated key") to
`null`, since a real `AUTO_INCREMENT` value is never `0`
(`MariadbPreparedStatement.normalizeGeneratedId`). PostgreSQL has no last-insert
id, so the key is asked for in the statement itself: the dialect's
`returningKey(insert, keyColumn)` appends `RETURNING keyColumn` (and leaves the
insert unchanged on MariaDB), and the PostgreSQL driver reports the one integer
an `INSERT … RETURNING` of one row and one column answered as the generated id.
The repository's insert goes through `returningKey` for an entity with a single
surrogate key, so `save` reads the key the same way on both.

## When a Write Fails

A write that throws has two very different meanings, and the exception does not
say which one it is.

If the **server answered** — "duplicate key", "deadlock, transaction rolled
back", "syntax error" — the statement definitively did not take effect, and the
caller may treat the failure as a clean no-op. If the **connection** failed, the
caller learned nothing: the statement may have been received, executed and
committed, with only the acknowledgement lost. The write may well have happened.

For most statements the distinction does not matter, because the caller retries
or gives up either way. It matters wherever the affected-row count **is** the
answer to a question — an exclusive claim, a compare-and-set takeover — because
there "the write failed" and "I did not get it" become two different statements,
and conflating them hands ownership to a node that believes it owns nothing.

`classifySqlFailure(Object? error)` answers the question as a
`TomSqlFailureMode`:

| Value | Meaning | What a caller does with it |
| ----- | ------- | -------------------------- |
| `definite` | The server answered with an error; the statement did not take effect | Treat it as a clean no-op — rethrow, retry, or report, whichever the operation calls for |
| `ambiguous` | The failure was on the way to or from the server; the write may have been applied | Do not assume. Re-read the state and believe what it says |

### Why the test recognises the *definite* side

The obvious implementation is a list of transport failures — socket closed,
broken pipe, TLS reset, timeout — treated as ambiguous, everything else as
definite. That list is open-ended: it grows with every driver, proxy, container
runtime and platform, and each omission is a silent correctness bug that only
appears under a network fault.

The other side is closed and recognisable. "The server sent back an error" is
exactly one thing per driver — a `MySQLServerException` from MariaDB, a
`ServerException` from PostgreSQL, each carrying the server's own error code —
and it is the only case in which the outcome is known. So the test is
inverted: **definite when the server answered, ambiguous otherwise.** Every
unrecognised failure, including one from a driver that did not exist when this
was written, lands on the safe side by default rather than by enumeration.

The asymmetry of the costs is what makes that the right default. Deciding
`ambiguous` when the truth was `definite` costs one extra `SELECT` that finds
nothing changed. Deciding `definite` when the truth was `ambiguous` is the bug
the classifier exists to prevent.

### Walking the chain

`classifySqlFailure` does not inspect the exception it is handed — it walks the
`rootException` chain, because the data source wraps driver failures — a failed
`executeQuery` as `error.failed-to-execute.exception`, a failed
`executeCommand` as `error.result_processing.executecommand_failed` — and the
server's exception is typically a link or two down inside the driver's
`TomSqlDatasourceException` subtype. The walk is bounded (8 links) so a cyclic or
pathologically nested chain cannot spin; wrapping is two links deep in practice.

`sqlFailureCauses(Object? error)` exposes that same walk — `error` and every
`rootException` beneath it, outermost first. It is public because a caller that
has decided a failure is ambiguous usually wants to log *what* it was, and the
driver exception worth naming is several wrappers down.

The scheduler's job store is the module that needs all of this; see
[`scheduling.md`](scheduling.md#when-the-answer-to-a-claim-is-lost) for the
claim path that consumes it.

### Deciding whether to retry

`isLostConnectionFailure(Object? error, {required bool connected})` answers a
neighbouring but distinct question: not *did the write happen*, but *is there
any point trying again*. Both drivers answer `TomSqlDatasource.isLostConnection`
with it, and `TomSqlPreparedStatement.run` uses that for its one retry on another
connection.

It is `true` when both halves hold:

| Half | Reads | Why it is needed |
| ---- | ----- | ---------------- |
| `!connected` | The driver's own record of whether the connection the statement ran on is up (`MySQLConnection.connected`, PostgreSQL's `Connection.isOpen`), at the moment the failure was caught | The exception alone cannot say. The MariaDB client reports a link it knows is gone as a bare `MySQLClientException` carrying no error code, and raises that *same type* for a protocol desync, a second `BEGIN` and a failed handshake — so the type would retry failures a second attempt cannot fix. Every "connection closed" the client throws sits behind its own `!connected` guard, so the flag recognises exactly those. |
| `classifySqlFailure(error) == ambiguous` | The `rootException` chain | A server exception anywhere beneath means the server received the statement and rejected it. That verdict stands however the link looks afterwards, and retrying would re-run a statement the server has already judged — for a write, one whose effect is unknown. |

Neither half is matched against message text. Binding a retry to the wording of
a third-party `toString` makes the driver's behaviour change on a dependency
bump, silently and with no compile error.

Because the type returned *is* the signal — `run` catches
`TomSqlConnectionLostException` (the driver's subtype, keyed
`error.failed-to-execute.connection_closed`) and nothing else, while every other
failure is the driver's `TomSqlDatasourceException` subtype keyed
`error.failed-to-execute.exception` — both branches attach the driver exception
as `rootException`. Without it the chain ends
at this layer and `classifySqlFailure` can never reach the server's own verdict.

The retry happens only **outside a transaction**. There the lost connection is
discarded, the pool lends a working one, and the statement runs again on it. A
statement inside a transaction has nothing to retry on: the transaction lived on
the connection that was lost, and running the statement on another would run it
outside the transaction it belongs to. So inside one the failure is the
driver's `TomSqlDatasourceException` subtype keyed
`error.failed-to-execute.transaction_connection_lost`, carrying the
`connection_closed` exception as its `rootException`, and the transaction is
concluded by its owner as any failed transaction is.

## The Connection Pool

A connection carries one transaction at a time: every statement on it between
`START TRANSACTION` and `COMMIT` belongs to that transaction, whoever issued
it. So a data source serves concurrent transactions only by giving each one a
connection of its own. `TomConnectionPool<C>` is where those connections come
from: it lends one per caller, up to a bound, and takes it back for reuse.

The pool knows nothing about any database. A driver supplies a
`TomConnectionFactory<C>` for its own connection type and decides what a lease
is held for:

| Factory member | What the pool uses it for |
| -------------- | ------------------------- |
| `open()` | Opening a connection when none is idle and there is room. A failure propagates to the `acquire` that needed it, and frees the slot it had reserved |
| `close(connection)` | Retiring a connection. Called once per connection; a failure is the driver's to log and never reaches the pool's caller |
| `isUsable(connection)` | The driver's own record of whether the link is up, asked without a round trip before a connection is lent and when it is handed back |
| `validate(connection)` | Asking the server whether the connection still works (a `SELECT 1`), for a connection that sat idle past `validateAfterIdle` |

`acquire()` lends a connection and `release(connection)` takes it back. A
released connection goes to the caller that has waited longest, so a later
caller cannot overtake an earlier one; with nobody waiting it joins the idle
connections, and the most recently released idle connection is lent first, so
the rest age out. Releasing a connection the pool did not lend is a
bookkeeping bug in the caller and throws `StateError`. `release(connection,
discard: true)` closes the connection instead of keeping it.

`TomConnectionPoolSettings` sizes the pool and decides when a connection is
retired. The defaults are those common to JDBC pools, HikariCP among them:

| Setting | Default | Meaning |
| ------- | ------- | ------- |
| `maxSize` | `10` | The most connections open at once, lent or idle. At least 1 |
| `minIdle` | `0` | Idle connections kept open past the idle timeout, and refilled in the background when a connection is discarded on its return. At most `maxSize`; `0` opens connections only when they are asked for |
| `acquireTimeout` | 30 s | How long `acquire` waits when all `maxSize` connections are lent |
| `idleTimeout` | 10 min | How long a connection may sit idle before it is closed, while more than `minIdle` are idle |
| `maxLifetime` | 30 min | How long a connection is used at all before it is replaced, bounding what a long-lived session accumulates and staying clear of the server's own idle disconnect |
| `validateAfterIdle` | 30 s | A connection idle longer than this is validated before it is lent, and replaced if the check fails; a shorter idle period is trusted |

The pool calls `validate()` on its settings when it is built, and settings it
cannot use — `maxSize` below 1, `minIdle` outside `0..maxSize`, a timeout that
is not positive, a negative `validateAfterIdle` — are refused with
`error.datasource.pool.invalid_settings`, its `fault` parameter naming which.

**Retirement is lazy.** A connection past its idle timeout or its lifetime is
closed the next time the pool is used — on an `acquire` or a `release` — not by
a timer. A pool with no traffic closes its idle connections when traffic
resumes. A timer would keep a process that never closes its data source from
exiting. A connection that is no longer usable or past its lifetime is closed
when it is handed back, and one found that way among the idle connections is
skipped and closed rather than lent.

**Waiting is bounded.** With every connection lent, `acquire` waits in line.
When a connection is released it is handed straight to the first waiter; when
one is discarded, or an open fails, the first waiter is woken to try again with
the slot that freed up. A waiter still without a connection after
`acquireTimeout` fails with `error.datasource.pool.acquire_timeout`, carrying
`maxSize` and `timeoutMs`.

**Closing** closes the idle connections at once and every lent one when it is
handed back, and fails every waiter with `error.datasource.pool.closed`; an
`acquire` after `close` is refused with the same key. Closing twice does
nothing.

Every refusal is a `TomConnectionPoolException`, a `TomServerException` raised
with `clientThrow: false`: the condition is the server's, and its key is what an
operator matches on. `size`, `lentCount`, `idleCount`, `waitingCount`,
`connections`, `idleConnections`, `isLent(connection)` and `isClosed` describe
the pool's state, and `toString` summarises it.

## The SQL Drivers

Two drivers ship, and they share everything that does not depend on the
database. `TomSqlDatasource` (`sql_datasource.dart`) holds the connection pool,
the transaction a connection is pinned to, the statement paths, the row mapping
and the settings binding, once; a driver extends it and supplies the wire — how
a connection is opened, how a statement runs on it, how its results read as
text, which words open and close a transaction:

| Configured `type` | Driver | Database | Transactions |
| ----------------- | ------ | -------- | ------------ |
| `mariadb` | `MariaDbDatasource` | MariaDB / MySQL, over `mysql_client` | `START TRANSACTION` / `COMMIT` / `ROLLBACK` |
| `mariadb_xa` | `MariaDbXADatasource` | the same | XA two-phase: `XA START` / `XA END` + `XA PREPARE` / `XA COMMIT` / `XA ROLLBACK` |
| `postgresql` | `PostgresDatasource` | PostgreSQL 15 and later, over `package:postgres` | `BEGIN` / `COMMIT` / `ROLLBACK` |
| `postgresql_xa` | `PostgresXADatasource` | the same | two-phase: `BEGIN` / `PREPARE TRANSACTION` / `COMMIT PREPARED` / `ROLLBACK [PREPARED]` |

Because every rule below lives in the base, the two drivers cannot drift apart
on one that has nothing to do with which server is on the other end: the
connection a statement runs on, when a data source counts as open, the
one-statement rule, the retry after a lost connection, the five row shapes and
their failure keys, and the transaction guard are the same code for both. Each
driver throws its own subtypes of the two base exceptions
(`TomSqlDatasourceException`, `TomSqlConnectionLostException`), so a log names
the database while a caller catching any of them catches the base type.

### Settings

Settings are filled from the configuration map by reflection in `initialize`,
which then opens the data source. Every setting bound to an `int` may also be
given as a string holding one — an environment substitution such as
`port: ${DB_PORT:3306}` always yields a string — and `normalizeSettings` folds
those before binding; the keys it folds are `TomSqlDatasource.integerSettings`.
A `port` that is neither an integer nor a string holding one is refused with
`error.initialize.invalid_port`; any other integer setting that is not is
refused with `error.initialize.invalid_integer`, whose `setting` and `value`
parameters name it. Every key in the block has to name a field of the
configured driver ([Every settings key has to bind](#every-settings-key-has-to-bind)).

| Key | Drivers | Default | Meaning |
| --- | ------- | ------- | ------- |
| `host` | both | `""` | The database host. |
| `port` | both | `5432` on PostgreSQL; unset (`-1`) on MariaDB | The database port. |
| `username` / `password` | both | `""` | The credentials. |
| `databaseName` | both | `""` | The database. Empty selects no default database on MariaDB and the `postgres` database on PostgreSQL. |
| `timeOut` | both | `10000` | The connect timeout, in milliseconds. |
| `poolMaxSize` … `poolValidateAfterIdleMs` | both | see [Connections](#connections) | The six pool settings. |
| `schema` | PostgreSQL | `""` | The schema unqualified names resolve in — set as the session's `search_path` when a connection opens. Empty keeps the server's default (`public`). |
| `sslMode` | PostgreSQL | `require` | `disable`, `require` (encrypt, accept any certificate) or `verifyFull` (encrypt and verify the certificate). Anything else fails the first connection with `error.initialize.invalid_ssl_mode`, its `sslMode` parameter naming the value. `require` unless set, so a deployment that has not thought about it still encrypts. |

```yaml
datasources:
  main:
    type: postgresql
    host: db
    port: ${DB_PORT:5432}
    databaseName: app
    schema: app
    sslMode: verifyFull
    username: app
    password: secret
    poolMaxSize: 20
```

Opening creates the pool and opens its first connection, so a server that
cannot be reached or refuses the session fails `connect` with the client
library's own error, and a `connect` that returns has reached its database.
`executeQuery` maps result rows back onto annotated `@tomReflector` entity
classes (including JSON columns, custom converters, and reference-field
dereferencing) — see [Reading rows](#reading-rows).

### Connections

The data source holds a `TomConnectionPool` of `TomSqlLink`s — each driver's own
connection wrapped with the server-side statements prepared on it — and one
method, `withLink`, chooses the connection for every statement, whichever entry
point it arrives through:

| The statement | Runs on |
| ------------- | ------- |
| Inside a running transaction | The connection pinned to that transaction. Its first statement on this data source enlists the data source in the transaction, which takes a connection from the pool; every later statement of the transaction runs on the same one; `endTransaction` hands it back |
| Outside any transaction | A connection lent for that statement alone and handed back when it completes — discarded instead when it went down while in use |

So **concurrent transactions run side by side**, each on its own connection,
and a statement outside a transaction never runs inside somebody else's. A
caller waits only when all `poolMaxSize` connections are lent, for at most
`poolAcquireTimeoutMs`, after which the statement fails with
`error.datasource.pool.acquire_timeout`. Statements of one transaction issued
concurrently start it once: the ones that arrive while the first is still
issuing its begin statement wait for it rather than start it again. A
transaction's connection and any two-phase branch it opened are held in a
`TomSqlBranch`.

The pool is configured through six fields, bound like every other setting:

| Key | Default | Pool setting |
| --- | ------- | ------------ |
| `poolMaxSize` | `10` | `maxSize` |
| `poolMinIdle` | `0` | `minIdle` |
| `poolAcquireTimeoutMs` | `30000` | `acquireTimeout` |
| `poolIdleTimeoutMs` | `600000` | `idleTimeout` |
| `poolMaxLifetimeMs` | `1800000` | `maxLifetime` |
| `poolValidateAfterIdleMs` | `30000` | `validateAfterIdle` |

```yaml
datasources:
  main:
    type: mariadb
    host: db
    port: ${DB_PORT:3306}
    databaseName: app
    username: app
    password: secret
    poolMaxSize: 20
    poolAcquireTimeoutMs: 5000
```

`poolSettings` is the `TomConnectionPoolSettings` those fields describe, and is
read when the data source is opened. `openConnectionCount` and
`lentConnectionCount` report how many connections the pool holds and how many
are lent; `toString` reads `open (N lent, M idle)` while the data source is
open.

**A prepared statement belongs to no connection.** A server-side prepared
statement lives on one connection, while a `TomSqlPreparedStatement` runs on
whichever connection the rule above selects. Each pooled connection therefore
prepares the statement's `command` the first time it runs it and keeps the
server-side statement for the next run, so a repository prepares a statement
once and keeps it for the life of the process. `prepareStatement` prepares it
on the connection its own zone selects, so a statement the server cannot compile
fails there rather than at its first execution. `deallocate` forgets the
statement on every connection; each connection frees it the next time it is
handed back, so nothing is freed under a statement that is running.

### The connection lifecycle

**A data source is opened explicitly, and never by the statement that wants to
run.** Opening it means one of the two forms the package documents:
`initialize(settings)`, which binds the configuration and opens the data source,
or setting the fields directly and calling `connect()`. Calling `connect()` on
an open data source does nothing.

Every execution entry point then observes the same rule:

| State of the data source | What an entry point does |
| ------------------------ | ------------------------ |
| Never opened | Throws `error.datasource.not_opened`, with `state: "never_opened"`. Nothing dials out |
| Closed | Throws the same `error.datasource.not_opened`, with `state: "closed"`. Nothing dials out |
| Open, and a connection has dropped | The pool discards it and lends a working connection, opening one if need be |
| Open | Runs the statement on the connection [Connections](#connections) selects |

Both refusals also name the calling entry point in the exception's `operation`
parameter, so a log says which call ran too early.

Opening on demand is not offered because it could not work. The pool opens
connections with `host`, `port` and the credentials, and those arrive only from
`initialize` or a direct assignment; before either, `host` is `""`. An implicit
connect could therefore never succeed — it could only turn "this data source was
never opened" into "the database is unreachable", sending the reader to the
network for what is a configuration bug.

Re-opening a *closed* data source, by contrast, would work — and that is exactly
why it must not happen by itself. `close()` is the application saying it is done
with this data source; a statement that quietly re-opened it would resurrect
something deliberately let go, and on the shutdown path would open a socket that
nothing is left to close. So `close()` closes the pool **and lets go of it**,
putting the data source back to not-open. Idle connections are closed at once; a
connection still lent — to a transaction, or to a running statement — is closed
when it is handed back. A connection that fails to close is logged and dropped,
and `close()` completes normally: the caller is done with it either way.

Which of the two not-open states it is rides in the `state` parameter and in
`toString`, rather than in the key: a caller matching "this data source has no
connection" should not have to match twice, but a reader diagnosing it needs the
distinction, because the two point at different faults — `never_opened` at
configuration or start-up ordering, `closed` at shutdown ordering. Closing a
data source that was never opened releases nothing and leaves it reading as
never opened.

The dropped-connection row is the half that must survive all of this. It is
the one case the driver repairs, because the caller never asked for the loss:
the settings are known, so a fresh connection is exactly what it wants and it
arrives without being asked. Only outside a transaction, though — a transaction
whose connection dropped has lost its work, and is reported as
`error.failed-to-execute.transaction_connection_lost` (see
[Deciding whether to retry](#deciding-whether-to-retry)).

`isOperational()` answers whether the data source is open and can reach its
database: open, and either holding a live connection or — holding none, because
the pool retired them all — having opened the last one it tried. `connected` answers the narrower
question of whether it is open and at least one of its connections is
established.

One private helper, `_requirePool(operation)`, is the only implementation of
the refusal, and one, `withLink`, the only place a connection is chosen. Every
site that needs a connection goes through both — `prepareStatement`,
`executeQuery`, `executeCommand`, the MariaDB driver's `withDriverConnection` and
a prepared statement's `run` — so the same data source is usable or unusable the
same way whichever method a caller reaches for first.

### One statement per call

`executeQuery` and `executeCommand` take **one SQL statement** and refuse more
with `error.datasource.multiple_statements`, carrying the `operation`, the
`statements` count and the `command`. The check runs before a connection is
touched, and it is quote- and comment-aware (`TomSqlLexer.splitStatements`): a
terminating `;`, and a `;` inside a literal, a quoted identifier or a comment,
do not count.

The reason differs by driver and the rule does not. `mysql_client` completes a
call on the first reply it reads and never checks whether more follow, so every
reply after the first stays on the wire and is read by the *next* call on the
same connection — which is then answered by its predecessor's reply, for the
rest of the connection's life. Nothing reports it: a query comes back empty, an
`XA COMMIT` returns before the server has committed, and an error in any
statement after the first is never raised at all. PostgreSQL's extended
protocol refuses a second statement outright. A script is split first; the
migration adaptors do exactly that.

### Reading rows

**Every column is read as text, in one convention.** A driver hands its rows to
the shared mapper as `TomSqlRow`s, whose `text`, `temporalText` and `boolean`
answer each column as: an instant as `YYYY-MM-DD HH:MM:SS.ffffff` in UTC
(`sqlInstant`), a date as `YYYY-MM-DD`, a time as `HH:MM:SS`, a number as its
decimal digits, a truth value as `1` or `0`. That is how the MariaDB protocol
delivers values anyway; the PostgreSQL driver, whose protocol delivers typed
values, renders them into it. The mapper therefore reads one representation,
with one set of parsers and one set of failure keys, whichever database a row
came from. A statement's rows, its affected-row count and its generated key
arrive together as a `TomSqlResult`.

The same holds on the way in. `tomSqlBindValue` marshals every bind value of
both statement paths the same way for both drivers: a `TomDbType` box is
unwrapped, a `bool` becomes `1`/`0`, a `TomZonedDate` its `DATE` text, a
`TomZonedTime` its `TIME` text and any other `DateTime` its UTC instant text.
MariaDB has no boolean type and rejects both a bound `'false'` and an instant
ending in `Z`; PostgreSQL, sent each value as text of unspecified type, reads
the same text correctly into a `SMALLINT`, a `BOOLEAN` or a `TIMESTAMP` column.

A grouped query takes a different path through the same mapper. A grouped row
has no entity class and no column metadata — its shape is decided by the query —
so `prepareStatement` copies the query's `projectionTypes` (alias → Dart type)
onto the prepared statement, and `mapGroupedRow` reads each alias as the type
the query declared for it, producing a `TomGroupedRow`. That runs before any
mirror is taken; an alias whose declared type is outside
`int`/`double`/`String`/`bool`/`DateTime` raises
`error.result_processing_grouped.unknown_type`.

**The shape decision is one public method.** `mapSqlResult` is the mapper's
largest decision, and which of five shapes a result takes is settled entirely by
what the result type declares (`MariaDbDatasource.mapResultSet` is the same
decision over a `mysql_client` result set):

| Result type | Bound by | A row that cannot be built | A member type it cannot read |
| ----------- | -------- | -------------------------- | ---------------------------- |
| any, with a grouped projection | the query's alias → type projection, into a `TomGroupedRow` | — | `error.result_processing_grouped.unknown_type` |
| a `TomClass` with no `@TomDbTable` | the observable member's own name | `error.result_processing_tcp.failed_to_instantiate_row` | `error.result_processing_tcp.unknown_type` |
| a `TomClass` with `@TomDbTable` | the `@TomDbColumn` name | `error.result_processing_tc.failed_to_instantiate_row` | `error.result_processing_tc.unknown_type` |
| a reflected holder with no `@TomDbTable` | the declared field name | `error.result_processing_field.failed_to_instantiate_row` | `error.result_processing_field.unknown_type` |
| a reflected entity with `@TomDbTable` | its persistent column list | `error.result_processing.failed_to_instantiate_row` | `error.result_processing.unknown_type` |

On the entity path a column can also be read through its declaration rather
than by type: a `fromDbConverter` that throws is
`error.result_processing.failed_custom_conversion`, and a JSON column whose text
does not decode into its declared type is
`error.result_processing.failed_json_conversion`; both carry the converter's
or decoder's exception as the root.

A column the result does not carry is skipped on **every** shape, so a
projection that selects a subset of an entity's columns maps rather than fails.
A result type the reflector does not hold is refused where the mirror is taken,
by `error.result_processing.unsuitable_class` naming the type — the one shape
the mapper cannot map, and the only outcome besides the five.

It is public, and takes a result rather than a connection, because nothing in
it needs a server: every column is already text, and only a `@TomReference`
column reaches back to the database. That column's own query is compiled,
rendered to SQL, run, and its rows added to the list the field already holds,
and each step that fails has its key:
`error.result_processing.ref_qsc_creation_failed` (no compiler for the target
and join entities), `error.result_processing.ref_query_compilation_failed`,
`error.result_processing.ref_query_generation_failed`,
`error.result_processing.ref_query_execution_failed`,
`error.result_processing.ref_failed_adding_result_to_value` and
`error.result_processing.ref_failed_invoke_setter`. A reference field holding
`null` has no list to fill and is
`error.result_processing.ref_reference_field_must_have_non-null_value`; anything
else that escapes the resolution is `error.result_processing.ref_failed_unexpected`.
That is what lets the whole decision be tested in the ordinary run
(`mariadb_row_mapping_test.dart`) instead of only where a database happens to be
listening.

> **Numeric columns are read as text, deliberately — on every path.**
> `mysql_client` converts a column to `double` only from a whitelist of protocol
> types (TINY, SHORT, LONG, LONGLONG, INT24, FLOAT, DOUBLE), and to `int` from a
> similar one. `DECIMAL`/`NEWDECIMAL` (protocol type 246) is in neither, so
> asking the driver for a number there throws `MySQLProtocolException` rather
> than widening. That is not an aggregate curiosity: `DECIMAL` is the correct SQL
> type for money, so an ordinary entity hits it on its first select —
> `SUM`/`AVG` over an integer column merely reach it first, which is how the gap
> was found. The mapper therefore reads the text and parses it in two shared
> helpers, `_readDouble` and `_readInt`, used by `mapGroupedRow` and by all four
> entity-mapping variants alike, for both drivers. Parsing here is lossless: the
> MariaDB driver's own conversion starts from exactly this text (the whitelist is
> a gate, not a decoder), and the PostgreSQL driver renders a `NUMERIC` as its
> exact digits. Text that is no number at all is refused by column name —
> `error.result_processing.not_a_double` for a `double` field,
> `error.result_processing.not_an_int` for an `int` one — so the failure names
> the column and the value, which a client's own conversion error does not.
>
> **Dates and times are refused the same way.** A stored instant, `DATE` or
> `TIME` is read through `parseSqlInstant`, `parseSqlDate` or
> `parseSqlTimeOfDay`, which are public parse functions and throw a
> `FormatException` as Dart's own parsers do. A stored row is data from outside
> the process, so the mapper converts: text none of them can read raises
> `error.result_processing.not_an_instant`, `error.result_processing.not_a_date`
> (a `DATE` column holding a timestamp) or `error.result_processing.not_a_time`
> (a `TIME` column holding an interval), naming the column and the value, with
> the parser's exception as the root. Every row shape goes through the one
> helper that does this, `_readTemporal`.
>
> **An `int`-declared field over a `DECIMAL` column is decided here, not by the
> driver.** `DECIMAL(n,0)` is a legitimate exact-integer mapping, so refusing
> every `DECIMAL`→`int` read would break real models; but reading `DECIMAL(10,2)`
> into an `int` and dropping the cents would turn a modelling mistake into wrong
> money that nothing downstream would catch. The encoded rule: **an exactly
> integral value is read, a fractional one is refused by name**
> (`error.result_processing.fractional_int`, naming the column and the value).
> Silent truncation never happens.

> **A `TomClass` result holder maps by observable member, nullable or not.**
> Two of the four entity-mapping variants take a `TomClass` rather than a
> reflected entity: without `@TomDbTable` the member's own name is the column
> name, with it the `@TomDbColumn` name is, and both then read the member
> according to the element type it declares. `TomObject<T>` reports that type
> *as declared*, so a `TomNString` answers `String?` rather than `String`, and
> the element type is therefore **normalised to its non-nullable counterpart
> before dispatch** — `int`, `double`, `String`, `bool` and `DateTime` are
> supported whether the member is the plain or the `TomN…` observable, and
> anything else raises `error.result_processing_tc.unknown_type` (with
> `@TomDbTable`) or `error.result_processing_tcp.unknown_type` (without) naming the
> type it refused. Normalising once is what keeps the two variants a single
> decision rather than two switches drifting apart.
>
> A SQL `NULL` reads as `null` for every one of those types. A member declared
> non-nullable over a column that is `NULL` therefore fails loudly, which is the
> intended outcome: the alternative — leaving the member holding whatever its
> field initialiser put there — presents a stale value as if it had been read.

### Transactions

As a transaction participant the plain driver is one-phase: its begin statement
(`START TRANSACTION` on MariaDB, `BEGIN` on PostgreSQL, each with a `READ ONLY`
form for a read-only transaction), then `COMMIT` or `ROLLBACK`, each issued on
the transaction's own connection. Every hook is handed the transaction it
concludes, which is how a data source serving several transactions at once knows
which connection a `commit` belongs to. `endTransaction` issues no statement — a
one-phase transaction has nothing to prepare — and **hands the transaction's
connection back to the pool**; the coordinator calls it on every participant
after either conclusion, which is what makes it the place the connection
returns. It always reports `true`, because the coordinator ands the
participants' results together and a `false` would fail a transaction that had
in fact completed.

The two-phase variants (`MariaDbXADatasource`, `PostgresXADatasource`) override
the lifecycle and keep a branch id per transaction, which each mints in
`startTransaction` with `tomSqlBranchId`:
`<database>@<host>:<port>_<process>_<time>_<counter>`, bounded to what the
server accepts — 64 bytes for an XA `gtrid`, 200 for a PostgreSQL prepared
transaction's id. The unique tail — a random per-process tag, the time in
microseconds and a per-process counter — is always kept whole, and the readable
head is what is truncated: a shortened name still tells an operator reading the
list of prepared transactions whose branch it is, while a shortened tail could
name two branches alike. Characters outside `[A-Za-z0-9_.@:-]` become `_`,
which keeps the id single-byte and safe to quote.

Concurrent two-phase transactions on one data source are separate branches.
The id doubles as the guard: a second start of the same transaction while its
branch is set throws rather than opening a nested branch. **Every exit clears
the id except a failing `prepare` and a failing `commit`.** A failing prepare
hands it on to `rollback`, which the coordinator issues in answer to the veto
and which has to name the branch; a failing commit leaves a prepared branch in
doubt, and the id is kept so it has a name. A start the database refused clears
it too: the branch never began, and a kept id would refuse every later start of
that transaction — which its caller cannot clear by rolling back, having just
been told the transaction did not begin.

**The statements map onto the coordinator's two phases.** `prepare` makes the
commit certain without performing it, `commit` performs it, and
`endTransaction` is the same no-op that reports success as on the one-phase
driver. It has to be this way round because `TomTransaction.commitTransaction`
drains its `commit` loop before it calls `endTransaction` on anyone, so a
prepare placed in `endTransaction` would run *after* the commit it is a
precondition of: the server refuses the commit of a branch that was never
prepared, the `false` reads as a veto, and the transaction becomes a rollback
with the branch left holding its locks.

All four lifecycles refuse a second start of the same transaction the same way,
through one shared helper (`refuseNestedTransaction`): the driver's
`TomSqlDatasourceException` subtype keyed **`error.transaction.already_active`**,
naming the participant and — for a two-phase driver, which has one — the branch
already open. Another transaction is not refused: it gets a connection of its
own. The type is the point. Starting a transaction has two ways of not
happening, and they are not the same kind of event:

| What happened | How the caller hears it | What the caller can do |
| ------------- | ----------------------- | ---------------------- |
| The database refused the begin statement | `startTransaction` returns `false` | Retry, route around it, or give up |
| The data source is already in this transaction | Throws `error.transaction.already_active` | Nothing — fix the code |

Which is why the guard sits **in front of** the `try`, not inside it. Inside,
the catch-all that turns a failed statement into `false` would swallow the
refusal and hand the caller the first row's answer for the second row's
situation. And it is thrown as the module's own type rather than a bare
`Exception` because `Exception` is the supertype of every failure there is: a
`catch` narrow enough to act on the one case the caller can fix cannot be
written against it.

### The MariaDB driver

`MariaDbDatasource` (`@TomDatasourceDriver("mariadb")`) connects to MariaDB /
MySQL through `mysql_client`. It binds positional `?` placeholders
(`toPositionalStatement`, over `SqlPlaceholderScan`) and renders SQL through
`MariadbSqlDialect`. `openConnection()` opens one `MySQLConnection` from the
configured settings; the pool calls it whenever it needs a connection, and a
test overrides it to hand out stand-in connections.
`normalizeIntegerSettings` and `parsePort` are the integer-settings folding
under static names, raising `MariadbDatasourceException`.

**`withDriverConnection(body)`** runs `body` with the `MySQLConnection` the
[Connections](#connections) rule selects — the transaction's when the data
source is enlisted in one, otherwise one lent for the call. It is for work that
needs the driver's own API: its typed row accessors, or a session-scoped lock
that must be taken and released on one connection. The connection must not be
kept beyond `body`.

Rows from a prepared statement arrive over MariaDB's binary protocol, where the
client writes a `DATETIME`'s microsecond field as a bare integer — 91 371 µs
becomes `.91371`, which every parser reads as 0.91371 s. The driver restores the
six-digit fraction in `temporalText` for exactly those rows: over the text
protocol the *server* formats the value with the column's precision, so the same
digits there mean what they say.

`MariaDbXADatasource` (`@TomDatasourceDriver("mariadb_xa")`) is the XA variant:
`prepare` issues `XA END` and then `XA PREPARE`, as two calls (see
[One statement per call](#one-statement-per-call)); `commit` issues `XA COMMIT`.
`XA START` has no read-only form in MariaDB or MySQL, so a read-only transaction
cannot be honoured on this data source; it is logged as unprotected rather than
silently ignored.

`rollback` ends the branch too, when it is still active. `XA END` is legal
exactly once and on an ACTIVE branch only, and it decides what the rollback may
issue: `XA ROLLBACK` is refused on an ACTIVE branch (`XAER_RMFAIL: The command
cannot be executed when global transaction is in the ACTIVE state`) and `XA END`
is refused on an IDLE or prepared one. A rollback can arrive in any of the three
states — before `prepare` ran, after its `XA END` succeeded and its
`XA PREPARE` did not, or after a prepare succeeded and the commit did not. So
the driver tracks whether the branch has been ended (`TomSqlBranch.ended`), and
issues `XA END` then `XA ROLLBACK` for an active branch and `XA ROLLBACK` alone
otherwise, rather than sending a statement and ignoring the failure — a rollback
the server refuses leaves the branch exactly where it was, and is reported as a
failed rollback.

### The PostgreSQL driver

`PostgresDatasource` (`@TomDatasourceDriver("postgresql")`) connects to
PostgreSQL 15 and later through `package:postgres`, and renders SQL through
`PostgresSqlDialect`. What differs from MariaDB is the wire, and each
difference is settled in the driver so that nothing above it has to know:

| PostgreSQL | What the driver does |
| ---------- | -------------------- |
| A session has a time zone, and `CURRENT_TIMESTAMP` reads in it | Every session runs with `TimeZone` set to `UTC`, so a server-side default writes in the zone the framework writes instants in. |
| Placeholders are `$1`, `$2`, …, and a backslash in a literal is itself | `toPositional` rewrites `:name` with `SqlPlaceholderScan.toPositional(slot: …, backslashEscapes: false)`, one slot per occurrence; `::` casts are left alone. |
| Parameters are typed | Every bind value is sent as text of **unspecified** type, so the server infers each parameter's type from where it is used — which is what lets the one marshalled `1` or instant text read into a `SMALLINT`, a `BOOLEAN` or a `TIMESTAMP` alike. A typed bind would have to know the column's type before the server does. |
| Results are typed values | Each value is rendered into the [text convention](#reading-rows): a timestamp through `sqlInstant`, a `date` through `sqlDate`, a `time` as `HH:MM:SS` (with a fraction only when there is one), a `bool` as `1`/`0`, `json`/`jsonb` as its JSON text, `bytea` as its UTF-8 text. |
| Unquoted identifiers fold to lower case | Result columns are matched without regard to case (`TomSqlResultValues.caseInsensitiveColumns`), so `SELECT due_at AS dueAt` answers the `dueAt` the mapper asks for. |
| No last-insert id | An `INSERT … RETURNING` answering one row of one integer column reports that integer as the generated id; the dialect asks for it (`returningKey`, `incrementCounter`). |
| A prepared statement whose table changed shape is refused — `cached plan must not change result type`, SQLSTATE `0A000` | The statement is dropped and prepared again, once, on that connection. MariaDB re-prepares such a statement on its own; without this, a migration that adds a column under a long-lived repository's `SELECT *` would need every pooled connection replaced. |
| A rejected statement is a `ServerException` | `classifySqlFailure` reads it as `definite`, exactly as it reads MariaDB's `MySQLServerException`. |

A schema-isolated tenant on PostgreSQL is a schema inside the one database:
`schema` is the setting that points a data source at it (the dialect's
`schemaSetting`), and its connections set `search_path` to it — see
[tenancy.md](tenancy.md).

`PostgresXADatasource` (`@TomDatasourceDriver("postgresql_xa")`) is the
two-phase variant over PostgreSQL's prepared transactions. `startTransaction`
issues `BEGIN` (`BEGIN READ ONLY` for a read-only transaction, which PostgreSQL
honours — unlike `XA START`); `prepare` issues `PREPARE TRANSACTION '<id>'`;
`commit` issues `COMMIT PREPARED '<id>'`; `rollback` issues `ROLLBACK` while the
transaction is still open and `ROLLBACK PREPARED '<id>'` once it has been
prepared. A prepared transaction survives a server restart and is resolved only
by those two statements — which is the promise the prepare phase asks every
participant for. A failed `PREPARE TRANSACTION` aborts the transaction on the
server, so the rollback that answers the veto finds an ordinary session and has
only to clear the branch; a failed `COMMIT PREPARED` leaves the branch in doubt,
named in `pg_prepared_xacts`.

**The server must allow prepared transactions.** `max_prepared_transactions` is
`0` by default, which makes every `PREPARE TRANSACTION` fail and so vetoes
every two-phase transaction a `postgresql_xa` data source joins. Raise it to at
least the number of two-phase transactions that may be prepared at once.

## Framework-Owned Tables

An application's tables are guarded end to end: the entity model declares a
shape, the migration chain builds one, and `TomSchemaConvergenceCheck` proves
the two agree. The framework's *own* tables — the job queue, the lease table,
the roll call, the blob pair, the audit trail — are not entities, so they sat
outside that guard entirely, and each declared its columns **twice**: once in a
`CREATE TABLE` string and again in the column lists of the statements that read
and write it. Nothing related the two.

That is a bad place for a divergence to live. A column renamed on one side and
not the other fails at runtime on a path that may only ever execute in
production — `recoverAbandoned` after a node dies, a chunk read of a large file
— and the framework's own tables are the ones a deployment is least able to
repair by hand.

`TomFrameworkTable` is that declaration, made once. Everything else is derived
from it:

| Derived | From |
| ------- | ---- |
| The create-if-missing DDL each store issues on first use, in the connected database's words | `create(datasource)`, `createStatements(dialect)` |
| The canonical DDL — the types as declared | `createTableDdl` |
| The column lists its statements interpolate | `columnList`, `columnsOf(names)` |
| Its row writes | `insertRow(dialect, values, ignoreConflict: …)`, `replaceStatements(dialect, values)`, `replaceRow(datasource, values, params)` |
| The `TomSchemaModel` the convergence guard compares | `db_migration/framework_convergence.dart`, which replays `createTableDdl` through the same `TomSchemaDdlReader` the migration side uses |

A `TomFrameworkColumn` carries a name, a SQL type, nullability, an optional
default and an auto-increment flag; a `TomFrameworkKey` carries the columns it
covers and whether it is unique. A key's *name* is built from the table's name
plus a suffix rather than given outright, because the table name is a
per-instance argument of the owning store — two stores over differently-named
tables in one schema would otherwise collide on an index name, and the second
`CREATE TABLE` would fail.

Every failure this type can catch, it catches as early as it can. A key part
that names no column throws at construction, because a descriptor is built once
at start-up and a typo there would otherwise surface as a `CREATE TABLE` failure
against a live server. `columnsOf` throws when a name is not a column, so a
projection that outlived the column it names fails at the first call. The row
writes key by column name rather than by position — a positional list would put the
column list and the value list in lock-step order, so inserting a column in the
descriptor would silently shift every value one place along, which type-checks
and is therefore worse than the failure this file exists to remove.

It lives here, and not in `db_migration/`, because the stores that own these
tables (`scheduling/`, `file_storage/`, `audit/`) already depend on
`datasources/` and must not be made to depend on the migration module — a
deployment can use the scheduler without ever running a migration. The
comparison is migration-shaped and lives there, depending on this file rather
than the other way round.

It is deliberately **not** a query builder. The statements in these stores are
conditional writes whose exact shape is load-bearing and documented at length —
the affected-row count of `UPDATE … WHERE state = 'pending'` *is* the
arbitration — so rendering them from a template would trade a readable invariant
for an unreadable one. What is generated is the part that is pure repetition:
the DDL and the column lists. Column references inside `SET`, `WHERE` and
`ORDER BY` stay written out, and are guarded by `unknownFrameworkColumns`,
which drives a store through a recording data source and audits every statement
it actually issued:

```dart
final jobs = jobRunTable('tom_job_run');

unknownFrameworkColumns('UPDATE tom_job_run SET state = :s '
    "WHERE state = 'pending'", [jobs]);
// []  — every identifier is a column, the table, or SQL

unknownFrameworkColumns('UPDATE tom_job_run SET stat = :s '
    'WHERE id = :i', [jobs]);
// ['stat']  — a rename the column lists could never have caught
```

The audit is conservative in the direction that matters. String literals, binds
and numbers are stripped before the scan and a fixed set of SQL words is
ignored; anything else that survives is reported. A word missing from that set
is a false positive in a test — noisy and self-correcting — whereas a missed
column reference is the production failure the whole file exists to prevent.

### One declaration, every database

A framework table is declared once, in a **canonical** type vocabulary —
MariaDB's spelling: `DATETIME(6)`, `TINYINT(1)`, `LONGTEXT`, `AUTO_INCREMENT`,
inline `KEY`s — and each database renders that declaration in its own words
through its dialect. `createTableDdl` is the canonical rendering, which the
convergence guard reads; `createStatements(dialect)` is the rendering a store
runs, and `create(datasource)` runs it in the data source's own dialect. The
canonical spelling is also the one the reference migrations are written in and
the convergence guard reads, so one declaration is compared against one chain;
each database's own spelling is derived from it, never written beside it.

| Canonical | MariaDB | PostgreSQL |
| --------- | ------- | ---------- |
| `DATETIME(6)` | as declared | `TIMESTAMP(6)` — both hold a wall reading with no zone; the framework writes UTC into it |
| `TINYINT(1)` | as declared | `SMALLINT` — a truth value is bound as `1`/`0` on every database, so it stays an integer |
| `INT`, `MEDIUMINT` | as declared | `INTEGER` |
| `DOUBLE` / `FLOAT` | as declared | `DOUBLE PRECISION` / `REAL` |
| `TINYTEXT`, `MEDIUMTEXT`, `LONGTEXT` | as declared | `TEXT` |
| `CHAR(n)` | as declared | `VARCHAR(n)` — PostgreSQL pads a `CHAR(n)` on read; MariaDB strips the padding, and the framework's code expects that |
| `BLOB` and its sizes, `VARBINARY(n)`, `BINARY(n)` | as declared | `BYTEA` |
| `ENUM(…)` | as declared | `VARCHAR(255)`, with a `CHECK` on the values when a canonical statement is translated |
| `… AUTO_INCREMENT` | as declared | `… GENERATED BY DEFAULT AS IDENTITY` |
| inline `KEY name (…)` | inline | a separate `CREATE INDEX IF NOT EXISTS` after the table |
| inline `UNIQUE KEY name (…)` | inline | `CONSTRAINT name UNIQUE (…)` |

A hand-written canonical statement — a migration script, a fixture table, a
store's own `CREATE TABLE` — goes through `translateCanonical(statement)`, which
returns the statements this database runs to the same effect (unchanged on
MariaDB), and `translateCanonicalScript(script)` does the same for a whole
`;`-separated script. On PostgreSQL that covers `CREATE TABLE` (each type
through the table above; `UNSIGNED`, `COMMENT`, `CHARACTER SET`, `COLLATE` and
`ON UPDATE CURRENT_TIMESTAMP` dropped, except that a binary collation such as
`utf8mb4_bin` becomes `COLLATE "C"`, both meaning case-sensitive identity and
code-unit order; a `TRUE`/`FALSE` default on a truth column as `1`/`0`; table
options dropped; an index name that does not already name its table prefixed
with it, because an index name is schema-wide in PostgreSQL), `ALTER TABLE …
ADD` and `… MODIFY` a column, MariaDB's refusing `SIGNAL SQLSTATE` trigger, and
`TRUNCATE` (with `RESTART IDENTITY`, as an `AUTO_INCREMENT` restarts). Backtick
quoting is removed throughout, so a name folds to lower case exactly as every
unquoted reference to it does. Leading comment lines stay on the first
statement.

The framework's conflicting writes are rendered the same way:

| Write | Dialect method | MariaDB | PostgreSQL |
| ----- | -------------- | ------- | ---------- |
| Insert, keeping a stored row on a key conflict | `insertInto(…, ignoreConflict: true)` | `INSERT IGNORE` | `INSERT … ON CONFLICT DO NOTHING` |
| Write a row over every row it supersedes | `replaceInto` | `REPLACE INTO` | `DELETE` of the superseded rows, then `INSERT … ON CONFLICT (<pk>) DO UPDATE` |
| Count one more and read the count, in one statement | `incrementCounter` | `ON DUPLICATE KEY UPDATE c = LAST_INSERT_ID(c + 1)` | `ON CONFLICT (…) DO UPDATE SET c = t.c + 1 RETURNING c` |
| Report a generated surrogate key | `returningKey` | unchanged — the last-insert id reports it | `… RETURNING <key>` |

**What "supersedes" means is MariaDB's `REPLACE`, kept.** `REPLACE` deletes the
row with the new row's primary key *and every row colliding with it on any
unique key*, then inserts. The second half is load-bearing: the job queue's
window key is how a second run for the same window supersedes the first, and an
upsert on the primary key alone would refuse that run as a duplicate. So
PostgreSQL's `replaceInto` deletes every row matching the new one on the primary
key or on a unique key whose columns the write supplies in full — a key over a
column the database generates cannot collide with a row the write has not given
it — and then inserts with `ON CONFLICT (<primary key>) DO UPDATE`, which
absorbs a writer that inserted the same key between the two statements. Two
statements, because one cannot do it: a row deleted by a `WITH` still holds its
key against the `INSERT` of the same statement. `replaceRow(datasource, values,
params)` runs them in one transaction when there are two, so no reader sees the
row missing.

`incrementCounter` takes and reads the count in one statement because a second
read is wrong under concurrency: every caller of a burst would see the final
total rather than its own place in it. The rate limiter is built on it.

### Creating a store's tables once

Each framework store creates its tables on first use, in `ensureSchema`. Two
requests reaching a fresh store at the same moment both see "not yet created";
with a connection pool their two `CREATE TABLE IF NOT EXISTS` run on two
connections, and the second can return — the table "exists" — before the first
has finished creating it, so the second request's statement fails on a table
that does not exist yet. A boolean flag set after the creation cannot close that
window.

`TomSchemaProvisioning` closes it by sharing the one creation in flight:
`ensure(create)` runs `create` once, and every caller — the first and every one
arriving while it runs — awaits the same future. A creation that fails is
forgotten, so the next call tries again rather than inheriting the failure for
the life of the store.

```dart
class TodoArchiveStore {
  TodoArchiveStore(this.datasource);

  final TomDataSource datasource;
  final TomSchemaProvisioning _schema = TomSchemaProvisioning();

  Future<void> ensureSchema() => _schema.ensure(() async {
    // archiveTableDdl is written in the canonical DDL; the dialect turns it
    // into the statements the connected database runs.
    for (final statement
        in datasource.sqlDialect.translateCanonical(archiveTableDdl)) {
      await datasource.executeCommand(statement);
    }
  });
}
```

All eight framework stores provision their tables this way: `TomSqlJobStore`,
`TomSqlLeaseLock`, `TomSqlSchedulerNodes`, `TomSqlDeliveryReportStore`,
`TomSqlInvalidationChannel`, `TomSqlOAuthStateStore`, `TomSqlScimStore` and
`TomDatabaseBlobStore`.

## Verification

Four suites cover the drivers, split by what needs a server rather than by
what is interesting, and one covers the connection pool. Two more cover the
framework-table declarations, split the same way, and three pin the module's
error vocabulary. Every suite that needs a server runs against both databases.

`test/connection_pool_test.dart` drives `TomConnectionPool` over a fake factory
and an injectable clock, so every timeout is asserted without waiting for it:
the default settings and the refusal of unusable ones, lending (nothing opened
until asked, a released connection reused, never more than `maxSize`, a failed
open freeing its slot), waiting (a waiter served by the next release, waiters in
arrival order, the typed timeout), retiring (a connection gone down replaced,
validation only after `validateAfterIdle`, the idle timeout and its `minIdle`
exemption, the lifetime) and closing.

`test/datasources_error_keys_test.dart`, `test/datasources_driver_scan_error_keys_test.dart`, `test/datasources_row_mapping_error_keys_test.dart` pin the module's error vocabulary: each case reaches a raise with a real input and asserts the exact key, so a key the module stops raising, or raises for a different condition, fails by name. None needs a database.

`test/datasources_test.dart` always runs, and reaches further into the driver
than "no connection" suggests. Beyond the dialect's SQL generation and the
`TomDbInt.of` / `TomDbBool.of` conversions it covers `MariadbPreparedStatement`'s
`buildPositionalParameters` and `normalizeGeneratedId`, its `run` — the count an
execution returned, the count on the retry after a lost connection, and two
overlapping executions of one handle each reporting their own —
`MariaDbDatasource.toPositionalStatement` and the placeholder scan it shares
with `crud_repository`, `sqlInstant` / `parseSqlInstant` /
`parseOptionalSqlInstant` — including the local-reading trap that
[Instants Are UTC](#instants-are-utc) exists to close — `parsePort` /
`normalizeIntegerSettings`, the `initializeDatasourceInfo` configuration guard,
`isLostConnectionFailure` — the retry decision described in
[When a Write Fails](#when-a-write-fails) — and the rule that a driver owns its
dialect. `escapeLikePattern` is covered here too, including the ordering that
makes it correct and the agreement between what it escapes and what the
rendered `ESCAPE` clause names; that the escaping actually changes which rows
match is settled where it has to be, against a live server, by
`object_persistence_db_test.dart`.

Two things there are worth knowing about, because they are what let a
connection-free suite assert connection behaviour at all. The **connection
lifecycle** table above is asserted state by state: never-opened, closed, and a
connection that dropped, each against every execution entry point, with
`openConnection` overridden to hand the pool stand-in connections. Over the same
stand-ins the suite runs **concurrent transactions**: a slow transaction does
not block another, every statement of a transaction runs on its one connection,
a statement outside any transaction borrows another, a transaction waits its
turn only when every connection is lent, concurrent statements of one
transaction start it once, and XA transactions side by side are separate
branches. It also covers a prepared statement on a pool — prepared once per
connection and reused, deallocated on every connection that prepared it once it
is handed back — and a lost connection inside a transaction not being retried.
And the **transaction state machine** is driven by overriding `executeCommand`
to script each command's outcome and record the SQL it was given, which is how a
failed `XA START` / `XA END` / `XA ROLLBACK` can be shown to clear the branch
id — a cleared id surfaces as the literal `XA COMMIT null`, so the recording is
the assertion.

`test/postgres_dialect_test.dart` covers the PostgreSQL side without a server:
the canonical vocabulary in PostgreSQL's words and PostgreSQL's own type names
classified into their families; a framework table created with an identity, a
unique constraint and a separate index while its canonical rendering stays what
the convergence guard reads; `translateCanonical` over a hand-written
`CREATE TABLE`, an added column, a `TRUNCATE`, a comment header, a refusing
trigger and a statement it leaves as written (and the identity on the standard
dialect); a backslash kept single in a literal, a truth value as `1`/`0`, a
generated key asked for with `RETURNING`; the driver's `$n` rewrite — every
occurrence numbered, a cast left alone, a backslash read as PostgreSQL reads
it; and the settings — an `sslMode` that is none of the three refused with
`error.initialize.invalid_ssl_mode`, the default port and the encrypted default.

`test/mariadb_row_mapping_test.dart` covers the shape decision
[Reading rows](#reading-rows) sets out, and also runs without a
server. It drives
`mapResultSet` over a result set whose rows carry what the protocol carries —
a column type, a length and the column's text — and hands every typed read to
the driver's own `MySQLColumnType.convertStringValueToProvidedType`, which is
the entire body of the real `ResultSetRow.typedColByName`. So a `NEWDECIMAL`
column refuses a `double` there for the same reason and from the same code as
against a live server, which is the fact the text readers exist to work around.
Each of the five shapes is mapped and asserted, as are the refusal of an
unreflected result type, a `NULL` on every element type, a projection that
omits columns, and the text spellings the numeric readers decide on —
`1234.56`, `43.0000`, `-42.05`, an exactly integral `10.00` onto an `int`, the
fractional value that is refused instead of truncated, and text that is no
number at all.

What a fake cannot stand in for is what the *server* sends: which protocol type
a given SQL expression yields and what text arrives in the column. That stays
the `db`-tagged suites' job — `test/decimal_column_db_test.dart` pins the
`NEWDECIMAL` spellings an entity meets, `test/grouped_query_db_test.dart` the
aggregate widening, `test/nullable_observable_db_test.dart` the two `TomClass`
variants over real columns. The two halves are complementary: those files
establish what arrives, this one establishes what the mapper does with it.

`test/datasources_db_test.dart` covers what only a real server can settle, on
whichever database the suites run against:
`connect` opening a live connection, `executeCommand` reporting an affected-row
count, `executeQuery` mapping result rows onto a reflected entity and binding
named parameters, `prepareStatement` binding positional parameters, and the
plain transaction lifecycle actually committing or discarding rows. It runs a
transaction that commits while another sleeps inside `SELECT SLEEP(1)`
(`SELECT pg_sleep(1)` on PostgreSQL), and
requires it to finish well inside that second. It also re-asserts that
starting the same transaction twice is refused, because on a real server the
guard and a genuine database failure are both reachable through the same call —
which is the only place the module's own exception type is doing work that
`isA<Exception>()` could not.

`test/datasources_xa_db_test.dart` covers the one thing neither of those can:
that the two-phase lifecycle, driven by the real coordinator, is a sequence the
server accepts — `mariadb_xa` on MariaDB, `postgresql_xa` on PostgreSQL. The
scripted suite proves the *order* of the statements by recording them, which is
a different claim — a recorder cannot object to `XA COMMIT` on a branch that was
never ended, and a server can. On a PostgreSQL server whose
`max_prepared_transactions` is `0` it skips with that reason stated rather than
failing. It commits through a real
`TomTransaction` and reads the row back on a *separate* connection, because the
connection that wrote can see its own uncommitted work and would report success
either way; it rolls one back and finds nothing; and it runs two transactions in
succession, which is the cheapest assertion that no branch was stranded holding
its locks.

The framework tables are covered by two files, because two different things
have to be proved about them.

`test/framework_table_test.dart` covers the descriptor types themselves — what
they *do*, rather than what they agree with. Every assertion in the convergence
file below reads a descriptor and compares it with something else, so all of
them stay green when the rendering is wrong the same way on both sides, and none
of them constructs a descriptor to see what it produces. This one does: the
padded column lines, the `DEFAULT` and `AUTO_INCREMENT` clauses in SQL's order,
the character capacity read back out of a type (and the `null` a `DECIMAL(10,2)`
must answer, so a precision cannot become a length), the index names built from
the table name, the three `ArgumentError` guards, a conflict policy rendered in
each database's words, and
`unknownFrameworkColumns` against a statement carrying a known column, an
unknown one and a bind. Its fixture is a small invented table rather than a real
one, so widening a real column cannot fail a test about padding.

`test/framework_schema_test.dart` runs without a server and closes the four
ways a second spelling of a column could survive: each declaration is compared
against the shipped reference migration, against the reflected row types the
mapper materialises, and — through `unknownFrameworkColumns`, driving each store
through a recording data source — against the statements the stores actually
issue. Its fourth test introduces a deliberate drift and asserts it is *caught*,
because a guard nobody has watched fail is a guard nobody knows works.

`test/framework_schema_db_test.dart` is the only variant that can see a schema
edited by hand after provisioning — the dropped "redundant" index, the widened
column, the `ALTER` applied outside the chain. The other three are readings of
the source tree and stay true of a database that no longer matches it. This one
creates each table by both of the routes a deployment may take — the stores'
create-on-first-use and the reference migration files a DBA applies — reads the
result back through the dialect's `tableColumnsQuery`, and compares it with the
descriptor. On PostgreSQL the reference migrations it applies are the generated
`migrations_postgresql` ones (see
[db_migration.md](db_migration.md#reference-migrations-for-postgresql)).

It, `test/datasources_db_test.dart` and `test/datasources_xa_db_test.dart` are
tagged `db` and skip themselves when no database is reachable, so the default
`testkit :test` run stays green with no database. The same suites run against
either database; `TOM_CORE_SERVER_TEST_DB_ENGINE` (`mariadb`, the default, or
`postgresql`) says which. To run them:

```bash
tool/run_db_tests.sh            # boots a throwaway MariaDB on 3309, runs, tears down
tool/run_db_tests_postgres.sh   # the same against PostgreSQL 15 on 5439
```

Each script needs Docker with Compose v2 and its free host port. The two
compose files (`docker-compose.test.yaml`, `docker-compose.test.postgres.yaml`)
carry their own project names, so both databases can run side by side; the
PostgreSQL one starts the server with `max_prepared_transactions=20` so the
two-phase suite can prepare transactions. A test of a behaviour only MariaDB has
— the MariaDB client's own protocol, MariaDB's account syntax — skips itself on
PostgreSQL with the reason stated (`TestDatabase.onlyOnMariaDb`); everything the
framework does on every database runs on both. To run against a server you
already have, export `TOM_CORE_SERVER_TEST_DB_ENGINE`,
`TOM_CORE_SERVER_TEST_DB_HOST`, `_PORT`, `_USER`, `_PASSWORD` and `_NAME`
instead and run `dart test --tags db` — or name one file after it. The port and
user default to `3309` / `root` on MariaDB and `5439` / `postgres` on
PostgreSQL.

**Every DB-backed suite file runs in a database of its own**, so no suite can
truncate or drop another's tables — neither the next suite file nor a second run
against the same server. The shared fixture
(`test/fixtures/test_database.dart`) names the database
`<_NAME>_<minutes since epoch>_<6 hex digits>` per suite isolate, creates it
when the suite registers its data source, and drops it when that group ends; a
database left by a killed run is swept by a later one after twelve hours.
`_NAME` is therefore a prefix, and the credential needs `CREATE` and `DROP` on
databases (on PostgreSQL, `CREATEDB`; a database is dropped `WITH (FORCE)`). The package's suite files still run one at a time, and the reason
is not the database: `dart_test.yaml` explains it — two suites change the
process-wide working directory.

`example/datasources/datasources_example.dart` is the readable entry point to
the same connection-free surface the first suite covers, in ten numbered
steps: boxing and parsing typed values; rendering literals; letting `objectOp`
dispatch on a runtime type, including an iterable becoming a comma-separated
list; emitting the `:name` placeholder that keeps untrusted input out of the
SQL; writing and reading back an instant through the one `DATETIME(6)`
encoding; rendering each clause a generated statement is assembled from;
scanning a statement for its placeholders without mistaking a colon inside a
literal for one; classifying a failed write as definite or ambiguous; declaring
a framework-owned table, then deriving its DDL, its column lists and its
row writes — in MariaDB's and in PostgreSQL's words — from that one
declaration; and walking an expression tree to reach the
column metadata a rendered fragment cannot carry.

Only two things genuinely need more than a Dart VM, which is why they are
described in this document instead of run there: the drivers and the registry
need a live server, and rendering a whole `TomSelect`, `TomCount` or `TomDelete`
needs annotated entity types, because the column list and the `ORDER BY` are
resolved from reflected persistence metadata. The clause builders those
statements are assembled from are static and pure, so step 6 runs them
directly.

```bash
dart run example/datasources/datasources_example.dart
```

`test/datasources_test.dart` runs the example under precisely that command and
requires it to exit 0 having printed exactly those ten steps, in order and with
no others — an added step nothing lists is a surface nothing checks. So the
transcript in the file is what the module currently does rather than what it did
when the file was written. Its expectations are written through the shared
`example/_support/check.dart`, which throws rather than asserting — see
[A green run is a verification](../README.md#a-green-example-run-is-a-verification)
for why, and for the suite that holds that line across every example. A second
test here requires this file in particular to keep using it.

## Core Components

- **`TomDbType<T>`** and its concrete subtypes — boxed SQL values with
  `of(String?)` parsing.
- **`sqlInstant` / `parseSqlInstant` / `parseOptionalSqlInstant`** — the one
  encoding of an instant in a `DATETIME(6)` column, applied to hand-written and
  reflected SQL alike. See [Instants Are UTC](#instants-are-utc).
- **`sqlDate` / `sqlTimeOfDay`** — the `DATE` and `TIME` renderings, components
  as labelled rather than normalised to UTC. Shared by the dialect's literals
  and the bind boundary so the two routes to a column agree. See
  [The two halves an instant splits into](#the-two-halves-an-instant-splits-into).
- **`parseSqlDate` / `parseSqlTimeOfDay`** — their reading halves, back to a
  `TomZonedDate` and a `TomZonedTime`. A renderer and a reader are only correct
  as a pair, so they are named as one and `TomDbDate.of` / `TomDbTime.of` call
  through to them.
- **`TomOperator<R>`** — the typed SQL expression node (`generate`, `getFields`,
  `getParameters`).
- **`TomStandardSqlDialect`** — SQL-fragment generation; `SqlString`. Also the
  reading side: `typeFamily` / `baseTypeName` / `typeArguments` reduce a DDL
  type name to a **`TomSqlTypeFamily`**, which is how a declared Dart type and
  a stored SQL type are compared at all.
- **`TomSqlFailureMode`** (+ `classifySqlFailure`, `sqlFailureCauses`) — whether
  a failed write is known not to have happened or merely unknown. Ambiguous is
  the default because the set of transport failures is open-ended and the set of
  "the server answered" is not.
- **`isLostConnectionFailure`** — whether a retry on another connection is worth
  one attempt, from the link state plus the cause chain. Deliberately not from the
  exception's message text, and deliberately not from its type alone: the driver
  raises one un-coded type for both a dropped link and a protocol desync.
- **`TomAggregateFunction`** and the aggregate fragments (`aggregate`,
  `aliased`, `groupByClause`, `havingClause`) — the whole SQL surface a grouped
  query renders through.
- **`TomQuery` / `TomGeneratedQuery`** and `TomSelect` / `TomCount` /
  `TomDelete` / `TomLiteralSelect` — query objects; `TomTypePersistenceInfo` /
  `TomTypedPersistenceBase` for the per-type metadata.
- **`SqlPlaceholderScan`** — the quote-aware `:name` scan the positional rewrite
  and the CRUD repository share, so neither mistakes a colon inside a literal
  for a bind. See
  [Finding Placeholders in Quoted SQL](#finding-placeholders-in-quoted-sql).
- **`TomSqlLexer`** — the package's one quote- and comment-aware SQL scanner:
  `endOfQuotedRun`, `commentOpensAt`, `endOfComment` and `splitStatements`. The
  driver uses it to refuse a multi-statement command
  ([One statement per call](#one-statement-per-call)); `db_migration`'s applier
  and DDL reader are written on it.
- **`TomDataSource`** (+ `TomPreparedStatement`, `TomDatasourceDriver`,
  `TomDataSourceInfo`) — the data-source/driver abstraction and registry.
- **`TomSqlDatasource`** (+ `TomSqlPreparedStatement`, `TomSqlRow`,
  `TomSqlResult` / `TomSqlResultValues`, `TomSqlLink`, `TomSqlBranch`,
  `tomSqlBindValue` / `tomSqlBindParams`, `tomSqlBranchId`,
  `TomSqlDatasourceException`, `TomSqlConnectionLostException`) — everything a
  SQL driver does that does not depend on the database, once. See
  [The SQL Drivers](#the-sql-drivers).
- **`TomStatementOutcome`** — what one execution of a prepared statement
  reported, returned by `TomPreparedStatement.run` rather than kept on the
  shared handle. See [What one execution reports](#what-one-execution-reports).
- **`MariaDbDatasource` / `MariaDbXADatasource` / `MariadbSqlDialect`** — the
  MariaDB implementation. See [The MariaDB driver](#the-mariadb-driver).
- **`PostgresDatasource` / `PostgresXADatasource` / `PostgresSqlDialect`** — the
  PostgreSQL 15+ implementation, and the dialect that renders the canonical DDL
  and the framework's conflicting writes in PostgreSQL's words. See
  [The PostgreSQL driver](#the-postgresql-driver) and
  [One declaration, every database](#one-declaration-every-database).
- **`TomConnectionPool`** (+ `TomConnectionPoolSettings`,
  `TomConnectionFactory`, `TomConnectionPoolException`) — the driver-neutral
  bounded pool both SQL drivers draw their connections from. See
  [The Connection Pool](#the-connection-pool).
- **`TomFrameworkTable` / `TomFrameworkColumn` / `TomFrameworkKey`** (+
  `unknownFrameworkColumns`) — the single declaration of a table the *framework*
  owns (the scheduler's queue and lease, the blob store's pair, the audit
  trail), from which its `CREATE TABLE`, its projections and its row writes are
  all derived, in each database's own words. See [Framework-Owned Tables](#framework-owned-tables) and
  [Schema Convergence](db_migration.md#schema-convergence).
- **`TomSchemaProvisioning`** — creates a store's tables once, however many
  first calls arrive together; see
  [Creating a store's tables once](#creating-a-stores-tables-once).

## Not Yet Implemented

- **A `DATE` or `TIME` column does not carry a zone, so a value read back from
  one has none.** Both are stored as the components the value labels — the 5th
  is written as the 5th, 14:30 as 14:30 — which is what makes the column
  orderable and comparable in SQL, and there is nowhere in `'2026-07-05'` or
  `'14:30:00'` to put `Pacific/Kiritimati`. So the reading survives the round
  trip and the anchoring does not: the value comes back anchored in UTC. A
  deployment that needs the zone stores `TomZonedDate.toString()` /
  `TomZonedTime.toString()` — the `@D@…` / `@T@…` form, which carries it — in a
  text column; both readers accept that form as well as the native one.
  <!-- pinned: test/documented_limitations_test.dart › a DATE read back keeps its components and is anchored in UTC -->
- **A `TIME` column may hold an interval, and this module will not read one.**
  MariaDB's `TIME` spans -838:59:59 to 838:59:59 because it doubles as a
  duration type. `TomZonedTime` holds a clock reading, so a column value past 23
  hours raises a `FormatException` rather than wrapping into the next day —
  wrapping would turn a modelling mistake into a plausible wrong answer. Store a
  duration as an integer count of its unit.
  <!-- pinned: test/mariadb_row_mapping_test.dart › a TIME column holding an interval is not a time of day -->
- **`run` is yours to answer, and only you can.** `TomPreparedStatement.run`
  is abstract, and the `TomStatementOutcome` it returns has no defaults. The
  generated key belongs to the connection the insert ran on, and the driver is
  the only layer that knows which connection that was; the affected-row count
  is what callers return as *the* answer to "how many rows went", and what a
  versioned update reads as a conflict. A default would let a driver stay
  silent and have the silence read as a real answer. Return what the
  execution's own result reported, on every path including a retry — see
  [What one execution reports](#what-one-execution-reports).

  Every member of the contract is abstract, and `datasources_test.dart` holds it
  there: a member that grows a body is one a driver can leave unanswered while
  the layers above read the default as its answer.
  <!-- unpinned: decision — abstract by design: only the driver knows the connection -->
- **Two-phase transactions have no recovery.** `MariaDbXADatasource` and
  `PostgresXADatasource` mint their branch ids in memory and keep them only
  there, and nothing ever issues `XA RECOVER` or reads `pg_prepared_xacts`, so a
  process that dies between the prepare and the commit leaves a prepared branch
  holding its locks with no id left in the system to resolve it by. An operator
  lists and resolves such a branch by hand at the server (`XA RECOVER` /
  `XA COMMIT` on MariaDB, `pg_prepared_xacts` / `COMMIT PREPARED` on
  PostgreSQL) until the drivers reconcile them on start-up; the sequences they
  do issue are under [Transactions](#transactions).
  <!-- unpinned: absence — nothing issues XA RECOVER or reads pg_prepared_xacts -->

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `connection_pool.dart`, `sql_datasource.dart`, `mariadb_datasource.dart`, `postgres_datasource.dart` | `Completer` and `Timer`: a caller waiting for a connection and its acquire timeout, and a statement waiting for its transaction's start; `Zone`: the zone marking a transaction's own lifecycle statements |
| `dart:collection` | dart | `connection_pool.dart`, `sql_datasource.dart` | `Queue` for the pool's waiters, and identity-keyed `HashMap`s for lent connections and each transaction's branch |
| `dart:convert` | dart | `postgres_datasource.dart` | `utf8` and `jsonEncode`, rendering a `bytea` or a JSON value into the text convention |
| `dart:math` | dart | `mariadb_datasource.dart`, `postgres_datasource.dart` | `Random`, the per-process tag in a two-phase branch id |
| `dart:typed_data` | dart | `postgres_datasource.dart` | `Uint8List`, a `bytea` value as PostgreSQL's client delivers it |
| `meta` | package | `sql_datasource.dart` | `@protected` on the members a driver supplies or calls |
| `mysql_client` | package | `mariadb_datasource.dart`, `sql_failure_mode.dart` | the MariaDB / MySQL client used by `MariaDbDatasource`, and its `MySQLServerException` |
| `postgres` | package | `postgres_datasource.dart`, `sql_failure_mode.dart` | the PostgreSQL client used by `PostgresDatasource`, and its `ServerException` |
| `tom_basics` | package | `sql_failure_mode.dart` | `TomBaseException`, walked to find the driver exception at the root of a failure chain |
| `tom_core_kernel` | package | 7 of 15 files | `TomObject`, `tomReflector` / `ClassMirror` / `InstanceMirror`, `TomException`, `TomZonedDate` / `TomZonedTime`, `TomExecutionContext`, `runChecked` / `runCheckedSync`, `tomLog` |
| [little_things](little_things.md) | module | `connection_pool.dart`, `datasource_initialization.dart`, `sql_datasource.dart` | `TomServerException` |
| [object_persistence](object_persistence.md) | module | `sql_datasource.dart`, `sql_dialects.dart` | `TomAnnotationAnalyzer`, `TomColumnInformation`, `TomDbTable`, `DbCol`, `TomQuerySentenceCompiler`, `TomGroupedSelect` / `TomGroupedRow` |
| [transactions](transactions.md) | module | `datasource_initialization.dart`, `sql_datasource.dart`, `mariadb_datasource.dart`, `postgres_datasource.dart`, `framework_table.dart` | `TomTransactionParticipant` for the contract `TomDataSource` implements, `TomTransaction` for the one a driver is handed on enlistment — which is where `isReadOnly` becomes a `READ ONLY` begin statement — and `TomTransactionManager.runInTransaction` for `TomFrameworkTable.replaceRow`'s two statements |
