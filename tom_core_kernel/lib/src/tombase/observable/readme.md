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
| `TomNString` / `TomNInt` / `TomNDouble` / `TomNBool` / `TomNDateTime` | Nullable counterparts, one per primitive above. Spelled out rather than elided: an abbreviation leaves a reader unable to tell whether the cell they want exists. |
| `TomOZonedTime` / `TomOZonedDate` / `TomOZonedDateTime` | Timezone-aware observable cells (see [`timezoned`](../timezoned/readme.md)), over `TomOTimezoned<TZ>`. |
| `TomNOZonedTime` / `TomNOZonedDate` / `TomNOZonedDateTime` | Their nullable counterparts, over `TomNOTimezoned<TZ>`. |
| `TomOTimezoned<TZ>` / `TomNOTimezoned<TZ>` | The two bases the six timezone-aware cells extend. |
| `TomDateRange` / `TomTimeRange` / `TomDateTimeRange` | `TomClass` composites holding a start and an end, so a range is observed as one value rather than as two cells a reader must keep in step. |
| `TomClass` / `TomList<E>` / `TomMap<K,V>` | Composite observables (object graph, observable list, observable map). |
| `TomObservableEnum<E>` | Enum cell whose display text is resolved from the text bundle (see [`resources`](../resources/readme.md)) — no Dart-side label table. |
| `TomEnumResourceSegment` | Implemented by an enum that overrides `toString()`, to declare its resource-key segment explicitly. |
| `TomObserver<T>` / `TomFunctionObserver<T>` | Observer contract and a function-backed implementation. |
| `TomObservableObservation<T>` | The extension carrying `>>`. Its type parameter is inferred from the *receiver*, so `count >> …` on a `TomInt` hands the callback a `TomInt` rather than a `TomObservable`. |
| `TomListLifecycleListener` | Hook fired around a `TomList` teardown-and-rebuild, so a holder of per-element state can rebuild it. `TomListForm` in `tom_flutter_ui` uses it to keep sub-forms in step when `TomClass.setValues()` replaces the list. |
| `TomObservableException` | Raised by this module. |

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
