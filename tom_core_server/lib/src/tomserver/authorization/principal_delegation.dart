/// Server-side delegation of per-principal-per-resource roles (C-6).
///
/// Delegation lets principal **A** (the *delegator*) lend some of their C-5
/// `(principal, resource)` roles to principal **B** (the *delegate*). A
/// delegation is a persistable row resolved **alongside** B's own direct grants
/// (C-5), in three modes:
///
/// - **share** — an explicit resource share: A grants B a named [role] on a
///   named [TomPrincipalDelegation.resourceKey] (the "shared todo, same form /
///   different formId" case, G-AUTHZ-3). B need hold no grant of their own.
/// - **absence** — time-bounded automatic delegation (out-of-office): within the
///   `[validFrom, validTo]` window B inherits **all** of A's direct roles;
///   outside it, none. This is the C-6 done-bar (verified at two timestamps).
/// - **intentional** — manual, revocable delegation: B inherits A's roles (or a
///   single [TomPrincipalDelegation.resourceKey] of them) until the row is
///   [TomPrincipalDelegation.revoked].
///
/// The validity window and the [TomPrincipalDelegation.revoked] kill-switch apply
/// **uniformly** to every mode ([TomPrincipalDelegation.isActiveAt]); the mode
/// only decides *which* roles flow — an explicit `(resourceKey, role)` for
/// `share`, or the delegator's own resolved roles for `absence`/`intentional`.
///
/// **Delegation is not transitive.** B inherits A's *direct* grants only, never
/// A's own delegated-in roles — a deliberate security default that forecloses
/// delegation chains and privilege loops. The merge reuses C-5's strength
/// ordering ([TomPrincipalResourceRoleResolver.foldRoles] /
/// [TomPrincipalResourceRoleResolver.registryStrength]), so a role B holds both
/// directly and by delegation collapses to the stronger, exactly as duplicate
/// direct grants do.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../object_persistence/persistence_annotations.dart';
import '../object_persistence/crud_repository.dart';
import 'principal_resource_grant.dart';
import '../privacy/personal_data.dart';
import '../datasources/read_replicas.dart';

/// How a [TomPrincipalDelegation] lends the delegator's roles to the delegate.
enum TomDelegationMode {
  /// An explicit share of one resource at one role (`resourceKey` + `role` set).
  share,

  /// Time-bounded automatic delegation of all the delegator's roles.
  absence,

  /// Manual, revocable delegation of the delegator's roles.
  intentional,
}

/// A persistable delegation of a delegator's C-5 roles to a delegate — the
/// storage row behind share / absence / intentional delegation.
///
/// Mapped to `tom_principal_delegation`. Resolve a delegate's active delegations
/// with [TomDelegationResolver], which folds the delegated roles into the same
/// `resourceKey → roleName` map C-5 carries on the principal.
@tomReflector
// Read from the primary: a change here — a revocation above all — must
// take effect at once, not after a replica's lag.
@TomPrimaryReads()
@TomDbTable(
  datasource: 'main',
  table: 'tom_principal_delegation',
  primaryKeyFields: ['id'],
)
// Authorization metadata: the delegation rows feed the row scope and so must
// not be filtered by it (see [TomPrincipalResourceGrant]). A delegation's
// `resource_key` names the resource being shared, not the resource the *row*
// belongs to, which is a second reason the automatic scope would be wrong here.
@TomDbScope.unscoped()
class TomPrincipalDelegation {
  /// Surrogate primary key (`-1` until persisted).
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int id;

  /// The principal whose roles are lent (A, the delegator), by its
  /// tenant-qualified id, like [TomPrincipalResourceGrant.principalId].
  @TomDataSubject()
  @TomDbColumn(columnName: 'delegator_id')
  String delegatorId;

  /// The principal receiving the lent roles (B, the delegate), by its
  /// tenant-qualified id.
  @TomDataSubject()
  @TomDbColumn(columnName: 'delegate_id')
  String delegateId;

  /// The delegation mode, stored as the [TomDelegationMode] name.
  @TomDbColumn(columnName: 'mode')
  String mode;

  /// For `share` the resource shared; for `absence`/`intentional` an optional
  /// single resource to narrow the inherited roles to (`null` = all of the
  /// delegator's resources).
  @TomDbColumn(columnName: 'resource_key')
  String? resourceKey;

  /// For `share` the role granted on [resourceKey]; for `absence`/`intentional`
  /// an optional override applied to every inherited resource (`null` = inherit
  /// the delegator's own role on each resource).
  @TomDbColumn(columnName: 'role')
  String? role;

