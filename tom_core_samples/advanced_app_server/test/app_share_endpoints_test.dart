/// Database-free tests for the share endpoints: the
/// [AppShareService] composes the [ResourceRoleResolver] over a seeded in-memory
/// share-delegation store, so the whole `POST /share` / `DELETE /share/{id}`
/// owner-only path — and the headline "a created share immediately grants the
/// grantee access" bar — verifies with no server or MariaDB.
///
/// The fixture mirrors the demo seed `[001]-app_demo_seed@dev,test.sql`
/// (workspace 1 owned by alice=2) and the prior steps' seeds: bob=3 starts as
/// an `editor` shared on project 1; carol=4 holds no share; dave=99 is a
/// stranger. A share is now a C-6 `share`-mode
/// [TomPrincipalDelegation]; because the same [InMemoryShareDelegationStore]
/// instance is both the write seam and the framework [PrincipalDelegationStore]
/// read seam, feeding the persisted share back into a [TomDelegationResolver]
/// proves the grant is effective on the grantee's very next request.
///
/// Ownership is a seeded C-5 owner grant; each principal holds at most one
/// role per resource key, so the fold never breaks a per-key tie and the suite
/// needs no reflection and no live role-vocabulary registry.
library;

import 'dart:convert';

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

/// The demo containment tree: project 1 in workspace 1; list 1 in project 1;
/// item 1 in list 1.
InMemoryResourceContainmentStore demoContainment() =>
    InMemoryResourceContainmentStore(
      projects: [
        ProjectRecord()
          ..id = 1
          ..workspaceId = 1,
      ],
      lists: [
        ListRecord()
          ..id = 1
          ..projectId = 1,
      ],
      items: [
        ItemRecord()
          ..id = 1
          ..listId = 1,
      ],
    );

/// Alice owns the whole tree via a single workspace-level owner grant.
List<TomPrincipalResourceGrant> demoGrants() => [
  TomPrincipalResourceGrant(
    principalId: '$alice',
    resourceKey: ResourceRoleKeys.workspace('1'),
    role: ProjectRole.owner.name,
  ),
];

/// The single pre-existing share: bob is an `editor` on project 1.
List<TomPrincipalDelegation> demoShares() => [
  TomPrincipalDelegation(
    id: 1,
    mode: TomDelegationMode.share.name,
    delegatorId: '$alice',
    delegateId: '$bob',
    resourceKey: ResourceRoleKeys.project('1'),
    role: ProjectRole.editor.name,
  ),
];

/// A resolver reading the delegation rows in [delegations] plus the demo
/// ownership grants — used to prove a freshly persisted share is effective.
ResourceRoleResolver resolverOver(PrincipalDelegationStore delegations) =>
    ResourceRoleResolver(
      demoContainment(),
      TomDelegationResolver(
        delegations,
        TomPrincipalResourceRoleResolver(
          InMemoryPrincipalResourceGrantStore(demoGrants()),
        ),
      ),
    );

/// A share service over a caller-supplied [store] (so a test can inspect what
/// was persisted) and a resolver reading the same delegation rows.
AppShareService shareServiceOver(InMemoryShareDelegationStore store) =>
    AppShareService(store, resolverOver(store));

