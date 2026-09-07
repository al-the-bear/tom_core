/// Demonstrates the **two-pass login** — everything that happens between "the
/// password was right" and "you are logged in", for an account that owes a
/// second factor.
///
/// The shape to hold on to is that pass 1 does *not* fail. It succeeds, and
/// returns a [TomAuthenticationResult] carrying an **interim** token: one that
/// identifies the user well enough for the next call in the flow and grants no
/// session at all, because its claims still say a factor is owed. The client's
/// job is to read those claims, render the right panel, and post an answer.
///
/// Two different things can be owed, and they are answered by different calls,
/// so they are reported by different flags and read back by different types:
///
/// ```text
/// requires2FA          → Tom2FAChallenge        "use the factor you have"
/// requires2FAEnrolment → Tom2FAPendingEnrolment "set one up first"
/// ```
///
/// They are never both true.
///
/// Key concepts covered:
/// - [TomAuthenticationMessage] and [TomAuthenticationResult] as the two ends of
///   each pass, and why the 2FA state is two flags rather than one
/// - [Tom2FAChallenge] as the *client's* read of an interim token, and
///   [Tom2FAClaims] as the claim names both tiers spell the same way
/// - The attempt budget — [Tom2FAChallenge.withConsumedAttempt],
///   [Tom2FAChallenge.attemptsRemaining], [Tom2FAChallenge.isExhausted] — and
///   that consuming an attempt produces a *new* challenge rather than mutating
///   one
/// - [TomTotp] as the one derivation the authenticator and the verifier must
///   agree on, digit for digit
/// - The fail-closed reading in [Tom2FAChallenge.fromClaims]: an unreadable
///   budget arrives as `0`, not as the constructor's `3`
/// - [Tom2FAPendingEnrolment]'s two stops — choosing and confirming —
///   distinguished by [Tom2FAPendingEnrolment.hasOffer], and why the choosing
///   stop legitimately has no deadline
/// - [Tom2FAMethodDescriptor.scoped] carrying resource *keys*, never display
///   text, so the tier that renders resolves them against the user's locale
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/security/09_two_factor_login_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// =============================================================================
// Two-Factor Login Example
// =============================================================================

/// A fixed instant, so the derived codes below are the same on every run.
final DateTime _now = DateTime.utc(2026, 3, 1, 12, 0, 0);

/// The secret the server generated at enrolment time and the authenticator
/// holds. Fixed bytes rather than a random draw, for the same reason.
final String _secret = TomTotp.encodeBase32(
  List<int>.generate(20, (i) => (i * 7 + 13) & 0xff),
);

