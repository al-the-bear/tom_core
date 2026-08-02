/// Bearer token authentication and principal management.
///
/// This library provides JWT-based bearer token authentication for the
/// Tom framework. It manages authentication and authorization tokens,
/// and provides access to the current user's [TomPrincipal].
///
/// ## Token Types
///
/// The system uses two separate JWT tokens:
/// - **Authentication Token**: Proves user identity
/// - **Authorization Token**: Contains access control information (ACI)
///
/// This separation allows for different token lifetimes and security
/// levels for identity vs. permissions.
///
/// ## Usage
///
/// ```dart
/// // Set tokens after successful login
/// TomBearerAuthentication.setTokens(authToken, authzToken);
///
/// // Access current user information
/// var principal = TomBearerAuthentication.getPrincipal();
/// print('Logged in as: ${principal.username}');
/// print('Roles: ${principal.aci.roles}');
/// ```
///
/// ## Token Payload Structure
///
/// Public payload (visible in JWT):
/// - User info: username, firstname, lastname, email, etc.
/// - Context: organization, application, process
/// - Localization: language, country, timezone
///
/// Secret payload (encrypted):
/// - Security: roles, groups, entitlements, resourceKeys
/// - Session context
///
/// See also:
/// - [TomAuthenticationMessage] for login requests
/// - [TomPrincipal] for the user context object
/// - [TomAccessControlInformation] for the ACI structure
library;

// =============================================================================
// IMPORTS
// =============================================================================

import 'package:tom_crypto/tom_crypto.dart';

import 'access_controls.dart';
import 'two_factor.dart';
import 'user_principal_aci.dart';

// =============================================================================
// BEARER AUTHENTICATION
// =============================================================================

/// Manages JWT bearer token authentication.
///
/// This singleton class stores and manages authentication/authorization
/// tokens, and provides the current user's [TomPrincipal].
///
/// ## Setting Tokens
///
/// After successful authentication, store the tokens:
///
/// ```dart
/// TomBearerAuthentication.setTokens(
///   result.authenticationToken,
///   result.authorizationToken,
/// );
/// ```
///
/// ## Getting the Principal
///
/// Access the current authenticated user:
///
/// ```dart
/// var principal = TomBearerAuthentication.getPrincipal();
/// if (principal.authenticated) {
///   print('Welcome, ${principal.user.firstname}!');
/// }
/// ```
///
/// ## Token Conversion
///
/// For server-side use, convert a principal back to tokens:
///
/// ```dart
/// var (publicPayload, privatePayload) =
///     TomBearerAuthentication.convertPrincipalToTokenPayload(
///       principal,
///       aciDefinition,
///       clientCountry,
///       clientLanguage,
///     );
/// ```
class TomBearerAuthentication {
  /// Global singleton instance for bearer authentication.
  static TomBearerAuthentication bearerAuthentication =
      TomBearerAuthentication();

  // -------------------------------------------------------------------------
  // Private cached state
  // -------------------------------------------------------------------------

  /// Cached principal derived from tokens.
  TomPrincipal? _principal;

  /// Parsed authentication JWT token.
  TomClientJwtToken? _clientJwtToken;

  /// Parsed authorization JWT token.
  TomClientJwtToken? _clientAuthorizationJwtToken;

  /// Raw authentication token string.
  String? _token;

  /// Raw authorization token string.
  String? _authorizationToken;

  // -------------------------------------------------------------------------
  // Static accessors
  // -------------------------------------------------------------------------

  /// Gets the current authentication token string.
  static String? get token => bearerAuthentication._token;

  /// Gets the current authorization token string.
  static String? get authorizationToken =>
      bearerAuthentication._authorizationToken;

  /// Gets the parsed authentication JWT token.
  static TomClientJwtToken? get clientJwtToken =>
      bearerAuthentication._clientJwtToken;

  /// Gets the parsed authorization JWT token.
  static TomClientJwtToken? get clientAuthorizationJwtToken =>
      bearerAuthentication._clientAuthorizationJwtToken;

