/// Persistence + write seam for cross-user shares, expressed as framework C-6
/// `share`-mode delegations (RCC3).
///
/// A share is exactly "principal A lends principal B a named role on a named
/// resource" — a [TomPrincipalDelegation] in [TomDelegationMode.share]. RCC3
/// retires the bespoke `ShareRecord` + `app_shares` table: shares are now
/// [TomPrincipalDelegation] rows on the framework `tom_principal_delegation`
/// table (datasource `main`, bound to the shared `auth_db` connection at boot),
/// resolved through the framework [TomDelegationResolver] alongside the C-5
/// ownership grants (RCC1). That leaves **one** enforcement path — the framework
/// resolver — with no parallel share scheme.
///
/// Writes sit behind a [ShareDelegationStore] seam so `AppShareService` is pure
/// over whichever store it is handed: [RepositoryShareDelegationStore] is the
/// live query-backed store wired at boot; [InMemoryShareDelegationStore] is a
/// seeded, database-free store the share tests drive — and, because it *also*
/// implements the framework read seam [PrincipalDelegationStore], the same
/// instance can be handed to a [TomDelegationResolver] to prove a written share
/// takes effect immediately (the step-21 "Done" bar, RCC3-migrated).
library;

import 'package:tom_core_server/tom_core_server.dart';

/// Repository for the framework's [TomPrincipalDelegation] table
/// (`tom_principal_delegation`, datasource `main`).
///
/// Mirrors `PrincipalResourceGrantRepository`: the delegation table is owned by
/// `tom_core_server` on the framework default `main` datasource, which the
/// app-server boot binds against the shared `auth_db` connection — so this
/// singleton writes the share delegations the app server's own enforcement then
/// reads back through [TomDelegationResolver].
class PrincipalDelegationRepository
    extends TomSqlDatasourceRepository<TomPrincipalDelegation, int> {}

/// Process-wide singleton principal-delegation repository.
final principalDelegationRepository = PrincipalDelegationRepository();

/// The share-write seam the `AppShareService` persists and revokes shares
/// through.
///
/// Three methods — save a new share delegation, load one by id (to authorize a
/// revoke against the share's own target), and delete it. Behind a small
/// interface the service runs against the live repository at boot and a seeded
/// store under test, with identical call sites on both.
abstract class ShareDelegationStore {
  /// Inserts (assigning a surrogate key) or updates [delegation], returning the
  /// saved row (an insert carries the assigned key).
  Future<TomPrincipalDelegation> saveShare(TomPrincipalDelegation delegation);

  /// Returns the delegation row for [id], or `null` when it does not exist.
  Future<TomPrincipalDelegation?> findDelegation(int id);

  /// Deletes the delegation row with [id].
  Future<void> deleteDelegation(int id);
}

/// The query-backed [ShareDelegationStore] wired at boot.
///
/// Writes through the [principalDelegationRepository] singleton over the `main`
/// datasource (bound to `auth_db`). Requires a live connection and the
/// reflection runtime, so it is exercised end-to-end (unit tests use
/// [InMemoryShareDelegationStore]).
class RepositoryShareDelegationStore implements ShareDelegationStore {
  /// Creates the repository-backed store (stateless; reads the singleton).
  const RepositoryShareDelegationStore();

  @override
  Future<TomPrincipalDelegation> saveShare(TomPrincipalDelegation delegation) =>
      principalDelegationRepository.save(delegation);

  @override
  Future<TomPrincipalDelegation?> findDelegation(int id) =>
      principalDelegationRepository.findById(id);

  @override
  Future<void> deleteDelegation(int id) =>
      principalDelegationRepository.deleteById(id);
}

/// A seeded, database-free store that is both the [ShareDelegationStore] write
/// seam and the framework [PrincipalDelegationStore] read seam.
///
/// Holds the delegation rows directly and assigns a surrogate key on insert
/// (`id <= 0`). The [delegations] getter lets a test assert the persisted share;
/// implementing [activeDelegationsForDelegate] lets the *same* instance feed a
/// [TomDelegationResolver], proving a newly written share immediately grants the
/// grantee access — with no connection or reflection.
class InMemoryShareDelegationStore
    implements ShareDelegationStore, PrincipalDelegationStore {
  final List<TomPrincipalDelegation> _delegations;

  int _nextId = 1;

  /// Seeds the store with the given rows (defaults to empty); the auto-increment
  /// counter advances past any seeded ids.
  InMemoryShareDelegationStore({
    List<TomPrincipalDelegation> delegations = const [],
  }) : _delegations = [...delegations] {
    _nextId =
        _delegations.fold<int>(0, (max, d) => d.id > max ? d.id : max) + 1;
  }

  /// The persisted delegation rows (test introspection).
  List<TomPrincipalDelegation> get delegations => List.unmodifiable(_delegations);

  @override
  Future<TomPrincipalDelegation> saveShare(
    TomPrincipalDelegation delegation,
  ) async {
    if (delegation.id <= 0) {
      delegation.id = _nextId++;
      _delegations.add(delegation);
    } else {
      final index = _delegations.indexWhere((d) => d.id == delegation.id);
      if (index >= 0) {
        _delegations[index] = delegation;
      } else {
        _delegations.add(delegation);
      }
    }
    return delegation;
  }

  @override
  Future<TomPrincipalDelegation?> findDelegation(int id) async {
    for (final delegation in _delegations) {
      if (delegation.id == id) return delegation;
    }
    return null;
  }

  @override
  Future<void> deleteDelegation(int id) async =>
      _delegations.removeWhere((d) => d.id == id);

  /// Applies both filters the live store pushes into SQL — the delegate and
  /// [TomPrincipalDelegation.isActiveAt] — so a revoked or out-of-window share
  /// stops being returned here exactly as it stops being selected there.
  @override
  Future<List<TomPrincipalDelegation>> activeDelegationsForDelegate(
    String delegateId,
    DateTime at,
  ) async => [
    for (final d in _delegations)
      if (d.delegateId == delegateId && d.isActiveAt(at)) d,
  ];
}
