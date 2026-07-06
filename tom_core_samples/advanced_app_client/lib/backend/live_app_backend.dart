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
/// client-core counterpart, folds the server's per-field grade list into the
/// UI-shaped `resourceKey → TomAuthState` map, and normalises the client core's
/// transport exceptions (`AuthClientException`/`AppApiException`/
/// `TomAuthExpiredException`) into the single [AppBackendException] the screens
/// catch. The parsers it relies on build reflected entities, so the bootstrap
/// must call `initializeReflection()` before the first call.
library;

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'app_backend.dart';

/// The gradable item leaf keys, in display order, used to fold the server's bare
/// grade list into a closed-safe per-key map (an unsent key defaults to `none`).
///
/// Addressed by scope + `tomId` (`todo.item.<field>`), resolved at use rather
/// than pulled from a key-catalogue class (G-RES-6). Steps 24–26 derive this set
/// from the item form's field `tomId`s; it is the interim client source.
const _gradableItemKeys = <String>[
  'todo.item.title',
  'todo.item.status',
  'todo.item.priority',
  'todo.item.assigneeId',
  'todo.item.dueDate',
  'todo.item.estimate',
  'todo.item.description',
];

/// An [AppBackend] backed by the live auth + app servers through
/// `advanced_client_core`.
class LiveAppBackend implements AppBackend {
  final AuthClient _auth;
  final AppApiClient _api;

  /// Builds the backend over an [AuthClient] (login/token storage) and an
  /// [AppApiClient] (the authenticated board API). They are expected to share a
  /// single [JsonTransport] so the stored bearer flows from one to the other.
  LiveAppBackend(this._auth, this._api);

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
  Future<Map<String, TomAuthState>> itemFieldStates(String itemId) =>
      _guard(() async {
        final graded =
            await _api.itemFieldStates(EntityIdRequest(id: itemId));
        // Fold the bare grade list into a closed-safe per-key map: every
        // gradable key is present, an unsent one defaulting to none.
        final byKey = {for (final g in graded) g.resourceKey: g.accessState};
        return {
          for (final key in _gradableItemKeys)
            key: byKey[key] ?? TomAuthState.none,
        };
      });

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
