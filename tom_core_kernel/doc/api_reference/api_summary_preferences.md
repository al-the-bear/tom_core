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
coerce. Reading therefore takes the whole `TomUserPreferenceDto`: the codec
exposes no entry point for the value's text on its own, since one would have
nothing to check the caller's requested type against.

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

Encodes and decodes preference values against `TomUserPreferenceDto`.

A preference value may take three shapes and no others: a scalar (`String`,
`int`, `double`, `bool`), a `DateTime`, or a `@tomReflector` type — either an
**enum**, written as `{"name": "<constant>"}`, or a **class**, written as a JSON
object of its members. Scalars are plain JSON; a reflected class goes through
the same reflection path the endpoint pipeline uses for every other DTO.
Anything else — notably a plain `List` or `Map` — is refused when it is named,
by `typeNameOf`, because the registry has no name for it; wrap it in a reflected
class.

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
| `enumNameField` | `String` | `name` | The JSON member an enum value is stored in: its constant *name*, never its index. An index is positional, so inserting a constant silently changes what every already-stored preference means; the name moves only when the constant is renamed, and a renamed one is refused loudly by `decode` rather than misread. |

#### Static Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `typeNameOf(Object value, [String key = ''])` | `String` | The `valueType` the value is stored under — a scalar's own type name, or, for anything else, the `simpleName` the reflection registry holds for its class. Not `runtimeType.toString()`: that name is written to a database column and read back by another release on another platform, and the compiler's rendering is rewritten by web minification, carries the generic instantiation (`BoxPreference<int>` vs `BoxPreference<dynamic>`), and for an SDK type can be private (`_Map<String, int>`) — a name no reader could ask for. The registry name is a generator-emitted literal, and is the same registry `decode` resolves `T` through, so a value can be written under a name exactly when it can be read back under it. Throws `preferences.type.not_reflected` for a class the registry does not know; `key` only names the preference in that exception. |
| `typeNameForType(Type type, [String key = ''])` | `String` | The `valueType` a value of that type is stored under — the same registry lookup as `typeNameOf`, from a `Type` rather than a value. For a value stored under the class it is declared as the two return the same string, but they are not the same question: this names the class a *type* denotes, `typeNameOf` the class a *value* turned out to have. Two divergences follow. **Subclass**: a value whose runtime class is a subclass of the declared type is named by the subclass there and by the declared type here, which `decode<T>` reports as `preferences.decode.type_mismatch` — intended strictness, since reading it as the supertype would drop the subclass's own members. **Instantiated generic**: the registry is keyed by declaration, so `typeNameForType(BoxPreference<int>)` throws where `typeNameForType(BoxPreference)` answers and `typeNameOf(BoxPreference<int>())` answers via the instance; read a generic preference under its bare class literal, and expect it back as a `BoxPreference<dynamic>`. Throws `preferences.type.not_reflected` for a class the registry does not know. |
| `encode(String key, Object value, {DateTime? updatedAt})` | `TomUserPreferenceDto` | Builds the whole DTO. `updatedAt` is the server's write timestamp; a client leaves it `null`. Names the value before encoding it, so an unreflected object is refused here as `preferences.type.not_reflected` rather than reaching the serializer. |
| `encodeValue(Object value, [String key = ''])` | `String` | The value's JSON text alone. An enum is written as `{"name": "<constant>"}` — an object rather than a bare string, so that "a non-scalar value is a JSON object" holds without exception and `validateEncoded` can keep checking the shape from the declared type name alone. `key` names the preference in the exception and is optional, for a caller encoding before it has decided where to put the value. Throws `TomUserPreferenceCodecException`: `preferences.encode.not_json` for a value JSON cannot represent — in practice a non-finite `double` — and `preferences.encode.failed` when a non-scalar value is not reflectable. An unreflected *enum* is not refused here — a constant name needs no registry — but `encode` refuses it, for having no name to be stored under. |
| `validateEncoded(String valueType, String valueJson, {String key = ''})` | `void` | Checks that the text is JSON and is shaped like the declared type. Throws `preferences.encoded.invalid_json`, `preferences.encoded.type_mismatch`, or `preferences.encoded.not_an_instant` for a `DateTime` whose text names no zone. A non-scalar type is only required to be a JSON object — which reflected class it names is deliberately not checked, since a preference type may be one only the client knows. That is also why an enum is stored as an object: this check sees a type *name* and cannot tell an enum from a class without reflecting it, so giving enums a shape of their own would mean either weakening the rule for every class or asking the server the question it must not ask. |
| `decode<T extends Object>(TomUserPreferenceDto dto)` | `T` | The stored value as a `T`, and **the only read** — there is no sibling taking the value's text alone, because it would have nothing to compare `T` against. Throws `preferences.decode.type_mismatch` when the stored `valueType` is not the one `T` is stored under; the comparison happens before any narrowing, so an `int` is not silently widened to a requested `double` and a stored `DateTime` is not read as the `String` its text is. Otherwise widens `int`→`double` where `T` asks for it, reads a `DateTime` as the UTC instant its text names, and reconstructs a reflected object through `createInstanceFromJson` member by member — unrecognised JSON members ignored, absent ones left at their declared defaults, so a row whose `valueType` and text disagree yields a defaulted instance. Resolves `T` through the registry once, before reading anything, and hands the resulting `ClassMirror` to the reconstruction — so a `T` the registry does not know is refused as `preferences.type.not_reflected` before the payload is looked at, and a row declared as a scalar but holding an object is reported as `preferences.decode.failed` rather than blamed on reflection. An **enum** `T` is matched against the constants it declares now, and a stored name that is not among them raises `preferences.decode.unknown_enum_constant` rather than defaulting — the tolerance the class path allows is deliberately absent, because an omitted member falls back to the value the class declares whereas an unmatched constant has no such answer, only the user's actual choice would do, and that is what has been lost. Throws `preferences.type.not_reflected`, `preferences.decode.invalid_json`, `preferences.decode.type_mismatch`, `preferences.decode.not_an_instant`, `preferences.decode.unknown_enum_constant` or `preferences.decode.failed` — including when reflection cannot instantiate a `T` that declares no no-argument constructor, which is reported as `preferences.decode.failed` rather than escaping as a reflection error. |
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
`preferences.type.not_reflected`,
`preferences.encode.not_json`, `preferences.encode.failed`,
`preferences.encoded.invalid_json`,
`preferences.encoded.type_mismatch`, `preferences.encoded.not_an_instant`,
`preferences.decode.type_mismatch`, `preferences.decode.invalid_json`,
`preferences.decode.not_an_instant` or
`preferences.decode.failed`.

`preferences.type.not_reflected` is not on either side of the wire: it is
raised while *naming* a value, so it belongs to both the write and the read.

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
