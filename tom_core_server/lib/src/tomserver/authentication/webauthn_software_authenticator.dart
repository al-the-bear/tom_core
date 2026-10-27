/// A WebAuthn authenticator in software, for tests and bring-up **only**.
///
/// It does what a platform authenticator does — makes a P-256 key pair, answers
/// a creation request with a `none`-attestation object, signs a request with
/// the private key — so a suite can drive [TomWebAuthn2FAService] end to end
/// without a browser, a phone or a security key. Its private key lives in
/// memory and its "user verification" is a flag, so a credential made with it
/// proves nothing about anyone; never enrol one outside a test.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart' as pc;
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A software passkey: one credential, one origin.
class TomWebAuthnSoftwareAuthenticator {
  /// The origin the "browser" reports in the client data. Settable, so a test
  /// can show what a page on another origin would get signed.
  String origin;

  /// Whether the user-verified flag is set on what this authenticator returns.
  bool userVerified;

  /// Whether the signature counter moves. Platform passkeys that sync between
  /// devices report `0` every time, which the server must accept.
  bool countsSignatures;

  /// The credential id.
  final Uint8List credentialId;

  /// The signature counter.
  int signCount = 0;

  final pc.ECPrivateKey _private;
  final pc.ECPublicKey _public;

  /// Creates an authenticator with a fresh key pair.
  factory TomWebAuthnSoftwareAuthenticator({
    required String origin,
    bool userVerified = true,
    bool countsSignatures = true,
  }) {
    final random = Random.secure();
    final fortuna = pc.FortunaRandom()
      ..seed(
        pc.KeyParameter(
          Uint8List.fromList(List.generate(32, (_) => random.nextInt(256))),
        ),
      );
    final generator = pc.ECKeyGenerator()
      ..init(
        pc.ParametersWithRandom(
          pc.ECKeyGeneratorParameters(pc.ECDomainParameters('secp256r1')),
          fortuna,
        ),
      );
    final pair = generator.generateKeyPair();
    return TomWebAuthnSoftwareAuthenticator._(
      origin,
      userVerified,
      countsSignatures,
      Uint8List.fromList(List.generate(16, (_) => random.nextInt(256))),
      pair.privateKey,
      pair.publicKey,
    );
  }

  TomWebAuthnSoftwareAuthenticator._(
    this.origin,
    this.userVerified,
    this.countsSignatures,
    this.credentialId,
    this._private,
    this._public,
  );

  /// The credential id, base64url.
  String get id => TomBase64Url.encode(credentialId);

  /// Answers a creation request.
  TomWebAuthnRegistrationResponse create(TomWebAuthnCreationOptions options) {
    final clientData = _clientData('webauthn.create', options.challenge);
    final authData = BytesBuilder()
      ..add(_rpIdHash(options.rpId))
      ..addByte(_flags(attested: true))
      ..add(_uint32(signCount))
      ..add(Uint8List(16))
      ..add([credentialId.length >> 8, credentialId.length & 0xff])
      ..add(credentialId)
      ..add(_coseKey());
    final attestation = _CborWriter()
      ..map({
        'fmt': 'none',
        'attStmt': <Object, Object>{},
        'authData': authData.toBytes(),
      });
    return TomWebAuthnRegistrationResponse(
      id: id,
      clientDataJson: TomBase64Url.encode(clientData),
      attestationObject: TomBase64Url.encode(attestation.bytes),
      transports: const ['internal'],
    );
  }

