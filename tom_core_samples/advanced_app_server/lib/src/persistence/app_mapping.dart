/// Pure conversions between the observable `advanced_todo_domain` entities and
/// the `app_db` persistence records.
///
/// This is the one place the two shapes meet. The domain entities are
/// form-bindable `TomClass`es with display-string ids and an observable
/// `TomList` of tags; the records use integer surrogate keys, integer
/// foreign-key columns, and a single serialized `tags` column. Each
/// `*ToRecord` flattens a domain entity into its row; each `*FromRecord`
/// rebuilds the observable entity. Every conversion here is **pure and total**,
/// so the whole boundary unit-tests without a database:
///
/// - **Unpersisted → null PK.** A domain entity whose id is still empty maps to
///   a `null` surrogate key, so the repository issues an INSERT, not an UPDATE.
/// - **Foreign keys.** Display-string ids (parent ids and the cross-database
///   `auth_users` references) convert to/from the records' integer columns.
/// - **Enum-token leniency.** Enum fields are carried as their stored name; an
///   absent column degrades to the domain default, and an unknown stored token
///   degrades through the entity's typed accessor (`statusValue`, …) rather
///   than throwing.
/// - **Tags.** The domain's `TomList<TomString>` collapses to one JSON text
///   column and rebuilds from it; a malformed column degrades to no tags.
library;

import 'dart:convert';

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
// The domain barrel does not re-export the kernel value holders; `TomString` is
// needed to append decoded tags onto the observable item list.
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'app_persistence_model.dart';

// ---------------------------------------------------------------------------
// Shared id <-> key helpers.
// ---------------------------------------------------------------------------

/// Parses a domain display-id into a database key, or `null` when the value is
/// empty (the entity has not been persisted yet → INSERT, not UPDATE).
int? _idOrNull(String value) => value.isEmpty ? null : int.tryParse(value);

/// Renders a database key back as the domain display-id (empty for `null`).
String _idString(int? value) => value?.toString() ?? '';

/// Narrows the domain's "unset" (an empty `TomString`) to SQL `NULL`.
///
/// Used for the `@TomFileReference` key columns, where the distinction matters:
/// the blob lifecycle reads "no key" as `NULL`, and an empty string would be a
/// key-shaped value the store would then try to account for.
String? _nullIfEmpty(String value) => value.isEmpty ? null : value;

/// Serializes the item's observable tags into a single JSON text column, or
/// `null` when there are none (the column is left NULL rather than `"[]"`).
String? _encodeTags(List<TomString> tags) =>
    tags.isEmpty ? null : jsonEncode([for (final tag in tags) tag.get()]);

/// Rebuilds the tag strings from the stored JSON column. Total: a `null`,
/// empty, or malformed column degrades to no tags rather than throwing.
List<String> _decodeTags(String? encoded) {
  if (encoded == null || encoded.isEmpty) return const [];
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is List) return [for (final tag in decoded) tag.toString()];
  } on FormatException {
    // A non-JSON tags column degrades to no tags (lenient, never fatal).
  }
  return const [];
}

// ---------------------------------------------------------------------------
// Workspace.
// ---------------------------------------------------------------------------

/// Flattens a [Workspace] into its [WorkspaceRecord].
WorkspaceRecord workspaceToRecord(Workspace workspace) => WorkspaceRecord()
  ..id = _idOrNull(workspace.id.get())
  ..name = workspace.name.get()
  ..ownerId = _idOrNull(workspace.ownerId.get())
  ..createdAt = workspace.createdAt.get();

/// Rebuilds a [Workspace] from its [WorkspaceRecord].
Workspace workspaceFromRecord(WorkspaceRecord record) => Workspace()
  ..id.set(_idString(record.id))
  ..name.set(record.name ?? '')
  ..ownerId.set(_idString(record.ownerId))
  ..createdAt.set(record.createdAt);

// ---------------------------------------------------------------------------
// Project.
// ---------------------------------------------------------------------------

/// Flattens a [Project] into its [ProjectRecord].
ProjectRecord projectToRecord(Project project) => ProjectRecord()
  ..id = _idOrNull(project.id.get())
  ..workspaceId = _idOrNull(project.workspaceId.get())
  ..name = project.name.get()
  ..description = project.description.get()
  ..colour = project.colour.get()
  ..archived = project.archived.get();

/// Rebuilds a [Project] from its [ProjectRecord].
Project projectFromRecord(ProjectRecord record) => Project()
  ..id.set(_idString(record.id))
  ..workspaceId.set(_idString(record.workspaceId))
  ..name.set(record.name ?? '')
  ..description.set(record.description ?? '')
  ..colour.set(record.colour ?? '')
  ..archived.set(record.archived ?? false);

// ---------------------------------------------------------------------------
// TodoList.
// ---------------------------------------------------------------------------

/// Flattens a [TodoList] into its [ListRecord].
ListRecord listToRecord(TodoList list) => ListRecord()
  ..id = _idOrNull(list.id.get())
  ..projectId = _idOrNull(list.projectId.get())
  ..name = list.name.get()
  ..position = list.position.get();

