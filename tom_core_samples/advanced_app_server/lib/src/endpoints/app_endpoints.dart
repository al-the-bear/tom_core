/// The app server's HTTP surface — the todo board's read/write/share endpoints
/// (the registry's `app` API).
///
/// The same three-collaborator split the auth server uses (`AuthUserStore`,
/// `AuthTokenService`, `AdminService`):
///
/// - [AppReadStore] is the listing seam the read operations enumerate through.
///   [RepositoryAppReadStore] is the live query-backed store over the `app_db`
///   repository singletons; [InMemoryAppReadStore] is a seeded,
///   database-free store for tests.
/// - [AppReadService] is the pure read logic over an [AppReadStore]. Every list
///   endpoint filters against the principal's visible id-set from
///   [VisibleResourceResolver] (owned ∪ shared, per entity type — the same set
///   the async `@TomDbScope` pushes to the database, so the service-layer and
///   database answers cannot diverge), and [AppReadService.resourceRoles]
///   expands the [ResourceRoleResolver]'s effective grants down each
///   containment subtree into the flat `resourceKey → roleName` map the client
///   grades its own fields from. **Reads never grade a field.** Per-field grades
///   are a write-time and file-column concern, resolved by the
///   [FieldGradeResolver] on behalf of [AppWriteService] and
///   `ItemAttachmentGradeResolver`; [AppReadService] holds no grade resolver at
///   all. It has no server/zone dependency either (only the resolvers' own
///   seams), so the visibility filter and the role-map expansion are unit-tested
///   directly against seeded stores — no server, no MariaDB.
/// - [AppWriteStore] / [AppWriteService] are the write counterpart:
///   the service gates each mutation by the principal's resolved [ProjectRole]
///   (role minimums for create/delete/comment) and, for item writes, enforces
///   the four-state field grade — a change to any field the caller is not `full`
///   on rejects the write, and the persisted row overlays only permitted fields.
/// - [AppShareService] is the cross-user sharing counterpart:
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
/// This file delivers all three surfaces — reads, writes, and shares. The
/// component is exercised end-to-end at boot, where its reflection is generated
/// from the `bin/app_server_start.dart` import graph; the behaviour itself is
/// pinned by the database-free [AppReadService]/[AppWriteService]/
/// [AppShareService] integration tests (a shared user sees the owner's project; a
/// `viewer` write to a read-only field is rejected while an `editor` write
/// persists only the permitted fields; a created share grants the grantee
/// access). [appForbiddenOrNotFound] is the server-level handler the boot installs
/// to map the services' closed/safe denial keys to HTTP 403/404.
library;

import 'dart:convert';
import 'dart:math';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../access/field_grade_resolver.dart';
import '../access/ownership_grant_writer.dart';
import '../access/resource_role_resolver.dart';
import '../access/share_delegation_store.dart';
import '../access/visible_resource_resolver.dart';
import '../persistence/app_mapping.dart';
import '../persistence/app_persistence_model.dart';
import '../resources/app_resource_bundles.dart';

/// The closed/safe "no such item" rejection, shared by every item-addressed
/// path — reads (the comment thread, the subtask checklist) and writes alike.
///
/// Top-level rather than private to one service because both services owe the
/// *same* answer: an item the principal may not reach is reported missing, not
/// forbidden, so no endpoint leaks its existence. Two separately worded
/// rejections would eventually disagree, and the difference between them is
/// precisely the leak.
TomEndpointHandlerException itemNotFound(int itemId) =>
    TomEndpointHandlerException(
      'app.item.not_found',
      'No accessible item with id $itemId',
    );

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

  /// The comment rows on item [itemId], oldest first.
  ///
  /// Ordering is part of the seam rather than left to the caller: a thread read
  /// out of order is a different thread, so both stores owe the same sequence.
  Future<List<CommentRecord>> commentsOnItem(int itemId);

  /// The subtask rows of item [itemId], in `position` order.
  Future<List<SubtaskRecord>> subtasksOfItem(int itemId);

  /// The stored-file descriptor of item [itemId]'s exposed `attachment`
  /// column, or null when the slot holds nothing.
  ///
  /// This is deliberately the *same* call a `HEAD` on the slot makes rather
  /// than a read of the row's key column: the framework applies the column
  /// grade (C-4) inside it, and a masked column describes as `null`. Looking at
  /// the key ourselves would report a file the caller may not have.
  Future<TomFileMetadata?> describeAttachment(int itemId);
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
  Future<List<WorkspaceRecord>> allWorkspaces() =>
      workspaceRepository.findAll();

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

  // The two ordered child reads. Each sort key is followed by `id`, which makes
  // the order *total*: `created_at` has second resolution and `position` is
  // caller-supplied, so either can tie, and a tie broken differently on two
  // reads is a thread that reshuffles itself. The tiebreak is free — InnoDB
  // carries the primary key in every secondary index leaf, so
  // `(item_id, created_at, id)` is served entirely by the
  // `idx_app_comments_item_created` index migration [004] adds.

  @override
  Future<List<CommentRecord>> commentsOnItem(int itemId) async {
    final matches = await commentRepository.findByQuerySentence(
      'FIND BY item_id = :itemId ORDER BY created_at id ASC',
      {'itemId': itemId},
    );
    return matches.toList();
  }

  @override
  Future<List<SubtaskRecord>> subtasksOfItem(int itemId) async {
    final matches = await subtaskRepository.findByQuerySentence(
      'FIND BY item_id = :itemId ORDER BY position id ASC',
      {'itemId': itemId},
    );
    return matches.toList();
  }

  @override
  Future<TomFileMetadata?> describeAttachment(int itemId) {
    // Resolved through the slot registry — the very object the file endpoint's
    // `HEAD` handler uses — so the batched board descriptors and a per-slot
    // `HEAD` cannot answer differently.
    final slot = TomFileSlots.resolve(appItemsTable, itemAttachmentColumn);
    if (slot == null) {
      throw StateError(
        'The $appItemsTable/$itemAttachmentColumn file slot is not '
        'registered — TomFileSlots.register(itemRepository) must run at boot '
        'before attachments can be described.',
      );
    }
    return slot.describe('$itemId');
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
  final List<CommentRecord> _comments;
  final List<SubtaskRecord> _subtasks;
  final Map<int, TomFileMetadata> _attachments;

  /// Seeds the store from the given record lists (each defaults to empty).
  ///
  /// [attachments] stands in for the blob store: item id → the descriptor a
  /// `HEAD` on that item's slot would return. An item absent from the map has
  /// no readable file, which is also how a masked column behaves live.
  InMemoryAppReadStore({
    List<WorkspaceRecord> workspaces = const [],
    List<ProjectRecord> projects = const [],
    List<ListRecord> lists = const [],
    List<ItemRecord> items = const [],
    List<CommentRecord> comments = const [],
    List<SubtaskRecord> subtasks = const [],
    Map<int, TomFileMetadata> attachments = const {},
  }) : _workspaces = workspaces,
       _projects = projects,
       _lists = lists,
       _items = items,
       _comments = comments,
       _subtasks = subtasks,
       _attachments = attachments;

  @override
  Future<List<WorkspaceRecord>> allWorkspaces() async => List.of(_workspaces);

  @override
  Future<List<ProjectRecord>> projectsInWorkspace(int workspaceId) async => [
    for (final p in _projects)
      if (p.workspaceId == workspaceId) p,
  ];

  @override
  Future<List<ListRecord>> listsInProject(int projectId) async => [
    for (final l in _lists)
      if (l.projectId == projectId) l,
  ];

  @override
  Future<List<ItemRecord>> itemsInList(int listId) async => [
    for (final i in _items)
      if (i.listId == listId) i,
  ];

  // Sorted here rather than trusting seed order, so the in-memory store owes the
  // same total ordering the repository store's `ORDER BY … id` produces. A test
  // may seed rows in any order and still assert the sequence the endpoint
  // promises. `??` guards the nullable record columns: an unset sort key sorts
  // first, which is where an incomplete row belongs in both stores.
  @override
  Future<List<CommentRecord>> commentsOnItem(int itemId) async {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return [
      for (final c in _comments)
        if (c.itemId == itemId) c,
    ]..sort((a, b) {
      final byTime = (a.createdAt ?? epoch).compareTo(b.createdAt ?? epoch);
      return byTime != 0 ? byTime : (a.id ?? 0).compareTo(b.id ?? 0);
    });
  }

  @override
  Future<List<SubtaskRecord>> subtasksOfItem(int itemId) async =>
      [
        for (final s in _subtasks)
          if (s.itemId == itemId) s,
      ]..sort((a, b) {
        final byPosition = (a.position ?? 0).compareTo(b.position ?? 0);
        return byPosition != 0 ? byPosition : (a.id ?? 0).compareTo(b.id ?? 0);
      });

  @override
  Future<TomFileMetadata?> describeAttachment(int itemId) async =>
      _attachments[itemId];
}

