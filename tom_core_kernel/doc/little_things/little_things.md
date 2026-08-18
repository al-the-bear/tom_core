# Little Things Module

Core utility functions for exception handling, zone management, stack trace processing, and data formatting.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
- [Usage Examples](#usage-examples)
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
  'user.fetch.not_found',
  'The requested user could not be found',
  parameters: {'userId': '12345'},
);

// Catch and handle
try {
  await fetchUser(id);
} on TomException catch (e) {
  log.error('Error ${e.uuid}: ${e.key}');
  e.printStackTrace(5); // Logs the top 5 frames at ERROR level
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
  throw TomException('payment.transfer.rejected', 'Transfer rejected',
      rootException: error, stack: stack);
}

// Originating: nothing to pass — the construction site *is* the failure site.
throw TomException('order.submit.no_positions',
    'The order has no positions');
```

`stack` is a `StackTrace?`, so passing anything else is a compile error rather
than a failure at construction time. That distinction matters here more than in
most APIs: an exception is built *while* something is already going wrong, and a
constructor that throws replaces the failure you were trying to report with one
about the reporting.

```dart
TomException(
  'area.operation.condition', // Programmatic error key
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

The type argument is the **key**, matched exactly — not a type the stored value
merely satisfies. `Zone.current[T]` is a map lookup on the `Type` object, and
`Zone` offers no way to enumerate its keys, so no subtype scan is possible:

```dart
runZoned(
  () {
    getFromCurrentZone<Derived>();  // the instance
    getFromCurrentZone<Base>();     // null — a different key
    getFromCurrentZone<Object>();   // null — Object is not a wildcard
  },
  zoneValues: {Derived: Derived()},
);
```

It misses in the other direction too — a `Derived` filed under `Base` is found
by `getFromCurrentZone<Base>()` and not by `getFromCurrentZone<Derived>()` — and
type arguments count, so `List<int>`, `List` and `List<num>` are three separate
keys, as are `T` and `T?`.

**So choose the key once and use it on both sides**, conventionally the declared
type of the field the value is read into. A mismatch is not a compile error and
throws nothing; it is a silent `null` that looks exactly like "nothing stored
here". `getObjectFromCurrentZone(T)` separates the two, since it performs the
same key lookup without the `is T` guard that `getFromCurrentZone` applies
afterwards.

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

// Log at ERROR level
tomPrintStackTrace(stackTrace, message: 'Error occurred', depth: 5);
```

`tomPrintStackTrace` does not `print`, and neither does
`TomException.printStackTrace`, which delegates to it. Both call
`tomLog.error`, so the trace goes wherever the configured log outputs point,
at ERROR level:

- under a recording output — the usual arrangement in a test — it never
  reaches stdout, so a test that expects console output sees none;
- under an output filtered above ERROR it is dropped altogether;
- in production it lands in the error log, which is to say it is *not* the
  harmless debugging aid the name suggests.

The name is inherited from `TomBaseException.printStackTrace` in
`tom_basics`, which genuinely does call `print`. `TomException` overrides it
to log instead, so the two behave differently under the same name.

`TomException.printStackTrace` supplies its own message —
`"$uuid-$requestUuid exception stacktrace"` — and `tomPrintStackTrace` joins
that to the trace with a space, not a newline. So the first frame shares a
line with the identifier:

```text
3f2a…-req-456 exception stacktrace #0  Foo.bar (file:///…/foo.dart:12:5)
#1  main (file:///…/main.dart:4:3)
```

Three things follow for anything parsing these records. The words after the
identifier pair are literal text, not a description, so they are always
present. A rule keying on the pair cannot anchor to end of line. And
`requestUuid` renders as the string `null` when the exception carries none,
rather than being omitted — the pair is always two fields wide.

Frames come back newest first — the throw site leads — and a `depth` limit
counts from there, so a bounded trace keeps the frames nearest the error.

Only a non-negative `depth` is a bound. **Any** negative value means all
frames: `-1` is the default and the conventional spelling of "no limit", but
the frame walk tests `depth >= 0` rather than comparing against `-1`, so `-2`
and `-99` are unbounded too, and the magnitude of a negative is never read as
a frame count. Write the depth yourself and this never comes up; compute it —
`available - alreadyLogged`, say — and it does, because arithmetic reaches
`-2` as readily as `-1`. Both give you the whole trace, which is the safe
direction to be wrong in: more context than asked for, never less.

An out-of-range depth is not rejected. These functions run while reporting
some other failure, and throwing here would discard that failure in order to
complain about the number used to describe it.

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

`tomPrintStackTrace` logs nothing at all when there is nothing to say — no
message and no frames. Besides `StackTrace.empty`, that state is reached by
`depth: 0`, which is a genuine request for no frames, and by a trace whose
every frame was folded away as noise. An ERROR record with an empty body would
assert that something failed while describing nothing, at the level operators
alert on, so the call is skipped instead. A message alone still logs: it is the
caller's context, and losing it because the trace was empty would hide the
error entirely.

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
          'user.fetch.not_found',
          'User not found',
          parameters: {'userId': id},
        );
      }
      return User.fromJson(response.body);
    },
    (error, stack) => TomException(
      'user.fetch.failed',
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

A key is dotted lowercase, `lower_snake_case` within each segment, and reads
`<area>.<operation>.<condition>`:

```dart
// Good
'beanlocator.bean_access.bean_not_found_by_name'
'isolate.pool_closed.execute_after_close'
'apis.endpoint.missing_url_parameter'

// Avoid
'USER_NOT_FOUND'      // no dots — nothing to group or namespace by
'user not found'      // spaces; not usable as a lookup key
'userNotFound'        // camelCase
'Error123'            // says nothing about what went wrong
```

Three segments is the norm and two or four are fine when the subject genuinely
has that shape (`messaging.email.recipients.empty`). What matters is that the
**first segment names the module or subsystem**, because that is the part that
makes keys from unrelated code impossible to collide and lets a handler match a
whole area with a prefix test.

The key is not a message. It is the value callers switch on and the natural
lookup key for a translated message, so it should stay stable even when the
wording of `defaultUserMessage` changes — and it should be specific enough that
two different failures never share one.

### Parameter Usage

Include relevant debugging context in parameters:

```dart
throw TomException(
  'signup.validate.invalid_email',
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
- **-1, or any other negative (all)**: For critical errors needing full context
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
throw TomException('storage.connect.unreachable', 'msg', autoLog: true);

// Disable for expected/handled errors
throw TomException('signup.validate.invalid_email', 'msg', autoLog: false);
```

---

## Dependencies

This module depends on:

| Dependency | Imported by | For |
| ---------- | ----------- | --- |
| `dart:async` | `little_things.dart` | `Zone`, behind both zone accessors |
| `package:stack_trace` | `little_things.dart` | `Chain.forTrace(...).foldFrames(...)` — flattening an async trace and folding out framework noise |
| `package:tom_basics` | `little_things.dart`, `exception_base.dart` | `TomBaseException` (the superclass of `TomException`), `TomLoggable` (which it implements), and `tomLog` for `autoLog` and `tomPrintStackTrace` |
| **HTTP Connection Module** | `exception_base.dart` | `TomServerCallError`, the type of `TomException`'s optional `serverCallError` field |

`formatting.dart` imports nothing at all — `convertMinutesToUtcOffset` is plain
Dart arithmetic.

`tomLog` is a live global with a working default, so nothing has to be wired up
before calling into this module; the package dependency is real nonetheless.

### The HTTP Connection edge is a cycle

The module is foundational in the sense that twelve of the package's modules
import it — but it is not free of internal dependencies, and the one it has
runs *both* ways:

```
exception_base.dart ──> http_connection/server_connection.dart
    for TomServerCallError

http_connection/endpoints_apis.dart ──> little_things/exception_base.dart
    for TomEndpointException extends TomException
```

Dart permits this — the two files form one library cycle, resolved through the
package barrel that `server_connection.dart` imports — so it compiles and is
not a defect to be fixed casually. It is worth knowing about before moving
either type: `TomServerCallError` cannot be pushed *down* into this module
without dragging the HTTP types with it, and `TomException` cannot be pushed
*up* into `http_connection` because seventeen classes across eight other
modules extend it.

### Consumers are not listed here

Twelve of the package's modules import this one — `beanlocator`, `context`,
`http_connection`, `isolate_pooling`, `logging`, `observable`, `preferences`,
`reflection`, `scheduling`, `scope_ids`, `security` and `timezoned`. Each
records that edge in its **own** `## Dependencies` section, and this section
deliberately does not repeat them.

The reason is that a consumer list kept here has no mechanism holding it to the
code: adding a module that uses `TomException` does not touch this file, so the
list silently decays while every line of it still reads as fact. The edge
recorded next to the import that creates it stays honest because the two change
together. Read the graph from the consumer side.
