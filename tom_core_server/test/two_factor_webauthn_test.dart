/// The passkey second factor, driven end to end by a software authenticator:
/// real P-256 keys, real CBOR, real signatures. Every refusal case is a valid
/// response with exactly one thing wrong, so each check is shown to be the one
/// that refused it.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

const String _rpId = 'example.com';
const String _origin = 'https://example.com';

TomPrincipal _principal() => TomPrincipal(
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
    id: '1',
    username: 'alice',
    firstname: 'Alice',
    lastname: 'Smith',
    attributes: {},
    timezone: 'utc',
  ),
  aci: TomAccessControlInformation(roles: const ['user']),
);

Tom2FAContext _context() => Tom2FAContext(
  principal: _principal(),
  organization: 'acme',
  application: 'console',
);

/// A challenge as the login pipeline hands it to `verifySubmission`.
Tom2FAChallenge _challenge() => Tom2FAChallenge(
  type: TomWebAuthn2FAService.mechanismType,
  expiresAt: DateTime.now().add(const Duration(minutes: 5)),
);

Matcher _throwsKey(String key) =>
    throwsA(isA<TomLoginException>().having((e) => e.key, 'key', key));

/// Rewrites one field of a base64url JSON blob, for the one-thing-wrong cases.
String _rewriteJson(String encoded, String field, Object value) {
  final json =
      jsonDecode(utf8.decode(TomBase64Url.decode(encoded)!))
          as Map<String, Object?>;
  json[field] = value;
  return TomBase64Url.encode(utf8.encode(jsonEncode(json)));
}

