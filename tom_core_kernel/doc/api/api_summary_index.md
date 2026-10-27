# Tom Core Kernel API Reference: Index

Per-module API summaries for `tom_core_kernel` — the foundational layer of Tom
Core. The package barrel (`lib/tom_core_kernel.dart`) exports the nineteen
modules documented here and re-exports `tom_basics`, `tom_crypto`, and
`tom_reflection` (see those packages' docs for their APIs — notably the runtime
and platform-detection types, which live in `tom_basics`).

Each summary follows the standard format (Overview with source paths, class
hierarchy, per-class constructors / static & instance members, enums, and
top-level functions/constants). Only public members are listed; `_`-prefixed
declarations are omitted.

## Quick Navigation

| Module | Summary | What it provides |
| ------ | ------- | ---------------- |
| Bean Locator | [api_summary_beanlocator.md](api_summary_beanlocator.md) | Component annotation and typed bean lookup/dependency injection. |
| Context | [api_summary_context.md](api_summary_context.md) | Zone-scoped typed execution context and ambient providers, the zone-carried tenant, W3C trace context and request id, and the tracing seam that records spans. |
| HTTP Connection | [api_summary_http_connection.md](api_summary_http_connection.md) | Server call model, remote APIs/endpoints, headers, MIME types, auth-retry, client factories, and the timeout, retry, circuit-breaker and bulkhead policies of outgoing calls. |
| Isolate Pooling | [api_summary_isolate_pooling.md](api_summary_isolate_pooling.md) | Worker/executor/command model and isolate worker pool. |
| JSON | [api_summary_json.md](api_summary_json.md) | JSON serialization contract, map merge/traversal, env substitution, pretty printing. |
| Little Things | [api_summary_little_things.md](api_summary_little_things.md) | Kernel base exception, zone helpers, checked runners, stack-trace and offset formatting. |
| Logging | [api_summary_logging.md](api_summary_logging.md) | Cross-isolate and remote log transport, outputs, and log servers, and the structured JSON line output with its zone-read context fields. |
| Metrics | [api_summary_metrics.md](api_summary_metrics.md) | Counters, gauges, histograms and observed gauges in a per-isolate registry, and the Prometheus text rendering of its snapshot. |
| Observable | [api_summary_observable.md](api_summary_observable.md) | Observable base, observers, and the boxed `TomObject<T>` value/collection hierarchy. |
| Offline | [api_summary_offline.md](api_summary_offline.md) | Server entities cached on the device: the storage-engine contract, the device-side repository with its queue of pending changes, the sync protocol, the sync engine with conflict resolution, and the protocol's in-memory reference server. |
| Preferences | [api_summary_preferences.md](api_summary_preferences.md) | Well-known preference keys, wire DTOs, the value codec, and the `/preferences` API declaration; the notification-preference keys and the `/notification-preferences` API declaration. |
| Reflection | [api_summary_reflection.md](api_summary_reflection.md) | The kernel reflector, reflection info, and JSON (de)serialization via mirrors. |
| Resources | [api_summary_resources.md](api_summary_resources.md) | Text and config resource providers over a JSON tree. |
| Scheduling | [api_summary_scheduling.md](api_summary_scheduling.md) | Schedules, job definitions, the persistent run store, the lease lock, and the scheduler. |
| Scope IDs | [api_summary_scope_ids.md](api_summary_scope_ids.md) | Hierarchical scope identity, scope-path building, and zone-scoped builders. |
| Security | [api_summary_security.md](api_summary_security.md) | Principals/ACIs, access controls, authorization state machine, resource roles, bearer auth. |
| Settings | [api_summary_settings.md](api_summary_settings.md) | Reflected settings request/result messages, and feature flags: the flag API, its providers and rules, and the `/feature-flags` API declaration with its client. |
| Shutdown Cleanup | [api_summary_shutdown_cleanup.md](api_summary_shutdown_cleanup.md) | Disposable/closable contracts and signal-driven shutdown coordination. |
| Timezoned | [api_summary_timezoned.md](api_summary_timezoned.md) | Timezone-aware date/time value types and the IANA-backed `TomTimezone`. |

## Modules

### Bean Locator (`lib/src/tombase/beanlocator/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomBean<T>` | class | Typed handle that resolves a registered bean by type or name. |
| `TomComponent` | class | Annotation marking a class as a locatable component. |
| `TomNullInterface` | abstract class | Sentinel interface for the null component. |
| `TomNoInterface` | abstract class | Sentinel interface for an unspecified component interface. |
| `TomBeanLocatorException` | class | Bean-lookup failure (extends `TomException`). |
| `tomComponent` | const | Default `TomComponent` annotation instance. |
| `initializeBeanContext` | function | Initializes the bean registry. |
| `validateBeanReferences` | function | Resolves every pending handle so that wiring errors surface at startup. |

