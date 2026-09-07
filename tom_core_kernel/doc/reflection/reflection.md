# Tom Reflection System

The Tom Reflection System provides reflection over annotated Dart classes,
enabling JSON serialization/deserialization without hand-written serialization
code for each model class. It is built on the `tom_reflection` package, whose
mirrors are emitted by a build step rather than discovered at runtime through
`dart:mirrors` — which is what lets the module work in AOT builds and on
Flutter web, where `dart:mirrors` is unavailable.

## Table of Contents

- [Overview](#overview)
  - [Why Use Reflection?](#why-use-reflection)
- [Quick Start](#quick-start)
  - [1. Annotate Your Class](#1-annotate-your-class)
  - [2. Initialize Reflection](#2-initialize-reflection)
  - [3. Use Reflection](#3-use-reflection)
- [Core Components](#core-components)
  - [TomReflector](#tomreflector)
  - [TomReflectionInfo](#tomreflectioninfo)
  - [Global Instances](#global-instances)
- [Annotations](#annotations)
  - [The @tomReflector annotation](#the-tomreflector-annotation)
- [Instance Creation](#instance-creation)
  - [Create Empty Instance](#create-empty-instance)
  - [Create from JSON](#create-from-json)
- [Deserialization (JSON to Object)](#deserialization-json-to-object)
  - [Basic Usage](#basic-usage)
  - [From JSON String](#from-json-string)
  - [Unknown Keys](#unknown-keys)
  - [TomClass Integration](#tomclass-integration)
  - [Custom Deserialization](#custom-deserialization)
- [Serialization (Object to JSON)](#serialization-object-to-json)
  - [Get Values as Map](#get-values-as-map)
  - [Get Values as JSON String](#get-values-as-json-string)
  - [Custom Serialization](#custom-serialization)
- [Serialization Hooks](#serialization-hooks)
  - [Outbound precedence — `getValues`](#outbound-precedence--getvalues)
  - [Inbound precedence — `setValues` and `createInstanceFromJson`](#inbound-precedence--setvalues-and-createinstancefromjson)
  - [`TomJsonSerializable`](#tomjsonserializable)
- [Supported Types](#supported-types)
  - [Primitive Types](#primitive-types)
  - [DateTime Types](#datetime-types)
  - [Collection Types](#collection-types)
  - [Dynamic Collections Carry Values, Not Types](#dynamic-collections-carry-values-not-types)
- [Working with Collections](#working-with-collections)
  - [Lists of Objects](#lists-of-objects)
  - [Maps of Objects](#maps-of-objects)
- [Working with Nested Objects](#working-with-nested-objects)
  - [Basic Nesting](#basic-nesting)
  - [Deep Nesting](#deep-nesting)
- [Debug Logging](#debug-logging)
  - [Debug Report](#debug-report)
- [Error Handling](#error-handling)
  - [Common Error Keys](#common-error-keys)
  - [Hooks That Fail](#hooks-that-fail)
  - [The Target Must Be Annotated](#the-target-must-be-annotated)
  - [Except The Containers, At The String Level](#except-the-containers-at-the-string-level)
  - [Atomic Collection Updates](#atomic-collection-updates)
  - [Ambiguous Type Names](#ambiguous-type-names)
  - [When the Value's Shape Does Not Fit the Field](#when-the-values-shape-does-not-fit-the-field)
- [Best Practices](#best-practices)
  - [1. Initialize All Fields](#1-initialize-all-fields)
  - [2. Use Non-Final Fields](#2-use-non-final-fields)
  - [3. Annotate All Related Classes](#3-annotate-all-related-classes)
  - [4. Handle Nullable Fields Carefully](#4-handle-nullable-fields-carefully)
- [Build Configuration](#build-configuration)
  - [build.yaml](#buildyaml)
  - [Running the Builder](#running-the-builder)
  - [Generated Files](#generated-files)
- [Type Resolution](#type-resolution)
  - [Get List Element Type](#get-list-element-type)
  - [Get Map Value Type](#get-map-value-type)
  - [Each Method Takes One Arity](#each-method-takes-one-arity)
- [Dependencies](#dependencies)
  - [The observable edge is a cycle](#the-observable-edge-is-a-cycle)

## Overview

The reflection system consists of three main components:

1. **`TomReflector`**: A configured `Reflection` subclass that provides the capabilities
   needed for reflection.

2. **`TomReflectionInfo`**: The main class providing reflection operations like
   instance creation, value setting, and value getting.

3. **`tomReflector` / `tomReflectionInfo`**: Global instances for convenient access.

### Why Use Reflection?

- **No per-model serialization code**: unlike `json_serializable`, there is no
  `toJson`/`fromJson` to write, no `part` directive to add to each model, and
  nothing to keep in step when a field is added or renamed. A `build_runner`
  step *is* required (see [Build Configuration](#build-configuration)), but it
  produces one `.reflection.dart` per **entry point** you list, covering every
  annotated class reachable from it, rather than one artifact per model. In this
  package a single generated file covers all fifteen sample sources that declare
  annotated classes.
- **Dynamic JSON handling**: Parse JSON into objects without knowing the structure at compile time.
- **Observable integration**: Seamlessly works with `TomClass` observable objects.

## Quick Start

### 1. Annotate Your Class

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

@tomReflector
class Person {
  String name = '';
  int age = 0;
  String? email;
}
```

### 2. Initialize Reflection

In your main entry point, call the generated initialization function:

```dart
import 'my_file.reflection.dart';

void main() {
  initializeReflection();
  
  // Now you can use reflection
}
```

### 3. Use Reflection

```dart
// Create an instance
final person = tomReflectionInfo.createInstance<Person>();

// Set values from JSON
tomReflectionInfo.setValues(person, {
  'name': 'John Doe',
  'age': 30,
  'email': 'john@example.com',
});

// Get values as JSON
final json = tomReflectionInfo.getValues(person);
print(json); // {name: John Doe, age: 30, email: john@example.com}

// Convert to JSON string
final jsonString = tomReflectionInfo.convertToJsonString(person);
print(jsonString); // {"name":"John Doe","age":30,"email":"john@example.com"}
```

## Core Components

### TomReflector

The `TomReflector` class extends `Reflection` and is configured with the necessary
capabilities for reflection operations:

```dart
class TomReflector extends Reflection {
  const TomReflector()
    : super.fromList(const [
        invokingCapability,          // Call methods and constructors
        typingCapability,            // Access type information
        typeRelationsCapability,     // Navigate class hierarchies
        reflectedTypeCapability,     // Get actual Dart Type objects
        typeAnnotationDeepQuantifyCapability,
        typeAnnotationQuantifyCapability,
        metadataCapability,          // Access annotations
        superclassQuantifyCapability, // Access superclass information
      ]);
}
```

### TomReflectionInfo

The main class for reflection operations. Key methods:

| Method | Description |
|--------|-------------|
| `createInstance<T>()` | Create a new instance using default constructor |
| `createInstanceFromJson<T>(mirror, data)` | Create instance and populate from JSON; returns a `T` or throws |
| `setValues<T>(object, values)` | Set field values on an existing object |
| `getValues(object)` | Get all field values as a map |
| `convertToJsonString(object)` | Serialize object to JSON string; a `List` or `Map` is encoded as itself, with complex elements rendered by `getValues` |
| `convertFromJsonString<T>(object, json)` | Deserialize JSON string to object |

### Global Instances

Two global instances are provided for convenience:

```dart
/// The reflector annotation - use this to annotate classes
const TomReflector tomReflector = TomReflector();

/// The reflection operations instance
final TomReflectionInfo tomReflectionInfo = TomReflectionInfo();
```

`TomReflectionInfo` takes no reflector — it always uses `tomReflector`. There
is no second reflector to pass: the generator emits mirror data only for a
*direct* subclass of `Reflection`, and `TomReflector` is that subclass.

It does take one option, `strictUnknownFields`, which is the whole of its
instance state and the only reason to build your own converter rather than use
the shared one — see [Unknown Keys](#unknown-keys).

## Annotations

### The @tomReflector annotation

Use this annotation on any class that needs reflection support:

```dart
@tomReflector
class MyModel {
  String field1 = '';
  int field2 = 0;
}
```

**Important**: Only classes annotated with `@tomReflector` will be available
for reflection at runtime.

## Instance Creation

### Create Empty Instance

```dart
// The type is known where you write the call
final Person person = tomReflectionInfo.createInstance<Person>();

// The type is only known at runtime
final Type someType = Person;
final Object instance = tomReflectionInfo.createInstance(someType);
```

`createInstance` names the type twice over, and the two are not the same
question. The **positional** says *what to build*; the **type argument** says
*what to call the result*, and is applied as a cast to whatever the positional
produced. Each defaults to the other, so most calls pass only one.

Passing only the positional means there is nothing for `T` to be inferred from,
so it falls back to its bound and you get an `Object` — the instance is of the
requested class, but the static type is not. Give both when the runtime `Type`
is the thing you have and a supertype is the thing you want back:

```dart
// Builds `someType`, hands it back typed as its supertype
final Person person = tomReflectionInfo.createInstance<Person>(someType);
```

Because the two are independent until the cast, a positional that is not a `T`
is not caught by the compiler. It fails when the cast does, reported as
`reflector.instance_creation.failed`.

### Create from JSON

```dart
// Get the class mirror first
final mirror = tomReflector.reflectType(Person) as ClassMirror;

// Create from Map
final person = tomReflectionInfo.createInstanceFromJson<Person>(
  mirror,
  {'name': 'John', 'age': 30},
);

// Create from JSON string
final person = tomReflectionInfo.createInstanceFromJsonString<Person>(
  mirror,
  '{"name": "John", "age": 30}',
);
```

Both factories return a non-nullable `T`. There is no failure value: a class
the reflector cannot construct (`reflector.instance_creation.failed`), a
`fromJson` that raises (`reflection.hook.failed`) or returns the wrong type
(`reflection.hook.invalid_return`), and a payload the target rejects all throw
`TomReflectorException`. The string overload parses before it reflects, so
malformed JSON raises a `FormatException` from `jsonDecode` — the one failure
that is not a `TomReflectorException`. Do not write `!`, `?? throw`, or an
`if (result == null)` branch around a call: the branch cannot be entered and so
hides nothing.

## Deserialization (JSON to Object)

### Basic Usage

```dart
final person = Person();
tomReflectionInfo.setValues(person, {
  'name': 'Alice',
  'age': 25,
});
```

### From JSON String

```dart
final person = Person();
tomReflectionInfo.convertFromJsonString(person, '{"name": "Alice", "age": 25}');
```

### Unknown Keys

A key that names no field on the target is **ignored by default**. The rest of
the map is applied and the object is returned as if nothing were wrong:

```dart
final person = Person();
tomReflectionInfo.setValues(person, {'name': 'Alice', 'headcount': 3});
// name == 'Alice'; 'headcount' is dropped without a word
```

That is deliberate, and it is a property of the wire rather than of this
module: a newer client talking to an older server, or a stored document holding
fields that have since been removed, sends keys the target no longer declares.
Rejecting the whole payload for them would make the format
non-forward-compatible.

Where the payload is under your own control the same tolerance works against
you, because it hides the commonest deserialization bug there is — a renamed
field, or a typo, silently dropped. Construct a strict converter for those call
sites:

```dart
final strict = TomReflectionInfo(strictUnknownFields: true);
strict.setValues(person, {'name': 'Alice', 'headcount': 3});
// throws TomReflectorException: reflection.set.unknown_field
//   "Person declares no field 'headcount' …"
```

`strictUnknownFields` is the whole of the converter's instance state, and it is
carried by the converter rather than passed per call so that nesting inherits
it: the walk recurses through `createInstanceFromJson` on the same instance, so
a strict converter is strict all the way down a nested payload. The shared
`tomReflectionInfo` is never strict — build your own where you want the checks,
typically in tests and wherever both ends of the payload are yours.

Two neighbouring cases are **not** governed by the flag:

- A key naming a member that exists but cannot be written — a `static`, `final`
  or private declaration — is an error in both modes
  (`reflection.set.unexpected_condition_final_static_private`). You addressed a
  field this class has and asked for a value it will never hold.
- A key naming a setter that has no matching getter is ignored in both modes.
  The member does exist, so it is not an unknown field; the walk simply has no
  declared return type to resolve a non-primitive value against. A primitive
  value reaches such a setter normally.

### TomClass Integration

If your class extends `TomClass`, `setValues` automatically delegates to
`TomClass.setValues()` for proper observable handling:

```dart
@tomReflector
class Person extends TomClass {
  TomString name = TomString('');
  TomInt age = TomInt(0);
}

final person = Person();
tomReflectionInfo.setValues(person, {'name': 'Alice', 'age': 25});
// Observable fields are updated via their setByString methods
```

### Custom Deserialization

Two optional hooks let a class take deserialization over from the field walk.
Declare either and it is used automatically; declare neither and nothing
changes.

`jsonDecode` — a method — replaces the field walk in `setValues`:

```dart
@tomReflector
class CustomPerson {
  String name = '';
  int age = 0;

  void jsonDecode(Map<String, dynamic> json) {
    name = json['fullName'] as String;   // Custom key name
    age = json['years'] as int;          // Custom key name
  }
}
```

`fromJson` — a named constructor — replaces the default constructor in
`createInstanceFromJson`, and is tried before it:

```dart
@tomReflector
class CustomPerson {
  String name = '';

  CustomPerson();

  factory CustomPerson.fromJson(Map<String, dynamic> json) =>
      CustomPerson()..name = json['fullName'] as String;
}
```

These are the two inbound hooks, and **both entry points honour both**:
`setValues` and `createInstanceFromJson` apply the same order, so which one a
caller reaches for does not change which hook runs. `fromJson` is tried first —
a constructor owns the object from nothing, where the method only overwrites
what is already there. One consequence is worth stating plainly: because a
constructor *builds*, `setValues` on a `fromJson` class returns a **new**
instance and leaves the argument untouched, so write
`o = converter.setValues(o, map)` rather than calling it and reading `o`. For
the outbound pair and the full precedence order, see [Serialization
Hooks](#serialization-hooks); for what happens when a hook exists and fails,
[Hooks That Fail](#hooks-that-fail).

## Serialization (Object to JSON)

### Get Values as Map

```dart
final person = Person()
  ..name = 'John'
  ..age = 30;

final values = tomReflectionInfo.getValues(person);
// {name: 'John', age: 30}
```

### Get Values as JSON String

```dart
final jsonString = tomReflectionInfo.convertToJsonString(person);
// '{"name":"John","age":30}'
```

### Custom Serialization

If your class has a `toJson()` method or a `jsonEncode` getter, it will be used
instead of reflection:

```dart
@tomReflector
class CustomPerson {
  String name = '';
  int age = 0;
  
  Map<String, Object?> get jsonEncode => {
    'fullName': name,  // Custom key name
    'years': age,      // Custom key name
  };
}
```

Either must return a `Map<String, Object?>` (or a subtype — a
`Map<String, dynamic>` or `Map<String, String>` is fine). Anything else is
reported rather than ignored; see [Hooks That Fail](#hooks-that-fail).

A class declaring both is served by `toJson()`, for the reason given in
[Serialization Hooks](#serialization-hooks).

## Serialization Hooks

Four member names let a class take conversion over from the field walk. They
are described one at a time above; this section is the single place that states
what each one is and in what order they are tried.

| Hook | Kind | Signature | Direction |
| ---- | ---- | --------- | --------- |
| `toJson` | method | `Map<String, Object?> toJson()` | out |
| `jsonEncode` | getter | `Map<String, Object?> get jsonEncode` | out |
| `fromJson` | named constructor | `Class.fromJson(Map<String, dynamic> json)` | in |
| `jsonDecode` | method | `void jsonDecode(Map<String, dynamic> json)` | in |

There are **two** entry points, one per direction — `getValues` outbound,
`setValues` inbound — and each honours every hook of its direction. Which
function you reach for therefore never decides which hooks apply, and a
consumer never needs a hook chain of its own.

The naming is asymmetric and worth reading twice. On the way out a hook is
either a **method** (`toJson`) or a **getter** (`jsonEncode`); on the way in
either a named **constructor** (`fromJson`) or a **method** (`jsonDecode`).
Nothing requires a class that declares one to declare its counterpart, so a
type can perfectly well encode through a hook and decode through the field
walk.

### Outbound precedence — `getValues`

In order, stopping at the first that applies:

1. **`o is TomClass`** — delegates to `TomClass.toJson()` and returns. This is
   ahead of everything else, so a `TomClass` subclass declaring `jsonEncode`
   never sees it used.
2. **`o is TomJsonSerializable`** — delegates to its `toJson()` and returns.
   Also before any mirror is taken: the interface exists to be cheap, and
   testing it here is what lets a self-rendering DTO serialize *without*
   carrying `@tomReflector` at all.
3. **Reflection is resolved.** No generated mirror data throws
   `reflector.reflect.not_reflectable`; mirror data without `@tomReflector`
   throws `reflector.type.not_annotated`. Then **a `toJson()` method**, if the
   class declares one, supplies the map.
4. Otherwise **a `jsonEncode` getter**, if the class declares one.
5. Otherwise the **field walk** — every non-static, non-final, non-private
   field. If the walk contributes *nothing* and it skipped at least one `final`
   member, it raises `reflector.type.all_final` rather than returning `{}` —
   see [Use Non-Final Fields](#2-use-non-final-fields).

Steps 1–3 are one hook under three spellings — two nominal, one structural —
which is why they are ranked together, ahead of `jsonEncode`:

```dart
// SelfSerializingDto implements TomJsonSerializable and has a working toJson()
// that deliberately renames the field, so the two answers cannot coincide.
final dto = SelfSerializingDto()..status = 'up';

dto.toJson();                        // {ok: up}
tomReflectionInfo.getValues(dto);    // {ok: up} — the same answer

// And the same again with the annotation stripped: an unannotated DTO is
// answered at step 2, before anything asks it to be reflectable.
```

Were `jsonEncode` ranked between them, adding `implements TomJsonSerializable`
to a class carrying both hooks would silently change its wire format — a
declaration of intent turning into a behavioural change. `test/reflection_test.dart`
pins that with a pair of fixtures differing only by the declaration and asserts
they answer identically.

### Inbound precedence — `setValues` and `createInstanceFromJson`

`setValues(o, values)` — the inbound entry point:

1. **`o is TomClass`** — delegates to `TomClass.setValues()` and returns.
2. **Reflection is resolved**, exactly as outbound. Then **a `fromJson` named
   constructor**, if the class declares one, is invoked and **its** instance
   returned.
3. Otherwise **a `jsonDecode` method**, if the class declares one, takes
   deserialization over entirely and `o` is returned.
4. Otherwise the **field walk**, entry by entry.

`fromJson` outranks `jsonDecode` because a constructor is the more complete
statement: it owns the object from nothing, where the method only overwrites
what is already there.

`createInstanceFromJson(mirror, json)` — builds a new object — applies the same
order from a mirror rather than an instance: `fromJson` if the class declares
one, otherwise the default constructor followed by `setValues`, which reaches
steps 3 and 4 above. **The two functions therefore agree on all four hooks**,
and a class declaring only `fromJson`, or only `jsonDecode`, is honoured by
both.

**A `fromJson` class does not preserve identity.** Step 2 *builds*, so
`setValues(o, map)` on such a class hands back a new instance and leaves `o`
exactly as it was. `o = converter.setValues(o, map)` is correct for every
shape; calling `setValues` and then reading `o` is correct for every shape but
this one.

### `TomJsonSerializable`

`TomJsonSerializable` is an interface declaring a single `toJson()`. Its value
is not that it enables custom JSON — a bare `toJson()` method does that too,
and produces the same map — but that it makes "this type serializes itself"
**cheap to detect**: an `is` check, with no mirror round-trip and no calling a
speculative member to see whether it exists. Where a custom path has to be
detected, that is the mechanism to prefer. Two things follow from the interface
being ranked *with* the structural `toJson()` rather than above or below it:
adding or removing the declaration never changes the resulting JSON, and an
implementer needs no `@tomReflector` to be serialized.

It is an escape hatch, not the default. Reflection is how a wire type is meant
to cross the boundary; a type should need nothing beyond `@tomReflector` and
plain mutable fields. Reach for `TomJsonSerializable` when a type must match a
wire shape it does not own, and keep the implementation a shape adapter with no
business or security logic in it. If the only reason is a member name that does
not match the wire name, rename the member instead.

All four share one failure contract: each is looked up before it is called, so
a hook that exists and fails is reported rather than mistaken for an absent
one. See [Hooks That Fail](#hooks-that-fail). The two *nominal* forms need none
of this — an `is` test cannot mistake absence for failure — so
`TomClass.toJson()` and `TomJsonSerializable.toJson()` are called directly and a
failure inside either propagates as whatever it threw.

## Supported Types

### Primitive Types

The following types are handled directly:

- `int` / `int?`
- `double` / `double?`
- `bool` / `bool?`
- `String` / `String?`
- `null`

An `int` destined for a `double` field is **widened** — neither JSON nor a
command-line `key=value` argument can express "the double 2", so `{"rate": 2}`
sets a `double rate` to `2.0`. The converse is deliberately absent: a `double`
for an `int` field is an error, because narrowing would need a rounding policy
and truncating `2.5` loses data.

The same widening applies inside collections, for the same reason:
`{"rates": [1, 2.5]}` sets a `List<double>` to `[1.0, 2.5]`.

### DateTime Types

The following DateTime types are automatically serialized/deserialized:

- `DateTime` - ISO 8601 string format
- `TomZonedDate` - Custom date with timezone
- `TomZonedTime` - Custom time with timezone
- `TomZonedDateTime` - Custom datetime with timezone

A string that will not parse into the field's date/time type raises
`reflection.set.date_parse_failed`, naming the class, the field and the
offending text — and, when the field is a `Map<String, DateTime>` or a
`List<DateTime>`, the map key or the list index of the element that failed:

```dart
tomReflectionInfo.setValues(order, {'placedAt': 'yesterday'});
// TomReflectorException: reflection.set.date_parse_failed
// Cannot set field 'placedAt' on Order: "yesterday" is not a valid DateTime

tomReflectionInfo.setValues(order, {
  'milestones': ['2026-01-02T00:00:00.000Z', 'soon'],
});
// Cannot set field 'milestones' on Order at index 1: "soon" is not a
// valid DateTime
```

The underlying `FormatException` is kept as the `rootException`. This matters
because the parsers — `DateTime.parse` and the `TomZoned*` ones — report only
the text they choked on; on a thirty-field payload that says *something* was
not a date and stops there. Wrapping also brings the failure back under the
module's auto-logging, so it carries an exception id like every other one, and
under `on TomReflectorException`, so a caller written against the error table
above catches it rather than having it fly past.

The field keeps its previous value, and a collection keeps its previous
contents: elements are parsed into a fresh collection that is only assigned
once every one of them has succeeded.

### Collection Types

**Lists:**
- `List<dynamic>`, `List<Object>`, `List<Object?>` — see
  [Dynamic Collections Carry Values, Not Types](#dynamic-collections-carry-values-not-types)
- `List<String>`, `List<String?>`
- `List<int>`, `List<int?>`
- `List<double>`, `List<double?>`
- `List<bool>`, `List<bool?>`
- `List<DateTime>`, `List<DateTime?>`
- `List<TomZonedDate>`, `List<TomZonedTime>`, `List<TomZonedDateTime>` and their nullable forms
- `List<MyClass>`, `List<MyClass?>` (where MyClass is annotated)

**Maps:**
- `Map<String, dynamic>`, `Map<String, Object>`, `Map<String, Object?>` — see
  [Dynamic Collections Carry Values, Not Types](#dynamic-collections-carry-values-not-types)
- `Map<String, String>`, `Map<String, String?>`
- `Map<String, int>`, `Map<String, int?>`
- `Map<String, double>`, `Map<String, double?>`
- `Map<String, bool>`, `Map<String, bool?>`
- `Map<String, DateTime>`, `Map<String, DateTime?>`
- `Map<String, TomZonedDate>`, `Map<String, TomZonedTime>`, `Map<String, TomZonedDateTime>` and their nullable forms
- `Map<String, MyClass>`, `Map<String, MyClass?>` (where MyClass is annotated)

### Dynamic Collections Carry Values, Not Types

A `Map<String, dynamic>` or `List<dynamic>` field round-trips **JSON-native
values** — `String`, `int`, `double`, `bool`, `null` — unchanged. Anything else
comes back as the JSON form the encoder produced, because a `dynamic` element
has no declared type for the decoder to dispatch on. The encode side knows what
it holds; the decode side does not.

```dart
holder.dynamicMap = {'when': DateTime.utc(2026, 1, 2), 'count': 5};

final json = tomReflectionInfo.convertToJsonString(holder);
// {"dynamicMap":{"when":"2026-01-02T00:00:00.000Z","count":5}}

tomReflectionInfo.convertFromJsonString(restored, json);
restored.dynamicMap!['when'];   // String  — not DateTime
restored.dynamicMap!['count'];  // 5       — unaffected
```

What each kind of value becomes:

| Value placed in a dynamic collection | What comes back |
|--------------------------------------|-----------------|
| `String`, `int`, `double`, `bool`, `null` | Itself, unchanged |
| `DateTime` | `String` — ISO-8601 text |
| `TomZonedDate` / `TomZonedTime` / `TomZonedDateTime` | `String` — the `@D@` / `@T@` / `@X@` marker text |
| A class annotated with `@tomReflector` | `Map<String, dynamic>` of its fields — **not** an instance |
| A nested `Map` or `List` | Itself, with its own values erased by the same rule |

This is **type erasure, not data loss.** The text is the same encoding the
typed fields use, so a caller who knows the intended type can restore it:

```dart
DateTime.parse(restored.dynamicMap!['when'] as String);
TomZonedDateTime.parseFromString(restored.dynamicMap!['z'] as String);
```

The failure is silent — no exception, no trace, and the object looks fully
populated. Code that reads `map['when'] as DateTime` throws at the cast, far
from the deserialization that caused it.

**Declare the element type when you know it.** The same value in a
`Map<String, DateTime>` field is restored as a `DateTime`, because the field
tells the decoder what to parse:

```dart
Map<String, DateTime>? dateTimeMap;   // round-trips as DateTime
Map<String, dynamic>? attributes;     // round-trips as String
```

Reserve `dynamic` for genuinely free-form data whose values are JSON-native —
attribute bags, passthrough payloads.

If such a field must carry typed values, the class itself is the only place
left that knows what they are, and
[`jsonDecode`](#inbound-precedence--setvalues-and-createinstancefromjson) is
where that knowledge goes:

```dart
@tomReflector
class Session {
  String label = '';
  Map<String, dynamic>? attributes;

  Session();

  void jsonDecode(Map<String, dynamic> json) {
    label = json['label'] as String? ?? '';
    final source = json['attributes'] as Map?;
    attributes = source?.map((key, value) => MapEntry(
          key as String,
          value is String ? (DateTime.tryParse(value) ?? value) : value,
        ));
  }
}
```

Note the cost: `jsonDecode` takes deserialization over **entirely**, so the
hook must populate every field, not only the one it cares about — `label` is
restored by hand above for that reason. `fromJson` would work here too and pays
the same cost, with one difference: it *builds* rather than fills, so a caller
must keep what `setValues` returns rather than reading the object it passed in.

**Collections nest one level deep.** The element type of a `List<T>` or a
`Map<String, T>` must be a primitive, one of the date/time types, or a class
annotated with `@tomReflector` — not another collection. `List<List<String>>`,
`Map<String, List<Address>>` and `Map<String, Map<String, int>>` are all
outside the supported set.

They are refused rather than silently mishandled. Both the deserializer and the
element-type resolution methods raise
`reflector.type_resolution.nested_generic_unsupported`, naming the declaration
and the argument that is generic:

```text
TomReflectionInfo.setValues: field 'nestedLists': 'List<List<String>>' has the
generic element type 'List<String>'; nested generic collections are not
supported — an element type must be a primitive, a date/time type, or a class
annotated with @tomReflector
```

The field keeps whatever it held before, as with any other rejected collection.

To carry a nested structure, give the inner collection a class of its own:

```dart
@tomReflector
class Tags {
  List<String> values = [];
}

@tomReflector
class Article {
  List<Tags> tagGroups = [];  // instead of List<List<String>>
}
```

## Working with Collections

### Lists of Objects

```dart
@tomReflector
class Order {
  String orderId = '';
  List<OrderItem> items = [];
}

@tomReflector
class OrderItem {
  String productId = '';
  int quantity = 0;
}

// Deserialize
final order = Order();
tomReflectionInfo.setValues(order, {
  'orderId': 'ORD-001',
  'items': [
    {'productId': 'PROD-1', 'quantity': 2},
    {'productId': 'PROD-2', 'quantity': 1},
  ],
});
```

**Important**: List fields can be nullable but the reflection system populates the existing list (or map) rather than creating a new one, if one exists.

### Maps of Objects

```dart
@tomReflector
class Catalog {
  Map<String, Product> products = {}; 
}

@tomReflector
class Product {
  String name = '';
  double price = 0.0;
}

// Deserialize
final catalog = Catalog();
tomReflectionInfo.setValues(catalog, {
  'products': {
    'SKU001': {'name': 'Widget', 'price': 9.99},
    'SKU002': {'name': 'Gadget', 'price': 19.99},
  },
});
```

**Important**: Only Maps with String keys are supported.

## Working with Nested Objects

### Basic Nesting

```dart
@tomReflector
class Customer {
  String name = '';
  Address address = Address();  // Initialize nested object!
}

@tomReflector
class Address {
  String street = '';
  String city = '';
  String zipCode = '';
}

// Deserialize - nested object is populated, not replaced
final customer = Customer();
tomReflectionInfo.setValues(customer, {
  'name': 'John Doe',
  'address': {
    'street': '123 Main St',
    'city': 'New York',
    'zipCode': '10001',
  },
});
```

### Deep Nesting

The system handles arbitrarily deep nesting:

```dart
@tomReflector
class Company {
  String name = '';
  List<Department> departments = [];
}

@tomReflector
class Department {
  String name = '';
  List<Employee> employees = [];
}

@tomReflector
class Employee {
  String name = '';
  Address address = Address();
}
```

## Debug Logging

Three debug switches are available for troubleshooting:

```dart
// Log type resolution information
TomReflectionInfo.debugSwitchLogReflectionDetailsTypes = true;

// Log class member information
TomReflectionInfo.debugSwitchLogReflectionDetailsMembers = true;

// Log value setting/getting operations
TomReflectionInfo.debugSwitchLogReflectionDetailsValues = true;
```

### Debug Report

For detailed class structure information:

```dart
final person = Person();
tomReflectionInfo.reportReflectObject(person);
```

This prints:
- All declarations (fields, methods, constructors)
- Instance members with types
- Superclass hierarchy

## Error Handling

The system throws `TomReflectorException` for reflection errors:

```dart
// No @tomReflector, so the builder generated no mirror data for it
class NotAnnotated {}

try {
  tomReflectionInfo.createInstance<NotAnnotated>();
} on TomReflectorException catch (e) {
  print('Error key: ${e.key}'); // reflector.instance_creation.failed
  print('Message: ${e.defaultUserMessage}'); // names NotAnnotated
}
```

`createInstance` wraps everything that goes wrong inside it, so the class being
unreflectable arrives under the same key as a class that reflects but has no
usable default constructor. The type name in the message is what tells the two
apart.

### Common Error Keys

| Error Key | Description |
|-----------|-------------|
| `reflector.reflect.not_reflectable` | The class has no generated reflection data at all — it was never annotated and never reached by quantification |
| `reflector.type.not_annotated` | The class reflects, but carries no `@tomReflector` — a built-in such as `String`, `int`, `DateTime` or `List` that only has data because it appears as a field type |
| `reflector.type.all_final` | `getValues` reached the field walk, the walk contributed no field, and every member it skipped was `final` — names the type and the skipped members. Declare a rendering hook or make the members non-final; see [Use Non-Final Fields](#2-use-non-final-fields) |
| `reflector.instance_creation.failed` | Failed to create instance |
| `reflector.type_resolution.not_a_generic_type` | The collection's runtime type carries no type arguments |
| `reflector.type_resolution.not_a_map_type` | `mapValueElementType` was given a collection with an argument count other than two — see [Each Method Takes One Arity](#each-method-takes-one-arity) |
| `reflector.type_resolution.not_a_single_element_type` | `singleElementType` was given a collection with an argument count other than one, typically a `Map<K, V>` |
| `reflector.type_resolution.nested_generic_unsupported` | The element type is itself a generic collection (`List<List<X>>`, `Map<String, List<X>>`) |
| `reflector.classmirror.not_found_for_map_value` | Map value type not found |
| `reflector.classmirror.not_found_for_iterable_value` | List element type not found |
| `reflector.classmirror.ambiguous_simple_name` | The simple name matches more than one annotated class |
| `reflection.set.unexpected_condition_final_static_private` | Field has a getter but no setter (static, final or private) — names the class and the field |
| `reflection.set.unknown_field` | The key names no field on the target class, and the converter was built with `strictUnknownFields: true`. The default converter ignores such keys silently — see [Unknown Keys](#unknown-keys) |
| `reflection.set.unexpected_type` | Unexpected value type during deserialization |
| `reflection.set.unexpected_string_type` | String value for non-DateTime field |
| `reflection.set.datetime_must_be_filled_from_string_in_map` | Non-String element in a `Map<String, DateTime>`-style field |
| `reflection.set.datetime_must_be_filled_from_string_for_list` | Non-String element in a `List<DateTime>`-style field |
| `reflection.set.date_parse_failed` | A String destined for a date/time field could not be parsed — names the class, the field, the offending text and, inside a collection, the map key or list index |
| `reflection.set.map_value_materialization_failed` | A value could not be materialized into a `Map<String, T>` field |
| `reflection.set.list_element_materialization_failed` | An element could not be materialized into a `List<T>` field |
| `reflection.set.collection_element_type_mismatch` | An element of a typed primitive collection is not of the field's element type |
| `reflection.set.map_key_type_mismatch` | A `Map<String, T>` field was given a key that is not a `String` |
| `reflection.hook.failed` | A `fromJson`, `jsonDecode`, `toJson` or `jsonEncode` hook exists and raised — names the hook and the class, and keeps the original error as `rootException` |
| `reflection.hook.invalid_return` | A hook exists, returned normally, and returned something unusable — a `toJson` or `jsonEncode` that is not a `Map<String, Object?>`, or a `fromJson` that is not an instance of the requested type |

### Hooks That Fail

The four conversion hooks — the `fromJson` constructor, the `jsonDecode` and
`toJson` methods and the `jsonEncode` getter — are all optional, so *not having
one* is the ordinary case and must stay silent. It does: a class that declares
no hook is converted by the field walk exactly as before. (The two *nominal*
forms, `TomClass` and `TomJsonSerializable`, need none of this machinery: an
`is` test cannot mistake absence for failure, so a throw from either propagates
unwrapped.)

What is no longer silent is a hook that **exists and fails**:

```dart
@tomReflector
class Broken {
  String name = '';

  Map<String, Object?> get jsonEncode => throw StateError('nope');
}

tomReflectionInfo.getValues(Broken());
// throws TomReflectorException(reflection.hook.failed):
// "Broken.jsonEncode raised while converting; the hook exists, so this is
//  not a missing hook but a failing one: Bad state: nope"
```

Previously both cases were one event. Each hook was located by *calling* it
inside an unqualified `catch`, so a hook that threw was indistinguishable from
a hook that was absent, and the field walk quietly took over. The consequences
differed by hook and were all bad:

- a bug inside a caller's own `fromJson` was swallowed, the object was rebuilt
  from the same payload by the fallback path, and the error the caller
  eventually saw — if any — named a *field* and pointed at the reflection
  layer rather than at their constructor;
- a throwing `jsonDecode`, `toJson` or `jsonEncode` did not even produce an
  error: the custom representation was simply not used, and a plausible-looking
  field-by-field result was returned in its place.

Each hook is now looked up before it is called — `instanceMembers` for the
methods and the getter, the declared constructor names for `fromJson` — so
absence is settled without running anything, and the `catch` around the call
exists only to attribute a failure. Nothing is inferred from the *type* of the
error, which matters: `tom_reflection` does not report absence
consistently. A missing constructor raises `NoSuchCapabilityError`, but a
missing method or getter surfaces as a plain `NoSuchMethodError` from a dynamic
dispatch, because the generated getters map is shared across the whole
reflector rather than held per class.

A hook that returns normally but returns something unusable is reported too,
under `reflection.hook.invalid_return`. Falling back would be the quiet answer
and the wrong one — the hook exists precisely to replace the field walk, so
producing the representation it was written to override is not a recovery.

### The Target Must Be Annotated

`getValues`, `convertToJsonString`, `setValues`, `convertFromJsonString` and
`reportReflectObject` all refuse a target whose class does not carry
`@tomReflector`:

```dart
tomReflectionInfo.getValues('hello');
// throws TomReflectorException(reflector.type.not_annotated):
// "TomReflectionInfo.getValues: String is not annotated with @tomReflector,
//  so it has no fields this converter may read or write; annotate the class
//  and regenerate, or pass an instance of one that is"
```

This is worth stating because *reflecting successfully is not the same as
being annotated*. The capability set includes deep type-annotation
quantification, so every type that appears as a field type of an annotated
class — `String`, `int`, `double`, `bool`, `DateTime`, `List`, `Map`, `Object`
— has generated data too. Those types reflect happily and then present no
settable fields, so without the check `getValues` walked zero declarations and
returned an empty map, and `convertToJsonString` returned the string `"{}"`: a
valid-looking payload with every field dropped, reported as a success.
`setValues` was the mirror image, returning the object untouched.

Two keys distinguish the two ways a target can be unusable:

- `reflector.reflect.not_reflectable` — no generated data exists. Annotate the
  class and re-run the builder.
- `reflector.type.not_annotated` — data exists, but the class is not one of
  yours. Usually this means a primitive or collection was passed where an
  annotated object was meant.

Both are `TomReflectorException`, so one `on TomReflectorException` covers
"this object cannot be serialized" regardless of which door it came through.

Note that membership of `tomReflector.annotatedClasses` is *not* the test being
applied, and must not be used as one: that list contains the quantified
built-ins as well, and it holds declaration mirrors, so the mirror of an
annotated **generic** instantiation such as `GenericHolder<int>` is absent from
it. The check reads the `@tomReflector` metadata on the resolved class mirror,
which survives instantiation and marks exactly the annotated set.

### Except The Containers, At The String Level

`convertToJsonString` takes a `List` or a `Map` and encodes it as itself,
rendering each complex element through `getValues`:

```dart
tomReflectionInfo.convertToJsonString([firstDto, secondDto]);
// [{"ok":"one"},{"ok":"two"}] — each element rendered exactly as a
// top-level object would be, by the outbound precedence above
```

`getValues` is unchanged and still refuses both: a container has no fields and
is not one of yours, so asking it for *values* has no answer. Only the string
form has one, because a container is directly encodable once its contents are.

This exists so that no consumer needs a hook chain of its own. A handler
returning `List<Task>` is ordinary, and before this the only way to put one on
the wire was for its transport to encode it — which is how the endpoint
pipeline and the HTTP client came to honour different hook sets, and how a type
could round-trip on one side and fail on the other.

The container is walked explicitly rather than handed to `jsonEncode` with a
`toEncodable` callback, because `dart:convert` catches whatever that callback
raises and rethrows `JsonUnsupportedObjectError` — the annotation guard's
message, which names the offending type and says what to do about it, would
reach the caller as "converting object to an encodable object failed". Walking
it here lets the guard's own exception through unwrapped:

```dart
tomReflectionInfo.convertToJsonString([NotOurs()]);
// throws TomReflectorException(reflector.reflect.not_reflectable)
```

Nothing in the container walk reproduces the field walk's own conversions
(dates, zoned times) — those belong to `getValues`, and a second copy of that
table is how the two would drift. A bare `DateTime` sitting directly in a map
is therefore refused rather than silently rendered.

A bare scalar stays refused as well: a `String` is not a container, so it takes
the object path and meets the annotation guard exactly as before.

### Atomic Collection Updates

Collection fields are built in full before the target field is touched. If any
element or value cannot be materialized, a `TomReflectorException` is thrown and
the field keeps its previous content — it is never left cleared, truncated, or
half-populated.

```dart
// Team declares `List<TeamMember> members = []`; TeamMember declares `String name`
final team = Team()..members.add(TeamMember()..name = 'Old');

try {
  tomReflectionInfo.setValues(team, {
    'members': [
      {'name': 'New'},
      null, // List<TeamMember> cannot hold null — the whole update fails
    ],
  });
} on TomReflectorException catch (e) {
  print(e.key); // reflection.set.list_element_materialization_failed
}

print(team.members.length); // 1 — the original content is intact
print(team.members[0].name); // 'Old'
```

This covers collections of **primitives** as well. A typed primitive collection
is built and checked element by element, never handed to the field as a lazy
`cast<T>()` view — a view accepts the wrong element without complaint and throws
a bare `TypeError` when that element is eventually *read*, in whichever layer
happens to touch it, with no mention of the field it came from. Since `length`
and the well-typed elements keep working, a shallow check after deserialization
reports success:

```dart
// ListHolder declares `List<int> intList = []`
final holder = ListHolder()..intList = [7, 8];

try {
  tomReflectionInfo.setValues(holder, {
    'intList': [1, 'x'],
  });
} on TomReflectorException catch (e) {
  print(e.key); // reflection.set.collection_element_type_mismatch
  // "TomReflectionInfo.setValues: 'intList[1]' expects int but the value is
  //  'x' of type String"
}

print(holder.intList); // [7, 8] — the original content is intact
```

The message names the field, the position (`[1]`, or `['key']` for a map) and
the offending value, at the one point that still knows all three.

### Ambiguous Type Names

Element types of annotated collections are resolved by *simple* name. If two
`@tomReflector` classes in different libraries share a simple name, the lookup
is rejected rather than silently resolved to the first match:

```dart
// Both a.dart and b.dart declare an annotated `Address`.
tomReflectionInfo.singleElementType(<Address>[]);
// throws TomReflectorException(reflector.classmirror.ambiguous_simple_name),
// naming the library of each candidate in the message.
```

The message identifies the candidates by their **library URI**, not by
qualified name: the reflector is configured without `libraryCapability`, so
every qualified name here is `.Address` and listing them would only repeat the
ambiguous name back. Resolve the collision by renaming one class or by dropping
its `@tomReflector`.

### When the Value's Shape Does Not Fit the Field

`setValues` picks how to fill a field from the **incoming value's** type, not
from the field's. A `Map` goes to the map-setting path and a `List` to the
list-setting path whatever the field was declared as — so the same category of
mistake gets two different answers depending on which way round it is:

| Payload | Field | Result |
| --- | --- | --- |
| `List` | any non-list field | **silently dropped** — the field is untouched and the call reports success |
| `Map` | scalar, or a collection of a known element type | `reflector.instance_creation.failed` |
| `Map` | `Object?`, or a class with no `@tomReflector` | `reflector.type.not_annotated` |
| `Map` | `dynamic`, or a generic instantiation such as `GenericHolder<int>` | **silently dropped** |

```dart
// MapHolder declares `Map<String, int>? intMap`
final holder = MapHolder();
tomReflectionInfo.setValues(holder, {'intMap': [1, 2, 3]});
print(holder.intMap); // null — the list was discarded without a word

// ListHolder declares `List<int>? intList`
tomReflectionInfo.setValues(ListHolder(), {'intList': {'a': 1}});
// throws TomReflectorException(reflector.instance_creation.failed)
```

The two silent cases are a known rough edge, not a design position: a field
declared `dynamic` to carry an arbitrary payload loses that payload, and a
list sent to the wrong field disappears. Both are covered by tests so that the
behaviour cannot change unnoticed, and turning either into a diagnosis is a
separate, deliberate change.

When the shape *does* fit, whether prior content survives depends on which
strategy claims the payload:

```dart
// A primitive map type is assigned wholesale — omitted keys are lost.
final holder = MapHolder()..stringMap = {'keep': 'me'};
tomReflectionInfo.setValues(holder, {'stringMap': {'add': 'new'}});
print(holder.stringMap); // {add: new}

// A field already holding an annotated object is filled in place — omitted
// fields keep their values.
final person = PersonWithAddress()
  ..address = (Address()..street = 'Old Street'..city = 'Berlin');
tomReflectionInfo.setValues(person, {'address': {'city': 'Hamburg'}});
print(person.address!.street); // Old Street
```

## Best Practices

### 1. Initialize All Fields

Always initialize fields with default values:

```dart
@tomReflector
class Person {
  String name = '';           // ✓ Good
  int age = 0;                // ✓ Good
  List<String> tags = [];     // ✓ Good - empty list
  Address address = Address(); // ✓ Good - initialized nested object
}
```

### 2. Use Non-Final Fields

Reflection can only set non-final, non-static, non-private fields:

```dart
@tomReflector
class Person {
  String name = '';           // ✓ Can be set via reflection
  final String id = '';       // ✗ Cannot be set (final)
  static String type = '';    // ✗ Cannot be set (static)
  String _internal = '';      // ✗ Cannot be set (private)
}
```

Neither direction is quiet about it. Inbound, a payload key naming such a
member raises `reflection.set.unexpected_condition_final_static_private`: you
addressed a field the class has and asked for a value it will never hold.

Outbound the skip is a *choice*, and the choice is not to emit. A `final`
member cannot be assigned after construction, so serializing one buys a payload
that renders and never restores — an asymmetry that loses data in the direction
nobody checks. What was wrong was the silence around it: a class whose members
are all `final` returned `{}` and reported success. `getValues` now raises
**`reflector.type.all_final`**, naming the type and every member it dropped:

```dart
@tomReflector
class AllFinalDto {
  final String name;
  final int age;
  AllFinalDto(this.name, this.age);
}

tomReflectionInfo.getValues(AllFinalDto('Ada', 36));
// throws TomReflectorException: reflector.type.all_final
//   "every wire member of AllFinalDto is final (name, age) …"
```

Two things the guard deliberately does *not* do:

- **It does not fire on partial loss.** The condition is *nothing contributed
  **and** something dropped*. `PartlyFinalDto` with one `final` and one settable
  field renders the settable one and omits the other, as before; a class with no
  wire members at all still renders `{}`, which is the truth about it.
- **It does not forbid immutable DTOs.** All four rendering hooks are consulted
  ahead of the field walk (see [Outbound precedence](#outbound-precedence--getvalues)),
  so an all-`final` class that declares `toJson()`, a `jsonEncode` getter,
  `TomJsonSerializable` or extends `TomClass` never reaches the guard. The
  exception asks how the type means to render itself; it does not answer for it.

### 3. Annotate All Related Classes

All classes in your object graph must be annotated:

```dart
@tomReflector  // ✓ Required
class Order {
  Customer customer = Customer();  // Customer must also be annotated!
}

@tomReflector  // ✓ Required
class Customer {
  String name = '';
}
```

### 4. Handle Nullable Fields Carefully

For nullable nested objects, check for null in your code:

```dart
@tomReflector
class Person {
  String name = '';
  Address? address;  // May be null
}

// In JSON, if address is null or missing, the field remains null
```

## Build Configuration

### build.yaml

Configure the reflection builder in your `build.yaml`:

```yaml
targets:
  $default:
    builders:
      tom_reflection_generator:reflection_generator:
        generate_for:
          # Entry points, not every annotated source: each one becomes a
          # reflection domain covering the classes reachable from it.
          - test/reflection_test.dart
          - example/run_all_samples.dart
        options:
          formatted: true
```

List **entry points**, not globs. Discovery walks every annotated class in a
domain and aborts the whole pass on the first interface it cannot resolve, so
fixtures that are deliberately ambiguous or deliberately excluded need domains
of their own — which is why this package's own `build.yaml` names each test
file individually rather than matching `test/**_test.dart`.

### Running the Builder

Generate reflection code with:

```bash
dart run build_runner build
```

Or for continuous generation during development:

```bash
dart run build_runner watch
```

### Generated Files

One `.reflection.dart` is generated per file listed in `generate_for` — not
per file that happens to contain annotated classes:

```
run_all_samples.dart
run_all_samples.reflection.dart  ← Generated
```

Each generated file covers every annotated class reachable through its entry
point's imports, so one artifact spans a whole tree of sources. This package's
`example/run_all_samples.reflection.dart` is the illustration: fifteen sample
files declare annotated classes and one generated file serves them all.

Import it and call the `initializeReflection()` it declares before any
reflection happens:

```dart
import 'run_all_samples.reflection.dart';

void main() {
  initializeReflection();
  // ...
}
```

## Type Resolution

For working with generic collection types, helper methods are available:

### Get List Element Type

```dart
List<Person> people = [];
final elementMirror = tomReflectionInfo.singleElementType(people);
// elementMirror is the ClassMirror for Person
```

### Get Map Value Type

```dart
Map<String, Person> peopleMap = {};
final valueMirror = tomReflectionInfo.mapValueElementType(peopleMap);
// valueMirror is the ClassMirror for Person
```

These are useful when dynamically creating instances for collection elements.

### Each Method Takes One Arity

The two methods are not interchangeable, and neither one falls back to the
other. `singleElementType` requires **exactly one** type argument;
`mapValueElementType` requires **exactly two**. The arity is checked before the
name is resolved, so a collection of the wrong shape raises rather than
returning a mirror for whichever argument happened to sit in the right slot:

```dart
tomReflectionInfo.singleElementType(<String, Person>{});
// reflector.type_resolution.not_a_single_element_type
// "…is not a List<T> or Set<T> type (expected one type argument, found 2);
//  use mapValueElementType for this collection"

tomReflectionInfo.mapValueElementType(<Person>[]);
// reflector.type_resolution.not_a_map_type
// "…is not a Map<K, V> type (expected two type arguments, found 1);
//  use singleElementType for this collection"
```

The `use …` clause appears **only** when the argument count is the one the
sibling method takes. A three-argument generic belongs to neither, so both
methods report the count and stop — pointing at a method that would refuse the
same collection would send the reader in a circle.

Why the check exists: `singleElementType` on a `Map<K, V>` used to resolve the
**key** type and report success. For `Map<String, Person>` that is the mirror
for `String`; for `Map<Address, Person>` it is a perfectly valid mirror for
`Address`. Nothing at the call site could distinguish that from the right
answer, so the wrong half of the collection propagated silently.

Both resolve the element type by **simple name** against the classes annotated
with `@tomReflector`, which is why they go one level deep and no further: a
generic instantiation such as `List<String>` is not an annotated class and
never will be. Given `List<List<String>>` or `Map<String, Map<String, int>>`
they raise `reflector.type_resolution.nested_generic_unsupported` rather than
searching for a type that cannot exist.

---

## Dependencies

This module depends on:

- **`tom_reflection`** (hosted on pub.dev, constraint `>=1.0.1`): supplies
  `Reflection`, the `ClassMirror`/`InstanceMirror` types and
  `NoSuchCapabilityError`. A Tom-framework package rather than a third-party
  one, but consumed by version constraint like any other hosted dependency —
  there is no path dependency and no override. Its mirror data is produced at
  build time by `tom_reflection_generator` (a dev dependency); see
  [Build Configuration](#build-configuration).
- **Observable Module**: `TomClass` and the observable field types, which the
  JSON conversion special-cases rather than treating as opaque objects
- **Timezoned Module**: `TomZonedDate`, `TomZonedTime` and `TomZonedDateTime` —
  the conversion knows these three types by name, which is why a zoned value
  survives a round trip that a general object graph would flatten
- **Little Things Module**: `TomException`, the base of `TomReflectorException`
- **`tom_basics`**: `tomLog`, used at `trace` level throughout the conversion to
  report each declaration and value it resolves. This is verbose by design and
  is the first thing to turn up when a field fails to serialize
- **`dart:convert`**: the `jsonEncode`/`jsonDecode` behind the string-level
  conversion entry points

The whole module is one file, `reflection.dart`, so every row above applies to
it.

### The observable edge is a cycle

The [observable module](../observable/observable.md) imports this one back —
for `@tomReflector` and the reflector itself, which is how `TomClass` discovers
its own fields. So the two are mutually dependent: reflection needs to
recognize `TomClass` to convert it, and `TomClass` needs the reflector to
describe itself. Dart permits the cycle, but neither module can be extracted
from the package without the other.
