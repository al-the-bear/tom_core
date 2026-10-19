/// DB-backed tests for the relational delivery-correlation index.
///
/// What only a real server can substantiate, and what the store exists for: **a
/// carrier's delivery report arrives minutes or hours after the send, over a
/// different request, possibly on a different node.** So every test here uses
/// *two store instances over one table* — one that remembers the id, another
/// that records the report — because a store that can only answer for what it
/// itself wrote is exactly the store the memory implementation already is.
///
/// The whole file is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable, so the default `testkit :test` run stays green everywhere. Bring
/// a server up with `tool/run_db_tests.sh`.
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

  group('the relational delivery-correlation index', () {
    late TomDataSourceInfo dsi;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      // Dropped, not truncated: the store creates the table on first use, so a
      // previous run with different DDL would otherwise persist.
      await TestDatabase.dropDeliveryReportTable(dsi);
    });

    tearDownAll(TestDatabase.reset);

    setUp(() async {
      await TomSqlDeliveryReportStore(dsi.datasource).deleteAll();
    });

    /// A store instance over the shared table — one per simulated node.
    TomSqlDeliveryReportStore node() =>
        TomSqlDeliveryReportStore(dsi.datasource);

    TomDeliveryCorrelation sent({
      String remoteId = 'SM1',
      String messageId = 'm1',
      DateTime? at,
    }) => TomDeliveryCorrelation(
      remoteId: remoteId,
      messageId: messageId,
      channel: TomMessageChannel.sms,
      sentAt: at ?? DateTime.utc(2026, 9, 15, 12),
    );

    test('one node remembers, another answers', () async {
      await node().remember(sent());
      final row = await node().messageOf('SM1');
      expect(row, isNotNull);
      expect(row!.messageId, 'm1');
      expect(row.channel, TomMessageChannel.sms);
      expect(row.sentAt, DateTime.utc(2026, 9, 15, 12));
      expect(row.isReported, isFalse);
    });

    test('a report recorded on one node is visible on another', () async {
      await node().remember(sent());
      final updated = await node().record(
        TomDeliveryReport(
          remoteId: 'SM1',
          state: TomDeliveryState.delivered,
          at: DateTime.utc(2026, 9, 15, 12, 5),
          detail: 'handset',
        ),
      );
      expect(updated!.state, TomDeliveryState.delivered);

      final read = await node().messageOf('SM1');
      expect(read!.state, TomDeliveryState.delivered);
      expect(read.reportedAt, DateTime.utc(2026, 9, 15, 12, 5));
      expect(read.detail, 'handset');
      expect(read.messageId, 'm1');
    });

    test('an unremembered id records nothing and says so', () async {
      expect(
        await node().record(
          TomDeliveryReport(
            remoteId: 'nobody',
            state: TomDeliveryState.delivered,
          ),
        ),
        isNull,
      );
    });

    test('repeating a report is not mistaken for an unknown id', () async {
      // MariaDB reports *changed* rows rather than matched ones, so a carrier
      // repeating a status it already sent affects no rows — indistinguishable
      // by that count from an id nobody remembered. The store reads the row
      // back instead of believing the count, and this is the case that proves
      // it: the second call must answer the row, not null.
      await node().remember(sent());
      final report = TomDeliveryReport(
        remoteId: 'SM1',
        state: TomDeliveryState.delivered,
        at: DateTime.utc(2026, 9, 15, 12, 5),
      );
      expect((await node().record(report))!.state, TomDeliveryState.delivered);
      expect(
        (await node().record(report))!.state,
        TomDeliveryState.delivered,
        reason: 'a repeated report is still a report about a known message',
      );
    });

    test('re-sending a message replaces the row rather than failing', () async {
      // The outbox guarantees at-least-once, so a message delivered twice is a
      // documented outcome — and a carrier may hand back an id already on file.
      // The later send is the one worth keeping.
      await node().remember(sent(messageId: 'first'));
      await node().remember(sent(messageId: 'second'));
      expect((await node().messageOf('SM1'))!.messageId, 'second');
    });

    test('the state survives a round trip as itself', () async {
      // The column is text and the value is an enum name, so a state written by
      // one version and read by another must come back as the same value —
      // which is what `TomDeliveryReport.stateOf` is for.
      for (final state in TomDeliveryState.values) {
        await node().remember(sent(remoteId: state.name));
        await node().record(
          TomDeliveryReport(remoteId: state.name, state: state),
        );
        expect((await node().messageOf(state.name))!.state, state);
      }
    });

    test('the sweep drops by send time', () async {
      await node().remember(
        sent(remoteId: 'old', at: DateTime.utc(2026, 1, 1)),
      );
      await node().remember(
        sent(remoteId: 'new', at: DateTime.utc(2026, 9, 1)),
      );
      expect(await node().purgeSentBefore(DateTime.utc(2026, 6, 1)), 1);
      expect(await node().messageOf('old'), isNull);
      expect(await node().messageOf('new'), isNotNull);
    });

    test('an outbox and the index agree across a restart', () async {
      // The whole point, end to end: the id an outbox recorded through one
      // store instance is resolvable through a fresh one, which is what a
      // callback arriving after a deploy needs.
      final outbox = TomMessageOutbox(
        router: TomMessageRouter([TomMemoryMessageTransport()]),
        reportStore: node(),
      );
      addTearDown(outbox.close);

      final receipts = <TomDeliveryReceipt>[];
      final subscription = outbox.receipts.listen(receipts.add);
      addTearDown(subscription.cancel);

      await outbox.sendNow(
        TomMessage.email(
          to: [TomRecipient('ops@example.com')],
          subject: 'hello',
          text: 'hello',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final remoteId = receipts.single.remoteId;
      expect(remoteId, isNotNull);
      final row = await node().messageOf(remoteId!);
      expect(row, isNotNull);
      expect(row!.messageId, receipts.single.messageId);
      expect(row.channel, TomMessageChannel.email);
    });
  }, skip: skipReason);
}
