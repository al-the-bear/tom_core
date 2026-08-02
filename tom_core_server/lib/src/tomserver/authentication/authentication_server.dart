import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import 'two_factor.dart';
import 'two_factor_policy.dart';

/// Marks a class as an authentication adaptor and constrains which login flows
/// it participates in.
///
/// [guestOnly] restricts the adaptor to guest logins; [userOnly] restricts it
/// to authenticated-user logins. Leaving both `false` (the default) makes the
/// adaptor eligible for either flow. The annotation is reflection-discoverable,
/// so a runtime can enumerate the registered adaptors and route a login to the
/// right one.
@tomReflector
class TomAuthenticationAdaptor {
  /// Whether this adaptor handles only guest logins.
  final bool guestOnly;

  /// Whether this adaptor handles only authenticated-user logins.
  final bool userOnly;

  /// Creates an adaptor marker; defaults make it eligible for both flows.
  TomAuthenticationAdaptor({this.guestOnly = false, this.userOnly = false});
}

/// The data carried into a single authentication attempt.
///
/// A [TomAuthenticationServer] builds this from an incoming
/// `TomAuthenticationMessage` and passes it to the configured
/// [TomAuthenticationService]. It identifies *what* is being logged into
/// (organization / application / process / client) and *who* ([username]),
/// plus the credential ([key], e.g. the password) and the client locale
/// (language / country / timezone). The fields are mutable so a service can
/// enrich them while resolving the login.
@tomReflector
class TomAuthenticationData {
  /// The organization being logged into.
  String organization;

  /// The application being logged into.
  String application;

  /// The process (sub-context of the application) being logged into.
  String process;

  /// The client's language code.
  String language;

  /// The client's country code.
  String country;

  /// The client's timezone identifier.
  String timezone;

  /// The client (front-end) identifier the login originates from.
  String client;

  /// The login name of the user (or `"GUEST"` for guest logins).
  String username;

  /// The credential to verify (typically the password); `null` for guests.
  Object? key;

  /// Creates the data for one authentication attempt.
  TomAuthenticationData({
    required this.username,
    this.key,
    required this.organization,
    required this.application,
    required this.process,
    required this.language,
    required this.country,
    required this.timezone,
    required this.client,
  });
}

/// The contract an application implements to authenticate a login.
///
/// Implementations resolve the [TomAuthenticationData] against their user store
/// (database, directory, etc.) and return a [TomAuthenticationInfo] carrying the
/// authenticated principal and its access-control definition. On failure they
/// throw a [LoginException]. The default implementation,
/// [TomDummyAuthenticationService], accepts everything and is for scaffolding
/// only.
@tomReflector
abstract class TomAuthenticationService {
  /// Authenticates [authData], returning the principal and its access rights,
  /// or throwing a [LoginException] when the login is rejected.
  Future<TomAuthenticationInfo> authenticateUser(
    TomAuthenticationData authData,
  );
}

/// The successful outcome of a [TomAuthenticationService.authenticateUser] call.
///
/// Pairs the authenticated [principal] (identity, locale, user record) with the
/// [acd] — the access-control definition (groups/roles) that
/// [TomAuthenticationServer] encodes into the issued authorization token.
class TomAuthenticationInfo {
  /// The authenticated principal (identity, locale, and user record).
  TomPrincipal principal;

  /// The principal's access-control definition (groups and roles).
  TomAccessControlDefinition acd;

  /// Pairs an authenticated [principal] with its access-control definition.
  TomAuthenticationInfo(this.principal, this.acd);
}

/// A no-op [TomAuthenticationService] that authenticates any non-`"GUEST"` user.
///
/// Provided as the default so a freshly scaffolded server can issue tokens
/// without a user store wired up. It logs an error on every call (unless
/// [showErrorMessage] is cleared) because relying on it outside scaffolding is a
/// mistake — replace it with a real [TomAuthenticationService] via
/// [TomAuthenticationServer.globalSettingUserAuthenticationService] /
/// [TomAuthenticationServer.globalSettingGuestAuthenticationService].
class TomDummyAuthenticationService implements TomAuthenticationService {
  /// Whether to log the "you are using the dummy service" error on each call.
  bool showErrorMessage = true;

