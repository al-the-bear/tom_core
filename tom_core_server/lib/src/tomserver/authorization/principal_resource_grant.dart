/// Server-side persistence and resolution of per-principal-per-resource roles
/// (C-5).
///
/// Where [TomResourceGrant] grades a `(role, resourceKey)` pair — "*what may
/// this role see/edit on this field?*" — this library stores the layer above it:
/// which **role** a **principal** holds on a **resource**. A principal can hold
/// a different role on every resource (`owner` of project X, `viewer` of project
/// Y), so the grant is keyed by `(principal_id, resource_key)` and carries the
/// role name.
///
/// The pieces:
///
/// - [TomPrincipalResourceGrant] — the persistable `(principal_id, resource_key,
///   role)` row, mapped to `tom_principal_resource_grant`.
/// - [PrincipalResourceGrantStore] — the read seam the resolver runs over
///   ([RepositoryPrincipalResourceGrantStore] at boot,
///   [InMemoryPrincipalResourceGrantStore] under test).
/// - [TomPrincipalResourceRoleResolver] — folds a principal's grant rows into
///   the `resourceKey → roleName` map carried in
///   [TomAccessControlInformation.resourceRoles] (and thus into the
///   authorization token, so re-login applies grant changes — G-AUTHZ-5).
///
/// **No fallback (C-5 done-bar).** A `(principal, resource)` with no grant row
/// simply has no entry in the resolved map; the kernel
/// [TomResourceRoleAdapter] then yields [TomAuthState.none] for it. When a
/// principal holds several roles on the *same* resource (via delegation, C-6),
/// the **strongest** role wins — decided by the caller-supplied role ordering,
/// so the resolver stays independent of any particular role vocabulary.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/types_operator.dart';
import '../object_persistence/persistence_annotations.dart';
import '../object_persistence/crud_repository.dart';

/// A persistable grant of a single role to a `(principalId, resourceKey)` pair —
/// the storage row behind per-principal-per-resource roles.
///
/// Mapped to `tom_principal_resource_grant` via the object-persistence
/// annotations. Load every grant for a principal with
/// [TomPrincipalResourceRoleResolver], fold them into a `resourceKey → roleName`
/// map, and carry that map on [TomAccessControlInformation.resourceRoles].
@tomReflector
@TomDbTable(
  datasource: 'main',
  table: 'tom_principal_resource_grant',
  primaryKeyField: 'id',
)
class TomPrincipalResourceGrant {
  /// Surrogate primary key (`-1` until persisted).
  @TomEntityId()
  @TomDbColumn<int, TomDbInt>(columnName: 'id', isReadOnly: true)
  int id;

  /// The principal the grant applies to (the principal's stable identifier,
  /// stringified — e.g. a user id).
  @TomDbColumn<String, TomDbString>(columnName: 'principal_id')
  String principalId;

  /// The resource the role is scoped to (a resource key / `tomId`).
  @TomDbColumn<String, TomDbString>(columnName: 'resource_key')
  String resourceKey;

  /// The role the principal holds on the resource (an opaque name resolved to a
  /// [TomAuthState] through [TomResourceRoleRegistry]).
  @TomDbColumn<String, TomDbString>(columnName: 'role')
  String role;

  /// Creates a grant.
  ///
  /// Every field defaults so the entity is **no-arg constructible**:
  /// [TomSqlDatasourceRepository] loads a row by instantiating a blank grant via
  /// reflection and then populating each `@TomDbColumn` field. Callers that
  /// build a fully-specified grant still pass the named arguments.
  TomPrincipalResourceGrant({
    this.id = -1,
    this.principalId = '',
    this.resourceKey = '',
    this.role = '',
  });

  /// The canonical DDL for the `tom_principal_resource_grant` table.
  ///
  /// A principal has at most one direct role per resource, enforced by the
  /// unique key. (Delegated roles from C-6 arrive as separate rows resolved
  /// alongside these; the resolver folds duplicates by strength.)
  static const String createTableSql = '''
CREATE TABLE IF NOT EXISTS tom_principal_resource_grant (
  id BIGINT NOT NULL AUTO_INCREMENT,
  principal_id VARCHAR(255) NOT NULL,
  resource_key VARCHAR(255) NOT NULL,
  role VARCHAR(255) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_principal_resource_grant (principal_id, resource_key)
);''';

  @override
  String toString() =>
      'TomPrincipalResourceGrant($principalId, $resourceKey -> $role)';
}

/// The grant-lookup seam the [TomPrincipalResourceRoleResolver] reads through.
///
/// The resolver needs only the grant rows for one principal. Putting that read
/// behind a one-method interface lets it run against the live repository at boot
/// and a seeded in-memory store under test, with identical folding on both.
abstract class PrincipalResourceGrantStore {
  /// Returns every grant for the principal identified by [principalId]. Empty
  /// when the principal has no grants (every resource then resolves to
  /// [TomAuthState.none] — closed/safe).
  Future<List<TomPrincipalResourceGrant>> grantsForPrincipal(String principalId);
}

