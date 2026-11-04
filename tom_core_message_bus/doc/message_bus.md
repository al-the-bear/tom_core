# Message Bus

A broker-neutral message bus for Tom services. A service publishes typed
messages to a topic; consumer groups subscribed to the topic receive them,
acknowledge or reject each delivery, and find what they gave up on in a
dead-letter topic. The trace a message was published in continues in its
handler. The package holds the contract (`TomMessageBus`), the in-memory bus
that keeps it inside one process (`TomMemoryMessageBus`), and the conformance
suite every bus — that one and every adapter over a broker — passes.

**The contract is at least once.** A message is delivered until a consumer of
its group acknowledges it or it is dead-lettered, and it may be delivered again
even then after a failure. Its id is the same on every delivery, so a consumer
that must not act twice keeps the ids it has handled — the server's idempotent
receiver, `TomInbox`, does exactly that (see the server's
[messaging guide](../../tom_core_server/doc/messaging.md#idempotent-receiver-inbox)).

## Table of Contents

- [Overview](#overview)
- [The Contract](#the-contract)
- [Consumer Groups](#consumer-groups)
  - [Durable groups](#durable-groups)
  - [Cancelling a consumer](#cancelling-a-consumer)
- [Acknowledge, Reject and Dead Letters](#acknowledge-reject-and-dead-letters)
  - [Settling a delivery](#settling-a-delivery)
  - [The dead-letter topic](#the-dead-letter-topic)
- [Typed Payloads and Codecs](#typed-payloads-and-codecs)
- [Headers and Trace](#headers-and-trace)
- [The Message on the Wire](#the-message-on-the-wire)
- [The In-Memory Bus](#the-in-memory-bus)
- [Ordering per Key](#ordering-per-key)
- [Writing an Adapter](#writing-an-adapter)
- [The Conformance Suite](#the-conformance-suite)
- [Error Keys](#error-keys)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomMessageBus` | abstract class | The contract every bus keeps: `publish`, `subscribe`, `close`, `capabilities` |
| `TomBusCapabilities` | class | What a bus does beyond the contract: `orderedPerKey` |
| `TomBusSubscription` | abstract class | One consumer's place on a topic: `topic`, `group`, `cancel` |
| `tomDeadLetterTopic` | function | The dead-letter topic of a topic: `<topic>.dlq` |
| `TomBusHeaders` | abstract final class | The header names a bus writes: the four dead-letter headers, `traceparent`, `tracestate` |
| `tomCheckSubscription` | function | Refuses an empty topic or group, or `maxDeliveries` below 1 |
| `TomBusException` | class | Every refusal of the bus (extends the kernel's `TomException`) |
| `TomBusMessage` | class | A message as it travels: id, topic, key, JSON payload, headers, publish time |
| `TomBusOutcome` | enum | `acknowledged`, `requeued`, `deadLettered` |
| `TomBusDelivery<T>` | class | One delivery of a message to a consumer, its payload decoded; settled once |
| `TomBusHandler<T>` | typedef | The function a subscription runs for each delivery |
| `TomBusCodec<T>` | class | A typed payload to JSON and back; `TomBusCodec.reflected()` by default |
| `TomBusTrace` | abstract final class | The trace across the bus: `publishing` and `delivering` |
| `TomMemoryMessageBus` | class | The contract in one process, with ordering per key and `settled()` |
| `tomMessageBusConformance` | function | The conformance suite, MB-C1 to MB-C18 (`conformance.dart`) |
| `TomConformanceOrder` | class | The typed payload, with its own codec, the suite's MB-C11 and MB-C13 use (`conformance.dart`) |

The barrel `package:tom_core_message_bus/tom_core_message_bus.dart` exports
`bus.dart`, `message.dart`, `codec.dart`, `trace.dart` and `memory_bus.dart`.
The conformance suite is the second library,
`package:tom_core_message_bus/conformance.dart`; it imports `package:test`, so
only test code imports it.

## The Contract

`TomMessageBus` states nine points. The first eight are the contract every bus
keeps; the ninth is the one capability a bus may declare or not.

1. **Publish and subscribe.** A message published to a topic is delivered to
   every consumer group subscribed to the topic.
2. **Consumer groups.** Within a group each message is handled by one of its
   consumers; the consumers of one group compete for the messages.
3. **Durable groups.** A group exists from its first subscription. A message
   published while none of its consumers is subscribed waits for the next; a
   message published to a topic no group has subscribed to reaches no one.
4. **At least once.** A delivery is repeated until it is acknowledged or
   dead-lettered, and may be repeated even then after a failure. The message id
   is the same on every delivery.
5. **Acknowledge and reject.** A handler settles its `TomBusDelivery`:
   returning acknowledges, throwing or `reject()` redelivers,
   `reject(requeue: false)` dead-letters.
6. **Dead letters.** A message rejected without requeue, one whose attempts
   reach the subscription's `maxDeliveries`, and one whose payload does not
   decode are published to `tomDeadLetterTopic(topic)` with `TomBusHeaders`
   naming why, where a group subscribed to that topic receives them.
7. **Headers and trace.** Headers arrive as published. A message published in a
   trace carries its position (`traceparent`, `tracestate`), and its handler
   runs in that trace.
8. **Typed payloads.** A publish encodes and a subscription decodes through a
   `TomBusCodec` — by default through reflection.
9. **Ordering per key** is a capability, not the contract: see
   [Ordering per Key](#ordering-per-key).

```dart
abstract class TomMessageBus {
  TomBusCapabilities get capabilities;

  Future<String> publish<T>(
    String topic,
    T payload, {
    String? key,
    Map<String, String> headers = const {},
    String? id,
    TomBusCodec<T>? codec,
  });

  Future<TomBusSubscription> subscribe<T>(
    String topic, {
    required String group,
    required TomBusHandler<T> handler,
    TomBusCodec<T>? codec,
    int maxDeliveries = 5,
  });

  Future<void> close();
}
```

`publish` answers the message id: `id` when the caller gives one, a new one
otherwise. A caller that may publish the same message twice — a retry after a
lost acknowledgement — gives the id itself, so the second publish carries the
id a consumer already knows. `close` stops every subscription, lets the
deliveries under way finish and refuses further publishing and subscribing; a
second call is the same close.

## Consumer Groups

A **group** is a named set of consumers of one topic. Every group subscribed to
a topic receives every message published to it (MB-C2); within a group one
consumer handles each message (MB-C3). A group is how a service scales: start a
second instance with the same group name and the two share the messages; give
a second service its own group and it receives all of them as well.

```dart
await bus.subscribe<OrderPlaced>('orders', group: 'billing', handler: bill);
await bus.subscribe<OrderPlaced>('orders', group: 'shipping', handler: ship);
```

### Durable groups

A group exists from its first subscription and keeps its messages while it has
no consumer: a message published after the last consumer of `billing`
cancelled waits for the next one to subscribe (MB-C4). Before a group's first
subscription there is nothing to keep the message for — a message published to
a topic no group has subscribed to reaches no one (MB-C5). A service subscribes
its groups before it relies on receiving anything.

How long a group keeps a waiting message is the bus's: the in-memory bus keeps
it until the process ends; a broker keeps it as its own retention says.

### Cancelling a consumer

`TomBusSubscription.cancel` stops that consumer's deliveries (MB-C6). A delivery
it is handling completes; the group's other consumers, and the group itself,
are untouched, so the messages it would have received go to them or wait.

## Acknowledge, Reject and Dead Letters

### Settling a delivery

A handler receives a `TomBusDelivery<T>`: the `message`, its decoded `payload`,
the `attempt` (from 1) and the `group`. It settles the delivery once:

| The handler | Outcome | What follows |
| ----------- | ------- | ------------ |
| returns without settling, or calls `ack()` | `acknowledged` | The message is not delivered to this group again (MB-C7) |
| throws, or calls `reject()` | `requeued` | Delivered again as the next attempt, with the same id (MB-C8) — dead-lettered with `max-deliveries` once its attempts reach `maxDeliveries` (MB-C10) |
| calls `reject(requeue: false, reason: ...)` | `deadLettered` | Published to the dead-letter topic now, with the reason (MB-C9) |

A second `ack` or `reject` throws `message_bus.delivery.already_settled`
(MB-C12). A handler that settled and then threw keeps the outcome it settled
with. `outcome` and `reason` read the decision back.

`maxDeliveries` is per subscription, 5 by default; a value below 1 is refused.
A handler that cannot succeed for this message — a validation failure, a
reference to a record that does not exist — rejects without requeue rather than
throwing, so the message does not spend its attempts on a failure that will
repeat.

### The dead-letter topic

A message is dead-lettered to `tomDeadLetterTopic(topic)`, `<topic>.dlq`, as the
same message — its id, key, payload and publish time — with four headers added
to its own:

| Header | Constant | Value |
| ------ | -------- | ----- |
| `tom-dead-letter-topic` | `TomBusHeaders.deadLetterTopic` | The topic it was published to |
| `tom-dead-letter-group` | `TomBusHeaders.deadLetterGroup` | The group that gave it up |
| `tom-dead-letter-reason` | `TomBusHeaders.deadLetterReason` | The consumer's reason; `max-deliveries` when its attempts ran out; `undecodable` when its payload did not decode (MB-C11) |
| `tom-dead-letter-attempts` | `TomBusHeaders.deadLetterAttempts` | How many deliveries it had |

The dead-letter topic is a topic like any other: an operator's tool, or a
service that repairs and republishes, subscribes a group to it. Like any topic,
it reaches no one until a group has subscribed, so a deployment that wants its
dead letters subscribes before they occur. Each group dead-letters on its own:
a message one group gave up on may have been handled by another.

## Typed Payloads and Codecs

A message carries JSON — a map, a list, a string, a number, a boolean or
`null` — because that is what every broker carries. A typed payload is encoded
to JSON by the publisher and decoded by each subscription, through a
`TomBusCodec<T>`.

`TomBusCodec.reflected()`, the default of every `publish` and `subscribe`, takes
a JSON value as it is and any other object through the kernel's reflection, so
a `@tomReflector` class with plain fields crosses the bus with no codec written
for it:

```dart
@tomReflector
class OrderPlaced {
  String orderId = '';
  int totalCents = 0;
}

await bus.subscribe<OrderPlaced>(
  'orders',
  group: 'billing',
  handler: (delivery) => print(delivery.payload.orderId),
);
await bus.publish('orders', OrderPlaced()..orderId = 'o-1');
```

The class needs its reflection generated (`dart run build_runner build`) and
initialised before the first publish. A type with a wire shape of its own
supplies a codec, on the publish and on the subscription:

```dart
final orderCodec = TomBusCodec<Order>(
  (order) => {'item': order.item, 'quantity': order.quantity},
  (json) {
    final map = json! as Map;
    return Order(map['item']! as String, map['quantity']! as int);
  },
);

await bus.publish('orders', order, codec: orderCodec);
await bus.subscribe<Order>('orders', group: 'g', codec: orderCodec, handler: handle);
```

`encode` passes its result through the JSON text form, so what is published is
exactly what a broker would carry and never a live object a consumer could
change under the publisher. A payload that does not encode to JSON throws
`message_bus.payload.not_json` at `publish`. A payload that does not decode to
the subscription's type is not handed to the handler: the delivery is
dead-lettered with the reason `undecodable`, since a redelivery would fail the
same way. `decode` itself throws `message_bus.payload.undecodable`.

## Headers and Trace

Headers are strings, and arrive as published (MB-C1). A message published in a
trace carries the trace's position in `traceparent` and `tracestate`, and its
handler runs in that trace (MB-C14): a new span of it, under a request id equal
to the trace id, so the handler's log lines, server exceptions and audit
entries name the request that published the message. A message published in no
trace is handled in a trace of its own (MB-C15).

Both halves go through `TomBusTrace`, which every bus calls, so a trace crosses
any broker the same way:

| Call | Runs | With a tracer installed |
| ---- | ---- | ----------------------- |
| `TomBusTrace.publishing(topic, headers, publish)` | `publish` with `headers` plus the trace's position, when the current zone is in a trace | A `producer` span, `<topic> publish` (`messaging.operation.type` `send`, `messaging.destination.name`), whose position is the one sent |
| `TomBusTrace.delivering(message, group, handle)` | `handle` in the trace the message's `traceparent` names, or a new root trace, under `TomRequestId.of(traceId)` | A `consumer` span, `<topic> process` (`messaging.operation.type` `process`, `messaging.destination.name`, `messaging.consumer.group.name`, `messaging.message.id`), a child of the publish |

The trace's position is written over a `traceparent` or `tracestate` the caller
put in `headers`. Without a tracer the headers carry a child of the current
trace context, and the handler runs in a child of the published one.

## The Message on the Wire

`TomBusMessage` is the message as it travels: `id`, `topic`, `key` (or `null`),
`payload` (JSON), `headers` (unmodifiable) and `publishedAt`. `toJson` gives the
form an adapter may put on the wire — `publishedAt` as UTC ISO 8601, `key`
left out when there is none — and `TomBusMessage.fromJson` reads it back.
`withHeaders(headers, {topic})` is the same message with headers added and,
when given, another topic: the shape of a dead letter.

## The In-Memory Bus

`TomMemoryMessageBus` keeps the whole contract, and ordering per key, inside
one process:

```dart
final bus = TomMemoryMessageBus(
  redeliveryDelay: const Duration(seconds: 1), // default Duration.zero
);
```

- **Each consumer handles one delivery at a time**, so the consumers of a group
  share its messages: a message goes to a free consumer of its group, taken in
  turn.
- **A message waits in memory** until a consumer of its group takes it, and is
  gone when the process ends. That makes it a single-process bus: a deployment
  of several processes, or one that must not lose a message on a restart, uses
  an adapter over a broker.
- **A rejected message waits `redeliveryDelay`** and then goes back to the
  front of its group's queue, before the messages of its key behind it.
- **A handler that throws** is logged as a warning (`tomLog.warn`) naming the
  message, the group and the attempt, and its delivery is rejected with the
  error as its reason.
- **A dead letter without a reason** — `reject(requeue: false)` with none — is
  headed `tom-dead-letter-reason: rejected`.
- **`settled()`** completes when nothing is being handled and no message waits
  for a free consumer of its group — every delivery made so far has run its
  course. A message waiting out a redelivery delay, or waiting for a group with
  no consumer, does not hold it up. It is what a test awaits after publishing.
- **`close()`** cancels the pending redeliveries, drops every consumer and
  waits for the deliveries under way.
- **Message ids** it generates are `msg-` and 32 hexadecimal digits from a
  secure random source.

## Ordering per Key

A bus that declares `TomBusCapabilities(orderedPerKey: true)` delivers the
messages of one key to a group one at a time, in the order they were
published: the next only once the previous is settled, and a redelivery before
the messages behind it (MB-C18). Messages without a key, and messages of other
keys, are not held up.

```dart
await bus.publish('accounts', debit, key: account.id);
await bus.publish('accounts', credit, key: account.id); // handled after debit
```

The in-memory bus declares it. Whether an adapter can depends on its broker —
a partitioned log orders a partition, a queue with competing consumers
generally does not — so a consumer that relies on ordering checks
`bus.capabilities.orderedPerKey` rather than assuming it.

The NATS adapter, `TomNatsMessageBus`, does not declare it: a NAK redelivers
one message while the next is already with another consumer of the group.

## Writing an Adapter

An adapter over Kafka, RabbitMQ, NATS or a cloud broker implements
`TomMessageBus`. [`tom_core_message_bus_nats`](../../../core_extension/tom_core_message_bus_nats/doc/nats_message_bus.md)
is a complete one, over NATS JetStream. Four rules keep every bus the same
above it:

1. **The trace.** `publish` runs its broker call inside
   `TomBusTrace.publishing` and sends the headers it is handed; the consumer
   loop runs each handler inside `TomBusTrace.delivering`.
2. **The arguments.** `subscribe` calls `tomCheckSubscription(topic, group,
   maxDeliveries)` before anything else, and `publish` and `subscribe` throw
   `message_bus.closed` once `close` has been called.
3. **The payload.** `publish` encodes with the given codec or
   `TomBusCodec<T>.reflected()`; the consumer decodes, dead-lettering a payload
   that does not decode with the reason `undecodable`.
4. **The suite.** The adapter's tests run `tomMessageBusConformance` against
   the broker.

The rest maps onto the broker. A consumer group is the broker's group, queue or
durable subscription, created by the first `subscribe`. Acknowledging is the
broker's ack or offset commit after the handler returns; requeueing its nack or
redelivery, counted against `maxDeliveries` with `TomBusDelivery.attempt`
taken from the broker's delivery count where it has one. Dead-lettering is a
publish of `message.withHeaders({...}, topic: tomDeadLetterTopic(topic))`
followed by the ack of the original. `TomBusMessage.toJson` is a wire form an
adapter may use when the broker carries one body and no headers of its own.

```dart
class MyBrokerBus implements TomMessageBus {
  @override
  TomBusCapabilities get capabilities => const TomBusCapabilities();

  @override
  Future<String> publish<T>(
    String topic,
    T payload, {
    String? key,
    Map<String, String> headers = const {},
    String? id,
    TomBusCodec<T>? codec,
  }) {
    final json = (codec ?? TomBusCodec<T>.reflected()).encode(payload);
    final messageId = id ?? newMessageId();
    return TomBusTrace.publishing(topic, headers, (sent) async {
      await client.send(topic, messageId, key, json, sent);
      return messageId;
    });
  }

  @override
  Future<TomBusSubscription> subscribe<T>(
    String topic, {
    required String group,
    required TomBusHandler<T> handler,
    TomBusCodec<T>? codec,
    int maxDeliveries = 5,
  }) async {
    tomCheckSubscription(topic, group, maxDeliveries);
    // The broker's consumer loop: decode each message, run the handler inside
    // TomBusTrace.delivering(message, group, ...), then ack, nack or
    // dead-letter by the delivery's outcome.
    return client.consume(topic, group, maxDeliveries, handler, codec);
  }

  @override
  Future<void> close() => client.close();
}
```

## The Conformance Suite

`tomMessageBusConformance({required create, timeout, quiet})` defines the tests
in the group it is called in. Each test makes a bus with `create`, uses topics
and groups named with a random suffix, so a persistent broker is not polluted
by an earlier run, and closes the bus. `timeout` (10 seconds) bounds the wait
for a delivery that must happen; `quiet` (300 milliseconds) is how long a test
waits to see that a delivery that must not happen does not. Raise both for a
broker with slow round trips.

```dart
void main() {
  group('MyBrokerBus', () {
    tomMessageBusConformance(
      create: () async => MyBrokerBus(await connect()),
      timeout: const Duration(seconds: 30),
      quiet: const Duration(seconds: 2),
    );
  });
}
```

| Test | Checks |
| ---- | ------ |
| MB-C1 | A subscribed group receives the message as published: id, topic, key, headers, payload, attempt 1 |
| MB-C2 | Every group receives every message |
| MB-C3 | The consumers of a group share its messages |
| MB-C4 | A group keeps the messages published while no consumer of it is subscribed |
| MB-C5 | A message published before any group subscribed reaches no one |
| MB-C6 | A cancelled consumer receives nothing more |
| MB-C7 | An acknowledged message is not delivered again |
| MB-C8 | A failed delivery is repeated, with the same id and the next attempt |
| MB-C9 | Reject without requeue dead-letters the message, with the dead-letter headers |
| MB-C10 | A message failing `maxDeliveries` times is dead-lettered with `max-deliveries` |
| MB-C11 | A payload that does not decode is dead-lettered with `undecodable`, the handler never called |
| MB-C12 | A delivery is settled once: a second settlement throws `message_bus.delivery.already_settled` |
| MB-C13 | A typed payload crosses through its codec (`TomConformanceOrder.codec`) |
| MB-C14 | The handler runs in the trace the message was published in, in a span of its own, under the trace id as request id |
| MB-C15 | A message published in no trace is handled in a trace of its own |
| MB-C16 | An empty topic or group, or `maxDeliveries` below 1, is refused with `message_bus.subscribe.invalid` |
| MB-C17 | A closed bus refuses to publish and to subscribe with `message_bus.closed` |
| MB-C18 | One key is handled one at a time, in publish order, a redelivery before the messages behind it — skipped for a bus that does not declare `orderedPerKey` |

## Error Keys

Every refusal is a `TomBusException`, a `TomException` with its key and
parameters.

| Key | Raised when | Parameters |
| --- | ----------- | ---------- |
| `message_bus.closed` | `publish` or `subscribe` on a closed bus | — |
| `message_bus.subscribe.invalid` | `subscribe` with an empty topic or group, or `maxDeliveries` below 1 (`tomCheckSubscription`) | `topic`, `group`, `maxDeliveries` |
| `message_bus.delivery.already_settled` | `ack` or `reject` on a delivery already settled | `message`, `outcome` |
| `message_bus.payload.not_json` | A payload that does not encode to JSON, at `publish` | `type` |
| `message_bus.payload.undecodable` | JSON that does not decode to the subscription's type; the bus dead-letters the message with `undecodable` | `type` (and `json` for a value the reflection codec cannot read) |

The server's bus relay adds `messaging.bus_relay.closed`, for a publish on a
closed relay (see the server's
[messaging guide](../../tom_core_server/doc/messaging.md#the-bus-relay)).

## Not Yet Implemented

- **No adapter over Kafka, RabbitMQ or a cloud broker.** The package holds
  the contract, the in-memory bus and the conformance suite; the one broker
  adapter is NATS JetStream's,
  [`tom_core_message_bus_nats`](../../../core_extension/tom_core_message_bus_nats/doc/nats_message_bus.md)
  in `tom_core_extensions`. An adapter over another broker is written against
  the contract, as [Writing an Adapter](#writing-an-adapter) describes.
  <!-- unpinned: absence — no adapter over Kafka, RabbitMQ or a cloud broker -->
- **No message priority.** Messages of a group are delivered in the order they
  wait, and nothing lets a message overtake another.
  <!-- unpinned: absence — TomMessageBus.publish takes no priority -->
- **No delayed delivery.** A message is deliverable when it is published;
  `publish` takes no time to deliver at. The redelivery delay of the in-memory
  bus applies to a rejected message only.
  <!-- unpinned: absence — TomMessageBus.publish takes no delivery time -->
- **No batch publish.** One `publish` is one message.
  <!-- unpinned: absence — TomMessageBus has no batch publish -->

## Verification

`test/memory_bus_test.dart` runs the conformance suite against
`TomMemoryMessageBus`, and the eight tests of what only the in-memory bus
promises: MB-M1 it declares ordering per key; MB-M2 `settled` waits for every
delivery and its redeliveries; MB-M3 a redelivery waits for the redelivery
delay; MB-M4 `close` lets a delivery under way finish; MB-M5 a payload that is
not JSON is refused at publish; MB-M6 with a tracer, publish is a producer span
and handling a consumer span continuing it; MB-M7 a message keeps its JSON
form, not the published object; MB-M8 the message survives its JSON form.

`test/codec_test.dart` covers the reflection codec, with a payload class whose
reflection `build.yaml` generates: MB-R1 a reflectable payload is published as
JSON and decoded back; MB-R2 JSON values pass through unchanged; MB-R3 JSON
that is not the type is undecodable.

None of the suites needs a broker or a database.

```bash
dart test
dart run example/message_bus_example.dart
```

`example/message_bus_example.dart` runs three checked steps on the in-memory
bus: an `OrderPlaced` event, crossing through reflection, received by the
`billing` and `shipping` groups; a consumer that always fails, retried three
times and then dead-lettered to `invoices.dlq` with `max-deliveries`; and a
message published in a trace, handled in that trace. Every step checks its own
result, and the run fails when one does not hold.

## Core Components

- **`TomMessageBus` / `TomBusCapabilities` / `TomBusSubscription`** — the
  contract (`bus.dart`).
- **`TomBusHeaders` / `tomDeadLetterTopic` / `tomCheckSubscription`** — the
  names and the argument check every bus shares (`bus.dart`).
- **`TomBusMessage` / `TomBusDelivery` / `TomBusOutcome` / `TomBusHandler` /
  `TomBusException`** — what travels, one delivery of it, and the refusals
  (`message.dart`).
- **`TomBusCodec`** — typed payloads, by reflection or by hand (`codec.dart`).
- **`TomBusTrace`** — the trace across the bus (`trace.dart`).
- **`TomMemoryMessageBus`** — the in-memory bus (`memory_bus.dart`).
- **`tomMessageBusConformance` / `TomConformanceOrder`** — the conformance
  suite (`conformance.dart`).

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `bus.dart`, `message.dart`, `trace.dart`, `memory_bus.dart`, `conformance.dart` | `Future`, `FutureOr`, `Timer` |
| `dart:convert` | dart | `codec.dart` | `jsonEncode` / `jsonDecode`, the JSON round trip of a payload |
| `dart:math` | dart | `memory_bus.dart`, `conformance.dart` | `Random` — message ids, and the suite's unique names |
| `tom_core_kernel` | package | `message.dart`, `codec.dart`, `trace.dart`, `memory_bus.dart`, `conformance.dart` | `TomException`, `tomReflector` / `tomReflectionInfo` / `ClassMirror`, `TomTraceContext`, `TomRequestId`, `TomTracing` / `TomSpanKind`, `tomLog` |
| `test` | package | `conformance.dart` | `group`, `test`, `setUp`, `tearDown`, `expect`, `markTestSkipped` |
