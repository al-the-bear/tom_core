/// The app server's HTTP surface — the todo board's read/write/share endpoints
/// (the registry's `app` API).
///
/// The same three-collaborator split the auth server uses (the step-10
/// `AuthUserStore`, the step-11 `AuthTokenService`, the step-12 `AdminService`):
///
/// - [AppReadStore] is the listing seam the read operations enumerate through.
///   [RepositoryAppReadStore] is the live query-backed store over the step-14
///   `app_db` repository singletons; [InMemoryAppReadStore] is a seeded,
///   database-free store for tests.
/// - [AppReadService] is the pure read logic over an [AppReadStore]: it filters
///   every listed row through the step-17 [ResourceRoleResolver]
///   (ownership-or-share → effective [ProjectRole], `null` = invisible) and
///   projects an item's per-field grades through the step-18 [FieldGradeResolver].
///   It has no server/zone dependency (only the resolvers' own seams), so the
///   visibility filter and the field-state matrix are unit-tested directly
///   against seeded stores — no server, no MariaDB.
/// - [AppWriteStore] / [AppWriteService] are the write counterpart (step 20):
///   the service gates each mutation by the principal's resolved [ProjectRole]
///   (role minimums for create/delete/comment) and, for item writes, enforces
///   the four-state field grade — a change to any field the caller is not `full`
///   on rejects the write, and the persisted row overlays only permitted fields.
/// - [AppShareService] is the cross-user sharing counterpart (step 21, RCC3):
///   only an `owner` of the target resource may create a `share`-mode
///   `TomPrincipalDelegation` (which immediately grants the grantee access, since
///   the resource-role resolver folds delegations into the effective roles) or
///   revoke one.
/// - [AdvancedAppApiService] is the thin `@tomComponent` adapter the endpoint
///   pipeline routes to. It binds each [AppApiService] method to its registry
///   endpoint (`tomRemoteApis['app'][...]`), sources the caller's principal from
///   the bearer token, and delegates reads to [AppReadService], writes to
///   [AppWriteService], and shares to [AppShareService].
///
/// This file delivers steps 19 (reads), 20 (writes), and 21 (shares). The
/// component is exercised end-to-end at boot (step 21), where its reflection is
/// generated from the `bin/app_server_start.dart` import graph; the step-19/20/21
/// "Done" bars are the database-free [AppReadService]/[AppWriteService]/
/// [AppShareService] integration tests (a shared user sees the owner's project; a
/// `viewer` write to a read-only field is rejected while an `editor` write
/// persists only the permitted fields; a created share grants the grantee
/// access). [appForbiddenOrNotFound] is the server-level handler the boot installs
/// to map the services' closed/safe denial keys to HTTP 403/404.
library;

import 'dart:convert';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../access/field_grade_resolver.dart';
import '../access/ownership_grant_writer.dart';
import '../access/resource_role_resolver.dart';
import '../access/share_delegation_store.dart';
import '../persistence/app_mapping.dart';
import '../persistence/app_persistence_model.dart';
import '../resources/app_resource_bundles.dart';

/// The listing seam the read operations enumerate candidate rows through.
///
/// The read service needs only to list the children of a parent (and every
/// workspace); the per-row visibility decision is the [ResourceRoleResolver]'s
/// job. Putting the listing behind a small interface lets the service run against
/// the live repositories at boot and a seeded in-memory store under test, with
/// identical filtering on both.
abstract class AppReadStore {
  /// Every workspace row (the read service filters them to the visible set).
  Future<List<WorkspaceRecord>> allWorkspaces();

  /// The project rows whose `workspace_id` is [workspaceId], in storage order.
  Future<List<ProjectRecord>> projectsInWorkspace(int workspaceId);

  /// The list rows whose `project_id` is [projectId], in storage order.
  Future<List<ListRecord>> listsInProject(int projectId);

  /// The item rows whose `list_id` is [listId], in storage order.
  Future<List<ItemRecord>> itemsInList(int listId);
}

/// The query-backed [AppReadStore] wired at boot.
///
/// Reads through the process-wide singleton repositories. Requires a live
/// `app_db` connection and the reflection runtime, so it is exercised
/// end-to-end (the unit tests use [InMemoryAppReadStore]).
class RepositoryAppReadStore implements AppReadStore {
  /// Creates the repository-backed store (stateless; reads the singletons).
  const RepositoryAppReadStore();

  @override
  Future<List<WorkspaceRecord>> allWorkspaces() => workspaceRepository.findAll();

  @override
  Future<List<ProjectRecord>> projectsInWorkspace(int workspaceId) async {
    final matches = await projectRepository.findByQuerySentence(
      'FIND BY workspace_id = :workspaceId',
      {'workspaceId': workspaceId},
    );
    return matches.toList();
  }

  @override
  Future<List<ListRecord>> listsInProject(int projectId) async {
    final matches = await listRepository.findByQuerySentence(
      'FIND BY project_id = :projectId',
      {'projectId': projectId},
    );
    return matches.toList();
  }

  @override
  Future<List<ItemRecord>> itemsInList(int listId) async {
    final matches = await itemRepository.findByQuerySentence(
      'FIND BY list_id = :listId',
      {'listId': listId},
    );
    return matches.toList();
  }
}

