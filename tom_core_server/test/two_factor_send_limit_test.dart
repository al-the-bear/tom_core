/// The pace of delivered second-factor codes to one address.
///
/// The limiter's arithmetic, against an injected clock: the first send is
/// free, each later one waits twice as long as the one before, the wait never
/// exceeds the cap, proof ends a run and silence lapses it. How the service
/// consults it is `two_factor_delivered_code_test.dart`'s "the send pace".
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

const _base = Duration(seconds: 30);
const _cap = Duration(days: 30);

Tom2FASend _send([
  String destination = 'a@example.com',
  String channel = 'email',
]) => Tom2FASend(
  channel: channel,
  destination: destination,
  baseInterval: _base,
  maxInterval: _cap,
);

void main() {
  late DateTime now;
  late Tom2FAMemorySendLimiter limiter;

  setUp(() {
    now = DateTime.utc(2026, 10, 1, 9);
    limiter = Tom2FAMemorySendLimiter(clock: () => now);
  });

  group('Tom2FASend.intervalAfter', () {
    test('nothing before the first send, then the base interval doubling', () {
      final send = _send();
      expect(send.intervalAfter(0), Duration.zero);
      expect(send.intervalAfter(1), const Duration(seconds: 30));
      expect(send.intervalAfter(2), const Duration(minutes: 1));
      expect(send.intervalAfter(3), const Duration(minutes: 2));
      expect(send.intervalAfter(8), const Duration(seconds: 30 * 128));
    });

    test('never more than the cap, however long the run', () {
      final send = _send();
      // 30 s × 2^16 is about 22.7 days, still under the cap; the next is not.
      expect(send.intervalAfter(17), const Duration(seconds: 30 * 65536));
      expect(send.intervalAfter(18), _cap);
      expect(send.intervalAfter(60), _cap);
      expect(send.intervalAfter(1 << 30), _cap, reason: 'no overflow');
    });
  });

  group('Tom2FAMemorySendLimiter', () {
    test('the first send to an address is allowed at once', () async {
      expect(await limiter.claim(_send()), isNull);
      expect(limiter.size, 1);
    });

    test(
      'a second send inside the interval is refused with the wait left',
      () async {
        await limiter.claim(_send());
        now = now.add(const Duration(seconds: 10));
        expect(await limiter.claim(_send()), const Duration(seconds: 20));
      },
    );

    test(
      'a refused send is not recorded, so it does not lengthen the wait',
      () async {
        await limiter.claim(_send());
        for (var i = 0; i < 5; i++) {
          now = now.add(const Duration(seconds: 1));
          expect(await limiter.claim(_send()), isNotNull);
        }
        now = now.add(const Duration(seconds: 25));
        expect(
          await limiter.claim(_send()),
          isNull,
          reason: '30 s after the first send, the second is due',
        );
      },
    );

    test('each allowed send doubles the wait before the next', () async {
      var wait = _base;
      expect(await limiter.claim(_send()), isNull);
      for (var sends = 1; sends <= 6; sends++) {
        now = now.add(wait - const Duration(seconds: 1));
        expect(
          await limiter.claim(_send()),
          const Duration(seconds: 1),
          reason: 'one second early after $sends sends',
        );
        now = now.add(const Duration(seconds: 1));
        expect(await limiter.claim(_send()), isNull);
        wait *= 2;
      }
    });

    test('the wait stops growing at the cap', () async {
      expect(await limiter.claim(_send()), isNull);
      // Keep sending as soon as allowed until the cap is the gap.
      for (var sends = 1; sends < 25; sends++) {
        now = now.add(_send().intervalAfter(sends));
        expect(await limiter.claim(_send()), isNull);
      }
      now = now.add(const Duration(days: 29));
      expect(await limiter.claim(_send()), const Duration(days: 1));
    });

    test('a reset ends the run, so the next send is allowed at once', () async {
      await limiter.claim(_send());
      await limiter.reset('email', 'a@example.com');
      expect(await limiter.claim(_send()), isNull);
      // And the run restarted: the next gap is the base interval again.
      now = now.add(const Duration(seconds: 29));
      expect(await limiter.claim(_send()), const Duration(seconds: 1));
    });

    test('a run at the cap stays at the cap rather than lapsing', () async {
      expect(await limiter.claim(_send()), isNull);
      for (var sends = 1; sends < 20; sends++) {
        now = now.add(_send().intervalAfter(sends));
        expect(await limiter.claim(_send()), isNull);
      }
      // Due again after exactly the cap — and the run continues, so the next
      // gap is the cap again rather than a fresh 30 seconds.
      now = now.add(_cap);
      expect(await limiter.claim(_send()), isNull);
      now = now.add(const Duration(minutes: 1));
      expect(await limiter.claim(_send()), _cap - const Duration(minutes: 1));
    });

    test(
      'a run lapses after twice the cap of silence and is dropped',
      () async {
        await limiter.claim(_send());
        now = now.add(_cap * 2);
        await limiter.claim(_send('other@example.com'));
        expect(limiter.size, 1, reason: 'the silent address was pruned');
        expect(await limiter.claim(_send()), isNull);
      },
    );

    test('addresses and channels are paced separately', () async {
      await limiter.claim(_send('a@example.com'));
      expect(await limiter.claim(_send('b@example.com')), isNull);
      expect(await limiter.claim(_send('a@example.com', 'sms')), isNull);
      expect(await limiter.claim(_send('a@example.com')), isNotNull);
    });

    test('an address differing only in case or surrounding space is the same '
        'address', () async {
      await limiter.claim(_send('Alice@Example.com'));
      expect(await limiter.claim(_send(' alice@example.com ')), isNotNull);
      await limiter.reset('email', 'ALICE@example.com');
      expect(await limiter.claim(_send('alice@example.com')), isNull);
    });
  });

  group('Tom2FASendLimiter.resolve', () {
    tearDown(TomBean.resetBeanContext);

    test('falls back to the process-wide default', () {
      TomBean.resetBeanContext();
      expect(Tom2FASendLimiter.resolve(), same(Tom2FAMemorySendLimiter.shared));
    });

    test('answers an installed limiter', () {
      TomBean.resetBeanContext();
      TomBean.withType<Tom2FASendLimiter>(limiter);
      expect(Tom2FASendLimiter.resolve(), same(limiter));
    });
  });
}