  @override
  Future<TomAuthenticationInfo> authenticateUser(
    TomAuthenticationData authData,
  ) {
    TomPrincipal result = TomPrincipal(
      authenticated: authData.username != "GUEST",
      context: {},
      requires2FA: false,
      twoFactorType: null,
      clientId: 0,
      organization: authData.organization,
      organizationId: 0,
      application: authData.application,
      applicationId: 0,
      process: authData.process,
      processId: 0,
      language: authData.language,
      country: authData.country,
      clientCountry: authData.language,
      clientLanguage: authData.language,
      clientTimezone: authData.timezone,
      user: TomUser(
        id: 0,
        username: authData.username,
        firstname: "guest",
        lastname: "guest",
        attributes: {},
        timeZone: "utc",
      ),
      aci: TomAccessControlInformation(),
    );
    if (showErrorMessage) {
      tomLog.error(
        "You are using TomDummyAuthenticationService. This is only acceptable while scaffolding the project. In any productive or product test situation this is an error.",
      );
    }
    return Future.syncValue(
      TomAuthenticationInfo(result, TomAccessControlDefinition()),
    );
  }
}

/// Orchestrates the server-side login flow and issues JWT tokens.
///
/// A server endpoint subclasses this and exposes [authenticateGuest] /
/// [authenticatePass1] / [authenticatePass2] as HTTP endpoints. Each takes a
/// `TomAuthenticationMessage` (the wire request), delegates credential checking
/// to the configured [TomAuthenticationService], and — on success — encodes the
/// resulting principal into two JWTs in the returned [TomAuthenticationResult]:
/// an authentication token (public claims) and an authorization token (public
/// claims plus the encrypted access-control payload).
///
/// Which service is used is selected per flow via the static
/// [globalSettingGuestAuthenticationService] /
/// [globalSettingUserAuthenticationService]; the JWT issuer is
/// [globalSettingJwtOrganization].
@tomReflector
class TomAuthenticationServer {
  /// The service used for authenticated-user logins (pass 1).
  static TomAuthenticationService globalSettingUserAuthenticationService =
      TomDummyAuthenticationService();

  /// The service used for guest logins.
  static TomAuthenticationService globalSettingGuestAuthenticationService =
      TomDummyAuthenticationService();

  /// The `iss` (issuer) organization stamped onto issued JWTs.
  static String globalSettingJwtOrganization = "tom";

  /// Authenticates a guest login via [globalSettingGuestAuthenticationService].
  Future<TomAuthenticationResult> authenticateGuest(
    TomAuthenticationMessage m,
  ) async {
    return await authenticateUser(m, true);
  }

  /// First authentication pass: validates user credentials via
  /// [globalSettingUserAuthenticationService] and issues tokens on success.
  Future<TomAuthenticationResult> authenticatePass1(
    TomAuthenticationMessage m,
  ) async {
    return await authenticateUser(m, false);
  }

