import 'package:advanced_todo_domain/advanced_todo_domain.dart' show UserStatus;
import 'package:tom_core_kernel/tom_core_kernel.dart' show TomJsonSerializable;

/// Credentials posted to `POST /auth/login`.
///
/// [app] and [org] scope the login to a tenant/application the way the real
/// `tom_uam` auth server does, so one auth server can serve several apps. The
/// password is never echoed by [toString] (it must not reach logs — see the
/// sample's security notes), but it is part of [==]/[hashCode] because two
/// requests differing only by password are genuinely different requests.
class LoginRequest {
  /// The account's login name.
  final String username;

  /// The plaintext password, verified server-side against a kernel hash. Never
  /// logged or rendered by [toString].
  final String password;

  /// Application the login targets (tenant scoping).
  final String app;

  /// Organisation the login targets (tenant scoping).
  final String org;

  /// Creates a login request. All fields default to empty so a partially built
  /// form maps cleanly.
  const LoginRequest({
    this.username = '',
    this.password = '',
    this.app = '',
    this.org = '',
  });

  /// Rebuilds a request from its JSON shape `{username, password, app, org}`.
  factory LoginRequest.fromJson(Map<String, Object?> json) => LoginRequest(
        username: (json['username'] as String?) ?? '',
        password: (json['password'] as String?) ?? '',
        app: (json['app'] as String?) ?? '',
        org: (json['org'] as String?) ?? '',
      );

  /// JSON shape `{username, password, app, org}`.
  Map<String, Object?> toJson() => {
        'username': username,
        'password': password,
        'app': app,
        'org': org,
      };

  @override
  bool operator ==(Object other) =>
      other is LoginRequest &&
      other.username == username &&
      other.password == password &&
      other.app == app &&
      other.org == org;

  @override
  int get hashCode => Object.hash(username, password, app, org);

  @override
  String toString() => 'LoginRequest($username, app: $app, org: $org)';
}

/// A user account projected onto the wire — the safe, password-free view the
/// auth server returns from login and the admin API returns from
/// `GET /admin/users`.
///
/// [status] travels as the [UserStatus.name] token (`active`/`suspended`); use
/// [statusValue] for the typed enum. Deliberately a flat record (not the
/// reflected `User` entity) so it carries clean value equality across the wire.
///
/// Implements [TomJsonSerializable] so the endpoint pipeline serializes a
/// single-`UserDto` result (e.g. `createUser`/`updateUser`) through [toJson]
/// rather than the reflection serializer, which would drop its `final` fields.
class UserDto implements TomJsonSerializable {
  /// Stable identifier (the auth server's primary key).
  final String id;

  /// The account's login name.
  final String username;

  /// Human-facing name shown in the UI.
  final String displayName;

  /// Contact email.
  final String email;

  /// Account lifecycle state as a [UserStatus.name] token; use [statusValue].
  final String status;

  /// Creates a user projection. [status] defaults to `active`.
  UserDto({
    this.id = '',
    this.username = '',
    this.displayName = '',
    this.email = '',
    String? status,
  }) : status = status ?? UserStatus.active.name;

  /// Rebuilds a user from its JSON shape. An unknown [status] token is kept
  /// verbatim on the wire field; [statusValue] resolves it leniently.
  factory UserDto.fromJson(Map<String, Object?> json) => UserDto(
        id: (json['id'] as String?) ?? '',
        username: (json['username'] as String?) ?? '',
        displayName: (json['displayName'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
        status: json['status'] as String?,
      );

  /// Typed view of [status]; falls back to [UserStatus.active] for an unknown
  /// stored value.
  UserStatus get statusValue =>
      UserStatus.values.asNameMap()[status] ?? UserStatus.active;

  /// JSON shape `{id, username, displayName, email, status}`.
  @override
  Map<String, Object?> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        'email': email,
        'status': status,
      };

  @override
  bool operator ==(Object other) =>
      other is UserDto &&
      other.id == id &&
      other.username == username &&
      other.displayName == displayName &&
      other.email == email &&
      other.status == status;

  @override
  int get hashCode => Object.hash(id, username, displayName, email, status);

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
/// bearer secrets) but are part of [==]/[hashCode].
///
/// Implements [TomJsonSerializable] so the endpoint pipeline serializes the
/// `/auth/login` and `/auth/refresh` result through [toJson] rather than the
/// reflection serializer, which would drop its `final` fields (the gap that
/// previously made a live login return an empty `{}` body / 500).
class LoginResult implements TomJsonSerializable {
  /// The authenticated principal, password-free.
  final UserDto user;

  /// Signed authentication (identity) token; a bearer secret.
  final String authToken;

  /// Signed authorization token carrying the resolved grade matrix; a bearer
  /// secret.
  final String authzToken;

  /// When the token pair expires (UTC).
  final DateTime expiresAt;

  /// Creates a login result.
  LoginResult({
    required this.user,
    required this.authToken,
    required this.authzToken,
    required this.expiresAt,
  });

  /// Rebuilds a result from its JSON shape `{user, authToken, authzToken,
  /// expiresAt}`, with [expiresAt] as an ISO-8601 string.
  factory LoginResult.fromJson(Map<String, Object?> json) => LoginResult(
        user: UserDto.fromJson(
            (json['user'] as Map?)?.cast<String, Object?>() ?? const {}),
        authToken: (json['authToken'] as String?) ?? '',
        authzToken: (json['authzToken'] as String?) ?? '',
        expiresAt:
            DateTime.parse((json['expiresAt'] as String?) ?? '').toUtc(),
      );

  /// JSON shape `{user, authToken, authzToken, expiresAt}` with [expiresAt] as
  /// an ISO-8601 UTC string.
  @override
  Map<String, Object?> toJson() => {
        'user': user.toJson(),
        'authToken': authToken,
        'authzToken': authzToken,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is LoginResult &&
      other.user == user &&
      other.authToken == authToken &&
      other.authzToken == authzToken &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(user, authToken, authzToken, expiresAt);

  @override
  String toString() =>
      'LoginResult(${user.username}, expiresAt: ${expiresAt.toUtc().toIso8601String()})';
}
