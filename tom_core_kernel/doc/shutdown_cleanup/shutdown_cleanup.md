# Shutdown Cleanup Module

The shutdown cleanup module provides a comprehensive system for managing graceful process termination in Tom applications. It ensures that resources are properly released and cleanup handlers are executed in an orderly fashion before the process exits.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
  - [Interfaces](#interfaces)
  - [TomCloseAdaptor](#tomcloseadaptor)
  - [TomShutdownCleanup](#tomshutdowncleanup)
    - [One shutdown per instance](#one-shutdown-per-instance)
    - [paused and silent](#paused-and-silent)
    - [output](#output)
    - [phaseTimeout](#phasetimeout)
    - [Exiting after a signal](#exiting-after-a-signal)
    - [Taking a registration back](#taking-a-registration-back)
    - [Tearing an instance down — dispose() and cancelAll()](#tearing-an-instance-down--dispose-and-cancelall)
    - [There is no arming step](#there-is-no-arming-step)
- [Usage Examples](#usage-examples)
  - [Basic Resource Cleanup](#basic-resource-cleanup)
  - [Custom Signal Handlers](#custom-signal-handlers)
  - [Multiple Cleanup Instances](#multiple-cleanup-instances)
  - [Server Application Pattern](#server-application-pattern)
- [Execution Order](#execution-order)
  - [Asynchronous teardown](#asynchronous-teardown)
- [Best Practices](#best-practices)
  - [1. Register Early](#1-register-early)
  - [2. Use Appropriate Interfaces](#2-use-appropriate-interfaces)
  - [3. Handle Errors Inside a Handler That Has More To Do](#3-handle-errors-inside-a-handler-that-has-more-to-do)
  - [4. Put What Must Run Ahead of What Might Hang](#4-put-what-must-run-ahead-of-what-might-hang)
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

Every entry may be asynchronous, and each is awaited before the next one is
called. Each of the three phases has a time budget,
[`phaseTimeout`](#phasetimeout), so an entry that never finishes costs the rest
of its phase rather than the whole shutdown.

The system is designed to be fault-tolerant—if one cleanup operation fails, it
reports the failure and continues with the remaining operations. The report
names the phase, the entry, the exception and the top frames of its stack, and
goes to the instance's [`output`](#output) — `print` unless the host supplies
another sink; setting `silent` suppresses it.

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

Both return `FutureOr<void>`, so an implementation may be synchronous or
`async`. The shutdown awaits an asynchronous one before it moves on — see
[Asynchronous teardown](#asynchronous-teardown).

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

  // Awaited: the socket has closed before the next closable is called.
  @override
  Future<void> close() async {
    await _socket?.close();
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

Every failure surfaces in the constructor — at registration, not during the
shutdown — as a `TomException` with a key and the target's type in its
parameters:

| Key | Exception | When |
| --- | --------- | ---- |
| `shutdown_cleanup.close_adaptor.not_reflectable` | `TomReflectorException` | the class is not reflectable |
| `shutdown_cleanup.close_adaptor.no_close_method` | `TomCloseAdaptorException` | no `close`/`dispose`, or no method of the given name, anywhere in the chain (`method` holds the name asked for) |
| `shutdown_cleanup.close_adaptor.method_requires_parameters` | `TomCloseAdaptorException` | the method has a required parameter (`method`, `parameterCount`); a method whose parameters are all optional is accepted and called without arguments |

```dart
try {
  tomShutdownCleanup.addClosable(TomCloseAdaptor(store, config.teardownMethod));
} on TomCloseAdaptorException catch (e) {
  tomLog.warn('cannot adapt ${e.parameters?['type']}: ${e.key}');
}
```

The unreflectable case names the type and the annotation that would have
fixed it:

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
process that decides to stop on its own terms triggers teardown. It returns a
`Future` that completes once every entry has finished or its phase has been
abandoned, so the process can exit straight after it:

```dart
await tomShutdownCleanup.performShutdown();
exit(0);
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
| Reports an entry that fails, or a phase that runs out of time | unless `silent` | unless `silent` |

Either way the cleanup runs **once** per instance. Whichever route arrives
first starts it, and every later call — during the shutdown or after it — is
handed that same shutdown, so awaiting it always waits for the real thing. A
signal arriving while it runs announces itself and reports `Shutdown is already
in progress`; one arriving afterwards reports that shutdown has already been
performed.

Do not await `performShutdown()` from inside one of the entries. The entry
would be waiting for the shutdown that is waiting for the entry, and only the
phase timeout would end it.

#### One shutdown per instance

An instance is single-use. After its shutdown has run, `hasShutDown` reads
`true` for good, every later `performShutdown()` is handed that finished
shutdown, and an entry registered afterwards is kept but never runs — a
registration racing the exit is ordinary, so it is not refused, but it is too
late. Nothing resets an instance: "the cleanup runs exactly once" is what keeps
a second run from closing again what the first had closed.

```dart
await cleanup.performShutdown();
print(cleanup.hasShutDown); // true
```

`hasShutDown` is a completion record: it stays `false` while the shutdown is
still running. To wait for a shutdown someone else may have started, await
`performShutdown()` instead. A signal ignored under `paused` does not count,
and `dispose()` leaves the flag alone.

A subsystem that shuts down and starts again within one process builds a new
instance for each run and disposes the one it replaces.

#### paused and silent

Two flags on the instance, both `false` by default.

`paused` makes arriving signals do nothing. Note what it does *not* do: the
watchers stay installed, so the signal is still delivered here and still
withheld from the operating system's default handling — it is simply ignored on
arrival. Under `paused`, then, Ctrl+C neither cleans up nor stops the program.
That is the intent; the flag exists for interactive REPLs that do their own
Ctrl+C handling and need this instance to keep out of the way. Manual
`performShutdown()` is unaffected.

`silent` suppresses output. That covers the status messages, which only the
signal path emits anyway, and the per-entry failure and phase-timeout
diagnostics, which both paths emit — so a silent instance stays quiet about a
cleanup that throws or hangs. See [Limitations](#limitations) for what that
costs.

#### output

Every line the instance writes goes through one sink, `output`: the status
messages of the signal path, the per-entry failure reports, and the
phase-timeout reports. It defaults to `print`, which reaches the console even
when the logging system is among the things being torn down. A host that wants
the shutdown record in its log routes it there:

```dart
tomShutdownCleanup.output = (line) => tomLog.info(line);
```

Each call receives one complete line — a failure report carries its stack
frames in the same call, so the two cannot be separated. `silent` silences the
sink as a whole. A sink that throws — a log already closed — does not fail the
shutdown: that line goes to `print` instead, with the reason appended.

#### phaseTimeout

How long each phase — signal handlers, closables, disposables — may take. It
defaults to `TomShutdownCleanup.defaultPhaseTimeout`, ten seconds, and must be
positive.

```dart
tomShutdownCleanup.phaseTimeout = const Duration(seconds: 30);
```

The budget covers the whole phase, not each entry: the time every entry takes,
awaited or synchronous, is spent from it. When it runs out the phase is
**abandoned** — the entry being awaited is left to finish on its own and the
entries behind it in that phase are not called — and the next phase starts with
a budget of its own. The abandonment is reported unless `silent`:

```text
Abandoned the closable phase after 10000 ms: Instance of 'PeerConnection' had not finished, 2 entries behind it not called
```

An abandoned entry that fails later is still reported, marked `(after its phase
abandoned it)`. A synchronous entry cannot be interrupted: one that overruns
the budget runs to its end, and the entries behind it are then abandoned.

#### Exiting after a signal

Watching a signal replaces its default action, so a signal this instance
handles does not terminate the process — the cleanup runs, and the program
carries on. An application that should stop on Ctrl+C exits once the shutdown
has finished. A handler can arrange that without awaiting anything itself,
because `performShutdown()` hands it the shutdown already under way:

```dart
tomShutdownCleanup.addSignalHandler((signal) {
  unawaited(tomShutdownCleanup.performShutdown().then((_) => exit(0)));
});
```

#### Taking a registration back

`addSignalHandler`, `addClosable` and `addDisposable` each return a
`TomShutdownUnregister` — a `void Function()` that takes that one registration
back, the way `cancel` takes back a stream subscription. Use it for a resource
the application closes and releases on its own before the process ends; left
registered, the coordinator would hold it for its whole life — for the global,
the life of the process — and close it a second time at exit.

```dart
final session = await openSession();
final unregister = tomShutdownCleanup.addClosable(session);

// …the session ends normally, long before the process does:
await session.close();
unregister();
```

It removes only the registration it was returned for: the same object
registered twice is two registrations. Calling it again, or after the shutdown,
does nothing. An entry unregistered while a shutdown runs is not called if its
phase has not reached it yet, and an entry registered while its phase runs is
still called.

#### Tearing an instance down — dispose() and cancelAll()

`cancelAll()` releases everything the instance holds: it cancels every signal
watcher — the two the constructor installed and any added with `addSignal()` —
and drops every registered handler, closable and disposable. `dispose()` is the
same operation under the name callers look for — it delegates and adds nothing.
Both are safe to call more than once.

Call one of them for **any instance whose lifetime is shorter than the
process**. A live watcher keeps the process alive, so an undisposed instance
stops the program from exiting, and the symptom is a hang rather than an error.
The global `tomShutdownCleanup` is the exception: it is meant to last as long
as the program, so it is never disposed.

Neither method runs the cleanup. Disposing lets the registered entries go
without closing them, so a `performShutdown()` afterwards finds nothing to do;
call `performShutdown()` first if the resources still need releasing. It
empties the instance without spending it — a registration made afterwards is
held again and a later manual shutdown runs it — and a disposed instance no
longer keeps anything that was registered on it reachable.

#### There is no arming step

A constructed instance is already listening. `TomShutdownCleanup()` installs
the SIGHUP and SIGINT watchers, so `addClosable`/`addDisposable`/
`addSignalHandler` are the whole of the setup and there is no call whose
position in the sequence matters.

That is worth stating because it is easy to assume otherwise, and there is no
`start()` to reach for: a method of that name would imply a lifecycle this
class has not got, and would do nothing but write a log line. A server that
wants a "cleanup is wired up" breadcrumb writes that line itself, where it is
one statement rather than a method whose name contradicts its body.

The corollary is the one thing a caller *does* have to remember: because
construction arms, a short-lived instance leaks its watchers unless it is
disposed. See [`dispose()`](#tearing-an-instance-down--dispose-and-cancelall).

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

Closing an `HttpServer` gracefully is asynchronous, and the shutdown awaits it,
so the server is simply registered. Everything behind it in the closables phase
— the database the requests were using, say — is closed only once the server
has stopped taking requests:

```dart
class ServerCloser implements TomClosable {
  ServerCloser(this._server);
  final HttpServer _server;

  @override
  Future<void> close() => _server.close(force: false);
}

Future<void> main() async {
  final server = await HttpServer.bind('localhost', 8080);
  final database = await Database.connect();

  tomShutdownCleanup
    ..addClosable(ServerCloser(server))
    ..addClosable(database)
    // Exit once the whole shutdown has finished — see "Exiting after a signal".
    ..addSignalHandler((signal) {
      unawaited(tomShutdownCleanup.performShutdown().then((_) => exit(0)));
    });

  await for (final request in server) {
    handleRequest(request);
  }
}
```

A graceful close waits for the requests in flight. If they can outlast the
phase budget, the phase is abandoned at the server and the database is never
closed — so either raise [`phaseTimeout`](#phasetimeout) or close with
`force: true` once a deadline of your own has passed.

## Execution Order

When a signal is received, cleanup operations execute in this order:

1. **Signal Handlers** - Custom functions added via `addSignalHandler()`
2. **Closables** - Objects added via `addClosable()`
3. **Disposables** - Objects added via `addDisposable()`

Within each category, items are processed in the order they were registered.

### Asynchronous teardown

A signal handler, a `close()` and a `dispose()` may each return a `Future`, and
the shutdown awaits it before it calls the next entry:

```dart
tomShutdownCleanup.addSignalHandler((signal) async {
  await flushJournal();   // finished before closeSockets() starts
  await closeSockets();   // finished before the closables phase begins
});
```

A synchronous entry is never awaited, so a phase of synchronous entries runs
straight through without yielding to the event loop.

A failure inside the returned future is reported exactly like a synchronous
throw — the phase, the entry, the exception and its stack — and the phase goes
on with the next entry. Nothing escapes as an unhandled asynchronous error.

The wait is bounded by [`phaseTimeout`](#phasetimeout). An entry that has not
finished when its phase's budget runs out is abandoned along with the entries
behind it, and the shutdown continues with the next phase.

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

### 4. Put What Must Run Ahead of What Might Hang

Entries run one after another, and a phase that runs out of time abandons
everything behind the entry it was waiting on. So within a phase, register the
teardown that must happen — flushing a journal, releasing a lease — before the
teardown that might hang, such as a graceful close of a peer connection.

Where one step has a sensible deadline of its own, impose it inside the entry;
it is awaited, so the deadline holds, and the entries behind it keep the rest
of the budget:

```dart
tomShutdownCleanup.addSignalHandler((signal) async {
  await slowCleanupOperation().timeout(
    const Duration(seconds: 2),
    onTimeout: () => print('gave up on the slow cleanup'),
  );
});
```

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

- A phase that overruns [`phaseTimeout`](#phasetimeout) is abandoned: the entry it was waiting on is left running and the entries behind it are not called. A synchronous entry cannot be interrupted at all
- A handled signal does not terminate the process; the application exits when the shutdown has finished — see [Exiting after a signal](#exiting-after-a-signal)
- Every line goes through one sink, [`output`](#output), which defaults to `print` rather than the logging system so the record survives a logger that is already closed; a host routes it into its log by supplying the sink, and a sink that throws falls back to `print` for that line
- `silent` suppresses the failure diagnostics along with the status messages, so a silent instance says nothing when a cleanup throws — the cleanup still continues, but the reason it failed is gone
- A failure's stack trace is cut to its top ten frames, enough to identify the failing `close()`/`dispose()` but not to follow a deep call chain
- Cleanup executes only once per instance — every later call or signal is handed the same shutdown, and nothing resets it; a restarted subsystem uses a new instance
- On some platforms, certain signals may not be available
- `TomCloseAdaptor` requires the target's class to carry `@tomReflector` and to have been through `build_runner`, so it cannot wrap a type from outside your own build no matter what methods that type declares; an unreflectable target raises a `TomReflectorException` from the constructor

---

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | every file | `FutureOr`, the return type of the three contracts; `Timer` and `Completer`, which bound a phase by `phaseTimeout`; `StreamSubscription`, held per registered signal so the handlers can be cancelled |
| `dart:io` | dart | every file | `ProcessSignal` — the whole signal-handling half of the module, and what makes it native-only |
| `tom_reflection` | package | every file | `ClassMirror`, walked up the supertype chain by the adaptor — `ClassMirror.declarations` holds only a type's *own* members, so an inherited `close` needs the walk |
| [little_things](../little_things/little_things.md) | module | every file | `tomGetStackTrace`, which formats and depth-limits the trace attached to a failed cleanup's diagnostic, and `TomException`, the base of `TomCloseAdaptorException` |
| [reflection](../reflection/reflection.md) | module | every file | The global `tomReflector`, which is how `TomCloseAdaptor` finds a `close`/`dispose` method on an object that implements neither interface |

`tom_shutdown_cleanup.dart` is the module's only source file. Its imports:

The reflection rows are the ones that cost something: `tomReflector` answers
from generated reflection data, so a package registering objects through
`TomCloseAdaptor` needs a **`build_runner` step**. Objects that implement
[`TomClosable` or `TomDisposable`](#interfaces) directly need none of it — the build step is the price of the adaptor, not of the module.

Note what is *not* here. The module logs nothing itself — its shutdown
diagnostics go to `output`, which is `print` unless the host supplies a sink,
because a logger may already be closed by the time they run — so it depends on
neither `tom_basics` nor the [logging module](../logging/logging.md). Nor does it depend on the
[observable module](../observable/observable.md): `tomReflector` belongs to the
reflection module and is imported from there directly. Observable re-exports
it, which is the only reason the two are ever confused.