  // -------------------------------------------------------------------------
  // Token management
  // -------------------------------------------------------------------------

  /// Sets the authentication and authorization tokens.
  ///
  /// This should be called after successful authentication to store
  /// the tokens and make the principal available.
  ///
  /// - [authenticationToken]: JWT proving user identity
  /// - [authorizationToken]: JWT containing access rights
  /// - [decrypt]: Whether to decrypt the token's secret data (default: true)
  static void setTokens(
    String authenticationToken,
    String authorizationToken, [
    bool decrypt = true,
  ]) {
    bearerAuthentication._token = authenticationToken;
    bearerAuthentication._authorizationToken = authorizationToken;
    var ct = TomClientJwtToken(authenticationToken, decrypt: decrypt);
    bearerAuthentication._clientJwtToken = ct;
    var cat = TomClientJwtToken(authorizationToken, decrypt: decrypt);
    bearerAuthentication._clientAuthorizationJwtToken = cat;
    var p = convertTokenPayloadToPrincipal(cat);
    bearerAuthentication._principal = p;
  }

  /// Discards the stored token pair and the cached principal.
  ///
  /// Use on logout, or when a login was answered with an interim 2FA token the
  /// client is abandoning. Leaves the singleton in the same state as a freshly
  /// constructed one, so a following [getPrincipal] throws rather than handing
  /// back a stale identity.
  static void clearTokens() {
    var b = bearerAuthentication;
    b._token = null;
    b._authorizationToken = null;
    b._clientJwtToken = null;
    b._clientAuthorizationJwtToken = null;
    b._principal = null;
  }

  /// The second-factor challenge the stored token is still waiting on, or
  /// `null` when the session needs no second factor (the ordinary case).
  ///
  /// A client drives its 2FA screen from this: after a pass-1 login it reads
  /// the challenge to learn which mechanism is in play, what to display, and
  /// how many attempts remain — without having to decode the token itself.
  /// Returns `null` once pass 2 has stored the completed token pair, which is
  /// exactly the signal that the login is done.
  static Tom2FAChallenge? get pendingTwoFactorChallenge {
    var t =
        bearerAuthentication._clientAuthorizationJwtToken ??
        bearerAuthentication._clientJwtToken;
    return t == null ? null : Tom2FAChallenge.fromClaims(t.payload);
  }

  /// The second-factor **enrolment** the stored token is part-way through, or
  /// `null` when the login owes no set-up (the ordinary case).
  ///
  /// The sibling of [pendingTwoFactorChallenge], read the same way and for the
  /// same reason: a client drives its enrolment screen from this — which
  /// mechanisms were offered, which one is half-built, whether declining is
  /// permitted — without decoding the token itself. Returns `null` once the
  /// completed token pair is stored, which is the signal that the login is
  /// done.
  ///
  /// Both getters can answer non-null at once: a principal whose policy forces
  /// enrolment *and* who already holds a factor is being asked for both, and
  /// the client renders the challenge first.
  static Tom2FAPendingEnrolment? get pendingTwoFactorEnrolment {
    var t =
        bearerAuthentication._clientAuthorizationJwtToken ??
        bearerAuthentication._clientJwtToken;
    return t == null ? null : Tom2FAPendingEnrolment.fromClaims(t.payload);
  }

