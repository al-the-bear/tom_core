/// Database-free tests for the share endpoints (step 21): the [AppShareService]
/// composes the step-17 [ResourceAccessResolver] over a seeded in-memory share
/// store, so the whole `POST /share` / `DELETE /share/{id}` owner-only path —
/// and the headline "a created share immediately grants the grantee access" bar
/// — verifies with no server or MariaDB.
///
/// The fixture mirrors §A.10 (workspace 1 owned by alice=2) and the prior steps'
/// seeds: bob=3 starts as an `editor` shared on project 1; carol=4 holds no
/// share; dave=99 is a stranger. The share service writes a [ShareRecord], and
/// because the resolver reads exactly those rows, feeding the persisted share
/// back into an [InMemoryAppResourceStore] proves the grant is effective on the
/// grantee's very next request.
///
/// Shares and persistence records are plain classes, so this suite needs no
/// reflection and no live registry.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

// Auth user ids, mirroring the auth seed.
const int alice = 2; // workspace owner
const int bob = 3; // editor, shared on project 1
const int carol = 4; // no share — a candidate grantee
const int dave = 99; // stranger — owns nothing, shares nothing

// The §A.10 demo records. Fresh instances per call so each store holds its own
// independent (but equal) copy.
List<WorkspaceRecord> demoWorkspaces() => [WorkspaceRecord()..id = 1..ownerId = alice];
List<ProjectRecord> demoProjects() => [ProjectRecord()..id = 1..workspaceId = 1];
List<ListRecord> demoLists() => [ListRecord()..id = 1..projectId = 1];
List<ItemRecord> demoItems() => [ItemRecord()..id = 1..listId = 1];

/// The single pre-existing share: bob is an `editor` on project 1.
List<ShareRecord> demoShares() => [
      ShareRecord()
        ..id = 1
        ..resourceType = AppResourceTypes.project
        ..resourceId = 1
        ..granteeUserId = bob
        ..projectRole = ProjectRole.editor.name
        ..grantedById = alice,
    ];

/// A share service over a caller-supplied [shareStore] (so a test can inspect
/// what was persisted) and a resolver seeded from the same share rows.
AppShareService shareServiceOver(InMemoryAppShareStore shareStore) =>
    AppShareService(
      shareStore,
      ResourceAccessResolver(InMemoryAppResourceStore(
        workspaces: demoWorkspaces(),
        projects: demoProjects(),
        lists: demoLists(),
        items: demoItems(),
        shares: shareStore.shares,
      )),
    );

/// A resolver reading exactly the rows in [shares] — used to prove a freshly
/// persisted share is effective.
ResourceAccessResolver resolverOver(List<ShareRecord> shares) =>
    ResourceAccessResolver(InMemoryAppResourceStore(
      workspaces: demoWorkspaces(),
      projects: demoProjects(),
      lists: demoLists(),
      items: demoItems(),
      shares: shares,
    ));

