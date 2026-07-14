/// The live [AppBackend]: delegates to `advanced_client_core` over HTTP
/// (step 26).
///
/// This is the production wiring the app bootstrap (step 27) installs: an
/// [AuthClient] against `advanced_auth_server` for login/logout/token storage,
/// and an [AppApiClient] (over the shared [AuthorizedHttp]) against
/// `advanced_app_server` for the board operations. Both share one
/// [JsonTransport], so the bearer the login stores is the one every later call
/// presents, and a single token expiry self-heals.
///
/// The class is a thin adapter: it forwards each [AppBackend] method to its
/// client-core counterpart and normalises the client core's transport exceptions
/// (`AuthClientException`/`AppApiException`/`TomAuthExpiredException`) into the
/// single [AppBackendException] the screens catch. The parsers it relies on build
/// reflected entities, so the bootstrap must call `initializeReflection()` before
/// the first call.
///
/// **Live resourceRoles are not yet wired (RCB5).** Since RCC2 the app resolves
/// field grades by installing the principal's `resourceRoles` as a framework
/// [TomResourceRoleAdapter] (see [resourceRoles]). This Flutter-free client treats
/// the authorization token as an opaque bearer (`decryptTokens: false`), so it
/// cannot read the token's `resourceRoles` claim, and the app server exposes no
/// endpoint that returns it. Until RCB5 delivers one (a readable claim or a
/// `/resource-roles` endpoint) plus reconciles the surrogate/business id-space,
/// [resourceRoles] returns empty against the live stack — every field resolves
/// closed-safe to [TomAuthState.none]. The seeded [InMemoryAppBackend] (what the
/// widget tests drive) already supplies real grants, so the teaching path is
/// complete; the live gap is tracked, not silently degraded.
library;

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'app_backend.dart';

/// An [AppBackend] backed by the live auth + app servers through
/// `advanced_client_core`.
class LiveAppBackend implements AppBackend {
  final AuthClient _auth;
  final AppApiClient _api;

  /// Builds the backend over an [AuthClient] (login/token storage) and an
  /// [AppApiClient] (the authenticated board API). They are expected to share a
  /// single [JsonTransport] so the stored bearer flows from one to the other.
  LiveAppBackend(this._auth, this._api);

  /// Self-wires the live backend from the [AdvancedClientConfig] config bean:
  /// resolves the auth + app server URLs, shares one [IoJsonTransport] between
  /// the [AuthClient] (login/token storage) and the [AuthorizedHttp] the
  /// [AppApiClient] sends on, so the bearer the login stores is the one every
  /// board call presents.
  ///
  /// This is the factory the app bootstrap registers as the `prod`-environment
  /// backend; it reads its URLs from the config bean, never from
  /// `String.fromEnvironment` (G-ENV-2). Call [AdvancedClientConfig.registerDefault]
  /// before this.
  factory LiveAppBackend.fromConfig() {
    final config = AdvancedClientConfig.resolve();
    final transport = IoJsonTransport();
    final auth =
        AuthClient(Uri.parse(config.authServerUrl), transport: transport);
    final api = AppApiClient(
        Uri.parse(config.appServerUrl), AuthorizedHttp(transport, auth));
    return LiveAppBackend(auth, api);
  }

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
  Future<List<Workspace>> listWorkspaces() =>
      _guard(() => _api.listWorkspaces());

  @override
  Future<List<Project>> listProjects(String workspaceId) =>
      _guard(() => _api.listProjects(workspaceId));

  @override
  Future<List<TodoList>> listLists(String projectId) =>
      _guard(() => _api.listLists(projectId));

  @override
  Future<List<TodoItem>> listItems(String listId) =>
      _guard(() => _api.listItems(listId));

  @override
  Future<TodoItem> saveItem(TodoItem item) => _guard(() {
        // An empty id means "create"; the server assigns the primary key. On
        // update the addressed item is carried on `item.id` (the `{id}` path
        // capture binds back onto it server-side).
        return item.id.get().isEmpty
            ? _api.createItem(item)
            : _api.updateItem(item);
      });

  @override
  Future<void> deleteItem(String id) =>
      _guard(() => _api.deleteItem(EntityIdRequest(id: id)));

  @override
  Future<TodoComment> addComment(String itemId, TodoComment comment) =>
      // The addressed item travels on the comment's `itemId` field, which the
      // `{id}` → `itemId` mapping binds server-side.
      _guard(() => _api.addComment(comment..itemId.set(itemId)));

  @override
  Future<Map<String, String>> resourceRoles() async {
    // Not yet wired against the live stack (RCB5): the authorization token is an
    // opaque bearer here (`decryptTokens: false`), so its `resourceRoles` claim
    // is unreadable, and the app server exposes no endpoint that returns the
    // grant map. Returning empty is honest — the framework adapter resolves every
    // resource key to none — rather than silently degrading. The seeded
    // in-memory backend supplies real grants for the teaching path and tests.
    return const {};
  }

  @override
  Future<void> share(ShareRequest request) =>
      _guard(() => _api.share(request));

  /// Runs [op], translating the client core's typed transport failures into the
  /// single [AppBackendException] the UI catches (preserving the server's stable
  /// error key).
  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on TomException catch (e) {
      // AuthClientException / AppApiException / TomAuthExpiredException all
      // extend TomException and carry the server's stable key + message.
      throw AppBackendException(e.defaultUserMessage, key: e.key);
    }
  }
}
