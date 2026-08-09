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
/// (`AuthClientException`/`AdminApiException`/`TomAuthExpiredException`) into the
/// single [AdminBackendException] the screens catch — preserving the server's
/// stable error key, so the shell can still reject a non-admin login by keying on
/// the `admin`-role gate's denial. The admin DTOs are reflection-first, so every
/// call here reaches `dtoFromJson`/`dtoToJsonString` inside the client core: the
/// console's `initializeReflection()` must have run before the first request.
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

  /// Bytes to and from the auth server's file endpoint, under the same session
  /// the JSON calls use.
  @override
  final TomFileTransferClient files;

  /// Builds the backend over an [AuthClient] (login/token storage), an
  /// [AdminApiClient] (the authenticated `/admin/*` API) and a [files] client
  /// (the avatar slots). They are expected to share a single [JsonTransport] so
  /// the stored bearer flows from one to the other.
  LiveAdminBackend(this._auth, this._api, this.files);

  /// Self-wires the live backend from the [AdvancedClientConfig] config bean:
  /// resolves the auth + admin server URLs, shares one [IoJsonTransport] between
  /// the [AuthClient] (login/token storage) and the [AuthorizedHttp] the
  /// [AdminApiClient] sends on, so the bearer the login stores is the one every
  /// `/admin/*` call presents.
  ///
  /// The file client rides that same [AuthorizedHttp]:
  /// [authenticatedFileTransferClient] takes it precisely so the bytes present
  /// the credential the JSON calls present and refresh through the one
  /// [TomAuthRefresher] the session already holds. It is the *identical*
  /// function the app client wires against `advanced_app_server`, pointed here
  /// at the auth server — which is the point of putting an avatar on this
  /// console at all: one authenticated file client, two servers, no second
  /// token path.
  ///
  /// This is the factory the admin bootstrap registers as the `prod`-environment
  /// backend; it reads its URLs from the config bean, never from
  /// `String.fromEnvironment` (G-ENV-2). Call
  /// [AdvancedClientConfig.registerDefault] before this.
  factory LiveAdminBackend.fromConfig() {
    final config = AdvancedClientConfig.resolve();
    final transport = IoJsonTransport();
    final authServer = Uri.parse(config.authServerUrl);
    final auth = AuthClient(authServer, transport: transport);
    final http = AuthorizedHttp(transport, auth);
    final api = AdminApiClient(Uri.parse(config.adminServerUrl), http);
    // The avatar slot lives on the auth server (`auth_users.avatar_ref`), so the
    // file client is pointed at `authServer`, not at `adminServerUrl`.
    return LiveAdminBackend(
      auth,
      api,
      authenticatedFileTransferClient(authServer, http),
    );
  }

  @override
  Future<LoginResult> login(LoginRequest request) =>
      _guard(() => _auth.login(request));

  @override
  Future<LoginResult> submitSecondFactor(String code) =>
      _guard(() => _auth.submitSecondFactor(code));

  @override
  Tom2FAChallenge? get pendingChallenge => _auth.pendingChallenge;

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
      _guard(() => _api.updateUser(user..id = id));

  @override
  Future<void> deleteUser(String id) =>
      _guard(() => _api.deleteUser(EntityIdRequest(id: id)));

  @override
  Future<List<RoleDto>> listRoles() => _guard(() => _api.listRoles());

  @override
  Future<RoleDto> createRole(RoleDto role) =>
      _guard(() => _api.createRole(role));

  @override
  Future<RoleDto> updateRole(String key, RoleDto role) =>
      _guard(() => _api.updateRole(role..key = key));

  @override
  Future<void> deleteRole(String key) =>
      _guard(() => _api.deleteRole(EntityIdRequest(id: key)));

  @override
  Future<List<GroupDto>> listGroups() => _guard(() => _api.listGroups());

  @override
  Future<GroupDto> createGroup(GroupDto group) =>
      _guard(() => _api.createGroup(group));

  @override
  Future<GroupDto> updateGroup(String id, GroupDto group) =>
      _guard(() => _api.updateGroup(group..id = id));

  @override
  Future<void> deleteGroup(String id) =>
      _guard(() => _api.deleteGroup(EntityIdRequest(id: id)));

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
  ///
  /// [AuthClientException] is matched first for its one extra bit,
  /// `canRetrySecondFactor` — dropping it would leave the login screen unable to
  /// tell "wrong code, try again" from "the challenge is spent".
  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on AuthClientException catch (e) {
      throw AdminBackendException(
        e.defaultUserMessage,
        key: e.key,
        canRetrySecondFactor: e.canRetrySecondFactor,
      );
    } on TomException catch (e) {
      // AdminApiException / TomAuthExpiredException also extend TomException and
      // carry the server's stable key + message.
      throw AdminBackendException(e.defaultUserMessage, key: e.key);
    }
  }
}
