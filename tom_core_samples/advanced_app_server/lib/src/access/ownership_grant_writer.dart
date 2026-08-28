/// Ownership-grant writes: when a principal creates a resource, record their
/// ownership as a C-5 [TomPrincipalResourceGrant] (`principal:resource -> owner`)
/// in the shared `main`/`auth_db` grant table.
///
/// This is the write half of RCC1's ownership model. Ownership used to be an
/// *implicit* `workspace.owner_id` chain the bespoke resolver once
/// walked; RCC1 makes it an *explicit* owner grant so the login can fold it into
/// [TomAccessControlInformation.resourceRoles] and the app/client resolve
/// resource-level access through the framework registry (C-5, G-AUTHZ-5). All
/// three of [AppWriteService]'s create paths — `createWorkspace`,
/// `createProject` and `createItem` — stamp the grant here after the row is
/// persisted, and the demo seed writes the same shape for the starter tree, so
/// seeded and runtime-created ownership share one representation.
///
/// Writes sit behind an [OwnershipGrantWriter] seam so the write service is pure
/// over whichever writer it is handed: [RepositoryOwnershipGrantWriter] is the
/// live query-backed writer wired at boot; [InMemoryOwnershipGrantWriter] is a
/// recording writer the write-path tests introspect (no database, no reflection).
library;

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// Repository for the framework's [TomPrincipalResourceGrant] table
/// (`tom_principal_resource_grant`, datasource `main`).
///
/// The grant table is owned by `tom_core_server` on the framework default `main`
/// datasource. The app server's own records live on the named `app_db`
/// datasource, so the app-server boot binds `main` against the shared `auth_db`
/// connection and this singleton writes the ownership rows the auth server's
/// login then reads.
class PrincipalResourceGrantRepository
    extends TomSqlDatasourceRepository<TomPrincipalResourceGrant, int> {}

/// Process-wide singleton principal-resource-grant repository.
final principalResourceGrantRepository = PrincipalResourceGrantRepository();

/// The ownership-write seam the [AppWriteService] records ownership through.
///
/// A single method: stamp [principalId] as the [ProjectRole.owner] of the
/// resource identified by [resourceKey] (a `<type>:<id>` key from
/// [ResourceRoleKeys]). Putting the write behind a one-method interface lets the
/// service run against the live repository at boot and a recording store under
/// test, with identical call sites on both.
abstract class OwnershipGrantWriter {
  /// Records [principalId] as the owner of [resourceKey].
  Future<void> recordOwner(String principalId, String resourceKey);
}

/// The query-backed [OwnershipGrantWriter] wired at boot.
///
/// Persists an `owner` grant row through the [principalResourceGrantRepository]
/// singleton over the `main` datasource (bound to `auth_db` at boot). Requires a
/// live connection and the reflection runtime, so it is exercised end-to-end (the
/// unit tests use [InMemoryOwnershipGrantWriter]).
class RepositoryOwnershipGrantWriter implements OwnershipGrantWriter {
  /// Creates the repository-backed writer (stateless; reads the singleton).
  const RepositoryOwnershipGrantWriter();

  @override
  Future<void> recordOwner(String principalId, String resourceKey) async {
    await principalResourceGrantRepository.save(
      TomPrincipalResourceGrant(
        principalId: principalId,
        resourceKey: resourceKey,
        role: ProjectRole.owner.name,
      ),
    );
  }
}

/// A recording, database-free [OwnershipGrantWriter] for tests.
///
/// Holds the ownership grants it is asked to record, so a write-path test can
/// drive a create path through the service and assert the owner grant was
/// stamped for the creator — no connection or reflection.
class InMemoryOwnershipGrantWriter implements OwnershipGrantWriter {
  final List<TomPrincipalResourceGrant> _grants = [];

  /// The ownership grants recorded so far (test introspection).
  List<TomPrincipalResourceGrant> get grants => List.unmodifiable(_grants);

  @override
  Future<void> recordOwner(String principalId, String resourceKey) async {
    _grants.add(
      TomPrincipalResourceGrant(
        principalId: principalId,
        resourceKey: resourceKey,
        role: ProjectRole.owner.name,
      ),
    );
  }
}
