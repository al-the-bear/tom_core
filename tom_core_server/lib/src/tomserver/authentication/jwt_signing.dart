/// Turns a server's configured JWT settings into the process-wide token
/// signing, verifies inbound bearer tokens against it, and refuses to hand a
/// deployment the framework's published sample keys outside development.
///
/// [installJwtSigning] reads the configuration; [verifyBearerToken] is the
/// inbound check; the keys themselves are `jwt_keys.dart`'s, and the JSON Web
/// Key Set that publishes them is `jwks_endpoint.dart`'s.
library;

import 'dart:convert';
import 'dart:math';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart' as jwt;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../configuration/base_server_configuration.dart';
import '../configuration/runtime_environment.dart';
import '../little_things/server_exception.dart';
import 'jwt_keys.dart';

/// A server would have signed tokens with key material it did not configure.
///
/// Raised by [installJwtSigning] when one or more of the JWT configuration
/// fields is unset outside a development or test environment. `parameters`
/// carries `fields`, the comma-separated names of the fields that fell back, so
/// a handler can report them without parsing the message.
///
/// [clientThrow] is `false`: the message names configuration fields of this
/// deployment, which is operator-facing detail and no business of a caller.
/// Nothing is expected to catch this — it is raised during boot, before a
/// socket is bound, precisely so that the failure is a server that did not
/// start rather than a server that started insecurely.
class TomSigningKeyException extends TomServerException {
  /// Creates the refusal for the unconfigured [fields].
  TomSigningKeyException(List<String> fields)
    : super(
        'jwt.signing.key.unconfigured',
        'The server would sign tokens with the framework\'s bundled sample '
            'keys, which are published in the tom_crypto sources and therefore '
            'secret from nobody. Configure ${fields.join(', ')} — as '
            'environment variables, ${fields.map(_environmentNameOf).join(', ')} '
            '— or run under a development or test environment.',
        parameters: {'fields': fields.join(', ')},
        clientThrow: false,
      );
}

/// Spells [fieldName] the way an environment variable naming it is written.
///
/// The inverse of `TomArgs.fieldNameOf`, used only to make the refusal
/// actionable: an operator reads the message in a deployment's log, where the
/// variable name is what they can act on and the Dart field name is not.
String _environmentNameOf(String fieldName) => fieldName
    .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}')
    .toUpperCase();

