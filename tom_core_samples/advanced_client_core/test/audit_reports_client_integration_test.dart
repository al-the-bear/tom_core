/// Live integration test for [AuditReportsClient]: the framework's
/// `/audit-reports` API on a running `advanced_app_server` (`localhost:8080`),
/// called as the seeded auditor `audrey` once logged in against
/// `advanced_auth_server` (`localhost:8081`).
///
/// The API reads `app_db`'s audit trail and keeps questions in its
/// `tom_audit_question`, both created by the ops server's migrations ([100],
/// [101]); `tool/run_cross_tier_integration.sh` applies them once the app
/// server is up. The suite **skips itself at runtime when a server is
/// unreachable**, like every live suite of this package.
library;

import 'dart:io';

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_client_core/reflection_seed.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

const _appBaseUri = 'http://localhost:8080';
const _authBaseUri = 'http://localhost:8081';

void main() {
  setUpAll(initializeReflection);

  group('AuditReportsClient (live app server)', () {
    setUp(
      () => TomBearerAuthentication.bearerAuthentication =
          TomBearerAuthentication(),
    );
    tearDown(
      () => TomBearerAuthentication.bearerAuthentication =
          TomBearerAuthentication(),
    );

    test('AR-LIVE-1: audrey asks the trail, saves a question, answers it, '
        'marks it for delivery and removes it; alice is refused', () async {
      final transport = HttpJsonTransport();
      final auth = AuthClient(Uri.parse(_authBaseUri), transport: transport);
      final client = AuditReportsClient(
        Uri.parse(_appBaseUri),
        AuthorizedHttp(transport, auth),
      );

      try {
        await auth.login(
          LoginRequest(username: 'audrey', password: 'audrey-pass'),
        );

        final writers = await client.writers();
        final everything = await client.query({'limit': 50});
        expect(everything.writers, writers);
        expect(everything.entries.length, lessThanOrEqualTo(50));
        for (final entry in everything.entries) {
          expect(writers, contains(entry.writer));
          expect(entry.hash, isNotEmpty);
        }

        final saved = await client.save(
          TomAuditQuestionDto(
            name: 'Denied in the last day',
            filter: {'outcome': 'denied', 'lastHours': 24},
            recipients: ['audrey@example.com'],
            format: 'csv',
          ),
        );
        expect(saved.id, isNotEmpty);
        expect(saved.nextDeliveryAt, isEmpty, reason: 'no schedule');
        expect([
          for (final question in await client.questions()) question.id,
        ], contains(saved.id));

        final answered = await client.answer(saved.id);
        for (final entry in answered.entries) {
          expect(entry.record['outcome'], 'denied');
        }

        final marked = await client.deliver(saved.id);
        expect(marked.nextDeliveryAt, isNotEmpty);

        await expectLater(
          client.query({'colour': 'red'}),
          throwsA(
            isA<AuditReportsException>()
                .having((e) => e.statusCode, 'status', 400)
                .having((e) => e.key, 'key', 'audit_reports.question.invalid'),
          ),
        );

        await client.delete(saved.id);
        await expectLater(
          client.answer(saved.id),
          throwsA(
            isA<AuditReportsException>().having(
              (e) => e.statusCode,
              'status',
              404,
            ),
          ),
        );

        // Without the auditor role the routes answer as if they did not exist.
        await auth.login(
          LoginRequest(username: 'alice', password: 'alice-pass'),
        );
        await expectLater(
          client.writers(),
          throwsA(
            isA<AuditReportsException>().having(
              (e) => e.statusCode,
              'status',
              404,
            ),
          ),
        );
      } on SocketException catch (e) {
        markTestSkipped(
          'app/auth server not reachable on $_appBaseUri/$_authBaseUri — '
          'start advanced_app_server + advanced_auth_server to run this '
          'integration test ($e)',
        );
        return;
      } finally {
        transport.close();
      }
    });
  });
}
