# Observing Module

Bridges the kernel observation model (`TomObservable` / `TomObserver`) to
Flutter's rebuild and listenable machinery. It lets observable kernel state
drive widget rebuilds directly, without `ChangeNotifier`/`ValueNotifier`
plumbing.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
- [Lifecycle and Limitations](#lifecycle-and-limitations)
- [Dependencies](#dependencies)

---

## Overview

| Type | Implements | Purpose |
| ---- | ---------- | ------- |
| `TomObservingWidget<T>` | `StatefulWidget` | Rebuilds a subtree whenever the bound `TomObservable` notifies |
| `ValueListenableObserver<T>` | `TomObserver<T>`, `ValueListenable<T>` | Adapts a `TomObservable` to Flutter's `ValueListenable` contract |

Both adapt the kernel observation primitives:

- A [`TomObservable`](../../tom_core_kernel/doc/observable/observable.md) is read
  with `~`, set with `|`, and notifies its observers on change.
- A `TomObserver<T>` receives `void onNotify(T observable)` callbacks.

## Quick Start

Rebuild a widget when an observable changes:

```dart
import 'package:tom_core_flutter/tom_core_flutter.dart';

final showForm = TomBool(false);

TomObservingWidget<TomBool>(
  subState: showForm,
  builder: (state, _) =>
      ~state ? const FormPanel() : const SizedBox.shrink(),
);

showForm | true; // the widget rebuilds and shows FormPanel
```

Feed an observable into any `ValueListenable` consumer:

```dart
final error = TomString('');
final adaptor = ValueListenableObserver<TomString>(error);

ValueListenableBuilder<TomString>(
  valueListenable: adaptor,
  builder: (context, value, _) => Text(~value),
);

error | 'Boom'; // the builder rebuilds with "Boom"
```

## Core Components

### `TomObservingWidget<T extends TomObservable>`

A `StatefulWidget` whose state registers as a `TomObserver` on `subState`. On
every notification it calls `setState`, re-invoking `builder` with the (current)
observable. The builder receives the observable itself, so read its value with
`~state` inside the closure.

| Parameter | Type | Meaning |
| --------- | ---- | ------- |
| `key` | `Key?` | Standard widget key — and the lever that selects between the two behaviours below |
| `subState` | `T` | The observable whose notifications drive the rebuild |
| `builder` | `Widget Function(T state, Widget? child)` | Builds the subtree from the current observable and the hoisted `child` |
| `child` | `Widget?` | A subtree built **once** and handed to `builder` on every rebuild, or `null` |

`builder` is a builder and is named like one: in Flutter, `child` names a
pre-built `Widget` slot and a `Widget Function` is a builder. The widget has
both, so the two names cannot be traded.

#### Hoisting a subtree that does not depend on the observable

`child` is the same escape hatch `ValueListenableBuilder` and `AnimatedBuilder`
provide, and it exists for the case this module is for: a form bound to a
high-frequency observable would otherwise repaint everything its builder returns
on every keystroke or frame.

```dart
TomObservingWidget<TomInt>(
  subState: progress,
  // Built once by the parent, however often `progress` ticks.
  child: const ExpensiveChart(),
  builder: (value, child) => Column(
    children: [Text('${~value}%'), child!],
  ),
);
```

What makes it work is that the *same widget instance* travels through every
rebuild: `child` is built in the parent's `build`, untouched by this widget's
`setState`, and Flutter skips rebuilding a child whose widget is identical to
the one already there. So the saving is the subtree's whole element rebuild, not
merely a closure call.

`builder`'s second parameter is nullable because `child` is optional. A builder
that reaches for a child it was not given should fail at the `!`, which names
the call site, rather than render something empty.

### `ValueListenableObserver<T extends TomObservable>`

Adapts a `TomObservable` to `ValueListenable<T>`. `value` returns the observed
observable; `addListener` appends a callback fired on each
notification, and `removeListener` removes the one it is given. Use it to plug
kernel state into
`ValueListenableBuilder`, `AnimatedBuilder`, or anything else accepting a
`ValueListenable` — but read
[Lifecycle and Limitations](#lifecycle-and-limitations) first: **an adaptor held
beyond a single build must be disposed**.

## Lifecycle and Limitations

- **Automatic registration and migration.** `TomObservingWidgetState` follows the
  standard `State` lifecycle: it registers its observer in `initState`, migrates
  the registration to the new observable in `didUpdateWidget` when the parent
  rebuilds with a different `subState` (dropping the old one), and deregisters in
  `dispose`. A mutation after the widget unmounts therefore never triggers
  `setState() called after dispose()`.
- **The `key` chooses between migrating and starting over.** Which of those two
  paths runs is Flutter's ordinary element-reuse decision, and `key` is how a
  caller makes it:

  | The parent rebuilds with | Flutter | This widget |
  | ------------------------ | ------- | ----------- |
  | the same key (or none) | reuses the element | `didUpdateWidget` migrates the registration; the `State` is kept |
  | a different key | builds a new element | `initState` registers afresh; the old `State` is disposed and deregisters |

  The second is the normal wish when a list row rebinds to an unrelated model: a
  clean `State`, not a migrated one. It is also what lets the widget be used in a
  keyed or reorderable list at all, which is why `key` is worth naming here rather
  than leaving as boilerplate.
- **An adaptor is bound to one observable, for life.** `observable` is `final`:
  the constructor registers against that observable and nothing moves the
  registration. A settable field would produce an adaptor that reports one
  observable through `value` while `onNotify` fires from another — a
  `ValueListenableBuilder` rebuilding on one observable's changes while
  rendering the other's contents. Retargeting is what a new adaptor is for.
  `TomObservingWidget` migrates instead, and can, because a widget has a
  `didUpdateWidget` to migrate in; the adaptor has no lifecycle at all.

  The listener list is private for the same reason: reaching it would bypass
  `addListener` and `removeListener`, which is where registration is traced and
  where use after `dispose` is caught.
- **Construction subscribes; `dispose` is what ends it.** The adaptor registers
  itself on the observable in its constructor, and `ValueListenableObserver.dispose()`
  is the only thing that deregisters it. An adaptor held beyond a single build —
  in a `State` field, which is the normal way to hold one — **must** be disposed,
  exactly like the `TomObservingWidget` it is the non-widget counterpart of:

  ```dart
  class _MyScreenState extends State<MyScreen> {
    late final ValueListenableObserver<TomString> error =
        ValueListenableObserver(widget.state.error);

    @override
    void dispose() {
      error.dispose();
      super.dispose();
    }
  }
  ```

  `removeListener` is **not** a substitute. It clears the Flutter listener and
  leaves the kernel registration in place, so the adaptor stays on the
  observer list and keeps running `onNotify`; refill the slot and it forwards
  again. After `dispose` there is no registration to resume from, and adding a
  listener to a disposed adaptor fails an `assert` rather than silently never
  firing. `dispose` is idempotent, and disposing one adaptor leaves any other
  adaptor on the same observable working.

  The weak-observer sweep below is not an answer here. It ends the subscription
  when the adaptor becomes unreachable *and* something else happens to notify —
  not a moment a caller can choose — and an adaptor still held in a field never
  becomes unreachable at all.
- **Which side holds which.** The two references point in opposite directions,
  and confusing them leads to reasoning about observer lifetime backwards:
  - The **observable holds its observers weakly**. `addObserver` stores a
    `WeakReference`, and `notifyObservers` prunes the ones whose target has been
    collected — so registering never kept the widget's `State` alive, and
    deregistering is not what releases it. See the kernel's
    [Memory Management](../../tom_core_kernel/doc/observable/observable.md#memory-management--you-must-retain-the-observer).
  - The **widget holds the observable strongly**, through the plain
    `final T subState` field. So for as long as the element is mounted, it is
    the *observable* that is kept alive by the widget — never the other way
    round. `dispose` removing the registration does nothing about that
    reference; unmounting the widget is what drops it.
- **What a caller may and may not do from inside a `build`.** Mutating an
  observable that something else observes, from inside a `build`, throws
  Flutter's "setState() or markNeedsBuild() called during build". That is
  deliberate and is not guarded against: the message names the widget that
  performed the mutation, which is where the mistake is. Deferring the rebuild
  to a post-frame callback would make it work — one frame late, every time,
  silently — trading a diagnosable failure for an undiagnosable one.

  The mutation itself carries no hint that it schedules anybody's rebuild: it is
  a plain `|` assignment. So the rule is about where state is written, not about
  which operator writes it — compute inside `build`, write outside it. A value
  that must be derived during layout belongs in a post-frame callback the
  *application* schedules, where the one-frame delay is a decision somebody made
  rather than one the framework made for them.

  Reading an observable during a build is unaffected, and is what the builder is
  for.
- **A notification arriving after teardown is a no-op.** `onNotify` returns early
  when the `State` is no longer `mounted`. `dispose` deregisters, so the ordinary
  path never reaches that check; the window it closes is the kernel's.
  `TomObservable.notifyObservers` iterates a **snapshot** taken before the loop,
  so an observer removed by an earlier observer's `onNotify` in the same round is
  still notified — and without the guard that is a `setState` on a disposed
  `State`.
- **Deregistration buys promptness, not leak prevention.** Because the
  registration was weak all along, the `removeObserver` in `dispose` is not
  standing between the application and a leak. What it buys is a *known moment*:
  notifications stop when the widget leaves the tree rather than whenever the
  collector next runs, which is what keeps a post-unmount mutation from reaching
  a disposed `State`. The corollary is the part worth remembering — an observer
  that is still reachable but no longer wanted **keeps receiving notifications
  for as long as something else holds it**. Collection is not a substitute for
  removing it.
- **`ValueListenableObserver` is a real multicast `Listenable`.** `addListener`
  appends and `removeListener` removes the callback it is given, so one adaptor
  may be handed to any number of consumers — two `ValueListenableBuilder`s, a
  builder plus an `AnimatedBuilder`, a manual registration in a
  `State.initState` — and each is notified.

  That it keeps the contract matters more than it sounds. A `Listenable` is
  *structurally* substitutable wherever Flutter asks for one: nothing at a call
  site distinguishes an adaptor that multicasts from one that does not, so an
  implementation that replaced on add would leave the first consumer silently
  not rebuilding, with no error anywhere to find.

  Flutter's own corner semantics apply, and each is asserted by the suite:
  - registering the same callback **twice** makes it fire twice, and one
    `removeListener` undoes one registration — the list counts registrations
    rather than de-duplicating them;
  - removing a callback that was **never registered** does nothing, rather than
    silencing the adaptor;
  - a listener may **add or remove listeners while being notified.** Dispatch
    walks a snapshot, so one removed mid-notification does not shift those after
    it, and one added mid-notification is called on the next notification rather
    than this one.

  `removeListener` is tolerated after `dispose`, unlike `addListener`: a widget
  tearing down cannot always control whether the listenable it registered on was
  disposed first, and refusing the call would turn a correct teardown into a
  crash.

---

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `flutter` | package | every file | `StatefulWidget`/`State` and `ValueListenable` |
| `tom_core_kernel` | package | every file | `TomObservable` and `TomObserver`, the observation primitives both adapters bridge |
