/// `auth_db` persistence records — the auth server's relational view of the
/// identity model (users, roles, groups, and the two membership join tables).
///
/// These are the server-side counterparts of the wire/domain shapes: the
/// contracts package carries the value DTOs (`UserDto`/`RoleDto`/`GroupDto`) and
/// `advanced_todo_domain` carries the observable `User` entity, but the
/// object-persistence layer needs the opposite shape — plain typed fields, an
/// integer surrogate primary key, and explicit foreign-key columns. The
/// conversions between the two worlds live in `auth_mapping.dart`.
///
/// Each record is `@tomReflector` + `@TomDbTable` and is loaded/saved through a
/// process-wide singleton `TomSqlDatasourceRepository`, exactly as
/// `core_server_sample` and the migrated `tom_uam` persistence model do. The
/// four-state **grant matrix** is *not* defined here: step 7 reuses the
/// framework's `TomResourceGrant` (re-exported from the `tom_core_server`
/// barrel) for that table.
library;

// tom_core_server re-exports tom_core_kernel, so `@tomReflector` and the
// persistence annotations both resolve through this single barrel.
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// The `auth_db` datasource name every record below binds to.
///
/// The reused `TomResourceGrant` carries the framework default datasource
/// (`main`) in its own annotation; the auth-server boot (step 13) registers the
/// auth connection so both names resolve to the same `auth_db` schema.
const String authDatasource = 'auth_db';

/// A user account row in `auth_users` — the principal the auth server
/// authenticates and the admin API manages.
///
/// [passwordHash] / [hashType] are server-only (the kernel-crypto hash written
/// at creation, step 9); they never cross the wire onto `UserDto`.
@tomReflector
// The table and the avatar column are read from the shared contract
// (`AppFileSlots`) rather than spelled here, because the admin console composes
// the very same names into the slot `auth_users/<id>/avatar_ref`.
@TomDbTable(
    datasource: authDatasource,
    table: AppFileSlots.usersTable,
    primaryKeyField: 'id')
class UserRecord {
  /// Surrogate primary key (`null` until first persisted).
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// Login handle, unique per deployment.
  @TomDbColumn(columnName: 'username')
  String? username;

  /// Name shown in the UI.
  @TomDbColumn(columnName: 'display_name')
  String? displayName;

  /// Contact email.
  @TomDbColumn(columnName: 'email')
  String? email;

  /// Blob key of the user's avatar — **exposed**, so the framework file
  /// endpoint serves it as the slot `auth_users/<id>/avatar_ref`.
  ///
  /// `cascadeDelete: false` is the deliberate contrast with
  /// `ItemRecord.attachment` (which is `true`). An attachment belongs to its
  /// item and dies with it; an avatar is an asset the application manages —
  /// several rows may point at one blob, and a suspended account is routinely
  /// restored — so the framework must not delete the bytes when the row goes.
  /// Reclaiming an orphaned avatar is then the application's job, which is the
  /// price of sharing the key.
  @TomDbColumn(columnName: AppFileSlots.userAvatarColumn)
  @TomFileReference(
    keyPrefix: 'users/avatar',
    exposed: true,
    cascadeDelete: false,
  )
  String? avatarRef;

  /// Account lifecycle state stored as the `UserStatus` name
  /// (`active`/`suspended`).
  @TomDbColumn(columnName: 'status')
  String? status;

  /// Salted, non-reversible password hash (kernel crypto); `null` until set.
  @TomDbColumn(columnName: 'password_hash')
  String? passwordHash;

  /// Hash algorithm tag stored alongside [passwordHash].
  @TomDbColumn(columnName: 'hash_type')
  String? hashType;

  /// The second-factor mechanism this account is enrolled in (a
  /// `@Tom2FAAdaptor` key such as `totp`), or `null`/empty when the account logs
  /// in on its password alone. Enrolling a user is therefore a data change, not
  /// a code change.
  @TomDbColumn(columnName: 'two_factor_type')
  String? twoFactorType;

  /// The mechanism's per-user enrolment secret — for `totp`, the base32 string
  /// the authenticator app was provisioned with.
  ///
  /// Server-only, and deliberately **not** projected onto the principal: token
  /// claims are readable by whoever holds the token, so a secret parked there
  /// would travel to the client. The TOTP adaptor reaches it through
  /// `TomTotp2FAService.globalSettingSecretResolver`, wired to this column in
  /// `authentication_service.dart`.
  @TomDbColumn(columnName: 'two_factor_secret')
  String? twoFactorSecret;
}

/// Repository for [UserRecord].
class UserRepository extends TomSqlDatasourceRepository<UserRecord, int> {}

