# little_things

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The kernel's grab-bag of small cross-cutting helpers: the base exception type
every Tom exception derives from, stack-trace formatting, zone-object lookup,
error-transforming execution wrappers, and assorted formatting utilities.

## Key types & functions

This is the module's whole exported surface — one class and nine functions.

| Symbol | Responsibility |
| ------ | -------------- |
| `TomException` | Base, loggable exception type for the framework. |
| `getFromCurrentZone<T>()` | Fetch the zone value filed under the exact key `T`. |
| `getObjectFromCurrentZone(Type)` | The same lookup, key given at run time, no `is` check. |
| `runChecked(body, onError)` | Await `body`; if it throws, throw what `onError` maps the error to instead. |
| `runCheckedSync(body, onError)` | The synchronous form of `runChecked`. |
| `tomGetStackTrace([s, depth])` | Render a (trimmed) stack trace as a string. |
| `tomGetStackTraceAsList([s, depth])` | Same, as a list of frames. |
| `tomGetStackTraceAsTuple([s, depth])` | Both forms at once, as a `(String, List<String>)` record. |
| `tomPrintStackTrace(s, {message, depth})` | Log a trimmed stack trace at ERROR level. Despite the name, it does not `print`. Logs nothing when there is neither a message nor a frame. |
| `convertMinutesToUtcOffset(minutes)` | Format a minute offset as `±HH:MM`. |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  print(convertMinutesToUtcOffset(540)); // +09:00

  try {
    // (error key, default user message)
    throw TomException('record.save.failed', 'Could not save the record');
  } on TomException catch (e) {
    print('${e.key}: ${e.defaultUserMessage}');
    // record.save.failed: Could not save the record
  }
}
```

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
