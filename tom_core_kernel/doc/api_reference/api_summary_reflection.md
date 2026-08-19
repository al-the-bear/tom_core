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
TomReflectionInfo(TomReflector reflector)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `debugSwitchLogReflectionDetailsMembers` | `bool` | When true, logs detailed member information during reflection operations (default `false`). |
| `debugSwitchLogReflectionDetailsValues` | `bool` | When true, logs detailed value setting/getting operations (default `false`). |
| `debugSwitchLogReflectionDetailsTypes` | `bool` | When true, logs type resolution information (default `false`). |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `reflector` | `TomReflector` | The reflector instance used for all reflection operations. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `mapValueElementType` | `ClassMirror mapValueElementType(Object collection)` | Extracts the value type's `ClassMirror` from a `Map<K, V>` type annotation. Throws `TomReflectorException` if the collection is not generic, carries fewer than two type arguments, the value type is not among annotated classes, or its simple name is ambiguous. |
| `singleElementType` | `ClassMirror singleElementType(Object collection)` | Extracts the element type's `ClassMirror` from a single-type-parameter collection (e.g. `List`, `Set`). Throws `TomReflectorException` if the collection is not generic, the element type is not found, or its simple name is ambiguous. |
| `reportReflectObject` | `void reportReflectObject(Object o)` | Prints detailed reflection information about an object (declarations, instance members, superclass hierarchy) for debugging. |
| `reportReflect` | `void reportReflect(ClassMirror cm)` | Prints detailed reflection information about a `ClassMirror` for debugging. |
| `convertFromJsonString` | `T convertFromJsonString<T extends Object>(T o, String s)` | Parses a JSON string and populates the fields of object `o`; returns the same object. |
| `createInstanceFromJsonString` | `T? createInstanceFromJsonString<T extends Object>(ClassMirror objectMirror, String s)` | Creates a new instance of `T` from a JSON string using `objectMirror`; returns null if creation fails. |
| `createInstanceFromJson` | `T? createInstanceFromJson<T extends Object>(ClassMirror objectMirror, Map<String, Object?> jsonData)` | Creates a new instance of `T` from JSON data, preferring a `fromJson` constructor and falling back to the default constructor plus `setValues`. |
| `createInstance` | `T createInstance<T extends Object>([Type? type])` | Creates a new instance of `T` (or `type`) using its default constructor; throws `TomReflectorException` if instantiation fails. |
| `setValues` | `T setValues<T extends Object>(T o, Map<String, dynamic> values)` | Sets field values on `o` from a map (the main deserialization entry point); handles primitives, `int`→`double` widening, date/time types, nested annotated objects, and collections. Collections of annotated objects are assigned atomically — the field is untouched unless every element materializes. Resolves the class from the instance, so an annotated generic class is populated like any other; see `getValues`. |
| `convertToJsonString` | `String convertToJsonString(Object o)` | Calls `getValues` and encodes the result to a JSON string. |
| `getValues` | `Map<String, Object?> getValues(Object o)` | Extracts all values from an object as a JSON-compatible map (the main serialization entry point). Resolves the class from the *instance*, so an annotated **generic** class serializes like any other — the registry is keyed by declaration and holds no `Holder<int>` entry, which is what a `reflectType(o.runtimeType)` lookup would fall over on. The type argument is not a member, so two instantiations of one declaration produce one JSON shape. |

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `tomReflector` | `const TomReflector tomReflector` | Global reflector annotation applied to classes (`@tomReflector`) that need reflection support. |
| `tomReflectionInfo` | `final TomReflectionInfo tomReflectionInfo` | Global reflection-info instance used for all reflection operations, built from `tomReflector`. |