/// A seeded, database-free [AppReadStore] for tests (and local scaffolding).
///
/// Holds the rows directly and filters by foreign key, so a test can assert the
/// owner/shared/stranger visibility set without a connection or reflection.
class InMemoryAppReadStore implements AppReadStore {
  final List<WorkspaceRecord> _workspaces;
  final List<ProjectRecord> _projects;
  final List<ListRecord> _lists;
  final List<ItemRecord> _items;

  /// Seeds the store from the given record lists (each defaults to empty).
  InMemoryAppReadStore({
    List<WorkspaceRecord> workspaces = const [],
    List<ProjectRecord> projects = const [],
    List<ListRecord> lists = const [],
    List<ItemRecord> items = const [],
  })  : _workspaces = workspaces,
        _projects = projects,
        _lists = lists,
        _items = items;

  @override
  Future<List<WorkspaceRecord>> allWorkspaces() async => List.of(_workspaces);

  @override
  Future<List<ProjectRecord>> projectsInWorkspace(int workspaceId) async =>
      [for (final p in _projects) if (p.workspaceId == workspaceId) p];

  @override
  Future<List<ListRecord>> listsInProject(int projectId) async =>
      [for (final l in _lists) if (l.projectId == projectId) l];

  @override
  Future<List<ItemRecord>> itemsInList(int listId) async =>
      [for (final i in _items) if (i.listId == listId) i];
}

/// Pure read logic over an [AppReadStore], filtered by the principal's access.
///
/// Every list endpoint enumerates the candidate rows and keeps only those the
/// principal can reach — the step-17 [ResourceRoleResolver] computes the
/// effective [ProjectRole] (ownership-or-share) and `null` means invisible. The
/// field-state endpoint resolves the principal's role on an item and projects
/// the step-18 [FieldGradeResolver]'s per-field grades into [GradedFieldDto]s.
class AppReadService {
  /// The listing seam candidate rows are enumerated through.
  final AppReadStore store;

  /// Resolves a principal's effective [ProjectRole] on a resource (step 17).
  final ResourceRoleResolver accessResolver;

  /// Resolves a [ProjectRole]'s per-field grades (step 18).
  final FieldGradeResolver gradeResolver;

  /// Builds the service over its three collaborators (live stores at boot,
  /// seeded stores under test).
  const AppReadService(this.store, this.accessResolver, this.gradeResolver);

  /// The production wiring: every collaborator over its repository-backed store.
  factory AppReadService.production() => AppReadService(
        const RepositoryAppReadStore(),
        ResourceRoleResolver.production(),
        FieldGradeResolver(const RepositoryGrantStore()),
      );

  /// Workspaces the principal [userId] owns or is shared into.
  Future<List<Workspace>> listWorkspaces(int userId) => _filterVisible(
        userId,
        AppResourceTypes.workspace,
        store.allWorkspaces,
        (r) => r.id,
        workspaceFromRecord,
      );

  /// Visible projects in the workspace [workspaceId] for the principal [userId].
  Future<List<Project>> listProjects(int userId, int workspaceId) =>
      _filterVisible(
        userId,
        AppResourceTypes.project,
        () => store.projectsInWorkspace(workspaceId),
        (r) => r.id,
        projectFromRecord,
      );

  /// Visible lists in the project [projectId] for the principal [userId].
  Future<List<TodoList>> listLists(int userId, int projectId) => _filterVisible(
        userId,
        AppResourceTypes.list,
        () => store.listsInProject(projectId),
        (r) => r.id,
        listFromRecord,
      );

  /// Visible items in the list [listId] for the principal [userId].
  Future<List<TodoItem>> listItems(int userId, int listId) => _filterVisible(
        userId,
        AppResourceTypes.item,
        () => store.itemsInList(listId),
        (r) => r.id,
        itemFromRecord,
      );

  /// The principal [userId]'s per-field grade matrix for the item [itemId], one
  /// [GradedFieldDto] per gradable field in display order.
  ///
  /// Throws [TomEndpointHandlerException] when the principal has no access to the
  /// item (closed/safe — the item is treated as not found rather than leaking a
  /// grade matrix for a resource the caller cannot reach).
  Future<List<GradedFieldDto>> itemFieldStates(int userId, int itemId) async {
    final role = await accessResolver.resolveRole(
      userId: userId,
      resourceType: AppResourceTypes.item,
      resourceId: itemId,
    );
    if (role == null) {
      throw TomEndpointHandlerException(
        'app.item.not_found',
        'No accessible item with id $itemId',
      );
    }
    final states = await gradeResolver.resolveItemFieldStates(role);
    return [
      for (final entry in states.entries)
        GradedFieldDto(resourceKey: entry.key, access: entry.value),
    ];
  }

  /// Loads the candidate rows, keeps those the principal can reach (resolved
  /// [ProjectRole] is non-`null`), and projects each survivor into its domain
  /// entity. The single filtering path every list endpoint shares.
  Future<List<R>> _filterVisible<T, R>(
    int userId,
    String resourceType,
    Future<List<T>> Function() loadCandidates,
    int? Function(T) idOf,
    R Function(T) project,
  ) async {
    final visible = <R>[];
    for (final record in await loadCandidates()) {
      final id = idOf(record);
      if (id == null) continue;
      final role = await accessResolver.resolveRole(
        userId: userId,
        resourceType: resourceType,
        resourceId: id,
      );
      if (role != null) visible.add(project(record));
    }
    return visible;
  }
}

