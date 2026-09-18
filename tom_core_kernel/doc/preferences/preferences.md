# Preferences Module

The Preferences module is the *contract* half of user preferences: the
well-known keys, the wire DTOs, the value codec, and the API declaration that a
client and a server both bind to.

## Table of Contents

- [Overview](#overview)
  - [A preference carries its own type](#a-preference-carries-its-own-type)
- [Quick Start](#quick-start)
  - [1. Import the Module](#1-import-the-module)
  - [2. Encode a Value](#2-encode-a-value)
  - [3. Decode a Value](#3-decode-a-value)
  - [4. Register the API](#4-register-the-api)
- [Core Components](#core-components)
  - [TomUserPreferenceKeys](#tomuserpreferencekeys)
  - [TomUserPreferenceDto](#tomuserpreferencedto)
  - [TomUserPreferenceWriteRequest](#tomuserpreferencewriterequest)
  - [TomUserPreferenceKeyRequest](#tomuserpreferencekeyrequest)
  - [TomUserPreferenceCodec](#tomuserpreferencecodec)
    - [What a preference value may be](#what-a-preference-value-may-be)
    - [Which name a value is stored under](#which-name-a-value-is-stored-under)
    - [A reflected value is rebuilt member by member](#a-reflected-value-is-rebuilt-member-by-member)
  - [tomUserPreferencesApi](#tomuserpreferencesapi)
    - [What "not set" looks like on the wire](#what-not-set-looks-like-on-the-wire)
    - [How big the account store can get](#how-big-the-account-store-can-get)
    - [Where the key is stated](#where-the-key-is-stated)
  - [TomUserPreferencesApiService](#tomuserpreferencesapiservice)
- [The Two Stores](#the-two-stores)
  - [When both stores hold the same key](#when-both-stores-hold-the-same-key)
- [Usage Examples](#usage-examples)
  - [Storing a Structured Preference](#storing-a-structured-preference)
  - [Preferring a Stored Value Over an Asserted One](#preferring-a-stored-value-over-an-asserted-one)
  - [Validating Before Storing](#validating-before-storing)
- [Best Practices](#best-practices)
  - [1. Read Through the Codec, Never Through `jsonDecode`](#1-read-through-the-codec-never-through-jsondecode)
  - [2. Let a Mismatch Throw](#2-let-a-mismatch-throw)
  - [3. Annotate Reflected Preference Values](#3-annotate-reflected-preference-values)
  - [4. Namespace Application Keys](#4-namespace-application-keys)
  - [5. Keep a Preference a Setting](#5-keep-a-preference-a-setting)
  - [6. Register the API Only Where It Is Used](#6-register-the-api-only-where-it-is-used)
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

The keys the framework's own code looks up. An application invents its own
freely — any key satisfying the rule below is its to use, up to the 256
preferences one principal may hold (see [How big the account store can
get](#how-big-the-account-store-can-get)); these exist so that an application
storing the same concept lands on the same key rather than a synonym.

| Constant | Value | Meaning |
|----------|-------|---------|
| `timezone` | `tom.timezone` | Preferred IANA timezone (e.g. `Europe/Berlin`) |
| `language` | `tom.language` | Preferred ISO 639-1 language code |
| `country` | `tom.country` | Preferred ISO 3166-1 alpha-2 country code |
| `theme` | `tom.theme` | Preferred UI theme name |

Constants rather than an enum: preference keys cross the wire and sit in a
database column, so their *text* is the contract.

#### What a key may be

**1 to `TomUserPreferenceKeys.maxLength` (191) characters, starting with an
ASCII letter, and thereafter only ASCII letters, digits, `.`, `_` and `-`.**

`TomUserPreferenceKeys.isValid` answers whether a key obeys the rule and
`TomUserPreferenceKeys.validate` throws a `TomUserPreferenceKeyException`
(`preferences.key.invalid`) when it does not.

A key is not free text, because it is not only a map key: the read and delete
endpoints are mounted at `/{key}`, so **a key read or deleted is a URL path
segment**. Measured against the contract's own endpoint, an unconstrained key
does not merely look odd:

| Key | Resolves to | What that is |
| --- | ----------- | ------------ |
| `a/b` | `/preferences/a%2Fb` | a `%2F` much HTTP infrastructure rejects, or normalises back to `/` — addressing a two-segment path the API never declared |
| `""` | `/preferences/` | the **collection**'s URI — the list under `GET`, and the *clear* under `DELETE` |
| `.` | `/preferences/` | the same again |
| `..` | `/` | outside the API's path entirely |

The empty key is not a contrived input: it is what
`TomUserPreferenceKeyRequest()`'s own default produces, so a caller that forgets
to set one sends it.

Two clauses are worth their reasons:

- **It starts with a letter.** That is what excludes `.` and `..` above, as a
  consequence of the rule rather than as two special cases — and with them every
  other leading character (`-`, `_`, a digit) that some reader somewhere treats
  as a flag, a hidden file or a number.
- **ASCII only.** `ü` has a composed and a decomposed Unicode form that render
  identically and compare unequal, so one *visible* key would be two stored
  keys — the silent split this vocabulary exists to prevent, in a form no diff
  would ever show.

`maxLength` is `tom_user_preference.preference_key`'s own width: a longer key is
one the server would store truncated, and two keys differing only past the cut
would silently become one row.

A write is bound by the same rule even though its key is not a path segment.
The rule is the store's vocabulary — one visible key must be one stored row —
and the store is the same one every endpoint addresses, so a key that may not
be read is a key that may not be written either.

The rule lives in the kernel rather than in either half because both halves
enforce it. A client refuses to build a request under an illegal key, and the
server refuses one that arrives anyway — the key is untrusted input whether it
came from the URL or from the body, so `TomUserPreferencesErrorHandler` answers
`400` for it. A rule stated in one half is a rule the other half's callers
discover in production.

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

`updatedAt` is UTC because the constructor converts it, not because writers
remember to. A `DateTime` cannot carry its zone in its type, so a server
writing `DateTime.now()` rather than `DateTime.now().toUtc()` would pass every
check and still be wrong — and wrong in a way that does not survive the wire,
since reflection writes a `DateTime` with `toIso8601String()` (no zone marker
for a local one) and reads it back with `DateTime.parse` (which resolves a
zoneless string against the *reading* device). Normalising at construction is
what keeps the stored instant the same instant everywhere. Assigning the field
directly afterwards is not intercepted: a reflected DTO's fields are plain and
public, so there is no setter to hook.

### TomUserPreferenceWriteRequest

The same three fields minus the timestamp. *When* a preference was written is
the server's answer, never the client's claim, so there is no timestamp field
on the request to disagree about.

Its `key` is the write's only statement of which preference it means: the write
endpoint is a `PUT` at `/preferences`, with no `{key}` in the path — see
[Where the key is stated](#where-the-key-is-stated).

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

The cost is that `typeNameOf` and `typeNameForType` can throw
`preferences.type.not_reflected` instead of answering. That is the point: a
value with no name the reader can ask for is unreadable either way, and failing
at the write is failing on the device that can still do something about it. Callers building a write request by hand
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
| A value JSON cannot represent — in practice a non-finite `double`, at the top level or as a collection element | `encodeValue` | `preferences.encode.not_json` |
| A value whose JSON text could not be written for any other reason | `encodeValue` | `preferences.encode.failed` |
| A value whose JSON text is longer than `maxValueBytes` (16 KiB of UTF-8) | `encodeValue`, and so `encode` | `preferences.encode.too_large` |

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
value that went wrong. A non-finite *element* takes the same key rather than a
shape key: `[1.0, double.nan]` is a well-formed `List<double>` that `typeNameOf`
names without complaint, so the defect is the number, not the shape.

##### A write refusal names the cause it detected

Five situations reach the write refusal and they have five different remedies,
only one of which is the `@tomReflector` annotation. Each refusal therefore
names its own, and carries a `cause` entry in `parameters` so a caller that has
to branch is not left parsing prose:

| `cause` | The value | The remedy |
|---------|-----------|------------|
| `value_not_json` | a non-finite number | store a finite one, or a `String` naming the special case |
| `element_not_json` | a collection holding one | the same, one level on |
| `map_key_not_string` | a `Map` keyed by anything but `String` | key it by `String`, or wrap it |
| `element_not_scalar` | a `List` or `Map` holding an element that is not a scalar | wrap the whole collection |
| `not_a_list_or_map` | a `Set`, or a lazy `Iterable` | `toList()` it, which makes the order part of the stored value |
| `unreflected_class` | an instance of a class the registry does not know | annotate the class with `@tomReflector` |

The distinction is not cosmetic. A `Set` and a `Map<int, String>` have no class
of their own to annotate, and a `List<Thing>` stays an unsupported shape however
well `Thing` is annotated — the element type is part of the stored name, so
`List<Thing>` is still no name a preference can be stored under. Advice a caller
cannot act on costs more time than no advice, because it reads as a fix and only
turns out not to be one after it has been tried.

The `cause` for a `Map` also carries `keyType`, and the one for an element
carries `elementType`, so the offending part is named and not only the whole.
Neither message repeats the value's `runtimeType` in its prose where that would
be a private SDK class: a `Map<int, String>` literal is a `_Map<int, String>`,
and telling a reader their value is a `_Map` explains nothing they can use. The
raw runtime type stays available as the `valueType` parameter.

`encodeValue` takes the preference key as an optional second argument so the
exception can name *which* preference failed rather than only which line;
`encode(key, value)` passes its own key down.

Only `encode` *validates* that key. Its key is the preference's identity — a DTO
is the addressed artifact, so a key that cannot be addressed must not reach one,
and `encode` raises `TomUserPreferenceKeyException` before it encodes anything.
The key `typeNameOf` and `encodeValue` take is a different thing: it is
optional, and its default `''` means "the caller has not decided on a key yet"
— a perfectly ordinary state for code that is naming a type before it knows
where the value will live. Checking it there would refuse the documented
default.

### tomUserPreferencesApi

The API declaration, mounted at `/preferences`.

| Endpoint id | Method | URI | Request | Result | When the preference is not there |
|-------------|--------|-----|---------|--------|----------------------------------|
| `listPreferences` | GET | `` | — | `List<TomUserPreferenceDto>` | not in the list |
| `readPreference` | GET | `/{key}` | `TomUserPreferenceKeyRequest` | `TomUserPreferenceDto` | `404` + envelope, `errorKey` = `tomUserPreferencesNotFoundErrorKey` |
| `writePreference` | PUT | `` | `TomUserPreferenceWriteRequest` | `TomUserPreferenceDto` | created |
| `deletePreference` | DELETE | `/{key}` | `TomUserPreferenceKeyRequest` | `void` | `200` — deleting nothing succeeds |
| `clearPreferences` | DELETE | `` | — | `void` | `200` — clearing nothing succeeds |

The two kinds of nothing in that table are different. `listPreferences` and
`clearPreferences` take no request at all — their `requestTypes` are empty, and
the `—` says so. `deletePreference` does have a request; what it has none of is
a *result*: the handler returns nothing, the pipeline answers `200` with an
empty body, and `void` is the declaration that says exactly that.
`TomUserPreferencesApiService` spells the same thing `Future<void>`.

**The two deletes are one path segment apart.** `deletePreference` removes one
preference and `clearPreferences` removes every one, and they differ only in
whether a segment follows the collection — the same collection/item pair the
two `GET`s form, except that here the two answers are very different sizes. A
caller that resolved the by-key URI with an **empty** key would address the
clear; that is one of the reasons the key vocabulary refuses the empty key, and
why both halves validate a key before they build a URI rather than after.

`clearPreferences` takes nothing and answers nothing. It takes nothing because a
partial clear is `deletePreference` repeated and a caller that wants one already
has it — and because taking nothing is what lets the server do it in one
statement. It answers nothing because how many preferences went is the store's
business: the only branch a count could support is "some were already gone",
which is the case the idempotence exists to make uninteresting.

An account reset is why the endpoint exists. Written as a loop — list, then
delete each — it can stop half way, and what it leaves is a set of preferences
nobody chose. On this store that half-reset state is shared by every device the
user owns, so the operation is the server's to do atomically or not at all.

#### What "not set" looks like on the wire

The read's result type is `TomUserPreferenceDto`, not `TomUserPreferenceDto?`,
because the endpoint pipeline answers a `null` result exactly as it answers a
`void` one — `200` with an empty body — and "not set" would then look like
success. So absence is an *error of the invocation*: the server raises the key
`tomUserPreferencesNotFoundErrorKey` (`preferences.not_found`) and answers

```text
GET /preferences/tom.theme
→ 404  Content-Type: application/json   x-tom-error: true
{"errorKey": "preferences.not_found", …}
```

**The key is the signal, not the status.** The pipeline answers a denied or
unauthenticated call with a `404` too — a *bare* one, plain text and no
envelope, so that a refusal cannot be told from a route that does not exist —
and a deployment that never mounted the API answers the same way. A caller that
read every `404` as "not set" would hand a signed-out user the defaults. The
rule is therefore:

| Answer | Meaning |
|--------|---------|
| `200` with a DTO | The preference as stored. |
| `404` whose envelope's `errorKey` is `tomUserPreferencesNotFoundErrorKey` | Never written by this caller — an ordinary state, answered with a default. |
| `404` without that envelope | Refused, or no such route — a failure. |
| `400` with `errorKey` `preferences.key.invalid` | The key is not a legal key — the caller's own mistake. |
| anything else | A failure. |

The constant is declared here, beside the endpoints, because both halves use it:
`tom_core_server` raises it and `tom_core_flutter`'s `TomUserPreferencesClient`
recognises it, answering `null` from `read` and `get` for that answer and
throwing for every other one.

Neither delete ever answers it. Deleting a preference that is not there has
already achieved its purpose and answers `200`, and so does clearing an account
that holds nothing — so a `404` from either is always a refusal.

#### How big the account store can get

`listPreferences` takes no page and no filter, and answers every preference the
caller holds. That is a decision, not an omission: every caller of the list —
one that renders a settings screen, one that syncs a device — wants all of it,
and a paged answer would make each of them loop to get it. It is only safe
because the store is bounded by construction, by two ceilings the contract
declares:

| Ceiling | Value | Enforced by | Refusal |
|---------|-------|-------------|---------|
| `tomUserPreferencesMaxPerPrincipal` — preferences one principal may hold | 256 | the server, on a write that would **add** a key | `409`, `errorKey` `preferences.limit.exceeded` (`tomUserPreferencesLimitExceededErrorKey`) |
| `TomUserPreferenceCodec.maxValueBytes` — the encoded value of one preference | 16 KiB of UTF-8 | the codec: `encodeValue` on the writing side, `validateEncoded` at the server's boundary | `preferences.encode.too_large` before a request is made; `400`, `errorKey` `preferences.encoded.too_large` from the server |

So the largest list the endpoint can ever answer is about four megabytes, and a
real one — a timezone, a language, a theme and a handful of application
settings — is a few hundred bytes. The list endpoint and the write endpoint both
state their ceilings in their own `description`, so a reader of the declaration
finds them where the endpoint is declared.

**Replacing a preference is never refused for the count.** A principal at the
ceiling can still change every setting it has; deleting one frees a place. The
count is read before an insert, so two inserts racing for the last place can both
succeed and leave the caller one or two over — the ceiling exists to keep the
list small, not to be exact.

**The ceilings say what a preference is for.** 256 is far beyond what settings
need, and 16 KiB holds a reflected settings object with dozens of members. An
application that reaches either has put data in a preference that belongs in a
table of its own — a preference *per document* or *per project* is the usual
case, and it is exactly the shape that would otherwise make every device
download everything on every sync.

The value ceiling is the codec's, not the endpoint's, so it applies to every
store that encodes through the codec — `tom_core_flutter`'s device store as well
as the account store. A value one store would take is a value every store takes,
which is what lets a preference move between them.

#### Where the key is stated

Three endpoints name a preference, and each names it exactly once.

Read and delete take a `TomUserPreferenceKeyRequest`, whose only field is bound
from the `{key}` path capture: the URL is the whole request, and the body is
empty. The write is the other way round. Its request already carries a `key`
field of its own — it has to, because a write states a key, a type and a value
together — so the endpoint declares **no** `{key}` capture and no
`urlParameterMapping`, and is a `PUT` at the collection:

```text
PUT /preferences
{"key": "tom.theme", "valueType": "String", "value": "\"dark\""}
```

The alternative — `PUT /preferences/tom.theme` with a body naming
`tom.language` — is a single request that names two different preferences, and
no answer to "which one is written" is a good one. Silently preferring the path
makes a body field that is read on some endpoints and ignored on this one;
rejecting the pair spends a status code on a state the contract could simply
not have. Dropping the capture removes the question: there is no second place
for the key to be stated, so there is nothing to disagree with.

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

### When both stores hold the same key

A key normally belongs to exactly one store, but nothing prevents the same key
from being written to both — and a device-side override of an account-wide
setting is the natural reason to do it. When both hold it, **the device value
wins for as long as it exists**, and the server value answers only a key this
device has never written.

That order matches what the user did. Writing a preference on *this* device is
a later, more deliberate and more specific act than the value that arrived with
the account, so the account value behaves as a cross-device default and the
device value as this machine's override. Reversed, a setting the user changed
here would revert the moment their other device wrote the same key. It is the
same relationship the client-configuration module has between shipped defaults
and install overrides.

| Device store | Server store | Answer |
| ------------ | ------------ | ------ |
| holds the key | holds the key | the device value — the server is not asked |
| holds the key | does not | the device value |
| does not | holds the key | the server value |
| does not | does not | nothing (`null`) |

The rule is applied in one place, `tom_core_flutter`'s
`TomDevicePreferences.getPreferred`, which reads the device first and consults
the server only when the device has no answer — so a device that has written
the key never pays for the round trip. Its tests cover each row of the table
above against every device backend — memory, file and read-only — and again
through the real HTTP client, and reversing the order or asking the server
eagerly fails them.

The kernel declares no resolver of its own, on purpose: it owns no device store,
so a kernel resolver could only take two lookups and return the first non-null
one, and the one reader that combines the stores already does exactly that next
to the store it reads. A client outside the Flutter binding that reads both
stores applies the same order — the local answer first, the server's only when
the local one is absent, and the server not asked at all when the local one is
present.

## Usage Examples

### Storing a Structured Preference

```dart
@tomReflector
class DisplayPreference {
  String theme = 'light';
  int fontSize = 14;
  bool compact = false;
}

final preference = DisplayPreference()
  ..theme = 'dark'
  ..fontSize = 18;

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

The fields are plain and non-`final`, and every one of them has a value before
anything is stored. Both matter, and for the same reason: reading a preference
back calls the class's no-argument constructor and then assigns members, so a
`final` field could not be assigned and an un-defaulted one would have no value
for a member the stored payload happens to omit. Where the default comes
from — a field initializer, as here, or a defaulted constructor parameter — is
yours to choose; the framework's own DTOs use both.

Reading it back gives a genuinely reconstructed instance. The value arrives as
a `TomUserPreferenceDto`, and it is the DTO's own `valueType` that decides
whether the read is allowed to produce a `DisplayPreference` at all:

```dart
Future<DisplayPreference> readDisplay(
  TomUserPreferencesApiService preferences,
) async {
  final TomUserPreferenceDto stored = await preferences.readPreference(
    TomUserPreferenceKeyRequest(key: 'ui.display'),
  );
  return TomUserPreferenceCodec.decode<DisplayPreference>(stored);
}
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

The annotation is not the answer to every write refusal, and the exception says
which refusal it is. Annotating the element class of a `List<Thing>` does not
make the list storable — wrap the collection instead; a `Set` and a
`Map<int, String>` have nothing to annotate at all. Read the `cause` before
reaching for `@tomReflector`.

### 4. Namespace Application Keys

The framework's keys start with `tom.`. Give an application's own keys a prefix
too, so a later framework key cannot collide with one already in the field. A
prefix is a convention on top of the rule in [What a key may
be](#what-a-key-may-be), not a second rule: `TomUserPreferenceKeys` says what a
key *can* be, and a prefix says which part of that space is yours.

### 5. Keep a Preference a Setting

A preference is a setting that follows the user, not a place to keep data. The
store is bounded — at most 256 preferences per principal, each at most 16 KiB of
encoded value (see [How big the account store can get](#how-big-the-account-store-can-get))
— and the bounds are what make it safe to hand every device the whole list. A
key minted per document, per project or per record is a table's worth of rows
and belongs in a table.

### 6. Register the API Only Where It Is Used

`registerTomUserPreferencesApi()` is explicit rather than run from a top-level
initializer: a deployment that stores no preferences should not carry the API in
its registry.

---

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:convert` | dart | `user_preference_codec.dart` | `jsonEncode` / `jsonDecode` in `user_preference_codec.dart`, which is how a preference value crosses the store boundary as text |
| `tom_reflection` | package | `user_preference_codec.dart` | `tomReflector`, `ClassMirror` and `TomReflectionInfo` — a preference object crosses the wire as reflected JSON |
| [http_connection](../http_connection/http_connection.md) | module | `user_preferences_contract.dart` | `TomApi`, `TomApiEndpoint`, the API registry |
| [little_things](../little_things/little_things.md) | module | `user_preference_codec.dart`, `user_preference_keys.dart` | `TomException`, the base of the codec's exception |
| [reflection](../reflection/reflection.md) | module | `user_preference_codec.dart`, `user_preferences_contract.dart` | `@tomReflector` and the JSON conversion path |
| [security](../security/security.md) | module | `user_preferences_contract.dart` | `TomAuthenticatedAccess` for the endpoint access policy |
