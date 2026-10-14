/// Authentication and authorization message types for the Tom framework.
///
/// This library defines the data transfer objects (DTOs) used for
/// authentication flows between client and server. It handles:
///
/// - User login credentials and session information
/// - Two-factor authentication (2FA) support
/// - Authentication results including tokens
///
/// ## Authentication Flow
///
/// 1. Client creates a [TomAuthenticationMessage] with credentials
/// 2. Server validates and returns a [TomAuthenticationResult]
/// 3. If `requires2FA` is true, client prompts for second factor
/// 4. Tokens are stored and used for subsequent requests
///
/// ## Example
///
/// This library declares only the DTOs; the exchange runs over
/// `TomServerEndpoint` from the `http_connection` module. A login addresses
/// `TomClientRemoteContext.current!.authenticationUri` — the authentication
/// server, which differs from the API base URI only in a split deployment — and
/// sends no bearer token, because establishing one is the point of the call.
///
/// ```dart
/// final endpoint =
///     TomServerEndpoint<TomAuthenticationMessage, TomAuthenticationResult>(
///       TomServerChannel('auth.example.com', 443),
///       TomServerCallSpecs(
///         'POST',
///         Uri.parse('https://auth.example.com/authenticate'),
///         includeBearerAuthentication: false,
///       ),
///     );
///
/// // Create authentication request
/// var message = TomAuthenticationMessage()
///   ..userName = 'john.doe'
///   ..password = 'secret'
///   ..application = 'myapp';
///
/// // Process result
/// var (result, error) = await endpoint.send(message);
/// if (!(error?.hasError ?? false) && result.error.isEmpty) {
///   TomBearerAuthentication.setTokens(
///     result.authenticationToken,
///     result.authorizationToken,
///   );
/// }
/// ```
///
/// Note the two failure channels: `error` reports that the *call* did not
/// succeed (refused connection, expired deadline, HTTP error), while
/// [TomAuthenticationResult.error] reports that the call succeeded and the
/// server declined the credentials. Both have to be checked.
///
/// See also:
/// - [TomBearerAuthentication] for token management
/// - [TomPrincipal] for the authenticated user context
library;

// =============================================================================
// IMPORTS
// =============================================================================

// For `@tomReflector` only, as in `oauth_contract.dart` and `two_factor.dart`.
// The observable module re-exports the annotation, but nothing here uses
// observable's own API.
import '../reflection/reflection.dart';
import 'two_factor.dart';
import 'user_principal_aci.dart';

// =============================================================================
// AUTHENTICATION MESSAGE
// =============================================================================

/// Represents an authentication request from a client.
///
/// This message is sent to the server to initiate authentication.
/// It contains user credentials and client context information
/// needed to establish a session.
///
/// ## Required Fields
///
/// - [userName]: The user's login name
/// - [password]: The user's password (sent securely)
///
/// ## Optional Context
///
/// Client context information helps the server customize the session:
/// - [clientLanguage], [clientCountry], [clientTimezone]: Localization
/// - [application], [process], [organization]: what the login is for — the
///   application, the process within it, and the organization (a business unit
///   inside the tenant) the user logs in for. The tenant is not part of the
///   message: it is resolved from the request.
///
/// ## Example
///
/// ```dart
/// var message = TomAuthenticationMessage()
///   ..userName = 'admin'
///   ..password = 'P@ssw0rd!'
///   ..application = 'web-portal'
///   ..clientLanguage = 'de'
///   ..clientCountry = 'DE';
/// ```
@tomReflector
class TomAuthenticationMessage {
  /// Unique client identifier for session tracking.
  String client = "";

  /// The username for authentication.
  ///
  /// Defaults to guest username for anonymous sessions.
  String userName = TomUser.guestUsername;

  /// The password for authentication.
  ///
  /// This should be transmitted over secure channels only.
  String password = "";

  /// The application identifier for multi-application deployments.
  String application = "";

  /// The process identifier within the application.
  String process = "";

  /// The organization the user logs in for — a business unit inside the tenant,
  /// not the tenant itself, which is resolved from the request.
  String organization = "";

  /// The client's preferred language (ISO 639-1 code).
  String clientLanguage = TomClientContext.defaultLanguage;

