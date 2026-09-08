/// Turns a server's configured JWT key material into the process-wide signing
/// configuration, and refuses to hand a deployment the framework's published
/// sample keys.
///
/// [TomBaseServerConfiguration] has always carried three JWT fields —
/// `jwtSharedSecretKey`, `jwtRsaPrivKey`, `jwtRsaPubKey` — and nothing read
/// them. Every server therefore signed with
/// [TomJwtConfiguration.defaultSignConfiguration], whose HMAC secret is the
/// literal `development-passphrase` written into `tom_crypto`. Two servers that
/// verified each other's tokens did so not because they shared a configured
/// secret but because they shared that default, which is the same trust any
/// stranger's server would have had. [installJwtSigning] is the reader those
/// fields never had.
library;

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart' as jwt;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../configuration/base_server_configuration.dart';
import '../little_things/server_exception.dart';

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

/// Whether the active runtime environment is a development or test one.
///
/// A boot that never called `TomRuntime.setCurrentEnvironment` has no current
/// environment, and [TomRuntime.getCurrentEnvironment] throws for it. That is
/// resolved here to `false` rather than propagated: a deployment that never
/// said it was a development server has not said so, and the safe reading of
/// silence is the strict one.
bool _isDevelopmentOrTest() {
  try {
    final environment = TomRuntime.getCurrentEnvironment();
    return environment.isDevelopment || environment.isTest;
  } catch (_) {
    return false;
  }
}

/// Builds the JWT signing configuration from [configuration]'s key material,
/// installs it as [TomJwtConfiguration.defaultSignConfiguration], and returns
/// it.
///
/// Each of the three fields that is set is used; each that is absent or blank
/// falls back to the framework's bundled sample key. The result is marked
/// `isDummy` when anything fell back, which is what makes the framework's own
/// development-key warning tell the truth for a partially configured server —
/// two real RSA keys and a published HMAC secret is a published signing key.
///
/// ## The refusal
///
/// If anything fell back, the environment decides what happens:
///
/// - **development or test** — a warning naming the unconfigured fields, and
///   the boot continues. The samples in this repository rely on this: they ship
///   no keys and are meant to be run.
/// - **anywhere else** — a [TomSigningKeyException], and
///   [TomJwtConfiguration.defaultSignConfiguration] is left exactly as it was.
///   Installing first and throwing after would leave the isolate holding the
///   very key the refusal exists to prevent.
///
/// The check is on the *key material*, not on the environment: a fully
/// configured server starts in production, which is the point, and an
/// unconfigured one starts in development, which is what lets the samples run.
///
/// ## Where this belongs in a boot
///
/// After the configuration is constructed and after the runtime environment is
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
/// and an application server that verifies — configure the *same*
/// `jwtSharedSecretKey`. That is now a property of their configuration and
/// visibly so: change it in one only, and the second rejects the first's
/// tokens.
TomJwtConfiguration installJwtSigning(
  TomBaseServerConfiguration configuration,
) {
  final unconfigured = <String>[];

  final secret = _configured(configuration.jwtSharedSecretKey);
  if (secret == null) unconfigured.add('jwtSharedSecretKey');

  final privPem = _configured(configuration.jwtRsaPrivKey);
  if (privPem == null) unconfigured.add('jwtRsaPrivKey');

  final pubPem = _configured(configuration.jwtRsaPubKey);
  if (pubPem == null) unconfigured.add('jwtRsaPubKey');

  if (unconfigured.isNotEmpty) {
    if (!_isDevelopmentOrTest()) throw TomSigningKeyException(unconfigured);
    tomLog.warn(
      'JWT signing falls back to the framework\'s bundled sample keys for '
      '${unconfigured.join(', ')}. Those keys are published in the tom_crypto '
      'sources; this is permitted here only because the runtime environment is '
      'a development or test one.',
    );
  }

  final installed = TomJwtConfiguration(
    secret == null ? TomJwtConfiguration.hmacKey : jwt.SecretKey(secret),
    TomJwtConfiguration.defaultSignConfiguration.algorithm,
    privPem == null
        ? TomJwtConfiguration.rsaPrivKey
        : RsaKeyHelper.parsePrivateKeyFromPem(privPem),
    pubPem == null
        ? TomJwtConfiguration.rsaPubKey
        : RsaKeyHelper.parsePublicKeyFromPem(pubPem),
    unconfigured.isNotEmpty,
  );
  TomJwtConfiguration.defaultSignConfiguration = installed;
  return installed;
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
/// **The signature, and only the signature** — against
/// [TomJwtConfiguration.defaultSignConfiguration]'s key, the same key
/// [TomServerJwtToken.getJWT] signs with, which is what makes an auth server
/// and an application server that share a `jwtSharedSecretKey` trust each
/// other's tokens and nobody else's.
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
/// The two questions are genuinely different: the signature asks *is this ours*
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
TomClientJwtToken? verifyBearerToken(String token, {bool decrypt = true}) {
  final configuration = TomJwtConfiguration.defaultSignConfiguration;
  try {
    jwt.JWT.verify(
      token,
      configuration.key,
      // See "What is checked": the window belongs to the layer that can act on
      // it, and dropping an expired token here would take the credentials a
      // renewal endpoint needs with it.
      checkExpiresIn: false,
      checkNotBefore: false,
    );
  } on jwt.JWTException catch (e) {
    tomLog.warn('Rejected a bearer token: ${e.message}');
    return null;
  } on Object catch (e) {
    // Anything else the decoder objects to — a malformed token, a payload that
    // is not JSON — is the same answer to the caller: this is not a token this
    // server issued. Reported separately because an unexpected type here means
    // the library changed under us, and a silent `null` would hide that.
    tomLog.warn('Rejected an unreadable bearer token: $e');
    return null;
  }
  try {
    return TomClientJwtToken(token, decrypt: decrypt);
  } on Object catch (e) {
    // A verified signature and an undecryptable body is a genuine oddity: the
    // token is ours, so this is a key rotation caught mid-flight or a corrupted
    // `encrypted` section rather than a forgery.
    tomLog.warn('Rejected a signed bearer token that would not decode: $e');
    return null;
  }
}
