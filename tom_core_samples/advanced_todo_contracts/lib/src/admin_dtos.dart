/// Admin-console wire DTOs for the auth server's `/admin/*` CRUD endpoints.
///
/// These back the authadmin client's Users/Roles/Groups/Assignments screens.
/// All are reflection-first wire DTOs (G-DTO): `@tomReflector`, plain non-`final`
/// fields, no hand-written serializer. The framework serializes them through the
/// reflection path ([TomReflectionInfo.getValues] /
/// [TomReflectionInfo.createInstanceFromJson]) exactly like the reflected domain
/// entities — both as a single endpoint result and inside a `List<…>` result.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Credentials + profile for `POST /admin/users` (account creation).
///
/// Distinct from `UserDto` (the password-free read projection): creation is the
/// one place the plaintext password crosses the wire, so it lives on its own
/// request type that never echoes the password through [toString].
@tomReflector
class CreateUserRequest {
  /// The new account's login name.
  String username;

  /// The initial plaintext password (hashed server-side; never logged).
  String password;

  /// Human-facing name.
  String displayName;

  /// Contact email.
  String email;

  /// Creates a user-creation request.
  CreateUserRequest({
    this.username = '',
    this.password = '',
    this.displayName = '',
    this.email = '',
  });

  @override
  String toString() => 'CreateUserRequest($username, $email)';
}

/// A role managed by `GET/POST/PUT/DELETE /admin/roles`.
///
/// [key] is the stable identifier the grant matrix and `@TomRoleAccess` key on
/// (e.g. `admin`); [name] is the human-facing label.
@tomReflector
class RoleDto {
  /// Stable role key (e.g. `admin`).
  String key;

  /// Human-facing role name.
  String name;

  /// Creates a role DTO.
  RoleDto({this.key = '', this.name = ''});

  @override
  String toString() => 'RoleDto($key, $name)';
}

/// A group plus its membership, managed by `GET/POST/PUT/DELETE /admin/groups`.
///
/// [memberUserIds] is a plain, mutable list of the member user ids in display
/// order (the admin UI preserves member order).
@tomReflector
class GroupDto {
  /// Stable group identifier.
  String id;

  /// Human-facing group name.
  String name;

  /// The member user ids, in display order.
  List<String> memberUserIds;

  /// Creates a group DTO.
  GroupDto({this.id = '', this.name = '', List<String>? memberUserIds})
    : memberUserIds = memberUserIds ?? <String>[];

  @override
  String toString() => 'GroupDto($id, $name, ${memberUserIds.length} members)';
}

/// A request to assign a role and/or group to a user, posted to
/// `POST /admin/assignments`.
///
/// [groupId] is optional (empty when assigning only a role); [roleKey] is empty
/// when assigning only group membership.
@tomReflector
class AssignmentRequest {
  /// The user receiving the assignment.
  String userId;

  /// The role key to assign (empty for a group-only assignment).
  String roleKey;

  /// The group to add the user to (empty for a role-only assignment).
  String groupId;

  /// Creates an assignment request.
  AssignmentRequest({this.userId = '', this.roleKey = '', this.groupId = ''});

  @override
  String toString() =>
      'AssignmentRequest($userId, role: $roleKey, group: $groupId)';
}
