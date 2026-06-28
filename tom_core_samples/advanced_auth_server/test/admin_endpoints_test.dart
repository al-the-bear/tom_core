/// Unit tests for the auth server's `/admin/*` logic (step 12).
///
/// The HTTP-routed [AdvancedAdminApiService] is a thin adapter whose production
/// wiring needs a database (the repository-backed store) and the request zone,
/// so it is exercised end-to-end at boot (step 13). The behaviour the plan's
/// "Done" bar calls out — an admin can edit a grant and the edit is persisted,
/// and a non-admin is rejected with HTTP 403 — is proven here against the pure
/// [AdminService] seeded with an [InMemoryAdminStore], the role-gate
/// [TomRoleAccess], and the [forbiddenOnAccessDenied] handler, with no server.
library;

import 'package:advanced_auth_server/advanced_auth_server.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// A grant of [access] to the `(role, resourceKey)` pair.
TomResourceGrant _grant(String role, String key, TomAuthState access) =>
    TomResourceGrant(roleName: role, resourceKey: key, accessLevel: access);

void main() {
  group('AdminService grants', () {
    test('getGrants projects the stored grants into the matrix', () async {
      final admin = AdminService(InMemoryAdminStore(grants: [
        _grant('editor', 'item.title', TomAuthState.read),
        _grant('editor', 'item.notes', TomAuthState.full),
        _grant('viewer', 'item.title', TomAuthState.disabled),
      ]));

      final matrix = await admin.getGrants();

      expect(matrix.accessFor('editor', 'item.title'), TomAuthState.read);
      expect(matrix.accessFor('editor', 'item.notes'), TomAuthState.full);
      expect(matrix.accessFor('viewer', 'item.title'), TomAuthState.disabled);
      // An unset cell is closed-safe.
      expect(matrix.accessFor('viewer', 'item.notes'), TomAuthState.none);
    });

    test('an admin can edit a grant and the edit is persisted (the Done bar)',
        () async {
      final store = InMemoryAdminStore(grants: [
        _grant('editor', 'item.title', TomAuthState.read),
      ]);
      final admin = AdminService(store);

      // Read the matrix, raise the cell to full, and write it back — the exact
      // get/edit/put round-trip the admin client's grant editor performs.
      final before = await admin.getGrants();
      expect(before.accessFor('editor', 'item.title'), TomAuthState.read);

      await admin.putGrants(
        before.withAccess('editor', 'item.title', TomAuthState.full),
      );

      // The reloaded matrix shows the edit ...
      final after = await admin.getGrants();
      expect(after.accessFor('editor', 'item.title'), TomAuthState.full);

      // ... and it is materialised as a persisted TomResourceGrant row.
      final rows = await store.allGrants();
      expect(
        rows.any((g) =>
            g.roleName == 'editor' &&
            g.resourceKey == 'item.title' &&
            g.accessLevel == TomAuthState.full),
        isTrue,
      );
    });

    test('putGrants replaces only the roles present in the matrix', () async {
      final store = InMemoryAdminStore(grants: [
        _grant('editor', 'item.title', TomAuthState.read),
        _grant('viewer', 'item.title', TomAuthState.read),
      ]);
      final admin = AdminService(store);

      // A matrix carrying only the editor row leaves the viewer grant intact.
      await admin.putGrants(
        GrantMatrixDto({
          'editor': {'item.title': TomAuthState.full},
        }),
      );

      final after = await admin.getGrants();
      expect(after.accessFor('editor', 'item.title'), TomAuthState.full);
      expect(after.accessFor('viewer', 'item.title'), TomAuthState.read);
    });
  });

  group('AdminService user CRUD', () {
    test('createUser hashes the password and persists the account', () async {
      final store = InMemoryAdminStore();
      final admin = AdminService(store);

      final created = await admin.createUser(const CreateUserRequest(
        username: 'ada',
        password: 's3cret',
        displayName: 'Ada Lovelace',
        email: 'ada@example.com',
      ));

      expect(created.username, 'ada');
      expect(created.id, isNotEmpty);
      expect(created.statusValue, UserStatus.active);

      final stored = await store.allUsers();
      expect(stored, hasLength(1));
      // The plaintext never lands on a column; only its salted hash does.
      expect(stored.first.passwordHash, isNotNull);
      expect(verifyUserPassword(stored.first, 's3cret'), isTrue);
    });

    test('updateUser edits the profile but preserves the stored password',
        () async {
      final seeded = applyPassword(
        UserRecord()
          ..id = 1
          ..username = 'ada'
          ..displayName = 'Ada'
          ..email = 'ada@old.example'
          ..status = UserStatus.active.name,
        's3cret',
      );
      final store = InMemoryAdminStore(users: [seeded]);
      final admin = AdminService(store);

      final updated = await admin.updateUser(
        '1',
        UserDto(
          id: '1',
          username: 'ada',
          displayName: 'Ada Lovelace',
          email: 'ada@new.example',
          status: UserStatus.active.name,
        ),
      );

      expect(updated.displayName, 'Ada Lovelace');
      expect(updated.email, 'ada@new.example');
      final stored = await store.findUser(1);
      expect(verifyUserPassword(stored!, 's3cret'), isTrue);
    });

    test('updateUser rejects an unknown id', () {
      final admin = AdminService(InMemoryAdminStore());
      expect(
        admin.updateUser('99', UserDto(id: '99', username: 'ghost')),
        throwsA(isA<TomEndpointHandlerException>()),
      );
    });

    test('deleteUser removes the account', () async {
      final store = InMemoryAdminStore(users: [UserRecord()..id = 1]);
      final admin = AdminService(store);

      await admin.deleteUser('1');

      expect(await store.allUsers(), isEmpty);
    });
  });

  group('AdminService role CRUD', () {
    test('create, rename and delete a role by its stable key', () async {
      final admin = AdminService(InMemoryAdminStore());

      await admin.createRole(const RoleDto(key: 'editor', name: 'Editor'));
      expect((await admin.listRoles()).map((r) => r.key), contains('editor'));

      final renamed = await admin.updateRole(
        'editor',
        const RoleDto(key: 'editor', name: 'Content Editor'),
      );
      expect(renamed.name, 'Content Editor');

      await admin.deleteRole('editor');
      expect(await admin.listRoles(), isEmpty);
    });
  });

  group('AdminService group CRUD', () {
    test('createGroup persists the group with its ordered membership', () async {
      final store = InMemoryAdminStore(users: [
        UserRecord()..id = 1,
        UserRecord()..id = 2,
      ]);
      final admin = AdminService(store);

      final created = await admin.createGroup(
        GroupDto(name: 'Engineering', memberUserIds: ['1', '2']),
      );

      expect(created.name, 'Engineering');
      expect(created.memberUserIds, ['1', '2']);
      final groups = await admin.listGroups();
      expect(groups.single.memberUserIds, ['1', '2']);
    });
  });

  group('AdminService assignments', () {
    test('assign records both the role and the group membership', () async {
      final store = InMemoryAdminStore(
        roles: [
          RoleRecord()
            ..id = 5
            ..roleKey = 'admin'
            ..name = 'Admin',
        ],
        groups: [
          GroupRecord()
            ..id = 9
            ..name = 'Engineering',
        ],
      );
      final admin = AdminService(store);

      await admin.assign(const AssignmentRequest(
        userId: '1',
        roleKey: 'admin',
        groupId: '9',
      ));

      expect(
        store.userRoleRows.any((a) => a.userId == 1 && a.roleId == 5),
        isTrue,
      );
      expect(
        (await store.membersOfGroup(9)).any((m) => m.userId == 1),
        isTrue,
      );
    });
  });

  group('admin role gate (the 403 contract)', () {
    const gate = TomRoleAccess(['admin']);

    TomPrincipal principalWithRoles(List<String> roles) => TomPrincipal(
          authenticated: true,
          aci: TomAccessControlInformation(roles: roles),
        );

    test('an admin principal passes the gate', () {
      expect(gate.checkAccessibility(principalWithRoles(['admin'])), isTrue);
    });

    test('a non-admin principal is rejected by the gate', () {
      expect(gate.checkAccessibility(principalWithRoles(['editor'])), isFalse);
    });

    test('an absent principal is rejected by the gate', () {
      expect(gate.checkAccessibility(null), isFalse);
    });
  });

  group('forbiddenOnAccessDenied', () {
    final request = Request('GET', Uri.parse('http://localhost/admin/users'));

    test('maps the pipeline access-denied exception to HTTP 403', () async {
      final response = forbiddenOnAccessDenied(
        request,
        TomEndpointHandlerException(endpointAccessDeniedKey, 'Access denied'),
        StackTrace.current,
      );

      expect(response, isNotNull);
      expect(response!.statusCode, 403);
      expect(await response.readAsString(), contains(endpointAccessDeniedKey));
    });

    test('passes any other error through to the default handler', () {
      final response = forbiddenOnAccessDenied(
        request,
        StateError('boom'),
        StackTrace.current,
      );

      expect(response, isNull);
    });
  });
}
