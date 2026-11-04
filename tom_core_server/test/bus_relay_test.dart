/// The bus relay: messages for the bus queued on a job store and published by
/// the relay's scheduler — under the message id they were queued with, in the
/// trace they were queued in, and again after a publish the bus refused.
///
/// The relay's write joining a database transaction is
/// `outbox_transaction_db_test.dart`'s.
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_core_message_bus/tom_core_message_bus.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// A bus refusing its first [refusals] publishes.
class _FlakyBus extends TomMemoryMessageBus {
  _FlakyBus(this.refusals);

  int refusals;

  @override
  Future<String> publish<T>(
    String topic,
    T payload, {
    String? key,
    Map<String, String> headers = const {},
    String? id,
    TomBusCodec<T>? codec,
  }) {
    if (refusals > 0) {
      refusals--;
      throw StateError('the broker is unreachable');
    }
    return super.publish(
      topic,
      payload,
      key: key,
      headers: headers,
      id: id,
      codec: codec,
    );
  }
}

/// A bus that publishes and then never answers — a process stopping after
/// the broker took the message and before the relay recorded it.
class _StoppingBus extends TomMemoryMessageBus {
  _StoppingBus(this.inner);

  final TomMessageBus inner;
  final Completer<void> released = Completer();

  @override
  Future<String> publish<T>(
    String topic,
    T payload, {
    String? key,
    Map<String, String> headers = const {},
    String? id,
    TomBusCodec<T>? codec,
  }) async {
    final published = await inner.publish(
      topic,
      payload,
      key: key,
      headers: headers,
      id: id,
      codec: codec,
    );
    await released.future;
    return published;
  }
}

/// A bus recording how many publishes run at once.
class _CountingBus extends TomMemoryMessageBus {
  int running = 0;
  int most = 0;

  @override
  Future<String> publish<T>(
    String topic,
    T payload, {
    String? key,
    Map<String, String> headers = const {},
    String? id,
    TomBusCodec<T>? codec,
  }) async {
    running++;
    if (running > most) most = running;
    await Future<void>.delayed(const Duration(milliseconds: 2));
    running--;
    return super.publish(
      topic,
      payload,
      key: key,
      headers: headers,
      id: id,
      codec: codec,
    );
  }
}

