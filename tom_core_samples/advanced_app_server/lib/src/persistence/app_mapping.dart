/// Pure conversions between the observable `advanced_todo_domain` entities and
/// the `app_db` persistence records.
///
/// This is the one place the two shapes meet. The domain entities are
/// form-bindable `TomClass`es with display-string ids and an observable
/// `TomList` of tags; the records use integer surrogate keys, integer
/// foreign-key columns, and a single serialized `tags` column. Each
/// `*ToRecord` flattens a domain entity into its row; each `*FromRecord`
/// rebuilds the observable entity. Every conversion here is **pure** — no I/O,
/// no database — so the whole boundary unit-tests without one, and **total** in
/// the record → entity direction: anything `app_db` can hold rebuilds, with an
/// unreadable stored value degrading to a default. In the entity → record
/// direction there is exactly one input they reject, a display-id that is
/// neither empty nor an integer; see [_idOrNull] for why that one is worth a
/// throw.
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

// Only for `MalformedIdException`: the id fault is named in the shared wire
// contract because both servers throw it and the client asserts on its key.
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
// The domain barrel does not re-export the kernel value holders; `TomString` is
// needed to append decoded tags onto the observable item list.
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'app_persistence_model.dart';

// ---------------------------------------------------------------------------
// Shared id <-> key helpers.
// ---------------------------------------------------------------------------

/// Parses a domain display-id into a database key: `null` for the empty id of a
/// not-yet-persisted entity, the parsed integer otherwise — and a
/// [MalformedIdException] naming [field] and [value] for anything else.
///
/// It throws rather than folding a malformed id into `null` because on this
/// side of the boundary `null` is not a neutral "unknown": it is an
/// instruction. For a primary key it means INSERT, so a corrupt id would file a
/// duplicate row while the client kept the id it thought it was updating; for a
/// foreign key ([Workspace.ownerId], [TodoItem.assigneeId], every parent id) it
/// means unowned, unassigned, or orphaned, so a corrupt id would silently strip
/// the relation. Both are writes that look successful and are found much later,
/// if at all — and unlike the read-only `core_server_sample`, this mapping sits
/// behind live mutating endpoints, so the corrupt id arrives from a client
/// rather than from a fixture.
///
/// The domain ids are free-form strings, so this is untrusted input and the
/// leniency [itemFromRecord] and [_decodeTags] apply in the other direction
/// does not carry over: degrading an unreadable *stored* enum keeps one bad row
/// from breaking a whole list, whereas degrading an unreadable *incoming* id is
/// what creates the bad row.
int? _idOrNull(String value, String field) {
  if (value.isEmpty) return null;
  final parsed = int.tryParse(value);
  if (parsed == null) throw MalformedIdException(field, value);
  return parsed;
}

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
  ..id = _idOrNull(workspace.id.get(), 'Workspace.id')
  ..name = workspace.name.get()
  ..ownerId = _idOrNull(workspace.ownerId.get(), 'Workspace.ownerId')
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
  ..id = _idOrNull(project.id.get(), 'Project.id')
  ..workspaceId = _idOrNull(project.workspaceId.get(), 'Project.workspaceId')
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
  ..id = _idOrNull(list.id.get(), 'TodoList.id')
  ..projectId = _idOrNull(list.projectId.get(), 'TodoList.projectId')
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
  ..id = _idOrNull(item.id.get(), 'TodoItem.id')
  ..listId = _idOrNull(item.listId.get(), 'TodoItem.listId')
  ..title = item.title.get()
  ..description = item.description.get()
  ..status = item.status.get()
  ..priority = item.priority.get()
  ..label = item.label.get()
  ..assigneeId = _idOrNull(item.assigneeId.get(), 'TodoItem.assigneeId')
  ..reporterId = _idOrNull(item.reporterId.get(), 'TodoItem.reporterId')
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
  ..id = _idOrNull(comment.id.get(), 'TodoComment.id')
  ..itemId = _idOrNull(comment.itemId.get(), 'TodoComment.itemId')
  ..authorId = _idOrNull(comment.authorId.get(), 'TodoComment.authorId')
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
  ..id = _idOrNull(subtask.id.get(), 'Subtask.id')
  ..itemId = _idOrNull(subtask.itemId.get(), 'Subtask.itemId')
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
