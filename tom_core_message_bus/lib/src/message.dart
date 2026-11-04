/// What travels on the bus: the message, and one delivery of it to a
/// consumer.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A bus operation that cannot be carried out.
class TomBusException extends TomException {
  /// Creates the exception; the parameters are [TomException]'s.
  TomBusException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
  });
}

/// A message as it travels: its id, its topic, its ordering key, a JSON
/// payload and its headers.
///
/// The payload is JSON — a map, a list, a string, a number, a boolean or
/// `null` — because that is what every broker carries; a typed payload is
/// encoded to it and decoded from it by a [TomBusCodec].
///
/// The [id] is the message's identity across every delivery of it. The bus
/// delivers at least once, so a consumer that must not act twice keeps the ids
/// it has handled.
class TomBusMessage {
  /// A message of [topic] carrying [payload].
  TomBusMessage({
    required this.id,
    required this.topic,
    required this.payload,
    required this.publishedAt,
    this.key,
    Map<String, String> headers = const {},
  }) : headers = Map.unmodifiable(headers);

  /// The message's identity, the same on every delivery.
  final String id;

  /// The topic it was published to.
  final String topic;

  /// The ordering key: messages of one key are delivered in the order they
  /// were published by a bus that declares [TomBusCapabilities.orderedPerKey];
  /// `null` for none.
  final String? key;

  /// The payload, as JSON.
  final Object? payload;

  /// The headers — `traceparent` and `tracestate` among them when the message
  /// was published in a trace.
  final Map<String, String> headers;

  /// When it was published.
  final DateTime publishedAt;

  /// The message with [headers] added to its own and, when given, another
  /// [topic].
  TomBusMessage withHeaders(Map<String, String> headers, {String? topic}) =>
      TomBusMessage(
        id: id,
        topic: topic ?? this.topic,
        key: key,
        payload: payload,
        publishedAt: publishedAt,
        headers: {...this.headers, ...headers},
      );

  /// The message as JSON, the form an adapter may put on the wire.
  Map<String, Object?> toJson() => {
    'id': id,
    'topic': topic,
    'key': ?key,
    'payload': payload,
    'headers': headers,
    'publishedAt': publishedAt.toUtc().toIso8601String(),
  };

  /// The message [toJson] wrote.
  factory TomBusMessage.fromJson(Map<String, Object?> json) => TomBusMessage(
    id: json['id']! as String,
    topic: json['topic']! as String,
    key: json['key'] as String?,
    payload: json['payload'],
    headers: {
      for (final entry in ((json['headers'] as Map?) ?? const {}).entries)
        '${entry.key}': '${entry.value}',
    },
    publishedAt: DateTime.parse(json['publishedAt']! as String),
  );

  @override
  String toString() => 'TomBusMessage($topic, $id)';
}

/// What a consumer decided about a delivery.
enum TomBusOutcome {
  /// Handled: the message is not delivered to this group again.
  acknowledged,

  /// To be delivered again, as a new attempt.
  requeued,

  /// Moved to the topic's dead-letter topic.
  deadLettered,
}

/// One delivery of a message to a consumer of a group, its payload decoded.
///
/// The consumer settles it once: [ack], or [reject] — which redelivers it, or
/// with `requeue: false` dead-letters it. A handler that returns without
/// settling acknowledges; one that throws rejects, to be redelivered. A
/// delivery whose attempts reach the subscription's `maxDeliveries` is
/// dead-lettered instead of redelivered.
class TomBusDelivery<T> {
  /// The delivery of [message], its payload decoded to [payload], as attempt
  /// [attempt] (from 1) for [group].
  TomBusDelivery({
    required this.message,
    required this.payload,
    required this.attempt,
    required this.group,
  });

  /// The message delivered.
  final TomBusMessage message;

  /// Its payload, decoded.
  final T payload;

  /// Which attempt this is, from 1.
  final int attempt;

  /// The consumer group it is delivered to.
  final String group;

  TomBusOutcome? _outcome;
  String? _reason;

  /// The consumer's decision, or `null` while unsettled.
  TomBusOutcome? get outcome => _outcome;

  /// Why it was rejected, when the consumer said.
  String? get reason => _reason;

  /// Acknowledges: the message is handled.
  void ack() => _settle(TomBusOutcome.acknowledged, null);

  /// Rejects: with [requeue] the message is delivered again (dead-lettered
  /// once its attempts are spent), without it dead-lettered now; [reason] is
  /// recorded on a dead-lettered message.
  void reject({bool requeue = true, String? reason}) => _settle(
    requeue ? TomBusOutcome.requeued : TomBusOutcome.deadLettered,
    reason,
  );

  void _settle(TomBusOutcome outcome, String? reason) {
    if (_outcome != null) {
      throw TomBusException(
        'message_bus.delivery.already_settled',
        'The delivery of ${message.id} was already settled '
            '(${_outcome!.name}).',
        parameters: {'message': message.id, 'outcome': _outcome!.name},
      );
    }
    _outcome = outcome;
    _reason = reason;
  }
}

/// Handles the deliveries of a subscription.
typedef TomBusHandler<T> = FutureOr<void> Function(TomBusDelivery<T> delivery);