/// Process-wide singleton repository instance.
final userRepository = UserRepository();

/// A role row in `auth_roles`. [roleKey] is the stable key the grant matrix and
/// `@TomRoleAccess` gate on (e.g. `admin`); [name] is the human-facing label.
@tomReflector
@TomDbTable(datasource: authDatasource, table: 'auth_roles', primaryKeyField: 'id')
class RoleRecord {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// Stable role key (e.g. `admin`) — the wire `RoleDto.key`.
  @TomDbColumn(columnName: 'role_key')
  String? roleKey;

  /// Human-facing role name.
  @TomDbColumn(columnName: 'name')
  String? name;
}

/// Repository for [RoleRecord].
class RoleRepository extends TomSqlDatasourceRepository<RoleRecord, int> {}

/// Process-wide singleton repository instance.
final roleRepository = RoleRepository();

/// A group row in `auth_groups`. Membership lives in [GroupMemberRecord]s, not
/// as a column here.
@tomReflector
@TomDbTable(datasource: authDatasource, table: 'auth_groups', primaryKeyField: 'id')
class GroupRecord {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// Human-facing group name.
  @TomDbColumn(columnName: 'name')
  String? name;
}

/// Repository for [GroupRecord].
class GroupRepository extends TomSqlDatasourceRepository<GroupRecord, int> {}

/// Process-wide singleton repository instance.
final groupRepository = GroupRepository();

/// A `(group, user)` membership row in `auth_group_members`.
///
/// Given a surrogate [id] of its own (rather than overloading one foreign key as
/// the primary key, as the legacy UAM join tables do) so the row is a
/// well-formed, individually addressable entity.
@tomReflector
@TomDbTable(
  datasource: authDatasource,
  table: 'auth_group_members',
  primaryKeyField: 'id',
)
class GroupMemberRecord {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// [GroupRecord.id] of the group.
  @TomDbColumn(columnName: 'group_id')
  int? groupId;

  /// [UserRecord.id] of the member.
  @TomDbColumn(columnName: 'user_id')
  int? userId;
}

/// Repository for [GroupMemberRecord].
class GroupMemberRepository
    extends TomSqlDatasourceRepository<GroupMemberRecord, int> {}

/// Process-wide singleton repository instance.
final groupMemberRepository = GroupMemberRepository();

/// A `(user, role)` assignment row in `auth_user_roles`.
///
/// Carries its own surrogate [id] for the same reason as [GroupMemberRecord].
@tomReflector
@TomDbTable(
  datasource: authDatasource,
  table: 'auth_user_roles',
  primaryKeyField: 'id',
)
class UserRoleRecord {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// [UserRecord.id] of the assignee.
  @TomDbColumn(columnName: 'user_id')
  int? userId;

  /// [RoleRecord.id] of the assigned role.
  @TomDbColumn(columnName: 'role_id')
  int? roleId;
}

/// Repository for [UserRoleRecord].
class UserRoleRepository
    extends TomSqlDatasourceRepository<UserRoleRecord, int> {}

/// Process-wide singleton repository instance.
final userRoleRepository = UserRoleRepository();

/// Repository for the framework's [TomPrincipalResourceGrant] table
/// (`tom_principal_resource_grant`) — the per-principal-per-resource role grants
/// (C-5) the login folds into `TomAccessControlInformation.resourceRoles`.
///
/// The entity carries the framework default `main` datasource, which the boot
/// (step 13) delegates to `auth_db`, so the grant rows live in the same physical
/// schema as the identity tables — reachable here and, through the same `main`
/// delegation, from the app server that writes ownership grants.
class PrincipalResourceGrantRepository
    extends TomSqlDatasourceRepository<TomPrincipalResourceGrant, int> {}

/// Process-wide singleton repository instance.
final principalResourceGrantRepository = PrincipalResourceGrantRepository();

/// Repository for the framework's [TomPrincipalDelegation] table
/// (`tom_principal_delegation`) — the per-delegate delegation rows, of which the
/// sample uses only C-6 `share`-mode grants ("owner shares a resource with a
/// grantee"). The login folds a delegate's active shares into
/// `TomAccessControlInformation.resourceRoles` (RCB7) so the minted token's
/// effective-role claim matches what the servers enforce.
///
/// Like the grant table it binds the framework default `main` datasource, which
/// the boot (step 13) delegates to `auth_db`, so the delegation rows the app
/// server writes on `main` are read here through the same physical schema.
class PrincipalDelegationRepository
    extends TomSqlDatasourceRepository<TomPrincipalDelegation, int> {}

/// Process-wide singleton repository instance.
final principalDelegationRepository = PrincipalDelegationRepository();