  /// Converts JWT token payloads to a [TomPrincipal] object.
  ///
  /// Extracts user information, context, and access control data from
  /// the token payloads to construct a complete principal.
  ///
  /// - [authenticationToken]: The parsed authentication JWT
  /// - [authorizationToken]: Optional parsed authorization JWT
  ///   (uses authentication token if not provided)
  ///
  /// Returns a [TomPrincipal] with all extracted information.
  static TomPrincipal convertTokenPayloadToPrincipal(
    TomClientJwtToken authenticationToken, [
    TomClientJwtToken? authorizationToken,
  ]) {
    var t = authorizationToken ?? authenticationToken;

    // A token without a payload cannot produce a principal — surface a clean
    // StateError rather than letting a null-check operator throw deep inside.
    final payload = t.payload;
    if (payload == null) {
      throw StateError("Can't construct a principal from a token without payload");
    }
    final secret = t.secretData;

    // Defensive readers: tokens come from outside this process, so individual
    // claims may be missing or the wrong shape. Each reader falls back rather
    // than crashing on malformed input.
    String? str(String key) {
      final v = payload[key];
      return v is String ? v : null;
    }

    int intOr(String key, int fallback) {
      final v = payload[key];
      return v is int ? v : fallback;
    }

    List<String> strListFrom(Map<String, dynamic>? src, String key) {
      final v = src?[key];
      return v is List ? v.whereType<String>().toList() : <String>[];
    }

    Map<String, Object?> mapFrom(Map<String, dynamic>? src, String key) {
      final v = src?[key];
      return v is Map ? v.cast<String, Object?>() : <String, Object?>{};
    }

    Map<String, int> intMapFrom(Map<String, dynamic>? src, String key) {
      final v = src?[key];
      if (v is! Map) return <String, int>{};
      final result = <String, int>{};
      v.forEach((k, value) {
        if (k is String && value is int) result[k] = value;
      });
      return result;
    }

    Map<String, String> strMapFrom(Map<String, dynamic>? src, String key) {
      final v = src?[key];
      if (v is! Map) return <String, String>{};
      final result = <String, String>{};
      v.forEach((k, value) {
        if (k is String && value is String) result[k] = value;
      });
      return result;
    }

    // A token that still owes a second factor is an *interim* token: it names
    // the user and carries the access-control payload the completed session
    // will get, but the login is not finished. Deriving `authenticated` here —
    // at the single point where every principal is reconstructed — means every
    // existing access check rejects such a token automatically, instead of each
    // call site having to remember to test `requires2FA` as well.
    final requires2FA = payload[Tom2FAClaims.requires2FA] == "true";

    return TomPrincipal(
      authenticated:
          (str("username") ?? TomUser.guestUsername) != TomUser.guestUsername &&
              !requires2FA,
      requires2FA: requires2FA,
      twoFactorType: str(Tom2FAClaims.type),
      context: mapFrom(secret, "context"),
      organization: str("organization"),
      application: str("application"),
      process: str("process"),
      organizationId: intOr("organizationId", -1),
      applicationId: intOr("applicationId", -1),
      processId: intOr("processId", -1),
      clientId: intOr("clientId", -1),
      country: str("country"),
      language: str("language"),
      timezone: str("timeZone"),
      clientCountry: str("clientCountry"),
      clientLanguage: str("clientLanguage"),
      clientTimezone: str("clientTimezone"),
      user: TomUser(
        id: intOr("userId", -1),
        username: str("username") ?? TomUser.guestUsername,
        firstname: str("firstname"),
        lastname: str("lastname"),
        email: str("email"),
        phone: str("phone"),
        mobile: str("mobile"),
        addressLine1: str("addressLine1"),
        addressLine2: str("addressLine2"),
        city: str("city"),
        postcode: str("postcode"),
        stateRegion: str("stateRegion"),
        attributes: mapFrom(payload, "attributes"),
        timeZone: str("userTimeZone"),
      ),
      aci: TomAccessControlInformation(
        groups: strListFrom(secret, "groups"),
        roles: strListFrom(secret, "roles"),
        entitlements: strListFrom(secret, "entitlements"),
        resourceKeys: strListFrom(secret, "resourceKeys"),
        resourceRoles: strMapFrom(secret, "resourceRoles"),
      ),
      cli: TomClientLimitsInformation(
        enabledModules: strListFrom(payload, "subscription_enabledModules"),
        quotas: intMapFrom(payload, "subscription_quotas"),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Principal access
  // -------------------------------------------------------------------------

  /// Gets the current authenticated principal.
  ///
  /// Returns the [TomPrincipal] for the current session. The principal
  /// is cached after first creation for performance.
  ///
  /// Throws [StateError] if no tokens have been set or if the tokens
  /// cannot be parsed into a valid principal.
  ///
  /// ```dart
  /// var principal = TomBearerAuthentication.getPrincipal();
  /// print('User: ${principal.username}');
  /// print('Roles: ${principal.aci.roles}');
  /// ```
  static TomPrincipal getPrincipal() {
    if (bearerAuthentication._principal != null) {
      return bearerAuthentication._principal!;
    }
    if (bearerAuthentication._clientJwtToken == null &&
        bearerAuthentication._clientAuthorizationJwtToken == null) {
      throw StateError("Can't get a principal without token");
    }
    var t =
        bearerAuthentication._clientAuthorizationJwtToken ??
        bearerAuthentication._clientJwtToken!;
    // TODO: check if we can construct some fallback here.
    if (t.payload == null || t.secretData == null) {
      throw StateError(
        "Can't construct principal from a token without payload or secret data",
      );
    }
    // Only one of the two tokens is guaranteed to be present (the guard above
    // merely rules out *both* being absent), so derive from whichever we have.
    bearerAuthentication._principal = convertTokenPayloadToPrincipal(
      bearerAuthentication._clientJwtToken ?? t,
      bearerAuthentication._clientAuthorizationJwtToken,
    );
    return bearerAuthentication._principal!;
  }

  /// Updates the current principal's access control information.
  ///
  /// This allows refreshing the user's permissions without requiring
  /// a full re-authentication. Useful when permissions change during
  /// a session.
  ///
  /// - [groups]: Updated list of group memberships
  /// - [roles]: Updated list of roles
  /// - [entitlements]: Updated list of entitlements
  /// - [resourceKeys]: Updated list of resource keys
  /// - [resourceRoles]: Updated per-resource role map (`resourceKey → roleName`)
  static void updatePrincipal(
    List<String> groups,
    List<String> roles,
    List<String> entitlements,
    List<String> resourceKeys, {
    Map<String, String> resourceRoles = const {},
  }) {
    var principal = getPrincipal();
    principal.aci = TomAccessControlInformation(
      roles: roles,
      groups: groups,
      entitlements: entitlements,
      resourceKeys: resourceKeys,
      resourceRoles: resourceRoles,
    );
  }

  // -------------------------------------------------------------------------
  // Token payload conversion
  // -------------------------------------------------------------------------

  /// Converts a principal to JWT token payloads.
  ///
  /// Creates the public and private payloads needed to generate
  /// authentication and authorization JWT tokens.
  ///
  /// - [principal]: The principal to convert
  /// - [definition]: Optional ACI definition for resolving full permissions
  /// - [clientCountry]: Client's country for localization
  /// - [clientLanguage]: Client's language for localization
  /// - [challenge]: A pending second-factor challenge to carry in the token,
  ///   making this an *interim* token rather than a completed session
  /// - [twoFactorVerification]: The mechanism's server-only verification
  ///   payload, placed in the encrypted section (only meaningful with
  ///   [challenge])
  /// - [twoFactorSatisfied]: Set on the second pass, once the factor has been
  ///   verified, to clear the requirement the principal still carries
  ///
  /// ## The `requires2FA` claim
  ///
  /// The claim is **fail-safe**: it is true whenever a [challenge] is being
  /// issued *or* the principal declares it needs a second factor, and only
  /// [twoFactorSatisfied] clears it. So a caller that mints tokens without
  /// going through the two-pass flow cannot accidentally hand a 2FA user a
  /// fully-authenticated token by forgetting a parameter — the omission
  /// produces an unusable interim token, not an over-privileged one.
  ///
  /// Returns a tuple of (publicPayload, privatePayload):
  /// - Public payload: User info visible in the JWT
  /// - Private payload: Encrypted security information (ACI)
  ///
  /// ```dart
  /// var (publicPayload, privatePayload) =
  ///     TomBearerAuthentication.convertPrincipalToTokenPayload(
  ///       principal,
  ///       aciDefinition,
  ///       'US',
  ///       'en',
  ///     );
  /// var token = TomServerJwtToken.create(publicPayload, privatePayload);
  /// ```
  static (Map<String, Object?>, Map<String, Object?>)
  convertPrincipalToTokenPayload(
    TomPrincipal principal,
    TomAccessControlDefinition? definition,
    String? clientCountry,
    String? clientLanguage, {
    Tom2FAChallenge? challenge,
    Map<String, Object?>? twoFactorVerification,
    bool twoFactorSatisfied = false,
  }) {
    // TODO: consider adding access rights-based filtering or sorting in public/private
    Map<String, Object?> publicInfo = {
      "username": principal.username,
      "userId": principal.user.id,
      "firstname": tomProtect<String?>(
        principal.user.firstname,
        null,
        "tom.user.firstname",
      ),
      "lastname": tomProtect<String?>(
        principal.user.lastname,
        null,
        "tom.user.lastname",
      ),
      "email": tomProtect<String?>(
        principal.user.email,
        null,
        "tom.user.email",
      ),
      "phone": tomProtect<String?>(
        principal.user.phone,
        null,
        "tom.user.phone",
      ),
      "mobile": tomProtect<String?>(
        principal.user.mobile,
        null,
        "tom.user.mobile",
      ),
      "addressLine1": tomProtect<String?>(
        principal.user.addressLine1,
        null,
        "tom.user.addressLine1",
      ),
      "addressLine2": tomProtect<String?>(
        principal.user.addressLine2,
        null,
        "tom.user.addressLine2",
      ),
      "city": tomProtect<String?>(principal.user.city, null, "tom.user.city"),
      "postcode": tomProtect<String?>(
        principal.user.postcode,
        null,
        "tom.user.postcode",
      ),
      "stateRegion": tomProtect<String?>(
        principal.user.stateRegion,
        null,
        "tom.user.stateRegion",
      ),
      "userTimeZone": principal.user.timeZone,
      "organization": principal.organization,
      "application": principal.application,
      "process": principal.process,
      "organizationId": principal.organizationId,
      "applicationId": principal.applicationId,
      "processId": principal.processId,
      "clientId": principal.clientId,
      "language": principal.language,
      "country": principal.country,
      "timeZone": principal.timezone,
      "clientLanguage": clientLanguage,
      "clientCountry": clientCountry,
      "clientTimezone": principal.clientTimezone,
      "attributes": tomProtect<Map<String, Object?>>(
        principal.user.attributes,
        const {},
        "tom.user.attributes",
      ),
      "subscription_enabledModules": principal.cli.enabledModules,
      "subscription_quotas": principal.cli.quotas,
    };

    if (challenge != null) {
      publicInfo.addAll(challenge.toClaims());
    } else {
      // No challenge in flight: the token still owes a factor only if the
      // principal says so and nobody has reported it satisfied.
      final stillOwed = principal.requires2FA && !twoFactorSatisfied;
      publicInfo[Tom2FAClaims.requires2FA] = stillOwed ? "true" : "false";
      publicInfo[Tom2FAClaims.type] =
          stillOwed ? principal.twoFactorType : null;
    }

    TomAccessControlInformation aci = definition != null
        ? definition.completeFromDefinition(principal.aci)
        : principal.aci;

    Map<String, Object?> privateInfo = {
      "context": principal.currentContext,
      "groups": aci.groups,
      "roles": aci.roles,
      "entitlements": aci.entitlements,
      "resourceKeys": aci.resourceKeys,
      "resourceRoles": aci.resourceRoles,
    };

    // Only ever present on an interim token: once the factor is verified the
    // re-issued pair carries no verification payload at all, so a mechanism
    // secret cannot outlive the challenge it was minted for.
    if (challenge != null && twoFactorVerification != null) {
      privateInfo[Tom2FAClaims.verificationData] = twoFactorVerification;
    }

    return (publicInfo, privateInfo);
  }
}
