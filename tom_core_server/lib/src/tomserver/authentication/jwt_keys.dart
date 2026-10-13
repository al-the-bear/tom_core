/// The keys a deployment signs and verifies its tokens with.
///
/// A token is signed with one key and verified with whichever key its `kid`
/// header names. Asymmetric signing (RS256 by default, ES256 selectable)
/// separates the two: the signing key stays on the server that issues tokens,
/// and the public half verifies them anywhere — on another Tom server, in an
/// API gateway, in any JWT library that reads the JSON Web Key Set this
/// deployment publishes. HS256 remains selectable for a single service; its
/// one key both signs and verifies, so it is never published.
///
/// ## Rotation
///
/// A new key signs as soon as it is configured; the key it replaces moves to
/// the verification keys, so tokens it signed keep verifying until they
/// expire, and is then removed. [TomJwtSigning.keys] holds both, and the JSON
/// Web Key Set publishes both, so a verifier that caches the set sees the new
/// key before the old one stops verifying.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart' as jwt;
import 'package:pointycastle/export.dart' as pc;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';

/// A key or signing setting that cannot be used.
///
/// | Key | Meaning |
/// | --- | ------- |
/// | `jwt.keys.unknown_algorithm` | `jwtAlgorithm` names no supported algorithm. |
/// | `jwt.keys.unreadable_key_file` | A configured key file cannot be read or holds no key of the configured algorithm's kind. |
/// | `jwt.keys.verify_only` | A token was to be issued by a server configured with verification keys only. |
///
/// `clientThrow` is `false`: every case names this deployment's
/// configuration.
class TomJwtKeyException extends TomServerException {
  /// Creates the exception with a message [key] and [defaultUserMessage].
  TomJwtKeyException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
  }) : super(clientThrow: false);
}

/// The token signing algorithms a deployment may configure.
enum TomJwtAlgorithm {
  /// RSA PKCS#1 v1.5 with SHA-256 — the default, verified by every JWT
  /// library and gateway.
  rs256('RS256', true),

  /// ECDSA over P-256 with SHA-256 — smaller keys and signatures.
  es256('ES256', true),

  /// HMAC with SHA-256 — one shared secret signs and verifies; for a single
  /// service, and never published.
  hs256('HS256', false);

  const TomJwtAlgorithm(this.jwtName, this.isAsymmetric);

  /// The name in a token's `alg` header.
  final String jwtName;

  /// Whether signing and verifying use different keys.
  final bool isAsymmetric;

  /// The `dart_jsonwebtoken` algorithm.
  jwt.JWTAlgorithm get algorithm => jwt.JWTAlgorithm.fromName(jwtName);

  /// The algorithm named [name] (`RS256`, `ES256`, `HS256`; any case).
  ///
  /// Throws `jwt.keys.unknown_algorithm` for any other name.
  static TomJwtAlgorithm parse(String name) {
    final wanted = name.trim().toUpperCase();
    for (final algorithm in values) {
      if (algorithm.jwtName == wanted) return algorithm;
    }
    throw TomJwtKeyException(
      'jwt.keys.unknown_algorithm',
      'jwtAlgorithm "$name" is not supported; use RS256, ES256 or HS256.',
      parameters: {'algorithm': name},
    );
  }
}

/// One key a token can be verified with, under its id.
class TomJwtKey {
  TomJwtKey._(this.keyId, this.algorithm, this.verificationKey, this.jwk);

  /// The key's id — the `kid` a token signed with it carries.
  ///
  /// For an asymmetric key, the RFC 7638 thumbprint of its public JWK, so
  /// every server derives the same id from the same key without being told
  /// it. `null` for an HMAC secret, which is never named.
  final String? keyId;

  /// The algorithm the key verifies.
  final TomJwtAlgorithm algorithm;

  /// The key `dart_jsonwebtoken` verifies with: the public key, or the secret.
  final jwt.JWTKey verificationKey;

  /// The public JWK, as the JSON Web Key Set publishes it; `null` for an HMAC
  /// secret.
  final Map<String, Object?>? jwk;