  /// Second authentication pass: answers the challenge issued by
  /// [authenticatePass1] and, on success, returns the completed token pair.
  ///
  /// The submitted factor travels in [TomAuthenticationMessage.password] — the
  /// message's credential slot — and the challenge itself is recovered from the
  /// **interim token the client presents as its bearer**, so no field had to be
  /// added to either wire type and no server-side pending-login record exists.
  /// [challengeToken] overrides that lookup; it defaults to the request zone's
  /// token, and tests pass one explicitly to run the pass without a zone.
  ///
  /// ## Outcomes
  ///
  /// - **Accepted** — a result whose token pair is exactly what a 2FA-free login
  ///   would have produced for this user: same claims, `requires2FA` cleared.
  /// - **Wrong answer, attempts left** — a result carrying
  ///   `login.error.2fa.invalid-code` *and a re-issued interim token* with the
  ///   attempt counter advanced. The client retries with that token.
  /// - **Wrong answer, attempts exhausted** — `login.error.2fa.attempts-exhausted`
  ///   and no token. That chain of tokens is burned; the client must restart at
  ///   pass 1.
  /// - **Lapsed or absent challenge** — `login.error.2fa.expired` /
  ///   `login.error.2fa.no-challenge`, likewise with no token.
  ///
  /// ## What the attempt counter does and does not bound
  ///
  /// The counter lives in the token and advances only along the chain of
  /// re-issued tokens. A **stateless** server holds no record of which interim
  /// tokens it has already answered, so it cannot tell a replay of an *earlier*
  /// token in the chain from the original presentation of it — and an earlier
  /// token is still within its validity and still carries its lower count.
  ///
  /// So the counter bounds a cooperative client (and gives a UI its "2 tries
  /// left"); it is **not** by itself a brute-force defence. What bounds an
  /// uncooperative one is the challenge's own short
  /// [Tom2FAChallengeSpec.validity] — after it lapses, every token in the chain
  /// is refused. Deployments that need a hard per-challenge attempt cap must add
  /// the server-side state that stateless verification deliberately omits (a
  /// spent-token denylist or a per-user counter); see the mechanism's own rate
  /// limiting as the usual alternative.
  Future<TomAuthenticationResult> authenticatePass2(
    TomAuthenticationMessage m, {
    TomClientJwtToken? challengeToken,
  }) async {
    try {
      final token =
          challengeToken ?? getFromCurrentZone<TomClientJwtToken>();
      if (token == null) {
        throw LoginException(
          'login.error.2fa.no-challenge',
          'No pending two-factor challenge was presented',
        );
      }

      final challenge = Tom2FAChallenge.fromClaims(token.payload);
      if (challenge == null) {
        throw LoginException(
          'login.error.2fa.no-challenge',
          'The presented token carries no two-factor challenge',
        );
      }
      if (challenge.isExpired()) {
        throw LoginException(
          'login.error.2fa.expired',
          'The two-factor challenge has expired',
        );
      }
      if (challenge.isExhausted) {
        throw LoginException(
          'login.error.2fa.attempts-exhausted',
          'No two-factor attempts remain',
        );
      }

      final adaptor = Tom2FARegistry.lookup(challenge.type);
      if (adaptor == null) {
        throw LoginException(
          'login.error.2fa.unsupported-mechanism',
          'No adaptor is registered for two-factor mechanism '
              '"${challenge.type}"',
        );
      }

      // The interim token carries the access-control payload pass 1 resolved,
      // so the completed session needs no second trip to the user store — and
      // the principal cannot be swapped for another between the passes.
      final principal =
          TomBearerAuthentication.convertTokenPayloadToPrincipal(token);
      final context = _contextFor(principal, m);

      final consumed = challenge.withConsumedAttempt();
      final verification = _verificationDataOf(token);
      final accepted = await adaptor.verifySubmission(
        context,
        Tom2FASubmission(
          submitted: m.password,
          challenge: consumed,
          verificationData: verification,
        ),
      );

      if (accepted) {
        return _issueTokens(
          principal,
          null,
          m,
          twoFactorSatisfied: true,
        );
      }

      if (consumed.isExhausted) {
        throw LoginException(
          'login.error.2fa.attempts-exhausted',
          'No two-factor attempts remain',
        );
      }

      // Retry: hand back the same challenge with the attempt spent, so the next
      // submission is counted against a token the client cannot roll back.
      final retry = _issueTokens(
        principal,
        null,
        m,
        challenge: consumed,
        twoFactorVerification: verification,
      );
      retry.error = 'login.error.2fa.invalid-code';
      return retry;
    } catch (ex, s) {
      return _failedResult(ex, s);
    }
  }

  /// Runs a login: builds [TomAuthenticationData] from the message, delegates to
  /// the guest or user service per [guestLogin], and encodes the principal into
  /// the authentication/authorization JWTs of the returned result.
  ///
  /// Whether a second factor is owed is [Tom2FAPolicy]'s decision, not a field
  /// read: the resolved policy is asked once, here, and anything but
  /// [Tom2FARequirement.disabled] takes the login down the challenge path. The
  /// mechanism's adaptor issues a challenge and the returned result carries an
  /// interim token plus [TomAuthenticationResult.requires2FA], to be completed
  /// by [authenticatePass2].
  ///
  /// [Tom2FARequirement.optional] currently behaves as `required` — the factor
  /// is challenged for. Letting a user *decline* an optional factor needs a
  /// wire-level "skip" the message type does not carry, so the decision is
  /// honoured to the extent the flow can honour it rather than being silently
  /// treated as `disabled`, which would be the unsafe reading.
  ///
  /// A [LoginException] yields a failed result carrying its `key`; any other
  /// error yields a `"login.error.unknown"` result.
  Future<TomAuthenticationResult> authenticateUser(
    TomAuthenticationMessage m,
    bool guestLogin,
  ) async {
    var authData = TomAuthenticationData(
      client: m.client,
      username: m.userName,
      organization: m.organization,
      application: m.application,
      process: m.process,
      language: m.clientLanguage,
      country: m.clientCountry,
      key: m.password,
      // TODO: get timezone from somewhere. Maybe best from user preferences in app?
      timezone: m.clientTimezone,
    );
    try {
      // TODO: is this where we get the principals cli from? Or is this obtained from the environment?
      var authInfo =
          await (guestLogin
                  ? globalSettingGuestAuthenticationService
                  : globalSettingUserAuthenticationService)
              .authenticateUser(authData);

      final context = _contextFor(authInfo.principal, m);
      final decision = await Tom2FAPolicy.resolve().decideFor(context);
      if (decision.isSatisfiedWithoutFactor) {
        return _issueTokens(authInfo.principal, authInfo.acd, m);
      }

      // The first mechanism the policy permits *and* this deployment has an
      // adaptor for. Both halves of that are needed: a policy names permissions,
      // and permissions the deployment cannot honour must fail here rather than
      // as a null adaptor further down.
      final offerable = decision.offerableMechanisms;
      if (offerable.isEmpty) {
        throw LoginException(
          'login.error.2fa.unsupported-mechanism',
          decision.allowedMechanisms.isEmpty
              ? 'The account requires a second factor but names no mechanism'
              : 'No adaptor is registered for any two-factor mechanism this '
                  'account may use: ${decision.allowedMechanisms.join(', ')}',
        );
      }
      final type = offerable.first;
      // Non-null by construction: `offerable` is the intersection with the
      // registry's own keys, so every entry resolves.
      final adaptor = Tom2FARegistry.lookup(type)!;

      final spec = await adaptor.issueChallenge(context);
      final challenge = Tom2FAChallenge(
        type: type,
        hint: spec.hint,
        attemptsAllowed: spec.attemptsAllowed,
        expiresAt: DateTime.now().toUtc().add(spec.validity),
        clientData: spec.clientData,
      );
      return _issueTokens(
        authInfo.principal,
        authInfo.acd,
        m,
        challenge: challenge,
        twoFactorVerification: spec.verificationData,
      );
    } catch (ex, s) {
      return _failedResult(ex, s);
    }
  }

