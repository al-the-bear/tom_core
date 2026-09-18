# Resources Module

Typed, UI-bound access to the kernel **configuration** resources. A
`TomProperty<T>` resolves a single config key to a typed value **once, at
construction**, and caches it — handy for binding a config value to a field on
a service or view-model.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Resolution Rules](#resolution-rules)
- [A Property Is a Snapshot](#a-property-is-a-snapshot)
- [Structured Values](#structured-values)
- [Core Components](#core-components)
- [Limitations](#limitations)
- [Dependencies](#dependencies)

---

## Overview

| Type | Holds | Notes |
| ---- | ----- | ----- |
| `TomProperty<T>` | `T` | Generic base; prefer a typed subclass, except when `T` is nullable |
| `TomStringProperty` | `String` | |
| `TomIntProperty` | `int` | |
| `TomDoubleProperty` | `double` | A configured whole number widens — see [Resolution Rules](#resolution-rules) |
| `TomBoolProperty` | `bool` | |
| `TomPropertyException` | — | Raised when resolution fails; one type, two `key` codes |

Each reads from the application
[`TomConfigResourceProvider`](../../tom_core_kernel/doc/resources/resources.md)
(the same provider the kernel uses for config lookups).

## Quick Start

```dart
import 'package:tom_core_flutter/tom_core_flutter.dart';

// Given config: { 'app.title': 'My App', 'app.retries': 3 }
final title = TomStringProperty('app.title');
print(~title);        // 'My App'  (operator form)
print(title.get());   // 'My App'  (method form)

// Fall back to a default when the key is absent:
final retries = TomIntProperty.withDefault('app.retries', 5);
```

## Resolution Rules

Evaluated **once, in the constructor**, from a **single** config lookup — one
read answers both whether the key is present and what it holds, on the failure
path as much as the success path:

1. If the config key resolves to a value, it is cast to `T`.
2. If that cast fails and the value is an `int` while `T` accepts a `double`,
   the value is widened. See [A whole number fills a
   double](#a-whole-number-fills-a-double).
3. If the cast fails otherwise, construction throws `TomPropertyException` with
   the key `resources.property.type_mismatch`, naming the key and value, and
   carrying the `TypeError` as its `rootException`.
4. Otherwise, if a default was supplied via `.withDefault`, the default is used.
5. Otherwise (absent key, no default) construction throws
   `TomPropertyException` with the key `resources.property.not_configured`.

A failure to read the configuration at all is not one of these: it propagates
as whatever the provider raised, and is never re-reported as a cast failure.

### A whole number fills a double

A configuration file cannot say "double". `rate: 2` in YAML and `"rate": 2` in
JSON both decode to an `int`, so a value the operator wrote for a
`TomDoubleProperty` would otherwise fail the property declared to read it —
while the reflected configuration path widens the same value onto a declared
`double` field. One file could fill a field and fail the matching property.
`TomConfig` on the server widens identically; the two are read by the same
operator writing the same file.

Three things it deliberately does not do:

- **It does not narrow.** `2.5` under a `TomIntProperty` is still a mismatch:
  narrowing needs a rounding policy, and truncating loses what the operator
  wrote.
- **It does not parse.** `'2'` under a `TomDoubleProperty` is still a mismatch.
  Reading text as a number is a different decision, and this module does not
  make it.
- **It does not convert an `int` a cast already accepted.** The widening is
  reached only *after* a cast has failed, so `TomProperty<num>('app.count')`
  over a configured `2` still holds an `int`. `0.0 is num` is true, so a check
  placed before the cast would have converted it.

### How a key resolves

The key is passed to the provider unchanged, so a property inherits the
provider's **dot notation over nested maps**. `'app.db.host'` finds either a
`host` entry inside a `db` map inside an `app` map, or a flat entry literally
named `'app.db.host'`.

The two are not equal alternatives. The nested walk runs **first** and the flat
lookup is its fallback, so a config holding both spellings answers with the
nested one:

```dart
// { 'app': {'title': 'nested'}, 'app.title': 'flat' }
~TomStringProperty('app.title');   // 'nested'
```

Descent stops at the last segment, which makes an interior node a value in its
own right. No typed subclass can hold one, so fetching a subtree is a second
place the generic is the intended form:

```dart
final db = TomProperty<Map<String, dynamic>>('app.db');
```

A path that reaches a real subtree but finds nothing in it is an ordinary miss
— rule 2 or 3 above, not an error of its own.

Because resolution is eager, construct the property **after** the config
providers are populated, and re-read is not supported — a later config change is
not reflected. That is a decision rather than a stage of development; see
[A Property Is a Snapshot](#a-property-is-a-snapshot) for what it obliges and
what it rules out.

## A Property Is a Snapshot

A `TomProperty` holds the value configuration had **at the moment the property
was built**. It is not a view of config, and it never becomes one. So:

> **Populate the config providers before any property is constructed, and treat
> a property as fixed for the life of the object.**

This is a decision, and it is the kernel's as much as this module's. Replacing
the application `TomConfigResourceProvider` announces nothing — deliberately,
because configuration is installed at bootstrap and *captured* by its consumers
when they are built, so a revision counter would notify values that have already
been taken. See
[`setAppConfigProvider`](../../tom_core_kernel/doc/resources/resources.md).

### One half of the rule is enforced, the other is not

| Situation | What happens |
| --------- | ------------ |
| A property is built with **no** config provider installed | The construction throws `resources.config_provider.not_installed`, from the kernel provider. Loud, and at the declaration. |
| A property is built, then the provider is **replaced** | The property keeps the value it resolved. Nothing reports this, and nothing can. |
| A property is built **after** the replacement | It reads the new provider, like any other first read. |

The first row is why "construct after the providers are populated" is not advice
a caller can quietly skip: with nothing installed there is no value to resolve
and the property says so where it is declared. The second row is the one to hold
in mind — it is silent by construction, and the module's own suite is what keeps
it from changing by accident.

A default follows the same rule. `TomIntProperty.withDefault('app.retries', 5)`
resolved against a config that does not carry the key holds `5`, and goes on
holding `5` when a later provider does carry it. The default was the resolution,
not a placeholder awaiting one.

### What to do instead of re-reading

- **Configuration that changes at a session boundary** — a per-user bundle
  installed after sign-in — is replaced, and whatever depends on it is rebuilt.
  That is the pattern the framework's own consumers use: the swap happens inside
  the rebuild, so the properties constructed afterwards are the new ones.
- **A value that genuinely has to be live** is not a property. Read it from the
  provider at the point of use — `TomConfigResourceProvider.getAppConfig()
  .getObjectOrNull(key)` is the single call a property makes — and pay the
  lookup each time, which is exactly the cost a property exists to avoid paying.
- **A setting a user changes** is not configuration at all. That is the
  [client-configuration module](configuration.md), which layers a user or device
  preference over an install's value and is built for the change.

Nothing here is a reactive property, and adding one would need a change the
kernel has declined for a reason: with no consumer that reconfigures under a
running screen, a counter would cost what a counter costs and mean nothing.

## Structured Values

The four typed subclasses are scalar: `String`, `int`, `double`, `bool`. A
configured list or map is not out of reach — it is held by the **generic**, with
the `dynamic` element type:

```dart
final hosts = TomProperty<List<dynamic>>('app.allowedHosts');
final db = TomProperty<Map<String, dynamic>>('app.db');
```

There is deliberately no `TomListProperty<E>` or `TomMapProperty<K, V>`. Two
properties of a configured collection decide that, and both are worth knowing
before holding one.

### The element type has to be `dynamic`

Every configuration format reaches the provider through a decoder, and no
decoder produces a narrower element type: `jsonDecode` and every YAML parser
yield `List<dynamic>` for `hosts: [alpha, beta]`. `List<dynamic>` is not a
subtype of `List<String>`, so `TomProperty<List<String>>` fails the cast — with
a message quoting `[alpha, beta]`, which is exactly what the operator wrote and
looks entirely valid. Only the chained `TypeError` on `rootException` names the
element type.

What makes that worth a section rather than a footnote is that it fails
**selectively**. A config map written by hand — which is what a test fixture is
— really does yield `List<String>`, and the narrow construction passes against
it. So `TomProperty<List<String>>` is a property that works in every test and
throws at start-up once the same values are loaded from a file.

Hold the decoder's type and narrow at the call site:

```dart
final hosts = TomProperty<List<dynamic>>('app.allowedHosts').get();
final typed = hosts.cast<String>();          // a view
final owned = List<String>.from(hosts);      // a copy — see below
```

### A structured value is held by reference

A scalar is copied by value, so every other property in this module is a
snapshot in the strong sense. A collection is not: the property caches the
**provider's own object**. A caller that mutates what it read has edited the
application's configuration, for every later reader of that key.

```dart
final hosts = TomProperty<List<dynamic>>('app.allowedHosts').get();
hosts.add('gamma');   // the provider now answers with three hosts
```

Copy it if it is going to be modified — `List.from`, `Map.of` — which is the
same `from` call the element type already wanted, so one construction settles
both questions.

### Why no collection property, yet

A `TomListProperty<E>` would have to settle three things this module has no case
to settle them against: whether it casts element-wise (and what it says when one
element is wrong) or hands back `List<dynamic>` anyway; whether it caches an
unmodifiable copy, which would break the symmetry with every other property that
caches what it resolved; and, for a map, how a map property over `app.db` and a
`TomStringProperty('app.db.host')` over the same subtree relate, which the
dot-notation resolver makes two readings of one value.

No consumer in the framework needs one, so answering those three questions now
would mean guessing with nothing to check the guesses against — and they are
precisely the answers that would be expensive to unpick. The shape if a consumer
appears is `TomListProperty<E>` alone: element-wise cast at construction, an
unmodifiable cached copy, and no map property until the dot-notation rule is
settled.

## Core Components

### `TomProperty<T>`

The generic base. Reads `key` from config at construction and caches the typed
result. Read it back with `get()` or the `~` operator. The config-provider
lookups it uses are private implementation detail, not part of the public
surface.

Prefer a typed subclass over the generic for the four non-nullable value types
below. **When `T` is nullable the generic is the intended form** — the
subclasses close over non-nullable `String`, `int`, `double` and `bool`, so
none of them can hold an optional value:

```dart
final region = TomProperty<String?>.withDefault('app.region', null);
if (~region == null) useDefaultRegion();
```

### Typed subclasses

`TomStringProperty`, `TomIntProperty`, `TomDoubleProperty`, and
`TomBoolProperty` fix `T` and offer the same two constructors — the plain
`(key)` form (throws if absent) and `.withDefault(key, value)`.

### `TomPropertyException`

A `TomClientException` — and so a kernel `TomException` — raised by both
failure paths. Catch it around the *declaration*, not the read: resolution
happens in the constructor, so a property that constructs successfully never
raises afterwards.

| `key` | Raised when |
| ----- | ----------- |
| `resources.property.not_configured` | The key is absent and no default was supplied. |
| `resources.property.type_mismatch` | The key holds a value that cannot be cast to `T`. |

`parameters` carries the key, plus `expectedType` and `value` on the mismatch
path; `rootException` carries the `TypeError`, which is the only record of the
value's actual runtime type — the message names only the type that was wanted.

## Limitations

- **Absent key without default throws `TomPropertyException`** naming the
  obligatory key (`Obligatory resource <key> not found in configuration
  resources`). Default *presence* is tracked separately from the default value,
  so a `.withDefault(key, null)` over a nullable `T` honours the explicit `null`
  rather than treating it as "no default".
- **Eager and immutable** — the value is captured at construction and never
  re-read, so a later config change is not reflected and the property must be
  built after the config providers are populated. Stated in full, with what is
  and is not enforced, under
  [A Property Is a Snapshot](#a-property-is-a-snapshot).
- **The only conversion is `int` to `double`.** A property casts; it does not
  coerce. A `'2'` configured for a numeric property, a `'true'` for a
  `TomBoolProperty`, a `2.5` for a `TomIntProperty` — all are mismatches. Where
  a loosely-typed external value has to be read, the configuration module's
  `coerceSettingValue` is the function that does it, and it is a separate
  decision on purpose.
- **A key configured with no value counts as absent.** The lookup reports a key
  that was never written and one written as `null` identically, and a property
  reads both as "not there": `app.region:` in a config file fails an obligatory
  property and loses to a default. A configured `null` can therefore never
  override a non-null default. A caller who must tell "explicitly unset" from
  "never configured" has to ask the provider's own map — `resources` is public,
  so `containsKey` settles a flat key and `getObjectFromTree` a dotted one —
  because a property offers no way to express the difference.

---

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `tom_core_kernel` | package | every file | `TomConfigResourceProvider`, the provider every property reads from — resolution is a single `getObjectOrNull` call on the provider returned by its `getAppConfig()`, which an application populates with `setAppConfigProvider` |
| [little_things](little_things.md) | module | every file | `TomClientException` |
