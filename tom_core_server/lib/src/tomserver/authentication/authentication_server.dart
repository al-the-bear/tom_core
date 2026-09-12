import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import '../preferences/user_preferences_service.dart';
import 'two_factor.dart';
import 'two_factor_attempts.dart';
import 'two_factor_enrolment.dart';
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
/// throw a [TomLoginException]. The default implementation,
/// [TomDummyAuthenticationService], accepts everything and is for scaffolding
/// only.
///
/// ## The implementation is the source of what the principal asserts
///
/// Everything the returned [TomPrincipal] carries is the implementation's
/// answer: the identity and its numeric ids, the locale, the access-control
/// information, and the client limits — [TomPrincipal.cli], the enabled modules
/// and quotas the client's subscription grants. [TomAuthenticationServer]
/// reads no subscription store and consults no environment; it encodes what it
/// was handed into the tokens.
///
/// Two values are resolved after the credential is accepted, each because the
/// implementation is not their authority:
///
/// - [TomPrincipal.timezone], from the user's stored preference — a
///   server-held *preference* rather than a fact about the identity being
///   asserted; see `_applyStoredTimezone`.
/// - [TomPrincipal.cli], from the installed [TomClientLimitsProvider], when one
///   is installed — the seam a subscription service fills, so that what a
///   client bought is answered by the service that sells it. With no provider,
///   the implementation's answer stands; see `_applyClientLimits`.
@tomReflector
abstract class TomAuthenticationService {
  /// Authenticates [authData], returning the principal and its access rights,
  /// or throwing a [TomLoginException] when the login is rejected.
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
      clientCountry: authData.country,
      clientLanguage: authData.language,
      clientTimezone: authData.timezone,
      user: TomUser(
        id: 0,
        username: authData.username,
        firstname: "guest",
        lastname: "guest",
        attributes: {},
        timezone: "utc",
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
  /// left"); it is **not** by itself a brute-force defence.
  ///
  /// What closes that is one recorded fact per token: *this one has been
  /// answered*. [Tom2FAAttemptStore] holds it, and this pass consults it before
  /// asking the mechanism anything, so each token in the chain is answerable
  /// exactly once and the chain admits exactly [Tom2FAChallenge.attemptsAllowed]
  /// guesses however the attacker orders it. A replay is refused with
  /// `login.error.2fa.challenge-already-answered` — including a replay of a
  /// *correct* answer, so one interim token cannot mint two sessions.
  ///
  /// The store is resolved rather than required: [Tom2FAMemoryAttemptStore] is
  /// the default and is per process, so a cluster bounds per node until a shared
  /// store is installed. The challenge's own short
  /// [Tom2FAChallengeSpec.validity] still bounds the chain in time on top of
  /// that.
  Future<TomAuthenticationResult> authenticatePass2(
    TomAuthenticationMessage m, {
    TomClientJwtToken? challengeToken,
  }) async {
    try {
      final token = challengeToken ?? getFromCurrentZone<TomClientJwtToken>();
      if (token == null) {
        throw TomLoginException(
          'login.error.2fa.no-challenge',
          'No pending two-factor challenge was presented',
        );
      }

      final challenge = Tom2FAChallenge.fromClaims(token.payload);
      if (challenge == null) {
        throw TomLoginException(
          'login.error.2fa.no-challenge',
          'The presented token carries no two-factor challenge',
        );
      }
      if (challenge.isExpired()) {
        throw TomLoginException(
          'login.error.2fa.expired',
          'The two-factor challenge has expired',
        );
      }
      if (challenge.isExhausted) {
        throw TomLoginException(
          'login.error.2fa.attempts-exhausted',
          'No two-factor attempts remain',
        );
      }

      // The interim token carries the access-control payload pass 1 resolved,
      // so the completed session needs no second trip to the user store — and
      // the principal cannot be swapped for another between the passes.
      // Resolved here rather than after verification because the attempt store
      // is told whose attempt it is refusing, and decoding a payload has no
      // side effect to sequence against.
      final principal = TomBearerAuthentication.convertTokenPayloadToPrincipal(
        token,
      );

      // Before the mechanism is asked anything, so a replay costs a request and
      // buys no information. The token's own identity is what is spent: a wrong
      // answer is what mints the next token, so one answer per token is one
      // guess per allowance, whichever token in the chain is presented.
      final fresh = await Tom2FAAttemptStore.resolve().spend(
        Tom2FAAttempt(
          fingerprint: tom2FATokenFingerprint(token.tokenString),
          username: principal.username,
          challengeType: challenge.type,
          notAfter: challenge.expiresAt,
        ),
      );
      if (!fresh) {
        throw TomLoginException(
          'login.error.2fa.challenge-already-answered',
          'This two-factor challenge token has already been answered',
        );
      }

      final adaptor = Tom2FARegistry.lookup(challenge.type);
      if (adaptor == null) {
        throw TomLoginException(
          'login.error.2fa.unsupported-mechanism',
          'No adaptor is registered for two-factor mechanism '
              '"${challenge.type}"',
        );
      }

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
        return _issueTokens(principal, null, m, twoFactorSatisfied: true);
      }

      if (consumed.isExhausted) {
        throw TomLoginException(
          'login.error.2fa.attempts-exhausted',
          'No two-factor attempts remain',
        );
      }

      // Retry: hand back the same challenge with the attempt spent, so the next
      // submission is counted against a token the client cannot roll back.
      final retry = await _issueTokens(
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
  /// ## The four shapes a deployment can be in
  ///
  /// | Policy | User has a usable factor | Outcome |
  /// | --- | --- | --- |
  /// | `disabled` | — | tokens, no mention of 2FA |
  /// | `required` / `optional` | yes | interim token + challenge, answered by [authenticatePass2] |
  /// | `required` | no | interim token + **enrolment offer**, answered by [beginTwoFactorEnrolment] |
  /// | `optional` (or `required` with grace left) | no | the same offer, additionally declinable via [skipTwoFactorEnrolment] |
  ///
  /// "Has a usable factor" is [Tom2FAEnrolmentStore]'s answer, narrowed to the
  /// mechanisms the policy permits. A deployment that installed **no** store
  /// keeps the pre-enrolment behaviour exactly — it is challenged for its
  /// factor, and the adaptor remains the only authority on whether the user has
  /// one — because there would be nowhere to record an enrolment, and offering
  /// one that could not be saved would be a lie.
  ///
  /// A [TomLoginException] yields a failed result carrying its `key`; any other
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
      // The client's assertion, and necessarily so: this data is what
      // *identifies* the user to the authentication service, so it is assembled
      // before there is a principal — and without a principal there is no
      // stored preference to read. The user's own timezone is resolved once the
      // credentials have been accepted, in `_applyStoredTimezone`.
      timezone: m.clientTimezone,
    );
    try {
      // This call is where the principal's client limits come from — the
      // subscription rides on the principal the service returns, and the server
      // adds nothing to it. See the TomAuthenticationService contract above for
      // why that is the whole answer and not merely the current behaviour.
      var authInfo =
          await (guestLogin
                  ? globalSettingGuestAuthenticationService
                  : globalSettingUserAuthenticationService)
              .authenticateUser(authData);

      return await _completeLogin(authInfo, m);
    } catch (ex, s) {
      return _failedResult(ex, s);
    }
  }

  /// Authenticates a login whose credential was established by an **external**
  /// identity provider, and completes it exactly as a password login completes.
  ///
  /// [credential] travels in [TomAuthenticationData.key] — the slot that carries
  /// a password for a password login, typed `Object?` for precisely this reason
  /// — and is verified by the configured
  /// [globalSettingUserAuthenticationService], which a deployment offering
  /// external identity wraps in a `TomOAuthAuthenticationService`. This method
  /// therefore adds **no** second way to authenticate: it hands a differently
  /// shaped credential to the same contract.
  ///
  /// What it deliberately does not do is decide anything about the resulting
  /// session. The 2FA policy, the enrolment offer, the stored-timezone
  /// resolution and the claim set all come from [_completeLogin], the same
  /// continuation [authenticateUser] reaches — so an externally authenticated
  /// principal is challenged for its second factor and issued exactly the claims
  /// a password login would have produced for it. See the module readme: the day
  /// this method issues its own tokens, the two copies start to drift, and the
  /// copy that drifts is the one that stops asking for a second factor.
  Future<TomAuthenticationResult> authenticateExternal(
    TomAuthenticationMessage m,
    Object credential,
  ) async {
    final authData = TomAuthenticationData(
      client: m.client,
      username: m.userName,
      organization: m.organization,
      application: m.application,
      process: m.process,
      language: m.clientLanguage,
      country: m.clientCountry,
      key: credential,
      timezone: m.clientTimezone,
    );
    try {
      final authInfo = await globalSettingUserAuthenticationService
          .authenticateUser(authData);
      return await _completeLogin(authInfo, m);
    } catch (ex, s) {
      return _failedResult(ex, s);
    }
  }

  /// Everything that happens *after* a credential has been verified: the 2FA
  /// policy decision, the challenge-or-enrolment branch, and token issuance.
  ///
  /// Extracted so that there is exactly one of it. [authenticateUser] and
  /// [authenticateExternal] resolve a principal by different means and then join
  /// here; nothing below this line knows or asks which of them called it, so a
  /// third way of resolving a principal acquires the whole of this behaviour by
  /// *calling* it rather than by agreeing with it.
  ///
  /// Exceptions propagate: both callers already wrap their own resolution step
  /// in the `try` that turns a [TomLoginException] into a failed result, and a
  /// second catch here would make the failure path two places as well.
  Future<TomAuthenticationResult> _completeLogin(
    TomAuthenticationInfo authInfo,
    TomAuthenticationMessage m,
  ) async {
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
      throw TomLoginException(
        'login.error.2fa.unsupported-mechanism',
        decision.allowedMechanisms.isEmpty
            ? 'The account requires a second factor but names no mechanism'
            : 'No adaptor is registered for any two-factor mechanism this '
                  'account may use: ${decision.allowedMechanisms.join(', ')}',
      );
    }
    // What this user has actually set up, narrowed to what they may use.
    // `null` means "no store installed", which is not the same as "none
    // enrolled" and must not be treated as it: the first keeps the legacy
    // challenge path, the second is what forces enrolment.
    final enrolled = await _usableEnrolments(context, offerable);
    if (enrolled != null && enrolled.isEmpty) {
      return _offerEnrolment(authInfo, m, decision, offerable);
    }

    // The user's primary factor among the permitted ones — not simply the
    // policy's first choice, so a user with several factors is challenged for
    // the one they nominated rather than for whichever the policy happens to
    // list first.
    //
    // Only two of the three outcomes reach this line: empty returned above, so
    // `null` here means *no store installed* and nothing else. That is what
    // makes the fallback legitimate — a deployment that tracks no enrolments
    // has no nomination to honour, so the policy's first choice is the only
    // answer available. It is not a stand-in for "this user has none".
    final type = enrolled == null ? offerable.first : _primaryOf(enrolled).type;
    // Non-null by construction: `offerable` is the intersection with the
    // registry's own keys, and `enrolled` was filtered against it.
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
  }