/// Resolves a principal's grant rows into the `resourceKey → roleName` map that
/// feeds [TomAccessControlInformation.resourceRoles].
class TomPrincipalResourceRoleResolver {
  /// The store the resolver loads grant rows through.
  final PrincipalResourceGrantStore store;

  /// Ranks two competing roles on the *same* resource, returning the stronger.
  ///
  /// Defaults to [TomResourceRoleRegistry]-backed comparison: the role whose
  /// registered [TomAuthState] is the less restrictive (wider) wins, so a
  /// delegated `owner` is not undone by a direct `viewer`. An application with a
  /// role vocabulary the registry does not cover can supply its own ordering.
  final String Function(String a, String b) strongerRole;

  /// Builds the resolver over [store]. [strongerRole] defaults to registry-based
  /// strength comparison.
  TomPrincipalResourceRoleResolver(
    this.store, {
    String Function(String a, String b)? strongerRole,
  }) : strongerRole = strongerRole ?? registryStrength;

  /// Loads [principalId]'s grants and folds them into a `resourceKey → roleName`
  /// map. Duplicate resources collapse to the [strongerRole].
  Future<Map<String, String>> resolveResourceRoles(String principalId) async {
    final grants = await store.grantsForPrincipal(principalId);
    return foldRoles(
      [for (final grant in grants) MapEntry(grant.resourceKey, grant.role)],
      strongerRole,
    );
  }

  /// Folds `resourceKey → roleName` [entries] into a map, collapsing duplicate
  /// resources to the [stronger] of the competing roles.
  ///
  /// Shared with C-6 delegation resolution, which merges delegated role entries
  /// alongside a principal's direct grants under the *same* strength ordering, so
  /// a direct and a delegated role on one resource resolve identically wherever
  /// the fold is applied.
  static Map<String, String> foldRoles(
    Iterable<MapEntry<String, String>> entries,
    String Function(String a, String b) stronger,
  ) {
    final result = <String, String>{};
    for (final entry in entries) {
      final existing = result[entry.key];
      result[entry.key] =
          existing == null ? entry.value : stronger(existing, entry.value);
    }
    return result;
  }

  /// Convenience: resolve [principalId]'s roles and wrap them in a kernel
  /// [TomResourceRoleAdapter] ready to install on [TomAuthorization] or to query
  /// directly for server-side enforcement.
  Future<TomResourceRoleAdapter> resolveAdapter(String principalId) async =>
      TomResourceRoleAdapter(await resolveResourceRoles(principalId));

  /// Default strength ordering: the role with the wider registered
  /// [TomAuthState] wins; an unregistered role is treated as [TomAuthState.none]
  /// (the weakest), so a known role always beats an unknown one.
  ///
  /// Exposed so C-6 delegation resolution folds delegated roles under the exact
  /// same ordering a caller left at its default here.
  static String registryStrength(String a, String b) {
    final sa = TomResourceRoleRegistry.stateFor(a) ?? TomAuthState.none;
    final sb = TomResourceRoleRegistry.stateFor(b) ?? TomAuthState.none;
    return sa.index >= sb.index ? a : b;
  }
}

/// The query-backed [PrincipalResourceGrantStore] wired at boot.
///
/// Reads through a [TomPrincipalResourceGrant] repository over the `main`
/// datasource. Requires a live connection and the reflection runtime, so it is
/// exercised end-to-end (unit tests use [InMemoryPrincipalResourceGrantStore]).
class RepositoryPrincipalResourceGrantStore
    implements PrincipalResourceGrantStore {
  /// The repository the store reads grant rows through.
  final TomSqlDatasourceRepository<TomPrincipalResourceGrant, int> repository;

  /// Builds the store over [repository].
  const RepositoryPrincipalResourceGrantStore(this.repository);

  @override
  Future<List<TomPrincipalResourceGrant>> grantsForPrincipal(
    String principalId,
  ) async {
    final matches = await repository.findByQuerySentence(
      'FIND BY principal_id = :principalId',
      {'principalId': principalId},
    );
    return matches.toList();
  }
}

/// A seeded, database-free [PrincipalResourceGrantStore] for tests.
///
/// Holds the grant rows directly and filters by principal id, so a test can
/// assert the resolved `resourceKey → roleName` map without a connection or
/// reflection.
class InMemoryPrincipalResourceGrantStore
    implements PrincipalResourceGrantStore {
  final List<TomPrincipalResourceGrant> _grants;

  /// Seeds the store with the full set of [grants] across all principals.
  InMemoryPrincipalResourceGrantStore(List<TomPrincipalResourceGrant> grants)
      : _grants = grants;

  @override
  Future<List<TomPrincipalResourceGrant>> grantsForPrincipal(
    String principalId,
  ) async =>
      [for (final g in _grants) if (g.principalId == principalId) g];
}
