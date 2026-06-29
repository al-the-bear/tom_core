/// The typed client over `advanced_auth_server`'s `/admin/*` API (step 25).
///
/// Like [AppApiClient], every call goes through [AuthorizedHttp] — so the bearer
/// is attached and a single token expiry self-heals (refresh-once-on-401) — and
/// the JSON↔DTO mapping is split into **pure** top-level `parse*` functions so it
/// is unit-tested against captured server responses with no socket. The admin
/// DTOs (`UserDto`/`RoleDto`/`GroupDto`/`GrantMatrixDto`) are plain value records
/// that already own a `fromJson`, so the parsers are thin, total wrappers (the
/// same discipline as `parseFieldStates` over `GradedFieldDto.fromJson`).
///
/// **Wire contract.** The auth server returns the framework serialization of the
/// service method's result (`tom_core_server`'s endpoint pipeline, lines 377-387):
///
/// - A **list** result (`adminListUsers`/`adminListRoles`/`adminListGroups`)
///   matches the pipeline's `result is List<Object>` branch and is serialized as
///   `jsonEncode(list)`, whose default encoder calls each element's `toJson()` —
///   so a list arrives as a *bare* JSON array of correctly-shaped DTO maps (no
///   `{items:[…]}` envelope). The parsers read `response.jsonArray`.
/// - A **void** result (the deletes, `adminPutGrants`, `adminAssign`) is an empty
///   `200` body — nothing to parse.
///
/// > **Known server gap (out of scope here).** A *single* DTO result
/// > (`adminCreateUser`/`adminUpdateUser`/`adminCreateRole`/`adminUpdateRole`/
/// > `adminCreateGroup`/`adminUpdateGroup`/`adminGetGrants`) is **not** a
/// > `TomClass`, a `Map`, or a `List`, so the pipeline falls through to
/// > `tomReflectionInfo.convertToJsonString` — the reflection serializer that
/// > reads `getValues`, skips final fields, and looks for a `jsonEncode` getter
/// > rather than `toJson`. A plain all-`final` DTO therefore serializes to `{}`
/// > over the live wire (the same pre-existing gap step 22 flagged for the
/// > `LoginResult` login response — owned by the auth-server/kernel steps, not
/// > this client step). These client methods are implemented to the *intended*
/// > contract — their parsers are correct against a correctly-shaped body, and
/// > the in-memory admin fake (step 32) and a fixed server both round-trip — but
/// > a single-DTO response cannot round-trip against the live server until that
/// > gap is fixed. The integration smoke therefore exercises a *list* endpoint
/// > (`adminListUsers`), which serializes correctly today. See
/// > `step25_admin_api_client_decisions.md`.
///
/// A denial the server maps to a non-success status (a `{"error": key}` body,
/// e.g. the `admin`-role gate's `403`) surfaces as a typed [AdminApiException]
/// carrying that stable key; a persistent `401` was already turned into an
/// `AuthorizedHttpException` by the wrapper before it reaches here.
///
/// No reflection is required: the admin DTOs are plain records (unlike the app
/// API's reflected entities), so this client needs neither `initializeReflection`
/// nor a domain dependency.
library;

import 'dart:convert';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../http/authorized_http.dart';
import '../http/json_transport.dart';

/// Raised when an admin-API call returns a non-success status the wrapper did not
/// already handle (a 401 becomes an `AuthorizedHttpException` upstream).
///
/// Carries the HTTP [statusCode] and the server's stable error [key] from the
/// `{"error": key}` body (e.g. `endpoint_handler.handle_method_call.access_denied`
/// → 403 for a non-admin caller), so a UI can branch on the key without parsing a
/// message.
class AdminApiException extends TomException {
  /// The HTTP status that triggered this.
  final int statusCode;

  /// Builds the exception from the server's stable [key], a human
  /// [defaultUserMessage] and the originating [statusCode].
  AdminApiException(
    super.key,
    super.defaultUserMessage, {
    required this.statusCode,
  });
}

/// Parses one `UserDto` from its wire map.
UserDto parseUser(Map<String, Object?> json) => UserDto.fromJson(json);

/// Parses a bare array of user maps into [UserDto]s.
List<UserDto> parseUsers(List<Object?> body) =>
    [for (final e in body) UserDto.fromJson(_asMap(e))];

/// Parses one `RoleDto` from its wire map.
RoleDto parseRole(Map<String, Object?> json) => RoleDto.fromJson(json);

/// Parses a bare array of role maps into [RoleDto]s.
List<RoleDto> parseRoles(List<Object?> body) =>
    [for (final e in body) RoleDto.fromJson(_asMap(e))];

/// Parses one `GroupDto` (with its membership) from its wire map.
GroupDto parseGroup(Map<String, Object?> json) => GroupDto.fromJson(json);

/// Parses a bare array of group maps into [GroupDto]s.
List<GroupDto> parseGroups(List<Object?> body) =>
    [for (final e in body) GroupDto.fromJson(_asMap(e))];

