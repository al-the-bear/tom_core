/// Executable example for the **second-factor enrolment round trip** of the
/// `tom_core_server` authentication module: what happens the first time a
/// policy demands a factor the user has not set up yet.
///
/// This is the flow that turns "you must use 2FA" from a lockout into an
/// onboarding step. Pass 1 answers with an *offer* rather than a challenge —
/// [TomAuthenticationResult.requires2FAEnrolment] rather than
/// [TomAuthenticationResult.requires2FA], never both — listing the mechanisms
/// that can be set up here. The client picks one and calls
/// [TomAuthenticationServer.beginTwoFactorEnrolment], which hands back the
/// material to install (a secret, a QR payload). Proving possession of it once
/// through [TomAuthenticationServer.completeTwoFactorEnrolment] both records
/// the factor and issues the session: no second hoop, because proving
/// possession once is proving it.
///
/// Where an offer is declinable, [TomAuthenticationServer.skipTwoFactorEnrolment]
/// is the third exit.
///
/// Two things make this the part of the module hardest to get right from prose,
/// and therefore the part most worth demonstrating. First, the message's single
/// credential slot means something *different* on each of the three calls: the
/// password, then the chosen mechanism's key, then the confirmation code.
/// Second, the token is re-minted at every step, so each call must present the
/// one the previous call returned.
///
/// The seams a deployment supplies are the mechanism (a [Tom2FAService] that
/// also implements [Tom2FAEnrolmentSupport]) and somewhere to record the result
/// (a [Tom2FAEnrolmentStore]). Both are stubbed in memory below; everything
/// between them is the production path, and it needs no database and no port.
///
/// The framework's key-configuration warning and its no-reflection notice are
/// expected in the output — see `two_factor_login_example.dart`, which covers
/// the login that follows once a factor exists.
///
/// Run with `dart run example/authentication/two_factor_enrolment_example.dart`.
/// Every result the eight steps print is checked and the run fails when one
/// does not hold, so a green run is a verification and not just a transcript.
/// The same behaviour is covered by `test/two_factor_test.dart`.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

/// Builds the wire message the server consumes.
///
/// [password] is the single credential slot, and the three enrolment calls read
/// it as three different things — which is exactly the subtlety this example
/// exists to make visible.
TomAuthenticationMessage _message({String password = 's3cret'}) =>
    TomAuthenticationMessage()
      ..client = 'web'
      ..userName = 'alice'
      ..password = password
      ..organization = 'acme'
      ..application = 'console'
      ..process = 'login'
      ..clientLanguage = 'en'
      ..clientCountry = 'US'
      ..clientTimezone = 'UTC';

/// A deployment's password check, standing in for a user directory.
class _DirectoryService implements TomAuthenticationService {
  @override
  Future<TomAuthenticationInfo> authenticateUser(
    TomAuthenticationData a,
  ) async => TomAuthenticationInfo(
    TomPrincipal(
      authenticated: true,
      context: {},
      clientId: 0,
      organization: a.organization,
      organizationId: 0,
      application: a.application,
      applicationId: 0,
      process: a.process,
      processId: 0,
      language: a.language,
      country: a.country,
      clientCountry: a.country,
      clientLanguage: a.language,
      clientTimezone: a.timezone,
      user: TomUser(
        id: 1,
        username: a.username,
        firstname: 'Alice',
        lastname: 'Example',
        attributes: {},
        timezone: 'utc',
      ),
      aci: TomAccessControlInformation(roles: const ['admin']),
    ),
    TomAccessControlDefinition(),
  );
}

