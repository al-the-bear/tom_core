/// Tests for the second factors that **send a code somewhere** — the email and
/// SMS adaptors, and the shared base they are both thin skins over.
///
/// These exercise the half of the adaptor contract TOTP never reached.
/// [Tom2FAChallengeSpec.verificationData] exists so that a mechanism can
/// remember something between pass 1 and pass 2 without the client being able to
/// read or forge it; TOTP stores nothing there, re-deriving its answer from the
/// shared secret. A delivered code has nothing to re-derive from, so it is the
/// first mechanism whose correctness *depends* on that channel — and the
/// property worth asserting hardest is the negative one: the code the user was
/// sent must appear nowhere in the token they are holding while they type it.
///
/// The messaging side runs on [TomMemoryMessageTransport], which is also what
/// makes the delivery-failure rule testable: an adaptor may not hand back a
/// challenge for a code that was never sent, and `failAlways` is how that is
/// provoked without a broken relay.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

// =============================================================================
// FIXTURES
// =============================================================================

class _FakeClock {
  DateTime now;

  _FakeClock(this.now);

  DateTime call() => now;
}

/// Templates for both channels, in the shape the adaptors' default keys name.
///
/// Every user-facing word lives here rather than in the adaptors (G-RES-1), so
/// these bundles are also the specification of which parameters a deployment may
/// use: `{code}`, `{minutes}`, `{firstname}`, `{application}`.
TomLocalizedTextResources _texts() => TomLocalizedTextResources(
  defaultLocale: TomTextLocale('en'),
  bundles: {
    'en': {
      'email': {
        'two_factor_code': {
          'subject': 'Your {application} sign-in code',
          'text':
              'Hello {firstname}, your code is {code}. '
              'It expires in {minutes} minutes.',
        },
        'two_factor_enrolment': {
          'subject': 'Confirm this address',
          'text': 'Enter {code} to confirm this address for {application}.',
        },
      },
      'sms': {
        'two_factor_code': {'text': '{code} is your {application} code.'},
        'two_factor_enrolment': {
          'text': 'Enter {code} to confirm this number.',
        },
      },
    },
  },
);

/// The user a challenge is issued for. Every destination field is settable so a
/// test can take one away and watch the adaptor refuse rather than guess.
TomPrincipal _principal({
  String? email = 'alice.smith@example.com',
  String? mobile = '+41791234567',
  String? phone,
  int id = 1,
}) => TomPrincipal(
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
    id: id,
    username: 'alice',
    firstname: 'Alice',
    lastname: 'Smith',
    email: email,
    mobile: mobile,
    phone: phone,
    attributes: {},
    timezone: 'utc',
  ),
  aci: TomAccessControlInformation(roles: const ['user']),
);

Tom2FAContext _context({
  String? email = 'alice.smith@example.com',
  String? mobile = '+41791234567',
  String? phone,
  int id = 1,
}) => Tom2FAContext(
  principal: _principal(email: email, mobile: mobile, phone: phone, id: id),
  client: 'web',
  organization: 'acme',
  application: 'console',
  process: 'login',
  language: 'en',
  country: 'US',
);

/// The wire message the server consumes; [password] is the primary credential
/// on pass 1, the submitted code on pass 2, and the chosen mechanism when
/// beginning an enrolment.
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

/// An authentication service answering with a principal that has both
/// destinations on record.
class _StubAuthService implements TomAuthenticationService {
  @override
  Future<TomAuthenticationInfo> authenticateUser(
    TomAuthenticationData a,
  ) async => TomAuthenticationInfo(_principal(), TomAccessControlDefinition());
}

/// The digits out of whatever the transport was handed.
///
/// Reading the code back out of the delivered message rather than reaching into
/// the adaptor is deliberate: it is the only copy a real user ever sees, so a
/// test that verifies with it is testing the same path they walk.
String _deliveredCode(TomMemoryMessageTransport transport) {
  final body = transport.last!.textBody!.content;
  final match = RegExp(r'\d{4,}').firstMatch(body);
  expect(match, isNotNull, reason: 'the template should have rendered a code');
  return match!.group(0)!;
}