/// Parses the `GET /admin/grants` body — the `{role: {resourceKey: accessToken}}`
/// matrix — into a [GrantMatrixDto]. Unknown access tokens degrade to
/// [TomAuthState.none] (closed-safe) via [GrantMatrixDto.fromJson].
GrantMatrixDto parseGrantMatrix(Map<String, Object?> json) =>
    GrantMatrixDto.fromJson(json);

Map<String, Object?> _asMap(Object? element) =>
    (element as Map).cast<String, Object?>();

/// The typed client over the auth server's `/admin/*` endpoints (the `adminApi`
/// registry).
///
/// Implements [AdminApiService] so it is the live seam the authadmin client's
/// backend plugs in (step 32); the in-memory fake implements the same interface
/// for widget tests. All transport flows through the supplied [AuthorizedHttp],
/// which carries the `admin` principal's bearer.
class AdminApiClient implements AdminApiService {
  /// Base URL of the auth server, e.g. `http://localhost:8081` (no path suffix —
  /// each endpoint adds its own absolute `/admin/...` path).
  final Uri baseUri;

  final AuthorizedHttp _http;

  /// Builds the client against [baseUri], sending every call through [http].
  AdminApiClient(this.baseUri, AuthorizedHttp http) : _http = http;

  // ----- Users -------------------------------------------------------------

  @override
  Future<List<UserDto>> listUsers() async =>
      parseUsers((await _get('/admin/users')).jsonArray);

  @override
  Future<UserDto> createUser(CreateUserRequest request) async => parseUser(
        (await _send('POST', '/admin/users',
                body: jsonEncode(request.toJson())))
            .jsonObject,
      );

  @override
  Future<UserDto> updateUser(String id, UserDto user) async => parseUser(
        (await _send('PUT', '/admin/users/$id',
                body: jsonEncode(user.toJson())))
            .jsonObject,
      );

  @override
  Future<void> deleteUser(String id) async =>
      _send('DELETE', '/admin/users/$id');

  // ----- Roles -------------------------------------------------------------

  @override
  Future<List<RoleDto>> listRoles() async =>
      parseRoles((await _get('/admin/roles')).jsonArray);

  @override
  Future<RoleDto> createRole(RoleDto role) async => parseRole(
        (await _send('POST', '/admin/roles', body: jsonEncode(role.toJson())))
            .jsonObject,
      );

  @override
  Future<RoleDto> updateRole(String key, RoleDto role) async => parseRole(
        (await _send('PUT', '/admin/roles/$key',
                body: jsonEncode(role.toJson())))
            .jsonObject,
      );

  @override
  Future<void> deleteRole(String key) async =>
      _send('DELETE', '/admin/roles/$key');

  // ----- Groups ------------------------------------------------------------

  @override
  Future<List<GroupDto>> listGroups() async =>
      parseGroups((await _get('/admin/groups')).jsonArray);

  @override
  Future<GroupDto> createGroup(GroupDto group) async => parseGroup(
        (await _send('POST', '/admin/groups',
                body: jsonEncode(group.toJson())))
            .jsonObject,
      );

  @override
  Future<GroupDto> updateGroup(String id, GroupDto group) async => parseGroup(
        (await _send('PUT', '/admin/groups/$id',
                body: jsonEncode(group.toJson())))
            .jsonObject,
      );

  @override
  Future<void> deleteGroup(String id) async =>
      _send('DELETE', '/admin/groups/$id');

  // ----- Grants + assignments ----------------------------------------------

  @override
  Future<GrantMatrixDto> getGrants() async =>
      parseGrantMatrix((await _get('/admin/grants')).jsonObject);

  @override
  Future<void> putGrants(GrantMatrixDto matrix) async =>
      _send('PUT', '/admin/grants', body: jsonEncode(matrix.toJson()));

  @override
  Future<void> assign(AssignmentRequest request) async =>
      _send('POST', '/admin/assignments', body: jsonEncode(request.toJson()));

  @override
  Future<ResourceBundleDto> resources() async =>
      ResourceBundleDto.fromJson((await _get('/admin/resources')).jsonObject);

  Future<HttpJsonResponse> _get(String path,
          [Map<String, String> query = const {}]) =>
      _send('GET', path, query: query);

  /// Sends [method] to [path] (with optional [query]/[body]) through the
  /// authorized transport and returns the response, throwing [AdminApiException]
  /// on any non-success status (reading the server's stable error key).
  Future<HttpJsonResponse> _send(
    String method,
    String path, {
    Map<String, String> query = const {},
    String? body,
  }) async {
    final response =
        await _http.send(method: method, uri: _uri(path, query), body: body);
    if (!response.isSuccess) {
      throw AdminApiException(
        _errorKey(response) ?? 'admin.request.failed',
        'Admin API $method $path failed (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    return response;
  }

  /// Resolves the absolute [path] (and optional [query]) against [baseUri].
  Uri _uri(String path, [Map<String, String> query = const {}]) {
    final base = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    return baseUri.replace(
      path: '$base$path',
      queryParameters: query.isEmpty ? null : query,
    );
  }

  /// The server's stable error key from a `{"error": "..."}` body, or null.
  String? _errorKey(HttpJsonResponse response) {
    try {
      final key = response.jsonObject['error'];
      return key is String ? key : null;
    } on FormatException {
      return null;
    }
  }
}
