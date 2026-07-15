# Tom Core Kernel API Reference: Logging Module

Isolate-aware and remote log delivery: log outputs that route messages from
worker isolates to a dedicated logging isolate or back to the creator isolate,
plus HTTP-based transmission of log messages to (and reception on) a central
logging server.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomLoggingExecutor](#tomloggingexecutor)
  - [TomInterIsolateLogMessage](#tominterisolatelogmessage)
  - [TomIsolateLogOutput](#tomisolatelogoutput)
  - [TomCreatorLogOutput](#tomcreatorlogoutput)
  - [TomLoggingWorkerContext](#tomloggingworkercontext)
  - [TomIsolateLogging](#tomisolatelogging)
  - [TomRemoteLogMessage](#tomremotelogmessage)
  - [TomRemoteLogResult](#tomremotelogresult)
  - [TomLoggingContext](#tomloggingcontext)
  - [TomRemoteLogOutput](#tomremotelogoutput)
  - [TomRemoteLogServer](#tomremotelogserver)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources:

- `lib/src/tombase/logging/logging_isolate.dart`
- `lib/src/tombase/logging/remote_logoutput.dart`
- `lib/src/tombase/logging/remote_logserver.dart`

The Logging module builds on the `TomLogLevel` / `TomLogOutput` primitives from
`tom_basics`. The isolate side lets the main isolate offload log processing to a
dedicated logging isolate pool (`TomIsolateLogOutput`, driven by
`TomLoggingExecutor` running in a `TomLoggingWorkerContext`), while worker
isolates route their log lines back to the creator isolate
(`TomCreatorLogOutput`); `TomInterIsolateLogMessage` is the cross-isolate
payload, and `TomIsolateLogging` is the setup facade. The remote side serializes
log entries as `TomRemoteLogMessage`, sends them over HTTP via
`TomRemoteLogOutput` (with re-entrancy protection through `TomLoggingContext`),
and reconstructs them on the server through `TomRemoteLogServer`, which replies
with a `TomRemoteLogResult`.

The log-level type (`TomLogLevel`) is defined in `tom_basics`, not in this
module.

## Class Hierarchy

```
TomExecutor  (tom_basics)
    └── TomLoggingExecutor

TomInterIsolateLogMessage

TomLogOutput  (tom_basics)
    ├── TomIsolateLogOutput
    ├── TomCreatorLogOutput
    └── TomRemoteLogOutput

TomWorkerContext  (isolate_pooling)
    └── TomLoggingWorkerContext

TomIsolateLogging

TomRemoteLogMessage

TomRemoteLogResult

TomLoggingContext

TomRemoteLogServer
```

## Classes

### TomLoggingExecutor

Executor that runs inside the dedicated logging isolate and outputs each
received `TomInterIsolateLogMessage` through the configured `TomLogOutput`.

- **Extends:** `TomExecutor`

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `execute` | `Object execute(Object command)` | *(override)* Outputs the log line when `command` is a `TomInterIsolateLogMessage`, returning `true`; otherwise returns `TomExecutor.noResult`. |

### TomInterIsolateLogMessage

Serializable container carrying a single log entry between isolates: timestamp,
logger/message levels, level string, message, isolate name, and optional origin.

#### Constructors

```dart
TomInterIsolateLogMessage(
  TomLogLevel loggerLevel,
  TomLogLevel logLevel,
  String level,
  String message,
  String isolateName,
  DateTime timeStamp,
  String? origin,
)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `timeStamp` | `DateTime` | When the log message was originally created. |
| `loggerLevel` | `TomLogLevel` | The logger's configured level at the time of logging. |
| `logLevel` | `TomLogLevel` | The level of this specific log message. |
| `level` | `String` | Human-readable level string (e.g. `"INFO   "`). |
| `message` | `String` | The log message content. |
| `isolateName` | `String` | Name of the isolate that generated the log. |
| `origin` | `String?` | Optional caller information (class.method). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Short representation combining isolate name, level, and message. |

### TomIsolateLogOutput

Log output that routes messages to a dedicated logging-isolate worker pool for
asynchronous (fire-and-forget) processing.

- **Extends:** `TomLogOutput`

#### Constructors

```dart
TomIsolateLogOutput(TomWorkerPool workerPool)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `workerPool` | `TomWorkerPool` | The worker pool that processes log messages. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `output` | `void output(TomLogLevel loggerLevel, TomLogLevel logLevel, String level, Object message, String isolateName, DateTime timeStamp, [String? origin])` | *(override)* Dispatches a `TomInterIsolateLogMessage` to the worker pool when `logLevel` matches `loggerLevel`; delivery is intentionally not awaited. |

### TomCreatorLogOutput

Log output used in worker isolates to send all log messages back to the creator
(main) isolate, falling back to console output when no creator connection is
available.

- **Extends:** `TomLogOutput`

#### Constructors

```dart
TomCreatorLogOutput()
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `fallbackOutput` | `TomConsoleLogOutput` | Console output used when the creator connection is unavailable. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `output` | `void output(TomLogLevel loggerLevel, TomLogLevel logLevel, String level, Object message, String isolateName, DateTime timeStamp, [String? origin])` | *(override)* Sends the message to the creator isolate when possible, otherwise writes it to `fallbackOutput`. |

### TomLoggingWorkerContext

Worker context for the logging isolate; installs a `TomLoggingExecutor` during
isolate initialization. Extend to customize the logging isolate's output.

- **Extends:** `TomWorkerContext`

#### Constructors

```dart
TomLoggingWorkerContext(
  TomEnvironment tomEnvironment,
  TomPlatform tomPlatform,
  List<String> args,
  String namePrefix,
)
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `initializeIsolate` | `Future<bool> initializeIsolate()` | *(override)* Registers a `TomLoggingExecutor` on the worker and returns `true`. |

### TomIsolateLogging

Utility facade for setting up isolate-based logging on both the main isolate and
worker isolates.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `startIsolatedLogging` | `static Future<bool> startIsolatedLogging(List<String> args, {int poolSize = 1, TomLoggingWorkerContext? workerContext})` | Creates a pool of logging workers and redirects `tomLog` output to them; returns `true` on success. |
| `startLoggingToCreator` | `static void startLoggingToCreator()` | Configures `tomLog` to route all messages to the creator isolate via `TomCreatorLogOutput`. |

### TomRemoteLogMessage

Serializable message format for transmitting a log entry to a remote logging
server over HTTP.

#### Constructors

```dart
TomRemoteLogMessage()

TomRemoteLogMessage.of(
  int loggerLevel,
  int logLevel,
  String level,
  String message,
  String isolateName,
  String timeStamp,
  String? origin,
)
```

The default constructor is used for deserialization; `.of` populates all fields
and copies `globalSettingSenderId` into `sender`.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `globalSettingSenderId` | `String` | Global sender identifier prepended to messages from this client (default `"RDEF"`). |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `sender` | `String` | The sender ID for this message (copied from `globalSettingSenderId`). |
| `timeStamp` | `String` | ISO 8601 timestamp of when the log was created. |
| `loggerLevel` | `int` | The logger's configured level as a bit pattern. |
| `logLevel` | `int` | This message's level as a bit pattern. |
| `level` | `String` | Human-readable level string. |
| `message` | `String` | The log message content. |
| `isolateName` | `String` | Name of the isolate that generated the log. |
| `origin` | `String?` | Optional caller information (class.method). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Short representation combining isolate name, level, and message. |

### TomRemoteLogResult

Response from the remote logging server, indicating whether processing
succeeded or failed.

#### Constructors

```dart
TomRemoteLogResult()

TomRemoteLogResult.withError(String errorMessage)
```

The default constructor represents success; `.withError` sets `hasError` and the
message.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `hasError` | `bool` | Whether an error occurred during log processing. |
| `errorMessage` | `String` | Error message when `hasError` is `true`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Short representation of the result. |

### TomLoggingContext

Zone-local context flag used internally by `TomRemoteLogOutput` to detect and
prevent recursive remote logging.

#### Constructors

```dart
TomLoggingContext({bool inRemoteLogging = false})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `inRemoteLogging` | `bool` | Whether execution is currently inside a remote logging operation. |

### TomRemoteLogOutput

Log output that transmits log messages over HTTP to a centralized logging
server, falling back to console output when the endpoint is unconfigured or
delivery fails.

- **Extends:** `TomLogOutput`

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `globalSettingFallbackOutput` | `TomLogOutput` | Fallback output used when remote logging fails or is unconfigured (console by default). |
| `remoteEndpoint` | `TomServerEndpoint<TomRemoteLogMessage, TomRemoteLogResult>?` | The configured remote endpoint; if `null`, all messages fall back to `globalSettingFallbackOutput`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `output` | `void output(TomLogLevel loggerLevel, TomLogLevel logLevel, String level, Object message, String isolateName, DateTime timeStamp, [String? origin])` | *(override)* Sends the message to `remoteEndpoint` inside a re-entrancy-guarded zone; on failure or missing endpoint writes to the fallback output. |

### TomRemoteLogServer

Server-side handler that receives `TomRemoteLogMessage` objects from clients,
sanitizes their fields, and writes them through the configured local output,
prefixing the isolate name with the sender ID.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `localOutput` | `TomLogOutput` | Destination for received log messages (defaults to `tomLog.logOutput` at initialization). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `receive` | `TomRemoteLogResult receive(TomRemoteLogMessage m)` | Reconstructs the log entry from `m`, sanitizes control characters and bounds field length (CWE-117 hardening), outputs it via `localOutput`, and returns a success or error `TomRemoteLogResult`. |

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