  /// The public key in [pem], verifying [algorithm].
  ///
  /// Throws `jwt.keys.unreadable_key_file` when [pem] holds no public key of
  /// the algorithm's kind; [source] names where it came from.
  factory TomJwtKey.publicPem(
    String pem,
    TomJwtAlgorithm algorithm, {
    String source = 'PEM',
  }) {
    final jwt.JWTKey key;
    try {
      key = switch (algorithm) {
        TomJwtAlgorithm.rs256 => jwt.RSAPublicKey(pem),
        TomJwtAlgorithm.es256 => jwt.ECPublicKey(pem),
        // throws-outside-family: programmer error — caught just below and
        // reported as the keyed `jwt.keys.unreadable_key_file`.
        TomJwtAlgorithm.hs256 => throw ArgumentError('HS256 has no public key'),
      };
    } catch (error) {
      throw _unreadable(source, algorithm, error);
    }
    return TomJwtKey._public(key, algorithm);
  }

  /// The HMAC key [secret], verifying HS256.
  factory TomJwtKey.hmac(jwt.SecretKey secret) =>
      TomJwtKey._(null, TomJwtAlgorithm.hs256, secret, null);

  factory TomJwtKey._public(jwt.JWTKey publicKey, TomJwtAlgorithm algorithm) {
    final full = publicKey.toJWK();
    final required = algorithm == TomJwtAlgorithm.rs256
        ? {'e': full['e'], 'kty': 'RSA', 'n': full['n']}
        : {'crv': full['crv'], 'kty': 'EC', 'x': full['x'], 'y': full['y']};
    final keyId = thumbprint(required);
    return TomJwtKey._(keyId, algorithm, publicKey, {
      ...required,
      'kid': keyId,
      'use': 'sig',
      'alg': algorithm.jwtName,
    });
  }

  /// The RFC 7638 thumbprint of [requiredMembers]: the base64url SHA-256 of
  /// the members in lexicographic order, without whitespace.
  static String thumbprint(Map<String, Object?> requiredMembers) {
    final keys = requiredMembers.keys.toList()..sort();
    final canonical = jsonEncode({for (final k in keys) k: requiredMembers[k]});
    return base64Url
        .encode(sha256.convert(utf8.encode(canonical)).bytes)
        .replaceAll('=', '');
  }

  @override
  String toString() => 'TomJwtKey(${algorithm.jwtName}, kid: $keyId)';
}

/// A signing key and the public key it publishes.
class TomJwtSigningKey {
  TomJwtSigningKey._(this.signingKey, this.publicKey);

  /// The private key in [pem], signing [algorithm].
  ///
  /// Throws `jwt.keys.unreadable_key_file` when [pem] holds no private key of
  /// the algorithm's kind; [source] names where it came from.
  factory TomJwtSigningKey.privatePem(
    String pem,
    TomJwtAlgorithm algorithm, {
    String source = 'PEM',
  }) {
    try {
      switch (algorithm) {
        case TomJwtAlgorithm.rs256:
          return TomJwtSigningKey.rsa(jwt.RSAPrivateKey(pem));
        case TomJwtAlgorithm.es256:
          final private = jwt.ECPrivateKey(pem);
          final k = private.key;
          final params = k.parameters!;
          final public = jwt.ECPublicKey.raw(
            pc.ECPublicKey(params.G * k.d, params),
          );
          return TomJwtSigningKey._(
            private,
            TomJwtKey._public(public, algorithm),
          );
        case TomJwtAlgorithm.hs256:
          // throws-outside-family: programmer error — caught just below and
          // reported as the keyed `jwt.keys.unreadable_key_file`.
          throw ArgumentError('HS256 signs with a secret, not a private key');
      }
    } on TomJwtKeyException {
      rethrow;
    } catch (error) {
      throw _unreadable(source, algorithm, error);
    }
  }

  /// The RSA [private] key, signing RS256.
  factory TomJwtSigningKey.rsa(jwt.RSAPrivateKey private) {
    final k = private.key;
    final public = jwt.RSAPublicKey.raw(
      pc.RSAPublicKey(k.modulus!, k.publicExponent!),
    );
    return TomJwtSigningKey._(
      private,
      TomJwtKey._public(public, TomJwtAlgorithm.rs256),
    );
  }

