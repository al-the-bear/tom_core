# Tom Core Kernel API Reference: Little Things Module

Small, cross-cutting kernel utilities: the framework's full-featured exception
class, Dart zone accessors, checked-execution wrappers, stack-trace formatting,
and a UTC-offset formatting helper.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomException](#tomexception)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources:

- `lib/src/tombase/little_things/exception_base.dart`
- `lib/src/tombase/little_things/formatting.dart`
- `lib/src/tombase/little_things/little_things.dart`

The Little Things module gathers the foundational helpers used throughout
`tom_core_kernel`. `TomException` extends the minimal `TomBaseException` from
`tom_basics` with automatic logging, HTTP server-call error tracking, and
integration into the TOM logging system via `TomLoggable`. The top-level
functions provide typed access to values stored in the current Dart `Zone`
(`getFromCurrentZone`, `getObjectFromCurrentZone`), error-transforming
execution wrappers (`runChecked`, `runCheckedSync`), and stack-trace formatting
that folds out framework noise (`tomPrintStackTrace`, `tomGetStackTrace`,
`tomGetStackTraceAsList`, `tomGetStackTraceAsTuple`). `convertMinutesToUtcOffset`
formats a minute offset as an ISO 8601 UTC-offset string.

The four formatting functions accept the trace as an optional argument. Passing
`null`, or nothing at all, captures `StackTrace.current` inside the formatter;
the formatter's own frames are folded away in that case, so the first frame
reported is always the caller's.

## Class Hierarchy

```
TomBaseException  (tom_basics)
    └── TomException  (implements TomLoggable)
```

## Classes

### TomException

Full-featured exception class with logging, server-error tracking, and UUID
support. Extends the minimal `TomBaseException` from `tom_basics` and adds
optional auto-logging on creation, HTTP server-call error details, and TOM
logging integration.

- **Extends:** `TomBaseException`
- **Implements:** `TomLoggable`

#### Constructors

```dart
TomException(
  String key,
  String defaultUserMessage, {
  String? requestUuid,
  Map<String, Object?>? parameters,
  Object? rootException,
  bool autoLog = false,
  Object? stack,
  String? uuid,
  TomServerCallError? serverCallError,
})
```

When `autoLog` is `true`, the exception and its stack trace are written to
`tomLog.error` immediately upon construction.

When `stack` is omitted it is captured at the construction site, so both the
`stack` field and the formatted `stackTrace` string describe where the
exception was created. The newest frame is `TomException`'s own constructor —
the trace is taken inside it — and the creating code is the frame below.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `autoLog` | `bool` | Whether this exception is automatically logged when created. |
| `serverCallError` | `TomServerCallError?` | Server-call error details when the exception originated from an HTTP call. |
| `logRepresentation` | `String` | *(override)* The string representation used by the logging system (equals `toString()`). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `printStackTrace` | `void printStackTrace([int depth = -1])` | *(override)* Prints the exception's stack trace to the log; `depth` limits the number of frames (`-1` prints all). Reports the construction site whether or not a `stack` was supplied. |

## Global Functions and Constants

### Constants

None — this module exposes no top-level constants.

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `getFromCurrentZone` | `T? getFromCurrentZone<T>()` | Retrieves a typed value of type `T` from the current Dart `Zone`, or `null` if absent or not of type `T`. |
| `getObjectFromCurrentZone` | `Object? getObjectFromCurrentZone(Type t)` | Retrieves the raw (untyped) zone value keyed by the runtime `Type` `t`, or `null` if not found. |
| `runChecked` | `Future<T> runChecked<T>(Future<T> Function() body, Object Function(Object error, StackTrace stacktrace) onError)` | Runs an async `body`, transforming any thrown error via `onError` before rethrowing. |
| `runCheckedSync` | `T runCheckedSync<T>(T Function() body, Object Function(Object error, StackTrace stacktrace) onError)` | Synchronous variant of `runChecked`. |
| `tomPrintStackTrace` | `void tomPrintStackTrace(Object? s, {String? message, int depth = -1})` | Formats and logs a stack trace to the error log with an optional `message` prefix; `depth` limits frames. |
| `tomGetStackTrace` | `String tomGetStackTrace([Object? s, int depth = -1])` | Returns a formatted stack trace as a newline-separated string, folding out core/`shelf`/`TomLogger` frames and this module's own formatting functions. An asynchronous trace is reported whole: every segment of the `await` chain is included, newest first, so the frames run from the throw site back to the caller that started the work. `depth` bounds the flattened chain, counting from the throw site. |
| `tomGetStackTraceAsList` | `List<String> tomGetStackTraceAsList([Object? s, int depth = -1])` | Same as `tomGetStackTrace` but returns individual frames as a list. |
| `tomGetStackTraceAsTuple` | `(String, List<String>) tomGetStackTraceAsTuple([Object? s, int depth = -1])` | Returns the formatted stack trace as both a string and a list of frame strings. |
| `convertMinutesToUtcOffset` | `String convertMinutesToUtcOffset(int totalMinutes)` | Converts a UTC offset in minutes to an ISO 8601 string (`"Z"`, `"+HH:MM"`, or `"-HH:MM"`). |