/// Returns [value] when it holds something, or null when it is absent or blank.
///
/// A blank value is treated as absent because that is what an unfilled variable
/// produces: `JWT_SHARED_SECRET_KEY=` in a `.env` file yields the empty string,
/// and an empty HMAC secret is not a secret. Accepting it would let the guard
/// below pass on exactly the mistake it exists to catch.
String? _configured(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Builds this process's token signing from [configuration], installs it —
/// as [TomJwtSigning.current] and as
/// [TomJwtConfiguration.defaultSignConfiguration] — and returns the latter.
///
/// ## What is read
///
/// - **The algorithm**, `jwtAlgorithm`: RS256 when unset, ES256 or HS256.
/// - **The signing key.** RS256/ES256 read the private key from the PEM file
///   at `jwtSigningKeyFile`; its id (`kid`) is the RFC 7638 thumbprint of its
///   public key, so every server derives the same id from the same key. HS256
///   signs with `jwtSharedSecretKey`.
/// - **The retired keys**, `jwtVerificationKeyFiles`: public keys that still
///   verify. Rotating means configuring the new private key and moving the old
///   public key here until the tokens it signed have expired. A server with
///   verification keys and no signing key only verifies, and refuses to issue
///   ([TomJwtSigning.requireSigning]).
/// - **The issuer and audience**, `jwtIssuer` (`tom` when unset) and
///   `jwtAudience` (none when unset): written into every token and required of
///   every token verified.
/// - **The payload-encryption pair**, `jwtRsaPrivKey` / `jwtRsaPubKey`.
///
/// ## The refusal
///
/// Key material left unset falls back to the framework's bundled sample keys —
/// the RSA pair for RS256, the passphrase for HS256 — and the result is marked
/// `isDummy`. In a development or test environment that is a warning; anywhere
/// else it is a [TomSigningKeyException] naming the unset fields, and nothing
/// is installed. ES256 has no sample key, so an unconfigured ES256 server is
/// refused in every environment.
///
/// ## Where this belongs in a boot
///
/// After the configuration is constructed and the runtime environment is
/// selected — it reads both — and before anything mints or verifies a token.
///
/// ```dart
/// TomRuntime.setCurrentEnvironment(Platform.environment['env'], 'prod');
/// final configuration = MyServerConfiguration(args);
/// installJwtSigning(configuration);
/// TomServer(configuration).start();
/// ```
///
/// Two servers that must trust each other's tokens — an auth server that issues
/// and an application server that verifies — agree on the issuer and audience;
/// the application server lists the auth server's public key in
/// `jwtVerificationKeyFiles` (or, with HS256, shares `jwtSharedSecretKey`).
TomJwtConfiguration installJwtSigning(
  TomBaseServerConfiguration configuration,
) {
  final unconfigured = <String>[];
  final algorithm = TomJwtAlgorithm.parse(
    _configured(configuration.jwtAlgorithm) ?? 'RS256',
  );

  final privPem = _configured(configuration.jwtRsaPrivKey);
  if (privPem == null) unconfigured.add('jwtRsaPrivKey');
  final pubPem = _configured(configuration.jwtRsaPubKey);
  if (pubPem == null) unconfigured.add('jwtRsaPubKey');

  jwt.JWTKey signingKey;
  String? signingKeyId;
  var canSign = true;
  final keys = <TomJwtKey>[];

  if (algorithm == TomJwtAlgorithm.hs256) {
    final secret = _configured(configuration.jwtSharedSecretKey);
    if (secret == null) unconfigured.add('jwtSharedSecretKey');
    final key = secret == null
        ? TomJwtConfiguration.hmacKey
        : jwt.SecretKey(secret);
    signingKey = key;
    keys.add(TomJwtKey.hmac(key));
  } else {
    final retired = [
      for (final path
          in (_configured(configuration.jwtVerificationKeyFiles) ?? '')
              .split(',')
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty))
        TomJwtKey.publicPem(
          readPemFile(path, algorithm),
          algorithm,
          source: path,
        ),
    ];
    final signingFile = _configured(configuration.jwtSigningKeyFile);
    TomJwtSigningKey? signing;
    if (signingFile != null) {
      signing = TomJwtSigningKey.privatePem(
        readPemFile(signingFile, algorithm),
        algorithm,
        source: signingFile,
      );
    } else if (retired.isEmpty) {
      unconfigured.add('jwtSigningKeyFile');
      if (algorithm == TomJwtAlgorithm.es256) {
        // No sample EC key ships, so there is nothing to fall back to.
        throw TomSigningKeyException(unconfigured);
      }
      signing = TomJwtSigningKey.rsa(
        jwt.RSAPrivateKey.raw(TomJwtConfiguration.rsaPrivKey),
      );
    }
    if (signing != null) {
      signingKey = signing.signingKey;
      signingKeyId = signing.keyId;
      keys.add(signing.publicKey);
    } else {
      // Verify-only: nothing here may sign. A random secret under an
      // asymmetric algorithm makes any attempt fail loudly rather than mint a
      // token with a key somebody else holds.
      canSign = false;
      signingKey = jwt.SecretKey(
        base64Url.encode(List.generate(32, (_) => _random.nextInt(256))),
      );
    }
    for (final key in retired) {
      if (!keys.any((k) => k.keyId == key.keyId)) keys.add(key);
    }
  }

  if (unconfigured.isNotEmpty) {
    if (!isDevelopmentOrTestRuntime()) {
      throw TomSigningKeyException(unconfigured);
    }
    tomLog.warn(
      'JWT signing falls back to the framework\'s bundled sample keys for '
      '${unconfigured.join(', ')}. Those keys are published in the tom_crypto '
      'sources; this is permitted here only because the runtime environment is '
      'a development or test one.',
    );
  }

  final installed = TomJwtConfiguration(
    signingKey,
    algorithm.algorithm,
    privPem == null
        ? TomJwtConfiguration.rsaPrivKey
        : RsaKeyHelper.parsePrivateKeyFromPem(privPem),
    pubPem == null
        ? TomJwtConfiguration.rsaPubKey
        : RsaKeyHelper.parsePublicKeyFromPem(pubPem),
    unconfigured.isNotEmpty,
  )..keyId = signingKeyId;
  TomJwtConfiguration.defaultSignConfiguration = installed;
  TomJwtSigning.install(
    TomJwtSigning(
      algorithm: algorithm,
      keys: keys,
      signingKeyId: signingKeyId,
      canSign: canSign,
      issuer:
          _configured(configuration.jwtIssuer) ?? TomJwtSigning.defaultIssuer,
      audience: _configured(configuration.jwtAudience),
    ),
  );
  return installed;
}

