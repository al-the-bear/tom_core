/// Live integration smoke test for [AdminApiClient] (step 25): logs in as the
/// seeded `admin` against `advanced_auth_server` (`localhost:8081`) and pulls the
/// user list through the authorized transport.
///
/// The done bar names a *list* endpoint deliberately: `adminListUsers` serializes
/// over the live wire as a bare JSON array of `UserDto.toJson()` maps (the
/// framework's `result is List<Object>` pipeline branch), so it round-trips
/// today. A *single*-DTO admin response cannot round-trip against the live server
/// until the kernel's reflection-serializer gap is fixed — see
/// `admin_api_client.dart`'s library doc and `step25_admin_api_client_decisions.md`.
/// Admin DTOs are plain value records, so no `initializeReflection` is needed
/// (unlike the app API's reflected entities).
///
/// This needs the auth server *and* its database up. Because neither is
/// guaranteed in a headless CI/dev box, the test **skips itself at runtime when
/// the server is unreachable** (a connection refusal calls [markTestSkipped]
/// instead of failing) — the socket-free unit suite (`admin_api_client_test.dart`)
/// carries the always-on coverage; this proves the wire path end-to-end when an
/// operator brings the stack up.
library;

import 'dart:io';

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:test/test.dart';

const _authBaseUri = 'http://localhost:8081';

void main() {
  group('AdminApiClient (live auth server)', () {
    setUp(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());
    tearDown(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());

    test('TC-25-14: admin logs in, then lists users', () async {
      // One live transport, shared by AuthClient and AdminApiClient (the
      // runtime wiring), closed regardless of outcome.
      final transport = IoJsonTransport();
      final authBase = Uri.parse(_authBaseUri);
      final auth = AuthClient(authBase, transport: transport);
      final client = AdminApiClient(authBase, AuthorizedHttp(transport, auth));

      try {
        await auth.login(
            const LoginRequest(username: 'admin', password: 'admin-pass'));
        final users = await client.listUsers();
        // The seed always contains at least the `admin` and `alice` principals.
        expect(users, isNotEmpty);
      } on SocketException catch (e) {
        markTestSkipped(
            'auth server not reachable on $_authBaseUri — start '
            'advanced_auth_server to run this integration test ($e)');
        return;
      } finally {
        transport.close();
      }
    });
  });
}
