/// The signed-in session: who is logged in, the token pair, and the four-state
/// field matrix for the item currently in view (step 27).
///
/// A [ChangeNotifier] so the app shell ([AdvancedTodoApp]) rebuilds the home on
/// every login/logout — navigation between "signed out" and "signed in" is a
/// pure function of [isLoggedIn], not imperative routing. The session owns the
/// single injected [AppBackend]; swap [InMemoryAppBackend] for [LiveAppBackend]
/// in one place (and the widget tests inject their own).
///
/// Every screen reaches the backend through [guard] (or the convenience
/// wrappers built on it), so a dead session surfaces uniformly: when the live
/// stack answers a post-refresh `401` it raises an [AppBackendException] keyed
/// `auth.session_expired`, which [guard] turns into an automatic logout — the
/// shell then routes straight back to the login screen.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter/foundation.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../backend/backend.dart';

/// Holds the authenticated principal and drives login/logout for the app shell.
class AppSession extends ChangeNotifier {
  /// Creates a session over [backend] (the seam every screen calls).
  AppSession(this.backend);

  /// The backend the screens reach through [guard]; the only injected seam.
  final AppBackend backend;

  UserDto? _user;
  String _authToken = '';
  String _authzToken = '';
  DateTime? _expiresAt;
  Map<String, TomAuthState> _currentFieldStates = const {};

  /// The signed-in principal, or null when logged out.
  UserDto? get user => _user;

  /// Whether a principal is currently signed in.
  bool get isLoggedIn => _user != null;

  /// The identity bearer for authenticated calls; empty when logged out.
  String get authToken => _authToken;

  /// The authorization bearer carrying the resolved grade matrix; empty when
  /// logged out.
  String get authzToken => _authzToken;

  /// When the stored token pair expires (UTC), or null when logged out.
  DateTime? get expiresAt => _expiresAt;

  /// The four-state matrix for the item the detail screen is currently showing,
  /// keyed by [TodoItemResourceKeys]. Empty until [loadFieldStates] is called
  /// for an item (and cleared on every login/logout).
  Map<String, TomAuthState> get currentFieldStates => _currentFieldStates;

  /// Authenticates [request] and stores the resolved principal + token pair.
  ///
  /// Throws [AppBackendException] on a rejected login; the session stays logged
  /// out. On success the shell rebuilds onto the board.
  Future<void> login(LoginRequest request) async {
    final result = await backend.login(request);
    _user = result.user;
    _authToken = result.authToken;
    _authzToken = result.authzToken;
    _expiresAt = result.expiresAt;
    _currentFieldStates = const {};
    notifyListeners();
  }

  /// Ends the session (best-effort server notification) and clears the stored
  /// principal + tokens, routing the shell back to login.
  Future<void> logout() async {
    try {
      await backend.logout();
    } on AppBackendException {
      // A failed server logout still ends the local session — stateless JWTs
      // have nothing to invalidate, so the local clear is authoritative.
    }
    _clearSession();
  }

  /// Loads the four-state matrix for [itemId] and stores it as the current
  /// matrix (the detail screen binds against it). Runs through [guard], so a
  /// dead session routes back to login instead of surfacing a raw failure.
  Future<Map<String, TomAuthState>> loadFieldStates(String itemId) async {
    final states = await guard((backend) => backend.itemFieldStates(itemId));
    _currentFieldStates = states;
    notifyListeners();
    return states;
  }

  /// Runs [op] against the backend, logging out automatically when the failure
  /// is a lost session (the live stack's post-refresh `401`).
  ///
  /// Every screen routes its backend calls through this, so "the session died"
  /// is handled in exactly one place: the [AppBackendException] is still
  /// rethrown for the caller to surface, but the principal is already cleared,
  /// so the next frame shows the login screen.
  Future<T> guard<T>(Future<T> Function(AppBackend backend) op) async {
    try {
      return await op(backend);
    } on AppBackendException catch (e) {
      if (_isSessionLost(e)) _clearSession();
      rethrow;
    }
  }

  /// The stable error keys that mean "re-authentication required": the live
  /// stack's post-refresh `401` ([AuthorizedHttpException] →
  /// `auth.session_expired`) and a call made with no session at all.
  static const Set<String> _sessionLostKeys = {
    'auth.session_expired',
    'app.no_session',
  };

  bool _isSessionLost(AppBackendException e) =>
      e.key != null && _sessionLostKeys.contains(e.key);

  void _clearSession() {
    _user = null;
    _authToken = '';
    _authzToken = '';
    _expiresAt = null;
    _currentFieldStates = const {};
    notifyListeners();
  }
}
