# Tom Framework Observer/Observable Architecture

This document describes the **Observer/Observable architecture** of the Tom framework, which implements the Observer pattern to enable reactive data binding. The architecture consists of two main files:

- `tom_observable.dart` — Base classes for the Observer pattern
- `tom_observable_objects.dart` — Observable wrapper types for values

---

## Base Classes (`tom_observable.dart`)

### `TomObservable`

The foundation of the observer pattern. Any class that needs to notify others of changes should extend `TomObservable`.

**Key Features:**
- Maintains a list of observers using `WeakReference` to prevent memory leaks
- Supports muting/unmuting notifications for batch updates
- Automatically cleans up garbage-collected observers

**Properties:**
- `isMuted` — Returns `true` if notifications are currently muted

**Methods:**
| Method | Description |
|--------|-------------|
| `addObserver(TomObserver)` | Registers an observer to receive notifications |
| `removeObserver(TomObserver)` | Unregisters an observer |
| `notifyObservers([message])` | Notifies all registered observers of a change |
| `mute()` | Temporarily suppresses notifications |
| `unmute()` | Resumes notifications (triggers if dirty) |

**Operators:**
| Operator | Description |
|----------|-------------|
| `observable >> callback` | Adds a callback function as an observer (returns `TomFunctionObserver`) |

**Example:**
```dart
class Counter extends TomObservable {
  int _count = 0;
  
  void increment() {
    _count++;
    notifyObservers();
  }
}
```

---

### `TomObserver<T extends TomObservable>`

An abstract interface for objects that want to observe changes in a `TomObservable`.

**Methods:**
| Method | Description |
|--------|-------------|
| `onNotify(T observable)` | Called when the observed object changes |

**Example:**
```dart
class CounterDisplay implements TomObserver<Counter> {
  @override
  void onNotify(Counter counter) {
    print('Counter changed!');
  }
}

final counter = Counter();
final display = CounterDisplay();
counter.addObserver(display);
counter.increment(); // Prints: "Counter changed!"
```

---

### `TomFunctionObserver<T extends TomObservable>`

A wrapper that allows using a callback function as a `TomObserver`. This enables the `>>` operator syntax.

**Example:**
```dart
final counter = Counter();
counter >> (obs) => print('Changed!'); // Uses TomFunctionObserver internally
```

---

## Observable Wrapper Types (`tom_observable_objects.dart`)

These types extend `TomObservable` and wrap values, automatically notifying observers when values change.

### `TomObservableException`
Custom exception class for observable-related errors, extending `TomException`.

### `TomObject<T>` (Base Class)
The generic observable wrapper that all other types extend.

**Key Features:**
- **Value storage**: Internal `_value` of type `T`
- **Operator overloads**:
  - `~obj` — get value (prefix operator)
  - `obj()` — get value (call operator)
  - `obj | newValue` — set value and notify observers
  - `obj >> callback` — observe changes (inherited from `TomObservable`)
- **Nullable access**: `getOrNull()`, `isNull` property
- **Observer integration**: Automatically notifies observers on value changes via `set()`

**Core Methods:**
- `T get()` — returns the current value
- `T call()` — returns the current value (call operator)
- `T set(T value)` — sets the value and notifies observers
- `T? getOrNull()` — returns value or null if unset; delegates to `get()`, so every override applies
- `bool get isNull` — checks if value is null

---

## Primitive Wrappers

| Class | Wraps | Description |
|-------|-------|-------------|
| `TomString` | `String` | Observable string wrapper |
| `TomInt` | `int` | Observable integer wrapper |
| `TomDouble` | `double` | Observable double wrapper |
| `TomBool` | `bool` | Observable boolean wrapper |
| `TomDateTime` | `DateTime` | Observable DateTime wrapper (serialization prefix: `@!@`) |

---

## Nullable Primitive Wrappers

| Class | Wraps | Description |
|-------|-------|-------------|
| `TomNString` | `String?` | Nullable string wrapper |
| `TomNInt` | `int?` | Nullable integer wrapper |
| `TomNDouble` | `double?` | Nullable double wrapper |
| `TomNBool` | `bool?` | Nullable boolean wrapper |
| `TomNDateTime` | `DateTime?` | Nullable DateTime wrapper |

---

## Resource-Keyed Enum Wrapper (`tom_observable_enum.dart`)

| Class | Wraps | Description |
|-------|-------|-------------|
| `TomObservableEnum<E extends Enum>` | `E` | Enum cell whose display text is resolved from the text bundle under `<scope>.<enumName>.<value>` |

| Member | Description |
|--------|-------------|
| `values` | The enum's value list, in declaration order (unmodifiable) |
| `scope` | The `TomScope` captured at construction, used for key resolution |
| `displayText` / `displayTextOf(v)` | Bundle text for the current value / for `v` |
| `displayKey` / `displayKeyOf(v)` | The key that resolved, else the `global` key |
| `displayTexts` | Bundle text for every entry of `values` |
| `detachFromResources()` | Stop reacting to bundle changes (value changes still notify) |
| `resourceKeysFor(v, {scope})` | The candidate keys, most specific scope first, ending at `global` |
| `resolveText(v, {scope})` | Bundle text, else the raw enum name (logs once per key per revision) |
| `resolveTextOrNull(v, {scope})` | Bundle text, else `null` — for a caller-supplied fallback |

