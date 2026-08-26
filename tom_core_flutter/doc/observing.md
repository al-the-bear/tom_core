# Observing Module

Bridges the kernel observation model (`TomObservable` / `TomObserver`) to
Flutter's rebuild and listenable machinery. It lets observable kernel state
drive widget rebuilds directly, without `ChangeNotifier`/`ValueNotifier`
plumbing.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
- [Lifecycle and Limitations](#lifecycle-and-limitations)
- [Dependencies](#dependencies)

---

## Overview

| Type | Implements | Purpose |
| ---- | ---------- | ------- |
| `TomObservingWidget<T>` | `StatefulWidget` | Rebuilds a subtree whenever the bound `TomObservable` notifies |
| `ValueListenableObserver<T>` | `TomObserver<T>`, `ValueListenable<T>` | Adapts a `TomObservable` to Flutter's `ValueListenable` contract |

Both adapt the kernel observation primitives:

- A [`TomObservable`](../../tom_core_kernel/doc/observable/observable.md) is read
  with `~`, set with `|`, and notifies its observers on change.
- A `TomObserver<T>` receives `void onNotify(T observable)` callbacks.

## Quick Start

Rebuild a widget when an observable changes:

```dart
import 'package:tom_core_flutter/tom_core_flutter.dart';

final showForm = TomBool(false);

TomObservingWidget<TomBool>(
  subState: showForm,
  child: (state) => ~state ? const FormPanel() : const SizedBox.shrink(),
);

showForm | true; // the widget rebuilds and shows FormPanel
```

Feed an observable into any `ValueListenable` consumer:

```dart
final error = TomString('');
final adaptor = ValueListenableObserver<TomString>(error);

ValueListenableBuilder<TomString>(
  valueListenable: adaptor,
  builder: (context, value, _) => Text(~value),
);

error | 'Boom'; // the builder rebuilds with "Boom"
```

## Core Components

### `TomObservingWidget<T extends TomObservable>`

A `StatefulWidget` whose state registers as a `TomObserver` on `subState`. On
every notification it calls `setState`, re-invoking the `child` builder with the
(current) observable. The builder receives the observable itself, so read its
value with `~state` inside the closure.

| Parameter | Type | Meaning |
| --------- | ---- | ------- |
| `subState` | `T` | The observable whose notifications drive the rebuild |
| `child` | `Widget Function(T state)` | Builds the subtree from the current observable |

### `ValueListenableObserver<T extends TomObservable>`

Adapts a `TomObservable` to `ValueListenable<T>`. `value` returns the observed
observable; `addListener` registers a single callback fired on each
notification. Use it to plug kernel state into `ValueListenableBuilder`,
`AnimatedBuilder`, or anything else accepting a `ValueListenable`.

## Lifecycle and Limitations

- **Automatic registration and migration.** `TomObservingWidgetState` follows the
  standard `State` lifecycle: it registers its observer in `initState`, migrates
  the registration to the new observable in `didUpdateWidget` when the parent
  rebuilds with a different `subState` (dropping the old one), and deregisters in
  `dispose`. A mutation after the widget unmounts therefore never triggers
  `setState() called after dispose()`.
- **Which side holds which.** The two references point in opposite directions,
  and confusing them leads to reasoning about observer lifetime backwards:
  - The **observable holds its observers weakly**. `addObserver` stores a
    `WeakReference`, and `notifyObservers` prunes the ones whose target has been
    collected — so registering never kept the widget's `State` alive, and
    deregistering is not what releases it. See the kernel's
    [Memory Management](../../tom_core_kernel/doc/observable/observable.md#memory-management--you-must-retain-the-observer).
  - The **widget holds the observable strongly**, through the plain
    `final T subState` field. So for as long as the element is mounted, it is
    the *observable* that is kept alive by the widget — never the other way
    round. `dispose` removing the registration does nothing about that
    reference; unmounting the widget is what drops it.
- **Deregistration buys promptness, not leak prevention.** Because the
  registration was weak all along, the `removeObserver` in `dispose` is not
  standing between the application and a leak. What it buys is a *known moment*:
  notifications stop when the widget leaves the tree rather than whenever the
  collector next runs, which is what keeps a post-unmount mutation from reaching
  a disposed `State`. The corollary is the part worth remembering — an observer
  that is still reachable but no longer wanted **keeps receiving notifications
  for as long as something else holds it**. Collection is not a substitute for
  removing it.
- **`ValueListenableObserver` holds a single listener.** `addListener` replaces
  any prior callback rather than appending; it is not a multicast
  `ValueListenable`. This matches its intended use with a single
  `ValueListenableBuilder`.

---

## Dependencies

- **`tom_core_kernel`**: `TomObservable` and `TomObserver`, the observation
  primitives both adapters bridge.
- **`flutter`**: `StatefulWidget`/`State` and `ValueListenable`.
