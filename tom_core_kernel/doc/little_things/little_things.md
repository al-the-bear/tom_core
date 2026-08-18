# Little Things Module

Core utility functions for exception handling, zone management, stack trace processing, and data formatting.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
- [Best Practices](#best-practices)
- [Dependencies](#dependencies)

---

## Overview

The `little_things` module provides a collection of small but essential utilities used throughout the tom_core framework. It includes:

| File | Purpose |
|------|---------|
| `exception_base.dart` | Base exception class with UUID tracking and logging |
| `little_things.dart` | Zone utilities and stack trace processing |
| `formatting.dart` | Data formatting helpers |

## Quick Start

### Import the Module

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
```

### Basic Exception Handling

```dart
// Throw a tracked exception
throw TomException(
  'USER_NOT_FOUND',
  'The requested user could not be found',
  parameters: {'userId': '12345'},
);

// Catch and handle
try {
  await fetchUser(id);
} on TomException catch (e) {
  log.error('Error ${e.uuid}: ${e.key}');
  e.printStackTrace(5); // Print top 5 frames
}
```

## Core Components

### TomException

A structured exception class that provides:

- **UUID Tracking**: Every exception gets a unique identifier
- **Request Correlation**: Link exceptions to specific requests via `requestUuid`
- **Timestamps**: Know exactly when the error occurred
- **Stack Traces**: Captured at the construction site and stored for inspection
- **Auto Logging**: Optionally log exceptions automatically

Pass `stack` only when you already hold a trace — the one from a `catch` clause,
say. Otherwise it is captured for you when the exception is constructed, which
is what lets `printStackTrace()` name the code that failed:

```dart
try {
  await transfer(order);
} catch (error, stack) {
  // Wrapping: the caught trace points at the original failure, so pass it on.
  throw TomException('TRANSFER_FAILED', 'Transfer rejected',
      rootException: error, stack: stack);
}

// Originating: nothing to pass — the construction site *is* the failure site.
throw TomException('ORDER_EMPTY', 'The order has no positions');
```

`stack` is a `StackTrace?`, so passing anything else is a compile error rather
than a failure at construction time. That distinction matters here more than in
most APIs: an exception is built *while* something is already going wrong, and a
constructor that throws replaces the failure you were trying to report with one
about the reporting.

```dart
TomException(
  'ERROR_KEY',           // Programmatic error code
  'User-friendly message',
  parameters: {...},     // Debug context
  requestUuid: reqId,    // Request correlation
  autoLog: true,         // Log immediately
  rootException: orig,   // Wrap original error
);
```

### Zone Utilities

Access typed values from the current Dart zone without threading parameters:

```dart
// Store values in zone
runZoned(
  () => handleRequest(),
  zoneValues: {
    RequestContext: context,
    AppConfig: config,
  },
);

// Later, retrieve them anywhere in the call chain
final context = getFromCurrentZone<RequestContext>();
final config = getFromCurrentZone<AppConfig>();
```

### Checked Execution

Transform errors with context-aware wrappers:

```dart
// Async version
final data = await runChecked(
  () => httpClient.get(url),
  (error, stack) => NetworkException(
    'Request to $url failed',
    originalError: error,
  ),
);

// Sync version
final config = runCheckedSync(
  () => parseConfig(json),
  (error, stack) => ConfigException('Invalid format', error),
);
```

### Stack Trace Processing

Format and filter stack traces for readable output:

```dart
// Get as string
final trace = tomGetStackTrace(stackTrace, 10);  // Top 10 frames

// Get as list
final frames = tomGetStackTraceAsList(stackTrace);

// Get both at once
final (traceStr, framesList) = tomGetStackTraceAsTuple();

// Print directly to log
tomPrintStackTrace(stackTrace, message: 'Error occurred', depth: 5);
```

Frames come back newest first — the throw site leads — and a `depth` limit
counts from there, so a bounded trace keeps the frames nearest the error.

All four take a `StackTrace?`. Nothing else is accepted, and the rejection is
the compiler's — these functions run on the error path, where a run-time type
failure would surface as a crash inside the crash report.

The trace argument is optional. Omit it (or pass `null`) and the current stack
is captured for you, which makes these functions usable as a "where am I?"
probe — the formatter's own frames are folded away, so the first frame you see
is your own:

```dart
// Both report the calling code, not this module.
final here = tomGetStackTrace();
tomPrintStackTrace(null, message: 'checkpoint', depth: 3);
```

A trace with no frames formats as an empty string rather than raising, so an
error handler can format whatever it caught without inspecting it first. This
is not a rare case: Dart supplies `StackTrace.empty` for any error created
without a trace, which includes `Future.error(e)` and
`Completer.completeError(e)`.

```dart
try {
  await Future<void>.error(Exception('created without a trace'));
} catch (error, stack) {
  // `stack` is StackTrace.empty here — this logs the message and no frames.
  tomPrintStackTrace(stack, message: 'failed: $error');
}
```

An **asynchronous** trace is reported whole. The runtime splits such a trace
into one segment per `await` boundary, and all of them are included:

```dart
Future<void> outer() async => await middle();   // ← in an older segment
Future<void> middle() async => await inner();   // ← in an older segment
Future<void> inner() async => throw StateError('boom');  // ← throw site

// tomGetStackTraceAsList(stack) reports inner, middle *and* outer.
```

This is what makes an async trace useful: the throw site alone rarely
identifies who initiated the failing work.

### Time Zone Formatting

Convert minute offsets to ISO 8601 format:

```dart
convertMinutesToUtcOffset(0);     // "Z"
convertMinutesToUtcOffset(330);   // "+05:30" (IST)
convertMinutesToUtcOffset(-300);  // "-05:00" (EST)
```

## Usage Examples

### Complete Error Handling Pattern

```dart
Future<User> getUser(String id) async {
  return await runChecked(
    () async {
      final response = await api.fetchUser(id);
      if (response.statusCode == 404) {
        throw TomException(
          'USER_NOT_FOUND',
          'User not found',
          parameters: {'userId': id},
        );
      }
      return User.fromJson(response.body);
    },
    (error, stack) => TomException(
      'USER_FETCH_ERROR',
      'Failed to fetch user',
      rootException: error,
      stack: stack,
      parameters: {'userId': id},
      autoLog: true,
    ),
  );
}
```

### Request Context with Zones

```dart
Future<void> handleRequest(HttpRequest request) async {
  final context = RequestContext(
    requestId: generateUuid(),
    timestamp: DateTime.now(),
  );

  await runZoned(
    () async {
      try {
        await processRequest(request);
      } on TomException catch (e) {
        // Exception automatically has access to context
        final ctx = getFromCurrentZone<RequestContext>();
        e.requestUuid = ctx?.requestId;
        rethrow;
      }
    },
    zoneValues: {RequestContext: context},
  );
}
```

## Best Practices

### Exception Keys

Use consistent, uppercase, underscore-separated keys:

```dart
// Good
'USER_NOT_FOUND'
'VALIDATION_ERROR'
'DATABASE_CONNECTION_FAILED'

// Avoid
'user not found'
'Error123'
'userNotFound'
```

### Parameter Usage

Include relevant debugging context in parameters:

```dart
throw TomException(
  'VALIDATION_ERROR',
  'Invalid email format',
  parameters: {
    'field': 'email',
    'value': userInput,
    'pattern': emailRegex.pattern,
  },
);
```

### Stack Trace Depth

Use appropriate depth for context without noise:

- **5-10 frames**: Typical for most debugging
- **-1 (all)**: For critical errors needing full context
- **1-3 frames**: For quick location identification

In asynchronous code a trace spans every `await` boundary, so `-1` can be
considerably longer than the equivalent synchronous trace. Since the limit
counts from the throw site, a bounded depth still reaches back through the
first few awaiting callers — which is usually enough to identify the operation
that failed.

### Auto Logging

Enable for unexpected/critical errors:

```dart
// Enable for unexpected errors
throw TomException('CRITICAL_ERROR', 'msg', autoLog: true);

// Disable for expected/handled errors
throw TomException('VALIDATION_ERROR', 'msg', autoLog: false);
```

---

## Dependencies

This module has no internal Tom dependencies. It is a foundational module used by:

- **Logging Module**: For log levels and output configuration
- **HTTP Connection Module**: For `TomServerCallError` integration