final Random _random = Random.secure();

/// The decoded header of [token]; throws a [FormatException] when it has
/// none that decodes to a JSON object.
Map<String, Object?> _headerOf(String token) {
  final encoded = token.split('.').first;
  final padded = encoded.padRight((encoded.length + 3) ~/ 4 * 4, '=');
  final decoded = jsonDecode(utf8.decode(base64Url.decode(padded)));
  if (decoded is! Map<String, Object?>) {
    // throws-outside-family: parse contract — the caller treats any decoding
    // failure of a presented token alike, as a token this deployment did not
    // issue, and logs only its first line.
    throw const FormatException('the token header is not a JSON object');
  }
  return decoded;
}

/// [error]'s reason, with the part that may quote the token it failed on cut
/// off.
///
/// `dart_jsonwebtoken` raises fixed strings for everything it anticipates
/// (`invalid signature`, `not a jwt`, `invalid header`), and wraps everything
/// else in a `JWTUndefinedException` whose message is the underlying
/// exception's `toString()`. That one path is the leak: a `FormatException`
/// from the base64 decoder prints the input it choked on, so interpolating the
/// message whole writes a slice of the presented credential into the log — and
/// a token this deployment cannot read is very often a live credential
/// somewhere else.
///
/// A `FormatException` puts its own text first and the quoted source on the
/// lines after it, so the first line is the reason and nothing but. That is the
/// rule here, and `test/server_test.dart` holds the battery that falsifies it:
/// a set of malformed tokens, and the requirement that no line the module
/// writes contains any of them.
String _reasonWithoutTheToken(Object error) {
  final text = error is jwt.JWTException ? error.message : error.toString();
  final firstLine = text.split('\n').first.trim();
  return firstLine.isEmpty ? error.runtimeType.toString() : firstLine;
}