  /// Inclusive window start; `null` = unbounded (active from any past time).
  ///
  /// An **instant**, stored and read as UTC — this bound decides whether a
  /// delegate holds a role, and a wall-clock reading would mean a different
  /// moment on every node that read it. The data source applies the convention
  /// (`datasources/sql_instant.dart`); nothing is asked of the caller beyond
  /// passing a `DateTime`, which comes back UTC-flagged.
  @TomDbColumn(columnName: 'valid_from')
  DateTime? validFrom;

  /// Inclusive window end; `null` = unbounded (never expires by time). An
  /// instant on the same terms as [validFrom].
  @TomDbColumn(columnName: 'valid_to')
  DateTime? validTo;

  /// Manual kill-switch: a revoked delegation is inactive at every timestamp.
  @TomDbColumn(columnName: 'revoked')
  bool revoked;

  /// Creates a delegation.
  ///
  /// Every field defaults so the entity is **no-arg constructible** (the
  /// repository loads a row by instantiating a blank delegation via reflection
  /// and populating each `@TomDbColumn`). Callers building a full delegation pass
  /// the named arguments.
  TomPrincipalDelegation({
    this.id = -1,
    this.delegatorId = '',
    this.delegateId = '',
    this.mode = '',
    this.resourceKey,
    this.role,
    this.validFrom,
    this.validTo,
    this.revoked = false,
  });

  /// The parsed [TomDelegationMode], or `null` when [mode] is unknown/blank
  /// (an unparseable mode delegates nothing — closed/safe).
  TomDelegationMode? get delegationMode {
    for (final value in TomDelegationMode.values) {
      if (value.name == mode) return value;
    }
    return null;
  }

  /// Whether this delegation is in force at [now]: not [revoked] and within the
  /// `[validFrom, validTo]` window (each bound optional and inclusive).
  bool isActiveAt(DateTime now) {
    if (revoked) return false;
    if (validFrom != null && now.isBefore(validFrom!)) return false;
    if (validTo != null && now.isAfter(validTo!)) return false;
    return true;
  }

  /// The canonical DDL for the `tom_principal_delegation` table.
  ///
  /// Shipped verbatim as the reference `db_migration` script, so the two cannot
  /// drift — `test/reference_migrations_test.dart` fails if they do.
  ///
  /// The delegate index covers `(delegate_id, revoked)` because that is the
  /// selective part of the lookup: revocation is a flag rather than a delete,
  /// so a delegate accumulates dead rows for life and the index has to keep
  /// them off the read. The window columns are deliberately *not* in it — the
  /// bounds are tested as `valid_from IS NULL OR valid_from <= :at`, and that
  /// shape is not usable as an index range.
  ///
  /// The window columns are `DATETIME(6)`, the width the instant convention
  /// (`datasources/sql_instant.dart`) writes. A plain `DATETIME` rounds each
  /// bound to the second, which puts the edge of a security window up to half a
  /// second away from the one its owner set.
  static const String createTableSql = '''
CREATE TABLE IF NOT EXISTS tom_principal_delegation (
  id BIGINT NOT NULL AUTO_INCREMENT,
  delegator_id VARCHAR(255) NOT NULL,
  delegate_id VARCHAR(255) NOT NULL,
  mode VARCHAR(32) NOT NULL,
  resource_key VARCHAR(255) NULL,
  role VARCHAR(255) NULL,
  valid_from DATETIME(6) NULL,
  valid_to DATETIME(6) NULL,
  revoked TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_tom_principal_delegation_delegate (delegate_id, revoked)
);''';

  @override
  String toString() =>
      'TomPrincipalDelegation($delegatorId -> $delegateId, $mode'
      '${resourceKey == null ? '' : ', resource=$resourceKey'}'
      '${role == null ? '' : ', role=$role'}'
      '${validFrom == null && validTo == null ? '' : ', [$validFrom, $validTo]'}'
      '${revoked ? ', REVOKED' : ''})';
}

/// The delegation-lookup seam the [TomDelegationResolver] reads through.
///
/// The resolver needs only the delegation rows *targeting* one delegate. Behind
/// a one-method interface this runs against the live repository at boot and a
/// seeded in-memory store under test, with identical resolution on both.
abstract class PrincipalDelegationStore {
  /// Returns the delegations targeting [delegateId] that are **in force at**
  /// [at] — i.e. those [TomPrincipalDelegation.isActiveAt] admits. Empty when
  /// none target the delegate, or none of theirs is live at that instant (they
  /// then inherit no delegated roles).
  ///
  /// The instant is a parameter rather than something the caller filters on
  /// afterwards so that an implementation can answer the question where the
  /// rows are. Revocation is a flag, not a delete, so a delegate's row count
  /// grows with their whole delegation *history*; loading it to discard most of
  /// it makes every request pay for that history.
  Future<List<TomPrincipalDelegation>> activeDelegationsForDelegate(
    String delegateId,
    DateTime at,
  );
}

