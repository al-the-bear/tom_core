# Object Persistence Module

A lightweight, annotation-driven ORM: map a reflected entity class to a database
table, then read and write it through a Spring-Data-style repository. Queries can
be expressed three ways — a parsed *query sentence*, a programmatically built
`TomQuery`, or raw SQL — and all of them render through a pluggable SQL dialect.

## Table of Contents

- [Overview](#overview)
- [Mapping an Entity](#mapping-an-entity)
- [The Repository Contract](#the-repository-contract)
- [Query Sentences](#query-sentences)
- [The Query Builder DSL](#the-query-builder-dsl)
- [Grouping and Aggregation](#grouping-and-aggregation)
- [How Metadata Is Resolved](#how-metadata-is-resolved)
- [SQL Dialects](#sql-dialects)
- [Core Components](#core-components)
- [Not Yet Implemented](#not-yet-implemented)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomDbTable` / `TomDbColumn` / `TomEntityId` / `TomReference` | annotations | Map an entity class and its fields to a table and columns |
| `TomRepository<T, K>` | abstract class | The CRUD + query contract for entity `T` keyed by `K` |
| `TomSqlDatasourceRepository<T, K>` | abstract class | SQL implementation of the contract |
| `MariadbRepository<T, K>` | class | MariaDB driver binding (`@TomRepositoryType("mariadb")`) |
| `TomQuerySentenceCompiler` | class | Parses a query sentence into a `TomQuery` |
| `TomQueryBuilder` | mixin | Fluent factory for the `TomOperator` expression tree |
| `TomAggregate` | abstract class | An aggregate function node (`CountAll`, `Count`, `Sum`, `Avg`, `Min`, `Max`) |
| `TomGroupedSelect` | class | A `SELECT … GROUP BY … HAVING` compiled from group keys and aggregates |
| `TomGroupedRow` | class | One group's result: the group keys plus the aggregate values, keyed by alias |
| `TomAnnotationAnalyzer` | mixin | Resolves an entity's persistence metadata by reflection |
| `TomColumnInformation` | class | The resolved metadata for one entity field |

## Mapping an Entity

Annotate a `@tomReflector` class with `@TomDbTable` and its fields with
`@TomDbColumn` (and `@TomEntityId` on the primary key):

```dart
@tomReflector
@TomDbTable(datasource: 'main', table: 'users', primaryKeyField: 'id')
class User {
  @TomEntityId()
  @TomDbColumn(columnName: 'id')
  int? id;

  @TomDbColumn(columnName: 'name')
  String name = '';

  @TomDbColumn(columnName: 'age')
  int age = 0;
}
```

`@TomDbColumn` can mark a column `isReadOnly` (skipped on insert/update),
`noLoad` (skipped on select), or `isJson`, and can carry `fromDbConverter` /
`toDbConverter` functions to translate between the Dart value and the boxed
`TomDbType` stored in the column.

## The Repository Contract

`TomRepository<T, K>` mirrors Spring Data's `CrudRepository`:

```dart
final repo = MariadbRepository<User, int>([User]);

await repo.save(user);                 // INSERT (null key) or UPDATE (key set)
final u   = await repo.findById(42);   // by primary key
final all = await repo.findAll();
final n   = await repo.count();
await repo.deleteById(42);
```

Beyond id-based CRUD it exposes three query styles, each in find / delete / count
flavours: a parsed query sentence (`findByQuerySentence`), a built `TomQuery`
(`findByQuery`), and raw SQL (`executeQueryString`). A fourth entry point,
`findGroupedByQuery`, runs a grouped query — its result is not `T`, so it does
not fit the find/delete/count pattern (see
[Grouping and Aggregation](#grouping-and-aggregation)).

## Query Sentences

A *query sentence* is a Spring-Data-style phrase compiled by
`TomQuerySentenceCompiler.compileQuerySentence`:

```text
find by name = :name order by age desc
count by status IS IN ( :statuses )
delete by id = $id
group count ( * ) as total over status by age >= :min
```

- The first word picks the kind: `find` → `TomSelect`, `count` → `TomCount`,
  `delete` → `TomDelete`, `group` → `TomGroupedSelect`.
- The part before `by` carries options: `distinct`, and `top N` / `first N`
  (mutually exclusive). For `group` it also carries the aggregate projection and
  the optional `over <fields>` group key — see
  [Grouping and Aggregation](#grouping-and-aggregation).
- The part after `by` is the predicate, optionally followed by a `having
  <predicate>` clause (`group` only) and `order by <fields> [asc|desc]` (the
  direction must be the last token).

A malformed sentence raises `TomQuerySyntaxException`.

## The Query Builder DSL

`TomQueryBuilder` builds a type-safe `TomOperator` tree without naming the
operator classes. Predicate factories return `TomOperator<TomDbBool>`; literal,
parameter, and column factories return the matching SQL-typed operator:

```dart
// (age >= :min) AND (name LIKE 'A%')
final predicate = and([
  group(gte(intF('age', ageCol), p<TomDbInt>('min'))),
  group(like(textF('name', nameCol), text('A%'))),
]);
final sql = predicate.generate(MariadbSqlDialect());
```

Use `p<T>('name')` for bound parameters (`:name`) — the driver binds the value,
avoiding SQL injection. Literal factories (`text`, `intOp`, `dateOp`, …)
interpolate directly and should be reserved for trusted values.

## Grouping and Aggregation

Everything above describes *rows*. A grouped query describes *groups*: rows
collapsed by one or more key columns, with an aggregate value computed per
group.

It is a separate query kind rather than an option on the select because its
**result is a different shape**. A grouped row holds the group keys and the
aggregates the query asked for — a tuple decided by the query, not by any
entity class — so it comes back as a `TomGroupedRow` rather than as `T`:

```dart
Future<List<TomGroupedRow>> findGroupedByQuery(
  TomGroupedSelect query,
  Map<String, Object?> params,
);
```

### The aggregates

Every aggregate is a `TomAggregate`, which *is* a `TomOperator` — so it composes
with the ordinary predicate factories, which is what makes `HAVING COUNT(*) > 3`
expressible without a second expression language.

| Builder factory | SQL | Dart value type |
| --------------- | --- | --------------- |
| `countAll(alias)` | `COUNT(*)` | `int` |
| `countOf(value, alias, {distinct})` | `COUNT([DISTINCT] v)` | `int` |
| `sum(value, alias, {distinct})` | `SUM([DISTINCT] v)` | `double` |
| `avg(value, alias, {distinct})` | `AVG([DISTINCT] v)` | `double` |
| `minInt` / `maxInt` | `MIN(v)` / `MAX(v)` | `int` |
| `minDouble` / `maxDouble` | `MIN(v)` / `MAX(v)` | `double` |
| `minText` / `maxText` | `MIN(v)` / `MAX(v)` | `String` |
| `minDateTime` / `maxDateTime` | `MIN(v)` / `MAX(v)` | `DateTime` |

`countAll` and `countOf` are not the same question: `COUNT(*)` counts rows,
`COUNT(column)` counts non-null values, so a group whose column is entirely
`NULL` yields the row count from the first and `0` from the second.

`sum` and `avg` always widen to `double` — SQL widens a sum to an exact-numeric
type, and widening once here keeps the Dart type predictable instead of
dialect-dependent. `min`/`max` are split by type instead, because an extremum is
one of the operand's own values and so preserves the column's type on both
sides.

Every aggregate carries an **alias**. Unlike an entity projection there is no
column metadata to map results back by, so the alias is the name the value comes
back under. It is validated at construction against `^[A-Za-z_][A-Za-z0-9_]*$`:
an alias is written into the statement text rather than bound, so it is the one
injection surface a grouped query adds, and it is closed where it opens.

### Building one

Through the builder:

```dart
// SELECT title, COUNT(*) AS n, SUM(priority) AS total
//   FROM task WHERE priority >= :floor
//   GROUP BY title HAVING COUNT(*) > 2 ORDER BY total DESC
final query = TomGroupedSelect(
  [Task],
  query: gte(priorityCol, p<TomDbInt>('floor')),
  groupBy: [titleCol],
  aggregates: [countAll('n'), sum(priorityCol, 'total')],
  having: gt(countAll('n'), intOp(2)),
  orderBy: ['total'],
  ascending: false,
);
final groups = await repo.findGroupedByQuery(query, {'floor': 1});
```

Or as a query sentence, using the fourth sentence kind, `group`:

```text
group count ( * ) as total , sum ( priority ) as weight over title
  by priority >= :floor having total > 2 order by total desc
```

The projection is a comma-separated list of `<fn> ( <arg> ) as <alias>`, with
`count ( * )` for the row count and a leading `distinct` inside the parentheses
for `count`/`sum`/`avg`. `over <fields>` names the group key — **omit it to
aggregate the whole filtered set into exactly one row**. `top N` / `first N`
work as they do on the other kinds.

`orderBy` names *projection aliases* — a group column's declared field name or an
aggregate's alias — not arbitrary entity fields. Ordering a grouped result by an
ungrouped column has no meaning, and the constructor rejects it rather than
letting the database pick a behaviour.

### Reading the result

`TomGroupedRow` is a keyed holder with typed accessors:

```dart
for (final row in groups) {
  final title = row.stringValue('title');  // the group key, under its field name
  final n     = row.intValue('n');
  final total = row.doubleValue('total');
}
```

- Group keys come back under the column's **declared field name**; aggregates
  under their **alias**. `row.keyOf(titleCol)` resolves the former from the
  column itself.
- `intValue` / `doubleValue` / `stringValue` / `boolValue` / `dateTimeValue`
  coerce from whatever the driver handed over. `value(alias)` returns it raw.
- An aggregate node reads its own value: `total.read(row)` returns a `double?`
  without naming the type twice.
- Reading an alias the query did not project **throws**
  `TomQuerySyntaxException`. Returning `null` would be indistinguishable from
  "this group had no value", which is a real and different answer — an aggregate
  over an all-null column is `null`, and a typo must not look like one.

`TomGroupedRow` is also directly consumable by the export module's tabular
projection (see [`export.md`](export.md)), which is the usual destination for a
grouped result.

### `WHERE` filters rows, `HAVING` filters groups

The two predicates stay separate all the way down to the dialect, for the same
reason they are separate in SQL: `WHERE` runs before aggregation and `HAVING`
after it, so ANDing them together would change the meaning of both.

`HAVING` therefore addresses the **projection**, by alias, while the `by`
predicate addresses **columns**. A `HAVING` on a bare column that is neither a
group key nor inside an aggregate is rejected with
`grouped_query.select.having_on_ungrouped_field` — such a predicate has many
values per group and no rule for picking one, and databases differ on whether
they refuse it or silently choose a row. Catching it in the query layer makes
the behaviour identical on every dialect.

### Authorization

Both server-side controls apply, and the column control applies *differently*
here than on the row-returning paths:

- **Row scope (C-3)** is ANDed into the `WHERE`, never into `HAVING` — it decides
  which rows the principal may see, so it must apply before aggregation.
  Filtering groups afterwards would still have counted the hidden rows.
- **Column rights (C-4)** cause the query to be **refused outright** rather than
  masked. The row paths null a forbidden column out of each returned entity; a
  grouped query cannot, because by the time rows exist the column has already
  been collapsed into a key or folded into an aggregate. Nulling the result would
  not undo the leak — a `COUNT(*)` per masked group still discloses the masked
  values' distribution. A grouped query naming a masked column therefore raises
  `TomColumnAuthorizationException` before it reaches the database.

### Value types across drivers

The value type is the one the **projection declared**, not the one the driver
happens to hand back. `MariaDbDatasource.mapGroupedRow` reads each alias as the
declared type, which is the only type information a grouped row has.

That mapping is load-bearing for `SUM` and `AVG`. MariaDB types `SUM(<int
column>)` as `NEWDECIMAL`, and `mysql_client` converts a column to `double` only
from a fixed whitelist of protocol types that does not include it — asking the
driver for a `double` there *throws* rather than widening. The driver therefore
reads numeric columns as raw text and parses them; the text form is lossless, so
nothing is given up. A caller sees a `double` either way and does not need to
know. The same applies to every entity-mapping path, not only to grouped rows:
`DECIMAL` is the correct SQL type for money, so a plain entity with a money
column meets the identical gap on its first select. See
[`datasources.md`](datasources.md#the-mariadb-driver) for the shared read
helpers and for the rule governing an `int`-declared field over a `DECIMAL`
column (exactly integral values are read; fractional ones are refused by name,
never truncated).

The consequence worth remembering: **`SUM` over an integer column is a `double`,
not an `int`.** Read it with `doubleValue`, and do not reach past the accessors
for a raw `as int`.

## How Metadata Is Resolved

`TomAnnotationAnalyzer` reads the `tomReflector` `ClassMirror` of an entity and
translates its annotations into a `TomTypePersistenceInfo` and a list of
`TomColumnInformation` (one per annotated field). Results are memoised per type
in `mirrorCache` / `tableCache` / `columnInfoCache`. A `TomColumnInformation`
also provides reflection-backed `getVariableValue` / `setVariableValue`
accessors that the repository uses to read and write entity fields. A type that
is not registered with `tomReflector`, or lacks a `@TomDbTable`, raises
`TomAnnotationAnalyzerException`.

`familyOf` reduces one column to the `TomSqlTypeFamily` it is **stored** in — a
JSON column is text whatever its Dart type, an explicit `TomDbType` box decides
next, and only failing both does the Dart type stand in; anything unrecognised is
`unknown`, which is compatible with everything, because a gap in the reader's
knowledge must not be reported as a defect. It is homed here, beside the
annotations it reads, rather than with either of its callers: the
schema-convergence check ([`db_migration.md`](db_migration.md#schema-convergence))
and the reflected export projection ([`export.md`](export.md#columns-derived-from-the-entity))
ask the same question of the same declaration, and a second answer would be a
second thing to keep in step. Note what it does *not* describe — the Dart value a
getter returns; a caller that cares about that must read
`TomColumnInformation.declaredType` as well, which is what the export projection
does.

## SQL Dialects

Every operator renders itself through a `TomStandardSqlDialect` (see
`doc/datasources.md`). A driver subclasses the dialect to override any fragment;
`MariadbRepository` uses `MariadbSqlDialect`. Repository discovery uses the
`@TomRepositoryType("...")` annotation to select the right repository for a data
source's type.

## Core Components

- **Annotations** — `TomDbTable`, `TomDbColumn`, `TomEntityId`, `TomReference`,
  `TomJoinTable`, `TomPersistenceEventHandler`, plus `TomDartType`.
- **`TomColumnInformation`** — resolved per-field metadata + reflection accessors.
- **`TomRepository` / `TomSqlDatasourceRepository` / `MariadbRepository`** — the
  CRUD/query contract and its SQL/MariaDB implementations.
- **`TomQuerySentenceCompiler`** — query-sentence parser.
- **`TomQueryBuilder` + the operators** (`Eq`, `Lt`, `Like`, `In`, `Between`,
  `And`, `Or`, literals, `Parameter`, the `*Col` references) — the expression
  tree and its dialect-rendered SQL.
- **`TomAggregate` + `TomGroupedSelect` + `TomGroupedRow`** — the aggregation
  nodes (`CountAll`, `Count`, `Sum`, `Avg`, `Min`, `Max`), the grouped sentence
  and its result shape.
- **`TomAnnotationAnalyzer`** — reflection-based metadata resolver.

## Not Yet Implemented

Tracked in the quest completion steps:

- Pagination on the repository: offset / page / slice. `top N` / `first N`
  renders `LIMIT n` on every query kind, but there is no `OFFSET`, so a result
  set can be capped and not paged through.
- Sorting as a repository argument. `orderBy` is a property of the query, so
  `findAll` and the other id-based methods cannot be given one.
- `@TomJoinTable` is declared but never read — neither detected nor acted on.
- `@TomPersistenceEventHandler` is *detected* (`TomAnnotationAnalyzer` resolves
  it onto `TomColumnInformation.eventHandler`) but never invoked, so declaring
  one currently has no effect.
- Additional query-sentence keywords (`After`, `Before`, `Containing`,
  `EndsWith`, `StartsWith`, `Exists`, `isEmpty`/`isNotEmpty`, `Within`, …). The
  sentence grammar covers comparison, `LIKE` / `NOT LIKE`, `REGEXP`,
  `IS IN` / `IS NOT IN`, `IS NULL` / `IS NOT NULL`, `AND` / `OR` / `NOT` and
  parenthesised groups.

## Dependencies

- `tom_core_kernel` — `tomReflector` (mirrors), the `TomZoned*` date/time types.
- The datasources module — `TomDbType`/`TomOperator`/`SqlString`,
  `TomStandardSqlDialect` / `MariadbSqlDialect` (including the `aggregate`,
  `aliased`, `groupByClause` and `havingClause` fragments), `TomQuery` family
  (`TomSelect` / `TomCount` / `TomDelete` / `TomLiteralSelect`),
  `TomAggregateFunction`, `TomTypedPersistenceBase`, `TomTypePersistenceInfo`,
  `TomDataSourceInfo`, `TomPreparedStatement`.
- The little-things module — `TomServerException` (base of the module's
  exceptions).
