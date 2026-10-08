/// `app_db` persistence records — the app server's relational view of the
/// task-management model (workspaces, projects, lists, items, comments, and
/// subtasks).
///
/// Cross-user *shares* are not an `app_db` record at all: they are framework
/// `share`-mode `TomPrincipalDelegation` rows on the shared
/// `tom_principal_delegation` table (see `share_delegation_store.dart`), so the
/// resource-role resolver enforces ownership and shares through one framework
/// path.
///
/// These are the server-side counterparts of the observable domain entities:
/// `advanced_todo_domain` carries the form-bindable `TomClass` entities
/// ([Workspace], [Project], [TodoList], [TodoItem], [TodoComment], [Subtask])
/// whose fields are `TomString` / `TomBool` / `TomList` value holders
/// and whose ids are display strings, while the object-persistence layer needs
/// the opposite shape — plain typed fields, an integer surrogate primary key,
/// explicit integer foreign-key columns, and no nested collections. The pure
/// conversions between the two worlds live in `app_mapping.dart`.
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
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// The `app_db` datasource name every record below binds to.
///
/// The app-server boot registers this connection; the reused
/// framework `TomResourceGrant` (the field-grade matrix the auth server seeds)
/// is read through the framework default `main` datasource, which the boot
/// points at the same physical schema.
const String appDatasource = 'app_db';

/// The `app_items` table name — the shared contract's [AppFileSlots.itemsTable].
///
/// Read from the contracts package rather than restated, because two
/// independent things must agree on it: [ItemRecord]'s own `@TomDbTable`, and
/// the file **slot** address `app_items/<id>/attachment` the framework file
/// endpoint publishes and the clients call. With the clients reading the same
/// constant there is no second spelling to drift — a mismatch here would
/// otherwise only show up as a 404.
const String appItemsTable = AppFileSlots.itemsTable;

/// The exposed file column of [ItemRecord], for the same reason as
/// [appItemsTable]: the annotation and the slot address share one spelling.
const String itemAttachmentColumn = AppFileSlots.itemAttachmentColumn;

/// The async `@TomDbScope` kind that scopes [ProjectRecord] reads to the
/// caller's visible projects. Registered at boot via
/// `registerAppDataScopes` to `VisibleResourceResolver`, which resolves the
/// owned ∪ shared project id-sets and pushes them to the database as
/// `(id IN (owned…) OR id IN (shared…))`.
const String projectVisibilityScope = 'visible:project';

/// The async `@TomDbScope` kind that scopes [ListRecord] reads to the caller's
/// visible lists. See [projectVisibilityScope].
const String listVisibilityScope = 'visible:list';

/// The async `@TomDbScope` kind that scopes [ItemRecord] reads to the caller's
/// visible items. See [projectVisibilityScope].
const String itemVisibilityScope = 'visible:item';

/// A workspace row in `app_workspaces` — the root of the ownership chain
/// `Workspace → Project → TodoList → TodoItem` the access resolver walks.
///
/// **C-3 row scope.** The workspace is the one entity whose read
/// visibility is *owner-only*: a workspace is reachable iff the caller owns it
/// (shares never target a workspace and never flow upward — see
/// `AppReadService`). That makes it faithfully expressible as the framework's
/// *synchronous* single-column `@TomDbScope` on `ownerId`, so every repository
/// read is owner-scoped at the database (`WHERE owner_id = <principal.id>`)
/// independently of any service-layer filter.
///
/// The project/list/item records fold ownership *and* `share`-mode delegations
/// over the containment chain, so a single-column *AND* scope cannot express
/// them (it would silently AND-hide legitimately shared rows). The framework
/// data scope therefore also accepts an **async, union/OR** resolver, and these
/// three records carry an `@TomDbScope` on their surrogate `id` bound to that
/// resolver ([projectVisibilityScope] / [listVisibilityScope] /
/// [itemVisibilityScope]): the repository pushes the caller's owned ∪ shared
/// id-set to the database as `(id IN (owned…) OR id IN (shared…))`, so the full
/// C-5/C-6 visibility is enforced at the database rather than by a service-layer
/// `ResourceRoleResolver` pass, which the async scope makes unnecessary.
@tomReflector
@TomDbTable(
  datasource: appDatasource,
  table: 'app_workspaces',
  primaryKeyFields: ['id'],
)
@TomDbScope(field: 'ownerId')
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
///
/// Read-scoped by the async [projectVisibilityScope] on its surrogate `id`
///: the repository restricts reads to the caller's owned ∪ shared
/// projects. The scope is on `id` (not a principal column) because a project's
/// visibility is not a single-column fact — it is the union of ownership and
/// share delegations folded over the containment chain, computed by
/// `VisibleResourceResolver`.
@tomReflector
@TomDbTable(
  datasource: appDatasource,
  table: 'app_projects',
  primaryKeyFields: ['id'],
)
@TomDbScope(field: 'id', scope: projectVisibilityScope)
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
class ProjectRepository
    extends TomSqlDatasourceRepository<ProjectRecord, int> {}

