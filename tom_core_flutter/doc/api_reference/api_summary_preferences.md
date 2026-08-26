# Tom Core Flutter API Reference: Preferences Module

Both halves of a user's preferences from the client side: the **device** store —
its typed API, its shipped implementation, the narrow per-platform backend and
the JSON document every persistent backend writes — and
`TomUserPreferencesClient`, the typed client for the **account** store the server
holds.

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
  - [TomUserPreferencesClient](#tomuserpreferencesclient)
  - [TomUserPreferencesClientException](#tomuserpreferencesclientexception)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tomclient/preferences/device_preferences.dart`,
`stored_device_preferences.dart`, `device_preference_store.dart`,
`device_preference_json.dart`,
`platform_device_preference_store{,_io,_web,_neutral}.dart`,
`user_preferences_client.dart`.

Preferences that must **not** follow the user — the last account used on this
device, whether biometric unlock is on here, a per-device layout — are stored
through one platform-independent API. The ones that *should* follow the user live
server-side (`TomUserPreferences`, `tom_core_server`) and are reached from here
through `TomUserPreferencesClient`.

The keys, the wire DTO and the value codec are the kernel's
(`TomUserPreferenceKeys`, `TomUserPreferenceDto`, `TomUserPreferenceCodec`), so
the two stores share one vocabulary and one encoding rather than two that agree
by inspection — and both carry the same method set, which is what lets a
preference *move* between them without a call site changing.

Backend selection happens twice and never at the call site: a conditional export
picks the storage the target *can* use, and the bean locator picks the
`TomDevicePreferences` the application *has registered*.

## Class Hierarchy

```text
TomDevicePreferences                                (interface; bean-resolved)
└── TomStoredDevicePreferences

TomDevicePreferenceStore                            (interface)
├── TomMemoryDevicePreferenceStore
└── TomPlatformDevicePreferenceStore                (io | web | neutral variant)

TomDevicePreferenceJson                             (namespace of statics)

TomUserPreferencesApiService                        (kernel contract face)
└── TomUserPreferencesClient

TomException
└── TomClientException
    ├── TomDevicePreferenceException
    └── TomUserPreferencesClientException
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

**Keys obey the same rule as the server's.** `read`, `get`, `set` and `remove`
reject a key that does not satisfy the kernel's `TomUserPreferenceKeys` with a
`TomUserPreferenceKeyException`. A device store never puts a key in a URL, so
nothing *here* would break under a looser rule — but the precedence below only
means anything if both stores answer to the same names, and a preference that
can move from this store to the server's must already carry a key the server
would accept. One vocabulary, one rule.

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
TomPlatformDevicePreferenceStore(String location)
```

| Variant | Selected by | `location` means | Behaviour |
| ------- | ----------- | ---------------- | --------- |
| io | `dart.library.io` | a filesystem path | JSON file; write-then-rename, deleted when the set becomes empty |
| web | `dart.library.js` | a `localStorage` entry name | one entry holding the whole document; removed when the set becomes empty |
| neutral | neither | — | **throws** `device_preferences.unsupported_platform` on construction |

The parameter is `location` on every variant because it is the *same* parameter
everywhere — one name is what lets an application construct the store in one
place without knowing which variant it got.

The constructor is **not** `const` on any variant, including the two that could
be. The neutral variant throws from its constructor body, so it cannot be; and a
signature that is `const` on some targets and not others is exactly the branch
this type exists to remove — `const TomPlatformDevicePreferenceStore(location)`
would compile on device and web and break the build on the target whose intended
behaviour is a run-time failure. Same reasoning, and same resolution, as
`TomFileClientConfigurationStore` in the configuration module.

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
| `decode(String content, {String source})` | `List<TomUserPreferenceDto>` | Parses it back. Blank content decodes to an empty document; anything else that is not an array of objects — or that carries an `updatedAt` naming no time zone — throws `device_preferences.store.invalid_content`. `source` only names the backend in the failure. |

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
  bool autoLog = false,
})
```

Parameters mirror `TomException`. The types above are the *kernel constructor's*,
reached through Dart super-parameters — which resolve against the immediate
superclass, not against the field's original declaration. That matters for
`stack`: the field on `TomBaseException` is `Object?`, but `TomException`'s
constructor narrows it to `StackTrace?`, so that is what a caller may pass here.
`autoLog` is non-nullable and defaults to `false`; the default is inherited too,
so omitting it is not the same as passing `null` — passing `null` does not
compile.

A *value* failure (a type mismatch,
unparseable JSON in a preference value) arrives as the kernel's
`TomUserPreferenceCodecException` instead, because it means the same thing in
both stores and is already named there.

### TomUserPreferencesClient

Typed access to the calling principal's **server-stored** preferences — the
account half of the pair, and the counterpart of `TomDevicePreferences`.

- **Implements:** `TomUserPreferencesApiService` (kernel). The client and the
  server are two implementations of one interface.

Without it every application writes the four HTTP calls itself: four spellings
of the same URIs, four decodings of the same DTO, four chances to read a broken
server as "no such preference" — the same G-DI-3 failure the device store was
built to remove, one layer up.

#### Constructors

```dart
TomUserPreferencesClient({
  required Uri baseUri,
  TomServerChannel? channel,
  Map<String, String> headers = const {},
  Map<String, String> Function()? headerProvider,
})
```

| Parameter | Meaning |
| --------- | ------- |
| `baseUri` | The server **root**, not the `/preferences` path — the API's own `uri` is part of the contract and is appended from it. A base that already carries a path (a gateway prefix) keeps it. |
| `channel` | Optional; one is created for `baseUri`'s host and port when omitted. Pass an existing channel to share a connection pool — `close()` then leaves it alone, because it belongs to whoever passed it in. |
| `headers` | Sent with every request. |
| `headerProvider` | Supplies the headers that must be computed **per request** — a credential that rotates would otherwise be captured once at construction. |

The constructor calls `registerTomUserPreferencesApi()` (idempotent) rather than
leaving it to the application: every request is resolved from the registered
contract, so a client built before anyone registered it would fail on its first
call for a reason that has nothing to do with the call.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `baseUri` | `Uri` | The server root endpoint paths are resolved against. |
| `channel` | `TomServerChannel` | The channel providing the pooled HTTP client. |
| `headers` | `Map<String, String>` | The unmodifiable per-client header set. |

#### Methods — the store face

The same six the device store carries, so a call site reads identically
whichever store it addresses.

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `all()` | `Future<List<TomUserPreferenceDto>>` | Every preference stored for the calling principal. |
| `read(String key)` | `Future<TomUserPreferenceDto?>` | One preference as stored, or `null` when the server has never been given one. |
| `get<T extends Object>(String key)` | `Future<T?>` | `read`, decoded as a `T`. Throws `TomUserPreferenceCodecException` on a stored-type mismatch. |
| `getOr<T extends Object>(String key, T fallback)` | `Future<T>` | `get`, with `fallback` for a preference that has never been written. A type mismatch still throws. |
| `set<T extends Object>(String key, T value)` | `Future<TomUserPreferenceDto>` | Encodes and writes, returning the stored DTO. |
| `remove(String key)` | `Future<void>` | Deletes. Returns nothing where the device store answers a `bool` — the delete endpoint is idempotent by design, so the server does not report whether a row existed, and a `bool` invented here could only be a second round trip pretending to be an answer. |
| `close()` | `void` | Releases the HTTP client, when this client created it. |

There is no `clear()`. The contract declares no bulk delete, and a loop over
`all()` that failed half way would leave an account in a state no user asked for
— exactly the failure the device store's atomic `clear` exists to prevent.

#### Methods — the contract face

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `listPreferences()` | `Future<List<TomUserPreferenceDto>>` | The list endpoint; decodes the bare JSON array the pipeline produces. |
| `readPreference(TomUserPreferenceKeyRequest request)` | `Future<TomUserPreferenceDto>` | Throws `preferences.client.not_found` on a miss, because the contract's result type is not nullable. `read` is the same call with the miss expressed as `null`, and is what an application should use. |
| `writePreference(TomUserPreferenceWriteRequest request)` | `Future<TomUserPreferenceDto>` | The write endpoint; passes no path parameters, because the write URI carries no `{key}` and `request.key` is the whole of what is addressed. |
| `deletePreference(TomUserPreferenceKeyRequest request)` | `Future<void>` | The delete endpoint; a `404` is success, the same rule the server applies. |

#### Addressing

**No URI is written here.** Every request is built by
`TomApiEndpoint.resolveUri` from the endpoint's own declaration — its method, its
path template and its `urlParameterMapping` — so the address the client calls and
the route the server serves are two readings of one declaration.

**A write states its key once, in the body.** `read` and `deletePreference` are
addressed at `/{key}`; `writePreference` is a `PUT` at the collection whose
request already carries the key, so it passes no path parameters and a URL and
a body naming different preferences is not expressible.

**A key that could not be a path segment never reaches a request.** `read`,
`writePreference` and `deletePreference` all validate against
`TomUserPreferenceKeys` before building one — the write included, since the
rule is the store's vocabulary and not the URL's — and throw
`TomUserPreferenceKeyException` instead, so the socket sees nothing. Escaping
is not a usable alternative: `%2F` is not a settled outcome, much HTTP
infrastructure rejects it and some normalises it back to `/`, at which point the
request addresses a two-segment path the API never declared. The empty key is
worse than ambiguous — it resolves to the *list* endpoint's own URI, so a read
of `''` would silently become a read of everything.

#### What a miss looks like

The server answers `404` for a key the caller has never written
(`TomUserPreferencesErrorHandler`, `tom_core_server`) and that is the **only**
status this client reads as absence: `read` and `get` answer `null`, `getOr`
answers its fallback. Every other failure throws, because a deployment whose
preference store is unreachable must not be indistinguishable from a user who has
set nothing. The same handler answers `400` for `preferences.key.invalid`; this
client rarely provokes it, having refused the key itself, but the server checks
because a client is not the only thing that can send an HTTP request.

#### Credentials

The bearer token from `TomBearerAuthentication` is sent by default. An
`Authorization` header supplied through `headers` or `headerProvider`
**suppresses** it — case-insensitively, because HTTP header names are — so a
request carries one credential rather than two spellings of one.

The client reaches the network through `TomPlatformUtils.current.httpClient()`,
so an application must have registered its platform
(`TomPlatformUtils.setCurrentPlatform(clientPlatformUtils)`); the neutral
fallback throws rather than guessing an implementation.

### TomUserPreferencesClientException

A failure raised by the server-preferences client —
`preferences.client.not_found`, `preferences.client.rejected`,
`preferences.client.invalid_response`.

- **Extends:** `TomClientException`.

#### Constructors

```dart
TomUserPreferencesClientException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

Parameters mirror `TomException`, with the same super-parameter resolution
described for `TomDevicePreferenceException` above: `stack` is `StackTrace?` —
the type `TomException`'s constructor narrows the `Object?` field to — and
`autoLog` is non-nullable with an inherited default of `false`.

A rejection carries the `statusCode` and, when
non-empty, the `response` body in `parameters`, so a caller diagnosing a failure
does not need the log. As with the device store, a *value* failure arrives as the
kernel's `TomUserPreferenceCodecException`.

## Global Functions and Constants

None — this module exposes no top-level functions or constants. The preference
keys it is addressed with are the kernel's `TomUserPreferenceKeys`, and so are
the API and endpoint ids the client resolves its URIs from
(`tomUserPreferencesApi`, `tomUserPreferences{List,Read,Write,Delete}EndpointId`,
`registerTomUserPreferencesApi`) — see
`tom_core_kernel/doc/api_reference/api_summary_preferences.md`.
