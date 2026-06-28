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
///   every listed row through the step-17 [ResourceAccessResolver]
///   (ownership-or-share → effective [ProjectRole], `null` = invisible) and
///   projects an item's per-field grades through the step-18 [FieldGradeResolver].
///   It has no server/zone dependency (only the resolvers' own seams), so the
///   visibility filter and the field-state matrix are unit-tested directly
///   against seeded stores — no server, no MariaDB.
/// - [AdvancedAppApiService] is the thin `@tomComponent` adapter the endpoint
///   pipeline routes to. It binds each [AppApiService] method to its registry
///   endpoint (`tomRemoteApis['app'][...]`), sources the caller's principal from
///   the bearer token, and (for the reads) delegates to [AppReadService]. The
///   write and share endpoints are wired in steps 20–21; until then they throw a
///   clear deferral so the contract stays fully implemented and analyzable.
///
/// This file delivers step 19 (the read endpoints). The component is exercised
/// end-to-end only at boot (step 21), where its reflection is generated from the
/// `bin/app_server_start.dart` import graph; the step-19 "Done" bar is the
/// database-free [AppReadService] integration test (a shared user sees the
/// owner's project, a stranger does not).
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../access/field_grade_resolver.dart';
import '../access/resource_access_resolver.dart';
import '../persistence/app_mapping.dart';
import '../persistence/app_persistence_model.dart';

/// The listing seam the read operations enumerate candidate rows through.
///
/// The read service needs only to list the children of a parent (and every
/// workspace); the per-row visibility decision is the [ResourceAccessResolver]'s
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
/// principal can reach — the step-17 [ResourceAccessResolver] computes the
/// effective [ProjectRole] (ownership-or-share) and `null` means invisible. The
/// field-state endpoint resolves the principal's role on an item and projects
/// the step-18 [FieldGradeResolver]'s per-field grades into [GradedFieldDto]s.
class AppReadService {
  /// The listing seam candidate rows are enumerated through.
  final AppReadStore store;

  /// Resolves a principal's effective [ProjectRole] on a resource (step 17).
  final ResourceAccessResolver accessResolver;

  /// Resolves a [ProjectRole]'s per-field grades (step 18).
  final FieldGradeResolver gradeResolver;

  /// Builds the service over its three collaborators (live stores at boot,
  /// seeded stores under test).
  const AppReadService(this.store, this.accessResolver, this.gradeResolver);

  /// The production wiring: every collaborator over its repository-backed store.
  factory AppReadService.production() => AppReadService(
        const RepositoryAppReadStore(),
        const ResourceAccessResolver(RepositoryAppResourceStore()),
        const FieldGradeResolver(RepositoryGrantStore()),
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

/// The `@tomComponent` implementing the registry's `app` API.
///
/// Bound to the `appApi` endpoints (`tomRemoteApis['app']`); the bean container
/// instantiates it through the no-argument constructor, which wires the
/// production [AppReadService]. The access annotations are declared explicitly
/// (the registry's `appApiAccess` map is informational, not auto-applied):
/// `appHealth` is public, every other endpoint requires an authenticated
/// principal, which the pipeline reads from the bearer token; the resource- and
/// field-level checks then run inside the handlers.
///
/// The read endpoints (this step) delegate to [AppReadService]. The write
/// endpoints (step 20) and share endpoints (step 21) are scaffolded with a
/// deferral throw until those steps replace them.
@tomReflector
@tomComponent
@TomApiImplementation(apiId: 'app')
class AdvancedAppApiService implements AppApiService {
  /// Production read logic over the repository-backed stores.
  final AppReadService _reads = AppReadService.production();

  /// The authenticated caller's auth-user id (the surrogate key the `app_db`
  /// rows reference cross-database). Resolved from the bearer-token principal.
  int get _principalId =>
      int.tryParse('${TomBearerAuthentication.getPrincipal().user.id}') ?? -1;

  @TomPublicAccess()
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appHealth')
  @override
  Future<Map<String, Object>> health() async =>
      {'status': 'ok', 'service': 'advanced_app_server'};

  @TomAuthenticatedAccess()
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appListWorkspaces')
  @override
  Future<List<Workspace>> listWorkspaces() =>
      _reads.listWorkspaces(_principalId);

  @TomAuthenticatedAccess()
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appListProjects')
  @override
  Future<List<Project>> listProjects(String workspaceId) =>
      _reads.listProjects(_principalId, int.tryParse(workspaceId) ?? -1);

  @TomAuthenticatedAccess()
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appListLists')
  @override
  Future<List<TodoList>> listLists(String projectId) =>
      _reads.listLists(_principalId, int.tryParse(projectId) ?? -1);

  @TomAuthenticatedAccess()
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appListItems')
  @override
  Future<List<TodoItem>> listItems(String listId) =>
      _reads.listItems(_principalId, int.tryParse(listId) ?? -1);

  @TomAuthenticatedAccess()
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appItemFieldStates')
  @override
  Future<List<GradedFieldDto>> itemFieldStates(String itemId) =>
      _reads.itemFieldStates(_principalId, int.tryParse(itemId) ?? -1);

  // ----- Write endpoints (step 20) -----------------------------------------

  @TomAuthenticatedAccess()
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appCreateProject')
  @override
  Future<Project> createProject(Project project) => _deferred('appCreateProject');

  @TomAuthenticatedAccess()
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appCreateItem')
  @override
  Future<TodoItem> createItem(TodoItem item) => _deferred('appCreateItem');

  @TomAuthenticatedAccess()
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appUpdateItem')
  @override
  Future<TodoItem> updateItem(String id, TodoItem item) =>
      _deferred('appUpdateItem');

  @TomAuthenticatedAccess()
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appDeleteItem')
  @override
  Future<void> deleteItem(String id) => _deferred('appDeleteItem');

  @TomAuthenticatedAccess()
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appAddComment')
  @override
  Future<TodoComment> addComment(String itemId, TodoComment comment) =>
      _deferred('appAddComment');

  // ----- Share endpoints (step 21) -----------------------------------------

  @TomAuthenticatedAccess()
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appShare')
  @override
  Future<void> share(ShareRequest request) => _deferred('appShare');

  @TomAuthenticatedAccess()
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appRevokeShare')
  @override
  Future<void> revokeShare(String id) => _deferred('appRevokeShare');

  /// Marks an endpoint that this step does not yet implement. The write
  /// endpoints land in step 20 and the share endpoints in step 21; until then a
  /// call surfaces a clear, stable signal rather than a silent no-op.
  Never _deferred(String endpointId) => throw TomEndpointHandlerException(
        'app.endpoint.not_implemented',
        'The "$endpointId" endpoint is wired in step 20/21 of '
            'advanced_example_specification_plan.md.',
      );
}
