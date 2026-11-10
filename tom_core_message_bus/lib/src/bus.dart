/// The broker-neutral contract: what every message bus — the in-memory one,
/// and an adapter over Kafka, RabbitMQ, NATS or a cloud broker — promises.
library;

import 'dart:async';

import 'codec.dart';
import 'message.dart';

/// What a bus can do beyond the contract every bus keeps.
class TomBusCapabilities {
  /// The capabilities of a bus.
  const TomBusCapabilities({this.orderedPerKey = false});

  /// Whether messages of one key are delivered to a group one at a time, in
  /// the order they were published — the next only once the previous is
  /// settled, a redelivery before the messages behind it.
  final bool orderedPerKey;
}

/// A consumer's place on a topic: deliveries reach it until it is
/// [cancel]led.
abstract class TomBusSubscription {
  /// The topic.
  String get topic;

  /// The consumer group.
  String get group;

  /// Stops this consumer's deliveries. A delivery it is handling completes;
  /// the group's other consumers, and the group itself, are untouched.
  Future<void> cancel();
}

/// The topic a message of [topic] is dead-lettered to: `<topic>.dlq`.
String tomDeadLetterTopic(String topic) => '$topic.dlq';

/// The headers a dead-lettered message carries besides its own.
abstract final class TomBusHeaders {
  /// The topic the message was published to.
  static const String deadLetterTopic = 'tom-dead-letter-topic';

  /// The group that gave it up.
  static const String deadLetterGroup = 'tom-dead-letter-group';

  /// Why: the consumer's reason, `max-deliveries`, `undecodable` or
  /// `invalid-tenant`.
  static const String deadLetterReason = 'tom-dead-letter-reason';

  /// How many deliveries it had.
  static const String deadLetterAttempts = 'tom-dead-letter-attempts';

  /// The W3C `traceparent` of the trace the message was published in.
  static const String traceparent = 'traceparent';

  /// The W3C `tracestate` that goes with it.
  static const String tracestate = 'tracestate';

  /// The tenant the message was published in — the tenant in context at the
  /// publish — which its handling runs in ([TomBusTrace.delivering]).
  static const String tenant = 'tom-tenant';
}

/// A message bus.
///
/// ## The contract
///
/// - **Publish and subscribe.** A message published to a topic is delivered to
///   every consumer group subscribed to the topic.
/// - **Consumer groups.** Within a group each message is handled by one of its
///   consumers; consumers of one group compete for the messages.
/// - **Durable groups.** A group exists from its first subscription. A message
///   published while none of its consumers is subscribed waits for the next;
///   a message published to a topic no group has subscribed to reaches no one.
/// - **Ephemeral groups.** A group subscribed `ephemeral` lives only while one
///   of its consumers is subscribed in this bus: when its last consumer
///   cancels, the group and what waits for it are gone, and a later
///   subscription starts a new group. The shape of a fan-out to every running
///   process — each subscribes with a group of its own, ephemeral, so a process
///   that stops leaves nothing behind on the broker.
/// - **At least once.** A delivery is repeated until it is acknowledged or
///   dead-lettered, and may be repeated even then after a failure: the message
///   [TomBusMessage.id] is the same on every delivery, for a consumer to
///   recognise one it has handled.
/// - **Acknowledge and reject.** A handler settles its [TomBusDelivery]:
///   returning acknowledges, throwing or `reject()` redelivers, `reject(
///   requeue: false)` dead-letters.
/// - **Dead letters.** A message rejected without requeue, one whose attempts
///   reach the subscription's `maxDeliveries`, and one whose payload does not
///   decode are published to [tomDeadLetterTopic] with [TomBusHeaders]
///   naming why, where a group subscribed to that topic receives them.
/// - **Headers and trace.** Headers arrive as published. A message published in
///   a trace carries its position (`traceparent`, `tracestate`), and its
///   handler runs in that trace — see `trace.dart`.
/// - **Typed payloads.** A publish encodes, a subscription decodes, through a
///   [TomBusCodec] — by default through reflection.
/// - **Ordering per key** is a capability, not the contract: see
///   [capabilities].
///
/// `conformance.dart` holds the suite that checks every point; an adapter runs
/// it against its broker.
abstract class TomMessageBus {
  /// What this bus does beyond the contract.
  TomBusCapabilities get capabilities;

  /// Publishes [payload] to [topic], encoded by [codec] (the reflection codec
  /// unless given); answers the message
  /// id — [id] when given, a new one otherwise. [key] orders the message
  /// among those of the same key where [capabilities] say so.
  ///
  /// Published in a trace, the message carries the trace in its headers.
  /// Throws `message_bus.closed` once the bus is closed.
  Future<String> publish<T>(
    String topic,
    T payload, {
    String? key,
    Map<String, String> headers = const {},
    String? id,
    TomBusCodec<T>? codec,
  });

  /// Subscribes [handler] to [topic] as a consumer of [group], decoding each
  /// payload with [codec] (the reflection codec unless given). A message is
  /// dead-lettered on its [maxDeliveries]th failed delivery. With [ephemeral]
  /// the group lives only while it has a consumer in this bus — see the
  /// contract; a group's first subscription decides whether it is.
  ///
  /// Throws `message_bus.subscribe.invalid` for an empty topic or group, or a
  /// [maxDeliveries] below 1, and `message_bus.closed` once the bus is
  /// closed.
  Future<TomBusSubscription> subscribe<T>(
    String topic, {
    required String group,
    required TomBusHandler<T> handler,
    TomBusCodec<T>? codec,
    int maxDeliveries = 5,
    bool ephemeral = false,
  });

  /// Stops every subscription, lets the deliveries under way finish, and
  /// refuses further publishing and subscribing. Idempotent.
  Future<void> close();
}

/// Refuses an empty topic or group, or a [maxDeliveries] below 1.
void tomCheckSubscription(String topic, String group, int maxDeliveries) {
  if (topic.isEmpty || group.isEmpty || maxDeliveries < 1) {
    throw TomBusException(
      'message_bus.subscribe.invalid',
      'A subscription needs a topic, a group and at least one delivery '
          "(topic '$topic', group '$group', maxDeliveries $maxDeliveries).",
      parameters: {
        'topic': topic,
        'group': group,
        'maxDeliveries': maxDeliveries,
      },
    );
  }
}
