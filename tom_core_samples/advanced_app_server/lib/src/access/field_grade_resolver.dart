/// Field-level grade resolution: given a principal's effective [ProjectRole]
/// (from the resource-access resolver), load that role's
/// [TomResourceGrant]s and fold them into the per-field [TomAuthState] grades
/// the server enforces against.
///
/// This is the app server's **second** authorization layer. The first
/// (resource access) answers "*may this principal touch this object, and as what
/// role?*"; this one answers "*for that role, which fields may they see/edit?*"
/// by resolving each gradable [TodoItem] field key to one of `full` / `read` /
/// `disabled` / `none`.
///
/// These grades are **enforcement, not rendering.**
/// `AppWriteService._enforceFieldWrites` rejects a write that changes any field
/// the caller is not `full` on, and `ItemAttachmentGradeResolver` grades an
/// item's file column the same way for `saveFile` / `openFile` / `describeFile`.
/// No JSON read endpoint resolves them at all: `AppReadService` holds no
/// [FieldGradeResolver].
///
/// The client never receives them either: it grades its own form fields
/// locally, from the flat `resourceKey → roleName` map it fetches once at
/// login folded against the shared domain's [projectRoleFieldGrades]. So the
/// matrix exists twice, and the duality is deliberate: the client's copy is
/// cooperation, this one is the decision. The two must *start* equal —
/// `advanced_auth_server`'s `grant_matrix_key_consistency_test.dart` pins the
/// seed SQL to that map offline, so changing a grade on one side alone fails
/// there — but only this copy moves when an administrator edits a grant, and
/// only this copy can refuse a tampered client.
///
/// The grant matrix is **data**, owned by the auth server's `auth_db`
/// `tom_resource_grant` table and managed through the authadmin client. The app
/// server reaches it through the framework's `main` datasource (the app's own
/// records live on the named `app_db` datasource, so `main` is free to bind the
/// shared grant table at boot). Folding reuses the framework
/// [TomGradedAccessControlInformation.fromGrants] verbatim — the same projection
/// the auth server's admin API uses — so the two agree on grade semantics
/// (most-permissive `widen` when a key is granted more than once).
///
/// Reads sit behind a [GrantStore] seam so the resolver is pure over whichever
/// store it is handed: [RepositoryGrantStore] is the live query-backed store
/// wired at boot; [InMemoryGrantStore] is a seeded store for tests
/// ([projectRoleFieldGrades] reproduced for each role with no database).
library;

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// Repository for the framework's [TomResourceGrant] table (`tom_resource_grant`).
///
/// The grant table is owned by `tom_core_server` (datasource `main`). The app
/// server's own records live on the named `app_db` datasource, so the app-server
/// boot binds `main` against the shared `auth_db` connection and this singleton
/// reads the grant rows the auth server seeded.
class GrantRepository
    extends TomSqlDatasourceRepository<TomResourceGrant, int> {}

/// Process-wide singleton grant repository.
final grantRepository = GrantRepository();

/// The grant-lookup seam the [FieldGradeResolver] reads through.
///
/// The resolver needs only the grant rows for a single role. Putting that read
/// behind a one-method interface lets it run against the live repository at boot
/// and a seeded in-memory store under test, with identical folding on both.
abstract class GrantStore {
  /// Returns every grant for [roleName]. Empty when the role has no grant rows
  /// (every gradable field then resolves to [TomAuthState.none] — closed/safe).
  Future<List<TomResourceGrant>> grantsForRole(String roleName);
}

/// The domain's gradable item keys, under a name the constructor's parameter
/// does not shadow.
const List<String> _domainGradableItemKeys = gradableItemKeys;

/// Resolves a [ProjectRole] to its per-field [TomAuthState] grades.
class FieldGradeResolver {
  /// The store the resolver loads grant rows through.
  final GrantStore store;

  /// The gradable `todo.item.<field>` keys the resolver reports a [TomAuthState]
  /// for, in display order. Defaults to the shared domain's `gradableItemKeys`
  /// — the one declaration every tier resolves grades over; tests and the
  /// attachment resolver inject an explicit set.
  final List<String> gradableItemKeys;

  /// Builds the resolver over [store] (the live repository at boot, a seeded
  /// store under test). [gradableItemKeys] defaults to the domain's set.
  FieldGradeResolver(this.store, {List<String>? gradableItemKeys})
    : gradableItemKeys = gradableItemKeys ?? _domainGradableItemKeys;

  /// Loads [role]'s grants and folds them into a graded view. Several rows for
  /// the same key widen to the most permissive grade (the framework default).
  Future<TomGradedAccessControlInformation> gradesForRole(
    ProjectRole role,
  ) async {
    final grants = await store.grantsForRole(role.name);
    return TomGradedAccessControlInformation.fromGrants(grants);
  }

  /// Resolves the per-field [TomAuthState] for every gradable [TodoItem] field
  /// ([gradableItemKeys]) under [role], in display order.
  ///
  /// A field with no grant row degrades to [TomAuthState.none] (hidden) — the
  /// closed/safe default the framework codec falls back to.
  Future<Map<String, TomAuthState>> resolveItemFieldStates(
    ProjectRole role,
  ) async {
    final graded = await gradesForRole(role);
    return {for (final key in gradableItemKeys) key: graded.resolveState(key)};
  }
}

/// The query-backed [GrantStore] wired at boot.
///
/// Reads through the [grantRepository] singleton over the `main` datasource
/// (bound to `auth_db` at boot). Requires a live connection and the reflection
/// runtime, so it is exercised end-to-end (the unit tests use
/// [InMemoryGrantStore]).
class RepositoryGrantStore implements GrantStore {
  /// Creates the repository-backed store (stateless; reads the singleton).
  const RepositoryGrantStore();

  @override
  Future<List<TomResourceGrant>> grantsForRole(String roleName) async {
    final matches = await grantRepository.findByQuerySentence(
      'FIND BY role_name = :roleName',
      {'roleName': roleName},
    );
    return matches.toList();
  }
}

/// A seeded, database-free [GrantStore] for tests (and local scaffolding).
///
/// Holds the grant rows directly and filters by role name, so a test can assert
/// the resolved field-state matrix without a connection or reflection.
class InMemoryGrantStore implements GrantStore {
  final List<TomResourceGrant> _grants;

  /// Seeds the store with the full set of [grants] across all roles.
  InMemoryGrantStore(List<TomResourceGrant> grants) : _grants = grants;

  @override
  Future<List<TomResourceGrant>> grantsForRole(String roleName) async => [
    for (final grant in _grants)
      if (grant.roleName == roleName) grant,
  ];
}
