# Tom Core Kernel API Reference: Index

Per-module API summaries for `tom_core_kernel` — the foundational layer of Tom
Core. The package barrel (`lib/tom_core_kernel.dart`) exports the fifteen
modules documented here and re-exports `tom_basics`, `tom_crypto`, and
`tom_reflection` (see those packages' docs for their APIs).

Each summary follows the standard format (Overview with source paths, class
hierarchy, per-class constructors / static & instance members, enums, and
top-level functions/constants). Only public members are listed; `_`-prefixed
declarations are omitted.

## Quick Navigation

| Module | Summary | What it provides |
| ------ | ------- | ---------------- |
| Bean Locator | [api_summary_beanlocator.md](api_summary_beanlocator.md) | Component annotation and typed bean lookup/dependency injection. |
| Context | [api_summary_context.md](api_summary_context.md) | Zone-scoped typed execution context and ambient providers. |
| HTTP Connection | [api_summary_http_connection.md](api_summary_http_connection.md) | Server call model, remote APIs/endpoints, headers, MIME types, auth-retry, client factories. |
| Isolate Pooling | [api_summary_isolate_pooling.md](api_summary_isolate_pooling.md) | Worker/executor/command model and isolate worker pool. |
| JSON | [api_summary_json.md](api_summary_json.md) | JSON serialization contract, map merge/traversal, env substitution, pretty printing. |
| Little Things | [api_summary_little_things.md](api_summary_little_things.md) | Kernel base exception, zone helpers, checked runners, stack-trace and offset formatting. |
| Logging | [api_summary_logging.md](api_summary_logging.md) | Cross-isolate and remote log transport, outputs, and log servers. |
| Observable | [api_summary_observable.md](api_summary_observable.md) | Observable base, observers, and the boxed `TomObject<T>` value/collection hierarchy. |
| Reflection | [api_summary_reflection.md](api_summary_reflection.md) | The kernel reflector, reflection info, and JSON (de)serialization via mirrors. |
| Resources | [api_summary_resources.md](api_summary_resources.md) | Text and config resource providers over a JSON tree. |
| Scope IDs | [api_summary_scope_ids.md](api_summary_scope_ids.md) | Hierarchical scope identity, scope-path building, and zone-scoped builders. |
| Security | [api_summary_security.md](api_summary_security.md) | Principals/ACIs, access controls, authorization state machine, resource roles, bearer auth. |
| Settings | [api_summary_settings.md](api_summary_settings.md) | Reflected settings request/result messages. |
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

### Context (`lib/src/tombase/context/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomExecutionContext` | class | Typed, zone-scoped context of named `TomContextEntry` values. |
| `TomContextEntry<T>` | class | A lazily-evaluated named context value. |
| `TomZoneValues` | class | `Map`-like view over a zone's values used when running in context. |
| `TomContextProviders` | class | Static accessors for the ambient providers (organization, application, …). |
| `tomExecutionContext` | var | Pre-wired execution context (reassignable). |

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
| `TomHttpClientFactory` | class | Default HTTP client factory. |
| `TomHttpClientAbstractFactory` | class | Abstract client-factory contract. |
| `TomDefaultHttpClientFactory` | class | Concrete default factory. |
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

### Isolate Pooling (`lib/src/tombase/isolate_pooling/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomWorker` | class | An isolate worker. |
| `TomWorkerPool` | class | A pool of workers dispatching commands. |
| `TomWorkerContext` | class | Per-worker isolate context/bootstrap. |
| `TomExecutor` | abstract class | Executes a command inside a worker. |
| `TomCommand` | abstract class | A unit of work sent to a worker. |
| `TomWorkerException` | class | Worker failure (extends `TomException`). |

### JSON (`lib/src/tombase/json/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomJsonSerializable` | abstract class | `toJson()` contract for reflectable objects. |
| `mergeMapsOneSided` | function | One-sided recursive map merge. |
| `traverseAndProcess` | function | Traverses a JSON tree processing matching nodes. |
| `traverseAndCreate` | function | Traverses a JSON tree creating new nodes. |
| `getPathFromTree` | function | Resolves a dotted path from a tree. |
| `getObjectFromTree` | function | Resolves an object at a dotted path. |
| `processTree` | function | Applies `@`-directive processing to a tree. |
| `makeCleanJsonMap` | function | Normalizes a map into a clean JSON map. |
| `substituteEnvVars` | function | Substitutes `${VAR}` references in a tree. |
| `prettyJson` | function | Indent-formats a JSON string. |
| `prettyJsonLine` | function | Single-line pretty JSON. |
| `indentEncoder` | const | Shared two-space `JsonEncoder`. |

### Little Things (`lib/src/tombase/little_things/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomException` | class | The kernel base exception (implements `TomLoggable`). |
| `getFromCurrentZone` | function | Reads a typed value from the current zone. |
| `getObjectFromCurrentZone` | function | Reads an object of a type from the current zone. |
| `runChecked` | function | Runs an async body wrapping errors. |
| `runCheckedSync` | function | Runs a sync body wrapping errors. |
| `tomPrintStackTrace` | function | Prints a formatted stack trace. |
| `tomGetStackTrace` | function | Returns a formatted stack trace string. |
| `tomGetStackTraceAsList` | function | Returns a stack trace as a list of frames. |
| `tomGetStackTraceAsTuple` | function | Returns a stack trace as structured tuples. |
| `convertMinutesToUtcOffset` | function | Formats a minute offset as a UTC offset string. |

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
| `tomNull` | final | The shared null-object `TomObject<String>`. |

### Reflection (`lib/src/tombase/reflection/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomReflector` | class | Kernel reflector (extends `Reflection`); JSON (de)serialization via mirrors. |
| `TomReflectionInfo` | class | Reflection metadata helper over a reflector. |
| `TomReflectorException` | class | Reflection failure (extends `TomException`). |
| `tomReflector` | const | Shared `TomReflector` instance. |
| `tomReflectionInfo` | final | Shared `TomReflectionInfo` instance. |

### Resources (`lib/src/tombase/resources/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomTextResourceProvider` | class | Provides localized text over a JSON tree with key fallback. |
| `TomConfigResourceProvider` | class | Provides config values over a JSON tree. |

### Scope IDs (`lib/src/tombase/scope_ids/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomScope` | abstract class | Scope identity contract with zone-current access and path building. |
| `TomScopeBase` | class | Concrete `TomScope` using `TomScopeMixin`. |
| `TomScopeMixin` | mixin | Adds scope identity/parenting to any `Object`. |
| `InScopeBuilder` | class | Runs a body within a nested scope. |

### Security (`lib/src/tombase/security/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomPrincipal` | class | An authenticated principal. |
| `TomUser` | class | A user principal (const `guestUsername`). |
| `TomGroup`, `TomRole`, `TomEntitlement` | class | Authorization subjects/grants. |
| `TomAccessControlInformation` | class | Resolved access-control info for a principal. |
| `TomClientLimitsInformation` | class | Client-side limits info. |
| `TomAccessControlDefinition` | class | Definition of an access-control policy. |
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
| `TomAccessControl` | abstract class | Base access-control policy; computes the `min(user, deployment)` meet. |
| `TomGradedAccess`, `TomNoAccess`, `TomPublicAccess`, `TomAuthenticatedAccess`, `TomGuestAccess`, `TomCustomAccess`, `TomEntitlementAccess`, `TomRoleAccess`, `TomGroupAccess`, `TomResourceKeyAccess` | class | Concrete access-control policies. |
| `TomServerPrincipal` | class | The ambient server principal — the deployment's own identity, which caps every user's grants. |
| `TomResourceKeyProtection` | class | Protects a value behind a resource key. |
| `TomAuthenticationMessage` | class | Authentication request message. |
| `TomAuthenticationResult` | class | Authentication response. |
| `TomBearerAuthentication` | class | Bearer-token authentication helper. |
| `Tom2FAChallenge` | class | A pending second factor, carried in an interim token's public claims. |
| `Tom2FAClaims` | class | The claim names a pending 2FA challenge travels under. |
| `TomTotp` | class | RFC 4226/6238 code derivation and the base32 codec. |
| `tomProtect<T>`, `tomProtected` | function | Wrap/read a resource-key-protected value. |

### Settings (`lib/src/tombase/settings/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomGetSettingsMessage` | class | Reflected request for client settings. |
| `TomGetSettingsResult` | class | Reflected settings response (texts, roles, …). |

### Shutdown Cleanup (`lib/src/tombase/shutdown_cleanup/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomShutdownCleanup` | class | Coordinates ordered shutdown on process signals. |
| `TomDisposable` | abstract class | `dispose()` contract. |
| `TomClosable` | abstract class | `close()` contract. |
| `TomCloseAdaptor` | class | Adapts a callback to `TomClosable`. |
| `TomSignalHandler` | typedef | `void Function(ProcessSignal)`. |
| `tomShutdownCleanup` | final | Shared shutdown coordinator. |

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
