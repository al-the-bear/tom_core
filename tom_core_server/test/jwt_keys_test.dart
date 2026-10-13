/// Asymmetric token signing, key rotation, and the published key set.
///
/// The key files under `test/fixtures/jwt/` were generated with openssl for
/// this suite: two RSA keys (a rotation needs two) and one P-256 key. They sign
/// nothing outside these tests.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart' as jwt;
import 'package:jose/jose.dart' as jose;
import 'package:shelf/shelf.dart' show Request;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

const _dir = 'test/fixtures/jwt';
String _file(String name) => '$_dir/$name';
String _pem(String name) => File(_file(name)).readAsStringSync();

class _JwtConfig extends TomBaseServerConfiguration {
  _JwtConfig() : super([]);
  @override
  void setValues(Map<String, Object?> values) {}
}

/// Mints a token for alice under whatever [installJwtSigning] installed.
String _mint({String? audience}) {
  final signing = TomJwtSigning.current;
  return TomServerJwtToken({
    'username': 'alice',
  }, audience: audience ?? signing.audience).getJWT(signing.issuer);
}

String? _kidOf(String token) => jwt.JWT.decode(token).header?['kid'] as String?;

void main() {
  late TomJwtConfiguration original;

  setUp(() {
    original = TomJwtConfiguration.defaultSignConfiguration;
    TomRuntime.reset();
    TomRuntime.addEnvironment(
      const TomEnvironment('dev', isDevelopment: true, isTest: true),
    );
    TomRuntime.setCurrentEnvironment('dev', '');
  });

  tearDown(() {
    TomJwtConfiguration.defaultSignConfiguration = original;
    TomJwtSigning.reset();
    TomRuntime.reset();
  });

  group('keys', () {
    test('a private key and its public half have the same id', () {
      for (final (name, algorithm) in [
        ('rsa_a', TomJwtAlgorithm.rs256),
        ('ec', TomJwtAlgorithm.es256),
      ]) {
        final signing = TomJwtSigningKey.privatePem(
          _pem('${name}_private.pem'),
          algorithm,
        );
        final public = TomJwtKey.publicPem(
          _pem('${name}_public.pem'),
          algorithm,
        );
        expect(signing.keyId, public.keyId, reason: name);
      }
    });

    test('different keys have different ids', () {
      final a = TomJwtKey.publicPem(
        _pem('rsa_a_public.pem'),
        TomJwtAlgorithm.rs256,
      );
      final b = TomJwtKey.publicPem(
        _pem('rsa_b_public.pem'),
        TomJwtAlgorithm.rs256,
      );
      expect(a.keyId, isNot(b.keyId));
    });

    test('the id is the RFC 7638 thumbprint of the required members', () {
      // Recomputed independently from the published JWK.
      final key = TomJwtKey.publicPem(
        _pem('rsa_a_public.pem'),
        TomJwtAlgorithm.rs256,
      );
      final jwk = key.jwk!;
      final canonical = '{"e":"${jwk['e']}","kty":"RSA","n":"${jwk['n']}"}';
      expect(
        key.keyId,
        TomJwtKey.thumbprint(jsonDecode(canonical) as Map<String, Object?>),
      );
      expect(key.keyId, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    });

    test('a key of the wrong kind is refused, naming the file', () {
      expect(
        () => TomJwtKey.publicPem(
          _pem('ec_public.pem'),
          TomJwtAlgorithm.rs256,
          source: 'ec_public.pem',
        ),
        throwsA(
          isA<TomJwtKeyException>()
              .having((e) => e.key, 'key', 'jwt.keys.unreadable_key_file')
              .having(
                (e) => e.parameters?['source'],
                'source',
                'ec_public.pem',
              ),
        ),
      );
    });

    test('an unknown algorithm is refused', () {
      expect(
        () => TomJwtAlgorithm.parse('none'),
        throwsA(
          isA<TomJwtKeyException>().having(
            (e) => e.key,
            'key',
            'jwt.keys.unknown_algorithm',
          ),
        ),
      );
      expect(TomJwtAlgorithm.parse('es256'), TomJwtAlgorithm.es256);
    });
  });

  group('signing from configured key files', () {
    test('RS256 signs with the file\'s key and names it', () {
      installJwtSigning(
        _JwtConfig()..jwtSigningKeyFile = _file('rsa_a_private.pem'),
      );
      final token = _mint();
      expect(_kidOf(token), TomJwtSigning.current.signingKeyId);
      expect(jwt.JWT.decode(token).header?['alg'], 'RS256');
      expect(verifyBearerToken(token), isNotNull);
    });

    test('ES256 signs and verifies', () {
      installJwtSigning(
        _JwtConfig()
          ..jwtAlgorithm = 'ES256'
          ..jwtSigningKeyFile = _file('ec_private.pem'),
      );
      final token = _mint();
      expect(jwt.JWT.decode(token).header?['alg'], 'ES256');
      expect(verifyBearerToken(token), isNotNull);
    });

    test('ES256 with no key file is refused even in development', () {
      expect(
        () => installJwtSigning(_JwtConfig()..jwtAlgorithm = 'ES256'),
        throwsA(isA<TomSigningKeyException>()),
      );
    });

    test('a key file that does not exist is refused, naming it', () {
      expect(
        () => installJwtSigning(
          _JwtConfig()..jwtSigningKeyFile = _file('missing.pem'),
        ),
        throwsA(
          isA<TomJwtKeyException>().having(
            (e) => e.key,
            'key',
            'jwt.keys.unreadable_key_file',
          ),
        ),
      );
    });

    test('a server with configured keys boots outside development', () {
      TomRuntime.reset();
      TomRuntime.addEnvironment(const TomEnvironment('prod'));
      TomRuntime.setCurrentEnvironment('prod', '');
      final installed = installJwtSigning(
        _JwtConfig()
          ..jwtSigningKeyFile = _file('rsa_a_private.pem')
          ..jwtRsaPrivKey = _pem('rsa_b_private.pem')
          ..jwtRsaPubKey = _pem('rsa_b_public.pem'),
      );
      expect(installed.isDummy, isFalse);
    });
  });

  group('rotating the signing key', () {
    void installA() => installJwtSigning(
      _JwtConfig()..jwtSigningKeyFile = _file('rsa_a_private.pem'),
    );
    void installBKeepingA() => installJwtSigning(
      _JwtConfig()
        ..jwtSigningKeyFile = _file('rsa_b_private.pem')
        ..jwtVerificationKeyFiles = _file('rsa_a_public.pem'),
    );
    void installBOnly() => installJwtSigning(
      _JwtConfig()..jwtSigningKeyFile = _file('rsa_b_private.pem'),
    );

    test('a token signed before the rotation keeps verifying', () {
      installA();
      final before = _mint();
      installBKeepingA();
      final after = _mint();

      expect(_kidOf(after), isNot(_kidOf(before)), reason: 'B signs now');
      expect(verifyBearerToken(before), isNotNull);
      expect(verifyBearerToken(after), isNotNull);
    });

    test('once the old key is removed, its tokens stop verifying', () {
      installA();
      final before = _mint();
      installBOnly();
      expect(verifyBearerToken(before), isNull);
      expect(verifyBearerToken(_mint()), isNotNull);
    });

    test('both keys are published during the rotation', () {
      installBKeepingA();
      final kids = [
        for (final key
            in (TomJwtSigning.current.jwks!['keys'] as List).cast<Map>())
          key['kid'],
      ];
      expect(kids, hasLength(2));
      expect(kids.first, TomJwtSigning.current.signingKeyId);
    });
  });

  group('what a verifier refuses', () {
    test('a token naming another algorithm — the HS256 confusion attack', () {
      // The classic forgery: sign with HS256 using the *public* key as the
      // HMAC secret. A verifier that took `alg` from the token would check it
      // with the public key it holds — and the MAC would match.
      installJwtSigning(
        _JwtConfig()..jwtSigningKeyFile = _file('rsa_a_private.pem'),
      );
      final forged = jwt
          .JWT(
            {'username': 'mallory'},
            issuer: TomJwtSigning.current.issuer,
            header: {'kid': TomJwtSigning.current.signingKeyId},
          )
          .sign(
            jwt.SecretKey(_pem('rsa_a_public.pem')),
            algorithm: jwt.JWTAlgorithm.HS256,
          );
      expect(verifyBearerToken(forged), isNull);
    });

    test('a token naming no key, or a key not held', () {
      installJwtSigning(
        _JwtConfig()..jwtSigningKeyFile = _file('rsa_a_private.pem'),
      );
      final unnamed = jwt
          .JWT({'username': 'alice'}, issuer: 'tom')
          .sign(
            jwt.RSAPrivateKey(_pem('rsa_a_private.pem')),
            algorithm: jwt.JWTAlgorithm.RS256,
          );
      expect(verifyBearerToken(unnamed), isNull);
    });

    test('a token from another issuer', () {
      installJwtSigning(
        _JwtConfig()..jwtSigningKeyFile = _file('rsa_a_private.pem'),
      );
      final other = TomServerJwtToken({
        'username': 'alice',
      }).getJWT('someone-else');
      expect(verifyBearerToken(other), isNull);
    });

    test(
      'a token for another audience, or for none, when one is configured',
      () {
        installJwtSigning(
          _JwtConfig()
            ..jwtSigningKeyFile = _file('rsa_a_private.pem')
            ..jwtIssuer = 'auth.example'
            ..jwtAudience = 'orders-api',
        );
        expect(verifyBearerToken(_mint()), isNotNull);
        expect(verifyBearerToken(_mint(audience: 'billing-api')), isNull);
        final none = TomServerJwtToken({
          'username': 'alice',
        }).getJWT('auth.example');
        expect(verifyBearerToken(none), isNull);
      },
    );
  });

  group('a verify-only server', () {
    test('verifies the issuer\'s tokens and refuses to issue', () {
      installJwtSigning(
        _JwtConfig()..jwtSigningKeyFile = _file('rsa_a_private.pem'),
      );
      final issued = _mint();

      installJwtSigning(
        _JwtConfig()..jwtVerificationKeyFiles = _file('rsa_a_public.pem'),
      );
      expect(TomJwtSigning.current.canSign, isFalse);
      expect(verifyBearerToken(issued), isNotNull);
      expect(
        TomJwtSigning.current.requireSigning,
        throwsA(
          isA<TomJwtKeyException>().having(
            (e) => e.key,
            'key',
            'jwt.keys.verify_only',
          ),
        ),
      );
    });
  });

  group('the JSON Web Key Set', () {
    test('publishes the public keys with their ids', () async {
      installJwtSigning(
        _JwtConfig()..jwtSigningKeyFile = _file('rsa_a_private.pem'),
      );
      final response = await TomJwksServer().jwks();
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'application/jwk-set+json');
      expect(response.headers['cache-control'], contains('max-age=300'));
      final set = jsonDecode(await response.readAsString()) as Map;
      final key = (set['keys'] as List).single as Map;
      expect(key['kty'], 'RSA');
      expect(key['alg'], 'RS256');
      expect(key['use'], 'sig');
      expect(key['kid'], TomJwtSigning.current.signingKeyId);
      expect(key.containsKey('d'), isFalse, reason: 'never the private part');
    });

    test('an HS256 deployment publishes nothing', () async {
      installJwtSigning(_JwtConfig()..jwtAlgorithm = 'HS256');
      expect((await TomJwksServer().jwks()).statusCode, 404);
    });

    test(
      'a third-party library verifies tokens through the published set',
      () async {
        // `package:jose` shares no code with the framework: it fetches the set
        // over HTTP, picks the key by `kid` and checks the signature itself.
        for (final (algorithm, file) in [
          ('RS256', 'rsa_a_private.pem'),
          ('ES256', 'ec_private.pem'),
        ]) {
          installJwtSigning(
            _JwtConfig()
              ..jwtAlgorithm = algorithm
              ..jwtSigningKeyFile = _file(file),
          );
          final server = await shelf_io.serve(
            (Request _) => TomJwksServer().jwks(),
            InternetAddress.loopbackIPv4,
            0,
          );
          try {
            final store = jose.JsonWebKeyStore()
              ..addKeySetUrl(
                Uri.parse(
                  'http://127.0.0.1:${server.port}/.well-known/jwks.json',
                ),
              );
            final verified = await jose.JsonWebToken.decodeAndVerify(
              _mint(),
              store,
            );
            expect(verified.claims['username'], 'alice', reason: algorithm);
          } finally {
            await server.close(force: true);
          }
        }
      },
    );
  });
}
