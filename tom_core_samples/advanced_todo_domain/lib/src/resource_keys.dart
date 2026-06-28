/// Stable resource keys for the gradable `TodoItem` fields.
///
/// The four-state field authorization model keys per-field `TomAuthState`
/// grades on these strings: the auth server's grant matrix stores
/// `(ProjectRole, resourceKey) → TomAuthState` rows, the app server projects the
/// resolved states to the client, and each form field is rendered through the
/// grade for its key. The set is **named and stable** so the same key means the
/// same field on the server, over the wire, and in the client — the same way
/// `core_server_sample` defines its keys.
library;

/// Stable resource keys for the gradable [TodoItem] fields.
///
/// The key for the effort estimate is `todo.item.estimate` even though the
/// entity field is `estimateHours` — the resource key names the *concept*, not
/// the storage field.
class TodoItemResourceKeys {
  const TodoItemResourceKeys._();

  /// Resource key for the item title field.
  static const String title = 'todo.item.title';

  /// Resource key for the workflow status field.
  static const String status = 'todo.item.status';

  /// Resource key for the priority field.
  static const String priority = 'todo.item.priority';

  /// Resource key for the assignee field.
  static const String assigneeId = 'todo.item.assigneeId';

  /// Resource key for the due-date field.
  static const String dueDate = 'todo.item.dueDate';

  /// Resource key for the effort-estimate field (the `estimateHours` entity
  /// field).
  static const String estimate = 'todo.item.estimate';

  /// Resource key for the description field.
  static const String description = 'todo.item.description';

  /// Every gradable key, in display order.
  static const List<String> all = [
    title,
    status,
    priority,
    assigneeId,
    dueDate,
    estimate,
    description,
  ];
}
