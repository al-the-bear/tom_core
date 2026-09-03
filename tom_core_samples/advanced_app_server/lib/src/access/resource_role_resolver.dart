/// Resource-level access resolution over the framework delegation resolver
///: given a principal and a target resource, compute the principal's
/// effective [ProjectRole] from their framework-resolved roles.
///
/// This is the first of the app server's two authorization layers. It
/// answers "*may this principal touch this object at all, and as what role?*" —
/// the field-level grade resolver then maps the resolved role to
/// per-field `TomAuthState`s.
///
/// It **replaces** the sample's earlier bespoke resolver, which walked an
/// implicit `workspace.owner_id` chain and read a separate share table:
/// ownership is now an explicit C-5 owner grant and a share is a C-6
/// `share`-mode `TomPrincipalDelegation`. Both arrive folded into one
/// flat `resourceKey → roleName` map from
/// [TomDelegationResolver.resolveEffectiveRoles]; this resolver adds only the
/// sample's **containment** rule — a role held on an ancestor covers its
/// descendants — which is app-domain logic the framework does not own.
///
/// The rule (unchanged in behaviour by that replacement):
///
/// - A principal's role on the target is the **strongest** role they hold on the
///   target *or any ancestor* in the containment chain (`item → list → project →
///   workspace`); a grant or share on an ancestor covers the descendant.
/// - [ProjectRole] is declared most-to-least privileged, so the lowest `index`
///   is strongest.
/// - With no role on the target or any ancestor, the principal has **no access**
///   (`null`).
///
/// The ancestry walk reads parent links through a [ResourceContainmentStore]
/// seam ([RepositoryResourceContainmentStore] at boot,
/// [InMemoryResourceContainmentStore] under test); the effective-role map comes
/// from the framework [TomDelegationResolver], so ownership and shares resolve
/// through one framework path — the sole enforcement path (no parallel scheme).
library;

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../persistence/app_persistence_model.dart';
import 'ownership_grant_writer.dart';
import 'share_delegation_store.dart';

/// The canonical resource-type tokens. A resource key is `<type>:<id>`; these
/// tokens name the target's kind and match the containment vocabulary the shared
/// [ResourceRoleKeys] builds keys with, so the resolver's ancestry keys line up
/// with the framework-resolved role map.
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

/// The record-lookup seam the [ResourceRoleResolver] walks parent links through.
///
/// The resolver needs only to read a resource's parent foreign key to climb the
/// containment chain (`item → list → project → workspace`). Ownership and shares
/// are no longer read here — they arrive from the framework delegation resolver
/// — so this seam carries just the three parent-link reads.
abstract class ResourceContainmentStore {
  /// Returns the project row for [id], or `null` when it does not exist.
  Future<ProjectRecord?> findProject(int id);

  /// Returns the list row for [id], or `null` when it does not exist.
  Future<ListRecord?> findList(int id);

  /// Returns the item row for [id], or `null` when it does not exist.
  Future<ItemRecord?> findItem(int id);
}

/// Resolves a principal's effective [ProjectRole] on a resource from their
/// framework-resolved roles (ownership grants ∪ share delegations), applying the
/// sample's containment rule.
class ResourceRoleResolver {
  /// The store parent links are read through to build the ancestry chain.
  final ResourceContainmentStore containment;

  /// The framework resolver folding C-5 ownership grants and C-6 share
  /// delegations into one flat `resourceKey → roleName` map.
  final TomDelegationResolver delegationResolver;

  /// Builds the resolver over [containment] and [delegationResolver] (live
  /// stores at boot, seeded stores under test).
  const ResourceRoleResolver(this.containment, this.delegationResolver);

  /// The production wiring: the repository-backed containment store, and the
  /// framework delegation resolver over the shared grant/delegation repositories
  /// (both on `main`, bound to `auth_db` at boot).
  factory ResourceRoleResolver.production() => ResourceRoleResolver(
    const RepositoryResourceContainmentStore(),
    TomDelegationResolver(
      RepositoryPrincipalDelegationStore(principalDelegationRepository),
      TomPrincipalResourceRoleResolver(
        RepositoryPrincipalResourceGrantStore(principalResourceGrantRepository),
      ),
    ),
  );

  /// Computes the effective [ProjectRole] the principal [userId] holds on the
  /// resource `(resourceType, resourceId)`, or `null` when they have no access.
  ///
  /// Resolves the principal's flat effective-role map from the framework
  /// resolver, then keeps the strongest role over the target's containment chain
  /// — so a role on an ancestor covers the descendant, and the closed/safe
  /// default (no matching key anywhere in the chain) is `null`.
  Future<ProjectRole?> resolveRole({
    required int userId,
    required String resourceType,
    required int resourceId,
  }) async {
    final effective = await delegationResolver.resolveEffectiveRoles(
      userId.toString(),
      DateTime.now(),
    );
    if (effective.isEmpty) return null;
    final chain = await _ancestry(resourceType, resourceId);
    ProjectRole? best;
    for (final ref in chain) {
      final token =
          effective[ResourceRoleKeys.forResource(ref.type, ref.id.toString())];
      if (token == null) continue;
      final role = _parseRole(token);
      if (best == null || role.index < best.index) best = role;
    }
    return best;
  }

