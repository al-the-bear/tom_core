import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A column/section within a [Project]; groups [TodoItem]s.
///
/// Middle of the hierarchy `Project → TodoList → TodoItem`. [position] orders
/// the columns left-to-right on the board.
@tomReflector
class TodoList extends TomClass {
  /// Stable identifier (the server's primary key).
  late final id = TomString('');

  /// `Project.id` this list belongs to.
  late final projectId = TomString('');

  /// Display name, e.g. `Sprint backlog`.
  late final name = TomString('');

  /// Zero-based ordering position within the project.
  late final position = TomInt(0);
}
