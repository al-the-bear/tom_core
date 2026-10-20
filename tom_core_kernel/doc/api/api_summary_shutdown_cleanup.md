# Tom Core Kernel API Reference: Shutdown Cleanup Module

A system for managing orderly cleanup when a process receives termination
signals, coordinating custom signal handlers, closables, and disposables, with a
reflection-based adaptor for objects lacking explicit interfaces.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomDisposable](#tomdisposable)
  - [TomClosable](#tomclosable)
  - [TomCloseAdaptor](#tomcloseadaptor)
  - [TomCloseAdaptorException](#tomcloseadaptorexception)
  - [TomShutdownCleanup](#tomshutdowncleanup)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tombase/shutdown_cleanup/tom_shutdown_cleanup.dart`.

This module coordinates graceful process termination. `TomShutdownCleanup` listens
for SIGHUP and SIGINT (and any additional signals added via `addSignal`) and, on
the first signal — or on a manual `performShutdown` call — runs three cleanup
phases in order: registered signal handlers, then closables (`TomClosable`), then
disposables (`TomDisposable`). Each callout is isolated so a failing handler
never blocks the rest, and cleanup runs at most once per instance. Every entry
may be asynchronous and is awaited before the next is called; each phase has
`phaseTimeout` (ten seconds by default) to finish in, and a phase that overruns
it is abandoned while the next phase still runs. `TomClosable`
and `TomDisposable` are the interfaces objects implement to participate;
`TomCloseAdaptor` uses reflection to wrap objects that expose a `close()` /
`dispose()` (or custom-named) method without implementing those interfaces. The
`TomSignalHandler` typedef names the signal-handler function shape, and the
global `tomShutdownCleanup` instance covers most needs.

## Class Hierarchy

```
TomDisposable  (abstract interface)

TomClosable  (abstract interface)
    └── TomCloseAdaptor  (implements TomClosable)

TomException  (kernel)
    └── TomCloseAdaptorException

TomDisposable  (abstract interface)
    └── TomShutdownCleanup  (implements TomDisposable)
```

## Classes

### TomDisposable

Interface for objects that need cleanup logic executed when the process
terminates. `dispose` is called automatically by `TomShutdownCleanup`.

- **Kind:** abstract class, used as an interface.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `dispose` | `FutureOr<void> dispose()` | Disposes of resources held by this object; called automatically during shutdown cleanup. May be asynchronous — a returned `Future` is awaited before the next object is disposed. |

### TomClosable

Interface for objects that need to be closed when the process terminates. `close`
is called automatically by `TomShutdownCleanup`.

- **Kind:** abstract class, used as an interface.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `close` | `FutureOr<void> close()` | Closes resources (connections, streams, etc.) held by this object; called automatically during shutdown cleanup. May be asynchronous — a returned `Future` is awaited, within the phase's `phaseTimeout`, and a failure inside it is reported like a thrown one. |

### TomCloseAdaptor

Adaptor that wraps objects with `close`/`dispose` methods to implement
`TomClosable`, using the global `tomReflector` to find and invoke the method.
The target method must have no required parameters, and the target's class must
carry `@tomReflector` and have been through `build_runner` — so the adaptor
applies to classes in your own build, not to types from outside it. Wrap a type
you do not own in a class of your own implementing `TomClosable` instead.

- **Implements:** `TomClosable`

#### Constructors

```dart
TomCloseAdaptor(Object closableObject, [String? methodName])
```

Throws at construction, with the target's runtime type as the `type`
parameter in every case:

| Key | Exception | When | Other parameters |
| --- | --------- | ---- | ---------------- |
| `shutdown_cleanup.close_adaptor.not_reflectable` | `TomReflectorException` | the class is not reflectable — not annotated with `@tomReflector`, or its generated data not initialized | — |
| `shutdown_cleanup.close_adaptor.no_close_method` | `TomCloseAdaptorException` | no `close`/`dispose` — or no method of the given name — anywhere in the class's chain | `method`: the name asked for, or `null` |
| `shutdown_cleanup.close_adaptor.method_requires_parameters` | `TomCloseAdaptorException` | the method has a required parameter; one whose parameters are all optional is accepted | `method`, `parameterCount` |

All three are `TomException`s.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `closableObject` | `final Object` | The object being adapted for closure. Fixed at construction — the adaptor binds its mirrors to this object once, so it always names the object `close()` will actually close. Build another adaptor to close another object. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `close` | `FutureOr<void> close()` | *(override)* Invokes the resolved close/dispose method on the wrapped object, handing on the `Future` an asynchronous target returns. |

### TomCloseAdaptorException

Raised by the `TomCloseAdaptor` constructor when the target has no method the
adaptor can call. Keys `shutdown_cleanup.close_adaptor.no_close_method` and
`shutdown_cleanup.close_adaptor.method_requires_parameters`; the target's
`type` and the `method` concerned are in `parameters`.

- **Extends:** `TomException`

```dart
TomCloseAdaptorException(String key, String defaultUserMessage, {Map<String, Object?>? parameters, StackTrace? stack, Object? rootException, bool autoLog = false, String? uuid, TomServerCallError? serverCallError})
```

### TomShutdownCleanup

Central coordinator for graceful shutdown cleanup, single-use by design: it runs
one shutdown and is then spent. Automatically listens for
SIGHUP and SIGINT; on the first signal (or a manual `performShutdown`) it runs
signal handlers, then closables, then disposables, exactly once — awaiting each
entry, within `phaseTimeout` per phase. It is a `TomDisposable`, so one
coordinator can be registered on another: the outer shutdown disposes the inner
one — watchers cancelled, registrations dropped, nothing run. To run the inner
shutdown too, register `(signal) => inner.performShutdown(signal: signal)` as a
signal handler on the outer.

- **Implements:** `TomDisposable`

#### Constructors

```dart
TomShutdownCleanup()
```

#### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `defaultPhaseTimeout` | `static const Duration` | The `phaseTimeout` a new instance starts with: ten seconds. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `phaseTimeout` | `Duration` | How long each phase may take before it is abandoned — the entry being awaited is left to finish on its own and the entries behind it are not called. Covers the whole phase, synchronous entries included. Must be positive; a zero or negative value throws `ArgumentError`. Default `defaultPhaseTimeout`. |
| `paused` | `bool` | When true, signal handling is paused and signals are ignored (for REPLs with their own CTRL-C handling) (default `false`). |
| `silent` | `bool` | When true, suppresses output messages during shutdown — every line `output` would receive: status messages, failure reports and phase-timeout reports (default `false`). |
| `output` | `void Function(String line)` | The one sink every line goes to — status messages, failure reports (with their stack frames in the same call), phase-timeout reports. Default `print`. A sink that throws does not fail the shutdown; that line goes to `print` with the reason. |
| `exitAfterSignalShutdown` | `bool` | When true, a shutdown started by a signal ends the process with `exitProcess(0)` once every phase has run (finished or abandoned). A shutdown started by calling `performShutdown` never exits. Off by default — a library cannot know nothing else in the process still has work; a server sets it so SIGTERM ends in a clean exit rather than a kill at the end of the grace period (default `false`). |
| `exitProcess` | `void Function(int code)` | How the process is ended when `exitAfterSignalShutdown` applies. Default `dart:io`'s `exit`; replaceable so a test can observe the exit instead of performing it. |
| `hasShutDown` | `bool` *(read-only)* | Whether the shutdown has run to its end, every phase finished or abandoned. `false` while it is still running; once `true` it never turns back — the instance is single-use, and an entry registered afterwards never runs. Unaffected by a signal ignored under `paused` and by `dispose`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `performShutdown` | `Future<void> performShutdown({ProcessSignal signal = ProcessSignal.sigint, bool fromSignal = false})` | Runs the cleanup once across the instance's life and completes when every entry has finished or its phase was abandoned; every later call gets the same shutdown. The manual path (`fromSignal` false) always runs quietly, the signal path honours `paused` and `silent`. Never await it from inside an entry. |
| `addSignalHandler` | `TomShutdownUnregister addSignalHandler(TomSignalHandler handler)` | Adds a custom signal handler, executed first (before closables and disposables). Returns the canceller for this registration. |
| `addClosable` | `TomShutdownUnregister addClosable(TomClosable closable)` | Adds a closable object, closed after signal handlers but before disposables. Returns the canceller for this registration. |
| `addDisposable` | `TomShutdownUnregister addDisposable(TomDisposable disposable)` | Adds a disposable object, disposed last. Returns the canceller for this registration. |
| `addSignal` | `void addSignal(ProcessSignal processSignal)` | Registers an additional OS signal to listen for (SIGHUP and SIGINT are registered by default). Idempotent per signal — a repeat registration does nothing. |
| `cancelAll` | `Future<void> cancelAll()` | Releases everything the instance holds: cancels every OS-signal watcher and drops every registered handler, closable and disposable, without running them. Empties the instance without spending it — a later registration is held again. Safe to call more than once. |
| `dispose` | `Future<void> dispose()` | *(override)* Tears the instance down; the same operation as `cancelAll`. `TomDisposable`'s method, so a coordinator registered on another is disposed by the outer shutdown. |

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `TomSignalHandler` | `typedef TomSignalHandler = FutureOr<void> Function(ProcessSignal onData)` | Handler function type for processing system signals; the `onData` parameter carries the received signal. An `async` handler is awaited before the next handler runs. |
| `TomShutdownUnregister` | `typedef TomShutdownUnregister = void Function()` | Returned by the three `add*` methods; takes back the one registration it was returned for and releases the coordinator's reference to the entry. Calling it again, or after the entry has run, does nothing. |
| `tomShutdownCleanup` | `final TomShutdownCleanup tomShutdownCleanup` | Global default `TomShutdownCleanup` instance, automatically listening for SIGHUP and SIGINT. |
