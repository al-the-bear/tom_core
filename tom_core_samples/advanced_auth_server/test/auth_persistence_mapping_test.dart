/// Database-free unit tests for the `auth_db` persistence boundary: the
/// record <-> domain `User` and record <-> wire DTO conversions are pure, so
/// they verify without a server or MariaDB.
///
/// They are total in the record → domain/DTO direction and the final group
/// below pins the one place they are not: a display-id that is not a usable
/// database key is rejected rather than folded into `null`.
///
/// The live schema and its seed rows are proven by booting
/// `bin/auth_server_start.dart` against MariaDB; these tests cover everything
/// that does not need a database.
library;

import 'package:advanced_auth_server/advanced_auth_server.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:test/test.dart';

// The server's single reflection seed is its boot root (G-REFL-1); its tests
// bootstrap reflection from that same seed rather than a library seed.
import '../bin/auth_server_start.reflection.dart' show initializeReflection;

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

    test('projects the stored language, and none as empty', () {
      final dto = userRecordToDto(
        UserRecord()
          ..id = 7
          ..language = 'de'
          ..country = 'AT',
      );
      expect(dto.language, 'de');
      expect(dto.country, 'AT');

      final none = userRecordToDto(UserRecord()..id = 8);
      expect(none.language, '');
      expect(none.country, '');
    });

    test('applyUserDto stores the language normalised, and a blank one as no '
        'preference', () {
      UserRecord apply(String language, String country) => applyUserDto(
        UserRecord()..id = 7,
        UserDto(id: '7', language: language, country: country),
      );

      final set = apply(' DE ', 'at');
      expect(set.language, 'de');
      expect(set.country, 'AT');

      final cleared = apply('  ', 'AT');
      expect(cleared.language, isNull);
      // A country narrows a language; without one it is no preference.
      expect(cleared.country, isNull);

      final languageOnly = apply('fr', '');
      expect(languageOnly.language, 'fr');
      expect(languageOnly.country, isNull);
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
      final record = createUserRequestToRecord(
        CreateUserRequest(
          username: 'grace',
          password: 'plaintext',
          displayName: 'Grace',
          email: 'grace@example.com',
        ),
      );
      expect(record.id, isNull);
      expect(record.username, 'grace');
      expect(record.email, 'grace@example.com');
      expect(record.status, UserStatus.active.name);
      expect(
        record.passwordHash,
        isNull,
        reason: 'hashing is applyPassword\'s job, not the mapper\'s',
      );
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
      final dto = groupToDto(
        GroupRecord()
          ..id = 5
          ..name = 'Empty',
        const [],
      );
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
  });

  // The one direction these conversions are not total. Every case below used to
  // pass silently: a malformed id became `null`, which on the way *into* the
  // database is not "unknown" but an instruction — INSERT for a primary key,
  // "no such member" for a membership row. The last case is the anti-vacuity
  // guard: the group cannot pass by rejecting everything.
  group('malformed ids are rejected, not folded into null', () {
    test('userToRecord rejects a non-numeric primary key', () {
      final user = User()..id.set('seven');
      expect(
        () => userToRecord(user),
        throwsA(
          isA<MalformedIdException>()
              .having((e) => e.source, 'source', 'seven')
              .having((e) => e.message, 'message', contains('User.id')),
        ),
      );
    });

    test('groupDtoToRecord rejects a non-numeric primary key', () {
      final dto = GroupDto(id: 'five', name: 'Engineering');
      expect(
        () => groupDtoToRecord(dto),
        throwsA(
          isA<MalformedIdException>()
              .having((e) => e.source, 'source', 'five')
              .having((e) => e.message, 'message', contains('GroupDto.id')),
        ),
      );
    });

    test('applyUserDto rejects a malformed id instead of editing the '
        'record the handler happened to load', () {
      final record = UserRecord()
        ..id = 7
        ..username = 'ada'
        ..displayName = 'Ada'
        ..email = 'ada@old.com'
        ..status = UserStatus.active.name;

      expect(
        () => applyUserDto(
          record,
          UserDto(
            id: 'not-an-id',
            username: 'ada',
            displayName: 'Mallory',
            email: 'mallory@example.com',
            status: UserStatus.active.name,
          ),
        ),
        throwsA(isA<MalformedIdException>()),
      );
      // The throw happens on the first cascade step, so nothing downstream of
      // it was applied — the loaded row is untouched, which is the whole point.
      expect(record.displayName, 'Ada');
      expect(record.email, 'ada@old.com');
    });

    test('applyUserDto still accepts an id-less DTO, addressing the loaded '
        'record', () {
      final record = UserRecord()
        ..id = 7
        ..username = 'ada'
        ..displayName = 'Ada'
        ..email = 'ada@old.com'
        ..status = UserStatus.active.name;

      applyUserDto(
        record,
        UserDto(
          id: '',
          username: 'ada',
          displayName: 'Ada L.',
          email: 'ada@new.com',
          status: UserStatus.active.name,
        ),
      );

      expect(record.id, 7, reason: 'an absent id is not a request to INSERT');
      expect(record.displayName, 'Ada L.');
    });

    test('groupMemberRecords rejects a non-numeric member id instead of '
        'silently dropping the member', () {
      final dto = GroupDto(
        id: '5',
        name: 'Engineering',
        memberUserIds: const ['7', 'not-an-id', '9'],
      );
      expect(
        () => groupMemberRecords(dto, groupId: 5),
        throwsA(
          isA<MalformedIdException>().having(
            (e) => e.message,
            'message',
            contains('GroupDto.memberUserIds'),
          ),
        ),
      );
    });

    test('groupMemberRecords rejects an empty member id: a membership row '
        'cannot reference an unpersisted user', () {
      final dto = GroupDto(
        id: '5',
        name: 'Engineering',
        memberUserIds: const ['7', ''],
      );
      expect(
        () => groupMemberRecords(dto, groupId: 5),
        throwsA(isA<MalformedIdException>()),
      );
    });

    test('a well-formed id still parses — the rejections above are not '
        'the whole story', () {
      expect(userToRecord(User()..id.set('7')).id, 7);
      expect(groupDtoToRecord(GroupDto(id: '5', name: 'E')).id, 5);
      expect(
        groupMemberRecords(
          GroupDto(id: '5', name: 'E', memberUserIds: const ['7']),
          groupId: 5,
        ).single.userId,
        7,
      );
    });
  });
}