### Context (`lib/src/tombase/context/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomExecutionContext` | class | Typed, zone-scoped context of named `TomContextEntry` values. |
| `TomContextEntry<T>` | class | A lazily-evaluated named context value. |
| `TomZoneValues` | class | `Map`-like view over a zone's values used when running in context. |
| `TomContextProviders` | class | Static accessors for the ambient providers (organization, application, …). |
| `tomExecutionContext` | var | Pre-wired execution context (reassignable). |
| `TomTenantContext` | abstract final class | The current tenant — an isolation boundary, not an organization — held in the zone. |
| `TomTenantException` | class | Invalid tenant id or missing tenant context (extends `TomException`). |
| `TomTenantScopedCommand` | class | A `TomCommand` that runs its inner command inside a tenant, across isolates too. |
| `TomTenantEvent` | class | An event for an event-triggered job, carrying its tenant. |
| `TomTraceContext` | class | The W3C trace and span the current zone's work belongs to; parses and renders `traceparent` and carries `tracestate`. |
| `TomRequestId` | final class | The id of the current unit of work — a request, a job run, a socket message — that every log line, server exception and audit entry of it names. |
| `TomSpanKind` | enum | The OpenTelemetry span kinds: `internal`, `server`, `client`, `producer`, `consumer`. |
| `TomSpan` | abstract class | One span being recorded; its `context` is the trace position its work runs at. |
| `TomTracer` | abstract class | Makes spans; installed with `TomTracing.install`. |
| `TomTracing` | abstract final class | The installed tracer and the ways to open spans (`start`, `within`, `ending`, `trace`, `untraced`); nothing is created when no tracer is installed. |
| `TomRecordingTracer` | class | A tracer keeping ended spans in memory, for tests. |
| `TomRecordedSpan` | class | A span `TomRecordingTracer` recorded. |

### HTTP Connection (`lib/src/tombase/http_connection/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomServerCall` | class | A single server call (request/response envelope). |
| `TomServerCallSpecs` | class | Static specification of a server call. |
| `TomServerCallLoad` | class | Request payload of a server call. |
| `TomServerCallError` | class | Error payload of a server call. |
| `TomServerChannel` | class | Channel abstraction over a server connection. |
| `TomServerEndpoint<T, R>` | class | Typed server-side endpoint. |
| `TomServerConnectionException` | class | Connection failure (extends `TomException`). |
| `TomRequestAbortedException` | class | Aborted-request failure (extends `TomException`). |
| `TomHttpClientFactory` | class | Resolves a client through a per-instance override or the global registration. |
| `TomHttpClientAbstractFactory` | abstract interface class | The client-factory contract a custom factory implements. |
| `TomDefaultHttpClientFactory` | class | The shipped factory: the platform's client inside a `TomResilientClient`. |
| `TomRemoteApis` | class | Registry of remote API groups. |
| `TomApi` | class | A remote API group. |
| `TomApiEndpoint<ReturnType, RequestType>` | class | A typed remote API endpoint. |
| `TomEndpointException` | class | Endpoint failure (extends `TomException`). |
| `TomContentDisposition` | class | Content-Disposition parsing/model. |
| `TomHeader` | class | HTTP header name constants/model. |
| `TomHttpMethod` | class | HTTP method constants/model. |
| `TomMimeType` | class | MIME-type model. |
| `TomMimeTypeException` | class | MIME-type failure (extends `TomException`). |
| `StaticFileMimetypeMapping` | class | Extension→MIME-type map for static files. |
| `TomAuthRefresher` | abstract class | Contract for refreshing an expired auth token. |
| `TomAuthRetryPolicy` | class | Policy for retrying on auth expiry. |
| `TomAuthExpiredException` | class | Auth-expired failure (extends `TomException`). |
| `TomClientRemoteContext` | class | Client-side remote context. |
| `TomClientRemoteContextException` | class | Remote-context failure (extends `TomException`). |
| `tomRemoteApis` | getter | The current `TomRemoteApis` registry. |
| `tomRunWithAuthRetry` | function | Runs a call under an auth-retry policy. |
| `tomDefaultAuthRetryPolicy` | const | Default `TomAuthRetryPolicy`. |
| `TomFileMetadata` | class | What the server knows about a stored file. |
| `TomFileSource` | class | The bytes to upload, together with what the server needs to know about them. |
| `TomFileTransferClient` | abstract class | Moves file bytes between an application and a file store. |
| `TomFileTransferException` | class | Exception thrown when a file transfer fails. |
| `TomHttpFileTransferClient` | class | A `TomFileTransferClient` over HTTP. |
| `TomMemoryFileTransferClient` | class | A `TomFileTransferClient` that keeps everything in a map. |
| `TomRequestTimeoutException` | class | Exception thrown when a request outlives its `TomServerCallSpecs.timeout`. |
| `TomTransferCancellation` | class | A cancel signal shared with an in-flight transfer. |
| `TomTransferProgress` | class | How far a transfer has got. |
| `TomHttpResilienceException` | class | A call refused or abandoned by a resilience policy (extends `TomException`). |
| `TomHttpRetryPolicy` | class | When and how often a failed attempt is repeated. |
| `TomCircuitBreakerPolicy` | class | When a destination's circuit opens and how long it stays open. |
| `TomBulkheadPolicy` | class | How many calls one destination may have at once. |
| `TomHttpResiliencePolicy` | class | The timeout, retry, breaker and bulkhead policies of one destination. |
| `TomCircuitState` | enum | Where a destination's circuit stands: closed, open, half-open. |
| `TomCircuitBreaker` | class | The circuit breaker of one destination. |
| `TomBulkhead` | class | The bulkhead of one destination. |
| `TomHttpResilience` | abstract final class | The isolate's resilience configuration and per-destination state. |
| `TomResilientClient` | class | A `package:http` client applying the resilience policies to every call. |
| `decodeFileDescriptor` | function | Decodes the JSON descriptor body shared by the upload and describe responses. |
| `tomEscapeFileNameForDisposition` | function | Escapes a file name for a quoted `Content-Disposition` parameter. |
| `tomFileDescriptorHeaders` | function | Writes the descriptor header a `HEAD` response needs so `TomFileTransferClient.describe` can answer without a body. |
| `tomFileNameFromDisposition` | function | Extracts `filename="…"` from a `Content-Disposition` header, or `null` when the header is absent or names no file. |

