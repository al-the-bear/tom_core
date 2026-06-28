/// `app_db` persistence records — the app server's relational view of the
/// task-management model (workspaces, projects, lists, items, comments,
/// subtasks, and shares).
///
/// These are the server-side counterparts of the observable domain entities:
/// `advanced_todo_domain` carries the form-bindable `TomClass` entities
/// ([Workspace], [Project], [TodoList], [TodoItem], [TodoComment], [Subtask],
/// [Share]) whose fields are `TomString` / `TomBool` / `TomList` value holders
/// and whose ids are display strings, while the object-persistence layer needs
/// the opposite shape — plain typed fields, an integer surrogate primary key,
/// explicit integer foreign-key columns, and no nested collections. The pure
/// conversions between the two worlds live in `app_mapping.dart` (step 15).
///
/// Each record is `@tomReflector` + `@TomDbTable` on the `app_db` datasource and
/// is loaded/saved through a process-wide singleton `TomSqlDatasourceRepository`,
/// exactly as `core_server_sample` and `advanced_auth_server` do.
///
/// **Cross-database user references.** The principals these rows point at
/// ([WorkspaceRecord.ownerId], [ItemRecord.assigneeId], …) live in the auth
/// server's `auth_db.auth_users`, not in `app_db`. They are stored as the auth
/// user's surrogate id (`int`) — a logical reference, not an enforced foreign
/// key — so a token minted by the auth server resolves to the same numeric id
/// here. The mapping layer converts between those ints and the domain's string
/// `User.id`s.
library;

// tom_core_server re-exports tom_core_kernel, so `@tomReflector` and the
// persistence annotations both resolve through this single barrel.
import 'package:tom_core_server/tom_core_server.dart';

/// The `app_db` datasource name every record below binds to.
///
/// The app-server boot (step 21) registers this connection; the reused
/// framework `TomResourceGrant` (the field-grade matrix the auth server seeds)
/// is read through the framework default `main` datasource, which the boot
/// points at the same physical schema.
const String appDatasource = 'app_db';

/// A workspace row in `app_workspaces` — the root of the ownership chain
/// `Workspace → Project → TodoList → TodoItem` the access resolver walks.
@tomReflector
@TomDbTable(datasource: appDatasource, table: 'app_workspaces', primaryKeyField: 'id')
class WorkspaceRecord {
  /// Surrogate primary key (`null` until first persisted).
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// Display name, e.g. `Acme Engineering`.
  @TomDbColumn(columnName: 'name')
  String? name;

  /// Auth `auth_users.id` of the owning principal (cross-db logical reference).
  @TomDbColumn(columnName: 'owner_id')
  int? ownerId;

  /// When the workspace was created; `null` until persisted.
  @TomDbColumn(columnName: 'created_at')
  DateTime? createdAt;
}

/// Repository for [WorkspaceRecord].
class WorkspaceRepository
    extends TomSqlDatasourceRepository<WorkspaceRecord, int> {}

/// Process-wide singleton repository instance.
final workspaceRepository = WorkspaceRepository();

/// A project row in `app_projects`; groups [ListRecord]s inside a workspace.
@tomReflector
@TomDbTable(datasource: appDatasource, table: 'app_projects', primaryKeyField: 'id')
class ProjectRecord {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// [WorkspaceRecord.id] this project belongs to.
  @TomDbColumn(columnName: 'workspace_id')
  int? workspaceId;

  /// Display name, e.g. `Website relaunch`.
  @TomDbColumn(columnName: 'name')
  String? name;

  /// Free-form summary shown on the project header.
  @TomDbColumn(columnName: 'description')
  String? description;

  /// UI accent colour as a hex string, e.g. `#3366FF`; empty/`null` when unset.
  @TomDbColumn(columnName: 'colour')
  String? colour;

  /// Whether the project is archived (hidden from the active board).
  @TomDbColumn(columnName: 'archived')
  bool? archived;
}

/// Repository for [ProjectRecord].
class ProjectRepository extends TomSqlDatasourceRepository<ProjectRecord, int> {}

/// Process-wide singleton repository instance.
final projectRepository = ProjectRepository();

/// A list (board column) row in `app_lists`; groups [ItemRecord]s.
@tomReflector
@TomDbTable(datasource: appDatasource, table: 'app_lists', primaryKeyField: 'id')
class ListRecord {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// [ProjectRecord.id] this list belongs to.
  @TomDbColumn(columnName: 'project_id')
  int? projectId;

  /// Display name, e.g. `Sprint backlog`.
  @TomDbColumn(columnName: 'name')
  String? name;

  /// Zero-based ordering position within the project.
  @TomDbColumn(columnName: 'position')
  int? position;
}

/// Repository for [ListRecord].
class ListRepository extends TomSqlDatasourceRepository<ListRecord, int> {}

/// Process-wide singleton repository instance.
final listRepository = ListRepository();

/// An item row in `app_items` — the leaf entity whose fields carry the
/// four-state field-authorization grades.
///
/// `status` / `priority` / `label` are stored as their enum's name (the
/// `advanced_todo_domain` convention). `tags` is stored as a single serialized
/// text column rather than a child table — the mapping layer (step 15) owns the
/// join/split codec, keeping this row flat like every other record.
@tomReflector
@TomDbTable(datasource: appDatasource, table: 'app_items', primaryKeyField: 'id')
class ItemRecord {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// [ListRecord.id] this item belongs to.
  @TomDbColumn(columnName: 'list_id')
  int? listId;

