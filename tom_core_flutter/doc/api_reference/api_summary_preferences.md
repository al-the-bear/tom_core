# Tom Core Flutter API Reference: Preferences Module

Device-stored user preferences: the typed API, its shipped implementation, the
narrow per-platform backend, and the JSON document every persistent backend
writes.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomDevicePreferences](#tomdevicepreferences)
  - [TomStoredDevicePreferences](#tomstoreddevicepreferences)
  - [TomDevicePreferenceStore](#tomdevicepreferencestore)
  - [TomMemoryDevicePreferenceStore](#tommemorydevicepreferencestore)
  - [TomPlatformDevicePreferenceStore](#tomplatformdevicepreferencestore)
  - [TomDevicePreferenceJson](#tomdevicepreferencejson)
  - [TomDevicePreferenceException](#tomdevicepreferenceexception)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tomclient/preferences/device_preferences.dart`,
`stored_device_preferences.dart`, `device_preference_store.dart`,
`device_preference_json.dart`,
`platform_device_preference_store{,_io,_web,_neutral}.dart`.

Preferences that must **not** follow the user — the last account used on this
device, whether biometric unlock is on here, a per-device layout — stored
through one platform-independent API. The keys, the wire DTO and the value codec
are the kernel's (`TomUserPreferenceKeys`, `TomUserPreferenceDto`,
`TomUserPreferenceCodec`), the same three the server-side store uses, so the two
stores share one vocabulary and one encoding.

Backend selection happens twice and never at the call site: a conditional export
picks the storage the target *can* use, and the bean locator picks the
`TomDevicePreferences` the application *has registered*.

## Class Hierarchy

```
TomDevicePreferences                                (interface; bean-resolved)
└── TomStoredDevicePreferences

TomDevicePreferenceStore                            (interface)
├── TomMemoryDevicePreferenceStore
└── TomPlatformDevicePreferenceStore                (io | web | neutral variant)

TomDevicePreferenceJson                             (namespace of statics)

TomException
└── TomClientException
    └── TomDevicePreferenceException
```

## Classes

### TomDevicePreferences

Typed access to this device's machine-local preferences. The interface, not an
implementation — an application that already has a preferences mechanism can
implement this and every framework consumer keeps working.

#### Constructors

```dart
const TomDevicePreferences()
```

#### Static Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `resolve()` | `TomDevicePreferences?` | The installed bean, or `null` when none is registered — `null` rather than a throw, because a preference is optional by nature and an app without a device store should fall back, not fail. |

#### Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `all()` | `Future<List<TomUserPreferenceDto>>` | Every preference on this device, in storage order. |
| `read(String key)` | `Future<TomUserPreferenceDto?>` | One preference as stored, or `null` when never written. |
| `get<T extends Object>(String key)` | `Future<T?>` | `read`, decoded as a `T`. Throws `TomUserPreferenceCodecException` on a stored-type mismatch. |
| `getOr<T extends Object>(String key, T fallback)` | `Future<T>` | `get`, with `fallback` for a preference that has never been written. A type mismatch still throws. |
| `set<T extends Object>(String key, T value)` | `Future<TomUserPreferenceDto>` | Encodes and stores, returning the stored DTO. Scalars and `DateTime`s go through the codec; anything else must be a `@tomReflector` class. |
| `remove(String key)` | `Future<bool>` | Deletes; answers whether a preference was removed, so a caller can tell "deleted" from "was never there". |
| `clear()` | `Future<void>` | Deletes everything on this device. Its own method rather than a loop over `all`, because a backend can do it atomically and a loop that fails half way leaves a state no user asked for. |
| `getPreferred<T extends Object>(String key, Future<T?> Function() fromUserStore)` | `Future<T?>` | Applies the documented precedence: the device value wins while it exists; `fromUserStore` is consulted only for a key this device has never written. |

There is no `getFor` — a device store has one user by definition, so a principal
parameter would have nothing to select.

**Precedence.** Where a key exists in both this store and the server-side
`TomUserPreferences`, the device value wins for as long as it exists. Writing on
*this* device is the later, more specific act, so the account value behaves as a
cross-device default and the device value as this machine's override. The rule
is stated on the interface and applied in `getPreferred`; no caller re-derives
it.

### TomStoredDevicePreferences

The `TomDevicePreferences` the framework ships: the typed API over a
`TomDevicePreferenceStore`. Everything platform-specific is in the store;
everything typed is here, so the encode/decode decision is made once.

- **Extends:** `TomDevicePreferences`.

#### Constructors

```dart
const TomStoredDevicePreferences(TomDevicePreferenceStore store)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `store` | `TomDevicePreferenceStore` | The backend preferences are persisted in. |

Every operation goes to the store — there is no in-memory cache. A device
preference is read when a screen opens and written when a user flips a switch,
so a cache would buy nothing measurable and would go stale the moment a second
browser tab, a background isolate or a platform settings panel wrote the same
store.

`set` encodes *before* reading the store, so an unencodable value cannot cause a
read-modify-write cycle that ends in a rewrite of unchanged content.

### TomDevicePreferenceStore

Where a device's preferences are persisted. Deliberately the narrowest interface
`TomStoredDevicePreferences` needs — two methods is the whole cost of adapting a
new backend.

#### Constructors

```dart
const TomDevicePreferenceStore()
```

#### Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `read()` | `Future<List<TomUserPreferenceDto>>` | Every persisted preference; empty when nothing has been written. Unreadable content throws `device_preferences.store.invalid_content` rather than reading as empty. |
| `write(List<TomUserPreferenceDto> values)` | `Future<void>` | Replaces the persisted set, all-or-nothing. An empty `values` clears the store. |

The unit is the kernel's `TomUserPreferenceDto` rather than a device-local
record type: a device preference and a server preference are the same thing
stored in two places, and a second record type would mean a second `valueType`
convention that agreed with the server's only by inspection.

### TomMemoryDevicePreferenceStore

A store that persists nothing beyond the process — for tests, examples, and
clients that deliberately keep no machine-local state. Not a fallback for a
platform without a real backend: a store that silently forgets is worse than a
loud one.

- **Extends:** `TomDevicePreferenceStore`.

#### Constructors

```dart
TomMemoryDevicePreferenceStore([List<TomUserPreferenceDto>? initialValues])
```

### TomPlatformDevicePreferenceStore

The backend for the current target, selected at compile time by the conditional
export in `platform_device_preference_store.dart`.

- **Extends:** `TomDevicePreferenceStore`.

#### Constructors

```dart
const TomPlatformDevicePreferenceStore(String location)
```

| Variant | Selected by | `location` means | Behaviour |
| ------- | ----------- | ---------------- | --------- |
| io | `dart.library.io` | a filesystem path | JSON file; write-then-rename, deleted when the set becomes empty |
| web | `dart.library.js` | a `localStorage` entry name | one entry holding the whole document; removed when the set becomes empty |
| neutral | neither | — | **throws** `device_preferences.unsupported_platform` on construction |

The parameter is `location` on every variant because it is the *same* parameter
everywhere — one name is what lets an application construct the store in one
place without knowing which variant it got.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `location` | `String` | The file path or `localStorage` entry name. On the neutral variant, retained only so the failure can name it. |

### TomDevicePreferenceJson

The stored representation, written once so every persistent backend stores the
same text. A JSON array of objects with `key`, `valueType`, `value` and an
optional `updatedAt` — the shape the store reads and writes, and the shape the
server's `/preferences` list endpoint answers.

#### Static Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `encode(List<TomUserPreferenceDto> values)` | `String` | The stored JSON text; `updatedAt` normalised to UTC and omitted when `null`. |
| `decode(String content, {String source})` | `List<TomUserPreferenceDto>` | Parses it back. Blank content decodes to an empty document; anything else that is not an array of objects throws `device_preferences.store.invalid_content`. `source` only names the backend in the failure. |

The DTO is written field by field rather than through reflection: a framework
store must keep working in an application whose generator never saw
`TomUserPreferenceDto`.

### TomDevicePreferenceException

A failure raised by this module — `device_preferences.unsupported_platform`,
`device_preferences.store.invalid_content`.

- **Extends:** `TomClientException`.

#### Constructors

```dart
TomDevicePreferenceException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog,
})
```

Parameters mirror `TomException`. A *value* failure (a type mismatch,
unparseable JSON in a preference value) arrives as the kernel's
`TomUserPreferenceCodecException` instead, because it means the same thing in
both stores and is already named there.

## Global Functions and Constants

None — this module exposes no top-level functions or constants. The preference
keys it is addressed with are the kernel's `TomUserPreferenceKeys` (see
`tom_core_kernel/doc/api_reference/api_summary_preferences.md`).
