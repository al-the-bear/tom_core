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
/// ```dart
/// // Create authentication request
/// var message = TomAuthenticationMessage()
///   ..userName = 'john.doe'
///   ..password = 'secret'
///   ..application = 'myapp';
///
/// // Process result
/// var result = await authService.authenticate(message);
/// if (result.error.isEmpty) {
///   TomBearerAuthentication.setTokens(
///     result.authenticationToken,
///     result.authorizationToken,
///   );
/// }
/// ```
///
/// See also:
/// - [TomBearerAuthentication] for token management
/// - [TomPrincipal] for the authenticated user context
library;

// =============================================================================
// IMPORTS
// =============================================================================

import '../observable/tom_observable_objects.dart';
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
/// - [application], [process], [organization]: Multi-tenant context
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

  /// The organization identifier for multi-tenant deployments.
  String organization = "";

  /// The client's preferred language (ISO 639-1 code).
  String clientLanguage = "en";

  /// The client's country (ISO 3166-1 alpha-2 code).
  String clientCountry = "XX"; // none

  /// The client's timezone identifier.
  // TODO: get from preferences or device
  String clientTimezone = "utc";
}

// =============================================================================
// AUTHENTICATION RESULT
// =============================================================================

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
/// If [requires2FA] is true, the client must:
/// 1. Present the appropriate 2FA challenge based on [twoFactorType]
/// 2. Submit the 2FA code to complete authentication
/// 3. Receive new tokens upon successful 2FA
///
/// ## Example
///
/// ```dart
/// var result = await authService.login(message);
///
/// if (result.error.isNotEmpty) {
///   showError(result.error);
///   return;
/// }
///
/// if (result.requires2FA) {
///   show2FADialog(result.twoFactorType);
/// } else {
///   navigateToHome();
/// }
/// ```
@tomReflector
class TomAuthenticationResult {
  /// Error message if authentication failed; empty on success.
  String error = "";

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

  /// Creates an authentication result.
  ///
  /// - [error]: Optional error message for failed authentication
  TomAuthenticationResult([this.error = ""]);
}
