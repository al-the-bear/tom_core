# little_things

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The kernel's grab-bag of small cross-cutting helpers: the base exception type
every Tom exception derives from, stack-trace formatting, zone-object lookup,
and assorted formatting utilities.

## Key types & functions

| Symbol | Responsibility |
| ------ | -------------- |
| `TomException` | Base, loggable exception type for the framework. |
| `getObjectFromCurrentZone(Type)` | Fetch a value stored in the current zone by type. |
| `tomGetStackTrace([s, depth])` | Render a (trimmed) stack trace as a string. |
| `tomGetStackTraceAsList([s, depth])` | Same, as a list of frames. |
| `tomPrintStackTrace(s, {message, depth})` | Print a trimmed stack trace. |
| `convertMinutesToUtcOffset(minutes)` | Format a minute offset as `±HH:MM`. |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  print(convertMinutesToUtcOffset(540)); // +09:00

  try {
    // (errorKey, default user message)
    throw TomException('error.save.failed', 'Could not save the record');
  } on TomException catch (e) {
    print('${e.key}: ${e.defaultUserMessage}');
    // error.save.failed: Could not save the record
  }
}
```

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
