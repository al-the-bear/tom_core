/// The backend contract the end-user app talks to, independent of transport
/// (step 26).
///
/// Every screen (steps 27–31) is written against this seam, not a concrete
/// backend, so the same widgets drive either the seeded [InMemoryAppBackend]
/// (the offline teaching default — and what the widget tests bind, never
/// touching a socket) or the [LiveAppBackend], which delegates to
/// `advanced_client_core` over HTTP. Keeping the seam here is what makes the
/// widget tests deterministic.
///
/// The seam speaks the shared **wire contracts** ([LoginRequest]/[LoginResult]/
/// [ShareRequest]) and the reflected **domain entities** ([Workspace]/[Project]/
/// [TodoList]/[TodoItem]/[TodoComment]) — exactly the currency the live client
/// core exchanges — plus one UI-shaped convenience, [itemFieldStates], which
/// folds the server's per-field grade list into a `resourceKey → TomAuthState`
/// map the bound forms render directly.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Raised when a backend call fails — rejected credentials, an unknown resource,
/// or a denied write.
///
/// A single typed failure the screens catch and surface: the in-memory backend
/// throws it directly, and [LiveAppBackend] wraps the client core's transport
/// exceptions (`AuthClientException`/`AppApiException`/`TomAuthExpiredException`)
/// in it. It carries a human [message] to show the user and, when the underlying
/// failure had one, the server's stable error [key] so a caller can branch
/// without parsing the message.
class AppBackendException implements Exception {
  /// What went wrong, fit to show the user.
  final String message;

  /// The server's stable error key when one was available (e.g.
  /// `auth.login.failed`, `app.access.forbidden`), else null.
  final String? key;

  /// Creates the exception with a human [message] and an optional stable [key].
  const AppBackendException(this.message, {this.key});

  @override
  String toString() =>
      'AppBackendException: $message${key == null ? '' : ' ($key)'}';
}

/// The end-user todo backend the app reads and edits against.
///
/// Reads are filtered to what the logged-in principal owns or is shared into;
/// writes are re-checked field-by-field against the principal's four-state
/// grade. The live implementation enforces this server-side; the in-memory fake
/// mirrors the same model so the client behaves identically either way.
abstract class AppBackend {
  /// Authenticates [request], stores the session, and returns the resolved
  /// principal + token pair. Throws [AppBackendException] when rejected.
  Future<LoginResult> login(LoginRequest request);

  /// Ends the session and discards the stored token pair.
  Future<void> logout();

  /// Fetches the public login resource bundle (screen texts) the app installs
  /// before the sign-in screen builds. Reachable unauthenticated.
  Future<ResourceBundleDto> loginResources();

  /// Fetches the authenticated full resource bundle (every screen's texts) the
  /// app installs right after sign-in, so the board, item form, and sharing
  /// chrome render server-delivered strings. Requires a session.
  Future<ResourceBundleDto> resources();

  /// Workspaces the current principal owns or is shared into.
  Future<List<Workspace>> listWorkspaces();

  /// Visible projects in [workspaceId].
  Future<List<Project>> listProjects(String workspaceId);

  /// Lists in the visible project [projectId].
  Future<List<TodoList>> listLists(String projectId);

  /// Items in the visible list [listId]; pair with [itemFieldStates] for the
  /// per-field grade matrix.
  Future<List<TodoItem>> listItems(String listId);

  /// Creates ([TodoItem.id] empty) or updates an item, returning the persisted
  /// entity (with its assigned id). A write to a field the principal's grade is
  /// not `full` on is rejected server-side with an [AppBackendException].
  Future<TodoItem> saveItem(TodoItem item);

  /// Removes the item with [id] (owner/editor only).
  Future<void> deleteItem(String id);

  /// Adds [comment] to the item [itemId] (commenter and above), returning the
  /// persisted comment.
  Future<TodoComment> addComment(String itemId, TodoComment comment);

  /// The four-state grade for each gradable field of item [itemId], resolved for
  /// the current principal and keyed by [TodoItemResourceKeys]. An ungranted
  /// field resolves to [TomAuthState.none] (hidden — the closed-safe default),
  /// matching the server's resolver.
  Future<Map<String, TomAuthState>> itemFieldStates(String itemId);

  /// Shares the named resource with another user at a [ProjectRole].
  Future<void> share(ShareRequest request);
}
