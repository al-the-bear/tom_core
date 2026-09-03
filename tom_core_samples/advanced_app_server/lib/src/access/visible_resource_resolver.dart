/// Computes a principal's **visible id-set** per entity type — the input the
/// async data-scope resolver pushes to the database.
///
/// The workspace entity's visibility is owner-only, so it stays a synchronous
/// single-column `@TomDbScope`. Project/list/item visibility, in
/// contrast, folds C-5 ownership grants **and** C-6 `share`-mode delegations
/// over the containment chain (`workspace → project → list → item`): a role held
/// on an ancestor covers every descendant. A single-column `IN (…)` AND-scope
/// cannot express that (it would silently AND-hide legitimately shared rows), so
/// The framework data scope accepts an **async, union/OR**
/// resolver — and this class is the sample's implementation of it.
///
/// For a principal it produces two id-sets per entity type — the ids reachable
/// via **ownership** (C-5) and the ids reachable via **shares** (C-6) — which
/// the framework ORs into `(id IN (owned…) OR id IN (shared…))`. Their union is
/// the full visible set; keeping them as separate groups is what genuinely
/// exercises the union predicate rather than pre-merging into one `IN` list.
///
/// The two role sources are resolved separately through the framework
/// [TomDelegationResolver]: its `directResolver` yields the C-5 grants and
/// `resolveDelegatedRoles` yields the C-6 shares. Each source's granted resource
/// keys are then expanded *down* the containment tree to the requested entity
/// type, mirroring the downward flow [ResourceRoleResolver] walks upward at
/// enforcement time — so the pushed-down scope and the service-layer resolver
/// agree on exactly which rows a principal may see.
///
/// **Re-entrancy.** The downward expansion enumerates children through the same
/// repositories these scopes filter, so every enumeration read runs inside
/// [TomDataScope.runUnscoped]: the reads that *compute* the visible set are not
/// themselves re-scoped, which is what prevents the resolver recursing into
/// itself.
///
/// **Why this is not the framework's built-in `resource` scope.** The framework
/// now ships a grant-driven row scope of its own ([TomDbScope.resourceScope],
/// backed by `TomResourceDataScope`), which filters an entity's `resource_key`
/// column by the keys the principal holds a grant on. That is a **direct-key**
/// model: a row is visible when a grant names *that row's own key*. This
/// resolver is a **containment** model: a row is visible when a grant names the
/// row's key *or any of its ancestors'*. The framework scope cannot express the
/// inheritance, and this resolver is not a hand-rolled duplicate of it — they
/// are two different visibility rules, and an application picks whichever
/// matches its domain. Do not "simplify" this into the built-in scope: doing so
/// would silently drop ancestor→descendant inheritance and hide every row a
/// principal reaches only through a workspace- or project-level grant.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../endpoints/app_endpoints.dart'
    show AppReadStore, RepositoryAppReadStore;
import '../persistence/app_persistence_model.dart';
import 'resource_role_resolver.dart';

/// Registers the async `visible:project|list|item` data scopes onto the
/// framework [TomDataScopeRegistry], each resolving a principal's owned ∪
/// shared id-set through a production [VisibleResourceResolver].
///
/// Called once at app-server boot — after *both* `initializeReflection()` and
/// `TomDataSourceInfo.initializeDatasourceInfo(...)`, and before serving. It
/// eagerly builds the production [VisibleResourceResolver], whose repositories
/// resolve their reflected persistence types and their datasource metadata at
/// construction time; running it before either is initialised throws. Each
/// registration maps the per-request [TomPrincipal] to the two-group
/// `[ownedIds, sharedIds]` the CRUD repository ORs into
/// `(id IN (owned…) OR id IN (shared…))` for the matching record type. The
/// resolver is built once and shared across the three scope kinds; it is
/// stateless (it reads the live repositories per call), so a single instance is
/// safe under concurrent requests.
void registerAppDataScopes() {
  final resolver = VisibleResourceResolver.production();
  TomDataScopeRegistry.registerAsync(
    projectVisibilityScope,
    (principal) => resolver.visibleIdGroups(
      AppResourceTypes.project,
      _scopePrincipalId(principal),
    ),
  );
  TomDataScopeRegistry.registerAsync(
    listVisibilityScope,
    (principal) => resolver.visibleIdGroups(
      AppResourceTypes.list,
      _scopePrincipalId(principal),
    ),
  );
  TomDataScopeRegistry.registerAsync(
    itemVisibilityScope,
    (principal) => resolver.visibleIdGroups(
      AppResourceTypes.item,
      _scopePrincipalId(principal),
    ),
  );
}