/// The write-side persistence seam the [AppWriteService] mutates through.
///
/// Mirrors the [AppReadStore]/[ResourceContainmentStore] split: the write service needs
/// to load a single item (to diff a `PUT` against the stored row), insert/update
/// items, projects and comments, and delete an item. [RepositoryAppWriteStore]
/// is the live store over the step-14 repository singletons; [InMemoryAppWriteStore]
/// is a seeded, database-free store the field-grade enforcement tests drive.
abstract class AppWriteStore {
  /// Returns the item row for [id], or `null` when it does not exist.
  Future<ItemRecord?> findItem(int id);

  /// Inserts (when `id` is `null`) or updates [record], returning the saved row
  /// (an insert carries the assigned surrogate key).
  Future<ItemRecord> saveItem(ItemRecord record);

  /// Deletes the item row with [id].
  Future<void> deleteItem(int id);

  /// Inserts or updates [record], returning the saved project row.
  Future<ProjectRecord> saveProject(ProjectRecord record);

  /// Inserts or updates [record], returning the saved comment row.
  Future<CommentRecord> saveComment(CommentRecord record);
}

/// The query-backed [AppWriteStore] wired at boot.
///
/// Writes through the process-wide singleton repositories. Requires a live
/// `app_db` connection and the reflection runtime, so it is exercised end-to-end
/// (the unit tests use [InMemoryAppWriteStore]).
class RepositoryAppWriteStore implements AppWriteStore {
  /// Creates the repository-backed store (stateless; reads the singletons).
  const RepositoryAppWriteStore();

  @override
  Future<ItemRecord?> findItem(int id) => itemRepository.findById(id);

  @override
  Future<ItemRecord> saveItem(ItemRecord record) => itemRepository.save(record);

  @override
  Future<void> deleteItem(int id) => itemRepository.deleteById(id);

  @override
  Future<ProjectRecord> saveProject(ProjectRecord record) =>
      projectRepository.save(record);

  @override
  Future<CommentRecord> saveComment(CommentRecord record) =>
      commentRepository.save(record);
}

/// A seeded, database-free [AppWriteStore] for tests (and local scaffolding).
///
/// Holds the rows directly and assigns surrogate keys on insert, mirroring the
/// auth server's `InMemoryAdminStore`. A test can seed an item, drive a write
/// through [AppWriteService], and assert the persisted row reflects only the
/// permitted fields — no connection or reflection.
class InMemoryAppWriteStore implements AppWriteStore {
  final List<ItemRecord> _items;
  final List<ProjectRecord> _projects;
  final List<CommentRecord> _comments;

  int _nextItemId = 1;
  int _nextProjectId = 1;
  int _nextCommentId = 1;

  /// Seeds the store with the given rows (each list defaults to empty); the
  /// auto-increment counters advance past any seeded ids.
  InMemoryAppWriteStore({
    List<ItemRecord> items = const [],
    List<ProjectRecord> projects = const [],
    List<CommentRecord> comments = const [],
  })  : _items = [...items],
        _projects = [...projects],
        _comments = [...comments] {
    _nextItemId = _maxId(_items.map((i) => i.id)) + 1;
    _nextProjectId = _maxId(_projects.map((p) => p.id)) + 1;
    _nextCommentId = _maxId(_comments.map((c) => c.id)) + 1;
  }

  static int _maxId(Iterable<int?> ids) =>
      ids.fold<int>(0, (max, id) => (id != null && id > max) ? id : max);

  /// The persisted item rows (test introspection).
  List<ItemRecord> get items => List.unmodifiable(_items);

  /// The persisted project rows (test introspection).
  List<ProjectRecord> get projects => List.unmodifiable(_projects);

  /// The persisted comment rows (test introspection).
  List<CommentRecord> get comments => List.unmodifiable(_comments);

  @override
  Future<ItemRecord?> findItem(int id) async {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<ItemRecord> saveItem(ItemRecord record) async {
    if (record.id == null) {
      record.id = _nextItemId++;
      _items.add(record);
    } else {
      _replaceById(_items, record, (i) => i.id == record.id);
    }
    return record;
  }

  @override
  Future<void> deleteItem(int id) async => _items.removeWhere((i) => i.id == id);

  @override
  Future<ProjectRecord> saveProject(ProjectRecord record) async {
    if (record.id == null) {
      record.id = _nextProjectId++;
      _projects.add(record);
    } else {
      _replaceById(_projects, record, (p) => p.id == record.id);
    }
    return record;
  }

  @override
  Future<CommentRecord> saveComment(CommentRecord record) async {
    if (record.id == null) {
      record.id = _nextCommentId++;
      _comments.add(record);
    } else {
      _replaceById(_comments, record, (c) => c.id == record.id);
    }
    return record;
  }

  static void _replaceById<T>(
    List<T> rows,
    T record,
    bool Function(T) matches,
  ) {
    final index = rows.indexWhere(matches);
    if (index >= 0) {
      rows[index] = record;
    } else {
      rows.add(record);
    }
  }
}

/// How one gradable [ItemRecord] column is read and copied. Backs both halves of
/// the write check — detecting that the caller changed a field (so its grade
/// must be `full`) and overlaying the permitted fields onto the persisted row.
/// Inherently code (per-column closures), keyed by the field's `todo.item.*` key
/// so the graded *set and order* come from the server resource bundle rather
/// than a second hand-maintained list.
class _GradableItemBinding {
  /// Reads the field's value from a record (for the changed/unchanged diff).
  final Object? Function(ItemRecord) read;

