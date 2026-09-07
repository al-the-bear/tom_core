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
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
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
| `convertFromJsonString` | `T convertFromJsonString<T extends Object>(T o, String s)` | Parses a JSON string and populates the fields of object `o`; returns `o`, or — for a class declaring a `fromJson` constructor — the instance that constructor built, so the return value is the one to keep. Parses before any reflection happens, so malformed JSON raises a `FormatException` from `jsonDecode` and `o` is left untouched. The inverse of `convertToJsonString`. |
| `createInstanceFromJsonString` | `T createInstanceFromJsonString<T extends Object>(ClassMirror objectMirror, String s)` | Creates a new instance of `T` from a JSON string using `objectMirror`. Parses `s` before any reflection happens, so malformed JSON raises a `FormatException` from `jsonDecode`; everything after that is `createInstanceFromJson`. Returns the instance or throws — there is no failure value. |
| `createInstanceFromJson` | `T createInstanceFromJson<T extends Object>(ClassMirror objectMirror, Map<String, Object?> jsonData)` | Creates a new instance of `T` from JSON data, preferring a `fromJson` constructor and falling back to the default constructor plus `setValues` — which reaches `jsonDecode` and the field walk, so all four hooks are honoured here, in the same order `setValues` itself applies; see [Serialization Hooks](#serialization-hooks). The constructor is looked up in the mirror's declarations *before* it is called, so the fallback happens only when there genuinely is no `fromJson`. One that exists and raises throws `TomReflectorException` (`reflection.hook.failed`) naming the hook and the class and keeping the original error as `rootException` — catching and discarding it instead would let a bug in the caller's own constructor be rebuilt around by the fallback path and reported, if at all, as a field-level type mismatch inside the reflection layer. One that returns something that is not a `T` throws `reflection.hook.invalid_return`. A target the reflector cannot construct at all — a quantified built-in such as `String`, which has mirror data but no invocable default constructor — throws `reflector.instance_creation.failed`, the same key and shape `createInstance` uses, rather than letting `tom_reflection`'s own `NoSuchCapabilityError` escape unwrapped — an exception type this module never tells anyone to catch. Returns the instance or throws: every exit either produces a `T` or raises, so the result is non-nullable and a caller testing it for null is writing a branch that cannot be entered. |
| `createInstance` | `T createInstance<T extends Object>([Type? type])` | Creates a new instance using its default constructor. The type is named twice over and the two are not the same question: `type` says *what to build*, `T` says *what to call the result* and is applied to it as a cast. Each defaults to the other, so most calls pass only one — but passing only `type` leaves nothing to infer `T` from, so it falls to its bound and the result is statically an `Object` even though the instance is of the requested class. Passing both is worthwhile when they differ: it builds `type` and hands it back as a supertype it satisfies. Nothing checks that they agree until the cast runs, so a `type` that is not a `T` is not a compile error; it throws `TomReflectorException` (`reflector.instance_creation.failed`), as does a class that cannot be reflected or constructed. |
| `setValues` | `T setValues<T extends Object>(T o, Map<String, dynamic> values)` | Sets field values on `o` from a map (the main deserialization entry point); handles primitives, `int`→`double` widening, date/time types, nested annotated objects, and collections. A `TomClass` short-circuits everything below: `o.setValues(values)` is called and no mirror is taken. Otherwise a class declaring a `fromJson` constructor takes deserialization over — the constructor is invoked and **its** instance is what comes back, so `o` is left untouched and the return value is the one to keep — and failing that, a class declaring a `jsonDecode` method takes it over entirely. Both are looked up (in the mirror's declarations, in `instanceMembers`) before they are called, so only genuine absence falls back to the field walk. This is the same order `createInstanceFromJson` applies, so which of the two a caller reaches for does not change which hooks run; for the full precedence and the outbound pair, see [Serialization Hooks](#serialization-hooks). A `fromJson` or `jsonDecode` that exists and raises throws `TomReflectorException` (`reflection.hook.failed`) rather than being read as absent and silently replaced by the walk it was written to override; a `fromJson` returning something that is not a `T` throws `reflection.hook.invalid_return`. A String bound for a `DateTime`, `TomZonedDate`, `TomZonedTime` or `TomZonedDateTime` field that will not parse throws `TomReflectorException` (`reflection.set.date_parse_failed`) naming the class, the field and the offending text — plus the map key or list index when the field is a `Map<String, DateTime>` or `List<DateTime>` — and keeps the `FormatException` as `rootException` rather than letting it escape bare: a bare `FormatException` names no field, no class and no exception id, and is invisible to `on TomReflectorException`. The field, or the collection, retains its previous contents. Collections are assigned atomically — the field is untouched unless every element materializes — and this covers collections of primitives as well as of annotated objects: a typed collection is built and checked element by element before assignment, never through a lazy `cast`. An element the target type rejects throws `TomReflectorException` (`reflection.set.collection_element_type_mismatch`) naming the field, the position and the value; a non-`String` map key throws `reflection.set.map_key_type_mismatch`. Collections nest one level deep: a field whose element type is itself generic (`List<List<String>>`, `Map<String, List<X>>`) throws `reflector.type_resolution.nested_generic_unsupported`, naming the field's declared type rather than reporting the cast that failed inside. `int`→`double` widening applies inside collections too. Resolves the class from the instance, so an annotated generic class is populated like any other; see `getValues`. Throws `TomReflectorException` (`reflector.reflect.not_reflectable`) if `o`'s class has no generated reflection data, and (`reflector.type.not_annotated`) if it reflects but is not annotated — without that check a `String`, `int`, `DateTime` or `List` target would be returned unchanged, reporting success for a write that could not happen. A key naming no field at all is ignored — the rest of the map is applied and the object returned — unless the converter was built with `strictUnknownFields: true`, which throws `reflection.set.unknown_field` naming the class and the key. Strictness reaches nested objects, because the recursion re-enters through the same instance. Two neighbours are not governed by the flag: a key naming a member that exists but cannot be written (`static`, `final`, private) throws `reflection.set.unexpected_condition_final_static_private` in both modes, and a setter with no matching getter is ignored in both — the member does exist, only its declared type is missing. |
| `convertToJsonString` | `String convertToJsonString(Object o)` | Calls `getValues` and encodes the result to a JSON string — **the** outbound entry point, and the only one a transport should need. A `List` or a `Map` is the exception: it is encoded as itself, its complex elements rendered by `getValues` and its scalars passed through, to any depth. `getValues` still refuses both, and correctly — a container has no fields to read; only the string form has an answer, because a container is directly encodable once its contents are. This is what lets a handler return `List<Task>` without its transport growing a serialization policy of its own, which is how the endpoint pipeline and the HTTP client came to honour different hook sets. The container is walked explicitly rather than handed to `jsonEncode` with a `toEncodable` callback, because `dart:convert` catches whatever that callback raises and rethrows `JsonUnsupportedObjectError` — the annotation guard's message, which names the offending type, would reach the caller as "converting object to an encodable object failed". So a value inside a container that is not yours throws `TomReflectorException` unwrapped, exactly as a top-level one does. Nothing in the container walk reproduces the field walk's date/zoned-time conversions: those belong to `getValues`, and a second copy of that table is how the two would drift, so a bare `DateTime` sitting directly in a map is refused. A bare scalar stays refused too — it is not a container, so it takes the object path and meets the annotation guard. |
| `getValues` | `Map<String, Object?> getValues(Object o)` | Extracts all values from an object as a JSON-compatible map (the main serialization entry point). A `TomClass` short-circuits everything below: `o.toJson()` is returned and no mirror is taken, and a `TomJsonSerializable` is answered the same way and just as cheaply — testing the interface *before* reflecting is what lets an unannotated self-rendering DTO serialize instead of throwing. Otherwise a class declaring a `toJson()` method, and failing that one declaring a `jsonEncode` getter, supplies its own representation; each is looked up in `instanceMembers` before it is invoked, so only its genuine absence falls back to the field walk. For the full precedence and the inbound pair, see [Serialization Hooks](#serialization-hooks). One that exists and raises throws `TomReflectorException` (`reflection.hook.failed`); one that returns anything but a `Map<String, Object?>` throws `reflection.hook.invalid_return`. Were either indistinguishable from "no such member", the custom representation would be quietly dropped and the fields it exists to replace serialized instead. Resolves the class from the *instance*, so an annotated **generic** class serializes like any other — the registry is keyed by declaration and holds no `Holder<int>` entry, which is what a `reflectType(o.runtimeType)` lookup would fall over on. The type argument is not a member, so two instantiations of one declaration produce one JSON shape. Throws `TomReflectorException` (`reflector.reflect.not_reflectable`) if `o`'s class has no generated reflection data, and (`reflector.type.not_annotated`) if it reflects but carries no `@tomReflector`. The latter is the case that would otherwise return `{}`: quantified built-ins such as `String`, `int`, `DateTime` and `List` have mirror data because they appear as field types, present no settable declarations, and would serialize to an empty map — which `convertToJsonString` would turn into the string `"{}"`. The test is the metadata on the resolved mirror, not membership of `annotatedClasses`, which holds the quantified types and omits the mirror of an annotated generic instantiation. The field walk reaches the same `{}`-as-success shape by a second route, and is refused the same way: a walk that contributes no field and skipped at least one `final` member throws `TomReflectorException` (`reflector.type.all_final`), naming the type and the members dropped. `final` members stay skipped — deserialization can never assign one back, so emitting them would buy a payload that renders and never restores — and the guard is narrow enough that only *total, invisible* loss is refused: a class contributing even one field serializes normally, and a class with no wire members at all returns `{}`, which is true of it. It is not a ban on immutability either, since all four rendering hooks precede the walk: an all-`final` class declaring `toJson()`, `jsonEncode`, `TomJsonSerializable` or extending `TomClass` never reaches it. Inbound is not silent either: a payload key naming a `final` member throws `reflection.set.unexpected_condition_final_static_private`. |

## Serialization Hooks

Four member names are part of this module's contract even though they are not
declared anywhere in it: a class *of the caller's* that declares one of them
takes over the corresponding conversion. Two are outbound, two inbound. The
names are looked for by string, so nothing enforces the signature — declaring
one with the wrong shape produces a hook failure at run time, not a compile
error.

| Hook | Kind | Expected signature | Direction | Honoured by |
| ---- | ---- | ------------------ | --------- | ----------- |
| `toJson` | method | `Map<String, Object?> toJson()` | out | `getValues` — nominally via `TomClass`/`TomJsonSerializable`, structurally via `instanceMembers` |
| `jsonEncode` | getter | `Map<String, Object?> get jsonEncode` | out | `getValues` — found via `instanceMembers`, on any annotated class |
| `fromJson` | named constructor | `X.fromJson(Map<String, Object?> json)` | in | `setValues` **and** `createInstanceFromJson` — found in the mirror's declarations |
| `jsonDecode` | method | `void jsonDecode(Map<String, dynamic> values)` | in | `setValues` **and** `createInstanceFromJson` — found via `instanceMembers`; the return value is ignored |

There are exactly **two** entry points, one per direction: `getValues`
outbound, `setValues` inbound. Each honours every hook of its direction, so
which of the two inbound functions a caller happens to reach for no longer
changes which hooks apply — `createInstanceFromJson` differs from `setValues`
only in *building* the object rather than being handed one. A consumer
therefore never needs a hook chain of its own.

**Outbound precedence, as `getValues` applies it:**

1. `o is TomClass` → return `o.toJson()`. No mirror is taken.
2. `o is TomJsonSerializable` → return `o.toJson()`. Also no mirror: the
   interface exists to be cheap, and testing it *before* reflecting is what
   lets an unannotated self-rendering DTO serialize instead of throwing.
3. Reflect the instance (`reflector.reflect.not_reflectable` if there is no
   generated data), require `@tomReflector` on the resolved mirror
   (`reflector.type.not_annotated`), then invoke a `toJson()` method if
   `instanceMembers` has one.
4. Otherwise read the `jsonEncode` getter if `instanceMembers` has one.
5. Otherwise walk the non-static, non-final, non-private fields. A walk that
   contributes nothing *and* skipped at least one `final` member throws
   `reflector.type.all_final` instead of returning `{}`.

Steps 1–3 are one hook under three spellings — two nominal, one structural —
and are therefore ranked together, ahead of `jsonEncode`. Were `jsonEncode`
placed between them, adding `implements TomJsonSerializable` to a class
carrying both hooks would silently change its wire format: a declaration of
intent would become a behavioural change.

**Inbound precedence, as `setValues` applies it:**

1. `o is TomClass` → `o.setValues(values)`, return `o`.
2. Reflect and require the annotation, as above, then invoke the `fromJson`
   constructor if the mirror declares one and **return what it built**.
3. Otherwise invoke `jsonDecode` if `instanceMembers` has one; it takes over
   entirely and `o` is returned.
4. Otherwise set each map entry onto its field.

`fromJson` outranks `jsonDecode` because a constructor is the more complete
statement: it owns the object from nothing, where the method only overwrites
what is already there.

`createInstanceFromJson` applies the same order, starting from a mirror rather
than an instance: `fromJson` if the mirror declares one, otherwise the default
constructor followed by `setValues` — which reaches steps 3 and 4 above. The
two entry points therefore agree on all four hooks.

**A `fromJson` class does not preserve identity.** A constructor builds an
object rather than filling one, so `setValues(x, map)` on such a class returns
a *new* instance and leaves `x` untouched. Use the return value:
`x = converter.setValues(x, map)` is correct for every shape, while calling
`setValues` and then reading `x` is correct for every shape *but* this one.

`TomJsonSerializable`
(`lib/src/tombase/json/json_serializable.dart`) declares nothing but
`Map<String, Object?> toJson();`. It exists as the cheap `is` test by which a
caller's custom conversion is *detected* — a one-instruction type check in
place of a mirror lookup — not as a workaround for something the serializer
cannot do. Implement it to say "this type converts itself"; it carries no
business or security logic and adds no behaviour of its own. Because it is
ranked with the structural `toJson()` rather than above or below it, adding or
removing the declaration never changes the resulting JSON.

All four hooks share one failure contract: each is looked up before it is
called, so a hook that exists and fails throws `TomReflectorException`
(`reflection.hook.failed`, or `reflection.hook.invalid_return` for a wrong
return type) rather than being mistaken for an absent one and silently replaced
by the walk it was written to override. The two nominal forms need none of
this — an `is` test cannot mistake absence for failure — so a failure inside
`TomClass.toJson()` or `TomJsonSerializable.toJson()` propagates as whatever it
threw.

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `tomReflector` | `const TomReflector tomReflector` | Global reflector annotation applied to classes (`@tomReflector`) that need reflection support. |
| `tomReflectionInfo` | `final TomReflectionInfo tomReflectionInfo` | Global reflection-info instance used for all reflection operations. The one to reach for: a converter is stateless as far as callers are concerned, so there is nothing a second one could do differently. |
