/// The passkey wire types both halves of the second factor read: the W3C JSON
/// forms, the base64url codec, and the `String` seam a response crosses.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  group('TomBase64Url', () {
    test('encodes without padding and decodes with or without it', () {
      expect(TomBase64Url.encode([0xfb, 0xff]), '-_8');
      expect(TomBase64Url.decode('-_8'), [0xfb, 0xff]);
      expect(TomBase64Url.decode('-_8='), [0xfb, 0xff]);
      expect(TomBase64Url.encode(utf8.encode('passkey')), 'cGFzc2tleQ');
    });

    test('answers null for text that is not base64url', () {
      expect(TomBase64Url.decode('not base64!'), isNull);
    });
  });

  group('the options', () {
    test('creation options round-trip through their W3C JSON form', () {
      const options = TomWebAuthnCreationOptions(
        rpId: 'example.com',
        rpName: 'Acme',
        userId: 'dXNlcg',
        userName: 'alice',
        userDisplayName: 'Alice',
        challenge: 'Y2hhbGxlbmdl',
        userVerification: TomWebAuthnUserVerification.required,
        excludeCredentialIds: ['Y3JlZA'],
      );
      final json = options.toJson();
      expect(json['attestation'], 'none');
      expect(json['excludeCredentials'], [
        {'type': 'public-key', 'id': 'Y3JlZA'},
      ]);
      expect(
        (json['authenticatorSelection']! as Map)['userVerification'],
        'required',
      );
      final back = TomWebAuthnCreationOptions.fromJson(
        jsonDecode(jsonEncode(json)),
      )!;
      expect(back.toJson(), json);
    });

    test('request options round-trip through their W3C JSON form', () {
      const options = TomWebAuthnRequestOptions(
        challenge: 'Y2hhbGxlbmdl',
        rpId: 'example.com',
        allowCredentialIds: ['Y3JlZA'],
      );
      final back = TomWebAuthnRequestOptions.fromJson(
        jsonDecode(jsonEncode(options.toJson())),
      )!;
      expect(back.toJson(), options.toJson());
    });

    test('options missing a required field read as null', () {
      expect(TomWebAuthnCreationOptions.fromJson({'rp': {}}), isNull);
      expect(TomWebAuthnRequestOptions.fromJson({'rpId': 'x'}), isNull);
      expect(TomWebAuthnRequestOptions.fromJson('not a map'), isNull);
    });
  });

  group('the responses through the String seam', () {
    test('a registration response survives toSubmission/fromSubmission', () {
      const response = TomWebAuthnRegistrationResponse(
        id: 'Y3JlZA',
        clientDataJson: 'e30',
        attestationObject: 'oA',
        transports: ['internal'],
      );
      final submission = response.toSubmission();
      expect(submission, isNot(contains('=')));
      expect(
        TomWebAuthnRegistrationResponse.fromSubmission(submission)!.toJson(),
        response.toJson(),
      );
    });

    test(
      'an authentication response survives it too, user handle included',
      () {
        const response = TomWebAuthnAuthenticationResponse(
          id: 'Y3JlZA',
          clientDataJson: 'e30',
          authenticatorData: 'YXV0aA',
          signature: 'c2ln',
          userHandle: 'dXNlcg',
        );
        final back = TomWebAuthnAuthenticationResponse.fromSubmission(
          response.toSubmission(),
        )!;
        expect(back.toJson(), response.toJson());
        expect(back.userHandle, 'dXNlcg');
      },
    );

    test('a typed code is not a response', () {
      expect(
        TomWebAuthnAuthenticationResponse.fromSubmission('123456'),
        isNull,
      );
      expect(TomWebAuthnRegistrationResponse.fromSubmission(''), isNull);
    });
  });
}
