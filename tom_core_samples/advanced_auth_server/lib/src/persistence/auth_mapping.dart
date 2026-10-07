/// Pure conversions between the `auth_db` persistence records and the shapes the
/// auth server actually works with: the observable `advanced_todo_domain.User`
/// entity and the `advanced_todo_contracts` wire DTOs
/// (`UserDto`/`RoleDto`/`GroupDto`).
///
/// This is the one place the relational and the domain/wire worlds meet. The
/// records use integer surrogate keys and foreign-key columns; the domain `User`
/// uses display-string ids and observable fields; the DTOs are flat value
/// records.
///
/// Every conversion here is **pure** — no I/O, no database — which is what lets
/// `test/auth_persistence_mapping_test.dart` cover the whole boundary without
/// one. They are **total** in the record → domain/DTO direction: anything
/// `auth_db` can hold rebuilds, with an unreadable stored value degrading to a
/// default. In the other direction there is exactly one input they reject, a
/// display-id that is not a usable database key; see [_idOrNull] for why that
/// one is worth a throw.
///
/// Server-only columns ([UserRecord.passwordHash] / [UserRecord.hashType]) never
/// round-trip through the domain or the DTOs — they are written by `applyPassword`
/// in `auth/password_hashing.dart` and by the authentication service, never
/// echoed on the wire.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';

import 'auth_persistence_model.dart';

/// Parses a domain/DTO display-id into a database key: `null` for the empty id
/// of a not-yet-persisted entity, the parsed integer otherwise — and a
/// [MalformedIdException] naming [field] and [value] for anything else.
///
/// It throws rather than folding a malformed id into `null` because on this
/// side of the boundary `null` is not a neutral "unknown": it is an
/// instruction. For a primary key it means INSERT, so a corrupt id would file a
/// second account while the client kept the id it thought it was updating. Both
/// are writes that look successful and are found much later, if at all — and
/// unlike the read-only `core_server_sample`, this mapping sits behind live
/// mutating `/admin/*` endpoints, so the corrupt id arrives from a client
/// rather than from a fixture.
///
/// The ids are free-form strings, so this is untrusted input and the leniency
/// [userFromRecord] applies in the other direction does not carry over:
/// degrading an unreadable *stored* status keeps one bad row from breaking a
/// whole list, whereas degrading an unreadable *incoming* id is what creates
/// the bad row.
int? _idOrNull(String value, String field) {
  if (value.isEmpty) return null;
  final parsed = int.tryParse(value);
  if (parsed == null) throw MalformedIdException(field, value);
  return parsed;
}

/// Parses a display-id that must name an already-persisted row, as a
/// membership entry does.
///
/// Same as [_idOrNull] except that the empty string is rejected too: "not
/// persisted yet" is not something a foreign key pointing at an existing user
/// can mean.
int _persistedId(String value, String field) =>
    _idOrNull(value, field) ??
    (throw MalformedIdException.persisted(field, value));

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
  ..id = _idOrNull(user.id.get(), 'User.id')
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
  language: record.language ?? '',
  country: record.country ?? '',
);

/// Applies the mutable profile fields of a [UserDto] onto a [UserRecord] (the
/// `PUT /admin/users` update path). Returns the same [record] for chaining.
///
/// The password/hash columns are deliberately untouched: an update echoes the
/// password-free `UserDto`, so a profile edit must never clear the stored hash.
///
/// The `?? record.id` covers exactly one case — a DTO that carries *no* id,
/// which addresses the record the handler already loaded. It no longer covers a
/// **malformed** id: [_idOrNull] throws on one now. That fallback used to
/// absorb the throw, so an update carrying a corrupt id quietly edited whatever
/// row the handler happened to fetch instead of failing, which is the one
/// outcome a client can neither see nor undo.
UserRecord applyUserDto(UserRecord record, UserDto dto) => record
  ..id = _idOrNull(dto.id, 'UserDto.id') ?? record.id
  ..username = dto.username
  ..displayName = dto.displayName
  ..email = dto.email
  ..status = dto.status
  ..language = _nullIfEmpty(dto.normalisedLocale.language)
  ..country = _nullIfEmpty(dto.normalisedLocale.country);

/// `null` — an absent column value — for the empty string the wire uses for
/// "none".
String? _nullIfEmpty(String value) => value.isEmpty ? null : value;

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
RoleDto roleRecordToDto(RoleRecord record) =>
    RoleDto(key: record.roleKey ?? '', name: record.name ?? '');

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
  ..id = _idOrNull(dto.id, 'GroupDto.id')
  ..name = dto.name;

/// Materialises a [GroupDto]'s membership into `(group_id, user_id)`
/// [GroupMemberRecord]s for the given [groupId].
///
/// Every member id must name a persisted user, so one that does not raises
/// [MalformedIdException] (via [_persistedId]) and the whole edit fails. This
/// used to *skip* such ids, and the skip was documented — but a documented skip
/// is still a silent one where it counts: a group edit carrying a single
/// corrupt id saved successfully and persisted a membership list quietly
/// missing that member, so the administrator saw a green save and a group that
/// had lost someone. Rejecting the edit leaves the stored membership as it was
/// and says which id was unusable.
List<GroupMemberRecord> groupMemberRecords(
  GroupDto dto, {
  required int groupId,
}) => [
  for (final memberId in dto.memberUserIds)
    GroupMemberRecord()
      ..groupId = groupId
      ..userId = _persistedId(memberId, 'GroupDto.memberUserIds'),
];

/// Rejects a [GroupDto] whose membership names a user id that is not a
/// persisted key, raising the same [MalformedIdException] [groupMemberRecords]
/// would.
///
/// It exists because [groupMemberRecords] needs a `groupId` and the *create*
/// path has none yet: the group row has to be written before its key is known.
/// Checking first is what keeps a rejected create from leaving an empty orphan
/// group behind — these endpoints declare no transaction, so a throw after the
/// row is saved is not rolled back.
void checkGroupMembership(GroupDto dto) {
  for (final memberId in dto.memberUserIds) {
    _persistedId(memberId, 'GroupDto.memberUserIds');
  }
}
