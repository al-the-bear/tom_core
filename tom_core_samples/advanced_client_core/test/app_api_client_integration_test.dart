/// Live integration smoke test for [AppApiClient] (step 24): hits the public
/// `GET /status` on a running `advanced_app_server` (`localhost:8080`), then —
/// once logged in against `advanced_auth_server` (`localhost:8081`) — pulls the
/// seeded `alice`'s workspaces through the authorized transport.
///
/// This needs both servers *and* their databases up (see the servers'
/// READMEs). Because neither is guaranteed in a headless CI/dev box, the test
/// **skips itself at runtime when a server is unreachable** (a connection
/// refusal calls [markTestSkipped] instead of failing) — the socket-free unit
/// suite (`app_api_client_test.dart`) carries the always-on coverage; this
/// proves the wire path end-to-end when an operator brings the stack up.
library;

import 'dart:io';

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_client_core/reflection_seed.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:test/test.dart';

const _appBaseUri = 'http://localhost:8080';
const _authBaseUri = 'http://localhost:8081';

void main() {
  setUpAll(initializeReflection);

  group('AppApiClient (live app server)', () {
    setUp(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());
    tearDown(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());

    test('TC-24-14: health is ok, then alice lists her workspaces', () async {
      // One live transport, shared by AuthClient and AppApiClient (the
      // runtime wiring), closed regardless of outcome.
      final transport = IoJsonTransport();
      final auth = AuthClient(Uri.parse(_authBaseUri), transport: transport);
      final client =
          AppApiClient(Uri.parse(_appBaseUri), AuthorizedHttp(transport, auth));

      try {
        final health = await client.health();
        expect(health['status'], equals('ok'));

        await auth.login(
            LoginRequest(username: 'alice', password: 'alice-pass'));
        final workspaces = await client.listWorkspaces();
        // alice owns at least the seeded starter workspace.
        expect(workspaces, isNotEmpty);
      } on SocketException catch (e) {
        markTestSkipped(
            'app/auth server not reachable on $_appBaseUri/$_authBaseUri — '
            'start advanced_app_server + advanced_auth_server to run this '
            'integration test ($e)');
        return;
      } finally {
        transport.close();
      }
    });
  });
}
