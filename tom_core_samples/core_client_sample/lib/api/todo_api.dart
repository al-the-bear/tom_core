/// The backend contract the client talks to, independent of transport.
///
/// The app is written against this interface, not a concrete backend, so the
/// same screens drive either the in-memory demo backend ([InMemoryTodoApi],
/// the default — fully working offline) or, for the live read path, the real
/// `core_server_sample` over HTTP. Keeping the seam here is what makes the
/// widget tests deterministic: they bind the screens to an in-memory api and
/// never touch a socket.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:todo_domain/todo_domain.dart';

/// The gradable todo-item field resource keys — the vocabulary every
/// [TodoApi.fieldStates] result is expanded over (G-RES-6).
///
/// A bare list, not a `*ResourceKeys` catalogue class: it only *enumerates* the
/// keys, which a field otherwise self-addresses by at its use site. They are the
/// same wire keys `core_server_sample` seeds into `tom_resource_grant`; the
/// client keeps its own copy so it works offline, rather than depending on the
/// server package.
///
/// Its job is to make each role's map **total**: both backends fold over it and
/// stamp [TomAuthState.none] on every key the role was not granted, which is
/// what delivers the closed-safe default instead of a missing entry. Only the
/// set matters, so this is not a display order — it is not even a candidate for
/// one, since `description` is rendered by the detail screen but is not
/// gradable and so does not appear here.
const List<String> gradableItemKeys = [
  'todo.item.title',
  'todo.item.done',
  'todo.item.priority',
  'todo.item.assigneeId',
];

/// The outcome of a successful [TodoApi.login]: the authenticated principal and
/// the bearer token subsequent calls present.
class LoginResult {
  /// Creates a login result.
  const LoginResult({required this.user, required this.token});

  /// The authenticated user (carries the role that drives field authorization).
  final User user;

  /// The opaque bearer token for authenticated calls.
  final String token;
}

/// Raised when a backend call fails (bad credentials, unknown item, …).
///
/// A single typed failure the screens can catch and surface; the in-memory
/// backend throws it for invalid input and the HTTP layer would wrap a
/// transport/4xx error in it. Carrying a human message keeps the call sites
/// from having to map error shapes.
class TodoApiException implements Exception {
  /// Creates the exception with a human-readable [message].
  const TodoApiException(this.message);

  /// What went wrong, fit to show the user.
  final String message;

  @override
  String toString() => 'TodoApiException: $message';
}

/// The todo backend the client edits against.
abstract class TodoApi {
  /// Authenticates [username] / [password], returning the principal + token.
  ///
  /// Throws a [TodoApiException] when the credentials are rejected.
  Future<LoginResult> login(String username, String password);

  /// Every todo item visible to the session.
  Future<List<TodoItem>> listItems();

  /// Creates ([TodoItem.id] empty) or updates a todo item, returning the
  /// persisted entity (with its assigned id).
  Future<TodoItem> saveItem(TodoItem item);

  /// Removes the item with [id].
  Future<void> deleteItem(String id);

  /// The effective [TomAuthState] for each gradable field, for [role].
  ///
  /// Keyed by the gradable-field resource keys (`todo.item.title`, …); an
  /// ungranted field resolves to [TomAuthState.none] (hidden — the closed-safe
  /// default), matching the server's resolver.
  Future<Map<String, TomAuthState>> fieldStates(String role);
}
