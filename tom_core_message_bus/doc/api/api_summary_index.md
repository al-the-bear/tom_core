# Tom Core Message Bus API Reference: Index

API summaries for `tom_core_message_bus` — the broker-neutral message bus of
Tom Core. The barrel (`lib/tom_core_message_bus.dart`) exports one module,
documented here; the conformance suite is a second library,
`lib/conformance.dart`, documented in the same summary.

Each summary follows the standard format (Overview with source paths, class
hierarchy, per-class constructors / static & instance members, enums, and
top-level functions/constants). Only public members are listed; `_`-prefixed
declarations are omitted.

## Quick Navigation

| Module | Summary | What it provides |
| ------ | ------- | ---------------- |
| Message Bus | [api_summary_message_bus.md](api_summary_message_bus.md) | The `TomMessageBus` contract, messages and deliveries, dead letters, typed payloads through a codec, the trace across the bus, the in-memory bus, and the conformance suite. |

## Modules

### Message Bus (`lib/src/`, `lib/conformance.dart`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomMessageBus` | abstract class | The contract every bus keeps: publish, subscribe with a consumer group, close. |
| `TomBusCapabilities` | class | What a bus does beyond the contract: ordering per key. |
| `TomBusSubscription` | abstract class | One consumer's place on a topic. |
| `TomBusHeaders` | abstract final class | The dead-letter and trace header names. |
| `TomBusException` | class | Every refusal of the bus (extends `TomException`). |
| `TomBusMessage` | class | A message as it travels, with its JSON wire form. |
| `TomBusDelivery<T>` | class | One delivery to a consumer, its payload decoded; settled once. |
| `TomBusOutcome` | enum | `acknowledged`, `requeued`, `deadLettered`. |
| `TomBusHandler<T>` | typedef | Handles the deliveries of a subscription. |
| `TomBusCodec<T>` | class | A typed payload to JSON and back; reflection by default. |
| `TomBusTrace` | abstract final class | The trace across the bus: `publishing`, `delivering`. |
| `TomMemoryMessageBus` | class | The contract in one process, with ordering per key. |
| `TomConformanceOrder` | class | The conformance suite's typed payload, with its codec. |
| `tomDeadLetterTopic` | function | `<topic>.dlq`. |
| `tomCheckSubscription` | function | The subscription arguments every bus refuses. |
| `tomMessageBusConformance` | function | The conformance suite, MB-C1 to MB-C18. |

## Alphabetical Type Index

| Type | Module |
| ---- | ------ |
| `TomBusCapabilities` | Message Bus |
| `TomBusCodec` | Message Bus |
| `TomBusDelivery` | Message Bus |
| `TomBusException` | Message Bus |
| `TomBusHandler` | Message Bus |
| `TomBusHeaders` | Message Bus |
| `TomBusMessage` | Message Bus |
| `TomBusOutcome` | Message Bus |
| `TomBusSubscription` | Message Bus |
| `TomBusTrace` | Message Bus |
| `tomCheckSubscription` | Message Bus |
| `TomConformanceOrder` | Message Bus |
| `tomDeadLetterTopic` | Message Bus |
| `TomMemoryMessageBus` | Message Bus |
| `TomMessageBus` | Message Bus |
| `tomMessageBusConformance` | Message Bus |