/// Pure read logic over an [AppReadStore], filtered by the principal's access.
///
/// The project/list/item list endpoints keep only the rows in the principal's
/// **visible id-set** — the owned ∪ shared ids the
/// [VisibleResourceResolver] computes (the same set the record's async
/// `@TomDbScope` pushes to the database). On the live store the repository read
/// is already scoped, so this membership filter is a reconciliation no-op; on
/// the database-free [InMemoryAppReadStore] (which is not DB-scoped) it is what
/// enforces visibility — the two stores agree by construction. Workspaces are
/// the exception: their visibility is *owner-only* (shares never target or
/// flow up to a workspace), so [listWorkspaces] filters by the owner column
/// directly — the same `owner_id = <principal.id>` predicate the
/// `WorkspaceRecord` synchronous `@TomDbScope` enforces at the database. The
/// [resourceRoles] endpoint expands the principal's ownership grants and share
/// delegations into a flat `<type>:<id> → role` map the client grades fields
/// against locally.
class AppReadService {
  /// The listing seam candidate rows are enumerated through.
  final AppReadStore store;

  /// Resolves a principal's effective [ProjectRole] on a resource.
  /// Still used by [resourceRoles] to expand the client's grading map; the
  /// list endpoints resolve visibility through [visibleResolver] instead.
  final ResourceRoleResolver accessResolver;

  /// Resolves a principal's visible id-set (owned ∪ shared) per entity type —
  /// the same set the async `@TomDbScope` pushes to the database. Derived
  /// from [store] and the [accessResolver]'s framework delegation resolver, so
  /// the service-layer reconciliation and the DB scope share one source of truth.
  final VisibleResourceResolver visibleResolver;

  /// Builds the service over its collaborators (live stores at boot, seeded
  /// stores under test), deriving the [visibleResolver] from them.
  AppReadService(this.store, this.accessResolver)
    : visibleResolver = VisibleResourceResolver(
        store,
        accessResolver.delegationResolver,
      );

  /// The production wiring: every collaborator over its repository-backed store.
  factory AppReadService.production() => AppReadService(
    const RepositoryAppReadStore(),
    ResourceRoleResolver.production(),
  );

  /// Workspaces the principal [userId] owns.
  ///
  /// Workspace visibility is owner-only (shares never target or flow up to a
  /// workspace), so this filters by the owner column — the identical predicate
  /// the `WorkspaceRecord` `@TomDbScope` applies at the database. The
  /// repository read is already owner-scoped by that annotation; applying the
  /// same predicate here filters the database-free [InMemoryAppReadStore] too,
  /// so both stores agree without a redundant per-row [ResourceRoleResolver]
  /// call.
  Future<List<Workspace>> listWorkspaces(int userId) async => [
    for (final record in await store.allWorkspaces())
      if (record.ownerId == userId) workspaceFromRecord(record),
  ];

  /// Visible projects in the workspace [workspaceId] for the principal [userId].
  Future<List<Project>> listProjects(int userId, int workspaceId) =>
      _filterByVisibility(
        userId,
        AppResourceTypes.project,
        () => store.projectsInWorkspace(workspaceId),
        (r) => r.id,
        projectFromRecord,
      );

