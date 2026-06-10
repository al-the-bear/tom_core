// Unit tests for the generic isolate-streaming machinery promoted from
// tom_brain_memory's isolate adapter (Tom Brain completion plan item 7).
//
// These exercise the mechanisms in isolation; the brain-memory isolate
// boundary round-trips that consume them live in
// `tom_brain_memory/test/a81_message_protocol_test.dart`.

import 'dart:async';

import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:test/test.dart';

void main() {
  group('IsolateCancellationRegistry', () {
    test('register then cancel flips the flag', () {
      final reg = IsolateCancellationRegistry();
      final tok = const IsolateCancellationToken(1);
      final h = reg.register(tok);
      expect(h.isCancelled, isFalse);
      reg.cancel(tok);
      expect(h.isCancelled, isTrue);
      expect(reg.isCancelled(tok), isTrue);
    });

    test('cancel-before-register is remembered (late-cancel race)', () {
      final reg = IsolateCancellationRegistry();
      final tok = const IsolateCancellationToken(2);
      reg.cancel(tok);
      expect(reg.pendingCancelCount, equals(1));
      final h = reg.register(tok);
      expect(h.isCancelled, isTrue,
          reason: 'register must consume the pending cancel');
      expect(reg.pendingCancelCount, equals(0));
    });

    test('throwIfCancelled raises IsolateCancellationException with the token',
        () {
      final reg = IsolateCancellationRegistry();
      final tok = const IsolateCancellationToken(3);
      final h = reg.register(tok);
      h.throwIfCancelled(); // does nothing
      reg.cancel(tok);
      expect(
        h.throwIfCancelled,
        throwsA(
          isA<IsolateCancellationException>()
              .having((e) => e.token.id, 'token.id', 3),
        ),
      );
    });

    test('cancelled future completes when the request is cancelled', () async {
      final reg = IsolateCancellationRegistry();
      final tok = const IsolateCancellationToken(99);
      final h = reg.register(tok);
      var fired = false;
      unawaited(h.cancelled.then((_) => fired = true));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(fired, isFalse);
      reg.cancel(tok);
      await h.cancelled;
      expect(fired, isTrue);
    });

    test('dispose is idempotent and unregisters', () {
      final reg = IsolateCancellationRegistry();
      final tok = const IsolateCancellationToken(4);
      final h = reg.register(tok);
      expect(reg.inFlightCount, equals(1));
      h.dispose();
      expect(reg.inFlightCount, equals(0));
      h.dispose(); // idempotent
      expect(reg.inFlightCount, equals(0));
    });

    test('cancel on unknown then register elsewhere does not leak', () {
      final reg = IsolateCancellationRegistry();
      reg.cancel(const IsolateCancellationToken(10));
      reg.cancel(const IsolateCancellationToken(11));
      expect(reg.pendingCancelCount, equals(2));
      reg.register(const IsolateCancellationToken(10));
      expect(reg.pendingCancelCount, equals(1));
    });
  });

  group('IsolateCancellationToken / allocator', () {
    test('value equality keys off the id', () {
      expect(const IsolateCancellationToken(7),
          equals(const IsolateCancellationToken(7)));
      expect(const IsolateCancellationToken(7),
          isNot(equals(const IsolateCancellationToken(8))));
      expect(const IsolateCancellationToken(7).hashCode,
          equals(const IsolateCancellationToken(7).hashCode));
    });

    test('allocator hands out monotonic ids', () {
      final a = IsolateCancellationTokenAllocator();
      expect(a.next().id, equals(1));
      expect(a.next().id, equals(2));
      expect(a.peekNext, equals(3));
    });
  });

  group('BackpressureTracker', () {
    test('rejects negative initial credits', () {
      expect(() => BackpressureTracker(initialCredits: -1), throwsArgumentError);
    });

    test('awaitCredit returns immediately when credits > 0', () async {
      final t = BackpressureTracker(initialCredits: 3);
      await t.awaitCredit();
      expect(t.credits, equals(3));
      t.consume();
      expect(t.credits, equals(2));
    });

    test('awaitCredit parks at zero and unblocks on grant', () async {
      final t = BackpressureTracker(initialCredits: 1);
      t.consume();
      expect(t.credits, equals(0));
      var unblocked = false;
      final f = t.awaitCredit().then((_) => unblocked = true);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(unblocked, isFalse);
      expect(t.waiterCount, equals(1));
      t.grant(1);
      await f;
      expect(unblocked, isTrue);
      expect(t.waiterCount, equals(0));
    });

    test('grant wakes parked waiters in FIFO order', () async {
      final t = BackpressureTracker(initialCredits: 0);
      final order = <int>[];
      final f1 = t.awaitCredit().then((_) => order.add(1));
      final f2 = t.awaitCredit().then((_) => order.add(2));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(t.waiterCount, equals(2));
      t.grant(2);
      await Future.wait([f1, f2]);
      expect(order, equals(<int>[1, 2]));
      expect(t.waiterCount, equals(0));
    });

    test('consume rejects negative and over-consume', () {
      final t = BackpressureTracker(initialCredits: 1);
      expect(() => t.consume(-1), throwsArgumentError);
      expect(() => t.consume(2), throwsStateError);
    });

    test('grant rejects non-positive', () {
      final t = BackpressureTracker(initialCredits: 1);
      expect(() => t.grant(0), throwsArgumentError);
      expect(() => t.grant(-1), throwsArgumentError);
    });

    test('close fails parked waiters and rejects later awaitCredit', () async {
      final t = BackpressureTracker(initialCredits: 0);
      final f = t.awaitCredit();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      t.close();
      expect(t.isClosed, isTrue);
      await expectLater(f, throwsStateError);
      await expectLater(t.awaitCredit(), throwsStateError);
    });
  });

  group('IsolateStreamCloseSignal', () {
    test('requestClose raises the flag and fires the signal', () async {
      final s = IsolateStreamCloseSignal();
      expect(s.closeRequested, isFalse);
      expect(s.closeSignal.isCompleted, isFalse);
      s.requestClose();
      expect(s.closeRequested, isTrue);
      await s.closeSignal.future; // completes
      expect(s.closeSignal.isCompleted, isTrue);
    });

    test('requestClose is idempotent', () {
      final s = IsolateStreamCloseSignal();
      s.requestClose();
      s.requestClose(); // must not throw on the already-completed signal
      expect(s.closeRequested, isTrue);
      expect(s.closeSignal.isCompleted, isTrue);
    });
  });
}
