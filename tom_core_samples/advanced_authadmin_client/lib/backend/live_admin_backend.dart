/// The live [AdminBackend]: delegates to `advanced_client_core` over HTTP
/// (step 32).
///
/// This is the production wiring the admin bootstrap (step 33) installs: an
/// [AuthClient] against `advanced_auth_server` for login/logout/token storage,
/// and an [AdminApiClient] (over the shared [AuthorizedHttp]) against the same
/// auth server's `/admin/*` API. Both share one [JsonTransport], so the bearer
/// the login stores is the one every admin call presents, and a single token
/// expiry self-heals.
///
/// The class is a thin adapter: it forwards each [AdminBackend] method to its
/// client-core counterpart and normalises the client core's transport exceptions
/// (`AuthClientException`/`AdminApiException`/`AuthorizedHttpException`) into the
/// single [AdminBackendException] the screens catch — preserving the server's
/// stable error key, so the shell can still reject a non-admin login by keying on
/// the `admin`-role gate's denial. The admin DTOs are plain records, so this
/// backend needs no reflection.
library;

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'admin_backend.dart';

/// An [AdminBackend] backed by the live auth server through
/// `advanced_client_core`.
class LiveAdminBackend implements AdminBackend {
  final AuthClient _auth;
  final AdminApiClient _api;

  /// Builds the backend over an [AuthClient] (login/token storage) and an
  /// [AdminApiClient] (the authenticated `/admin/*` API). They are expected to
  /// share a single [JsonTransport] so the stored bearer flows from one to the
  /// other.
  LiveAdminBackend(this._auth, this._api);

  @override
  Future<LoginResult> login(LoginRequest request) =>
      _guard(() => _auth.login(request));

  @override
  Future<void> logout() => _guard(() => _auth.logout());

  @override
  Future<ResourceBundleDto> loginResources() =>
      _guard(() => _auth.loginResources());

  @override
  Future<ResourceBundleDto> resources() => _guard(() => _api.resources());

  @override
  Future<List<UserDto>> listUsers() => _guard(() => _api.listUsers());

  @override
  Future<UserDto> createUser(CreateUserRequest request) =>
      _guard(() => _api.createUser(request));

  @override
  Future<UserDto> updateUser(String id, UserDto user) =>
      _guard(() => _api.updateUser(id, user));

  @override
  Future<void> deleteUser(String id) => _guard(() => _api.deleteUser(id));

  @override
  Future<List<RoleDto>> listRoles() => _guard(() => _api.listRoles());

  @override
  Future<RoleDto> createRole(RoleDto role) =>
      _guard(() => _api.createRole(role));

  @override
  Future<RoleDto> updateRole(String key, RoleDto role) =>
      _guard(() => _api.updateRole(key, role));

  @override
  Future<void> deleteRole(String key) => _guard(() => _api.deleteRole(key));

  @override
  Future<List<GroupDto>> listGroups() => _guard(() => _api.listGroups());

  @override
  Future<GroupDto> createGroup(GroupDto group) =>
      _guard(() => _api.createGroup(group));

  @override
  Future<GroupDto> updateGroup(String id, GroupDto group) =>
      _guard(() => _api.updateGroup(id, group));

  @override
  Future<void> deleteGroup(String id) => _guard(() => _api.deleteGroup(id));

  @override
  Future<GrantMatrixDto> getGrants() => _guard(() => _api.getGrants());

  @override
  Future<void> putGrants(GrantMatrixDto matrix) =>
      _guard(() => _api.putGrants(matrix));

  @override
  Future<void> assign(AssignmentRequest request) =>
      _guard(() => _api.assign(request));

  /// Runs [op], translating the client core's typed transport failures into the
  /// single [AdminBackendException] the UI catches (preserving the server's
  /// stable error key).
  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on TomException catch (e) {
      // AuthClientException / AdminApiException / AuthorizedHttpException all
      // extend TomException and carry the server's stable key + message.
      throw AdminBackendException(e.defaultUserMessage, key: e.key);
    }
  }
}