void main() {
  late TomMemoryMessageBus bus;
  late TomBusRelay relay;
  late List<TomBusDelivery<Map<String, Object?>>> received;

  Future<void> listen() async {
    received = [];
    await bus.subscribe<Map<String, Object?>>(
      'orders',
      group: 'billing',
      handler: received.add,
    );
  }

  tearDown(() async {
    await relay.close();
    await bus.close();
  });

  test(
    'a queued message reaches the bus on the next tick, under its id',
    () async {
      bus = TomMemoryMessageBus();
      relay = TomBusRelay(bus: bus);
      await listen();

      final id = await relay.publish(
        'orders',
        {'order': 'o-1'},
        key: 'customer-7',
        headers: {'x-source': 'shop'},
      );
      await bus.settled();
      expect(received, isEmpty, reason: 'queued, not yet published');

      await relay.tick();
      await bus.settled();
      final delivery = received.single;
      expect(delivery.message.id, id);
      expect(delivery.message.key, 'customer-7');
      expect(delivery.message.headers['x-source'], 'shop');
      expect(delivery.payload, {'order': 'o-1'});
    },
  );

  test('a message id the relay holds is not queued twice', () async {
    bus = TomMemoryMessageBus();
    relay = TomBusRelay(bus: bus);
    await listen();
    await relay.publish('orders', {'n': 1}, id: 'm-1');
    await relay.publish('orders', {'n': 2}, id: 'm-1');
    await relay.tick();
    await bus.settled();
    expect(received.single.payload, {'n': 1});
  });

  test('the consumer runs in the trace the message was queued in', () async {
    bus = TomMemoryMessageBus();
    relay = TomBusRelay(bus: bus);
    TomTraceContext? handledIn;
    await bus.subscribe<Object?>(
      'orders',
      group: 'billing',
      handler: (_) => handledIn = TomTraceContext.current,
    );
    final request = TomTraceContext.newRoot();
    await TomTraceContext.run(
      request,
      () => relay.publish('orders', {'order': 'o-1'}),
    );
    await relay.tick();
    await bus.settled();
    expect(handledIn!.traceId, request.traceId);
  });

  test('a publish the bus refused is made again', () async {
    final flaky = _FlakyBus(1);
    bus = flaky;
    relay = TomBusRelay(
      bus: bus,
      retryPolicy: const TomRetryPolicy(
        maxAttempts: 3,
        initialBackoff: Duration(milliseconds: 1),
        maxBackoff: Duration(milliseconds: 2),
      ),
    );
    await listen();
    await relay.publish('orders', {'order': 'o-1'}, id: 'm-1');
    await relay.tick();
    expect(flaky.refusals, 0, reason: 'the first publish was refused');
    expect(received, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await relay.tick();
    await bus.settled();
    expect(received.single.message.id, 'm-1');
  });

  test('a closed relay refuses to queue', () async {
    bus = TomMemoryMessageBus();
    relay = TomBusRelay(bus: bus);
    await relay.close();
    await expectLater(
      relay.publish('orders', {'n': 1}),
      throwsA(
        isA<TomMessagingException>().having(
          (e) => e.key,
          'key',
          'messaging.bus_relay.closed',
        ),
      ),
    );
  });

  group('the guarantees', () {
    test('a stop between queueing and publishing loses nothing: the next '
        'relay on the store publishes it', () async {
      bus = TomMemoryMessageBus();
      await listen();
      final store = TomMemoryJobStore();
      final stopped = TomBusRelay(bus: bus, store: store);
      final id = await stopped.publish('orders', {'order': 'o-1'});
      await stopped.close(); // the process stops before its next tick

      relay = TomBusRelay(bus: bus, store: store);
      await relay.tick();
      await bus.settled();
      expect(received.single.message.id, id);
    });

    test('a stop during the publish is recovered: published again, under the '
        'same id — a duplicate, never a loss', () async {
      bus = TomMemoryMessageBus();
      await listen();
      final store = TomMemoryJobStore();
      final stopping = _StoppingBus(bus);
      final first = TomBusRelay(bus: stopping, store: store);
      final id = await first.publish('orders', {'order': 'o-1'});
      unawaited(first.tick());
      await Future.doWhile(() async {
        await bus.settled();
        if (received.isNotEmpty) return false;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return true;
      });

      // Another node, after the stopped one's lease ran out.
      final later = DateTime.now().add(const Duration(minutes: 20));
      relay = TomBusRelay(bus: bus, store: store, clock: () => later);
      await relay.tick();
      await bus.settled();
      expect(received.map((d) => d.message.id), [id, id]);

      stopping.released.complete();
      await first.close();
    });

    test('nodes sharing a lease lock publish one message at a time, each '
        'once, in queue order', () async {
      final counting = _CountingBus();
      bus = counting;
      final order = <Object?>[];
      await bus.subscribe<Map<String, Object?>>(
        'orders',
        group: 'billing',
        handler: (d) => order.add(d.payload['n']),
      );
      final store = TomMemoryJobStore();
      final lock = TomMemoryLeaseLock();
      relay = TomBusRelay(bus: bus, store: store, lock: lock);
      final other = TomBusRelay(bus: bus, store: store, lock: lock);
      addTearDown(other.close);
      for (var n = 0; n < 10; n++) {
        await relay.publish('orders', {'n': n});
      }
      await Future.wait([relay.tick(), other.tick()]);
      await relay.tick();
      await bus.settled();
      expect(order, [for (var n = 0; n < 10; n++) n]);
      expect(counting.most, 1);
    });
  });
}
