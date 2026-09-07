// `SecretKey` is `dart_jsonwebtoken`'s, and tom_crypto does not re-export it —
// so a test that wants to read the installed HMAC key back out reaches for the
// package directly, exactly as `jwt_signing.dart` does.
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// A concrete configuration whose JWT fields the test sets directly.
///
/// [setValues] is overridden to do nothing so no generated reflection is
/// involved: what is under test is what [installJwtSigning] makes of the three
/// fields, not how they came to be filled.
class _JwtConfig extends TomBaseServerConfiguration {
  _JwtConfig() : super([]);
  @override
  void setValues(Map<String, Object?> values) {}
}

/// The bundled sample PEMs, reused verbatim as *a* pair of real keys.
///
/// A test that wants "the operator configured RSA keys" needs a parseable PEM
/// and does not care which one; generating a fresh keypair per test would cost
/// seconds of RSA key generation to prove nothing the bundled pair does not.
/// What the tests never do is treat these as *distinct* from the framework's —
/// see `a configured RSA pair alone does not clear the bundled secret`.
const _pubPem = '''
-----BEGIN PUBLIC KEY-----
MIIBCgKCAQEApobMwJj9SxpZbk0fcG8Awv9PCiO4/GsPimeH398D+Qt1kUrrMqvm5+AYLh1PcIgE/V+QiFTgBv9Fpuu5YtrnF+oi/dg23MUKPA0yXzHjTyshm3P2uhIRN4c6fVru5HF3HXGh5POR1A6kGW9IGbeKhLCG1yyoNDGzHdrdwNEREw3N6KEKAN4swXOMau7rhaRXTkOWTSyPwhAEI+ZrwTnHBIDsVouqPQ0yAX7vTGK1UFNPGmh7itLECj8WgbxgElyrPgtDknmXmfCzrn3DMJeGbuq9dzl0z5DZysrR3nEqIQB8xnDLkkejjnmn1YOflaZMql3mKSJeJ9KxPUZ+u+6DcwIDAQAB
-----END PUBLIC KEY-----
''';

const _privPem = '''
-----BEGIN PRIVATE KEY-----
MIIFowIBAAKCAQEApobMwJj9SxpZbk0fcG8Awv9PCiO4/GsPimeH398D+Qt1kUrrMqvm5+AYLh1PcIgE/V+QiFTgBv9Fpuu5YtrnF+oi/dg23MUKPA0yXzHjTyshm3P2uhIRN4c6fVru5HF3HXGh5POR1A6kGW9IGbeKhLCG1yyoNDGzHdrdwNEREw3N6KEKAN4swXOMau7rhaRXTkOWTSyPwhAEI+ZrwTnHBIDsVouqPQ0yAX7vTGK1UFNPGmh7itLECj8WgbxgElyrPgtDknmXmfCzrn3DMJeGbuq9dzl0z5DZysrR3nEqIQB8xnDLkkejjnmn1YOflaZMql3mKSJeJ9KxPUZ+u+6DcwKCAQAvUp9dHBze+t3vOnt0uBa/U05i00P+d24zJri2Jeo7G8aNQ30TKUa1HjnA4RNyJzVDy6SHGZeQZXqltNc6AHsrkJ3hBVCR7Gy8JAPsiYDPPrKOOqYiun+qCAPXG8BHqvbupxwatBz85iw8DiOvKzlx+7hV7ZrfOkBse4YJBWCUySF/T+ZVdM3kqoMtfegnGa2AWmGa09qDoCBt1TAHVtNDAu/1UnbvjlHTJ6NFfboibortCRBicmhAu1jcbW6dn9/J9naXlkYxRK22uItXKunv/dqmDQ+lRE9KuKArexYweenHd3yuExuXGOR9XM8vJtgZqTR8WYRDbeWgNQMwXSoBAoIBAC9Sn10cHN763e86e3S4Fr9TTmLTQ/53bjMmuLYl6jsbxo1DfRMpRrUeOcDhE3InNUPLpIcZl5BleqW01zoAeyuQneEFUJHsbLwkA+yJgM8+so46piK6f6oIA9cbwEeq9u6nHBq0HPzmLDwOI68rOXH7uFXtmt86QGx7hgkFYJTJIX9P5lV0zeSqgy196CcZrYBaYZrT2oOgIG3VMAdW00MC7/VSdu+OUdMno0V9uiJuiu0JEGJyaEC7WNxtbp2f38n2dpeWRjFErba4i1cq6e/92qYND6VET0q4oCt7FjB56cd3fK4TG5cY5H1czy8m2BmpNHxZhENt5aA1AzBdKgECgYEA5QjshbsxGUmtMLSFXPn3Y2KW9e2K0r2itb5A2PRB+28aDiFArPmWVhvRujS8KG78NUBwWq/c2c8bET/6j1y0qIsy/2ZBWmoKTSyIbrxybzalMpOWQ5Y37CKypG73EQtigHmuZ6TN0Tr9vkY/q+o+wilVF+EIzcj39WAherAKHwcCgYEAuiHin+jukcxVNKy4bz8dRkHHbmCoCv12fNSihhemfrE/daCWCY1J+VkCrB1a5iuOx6huDAYHXMWl3jjfkvoTX1/YQjhb5f2bMqrHjkyw86k1j6yMdgfO+AG3sqhIz3fszMaVd6UfE7mwwaqE4QfppAJWBvKS9SQaY7KNN2+8cTUCgYB3qPHp7KL6U0Po7me+69oUUq4MTs74y5r22S+IKhVPB/zU5QqlVMD2vBIW9vZXKaUbLU+GEduQ8GNz37lIrWa1qAQ862+5jS1UpK+jK1GeSS6F/hXDuff9pyMuRctPXGNaPDiibbgaWHe5sXoSl4+yYWXT0/6FhToHOPJE5zRigQKBgQCpx2zTFgI+xVZXNNEK0FQgmLGT0eCWHbpthPs2Ou5ok77hyXfyAImgQvu4CRK37rVPEyhGGV2v1q1EdTYh96+iCGfXh1b0A48D+VkLSJMDvq2XfvmkU90KxW5NLUk0zRwXcXA28UvWj0NWc/a+2JvaOTNFJRC9QJA9rkk3btlBnQKBgQCTT4oMD16jRtyxwK+cczzxPX3P4FtZHuppBetUmuq+2xFTvdB/ivUARXcYhibG09+AC1heYtImy+pRXxMPnKXimFFvimJMT4edBq0w2XA33VDoG+xeYM6G0c3bHbk53DTNk+lr4GirKMSe6kYFV3Fo9kmnvW0N9ttLfFQqds+LUg==
-----END PRIVATE KEY-----
''';