/// The auth-user surrogate id the async scopes key on, extracted from the
/// per-request [principal] exactly as `AdvancedAppApiService._principalId` does
/// (`principal.user.id`, not `principal.id` — the app-server principal wraps the
/// auth user). A `null` principal yields `null` (which the resolver treats as
/// deny-all); a non-numeric id collapses to `-1`, which resolves to an empty
/// visible set — deny-all, the secure default.
String? _scopePrincipalId(TomPrincipal? principal) {
  if (principal == null) return null;
  return '${int.tryParse('${principal.user.id}') ?? -1}';
}

/// Resolves the visible id-sets (owned ∪ shared) for the shared entity types
/// (project/list/item) from a principal's framework-resolved roles.
class VisibleResourceResolver {
  /// The listing seam child rows are enumerated through when expanding a grant
  /// down its containment subtree.
  final AppReadStore store;

  /// The framework resolver whose `directResolver` yields C-5 ownership grants
  /// and whose `resolveDelegatedRoles` yields C-6 share delegations.
  final TomDelegationResolver delegationResolver;

  /// Builds the resolver over [store] and [delegationResolver] (live stores at
  /// boot, seeded stores under test).
  const VisibleResourceResolver(this.store, this.delegationResolver);

  /// The production wiring: the repository-backed read store and the framework
  /// delegation resolver over the shared grant/delegation repositories.
  factory VisibleResourceResolver.production() => VisibleResourceResolver(
    const RepositoryAppReadStore(),
    ResourceRoleResolver.production().delegationResolver,
  );

  /// The owned and shared id-set groups for entity [type] that principal
  /// [principalId] may see — the two groups the async data scope ORs into
  /// `(id IN (owned…) OR id IN (shared…))`.
  ///
  /// A `null`/blank principal denies every row (an empty outer list — deny-all,
  /// the secure default). Otherwise returns `[ownedIds, sharedIds]`; either may
  /// be empty (an empty group contributes a `FALSE` disjunct, so the union is
  /// simply the other set).
  Future<List<List<Object?>>> visibleIdGroups(
    String type,
    String? principalId,
  ) async {
    if (principalId == null || principalId.isEmpty) return const [];
    return TomDataScope.runUnscoped(() async {
      final owned = await _idsFromRoles(
        await delegationResolver.directResolver.resolveResourceRoles(
          principalId,
        ),
        type,
      );
      final shared = await _idsFromRoles(
        await delegationResolver.resolveDelegatedRoles(
          principalId,
          DateTime.now(),
        ),
        type,
      );
      return [owned.toList(), shared.toList()];
    });
  }

  /// The flat visible id-set for entity [type] and principal [principalId] — the
  /// union of the [visibleIdGroups]. The service layer filters the in-memory
  /// store against this so a database-free read agrees with the pushed-down DB
  /// scope (the same reconciliation applied to owner-scoped workspaces).
  Future<Set<Object?>> visibleIds(String type, String? principalId) async {
    final groups = await visibleIdGroups(type, principalId);
    return {for (final group in groups) ...group};
  }

  /// Expands every granted resource key in [roles] down to the [targetType],
  /// collecting the reachable ids. Shared by the owned and shared groups.
  Future<Set<int>> _idsFromRoles(
    Map<String, String> roles,
    String targetType,
  ) async {
    final ids = <int>{};
    for (final key in roles.keys) {
      final ref = parseResourceKey(key);
      if (ref == null) continue;
      await _descend(ref.type, ref.id, targetType, ids);
    }
    return ids;
  }

  /// Collects into [out] the ids of type [target] reachable from the resource
  /// `(type, id)` by walking *down* the containment chain.
  ///
  /// A grant on a resource covers itself and its descendants but never its
  /// ancestors, so a resource above [target] descends into its children while a
  /// resource at or below [target] contributes only a direct match — the exact
  /// downward flow the enforcement-time [ResourceRoleResolver.resolveRole] walk
  /// climbs in reverse.
  Future<void> _descend(
    String type,
    int id,
    String target,
    Set<int> out,
  ) async {
    if (type == target) {
      out.add(id);
      return;
    }
    switch (type) {
      case AppResourceTypes.workspace:
        for (final project in await store.projectsInWorkspace(id)) {
          final projectId = project.id;
          if (projectId != null) {
            await _descend(AppResourceTypes.project, projectId, target, out);
          }
        }
      case AppResourceTypes.project:
        for (final list in await store.listsInProject(id)) {
          final listId = list.id;
          if (listId != null) {
            await _descend(AppResourceTypes.list, listId, target, out);
          }
        }
      case AppResourceTypes.list:
        for (final item in await store.itemsInList(id)) {
          final itemId = item.id;
          if (itemId != null) {
            await _descend(AppResourceTypes.item, itemId, target, out);
          }
        }
    }
  }
}
