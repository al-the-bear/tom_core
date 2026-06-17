import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'todo_list.dart';

/// A workspace that groups [TodoList]s under a single owning [User].
///
/// Top of the todo-management hierarchy: `Project → TodoList → TodoItem`.
@tomReflector
class Project extends TomClass {
  /// Stable identifier (the server's primary key).
  late final id = TomString('');

  /// Display name, e.g. `Website relaunch`.
  late final name = TomString('');

  /// Free-form summary shown on the project header.
  late final description = TomString('');

  /// [User.id] of the project owner.
  late final ownerId = TomString('');

  /// The lists this project contains.
  late final lists = TomList<TodoList>();
}
