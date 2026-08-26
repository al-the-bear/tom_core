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

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomDbTable` · `TomDbColumn` · `TomEntityId` · `TomReference` · `TomJoinTable` | Mapping annotations placed on a reflected entity. |
| `TomAnnotationAnalyzer` | Mixin that reads the mapping annotations off an entity. |
| `TomRepository<T, K>` | CRUD contract: `save`, `findById`, `findAll`, `delete`/`deleteById`, `count`, `existsById`, and `*ByQuery` / `*ByQuerySentence`. |
| `TomSqlDatasourceRepository<T, K>` | SQL implementation over a `TomDataSource`; subclass and override `sqlDialect`. |
| `TomPageRequest` · `TomSortField` · `TomSortDirection` | The optional row window (`offset` + `limit`) and per-field sort the finders accept; an unsorted window gets the primary key appended so consecutive pages partition the result. |
| `TomQueryBuilder` | Mixin offering `isNull` / `isNotNull` / `isIn` / `between` / `like` plus the `Eq` / `Neq` / `And` / `Or` / `Not` operators and the typed column references (`IntCol`, `StringCol`, …). |
| `TomDbScope` | Annotation declaring an entity's row scope — its scope field and kind — or, as `TomDbScope.unscoped()`, the deliberate opt-out. |
| `TomDataScopeRegistry` | The named scope-kind resolvers (`owner`, `group`, `resource`, plus application kinds), sync or async, read and write. |
| `TomDataScope` | Renders a resolver's answer into a bound `IN` (or OR-union) predicate; `runUnscoped` is the recursion guard async resolvers run their own reads inside. |
| `TomResourceScopeSource` | The hook behind the `resource` kind, implemented and installed by the authorization module. |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_core_server/tom_core_server.dart';

// A reflected entity mapped to a table by annotations:
@tomReflector
@TomDbTable(datasource: 'todo', table: 'todo_item', primaryKeyField: 'id')
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

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
