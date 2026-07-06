/// Database-free unit tests for the `auth_db` persistence boundary: the
/// record <-> domain `User` and record <-> wire DTO conversions are pure and
/// total, so they verify without a server or MariaDB.
///
/// The live schema boot + seed rows are the gate of step 8; these tests cover
/// everything that does not need a database — step 7's "Done" bar.
library;

import 'package:advanced_auth_server/advanced_auth_server.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:test/test.dart';

void main() {
  // The domain `User` is an observable TomClass: constructing one self-observes
  // through reflection, so the registry must be live before any mapping runs.
  // The records and DTOs are plain classes and need no such setup.
  setUpAll(initializeReflection);

  group('user mapping (domain entity <-> record)', () {
    test('round-trips a persisted user, preserving every domain field', () {
      final record = UserRecord()
        ..id = 7
        ..username = 'ada'
        ..displayName = 'Ada Lovelace'
        ..email = 'ada@example.com'
        ..avatarRef = 'avatars/ada.png'
        ..status = UserStatus.suspended.name;

      final user = userFromRecord(record);
      expect(user.id.get(), '7');
      expect(user.username.get(), 'ada');
      expect(user.displayName.get(), 'Ada Lovelace');
      expect(user.email.get(), 'ada@example.com');
      expect(user.avatarRef.get(), 'avatars/ada.png');
      expect(user.statusValue, UserStatus.suspended);

      final back = userToRecord(user);
      expect(back.id, 7);
      expect(back.username, 'ada');
      expect(back.displayName, 'Ada Lovelace');
      expect(back.email, 'ada@example.com');
      expect(back.avatarRef, 'avatars/ada.png');
      expect(back.status, UserStatus.suspended.name);
    });

    test('an unpersisted user maps to a null primary key (INSERT)', () {
      final user = User()..username.set('new');
      expect(userToRecord(user).id, isNull);
    });

    test('an absent stored status degrades to active', () {
      final user = userFromRecord(UserRecord()..id = 1);
      expect(user.statusValue, UserStatus.active);
    });

    test('the domain mapping never carries the password hash', () {
      // The server-only columns are not part of the domain entity, so a
      // round-trip through `User` leaves them untouched (null here).
      final record = UserRecord()
        ..id = 1
        ..username = 'ada'
        ..passwordHash = 'secret-hash'
        ..hashType = 'argon2';
      final back = userToRecord(userFromRecord(record));
      expect(back.passwordHash, isNull);
      expect(back.hashType, isNull);
    });
  });

  group('user mapping (record -> wire DTO)', () {
    test('projects the password-free user view', () {
      final record = UserRecord()
        ..id = 7
        ..username = 'ada'
        ..displayName = 'Ada'
        ..email = 'ada@example.com'
        ..status = UserStatus.active.name
        ..passwordHash = 'secret-hash';

      final dto = userRecordToDto(record);
      // Reflection-first DTOs carry no value `==`; assert the projected fields.
      expect(dto.id, '7');
      expect(dto.username, 'ada');
      expect(dto.displayName, 'Ada');
      expect(dto.email, 'ada@example.com');
      expect(dto.statusValue, UserStatus.active);
      // The DTO has no password field at all — the hash cannot leak through it.
      expect(dto.toString(), isNot(contains('secret-hash')));
    });

    test('applyUserDto updates the profile without clearing the hash', () {
      final record = UserRecord()
        ..id = 7
        ..username = 'ada'
        ..displayName = 'Ada'
        ..email = 'ada@old.com'
        ..status = UserStatus.active.name
        ..passwordHash = 'secret-hash'
        ..hashType = 'argon2';

      applyUserDto(
        record,
        UserDto(
          id: '7',
          username: 'ada',
          displayName: 'Ada L.',
          email: 'ada@new.com',
          status: UserStatus.suspended.name,
        ),
      );

      expect(record.displayName, 'Ada L.');
      expect(record.email, 'ada@new.com');
      expect(record.status, UserStatus.suspended.name);
      expect(record.passwordHash, 'secret-hash', reason: 'hash preserved');
      expect(record.hashType, 'argon2');
    });

    test('createUserRequestToRecord seeds active with no hash yet', () {
      final record = createUserRequestToRecord(CreateUserRequest(
        username: 'grace',
        password: 'plaintext',
        displayName: 'Grace',
        email: 'grace@example.com',
      ));
      expect(record.id, isNull);
      expect(record.username, 'grace');
      expect(record.email, 'grace@example.com');
      expect(record.status, UserStatus.active.name);
      expect(record.passwordHash, isNull,
          reason: 'hashing is the step-9 helper, not the mapper');
    });
  });

  group('role mapping (record <-> wire DTO)', () {
    test('round-trips key and name', () {
      final record = RoleRecord()
        ..id = 3
        ..roleKey = 'admin'
        ..name = 'Administrator';
      final dto = roleRecordToDto(record);
      // Reflection-first DTOs carry no value `==`; assert the projected fields.
      expect(dto.key, 'admin');
      expect(dto.name, 'Administrator');

      final back = roleDtoToRecord(dto);
      expect(back.roleKey, 'admin');
      expect(back.name, 'Administrator');
      expect(back.id, isNull, reason: 'surrogate id assigned on insert');
    });
  });

  group('group mapping (record + members <-> wire DTO)', () {
    test('assembles a group with members in row order', () {
      final group = GroupRecord()
        ..id = 5
        ..name = 'Engineering';
      final members = [
        GroupMemberRecord()
          ..groupId = 5
          ..userId = 7,
        GroupMemberRecord()
          ..groupId = 5
          ..userId = 9,
      ];

      final dto = groupToDto(group, members);
      // Reflection-first DTOs carry no value `==`; assert the projected fields.
      expect(dto.id, '5');
      expect(dto.name, 'Engineering');
      expect(dto.memberUserIds, ['7', '9']);
    });

    test('a group with no members maps to an empty member list', () {
      final dto = groupToDto(GroupRecord()..id = 5..name = 'Empty', const []);
      expect(dto.memberUserIds, isEmpty);
    });

    test('groupDtoToRecord + groupMemberRecords split the DTO back apart', () {
      final dto = GroupDto(
        id: '5',
        name: 'Engineering',
        memberUserIds: const ['7', '9'],
      );

      final record = groupDtoToRecord(dto);
      expect(record.id, 5);
      expect(record.name, 'Engineering');

      final memberRows = groupMemberRecords(dto, groupId: 5);
      expect(memberRows.map((m) => m.userId), [7, 9]);
      expect(memberRows.every((m) => m.groupId == 5), isTrue);
    });

    test('non-numeric member ids are skipped when materialising rows', () {
      final dto = GroupDto(
        id: '5',
        name: 'Engineering',
        memberUserIds: const ['7', 'not-an-id', '9'],
      );
      final memberRows = groupMemberRecords(dto, groupId: 5);
      expect(memberRows.map((m) => m.userId), [7, 9]);
    });
  });
}
