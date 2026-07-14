/// Unit tests for the auth server's [AdvancedAuthenticationService] (step 10).
///
/// The DB reads sit behind the [AuthUserStore] seam, so these tests run the real
/// login logic against a seeded [InMemoryAuthUserStore] — no database and no
/// reflection. They assert the two paths the plan calls out: the **accept** path
/// returns an authenticated [TomPrincipal] carrying the user's expected roles and
/// groups, and the **reject** paths (wrong password, unknown user, suspended
/// account, credential-less row) each throw a [LoginException] rather than
/// returning a principal.
library;

import 'package:advanced_auth_server/advanced_auth_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Builds the login data for [username]/[password]; the locale/tenant fields are
/// fixed since the single-tenant service ignores them for the credential check.
TomAuthenticationData _login(String username, String password) =>
    TomAuthenticationData(
      username: username,
      key: password,
      organization: 'acme',
      application: 'todo',
      process: 'default',
      language: 'en',
      country: 'US',
      timezone: 'UTC',
      client: 'web',
    );

/// A store seeded with one active user (`ada`, id 1, password `s3cret`, role
/// `editor`, group `Engineering`) plus the optional [extraUsers] / assignments.
InMemoryAuthUserStore _storeWith({
  List<UserRecord> extraUsers = const [],
  Map<int, List<String>> roleKeysByUserId = const {
    1: ['editor'],
  },
  Map<int, List<String>> groupNamesByUserId = const {
    1: ['Engineering'],
  },
}) {
  final ada = applyPassword(
    UserRecord()
      ..id = 1
      ..username = 'ada'
      ..displayName = 'Ada Lovelace'
      ..email = 'ada@example.com'
      ..status = UserStatus.active.name,
    's3cret',
  );
  return InMemoryAuthUserStore(
    users: [ada, ...extraUsers],
    roleKeysByUserId: roleKeysByUserId,
    groupNamesByUserId: groupNamesByUserId,
  );
}

/// Builds the effective-role resolver over seeded in-memory grant and delegation
/// stores, so the login folds the given C-5 [grants] and C-6 `share`-mode
/// [shares] into `aci.resourceRoles`. Defaults to neither (the common case for
/// the credential-path tests).
TomDelegationResolver _resolverWith({
  List<TomPrincipalResourceGrant> grants = const [],
  List<TomPrincipalDelegation> shares = const [],
}) =>
    TomDelegationResolver(
      InMemoryPrincipalDelegationStore(shares),
      TomPrincipalResourceRoleResolver(
        InMemoryPrincipalResourceGrantStore(grants),
      ),
    );

/// A C-6 `share`-mode delegation lending [delegateId] the [role] on [resourceKey],
/// granted by [delegatorId] (always active — no time bounds).
TomPrincipalDelegation _share({
  required String delegatorId,
  required String delegateId,
  required String resourceKey,
  required ProjectRole role,
}) =>
    TomPrincipalDelegation(
      mode: TomDelegationMode.share.name,
      delegatorId: delegatorId,
      delegateId: delegateId,
      resourceKey: resourceKey,
      role: role.name,
    );

