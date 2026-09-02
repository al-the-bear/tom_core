# Tom Observable State Management

*Part of the [Tom Flutter UI documentation set](README.md).*

**Date:** 2026-03-18  
**Status:** Living document — will be extended as patterns evolve

This document describes the observable state management patterns currently implemented in the Tom framework, their architecture, their integration with Flutter, and the planned extensions for ACL-based form and widget resource resolution.

**Related:** [tom_ui_design_architecture.md](tom_ui_design_architecture.md) — the UI architecture document that builds on this state management foundation. It covers identity, authorization, resources, widget architecture, forms, actions, screen definitions, data sources, theming, and debug tooling.

---

## Table of Contents

- [Tom Observable State Management](#tom-observable-state-management)
  - [Table of Contents](#table-of-contents)
  - [Part 1 — Tom Observer/Observable Core](#part-1--tom-observerobservable-core)
    - [Architecture Overview](#architecture-overview)
    - [TomObservable — Base Class](#tomobservable--base-class)
    - [TomObserver — Listener Interface](#tomobserver--listener-interface)
    - [TomFunctionObserver — Callback Wrapper](#tomfunctionobserver--callback-wrapper)
    - [Operator Syntax](#operator-syntax)
  - [Part 2 — Observable Value Types](#part-2--observable-value-types)
    - [TomObject\<T\> — Generic Base](#tomobjectt--generic-base)
    - [Primitive Wrappers](#primitive-wrappers)
    - [Nullable Wrappers](#nullable-wrappers)
    - [DateTime and Timezone Types](#datetime-and-timezone-types)
    - [Range Types](#range-types)
  - [Part 3 — TomClass — Observable Domain Objects](#part-3--tomclass--observable-domain-objects)
    - [Automatic Member Registration](#automatic-member-registration)
    - [Nested Change Propagation](#nested-change-propagation)
    - [Bulk Updates and JSON Serialization](#bulk-updates-and-json-serialization)
    - [Muting Notifications](#muting-notifications)
  - [Part 4 — Observable Collections](#part-4--observable-collections)
    - [TomList\<E\>](#tomliste)
    - [TomMap\<K, V\>](#tommapk-v)
  - [Part 5 — Flutter Integration: Current Patterns](#part-5--flutter-integration-current-patterns)
    - [TomObservingWidget](#tomobservingwidget)
    - [ValueListenableObserver — Adapter to Flutter](#valuelistenableobserver--adapter-to-flutter)
    - [Tom Forms Framework — TomForm / TomField (tom_flutter_ui)](#tom-forms-framework--tomform--tomfield-tom_flutter_ui)
    - [TomTextResourceProvider / TomConfigResourceProvider](#tomtextresourceprovider--tomconfigresourceprovider)
    - [Global State Extension Pattern](#global-state-extension-pattern)
  - [Part 6 — Class Hierarchy](#part-6--class-hierarchy)
  - [Part 7 — Reflection Dependency](#part-7--reflection-dependency)
  - [Part 8 — Planned Extensions](#part-8--planned-extensions)
    - [8.1 — ValueNotifier/ChangeNotifier Compatibility Layer](#81--valuenotifierchangenotifier-compatibility-layer)
    - [8.2 — ACL Named Widget Integration via TomForm](#82--acl-named-widget-integration-via-tomform)
    - [8.3 — Self-Discovering Form Fields with Resource Resolution](#83--self-discovering-form-fields-with-resource-resolution)
    - [8.4 — General ACL-Aware Widgets with Auto-Resource Resolution](#84--general-acl-aware-widgets-with-auto-resource-resolution)

---

## Part 1 — Tom Observer/Observable Core

**Package:** `tom_core_kernel`  
**Source:** `lib/src/tombase/observable/tom_observable.dart`

### Architecture Overview

The Tom observable system implements a classic Observer pattern with these design choices:

1. **WeakReference-based listener storage** — observers are held via `WeakReference`, so a dead observer never keeps the observable's list growing; the corollary is that *you* must retain every observer you register (see [Memory management](#tomobservable--base-class))
2. **Operator-based API** — uses `~`, `|`, and `>>` operators for get, set, and subscribe
3. **Muting support** — batch changes can be wrapped in `mute()`/`unmute()` to emit a single notification
4. **Hierarchical propagation** — `TomClass`, `TomList`, and `TomMap` automatically observe their members and propagate child changes upward

### TomObservable — Base Class

Any class that needs to notify others of state changes extends `TomObservable`.

```dart
class Counter extends TomObservable {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyObservers();
  }
}
```

**Methods:**

| Method | Description |
|--------|-------------|
| `addObserver(TomObserver)` | Register an observer |
| `removeObserver(TomObserver)` | Unregister an observer |
| `notifyObservers([String? message])` | Notify all registered observers |
| `mute()` | Suppress notifications; tracks dirty state |
| `unmute()` | Resume notifications; fires if dirty |
| `isMuted` → `bool` | Whether currently muted |

**Memory management — you must retain the observer.** Observers are stored as
`WeakReference<TomObserver>`, so the observable does **not** keep your observer
alive. An observer that nothing else references is garbage-collected, and from
that moment it silently stops being notified — no exception, no log line. The
automatic pruning of collected references keeps the observable's list tidy; it
is not a promise that your observer is still in it.

Keep the observer (or the wrapper `>>` returns) in a field that lives as long
as the observation, and end it with `removeObserver`. Observers that are
objects you already hold — a widget state, a `TomList` registering itself on
its elements — need no extra handle. See
[`tom_core_kernel/doc/observable/observable.md`](../../tom_core_kernel/doc/observable/observable.md#memory-management--you-must-retain-the-observer)
for the full contract, including why a local variable you never read again is
not sufficient retention under AOT.

### TomObserver — Listener Interface

```dart
abstract class TomObserver<T extends TomObservable> {
  void onNotify(T observable);
}
```

The type parameter provides type safety — a `TomObserver<Counter>` receives the observable as a typed `Counter` in `onNotify`.

### TomFunctionObserver — Callback Wrapper

Wraps a closure as a `TomObserver`, enabling the `>>` operator syntax:

```dart
final counter = Counter();

// These are equivalent:
counter >> (obs) => print('Changed!');

final observer = TomFunctionObserver<Counter>((obs) => print('Changed!'));
counter.addObserver(observer);
```

The `>>` operator returns the `TomFunctionObserver`, allowing the caller to keep a reference for later removal.

### Operator Syntax

| Operator | Usage | Description |
|----------|-------|-------------|
| `~obj` | Get value | Prefix unary operator on `TomObject<T>` |
| `obj()` | Get value | Call operator (alternative to `~`) |
| `obj \| value` | Set value | Sets value and notifies observers |
| `obj >> callback` | Subscribe | Adds a callback function as an observer |

```dart
final name = TomString("John");

// Get
String v1 = ~name;        // "John"
String v2 = name();       // "John"
String v3 = name.get();   // "John"

// Set (triggers notification)
name | "Jane";
name.set("Jane");

// Subscribe
name >> (obs) => print("Changed to: ${~name}");
```

---

## Part 2 — Observable Value Types

**Package:** `tom_core_kernel`  
**Source:** `lib/src/tombase/observable/tom_observable_objects.dart`

### TomObject\<T\> — Generic Base

All observable value wrappers extend `TomObject<T>`, which extends `TomObservable`:

```dart
abstract class TomObject<T> extends TomObservable {
  T _value;

  T get();             // Current value
  T call();            // Current value (call operator)
  T set(T value);      // Set and notify
  T? getOrNull();      // Value or null
  bool get isNull;     // Whether value is null

  T operator ~();                          // Get
  T operator |(T value);                   // Set
  TomFunctionObserver operator >>(fn);     // Subscribe
}
```

### Primitive Wrappers

| Class | Wraps | Default |
|-------|-------|---------|
| `TomString` | `String` | `""` |
| `TomInt` | `int` | `0` |
| `TomDouble` | `double` | `0.0` |
| `TomBool` | `bool` | `false` |
| `TomDateTime` | `DateTime` | Current time |

```dart
final name = TomString("Alice");
final age = TomInt(30);
final active = TomBool(true);

name | "Bob";        // triggers notification
print(~age);         // 30
```

### Nullable Wrappers

| Class | Wraps |
|-------|-------|
| `TomNString` | `String?` |
| `TomNInt` | `int?` |
| `TomNDouble` | `double?` |
| `TomNBool` | `bool?` |
| `TomNDateTime` | `DateTime?` |

```dart
final email = TomNString(null);
if (email.isNull) { /* not set */ }
email | "alice@example.com";
String? val = email.getOrNull();
```

### DateTime and Timezone Types

**Non-nullable timezone-aware:**

| Class | Wraps | Serialization Prefix |
|-------|-------|---------------------|
| `TomOZonedDate` | `TomZonedDate` | `@D@` |
| `TomOZonedTime` | `TomZonedTime` | `@T@` |
| `TomOZonedDateTime` | `TomZonedDateTime` | `@X@` |

**Nullable variants:** `TomNOZonedDate`, `TomNOZonedTime`, `TomNOZonedDateTime`

All support `setByString(String s)` for deserialization from prefixed strings.

### Range Types

| Class | Fields | Field Type |
|-------|--------|------------|
| `TomDateRange` | `startDate`, `endDate` | `TomNOZonedDate` |
| `TomTimeRange` | `startTime`, `endTime` | `TomNOZonedTime` |
| `TomDateTimeRange` | `startDateTime`, `endDateTime` | `TomNOZonedDateTime` |

Range types extend `TomClass` — their fields are automatically registered and observed.

---

## Part 3 — TomClass — Observable Domain Objects

`TomClass` extends `TomObject` and implements `TomObserver`. It is the primary mechanism for creating observable domain models.

### Automatic Member Registration

When a `TomClass` is instantiated, reflection (`@tomReflect`) discovers all `TomObject` fields and:

1. Registers them as members via `getMembers()`
2. Calls `startSelfObservation()` which registers the `TomClass` as an observer on each member
3. Returns a member map for programmatic access

```dart
@tomReflect
class Person extends TomClass {
  TomString name = TomString("");
  TomInt age = TomInt(0);
  TomBool isActive = TomBool(true);
}
```

The class **knows its own structure** — it can enumerate, read, and write all its fields at runtime.

### Nested Change Propagation

Changes to any member (or nested `TomClass` member) propagate up to the parent:

```dart
@tomReflect
class Address extends TomClass {
  TomString city = TomString("");
  TomString zip = TomString("");
}

@tomReflect
class Customer extends TomClass {
  TomString name = TomString("");
  Address address = Address();
}

final customer = Customer();
customer >> (obs) => print("Customer changed!");

customer.address.city | "Berlin";  // Prints: "Customer changed!"
```

The propagation chain is: `city.notifyObservers()` → `address.onNotify()` → `address.notifyObservers()` → `customer.onNotify()` → `customer.notifyObservers()` → callback fires.

### Bulk Updates and JSON Serialization

```dart
final person = Person();

// Bulk update (single notification if muted, or one per field if not)
person.setValues({'name': 'Alice', 'age': 30, 'isActive': true});

// Get all values
Map<String, dynamic> data = person.getValues();

// JSON round-trip
String json = person.toJson().toString();
person.fromJson('{"name": "Bob", "age": 25}');
```

### Muting Notifications

```dart
final person = Person();
int count = 0;
person >> (obs) => count++;

// Without muting: 3 notifications
person.name | "A";
person.age | 1;
person.isActive | false;
// count == 3

// With muting: 1 notification
count = 0;
person.mute();
person.name | "B";
person.age | 2;
person.isActive | true;
person.unmute();
// count == 1
```

For `TomClass`, `TomList`, and `TomMap`, muting propagates to contained children.

---

## Part 4 — Observable Collections

### TomList\<E\>

An observable list that:
- Implements the full `List<E>` interface
- Automatically observes all contained elements (if they are `TomObservable`)
- Notifies on structural changes (add, remove, reorder) and on element value changes

```dart
final tasks = TomList<Task>();
tasks >> (obs) => print("Tasks changed!");

tasks.add(Task()..title | "Buy groceries");     // "Tasks changed!"
tasks[0].title | "Buy organic groceries";        // "Tasks changed!" (element change)
```

**Constructors:** `TomList()`, `TomList.from(...)`, `TomList.of(...)`, `TomList.ofList(...)`

**Operators:** `list + otherList` for concatenation.

### TomMap\<K, V\>

An observable map that:
- Provides full `Map<K, V>` interface
- Automatically observes all values (not keys)
- Notifies on structural changes and value mutations

```dart
final users = TomMap<String, User>();
users >> (obs) => print("Users changed!");

users['alice'] = User()..name | "Alice";   // "Users changed!"
users['alice']!.score | 100;                // "Users changed!" (value change)
```

**Constructors:** `TomMap()`, `TomMap.from(...)`, `TomMap.of(...)`, `TomMap.ofMap(...)`

**Restriction:** `set()` throws `TomObservableException` — cannot replace the entire map. Use `clear()` + `addAll()` instead.

**Note:** The legacy `tom_core_flutter.TomForm` extended `TomMap<String, TomField>`. The current Tom Forms Framework in `tom_flutter_ui` does **not** follow that shape — `TomForm<T extends TomClass>` is a plain `TomClass` whose field members are discovered by reflection and exposed via a `fields` map keyed by member name. See the "Tom Forms Framework" subsection in Part 5 below and [tom_ui_widgets_forms.md](tom_ui_widgets_forms.md) for the canonical spec.

---

## Part 5 — Flutter Integration: Current Patterns

> For the full widget architecture built on top of these integration patterns — including authorization-aware widgets, the action system, screen definitions, and the theming layer — see [tom_ui_design_architecture.md](tom_ui_design_architecture.md).

**Packages:** `tom_core_flutter` and `tom_flutter_ui`  
**Source:** `tom_core_flutter/lib/src/tomclient/observing/` and `tom_flutter_ui/lib/src/forms/`

### TomObservingWidget

A `StatefulWidget` that listens to a `TomObservable` substate and rebuilds via `setState` when notified.

**Source:** `tom_core_flutter/lib/src/tomclient/observing/tom_observing_widget.dart`

```dart
class TomObservingWidget<T extends TomObservable> extends StatefulWidget {
  final Widget Function(T state) child;
  final T subState;
  // ...
}
```

The state class implements `TomObserver` and registers itself on the observable in the constructor. On `onNotify`, it calls `setState(() {})` to trigger a rebuild.

**Usage (from tom_uam_client):**

```dart
TomObservingWidget<BlocFormData>(
  subState: state.formData,
  child: (BlocFormData s) => Column(
    children: [
      Text("Username ${~s.username}"),
      Text("Password ${~s.password}"),
    ],
  ),
)
```

This rebuilds only when `formData` (or any of its members) changes, without requiring a `StreamBuilder` or external state management library.

### ValueListenableObserver — Adapter to Flutter

Bridges the Tom observable system to Flutter's `ValueListenable<T>` interface, enabling use with `ValueListenableBuilder`.

**Source:** `tom_core_flutter/lib/src/tomclient/observing/value_listenable_observer.dart`

```dart
class ValueListenableObserver<T extends TomObservable>
    implements TomObserver<T>, ValueListenable<T> {
  ValueListenableObserver(this.observable) {
    observable.addObserver(this);
  }
  // Delegates addListener/removeListener to a voidCallback
  // value getter returns the observable itself
}
```

**Usage (from loginformpage.dart):**

```dart
ValueListenableBuilder<AppErrorInfo>(
  valueListenable: ValueListenableObserver<AppErrorInfo>(state.error),
  builder: (context, errorInfo, child) {
    return Column(
      children: [
        Text(~errorInfo.errorKey),
        Text(~errorInfo.errorMessage),
      ],
    );
  },
)
```

This wraps any `TomObservable` (here `AppErrorInfo extends TomClass`) into a `ValueListenable`, making it compatible with Flutter's standard `ValueListenableBuilder`.

### Tom Forms Framework — TomForm / TomField (tom_flutter_ui)

**Source:** `tom_flutter_ui/lib/src/forms/`  
**Full spec:** [tom_ui_widgets_forms.md](tom_ui_widgets_forms.md)

The `TomForm` / `TomField` pattern in `tom_core_flutter` is **superseded** by the Tom Forms Framework in `tom_flutter_ui`. The legacy wrappers (`TomFormStringInputClassic`, `TomFormEmailStringInputClassic`, `TomFormPasswordStringInputClassic`, `TomFormIntInputClassic`, `TomFormDoubleInputClassic`) still compile — `@Deprecated` — for the Classic-field coexistence story in Demo C, but no new code should add to them.

**Shape of the new framework (condensed; see the full spec for §-level detail):**

- **`TomForm<T extends TomClass>`** is an abstract `TomClass` with a `formId`, a `basePath`, a lazy `fields` map populated from `@tomReflector`-discovered members, a built-in event bus (`addListener(TomFormEventListener)` / `changes` / `form.events`), and a full lifecycle: `bind(target)` → `validate()` → `save()` / `discard()` / `unbind()` / `commit()`. Forms aggregate `isDirty`, `isValid`, `dirtyFields`, `fieldsWithErrors`, an `initialSnapshot`, and run cross-field validation via `validateForm()`.
- **`TomField<T extends TomObservable>`** extends `TomObject<T>` and implements `TomAuthorizable`. Identity is `(tomId, basePath)` — `tomId` is the short id the caller passed, `basePath` is the scope-prefixed full path used for resource and auth lookups (`"$basePath.<suffix>"`). Fields carry validators, debounce timers (fast + slow), an effective auth chain (resource → group → form → authorizer → UI-state controller), and emit `FieldValueChangedEvent` / `FieldValidatedEvent` / `FieldAuthChangedEvent` / lifecycle events on the owning form's bus.
- **Concrete fields** in the spec-aligned tier: `TomFormStringInput`, `TomFormStringDropdown` (and — Phase 2+ — checkbox/switch/radio/chips, numeric, date/time, selection, file, list variants). Each field instantiates **at its declaration site** with `form: this`, so the base-class constructor derives `scope` from `form.basePath` — no reliance on zone scope at lazy-init time.
- **Validation** is a sealed `ValidationResult` (`Pristine` / `Success` / `Error(errorKey, params)` / `Pending`) plus sync `Validator<T>` and explicit `SlowValidator<T>` wrappers (longer debounce + `Pending` transition). `Validators.compose`, `.required`, `.email`, `.minLength`, `.maxLength`, `.pattern`, `.min`, `.max` are provided. Cross-field errors return a `FormValidationError(errorKey, fields)` from `validateForm`.
- **Styling** goes through `TomFormStyle` — a nested `TomFieldStyle` (`labelPlacement`, placements / indicators, spacing, borders, `borderRadius`, typography, hint tuning, `disabledOpacity`, `readOnlyOpacity`, `readOnlyBackground`, error visuals) plus per-widget partial overrides (`TomStringInputStyle`, `TomDropdownStyle`, …). Presets `material3` / `compact` / `bordered`. Resolution is `programmatic → JSON overlay → withTheme(ThemeData)` — applied by `TomFormStyleScope`, which also owns the breakpoint ladder and cs.* colour-token substitution.
- **Layout hand-off**: fields are Flutter widgets via `field.widget` and drop straight into a `TomAclBuilder<T extends TomScreenElementsProvider>` where `T` is the `TomForm` subclass. See [acl_design_specification.md §31](acl_design_specification.md) for the container-level authorization + resource plumbing and the form-alignment rules.

**Minimal snapshot (for readers of this spec):**

```dart
@tomReflector
class CustomerForm extends TomForm<TomClass> {
  CustomerForm() : super(formId: 'customer');

  late final fullName = TomFormStringInput(
    'fullName', '',
    form: this,
    validators: [Validators.required(), Validators.minLength(2)],
  );

  late final email = TomFormStringInput(
    'email', '',
    form: this,
    validators: [Validators.required(), Validators.email()],
    keyboardType: TextInputType.emailAddress,
  );

  @override
  Future<List<FormValidationError>> validateForm() async { … }
}

// Usage
final form = TomScope.withScope('checkout', () => CustomerForm());
form.bind(customerState);
final ok = await form.save();
```

Resource keys now live under the field's **basePath**, e.g. `checkout.customer.email.label`, `checkout.customer.email.hint`, `checkout.customer.email.description`, `checkout.customer.email.error.required`, etc. The legacy `{formName}.{fieldName}.<suffix>` convention continues to work for Classic fields only.

### TomTextResourceProvider / TomConfigResourceProvider

**Source:** `tom_core_kernel/lib/src/tombase/resources/tom_resource_provider.dart`

Singleton-based resource management using hierarchical dot-notation keys.

```dart
// Install once at startup, before anything reads text.
TomTextResourceProvider.setAppResourceProvider(
  TomTextResourceProvider.load(() => loadFromJson('strings.json')),
);

// Access anywhere
final resources = TomTextResourceProvider.getAppResources();
String label = resources.getText('form.username.label');
bool hasIt = resources.exists('form.username.helperText');
```

**TomConfigResourceProvider** — identical pattern for configuration values (returns `Object`, not just `String`).

Both support:
- Singleton pattern with `getAppResources()` / `getAppConfig()`
- Deferred loading via the `loader` callback or the `.load(fn)` constructor
- Direct initialization via `.from(Map)` constructor
- Hierarchical key resolution via `getObjectFromTree()`

Installation is explicit: the getters throw
`resources.text_provider.not_installed` /
`resources.config_provider.not_installed` rather than creating a provider on
first access, so a widget reading a label before the app bootstrapped says so
instead of rendering raw keys. Widget tests in this package get an empty bundle
from `test/flutter_test_config.dart`; tests that care about specific text
install their own in `setUp`.

### Global State Extension Pattern

**Source:** `tom_uam/tom_uam_client/lib/uam/sample_app_state.dart`

The UAM client demonstrates a global state pattern:

```dart
@tomReflect
class AppState extends TomClass {
  static AppState appState = AppState();

  AppErrorInfo error = AppErrorInfo();
  BlocFormData formData = BlocFormData();
  UserSettings userSetting = UserSettings();
  TomInt counter = TomInt(0);
  TomObject<TomPrincipal> currentUser = TomObject(_initialPrincipal);
  BottomSlideFormState bottomSlideFormState = BottomSlideFormState();
}

// Global access via extension
extension StateAccessor on Object {
  AppState get state => AppState.appState;
}
```

This provides:
- A singleton observable state tree (`AppState.appState`)
- Sub-states as `TomClass` members (auto-observed by parent)
- Access from any widget via the `state` extension getter
- Reactive UI binding via `TomObservingWidget` or `ValueListenableObserver`

**Sub-state example:**

```dart
@tomReflect
class AppErrorInfo extends TomClass {
  TomBool hasError = TomBool(false);
  TomString errorKey = TomString('');
  TomString errorMessage = TomString('');

  void reset() {
    setValues({"hasError": false, "errorKey": "", "errorMessage": ""});
  }

  void fillFromException(Object e) {
    if (e is TomClientUIException) {
      state.error.hasError | true;
      state.error.errorKey | e.key;
      state.error.errorMessage | e.defaultUserMessage;
    } else {
      state.error.hasError | true;
      state.error.errorKey | "error.unknown";
      state.error.errorMessage | "$e";
    }
  }
}
```

**Usage in widgets** (from `loginformpage.dart`):

```dart
// Option A: Using TomObservingWidget (Tom-native)
TomObservingWidget<AppErrorInfo>(
  subState: state.error,
  child: (AppErrorInfo e) => Column(
    children: [Text(~e.errorKey), Text(~e.errorMessage)],
  ),
)

// Option B: Using ValueListenableBuilder via adapter
ValueListenableBuilder<AppErrorInfo>(
  valueListenable: ValueListenableObserver<AppErrorInfo>(state.error),
  builder: (context, e, child) => Column(
    children: [Text(~e.errorKey), Text(~e.errorMessage)],
  ),
)
```

---

## Part 6 — Class Hierarchy

```
TomObserver<T> (interface)
├── TomFunctionObserver<T>  — Wraps callback closures
├── TomClass                — Observes its own TomObject members
├── TomList<E>              — Observes its elements
├── TomMap<K, V>            — Observes its values
└── TomObservingWidgetState — Flutter StatefulWidget state

TomObservable (base class)
└── TomObject<T>
    ├── TomString, TomInt, TomDouble, TomBool, TomDateTime
    ├── TomNString, TomNInt, TomNDouble, TomNBool, TomNDateTime
    ├── TomOTimezoned<TZ>
    │   ├── TomOZonedTime, TomOZonedDate, TomOZonedDateTime
    │   └── TomNOTimezoned<TZ>
    │       └── TomNOZonedTime, TomNOZonedDate, TomNOZonedDateTime
    ├── TomClass (also implements TomObserver)
    │   ├── TomDateRange, TomTimeRange, TomDateTimeRange
    │   ├── TomForm<T extends TomClass>
    │   │   └── (user form classes, e.g. CustomerForm, ValidationForm)
    │   ├── AppState, AppErrorInfo, BlocFormData, …  (user domain)
    │   └── BottomSlideFormState
    ├── TomList<E> (also implements TomObserver)
    ├── TomMap<K, V> (also implements TomObserver)
    └── TomField<T> (also implements TomAuthorizable — tom_flutter_ui)
        ├── TomFormStringField
        │   ├── TomFormStringInput
        │   └── TomFormStringDropdown
        ├── (Phase 2+ field types)
        └── TomTextFormFieldBase<T> — Classic tier (deprecated)
            ├── TomFormStringInputClassic, TomFormEmailStringInputClassic,
            ├── TomFormPasswordStringInputClassic, TomFormIntInputClassic,
            └── TomFormDoubleInputClassic

ValueListenable<T> (Flutter interface)
└── ValueListenableObserver<T>  — Adapter: TomObservable → ValueListenable
```

---

## Part 7 — Reflection Dependency

> The UI architecture uses reflection for screen element discovery, ActionController wiring, undo/redo snapshots, debug inspection, and semantic annotations. See [§2 in tom_ui_design_architecture.md](tom_ui_design_architecture.md#2-observable-state-and-reflection--the-foundation) for the UI-specific implications.

**Current state:** `TomClass` relies on the `@tomReflect` annotation and `TomReflectionInfo` for automatic member discovery. This provides:

- Zero-boilerplate member registration (no manual `registerMember()` calls)
- JSON serialization/deserialization via `setValues()` / `getValues()`
- Runtime type introspection for nested `TomObject` fields

**The reflection package (`tom_reflection`)** requires code generation and adds a transitive dependency that may not be appropriate for all consumers — in particular, the widget library (`tom_flutter_ui`) should not introduce a reflection dependency.

**Implications for the widget library:**

- Widgets in `tom_flutter_ui` cannot use `@tomReflector` or `TomReflectionInfo`.
- **Forms are the exception** — `TomForm<T>` extends `TomClass`, which means its subclasses carry `@tomReflector` and rely on `tom_reflection` for member discovery (`TomClass.startSelfObservation`). This is the only reflection touch-point in the framework tier; concrete field implementations (`TomFormStringInput`, …) are plain Flutter widgets that do not introspect themselves.
- For non-form widgets — menus, dialogs, navigation, etc. — self-registration still uses explicit mechanisms (constructor IDs, convention-based naming, `TomScope.withScope`) so they stay reflection-free.

---

## Part 8 — Planned Extensions

The following extensions are planned to bring the Tom observable state management system forward as a complete solution for ACL-based UI development.

> **Implementation status (updated 2026-04-07):** Extensions 8.3 and 8.4 are now largely implemented in `tom_flutter_ui` through `TomNodeBase` (resource resolution via `basePath` + suffixes) and the form system (`TomForm`/`TomField` with resource-aware field anatomy). Extension 8.2 is partially implemented through `TomScreenElementsProvider`. Extension 8.1 remains planned.

> Several planned extensions integrate with the UI architecture's form system (§9), action system (§10), and screen definitions (§11). See [tom_ui_design_architecture.md](tom_ui_design_architecture.md) for the UI-side design.

### 8.1 — ValueNotifier/ChangeNotifier Compatibility Layer

**Goal:** Make Tom observables fully interchangeable with Flutter's native notification system.

**Current state:** `ValueListenableObserver<T>` already adapts `TomObservable` → `ValueListenable<T>`, allowing use with `ValueListenableBuilder`. This is a one-direction adapter.

**Planned:**

- **Bidirectional adapter** — wrap a `ValueNotifier<T>` as a `TomObservable`, so existing Flutter code that uses `ValueNotifier` can be observed by `TomObserver`-based code
- **ChangeNotifier adapter** — wrap any `ChangeNotifier` (e.g., `TextEditingController`, `ScrollController`) as a `TomObservable`
- **Mixin-based approach** — a `TomListenableMixin` that can be applied to any `TomObservable` to directly implement `Listenable`, bypassing the need for a wrapper object
- These should live in `tom_core_flutter` (not `tom_core_kernel`) to keep the kernel Flutter-free

### 8.2 — ACL Named Widget Integration via TomForm

**Goal:** Use the `TomForm` pattern to provide named widgets that the ACL JSON layout system can reference by name.

**Context:** The ACL JSON Layout format (see `_ai/quests/flutter_ui/acl_json_layout.md`) resolves widgets by string name from a `Map<String, Widget>`:

```dart
final widget = layout.build(widgets: {
  'firstName': firstNameField,
  'lastName': lastNameField,
  'submit': submitButton,
});
```

**Planned integration:**

- A `TomForm` instance generates its widget map via `getFields()` (already returns `List<Widget>`) — extend this to return `Map<String, Widget>` keyed by field name
- This map is passed directly to `AclJsonLayout.build(widgets: form.getWidgetMap())`
- The form's field names become the ACL component `ref` names
- The form handles validation, state sync, and error display; the ACL handles layout
- This cleanly separates **what widgets exist** (TomForm) from **how they are arranged** (ACL JSON)

### 8.3 — Self-Discovering Form Fields with Resource Resolution

**Goal:** Form fields automatically resolve all their UI resources (labels, error messages, helper texts, placeholders) from a structured resource key hierarchy based on their identity within the container tree.

**Identity model — a field knows:**

| Component | Source | Example |
|-----------|--------|---------|
| Container ID | ACL container `setAclId()` | `"userProfile"` |
| Form name | `TomForm` / `TomField.formName` | `"registration"` |
| Field name | `TomField.fieldName` | `"email"` |

**Resource key structure (constants per field type):**

```
{containerId}.{formName}.{fieldName}.label
{containerId}.{formName}.{fieldName}.placeholder
{containerId}.{formName}.{fieldName}.helperText
{containerId}.{formName}.{fieldName}.tooltip
{containerId}.{formName}.{fieldName}.errors.required
{containerId}.{formName}.{fieldName}.errors.pattern
{containerId}.{formName}.{fieldName}.errors.minLength
{containerId}.{formName}.{fieldName}.errors.maxLength
{containerId}.{formName}.{fieldName}.errors.validEmail
{containerId}.{formName}.{fieldName}.errors.custom
```

**Resolution cascade:** When looking up a key, the system tries from most specific to least specific:

1. `{containerId}.{formName}.{fieldName}.label` — fully qualified
2. `{formName}.{fieldName}.label` — form-scoped (current behavior)
3. `{fieldName}.label` — field-only (global fallback)
4. Key itself as display text (development fallback)

**The substructure suffixes** (`.label`, `.errors.required`, etc.) are determined by field type and are defined as constants:

```dart
abstract class TomFieldResourceKeys {
  static const label = 'label';
  static const placeholder = 'placeholder';
  static const helperText = 'helperText';
  static const tooltip = 'tooltip';

  // Error subkeys by validation type
  static const errorRequired = 'errors.required';
  static const errorPattern = 'errors.pattern';
  static const errorMinLength = 'errors.minLength';
  static const errorMaxLength = 'errors.maxLength';
  static const errorValidEmail = 'errors.validEmail';
  static const errorMinValue = 'errors.minValue';
  static const errorMaxValue = 'errors.maxValue';
}
```

**Field types and their resource subkeys:**

| Field Type | Extra Resource Keys |
|------------|-------------------|
| `TomFormStringInput` | `.label`, `.placeholder`, `.helperText`, `.errors.*` |
| `TomFormStringInput` + `Validators.email()` | + `.errors.validEmail` |
| `TomFormStringInput(obscureText: true)` + `Validators.minLength()` | + `.errors.minLength` |
| `TomFormIntInput` / `TomFormDoubleInput` | + `.errors.minValue`, `.errors.maxValue` |
| `TomFormStringDropdown` / `TomFormEnumDropdown` | + `.options.{value}` for option labels |
| `TomFormBoolCheckbox` | `.label`, `.helperText` |
| `TomFormDateTextInput` | `.label`, `.helperText`, `.errors.dateRange` |
| `TomFormBoolSwitch` | `.label`, `.onLabel`, `.offLabel` |

**After constructing a widget tree, all resource keys are known** — this enables:
- Pre-validation of resource completeness (which keys are missing?)
- Generation of resource file templates
- Static analysis of resource usage

### 8.4 — General ACL-Aware Widgets with Auto-Resource Resolution

**Goal:** Extend the self-discovery pattern beyond form fields to a significant subset of standard Flutter widgets, so any widget placed in an ACL container can resolve its own labels, tooltips, and configuration from the resource system.

**Identity model for non-form widgets:**

| Component | Source | Example |
|-----------|--------|---------|
| Container ID | ACL container hierarchy | `"userProfile"` |
| Widget ID | ACL component `id()` | `"saveButton"` |
| Widget type | Determined by widget class | `"button"` |

**Resource key structure for non-form widgets:**

```
{containerId}.{widgetId}.label
{containerId}.{widgetId}.tooltip
{containerId}.{widgetId}.icon       → icon name/code reference
{containerId}.{widgetId}.enabled    → config: is this widget enabled
{containerId}.{widgetId}.visible    → config: is this widget visible
```

**Widget type-specific resource subkeys:**

| Widget Type | Resource Keys |
|-------------|--------------|
| `TomElevatedButton` | `.label`, `.tooltip`, `.icon`, `.confirmMessage` |
| `TomLabel` / `TomText` | `.text`, `.style` (config reference) |
| `TomIcon` | `.icon`, `.tooltip`, `.semanticLabel` |
| `TomCard` / `TomPanel` | `.title`, `.subtitle` |
| `TomTab` | `.label`, `.icon`, `.tooltip` |
| `TomMenuItem` | `.label`, `.icon`, `.shortcut`, `.tooltip` |
| `TomBadge` | `.text`, `.tooltip` |
| `TomChip` | `.label`, `.tooltip` |
| `TomDivider` | `.label` (optional section divider title) |

> **Shipped-name note (verified 2026-07-15):** `TomText`, `TomIcon`, `TomCard`,
> `TomTab`, `TomBadge`, `TomChip`, and `TomDivider` ship in `tom_flutter_ui`.
> `TomLabel`, `TomPanel`, and `TomMenuItem` are **proposed names that do not ship** —
> use `TomText` (label), `TomCard` / `TomContainerBase` (panel), and the
> navigation widgets / `TomTab` (menu item) respectively. This whole part is a
> planned extension, so the resource-key auto-resolution it describes is design,
> not shipped API.

**Placement modes:**

1. **Inside a form** — widget participates in form validation/state; resource keys include form name
2. **Outside a form, within same page/route** — widget uses container/widget-id based keys; no form context
3. **Both modes supported simultaneously** — a button inside a form section and another button in the page toolbar both resolve their own resources independently

**Resolution mechanism:**

Widgets access the ACL container hierarchy via `InheritedWidget` (the ACL already provides container context). The widget reads:
- Its own component ID from the ACL component metadata
- The container ID hierarchy from the ACL scope chain
- Resolves resource keys through `TomTextResourceProvider` with the cascade in §8.3

This means after constructing the complete widget tree, every widget in the tree knows:
- Its full identity path: `{rootContainerId}.{nestedContainerId}.{widgetId}`
- Which resource keys it will look up
- Which resource keys are type-determined constants

**Benefits:**
- Resource files can be generated or validated automatically from a layout definition
- Changing a container ID or widget ID automatically updates all resource lookups
- Consistent text/label resolution across the entire application without manual wiring
- Server-driven layouts (ACL JSON) and server-driven content (resources) work together seamlessly
