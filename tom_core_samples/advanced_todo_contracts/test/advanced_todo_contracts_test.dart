import 'dart:convert';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart'
    show ProjectRole, UserStatus;
import 'package:tom_core_kernel/tom_core_kernel.dart' show TomAuthState;
import 'package:test/test.dart';

// The single test-only reflection seed for this package (G-REFL-2).
import 'run_all_tests.reflection.dart';

/// Serializes [dto] to a JSON string and back into a map, exercising the exact
/// wire path a server/client uses (including `DateTime` → ISO string encoding).
Map<String, Object?> _wire(Object dto) =>
    jsonDecode(dtoToJsonString(dto)) as Map<String, Object?>;

void main() {
  // The reflection-first DTOs carry no hand-written serializer; the round-trip
  // is driven entirely by the kernel reflection path, which requires the DTO
  // reflection seed to be installed once.
  setUpAll(initializeReflection);

  group('LoginRequest', () {
    LoginRequest request() => LoginRequest(
          username: 'alice',
          password: 's3cret',
          app: 'todo',
          org: 'acme',
        );

    test('toString never leaks the password', () {
      expect(request().toString(), isNot(contains('s3cret')));
      expect(request().toString(), contains('alice'));
    });

    test('round-trips through reflection JSON', () {
      final restored = dtoFromJson<LoginRequest>(_wire(request()));
      expect(restored.username, 'alice');
      expect(restored.password, 's3cret');
      expect(restored.app, 'todo');
      expect(restored.org, 'acme');
    });
  });

  group('UserDto', () {
    UserDto user() => UserDto(
          id: 'u1',
          username: 'alice',
          displayName: 'Alice',
          email: 'alice@example.com',
          status: UserStatus.suspended.name,
        );

    test('defaults to the active status', () {
      expect(UserDto().statusValue, UserStatus.active);
    });

    test('resolves the typed status, falling back to active', () {
      expect(user().statusValue, UserStatus.suspended);
      expect(UserDto(status: 'bogus').statusValue, UserStatus.active);
    });

    test('round-trips through reflection JSON', () {
      final restored = dtoFromJson<UserDto>(_wire(user()));
      expect(restored.id, 'u1');
      expect(restored.username, 'alice');
      expect(restored.displayName, 'Alice');
      expect(restored.email, 'alice@example.com');
      expect(restored.statusValue, UserStatus.suspended);
    });

    test('toString carries id, username and status', () {
      expect(user().toString(), contains('u1'));
      expect(user().toString(), contains('alice'));
      expect(user().toString(), contains('suspended'));
    });
  });

  group('LoginResult', () {
    LoginResult result() => LoginResult(
          user: UserDto(id: 'u1', username: 'alice'),
          authToken: 'auth-token',
          authzToken: 'authz-token',
          expiresAt: DateTime.utc(2026, 6, 28, 12),
        );

    test('toString never leaks the bearer tokens', () {
      expect(result().toString(), isNot(contains('auth-token')));
      expect(result().toString(), isNot(contains('authz-token')));
      expect(result().toString(), contains('alice'));
    });

    test('round-trips the nested user and a UTC expiry', () {
      final restored = dtoFromJson<LoginResult>(_wire(result()));
      expect(restored.user.id, 'u1');
      expect(restored.user.username, 'alice');
      expect(restored.authToken, 'auth-token');
      expect(restored.authzToken, 'authz-token');
      expect(restored.expiresAt.toUtc(), DateTime.utc(2026, 6, 28, 12));
      expect(restored.expiresAt.isUtc, isTrue);
    });
  });

  group('GradedFieldDto', () {
    test('defaults to the closed-safe none access', () {
      expect(GradedFieldDto().accessState, TomAuthState.none);
    });

    test('parseAccess is closed-safe for unknown/absent tokens', () {
      expect(GradedFieldDto.parseAccess('full'), TomAuthState.full);
      expect(GradedFieldDto.parseAccess('bogus'), TomAuthState.none);
      expect(GradedFieldDto.parseAccess(null), TomAuthState.none);
    });

    test('round-trips through reflection JSON', () {
      final grade = GradedFieldDto(
          resourceKey: 'todo.item.status', access: TomAuthState.read);
      final restored = dtoFromJson<GradedFieldDto>(_wire(grade));
      expect(restored.resourceKey, 'todo.item.status');
      expect(restored.accessState, TomAuthState.read);
    });

    test('toString shows the key and access token', () {
      expect(
        GradedFieldDto(
                resourceKey: 'todo.item.title', access: TomAuthState.read)
            .toString(),
        'GradedFieldDto(todo.item.title -> read)',
      );
    });
  });

  group('ShareRequest', () {
    ShareRequest share() => ShareRequest(
          resourceType: 'project',
          resourceId: 'p1',
          granteeUserId: 'u2',
          projectRole: ProjectRole.editor,
        );

    test('defaults to the least-privileged viewer role', () {
      expect(ShareRequest().projectRoleValue, ProjectRole.viewer);
    });

    test('round-trips through reflection JSON', () {
      final restored = dtoFromJson<ShareRequest>(_wire(share()));
      expect(restored.resourceType, 'project');
      expect(restored.resourceId, 'p1');
      expect(restored.granteeUserId, 'u2');
      expect(restored.projectRoleValue, ProjectRole.editor);
    });

    test('an unknown role token degrades to viewer', () {
      final restored = dtoFromJson<ShareRequest>({
        'resourceType': 'project',
        'resourceId': 'p1',
        'granteeUserId': 'u2',
        'projectRole': 'bogus',
      });
      expect(restored.projectRoleValue, ProjectRole.viewer);
    });

    test('toString renders the grant', () {
      expect(share().toString(), contains('project:p1'));
      expect(share().toString(), contains('editor'));
    });
  });

  group('GrantMatrixDto', () {
    GrantMatrixDto sampleMatrix() => GrantMatrixDto.fromGrades({
          'owner': [
            GradedFieldDto(
                resourceKey: 'todo.item.title', access: TomAuthState.full),
            GradedFieldDto(
                resourceKey: 'todo.item.status', access: TomAuthState.full),
          ],
          'viewer': [
            GradedFieldDto(
                resourceKey: 'todo.item.title', access: TomAuthState.read),
            GradedFieldDto(
                resourceKey: 'todo.item.status', access: TomAuthState.read),
          ],
        });

    test('empty matrix resolves every cell to closed-safe none', () {
      expect(GrantMatrixDto().accessFor('owner', 'todo.item.title'),
          TomAuthState.none);
    });

    test('accessFor returns the set cell and none for the unset', () {
      final matrix = sampleMatrix();
      expect(matrix.accessFor('owner', 'todo.item.title'), TomAuthState.full);
      expect(matrix.accessFor('viewer', 'todo.item.status'), TomAuthState.read);
      expect(matrix.accessFor('owner', 'unknown.key'), TomAuthState.none);
      expect(matrix.accessFor('commenter', 'todo.item.title'),
          TomAuthState.none);
    });

    test('withAccess leaves the original instance unchanged', () {
      final base = sampleMatrix();
      final updated =
          base.withAccess('viewer', 'todo.item.title', TomAuthState.disabled);
      expect(base.accessFor('viewer', 'todo.item.title'), TomAuthState.read);
      expect(updated.accessFor('viewer', 'todo.item.title'),
          TomAuthState.disabled);
    });

    test('gradesFor returns grades ordered by resource key', () {
      expect(sampleMatrix().gradesFor('owner').map((g) => g.resourceKey),
          ['todo.item.status', 'todo.item.title']);
    });

    test('round-trips through reflection JSON, degrading unknown tokens', () {
      final matrix = sampleMatrix();
      final restored = dtoFromJson<GrantMatrixDto>(_wire(matrix));
      expect(restored.accessFor('owner', 'todo.item.title'), TomAuthState.full);
      expect(restored.accessFor('viewer', 'todo.item.status'),
          TomAuthState.read);

      final lenient = dtoFromJson<GrantMatrixDto>({
        'matrix': {
          'owner': {'todo.item.title': 'bogus'},
        },
      });
      expect(lenient.accessFor('owner', 'todo.item.title'), TomAuthState.none);
    });

    test('toString summarises role and cell counts', () {
      expect(sampleMatrix().toString(), 'GrantMatrixDto(2 roles, 4 cells)');
    });
  });

  group('ResourceBundleDto', () {
    ResourceBundleDto sampleBundle() => ResourceBundleDto(const {
          'todo.item.title.label': 'Title',
          'todo.item.status.label': 'Status',
          'todo.item.estimate.error.required': 'An estimate is required',
          'login.username.hint': 'Your username',
        });

    test('defaults to an empty bundle', () {
      expect(ResourceBundleDto().texts, isEmpty);
    });

    test('round-trips through reflection JSON', () {
      final restored = dtoFromJson<ResourceBundleDto>(_wire(sampleBundle()));
      expect(restored.texts, sampleBundle().texts);
    });

    test('round-trips a nested-map bundle by value', () {
      final nested = ResourceBundleDto(const {
        'todo': {
          'item': {
            'title': {'label': 'Title'},
          },
        },
        'login.username.hint': 'Your username',
      });
      final restored = dtoFromJson<ResourceBundleDto>(_wire(nested));
      expect(restored.texts, nested.texts);
    });

    test('toString summarises the key count without dumping values', () {
      expect(sampleBundle().toString(), 'ResourceBundleDto(4 keys)');
    });
  });

  group('admin CRUD DTOs', () {
    test('CreateUserRequest round-trips and hides the password', () {
      final request = CreateUserRequest(
        username: 'bob',
        password: 'pw',
        displayName: 'Bob',
        email: 'bob@example.com',
      );
      final restored = dtoFromJson<CreateUserRequest>(_wire(request));
      expect(restored.username, 'bob');
      expect(restored.password, 'pw');
      expect(restored.displayName, 'Bob');
      expect(restored.email, 'bob@example.com');
      expect(request.toString(), isNot(contains('pw')));
      expect(request.toString(), contains('bob'));
    });

    test('RoleDto round-trips', () {
      final role = RoleDto(key: 'admin', name: 'Administrator');
      final restored = dtoFromJson<RoleDto>(_wire(role));
      expect(restored.key, 'admin');
      expect(restored.name, 'Administrator');
      expect(role.toString(), contains('admin'));
    });

    group('GroupDto', () {
      test('round-trips through reflection JSON with members', () {
        final group = GroupDto(
          id: 'g1',
          name: 'Engineering',
          memberUserIds: ['u1', 'u2'],
        );
        final restored = dtoFromJson<GroupDto>(_wire(group));
        expect(restored.id, 'g1');
        expect(restored.name, 'Engineering');
        expect(restored.memberUserIds, ['u1', 'u2']);
      });
    });

    test('AssignmentRequest round-trips', () {
      final assignment =
          AssignmentRequest(userId: 'u1', roleKey: 'admin', groupId: 'g1');
      final restored = dtoFromJson<AssignmentRequest>(_wire(assignment));
      expect(restored.userId, 'u1');
      expect(restored.roleKey, 'admin');
      expect(restored.groupId, 'g1');
      expect(assignment.toString(), contains('admin'));
    });

    test('EntityIdRequest round-trips (the by-id path-param DTO)', () {
      // The server pipeline folds a `{id}` (or mapped `{key}`) path capture onto
      // `EntityIdRequest.id` and instantiates it via this reflection round-trip
      // before a by-id handler (delete / read-one) runs — so the DTO must
      // reflect losslessly from a bare `{id: ...}` map.
      final request = EntityIdRequest(id: '55');
      final restored = dtoFromJson<EntityIdRequest>(_wire(request));
      expect(restored.id, '55');
      expect(request.toString(), contains('55'));
    });
  });
}
