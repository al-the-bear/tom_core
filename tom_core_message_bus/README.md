# tom_core_message_bus

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and published on pub.dev.

> **⚠️ Work in progress — unstable API.** The Tom Core packages are under active
> development and not yet stable. Their version numbers carry no promise about
> API maturity: they are publishing counters, not semver. The patch number is
> bumped on every change — **including breaking changes** — so a patch bump may
> break you. Expect the public surface to shift without notice. Not recommended
> for production use yet.

A broker-neutral message bus for Tom services: publish and subscribe with
consumer groups, acknowledgement and rejection, dead-letter topics, typed
payloads through reflection and the trace context carried in the headers.

## Overview

A service that hands work to another through a broker — Kafka, RabbitMQ, NATS,
a cloud queue — writes against `TomMessageBus`, the contract every bus keeps,
and not against the broker's client. The package holds that contract, the
in-memory bus that keeps it inside one process, and the conformance suite that
checks any bus against it. A broker adapter implements the contract and runs
the suite in its own tests; no broker adapter ships in this package. The
adapters live in `tom_core_extensions`:
[`tom_core_message_bus_nats`](../../core_extension/tom_core_message_bus_nats/README.md)
over NATS JetStream,
[`tom_core_message_bus_rabbitmq`](../../core_extension/tom_core_message_bus_rabbitmq/README.md)
over RabbitMQ,
[`tom_core_message_bus_kafka`](../../core_extension/tom_core_message_bus_kafka/README.md)
over Kafka through a REST proxy,
[`tom_core_message_bus_aws`](../../core_extension/tom_core_message_bus_aws/README.md)
over Amazon SNS and SQS,
[`tom_core_message_bus_gcp`](../../core_extension/tom_core_message_bus_gcp/README.md)
over Google Cloud Pub/Sub, and
[`tom_core_message_bus_azure`](../../core_extension/tom_core_message_bus_azure/README.md)
over Azure Service Bus.

The contract is **at least once**: a message is delivered until a consumer of
its group acknowledges it or it is dead-lettered, and the message id is the
same on every delivery, so a consumer that must not act twice recognises a
repeat. **Ordering per key** is not part of the contract: it is a capability a
bus declares (`TomBusCapabilities.orderedPerKey`), and the in-memory bus does.