### Isolate Pooling (`lib/src/tombase/isolate_pooling/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomWorker` | class | An isolate worker. |
| `TomWorkerPool` | class | A pool of workers dispatching commands. |
| `TomCommandDispatcher` | abstract interface class | Dispatch-only view of a pool: `execute` and `close`. |
| `TomCreatorChannel` | abstract interface class | The worker-to-creator back-channel; `current` is the running isolate's. |
| `TomWorkerContext` | class | Per-worker isolate context/bootstrap. |
| `TomExecutor` | abstract class | Executes a command inside a worker. |
| `TomCommand` | abstract class | A unit of work sent to a worker. |
| `TomWorkerException` | class | Worker failure (extends `TomException`). |
| `TomWorkerDiedException` | class | Exception used to fail a command whose worker isolate died mid-flight. |

### JSON (`lib/src/tombase/json/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomJsonSerializable` | abstract class | `toJson()` contract for reflectable objects. |
| `mergeMapsOneSided` | function | One-sided recursive map merge. |
| `deepCopyJsonTree` | function | Deep copy of a JSON tree, sharing no map or list. |
| `traverseAndProcess` | function | Traverses a JSON tree — maps, lists, and lists inside lists — processing matching string values. |
| `traverseAndCreate` | function | Traverses a JSON tree, handing each matching key's containing map to a creator that may insert into, remove from, or overwrite it. |
| `getPathFromTree` | function | Resolves a dotted path from a tree, wrapping a non-map terminal (`null` included) under a supplied name. |
| `getObjectFromTree` | function | Resolves an object at a dotted path, returning `null` for a present-and-null key and throwing only for an absent one. |
| `lookupObjectInTree` | function | The same walk as `getObjectFromTree`, reporting a path it cannot resolve as `found: false` instead of throwing — for a lenient caller to whom a miss is an answer. |
| `processTree` | function | Applies `@`-directive processing to a tree; the key pattern is anchored to exactly three parts, and both a malformed directive key and a `"@"` whose key the provider did not return throw a named `Exception`. |
| `makeCleanJsonMap` | function | Normalizes a map into a clean JSON map, converting `TomJsonSerializable` values. |
| `substituteEnvVars` | function | Substitutes `${VAR}` references in a tree; an empty environment value counts as unset. |
| `prettyJson` | function | Indent-formats a JSON string. |
| `prettyJsonLine` | function | Single-line pretty JSON. |
| `indentEncoder` | final | Shared two-space `JsonEncoder`. |
| `TomJsonCycleException` | class | Raised when a tree walk meets a value that refers back to one of its own ancestors. |
| `TomJsonDirectiveException` | class | Raised when a profile directive cannot be resolved by `processTree`. |
| `TomJsonPathException` | class | Raised when a dot-separated path cannot be resolved against a tree. |

### Little Things (`lib/src/tombase/little_things/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomException` | class | The kernel base exception (implements `TomLoggable`). |
| `TomFormattingException` | class | Raised when a formatting function is given a value it cannot render. |
| `getFromCurrentZone` | function | Reads the current zone's value for the exact key `T`. |
| `getObjectFromCurrentZone` | function | The same lookup, key given at run time, no `is` check. |
| `runChecked` | function | Runs an async body wrapping errors. |
| `runCheckedSync` | function | Runs a sync body wrapping errors. |
| `tomPrintStackTrace` | function | Logs a formatted stack trace at ERROR level. |
| `tomGetStackTrace` | function | Returns a formatted stack trace string. |
| `tomGetStackTraceAsList` | function | Returns a stack trace as a list of frames. |
| `tomGetStackTraceAsTuple` | function | Returns a stack trace as structured tuples. |
| `convertMinutesToUtcOffset` | function | Formats a minute offset as a UTC offset string; throws outside ±14:00. |
| `TomStackTraceNoise` | class | Classifies a stack frame as noise for the formatting functions in this library. |