/// A configuration with every JWT field supplied, so nothing falls back.
_JwtConfig _fullyConfigured() => _JwtConfig()
  ..jwtSharedSecretKey = 'a-secret-nobody-published'
  ..jwtRsaPrivKey = _privPem
  ..jwtRsaPubKey = _pubPem;

void main() {
  // `TomJwtConfiguration.defaultSignConfiguration` and the runtime's current
  // environment are both process-global, and installJwtSigning writes the
  // first while reading the second. Restoring both around every test keeps the
  // cases independent of one another and of whatever ran before this file.
  late TomJwtConfiguration originalSigning;

  setUp(() {
    originalSigning = TomJwtConfiguration.defaultSignConfiguration;
    TomRuntime.reset();
  });

  tearDown(() {
    TomJwtConfiguration.defaultSignConfiguration = originalSigning;
    TomRuntime.reset();
  });

  void selectEnvironment({required bool development}) {
    TomRuntime.addEnvironment(
      TomEnvironment(
        development ? 'dev' : 'prod',
        isDevelopment: development,
        isTest: development,
      ),
    );
    TomRuntime.setCurrentEnvironment(development ? 'dev' : 'prod', '');
  }

  // The three JWT fields were carried and read by nothing: a deployment could
  // set `jwtSharedSecretKey` and go on signing with the framework's published
  // `development-passphrase`, with no way to tell from the outside. Two servers
  // then trusted each other's tokens not because they shared a configured
  // secret but because they shared a *default* — which is the same trust a
  // stranger's server would have had. These tests fix that the fields are the
  // signing keys, and that a server which did not supply them says so.
  group('installJwtSigning reads the configured key material', () {
    test('a configured shared secret becomes the signing key', () {
      selectEnvironment(development: false);
      final installed = installJwtSigning(_fullyConfigured());
      expect(installed.key, isA<SecretKey>());
      expect((installed.key as SecretKey).key, 'a-secret-nobody-published');
    });

    test('the installed configuration becomes the process default', () {
      selectEnvironment(development: false);
      final installed = installJwtSigning(_fullyConfigured());
      expect(
        TomJwtConfiguration.defaultSignConfiguration,
        same(installed),
        reason:
            'every token minted or verified in this process reads the default; '
            'a returned-but-not-installed configuration would sign nothing',
      );
    });

    test('a fully configured server is not a dummy configuration', () {
      selectEnvironment(development: false);
      expect(installJwtSigning(_fullyConfigured()).isDummy, isFalse);
    });

    test('the configured RSA pair is what encrypts the payload', () {
      selectEnvironment(development: false);
      final installed = installJwtSigning(_fullyConfigured());
      expect(installed.decrypt(installed.encrypt('payload')), 'payload');
    });

    test('two servers configured alike arrive at the same signing key', () {
      // This is the property the advanced sample's cross-server trust rests on,
      // and the one that was previously an accident of a shared default: set
      // the same secret in both deployments and their tokens verify against
      // each other; set it in one only and they do not.
      selectEnvironment(development: false);
      final auth = installJwtSigning(_fullyConfigured());
      final app = installJwtSigning(_fullyConfigured());
      expect((app.key as SecretKey).key, (auth.key as SecretKey).key);

      final divergent = installJwtSigning(
        _fullyConfigured()..jwtSharedSecretKey = 'a-different-secret',
      );
      expect(
        (divergent.key as SecretKey).key,
        isNot((auth.key as SecretKey).key),
      );
    });
  });

  // A server that supplied no key material still has to start in development,
  // or the sample could not be run at all; what it must not do is start that
  // way anywhere else. The bundled keys are published in this repository, so
  // outside development they are not a weak secret but a public one.
  group('installJwtSigning refuses bundled keys outside development', () {
    test('an unconfigured server boots in development on the bundled keys', () {
      selectEnvironment(development: true);
      final installed = installJwtSigning(_JwtConfig());
      expect(installed.isDummy, isTrue);
      expect(installed.key, same(TomJwtConfiguration.hmacKey));
    });

    test('an unconfigured server refuses to boot in production', () {
      selectEnvironment(development: false);
      expect(
        () => installJwtSigning(_JwtConfig()),
        throwsA(isA<TomSigningKeyException>()),
      );
    });

    test('the refusal names the fields that were not configured', () {
      selectEnvironment(development: false);
      expect(
        () => installJwtSigning(_JwtConfig()),
        throwsA(
          isA<TomSigningKeyException>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('jwtSharedSecretKey'),
              contains('jwtRsaPrivKey'),
              contains('jwtRsaPubKey'),
            ),
          ),
        ),
      );
    });

    test('the refusal leaves the process default untouched', () {
      // A half-installed signing configuration would be worse than none: the
      // server would be dead but the isolate's default would carry the very
      // bundled key the refusal exists to prevent.
      selectEnvironment(development: false);
      final before = TomJwtConfiguration.defaultSignConfiguration;
      expect(() => installJwtSigning(_JwtConfig()), throwsA(isA<Exception>()));
      expect(TomJwtConfiguration.defaultSignConfiguration, same(before));
    });

    test('a configured RSA pair alone does not clear the bundled secret', () {
      // Partial configuration is the interesting case, because it is what a
      // reader who set one of the three variables produces. Two real keys and
      // one published one is a published signing key.
      selectEnvironment(development: false);
      final partial = _JwtConfig()
        ..jwtRsaPrivKey = _privPem
        ..jwtRsaPubKey = _pubPem;
      expect(
        () => installJwtSigning(partial),
        throwsA(
          isA<TomSigningKeyException>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('jwtSharedSecretKey'),
              isNot(contains('jwtRsaPrivKey')),
            ),
          ),
        ),
      );
    });

    test('a configured secret alone does not clear the bundled RSA pair', () {
      selectEnvironment(development: false);
      final partial = _JwtConfig()..jwtSharedSecretKey = 'a-secret';
      expect(
        () => installJwtSigning(partial),
        throwsA(isA<TomSigningKeyException>()),
      );
    });

    test('a blank value counts as unconfigured, not as a key', () {
      // `JWT_SHARED_SECRET_KEY=` in a `.env` file yields the empty string, and
      // an empty HMAC secret is not a secret. Treating it as one would let the
      // guard pass on a variable the operator plainly failed to fill in.
      selectEnvironment(development: false);
      final blank = _fullyConfigured()..jwtSharedSecretKey = '   ';
      expect(
        () => installJwtSigning(blank),
        throwsA(isA<TomSigningKeyException>()),
      );
    });

    test('a server that never declared an environment is not development', () {
      // `TomRuntime.reset()` leaves no current environment, which is the state
      // of a boot that forgot `setCurrentEnvironment`. The guard resolves that
      // to "not development" rather than to an environment lookup failure: a
      // deployment that never said it was a development server has not said so.
      expect(
        () => installJwtSigning(_JwtConfig()),
        throwsA(isA<TomSigningKeyException>()),
      );
    });

    test('a fully configured server boots in production', () {
      // The mirror of the refusal, and the reason the guard is on the key
      // material rather than on the environment: production is exactly where a
      // configured server must start.
      selectEnvironment(development: false);
      expect(() => installJwtSigning(_fullyConfigured()), returnsNormally);
    });
  });
}