  /// Visible lists in the project [projectId] for the principal [userId].
  Future<List<TodoList>> listLists(int userId, int projectId) =>
      _filterByVisibility(
        userId,
        AppResourceTypes.list,
        () => store.listsInProject(projectId),
        (r) => r.id,
        listFromRecord,
      );

  /// Visible items in the list [listId] for the principal [userId].
  Future<List<TodoItem>> listItems(int userId, int listId) =>
      _filterByVisibility(
        userId,
        AppResourceTypes.item,
        () => store.itemsInList(listId),
        (r) => r.id,
        itemFromRecord,
      );

  /// The comment thread on item [itemId] for the principal [userId], oldest
  /// first.
  ///
  /// Gated by [_requireVisibleItem]: the *item's* readability decides the whole
  /// thread (C-3), so a viewer with a share sees the history they may not add
  /// to, and a stranger gets `app.item.not_found` rather than an empty list —
  /// an empty thread and an unreachable item must not look alike.
  Future<List<TodoComment>> listComments(int userId, int itemId) async {
    await _requireVisibleItem(userId, itemId);
    return [
      for (final record in await store.commentsOnItem(itemId))
        commentFromRecord(record),
    ];
  }

  /// The subtasks of item [itemId] for the principal [userId], in `position`
  /// order. Gated exactly like [listComments].
  Future<List<Subtask>> listSubtasks(int userId, int itemId) async {
    await _requireVisibleItem(userId, itemId);
    return [
      for (final record in await store.subtasksOfItem(itemId))
        subtaskFromRecord(record),
    ];
  }

  /// Throws the closed/safe `app.item.not_found` unless [itemId] is in the
  /// principal's visible item id-set.
  ///
  /// Deliberately the *same* set [listItems] filters against rather than a
  /// per-resource [ResourceRoleResolver] call: a child collection must be
  /// reachable exactly when its parent is listed, and two independently
  /// resolved answers to "may this principal read this item?" would eventually
  /// disagree.
  Future<void> _requireVisibleItem(int userId, int itemId) async {
    final visible = await visibleResolver.visibleIds(
      AppResourceTypes.item,
      userId.toString(),
    );
    if (!visible.contains(itemId)) throw itemNotFound(itemId);
  }

  /// The attachment descriptors of the visible items in [listId] — the board's
  /// paperclip source, one entry per item that actually has a readable file.
  ///
  /// Derived from [listItems], so an item the principal cannot see contributes
  /// nothing: visibility is decided once, by the same filter the item list
  /// uses, and never re-derived here. Items whose key column is empty are
  /// skipped without asking the store (there is nothing to describe); for the
  /// rest the store performs the slot `HEAD`, and a `null` answer — an
  /// orphaned key, or a column the caller's grade masks — is likewise omitted.
  /// Absence therefore always means "no paperclip", which is the only reading
  /// a client should have to implement.
  Future<List<FileDescriptorDto>> listAttachments(
    int userId,
    int listId,
  ) async {
    final descriptors = <FileDescriptorDto>[];
    for (final item in await listItems(userId, listId)) {
      if (item.attachment.get().isEmpty) continue;
      final id = int.tryParse(item.id.get());
      if (id == null) continue;
      final metadata = await store.describeAttachment(id);
      if (metadata == null) continue;
      descriptors.add(
        FileDescriptorDto.fromMetadata(
          FileDescriptorDto.slotOf(
            appItemsTable,
            item.id.get(),
            itemAttachmentColumn,
          ),
          metadata,
        ),
      );
    }
    return descriptors;
  }

  /// The principal [userId]'s effective resource-role map: every resource they
  /// can reach keyed `<type>:<id>` (e.g. `project:1`, `item:1`) → role name.
  ///
  /// Resolves the flat effective-role map from the framework delegation resolver
  /// (ownership grants C-5 ∪ share delegations C-6), then expands each grant down
  /// its containment subtree — a role on a workspace/project/list surfaces on
  /// every resource it contains — so the client's exact-match resource-role
  /// adapter can grade any reachable resource without re-walking ancestry.
  /// When two grants cover the same resource the strongest role wins
  /// ([ProjectRole] is declared most-to-least privileged, so the lowest index is
  /// strongest). This is the read side of the resolver's containment rule: the
  /// [resolveRole] walk climbs *up* from a target; this expansion walks *down*
  /// from each grant, and the two agree on which role a principal holds where.
  Future<Map<String, String>> resourceRoles(int userId) async {
    final effective = await accessResolver.delegationResolver
        .resolveEffectiveRoles(userId.toString(), DateTime.now());
    final roles = <String, ProjectRole>{};
    void put(String type, int id, ProjectRole role) {
      final key = ResourceRoleKeys.forResource(type, id.toString());
      final existing = roles[key];
      if (existing == null || role.index < existing.index) roles[key] = role;
    }

    for (final entry in effective.entries) {
      final target = parseResourceKey(entry.key);
      if (target == null) continue;
      await _expandGrant(target.type, target.id, _parseRole(entry.value), put);
    }
    return {for (final e in roles.entries) e.key: e.value.name};
  }

  /// Emits `(type, id)`'s own key at [role] via [put], then recurses into its
  /// children — so a grant on an ancestor surfaces on every descendant. An
  /// unknown type contributes only its own key (nothing to walk beneath it).
  Future<void> _expandGrant(
    String type,
    int id,
    ProjectRole role,
    void Function(String type, int id, ProjectRole role) put,
  ) async {
    put(type, id, role);
    switch (type) {
      case AppResourceTypes.workspace:
        for (final project in await store.projectsInWorkspace(id)) {
          final projectId = project.id;
          if (projectId != null) {
            await _expandGrant(AppResourceTypes.project, projectId, role, put);
          }
        }
      case AppResourceTypes.project:
        for (final list in await store.listsInProject(id)) {
          final listId = list.id;
          if (listId != null) {
            await _expandGrant(AppResourceTypes.list, listId, role, put);
          }
        }
      case AppResourceTypes.list:
        for (final item in await store.itemsInList(id)) {
          final itemId = item.id;
          if (itemId != null) {
            await _expandGrant(AppResourceTypes.item, itemId, role, put);
          }
        }
    }
  }

