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
| `runChecked(body, onError)` | Await `body`; if it throws an `Exception`, throw the `Exception` `onError` maps it to instead. An `Error` is a bug rather than a condition and propagates unchanged. |
| `runCheckedSync(body, onError)` | The synchronous form of `runChecked`, with the same `Exception`-only rule. |
| `tomGetStackTrace([s, depth])` | Render a (trimmed) stack trace as a string. |
| `tomGetStackTraceAsList([s, depth])` | Same, as a list of frames. |
| `tomGetStackTraceAsTuple([s, depth])` | Both forms at once, as a `(String, List<String>)` record. |
| `TomStackTraceNoise` | Classifies a stack frame as noise. The built-in set folds core frames, `shelf`, `TomLogger.*` and this library's own formatters; a consumer registers its own layer on top. |
| `tomStackTraceNoise` | The process-wide `TomStackTraceNoise` every formatter here reads, so a registration reaches the traces the framework formats for itself. |
| `tomPrintStackTrace(s, {message, depth})` | Log a trimmed stack trace at ERROR level. Despite the name, it does not `print`. Logs nothing when there is neither a message nor a frame. |
| `convertMinutesToUtcOffset(minutes)` | Format a minute offset as `±HH:MM`. Throws outside ±840 minutes (±14:00), which no real zone reaches — the hour field is two digits wide, so a wider offset has no valid rendering. |

The module also holds two files that import `dart:io` and so stay off the
package barrel, serving the package's file-backed stores (`TomFileJobStore` and
`TomFileLogReplayStore`):

- `atomic_file.dart` — the crash-safe whole-file write. Content is staged in a
  per-writer sibling file and renamed over the target, so a reader sees either
  the complete previous content or the complete new one.
- `file_mutex.dart` — mutual exclusion between everything that might write one
  file. Built on exclusive file creation rather than `dart:io`'s own locks,
  which are process-scoped and so cannot separate two isolates of one process.
  A guard left behind by a killed writer is broken once it goes stale. It waits
  synchronously (`tomWithFileLock`) or without blocking its isolate
  (`tomWithFileLockAsync`), and is public through
  `package:tom_core_kernel/tom_core_kernel_io.dart` — the native-only entry
  library — together with `tomFileLockPath` and `tomFileLockStaleAfter`, so a
  framework store outside the kernel takes the same guard rather than a copy.

`atomic_file.dart` stays internal: how a store stages a write is not something a
caller should be reaching for.

## Quick start

```dart complete
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
