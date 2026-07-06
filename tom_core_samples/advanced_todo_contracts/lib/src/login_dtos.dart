import 'package:advanced_todo_domain/advanced_todo_domain.dart' show UserStatus;
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Credentials posted to `POST /auth/login`.
///
/// [app] and [org] scope the login to a tenant/application the way the real
/// `tom_uam` auth server does, so one auth server can serve several apps. The
/// password is never echoed by [toString] (it must not reach logs — see the
/// sample's security notes).
///
/// A reflection-first wire DTO (G-DTO): `@tomReflector`, plain non-`final`
/// fields, no hand-written serializer — the framework serializes it through the
/// reflection path.
@tomReflector
class LoginRequest {
  /// The account's login name.
  String username;

  /// The plaintext password, verified server-side against a kernel hash. Never
  /// logged or rendered by [toString].
  String password;

  /// Application the login targets (tenant scoping).
  String app;

  /// Organisation the login targets (tenant scoping).
  String org;

  /// Creates a login request. All fields default to empty so a partially built
  /// form maps cleanly.
  LoginRequest({
    this.username = '',
    this.password = '',
    this.app = '',
    this.org = '',
  });

  @override
  String toString() => 'LoginRequest($username, app: $app, org: $org)';
}

/// A user account projected onto the wire — the safe, password-free view the
/// auth server returns from login and the admin API returns from
/// `GET /admin/users`.
///
/// [status] travels as the [UserStatus.name] token (`active`/`suspended`) under
/// the wire key `status`; use [statusValue] for the typed enum. Deliberately a
/// flat record (not the reflected `User` entity) so it carries only the wire
/// projection.
///
/// A reflection-first wire DTO (G-DTO): `@tomReflector`, plain non-`final`
/// fields, no hand-written serializer.
@tomReflector
class UserDto {
  /// Stable identifier (the auth server's primary key).
  String id;

  /// The account's login name.
  String username;

  /// Human-facing name shown in the UI.
  String displayName;

  /// Contact email.
  String email;

  /// Account lifecycle state as a [UserStatus.name] token; use [statusValue].
  String status;

  /// Creates a user projection. [status] defaults to `active`.
  UserDto({
    this.id = '',
    this.username = '',
    this.displayName = '',
    this.email = '',
    String? status,
  }) : status = status ?? UserStatus.active.name;

  /// Typed view of [status]; falls back to [UserStatus.active] for an unknown
  /// stored value.
  UserStatus get statusValue =>
      UserStatus.values.asNameMap()[status] ?? UserStatus.active;

  /// Sets [status] from a typed [UserStatus].
  set statusValue(UserStatus value) => status = value.name;

  @override
  String toString() => 'UserDto($id, $username, $status)';
}

/// The result of a successful `POST /auth/login`: the resolved principal plus
/// the signed token pair and its expiry.
///
/// Mirrors `tom_uam`'s login response shape `{user, authToken, authzToken,
/// expiresAt}`: [authToken] proves identity, [authzToken] carries the resolved
/// authorization (the graded field matrix), and [expiresAt] is when the pair
/// stops being accepted. Tokens are never rendered by [toString] (they are
/// bearer secrets).
///
/// A reflection-first wire DTO (G-DTO): `@tomReflector`, plain non-`final`
/// fields, no hand-written serializer. The nested [user] is itself a reflected
/// DTO and round-trips through the same reflection path; [expiresAt] travels as
/// an ISO-8601 string (the reflection serializer's `DateTime` encoding).
@tomReflector
class LoginResult {
  /// The authenticated principal, password-free.
  UserDto user;

  /// Signed authentication (identity) token; a bearer secret.
  String authToken;

  /// Signed authorization token carrying the resolved grade matrix; a bearer
  /// secret.
  String authzToken;

  /// When the token pair expires (UTC).
  DateTime expiresAt;

  /// Creates a login result. [user] defaults to an empty [UserDto] and
  /// [expiresAt] to the epoch so a reflection-built instance is fully
  /// initialised before its fields are filled.
  LoginResult({
    UserDto? user,
    this.authToken = '',
    this.authzToken = '',
    DateTime? expiresAt,
  })  : user = user ?? UserDto(),
        expiresAt =
            expiresAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  @override
  String toString() =>
      'LoginResult(${user.username}, expiresAt: ${expiresAt.toUtc().toIso8601String()})';
}