  // ---------------------------------------------------------------------------
  // Enrolment passes
  // ---------------------------------------------------------------------------

  /// Enrolment pass 1: begins setting up the mechanism the user chose.
  ///
  /// The chosen mechanism key travels in [TomAuthenticationMessage.password] —
  /// the message's one payload slot, used here exactly as [authenticatePass2]
  /// uses it for the submitted code. Every pass in this flow carries a single
  /// user-supplied value, and giving each its own wire field would say the
  /// passes are more different than they are.
  ///
  /// The offer token is recovered from the **interim token the client
  /// presents**, as everywhere else in this flow; [enrolmentToken] overrides
  /// that lookup for tests running without a request zone.
  ///
  /// Returns an interim token whose public claims carry the mechanism's
  /// [Tom2FAEnrolmentOffer.clientData] — for TOTP, the secret and the
  /// `otpauth://` URI the user scans — and whose encrypted section carries the
  /// whole offer, so [completeTwoFactorEnrolment] can check the typed code
  /// against material the client could not have edited.
  ///
  /// Refuses a mechanism that was not in the offer this token was issued with:
  /// the authority for what may be enrolled is the list *the server* named,
  /// never the key the client sends back.
  Future<TomAuthenticationResult> beginTwoFactorEnrolment(
    TomAuthenticationMessage m, {
    TomClientJwtToken? enrolmentToken,
  }) async {
    try {
      final (token, state) = _pendingEnrolment(enrolmentToken);

      final type = m.password.trim();
      if (!state.offeredTypes.contains(type)) {
        throw TomLoginException(
          'login.error.2fa.enrolment-not-offered',
          'Two-factor mechanism "$type" was not offered for enrolment',
        );
      }
      final support = Tom2FARegistry.enrolmentSupportFor(type);
      if (support == null) {
        throw TomLoginException(
          'login.error.2fa.unsupported-mechanism',
          'No enrollable adaptor is registered for two-factor mechanism '
              '"$type"',
        );
      }

      final principal = TomBearerAuthentication.convertTokenPayloadToPrincipal(
        token,
      );
      final context = _contextFor(principal, m);
      final offer = await support.beginEnrolment(context);

      return _issueTokens(
        principal,
        null,
        m,
        enrolment: state.withOffer(offer),
      );
    } catch (ex, s) {
      return _failedResult(ex, s);
    }
  }

