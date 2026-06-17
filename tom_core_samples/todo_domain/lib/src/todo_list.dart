import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'todo_item.dart';

/// A named list of [TodoItem]s belonging to a [Project].
///
/// Middle of the hierarchy: `Project → TodoList → TodoItem`.
@tomReflector
class TodoList extends TomClass {
  /// Stable identifier (the server's primary key).
  late final id = TomString('');

  /// Display name, e.g. `Sprint backlog`.
  late final name = TomString('');

  /// [Project.id] this list belongs to.
  late final projectId = TomString('');

  /// The items this list contains.
  late final items = TomList<TodoItem>();
}
