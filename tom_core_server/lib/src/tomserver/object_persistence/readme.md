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

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomDbTable` · `TomDbColumn` · `TomEntityId` · `TomReference` · `TomJoinTable` | Mapping annotations placed on a reflected entity. |
| `TomAnnotationAnalyzer` | Mixin that reads the mapping annotations off an entity. |
| `TomRepository<T, K>` | CRUD contract: `save`, `findById`, `findAll`, `delete`/`deleteById`, `count`, `existsById`, and `*ByQuery` / `*ByQuerySentence`. |
| `TomSqlDatasourceRepository<T, K>` | SQL implementation over a `TomDataSource`; subclass and override `sqlDialect`. |
| `TomQueryBuilder` | Mixin offering `isNull` / `isNotNull` / `isIn` / `between` / `like` plus the `Eq` / `Neq` / `And` / `Or` / `Not` operators and the typed column references (`IntCol`, `StringCol`, …). |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_core_server/tom_core_server.dart';

// A reflected entity mapped to a table by annotations:
@tomReflector
@TomDbTable(datasource: 'todo', table: 'todo_item', primaryKeyField: 'id')
class TodoItem {
  @TomEntityId()
  @TomDbColumn(columnName: 'id')
  int id = 0;

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
