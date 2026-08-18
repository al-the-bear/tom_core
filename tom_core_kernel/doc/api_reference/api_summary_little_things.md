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

The two zone accessors key on the **exact** `Type`. `Zone.current[T]` is a map
lookup matched by `==`, and `Zone` exposes no way to enumerate its keys, so no
subtype scan is possible: a value stored under `Derived` is invisible to
`getFromCurrentZone<Base>()`, one stored under `Base` is invisible to
`getFromCurrentZone<Derived>()`, `Object` is not a wildcard, and `List<int>`,
`List`, `List<num>`, `T` and `T?` are all distinct keys. Producers and consumers
must therefore name the same type; a mismatch is a silent `null`, not an error.
`getFromCurrentZone` returns `null` for two independent reasons — an absent key,
or a key holding a value that is not a `T` — and `getObjectFromCurrentZone`
tells them apart by omitting the `is` check.

The four formatting functions accept the trace as an optional argument. Passing
`null`, or nothing at all, captures `StackTrace.current` inside the formatter;
the formatter's own frames are folded away in that case, so the first frame
reported is always the caller's.

The parameter is typed `StackTrace?`, and so is `TomException`'s `stack`. Any
other object is rejected by the compiler rather than at run time — which for
these functions matters more than usual, since they run on the error path and
would otherwise raise while reporting some other failure.

A trace carrying no frames formats as an empty string (or an empty list) rather
than raising. `StackTrace.empty` is what Dart supplies for an error created
without a trace — `Future.error(e)` and `Completer.completeError(e)` both hand
out that object — so a handler can format whatever it caught without checking
it first.

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
  StackTrace? stack,
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
| `printStackTrace` | `void printStackTrace([int depth = -1])` | *(override)* Logs the exception's stack trace at ERROR level via `tomPrintStackTrace`, under the message `"$uuid-$requestUuid exception stacktrace"` — the trailing two words are literal text in the record, so a rule matching the identifier must not anchor to end of line; `depth` limits the number of frames (`-1` includes all). Despite the inherited name it does not `print` — `TomBaseException.printStackTrace` does, this override does not. Reports the construction site whether or not a `stack` was supplied. The inherited `stack` field is declared `Object?` and is publicly mutable, so a value that is not a `StackTrace` can still reach this method; it is reported as no frames at all — never as a substituted trace of the reporting site. |

## Global Functions and Constants

### Constants

None — this module exposes no top-level constants.

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `getFromCurrentZone` | `T? getFromCurrentZone<T>()` | Retrieves the value stored in the current Dart `Zone` under the key `T`, or `null` when that key is absent **or** holds a value that is not a `T`. The key is the exact `Type`, not an assignable one. |
| `getObjectFromCurrentZone` | `Object? getObjectFromCurrentZone(Type t)` | The same exact-key lookup with the type given at run time and no `is` check, so it distinguishes an absent key from a key holding an unexpected value. |
| `runChecked` | `Future<T> runChecked<T>(Future<T> Function() body, Object Function(Object error, StackTrace stacktrace) onError)` | Runs an async `body`, transforming any thrown error via `onError` before rethrowing. |
| `runCheckedSync` | `T runCheckedSync<T>(T Function() body, Object Function(Object error, StackTrace stacktrace) onError)` | Synchronous variant of `runChecked`. |
| `tomPrintStackTrace` | `void tomPrintStackTrace(StackTrace? s, {String? message, int depth = -1})` | Formats a stack trace and logs it at ERROR level via `tomLog.error`, with an optional `message` prefix; `depth` limits frames. Despite the name it does not `print`, so the output goes to the configured log outputs rather than stdout. Logs nothing when there is neither a message nor a frame — reachable via `depth: 0`, `StackTrace.empty`, or a trace entirely folded away as noise — since an empty ERROR record asserts a failure it does not describe. A message alone is still logged, with no trailing separator. |
| `tomGetStackTrace` | `String tomGetStackTrace([StackTrace? s, int depth = -1])` | Returns a formatted stack trace as a newline-separated string, folding out core/`shelf`/`TomLogger` frames and this module's own formatting functions. An asynchronous trace is reported whole: every segment of the `await` chain is included, newest first, so the frames run from the throw site back to the caller that started the work. `depth` bounds the flattened chain, counting from the throw site. |
| `tomGetStackTraceAsList` | `List<String> tomGetStackTraceAsList([StackTrace? s, int depth = -1])` | Same as `tomGetStackTrace` but returns individual frames as a list. Empty for a trace with no frames, such as `StackTrace.empty`. |
| `tomGetStackTraceAsTuple` | `(String, List<String>) tomGetStackTraceAsTuple([StackTrace? s, int depth = -1])` | Returns the formatted stack trace as both a string and a list of frame strings. |
| `convertMinutesToUtcOffset` | `String convertMinutesToUtcOffset(int totalMinutes)` | Converts a UTC offset in minutes to an ISO 8601 string (`"Z"`, `"+HH:MM"`, or `"-HH:MM"`). |