  /// Builds the containment chain from the target up to its workspace, as far as
  /// the parent links resolve. The target itself is always the first element, so
  /// a direct grant/share matches even when a broken parent link stops the walk
  /// short of the workspace.
  Future<List<_Ref>> _ancestry(String type, int id) async {
    final chain = <_Ref>[_Ref(type, id)];
    var current = _Ref(type, id);
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
  Future<_Ref?> _parentOf(_Ref ref) async {
    switch (ref.type) {
      case AppResourceTypes.item:
        final listId = (await containment.findItem(ref.id))?.listId;
        return listId == null ? null : _Ref(AppResourceTypes.list, listId);
      case AppResourceTypes.list:
        final projectId = (await containment.findList(ref.id))?.projectId;
        return projectId == null
            ? null
            : _Ref(AppResourceTypes.project, projectId);
      case AppResourceTypes.project:
        final workspaceId = (await containment.findProject(
          ref.id,
        ))?.workspaceId;
        return workspaceId == null
            ? null
            : _Ref(AppResourceTypes.workspace, workspaceId);
      default:
        return null;
    }
  }

  /// Parses a stored role token leniently — an unknown or absent token degrades
  /// to [ProjectRole.viewer] (the least-privileged), mirroring the domain
  /// `Share.projectRoleValue` accessor.
  static ProjectRole _parseRole(String? token) =>
      ProjectRole.values.asNameMap()[token] ?? ProjectRole.viewer;
}

/// A `(type, id)` link in a containment chain — internal to the ancestry walk.
class _Ref {
  final String type;
  final int id;

  const _Ref(this.type, this.id);
}

/// Parses a resource key (`<type>:<id>`, e.g. `project:1`) into its type token
/// and surrogate id, or `null` when it is absent or malformed.
///
/// The single parsing seam for the `<type>:<id>` convention [ResourceRoleKeys]
/// builds keys with: the share revoke path (parsing a delegation's stored
/// `resourceKey`) and the resource-role expansion (parsing the framework
/// delegation resolver's effective-role keys) both read keys through it, so the
/// parse rule lives in exactly one place.
({String type, int id})? parseResourceKey(String? resourceKey) {
  if (resourceKey == null) return null;
  final separator = resourceKey.indexOf(':');
  if (separator <= 0 || separator == resourceKey.length - 1) return null;
  final id = int.tryParse(resourceKey.substring(separator + 1));
  if (id == null) return null;
  return (type: resourceKey.substring(0, separator), id: id);
}

/// The query-backed [ResourceContainmentStore] wired at boot.
///
/// Reads parent links through the process-wide singleton repositories. Requires
/// a live `app_db` connection and the reflection runtime, so it is exercised
/// end-to-end (unit tests use [InMemoryResourceContainmentStore]).
class RepositoryResourceContainmentStore implements ResourceContainmentStore {
  /// Creates the repository-backed store (stateless; reads the singletons).
  const RepositoryResourceContainmentStore();

  @override
  Future<ProjectRecord?> findProject(int id) => projectRepository.findById(id);

  @override
  Future<ListRecord?> findList(int id) => listRepository.findById(id);

  @override
  Future<ItemRecord?> findItem(int id) => itemRepository.findById(id);
}

/// A seeded, database-free [ResourceContainmentStore] for tests.
///
/// Holds the project/list/item rows keyed by surrogate id, so a test can assert
/// the containment walk (ownership/share flows down, not up) without a
/// connection or reflection.
class InMemoryResourceContainmentStore implements ResourceContainmentStore {
  final Map<int, ProjectRecord> _projects;
  final Map<int, ListRecord> _lists;
  final Map<int, ItemRecord> _items;

  /// Seeds the store from the given record lists, indexing each by its `id`.
  /// Records with a `null` id are ignored (they are unpersisted).
  InMemoryResourceContainmentStore({
    List<ProjectRecord> projects = const [],
    List<ListRecord> lists = const [],
    List<ItemRecord> items = const [],
  }) : _projects = {
         for (final p in projects)
           if (p.id != null) p.id!: p,
       },
       _lists = {
         for (final l in lists)
           if (l.id != null) l.id!: l,
       },
       _items = {
         for (final i in items)
           if (i.id != null) i.id!: i,
       };

  @override
  Future<ProjectRecord?> findProject(int id) async => _projects[id];

  @override
  Future<ListRecord?> findList(int id) async => _lists[id];

  @override
  Future<ItemRecord?> findItem(int id) async => _items[id];
}