  /// Enrolment pass 2: confirms the offer and completes the login.
  ///
  /// The typed confirmation travels in [TomAuthenticationMessage.password].
  ///
  /// On success the factor is written to the [Tom2FAEnrolmentStore] and the
  /// **full token pair is issued immediately**, with no further challenge. A
  /// user who has just derived a code from the secret they were handed has
  /// demonstrated possession of the factor; challenging them for a second code
  /// a moment later would prove nothing that this pass has not already proved.
  ///
  /// A wrong code stores nothing and returns a retry — the same offer with one
  /// attempt spent, exactly as [authenticatePass2] does for a wrong challenge
  /// answer — until [Tom2FAEnrolmentOffer.attemptsAllowed] is exhausted. And as
  /// there, the count alone would bound only a cooperative client, so the offer
  /// token is spent against [Tom2FAAttemptStore] before the mechanism is asked
  /// anything: a replay is refused with
  /// `login.error.2fa.enrolment-already-answered`.
  Future<TomAuthenticationResult> completeTwoFactorEnrolment(
    TomAuthenticationMessage m, {
    TomClientJwtToken? enrolmentToken,
  }) async {
    try {
      final (token, state) = _pendingEnrolment(enrolmentToken);

      final offer = state.offer;
      if (offer == null) {
        throw TomLoginException(
          'login.error.2fa.enrolment-offer-invalid',
          'No two-factor enrolment has been begun on this token',
        );
      }
      if (state.isExpired()) {
        throw TomLoginException(
          'login.error.2fa.enrolment-expired',
          'The two-factor enrolment has expired',
        );
      }
      if (state.isExhausted) {
        throw TomLoginException(
          'login.error.2fa.enrolment-attempts-exhausted',
          'No two-factor enrolment attempts remain',
        );
      }

      // The same bound as [authenticatePass2], for the same reason: the count
      // rides in the token, so without a record of what has been answered a
      // replay of an earlier offer token buys a fresh allowance. It matters for
      // the mechanisms whose confirmation is a code sent out of band — an
      // authenticator app hands the secret to whoever holds the token, so
      // guessing its code proves nothing, but an emailed code is exactly as
      // brute-forceable here as a challenge code is there.
      final fresh = await Tom2FAAttemptStore.resolve().spend(
        Tom2FAAttempt(
          fingerprint: tom2FATokenFingerprint(token.tokenString),
          username: TomBearerAuthentication.convertTokenPayloadToPrincipal(
            token,
          ).username,
          challengeType: offer.type,
          // Never null here: a begun state with no deadline reads as expired,
          // and the check above has already refused it. The fallback records a
          // lapsed attempt — pruned at once, and about a request that is
          // refused either way — rather than inventing a window.
          notAfter: state.expiresAt ?? DateTime.now().toUtc(),
        ),
      );
      if (!fresh) {
        throw TomLoginException(
          'login.error.2fa.enrolment-already-answered',
          'This two-factor enrolment token has already been answered',
        );
      }

      final support = Tom2FARegistry.enrolmentSupportFor(offer.type);
      if (support == null) {
        throw TomLoginException(
          'login.error.2fa.unsupported-mechanism',
          'No enrollable adaptor is registered for two-factor mechanism '
              '"${offer.type}"',
        );
      }
      final store = Tom2FAEnrolmentStore.resolve();
      if (store == null) {
        throw TomLoginException(
          'login.error.2fa.enrolment-unavailable',
          'This deployment has no two-factor enrolment store, so the factor '
              'cannot be recorded',
        );
      }

      final principal = TomBearerAuthentication.convertTokenPayloadToPrincipal(
        token,
      );
      final context = _contextFor(principal, m);
      final consumed = state.withConsumedAttempt();

      final Tom2FAEnrolment confirmed;
      try {
        confirmed = await support.confirmEnrolment(context, offer, m.password);
      } on TomLoginException catch (ex) {
        // The confirmation contract signals every failure by throwing, so a
        // throw here is treated the way a `false` from `verifySubmission` is:
        // one attempt spent, then the same offer handed back.
        if (consumed.isExhausted) {
          throw TomLoginException(
            'login.error.2fa.enrolment-attempts-exhausted',
            'No two-factor enrolment attempts remain',
          );
        }
        final retry = await _issueTokens(
          principal,
          null,
          m,
          enrolment: consumed,
        );
        retry.error = ex.key;
        return retry;
      }

      // The user's first factor becomes their primary one, so the next login
      // has something to challenge without anyone having to nominate it.
      final existing = await store.enrolmentsFor(context);
      await store.store(
        context,
        existing.isEmpty ? confirmed.copyWith(isPrimary: true) : confirmed,
      );

      return _issueTokens(principal, null, m, twoFactorSatisfied: true);
    } catch (ex, s) {
      return _failedResult(ex, s);
    }
  }

