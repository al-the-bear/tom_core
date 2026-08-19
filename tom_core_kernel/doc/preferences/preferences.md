# Preferences Module

The Preferences module is the *contract* half of user preferences: the
well-known keys, the wire DTOs, the value codec, and the API declaration that a
client and a server both bind to.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
- [The Two Stores](#the-two-stores)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)
- [Dependencies](#dependencies)

---

## Overview

A preference is a typed value belonging to one user. The *store* is not here —
server-stored preferences live in `tom_core_server`
(`TomUserPreference` + `TomUserPreferences`), and device-stored ones live on the
client. What lives here is the part both halves must agree on:

- **`TomUserPreferenceKeys`** — the keys the framework itself reads.
- **`TomUserPreferenceDto`**, **`TomUserPreferenceWriteRequest`**,
  **`TomUserPreferenceKeyRequest`** — the shapes a preference takes on the wire.
- **`TomUserPreferenceCodec`** — how a value becomes JSON text and comes back.
- **`tomUserPreferencesApi`** — the URI, method, request type, result type and
  access policy of every preference endpoint.

The kernel is the framework's contracts package: it is the one package a client
and a server both already depend on, so declaring any of the above elsewhere
would mean one of them re-stating it — and a re-stated contract is a contract
that drifts.

### A preference carries its own type

A stored preference is JSON text *plus the name of the type it was written as*.
JSON forgets types — `3` is an `int` and a `double`,
`"2026-01-01T00:00:00Z"` is a `String` and a `DateTime`, and an object is every
reflected class at once — so the type name travels with the value. That is what
lets a reflected object be reconstructed, and what makes a mismatched read fail
loudly instead of quietly parsing a `Duration` as an `int`.

Read the last sentence literally: it is **the type name** that makes a
mismatched read fail, so a read that cannot see the type name cannot fail. That
is why `decode` takes the whole DTO and why the module offers nothing that
takes the value's text on its own — see
[A reflected value is rebuilt member by member](#a-reflected-value-is-rebuilt-member-by-member).

## Quick Start

### 1. Import the Module

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
```

### 2. Encode a Value

```dart
const timezone = 'Europe/Berlin';

final request = TomUserPreferenceWriteRequest(
  key: TomUserPreferenceKeys.timezone,
  valueType: TomUserPreferenceCodec.typeNameOf(
    timezone,
    TomUserPreferenceKeys.timezone,
  ),
  value: TomUserPreferenceCodec.encodeValue(
    timezone,
    TomUserPreferenceKeys.timezone,
  ),
);
```

Both calls take the key so that a failure can name the preference it was
about. `typeNameOf` can fail: for anything that is not a scalar it asks the
reflection registry for the name, and a class the registry does not know has
no name it could be stored under.

### 3. Decode a Value

```dart
final TomUserPreferenceDto stored = await readPreferenceFromServer();
final String timezone = TomUserPreferenceCodec.decode<String>(stored);
```

### 4. Register the API

```dart
registerTomUserPreferencesApi(); // idempotent; both halves may call it
```

## Core Components

### TomUserPreferenceKeys

The keys the framework's own code looks up. A key is any string, so an
application is free to invent its own; these exist so that an application
storing the same concept lands on the same key rather than a synonym.

| Constant | Value | Meaning |
|----------|-------|---------|
| `timezone` | `tom.timezone` | Preferred IANA timezone (e.g. `Europe/Berlin`) |
| `language` | `tom.language` | Preferred ISO 639-1 language code |
| `country` | `tom.country` | Preferred ISO 3166-1 alpha-2 country code |
| `theme` | `tom.theme` | Preferred UI theme name |

Constants rather than an enum: preference keys cross the wire and sit in a
database column, so their *text* is the contract.

### TomUserPreferenceDto

One stored preference as it travels the wire.

| Property | Type | Description |
|----------|------|-------------|
| `key` | `String` | The preference key |
| `valueType` | `String` | The name the value's type is stored under — see [Which name a value is stored under](#which-name-a-value-is-stored-under) |
| `value` | `String` | The value's JSON text |
| `updatedAt` | `DateTime?` | When the server last wrote it, in UTC |

`value` is text rather than a decoded `Object?` so the DTO stays flat: a
`Map<String, Object?>` field would have to survive the reflection serializer
twice — once as the DTO's own field and again as the preference's payload — and
the two nestings do not compose.

### TomUserPreferenceWriteRequest

The same three fields minus the timestamp. *When* a preference was written is
the server's answer, never the client's claim, so there is no field on the
request to disagree about.

### TomUserPreferenceKeyRequest

A single `key`, for reading and deleting. A DTO rather than a bare `String`
parameter because the path capture binds onto a typed field, the same way the
rest of the framework's by-id endpoints do.

### TomUserPreferenceCodec

Encodes and decodes preference values.

| Member | Purpose |
|--------|---------|
| `stringType` / `intType` / `doubleType` / `boolType` / `dateTimeType` | The scalar type names |
| `typeNameOf(value, [key])` | The name a value is stored under |
| `typeNameForType(type, [key])` | The name a value of that type is stored under |
| `encode(key, value, {updatedAt})` | Builds the whole DTO |
| `encodeValue(value, [key])` | The JSON text alone |
| `validateEncoded(valueType, valueJson, {key})` | Checks an already-encoded pair |
| `decode<T>(dto)` | The stored value as a `T` — the only way to read one |
| `parseInstant(text)` | The instant `text` names, or `null` if it names none |

The read side is one method, not two. There is no counterpart to `encodeValue`
taking the value's text on its own: it would have nothing to compare the
caller's `T` against, and the guarantee below would then hold only for callers
who picked the other method.

A `DateTime` is always written in UTC: a preference follows the user across
devices, and an instant carrying one device's local offset would come back
meaning a different moment on the next.

The read path enforces that rather than trusting the writer. Nothing obliges a
client to use `encodeValue` — a hand-built write request, or a non-Dart client,
can put its own text on the wire — so a stored timestamp is required to name its
zone, with a trailing `Z` or an explicit offset. One that does not is refused:

| Path | Error key |
|------|-----------|
| `validateEncoded` | `preferences.encoded.not_an_instant` |
| `decode` | `preferences.decode.not_an_instant` |

The alternative is worse than an error. `2026-03-04T05:06:07` is well-formed and
completely ambiguous — `DateTime.parse` reads it as local time *in the reading
process's zone*, so the same stored text denotes a different instant on every
device. `.toUtc()` does not rescue it: the resulting value is UTC-*flagged*, so
the flag proves a conversion happened and says nothing about which zone it
converted from. A date-only `2026-03-04` is the same case; it means local
midnight.

`parseInstant` is that test, exposed: a client building its own write request can
check its text and get the same verdict the boundary will give.

A non-scalar value must be a `@tomReflector` class. It is serialized through the
same reflection path the endpoint pipeline uses for every other DTO, so a
preference object is written exactly as it would be if it were an endpoint
result.

#### Which name a value is stored under

A scalar is stored under its own name — `String`, `int`, `double`, `bool`,
`DateTime`. Anything else is stored under **the name the reflection registry
holds for its class**: `typeNameOf` resolves the value through the registry and
writes the `simpleName` it finds there.

That is deliberately *not* `value.runtimeType.toString()`, which is what the
name would otherwise be. This string is written into a database column, sent
across the wire, and read back — possibly by a different release of a different
application on a different platform, which is the whole premise of the module.
The compiler's rendering of a type is not durable enough for that job, in three
concrete ways:

| Hazard | What `runtimeType.toString()` gives | What the registry gives |
|--------|-------------------------------------|-------------------------|
| Web minification | The obfuscated name, so a client compiled with `dart compile js -O4` and a server running from source disagree about the same class | A string literal the generator emitted, which minification cannot rewrite |
| Generics | `BoxPreference<int>` from a value and `BoxPreference<dynamic>` from the bare class literal — the write and the read can never meet | `BoxPreference` from both; one class is one preference type, whatever it was instantiated at |
| Private SDK classes | `_Map<String, int>` for a plain map — a name no caller can write, so the row is unreadable the moment it is written | Nothing: the registry does not know it, so the write is refused |

The same registry is what the read path resolves `T` through, so the two halves
are symmetric by construction: a value can be written under a name exactly when
it can be read back under it.

The cost is that `typeNameOf` and `typeNameForType` can now throw
`preferences.type.not_reflected` where they previously always answered. That is
the point rather than a regression — a value with no name the reader can ask
for was already unreadable, and failing at the write is failing on the device
that can still do something about it. Callers building a write request by hand
should pass the key, so the exception names the preference.

`typeNameForType(type)` answers the same question from a `Type` rather than a
value. It agrees with `typeNameOf` on the class — both read the registry — but
it can only see the type it is handed: a value whose runtime class is a
*subclass* of the declared type is named by the subclass on the way out and by
the declared type on the way in, and `decode<T>` will report that as a
`preferences.decode.type_mismatch`. Store a preference under the class it is
declared as.

#### A reflected value is rebuilt member by member

Decoding a reflected preference is not a type test followed by a cast — it
constructs a blank instance and assigns the members it recognises. A JSON
member the class does not declare is ignored; a member the class declares but
the payload omits keeps its declared default. So a payload belonging to a
*different* reflected class decodes to a fully-defaulted instance, and an empty
object decodes to nothing but defaults. Neither is an error.

The `valueType` is what stops that being a hazard. `decode<T>(dto)` compares
the stored type name against `T` and refuses a mismatch with
`preferences.decode.type_mismatch` before a single member is assigned, so a
caller asking for the wrong class never reaches the reconstruction at all.

What remains is a *row* whose declared type and text disagree — written by a
buggy producer, or hand-edited in the database. Nothing on the read side can
catch that: a JSON object is shaped like every reflected class at once, so
there is no evidence in the payload of which one wrote it. The boundary does
not catch it either, and says why not: `validateEncoded` deliberately declines
to reflect a type it may not know. A mislabelled row is therefore the one way
a defaulted instance still comes back, and it is a data fault rather than a
caller's mistake.

The scalar case is the opposite, which is worth stating because it explains why
the guard has to exist at all: a decoded scalar carries its own runtime type, so
narrowing has something to test — but only *after* the `valueType` check has
already refused the same mistake. `3` is a valid `double`, and
`"2026-03-04T05:06:07Z"` is a valid `String`; the declared type is what makes
either read wrong.

Best-effort applies to a payload's members, not to whether the type is
reflected at all: a class the generator never captured is still refused, with
`preferences.type.not_reflected` — and refused before the payload is looked at,
because the read starts by asking the registry what name `T` is stored under.

#### Every write failure is a codec exception

Every failure of the write path is a `TomUserPreferenceCodecException`, which
is the only exception the rest of this module tells callers to catch:

| Cause | Raised by | Error key |
|-------|-----------|-----------|
| A value whose class has no name it could be stored under | `typeNameOf`, and so `encode` | `preferences.type.not_reflected` |
| A value JSON cannot represent — in practice a non-finite `double` | `encodeValue` | `preferences.encode.not_json` |
| A non-scalar value the reflection path cannot serialize | `encodeValue` | `preferences.encode.failed` |

The first two rows both mean "an unreflected object", reached from two
directions: `encode` asks for the name first and stops there, while
`encodeValue` called on its own never asks and fails at the serializer. Nothing
gets past both.

`double.nan` and `double.infinity` are the whole of the first row: every other
scalar encodes. They are not exotic values for a preference — a computed UI
scale produces a NaN the moment the number it divided by is zero — and JSON has
no notation for either, so there is nothing to store and no substitute worth
storing. Refusing at the write is the only place the caller still holds the
value that went wrong.

`encodeValue` takes the preference key as an optional second argument so the
exception can name *which* preference failed rather than only which line;
`encode(key, value)` passes its own key down.

### tomUserPreferencesApi

The API declaration, mounted at `/preferences`.

| Endpoint id | Method | URI | Request | Result |
|-------------|--------|-----|---------|--------|
| `listPreferences` | GET | `` | — | `List<TomUserPreferenceDto>` |
| `readPreference` | GET | `/{key}` | `TomUserPreferenceKeyRequest` | `TomUserPreferenceDto` |
| `writePreference` | PUT | `/{key}` | `TomUserPreferenceWriteRequest` | `TomUserPreferenceDto` |
| `deletePreference` | DELETE | `/{key}` | `TomUserPreferenceKeyRequest` | — |

Every endpoint is `TomAuthenticatedAccess`, and that is the only policy the
contract can state: there is no anonymous preference, because a preference is
per principal and an anonymous caller is not one.

**Which** rows a caller reaches is deliberately *not* decided here. The server's
entity declares a row scope on the principal column, so the repository ANDs the
caller's own id into every read and rejects every write that would touch another
principal's row. No URI carries a principal parameter for exactly that reason:
there is nothing to ask for but your own.

### TomUserPreferencesApiService

The contract's Dart face — implemented by the server, and by any hand-written or
generated client caller. It carries no annotation, because the server-side ones
live in `tom_core_server` and cannot be named from the kernel.

## The Two Stores

Preferences come in two kinds, and the split is a design decision rather than an
implementation detail:

| | Server-stored | Device-stored |
|-|---------------|---------------|
| Home | `tom_core_server` `preferences` module | the client |
| Follows | the user, across devices | the device |
| Example | preferred timezone, language | window size, last-opened tab |

Both use the keys, DTOs and codec declared here, so a value can move between
them without being re-encoded. Deciding *which* store a given preference belongs
in is the application's call: ask whether the answer should change when the user
picks up a different device.

## Usage Examples

### Storing a Structured Preference

```dart
@tomReflector
class DisplayPreference {
  String theme = 'light';
  int fontSize = 14;
  bool compact = false;
}

final request = TomUserPreferenceWriteRequest(
  key: 'ui.display',
  valueType: TomUserPreferenceCodec.typeNameOf(preference, 'ui.display'),
  value: TomUserPreferenceCodec.encodeValue(preference, 'ui.display'),
);
```

The `@tomReflector` annotation is what makes this work at all: `typeNameOf`
takes the stored name from the registry the annotation puts the class in, so
dropping the annotation does not silently store the value under the compiler's
name — it refuses the write with `preferences.type.not_reflected`.

Reading it back gives a genuinely reconstructed instance:

```dart
final display = TomUserPreferenceCodec.decode<DisplayPreference>(stored);
```

### Preferring a Stored Value Over an Asserted One

```dart
String resolveTimezone(TomUserPreferenceDto? stored, String clientAsserted) {
  if (stored == null) return clientAsserted;
  return TomUserPreferenceCodec.decode<String>(stored);
}
```

The stored value is the user's *choice*; the client-asserted one is only
wherever the device happens to be. That is the order the framework's own
authentication path uses.

### Validating Before Storing

```dart
TomUserPreferenceCodec.validateEncoded(
  request.valueType,
  request.value,
  key: request.key,
);
```

The server runs this check before it stores; a client can run the same one to
fail early. A disagreeing pair costs nothing to store and breaks every future
read of that key — on every device.

## Best Practices

### 1. Read Through the Codec, Never Through `jsonDecode`

The codec is what makes both halves agree on a `DateTime`'s zone and a
mismatch's outcome. A caller that decodes the text itself has quietly opted out
of both.

### 2. Let a Mismatch Throw

`decode<T>` refuses a stored type it was not asked for rather than coercing. Do
not wrap it in a `try` that returns a default: an unwritten preference is an
ordinary state that a default answers, while a preference stored as the wrong
type is a bug, and defaulting hides it.

There is nothing to reach past it to. Read through the DTO even when the text
is all you were handed — building one is how you state what you believe the
text to be, and stating it is what lets the codec disagree. See
[A reflected value is rebuilt member by member](#a-reflected-value-is-rebuilt-member-by-member).

### 3. Annotate Reflected Preference Values

A non-scalar preference type must be `@tomReflector`, and the generator must
have captured it. A class it has not captured fails at the *write*, with
`preferences.type.not_reflected`, because the registry is where the stored name
comes from and there is none to write. That is the useful place for it to fail:
the alternative is a row that stores cleanly and then fails every read of that
key, on whichever device reads it next.

### 4. Namespace Application Keys

The framework's keys start with `tom.`. Give an application's own keys a prefix
too, so a later framework key cannot collide with one already in the field.

### 5. Register the API Only Where It Is Used

`registerTomUserPreferencesApi()` is explicit rather than run from a top-level
initializer: a deployment that stores no preferences should not carry the API in
its registry.

---

## Dependencies

This module depends on:

- **HTTP Connection Module**: `TomApi`, `TomApiEndpoint`, the API registry
- **Reflection Module**: `@tomReflector` and the JSON conversion path
- **Security Module**: `TomAuthenticatedAccess` for the endpoint access policy
- **Little Things Module**: `TomException`, the base of the codec's exception