  /// Parses a stored role token leniently — an unknown token degrades to
  /// [ProjectRole.viewer] (the least-privileged), mirroring the resolver's own
  /// lenient parse of delegation role tokens.
  static ProjectRole _parseRole(String token) =>
      ProjectRole.values.asNameMap()[token] ?? ProjectRole.viewer;

  /// Loads the candidate rows and keeps those whose id is in the principal's
  /// visible id-set for [resourceType] (owned ∪ shared, resolved by
  /// [visibleResolver]), projecting each survivor into its domain entity — the
  /// single filtering path every list endpoint shares.
  ///
  /// The visible set is computed once per call (not per row), then each
  /// candidate is a set-membership test. On the live store the rows are already
  /// database-scoped to this same set, so the filter is a reconciliation no-op;
  /// on the in-memory store it is the sole visibility gate. This mirrors how
  /// [listWorkspaces] reconciles the owner-only workspace scope.
  Future<List<R>> _filterByVisibility<T, R>(
    int userId,
    String resourceType,
    Future<List<T>> Function() loadCandidates,
    int? Function(T) idOf,
    R Function(T) project,
  ) async {
    final visible = await visibleResolver.visibleIds(
      resourceType,
      userId.toString(),
    );
    return [
      for (final record in await loadCandidates())
        if (idOf(record) != null && visible.contains(idOf(record)))
          project(record),
    ];
  }
}

/// The write-side persistence seam the [AppWriteService] mutates through.
///
/// Mirrors the [AppReadStore]/[ResourceContainmentStore] split: the write service needs
/// to load a single item (to diff a `PUT` against the stored row), insert/update
/// items, projects and comments, and delete an item. [RepositoryAppWriteStore]
/// is the live store over the `app_db` repository singletons;
/// [InMemoryAppWriteStore] is a seeded, database-free store the field-grade
/// enforcement tests drive.
abstract class AppWriteStore {
  /// Inserts or updates [record], returning the saved workspace row.
  ///
  /// This is the one **scoped-entity** write seam: [WorkspaceRecord]
  /// carries `@TomDbScope(field: 'ownerId')`, so on the live repository an
  /// update/delete of a row the caller does not own raises
  /// [TomDataScopeAuthorizationException] before any statement runs.
  Future<WorkspaceRecord> saveWorkspace(WorkspaceRecord record);

  /// Deletes the workspace row with [id] (owner-scoped on the live repository).
  Future<void> deleteWorkspace(int id);

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

  /// Returns the subtask row for [id], or `null` when it does not exist.
  ///
  /// The update path needs the stored row before it can authorize: a subtask
  /// carries no owner of its own, so the gate is resolved from the *parent*
  /// item — which means the parent link has to be read from storage rather than
  /// taken from the caller's payload.
  Future<SubtaskRecord?> findSubtask(int id);

  /// The `position` a newly added subtask of item [itemId] should take — one
  /// past the highest currently stored, or `0` for the first.
  ///
  /// On the store rather than computed by the caller because `position` is
  /// **server-owned**, like `id` and `itemId`: a client that sent one would be
  /// guessing from the list it happens to hold, and two clients adding a step
  /// concurrently would both guess the same number. The store is the only place
  /// that can read what is actually there.
  Future<int> nextSubtaskPosition(int itemId);

  /// Inserts or updates [record], returning the saved subtask row.
  Future<SubtaskRecord> saveSubtask(SubtaskRecord record);
}

/// The query-backed [AppWriteStore] wired at boot.
///
/// Writes through the process-wide singleton repositories. Requires a live
/// `app_db` connection and the reflection runtime, so it is exercised end-to-end
/// (the unit tests use [InMemoryAppWriteStore]).
///
/// The deletes `await` in a block body rather than tail-returning, which reads
/// as needless ceremony and is not: [TomRepository.deleteById] completes with an
/// affected-row count, and `Future<void>` does not erase it. Tail-returning one
/// makes this store hand its callers an `int` that no static type between here
/// and the endpoint admits to — the whole chain up to
/// [AdvancedAppApiService.deleteWorkspace] says `Future<void>` — so the leak is
/// invisible at every point where someone might notice it. `await` is where the
/// value stops.
class RepositoryAppWriteStore implements AppWriteStore {
  /// Creates the repository-backed store (stateless; reads the singletons).
  const RepositoryAppWriteStore();

  @override
  Future<WorkspaceRecord> saveWorkspace(WorkspaceRecord record) =>
      workspaceRepository.save(record);

  @override
  Future<void> deleteWorkspace(int id) async {
    await workspaceRepository.deleteById(id);
  }

  @override
  Future<ItemRecord?> findItem(int id) => itemRepository.findById(id);

  @override
  Future<ItemRecord> saveItem(ItemRecord record) => itemRepository.save(record);

  @override
  Future<void> deleteItem(int id) async {
    await itemRepository.deleteById(id);
  }

  @override
  Future<ProjectRecord> saveProject(ProjectRecord record) =>
      projectRepository.save(record);

  @override
  Future<CommentRecord> saveComment(CommentRecord record) =>
      commentRepository.save(record);

  @override
  Future<SubtaskRecord?> findSubtask(int id) => subtaskRepository.findById(id);

  @override
  Future<int> nextSubtaskPosition(int itemId) async {
    // Descending by position, first row: the same
    // `idx_app_subtasks_item_position` index migration [004] adds serves this
    // read backwards, so "what is the last step" costs one index seek rather
    // than loading the checklist.
    final rows = await subtaskRepository.findByQuerySentence(
      'FIND BY item_id = :itemId ORDER BY position DESC',
      {'itemId': itemId},
    );
    return rows.isEmpty ? 0 : (rows.first.position ?? 0) + 1;
  }

  @override
  Future<SubtaskRecord> saveSubtask(SubtaskRecord record) =>
      subtaskRepository.save(record);
}

/// A seeded, database-free [AppWriteStore] for tests (and local scaffolding).
///
/// Holds the rows directly and assigns surrogate keys on insert, mirroring the
/// auth server's `InMemoryAdminStore`. A test can seed an item, drive a write
/// through [AppWriteService], and assert the persisted row reflects only the
/// permitted fields — no connection or reflection.
class InMemoryAppWriteStore implements AppWriteStore {
  final List<WorkspaceRecord> _workspaces;
  final List<ItemRecord> _items;
  final List<ProjectRecord> _projects;
  final List<CommentRecord> _comments;
  final List<SubtaskRecord> _subtasks;

