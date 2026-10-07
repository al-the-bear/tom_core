# TomBase Logging System

A flexible, configurable logging framework for Dart applications with support for multiple log levels, custom outputs, isolate-based logging, and remote log collection.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
  - [Basic Usage](#basic-usage)
  - [Configure Log Level](#configure-log-level)
- [Core Components](#core-components)
  - [TomLogLevel](#tomloglevel)
  - [TomLogger](#tomlogger)
  - [TomLogOutput](#tomlogoutput)
- [Usage Examples](#usage-examples)
  - [Application Startup](#application-startup)
  - [Remote Logging](#remote-logging)
  - [Multi-Isolate Logging](#multi-isolate-logging)
    - [When the creator channel is absent](#when-the-creator-channel-is-absent)
  - [Custom Loggable Objects](#custom-loggable-objects)
  - [Delayed/Function Logging](#delayedfunction-logging)
- [Best Practices](#best-practices)
  - [1. Use Appropriate Log Levels](#1-use-appropriate-log-levels)
  - [2. Use Lazy Evaluation for Expensive Messages](#2-use-lazy-evaluation-for-expensive-messages)
  - [3. Configure Levels Per Environment](#3-configure-levels-per-environment)
  - [4. Use Status for Important Lifecycle Events](#4-use-status-for-important-lifecycle-events)
  - [5. Disable Stack Analysis in Production](#5-disable-stack-analysis-in-production)
- [What the module throws](#what-the-module-throws)
- [Configuration Reference](#configuration-reference)
  - [Logger Settings](#logger-settings)
  - [Console Output Settings](#console-output-settings)
  - [Remote Logging Settings](#remote-logging-settings)
  - [Collector and Isolate Settings](#collector-and-isolate-settings)
- [File Structure](#file-structure)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
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

The TomBase logging system provides:

- **Multiple Log Levels**: From trace (most verbose) to fatal (most severe)
- **Bitwise Level Composition**: Combine or exclude levels using `+` and `-` operators
- **Per-Class/Method Customization**: Set different log levels for specific code locations
- **Pluggable Outputs**: Console, remote server, isolate-based, or custom implementations
- **Multi-Isolate Support**: Centralized logging across all application isolates
- **Remote Logging**: Send logs to a centralized server for analysis

## Quick Start

### Basic Usage

```dart complete
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // Use the global logger instance
  tomLog.info('Application started');
  tomLog.debug('Debug information');
  tomLog.error('Something went wrong');
  tomLog.warn('This might be a problem');
}
```

### Configure Log Level

```dart
// Set to development mode (most verbose)
tomLog.setLogLevel(TomLogLevel.development);

// Set to production mode (info, warn, errors, status)
tomLog.setLogLevel(TomLogLevel.production);

// Set by name (useful for config files)
tomLog.setLogLevelByName('DEVELOPMENT');
```

## Core Components

### TomLogLevel

Represents logging levels as bit patterns, enabling flexible level composition.

#### Individual Levels (in order of verbosity)

| Level     | Description                          |
|-----------|--------------------------------------|
| `trace`   | Most verbose, detailed tracing       |
| `debug`   | Debug information                    |
| `traffic` | Network/data traffic logging         |
| `info`    | General informational messages       |
| `warn`    | Warning messages                     |
| `status`  | Important status updates             |
| `error`   | Error conditions                     |
| `severe`  | Severe errors                        |
| `fatal`   | Fatal errors causing termination     |

#### Compound Levels

| Level         | Includes                           |
|---------------|-------------------------------------|
| `development` | All levels including trace          |
| `extended`    | production + debug + traffic        |
| `production`  | info, warn, errors, status          |
| `still`       | warn + errors + status              |
| `silent`      | errors + status only                |
| `off`         | No logging                          |

#### Level Composition

```dart
// Combine levels
var myLevel = TomLogLevel.info + TomLogLevel.error;

// Remove a level
var quieter = TomLogLevel.production - TomLogLevel.info;

// Check if a level matches
if (currentLevel.matches(TomLogLevel.debug)) {
  // This level is included
}
```

### TomLogger

The main logger class providing structured logging capabilities.

#### Logging Methods

```dart
tomLog.trace('Entering function processData');    // Most verbose
tomLog.debug('Variable x = $x');                   // Debug info
tomLog.traffic('HTTP GET /api/users');             // Network traffic
tomLog.info('Server started on port 8080');        // General info
tomLog.warn('Config file not found, using defaults');
tomLog.status('Database migration complete');      // Status updates
tomLog.error('Failed to connect to database');     // Errors
tomLog.severe('Critical subsystem failure');       // Severe errors
tomLog.fatal('Unrecoverable error, shutting down'); // Fatal errors
```

#### Temporary Level Changes

```dart
// Temporarily increase verbosity for debugging
tomLog.pushLogLevel(TomLogLevel.trace);
debugComplexOperation();
tomLog.popLogLevel(); // Restore previous level
```

#### Per-Class/Method Levels

```dart
// Set level for a specific class
tomLog.addNameLevel('DatabaseService', TomLogLevel.trace);

// Set level for a specific method
tomLog.addNameLevel('ApiClient.sendRequest', TomLogLevel.debug);

// Remove custom level
tomLog.removeNameLevel('DatabaseService');

// Bulk configuration from string pattern
tomLog.setLogLevelExceptions('MyClass=DEBUG,ApiClient=TRACE');
```

### TomLogOutput

Abstract base class for log output implementations.

#### Built-in Implementations

- **TomConsoleLogOutput**: Outputs to stdout/stderr (default)
- **TomRemoteLogOutput**: Sends logs to a remote server
- **TomIsolateLogOutput**: Routes logs through a dedicated logging isolate
- **TomCreatorLogOutput**: Routes worker isolate logs to main isolate

#### Custom Output

```dart
class FileLogOutput extends TomLogOutput {
  final File logFile;
  
  FileLogOutput(this.logFile);
  
  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) {
    if (logLevel.matches(loggerLevel)) {
      logFile.writeAsStringSync(
        '$timeStamp $level ${convertToString(message)}\n',
        mode: FileMode.append,
      );
    }
  }
}

// Use custom output
tomLog.logOutput = FileLogOutput(File('app.log'));
```

## Usage Examples

### Application Startup

```dart
void main() async {
  // Configure logging based on environment
  if (isProduction) {
    tomLog.setLogLevel(TomLogLevel.production);
  } else {
    tomLog.setLogLevel(TomLogLevel.development);
  }
  
  tomLog.status('Application starting...');
  
  try {
    await initializeApp();
    tomLog.info('Application initialized successfully');
  } catch (e) {
    tomLog.fatal('Failed to initialize: $e');
    exit(1);
  }
}
```

### Remote Logging

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

void setupRemoteLogging() {
  // Configure sender identification. The value form installs a resolver that
  // answers this constant forever, which is right for a client whose name is
  // known at this line. Where the name is not settled yet — a server that names
  // itself in a constructor body that has not run — install the resolver
  // instead: `globalSettingSenderIdResolver = () => tomAppId;`. A consumer of
  // `tom_core_server` installs nothing: its configuration does this already.
  TomRemoteLogMessage.globalSettingSenderId = 'frontend-01';

  // Set up the remote endpoint. `TomServerEndpoint` takes a channel (host and
  // port) and call specs (method and full URL). Building it opens no
  // connection — the channel creates its HTTP client on the first call.
  TomRemoteLogOutput.remoteEndpoint =
      TomServerEndpoint<TomRemoteLogMessage, TomRemoteLogResult>(
        TomServerChannel('logs.example.com', 443),
        TomServerCallSpecs(
          'POST',
          Uri.parse('https://logs.example.com/api/logs'),
        ),
      );

  // Activate remote logging
  tomLog.logOutput = TomRemoteLogOutput();
}
```

On the collecting side, `TomRemoteLogMessage` and `TomRemoteLogResult` carry no
`fromJson`/`toJson` of their own. Both are `@tomReflector` types, so a collector
serialises through `tomReflectionInfo` — the same route `TomServerEndpoint.send`
takes on the client, which is what makes the two agree by construction:

```dart
final logServer = TomRemoteLogServer();
// Leave `localOutput` unset and the collector writes to whatever
// `tomLog.logOutput` is when each record arrives. Assign it to send received
// records somewhere else instead:
TomRemoteLogServer.localOutput = TomConsoleLogOutput();

router.post('/remotelog', (request) async {
  final message = tomReflectionInfo.convertFromJsonString(
    TomRemoteLogMessage(),
    await request.readAsString(),
  );
  final result = logServer.receive(message);
  return Response.ok(tomReflectionInfo.convertToJsonString(result));
});
```

Everything above that touches a Tom type is copied from steps 3 and 4 of
`example/samples/logging/05_isolate_and_remote_logging_example.dart`, where it
is compiled, analyzed and asserted. Only the routing (`router.post`,
`Response.ok`) is illustrative, since that belongs to whichever HTTP framework
the collector is built on. Change the Tom half there and copy it out: a
document, unlike an example, cannot fail to build.

##### What the collector does to an untrusted record

Every field of a received message is controlled by whoever sent it, and
`receive` reconstructs those fields into the collector's *own* log stream. Two
things are done to each field before it reaches the collector's sink.

**Control characters are removed** — the C0 range (`0x00`–`0x1F`, which is
CR, LF, TAB and ESC) and the C1 range (`0x7F`–`0x9F`). Left in, a CR/LF lets a
client forge extra log lines and an ESC lets it inject terminal escape
sequences into a console reading the log: CWE-117, improper output
neutralization for logs.

**Length is capped** at 8192 UTF-16 code units per field, so one oversized
field cannot exhaust the sink. A field that is cut ends in `…[truncated]`,
inside the cap rather than past it — a silently shortened record reads as a
complete one, and the reader could not otherwise tell a client that sent 8 KB
from one that sent 8 MB. Only length truncation is marked; dropping a control
character does not shorten what the field says.

The cap is per field. A record's bound follows from it — four sanitized fields,
so at most four times the cap per `receive` call — and that is the intended
protection: a second, whole-record budget would have to decide which field to
sacrifice when a record is collectively too large, and no rule makes that choice
better than the per-field one does. How *many* records a client may send is not
bounded here at all; that belongs to the transport, and a collector endpoint
should sit behind the same authentication and rate limiting as any other write
endpoint.

##### When the collector refuses a record

Two independent things can make `receive` refuse: the message can be undecodable
(a malformed `timeStamp`), or the collector's sink can be broken. The returned
`errorMessage` names which — the caller is a remote process with nothing else to
inspect, and the client reproduces that text verbatim in the warning it writes
beside the fallback record, so the reason reaches the client's own log.

The refusal is logged on the collector as well, at error level; without that it
would be visible only to the client that caused it, and the operator would just
see a record never arrive. That diagnostic is deliberately *not* gated by the
`loggerLevel` carried in the message — a client-supplied field that defaults to
"log nothing", which would otherwise let a malformed message suppress the record
of its own rejection.

Both the returned reason and the logged one are sanitized, for the same reason
the message fields are: the error text is derived from client input.
`FormatException` embeds the offending string verbatim after a newline, so
reporting it raw would reopen the CWE-117 log-forging hole using the rejection
path as the carrier.

#### Delivery Resilience

By default `TomRemoteLogOutput` makes a single delivery attempt and, on failure,
writes the record to its fallback output (console) so nothing is lost. A send is
treated as failed whenever it does not reach a server that accepted it: the
endpoint was *unreachable*, the server *returned* an error result, or the send
*threw*. The warning written alongside the record names which one it was — an
unreachable endpoint is reported as `server unreachable` with the underlying
exception, never as a rejection.

"Returned an error result" covers both channels the endpoint reports on, since
the record is equally lost either way: a transport-level `TomServerCallError`
(a non-2xx status, an internal error) *and* an application-level refusal in the
response body (`TomRemoteLogResult.hasError`) delivered over a perfectly
successful HTTP 200 — which is how a healthy collector says "received, not
stored". The server's own `errorMessage` is reproduced in the warning, so the
operator reads the reason and not merely the refusal.

##### When the fallback itself fails

The fallback is the last sink in the chain, so a fallback that throws — a full
disk for a file sink, a closed port, a misconfigured custom output — means the
record is lost. Nothing can be done about that. What *can* be done is to say so:
the failure is announced on `TomPlatformUtils.outError`, which sits below the
logging stack and so cannot be broken by the same misconfiguration. The report
carries the lost record and the fallback's own error.

Two properties matter for reading these reports:

- **The throw never reaches the caller.** A logging sink must not take down the
  application, and that holds for the sink of last resort too.
- **The report is written once per installed fallback.** A broken fallback is
  normally broken for every record, so reporting per record would produce
  exactly the flood the fallback exists to prevent. Assigning a new
  `globalSettingFallbackOutput` re-arms the report — the old output's
  brokenness says nothing about its replacement.

A fallback that refuses only *one* record — an over-long line, a message whose
`toString` throws — is a different fault and is handled differently: since the
sink is alive, the refusal is reported *through it*, once per affected record.

For flaky links you can opt into retry-with-backoff and a
bounded replay queue that drains, oldest-first, once the endpoint recovers:

```dart
// Retry each record up to 3 more times, waiting 200ms × attempt between tries.
TomRemoteLogOutput.globalSettingMaxSendRetries = 3;
TomRemoteLogOutput.globalSettingRetryBackoff = const Duration(milliseconds: 200);

// Buffer up to 500 records that still fail; the oldest is dropped on overflow.
TomRemoteLogOutput.globalSettingReplayQueueMaxSize = 500;

// When switching endpoints, discard records queued for the old one.
TomRemoteLogOutput.clearReplayQueue();
```

**A negative value on any of the three reads as zero, and `-1` does not mean
"unlimited".** Plenty of buffering APIs use `-1` that way, so it is a plausible
way to try to say "never drop anything" — and here it says the opposite:
buffering off, every record that exhausts its retries dropped after the fallback
write. A negative retry count is one attempt, and a negative backoff waits no
time without skipping a retry.

There is no unbounded setting, deliberately. A queue that grows without limit
while an endpoint is down is the failure this one exists to prevent, and the
records it would hold are already safe in the fallback output. To buffer a lot,
name a large number.

The defaults (no retries, no backoff, no replay queue) keep behaviour
predictable and testable without a live server.

Records reach the endpoint one at a time, in the order `output` was called.
This matters because `output` returns before its record has been sent, so
back-to-back log lines overlap by default; without serialisation each of them
would run its own drain over the same replay queue and re-send records another
drain had read but not yet removed. The guarantee covers one isolate — the same
scope as the queue it protects, since both are statics.

#### Waiting before the process exits

`output` returns before its record has been sent. That is deliberate — a
logging call must never block the code that made it — but it means a process
that exits straight after logging loses whatever was in flight, and whatever an
earlier outage left buffered. `flush` is the supported way to wait:

```dart
Future<void> shutdown() async {
  // ... stop the code that logs first, then:
  await TomRemoteLogOutput.flush();
}
```

It settles every record handed to `output` **before the call**, then gives the
replay queue a chance to drain — which is the only way to empty the queue with
nothing left to log, since a drain otherwise happens only as a side effect of
sending the next record.

Four things it deliberately is not:

- **Not a per-record await.** `output` stays fire-and-forget. A sink a caller
  can await per record invites exactly the coupling this one exists to avoid.
- **Not a promise of delivery.** A record the endpoint still refuses stays
  buffered, which is what the replay queue is for. The promise is only that
  nothing is left half-done.
- **Not a moving target.** A record logged *while* the flush runs appends
  behind it and is not waited for. Waiting for those too would mean re-reading
  the lane until it stopped moving, which in a process that never stops logging
  never returns. Call it after the code that logs has stopped — and again if
  that was not true.
- **Not a way around the delivery lane.** The drain takes a lane slot exactly
  as a record does, so it cannot overlap a delivery in flight, and it runs in
  the same re-entrancy-guarded zone, so a line the HTTP client writes on its
  way out does not become another remote record.

The queue's *storage* is pluggable through `TomLogReplayStore`. The default
(`TomInMemoryLogReplayStore`) keeps records in memory, so they are lost if the
process exits mid-outage. Point the store at a file to make the buffer durable —
constructing it reloads whatever the previous process left behind:

```dart
TomRemoteLogOutput.globalSettingReplayStore =
    TomFileLogReplayStore('/var/lib/myservice/log_replay.json');
```

`TomFileLogReplayStore` mirrors the queue to a JSON file on every mutation and
requires `dart:io`, so it is not available on the web. Implement
`TomLogReplayStore` yourself to back the queue with anything else that preserves
arrival order.

Each mutation is written to a sibling temp file and renamed into place, so a
process killed mid-write leaves either the previous queue or the new one, never
a half-written array.

Two owners may point at the same path — a worker isolate and the isolate that
spawned it, or a restarted process overlapping with the one it replaces. Every
operation re-reads the file and every mutation runs while holding a sibling lock
file (`<path>.lock`), so a change applies to what is on disk now rather than to
whatever this owner last saw. Reads cost a file read for the same reason: an
owner reporting a private count would let `oldest` and `removeOldest` disagree
about which record is next. A lock left behind by a killed owner is broken once
it has stood unchanged for ten seconds, and the recovery is reported through
`globalSettingFallbackOutput` — that writer died inside a mutation, so its last
change may not have landed.

What sharing does *not* buy is exactly-once delivery: two owners draining at the
same time can both read the same oldest record and both send it. A duplicated log
record is a nuisance; a lost one is the failure the durable store exists to
prevent.

Constructing the store never throws because of the file's content. That matters
because the store is normally wired up during startup: a constructor that threw
on a damaged file would let a past crash prevent the next start, so the durable
buffer would take down the process it exists to protect. A file that cannot be
read is instead handled by

- salvaging whatever records are readable;
- moving the previous content aside to `<path>.corrupt`, so it is preserved for
  diagnosis instead of being overwritten by the next write; and
- reporting the loss through `globalSettingFallbackOutput` — a single-line
  warning naming the path, what went wrong, and how many entries were dropped.

How much can be salvaged depends on where the damage is, and the two cases are
worth telling apart:

| On-disk state | Result |
| ------------- | ------ |
| A well-formed array with unusable entries among the records | The usable records are kept and only the bad entries are dropped, so partial damage does not present as an empty queue |
| Anything JSON cannot parse — a truncated array, unreadable bytes, a non-list top level | An empty queue. JSON parses all-or-nothing, so a half-written array has no readable prefix to recover |

The second row is the shape a crash actually produces, which is why writes are
atomic: preventing the truncation is the only thing that saves those records,
because recovery cannot.

An empty or missing file is not damage: it loads as an empty queue and is not
reported. The `<path>.corrupt` file holds only the most recent damaged content;
a later corruption replaces it.

### Multi-Isolate Logging

```dart complete
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main(List<String> args) async {
  // Main isolate: Start isolated logging
  await TomIsolateLogging.startIsolatedLogging(args);

  // All logs now route through the logging isolate
  tomLog.info('This goes through the logging isolate');
}

// In worker isolate initialization
void initWorker() {
  // Route logs back to main isolate
  TomIsolateLogging.startLoggingToCreator();
  tomLog.info('Worker started');
}
```

#### Where the logging isolate writes

`startIsolatedLogging` returns nothing. Completing is the success signal —
the pool is either spawned and installed, or the call throws on the way — so
there is no result to branch on.

`startIsolatedLogging` replaces the *main* isolate's output with a
`TomIsolateLogOutput` that forwards every record to the pool. The record is
finally written by `TomLoggingExecutor` in the spawned isolate, through *that*
isolate's `tomLog.logOutput`. Dart statics are per-isolate, so assigning
`tomLog.logOutput` in `main` cannot change where the logging isolate writes — it
only changes what the main isolate does before forwarding.

The place that can is `initializeIsolate`, which runs inside the spawned
isolate. Subclass `TomLoggingWorkerContext` and pass the subclass to
`startIsolatedLogging`:

```dart
class CustomLoggingContext extends TomLoggingWorkerContext {
  CustomLoggingContext(
    super.tomEnvironment,
    super.tomPlatform,
    super.args,
    super.namePrefix,
  );

  @override
  Future<void> initializeIsolate() async {
    // Registers TomLoggingExecutor. Skip the super call and the isolate has
    // no handler for the records the pool sends it, and drops every one.
    await super.initializeIsolate();
    tomLog.logOutput = TomRemoteLogOutput();
  }
}

await TomIsolateLogging.startIsolatedLogging(
  args,
  workerContext: CustomLoggingContext(
    TomRuntime.getCurrentEnvironment(),
    TomRuntime.getCurrentPlatform()!,
    args,
    'L',
  ),
);
```

The four positional arguments are required: `TomWorkerContext` has no
zero-argument constructor for a subclass to inherit. The class is compiled and
run as `CustomLoggingContext` in
`example/samples/logging/05_isolate_and_remote_logging_example.dart`.

#### When the creator channel is absent

`TomCreatorLogOutput` sends to the creator isolate only when there is one to
send to; `TomWorker.canSendToCreator()` is false in the main isolate and in any
worker started without a back-channel. Everything else goes to
`TomCreatorLogOutput.fallbackOutput`.

That slot is a `TomLogOutput`, so any sink can be installed there — a remote
collector, a capture in a test, an application's own sink — and the whole
record is handed on, not just the message text. It defaults to a
`TomConsoleLogOutput`, so an application that never touches it behaves as
before. The type matters because a worker that has lost its creator is the case
where its records are least likely to be watched on a console, which is exactly
when sending them somewhere else is worth doing:

```dart
// Ship the records a lost creator would have collected to the log server
// instead. TomRemoteLogOutput buffers and replays across an outage, so this
// survives the collector being down as well.
TomCreatorLogOutput.fallbackOutput = TomRemoteLogOutput();
```

The level gate is applied before the fallback is consulted, so a record filtered
out by the active logger level never reaches it.

### Custom Loggable Objects

```dart
class User implements TomLoggable {
  final String id;
  final String name;
  final String email;
  
  User(this.id, this.name, this.email);
  
  @override
  String get logRepresentation => 'User($id, $name)';
}

// Usage
final user = User('123', 'John', 'john@example.com');
tomLog.info(user); // Logs: "User(123, John)"
```

### Delayed/Function Logging

```dart
class User implements TomLoggable {
  final String id;
  final String name;
  final String email;
  
  User(this.id, this.name, this.email);
  
  @override
  String get logRepresentation => 'User($id, $name)';
}

// Usage
final user = User('123', 'John', 'john@example.com');

tomLog.trace(() => 'Created user: $user'); // Will only be executed if the log level includes TRACE

```

## Best Practices

### 1. Use Appropriate Log Levels

```dart
// ✓ Good
tomLog.trace('Entering processItems with ${items.length} items');
tomLog.debug('Processing item: ${item.id}');
tomLog.info('Processed ${count} items successfully');
tomLog.warn('Item ${id} has missing optional field');
tomLog.error('Failed to process item ${id}: $error');

// ✗ Avoid
tomLog.info('Debug: x = $x');  // Use debug() for debug info
tomLog.error('Warning: ...');   // Use warn() for warnings
```

### 2. Use Lazy Evaluation for Expensive Messages

```dart
// ✓ Good - message only constructed if debug is enabled
tomLog.debug(() => 'Complex object: ${expensiveToString(obj)}');

// ✗ Avoid - always constructs the string
tomLog.debug('Complex object: ${expensiveToString(obj)}');
```

### 3. Configure Levels Per Environment

```dart
void configureLogging(Environment env) {
  switch (env) {
    case Environment.development:
      tomLog.setLogLevel(TomLogLevel.development);
      break;
    case Environment.staging:
      tomLog.setLogLevel(TomLogLevel.extended);
      break;
    case Environment.production:
      tomLog.setLogLevel(TomLogLevel.production);
      break;
  }
}
```

### 4. Use Status for Important Lifecycle Events

```dart
tomLog.status('Server starting on port $port');
tomLog.status('Database connected');
tomLog.status('Shutting down gracefully');
```

### 5. Disable Stack Analysis in Production

```dart
// Improves performance in high-volume logging
if (isProduction) {
  TomLogger.globalSettingDetermineCaller = false;
}
```

## What the module throws

One failure, and it is a startup-ordering mistake rather than a condition to
recover from — which is why it is raised rather than reported through a return
value a caller would ignore.

| Type | Error key | Raised when |
| ---- | --------- | ----------- |
| `TomException` | `logging.isolate.runtime_not_initialized` | `TomIsolateLogging.startIsolatedLogging` was called without a `workerContext` and the runtime platform has not been registered, so the default worker context cannot be built. Register it during application startup — normally `TomRuntime.setCurrentPlatform(...)` — or pass a context of your own. |

Delivery failures are not in this table and never throw. A record the remote
endpoint refuses is written to the fallback output and, if the replay queue is
enabled, buffered — see *Delivery Resilience*. A logging sink that threw at its
caller would take down the code it was reporting on.

## Configuration Reference

Every setting below is a static field, so it is per-isolate and global within
that isolate. These tables are the complete set for the logger and for the
sinks this module supplies — twenty-one settings, matching the declarations in
`tom_basics/lib/src/logging/logging.dart` and
`lib/src/tombase/logging/*.dart`. Completeness is worth stating because it is
re-checkable: extract the settable statics from those files and confirm each
appears here.

### Logger Settings

Declared by `TomLogger` in `tom_basics`.

| Setting                                  | Default | Description                 |
|------------------------------------------|---------|-----------------------------|
| `TomLogger.globalSettingDetermineCaller` | `true`  | Enable stack trace analysis |
| `TomLogger.globalSettingTraceEnabled`    | `true`  | Global toggle, trace level  |
| `TomLogger.globalSettingDebugEnabled`    | `true`  | Global toggle, debug level  |
| `TomLogger.globalSettingTrafficEnabled`  | `true`  | Global toggle, traffic level |
| `TomLogger.globalSettingInfoEnabled`     | `true`  | Global toggle, info level   |
| `TomLogger.globalSettingStatusEnabled`   | `true`  | Global toggle, status level |
| `TomLogger.globalSettingWarnEnabled`     | `true`  | Global toggle, warn level   |
| `TomLogger.globalSettingErrorEnabled`    | `true`  | Global toggle, error level  |
| `TomLogger.globalSettingSevereEnabled`   | `true`  | Global toggle, severe level |
| `TomLogger.globalSettingFatalEnabled`    | `true`  | Global toggle, fatal level  |

The nine level toggles are compile-out switches, one per level, independent of
the per-logger `logLevel`. See [Disable Stack Analysis in
Production](#5-disable-stack-analysis-in-production) for the one that costs
something to leave on.

### Console Output Settings

| Setting                                           | Default                    | Description      |
|---------------------------------------------------|----------------------------|------------------|
| `TomConsoleLogOutput.globalSettingStderrLogLevel` | `errors + status`          | Levels to stderr |
| `TomConsoleLogOutput.globalSettingStdoutLogLevel` | `all - (errors + status)`  | Levels to stdout |

### Remote Logging Settings

Declared by `TomRemoteLogOutput` unless noted. The defaults are deliberately
inert — one attempt, no backoff, no queue — so remote logging behaves
predictably without a live server; resilience is opted into. See [Delivery
Resilience](#delivery-resilience) for what each knob buys.

| Setting                                             | Default                     | Description                                                                 |
|-----------------------------------------------------|-----------------------------|-----------------------------------------------------------------------------|
| `TomRemoteLogOutput.remoteEndpoint`                 | `null`                      | Where records are sent. While `null`, every record goes to the fallback instead |
| `TomRemoteLogOutput.globalSettingFallbackOutput`    | `TomConsoleLogOutput()`     | Sink for records that could not be delivered, and for the warnings explaining why. If it throws, the loss is announced once on `TomPlatformUtils.outError`; assigning a new sink re-arms that report |
| `TomRemoteLogOutput.globalSettingMaxSendRetries`    | `0`                         | *Additional* attempts after the first fails, so `n` means up to `n + 1` sends. A negative value reads as `0` |
| `TomRemoteLogOutput.globalSettingRetryBackoff`      | `Duration.zero`             | Base delay; the wait before retry *k* is `backoff × k`. A negative duration reads as `Duration.zero` |
| `TomRemoteLogOutput.globalSettingReplayQueueMaxSize` | `0`                         | Records buffered after retries are exhausted. `0` disables the queue; on overflow the oldest is dropped. A negative value reads as `0` — it does **not** mean unlimited |
| `TomRemoteLogOutput.globalSettingReplayStore`       | `TomInMemoryLogReplayStore()` | Storage behind that queue. Swap in `TomFileLogReplayStore` to survive a restart mid-outage |
| `TomRemoteLogMessage.globalSettingSenderIdResolver` | `() => ""`                  | Answers which application sent a record, asked once per message. A function so that a name settled after installation is still reported |
| `TomRemoteLogMessage.globalSettingSenderId`         | `""`                        | The same answer as a value: reading asks the resolver, assigning installs one that answers that constant. Empty until something names the application, so an unset sender looks unset |

### Collector and Isolate Settings

| Setting                             | Default                            | Description                                                                 |
|-------------------------------------|------------------------------------|-----------------------------------------------------------------------------|
| `TomRemoteLogServer.localOutput`    | `null` — follow `tomLog.logOutput` | Overrides where a collector writes the records it receives; `TomRemoteLogServer.effectiveOutput` reports the resolved sink |
| `TomCreatorLogOutput.fallbackOutput` | `TomConsoleLogOutput()`            | Where a worker writes when its creator channel is absent ([When the creator channel is absent](#when-the-creator-channel-is-absent)) |

## File Structure

```
logging/
├── logging_isolate.dart        # Multi-isolate support
├── remote_logoutput.dart       # Remote logging client + replay queue
├── file_log_replay_store.dart  # Durable, file-backed replay store
├── remote_logserver.dart       # Remote logging server
└── readme.md                   # Module overview
```

The logger itself (`TomLogger`, `TomLogLevel`, `TomLogOutput`,
`TomConsoleLogOutput`) lives in `tom_basics`; this module supplies the sinks
that route records off the emitting isolate.

---

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `logging_isolate.dart`, `remote_logoutput.dart` | `Completer`, `Future`, `unawaited` |
| `dart:convert` | dart | `file_log_replay_store.dart` | `jsonDecode`, `jsonEncode` |
| `dart:io` | dart | `file_log_replay_store.dart` | The replay store's file access, and the reason that one file is native-only |
| `tom_basics` | package | every file | `tomLog` and the `TomLogOutput` interface this module plugs into. The module does not *define* logging — it supplies outputs for the logger that already exists |
| [http_connection](../http_connection/http_connection.md) | module | `remote_logoutput.dart` | `TomServerEndpoint`, which ships batches to the log server |
| [isolate_pooling](../isolate_pooling/isolate_pooling.md) | module | `logging_isolate.dart` | `TomWorker`, which is what moves file writes off the calling isolate |
| [little_things](../little_things/little_things.md) | module | `file_log_replay_store.dart`, `logging_isolate.dart`, `remote_logoutput.dart` | `getFromCurrentZone` for the ambient `TomLoggingContext`, `tomWriteFileAtomically` for the replay store, and `TomException` for the module's one raised failure — `logging.isolate.runtime_not_initialized`, see *What the module throws* |
| [reflection](../reflection/reflection.md) | module | `remote_logoutput.dart`, `remote_logserver.dart` | `@tomReflector` on the wire DTOs — the remote path does not work without generated reflection data |

The isolate-pooling row runs one way only: logging depends on isolate pooling,
never the reverse — see
[The logging module is a dependent, not a dependency](../isolate_pooling/isolate_pooling.md#the-logging-module-is-a-dependent-not-a-dependency).
The pool reports through `tomLog` precisely so that it does not have to import
this module back.