void main() {
  // ===========================================================================
  // CODE HANDLING
  // ===========================================================================

  /// The parts that are pure arithmetic, tested without a channel.
  ///
  /// Small surface, but it is the surface everything else trusts: if a sealed
  /// code could be read back, the encrypted-claims split would be decoration.
  group('TomDeliveredCode2FAService codes', () {
    test('generates a decimal code of the requested length', () {
      for (final digits in [4, 6, 8]) {
        final code = TomDeliveredCode2FAService.generateNumericCode(digits);
        expect(code, hasLength(digits));
        expect(code, matches(RegExp(r'^\d+$')));
      }
    });

    // Not a distribution test — that would need a sample size no unit test
    // should take — but enough to catch a generator that has become constant,
    // which is the failure mode that silently disables the mechanism.
    test('does not produce the same code twice in a row', () {
      final codes = {
        for (var i = 0; i < 20; i++)
          TomDeliveredCode2FAService.generateNumericCode(6),
      };
      expect(codes.length, greaterThan(1));
    });

    test('a sealed code contains a salt and a hash, and not the code', () {
      const code = '123456';
      final sealed = TomDeliveredCode2FAService.sealCode(code);

      expect(
        sealed.keys,
        containsAll([
          TomDeliveredCode2FAService.saltKey,
          TomDeliveredCode2FAService.hashKey,
        ]),
      );
      expect(
        sealed.toString(),
        isNot(contains(code)),
        reason: 'this map travels in a token the client holds',
      );
    });

    test('recognises the code it sealed and nothing else', () {
      final sealed = TomDeliveredCode2FAService.sealCode('123456');

      expect(
        TomDeliveredCode2FAService.matchesSealedCode(sealed, '123456'),
        isTrue,
      );
      expect(
        TomDeliveredCode2FAService.matchesSealedCode(sealed, '123457'),
        isFalse,
      );
      expect(TomDeliveredCode2FAService.matchesSealedCode(sealed, ''), isFalse);
    });

    // Users paste codes out of mail clients, which add spaces.
    test('tolerates surrounding whitespace in the submission', () {
      final sealed = TomDeliveredCode2FAService.sealCode('123456');
      expect(
        TomDeliveredCode2FAService.matchesSealedCode(sealed, ' 123456 '),
        isTrue,
      );
    });

    // Two salts, one code: the hashes must differ, or a table of hashes of every
    // six-digit code would be worth building once.
    test('two seals of the same code differ', () {
      final first = TomDeliveredCode2FAService.sealCode('123456');
      final second = TomDeliveredCode2FAService.sealCode('123456');
      expect(
        first[TomDeliveredCode2FAService.hashKey],
        isNot(second[TomDeliveredCode2FAService.hashKey]),
      );
    });

    // A blob that was truncated, tampered with, or never written must read as
    // "no" rather than as an exception the login flow would report as an
    // unknown error.
    test('a malformed seal refuses rather than throwing', () {
      expect(
        TomDeliveredCode2FAService.matchesSealedCode(const {}, '123456'),
        isFalse,
      );
      expect(
        TomDeliveredCode2FAService.matchesSealedCode(const {
          TomDeliveredCode2FAService.saltKey: 'not base64 !!',
          TomDeliveredCode2FAService.hashKey: 'x',
        }, '123456'),
        isFalse,
      );
    });
  });

  // ===========================================================================
  // MASKING
  // ===========================================================================

  /// What a caller who has proved nothing yet is allowed to see.
  group('destination masking', () {
    test('keeps the mail domain and reduces the local part to its ends', () {
      expect(
        TomEmailCode2FAService.maskEmailAddress('alice.smith@example.com'),
        'a***h@example.com',
      );
    });

    test('masks a short local part entirely', () {
      expect(
        TomEmailCode2FAService.maskEmailAddress('ab@example.com'),
        '***@example.com',
      );
    });

    test('masks a malformed address opaquely rather than rejecting it', () {
      expect(TomEmailCode2FAService.maskEmailAddress('not-an-address'), 'n***');
    });

    test('keeps the last four digits of a number and its punctuation', () {
      expect(
        TomSmsCode2FAService.maskPhoneNumber('+41791234567'),
        '+*******4567',
      );
      expect(
        TomSmsCode2FAService.maskPhoneNumber('079 123 45 67'),
        '*** *** 45 67',
      );
    });
  });

  // ===========================================================================
  // CHALLENGE
  // ===========================================================================

  group('delivered-code challenges', () {
    late TomMemoryMessageTransport mail;
    late TomMemoryMessageTransport sms;
    late TomMessageOutbox outbox;
    late TomEmailCode2FAService email;
    late TomSmsCode2FAService text;

    setUp(() {
      TomBean.resetBeanContext();
      final clock = _FakeClock(DateTime.utc(2026, 8, 2, 10));
      mail = TomMemoryMessageTransport(channel: TomMessageChannel.email);
      sms = TomMemoryMessageTransport(channel: TomMessageChannel.sms);
      outbox = TomMessageOutbox(
        router: TomMessageRouter([mail, sms]),
        clock: clock.call,
      );
      addTearDown(outbox.close);
      TomBean.withType(
        TomEmailService,
        TomEmailService(outbox: outbox, texts: _texts()),
      );
      TomBean.withType(
        TomSmsService,
        TomSmsService(outbox: outbox, texts: _texts()),
      );
      email = TomEmailCode2FAService();
      text = TomSmsCode2FAService();
    });

    tearDown(TomBean.resetBeanContext);

    // -----------------------------------------------------------------------
    // Email
    // -----------------------------------------------------------------------

    test(
      'mails a code to the address on record, rendered from the template',
      () async {
        await email.issueChallenge(_context());

        expect(mail.count, 1);
        final sent = mail.last!;
        expect(sent.channel, TomMessageChannel.email);
        expect(sent.recipients.single.address, 'alice.smith@example.com');
        expect(sent.subject, 'Your console sign-in code');
        expect(sent.textBody!.content, startsWith('Hello Alice, your code is'));
        expect(sent.textBody!.content, contains('expires in 10 minutes'));
      },
    );

    test('the challenge tells the client where to look, masked', () async {
      final spec = await email.issueChallenge(_context());

      expect(spec.hint, 'a***h@example.com');
      expect(
        spec.clientData[TomDeliveredCode2FAService.maskedDestinationKey],
        'a***h@example.com',
      );
      expect(spec.clientData[TomDeliveredCode2FAService.digitsKey], 6);
      expect(spec.attemptsAllowed, 3);
      expect(spec.validity, const Duration(minutes: 10));
    });

    // The property the encrypted split exists for, asserted at the adaptor
    // boundary; the flow group asserts it again on the real token.
    test('the code is nowhere in what the client is handed', () async {
      final spec = await email.issueChallenge(_context());
      final code = _deliveredCode(mail);

      expect(spec.clientData.toString(), isNot(contains(code)));
      expect(spec.hint, isNot(contains(code)));
      expect(
        spec.verificationData.toString(),
        isNot(contains(code)),
        reason: 'even the server-only blob keeps only a hash',
      );
    });

    test('the mailed code verifies and a wrong one does not', () async {
      final spec = await email.issueChallenge(_context());
      final code = _deliveredCode(mail);

      expect(await _verify(email, spec, code), isTrue);
      expect(await _verify(email, spec, '000000'), isFalse);
    });

    // Each challenge seals its own code, so an old code cannot be replayed
    // against a fresh challenge.
    test(
      'a code from an earlier challenge does not answer a later one',
      () async {
        await email.issueChallenge(_context());
        final first = _deliveredCode(mail);
        final second = await email.issueChallenge(_context());

        expect(await _verify(email, second, first), isFalse);
        expect(await _verify(email, second, _deliveredCode(mail)), isTrue);
      },
    );

    test('a user with no address is refused, and nothing is sent', () async {
      await expectLater(
        email.issueChallenge(_context(email: null)),
        throwsA(
          isA<TomLoginException>().having(
            (e) => e.key,
            'key',
            'login.error.2fa.not-enrolled',
          ),
        ),
      );
      expect(mail.count, 0);
    });

    // -----------------------------------------------------------------------
    // SMS
    // -----------------------------------------------------------------------

    test('texts a code to the mobile number on record', () async {
      final spec = await text.issueChallenge(_context());

      expect(sms.count, 1);
      expect(
        mail.count,
        0,
        reason: 'the channels do not bleed into each other',
      );
      final sent = sms.last!;
      expect(sent.channel, TomMessageChannel.sms);
      expect(sent.recipients.single.address, '+41791234567');
      expect(sent.textBody!.content, endsWith('is your console code.'));
      expect(spec.hint, '+*******4567');
      expect(spec.validity, const Duration(minutes: 5));
    });

    test('the texted code verifies and a wrong one does not', () async {
      final spec = await text.issueChallenge(_context());
      final code = _deliveredCode(sms);

      expect(await _verify(text, spec, code), isTrue);
      expect(await _verify(text, spec, '000000'), isFalse);
    });

    // The same order [TomSmsRequest.toPrincipal] uses, so a code and a
    // notification reach the same handset.
    test('falls back from mobile to phone', () async {
      await text.issueChallenge(_context(mobile: null, phone: '+41441112233'));

      expect(sms.last!.recipients.single.address, '+41441112233');
    });

    test('a user with neither number is refused', () async {
      await expectLater(
        text.issueChallenge(_context(mobile: null)),
        throwsA(
          isA<TomLoginException>().having(
            (e) => e.key,
            'key',
            'login.error.2fa.not-enrolled',
          ),
        ),
      );
      expect(sms.count, 0);
    });

    // -----------------------------------------------------------------------
    // Delivery failure
    // -----------------------------------------------------------------------

    /// A code that was never sent must fail the challenge here, not become a
    /// prompt the user stares at until it expires. The flow cannot tell an
    /// undelivered challenge from a user who has not typed yet, so the adaptor
    /// has to.
    test(
      'a transport failure fails the challenge instead of prompting',
      () async {
        mail.failAlways = TomDeliveryException.transient(
          'test.relay.down',
          'The relay refused the connection.',
        );

        await expectLater(
          email.issueChallenge(_context()),
          throwsA(
            isA<TomLoginException>().having(
              (e) => e.key,
              'key',
              'login.error.2fa.delivery-failed',
            ),
          ),
        );
        expect(mail.count, 0);
      },
    );

    test('a permanent transport failure fails the same way', () async {
      sms.failAlways = TomDeliveryException.permanent(
        'test.gateway.rejected',
        'The gateway rejected the number.',
      );

      await expectLater(
        text.issueChallenge(_context()),
        throwsA(
          isA<TomLoginException>().having(
            (e) => e.key,
            'key',
            'login.error.2fa.delivery-failed',
          ),
        ),
      );
    });

    // A template nobody wrote is a fault of the same class: the challenge
    // cannot be issued, so it must not be.
    test('a missing template fails the challenge', () async {
      final saved = TomEmailCode2FAService.globalSettingChallengeTemplateKey;
      addTearDown(
        () => TomEmailCode2FAService.globalSettingChallengeTemplateKey = saved,
      );
      TomEmailCode2FAService.globalSettingChallengeTemplateKey =
          'email.nobody_wrote_this';

      await expectLater(
        email.issueChallenge(_context()),
        throwsA(
          isA<TomLoginException>().having(
            (e) => e.key,
            'key',
            'login.error.2fa.delivery-failed',
          ),
        ),
      );
      expect(mail.count, 0);
    });

    /// A wiring fault, not a login outcome — so it is a [Tom2FAException] the
    /// operator is told about rather than something the user could fix.
    test('a mechanism with no messaging service installed says so', () async {
      TomBean.resetBeanContext();

      await expectLater(
        email.issueChallenge(_context()),
        throwsA(
          isA<Tom2FAException>().having(
            (e) => e.key,
            'key',
            'authentication.2fa.email.no_service',
          ),
        ),
      );
    });

    // The same raise, one line in the shared base class, interpolating the
    // subclass's `type`. Worth asserting twice rather than once: the key an
    // operator greps for is the interpolated one, and the two subclasses reach
    // it through *different* `resolveDeliveryService` overrides — a subclass
    // that resolved the wrong bean type would still throw, just never here.
    test('the sms mechanism names itself, not the family', () async {
      TomBean.resetBeanContext();

      await expectLater(
        text.issueChallenge(_context()),
        throwsA(
          isA<Tom2FAException>()
              .having((e) => e.key, 'key', 'authentication.2fa.sms.no_service')
              // The message names what to install, which is the only actionable
              // part of a wiring failure.
              .having(
                (e) => e.toString(),
                'message',
                contains('TomSmsService'),
              ),
        ),
      );
    });

    // -----------------------------------------------------------------------
    // Descriptors
    // -----------------------------------------------------------------------

    test('both mechanisms describe themselves in resource keys only', () {
      expect(email.descriptor.type, 'email');
      expect(email.descriptor.displayNameKey, 'two_factor.email.name');
      expect(email.descriptor.descriptionKey, 'two_factor.email.description');
      expect(email.descriptor.iconKey, 'two_factor.email.icon');

      expect(text.descriptor.type, 'sms');
      expect(text.descriptor.displayNameKey, 'two_factor.sms.name');
      expect(text.descriptor.descriptionKey, 'two_factor.sms.description');
      expect(text.descriptor.iconKey, 'two_factor.sms.icon');
    });

    test('both can be enrolled', () {
      expect(email, isA<Tom2FAEnrolmentSupport>());
      expect(text, isA<Tom2FAEnrolmentSupport>());
    });

    // -----------------------------------------------------------------------
    // Prerequisites
    // -----------------------------------------------------------------------

    // The throw above is the last line of defence, and it is a bad place to
    // discover a missing mail relay: it happens inside a login the user has
    // already begun. The same question asked at registration keeps the
    // mechanism out of every offer, so the login never reaches the throw.
    test('both declare the service they send through as a prerequisite', () {
      expect(email, isA<Tom2FAPrerequisite>());
      expect(text, isA<Tom2FAPrerequisite>());
    });

    test('nothing is missing while the services are installed', () {
      expect(email.unmetPrerequisite, isNull);
      expect(text.unmetPrerequisite, isNull);
    });

    // Named types rather than "a delivery service": the operator reading this
    // line has to know which bean to install, and the two channels are
    // installed separately.
    test('an absent service is reported by the type to install', () {
      TomBean.resetBeanContext();

      expect(email.unmetPrerequisite, contains('TomEmailService'));
      expect(email.unmetPrerequisite, contains('email'));
      expect(text.unmetPrerequisite, contains('TomSmsService'));
      expect(text.unmetPrerequisite, contains('sms'));
    });

    // One channel installed is one channel offered. A deployment that sends
    // mail but has no SMS contract keeps its mail codes.
    test('the two channels are judged separately', () {
      TomBean.resetBeanContext();
      TomBean.withType(
        TomEmailService,
        TomEmailService(outbox: outbox, texts: _texts()),
      );

      expect(email.unmetPrerequisite, isNull);
      expect(text.unmetPrerequisite, isNotNull);
    });
  });

  // ===========================================================================
  // ENROLMENT
  // ===========================================================================

  /// Enrolling a delivered-code factor *is* proving control of the destination:
  /// there is no secret to install, only an address to confirm.
  group('delivered-code enrolment', () {
    late TomMemoryMessageTransport mail;
    late TomMessageOutbox outbox;
    late TomEmailCode2FAService email;
    late TomMemory2FAEnrolmentStore store;

    setUp(() {
      TomBean.resetBeanContext();
      final clock = _FakeClock(DateTime.utc(2026, 8, 2, 10));
      mail = TomMemoryMessageTransport(channel: TomMessageChannel.email);
      outbox = TomMessageOutbox(
        router: TomMessageRouter([mail]),
        clock: clock.call,
      );
      addTearDown(outbox.close);
      TomBean.withType(
        TomEmailService,
        TomEmailService(outbox: outbox, texts: _texts()),
      );
      store = TomMemory2FAEnrolmentStore();
      TomBean.withType(Tom2FAEnrolmentStore, store);
      email = TomEmailCode2FAService();
    });

    tearDown(TomBean.resetBeanContext);

    test(
      'beginning an enrolment sends a code to the claimed address',
      () async {
        final offer = await email.beginEnrolment(_context());

        expect(mail.count, 1);
        expect(mail.last!.subject, 'Confirm this address');
        expect(offer.type, 'email');
        expect(offer.hint, 'a***h@example.com');
        expect(offer.validity, const Duration(minutes: 15));
      },
    );

    test(
      'the offer keeps the address and the seal out of the client half',
      () async {
        final offer = await email.beginEnrolment(_context());
        final code = _deliveredCode(mail);

        expect(offer.clientData.toString(), isNot(contains(code)));
        expect(
          offer.clientData.toString(),
          isNot(contains('alice.smith@example.com')),
          reason: 'the client gets the mask, the server keeps the address',
        );
        expect(
          offer.enrolmentData[TomDeliveredCode2FAService.destinationKey],
          'alice.smith@example.com',
        );
        expect(offer.enrolmentData.toString(), isNot(contains(code)));
      },
    );

    test('confirming with the delivered code yields the enrolment', () async {
      final offer = await email.beginEnrolment(_context());
      final code = _deliveredCode(mail);

      final enrolment = await email.confirmEnrolment(_context(), offer, code);

      expect(enrolment.type, 'email');
      expect(enrolment.hint, 'a***h@example.com');
      expect(
        enrolment.secretData[TomDeliveredCode2FAService.destinationKey],
        'alice.smith@example.com',
      );
    });

    /// The whole point of the step: an unconfirmed destination must not become
    /// an enrolment. Throwing rather than returning `null` is what makes that
    /// unforgettable at the call site.
    test('a wrong code confirms nothing', () async {
      final offer = await email.beginEnrolment(_context());

      await expectLater(
        email.confirmEnrolment(_context(), offer, '000000'),
        throwsA(
          isA<TomLoginException>().having(
            (e) => e.key,
            'key',
            'login.error.2fa.enrolment-code-invalid',
          ),
        ),
      );
    });

    test('an offer with no destination cannot be confirmed', () async {
      final offer = Tom2FAEnrolmentOffer(
        type: 'email',
        hint: 'a***h@example.com',
        clientData: const {},
        enrolmentData: TomDeliveredCode2FAService.sealCode('123456'),
      );

      await expectLater(
        email.confirmEnrolment(_context(), offer, '123456'),
        throwsA(
          isA<TomLoginException>().having(
            (e) => e.key,
            'key',
            'login.error.2fa.enrolment-offer-invalid',
          ),
        ),
      );
    });

    test(
      'a user with no address on record cannot begin an enrolment',
      () async {
        await expectLater(
          email.beginEnrolment(_context(email: null)),
          throwsA(
            isA<TomLoginException>().having(
              (e) => e.key,
              'key',
              'login.error.2fa.no-destination',
            ),
          ),
        );
        expect(mail.count, 0);
      },
    );

    /// A proven address outranks an asserted one: an attacker who can edit a
    /// profile field must not thereby redirect the second factor.
    test('a confirmed enrolment outranks the user record', () async {
      final context = _context();
      await store.store(
        context,
        Tom2FAEnrolment(
          type: 'email',
          enrolmentId: 'email',
          hint: 'p***y@example.org',
          secretData: const {
            TomDeliveredCode2FAService.destinationKey: 'proven@example.org',
          },
        ),
      );

      await email.issueChallenge(context);

      expect(mail.last!.recipients.single.address, 'proven@example.org');
    });

    // Enrolling is how a destination *becomes* confirmed, so starting from the
    // confirmed one would make the step a tautology no user could ever use to
    // move to a new address.
    test(
      'beginning an enrolment goes to the record, not the confirmed one',
      () async {
        final context = _context();
        await store.store(
          context,
          Tom2FAEnrolment(
            type: 'email',
            enrolmentId: 'email',
            hint: 'p***y@example.org',
            secretData: const {
              TomDeliveredCode2FAService.destinationKey: 'proven@example.org',
            },
          ),
        );

        await email.beginEnrolment(context);

        expect(mail.last!.recipients.single.address, 'alice.smith@example.com');
      },
    );

    // One row per channel per user: [resolveDestination] answers with the first
    // match, so a second row would make which address is challenged depend on
    // storage order.
    test(
      're-confirming replaces the destination rather than adding one',
      () async {
        final context = _context();
        final first = await email.beginEnrolment(context);
        await store.store(
          context,
          await email.confirmEnrolment(context, first, _deliveredCode(mail)),
        );
        final second = await email.beginEnrolment(context);
        await store.store(
          context,
          await email.confirmEnrolment(context, second, _deliveredCode(mail)),
        );

        final stored = await store.enrolmentsFor(context);
        expect(stored.where((e) => e.type == 'email'), hasLength(1));
      },
    );
  });

  // ===========================================================================
  // THROUGH THE LOGIN FLOW
  // ===========================================================================

  /// The same assertions again, but driven through the real two-pass server —
  /// because the property that matters is about the *token*, and only the
  /// server builds one.
  group('delivered codes through the login flow', () {
    late TomAuthenticationService savedUserService;
    late bool savedProtectionDefault;
    late TomMemoryMessageTransport mail;
    late TomMessageOutbox outbox;
    final server = TomAuthenticationServer();

    setUp(() {
      savedUserService =
          TomAuthenticationServer.globalSettingUserAuthenticationService;
      savedProtectionDefault =
          TomResourceKeyProtection.globalSettingProtectionDefault;
      // Off, so the token's payload is inspectable rather than key-protected —
      // this group's whole subject is what the payload does and does not hold.
      TomResourceKeyProtection.globalSettingProtectionDefault = false;

      TomBean.resetBeanContext();
      Tom2FARegistry.reset();
      Tom2FARegistry.register('email', TomEmailCode2FAService());

      final clock = _FakeClock(DateTime.utc(2026, 8, 2, 10));
      mail = TomMemoryMessageTransport(channel: TomMessageChannel.email);
      outbox = TomMessageOutbox(
        router: TomMessageRouter([mail]),
        clock: clock.call,
      );
      addTearDown(outbox.close);
      TomBean.withType(
        TomEmailService,
        TomEmailService(outbox: outbox, texts: _texts()),
      );
      TomBean.withType(
        Tom2FAPolicy,
        TomRole2FAPolicy(
          defaultRequirement: Tom2FARequirement.required,
          mechanisms: const ['email'],
        ),
      );

      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _StubAuthService();
    });

    tearDown(() {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          savedUserService;
      TomResourceKeyProtection.globalSettingProtectionDefault =
          savedProtectionDefault;
      Tom2FARegistry.reset();
      TomBean.resetBeanContext();
    });

    test('pass 1 mails a code and hands back an interim token', () async {
      final result = await server.authenticatePass1(_message());

      expect(result.error, isEmpty);
      expect(result.requires2FA, isTrue);
      expect(result.twoFactorType, 'email');
      expect(mail.count, 1);
      expect(
        TomBearerAuthentication.convertTokenPayloadToPrincipal(
          TomClientJwtToken(result.authorizationToken),
        ).authenticated,
        isFalse,
        reason: 'the interim token grants no session',
      );
    });

    /// **The property the encrypted split exists for.**
    ///
    /// The client holds this token while it types the code it was mailed. If
    /// the code — or anything the code can be derived from — were readable in
    /// the public claims, the second factor would be proving possession of the
    /// first.
    test('the code never reaches the token the client holds', () async {
      final result = await server.authenticatePass1(_message());
      final code = _deliveredCode(mail);

      final public = TomClientJwtToken(
        result.authorizationToken,
        decrypt: false,
      ).payload;
      expect(public, isNot(contains(Tom2FAClaims.verificationData)));
      expect(public.toString(), isNot(contains(code)));

      // And not even in the half only the server can read: what is kept there
      // is a salted hash, so a leaked interim token still does not yield a
      // usable code.
      final decrypted = TomClientJwtToken(result.authorizationToken);
      final verification =
          decrypted.secretData![Tom2FAClaims.verificationData] as Map;
      expect(
        verification.keys,
        containsAll([
          TomDeliveredCode2FAService.saltKey,
          TomDeliveredCode2FAService.hashKey,
        ]),
      );
      expect(verification.toString(), isNot(contains(code)));
    });

    test(
      'the masked address does travel, so the user knows where to look',
      () async {
        final result = await server.authenticatePass1(_message());

        final challenge = Tom2FAChallenge.fromClaims(
          TomClientJwtToken(result.authorizationToken, decrypt: false).payload,
        )!;
        expect(challenge.hint, 'a***h@example.com');
        expect(challenge.hint, isNot(contains('alice.smith')));
        expect(
          challenge.clientData[TomDeliveredCode2FAService.digitsKey],
          6,
          reason: 'so a UI can size its input without knowing the mechanism',
        );
      },
    );

    test('pass 2 with the mailed code issues a session', () async {
      final pass1 = await server.authenticatePass1(_message());
      final code = _deliveredCode(mail);

      final pass2 = await server.authenticatePass2(
        _message(password: code),
        challengeToken: TomClientJwtToken(pass1.authorizationToken),
      );

      expect(pass2.error, isEmpty);
      expect(pass2.requires2FA, isFalse);
      expect(
        TomBearerAuthentication.convertTokenPayloadToPrincipal(
          TomClientJwtToken(pass2.authorizationToken),
        ).authenticated,
        isTrue,
      );
    });

    test(
      'pass 2 with a wrong code is refused and offers another attempt',
      () async {
        final pass1 = await server.authenticatePass1(_message());

        final pass2 = await server.authenticatePass2(
          _message(password: '000000'),
          challengeToken: TomClientJwtToken(pass1.authorizationToken),
        );

        expect(pass2.error, 'login.error.2fa.invalid-code');
        expect(pass2.requires2FA, isTrue);
        expect(mail.count, 1, reason: 'a retry reuses the code already sent');
      },
    );

    /// The flow-level half of the delivery rule: a relay that is down produces
    /// a failed login, not a pending challenge for a code nobody will receive.
    test('a delivery failure fails the login rather than prompting', () async {
      mail.failAlways = TomDeliveryException.transient(
        'test.relay.down',
        'The relay refused the connection.',
      );

      final result = await server.authenticatePass1(_message());

      expect(result.error, 'login.error.2fa.delivery-failed');
      expect(result.requires2FA, isFalse);
      expect(result.authorizationToken, isEmpty);
    });

    /// Enrolment through the server, which is where "confirm before storing"
    /// has to hold: nothing is written until the mailed code comes back.
    test(
      'the enrol-on-first-login round trip confirms before storing',
      () async {
        final store = TomMemory2FAEnrolmentStore();
        TomBean.withType(Tom2FAEnrolmentStore, store);
        final context = _context();

        final offered = await server.authenticatePass1(_message());
        expect(offered.requires2FAEnrolment, isTrue);
        expect(offered.availableTwoFactorMethods.map((m) => m.type), ['email']);
        expect(
          offered.availableTwoFactorMethods.single.displayNameKey,
          'two_factor.email.name',
        );
        expect(mail.count, 0, reason: 'nothing to challenge yet');

        final begun = await server.beginTwoFactorEnrolment(
          _message(password: 'email'),
          enrolmentToken: TomClientJwtToken(offered.authorizationToken),
        );
        expect(begun.error, isEmpty);
        expect(mail.count, 1);
        final code = _deliveredCode(mail);
        expect(
          await store.enrolmentsFor(context),
          isEmpty,
          reason: 'an unconfirmed address is not an enrolment',
        );

        // The confirmation material is encrypted, so a client cannot swap the
        // address it is about to be tested on.
        final publicClaims = TomClientJwtToken(
          begun.authorizationToken,
          decrypt: false,
        ).payload;
        expect(publicClaims, isNot(contains(Tom2FAEnrolmentClaims.offerData)));
        expect(publicClaims.toString(), isNot(contains(code)));

        final refused = await server.completeTwoFactorEnrolment(
          _message(password: '000000'),
          enrolmentToken: TomClientJwtToken(begun.authorizationToken),
        );
        expect(refused.error, isNotEmpty);
        expect(await store.enrolmentsFor(context), isEmpty);

        final done = await server.completeTwoFactorEnrolment(
          _message(password: code),
          enrolmentToken: TomClientJwtToken(begun.authorizationToken),
        );

        expect(done.error, isEmpty);
        expect(done.requires2FAEnrolment, isFalse);
        final stored = await store.enrolmentsFor(context);
        expect(stored, hasLength(1));
        expect(stored.single.type, 'email');
        expect(
          stored.single.secretData[TomDeliveredCode2FAService.destinationKey],
          'alice.smith@example.com',
        );
        expect(stored.single.isPrimary, isTrue);
      },
    );
  });
}

/// Runs [spec] back through [service] the way the server would, so a test does
/// not have to rebuild a [Tom2FASubmission] five times.
Future<bool> _verify(
  TomDeliveredCode2FAService service,
  Tom2FAChallengeSpec spec,
  String submitted,
) => service.verifySubmission(
  _context(),
  Tom2FASubmission(
    submitted: submitted,
    challenge: Tom2FAChallenge(
      type: service.type,
      hint: spec.hint,
      attemptsAllowed: spec.attemptsAllowed,
      expiresAt: DateTime.now().toUtc().add(spec.validity),
      clientData: spec.clientData,
    ),
    verificationData: spec.verificationData,
  ),
);