/// Verifies [token]'s signature against the installed signing configuration and
/// returns it decoded, or `null` when it is not a token this deployment issued.
///
/// ## Why this exists at all
///
/// [TomClientJwtToken] *decodes*: it splits the token, base64-decodes the
/// payload and decrypts the `encrypted` section, and at no point consults the
/// signature. That is right for the client half, which holds no verifying key
/// and has nothing to gain from lying to itself. It is wrong for the inbound
/// server path, where the payload is whatever the caller last wrote in it —
/// and everything the request is then judged by, the [TomPrincipal] included,
/// is reconstructed from that payload.
///
/// The signature is the only thing that distinguishes a token this server
/// minted from a token a client typed. This function is where that is checked,
/// and [extractAuthentication] is the one call site that matters.
///
/// ## Why here and not in the value class
///
/// Verifying inside [TomClientJwtToken]'s constructor would be the tighter
/// guarantee — no code path could hold an unverified token — but the same class
/// runs in Flutter clients that have no verifying key, so it would need an
/// opt-out, and an opt-out is the hole again with a flag in front of it. The
/// check therefore lives on the server, next to the configuration that installs
/// the key it checks against.
///
/// ## What is checked
///
/// **Whose token it is**, against [TomJwtSigning.current]:
///
/// - the `alg` header must be this deployment's algorithm — never taken from
///   the token, which could otherwise ask for an RS256 public key to be
///   checked as an HMAC secret;
/// - the `kid` header must name a key this deployment holds — the signing key
///   or a retired key still verifying (HS256 has one key and no ids);
/// - the signature must verify against that key;
/// - `iss` must be the configured issuer, and `aud` the configured audience
///   when one is configured.
///
/// That is what makes an auth server and an application server configured
/// with one key pair trust each other's tokens, through a rotation, and
/// nobody else's.
///
/// The validity window is deliberately *not* checked here, and that is a
/// decision rather than an omission. An expired token still has to reach the
/// request zone: it is the only thing left identifying who is asking, and a
/// refresh or re-login endpoint is reached with exactly it. The framework
/// already answers expiry one layer up — `tomDefaultAuthenticationMiddleware`
/// resolves an expired session to *no principal*, so the request is served as
/// anonymous while the credentials survive for the endpoint that can renew
/// them. Rejecting `exp` here would drop the token as well and break the
/// renewal path, which is the one thing an expired session still needs.
///
/// The two questions are genuinely different: these checks ask *is this ours*
/// and the window asks *is it still current*. Only the first can be forged, and
/// only the first is this function's business.
///
/// ## What a failure produces
///
/// `null`, and a warning naming the reason. Not an exception: the caller's
/// contract is that a token it cannot use means *no credentials*, so a forged
/// token buys anonymous access rather than the claims it forged, and
/// authorization is decided downstream exactly as it is for a request that
/// presented nothing. Throwing would turn a hostile request into a 500 and hand
/// the sender a way to tell a rejected signature from an accepted one.
///
/// The warning matters more than it looks: a bad signature on a live server is
/// either a misconfigured pair of deployments or somebody probing, and both are
/// things an operator wants to see. It is a warning rather than an error
/// because a caller can produce it at will.
///
/// The warning never contains the token. See [_reasonWithoutTheToken] for the
/// one path that would otherwise put it there.
TomClientJwtToken? verifyBearerToken(String token, {bool decrypt = true}) {
  final signing = TomJwtSigning.current;
  try {
    final header = _headerOf(token);
    // The algorithm is this deployment's, never the token's: a verifier that
    // took `alg` from the header could be told to check an RS256 public key as
    // an HMAC secret, and anyone can compute that HMAC.
    final alg = header['alg'];
    if (alg != signing.algorithm.jwtName) {
      tomLog.warn(
        'Rejected a bearer token signed with $alg; this deployment signs with '
        '${signing.algorithm.jwtName}',
      );
      return null;
    }
    final kid = header['kid'];
    final key = signing.keyFor(kid is String ? kid : null);
    if (key == null) {
      tomLog.warn(
        'Rejected a bearer token signed with a key this deployment does not '
        'hold (kid: ${kid is String ? kid : 'none'})',
      );
      return null;
    }
    final audience = signing.audience;
    jwt.JWT.verify(
      token,
      key.verificationKey,
      // See "What is checked": the window belongs to the layer that can act on
      // it, and dropping an expired token here would take the credentials a
      // renewal endpoint needs with it.
      checkExpiresIn: false,
      checkNotBefore: false,
      issuer: signing.issuer,
      audience: audience == null ? null : jwt.Audience.one(audience),
    );
  } on jwt.JWTException catch (e) {
    tomLog.warn('Rejected a bearer token: ${_reasonWithoutTheToken(e)}');
    return null;
  } on Object catch (e) {
    // Anything else the decoder objects to — a malformed token, a payload that
    // is not JSON — is the same answer to the caller: this is not a token this
    // server issued. Reported separately because an unexpected type here means
    // the library changed under us, and a silent `null` would hide that.
    tomLog.warn(
      'Rejected an unreadable bearer token: ${_reasonWithoutTheToken(e)}',
    );
    return null;
  }
  try {
    return TomClientJwtToken(token, decrypt: decrypt);
  } on Object catch (e) {
    // A verified signature and an undecryptable body is a genuine oddity: the
    // token is ours, so this is a key rotation caught mid-flight or a corrupted
    // `encrypted` section rather than a forgery.
    tomLog.warn(
      'Rejected a signed bearer token that would not decode: '
      '${_reasonWithoutTheToken(e)}',
    );
    return null;
  }
}
