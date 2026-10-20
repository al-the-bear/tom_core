// ignore_for_file: avoid_print
/// Executable example for the sagas of the transactions module of
/// `tom_core_server`.
///
/// An order that reserves stock, charges a card and books a shipment touches
/// three services, which no one transaction spans. A saga runs each step as a
/// local transaction and, when a step fails for good, runs the compensations of
/// the steps already done, last first. This program shows:
///
/// 1. a saga whose steps all succeed, in order, each seeing what the steps
///    before it recorded;
/// 2. a step retried by its saga's policy and then failing for good, and the
///    two steps before it compensated in reverse order;
/// 3. a step's compensation reading what its action recorded (a payment
///    reference), and a step without a compensation passed over;
/// 4. a compensation failing for good, which ends the saga `failed` and raises
///    the scheduler's alert;
/// 5. a restart in the middle of a saga: a new orchestrator over the same
///    stores resumes it where it stopped;
/// 6. a saga name nobody registered refused with
///    `transactions.saga.unknown`.
///
/// It uses `TomMemorySagaStore` and `TomMemoryJobStore`, so it needs no
/// database. A deployment uses `TomSqlSagaStore` over the data source its
/// steps write to and a durable job store — see "Sagas" in
/// `doc/transactions.md`.
///
/// Run with `dart run example/transactions/saga_example.dart`. Every step
/// checks its own result and the run fails when one does not hold.
/// `test/saga_test.dart` covers the same behaviour.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

/// A failure no retry can mend: the saga compensates at once.
class _Declined implements Exception, TomPermanentFailure {
  @override
  String toString() => 'declined';
}

/// What the steps and compensations did, in order.
final journal = <String>[];

/// Two attempts, no wait between them, so the example runs in milliseconds.
const quickRetry = TomRetryPolicy(
  maxAttempts: 2,
  initialBackoff: Duration.zero,
  maxBackoff: Duration(seconds: 1),
  jitter: 0,
);

/// A step that records its attempt and, unless [fails] is given, notes itself
/// in the saga's data; its compensation records the undo.
TomSagaStep step(String name, {Object? fails, bool compensable = true}) =>
    TomSagaStep(
      name,
      action: (context) {
        journal.add('$name#${context.attempt}');
        if (fails != null) throw fails;
        context.data[name] = 'done';
      },
      compensation: compensable ? (context) => journal.add('undo $name') : null,
    );

/// The order saga: reserve, charge, ship — [shipFails] makes the last step
/// throw.
TomSaga order(String name, {Object? shipFails}) => TomSaga(
  name: name,
  retryPolicy: quickRetry,
  compensationRetryPolicy: quickRetry,
  steps: [
    step('reserve'),
    step('charge'),
    step('ship', fails: shipFails),
  ],
);

