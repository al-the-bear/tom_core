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

TomShutdownCleanup
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

Throws an `Exception` if the class is not reflectable (a
`TomReflectorException` naming the type and the annotation), if no
close/dispose method is found, or if the method requires parameters.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `closableObject` | `final Object` | The object being adapted for closure. Fixed at construction — the adaptor binds its mirrors to this object once, so it always names the object `close()` will actually close. Build another adaptor to close another object. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `close` | `FutureOr<void> close()` | *(override)* Invokes the resolved close/dispose method on the wrapped object, handing on the `Future` an asynchronous target returns. |

### TomShutdownCleanup

Central coordinator for graceful shutdown cleanup. Automatically listens for
SIGHUP and SIGINT; on the first signal (or a manual `performShutdown`) it runs
signal handlers, then closables, then disposables, exactly once — awaiting each
entry, within `phaseTimeout` per phase.

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
| `silent` | `bool` | When true, suppresses output messages during shutdown — status messages, failure reports and phase-timeout reports (default `false`). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `performShutdown` | `Future<void> performShutdown({ProcessSignal signal = ProcessSignal.sigint, bool fromSignal = false})` | Runs the cleanup once across the instance's life and completes when every entry has finished or its phase was abandoned; every later call gets the same shutdown. The manual path (`fromSignal` false) always runs quietly, the signal path honours `paused` and `silent`. Never await it from inside an entry. |
| `addSignalHandler` | `void addSignalHandler(TomSignalHandler handler)` | Adds a custom signal handler, executed first (before closables and disposables). |
| `addClosable` | `void addClosable(TomClosable closable)` | Adds a closable object, closed after signal handlers but before disposables. |
| `addDisposable` | `void addDisposable(TomDisposable disposable)` | Adds a disposable object, disposed last. |
| `addSignal` | `void addSignal(ProcessSignal processSignal)` | Registers an additional OS signal to listen for (SIGHUP and SIGINT are registered by default). Idempotent per signal — a repeat registration does nothing. |
| `cancelAll` | `Future<void> cancelAll()` | Cancels every registered OS-signal watcher subscription; safe to call more than once. |
| `dispose` | `Future<void> dispose()` | Tears the instance down by cancelling its signal watchers (delegates to `cancelAll`). |

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `TomSignalHandler` | `typedef TomSignalHandler = FutureOr<void> Function(ProcessSignal onData)` | Handler function type for processing system signals; the `onData` parameter carries the received signal. An `async` handler is awaited before the next handler runs. |
| `tomShutdownCleanup` | `final TomShutdownCleanup tomShutdownCleanup` | Global default `TomShutdownCleanup` instance, automatically listening for SIGHUP and SIGINT. |