### Logging (`lib/src/tombase/logging/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomIsolateLogging` | class | Cross-isolate logging coordinator. |
| `TomIsolateLogOutput` | class | Log output forwarding across isolates. |
| `TomCreatorLogOutput` | class | Output that forwards to the creator isolate. |
| `TomInterIsolateLogMessage` | class | Message carrying a log record between isolates. |
| `TomLoggingExecutor` | class | Executor for isolate logging commands. |
| `TomLoggingWorkerContext` | class | Worker context wiring isolate logging. |
| `TomRemoteLogOutput` | class | Log output sending records to a remote server. |
| `TomRemoteLogServer` | class | Receives remote log messages. |
| `TomRemoteLogMessage` | class | Remote log request message. |
| `TomRemoteLogResult` | class | Remote log response. |
| `TomLoggingContext` | class | Context for remote logging. |
| `TomFileLogReplayStore` | class | A `TomLogReplayStore` that persists buffered records to a JSON file. |
| `TomInMemoryLogReplayStore` | class | In-memory `TomLogReplayStore` — the zero-config default. |
| `TomLogReplayStore` | abstract class | Pluggable backend for `TomRemoteLogOutput`'s replay queue. |
| `TomLogFieldProvider` | typedef | Computes one context field of a structured log line from the current zone. |
| `TomLogContext` | abstract final class | The context fields every structured log line carries (`trace_id`, `span_id`, `request_id`, `tenant`, and registered ones). |
| `TomJsonLogOutput` | class | Log output writing one JSON object per line. |

### Metrics (`lib/src/tombase/metrics/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomMetricsException` | class | A misuse of the metrics API: an invalid name, a name registered as two kinds, a negative counter increment (extends `TomException`). |
| `TomMetricKind` | enum | `counter`, `gauge`, `histogram` — how an instrument's points are read. |
| `tomLatencyBuckets` | const | Bucket bounds in seconds for millisecond-to-second latencies. |
| `tomLagBuckets` | const | Bucket bounds in seconds for second-to-hour delays (job start lag, job run time). |
| `TomMetric` | sealed class | One instrument of a registry: name, help, unit, kind. |
| `TomCounter` | class | A total that only grows; read as `<name>_total`. |
| `TomGauge` | class | A value set whenever it changes. |
| `TomHistogram` | class | Observations sorted into fixed buckets; read as `_bucket`, `_sum`, `_count`. |
| `TomHistogramData` | class | One histogram series: a count per bucket, the observation count and their sum. |
| `TomMetricPoint` | class | One series of a family at the moment of the snapshot. |
| `TomMetricFamily` | class | One instrument's series at the moment of the snapshot. |
| `TomObservedValue` | class | One value an observation callback reports, with its labels. |
| `TomMetricObserver` | typedef | Computes an observed gauge's values when a snapshot is taken. |
| `TomMetricObservation` | class | A registered observation; `cancel` removes it. |
| `TomMetricRegistry` | class | The instruments of one isolate, and the sorted snapshot of them (`collect`). |
| `TomMetrics` | abstract final class | `TomMetrics.registry` — the registry the framework records into. |
| `tomPrometheusContentType` | const | The `Content-Type` a Prometheus scrape is served with. |
| `tomPrometheusText` | function | A snapshot in the Prometheus text exposition format 0.0.4. |

### Observable (`lib/src/tombase/observable/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomObservable` | class | Base observable with observer notification. |
| `TomObserver<T>` | abstract class | Observer contract over a `TomObservable`. |
| `TomFunctionObserver<T>` | class | Function-backed observer. |
| `TomObservableException` | class | Observable failure (extends `TomException`). |
| `TomObject<T>` | class | Boxed observable value of type `T`. |
| `TomString`, `TomInt`, `TomDouble`, `TomBool`, `TomDateTime` | class | Non-null boxed primitives. |
| `TomNString`, `TomNInt`, `TomNDouble`, `TomNBool`, `TomNDateTime` | class | Nullable boxed primitives. |
| `TomOTimezoned<TZ>`, `TomOZonedTime`, `TomOZonedDate`, `TomOZonedDateTime` | class | Boxed timezone-aware values. |
| `TomNOTimezoned<TZ>`, `TomNOZonedTime`, `TomNOZonedDate`, `TomNOZonedDateTime` | class | Nullable boxed timezone-aware values. |
| `TomDateRange`, `TomTimeRange`, `TomDateTimeRange` | class | Range value objects. |
| `TomClass` | class | Boxed map of named `TomObject`s (composite). |
| `TomList<E>` | class | Observable list of `TomObject`s. |
| `TomMap<K, V>` | class | Observable map of `TomObject` values. |
| `TomListLifecycleListener` | abstract class | Lifecycle callbacks for `TomList` elements. |
| `TomObservableEnum<E extends Enum>` | class | Boxed enum whose display text resolves from the text bundle under `<scope>.<enumName>.<value>`. |
| `TomEnumResourceSegment` | abstract interface class | Implemented by an enum that overrides `toString()`, to declare its key segment explicitly. |
| `tomNull` | final | The shared, read-only null-object `TomObject<String>`; writing to it throws. |
| `TomObservableObservation` | extension | Adds the observation operator `>>` to every `TomObservable`. |

