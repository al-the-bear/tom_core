/// Contract tests for the seeded [InMemoryAdminBackend]: the offline
/// teaching backend the admin console's widgets bind in tests, exercised across
/// the seam's whole surface — the `admin`-role gate, Users/Roles/Groups CRUD, the
/// four-state grant matrix round-trip, and role/group assignments.
///
/// These are socket-free and reflection-free: the admin DTOs are plain value
/// records (no reflected entities), so unlike the app client's contract test this
/// one needs no `initializeReflection`. The same scenarios are the contract any
/// [AdminBackend] must honour, so when [LiveAdminBackend] is wired against a
/// running auth server it must behave identically.
library;

import 'package:advanced_authadmin_client/backend/backend.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryAdminBackend backend;
  setUp(() => backend = InMemoryAdminBackend());

  Future<LoginResult> loginAs(String username) => backend.login(
    LoginRequest(
      username: username,
      password: InMemoryAdminBackend.demoPassword,
    ),
  );

  Future<LoginResult> loginAdmin() => loginAs('admin');

  group('login + admin gate', () {
    test(
      'TC-32-01: the admin logs in and returns the principal + tokens',
      () async {
        final result = await loginAdmin();
        expect(result.user.username, 'admin');
        expect(result.user.id, 'u-admin');
        expect(result.authToken, isNotEmpty);
        expect(result.authzToken, isNotEmpty);
        expect(result.expiresAt.isAfter(DateTime.now().toUtc()), isTrue);
      },
    );

    test(
      'TC-32-02: an unknown account is rejected with a typed error',
      () async {
        await expectLater(
          loginAs('mallory'),
          throwsA(
            isA<AdminBackendException>().having(
              (e) => e.key,
              'key',
              'auth.login.failed',
            ),
          ),
        );
      },
    );

    test('TC-32-03: a wrong password is rejected', () async {
      await expectLater(
        backend.login(LoginRequest(username: 'admin', password: 'nope')),
        throwsA(
          isA<AdminBackendException>().having(
            (e) => e.key,
            'key',
            'auth.login.failed',
          ),
        ),
      );
    });

    test(
      'TC-32-04: an admin call before login throws admin.no_session',
      () async {
        await expectLater(
          backend.listUsers(),
          throwsA(
            isA<AdminBackendException>().having(
              (e) => e.key,
              'key',
              'admin.no_session',
            ),
          ),
        );
      },
    );

    test(
      'TC-32-05: a signed-in non-admin is refused admin.access.forbidden',
      () async {
        await loginAs('alice'); // alice holds `owner`, not `admin`
        await expectLater(
          backend.listUsers(),
          throwsA(
            isA<AdminBackendException>().having(
              (e) => e.key,
              'key',
              'admin.access.forbidden',
            ),
          ),
        );
      },
    );
  });

  group('users', () {
    test('TC-32-06: listUsers returns the seeded accounts', () async {
      await loginAdmin();
      final users = await backend.listUsers();
      expect(
        users.map((u) => u.username),
        containsAll(<String>['admin', 'alice', 'bob', 'carol']),
      );
    });

    test(
      'TC-32-07: createUser assigns an id and the account appears',
      () async {
        await loginAdmin();
        final created = await backend.createUser(
          CreateUserRequest(
            username: 'carol',
            password: 'secret',
            displayName: 'Carol',
            email: 'carol@todo.example',
          ),
        );
        expect(created.id, isNotEmpty);
        expect(created.username, 'carol');
        final users = await backend.listUsers();
        expect(users.map((u) => u.id), contains(created.id));
      },
    );

    test(
      'TC-32-08: updateUser changes the profile but keeps id + username',
      () async {
        await loginAdmin();
        final alice = (await backend.listUsers()).firstWhere(
          (u) => u.username == 'alice',
        );
        final updated = await backend.updateUser(
          alice.id,
          UserDto(
            id: alice.id,
            username: 'ignored-on-update',
            displayName: 'Alice Cooper',
            email: 'alice.cooper@todo.example',
          ),
        );
        expect(updated.id, alice.id);
        expect(updated.username, 'alice'); // username is a stable key
        expect(updated.displayName, 'Alice Cooper');
        expect(updated.email, 'alice.cooper@todo.example');
      },
    );

    test('TC-32-09: deleteUser removes the account', () async {
      await loginAdmin();
      final bob = (await backend.listUsers()).firstWhere(
        (u) => u.username == 'bob',
      );
      await backend.deleteUser(bob.id);
      final users = await backend.listUsers();
      expect(users.map((u) => u.username), isNot(contains('bob')));
    });
  });

  group('roles', () {
    test('TC-32-10: listRoles returns the seeded roles', () async {
      await loginAdmin();
      final roles = await backend.listRoles();
      expect(
        roles.map((r) => r.key),
        containsAll(<String>[
          'admin',
          'owner',
          'editor',
          'commenter',
          'viewer',
        ]),
      );
    });

    test(
      'TC-32-11: createRole adds a role; a duplicate key is rejected',
      () async {
        await loginAdmin();
        await backend.createRole(RoleDto(key: 'auditor', name: 'Auditor'));
        expect(
          (await backend.listRoles()).map((r) => r.key),
          contains('auditor'),
        );
        await expectLater(
          backend.createRole(RoleDto(key: 'auditor', name: 'Dup')),
          throwsA(
            isA<AdminBackendException>().having(
              (e) => e.key,
              'key',
              'admin.role.duplicate',
            ),
          ),
        );
      },
    );

    test('TC-32-12: updateRole renames and deleteRole removes', () async {
      await loginAdmin();
      final updated = await backend.updateRole(
        'viewer',
        RoleDto(name: 'Read-only'),
      );
      expect(updated.key, 'viewer');
      expect(updated.name, 'Read-only');
      await backend.deleteRole('commenter');
      expect(
        (await backend.listRoles()).map((r) => r.key),
        isNot(contains('commenter')),
      );
    });
  });

  group('groups', () {
    test(
      'TC-32-13: listGroups returns the seeded group with members',
      () async {
        await loginAdmin();
        final groups = await backend.listGroups();
        final eng = groups.firstWhere((g) => g.id == 'g-eng');
        expect(eng.name, 'Engineering');
        expect(eng.memberUserIds, <String>['u-bob', 'u-carol']);
      },
    );

    test(
      'TC-32-14: createGroup assigns an id; updateGroup edits membership',
      () async {
        await loginAdmin();
        final created = await backend.createGroup(
          GroupDto(name: 'QA', memberUserIds: const ['u-carol']),
        );
        expect(created.id, isNotEmpty);
        final edited = await backend.updateGroup(
          created.id,
          GroupDto(
            id: created.id,
            name: 'Quality',
            memberUserIds: const ['u-carol', 'u-bob'],
          ),
        );
        expect(edited.name, 'Quality');
        expect(edited.memberUserIds, <String>['u-carol', 'u-bob']);
        await backend.deleteGroup(created.id);
        expect(
          (await backend.listGroups()).map((g) => g.id),
          isNot(contains(created.id)),
        );
      },
    );
  });

  group('grants', () {
    test('TC-32-15: getGrants returns the seeded four-state matrix', () async {
      await loginAdmin();
      final matrix = await backend.getGrants();
      expect(
        matrix.roles,
        containsAll(<String>['owner', 'editor', 'commenter', 'viewer']),
      );
      // Spot-check one cell of each state across the matrix.
      expect(matrix.accessFor('owner', 'todo.item.title'), TomAuthState.full);
      expect(
        matrix.accessFor('editor', 'todo.item.assigneeId'),
        TomAuthState.read,
      );
      expect(
        matrix.accessFor('commenter', 'todo.item.priority'),
        TomAuthState.none,
      );
      expect(
        matrix.accessFor('viewer', 'todo.item.status'),
        TomAuthState.disabled,
      );
    });

    test(
      'TC-32-16: putGrants replaces the matrix and a reload reflects it',
      () async {
        await loginAdmin();
        final before = await backend.getGrants();
        final edited = before.withAccess(
          'viewer',
          'todo.item.status',
          TomAuthState.full,
        );
        await backend.putGrants(edited);
        final reloaded = await backend.getGrants();
        expect(
          reloaded.accessFor('viewer', 'todo.item.status'),
          TomAuthState.full,
        );
      },
    );
  });

  group('assignments', () {
    test('TC-32-17: assign records a role and adds group membership', () async {
      await loginAdmin();
      await backend.assign(
        AssignmentRequest(userId: 'u-carol', roleKey: 'editor'),
      );
      expect(backend.rolesOf('u-carol'), contains('editor'));

      await backend.assign(
        AssignmentRequest(userId: 'u-alice', groupId: 'g-eng'),
      );
      final eng = (await backend.listGroups()).firstWhere(
        (g) => g.id == 'g-eng',
      );
      expect(eng.memberUserIds, contains('u-alice'));
    });

    test('TC-32-18: assigning to an unknown user is rejected', () async {
      await loginAdmin();
      await expectLater(
        backend.assign(
          AssignmentRequest(userId: 'u-nobody', roleKey: 'editor'),
        ),
        throwsA(
          isA<AdminBackendException>().having(
            (e) => e.key,
            'key',
            'admin.user.not_found',
          ),
        ),
      );
    });
  });
}
