/// The conformance suite of the [TomMessageBus] contract: every bus — the
/// in-memory one, and every adapter over a broker — runs it in its own tests.
///
/// ```dart
/// import 'package:test/test.dart';
/// import 'package:tom_core_message_bus/conformance.dart';
///
/// void main() {
///   group('MyBrokerBus', () {
///     tomMessageBusConformance(create: () async => MyBrokerBus(...));
///   });
/// }
/// ```
///
/// Each test makes a bus with `create`, uses topics and groups of its own
/// (named with a random suffix, so a persistent broker is not polluted by an
/// earlier run), and closes the bus. Ordering per key is tested only when the
/// bus declares it ([TomBusCapabilities.orderedPerKey]).
library;

import 'dart:async';
import 'dart:math';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'tom_core_message_bus.dart';

/// A payload type with a codec of its own, for the typed-payload test.
class TomConformanceOrder {
  /// An order of [quantity] items of [item].
  const TomConformanceOrder(this.item, this.quantity);

  /// The item.
  final String item;

  /// How many.
  final int quantity;

  /// Its codec.
  static final TomBusCodec<TomConformanceOrder> codec = TomBusCodec(
    (order) => {'item': order.item, 'quantity': order.quantity},
    (json) {
      final map = json! as Map;
      return TomConformanceOrder(
        map['item']! as String,
        map['quantity']! as int,
      );
    },
  );
}