### Offline (`lib/src/tombase/offline/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomOfflineException` | class | An offline-store failure, `offline.*` keys (extends `TomException`). |
| `TomLocalStoreEngine` | abstract class | The device database contract an application implements: JSON documents in named collections, and all-or-nothing transactions. |
| `TomMemoryLocalStoreEngine` | class | `TomLocalStoreEngine` in memory, for tests and session caches. |
| `TomOfflineStore` | class | The device's copy of server entities with their versions, the queue of pending changes, and the sync cursors. |
| `TomLocalEntityCodec<T>` | class | How a repository turns an entity into JSON and back, and which id it has. |
| `TomLocalRepository<T>` | class | The device-side counterpart of the server's `TomRepository`; every write is queued for the server. |
| `TomChangeOperation` | enum | What a pending change does: `save`, `delete`. |
| `TomPendingChange` | class | A local change waiting to reach the server, with the version it was based on. |
| `TomPushOutcome` | enum | How the server took a pushed change: `applied`, `conflict`, `rejected`. |
| `TomPushResult` | class | The server's answer to one pushed change. |
| `TomPulledChange` | class | One change the server applied, as a device pulls it. |
| `TomPullBatch` | class | The changes after a cursor, the next cursor, and whether more follow. |
| `TomSyncTransport` | abstract class | How a device reaches the server's sync endpoint: `push`, `pull`. |
| `TomSyncConflict` | class | A pushed change the server did not apply, with what the server holds. |
| `TomConflictResolution` | sealed class | What to do about a conflict: `keepServer`, `keepLocal`, `merge`. |
| `TomConflictResolver` | typedef | Decides a conflict; the application's to supply. |
| `TomSyncReport` | class | What one sync did: applied, conflicts, discarded, rejected, pulled, still pending. |
| `TomSyncEngine` | class | Pushes the queued changes, resolves conflicts, pulls the server's changes. |
| `TomMemorySyncServer` | class | The sync protocol's server side in memory: the reference semantics, and a transport for tests. |

### Preferences (`lib/src/tombase/preferences/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomUserPreferenceKeys` | class | Namespace of the preference keys the framework itself reads (`tom.timezone`, `tom.language`, `tom.country`, `tom.theme`). |
| `TomUserPreferenceDto` | class | One stored preference on the wire: key, stored type name, JSON text, UTC write timestamp, origin (`user`, `role`, `deployment`). |
| `TomUserPreferenceWriteRequest` | class | Write request — the DTO's value fields without the timestamp. |
| `TomUserPreferenceBulkWriteRequest` | class | Bulk write request — key → `{valueType, value}`, written all or none. |
| `TomUserPreferenceKeyRequest` | class | Read/delete request addressing one preference by key. |
| `TomUserPreferencesApiService` | abstract class | The contract's Dart face, implemented by the server and by client callers. |
| `TomUserPreferenceCodec` | class | Encodes/decodes preference values; refuses a type mismatch rather than coercing. |
| `TomUserPreferenceCodecException` | class | Encode/decode failure (extends `TomException`). |
| `tomUserPreferencesApi` | final | The `/preferences` API: list, read, write, bulk write, delete, clear — all `TomAuthenticatedAccess`. |
| `tomUserPreferencesApiId` | const | The API id (`tomUserPreferences`) the server implementation binds to. |
| `tomUserPreferencesListEndpointId`, `…ReadEndpointId`, `…WriteEndpointId`, `…BulkWriteEndpointId`, `…DeleteEndpointId`, `…ClearEndpointId` | const | The six endpoint ids. |
| `tomUserPreferenceOriginUser`, `…OriginRole`, `…OriginDeployment` | const | The values of `TomUserPreferenceDto.origin`. |
| `tomUserPreferencesBulkMalformedErrorKey` | const | `preferences.bulk.malformed` — a bulk entry is not `{valueType, value}` (`400`). |
| `registerTomUserPreferencesApi()` | function | Registers the API with `tomRemoteApis`; idempotent. |
| `TomUserPreferenceKeyException` | class | Raised when a preference key does not satisfy `TomUserPreferenceKeys`. |
| `registerTomUserPreferencesApi` | function | Registers `tomUserPreferencesApi` with the global `tomRemoteApis` registry. |
| `TomNotificationPreferenceKeys` | abstract final class | The preference keys a principal's notification choices are stored under, and the encoding of their values. |
| `tomNotificationPreferencesApi` | final | The `/notification-preferences` API: one authenticated `GET` listing the notification types the caller may configure. |
| `tomNotificationPreferencesApiId`, `tomNotificationPreferencesListEndpointId` | const | Its API id (`tomNotificationPreferences`) and endpoint id (`listNotificationPreferences`). |
| `registerTomNotificationPreferencesApi` | function | Registers `tomNotificationPreferencesApi` — `GET /notification-preferences` — with `tomRemoteApis`; idempotent. |