  /// Copies the field's value from [source] onto [target] (the permitted merge).
  final void Function(ItemRecord target, ItemRecord source) copy;

  const _GradableItemBinding(this.read, this.copy);
}

/// One gradable [ItemRecord] field: its resource key plus its read/copy binding.
class _GradableItemField {
  /// The `todo.item.*` resource key the four-state grade is declared against.
  final String resourceKey;

  /// Reads the field's value from a record (for the changed/unchanged diff).
  final Object? Function(ItemRecord) read;

  /// Copies the field's value from [source] onto [target] (the permitted merge).
  final void Function(ItemRecord target, ItemRecord source) copy;

  const _GradableItemField(this.resourceKey, this.read, this.copy);
}

/// The read/copy binding for every gradable `todo.item.*` field, keyed by its
/// full resource key. Only the closures live here; the *set and order* of graded
/// fields is the server resource bundle's [AppResourceBundles.gradableItemKeys]
/// (step 21), so a bundle key without a binding fails loudly when
/// [_gradableItemFields] is built. The non-gradable columns (`label`, `tags`)
/// are absent by design — `updateItem` preserves them from the stored row,
/// `createItem` takes them from the creator's payload.
final Map<String, _GradableItemBinding> _gradableItemBindings = {
  'todo.item.title':
      _GradableItemBinding((r) => r.title, (t, s) => t.title = s.title),
  'todo.item.status':
      _GradableItemBinding((r) => r.status, (t, s) => t.status = s.status),
  'todo.item.priority':
      _GradableItemBinding((r) => r.priority, (t, s) => t.priority = s.priority),
  'todo.item.assigneeId': _GradableItemBinding(
      (r) => r.assigneeId, (t, s) => t.assigneeId = s.assigneeId),
  'todo.item.dueDate':
      _GradableItemBinding((r) => r.dueDate, (t, s) => t.dueDate = s.dueDate),
  'todo.item.estimate': _GradableItemBinding(
      (r) => r.estimateHours, (t, s) => t.estimateHours = s.estimateHours),
  'todo.item.description': _GradableItemBinding(
      (r) => r.description, (t, s) => t.description = s.description),
};

/// The field-graded [ItemRecord] columns, in the display order the server
/// resource bundle labels them — the same set the field-grade resolver answers
/// and the matrix the auth server seeds (step 21). The order and membership come
/// from [AppResourceBundles.gradableItemKeys]; [_gradableItemBindings] supplies
/// each key's read/copy closures. A gradable key with no binding throws here.
final List<_GradableItemField> _gradableItemFields = [
  for (final key in AppResourceBundles.gradableItemKeys())
    _GradableItemField(
        key, _gradableItemBindings[key]!.read, _gradableItemBindings[key]!.copy),
];

/// The gradable `todo.item.*` field keys the write path enforces, in order —
/// exposed so a drift guard can assert it against the server resource bundle.
List<String> get gradableItemFieldKeys =>
    [for (final field in _gradableItemFields) field.resourceKey];

/// Pure write logic over an [AppWriteStore], gated by the same two authorization
/// layers the reads use.
///
/// Every mutation first resolves the principal's effective [ProjectRole] on the
/// target through the step-17 [ResourceRoleResolver] (no access → the resource
/// is treated as not-found, closed/safe). It then enforces the §A.4 policy:
///
/// - **Role gating.** Structural mutations check a minimum role —
///   `createProject`/`createItem` require `editor` or above on the parent,
///   `deleteItem` requires `editor` or above on the item, `addComment` requires
///   `commenter` or above.
/// - **Field-grade enforcement.** For item writes every gradable field the
///   caller *changes* must be graded [TomAuthState.full] for their role (the
///   step-18 [FieldGradeResolver]); the first violation rejects the whole write.
///   The persisted row overlays only the `full`-graded fields, so server-owned
///   columns (`id`, `listId`, `reporterId`, `createdAt`) and non-`full` fields
///   always keep their stored value — the persisted row reflects only permitted
///   fields.
///
/// Like [AppReadService] it has no server/zone dependency (only the store and the
/// two resolvers' seams), so the whole write path unit-tests against seeded
/// stores — the step-20 "Done" bar with no MariaDB.
class AppWriteService {
  /// The persistence seam mutations are applied through.
  final AppWriteStore store;

  /// Resolves a principal's effective [ProjectRole] on a resource (step 17).
  final ResourceRoleResolver accessResolver;

  /// Resolves a [ProjectRole]'s per-field grades (step 18).
  final FieldGradeResolver gradeResolver;

  /// Records the creator's C-5 ownership grant when a resource is created (RCC1).
  final OwnershipGrantWriter ownershipWriter;