/// Moves saga [id] on until it has finished.
Future<TomSagaState> settle(TomSagaOrchestrator orchestrator, String id) async {
  for (var pass = 0; pass < 20; pass++) {
    final state = (await orchestrator.find(id))!;
    if (state.status.isFinished) return state;
    await orchestrator.tick();
    // A started orchestrator runs passes of its own, and a tick made while one
    // is under way returns at once: give that pass its turn.
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  throw StateError('saga $id did not finish');
}

Future<void> main() async {
  final now = DateTime.utc(2026, 10, 20, 12);
  final sagas = TomMemorySagaStore();
  final jobs = TomMemoryJobStore();
  final alerts = <TomJobAlert>[];
  TomSagaOrchestrator orchestrator() => TomSagaOrchestrator(
    store: sagas,
    jobStore: jobs,
    clock: () => now,
    onAlert: alerts.add,
  );

  final first = orchestrator()
    ..register(order('place_order'))
    ..register(order('place_order_ship_down', shipFails: StateError('down')))
    ..register(
      TomSaga(
        name: 'refund_order',
        steps: [
          TomSagaStep(
            'charge',
            action: (context) => context.data['payment'] = 'P-7',
            compensation: (context) =>
                journal.add('refund ${context.data['payment']}'),
          ),
          step('notify', compensable: false),
          step('ship', fails: _Declined()),
        ],
      ),
    )
    ..register(
      TomSaga(
        name: 'stuck_order',
        compensationRetryPolicy: quickRetry,
        steps: [
          step('reserve'),
          TomSagaStep(
            'charge',
            action: (context) => journal.add('charge#${context.attempt}'),
            compensation: (context) {
              journal.add('undo charge#${context.attempt}');
              throw StateError('refund refused');
            },
          ),
          step('ship', fails: _Declined()),
        ],
      ),
    );

  // 1. Every step succeeds: they run in order and the saga completes, its data
  //    holding what each step recorded.
  final done = await settle(
    first,
    await first.begin('place_order', data: {'order': 42}),
  );
  print('1. ${done.status.name}: $journal, data ${done.data}');
  check(done.status == TomSagaStatus.completed, 'the saga completed');
  check(
    journal.join(',') == 'reserve#1,charge#1,ship#1',
    'the three steps ran once each, in order',
  );
  check(
    done.data['order'] == 42 && done.data['ship'] == 'done',
    'the data kept what begin was given and what every step recorded',
  );
  check(done.version == 3, 'three transitions, one version each');

  // 2. The last step fails on both of its attempts: the saga compensates the
  //    two steps before it, last first.
  journal.clear();
  final undone = await settle(
    first,
    await first.begin('place_order_ship_down'),
  );
  print('2. ${undone.status.name}: $journal');
  check(
    journal.join(',') ==
        'reserve#1,charge#1,ship#1,ship#2,undo charge,undo reserve',
    'the step was retried by the saga policy, then the steps before it were '
    'compensated in reverse order',
  );
  check(
    undone.status == TomSagaStatus.compensated,
    'every step before the failed one was compensated',
  );
  check(
    undone.error!.contains("step 'ship'"),
    'the saga records which step failed',
  );

  // 3. A compensation reads what its action recorded; a step without one is
  //    passed over, and a permanent failure is not retried.
  journal.clear();
  final refunded = await settle(first, await first.begin('refund_order'));
  print('3. ${refunded.status.name}: $journal');
  check(
    journal.join(',') == 'notify#1,ship#1,refund P-7',
    'the declined step ran once, `notify` was passed over and the charge was '
    'refunded by the reference its action saved',
  );

  // 4. A compensation that fails for good ends the saga `failed`: the steps
  //    before it stay done, and the scheduler's alert names the saga.
  journal.clear();
  final failed = await settle(first, await first.begin('stuck_order'));
  print('4. ${failed.status.name}: $journal');
  check(failed.status == TomSagaStatus.failed, 'the saga failed');
  check(
    journal.join(',') ==
        'reserve#1,charge#1,ship#1,undo charge#1,undo charge#2',
    'the compensation was retried, and `reserve` was never compensated',
  );
  check(
    alerts.any(
      (alert) => '${alert.error}'.contains("compensation of step 'charge'"),
    ),
    'the alert names the compensation that failed',
  );

  // 5. A restart: the first step commits, the process stops, and a new
  //    orchestrator over the same stores carries the saga on.
  journal.clear();
  final id = await first.begin('place_order');
  await first.tick();
  await first.close();
  final second = orchestrator()..register(order('place_order'));
  await second.start();
  final resumed = await settle(second, id);
  print('5. after a restart ${resumed.status.name}: $journal');
  check(
    journal.join(',') == 'reserve#1,charge#1,ship#1',
    'the restart ran no step twice and skipped none',
  );
  check(
    resumed.status == TomSagaStatus.completed,
    'the resumed saga completed',
  );

  // 6. A saga that is not registered cannot be begun.
  String? key;
  try {
    await second.begin('cancel_order');
  } on TomSagaException catch (error) {
    key = error.key;
  }
  print('6. begin(cancel_order) -> $key');
  check(key == 'transactions.saga.unknown', 'an unknown saga is refused');
  await second.close();
}
