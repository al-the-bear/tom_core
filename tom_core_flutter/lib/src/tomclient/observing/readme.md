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
| `TomObservingWidget<T extends TomObservable>` | A `StatefulWidget` that registers as a `TomObserver` on its `subState` and rebuilds (`setState`) its `child` builder on every notification. |
| `TomObservingWidgetState<T>` | The backing `State` that holds the observer registration. |
| `ValueListenableObserver<T extends TomObservable>` | Adapts a `TomObservable` to `ValueListenable<T>` so it can feed a `ValueListenableBuilder`/`AnimatedBuilder`. Single-listener, deviating from the contract at both ends: `addListener` replaces rather than appends, and `removeListener` ignores its argument and clears the slot regardless. |

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
    child: (s) => ~s ? const Text('form') : const SizedBox.shrink(),
  );

  // elsewhere: showForm | true;  // the widget rebuilds
}
```

---

Part of [`tom_core_flutter`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
