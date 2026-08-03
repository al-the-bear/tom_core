# Preferences Module

Device-stored user preferences: one typed API, one backend per platform, and the
backend chosen by dependency injection rather than by an `if (kIsWeb)` where the
value is read.

## Table of Contents

- [Overview](#overview)
- [Why the Framework Owns This](#why-the-framework-owns-this)
- [The Same Shape as the Server Store](#the-same-shape-as-the-server-store)
- [Choosing a Backend](#choosing-a-backend)
- [Precedence Against the Server Store](#precedence-against-the-server-store)
- [The Stored Document](#the-stored-document)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomDevicePreferences` | interface | The typed API; resolved as a bean |
| `TomStoredDevicePreferences` | class | The shipped implementation — typed API over a store |
| `TomDevicePreferenceStore` | interface | The narrow backend: read / write the whole set |
| `TomPlatformDevicePreferenceStore` | class | The backend for the current target (file / `localStorage` / loud failure) |
| `TomMemoryDevicePreferenceStore` | class | A store that persists nothing beyond the process |
| `TomDevicePreferenceJson` | class | The stored JSON document, written once for every persistent backend |
| `TomDevicePreferenceException` | exception | Module failures, keyed by stable dotted codes |

The *keys*, the *wire DTO* and the *value codec* are not here. `TomUserPreferenceKeys`,
`TomUserPreferenceDto` and `TomUserPreferenceCodec` live in `tom_core_kernel`'s
`preferences` module, because the server-side store (C-13) uses exactly the same
three, and a vocabulary spelled in two packages is a preference that silently
splits in two.

## Why the Framework Owns This

Some preferences must **not** follow the user. Which account was last used on
this device, whether biometric unlock is enabled *here*, a layout choice that is
right on the tablet and wrong on the phone in the same pocket — storing those
server-side gives every device the last one's answer.

Without a framework device store every application reaches for
`shared_preferences` (or `window.localStorage`, or a file) directly. That puts a
raw platform dependency at the application layer and makes the *call site*
branch on the platform, which is what G-DI-3 / G-ENV-1 exist to prevent. The
requirement this module satisfies is therefore not "a place to put values" — it
is the **uniform API**: the same call works on web, desktop and mobile, and only
one line in the whole application knows which storage is behind it.

## The Same Shape as the Server Store

The method set deliberately mirrors `TomUserPreferences` (`tom_core_server`):

| Method | Returns | Description |
|--------|---------|-------------|
| `all()` | `Future<List<TomUserPreferenceDto>>` | Every preference on this device |
| `read(key)` | `Future<TomUserPreferenceDto?>` | One preference as stored, or `null` |
| `get<T>(key)` | `Future<T?>` | Decoded as a `T`; `null` when never written |
| `getOr<T>(key, fallback)` | `Future<T>` | `get`, with a default for the unwritten case |
| `set<T>(key, value)` | `Future<TomUserPreferenceDto>` | Encodes and stores |
| `remove(key)` | `Future<bool>` | Deletes; answers whether one was removed |
| `clear()` | `Future<void>` | Deletes everything on this device |
| `getPreferred<T>(key, fromUserStore)` | `Future<T?>` | Applies the documented precedence |

That symmetry is not incidental. It is what lets a preference **move** between
the two stores — a value that turns out to belong to the user rather than the
device — without a single call site changing.

There is no `getFor`: a device store has one user by definition, so a principal
parameter would have nothing to select. And `clear()` is its own method rather
than a loop over `all()` because a backend can do it atomically and a loop
cannot: a loop that fails half way leaves a device in a state no user asked for.

`getOr` answers its fallback only for a preference that has **never been
written**. A type *mismatch* still throws `TomUserPreferenceCodecException`: an
unwritten preference is an ordinary state that a default answers, while a
preference stored as the wrong type is a bug, and silently answering the
fallback would hide it.

## Choosing a Backend

Backend selection happens twice, and neither half is a branch at the call site.

**At compile time**, `platform_device_preference_store.dart` conditionally
exports one of three implementations of `TomPlatformDevicePreferenceStore`:

| Target | Backend | Notes |
|--------|---------|-------|
| `dart:io` (desktop, mobile) | JSON file | Write-then-rename; deleted when empty |
| `dart:js` (web) | `localStorage` | One entry holding the whole document |
| neither | throws on construction | `device_preferences.unsupported_platform` |

It takes one `location` on every platform — a filesystem path where there is a
filesystem, a `localStorage` entry name in the browser — so the construction is
written once and never branches.

The neutral variant **throws** rather than degrading to an in-memory store. A
settings screen whose switches appear to work but forget everything on restart
is a worse outcome than a failure at startup, and only the app knows what the
right store would be on such a target. A client that genuinely wants no
machine-local persistence says so with `TomMemoryDevicePreferenceStore`.

**At run time**, the bean locator selects the `TomDevicePreferences`
implementation. The simplest wiring registers one instance:

```dart
TomBean.withType(
  TomDevicePreferences,
  TomStoredDevicePreferences(TomPlatformDevicePreferenceStore(location)),
);

final preferences = TomDevicePreferences.resolve()!;
await preferences.set('device.biometricUnlock', true);
```

An application that needs genuinely different behaviour per platform — an
encrypted store on mobile, a plain one on desktop — declares reflected
components instead and lets the four-tier selection choose:

```dart
@tomReflector
@TomComponent(TomDevicePreferences)
@platformIos
class IosDevicePreferences extends TomStoredDevicePreferences { … }
```

The framework ships **no** default component. A default would have to be the
memory store — the only one constructible without knowing where the app's
machine-local state belongs — and a default that silently forgets is exactly
what this module refuses.

`resolve()` answers `null` when nothing is registered, mirroring
`TomUserPreferences.resolve`: a preference is optional by nature, and an
application that has not wired a device store should fall back to its defaults
rather than fail to start.

## Precedence Against the Server Store

A key normally belongs to exactly one store. Where the same key exists in both,
**the device value wins for as long as it exists**, and the server value answers
only a key this device has never written.

That ordering matches what a user did: writing a preference on *this* device is
a deliberate, later, more specific act than the value that arrived with the
account. So the account value behaves as a cross-device default and the device
value as this machine's override — the same relationship the client-configuration
module has between shipped defaults and install overrides. Reversing it would
make a setting the user changed here revert the moment their other device wrote
the same key.

The rule is stated once on `TomDevicePreferences` and applied once in
`getPreferred`:

```dart
final theme = await preferences.getPreferred<String>(
  TomUserPreferenceKeys.theme,
  () => userPreferencesClient.get<String>(TomUserPreferenceKeys.theme),
);
```

The server side arrives as a **callback** rather than a dependency for two
reasons: this package must not depend on the server package, and the callback is
only invoked when this device has no answer — a device that has written the key
never pays for the round trip.

## The Stored Document

Every persistent backend stores the same JSON text, produced by
`TomDevicePreferenceJson`:

```json
[
  {"key": "device.lastAccount", "valueType": "String", "value": "\"alex\"",
   "updatedAt": "2026-03-14T09:26:53.000Z"},
  {"key": "device.launchCount", "valueType": "int", "value": "12"}
]
```

An **array** rather than an object keyed by preference key, because that is the
shape `TomDevicePreferenceStore` reads and writes, and because it is the shape
the server's `/preferences` list endpoint answers — the same text moves between
the two stores without a reshaping step.

The encoding lives in one class rather than in each backend: two backends that
each wrote their own JSON would agree only by inspection, and the day they
diverged would be the day a preference exported from one device failed to import
on another.

Blank content decodes to an empty document — a crash between creating a file and
writing it leaves exactly that, and treating it as empty loses nothing that was
ever committed. Anything else that is not an array of objects throws
`device_preferences.store.invalid_content` rather than reading as empty, because
a corrupt store that looked empty would be overwritten by the next write and
lose everything the device had chosen.

`updatedAt` is the device's own clock, normalised to UTC. Unlike the server
store nothing here can supply a more authoritative timestamp, but the
normalisation means a preference that later moves to the server carries an
instant the server can store unchanged.

## Core Components

- **`TomDevicePreferences`** — the interface, the precedence rule, and
  `resolve()`.
- **`TomStoredDevicePreferences`** — the typed API over a store; holds the
  single encode/decode decision. Every operation goes to the store: a device
  preference is read when a screen opens and written when a user flips a switch,
  so a cache would buy nothing measurable and would go stale the moment a second
  browser tab or a background isolate wrote the same store.
- **`TomDevicePreferenceStore`** — two methods, `read` and `write`, over the
  whole set. The only platform-specific part of the module, and the whole cost
  of adapting a new backend.
- **`TomPlatformDevicePreferenceStore`** — the compile-time selected backend.
- **`TomMemoryDevicePreferenceStore`** — for tests, examples, and clients that
  deliberately keep no machine-local state.

## Dependencies

- `tom_core_kernel` — `TomUserPreferenceKeys`, `TomUserPreferenceDto`,
  `TomUserPreferenceCodec`, `TomBean`, `TomRuntime`
  (see `../../tom_core_kernel/doc/preferences/preferences.md`).
- The little-things module — `TomClientException` (see
  [little_things.md](little_things.md)).
- `dart:io` / `package:web` — in the respective compile-time variants only.