Notifies on a **value change or a bundle change**; the bundle trigger is
`TomTextResourceProvider.appResourcesRevision`.

---

## Timezone-Aware Date/Time Types

### Non-Nullable

| Class | Wraps | Purpose |
|-------|-------|---------|
| `TomOTimezoned<TZ>` | `TomTimezoned` | Abstract base for timezone-aware observable types |
| `TomOZonedDate` | `TomZonedDate` | Observable date with timezone (prefix: `@D@`) |
| `TomOZonedTime` | `TomZonedTime` | Observable time with timezone (prefix: `@T@`) |
| `TomOZonedDateTime` | `TomZonedDateTime` | Observable datetime with timezone (prefix: `@X@`) |

**Common Methods:**
- `setByString(String s)` — sets the value by parsing a serialized string
- `getSerializationPrefix()` — returns the serialization prefix for this type

### Nullable

| Class | Wraps | Purpose |
|-------|-------|---------|
| `TomNOTimezoned<TZ>` | `TomTimezoned?` | Abstract nullable base for timezone types |
| `TomNOZonedDate` | `TomZonedDate?` | Nullable observable date with timezone |
| `TomNOZonedTime` | `TomZonedTime?` | Nullable observable time with timezone |
| `TomNOZonedDateTime` | `TomZonedDateTime?` | Nullable observable datetime with timezone |

Nullable types deserialize to `null` when the serialized string has only the prefix with no value.

---

## Range Types

| Class | Members | Purpose |
|-------|---------|---------|
| `TomDateRange` | `startDate`, `endDate` (`TomNOZonedDate`) | Observable start/end date pair |
| `TomTimeRange` | `startTime`, `endTime` (`TomNOZonedTime`) | Observable start/end time pair |
| `TomDateTimeRange` | `startDateTime`, `endDateTime` (`TomNOZonedDateTime`) | Observable start/end datetime pair |

All range types extend `TomClass` and their members are automatically registered for observation via reflection. Both ends of a fresh range hold the "no value" sentinel of the matching type.

---

## "No Value" Sentinels

Placeholders for code that needs a "not set" marker but cannot use `null`. Each type offers a **plain** sentinel (the bare value) and an **observable** one (already wrapped).

| Type | Plain | Observable |
|------|-------|------------|
| `TomDateTime` / `TomNDateTime` | — | `noDateTime` |
| `TomOTimezoned` / `TomNOTimezoned` | — | `noDateTime` |
| `TomOZonedTime` / `TomNOZonedTime` | `noZonedTime` | `noTime` |
| `TomOZonedDate` / `TomNOZonedDate` | `noZonedDate` | `noTime` |
| `TomOZonedDateTime` / `TomNOZonedDateTime` | `noZonedDateTime` | `noTime` |

**All sentinels denote the same instant — the Unix epoch in UTC.**

- Built from `DateTime.utc(1970)`, never `DateTime(1970)`: a local-time epoch would shift with the reader's zone, so a comparison would depend on where it runs and a persisted "no value" would become a real date when it crossed zones
- The plain and observable families are interchangeable: `TomOZonedDate.noZonedDate == TomOZonedDate.noTime.get()`
- Compare with `value.toUtc() == DateTime.utc(1970)`
- The two spellings are indistinguishable under `TZ=UTC`, so use `tool/run_tz_matrix.sh` to exercise the suite across zones

---

## `TomClass` (Complex Observable Object)

A powerful base class for creating observable domain objects with automatic member observation and JSON serialization.

**Key Features:**

### Automatic Member Registration
- Uses reflection to discover all `TomObject` fields
- Members are automatically registered and observed in the constructor
- `getMembers()` — returns a **read-only, live** view of all registered `TomObject` members; mutating it throws `UnsupportedError`, and members registered later appear in a view taken earlier
- `getOrNull()` — throws, exactly as `get()` does: a `TomClass` has no scalar value to hand out

### Self-Observation
- `startSelfObservation()` — registers this class as observer on all members (called automatically)
- Implements `TomObserver` interface
- Changes to any member notify the parent `TomClass`

### Value Operations
- `setValues(Map<String, dynamic>)` — bulk update multiple fields
- `setOrMergeValues(Map<String, dynamic>)` — update or merge with existing values
- `getValues()` — returns all registered members as a `Map<String, dynamic>`
- Timezone-aware members are dispatched to `setByString` before the plain-`DateTime` handling — `TomTimezoned` extends `DateTime`, so a zoned member also satisfies `TomObject<DateTime?>` and would otherwise reach `DateTime.parse` with its `@D@`/`@T@`/`@X@` prefix attached
- `getValues()` output round-trips back through `setValues()`, zoned members included

### JSON Serialization
- `toJson()` — serializes object to JSON-compatible Map (calls `getValues()`)
- `fromJson(String json)` — deserializes from JSON string
- Uses `@tomReflector` annotation for reflection support

