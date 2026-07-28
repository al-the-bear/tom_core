import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'enums.dart';

/// The core record: a single task on a [TodoList].
///
/// Its fields are the subject of the four-state field authorization model — the
/// gradable resource keys ([title], [status], [priority], [assigneeId],
/// [dueDate], [estimateHours], [description]) map to per-principal
/// `TomAuthState` grades.
///
/// [status], [priority], and [label] are stored as their enum's [Enum.name] in
/// a `TomString` so they persist and serialize without a custom codec; the
/// [statusValue] / [priorityValue] / [labelValue] accessors expose them as
/// typed enums.
@tomReflector
class TodoItem extends TomClass {
  /// Stable identifier (the server's primary key).
  late final id = TomString('');

  /// `TodoList.id` this item belongs to.
  late final listId = TomString('');

  /// Short task title.
  late final title = TomString('');

  /// Optional longer description.
  late final description = TomString('');

  /// Workflow state stored as [TodoStatus.name]; use [statusValue] for the
  /// typed enum.
  late final status = TomString(TodoStatus.backlog.name);

  /// Priority stored as [TodoPriority.name]; use [priorityValue] for the typed
  /// enum.
  late final priority = TomString(TodoPriority.medium.name);

  /// Category stored as [TodoLabel.name]; use [labelValue] for the typed enum.
  late final label = TomString(TodoLabel.feature.name);

  /// [User.id] of the assignee; empty when unassigned.
  late final assigneeId = TomString('');

  /// [User.id] of the principal who created the item.
  late final reporterId = TomString('');

  /// Optional due date.
  late final dueDate = TomNDateTime(null);

  /// Optional effort estimate in hours.
  late final estimateHours = TomNDouble(null);

  /// Free-form tags applied to the item.
  late final tags = TomList<TomString>();

  /// Blob-storage key of the item's attachment; empty when there is none.
  ///
  /// The key is *minted by the server* when the file is uploaded through the
  /// framework file endpoint — the client reads it (to build the download URL)
  /// but never authors it, so a value set here does not travel to the row on
  /// save. The matching `internal_note` column exists only server-side: it is
  /// not exposed over HTTP, so the domain has no reason to carry it.
  late final attachment = TomString('');

  /// When the item was created; null until persisted.
  late final createdAt = TomNDateTime(null);

  /// When the item was last modified; null until persisted.
  late final updatedAt = TomNDateTime(null);

  /// Typed view of [status]; falls back to [TodoStatus.backlog] for an unknown
  /// stored value.
  TodoStatus get statusValue =>
      TodoStatus.values.asNameMap()[status.get()] ?? TodoStatus.backlog;

  set statusValue(TodoStatus value) => status.set(value.name);

  /// Typed view of [priority]; falls back to [TodoPriority.medium] for an
  /// unknown stored value.
  TodoPriority get priorityValue =>
      TodoPriority.values.asNameMap()[priority.get()] ?? TodoPriority.medium;

  set priorityValue(TodoPriority value) => priority.set(value.name);

  /// Typed view of [label]; falls back to [TodoLabel.feature] for an unknown
  /// stored value.
  TodoLabel get labelValue =>
      TodoLabel.values.asNameMap()[label.get()] ?? TodoLabel.feature;

  set labelValue(TodoLabel value) => label.set(value.name);
}
