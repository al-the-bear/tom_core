# little_things

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The kernel's grab-bag of small cross-cutting helpers: the base exception type
every Tom exception derives from, stack-trace formatting, zone-object lookup,
error-transforming execution wrappers, and assorted formatting utilities.

## Key types & functions

This is the module's whole exported surface — two classes and nine functions.

| Symbol | Responsibility |
| ------ | -------------- |
| `TomException` | Base, loggable exception type for the framework. |
| `TomFormattingException` | Raised when a formatting function is given a value it cannot render. |
| `getFromCurrentZone<T>()` | Fetch the zone value filed under the exact key `T`. |
| `getObjectFromCurrentZone(Type)` | The same lookup, key given at run time, no `is` check. |
| `runChecked(body, onError)` | Await `body`; if it throws, throw what `onError` maps the error to instead. |
| `runCheckedSync(body, onError)` | The synchronous form of `runChecked`. |
| `tomGetStackTrace([s, depth])` | Render a (trimmed) stack trace as a string. |
| `tomGetStackTraceAsList([s, depth])` | Same, as a list of frames. |
| `tomGetStackTraceAsTuple([s, depth])` | Both forms at once, as a `(String, List<String>)` record. |
| `tomPrintStackTrace(s, {message, depth})` | Log a trimmed stack trace at ERROR level. Despite the name, it does not `print`. Logs nothing when there is neither a message nor a frame. |
| `convertMinutesToUtcOffset(minutes)` | Format a minute offset as `±HH:MM`. Throws outside ±840 minutes (±14:00), which no real zone reaches — the hour field is two digits wide, so a wider offset has no valid rendering. |

The module also holds one **internal**, deliberately unexported file:
`atomic_file.dart`, the crash-safe whole-file write shared by the package's two
file-backed stores (`TomFileJobStore` and `TomFileLogReplayStore`). It stays off
the exported surface because it imports `dart:io` and because how a store
reaches the disk is not something a caller should be reaching for.

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