/// An authenticator-app mechanism that can be *set up*, not merely answered.
///
/// [Tom2FAEnrolmentSupport] is a separate interface from [Tom2FAService] on
/// purpose: a registry may hold mechanisms that can challenge but not enrol —
/// a hardware token issued out of band, say — and the offer must name only the
/// ones a user can actually complete here. [_SmsAdaptor] below is that other
/// shape, present so the difference is observable rather than asserted.
///
/// The offer, like a challenge, carries two payloads. `clientData` is what the
/// user installs; `enrolmentData` is the copy the server confirms against, and
/// it rides encrypted, so a client cannot swap the secret it is about to prove
/// possession of.
class _AuthenticatorApp implements Tom2FAService, Tom2FAEnrolmentSupport {
  /// The mechanism key this adaptor is registered under.
  static const String type = 'app';

  /// The material handed to the client to install.
  static const String secret = 'JBSWY3DPEHPK3PXP';

  /// The one confirmation this adaptor accepts — a fixed code rather than a
  /// real time-based one, so the example does not depend on the clock.
  static const String confirmation = '111222';

  /// How many offers it made, how many confirmations it checked, and how many
  /// challenges it issued afterwards — the last of which must stay at zero.
  int begun = 0;
  int confirmed = 0;
  int issued = 0;

  @override
  Tom2FAMethodDescriptor get descriptor => Tom2FAMethodDescriptor.scoped(type);

  @override
  Future<Tom2FAEnrolmentOffer> beginEnrolment(Tom2FAContext context) async {
    begun++;
    return Tom2FAEnrolmentOffer(
      type: type,
      hint: 'authenticator app on this phone',
      clientData: const {
        'setupCode': secret,
        'otpauthUri': 'otpauth://totp/acme:alice?secret=$secret&issuer=acme',
      },
      enrolmentData: const {'secret': secret},
      attemptsAllowed: 2,
      validity: const Duration(minutes: 10),
    );
  }

  @override
  Future<Tom2FAEnrolment> confirmEnrolment(
    Tom2FAContext context,
    Tom2FAEnrolmentOffer offer,
    String submitted,
  ) async {
    confirmed++;
    if (submitted != confirmation) {
      throw TomLoginException(
        'login.error.2fa.enrolment-invalid-code',
        'The confirmation code does not match the offered factor',
        reason: TomLoginFailure.secondFactorInvalid,
      );
    }
    return Tom2FAEnrolment(
      type: type,
      enrolmentId: 'enrolment-1',
      hint: offer.hint,
      secretData: offer.enrolmentData,
    );
  }

  @override
  Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context) async {
    issued++;
    return const Tom2FAChallengeSpec(
      hint: 'authenticator app on this phone',
      attemptsAllowed: 3,
      validity: Duration(minutes: 5),
    );
  }

  @override
  Future<bool> verifySubmission(
    Tom2FAContext context,
    Tom2FASubmission submission,
  ) async => submission.submitted == confirmation;
}

/// A mechanism that can answer a challenge but cannot be set up from a login.
class _SmsAdaptor implements Tom2FAService {
  /// The mechanism key this adaptor is registered under.
  static const String type = 'sms';

  @override
  Tom2FAMethodDescriptor get descriptor => Tom2FAMethodDescriptor.scoped(type);

  @override
  Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context) async =>
      const Tom2FAChallengeSpec(
        hint: '***-**-4711',
        attemptsAllowed: 3,
        validity: Duration(minutes: 5),
      );

  @override
  Future<bool> verifySubmission(
    Tom2FAContext context,
    Tom2FASubmission submission,
  ) async => submission.submitted == '424242';
}

/// The mechanism and the store the current configuration installed.
late _AuthenticatorApp _app;
late TomMemory2FAEnrolmentStore _store;

/// Installs both mechanisms, the enrolment store, and a policy at
/// [requirement] permitting both — so what the offer *omits* is the framework's
/// doing rather than the configuration's.
void _configure(Tom2FARequirement requirement) {
  _app = _AuthenticatorApp();
  Tom2FARegistry.reset();
  Tom2FARegistry.register(_AuthenticatorApp.type, _app);
  Tom2FARegistry.register(_SmsAdaptor.type, _SmsAdaptor());

  TomBean.resetBeanContext();
  _store = TomMemory2FAEnrolmentStore();
  TomBean.withType<Tom2FAEnrolmentStore>(_store);
  TomBean.withType<Tom2FAPolicy>(
    TomRole2FAPolicy(
      defaultRequirement: requirement,
      mechanisms: const [_SmsAdaptor.type, _AuthenticatorApp.type],
    ),
  );

  TomAuthenticationServer.globalSettingUserAuthenticationService =
      _DirectoryService();
}