  /// Builds the service over its four collaborators (live stores at boot,
  /// seeded stores under test).
  const AppWriteService(
    this.store,
    this.accessResolver,
    this.gradeResolver,
    this.ownershipWriter,
  );

  /// The production wiring: every collaborator over its repository-backed store.
  factory AppWriteService.production() => AppWriteService(
        const RepositoryAppWriteStore(),
        ResourceRoleResolver.production(),
        FieldGradeResolver(const RepositoryGrantStore()),
        const RepositoryOwnershipGrantWriter(),
      );

  /// Creates [project] in its workspace; the principal must own or edit that
  /// workspace (project ownership flows from the owning workspace, so the creator
  /// "becomes the owner" by virtue of owning/editing it).
  Future<Project> createProject(int userId, Project project) async {
    final record = projectToRecord(project)..id = null;
    final workspaceId = record.workspaceId;
    if (workspaceId == null) {
      throw TomEndpointHandlerException(
        'app.project.invalid',
        'createProject requires a workspaceId',
      );
    }
    await _requireRole(
      userId,
      AppResourceTypes.workspace,
      workspaceId,
      ProjectRole.editor,
      'create projects in this workspace',
    );
    final saved = await store.saveProject(record);
    // RCC1: the creator becomes the project's owner — stamp the explicit C-5
    // owner grant so the login folds it into aci.resourceRoles (ownership is no
    // longer only the implicit workspace chain the bespoke resolver walks).
    await ownershipWriter.recordOwner(
      userId.toString(),
      ResourceRoleKeys.project(saved.id!),
    );
    return projectFromRecord(saved);
  }

  /// Creates [item] in its list; the principal must edit (or own) the list and
  /// be `full` on every gradable field they populate. The creator is recorded as
  /// the reporter.
  Future<TodoItem> createItem(int userId, TodoItem item) async {
    final incoming = itemToRecord(item);
    final listId = incoming.listId;
    if (listId == null) {
      throw TomEndpointHandlerException(
        'app.item.invalid',
        'createItem requires a listId',
      );
    }
    final role = await _requireRole(
      userId,
      AppResourceTypes.list,
      listId,
      ProjectRole.editor,
      'create items in this list',
    );
    final grades = await gradeResolver.resolveItemFieldStates(role);
    final now = DateTime.now();
    // A fresh, server-owned row: the creator is the reporter, and the
    // non-gradable columns flow from the payload. The gradable columns are
    // overlaid only where the creator is `full`, after the change check.
    final baseline = ItemRecord()
      ..listId = listId
      ..reporterId = userId
      ..label = incoming.label
      ..tags = incoming.tags
      ..createdAt = now
      ..updatedAt = now;
    final toPersist = _enforceFieldWrites(baseline, incoming, grades);
    final saved = await store.saveItem(toPersist);
    // RCC1: the creator (also the reporter) owns the new item — stamp the C-5
    // owner grant so ownership is an explicit, resolvable resource role.
    await ownershipWriter.recordOwner(
      userId.toString(),
      ResourceRoleKeys.item(saved.id!),
    );
    return itemFromRecord(saved);
  }

  /// Applies the caller's [item] payload to the stored item [itemId] under
  /// field-level authorization: every gradable field the payload changes must be
  /// graded `full` for the caller's role, or the whole write is rejected. The
  /// persisted row overlays only the permitted fields onto the stored row.
  Future<TodoItem> updateItem(int userId, int itemId, TodoItem item) async {
    final role = await accessResolver.resolveRole(
      userId: userId,
      resourceType: AppResourceTypes.item,
      resourceId: itemId,
    );
    if (role == null) throw _notFoundItem(itemId);
    final stored = await store.findItem(itemId);
    if (stored == null) throw _notFoundItem(itemId);
    final grades = await gradeResolver.resolveItemFieldStates(role);
    final merged = _enforceFieldWrites(stored, itemToRecord(item), grades)
      ..updatedAt = DateTime.now();
    return itemFromRecord(await store.saveItem(merged));
  }

  /// Deletes the item [itemId]; only an `owner` or `editor` may delete.
  Future<void> deleteItem(int userId, int itemId) async {
    await _requireRole(
      userId,
      AppResourceTypes.item,
      itemId,
      ProjectRole.editor,
      'delete this item',
      notFoundOnNoAccess: true,
    );
    await store.deleteItem(itemId);
  }

  /// Adds [comment] to the item [itemId]; `commenter` or above may comment. The
  /// caller is recorded as the author.
  Future<TodoComment> addComment(
    int userId,
    int itemId,
    TodoComment comment,
  ) async {
    await _requireRole(
      userId,
      AppResourceTypes.item,
      itemId,
      ProjectRole.commenter,
      'comment on this item',
      notFoundOnNoAccess: true,
    );
    final record = commentToRecord(comment)
      ..id = null
      ..itemId = itemId
      ..authorId = userId
      ..createdAt = DateTime.now();
    return commentFromRecord(await store.saveComment(record));
  }

