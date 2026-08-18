# Tom Observable System

The Tom Observable System implements the Observer pattern to enable reactive data binding
in Dart applications. It provides observable wrapper types for primitives, collections,
and complex objects with automatic change notification and propagation.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
  - [TomObservable](#tomobservable)
  - [TomObserver](#tomobserver)
  - [TomFunctionObserver](#tomfunctionobserver)
- [Operators](#operators)
- [Observable Primitives](#observable-primitives)
  - [Non-Nullable Types](#non-nullable-types)
  - [Nullable Types](#nullable-types)
- [DateTime and Timezone Types](#datetime-and-timezone-types)
  - [Basic DateTime](#basic-datetime)
  - [Timezone-Aware Types](#timezone-aware-types)
  - [Range Types](#range-types)
- [TomClass (Observable Objects)](#tomclass-observable-objects)
- [The Collection Notification Contract](#the-collection-notification-contract)
- [TomList (Observable Lists)](#tomlist-observable-lists)
  - [Atomic Replacement with resetWith](#atomic-replacement-with-resetwith)
  - [Lifecycle Listeners](#lifecycle-listeners)
- [TomMap (Observable Maps)](#tommap-observable-maps)
- [TomObservableEnum (Resource-Keyed Enums)](#tomobservableenum-resource-keyed-enums)
  - [Resource Keys and Scope](#resource-keys-and-scope)
  - [Locale Changes](#locale-changes)
  - [Missing Keys](#missing-keys)
- [Muting Notifications](#muting-notifications)
- [Error Handling](#error-handling)
- [Class Hierarchy](#class-hierarchy)
- [Best Practices](#best-practices)
- [Dependencies](#dependencies)

## Overview

The observable system consists of two main components:

1. **`tom_observable.dart`**: Base classes for the Observer pattern (`TomObservable`, 
   `TomObserver`, `TomFunctionObserver`)

2. **`tom_observable_objects.dart`**: Observable wrapper types including primitives
   (`TomString`, `TomInt`, etc.), collections (`TomList`, `TomMap`), and complex
   objects (`TomClass`)

### Why Use Observables?

- **Reactive Data Binding**: UI components can automatically update when data changes
- **Change Propagation**: Nested objects propagate changes to parent containers
- **Batch Updates**: Mute notifications during bulk changes for better performance
- **Memory Safe**: Uses `WeakReference` to prevent memory leaks from observers
- **JSON Integration**: Seamless serialization/deserialization with the reflection system

## Quick Start

### 1. Basic Observable Value

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

// Create an observable string
final name = TomString("John");

// Subscribe to changes using >> operator
name >> (obs) => print("Name changed to: ${~name}");

// Set value using | operator - triggers notification
name | "Jane";  // Prints: "Name changed to: Jane"

// Get value using ~ operator
print(~name);  // Prints: "Jane"
```

### 2. Observable Class

```dart
@tomReflector
class Person extends TomClass {
  TomString name = TomString("");
  TomInt age = TomInt(0);
  TomBool isActive = TomBool(true);
}

void main() {
  final person = Person();
  
  // Subscribe to any changes in the Person
  person >> (obs) => print("Person changed!");
  
  // Set values - triggers notification
  person.name | "Alice";  // Prints: "Person changed!"
  person.age | 25;        // Prints: "Person changed!"
  
  // Get values
  print("Name: ${~person.name}");  // Prints: "Name: Alice"
  print("Age: ${~person.age}");    // Prints: "Age: 25"
}
```

### 3. Observable Collections

```dart
// Observable list
final names = TomList<TomString>();
names >> (obs) => print("List changed!");

names.add(TomString("Alice"));  // Prints: "List changed!"
names.add(TomString("Bob"));    // Prints: "List changed!"

// Changes to elements also notify the list
names[0] | "Alicia";  // Prints: "List changed!"

// Observable map
final scores = TomMap<String, TomInt>();
scores >> (obs) => print("Scores changed!");

scores["alice"] = TomInt(100);  // Prints: "Scores changed!"
scores["alice"]! | 95;          // Prints: "Scores changed!"
```

## Core Components

### TomObservable

The foundation of the observer pattern. Any class that needs to notify others of 
changes should extend `TomObservable`.

```dart
class Counter extends TomObservable {
  int _count = 0;
  
  int get count => _count;
  
  void increment() {
    _count++;
    notifyObservers();  // Notify all registered observers
  }
  
  void reset() {
    _count = 0;
    notifyObservers("reset");  // Optional message
  }
}
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isMuted` | `bool` | Returns `true` if notifications are currently muted |

#### Methods

| Method | Description |
|--------|-------------|
| `addObserver(TomObserver observer)` | Registers an observer to receive notifications |
| `removeObserver(TomObserver observer)` | Unregisters an observer |
| `notifyObservers([String? message])` | Notifies all registered observers of a change |
| `batch<T>(T Function() body)` | Runs `body` with notifications suppressed, releasing even if it throws; returns the body's result |
| `batchSelf<T>(T Function() body)` | Like `batch`, but suppresses this object only — the members stay audible |
| `mute()` | Suppresses notifications; nests, so each call needs one `unmute()` |
| `unmute()` | Releases one `mute()`; notifies once when the last one is released and something changed |

| Getter | Type | Description |
|--------|------|-------------|
| `muteCascadeTargets` | `Iterable<TomObservable>` | The members `mute()` cascades to. Empty here; the composites override it |

#### Memory Management

`TomObservable` uses `WeakReference` for storing observers. This means:
- Observers that are garbage-collected are automatically cleaned up
- No need to manually remove observers in most cases
- Prevents memory leaks in long-running applications

```dart
void setupObserver() {
  final counter = Counter();
  
  // This observer will be cleaned up when it goes out of scope
  final observer = CounterObserver();
  counter.addObserver(observer);
}
// When observer is garbage collected, counter automatically removes it
```

### TomObserver

An abstract interface for objects that want to observe changes in a `TomObservable`.

```dart
class CounterDisplay implements TomObserver<Counter> {
  int _lastSeenValue = 0;
  
  @override
  void onNotify(Counter observable) {
    _lastSeenValue = observable.count;
    print('Counter is now: $_lastSeenValue');
  }
}

void main() {
  final counter = Counter();
  final display = CounterDisplay();
  
  counter.addObserver(display);
  
  counter.increment();  // Prints: "Counter is now: 1"
  counter.increment();  // Prints: "Counter is now: 2"
}
```

#### Type Parameter

The type parameter `T extends TomObservable` specifies what type of observable
this observer can observe. This provides type safety:

```dart
// This observer can only observe Counter objects
class CounterObserver implements TomObserver<Counter> {
  @override
  void onNotify(Counter observable) {
    print('Counter: ${observable.count}');
  }
}

// This observer can observe any TomObservable
class GenericObserver implements TomObserver<TomObservable> {
  @override
  void onNotify(TomObservable observable) {
    print('Something changed!');
  }
}
```

### TomFunctionObserver

A wrapper that allows using a callback function as a `TomObserver`. This is what
enables the `>>` operator syntax.

```dart
// These are equivalent:
counter >> (obs) => print('Changed!');

// Manually creating a TomFunctionObserver:
final observer = TomFunctionObserver<Counter>((obs) => print('Changed!'));
counter.addObserver(observer);
```

#### Keeping References

The `>>` operator returns the `TomFunctionObserver` so you can keep a reference
and later remove it:

```dart
final counter = Counter();

// Keep the reference
final observer = counter >> (obs) => print('Changed!');

// Later, remove the observer
counter.removeObserver(observer);
```

## Operators

The observable system uses custom operators for a clean, expressive API:

| Operator | Usage | Description |
|----------|-------|-------------|
| `~` | `~observable` | Get the current value (prefix unary operator) |
| `()` | `observable()` | Get the current value (call operator) |
| `\|` | `observable \| value` | Set the value and notify observers |
| `>>` | `observable >> callback` | Add a callback function as an observer |

### Operator Examples

```dart
final name = TomString("Hello");

// Get value - three equivalent ways
String value1 = ~name;          // Using ~ operator
String value2 = name();         // Using () operator  
String value3 = name.get();     // Using get() method

// Set value
name | "World";                 // Sets value and notifies observers
name.set("World");              // Equivalent using method

// Subscribe to changes
name >> (obs) => print("Changed to: ${~name}");

// Combined example
final counter = TomInt(0);
counter >> (obs) => print("Counter: ${~counter}");
counter | (~counter + 1);  // Increment: Prints "Counter: 1"
counter | (~counter + 1);  // Increment: Prints "Counter: 2"
```

## Observable Primitives

### TomObject&lt;T&gt; (Base Class)

All observable types extend `TomObject<T>`, which provides:

```dart
abstract class TomObject<T> extends TomObservable {
  T _value;
  
  // Core methods
  T get();                    // Get current value
  T call();                   // Get current value (call operator)
  T set(T value);             // Set value and notify
  T? getOrNull();             // Get value or null
  bool get isNull;            // Check if value is null
  
  // Operators
  T operator ~();             // Get value (prefix)
  T operator |(T value);      // Set value
  TomFunctionObserver<...> operator >>(Function callback);  // Subscribe
}
```

### Non-Nullable Types

| Class | Wraps | Default Value |
|-------|-------|---------------|
| `TomString` | `String` | `""` |
| `TomInt` | `int` | `0` |
| `TomDouble` | `double` | `0.0` |
| `TomBool` | `bool` | `false` |
| `TomDateTime` | `DateTime` | Current time |

```dart
// Creating observable primitives
final name = TomString("John");
final age = TomInt(30);
final salary = TomDouble(50000.0);
final isActive = TomBool(true);
final createdAt = TomDateTime(DateTime.now());

// Using them
print(~name);              // "John"
print(~age);               // 30
print(~salary);            // 50000.0
print(~isActive);          // true
print(~createdAt);         // 2024-01-15 10:30:00.000

// Modifying
name | "Jane";
age | 31;
salary | 55000.0;
isActive | false;
createdAt | DateTime(2025, 1, 1);
```

### Nullable Types

| Class | Wraps | Default Value |
|-------|-------|---------------|
| `TomNString` | `String?` | `null` |
| `TomNInt` | `int?` | `null` |
| `TomNDouble` | `double?` | `null` |
| `TomNBool` | `bool?` | `null` |
| `TomNDateTime` | `DateTime?` | `null` |

```dart
// Nullable types can hold null values
final middleName = TomNString(null);
final score = TomNInt(null);

// Check for null
if (middleName.isNull) {
  print("No middle name");
}

// Safe access
String? name = middleName.getOrNull();
int? scoreValue = score.getOrNull();

// Set to a value or back to null
middleName | "Robert";
middleName | null;  // Back to null
```

## DateTime and Timezone Types

### Basic DateTime

`TomDateTime` and `TomNDateTime` wrap standard Dart `DateTime` objects:

```dart
final timestamp = TomDateTime(DateTime.now());
final nullableDate = TomNDateTime(null);

// Serialize to string (ISO 8601 format)
String serialized = (~timestamp).toIso8601String();

// The serialization prefix is @!@
print(TomDateTime.serializationPrefix);  // "@!@"
```

### Timezone-Aware Types

For applications requiring timezone support, use the `TomZoned*` types:

| Observable Type | Underlying Type | Prefix |
|----------------|-----------------|--------|
| `TomOZonedDate` | `TomZonedDate` | `@D@` |
| `TomOZonedTime` | `TomZonedTime` | `@T@` |
| `TomOZonedDateTime` | `TomZonedDateTime` | `@X@` |

```dart
// Create timezone-aware observable
final meetingTime = TomOZonedDateTime(TomZonedDateTime(
  year: 2024,
  month: 6,
  day: 15,
  hour: 14,
  minute: 30,
  timezone: TomTimezone.fromName('America/New_York'),
));

// Subscribe to changes
meetingTime >> (obs) => print("Meeting time changed!");

// Get the value
TomZonedDateTime time = ~meetingTime;
print(time.timezone.name);  // "America/New_York"
print(time.hour);           // 14
```

#### Nullable Timezone Types

| Observable Type | Underlying Type | Description |
|----------------|-----------------|-------------|
| `TomNOZonedDate` | `TomZonedDate?` | Nullable date with timezone |
| `TomNOZonedTime` | `TomZonedTime?` | Nullable time with timezone |
| `TomNOZonedDateTime` | `TomZonedDateTime?` | Nullable datetime with timezone |

```dart
final deadline = TomNOZonedDateTime(null);

// Check if set
if (deadline.isNull) {
  print("No deadline set");
}

// Set a value
deadline | TomZonedDateTime(
  year: 2024, month: 12, day: 31,
  hour: 23, minute: 59,
  timezone: TomTimezone.utc,
);

// Set from serialized string
deadline.setByString("@X@2024-12-31T23:59:00.000Z_Z_UTC ");
```

### Range Types

For representing date/time ranges, use the range types which extend `TomClass`:

| Class | Start Field | End Field | Field Type |
|-------|-------------|-----------|------------|
| `TomDateRange` | `startDate` | `endDate` | `TomNOZonedDate` |
| `TomTimeRange` | `startTime` | `endTime` | `TomNOZonedTime` |
| `TomDateTimeRange` | `startDateTime` | `endDateTime` | `TomNOZonedDateTime` |

```dart
@tomReflector
class Event extends TomClass {
  TomString name = TomString("");
  TomDateTimeRange duration = TomDateTimeRange();
}

final event = Event();
event.name | "Conference";

// Set range values
event.duration.startDateTime | TomZonedDateTime(
  year: 2024, month: 6, day: 15, hour: 9, minute: 0,
  timezone: TomTimezone.utc,
);
event.duration.endDateTime | TomZonedDateTime(
  year: 2024, month: 6, day: 17, hour: 17, minute: 0,
  timezone: TomTimezone.utc,
);

// Subscribe to event changes (includes range changes)
event >> (obs) => print("Event modified!");
```

## TomClass (Observable Objects)

`TomClass` is a powerful base class for creating observable domain objects with 
automatic member observation and JSON serialization.

### Basic Usage

```dart
@tomReflector
class Person extends TomClass {
  TomString name = TomString("");
  TomInt age = TomInt(0);
  TomNString email = TomNString(null);
  TomBool isActive = TomBool(true);
}

void main() {
  final person = Person();
  
  // Observe any change to the person
  int notifyCount = 0;
  person >> (obs) => notifyCount++;
  
  // Set individual fields
  person.name | "Alice";
  person.age | 30;
  person.email | "alice@example.com";
  
  print(notifyCount);  // 3 - one notification per change
  
  // Get all values as a map
  Map<String, dynamic> values = person.getValues();
  print(values);  // {name: Alice, age: 30, email: alice@example.com, isActive: true}
}
```

### Automatic Member Registration

When a `TomClass` is instantiated, it uses reflection to:
1. Discover all `TomObject` fields
2. Register itself as an observer on each field
3. Propagate changes from any field to observers of the `TomClass`

```dart
@tomReflector
class Address extends TomClass {
  TomString street = TomString("");
  TomString city = TomString("");
  TomString zipCode = TomString("");
}

@tomReflector
class Customer extends TomClass {
  TomString name = TomString("");
  Address address = Address();  // Nested TomClass
}

void main() {
  final customer = Customer();
  
  // Observe customer - gets notified for nested changes too!
  customer >> (obs) => print("Customer changed!");
  
  customer.name | "Acme Corp";        // Prints: "Customer changed!"
  customer.address.city | "New York"; // Prints: "Customer changed!"
}
```

### Key Methods

| Method | Description |
|--------|-------------|
| `getMembers()` | Returns a map of all registered `TomObject` members |
| `setValues(Map<String, dynamic>)` | Bulk update multiple fields at once |
| `setOrMergeValues(Map<String, dynamic>)` | Update or merge with existing values |
| `getValues()` | Returns all members as a `Map<String, dynamic>` |
| `toJson()` | Serializes to JSON-compatible map (same as `getValues()`) |
| `fromJson(String json)` | Deserializes from JSON string |

### Bulk Updates with setValues

```dart
final person = Person();

// Set multiple values at once
person.setValues({
  'name': 'Bob',
  'age': 25,
  'email': 'bob@example.com',
  'isActive': false,
});

print(~person.name);     // "Bob"
print(~person.age);      // 25
print(~person.email);    // "bob@example.com"
print(~person.isActive); // false
```

#### When a value has the wrong shape

The input is usually decoded JSON, so a mistyped value is an ordinary event,
not a programming error. Two guarantees apply:

**The object stays usable.** `setValues` runs inside a `batch()`, which
releases in a `finally`. A rejected value therefore cannot leave the object —
or the members the batch cascades to — permanently silent. Whatever was applied
before the failure is announced at that point: the object *has* changed, and
hiding it would be worse than reporting a partial update.

**The error says which key.** Every failure surfaces as a
`TomObservableException` naming the offending key and the runtime type actually
supplied, with both repeated in `parameters` for programmatic handling:

```dart
try {
  person.setValues({'age': 'not a number'});
} on TomObservableException catch (e) {
  print(e.defaultUserMessage);
  // Failed to set TomClass member 'age' from a String: type 'String' is not …
  print(e.parameters);        // {key: age, valueType: String}
}
```

For a `TomList` member the report is per element, and it is raised *before* the
list is touched — so a payload with one bad entry does not empty the member it
failed to replace:

```dart
item.setValues({'tags': ['a', 'b']});
try {
  item.setValues({'tags': ['c', 42]});    // 42 is not a TomString
} on TomObservableException catch (e) {
  print(e.defaultUserMessage);
  // TomList member 'tags' element 1 cannot be deserialized from an int:
  // that yields a TomInt, but the list holds TomString
}
print(item.tags.map((e) => ~e));  // (a, b) — unchanged
```

### Numbers: Integers Widen Into Double Destinations

JSON has a single number type, so a producer is free to write `20` where the
schema says `double` — JavaScript's `JSON.stringify(20.0)` does exactly that.
An integral value arriving at a double-holding destination is therefore widened
rather than rejected, whether the destination is a field, a list element or a
map value:

```dart
final item = PricedItem();          // price: TomDouble, rates: TomList<TomDouble>

item.setValues({'price': 20, 'rates': [1, 2]});

print(item.price.get());            // 20.0  — a double, not an int
print(item.rates.map((e) => ~e));   // (1.0, 2.0)
```

The widening is keyed on the *destination*, not on the value, so integers that
are meant to stay integers do:

```dart
item.setValues({'quantity': 7, 'counts': [1, 2]});   // TomInt, TomList<TomInt>

print(item.quantity.get() is int);  // true
```

It is also one-directional. Widening `int` to `double` is lossless; narrowing
is not, so a fractional value offered to an integer destination is refused with
the usual `TomObservableException` rather than silently truncated:

```dart
item.setValues({'quantity': 2.5});
// TomObservableException: Failed to set TomClass member 'quantity' from a
// double: type 'double' is not a subtype of type 'int' of 'value'
```

### JSON Serialization

```dart
final person = Person();
person.name | "Charlie";
person.age | 35;

// Serialize to JSON
Map<String, dynamic> jsonMap = person.toJson();
print(jsonMap);  // {name: Charlie, age: 35, email: null, isActive: true}

// Deserialize from JSON
final person2 = Person();
person2.fromJson('{"name": "Diana", "age": 28}');
print(~person2.name);  // "Diana"
print(~person2.age);   // 28
```

## The Collection Notification Contract

`TomList` and `TomMap` obey one rule, and it is worth stating before the
individual operations:

> **A mutator notifies exactly once when it changed the collection's contents,
> and not at all when it left them as they were.**

So `clear()` on an empty list is silent, `addAll([])` is silent, `sort()` on an
already-sorted list is silent, `map.remove(key)` for an absent key is silent —
while `map.remove(key)` for a *present* key notifies once:

```dart
final map = TomMap<String, TomInt>();
map['a'] = TomInt(1);

int notifications = 0;
map >> (obs) => notifications++;

map.remove('missing');
print(notifications);  // 0 — nothing changed

map.remove('a');
print(notifications);  // 1 — an entry went away
```

```dart
final list = TomList<TomInt>();
list.addAll([TomInt(1), TomInt(2), TomInt(3)]);

int notifications = 0;
list >> (obs) => notifications++;

list.addAll([]);                            // 0 — nothing to add
list.sort((a, b) => (~a).compareTo(~b));    // 0 — already in order
list[0] = list[0];                          // 0 — same element
list.length = 3;                            // 0 — already that long
print(notifications);  // 0

list.length = 2;       // truncation drops an element
print(notifications);  // 1
```

**"Contents" means references, compared by identity.** Replacing an element
with an equal-but-distinct one *is* a change, because observers hold references
to what they were given:

```dart
list[0] = TomInt(~list[0]);  // notifies: same number, different object
```

**A change *inside* an element is not a mutator's business.** It reaches
observers by propagation instead (see *Element Change Propagation* below), which
is why the contract can talk about references alone.

Why the rule is worth the guards: an observer is typically a UI rebuild or a
write-back handler, so a notification that reports no change is not merely
noise — it is real work, and in a write-back loop it can be a cycle.

Two consequences follow for the collection API:

- **`resetWith` is the one deliberate exception**: it notifies even when the
  new contents equal the old ones, because its lifecycle listeners have already
  torn down and rebuilt whatever they held per element.
- **`TomList.length` cannot be used to grow a list.** A `TomList` holds
  non-nullable elements, so there is nothing to pad with; assigning a larger
  length throws a `TomObservableException` naming the list's current and
  requested length. Use `add`, `addAll` or `insert`.

## TomList (Observable Lists)

`TomList<E>` is an observable list that notifies observers when:
- Elements are added, removed, or replaced
- Any contained element changes (if the element is a `TomObject`)

### Creating TomList

```dart
// Empty list
final names = TomList<TomString>();

// From existing TomList
final names2 = TomList.from(names);
final names3 = TomList.of(names);

// From standard List
final names4 = TomList.ofList([TomString("Alice"), TomString("Bob")]);
```

### List Operations

```dart
final items = TomList<TomInt>();

// Add elements
items.add(TomInt(10));
items.addAll([TomInt(20), TomInt(30)]);
items.insert(0, TomInt(5));

// Access elements
print(~items[0]);     // 5
print(items.length);  // 4
print(items.first);   // TomInt(5)
print(items.last);    // TomInt(30)

// Modify elements
items[0] | 100;       // Set via operator
items[0] = TomInt(1); // Replace element

// Remove elements. `remove` takes the element itself: TomObject does not
// override `==`, so `remove(TomInt(20))` would match nothing, return false
// and — per the notification contract — stay silent.
final twenty = items[1];
items.removeAt(0);
items.removeLast();
items.remove(twenty);
items.clear();

// Iteration
for (final item in items) {
  print(~item);
}

// Functional operations
final doubled = items.map((e) => TomInt(~e * 2));
final filtered = items.where((e) => ~e > 10);
```

### Concatenation

```dart
final list1 = TomList<TomInt>();
list1.addAll([TomInt(1), TomInt(2)]);

final list2 = TomList<TomInt>();
list2.addAll([TomInt(3), TomInt(4)]);

// Concatenate using + operator
final combined = list1 + list2;  // [1, 2, 3, 4]
```

### Element Change Propagation

```dart
@tomReflector
class Task extends TomClass {
  TomString title = TomString("");
  TomBool completed = TomBool(false);
}

final tasks = TomList<Task>();
int listNotifications = 0;
tasks >> (obs) => listNotifications++;

// Add a task
tasks.add(Task()..title | "Buy groceries");
print(listNotifications);  // 1

// Modify the task's title - list is notified!
tasks[0].title | "Buy organic groceries";
print(listNotifications);  // 2

// Mark as completed - list is notified again!
tasks[0].completed | true;
print(listNotifications);  // 3
```

### Atomic Replacement with resetWith

`resetWith(Iterable<E>)` replaces the **entire** contents of a `TomList` in a
single operation and sends exactly **one** notification afterwards. It detaches
the list's observer from the old elements, clears them, attaches to and installs
the new elements, then notifies:

```dart
final rows = TomList<Task>();
rows.addAll([Task()..title | 'a', Task()..title | 'b']);

int notifications = 0;
rows >> (obs) => notifications++;

// Swap all contents in one shot — a single notification, not one per element.
rows.resetWith([Task()..title | 'x', Task()..title | 'y']);
print(notifications);  // 1
```

This is the path `TomClass` uses internally when a parent form writes a bind-time
snapshot back via `setValues()` — the list member's contents are swapped
wholesale rather than diffed.

### Lifecycle Listeners

`TomListLifecycleListener` lets observers tear down and recreate state that is
tied to the *identity* of list elements around a `resetWith` replacement. It is
the mechanism `TomListForm` (in `tom_flutter_ui`) uses to keep its per-row
sub-form instances in sync when the backing list is replaced.

| Hook | When it fires |
| ---- | ------------- |
| `onBeforeClear(list)` | Immediately **before** the old elements are removed (list still intact — safe to read for cleanup) |
| `onAfterReset(list)` | Immediately **after** the new elements are installed (list fully populated — safe to read to recreate state) |

```dart
class RowFormSync extends TomListLifecycleListener {
  @override
  void onBeforeClear(TomList list) {
    // dispose sub-forms bound to the outgoing rows
  }
  @override
  void onAfterReset(TomList list) {
    // build sub-forms for the incoming rows
  }
}

final rows = TomList<Task>();
rows.addLifecycleListener(RowFormSync());
// ... later
rows.removeLifecycleListener(listener);
```

Both `resetWith` and `notifyObservers` snapshot their listener/observer lists
before iterating, so a listener or observer callback may itself add or remove
listeners/observers without triggering a `ConcurrentModificationError`.

## TomMap (Observable Maps)

`TomMap<K, V>` is an observable map that notifies observers when:
- Entries are added, removed, or replaced
- Any contained value changes (if the value is a `TomObject`)

### Creating TomMap

```dart
// Empty map
final scores = TomMap<String, TomInt>();

// From existing TomMap
final scores2 = TomMap.from(scores);
final scores3 = TomMap.of(scores);

// From standard Map
final scores4 = TomMap.ofMap({
  'alice': TomInt(100),
  'bob': TomInt(85),
});
```

### Map Operations

```dart
final config = TomMap<String, TomString>();

// Add entries
config['host'] = TomString('localhost');
config['port'] = TomString('8080');
config.addAll({
  'protocol': TomString('https'),
  'path': TomString('/api'),
});

// Access entries
print(~config['host']!);     // "localhost"
print(config.length);         // 4
print(config.keys);           // (host, port, protocol, path)
print(config.containsKey('host'));  // true

// Modify values
config['host']! | 'example.com';

// Remove entries
config.remove('path');
config.removeWhere((k, v) => ~v == 'https');
config.clear();

// Iteration
config.forEach((key, value) {
  print('$key: ${~value}');
});
```

### Merging Maps

```dart
final map1 = TomMap<String, TomInt>();
map1['a'] = TomInt(1);
map1['b'] = TomInt(2);

final map2 = TomMap<String, TomInt>();
map2['c'] = TomInt(3);
map2['d'] = TomInt(4);

// Merge using + operator
final merged = map1 + map2;  // {a: 1, b: 2, c: 3, d: 4}
```

### Value Change Propagation

```dart
@tomReflector
class User extends TomClass {
  TomString name = TomString("");
  TomInt score = TomInt(0);
}

final users = TomMap<String, User>();
int mapNotifications = 0;
users >> (obs) => mapNotifications++;

// Add a user
users['alice'] = User()..name | "Alice";
print(mapNotifications);  // 1

// Modify the user's score - map is notified!
users['alice']!.score | 100;
print(mapNotifications);  // 2
```

### Restriction: Cannot Replace Entire Map

Unlike regular maps, you cannot replace the entire contents at once using `set()`:

```dart
final map = TomMap<String, TomInt>();

// This throws TomObservableException
// map.set({'a': TomInt(1)});  // ✗ Not allowed

// Instead, clear and add new entries
map.clear();
map.addAll({'a': TomInt(1)});  // ✓ OK

// Or replace in one shot with <<, which is a single notification rather
// than the two the clear/addAll pair produces.
map << {'a': TomInt(1)};       // ✓ OK
```

## TomObservableEnum (Resource-Keyed Enums)

`TomObservableEnum<E extends Enum>` is an ordinary `TomObject` holding an enum
value, with one addition: it also resolves that value to display text through
the application's text resource bundle. Enums therefore carry **no Dart-side
label table** — no `extension TodoStatusText on TodoStatus { String get text …
}`. The strings a user sees are the ones the server sent.

```dart
enum TodoStatus { open, inReview, done }

final status = TomObservableEnum(TodoStatus.open, values: TodoStatus.values);

print(~status);              // TodoStatus.open  — the value, as usual
print(status.displayText);   // 'Open'           — resolved from the bundle
print(status.displayTexts);  // ['Open', 'In review', 'Done']

status | TodoStatus.done;
print(status.displayText);   // 'Done'
```

The `values` argument is the enum's value list. It is what a picker enumerates
to build its options; Dart cannot recover `E.values` from a type parameter, so
it has to be passed.

### Resource Keys and Scope

The key for a value is `<scope>.<enumName>.<value>`, all lower case:

```json
{
  "global": {
    "todostatus": { "open": "Open", "inreview": "In review", "done": "Done" }
  }
}
```

The scope segment is **implicit** — it comes from the ambient `TomScope`, never
from an argument at the call site, and there is no class cataloguing keys as
constants. Resolution walks the scope chain from most specific to least
specific and ends at `global`, so a label declared once under `global` works
everywhere while a single scope can override just the labels it cares about:

```dart
TomScope.withScope('checkout', () {
  final status = TomObservableEnum(TodoStatus.open, values: TodoStatus.values);

  // Tries, in order:
  //   checkout.todostatus.open
  //   global.todostatus.open
  //   → else the raw name 'open'
  print(status.displayText);
  print(status.displayKey);   // whichever key resolved
});
```

In the default root scope the chain is the single key
`global.todostatus.open`.

The scope is captured **when the cell is constructed**, not when its text is
read: display resolution frequently happens inside a Flutter builder callback,
which runs outside the zone that installed the scope. Pass `scope:` explicitly
only when the cell must be built outside the scope whose labels it should use.

### Locale Changes

A cell notifies its observers when *either* the value **or** the installed
bundle changes. Switching locale therefore re-renders anything bound to it,
with no rebuild on the caller's side:

```dart
final status = TomObservableEnum(TodoStatus.inReview, values: TodoStatus.values);

// Retain the observer — observers are held weakly.
final observer = status >> (_) => print(status.displayText);

TomTextResourceProvider.setAppResourceProvider(germanBundle);  // 'In Prüfung'
```

The trigger is `TomTextResourceProvider.appResourcesRevision`, a `TomInt`
bumped whenever the installed provider — or its `resources` map — is replaced.
Mutating that map in place cannot be detected; call
`TomTextResourceProvider.notifyAppResourcesChanged()` after such an edit.

Call `detachFromResources()` to freeze a long-lived cell on the labels it
already has; value changes still notify.

### Missing Keys

A value with no key in the bundle degrades to its **raw enum name**
(`inReview` — recognisable, never blank) and logs a warning naming the keys
that were tried:

```text
WARN No enum label resource for global.todostatus.done
     (tried: global.todostatus.done) — rendering the raw enum name.
```

The warning is emitted once per key per bundle revision, so a missing label in
a thousand-row list does not flood the log, while a locale switch reports it
again. Degradation is per value: the labels that *are* present still resolve.

Use `TomObservableEnum.resolveTextOrNull` when the caller wants to supply its
own fallback rather than the raw name.

### In Forms

`tom_flutter_ui` exposes this as `TomEnumSelectableSource` and the
`enumPickerFor` family helper, which builds a dropdown whose options are
labelled from the bundle and which re-labels itself on a locale change:

```dart
family.enumPickerFor('status', TodoStatus.open, values: TodoStatus.values);
```

## Muting Notifications

When making multiple changes, you may want to suppress notifications until
all changes are complete. This is called "muting".

### Basic Muting

```dart
final person = Person();
int notifications = 0;
person >> (obs) => notifications++;

// Without muting: 3 notifications
person.name | "Alice";
person.age | 30;
person.email | "alice@example.com";
print(notifications);  // 3

// With muting: 1 notification
notifications = 0;
person.mute();
person.name | "Bob";
person.age | 25;
person.email | "bob@example.com";
person.unmute();  // Triggers single notification
print(notifications);  // 1
```

### How Muting Works

1. `mute()` increments a mute counter, and cascades to the object's members
2. While the counter is above zero, `notifyObservers()` records the object as
   "dirty" instead of notifying
3. `unmute()` releases the members this mute silenced, then decrements
4. When the counter reaches zero, a dirty object sends a single notification

### Batches Nest

The mute is a **counter, not a flag**. Each `mute()` must be matched by exactly
one `unmute()`, and notifications resume only when the outermost one is
released:

```dart
person.mute();
person.mute();

person.name | "Bob";

person.unmute();  // inner release: still muted, still silent
print(person.isMuted);  // true

person.unmute();  // outer release: one notification
```

This is what makes the framework's own batching methods safe to call from
inside your batch. `setValues`, `replaceRange` and `TomMap.update` all mute
while they work; because mutes nest, doing so suppresses their own intermediate
notifications without releasing yours:

```dart
order.batch(() {
  order.setValues({'orderId': 'ORD-001'});  // batches internally
  order.total | 99.99;
});  // still exactly one notification
```

Releasing more often than you muted is a no-op rather than an error — the
counter floors at zero, so a stray `unmute()` cannot leave the object in a
state where the next batch fails to suppress.

### Cascading to Members

For `TomClass`, `TomList`, and `TomMap`, muting propagates to children:

```dart
@tomReflector
class Order extends TomClass {
  TomString orderId = TomString("");
  TomList<OrderItem> items = TomList();
  TomDouble total = TomDouble(0.0);
}

final order = Order();
int notifications = 0;
order >> (obs) => notifications++;

order.mute();

// All these changes are batched
order.orderId | "ORD-001";
order.items.add(OrderItem()..name | "Widget");
order.items.add(OrderItem()..name | "Gadget");
order.total | 99.99;

order.unmute();  // Single notification for all changes
print(notifications);  // 1
```

### Prefer `batch()` over `mute()` / `unmute()`

An unreleased mute is not a lost notification — it is an object that never
notifies again, because nothing outside `unmute()` decrements the counter. Use
`batch()`, which releases in a `finally`, and the mistake becomes unavailable:

```dart
void performBatchUpdate(Person person) {
  person.batch(() {
    person.name | "Updated Name";
    person.age | 30;
    // ... more updates
  });  // released even if an update throws
}
```

`batch()` returns whatever its body returns, so it wraps an expression as
readily as a statement:

```dart
final count = order.batch(() {
  order.items.addAll(newItems);
  return order.items.length;
});
```

The framework's own batching uses it: `TomClass.setOrMergeValues` (and
therefore `setValues` / `fromJson`) runs inside a `batch()`, and
`TomList.replaceRange` and `TomMap.update` / `updateAll` inside a `batchSelf()`.

### `batchSelf()` — consolidating without silencing the members

`batch()` cascades: it mutes the members too, so nothing inside the object is
heard from until the batch ends. That is the right default for a caller
assembling a set of edits, but the wrong one for a mutator that only wants to
merge *its own* notifications.

`batchSelf()` mutes the container alone. `TomList.replaceRange` uses it so that
its internal remove-then-insert surfaces as one notification from the list,
while observers watching an individual element still hear about that element
when it changes:

```dart
list.batchSelf(() {
  // list is muted; its elements are not
});
```

Reach for `batch()` unless you are writing a container mutator and have a
reason to leave the elements audible.

## Error Handling

The system throws `TomObservableException` for observable-related errors:

```dart
try {
  final map = TomMap<String, TomInt>();
  map.set({'key': TomInt(1)});  // Not allowed
} on TomObservableException catch (e) {
  print('Error key: ${e.key}');
  print('Message: ${e.defaultUserMessage}');
}
```

### Common Error Keys

| Error Key | Description |
|-----------|-------------|
| `TomClass.state_error.set_not_allowed` | Cannot set entire TomClass value |
| `TomMap.set.not_allowed` | Cannot replace entire map |
| `TomClass.set_list_member_error.not_a_list` | Expected list for TomList member |

## Class Hierarchy

```
TomObserver<T> (interface)
├── TomFunctionObserver<T>  — Wraps callback functions as observers
├── TomClass                — Observes its own members
├── TomList<E>              — Observes its elements
└── TomMap<K, V>            — Observes its values

TomObservable (base class)
└── TomObject<T>
    ├── TomString, TomInt, TomDouble, TomBool, TomDateTime
    ├── TomNString, TomNInt, TomNDouble, TomNBool, TomNDateTime
    ├── TomObservableEnum<E>     — display text resolved from the text bundle
    ├── TomOTimezoned<TZ>
    │   ├── TomOZonedTime, TomOZonedDate, TomOZonedDateTime
    │   └── TomNOTimezoned<TZ>
    │       └── TomNOZonedTime, TomNOZonedDate, TomNOZonedDateTime
    ├── TomClass (also implements TomObserver)
    │   ├── TomDateRange, TomTimeRange, TomDateTimeRange
    │   └── (user-defined domain objects)
    ├── TomList<E> (also implements TomObserver, List<E>)
    └── TomMap<K, V> (also implements TomObserver, Map<K, V>)
```

## Best Practices

### 1. Use Operators for Clean Code

Prefer operators over method calls for readability:

```dart
// ✓ Clean and idiomatic
name | "John";
String value = ~name;
name >> (obs) => print("Changed!");

// ✗ More verbose (but equivalent)
name.set("John");
String value = name.get();
name.addObserver(TomFunctionObserver((obs) => print("Changed!")));
```

### 2. Batch Multiple Changes

Wrap multiple changes in `batch()` so observers see one notification, not one
per field:

```dart
void updatePerson(Person person, Map<String, dynamic> data) {
  person.batch(() {
    if (data['name'] != null) person.name | data['name'];
    if (data['age'] != null) person.age | data['age'];
    if (data['email'] != null) person.email | data['email'];
  });
}
```

Use the raw `mute()` / `unmute()` pair only when the batch cannot be expressed
as a single block — and then release it in a `finally`.

### 3. Initialize Fields with Default Values

Always provide default values for `TomClass` fields:

```dart
@tomReflector
class Person extends TomClass {
  TomString name = TomString("");          // ✓ Good
  TomInt age = TomInt(0);                  // ✓ Good
  TomNString email = TomNString(null);     // ✓ Good for nullable
  TomList<Task> tasks = TomList();         // ✓ Good for collections
}
```

### 4. Use Typed TomList and TomMap

Always specify type parameters for type safety:

```dart
// ✓ Good - type safe
TomList<TomString> names = TomList<TomString>();
TomMap<String, TomInt> scores = TomMap<String, TomInt>();

// ✗ Avoid dynamic types
TomList<dynamic> items = TomList<dynamic>();
```

### 5. Keep Observer References if Needed Later

If you need to remove an observer later, keep the reference:

```dart
class MyWidget {
  late TomFunctionObserver<TomObservable> _observer;
  final Person _person;
  
  MyWidget(this._person) {
    _observer = _person >> (obs) => _onPersonChanged();
  }
  
  void dispose() {
    _person.removeObserver(_observer);
  }
  
  void _onPersonChanged() {
    // Handle change
  }
}
```

### 6. Annotate Classes with @tomReflector

All `TomClass` subclasses must be annotated for reflection to work:

```dart
@tomReflector  // ✓ Required
class Customer extends TomClass {
  TomString name = TomString("");
  Address address = Address();  // Address must also be annotated!
}

@tomReflector  // ✓ Required for nested class
class Address extends TomClass {
  TomString city = TomString("");
}
```

## Dependencies

The observable system depends on:

- **Reflection Module**: `@tomReflector` annotation for `TomClass` reflection
- **Timezoned Module**: `TomTimezoned`, `TomZonedDate`, `TomZonedTime`, `TomZonedDateTime`
- **Little Things Module**: Base `TomException` class for `TomObservableException`
