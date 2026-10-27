/// Transport and browser security: the default security headers, the CORS
/// allow-list's settings, browser sessions in a cookie with their CSRF check,
/// and mutual TLS between services — the last over a real TLS socket, with the
/// certificates in `test/fixtures/mtls/` (a test CA, a server certificate for
/// localhost, client certificates it issued, and one from a CA nobody trusts).
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

String _fixture(String name) =>
    File('test/fixtures/mtls/$name').readAsStringSync();

/// A JWT signed with this deployment's configuration.
String _signed(Map<String, dynamic> claims) =>
    TomServerJwtToken(claims).getJWT(TomJwtSigning.current.issuer);

Matcher _throwsKey(String key) =>
    throwsA(isA<TomServerException>().having((e) => e.key, 'key', key));

/// A handler answering who the request was authenticated as.
Handler _whoAmI() => const Pipeline()
    .addMiddleware(tomDefaultAuthenticationMiddleware('web security test'))
    .addHandler((request) {
      final principal = getFromCurrentZone<TomPrincipal>();
      return Response.ok(
        jsonEncode({
          'authenticated': principal?.authenticated ?? false,
          'id': principal?.authenticated == true ? principal!.id : null,
        }),
        headers: {'content-type': 'application/json'},
      );
    });

/// Why the live mutual-TLS group cannot run here, or `null` when it can.
final String? _openSslMissing = () {
  try {
    return Process.runSync('openssl', ['version']).exitCode == 0
        ? null
        : 'openssl does not run on this machine';
  } on ProcessException {
    return 'openssl is not on the PATH: the server certificate cannot be '
        'issued';
  }
}();

