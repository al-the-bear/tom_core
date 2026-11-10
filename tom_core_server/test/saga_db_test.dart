/// Sagas against a live database: the SQL saga store and the SQL job store,
/// steps writing in their local transaction, compensation, a restart in the
/// middle of a saga, and a message sent through the outbox in a step's
/// transaction.
///
/// `@Tags(['db'])`, self-skipping without a server; bring one up with
/// `tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`.
@Tags(['db'])
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// A step's failure that is not worth retrying.
class _Declined implements Exception, TomPermanentFailure {
  @override
  String toString() => 'declined';
}

const _ledger = 'zz_saga_ledger';

void main() async {
  final reachable = await TestDatabase.isReachable();
  final skip = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable at '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh.';

  group('sagas over SQL', () {
    late TomDataSource ds;
    late List<String> log;
    final opened = <TomClosable>[];

    setUpAll(() async {
      initializeReflection();
      await TestDatabase.register();
      ds = TomDataSourceInfo.getDataSourceInfo(
        TestDatabase.datasourceName,
      )!.datasource;
      await ds.executeCommand(
        'CREATE TABLE IF NOT EXISTS $_ledger ('
        'entry VARCHAR(64) NOT NULL PRIMARY KEY, touched INT NOT NULL)',
      );
    });

    setUp(() async {
      log = [];
      await TomSqlSagaStore(TestDatabase.datasourceName).deleteAll();
      await TomSqlJobStore(ds).deleteAll();
      await ds.executeCommand('DELETE FROM $_ledger');
    });

    tearDown(() async {
      for (final c in opened.reversed) {
        await c.close();
      }
      opened.clear();
    });

    /// How many ledger rows there are — an update's count, which needs no
    /// mapped row type.
    Future<int> ledgerRows() async => (await ds.executeCommand(
      'UPDATE $_ledger SET touched = touched + 1',
    )).toInt();

    Future<bool> hasEntry(String entry) async =>
        (await ds.executeCommand(
          'UPDATE $_ledger SET touched = touched + 1 WHERE entry = :e',
          {'e': entry},
        )) !=
        BigInt.zero;

    TomSagaOrchestrator orchestrator() {
      final o = TomSagaOrchestrator(
        store: TomSqlSagaStore(TestDatabase.datasourceName),
        jobStore: TomSqlJobStore(ds),
      );
      opened.add(o);
      return o;
    }

    TomSagaStep write(String name, {Object? fails}) => TomSagaStep(
      name,
      action: (c) async {
        log.add(name);
        await ds.executeCommand(
          'INSERT INTO $_ledger (entry, touched) VALUES (:e, 0)',
          {'e': name},
        );
        if (fails != null) throw fails;
      },
      compensation: (c) async {
        log.add('undo $name');
        await ds.executeCommand('DELETE FROM $_ledger WHERE entry = :e', {
          'e': name,
        });
      },
    );

    TomSaga order({Object? thirdFails}) => TomSaga(
      name: 'place_order',
      retryPolicy: const TomRetryPolicy(
        maxAttempts: 1,
        maxBackoff: Duration(seconds: 1),
      ),
      steps: [
        write('reserve'),
        write('charge'),
        write('ship', fails: thirdFails),
      ],
    );

    Future<TomSagaState> settle(TomSagaOrchestrator o, String id) async {
      for (var pass = 0; pass < 200; pass++) {
        final state = await o.find(id);
        if (state!.status.isFinished) return state;
        await o.tick();
        // A started orchestrator's own pass may be under way, and a tick then
        // returns at once: give it time.
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      fail('saga $id did not finish');
    }

    test(
      'a three-step saga commits each step in its own transaction',
      () async {
        final o = orchestrator()..register(order());
        final state = await settle(o, await o.begin('place_order'));
        expect(state.status, TomSagaStatus.completed);
        expect(await ledgerRows(), 3);
      },
      skip: skip,
    );

    test('a third step that fails is rolled back, and the two before it are '
        'compensated', () async {
      final o = orchestrator()..register(order(thirdFails: _Declined()));
      final state = await settle(o, await o.begin('place_order'));
      expect(log, ['reserve', 'charge', 'ship', 'undo charge', 'undo reserve']);
      expect(state.status, TomSagaStatus.compensated);
      expect(
        await ledgerRows(),
        0,
        reason: "the third step's insert rolled back",
      );
    }, skip: skip);

    test('a restart mid-saga resumes it from the store', () async {
      final first = orchestrator()..register(order());
      final id = await first.begin('place_order');
      await first.tick();
      expect(log, ['reserve']);
      await first.close();

      final second = orchestrator()..register(order());
      await second.start();
      final state = await settle(second, id);
      expect(state.status, TomSagaStatus.completed);
      expect(log, ['reserve', 'charge', 'ship']);
      expect(await ledgerRows(), 3);
    }, skip: skip);

    test('a saga whose run was lost is queued again on resume', () async {
      final first = orchestrator()..register(order());
      final id = await first.begin('place_order');
      await first.tick();
      await first.close();
      await TomSqlJobStore(ds).deleteAll();

      final second = orchestrator()..register(order());
      expect(await second.resume(), 1);
      final state = await settle(second, id);
      expect(state.status, TomSagaStatus.completed);
      expect(log, ['reserve', 'charge', 'ship']);
    }, skip: skip);

    test('a version already left behind is not written again', () async {
      final store = TomSqlSagaStore(TestDatabase.datasourceName);
      final o = orchestrator()..register(order());
      final id = await o.begin('place_order');
      await o.tick();
      final state = (await store.load(id))!;
      expect(state.version, 1);
      expect(await store.update(state, expectedVersion: 0), isFalse);
      expect(await store.unfinished(), hasLength(1));
    }, skip: skip);

    test(
      'a message sent through the outbox in a step commits with it',
      () async {
        final outbox = TomMessageOutbox(
          router: TomMessageRouter(),
          store: TomSqlJobStore(ds),
        );
        opened.add(outbox);
        TomMessage mail(String subject) => TomMessage.email(
          to: [TomRecipient('ops@example.com')],
          subject: subject,
          text: 'saga',
        );
        final o = orchestrator()
          ..register(
            TomSaga(
              name: 'notify',
              steps: [
                TomSagaStep('sent', action: (c) => outbox.send(mail('kept'))),
                TomSagaStep(
                  'refused',
                  action: (c) async {
                    await outbox.send(mail('dropped'));
                    throw _Declined();
                  },
                ),
              ],
            ),
          );
        await settle(o, await o.begin('notify'));
        final subjects = [
          for (final run in await TomSqlJobStore(ds).all())
            if (run.jobName == tomOutboxJobName)
              (run.payload as Map)['subject'],
        ];
        expect(subjects, ['kept']);
      },
      skip: skip,
    );

    test('two outbox messages queued in one instant are both kept', () async {
      final at = DateTime.utc(2026, 10, 20, 12);
      final queue = TomSqlJobStore(ds);
      final outbox = TomMessageOutbox(
        router: TomMessageRouter(),
        store: queue,
        clock: () => at,
      );
      opened.add(outbox);
      for (var i = 0; i < 2; i++) {
        await outbox.send(
          TomMessage.email(
            to: [TomRecipient('ops@example.com')],
            subject: 's$i',
            text: 't',
          ),
        );
      }
      expect(await queue.all(), hasLength(2));
    }, skip: skip);

    test('the ledger helper counts', () async {
      await ds.executeCommand(
        'INSERT INTO $_ledger (entry, touched) VALUES (:e, 0)',
        {'e': 'x'},
      );
      expect(await hasEntry('x'), isTrue);
      expect(await hasEntry('y'), isFalse);
    }, skip: skip);
  }, skip: skip);
}
