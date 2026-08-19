# Tom Observable System

The Tom Observable System implements the Observer pattern to enable reactive data binding
in Dart applications. It provides observable wrapper types for primitives, collections,
and complex objects with automatic change notification and propagation.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
  - [TomObservable](#tomobservable)
    - [**Memory Management — you must retain the observer**](#memory-management--you-must-retain-the-observer)
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
  - [The "no value" sentinels](#the-no-value-sentinels)
- [TomClass (Observable Objects)](#tomclass-observable-objects)
- [The Collection Notification Contract](#the-collection-notification-contract)
- [TomList (Observable Lists)](#tomlist-observable-lists)
  - [Atomic Replacement with resetWith](#atomic-replacement-with-resetwith)
  - [Lifecycle Listeners](#lifecycle-listeners)
- [TomMap (Observable Maps)](#tommap-observable-maps)
- [TomObservableEnum (Resource-Keyed Enums)](#tomobservableenum-resource-keyed-enums)
  - [Permitted Values](#permitted-values)
  - [Resource Keys and Scope](#resource-keys-and-scope)
  - [Where the Enum Segment Comes From](#where-the-enum-segment-comes-from)
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
- **Memory Safe**: Observers are held by `WeakReference`, so an observable never
  keeps a dead observer alive — which also means *you* must retain any observer
  you register (see [Memory Management](#memory-management--you-must-retain-the-observer))
- **JSON Integration**: Seamless serialization/deserialization with the reflection system

## Quick Start

### 1. Basic Observable Value

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

// Create an observable string
final name = TomString("John");

// Subscribe to changes using >> operator. Keep the returned observer: it is
// held weakly, and dropping it silently ends the subscription.
final observer = name >> (obs) => print("Name changed to: ${~name}");

// Set value using | operator - triggers notification
name | "Jane";  // Prints: "Name changed to: Jane"

// Get value using ~ operator
print(~name);  // Prints: "Jane"

// Done observing
name.removeObserver(observer);
```

> **Every example below captures the observer it registers.** That is not
> stylistic: `TomObservable` holds observers by `WeakReference`, so an observer
> nothing else references is collected and stops firing without any error. See
> [Memory Management](#memory-management--you-must-retain-the-observer).

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
  final observer = person >> (obs) => print("Person changed!");

  // Set values - triggers notification
  person.name | "Alice";  // Prints: "Person changed!"
  person.age | 25;        // Prints: "Person changed!"

  // Get values
  print("Name: ${~person.name}");  // Prints: "Name: Alice"
  print("Age: ${~person.age}");    // Prints: "Age: 25"

  person.removeObserver(observer);
}
```

### 3. Observable Collections

```dart
// Observable list
final names = TomList<TomString>();
final namesObserver = names >> (obs) => print("List changed!");

names.add(TomString("Alice"));  // Prints: "List changed!"
names.add(TomString("Bob"));    // Prints: "List changed!"

// Changes to elements also notify the list
names[0] | "Alicia";  // Prints: "List changed!"

names.removeObserver(namesObserver);

// Observable map
final scores = TomMap<String, TomInt>();
final scoresObserver = scores >> (obs) => print("Scores changed!");

scores["alice"] = TomInt(100);  // Prints: "Scores changed!"
scores["alice"]! | 95;          // Prints: "Scores changed!"

scores.removeObserver(scoresObserver);
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
| `void addObserver(TomObserver observer)` | Registers an observer (as a `WeakReference`); a no-op if it is already registered |
| `void removeObserver(TomObserver observer)` | Unregisters an observer; a no-op if it is not registered |
| `void notifyObservers([dynamic message])` | Notifies every live observer, or marks the object dirty if muted. Also prunes references whose observer has been collected. `message` is accepted but unused — reserved for future context |
| `T batch<T>(T Function() body)` | Runs `body` with notifications suppressed, releasing even if it throws; returns the body's result |
| `T batchSelf<T>(T Function() body)` | Like `batch`, but suppresses this object only — the members stay audible |
| `void mute()` | Suppresses notifications; nests, so each call needs one `unmute()` |
| `void unmute()` | Releases one `mute()`; notifies once when the last one is released and something changed. Releasing more often than muting is a no-op, not an error |

| Getter | Type | Description |
|--------|------|-------------|
| `muteCascadeTargets` | `Iterable<TomObservable>` | The members `mute()` cascades to. Empty here; the composites override it |

#### Memory Management — you must retain the observer

**`TomObservable` holds its observers weakly. The observable does not keep your
observer alive; you do.** An observer that nothing else references is garbage
collected, and from that moment it stops being notified.

This is the single most important thing to know about the module, because the
failure mode is silence: no exception, no log line, no dead-observer warning.
The notifications simply stop, at a point determined by when the collector
happens to run, and a program that was working keeps running with one of its
observers no longer connected.

The rule follows from `addObserver`, which stores a `WeakReference` rather than
the observer itself. Written out with the private helper inlined, it is:

```dart
final List<WeakReference<TomObserver>> observers = [];

void addObserver(TomObserver observer) {
  final alreadyRegistered =
      observers.any((ref) => identical(ref.target, observer));
  if (!alreadyRegistered) {
    observers.add(WeakReference(observer)); // weak, not strong
  }
}
```

`notifyObservers` skips references whose target has been collected and prunes
them from the list. That is the "automatic cleanup" this design buys — it
prevents the observable from keeping dead observers alive. It is not a promise
that your observer will still be there.

##### The pattern

Keep the handle in something that lives at least as long as the observation —
normally a field — and end the observation explicitly with
[`removeObserver`](#methods):

```dart
class PriceTicker {
  final TomInt _price;
  late final TomFunctionObserver<TomObservable> _observer;

  PriceTicker(this._price) {
    // Retained in a field: the observation lives as long as this object.
    _observer = _price >> (obs) => _redraw();
  }

  void dispose() {
    // Deterministic end, rather than waiting for the collector.
    _price.removeObserver(_observer);
  }

  void _redraw() {/* ... */}
}
```

##### What does *not* count as retaining

Discarding the handle is the mistake, and it is easy to make because the
expression reads perfectly well without it:

```dart
final counter = Counter();

// ✗ Broken: nothing references the returned observer, so it is collected
//   and the callback silently stops firing.
counter >> (obs) => print('Changed!');
```

Less obviously, **assigning to a local you never read again is not enough
either.** The compiler is entitled to treat such a local as dead, and under AOT
it does:

```dart
// ✗ Also broken under `dart compile exe`: `handle` is never read after this
//   line, so it does not keep the observer reachable.
final handle = counter >> (obs) => print('Changed!');
await Future<void>.delayed(const Duration(seconds: 1));   // a GC may run here
counter.increment();   // may print nothing
```

The two compilers disagree here, which makes this particularly unpleasant to
diagnose: the same code observed correctly under `dart run` and stopped
observing once compiled with `dart compile exe`. Do not rely on a local unless
something later in the same scope actually uses it — `removeObserver(handle)` at
the end of the scope both ends the observation and keeps the handle reachable
until then.

##### When an observer legitimately needs no handle

If the observer is an object your program already holds for other reasons —
a widget, a service, a collection — it is retained by whatever holds it, and
there is no separate handle to keep:

```dart
class CounterPanel {
  final CounterDisplay _display = CounterDisplay();   // field: retained
  final Counter _counter;

  CounterPanel(this._counter) {
    _counter.addObserver(_display);   // the observer *is* the field
  }
}
```

The composites rely on exactly this. `TomList` and `TomMap` implement
`TomObserver` and register *themselves* on each element (`e.addObserver(this)`),
so the observer is the collection, which your application already holds. They
also call `removeObserver` when an element leaves, so the observation ends with
the membership rather than at the collector's convenience.

The caveat above still applies to the shortcut form: a
`final display = CounterDisplay();` local that nothing reads again is no more
retained than a discarded `>>` handle. What makes an observer safe is that
something *live* refers to it — a field, a collection, a later read — not the
fact that it has a name.

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

  // `display` is the observer, so `display` is what has to stay reachable —
  // ending the observation here also keeps it reachable up to this point.
  counter.removeObserver(display);
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
// `>>` wraps the callback and registers it, returning the wrapper:
final observer = counter >> (obs) => print('Changed!');

// The same thing spelled out:
final sameObserver = TomFunctionObserver<Counter>((obs) => print('Changed!'));
counter.addObserver(sameObserver);
```

#### Keeping References — required, not optional

The `>>` operator returns the `TomFunctionObserver` it created, and **that
wrapper is the only strong reference to your callback.** Capturing it is not a
convenience for removing the observer later; it is what keeps the observation
alive at all. Discard it and the callback stops firing as soon as the wrapper is
collected — see
[Memory Management](#memory-management--you-must-retain-the-observer) for the
full contract and for why a local you never read again does not count.

```dart
class PriceWatcher {
  final Counter _counter;
  late final TomFunctionObserver<TomObservable> _observer;

  PriceWatcher(this._counter) {
    _observer = _counter >> (obs) => print('Changed!');
  }

  void dispose() => _counter.removeObserver(_observer);
}
```

## Operators

The observable system uses custom operators for a clean, expressive API:

| Operator | Usage | Returns | Description |
|----------|-------|---------|-------------|
| `~` | `~observable` | `T` | Get the current value (prefix unary operator) |
| `()` | `observable()` | `T` | Get the current value (call operator) |
| `\|` | `observable \| value` | `T` | Set the value and notify observers; yields the value that was set |
| `<<` | `observable << value` | `TomObject<T>` | Set the value and notify observers; yields the observable, so calls chain |
| `>>` | `observable >> callback` | `TomFunctionObserver<TomObservable>` | Wrap the callback in an observer, register it, and return it. **Keep the returned observer** — it is held weakly (see [Memory Management](#memory-management--you-must-retain-the-observer)) |

On a value cell, `|` and `<<` differ only in what they hand back. Use `|` when
the value is what you want next (`final next = counter | 5;`), `<<` when you
want to keep working on the observable (`counter << 5 << 6;`). Both go through
`set()`, so both are silent when the value does not change. A chain's static
type is `TomObject<T>`, not the subtype it started from — chain for the writes,
not to keep hold of a `TomString`.

**The composites override `<<`, and it does not mean the same thing on them.**
`set()` throws on a list and on a map, so there `<<` is the *only* operator-form
whole-value write, and it means wholesale replacement:

| Receiver | `receiver << value` |
|----------|---------------------|
| `TomObject<T>` | Sets the value, returns the observable |
| [`TomList<E>`](#tomlist-observable-lists) | Replaces **all** elements — detaches the outgoing ones, attaches the incoming ones, **one** notification for the exchange. Silent when the new sequence is element-for-element identical (compared by identity, since observers hold element references) |
| [`TomMap<K, V>`](#tommap-observable-maps) | Replaces **all** entries, same contract |
| [`TomClass`](#tomclass-observable-objects) | **Throws** `TomObservableException` — a class has no single value to replace. Use `setValues` to write many members at once |

The `TomClass` asymmetry is deliberate: a list's and a map's contents are
replaceable, whereas a class's set of members is fixed by its declaration.

`>>` is declared on `TomObservable`, so it is available on every observable —
not only on the `TomObject<T>` value cells.

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
final nameObserver = name >> (obs) => print("Changed to: ${~name}");
name.removeObserver(nameObserver);

// Combined example
final counter = TomInt(0);
final counterObserver = counter >> (obs) => print("Counter: ${~counter}");
counter | (~counter + 1);  // Increment: Prints "Counter: 1"
counter | (~counter + 1);  // Increment: Prints "Counter: 2"
counter.removeObserver(counterObserver);
```

## Observable Primitives

### TomObject&lt;T&gt; (Base Class)

All observable value types extend `TomObject<T>`. It is a concrete class — you
can instantiate `TomObject<T>` directly for a type the library does not wrap —
and it provides:

```dart
final greeting = TomObject<String>("hello");   // directly instantiable
print(~greeting);                              // hello
```

| Member | Description |
|--------|-------------|
| `TomObject(T initialValue)` | The only constructor — the initial value is required |
| `Type getType()` | The runtime type argument `T` |
| `T get()` | The current value |
| `T call()` | The current value (call operator) |
| `T set(T value)` | Sets the value and returns it; notifies **only if the value changed** |
| `T? getOrNull()` | The current value, nullably typed. Delegates to `get()`, so every override of `get()` applies here too |
| `bool get isNull` | Whether the current value is `null` |
| `T operator ~()` | `~o` — the current value |
| `T operator \|(T value)` | `o \| v` — sets, yields the value |
| `TomObject<T> operator <<(T value)` | `o << v` — sets, yields `this`, so calls chain |

`set` — and therefore `|` and `<<` — compares against the current value and
stays silent when they are equal, so writing the same value twice notifies once.

Subscription is not declared here: `operator >>` and the
`addObserver`/`removeObserver`/`notifyObservers` trio come from
[`TomObservable`](#tomobservable).

The composites narrow this contract rather than extending it. All three throw
from `set`, and for two different reasons.
[`TomClass`](#tomclass-observable-objects) has no single value to replace: its
members are fixed by its declaration. [`TomList`](#tomlist-observable-lists) and
[`TomMap`](#tommap-observable-maps) *do* have replaceable contents, but
assigning the backing collection would leave the outgoing entries still observed
and the incoming ones unobserved — so the swap is done by `<<` (and, on a list,
[`resetWith`](#atomic-replacement-with-resetwith)),
which exchange the observers as part of the operation. `get` on `TomList` and
`TomMap` returns a **copy**, so mutating the result changes nothing. For
individual entries use the collection's own API (`add`, `[]=`, `setValues`, …).

### Non-Nullable Types

Every one of these takes its initial value as a required positional argument —
there is no zero-argument constructor and therefore no implicit default. Pick
the starting value explicitly.

| Class | Wraps | Constructor |
|-------|-------|-------------|
| `TomString` | `String` | `TomString("")` |
| `TomInt` | `int` | `TomInt(0)` |
| `TomDouble` | `double` | `TomDouble(0.0)` |
| `TomBool` | `bool` | `TomBool(false)` |
| `TomDateTime` | `DateTime` | `TomDateTime(DateTime.now())` |

For "not set yet" on a non-nullable type, use the sentinel rather than inventing
one: `TomDateTime.noDateTime` is the Unix epoch in UTC. See
[The "no value" sentinels](#the-no-value-sentinels).

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

The nullable variants also require the initial value — `null` is a legal
argument, not an omitted one, so write it out.

| Class | Wraps | Constructor |
|-------|-------|-------------|
| `TomNString` | `String?` | `TomNString(null)` |
| `TomNInt` | `int?` | `TomNInt(null)` |
| `TomNDouble` | `double?` | `TomNDouble(null)` |
| `TomNBool` | `bool?` | `TomNBool(null)` |
| `TomNDateTime` | `DateTime?` | `TomNDateTime(null)` |

```dart
// Nullable types can hold null values
final middleName = TomNString(null);
final score = TomNInt(null);

// Check for null
if (middleName.isNull) {
  print("No middle name");
}

// Safe access
String? middle = middleName.getOrNull();
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

Together with `@!@` for a plain `TomDateTime` these are the **complete** set of
prefixes. Deserialization inspects an incoming string for each of the four and
rebuilds the matching observable; an unprefixed string stays a `TomString`. So
the prefix is what distinguishes a date from text that merely looks like one —
which is why `getValues()` writes it and `setValues()` requires it.

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
final observer = meetingTime >> (obs) => print("Meeting time changed!");

// Get the value
TomZonedDateTime time = ~meetingTime;
print(time.timezone.timezone);  // "America/New_York" — the IANA name
print(time.hour);               // 14

meetingTime.removeObserver(observer);
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
final observer = event >> (obs) => print("Event modified!");
// ... later, when the subscription is no longer wanted:
event.removeObserver(observer);
```

A freshly constructed range is not empty — both ends are seeded with the "no
value" sentinel of the matching type, described next.

### The "no value" sentinels

Each date/time type carries a sentinel meaning "no value", for code that needs
a placeholder but cannot use `null` (a non-nullable field, or a range end that
must always hold an object). They come in pairs: a **plain** one holding the
bare value, and an **observable** one already wrapped.

| Type | Plain sentinel | Observable sentinel |
|------|----------------|---------------------|
| `TomDateTime` | — | `TomDateTime.noDateTime` |
| `TomOTimezoned` | — | `TomOTimezoned.noDateTime` |
| `TomOZonedTime` | `TomOZonedTime.noZonedTime` | `TomOZonedTime.noTime` |
| `TomOZonedDate` | `TomOZonedDate.noZonedDate` | `TomOZonedDate.noTime` |
| `TomOZonedDateTime` | `TomOZonedDateTime.noZonedDateTime` | `TomOZonedDateTime.noTime` |

The nullable types (`TomNDateTime`, `TomNOZonedTime`, `TomNOZonedDate`,
`TomNOZonedDateTime`, `TomNOTimezoned`) expose the same pairs under the same
names.

**Every sentinel denotes one instant: the Unix epoch in UTC.** That is the
whole point of a sentinel — two machines in different timezones must agree on
which values mean "no value", so the sentinels are built from
`DateTime.utc(1970)` and never from `DateTime(1970)`:

```dart
@tomReflector
class Booking extends TomClass {
  // Seeded with the sentinel, so the field is never null and never a real date.
  TomDateTime cancelledAt = TomDateTime(TomDateTime.noDateTime.get());
}

final booking = Booking();

// The comparison below holds on every machine, in every timezone.
if (booking.cancelledAt.get().toUtc() == DateTime.utc(1970)) {
  print("not cancelled");
}

// The two families are interchangeable, so it does not matter which one a
// value was seeded from.
TomOZonedDate.noZonedDate == TomOZonedDate.noTime.get();  // true
```

A local-time epoch would break this in three ways at once: the sentinel would
shift with the reader's zone, a value written by one machine and read by
another would silently become a real date, and — because `TomZonedDate`
truncates to a date — a negative UTC offset would move the sentinel to the
*previous day*. Note also that the direction of the skew follows the sign of
the offset, so a local-epoch sentinel is not even reliably *before* the real
epoch.

Because `DateTime(1970)` and `DateTime.utc(1970)` are the same value when the
process runs in UTC, this class of defect is invisible to a UTC-only test run.
`tool/run_tz_matrix.sh` runs the suite across five zones spanning both signs of
offset and the +14 extreme.

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
  final observer = person >> (obs) => notifyCount++;
  
  // Set individual fields
  person.name | "Alice";
  person.age | 30;
  person.email | "alice@example.com";
  
  print(notifyCount);  // 3 - one notification per change
  
  // Get all values as a map
  Map<String, dynamic> values = person.getValues();
  print(values);  // {name: Alice, age: 30, email: alice@example.com, isActive: true}

  person.removeObserver(observer);
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
  final observer = customer >> (obs) => print("Customer changed!");

  customer.name | "Acme Corp";        // Prints: "Customer changed!"
  customer.address.city | "New York"; // Prints: "Customer changed!"

  customer.removeObserver(observer);
}
```

### Key Methods

| Method | Description |
|--------|-------------|
| `getMembers()` | Returns a read-only, live view of all registered `TomObject` members |
| `setValues(Map<String, dynamic>)` | Bulk update multiple fields at once |
| `setOrMergeValues(Map<String, dynamic>)` | Update or merge with existing values |
| `getValues()` | Returns all members as a `Map<String, dynamic>` |
| `toJson()` | Serializes to JSON-compatible map (same as `getValues()`) |
| `fromJson(String json)` | Deserializes from JSON string |

### Accessors never hand out a writable collection

No accessor on a composite returns a handle you can write through. Writing
through one would bypass the notification the mutator sends, and on a
`TomClass` it would deregister a member without detaching the observer wiring
that registration installed — leaving a half-attached object that nothing
outside the class can repair. So:

| Accessor | Returns | Writing to it |
|----------|---------|---------------|
| `TomClass.getMembers()` | a **live, read-only view** of the member map | throws `UnsupportedError` |
| `TomClass.getOrNull()` | — | throws `TomObservableException`, exactly as `get()` does |
| `TomList.get()` / `getOrNull()` | a **copy** of the elements | allowed, but changes nothing |
| `TomMap.get()` / `getOrNull()` | a **copy** of the entries | allowed, but changes nothing |
| `TomList.cast<R>()` | a **live, read-only** re-typed view | throws `UnsupportedError` |
| `TomMap.cast<RK, RV>()` | a **live, read-only** re-typed view | throws `UnsupportedError` |

`getOrNull()` is the nullable-typed sibling of `get()` and nothing more — it
delegates rather than reading the backing field, so every rule above holds for
both.

The views are *live*, not snapshots: elements and members added later show up
in a view taken earlier. This matters for `getMembers()`, because a member
whose field is still `null` at construction is registered only when a later
`startSelfObservation()` runs, and a snapshot taken before that would silently
be missing it.

Read-only applies to the *collection*, not to what is in it. The members and
elements are the live cells, so reading one and assigning through it works
as usual:

```dart
// Refused — the collection itself is read-only.
customer.getMembers()['name'] = TomString("x");   // throws UnsupportedError

// Fine — the cell is live, and the assignment notifies.
(customer.getMembers()['name'] as TomString) | "Acme Corp";
```

To change the contents of a `TomList` or `TomMap`, use its mutators (`add`,
`remove`, `[]=`, …); those notify observers.

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
@tomReflector
class PricedItem extends TomClass {
  TomList<TomString> tags = TomList();
  TomDouble price = TomDouble(0.0);
  TomList<TomDouble> rates = TomList();
  TomInt quantity = TomInt(0);
  TomList<TomInt> counts = TomList();
}

final item = PricedItem();

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
// PricedItem, from above: price is a TomDouble, rates a TomList<TomDouble>.
item.setValues({'price': 20, 'rates': [1, 2]});

print(item.price.get());            // 20.0  — a double, not an int
print(item.rates.map((e) => ~e));   // (1.0, 2.0)
```

The widening is keyed on the *destination*, not on the value, so integers that
are meant to stay integers do:

```dart
item.setValues({'quantity': 7, 'counts': [1, 2]});   // TomInt, TomList<TomInt>

print(item.quantity.get());          // 7     — still an int
print(item.counts.map((e) => ~e));   // (1, 2)
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

`getValues()` prefixes each date/time member with its own marker — `@!@` for a
plain `DateTime`, `@D@`/`@T@`/`@X@` for the zoned types — and `setValues()`
reads all of them back, so a class round-trips through its own output whatever
mix of date members it holds:

```dart
final original = Event()..name.set("Conference");

final restored = Event();
restored.setValues(original.getValues());   // zoned members included
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
final observer = map >> (obs) => notifications++;

map.remove('missing');
print(notifications);  // 0 — nothing changed

map.remove('a');
print(notifications);  // 1 — an entry went away

map.removeObserver(observer);
```

```dart
final list = TomList<TomInt>();
list.addAll([TomInt(1), TomInt(2), TomInt(3)]);

int notifications = 0;
final observer = list >> (obs) => notifications++;

list.addAll([]);                            // 0 — nothing to add
list.sort((a, b) => (~a).compareTo(~b));    // 0 — already in order
list[0] = list[0];                          // 0 — same element
list.length = 3;                            // 0 — already that long
print(notifications);  // 0

list.length = 2;       // truncation drops an element
print(notifications);  // 1

list.removeObserver(observer);
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
final observer = tasks >> (obs) => listNotifications++;

// Add a task
tasks.add(Task()..title.set("Buy groceries"));
print(listNotifications);  // 1

// Modify the task's title - list is notified!
tasks[0].title | "Buy organic groceries";
print(listNotifications);  // 2

// Mark as completed - list is notified again!
tasks[0].completed | true;
print(listNotifications);  // 3

tasks.removeObserver(observer);
```

### Atomic Replacement with resetWith

`resetWith(Iterable<E>)` replaces the **entire** contents of a `TomList` in a
single operation and sends exactly **one** notification afterwards. It detaches
the list's observer from the old elements, clears them, attaches to and installs
the new elements, then notifies:

```dart
final rows = TomList<Task>();
rows.addAll([Task()..title.set('a'), Task()..title.set('b')]);

int notifications = 0;
final observer = rows >> (obs) => notifications++;

// Swap all contents in one shot — a single notification, not one per element.
rows.resetWith([Task()..title.set('x'), Task()..title.set('y')]);
print(notifications);  // 1

rows.removeObserver(observer);
```

This is the path `TomClass` uses internally when a parent form writes a bind-time
snapshot back via `setValues()` — the list member's contents are swapped
wholesale rather than diffed.

`rows << [...]` performs the same exchange in operator form, and differs in two
ways. `resetWith` fires the [lifecycle listeners](#lifecycle-listeners) and `<<`
does not; and `resetWith` notifies *unconditionally* — even when the new
contents are the old ones — because the listeners have already torn down and
rebuilt whatever they hold per element, whereas `<<` is silent when the new
sequence is element-for-element identical. Reach for `<<` when nothing is tied
to element identity, and for `resetWith` when something is.

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

// Keep the listener: removing it later needs the same instance.
final rowFormSync = RowFormSync();
rows.addLifecycleListener(rowFormSync);
// ... later
rows.removeLifecycleListener(rowFormSync);
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
final observer = users >> (obs) => mapNotifications++;

// Add a user
users['alice'] = User()..name.set("Alice");
print(mapNotifications);  // 1

// Modify the user's score - map is notified!
users['alice']!.score | 100;
print(mapNotifications);  // 2

users.removeObserver(observer);
```

### Replacing the Entire Map: `<<`, not `set()`

`set()` throws on a map. Replacing the backing map behind the value observers
would silently strand them, so the plain whole-value write is refused and `<<`
is provided instead — it performs the same exchange *properly*, detaching the
outgoing values and attaching the incoming ones:

```dart
final map = TomMap<String, TomInt>();

// This throws TomObservableException
// map.set({'a': TomInt(1)});  // ✗ Not allowed

// Replace in one shot with <<, which is a single notification …
map << {'a': TomInt(1)};       // ✓ OK

// … rather than the two the clear/addAll pair produces.
map.clear();
map.addAll({'a': TomInt(1)});  // ✓ OK, but notifies twice
```

`TomList` works the same way — see
[Atomic Replacement with resetWith](#atomic-replacement-with-resetwith) for the
variant that also fires the lifecycle callbacks.

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

### Permitted Values

The `values` argument is the set of values the cell may hold. It is what a
picker enumerates to build its options, and it is **required** — Dart cannot
recover `E.values` from a type parameter, and a default would be a guess.

A subset is legitimate and means what it says: a cell offering a restricted
choice. What is *not* legitimate is a cell holding a value its own option list
does not contain — it would label itself from a list that excludes it, so
`displayTexts` would describe something other than `displayText`, and a bound
picker would have no option to select. Both the constructor and `set` therefore
reject an out-of-range value:

```dart
final status = TomObservableEnum(
  TodoStatus.open,
  values: const [TodoStatus.open, TodoStatus.inReview],   // no 'done'
);

status | TodoStatus.inReview;   // fine
status | TodoStatus.done;       // throws TomObservableException
```

`set` is the single mutation path — `|` and `<<` both delegate to it — so the
guarantee holds however the cell is written, and a rejected write changes
nothing and notifies nobody.

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

### Where the Enum Segment Comes From

The middle segment — `todostatus` above — is read out of `Enum.toString()`,
whose default form is exactly `<EnumType>.<name>`, **not** out of
`runtimeType`. The two are the same string in a debug build, but only
`toString()` survives a minifying or obfuscating compile: the declared name is
baked into the enum as a string literal, while `runtimeType` is a class name
the compiler is free to rewrite. Under `dart compile js -O4 --minify`,
`runtimeType` reads `minified:y` while `toString()` still reads
`TodoStatus.inReview` — so a segment taken from `runtimeType` would address a
key that exists in no bundle, losing every label in release while working
perfectly in development.

An **enhanced enum that overrides `toString()`** defeats that inference. Rather
than fall back to the unstable name, resolution rejects it with a
`TomObservableException`; the enum declares its segment instead by implementing
`TomEnumResourceSegment`:

```dart
enum ShippingState implements TomEnumResourceSegment {
  pending, shipped;

  @override
  String get resourceSegment => 'shipping';   // → global.shipping.shipped

  @override
  String toString() => 'ShippingState<$name>';
}
```

The declared value is lower-cased before use and must be a literal — deriving
it from `runtimeType` would reintroduce the problem it exists to avoid. The
failure is deterministic in every build, including debug, so an enum that needs
this is caught while it is being written rather than after it ships.

### Locale Changes

A cell notifies its observers when *either* the value **or** the installed
bundle changes. Switching locale therefore re-renders anything bound to it,
with no rebuild on the caller's side:

```dart
final status = TomObservableEnum(TodoStatus.inReview, values: TodoStatus.values);

// Retain the observer — observers are held weakly.
final observer = status >> (_) => print(status.displayText);

final germanBundle = TomTextResourceProvider.from({
  'global': {
    'todostatus': {'open': 'Offen', 'inreview': 'In Prüfung', 'done': 'Erledigt'},
  },
});
TomTextResourceProvider.setAppResourceProvider(germanBundle);  // 'In Prüfung'

status.removeObserver(observer);
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
again. Because a key carries the scope path and scope ids are arbitrary
strings, the number of distinct keys is bounded by the application's scopes
rather than by its enums; past 512 of them the warnings stop, with one message
saying so, and resume at the next bundle change. Degradation is per value: the
labels that *are* present still resolve.

Use `TomObservableEnum.resolveTextOrNull` when the caller wants to supply its
own fallback rather than the raw name.

### In Forms

`tom_flutter_ui` exposes this as `TomEnumSelectableSource` and the
`enumPickerFor` family helper — `family.enumPickerFor('status',
TodoStatus.open, values: TodoStatus.values)` — which builds a dropdown whose
options are labelled from the bundle and which re-labels itself on a locale
change. That call belongs to `tom_flutter_ui`, not to this package.

## Muting Notifications

When making multiple changes, you may want to suppress notifications until
all changes are complete. This is called "muting".

### Basic Muting

```dart
final person = Person();
int notifications = 0;
final observer = person >> (obs) => notifications++;

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

person.removeObserver(observer);
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
person.batch(() {
  person.setValues({'name': 'Bob'});  // batches internally
  person.age | 30;
});  // still exactly one notification
```

Releasing more often than you muted is a no-op rather than an error — the
counter floors at zero, so a stray `unmute()` cannot leave the object in a
state where the next batch fails to suppress.

### Cascading to Members

For `TomClass`, `TomList`, and `TomMap`, muting propagates to children:

```dart
@tomReflector
class OrderItem extends TomClass {
  TomString name = TomString("");
}

@tomReflector
class Order extends TomClass {
  TomString orderId = TomString("");
  TomList<OrderItem> items = TomList();
  TomDouble total = TomDouble(0.0);
}

final order = Order();
int notifications = 0;
final observer = order >> (obs) => notifications++;

order.mute();

// All these changes are batched
order.orderId | "ORD-001";
order.items.add(OrderItem()..name.set("Widget"));
order.items.add(OrderItem()..name.set("Gadget"));
order.total | 99.99;

order.unmute();  // Single notification for all changes
print(notifications);  // 1

order.removeObserver(observer);
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
final newItems = [OrderItem()..name.set("Bolt"), OrderItem()..name.set("Nut")];

final count = order.batch(() {
  order.items.addAll(newItems);
  return order.items.length;   // batch() returns whatever the body returns
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
final rowList = TomList<TomString>();
rowList.addAll([TomString('a'), TomString('b')]);

rowList.batchSelf(() {
  // rowList is muted; its elements are not, so an observer watching
  // rowList[0] still hears this change immediately.
  rowList[0] | 'A';
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
| `TomClass.tomlist_state_error.set_not_allowed` | Cannot replace the backing list via `set` — use `<<` or `resetWith` |
| `TomClass.tommap_state_error.set_not_allowed` | Cannot replace the backing map via `set` — use `<<` |
| `TomClass.set_list_member_error.not_a_list` | Expected list for TomList member |
| `TomObservableEnum.enum_segment_error.unstable_type_name` | The enum overrides `toString()` and does not implement `TomEnumResourceSegment`, so no stable key segment can be derived |
| `TomObservableEnum.enum_value_error.not_in_values` | The value constructed or set is not one of the cell's permitted `values` |

## Class Hierarchy

The full tree — every leaf type and its exact `extends` / `implements` clauses
— lives in
**[the API reference](../api_reference/api_summary_observable.md#class-hierarchy)**,
which is the authoritative statement. It is not repeated here: a second copy is
a second thing to keep in step with the source.

What a reader of this guide needs are the three rules the tree encodes:

1. **Everything that notifies extends `TomObservable`**, and every *value*
   — scalar, nullable, timezone-aware, enum, range, or container — is a
   `TomObject<T>` beneath it. So [Muting Notifications](#muting-notifications)
   applies to all of them, and so does the operator vocabulary in
   [Operators](#operators) — subject to the per-receiver differences documented
   there, since the composites override `<<` and `TomClass` refuses the
   whole-value operators outright.

2. **`TomObserver` is a separate interface.** Being observable and being an
   observer are different capabilities. `TomClass`, `TomList` and `TomMap` have
   both: they are `TomObject`s that also implement `TomObserver`, and they
   register themselves as observers of their own members, elements and values.
   That dual role *is* the cascade — a change to a nested member notifies the
   container, which notifies its own observers in turn, all the way to the
   root. Nothing else in the system propagates changes upward.

3. **The containers are not `dart:core` collections.** `TomList<E>` implements
   `Iterable<E>`; `TomMap<K, V>` implements no `Map` interface at all. Both
   offer the familiar surface, but neither is assignable to `List<E>` or
   `Map<K, V>` — convert at the boundary with `toList()` / `get()`, each of
   which hands back a copy.

## Best Practices

### 1. Use Operators for Clean Code

Prefer operators over method calls for readability:

```dart
class NameField {
  final TomString name = TomString("");
  late TomFunctionObserver<TomObservable> _observer;

  void useOperators() {
    // ✓ Clean and idiomatic
    name | "John";
    String value = ~name;
    _observer = name >> (obs) => print("Changed! $value");  // field: kept alive
  }

  void useMethods() {
    // ✗ More verbose (but equivalent)
    name.set("John");
    String value = name.get();
    _observer = TomFunctionObserver((obs) => print("Changed! $value"));
    name.addObserver(_observer);
  }
}
```

Note that both spellings capture the observer. `>>` is shorter than
`addObserver(TomFunctionObserver(...))`, but it is not a licence to drop the
result: whichever form you use, the observer must be retained or the
notifications stop — see
[Memory Management](#memory-management--you-must-retain-the-observer).

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

// ✗ Legal, but gives up every element type check
TomList<TomObject> anything = TomList<TomObject>();
```

`TomList<dynamic>` is not an option at all: the element type is declared as
`E extends TomObject`, so the compiler rejects it. The widest thing you can
actually write is `TomObject` — and that only defers the type error to a cast
at the point of use.

### 5. Always Keep the Observer Reference

Observers are held weakly, so the reference you keep is what makes the
observation last. Put it in a field of an object that lives at least as long as
the observation, and end the observation explicitly:

```dart
class MyWidget {
  late TomFunctionObserver<TomObservable> _observer;
  final Person _person;

  MyWidget(this._person) {
    // Field, not a discarded expression: this is what keeps the callback alive.
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

The exception is an observer that is already an object you hold — a `TomClass`,
a `TomList`, or any class of your own implementing `TomObserver`. Those need no
extra handle. See
[Memory Management](#memory-management--you-must-retain-the-observer) for the
full contract, including why a local variable you never read again does not
count as retaining.

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
