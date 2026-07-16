# TomBase Logging System

A flexible, configurable logging framework for Dart applications with support for multiple log levels, custom outputs, isolate-based logging, and remote log collection.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
- [Best Practices](#best-practices)
- [Configuration Reference](#configuration-reference)
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
  
  // Set up remote endpoint
  TomRemoteLogOutput.remoteEndpoint = TomServerEndpoint<
      TomRemoteLogMessage, TomRemoteLogResult>(
    baseUrl: 'https://logs.example.com',
    path: '/api/logs',
  );
  
  // Activate remote logging
  tomLog.logOutput = TomRemoteLogOutput();
}
```

#### Delivery Resilience

By default `TomRemoteLogOutput` makes a single delivery attempt and, on failure,
writes the record to its fallback output (console) so nothing is lost. A send is
treated as failed both when the transport *throws* and when the server *returns*
an error result. For flaky links you can opt into retry-with-backoff and an
in-memory replay queue that drains, oldest-first, once the endpoint recovers:

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
predictable and testable without a live server. The queue is in-memory only, so
buffered records do not survive a process restart.

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
├── logging.dart           # Core logging system
├── logging_isolate.dart   # Multi-isolate support
├── remote_logoutput.dart  # Remote logging client
├── remote_logserver.dart  # Remote logging server
└── logging.md             # This documentation
```

---

## Dependencies

This module depends on:

- **Little Things Module**: `TomException` for error handling and zone utilities
- **HTTP Connection Module**: For remote logging endpoints