  /// The client's country (ISO 3166-1 alpha-2 code), or
  /// [TomClientContext.noCountry] for none — see there for why `XX` and what a
  /// consumer must do with it.
  String clientCountry = TomClientContext.noCountry;

  /// The client's timezone identifier — what the *device* is set to.
  ///
  /// The device's own setting, not the user's choice: the two are separate
  /// claims and both reach the token ([TomPrincipal.clientTimezone] and
  /// [TomPrincipal.timezone]). A client fills this from the platform, and never
  /// from a stored preference — the preference is server-side
  /// ([TomUserPreferenceKeys.timezone]) and the server applies it after the
  /// login has produced a principal, which is the earliest point at which it
  /// can be read.
  String clientTimezone = TomClientContext.defaultTimezone;
}

// =============================================================================
// AUTHENTICATION RESULT
// =============================================================================

/// Why a login could not succeed, as a closed set a caller can switch on.
///
/// The set is deliberately **coarser than the framework's own knowledge**. A
/// login failure carries two audiences with opposite needs: the server, which
/// wants every distinction it can get for its logging and its lockout logic,
/// and the client, which must not be told more than it has earned. This enum
/// serves the client, and the `key` — free-form, and as specific as the throw
/// site likes — still serves the server.
///
/// That is why there is no `badCredentials`, no `unknownUser` and no
/// `accountLocked`: all three are [accountProblem]. Telling a caller which of
/// the three it hit is a **user-enumeration oracle** — "unknown user" and "wrong
/// password" as separate answers let anyone confirm which accounts exist, and
/// "locked" confirms it a second way. One value, and the account's owner learns
/// the detail through a channel that already knows who they are.
///
/// The rest are separated because a client can act on each differently and
/// none of them says anything about whether an account exists.
///
/// It lives in the kernel, beside [TomAuthenticationResult], because it is a
/// fact about authentication rather than about the server: the server's
/// `TomLoginException` carries it, a failed [TomAuthenticationResult] carries
/// it, and a client switches on it without depending on the server package.
enum TomLoginFailure {
  /// The account cannot authenticate: no such account, wrong credentials, or
  /// the account is locked. One value for the three on purpose — see above.
  accountProblem,

  /// The first factor was accepted and a second one is needed that the caller
  /// has not supplied or not enrolled. The remedy is to complete or begin
  /// enrolment; the credentials themselves were not refused.
  secondFactorRequired,

  /// A second factor was supplied and is not usable: the wrong code, an expired
  /// challenge, one already answered, or one this token does not carry. The
  /// remedy is to try the factor again.
  secondFactorInvalid,

  /// The attempts for this challenge or enrolment are spent. Distinct from
  /// [secondFactorInvalid] because the remedy differs: trying the same factor
  /// again cannot succeed, and the caller has to start the login over.
  rateLimited,

  /// The failure is on the deployment's side rather than the caller's: an
  /// identity provider refused or is unreachable, a one-time code could not be
  /// delivered, or the configuration names a mechanism nothing implements.
  /// Retrying the same credentials may well work once the cause is fixed, and
  /// nothing the caller did is wrong.
  providerError,
}