  /// Declines a skippable enrolment offer and completes the login with no
  /// factor.
  ///
  /// A pass of its own rather than a flag on [completeTwoFactorEnrolment],
  /// because "I set up a factor" and "I chose not to" are different events with
  /// different consequences — only the second spends a grace login — and a
  /// boolean that switched between them would make the audit trail depend on a
  /// parameter's default.
  ///
  /// Refuses unless the presented token says the offer was skippable. That flag
  /// is one this server signed, so a client that decides for itself that it may
  /// decline achieves nothing — but only because the signature is *checked*:
  /// `verifyBearerToken` does that on the inbound path, and without it the flag
  /// would be plain base64 the caller could edit. See `jwt_signing.dart`.
  Future<TomAuthenticationResult> skipTwoFactorEnrolment(
    TomAuthenticationMessage m, {
    TomClientJwtToken? enrolmentToken,
  }) async {
    try {
      final (token, state) = _pendingEnrolment(enrolmentToken);
      if (!state.skippable) {
        throw TomLoginException(
          'login.error.2fa.enrolment-required',
          'This two-factor enrolment cannot be declined',
        );
      }

      final principal = TomBearerAuthentication.convertTokenPayloadToPrincipal(
        token,
      );
      final context = _contextFor(principal, m);

      if (state.skipSpendsGrace) {
        if (Tom2FAPolicy.resolve() case final Tom2FAGraceAccounting policy) {
          await policy.recordGraceLoginConsumed(context);
        }
      }

      return _issueTokens(principal, null, m, twoFactorSatisfied: true);
    } catch (ex, s) {
      return _failedResult(ex, s);
    }
  }