/// Process-wide singleton repository instance.
final projectRepository = ProjectRepository();

/// A list (board column) row in `app_lists`; groups [ItemRecord]s.
///
/// Read-scoped by the async [listVisibilityScope] on its surrogate `id`;
/// see [ProjectRecord] for why the scope is on `id`.
@tomReflector
@TomDbTable(
  datasource: appDatasource,
  table: 'app_lists',
  primaryKeyFields: ['id'],
)
@TomDbScope(field: 'id', scope: listVisibilityScope)
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
/// text column rather than a child table — the mapping layer owns the
/// join/split codec, keeping this row flat like every other record.
///
/// Read-scoped by the async [itemVisibilityScope] on its surrogate `id`;
/// see [ProjectRecord] for why the scope is on `id`.
@tomReflector
@TomDbTable(
  datasource: appDatasource,
  table: appItemsTable,
  primaryKeyFields: ['id'],
)
@TomDbScope(field: 'id', scope: itemVisibilityScope)
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

  /// Blob key of the item's user-facing attachment — **exposed**, so the
  /// framework file endpoint serves it as the slot `app_items/<id>/attachment`.
  ///
  /// `cascadeDelete: true` (the default, spelled out here for the contrast with
  /// `UserRecord.avatarRef`, which is `false`): the blob belongs to this row and
  /// nothing else points at it, so deleting the item must not leave the bytes
  /// behind. Compare an avatar, which the application may reuse across rows and
  /// therefore manages itself.
  ///
  /// **`authKey` is what makes the transfer authorized rather than merely
  /// authenticated.** `exposed: true` decides that a slot *names* this column;
  /// it says nothing about who may have it. The C-4 grade does: the app-server
  /// boot registers a per-row resolver for [itemAttachmentGradeKey]
  /// (`registerAppColumnGrades`), so `openFile`/`saveFile`/`describeFile` resolve
  /// the caller's role on *this item's* project and grade the column from the
  /// seeded grant matrix — `full` downloads and replaces, `read` downloads and
  /// is refused the upload.
  @TomDbColumn(
    columnName: itemAttachmentColumn,
    authKey: itemAttachmentGradeKey,
  )
  @TomFileReference(
    keyPrefix: 'items/attachment',
    exposed: true,
    cascadeDelete: true,
  )
  String? attachment;

  /// Blob key of an internal, staff-only note document — deliberately **not**
  /// exposed (`exposed` defaults to `false`).
  ///
  /// The bytes are stored, streamed and cascade-deleted exactly like
  /// [attachment]; the only difference is that no HTTP slot is published, so a
  /// request for `app_items/<id>/internal_note` is a 404 however privileged the
  /// caller is. That is the framework's default-closed rule: reaching a file
  /// over HTTP is opted into per column, never inherited from the row.
  @TomDbColumn(columnName: 'internal_note')
  @TomFileReference(keyPrefix: 'items/internal_note')
  String? internalNote;

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
@TomDbTable(
  datasource: appDatasource,
  table: 'app_comments',
  primaryKeyFields: ['id'],
)
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
class CommentRepository
    extends TomSqlDatasourceRepository<CommentRecord, int> {}

/// Process-wide singleton repository instance.
final commentRepository = CommentRepository();

/// A subtask row in `app_subtasks` — a checklist row on an [ItemRecord].
@tomReflector
@TomDbTable(
  datasource: appDatasource,
  table: 'app_subtasks',
  primaryKeyFields: ['id'],
)
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
class SubtaskRepository
    extends TomSqlDatasourceRepository<SubtaskRecord, int> {}

/// Process-wide singleton repository instance.
final subtaskRepository = SubtaskRepository();
