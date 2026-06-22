/// The signed-in session: who is logged in, their token, and the resolved
/// four-state field matrix for their role.
///
/// A [ChangeNotifier] so the app shell can rebuild on login/logout. It owns the
/// [TodoApi] the screens call, which keeps the backend a single injected
/// dependency — swap an [InMemoryTodoApi] for a live one in one place (and the
/// widget tests inject their own).
library;

import 'package:flutter/foundation.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:todo_domain/todo_domain.dart';

import '../api/todo_api.dart';

/// Holds the authenticated principal and drives login/logout.
class AppSession extends ChangeNotifier {
  /// Creates a session over [api] (the backend the screens call).
  AppSession(this.api);

  /// The backend every screen talks to.
  final TodoApi api;

  User? _user;
  String? _token;
  Map<String, TomAuthState> _fieldStates = const {};

  /// The signed-in user, or null when logged out.
  User? get user => _user;

  /// The bearer token for authenticated calls, or null when logged out.
  String? get token => _token;

  /// Whether a user is currently signed in.
  bool get isLoggedIn => _user != null;

  /// The signed-in user's role (empty when logged out).
  String get role => _user?.role.get() ?? '';

  /// The resolved [TomAuthState] for each gradable field, for the current role.
  /// Empty until a successful [login].
  Map<String, TomAuthState> get fieldStates => _fieldStates;

  /// Authenticates [username]/[password] and loads the role's field matrix.
  ///
  /// Throws a [TodoApiException] on failure; the session stays logged out.
  Future<void> login(String username, String password) async {
    final result = await api.login(username, password);
    _user = result.user;
    _token = result.token;
    _fieldStates = await api.fieldStates(result.user.role.get());
    notifyListeners();
  }

  /// Clears the session.
  void logout() {
    _user = null;
    _token = null;
    _fieldStates = const {};
    notifyListeners();
  }
}
