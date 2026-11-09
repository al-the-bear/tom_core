/// Holds `example/` to the client core it demonstrates.
///
/// The example's work lives in `listWorkspacesAs`, which takes its transport
/// as a parameter precisely so this suite can run the same sequence the example
/// teaches — config, login, one authenticated call — without a server. The
/// second case runs the example the way its header tells a reader to, which
/// needs the live stack; with none running it asserts the documented failure
/// instead: a one-line hint and exit status 2, never a stack trace.
library;

import 'dart:convert';
import 'dart:io';

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_client_core/reflection_seed.dart';
import 'package:test/test.dart';

import '../example/authenticated_call_example.dart' as example;

void main() {
  setUpAll(initializeReflection);

  group('example/authenticated_call_example.dart', () {
    test('logs in, then lists workspaces with the bearer attached', () async {
      final jwt = _makeJwt({'username': 'alice', 'userId': 2});
      final transport = _ScriptedTransport({
        '/auth/login': HttpJsonResponse(
          200,
          jsonEncode({
            'user': {'id': '2', 'username': 'alice', 'status': 'active'},
            'authToken': jwt,
            'authzToken': jwt,
            'expiresAt': '2026-06-28T12:34:56.000Z',
          }),
        ),
        '/workspaces': HttpJsonResponse(
          200,
          jsonEncode([
            {'id': '1', 'name': 'Acme Engineering', 'ownerId': '2'},
            {'id': '2', 'name': 'Personal', 'ownerId': '2'},
          ]),
        ),
      });

      final names = await example.listWorkspacesAs(
        const AdvancedClientConfig(),
        transport,
        username: 'alice',
        password: 'alice-pass',
      );

      expect(names, ['Acme Engineering', 'Personal']);
      // Login first, against the auth server; then the call, against the app
      // server, carrying the bearer the login stored.
      expect(transport.calls.map((c) => '${c.method} ${c.uri}'), [
        'POST http://localhost:8081/auth/login',
        'GET http://localhost:8080/workspaces',
      ]);
      expect(transport.calls.last.headers['Authorization'], 'Bearer $jwt');
    });

    test('runs under its documented command', () async {
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        'example/authenticated_call_example.dart',
      ]);

      if (result.exitCode == 0) {
        // A stack is up: the example reached it.
        expect(result.stdout, contains('workspace(s):'));
        return;
      }
      expect(result.exitCode, 2, reason: '${result.stderr}');
      expect(result.stderr, contains('No server answered'));
      expect(result.stderr, contains('tool/run_cross_tier_integration.sh'));
      expect(result.stderr, isNot(contains('#0 ')), reason: 'no stack trace');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

/// A [JsonTransport] that answers each path with one scripted response and
/// records what was sent.
class _ScriptedTransport implements JsonTransport {
  _ScriptedTransport(this._responses);
  final Map<String, HttpJsonResponse> _responses;
  final List<({String method, Uri uri, Map<String, String> headers})> calls =
      [];

  @override
  Future<HttpJsonResponse> send({
    required String method,
    required Uri uri,
    Map<String, String> headers = const {},
    String? body,
  }) async {
    calls.add((method: method, uri: uri, headers: headers));
    final response = _responses[uri.path];
    if (response == null) throw StateError('unscripted ${uri.path}');
    return response;
  }
}

/// An unsigned JWT whose middle segment carries [payload] — the client stores
/// tokens without decrypting them, so no key is involved.
String _makeJwt(Map<String, dynamic> payload) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.${seg({'exp': 4102444800, ...payload})}.sig';
}
