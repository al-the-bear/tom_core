// ignore_for_file: avoid_print
/// The message bus in one process: a typed event published to a topic, two
/// consumer groups each receiving it, a failing consumer retried and then
/// dead-lettered, and the trace carried from the publisher to the consumer.
///
/// Run with `dart run example/message_bus_example.dart`. Every step checks its
/// own result and the run fails when one does not hold.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_core_message_bus/tom_core_message_bus.dart';

import 'message_bus_example.reflection.dart';

/// An event, crossing the bus through reflection — no codec written for it.
@tomReflector
class OrderPlaced {
  /// The order.
  String orderId = '';

  /// Its total, in cents.
  int totalCents = 0;
}

void check(bool ok, String expectation) {
  if (!ok) throw StateError('example check failed: $expectation');
}

Future<void> main() async {
  initializeReflection();
  final bus = TomMemoryMessageBus();

  // 1. Two groups subscribe to one topic: each receives every message.
  final billed = <String>[];
  final shipped = <String>[];
  await bus.subscribe<OrderPlaced>(
    'orders',
    group: 'billing',
    handler: (d) => billed.add(d.payload.orderId),
  );
  await bus.subscribe<OrderPlaced>(
    'orders',
    group: 'shipping',
    handler: (d) => shipped.add(d.payload.orderId),
  );
  await bus.publish(
    'orders',
    OrderPlaced()
      ..orderId = 'o-1'
      ..totalCents = 4200,
  );
  await bus.settled();
  print('1. billing $billed, shipping $shipped');
  check(billed.single == 'o-1' && shipped.single == 'o-1', 'both groups');

  // 2. A consumer that fails is retried; after maxDeliveries the message is
  //    dead-lettered to `<topic>.dlq`, with the reason in its headers.
  final dead = <TomBusDelivery<Object?>>[];
  await bus.subscribe<Object?>(
    tomDeadLetterTopic('invoices'),
    group: 'operators',
    handler: dead.add,
  );
  var attempts = 0;
  await bus.subscribe<Object?>(
    'invoices',
    group: 'printing',
    maxDeliveries: 3,
    handler: (_) {
      attempts++;
      throw StateError('the printer is out of paper');
    },
  );
  await bus.publish('invoices', {'invoice': 'i-9'});
  await bus.settled();
  final reason = dead.single.message.headers[TomBusHeaders.deadLetterReason];
  print('2. $attempts attempts, then dead-lettered: $reason');
  check(attempts == 3 && reason == 'max-deliveries', 'retried, then parked');

  // 3. A message published in a trace is handled in that trace.
  String? handledInTrace;
  await bus.subscribe<Object?>(
    'audit',
    group: 'archive',
    handler: (_) => handledInTrace = TomTraceContext.current?.traceId,
  );
  final request = TomTraceContext.newRoot();
  await TomTraceContext.run(request, () => bus.publish('audit', 'login'));
  await bus.settled();
  print('3. handled in trace $handledInTrace');
  check(handledInTrace == request.traceId, 'the trace crosses the bus');

  await bus.close();
}