  /// Short task title.
  @TomDbColumn(columnName: 'title')
  String? title;

  /// Optional longer description.
  @TomDbColumn(columnName: 'description')
  String? description;

  /// Workflow state stored as the `TodoStatus` name (`backlog` / `todo` / …).
  @TomDbColumn(columnName: 'status')
  String? status;

  /// Priority stored as the `TodoPriority` name (`low` / `medium` / `high` /
  /// `critical`).
  @TomDbColumn(columnName: 'priority')
  String? priority;

  /// Category stored as the `TodoLabel` name (`feature` / `bug` / …).
  @TomDbColumn(columnName: 'label')
  String? label;

  /// Auth `auth_users.id` of the assignee; `null` when unassigned.
  @TomDbColumn(columnName: 'assignee_id')
  int? assigneeId;

  /// Auth `auth_users.id` of the principal who created the item.
  @TomDbColumn(columnName: 'reporter_id')
  int? reporterId;

  /// Optional due date.
  @TomDbColumn(columnName: 'due_date')
  DateTime? dueDate;

  /// Optional effort estimate in hours.
  @TomDbColumn(columnName: 'estimate_hours')
  double? estimateHours;

  /// Free-form tags, serialized to a single text column by the mapping layer.
  @TomDbColumn(columnName: 'tags')
  String? tags;

  /// When the item was created; `null` until persisted.
  @TomDbColumn(columnName: 'created_at')
  DateTime? createdAt;

  /// When the item was last modified; `null` until persisted.
  @TomDbColumn(columnName: 'updated_at')
  DateTime? updatedAt;
}

/// Repository for [ItemRecord].
class ItemRepository extends TomSqlDatasourceRepository<ItemRecord, int> {}

/// Process-wide singleton repository instance.
final itemRepository = ItemRepository();

/// A comment row in `app_comments` — a discussion entry on an [ItemRecord].
@tomReflector
@TomDbTable(datasource: appDatasource, table: 'app_comments', primaryKeyField: 'id')
class CommentRecord {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// [ItemRecord.id] this comment is attached to.
  @TomDbColumn(columnName: 'item_id')
  int? itemId;

  /// Auth `auth_users.id` of the comment author.
  @TomDbColumn(columnName: 'author_id')
  int? authorId;

  /// Comment text.
  @TomDbColumn(columnName: 'body')
  String? body;

  /// When the comment was posted; `null` until persisted.
  @TomDbColumn(columnName: 'created_at')
  DateTime? createdAt;
}

/// Repository for [CommentRecord].
class CommentRepository extends TomSqlDatasourceRepository<CommentRecord, int> {}

/// Process-wide singleton repository instance.
final commentRepository = CommentRepository();

/// A subtask row in `app_subtasks` — a checklist row on an [ItemRecord].
@tomReflector
@TomDbTable(datasource: appDatasource, table: 'app_subtasks', primaryKeyField: 'id')
class SubtaskRecord {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// [ItemRecord.id] this subtask belongs to.
  @TomDbColumn(columnName: 'item_id')
  int? itemId;

  /// Short label for the checklist row.
  @TomDbColumn(columnName: 'title')
  String? title;

  /// Whether the subtask is completed.
  @TomDbColumn(columnName: 'done')
  bool? done;

  /// Zero-based ordering position within the item.
  @TomDbColumn(columnName: 'position')
  int? position;
}

/// Repository for [SubtaskRecord].
class SubtaskRepository extends TomSqlDatasourceRepository<SubtaskRecord, int> {}

/// Process-wide singleton repository instance.
final subtaskRepository = SubtaskRepository();

/// A share row in `app_shares` — the cross-user access grant the resource
/// resolver (step 17) reads.
///
/// [resourceType] / [resourceId] address the granted object polymorphically
/// (a workspace, project, list, or item), so [resourceId] is the int surrogate
/// key of a row in the matching `app_*` table and [resourceType] names which
/// table. [projectRole] is stored as the `ProjectRole` name.
@tomReflector
@TomDbTable(datasource: appDatasource, table: 'app_shares', primaryKeyField: 'id')
class ShareRecord {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// Kind of resource granted (`workspace` / `project` / `list` / `item`).
  @TomDbColumn(columnName: 'resource_type')
  String? resourceType;

  /// Surrogate id of the granted resource within [resourceType]'s table.
  @TomDbColumn(columnName: 'resource_id')
  int? resourceId;

  /// Auth `auth_users.id` the access is granted to.
  @TomDbColumn(columnName: 'grantee_user_id')
  int? granteeUserId;

  /// Role granted on the resource, stored as the `ProjectRole` name
  /// (`owner` / `editor` / `commenter` / `viewer`).
  @TomDbColumn(columnName: 'project_role')
  String? projectRole;

  /// Auth `auth_users.id` of the principal who created the share.
  @TomDbColumn(columnName: 'granted_by_id')
  int? grantedById;

  /// When the share was created; `null` until persisted.
  @TomDbColumn(columnName: 'created_at')
  DateTime? createdAt;
}

/// Repository for [ShareRecord].
class ShareRepository extends TomSqlDatasourceRepository<ShareRecord, int> {}

/// Process-wide singleton repository instance.
final shareRepository = ShareRepository();
