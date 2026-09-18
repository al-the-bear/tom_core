# observing

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The bridge from the kernel observation model to Flutter. These adaptors let a
kernel `TomObservable` drive a Flutter rebuild — either directly as a widget
(`TomObservingWidget`) or by adapting to Flutter's `ValueListenable` contract
(`ValueListenableObserver`).

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomObservingWidget<T extends TomObservable>` | A `StatefulWidget` that registers as a `TomObserver` on its `subState` and re-invokes its `builder` on every notification. An optional `child` is built **once** by the parent and handed to the builder on every rebuild — the hoisting escape hatch `ValueListenableBuilder` and `AnimatedBuilder` also provide, for the part of a subtree that does not depend on the observable. |
| `TomObservingWidgetState<T>` | The backing `State` that holds the observer registration. |
| `ValueListenableObserver<T extends TomObservable>` | Adapts a `TomObservable` to `ValueListenable<T>` so it can feed a `ValueListenableBuilder`/`AnimatedBuilder`. A real multicast `Listenable`: `addListener` appends and `removeListener` removes the callback it is given, so one adaptor serves any number of consumers. **Subscribes in its constructor**, so an adaptor held beyond one build must be ended with `dispose()` — `removeListener` unregisters one listener and leaves the kernel registration in place. Bound to one observable for life (`observable` is `final`); `value` is the reader. |

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

Widget build(BuildContext context) {
  final showForm = TomBool(false);

  // Rebuilds whenever `showForm` notifies its observers.
  return TomObservingWidget<TomBool>(
    subState: showForm,
    builder: (s, _) => ~s ? const Text('form') : const SizedBox.shrink(),
  );

  // elsewhere: showForm | true;  // the widget rebuilds
}
```

## Hoisting the part that does not change

```dart
TomObservingWidget<TomInt>(
  subState: progress,
  child: const ExpensiveChart(),      // built once
  builder: (value, child) => Column(
    children: [Text('${~value}%'), child!],
  ),
);
```

The same widget instance travels through every rebuild — `child` is built in the
parent's `build`, untouched by this widget's `setState` — and Flutter skips
rebuilding a child whose widget is identical to the one already there. So what
is saved is the subtree's element rebuild, not merely a closure call. `builder`'s
second parameter is nullable because `child` is optional.

---

Part of [`tom_core_flutter`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
