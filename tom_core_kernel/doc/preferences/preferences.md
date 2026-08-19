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
about. `typeNameOf` can fail: for anything that is not a scalar — a reflected
class or an enum — it asks the reflection registry for the name, and a type the
registry does not know has no name it could be stored under. See
[What a preference value may be](#what-a-preference-value-may-be).

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
| `enumNameField` | The JSON member an enum's constant name is stored in |
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

#### What a preference value may be

Four shapes, and nothing else:

| Shape | Stored as | Named by |
|-------|-----------|----------|
| `String`, `int`, `double`, `bool` | plain JSON | itself |
| `DateTime` | an ISO 8601 instant in UTC | `DateTime` |
| a `List` or `Map<String, …>` of **one** scalar type | a JSON array or object | e.g. `List<String>` |
| a `@tomReflector` **enum** | `{"name": "<constant>"}` | the registry |
| a `@tomReflector` **class** | a JSON object of its members | the registry |

A value of any other shape is refused when it is *named*, by `typeNameOf`,
before anything is written.

The two reflected shapes share one rule — the value's class must carry
`@tomReflector` — so an enum is not a special case to remember. What the
annotation buys is the same either way: a name that is a literal the generator
emitted rather than one the compiler is free to rewrite, and, for an enum, the
constants to match a stored name against on the way back.

A reflected class is serialized through the same reflection path the endpoint
pipeline uses for every other DTO, so a preference object is written exactly as
it would be if it were an endpoint result.

#### A collection of scalars

A list of pinned items or a map of labels is one of the most ordinary
preferences there is, so it is a shape of its own rather than something to wrap:

```dart
final stored = TomUserPreferenceCodec.encode('ui.pinned', <String>['a', 'b']);
stored.valueType;   // 'List<String>'
stored.value;       // '["a","b"]'

TomUserPreferenceCodec.decode<List<String>>(stored);  // ['a', 'b']
```

Ten shapes qualify: a `List` of each of the five scalars, and a `Map<String, …>`
of each. There is no envelope — an array and an object are JSON's own shapes,
and the element type is already in the stored name, so a wrapper would only be a
second thing for a non-Dart client to know.

**The name is composed, not rendered.** `List<String>` is built from the codec's
own type constants, never from `Type.toString()`, which is why a collection name
survives everything a scalar name survives — minification included. This is what
makes the shape storable at all: a map literal's runtime class is the private
`_Map`, a name no reader could ever ask for.

**The boundary checks a collection completely** — every element against the
element type, and every `DateTime` element against the zone rule. Not a stricter
policy than the one for a reflected class, the same one: the element type is
part of the stored name, so verifying it asks the server nothing it does not
already have. A class *name* offers no such thing, which is the concrete reason
collections earn their own shape.

The read is symmetric. `decode<Map<String, int>>` returns exactly that, not a
`Map<String, dynamic>` to be cast, and every element obeys the rule its own type
obeys one level up — so a `List<double>` reads a JSON `[1, 2]` back as
`[1.0, 2.0]`, and a list holding one zoneless timestamp is refused whole.

**What does not qualify** is refused with
`preferences.type.unsupported_collection`, whose message states the restriction:
an untyped `[]`, a mixed `List<Object>`, a `Map` keyed by anything but `String`
(JSON object keys are strings, and any other key type would need an encoding
convention — precisely the kind of silent convention this module exists to
settle), a nested collection, a `Set`, and a list of reflected objects. Wrap
those in a reflected class, whose members can then evolve under a name that
survives. A reflected class whose *member* is a list is the supported way to
store a list of objects.

The refusal has a key of its own because `preferences.type.not_reflected` would
be untrue twice over for a `List<Object>`: the registry *does* know `List`, and
"annotate it with `@tomReflector`" is not advice a collection can act on.

#### An enum is stored by name, never by index

```dart
@tomReflector
enum ThemePreference { light, dark, highContrast }

final stored = TomUserPreferenceCodec.encode('ui.theme', ThemePreference.dark);
stored.valueType;   // 'ThemePreference'
stored.value;       // '{"name":"dark"}'

TomUserPreferenceCodec.decode<ThemePreference>(stored);  // ThemePreference.dark
```

The name and not the index, which is the convention the module exists to settle.
An index is positional, so inserting a constant silently changes what every
preference already stored means — a user who chose `dark` gets `highContrast`
after a release that added one constant above it, and nothing anywhere reports
it. The name moves only when the constant is renamed.

A renamed or removed constant is therefore the case that remains, and it is
refused rather than guessed:

| Situation | Error key |
|-----------|-----------|
| The stored name is not a constant the enum declares now | `preferences.decode.unknown_enum_constant` |

Defaulting to the first constant would hand back a setting the user never chose,
and it would be indistinguishable from one they did. The message names the
constant it could not place and the ones that exist, which is what identifies
the release that wrote the row.

The stored form is an object rather than a bare string so that "a non-scalar
value is a JSON object" stays true without exception. `validateEncoded` checks
the boundary from the declared type name and the text alone, deliberately
without reflecting the class (see
[Validating Before Storing](#validating-before-storing)), and a type name does
not say whether it belongs to an enum or a class. Giving
enums a shape of their own would mean either weakening that check for every
class or asking the server a question it must not ask.

An enum that overrides `toString` is unaffected: the type name comes from the
registry and the constant from `Enum.name`, neither of which an override
touches. (`TomObservableEnum.enumTypeSegment`, elsewhere in the kernel, *does*
read the declared name back out of `toString` and rejects such an enum — the two
mechanisms differ, and only that one cares.)

#### Which name a value is stored under

A scalar is stored under its own name — `String`, `int`, `double`, `bool`,
`DateTime` — and a supported collection under a name composed from those, such
as `List<String>`. Anything else is stored under **the name the reflection
registry holds for its class**: `typeNameOf` resolves the value through the
registry and writes the `simpleName` it finds there.

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
| Private SDK classes | `_SimpleUri` for a `Uri` — a name no caller can write, so the row is unreadable the moment it is written | Nothing: the registry does not know it, so the write is refused |

The same registry is what the read path resolves `T` through, so the two halves
are symmetric by construction: a value can be written under a name exactly when
it can be read back under it.

A collection name is neither of these. It is composed from the codec's own type
constants, so it has the durability the registry name has, for the same reason:
there is no compiler rendering in it. That is why `<String, int>{}` is storable
as `Map<String, int>` even though its runtime class is the private `_Map`.

The cost is that `typeNameOf` and `typeNameForType` can now throw
`preferences.type.not_reflected` where they previously always answered. That is
the point rather than a regression — a value with no name the reader can ask
for was already unreadable, and failing at the write is failing on the device
that can still do something about it. Callers building a write request by hand
should pass the key, so the exception names the preference.

#### Where the two naming methods diverge

`typeNameForType(type)` answers the same question from a `Type` rather than a
value, and both read the registry — so for a value stored under the class it is
declared as, the two produce the same string. That is the ordinary case, and it
is what makes the two exceptions easy to miss. They are not the same question:
`typeNameOf` names the class a **value** turned out to have, `typeNameForType`
the class a **type** denotes.

| | `typeNameOf(value)` | `typeNameForType(T)` |
|---|---|---|
| A value of the class itself | `DisplayPreference` | `DisplayPreference` — they agree |
| A value of a **subclass** | `SubPreference`, its runtime class | `BasePreference`, the type handed in |
| An **instantiated generic** | `BoxPreference`, via the instance | throws — the registry has no `BoxPreference<int>` |

**Subclasses.** A value whose runtime class is a subclass of the declared type
is named by the subclass on the way out and by the declared type on the way in,
so `decode<BasePreference>` of a row written from a `SubPreference` is refused
with `preferences.decode.type_mismatch`. That is the intended strictness rather
than a gap — reading it as the supertype would silently drop the members only
the subclass declares. Store a preference under the class it is declared as.

**Generics.** The registry is keyed by *declaration*, so it holds an entry for
`BoxPreference` and none for `BoxPreference<int>`. `typeNameOf` gets past that
because it resolves from the instance, which the registry can match against its
generic entries; a bare `Type` offers no route back to the declaration. So read
a generic preference under its **bare class literal**:

```dart
final stored = TomUserPreferenceCodec.encode('ui.box', BoxPreference<int>());
stored.valueType;                                        // 'BoxPreference'

TomUserPreferenceCodec.decode<BoxPreference>(stored);    // works
TomUserPreferenceCodec.decode<BoxPreference<int>>(stored);
// throws preferences.type.not_reflected
```

The instantiation is deliberately not part of the stored identity — one class
written from two call sites at two instantiations is one preference type — and
so it is not restored either: the value comes back as a `BoxPreference<dynamic>`.

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
| A collection that is not one of the ten supported shapes | `typeNameOf`, and so `encode` | `preferences.type.unsupported_collection` |
| A value JSON cannot represent — in practice a non-finite `double` | `encodeValue` | `preferences.encode.not_json` |
| A non-scalar value the reflection path cannot serialize | `encodeValue` | `preferences.encode.failed` |

`preferences.type.not_reflected` and `preferences.encode.failed` both mean "an
unreflected object", reached from two directions: `encode` asks for the name
first and stops there, while `encodeValue` called on its own never asks and
fails at the serializer. Nothing gets past both. An unreflected *enum* takes the
same split — its text is writable, since a constant name needs no registry, so
it is `encode` that refuses it for having no name to be stored under. So does a
mixed `List<Object>`: `["a",1]` is perfectly good JSON, so `encodeValue` writes
it and `typeNameOf` is what refuses it, for naming no supported shape.

`double.nan` and `double.infinity` are the whole of `preferences.encode.not_json`:
every other scalar encodes. They are not exotic values for a preference — a computed UI
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

How much it can check depends on how much the declared name says. A scalar is
checked exactly; a **collection** is checked exactly *and* element by element,
because the element type is in the name; a reflected class is only required to
be a JSON object, since which class the name denotes is deliberately not
resolved — a preference type may be one only the client knows.

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

A preference type that is neither a scalar nor a supported collection must be
`@tomReflector`, and the generator must have captured it. **This includes
enums** — an enum is a non-scalar like any other, and the annotation is what
supplies both its durable name and, on the way back, the constants a stored name
is matched against.

A type the generator has not captured fails at the *write*, with
`preferences.type.not_reflected`, because the registry is where the stored name
comes from and there is none to write. That is the useful place for it to fail:
the alternative is a row that stores cleanly and then fails every read of that
key, on whichever device reads it next.

Store it under the class it is *declared* as, and read a generic one under its
bare class literal — see [Where the two naming methods
diverge](#where-the-two-naming-methods-diverge) for the two cases where the name
a value is written under is not the one a caller would reach for.

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
