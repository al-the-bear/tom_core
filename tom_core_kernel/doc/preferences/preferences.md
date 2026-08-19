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
  valueType: TomUserPreferenceCodec.typeNameOf(timezone),
  value: TomUserPreferenceCodec.encodeValue(
    timezone,
    TomUserPreferenceKeys.timezone,
  ),
);
```

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
| `valueType` | `String` | The name of the type `value` was written as |
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
| `typeNameOf(value)` | The type name a value is stored under |
| `encode(key, value, {updatedAt})` | Builds the whole DTO |
| `encodeValue(value, [key])` | The JSON text alone |
| `validateEncoded(valueType, valueJson, {key})` | Checks an already-encoded pair |
| `decode<T>(dto)` | The stored value as a `T` |
| `decodeValue<T>(json, [key])` | The JSON text alone as a `T` |
| `parseInstant(text)` | The instant `text` names, or `null` if it names none |

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
| `decodeValue` / `decode` | `preferences.decode.not_an_instant` |

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

#### Every write failure is a codec exception

`encodeValue` reports both of its failures as a
`TomUserPreferenceCodecException`, which is the only exception the rest of this
module tells callers to catch:

| Cause | Error key |
|-------|-----------|
| A value JSON cannot represent — in practice a non-finite `double` | `preferences.encode.not_json` |
| A non-scalar value the reflection path cannot serialize | `preferences.encode.failed` |

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
  valueType: TomUserPreferenceCodec.typeNameOf(preference),
  value: TomUserPreferenceCodec.encodeValue(preference, 'ui.display'),
);
```

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

### 3. Annotate Reflected Preference Values

A non-scalar preference type must be `@tomReflector`, and the generator must
have captured it. A class it has not captured fails at the *decode* — on
whichever device reads it next — not at the write.

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
