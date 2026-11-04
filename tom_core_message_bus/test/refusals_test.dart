/// The refusals of the bus, keyed: a closed bus, a subscription that cannot
/// be made, a delivery settled twice.
library;

import 'package:test/test.dart';
import 'package:tom_core_message_bus/tom_core_message_bus.dart';

Matcher _keyed(String key) =>
    throwsA(isA<TomBusException>().having((e) => e.key, 'key', key));

void main() {
  test('MB-E1: a closed bus refuses publish and subscribe '
      '(message_bus.closed)', () async {
    final bus = TomMemoryMessageBus();
    await bus.close();
    await expectLater(bus.publish('t', 'x'), _keyed('message_bus.closed'));
    await expectLater(
      bus.subscribe<String>('t', group: 'g', handler: (_) {}),
      _keyed('message_bus.closed'),
    );
  });

  test('MB-E2: a subscription without topic, group or delivery is refused '
      '(message_bus.subscribe.invalid)', () {
    expect(
      () => tomCheckSubscription('', 'g', 1),
      throwsA(
        isA<TomBusException>().having(
          (e) => e.key,
          'key',
          'message_bus.subscribe.invalid',
        ),
      ),
    );
    expect(
      () => tomCheckSubscription('t', '', 1),
      throwsA(isA<TomBusException>()),
    );
    expect(
      () => tomCheckSubscription('t', 'g', 0),
      throwsA(isA<TomBusException>()),
    );
  });

  test('MB-E3: a delivery is settled once '
      '(message_bus.delivery.already_settled)', () {
    final delivery = TomBusDelivery<String>(
      message: TomBusMessage(
        id: 'm-1',
        topic: 't',
        payload: 'x',
        publishedAt: DateTime.utc(2026, 11, 4),
      ),
      payload: 'x',
      attempt: 1,
      group: 'g',
    );
    delivery.reject(requeue: false, reason: 'bad');
    expect(delivery.outcome, TomBusOutcome.deadLettered);
    expect(delivery.reason, 'bad');
    expect(
      delivery.ack,
      throwsA(
        isA<TomBusException>().having(
          (e) => e.key,
          'key',
          'message_bus.delivery.already_settled',
        ),
      ),
    );
  });
}
