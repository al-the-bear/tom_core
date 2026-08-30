/// The admin console's signed-in session: who is logged in, the token pair, and
/// the login-time `admin`-role probe.
///
/// A [ChangeNotifier] so the console shell ([AdminConsoleApp]) rebuilds between
/// "signed out" and "signed in" as a pure function of [isLoggedIn] — navigation
/// is state-driven, not imperative. The session owns the single injected
/// [AdminBackend]; swap [InMemoryAdminBackend] for [LiveAdminBackend] in one
/// place (and the widget tests inject their own).
///
/// Login is two-phase because each `/admin/*` endpoint's contract declares
/// `TomRoleAccess(['admin'])` (`TomApiEndpoint.access`) rather than gating login:
/// a non-admin
/// authenticates fine but is refused the moment they touch admin data. So
/// [login] first authenticates, then **probes** an admin call; only when the
/// probe succeeds is the principal stored and the shell allowed to open. A
/// signed-in non-admin is undone and the refusal ([AdminBackendException] keyed
/// `admin.access.forbidden`) is surfaced on the login screen.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter/foundation.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../backend/backend.dart';

/// Holds the authenticated administrator and drives login/logout for the shell.
class AdminSession extends ChangeNotifier {
  /// Creates a session over [backend] (the seam every screen calls).
  AdminSession(this.backend);

  /// The backend the console reaches; the only injected seam.
  final AdminBackend backend;

  UserDto? _user;
  String _authToken = '';
  String _authzToken = '';
  DateTime? _expiresAt;
  bool _awaitingSecondFactor = false;

  /// The provider contents captured just before [login] installed the full
  /// bundle, restored on logout so a re-login starts from the same chrome.
  ///
  /// Null until a login installs the full bundle (and again after the restore),
  /// so logout only undoes an install that actually happened — it never clobbers
  /// a provider the session did not put in place.
  Map<String, dynamic>? _preLoginTexts;

  /// The signed-in administrator, or null when logged out.
  UserDto? get user => _user;

  /// Whether an administrator is currently signed in (login + admin probe both
  /// passed).
  ///
  /// A half-finished two-factor login is **not** signed in — see
  /// [awaitingSecondFactor].
  bool get isLoggedIn => _user != null;

  /// Whether a [login] verified the password but left a second factor
  /// outstanding.
  ///
  /// The login screen switches to its code phase on this. The `admin` probe has
  /// *not* run yet — it cannot, because the interim token authorizes nothing —
  /// so a non-admin with a second factor is still rejected, just one pass later.
  bool get awaitingSecondFactor => _awaitingSecondFactor;

  /// The outstanding challenge — mechanism, attempts remaining, expiry, and the
  /// `clientData` the code field sizes itself from. Null unless
  /// [awaitingSecondFactor].
  Tom2FAChallenge? get pendingChallenge =>
      _awaitingSecondFactor ? backend.pendingChallenge : null;

  /// The identity bearer for authenticated calls; empty when logged out.
  String get authToken => _authToken;

  /// The authorization bearer carrying the resolved grade matrix; empty when
  /// logged out.
  String get authzToken => _authzToken;

  /// When the stored token pair expires (UTC), or null when logged out.
  DateTime? get expiresAt => _expiresAt;

  /// Fetches the public login resource bundle through the backend seam and
  /// installs it as the singleton [TomTextResourceProvider], so the admin
  /// sign-in screen renders server-delivered chrome (title/intro/submit) instead
  /// of any hardcoded string. The bootstrap awaits this before the first frame;
  /// the `notifyListeners` lets a test force the install mid-pump.
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

  /// Fetches the admin-gated console bundle through the seam and installs it
  /// merged over the **current** provider (full-bundle keys win on overlap), so
  /// every console screen — users, roles, groups, grants — renders
  /// server-delivered strings while the login chrome installed before sign-in
  /// stays resolvable. Reachable only once the `admin` role is confirmed (the
  /// probe in [login] precedes it). The pre-install provider is captured so
  /// logout can restore it exactly.
  Future<void> _installFullResources() async {
    final bundle = await backend.resources();
    final current = Map<String, dynamic>.of(
      TomTextResourceProvider.getAppResources().resources,
    );
    _preLoginTexts = current;
    _installResources({...current, ...bundle.texts});
  }

