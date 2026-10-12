import 'dart:convert';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart'
    show ProjectRole, UserStatus;
import 'package:tom_core_kernel/tom_core_kernel.dart'
    show Tom2FAMethodDescriptor, TomAuthState, TomFileMetadata;
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

    test('carries no language preference by default', () {
      expect(UserDto().language, '');
      expect(UserDto().country, '');
    });

    test('normalises the stored language, and blank as no preference', () {
      expect(normaliseStoredLocale(' DE ', 'at'), (
        language: 'de',
        country: 'AT',
      ));
      expect(normaliseStoredLocale('fr', null), (language: 'fr', country: ''));
      // A country only narrows a language; alone it is no preference.
      expect(normaliseStoredLocale('  ', 'AT'), (language: '', country: ''));
      expect(normaliseStoredLocale(null, null), (language: '', country: ''));
      expect(UserDto(language: 'De', country: 'at').normalisedLocale, (
        language: 'de',
        country: 'AT',
      ));
    });

    test('round-trips the stored language through reflection JSON', () {
      final restored = dtoFromJson<UserDto>(
        _wire(UserDto(id: 'u1', language: 'de', country: 'AT')),
      );
      expect(restored.language, 'de');
      expect(restored.country, 'AT');
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

    // The half-finished shapes. A completed login leaves every two-factor
    // member at its default, so the case above cannot notice one of them
    // failing to cross the wire.

    test('round-trips a pending challenge', () {
      final restored = dtoFromJson<LoginResult>(
        _wire(
          LoginResult(
            user: UserDto(id: 'u4', username: 'dave'),
            authToken: 'interim-auth',
            authzToken: 'interim-authz',
            expiresAt: DateTime.utc(2026, 6, 28, 12, 5),
            requires2FA: true,
            twoFactorType: 'totp',
          ),
        ),
      );

      expect(restored.requires2FA, isTrue);
      expect(restored.twoFactorType, 'totp');
      expect(restored.requires2FAEnrolment, isFalse);
      expect(restored.availableTwoFactorMethods, isEmpty);
      expect(restored.twoFactorEnrolmentSkippable, isFalse);
      expect(restored.user.username, 'dave');
      expect(restored.authzToken, 'interim-authz');
      expect(restored.expiresAt.toUtc(), DateTime.utc(2026, 6, 28, 12, 5));
    });

    test('round-trips an enrolment offer, each descriptor by value', () {
      // `availableTwoFactorMethods` is the package's only list of a *kernel*
      // type: the reflection path has to find `Tom2FAMethodDescriptor` in the
      // seed and rebuild each element, not hand back maps. Compared field by
      // field, because a list of blank descriptors would pass a length check.
      final restored = dtoFromJson<LoginResult>(
        _wire(
          LoginResult(
            user: UserDto(id: 'u5', username: 'erin'),
            requires2FAEnrolment: true,
            availableTwoFactorMethods: [
              Tom2FAMethodDescriptor.scoped('totp'),
              Tom2FAMethodDescriptor(
                type: 'sms',
                displayNameKey: 'two_factor.sms.name',
                descriptionKey: 'two_factor.sms.description',
                iconKey: 'two_factor.sms.icon',
              ),
            ],
          ),
        ),
      );

      expect(restored.requires2FAEnrolment, isTrue);
      expect(restored.twoFactorEnrolmentSkippable, isFalse);
      expect(restored.requires2FA, isFalse);
      expect(
        restored.availableTwoFactorMethods,
        everyElement(isA<Tom2FAMethodDescriptor>()),
      );
      expect(
        [
          for (final m in restored.availableTwoFactorMethods)
            [m.type, m.displayNameKey, m.descriptionKey, m.iconKey],
        ],
        [
          [
            'totp',
            'two_factor.totp.name',
            'two_factor.totp.description',
            'two_factor.totp.icon',
          ],
          [
            'sms',
            'two_factor.sms.name',
            'two_factor.sms.description',
            'two_factor.sms.icon',
          ],
        ],
      );
    });

    test('round-trips a skippable enrolment offer', () {
      final restored = dtoFromJson<LoginResult>(
        _wire(
          LoginResult(
            user: UserDto(id: 'u5', username: 'erin'),
            requires2FAEnrolment: true,
            availableTwoFactorMethods: [Tom2FAMethodDescriptor.scoped('totp')],
            twoFactorEnrolmentSkippable: true,
          ),
        ),
      );

      expect(restored.requires2FAEnrolment, isTrue);
      expect(restored.twoFactorEnrolmentSkippable, isTrue);
      expect(restored.availableTwoFactorMethods.single.type, 'totp');
    });
  });

  group('two-factor requests', () {
    test('SecondFactorRequest round-trips the code and the interim token', () {
      final restored = dtoFromJson<SecondFactorRequest>(
        _wire(
          SecondFactorRequest(code: '123456', challengeToken: 'interim-authz'),
        ),
      );
      expect(restored.code, '123456');
      expect(restored.challengeToken, 'interim-authz');
    });

    test('TwoFactorEnrolmentRequest round-trips every field', () {
      final restored = dtoFromJson<TwoFactorEnrolmentRequest>(
        _wire(
          TwoFactorEnrolmentRequest(
            type: 'totp',
            code: '654321',
            enrolmentToken: 'enrolment-authz',
          ),
        ),
      );
      expect(restored.type, 'totp');
      expect(restored.code, '654321');
      expect(restored.enrolmentToken, 'enrolment-authz');
    });

    test('neither prints the code it carries', () {
      expect(
        SecondFactorRequest(code: '123456').toString(),
        isNot(contains('123456')),
      );
      expect(
        TwoFactorEnrolmentRequest(type: 'totp', code: '654321').toString(),
        allOf(isNot(contains('654321')), contains('totp')),
      );
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
      // Not every caller can promise a String: `GrantMatrixDto.matrix` is typed
      // `Map<String, Object?>`, so the guard has to cover any value at all.
      expect(GradedFieldDto.parseAccess(7), TomAuthState.none);
      expect(
        GradedFieldDto.parseAccess(const <String, Object?>{}),
        TomAuthState.none,
      );
    });

    test('parseAccess honours a non-default orElse', () {
      const fallback = TomAuthState.disabled;
      expect(GradedFieldDto.parseAccess('bogus', orElse: fallback), fallback);
      expect(GradedFieldDto.parseAccess(null, orElse: fallback), fallback);
      expect(GradedFieldDto.parseAccess(7, orElse: fallback), fallback);
      // A recognised token still wins over orElse.
      expect(
        GradedFieldDto.parseAccess('read', orElse: fallback),
        TomAuthState.read,
      );
    });

    test('round-trips through reflection JSON', () {
      final grade = GradedFieldDto(
        resourceKey: 'todo.item.status',
        access: TomAuthState.read,
      );
      final restored = dtoFromJson<GradedFieldDto>(_wire(grade));
      expect(restored.resourceKey, 'todo.item.status');
      expect(restored.accessState, TomAuthState.read);
    });

    test('toString shows the key and access token', () {
      expect(
        GradedFieldDto(
          resourceKey: 'todo.item.title',
          access: TomAuthState.read,
        ).toString(),
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
          resourceKey: 'todo.item.title',
          access: TomAuthState.full,
        ),
        GradedFieldDto(
          resourceKey: 'todo.item.status',
          access: TomAuthState.full,
        ),
      ],
      'viewer': [
        GradedFieldDto(
          resourceKey: 'todo.item.title',
          access: TomAuthState.read,
        ),
        GradedFieldDto(
          resourceKey: 'todo.item.status',
          access: TomAuthState.read,
        ),
      ],
    });

    test('empty matrix resolves every cell to closed-safe none', () {
      expect(
        GrantMatrixDto().accessFor('owner', 'todo.item.title'),
        TomAuthState.none,
      );
    });

    test('accessFor returns the set cell and none for the unset', () {
      final matrix = sampleMatrix();
      expect(matrix.accessFor('owner', 'todo.item.title'), TomAuthState.full);
      expect(matrix.accessFor('viewer', 'todo.item.status'), TomAuthState.read);
      expect(matrix.accessFor('owner', 'unknown.key'), TomAuthState.none);
      expect(
        matrix.accessFor('commenter', 'todo.item.title'),
        TomAuthState.none,
      );
    });

    test('withAccess leaves the original instance unchanged', () {
      final base = sampleMatrix();
      final updated = base.withAccess(
        'viewer',
        'todo.item.title',
        TomAuthState.disabled,
      );
      expect(base.accessFor('viewer', 'todo.item.title'), TomAuthState.read);
      expect(
        updated.accessFor('viewer', 'todo.item.title'),
        TomAuthState.disabled,
      );
    });

    test('gradesFor returns grades ordered by resource key', () {
      expect(sampleMatrix().gradesFor('owner').map((g) => g.resourceKey), [
        'todo.item.status',
        'todo.item.title',
      ]);
    });

    test('round-trips through reflection JSON, degrading unknown tokens', () {
      final matrix = sampleMatrix();
      final restored = dtoFromJson<GrantMatrixDto>(_wire(matrix));
      expect(restored.accessFor('owner', 'todo.item.title'), TomAuthState.full);
      expect(
        restored.accessFor('viewer', 'todo.item.status'),
        TomAuthState.read,
      );

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

    // `matrix` is typed `Map<String, Object?>`, so a cell can hold anything the
    // sender put there. All four readers must deny such a cell rather than
    // throw: this object is an authorization decision arriving from the
    // network, and a reader that throws breaks the console's read path instead
    // of rendering the most restrictive grade.
    group('malformed cells', () {
      GrantMatrixDto malformed() =>
          GrantMatrixDto()
            ..matrix = <String, Object?>{
              'owner': <String, Object?>{
                'todo.item.title': 'full', // well-formed: must still parse
                'todo.item.status': 7, // an int where a token belongs
                'todo.item.priority': <String, Object?>{}, // a nested map
              },
              'ghost': 'not-a-row', // a row that is not a map at all
            };

      test('accessFor denies a non-String cell', () {
        final dto = malformed();
        expect(dto.accessFor('owner', 'todo.item.status'), TomAuthState.none);
        expect(dto.accessFor('owner', 'todo.item.priority'), TomAuthState.none);
        expect(dto.accessFor('ghost', 'todo.item.title'), TomAuthState.none);
        // Anti-vacuity: the well-formed cell beside them still parses.
        expect(dto.accessFor('owner', 'todo.item.title'), TomAuthState.full);
      });

      test('gradeMapFor denies a non-String cell', () {
        final row = malformed().gradeMapFor('owner');
        expect(row['todo.item.status'], TomAuthState.none);
        expect(row['todo.item.priority'], TomAuthState.none);
        expect(row['todo.item.title'], TomAuthState.full); // anti-vacuity
        expect(row, hasLength(3)); // no cell is silently dropped
        expect(malformed().gradeMapFor('ghost'), isEmpty);
      });

      test('gradesFor denies a non-String cell and keeps key order', () {
        final grades = malformed().gradesFor('owner');
        expect(grades.map((g) => g.resourceKey), [
          'todo.item.priority',
          'todo.item.status',
          'todo.item.title',
        ]);
        expect(grades.map((g) => g.accessState), [
          TomAuthState.none,
          TomAuthState.none,
          TomAuthState.full, // anti-vacuity
        ]);
      });

      test('withAccess copies a malformed row as denied', () {
        final updated = malformed().withAccess(
          'owner',
          'todo.item.status',
          TomAuthState.read,
        );
        expect(
          updated.accessFor('owner', 'todo.item.status'),
          TomAuthState.read,
        ); // the edited cell
        expect(
          updated.accessFor('owner', 'todo.item.priority'),
          TomAuthState.none,
        ); // the other malformed cell, now a token
        expect(
          updated.accessFor('owner', 'todo.item.title'),
          TomAuthState.full,
        ); // anti-vacuity
      });

      test('a malformed cell survives the wire path', () {
        final back = dtoFromJson<GrantMatrixDto>(const {
          'matrix': {
            'owner': {'todo.item.title': 'full', 'todo.item.status': 7},
          },
        });
        expect(back.accessFor('owner', 'todo.item.status'), TomAuthState.none);
        expect(
          back.gradeMapFor('owner')['todo.item.status'],
          TomAuthState.none,
        );
        expect(back.accessFor('owner', 'todo.item.title'), TomAuthState.full);
      });
    });
  });

  group('flattenResourceTree', () {
    test('joins nested map keys with dots down to each leaf', () {
      expect(
        flattenResourceTree({
          'todo': {
            'item': {
              'title': {'label': 'Title', 'hint': 'What needs doing'},
            },
          },
        }),
        {
          'todo.item.title.label': 'Title',
          'todo.item.title.hint': 'What needs doing',
        },
      );
    });

    test('a scalar leaf whose key already holds dots flattens as written', () {
      // Only map nodes are descended; the key is never split. This is the rule
      // a reader is most likely to get wrong in the other direction.
      expect(flattenResourceTree({'board.title': 'My Board'}), {
        'board.title': 'My Board',
      });
      expect(
        flattenResourceTree({
          'board': {'header.subtitle': 'Today'},
        }),
        {'board.header.subtitle': 'Today'},
      );
    });

    test('the first non-map value ends a key, lists included', () {
      // A list is a value, not a node: it is carried whole, never indexed into
      // `key.0`, `key.1`.
      expect(
        flattenResourceTree({
          'todo': {
            'status': {
              'options': ['backlog', 'done'],
              'count': 2,
              'required': true,
            },
          },
        }),
        {
          'todo.status.options': ['backlog', 'done'],
          'todo.status.count': 2,
          'todo.status.required': true,
        },
      );
    });

    test('an empty map node contributes no key', () {
      expect(
        flattenResourceTree({
          'todo': <String, Object?>{},
          'a': {'b': 'c'},
        }),
        {'a.b': 'c'},
      );
    });
  });

  group('GrantMatrixDto.gradeMapFor', () {
    test('decodes one role\'s row into the typed grade map', () {
      // The map the server hands `TomGradedAccessControlInformation(grades:)`
      // - typed values, one per cell, and exactly the row's keys.
      final matrix = GrantMatrixDto.fromGrades({
        'editor': [
          GradedFieldDto(
            resourceKey: 'todo.item.title',
            access: TomAuthState.full,
          ),
          GradedFieldDto(
            resourceKey: 'todo.item.status',
            access: TomAuthState.read,
          ),
          GradedFieldDto(
            resourceKey: 'todo.item.estimate',
            access: TomAuthState.disabled,
          ),
        ],
      });

      final grades = matrix.gradeMapFor('editor');

      expect(grades, isA<Map<String, TomAuthState>>());
      expect(grades, {
        'todo.item.title': TomAuthState.full,
        'todo.item.status': TomAuthState.read,
        'todo.item.estimate': TomAuthState.disabled,
      });
      // It is the same answer the cell reader gives, cell by cell.
      for (final entry in grades.entries) {
        expect(matrix.accessFor('editor', entry.key), entry.value);
      }
    });

    test('survives the wire unchanged', () {
      final matrix = GrantMatrixDto.fromGrades({
        'viewer': [
          GradedFieldDto(
            resourceKey: 'todo.item.title',
            access: TomAuthState.read,
          ),
        ],
      });
      final back = dtoFromJson<GrantMatrixDto>(_wire(matrix));
      expect(back.gradeMapFor('viewer'), matrix.gradeMapFor('viewer'));
    });
  });

  group('dtoToMap', () {
    test('is the decoded form of dtoToJsonString', () {
      // The three exported helpers are one serializer seen three ways; the map
      // form must not drift from the string form a server writes.
      final dto = LoginResult(
        user: UserDto(id: 'u1', username: 'alice'),
        authToken: 'a',
        authzToken: 'z',
        expiresAt: DateTime.utc(2026, 6, 28, 12),
        availableTwoFactorMethods: [Tom2FAMethodDescriptor.scoped('totp')],
      );

      expect(jsonDecode(jsonEncode(dtoToMap(dto))), _wire(dto));
    });

    test('feeds dtoFromJson back to an equal DTO', () {
      final restored = dtoFromJson<UserDto>(
        dtoToMap(UserDto(id: 'u2', username: 'bob', email: 'bob@example.com')),
      );
      expect(restored.id, 'u2');
      expect(restored.username, 'bob');
      expect(restored.email, 'bob@example.com');
    });
  });

  group('AppFileSlots', () {
    test('composes <table>/<id>/<column> from the named parts', () {
      expect(AppFileSlots.itemAttachment('42'), 'app_items/42/attachment');
      expect(AppFileSlots.userAvatar('7'), 'auth_users/7/avatar_ref');
    });

    test('slotId reads back the id each composer wrote', () {
      // Pins the format from both ends: a composer and the reader the file
      // endpoints use cannot disagree about where the id sits.
      for (final id in ['42', 'u-7', '2026']) {
        expect(
          FileDescriptorDto(slot: AppFileSlots.itemAttachment(id)).slotId,
          id,
        );
        expect(FileDescriptorDto(slot: AppFileSlots.userAvatar(id)).slotId, id);
      }
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
      final assignment = AssignmentRequest(
        userId: 'u1',
        roleKey: 'admin',
        groupId: 'g1',
      );
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

    test('the child-create requests assemble from a body and a capture', () {
      // What the pipeline does for `POST /items/{id}/comments`: the body holds
      // the authored fields only, and `{id}` is folded on as `id`. The DTO must
      // instantiate from that merged map, and the body alone names no parent.
      final comment = dtoFromJson<AddCommentRequest>({
        ...{'body': 'Looks good'},
        'id': '7',
      });
      expect(comment.id, '7');
      expect(comment.body, 'Looks good');

      final subtask = dtoFromJson<AddSubtaskRequest>({
        ...{'title': 'Draft', 'done': true},
        'id': '7',
      });
      expect(subtask.id, '7');
      expect(subtask.title, 'Draft');
      expect(subtask.done, isTrue);
    });
  });

  group('FileDescriptorDto', () {
    // The descriptor JSON the framework file endpoint actually emits: the
    // kernel `TomFileMetadata.toJson()` shape, optional members and all.
    const headJson = <String, dynamic>{
      'key': 'items/attachment/7f3c',
      'mediaType': 'text/plain; charset=utf-8',
      'byteCount': 34,
      'fileName': 'notes.txt',
      'storedAt': '2026-07-28T09:15:00.000Z',
      'digest':
          'sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
    };

    test('an unset descriptor reads as "no file", not a zero-byte one', () {
      // The board decides whether to draw a paperclip from `hasFile`; a default
      // descriptor must never look like an empty file that exists.
      expect(FileDescriptorDto().hasFile, isFalse);
      expect(FileDescriptorDto(key: 'k').hasFile, isTrue);
    });

    test('wraps the endpoint descriptor losslessly in both directions', () {
      // This is the "agree by construction" claim of the contract: whatever a
      // HEAD returns survives the trip onto the application wire and back as
      // the *same* kernel value. A bespoke present/type/size triple could not
      // make this assertion at all.
      final metadata = TomFileMetadata.fromJson(headJson);
      final dto = FileDescriptorDto.fromMetadata(
        'app_items/1/attachment',
        metadata,
      );

      expect(dto.toMetadata(), equals(metadata));
      expect(dto.toMetadata().toJson(), equals(headJson));
      expect(dto.hasFile, isTrue);
    });

    test('the optional members survive being absent', () {
      // `fileName`/`storedAt`/`digest` travel as the empty string (the reflection path's
      // shape for an absent String); mapping empty back to null is what keeps
      // the round trip equal for a server that reported neither.
      final metadata = TomFileMetadata.fromJson(const {
        'key': 'k',
        'mediaType': 'application/octet-stream',
        'byteCount': 0,
      });
      final dto = FileDescriptorDto.fromMetadata(
        'auth_users/2/avatar_ref',
        metadata,
      );

      expect(dto.fileName, isEmpty);
      expect(dto.storedAt, isEmpty);
      expect(dto.digest, isEmpty);
      expect(dto.toMetadata(), equals(metadata));
    });

    test('carries the slot it describes, and its row id', () {
      final dto = FileDescriptorDto(
        slot: FileDescriptorDto.slotOf('app_items', '42', 'attachment'),
      );
      expect(dto.slot, 'app_items/42/attachment');
      expect(dto.slotId, '42');
      // A malformed address yields null rather than a wrong id — the caller
      // must not silently key a board row on a guess.
      expect(FileDescriptorDto(slot: 'app_items/42').slotId, isNull);
    });

    test('round-trips through reflection JSON', () {
      final dto = FileDescriptorDto.fromMetadata(
        'app_items/1/attachment',
        TomFileMetadata.fromJson(headJson),
      );
      final restored = dtoFromJson<FileDescriptorDto>(_wire(dto));

      expect(restored.slot, 'app_items/1/attachment');
      expect(restored.toMetadata(), equals(dto.toMetadata()));
    });

    test('toString names the slot and size without the storage key', () {
      final dto = FileDescriptorDto.fromMetadata(
        'app_items/1/attachment',
        TomFileMetadata.fromJson(headJson),
      );
      expect(dto.toString(), contains('app_items/1/attachment'));
      expect(dto.toString(), contains('34'));
    });
  });
}
