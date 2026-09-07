# Shutdown Cleanup Module

The shutdown cleanup module provides a comprehensive system for managing graceful process termination in Tom applications. It ensures that resources are properly released and cleanup handlers are executed in an orderly fashion before the process exits.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
  - [Interfaces](#interfaces)
  - [TomCloseAdaptor](#tomcloseadaptor)
  - [TomShutdownCleanup](#tomshutdowncleanup)
    - [paused and silent](#paused-and-silent)
    - [Tearing an instance down — dispose() and cancelAll()](#tearing-an-instance-down--dispose-and-cancelall)
    - [start() — an optional log breadcrumb](#start--an-optional-log-breadcrumb)
- [Usage Examples](#usage-examples)
  - [Basic Resource Cleanup](#basic-resource-cleanup)
  - [Custom Signal Handlers](#custom-signal-handlers)
  - [Multiple Cleanup Instances](#multiple-cleanup-instances)
  - [Server Application Pattern](#server-application-pattern)
- [Execution Order](#execution-order)
  - [Teardown is never awaited](#teardown-is-never-awaited)
- [Best Practices](#best-practices)
  - [1. Register Early](#1-register-early)
  - [2. Use Appropriate Interfaces](#2-use-appropriate-interfaces)
  - [3. Handle Errors Inside a Handler That Has More To Do](#3-handle-errors-inside-a-handler-that-has-more-to-do)
  - [4. Don't Block Indefinitely](#4-dont-block-indefinitely)
  - [5. Reach for TomCloseAdaptor Last, Not First](#5-reach-for-tomcloseadaptor-last-not-first)
- [Limitations](#limitations)
- [Dependencies](#dependencies)

---

## Overview

When a process receives termination signals (like SIGHUP or SIGINT from Ctrl+C), the shutdown cleanup system:

1. Intercepts the signal
2. Executes all registered signal handlers
3. Closes all registered closable objects
4. Disposes all registered disposable objects
5. Marks the cleanup as complete to prevent duplicate execution

The system is designed to be fault-tolerant—if one cleanup operation fails, it
reports the failure and continues with the remaining operations. The report
names the phase, the entry, the exception and the top frames of its stack, and
goes to `print` rather than the logging system (see
[Limitations](#limitations)); setting `silent` suppresses it.

## Quick Start

Registering a resource is the whole setup. There is no arming step: the global
instance begins listening for SIGHUP and SIGINT when it is created, so a
registered resource is already covered.

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // Register resources for cleanup
  final database = DatabaseConnection();
  final cache = CacheManager();
  
  tomShutdownCleanup.addClosable(database);
  tomShutdownCleanup.addDisposable(cache);
  
  // Your application logic here...
  // On Ctrl+C: database.close() then cache.dispose(), automatically.
}
```

## Core Components

### Interfaces

Both are synchronous, and deliberately so — see
[Teardown is never awaited](#teardown-is-never-awaited) before writing an
`async` implementation of either, because the compiler will accept one.

#### TomDisposable

Interface for objects that need cleanup via a `dispose()` method.

```dart
class MyStreamManager implements TomDisposable {
  final StreamController _controller = StreamController();
  
  @override
  void dispose() {
    _controller.close();
    print('StreamManager disposed');
  }
}
```

#### TomClosable

Interface for objects that need cleanup via a `close()` method.

```dart
class MyConnection implements TomClosable {
  Socket? _socket;
  
  @override
  void close() {
    _socket?.close();
    print('Connection closed');
  }
}
```

### TomCloseAdaptor

Wraps an object that has a close/dispose method but does not implement the Tom
interfaces, resolving that method through the global `tomReflector`.

Read the reflector requirement before reaching for this. The target's class
must carry `@tomReflector` and must have been through `build_runner`, which
makes the adaptor a tool for **your own** classes — usually ones already
annotated for something else — and rules out the case its name suggests. A
type you do not own cannot be annotated, so `HttpClient` and anything else
from outside your build is beyond it. See [Adapting a class you do not
own](#adapting-a-class-you-do-not-own).

```dart
// A class of your own, already annotated, whose teardown method you would
// rather not re-expose by implementing TomClosable.
@tomReflector
class SessionStore {
  void close() { /* ... */ }
}

tomShutdownCleanup.addClosable(TomCloseAdaptor(SessionStore()));

// Specify a custom method name
@tomReflector
class Worker {
  void shutdown() { /* ... */ }
}

tomShutdownCleanup.addClosable(TomCloseAdaptor(Worker(), 'shutdown'));
```

An unreflectable target fails in the constructor with a `TomReflectorException`
naming the type and the annotation that would have fixed it:

```text
TomCloseAdaptor: cannot reflect on HttpClient — the class is not annotated
with @tomReflector, or its generated reflection data was not initialized. A
type you do not own cannot be annotated; wrap it in a class of your own that
implements TomClosable instead: ...
```

#### Adapting a class you do not own

You cannot, and the adaptor is the wrong tool for it. Write the four lines
instead — they need no reflection, no annotation and no build step, and they
are checked by the compiler rather than at runtime:

```dart
class HttpClientCloser implements TomClosable {
  HttpClientCloser(this._client);
  final HttpClient _client;

  @override
  void close() => _client.close();
}

tomShutdownCleanup.addClosable(HttpClientCloser(httpClient));
```

This is the better choice even when the target *is* one of your annotated
classes. The adaptor earns its keep only where the wrapper cannot be written
by hand — chiefly when the method name is chosen at runtime.

### TomShutdownCleanup

The main coordinator class that manages all cleanup operations.

#### Default Signals

By default, `TomShutdownCleanup` listens for:
- `SIGHUP` - Hangup signal
- `SIGINT` - Interrupt signal (Ctrl+C)

#### Adding Additional Signals

```dart
// Also handle SIGTERM
tomShutdownCleanup.addSignal(ProcessSignal.sigterm);
```

Naming a signal that is already watched — one of the two defaults above, or one
added earlier — does nothing. Registering is safe to repeat, so code that arms
its own signals need not first work out which ones are already covered.

#### Running cleanup without a signal — performShutdown()

A signal is one way into the cleanup, not the only one. `performShutdown()`
runs the three phases immediately, which is how a test, a hosted runtime, or a
process that decides to stop on its own terms triggers teardown:

```dart
tomShutdownCleanup.performShutdown();
```

The optional `signal:` argument is forwarded to the registered signal handlers
for those that branch on it; it defaults to `SIGINT` and names nothing that
actually arrived. The signal path calls the same method with `fromSignal: true`,
and that flag — not the presence of a real signal — is what selects the
right-hand column below:

| | `performShutdown()` | An arriving signal |
| --- | --- | --- |
| Runs while [`paused`](#paused-and-silent) is set | yes, `paused` is ignored | no, the signal is dropped |
| Prints `Received …` / `Shutdown performed` | never | unless [`silent`](#paused-and-silent) |
| Reports an entry that throws | unless `silent` | unless `silent` |

Either way the cleanup runs **once** per instance: whichever route arrives
first does the work and the other finds it done. A signal arriving after a
manual shutdown still announces itself and then reports that shutdown has
already been performed.

#### paused and silent

Two flags on the instance, both `false` by default.

`paused` makes arriving signals do nothing. Note what it does *not* do: the
watchers stay installed, so the signal is still delivered here and still
withheld from the operating system's default handling — it is simply ignored on
arrival. Under `paused`, then, Ctrl+C neither cleans up nor stops the program.
That is the intent; the flag exists for interactive REPLs that do their own
Ctrl+C handling and need this instance to keep out of the way. Manual
`performShutdown()` is unaffected.

`silent` suppresses output. That covers the two status messages, which only the
signal path emits anyway, and the per-entry failure diagnostics, which both
paths emit — so a silent instance stays quiet about a cleanup that throws. See
[Limitations](#limitations) for what that costs.

#### Tearing an instance down — dispose() and cancelAll()

`cancelAll()` cancels every signal watcher the instance holds: the two the
constructor installed and any added with `addSignal()`. `dispose()` is the same
operation under the name callers look for — it delegates and adds nothing.
Both are safe to call more than once.

Call one of them for **any instance whose lifetime is shorter than the
process**. A live watcher keeps the process alive, so an undisposed instance
stops the program from exiting, and the symptom is a hang rather than an error.
The global `tomShutdownCleanup` is the exception: it is meant to last as long
as the program, so it is never disposed.

Neither method runs the cleanup. Disposing releases the instance's watchers; it
does not close the closables registered on it. Call `performShutdown()` first
if the resources still need releasing.

#### start() — an optional log breadcrumb

`start()` does not start anything. Signal listening is armed by the
constructor, so calling it or omitting it makes no difference to shutdown
behaviour; the method writes one constant `tomLog.info` line and returns.

```dart
tomShutdownCleanup.start(); // Logs "Shutdown cleanup in use". Nothing else.
```

It is worth calling in a long-running server, where the line is useful
evidence in the log that the process had cleanup wired up. It is not a setup
step, it has no required position relative to the `add*` calls, and no example
in this document uses it.

## Usage Examples

### Basic Resource Cleanup

```dart
void main() {
  final db = DatabaseConnection.connect();
  final redis = RedisClient.connect();
  
  tomShutdownCleanup.addClosable(db);
  tomShutdownCleanup.addClosable(redis);
  
  // Application runs...
  // On Ctrl+C: db.close() and redis.close() are called automatically
}
```

### Custom Signal Handlers

```dart
tomShutdownCleanup.addSignalHandler((signal) {
  print('Shutting down due to $signal');
  
  // Custom cleanup logic
  saveApplicationState();
  notifyConnectedClients();
  flushLogs();
});
```

### Multiple Cleanup Instances

For specialized handling of different signals:

```dart
// Main cleanup for standard signals
tomShutdownCleanup.addClosable(mainDatabase);

// Separate handler for user-defined signals
final debugCleanup = TomShutdownCleanup();
debugCleanup.addSignal(ProcessSignal.sigusr1);
debugCleanup.addSignalHandler((signal) {
  print('Debug info requested');
  dumpDebugState();
});
```

A custom instance created for the life of the program, as above, needs nothing
further. One with a bounded lifetime must be
[disposed](#tearing-an-instance-down--dispose-and-cancelall) when that lifetime
ends — constructing it armed SIGHUP/SIGINT watchers, and a live watcher keeps
the process alive:

```dart
await debugCleanup.dispose();
```

### Server Application Pattern

Closing an `HttpServer` gracefully is asynchronous, and
[nothing here is awaited](#teardown-is-never-awaited) — so the handler does not
attempt it. Its whole job is to *signal*, synchronously, that shutdown was
requested; the awaiting happens back in the server's own control flow, where an
`await` means what it says:

```dart
class MyServer {
  late HttpServer _server;
  final Completer<void> _stopRequested = Completer<void>();

  Future<void> run() async {
    _server = await HttpServer.bind('localhost', 8080);

    // Synchronous, and complete by the time it returns.
    tomShutdownCleanup.addSignalHandler((signal) {
      if (!_stopRequested.isCompleted) _stopRequested.complete();
    });

    unawaited(_serve());
    await _stopRequested.future;

    print('Shutting down server...');
    await _server.close(force: false);
  }

  Future<void> _serve() async {
    await for (final request in _server) {
      handleRequest(request);
    }
  }
}
```

The cost of the indirection is one `Completer`; what it buys is that
`_server.close()` is genuinely waited for before `run()` returns and the
process goes.

## Execution Order

When a signal is received, cleanup operations execute in this order:

1. **Signal Handlers** - Custom functions added via `addSignalHandler()`
2. **Closables** - Objects added via `addClosable()`
3. **Disposables** - Objects added via `addDisposable()`

Within each category, items are processed in the order they were registered.

### Teardown is never awaited

Every entry is called through a plain `void Function(…)`, and the shutdown does
not wait for what comes back. That applies to all three phases alike: a signal
handler, a `close()` and a `dispose()` are each called, and the shutdown moves
straight on to the next entry.

An `async` entry therefore **compiles and does not work as it reads**:

```dart
// Not what it looks like.
tomShutdownCleanup.addSignalHandler((signal) async {
  await flushJournal();   // <- the shutdown has already moved on
  await closeSockets();   // <- may never run at all
});
```

Dart accepts the `async` body because in return position every type is a
subtype of `void`, so nothing warns. What happens instead is:

- the body runs synchronously **only up to its first `await`**, and the phase
  continues from there;
- the remainder resumes on a later turn of the event loop — a turn a shutting
  down process may not be there for;
- anything it throws after that first `await` misses the per-entry failure
  report entirely, because that catch is around the *call*, not around the
  future the call returned. The error surfaces as an unhandled asynchronous
  error with nothing left to say which phase or which entry produced it.

So keep the entries synchronous, and drive awaited teardown from your own
control flow: let a handler record that shutdown was requested, and do the
awaiting where an `await` is honoured. The
[Server Application Pattern](#server-application-pattern) below is that shape
in full.

## Best Practices

### 1. Register Early

Register cleanup handlers as soon as resources are created:

```dart
final connection = await Database.connect();
tomShutdownCleanup.addClosable(connection); // Register immediately
```

### 2. Use Appropriate Interfaces

- Use `TomClosable` for resources that need to be closed (connections, files, sockets)
- Use `TomDisposable` for resources that need disposal (controllers, subscriptions)
- Use signal handlers for complex cleanup logic

### 3. Handle Errors Inside a Handler That Has More To Do

The system catches what escapes a handler and reports it — phase, entry,
exception, and the top ten stack frames — so you do not need your own
try/catch merely to find out that something failed:

```text
Failed to call closable Instance of 'CacheService': Exception: flush timed out
lib/cache_service.dart 88:5 l:88 c:5 CacheService.close lib/cache_service.dart
…
```

What it cannot do is resume your handler. The catch is *around* the whole
callout, so the first throw ends that handler and the remaining entries run.
Catch inside a handler when the steps after the risky one still need to happen:

```dart
tomShutdownCleanup.addSignalHandler((signal) {
  try {
    flushPendingWrites();
  } catch (e) {
    print('Flush failed, continuing: $e');
  }
  notifyConnectedClients(); // runs either way — this is the point
});
```

### 4. Don't Block Indefinitely

Every entry runs on the shutdown's own thread of control, one after another, so
a slow entry delays every entry behind it. Prefer the bounded, synchronous form
of an operation where the resource offers one:

```dart
// flushSync(), not flush() — see "Teardown is never awaited" above.
tomShutdownCleanup.addClosable(journal);
```

Note that the obvious way to bound a slow step does not work here:

```dart
// Inert. Nothing awaits the handler, so nothing waits for the race either.
tomShutdownCleanup.addSignalHandler((signal) async {
  await Future.any([
    slowCleanupOperation(),
    Future.delayed(Duration(seconds: 5)),
  ]);
});
```

The phase returns the moment that body reaches its first `await`, so the
timeout bounds nothing — it merely looks as though it does. A deadline needs
somewhere that actually waits, which means the application's own control flow:
signal from the handler and impose the timeout there, as under
[Server Application Pattern](#server-application-pattern).

### 5. Reach for TomCloseAdaptor Last, Not First

The adaptor looks like the answer for objects you don't control, and it is the
one thing it cannot be: it resolves the method through `tomReflector`, so the
target's class needs an annotation only its own author can add.

Prefer, in order:

1. **Implement `TomClosable`/`TomDisposable`** on the class, if it is yours.
2. **Write a small wrapper** that implements one of them, if it is not. No
   reflection, no build step, and a compile error rather than a runtime one if
   the wrapped method changes.
3. **Use `TomCloseAdaptor`** when neither fits — chiefly when the method name
   is not known until runtime:

```dart
tomShutdownCleanup.addClosable(TomCloseAdaptor(store, config.teardownMethod));
```

## Limitations

- Teardown is synchronous throughout: a `Future` returned from a signal handler, a `close()` or a `dispose()` is discarded rather than awaited, and the compiler cannot flag it because `void` accepts any return type — see [Teardown is never awaited](#teardown-is-never-awaited)
- The cleanup system uses `print()` for logging during shutdown (not the full logging system) to ensure output even if logging is affected
- `silent` suppresses the failure diagnostics along with the status messages, so a silent instance says nothing when a cleanup throws — the cleanup still continues, but the reason it failed is gone
- A failure's stack trace is cut to its top ten frames, enough to identify the failing `close()`/`dispose()` but not to follow a deep call chain
- Cleanup executes only once—subsequent signals are ignored after the first cleanup completes
- On some platforms, certain signals may not be available
- `TomCloseAdaptor` requires the target's class to carry `@tomReflector` and to have been through `build_runner`, so it cannot wrap a type from outside your own build no matter what methods that type declares; an unreflectable target raises a `TomReflectorException` from the constructor

---

## Dependencies

`tom_shutdown_cleanup.dart` is the module's only source file. Its imports:

| Dependency | Kind | Used for |
| ---------- | ---- | -------- |
| [**Reflection Module**](../reflection/reflection.md) | kernel module | The global `tomReflector`, which is how `TomCloseAdaptor` finds a `close`/`dispose` method on an object that implements neither interface |
| [**Little Things Module**](../little_things/little_things.md) | kernel module | `tomGetStackTrace`, which formats and depth-limits the trace attached to a failed cleanup's diagnostic |
| `tom_reflection` | package | `ClassMirror`, walked up the supertype chain by the adaptor — `ClassMirror.declarations` holds only a type's *own* members, so an inherited `close` needs the walk |
| `tom_basics` | package | `tomLog`, for the module's only log line — the breadcrumb [`start()`](#start--an-optional-log-breadcrumb) writes. Nothing logs during shutdown itself; those diagnostics are `print` |
| `dart:io` | SDK | `ProcessSignal` — the whole signal-handling half of the module, and what makes it native-only |
| `dart:async` | SDK | `StreamSubscription`, held per registered signal so the handlers can be cancelled |

The reflection rows are the ones that cost something: `tomReflector` answers
from generated reflection data, so a package registering objects through
`TomCloseAdaptor` needs a **`build_runner` step**. Objects that implement
[`TomClosable` or `TomDisposable`](#interfaces) directly need none of it — the build step is the price of the adaptor, not of the module.

Note what is *not* here. The module does not depend on the
[logging module](../logging/logging.md): its one log line — the breadcrumb
[`start()`](#start--an-optional-log-breadcrumb) writes, which is not part of
shutdown at all — goes through `tomLog`, the live global from `tom_basics`,
which needs no wiring. Nor does it depend on the
[observable module](../observable/observable.md): `tomReflector` belongs to the
reflection module and is imported from there directly. Observable re-exports
it, which is the only reason the two are ever confused.