  /// Resolves the principal's role on `(resourceType, resourceId)` and asserts it
  /// is at least [minimum]. Returns the resolved role for callers that need it.
  ///
  /// No access throws `app.access.forbidden` — or, when [notFoundOnNoAccess] is
  /// set, `app.item.not_found` (closed/safe: a resource the caller cannot reach
  /// is reported as missing rather than as forbidden, avoiding an existence
  /// leak). A role weaker than [minimum] always throws `app.access.forbidden`.
  Future<ProjectRole> _requireRole(
    int userId,
    String resourceType,
    int resourceId,
    ProjectRole minimum,
    String action, {
    bool notFoundOnNoAccess = false,
  }) async {
    final role = await accessResolver.resolveRole(
      userId: userId,
      resourceType: resourceType,
      resourceId: resourceId,
    );
    if (role == null) {
      if (notFoundOnNoAccess && resourceType == AppResourceTypes.item) {
        throw _notFoundItem(resourceId);
      }
      throw TomEndpointHandlerException(
        'app.access.forbidden',
        'You do not have access to $action.',
      );
    }
    if (!_roleAtLeast(role, minimum)) {
      throw TomEndpointHandlerException(
        'app.access.forbidden',
        'Your role (${role.name}) may not $action.',
      );
    }
    return role;
  }

  /// Validates the caller's field-level writes and builds the row to persist.
  ///
  /// [baseline] is the row the write is measured against (the stored row for an
  /// update, a fresh server-owned row for a create); [incoming] is the caller's
  /// payload as a record; [grades] is the caller's per-field grade. The check is
  /// delegated to the framework's first-class C-4 decision core
  /// [TomColumnAuthorization.decideWrites] over the [_gradableItemFields] tokens:
  /// a field the caller is not `full` on but *changed* while it is visible
  /// (`read`) throws `app.item.field_forbidden`; every non-`full` field is
  /// preserved from [baseline], and only the `full`-graded (writable) fields are
  /// overlaid from [incoming] — so non-`full` and server-owned columns keep their
  /// baseline value.
  ///
  /// The service resolves grades per **role** (via [FieldGradeResolver]), not
  /// through the process-wide `TomAuthorization` the repository's default C-4
  /// resolver consults; the pure decision core is reflection-free precisely so a
  /// DTO/closure path like this can drive it with its own resolver and its own
  /// [TomEndpointHandlerException].
  ItemRecord _enforceFieldWrites(
    ItemRecord baseline,
    ItemRecord incoming,
    Map<String, TomAuthState> grades,
  ) {
    final decision = TomColumnAuthorization.decideWrites<_GradableItemField>(
      columns: _gradableItemFields,
      gradeOf: (field) => field.resourceKey,
      changed: (field) => field.read(incoming) != field.read(baseline),
      onForbidden: (field, key, grade) => throw TomEndpointHandlerException(
        'app.item.field_forbidden',
        'Field "$key" is not writable at your access level.',
      ),
      resolver: (key) => grades[key] ?? TomAuthState.none,
    );
    final merged = _cloneItem(baseline);
    for (final field in decision.writable) {
      field.copy(merged, incoming);
    }
    return merged;
  }

  /// Whether [role] is at least as privileged as [minimum]. [ProjectRole] is
  /// declared strongest-first, so a *lower* index is the stronger role.
  static bool _roleAtLeast(ProjectRole role, ProjectRole minimum) =>
      role.index <= minimum.index;

  /// The closed/safe "no such item" rejection shared by the item write paths.
  static TomEndpointHandlerException _notFoundItem(int itemId) =>
      TomEndpointHandlerException(
        'app.item.not_found',
        'No accessible item with id $itemId',
      );

  /// A field-by-field copy of [record] (the write paths never mutate the stored
  /// row in place — a rejected write must leave storage untouched).
  static ItemRecord _cloneItem(ItemRecord record) => ItemRecord()
    ..id = record.id
    ..listId = record.listId
    ..title = record.title
    ..description = record.description
    ..status = record.status
    ..priority = record.priority
    ..label = record.label
    ..assigneeId = record.assigneeId
    ..reporterId = record.reporterId
    ..dueDate = record.dueDate
    ..estimateHours = record.estimateHours
    ..tags = record.tags
    ..createdAt = record.createdAt
    ..updatedAt = record.updatedAt;
}

/// Cross-user sharing — the `POST /share` / `DELETE /share/{id}` logic (step 21,
/// RCC3-migrated to framework delegation).
///
/// Both operations are **owner-only**: the principal must resolve to
/// [ProjectRole.owner] on the shared resource (via the step-17
/// [ResourceRoleResolver]). Creating a share writes a `share`-mode
/// [TomPrincipalDelegation] through the [ShareDelegationStore] — the framework
/// [TomDelegationResolver] the resolver reads folds it into the grantee's
/// effective roles on their next request, so the grant takes effect immediately
/// with no parallel share table. Revoking deletes the delegation row, authorized
/// against the share's own target (parsed back from the delegation's
/// `resourceKey`).
///
/// Like the read/write services it has no server/zone dependency (only the store
/// and the resolver's seam), so the share path unit-tests against seeded stores.
class AppShareService {
  /// The delegation-write seam shares are persisted and revoked through.
  final ShareDelegationStore store;

  /// Resolves a principal's effective [ProjectRole] on a resource (step 17).
  final ResourceRoleResolver accessResolver;

