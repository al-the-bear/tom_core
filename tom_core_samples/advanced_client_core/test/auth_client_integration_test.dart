/// Live integration test for [AuthClient] (step 22): logs in against a running
/// `advanced_auth_server` on `localhost:8081` with the seeded `alice` account
/// and asserts the returned principal plus stored bearer.
///
/// This needs the auth server *and* its database up (see
/// `../advanced_auth_server/README.md`). Because neither is guaranteed in a
/// headless CI/dev box, the test **skips itself at runtime when the server is
/// unreachable** (a connection refusal calls [markTestSkipped] instead of
/// failing) — the unit suite (`auth_client_test.dart`) carries the always-on
/// coverage; this proves the wire path end-to-end when an operator brings the
/// server up locally.
library;

import 'dart:io';

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_client_core/reflection_seed.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:test/test.dart';

const _authBaseUri = 'http://localhost:8081';

void main() {
  setUpAll(initializeReflection);

  group('AuthClient (live auth server)', () {
    setUp(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());
    tearDown(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());

    test('TC-22-11: logs in alice and stores the bearer', () async {
      // The live transport is owned here so it can be closed regardless of
      // outcome (and so a connection refusal is observable as a SocketException).
      final transport = IoJsonTransport();
      final client = AuthClient(Uri.parse(_authBaseUri), transport: transport);

      final LoginResult result;
      try {
        result = await client.login(
            LoginRequest(username: 'alice', password: 'alice-pass'));
      } on SocketException catch (e) {
        markTestSkipped(
            'auth server not reachable on $_authBaseUri — start '
            'advanced_auth_server to run this integration test ($e)');
        return;
      } finally {
        transport.close();
      }

      expect(result.user.username, equals('alice'));
      expect(result.authzToken, isNotEmpty);
      expect(TomBearerAuthentication.authorizationToken,
          equals(result.authzToken));
    });
  });
}
