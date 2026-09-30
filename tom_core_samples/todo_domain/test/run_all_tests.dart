/// Reflection seed root for the `todo_domain` **tests** (G-REFL-2).
///
/// The domain is a library — it carries no runtime `main()`, so it does not ship
/// a reflection seed in `lib/`. Every runtime that uses it builds a seed of its
/// own covering its whole program (`core_server_sample`'s
/// `bin/server_start.reflection.dart`, `core_client_sample`'s
/// `lib/reflection_seed.dart`); a second seed exported from this package would
/// collide with theirs on `initializeReflection`, and which one a consumer got
/// would be decided by import order.
///
/// Reflection is needed here only to run the package's own tests and examples,
/// so the single seed lives in `test/`: the reflection generator treats this
/// file as its root (see `build.yaml`), follows the import graph from `main()`,
/// and emits `run_all_tests.reflection.dart` next to it.
///
/// The `main()` merely *touches* each reflected type so the imports are retained
/// and the generator can reach every entity and wire DTO; it is never run as a
/// program.
library;

import 'package:todo_domain/todo_domain.dart';

void main() {
  User();
  Project();
  TodoList();
  TodoItem();
  TodoPriority.values;
  TodoLabel.values;
  TodoItemDto();
  TodoFieldMatrixDto();
}