  int _nextWorkspaceId = 1;
  int _nextItemId = 1;
  int _nextProjectId = 1;
  int _nextCommentId = 1;
  int _nextSubtaskId = 1;

  /// Seeds the store with the given rows (each list defaults to empty); the
  /// auto-increment counters advance past any seeded ids.
  InMemoryAppWriteStore({
    List<WorkspaceRecord> workspaces = const [],
    List<ItemRecord> items = const [],
    List<ProjectRecord> projects = const [],
    List<CommentRecord> comments = const [],
    List<SubtaskRecord> subtasks = const [],
  }) : _workspaces = [...workspaces],
       _items = [...items],
       _projects = [...projects],
       _comments = [...comments],
       _subtasks = [...subtasks] {
    _nextWorkspaceId = _maxId(_workspaces.map((w) => w.id)) + 1;
    _nextItemId = _maxId(_items.map((i) => i.id)) + 1;
    _nextProjectId = _maxId(_projects.map((p) => p.id)) + 1;
    _nextCommentId = _maxId(_comments.map((c) => c.id)) + 1;
    _nextSubtaskId = _maxId(_subtasks.map((s) => s.id)) + 1;
  }

  static int _maxId(Iterable<int?> ids) =>
      ids.fold<int>(0, (max, id) => (id != null && id > max) ? id : max);

  /// The persisted workspace rows (test introspection). The database-free store
  /// does *not* enforce the framework `@TomDbScope` owner-scope (that lives in
  /// the live repository and is exercised by the integration script); here
  /// a save/delete always succeeds, so the create path can be unit-tested.
  List<WorkspaceRecord> get workspaces => List.unmodifiable(_workspaces);

  /// The persisted item rows (test introspection).
  List<ItemRecord> get items => List.unmodifiable(_items);

  /// The persisted project rows (test introspection).
  List<ProjectRecord> get projects => List.unmodifiable(_projects);

  /// The persisted comment rows (test introspection).
  List<CommentRecord> get comments => List.unmodifiable(_comments);

  /// The persisted subtask rows (test introspection).
  List<SubtaskRecord> get subtasks => List.unmodifiable(_subtasks);

  @override
  Future<WorkspaceRecord> saveWorkspace(WorkspaceRecord record) async {
    if (record.id == null) {
      record.id = _nextWorkspaceId++;
      _workspaces.add(record);
    } else {
      _replaceById(_workspaces, record, (w) => w.id == record.id);
    }
    return record;
  }

  @override
  Future<void> deleteWorkspace(int id) async =>
      _workspaces.removeWhere((w) => w.id == id);

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
  Future<void> deleteItem(int id) async =>
      _items.removeWhere((i) => i.id == id);

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

  @override
  Future<SubtaskRecord?> findSubtask(int id) async {
    for (final subtask in _subtasks) {
      if (subtask.id == id) return subtask;
    }
    return null;
  }

  @override
  Future<int> nextSubtaskPosition(int itemId) async {
    var highest = -1;
    for (final subtask in _subtasks) {
      if (subtask.itemId == itemId) {
        highest = max(highest, subtask.position ?? 0);
      }
    }
    return highest + 1;
  }

