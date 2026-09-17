# Tom Core Flutter API Reference: Observing Module

Bridges the kernel observation model (`TomObservable` / `TomObserver`) to
Flutter's rebuild and `ValueListenable` contracts.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomObservingWidget&lt;T&gt;](#tomobservingwidgett)
  - [TomObservingWidgetState&lt;T&gt;](#tomobservingwidgetstatet)
  - [ValueListenableObserver&lt;T&gt;](#valuelistenableobservert)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomclient/observing/tom_observing_widget.dart`,
`lib/src/tomclient/observing/value_listenable_observer.dart`.

`TomObservingWidget` rebuilds a subtree whenever a `TomObservable` notifies,
managing observer registration across the standard `State` lifecycle.
`ValueListenableObserver` adapts a `TomObservable` to Flutter's
`ValueListenable`, so kernel state can drive a `ValueListenableBuilder` or
`AnimatedBuilder`.

## Class Hierarchy

```
StatefulWidget  (Flutter)
    └── TomObservingWidget<T extends TomObservable>

State<TomObservingWidget<T>>  (Flutter) + TomObserver
    └── TomObservingWidgetState<T extends TomObservable>

TomObserver<T> + ValueListenable<T>
    └── ValueListenableObserver<T extends TomObservable>
```

## Classes

### TomObservingWidget&lt;T&gt;

A widget that rebuilds whenever its observable `subState` notifies.

- **Extends:** `StatefulWidget`
- **Type Parameters:** `T extends TomObservable`

#### Constructors

```dart
TomObservingWidget({
  required Widget Function(T state) child,
  required T subState,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `child` | `Widget Function(T state)` | Builds the subtree from the current observable state. |
| `subState` | `T` | The observable whose notifications drive the rebuild. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `createState` | `State<StatefulWidget> createState()` | *(override)* Creates a `TomObservingWidgetState<T>`. |

### TomObservingWidgetState&lt;T&gt;

The `State` for `TomObservingWidget`; observes the current `subState` and
rebuilds on every notification. Registration follows the `State` lifecycle
(`initState` registers, `didUpdateWidget` migrates, `dispose` deregisters), so
the bridge never calls `setState` on a disposed element. The deregistration is
about *when*, not about leaks: `TomObservable` holds observers weakly, so the
registration never kept this `State` alive — while `subState` is a strong field,
so the widget keeps the observable alive. See
[Lifecycle and Limitations](../observing.md#lifecycle-and-limitations).

- **Extends:** `State<TomObservingWidget<T>>`
- **Implements:** `TomObserver`
- **Type Parameters:** `T extends TomObservable`

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `initState` | `void initState()` | *(override)* Registers as an observer on the initial `subState`. |
| `didUpdateWidget` | `void didUpdateWidget(TomObservingWidget<T> oldWidget)` | *(override)* Migrates registration when `subState` changes. |
| `dispose` | `void dispose()` | *(override)* Deregisters before the element is destroyed. |
| `build` | `Widget build(BuildContext context)` | *(override)* Invokes `child` with the current `subState`. |
| `onNotify` | `void onNotify(TomObservable observable)` | *(override)* Calls `setState` to rebuild on notification. |

### ValueListenableObserver&lt;T&gt;

Adapts a kernel `TomObservable` to Flutter's `ValueListenable` contract.

- **Implements:** `TomObserver<T>`, `ValueListenable<T>`
- **Type Parameters:** `T extends TomObservable`

> **Single-listener limitation:** holds at most one listener, and deviates from
> the `ValueListenable` contract at both ends of it. `addListener` **replaces**
> any previously registered callback rather than appending. `removeListener`
> **ignores its argument** — it clears the single slot unconditionally, so
> calling it with a listener that was never registered still silences the
> adaptor. There is one slot, so there is nothing to match against. It is not a
> general-purpose multicast `ValueListenable`.

> **Construction subscribes; `dispose` ends it.** An adaptor held beyond a
> single build — in a `State` field — **must** be disposed. `removeListener` is
> not a substitute: it clears the Flutter listener and leaves the kernel
> registration in place, so the adaptor stays on the observer list and forwards
> again as soon as the slot is refilled.

#### Constructors

```dart
ValueListenableObserver(T observable)
```

Registers this adaptor as an observer of `observable`. The subscription ends
only at `dispose`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `observable` | `T` | The kernel observable whose notifications are forwarded. |
| `voidCallback` | `void Function()?` | The single Flutter listener to invoke on each notification, if any. |
| `value` | `T` | *(override)* The current value — the observed `observable` itself. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `onNotify` | `void onNotify(T observable)` | *(override)* Forwards the notification to the registered listener. |
| `addListener` | `void addListener(VoidCallback listener)` | *(override)* Registers `listener`, replacing any previous one. |
| `removeListener` | `void removeListener(VoidCallback listener)` | *(override)* Clears the single listener slot. `listener` is ignored — any argument clears it. **Not a teardown**: the kernel registration survives it. |
| `dispose` | `void dispose()` | Ends the subscription — deregisters from `observable` and drops the listener. Required for any adaptor that outlives one build. Idempotent; after it, `addListener` fails an `assert` in debug, because a deregistered adaptor would never fire. |

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
