/// Executable example for the **two-pass login** of the `tom_core_server`
/// authentication module: the flow that runs when a principal still owes a
/// second factor.
///
/// A one-pass login answers with a session. A login that owes a factor answers
/// instead with an *interim* token that carries the challenge, and the client
/// comes back a second time with the code. The two calls are
/// [TomAuthenticationServer.authenticatePass1] and
/// [TomAuthenticationServer.authenticatePass2], and the token that travels
/// between them is the only state the server keeps — there is no pending-login
/// table, which is why this example needs neither a database nor a port.
///
/// The one seam a deployment supplies is the mechanism itself: a
/// [Tom2FAService] registered under a key. The [_SmsAdaptor] below stands in for
/// one, accepting a constant code so the example does not need the clock that
/// TOTP would. Everything else — the policy decision, the challenge minting, the
/// attempt accounting, the token issuance — is the production path.
///
/// Read it alongside `two_factor_enrolment_example.dart`, which covers the
/// three-pass round trip that *sets up* a factor, and
/// `authentication_example.dart`, which covers the service contract itself.
///
/// Two framework notices are expected in the output and are not faults. The
/// interim token is genuinely signed and encrypted, and this program configures
/// no keys, so `TomJwtConfiguration` says so on every mint — a deployment
/// silences it by configuring its own. The registry likewise reports that it
/// found no generated reflection to scan for annotated adaptors, which is
/// correct here: [_SmsAdaptor] is registered by hand.
///
/// Run with `dart run example/authentication/two_factor_login_example.dart`.
/// Every step checks its own result and the run fails when one does not hold,
/// so a green run is a verification and not just a transcript. The same
/// behaviour is covered by `test/two_factor_test.dart`.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

/// The mechanism key [_SmsAdaptor] is registered under.
const String _mechanism = 'sms';

/// Builds the wire message the server consumes.
///
/// [password] is the message's single credential slot, and it means different
/// things on the two passes: the account password on pass 1, the second-factor
/// code on pass 2. That reuse is why adding 2FA needed no new wire field.
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