void main() {
  group('security headers', () {
    Future<Response> serve(
      Request request, {
      Map<String, String> answer = const {},
    }) async => await const Pipeline()
        .addMiddleware(tomSecurityHeadersMiddleware())
        .addHandler((_) => Response.ok('ok', headers: answer))(request);

    tearDown(() => TomSecurityHeaders.current = const TomSecurityHeaders());

    test('every response carries the defaults; HSTS only over HTTPS', () async {
      final plain = await serve(Request('GET', Uri.parse('http://h/x')));
      expect(plain.headers['x-content-type-options'], 'nosniff');
      expect(plain.headers['x-frame-options'], 'DENY');
      expect(plain.headers['referrer-policy'], 'no-referrer');
      expect(
        plain.headers['content-security-policy'],
        "default-src 'none'; frame-ancestors 'none'",
      );
      expect(plain.headers['strict-transport-security'], isNull);

      final secure = await serve(Request('GET', Uri.parse('https://h/x')));
      expect(
        secure.headers['strict-transport-security'],
        'max-age=31536000; includeSubDomains',
      );
    });

    test('a header the response sets itself is left alone', () async {
      final response = await serve(
        Request('GET', Uri.parse('http://h/x')),
        answer: {'content-security-policy': "default-src 'self'"},
      );
      expect(response.headers['content-security-policy'], "default-src 'self'");
    });

    test(
      'the CSP hook chooses per request, and "" leaves a header out',
      () async {
        TomSecurityHeaders.current = TomSecurityHeaders(
          frameOptions: '',
          contentSecurityPolicyFor: (request, _) =>
              request.requestedUri.path.startsWith('/docs')
              ? "default-src 'self'"
              : null,
        );
        final docs = await serve(Request('GET', Uri.parse('http://h/docs/a')));
        expect(docs.headers['content-security-policy'], "default-src 'self'");
        expect(docs.headers['x-frame-options'], isNull);
        final api = await serve(Request('GET', Uri.parse('http://h/api')));
        expect(
          api.headers['content-security-policy'],
          "default-src 'none'; frame-ancestors 'none'",
        );
      },
    );

    test('are configured from the server configuration', () async {
      TomSecurityHeaders.configure({
        'hstsMaxAgeSeconds': 600,
        'hstsIncludeSubDomains': false,
        'hstsPreload': true,
        'referrerPolicy': 'same-origin',
      });
      final response = await serve(Request('GET', Uri.parse('https://h/x')));
      expect(
        response.headers['strict-transport-security'],
        'max-age=600; preload',
      );
      expect(response.headers['referrer-policy'], 'same-origin');
      TomSecurityHeaders.configure({'enabled': false});
      final off = await serve(Request('GET', Uri.parse('https://h/x')));
      expect(off.headers['x-content-type-options'], isNull);
      for (final bad in <Object?>[
        'on',
        {'hstsMaxAgeSeconds': -1},
        {'hstsMaxAgeSeconds': '600'},
        {'frameOption': 'DENY'},
      ]) {
        expect(
          () => TomSecurityHeaders.configure(bad),
          _throwsKey('server.security_headers.config.invalid'),
          reason: '$bad',
        );
      }
    });
  });

  group('the CORS allow-list', () {
    tearDown(() => TomCors.current = const TomCors());

    test('admits exact origins, any port of a host, or every origin', () {
      const cors = TomCors(
        allowedOrigins: ['https://app.example.com', 'http://localhost:*'],
      );
      expect(cors.admits('https://app.example.com'), isTrue);
      expect(cors.admits('https://app.example.com:8443'), isFalse);
      expect(cors.admits('http://localhost:5173'), isTrue);
      expect(cors.admits('http://localhost'), isTrue);
      expect(cors.admits('http://localhost.evil.com'), isFalse);
      expect(cors.admits('http://localhost:x'), isFalse);
      expect(
        const TomCors(allowedOrigins: ['*']).admits('https://any'),
        isTrue,
      );
      expect(const TomCors().admits('https://app.example.com'), isFalse);
    });

    test('answers "*" for every origin, without credentials', () {
      final headers = const TomCors(allowedOrigins: ['*']).headersFor(
        Request(
          'GET',
          Uri.parse('http://h/x'),
          headers: {'origin': 'https://a.example'},
        ),
      );
      expect(headers['Access-Control-Allow-Origin'], '*');
      expect(headers.keys, isNot(contains('Vary')));
    });

    test('is configured from the server configuration', () {
      TomCors.configure({
        'allowedOrigins': ['https://app.example.com'],
        'allowCredentials': true,
        'maxAgeSeconds': 60,
      });
      expect(TomCors.current.allowedOrigins, ['https://app.example.com']);
      expect(TomCors.current.allowCredentials, isTrue);
      for (final bad in <Object?>[
        ['https://a'],
        {'allowedOrigins': 'https://a'},
        {
          'allowedOrigins': ['app.example.com'],
        },
        {
          'allowedOrigins': ['https://a/path'],
        },
        {
          'allowedOrigins': ['*'],
          'allowCredentials': true,
        },
        {'allowedOrigin': <String>[]},
      ]) {
        expect(
          () => TomCors.configure(bad),
          _throwsKey('endpoint.cors.config.invalid'),
          reason: '$bad',
        );
      }
    });
  });

  group('a browser session in a cookie', () {
    late Handler handler;
    late String token;

    setUp(() {
      TomSessionCookie.current = const TomSessionCookie();
      handler = _whoAmI();
      token = _signed({'userId': 'alice', 'username': 'alice'});
    });
    tearDown(() {
      TomSessionCookie.current = null;
      TomCors.current = const TomCors();
    });

    Request request(
      String method, {
      String? cookie,
      String? csrf,
      String? origin,
    }) => Request(
      method,
      Uri.parse('https://api.example.com/orders'),
      headers: {'cookie': ?cookie, 'x-csrf-token': ?csrf, 'origin': ?origin},
    );

    Future<Map<String, Object?>> who(Response response) async =>
        jsonDecode(await response.readAsString()) as Map<String, Object?>;

    test('attach sets the token HttpOnly and a readable CSRF token', () {
      final response = TomSessionCookie.current!.attach(
        Response.ok('signed in'),
        token,
        maxAge: const Duration(hours: 1),
      );
      final cookies = response.headersAll['set-cookie']!;
      expect(cookies, hasLength(2));
      expect(
        cookies.first,
        'tom_session=$token; Path=/; Max-Age=3600; Secure; HttpOnly; '
        'SameSite=Strict',
      );
      expect(cookies.last, startsWith('tom_csrf='));
      expect(cookies.last, isNot(contains('HttpOnly')));
      expect(cookies.last, endsWith('; Secure; SameSite=Strict'));
      final cleared = TomSessionCookie.current!.clear(Response.ok(''));
      expect(cleared.headersAll['set-cookie']!.first, contains('Max-Age=0'));
    });

    test('authenticates a request carrying only the cookie', () async {
      final response = await handler(
        request('GET', cookie: 'tom_session=$token'),
      );
      expect(response.statusCode, 200);
      expect((await who(response))['id'], 'alice');
    });

    test(
      'an unsafe method needs the CSRF header to match the cookie',
      () async {
        final ok = await handler(
          request(
            'POST',
            cookie: 'tom_session=$token; tom_csrf=abc123',
            csrf: 'abc123',
          ),
        );
        expect(ok.statusCode, 200);
        expect((await who(ok))['id'], 'alice');

        for (final (cookie, csrf, reason) in [
          ('tom_session=$token', null, 'missing_token'),
          ('tom_session=$token; tom_csrf=abc123', null, 'missing_token'),
          ('tom_session=$token; tom_csrf=abc123', 'abc124', 'token_mismatch'),
        ]) {
          final refused = await handler(
            request('POST', cookie: cookie, csrf: csrf),
          );
          expect(refused.statusCode, 403, reason: reason);
          final body = await who(refused);
          expect(body['errorKey'], 'authentication.csrf.rejected');
        }
      },
    );

    test(
      'a foreign Origin is refused unless the CORS policy admits it',
      () async {
        Request post(String origin) => request(
          'POST',
          cookie: 'tom_session=$token; tom_csrf=t0k3n',
          csrf: 't0k3n',
          origin: origin,
        );
        expect(
          (await handler(post('https://evil.example.com'))).statusCode,
          403,
        );
        expect(
          (await handler(post('https://api.example.com'))).statusCode,
          200,
        );
        TomCors.current = const TomCors(
          allowedOrigins: ['https://app.example.com'],
        );
        expect(
          (await handler(post('https://app.example.com'))).statusCode,
          200,
        );
      },
    );

    test('a bearer header is not held to the CSRF check', () async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('https://api.example.com/orders'),
          headers: {
            'authorization': 'Bearer $token',
            'cookie': 'tom_session=junk',
          },
        ),
      );
      expect(response.statusCode, 200);
      expect((await who(response))['id'], 'alice');
    });

    test('is configured from the server configuration', () {
      TomSessionCookie.configure({
        'name': 'sid',
        'sameSite': 'Lax',
        'path': '/app',
        'domain': 'example.com',
      });
      final cookie = TomSessionCookie.current!
          .attach(Response.ok(''), 't')
          .headersAll['set-cookie']!
          .first;
      expect(
        cookie,
        'sid=t; Path=/app; Domain=example.com; Secure; HttpOnly; '
        'SameSite=Lax',
      );
      for (final bad in <Object?>[
        'tom_session',
        {'sameSite': 'None', 'secure': false},
        {'sameSite': 'Sometimes'},
        {'path': 'app'},
        {'name': 'bad name'},
        {'cookie': 'x'},
      ]) {
        expect(
          () => TomSessionCookie.configure(bad),
          _throwsKey('authentication.session_cookie.config.invalid'),
          reason: '$bad',
        );
      }
    });
  });

  group('mutual TLS', skip: _openSslMissing, () {
    late HttpServer server;
    late String clientFingerprint;
    late String serverCertificate;
    late String serverKey;

    // macOS refuses a TLS server certificate valid for more than 825 days, so
    // the server's is issued from the test CA for each run (see
    // test/fixtures/mtls/README.md).
    setUpAll(() async {
      final dir = await Directory.systemTemp.createTemp('tom_mtls_test_');
      addTearDown(() => dir.delete(recursive: true));
      final path = dir.path;
      File('$path/server.ext').writeAsStringSync(
        'subjectAltName=DNS:localhost,IP:127.0.0.1\n'
        'extendedKeyUsage=serverAuth\n',
      );
      for (final arguments in [
        [
          'req',
          '-newkey',
          'rsa:2048',
          '-nodes',
          '-keyout',
          '$path/server.key',
          '-out',
          '$path/server.csr',
          '-subj',
          '/CN=localhost',
        ],
        [
          'x509',
          '-req',
          '-in',
          '$path/server.csr',
          '-CA',
          'test/fixtures/mtls/ca.pem',
          '-CAkey',
          'test/fixtures/mtls/ca.key',
          '-set_serial',
          '1',
          '-days',
          '2',
          '-extfile',
          '$path/server.ext',
          '-out',
          '$path/server.pem',
        ],
      ]) {
        final result = await Process.run('openssl', arguments);
        if (result.exitCode != 0) {
          fail('openssl ${arguments.first} failed: ${result.stderr}');
        }
      }
      serverCertificate = File('$path/server.pem').readAsStringSync();
      serverKey = File('$path/server.key').readAsStringSync();
    });

    String fingerprintOf(String pem) => TomMutualTls.fingerprintOfPem(pem);

    SecurityContext clientContext(String name) => TomMutualTls.clientContext(
      certificateChainPem: _fixture('$name.pem'),
      privateKeyPem: _fixture('$name.key'),
      trustedCaPem: _fixture('ca.pem'),
    );

    Future<(int, Map<String, Object?>)> call(
      String path, {
      SecurityContext? context,
    }) async {
      final client = HttpClient(
        context:
            context ??
            (SecurityContext()
              ..setTrustedCertificatesBytes(utf8.encode(_fixture('ca.pem')))),
      );
      try {
        final request = await client.getUrl(
          Uri.parse('https://localhost:${server.port}$path'),
        );
        final response = await request.close();
        final text = await response.transform(utf8.decoder).join();
        return (response.statusCode, jsonDecode(text) as Map<String, Object?>);
      } finally {
        client.close(force: true);
      }
    }

    setUp(() async {
      clientFingerprint = fingerprintOf(_fixture('client.pem'));
      TomMutualTls.current = TomMutualTls(
        clientAuthoritiesPem: _fixture('ca.pem'),
        services: {
          clientFingerprint: TomMutualTls.servicePrincipal(
            'orders-service',
            roles: ['service'],
          ),
        },
        requiredPaths: ['/internal'],
      );
      server = await TomMutualTls.current!.serve(
        _whoAmI(),
        InternetAddress.loopbackIPv4,
        0,
        securityContext: SecurityContext()
          ..useCertificateChainBytes(utf8.encode(serverCertificate))
          ..usePrivateKeyBytes(utf8.encode(serverKey)),
      );
    });
    tearDown(() async {
      await server.close(force: true);
      TomMutualTls.current = null;
      TomHttpClientFactory.resetGlobalHttpClientFactory();
    });

    test('a listed client certificate authenticates as its service', () async {
      final (status, body) = await call(
        '/internal/orders',
        context: clientContext('client'),
      );
      expect(status, 200);
      expect(body, {'authenticated': true, 'id': 'orders-service'});
      final (_, outside) = await call(
        '/public',
        context: clientContext('client'),
      );
      expect(outside['id'], 'orders-service');
    });

    test(
      'a required path refuses a request without a listed certificate',
      () async {
        for (final context in [null, clientContext('unmapped_client')]) {
          final (status, body) = await call(
            '/internal/orders',
            context: context,
          );
          expect(status, 401);
          expect(body['errorKey'], 'server.mutual_tls.required');
        }
        // Elsewhere such a request is simply anonymous.
        final (status, body) = await call(
          '/public',
          context: clientContext('unmapped_client'),
        );
        expect(status, 200);
        expect(body['authenticated'], isFalse);
      },
    );

    test('a certificate from a CA the server does not trust is refused '
        'at the handshake', () async {
      await expectLater(
        call(
          '/internal/orders',
          context: TomMutualTls.clientContext(
            certificateChainPem: _fixture('rogue_client.pem'),
            privateKeyPem: _fixture('rogue_client.key'),
            trustedCaPem: _fixture('ca.pem'),
          ),
        ),
        // The server's handshake refuses it. Under TLS 1.3 the client only
        // learns so when it reads: the connection closes before any answer.
        throwsA(
          anyOf(
            isA<HandshakeException>(),
            isA<SocketException>(),
            isA<HttpException>(),
          ),
        ),
      );
    });

    test('a bearer token outside the required paths wins over the '
        'certificate', () async {
      final client = HttpClient(context: clientContext('client'));
      addTearDown(() => client.close(force: true));
      final request = await client.getUrl(
        Uri.parse('https://localhost:${server.port}/public'),
      );
      request.headers.set(
        'authorization',
        'Bearer ${_signed({'userId': 'alice', 'username': 'alice'})}',
      );
      final response = await request.close();
      final body =
          jsonDecode(await response.transform(utf8.decoder).join()) as Map;
      expect(body['id'], 'alice');
    });

    test('the configured client factory presents this service\'s '
        'certificate on outgoing calls', () async {
      TomMutualTls.configure({
        'clientCa': _fixture('ca.pem'),
        'services': {
          // The openssl spelling: upper-case, colon-separated.
          [
            for (var i = 0; i < clientFingerprint.length; i += 2)
              clientFingerprint.substring(i, i + 2).toUpperCase(),
          ].join(':'): {
            'id': 'orders-service',
            'roles': ['service'],
          },
        },
        'requiredPaths': ['/internal'],
        'client': {
          'certificateChain': _fixture('client.pem'),
          'privateKey': _fixture('client.key'),
          'trustedCa': _fixture('ca.pem'),
        },
      });
      expect(
        TomMutualTls.current!.services.keys.single,
        clientFingerprint,
        reason: 'fingerprints are normalised',
      );
      final client = TomHttpClientFactory().getClient();
      addTearDown(client.close);
      final response = await client.get(
        Uri.parse('https://localhost:${server.port}/internal/orders'),
      );
      expect(response.statusCode, 200);
      expect((jsonDecode(response.body) as Map)['id'], 'orders-service');
      expect(client, isA<http.BaseClient>());
    });

    test('the configuration refuses what it cannot apply', () {
      for (final bad in <Object?>[
        'on',
        {'clientCa': 'not a certificate'},
        {
          'clientCa': _fixture('ca.pem'),
          'services': {
            'abc': {'id': 'x'},
          },
        },
        {
          'clientCa': _fixture('ca.pem'),
          'services': {
            clientFingerprint: {'roles': <String>[]},
          },
        },
        {
          'clientCa': _fixture('ca.pem'),
          'client': {'certificateChain': _fixture('client.pem')},
        },
        {'clientCa': _fixture('ca.pem'), 'requiredPath': '/internal'},
      ]) {
        expect(
          () => TomMutualTls.configure(bad),
          _throwsKey('server.mutual_tls.config.invalid'),
          reason: '$bad',
        );
      }
    });
  });

  test('TomServer.configureSecurity applies each key it finds', () {
    addTearDown(() {
      TomSecurityHeaders.current = const TomSecurityHeaders();
      TomCors.current = const TomCors();
      TomSessionCookie.current = null;
      TomMutualTls.current = null;
    });
    TomServer.configureSecurity(
      TomServerConfigResourceProvider.from({
        'securityHeaders': {'referrerPolicy': 'same-origin'},
        'cors': {
          'allowedOrigins': ['https://app.example.com'],
        },
        'sessionCookie': {'name': 'sid'},
        'mutualTls': {'clientCa': _fixture('ca.pem')},
      }),
    );
    expect(TomSecurityHeaders.current.referrerPolicy, 'same-origin');
    expect(TomCors.current.allowedOrigins, ['https://app.example.com']);
    expect(TomSessionCookie.current!.name, 'sid');
    expect(TomMutualTls.current!.services, isEmpty);
  });
}