/// The context the server builds for the logging-in user, so this example can
/// read the store back under the same key the flow wrote it with.
Tom2FAContext _contextOfAlice() => Tom2FAContext(
  principal: TomPrincipal(
    authenticated: true,
    context: {},
    clientId: 0,
    organization: 'acme',
    organizationId: 0,
    application: 'console',
    applicationId: 0,
    process: 'login',
    processId: 0,
    language: 'en',
    country: 'US',
    clientCountry: 'US',
    clientLanguage: 'en',
    clientTimezone: 'UTC',
    user: TomUser(
      id: 1,
      username: 'alice',
      firstname: 'Alice',
      lastname: 'Example',
      attributes: {},
      timezone: 'utc',
    ),
    aci: TomAccessControlInformation(roles: const ['admin']),
  ),
);

Future<void> run() async {
  final server = TomAuthenticationServer();
  _configure(Tom2FARequirement.required);

  // Example 1: pass 1 offers, it does not lock out. A required policy meeting a
  // user with nothing enrolled is a third outcome rather than a hard failure,
  // and distinct from a challenge -- `requires2FAEnrolment` and `requires2FA`
  // are never both set, so a client can switch on which arrived.
  //
  // Only the app is offered. SMS is permitted by the policy and registered, but
  // it cannot be set up from a login, and advertising it would give the chooser
  // an entry that fails the moment it is picked.
  final offer = await server.authenticatePass1(_message());
  print('offer error:               "${offer.error}"');
  print('requires enrolment:        ${offer.requires2FAEnrolment}');
  print('requires a challenge:      ${offer.requires2FA}');
  print(
    'offered mechanisms:        '
    '${offer.availableTwoFactorMethods.map((m) => m.type).toList()}',
  );
  print('declinable:                ${offer.twoFactorEnrolmentSkippable}');

  // The chooser has to render in the user's own language, so a mechanism
  // advertises resource keys rather than a display string -- and never the bare
  // mechanism key, which is a wiring identifier.
  final method = offer.availableTwoFactorMethods.single;
  print('display name key:          ${method.displayNameKey}');
  print('description key:           ${method.descriptionKey}');
  print('icon key:                  ${method.iconKey}');

  // Example 2: the offer token is not a session either. Same rule as an interim
  // challenge token: the identity is real so the next call need not re-check
  // the password, but nothing is authenticated until the round trip finishes.
  final offered = TomClientJwtToken(offer.authorizationToken);
  final beforeEnrolling =
      TomBearerAuthentication.convertTokenPayloadToPrincipal(offered);
  print('offer token username:      ${beforeEnrolling.username}');
  print('offer token authenticated: ${beforeEnrolling.authenticated}');

  // Example 3: the client picks a mechanism -- and the credential slot now
  // carries the *mechanism key*, not a password and not a code. What comes back
  // is what the user has to install, in the public claims so the client can
  // render a QR code from it.
  final begun = await server.beginTwoFactorEnrolment(
    _message(password: _AuthenticatorApp.type),
    enrolmentToken: offered,
  );
  final publicClaims = TomClientJwtToken(
    begun.authorizationToken,
    decrypt: false,
  ).payload;
  final clientData =
      publicClaims?[Tom2FAEnrolmentClaims.clientData] as Map<String, dynamic>?;
  print('begin error:               "${begun.error}"');
  print('secret to install:         ${clientData?['setupCode']}');
  print('provisioning URI:          ${clientData?['otpauthUri']}');

  // The copy the server will confirm against is not in those claims. It rides
  // in the encrypted section, so the client cannot substitute a secret it
  // already knows the code for.
  final begunToken = TomClientJwtToken(begun.authorizationToken);
  print(
    'offer data public:         '
    '${publicClaims?.containsKey(Tom2FAEnrolmentClaims.offerData)}',
  );
  print(
    'offer data encrypted:      '
    '${begunToken.secretData?.containsKey(Tom2FAEnrolmentClaims.offerData)}',
  );

  // Example 4: a wrong confirmation is retryable, and it says so by key. Note
  // that the token to present next is the one *this* answer carried -- the
  // attempt has been counted onto it.
  final mistyped = await server.completeTwoFactorEnrolment(
    _message(password: '000000'),
    enrolmentToken: begunToken,
  );
  print('mistyped error:            ${mistyped.error}');
  print('retry token issued:        ${mistyped.authorizationToken.isNotEmpty}');

  // Example 5: the right confirmation both records the factor and logs the user
  // in. There is no fourth call and no challenge afterwards: the user just
  // demonstrated possession, and asking again would be asking twice.
  final done = await server.completeTwoFactorEnrolment(
    _message(password: _AuthenticatorApp.confirmation),
    enrolmentToken: TomClientJwtToken(mistyped.authorizationToken),
  );
  final session = TomBearerAuthentication.convertTokenPayloadToPrincipal(
    TomClientJwtToken(done.authorizationToken),
  );
  // Captured here rather than read at the end: `_configure` below installs a
  // fresh adaptor, so these counts belong to the round trip just run.
  final offersBegun = _app.begun;
  final confirmationsChecked = _app.confirmed;
  final challengesIssued = _app.issued;
  print('complete error:            "${done.error}"');
  print(
    'still owes a factor:       '
    '${done.requires2FA || done.requires2FAEnrolment}',
  );
  print('session authenticated:     ${session.authenticated}');
  print('confirmations checked:     $confirmationsChecked');
  print('challenges issued:         $challengesIssued');

  // And it was recorded -- as the primary factor, because it is the first, so
  // the next login has something to challenge without anyone nominating it.
  final stored = await _store.enrolmentsFor(_contextOfAlice());
  print('factors on file:           ${stored.length}');
  print(
    'primary factor:            '
    '${stored.single.type} (isPrimary: ${stored.single.isPrimary})',
  );

  // Example 6: the next login is an ordinary two-pass one. Nothing was
  // reconfigured between here and Example 1 -- the store answering differently
  // is the whole difference.
  final second = await server.authenticatePass1(_message());
  print('next login enrolment:      ${second.requires2FAEnrolment}');
  print('next login challenge:      ${second.requires2FA}');
  print('next login mechanism:      ${second.twoFactorType}');

  // Example 7: a required offer cannot be declined. The skip pass answers with
  // a key and no token, which is the difference between "not now" and "no".
  _configure(Tom2FARequirement.required);
  final mustEnrol = await server.authenticatePass1(_message());
  final refused = await server.skipTwoFactorEnrolment(
    _message(),
    enrolmentToken: TomClientJwtToken(mustEnrol.authorizationToken),
  );
  print('declining a must:          ${refused.error}');
  print('token to continue with:    "${refused.authorizationToken}"');

  // Example 8: an optional policy offers the same enrolment and lets it go. The
  // user is logged in, and nothing is recorded -- so the offer comes back next
  // time, which is what makes "optional" an invitation rather than a one-shot.
  _configure(Tom2FARequirement.optional);
  final invitation = await server.authenticatePass1(_message());
  final declined = await server.skipTwoFactorEnrolment(
    _message(),
    enrolmentToken: TomClientJwtToken(invitation.authorizationToken),
  );
  final afterDeclining = TomBearerAuthentication.convertTokenPayloadToPrincipal(
    TomClientJwtToken(declined.authorizationToken),
  );
  print(
    'optional declinable:       '
    '${invitation.twoFactorEnrolmentSkippable}',
  );
  print('declined error:            "${declined.error}"');
  print('declined authenticated:    ${afterDeclining.authenticated}');
  print(
    'factors on file:           '
    '${(await _store.enrolmentsFor(_contextOfAlice())).length}',
  );

  // What every step above had to have held to, stated through `check` rather
  // than `assert` -- `dart run` leaves assertions disabled, so an asserting
  // example verifies nothing under its own documented command. See
  // `../_support/check.dart`.
  check(
    offer.error.isEmpty,
    'a required policy meeting a user with nothing enrolled is not a failure',
  );
  check(
    offer.requires2FAEnrolment && !offer.requires2FA,
    'pass 1 answers with an offer to enrol, and never also with a challenge',
  );
  check(
    offer.availableTwoFactorMethods.single.type == _AuthenticatorApp.type,
    'the offer lists only mechanisms a user can complete here, so sms -- '
    'permitted and registered, but not enrollable from a login -- is left out',
  );
  check(
    !offer.twoFactorEnrolmentSkippable,
    'an offer made under a required policy is not declinable',
  );
  check(
    method.displayNameKey == 'two_factor.app.name',
    'a mechanism advertises resource keys for the chooser to translate',
  );
  check(
    !beforeEnrolling.authenticated,
    'the offer token names the identity but authenticates nobody yet',
  );
  check(
    begun.error.isEmpty,
    'the credential slot carrying a mechanism key starts that enrolment',
  );
  check(
    offersBegun == 1,
    'the chosen mechanism is asked for setup material exactly once',
  );
  check(
    clientData?['setupCode'] == _AuthenticatorApp.secret,
    'the material the user installs is public, so the client can render it',
  );
  check(
    !publicClaims!.containsKey(Tom2FAEnrolmentClaims.offerData),
    'the copy the server confirms against is not readable by the client',
  );
  check(
    begunToken.secretData!.containsKey(Tom2FAEnrolmentClaims.offerData),
    'that copy rides encrypted instead, so the secret cannot be substituted',
  );
  check(
    mistyped.error == 'login.error.2fa.enrolment-invalid-code',
    'a wrong confirmation is reported by resource key, not by prose',
  );
  check(
    mistyped.authorizationToken.isNotEmpty,
    'a wrong confirmation is retryable, on the token that counted the attempt',
  );
  check(done.error.isEmpty, 'the right confirmation completes the enrolment');
  check(
    !done.requires2FA && !done.requires2FAEnrolment,
    'completing the round trip leaves nothing further owed',
  );
  check(
    session.authenticated,
    'confirming possession issues the session, without a fourth call',
  );
  check(
    challengesIssued == 0,
    'enrolling is not followed by a challenge, which would ask twice',
  );
  check(
    stored.single.type == _AuthenticatorApp.type,
    'the confirmed factor is recorded against the user',
  );
  check(
    stored.single.isPrimary,
    'the first factor on file becomes primary without anyone nominating it',
  );
  check(
    !second.requires2FAEnrolment && second.requires2FA,
    'with a factor on file the next login is an ordinary two-pass one',
  );
  check(
    second.twoFactorType == _AuthenticatorApp.type,
    'and it challenges the factor that was just enrolled',
  );
  check(
    refused.error == 'login.error.2fa.enrolment-required',
    'declining a required enrolment is refused, by key',
  );
  check(
    refused.authorizationToken.isEmpty,
    'a refusal hands back no token, so there is no way to continue',
  );
  check(
    invitation.twoFactorEnrolmentSkippable,
    'an optional policy makes the same offer declinable',
  );
  check(declined.error.isEmpty, 'declining an invitation is a normal outcome');
  check(afterDeclining.authenticated, 'and the user is logged in all the same');
  check(
    (await _store.enrolmentsFor(_contextOfAlice())).isEmpty,
    'nothing is recorded when an offer is declined, so it returns next login',
  );
}

void main() => run();
