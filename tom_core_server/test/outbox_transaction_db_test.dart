/// A message queued on the outbox inside a database transaction commits or
/// rolls back with the transaction: the business write and the enqueue are one
/// unit, with no broker.
///
/// Three placements of the outbox's job store: on the data source the
/// transaction writes, on a different one, and — under `schema` tenancy — on
/// the unrouted base data source while the business write goes to the tenant's
/// schema.
///
/// `@Tags(['db'])`, self-skipping without a server; bring one up with
/// `tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`.
@Tags(['db'])
library;

import 'package:test/test.dart';
import 'package:tom_core_message_bus/tom_core_message_bus.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

const _orderDdl =
    'CREATE TABLE IF NOT EXISTS outbox_tx_order ('
    'id VARCHAR(64) NOT NULL PRIMARY KEY, total INT NOT NULL)';

/// A transport accepting everything; the tests are about the queue.
class _AcceptingTransport extends TomMessageTransport {
  @override
  TomMessageChannel get channel => TomMessageChannel.sms;

  @override
  Future<TomDeliveryReceipt> send(TomMessage message) async =>
      TomDeliveryReceipt(
        messageId: message.id,
        outcome: TomDeliveryOutcome.delivered,
        at: DateTime.utc(2026, 11, 3),
      );
}

TomMessage _confirmation(String id) => TomMessage(
  id: id,
  channel: TomMessageChannel.sms,
  recipients: [TomRecipient('+41791234567')],
  bodies: [TomMessageBody.text('order $id confirmed')],
);

/// Places an order and queues its confirmation in one transaction; throws
/// after both when [fail] is set.
Future<void> _placeOrder(
  TomDataSource orders,
  TomMessageOutbox outbox,
  String id, {
  bool fail = false,
}) => TomTransactionManager.runInTransaction((transaction) async {
  await orders.executeCommand(
    'INSERT INTO outbox_tx_order (id, total) VALUES (:id, 42)',
    {'id': id},
  );
  await outbox.send(_confirmation(id));
  if (fail) throw StateError('the order is refused after the enqueue');
});

Future<int> _orderCount(TomDataSource orders, String id) async {
  final rows = await orders.executeQuery<TomCountResult>(
    'SELECT COUNT(*) AS count FROM outbox_tx_order WHERE id = :id',
    {'id': id},
  );
  return rows.single.count;
}

