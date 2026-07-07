# runtime

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Compile-time platform detection for the Flutter client. A single conditional
import picks the right `TomPlatformUtils` implementation — native IO on
desktop/mobile, web in the browser, or a neutral fallback — exposed through the
`clientPlatformUtils` getter.

## Key types

| Type / member | Responsibility |
| ------------- | -------------- |
| `clientPlatformUtils` | Getter returning a fresh `TomPlatformUtils` whose concrete type is selected at compile time. Register it process-wide at startup. |
| `TomFlutterPlatformUtils` | The concrete `TomPlatformUtils` subtype; three variants live in `platform_detection_flutter_io.dart` (`dart:io`), `platform_detection_web.dart` (`dart:js`), and `platform_detection_neutral.dart` (fallback). |

The conditional import in `platform_detection_client.dart` is the seam:

```dart
import 'platform_detection_neutral.dart'
    if (dart.library.io) 'platform_detection_flutter_io.dart'
    if (dart.library.js) 'platform_detection_web.dart';
```

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

void main() {
  // Register the compile-time-selected platform as the process-wide platform.
  TomPlatformUtils.setCurrentPlatform(clientPlatformUtils);

  // Now platform predicates answer for the current target:
  print(TomPlatformUtils.current.isWeb()); // true in the browser
}
```

---

Part of [`tom_core_flutter`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