---

## `TomList<E extends TomObject>`

An observable list implementation that automatically observes all contained elements.

**Key Features:**
- Implements the full `List<E>` interface
- Uses `@tomReflector` annotation for reflection
- Automatically observes all contained elements
- Notifies observers on any list modification

**Constructors:**
- `TomList()` — creates empty list
- `TomList.from(TomList<E>)` — creates from existing TomList
- `TomList.of(TomList<E>)` — creates copy of existing TomList
- `TomList.ofList(List<E>)` — creates from standard List

**Observer Management:**
- `_attachTo(Iterable<E>)` — adds this list as observer to all elements
- `_detachFrom(Iterable<E>)` — removes this list as observer from elements

**All Standard List Operations:**
- `add()`, `addAll()`, `insert()`, `insertAll()`
- `remove()`, `removeAt()`, `removeLast()`, `removeRange()`, `removeWhere()`
- `clear()`, `sort()`, `shuffle()`
- `operator []`, `operator []=`
- `operator +` — concatenates two TomLists
- Iterable methods: `map()`, `where()`, `fold()`, `expand()`, etc.

**Structural Replacement:**
- `resetWith(Iterable<E>)` — atomically replaces all contents with a single notification
- `addLifecycleListener(TomListLifecycleListener)` / `removeLifecycleListener(...)` — register hooks around `resetWith`

**Read-only Accessors:**
- `get()` / `getOrNull()` — return a **copy** of the elements; writing to it changes nothing
- `cast<R>()` — a **live, read-only** re-typed view; writing to it throws `UnsupportedError`

**Static Methods:**
- `TomList.castFrom<S, E>()` — casts list element types

---

## `TomListLifecycleListener`

Listener for structural reset events on a `TomList` (fired around `resetWith`).

- `onBeforeClear(TomList)` — before the old elements are removed (list still intact)
- `onAfterReset(TomList)` — after the new elements are installed (list fully populated)

---

## `TomMap<K, V extends TomObject>`

An observable map implementation that automatically observes all contained values.

**Key Features:**
- Provides full Map interface
- Uses `@tomReflector` annotation for reflection
- Automatically observes all values (not keys)
- Notifies observers on any map modification

**Constructors:**
- `TomMap()` — creates empty map
- `TomMap.from(TomMap<K, V>)` — creates from existing TomMap
- `TomMap.of(TomMap<K, V>)` — creates copy of existing TomMap
- `TomMap.ofMap(Map<K, V>)` — creates from standard Map

**Restrictions:**
- `set()` throws `TomObservableException` — cannot replace entire map, only individual elements

**Observer Management:**
- `_attachTo(Iterable<V>)` — adds this map as observer to all values
- `_detachFrom(Iterable<V>)` — removes this map as observer from values

**All Standard Map Operations:**
- `operator []`, `operator []=`
- `operator +` — merges two TomMaps
- `add()`, `addAll()`, `addEntries()`
- `remove()`, `removeWhere()`, `clear()`
- `update()`, `updateAll()`, `putIfAbsent()`
- `containsKey()`, `containsValue()`
- `keys`, `values`, `entries`, `length`, `isEmpty`, `isNotEmpty`
- `forEach()`, `map()`, `cast()`

**Read-only Accessors:**
- `get()` / `getOrNull()` — return a **copy** of the entries; writing to it changes nothing
- `cast<RK, RV>()` — a **live, read-only** re-typed view; writing to it throws `UnsupportedError`

**Static Methods:**
- `TomMap.castFrom<K, V, K2, V2>()` — casts map key/value types

---

## Design Patterns Used

1. **Observer Pattern**: All types extend `TomObservable` and implement `TomObserver`
2. **Decorator Pattern**: Wraps primitive types with observable behavior
3. **Composite Pattern**: `TomClass`, `TomList`, `TomMap` observe their children
4. **Reflection Pattern**: `TomClass` uses reflection to auto-discover and register members

---

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
    ├── TomList<E> (also implements TomObserver)
    └── TomMap<K, V> (also implements TomObserver)
```

---

## Usage Example

```dart
// Primitive wrapper with observation
final name = TomString("John");
name >> (observable) => print("Name changed!"); // Subscribe to changes
name | "Jane"; // Set value and trigger observer

// Check for null values
final nullable = TomNString(null);
if (nullable.isNull) {
  print("Value is null");
}
String? maybeValue = nullable.getOrNull();

// Complex observable object - members are registered automatically via reflection
@tomReflector
class Person extends TomClass {
  final name = TomString("");
  final age = TomInt(0);
}

// Observable list
final people = TomList<Person>();
people.add(Person());
people >> (observable) => print("List changed!"); // Subscribe to changes

// Observable map
final lookup = TomMap<String, Person>();
lookup["john"] = Person();
```

---

## Dependencies

- `reflection.dart` — `@tomReflector` annotation and reflection utilities
- `date_timestamp.dart` — `TomTimezoned`, `TomZonedDate`, `TomZonedTime`, `TomZonedDateTime`
- `tom_exception.dart` — base exception class
