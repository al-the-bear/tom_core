/// The signed-in session: who is logged in, the token pair, and the principal's
/// per-resource role grants (step 27, RCC2).
///
/// A [ChangeNotifier] so the app shell ([AdvancedTodoApp]) rebuilds the home on
/// every login/logout — navigation between "signed out" and "signed in" is a
/// pure function of [isLoggedIn], not imperative routing. The session owns the
/// single injected [AppBackend]; swap [InMemoryAppBackend] for [LiveAppBackend]
/// in one place (and the widget tests inject their own).
///
/// On login the session installs the principal's `resourceRoles` as the global
/// [TomAuthorization] adapter (an [AppResourceRoleAdapter]), so every screen
/// resolves resource keys through the framework's [TomResourceRoleRegistry]; on
/// logout it resets the adapter. This is what lets the item screen grade fields
/// through the registry rather than stamping a DB-resolved matrix directly.
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
import 'app_resource_role_adapter.dart';

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
  Map<String, String> _resourceRoles = const {};
  bool _awaitingSecondFactor = false;
  bool _awaitingEnrolment = false;
  List<Tom2FAMethodDescriptor> _availableTwoFactorMethods = const [];
  String _pendingAccount = '';
  String? _abandonedTwoFactorMessage;

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
  ///
  /// A half-finished two-factor login is **not** signed in — see
  /// [awaitingSecondFactor].
  bool get isLoggedIn => _user != null;

  /// Whether a [login] verified the password but left a second factor
  /// outstanding.
  ///
  /// The login screen switches to its code phase on this, and the shell keeps
  /// showing the login screen because [isLoggedIn] is still false — the interim
  /// token authorizes nothing, so routing to the board would show an app whose
  /// every call `401`s.
  bool get awaitingSecondFactor => _awaitingSecondFactor;

  /// Whether a [login] verified the password but left a second factor to be
  /// *set up* — the other half-finished login.
  ///
  /// Mutually exclusive with [awaitingSecondFactor]: a principal either holds a
  /// factor and is challenged on it, or holds none and is offered one. Like the
  /// challenge, it keeps [isLoggedIn] false, so the shell stays on the login
  /// screen while the flow runs.
  bool get awaitingEnrolment => _awaitingEnrolment;

  /// Whether the login is part-way through the second factor at all — either
  /// branch. The login screen switches to the framework flow panel on this.
  bool get awaitingTwoFactor => _awaitingSecondFactor || _awaitingEnrolment;

  /// The outstanding challenge — mechanism, attempts remaining, expiry, and the
  /// `clientData` the code field sizes itself from. Null unless
  /// [awaitingSecondFactor].
  Tom2FAChallenge? get pendingChallenge =>
      _awaitingSecondFactor ? backend.pendingChallenge : null;

  /// The outstanding enrolment offer — the mechanisms available, whether it may
  /// be declined, and (once one is chosen) that mechanism's `clientData`. Null
  /// unless [awaitingEnrolment].
  Tom2FAPendingEnrolment? get pendingEnrolment =>
      _awaitingEnrolment ? backend.pendingEnrolment : null;

  /// How the offered mechanisms describe themselves, as the server sent them —
  /// the chooser's labels. Empty unless [awaitingEnrolment].
  List<Tom2FAMethodDescriptor> get availableTwoFactorMethods =>
      _awaitingEnrolment ? _availableTwoFactorMethods : const [];

  /// The username the half-finished login belongs to, shown beside an
  /// enrolment's QR code so a user with several accounts in one authenticator
  /// can tell them apart. Empty when no login is part-way through.
  ///
  /// Held separately from [user] on purpose: assigning [user] before the factor
  /// is settled would flip [isLoggedIn] and route the shell onto a board whose
  /// every call would `401`.
  String get pendingAccount => _pendingAccount;

  /// Why the second-factor phase ended without a session, or null when it did
  /// not end that way.
  ///
  /// A spent challenge or a burned enrolment offer takes the flow panel off the
  /// screen — and the panel's own error line goes with it. Without this the user
  /// would land back at username/password with no account of what happened, so
  /// the message outlives the phase it belongs to and the credentials screen
  /// shows it. Cleared by the next [login] attempt and by a user-initiated
  /// [cancelSecondFactor], which needs no explanation.
  String? get abandonedTwoFactorMessage => _abandonedTwoFactorMessage;

  /// The identity bearer for authenticated calls; empty when logged out.
  String get authToken => _authToken;

  /// The authorization bearer carrying the resolved grade matrix; empty when
  /// logged out.
  String get authzToken => _authzToken;

  /// When the stored token pair expires (UTC), or null when logged out.
  DateTime? get expiresAt => _expiresAt;

  /// The principal's per-resource role grants, `resourceKey → roleName`
  /// (`<type>:<id>` keys, e.g. `item:i-1` → `'editor'`). Snapshotted from the
  /// backend at login and installed as the [TomAuthorization] adapter; empty when
  /// logged out. The item screen reads a resource's role from here to pick the
  /// field-grade row it narrows the framework-resolved resource state by.
  Map<String, String> get resourceRoles => _resourceRoles;

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
  /// out. On success the shell rebuilds onto the board — *unless* the account
  /// owes a second factor, in which case the login is only half done:
  /// [awaitingSecondFactor] goes true, [isLoggedIn] stays false, and the caller
  /// must finish with [submitSecondFactor].
  Future<void> login(LoginRequest request) async {
    // A fresh attempt supersedes whatever ended the last one.
    _abandonedTwoFactorMessage = null;
    final result = await backend.login(request);
    if (result.requires2FA) {
      // Deliberately store *nothing* from the interim result but the flag: its
      // token authorizes no call, and assigning `_user` here would flip
      // [isLoggedIn] and route the shell onto a board that cannot load.
      _awaitingSecondFactor = true;
      _pendingAccount = result.user.username;
      notifyListeners();
      return;
    }
    if (result.requires2FAEnrolment) {
      // The same rule, the other branch — plus the mechanism catalog, which is
      // the one thing the interim result carries that the flow cannot get from
      // the token: the descriptors are resolved from the *server's* registry, so
      // a client that reconstructed them would be guessing.
      _awaitingEnrolment = true;
      _availableTwoFactorMethods = result.availableTwoFactorMethods;
      _pendingAccount = result.user.username;
      notifyListeners();
      return;
    }
    await _completeLogin(result);
  }

  /// Answers the outstanding challenge with the one-time [code].
  ///
  /// On success the session is fully established exactly as a 2FA-free [login]
  /// would have left it. On refusal the [AppBackendException] is rethrown for
  /// the screen to surface; when it is *not* retryable
  /// ([AppBackendException.canRetrySecondFactor]) the challenge is spent, so the
  /// session drops back to "awaiting credentials" and the shell shows the
  /// password screen again. A retryable refusal leaves [awaitingSecondFactor]
  /// set and [pendingChallenge] carrying the decremented attempt count.
  Future<void> submitSecondFactor(String code) async {
    try {
      await _completeLogin(await backend.submitSecondFactor(code));
    } on AppBackendException catch (e) {
      if (!e.canRetrySecondFactor) cancelSecondFactor(reason: e.message);
      rethrow;
    }
  }

  /// Begins enrolment in the mechanism [type] the user picked, so the flow moves
  /// from the chooser to that mechanism's set-up panel.
  ///
  /// Still not a session: the interim token is replaced by another interim
  /// token, now carrying the mechanism's `clientData`. The `notifyListeners`
  /// is what moves the panel on — the flow reads its position from the session
  /// rather than holding one of its own.
  Future<void> chooseTwoFactorMethod(String type) async {
    await backend.beginEnrolment(type);
    notifyListeners();
  }

  /// Confirms the half-built factor with [code], completing the login exactly
  /// as [submitSecondFactor] does.
  ///
  /// A refusal is rethrown for the panel to surface; a *non*-retryable one means
  /// the offer is burned, so the session drops back to the credentials screen —
  /// the same rule the challenge follows, and for the same reason.
  Future<void> confirmEnrolment(String code) async {
    try {
      await _completeLogin(await backend.confirmEnrolment(code));
    } on AppBackendException catch (e) {
      if (!e.canRetrySecondFactor) cancelSecondFactor(reason: e.message);
      rethrow;
    }
  }

  /// Declines the offer and completes the login without a factor. Reachable
  /// only when the server marked the offer skippable.
  Future<void> skipEnrolment() async =>
      _completeLogin(await backend.skipEnrolment());

  /// Abandons a half-finished two-factor login — challenge or enrolment — and
  /// returns to the credentials screen. Also the path a spent challenge and a
  /// burned offer take.
  ///
  /// [reason] is the message the credentials screen shows to explain why the
  /// phase ended, and it is the whole difference between the two callers: the
  /// user pressing "Back to sign in" already knows why, so the flow's own cancel
  /// passes nothing and the message is cleared.
  void cancelSecondFactor({String? reason}) {
    if (!awaitingTwoFactor) return;
    _awaitingSecondFactor = false;
    _awaitingEnrolment = false;
    _availableTwoFactorMethods = const [];
    _pendingAccount = '';
    _abandonedTwoFactorMessage = reason;
    notifyListeners();
  }

  /// Establishes the session from a *completed* [result] — the shared tail of
  /// both login paths, so a two-factor sign-in and a plain one leave exactly the
  /// same state behind.
  Future<void> _completeLogin(LoginResult result) async {
    _awaitingSecondFactor = false;
    _awaitingEnrolment = false;
    _availableTwoFactorMethods = const [];
    _pendingAccount = '';
    _abandonedTwoFactorMessage = null;
    _user = result.user;
    _authToken = result.authToken;
    _authzToken = result.authzToken;
    _expiresAt = result.expiresAt;
    // Snapshot the principal's per-resource role grants and install them as the
    // framework authorization adapter, so every screen resolves resource keys
    // through the TomResourceRoleRegistry (RCC2). Non-resource-key lookups stay
    // permissive via [AppResourceRoleAdapter].
    _resourceRoles = await backend.resourceRoles();
    TomAuthorization.adapter = AppResourceRoleAdapter(_resourceRoles);
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
    _awaitingSecondFactor = false;
    _awaitingEnrolment = false;
    _availableTwoFactorMethods = const [];
    _pendingAccount = '';
    _abandonedTwoFactorMessage = null;
    _user = null;
    _authToken = '';
    _authzToken = '';
    _expiresAt = null;
    _resourceRoles = const {};
    // Drop the authorization adapter so a logged-out app resolves permissively
    // again (no principal, no grants); the next login reinstalls it.
    TomAuthorization.reset();
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