void main() {
  group('AdvancedAuthenticationService.authenticateUser', () {
    test('accepts the right password and builds the authenticated principal',
        () async {
      final service = AdvancedAuthenticationService(_storeWith(), _resolverWith());

      final info = await service.authenticateUser(_login('ada', 's3cret'));

      expect(info.principal.authenticated, isTrue);
      expect(info.principal.username, 'ada');
      expect(info.principal.user.id, 1);
      expect(info.principal.user.email, 'ada@example.com');
    });

    test('the principal carries the user\'s expected roles and groups',
        () async {
      final service = AdvancedAuthenticationService(
        _storeWith(
          roleKeysByUserId: const {
            1: ['editor', 'viewer'],
          },
          groupNamesByUserId: const {
            1: ['Engineering'],
          },
        ),
        _resolverWith(),
      );

      final info = await service.authenticateUser(_login('ada', 's3cret'));

      expect(info.principal.aci.roles, containsAll(['editor', 'viewer']));
      expect(info.principal.aci.groups, contains('Engineering'));
      // The access-control definition mirrors the assigned roles/groups.
      expect(info.acd.toString(), contains('2 roles'));
    });

    test('the principal carries the user\'s resource roles from grants (C-5)',
        () async {
      // Ada (id 1) owns a project and is a viewer of an item; the login folds
      // her grant rows into aci.resourceRoles keyed by resource key.
      final service = AdvancedAuthenticationService(
        _storeWith(),
        _resolverWith(grants: [
          TomPrincipalResourceGrant(
            principalId: '1',
            resourceKey: ResourceRoleKeys.project(7),
            role: ProjectRole.owner.name,
          ),
          TomPrincipalResourceGrant(
            principalId: '1',
            resourceKey: ResourceRoleKeys.item(9),
            role: ProjectRole.viewer.name,
          ),
          // A grant for a different principal must not leak into ada's map.
          TomPrincipalResourceGrant(
            principalId: '2',
            resourceKey: ResourceRoleKeys.project(7),
            role: ProjectRole.editor.name,
          ),
        ]),
      );

      final info = await service.authenticateUser(_login('ada', 's3cret'));

      expect(info.principal.aci.resourceRoles, {
        'project:7': 'owner',
        'item:9': 'viewer',
      });
    });

    test(
        'the principal carries roles shared to it via C-6 delegations, '
        'folded with its own grants (RCB7)', () async {
      // Ada (id 1) owns project 7 (C-5) and is separately shared `editor` on
      // project 5 by user 2 (C-6). The login folds both into aci.resourceRoles,
      // so the minted token's claim matches what the app server enforces.
      final service = AdvancedAuthenticationService(
        _storeWith(),
        _resolverWith(
          grants: [
            TomPrincipalResourceGrant(
              principalId: '1',
              resourceKey: ResourceRoleKeys.project(7),
              role: ProjectRole.owner.name,
            ),
          ],
          shares: [
            _share(
              delegatorId: '2',
              delegateId: '1',
              resourceKey: ResourceRoleKeys.project(5),
              role: ProjectRole.editor,
            ),
            // A share to a different delegate must not leak into ada's map.
            _share(
              delegatorId: '1',
              delegateId: '2',
              resourceKey: ResourceRoleKeys.project(7),
              role: ProjectRole.viewer,
            ),
          ],
        ),
      );

      final info = await service.authenticateUser(_login('ada', 's3cret'));

      expect(info.principal.aci.resourceRoles, {
        'project:7': 'owner',
        'project:5': 'editor',
      });
    });

    test(
        'a C-6 share on an already-owned resource collapses to the stronger '
        'role (RCB7)', () async {
      // Ada owns project 7 (owner) and is also shared `viewer` on it — the fold
      // keeps the stronger `owner`, so a weaker share never demotes ownership.
      final service = AdvancedAuthenticationService(
        _storeWith(),
        _resolverWith(
          grants: [
            TomPrincipalResourceGrant(
              principalId: '1',
              resourceKey: ResourceRoleKeys.project(7),
              role: ProjectRole.owner.name,
            ),
          ],
          shares: [
            _share(
              delegatorId: '2',
              delegateId: '1',
              resourceKey: ResourceRoleKeys.project(7),
              role: ProjectRole.viewer,
            ),
          ],
        ),
      );

      final info = await service.authenticateUser(_login('ada', 's3cret'));

      expect(info.principal.aci.resourceRoles, {'project:7': 'owner'});
    });

    test('rejects the wrong password with a LoginException', () async {
      final service = AdvancedAuthenticationService(_storeWith(), _resolverWith());

      await expectLater(
        service.authenticateUser(_login('ada', 'wrong')),
        throwsA(isA<LoginException>()),
      );
    });

    test('rejects an unknown user with a LoginException', () async {
      final service = AdvancedAuthenticationService(_storeWith(), _resolverWith());

      await expectLater(
        service.authenticateUser(_login('nobody', 's3cret')),
        throwsA(isA<LoginException>()),
      );
    });

    test('rejects a suspended account even with the right password', () async {
      final suspended = applyPassword(
        UserRecord()
          ..id = 2
          ..username = 'bob'
          ..status = UserStatus.suspended.name,
        'hunter2',
      );
      final service = AdvancedAuthenticationService(
        _storeWith(extraUsers: [suspended]),
        _resolverWith(),
      );

      await expectLater(
        service.authenticateUser(_login('bob', 'hunter2')),
        throwsA(
          isA<LoginException>().having(
            (e) => e.key,
            'key',
            'error.user.suspended',
          ),
        ),
      );
    });

    test('rejects a credential-less row (freshly seeded, no password)',
        () async {
      // Step-8 seeds leave password_hash NULL until a password is set.
      final seeded = UserRecord()
        ..id = 3
        ..username = 'carol'
        ..status = UserStatus.active.name;
      final service = AdvancedAuthenticationService(
        _storeWith(extraUsers: [seeded]),
        _resolverWith(),
      );

      await expectLater(
        service.authenticateUser(_login('carol', 'anything')),
        throwsA(isA<LoginException>()),
      );
    });

    test('unknown user and wrong password share the same generic key', () async {
      final service = AdvancedAuthenticationService(_storeWith(), _resolverWith());

      Future<String> keyFor(String user, String password) async {
        try {
          await service.authenticateUser(_login(user, password));
          fail('expected a LoginException');
        } on LoginException catch (e) {
          return e.key;
        }
      }

      expect(await keyFor('nobody', 's3cret'),
          await keyFor('ada', 'definitely-wrong'));
    });
  });
}