  /// The interim token and the enrolment it carries, or a thrown
  /// [TomLoginException] when it carries none.
  ///
  /// This is what stops the enrolment passes from being an unauthenticated way
  /// to attach a factor to an account: a completed token has no pending
  /// enrolment, so presenting one is refused here before any mechanism is
  /// reached. Only a token this server minted while branching a login into
  /// enrolment gets past.
  (TomClientJwtToken, Tom2FAEnrolmentState) _pendingEnrolment(
    TomClientJwtToken? presented,
  ) {
    final token = presented ?? getFromCurrentZone<TomClientJwtToken>();
    if (token == null) {
      throw TomLoginException(
        'login.error.2fa.no-enrolment',
        'No pending two-factor enrolment was presented',
      );
    }
    final state = Tom2FAEnrolmentState.fromClaims(
      token.payload,
      token.secretData,
    );
    if (state == null) {
      throw TomLoginException(
        'login.error.2fa.no-enrolment',
        'The presented token carries no pending two-factor enrolment',
      );
    }
    return (token, state);
  }

  /// Branches the login into enrolment: an interim token offering every
  /// permitted mechanism this deployment can actually set up.
  ///
  /// `async` so the "nothing here can be enrolled" refusal is a rejected future
  /// rather than a synchronous throw. Today the sole call site is inside an
  /// `async` body, which captures it either way; the declared return type is
  /// the contract a second call site would rely on.
  Future<TomAuthenticationResult> _offerEnrolment(
    TomAuthenticationInfo authInfo,
    TomAuthenticationMessage m,
    Tom2FADecision decision,
    List<String> offerable,
  ) async {
    final enrollable = [
      for (final type in offerable)
        if (Tom2FARegistry.enrolmentSupportFor(type) != null) type,
    ];
    if (enrollable.isEmpty) {
      throw TomLoginException(
        'login.error.2fa.unsupported-mechanism',
        'The account requires a second factor it has not set up, and none of '
            'the mechanisms it may use can be enrolled here: '
            '${offerable.join(', ')}',
      );
    }

    // Grace softens `required` into a declinable offer; `optional` is
    // declinable by definition and costs nothing.
    final optional = decision.requirement == Tom2FARequirement.optional;
    final onGrace = !optional && decision.graceLogins > 0;

    return _issueTokens(
      authInfo.principal,
      authInfo.acd,
      m,
      enrolment: Tom2FAEnrolmentState(
        offeredTypes: enrollable,
        skippable: optional || onGrace,
        skipSpendsGrace: onGrace,
      ),
    );
  }

