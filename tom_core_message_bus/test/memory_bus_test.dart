/// The in-memory bus: the conformance suite, and what only it promises —
/// [TomMemoryMessageBus.settled], the redelivery delay, and its spans.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_core_message_bus/conformance.dart';
import 'package:tom_core_message_bus/tom_core_message_bus.dart';

void main() {
  group('TomMemoryMessageBus conformance', () {
    tomMessageBusConformance(
      create: () async => TomMemoryMessageBus(),
      quiet: const Duration(milliseconds: 50),
    );
  });

  group('TomMemoryMessageBus', () {
    late TomMemoryMessageBus bus;
    setUp(() => bus = TomMemoryMessageBus());
    tearDown(() async {
      await bus.close();
      TomTracing.install(null);
    });

    test('MB-M1: declares ordering per key', () {
      expect(bus.capabilities.orderedPerKey, isTrue);
    });

    test(
      'MB-M2: settled waits for every delivery and its redeliveries',
      () async {
        final attempts = <int>[];
        await bus.subscribe<String>(
          'orders',
          group: 'billing',
          handler: (d) {
            attempts.add(d.attempt);
            if (d.attempt < 3) throw StateError('not yet');
          },
        );
        await bus.publish('orders', 'o-1');
        await bus.settled();
        expect(attempts, [1, 2, 3]);
      },
    );

    test('MB-M3: a redelivery waits for the redelivery delay', () async {
      final delayed = TomMemoryMessageBus(
        redeliveryDelay: const Duration(milliseconds: 80),
      );
      addTearDown(delayed.close);
      final at = <DateTime>[];
      await delayed.subscribe<String>(
        'orders',
        group: 'billing',
        handler: (d) {
          at.add(DateTime.now());
          if (d.attempt == 1) d.reject();
        },
      );
      await delayed.publish('orders', 'o-1');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(at, hasLength(2));
      expect(
        at[1].difference(at[0]),
        greaterThanOrEqualTo(const Duration(milliseconds: 70)),
      );
    });

    test('MB-M4: close lets a delivery under way finish', () async {
      var finished = false;
      await bus.subscribe<String>(
        'orders',
        group: 'billing',
        handler: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          finished = true;
        },
      );
      await bus.publish('orders', 'o-1');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await bus.close();
      expect(finished, isTrue);
    });

    test('MB-M5: a payload that is not JSON is refused at publish', () async {
      await expectLater(
        bus.publish('orders', {'when': Object()}),
        throwsA(
          isA<TomBusException>().having(
            (e) => e.key,
            'key',
            'message_bus.payload.not_json',
          ),
        ),
      );
    });

    test('MB-M6: with a tracer, publish is a producer span and handling a '
        'consumer span continuing it', () async {
      final tracer = TomRecordingTracer();
      TomTracing.install(tracer);
      await bus.subscribe<String>(
        'orders',
        group: 'billing',
        handler: (_) async {},
      );
      await TomTracing.trace('request', (_) => bus.publish('orders', 'o-1'));
      await bus.settled();
      final request = tracer.named('request').single;
      final publish = tracer.named('orders publish').single;
      final process = tracer.named('orders process').single;
      expect(tracer.childrenOf(request), [publish]);
      expect(tracer.childrenOf(publish), [process]);
      expect(publish.kind, TomSpanKind.producer);
      expect(process.kind, TomSpanKind.consumer);
      expect(process.attributes['messaging.consumer.group.name'], 'billing');
    });

    test(
      'MB-M7: a message keeps its JSON form, not the published object',
      () async {
        final published = <String, Object?>{
          'lines': <Object?>[1, 2],
        };
        Map<String, Object?>? received;
        await bus.subscribe<Map<String, Object?>>(
          'orders',
          group: 'billing',
          handler: (d) => received = d.payload,
        );
        await bus.publish('orders', published);
        (published['lines']! as List).add(3);
        await bus.settled();
        expect(received, {
          'lines': [1, 2],
        });
      },
    );

    test('MB-M8: the message survives its JSON form', () {
      final message = TomBusMessage(
        id: 'm-1',
        topic: 'orders',
        key: 'c-7',
        payload: {'n': 1},
        headers: {'traceparent': 'x'},
        publishedAt: DateTime.utc(2026, 11, 4, 12),
      );
      final back = TomBusMessage.fromJson(message.toJson());
      expect(back.id, 'm-1');
      expect(back.topic, 'orders');
      expect(back.key, 'c-7');
      expect(back.payload, {'n': 1});
      expect(back.headers, {'traceparent': 'x'});
      expect(back.publishedAt, DateTime.utc(2026, 11, 4, 12));
    });
  });
}
