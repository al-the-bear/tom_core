/// Sagas in memory: the orchestration, compensation, retries, resumption after
/// a restart, and the definitions' and arguments' validation.
///
/// `saga_db_test.dart` runs the same flows over the SQL saga and job stores.
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// A step's failure that is not worth retrying.
class _Declined implements Exception, TomPermanentFailure {
  @override
  String toString() => 'declined';
}

void main() {
  late DateTime now;
  late List<String> log;
  late TomMemorySagaStore store;
  late TomMemoryJobStore jobs;
  late List<TomJobAlert> alerts;
  final opened = <TomSagaOrchestrator>[];

  setUp(() {
    now = DateTime.utc(2026, 10, 20, 12);
    log = [];
    store = TomMemorySagaStore();
    jobs = TomMemoryJobStore();
    alerts = [];
  });

  tearDown(() async {
    for (final orchestrator in opened) {
      await orchestrator.close();
    }
    opened.clear();
  });

  TomSagaOrchestrator orchestrator() {
    final o = TomSagaOrchestrator(
      store: store,
      jobStore: jobs,
      clock: () => now,
      onAlert: alerts.add,
    );
    opened.add(o);
    return o;
  }

  const quickRetry = TomRetryPolicy(
    maxAttempts: 2,
    initialBackoff: Duration.zero,
    maxBackoff: Duration(seconds: 1),
    jitter: 0,
  );

  TomSagaStep step(String name, {bool compensable = true, Object? fails}) =>
      TomSagaStep(
        name,
        action: (context) {
          log.add('$name#${context.attempt}');
          if (fails != null) throw fails;
          context.data[name] = 'done';
        },
        compensation: compensable ? (context) => log.add('undo $name') : null,
      );

  TomSaga order({Object? thirdFails, TomRetryPolicy retry = quickRetry}) =>
      TomSaga(
        name: 'place_order',
        retryPolicy: retry,
        compensationRetryPolicy: quickRetry,
        steps: [
          step('reserve'),
          step('charge'),
          step('ship', fails: thirdFails),
        ],
      );

  /// Ticks [o] until saga [id] has finished; fails the test after 20 passes.
  Future<TomSagaState> settle(TomSagaOrchestrator o, String id) async {
    for (var pass = 0; pass < 20; pass++) {
      final state = await o.find(id);
      if (state!.status.isFinished) return state;
      await o.tick();
      // A started orchestrator's own pass may be under way, and a tick then
      // returns at once: let it run.
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    fail('saga $id did not finish');
  }

  group('a saga that succeeds', () {
    test('runs its steps in order and completes', () async {
      final o = orchestrator()..register(order());
      final id = await o.begin('place_order', data: {'order': 42});
      final state = await settle(o, id);
      expect(state.status, TomSagaStatus.completed);
      expect(log, ['reserve#1', 'charge#1', 'ship#1']);
      expect(state.data, {
        'order': 42,
        'reserve': 'done',
        'charge': 'done',
        'ship': 'done',
      });
      expect(state.version, 3);
    });

    test('a step sees what the steps before it recorded', () async {
      Object? seen;
      final o = orchestrator()
        ..register(
          TomSaga(
            name: 'pair',
            steps: [
              TomSagaStep('a', action: (c) => c.data['ref'] = 'R-1'),
              TomSagaStep('b', action: (c) => seen = c.data['ref']),
            ],
          ),
        );
      await settle(o, await o.begin('pair'));
      expect(seen, 'R-1');
    });
  });

  group('a saga whose third step fails', () {
    test('compensates the two steps before it, last first', () async {
      final o = orchestrator()..register(order(thirdFails: _Declined()));
      final id = await o.begin('place_order');
      final state = await settle(o, id);
      expect(log, [
        'reserve#1',
        'charge#1',
        'ship#1',
        'undo charge',
        'undo reserve',
      ]);
      expect(state.status, TomSagaStatus.compensated);
      expect(state.error, contains("step 'ship'"));
      expect(state.error, contains('declined'));
    });

    test(
      'retries the step by the saga\'s policy before compensating',
      () async {
        final o = orchestrator()
          ..register(order(thirdFails: StateError('down')));
        final state = await settle(o, await o.begin('place_order'));
        expect(log, [
          'reserve#1',
          'charge#1',
          'ship#1',
          'ship#2',
          'undo charge',
          'undo reserve',
        ]);
        expect(state.status, TomSagaStatus.compensated);
      },
    );

    test(
      'a step that recovers within its attempts lets the saga complete',
      () async {
        var calls = 0;
        final o = orchestrator()
          ..register(
            TomSaga(
              name: 'flaky',
              retryPolicy: quickRetry,
              steps: [
                TomSagaStep(
                  'call',
                  action: (c) {
                    if (++calls == 1) throw StateError('blip');
                  },
                ),
              ],
            ),
          );
        final state = await settle(o, await o.begin('flaky'));
        expect(state.status, TomSagaStatus.completed);
        expect(calls, 2);
      },
    );

    test(
      'compensation gives the reason and keeps what the steps recorded',
      () async {
        final reasons = <String?>[];
        final refs = <Object?>[];
        final o = orchestrator()
          ..register(
            TomSaga(
              name: 'refund',
              steps: [
                TomSagaStep(
                  'charge',
                  action: (c) => c.data['payment'] = 'P-7',
                  compensation: (c) {
                    reasons.add(c.failure);
                    refs.add(c.data['payment']);
                    expect(c.isCompensating, isTrue);
                    expect(c.stepName, 'charge');
                  },
                ),
                TomSagaStep('ship', action: (c) => throw _Declined()),
              ],
            ),
          );
        await settle(o, await o.begin('refund'));
        expect(refs, ['P-7']);
        expect(reasons.single, contains("step 'ship'"));
      },
    );

    test('an attempt that fails saves none of its data', () async {
      final o = orchestrator()
        ..register(
          TomSaga(
            name: 'partial',
            steps: [
              TomSagaStep(
                'a',
                action: (c) {
                  c.data['half'] = true;
                  throw _Declined();
                },
              ),
            ],
          ),
        );
      final state = await settle(o, await o.begin('partial', data: {'x': 1}));
      expect(state.data, {'x': 1});
    });

    test('a step without a compensation is passed over', () async {
      final o = orchestrator()
        ..register(
          TomSaga(
            name: 'mixed',
            steps: [
              step('reserve'),
              step('notify', compensable: false),
              step('ship', fails: _Declined()),
            ],
          ),
        );
      final state = await settle(o, await o.begin('mixed'));
      expect(log, ['reserve#1', 'notify#1', 'ship#1', 'undo reserve']);
      expect(state.status, TomSagaStatus.compensated);
    });

    test('a first step that fails leaves nothing to compensate', () async {
      final o = orchestrator()
        ..register(
          TomSaga(
            name: 'early',
            steps: [step('reserve', fails: _Declined())],
          ),
        );
      final state = await settle(o, await o.begin('early'));
      expect(state.status, TomSagaStatus.compensated);
      expect(log, ['reserve#1']);
    });

    test(
      'a compensation that fails for good ends the saga failed and alerts',
      () async {
        final o = orchestrator()
          ..register(
            TomSaga(
              name: 'stuck',
              compensationRetryPolicy: quickRetry,
              steps: [
                step('reserve'),
                TomSagaStep(
                  'charge',
                  action: (c) => log.add('charge'),
                  compensation: (c) {
                    log.add('undo charge#${c.attempt}');
                    throw StateError('refund refused');
                  },
                ),
                step('ship', fails: _Declined()),
              ],
            ),
          );
        final state = await settle(o, await o.begin('stuck'));
        expect(state.status, TomSagaStatus.failed);
        expect(state.error, contains('refund refused'));
        expect(log, contains('undo charge#2'));
        expect(log, isNot(contains('undo reserve')));
        expect(
          alerts.map((a) => '${a.error}'),
          contains(contains("compensation of step 'charge'")),
        );
      },
    );
  });

  group('resumption', () {
    test('a restart mid-saga resumes it where it stopped', () async {
      final first = orchestrator()..register(order());
      final id = await first.begin('place_order');
      await first.tick();
      expect(log, ['reserve#1']);
      await first.close();

      // A new process: the same stores, a new orchestrator.
      final second = orchestrator()..register(order());
      await second.start();
      final state = await settle(second, id);
      expect(state.status, TomSagaStatus.completed);
      expect(log, ['reserve#1', 'charge#1', 'ship#1']);
    });

    test('a saga whose run was lost is queued again by start', () async {
      final first = orchestrator()..register(order());
      final id = await first.begin('place_order');
      await first.tick();
      await first.close();

      // The queue lost the next run — a crash between the step's commit and
      // the queueing of its successor.
      jobs = TomMemoryJobStore();
      final second = orchestrator()..register(order());
      expect(await second.resume(), 1);
      final state = await settle(second, id);
      expect(state.status, TomSagaStatus.completed);
      expect(log, ['reserve#1', 'charge#1', 'ship#1']);
    });

    test('a saga whose run is still queued is not queued twice', () async {
      final o = orchestrator()..register(order());
      await o.begin('place_order');
      expect(await o.resume(), 0);
    });

    test('a resumed compensation carries on compensating', () async {
      final first = orchestrator()..register(order(thirdFails: _Declined()));
      final id = await first.begin('place_order');
      for (var i = 0; i < 4; i++) {
        await first.tick();
      }
      expect(log.last, 'undo charge');
      await first.close();
      jobs = TomMemoryJobStore();
      final second = orchestrator()..register(order(thirdFails: _Declined()));
      await second.start();
      final state = await settle(second, id);
      expect(state.status, TomSagaStatus.compensated);
      expect(log.where((e) => e == 'undo charge'), hasLength(1));
      expect(log.last, 'undo reserve');
    });

    test('resume looks into every tenant of the installed tenancy', () async {
      await TomTenancy.install(
        TomTenancy(
          tenants: [TomTenant('acme'), TomTenant('globex')],
          datasources: const {},
        ),
      );
      addTearDown(TomTenancy.reset);
      final first = orchestrator()..register(order());
      final ids = <String, String>{};
      for (final tenant in ['acme', 'globex']) {
        ids[tenant] = await TomTenantContext.run(
          tenant,
          () => first.begin('place_order'),
        );
      }
      await first.close();
      jobs = TomMemoryJobStore();
      final second = orchestrator()..register(order());
      expect(await second.resume(), 2);
      for (var i = 0; i < 4; i++) {
        await second.tick();
      }
      for (final tenant in ['acme', 'globex']) {
        final state = await TomTenantContext.run(
          tenant,
          () => second.find(ids[tenant]!),
        );
        expect(state!.status, TomSagaStatus.completed, reason: tenant);
        expect(state.tenant, tenant);
      }
    });
  });

  group('a transition runs once', () {
    test('a run for a version the saga has left does nothing', () async {
      final o = orchestrator()..register(order());
      final id = await o.begin('place_order');
      await o.tick();
      // Queue the first step's run again, as a redelivery would.
      await jobs.enqueue(
        TomJobRun(
          id: 'replayed',
          jobName: o.stepJobName('place_order'),
          scheduledFor: now.add(const Duration(seconds: 1)),
          runAt: now,
          payload: {'saga': id, 'version': 0},
        ),
      );
      await settle(o, id);
      expect(log.where((e) => e.startsWith('reserve')), hasLength(1));
    });

    test('a transition that finds the saga moved on is dropped '
        '(transactions.saga.superseded)', () async {
      late TomSagaOrchestrator o;
      var raced = false;
      o = orchestrator()
        ..register(
          TomSaga(
            name: 'raced',
            steps: [
              TomSagaStep(
                'a',
                action: (c) async {
                  log.add('a');
                  if (raced) return;
                  raced = true;
                  // Another node completes this step while this one runs it.
                  final state = (await store.load(c.sagaId))!;
                  await store.update(
                    TomSagaState(
                      id: state.id,
                      name: state.name,
                      tenant: state.tenant,
                      status: TomSagaStatus.running,
                      step: 1,
                      version: 1,
                      data: {...state.data, 'by': 'other node'},
                      createdAt: state.createdAt,
                      updatedAt: now,
                    ),
                    expectedVersion: 0,
                  );
                },
              ),
              TomSagaStep('b', action: (c) => log.add('b')),
            ],
          ),
        );
      final id = await o.begin('raced');
      await o.tick();
      final moved = (await o.find(id))!;
      expect(moved.version, 1, reason: "this node's transition was dropped");
      expect(moved.data['by'], 'other node');
      // The other node's run is not in this node's queue: resumption finds it.
      expect(await o.resume(), 1);
      final state = await settle(o, id);
      expect(state.status, TomSagaStatus.completed);
      expect(log, ['a', 'b']);
    });

    test('steps run in the tenant the saga began in', () async {
      String? seen;
      final o = orchestrator()
        ..register(
          TomSaga(
            name: 'tenanted',
            steps: [
              TomSagaStep(
                'a',
                action: (c) => seen = TomTenantContext.currentId,
              ),
            ],
          ),
        );
      final id = await TomTenantContext.run('acme', () => o.begin('tenanted'));
      await o.tick();
      expect(seen, 'acme');
      expect(await o.find(id), isNull, reason: 'another tenant sees nothing');
      expect(
        (await TomTenantContext.run('acme', () => o.find(id)))!.status,
        TomSagaStatus.completed,
      );
    });
  });

  group('declarations and arguments', () {
    void refused(void Function() call, String key) => expect(
      call,
      throwsA(isA<TomSagaException>().having((e) => e.key, 'key', key)),
    );

    Future<void> refusedAsync(Future<Object?> Function() call, String key) =>
        expectLater(
          call(),
          throwsA(isA<TomSagaException>().having((e) => e.key, 'key', key)),
        );

    test('a saga needs a name, steps and distinct step names', () {
      refused(
        () => TomSaga(name: '', steps: [step('a')]),
        'transactions.saga.invalid_definition',
      );
      refused(
        () => TomSaga(name: 'x' * 121, steps: [step('a')]),
        'transactions.saga.invalid_definition',
      );
      refused(
        () => TomSaga(name: 'empty', steps: const []),
        'transactions.saga.invalid_definition',
      );
      refused(
        () => TomSaga(name: 'twice', steps: [step('a'), step('a')]),
        'transactions.saga.invalid_definition',
      );
    });

    test('a saga is registered once', () {
      final o = orchestrator()..register(order());
      refused(
        () => o.register(order()),
        'transactions.saga.already_registered',
      );
    });

    test('begin refuses an unknown saga, a bad id, a taken id and non-JSON '
        'data', () async {
      final o = orchestrator()..register(order());
      await refusedAsync(() => o.begin('nope'), 'transactions.saga.unknown');
      await refusedAsync(
        () => o.begin('place_order', id: ''),
        'transactions.saga.invalid_id',
      );
      await refusedAsync(
        () => o.begin('place_order', id: 'x' * 129),
        'transactions.saga.invalid_id',
      );
      await o.begin('place_order', id: 'order-1');
      await refusedAsync(
        () => o.begin('place_order', id: 'order-1'),
        'transactions.saga.id_taken',
      );
      await refusedAsync(
        () => o.begin('place_order', data: {'when': DateTime(2026)}),
        'transactions.saga.data_not_json',
      );
    });

    test('a closed orchestrator refuses work', () async {
      final o = orchestrator()..register(order());
      await o.close();
      await refusedAsync(
        () => o.begin('place_order'),
        'transactions.saga.closed',
      );
      refused(() => o.register(order()), 'transactions.saga.closed');
    });

    test('a SQL store naming an unregistered data source says so', () async {
      await refusedAsync(
        () => TomSqlSagaStore('no_such_source').prepare(),
        'transactions.saga.no_datasource',
      );
    });

    test('the jobs are named after the saga', () {
      final o = orchestrator();
      expect(o.stepJobName('place_order'), 'saga.place_order');
      expect(
        o.compensationJobName('place_order'),
        'saga.place_order.compensation',
      );
    });
  });

  group('runs enqueued under ids of their own', () {
    test(
      'outbox messages queued in one instant get runs of their own',
      () async {
        final queue = TomMemoryJobStore();
        final outbox = TomMessageOutbox(
          router: TomMessageRouter(),
          store: queue,
          clock: () => now,
        );
        addTearDown(outbox.close);
        for (var i = 0; i < 2; i++) {
          await outbox.send(
            TomMessage.email(
              to: [TomRecipient('ops@example.com')],
              subject: 's$i',
              text: 't',
            ),
          );
        }
        // One instant, two runs: each is keyed by its message, and neither
        // takes the window of that instant.
        final runs = await queue.all();
        expect(runs, hasLength(2));
        expect(runs.map((r) => r.scheduledFor).toSet(), {now});
        expect(runs.every((r) => !r.windowed), isTrue);
      },
    );
  });
}
