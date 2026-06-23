/// Conversions between the observable `todo_domain` entities (the client's
/// form model) and the relational persistence records (the server's DB model).
///
/// This is the one place the two shapes meet. The domain uses display-string
/// ids and nested `TomList` collections; the records use integer primary keys
/// and foreign-key columns. Each `*ToRecord` flattens a domain entity into its
/// row (the caller supplies the parent foreign key that the domain models as
/// containment); each `*FromRecord` rebuilds the observable entity. The
/// conversions are pure and total, so they unit-test without a database.
library;

import 'package:todo_domain/todo_domain.dart';

import 'todo_records.dart';

/// Parses a domain display-id into a database key, or `null` when the entity
/// has not been persisted yet (empty id).
int? _idOrNull(String value) => value.isEmpty ? null : int.tryParse(value);

/// Renders a database key back as the domain display-id (empty for `null`).
String _idString(int? value) => value?.toString() ?? '';

/// Flattens a [User] into its [TodoUserRecord]. Auth columns
/// ([TodoUserRecord.passwordHash] / [TodoUserRecord.hashType]) are server-only
/// and never round-trip through the domain, so they are left untouched.
TodoUserRecord userToRecord(User user) => TodoUserRecord()
  ..id = _idOrNull(user.id.get())
  ..displayName = user.displayName.get()
  ..email = user.email.get()
  ..role = user.role.get();

/// Rebuilds a [User] from its [TodoUserRecord].
User userFromRecord(TodoUserRecord record) => User()
  ..id.set(_idString(record.id))
  ..displayName.set(record.displayName ?? '')
  ..email.set(record.email ?? '')
  ..role.set(record.role ?? 'member');

/// Flattens a [Project] into its [TodoProjectRecord]. The nested
/// [Project.lists] are persisted separately (one [TodoListRecord] each), so
/// they are not part of the row.
TodoProjectRecord projectToRecord(Project project) => TodoProjectRecord()
  ..id = _idOrNull(project.id.get())
  ..name = project.name.get()
  ..description = project.description.get()
  ..ownerId = _idOrNull(project.ownerId.get());

/// Rebuilds a [Project] from its [TodoProjectRecord] (without its lists; load
/// those via [TodoListRepository] and attach with [listFromRecord]).
Project projectFromRecord(TodoProjectRecord record) => Project()
  ..id.set(_idString(record.id))
  ..name.set(record.name ?? '')
  ..description.set(record.description ?? '')
  ..ownerId.set(_idString(record.ownerId));

/// Flattens a [TodoList] into its [TodoListRecord]. The nested
/// [TodoList.items] persist separately.
TodoListRecord listToRecord(TodoList list) => TodoListRecord()
  ..id = _idOrNull(list.id.get())
  ..name = list.name.get()
  ..projectId = _idOrNull(list.projectId.get());

/// Rebuilds a [TodoList] from its [TodoListRecord] (without its items).
TodoList listFromRecord(TodoListRecord record) => TodoList()
  ..id.set(_idString(record.id))
  ..name.set(record.name ?? '')
  ..projectId.set(_idString(record.projectId));

/// Flattens a [TodoItem] into its [TodoItemRecord].
///
/// The domain models an item's membership by containment ([TodoList.items]);
/// the row needs an explicit `list_id`, so the owning [listId] is passed in.
TodoItemRecord itemToRecord(TodoItem item, {required int listId}) =>
    TodoItemRecord()
      ..id = _idOrNull(item.id.get())
      ..title = item.title.get()
      ..description = item.description.get()
      ..done = item.done.get()
      ..priority = item.priority.get()
      ..label = item.label.get()
      ..assigneeId = _idOrNull(item.assigneeId.get())
      ..dueDate = item.dueDate.get()
      ..listId = listId;

/// Rebuilds a [TodoItem] from its [TodoItemRecord]. Unknown stored enum tokens
/// degrade through the domain's typed accessors to their defaults.
TodoItem itemFromRecord(TodoItemRecord record) => TodoItem()
  ..id.set(_idString(record.id))
  ..title.set(record.title ?? '')
  ..description.set(record.description ?? '')
  ..done.set(record.done ?? false)
  ..priority.set(record.priority ?? TodoPriority.medium.name)
  ..label.set(record.label ?? TodoLabel.feature.name)
  ..assigneeId.set(_idString(record.assigneeId))
  ..dueDate.set(record.dueDate);
