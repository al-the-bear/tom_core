/// The typed client over `advanced_auth_server`'s `/admin/*` API (step 25).
///
/// Like [AppApiClient], every call goes through [AuthorizedHttp] — so the bearer
/// is attached and a single token expiry self-heals (refresh-once-on-401) — and
/// the JSON↔DTO mapping is split into **pure** top-level `parse*` functions so it
/// is unit-tested against captured server responses with no socket. The admin
/// DTOs (`UserDto`/`RoleDto`/`GroupDto`/`GrantMatrixDto`) are reflection-first
/// value records, so the parsers are thin, total wrappers over `dtoFromJson<T>`
/// (the same discipline as `parseFieldStates` over `dtoFromJson<GradedFieldDto>`).
///
/// **Wire contract.** The auth server returns the framework serialization of the
/// service method's result (`tom_core_server`'s endpoint pipeline):
///
/// - A **list** result (`adminListUsers`/`adminListRoles`/`adminListGroups`)
///   matches the pipeline's `result is List<Object>` branch and is serialized
///   element-by-element via the reflection encoder — so a list arrives as a
///   *bare* JSON array of correctly-shaped DTO maps (no `{items:[…]}` envelope).
///   The parsers read `response.jsonArray`.
/// - A **single** DTO result (`adminCreateUser`/`adminUpdateUser`/…/
///   `adminGetGrants`) falls to the pipeline's reflection serializer
///   (`convertToJsonString`), which reads the reflected fields into a correctly
///   shaped map. The parsers read `response.jsonObject`.
/// - A **void** result (the deletes, `adminPutGrants`, `adminAssign`) is an empty
///   `200` body — nothing to parse.
///
/// A denial the server maps to a non-success status (a `{"error": key}` body,
/// e.g. the `admin`-role gate's `403`) surfaces as a typed [AdminApiException]
/// carrying that stable key; a persistent `401` was already turned into an
/// `TomAuthExpiredException` by the wrapper before it reaches here.
///
/// The reflection round-trip requires the DTO seed to be installed once
/// (`initializeReflection`) — the same seed the app client and servers build.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../http/authorized_http.dart';
import '../http/json_transport.dart';

/// Raised when an admin-API call returns a non-success status the wrapper did not
/// already handle (a 401 becomes an `TomAuthExpiredException` upstream).
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
UserDto parseUser(Map<String, Object?> json) => dtoFromJson<UserDto>(json);

/// Parses a bare array of user maps into [UserDto]s.
List<UserDto> parseUsers(List<Object?> body) =>
    [for (final e in body) dtoFromJson<UserDto>(_asMap(e))];

/// Parses one `RoleDto` from its wire map.
RoleDto parseRole(Map<String, Object?> json) => dtoFromJson<RoleDto>(json);

/// Parses a bare array of role maps into [RoleDto]s.
List<RoleDto> parseRoles(List<Object?> body) =>
    [for (final e in body) dtoFromJson<RoleDto>(_asMap(e))];

/// Parses one `GroupDto` (with its membership) from its wire map.
GroupDto parseGroup(Map<String, Object?> json) => dtoFromJson<GroupDto>(json);

/// Parses a bare array of group maps into [GroupDto]s.
List<GroupDto> parseGroups(List<Object?> body) =>
    [for (final e in body) dtoFromJson<GroupDto>(_asMap(e))];

/// Parses the `GET /admin/grants` body — the `{matrix: {role: {resourceKey:
/// accessToken}}}` map — into a [GrantMatrixDto]. Unknown access tokens degrade
/// to [TomAuthState.none] (closed-safe) at read time via [GrantMatrixDto.accessFor].
GrantMatrixDto parseGrantMatrix(Map<String, Object?> json) =>
    dtoFromJson<GrantMatrixDto>(json);

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
                body: dtoToJsonString(request)))
            .jsonObject,
      );

  @override
  Future<UserDto> updateUser(UserDto user) async => parseUser(
        (await _send('PUT', '/admin/users/${user.id}',
                body: dtoToJsonString(user)))
            .jsonObject,
      );

  @override
  Future<void> deleteUser(EntityIdRequest request) async =>
      _send('DELETE', '/admin/users/${request.id}');

  // ----- Roles -------------------------------------------------------------

  @override
  Future<List<RoleDto>> listRoles() async =>
      parseRoles((await _get('/admin/roles')).jsonArray);

  @override
  Future<RoleDto> createRole(RoleDto role) async => parseRole(
        (await _send('POST', '/admin/roles', body: dtoToJsonString(role)))
            .jsonObject,
      );

  @override
  Future<RoleDto> updateRole(RoleDto role) async => parseRole(
        (await _send('PUT', '/admin/roles/${role.key}',
                body: dtoToJsonString(role)))
            .jsonObject,
      );

  @override
  Future<void> deleteRole(EntityIdRequest request) async =>
      _send('DELETE', '/admin/roles/${request.id}');

  // ----- Groups ------------------------------------------------------------

  @override
  Future<List<GroupDto>> listGroups() async =>
      parseGroups((await _get('/admin/groups')).jsonArray);

  @override
  Future<GroupDto> createGroup(GroupDto group) async => parseGroup(
        (await _send('POST', '/admin/groups',
                body: dtoToJsonString(group)))
            .jsonObject,
      );

  @override
  Future<GroupDto> updateGroup(GroupDto group) async => parseGroup(
        (await _send('PUT', '/admin/groups/${group.id}',
                body: dtoToJsonString(group)))
            .jsonObject,
      );

  @override
  Future<void> deleteGroup(EntityIdRequest request) async =>
      _send('DELETE', '/admin/groups/${request.id}');

  // ----- Grants + assignments ----------------------------------------------

  @override
  Future<GrantMatrixDto> getGrants() async =>
      parseGrantMatrix((await _get('/admin/grants')).jsonObject);

  @override
  Future<void> putGrants(GrantMatrixDto matrix) async =>
      _send('PUT', '/admin/grants', body: dtoToJsonString(matrix));

  @override
  Future<void> assign(AssignmentRequest request) async =>
      _send('POST', '/admin/assignments', body: dtoToJsonString(request));

  @override
  Future<ResourceBundleDto> resources() async =>
      dtoFromJson<ResourceBundleDto>((await _get('/admin/resources')).jsonObject);

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
