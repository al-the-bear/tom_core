# Changelog

## 0.1.1

### Added

- **The tenant crosses the bus.** A message published in a tenant's context
  carries the tenant in `TomBusHeaders.tenant` (`tom-tenant`) unless the
  caller's headers name one (`TomBusTrace.publishing`), and its handler runs in
  that tenant (`TomBusTrace.delivering`, `TomBusTrace.tenantOf`). `tomDispatch`
  dead-letters a message whose tenant header is not a tenant id, reason
  `invalid-tenant`.

## 0.1.0

### Added

- **The broker-neutral contract.** `TomMessageBus`: `publish<T>(topic,
  payload, {key, headers, id, codec})` answering the message id,
  `subscribe<T>(topic, {group, handler, codec, maxDeliveries = 5, ephemeral =
  false})` answering a
  `TomBusSubscription` (`topic`, `group`, `cancel`), `close`, and
  `capabilities` (`TomBusCapabilities.orderedPerKey`). The contract:
  publish and subscribe, consumer groups whose consumers compete, durable
  groups (a group exists from its first subscription; a message to a topic no
  group subscribed to reaches no one), ephemeral groups (a group subscribed
  `ephemeral` lives only while one of its consumers is subscribed in this bus;
  a group's first subscription decides), at-least-once delivery under one message
  id, acknowledge and reject, dead letters, headers and trace, typed payloads;
  ordering per key is a capability a bus declares.
- **Messages and deliveries.** `TomBusMessage` (id, topic, key, JSON payload,
  headers, `publishedAt`; `toJson` / `fromJson`, `withHeaders`);
  `TomBusDelivery<T>` with `ack`, `reject({requeue, reason})`, `attempt`,
  `group`, `outcome` and `reason`, settled once; `TomBusOutcome`;
  `TomBusHandler<T>`.
- **Dead letters.** `tomDeadLetterTopic` (`<topic>.dlq`) and `TomBusHeaders`:
  `tom-dead-letter-topic`, `tom-dead-letter-group`, `tom-dead-letter-reason`
  (the consumer's reason, `max-deliveries` or `undecodable`) and
  `tom-dead-letter-attempts`, plus `traceparent` / `tracestate`.
- **Typed payloads.** `TomBusCodec<T>`: a codec of an encode and a decode
  function, and `TomBusCodec.reflected()`, the default, which takes a JSON
  value as it is and any other object through the kernel's reflection.
- **The trace across the bus.** `TomBusTrace.publishing` adds the trace to a
  publish's headers (a producer span, `<topic> publish`, with a tracer
  installed) and `TomBusTrace.delivering` runs a handler in the trace the
  message was published in, under a request id equal to the trace id (a
  consumer span, `<topic> process`).
- **The in-memory bus.** `TomMemoryMessageBus({redeliveryDelay, clock})`:
  the contract in one process, with ordering per key, one delivery at a time
  per consumer, ephemeral groups dropped with their waiting messages when the
  last consumer cancels, and `settled()` for a test to wait on.
- **The delivery step every bus shares.** `tomDispatch<T>(message, {attempt,
  group, codec, handler})` decodes a delivery, runs the handler in
  `TomBusTrace.delivering` and answers `(TomBusOutcome, String?)`: an
  undecodable payload dead-lettered as `undecodable` without the handler, a
  handler that throws without settling rejected for redelivery with the error
  as reason, one that returns without settling acknowledged.
  `tomDeadLetter(message, {group, reason, attempts})` is the message on
  `tomDeadLetterTopic` with the four dead-letter headers. The in-memory bus and
  every adapter use both.
- **The conformance suite.** `package:tom_core_message_bus/conformance.dart`:
  `tomMessageBusConformance({create, timeout, quiet})`, tests MB-C1 to
  MB-C20, with `TomConformanceOrder` and its codec for the typed-payload test.
- **Errors.** `TomBusException` and `tomCheckSubscription`; the keys
  `message_bus.closed`, `message_bus.subscribe.invalid`,
  `message_bus.delivery.already_settled`, `message_bus.payload.not_json` and
  `message_bus.payload.undecodable`.
- **Tests.** The dispatch tests MB-D1 to MB-D5 (`test/dispatch_test.dart`),
  beside the in-memory bus's, the refusals and the reflection codec.
- **Example.** `example/message_bus_example.dart`, three checked steps.