void main() {
  late TomMemory2FAEnrolmentStore store;
  late TomWebAuthn2FAService service;

  setUp(() {
    TomBean.resetBeanContext();
    store = TomMemory2FAEnrolmentStore();
    TomBean.withType<Tom2FAEnrolmentStore>(store);
    TomWebAuthn2FAService.globalSettingRelyingPartyId = _rpId;
    TomWebAuthn2FAService.globalSettingAllowedOrigins = {_origin};
    TomWebAuthn2FAService.globalSettingUserVerification =
        TomWebAuthnUserVerification.preferred;
    service = TomWebAuthn2FAService();
  });

  tearDown(() {
    TomBean.resetBeanContext();
    TomWebAuthn2FAService.globalSettingRelyingPartyId = '';
    TomWebAuthn2FAService.globalSettingAllowedOrigins = {};
  });

  /// Enrols [authenticator] through the service and stores the result.
  Future<Tom2FAEnrolment> enrol(
    TomWebAuthnSoftwareAuthenticator authenticator,
  ) async {
    final offer = await service.beginEnrolment(_context());
    final options = TomWebAuthnCreationOptions.fromJson(
      offer.clientData[TomWebAuthn2FAService.optionsKey],
    )!;
    final enrolment = await service.confirmEnrolment(
      _context(),
      offer,
      authenticator.create(options).toSubmission(),
    );
    await store.store(_context(), enrolment);
    return enrolment;
  }

  /// Issues a challenge and answers it with [authenticator], after [tamper].
  Future<bool> signIn(
    TomWebAuthnSoftwareAuthenticator authenticator, {
    TomWebAuthnAuthenticationResponse Function(
      TomWebAuthnAuthenticationResponse,
    )?
    tamper,
  }) async {
    final spec = await service.issueChallenge(_context());
    final options = TomWebAuthnRequestOptions.fromJson(
      spec.clientData[TomWebAuthn2FAService.optionsKey],
    )!;
    var response = authenticator.get(options);
    if (tamper != null) response = tamper(response);
    return service.verifySubmission(
      _context(),
      Tom2FASubmission(
        submitted: response.toSubmission(),
        challenge: _challenge(),
        verificationData: spec.verificationData,
      ),
    );
  }

  group('the wire types', () {
    test('round-trip through the String seam', () {
      final authenticator = TomWebAuthnSoftwareAuthenticator(origin: _origin);
      final response = authenticator.get(
        const TomWebAuthnRequestOptions(challenge: 'AAAA', rpId: _rpId),
      );
      final back = TomWebAuthnAuthenticationResponse.fromSubmission(
        response.toSubmission(),
      )!;
      expect(back.toJson(), response.toJson());
      expect(
        TomWebAuthnAuthenticationResponse.fromSubmission('not a submission'),
        isNull,
      );
    });

    test('use the W3C JSON field names', () {
      const options = TomWebAuthnCreationOptions(
        rpId: _rpId,
        rpName: 'Acme',
        userId: 'dXNlcg',
        userName: 'alice',
        userDisplayName: 'Alice',
        challenge: 'Y2hhbGxlbmdl',
      );
      final json = options.toJson();
      expect(json['rp'], {'id': _rpId, 'name': 'Acme'});
      expect(json['attestation'], 'none');
      expect(json['pubKeyCredParams'], [
        {'type': 'public-key', 'alg': -7},
        {'type': 'public-key', 'alg': -257},
      ]);
      expect(TomWebAuthnCreationOptions.fromJson(json)!.toJson(), json);
    });
  });

  group('the prerequisite', () {
    test('is unmet until a relying party id is configured', () {
      TomWebAuthn2FAService.globalSettingRelyingPartyId = '';
      expect(
        service.unmetPrerequisite,
        contains('globalSettingRelyingPartyId'),
      );
      TomWebAuthn2FAService.globalSettingRelyingPartyId = _rpId;
      expect(service.unmetPrerequisite, isNull);
    });

    test('origins default to https on the RP id', () {
      TomWebAuthn2FAService.globalSettingAllowedOrigins = {};
      expect(TomWebAuthn2FAService.allowedOrigins, {'https://$_rpId'});
    });
  });

  group('enrolment', () {
    test('offers creation options bound to the RP and the user', () async {
      final offer = await service.beginEnrolment(_context());
      final options = TomWebAuthnCreationOptions.fromJson(
        offer.clientData[TomWebAuthn2FAService.optionsKey],
      )!;
      expect(options.rpId, _rpId);
      expect(options.rpName, 'console');
      expect(options.userName, 'alice');
      expect(options.userDisplayName, 'Alice Smith');
      expect(options.userId, TomWebAuthn2FAService.userHandleOf(_context()));
      expect(options.userId, isNot(contains('alice')));
      expect(
        offer.enrolmentData[TomWebAuthn2FAService.challengeKey],
        options.challenge,
        reason: 'the server keeps its own copy of the challenge',
      );
    });

    test('stores the credential a valid registration made', () async {
      final authenticator = TomWebAuthnSoftwareAuthenticator(origin: _origin);
      final enrolment = await enrol(authenticator);

      expect(enrolment.type, 'webauthn');
      expect(enrolment.enrolmentId, 'webauthn:${authenticator.id}');
      expect(
        enrolment.secretData[TomWebAuthn2FAService.credentialIdKey],
        authenticator.id,
      );
      expect(
        enrolment.secretData[TomWebAuthn2FAService.publicKeyKey],
        isA<String>(),
      );
    });

    test('excludes credentials the user already holds', () async {
      final first = TomWebAuthnSoftwareAuthenticator(origin: _origin);
      await enrol(first);
      final offer = await service.beginEnrolment(_context());
      final options = TomWebAuthnCreationOptions.fromJson(
        offer.clientData[TomWebAuthn2FAService.optionsKey],
      )!;
      expect(options.excludeCredentialIds, [first.id]);
    });

    Future<void> expectRefused(
      TomWebAuthnRegistrationResponse Function(
        TomWebAuthnRegistrationResponse,
        TomWebAuthnCreationOptions,
      )
      tamper,
    ) async {
      final authenticator = TomWebAuthnSoftwareAuthenticator(origin: _origin);
      final offer = await service.beginEnrolment(_context());
      final options = TomWebAuthnCreationOptions.fromJson(
        offer.clientData[TomWebAuthn2FAService.optionsKey],
      )!;
      final response = tamper(authenticator.create(options), options);
      await expectLater(
        service.confirmEnrolment(_context(), offer, response.toSubmission()),
        _throwsKey('login.error.2fa.webauthn-registration-invalid'),
      );
    }

    test('refuses a registration for another challenge', () async {
      await expectRefused(
        (r, _) => TomWebAuthnRegistrationResponse(
          id: r.id,
          clientDataJson: _rewriteJson(r.clientDataJson, 'challenge', 'AAAA'),
          attestationObject: r.attestationObject,
        ),
      );
    });

    test('refuses a registration from another origin', () async {
      await expectRefused(
        (r, _) => TomWebAuthnRegistrationResponse(
          id: r.id,
          clientDataJson: _rewriteJson(
            r.clientDataJson,
            'origin',
            'https://evil.example',
          ),
          attestationObject: r.attestationObject,
        ),
      );
    });

    test('refuses an assertion presented as a registration', () async {
      await expectRefused(
        (r, _) => TomWebAuthnRegistrationResponse(
          id: r.id,
          clientDataJson: _rewriteJson(
            r.clientDataJson,
            'type',
            'webauthn.get',
          ),
          attestationObject: r.attestationObject,
        ),
      );
    });

    test('refuses a credential made for another RP id', () async {
      final authenticator = TomWebAuthnSoftwareAuthenticator(origin: _origin);
      final offer = await service.beginEnrolment(_context());
      final options = TomWebAuthnCreationOptions.fromJson(
        offer.clientData[TomWebAuthn2FAService.optionsKey],
      )!;
      final foreign = TomWebAuthnCreationOptions.fromJson({
        ...options.toJson(),
        'rp': {'id': 'evil.example', 'name': 'x'},
      })!;
      await expectLater(
        service.confirmEnrolment(
          _context(),
          offer,
          authenticator.create(foreign).toSubmission(),
        ),
        _throwsKey('login.error.2fa.webauthn-registration-invalid'),
      );
    });

    test(
      'refuses a response whose id is not the attested credential',
      () async {
        await expectRefused(
          (r, _) => TomWebAuthnRegistrationResponse(
            id: TomWebAuthnSoftwareAuthenticator(origin: _origin).id,
            clientDataJson: r.clientDataJson,
            attestationObject: r.attestationObject,
          ),
        );
      },
    );

    test('refuses an unverified user when verification is required', () async {
      TomWebAuthn2FAService.globalSettingUserVerification =
          TomWebAuthnUserVerification.required;
      final authenticator = TomWebAuthnSoftwareAuthenticator(
        origin: _origin,
        userVerified: false,
      );
      final offer = await service.beginEnrolment(_context());
      final options = TomWebAuthnCreationOptions.fromJson(
        offer.clientData[TomWebAuthn2FAService.optionsKey],
      )!;
      await expectLater(
        service.confirmEnrolment(
          _context(),
          offer,
          authenticator.create(options).toSubmission(),
        ),
        _throwsKey('login.error.2fa.webauthn-registration-invalid'),
      );
    });

    test('refuses an offer that lost its challenge', () async {
      await expectLater(
        service.confirmEnrolment(
          _context(),
          const Tom2FAEnrolmentOffer(type: 'webauthn'),
          'x',
        ),
        _throwsKey('login.error.2fa.enrolment-offer-invalid'),
      );
    });
  });

  group('sign-in', () {
    test('a user with no passkey is refused at challenge time', () async {
      await expectLater(
        service.issueChallenge(_context()),
        _throwsKey('login.error.2fa.not-enrolled'),
      );
    });

    test('the enrolled passkey signs in, and the counter is stored', () async {
      final authenticator = TomWebAuthnSoftwareAuthenticator(origin: _origin);
      await enrol(authenticator);

      expect(await signIn(authenticator), isTrue);
      expect(await signIn(authenticator), isTrue);

      final stored = (await store.enrolmentsFor(_context())).single;
      expect(stored.secretData[TomWebAuthn2FAService.signCountKey], 2);
    });

    test('a passkey that never counts is accepted every time', () async {
      final authenticator = TomWebAuthnSoftwareAuthenticator(
        origin: _origin,
        countsSignatures: false,
      );
      await enrol(authenticator);

      expect(await signIn(authenticator), isTrue);
      expect(await signIn(authenticator), isTrue);
    });

    test('a counter that does not move up is a clone and refused', () async {
      final authenticator = TomWebAuthnSoftwareAuthenticator(origin: _origin);
      await enrol(authenticator);
      expect(await signIn(authenticator), isTrue);

      authenticator.signCount = 0; // the copy that never saw the first login
      expect(await signIn(authenticator), isFalse);
    });

    test('a passkey that is not enrolled is refused', () async {
      await enrol(TomWebAuthnSoftwareAuthenticator(origin: _origin));
      final stranger = TomWebAuthnSoftwareAuthenticator(origin: _origin);
      expect(await signIn(stranger), isFalse);
    });

    test('a signature from another key is refused', () async {
      final authenticator = TomWebAuthnSoftwareAuthenticator(origin: _origin);
      await enrol(authenticator);
      final impostor = TomWebAuthnSoftwareAuthenticator(origin: _origin);
      expect(
        await signIn(
          authenticator,
          tamper: (r) {
            final forged = impostor.get(
              TomWebAuthnRequestOptions.fromJson({
                'challenge': jsonDecode(
                  utf8.decode(TomBase64Url.decode(r.clientDataJson)!),
                )['challenge'],
                'rpId': _rpId,
              })!,
            );
            return TomWebAuthnAuthenticationResponse(
              id: r.id,
              clientDataJson: forged.clientDataJson,
              authenticatorData: forged.authenticatorData,
              signature: forged.signature,
            );
          },
        ),
        isFalse,
      );
    });

    test('a replayed answer to an earlier challenge is refused', () async {
      final authenticator = TomWebAuthnSoftwareAuthenticator(origin: _origin);
      await enrol(authenticator);
      final first = await service.issueChallenge(_context());
      final answer = authenticator.get(
        TomWebAuthnRequestOptions.fromJson(
          first.clientData[TomWebAuthn2FAService.optionsKey],
        )!,
      );
      final second = await service.issueChallenge(_context());

      expect(
        await service.verifySubmission(
          _context(),
          Tom2FASubmission(
            submitted: answer.toSubmission(),
            challenge: _challenge(),
            verificationData: second.verificationData,
          ),
        ),
        isFalse,
      );
    });

    test('an answer signed on a phishing origin is refused', () async {
      // The signature is valid: the authenticator signed what the browser gave
      // it, and the browser wrote the page's real origin into that. The origin
      // check is the only thing standing between this and a login.
      final authenticator = TomWebAuthnSoftwareAuthenticator(origin: _origin);
      await enrol(authenticator);
      authenticator.origin = 'https://examp1e.com';
      expect(await signIn(authenticator), isFalse);
      authenticator.origin = _origin;
      expect(await signIn(authenticator), isTrue);
    });

    test(
      'an unverified user is refused when verification is required',
      () async {
        final authenticator = TomWebAuthnSoftwareAuthenticator(origin: _origin);
        await enrol(authenticator);
        TomWebAuthn2FAService.globalSettingUserVerification =
            TomWebAuthnUserVerification.required;
        authenticator.userVerified = false;
        expect(await signIn(authenticator), isFalse);
        authenticator.userVerified = true;
        expect(await signIn(authenticator), isTrue);
      },
    );

    test('a user handle for someone else is refused', () async {
      final authenticator = TomWebAuthnSoftwareAuthenticator(origin: _origin);
      await enrol(authenticator);
      expect(
        await signIn(
          authenticator,
          tamper: (r) => TomWebAuthnAuthenticationResponse(
            id: r.id,
            clientDataJson: r.clientDataJson,
            authenticatorData: r.authenticatorData,
            signature: r.signature,
            userHandle: 'c29tZW9uZS1lbHNl',
          ),
        ),
        isFalse,
      );
    });

    test('garbage is a wrong answer, not an error', () async {
      await enrol(TomWebAuthnSoftwareAuthenticator(origin: _origin));
      final spec = await service.issueChallenge(_context());
      expect(
        await service.verifySubmission(
          _context(),
          Tom2FASubmission(
            submitted: '123456',
            challenge: _challenge(),
            verificationData: spec.verificationData,
          ),
        ),
        isFalse,
      );
    });

    test('every enrolled passkey may answer', () async {
      final phone = TomWebAuthnSoftwareAuthenticator(origin: _origin);
      final key = TomWebAuthnSoftwareAuthenticator(origin: _origin);
      await enrol(phone);
      await enrol(key);

      final spec = await service.issueChallenge(_context());
      final options = TomWebAuthnRequestOptions.fromJson(
        spec.clientData[TomWebAuthn2FAService.optionsKey],
      )!;
      expect(options.allowCredentialIds, unorderedEquals([phone.id, key.id]));
      expect(await signIn(key), isTrue);
      expect(await signIn(phone), isTrue);
    });
  });
}
