/// Pure conversions between the `auth_db` persistence records and the shapes the
/// auth server actually works with: the observable `advanced_todo_domain.User`
/// entity and the `advanced_todo_contracts` wire DTOs
/// (`UserDto`/`RoleDto`/`GroupDto`).
///
/// This is the one place the relational and the domain/wire worlds meet. The
/// records use integer surrogate keys and foreign-key columns; the domain `User`
/// uses display-string ids and observable fields; the DTOs are flat value
/// records. Every conversion here is **pure and total**, which is what lets
/// `test/auth_persistence_mapping_test.dart` cover the whole boundary without a
/// database.
///
/// Server-only columns ([UserRecord.passwordHash] / [UserRecord.hashType]) never
/// round-trip through the domain or the DTOs — they are written by `applyPassword`
/// in `auth/password_hashing.dart` and by the authentication service, never
/// echoed on the wire.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';

import 'auth_persistence_model.dart';

/// Parses a domain/DTO display-id into a database key, or `null` when the value
/// is empty (the entity has not been persisted yet → INSERT, not UPDATE).
int? _idOrNull(String value) => value.isEmpty ? null : int.tryParse(value);

/// Renders a database key back as a display-id string (empty for `null`).
String _idString(int? value) => value?.toString() ?? '';

// ---------------------------------------------------------------------------
// User — domain entity <-> record, and record -> wire DTO.
// ---------------------------------------------------------------------------

/// Flattens the observable domain [User] into its [UserRecord].
///
/// The auth columns are server-only and not part of the domain entity, so they
/// are left untouched (callers that set a password write [UserRecord.passwordHash]
/// separately via `applyPassword`).
UserRecord userToRecord(User user) => UserRecord()
  ..id = _idOrNull(user.id.get())
  ..username = user.username.get()
  ..displayName = user.displayName.get()
  ..email = user.email.get()
  ..avatarRef = user.avatarRef.get()
  ..status = user.status.get();

/// Rebuilds the observable domain [User] from its [UserRecord]. An absent stored
/// status degrades to [UserStatus.active] through the entity's typed accessor.
User userFromRecord(UserRecord record) => User()
  ..id.set(_idString(record.id))
  ..username.set(record.username ?? '')
  ..displayName.set(record.displayName ?? '')
  ..email.set(record.email ?? '')
  ..avatarRef.set(record.avatarRef ?? '')
  ..status.set(record.status ?? UserStatus.active.name);

/// Projects a [UserRecord] onto the password-free wire [UserDto] the auth and
/// admin APIs return.
UserDto userRecordToDto(UserRecord record) => UserDto(
      id: _idString(record.id),
      username: record.username ?? '',
      displayName: record.displayName ?? '',
      email: record.email ?? '',
      status: record.status,
    );

/// Applies the mutable profile fields of a [UserDto] onto a [UserRecord] (the
/// `PUT /admin/users/{id}` update path). Returns the same [record] for chaining.
///
/// The password/hash columns are deliberately untouched: an update echoes the
/// password-free `UserDto`, so a profile edit must never clear the stored hash.
UserRecord applyUserDto(UserRecord record, UserDto dto) => record
  ..id = _idOrNull(dto.id) ?? record.id
  ..username = dto.username
  ..displayName = dto.displayName
  ..email = dto.email
  ..status = dto.status;

/// Builds a fresh [UserRecord] from a [CreateUserRequest] (the
/// `POST /admin/users` create path). The password is hashed and written
/// separately by `applyPassword`, so [UserRecord.passwordHash] stays `null`
/// here; [UserRecord.status] seeds to [UserStatus.active].
UserRecord createUserRequestToRecord(CreateUserRequest request) => UserRecord()
  ..username = request.username
  ..displayName = request.displayName
  ..email = request.email
  ..status = UserStatus.active.name;

// ---------------------------------------------------------------------------
// Role — record <-> wire DTO.
// ---------------------------------------------------------------------------

/// Projects a [RoleRecord] onto its wire [RoleDto] (`{key, name}`).
RoleDto roleRecordToDto(RoleRecord record) => RoleDto(
      key: record.roleKey ?? '',
      name: record.name ?? '',
    );

/// Builds a [RoleRecord] from a [RoleDto]. The surrogate [RoleRecord.id] is left
/// `null` (assigned on insert); the stable [RoleDto.key] is the natural lookup
/// key.
RoleRecord roleDtoToRecord(RoleDto dto) => RoleRecord()
  ..roleKey = dto.key
  ..name = dto.name;

// ---------------------------------------------------------------------------
// Group — (record + member rows) <-> wire DTO.
// ---------------------------------------------------------------------------

/// Assembles a [GroupDto] from its [GroupRecord] and the group's
/// [GroupMemberRecord]s. Membership is projected to display-id strings in the
/// order the member rows are supplied (the admin UI preserves member order).
GroupDto groupToDto(GroupRecord record, Iterable<GroupMemberRecord> members) =>
    GroupDto(
      id: _idString(record.id),
      name: record.name ?? '',
      memberUserIds: [for (final member in members) _idString(member.userId)],
    );

/// Extracts the [GroupRecord] from a [GroupDto] (the row only; membership is
/// materialised separately via [groupMemberRecords]).
GroupRecord groupDtoToRecord(GroupDto dto) => GroupRecord()
  ..id = _idOrNull(dto.id)
  ..name = dto.name;

/// Materialises a [GroupDto]'s membership into `(group_id, user_id)`
/// [GroupMemberRecord]s for the given [groupId]. Member ids that are not numeric
/// keys are skipped (they cannot reference a persisted user).
List<GroupMemberRecord> groupMemberRecords(GroupDto dto, {required int groupId}) =>
    [
      for (final memberId in dto.memberUserIds)
        if (_idOrNull(memberId) case final int userId)
          GroupMemberRecord()
            ..groupId = groupId
            ..userId = userId,
    ];
