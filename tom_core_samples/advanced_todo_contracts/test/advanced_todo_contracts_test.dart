import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart'
    show ProjectRole, UserStatus;
import 'package:tom_core_kernel/tom_core_kernel.dart' show TomAuthState;
import 'package:test/test.dart';

void main() {
  group('LoginRequest', () {
    final request = LoginRequest(
      username: 'alice',
      password: 's3cret',
      app: 'todo',
      org: 'acme',
    );

    test('equal requests compare equal and share a hash', () {
      final same = LoginRequest(
        username: 'alice',
        password: 's3cret',
        app: 'todo',
        org: 'acme',
      );
      expect(request, same);
      expect(request.hashCode, same.hashCode);
    });

    test('a differing password breaks equality', () {
      expect(
        request == LoginRequest(username: 'alice', app: 'todo', org: 'acme'),
        isFalse,
      );
    });

    test('toString never leaks the password', () {
      expect(request.toString(), isNot(contains('s3cret')));
      expect(request.toString(), contains('alice'));
    });

    test('round-trips through JSON', () {
      expect(LoginRequest.fromJson(request.toJson()), request);
    });
  });

  group('UserDto', () {
    final user = UserDto(
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
      expect(user.statusValue, UserStatus.suspended);
      expect(UserDto(status: 'bogus').statusValue, UserStatus.active);
    });

    test('round-trips through JSON', () {
      expect(UserDto.fromJson(user.toJson()), user);
    });

    test('toString carries id, username and status', () {
      expect(user.toString(), contains('u1'));
      expect(user.toString(), contains('alice'));
      expect(user.toString(), contains('suspended'));
    });
  });

  group('LoginResult', () {
    final result = LoginResult(
      user: UserDto(id: 'u1', username: 'alice'),
      authToken: 'auth-token',
      authzToken: 'authz-token',
      expiresAt: DateTime.utc(2026, 6, 28, 12),
    );

    test('equal results compare equal and share a hash', () {
      final same = LoginResult(
        user: UserDto(id: 'u1', username: 'alice'),
        authToken: 'auth-token',
        authzToken: 'authz-token',
        expiresAt: DateTime.utc(2026, 6, 28, 12),
      );
      expect(result, same);
      expect(result.hashCode, same.hashCode);
    });

    test('toString never leaks the bearer tokens', () {
      expect(result.toString(), isNot(contains('auth-token')));
      expect(result.toString(), isNot(contains('authz-token')));
      expect(result.toString(), contains('alice'));
    });

    test('round-trips through JSON with a UTC expiry', () {
      final restored = LoginResult.fromJson(result.toJson());
      expect(restored, result);
      expect(restored.expiresAt.isUtc, isTrue);
    });
  });

  group('GradedFieldDto', () {
    test('defaults to the closed-safe none access', () {
      expect(const GradedFieldDto().access, TomAuthState.none);
    });

    test('equal grades compare equal and share a hash', () {
      const a = GradedFieldDto(
          resourceKey: 'todo.item.title', access: TomAuthState.full);
      const b = GradedFieldDto(
          resourceKey: 'todo.item.title', access: TomAuthState.full);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('parseAccess is closed-safe for unknown/absent tokens', () {
      expect(GradedFieldDto.parseAccess('full'), TomAuthState.full);
      expect(GradedFieldDto.parseAccess('bogus'), TomAuthState.none);
      expect(GradedFieldDto.parseAccess(null), TomAuthState.none);
    });

    test('round-trips through JSON', () {
      const grade = GradedFieldDto(
          resourceKey: 'todo.item.status', access: TomAuthState.read);
      expect(GradedFieldDto.fromJson(grade.toJson()), grade);
    });

    test('toString shows the key and access token', () {
      expect(
        const GradedFieldDto(
                resourceKey: 'todo.item.title', access: TomAuthState.read)
            .toString(),
        'GradedFieldDto(todo.item.title -> read)',
      );
    });
  });

  group('ShareRequest', () {
    final share = const ShareRequest(
      resourceType: 'project',
      resourceId: 'p1',
      granteeUserId: 'u2',
      projectRole: ProjectRole.editor,
    );

    test('defaults to the least-privileged viewer role', () {
      expect(const ShareRequest().projectRole, ProjectRole.viewer);
    });

    test('equal requests compare equal and share a hash', () {
      const same = ShareRequest(
        resourceType: 'project',
        resourceId: 'p1',
        granteeUserId: 'u2',
        projectRole: ProjectRole.editor,
      );
      expect(share, same);
      expect(share.hashCode, same.hashCode);
    });

    test('round-trips through JSON', () {
      expect(ShareRequest.fromJson(share.toJson()), share);
    });

    test('an unknown role token degrades to viewer', () {
      final restored = ShareRequest.fromJson({
        'resourceType': 'project',
        'resourceId': 'p1',
        'granteeUserId': 'u2',
        'projectRole': 'bogus',
      });
      expect(restored.projectRole, ProjectRole.viewer);
    });

    test('toString renders the grant', () {
      expect(share.toString(), contains('project:p1'));
      expect(share.toString(), contains('editor'));
    });
  });

  group('GrantMatrixDto', () {
    GrantMatrixDto sampleMatrix() => GrantMatrixDto.fromGrades({
          'owner': const [
            GradedFieldDto(
                resourceKey: 'todo.item.title', access: TomAuthState.full),
            GradedFieldDto(
                resourceKey: 'todo.item.status', access: TomAuthState.full),
          ],
          'viewer': const [
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
      expect(
          matrix.accessFor('owner', 'unknown.key'), TomAuthState.none);
      expect(matrix.accessFor('commenter', 'todo.item.title'),
          TomAuthState.none);
    });

    test('equal matrices compare equal regardless of insertion order', () {
      final a = GrantMatrixDto.fromGrades({
        'owner': const [
          GradedFieldDto(
              resourceKey: 'todo.item.title', access: TomAuthState.full),
          GradedFieldDto(
              resourceKey: 'todo.item.status', access: TomAuthState.read),
        ],
      });
      final b = GrantMatrixDto.fromGrades({
        'owner': const [
          GradedFieldDto(
              resourceKey: 'todo.item.status', access: TomAuthState.read),
          GradedFieldDto(
              resourceKey: 'todo.item.title', access: TomAuthState.full),
        ],
      });
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a single differing cell breaks equality', () {
      final base = sampleMatrix();
      final changed =
          base.withAccess('viewer', 'todo.item.title', TomAuthState.disabled);
      expect(base == changed, isFalse);
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

    test('the exposed matrix view is unmodifiable', () {
      expect(() => GrantMatrixDto().matrix['x'] = {}, throwsUnsupportedError);
    });

    test('round-trips through JSON, degrading unknown tokens to none', () {
      final matrix = sampleMatrix();
      expect(GrantMatrixDto.fromJson(matrix.toJson()), matrix);

      final lenient = GrantMatrixDto.fromJson({
        'owner': {'todo.item.title': 'bogus'},
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

    test('exposes an unmodifiable texts view', () {
      expect(() => ResourceBundleDto().texts['x'] = 'y',
          throwsUnsupportedError);
    });

    test('equal bundles compare equal and share a hash', () {
      expect(sampleBundle(), sampleBundle());
      expect(sampleBundle().hashCode, sampleBundle().hashCode);
    });

    test('order-independent equality across keys', () {
      final a = ResourceBundleDto(const {
        'login.username.hint': 'Your username',
        'todo.item.title.label': 'Title',
      });
      final b = ResourceBundleDto(const {
        'todo.item.title.label': 'Title',
        'login.username.hint': 'Your username',
      });
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a single differing value breaks equality', () {
      final changed = ResourceBundleDto(const {
        'todo.item.title.label': 'Title',
        'todo.item.status.label': 'State',
        'todo.item.estimate.error.required': 'An estimate is required',
        'login.username.hint': 'Your username',
      });
      expect(sampleBundle() == changed, isFalse);
    });

    test('round-trips through JSON', () {
      expect(ResourceBundleDto.fromJson(sampleBundle().toJson()),
          sampleBundle());
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
      expect(ResourceBundleDto.fromJson(nested.toJson()), nested);
    });

    test('a missing or non-map texts decodes to an empty bundle', () {
      expect(ResourceBundleDto.fromJson(const {}).texts, isEmpty);
      expect(
          ResourceBundleDto.fromJson(const {'texts': 'oops'}).texts, isEmpty);
    });

    test('toString summarises the key count without dumping values', () {
      expect(sampleBundle().toString(), 'ResourceBundleDto(4 keys)');
    });
  });

  group('admin CRUD DTOs', () {
    test('CreateUserRequest round-trips and hides the password', () {
      const request = CreateUserRequest(
        username: 'bob',
        password: 'pw',
        displayName: 'Bob',
        email: 'bob@example.com',
      );
      expect(CreateUserRequest.fromJson(request.toJson()), request);
      expect(request.toString(), isNot(contains('pw')));
      expect(request.toString(), contains('bob'));
    });

    test('RoleDto round-trips and compares structurally', () {
      const role = RoleDto(key: 'admin', name: 'Administrator');
      expect(RoleDto.fromJson(role.toJson()), role);
      expect(role.hashCode, const RoleDto(key: 'admin', name: 'Administrator').hashCode);
      expect(role.toString(), contains('admin'));
    });

    group('GroupDto', () {
      test('round-trips through JSON with members', () {
        final group = GroupDto(
          id: 'g1',
          name: 'Engineering',
          memberUserIds: ['u1', 'u2'],
        );
        expect(GroupDto.fromJson(group.toJson()), group);
      });

      test('member order is significant for equality', () {
        final a = GroupDto(id: 'g1', name: 'Eng', memberUserIds: ['u1', 'u2']);
        final b = GroupDto(id: 'g1', name: 'Eng', memberUserIds: ['u2', 'u1']);
        expect(a == b, isFalse);
      });

      test('exposes an unmodifiable member list', () {
        final group = GroupDto(memberUserIds: ['u1']);
        expect(() => group.memberUserIds.add('u2'), throwsUnsupportedError);
      });

      test('drops non-string members on decode', () {
        final group = GroupDto.fromJson({
          'id': 'g1',
          'name': 'Eng',
          'memberUserIds': ['u1', 42, 'u2'],
        });
        expect(group.memberUserIds, ['u1', 'u2']);
      });
    });

    test('AssignmentRequest round-trips and compares structurally', () {
      const assignment =
          AssignmentRequest(userId: 'u1', roleKey: 'admin', groupId: 'g1');
      expect(AssignmentRequest.fromJson(assignment.toJson()), assignment);
      expect(
        assignment,
        const AssignmentRequest(userId: 'u1', roleKey: 'admin', groupId: 'g1'),
      );
      expect(assignment.toString(), contains('admin'));
    });
  });
}
