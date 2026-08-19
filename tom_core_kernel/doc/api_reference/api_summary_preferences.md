# Tom Core Kernel API Reference: Preferences Module

The keys, wire DTOs, value codec and API declaration shared by the server-side
and device-side preference stores.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomUserPreferenceKeys](#tomuserpreferencekeys)
  - [TomUserPreferenceKeyException](#tomuserpreferencekeyexception)
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
TomUserPreferenceKeys              (constants + the key rule)

TomUserPreferenceDto               (@tomReflector)
TomUserPreferenceWriteRequest      (@tomReflector)
TomUserPreferenceKeyRequest        (@tomReflector)

TomUserPreferencesApiService       (abstract)

TomUserPreferenceCodec             (static-only)

TomException
├── TomUserPreferenceKeyException
└── TomUserPreferenceCodecException
```

## Classes

### TomUserPreferenceKeys

The preference keys the framework itself reads, and the rule every other key has
to satisfy. Constants rather than an enum, because a key's *text* is the
contract: it crosses the wire as a URL path segment and lives in a database
column.

**A key is 1–191 characters, starts with an ASCII letter, and thereafter uses
only ASCII letters, digits, `.`, `_` and `-`.** Anything else is refused with
`TomUserPreferenceKeyException`.

- **Constructor:** private (`TomUserPreferenceKeys._()`); the class is never
  instantiated.

#### Constants

| Constant | Type | Value | Description |
| -------- | ---- | ----- | ----------- |
| `timezone` | `String` | `tom.timezone` | Preferred IANA timezone identifier; read during authentication, where a stored value wins over the timezone a client asserts about itself. |
| `language` | `String` | `tom.language` | Preferred language as an ISO 639-1 code. |
| `country` | `String` | `tom.country` | Preferred country as an ISO 3166-1 alpha-2 code. |
| `theme` | `String` | `tom.theme` | Preferred UI theme name. |
| `maxLength` | `int` | `191` | The longest a key may be — not a taste but `tom_user_preference.preference_key`'s own width, so a key the rule accepts is one the column stores whole rather than truncated into a collision. |

#### Static Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `isValid(String key)` | `bool` | Whether `key` satisfies the rule. For a caller deciding something — offering a name, filtering a list — rather than asserting it. |
| `validate(String key)` | `void` | Refuses `key` with `TomUserPreferenceKeyException` (`preferences.key.invalid`) when it does not satisfy the rule, and returns silently when it does. Every store face calls it on the way in. |

The two least obvious clauses each buy something. **Starting with a letter** is
what makes `.` and `..` illegal — both resolve away from the preference they
name (`.` reaches the *list* endpoint's URI, `..` leaves the API's path
altogether), and a rule handles them as a consequence rather than as two special
cases. **ASCII only** is about identity, not transport: `ü` has a composed and a
decomposed form that render identically and compare unequal, so one *visible*
key would be two stored keys — a split no diff would show.

### TomUserPreferenceKeyException

Raised for a key that does not satisfy `TomUserPreferenceKeys`.

- **Extends:** `TomException`.

#### Constructors

```dart
TomUserPreferenceKeyException(String key, String cause, String message)
```

The error key is always `preferences.key.invalid`; `parameters` carries the
offending `key` and a `cause`, so a caller can branch on the reason without
parsing prose:

| `cause` | Meaning |
| ------- | ------- |
| `empty` | The key has no characters. Addresses the list endpoint's own URI, so it would read as "all preferences" rather than fail. |
| `leading_character` | The first character is not an ASCII letter. |
| `illegal_character` | Some character after the first is outside `A-Za-z0-9._-`. |
| `too_long` | More than `maxLength` characters. |

Shape is checked before size, so an over-long key that is also malformed is
reported as malformed — the fault the caller has to fix first.

Both halves enforce the rule. The client refuses a bad key before building a
request; the server refuses it at the boundary, because the endpoints read the
key off the request URL and on that side it is untrusted input. The endpoints'
`TomUserPreferencesErrorHandler` maps it to a `400`: a malformed key is the
caller's mistake, not a server fault worth retrying.

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

A preference value may take four shapes and no others: a scalar (`String`,
`int`, `double`, `bool`), a `DateTime`, a `List` or `Map<String, …>` of **one**
scalar type, or a `@tomReflector` type — either an **enum**, written as
`{"name": "<constant>"}`, or a **class**, written as a JSON object of its
members. Scalars are plain JSON; a collection is a bare JSON array or object,
with no envelope, since the element type is already in the stored name; a
reflected class goes through the same reflection path the endpoint pipeline uses
for every other DTO.

A collection's name (`List<String>`) is *composed* from the codec's own type
constants rather than rendered from a `Type`, so it is as durable as a registry
name and for the same reason — nothing in it is a compiler rendering. That, plus
the fact that a name carrying its element type lets `validateEncoded` verify the
whole value without reflecting anything, is why collections are a shape of their
own rather than something to wrap.

Anything else is refused when it is named, by `typeNameOf`: an unreflected class
as `preferences.type.not_reflected`, and a collection outside the ten supported
shapes — an untyped `[]`, a mixed `List<Object>`, a non-`String`-keyed `Map`, a
nested collection, a `Set`, a list of reflected objects — as
`preferences.type.unsupported_collection`, a key of its own because for a
`List<Object>` "the registry does not know it" is false and "annotate it" is not
actionable. Wrap those in a reflected class.

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
| `typeNameOf(Object value, [String key = ''])` | `String` | The `valueType` the value is stored under — a scalar's own type name, a supported collection's composed name (`List<String>`), or, for anything else, the `simpleName` the reflection registry holds for its class. Not `runtimeType.toString()`: that name is written to a database column and read back by another release on another platform, and the compiler's rendering is rewritten by web minification, carries the generic instantiation (`BoxPreference<int>` vs `BoxPreference<dynamic>`), and for an SDK type can be private (`_SimpleUri` for a `Uri`) — a name no reader could ask for. The registry name is a generator-emitted literal, and is the same registry `decode` resolves `T` through, so a value can be written under a name exactly when it can be read back under it. Throws `preferences.type.not_reflected` for a class the registry does not know. An unsupported collection throws `preferences.type.unsupported_collection` **here**, before reflection is consulted: the registry answers for some of them — it knows `List` — and the value would then be stored under that name and encoded as `{}`, every element silently dropped. `key` only names the preference in those exceptions. |
| `typeNameForType(Type type, [String key = ''])` | `String` | The `valueType` a value of that type is stored under — the same registry lookup as `typeNameOf`, from a `Type` rather than a value. For a value stored under the class it is declared as the two return the same string, but they are not the same question: this names the class a *type* denotes, `typeNameOf` the class a *value* turned out to have. Two divergences follow. **Subclass**: a value whose runtime class is a subclass of the declared type is named by the subclass there and by the declared type here, which `decode<T>` reports as `preferences.decode.type_mismatch` — intended strictness, since reading it as the supertype would drop the subclass's own members. **Instantiated generic**: the registry is keyed by declaration, so `typeNameForType(BoxPreference<int>)` throws where `typeNameForType(BoxPreference)` answers and `typeNameOf(BoxPreference<int>())` answers via the instance; read a generic preference under its bare class literal, and expect it back as a `BoxPreference<dynamic>`. A supported collection `Type` (`List<String>`, `Map<String, int>`, …) resolves to its composed name without the registry. Throws `preferences.type.not_reflected` for a class the registry does not know, and `preferences.type.unsupported_collection` for a bare `List`/`Map`/`Set`/`Iterable` literal — `List` *is* `List<dynamic>`, so blaming the registry there would send the caller after the wrong fix. |
| `encode(String key, Object value, {DateTime? updatedAt})` | `TomUserPreferenceDto` | Builds the whole DTO. `updatedAt` is the server's write timestamp; a client leaves it `null`. Validates `key` against `TomUserPreferenceKeys` first — a DTO is the *addressed* artifact, so a key that cannot be addressed must not reach one; the alternative is a value that encodes successfully and is then unstorable. Unlike the optional `key` of `typeNameOf` and `encodeValue`, whose default `''` means "not decided yet", the key here is the preference's identity. Then names the value before encoding it, so an unreflected object is refused as `preferences.type.not_reflected` rather than reaching the serializer. |
| `encodeValue(Object value, [String key = ''])` | `String` | The value's JSON text alone. An enum is written as `{"name": "<constant>"}` — an object rather than a bare string, so that "a non-scalar value is a JSON object" holds without exception and `validateEncoded` can keep checking the shape from the declared type name alone. `key` names the preference in the exception and is optional, for a caller encoding before it has decided where to put the value. Throws `TomUserPreferenceCodecException`: `preferences.encode.not_json` for a number JSON cannot represent, at the top level or as a collection element, and `preferences.encode.failed` for every other unwritable value. A refusal names the cause it detected instead of one generic one and carries it as a `cause` parameter — `value_not_json`, `element_not_json`, `map_key_not_string`, `element_not_scalar`, `not_a_list_or_map`, `unreflected_class` — because only the last is fixed by the `@tomReflector` annotation the message used to advise for all of them: a `Set` and a `Map<int, …>` have no class of their own to annotate, and a `List<Thing>` stays an unsupported shape however well `Thing` is annotated, since the element type is part of the stored name. A `map_key_not_string` refusal also carries `keyType`, an `element_not_scalar` one `elementType`. An unreflected *enum* is not refused here — a constant name needs no registry — but `encode` refuses it, for having no name to be stored under. |
| `validateEncoded(String valueType, String valueJson, {String key = ''})` | `void` | Checks that the text is JSON and is shaped like the declared type. Throws `preferences.encoded.invalid_json`, `preferences.encoded.type_mismatch`, or `preferences.encoded.not_an_instant` for a `DateTime` whose text names no zone. A **collection** is checked completely — every element against the element type, and every `DateTime` element against the zone rule — because the element type is part of the stored name, so verifying it asks the server nothing it does not already have; this is the one non-scalar shape the boundary verifies in full. A **reflected** type is only required to be a JSON object — which class it names is deliberately not checked, since a preference type may be one only the client knows. That is also why an enum is stored as an object: this check sees a type *name* and cannot tell an enum from a class without reflecting it, so giving enums a shape of their own would mean either weakening the rule for every class or asking the server the question it must not ask. |
| `decode<T extends Object>(TomUserPreferenceDto dto)` | `T` | The stored value as a `T`, and **the only read** — there is no sibling taking the value's text alone, because it would have nothing to compare `T` against. Throws `preferences.decode.type_mismatch` when the stored `valueType` is not the one `T` is stored under; the comparison happens before any narrowing, so an `int` is not silently widened to a requested `double` and a stored `DateTime` is not read as the `String` its text is. Otherwise widens `int`→`double` where `T` asks for it, reads a `DateTime` as the UTC instant its text names, returns a **collection** as the exact `List<E>`/`Map<String, E>` it was stored as rather than a `dynamic`-typed one the caller must cast — with every element obeying the rule its own type obeys one level up, so a `List<double>` reads `[1, 2]` back as `[1.0, 2.0]` and a list holding one zoneless timestamp is refused whole — and reconstructs a reflected object through `createInstanceFromJson` member by member — unrecognised JSON members ignored, absent ones left at their declared defaults, so a row whose `valueType` and text disagree yields a defaulted instance. Resolves `T` through the registry once, before reading anything, and hands the resulting `ClassMirror` to the reconstruction — so a `T` the registry does not know is refused as `preferences.type.not_reflected` before the payload is looked at, and a row declared as a scalar but holding an object is reported as `preferences.decode.failed` rather than blamed on reflection. An **enum** `T` is matched against the constants it declares now, and a stored name that is not among them raises `preferences.decode.unknown_enum_constant` rather than defaulting — the tolerance the class path allows is deliberately absent, because an omitted member falls back to the value the class declares whereas an unmatched constant has no such answer, only the user's actual choice would do, and that is what has been lost. Throws `preferences.type.not_reflected`, `preferences.decode.invalid_json`, `preferences.decode.type_mismatch`, `preferences.decode.not_an_instant`, `preferences.decode.unknown_enum_constant` or `preferences.decode.failed` — including when reflection cannot instantiate a `T` that declares no no-argument constructor, which is reported as `preferences.decode.failed` rather than escaping as a reflection error. |
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
`preferences.type.unsupported_collection`,
`preferences.encode.not_json`, `preferences.encode.failed`,
`preferences.encoded.invalid_json`,
`preferences.encoded.type_mismatch`, `preferences.encoded.not_an_instant`,
`preferences.decode.type_mismatch`, `preferences.decode.invalid_json`,
`preferences.decode.not_an_instant`,
`preferences.decode.unknown_enum_constant` or
`preferences.decode.failed`.

A write refusal also carries a `cause` in `parameters`, because one key covers
several situations with different remedies: see `encodeValue` above for the six
values and what each one means.

The two `preferences.type.*` keys are not on either side of the wire: they are
raised while *naming* a value, so they belong to both the write and the read.

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