### Reflection (`lib/src/tombase/reflection/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomReflector` | class | Kernel reflector (extends `Reflection`); JSON (de)serialization via mirrors. |
| `TomReflectionInfo` | class | Reflection metadata helper over a reflector. |
| `TomReflectorException` | class | Reflection failure (extends `TomException`). |
| `TomRequiredField` | class | Field annotation: a bound map must supply a value for it. |
| `tomReflector` | const | Shared `TomReflector` instance. |
| `tomReflectionInfo` | final | Shared `TomReflectionInfo` instance. |
| `TomRecommendedField` | class | Marks a field a bound map *should* supply a value for, where its absence is worth saying but not worth refusing. |

### Resources (`lib/src/tombase/resources/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomTextResourceProvider` | class | Provides localized text over a JSON tree with key fallback; `appResourcesRevision` announces bundle changes. |
| `TomConfigResourceProvider` | class | Provides config values over a JSON tree. |
| `TomResourceException` | class | Thrown when the resource providers are used outside their contract. |

### Scheduling (`lib/src/tombase/scheduling/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomSchedule` | abstract class | The "when" contract — `nextFireAfter` and nothing about jobs. |
| `TomCronSchedule`, `TomCalendarSchedule`, `TomIntervalSchedule`, `TomOnceSchedule`, `TomEventSchedule` | class | Cron, month-grid, fixed-interval, one-shot and stream-driven schedules. |
| `TomCalendarRule` | enum | `dayOfMonth`, `weekdayOfMonth`. |
| `TomJobDefinition` | class | A named schedule bound to a `TomCommand` factory, plus retry/timeout/overlap/catch-up policy. |
| `TomRetryPolicy` | class | Exponential backoff with jitter (`none` for no retry). |
| `TomMissedWindowPolicy` | enum | `skip`, `runOnce`, `runAll`. |
| `TomJobDispatcher` | abstract class | How a job's command is executed. |
| `TomWorkerPoolJobDispatcher`, `TomInlineJobDispatcher` | class | Dispatch onto a worker pool, or inline in the calling isolate. |
| `TomJobAlert` | class | Everything the scheduler wants an operator to know. |
| `TomJobAlertKind` | enum | Attempt/run failures, timeouts, missed windows, never-fires, and the four lease outcomes. |
| `TomJobAlertSink` | typedef | `void Function(TomJobAlert alert)`. |
| `TomPermanentFailure` | mixin | Marker meaning "do not retry". |
| `TomPermanentJobFailure` | class | The ready-made permanent failure. |
| `TomJobBase` | abstract class | Base for an annotation-declared job; carries the injected `TomJobRun`. |
| `TomScheduledJob` | class | The `@TomScheduledJob` annotation — exactly one of `cron`/`interval`/`calendar`/`event`. |
| `TomScheduledJobs` | class | Reflection-driven `discover` / `registerAll`. |
| `TomJobRun` | class | One row per schedule *window* — the idempotence key across restarts and cluster nodes. |
| `TomJobRunState` | enum | `pending`, `running`, `succeeded`, `failed`. |
| `TomJobStore` | abstract class | The persistence contract the tick loop is written in. |
| `TomMemoryJobStore`, `TomFileJobStore` | class | In-process store, and its JSON-file-backed durable subclass. |
| `TomLease` | class | A time-limited claim carrying a monotonic fencing `token`. |
| `TomLeaseInfo` | class | A resource's lock state, including "the holder vanished". |
| `TomLeaseLock` | abstract class | The mutual-exclusion contract. |
| `TomMemoryLeaseLock`, `TomFileLeaseLock` | class | In-isolate lock, and a cross-process lock over a shared directory. |
| `TomScheduler` | class | The tick loop: recover, plan, claim, lease, dispatch, retry (implements `TomClosable`). |
| `TomScheduleException`, `TomScheduledJobException` | class | Misconfiguration, raised eagerly at construction / scan time. |
| `TomJobClaim` | class | A ticket proving that one particular claim of `run` was won. |
| `TomJobRunContext` | class | What a running job body may ask of its run: its checkpoint, and a way to save a new one. |
| `TomJobRunCommand` | class | The command the scheduler dispatches around every body, carrying its run context and running each attempt under a request id of its own. |
| `TomOneShotResource` | extension type | A lease resource name that will never be acquired again once its work is done — the only kind `TomLeaseLock.forget` accepts. |
| `TomJobBacklog` | class | The due, unclaimed runs of one job — what `TomJobStore.backlog` answers. |