/// Defines the conformance tests against the bus [create] makes.
///
/// [timeout] bounds the wait for an expected delivery; [quiet] is how long a
/// test waits to see that a delivery that must not happen does not — raise
/// both for a broker with slow round trips.
void tomMessageBusConformance({
  required Future<TomMessageBus> Function() create,
  Duration timeout = const Duration(seconds: 10),
  Duration quiet = const Duration(milliseconds: 300),
}) {
  late TomMessageBus bus;
  final random = Random();
  String unique(String name) =>
      'conformance-$name-${random.nextInt(1 << 32).toRadixString(16)}';

  /// Waits until [condition] holds, failing after [timeout].
  Future<void> until(bool Function() condition, String what) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Timed out waiting for $what.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<void> calm() => Future<void>.delayed(quiet);

  setUp(() async => bus = await create());
  tearDown(() => bus.close());

  group('publish and subscribe', () {
    test(
      'MB-C1: a subscribed group receives the message as published',
      () async {
        final topic = unique('c1');
        final received = <TomBusDelivery<Map<String, Object?>>>[];
        await bus.subscribe<Map<String, Object?>>(
          topic,
          group: unique('g'),
          handler: received.add,
        );
        final id = await bus.publish<Map<String, Object?>>(
          topic,
          {
            'order': 42,
            'items': ['a', 'b'],
          },
          key: 'customer-7',
          headers: {'x-tenant': 'acme'},
        );
        await until(() => received.isNotEmpty, 'the delivery');
        final delivery = received.single;
        expect(delivery.message.id, id);
        expect(delivery.message.topic, topic);
        expect(delivery.message.key, 'customer-7');
        expect(delivery.message.headers['x-tenant'], 'acme');
        expect(delivery.payload, {
          'order': 42,
          'items': ['a', 'b'],
        });
        expect(delivery.attempt, 1);
      },
    );

    test('MB-C2: every group receives every message', () async {
      final topic = unique('c2');
      final first = <String>[];
      final second = <String>[];
      await bus.subscribe<String>(
        topic,
        group: unique('a'),
        handler: (d) => first.add(d.payload),
      );
      await bus.subscribe<String>(
        topic,
        group: unique('b'),
        handler: (d) => second.add(d.payload),
      );
      await bus.publish(topic, 'one');
      await bus.publish(topic, 'two');
      await until(() => first.length == 2 && second.length == 2, 'both groups');
      expect(first.toSet(), {'one', 'two'});
      expect(second.toSet(), {'one', 'two'});
    });

    test('MB-C3: the consumers of a group share its messages', () async {
      final topic = unique('c3');
      final group = unique('g');
      final handled = <String>[];
      for (var i = 0; i < 2; i++) {
        await bus.subscribe<int>(
          topic,
          group: group,
          handler: (d) => handled.add(d.message.id),
        );
      }
      final ids = [for (var i = 0; i < 20; i++) await bus.publish(topic, i)];
      await until(() => handled.length >= 20, 'twenty deliveries');
      await calm();
      expect(handled, unorderedEquals(ids));
    });

    test('MB-C4: a group keeps the messages published while no consumer of '
        'it is subscribed', () async {
      final topic = unique('c4');
      final group = unique('g');
      final first = await bus.subscribe<String>(
        topic,
        group: group,
        handler: (_) {},
      );
      await first.cancel();
      await bus.publish(topic, 'while away');
      final received = <String>[];
      await bus.subscribe<String>(
        topic,
        group: group,
        handler: (d) => received.add(d.payload),
      );
      await until(() => received.isNotEmpty, 'the kept message');
      expect(received, ['while away']);
    });

    test('MB-C5: a message published before any group subscribed reaches '
        'no one', () async {
      final topic = unique('c5');
      await bus.publish(topic, 'nobody listens');
      final received = <String>[];
      await bus.subscribe<String>(
        topic,
        group: unique('g'),
        handler: (d) => received.add(d.payload),
      );
      await calm();
      expect(received, isEmpty);
    });

    test('MB-C6: a cancelled consumer receives nothing more', () async {
      final topic = unique('c6');
      final received = <String>[];
      final subscription = await bus.subscribe<String>(
        topic,
        group: unique('g'),
        handler: (d) => received.add(d.payload),
      );
      await bus.publish(topic, 'before');
      await until(() => received.isNotEmpty, 'the first delivery');
      await subscription.cancel();
      await bus.publish(topic, 'after');
      await calm();
      expect(received, ['before']);
    });
  });

  group('ephemeral groups', () {
    test('MB-C19: an ephemeral group keeps nothing once its last consumer is '
        'gone', () async {
      final topic = unique('c19');
      final group = unique('g');
      final first = await bus.subscribe<String>(
        topic,
        group: group,
        ephemeral: true,
        handler: (_) {},
      );
      await first.cancel();
      await bus.publish(topic, 'while gone');
      final received = <String>[];
      await bus.subscribe<String>(
        topic,
        group: group,
        ephemeral: true,
        handler: (d) => received.add(d.payload),
      );
      await bus.publish(topic, 'after');
      await until(() => received.isNotEmpty, 'the later message');
      await calm();
      expect(received, ['after']);
    });

    test(
      'MB-C20: ephemeral groups fan a message out to each of them',
      () async {
        final topic = unique('c20');
        final seen = <String, List<String>>{'a': [], 'b': []};
        for (final node in ['a', 'b']) {
          await bus.subscribe<String>(
            topic,
            group: unique('node-$node'),
            ephemeral: true,
            handler: (d) => seen[node]!.add(d.payload),
          );
        }
        await bus.publish(topic, 'to everyone');
        await until(
          () => seen.values.every((l) => l.isNotEmpty),
          'both ephemeral groups',
        );
        expect(seen, {
          'a': ['to everyone'],
          'b': ['to everyone'],
        });
      },
    );
  });

  group('acknowledge and reject', () {
    test('MB-C7: an acknowledged message is not delivered again', () async {
      final topic = unique('c7');
      var deliveries = 0;
      await bus.subscribe<String>(
        topic,
        group: unique('g'),
        handler: (d) {
          deliveries++;
          d.ack();
        },
      );
      await bus.publish(topic, 'once');
      await until(() => deliveries == 1, 'the delivery');
      await calm();
      expect(deliveries, 1);
    });

    test('MB-C8: a failed delivery is repeated, with the same id and the '
        'next attempt', () async {
      final topic = unique('c8');
      final seen = <(String, int)>[];
      await bus.subscribe<String>(
        topic,
        group: unique('g'),
        handler: (d) {
          seen.add((d.message.id, d.attempt));
          if (d.attempt == 1) throw StateError('first attempt fails');
        },
      );
      final id = await bus.publish(topic, 'retry me');
      await until(() => seen.length == 2, 'the redelivery');
      await calm();
      expect(seen, [(id, 1), (id, 2)]);
    });

    test('MB-C9: reject without requeue dead-letters the message', () async {
      final topic = unique('c9');
      final group = unique('g');
      final dead = <TomBusDelivery<String>>[];
      await bus.subscribe<String>(
        tomDeadLetterTopic(topic),
        group: unique('dlq'),
        handler: dead.add,
      );
      await bus.subscribe<String>(
        topic,
        group: group,
        handler: (d) => d.reject(requeue: false, reason: 'malformed order'),
      );
      final id = await bus.publish(topic, 'bad');
      await until(() => dead.isNotEmpty, 'the dead letter');
      final letter = dead.single;
      expect(letter.message.id, id);
      expect(letter.payload, 'bad');
      expect(letter.message.headers[TomBusHeaders.deadLetterTopic], topic);
      expect(letter.message.headers[TomBusHeaders.deadLetterGroup], group);
      expect(
        letter.message.headers[TomBusHeaders.deadLetterReason],
        'malformed order',
      );
    });

    test(
      'MB-C10: a message failing maxDeliveries times is dead-lettered',
      () async {
        final topic = unique('c10');
        var attempts = 0;
        final dead = <TomBusDelivery<String>>[];
        await bus.subscribe<String>(
          tomDeadLetterTopic(topic),
          group: unique('dlq'),
          handler: dead.add,
        );
        await bus.subscribe<String>(
          topic,
          group: unique('g'),
          maxDeliveries: 2,
          handler: (_) {
            attempts++;
            throw StateError('always fails');
          },
        );
        await bus.publish(topic, 'doomed');
        await until(() => dead.isNotEmpty, 'the dead letter');
        await calm();
        expect(attempts, 2);
        final headers = dead.single.message.headers;
        expect(headers[TomBusHeaders.deadLetterReason], 'max-deliveries');
        expect(headers[TomBusHeaders.deadLetterAttempts], '2');
      },
    );

    test('MB-C11: a payload that does not decode is dead-lettered', () async {
      final topic = unique('c11');
      final dead = <TomBusDelivery<Object?>>[];
      var handled = 0;
      await bus.subscribe<Object?>(
        tomDeadLetterTopic(topic),
        group: unique('dlq'),
        handler: dead.add,
      );
      await bus.subscribe<TomConformanceOrder>(
        topic,
        group: unique('g'),
        codec: TomConformanceOrder.codec,
        handler: (_) => handled++,
      );
      await bus.publish(topic, 'not an order');
      await until(() => dead.isNotEmpty, 'the dead letter');
      expect(handled, 0);
      expect(
        dead.single.message.headers[TomBusHeaders.deadLetterReason],
        'undecodable',
      );
    });

    test('MB-C12: a delivery is settled once', () async {
      final topic = unique('c12');
      Object? second;
      await bus.subscribe<String>(
        topic,
        group: unique('g'),
        handler: (d) {
          d.ack();
          try {
            d.reject();
          } on TomBusException catch (error) {
            second = error;
          }
        },
      );
      await bus.publish(topic, 'x');
      await until(() => second != null, 'the second settlement');
      expect(
        (second! as TomBusException).key,
        'message_bus.delivery.already_settled',
      );
    });
  });

  group('payloads, headers and trace', () {
    test('MB-C13: a typed payload crosses through its codec', () async {
      final topic = unique('c13');
      final received = <TomConformanceOrder>[];
      await bus.subscribe<TomConformanceOrder>(
        topic,
        group: unique('g'),
        codec: TomConformanceOrder.codec,
        handler: (d) => received.add(d.payload),
      );
      await bus.publish(
        topic,
        const TomConformanceOrder('lamp', 3),
        codec: TomConformanceOrder.codec,
      );
      await until(() => received.isNotEmpty, 'the order');
      expect(received.single.item, 'lamp');
      expect(received.single.quantity, 3);
    });

    test('MB-C14: the handler runs in the trace the message was published '
        'in', () async {
      final topic = unique('c14');
      final trace = TomTraceContext.newRoot();
      TomTraceContext? handledIn;
      TomRequestId? requestId;
      Map<String, String>? headers;
      await bus.subscribe<String>(
        topic,
        group: unique('g'),
        handler: (d) {
          handledIn = TomTraceContext.current;
          requestId = TomRequestId.current;
          headers = d.message.headers;
        },
      );
      await TomTraceContext.run(trace, () => bus.publish(topic, 'traced'));
      await until(() => handledIn != null, 'the delivery');
      expect(handledIn!.traceId, trace.traceId);
      expect(handledIn!.spanId, isNot(trace.spanId));
      expect(requestId!.value, trace.traceId);
      expect(
        TomTraceContext.parse(headers![TomBusHeaders.traceparent])!.traceId,
        trace.traceId,
      );
    });

    test('MB-C15: a message published in no trace is handled in one of its '
        'own', () async {
      final topic = unique('c15');
      TomTraceContext? handledIn;
      await bus.subscribe<String>(
        topic,
        group: unique('g'),
        handler: (_) => handledIn = TomTraceContext.current,
      );
      await bus.publish(topic, 'untraced');
      await until(() => handledIn != null, 'the delivery');
      expect(TomRequestId.isValid(handledIn!.traceId), isTrue);
    });
  });

  group('refusals', () {
    test(
      'MB-C16: an empty group or topic, or no delivery, is refused',
      () async {
        for (final (topic, group, max) in [
          ('', 'g', 5),
          ('t', '', 5),
          ('t', 'g', 0),
        ]) {
          await expectLater(
            bus.subscribe<String>(
              topic,
              group: group,
              maxDeliveries: max,
              handler: (_) {},
            ),
            throwsA(
              isA<TomBusException>().having(
                (e) => e.key,
                'key',
                'message_bus.subscribe.invalid',
              ),
            ),
          );
        }
      },
    );

    test('MB-C17: a closed bus refuses to publish and subscribe', () async {
      await bus.close();
      Matcher closed() => throwsA(
        isA<TomBusException>().having(
          (e) => e.key,
          'key',
          'message_bus.closed',
        ),
      );
      await expectLater(bus.publish(unique('c17'), 'late'), closed());
      await expectLater(
        bus.subscribe<String>(unique('c17'), group: 'g', handler: (_) {}),
        closed(),
      );
    });
  });

  group('ordering per key', () {
    test('MB-C18: one key is handled one at a time, in publish order, a '
        'redelivery before the messages behind it', () async {
      if (!bus.capabilities.orderedPerKey) {
        markTestSkipped('The bus does not declare ordering per key.');
        return;
      }
      final topic = unique('c18');
      final group = unique('g');
      final handled = <int>[];
      var running = 0;
      var overlapped = false;
      var failedOnce = false;
      for (var i = 0; i < 3; i++) {
        await bus.subscribe<int>(
          topic,
          group: group,
          handler: (d) async {
            if (d.message.key != 'k') return;
            running++;
            if (running > 1) overlapped = true;
            await Future<void>.delayed(const Duration(milliseconds: 2));
            running--;
            if (d.payload == 3 && !failedOnce) {
              failedOnce = true;
              throw StateError('the third fails once');
            }
            handled.add(d.payload);
          },
        );
      }
      for (var i = 0; i < 10; i++) {
        await bus.publish(topic, i, key: 'k');
      }
      await until(() => handled.length == 10, 'all ten');
      expect(handled, [for (var i = 0; i < 10; i++) i]);
      expect(overlapped, isFalse);
    });
  });
}