  /// This principal's set-up factors among [offerable], or `null` when no
  /// [Tom2FAEnrolmentStore] is installed.
  ///
  /// The three outcomes are deliberately distinguishable: `null` is *nobody
  /// tracks enrolments here*, an empty list is *tracked, and this user has
  /// none*, and a non-empty list names what to challenge. Collapsing the first
  /// two would force enrolment on every deployment that never opted in.
  Future<List<Tom2FAEnrolment>?> _usableEnrolments(
    Tom2FAContext context,
    List<String> offerable,
  ) async {
    final store = Tom2FAEnrolmentStore.resolve();
    if (store == null) return null;
    final enrolments = await store.enrolmentsFor(context);
    return [
      for (final enrolment in enrolments)
        if (offerable.contains(enrolment.type)) enrolment,
    ];
  }

  /// The enrolment to challenge: the one the user nominated, or the first if
  /// none is nominated. [enrolments] must not be empty.
  Tom2FAEnrolment _primaryOf(List<Tom2FAEnrolment> enrolments) =>
      enrolments.firstWhere(
        (enrolment) => enrolment.isPrimary,
        orElse: () => enrolments.first,
      );

  /// Projects [principal] onto the token pair of a [TomAuthenticationResult].
  ///
  /// The single point at which this server mints tokens, so a completed pass 2
  /// and a 2FA-free pass 1 provably produce the same claim set: the only
  /// difference between them is the [challenge] / [enrolment] /
  /// [twoFactorSatisfied] triple fed into the projection.
  ///
  /// [challenge] and [enrolment] are mutually exclusive by construction — a
  /// login is either answering a factor or setting one up — and each turns the
  /// pair into an *interim* token that grants no session.
  ///
  /// It is also where the principal's stored preferences are applied
  /// ([_applyStoredTimezone]) and its client limits are asked of the installed
  /// [TomClientLimitsProvider] ([_applyClientLimits]), for the same reason:
  /// every token this server mints, on every pass, then carries the same
  /// resolved values.
  Future<TomAuthenticationResult> _issueTokens(
    TomPrincipal principal,
    TomAccessControlDefinition? definition,
    TomAuthenticationMessage m, {
    Tom2FAChallenge? challenge,
    Map<String, Object?>? twoFactorVerification,
    Tom2FAEnrolmentState? enrolment,
    bool twoFactorSatisfied = false,
  }) async {
    await _applyStoredTimezone(principal, m);
    await _applyClientLimits(principal);

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

    if (enrolment != null) {
      // A pending enrolment must not grant a session either, and the claim that
      // withholds one is the same claim a pending challenge sets: everything
      // downstream asks "may this token act?", and for both states the answer
      // is no. Set before the enrolment's own claims so neither can be
      // shadowed by the projection's default.
      publicInfo[Tom2FAClaims.requires2FA] = 'true';
      publicInfo.addAll(enrolment.toClaims());
      final secret = enrolment.secretClaims;
      if (secret != null) privateInfo.addAll(secret);
    }

    var result = TomAuthenticationResult();
    result.authenticationToken = TomServerJwtToken(
      publicInfo,
    ).getJWT(globalSettingJwtOrganization);
    result.authorizationToken = TomServerJwtToken(
      publicInfo,
      encryptedData: privateInfo,
    ).getJWT(globalSettingJwtOrganization);
    if (challenge != null) {
      result.requires2FA = true;
      result.twoFactorType = challenge.type;
    }
    if (enrolment != null) {
      result.requires2FAEnrolment = true;
      result.availableTwoFactorMethods = _descriptorsFor(
        enrolment.offeredTypes,
      );
      result.twoFactorEnrolmentSkippable = enrolment.skippable;
    }
    return result;
  }

