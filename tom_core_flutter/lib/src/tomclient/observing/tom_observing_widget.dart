import 'package:flutter/material.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A widget that rebuilds whenever a [TomObservable] notifies its observers.
///
/// `TomObservingWidget` bridges the kernel observation model to Flutter: it
/// registers as a [TomObserver] on [subState] and calls [State.setState] on
/// every notification, re-invoking [builder] with the (current) observable.
///
/// ```dart
/// final showForm = TomBool(false);
///
/// TomObservingWidget<TomBool>(
///   subState: showForm,
///   builder: (s, _) => ~s ? const FormPanel() : const SizedBox.shrink(),
/// );
///
/// showForm | true; // the widget rebuilds
/// ```
///
/// **[child] is the hoisting escape hatch**, and it is the same one
/// [ValueListenableBuilder] and [AnimatedBuilder] provide. A subtree that does
/// not depend on the observable is built **once**, by the parent, and handed
/// back to [builder] as its second argument on every rebuild — so a form bound
/// to a high-frequency observable does not repaint the part of itself that
/// cannot have changed:
///
/// ```dart
/// TomObservingWidget<TomInt>(
///   subState: progress,
///   // Built once, however often `progress` ticks.
///   child: const ExpensiveChart(),
///   builder: (value, child) => Column(
///     children: [Text('${~value}%'), child!],
///   ),
/// );
/// ```
///
/// It is `null` when no subtree was hoisted, which is why [builder]'s second
/// parameter is nullable: a builder that asks for a child it was not given is a
/// mistake at the call site, and `child!` says where to look.
class TomObservingWidget<T extends TomObservable> extends StatefulWidget {
  /// Creates a widget that rebuilds [builder] whenever [subState] notifies.
  ///
  /// [key] is the ordinary widget key, and it is the lever that chooses between
  /// this widget's two behaviours. Whether Flutter reuses the element or builds
  /// a new one is what selects between [TomObservingWidgetState.didUpdateWidget]
  /// *migrating* the registration and [State.initState] making a fresh one — so
  /// a parent that rebuilds with the same key keeps the `State`, and one that
  /// rebuilds with a different key disposes it and starts over. The second is
  /// the normal wish when a list row rebinds to an unrelated model.
  TomObservingWidget({
    super.key,
    required this.builder,
    required this.subState,
    this.child,
  });

  /// Builds the subtree from the current observable state and the hoisted
  /// [child].
  ///
  /// Named `builder` rather than `child` because that is what it is: in
  /// Flutter, `child` names a pre-built `Widget` slot and a `Widget Function`
  /// is a builder. The distinction is what lets a reader tell from the call
  /// site alone whether a subtree is built eagerly or on demand — and this
  /// widget now has both, so the two names cannot be traded.
  ///
  /// Read the observable **inside** the builder. The argument is the
  /// observable itself, not a snapshot of its value, so capturing `~state`
  /// outside and closing over it would freeze the value at the moment the
  /// closure was created.
  final Widget Function(T state, Widget? child) builder;

  /// A subtree built once and handed to [builder] on every rebuild, or `null`.
  ///
  /// The part of the subtree that does not depend on [subState]. It is built by
  /// the parent, in the parent's build, and is therefore untouched by this
  /// widget's [State.setState] — which is the whole mechanism: a rebuild
  /// re-runs [builder], and anything reached through this field is reused
  /// rather than rebuilt.
  final Widget? child;

  /// The observable whose notifications drive the rebuild.
  final T subState;

  @override
  State<StatefulWidget> createState() => TomObservingWidgetState<T>();
}

/// The [State] for [TomObservingWidget]; observes the current
/// [TomObservingWidget.subState] and rebuilds on every notification.
///
/// The observation lifecycle follows the standard Flutter `State` contract, so
/// the bridge does not outlive the element:
///   * [initState] registers as an observer on the initial `subState`.
///   * [didUpdateWidget] migrates the registration when the parent rebuilds
///     with a different `subState`, so the widget always observes the current
///     observable and drops the previous one.
///   * [dispose] deregisters before the element is destroyed, so a later
///     mutation never calls [setState] on a disposed `State`.
///
/// **What the deregistration is and is not for.** [TomObservable] holds its
/// observers by `WeakReference`, so the registration never kept this `State`
/// alive and removing it is not what releases it. The reference that does exist
/// runs the other way: [TomObservingWidget.subState] is a plain strong field,
/// so while the element is mounted it is the *observable* that the widget keeps
/// alive. What [dispose] buys is a known moment — notifications stop when the
/// widget leaves the tree instead of whenever the collector next runs, which is
/// what prevents `setState() called after dispose()`.
class TomObservingWidgetState<T extends TomObservable>
    extends State<TomObservingWidget<T>>
    implements TomObserver {
  @override
  void initState() {
    super.initState();
    widget.subState.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant TomObservingWidget<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.subState, oldWidget.subState)) {
      oldWidget.subState.removeObserver(this);
      widget.subState.addObserver(this);
    }
  }

  @override
  void dispose() {
    widget.subState.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(widget.subState, widget.child);
  }

  /// Rebuilds this widget for a notification from the observed observable.
  ///
  /// **The `mounted` guard closes a window [dispose] cannot.** Deregistering in
  /// [dispose] makes the ordinary path safe, but [TomObservable.notifyObservers]
  /// iterates a *snapshot* taken before the loop — so an observer removed by an
  /// earlier observer's `onNotify` in the same round is still notified, and a
  /// `setState` on a disposed `State` throws. The guard makes a notification
  /// that arrives after teardown a no-op, which is the right answer: there is
  /// no element left to rebuild.
  ///
  /// **A notification arriving during a build is deliberately left to throw.**
  /// Flutter's "setState() or markNeedsBuild() called during build" names the
  /// widget that mutated the observable from inside its own `build`, which is
  /// an application-structure mistake. Deferring the rebuild to a post-frame
  /// callback would make it work — one frame late, every time, silently —
  /// trading a diagnosable failure for an undiagnosable one. See
  /// `doc/observing.md`, "Lifecycle and Limitations".
  @override
  void onNotify(TomObservable observable) {
    if (!mounted) return;
    // A closure, not a string. `TomLogOutput.convertToString` calls a `Function`
    // message, and every output does so *inside* its level check — so the
    // message, and `observable.toString()` with it, is built only when the line
    // is actually written. Interpolating here would walk a `TomList`'s or a
    // `TomClass`'s contents on every mutation for the lifetime of the widget,
    // with trace logging off, in the one module whose purpose is being attached
    // to state that changes often.
    tomLog.trace(
      () =>
          "TomObservingWidgetState: Updating state "
          "${observable.runtimeType} $observable",
    );
    // Empty on purpose. `setState` brackets a *state mutation*, and the
    // mutation already happened — in the observable, outside this widget. What
    // this call is for is marking the element dirty; putting anything else in
    // the callback would say the opposite.
    setState(() {});
  }
}
