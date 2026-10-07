# Tom Core Kernel API Reference: Little Things Module

Small, cross-cutting kernel utilities: the framework's full-featured exception
class, Dart zone accessors, checked-execution wrappers, stack-trace formatting,
and a UTC-offset formatting helper.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomException](#tomexception)
  - [TomFormattingException](#tomformattingexception)
  - [TomStackTraceNoise](#tomstacktracenoise)
- [Global Functions and Constants](#global-functions-and-constants)
  - [Constants](#constants)
  - [Functions](#functions)

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

That last function is the one place in the module that *does* throw. Its hour
field is two digits wide and the padding never truncates, so an unbounded
offset would render as `+100:00` — silently accepted here, rejected by every
ISO 8601 parser downstream. It therefore rejects anything outside ±840 minutes
(±14:00) with a `TomFormattingException`. The bound is the reachable range of
the packaged IANA data rather than a guess: scanning every location's
transition table yields −720 (Pacific/Kanton) through +840 (Asia/Anadyr) and
nothing beyond, so it never refuses a value the timezone API can produce, and
it is inclusive because Asia/Anadyr sits exactly on it. Raising is right here
and wrong for the trace formatters below, because this runs on the ordinary
path rather than while reporting some other failure.

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

They also share a `depth`. A non-negative value is a bound — `0` yields no
frames, `n` yields the `n` nearest the throw site — and **any** negative value
means all frames. `-1` is the default and the conventional way to write "no
limit", but it is not a sentinel the frame walk tests for: `-2` and `-99` are
equally unbounded. This matters when a depth is computed rather than written,
since arithmetic can land on `-2` as readily as `-1`; the magnitude of a
negative is never read as a frame count. A depth outside the intended range is
not rejected, because these functions run while reporting some other failure
and raising here would lose it.

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
            └── TomFormattingException

Object
    └── TomStackTraceNoise
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
| `autoLog` | `final bool` | Whether this exception logged itself when it was created — a record of what happened, not a switch. It is read in exactly one place, the constructor body that writes the two `EXCEPTION` log lines, so by the time anyone holds the exception the decision has been carried out. `final` for that reason: a settable field advertised a control it did not have. It stays readable because a server returns it in the error envelope, so a client can tell whether the failure was logged on the far side. |
| `serverCallError` | `final TomServerCallError?` | Server-call error details when the exception originated from an HTTP call. `final`: an exception is a report of something that has already happened, and a payload that can be swapped after the throw would let a handler five frames up read a description the code between it and the throw site had rewritten. |
| `logRepresentation` | `String` | *(override)* The string representation used by the logging system (equals `toString()`). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `renderStackTrace` | `String renderStackTrace(StackTrace? stack, int depth)` | *(override)* Renders a trace with `tomGetStackTrace`. `TomBaseException` fills its `stackTrace` string through this seam, so overriding it is what makes one formatter serve both representations: `e.stackTrace` equals `tomGetStackTrace(e.stack)`, and a registration on `tomStackTraceNoise` reaches both. The base's own renderer folds core frames only and writes each frame with `Frame.toString()`. Reached from the base constructor's body, before this class's body runs — safe because it reads no instance state. |
| `printStackTrace` | `void printStackTrace([int depth = -1])` | *(override)* Logs the exception's stack trace at ERROR level via `tomPrintStackTrace`, under the message `"$uuid-$requestUuid exception stacktrace"` — the trailing two words are literal text in the record, so a rule matching the identifier must not anchor to end of line; `depth` limits the number of frames (any negative value includes all; `-1` is the default). Despite the inherited name it does not `print` — `TomBaseException.printStackTrace` does, this override does not. Reports the construction site whether or not a `stack` was supplied. The inherited `stack` field is declared `Object?` and is publicly mutable, so a value that is not a `StackTrace` can still reach this method; it is reported as no frames at all — never as a substituted trace of the reporting site. |

### TomFormattingException

Thrown when a formatting function is given a value it cannot render. Currently
raised only by `convertMinutesToUtcOffset`, under the key
`formatting.utc_offset.out_of_range`, with the offending value in the message
and in `parameters['totalMinutes']`.

- **Extends:** `TomException`

#### Constructors

```dart
TomFormattingException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog,
})
```

### TomStackTraceNoise

Classifies a stack frame as noise for the formatting functions in this module.
Four groups are folded by default and cannot be unregistered, because each
describes machinery rather than the failure: Dart core-library frames
(`frame.isCore`), `package:shelf` frames, members named `TomLogger.*`, and this
module's own formatting functions.

A consumer registers its own layer on top. Registration is process-wide rather
than a per-call parameter, which is what lets it reach the formatters the
application never calls itself — `TomException.printStackTrace` and the logger
format their own traces through the same classification.

Folding **collapses** a contiguous run of matching frames into one summary
frame carrying the outermost member of the run, without line or column; it does
not delete them. A registration can only add: there is no way to declare a
frame *not* noise, so one the built-in set already claimed stays folded.

- **Extends:** none

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `predicates` | `List<bool Function(Frame frame)> get predicates` | The predicates registered on top of the built-in set, in registration order. Unmodifiable. |
| `addPredicate` | `void addPredicate(bool Function(Frame frame) predicate)` | Folds every frame `predicate` accepts, in addition to the built-in set. The general form; `Frame` is re-exported by this module, so no separate `stack_trace` dependency is needed. |
| `addPackage` | `void addPackage(String package)` | Folds every frame whose `Frame.package` equals `package` — the package name without the `package:` scheme. Matches a layer resolved as a package; a `file:` or `dart:` frame has no package name and never matches. |
| `addMemberPrefix` | `void addMemberPrefix(String prefix)` | Folds every frame whose member name *starts with* `prefix` — the shape the built-in `TomLogger.` rule takes, and the one that reaches a layer compiled into the application, where there is no package name to match on. |
| `clear` | `void clear()` | Removes every registered predicate; the built-in set is unaffected. Intended for a test's teardown — a process that registers at startup would also drop a registration made by a library it depends on. |
| `isNoise` | `bool isNoise(Frame frame)` | Whether `frame` should be folded. A registered predicate that throws is treated as answering `false` and the frame is kept: these functions run while some *other* failure is being reported, so letting the predicate's failure out would lose that report. It is not logged, because the logger formats its own traces through this function. |

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `tomStackTraceNoise` | `TomStackTraceNoise` | The process-wide noise classification every formatting function in this module reads. `final`, not `const` — it holds the registration list, which is mutated at startup. |

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `getFromCurrentZone` | `T? getFromCurrentZone<T>()` | Retrieves the value stored in the current Dart `Zone` under the key `T`, or `null` when that key is absent **or** holds a value that is not a `T`. The key is the exact `Type`, not an assignable one. |
| `getObjectFromCurrentZone` | `Object? getObjectFromCurrentZone(Type t)` | The same exact-key lookup with the type given at run time and no `is` check, so it distinguishes an absent key from a key holding an unexpected value. |
| `runChecked` | `Future<T> runChecked<T>(Future<T> Function() body, Exception Function(Object error, StackTrace stacktrace) onError)` | Runs an async `body`, transforming any `Exception` it throws via `onError` before throwing the result. An `Error` — `StateError`, `RangeError`, `TypeError`, `StackOverflowError` — propagates unchanged and never reaches `onError`, as does any other object thrown: an `Exception` reports a condition the program is expected to handle, an `Error` reports a fault in the program itself, and translating the second kind reports a bug at the wrong layer under a message describing something else. A body that means "no such thing" throws an `Exception` saying so rather than relying on `.first` raising `StateError`. `onError` *returns* the replacement rather than throwing it, so a transform cannot swallow the failure, and it returns an `Exception` so the replacement is catchable by type — `Object` allowed returning `42`, which the wrapper then threw as an unhandled `int`. |
| `runCheckedSync` | `T runCheckedSync<T>(T Function() body, Exception Function(Object error, StackTrace stacktrace) onError)` | Synchronous variant of `runChecked`, with the same `Exception`-only rule on both sides. |
| `tomPrintStackTrace` | `void tomPrintStackTrace(StackTrace? s, {String? message, int depth = -1})` | Formats a stack trace and logs it at ERROR level via `tomLog.error`, with an optional `message` prefix; `depth` limits frames. Despite the name it does not `print`, so the output goes to the configured log outputs rather than stdout. Logs nothing when there is neither a message nor a frame — reachable via `depth: 0`, `StackTrace.empty`, or a trace entirely folded away as noise — since an empty ERROR record asserts a failure it does not describe. A message alone is still logged, with no trailing separator. |
| `tomGetStackTrace` | `String tomGetStackTrace([StackTrace? s, int depth = -1])` | Returns a formatted stack trace as a newline-separated string, folding out core/`shelf`/`TomLogger` frames, this module's own formatting functions, and anything registered on `tomStackTraceNoise`. An asynchronous trace is reported whole: every segment of the `await` chain is included, newest first, so the frames run from the throw site back to the caller that started the work. `depth` bounds the flattened chain, counting from the throw site. |
| `tomGetStackTraceAsList` | `List<String> tomGetStackTraceAsList([StackTrace? s, int depth = -1])` | Same as `tomGetStackTrace` but returns individual frames as a list. Empty for a trace with no frames, such as `StackTrace.empty`. |
| `tomGetStackTraceAsTuple` | `(String, List<String>) tomGetStackTraceAsTuple([StackTrace? s, int depth = -1])` | Returns the formatted stack trace as both a string and a list of frame strings. |
| `convertMinutesToUtcOffset` | `String convertMinutesToUtcOffset(int totalMinutes)` | Converts a UTC offset in minutes to an ISO 8601 string (`"Z"`, `"+HH:MM"`, or `"-HH:MM"`). Throws `TomFormattingException` (`formatting.utc_offset.out_of_range`) outside ±840 minutes (±14:00, inclusive) — the hour field is two digits wide, so a wider offset has no valid rendering. |
