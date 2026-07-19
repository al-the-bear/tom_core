# Flutter and Dart Listener/Observer Patterns

*Part of the [Tom Flutter UI documentation set](README.md).*

**Date:** 2026-03-18

This document provides a comprehensive reference for all observer/observable and listener patterns available in Flutter and pure Dart, covering their design, usage, and trade-offs.

---

## Table of Contents

- [Part 1 — Pure Dart Patterns](#part-1--pure-dart-patterns)
  - [Stream / StreamController](#stream--streamcontroller)
  - [Future](#future)
  - [StreamTransformer and Stream Operators](#streamtransformer-and-stream-operators)
- [Part 2 — Flutter Foundation Patterns](#part-2--flutter-foundation-patterns)
  - [Listenable](#listenable)
  - [ChangeNotifier](#changenotifier)
  - [ValueNotifier\<T\>](#valuenotifiert)
  - [ValueListenable\<T\>](#valuelistenablet)
  - [Animation\<T\> / AnimationController](#animationt--animationcontroller)
- [Part 3 — Flutter Widget-Tree Patterns](#part-3--flutter-widget-tree-patterns)
  - [InheritedWidget](#inheritedwidget)
  - [InheritedNotifier\<T\>](#inheritednotifiert)
  - [InheritedModel\<T\>](#inheritedmodelt)
  - [NotificationListener / Notification](#notificationlistener--notification)
  - [StreamBuilder](#streambuilder)
  - [FutureBuilder](#futurebuilder)
  - [ValueListenableBuilder](#valuelistenablebuilder)
  - [ListenableBuilder / AnimatedBuilder](#listenablebuilder--animatedbuilder)
- [Part 4 — Flutter Lifecycle and Navigation Observers](#part-4--flutter-lifecycle-and-navigation-observers)
  - [WidgetsBindingObserver](#widgetsbindingobserver)
  - [NavigatorObserver / RouteObserver / RouteAware](#navigatorobserver--routeobserver--routeaware)
- [Part 5 — Comparison and Selection Guide](#part-5--comparison-and-selection-guide)

---

## Part 1 — Pure Dart Patterns

These patterns are available in `dart:async` and `dart:core` without any Flutter dependency.

### Stream / StreamController

The primary reactive pattern in Dart. A `Stream` emits a sequence of asynchronous events that listeners can subscribe to.

**Core Classes:**

| Class | Purpose |
|-------|---------|
| `Stream<T>` | An asynchronous sequence of events |
| `StreamController<T>` | Creates and controls a `Stream` |
| `StreamSubscription<T>` | A handle to a subscription; supports pause, resume, cancel |
| `StreamSink<T>` | The input side of a stream (via `controller.sink`) |

**Single-Subscription vs Broadcast:**

```dart
// Single-subscription — only one listener at a time
final controller = StreamController<int>();

// Broadcast — multiple concurrent listeners
final broadcast = StreamController<int>.broadcast();
```

| Property | Single-Subscription | Broadcast |
|----------|-------------------|-----------|
| Listener count | Exactly 1 | 0..N |
| Buffering | Events buffered until listener attaches | Events lost if no listener |
| Use case | File I/O, HTTP responses | UI events, state changes |

**Event Types:**

A stream emits three types of events:

1. **Data events** — the values (`onData`)
2. **Error events** — exceptions (`onError`)
3. **Done event** — stream closed (`onDone`)

```dart
final controller = StreamController<String>.broadcast();

final subscription = controller.stream.listen(
  (data) => print('Data: $data'),     // onData
  onError: (error) => print('Error: $error'),  // onError
  onDone: () => print('Stream closed'),        // onDone
);

controller.add('hello');
controller.addError(Exception('oops'));
controller.close();

// Later: clean up
subscription.cancel();
```

**Subscription Control:**

```dart
final sub = stream.listen((data) => print(data));
sub.pause();           // Pause receiving events (buffered)
sub.resume();          // Resume
await sub.cancel();    // Permanently detach
```

**async* Generator Syntax:**

```dart
Stream<int> countUp(int max) async* {
  for (int i = 0; i <= max; i++) {
    await Future.delayed(Duration(seconds: 1));
    yield i;
  }
}
```

### Future

A one-shot asynchronous computation that produces a single value or error.

```dart
Future<String> fetchData() async {
  final response = await httpClient.get(uri);
  return response.body;
}

// Listening to completion:
fetchData().then(
  (value) => print('Got: $value'),
  onError: (e) => print('Error: $e'),
);

// Or with await:
try {
  final data = await fetchData();
} catch (e) {
  print('Error: $e');
}
```

**Key difference from Stream:** A `Future` resolves exactly once. A `Stream` can emit zero or more events over time.

### StreamTransformer and Stream Operators

Streams support a rich set of transformation operators (functional-reactive style):

| Operator | Description |
|----------|-------------|
| `stream.map((e) => ...)` | Transform each element |
| `stream.where((e) => ...)` | Filter elements |
| `stream.expand((e) => [...])` | One-to-many transform |
| `stream.distinct()` | Skip consecutive duplicates |
| `stream.asyncMap((e) async => ...)` | Async transform per element |
| `stream.asyncExpand((e) => stream)` | Flatten async sub-streams |
| `stream.take(n)` / `stream.skip(n)` | Limit element count |
| `stream.takeWhile(pred)` / `stream.skipWhile(pred)` | Conditional take/skip |
| `stream.timeout(duration)` | Error on timeout between events |
| `stream.handleError(handler)` | Intercept errors |
| `stream.transform(transformer)` | Apply a custom `StreamTransformer` |

**Custom StreamTransformer:**

```dart
final transformer = StreamTransformer<int, String>.fromHandlers(
  handleData: (data, sink) {
    sink.add('Value: $data');
  },
  handleError: (error, stackTrace, sink) {
    sink.addError('Wrapped: $error');
  },
);

stream.transform(transformer).listen(print);
```

---

## Part 2 — Flutter Foundation Patterns

These classes live in `package:flutter/foundation.dart` and have no dependency on the widget tree.

### Listenable

The root interface for all callback-based observation in Flutter.

```dart
abstract class Listenable {
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
}
```

- **No value** — it only signals "something changed"
- Used as the base type for `ChangeNotifier`, `Animation`, and `ValueNotifier`
- `Listenable.merge([l1, l2, ...])` — combines multiple listenables into one

### ChangeNotifier

The standard mixin/class implementing `Listenable` with a list of callbacks.

```dart
class CounterModel extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners(); // Triggers all registered VoidCallbacks
  }
}
```

**Key characteristics:**

| Property | Detail |
|----------|--------|
| Notification granularity | None — just "something changed" |
| Listener type | `VoidCallback` (no payload) |
| Memory management | Must call `dispose()` to release listeners |
| Error handling | Catches listener exceptions, reports via `FlutterError` |
| Debug support | Asserts on use after `dispose()` |

**Lifecycle:**

```dart
final model = CounterModel();
void callback() => print('Changed: ${model.count}');

model.addListener(callback);
model.increment();            // prints "Changed: 1"
model.removeListener(callback);
model.dispose();              // releases all listeners, marks as disposed
```

### ValueNotifier\<T\>

A `ChangeNotifier` that holds a single typed value and notifies only when the value actually changes (uses `!=` comparison).

```dart
final counter = ValueNotifier<int>(0);

counter.addListener(() => print('Now: ${counter.value}'));
counter.value = 1;  // Notifies → "Now: 1"
counter.value = 1;  // No notification (same value)
counter.value = 2;  // Notifies → "Now: 2"
```

**Custom subclass pattern:**

```dart
class ClampedNotifier extends ValueNotifier<int> {
  ClampedNotifier(super.value);

  @override
  set value(int newValue) {
    super.value = newValue.clamp(0, 100);
  }
}
```

### ValueListenable\<T\>

The read-only interface for `ValueNotifier`. It is a `Listenable` that also exposes a typed `value` getter.

```dart
abstract class ValueListenable<T> extends Listenable {
  T get value;
}
```

Use `ValueListenable<T>` as the type for parameters and fields when you want read-only access to a notifier's value without exposing the setter.

### Animation\<T\> / AnimationController

`Animation<T>` extends `Listenable` and adds:

- A typed `value` (typically `double` from 0.0 to 1.0)
- An `AnimationStatus` (forward, reverse, completed, dismissed)
- Two listener types:
  - `addListener(VoidCallback)` — fires on every value change (every frame)
  - `addStatusListener(Function(AnimationStatus))` — fires on status transitions

```dart
final controller = AnimationController(
  duration: Duration(seconds: 1),
  vsync: this, // TickerProvider
);

controller.addListener(() => print(controller.value));
controller.addStatusListener((status) => print(status));

controller.forward(); // Animate from 0.0 to 1.0
```

**Curving and chaining:**

```dart
final curved = CurvedAnimation(parent: controller, curve: Curves.easeInOut);
final scaled = Tween<double>(begin: 0, end: 200).animate(curved);
// scaled.value goes from 0 to 200 with easing
```

---

## Part 3 — Flutter Widget-Tree Patterns

These patterns integrate observation into the widget tree for automatic rebuilds.

### InheritedWidget

The core Flutter mechanism for propagating data down the widget tree. Dependent widgets rebuild when `updateShouldNotify` returns `true`.

```dart
class ThemeData {
  final Color primaryColor;
  ThemeData(this.primaryColor);
}

class ThemeScope extends InheritedWidget {
  final ThemeData theme;
  const ThemeScope({required this.theme, required super.child});

  static ThemeData of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeScope>()!.theme;
  }

  @override
  bool updateShouldNotify(ThemeScope oldWidget) => theme != oldWidget.theme;
}
```

**How it works:**

1. `context.dependOnInheritedWidgetOfExactType<T>()` registers the calling widget as a dependent
2. When the `InheritedWidget` is replaced (parent rebuilds with new data), `updateShouldNotify` is called
3. If `true`, all dependents are marked dirty and rebuild

**Key property:** No callback registration — the framework tracks dependencies automatically through `BuildContext`.

### InheritedNotifier\<T\>

Combines `InheritedWidget` with a `Listenable`. Dependents rebuild automatically whenever the `Listenable` fires.

```dart
class CounterScope extends InheritedNotifier<ValueNotifier<int>> {
  const CounterScope({
    required ValueNotifier<int> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static int of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<CounterScope>()!
        .notifier!
        .value;
  }
}
```

The parent widget does **not** need to call `setState` — `InheritedNotifier` listens to the notifier internally and triggers dependent rebuilds.

### InheritedModel\<T\>

Fine-grained variant of `InheritedWidget`. Dependents declare which **aspect** they care about, and only rebuild when that specific aspect changes.

```dart
enum ThemeAspect { color, fontSize }

class ThemeModel extends InheritedModel<ThemeAspect> {
  final Color color;
  final double fontSize;

  const ThemeModel({
    required this.color,
    required this.fontSize,
    required super.child,
  });

  static ThemeModel of(BuildContext context, {required ThemeAspect aspect}) {
    return InheritedModel.inheritFrom<ThemeModel>(context, aspect: aspect)!;
  }

  @override
  bool updateShouldNotify(ThemeModel old) =>
      color != old.color || fontSize != old.fontSize;

  @override
  bool updateShouldNotifyDependent(ThemeModel old, Set<ThemeAspect> deps) {
    if (deps.contains(ThemeAspect.color) && color != old.color) return true;
    if (deps.contains(ThemeAspect.fontSize) && fontSize != old.fontSize) return true;
    return false;
  }
}
```

A widget that only depends on `ThemeAspect.color` will **not** rebuild when only `fontSize` changes.

### NotificationListener / Notification

A bubble-up communication pattern. Widgets dispatch `Notification` subclasses that travel up the tree until caught by a `NotificationListener`.

```dart
// Define a custom notification
class ItemSelectedNotification extends Notification {
  final int itemId;
  ItemSelectedNotification(this.itemId);
}

// Dispatch from a child widget
ItemSelectedNotification(42).dispatch(context);

// Catch in an ancestor
NotificationListener<ItemSelectedNotification>(
  onNotification: (notification) {
    print('Selected: ${notification.itemId}');
    return true;  // true = stop bubbling, false = continue
  },
  child: childWidget,
)
```

**Built-in notifications:** `ScrollNotification`, `OverscrollNotification`, `LayoutChangedNotification`, `SizeChangedLayoutNotification`, `KeepAliveNotification`.

### StreamBuilder

Rebuilds a widget subtree in response to `Stream` events.

```dart
StreamBuilder<int>(
  stream: myStream,
  initialData: 0,
  builder: (context, snapshot) {
    if (snapshot.hasError) return Text('Error: ${snapshot.error}');
    if (!snapshot.hasData) return CircularProgressIndicator();
    return Text('Value: ${snapshot.data}');
  },
)
```

**`AsyncSnapshot<T>` states:**

| Property | Meaning |
|----------|---------|
| `connectionState` | `none`, `waiting`, `active`, `done` |
| `hasData` | A data event has been received |
| `hasError` | An error event has been received |
| `data` | The latest data value |
| `error` | The latest error |

### FutureBuilder

Rebuilds based on the state of a single `Future`.

```dart
FutureBuilder<String>(
  future: fetchData(),
  builder: (context, snapshot) {
    switch (snapshot.connectionState) {
      case ConnectionState.waiting:
        return CircularProgressIndicator();
      case ConnectionState.done:
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');
        return Text(snapshot.data!);
      default:
        return SizedBox.shrink();
    }
  },
)
```

**Warning:** Avoid creating the `Future` inside `build()` — this causes a new future on every rebuild. Store it in `initState()` or outside the widget.

### ValueListenableBuilder

Efficiently rebuilds only its subtree when a `ValueListenable<T>` changes. The `child` parameter enables optimization by excluding static subtrees from rebuilds.

```dart
ValueListenableBuilder<int>(
  valueListenable: counter,
  builder: (context, value, child) {
    return Row(
      children: [
        Text('Count: $value'),
        child!, // Static widget — not rebuilt
      ],
    );
  },
  child: Icon(Icons.star), // Passed as child parameter
)
```

### ListenableBuilder / AnimatedBuilder

Rebuilds when any `Listenable` fires. `ListenableBuilder` (Flutter 3.10+) is the modern replacement for `AnimatedBuilder`.

```dart
ListenableBuilder(
  listenable: myChangeNotifier,
  builder: (context, child) {
    return Text('Value: ${myChangeNotifier.someProperty}');
  },
)

// AnimatedBuilder — identical API, typically used with Animation
AnimatedBuilder(
  animation: controller,
  builder: (context, child) {
    return Transform.rotate(
      angle: controller.value * 2 * pi,
      child: child,
    );
  },
  child: Icon(Icons.refresh),
)
```

---

## Part 4 — Flutter Lifecycle and Navigation Observers

### WidgetsBindingObserver

Observe application-level lifecycle events.

```dart
class _MyState extends State<MyWidget> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // state: resumed, inactive, paused, detached, hidden
  }

  @override
  void didChangeMetrics() { /* screen size/orientation changed */ }

  @override
  void didChangeLocales(List<Locale>? locales) { /* locale changed */ }

  @override
  void didChangeTextScaleFactor() { /* accessibility text scaling changed */ }

  @override
  void didHaveMemoryPressure() { /* OS memory warning */ }
}
```

### NavigatorObserver / RouteObserver / RouteAware

**NavigatorObserver** — observe all navigation events:

```dart
class AnalyticsObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    analytics.logScreenView(route.settings.name);
  }

  @override
  void didPop(Route route, Route? previousRoute) { }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) { }

  @override
  void didRemove(Route route, Route? previousRoute) { }
}

// Register:
MaterialApp(navigatorObservers: [AnalyticsObserver()])
```

**RouteObserver + RouteAware** — individual widgets observe their own route visibility:

```dart
final routeObserver = RouteObserver<ModalRoute<void>>();

class _MyPageState extends State<MyPage> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() { /* Returned to this page (was covered, now revealed) */ }

  @override
  void didPushNext() { /* Another page pushed on top of this one */ }
}
```

---

## Part 5 — Comparison and Selection Guide

### Pattern Selection Matrix

| Scenario | Recommended Pattern |
|----------|-------------------|
| Single changing value, rebuild one widget | `ValueNotifier` + `ValueListenableBuilder` |
| Complex model with multiple fields | `ChangeNotifier` + `ListenableBuilder` |
| Async data from network/file/DB | `Stream` + `StreamBuilder` |
| One-shot async load | `Future` + `FutureBuilder` |
| Share data down widget tree | `InheritedWidget` / `InheritedNotifier` |
| Fine-grained per-aspect dependency | `InheritedModel` |
| Child-to-parent communication | `NotificationListener` + custom `Notification` |
| Animation values | `AnimationController` + `AnimatedBuilder` |
| App lifecycle events | `WidgetsBindingObserver` |
| Navigation tracking | `NavigatorObserver` / `RouteObserver` |
| Multiple listenables combined | `Listenable.merge()` + `ListenableBuilder` |

### Key Differences: Dart-Only vs Flutter-Only

| Pattern | Dart | Flutter | Notes |
|---------|------|---------|-------|
| `Stream` / `StreamController` | Yes | Yes (+ `StreamBuilder`) | The only Dart-native reactive pattern |
| `Future` | Yes | Yes (+ `FutureBuilder`) | One-shot async |
| `ChangeNotifier` | — | Yes | Requires `package:flutter/foundation.dart` |
| `ValueNotifier` | — | Yes | Extends `ChangeNotifier` |
| `Listenable` | — | Yes | Abstract interface |
| `InheritedWidget` | — | Yes | Widget-tree scoped |
| `Notification` | — | Yes | Bubble-up in widget tree |

### Memory Management Summary

| Pattern | Cleanup Required |
|---------|-----------------|
| `ChangeNotifier` / `ValueNotifier` | Call `dispose()` when done |
| `Stream` listener | Call `subscription.cancel()` |
| `StreamController` | Call `controller.close()` |
| `WidgetsBindingObserver` | Call `removeObserver(this)` |
| `RouteAware` | Call `unsubscribe(this)` |
| `InheritedWidget` | None — framework-managed |
| `StreamBuilder` / `ValueListenableBuilder` | None — widget lifecycle manages it |

### Notification Direction

| Direction | Patterns |
|-----------|----------|
| Down the tree | `InheritedWidget`, `InheritedNotifier`, `InheritedModel` |
| Up the tree | `NotificationListener` / `Notification.dispatch()` |
| Lateral / decoupled | `Stream`, `ChangeNotifier`, `ValueNotifier` |
| From child to builder | `StreamBuilder`, `FutureBuilder`, `ValueListenableBuilder` |