### Scope IDs (`lib/src/tombase/scope_ids/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomScope` | abstract class | Scope identity contract with zone-current access and path building. |
| `TomScopeBase` | class | Concrete `TomScope` using `TomScopeMixin`. |
| `TomScopeMixin` | mixin | Adds scope identity/parenting to any `Object`. |
| `ScopeCapture` | class | Captures a scope and wraps callbacks so they run in it when invoked later. |
| `TomScopeException` | class | Raised when a scope cannot be built or used as one. |

### Security (`lib/src/tombase/security/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomPrincipal` | class | An authenticated principal. |
| `TomUser` | class | A user principal (const `guestUsername`). |
| `TomGroup`, `TomRole`, `TomEntitlement` | class | Authorization subjects/grants. |
| `TomAccessControlInformation` | class | Resolved access-control info for a principal. |
| `TomClientLimitsInformation` | class | Client-side limits info. |
| `TomAccessControlDefinition` | class | Definition of an access-control policy. |
| `TomLoginFailure` | enum | Why a login failed, as the closed set a client branches on; carried by the server's `TomLoginException` and by a failed `TomAuthenticationResult`. |
| `TomAuthState` | enum | `none`, `disabled`, `read`, `full` (with `narrow`/`widen`, visibility getters). |
| `AuthGroupMode` | enum | `controlsAll`, `controlsWidest`, `controlsNarrowest`. |
| `TomAuthorizerStrategy` | enum | `authorizerDecides`, `authorizerNarrowsOnly`. |
| `TomAuthorizable` | abstract class | Contract for elements carrying an auth group. |
| `TomAuthorizationGroup` | class | Collective authorization control over members. |
| `TomAuthorization` | class | Global authorization resolver. |
| `TomAuthorizationAdapter` | abstract class | Adapter resolving auth state per resource. |
| `TomAuthorizer` | class | Per-element authorizer applying a strategy. |
| `TomUIStateController` | class | Build-time UI-state narrowing controller. |
| `TomResourceRoleRegistry` | class | Maps role names to a `TomAuthState`. |
| `TomResourceRoleAdapter` | abstract class | Adapter supplying resource-role mappings. |
| `TomItemType` | class | An item type with ordered permission levels, each mapped to a `TomAuthState`. |
| `TomItemTypeRegistry` | class | The process-wide registry of item types. |
| `TomItemPermissions` | abstract final class | The level a principal holds on an item, patterns included. |
| `TomAccessControl` | abstract class | Base access-control policy; computes the `min(user, deployment)` meet. |
| `TomGradedAccess`, `TomNoAccess`, `TomPublicAccess`, `TomAuthenticatedAccess`, `TomGuestAccess`, `TomCustomAccess`, `TomEntitlementAccess`, `TomRoleAccess`, `TomGroupAccess`, `TomResourceKeyAccess` | class | Concrete access-control policies. |
| `TomServerPrincipal` | class | The ambient server principal — the deployment's own identity, which caps every user's grants. |
| `TomResourceKeyProtection` | class | Protects a value behind a resource key. |
| `TomAuthenticationMessage` | class | Authentication request message. |
| `TomAuthenticationResult` | class | Authentication response. |
| `TomBearerAuthentication` | class | Bearer-token authentication helper. |
| `Tom2FAChallenge` | class | A pending second factor, carried in an interim token's public claims. |
| `Tom2FAClaims` | class | The claim names a pending 2FA challenge travels under. |
| `Tom2FAPendingEnrolment` | class | A second factor being *set up*, carried in an interim token's public claims; `hasOffer` tells a chooser apart from a half-built mechanism. |
| `Tom2FAEnrolmentClaims` | class | The claim names a pending 2FA enrolment travels under. |
| `Tom2FAMethodDescriptor` | class | How a mechanism names itself to a user choosing one — an identifier plus three resource keys, never literal text. |
| `TomTotp` | class | RFC 4226/6238 code derivation and the base32 codec. |
| `TomBase64Url` | abstract final class | Unpadded base64url, the encoding every WebAuthn field uses. |
| `TomWebAuthnAlgorithms` | abstract final class | The COSE algorithm ids a passkey may be created with. |
| `TomWebAuthnUserVerification` | enum | What a passkey must prove about the user. |
| `TomWebAuthnCreationOptions` | class | The options to make a passkey, in their W3C JSON form. |
| `TomWebAuthnRequestOptions` | class | The options to sign in with a passkey, in their W3C JSON form. |
| `TomWebAuthnRegistrationResponse` | class | What an authenticator returned when it made a passkey. |
| `TomWebAuthnAuthenticationResponse` | class | What an authenticator returned when it signed a challenge. |
| `tomProtect<T>`, `tomProtected` | function | Wrap/read a resource-key-protected value. |
| `TomAccessControlHandler` | typedef | Function signature for custom access control handlers. |
| `TomClientContext` | class | The language, country and timezone a principal carries when nothing better is known. |
| `TomClientLimitsProvider` | abstract class | The source of a client's limits: what its subscription currently grants. |
| `TomOAuthApiService` | abstract class | The typed service interface behind `tomOAuthApi`. |
| `TomOAuthAuthorizationDto` | class | Where to send the user, and the handle the flow is remembered under. |
| `TomOAuthAuthorizationRequest` | class | The request that starts an authorization-code flow. |
| `TomOAuthCallbackRequest` | class | What the provider's redirect carried back, forwarded by the application. |
| `TomOAuthProviderDto` | class | One configured external-identity provider, as a client sees it. |
| `TomProtectedField` | class | Marks a reflected field as protected by `resourceKey`. |
| `TomProtectionSettingException` | class | Raised when a protection setting cannot be applied: a name in the `tom.protection` namespace that is not a switch, or a value that is not `true` or `false`. |
| `TomTokenLifetimeException` | class | A token refused because it is not live: expired, carrying no usable `exp`, or contradicting itself about when it expires. |
| `registerTomOAuthApi` | function | Registers `tomOAuthApi` with the global `tomRemoteApis` registry. |
| `tomResourceState` | function | Convenience function for the `TomAuthState` the current user holds on `resourceKey` — a shorthand for `TomResourceKeyProtection.resourceState`. |

