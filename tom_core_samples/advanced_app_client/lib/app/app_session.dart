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

  /// The provider contents captured just before [login] installed the full
  /// bundle, restored on logout so a re-login starts from the same chrome.
  ///
  /// Null until a login installs the full bundle (and again after the restore),
  /// so logout only undoes an install that actually happened — it never clobbers
  /// a provider the session did not put in place.
  Map<String, dynamic>? _preLoginTexts;

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
  /// keyed by the gradable item resource keys (`todo.item.*`). Empty until
  /// [loadFieldStates] is called for an item (and cleared on every login/logout).
  Map<String, TomAuthState> get currentFieldStates => _currentFieldStates;

  /// Fetches the public login resource bundle through the backend seam and
  /// installs it as the singleton [TomTextResourceProvider], so the sign-in
  /// screen renders server-delivered chrome (title/intro/submit) instead of any
  /// hardcoded string. The bootstrap awaits this before the first frame; the
  /// `notifyListeners` lets a test force the install mid-pump.
  Future<void> loadLoginResources() async {
    final bundle = await backend.loginResources();
    _installResources(Map<String, dynamic>.from(bundle.texts));
    notifyListeners();
  }

  /// Installs [texts] as the singleton [TomTextResourceProvider]. The one place
  /// the provider is swapped, so login/logout/post-login all route through it.
  void _installResources(Map<String, dynamic> texts) {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(texts),
    );
  }

  /// Fetches the authenticated full bundle through the seam and installs it
  /// merged over the **current** provider (full-bundle keys win on overlap), so
  /// every post-login screen — board, item form, sharing — renders
  /// server-delivered strings while the login chrome installed before sign-in
  /// stays resolvable. The pre-install provider is captured so logout can
  /// restore it exactly.
  Future<void> _installFullResources() async {
    final bundle = await backend.resources();
    final current = Map<String, dynamic>.of(
      TomTextResourceProvider.getAppResources().resources,
    );
    _preLoginTexts = current;
    _installResources({...current, ...bundle.texts});
  }

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
    _setFieldStates(const {});
    // Now authenticated: pull the full bundle so every post-login screen renders
    // server-delivered texts. Reachable only with a session, hence after login.
    await _installFullResources();
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
  /// matrix, returning it so the detail screen can apply it per field. Runs
  /// through [guard], so a dead session routes back to login instead of
  /// surfacing a raw failure.
  Future<Map<String, TomAuthState>> loadFieldStates(String itemId) async {
    final states = await guard((backend) => backend.itemFieldStates(itemId));
    _setFieldStates(states);
    notifyListeners();
    return states;
  }

  /// Stores [states] as the current matrix (the DB-resolved grades for the item
  /// now in view). The detail screen reads the returned matrix and stamps each
  /// gradable field with its grade; the session holds no authorization
  /// indirection of its own.
  void _setFieldStates(Map<String, TomAuthState> states) {
    _currentFieldStates = states;
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
  /// stack's post-refresh `401` ([TomAuthExpiredException] →
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
    _setFieldStates(const {});
    // Reset the provider to the pre-login chrome so a re-login starts clean — no
    // full-bundle keys linger. Only undo an install that actually happened.
    final base = _preLoginTexts;
    if (base != null) {
      _installResources(base);
      _preLoginTexts = null;
    }
    notifyListeners();
  }
}
