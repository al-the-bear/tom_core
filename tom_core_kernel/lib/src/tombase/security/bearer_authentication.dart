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
  ///
  /// Assignable on purpose, and not `final`: every static accessor on this
  /// class — [token], [getPrincipal], [setTokens] and the rest — reads through
  /// this field, so replacing it swaps the whole of the cached client-side
  /// authentication state in one move. That is the isolation seam tests use,
  /// in `setUp`/`tearDown`, to stop one test's login leaking into the next.
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
  /// **All or nothing.** Both tokens are parsed and the principal derived
  /// before anything is stored, so a pair that cannot be read — a token with
  /// no payload, a claim Tom never writes — throws and leaves the session
  /// exactly as it was: the previous session's tokens and principal, or none.
  /// Storing the tokens first would pair the new tokens with the previous
  /// principal, and [getPrincipal] would answer for the wrong user. It is also
  /// what makes a stored token always readable, so [getPrincipal] has only one
  /// way to fail.
  ///
  /// - [authenticationToken]: JWT proving user identity
  /// - [authorizationToken]: JWT containing access rights
  /// - [decrypt]: Whether to decrypt the token's secret data (default: true)
  static void setTokens(
    String authenticationToken,
    String authorizationToken, [
    bool decrypt = true,
  ]) {
    final ct = TomClientJwtToken(authenticationToken, decrypt: decrypt);
    final cat = TomClientJwtToken(authorizationToken, decrypt: decrypt);
    final principal = convertTokenPayloadToPrincipal(cat);

    final b = bearerAuthentication;
    b._token = authenticationToken;
    b._authorizationToken = authorizationToken;
    b._clientJwtToken = ct;
    b._clientAuthorizationJwtToken = cat;
    b._principal = principal;
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
  ///
  /// Also `null` for a challenge that has lapsed or burned its last attempt.
  /// Such a challenge is no longer answerable — the server refuses it — so
  /// reporting it as pending would leave a client that slept, or sat in a
  /// background tab, looping on a dead challenge instead of restarting at
  /// pass 1. "Nothing pending" is the honest answer and the actionable one.
  ///
  /// The freshness test lives here rather than in [Tom2FAChallenge.fromClaims]
  /// because it is the only genuinely client-side read. `fromClaims` stays a
  /// pure decoder of the wire format, with no dependency on
  /// [DateTime.now]: the server has its own authoritative clock, and a test
  /// needs to be able to build a lapsed challenge to assert against.
  static Tom2FAChallenge? get pendingTwoFactorChallenge {
    final challenge = Tom2FAChallenge.fromClaims(_currentTokenPayload);
    if (challenge == null) return null;
    return challenge.isExpired() || challenge.isExhausted ? null : challenge;
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
  ///
  /// Filtered for freshness exactly like [pendingTwoFactorChallenge], and it
  /// matters more here: the documented client loop re-reads this getter until
  /// it answers `null`, so a lapsed offer that kept reporting itself would
  /// spin. The two stops need no distinction at this level —
  /// [Tom2FAPendingEnrolment.isExpired] and
  /// [Tom2FAPendingEnrolment.isExhausted] both already answer false at the
  /// choosing stop, where nothing has been generated that could go stale or be
  /// spent.
  static Tom2FAPendingEnrolment? get pendingTwoFactorEnrolment {
    final enrolment = Tom2FAPendingEnrolment.fromClaims(_currentTokenPayload);
    if (enrolment == null) return null;
    return enrolment.isExpired() || enrolment.isExhausted ? null : enrolment;
  }

  /// The public claims of the token the 2FA getters read, or `null` when no
  /// token is held.
  ///
  /// The authorization token when there is one, else the authentication token:
  /// a pass-1 login installs the same interim token as both, but a client that
  /// refreshed only its authorization half must be read from the fresher one.
  static Map<String, dynamic>? get _currentTokenPayload =>
      (bearerAuthentication._clientAuthorizationJwtToken ??
              bearerAuthentication._clientJwtToken)
          ?.payload;

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
      throw StateError(
        "Can't construct a principal from a token without payload",
      );
    }
    final secret = t.secretData;

    // Defensive readers: tokens come from outside this process, so individual
    // claims may be missing or the wrong shape. Each reader falls back rather
    // than crashing on malformed input.
    String? str(String key) {
      final v = payload[key];
      return v is String ? v : null;
    }

    // The personal fields travel in the encrypted half; a token read without
    // decryption has no secret, and yields a principal that names the user and
    // carries nothing personal.
    String? secretStr(String key) {
      final v = secret?[key];
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
    //
    // Read through [Tom2FAClaims.isTrue] rather than against the string alone:
    // this is the gate where a missed "still owes a factor" fails *open*, so it
    // accepts both encodings the claim travels in.
    final requires2FA = Tom2FAClaims.isTrue(payload[Tom2FAClaims.requires2FA]);

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
      timezone: str("timezone"),
      clientCountry: str("clientCountry"),
      clientLanguage: str("clientLanguage"),
      clientTimezone: str("clientTimezone"),
      user: TomUser(
        id: intOr("userId", -1),
        username: str("username") ?? TomUser.guestUsername,
        firstname: secretStr("firstname"),
        lastname: secretStr("lastname"),
        email: secretStr("email"),
        phone: secretStr("phone"),
        mobile: secretStr("mobile"),
        addressLine1: secretStr("addressLine1"),
        addressLine2: secretStr("addressLine2"),
        city: secretStr("city"),
        postcode: secretStr("postcode"),
        stateRegion: secretStr("stateRegion"),
        attributes: mapFrom(secret, "attributes"),
        timezone: str("userTimezone"),
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

  /// The current session's principal, or `null` when there is no session.
  ///
  /// The non-throwing sibling of [getPrincipal], for a caller to whom "not
  /// signed in" is an ordinary state — a widget build, a guard — rather than a
  /// fault. It never throws: a stored token is always readable, because
  /// [setTokens] refuses a pair it cannot derive a principal from and keeps
  /// the previous session instead.
  static TomPrincipal? tryGetPrincipal() => bearerAuthentication._principal;

  /// Gets the current authenticated principal.
  ///
  /// Returns the [TomPrincipal] for the current session — the one live object
  /// [setTokens] derived, which [replacePrincipalAci] and
  /// [replaceClientLimits] update in place.
  ///
  /// Throws [StateError] when there is no session: no tokens have been set, or
  /// [clearTokens] discarded them. That is its only failure. A stored token is
  /// always readable, because [setTokens] refuses a pair it cannot derive a
  /// principal from — so a corrupt token surfaces there, loudly, when it
  /// arrives, rather than here as a degraded guest identity that would make a
  /// broken session look like a signed-out one. A caller for whom "not signed
  /// in" is an ordinary state uses [tryGetPrincipal].
  ///
  /// ```dart
  /// var principal = TomBearerAuthentication.getPrincipal();
  /// print('User: ${principal.username}');
  /// print('Roles: ${principal.aci.roles}');
  /// ```
  static TomPrincipal getPrincipal() {
    final principal = bearerAuthentication._principal;
    if (principal == null) {
      throw StateError(
        "There is no session: call setTokens after a login before reading the "
        'principal, or use tryGetPrincipal when "not signed in" is expected.',
      );
    }
    return principal;
  }

  /// Replaces the current principal's access control information.
  ///
  /// Refreshes a user's permissions without a full re-authentication, which is
  /// what a periodic poll of the server's authorization state needs: the
  /// server holds the whole answer, so the whole answer is what arrives here.
  ///
  /// **Replacement, stated in the name and enforced by the signature.** Every
  /// collection is set to exactly what this call is given, so what a caller
  /// passes is the set the principal ends up with, never a delta. All five are
  /// `required` and named: none can be left out, and none can be transposed
  /// with its neighbour — four adjacent `List<String>` parameters
  /// distinguished only by position would grant the wrong things at run time
  /// while compiling cleanly, and an optional `resourceRoles` would let a
  /// caller clear every per-resource grant by saying nothing. Since
  /// `TomResourceRoleAdapter` resolves an ungranted resource to
  /// `TomAuthState.none`, that omission is invisible: the UI thins out and
  /// nothing is raised.
  ///
  /// Pass `const []` or `const {}` deliberately to clear one.
  ///
  /// - [groups]: The group memberships the principal should end up with
  /// - [roles]: The roles it should end up with
  /// - [entitlements]: The entitlements it should end up with
  /// - [resourceKeys]: The resource keys it should end up with
  /// - [resourceRoles]: The per-resource role map (`resourceKey → roleName`)
  static void replacePrincipalAci({
    required List<String> groups,
    required List<String> roles,
    required List<String> entitlements,
    required List<String> resourceKeys,
    required Map<String, String> resourceRoles,
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

  /// Replaces the current principal's client limits.
  ///
  /// The sibling of [replacePrincipalAci], with the same contract: both
  /// collections are `required`, and what is passed is what the principal ends
  /// up with — pass `const []` or `const {}` deliberately to clear one. Use it
  /// when the new values are already in hand (a server push); to fetch them,
  /// call [refreshClientLimits].
  ///
  /// The token is not re-minted: the replacement is the client's view. A server
  /// reading limits from a request's token sees the login-time snapshot until
  /// the next login, and asks the installed [TomClientLimitsProvider] when it
  /// needs the current figures.
  static void replaceClientLimits({
    required List<String> enabledModules,
    required Map<String, int> quotas,
  }) {
    getPrincipal().cli = TomClientLimitsInformation(
      enabledModules: enabledModules,
      quotas: quotas,
    );
  }

  /// Asks the installed [TomClientLimitsProvider] for the current principal's
  /// limits and replaces them with the answer.
  ///
  /// Returns `true` when the limits were replaced; `false` when no provider is
  /// installed or it had no answer, in which case the principal keeps the
  /// limits it carries. A provider failure propagates: the caller decided to
  /// refresh, so it is the one to decide whether a failed refresh matters.
  static Future<bool> refreshClientLimits() async {
    final provider = TomClientLimitsProvider.installed;
    if (provider == null) return false;
    final principal = getPrincipal();
    final limits = await provider.clientLimitsFor(principal);
    if (limits == null) return false;
    principal.cli = limits;
    return true;
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
  /// ## What each half carries
  ///
  /// The **public** half is base64, not encryption: anyone holding the token —
  /// and anything with access to where it is stored — can read it. It carries
  /// what identifies and routes the session and nothing personal: `username`,
  /// `userId`, `userTimezone`, the organization/application/process context
  /// and its ids, `clientId`, the effective and client locale, the
  /// subscription claims, and the second-factor claims.
  ///
  /// The **private** half is encrypted. It carries every personal field —
  /// first and last name, email, phone, mobile, both address lines, city,
  /// postcode, state/region and `attributes` — beside the context and the five
  /// ACI collections. A reader that decrypts gets them back through
  /// [convertTokenPayloadToPrincipal]; one that does not sees who the session
  /// belongs to and no personal data. The split does not depend on any
  /// resource-key switch being set.
  ///
  /// ## Which principal decides redaction
  ///
  /// Eleven personal fields — all in the private half — are filtered through
  /// [TomResourceKeyProtection.protectFor] under the key `tom.user.<field>`,
  /// and the operand is **[principal] itself** — the subject the token is being
  /// minted for — not whoever the ambient zone names. A field survives when the
  /// subject's own ACI holds its key, and falls back to `null` (or `const {}`
  /// for `attributes`) when it does not.
  ///
  /// The distinction is load-bearing on the login path, which is where this is
  /// called from: the subject is being authenticated at that moment, so nothing
  /// is installed on the zone yet, and reading the zone would be fail-closed —
  /// with [TomResourceKeyProtection.globalSettingProtectionDefault] on, every
  /// protected field in every minted token would come back empty.
  ///
  /// `username`, `userId` and `userTimezone` are not filtered and travel in the
  /// public half.
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
  /// - Public payload: the session's identity, readable by any token holder
  /// - Private payload: encrypted personal fields, context and ACI
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
    // Redaction is decided by the principal the token is *for*, never by
    // whoever the ambient zone names. On the login path — the caller that
    // matters — the subject is being authenticated right now, so no principal
    // is installed yet and the zone-reading form would be fail-closed, blanking
    // every protected field in every minted token.
    T protectField<T>(T data, T fallback, String resourceKey) =>
        TomResourceKeyProtection.protectFor<T>(
          principal,
          data,
          fallback,
          resourceKey,
        );

    // The public half is base64, readable by anyone holding the token: it
    // carries what identifies the session and nothing personal. See the
    // dartdoc's "What each half carries".
    Map<String, Object?> publicInfo = {
      "username": principal.username,
      "userId": principal.user.id,
      "userTimezone": principal.user.timezone,
      "organization": principal.organization,
      "application": principal.application,
      "process": principal.process,
      "organizationId": principal.organizationId,
      "applicationId": principal.applicationId,
      "processId": principal.processId,
      "clientId": principal.clientId,
      "language": principal.language,
      "country": principal.country,
      "timezone": principal.timezone,
      "clientLanguage": clientLanguage,
      "clientCountry": clientCountry,
      "clientTimezone": principal.clientTimezone,
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
      publicInfo[Tom2FAClaims.type] = stillOwed
          ? principal.twoFactorType
          : null;
    }

    TomAccessControlInformation aci = definition != null
        ? definition.completeFromDefinition(principal.aci)
        : principal.aci;

    Map<String, Object?> privateInfo = {
      "firstname": protectField<String?>(
        principal.user.firstname,
        null,
        "tom.user.firstname",
      ),
      "lastname": protectField<String?>(
        principal.user.lastname,
        null,
        "tom.user.lastname",
      ),
      "email": protectField<String?>(
        principal.user.email,
        null,
        "tom.user.email",
      ),
      "phone": protectField<String?>(
        principal.user.phone,
        null,
        "tom.user.phone",
      ),
      "mobile": protectField<String?>(
        principal.user.mobile,
        null,
        "tom.user.mobile",
      ),
      "addressLine1": protectField<String?>(
        principal.user.addressLine1,
        null,
        "tom.user.addressLine1",
      ),
      "addressLine2": protectField<String?>(
        principal.user.addressLine2,
        null,
        "tom.user.addressLine2",
      ),
      "city": protectField<String?>(principal.user.city, null, "tom.user.city"),
      "postcode": protectField<String?>(
        principal.user.postcode,
        null,
        "tom.user.postcode",
      ),
      "stateRegion": protectField<String?>(
        principal.user.stateRegion,
        null,
        "tom.user.stateRegion",
      ),
      "attributes": protectField<Map<String, Object?>>(
        principal.user.attributes,
        const {},
        "tom.user.attributes",
      ),
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
