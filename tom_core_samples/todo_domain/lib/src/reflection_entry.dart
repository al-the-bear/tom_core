/// Reflection generation entrypoint.
///
/// The reflection generator only processes files that expose a `main()`
/// entry point and follows the import graph from there to discover every
/// `@tomReflector` entity. This file exists solely to give the generator
/// that root — it is **not** used at runtime. Consumers call
/// [initializeReflection] (re-exported from `todo_domain.dart`, generated
/// into `reflection_entry.reflection.dart`).
library;

import 'enums.dart';
import 'project.dart';
import 'todo_item.dart';
import 'todo_list.dart';
import 'user.dart';
import 'wire/todo_field_matrix_dto.dart';
import 'wire/todo_item_dto.dart';

/// Touches each reflected type so the imports are retained and the generator
/// can reach every entity. Never invoked in production.
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
