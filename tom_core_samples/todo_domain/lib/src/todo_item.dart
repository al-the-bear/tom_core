import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'enums.dart';

/// A single task in a [TodoList] — the leaf entity the CRUD forms edit.
///
/// [priority] and [label] are stored as the enum's [Enum.name] in a
/// `TomString` so they persist and serialize without a custom codec; the
/// [priorityValue] / [labelValue] accessors expose them as typed enums.
@tomReflector
class TodoItem extends TomClass {
  /// Stable identifier (the server's primary key).
  late final id = TomString('');

  /// Short task title.
  late final title = TomString('');

  /// Optional longer description.
  late final description = TomString('');

  /// Whether the task is completed.
  late final done = TomBool(false);

  /// Priority stored as [TodoPriority.name]; use [priorityValue] for the
  /// typed enum.
  late final priority = TomString(TodoPriority.medium.name);

  /// Category stored as [TodoLabel.name]; use [labelValue] for the typed
  /// enum.
  late final label = TomString(TodoLabel.feature.name);

  /// [User.id] of the assignee; empty when unassigned.
  late final assigneeId = TomString('');

  /// Optional due date.
  late final dueDate = TomNDateTime(null);

  /// Typed view of [priority]; falls back to [TodoPriority.medium] for an
  /// unknown stored value.
  TodoPriority get priorityValue =>
      TodoPriority.values.asNameMap()[priority.get()] ?? TodoPriority.medium;

  set priorityValue(TodoPriority value) => priority.set(value.name);

  /// Typed view of [label]; falls back to [TodoLabel.feature] for an
  /// unknown stored value.
  TodoLabel get labelValue =>
      TodoLabel.values.asNameMap()[label.get()] ?? TodoLabel.feature;

  set labelValue(TodoLabel value) => label.set(value.name);
}