### Settings (`lib/src/tombase/settings/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomGetSettingsMessage` | class | Reflected request for client settings. |
| `TomGetSettingsResult` | class | Reflected settings response (texts, roles, …). |
| `TomFeatureFlags` | abstract final class | The flag API: `isEnabled`, `getString`, `getInt`, `getDouble`, `getObject`, `details`, through the installed `provider`; never throws. |
| `TomFlagContext` | class | Who a flag is evaluated for: targeting key, tenant, roles, attributes; `current()` reads the zone. |
| `TomFlagResolutionReason` | enum | Why a flag resolved to its value (OpenFeature's reasons). |
| `TomFlagResolution` | class | One evaluation: value, reason, deciding rule, error. |
| `TomFlagProvider` | abstract class | The provider contract, shaped after OpenFeature's: `resolve`, `evaluateAll`. |
| `TomStaticFlagProvider` | class | Fixed values — a client's snapshot, or a test's. |
| `TomFlagRule` | class | A targeting rule by tenants, roles and stable percentage. |
| `TomFlagDefinition` | class | A flag: default, rules, and whether a client may read it. |
| `TomRuleFlagProvider` | class | The built-in provider: flag definitions read from configuration. |
| `tomFeatureFlagsApi` | final | The `GET /feature-flags` API, `TomPublicAccess`. |
| `tomFeatureFlagsApiId`, `tomFeatureFlagsEvaluateEndpointId` | const | The API id (`tomFeatureFlags`) and its endpoint id (`evaluateFlags`). |
| `registerTomFeatureFlagsApi` | function | Registers `tomFeatureFlagsApi` with the global `tomRemoteApis` registry; idempotent. |
| `TomFeatureFlagsClient` | abstract final class | Fetches a client's evaluated flags from a server. |
| `TomFeatureFlagsException` | class | A client could not fetch its flags, `feature_flags.fetch.failed` (extends `TomException`). |

### Shutdown Cleanup (`lib/src/tombase/shutdown_cleanup/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomShutdownCleanup` | class | Coordinates ordered shutdown on process signals. |
| `TomDisposable` | abstract class | `dispose()` contract. |
| `TomClosable` | abstract class | `close()` contract. |
| `TomCloseAdaptor` | class | Adapts a `@tomReflector` class's close-style method to `TomClosable`. |
| `TomSignalHandler` | typedef | `void Function(ProcessSignal)`. |
| `tomShutdownCleanup` | final | Shared shutdown coordinator. |
| `TomCloseAdaptorException` | class | Raised by the `TomCloseAdaptor` constructor when the target has no method the adaptor can call. |
| `TomShutdownUnregister` | typedef | Takes back one registration made on a `TomShutdownCleanup`. |

### Timezoned (`lib/src/tombase/timezoned/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomTimezoned` | class | Timezone-aware datetime (extends `DateTime`, stored UTC). |
| `TomZonedDate` | class | Date-only timezone-aware value (`@D@`). |
| `TomZonedTime` | class | Time-only timezone-aware value (`@T@`). |
| `TomZonedDateTime` | class | Full timezone-aware datetime (`@X@`). |
| `TomTimezone` | class | IANA timezone wrapper (name/offset lookup, DST-aware conversion). |
| `TomTimezoneException` | class | Timezone failure (extends `TomException`). |
| `tomSetupTimezones` | function | Async IANA database init (mandatory on web). |
| `tomSetupTimezonesSync` | function | Sync IANA database init (native/Flutter). |
