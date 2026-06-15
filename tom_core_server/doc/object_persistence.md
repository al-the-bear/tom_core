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
(`findByQuery`), and raw SQL (`executeQueryString`).

## Query Sentences

A *query sentence* is a Spring-Data-style phrase compiled by
`TomQuerySentenceCompiler.compileQuerySentence`:

```text
find by name = :name order by age desc
count by status IS IN ( :statuses )
delete by id = $id
```

- The first word picks the kind: `find` → `TomSelect`, `count` → `TomCount`,
  `delete` → `TomDelete`.
- The part before `by` carries options: `distinct`, and `top N` / `first N`
  (mutually exclusive).
- The part after `by` is the predicate, optionally followed by
  `order by <fields> [asc|desc]` (the direction must be the last token).

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

## How Metadata Is Resolved

`TomAnnotationAnalyzer` reads the `tomReflector` `ClassMirror` of an entity and
translates its annotations into a `TomTypePersistenceInfo` and a list of
`TomColumnInformation` (one per annotated field). Results are memoised per type
in `mirrorCache` / `tableCache` / `columnInfoCache`. A `TomColumnInformation`
also provides reflection-backed `getVariableValue` / `setVariableValue`
accessors that the repository uses to read and write entity fields. A type that
is not registered with `tomReflector`, or lacks a `@TomDbTable`, raises
`TomAnnotationAnalyzerException`.

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
- **`TomAnnotationAnalyzer`** — reflection-based metadata resolver.

## Not Yet Implemented

Tracked in the quest completion steps:

- Pageable / `Limit` / slicing / additional result sorting on the repository.
- Detection and use of `@TomJoinTable` and `@TomPersistenceEventHandler`.
- Additional query-method keywords (`After`, `Before`, `Containing`,
  `EndsWith`, `StartsWith`, `Exists`, `isEmpty`/`isNotEmpty`, `Within`, …).
- `deleteById` currently executes the wrong cached prepared statement (a
  follow-up DB-integration fix — see the completion steps).

## Dependencies

- `tom_core_kernel` — `tomReflector` (mirrors), the `TomZoned*` date/time types.
- The datasources module — `TomDbType`/`TomOperator`/`SqlString`,
  `TomStandardSqlDialect` / `MariadbSqlDialect`, `TomQuery` family
  (`TomSelect` / `TomCount` / `TomDelete` / `TomLiteralSelect`),
  `TomTypedPersistenceBase`, `TomTypePersistenceInfo`, `TomDataSourceInfo`,
  `TomPreparedStatement`.
- The little-things module — `TomServerException` (base of the module's
  exceptions).