/// Represents the server's response to an authentication request.
///
/// Contains either an error message or the authentication/authorization
/// tokens needed for subsequent API calls.
///
/// ## Successful Authentication
///
/// On success, [error] is empty and tokens are provided:
/// - [authenticationToken]: Proves user identity
/// - [authorizationToken]: Contains access rights (ACI)
///
/// ## Two-Factor Authentication
///
/// A login that owes a second factor can be in one of *two* states, and they
/// are answered by different calls, so they are reported by different flags:
///
/// - [requires2FA] — the user has a factor and must now **use** it. The
///   challenge's mechanism is [twoFactorType]; the client collects the code and
///   calls the server's second pass.
/// - [requires2FAEnrolment] — the user has no usable factor and must first
///   **set one up**. [availableTwoFactorMethods] is the choice to render, and
///   [twoFactorEnrolmentSkippable] says whether declining is allowed.
///
/// The two are deliberately separate flags rather than one overloaded field. A
/// client written before enrolment existed reads [requires2FA] and
/// [twoFactorType] exactly as it always did; it simply never sees the enrolment
/// state, and the interim token it would try to use is refused by the server —
/// which is the safe way for an out-of-date client to fail.
///
/// In both states the result carries an **interim** token pair: it identifies
/// the user for the next call in the flow but grants no session, because its
/// claims still say a factor is owed.
///
/// ## Example
///
/// `loginEndpoint` is the
/// `TomServerEndpoint<TomAuthenticationMessage, TomAuthenticationResult>` built
/// as shown in this library's documentation; only its result is of interest
/// here.
///
/// ```dart
/// var (result, error) = await loginEndpoint.send(message);
///
/// if (error?.hasError ?? false) {
///   showError(error!.errorKey);
///   return;
/// }
///
/// if (result.error.isNotEmpty) {
///   showError(result.error);
///   return;
/// }
///
/// if (result.requires2FAEnrolment) {
///   showEnrolmentChooser(
///     result.availableTwoFactorMethods,
///     canSkip: result.twoFactorEnrolmentSkippable,
///   );
/// } else if (result.requires2FA) {
///   show2FADialog(result.twoFactorType);
/// } else {
///   navigateToHome();
/// }
/// ```
@tomReflector
class TomAuthenticationResult {
  /// Error message if authentication failed; empty on success.
  String error = "";

  /// Why the login failed, as the [TomLoginFailure] value's name; empty on
  /// success.
  ///
  /// The wire form of [loginFailureReason], and the same name the server's
  /// error envelope reports as `loginFailure` for a failure that is thrown, so
  /// a client reads one vocabulary whichever way a login failed. A string
  /// because the reflection layer serializes plain fields; read and write it
  /// through [loginFailureReason].
  String loginFailure = "";

  /// Why the login failed, or `null` when it did not (or the name on the wire
  /// is one this build does not know).
  ///
  /// Set wherever [error] is set, so a caller switches on a closed set instead
  /// of matching the free-form key in [error].
  TomLoginFailure? get loginFailureReason =>
      TomLoginFailure.values.asNameMap()[loginFailure];

  set loginFailureReason(TomLoginFailure? reason) =>
      loginFailure = reason?.name ?? "";

  /// JWT token proving user identity.
  ///
  /// Used in the `Authorization: Bearer` header for API requests.
  String authenticationToken = "";

  /// JWT token containing authorization information.
  ///
  /// Contains the user's access control information (ACI) including
  /// roles, groups, entitlements, and resource keys.
  String authorizationToken = "";

  /// Indicates if two-factor authentication is required.
  ///
  /// When true, the client must complete 2FA before receiving
  /// final tokens.
  bool requires2FA = false;

  /// The type of 2FA required (e.g., 'totp', 'sms', 'email').
  String twoFactorType = "";

  /// Indicates that the user owes a second factor but has none set up yet.
  ///
  /// Distinct from [requires2FA]: that one says *answer a challenge*, this one
  /// says *choose a mechanism and enrol it*. They are never both true — a login
  /// is either being challenged or being enrolled — and a client that
  /// understands only [requires2FA] therefore cannot mistake one for the other.
  bool requires2FAEnrolment = false;

  /// The mechanisms offered for set-up, in preference order, when
  /// [requires2FAEnrolment] is true; empty otherwise.
  ///
  /// Already narrowed to what this principal's policy permits *and* this
  /// deployment can actually enrol, so the client renders the list as given
  /// rather than filtering it — a client-side filter would be a second place
  /// for the two answers to disagree.
  ///
  /// The entries carry resource keys, not text (G-RES-1): the tier that renders
  /// resolves them against the user's locale.
  List<Tom2FAMethodDescriptor> availableTwoFactorMethods = [];

  /// Whether the user may decline the enrolment offer and complete the login
  /// without a second factor.
  ///
  /// True under an `optional` policy, and under a `required` one while grace
  /// logins remain. The client shows a "not now" affordance only when this is
  /// set; the server checks the same fact again from its own signed token, so a
  /// client that shows one anyway achieves nothing.
  bool twoFactorEnrolmentSkippable = false;

  /// Creates an authentication result.
  ///
  /// - [error]: Optional error message for failed authentication
  TomAuthenticationResult([this.error = ""]);
}
