# Tom Core Kernel API Reference: Observable Module

An Observer-pattern foundation plus a generic observable value-wrapper type
system: `TomObservable`/`TomObserver` for change notification, and the
`TomObject<T>` family (scalars, nullable scalars, timezone-aware values,
ranges, `TomClass`, `TomList`, and `TomMap`) for building reactive,
JSON-serializable data models.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomObservable](#tomobservable)
  - [TomObserver](#tomobserver)
  - [TomFunctionObserver](#tomfunctionobserver)
  - [TomObservableException](#tomobservableexception)
  - [TomObject](#tomobject)
  - [TomString](#tomstring)
  - [TomInt](#tomint)
  - [TomDouble](#tomdouble)
  - [TomBool](#tombool)
  - [TomDateTime](#tomdatetime)
  - [TomOTimezoned](#tomotimezoned)
  - [TomOZonedTime](#tomozonedtime)
  - [TomOZonedDate](#tomozoneddate)
  - [TomOZonedDateTime](#tomozoneddatetime)
  - [TomNString](#tomnstring)
  - [TomNInt](#tomnint)
  - [TomNDouble](#tomndouble)
  - [TomNBool](#tomnbool)
  - [TomNDateTime](#tomndatetime)
  - [TomNOTimezoned](#tomnotimezoned)
  - [TomNOZonedTime](#tomnozonedtime)
  - [TomNOZonedDate](#tomnozoneddate)
  - [TomNOZonedDateTime](#tomnozoneddatetime)
  - [TomDateRange](#tomdaterange)
  - [TomTimeRange](#tomtimerange)
  - [TomDateTimeRange](#tomdatetimerange)
  - [TomClass](#tomclass)
  - [TomListLifecycleListener](#tomlistlifecyclelistener)
  - [TomList](#tomlist)
  - [TomMap](#tommap)
  - [TomObservableEnum](#tomobservableenum)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources:

- `lib/src/tombase/observable/tom_observable.dart`
- `lib/src/tombase/observable/tom_observable_objects.dart`
- `lib/src/tombase/observable/tom_observable_enum.dart`

The Observable module provides `TomObservable`, an Observer-pattern base that
holds its observers via `WeakReference` and supports muting during batch
updates, together with the `TomObserver<T>` interface and the callback wrapper
`TomFunctionObserver<T>` (installed with the `>>` operator). On top of that,
`TomObject<T>` is a generic observable value wrapper offering operator sugar
(`~obj`, `obj()`, `obj | value`, `obj << value`). A family of concrete wrappers
covers scalars (`TomString`, `TomInt`, `TomDouble`, `TomBool`, `TomDateTime`),
their nullable counterparts (`TomN…`), and timezone-aware values
(`TomOTimezoned` and its zoned/nullable-zoned subclasses). `TomClass` composes
observable members with reflection and adds JSON serialization; `TomList<E>` and
`TomMap<K,V>` are observable collections that cascade element notifications, with
`TomListLifecycleListener` receiving structural reset events. `TomDateRange`,
`TomTimeRange`, and `TomDateTimeRange` are ready-made range `TomClass`es.
`TomObservableEnum<E>` is an enum cell whose *display text* is derived rather
than stored: it resolves from the application text bundle under
`<scope>.<enumName>.<value>` and notifies on a bundle change as well as a value
change, so enums need no Dart-side label table.

## Class Hierarchy

```
TomObservable
    └── TomObject<T>
        ├── TomString
        ├── TomInt
        ├── TomDouble
        ├── TomBool
        ├── TomDateTime
        ├── TomOTimezoned<TZ>
        │   ├── TomOZonedTime
        │   ├── TomOZonedDate
        │   ├── TomOZonedDateTime
        │   └── TomNOTimezoned<TZ>
        │       ├── TomNOZonedTime
        │       ├── TomNOZonedDate
        │       └── TomNOZonedDateTime
        ├── TomNString
        ├── TomNInt
        ├── TomNDouble
        ├── TomNBool
        ├── TomNDateTime
        ├── TomClass  (implements TomObserver<TomObject>)
        │   ├── TomDateRange
        │   ├── TomTimeRange
        │   └── TomDateTimeRange
        ├── TomList<E>  (implements TomObserver, Iterable<E>)
        ├── TomMap<K, V>  (implements TomObserver)
        └── TomObservableEnum<E extends Enum>

TomObserver<T>
    └── TomFunctionObserver<T>  (implements TomObserver<T>)

TomListLifecycleListener

TomException  (little_things)
    └── TomObservableException
```

## Classes

### TomObservable

Base class implementing the Observer pattern. Holds observers by `WeakReference`
— so the caller must retain every observer it registers, or it is collected and
silently stops being notified (collected references are pruned automatically).
Supports muting to defer notifications during batch updates.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isMuted` | `bool` | `true` while observer notifications are muted. |
| `muteCascadeTargets` | `Iterable<TomObservable>` | The observables `mute` cascades to. Empty here; the composites override it to name their members. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `batch` | `T batch<T>(T Function() body)` | Runs `body` with notifications muted, releasing in a `finally` so a throwing body cannot leave the object silent. Returns the body's result. The preferred form. |
| `batchSelf` | `T batchSelf<T>(T Function() body)` | Like `batch`, but mutes this observable only — `muteCascadeTargets` stay audible. For container mutators consolidating their own notifications. |
| `mute` | `void mute()` | Mutes notifications and cascades to `muteCascadeTargets`; subsequent `notifyObservers` calls mark the observable dirty instead of notifying. Nests — each call needs one `unmute`. |
| `unmute` | `void unmute()` | Releases one `mute`, first releasing the targets that mute silenced. Notifies once when the last mute is released and the observable is dirty. Releasing more often than muting is a no-op. |
| `addObserver` | `void addObserver(TomObserver observer)` | Registers `observer` (as a weak reference); a no-op if already registered. |
| `removeObserver` | `void removeObserver(TomObserver observer)` | Unregisters `observer`; a no-op if not registered. |
| `notifyObservers` | `void notifyObservers([dynamic message])` | Notifies all live observers (or marks dirty if muted) and prunes dead weak references. `message` is reserved. |

#### Operators

| Operator | Return Type | Description |
| -------- | ----------- | ----------- |
| `operator >>(callback)` | `TomFunctionObserver<TomObservable>` | Registers a callback observer and returns the wrapper (which must be retained to keep the callback alive). |

### TomObserver

Abstract base for objects that observe a `TomObservable`. Implementers override
`onNotify`.

- **Type Parameters:** `<T extends TomObservable>`

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `onNotify` | `void onNotify(T observable)` | Called when the observed `T` notifies of a change. |

### TomFunctionObserver

Wraps a callback function as a `TomObserver`, enabling the `>>` operator syntax.
Must be retained (observers are weakly held) to keep firing.

- **Implements:** `TomObserver<T>`
- **Type Parameters:** `<T extends TomObservable>`

#### Constructors

```dart
TomFunctionObserver(void Function(T observable) callback)
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `onNotify` | `void onNotify(T observable)` | *(override)* Invokes the wrapped callback with `observable`. |

### TomObservableException

Exception thrown by observable objects for invalid operations (e.g. attempting
to set the whole value of a `TomClass`, `TomList`, or `TomMap`, or on
deserialization/type-mismatch errors).

- **Extends:** `TomException`

#### Constructors

```dart
TomObservableException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
  String? uuid,
  TomServerCallError? serverCallError,
})
```

### TomObject

Generic observable wrapper holding a value of type `T`; notifies observers on
change and provides operator sugar for getting and setting.

- **Extends:** `TomObservable`
- **Type Parameters:** `<T>`

#### Constructors

```dart
TomObject(T initialValue)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isNull` | `bool` | `true` if the current value is `null`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getType` | `Type getType()` | Returns the runtime type argument `T`. |
| `get` | `T get()` | Returns the current value. |
| `set` | `T set(T value)` | Sets the value and notifies observers if it changed; returns the new value. |
| `getOrNull` | `T? getOrNull()` | Returns the value, or `null` if it is null (for nullable types). Delegates to `get()`, so every override applies: on `TomList`/`TomMap` it returns a copy, and on `TomClass` it throws. |
| `call` | `T call()` | Call-operator form of `get()`. |
| `toString` | `String toString()` | *(override)* Returns `"~<value>"`. |

#### Operators

| Operator | Return Type | Description |
| -------- | ----------- | ----------- |
| `operator ~()` | `T` | Prefix get: `~obj`. |
| `operator |(value)` | `T` | Sets the value and notifies, returning the value: `obj | value`. |
| `operator <<(value)` | `TomObject<T>` | Sets the value and notifies, returning `this` so writes chain: `obj << 1 << 2`. |

`|` and `<<` both delegate to `set`, so they write identically — including the
notify-only-on-change rule — and differ only in what they return. A chain's
static type is `TomObject<T>`, not the subtype it started from. The composites
override `<<` to mean wholesale replacement; `TomClass` throws.

### TomString

Observable wrapper for `String` values.

- **Extends:** `TomObject<String>`

#### Constructors

```dart
TomString(String initialValue)
```

### TomInt

Observable wrapper for `int` values.

- **Extends:** `TomObject<int>`

#### Constructors

```dart
TomInt(int initialValue)
```

### TomDouble

Observable wrapper for `double` values.

- **Extends:** `TomObject<double>`

#### Constructors

```dart
TomDouble(double initialValue)
```

### TomBool

Observable wrapper for `bool` values.

- **Extends:** `TomObject<bool>`

#### Constructors

```dart
TomBool(bool initialValue)
```

### TomDateTime

Observable wrapper for `DateTime` values, using a serialization prefix for JSON
round-tripping.

- **Extends:** `TomObject<DateTime>`

#### Constructors

```dart
TomDateTime(DateTime initialValue)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `noDateTime` | `TomDateTime` | Sentinel "no date" (Unix epoch in UTC). |
| `serializationPrefix` | `String` | Prefix used when serializing `TomDateTime` values (`"@!@"`). |

### TomOTimezoned

Observable wrapper for timezone-aware `TomTimezoned` values; base class for the
zoned observable types. Subclasses override `setByString` and
`getSerializationPrefix`.

- **Extends:** `TomObject<TZ>`
- **Type Parameters:** `<TZ extends TomTimezoned?>`

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `noDateTime` | `TomOTimezoned` | Sentinel "no datetime" (Unix epoch in UTC). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getSerializationPrefix` | `String getSerializationPrefix()` | Returns the serialization prefix for this timezone type (override in subclasses). |
| `setByString` | `void setByString(String s)` | Parses a serialized string and sets the value (override in subclasses). |

### TomOZonedTime

Observable wrapper for `TomZonedTime` (time with timezone), serialized with
`TomZonedTime.serializationPrefix` (`@T@`).

- **Extends:** `TomOTimezoned<TomZonedTime>`

#### Constructors

```dart
TomOZonedTime(TomZonedTime initialValue)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `noZonedTime` | `TomZonedTime` | Sentinel "no time" (Unix epoch in UTC). |
| `noTime` | `TomOZonedTime` | Sentinel wrapper for "no time" (Unix epoch in UTC). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setByString` | `void setByString(String s)` | *(override)* Parses a `TomZonedTime` from `s`. |
| `getSerializationPrefix` | `String getSerializationPrefix()` | *(override)* Returns `TomZonedTime.serializationPrefix`. |

### TomOZonedDate

Observable wrapper for `TomZonedDate` (date with timezone), serialized with
`TomZonedDate.serializationPrefix` (`@D@`).

- **Extends:** `TomOTimezoned<TomZonedDate>`

#### Constructors

```dart
TomOZonedDate(TomZonedDate initialValue)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `noZonedDate` | `TomZonedDate` | Sentinel "no date" (Unix epoch in UTC). |
| `noTime` | `TomOZonedDate` | Sentinel wrapper for "no date" (Unix epoch in UTC). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setByString` | `void setByString(String s)` | *(override)* Parses a `TomZonedDate` from `s`. |
| `getSerializationPrefix` | `String getSerializationPrefix()` | *(override)* Returns `TomZonedDate.serializationPrefix`. |

### TomOZonedDateTime

Observable wrapper for `TomZonedDateTime` (datetime with timezone), serialized
with `TomZonedDateTime.serializationPrefix` (`@X@`).

- **Extends:** `TomOTimezoned<TomZonedDateTime>`

#### Constructors

```dart
TomOZonedDateTime(TomZonedDateTime initialValue)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `noZonedDateTime` | `TomZonedDateTime` | Sentinel "no datetime" (Unix epoch in UTC). |
| `noTime` | `TomOZonedDateTime` | Sentinel wrapper for "no datetime" (Unix epoch in UTC). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setByString` | `void setByString(String s)` | *(override)* Parses a `TomZonedDateTime` from `s`. |

### TomNString

Observable wrapper for nullable `String` values.

- **Extends:** `TomObject<String?>`

#### Constructors

```dart
TomNString(String? initialValue)
```

### TomNInt

Observable wrapper for nullable `int` values.

- **Extends:** `TomObject<int?>`

#### Constructors

```dart
TomNInt(int? initialValue)
```

### TomNDouble

Observable wrapper for nullable `double` values.

- **Extends:** `TomObject<double?>`

#### Constructors

```dart
TomNDouble(double? initialValue)
```

### TomNBool

Observable wrapper for nullable `bool` values.

- **Extends:** `TomObject<bool?>`

#### Constructors

```dart
TomNBool(bool? initialValue)
```

### TomNDateTime

Observable wrapper for nullable `DateTime` values.

- **Extends:** `TomObject<DateTime?>`

#### Constructors

```dart
TomNDateTime(DateTime? initialValue)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `noDateTime` | `TomDateTime` | Sentinel "no date" (Unix epoch in UTC). |
| `serializationPrefix` | `String` | Prefix used when serializing values (equals `TomDateTime.serializationPrefix`). |

### TomNOTimezoned

Observable wrapper for nullable timezone-aware values; base class for the
nullable zoned observable types.

- **Extends:** `TomOTimezoned<TZ>`
- **Type Parameters:** `<TZ extends TomTimezoned?>`

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `noDateTime` | `TomNOTimezoned` | Sentinel "no datetime" (Unix epoch in UTC). |

### TomNOZonedTime

Observable wrapper for nullable `TomZonedTime` values; deserializes to `null`
when the serialized value after the prefix is empty.

- **Extends:** `TomNOTimezoned<TomZonedTime?>`

#### Constructors

```dart
TomNOZonedTime(TomZonedTime? initialValue)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `noZonedTime` | `TomZonedTime` | Sentinel "no time" (Unix epoch in UTC). |
| `noTime` | `TomNOZonedTime` | Sentinel wrapper for "no time" (Unix epoch in UTC). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setByString` | `void setByString(String s)` | *(override)* Parses a `TomZonedTime` from `s`, or `null` for an empty value. |
| `getSerializationPrefix` | `String getSerializationPrefix()` | *(override)* Returns `TomZonedTime.serializationPrefix`. |

### TomNOZonedDate

Observable wrapper for nullable `TomZonedDate` values; deserializes to `null`
when the serialized value after the prefix is empty.

- **Extends:** `TomNOTimezoned<TomZonedDate?>`

#### Constructors

```dart
TomNOZonedDate(TomZonedDate? initialValue)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `noZonedDate` | `TomZonedDate` | Sentinel "no date" (Unix epoch in UTC). |
| `noTime` | `TomNOZonedDate` | Sentinel wrapper for "no date" (Unix epoch in UTC). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setByString` | `void setByString(String s)` | *(override)* Parses a `TomZonedDate` from `s`, or `null` for an empty value. |
| `getSerializationPrefix` | `String getSerializationPrefix()` | *(override)* Returns `TomZonedDate.serializationPrefix`. |

### TomNOZonedDateTime

Observable wrapper for nullable `TomZonedDateTime` values; deserializes to
`null` when the serialized value after the prefix is empty.

- **Extends:** `TomNOTimezoned<TomZonedDateTime?>`

#### Constructors

```dart
TomNOZonedDateTime(TomZonedDateTime? initialValue)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `noZonedDateTime` | `TomZonedDateTime` | Sentinel "no datetime" (Unix epoch in UTC). |
| `noTime` | `TomNOZonedDateTime` | Sentinel wrapper for "no datetime" (Unix epoch in UTC). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setByString` | `void setByString(String s)` | *(override)* Parses a `TomZonedDateTime` from `s`, or `null` for an empty value. |

### TomDateRange

Observable date range with nullable start and end dates.

- **Extends:** `TomClass`

#### Constructors

```dart
TomDateRange()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `startDate` | `TomNOZonedDate` | The start date of the range (nullable). |
| `endDate` | `TomNOZonedDate` | The end date of the range (nullable). |

### TomTimeRange

Observable time range with nullable start and end times.

- **Extends:** `TomClass`

#### Constructors

```dart
TomTimeRange()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `startTime` | `TomNOZonedTime` | The start time of the range (nullable). |
| `endTime` | `TomNOZonedTime` | The end time of the range (nullable). |

### TomDateTimeRange

Observable datetime range with nullable start and end datetimes.

- **Extends:** `TomClass`

#### Constructors

```dart
TomDateTimeRange()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `startDateTime` | `TomNOZonedDateTime` | The start datetime of the range (nullable). |
| `endDateTime` | `TomNOZonedDateTime` | The end datetime of the range (nullable). |

### TomClass

Base class for composite observable objects. Automatically registers all
`TomObject` member fields via reflection, cascades their notifications, and
provides JSON serialization and batch updates. Direct whole-value get/set is
disallowed.

- **Extends:** `TomObject<Map<String, TomObject>>`
- **Implements:** `TomObserver<TomObject>`

#### Constructors

```dart
TomClass()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `muteCascadeTargets` | `Iterable<TomObservable>` | *(override)* The member objects, so `mute` and `batch` cascade to them. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `prepareForSelfObservation` | `void prepareForSelfObservation()` | Hook to create member objects before self-observation starts (override in subclasses). |
| `set` | `Map<String, TomObject> set(Map<String, TomObject> value)` | *(override)* Throws `TomObservableException` — set individual fields instead. |
| `get` | `Map<String, TomObject> get()` | *(override)* Throws `TomObservableException` — use `getValues` or access fields. |
| `startSelfObservation` | `void startSelfObservation()` | Discovers `TomObject` fields via reflection and registers this instance as their observer. |
| `getMembers` | `Map<String, TomObject> getMembers()` | Returns a **read-only, live** view of the registered member map (field name → `TomObject`). Mutating it throws `UnsupportedError`; members registered later appear in it. |
| `onNotify` | `void onNotify(TomObservable observable)` | *(override)* Propagates a member change to this class's own observers. |
| `setValues` | `void setValues(Map<String, dynamic> values)` | Updates member fields from a map, clearing collection members first. |
| `setOrMergeValues` | `void setOrMergeValues(Map<String, dynamic> values, bool merge)` | Updates member fields; when `merge` is `true`, collection members are appended to rather than cleared. A value of the wrong shape throws `TomObservableException` naming the key and the supplied runtime type (also in `parameters`). An integral number bound for a double-holding field, list element or map value is widened, since JSON has one number type; the reverse is refused rather than truncated. Timezone-aware members are dispatched to `setByString` **before** the plain-`DateTime` handling, because `TomTimezoned` extends `DateTime` and would otherwise be parsed with its own `@D@`/`@T@`/`@X@` prefix still attached. The work runs inside a `batch`, which releases in a `finally`, so the object and its members stay notifying. |
| `getValues` | `Map<String, dynamic> getValues()` | Returns all member values as a JSON-safe map (recursing nested classes; prefixing date/timezone values). The output round-trips back through `setValues`, zoned members included. |
| `fromJson` | `void fromJson(String json)` | Populates this class from a JSON string via `setValues`. |
| `toJson` | `Map<String, dynamic> toJson()` | Returns the JSON-compatible map (equivalent to `getValues`). |
| `toString` | `String toString()` | *(override)* Reflection-based string of all values. |

#### Operators

| Operator | Return Type | Description |
| -------- | ----------- | ----------- |
| `operator <<(value)` | `TomClass` | *(override)* Throws `TomObservableException` — a class has no single value to replace. |

The asymmetry with `TomList` and `TomMap`, whose contents *are* replaceable via
`<<`, is deliberate: a class's set of members is fixed by its declaration.
Write members individually (`person.name | "John"`) or many at once with
`setValues` / `setOrMergeValues`, which address them by name.

### TomListLifecycleListener

Abstract listener for structural reset events on a `TomList`. Register via
`TomList.addLifecycleListener` to tear down / recreate state around
`TomList.resetWith`.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `onBeforeClear` | `void onBeforeClear(TomList list)` | Called immediately before all elements are removed; the list is still intact. |
| `onAfterReset` | `void onAfterReset(TomList list)` | Called immediately after new elements are installed; the list is fully populated. |

### TomList

Observable list that automatically observes all contained `TomObject` elements
and cascades their notifications. Provides the standard `List`/`Iterable`
surface with observer management. Direct whole-value `set` is disallowed
(except during serialization).

Every mutator below obeys one contract: **it notifies exactly once when it
changed the element sequence, and not at all when it left it as it was.**
Sequences are compared by element identity, so an equal-but-distinct element is
a change. `resetWith` is the deliberate exception — it notifies unconditionally,
because its lifecycle listeners have already rebuilt their per-element state.

- **Extends:** `TomObject<List<E>>`
- **Implements:** `TomObserver`, `Iterable<E>`
- **Type Parameters:** `<E extends TomObject>`

#### Constructors

```dart
TomList()
TomList.from(TomList<E> existing)
TomList.of(TomList<E> existing)
TomList.ofList(List<E> list)
```

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `castFrom` | `static TomList<E> castFrom<S extends TomObject, E extends TomObject>(TomList<S> source)` | Casts a `TomList` from element type `S` to `E`. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `first` | `E` | *(override)* First element; the setter re-observes on change. |
| `last` | `E` | *(override)* Last element; the setter re-observes on change. |
| `length` | `int` | *(override)* Element count. The setter truncates, un-observing the trimmed elements, and notifies; assigning the current length is silent, and assigning a larger one throws `TomObservableException` (a `TomList` holds non-nullable elements, so there is nothing to pad with). |
| `reversed` | `Iterable<E>` | The elements in reverse order. |
| `isEmpty` | `bool` | *(override)* `true` if the list has no elements. |
| `isNotEmpty` | `bool` | *(override)* `true` if the list has at least one element. |
| `iterator` | `Iterator<E>` | *(override)* Iterator over the elements. |
| `single` | `E` | *(override)* The single element (throws if not exactly one). |
| `hashCode` | `int` | *(override)* Hash of the backing list. |
| `muteCascadeTargets` | `Iterable<TomObservable>` | *(override)* The elements, so `mute` and `batch` cascade to them. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `addLifecycleListener` | `void addLifecycleListener(TomListLifecycleListener listener)` | Registers a lifecycle listener for reset events. |
| `removeLifecycleListener` | `void removeLifecycleListener(TomListLifecycleListener listener)` | Unregisters a lifecycle listener. |
| `set` | `List<E> set(List<E> value)` | *(override)* Throws `TomObservableException` unless serializing. |
| `get` | `List<E> get()` | *(override)* Returns a growable copy of the backing list. |
| `onNotify` | `void onNotify(TomObservable observable)` | *(override)* Propagates an element change to this list's observers. |
| `append` | `TomList<E> append(E element)` | Adds an element and returns the list for chaining. |
| `resetWith` | `void resetWith(Iterable<E> elements)` | Atomically replaces all contents, firing `onBeforeClear`/`onAfterReset`. |
| `add` | `void add(E value)` | Adds and observes an element. |
| `addAll` | `void addAll(Iterable<E> iterable)` | Adds and observes multiple elements; an empty `iterable` is silent. |
| `asMap` | `Map<int, E> asMap()` | Returns an index-to-element map. |
| `clear` | `void clear()` | Removes and un-observes all elements; silent if the list was already empty. |
| `fillRange` | `void fillRange(int start, int end, [E? fillValue])` | Fills a range with `fillValue`; silent if the range is empty or already held `fillValue`. |
| `getRange` | `Iterable<E> getRange(int start, int end)` | Returns the elements in `[start, end)`. |
| `indexOf` | `int indexOf(E element, [int start = 0])` | Index of `element` from `start`. |
| `indexWhere` | `int indexWhere(bool Function(E element) test, [int start = 0])` | First index matching `test`. |
| `insert` | `void insert(int index, E element)` | Inserts and observes an element. |
| `insertAll` | `void insertAll(int index, Iterable<E> iterable)` | Inserts and observes multiple elements; an empty `iterable` is silent, but `index` is still range-checked. |
| `lastIndexOf` | `int lastIndexOf(E element, [int? start])` | Last index of `element`. |
| `lastIndexWhere` | `int lastIndexWhere(bool Function(E element) test, [int? start])` | Last index matching `test`. |
| `remove` | `bool remove(Object? value)` | Removes and un-observes `value`, returning whether it was there. An absent element is silent. `TomObject` does not override `==`, so this matches by identity. |
| `removeAt` | `E removeAt(int index)` | Removes and un-observes the element at `index`. |
| `removeLast` | `E removeLast()` | Removes and un-observes the last element. |
| `removeRange` | `void removeRange(int start, int end)` | Removes and un-observes elements in `[start, end)`. |
| `removeWhere` | `void removeWhere(bool Function(E element) test)` | Removes and un-observes matching elements. |
| `replaceRange` | `void replaceRange(int start, int end, Iterable<E> replacements)` | Replaces a range as a single consolidated notification. It runs inside a `batchSelf`, which mutes only the list — the elements stay audible — and releases in a `finally`, so an out-of-range index does not silence the list, and an enclosing `batch` is left intact. |
| `retainWhere` | `void retainWhere(bool Function(E element) test)` | Retains only matching elements as a single notification. It delegates to `removeWhere`, which already notifies at most once, so no batch is involved. |
| `setAll` | `void setAll(int index, Iterable<E> iterable)` | Overwrites elements from `index`, re-observing; silent if the sequence is unchanged. |
| `setRange` | `void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0])` | Overwrites a range, re-observing; silent if the sequence is unchanged. |
| `shuffle` | `void shuffle([Random? random])` | Shuffles the elements; silent if the order came out unchanged. |
| `sort` | `void sort([int Function(E a, E b)? compare])` | Sorts the elements; silent if they were already in order. |
| `sublist` | `List<E> sublist(int start, [int? end])` | Returns a sublist copy. |
| `any` | `bool any(bool Function(E e) test)` | *(override)* Whether any element matches. |
| `cast` | `List<R> cast<R>()` | *(override)* A **read-only, live** re-typed view of the backing list. Mutating it throws `UnsupportedError`. |
| `contains` | `bool contains(Object? o)` | *(override)* Whether `o` is present. |
| `elementAt` | `E elementAt(int index)` | *(override)* Element at `index`. |
| `every` | `bool every(bool Function(E e) test)` | *(override)* Whether all elements match. |
| `expand` | `Iterable<R> expand<R>(Iterable<R> Function(E e) toElements)` | *(override)* Flat-maps elements. |
| `firstWhere` | `E firstWhere(bool Function(E e) test, {E Function()? orElse})` | *(override)* First matching element. |
| `fold` | `T fold<T>(T initialValue, T Function(T previousValue, E element) combine)` | *(override)* Folds the elements. |
| `followedBy` | `Iterable<E> followedBy(Iterable<E> other)` | *(override)* This iterable followed by `other`. |
| `forEach` | `void forEach(void Function(E element) action)` | *(override)* Applies `action` to each element. |
| `join` | `String join([String separator = ""])` | *(override)* Joins elements into a string. |
| `lastWhere` | `E lastWhere(bool Function(E e) test, {E Function()? orElse})` | *(override)* Last matching element. |
| `map` | `Iterable<T> map<T>(T Function(E e) toElement)` | *(override)* Maps elements. |
| `reduce` | `E reduce(E Function(E value, E element) combine)` | *(override)* Reduces the elements. |
| `singleWhere` | `E singleWhere(bool Function(E e) test, {E Function()? orElse})` | *(override)* The single matching element. |
| `skip` | `Iterable<E> skip(int count)` | *(override)* Skips `count` elements. |
| `skipWhile` | `Iterable<E> skipWhile(bool Function(E value) test)` | *(override)* Skips while `test` holds. |
| `take` | `Iterable<E> take(int count)` | *(override)* Takes `count` elements. |
| `takeWhile` | `Iterable<E> takeWhile(bool Function(E value) test)` | *(override)* Takes while `test` holds. |
| `toList` | `List<E> toList({bool growable = true})` | *(override)* Returns a list copy. |
| `toSet` | `Set<E> toSet()` | *(override)* Returns a set of the elements. |
| `toString` | `String toString()` | *(override)* String of the backing list. |
| `where` | `Iterable<E> where(bool Function(E element) test)` | *(override)* Elements matching `test`. |
| `whereType` | `Iterable<T> whereType<T>()` | *(override)* Elements of type `T`. |

#### Operators

| Operator | Return Type | Description |
| -------- | ----------- | ----------- |
| `operator [](index)` | `E` | Element at `index`. |
| `operator []=(index, value)` | `void` | Sets and re-observes the element at `index`. |
| `operator +(other)` | `TomList<E>` | Concatenates two lists. |
| `operator <<(value)` | `TomList<E>` | *(override)* Replaces **all** elements, returning the list. Detaches the outgoing elements, attaches the incoming ones, and notifies **once** for the whole exchange. |
| `operator ==(other)` | `bool` | *(override)* Equal when backing lists are equal. |

`set` throws on a list, so `<<` is the only operator-form wholesale swap. It is
silent when the new sequence is element-for-element **identical** to the old
one — the comparison is by identity, not equality, because observers hold
element references, so an equal-but-distinct element is a real change. See
`resetWith` for the same swap with lifecycle callbacks.

### TomMap

Observable map with `TomObject` values that automatically observes all values
and cascades their notifications. Keys are not observed. Direct whole-value
`set` is disallowed.

Every mutator below obeys one contract: **it notifies exactly once when it
changed the key-to-value mapping, and not at all when it left it as it was.**
Values are compared by identity, so an equal-but-distinct value is a change.

- **Extends:** `TomObject<Map<K, V>>`
- **Implements:** `TomObserver`
- **Type Parameters:** `<K, V extends TomObject>`

#### Constructors

```dart
TomMap()
TomMap.from(TomMap<K, V> existing)
TomMap.of(TomMap<K, V> existing)
TomMap.ofMap(Map<K, V> map)
```

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `castFrom` | `static TomMap<K2, V2> castFrom<K, V extends TomObject, K2, V2 extends TomObject>(TomMap<K, V> source)` | Casts a `TomMap` from key/value types `K`/`V` to `K2`/`V2`. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `length` | `int` | Number of key-value pairs. |
| `hashCode` | `int` | *(override)* Hash of the backing map. |
| `isEmpty` | `bool` | `true` if the map has no pairs. |
| `isNotEmpty` | `bool` | `true` if the map has at least one pair. |
| `keys` | `Iterable<K>` | All keys. |
| `values` | `Iterable<V>` | All values. |
| `entries` | `Iterable<MapEntry<K, V>>` | All key-value pairs. |
| `muteCascadeTargets` | `Iterable<TomObservable>` | *(override)* The values, so `mute` and `batch` cascade to them. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `set` | `Map<K, V> set(Map<K, V> value)` | *(override)* Throws `TomObservableException` — modify individual entries instead. |
| `get` | `Map<K, V> get()` | *(override)* Returns a copy of the backing map. |
| `onNotify` | `void onNotify(TomObservable observable)` | *(override)* Propagates a value change to this map's observers. |
| `add` | `void add(K key, V value)` | Adds/replaces a key's value, re-observing. |
| `addAll` | `void addAll(Map<K, V> other)` | Adds all entries from `other`, re-observing; silent if the mapping is unchanged. |
| `addEntries` | `void addEntries(Iterable<MapEntry<K, V>> newEntries)` | Adds entries, re-observing; silent if the mapping is unchanged. |
| `cast` | `Map<RK, RV> cast<RK, RV>()` | A **read-only, live** re-typed view of the backing map. Mutating it throws `UnsupportedError`. |
| `clear` | `void clear()` | Removes and un-observes all entries; silent if the map was already empty. |
| `containsKey` | `bool containsKey(K key)` | Whether `key` is present. |
| `containsValue` | `bool containsValue(V value)` | Whether `value` is present. |
| `forEach` | `void forEach(void Function(K key, V value) action)` | Applies `action` to each entry. |
| `map` | `Map<K2, V2> map<K2, V2>(MapEntry<K2, V2> Function(K key, V value) convert)` | Maps entries to a new map. |
| `putIfAbsent` | `V putIfAbsent(K key, V Function() ifAbsent)` | Inserts and observes a value if `key` is absent; a present key is returned untouched and is silent. |
| `remove` | `V? remove(K? key)` | Removes and un-observes the value for `key` and notifies; a `null` or absent key returns `null` and is silent. |
| `removeWhere` | `void removeWhere(bool Function(K key, V value) test)` | Removes matching entries, re-observing survivors; silent if nothing matched. |
| `update` | `V update(K key, V Function(V value) update, {V Function()? ifAbsent})` | Updates the value for `key`, re-observing. Runs inside a `batchSelf`, so a callback that both mutates the value in place and returns a replacement still notifies once. |
| `updateAll` | `void updateAll(V Function(K key, V value) update)` | Updates all values, re-observing changed ones. Runs inside a `batchSelf`: one notification for the whole call, and none if every callback returned the value it was given unchanged. |

#### Operators

| Operator | Return Type | Description |
| -------- | ----------- | ----------- |
| `operator [](key)` | `V?` | Value for `key`, or `null`. |
| `operator []=(key, value)` | `void` | Sets and observes the value for `key`. |
| `operator +(other)` | `TomMap<K, V>` | Merges two maps into a new one. |
| `operator <<(newMap)` | `TomMap<K, V>` | *(override)* Replaces **all** entries, returning the map. Detaches the outgoing values, attaches the incoming ones, and notifies **once** for the whole exchange. |
| `operator ==(other)` | `bool` | *(override)* Equal when backing maps are equal. |

As on `TomList`, `set` throws on a map, so `<<` is the operator form of a
wholesale swap and the only one.

### TomObservableEnum

Observable wrapper for an `Enum` value whose **display text** is resolved from
the application text bundle instead of a Dart-side label table. Notifies its
observers when either the value or the installed bundle changes, so a locale
switch re-renders bound widgets without the caller rebuilding them.

Keys are `<scope>.<enumName>.<value>`, all lower case. The scope segment is
implicit — taken from the ambient `TomScope` **at construction time**, because
display resolution typically runs inside a Flutter builder callback, outside
the zone that installed the scope. Resolution walks the scope chain from most
specific to least specific and ends at `global`, so a label declared once under
`global` works everywhere while one scope can override just the labels it needs.

A value with no key degrades to the raw enum name (never blank) and logs a
warning naming the keys tried — once per key per bundle revision.

- **Extends:** `TomObject<E>`

#### Constructors

```dart
TomObservableEnum(E initialValue, {List<E>? values, TomScope? scope})
```

`values` is the enum's value list (`MyEnum.values`), used by pickers to
enumerate options; it defaults to just `initialValue`. `scope` overrides the
ambient scope.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `globalScopeId` | `String` | `'global'` — the least specific segment of every key chain. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `enumTypeSegment` | `static String enumTypeSegment(Enum value)` | The enum-type segment of a key: the runtime type, lower case. |
| `valueSegment` | `static String valueSegment(Enum value)` | The value segment of a key: the constant name, lower case. |
| `resourceKeysFor` | `static List<String> resourceKeysFor(Enum value, {TomScope? scope})` | The candidate keys, most specific scope first, ending at the `global` key. |
| `resolveTextOrNull` | `static String? resolveTextOrNull(Enum value, {TomScope? scope})` | Bundle text for `value`, or `null` when no candidate resolves. |
| `resolveText` | `static String resolveText(Enum value, {TomScope? scope})` | Bundle text for `value`, else its raw enum name (logging the miss). |
| `resourceKeyFor` | `static String resourceKeyFor(Enum value, {TomScope? scope})` | The key that resolved, or the `global` key when none did. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `values` | `List<E>` | The enum's value list, in declaration order. Unmodifiable. |
| `scope` | `TomScope` | The scope captured at construction, used for key resolution. |
| `displayText` | `String` | Bundle text for the current value. |
| `displayKey` | `String` | Resource key for the current value. |
| `displayTexts` | `List<String>` | Bundle text for every entry of `values`, in order. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `displayTextOf` | `String displayTextOf(E value)` | Bundle text for `value`, resolved in this cell's scope. |
| `displayKeyOf` | `String displayKeyOf(E value)` | Resource key for `value`, resolved in this cell's scope. |
| `detachFromResources` | `void detachFromResources()` | Stops reacting to bundle changes; value changes still notify. |

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `tomNull` | `TomObject<String>` | Sentinel `TomObject` representing a null or unknown value, returned when a value's type cannot be determined. Declared `final`, not `const` — `TomObject`'s constructor has a body, so it cannot be const; the sentinel is one run-time instance, and testing for it means comparing identity against this variable rather than against a canonicalised literal. |

### Functions

None — this module exposes no top-level functions.
