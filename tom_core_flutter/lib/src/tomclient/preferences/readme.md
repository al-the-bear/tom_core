# preferences

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Both halves of a user's preferences, from the client side: the **device** store
— one typed API, one backend per platform, chosen by dependency injection instead
of an `if (kIsWeb)` where the value is read — and `TomUserPreferencesClient`, the
typed client for the **account** store the server holds.

Some preferences must **not** follow the user — which account was last used on
this device, whether biometric unlock is on here, a layout choice that is right
on the tablet and wrong on the phone. Those live in the device store. The ones
that *should* follow the user live server-side (`TomUserPreferences`,
`tom_core_server`) and are reached from here through `TomUserPreferencesClient`,
which speaks the kernel's `tomUserPreferencesApi` contract. The keys, the wire
DTO and the value codec are the kernel's, so the two stores share one vocabulary
and one encoding rather than two that agree by inspection — and both carry the
same method set, which is what lets a preference *move* between them without a
call site changing.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomDevicePreferences` | The interface: `all` / `read` / `get` / `getOr` / `set` / `remove` / `clear`, plus `getPreferred` for the documented device-over-server precedence. Resolved as a bean. |
| `TomStoredDevicePreferences` | The shipped implementation — the typed API over a store; holds the single encode/decode decision. |
| `TomDevicePreferenceStore` | The narrow backend: `read()` / `write()` of the whole set. The only platform-specific part of the module. The list `read()` returns belongs to the store and the list given to `write()` belongs to the caller, so neither side has to copy defensively. |
| `TomPlatformDevicePreferenceStore` | The backend for the current target, chosen by conditional export: a JSON file on desktop/mobile, a `localStorage` entry on the web, a loud failure elsewhere. |
| `TomMemoryDevicePreferenceStore` | A store that persists nothing beyond the process — for tests, examples, and clients that deliberately keep no machine-local state. |
| `TomDevicePreferenceJson` | The stored JSON document, written once so every persistent backend stores the same text. |
| `TomDevicePreferenceException` | `device_preferences.unsupported_platform`, `device_preferences.store.invalid_content`. |
| `TomUserPreferencesClient` | The account store: `all` / `read` / `get` / `getOr` / `set` / `remove` over the server's `/preferences/*` routes. Implements the kernel's `TomUserPreferencesApiService`; every URI is resolved from the contract, none is written. |
| `TomUserPreferencesClientException` | `preferences.client.not_found`, `preferences.client.rejected`, `preferences.client.invalid_response`. |

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

## Scope — a store belongs to its location, not to a user

Nothing in this module knows who is signed in; one store is one flat key space.
So **an application on which more than one account can sign in separates them by
construction** — it gives the store a `location` naming the signed-in account
and installs a new store when the account changes:

```dart
TomBean.withType(
  TomDevicePreferences,
  TomStoredDevicePreferences(
    TomPlatformDevicePreferenceStore(
      '$supportDirectory/preferences/$accountId.json',
    ),
  ),
);
```

The account part must be a single path (or entry-name) segment and stable — a
surrogate id, or an address hashed or percent-encoded, never a display name. An
install that gives every account one location gives them one set of
preferences: the second sign-in reads the first user's last-used account,
biometric flag and layout, and nothing here detects it.

That is also what decides which configuration scope the store occupies
(`codespecs_mapping.md` §11): at a fixed location it is `(client app, machine)`
— CE-CC's scope — and at a per-account location `(user, device)`, CE-DS. Same
class, different address. The API stays principal-free under both, which is what
keeps it swappable with the server-side `TomUserPreferences`.

Switching accounts costs nothing beyond the new bean: `TomStoredDevicePreferences`
holds no cache, so the next read already answers from the new document.

## Precedence

Where a key exists in both stores, **the device value wins for as long as it
exists**; the server value answers only a key this device has never written.
Writing here is the later, more specific act, so the account value behaves as a
cross-device default and the device value as this machine's override. The rule
is stated on `TomDevicePreferences` and applied in `getPreferred` — no caller
re-derives it.

```dart
final theme = await preferences.getPreferred<String>(
  TomUserPreferenceKeys.theme,
  () => account.get<String>(TomUserPreferenceKeys.theme),
);
```

The account side stays a **callback** even though the client ships beside the
device store: a device-only app must not be made to carry an HTTP client to read
a local setting. The client is simply what an application that has one closes
over, so the pairing is written at the application layer — see
`example/preferences/preferences_example.dart`, which runs it end to end against
a real socket.

The client needs the application to have registered its platform
(`TomPlatformUtils.setCurrentPlatform(clientPlatformUtils)`); it reaches the
network through `TomPlatformUtils.current.httpClient()`, and the neutral fallback
throws rather than guessing one.

---

Part of [`tom_core_flutter`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