void run() {
  print('=== 09: The Two-Pass Login ===\n');

  // ---------------------------------------------------------------------------
  // Example 1: pass 1 — the credentials are accepted and the login is not over.
  //   Note what the result is *not*: it carries no error. Reading `error` alone
  //   and navigating home on empty is the classic way to skip the second factor
  //   entirely.
  // ---------------------------------------------------------------------------
  print('1. Pass 1 — correct password, unfinished login:');

  final login = TomAuthenticationMessage()
    ..userName = 'jo'
    ..password = 'correct-horse'
    ..application = 'reports'
    ..client = 'reports-web'
    ..clientLanguage = 'de'
    ..clientCountry = 'DE';

  final pass1 = TomAuthenticationResult()
    ..authenticationToken = '<interim>'
    ..requires2FA = true
    ..twoFactorType = 'totp';

  print('   - message.userName        : ${login.userName}');
  print(
    '   - result.error            : "${pass1.error}"  ← empty, yet not done',
  );
  print('   - result.requires2FA      : ${pass1.requires2FA}');
  print('   - result.twoFactorType    : ${pass1.twoFactorType}');
  print('   - result.authorizationToken: "${pass1.authorizationToken}"');
  print('   → an interim token: identifies the user, grants nothing\n');

  // ---------------------------------------------------------------------------
  // Example 2: the challenge rides in the token's public claims.
  //   The server builds it, projects it onto claims, signs them; the client
  //   reads the same claims back. Both sides name the claims through
  //   Tom2FAClaims, so a rename moves both at once.
  // ---------------------------------------------------------------------------
  print('2. The challenge crosses the wire as claims:');

  final issued = Tom2FAChallenge(
    type: 'totp',
    hint: 'Authenticator app',
    expiresAt: _now.add(const Duration(minutes: 5)),
  );

  final claims = issued.toClaims();
  final received = Tom2FAChallenge.fromClaims(claims)!;

  print('   - issued                          : $issued');
  print(
    '   - claims[${Tom2FAClaims.requires2FA}]                : '
    '"${claims[Tom2FAClaims.requires2FA]}"',
  );
  print(
    '   - claims[${Tom2FAClaims.attemptsAllowed}] : '
    '${claims[Tom2FAClaims.attemptsAllowed]}',
  );
  print('   - received.type                   : ${received.type}');
  print('   - received.attemptsRemaining      : ${received.attemptsRemaining}');
  print('   → requires2FA is the string "true", not a JSON boolean\n');

  // ---------------------------------------------------------------------------
  // Example 3: a wrong code costs an attempt.
  //   withConsumedAttempt returns a *new* challenge. The old one is still valid
  //   and still says attempt 0 — so a server that forgets to re-issue the token
  //   from the returned value has handed out an unlimited guess budget.
  // ---------------------------------------------------------------------------
  print('3. A wrong code consumes one attempt:');

  // A code that was correct five minutes ago. Wrong now — which is exactly the
  // failure mode a user with a stale screen hits.
  final staleCode = TomTotp.codeFor(
    _secret,
    at: _now.subtract(const Duration(minutes: 5)),
  );
  final expectedCode = TomTotp.codeFor(_secret, at: _now);

  final afterMiss = received.withConsumedAttempt();

  print(
    '   - submitted           : $staleCode  (a code from five minutes ago)',
  );
  print('   - server expects      : $expectedCode');
  print(
    '   - before: attempt ${received.attempt}, remaining '
    '${received.attemptsRemaining}',
  );
  print(
    '   - after : attempt ${afterMiss.attempt}, remaining '
    '${afterMiss.attemptsRemaining}',
  );
  print('   → the original object is unchanged; re-issue from the new one\n');

  // ---------------------------------------------------------------------------
  // Example 4: burning the budget.
  //   isExhausted is what the server checks before it even looks at the code.
  // ---------------------------------------------------------------------------
  print('4. Spending the rest of the budget:');

  final afterSecondMiss = afterMiss.withConsumedAttempt();
  final afterThirdMiss = afterSecondMiss.withConsumedAttempt();

  print(
    '   - after 2 misses: remaining ${afterSecondMiss.attemptsRemaining}, '
    'exhausted ${afterSecondMiss.isExhausted}',
  );
  print(
    '   - after 3 misses: remaining ${afterThirdMiss.attemptsRemaining}, '
    'exhausted ${afterThirdMiss.isExhausted}',
  );
  print(
    '   - once more     : remaining '
    '${afterThirdMiss.withConsumedAttempt().attemptsRemaining}  (never < 0)',
  );
  print('   → an exhausted challenge is refused before the code is read\n');

  // ---------------------------------------------------------------------------
  // Example 5: the code itself — one derivation, two tiers.
  //   The authenticator calls codeFor; the server decodes and counts by hand
  //   because it verifies against a skew window. Both must land on the same
  //   digits, which is why the primitive lives in the kernel and not in either.
  // ---------------------------------------------------------------------------
  print('5. The right code, derived twice:');

  final authenticatorCode = TomTotp.codeFor(_secret, at: _now);
  final serverCode = TomTotp.generateCode(
    TomTotp.decodeBase32(_secret),
    TomTotp.counterFor(at: _now),
  );
  final previousWindowCode = TomTotp.codeFor(
    _secret,
    at: _now.subtract(TomTotp.defaultPeriod),
  );

  print('   - secret (base32)     : $_secret');
  print('   - authenticator says  : $authenticatorCode');
  print('   - server derives      : $serverCode');
  print(
    '   - one window earlier  : $previousWindowCode  '
    '(accepted only if policy allows skew)',
  );
  print(
    '   - an undecodable secret yields: '
    '"${TomTotp.codeFor('not base32!')}"',
  );
  print('   → the codes match, and a bad secret is a non-match, not a throw\n');

  // ---------------------------------------------------------------------------
  // Example 6: two ways a challenge stops being answerable.
  //   The second is the one worth knowing: fromClaims falls attemptsAllowed
  //   back to 0, *not* to the constructor's 3. A malformed token must not be
  //   able to mint guesses, so an unreadable budget arrives already exhausted.
  // ---------------------------------------------------------------------------
  print('6. Expiry, and the fail-closed budget:');

  final lapsed = Tom2FAChallenge(
    type: 'totp',
    expiresAt: _now.subtract(const Duration(seconds: 1)),
  );

  final tamperedClaims = Map<String, dynamic>.from(claims)
    ..[Tom2FAClaims.attemptsAllowed] = 'lots';
  final fromTampered = Tom2FAChallenge.fromClaims(tamperedClaims)!;

  final notAChallenge = Tom2FAChallenge.fromClaims({
    Tom2FAClaims.requires2FA: 'true',
    Tom2FAClaims.type: '',
    Tom2FAClaims.expiresAt: _now.toIso8601String(),
  });

  print('   - lapsed.isExpired(_now)            : ${lapsed.isExpired(_now)}');
  print(
    '   - constructor default attemptsAllowed: '
    '${issued.attemptsAllowed}',
  );
  print(
    '   - unreadable budget → attemptsAllowed: '
    '${fromTampered.attemptsAllowed}, exhausted ${fromTampered.isExhausted}',
  );
  print('   - a payload naming no mechanism      : $notAChallenge');
  print('   → back to pass 1 is recoverable; free guesses are not\n');

  // ---------------------------------------------------------------------------
  // Example 7: enrolment, stop one — choosing.
  //   A different user, with no factor at all. The offer is a list of *keys*;
  //   nothing here is displayable text, because the tier that renders knows the
  //   locale and this one does not.
  // ---------------------------------------------------------------------------
  print('7. Enrolment, stop one — choosing a mechanism:');

  final enrolmentPass1 = TomAuthenticationResult()
    ..authenticationToken = '<interim>'
    ..requires2FAEnrolment = true
    ..twoFactorEnrolmentSkippable = true
    ..availableTwoFactorMethods = [
      Tom2FAMethodDescriptor.scoped('totp'),
      Tom2FAMethodDescriptor.scoped('email'),
    ];

  // The server's projection of the same state onto the interim token's claims.
  final choosingClaims = <String, dynamic>{
    Tom2FAEnrolmentClaims.pendingEnrolment: 'true',
    Tom2FAEnrolmentClaims.offeredTypes: ['totp', 'email'],
    Tom2FAEnrolmentClaims.skippable: true,
    Tom2FAEnrolmentClaims.skipSpendsGrace: true,
  };
  final choosing = Tom2FAPendingEnrolment.fromClaims(choosingClaims)!;

  final totpDescriptor = enrolmentPass1.availableTwoFactorMethods.first;

  print(
    '   - requires2FA / requires2FAEnrolment : '
    '${enrolmentPass1.requires2FA} / ${enrolmentPass1.requires2FAEnrolment}',
  );
  print('   - offered descriptor                 : $totpDescriptor');
  print(
    '   -   displayNameKey                   : '
    '${totpDescriptor.displayNameKey}',
  );
  print('   -   iconKey                          : ${totpDescriptor.iconKey}');
  print('   - choosing.hasOffer                  : ${choosing.hasOffer}');
  print('   - choosing.expiresAt                 : ${choosing.expiresAt}');
  print(
    '   - choosing.isExpired(_now)           : '
    '${choosing.isExpired(_now)}',
  );
  print(
    '   - choosing.skippable / spendsGrace   : '
    '${choosing.skippable} / ${choosing.skipSpendsGrace}',
  );
  print('   → nothing has been generated yet, so nothing can go stale\n');

  // ---------------------------------------------------------------------------
  // Example 8: enrolment, stop two — confirming.
  //   The user picked TOTP; the server generated a secret and put the public
  //   half in clientData. Now there *is* something that can go stale, so now
  //   there is a deadline — and hasOffer flips.
  // ---------------------------------------------------------------------------
  print('8. Enrolment, stop two — confirming the chosen mechanism:');

  final confirmingClaims = <String, dynamic>{
    Tom2FAEnrolmentClaims.pendingEnrolment: 'true',
    Tom2FAEnrolmentClaims.type: 'totp',
    Tom2FAEnrolmentClaims.hint: 'Authenticator app',
    Tom2FAEnrolmentClaims.attemptsAllowed: 3,
    Tom2FAEnrolmentClaims.expiresAt: _now
        .add(const Duration(minutes: 10))
        .toIso8601String(),
    Tom2FAEnrolmentClaims.clientData: {
      'secret': _secret,
      'uri': 'otpauth://totp/Reports:jo?secret=$_secret&issuer=Reports',
    },
    Tom2FAEnrolmentClaims.offeredTypes: ['totp', 'email'],
    // The wire may present these either way; both readings are accepted.
    Tom2FAEnrolmentClaims.skippable: 'true',
  };
  final confirming = Tom2FAPendingEnrolment.fromClaims(confirmingClaims)!;

  // The user scans the URI and types back what their authenticator shows.
  final confirmationCode = TomTotp.codeFor(
    confirming.clientData['secret']! as String,
    at: _now,
  );

  print('   - confirming.hasOffer      : ${confirming.hasOffer}');
  print(
    '   - confirming.type / hint   : '
    '${confirming.type} / ${confirming.hint}',
  );
  print('   - confirming.expiresAt     : ${confirming.expiresAt}');
  print('   - clientData.uri           : ${confirming.clientData['uri']}');
  print('   - skippable (from "true")  : ${confirming.skippable}');
  print('   - typed-back code          : $confirmationCode');
  print('   → the same derivation as a login, one step earlier\n');

  // ---------------------------------------------------------------------------
  // Example 9: pass 2 — the code is right and the session finally exists.
  //   The flags are back to false and both tokens are present. That, not an
  //   empty error, is what "logged in" looks like.
  // ---------------------------------------------------------------------------
  print('9. Pass 2 — the real token pair:');

  final pass2 = TomAuthenticationResult()
    ..authenticationToken = '<authentication>'
    ..authorizationToken = '<authorization>';

  print('   - error                : "${pass2.error}"');
  print('   - requires2FA          : ${pass2.requires2FA}');
  print('   - requires2FAEnrolment : ${pass2.requires2FAEnrolment}');
  print('   - authorizationToken   : ${pass2.authorizationToken}');
  print('   → and no interim claim remains on the token\n');

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: pass 1 succeeds without finishing. The message defaults matter
  // as much as what was set — a client that fills nothing still sends a valid
  // guest-shaped message.
  assert(login.userName == 'jo');
  assert(TomAuthenticationMessage().userName == TomUser.guestUsername);
  assert(TomAuthenticationMessage().clientTimezone == 'utc');
  assert(pass1.error.isEmpty);
  assert(pass1.requires2FA);
  assert(!pass1.requires2FAEnrolment);
  assert(pass1.authorizationToken.isEmpty);

  // Example 2: the round trip preserves every claim the client needs.
  assert(claims[Tom2FAClaims.requires2FA] == 'true');
  assert(claims[Tom2FAClaims.type] == 'totp');
  assert(claims[Tom2FAClaims.attemptsAllowed] == 3);
  assert(received.type == issued.type);
  assert(received.hint == 'Authenticator app');
  assert(received.expiresAt == issued.expiresAt);
  assert(received.expiresAt.isUtc);
  assert(received.attemptsRemaining == 3);
  assert(!received.isExpired(_now));

  // Example 3: consuming an attempt is non-destructive.
  assert(staleCode != expectedCode);
  assert(received.attempt == 0);
  assert(afterMiss.attempt == 1);
  assert(afterMiss.attemptsRemaining == 2);
  assert(afterMiss.type == received.type);
  assert(afterMiss.expiresAt == received.expiresAt);

  // Example 4: the budget floors at zero.
  assert(!afterSecondMiss.isExhausted);
  assert(afterThirdMiss.isExhausted);
  assert(afterThirdMiss.attemptsRemaining == 0);
  assert(afterThirdMiss.withConsumedAttempt().attemptsRemaining == 0);

  // Example 5: both tiers derive the same digits, and a bad secret is a
  // non-match rather than an exception.
  assert(authenticatorCode == serverCode);
  assert(authenticatorCode.length == TomTotp.defaultDigits);
  assert(int.tryParse(authenticatorCode) != null);
  assert(previousWindowCode != authenticatorCode);
  assert(TomTotp.codeFor('not base32!').isEmpty);
  assert(TomTotp.decodeBase32(_secret).length == 20);
  assert(TomTotp.encodeBase32(TomTotp.decodeBase32(_secret)) == _secret);
  // The counter is UTC seconds over the step — the one number the two tiers
  // most easily disagree about.
  assert(
    TomTotp.counterFor(at: _now) ==
        _now.millisecondsSinceEpoch ~/ 1000 ~/ TomTotp.defaultPeriod.inSeconds,
  );
  assert(
    TomTotp.counterFor(at: _now, period: const Duration(seconds: 60)) ==
        TomTotp.counterFor(at: _now) ~/ 2,
  );

  // Example 6: expiry, and the fail-closed budget.
  assert(lapsed.isExpired(_now));
  assert(issued.attemptsAllowed == 3);
  assert(fromTampered.attemptsAllowed == 0);
  assert(fromTampered.isExhausted);
  assert(notAChallenge == null);
  assert(Tom2FAChallenge.fromClaims(null) == null);
  assert(Tom2FAChallenge.fromClaims(const {}) == null);

  // Example 7: the choosing stop — an offer, no mechanism, no deadline, and
  // keys rather than text.
  assert(enrolmentPass1.requires2FAEnrolment);
  assert(!enrolmentPass1.requires2FA);
  assert(enrolmentPass1.twoFactorEnrolmentSkippable);
  assert(totpDescriptor.type == 'totp');
  assert(totpDescriptor.displayNameKey == 'two_factor.totp.name');
  assert(totpDescriptor.descriptionKey == 'two_factor.totp.description');
  assert(totpDescriptor.iconKey == 'two_factor.totp.icon');
  assert(
    totpDescriptor.displayNameKey.startsWith(
      '${Tom2FAMethodDescriptor.resourceScope}.',
    ),
  );
  assert(!choosing.hasOffer);
  assert(choosing.type.isEmpty);
  assert(choosing.offeredTypes.join(',') == 'totp,email');
  assert(choosing.expiresAt == null);
  assert(!choosing.isExpired(_now));
  assert(choosing.skippable);
  assert(choosing.skipSpendsGrace);

  // Example 8: the confirming stop — a mechanism, a deadline, and material.
  assert(confirming.hasOffer);
  assert(confirming.type == 'totp');
  assert(confirming.hint == 'Authenticator app');
  assert(confirming.expiresAt != null);
  assert(confirming.expiresAt!.isUtc);
  assert(!confirming.isExpired(_now));
  assert(confirming.attemptsRemaining == 3);
  assert(confirming.clientData['secret'] == _secret);
  // A string 'true' reads the same as a JSON true — mixed framework versions
  // must not make the skip affordance vanish.
  assert(confirming.skippable);
  assert(!confirming.skipSpendsGrace);
  assert(confirmationCode == authenticatorCode);
  // Nothing renderable, or a begun enrolment with no readable deadline.
  assert(Tom2FAPendingEnrolment.fromClaims(null) == null);
  assert(
    Tom2FAPendingEnrolment.fromClaims({
          Tom2FAEnrolmentClaims.pendingEnrolment: 'true',
        }) ==
        null,
  );
  assert(
    Tom2FAPendingEnrolment.fromClaims({
          Tom2FAEnrolmentClaims.pendingEnrolment: 'true',
          Tom2FAEnrolmentClaims.type: 'totp',
        }) ==
        null,
  );

  // Example 9: a finished login carries both tokens and neither flag.
  assert(pass2.error.isEmpty);
  assert(!pass2.requires2FA);
  assert(!pass2.requires2FAEnrolment);
  assert(pass2.authenticationToken.isNotEmpty);
  assert(pass2.authorizationToken.isNotEmpty);
  assert(pass2.availableTwoFactorMethods.isEmpty);

  print('Two-factor login example complete.\n');
}

/// Standalone entry point.
void main() {
  prepareSampleProcess();
  run();
}
