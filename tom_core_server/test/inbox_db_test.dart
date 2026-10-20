/// The SQL inbox against a live database: the message record and the
/// consumer's own write commit together, so a redelivered message changes the
/// data once, a failed one changes nothing, and two simultaneous deliveries are
/// serialised by the inbox's key.
///
/// `@Tags(['db'])`, self-skipping without a server; bring one up with
/// `tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`.
@Tags(['db'])
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// The consumer's own table: one row per charge it made.
const String _ledgerDdl = '''
CREATE TABLE IF NOT EXISTS inbox_test_ledger (
  message_id VARCHAR(191) NOT NULL,
  amount     INT          NOT NULL
)''';

void main() async {
  final reachable = await TestDatabase.isReachable();
  final skip = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable at '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh.';

  group('TomSqlInbox', () {
    late TomDataSource ds;
    late TomSqlInbox inbox;

    setUpAll(() async {
      initializeReflection();
      ds = (await TestDatabase.register()).datasource;
      await TestDatabase.execute(ds, _ledgerDdl);
    });

    setUp(() async {
      inbox = TomSqlInbox(ds);
      await inbox.deleteAll();
      await ds.executeCommand('DELETE FROM inbox_test_ledger');
    });

    /// The consumer's work: charge the message's amount.
    Future<void> charge(String messageId, int amount) => ds.executeCommand(
      'INSERT INTO inbox_test_ledger (message_id, amount) VALUES (:m, :a)',
      {'m': messageId, 'a': amount},
    );

    Future<int> charges() async {
      final rows = await ds.executeQuery<Object>(
        'SELECT message_id FROM inbox_test_ledger',
      );
      return rows.length;
    }

    test(
      'a redelivered message charges once and is acknowledged twice',
      () async {
        var acks = 0;
        for (var delivery = 0; delivery < 2; delivery++) {
          await inbox.process(
            'billing',
            'order-1',
            () => charge('order-1', 42),
            acknowledge: () => acks++,
          );
        }
        expect(await charges(), 1);
        expect(acks, 2);
        expect(await inbox.hasProcessed('billing', 'order-1'), isTrue);
      },
    );

    test(
      'a delivery that fails after its write leaves nothing behind',
      () async {
        var acked = false;
        await expectLater(
          inbox.process('billing', 'order-2', () async {
            await charge('order-2', 10);
            throw StateError('the payment provider refused');
          }, acknowledge: () => acked = true),
          throwsStateError,
        );
        expect(acked, isFalse, reason: 'unacknowledged, so it is redelivered');
        expect(
          await charges(),
          0,
          reason: 'the write rolled back with the record',
        );
        expect(await inbox.hasProcessed('billing', 'order-2'), isFalse);

        // The redelivery processes it.
        expect(
          await inbox.process(
            'billing',
            'order-2',
            () => charge('order-2', 10),
          ),
          TomInboxOutcome.processed,
        );
        expect(await charges(), 1);
      },
    );

    test('two simultaneous deliveries charge once', () async {
      Future<TomInboxOutcome> deliver() =>
          inbox.process('billing', 'order-3', () async {
            await charge('order-3', 5);
            // Hold the transaction open, so the other delivery's insert
            // reaches the key while this one has not committed.
            await Future<void>.delayed(const Duration(milliseconds: 300));
          });
      final outcomes = await Future.wait([deliver(), deliver()]);
      expect(outcomes.toSet(), {
        TomInboxOutcome.processed,
        TomInboxOutcome.duplicate,
      });
      expect(await charges(), 1);
    });

    test('consumers are kept apart; old records are purged', () async {
      await inbox.process('billing', 'order-4', () => charge('order-4', 1));
      await inbox.process('notifier', 'order-4', () {});
      expect(await inbox.hasProcessed('notifier', 'order-4'), isTrue);
      expect(
        await inbox.purgeProcessedBefore(
          DateTime.now().add(const Duration(minutes: 1)),
        ),
        2,
      );
      expect(await inbox.hasProcessed('billing', 'order-4'), isFalse);
    });
  }, skip: skip);
}
