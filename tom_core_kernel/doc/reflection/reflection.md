# Tom Reflection System

The Tom Reflection System provides runtime reflection capabilities for Dart classes,
enabling JSON serialization/deserialization without code generation for each model class.
It uses the `reflection` package to achieve this while maintaining type safety.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
- [Annotations](#annotations)
- [Instance Creation](#instance-creation)
- [Deserialization (JSON to Object)](#deserialization-json-to-object)
- [Serialization (Object to JSON)](#serialization-object-to-json)
- [Supported Types](#supported-types)
- [Working with Collections](#working-with-collections)
- [Working with Nested Objects](#working-with-nested-objects)
- [Debug Logging](#debug-logging)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)
- [Build Configuration](#build-configuration)
- [Type Resolution](#type-resolution)
- [Dependencies](#dependencies)

## Overview

The reflection system consists of three main components:

1. **`TomReflector`**: A configured `Reflection` subclass that provides the capabilities
   needed for reflection.

2. **`TomReflectionInfo`**: The main class providing reflection operations like
   instance creation, value setting, and value getting.

3. **`tomReflector` / `tomReflectionInfo`**: Global instances for convenient access.

### Why Use Reflection?

- **No per-model code generation**: Unlike `json_serializable`, you don't need to generate
  code for each model class.
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
final person = tomReflectionInfo.createInstance<Person>(DbPersonImpl);

// Or: final person = tomReflectionInfo.createInstance(DbPersonImpl) as Person;

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
| `createInstanceFromJson<T>(mirror, data)` | Create instance and populate from JSON |
| `setValues<T>(object, values)` | Set field values on an existing object |
| `getValues(object)` | Get all field values as a map |
| `convertToJsonString(object)` | Serialize object to JSON string |
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

## Annotations

### @tomReflector

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
// Using type parameter
final person = tomReflectionInfo.createInstance<Person>();

// Using Type object
final person = tomReflectionInfo.createInstance(Person);
```

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

If your class has a `jsonEncode` getter, it will be used instead of reflection:

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

### Collection Types

**Lists:**
- `List<dynamic>`, `List<Object>`, `List<Object?>`
- `List<String>`, `List<String?>`
- `List<int>`, `List<int?>`
- `List<double>`, `List<double?>`
- `List<bool>`, `List<bool?>`
- `List<DateTime>`, `List<DateTime?>`
- `List<TomZonedDate>`, `List<TomZonedTime>`, `List<TomZonedDateTime>` and their nullable forms
- `List<MyClass>`, `List<MyClass?>` (where MyClass is annotated)

**Maps:**
- `Map<String, dynamic>`, `Map<String, Object>`, `Map<String, Object?>`
- `Map<String, String>`, `Map<String, String?>`
- `Map<String, int>`, `Map<String, int?>`
- `Map<String, double>`, `Map<String, double?>`
- `Map<String, bool>`, `Map<String, bool?>`
- `Map<String, DateTime>`, `Map<String, DateTime?>`
- `Map<String, TomZonedDate>`, `Map<String, TomZonedTime>`, `Map<String, TomZonedDateTime>` and their nullable forms
- `Map<String, MyClass>`, `Map<String, MyClass?>` (where MyClass is annotated)

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
try {
  final instance = tomReflectionInfo.createInstance<UnknownClass>();
} on TomReflectorException catch (e) {
  print('Error key: ${e.key}');
  print('Message: ${e.defaultUserMessage}');
}
```

### Common Error Keys

| Error Key | Description |
|-----------|-------------|
| `reflector.instance_creation.failed` | Failed to create instance |
| `reflector.type_resolution.not_a_generic_type` | The collection's runtime type carries no type arguments |
| `reflector.type_resolution.not_a_map_type` | Expected `Map<K, V>` but found fewer than two type arguments |
| `reflector.type_resolution.nested_generic_unsupported` | The element type is itself a generic collection (`List<List<X>>`, `Map<String, List<X>>`) |
| `reflector.classmirror.not_found_for_map_value` | Map value type not found |
| `reflector.classmirror.not_found_for_iterable_value` | List element type not found |
| `reflector.classmirror.ambiguous_simple_name` | The simple name matches more than one annotated class |
| `reflection.set.unexpected_condition_final_static_private` | Field has a getter but no setter (static, final or private) |
| `reflection.set.unexpected_type` | Unexpected value type during deserialization |
| `reflection.set.unexpected_string_type` | String value for non-DateTime field |
| `reflection.set.datetime_must_be_filled_from_string_in_map` | Non-String element in a `Map<String, DateTime>`-style field |
| `reflection.set.datetime_must_be_filled_from_string_for_list` | Non-String element in a `List<DateTime>`-style field |
| `reflection.set.map_value_materialization_failed` | A value could not be materialized into a `Map<String, T>` field |
| `reflection.set.list_element_materialization_failed` | An element could not be materialized into a `List<T>` field |
| `reflection.set.collection_element_type_mismatch` | An element of a typed primitive collection is not of the field's element type |
| `reflection.set.map_key_type_mismatch` | A `Map<String, T>` field was given a key that is not a `String` |

### Atomic Collection Updates

Collection fields are built in full before the target field is touched. If any
element or value cannot be materialized, a `TomReflectorException` is thrown and
the field keeps its previous content — it is never left cleared, truncated, or
half-populated.

```dart
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
// naming both qualified names in the message.
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
      reflection_builder:
        generate_for:
          - lib/**.dart           # All library files
          - test/**_test.dart     # Test files
          - example/**/**.dart    # Example files
        options:
          formatted: true
```

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

For each file containing annotated classes, a `.reflection.dart` file is generated:

```
my_models.dart
my_models.reflection.dart  ← Generated
```

Import and call `initializeReflection()` from the generated file:

```dart
import 'my_models.reflection.dart';

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

Both resolve the element type by **simple name** against the classes annotated
with `@tomReflector`, which is why they go one level deep and no further: a
generic instantiation such as `List<String>` is not an annotated class and
never will be. Given `List<List<String>>` or `Map<String, Map<String, int>>`
they raise `reflector.type_resolution.nested_generic_unsupported` rather than
searching for a type that cannot exist.

---

## Dependencies

This module depends on:

- **External**: `reflection` package for runtime reflection capabilities
- **Observable Module**: Integration with `TomClass` observable objects
- **Little Things Module**: `TomException`, the base of `TomReflectorException`
