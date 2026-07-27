/// The **ambient server principal** — the deployment's own identity, held for
/// the lifetime of the process and readable from the access-evaluation path.
///
/// A deployed server is itself a principal: it authenticates against the auth
/// server with a service credential exactly like any other client, and the
/// token it gets back reconstructs a [TomPrincipal] whose entitlements are the
/// **feature grants of this deployment**. Those grants cap every user's grants
/// (see `access_controls.dart`, the meet).
///
/// ## Why a process-wide static rather than a zone value
///
/// The kernel already carries the *user* principal in the current zone
/// ([getFromCurrentZone]), one per in-flight request. The server principal
/// cannot live there: it must be visible from **inside** those same request
/// zones, where the zone slot for [TomPrincipal] is already taken by the user.
/// It is also genuinely process-scoped — one deployment, one identity, resolved
/// once at startup — so a static holder states the lifetime honestly instead of
/// re-deriving it per request.
///
/// ## Unconfigured is a supported state
///
/// A deployment that never logs itself in leaves this empty, and access
/// evaluation then degrades to the user's grant alone — exactly the behaviour
/// of every server built before server-as-principal existed. This is the
/// designed default, not a failure mode: [isConfigured] answers which regime a
/// process is in.
library;

import 'user_principal_aci.dart';

/// Process-wide holder for the deployment's own [TomPrincipal].
///
/// ```dart
/// // At startup, after the server has logged itself in:
/// TomServerPrincipal.install(principalFromServiceToken);
///
/// // Anywhere later — including inside a request zone carrying a user:
/// if (TomServerPrincipal.isConfigured) { ... }
/// ```
class TomServerPrincipal {
  TomServerPrincipal._();

  static TomPrincipal? _current;

  /// The deployment's principal, or `null` when this process never logged
  /// itself in.
  ///
  /// A `null` here is the instruction to skip the meet entirely — see
  /// [TomAccessControl.resolveAuthState]. Callers must not substitute a blank
  /// principal for it: a principal with an empty entitlement set means "this
  /// deployment is entitled to nothing", which denies every feature, whereas
  /// `null` means "no deployment cap applies". The two are opposites.
  static TomPrincipal? get current => _current;

  /// Whether a server principal has been installed.
  static bool get isConfigured => _current != null;

  /// Installs [principal] as the deployment's identity for the rest of the
  /// process.
  ///
  /// Replacing an existing principal is allowed and intended: a long-running
  /// server re-authenticates when its service token nears expiry, and the
  /// refreshed principal must take effect for subsequent checks.
  static void install(TomPrincipal principal) {
    _current = principal;
  }

  /// Removes the server principal, returning the process to the uncapped
  /// regime.
  ///
  /// Intended for tests and for an orderly shutdown. Note the security
  /// direction: clearing *widens* access (the cap stops applying), so this is
  /// never the right response to an expired token — re-[install] instead.
  static void clear() {
    _current = null;
  }
}