/// Resolves the roles a delegate receives via C-6 delegation and merges them
/// with the delegate's own C-5 direct grants.
///
/// It composes the C-5 [TomPrincipalResourceRoleResolver]: `share` delegations
/// contribute their explicit `(resourceKey, role)`, while `absence`/`intentional`
/// delegations resolve the **delegator's** direct roles (never the delegator's
/// own delegated roles — delegation is not transitive) and lend them, optionally
/// narrowed to one resource and/or overridden to one role. All contributions are
/// folded under C-5's strength ordering.
class TomDelegationResolver {
  /// The store active delegations are read through.
  final PrincipalDelegationStore delegationStore;

  /// Resolves a delegator's (and the delegate's own) direct C-5 roles.
  final TomPrincipalResourceRoleResolver directResolver;

  /// Ranks two competing roles on one resource, returning the stronger. Defaults
  /// to the same registry-backed ordering the direct resolver uses, so direct
  /// and delegated roles collapse consistently.
  final String Function(String a, String b) strongerRole;

  /// Builds the resolver over the [delegationStore] and the C-5 [directResolver].
  /// [strongerRole] defaults to [TomPrincipalResourceRoleResolver.registryStrength].
  TomDelegationResolver(
    this.delegationStore,
    this.directResolver, {
    String Function(String a, String b)? strongerRole,
  }) : strongerRole =
           strongerRole ?? TomPrincipalResourceRoleResolver.registryStrength;

  /// Resolves the `resourceKey → roleName` map [delegateId] receives purely via
  /// delegations active at [at]. Empty when no active delegation targets them.
  ///
  /// Costs one grant read per *distinct delegator* named by the active rows, not
  /// one per row: lending several resources means one row each, so a delegator
  /// who lends four resources appears four times and their grants are read once.
  /// The reuse lasts exactly this call — it is a way of not asking the same
  /// question twice in one resolution, not a cache, and nothing it holds
  /// survives to be served stale to the next one. (Amortising across a whole
  /// request is [TomResourceDataScope.runCached]'s job, one layer up.)
  Future<Map<String, String>> resolveDelegatedRoles(
    String delegateId,
    DateTime at,
  ) async {
    final delegations = await delegationStore.activeDelegationsForDelegate(
      delegateId,
      at,
    );
    final delegatorRoles = <String, Future<Map<String, String>>>{};
    final entries = <MapEntry<String, String>>[];
    for (final delegation in delegations) {
      // The store already promises only live rows, and both shipped stores keep
      // that promise. The re-check stays because this is the gate a revoked
      // delegation has to fail: the store is an open seam, and a deployment
      // whose implementation forgets the predicate should lose the delegation,
      // not silently keep granting it.
      if (!delegation.isActiveAt(at)) continue;
      entries.addAll(await _entriesFor(delegation, delegatorRoles));
    }
    return TomPrincipalResourceRoleResolver.foldRoles(entries, strongerRole);
  }

  /// The effective `resourceKey → roleName` map for [principalId] at [at]: their
  /// C-5 direct grants merged with every role delegated to them, folded to the
  /// stronger role per resource.
  Future<Map<String, String>> resolveEffectiveRoles(
    String principalId,
    DateTime at,
  ) async {
    final direct = await directResolver.resolveResourceRoles(principalId);
    final delegated = await resolveDelegatedRoles(principalId, at);
    return TomPrincipalResourceRoleResolver.foldRoles([
      ...direct.entries,
      ...delegated.entries,
    ], strongerRole);
  }

  /// Convenience: resolve [principalId]'s effective roles at [at] and wrap them
  /// in a kernel [TomResourceRoleAdapter] ready to install on [TomAuthorization]
  /// or query directly for server-side enforcement.
  Future<TomResourceRoleAdapter> resolveAdapter(
    String principalId,
    DateTime at,
  ) async =>
      TomResourceRoleAdapter(await resolveEffectiveRoles(principalId, at));

