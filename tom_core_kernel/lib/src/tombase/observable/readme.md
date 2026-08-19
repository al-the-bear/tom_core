# observable

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The kernel's reactive value model. A `TomObject<T>` wraps a value, broadcasts
changes to observers, and exposes a terse operator surface — `|` to set, `~` to
read, `>>` to observe — that the forms and UI layers build on.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomObservable` | Base broadcaster; notifies registered observers on change. |
| `TomObject<T>` | Observable value cell; `|` set, `~` read, `>>` subscribe. |
| `TomString` / `TomInt` / `TomDouble` / `TomBool` / `TomDateTime` | Concrete non-null cells for the primitive types. |
| `TomNString` / `TomNInt` / `TomND…` | Nullable counterparts. |
| `TomOZonedTime` / `TomOZonedDate` / `TomOZonedDateTime` | Timezone-aware observable cells (see [`timezoned`](../timezoned/readme.md)). |
| `TomClass` / `TomList<E>` / `TomMap<K,V>` | Composite observables (object graph, observable list, observable map). |
| `TomObservableEnum<E>` | Enum cell whose display text is resolved from the text bundle (see [`resources`](../resources/readme.md)) — no Dart-side label table. |
| `TomObserver<T>` / `TomFunctionObserver<T>` | Observer contract and a function-backed implementation. |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  final count = TomInt(0);

  // The callback receives the observable; read its value with `~`.
  // Observers are held weakly — keep the one `>>` returns, or it is collected
  // and the callback silently stops firing.
  final observer = count >> (obs) => print('count is now ${~(obs as TomInt)}');

  count | 1; // prints: count is now 1
  count | 2; // prints: count is now 2

  print(~count); // 2

  count.removeObserver(observer);
}
```

See [Memory Management](../../../../doc/observable/observable.md#memory-management--you-must-retain-the-observer)
for the full retention contract.

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
