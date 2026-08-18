# TomBase Logging System

A flexible, configurable logging framework for Dart applications with support for multiple log levels, custom outputs, isolate-based logging, and remote log collection.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)
- [Configuration Reference](#configuration-reference)
- [File Structure](#file-structure)
- [Dependencies](#dependencies)

---

## Overview

The TomBase logging system provides:

- **Multiple Log Levels**: From trace (most verbose) to fatal (most severe)
- **Bitwise Level Composition**: Combine or exclude levels using `+` and `-` operators
- **Per-Class/Method Customization**: Set different log levels for specific code locations
- **Pluggable Outputs**: Console, remote server, isolate-based, or custom implementations
- **Multi-Isolate Support**: Centralized logging across all application isolates
- **Remote Logging**: Send logs to a centralized server for analysis

## Quick Start

### Basic Usage

```dart
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
  // Configure sender identification
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
the collector is built on. Change the Tom half there and copy it out: this
section previously showed a `baseUrl`/`path` endpoint constructor and
`fromJson`/`toJson` methods that do not exist, because a document, unlike an
example, cannot fail to build.

##### When the collector refuses a record

Two independent things can make `receive` refuse: the message can be undecodable
(a malformed `timeStamp`), or `localOutput` can be broken. The returned
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

The defaults (no retries, no backoff, no replay queue) keep behaviour
predictable and testable without a live server.

Records reach the endpoint one at a time, in the order `output` was called.
This matters because `output` returns before its record has been sent, so
back-to-back log lines overlap by default; without serialisation each of them
would run its own drain over the same replay queue and re-send records another
drain had read but not yet removed. The guarantee covers one isolate — the same
scope as the queue it protects, since both are statics.

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

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() async {
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

#### When the creator channel is absent

`TomCreatorLogOutput` sends to the creator isolate only when there is one to
send to; `TomWorker.canSendToCreator()` is false in the main isolate and in any
worker started without a back-channel. Everything else goes to
`TomCreatorLogOutput.fallbackOutput`.

That slot is a `TomLogOutput`, so any sink can be installed there — a file, a
collector, a capture in a test — and the whole record is handed on, not just
the message text. It defaults to a `TomConsoleLogOutput`, so an application
that never touches it behaves as before. The type matters because a worker
that has lost its creator is the case where its records are least likely to be
watched on a console, which is exactly when redirecting them somewhere durable
is worth doing.

```dart
TomCreatorLogOutput.fallbackOutput = FileLogOutput('/var/log/worker.log');
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

## Configuration Reference

### Global Settings

| Setting                                | Default       | Description                    |
|----------------------------------------|---------------|--------------------------------|
| `TomLogger.globalSettingDetermineCaller` | `true`      | Enable stack trace analysis    |
| `TomLogger.globalSettingInfoEnabled`   | `true`        | Global toggle for info logs    |
| `TomLogger.globalSettingDebugEnabled`  | `true`        | Global toggle for debug logs   |
| `TomLogOutput.globalSettingRemoteLogEndpoint` | `/remotelog` | Remote endpoint path      |

### Console Output Settings

| Setting                                      | Default           | Description              |
|----------------------------------------------|-------------------|--------------------------|
| `TomConsoleLogOutput.globalSettingStderrLogLevel` | errors + status | Levels to stderr        |
| `TomConsoleLogOutput.globalSettingStdoutLogLevel` | all - errors    | Levels to stdout        |

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

This module depends on:

- **Little Things Module**: `getFromCurrentZone`, used by `remote_logoutput.dart`
  to pick up the ambient `TomLoggingContext`. Only `little_things.dart` is
  imported, not `exception_base.dart` — this module raises no `TomException`
- **HTTP Connection Module**: For remote logging endpoints