  /// Resolves [principal]'s effective timezone before it is minted into a
  /// token: the preference stored for the user, else the one the client
  /// asserted.
  ///
  /// The two are different claims and both survive.
  /// [TomPrincipal.clientTimezone] is what the *device* says it is in — a fact
  /// only the device knows, and one that changes when the user travels.
  /// [TomPrincipal.timezone] is what the *user chose*, which follows them onto
  /// the next device and is therefore the server's to answer. With no stored
  /// preference there is nowhere to read the second from, so the client's
  /// assertion serves as both.
  ///
  /// The preference wins when it exists because it is the only one of the two
  /// the user set deliberately; the device's assertion remains the fallback,
  /// so a user who has never set the preference keeps the device's answer.
  Future<void> _applyStoredTimezone(
    TomPrincipal principal,
    TomAuthenticationMessage m,
  ) async {
    principal.clientTimezone = m.clientTimezone;
    principal.timezone = await _storedTimezone(principal) ?? m.clientTimezone;
  }

  /// Replaces [principal]'s client limits with the installed
  /// [TomClientLimitsProvider]'s answer, when there is a provider and it has
  /// one.
  ///
  /// The provider is the seam a subscription service fills; with none
  /// installed, the limits stay what the authentication service put on the
  /// principal. A provider that fails costs no one their login, for the same
  /// reason as a stored-preference failure: an unreachable subscription service
  /// would otherwise stop every sign-in. The failure is logged and the
  /// authentication service's answer is minted — exactly what a deployment
  /// without a provider issues.
  Future<void> _applyClientLimits(TomPrincipal principal) async {
    final provider = TomClientLimitsProvider.installed;
    if (provider == null) return;
    try {
      final limits = await provider.clientLimitsFor(principal);
      if (limits != null) principal.cli = limits;
    } catch (error) {
      tomLog.warn(
        'TomAuthenticationServer: the client limits of '
        '"${principal.username}" could not be read from the installed '
        'TomClientLimitsProvider; minting the limits the authentication '
        'service returned. Cause: $error',
      );
    }
  }