void main() {
  group('share (POST /share) — owner-only', () {
    test('the owner shares a project; the persisted row records the grant',
        () async {
      final store = InMemoryAppShareStore(shares: demoShares());
      await shareServiceOver(store).share(
        alice,
        const ShareRequest(
          resourceType: AppResourceTypes.project,
          resourceId: '1',
          granteeUserId: '$carol',
          projectRole: ProjectRole.commenter,
        ),
      );

      final saved = store.shares.firstWhere((s) => s.granteeUserId == carol);
      expect(saved.id, isNotNull); // surrogate key assigned
      expect(saved.resourceType, AppResourceTypes.project);
      expect(saved.resourceId, 1);
      expect(saved.projectRole, ProjectRole.commenter.name);
      expect(saved.grantedById, alice); // the sharer is recorded as the grantor
    });

    test('a created share immediately grants the grantee access (the step-21 Done bar)',
        () async {
      final store = InMemoryAppShareStore(shares: demoShares());
      // carol has no role on project 1 to begin with.
      expect(
        await resolverOver(store.shares).resolveRole(
          userId: carol,
          resourceType: AppResourceTypes.project,
          resourceId: 1,
        ),
        isNull,
      );

      await shareServiceOver(store).share(
        alice,
        const ShareRequest(
          resourceType: AppResourceTypes.project,
          resourceId: '1',
          granteeUserId: '$carol',
          projectRole: ProjectRole.editor,
        ),
      );

      // The very next resolve over the now-persisted rows sees the grant.
      expect(
        await resolverOver(store.shares).resolveRole(
          userId: carol,
          resourceType: AppResourceTypes.project,
          resourceId: 1,
        ),
        ProjectRole.editor,
      );
    });

    test('a non-owner editor may not share (forbidden)', () async {
      final store = InMemoryAppShareStore(shares: demoShares());
      await expectLater(
        () => shareServiceOver(store).share(
          bob, // editor on project 1, not its owner
          const ShareRequest(
            resourceType: AppResourceTypes.project,
            resourceId: '1',
            granteeUserId: '$carol',
            projectRole: ProjectRole.viewer,
          ),
        ),
        throwsA(isA<TomEndpointHandlerException>()
            .having((e) => e.key, 'key', 'app.access.forbidden')),
      );
      // Nothing was persisted beyond the seed.
      expect(store.shares, hasLength(1));
    });

    test('a stranger may not share (forbidden, not leaked as missing)',
        () async {
      final store = InMemoryAppShareStore(shares: demoShares());
      await expectLater(
        () => shareServiceOver(store).share(
          dave,
          const ShareRequest(
            resourceType: AppResourceTypes.project,
            resourceId: '1',
            granteeUserId: '$carol',
            projectRole: ProjectRole.viewer,
          ),
        ),
        throwsA(isA<TomEndpointHandlerException>()
            .having((e) => e.key, 'key', 'app.access.forbidden')),
      );
      expect(store.shares, hasLength(1));
    });

    test('a non-numeric resource or grantee id is rejected as invalid',
        () async {
      final store = InMemoryAppShareStore(shares: demoShares());
      await expectLater(
        () => shareServiceOver(store).share(
          alice,
          const ShareRequest(
            resourceType: AppResourceTypes.project,
            resourceId: 'not-a-number',
            granteeUserId: '$carol',
            projectRole: ProjectRole.viewer,
          ),
        ),
        throwsA(isA<TomEndpointHandlerException>()
            .having((e) => e.key, 'key', 'app.share.invalid')),
      );
      expect(store.shares, hasLength(1));
    });
  });

  group('revokeShare (DELETE /share/{id}) — owner-only', () {
    test('the owner revokes a share; the row is deleted', () async {
      final store = InMemoryAppShareStore(shares: demoShares());
      await shareServiceOver(store).revokeShare(alice, 1);
      expect(store.shares, isEmpty);
    });

    test('revoking removes the grantee\'s access', () async {
      final store = InMemoryAppShareStore(shares: demoShares());
      // bob has editor access via share 1.
      expect(
        await resolverOver(store.shares).resolveRole(
          userId: bob,
          resourceType: AppResourceTypes.project,
          resourceId: 1,
        ),
        ProjectRole.editor,
      );

      await shareServiceOver(store).revokeShare(alice, 1);

      expect(
        await resolverOver(store.shares).resolveRole(
          userId: bob,
          resourceType: AppResourceTypes.project,
          resourceId: 1,
        ),
        isNull,
      );
    });

    test('a non-owner may not revoke (forbidden)', () async {
      final store = InMemoryAppShareStore(shares: demoShares());
      await expectLater(
        () => shareServiceOver(store).revokeShare(bob, 1),
        throwsA(isA<TomEndpointHandlerException>()
            .having((e) => e.key, 'key', 'app.access.forbidden')),
      );
      expect(store.shares, hasLength(1)); // untouched
    });

    test('revoking an unknown share is reported as not found (closed/safe)',
        () async {
      final store = InMemoryAppShareStore(shares: demoShares());
      await expectLater(
        () => shareServiceOver(store).revokeShare(alice, 999),
        throwsA(isA<TomEndpointHandlerException>()
            .having((e) => e.key, 'key', 'app.share.not_found')),
      );
      expect(store.shares, hasLength(1));
    });
  });

  group('appForbiddenOrNotFound — the server-level status mapping', () {
    final request = Request('post', Uri.parse('http://localhost/share'));

    test('denial keys map to 403', () {
      for (final key in [
        'app.access.forbidden',
        'app.item.field_forbidden',
        appEndpointAccessDeniedKey,
      ]) {
        final response = appForbiddenOrNotFound(
          request,
          TomEndpointHandlerException(key, 'denied'),
          StackTrace.current,
        );
        expect(response?.statusCode, 403, reason: key);
      }
    });

    test('not-found keys map to 404', () {
      for (final key in ['app.item.not_found', 'app.share.not_found']) {
        final response = appForbiddenOrNotFound(
          request,
          TomEndpointHandlerException(key, 'missing'),
          StackTrace.current,
        );
        expect(response?.statusCode, 404, reason: key);
      }
    });

    test('an unmapped error falls through to the framework default (null)', () {
      expect(
        appForbiddenOrNotFound(
          request,
          TomEndpointHandlerException('app.share.invalid', 'bad'),
          StackTrace.current,
        ),
        isNull,
      );
      expect(
        appForbiddenOrNotFound(request, StateError('boom'), StackTrace.current),
        isNull,
      );
    });
  });
}
