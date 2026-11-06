/// The steps every bus takes for one delivery — decode, hand to the handler in
/// the published trace, read the outcome — and the dead letter it publishes
/// when a delivery ends there. An adapter maps the outcome onto its broker.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'bus.dart';
import 'codec.dart';
import 'message.dart';
import 'trace.dart';

/// Decodes [message] with [codec], runs [handler] on it in the trace it was
/// published in ([TomBusTrace.delivering]) as delivery [attempt] to [group],
/// and answers how the delivery ended, with the reason a rejection gave.
///
/// A payload [codec] cannot decode ends dead-lettered, reason `undecodable`,
/// without reaching [handler]. A handler that throws without settling the
/// delivery rejects it for redelivery, the error as its reason; one that
/// returns without settling acknowledges it.
Future<(TomBusOutcome, String?)> tomDispatch<T>(
  TomBusMessage message, {
  required int attempt,
  required String group,
  required TomBusCodec<T> codec,
  required TomBusHandler<T> handler,
}) async {
  final T payload;
  try {
    payload = codec.decode(message.payload);
  } on TomBusException {
    return (TomBusOutcome.deadLettered, 'undecodable');
  }
  final delivery = TomBusDelivery<T>(
    message: message,
    payload: payload,
    attempt: attempt,
    group: group,
  );
  try {
    await TomBusTrace.delivering(message, group, () async => handler(delivery));
  } on Object catch (error) {
    tomLog.warn(
      'Message ${message.id} of ${message.topic} failed in $group, '
      'attempt $attempt: $error',
    );
    if (delivery.outcome == null) delivery.reject(reason: '$error');
  }
  return (delivery.outcome ?? TomBusOutcome.acknowledged, delivery.reason);
}

/// The dead letter of [message]: the same message on its topic's dead-letter
/// topic ([tomDeadLetterTopic]), with the headers naming the topic, the
/// [group] that gave up, the [reason] and the [attempts] made.
TomBusMessage tomDeadLetter(
  TomBusMessage message, {
  required String group,
  required String reason,
  required int attempts,
}) => message.withHeaders({
  TomBusHeaders.deadLetterTopic: message.topic,
  TomBusHeaders.deadLetterGroup: group,
  TomBusHeaders.deadLetterReason: reason,
  TomBusHeaders.deadLetterAttempts: '$attempts',
}, topic: tomDeadLetterTopic(message.topic));