void main() {
  group('share (POST /share) — owner-only', () {
    test(
      'the owner shares a project; the persisted row records the grant',
      () async {
        final store = InMemoryShareDelegationStore(delegations: demoShares());
        await shareServiceOver(store).share(
          alice,
          ShareRequest(
            resourceType: AppResourceTypes.project,
            resourceId: '1',
            granteeUserId: '$carol',
            projectRole: ProjectRole.commenter,
          ),
        );

        final saved = store.delegations.firstWhere(
          (d) => d.delegateId == '$carol',
        );
        expect(saved.id, greaterThan(0)); // surrogate key assigned
        expect(saved.mode, TomDelegationMode.share.name);
        expect(saved.resourceKey, ResourceRoleKeys.project('1'));
        expect(saved.role, ProjectRole.commenter.name);
        expect(
          saved.delegatorId,
          '$alice',
        ); // the sharer is recorded as delegator
      },
    );

    test('a created share immediately grants the grantee access', () async {
      final store = InMemoryShareDelegationStore(delegations: demoShares());
      // carol has no role on project 1 to begin with.
      expect(
        await resolverOver(store).resolveRole(
          userId: carol,
          resourceType: AppResourceTypes.project,
          resourceId: 1,
        ),
        isNull,
      );

      await shareServiceOver(store).share(
        alice,
        ShareRequest(
          resourceType: AppResourceTypes.project,
          resourceId: '1',
          granteeUserId: '$carol',
          projectRole: ProjectRole.editor,
        ),
      );

      // The very next resolve over the now-persisted rows sees the grant.
      expect(
        await resolverOver(store).resolveRole(
          userId: carol,
          resourceType: AppResourceTypes.project,
          resourceId: 1,
        ),
        ProjectRole.editor,
      );
    });

    test('a non-owner editor may not share (forbidden)', () async {
      final store = InMemoryShareDelegationStore(delegations: demoShares());
      await expectLater(
        () => shareServiceOver(store).share(
          bob, // editor on project 1, not its owner
          ShareRequest(
            resourceType: AppResourceTypes.project,
            resourceId: '1',
            granteeUserId: '$carol',
            projectRole: ProjectRole.viewer,
          ),
        ),
        throwsA(
          isA<TomEndpointHandlerException>().having(
            (e) => e.key,
            'key',
            'app.access.forbidden',
          ),
        ),
      );
      // Nothing was persisted beyond the seed.
      expect(store.delegations, hasLength(1));
    });

    test(
      'a stranger may not share (forbidden, not leaked as missing)',
      () async {
        final store = InMemoryShareDelegationStore(delegations: demoShares());
        await expectLater(
          () => shareServiceOver(store).share(
            dave,
            ShareRequest(
              resourceType: AppResourceTypes.project,
              resourceId: '1',
              granteeUserId: '$carol',
              projectRole: ProjectRole.viewer,
            ),
          ),
          throwsA(
            isA<TomEndpointHandlerException>().having(
              (e) => e.key,
              'key',
              'app.access.forbidden',
            ),
          ),
        );
        expect(store.delegations, hasLength(1));
      },
    );

    test(
      'a non-numeric resource or grantee id is rejected as invalid',
      () async {
        final store = InMemoryShareDelegationStore(delegations: demoShares());
        await expectLater(
          () => shareServiceOver(store).share(
            alice,
            ShareRequest(
              resourceType: AppResourceTypes.project,
              resourceId: 'not-a-number',
              granteeUserId: '$carol',
              projectRole: ProjectRole.viewer,
            ),
          ),
          throwsA(
            isA<TomEndpointHandlerException>().having(
              (e) => e.key,
              'key',
              'app.share.invalid',
            ),
          ),
        );
        expect(store.delegations, hasLength(1));
      },
    );
  });

  group('revokeShare (DELETE /share/{id}) — owner-only', () {
    test('the owner revokes a share; the row is deleted', () async {
      final store = InMemoryShareDelegationStore(delegations: demoShares());
      await shareServiceOver(store).revokeShare(alice, 1);
      expect(store.delegations, isEmpty);
    });

    test('revoking removes the grantee\'s access', () async {
      final store = InMemoryShareDelegationStore(delegations: demoShares());
      // bob has editor access via share 1.
      expect(
        await resolverOver(store).resolveRole(
          userId: bob,
          resourceType: AppResourceTypes.project,
          resourceId: 1,
        ),
        ProjectRole.editor,
      );

      await shareServiceOver(store).revokeShare(alice, 1);

      expect(
        await resolverOver(store).resolveRole(
          userId: bob,
          resourceType: AppResourceTypes.project,
          resourceId: 1,
        ),
        isNull,
      );
    });

    test('a non-owner may not revoke (forbidden)', () async {
      final store = InMemoryShareDelegationStore(delegations: demoShares());
      await expectLater(
        () => shareServiceOver(store).revokeShare(bob, 1),
        throwsA(
          isA<TomEndpointHandlerException>().having(
            (e) => e.key,
            'key',
            'app.access.forbidden',
          ),
        ),
      );
      expect(store.delegations, hasLength(1)); // untouched
    });

    test(
      'revoking an unknown share is reported as not found (closed/safe)',
      () async {
        final store = InMemoryShareDelegationStore(delegations: demoShares());
        await expectLater(
          () => shareServiceOver(store).revokeShare(alice, 999),
          throwsA(
            isA<TomEndpointHandlerException>().having(
              (e) => e.key,
              'key',
              'app.share.not_found',
            ),
          ),
        );
        expect(store.delegations, hasLength(1));
      },
    );
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

    test('a malformed id maps to 400, carrying the shared wire key', () async {
      final response = appForbiddenOrNotFound(
        request,
        MalformedIdException('TodoItem.listId', 'not-an-id'),
        StackTrace.current,
      );
      expect(response?.statusCode, 400);
      expect(jsonDecode(await response!.readAsString()), {
        'error': malformedIdKey,
      });
    });

    test('a plain FormatException is still a server fault, not a 400', () {
      // The mapping's rejection is a `MalformedIdException`; a bare
      // `FormatException` here means something like a malformed resource-bundle
      // asset, which is the server's problem and must keep its 500.
      expect(
        appForbiddenOrNotFound(
          request,
          const FormatException('unexpected character'),
          StackTrace.current,
        ),
        isNull,
      );
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
