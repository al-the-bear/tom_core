/// Reflection seed root for the `advanced_todo_domain` **tests** (G-REFL-2).
///
/// The domain is a library — it carries no runtime `main()`, so it does not ship
/// a reflection seed in `lib/`. Reflection is needed only to run the package's
/// own tests, so the single seed lives here in `test/`: the reflection generator
/// treats this file as its root (see `build.yaml`), follows the import graph
/// from `main()`, and emits `run_all_tests.reflection.dart` next to it. Every
/// test in this package installs that one seed via
/// `setUpAll(initializeReflection)`.
///
/// The `main()` merely *touches* each reflected type so the imports are retained
/// and the generator can reach every entity; it is never run as a program.
library;

import 'package:advanced_todo_domain/advanced_todo_domain.dart';

void main() {
  User();
  Workspace();
  Project();
  TodoList();
  TodoItem();
  TodoComment();
  Subtask();
  Share();
  TodoStatus.values;
  TodoPriority.values;
  TodoLabel.values;
  UserStatus.values;
  ProjectRole.values;
}
