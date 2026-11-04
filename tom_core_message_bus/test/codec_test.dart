/// Typed payloads through the kernel's reflection: a `@tomReflector` class
/// crosses the bus with no codec written for it.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_core_message_bus/tom_core_message_bus.dart';

import 'codec_test.reflection.dart';

/// A payload class with plain fields, as the kernel's reflection reads them.
@tomReflector
class OrderPlaced {
  /// The order.
  String orderId = '';

  /// How many lines it has.
  int lines = 0;

  /// The customer's tags.
  List<String> tags = [];
}

void main() {
  setUpAll(initializeReflection);

  test(
    'MB-R1: a reflectable payload is published as JSON and decoded back',
    () async {
      final bus = TomMemoryMessageBus();
      addTearDown(bus.close);
      final received = <OrderPlaced>[];
      Object? wire;
      await bus.subscribe<OrderPlaced>(
        'orders',
        group: 'billing',
        handler: (d) {
          wire = d.message.payload;
          received.add(d.payload);
        },
      );
      await bus.publish(
        'orders',
        OrderPlaced()
          ..orderId = 'o-1'
          ..lines = 3
          ..tags = ['vip'],
      );
      await bus.settled();
      expect(wire, isA<Map<String, Object?>>());
      expect((wire! as Map)['orderId'], 'o-1');
      expect(received.single.orderId, 'o-1');
      expect(received.single.lines, 3);
      expect(received.single.tags, ['vip']);
    },
  );

  test('MB-R2: JSON values pass through unchanged', () {
    const codec = TomBusCodec<Object?>.reflected();
    expect(codec.decode(codec.encode({'a': 1})), {'a': 1});
    expect(codec.decode(codec.encode('text')), 'text');
    expect(codec.decode(codec.encode(null)), isNull);
  });

  test('MB-R3: JSON that is not the type is undecodable', () {
    expect(
      () => const TomBusCodec<OrderPlaced>.reflected().decode('a string'),
      throwsA(
        isA<TomBusException>().having(
          (e) => e.key,
          'key',
          'message_bus.payload.undecodable',
        ),
      ),
    );
  });
}
