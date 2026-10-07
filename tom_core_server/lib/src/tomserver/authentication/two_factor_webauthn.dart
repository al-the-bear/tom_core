/// WebAuthn (passkey) as a second factor: the strongest of the common ones.
///
/// A passkey is a key pair made by an authenticator — the phone's secure
/// enclave, a security key, the laptop's TPM — whose private half never leaves
/// it. Enrolment stores the public half; a challenge asks the authenticator to
/// sign a fresh random value together with the origin it is shown on. A
/// phishing site cannot obtain a usable answer, because the browser writes the
/// *real* origin into what is signed and the server refuses any other.
///
/// ## What is verified
///
/// Registration and assertion follow WebAuthn Level 2 §7.1 and §7.2:
///
/// - the client data names the ceremony (`webauthn.create` / `webauthn.get`),
///   carries exactly the challenge this server issued, and an origin in
///   [TomWebAuthn2FAService.globalSettingAllowedOrigins];
/// - the authenticator data's RP id hash is SHA-256 of the configured RP id,
///   the user-present flag is set, and the user-verified flag is set when
///   verification is [TomWebAuthnUserVerification.required];
/// - an assertion's signature verifies, over the authenticator data followed by
///   SHA-256 of the client data, against the stored public key — ES256 (P-256)
///   or RS256;
/// - an assertion's signature counter is greater than the stored one whenever
///   either is non-zero. A counter that does not move up means two copies of
///   the credential exist, and the login is refused.
///
/// ## What is deliberately not verified: attestation
///
/// The creation options request attestation `none`, and an attestation
/// statement that arrives anyway is not checked. Attestation answers *which
/// model of authenticator* made the credential — useful to a deployment that
/// admits only certified hardware keys, and a certificate-chain trust store to
/// maintain for everyone else. The server trusts what the credential signs,
/// never what it claims to be, which is the trust model every consumer
/// passkey provider expects.
///
/// ## Configuration
///
/// Offered only once [TomWebAuthn2FAService.globalSettingRelyingPartyId] is
/// set: a credential is bound to its RP id forever, so a guessed one would make
/// every passkey enrolled under it unusable after the guess is corrected.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart' as pc;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import 'two_factor.dart';
import 'two_factor_enrolment.dart';

// =============================================================================
// ADAPTOR
// =============================================================================

