/// DB-backed tests for the suppression list and the correlation columns a
/// failure report reads.
///
/// What only a real server can substantiate: the report that suppresses an
/// address arrives on one node and the next message is sent from another, so
/// each test writes through one instance and reads through a second over the
/// same table.
///
/// The whole file is `@Tags(['db'])` and skips itself when no database is
/// reachable. Bring one up with `tool/run_db_tests.sh` (MariaDB) or
/// `tool/run_db_tests_postgres.sh` (PostgreSQL).
@Tags(['db'])
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  group('the relational suppression list', () {
    late TomDataSourceInfo dsi;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      // Dropped, not truncated: the store creates its table on first use, so a
      // previous run with different DDL would otherwise persist.
      await TestDatabase.execute(
        dsi.datasource,
        'DROP TABLE IF EXISTS $defaultSuppressionTable',
      );
      await TestDatabase.dropDeliveryReportTable(dsi);
    });

    tearDownAll(TestDatabase.reset);

    setUp(() async {
      await TomSqlSuppressionList(dsi.datasource).deleteAll();
      await TomSqlDeliveryReportStore(dsi.datasource).deleteAll();
    });

    TomSqlSuppressionList node() => TomSqlSuppressionList(dsi.datasource);

    test('DSD-1: an address suppressed on one node is left out on '
        'another', () async {
      await node().suppress(
        TomSuppressedAddress(
          channel: TomMessageChannel.sms,
          address: '+44 7700 900000',
          suppressedAt: DateTime.utc(2026, 11, 7, 9, 30),
          messageId: 'm1',
          remoteId: 'SM1',
          providerCode: '3',
          detail: 'failed',
          tenant: 'acme',
        ),
      );
      final entry = await node().find(TomMessageChannel.sms, '447700900000');
      expect(entry, isNotNull);
      expect(entry!.address, '447700900000');
      expect(entry.suppressedAt, DateTime.utc(2026, 11, 7, 9, 30));
      expect(entry.messageId, 'm1');
      expect(entry.remoteId, 'SM1');
      expect(entry.providerCode, '3');
      expect(entry.tenant, 'acme');
      expect(
        await node().suppressedAmong(TomMessageChannel.sms, [
          '+447700900000',
          '+41791234567',
        ]),
        {'+447700900000'},
      );
    });

    test('DSD-2: suppressing again replaces the entry; the channel is part '
        'of the key', () async {
      await node().suppress(
        TomSuppressedAddress(
          channel: TomMessageChannel.email,
          address: 'Dead@Example.com',
          providerCode: '550',
        ),
      );
      await node().suppress(
        TomSuppressedAddress(
          channel: TomMessageChannel.email,
          address: 'dead@example.com',
          providerCode: '551',
        ),
      );
      final all = await node().all();
      expect(all, hasLength(1));
      expect(all.single.providerCode, '551');
      expect(
        await node().find(TomMessageChannel.sms, 'dead@example.com'),
        isNull,
      );
      expect(await node().all(channel: TomMessageChannel.sms), isEmpty);
    });

    test('DSD-3: release lifts a suppression and answers whether there was '
        'one', () async {
      await node().suppress(
        TomSuppressedAddress(
          channel: TomMessageChannel.sms,
          address: '+14155552671',
        ),
      );
      expect(
        await node().release(TomMessageChannel.sms, '1 415 555 2671'),
        isTrue,
      );
      expect(
        await node().release(TomMessageChannel.sms, '+14155552671'),
        isFalse,
      );
      expect(await node().all(), isEmpty);
    });

    test('DSD-4: the correlation keeps its addresses and the code of the last '
        'report, and a failure read back suppresses its address', () async {
      final store = TomSqlDeliveryReportStore(dsi.datasource);
      await store.remember(
        TomDeliveryCorrelation(
          remoteId: 'SM9',
          messageId: 'm9',
          channel: TomMessageChannel.sms,
          sentAt: DateTime.utc(2026, 11, 7, 9),
          addresses: ['+14155552671'],
        ),
      );
      final recorded = await TomSqlDeliveryReportStore(dsi.datasource).record(
        TomDeliveryReport(
          remoteId: 'SM9',
          state: TomDeliveryState.failed,
          at: DateTime.utc(2026, 11, 7, 9, 2),
          providerCode: '30005',
        ),
      );
      expect(recorded!.addresses, ['+14155552671']);
      expect(recorded.providerCode, '30005');

      await node().applyReport(recorded);
      expect(
        await node().suppressedAmong(TomMessageChannel.sms, ['+14155552671']),
        {'+14155552671'},
      );
    });
  }, skip: skipReason);
}
