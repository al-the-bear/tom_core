/// Stable resource keys for the gradable [TodoItem] fields.
///
/// These mirror `core_server_sample`'s `TodoItemResourceKeys` and the
/// `resource_key` values its migration seeds into `tom_resource_grant`, so the
/// per-field [TomAuthState] the server resolves lines up with the field the
/// client renders. One key vocabulary across the tier.
library;

/// The resource key for each gradable todo-item field, and the parser that
/// turns a stored token back into a [TomAuthState].
class TodoFieldKeys {
  const TodoFieldKeys._();

  /// Resource key for the item title field.
  static const String title = 'todo.item.title';

  /// Resource key for the done/complete toggle.
  static const String done = 'todo.item.done';

  /// Resource key for the priority field.
  static const String priority = 'todo.item.priority';

  /// Resource key for the assignee field.
  static const String assigneeId = 'todo.item.assigneeId';

  /// Every gradable key, in display order.
  static const List<String> all = [title, done, priority, assigneeId];
}
