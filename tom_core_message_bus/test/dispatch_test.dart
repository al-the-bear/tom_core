/// The delivery step every bus shares ([tomDispatch]) and the dead letter it
/// publishes ([tomDeadLetter]).
library;

import 'package:test/test.dart';
import 'package:tom_core_message_bus/conformance.dart';
import 'package:tom_core_message_bus/tom_core_message_bus.dart';

TomBusMessage _message(Object? payload) => TomBusMessage(
  id: 'm-1',
  topic: 'orders',
  key: 'c-7',
  payload: payload,
  headers: const {'x-tenant': 'acme'},
  publishedAt: DateTime.utc(2026, 11, 6),
);

void main() {
  test('MB-D1: a handler that returns acknowledges the delivery', () async {
    TomBusDelivery<String>? seen;
    final result = await tomDispatch<String>(
      _message('hello'),
      attempt: 2,
      group: 'billing',
      codec: TomBusCodec<String>.reflected(),
      handler: (d) => seen = d,
    );
    expect(result, (TomBusOutcome.acknowledged, null));
    expect(seen!.payload, 'hello');
    expect(seen!.attempt, 2);
    expect(seen!.group, 'billing');
  });

  test('MB-D2: a handler that throws rejects for redelivery, the error as '
      'its reason', () async {
    final (outcome, reason) = await tomDispatch<String>(
      _message('hello'),
      attempt: 1,
      group: 'billing',
      codec: TomBusCodec<String>.reflected(),
      handler: (_) => throw StateError('printer jammed'),
    );
    expect(outcome, TomBusOutcome.requeued);
    expect(reason, contains('printer jammed'));
  });

  test('MB-D3: the handler\'s own settlement stands', () async {
    final result = await tomDispatch<String>(
      _message('hello'),
      attempt: 1,
      group: 'billing',
      codec: TomBusCodec<String>.reflected(),
      handler: (d) {
        d.reject(requeue: false, reason: 'malformed');
        throw StateError('after settling');
      },
    );
    expect(result, (TomBusOutcome.deadLettered, 'malformed'));
  });

  test('MB-D4: a payload that does not decode is dead-lettered without '
      'reaching the handler', () async {
    var handled = 0;
    final result = await tomDispatch<TomConformanceOrder>(
      _message('not an order'),
      attempt: 1,
      group: 'billing',
      codec: TomConformanceOrder.codec,
      handler: (_) => handled++,
    );
    expect(result, (TomBusOutcome.deadLettered, 'undecodable'));
    expect(handled, 0);
  });

  test('MB-D5: the dead letter is the message on the dead-letter topic, with '
      'the headers naming why', () {
    final letter = tomDeadLetter(
      _message('hello'),
      group: 'billing',
      reason: 'max-deliveries',
      attempts: 5,
    );
    expect(letter.topic, 'orders.dlq');
    expect(letter.id, 'm-1');
    expect(letter.key, 'c-7');
    expect(letter.payload, 'hello');
    expect(letter.headers, {
      'x-tenant': 'acme',
      TomBusHeaders.deadLetterTopic: 'orders',
      TomBusHeaders.deadLetterGroup: 'billing',
      TomBusHeaders.deadLetterReason: 'max-deliveries',
      TomBusHeaders.deadLetterAttempts: '5',
    });
  });
}
