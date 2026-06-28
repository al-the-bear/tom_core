/// Admin-console wire DTOs for the auth server's `/admin/*` CRUD endpoints.
///
/// These back the authadmin client's Users/Roles/Groups/Assignments screens.
/// All are flat value records with hand-written JSON mapping, matching the rest
/// of the contract surface.
library;

/// Credentials + profile for `POST /admin/users` (account creation).
///
/// Distinct from `UserDto` (the password-free read projection): creation is the
/// one place the plaintext password crosses the wire, so it lives on its own
/// request type that never echoes the password through [toString].
class CreateUserRequest {
  /// The new account's login name.
  final String username;

  /// The initial plaintext password (hashed server-side; never logged).
  final String password;

  /// Human-facing name.
  final String displayName;

  /// Contact email.
  final String email;

  /// Creates a user-creation request.
  const CreateUserRequest({
    this.username = '',
    this.password = '',
    this.displayName = '',
    this.email = '',
  });

  /// Rebuilds a request from its JSON shape `{username, password, displayName,
  /// email}`.
  factory CreateUserRequest.fromJson(Map<String, Object?> json) =>
      CreateUserRequest(
        username: (json['username'] as String?) ?? '',
        password: (json['password'] as String?) ?? '',
        displayName: (json['displayName'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
      );

  /// JSON shape `{username, password, displayName, email}`.
  Map<String, Object?> toJson() => {
        'username': username,
        'password': password,
        'displayName': displayName,
        'email': email,
      };

  @override
  bool operator ==(Object other) =>
      other is CreateUserRequest &&
      other.username == username &&
      other.password == password &&
      other.displayName == displayName &&
      other.email == email;

  @override
  int get hashCode => Object.hash(username, password, displayName, email);

  @override
  String toString() => 'CreateUserRequest($username, $email)';
}

/// A role managed by `GET/POST/PUT/DELETE /admin/roles`.
///
/// [key] is the stable identifier the grant matrix and `@TomRoleAccess` key on
/// (e.g. `admin`); [name] is the human-facing label.
class RoleDto {
  /// Stable role key (e.g. `admin`).
  final String key;

  /// Human-facing role name.
  final String name;

  /// Creates a role DTO.
  const RoleDto({this.key = '', this.name = ''});

  /// Rebuilds a role from its JSON shape `{key, name}`.
  factory RoleDto.fromJson(Map<String, Object?> json) => RoleDto(
        key: (json['key'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
      );

  /// JSON shape `{key, name}`.
  Map<String, Object?> toJson() => {'key': key, 'name': name};

  @override
  bool operator ==(Object other) =>
      other is RoleDto && other.key == key && other.name == name;

  @override
  int get hashCode => Object.hash(key, name);

  @override
  String toString() => 'RoleDto($key, $name)';
}

/// A group plus its membership, managed by `GET/POST/PUT/DELETE /admin/groups`.
///
/// [memberUserIds] is copied defensively and exposed unmodifiable so a DTO
/// never mutates under a caller; equality is order-sensitive over the member
/// list (the admin UI preserves member order).
class GroupDto {
  /// Stable group identifier.
  final String id;

  /// Human-facing group name.
  final String name;

  /// The member user ids, in display order (unmodifiable).
  final List<String> memberUserIds;

  /// Creates a group DTO with a defensive, unmodifiable copy of [memberUserIds].
  GroupDto({
    this.id = '',
    this.name = '',
    List<String>? memberUserIds,
  }) : memberUserIds = List.unmodifiable(memberUserIds ?? const []);

  /// Rebuilds a group from its JSON shape `{id, name, memberUserIds}`. Non-string
  /// member entries are dropped.
  factory GroupDto.fromJson(Map<String, Object?> json) => GroupDto(
        id: (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        memberUserIds: [
          for (final member in (json['memberUserIds'] as List?) ?? const [])
            if (member is String) member,
        ],
      );

  /// JSON shape `{id, name, memberUserIds}`.
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'memberUserIds': List<String>.of(memberUserIds),
      };

  @override
  bool operator ==(Object other) =>
      other is GroupDto &&
      other.id == id &&
      other.name == name &&
      _listEquals(other.memberUserIds, memberUserIds);

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(memberUserIds));

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'GroupDto($id, $name, ${memberUserIds.length} members)';
}

/// A request to assign a role and/or group to a user, posted to
/// `POST /admin/assignments`.
///
/// [groupId] is optional (empty when assigning only a role); [roleKey] is empty
/// when assigning only group membership.
class AssignmentRequest {
  /// The user receiving the assignment.
  final String userId;

  /// The role key to assign (empty for a group-only assignment).
  final String roleKey;

  /// The group to add the user to (empty for a role-only assignment).
  final String groupId;

  /// Creates an assignment request.
  const AssignmentRequest({
    this.userId = '',
    this.roleKey = '',
    this.groupId = '',
  });

  /// Rebuilds a request from its JSON shape `{userId, roleKey, groupId}`.
  factory AssignmentRequest.fromJson(Map<String, Object?> json) =>
      AssignmentRequest(
        userId: (json['userId'] as String?) ?? '',
        roleKey: (json['roleKey'] as String?) ?? '',
        groupId: (json['groupId'] as String?) ?? '',
      );

  /// JSON shape `{userId, roleKey, groupId}`.
  Map<String, Object?> toJson() => {
        'userId': userId,
        'roleKey': roleKey,
        'groupId': groupId,
      };

  @override
  bool operator ==(Object other) =>
      other is AssignmentRequest &&
      other.userId == userId &&
      other.roleKey == roleKey &&
      other.groupId == groupId;

  @override
  int get hashCode => Object.hash(userId, roleKey, groupId);

  @override
  String toString() => 'AssignmentRequest($userId, role: $roleKey, group: $groupId)';
}
