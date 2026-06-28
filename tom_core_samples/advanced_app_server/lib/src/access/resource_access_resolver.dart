/// Resource-level access resolution: given a principal and a target resource,
/// compute the principal's effective [ProjectRole] from **ownership-or-share**.
///
/// This is the first of the app server's two authorization layers (§A.4). It
/// answers "*may this principal touch this object at all, and as what role?*" —
/// the field-level grade resolver (step 18) then maps the resolved role to
/// per-field `TomAuthState`s.
///
/// The rule (§A.4):
///
/// - A principal **owns** a resource when they own the `Workspace` at the top of
///   its containment chain (`item → list → project → workspace.ownerId`).
///   Ownership resolves to [ProjectRole.owner].
/// - Otherwise a **`Share`** whose `(resourceType, resourceId)` covers the target
///   *or any ancestor* grants the share's role — a share on a project covers its
///   lists and items.
/// - With neither, the principal has **no access** (`null`).
///
/// When several shares apply, the **strongest** wins ([ProjectRole] is declared
/// most-to-least privileged, so the lowest `index` is strongest).
///
/// The DB reads sit behind an [AppResourceStore] seam so the resolver is pure
/// over whichever store it is handed: [RepositoryAppResourceStore] is the live
/// query-backed store wired at boot; [InMemoryAppResourceStore] is a seeded
/// store for tests (step 17's "Done" bar — owner/shared/stranger resolved with
/// no database). The resolver mirrors the auth server's store-seam pattern.
library;

import 'package:advanced_todo_domain/advanced_todo_domain.dart';

import '../persistence/app_persistence_model.dart';

/// The canonical `Share.resourceType` tokens. A share names which table its
/// polymorphic `resourceId` keys into; the resolver matches these against the
/// target's containment chain.
class AppResourceTypes {
  const AppResourceTypes._();

  /// A whole workspace (the top of the containment chain).
  static const String workspace = 'workspace';

  /// A project within a workspace.
  static const String project = 'project';

  /// A list within a project.
  static const String list = 'list';

  /// An item within a list.
  static const String item = 'item';
}

/// A `(resourceType, resourceId)` reference — one link in a containment chain.
class ResourceRef {
  /// The resource's type token (one of [AppResourceTypes]).
  final String type;

  /// The resource's surrogate key.
  final int id;

  /// Creates a reference to the resource of [type] with key [id].
  const ResourceRef(this.type, this.id);

  @override
  bool operator ==(Object other) =>
      other is ResourceRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() => '$type:$id';
}

/// The record-lookup seam the [ResourceAccessResolver] reads through.
///
/// The resolver needs only to walk parent links (`item → list → project →
/// workspace`), read a workspace's owner, and list a user's shares. Putting
/// those reads behind a small interface lets it run against the live
/// repositories at boot and a seeded in-memory store under test, with identical
/// logic on both.
abstract class AppResourceStore {
  /// Returns the workspace row for [id], or `null` when it does not exist.
  Future<WorkspaceRecord?> findWorkspace(int id);

  /// Returns the project row for [id], or `null` when it does not exist.
  Future<ProjectRecord?> findProject(int id);

  /// Returns the list row for [id], or `null` when it does not exist.
  Future<ListRecord?> findList(int id);

  /// Returns the item row for [id], or `null` when it does not exist.
  Future<ItemRecord?> findItem(int id);

  /// Returns every share granted to the user with [userId]. Empty when the user
  /// is the grantee of no share.
  Future<List<ShareRecord>> sharesForUser(int userId);
}

/// Resolves a principal's effective [ProjectRole] on a resource from ownership
/// and shares.
class ResourceAccessResolver {
  /// The store the resolver reads parent links, ownership, and shares through.
  final AppResourceStore store;

  /// Builds the resolver over [store] (the live repositories at boot, a seeded
  /// store under test).
  const ResourceAccessResolver(this.store);

  /// Computes the effective [ProjectRole] the principal [userId] holds on the
  /// resource `(resourceType, resourceId)`, or `null` when they have no access.
  ///
  /// Ownership of the containing workspace short-circuits to [ProjectRole.owner]
  /// (the strongest role); otherwise the strongest matching share wins; with no
  /// match the result is `null`.
  Future<ProjectRole?> resolveRole({
    required int userId,
    required String resourceType,
    required int resourceId,
  }) async {
    final chain = await _ancestry(resourceType, resourceId);

    // Ownership: the chain ends at the workspace when the links resolve. If the
    // principal owns it, they are the owner — the strongest role, so we are done.
    final top = chain.last;
    if (top.type == AppResourceTypes.workspace) {
      final workspace = await store.findWorkspace(top.id);
      if (workspace?.ownerId == userId) return ProjectRole.owner;
    }

    // Shares: the strongest share whose target is the resource or any ancestor.
    ProjectRole? best;
    for (final share in await store.sharesForUser(userId)) {
      final type = share.resourceType;
      final id = share.resourceId;
      if (type == null || id == null) continue;
      if (!chain.contains(ResourceRef(type, id))) continue;
      final role = _parseRole(share.projectRole);
      if (best == null || role.index < best.index) best = role;
    }
    return best;
  }