  /// [principal]'s stored timezone preference, or `null` when there is none to
  /// be had.
  ///
  /// Read through [TomUserPreferences.getFor] because there is no request zone
  /// carrying this principal yet — it has only just been authenticated — and
  /// that method installs one, so the read is scoped like every other.
  ///
  /// Why: a failure here must not cost the user their login. A deployment that
  /// has not run the preferences migration, or a preference someone stored as
  /// the wrong type, would otherwise turn an unrelated data problem into "no
  /// one can sign in". The failure is logged and the client's assertion is
  /// used, which is exactly the behaviour of a deployment that stores no
  /// preferences at all.
  Future<String?> _storedTimezone(TomPrincipal principal) async {
    final preferences = TomUserPreferences.resolve();
    if (preferences == null) return null;
    try {
      return await preferences.getFor<String>(
        principal,
        TomUserPreferenceKeys.timezone,
      );
    } catch (error) {
      tomLog.warn(
        'TomAuthenticationServer: the stored timezone preference of '
        '"${principal.username}" could not be read; falling back to the '
        'timezone the client asserted. Cause: $error',
      );
      return null;
    }
  }

  /// How the offered mechanisms describe themselves, in the order they were
  /// offered.
  ///
  /// Asks the registry rather than carrying descriptors in the token: the
  /// catalog is a property of the running deployment, and a token minted before
  /// a mechanism's resource keys were corrected would otherwise keep handing out
  /// the old ones.
  List<Tom2FAMethodDescriptor> _descriptorsFor(List<String> types) => [
    for (final type in types)
      if (Tom2FARegistry.lookup(type) case final adaptor?) adaptor.descriptor,
  ];

  /// Builds the adaptor-facing context from the principal and the request.
  Tom2FAContext _contextFor(
    TomPrincipal principal,
    TomAuthenticationMessage m,
  ) => Tom2FAContext(
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

  /// Maps a thrown error onto a failed result: a [TomLoginException] surfaces
  /// its stable `key`, anything else is masked behind `"login.error.unknown"` so
  /// an internal fault never describes itself to the caller.
  TomAuthenticationResult _failedResult(Object ex, StackTrace s) {
    if (ex is TomLoginException) {
      tomLog.info("Login failed ${ex.key} ${ex.parameters}");
      return TomAuthenticationResult(ex.key);
    }
    tomLog.error("Login failed with unexpected error $ex");
    tomPrintStackTrace(s);
    return TomAuthenticationResult("login.error.unknown");
  }
}