  /// The `resourceKey → roleName` entries one active [delegation] contributes.
  ///
  /// [delegatorRoles] memoises the delegator grant reads for the enclosing
  /// [resolveDelegatedRoles] call; it holds the pending future rather than the
  /// resolved map, so a delegator named by two rows shares one read whether or
  /// not the first has landed.
  Future<Iterable<MapEntry<String, String>>> _entriesFor(
    TomPrincipalDelegation delegation,
    Map<String, Future<Map<String, String>>> delegatorRoles,
  ) async {
    switch (delegation.delegationMode) {
      case TomDelegationMode.share:
        // A share needs both an explicit resource and role; a malformed share
        // (either missing) contributes nothing.
        final resourceKey = delegation.resourceKey;
        final role = delegation.role;
        if (resourceKey == null || role == null) return const [];
        return [MapEntry(resourceKey, role)];
      case TomDelegationMode.absence:
      case TomDelegationMode.intentional:
        // Inherit the delegator's own direct roles (not their delegated ones:
        // delegation is not transitive), optionally narrowed to one resource
        // and/or overridden to a single role.
        final inherited = await delegatorRoles.putIfAbsent(
          delegation.delegatorId,
          () => directResolver.resolveResourceRoles(delegation.delegatorId),
        );
        return [
          for (final entry in inherited.entries)
            if (delegation.resourceKey == null ||
                delegation.resourceKey == entry.key)
              MapEntry(entry.key, delegation.role ?? entry.value),
        ];
      case null:
        // Unknown/blank mode delegates nothing (closed/safe).
        return const [];
    }
  }
}

/// The query-backed [PrincipalDelegationStore] wired at boot.
///
/// Reads through a [TomPrincipalDelegation] repository over the `main`
/// datasource. Requires a live connection and the reflection runtime, so it is
/// exercised end-to-end (unit tests use [InMemoryPrincipalDelegationStore]).
class RepositoryPrincipalDelegationStore implements PrincipalDelegationStore {
  /// The repository the store reads delegation rows through.
  final TomSqlDatasourceRepository<TomPrincipalDelegation, int> repository;

  /// Builds the store over [repository].
  const RepositoryPrincipalDelegationStore(this.repository);

  /// The query sentence [activeDelegationsForDelegate] runs — the SQL
  /// expression of [TomPrincipalDelegation.isActiveAt].
  ///
  /// Each window bound admits `NULL` explicitly because `null` means *unbounded
  /// on that side*, and SQL's three-valued logic answers `NULL <= :at` with
  /// unknown rather than true — a bare comparison would silently drop every
  /// open-ended delegation, which is most of them.
  ///
  /// Only the two window bounds are bracketed. The sentence compiler builds
  /// `AND`/`OR` right-recursively, so an `OR` written bare among the conjuncts
  /// would take everything after it as its right-hand side and the sentence
  /// would mean something else; the brackets say where each alternation ends.
  /// The three comparisons need none — each ends at its own operand.
  ///
  /// A named constant rather than a literal at the call site so a test can
  /// compile *this* sentence and inspect the SQL, instead of a copy that would
  /// go on passing after the real one changed.
  static const String activeDelegationsQuery =
      'FIND BY delegate_id = :delegateId AND revoked = :revoked '
      'AND ( valid_from IS NULL OR valid_from <= :at ) '
      'AND ( valid_to IS NULL OR valid_to >= :at )';

  @override
  Future<List<TomPrincipalDelegation>> activeDelegationsForDelegate(
    String delegateId,
    DateTime at,
  ) async {
    final matches = await repository.findByQuerySentence(
      activeDelegationsQuery,
      {'delegateId': delegateId, 'revoked': false, 'at': at},
    );
    return matches.toList();
  }
}

/// A seeded, database-free [PrincipalDelegationStore] for tests.
///
/// Holds the delegation rows directly, so a test can assert resolution at
/// chosen timestamps without a connection or reflection. Applies the same two
/// filters the repository store pushes into SQL — the delegate, and
/// [TomPrincipalDelegation.isActiveAt] — so a test seeing rows here sees what a
/// database would have returned.
class InMemoryPrincipalDelegationStore implements PrincipalDelegationStore {
  final List<TomPrincipalDelegation> _delegations;

  /// Seeds the store with the full set of [delegations] across all delegates.
  InMemoryPrincipalDelegationStore(List<TomPrincipalDelegation> delegations)
    : _delegations = delegations;

  @override
  Future<List<TomPrincipalDelegation>> activeDelegationsForDelegate(
    String delegateId,
    DateTime at,
  ) async => [
    for (final d in _delegations)
      if (d.delegateId == delegateId && d.isActiveAt(at)) d,
  ];
}