  /// The key tokens are signed with.
  final jwt.JWTKey signingKey;

  /// The public half, as it verifies and is published.
  final TomJwtKey publicKey;

  /// The id signed tokens carry.
  String get keyId => publicKey.keyId!;
}

TomJwtKeyException _unreadable(
  String source,
  TomJwtAlgorithm algorithm,
  Object error,
) => TomJwtKeyException(
  'jwt.keys.unreadable_key_file',
  '$source holds no ${algorithm.jwtName} key that can be read.',
  parameters: {'source': source, 'algorithm': algorithm.jwtName},
  rootException: error,
);

/// Reads the PEM at [path], naming it in the error a missing file raises.
String readPemFile(String path, TomJwtAlgorithm algorithm) {
  try {
    return File(path.trim()).readAsStringSync();
  } catch (error) {
    throw _unreadable(path, algorithm, error);
  }
}

/// How this process signs and verifies tokens: the algorithm, the key tokens
/// are signed with, every key a token may be verified with, and the issuer
/// and audience tokens carry.
///
/// Installed by `installJwtSigning` from the server configuration. Until then
/// [current] describes the process-wide `TomJwtConfiguration` default: HS256
/// with its secret, issuer `tom` — the configuration a process that never ran
/// a server boot has.
class TomJwtSigning {
  /// Creates a signing description.
  TomJwtSigning({
    required this.algorithm,
    required this.keys,
    this.signingKeyId,
    this.canSign = true,
    this.issuer = defaultIssuer,
    this.audience,
  });

  /// The issuer a deployment that configures none writes and expects.
  static const String defaultIssuer = 'tom';

  static TomJwtSigning? _installed;

  /// The installed description, or the one implied by the process-wide
  /// `TomJwtConfiguration` default.
  static TomJwtSigning get current =>
      _installed ??
      TomJwtSigning(
        algorithm: TomJwtAlgorithm.hs256,
        keys: [
          TomJwtKey._(
            null,
            TomJwtAlgorithm.hs256,
            TomJwtConfiguration.defaultSignConfiguration.key,
            null,
          ),
        ],
      );

  /// Installs [signing] as [current].
  static void install(TomJwtSigning signing) => _installed = signing;

  /// Forgets the installed description. Test support.
  static void reset() => _installed = null;

  /// The algorithm every token is signed with and every token must name.
  final TomJwtAlgorithm algorithm;

  /// Every key a token may be verified with: the signing key's public half
  /// first, then the retired keys still verifying.
  final List<TomJwtKey> keys;

  /// The `kid` tokens are signed under; `null` for HS256.
  final String? signingKeyId;

  /// Whether this process can issue tokens, or only verify them.
  final bool canSign;

  /// The `iss` every token carries and must carry.
  final String issuer;

  /// The `aud` every token carries and must carry, or `null` for none.
  final String? audience;

  /// The key a token with header `kid` [keyId] verifies against, or `null`.
  ///
  /// HS256 has one key and no ids, so its key answers for any token.
  TomJwtKey? keyFor(String? keyId) {
    if (!algorithm.isAsymmetric) return keys.isEmpty ? null : keys.first;
    if (keyId == null) return null;
    for (final key in keys) {
      if (key.keyId == keyId) return key;
    }
    return null;
  }

  /// The JSON Web Key Set publishing every verification key; `null` for
  /// HS256, whose secret is never published.
  Map<String, Object?>? get jwks => algorithm.isAsymmetric
      ? {
          'keys': [for (final key in keys) key.jwk],
        }
      : null;

  /// Throws `jwt.keys.verify_only` unless this process can issue tokens.
  void requireSigning() {
    if (canSign) return;
    throw TomJwtKeyException(
      'jwt.keys.verify_only',
      'This server holds verification keys only and cannot issue tokens; '
          'configure jwtSigningKeyFile on the server that issues them.',
    );
  }
}
