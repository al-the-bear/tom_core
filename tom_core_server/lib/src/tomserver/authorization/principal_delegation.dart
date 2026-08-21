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

import '../datasources/types_operator.dart';
import '../object_persistence/persistence_annotations.dart';
import '../object_persistence/crud_repository.dart';
import 'principal_resource_grant.dart';

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
@TomDbTable(
  datasource: 'main',
  table: 'tom_principal_delegation',
  primaryKeyField: 'id',
)
// Authorization metadata: the delegation rows feed the row scope and so must
// not be filtered by it (see [TomPrincipalResourceGrant]). A delegation's
// `resource_key` names the resource being shared, not the resource the *row*
// belongs to, which is a second reason the automatic scope would be wrong here.
@TomDbScope.unscoped()
class TomPrincipalDelegation {
  /// Surrogate primary key (`-1` until persisted).
  @TomEntityId()
  @TomDbColumn<int, TomDbInt>(columnName: 'id', isReadOnly: true)
  int id;

  /// The principal whose roles are lent (A, the delegator).
  @TomDbColumn<String, TomDbString>(columnName: 'delegator_id')
  String delegatorId;

  /// The principal receiving the lent roles (B, the delegate).
  @TomDbColumn<String, TomDbString>(columnName: 'delegate_id')
  String delegateId;

  /// The delegation mode, stored as the [TomDelegationMode] name.
  @TomDbColumn<String, TomDbString>(columnName: 'mode')
  String mode;

  /// For `share` the resource shared; for `absence`/`intentional` an optional
  /// single resource to narrow the inherited roles to (`null` = all of the
  /// delegator's resources).
  @TomDbColumn<String?, TomDbString>(columnName: 'resource_key')
  String? resourceKey;

  /// For `share` the role granted on [resourceKey]; for `absence`/`intentional`
  /// an optional override applied to every inherited resource (`null` = inherit
  /// the delegator's own role on each resource).
  @TomDbColumn<String?, TomDbString>(columnName: 'role')
  String? role;

  /// Inclusive window start; `null` = unbounded (active from any past time).
  @TomDbColumn<DateTime?, TomDbDateTime>(columnName: 'valid_from')
  DateTime? validFrom;

  /// Inclusive window end; `null` = unbounded (never expires by time).
  @TomDbColumn<DateTime?, TomDbDateTime>(columnName: 'valid_to')
  DateTime? validTo;

  /// Manual kill-switch: a revoked delegation is inactive at every timestamp.
  @TomDbColumn<bool, TomDbBool>(columnName: 'revoked')
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
  static const String createTableSql = '''
CREATE TABLE IF NOT EXISTS tom_principal_delegation (
  id BIGINT NOT NULL AUTO_INCREMENT,
  delegator_id VARCHAR(255) NOT NULL,
  delegate_id VARCHAR(255) NOT NULL,
  mode VARCHAR(32) NOT NULL,
  resource_key VARCHAR(255) NULL,
  role VARCHAR(255) NULL,
  valid_from DATETIME NULL,
  valid_to DATETIME NULL,
  revoked TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_tom_principal_delegation_delegate (delegate_id)
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
  /// Returns every delegation whose delegate is [delegateId]. Empty when none
  /// target the delegate (they then inherit no delegated roles).
  Future<List<TomPrincipalDelegation>> delegationsForDelegate(
    String delegateId,
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
  Future<Map<String, String>> resolveDelegatedRoles(
    String delegateId,
    DateTime at,
  ) async {
    final delegations = await delegationStore.delegationsForDelegate(
      delegateId,
    );
    final entries = <MapEntry<String, String>>[];
    for (final delegation in delegations) {
      if (!delegation.isActiveAt(at)) continue;
      entries.addAll(await _entriesFor(delegation));
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
  Future<Iterable<MapEntry<String, String>>> _entriesFor(
    TomPrincipalDelegation delegation,
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
        final inherited = await directResolver.resolveResourceRoles(
          delegation.delegatorId,
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

  @override
  Future<List<TomPrincipalDelegation>> delegationsForDelegate(
    String delegateId,
  ) async {
    final matches = await repository.findByQuerySentence(
      'FIND BY delegate_id = :delegateId',
      {'delegateId': delegateId},
    );
    return matches.toList();
  }
}

/// A seeded, database-free [PrincipalDelegationStore] for tests.
///
/// Holds the delegation rows directly and filters by delegate id, so a test can
/// assert resolution at chosen timestamps without a connection or reflection.
class InMemoryPrincipalDelegationStore implements PrincipalDelegationStore {
  final List<TomPrincipalDelegation> _delegations;

  /// Seeds the store with the full set of [delegations] across all delegates.
  InMemoryPrincipalDelegationStore(List<TomPrincipalDelegation> delegations)
    : _delegations = delegations;

  @override
  Future<List<TomPrincipalDelegation>> delegationsForDelegate(
    String delegateId,
  ) async => [
    for (final d in _delegations)
      if (d.delegateId == delegateId) d,
  ];
}
