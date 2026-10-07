# Datasources Module

The data-access foundation of the server: **SQL-typed values**
(`TomDbType<T>`), a typed **operator tree** (`TomOperator<R>`), a **SQL dialect**
that renders that tree to SQL fragments (`TomStandardSqlDialect`), reusable
**query objects** (`TomSelect`, `TomCount`, `TomDelete`, `TomLiteralSelect`),
and the **data-source / driver** abstraction (`TomDataSource`,
`TomDatasourceDriver`, `TomDataSourceInfo`) with a MariaDB implementation. The
object-persistence module builds its query DSL and repositories on top of this
layer.

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
- [When a Write Fails](#when-a-write-fails)
  - [Why the test recognises the *definite* side](#why-the-test-recognises-the-definite-side)
  - [Walking the chain](#walking-the-chain)
  - [Deciding whether to retry](#deciding-whether-to-retry)
- [The MariaDB Driver](#the-mariadb-driver)
  - [The connection lifecycle](#the-connection-lifecycle)
  - [One statement per call](#one-statement-per-call)
- [Framework-Owned Tables](#framework-owned-tables)
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
| `isLostConnectionFailure` | function | Whether a failure left no live link to have run on, so one reconnect-and-retry is worth it |
| `TomQuery` / `TomGeneratedQuery` | abstract class | A query over a set of entity types |
| `TomSelect` / `TomCount` / `TomDelete` / `TomLiteralSelect` | class | Concrete statements |
| `TomTypePersistenceInfo` | class | Per-type persistence metadata (table + columns) |
| `TomTypedPersistenceBase` | abstract class | Base for anything scoped to a set of entity types; analyses their annotations once and exposes the flattened column information |
| `SqlPlaceholderScan` | class | Finds `:name` placeholders in generated SQL without mistaking one inside a quoted literal for a bind |
| `TomSqlLexer` | class | The package's one quote/comment scanner and statement splitter — shared by this driver's one-statement check and by `db_migration`'s applier and DDL reader |
| `TomDataSource` | abstract class | A connection to one data source (lifecycle + execution) |
| `TomPreparedStatement<T>` | abstract class | A reusable compiled statement |
| `TomDatasourceDriver` | class | Marks a `TomDataSource` as the driver for a named type |
| `TomDataSourceInfo` | class | The process-wide registry of named, configured data sources |
| `TomDatasourceInitException` | class | A data source could not be discovered, instantiated or initialised |
| `MariaDbDatasource` / `MariaDbXADatasource` / `MariadbSqlDialect` | class | The MariaDB implementation (plain + XA transactions) |
| `MariadbPreparedStatement<T>` | class | A MariaDB-backed `TomPreparedStatement` — the server-side statement, the ordered parameter list, and the type its rows map onto |
| `MariadbDatasourceException` | class | A MariaDB connect, execute or result-mapping failure |
| `MariadbPreparedStatementException` | class | A statement failed with no live link to have run on; raising it *is* the decision to retry once |
| `TomFrameworkTable` / `TomFrameworkColumn` / `TomFrameworkKey` | class | The single declaration of a table the framework itself owns, from which its DDL, column lists and inserts are derived |
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

A MariaDB `DATETIME` carries no zone, and the driver materialises one with
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
- **Reflected entity columns** — a `@TomDbColumn<DateTime?, TomDbDateTime>`
  field names no conversion at all, so this module applies one on its behalf:
  the MariaDB bind boundary renders every bound `DateTime` through `sqlInstant`,
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
  text. `test/temporal_columns_db_test.dart` holds both halves.
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
specially — see [The MariaDB Driver](#the-mariadb-driver).

## Finding Placeholders in Quoted SQL

The dialect renders a bound parameter as `:name` (`TomStandardSqlDialect.p`) and
inlines a string literal with its own escaping (`text` doubles single quotes and
backslashes). Two consumers then have to find those placeholders again in the
finished text: the MariaDB datasource rewrites each one to a positional `?`, and
the CRUD repository extracts their names to bind a raw statement.

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
left-to-right order the `?` slots appear — repeats included, because a repeated
name is a repeated slot and the driver binds by position. `extractNames` is the
same walk with the rewrite discarded.

Three quoting forms are skipped, each with the escape rule its delimiter
actually uses:

| Span | Escapes |
| ---- | ------- |
| `'…'` and `"…"` (string literals) | a backslash escapes the next character (MariaDB's default mode), **and** a doubled delimiter (`''`, `""`) is an escaped delimiter that keeps the scan inside the literal |
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
`TomTransactionParticipant`, and `MariaDbDatasource` enlists itself in the
running transaction on the first statement it issues inside one (see
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

A block names either a `type` or a `delegateTo`; one with neither is
`tom_datasource_info.initialize.no_type_specified`. A delegate is resolved
against the entries already registered, so it must come after the block it
names — otherwise it is `tom_datasource_info.initialize.delegate_not_found`. A
`type` whose driver yields no data source is
`tom_datasource_info.initialize.no_datasource_obtained_for_type`. Reading
`datasource` from an entry that was never initialised throws
`tom_datasource_info.get_datasource.datasource_is_null` rather than answering
`null`.

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
exactly one thing — a `MySQLServerException`, carrying the server's own error
code — and it is the only case in which the outcome is known. So the test is
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
`MySQLServerException` is typically a link or two down inside a
`MariadbDatasourceException`. The walk is bounded (8 links) so a cyclic or
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
any point trying again*. `MariadbPreparedStatement.execute` uses it for its one
reconnect-and-retry.

It is `true` when both halves hold:

| Half | Reads | Why it is needed |
| ---- | ----- | ---------------- |
| `!connected` | The driver's own `MySQLConnection.connected` at the moment the failure was caught | The exception alone cannot say. The driver reports a link it knows is gone as a bare `MySQLClientException` carrying no error code, and raises that *same type* for a protocol desync, a second `BEGIN` and a failed handshake — so the type would retry failures a second attempt cannot fix. Every "connection closed" the driver throws sits behind its own `!connected` guard, so the flag recognises exactly those. |
| `classifySqlFailure(error) == ambiguous` | The `rootException` chain | A `MySQLServerException` anywhere beneath means the server received the statement and rejected it. That verdict stands however the link looks afterwards, and retrying would re-run a statement the server has already judged — for a write, one whose effect is unknown. |

Neither half is matched against message text. Binding a retry to the wording of
a third-party `toString` makes the driver's behaviour change on a dependency
bump, silently and with no compile error.

Because the type returned *is* the signal — `execute` catches
`MariadbPreparedStatementException` (keyed
`error.failed-to-execute.connection_closed`) and nothing else, while every other
failure is a `MariadbDatasourceException` keyed
`error.failed-to-execute.exception` — both branches of the
mapper attach the driver exception as `rootException`. Without it the chain ends
at this layer and `classifySqlFailure` can never reach the server's own verdict.

## The MariaDB Driver

`MariaDbDatasource` (`@TomDatasourceDriver("mariadb")`) connects to MariaDB /
MySQL. Connection settings (`username`, `password`, `host`, `port`,
`databaseName`, `timeOut`) are filled from the configuration map by reflection
in `initialize`, which then opens the connection. A `port` that is neither an
integer nor a string holding one is refused by `parsePort` with
`error.initialize.invalid_port`. A connection the client library hands back
unconnected is `error.failed-to-connect.remained_unconnected`;
`error.failed-to-connect.connect_failed` is the guard for the client returning
no connection object at all, which should not happen. `executeQuery` maps result
rows back onto annotated `@tomReflector` entity classes (including JSON columns,
custom converters, and reference-field dereferencing). Transactions use plain
`START TRANSACTION` / `COMMIT` / `ROLLBACK`.

### The connection lifecycle

**A data source is opened explicitly, and never by the statement that wants to
run.** Opening it means one of the two forms the package documents:
`initialize(settings)`, which binds the configuration and connects, or setting
the connection fields directly and calling `connect()`.

Every execution entry point then observes the same rule:

| State of the data source | What an entry point does |
| ------------------------ | ------------------------ |
| Never opened | Throws `error.datasource.not_opened`, with `state: "never_opened"`. Nothing dials out |
| Closed | Throws the same `error.datasource.not_opened`, with `state: "closed"`. Nothing dials out |
| Opened, but the link has since dropped | Re-opens it and runs the statement on the new link |
| Opened and live | Runs the statement on the link as it stands |

Both refusals also name the calling entry point in the exception's `operation`
parameter, so a log says which call ran too early.

### One statement per call

`executeQuery` and `executeCommand` take **one SQL statement** and refuse more
with `error.datasource.multiple_statements`, carrying the `operation`, the
`statements` count and the `command`. The check runs before the connection is
touched, and it is quote- and comment-aware (`TomSqlLexer.splitStatements`): a
terminating `;`, and a `;` inside a literal, a quoted identifier or a comment,
do not count.

The reason is the client library. `mysql_client` completes a call on the first
reply it reads and never checks whether more follow, so every reply after the
first stays on the wire and is read by the *next* call on the same connection —
which is then answered by its predecessor's reply, for the rest of the
connection's life. Nothing reports it: a query comes back empty, an `XA COMMIT`
returns before the server has committed, and an error in any statement after
the first is never raised at all. A script is split first; the migration
adaptor does exactly that.

Opening on demand is not offered because it could not work. `connect()` binds
`host`, `port` and the credentials, and those arrive only from `initialize` or a
direct assignment; before either, `host` is `""` and `port` is `-1`. An implicit
connect could therefore never succeed — it could only turn "this data source was
never opened" into "the database at `:-1` is unreachable", sending the reader to
the network for what is a configuration bug.

Re-opening a *closed* data source, by contrast, would work — and that is exactly
why it must not happen by itself. `close()` is the application saying it is done
with this data source; a statement that quietly re-opened it would resurrect
something deliberately let go, and on the shutdown path would open a socket that
nothing is left to close. So `close()` releases the link **and lets go of it**,
putting the data source back to not-open.

Which of the two not-open states it is rides in the `state` parameter and in
`toString`, rather than in the key: a caller matching "this data source has no
connection" should not have to match twice, but a reader diagnosing it needs the
distinction, because the two point at different faults — `never_opened` at
configuration or start-up ordering, `closed` at shutdown ordering. Closing a
data source that was never opened releases nothing and leaves it reading as
never opened.

The dropped-link row is the half that must survive all of this. It is the one
case the driver repairs, because the caller never asked for the loss: the
settings are known, so reconnecting is exactly what it wants and it happens
without being asked.

One private helper, `_openConnection(operation)`, is the only implementation of
this rule, and all four sites that need a link go through it:
`prepareStatement`, `executeQuery`, `executeCommand`, and the retry inside
`MariadbPreparedStatement.execute`. They previously carried a guard each, and
had drifted — `prepareStatement` connected on demand while the other two threw,
so the same data source was usable or unusable depending on which method a
caller reached for first. With a single implementation the rule cannot drift
again.

A grouped query takes a different path through the same driver. A grouped row
has no entity class and no column metadata — its shape is decided by the query —
so `prepareStatement` copies the query's `projectionTypes` (alias → Dart type)
onto the prepared statement, and `mapGroupedRow` reads each alias as the type
the query declared for it, producing a `TomGroupedRow`. That runs before any
mirror is taken; an alias whose declared type is outside
`int`/`double`/`String`/`bool`/`DateTime` raises
`error.result_processing_grouped.unknown_type`.

**The shape decision is one public method.** `mapResultSet` is the driver's
largest decision, and which of five shapes a result takes is settled entirely by
what the result type declares:

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
this driver cannot map, and the only outcome besides the five.

It is public, and takes the driver's result set rather than a connection,
because nothing in it needs a server: the protocol has already decoded every
column to text, and only a `@TomReference` column reaches back to the database.
That column's own query is compiled, rendered to SQL, run, and its rows added to
the list the field already holds, and each step that fails has its key:
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
(`mariadb_row_mapping_test.dart`) instead of only where a MariaDB happens to be
listening.

> **Numeric columns are read as text, deliberately — on every path.**
> `mysql_client` converts a column to `double` only from a whitelist of protocol
> types (TINY, SHORT, LONG, LONGLONG, INT24, FLOAT, DOUBLE), and to `int` from a
> similar one. `DECIMAL`/`NEWDECIMAL` (protocol type 246) is in neither, so
> asking the driver for a number there throws `MySQLProtocolException` rather
> than widening. That is not an aggregate curiosity: `DECIMAL` is the correct SQL
> type for money, so an ordinary entity hits it on its first select —
> `SUM`/`AVG` over an integer column merely reach it first, which is how the gap
> was found. The driver therefore reads the raw text and parses it in two shared
> helpers, `_readDouble` and `_readInt`, used by `mapGroupedRow` and by all four
> entity-mapping variants alike. Parsing here is lossless: the driver's own
> conversion starts from exactly this text (the whitelist is a gate, not a
> decoder) and it reports `DECIMAL` as best-matching Dart `String`. Text that is
> no number at all is refused by column name —
> `error.result_processing.not_a_double` for a `double` field,
> `error.result_processing.not_an_int` for an `int` one — so the failure names
> the column and the value, which the driver's own conversion error does not.
>
> **Dates and times are refused the same way.** A stored `DATETIME`, `DATE` or
> `TIME` is read through `parseSqlInstant`, `parseSqlDate` or
> `parseSqlTimeOfDay`, which are public parse functions and throw a
> `FormatException` as Dart's own parsers do. A stored row is data from outside
> the process, so the driver converts: text none of them can read raises
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
>
> A driver for another database should check the equivalent conversion before
> assuming its client widens.

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

As a transaction participant the plain driver is one-phase: `START
TRANSACTION`, then `COMMIT` or `ROLLBACK`, each of which lowers the
in-transaction flag itself. `endTransaction` is therefore **a no-op that always
succeeds** — there is no prepare step to issue, and by the time the coordinator
calls it, commit or rollback has already released everything there was to
release. It still reports `true` rather than nothing, because the coordinator
ands the participants' results together and a `false` would fail a transaction
that had in fact completed.

`MariaDbXADatasource` (`@TomDatasourceDriver("mariadb_xa")`) inherits all of
that but overrides the transaction lifecycle to use **XA** (`XA START` / `XA
END` + `XA PREPARE` / `XA COMMIT` / `XA ROLLBACK`), so it can take part in a
two-phase commit across multiple resources.

Each transaction runs against a branch id the data source mints in
`startTransaction`, and that id doubles as the guard: a second start while one
is set throws rather than opening a nested branch. **Every exit clears the id
except a failing `prepare` and a failing `commit`.** A failing prepare hands it
on to `rollback`, which the coordinator issues in answer to the veto and which
has to name the branch; a failing commit leaves a prepared branch in doubt, and
the id is kept so it has a name. An exit that forgets locks the data source out
of all later transactions permanently, and the caller cannot recover by rolling
back — the branch it would have to name never began.

The branch id is `<database>@<host>:<port>_<process>_<time>_<counter>`, and it
is **bounded to 64 bytes**, the most an XA `gtrid` may hold — MariaDB refuses a
longer one as a syntax error, so an id built from the coordinates as written
would make every XA transaction fail to start as soon as the hostname or the
database name was long enough. The unique tail — a random per-process tag, the
time in microseconds and a per-process counter — is always kept whole, and the
readable head is what is truncated: a shortened name still tells an operator
reading `XA RECOVER` whose branch it is, while a shortened tail could name two
branches alike. Characters outside `[A-Za-z0-9_.@:-]` become `_`, which keeps
the id single-byte and safe to quote.

**The statements map onto the coordinator's two phases.** `prepare` issues
`XA END` and then `XA PREPARE`, as two calls (see
[One statement per call](#one-statement-per-call)); `commit` issues
`XA COMMIT`; `endTransaction` is the same no-op that reports success as its
one-phase sibling's. It has to be this way round because
`TomTransaction.commitTransaction` drains its `commit()` loop before it calls
`endTransaction()` on anyone, so a prepare placed in `endTransaction` would run
*after* the commit it is a precondition of: the server refuses `XA COMMIT` on a
branch that was never ended, the `false` reads as a veto, and the transaction
becomes a rollback with the branch left ACTIVE holding its locks.

`rollback` ends the branch too, when it is still active. `XA END` is legal
exactly once and on an ACTIVE branch only, and it decides what the rollback may
issue: `XA ROLLBACK` is refused on an ACTIVE branch (`XAER_RMFAIL: The command
cannot be executed when global transaction is in the ACTIVE state`) and `XA END`
is refused on an IDLE or prepared one. A rollback can arrive in any of the three
states — before `prepare` ran, after its `XA END` succeeded and its
`XA PREPARE` did not, or after a prepare succeeded and the commit did not. So
the driver tracks whether the branch has been ended, and issues `XA END` then
`XA ROLLBACK` for an active branch and `XA ROLLBACK` alone otherwise, rather
than sending a statement and ignoring the failure — a rollback the server
refuses leaves the branch exactly where it was, and is reported as a failed
rollback.

Both lifecycles refuse a nested start the same way, through one shared helper:
a **`MariadbDatasourceException` keyed `error.transaction.already_active`**,
naming the participant and — for XA, which has one — the branch already open.
The type is the point. Starting a transaction has two ways of not happening,
and they are not the same kind of event:

| What happened | How the caller hears it | What the caller can do |
| ------------- | ----------------------- | ---------------------- |
| The database refused `START TRANSACTION` | `startTransaction` returns `false` | Retry, route around it, or give up |
| The data source is already in a transaction | Throws `error.transaction.already_active` | Nothing — fix the code |

Which is why the guard sits **in front of** the `try`, not inside it. Inside,
the catch-all that turns a failed statement into `false` would swallow the
refusal and hand the caller the first row's answer for the second row's
situation. And it is thrown as the module's own type rather than a bare
`Exception` because `Exception` is the supertype of every failure there is: a
`catch` narrow enough to act on the one case the caller can fix cannot be
written against it.

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
| The create-if-missing DDL each store issues on first use | `createTableDdl` |
| The column lists its statements interpolate | `columnList`, `columnsOf(names)` |
| Its `INSERT` / `REPLACE` shape | `insert(verb, values)` |
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
projection that outlived the column it names fails at the first call. `insert`
keys by column name rather than by position — a positional list would put the
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

## Verification

Three suites cover the driver, split by what needs a server rather than by what
is interesting. Two more cover the framework-table declarations, split the same
way.

`test/datasources_test.dart` always runs, and reaches further into the driver
than "no connection" suggests. Beyond the dialect's SQL generation and the
`TomDbInt.of` / `TomDbBool.of` conversions it covers `MariadbPreparedStatement`'s
`buildPositionalParameters` and `normalizeGeneratedId`,
`MariaDbDatasource.toPositionalStatement` and the placeholder scan it shares
with `crud_repository`, `sqlInstant` / `parseSqlInstant` /
`parseOptionalSqlInstant` — including the local-reading trap that
[Instants Are UTC](#instants-are-utc) exists to close — `parsePort` /
`normalizePort`, the `initializeDatasourceInfo` configuration guard,
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
link that dropped, each against every execution entry point. And the
**transaction state machine** is driven by overriding `executeCommand` to
script each command's outcome and record the SQL it was given, which is how a
failed `XA START` / `XA END` / `XA ROLLBACK` can be shown to clear the branch
id — a cleared id surfaces as the literal `XA COMMIT null`, so the recording is
the assertion.

`test/mariadb_row_mapping_test.dart` covers the shape decision
[The MariaDB Driver](#the-mariadb-driver) sets out, and also runs without a
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

`test/datasources_db_test.dart` covers what only a real server can settle:
`connect` opening a live link, `executeCommand` reporting an affected-row
count, `executeQuery` mapping result rows onto a reflected entity and binding
named parameters, `prepareStatement` binding positional parameters, and the
plain transaction lifecycle actually committing or discarding rows. It also
re-asserts the second-concurrent-transaction refusal that the scripted suite
covers, because on a real server the guard and a genuine database failure are
both reachable through the same call — which is the only place the module's own
exception type is doing work that `isA<Exception>()` could not.

`test/datasources_xa_db_test.dart` covers the one thing neither of those can:
that the XA lifecycle, driven by the real coordinator, is a sequence MariaDB
accepts. The scripted suite proves the *order* of the statements by recording
them, which is a different claim — a recorder cannot object to `XA COMMIT` on a
branch that was never ended, and a server can. It commits through a real
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
the table name, the three `ArgumentError` guards, the `INSERT` shape, and
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
result back out of `information_schema`, and compares it with the descriptor.

It, `test/datasources_db_test.dart` and `test/datasources_xa_db_test.dart` are
tagged `db` and skip themselves when no MariaDB is reachable, so the default `testkit :test` run stays green with no
database. To run them:

```bash
tool/run_db_tests.sh     # boots a throwaway MariaDB on 3309, runs, tears down
```

The script needs Docker with Compose v2 and a free host port 3309. To run
against a server you already have, export `TOM_CORE_SERVER_TEST_DB_HOST`,
`_PORT`, `_USER`, `_PASSWORD` and `_NAME` instead and run
`dart test --tags db` — or name one file after it.

**Every DB-backed suite file runs in a database of its own**, so no suite can
truncate or drop another's tables — neither the next suite file nor a second run
against the same server. The shared fixture
(`test/fixtures/test_database.dart`) names the database
`<_NAME>_<minutes since epoch>_<6 hex digits>` per suite isolate, creates it
when the suite registers its data source, and drops it when that group ends; a
database left by a killed run is swept by a later one after twelve hours.
`_NAME` is therefore a prefix, and the credential needs `CREATE` and `DROP` on
databases. The package's suite files still run one at a time, and the reason
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
inserts from that one declaration; and walking an expression tree to reach the
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
- **`isLostConnectionFailure`** — whether a reconnect-and-retry is worth one
  attempt, from the link state plus the cause chain. Deliberately not from the
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
- **`MariaDbDatasource` / `MariaDbXADatasource` / `MariadbSqlDialect`** — the
  MariaDB implementation.
- **`TomFrameworkTable` / `TomFrameworkColumn` / `TomFrameworkKey`** (+
  `unknownFrameworkColumns`) — the single declaration of a table the *framework*
  owns (the scheduler's queue and lease, the blob store's pair, the audit
  trail), from which its `CREATE TABLE`, its projections and its inserts are all
  derived. See [Framework-Owned Tables](#framework-owned-tables) and
  [Schema Convergence](db_migration.md#schema-convergence).

## Not Yet Implemented

- **One database, not a family of them.** Both registered drivers are MariaDB —
  `MariaDbXADatasource` extends `MariaDbDatasource` — so the dialect surface
  described above has exactly one shipped implementation, and the portability
  the operator tree exists for has never been exercised against a second
  engine. A deployment on another database writes its own `TomDataSource`,
  `TomPreparedStatement` and dialect and registers them with
  `@TomDatasourceDriver`, as described in
  [Data Sources and Drivers](#data-sources-and-drivers).
  <!-- unpinned: absence — one engine ships; a second is a deployment's driver -->
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
- **One connection per data source, and no pool.** `MariaDbDatasource` holds a
  single `MySQLConnection`, and a transaction belongs to the connection, so a
  transaction *holds* the data source from its first statement until the
  coordinator ends it: a statement from anywhere else — another request's
  transaction, or a request with none — waits for the release rather than
  running inside a transaction that is not its own. Concurrent transactions on
  one data source therefore take turns, and a long transaction stalls every
  other user of that data source. `delegateTo` gives two logical names the same
  physical link, so they share this too. Configure a separate data source for
  each unit of work that has to commit independently, rather than two names over
  one connection. Work the owning transaction waits on must run in its zone: a
  statement issued from a `runInTransactionScope` nested inside it waits on its
  own transaction for good.
  <!-- unpinned: absence — no pool ships -->
- **`lastGeneratedId` is yours to answer, and only you can.**
  `TomPreparedStatement.lastGeneratedId` is abstract. The key belongs to the
  connection the insert ran on, and the driver is the only layer that knows
  which connection that was — a follow-up `SELECT LAST_INSERT_ID()` from any
  layer above reads the *session's* last value and answers 0 on another
  connection, which is the defect reading it from the insert's own result
  exists to remove. Return what the insert reported;
  `TomSqlDatasourceRepository.save` takes a freshly inserted row's surrogate key
  from it and refuses the insert by name
  (`crud_repository.save.no_generated_key`) when there is none, rather than
  storing a row under a key that is not its own.
  <!-- unpinned: decision — abstract by design: only the driver knows the connection -->
- **`lastAffectedRows` is per-execution.** `TomPreparedStatement.lastAffectedRows`
  is abstract and non-nullable for the same reason — a driver that ran a write
  knows how many rows it touched, and callers (the CRUD repository's delete
  methods) return the number as *the* answer to "how many rows went". A default
  would let a driver stay silent and have the silence read as a real count. It
  is state on the handle, replaced by the next `execute` and meaningless after
  `deallocate`, so read it immediately after the execute that produced it. Both
  this and `lastGeneratedId` are captured in one place in the MariaDB statement,
  so that its reconnect-and-retry branch cannot pick up one and drop the
  other.

  Every member of the contract is abstract, and `datasources_test.dart` holds it
  there: a member that grows a body is one a driver can leave unanswered while
  the layers above read the default as its answer.
  <!-- unpinned: decision — abstract by design, like lastGeneratedId -->
- **XA has no recovery.** `MariaDbXADatasource` mints its branch id in
  memory and keeps it only there, and nothing ever issues `XA RECOVER`,
  so a process that dies between `XA PREPARE` and `XA COMMIT` leaves a prepared
  branch holding its locks with no id left in the system to resolve it by. An
  operator lists and resolves such a branch by hand at the server until the
  driver reconciles them on start-up; the sequence it does issue is under
  [The MariaDB Driver](#the-mariadb-driver).
  <!-- unpinned: absence — nothing issues XA RECOVER -->

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `mariadb_datasource.dart` | `Completer` and `Zone`: a transaction's hold on the connection, and the zone marking its own statements |
| `dart:math` | dart | `mariadb_datasource.dart` | `Random`, the per-process tag in an XA branch id |
| `mysql_client` | package | `mariadb_datasource.dart`, `sql_failure_mode.dart` | the MariaDB / MySQL driver used by `MariaDbDatasource` |
| `tom_basics` | package | `sql_failure_mode.dart` | `TomBaseException`, walked to find the driver exception at the root of a failure chain |
| `tom_core_kernel` | package | `datasource_initialization.dart`, `mariadb_datasource.dart`, `sql_dialects.dart`, `sql_instant.dart`, `types_operator.dart` | `TomObject`, `tomReflector` / `ClassMirror` / `InstanceMirror`, `TomException`, `TomZonedDate` / `TomZonedTime`, `TomExecutionContext`, `runChecked` / `runCheckedSync`, `tomLog` |
| [little_things](little_things.md) | module | `datasource_initialization.dart`, `mariadb_datasource.dart` | `TomServerException` |
| [object_persistence](object_persistence.md) | module | `mariadb_datasource.dart`, `sql_dialects.dart` | `TomAnnotationAnalyzer`, `TomColumnInformation`, `TomDbTable`, `DbCol`, `TomQuerySentenceCompiler`, `TomGroupedSelect` / `TomGroupedRow` |
| [transactions](transactions.md) | module | `datasource_initialization.dart`, `mariadb_datasource.dart` | `TomTransactionParticipant` for the contract `TomDataSource` implements, and `TomTransaction` for the one the driver is handed on enlistment — which is where `isReadOnly` becomes `START TRANSACTION READ ONLY` |
