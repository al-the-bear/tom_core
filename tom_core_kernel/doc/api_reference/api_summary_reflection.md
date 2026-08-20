# Tom Core Kernel API Reference: Reflection Module

The reflection surface used across the Tom framework for JSON serialization and
deserialization of annotated classes: a configured reflector, a rich
reflection-based converter, an exception type, and the global annotation and
converter singletons.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomReflectorException](#tomreflectorexception)
  - [TomReflector](#tomreflector)
  - [TomReflectionInfo](#tomreflectioninfo)
- [Serialization Hooks](#serialization-hooks)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tombase/reflection/reflection.dart`.

This is a stable module that wraps the `tom_reflection` package's `Reflection`
type with the capability set the Tom framework needs, and layers a JSON
converter on top. `TomReflector` is a `Reflection` preconfigured with the
invoking, typing, type-relations, reflected-type, deep/quantify type-annotation,
metadata, and superclass-quantify capabilities. `TomReflectionInfo` is the main
entry point for reflection-driven serialization: it creates instances of
`@tomReflector`-annotated classes, populates their fields from JSON/maps
(handling primitives, `DateTime` and `TomZoned*` date/time types, nested
annotated objects, and typed `List`/`Map` collections), and extracts their
fields back into JSON-compatible maps. `TomReflectorException` (a kernel
`TomException` subtype) signals failures in these operations. The module also
exposes the global `tomReflector` annotation and the shared `tomReflectionInfo`
converter.

## Class Hierarchy

```
TomException  (kernel)
    └── TomReflectorException

Reflection  (tom_reflection)
    └── TomReflector

TomReflectionInfo
```

## Classes

### TomReflectorException

Exception thrown when reflection operations fail — instance creation from JSON,
field-value setting via reflection, collection type resolution, and
serialization/deserialization.

- **Extends:** `TomException`

#### Constructors

```dart
TomReflectorException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? stack,
  Object? rootException,
  bool? autoLog,
})
```

### TomReflector

A reflector configured with the capabilities required for JSON serialization and
deserialization of annotated classes (invoking, typing, type relations,
reflected type, deep/quantify type annotations, metadata, and superclass
quantify). Classes must be annotated with `@tomReflector` to be discoverable at
runtime.

- **Extends:** `Reflection`

#### Constructors

```dart
const TomReflector()
```

### TomReflectionInfo

Provides reflection-based operations for object serialization and
deserialization: creating instances of annotated classes, setting values on
objects from JSON/maps, getting values from objects as JSON/maps, and resolving
element types from collections.

#### Constructors

```dart
TomReflectionInfo({bool strictUnknownFields = false})
```

Takes no reflector: every operation goes through the global `tomReflector`.
The generator emits mirror data only for a **direct** subclass of `Reflection`,
which `TomReflector` already is, so no second reflector can carry data; and
`const TomReflector()` is canonicalised to `tomReflector` besides. Prefer the
shared `tomReflectionInfo` instance — the one thing a converter of your own can
differ in is `strictUnknownFields`, and it is not which reflector it uses.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `debugSwitchLogReflectionDetailsMembers` | `bool` | When true, logs detailed member information during reflection operations (default `false`). |
| `debugSwitchLogReflectionDetailsValues` | `bool` | When true, logs detailed value setting/getting operations (default `false`). |
| `debugSwitchLogReflectionDetailsTypes` | `bool` | When true, logs type resolution information (default `false`). |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `strictUnknownFields` | `bool` | Whether `setValues` rejects a key naming no field on the target, with `reflection.set.unknown_field`. Final, and `false` on the shared `tomReflectionInfo`: tolerating unknown keys keeps the wire format forward-compatible, so strictness is opted into per converter where both ends of the payload are yours. Carried by the converter rather than passed per call so that nesting inherits it — the walk recurses through `createInstanceFromJson` on the same instance. |

The only instance state there is. Type arguments are parsed by a static helper
that counts bracket depth.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `mapValueElementType` | `ClassMirror mapValueElementType(Object collection)` | Extracts the value type's `ClassMirror` from a `Map<K, V>` type annotation. Type arguments are split on bracket depth, so a comma inside the value's own arguments is not a separator. Throws `TomReflectorException` if the collection is not generic, carries fewer than two top-level type arguments, the value type is itself generic (`reflector.type_resolution.nested_generic_unsupported`), is not among annotated classes, or its simple name is ambiguous. |
| `singleElementType` | `ClassMirror singleElementType(Object collection)` | Extracts the element type's `ClassMirror` from a single-type-parameter collection (e.g. `List`, `Set`). Throws `TomReflectorException` if the collection is not generic, the element type is itself generic (`reflector.type_resolution.nested_generic_unsupported`), is not found, or its simple name is ambiguous. Both methods resolve by simple name against the annotated classes, so one level of nesting is the supported depth — a `List<String>` is not an annotated class and cannot be resolved. |
| `reportReflectObject` | `void reportReflectObject(Object o)` | Prints detailed reflection information about an object (declarations, instance members, superclass hierarchy) for debugging. Held to the same annotation check as the converting entry points: throws `TomReflectorException` (`reflector.reflect.not_reflectable`) if the object's class has no generated data, and (`reflector.type.not_annotated`) if it reflects but carries no `@tomReflector`. |
| `reportReflect` | `void reportReflect(ClassMirror cm)` | Prints detailed reflection information about a `ClassMirror` for debugging: the class name, its declarations, its instance members, then the same again for each superclass. A mirror with no reflected type — which is every *generic* annotated class, since the registry holds the declaration and a declaration is not a type — prints `<name> has no reflected type` and nothing else. |
| `convertFromJsonString` | `T convertFromJsonString<T extends Object>(T o, String s)` | Parses a JSON string and populates the fields of object `o` in place; returns that same object. Parses before any reflection happens, so malformed JSON raises a `FormatException` from `jsonDecode` and `o` is left untouched. The inverse of `convertToJsonString`. |
| `createInstanceFromJsonString` | `T createInstanceFromJsonString<T extends Object>(ClassMirror objectMirror, String s)` | Creates a new instance of `T` from a JSON string using `objectMirror`. Parses `s` before any reflection happens, so malformed JSON raises a `FormatException` from `jsonDecode`; everything after that is `createInstanceFromJson`. Returns the instance or throws — there is no failure value. |
| `createInstanceFromJson` | `T createInstanceFromJson<T extends Object>(ClassMirror objectMirror, Map<String, Object?> jsonData)` | Creates a new instance of `T` from JSON data, preferring a `fromJson` constructor and falling back to the default constructor plus `setValues` — so a class declaring only `jsonDecode` is honoured here too, while one declaring only `fromJson` is not honoured by `setValues`; see [Serialization Hooks](#serialization-hooks). The constructor is looked up in the mirror's declarations *before* it is called, so the fallback happens only when there genuinely is no `fromJson`. One that exists and raises throws `TomReflectorException` (`reflection.hook.failed`) naming the hook and the class and keeping the original error as `rootException` — catching and discarding it instead would let a bug in the caller's own constructor be rebuilt around by the fallback path and reported, if at all, as a field-level type mismatch inside the reflection layer. One that returns something that is not a `T` throws `reflection.hook.invalid_return`. A target the reflector cannot construct at all — a quantified built-in such as `String`, which has mirror data but no invocable default constructor — throws `reflector.instance_creation.failed`, the same key and shape `createInstance` uses, rather than letting `tom_reflection`'s own `NoSuchCapabilityError` escape unwrapped — an exception type this module never tells anyone to catch. Returns the instance or throws: every exit either produces a `T` or raises, so the result is non-nullable and a caller testing it for null is writing a branch that cannot be entered. |
| `createInstance` | `T createInstance<T extends Object>([Type? type])` | Creates a new instance using its default constructor. The type is named twice over and the two are not the same question: `type` says *what to build*, `T` says *what to call the result* and is applied to it as a cast. Each defaults to the other, so most calls pass only one — but passing only `type` leaves nothing to infer `T` from, so it falls to its bound and the result is statically an `Object` even though the instance is of the requested class. Passing both is worthwhile when they differ: it builds `type` and hands it back as a supertype it satisfies. Nothing checks that they agree until the cast runs, so a `type` that is not a `T` is not a compile error; it throws `TomReflectorException` (`reflector.instance_creation.failed`), as does a class that cannot be reflected or constructed. |
| `setValues` | `T setValues<T extends Object>(T o, Map<String, dynamic> values)` | Sets field values on `o` from a map (the main deserialization entry point); handles primitives, `int`→`double` widening, date/time types, nested annotated objects, and collections. A `TomClass` short-circuits everything below: `o.setValues(values)` is called and no mirror is taken. Otherwise a class declaring a `jsonDecode` method takes deserialization over entirely; the method is looked up in `instanceMembers` before it is called, so only its genuine absence falls back to the field walk. For the full precedence and the other three hooks, see [Serialization Hooks](#serialization-hooks). A `jsonDecode` that exists and raises throws `TomReflectorException` (`reflection.hook.failed`) rather than being read as absent and silently replaced by the walk it was written to override. A String bound for a `DateTime`, `TomZonedDate`, `TomZonedTime` or `TomZonedDateTime` field that will not parse throws `TomReflectorException` (`reflection.set.date_parse_failed`) naming the class, the field and the offending text — plus the map key or list index when the field is a `Map<String, DateTime>` or `List<DateTime>` — and keeps the `FormatException` as `rootException` rather than letting it escape bare: a bare `FormatException` names no field, no class and no exception id, and is invisible to `on TomReflectorException`. The field, or the collection, retains its previous contents. Collections are assigned atomically — the field is untouched unless every element materializes — and this covers collections of primitives as well as of annotated objects: a typed collection is built and checked element by element before assignment, never through a lazy `cast`. An element the target type rejects throws `TomReflectorException` (`reflection.set.collection_element_type_mismatch`) naming the field, the position and the value; a non-`String` map key throws `reflection.set.map_key_type_mismatch`. Collections nest one level deep: a field whose element type is itself generic (`List<List<String>>`, `Map<String, List<X>>`) throws `reflector.type_resolution.nested_generic_unsupported`, naming the field's declared type rather than reporting the cast that failed inside. `int`→`double` widening applies inside collections too. Resolves the class from the instance, so an annotated generic class is populated like any other; see `getValues`. Throws `TomReflectorException` (`reflector.reflect.not_reflectable`) if `o`'s class has no generated reflection data, and (`reflector.type.not_annotated`) if it reflects but is not annotated — without that check a `String`, `int`, `DateTime` or `List` target would be returned unchanged, reporting success for a write that could not happen. A key naming no field at all is ignored — the rest of the map is applied and the object returned — unless the converter was built with `strictUnknownFields: true`, which throws `reflection.set.unknown_field` naming the class and the key. Strictness reaches nested objects, because the recursion re-enters through the same instance. Two neighbours are not governed by the flag: a key naming a member that exists but cannot be written (`static`, `final`, private) throws `reflection.set.unexpected_condition_final_static_private` in both modes, and a setter with no matching getter is ignored in both — the member does exist, only its declared type is missing. |
| `convertToJsonString` | `String convertToJsonString(Object o)` | Calls `getValues` and encodes the result to a JSON string. |
| `getValues` | `Map<String, Object?> getValues(Object o)` | Extracts all values from an object as a JSON-compatible map (the main serialization entry point). A `TomClass` short-circuits everything below: `o.toJson()` is returned and no mirror is taken. Outside that one case a plain `toJson()` method is *not* consulted, and neither is `TomJsonSerializable` — see [Serialization Hooks](#serialization-hooks). Otherwise a class declaring a `jsonEncode` getter supplies its own representation; the getter is looked up in `instanceMembers` before it is read, so only its genuine absence falls back to the field walk. One that exists and raises throws `TomReflectorException` (`reflection.hook.failed`); one that returns anything but a `Map<String, Object?>` throws `reflection.hook.invalid_return`. Were either indistinguishable from "no such getter", the custom representation would be quietly dropped and the fields it exists to replace serialized instead. Resolves the class from the *instance*, so an annotated **generic** class serializes like any other — the registry is keyed by declaration and holds no `Holder<int>` entry, which is what a `reflectType(o.runtimeType)` lookup would fall over on. The type argument is not a member, so two instantiations of one declaration produce one JSON shape. Throws `TomReflectorException` (`reflector.reflect.not_reflectable`) if `o`'s class has no generated reflection data, and (`reflector.type.not_annotated`) if it reflects but carries no `@tomReflector`. The latter is the case that would otherwise return `{}`: quantified built-ins such as `String`, `int`, `DateTime` and `List` have mirror data because they appear as field types, present no settable declarations, and would serialize to an empty map — which `convertToJsonString` would turn into the string `"{}"`. The test is the metadata on the resolved mirror, not membership of `annotatedClasses`, which holds the quantified types and omits the mirror of an annotated generic instantiation. |

## Serialization Hooks

Four member names are part of this module's contract even though they are not
declared anywhere in it: a class *of the caller's* that declares one of them
takes over the corresponding conversion. Two are outbound, two inbound. The
names are looked for by string, so nothing enforces the signature — declaring
one with the wrong shape produces a hook failure at run time, not a compile
error.

| Hook | Kind | Expected signature | Direction | Honoured by |
| ---- | ---- | ------------------ | --------- | ----------- |
| `jsonEncode` | getter | `Map<String, Object?> get jsonEncode` | out | `getValues` — found via `instanceMembers`, on any annotated class |
| `toJson` | method | `Map<String, dynamic> toJson()` | out | `getValues` — **only** when the object `is TomClass`; not looked up by name |
| `jsonDecode` | method | `void jsonDecode(Map<String, dynamic> values)` | in | `setValues` — found via `instanceMembers`; the return value is ignored |
| `fromJson` | named constructor | `X.fromJson(Map<String, Object?> json)` | in | `createInstanceFromJson` — found in the mirror's declarations |

The two directions are not symmetric, and the asymmetry is in the names: the
outbound pair is `jsonEncode`/`toJson`, the inbound pair
`jsonDecode`/`fromJson`. `jsonEncode` and `jsonDecode` are a matched pair;
`toJson` and `fromJson` are not — `toJson` is reachable only through
`TomClass`, `fromJson` on any class the reflector can see.

**Outbound precedence, as `getValues` applies it:**

1. `o is TomClass` → return `o.toJson()`. No mirror is taken.
2. Reflect the instance (`reflector.reflect.not_reflectable` if there is no
   generated data) and require `@tomReflector` on the resolved mirror
   (`reflector.type.not_annotated`).
3. Read the `jsonEncode` getter if `instanceMembers` has one; its result is
   the answer.
4. Otherwise walk the non-static, non-final, non-private fields.

A plain `toJson()` method is not consulted at step 3, and neither is
`TomJsonSerializable`. Today a class that implements `TomJsonSerializable` but
is neither a `TomClass` nor `@tomReflector`-annotated does not fall back to its
own `toJson()` — it fails at step 2. `TomErrorResult` is the worked case: its
`toJson()` returns `{code: …, message: …, retryable: …, severity: …}`, while
`tomReflectionInfo.getValues` on the same instance throws
`TomReflectorException` (`reflector.reflect.not_reflectable`). The server's
endpoint pipeline reaches such results only because it tests `TomClass`,
`TomJsonSerializable`, `Map` and `List` itself before falling through to
`convertToJsonString` — that chain is load-bearing, not a convenience.

**Inbound precedence, as `createInstanceFromJson` applies it:**

1. A `fromJson` named constructor, if the mirror declares one.
2. Otherwise the default constructor, then `setValues` on the result.

**Inbound precedence, as `setValues` applies it:**

1. `o is TomClass` → `o.setValues(values)`, return `o`.
2. Reflect and require the annotation, as above.
3. Invoke `jsonDecode` if `instanceMembers` has one; it takes over entirely.
4. Otherwise set each map entry onto its field.

Because `createInstanceFromJson` falls through to `setValues`, a class
declaring only `jsonDecode` is honoured by both entry points. The reverse does
not hold: a class declaring only `fromJson` is not consulted when an existing
instance is updated.

`TomJsonSerializable`
(`lib/src/tombase/json/json_serializable.dart`) declares nothing but
`Map<String, Object?> toJson();`. It exists as the cheap `is` test by which a
caller's custom conversion is *detected* — a one-instruction type check in
place of a mirror lookup — not as a workaround for something the serializer
cannot do. Implement it to say "this type converts itself"; it carries no
business or security logic and adds no behaviour of its own.

Three of the four hooks — `jsonEncode`, `jsonDecode` and `fromJson` — share one
failure contract: each is looked up before it is called, so a hook that exists
and fails throws `TomReflectorException` (`reflection.hook.failed`, or
`reflection.hook.invalid_return` for a wrong return type) rather than being
mistaken for an absent one and silently replaced by the walk it was written to
override. `toJson` is not among them: nothing looks it up, `TomClass.toJson()`
is called directly, and a failure inside it propagates as whatever it threw.

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `tomReflector` | `const TomReflector tomReflector` | Global reflector annotation applied to classes (`@tomReflector`) that need reflection support. |
| `tomReflectionInfo` | `final TomReflectionInfo tomReflectionInfo` | Global reflection-info instance used for all reflection operations. The one to reach for: a converter is stateless as far as callers are concerned, so there is nothing a second one could do differently. |