  @override
  Future<SubtaskRecord> saveSubtask(SubtaskRecord record) async {
    if (record.id == null) {
      record.id = _nextSubtaskId++;
      _subtasks.add(record);
    } else {
      _replaceById(_subtasks, record, (s) => s.id == record.id);
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
/// full resource key. Only the closures live here; the *set and order* of
/// graded fields is the server resource bundle's
/// [AppResourceBundles.gradableItemKeys], so a bundle key without a binding
/// fails loudly when [_gradableItemFields] is built. The non-gradable columns
/// (`label`, `tags`) are absent by design — `updateItem` preserves them from
/// the stored row, `createItem` takes them from the creator's payload.
///
/// The `@TomFileReference` columns (`attachment`, `internalNote`) are absent for
/// a stronger reason than grading: a blob key is *server-minted* by
/// `saveFile`, and a caller who could write one would repoint their row at
/// somebody else's bytes. Because the merge only ever overlays fields listed
/// here, leaving them out is what makes a client-supplied key unwritable — the
/// keys move exclusively through the file endpoint.
final Map<String, _GradableItemBinding> _gradableItemBindings = {
  'todo.item.title': _GradableItemBinding(
    (r) => r.title,
    (t, s) => t.title = s.title,
  ),
  'todo.item.status': _GradableItemBinding(
    (r) => r.status,
    (t, s) => t.status = s.status,
  ),
  'todo.item.priority': _GradableItemBinding(
    (r) => r.priority,
    (t, s) => t.priority = s.priority,
  ),
  'todo.item.assigneeId': _GradableItemBinding(
    (r) => r.assigneeId,
    (t, s) => t.assigneeId = s.assigneeId,
  ),
  'todo.item.dueDate': _GradableItemBinding(
    (r) => r.dueDate,
    (t, s) => t.dueDate = s.dueDate,
  ),
  'todo.item.estimate': _GradableItemBinding(
    (r) => r.estimateHours,
    (t, s) => t.estimateHours = s.estimateHours,
  ),
  'todo.item.description': _GradableItemBinding(
    (r) => r.description,
    (t, s) => t.description = s.description,
  ),
};

/// The field-graded [ItemRecord] columns, in the display order the server
/// resource bundle labels them — the same set the field-grade resolver answers
/// and the matrix the auth server seeds. The order and membership come
/// from [AppResourceBundles.gradableItemKeys]; [_gradableItemBindings] supplies
/// each key's read/copy closures. A gradable key with no binding throws here.
final List<_GradableItemField> _gradableItemFields = [
  for (final key in AppResourceBundles.gradableItemKeys())
    _GradableItemField(
      key,
      _gradableItemBindings[key]!.read,
      _gradableItemBindings[key]!.copy,
    ),
];

/// The gradable `todo.item.*` field keys the write path enforces, in order —
/// exposed so a drift guard can assert it against the server resource bundle.
List<String> get gradableItemFieldKeys => [
  for (final field in _gradableItemFields) field.resourceKey,
];

/// Pure write logic over an [AppWriteStore], gated by the same two authorization
/// layers the reads use.
///
/// Item, comment, subtask and project mutations first resolve the principal's
/// effective [ProjectRole] on the target through the [ResourceRoleResolver] (no
/// access → the resource is treated as not-found, closed/safe); the three
/// workspace mutations carry no role resolution at all and rely on ownership
/// instead, as below. Authorization is then enforced in two layers:
///
/// - **Role gating.** Six mutations check a minimum role through `_requireRole`:
///   `createProject` and `createItem` require `editor` or above on the parent,
///   `deleteItem` `editor` on the item, `addSubtask` and `updateSubtask`
///   `editor` on the **parent item** (a subtask has no owner of its own), and
///   `addComment` `commenter` or above. The other four writes are protected
///   without a role gate: [updateWorkspace] and [deleteWorkspace] are owner-only
///   *by construction* — the CRUD repository's C-3 write enforcement rejects a
///   non-owner's row before any statement runs; [updateItem] resolves the role
///   only to grade the fields below; and [createWorkspace] has no parent to gate
///   against, recording the creator's C-5 ownership instead.
/// - **Field-grade enforcement.** For item writes every gradable field the
///   caller *changes* must be graded [TomAuthState.full] for their role (the
///   [FieldGradeResolver]); the first violation rejects the whole write.
///   The persisted row overlays only the `full`-graded fields, so server-owned
///   columns (`id`, `listId`, `reporterId`, `createdAt`) and non-`full` fields
///   always keep their stored value — the persisted row reflects only permitted
///   fields.
///
/// Like [AppReadService] it has no server/zone dependency (only the store and the
/// two resolvers' seams), so the whole write path unit-tests against seeded
/// stores, with no MariaDB.
class AppWriteService {
  /// The persistence seam mutations are applied through.
  final AppWriteStore store;

  /// Resolves a principal's effective [ProjectRole] on a resource.
  final ResourceRoleResolver accessResolver;

  /// Resolves a [ProjectRole]'s per-field grades.
  final FieldGradeResolver gradeResolver;

  /// Records the creator's C-5 ownership grant when a resource is created.
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
    // The creator becomes the project's owner — stamp the explicit C-5
    // owner grant so enforcement (which re-resolves grants/shares live from the
    // DB on every request) and the `/resource-roles` endpoint both see the
    // ownership, rather than only the implicit workspace chain the bespoke
    // resolver walks.
    await ownershipWriter.recordOwner(
      userId.toString(),
      ResourceRoleKeys.project(saved.id!.toString()),
    );
    return projectFromRecord(saved);
  }

  /// Creates [workspace] owned by the caller — the scoped-entity create path.
  ///
  /// The caller "becomes the owner" two ways, mirroring [createProject]: the
  /// persisted `ownerId` column is stamped with their id — so the framework
  /// `@TomDbScope(field: 'ownerId')` owner-scope makes the row theirs and the
  /// C-3 *insert*-scope check permits it (a principal may only create a row
  /// scoped to a value they are allowed) — and an explicit C-5 owner grant is
  /// recorded so live enforcement and the `/resource-roles` endpoint both see
  /// the ownership.
  Future<Workspace> createWorkspace(int userId, Workspace workspace) async {
    final record = workspaceToRecord(workspace)
      ..id = null
      ..ownerId = userId
      ..createdAt = DateTime.now();
    final saved = await store.saveWorkspace(record);
    await ownershipWriter.recordOwner(
      userId.toString(),
      ResourceRoleKeys.workspace(saved.id!.toString()),
    );
    return workspaceFromRecord(saved);
  }

  /// Updates the workspace [workspaceId] (its mutable name), owner-only *by
  /// construction* — the live write-rejection path.
  ///
  /// The save routes through the framework CRUD repository, whose C-3 write
  /// enforcement first asserts the target row is within the caller's owner-scope
  /// — a non-owner's update raises [TomDataScopeAuthorizationException] before
  /// any statement runs, which the app server maps to a 403. There is
  /// deliberately **no pre-read** here (which would surface a not-found instead):
  /// the point is to let the framework exception fire. `ownerId` is
  /// re-stamped with the caller's id — a no-op for the legitimate owner, and
  /// never reached by a non-owner.
  Future<Workspace> updateWorkspace(
    int userId,
    int workspaceId,
    Workspace workspace,
  ) async {
    final record = workspaceToRecord(workspace)
      ..id = workspaceId
      ..ownerId = userId;
    return workspaceFromRecord(await store.saveWorkspace(record));
  }

  /// Deletes the workspace [workspaceId], owner-only by the same C-3 write
  /// enforcement as [updateWorkspace]: a non-owner's delete raises
  /// [TomDataScopeAuthorizationException] (mapped to 403).
  Future<void> deleteWorkspace(int userId, int workspaceId) =>
      store.deleteWorkspace(workspaceId);

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
    // The creator (also the reporter) owns the new item — stamp the C-5
    // owner grant so ownership is an explicit, resolvable resource role.
    await ownershipWriter.recordOwner(
      userId.toString(),
      ResourceRoleKeys.item(saved.id!.toString()),
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
    if (role == null) throw itemNotFound(itemId);
    final stored = await store.findItem(itemId);
    if (stored == null) throw itemNotFound(itemId);
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

  /// Adds [subtask] to the item [itemId]; `editor` or above may add one.
  ///
  /// The gate is deliberately one step stronger than [addComment]'s: a comment
  /// is *about* an item, a subtask is *part of* it, so adding one changes what
  /// the item claims to require. A `commenter` who could create subtasks would
  /// be editing the item's scope through a side door.
  ///
  /// `id`, `itemId` and `position` are all stamped server-side: the first two
  /// from the addressed item, so the payload cannot file the subtask under an
  /// item the caller was not gated on, and the third from the stored checklist
  /// ([AppWriteStore.nextSubtaskPosition]) — a new step always appends. Only
  /// `title` and `done` are caller-owned on create.
  Future<Subtask> addSubtask(int userId, int itemId, Subtask subtask) async {
    await _requireRole(
      userId,
      AppResourceTypes.item,
      itemId,
      ProjectRole.editor,
      'add a subtask to this item',
      notFoundOnNoAccess: true,
    );
    final record = subtaskToRecord(subtask)
      ..id = null
      ..itemId = itemId
      ..position = await store.nextSubtaskPosition(itemId);
    return subtaskFromRecord(await store.saveSubtask(record));
  }

  /// Applies the caller's [subtask] payload to the stored subtask [subtaskId];
  /// `editor` or above on the **parent item** may update it.
  ///
  /// The parent is read from storage rather than from the payload, for two
  /// reasons that are really one: it is what the authorization gate must be
  /// resolved against (a subtask has no owner of its own), and re-stamping it
  /// onto the merged row makes the parent link unwritable — a caller cannot
  /// move a subtask onto an item they do not hold `editor` on by editing its
  /// `itemId`. Only `title`, `done` and `position` are caller-owned.
  Future<Subtask> updateSubtask(
    int userId,
    int subtaskId,
    Subtask subtask,
  ) async {
    final stored = await store.findSubtask(subtaskId);
    final parentId = stored?.itemId;
    if (parentId == null) throw _subtaskNotFound(subtaskId);
    await _requireRole(
      userId,
      AppResourceTypes.item,
      parentId,
      ProjectRole.editor,
      'edit this subtask',
      notFoundOnNoAccess: true,
    );
    final merged = subtaskToRecord(subtask)
      ..id = subtaskId
      ..itemId = parentId;
    return subtaskFromRecord(await store.saveSubtask(merged));
  }

  /// The closed/safe "no such subtask" rejection, shaped like [itemNotFound]:
  /// an unreachable subtask and a non-existent one are indistinguishable.
  static TomEndpointHandlerException _subtaskNotFound(int subtaskId) =>
      TomEndpointHandlerException(
        'app.subtask.not_found',
        'No accessible subtask with id $subtaskId',
      );

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
        throw itemNotFound(resourceId);
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

  /// A field-by-field copy of [record] (the write paths never mutate the stored
  /// row in place — a rejected write must leave storage untouched).
  ///
  /// The `@TomFileReference` keys are copied like any other column, which is
  /// what makes them survive an ordinary edit: [_enforceFieldWrites] builds the
  /// row to persist from this clone and overlays only the *gradable* fields, so
  /// a column absent from [_gradableItemFields] always keeps its baseline value.
  /// Omitting them here would clear a live blob key on every update.
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
    ..attachment = record.attachment
    ..internalNote = record.internalNote
    ..createdAt = record.createdAt
    ..updatedAt = record.updatedAt;
}

/// Cross-user sharing — the `POST /share` / `DELETE /share/{id}` logic over
/// framework delegation.
///
/// Both operations are **owner-only**: the principal must resolve to
/// [ProjectRole.owner] on the shared resource (via the [ResourceRoleResolver]).
/// Creating a share writes a `share`-mode [TomPrincipalDelegation] through the
/// [ShareDelegationStore] — the framework [TomDelegationResolver] the resolver
/// reads folds it into the grantee's effective roles on their next request, so
/// the grant takes effect immediately with no parallel share table. Revoking
/// deletes the delegation row, authorized against the share's own target
/// (parsed back from the delegation's `resourceKey`).
///
/// Like the read/write services it has no server/zone dependency (only the store
/// and the resolver's seam), so the share path unit-tests against seeded stores.
class AppShareService {
  /// The delegation-write seam shares are persisted and revoked through.
  final ShareDelegationStore store;

  /// Resolves a principal's effective [ProjectRole] on a resource.
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
        resourceKey: ResourceRoleKeys.forResource(
          request.resourceType,
          resourceId.toString(),
        ),
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
    final target = parseResourceKey(delegation?.resourceKey);
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
/// over [TomDefaultErrorHandler] to turn those keys into the HTTP contract
/// `README_advanced_10_servers_endpoints.md` documents:
///
/// - `app.item.not_found` / `app.share.not_found` / `app.subtask.not_found` →
///   **404** (a resource the caller cannot reach is reported missing, never
///   leaking its existence).
/// - `app.access.forbidden` / `app.item.field_forbidden` (and the pipeline's
///   pre-invocation [appEndpointAccessDeniedKey]) → **403**.
/// - a framework [TomDataScopeAuthorizationException] (a non-owner's write to a
///   `@TomDbScope` row) → **403**, carrying its own
///   `data_scope.write.out_of_scope` key.
Response? appForbiddenOrNotFound(
  Request request,
  Object error,
  StackTrace stack,
) {
  // A framework data-scope *write* rejection — a non-owner updating or
  // deleting a `@TomDbScope` row (the sample's workspace write path) — surfaces
  // as a 403 carrying the framework's own stable key
  // (`data_scope.write.out_of_scope`), distinct from the app's own
  // `app.access.forbidden`. Checked before the `TomException` narrowing so it is
  // mapped regardless of the exception's place in the hierarchy.
  if (error is TomDataScopeAuthorizationException) {
    return Response.forbidden(
      jsonEncode({'error': error.key}),
      headers: {TomHeader.contentType: TomMimeType.json.toHeaderValue()},
    );
  }
  if (error is! TomException) return null;
  switch (error.key) {
    case 'app.item.not_found':
    case 'app.share.not_found':
    case 'app.subtask.not_found':
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

/// The per-endpoint [TomErrorHandler] that maps the app services' closed/safe
/// denial keys to 403/404 when a service **method itself** throws.
///
/// Two distinct places raise the denial keys, and they surface at *different*
/// layers. A *pre-invocation* access check (the pipeline's contract-declared
/// `TomAuthenticatedAccess`) throws outside the per-endpoint try/catch, so it
/// escapes to the server-level [appServerErrorHandler]. But an *in-method*
/// denial — `deleteItem` rejecting a viewer, `updateItem` rejecting a
/// forbidden field write — is caught by the endpoint pipeline's per-endpoint
/// handler (`TomEndpoint.errorHandler`), which otherwise defaults to
/// [TomDefaultErrorHandler] and turns every such throw into an opaque 500. This
/// handler, declared on the `@TomApiImplementation`, is that per-endpoint
/// handler: it reuses [appForbiddenOrNotFound] to map the keys and falls back
/// to the framework default for genuine faults.
class AppEndpointErrorHandler extends TomErrorHandler {
  /// Const so it can be supplied as the `@TomApiImplementation` annotation's
  /// `errorHandler`.
  const AppEndpointErrorHandler();

  @override
  Response handleErrorDefault(
    Object error,
    Object stacktrace,
    Request r,
    Object? result,
  ) =>
      appForbiddenOrNotFound(
        r,
        error,
        stacktrace is StackTrace ? stacktrace : StackTrace.current,
      ) ??
      const TomDefaultErrorHandler().handleErrorDefault(
        error,
        stacktrace,
        r,
        result,
      );
}

/// The `@tomComponent` implementing the registry's `app` API.
///
/// Bound to the `appApi` endpoints (`tomRemoteApis['app']`); the bean container
/// instantiates it through the no-argument constructor, which wires nothing —
/// [AppReadService], [AppWriteService] and [AppShareService] are each built
/// lazily on first use (the `_reads` field below documents why the wiring has
/// to be deferred). The per-endpoint access policy is **declared on the
/// contract** (each `appApi` endpoint's `TomApiEndpoint.access`, G-API-3)
/// and extracted by the pipeline on first call, so these handlers carry no
/// inline access annotation: `appHealth` is public, every other endpoint
/// requires an authenticated principal, which the pipeline reads from the bearer
/// token; the resource- and field-level checks then run inside the handlers.
///
/// The read endpoints delegate to [AppReadService], the write endpoints — the
/// workspace, project, item, comment and subtask mutations — to
/// [AppWriteService] (role gating + field-grade enforcement), and the share
/// endpoints (`share`/`revokeShare`) to [AppShareService] (owner-only). Two
/// endpoints reach no service at all: `health` answers with a literal status
/// map and `resources` with the static [AppResourceBundles] bundle.
@tomReflector
@tomComponent
@TomApiImplementation(apiId: 'app', errorHandler: AppEndpointErrorHandler())
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
  Future<Map<String, Object>> health() async => {
    'status': 'ok',
    'service': 'advanced_app_server',
  };

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appListWorkspaces')
  @override
  Future<List<Workspace>> listWorkspaces() =>
      _reads.listWorkspaces(_principalId);

  // ----- Workspace write endpoints (scoped-entity write path) --------------

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appCreateWorkspace')
  @override
  Future<Workspace> createWorkspace(Workspace workspace) =>
      _writes.createWorkspace(_principalId, workspace);

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appUpdateWorkspace')
  @override
  Future<Workspace> updateWorkspace(Workspace workspace) =>
      _writes.updateWorkspace(
        _principalId,
        int.tryParse(workspace.id.get()) ?? -1,
        workspace,
      );

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appDeleteWorkspace')
  @override
  Future<void> deleteWorkspace(EntityIdRequest request) =>
      _writes.deleteWorkspace(_principalId, int.tryParse(request.id) ?? -1);

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

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appListAttachments')
  @override
  Future<List<FileDescriptorDto>> listAttachments(String listId) =>
      _reads.listAttachments(_principalId, int.tryParse(listId) ?? -1);

  // The two ordered child reads on an item. Both take an [EntityIdRequest]
  // rather than a bare `String` (G-API-2) even though their GETs carry no body:
  // the pipeline folds URL parameters into the request DTO before instantiating
  // it, so a body-less `GET /items/{id}/comments` still arrives typed.
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appListComments')
  @override
  Future<List<TodoComment>> listComments(EntityIdRequest request) =>
      _reads.listComments(_principalId, int.tryParse(request.id) ?? -1);

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appListSubtasks')
  @override
  Future<List<Subtask>> listSubtasks(EntityIdRequest request) =>
      _reads.listSubtasks(_principalId, int.tryParse(request.id) ?? -1);

  // ----- Write endpoints ---------------------------------------------------

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
  Future<TodoItem> updateItem(TodoItem item) =>
      _writes.updateItem(_principalId, int.tryParse(item.id.get()) ?? -1, item);

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appDeleteItem')
  @override
  Future<void> deleteItem(EntityIdRequest request) =>
      _writes.deleteItem(_principalId, int.tryParse(request.id) ?? -1);

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appAddComment')
  @override
  Future<TodoComment> addComment(TodoComment comment) => _writes.addComment(
    _principalId,
    int.tryParse(comment.itemId.get()) ?? -1,
    comment,
  );

  // The parent link is read from the payload's `itemId` — which the pipeline
  // has already populated from the `{id}` path capture (`urlParameterMapping:
  // {'id': 'itemId'}`), the same shape `appAddComment` uses. So the addressed
  // item, not a caller-chosen field, is what the write is gated on.
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appAddSubtask')
  @override
  Future<Subtask> addSubtask(Subtask subtask) => _writes.addSubtask(
    _principalId,
    int.tryParse(subtask.itemId.get()) ?? -1,
    subtask,
  );

  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appUpdateSubtask')
  @override
  Future<Subtask> updateSubtask(Subtask subtask) => _writes.updateSubtask(
    _principalId,
    int.tryParse(subtask.id.get()) ?? -1,
    subtask,
  );

  // ----- Share endpoints ---------------------------------------------------

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
  // strings, not data.
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appResources')
  @override
  Future<ResourceBundleDto> resources() async => AppResourceBundles.appBundle();

  // `resourceRoles` (`appResourceRoles`, authenticated `GET /resource-roles`)
  // serves the caller's effective resource-role map. The client
  // holds the authz token as an opaque bearer, so the grade-bearing role map is
  // fetched here rather than decoded from a token claim; the app server resolves
  // it from the principal's ownership grants and share delegations.
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appResourceRoles')
  @override
  Future<Map<String, String>> resourceRoles() =>
      _reads.resourceRoles(_principalId);
}