The bus builds on [`tom_core_kernel`](../tom_core_kernel/README.md) only: the
exception base, reflection for typed payloads, the W3C trace context, the
request id a delivery runs under and the span seam. The transactional outbox
that publishes to a bus after a database commit is the server's
`TomBusRelay` — see the
[messaging guide](../tom_core_server/doc/messaging.md#the-bus-relay).

## Installation

```yaml
dependencies:
  tom_core_message_bus: ^0.1.0
```

Then import the barrel:

```dart
import 'package:tom_core_message_bus/tom_core_message_bus.dart';
```

An adapter's tests also import the conformance suite:

```dart
import 'package:tom_core_message_bus/conformance.dart';
```

**SDK:** Dart `^3.10.0`. `conformance.dart` is a library an adapter imports
into its own tests, so what it uses of the test framework is a regular
dependency of the package: `test_api` (`group`, `test`, `setUp`, `tearDown`,
`markTestSkipped`) and `matcher` (`expect` and the matchers). It does not
depend on the `test` runner: a Flutter package's `flutter_test` pins
`test_api`, and the `test` release accepting the pinned one caps analyzer below
14, so a dependency on `test` would hold every Flutter application that reaches
this package — through `tom_core_server`, for one — below analyzer 14. An
adapter's own test still imports `package:test`, which runs the suite. A payload
class that crosses the bus through reflection needs `dart run build_runner
build` to generate its `*.reflection.dart`.

## Features

| Type | What it does |
| ---- | ------------ |
| `TomMessageBus` | The contract: `publish`, `subscribe` with a consumer group, `close`, and the `capabilities` a bus declares beyond it. |
| `TomBusCapabilities` | What a bus does beyond the contract: `orderedPerKey`. |
| `TomBusSubscription` | One consumer's place on a topic, with its `topic`, `group` and `cancel`. |
| `TomBusMessage` | A message as it travels: id, topic, ordering key, JSON payload, headers, publish time; `toJson` / `fromJson` for the wire, `withHeaders`. |
| `TomBusDelivery<T>` | One delivery to a consumer, its payload decoded: `ack`, `reject` (redeliver, or dead-letter with `requeue: false`), `attempt`, `outcome`, `reason`. |
| `TomBusOutcome` | `acknowledged`, `requeued`, `deadLettered`. |
| `TomBusHandler<T>` | The handler a subscription runs for each delivery. |
| `TomBusCodec<T>` | A typed payload to JSON and back; `TomBusCodec.reflected()`, the default, through the kernel's reflection. |
| `TomBusTrace` | The trace across the bus: `publishing` adds the trace to the headers, `delivering` runs a handler in it. |
| `TomBusHeaders` / `tomDeadLetterTopic` | The header names a bus writes, and the dead-letter topic of a topic (`<topic>.dlq`). |
| `tomCheckSubscription` | The subscription arguments every bus refuses. |
| `tomDispatch` / `tomDeadLetter` | The delivery step every bus shares — decode, run the handler in the published trace, read the outcome — and the dead letter it publishes. |
| `TomMemoryMessageBus` | The contract in the memory of one process, with ordering per key; for tests and a single-process deployment. |
| `TomBusException` | Every refusal of the bus, keyed `message_bus.*`. |
| `tomMessageBusConformance` | The conformance suite, MB-C1 to MB-C20, in `conformance.dart`. |

## Quick start

```dart
import 'package:tom_core_message_bus/tom_core_message_bus.dart';

Future<void> main() async {
  final bus = TomMemoryMessageBus();

  // Two groups on one topic: each receives every message.
  await bus.subscribe<String>(
    'orders',
    group: 'billing',
    handler: (delivery) => print('billing ${delivery.payload}'),
  );
  await bus.subscribe<String>(
    'orders',
    group: 'shipping',
    handler: (delivery) => print('shipping ${delivery.payload}'),
  );

  await bus.publish('orders', 'o-1');
  await bus.settled();
  await bus.close();
}
```

It prints `billing o-1` and `shipping o-1`. A handler that returns
acknowledges its delivery; one that throws has it delivered again, and after
`maxDeliveries` attempts (5 unless the subscription says otherwise) the message
is dead-lettered to `orders.dlq`.

## The contract

The points every bus keeps, each one checked by the conformance suite:

- **Publish and subscribe.** A message published to a topic is delivered to
  every consumer group subscribed to the topic.
- **Consumer groups.** Within a group, each message is handled by one of its
  consumers; the consumers of a group compete for the messages.
- **Durable groups.** A group exists from its first subscription. A message
  published while none of its consumers is subscribed waits for the next; a
  message published to a topic no group has subscribed to reaches no one.
- **Ephemeral groups.** A group subscribed with `ephemeral: true` lives only
  while one of its consumers is subscribed in this bus: when its last consumer
  cancels, the group and what waits for it are gone, and a later subscription
  starts a new group. Each running process subscribing with a group of its own,
  ephemeral, is a fan-out to every process.
- **At least once.** A delivery is repeated until it is acknowledged or
  dead-lettered, with the same message id on every delivery.
- **Acknowledge and reject.** Returning acknowledges; throwing or `reject()`
  redelivers; `reject(requeue: false)` dead-letters.
- **Dead letters.** A message rejected without requeue, one whose attempts
  reach `maxDeliveries`, and one whose payload does not decode go to
  `<topic>.dlq`, with headers naming the topic, the group, the reason and the
  attempts.
- **Headers and trace.** Headers arrive as published; a message published in a
  trace carries `traceparent` and `tracestate`, and its handler runs in that
  trace, under a request id equal to the trace id.
- **Typed payloads.** A publish encodes and a subscription decodes through a
  `TomBusCodec`, by default through reflection.
- **Ordering per key** is the one capability a bus may declare or not.

The [guide](doc/message_bus.md) goes through each point.

## Writing an adapter

An adapter over a broker implements `TomMessageBus` and keeps four rules, so
every bus behaves the same way above it:

1. Publish through `TomBusTrace.publishing`, and hand every delivery to
   `tomDispatch`, which decodes it and runs the handler through
   `TomBusTrace.delivering` — the trace crosses every broker the same way.
2. Check the arguments of `subscribe` with `tomCheckSubscription`.
3. Encode payloads with the `TomBusCodec` given, or `TomBusCodec.reflected()`;
   map the outcome `tomDispatch` answers onto the broker, publishing
   `tomDeadLetter(message, ...)` for a dead letter.
4. Run `tomMessageBusConformance` in the adapter's own tests, against the
   broker.

See [Writing an adapter](doc/message_bus.md#writing-an-adapter) in the guide.

## The conformance suite

```dart
import 'package:test/test.dart';
import 'package:tom_core_message_bus/conformance.dart';
import 'package:tom_core_message_bus/tom_core_message_bus.dart';

void main() {
  group('TomMemoryMessageBus', () {
    tomMessageBusConformance(create: () async => TomMemoryMessageBus());
  });
}
```

Each test makes a bus with `create`, uses topics and groups named with a random
suffix (so a persistent broker is not polluted by an earlier run) and closes the
bus. `timeout` bounds the wait for a delivery that must happen and `quiet` the
wait for one that must not; raise both for a broker with slow round trips. The
ordering test runs only for a bus that declares `orderedPerKey`. The twenty
tests are listed in the [guide](doc/message_bus.md#the-conformance-suite).

## Example

[`example/message_bus_example.dart`](example/message_bus_example.dart) runs
three checked steps on the in-memory bus: a reflected event received by two
groups, a failing consumer retried and then dead-lettered with
`max-deliveries`, and a trace carried from the publisher to the handler. Every
step checks its own result, and the run fails when one does not hold.

```bash
dart run example/message_bus_example.dart
```

## Documentation

- [`doc/message_bus.md`](doc/message_bus.md) — the guide: the contract point by
  point, consumer groups, acknowledgement and dead letters, codecs, headers and
  trace, the in-memory bus, ordering per key, writing an adapter, the
  conformance suite and the error keys.
- [`doc/api/api_summary_index.md`](doc/api/api_summary_index.md) — the API
  reference, with [`api_summary_message_bus.md`](doc/api/api_summary_message_bus.md).
- [`tom_core_server/doc/messaging.md`](../tom_core_server/doc/messaging.md#the-bus-relay)
  — the bus relay: messages queued in the caller's database transaction and
  published to a bus after the commit.
- [`tom_core_message_bus_nats`](../../core_extension/tom_core_message_bus_nats/README.md)
  — the adapter over NATS JetStream, in `tom_core_extensions`.
- [`tom_core_message_bus_rabbitmq`](../../core_extension/tom_core_message_bus_rabbitmq/README.md)
  — the adapter over RabbitMQ, in `tom_core_extensions`.
- [`tom_core_message_bus_kafka`](../../core_extension/tom_core_message_bus_kafka/README.md)
  — the adapter over Kafka through a REST proxy, in `tom_core_extensions`.
- [`tom_core_message_bus_aws`](../../core_extension/tom_core_message_bus_aws/README.md)
  — the adapter over Amazon SNS and SQS, in `tom_core_extensions`.
- [`tom_core_message_bus_gcp`](../../core_extension/tom_core_message_bus_gcp/README.md)
  — the adapter over Google Cloud Pub/Sub, in `tom_core_extensions`.

## Dependencies

| Dependency | Kind | For |
| ---------- | ---- | --- |
| `tom_core_kernel` | runtime | `TomException`, reflection for `TomBusCodec.reflected()`, `TomTraceContext`, `TomRequestId`, `TomTracing` and `tomLog` |
| `test_api` | runtime | `conformance.dart`, which adapters import into their tests: `group`, `test`, `setUp`, `tearDown`, `markTestSkipped` |
| `matcher` | runtime | `conformance.dart`: `expect`, `expectLater`, `fail` and the matchers |
| `test` | dev | this package's own suites |
| `lints`, `build_runner`, `build`, `tom_reflection_generator` | dev | analysis, and the reflection of the test and example payload classes |

## Status

- **Version:** 0.1.0
- **Tests:** run with `testkit :test` or `dart test`: the conformance suite and
  the in-memory bus's own tests (`test/memory_bus_test.dart`), the refusals
  (`test/refusals_test.dart`), the reflection codec (`test/codec_test.dart`)
  and the delivery step every bus shares (`test/dispatch_test.dart`). None
  needs a broker or a database.
- **License:** BSD-3-Clause — see [LICENSE](LICENSE).