  /// Builds the service over its collaborators (live stores at boot, seeded
  /// stores under test).
  const AppShareService(this.store, this.accessResolver);

  /// The production wiring: every collaborator over its repository-backed store.
  factory AppShareService.production() => AppShareService(
        const RepositoryShareDelegationStore(),
        ResourceRoleResolver.production(),
      );

  /// Grants [request.granteeUserId] the [request.projectRole] on the resource
  /// `(request.resourceType, request.resourceId)` as a `share`-mode delegation.
  /// Only the resource's `owner` may share; the principal who creates the share
  /// is the delegation's delegator.
  Future<void> share(int userId, ShareRequest request) async {
    final resourceId = int.tryParse(request.resourceId);
    final granteeId = int.tryParse(request.granteeUserId);
    if (resourceId == null || granteeId == null) {
      throw TomEndpointHandlerException(
        'app.share.invalid',
        'share requires a numeric resourceId and granteeUserId',
      );
    }
    await _requireOwner(userId, request.resourceType, resourceId);
    await store.saveShare(
      TomPrincipalDelegation(
        mode: TomDelegationMode.share.name,
        delegatorId: userId.toString(),
        delegateId: granteeId.toString(),
        resourceKey:
            ResourceRoleKeys.forResource(request.resourceType, resourceId),
        role: request.projectRole,
      ),
    );
  }

  /// Revokes the share [shareId] (a `share`-mode delegation id). Only an `owner`
  /// of the share's target resource may revoke it; an unknown share, or one
  /// whose `resourceKey` cannot be parsed, is reported as not found
  /// (closed/safe).
  Future<void> revokeShare(int userId, int shareId) async {
    final delegation = await store.findDelegation(shareId);
    final target = _parseResourceKey(delegation?.resourceKey);
    if (delegation == null || target == null) {
      throw TomEndpointHandlerException(
        'app.share.not_found',
        'No share with id $shareId',
      );
    }
    await _requireOwner(userId, target.type, target.id);
    await store.deleteDelegation(shareId);
  }

  /// Asserts the principal [userId] is the `owner` of `(resourceType,
  /// resourceId)`. No access or a weaker role both throw `app.access.forbidden`
  /// (sharing is an ownership-only act, so a non-owner is simply forbidden).
  Future<void> _requireOwner(
    int userId,
    String resourceType,
    int resourceId,
  ) async {
    final role = await accessResolver.resolveRole(
      userId: userId,
      resourceType: resourceType,
      resourceId: resourceId,
    );
    if (role != ProjectRole.owner) {
      throw TomEndpointHandlerException(
        'app.access.forbidden',
        'Only the resource owner may share or revoke access.',
      );
    }
  }

  /// Parses a delegation `resourceKey` (`<type>:<id>`) into its type token and
  /// surrogate id, or `null` when it is absent or malformed.
  static ({String type, int id})? _parseResourceKey(String? resourceKey) {
    if (resourceKey == null) return null;
    final separator = resourceKey.indexOf(':');
    if (separator <= 0 || separator == resourceKey.length - 1) return null;
    final id = int.tryParse(resourceKey.substring(separator + 1));
    if (id == null) return null;
    return (type: resourceKey.substring(0, separator), id: id);
  }
}

/// The message key the endpoint pipeline throws when an access check (e.g. the
/// contract-declared `TomAuthenticatedAccess` on a missing token) fails *before*
/// the method runs.
///
/// Coupled to `TomEndpointHandler`'s access-denied throw in `tom_core_server`,
/// it surfaces *outside* the per-endpoint try/catch, so only a server-level
/// handler ([appForbiddenOrNotFound]) can map it.
const String appEndpointAccessDeniedKey =
    'endpoint_handler.handle_method_call.access_denied';

/// Server-level error handler mapping the app services' closed/safe denial keys
/// to HTTP statuses; returns `null` for everything else so genuine faults fall
/// through to the framework's default JSON 500.
///
/// The services throw stable [TomEndpointHandlerException] keys rather than shelf
/// responses (so they stay server-free and unit-testable). The boot composes this
/// over [TomDefaultErrorHandler] to turn those keys into the HTTP contract §A.6
/// promises:
///
/// - `app.item.not_found` / `app.share.not_found` → **404** (a resource the
///   caller cannot reach is reported missing, never leaking its existence).
/// - `app.access.forbidden` / `app.item.field_forbidden` (and the pipeline's
///   pre-invocation [appEndpointAccessDeniedKey]) → **403**.
Response? appForbiddenOrNotFound(
  Request request,
  Object error,
  StackTrace stack,
) {
  if (error is! TomException) return null;
  switch (error.key) {
    case 'app.item.not_found':
    case 'app.share.not_found':
      return Response.notFound(
        jsonEncode({'error': error.key}),
        headers: {TomHeader.contentType: TomMimeType.json.toHeaderValue()},
      );
    case 'app.access.forbidden':
    case 'app.item.field_forbidden':
    case appEndpointAccessDeniedKey:
      return Response.forbidden(
        jsonEncode({'error': error.key}),
        headers: {TomHeader.contentType: TomMimeType.json.toHeaderValue()},
      );
    default:
      return null;
  }
}

/// The `@tomComponent` implementing the registry's `app` API.
///
/// Bound to the `appApi` endpoints (`tomRemoteApis['app']`); the bean container
/// instantiates it through the no-argument constructor, which wires the
/// production [AppReadService]. The per-endpoint access policy is **declared on
/// the contract** (each `appApi` endpoint's `TomApiEndpoint.access`, G-API-3)
/// and extracted by the pipeline on first call, so these handlers carry no
/// inline access annotation: `appHealth` is public, every other endpoint
/// requires an authenticated principal, which the pipeline reads from the bearer
/// token; the resource- and field-level checks then run inside the handlers.
///
/// The read endpoints delegate to [AppReadService], the write endpoints
/// (`createProject`/`createItem`/`updateItem`/`deleteItem`/`addComment`) to
/// [AppWriteService] (role gating + field-grade enforcement), and the share
/// endpoints (`share`/`revokeShare`) to [AppShareService] (owner-only).
@tomReflector
@tomComponent
@TomApiImplementation(apiId: 'app')
class AdvancedAppApiService implements AppApiService {
  /// Production read logic over the repository-backed stores.
  ///
  /// Wired lazily: constructing the repository-backed resolvers analyses their
  /// framework-reflected persistence types, which is only valid once the boot
  /// has run `initializeReflection()`. Deferring to first use keeps the pure
  /// [resources]/[health] endpoints reflection-free and matches production,
  /// where the first request always follows boot-time reflection.
  late final AppReadService _reads = AppReadService.production();