  /// Builds the containment chain from the target up to its workspace, as far as
  /// the parent links resolve. The target itself is always the first element, so
  /// a direct share matches even when the row (or a broken parent link) cannot
  /// be walked all the way to a workspace.
  Future<List<ResourceRef>> _ancestry(String type, int id) async {
    final chain = <ResourceRef>[ResourceRef(type, id)];
    var current = ResourceRef(type, id);
    while (current.type != AppResourceTypes.workspace) {
      final parent = await _parentOf(current);
      if (parent == null) break;
      chain.add(parent);
      current = parent;
    }
    return chain;
  }

  /// Resolves the parent reference of [ref] by reading its foreign key, or
  /// `null` when the row or the link is missing (so the walk stops cleanly).
  Future<ResourceRef?> _parentOf(ResourceRef ref) async {
    switch (ref.type) {
      case AppResourceTypes.item:
        final listId = (await store.findItem(ref.id))?.listId;
        return listId == null ? null : ResourceRef(AppResourceTypes.list, listId);
      case AppResourceTypes.list:
        final projectId = (await store.findList(ref.id))?.projectId;
        return projectId == null
            ? null
            : ResourceRef(AppResourceTypes.project, projectId);
      case AppResourceTypes.project:
        final workspaceId = (await store.findProject(ref.id))?.workspaceId;
        return workspaceId == null
            ? null
            : ResourceRef(AppResourceTypes.workspace, workspaceId);
      default:
        return null;
    }
  }

  /// Parses a stored `project_role` token leniently — an unknown or absent token
  /// degrades to [ProjectRole.viewer] (the least-privileged), mirroring the
  /// domain `Share.projectRoleValue` accessor.
  static ProjectRole _parseRole(String? token) =>
      ProjectRole.values.asNameMap()[token] ?? ProjectRole.viewer;
}

/// The query-backed [AppResourceStore] wired at boot.
///
/// Reads through the process-wide singleton repositories. Requires a live
/// `app_db` connection and the reflection runtime, so it is exercised
/// end-to-end (the unit tests use [InMemoryAppResourceStore]).
class RepositoryAppResourceStore implements AppResourceStore {
  /// Creates the repository-backed store (stateless; reads the singletons).
  const RepositoryAppResourceStore();

  @override
  Future<WorkspaceRecord?> findWorkspace(int id) =>
      workspaceRepository.findById(id);

  @override
  Future<ProjectRecord?> findProject(int id) => projectRepository.findById(id);

  @override
  Future<ListRecord?> findList(int id) => listRepository.findById(id);

  @override
  Future<ItemRecord?> findItem(int id) => itemRepository.findById(id);

  @override
  Future<List<ShareRecord>> sharesForUser(int userId) async {
    final matches = await shareRepository.findByQuerySentence(
      'FIND BY grantee_user_id = :userId',
      {'userId': userId},
    );
    return matches.toList();
  }
}

/// A seeded, database-free [AppResourceStore] for tests (and local scaffolding).
///
/// Holds the workspace/project/list/item rows and the shares directly, keyed by
/// surrogate id, so a test can assert the owner/shared/stranger paths without a
/// connection or reflection.
class InMemoryAppResourceStore implements AppResourceStore {
  final Map<int, WorkspaceRecord> _workspaces;
  final Map<int, ProjectRecord> _projects;
  final Map<int, ListRecord> _lists;
  final Map<int, ItemRecord> _items;
  final List<ShareRecord> _shares;

  /// Seeds the store from the given record lists, indexing each by its `id`.
  /// Records with a `null` id are ignored (they are unpersisted).
  InMemoryAppResourceStore({
    List<WorkspaceRecord> workspaces = const [],
    List<ProjectRecord> projects = const [],
    List<ListRecord> lists = const [],
    List<ItemRecord> items = const [],
    List<ShareRecord> shares = const [],
  })  : _workspaces = {for (final w in workspaces) if (w.id != null) w.id!: w},
        _projects = {for (final p in projects) if (p.id != null) p.id!: p},
        _lists = {for (final l in lists) if (l.id != null) l.id!: l},
        _items = {for (final i in items) if (i.id != null) i.id!: i},
        _shares = shares;

  @override
  Future<WorkspaceRecord?> findWorkspace(int id) async => _workspaces[id];

  @override
  Future<ProjectRecord?> findProject(int id) async => _projects[id];

  @override
  Future<ListRecord?> findList(int id) async => _lists[id];

  @override
  Future<ItemRecord?> findItem(int id) async => _items[id];

  @override
  Future<List<ShareRecord>> sharesForUser(int userId) async =>
      [for (final s in _shares) if (s.granteeUserId == userId) s];
}