  /// Answers a request, signing it with this credential.
  TomWebAuthnAuthenticationResponse get(
    TomWebAuthnRequestOptions options, {
    String? userHandle,
  }) {
    if (countsSignatures) signCount++;
    final clientData = _clientData('webauthn.get', options.challenge);
    final authData = Uint8List.fromList([
      ..._rpIdHash(options.rpId),
      _flags(attested: false),
      ..._uint32(countsSignatures ? signCount : 0),
    ]);
    final signed = Uint8List.fromList([
      ...authData,
      ...crypto.sha256.convert(clientData).bytes,
    ]);
    final signer = pc.ECDSASigner(
      pc.SHA256Digest(),
      pc.HMac(pc.SHA256Digest(), 64),
    )..init(true, pc.PrivateKeyParameter<pc.ECPrivateKey>(_private));
    final signature = signer.generateSignature(signed) as pc.ECSignature;
    return TomWebAuthnAuthenticationResponse(
      id: id,
      clientDataJson: TomBase64Url.encode(clientData),
      authenticatorData: TomBase64Url.encode(authData),
      signature: TomBase64Url.encode(_der(signature.r, signature.s)),
      userHandle: userHandle,
    );
  }

  Uint8List _clientData(String type, String challenge) => utf8.encode(
    jsonEncode({'type': type, 'challenge': challenge, 'origin': origin}),
  );

  int _flags({required bool attested}) =>
      0x01 | (userVerified ? 0x04 : 0) | (attested ? 0x40 : 0);

  static List<int> _rpIdHash(String rpId) =>
      crypto.sha256.convert(utf8.encode(rpId)).bytes;

  static List<int> _uint32(int value) => [
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];

  Uint8List _coseKey() {
    final q = _public.Q!;
    return (_CborWriter()..map({
          1: 2,
          3: TomWebAuthnAlgorithms.es256,
          -1: 1,
          -2: _fixed(q.x!.toBigInteger()!, 32),
          -3: _fixed(q.y!.toBigInteger()!, 32),
        }))
        .bytes;
  }

  static Uint8List _fixed(BigInt value, int length) {
    final out = Uint8List(length);
    var v = value;
    for (var i = length - 1; i >= 0; i--) {
      out[i] = (v & BigInt.from(0xff)).toInt();
      v = v >> 8;
    }
    return out;
  }

  static Uint8List _der(BigInt r, BigInt s) {
    List<int> integer(BigInt value) {
      var bytes = _fixed(value, 33).toList();
      while (bytes.length > 1 && bytes[0] == 0 && bytes[1] < 0x80) {
        bytes = bytes.sublist(1);
      }
      return [0x02, bytes.length, ...bytes];
    }

    final body = [...integer(r), ...integer(s)];
    return Uint8List.fromList([0x30, body.length, ...body]);
  }
}

/// The CBOR encoding a software authenticator needs: the inverse of the
/// verifier's reader for maps, integers, byte and text strings.
class _CborWriter {
  final BytesBuilder _out = BytesBuilder();

  Uint8List get bytes => _out.toBytes();

  void map(Map<Object, Object> map) {
    _head(5, map.length);
    for (final entry in map.entries) {
      _value(entry.key);
      _value(entry.value);
    }
  }

  void _value(Object value) {
    if (value is int) {
      value >= 0 ? _head(0, value) : _head(1, -1 - value);
    } else if (value is Uint8List) {
      _head(2, value.length);
      _out.add(value);
    } else if (value is String) {
      final encoded = utf8.encode(value);
      _head(3, encoded.length);
      _out.add(encoded);
    } else if (value is Map<Object, Object>) {
      map(value);
    } else {
      // throws-outside-family: programmer error — the authenticator encodes
      // only the values it builds itself, so another type is a bug here.
      throw ArgumentError.value(value, 'value', 'not encodable');
    }
  }

  void _head(int major, int argument) {
    final type = major << 5;
    if (argument < 24) {
      _out.addByte(type | argument);
    } else if (argument < 0x100) {
      _out
        ..addByte(type | 24)
        ..addByte(argument);
    } else if (argument < 0x10000) {
      _out
        ..addByte(type | 25)
        ..add([argument >> 8, argument & 0xff]);
    } else {
      _out
        ..addByte(type | 26)
        ..add([
          (argument >> 24) & 0xff,
          (argument >> 16) & 0xff,
          (argument >> 8) & 0xff,
          argument & 0xff,
        ]);
    }
  }
}
