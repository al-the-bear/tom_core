/// The idempotent receiver's contract, on the in-memory inbox: a redelivered
/// message is processed once and acknowledged each time, a failed delivery is
/// neither recorded nor acknowledged, and consumers are kept apart.
///
/// The SQL inbox — the record and the consumer's own write in one transaction
/// — is tested against a database in `inbox_db_test.dart`.
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

Matcher _refused(String key) =>
    throwsA(isA<TomInboxException>().having((e) => e.key, 'key', key));

void main() {
  late TomMemoryInbox inbox;
  late int workDone;
  late int acks;

  setUp(() {
    inbox = TomMemoryInbox();
    workDone = 0;
    acks = 0;
  });

  Future<TomInboxOutcome> deliver(String id, {String consumer = 'billing'}) =>
      inbox.process(consumer, id, () => workDone++, acknowledge: () => acks++);

  test(
    'a redelivered message is processed once and acknowledged each time',
    () async {
      expect(await deliver('m-1'), TomInboxOutcome.processed);
      expect(await deliver('m-1'), TomInboxOutcome.duplicate);
      expect(await deliver('m-1'), TomInboxOutcome.duplicate);
      expect(workDone, 1);
      expect(acks, 3, reason: 'a duplicate is acknowledged so it stops coming');
      expect(await inbox.hasProcessed('billing', 'm-1'), isTrue);
    },
  );

  test(
    'a failed delivery is not recorded or acknowledged; the redelivery runs',
    () async {
      await expectLater(
        inbox.process(
          'billing',
          'm-2',
          () => throw StateError('downstream down'),
          acknowledge: () => acks++,
        ),
        throwsStateError,
      );
      expect(acks, 0);
      expect(await inbox.hasProcessed('billing', 'm-2'), isFalse);
      expect(await deliver('m-2'), TomInboxOutcome.processed);
      expect(workDone, 1);
    },
  );

  test('two consumers each process one message once', () async {
    await deliver('m-3', consumer: 'billing');
    await deliver('m-3', consumer: 'notifier');
    await deliver('m-3', consumer: 'notifier');
    expect(workDone, 2);
  });

  test('two simultaneous deliveries of one message do the work once', () async {
    final gate = Completer<void>();
    Future<TomInboxOutcome> slow() => inbox.process('billing', 'm-4', () async {
      workDone++;
      await gate.future;
    });
    final first = slow();
    final second = slow();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    gate.complete();
    expect(
      {await first, await second},
      {TomInboxOutcome.processed, TomInboxOutcome.duplicate},
    );
    expect(workDone, 1);
  });

  test('records older than a cut-off are purged', () async {
    var now = DateTime.utc(2026, 10, 1);
    inbox = TomMemoryInbox(clock: () => now);
    await deliver('old');
    now = DateTime.utc(2026, 10, 20);
    await deliver('new');
    expect(await inbox.purgeProcessedBefore(DateTime.utc(2026, 10, 10)), 1);
    expect(await inbox.hasProcessed('billing', 'old'), isFalse);
    expect(await inbox.hasProcessed('billing', 'new'), isTrue);
  });

  test('an empty or over-long consumer or message id is refused', () async {
    await expectLater(
      inbox.process('', 'm', () {}),
      _refused('messaging.inbox.invalid_consumer'),
    );
    await expectLater(
      inbox.process('x' * 151, 'm', () {}),
      _refused('messaging.inbox.invalid_consumer'),
    );
    await expectLater(
      inbox.process('billing', '', () {}),
      _refused('messaging.inbox.invalid_message_id'),
    );
    await expectLater(
      inbox.process('billing', 'm' * 192, () {}),
      _refused('messaging.inbox.invalid_message_id'),
    );
  });
}
