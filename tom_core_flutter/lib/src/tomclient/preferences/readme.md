# preferences

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Device-stored user preferences: one typed API, one backend per platform, and
the backend chosen by dependency injection instead of an `if (kIsWeb)` where the
value is read.

Some preferences must **not** follow the user — which account was last used on
this device, whether biometric unlock is on here, a layout choice that is right
on the tablet and wrong on the phone. This module is where those live. The
per-*user* store is the server's (`TomUserPreferences`, `tom_core_server`); the
keys, the wire DTO and the value codec are the kernel's, so the two stores share
one vocabulary and one encoding rather than two that agree by inspection.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomDevicePreferences` | The interface: `all` / `read` / `get` / `getOr` / `set` / `remove` / `clear`, plus `getPreferred` for the documented device-over-server precedence. Resolved as a bean. |
| `TomStoredDevicePreferences` | The shipped implementation — the typed API over a store; holds the single encode/decode decision. |
| `TomDevicePreferenceStore` | The narrow backend: `read()` / `write()` of the whole set. The only platform-specific part of the module. |
| `TomPlatformDevicePreferenceStore` | The backend for the current target, chosen by conditional export: a JSON file on desktop/mobile, a `localStorage` entry on the web, a loud failure elsewhere. |
| `TomMemoryDevicePreferenceStore` | A store that persists nothing beyond the process — for tests, examples, and clients that deliberately keep no machine-local state. |
| `TomDevicePreferenceJson` | The stored JSON document, written once so every persistent backend stores the same text. |
| `TomDevicePreferenceException` | `device_preferences.unsupported_platform`, `device_preferences.store.invalid_content`. |

## Quick start

```dart
import 'package:tom_core_flutter/tom_core_flutter.dart';

Future<void> main() async {
  // Register once at startup — the only line that knows about storage.
  TomBean.withType(
    TomDevicePreferences,
    TomStoredDevicePreferences(
      TomPlatformDevicePreferenceStore('$supportDirectory/preferences.json'),
    ),
  );

  // Every call site from here on is platform-independent.
  final preferences = TomDevicePreferences.resolve()!;
  await preferences.set('device.biometricUnlock', true);

  final unlock = await preferences.getOr('device.biometricUnlock', false);
  print(unlock); // true
}
```

`TomPlatformDevicePreferenceStore` takes one `location` on every platform — a
filesystem path where there is a filesystem, a `localStorage` entry name in the
browser — so the construction above is written once and never branches.

## Precedence

Where a key exists in both stores, **the device value wins for as long as it
exists**; the server value answers only a key this device has never written.
Writing here is the later, more specific act, so the account value behaves as a
cross-device default and the device value as this machine's override. The rule
is stated on `TomDevicePreferences` and applied in `getPreferred` — no caller
re-derives it.

---

Part of [`tom_core_flutter`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
