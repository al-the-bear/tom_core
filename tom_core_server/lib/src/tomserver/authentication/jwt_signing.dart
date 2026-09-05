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
