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
/// **Live resourceRoles (RCB5).** Since RCC2 the app resolves field grades by
/// installing the principal's `resourceRoles` as a framework
/// [TomResourceRoleAdapter] (see [resourceRoles]). This Flutter-free client
/// treats the authorization token as an opaque bearer (`decryptTokens: false`),
/// so it cannot read the token's `resourceRoles` claim; instead [resourceRoles]
/// fetches the grant map from the app server's authenticated
/// `GET /resource-roles` endpoint, which resolves the principal's ownership
/// grants and share delegations and expands them down the containment chain. The
/// keys are `app_db` surrogate ids — the same ids `TodoItem.id` already carries
/// on the live wire — so `item:<id>` lookups match without id translation.
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

  @override
  final TomFileTransferClient files;

  /// Builds the backend over an [AuthClient] (login/token storage), an
  /// [AppApiClient] (the authenticated board API) and a [files] client (the
  /// byte half). All three are expected to share a single [JsonTransport] and
  /// one [AuthorizedHttp] so the stored bearer — and its refresh — flows from
  /// one to the next. [LiveAppBackend.fromConfig] is the wiring that guarantees
  /// it.
  LiveAppBackend(this._auth, this._api, this.files);

  /// Self-wires the live backend from the [AdvancedClientConfig] config bean:
  /// resolves the auth + app server URLs, shares one [IoJsonTransport] between
  /// the [AuthClient] (login/token storage) and the [AuthorizedHttp] the
  /// [AppApiClient] sends on, so the bearer the login stores is the one every
  /// board call presents.
  ///
  /// The file client is built from that **same** [AuthorizedHttp], which is why
  /// it is a local here rather than an inline argument:
  /// [authenticatedFileTransferClient] takes it precisely so the bytes ride the
  /// session the JSON already has — one stored token, one refresher. Giving the
  /// file half its own would produce the failure this tier exists to avoid, a
  /// board that loads while its attachments 401.
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
    final http = AuthorizedHttp(transport, auth);
    final appServer = Uri.parse(config.appServerUrl);
    return LiveAppBackend(
      auth,
      AppApiClient(appServer, http),
      authenticatedFileTransferClient(appServer, http),
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
  Tom2FAPendingEnrolment? get pendingEnrolment => _auth.pendingEnrolment;

  @override
  Future<LoginResult> beginEnrolment(String type) =>
      _guard(() => _auth.beginEnrolment(type));

  @override
  Future<LoginResult> confirmEnrolment(String code) =>
      _guard(() => _auth.confirmEnrolment(code));

  @override
  Future<LoginResult> skipEnrolment() => _guard(() => _auth.skipEnrolment());

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
  Future<List<FileDescriptorDto>> listAttachments(String listId) =>
      _guard(() => _api.listAttachments(listId));

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
  Future<List<TodoComment>> listComments(String itemId) =>
      _guard(() => _api.listComments(EntityIdRequest(id: itemId)));

  @override
  Future<List<Subtask>> listSubtasks(String itemId) =>
      _guard(() => _api.listSubtasks(EntityIdRequest(id: itemId)));

  @override
  Future<Subtask> addSubtask(String itemId, Subtask subtask) =>
      // As with `addComment`, the addressed item travels on the payload's
      // `itemId`, which the `{id}` → `itemId` mapping binds server-side.
      _guard(() => _api.addSubtask(subtask..itemId.set(itemId)));

  @override
  Future<Subtask> updateSubtask(Subtask subtask) =>
      _guard(() => _api.updateSubtask(subtask));

  @override
  Future<Map<String, String>> resourceRoles() =>
      _guard(() => _api.resourceRoles());

  @override
  Future<void> share(ShareRequest request) =>
      _guard(() => _api.share(request));

  /// Runs [op], translating the client core's typed transport failures into the
  /// single [AppBackendException] the UI catches (preserving the server's stable
  /// error key).
  ///
  /// [AuthClientException] is matched first for its one extra bit,
  /// `canRetrySecondFactor` — dropping it here would leave the login screen
  /// unable to tell "wrong code, try again" from "the challenge is spent".
  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on AuthClientException catch (e) {
      throw AppBackendException(
        e.defaultUserMessage,
        key: e.key,
        canRetrySecondFactor: e.canRetrySecondFactor,
      );
    } on TomException catch (e) {
      // AppApiException / TomAuthExpiredException also extend TomException and
      // carry the server's stable key + message.
      throw AppBackendException(e.defaultUserMessage, key: e.key);
    }
  }
}
