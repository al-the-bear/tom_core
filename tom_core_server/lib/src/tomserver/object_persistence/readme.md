# object_persistence

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Annotation-driven object/relational persistence. A reflected entity is mapped to
a table with `@TomDbTable` / `@TomDbColumn` / `@TomEntityId` / `@TomReference`;
the `TomAnnotationAnalyzer` reads that mapping. `TomRepository<T, K>` is the CRUD
contract (`save`, `findById`, `findAll`, `delete`, `count`, plus the
`*ByQuery` variants); `TomSqlDatasourceRepository` implements it over a
`datasources` `TomDataSource`. A typed query DSL (`TomQueryBuilder` mixin +
column/operator expressions) builds `WHERE` clauses without raw SQL.

The four finders take an optional `TomPageRequest`, so a caller asks for page N
of size M with a multi-column, mixed-direction sort instead of loading the table.
A window is applied *before* the row scope, so the page is cut out of the rows
the principal may see and `count()` reports that same scoped total — page
metadata cannot leak a row count the principal is not allowed to read.

Entities can also carry a **row scope**: `@TomDbScope` narrows every query to the
rows the current principal may see, and the repository rejects writes that fall
outside it. An entity with a `resource_key` column is scoped by the principal's
resource grants automatically, without an annotation — `@TomDbScope.unscoped()`
is the explicit opt-out.

A `@TomVersion` field turns on **optimistic locking**: every update and
`delete(entity)` matches the row only at the version the caller loaded, so of
two saves of one loaded row the second raises `TomOptimisticLockException`
instead of silently overwriting the first.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomDbTable` · `TomDbColumn` · `TomEntityId` · `TomReference` | Mapping annotations placed on a reflected entity. |
| `TomAnnotationAnalyzer` | Mixin that reads the mapping annotations off an entity. |
| `TomRepository<T, K>` | CRUD contract: `save`, `findById`, `findAll`, `delete`/`deleteById`, `count`, `existsById`, and `*ByQuery` / `*ByQuerySentence`. |
| `TomSqlDatasourceRepository<T, K>` | SQL implementation over a `TomDataSource`; subclass and override `sqlDialect`. |
| `TomVersion` · `TomOptimisticLockException` | The `int` field holding a row's version, which the repository writes and checks on every update and `delete(entity)`; and the refusal of a write whose version moved, carrying the version held and the one stored. |
| `TomCompositeKey` | The `K` of an entity whose `primaryKeyFields` lists several fields — a join table keyed by its two foreign keys — keyed by field name. |
| `TomPageRequest` · `TomSortField` · `TomSortDirection` | The optional row window (`offset` + `limit`) and per-field sort the finders accept; an unsorted window gets every primary-key field appended so consecutive pages partition the result. |
| `TomQueryBuilder` | Mixin offering `isNull` / `isNotNull` / `isIn` / `between` / `like` plus the `Eq` / `Neq` / `And` / `Or` / `Not` operators and the typed column references (`IntCol`, `StringCol`, …). |
| `TomDbScope` | Annotation declaring an entity's row scope — its scope field and kind — or, as `TomDbScope.unscoped()`, the deliberate opt-out. |
| `TomDataScopeRegistry` | The named scope-kind resolvers (`owner`, `group`, `resource`, plus application kinds), sync or async, read and write. |
| `TomDataScope` | Renders a resolver's answer into a bound `IN` (or OR-union) predicate; `runUnscoped` is the recursion guard async resolvers run their own reads inside. |
| `TomResourceScopeSource` | The hook behind the `resource` kind, implemented and installed by the authorization module. |
| `TomColumnAuthorization` · `TomColumnWriteDecision` | The per-column half of the same idea: which columns of a row this principal may *write*, resolved through a `TomColumnAuthResolver` — or a `TomRowColumnAuthResolver` when the answer depends on the row. |
| `TomFileReference` · `TomFileReferenceKeys` | Marks a `String` column as holding a blob storage key rather than the bytes, and mints the keys for it. The bytes live in the file-storage module; the column holds the way back to them. |
| `TomBlobMigration` · `TomBlobMigrationReport` | Moves the blobs those columns name from one blob store to another. The key list comes from the rows because a blob store cannot enumerate itself — which makes a file column the index of what a deployment stored, and the sweep read-only on the database. |
| `MariadbRepository<T, K>` | The MariaDB binding of `TomSqlDatasourceRepository` — constructed directly, and the only thing it adds is `MariadbSqlDialect`. |
| `TomQuerySentenceCompiler` | Compiles a written sentence (`find by owner = :who order by created_at`) into the same operator tree the builder produces, so a query can be data. |
| `TomGroupedSelect` · `TomGroupedRow` · `TomAggregate` | `GROUP BY` and its aggregates — `CountAll`, `Count`, `Sum`, `Avg`, `Min`, `Max` — projected under an alias and read back off the row by it. A `DateTime` alias reads back UTC, through the one instant convention the data source writes (`datasources/sql_instant.dart`). |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_core_server/tom_core_server.dart';

// A reflected entity mapped to a table by annotations:
@tomReflector
@TomDbTable(datasource: 'todo', table: 'todo_item', primaryKeyFields: ['id'])
class TodoItem {
  // Nullable, and null until first persisted: `save` inserts when the key is
  // null or negative and updates otherwise. `0` is a legitimate key value, not
  // a sentinel, so an `int id = 0` would take the update arm on its very first
  // save and quietly write nothing. Declare `int? id;`, or `int id = -1;` if
  // the key must be non-nullable.
  @TomEntityId()
  @TomDbColumn(columnName: 'id')
  int? id;

  @TomDbColumn(columnName: 'title')
  String title = '';
}

void main() {
  final item = TodoItem()..title = 'write the readme';
  // A TomSqlDatasourceRepository<TodoItem, int> then persists it:
  //   await repository.save(item);
  print(item.title); // write the readme
}
```

See [`doc/object_persistence.md`](../../../../doc/object_persistence.md) for the
mapping annotations, the repository contract, the query builder and paging, and
`example/object_persistence/object_persistence_example.dart` for a seventeen-step
walkthrough that checks its own results, with its entities beside it in
`example/object_persistence/object_persistence_entities.dart`.
`example/object_persistence/optimistic_locking_example.dart` walks optimistic
locking the same way, and `test/optimistic_locking_test.dart` and
`test/optimistic_locking_db_test.dart` cover it without and with a server.
`test/object_persistence_test.dart` covers the module and
`test/object_persistence_db_test.dart` adds what only a live MariaDB can answer;
`test/examples_test.dart` runs the example and
`test/readme_quick_start_test.dart` runs the snippet above, so neither can drift
away from the code.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