/// A deployment's own password check, standing in for a user directory.
///
/// It says nothing about second factors: whether one is owed is the *policy's*
/// decision, taken from the principal this returns.
class _DirectoryService implements TomAuthenticationService {
  @override
  Future<TomAuthenticationInfo> authenticateUser(
    TomAuthenticationData a,
  ) async {
    if (a.key != 's3cret') {
      throw TomLoginException(
        'error.invalid-user-or-password',
        'Invalid user or password',
        reason: TomLoginFailure.accountProblem,
      );
    }
    return TomAuthenticationInfo(
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
}

/// A second factor over a channel the example does not have: a code is
/// "delivered", and one constant answer is accepted.
///
/// The two halves of the contract are worth reading as a pair.
/// [issueChallenge] returns *two* payloads — `clientData`, which the client is
/// shown, and `verificationData`, which only the server ever sees — and
/// [verifySubmission] gets the second one back. That split is what lets a
/// stateless flow verify a code it minted a round trip earlier without a
/// server-side pending table.
class _SmsAdaptor implements Tom2FAService {
  /// The one submission this mechanism accepts.
  static const String expected = '424242';

  /// How many codes it has issued, and how many it has checked.
  int issued = 0;
  int verified = 0;

  @override
  Tom2FAMethodDescriptor get descriptor =>
      Tom2FAMethodDescriptor.scoped(_mechanism);

  @override
  Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context) async {
    issued++;
    return const Tom2FAChallengeSpec(
      // Enough for the user to recognise the phone, not enough to identify it.
      hint: '***-**-4711',
      clientData: {'shape': 'digits-6'},
      verificationData: {'nonce': 'n-1'},
      attemptsAllowed: 2,
      validity: Duration(minutes: 5),
    );
  }

  @override
  Future<bool> verifySubmission(
    Tom2FAContext context,
    Tom2FASubmission submission,
  ) async {
    verified++;
    return submission.submitted == expected;
  }
}

/// Installs the mechanism and the policy that demands it of administrators.
///
/// A policy is a bean rather than a setting because it is a *decision*, and
/// deployments take it differently: [TomRole2FAPolicy] answers from the
/// principal's roles, but any [Tom2FAPolicy] will do.
void _configure({required Tom2FARequirement forAdmins}) {
  _adaptor = _SmsAdaptor();
  Tom2FARegistry.reset();
  Tom2FARegistry.register(_mechanism, _adaptor);
  TomBean.resetBeanContext();
  TomBean.withType<Tom2FAPolicy>(
    TomRole2FAPolicy(
      requirementByRole: {'admin': forAdmins},
      defaultRequirement: Tom2FARequirement.disabled,
      mechanisms: const [_mechanism],
    ),
  );
  TomAuthenticationServer.globalSettingUserAuthenticationService =
      _DirectoryService();
}

/// The mechanism the current configuration has installed.
///
/// Rebuilt by every [_configure] call rather than shared, so that the issue and
/// verify counts printed below belong to the run being described and cannot be
/// read as carry-over from the previous one.
late _SmsAdaptor _adaptor;

Future<void> run() async {
  final server = TomAuthenticationServer();
  _configure(forAdmins: Tom2FARequirement.required);

  // Example 1: pass 1 answers with a challenge instead of a session. The
  // password was right -- a wrong one would have thrown out of the directory
  // service -- so what comes back is not a refusal but an unfinished login.
  final pass1 = await server.authenticatePass1(_message());
  print('pass 1 error:              "${pass1.error}"');
  print('pass 1 requires2FA:        ${pass1.requires2FA}');
  print('pass 1 mechanism:          ${pass1.twoFactorType}');
  print('codes issued:              ${_adaptor.issued}');

  // Example 2: what the client is shown, and what it is not. The challenge is
  // readable from the interim token's public claims -- the client has to render
  // the hint and know how many tries are left -- while the adaptor's own
  // verification payload sits in the encrypted section, so a client cannot
  // rewrite the thing it is about to be tested on.
  final interim = TomClientJwtToken(pass1.authorizationToken);
  final challenge = Tom2FAChallenge.fromClaims(interim.payload)!;
  print('challenge hint:            ${challenge.hint}');
  print('challenge shape:           ${challenge.clientData['shape']}');
  print(
    'attempts used/allowed:     '
    '${challenge.attempt}/${challenge.attemptsAllowed}',
  );
  final publicClaims = TomClientJwtToken(
    pass1.authorizationToken,
    decrypt: false,
  ).payload;
  print(
    'verification data public:  '
    '${publicClaims?.containsKey(Tom2FAClaims.verificationData)}',
  );

  // Example 3: the interim token is not a session. It carries the real identity
  // and the real roles -- pass 2 needs them, and re-running the password check
  // would be asking the user to log in twice -- but the principal derived from
  // it is not authenticated, which is the single flag every access check in the
  // framework consults.
  final interimPrincipal =
      TomBearerAuthentication.convertTokenPayloadToPrincipal(interim);
  print('interim username:          ${interimPrincipal.username}');
  print('interim roles:             ${interimPrincipal.aci.roles}');
  print('interim authenticated:     ${interimPrincipal.authenticated}');

  // Example 4: a wrong code is a retry, not a rejection. The result carries an
  // error *key* -- branching on the key is how a client tells "try again" from
  // "start over" -- and a fresh token with the attempt counted, so the next
  // submission must present that one rather than the original.
  final wrong = await server.authenticatePass2(
    _message(password: '000000'),
    challengeToken: interim,
  );
  print('wrong code error:          ${wrong.error}');
  print('retry token issued:        ${wrong.authorizationToken.isNotEmpty}');
  final afterOneMiss = TomClientJwtToken(wrong.authorizationToken);
  print(
    'attempts used now:         '
    '${Tom2FAChallenge.fromClaims(afterOneMiss.payload)!.attempt}',
  );

  // Example 5: the right code completes the login. What comes back is an
  // ordinary session -- the same token a user who owed no factor would have
  // been handed on pass 1 -- and it carries no trace of the challenge: no
  // mechanism, no verification payload, nothing a later request could replay.
  final pass2 = await server.authenticatePass2(
    _message(password: _SmsAdaptor.expected),
    challengeToken: afterOneMiss,
  );
  final session = TomClientJwtToken(pass2.authorizationToken);
  final principal = TomBearerAuthentication.convertTokenPayloadToPrincipal(
    session,
  );
  print('pass 2 error:              "${pass2.error}"');
  print('pass 2 requires2FA:        ${pass2.requires2FA}');
  print('session authenticated:     ${principal.authenticated}');
  print('session roles survive:     ${principal.aci.roles}');
  print(
    'challenge left in token:   '
    '${Tom2FAChallenge.fromClaims(session.payload) != null}',
  );
  print('codes checked:             ${_adaptor.verified}');

  // Example 6: the attempts run out. Two allowed, two missed -- and the answer
  // changes key, from the retryable `invalid-code` to `attempts-exhausted`,
  // with no token to come back with. The client must start the login again,
  // which is what stops a six-digit code from being brute-forced.
  _configure(forAdmins: Tom2FARequirement.required);
  var token = TomClientJwtToken(
    (await server.authenticatePass1(_message())).authorizationToken,
  );
  late TomAuthenticationResult exhausted;
  for (var attempt = 0; attempt < 2; attempt++) {
    exhausted = await server.authenticatePass2(
      _message(password: '000000'),
      challengeToken: token,
    );
    if (exhausted.authorizationToken.isNotEmpty) {
      token = TomClientJwtToken(exhausted.authorizationToken);
    }
  }
  print('exhausted error:           ${exhausted.error}');
  print(
    'exhausted token:           '
    '"${exhausted.authorizationToken}"',
  );

  // Example 7: the policy is what decides, not the mechanism being registered.
  // The same user, the same adaptor, the same password -- but a policy that
  // asks nothing of administrators logs them in on the first pass, with the
  // adaptor never consulted.
  _configure(forAdmins: Tom2FARequirement.disabled);
  final onePass = await server.authenticatePass1(_message());
  final direct = TomBearerAuthentication.convertTokenPayloadToPrincipal(
    TomClientJwtToken(onePass.authorizationToken),
  );
  print('policy off, requires2FA:   ${onePass.requires2FA}');
  print('policy off, authenticated: ${direct.authenticated}');
  print('policy off, codes issued:  ${_adaptor.issued}');

  // Checks
  check(
    pass1.error.isEmpty,
    'a login that still owes a factor is unfinished, not refused',
  );
  check(
    pass1.requires2FA,
    'the policy demands a second factor of an administrator',
  );
  check(
    pass1.twoFactorType == _mechanism,
    'the answer names the mechanism the client has to satisfy',
  );
  check(
    challenge.hint == '***-**-4711',
    'the hint shows enough to recognise the phone and not enough to '
    'identify it',
  );
  check(
    challenge.attempt == 0 && challenge.attemptsAllowed == 2,
    'a freshly minted challenge has both of its tries left',
  );
  check(
    !publicClaims!.containsKey(Tom2FAClaims.verificationData),
    'the verification payload stays in the encrypted section, so a client '
    'cannot rewrite the thing it is about to be tested on',
  );
  check(
    interimPrincipal.username == 'alice',
    'the interim token carries the real identity, so the second pass need '
    'not ask for the password again',
  );
  check(
    interimPrincipal.aci.roles.contains('admin'),
    'it carries the real roles as well, which is what pass 2 concludes on',
  );
  check(
    !interimPrincipal.authenticated,
    'an interim token is not a session, whatever else it carries',
  );
  check(
    wrong.error == 'login.error.2fa.invalid-code',
    'a wrong code answers with the key that means "try again"',
  );
  check(
    wrong.authorizationToken.isNotEmpty,
    'a retry is handed a fresh token to come back with',
  );
  check(
    Tom2FAChallenge.fromClaims(afterOneMiss.payload)!.attempt == 1,
    'the miss is counted in the token the next submission must present',
  );
  check(pass2.error.isEmpty, 'the right code completes the login');
  check(
    !pass2.requires2FA,
    'nothing further is owed once the factor has been satisfied',
  );
  check(
    principal.authenticated,
    'what comes back is an ordinary session, like any one-pass login',
  );
  check(
    principal.aci.roles.contains('admin'),
    'the roles established on pass 1 survive into that session',
  );
  check(
    Tom2FAChallenge.fromClaims(session.payload) == null,
    'the session keeps no trace of the challenge for a later request to '
    'replay',
  );
  check(
    exhausted.error == 'login.error.2fa.attempts-exhausted',
    'spending the last try changes the key from "try again" to "start over"',
  );
  check(
    exhausted.authorizationToken.isEmpty,
    'no token comes back, so a six-digit code cannot be brute-forced',
  );
  check(
    !onePass.requires2FA,
    'a policy that asks nothing of administrators demands no factor',
  );
  check(
    direct.authenticated,
    'that login is finished on the first pass, session and all',
  );
  check(_adaptor.issued == 0, 'a disabled policy never reaches the mechanism');
}

void main() => run();