  /// Authenticates [request], then verifies the principal holds the `admin`
  /// role by probing an admin call.
  ///
  /// Throws [AdminBackendException] keyed `auth.login.failed` for bad
  /// credentials (the session stays logged out) or `admin.access.forbidden` for
  /// a signed-in non-admin (the login is undone first, so the shell never
  /// opens). On success the principal + tokens are stored and the shell rebuilds
  /// onto the console.
  Future<void> login(LoginRequest request) async {
    final result = await backend.login(request);
    if (result.requires2FA) {
      // Pass 1 of two. Store nothing but the flag: the interim token authorizes
      // no call, so the `admin` probe would fail for the wrong reason and
      // assigning [_user] would open the shell onto a console that cannot load.
      _awaitingSecondFactor = true;
      notifyListeners();
      return;
    }
    await _completeLogin(result);
  }

  /// Completes a two-pass login with the one-time [code], then runs the same
  /// `admin` probe a single-pass login runs.
  ///
  /// Rethrows the [AdminBackendException] the backend raised. When the refusal
  /// is final ([AdminBackendException.canRetrySecondFactor] false) the pending
  /// login is abandoned first, so the screen falls back to its credentials
  /// phase; a retryable refusal leaves the challenge in place, with its attempt
  /// count already decremented.
  Future<void> submitSecondFactor(String code) async {
    try {
      await _completeLogin(await backend.submitSecondFactor(code));
    } on AdminBackendException catch (e) {
      if (!e.canRetrySecondFactor) cancelSecondFactor();
      rethrow;
    }
  }

  /// Abandons a half-finished two-factor login and returns the screen to its
  /// credentials phase. Also the path a spent challenge takes.
  void cancelSecondFactor() {
    if (!_awaitingSecondFactor) return;
    _awaitingSecondFactor = false;
    notifyListeners();
  }

  /// Establishes the session from a *completed* [result] — the shared tail of
  /// both login paths, so a two-factor sign-in and a plain one leave exactly the
  /// same state behind.
  ///
  /// The `admin` probe lives here rather than in [login] precisely so it runs
  /// against a real token: after pass 2 for a 2FA account, immediately for
  /// everyone else.
  Future<void> _completeLogin(LoginResult result) async {
    try {
      // The role gate is per-operation, so confirm admin reach before opening
      // the shell. A non-admin reaches here authenticated but is refused.
      await backend.listUsers();
    } on AdminBackendException {
      // Not an administrator (or the session was lost): undo the login so no
      // half-open session lingers, then surface the refusal to the screen.
      await _safeLogout();
      _awaitingSecondFactor = false;
      rethrow;
    }
    _awaitingSecondFactor = false;
    _user = result.user;
    _authToken = result.authToken;
    _authzToken = result.authzToken;
    _expiresAt = result.expiresAt;
    // Admin confirmed (the probe above passed): pull the admin-gated console
    // bundle so every post-login screen renders server-delivered texts.
    await _installFullResources();
    notifyListeners();
  }

  /// Ends the session (best-effort server notification) and clears the stored
  /// principal + tokens, routing the shell back to login.
  Future<void> logout() async {
    await _safeLogout();
    _clearSession();
  }

  /// Runs [op] against the backend, logging out automatically when the failure
  /// is a lost session (no session, or the live stack's post-refresh `401`).
  ///
  /// Every admin screen routes its backend calls through this, so "the session
  /// died" is handled in one place: the [AdminBackendException] is still
  /// rethrown for the caller to surface, but the principal is already cleared,
  /// so the next frame shows the login screen.
  Future<T> guard<T>(Future<T> Function(AdminBackend backend) op) async {
    try {
      return await op(backend);
    } on AdminBackendException catch (e) {
      if (_isSessionLost(e)) _clearSession();
      rethrow;
    }
  }

  /// The stable error keys that mean "re-authentication required": a call made
  /// with no session, and the live stack's post-refresh `401`.
  static const Set<String> _sessionLostKeys = {
    'admin.no_session',
    'auth.session_expired',
  };

  bool _isSessionLost(AdminBackendException e) =>
      e.key != null && _sessionLostKeys.contains(e.key);

  Future<void> _safeLogout() async {
    try {
      await backend.logout();
    } on AdminBackendException {
      // A failed server logout still ends the local session — stateless JWTs
      // have nothing to invalidate, so the local clear is authoritative.
    }
  }

  void _clearSession() {
    _awaitingSecondFactor = false;
    _user = null;
    _authToken = '';
    _authzToken = '';
    _expiresAt = null;
    // Reset the provider to the pre-login chrome so a re-login starts clean — no
    // console keys linger. Only undo an install that actually happened.
    final base = _preLoginTexts;
    if (base != null) {
      _installResources(base);
      _preLoginTexts = null;
    }
    notifyListeners();
  }
}
