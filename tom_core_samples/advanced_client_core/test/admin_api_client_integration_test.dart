/// Live integration smoke test for [AdminApiClient]: logs in as the
/// seeded `admin` against `advanced_auth_server` (`localhost:8081`) and pulls the
/// user list through the authorized transport.
///
/// `adminListUsers` serializes over the live wire as a bare JSON array of
/// reflected `UserDto` maps (the framework's `result is List<Object>` pipeline
/// branch); single-DTO admin responses also round-trip now that the DTOs are
/// reflection-first and the pipeline serializes them via the reflection encoder.
/// Because the parsers construct reflection-first DTOs, the combined
/// domain+contracts seed must be installed once (`initializeReflection`).
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
import 'package:advanced_client_core/reflection_seed.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:test/test.dart';

const _authBaseUri = 'http://localhost:8081';

void main() {
  setUpAll(initializeReflection);

  group('AdminApiClient (live auth server)', () {
    setUp(
      () => TomBearerAuthentication.bearerAuthentication =
          TomBearerAuthentication(),
    );
    tearDown(
      () => TomBearerAuthentication.bearerAuthentication =
          TomBearerAuthentication(),
    );

    test('TC-25-14: admin logs in, then lists users', () async {
      // One live transport, shared by AuthClient and AdminApiClient (the
      // runtime wiring), closed regardless of outcome.
      final transport = HttpJsonTransport();
      final authBase = Uri.parse(_authBaseUri);
      final auth = AuthClient(authBase, transport: transport);
      final client = AdminApiClient(authBase, AuthorizedHttp(transport, auth));

      try {
        await auth.login(
          LoginRequest(username: 'admin', password: 'admin-pass'),
        );
        final users = await client.listUsers();
        // The seed always contains at least the `admin` and `alice` principals.
        expect(users, isNotEmpty);
      } on SocketException catch (e) {
        markTestSkipped(
          'auth server not reachable on $_authBaseUri — start '
          'advanced_auth_server to run this integration test ($e)',
        );
        return;
      } finally {
        transport.close();
      }
    });

    // A malformed id is raised *inside* an endpoint method by the server's
    // persistence mapping, which the framework pipeline would otherwise turn
    // into an opaque 500 — the auth server's per-endpoint
    // `AdminEndpointErrorHandler` is what makes it the 400 it is. Reading the
    // pipeline is not enough to know that: the mapping only holds because the
    // handler is declared on the `@TomApiImplementation` *and* survives
    // reflection generation, so this asserts it over a real socket.
    test('TC-25-15: a malformed member id is a 400, not a 500', () async {
      final transport = HttpJsonTransport();
      final authBase = Uri.parse(_authBaseUri);
      final auth = AuthClient(authBase, transport: transport);
      final client = AdminApiClient(authBase, AuthorizedHttp(transport, auth));

      try {
        await auth.login(
          LoginRequest(username: 'admin', password: 'admin-pass'),
        );

        final before = await client.listGroups();

        await expectLater(
          () => client.createGroup(
            GroupDto(
              name: 'Rejected by a bad member id',
              memberUserIds: const ['not-an-id'],
            ),
          ),
          throwsA(
            isA<AdminApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having((e) => e.key, 'key', malformedIdKey),
          ),
        );

        // The membership is checked before the group row is written, and there
        // is no transaction to undo it — so a rejected create must leave no
        // orphan group behind on the live database either.
        expect(await client.listGroups(), hasLength(before.length));
      } on SocketException catch (e) {
        markTestSkipped(
          'auth server not reachable on $_authBaseUri — start '
          'advanced_auth_server to run this integration test ($e)',
        );
        return;
      } finally {
        transport.close();
      }
    });
  });
}
