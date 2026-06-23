/// Persistence records — the server's database-mapped view of the todo model.
///
/// The shared `todo_domain` entities ([User], [Project], [TodoList],
/// [TodoItem]) are observable [TomClass]es built for *form binding* on the
/// client: their fields are `TomString` / `TomBool` / `TomList` value holders,
/// and their ids are display strings. The object-persistence layer needs the
/// opposite shape — plain typed fields, an integer primary key, foreign-key
/// columns, no nested collections — so these records are the persistence-side
/// counterparts. `todo_mapping.dart` converts between the two worlds.
///
/// Keeping the DB mapping here (rather than annotating the domain entities)
/// settles the blueprint's open question in the only direction item 14's
/// realised shape allows: the domain model is the client's observable form
/// model, the records are the server's relational model, and the boundary is
/// explicit and tested. See `core_server_sample_design.md` (Open decision #1).
library;

// tom_core_server re-exports tom_core_kernel, so `@tomReflector` and the
// persistence annotations both resolve through this single barrel.
import 'package:tom_core_server/tom_core_server.dart';

/// A user row in `todo_users`.
@tomReflector
@TomDbTable(datasource: 'todo_db', table: 'todo_users', primaryKeyField: 'id')
class TodoUserRecord {
  /// Surrogate primary key (`null` until first persisted).
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// Name shown in the UI.
  @TomDbColumn(columnName: 'display_name')
  String? displayName;

  /// Login / contact email (unique).
  @TomDbColumn(columnName: 'email')
  String? email;

  /// Role key driving four-state authorization (`owner` / `member` / `viewer`).
  @TomDbColumn(columnName: 'role')
  String? role;

  /// Hashed password (kernel crypto); `null` for the seeded demo user.
  @TomDbColumn(columnName: 'password_hash')
  String? passwordHash;

  /// Hash algorithm tag stored alongside [passwordHash].
  @TomDbColumn(columnName: 'hash_type')
  String? hashType;
}

/// Repository for [TodoUserRecord].
class TodoUserRepository extends TomSqlDatasourceRepository<TodoUserRecord, int> {
}

/// Process-wide singleton repository instance.
final todoUserRepository = TodoUserRepository();

/// A project row in `todo_projects`.
@tomReflector
@TomDbTable(datasource: 'todo_db', table: 'todo_projects', primaryKeyField: 'id')
class TodoProjectRecord {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// Display name.
  @TomDbColumn(columnName: 'name')
  String? name;

  /// Free-form summary.
  @TomDbColumn(columnName: 'description')
  String? description;

  /// [TodoUserRecord.id] of the owner.
  @TomDbColumn(columnName: 'owner_id')
  int? ownerId;
}

/// Repository for [TodoProjectRecord].
class TodoProjectRepository
    extends TomSqlDatasourceRepository<TodoProjectRecord, int> {}

/// Process-wide singleton repository instance.
final todoProjectRepository = TodoProjectRepository();

/// A list row in `todo_lists`.
@tomReflector
@TomDbTable(datasource: 'todo_db', table: 'todo_lists', primaryKeyField: 'id')
class TodoListRecord {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// Display name.
  @TomDbColumn(columnName: 'name')
  String? name;

  /// [TodoProjectRecord.id] this list belongs to.
  @TomDbColumn(columnName: 'project_id')
  int? projectId;
}

/// Repository for [TodoListRecord].
class TodoListRepository
    extends TomSqlDatasourceRepository<TodoListRecord, int> {}

/// Process-wide singleton repository instance.
final todoListRepository = TodoListRepository();

/// An item row in `todo_items` — the leaf entity the CRUD endpoints edit.
@tomReflector
@TomDbTable(datasource: 'todo_db', table: 'todo_items', primaryKeyField: 'id')
class TodoItemRecord {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// Short task title.
  @TomDbColumn(columnName: 'title')
  String? title;

  /// Optional longer description.
  @TomDbColumn(columnName: 'description')
  String? description;

  /// Whether the task is completed.
  @TomDbColumn(columnName: 'done')
  bool? done;

  /// Priority stored as the enum name (`low` / `medium` / `high` / `critical`).
  @TomDbColumn(columnName: 'priority')
  String? priority;

  /// Category stored as the enum name.
  @TomDbColumn(columnName: 'label')
  String? label;

  /// [TodoUserRecord.id] of the assignee; `null` when unassigned.
  @TomDbColumn(columnName: 'assignee_id')
  int? assigneeId;

  /// Optional due date.
  @TomDbColumn(columnName: 'due_date')
  DateTime? dueDate;

  /// [TodoListRecord.id] this item belongs to.
  @TomDbColumn(columnName: 'list_id')
  int? listId;
}

/// Repository for [TodoItemRecord].
class TodoItemRepository
    extends TomSqlDatasourceRepository<TodoItemRecord, int> {}

/// Process-wide singleton repository instance.
final todoItemRepository = TodoItemRepository();