/// Rebuilds a [TodoList] from its [ListRecord].
TodoList listFromRecord(ListRecord record) => TodoList()
  ..id.set(_idString(record.id))
  ..projectId.set(_idString(record.projectId))
  ..name.set(record.name ?? '')
  ..position.set(record.position ?? 0);

// ---------------------------------------------------------------------------
// TodoItem.
// ---------------------------------------------------------------------------

/// Flattens a [TodoItem] into its [ItemRecord]. The enum fields are stored as
/// their raw name token; the tags collapse to the JSON `tags` column.
///
/// The `attachment` blob key is carried for symmetry with [itemFromRecord], not
/// because a caller may set it: the endpoint write paths merge through
/// `_enforceFieldWrites`, which overlays only *gradable* fields, so a
/// client-supplied key is dropped and the stored one preserved. The key is
/// minted server-side by `saveFile` and moves solely through the file endpoint.
/// `internalNote` has no domain counterpart at all — it is not exposed.
ItemRecord itemToRecord(TodoItem item) => ItemRecord()
  ..id = _idOrNull(item.id.get())
  ..listId = _idOrNull(item.listId.get())
  ..title = item.title.get()
  ..description = item.description.get()
  ..status = item.status.get()
  ..priority = item.priority.get()
  ..label = item.label.get()
  ..assigneeId = _idOrNull(item.assigneeId.get())
  ..reporterId = _idOrNull(item.reporterId.get())
  ..dueDate = item.dueDate.get()
  ..estimateHours = item.estimateHours.get()
  ..tags = _encodeTags(item.tags.get())
  ..attachment = _nullIfEmpty(item.attachment.get())
  ..createdAt = item.createdAt.get()
  ..updatedAt = item.updatedAt.get();

/// Rebuilds a [TodoItem] from its [ItemRecord].
///
/// Absent enum columns seed the domain defaults; an unknown stored token is
/// carried through and degrades via the entity's typed accessors. Tags are
/// appended from the decoded JSON column.
TodoItem itemFromRecord(ItemRecord record) {
  final item = TodoItem()
    ..id.set(_idString(record.id))
    ..listId.set(_idString(record.listId))
    ..title.set(record.title ?? '')
    ..description.set(record.description ?? '')
    ..status.set(record.status ?? TodoStatus.backlog.name)
    ..priority.set(record.priority ?? TodoPriority.medium.name)
    ..label.set(record.label ?? TodoLabel.feature.name)
    ..assigneeId.set(_idString(record.assigneeId))
    ..reporterId.set(_idString(record.reporterId))
    ..dueDate.set(record.dueDate)
    ..estimateHours.set(record.estimateHours)
    ..attachment.set(record.attachment ?? '')
    ..createdAt.set(record.createdAt)
    ..updatedAt.set(record.updatedAt);
  for (final tag in _decodeTags(record.tags)) {
    item.tags.add(TomString(tag));
  }
  return item;
}

// ---------------------------------------------------------------------------
// TodoComment.
// ---------------------------------------------------------------------------

/// Flattens a [TodoComment] into its [CommentRecord].
CommentRecord commentToRecord(TodoComment comment) => CommentRecord()
  ..id = _idOrNull(comment.id.get())
  ..itemId = _idOrNull(comment.itemId.get())
  ..authorId = _idOrNull(comment.authorId.get())
  ..body = comment.body.get()
  ..createdAt = comment.createdAt.get();

/// Rebuilds a [TodoComment] from its [CommentRecord].
TodoComment commentFromRecord(CommentRecord record) => TodoComment()
  ..id.set(_idString(record.id))
  ..itemId.set(_idString(record.itemId))
  ..authorId.set(_idString(record.authorId))
  ..body.set(record.body ?? '')
  ..createdAt.set(record.createdAt);

// ---------------------------------------------------------------------------
// Subtask.
// ---------------------------------------------------------------------------

/// Flattens a [Subtask] into its [SubtaskRecord].
SubtaskRecord subtaskToRecord(Subtask subtask) => SubtaskRecord()
  ..id = _idOrNull(subtask.id.get())
  ..itemId = _idOrNull(subtask.itemId.get())
  ..title = subtask.title.get()
  ..done = subtask.done.get()
  ..position = subtask.position.get();

/// Rebuilds a [Subtask] from its [SubtaskRecord].
Subtask subtaskFromRecord(SubtaskRecord record) => Subtask()
  ..id.set(_idString(record.id))
  ..itemId.set(_idString(record.itemId))
  ..title.set(record.title ?? '')
  ..done.set(record.done ?? false)
  ..position.set(record.position ?? 0);

// Cross-user shares have no `app_db` record mapping: they are framework
// `share`-mode `TomPrincipalDelegation` rows (see
// `share_delegation_store.dart`), which the share service builds directly from
// the wire `ShareRequest` — no domain `Share`↔record round-trip.