  /// Projects [principal] onto the token pair of a [TomAuthenticationResult].
  ///
  /// The single point at which this server mints tokens, so a completed pass 2
  /// and a 2FA-free pass 1 provably produce the same claim set: the only
  /// difference between them is the [challenge] / [twoFactorSatisfied] pair fed
  /// into the projection.
  TomAuthenticationResult _issueTokens(
    TomPrincipal principal,
    TomAccessControlDefinition? definition,
    TomAuthenticationMessage m, {
    Tom2FAChallenge? challenge,
    Map<String, Object?>? twoFactorVerification,
    bool twoFactorSatisfied = false,
  }) {
    var (
      publicInfo,
      privateInfo,
    ) = TomBearerAuthentication.convertPrincipalToTokenPayload(
      principal,
      definition,
      m.clientCountry,
      m.clientLanguage,
      challenge: challenge,
      twoFactorVerification: twoFactorVerification,
      twoFactorSatisfied: twoFactorSatisfied,
    );

    var result = TomAuthenticationResult();
    result.authenticationToken =
        TomServerJwtToken(publicInfo).getJWT(globalSettingJwtOrganization);
    result.authorizationToken = TomServerJwtToken(
      publicInfo,
      encryptedData: privateInfo,
    ).getJWT(globalSettingJwtOrganization);
    if (challenge != null) {
      result.requires2FA = true;
      result.twoFactorType = challenge.type;
    }
    return result;
  }

  /// Builds the adaptor-facing context from the principal and the request.
  Tom2FAContext _contextFor(
    TomPrincipal principal,
    TomAuthenticationMessage m,
  ) =>
      Tom2FAContext(
        principal: principal,
        client: m.client,
        organization: m.organization,
        application: m.application,
        process: m.process,
        language: m.clientLanguage,
        country: m.clientCountry,
      );

  /// The adaptor's server-only payload from the interim token's encrypted
  /// section, or empty when the mechanism stored none (or the token was not
  /// decrypted).
  Map<String, Object?> _verificationDataOf(TomClientJwtToken token) {
    final raw = token.secretData?[Tom2FAClaims.verificationData];
    return raw is Map ? raw.cast<String, Object?>() : const <String, Object?>{};
  }

  /// Maps a thrown error onto a failed result: a [LoginException] surfaces its
  /// stable `key`, anything else is masked behind `"login.error.unknown"` so an
  /// internal fault never describes itself to the caller.
  TomAuthenticationResult _failedResult(Object ex, StackTrace s) {
    if (ex is LoginException) {
      tomLog.info("Login failed ${ex.key} ${ex.parameters}");
      return TomAuthenticationResult(ex.key);
    }
    tomLog.error("Login failed with unexpected error $ex");
    tomPrintStackTrace(s);
    return TomAuthenticationResult("login.error.unknown");
  }
}
