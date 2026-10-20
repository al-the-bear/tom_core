/// The idempotent receiver: a message a broker delivers more than once is
/// processed once.
///
/// A broker that promises at-least-once delivery redelivers every message whose
/// acknowledgement it did not receive. `TomInbox.process` records the message
/// and runs the consumer's work together, skips a message it has recorded, and
/// acknowledges only after the record is in — so a redelivery is recognised
/// and a failed delivery is processed again.
///
/// This program uses `TomMemoryInbox`, which needs no database and keeps the
/// same contract. A deployment uses `TomSqlInbox` over the data source its work
/// writes to, so the record and the work commit in one transaction — see
/// "Idempotent Receiver (Inbox)" in `doc/messaging.md`.
///
/// No broker is involved either: a delivery here is a message id, a piece of
/// work and an acknowledgement callback, which is all `process` asks of any
/// broker's consumer loop.
///
/// Run with `dart run example/messaging/inbox_example.dart`. Every step checks
/// its own result and the run fails when one does not hold.
library;

import 'dart:async';

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

/// What the consumer's work changes: one charge per order it processed.
final charges = <String>[];

/// How many times each message was acknowledged to the (imagined) broker.
final acknowledged = <String, int>{};

/// One delivery of [messageId] to the `billing` consumer of [inbox].
Future<TomInboxOutcome> deliver(
  TomInbox inbox,
  String messageId, {
  String consumer = 'billing',
}) => inbox.process(
  consumer,
  messageId,
  () => charges.add('$consumer:$messageId'),
  acknowledge: () => acknowledged['$consumer:$messageId'] =
      (acknowledged['$consumer:$messageId'] ?? 0) + 1,
);

Future<void> main() async {
  var now = DateTime.utc(2026, 10, 1, 9);
  final inbox = TomMemoryInbox(clock: () => now);

  // 1. A first delivery: the work runs, the message is recorded, and the
  //    broker is told it was handled.
  final first = await deliver(inbox, 'order-1');
  print('1. first delivery of order-1: ${first.name}, charges $charges');
  check(first == TomInboxOutcome.processed, 'a new message is processed');
  check(charges.length == 1, 'its work ran once');
  check(acknowledged['billing:order-1'] == 1, 'and it was acknowledged');

  // 2. The broker did not receive that acknowledgement and delivers again.
  //    The inbox recognises the message, skips the work, and acknowledges
  //    again so the broker stops.
  final again = await deliver(inbox, 'order-1');
  print('2. redelivery of order-1: ${again.name}, charges $charges');
  check(again == TomInboxOutcome.duplicate, 'a redelivery is a duplicate');
  check(charges.length == 1, 'the work did not run a second time');
  check(acknowledged['billing:order-1'] == 2, 'the duplicate is acknowledged');

  // 3. A delivery whose work fails is neither recorded nor acknowledged, so
  //    the broker redelivers it — and the redelivery processes it.
  Object? failure;
  try {
    await inbox.process(
      'billing',
      'order-2',
      () => throw StateError('payment provider unavailable'),
      acknowledge: () => acknowledged['billing:order-2'] = 1,
    );
  } on StateError catch (e) {
    failure = e;
  }
  final recordedAfterFailure = await inbox.hasProcessed('billing', 'order-2');
  final retried = await deliver(inbox, 'order-2');
  print(
    '3. order-2 failed (${failure != null ? 'rethrown' : 'swallowed'}), '
    'recorded: $recordedAfterFailure; redelivery: ${retried.name}',
  );
  check(failure != null, 'the failing work is rethrown to the consumer loop');
  check(!recordedAfterFailure, 'a failed message is not recorded');
  check(retried == TomInboxOutcome.processed, 'its redelivery is processed');
  check(
    acknowledged['billing:order-2'] == 1,
    'acknowledged once, by the delivery that succeeded',
  );

  // 4. The consumer is part of the key: a second consumer of the same message
  //    processes it once of its own.
  final notifier = await deliver(inbox, 'order-1', consumer: 'notifier');
  final notifierAgain = await deliver(inbox, 'order-1', consumer: 'notifier');
  print(
    '4. order-1 for notifier: ${notifier.name}, then ${notifierAgain.name}',
  );
  check(notifier == TomInboxOutcome.processed, 'a second consumer processes');
  check(notifierAgain == TomInboxOutcome.duplicate, 'once');
  check(
    charges.where((c) => c.endsWith(':order-1')).length == 2,
    'order-1 ran once per consumer',
  );

  // 5. Two deliveries of one message at the same moment: the second waits for
  //    the first and then finds the record.
  final gate = Completer<void>();
  var slowRuns = 0;
  Future<TomInboxOutcome> slow() =>
      inbox.process('billing', 'order-3', () async {
        slowRuns++;
        await gate.future;
      });
  final racing = [slow(), slow()];
  await Future<void>.delayed(const Duration(milliseconds: 20));
  gate.complete();
  final outcomes = (await Future.wait(racing)).map((o) => o.name).toList()
    ..sort();
  print('5. two simultaneous deliveries of order-3: $outcomes');
  check(slowRuns == 1, 'the work ran once');
  check(
    outcomes.join(',') == 'duplicate,processed',
    'one delivery processed it, the other found it processed',
  );

  // 6. Records are purged only on request, and only those older than a
  //    cut-off chosen beyond the broker's longest redelivery window.
  now = DateTime.utc(2026, 10, 20, 9);
  await deliver(inbox, 'order-4');
  final purged = await inbox.purgeProcessedBefore(DateTime.utc(2026, 10, 10));
  final oldKept = await inbox.hasProcessed('billing', 'order-1');
  final newKept = await inbox.hasProcessed('billing', 'order-4');
  print('6. purged $purged records; order-1 kept: $oldKept, order-4: $newKept');
  check(purged == 4, 'the four records from 1 October were purged');
  check(!oldKept, 'an old record is gone');
  check(newKept, 'a recent one stays');
}