  /// Production write logic (role gating + field-grade enforcement) over the
  /// repository-backed stores (lazily wired; see [_reads]).
  late final AppWriteService _writes = AppWriteService.production();

  /// Production share logic (owner-only) over the repository-backed stores
  /// (lazily wired; see [_reads]).
  late final AppShareService _shares = AppShareService.production();

  /// The authenticated caller's auth-user id (the surrogate key the `app_db`
  /// rows reference cross-database). Resolved from the per-request principal the
  /// server's authentication middleware places in the Dart zone
  /// ([getFromCurrentZone]) — NOT from [TomBearerAuthentication], whose static
  /// singleton is a client-side token store that the server middleware never
  /// populates (and which is not request-scoped, so it is unsafe on a server
  /// handling concurrent requests).
  int get _principalId =>
      int.tryParse('${getFromCurrentZone<TomPrincipal>()?.user.id}') ?? -1;

  // Mounted at `GET /status` (see the `appHealth` registry entry): the
  // framework's TomHealthService already owns the plain-text `GET /health`
  // liveness probe in every server, so the app's typed JSON status uses a
  // distinct path to avoid being shadowed by it.
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appHealth')
  @override
  Future<Map<String, Object>> health() async =>
      {'status': 'ok', 'service': 'advanced_app_server'};

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appListWorkspaces')
  @override
  Future<List<Workspace>> listWorkspaces() =>
      _reads.listWorkspaces(_principalId);

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appListProjects')
  @override
  Future<List<Project>> listProjects(String workspaceId) =>
      _reads.listProjects(_principalId, int.tryParse(workspaceId) ?? -1);

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appListLists')
  @override
  Future<List<TodoList>> listLists(String projectId) =>
      _reads.listLists(_principalId, int.tryParse(projectId) ?? -1);

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appListItems')
  @override
  Future<List<TodoItem>> listItems(String listId) =>
      _reads.listItems(_principalId, int.tryParse(listId) ?? -1);

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appItemFieldStates')
  @override
  Future<List<GradedFieldDto>> itemFieldStates(EntityIdRequest request) =>
      _reads.itemFieldStates(_principalId, int.tryParse(request.id) ?? -1);

  // ----- Write endpoints (step 20) -----------------------------------------

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appCreateProject')
  @override
  Future<Project> createProject(Project project) =>
      _writes.createProject(_principalId, project);

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appCreateItem')
  @override
  Future<TodoItem> createItem(TodoItem item) =>
      _writes.createItem(_principalId, item);

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appUpdateItem')
  @override
  Future<TodoItem> updateItem(TodoItem item) => _writes.updateItem(
      _principalId, int.tryParse(item.id.get()) ?? -1, item);

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appDeleteItem')
  @override
  Future<void> deleteItem(EntityIdRequest request) =>
      _writes.deleteItem(_principalId, int.tryParse(request.id) ?? -1);

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appAddComment')
  @override
  Future<TodoComment> addComment(TodoComment comment) => _writes.addComment(
      _principalId, int.tryParse(comment.itemId.get()) ?? -1, comment);

  // ----- Share endpoints (step 21) -----------------------------------------

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appShare')
  @override
  Future<void> share(ShareRequest request) =>
      _shares.share(_principalId, request);

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appRevokeShare')
  @override
  Future<void> revokeShare(String id) =>
      _shares.revokeShare(_principalId, int.tryParse(id) ?? -1);

  // `resources` (`appResources`, authenticated `GET /resources`) serves the app
  // client's full text bundle (board + item-form labels), installed after
  // sign-in. Any authenticated principal may read it — the texts are display
  // strings, not data (D-A10).
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appResources')
  @override
  Future<ResourceBundleDto> resources() async => AppResourceBundles.appBundle();
}
