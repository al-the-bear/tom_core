/// Reflection generation entrypoint for the persistence records.
///
/// The reflection generator follows the import graph from a file that exposes
/// a `main()` to discover every `@tomReflector` type. This file is that root
/// for the sample's DB-mapped records — it is **not** used at runtime. The live
/// server boot imports the generated `reflection_entry.reflection.dart` (run
/// `./reflection_generation.sh`) so the persistence layer can reflect the
/// records into SQL.
library;

import 'persistence/todo_records.dart';

/// Touches each reflected record so the generator reaches it. Never invoked in
/// production.
void main() {
  TodoUserRecord();
  TodoProjectRecord();
  TodoListRecord();
  TodoItemRecord();
}
