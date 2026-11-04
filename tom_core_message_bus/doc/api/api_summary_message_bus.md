# Tom Core Message Bus API Reference: Message Bus

The broker-neutral message bus: the `TomMessageBus` contract, the message and
its delivery to a consumer, typed payloads through a codec, the trace across
the bus, the in-memory bus, and the conformance suite every bus passes. The
guide is [message_bus.md](../message_bus.md).

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomMessageBus](#tommessagebus)
  - [TomBusCapabilities](#tombuscapabilities)
  - [TomBusSubscription](#tombussubscription)
  - [TomBusHeaders](#tombusheaders)
  - [TomBusException](#tombusexception)
  - [TomBusMessage](#tombusmessage)
  - [TomBusDelivery](#tombusdelivery)
  - [TomBusCodec](#tombuscodec)
  - [TomBusTrace](#tombustrace)
  - [TomMemoryMessageBus](#tommemorymessagebus)
  - [TomConformanceOrder](#tomconformanceorder)
- [Enums](#enums)
  - [TomBusOutcome](#tombusoutcome)
- [Typedefs](#typedefs)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/bus.dart`, `lib/src/message.dart`, `lib/src/codec.dart`,
`lib/src/trace.dart`, `lib/src/memory_bus.dart`, exported by
`lib/tom_core_message_bus.dart`; `lib/conformance.dart`, a library of its own.

`TomMessageBus` is the contract: `publish` a payload to a topic, `subscribe` a
handler to a topic as a consumer of a group, `close`, and the
`TomBusCapabilities` a bus declares beyond the contract — ordering per key.
A subscription is a `TomBusSubscription`. A message travels as a
`TomBusMessage` with a JSON payload; each delivery of it to a consumer is a
`TomBusDelivery<T>` carrying the decoded payload, which the handler
(`TomBusHandler<T>`) settles once as a `TomBusOutcome`. A message rejected
without requeue, out of attempts, or undecodable is published to
`tomDeadLetterTopic(topic)` with the `TomBusHeaders` dead-letter headers.

`TomBusCodec<T>` turns a typed payload into JSON and back —
`TomBusCodec.reflected()` through the kernel's reflection unless a codec is
given. `TomBusTrace` carries the trace context across the bus: every bus
publishes through `publishing` and handles through `delivering`.
`tomCheckSubscription` is the argument check every bus makes, and
`TomBusException` every refusal.

`TomMemoryMessageBus` keeps the contract in one process. The conformance suite,
`tomMessageBusConformance`, is in `conformance.dart` with the payload type its
typed tests use, `TomConformanceOrder`.

## Class Hierarchy

```text
TomException  (tom_core_kernel)
    └── TomBusException

TomMessageBus  (abstract)
    └── TomMemoryMessageBus  (implements)

TomBusSubscription  (abstract)

TomBusCapabilities
TomBusHeaders  (abstract final)
TomBusMessage
TomBusDelivery<T>
TomBusCodec<T>
TomBusTrace  (abstract final)
TomConformanceOrder  (conformance.dart)
TomBusOutcome  (enum)
```

## Classes

### TomMessageBus

A message bus: the contract every bus keeps — publish and subscribe, consumer
groups, durable groups, at least once, acknowledge and reject, dead letters,
headers and trace, typed payloads — with ordering per key as a declared
capability.

- **Extends:** none (abstract)

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `capabilities` | `TomBusCapabilities` | *(getter)* What this bus does beyond the contract. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `publish` | `Future<String> publish<T>(String topic, T payload, {String? key, Map<String, String> headers = const {}, String? id, TomBusCodec<T>? codec})` | Publishes `payload` to `topic`, encoded by `codec` (the reflection codec unless given), and answers the message id — `id` when given, a new one otherwise. `key` orders the message among those of the same key where `capabilities` say so. Published in a trace, the message carries the trace in its headers. Throws `message_bus.closed` once the bus is closed. |
| `subscribe` | `Future<TomBusSubscription> subscribe<T>(String topic, {required String group, required TomBusHandler<T> handler, TomBusCodec<T>? codec, int maxDeliveries = 5})` | Subscribes `handler` to `topic` as a consumer of `group`, decoding each payload with `codec` (the reflection codec unless given). A message is dead-lettered on its `maxDeliveries`th failed delivery. Throws `message_bus.subscribe.invalid` for an empty topic or group or a `maxDeliveries` below 1, and `message_bus.closed` once the bus is closed. |
| `close` | `Future<void> close()` | Stops every subscription, lets the deliveries under way finish, and refuses further publishing and subscribing. Idempotent. |

### TomBusCapabilities

What a bus can do beyond the contract every bus keeps.

- **Extends:** none

#### Constructors

```dart
const TomBusCapabilities({bool orderedPerKey = false})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `orderedPerKey` | `bool` | Whether messages of one key are delivered to a group one at a time, in the order they were published — the next only once the previous is settled, a redelivery before the messages behind it (final). |

### TomBusSubscription

A consumer's place on a topic: deliveries reach it until it is cancelled.

- **Extends:** none (abstract)

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `topic` | `String` | *(getter)* The topic. |
| `group` | `String` | *(getter)* The consumer group. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `cancel` | `Future<void> cancel()` | Stops this consumer's deliveries. A delivery it is handling completes; the group's other consumers, and the group itself, are untouched. |

### TomBusHeaders

The headers a dead-lettered message carries besides its own, and the trace
headers.

- **Extends:** none (abstract final)

#### Static Constants

| Constant | Type | Value | Description |
| -------- | ---- | ----- | ----------- |
| `deadLetterTopic` | `String` | `'tom-dead-letter-topic'` | The topic the message was published to. |
| `deadLetterGroup` | `String` | `'tom-dead-letter-group'` | The group that gave it up. |
| `deadLetterReason` | `String` | `'tom-dead-letter-reason'` | Why: the consumer's reason, `max-deliveries`, or `undecodable`. |
| `deadLetterAttempts` | `String` | `'tom-dead-letter-attempts'` | How many deliveries it had. |
| `traceparent` | `String` | `'traceparent'` | The W3C `traceparent` of the trace the message was published in. |
| `tracestate` | `String` | `'tracestate'` | The W3C `tracestate` that goes with it. |

### TomBusException

A bus operation that cannot be carried out. Its keys are listed in the guide's
[Error Keys](../message_bus.md#error-keys).

- **Extends:** `TomException` (tom_core_kernel)

#### Constructors

```dart
TomBusException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? rootException,
  StackTrace? stack,
})
```

### TomBusMessage

A message as it travels: its id, its topic, its ordering key, a JSON payload and
its headers. The id is the message's identity across every delivery of it.

- **Extends:** none

#### Constructors

```dart
TomBusMessage({
  required String id,
  required String topic,
  required Object? payload,
  required DateTime publishedAt,
  String? key,
  Map<String, String> headers = const {},
})
```

`headers` are kept as an unmodifiable copy.

#### Factory Constructors

```dart
factory TomBusMessage.fromJson(Map<String, Object?> json)
```

The message `toJson` wrote.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | The message's identity, the same on every delivery (final). |
| `topic` | `String` | The topic it was published to (final). |
| `key` | `String?` | The ordering key, or `null` for none (final). |
| `payload` | `Object?` | The payload, as JSON (final). |
| `headers` | `Map<String, String>` | The headers — `traceparent` and `tracestate` among them when the message was published in a trace (final). |
| `publishedAt` | `DateTime` | When it was published (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `withHeaders` | `TomBusMessage withHeaders(Map<String, String> headers, {String? topic})` | The message with `headers` added to its own and, when given, another `topic`. |
| `toJson` | `Map<String, Object?> toJson()` | The message as JSON, the form an adapter may put on the wire: `id`, `topic`, `key` (left out when `null`), `payload`, `headers`, `publishedAt` as UTC ISO 8601. |
| `toString` | `String toString()` | *(override)* `TomBusMessage(<topic>, <id>)`. |

### TomBusDelivery

One delivery of a message to a consumer of a group, its payload decoded. The
consumer settles it once: `ack`, or `reject`. A handler that returns without
settling acknowledges; one that throws rejects, to be redelivered. A delivery
whose attempts reach the subscription's `maxDeliveries` is dead-lettered
instead of redelivered.

- **Extends:** none

#### Constructors

```dart
TomBusDelivery({
  required TomBusMessage message,
  required T payload,
  required int attempt,
  required String group,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `message` | `TomBusMessage` | The message delivered (final). |
| `payload` | `T` | Its payload, decoded (final). |
| `attempt` | `int` | Which attempt this is, from 1 (final). |
| `group` | `String` | The consumer group it is delivered to (final). |
| `outcome` | `TomBusOutcome?` | *(getter)* The consumer's decision, or `null` while unsettled. |
| `reason` | `String?` | *(getter)* Why it was rejected, when the consumer said. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ack` | `void ack()` | Acknowledges: the message is handled. Throws `message_bus.delivery.already_settled` on a settled delivery. |
| `reject` | `void reject({bool requeue = true, String? reason})` | Rejects: with `requeue` the message is delivered again (dead-lettered once its attempts are spent), without it dead-lettered now; `reason` is recorded on a dead-lettered message. Throws `message_bus.delivery.already_settled` on a settled delivery. |

### TomBusCodec

Encodes payloads of type `T` to JSON and decodes them back.
`TomBusCodec.reflected()` — the default of every publish and subscription —
takes a JSON value as it is and any other object through the kernel's
reflection, so a `@tomReflector` class with plain fields crosses the bus with
no codec written for it.

- **Extends:** none

#### Constructors

```dart
const TomBusCodec(
  Object? Function(T payload) encode,
  T Function(Object? json) decode,
)

const TomBusCodec.reflected()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `encode` | `Object? encode(T payload)` | `payload` as JSON, passed through the JSON text form so the result is exactly what a broker would carry. Throws `message_bus.payload.not_json` for a value neither JSON nor reflectable. |
| `decode` | `T decode(Object? json)` | The payload `json` encodes: by the codec's own function, or — reflected — `json` itself when it is a `T`, a reflected instance of `T` from a map. Throws `message_bus.payload.undecodable` for JSON that is not a `T`. |

### TomBusTrace

The trace handling of the bus: the headers a publish adds, and the trace a
delivery runs in. Every bus goes through these two, so a trace crosses any
broker the same way.

- **Extends:** none (abstract final)

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `publishing` | `static Future<R> publishing<R>(String topic, Map<String, String> headers, Future<R> Function(Map<String, String> headers) publish)` | Runs `publish` with the headers to send: `headers` and, when the current zone is in a trace, its position. With a tracer installed the publish is a `producer` span, `<topic> publish` (`messaging.operation.type` `send`, `messaging.destination.name`), and the position sent is the span's. |
| `delivering` | `static Future<R> delivering<R>(TomBusMessage message, String group, Future<R> Function() handle)` | Runs `handle` — the handling of `message` by `group` — in the trace the message was published in: a new span of it, whose trace id is the request id (`TomRequestId`), or a trace of its own for a message published in none. With a tracer installed the handling is a `consumer` span, `<topic> process` (`messaging.operation.type` `process`, `messaging.destination.name`, `messaging.consumer.group.name`, `messaging.message.id`). |

### TomMemoryMessageBus

A `TomMessageBus` in the memory of this process, for tests and a
single-process deployment. It keeps the whole contract, and ordering per key.
Each consumer handles one delivery at a time, so the consumers of a group share
its messages. A message waits in memory until a consumer of its group takes
it, and is gone when the process ends.

- **Implements:** `TomMessageBus`

#### Constructors

```dart
TomMemoryMessageBus({
  Duration redeliveryDelay = Duration.zero,
  DateTime Function()? clock,
})
```

`clock`, the `publishedAt` of each message, defaults to `DateTime.now`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `redeliveryDelay` | `Duration` | How long a rejected message waits before its next delivery (final). |
| `capabilities` | `TomBusCapabilities` | *(getter)* *(override)* `orderedPerKey: true`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `publish` | `Future<String> publish<T>(String topic, T payload, {String? key, Map<String, String> headers = const {}, String? id, TomBusCodec<T>? codec})` | *(override)* Encodes the payload, routes the message to every group of the topic and answers its id — `id`, or `msg-` and 32 hexadecimal digits. |
| `subscribe` | `Future<TomBusSubscription> subscribe<T>(String topic, {required String group, required TomBusHandler<T> handler, TomBusCodec<T>? codec, int maxDeliveries = 5})` | *(override)* Adds a consumer to the group, creating the group on its first subscription. A handler that throws is logged as a warning and its delivery rejected with the error as reason; a rejection without requeue and without a reason is dead-lettered as `rejected`. |
| `settled` | `Future<void> settled()` | Completes when nothing is being handled and no message waits for a free consumer of its group. A message waiting for a redelivery delay, or for a group with no consumer, does not hold it up. |
| `close` | `Future<void> close()` | *(override)* Cancels pending redeliveries, drops every consumer and waits for the deliveries under way. Idempotent. |

### TomConformanceOrder

A payload type with a codec of its own, for the conformance suite's
typed-payload tests. In `conformance.dart`.

- **Extends:** none

#### Constructors

```dart
const TomConformanceOrder(String item, int quantity)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `codec` | `static final TomBusCodec<TomConformanceOrder>` | Its codec: `{'item': ..., 'quantity': ...}`. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `item` | `String` | The item (final). |
| `quantity` | `int` | How many (final). |

## Enums

### TomBusOutcome

What a consumer decided about a delivery.

| Value | Description |
| ----- | ----------- |
| `acknowledged` | Handled: the message is not delivered to this group again. |
| `requeued` | To be delivered again, as a new attempt. |
| `deadLettered` | Moved to the topic's dead-letter topic. |

## Typedefs

| Typedef | Definition | Description |
| ------- | ---------- | ----------- |
| `TomBusHandler<T>` | `FutureOr<void> Function(TomBusDelivery<T> delivery)` | Handles the deliveries of a subscription. |

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `tomDeadLetterTopic` | `String tomDeadLetterTopic(String topic)` | The topic a message of `topic` is dead-lettered to: `<topic>.dlq`. |
| `tomCheckSubscription` | `void tomCheckSubscription(String topic, String group, int maxDeliveries)` | Throws `message_bus.subscribe.invalid` (parameters `topic`, `group`, `maxDeliveries`) for an empty topic or group, or a `maxDeliveries` below 1. |
| `tomMessageBusConformance` | `void tomMessageBusConformance({required Future<TomMessageBus> Function() create, Duration timeout = const Duration(seconds: 10), Duration quiet = const Duration(milliseconds: 300)})` | Defines the conformance tests MB-C1 to MB-C18 against the bus `create` makes, one bus per test, closed after it. `timeout` bounds the wait for an expected delivery; `quiet` is how long a test waits to see that a delivery that must not happen does not. The ordering test is skipped for a bus that does not declare `orderedPerKey`. In `conformance.dart`. |
