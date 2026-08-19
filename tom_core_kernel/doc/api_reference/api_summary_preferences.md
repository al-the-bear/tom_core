# Tom Core Kernel API Reference: Preferences Module

The keys, wire DTOs, value codec and API declaration shared by the server-side
and device-side preference stores.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomUserPreferenceKeys](#tomuserpreferencekeys)
  - [TomUserPreferenceDto](#tomuserpreferencedto)
  - [TomUserPreferenceWriteRequest](#tomuserpreferencewriterequest)
  - [TomUserPreferenceKeyRequest](#tomuserpreferencekeyrequest)
  - [TomUserPreferencesApiService](#tomuserpreferencesapiservice)
  - [TomUserPreferenceCodec](#tomuserpreferencecodec)
  - [TomUserPreferenceCodecException](#tomuserpreferencecodecexception)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tombase/preferences/user_preference_keys.dart`,
`lib/src/tombase/preferences/user_preferences_contract.dart`,
`lib/src/tombase/preferences/user_preference_codec.dart`.

This module holds the contract half of user preferences. The store itself is
elsewhere — server-stored preferences live in `tom_core_server`, device-stored
ones on the client — but both bind to the declarations here: the well-known
keys, the wire DTOs, the codec that decides how a value becomes JSON text and
comes back, and the `TomApi` describing the four `/preferences` endpoints.

A stored preference is JSON text plus the name of the type it was written as.
The name travels with the value because JSON forgets types, and it is what lets
a reflected object round-trip and a mismatched read fail loudly rather than
coerce.

## Class Hierarchy

```
TomUserPreferenceKeys              (namespace of String constants)

TomUserPreferenceDto               (@tomReflector)
TomUserPreferenceWriteRequest      (@tomReflector)
TomUserPreferenceKeyRequest        (@tomReflector)

TomUserPreferencesApiService       (abstract)

TomUserPreferenceCodec             (static-only)

TomException
└── TomUserPreferenceCodecException
```

## Classes

### TomUserPreferenceKeys

A namespace of the preference keys the framework itself reads. Constants rather
than an enum, because a key's *text* is the contract: it crosses the wire and
lives in a database column.

- **Constructor:** private (`TomUserPreferenceKeys._()`); the class is never
  instantiated.

#### Constants

| Constant | Type | Value | Description |
| -------- | ---- | ----- | ----------- |
| `timezone` | `String` | `tom.timezone` | Preferred IANA timezone identifier; read during authentication, where a stored value wins over the timezone a client asserts about itself. |
| `language` | `String` | `tom.language` | Preferred language as an ISO 639-1 code. |
| `country` | `String` | `tom.country` | Preferred country as an ISO 3166-1 alpha-2 code. |
| `theme` | `String` | `tom.theme` | Preferred UI theme name. |

### TomUserPreferenceDto

One stored preference as it travels the wire. A reflection-first DTO:
`@tomReflector`, plain non-`final` fields, no hand-written serializer.

#### Constructors

```dart
TomUserPreferenceDto({
  String key = '',
  String valueType = '',
  String value = '',
  DateTime? updatedAt,
})
```

Every field defaults, because the reflection path instantiates a blank instance
and fills it field by field.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `key` | `String` | The preference key. |
| `valueType` | `String` | The name of the type `value` was written as — a scalar's Dart type name or the simple name of a `@tomReflector` class. |
| `value` | `String` | The value's JSON text; text rather than a decoded `Object?` so the DTO stays flat. |
| `updatedAt` | `DateTime?` | When the preference was last written, in UTC; `null` for one that has never been stored. |

#### Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `toString()` | `String` | `TomUserPreferenceDto(<key>: <valueType>)`. |

### TomUserPreferenceWriteRequest

The request for writing one preference — the DTO's three value fields without
the timestamp, because when a preference was written is the server's answer.

#### Constructors

```dart
TomUserPreferenceWriteRequest({
  String key = '',
  String valueType = '',
  String value = '',
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `key` | `String` | The preference key to write. |
| `valueType` | `String` | The name of the type `value` is encoded as. |
| `value` | `String` | The value's JSON text. |

#### Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `toString()` | `String` | `TomUserPreferenceWriteRequest(<key>: <valueType>)`. |

### TomUserPreferenceKeyRequest

The request for reading or deleting one preference by key. A DTO rather than a
bare `String` parameter so the path capture binds onto a typed field.

#### Constructors

```dart
TomUserPreferenceKeyRequest({String key = ''})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `key` | `String` | The addressed preference key, captured from the URL path. |

#### Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `toString()` | `String` | `TomUserPreferenceKeyRequest(<key>)`. |

### TomUserPreferencesApiService

The typed service interface behind `tomUserPreferencesApi` — the contract's Dart
face, implemented by the server and by any client caller. It carries no
annotation because the server-side annotations live in `tom_core_server`.

- **Kind:** abstract class.

#### Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `listPreferences()` | `Future<List<TomUserPreferenceDto>>` | Every preference of the calling principal. |
| `readPreference(TomUserPreferenceKeyRequest request)` | `Future<TomUserPreferenceDto>` | The caller's preference under `request.key`. |
| `writePreference(TomUserPreferenceWriteRequest request)` | `Future<TomUserPreferenceDto>` | Writes one preference of the caller, replacing any previous value. |
| `deletePreference(TomUserPreferenceKeyRequest request)` | `Future<void>` | Deletes the caller's preference under `request.key`. |

### TomUserPreferenceCodec

Encodes and decodes preference values against `TomUserPreferenceDto`. Scalars
are written as plain JSON; a reflected object goes through the same reflection
path the endpoint pipeline uses for every other DTO.

- **Constructor:** private (`TomUserPreferenceCodec._()`); all members are
  static.

#### Constants

| Constant | Type | Value | Description |
| -------- | ---- | ----- | ----------- |
| `stringType` | `String` | `String` | The `valueType` of a `String` value. |
| `intType` | `String` | `int` | The `valueType` of an `int` value. |
| `doubleType` | `String` | `double` | The `valueType` of a `double` value. |
| `boolType` | `String` | `bool` | The `valueType` of a `bool` value. |
| `dateTimeType` | `String` | `DateTime` | The `valueType` of a `DateTime` value; always written in UTC, and required to name its zone on the way back in. |
| `scalarTypes` | `List<String>` | — | The scalar type names, in the order `typeNameOf` tests them. |

#### Static Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `typeNameOf(Object value)` | `String` | The `valueType` the value is stored under — a scalar's own type name, or a reflected object's runtime type name. |
| `typeNameForType(Type type)` | `String` | The `valueType` a value of that type is stored under; agrees with `typeNameOf` for every type either can see. |
| `encode(String key, Object value, {DateTime? updatedAt})` | `TomUserPreferenceDto` | Builds the whole DTO. `updatedAt` is the server's write timestamp; a client leaves it `null`. |
| `encodeValue(Object value, [String key = ''])` | `String` | The value's JSON text alone. `key` names the preference in the exception and is optional, for a caller encoding before it has decided where to put the value. Throws `TomUserPreferenceCodecException`: `preferences.encode.not_json` for a value JSON cannot represent — in practice a non-finite `double` — and `preferences.encode.failed` when a non-scalar value is not reflectable. |
| `validateEncoded(String valueType, String valueJson, {String key = ''})` | `void` | Checks that the text is JSON and is shaped like the declared type. Throws `preferences.encoded.invalid_json`, `preferences.encoded.type_mismatch`, or `preferences.encoded.not_an_instant` for a `DateTime` whose text names no zone. A non-scalar type is only required to be a JSON object — which reflected class it names is deliberately not checked. |
| `decode<T extends Object>(TomUserPreferenceDto dto)` | `T` | The stored value as a `T`. Throws `preferences.decode.type_mismatch` when the stored `valueType` is not the one `T` is stored under. |
| `decodeValue<T extends Object>(String json, [String key = ''])` | `T` | The JSON text alone as a `T`. Widens an `int` to a `double`, reads a `DateTime` as the UTC instant its text names, and reconstructs a reflected object through `createInstanceFromJson`. Throws `preferences.decode.invalid_json`, `preferences.decode.type_mismatch`, `preferences.decode.not_an_instant`, `preferences.decode.not_reflected` or `preferences.decode.failed`. |
| `parseInstant(String text)` | `DateTime?` | The UTC instant `text` names, or `null` when it names none. Stricter than `DateTime.parse`, which reads a zoneless timestamp as the reading process's local time — so one stored string would mean a different instant on every device. Public so a client can check its own text before sending it. |

### TomUserPreferenceCodecException

Raised when a preference cannot be encoded or decoded.

- **Extends:** `TomException`.

#### Constructors

```dart
TomUserPreferenceCodecException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? rootException,
  StackTrace? stack,
})
```

Parameters mirror `TomException`. The `key` is one of
`preferences.encode.not_json`, `preferences.encode.failed`,
`preferences.encoded.invalid_json`,
`preferences.encoded.type_mismatch`, `preferences.encoded.not_an_instant`,
`preferences.decode.type_mismatch`, `preferences.decode.invalid_json`,
`preferences.decode.not_an_instant`, `preferences.decode.not_reflected` or
`preferences.decode.failed`.

## Global Functions and Constants

| Name | Type | Description |
| ---- | ---- | ----------- |
| `tomUserPreferencesApiId` | `String` | `tomUserPreferences` — the id `tomUserPreferencesApi` is registered and bound under. A constant because the server's `@TomApiEndpointImplementation(apiId: …)` has to name it. |
| `tomUserPreferencesListEndpointId` | `String` | `listPreferences`. |
| `tomUserPreferencesReadEndpointId` | `String` | `readPreference`. |
| `tomUserPreferencesWriteEndpointId` | `String` | `writePreference`. |
| `tomUserPreferencesDeleteEndpointId` | `String` | `deletePreference`. |
| `tomUserPreferencesApi` | `TomApi` | The `/preferences` API — see below. |
| `registerTomUserPreferencesApi()` | `void` | Registers `tomUserPreferencesApi` with the global `tomRemoteApis` registry. Idempotent, and called by both halves. Explicit rather than implicit so a deployment that stores no preferences does not carry the API. |

### tomUserPreferencesApi

Base URI `/preferences`. Every endpoint is `TomAuthenticatedAccess`: there is no
anonymous preference, because a preference is per principal.

| Endpoint id | Method | URI | Request type | Result type |
| ----------- | ------ | --- | ------------ | ----------- |
| `listPreferences` | GET | `` | — | `List<TomUserPreferenceDto>` |
| `readPreference` | GET | `/{key}` | `TomUserPreferenceKeyRequest` | `TomUserPreferenceDto` |
| `writePreference` | PUT | `/{key}` | `TomUserPreferenceWriteRequest` | `TomUserPreferenceDto` |
| `deletePreference` | DELETE | `/{key}` | `TomUserPreferenceKeyRequest` | `Object?` |

The by-key endpoints map the `{key}` path segment onto the request DTO's `key`
field. **Which** rows a caller reaches is not an endpoint-level question and is
not decided by this API: the server's entity declares
`@TomDbScope(field: 'principal_id')`, so the repository confines every statement
to the caller. No URI carries a principal parameter, because there is nothing to
ask for but your own.
