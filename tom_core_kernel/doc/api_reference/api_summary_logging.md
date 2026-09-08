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
  - [TomLogReplayStore](#tomlogreplaystore)
  - [TomInMemoryLogReplayStore](#tominmemorylogreplaystore)
  - [TomFileLogReplayStore](#tomfilelogreplaystore)
  - [TomRemoteLogOutput](#tomremotelogoutput)
  - [TomRemoteLogServer](#tomremotelogserver)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources:

- `lib/src/tombase/logging/logging_isolate.dart`
- `lib/src/tombase/logging/remote_logoutput.dart`
- `lib/src/tombase/logging/file_log_replay_store.dart`
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
with a `TomRemoteLogResult`. Records that fail every send attempt are buffered
in a bounded replay queue whose storage is pluggable through
`TomLogReplayStore` — in memory by default (`TomInMemoryLogReplayStore`), or
mirrored to disk (`TomFileLogReplayStore`) so the buffer survives a process
restart during an endpoint outage.

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

TomLogReplayStore  (abstract interface)
    ├── TomInMemoryLogReplayStore
    └── TomFileLogReplayStore

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
| `fallbackOutput` | `TomLogOutput` | Sink used when the creator connection is unavailable. Any output may be installed; defaults to a `TomConsoleLogOutput`. |

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
| `initializeIsolate` | `Future<void> initializeIsolate()` | *(override)* Registers a `TomLoggingExecutor` on the worker. Completing normally is the success signal; a failing override reports by throwing. |

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
and asks `globalSettingSenderIdResolver` for `sender`.

The type is `@tomReflector`-annotated and has no `fromJson`/`toJson` of its own:
both directions go through `tomReflectionInfo.convertToJsonString` and
`tomReflectionInfo.convertFromJsonString(TomRemoteLogMessage(), body)`, which is
why an empty instance is what deserialization starts from. `TomServerEndpoint`
takes that same route internally, so a collector decoding this way agrees with
the sender by construction.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `globalSettingSenderIdResolver` | `String Function()` | Answers which application sent a record, asked once per message. A function rather than a value because a name is often not settled when the resolver is installed — a `tom_core_server` deployment names itself in its configuration subclass constructor, which runs after the base constructor that installs. Defaults to `() => ""`. |
| `globalSettingSenderId` | `String` | The same answer as a value: reading asks the resolver, assigning installs one that answers the given constant forever. The right form for a client whose name is a constant, the wrong one for a name not yet settled. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `sender` | `String` | The sender this message reports, from `globalSettingSenderIdResolver` at construction. Empty when nothing named the application, which the collector reads as "file this under the isolate alone". |
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

### TomLogReplayStore

Pluggable storage behind `TomRemoteLogOutput`'s replay queue. Implementations
own ordering: records must be returned in the order they were appended (FIFO),
and overflow drops from the head.

- **Kind:** `abstract interface class`

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `length` | `int get length` | Number of records currently buffered. |
| `append` | `void append(TomRemoteLogMessage message)` | Appends a record to the tail of the queue. |
| `snapshot` | `List<TomRemoteLogMessage> snapshot()` | Returns a copy of all buffered records in arrival order. |
| `oldest` | `TomRemoteLogMessage? get oldest` | The oldest buffered record, or `null` when empty. |
| `removeOldest` | `void removeOldest()` | Removes the oldest record; a no-op when empty. |
| `trim` | `void trim(int maxSize)` | Drops the oldest records until at most `maxSize` remain; a non-positive size clears the queue. |
| `clear` | `void clear()` | Discards every buffered record. |

### TomInMemoryLogReplayStore

In-memory `TomLogReplayStore` — the zero-config default. Buffered records live
in a plain list and are lost if the process exits while the queue is non-empty.

- **Implements:** `TomLogReplayStore`

#### Constructors

```dart
TomInMemoryLogReplayStore()
```

### TomFileLogReplayStore

File-backed `TomLogReplayStore` for durable replay buffering. The file is the
queue: every operation re-reads it and every mutation rewrites it (flushed to
disk before returning), so the buffer survives a process restart during an
endpoint outage. Each write goes to a sibling temp file that is renamed into
place, so a process killed mid-write leaves either the previous queue or the new
one, never a half-written array. Requires `dart:io` and is therefore not
available on the web.

Two owners may share one path — a worker isolate and the isolate that spawned
it, or a restarted process overlapping with the one it replaces. Every operation
runs while holding a sibling lock file (`<path>.lock`), which makes a mutation a
read-modify-write of the current file rather than a rewrite from a stale
snapshot. Reads are guarded for the same reason: an owner answering `oldest` from
a private copy while another rewrites the file would let a drain loop delete a
record it had never sent. A lock left behind by a killed owner is broken once it
has stood unchanged for ten seconds, and that recovery is reported through
`TomRemoteLogOutput.globalSettingFallbackOutput`. Sharing does not buy
exactly-once delivery — two owners draining concurrently can both send the same
record — because a duplicated log record is a nuisance and a lost one is the
failure this store exists to prevent.

- **Implements:** `TomLogReplayStore`

#### Constructors

```dart
TomFileLogReplayStore(String path)
```

Creates a store backed by `path`, loading any previously persisted records.
Parent directories are created on the first write. A missing or empty file
yields an empty queue and is not treated as damage.

Never throws because of the file's content — the store is normally constructed
during startup, so throwing would let a past crash prevent the next start. A
file that cannot be read (invalid JSON, a truncated array, a non-list top
level, unreadable bytes) is handled by salvaging whatever records are readable,
moving the previous content aside to `<path>.corrupt` so it survives for
diagnosis instead of being overwritten, and reporting the loss through
`TomRemoteLogOutput.globalSettingFallbackOutput` as a single-line warning
naming the path, the cause and the number of dropped entries.

A well-formed array with unusable entries keeps its usable records, so partial
damage does not present as an empty queue. Anything the decoder cannot parse at
all yields an empty queue — JSON parses all-or-nothing, so a half-written array
has no readable prefix. That is the case a crash produces, and it is prevented
by the atomic write rather than repaired by the load.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `file` | `File` | *(final)* The file the queue is mirrored to and reloaded from. |

### TomRemoteLogOutput

Log output that transmits log messages over HTTP to a centralized logging
server, falling back to console output when the endpoint is unconfigured or
delivery fails.

- **Extends:** `TomLogOutput`

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `globalSettingFallbackOutput` | `TomLogOutput` | Fallback output used when remote logging fails or is unconfigured (console by default). Being the last sink in the chain, a throw here loses the record — but never silently: the failure is announced on `TomPlatformUtils.outError`, once per installed output, and assigning a new output re-arms that report. The throw itself never reaches the caller. |
| `remoteEndpoint` | `TomServerEndpoint<TomRemoteLogMessage, TomRemoteLogResult>?` | The configured remote endpoint; if `null`, all messages fall back to `globalSettingFallbackOutput`. |
| `globalSettingMaxSendRetries` | `int` | Number of *additional* send attempts after the first fails (`0` = single attempt, the default). |
| `globalSettingRetryBackoff` | `Duration` | Base delay between retries; the wait before retry *k* is `backoff × k` (`Duration.zero` by default = retry immediately). |
| `globalSettingReplayQueueMaxSize` | `int` | Maximum records held in the replay queue; `0` (default) disables buffering, drop-oldest on overflow otherwise. |
| `globalSettingReplayStore` | `TomLogReplayStore` | Storage backing the replay queue (defaults to `TomInMemoryLogReplayStore`); assign `TomFileLogReplayStore` for durability across a restart. Shared across instances. |
| `replayQueueLength` | `int` | *(read-only)* Number of records currently buffered for replay. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `clearReplayQueue` | `void clearReplayQueue()` | Discards every buffered record — use when reconfiguring `remoteEndpoint` so records queued for a previous endpoint are not replayed to the new one. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `output` | `void output(TomLogLevel loggerLevel, TomLogLevel logLevel, String level, Object message, String isolateName, DateTime timeStamp, [String? origin])` | *(override)* Sends the message to `remoteEndpoint` inside a re-entrancy-guarded zone. A send fails when the endpoint is unreachable, when the server returns an error, or when the send throws — the warning accompanying the record names which. "Returns an error" covers both channels: a transport-level `TomServerCallError` *and* an application-level `TomRemoteLogResult.hasError` carried in the body of an HTTP 200, whose `errorMessage` is reproduced in the warning. On failure it retries up to `globalSettingMaxSendRetries` times (with `globalSettingRetryBackoff × attempt` backoff), then writes the record to the fallback output and — if enabled — buffers it in the bounded replay queue. Each send first drains any buffered records oldest-first so records recover in order after an outage. Deliveries are serialised in call order within the isolate, so overlapping calls neither re-send a record another drain has in flight nor arrive out of order. A fallback that throws cannot escape this method — the loss is reported on `TomPlatformUtils.outError` instead (see `globalSettingFallbackOutput`). |

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
| `receive` | `TomRemoteLogResult receive(TomRemoteLogMessage m)` | Reconstructs the log entry from `m`, strips control characters and caps each field at 8192 UTF-16 code units — a cut field ends in `…[truncated]` inside that cap (CWE-117 hardening) — outputs it via `localOutput`, and returns a success or error `TomRemoteLogResult`. On failure the caught error is folded into `errorMessage` and the refusal is also logged locally at error level. |

The cap is per field, so the bound on one `receive` call is four times it, over
the four sanitized fields; the number of calls is the transport's concern, not
this class's. See `doc/logging/logging.md` § "What the collector does to an
untrusted record".

`receive` takes an already-decoded message and returns an object, so moving
either across the wire is the HTTP handler's job — see `TomRemoteLogMessage`
above for the `tomReflectionInfo` route both directions use, and step 4 of
`example/samples/logging/05_isolate_and_remote_logging_example.dart` for the
round-trip running end to end.

Two independent things can make `receive` refuse a record: the message can be
undecodable (a malformed `timeStamp`), or `localOutput` can be broken. The
returned `errorMessage` names which, because the caller is a remote process
with nothing else to inspect — `TomRemoteLogOutput` reproduces it verbatim in
the warning it writes beside the fallback record, so the reason survives all
the way to the client's own log. The refusal is logged locally too, otherwise
it is visible only to that client and the collector's operator just sees a
record never arrive.

That local diagnostic is emitted at `TomLogLevel.error` against
`TomLogLevel.errors`, deliberately *not* against the `loggerLevel` carried in
the message: that field is client-supplied and defaults to `0` (log nothing),
so honouring it would let a malformed message suppress the record of its own
rejection. Reporting is itself failure-tolerant — when the broken sink is the
cause, writing the diagnostic throws again, and that second failure is
swallowed rather than allowed to escape into the collector's HTTP handler.

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