/// The passkey second factor, registered under `'webauthn'`.
@tomReflector
@Tom2FAAdaptor(TomWebAuthn2FAService.mechanismType)
class TomWebAuthn2FAService
    implements Tom2FAService, Tom2FAEnrolmentSupport, Tom2FAPrerequisite {
  /// The mechanism key.
  static const String mechanismType = 'webauthn';

  /// The `clientData` key the creation or request options travel under.
  static const String optionsKey = 'publicKey';

  /// The key the issued challenge is kept under in the encrypted half.
  static const String challengeKey = 'challenge';

  /// The keys of an enrolment's `secretData`.
  static const String credentialIdKey = 'credentialId';

  /// The COSE public key, base64url.
  static const String publicKeyKey = 'publicKey';

  /// The last signature counter seen.
  static const String signCountKey = 'signCount';

  /// The user handle the credential was made for, base64url.
  static const String userHandleKey = 'userHandle';

  /// The relying party id — the registrable domain passkeys are bound to, such
  /// as `example.com`. Empty means the mechanism is not offered.
  static String globalSettingRelyingPartyId = '';

  /// The relying party's display name; the context's application when empty.
  static String globalSettingRelyingPartyName = '';

  /// The origins a ceremony may run on. Empty means `https://<RP id>` alone.
  ///
  /// List every origin the login page is served from, including a development
  /// one such as `http://localhost:8080` (browsers allow WebAuthn on
  /// `localhost` without TLS), and the `android:apk-key-hash:…` origin of an
  /// Android app.
  static Set<String> globalSettingAllowedOrigins = {};

  /// The user-verification requirement.
  static TomWebAuthnUserVerification globalSettingUserVerification =
      TomWebAuthnUserVerification.preferred;

  /// Submissions one challenge tolerates.
  static int globalSettingAttemptsAllowed = 3;

  /// How long a challenge stays answerable.
  static Duration globalSettingChallengeValidity = const Duration(minutes: 5);

  /// Confirmations one enrolment offer tolerates.
  static int globalSettingEnrolmentAttemptsAllowed = 3;

  /// How long an enrolment offer stays answerable.
  static Duration globalSettingEnrolmentValidity = const Duration(minutes: 10);

  static final Tom2FAMethodDescriptor _descriptor =
      Tom2FAMethodDescriptor.scoped(mechanismType);

  /// Constructed by [Tom2FARegistry] through reflection.
  TomWebAuthn2FAService();

  @override
  Tom2FAMethodDescriptor get descriptor => _descriptor;

  @override
  String? get unmetPrerequisite => globalSettingRelyingPartyId.trim().isEmpty
      ? 'TomWebAuthn2FAService.globalSettingRelyingPartyId is not set, so no '
            'passkey can be bound to this deployment'
      : null;

  /// The origins a ceremony may run on.
  static Set<String> get allowedOrigins => globalSettingAllowedOrigins.isEmpty
      ? {'https://$globalSettingRelyingPartyId'}
      : globalSettingAllowedOrigins;

  // ---------------------------------------------------------------------------
  // CHALLENGE
  // ---------------------------------------------------------------------------

  @override
  Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context) async {
    final credentials = await _credentialsOf(context);
    if (credentials.isEmpty) {
      throw TomLoginException(
        'login.error.2fa.not-enrolled',
        'No passkey is enrolled for this account',
        reason: TomLoginFailure.secondFactorRequired,
      );
    }
    final challenge = _newChallenge();
    final options = TomWebAuthnRequestOptions(
      challenge: challenge,
      rpId: globalSettingRelyingPartyId,
      allowCredentialIds: [
        for (final credential in credentials)
          credential.secretData[credentialIdKey] as String,
      ],
      timeoutMs: globalSettingChallengeValidity.inMilliseconds,
      userVerification: globalSettingUserVerification,
    );
    return Tom2FAChallengeSpec(
      clientData: {optionsKey: options.toJson()},
      verificationData: {challengeKey: challenge},
      attemptsAllowed: globalSettingAttemptsAllowed,
      validity: globalSettingChallengeValidity,
    );
  }

  @override
  Future<bool> verifySubmission(
    Tom2FAContext context,
    Tom2FASubmission submission,
  ) async {
    final response = TomWebAuthnAuthenticationResponse.fromSubmission(
      submission.submitted,
    );
    final challenge = submission.verificationData[challengeKey];
    if (response == null || challenge is! String) return false;

    final enrolment = (await _credentialsOf(
      context,
    )).where((e) => e.secretData[credentialIdKey] == response.id).firstOrNull;
    if (enrolment == null) return false;

    final verified = TomWebAuthnVerifier.verifyAssertion(
      response: response,
      expectedChallenge: challenge,
      rpId: globalSettingRelyingPartyId,
      allowedOrigins: allowedOrigins,
      userVerification: globalSettingUserVerification,
      publicKey: enrolment.secretData[publicKeyKey] as String? ?? '',
      storedSignCount: _int(enrolment.secretData[signCountKey]),
      expectedUserHandle: enrolment.secretData[userHandleKey] as String?,
    );
    if (verified == null) return false;

    // The counter is the clone detector, so it has to move with every login.
    // A store that cannot record it is installed by the deployment, and a
    // login refused for a write the user cannot see would be worse than one
    // that succeeds with the counter one step stale.
    final store = Tom2FAEnrolmentStore.resolve();
    if (store != null) {
      await store.store(
        context,
        Tom2FAEnrolment(
          type: enrolment.type,
          enrolmentId: enrolment.enrolmentId,
          hint: enrolment.hint,
          enrolledAt: enrolment.enrolledAt,
          isPrimary: enrolment.isPrimary,
          secretData: {
            ...enrolment.secretData,
            signCountKey: verified.signCount,
          },
        ),
      );
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // ENROLMENT
  // ---------------------------------------------------------------------------

  @override
  Future<Tom2FAEnrolmentOffer> beginEnrolment(Tom2FAContext context) async {
    final challenge = _newChallenge();
    final existing = await _credentialsOf(context);
    final principal = context.principal;
    final options = TomWebAuthnCreationOptions(
      rpId: globalSettingRelyingPartyId,
      rpName: globalSettingRelyingPartyName.isNotEmpty
          ? globalSettingRelyingPartyName
          : (context.application.isNotEmpty
                ? context.application
                : globalSettingRelyingPartyId),
      userId: userHandleOf(context),
      userName: principal.username,
      userDisplayName:
          '${principal.user.firstname} ${principal.user.lastname}'
              .trim()
              .isEmpty
          ? principal.username
          : '${principal.user.firstname} ${principal.user.lastname}'.trim(),
      challenge: challenge,
      timeoutMs: globalSettingEnrolmentValidity.inMilliseconds,
      userVerification: globalSettingUserVerification,
      excludeCredentialIds: [
        for (final credential in existing)
          credential.secretData[credentialIdKey] as String,
      ],
    );
    return Tom2FAEnrolmentOffer(
      type: mechanismType,
      clientData: {optionsKey: options.toJson()},
      enrolmentData: {challengeKey: challenge},
      attemptsAllowed: globalSettingEnrolmentAttemptsAllowed,
      validity: globalSettingEnrolmentValidity,
    );
  }

  @override
  Future<Tom2FAEnrolment> confirmEnrolment(
    Tom2FAContext context,
    Tom2FAEnrolmentOffer offer,
    String submitted,
  ) async {
    final challenge = offer.enrolmentData[challengeKey];
    if (challenge is! String || challenge.isEmpty) {
      throw TomLoginException(
        'login.error.2fa.enrolment-offer-invalid',
        'This enrolment can no longer be completed; please start again',
        reason: TomLoginFailure.secondFactorInvalid,
      );
    }
    final response = TomWebAuthnRegistrationResponse.fromSubmission(submitted);
    final registered = response == null
        ? null
        : TomWebAuthnVerifier.verifyRegistration(
            response: response,
            expectedChallenge: challenge,
            rpId: globalSettingRelyingPartyId,
            allowedOrigins: allowedOrigins,
            userVerification: globalSettingUserVerification,
          );
    if (registered == null) {
      throw TomLoginException(
        'login.error.2fa.webauthn-registration-invalid',
        'The passkey could not be verified; please try again',
        reason: TomLoginFailure.secondFactorInvalid,
      );
    }
    return Tom2FAEnrolment(
      type: mechanismType,
      // One enrolment per credential, so a user may hold a passkey on each
      // device; the id keeps re-registering one credential an upsert.
      enrolmentId: '$mechanismType:${registered.credentialId}',
      secretData: {
        credentialIdKey: registered.credentialId,
        publicKeyKey: registered.publicKey,
        signCountKey: registered.signCount,
        userHandleKey: userHandleOf(context),
      },
    );
  }

  /// The opaque user handle a credential is made for: SHA-256 of the
  /// principal key, base64url. Stable per user, and never a name, as the
  /// specification requires — an authenticator may show it to anyone holding
  /// the device.
  static String userHandleOf(Tom2FAContext context) => TomBase64Url.encode(
    crypto.sha256
        .convert(utf8.encode(Tom2FAEnrolmentStore.principalKeyOf(context)))
        .bytes,
  );

  Future<List<Tom2FAEnrolment>> _credentialsOf(Tom2FAContext context) async {
    final store = Tom2FAEnrolmentStore.resolve();
    if (store == null) return const [];
    return [
      for (final enrolment in await store.enrolmentsFor(context))
        if (enrolment.type == mechanismType &&
            enrolment.secretData[credentialIdKey] is String &&
            enrolment.secretData[publicKeyKey] is String)
          enrolment,
    ];
  }

  static String _newChallenge() =>
      TomBase64Url.encode(RsaKeyHelper.getSecureRandom().nextBytes(32));

  static int _int(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;
}

// =============================================================================
// VERIFICATION
// =============================================================================

/// A credential that registration verified.
class TomWebAuthnRegisteredCredential {
  /// The credential id, base64url.
  final String credentialId;

  /// The COSE public key, base64url.
  final String publicKey;

  /// The authenticator's signature counter at registration.
  final int signCount;

  /// Creates the value.
  const TomWebAuthnRegisteredCredential({
    required this.credentialId,
    required this.publicKey,
    required this.signCount,
  });
}

/// An assertion that verified.
class TomWebAuthnVerifiedAssertion {
  /// The authenticator's new signature counter.
  final int signCount;

  /// Whether the authenticator verified the user (PIN or biometric).
  final bool userVerified;

  /// Creates the value.
  const TomWebAuthnVerifiedAssertion({
    required this.signCount,
    required this.userVerified,
  });
}

/// The WebAuthn ceremony checks, as pure functions over the wire types.
///
/// Each answers `null` for anything that fails, rather than throwing: to the
/// caller every failure is the same "this is not a valid passkey answer", and
/// distinguishing them would only tell an attacker which check to aim at.
abstract final class TomWebAuthnVerifier {
  static const int _flagUserPresent = 0x01;
  static const int _flagUserVerified = 0x04;
  static const int _flagAttestedData = 0x40;

  /// Verifies a registration response; the credential to store, or `null`.
  static TomWebAuthnRegisteredCredential? verifyRegistration({
    required TomWebAuthnRegistrationResponse response,
    required String expectedChallenge,
    required String rpId,
    required Set<String> allowedOrigins,
    required TomWebAuthnUserVerification userVerification,
  }) {
    try {
      if (!_clientDataValid(
        response.clientDataJson,
        'webauthn.create',
        expectedChallenge,
        allowedOrigins,
      )) {
        return null;
      }
      final attestationBytes = TomBase64Url.decode(response.attestationObject);
      if (attestationBytes == null) return null;
      final attestation = _Cbor(attestationBytes).read();
      if (attestation is! Map) return null;
      final authData = attestation['authData'];
      if (authData is! Uint8List) return null;

      final parsed = _AuthenticatorData.parse(authData);
      if (parsed == null ||
          !_authDataValid(parsed, rpId, userVerification) ||
          parsed.flags & _flagAttestedData == 0) {
        return null;
      }
      final credentialId = parsed.credentialId;
      final coseKey = parsed.credentialPublicKey;
      if (credentialId == null || coseKey == null) return null;
      if (TomBase64Url.encode(credentialId) !=
          TomBase64Url.encode(TomBase64Url.decode(response.id) ?? [])) {
        return null;
      }
      // A key this server could never verify a signature with is refused now,
      // not at the first login.
      if (_CoseKey.parse(coseKey) == null) return null;
      return TomWebAuthnRegisteredCredential(
        credentialId: TomBase64Url.encode(credentialId),
        publicKey: TomBase64Url.encode(coseKey),
        signCount: parsed.signCount,
      );
    } on Object {
      // Malformed CBOR, truncated data: not a valid answer.
      return null;
    }
  }

  /// Verifies an authentication response against a stored credential; the new
  /// counter, or `null`.
  static TomWebAuthnVerifiedAssertion? verifyAssertion({
    required TomWebAuthnAuthenticationResponse response,
    required String expectedChallenge,
    required String rpId,
    required Set<String> allowedOrigins,
    required TomWebAuthnUserVerification userVerification,
    required String publicKey,
    required int storedSignCount,
    String? expectedUserHandle,
  }) {
    try {
      if (!_clientDataValid(
        response.clientDataJson,
        'webauthn.get',
        expectedChallenge,
        allowedOrigins,
      )) {
        return null;
      }
      if (expectedUserHandle != null &&
          response.userHandle != null &&
          response.userHandle != expectedUserHandle) {
        return null;
      }
      final authData = TomBase64Url.decode(response.authenticatorData);
      final clientData = TomBase64Url.decode(response.clientDataJson);
      final signature = TomBase64Url.decode(response.signature);
      final coseBytes = TomBase64Url.decode(publicKey);
      if (authData == null ||
          clientData == null ||
          signature == null ||
          coseBytes == null) {
        return null;
      }
      final parsed = _AuthenticatorData.parse(authData);
      if (parsed == null || !_authDataValid(parsed, rpId, userVerification)) {
        return null;
      }
      final key = _CoseKey.parse(coseBytes);
      if (key == null) return null;
      final signed = Uint8List.fromList([
        ...authData,
        ...crypto.sha256.convert(clientData).bytes,
      ]);
      if (!key.verify(signed, signature)) return null;

      // WebAuthn Level 2 §7.2 step 21: a counter in use must strictly increase.
      if ((parsed.signCount != 0 || storedSignCount != 0) &&
          parsed.signCount <= storedSignCount) {
        return null;
      }
      return TomWebAuthnVerifiedAssertion(
        signCount: parsed.signCount,
        userVerified: parsed.flags & _flagUserVerified != 0,
      );
    } on Object {
      return null;
    }
  }

  static bool _clientDataValid(
    String clientDataJson,
    String type,
    String expectedChallenge,
    Set<String> allowedOrigins,
  ) {
    final bytes = TomBase64Url.decode(clientDataJson);
    if (bytes == null) return false;
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map) return false;
    if (data['type'] != type) return false;
    final challenge = data['challenge'];
    if (challenge is! String) return false;
    final presented = TomBase64Url.decode(challenge);
    final expected = TomBase64Url.decode(expectedChallenge);
    if (presented == null || expected == null) return false;
    if (!_constantTimeEquals(presented, expected)) return false;
    return allowedOrigins.contains(data['origin']);
  }

  static bool _authDataValid(
    _AuthenticatorData data,
    String rpId,
    TomWebAuthnUserVerification userVerification,
  ) {
    final expected = crypto.sha256.convert(utf8.encode(rpId)).bytes;
    if (!_constantTimeEquals(data.rpIdHash, expected)) return false;
    if (data.flags & _flagUserPresent == 0) return false;
    if (userVerification == TomWebAuthnUserVerification.required &&
        data.flags & _flagUserVerified == 0) {
      return false;
    }
    return true;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}

// =============================================================================
// AUTHENTICATOR DATA, COSE, CBOR
// =============================================================================

class _AuthenticatorData {
  final Uint8List rpIdHash;
  final int flags;
  final int signCount;
  final Uint8List? credentialId;
  final Uint8List? credentialPublicKey;

  _AuthenticatorData(
    this.rpIdHash,
    this.flags,
    this.signCount,
    this.credentialId,
    this.credentialPublicKey,
  );

  static _AuthenticatorData? parse(Uint8List data) {
    if (data.length < 37) return null;
    final view = ByteData.sublistView(data);
    final flags = data[32];
    final signCount = view.getUint32(33);
    Uint8List? credentialId;
    Uint8List? publicKey;
    if (flags & 0x40 != 0) {
      // 16 bytes of AAGUID, a two-byte length, the id, then one CBOR value.
      if (data.length < 55) return null;
      final idLength = view.getUint16(53);
      final keyStart = 55 + idLength;
      if (data.length < keyStart) return null;
      credentialId = data.sublist(55, keyStart);
      final reader = _Cbor(data, keyStart)..read();
      publicKey = data.sublist(keyStart, reader.offset);
    }
    return _AuthenticatorData(
      data.sublist(0, 32),
      flags,
      signCount,
      credentialId,
      publicKey,
    );
  }
}

abstract class _CoseKey {
  bool verify(Uint8List message, Uint8List signature);

  static _CoseKey? parse(Uint8List bytes) {
    final key = _Cbor(bytes).read();
    if (key is! Map) return null;
    final kty = key[1];
    final alg = key[3];
    if (kty == 2 && alg == TomWebAuthnAlgorithms.es256 && key[-1] == 1) {
      final x = key[-2];
      final y = key[-3];
      if (x is! Uint8List || y is! Uint8List) return null;
      if (x.length != 32 || y.length != 32) return null;
      return _Es256Key(_unsigned(x), _unsigned(y));
    }
    if (kty == 3 && alg == TomWebAuthnAlgorithms.rs256) {
      final n = key[-1];
      final e = key[-2];
      if (n is! Uint8List || e is! Uint8List) return null;
      return _Rs256Key(_unsigned(n), _unsigned(e));
    }
    return null;
  }

  static BigInt _unsigned(List<int> bytes) {
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = (value << 8) | BigInt.from(byte);
    }
    return value;
  }
}

class _Es256Key extends _CoseKey {
  final BigInt x;
  final BigInt y;

  _Es256Key(this.x, this.y);

  @override
  bool verify(Uint8List message, Uint8List signature) {
    final rs = _derSignature(signature);
    if (rs == null) return false;
    final domain = pc.ECDomainParameters('secp256r1');
    final point = domain.curve.createPoint(x, y);
    final signer = pc.ECDSASigner(pc.SHA256Digest())
      ..init(
        false,
        pc.PublicKeyParameter<pc.ECPublicKey>(pc.ECPublicKey(point, domain)),
      );
    return signer.verifySignature(message, pc.ECSignature(rs.$1, rs.$2));
  }

  /// `SEQUENCE { INTEGER r, INTEGER s }`, the form WebAuthn signatures take.
  static (BigInt, BigInt)? _derSignature(Uint8List der) {
    var offset = 0;
    int? length() {
      if (offset >= der.length) return null;
      var first = der[offset++];
      if (first < 0x80) return first;
      final count = first & 0x7f;
      if (count == 0 || count > 2 || offset + count > der.length) return null;
      var value = 0;
      for (var i = 0; i < count; i++) {
        value = (value << 8) | der[offset++];
      }
      return value;
    }

    BigInt? integer() {
      if (offset >= der.length || der[offset++] != 0x02) return null;
      final size = length();
      if (size == null || offset + size > der.length) return null;
      final value = _CoseKey._unsigned(der.sublist(offset, offset + size));
      offset += size;
      return value;
    }

    if (der.isEmpty || der[offset++] != 0x30) return null;
    if (length() == null) return null;
    final r = integer();
    final s = integer();
    if (r == null || s == null) return null;
    return (r, s);
  }
}

class _Rs256Key extends _CoseKey {
  final BigInt n;
  final BigInt e;

  _Rs256Key(this.n, this.e);

  @override
  bool verify(Uint8List message, Uint8List signature) {
    final signer = pc.RSASigner(pc.SHA256Digest(), '0609608648016503040201')
      ..init(
        false,
        pc.PublicKeyParameter<pc.RSAPublicKey>(pc.RSAPublicKey(n, e)),
      );
    try {
      return signer.verifySignature(message, pc.RSASignature(signature));
    } on ArgumentError {
      return false;
    }
  }
}

/// A reader for the CBOR subset WebAuthn uses: integers, byte and text
/// strings, arrays, maps and the simple values, all definite-length.
class _Cbor {
  final Uint8List _bytes;
  int offset;

  _Cbor(this._bytes, [this.offset = 0]);

  Object? read() {
    final initial = _byte();
    final major = initial >> 5;
    final info = initial & 0x1f;
    switch (major) {
      case 0:
        return _argument(info);
      case 1:
        return -1 - _argument(info);
      case 2:
        return _take(_argument(info));
      case 3:
        return utf8.decode(_take(_argument(info)));
      case 4:
        final count = _argument(info);
        return [for (var i = 0; i < count; i++) read()];
      case 5:
        final count = _argument(info);
        final map = <Object?, Object?>{};
        for (var i = 0; i < count; i++) {
          final key = read();
          map[key] = read();
        }
        return map;
      case 7:
        if (info == 20) return false;
        if (info == 21) return true;
        if (info == 22 || info == 23) return null;
        // throws-outside-family: parse contract — the CBOR reader signals malformed
        // input as Dart's FormatException, and its only caller, TomWebAuthnVerifier,
        // catches it and answers null.
        throw const FormatException('unsupported CBOR simple value');
      default:
        // throws-outside-family: parse contract — as above.
        throw const FormatException('unsupported CBOR major type');
    }
  }

  int _byte() {
    if (offset >= _bytes.length) {
      // throws-outside-family: parse contract — as above.
      throw const FormatException('truncated CBOR');
    }
    return _bytes[offset++];
  }

  int _argument(int info) {
    if (info < 24) return info;
    final size = switch (info) {
      24 => 1,
      25 => 2,
      26 => 4,
      27 => 8,
      // throws-outside-family: parse contract — as above.
      _ => throw const FormatException('indefinite CBOR length'),
    };
    var value = 0;
    for (var i = 0; i < size; i++) {
      value = (value << 8) | _byte();
    }
    return value;
  }

  Uint8List _take(int count) {
    if (count < 0 || offset + count > _bytes.length) {
      // throws-outside-family: parse contract — as above.
      throw const FormatException('truncated CBOR');
    }
    final slice = _bytes.sublist(offset, offset + count);
    offset += count;
    return slice;
  }
}