void main() async {
  final reachable = await TestDatabase.isReachable();
  final skip = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable at '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh.';

  late TomDataSourceInfo base;

  setUpAll(() async {
    if (!reachable) return;
    initializeReflection();
    base = await TestDatabase.register();
    await base.datasource.executeCommand(_orderDdl);
  });

  group('on the data source the transaction writes', () {
    late TomSqlJobStore store;
    late TomMessageOutbox outbox;

    setUp(() {
      // A store that has not created its tables yet: the first enqueue
      // provisions them, and that DDL must not commit the caller's work.
      store = TomSqlJobStore(
        base.datasource,
        table: 'outbox_tx_runs',
        pauseTable: 'outbox_tx_runs_pause',
        archiveTable: null,
      );
      outbox = TomMessageOutbox(
        router: TomMessageRouter([_AcceptingTransport()]),
        store: store,
      );
    });
    tearDown(() async {
      await outbox.close();
      await base.datasource.executeCommand(
        'DROP TABLE IF EXISTS outbox_tx_runs',
      );
      await base.datasource.executeCommand(
        'DROP TABLE IF EXISTS outbox_tx_runs_pause',
      );
      await base.datasource.executeCommand('DELETE FROM outbox_tx_order');
    });

    test('a rolled-back transaction leaves no outbox row', () async {
      await expectLater(
        _placeOrder(base.datasource, outbox, 'rb-1', fail: true),
        throwsStateError,
      );
      expect(await store.findRun('${outbox.jobName}:rb-1'), isNull);
      expect(await _orderCount(base.datasource, 'rb-1'), 0);
    });

    test('a committed transaction leaves exactly one', () async {
      await _placeOrder(base.datasource, outbox, 'ok-1');
      final run = await store.findRun('${outbox.jobName}:ok-1');
      expect(run, isNotNull);
      expect(run!.state, TomJobRunState.pending);
      expect(await _orderCount(base.datasource, 'ok-1'), 1);
      expect((await store.backlog(DateTime.now())).single.due, 1);

      // Queued once: a repeated send in a new transaction adds nothing.
      await TomTransactionManager.runInTransaction(
        (_) => outbox.send(_confirmation('ok-1')),
      );
      expect((await store.backlog(DateTime.now())).single.due, 1);
    });

    test('the enqueue runs in the transaction\'s own branch', () async {
      late List<String> participants;
      await TomTransactionManager.runInTransaction((transaction) async {
        await base.datasource.executeCommand(
          'INSERT INTO outbox_tx_order (id, total) VALUES (:id, 1)',
          {'id': 'one-branch'},
        );
        await outbox.send(_confirmation('one-branch'));
        participants = transaction.participantIds;
      });
      expect(participants, [base.datasource.getParticipantId()]);
    });
  }, skip: skip);

  group('the bus relay, on the data source the transaction writes', () {
    late TomSqlJobStore store;
    late TomMemoryMessageBus bus;
    late TomBusRelay relay;

    setUp(() {
      store = TomSqlJobStore(
        base.datasource,
        table: 'outbox_tx_relay_runs',
        pauseTable: 'outbox_tx_relay_runs_pause',
        archiveTable: null,
      );
      bus = TomMemoryMessageBus();
      relay = TomBusRelay(bus: bus, store: store);
    });
    tearDown(() async {
      await relay.close();
      await bus.close();
      await base.datasource.executeCommand(
        'DROP TABLE IF EXISTS outbox_tx_relay_runs',
      );
      await base.datasource.executeCommand(
        'DROP TABLE IF EXISTS outbox_tx_relay_runs_pause',
      );
      await base.datasource.executeCommand('DELETE FROM outbox_tx_order');
    });

    test('a rolled-back transaction publishes nothing; a committed one '
        'publishes once', () async {
      final received = <String>[];
      await bus.subscribe<Object?>(
        'orders',
        group: 'billing',
        handler: (d) => received.add(d.message.id),
      );
      Future<void> place(String id, {bool fail = false}) =>
          TomTransactionManager.runInTransaction((_) async {
            await base.datasource.executeCommand(
              'INSERT INTO outbox_tx_order (id, total) VALUES (:id, 1)',
              {'id': id},
            );
            await relay.publish('orders', {'order': id}, id: id);
            if (fail) throw StateError('refused');
          });

      await expectLater(place('relay-rb', fail: true), throwsStateError);
      await place('relay-ok');
      await relay.tick();
      await bus.settled();
      expect(received, ['relay-ok']);
      expect(await store.findRun('${relay.jobName}:relay-rb'), isNull);
    });
  }, skip: skip);

  group('on a different data source', () {
    const otherName = 'tom_core_server_test_outbox';
    late TomSqlDatasource other;
    late TomSqlJobStore store;
    late TomMessageOutbox outbox;

    final otherDatabase = '${TestDatabase.databaseName}_outbox';

    setUpAll(() async {
      await TestDatabase.createDatabase(base.datasource, otherDatabase);
      await TomDataSourceInfo.initializeDatasourceInfo({
        otherName: {
          ...TestDatabase.datasourceConfig[TestDatabase.datasourceName]
              as Map<String, dynamic>,
          'databaseName': otherDatabase,
        },
      });
      other =
          TomDataSourceInfo.getDataSourceInfo(otherName)!.datasource
              as TomSqlDatasource;
    });
    tearDownAll(() async {
      await other.close();
      await TestDatabase.dropDatabase(base.datasource, otherDatabase);
    });

    setUp(() async {
      store = TomSqlJobStore(
        other,
        table: 'outbox_tx_other_runs',
        pauseTable: 'outbox_tx_other_runs_pause',
        archiveTable: null,
      );
      await store.ensureSchema();
      outbox = TomMessageOutbox(
        router: TomMessageRouter([_AcceptingTransport()]),
        store: store,
      );
    });
    tearDown(() async {
      await outbox.close();
      await other.executeCommand('DROP TABLE IF EXISTS outbox_tx_other_runs');
      await other.executeCommand(
        'DROP TABLE IF EXISTS outbox_tx_other_runs_pause',
      );
      await base.datasource.executeCommand('DELETE FROM outbox_tx_order');
    });

    test('the enqueue is a participant of its own, and rolls back with '
        'the transaction', () async {
      late List<String> participants;
      await expectLater(
        TomTransactionManager.runInTransaction((transaction) async {
          await base.datasource.executeCommand(
            'INSERT INTO outbox_tx_order (id, total) VALUES (:id, 1)',
            {'id': 'other-rb'},
          );
          await outbox.send(_confirmation('other-rb'));
          participants = transaction.participantIds;
          throw StateError('refused');
        }),
        throwsStateError,
      );
      expect(participants, hasLength(2));
      expect(await store.findRun('${outbox.jobName}:other-rb'), isNull);
      expect(await _orderCount(base.datasource, 'other-rb'), 0);
    });

    test('and commits with it', () async {
      await _placeOrder(base.datasource, outbox, 'other-ok');
      expect(await store.findRun('${outbox.jobName}:other-ok'), isNotNull);
      expect(await _orderCount(base.datasource, 'other-ok'), 1);
    });
  }, skip: skip);

  group('under schema tenancy, on the unrouted base data source', () {
    late TomTenancy tenancy;
    late TomSqlJobStore store;
    late TomMessageOutbox outbox;
    final schema = '${TestDatabase.databaseName}_acme';

    TomDataSource routed() => TomDataSourceInfo.getDataSourceInfo(
      TestDatabase.datasourceName,
    )!.datasource;

    setUpAll(() async {
      tenancy = TomTenancy(
        tenants: [TomTenant('acme', isolation: TomTenantIsolation.schema)],
        datasources: {TestDatabase.datasourceName},
        createSchemas: true,
      );
      await TomTenancy.install(tenancy);
      await tenancy.runFor('acme', () => routed().executeCommand(_orderDdl));
      store = TomSqlJobStore(
        base.datasource,
        table: 'outbox_tx_tenant_runs',
        pauseTable: 'outbox_tx_tenant_runs_pause',
        archiveTable: null,
      );
      await store.ensureSchema();
      outbox = TomMessageOutbox(
        router: TomMessageRouter([_AcceptingTransport()]),
        store: store,
      );
    });
    tearDownAll(() async {
      await outbox.close();
      await TomTenancy.reset();
      await base.datasource.executeCommand(
        'DROP TABLE IF EXISTS outbox_tx_tenant_runs',
      );
      await base.datasource.executeCommand(
        'DROP TABLE IF EXISTS outbox_tx_tenant_runs_pause',
      );
      await TestDatabase.dropSchema(base.datasource, schema);
    });

    test(
      'the enqueue joins the tenant\'s branch and rolls back with it',
      () async {
        late List<String> participants;
        await expectLater(
          tenancy.runFor(
            'acme',
            () => TomTransactionManager.runInTransaction((transaction) async {
              await routed().executeCommand(
                'INSERT INTO outbox_tx_order (id, total) VALUES (:id, 1)',
                {'id': 'tenant-rb'},
              );
              await outbox.send(_confirmation('tenant-rb'));
              participants = transaction.participantIds;
              throw StateError('refused');
            }),
          ),
          throwsStateError,
        );
        expect(participants, hasLength(1), reason: 'one branch, one commit');
        expect(await store.findRun(_acmeRun(outbox, 'tenant-rb')), isNull);
      },
    );

    test('commits once, in the base schema the scheduler reads', () async {
      await tenancy.runFor(
        'acme',
        () => _placeOrder(routed(), outbox, 'tenant-ok'),
      );
      final run = await store.findRun(_acmeRun(outbox, 'tenant-ok'));
      expect(run, isNotNull);
      expect(run!.tenant, 'acme');
      expect(
        await tenancy.runFor('acme', () => _orderCount(routed(), 'tenant-ok')),
        1,
      );

      // Delivered by the outbox's scheduler from the base schema.
      await outbox.tick();
      expect(
        (await store.findRun(_acmeRun(outbox, 'tenant-ok')))!.state,
        TomJobRunState.succeeded,
      );
    });
  }, skip: skip);
}

/// The run id [outbox] files the message [id] under when it is sent in the
/// tenant `acme`.
String _acmeRun(TomMessageOutbox outbox, String id) =>
    TomTenantContext.run('acme', () => outbox.runIdOf(id));
