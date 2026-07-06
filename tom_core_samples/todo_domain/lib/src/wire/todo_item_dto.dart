import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../enums.dart';

/// The JSON wire shape of a todo item — what `core_server_sample`'s `GET /todos`
/// emits (a bare array of these) and `core_client_sample`'s live read path
/// parses back.
///
/// A reflection-first wire DTO (G-DTO): `@tomReflector`, plain non-`final`
/// fields, and **no** hand-written `toJson`/`fromJson`. The framework serializes
/// it through the kernel reflection path ([TomReflectionInfo.getValues] /
/// [TomReflectionInfo.createInstanceFromJson]) exactly like the reflected domain
/// entities — the server endpoint pipeline drives it directly, while the client
/// goes through the [dtoFromJson] / [dtoToMap] helpers.
///
/// The item is a flat, transport-friendly projection: the surrogate key and
/// foreign keys travel as strings ([id], [assigneeId], [listId]), [priority] /
/// [label] travel as their enum [Enum.name] token, and [dueDate] as an
/// ISO-8601 string (empty when unset). The client maps this into the observable
/// `TodoItem` form entity; the server builds it from its persistence record.
@tomReflector
class TodoItemDto {
  /// Surrogate primary key as a string; empty for a never-persisted item.
  String id;

  /// Short task title.
  String title;

  /// Optional longer description.
  String description;

  /// Whether the task is completed.
  bool done;

  /// Priority as its [TodoPriority] `.name` token; empty defaults to
  /// [TodoPriority.medium] at read time.
  String priority;

  /// Category as its [TodoLabel] `.name` token; empty defaults to
  /// [TodoLabel.feature] at read time.
  String label;

  /// Assignee's user id as a string; empty when unassigned.
  String assigneeId;

  /// Due date as an ISO-8601 string; empty when unset.
  String dueDate;

  /// Owning list id as a string; empty when unset.
  String listId;

  /// Creates a wire item. Every field defaults to a closed-safe empty value so a
  /// partial payload round-trips without throwing.
  TodoItemDto({
    this.id = '',
    this.title = '',
    this.description = '',
    this.done = false,
    this.priority = '',
    this.label = '',
    this.assigneeId = '',
    this.dueDate = '',
    this.listId = '',
  });

  @override
  String toString() => 'TodoItemDto($id: $title)';
}
